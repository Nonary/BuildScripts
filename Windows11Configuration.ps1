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
    $openFileValueData = ".zip;.rar;.nfo;.txt;.exe;.bat;.com;.cmd;.reg;.msi;.htm;.html;.gif;.bmp;.jpg;.avi;.mpg;.mpeg;.mov;.mp3;.m3u;.wav;"

    # Check if the key exists; if not, create it
    if (-not (Test-Path $openFileKeyPath)) {
        New-Item -Path $openFileKeyPath -Force
    }

    # Set the registry value
    Set-ItemProperty -Path $openFileKeyPath -Name $openFileValueName -Value $openFileValueData
}

function Restrict-WindowsUpdates {
    # Mostly because I use immutable windows images, I update my backups manually.
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Force }
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name AUOptions -Value 2 -Force
}


function Disable-BluetoothAdapter() {
    # The MAC address of the network adapter to disable
    $macAddress = "B4-8C-9D-9F-7E-B2"

    # Find the network adapter with the given MAC address
    $adapter = Get-NetAdapter | Where-Object { $_.MacAddress -eq $macAddress }

    # Check if the adapter was found
    if ($adapter) {
        # Disable the network adapter
        Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
        Write-Host "Adapter with MAC address $macAddress has been disabled."
    }
    else {
        Write-Host "No adapter found with MAC address $macAddress."
    }

}

Set-ExecutionPolicy RemoteSigned -Scope LocalMachine

EnableFileExtensionsAndHiddenFiles
Set-UACToHighestLevel
Disable-DownloadWarnings