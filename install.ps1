$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$ProgressPreference = 'SilentlyContinue'

# A red line and a vanishing window is useless. Any terminating error that escapes
# the main try/catch still prints the reason and waits before the host is closed.
$script:HasFailed = $false
trap {
    $script:HasFailed = $true
    Write-Host ''
    Write-Host "Installer stopped: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Run the command again with the safe wrapper from the README to keep this window open.' -ForegroundColor Yellow
    if ($Host.Name -eq 'ConsoleHost') { $null = Read-Host 'Press Enter to close' }
    exit 1
}

# === Hardened configuration ===
# Pinned source. The four files are fetched from this exact commit, never from
# the moving "main" branch, so the hashes below always describe what arrives.
# Refreshed together with $expectedHashes in the same commit.
$pinnedCommit = '3c2afc643c71f0dff323849d40a719ea0f6c8ed0'
$rawBase = "https://raw.githubusercontent.com/fem-dev/Prime-OS/$pinnedCommit"

# Pinned SHA-256 of every file this installer copies. Keep in sync with
# install.sh, install-mac.sh and loader.py whenever the sources change.
$expectedHashes = @{
    'loader.py'        = '2A544368C4907D720761722BF2D6F48DEF54FA48C82B3C9DC1298319073B0117'
    'faravahar.png'    = '7A2650C3A71E26E70DEF9E841BB3105756B246C9FBCE64DE719F0B1642FD472E'
    'you.py'           = '870972D63ACC13B13EB2FFE44420C7E01A8366064E1EBF7AC7A6D6859CA22A36'
    'requirements.txt' = 'B4506838C7BE3C862AC0DA2886CDF9DC7DC056F8C25EDF5D47038803AC21AE9A'
}

# A log next to the temp folder, so a closed window still leaves a trace.
$logPath = Join-Path ([System.IO.Path]::GetTempPath()) 'prime-os-install.log'

function Write-Step {
    param([string]$Message)
    Write-Host $Message
    try { Add-Content -Path $logPath -Value ("[{0}] {1}" -f (Get-Date).ToString('u'), $Message) -ErrorAction SilentlyContinue } catch { }
}

function Get-Sha256Hex {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Assert-FileHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Expected
    )
    $expectedLower = $Expected.ToLowerInvariant()
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ((Get-Sha256Hex -Bytes $bytes) -eq $expectedLower) { return }

    # Windows Git may have checked the file out with CRLF line endings
    # (core.autocrlf=true), which changes the SHA-256 without changing the file.
    # Normalise to LF, verify that, and keep the normalised copy on disk.
    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -in '.py', '.txt', '.md', '.sh', '.json') {
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        $normalised = [System.Text.Encoding]::UTF8.GetBytes(($text -replace "`r`n", "`n"))
        if ((Get-Sha256Hex -Bytes $normalised) -eq $expectedLower) {
            [System.IO.File]::WriteAllBytes($Path, $normalised)
            Write-Step "Note: converted $([System.IO.Path]::GetFileName($Path)) from CRLF to LF to match the published SHA-256."
            return
        }
    }

    throw "$([System.IO.Path]::GetFileName($Path)) SHA-256 verification failed. The download was not installed. Hash mismatch detected."
}

function Find-PythonCommand {
    if (Get-Command python -ErrorAction SilentlyContinue) { return 'python' }
    if (Get-Command py -ErrorAction SilentlyContinue) { return 'py' }
    return $null
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$failed = $false

try {
    Write-Step 'Prime-OS installer starting (script version 3.2)...'
    Write-Step "Log file: $logPath"

    $pythonCommand = Find-PythonCommand
    if (-not $pythonCommand) {
        throw 'Python 3 is required. Install Python 3 from python.org and enable "Add python.exe to PATH", then run this command again.'
    }
    $pythonArgs = if ($pythonCommand -eq 'py') { @('-3') } else { @() }

    $scriptDir = Get-Variable -Name PSScriptRoot -ValueOnly -ErrorAction SilentlyContinue
    $localRepo = if ($scriptDir) { Join-Path $scriptDir 'repo' } else { '' }
    if ($localRepo -and (Test-Path (Join-Path $localRepo 'install.ps1'))) {
        Write-Step 'Using the local repository next to this script.'
        $sourceDir = $localRepo
    }
    else {
        Write-Step 'Downloading Prime-OS setup files from GitHub...'
        $sourceDir = Join-Path $temp 'repo'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        foreach ($name in $expectedHashes.Keys) {
            $url = "$rawBase/$name"
            try {
                Invoke-WebRequest -Uri $url -OutFile (Join-Path $sourceDir $name) -UseBasicParsing -TimeoutSec 90
            }
            catch {
                throw "Could not download $name from GitHub. Check your internet connection, then try again. If GitHub is blocked on your network, turn a VPN on and retry, or turn an existing VPN off and retry."
            }
        }
    }

    # === SHA-256 verification of all bundled assets ===
    Write-Step 'Verifying downloaded files...'
    foreach ($name in $expectedHashes.Keys) {
        Assert-FileHash -Path (Join-Path $sourceDir $name) -Expected $expectedHashes[$name]
    }

    $appDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Prime-OS' } else { Join-Path $HOME 'AppData\Local\Prime-OS' }
    New-Item -ItemType Directory -Path $appDir -Force | Out-Null

    foreach ($name in $expectedHashes.Keys) {
        Copy-Item (Join-Path $sourceDir $name) (Join-Path $appDir $name) -Force
    }

    # Optional hardening: never fatal. A locked-down folder must not abort the setup.
    if ($env:OS -eq 'Windows_NT' -and (Get-Command icacls -ErrorAction SilentlyContinue)) {
        try {
            & icacls $appDir /inheritance:r /grant:r "$($env:USERNAME):(OI)(CI)(F)" *> $null
        }
        catch {
            Write-Step "Note: could not tighten folder permissions (not fatal): $($_.Exception.Message)"
        }
    }

    # === Configuration ===
    Write-Host ''
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
    Remove-Variable -Name pass1, pass2, secure1, secure2 -ErrorAction SilentlyContinue

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
    try { (Get-Item $profileFile).Attributes = 'Hidden' } catch { }

    Write-Step "Configuration saved to: $profileFile"

    # Python virtual environment and dependencies (Pillow is needed by loader.py)
    $venvDir = Join-Path $appDir 'venv'
    $venvPython = if ($env:OS -eq 'Windows_NT') { Join-Path $venvDir 'Scripts\python.exe' } else { Join-Path $venvDir 'bin/python' }
    if (-not (Test-Path $venvPython)) {
        Write-Step 'Creating a private Python environment...'
        & $pythonCommand @pythonArgs -m venv $venvDir
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $venvPython)) {
            throw 'Could not create the Python virtual environment. Reinstall Python 3 from python.org with the "venv" component, then try again.'
        }
    }
    # The wizard only needs Pillow. exa-py is for the optional web_search.py
    # helper, so installing it here would add ~20 packages and a long wait.
    Write-Step 'Installing Pillow (the only package the wizard needs)...'
    & $venvPython -m pip install --disable-pip-version-check --no-input --progress-bar off --timeout 30 --retries 2 "Pillow>=10.0,<14"
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not install Pillow. Check your internet connection and try again. If GitHub and PyPI are blocked on your network, connect a VPN and retry, or disconnect the VPN and retry.'
    }

    # The wizard uses Tk for its window. A Python built without Tcl/Tk cannot run it.
    & $venvPython -c "import tkinter" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'This Python installation has no Tk support, which the Prime-OS window needs. Reinstall Python 3 from python.org with the "tcl/tk and IDLE" option enabled, then run this command again.'
    }

    Write-Step 'Starting Prime-OS preview setup. This does not install or replace Windows.'
    & $venvPython (Join-Path $appDir 'loader.py')
    if ($LASTEXITCODE -ne 0) { throw 'Prime-OS setup did not start successfully.' }
}
catch {
    $failed = $true
    Write-Host ''
    Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Details were written to: $logPath" -ForegroundColor Yellow
    try { Add-Content -Path $logPath -Value ("[{0}] FAILED: {1}" -f (Get-Date).ToString('u'), $_.Exception.Message) -ErrorAction SilentlyContinue } catch { }
}
finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    # Keep the window open when the script runs in its own console, and show the
    # real reason instead of closing silently (the old exit 1 closed the window).
    if ($failed -and $Host.Name -eq 'ConsoleHost' -and -not $env:PRIME_OS_NO_PAUSE) {
        Write-Host ''
        Write-Host 'Press Enter to close this window...' -ForegroundColor Gray
        $null = Read-Host
    }
}
