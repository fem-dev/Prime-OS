$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectOnWindows = $root

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'WSL is unavailable. Install WSL2 and Arch Linux first, or build from Arch Linux directly. See README.md.'
}

# Use the Windows project directory as a WSL path only when it is mounted.
$wslPath = (& wsl.exe wslpath -a $projectOnWindows 2>$null | Select-Object -Last 1).Trim()
if ($LASTEXITCODE -ne 0 -or -not $wslPath) {
    throw 'WSL cannot access this project path. Clone the repository inside your Arch WSL home directory and run sudo ./build.sh there.'
}

$escapedPath = $wslPath.Replace("'", "'\''")
& wsl.exe bash -lc "cd '$escapedPath' && sudo ./build.sh"
if ($LASTEXITCODE -ne 0) {
    throw "Prime-OS ISO build failed with exit code $LASTEXITCODE. See README.md for the supported Arch Linux build environment."
}

Write-Host "ISO created at: $(Join-Path $root 'out\os.iso')"
