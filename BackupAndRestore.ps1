# Script Name: BackupAndRestore.ps1

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Backup", "Restore")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$DriveLetter = "D",  # Default drive letter to remove and reassign
    [Parameter(Mandatory = $false)]
    [string]$BackupTarget = "E:",  # Default backup target drive
    [Parameter(Mandatory = $false)]
    [string]$IncludeVolumes = "C:"  # Default volumes to include in the backup
)

function Update-InstallationDate {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CustomDateString
    )

    try {
        # Parse the input date but keep the current time
        $customDate = Get-Date $CustomDateString -Hour (Get-Date).Hour -Minute (Get-Date).Minute -Second (Get-Date).Second

        # Convert the custom datetime to a Unix timestamp (seconds since 1970-01-01)
        $unixTimestamp = [int][double]::Parse((New-TimeSpan -Start (Get-Date "1970-01-01") -End $customDate).TotalSeconds)

        # Calculate the Windows File Time (100-nanosecond intervals since 1601-01-01)
        $epochStart = Get-Date -Year 1601 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
        $timeSpan = New-TimeSpan -Start $epochStart -End $customDate
        $windowsFileTime = [long]$timeSpan.TotalMilliseconds * 10000

        # Define the registry path
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

        # Set the InstallDate and InstallTime in the registry
        Set-ItemProperty -Path $regPath -Name "InstallDate" -Value $unixTimestamp -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "InstallTime" -Value $windowsFileTime -ErrorAction Stop

        Write-Host "Successfully updated InstallDate and InstallTime to $customDate"
    }
    catch {
        Write-Error "Failed to update installation date: $_"
    }
}

function Complete-RestorationChanges {
    try {
        # Re-attach the drive letter
        $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $null -and $_.GptType -ne $null }
        if ($partition) {
            Set-Partition -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -NewDriveLetter $DriveLetter -ErrorAction Stop
            Write-Host "Drive letter $DriveLetter reattached to partition."
        } else {
            Write-Error "No suitable partition found to reassign drive letter."
        }

        # Update the InstallDate
        $today = Get-Date -Format "yyyy-MM-dd"
        Update-InstallationDate $today

        # Remove the ImageRecovery directory
        Remove-Item -Recurse C:\ImageRecovery -Force -ErrorAction Stop

        Write-Host "Restoration changes completed successfully."
    }
    catch {
        Write-Error "An error occurred during restoration: $_"
    }
}

function Prepare-ForBackup {
    try {
        # Create the ImageRecovery directory and copy the script
        New-Item C:\ImageRecovery -ItemType Directory -Force -ErrorAction Stop
        Copy-Item -Path "$PSScriptRoot\BackupAndRestore.ps1" -Destination C:\ImageRecovery -Force -ErrorAction Stop

        # Remove the drive letter
        $partition = Get-Partition -DriveLetter $DriveLetter
        if ($partition) {
            Remove-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "$DriveLetter`:\" -ErrorAction Stop
            Write-Host "Drive letter $DriveLetter removed."
        } else {
            Write-Error "Drive letter $DriveLetter not found."
            return
        }

        # Define the script block for the first reboot (backup)
        $firstRebootScript = {
            param($BackupTarget, $IncludeVolumes)

            # Start the backup process using wbadmin
            Write-Host "Starting backup..."
            wbadmin start backup -backupTarget:$BackupTarget -include:$IncludeVolumes -quiet

            # Define the script block for the second reboot (restoration)
            $secondRebootScript = {
                # Import the RestoreScript.ps1
                . C:\ImageRecovery\BackupAndRestore.ps1 -Action Restore -DriveLetter $using:DriveLetter

                # Call the Complete-RestorationChanges function
                Complete-RestorationChanges
            }

            # Encode the second reboot script block to Base64
            $bytes2 = [System.Text.Encoding]::Unicode.GetBytes($secondRebootScript.ToString())
            $encodedCommand2 = [Convert]::ToBase64String($bytes2)

            # Build the command string with the encoded script
            $commandString2 = "powershell.exe -executionpolicy bypass -encodedcommand $encodedCommand2"

            # Add the command to the RunOnce registry key
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'SecondRebootScript' -Value $commandString2 -ErrorAction Stop

            # Reboot the system after backup
            Write-Host "Backup completed. System will reboot to complete restoration."
            Restart-Computer -Force
        }

        # Encode the first reboot script block to Base64
        $bytes1 = [System.Text.Encoding]::Unicode.GetBytes($firstRebootScript.ToString())
        $encodedCommand1 = [Convert]::ToBase64String($bytes1)

        # Build the command string with the encoded script and parameters
        $commandString1 = "powershell.exe -executionpolicy bypass -encodedcommand $encodedCommand1 -argumentlist '$($BackupTarget)', '$($IncludeVolumes)'"

        # Add the command to the RunOnce registry key
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'FirstRebootScript' -Value $commandString1 -ErrorAction Stop

        Write-Host "Preparation complete. System will reboot to start backup."
        Restart-Computer -Force
    }
    catch {
        Write-Error "An error occurred during preparation: $_"
    }
}

function Restore-FromBackup {
    try {
        # Specify the backup location
        $backupLocation = $BackupTarget  # Use the backup target specified

        # Get the list of available backups
        $backups = wbadmin get versions -backupTarget:$backupLocation

        # If there are multiple backups, select the latest one
        $latestBackup = ($backups | Select-String 'Version identifier')[-1]

        if ($latestBackup) {
            # Extract the version identifier
            $versionId = $latestBackup.ToString().Split(':')[1].Trim()

            Write-Host "Restoring from backup version: $versionId"

            # Start the bare metal recovery
            wbadmin start sysrecovery -version:$versionId -backupTarget:$backupLocation -recreateDisks -quiet

            Write-Host "Restoration initiated. The system will reboot after the process is complete."
        }
        else {
            Write-Error "No backups found to restore."
        }
    }
    catch {
        Write-Error "An error occurred during restoration: $_"
    }
}

# Main Script Execution

if ($Action -eq "Prepare") {
    Prepare-ForBackup
}
if($action -eq "Backup") {
 & wbadmin start backup -backupTarget:$BackupTarget -allCritical -quiet
}
elseif ($Action -eq "Restore") {
    Complete-RestorationChanges
}
