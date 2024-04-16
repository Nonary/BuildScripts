# PowerShell script to move library folders to a new drive

Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class KnownFolders {
        [DllImport("shell32.dll")]
        public static extern int SHSetKnownFolderPath(ref Guid folderId, uint flags, IntPtr token, [MarshalAs(UnmanagedType.LPWStr)] string path);
    }
"@

# Define the new base directory
$NewBaseDir = "D:\"

# Map of library folders to their respective GUIDs
$LibraryFolders = @{
    Documents = 'FDD39AD0-238F-46AF-ADB4-6C85480369C7'
    Pictures  = '33E28130-4E1E-4676-835A-98395C3BC3BB'
    Music     = '4BD8D571-6D19-48D3-BE97-422220080E43'
    Videos    = '18989B1D-99B5-455B-841C-AB7C74E4DDFC'
    Downloads = '374DE290-123F-4565-9164-39C4925E467B'
}

# Create the new base directory if it does not exist
if (-not (Test-Path -Path $NewBaseDir)) {
    New-Item -ItemType Directory -Path $NewBaseDir -Force
}

# Loop through each library folder and set the new path
foreach ($Folder in $LibraryFolders.GetEnumerator()) {
    $NewPath = Join-Path -Path $NewBaseDir -ChildPath $Folder.Name
    # Create the new library folder if it does not exist
    if (-not (Test-Path -Path $NewPath)) {
        New-Item -ItemType Directory -Path $NewPath -Force
    }

    # Set the new library location as the default
    $folderId = [Guid]$Folder.Value
    $result = [KnownFolders]::SHSetKnownFolderPath([ref]$folderId, 0, [IntPtr]::Zero, $NewPath)

    if ($result -ne 0) {
        Write-Warning "Failed to set known folder path for '$($Folder.Name)' (HRESULT: $result)"
    }
}
