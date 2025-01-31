param($port)

if($null -eq $port) {
    Write-Host "You must specify a port number!"
    return
}

# Install the OpenSSH Client
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Install the OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start the sshd service
Start-Service sshd

# OPTIONAL but recommended:
Set-Service -Name sshd -StartupType 'Automatic'


#Set default shell to PowerShell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force



# I don't care, these are public keys and by design can be exposed publically without much risk
$publicKeys = @"
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC1NXygJ4nSga//IAa8sF5S3lzu70eAWK6ze/PU9JeEx Shortcuts on DeltaE (2)

ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHuWx+Oa7g6J0L0mx16kI3ZDVs515zfeHjR4pMFUvwjK Shortcuts on iPad (2)

ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID5PU+282iAazrIT9u7MT1RUv8dlWAafO6GNxXeNcPWp Terminus on iPad
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCFx28Lr3b6dwv+iLC/96jvKJKqsC4xyCWo1oe6jXVT Macintosh
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3noGSVzUmcp71+aH8MBwhGMlJqAJHEJxVOf2W6LsB9 Shortcuts on iPad (3)
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGK8G4WXfcIGHX7ih7qyeu7Za1HeJaWOADyHBNOG1Enx
"@
Add-Content -Force -Path $env:ProgramData\ssh\administrators_authorized_keys -Value $publicKeys;
& icacls.exe "$env:ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

# Create a new firewall rule to allow OpenSSH to communicate over specified port
New-NetFirewallRule -DisplayName "Allow OpenSSH" -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow

# Also creating the rule for outbound traffic (optional)
New-NetFirewallRule -DisplayName "Allow OpenSSH" -Direction Outbound -LocalPort $port -Protocol TCP -Action Allow


# Define the path to the sshd_config file
$SSHDConfigPath = 'C:\ProgramData\ssh\sshd_config'

# Check if the sshd_config file exists
if (Test-Path $SSHDConfigPath) {
    
    # Take a backup of the existing config file
    Copy-Item $SSHDConfigPath -Destination "$SSHDConfigPath.bak" -Force
    
    # Change the port number to user defined port in the sshd_config file
    (Get-Content $SSHDConfigPath) | 
        ForEach-Object { $_ -replace '^#?Port\s+\d+', "Port $port" } | 
        Set-Content $SSHDConfigPath

    # Restart the sshd service to apply the changes
    Restart-Service sshd

    Write-Host "Port has been changed to $port and sshd service has been restarted." -ForegroundColor Green
}
else {
    Write-Host "sshd_config file not found at path: $SSHDConfigPath" -ForegroundColor Red
}