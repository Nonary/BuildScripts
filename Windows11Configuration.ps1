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

Add-OpenAsAdministratorTerminal
EnableFileExtensionsAndHiddenFiles
Set-UACToHighestLevel
