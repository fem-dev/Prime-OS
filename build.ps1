$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Require-Success([string]$Message) {
    if ($LASTEXITCODE -ne 0) { throw $Message }
}

if (-not (Get-Command docker.exe -ErrorAction SilentlyContinue)) {
    throw 'Docker Desktop is required. Install and start Docker Desktop, then retry.'
}

docker.exe info *> $null
Require-Success 'Docker Desktop is not running. Start it, then retry.'

$repoPath = (Resolve-Path $root).Path.Replace('\', '/')
if ($repoPath -match "'") { throw 'Project paths containing a single quote are not supported by this launcher.' }

$buildCommand = "pacman -Syu --noconfirm archiso && PRIME_OS_BUILD_CONTAINER=1 bash ./build.sh"
docker.exe run --rm --privileged `
    -e PRIME_OS_BUILD_CONTAINER=1 `
    -v "${repoPath}:/work" `
    -w /work `
    archlinux:latest `
    bash -lc $buildCommand
Require-Success 'Prime-OS ISO build failed. Review the Docker build output above.'

$iso = Join-Path $root 'out\os.iso'
if (-not (Test-Path -LiteralPath $iso -PathType Leaf)) {
    throw "Build reported success but the ISO was not found at: $iso"
}
Write-Host "Prime-OS ISO created: $iso"
