$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$ProgressPreference = 'SilentlyContinue'

# === Hardened configuration ===
# Pinned source repository. If GitHub is unreachable from your network, put the
# checkout next to this script in a folder named "repo" and run it again.
$repo = 'https://github.com/fem-dev/Prime-OS.git'

# Pinned SHA-256 of every file this installer copies. Keep in sync with
# install.sh, install-mac.sh and loader.py whenever the sources change.
$expectedHashes = @{
    'loader.py'      = 'FB2EEB35B84A56AFF72AC7A33563F710CD3EDCDAB4CA39971BDC396229D3C319'
    'faravahar.png'  = '7A2650C3A71E26E70DEF9E841BB3105756B246C9FBCE64DE719F0B1642FD472E'
    'you.py'         = '870972D63ACC13B13EB2FFE44420C7E01A8366064E1EBF7AC7A6D6859CA22A36'
    'requirements.txt' = 'B4506838C7BE3C862AC0DA2886CDF9DC7DC056F8C25EDF5D47038803AC21AE9A'
}

function Assert-FileHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Expected
    )
    $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) {
        throw "$([System.IO.Path]::GetFileName($Path)) SHA-256 verification failed. The download was not installed. Hash mismatch detected."
    }
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp -Force | Out-Null

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required. Install Git for Windows, then run this command again.'
    }
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw 'Python 3 is required. Install Python 3 from python.org and enable "Add python.exe to PATH", then run this command again.'
    }

    $scriptDir = Get-Variable -Name PSScriptRoot -ValueOnly -ErrorAction SilentlyContinue
    $localRepo = if ($scriptDir) { Join-Path $scriptDir 'repo' } else { '' }
    if ($localRepo -and (Test-Path (Join-Path $localRepo 'install.ps1'))) {
        Write-Host 'Using the local repository next to this script.' -ForegroundColor Cyan
        $sourceDir = $localRepo
    }
    else {
        Write-Host 'Downloading Prime-OS setup files from GitHub...' -ForegroundColor Cyan
        $sourceDir = Join-Path $temp 'repo'
        git clone --depth 1 $repo $sourceDir
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not download the Prime-OS repository. Check your internet connection, then try again. If GitHub is blocked on your network, connect a VPN and retry, or disconnect the VPN and retry.'
        }
    }

    # === SHA-256 verification of all bundled assets ===
    foreach ($name in $expectedHashes.Keys) {
        Assert-FileHash -Path (Join-Path $sourceDir $name) -Expected $expectedHashes[$name]
    }

    $appDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Prime-OS' } else { Join-Path $HOME 'AppData\Local\Prime-OS' }
    New-Item -ItemType Directory -Path $appDir -Force | Out-Null

    foreach ($name in $expectedHashes.Keys) {
        Copy-Item (Join-Path $sourceDir $name) (Join-Path $appDir $name) -Force
    }

    # Restrictive NTFS permissions: current user only
    icacls $appDir /inheritance:r /grant:r "$($env:USERNAME):(OI)(CI)(F)" 2>$null | Out-Null

    # === Configuration ===
    Write-Host 'Prime-OS Setup: Configuration' -ForegroundColor Cyan
    Write-Host '================================' -ForegroundColor Cyan

    Write-Host 'Enter desired username (3-32 characters, letters, digits, underscores, hyphens):' -ForegroundColor Yellow
    do {
        $userName = Read-Host 'Username'
        if ($userName -notmatch '^[a-zA-Z0-9_-]{3,32}$') {
            Write-Host 'Invalid username. Use 3-32 letters, digits, underscores or hyphens.' -ForegroundColor Red
        }
    } while ($userName -notmatch '^[a-zA-Z0-9_-]{3,32}$')

    Write-Host 'Enter hostname (3-63 characters, letters, digits, dots, hyphens):' -ForegroundColor Yellow
    do {
        $hostName = Read-Host 'Hostname'
        if ($hostName -notmatch '^[a-zA-Z0-9.-]{3,63}$') {
            Write-Host 'Invalid hostname. Use 3-63 letters, digits, dots or hyphens.' -ForegroundColor Red
        }
    } while ($hostName -notmatch '^[a-zA-Z0-9.-]{3,63}$')

    # Hidden password entry: Read-Host -AsSecureString never echoes the input
    Write-Host 'Enter password (minimum 8 characters, must contain a digit and a special character):' -ForegroundColor Yellow
    $passValid = $false
    $pass1 = ''
    while (-not $passValid) {
        $secure1 = Read-Host 'Password' -AsSecureString
        $pass1 = [System.Net.NetworkCredential]::new('', $secure1).Password
        $secure2 = Read-Host 'Confirm Password' -AsSecureString
        $pass2 = [System.Net.NetworkCredential]::new('', $secure2).Password

        if ([string]::IsNullOrEmpty($pass1)) {
            Write-Host 'Password cannot be empty. Try again.' -ForegroundColor Red
            continue
        }
        if ($pass1.Length -lt 8) {
            Write-Host 'Password must be at least 8 characters. Try again.' -ForegroundColor Red
            continue
        }
        if ($pass1 -notmatch '\d') {
            Write-Host 'Password must contain at least one digit. Try again.' -ForegroundColor Red
            continue
        }
        if ($pass1 -notmatch '[^a-zA-Z0-9]') {
            Write-Host 'Password must contain at least one special character. Try again.' -ForegroundColor Red
            continue
        }
        if ($pass1 -ne $pass2) {
            Write-Host 'Passwords do not match. Try again.' -ForegroundColor Red
            continue
        }
        $passValid = $true
    }

    # Hash the password with SHA-256; the plaintext is never written to disk
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $passwordHash = [Convert]::ToBase64String($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($pass1)))
    }
    finally {
        $sha.Dispose()
    }
    Remove-Variable -Name pass1, pass2 -ErrorAction SilentlyContinue

    $configDir = Join-Path $appDir 'profiles'
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    $profileFile = Join-Path $configDir 'user-profile.pssc'

    $configData = @{
        Username      = $userName
        Hostname      = $hostName
        Mode          = 'preview-only; hardware allocation and OS installation are not implemented'
        InstallDate   = (Get-Date).ToString('u')
        ScriptVersion = '3.0-hardened'
        PasswordHash  = $passwordHash
    }

    $configJson = $configData | ConvertTo-Json -Depth 3
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($configJson))
    Set-Content -Path $profileFile -Value $encoded -Encoding Ascii
    Set-Content -Path "$profileFile.readme" -Value 'Prime-OS configuration file. Contains username and hostname. Password hash only. Do not share.' -Encoding Ascii
    Set-ItemProperty -Path $profileFile -Name Attributes -Value 'Hidden,System'
    Set-ItemProperty -Path $appDir -Name Attributes -Value 'Hidden,System'

    Write-Host "Configuration saved to: $profileFile" -ForegroundColor Green

    # Python virtual environment and dependencies (Pillow is needed by loader.py)
    $venvDir = Join-Path $appDir 'venv'
    $venvPython = Join-Path $venvDir 'Scripts\python.exe'
    if (-not (Test-Path $venvPython)) {
        Write-Host 'Creating a private Python environment...' -ForegroundColor Cyan
        python -m venv $venvDir
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the Python virtual environment.' }
    }
    & $venvPython -m pip install --quiet --upgrade pip
    & $venvPython -m pip install --quiet -r (Join-Path $appDir 'requirements.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Could not install the Python dependencies.' }

    Write-Host 'Starting Prime-OS preview setup. This does not install or replace Windows.' -ForegroundColor Cyan
    & $venvPython (Join-Path $appDir 'loader.py')
    if ($LASTEXITCODE -ne 0) { throw 'Prime-OS setup did not start successfully.' }
}
catch {
    Write-Host "Setup failed: $_" -ForegroundColor Red
    exit 1
}
finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
