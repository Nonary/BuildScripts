# Define the file paths
$paths = @(
    "C:\Users\Chase\AppData\Roaming\yuzu",
    "C:\Users\Chase\AppData\LocalLow\RedHook",
    "C:\Users\Chase\AppData\Local\Syncthing",
    "C:\Users\Chase\AppData\Roaming\SyncTrayzor",
    "C:\Program Files\Sunshine\config",
    "C:\Users\Chase\AppData\Local\Sunshine Playnite App Export",
    "C:\Users\Chase\AppData\Roaming\awakened-poe-trade",
    "C:\Program Files (x86)\Steam\userdata\93705779\config"
    # Add more paths if needed
)

# Mainly used for video games
$otherPaths = @(
    "C:\Users\Chase\AppData\Local\Larian Studios"
)

$paths += $otherPaths

function Copy-FilesWithPermissions($source, $destination) {
    Get-ChildItem -Path $source -Recurse | ForEach-Object {
        $destPath = $_.FullName.Replace($source, $destination)
        $destDir = [System.IO.Path]::GetDirectoryName($destPath)
        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory
        }
        Copy-Item -Path $_.FullName -Destination $destPath -Force
        $acl = Get-Acl -Path $_.FullName
        Set-Acl -Path $destPath -AclObject $acl
    }
}


# Iterate through the paths
foreach ($path in $paths) {
    $destination = Join-Path -ChildPath $path.Replace('C:\', '') -Path "E:\Links"
    $sourceExists = Test-Path $path
    $destinationExists = Test-Path $destination

    # Check if the path is not a symbolic link
    $pathIsNotSymLink = $true
    if ($sourceExists) {
        $item = Get-Item $path
        $pathIsNotSymLink = -not ($item.Attributes -match "ReparsePoint")
    }

    if ($sourceExists -and -not $destinationExists) {
        Copy-FilesWithPermissions -source $path -destination $destination
        # Copy-Item -Path $path -Destination $destination -Recurse -Force


        # Remove the existing path recursively
        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop

        # Create a symbolic link
        New-Item -Path $path -ItemType SymbolicLink -Target $destination
    }
    elseif (($sourceExists -and $destinationExists) -and $pathIsNotSymLink) {
        # Remove the existing path recursively
        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop

        # Create a symbolic link
        New-Item -Path $path -ItemType SymbolicLink -Target $destination
    }
    elseif ($destinationExists -and -not $sourceExists) {
        # Create a symbolic link
        New-Item -Path $path -ItemType SymbolicLink -Target $destination
    }
}
