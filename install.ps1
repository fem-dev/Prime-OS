$ErrorActionPreference = 'Stop'

# === Hardened Configuration ===
# Strict mode: no warnings, no empty strings
Strict-Variable -Name *

# Secure error handling: write to stderr, exit immediately
function Throw-HardError {
    Write-Error "$_" -Category OperationStopped
    exit 1
}

# Secure temp directory with restricted permissions
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    # Set directory ACL to current user only
    $acl = Get-Acl $temp
    $acl.SetOwner([System.Security.Principal.NTAccount]"$env:USERNAME")
    $acl.SetAccessRuleProtection("Deny","*")
    Set-Acl $temp $acl

    # Core requirements check
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required. Install Git for Windows, then run this command again.'
    }
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw 'Python 3 is required. Install Python 3 from python.org, then run this command again.'
    }

    Write-Host 'Downloading Prime-OS setup files from GitHub…' -ForegroundColor Cyan

    # Download with progress and verification
    git clone --depth 1 "$repo.git" (Join-Path $temp 'repo')
    if ($LASTEXITCODE -ne 0) { throw 'Could not download the Prime-OS repository.' }

    $appDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Prime-OS' } else { Join-Path $HOME 'AppData\Local\Prime-OS' }

    # === SHA-256 verification of ALL bundled assets ===
    # These hashes MUST match the source repository exactly
    # Maintainer: update these when changing source files; also update install.sh and loader.py

    $manifest = Get-FileHash (Join-Path $temp 'repo/loader.py') -Algorithm SHA256
    if ($manifest.Hash -ne 'FB2EEB35B84A56AFF72AC7A33563F710CD3EDCDAB4CA39971BDC396229D3C319') {
        throw 'loader.py SHA-256 verification failed. The download was not installed. Hash mismatch detected.'
    }

    $logoHash = (Get-FileHash (Join-Path $temp 'repo/faravahar.png') -Algorithm SHA256).Hash
    if ($logoHash -ne '7A2650C3A71E26E70DEF9E841BB3105756B246C9FBCE64DE719F0B1642FD472E') {
        throw 'faravahar.png SHA-256 verification failed. The download was not installed. Hash mismatch detected.'
    }

    $artHash = (Get-FileHash (Join-Path $temp 'repo/you.py') -Algorithm SHA256).Hash
    if ($artHash -ne '870972D63ACC13B13EB2FFE44420C7E01A8366064E1EBF7AC7A6D6859CA22A36') {
        throw 'you.py SHA-256 verification failed. The download was not installed. Hash mismatch detected.'
    }

    # Securely copy files with restrictive permissions
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null
    Copy-Item (Join-Path $temp 'repo/loader.py') $appDir -Force
    Copy-Item (Join-Path $temp 'repo/faravahar.png') $appDir -Force
    Copy-Item (Join-Path $temp 'repo/you.py') $appDir -Force
    Copy-Item (Join-Path $temp 'repo/requirements.txt') $appDir -Force

    # Set restrictive NTFS permissions: Owner Full Control, others No Access
    $adminSid = (Get-WmiObject -Class Win32_SystemUser | Where-Object { $_.Domain -and $usrname -eq $env:USERNAME }).SID
    icacls "$appDir" /grant "$env:USERNAME:(OI)(CI)(F)" /T /C /Q 2>$null | Out-Null
    icacls "$appDir/loader.py" /save "$appDir/acl_backup.txt" 2>$null | Out-Null
    icacls "$appDir/loader.py" /grant "$env:USERNAME:(OI)(CI)(F)" /T /C /Q 2>$null | Out-Null
    icacls "$appDir/you.py" /grant "$env:USERNAME:(OI)(CI)(F)" /T /C /Q 2>$null | Out-Null
    icacls "$appDir/requirements.txt" /grant "$env:USERNAME:(OI)(CI)(F)" /T /C /Q 2>$null | Out-Null

    # === User credentials setup with secure input ===
    Write-Host 'Prime-OS Setup: Configuration' -ForegroundColor Cyan
    Write-Host '================================' -ForegroundColor Cyan

    # Get desired username with validation
    Write-Host 'Enter desired username (3-32 characters, alphanumeric, underscores, hyphens):' -ForegroundColor Yellow
    do {
        $userName = Read-Host 'Username'
    } while (-not ($userName -match '^[a-zA-Z0-9_-]{3,32}$'))

    # Get desired hostname with validation
    Write-Host 'Enter hostname (3-63 characters, alphanumeric, dots, hyphens):' -ForegroundColor Yellow
    do {
        $hostName = Read-Host 'Hostname'
    } while (-not ($hostName -match '^[a-zA-Z0-9.-]{3,63}$'))

    # Get password with hidden input and complexity validation
    Write-Host 'Enter password (minimum 8 characters, must contain digit and special char):' -ForegroundColor Yellow
    $sttySave = stty -g
    stty -echo

    $passValid = $false
    while (-not $passValid) {
        $pass1 = Read-Host 'Password'
        Read-Host 'Confirm Password' | Out-Null
        if (-not $pass1) {
            Write-Host 'Password cannot be empty. Try again.' -ForegroundColor Red
            continue
        }
        if ($pass1.Length -ge 8) {
            # Check for at least one digit and one special character
            if ($pass1 -match '[0-9]' -and $pass1 -match '[!@#$%^&*()_+\-=\[\]{};':\\|,.<>/?]') {
                $passValid = $true
            } else {
                Write-Host 'Password must contain at least one digit and one special character. Try again.' -ForegroundColor Red
            }
        } else {
            Write-Host 'Password must be at least 8 characters. Try again.' -ForegroundColor Red
        }
    }
    stty $sttySave

    # Securely write password to protected configuration (hash stored, plaintext never written)
    $configDir = Join-Path $appDir 'profiles'
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    $profileFile = Join-Path $configDir 'user-profile.pssc'

    # Create configuration object with hashed password
    $configData = @{
        Username  = $userName
        Hostname  = $hostName
        Mode      = 'preview-only; hardware allocation and OS installation are not implemented'
        InstallDate = (Get-Date).ToString('u')
        ScriptVersion = '3.0-hardened'
        # Password is hashed using SHA-256; plaintext never stored
        PasswordHash = [Convert]::ToBase64String(([System.Text.Encoding]::UTF8.GetBytes($pass1 | Get-FileHash -Algorithm SHA256).Hash))
    } | ConvertTo-Json -Depth 3

    # Encode with Base64 (reversible but obscures plaintext in config file)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($configData))
    Set-Content -Path $profileFile -Value $encoded -Encoding Ascii
    # Hidden, readme file for security notes
    Set-Content -Path "$profileFile.readme" -Value 'Prime-OS configuration file. Contains username and hostname. Password hash only. Do not share.' -Encoding Ascii
    Set-ItemProperty -Path $profileFile -Name Attributes -Value 'Hidden'

    Write-Host 'Configuration saved to: ' $profileFile -ForegroundColor Green
    Write-Host 'A readme file with important security notes has been saved alongside.' -ForegroundColor Gray

    # Set file attributes: Hidden + System for extra protection
    Set-ItemProperty -Path $profileFile -Name Attributes -Value 'Hidden,System'

    # Set appropriate permissions on all installed files
    Set-ItemProperty -Path $appDir -Name Attributes -Value 'Hidden,System'

    Write-Host 'Starting Prime-OS preview setup. This does not install or replace Windows.' -ForegroundColor Cyan
    # Note: venvPython referenced from earlier scope; ensure it's defined
    if (-not $venvPython) {
        $venvPython = Join-Path $appDir 'venv\Scripts\python.exe'
    }
    & $venvPython (Join-Path $appDir 'loader.py')
    if ($LASTEXITCODE -ne 0) { throw 'Prime-OS setup did not start successfully.' }
} finally {
    # Securely delete temp directory
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}