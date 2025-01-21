## Restore Old Right Click Menu
& reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve


## Add terminal admin
& reg.exe import .\add_terminal_admin_context_menu.reg

function EnableFileExtensionsAndHiddenFiles {
    try {
        # Enable viewing of file extensions
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0

        # Enable viewing of hidden files
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1

        # Refreshing the desktop and explorer windows to apply changes
        Stop-Process -Name explorer -Force
        Start-Process explorer
        
        Write-Host "File extensions and hidden files are now visible." -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

function Set-UACToHighestLevel {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 2

}

function Disable-DownloadWarnings {


    # Disable Edge Download Warning
    $edgeKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    $edgeValueName = "EdgeDownloadBlockPolicy"
    $edgeValueData = 0

    # Check if the key exists; if not, create it
    if (-not (Test-Path $edgeKeyPath)) {
        New-Item -Path $edgeKeyPath -Force
    }

    # Set the registry value
    Set-ItemProperty -Path $edgeKeyPath -Name $edgeValueName -Value $edgeValueData



    # Disable Open File Warning
    $openFileKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations"
    $openFileValueName = "LowRiskFileTypes"
    $openFileValueData = ".zip;.rar;.nfo;.txt;.exe;.bat;.com;.cmd;.reg;.msi;.htm;.html;.gif;.bmp;.jpg;.avi;.mpg;.mpeg;.mov;.mp3;.m3u;.wav;.bin;"

    # Check if the key exists; if not, create it
    if (-not (Test-Path $openFileKeyPath)) {
        New-Item -Path $openFileKeyPath -Force
    }

    # Set the registry value
    Set-ItemProperty -Path $openFileKeyPath -Name $openFileValueName -Value $openFileValueData
}

Function Disable-EdgeSmartScreen {
    <#
    .SYNOPSIS
        Disables SmartScreen in Microsoft Edge by setting the registry value to 1.

    .DESCRIPTION
        This function modifies the Windows Registry to disable the SmartScreen feature in Microsoft Edge
        for the current user. It sets the default value of the `SmartScreenEnabled` key to `1`.

    .EXAMPLE
        Disable-EdgeSmartScreen
    #>

    try {
        # Define the registry path
        $registryPath = "HKCU:\Software\Microsoft\Edge\SmartScreenEnabled"

        # Ensure the registry key exists; create it if it doesn't
        if (-not (Test-Path -Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            Write-Verbose "Created registry path: $registryPath"
        }

        # Set the default value to 1 to disable SmartScreen
        Set-ItemProperty -Path $registryPath -Name "(Default)" -Value 0 -Type DWord -Force

        Write-Output "SmartScreen has been disabled in Microsoft Edge successfully."
    }
    catch {
        Write-Error "Failed to disable SmartScreen in Microsoft Edge. Error details: $_"
    }
}

function Restrict-WindowsUpdates {
    # Mostly because I use immutable windows images, I update my backups manually.
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Force }
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name AUOptions -Value 2 -Force
}


function Disable-BluetoothAdapter($instancePath) {
    # The MAC address of the network adapter to disable
    $device = Get-PnpDevice | Where-Object { $_.InstanceId -eq $instancePath }
    
    if ($device) {
        # Disable the network adapter
        Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
        Write-Output "Bluetooth adapter has been disabled successfully."
    }
    else {
        Write-Error "Bluetooth adapter not found."
    }


}

Function Set-MemoryIntegrity {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet("Enable", "Disable")]
        [string]$Action
    )

    # Check for Administrator privileges
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "You must run this script as an Administrator."
        return
    }

    try {
        # Define the correct registry path
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"

        # Ensure the intermediate registry keys exist
        if (-not (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios")) {
            New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "Scenarios" -Force | Out-Null
            Write-Output "Created registry path: HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios"
        }

        # Create the 'HypervisorEnforcedCodeIntegrity' key if it doesn't exist
        if (-not (Test-Path $regPath)) {
            New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios" -Name "HypervisorEnforcedCodeIntegrity" -Force | Out-Null
            Write-Output "Created registry key: HypervisorEnforcedCodeIntegrity"
        }

        # Set the 'Enabled' DWORD value
        $enabledValue = if ($Action -eq "Enable") { 1 } else { 0 }
        New-ItemProperty -Path $regPath -Name "Enabled" -Value $enabledValue -PropertyType DWORD -Force | Out-Null
        Write-Output "Memory Integrity has been set to $Action successfully."

    }
    catch {
        Write-Error "An error occurred: $_"
    }
}

function Disable-WakeArmedDevices($excludedDevices) {
    # Get all devices that can wake the computer
    $wakeDevices = powercfg /devicequery wake_armed

    foreach ($device in $wakeDevices) {
        # Check if the device is in the excluded list
        if ($excludedDevices -notcontains $device -and $device -ne "") {
            # Disable the device's ability to wake the computer
            powercfg /devicedisablewake "$device"
            Write-Output "Disabled wake ability for device: $device"
        }
    }
}

Set-ExecutionPolicy RemoteSigned -Scope LocalMachine

EnableFileExtensionsAndHiddenFiles
Set-UACToHighestLevel
Disable-DownloadWarnings
Disable-EdgeSmartScreen
Disable-BluetoothAdapter "USB\VID_13D3&PID_3533\00E04C000001"
Set-MemoryIntegrity "Enable"
Disable-WakeArmedDevices -excludedDevices @("Realtek Gaming 2.5GbE Family Controller")