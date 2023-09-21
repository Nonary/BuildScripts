# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Git, MinGW, MSYS2, and common Pacman packages
choco install -y git msys2 github-desktop nodejs cmake
& C:\tools\msys64\usr\bin\pacman.exe -Syyu --noconfirm
& C:\tools\msys64\usr\bin\pacman.exe -S --needed --noconfirm base-devel cmake diffutils gcc git make mingw-w64-x86_64-binutils mingw-w64-x86_64-boost mingw-w64-x86_64-cmake mingw-w64-x86_64-curl mingw-w64-x86_64-libmfx mingw-w64-x86_64-openssl mingw-w64-x86_64-opus mingw-w64-x86_64-toolchain



$paths = @(
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin",
    "C:\tools\msys64\usr\bin"
)

foreach ($dir in $paths) {
    if (![Environment]::GetEnvironmentVariable("PATH", "Machine").Contains($dir)) {
        $newPath = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + $dir
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
        Write-Host "Added $dir to system PATH."
    } else {
        Write-Host "$dir is already in system PATH."
    }
}

[System.Environment]::SetEnvironmentVariable("CMAKE_C_COMPILER", "C:\tools\msys64\mingw64\bin\gcc.exe", "Machine")
[System.Environment]::SetEnvironmentVariable("CMAKE_CXX_COMPILER", "C:\tools\msys64\mingw64\bin\g++.exe", "Machine")
