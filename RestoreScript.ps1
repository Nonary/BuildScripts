function Update-InstallationDate {
    param (
        [Parameter(Mandatory=$true)]
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
        Set-ItemProperty -Path $regPath -Name "InstallDate" -Value $unixTimestamp
        Set-ItemProperty -Path $regPath -Name "InstallTime" -Value $windowsFileTime

        Write-Host "Successfully updated InstallDate and InstallTime to $customDate"
    } catch {
        Write-Host "Failed to update installation date: $_"
    }
}

# Example usage of the function:
# Update-InstallationDate -CustomDateString '2023-10-01'
