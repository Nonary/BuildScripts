# Script Name: BackupAndRestore.ps1

<#
.SYNOPSIS
  Provides functions for preparing for backup (by removing a drive letter and saving partition info), 
  performing a backup, and restoring (by reattaching the drive letter and updating installation dates).

.PARAMETER Action
  The action to perform. Valid values are: Prepare, Backup, Restore.

.PARAMETER DriveLetter
  The drive letter to remove (for Prepare) or to reattach (for Restore). Not required for Backup.

.PARAMETER BackupTarget
  The backup target drive for wbadmin (used in Backup). Not required for Prepare or Restore.

.PARAMETER IncludeVolumes
  A list of volumes to include in the backup. (Optional – defaults to "C:")
#>

[CmdletBinding(DefaultParameterSetName = 'Prepare')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Backup", "Restore", "Prepare")]
    [string]$Action,

    [Parameter(Mandatory = $true, ParameterSetName = "Prepare", Position = 1, HelpMessage = "Drive letter required when preparing for backup.")]
    [Parameter(Mandatory = $true, ParameterSetName = "Restore", Position = 1, HelpMessage = "Drive letter required when restoring.")]
    [Parameter(Mandatory = $false, ParameterSetName = "Backup", HelpMessage = "Drive letter is not required for backup.")]
    [string]$DriveLetter,

    [Parameter(Mandatory = $true, ParameterSetName = "Backup", Position = 1, HelpMessage = "Backup target is required for Backup action.")]
    [Parameter(Mandatory = $false, ParameterSetName = "Prepare", HelpMessage = "Backup target is not required for Prepare.")]
    [Parameter(Mandatory = $false, ParameterSetName = "Restore", HelpMessage = "Backup target is not required for Restore.")]
    [string]$BackupTarget,

    [Parameter(Mandatory = $false)]
    [string]$IncludeVolumes = "C:"
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
        $windowsFileTime = [long]($timeSpan.TotalMilliseconds * 10000)

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
    # Ensure the drive letter is in the correct format (e.g. "C" instead of "C:")
    if ($DriveLetter.Contains(":")) {
        $DriveLetter = $DriveLetter.Replace(":", "")
    }
    try {
        $infoPath = "C:\ImageRecovery\PartitionInfo.json"
        if (-Not (Test-Path $infoPath)) {
            Write-Error "Partition info file not found. Cannot reattach drive letter."
            return
        }

        # Read the stored partition details
        $partitionInfo = Get-Content $infoPath | ConvertFrom-Json

        # Re-attach the drive letter using the stored DiskNumber and PartitionNumber
        Set-Partition -DiskNumber $partitionInfo.DiskNumber -PartitionNumber $partitionInfo.PartitionNumber -NewDriveLetter $DriveLetter -ErrorAction Stop
        Write-Host "Drive letter $DriveLetter reattached to partition (Disk $($partitionInfo.DiskNumber), Partition $($partitionInfo.PartitionNumber))."

        # Update the InstallDate (using today’s date)
        $today = Get-Date -Format "yyyy-MM-dd"
        Update-InstallationDate $today

        # Remove the ImageRecovery directory (cleanup)
        Remove-Item -Recurse C:\ImageRecovery -Force -ErrorAction Stop

        Write-Host "Restoration changes completed successfully."
    }
    catch {
        Write-Error "An error occurred during restoration: $_"
    }
}

function Prepare-ForBackup {
    try {
        # Ensure the drive letter is in the correct format (e.g. "C" instead of "C:")
        if ($DriveLetter.Contains(":")) {
            $DriveLetter = $DriveLetter.Replace(":", "")
        }
        
        # Create the ImageRecovery directory and copy this script for later use
        New-Item -Path C:\ImageRecovery -ItemType Directory -Force -ErrorAction Stop
        Copy-Item -Path "$PSScriptRoot\BackupAndRestore.ps1" -Destination C:\ImageRecovery -Force -ErrorAction Stop

        # Get the partition object before removing the drive letter
        $partition = Get-Partition -DriveLetter $DriveLetter
        if ($partition) {
            # Save partition details (DiskNumber and PartitionNumber) for restoration
            $partitionInfo = @{
                DiskNumber      = $partition.DiskNumber
                PartitionNumber = $partition.PartitionNumber
            }
            $partitionInfo | ConvertTo-Json | Out-File -FilePath "C:\ImageRecovery\PartitionInfo.json" -Force

            # Remove the drive letter from the partition
            Remove-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "$DriveLetter`:" -ErrorAction Stop
            Write-Host "Drive letter $DriveLetter removed."
        }
        else {
            Write-Error "Drive letter $DriveLetter not found."
            return
        }

        Write-Host "Now rebooting machine to prepare it for backup. Please log back in and run the script again with the Backup command."
        Restart-Computer -Force
    }
    catch {
        Write-Error "An error occurred during preparation: $_"
    }
}

# (Optional) Function for a full restore via wbadmin.
# Note: This function is currently not invoked in the main execution.
function Restore-FromBackup {
    try {
        # Specify the backup location (the BackupTarget parameter should be supplied if you want to use this function)
        $backupLocation = $BackupTarget  

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
switch ($Action) {
    "Prepare" {
        Prepare-ForBackup
        break
    }
    "Backup" {
        # Run the backup command (drive letter not needed)
        wbadmin start backup -backupTarget:$BackupTarget -allCritical -quiet
        break
    }
    "Restore" {
        Complete-RestorationChanges
        break
    }
}
