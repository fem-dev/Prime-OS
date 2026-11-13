$ErrorActionPreference = 'Stop'
$repo = 'https://github.com/fem-dev/Prime-OS'
$appDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Prime-OS' } else { Join-Path $HOME 'AppData\Local\Prime-OS' }
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp | Out-Null

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required. Install Git for Windows, then run this command again.'
    }
    $python = Get-Command py -ErrorAction SilentlyContinue
    if ($python) {
        $pythonCommand = 'py'
        $pythonArgs = @('-3')
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonCommand = 'python'
        $pythonArgs = @()
    } else {
        throw 'Python 3 is required. Install Python 3 from python.org, then run this command again.'
    }

    Write-Host 'Downloading Prime-OS setup files from GitHub…'
    git clone --depth 1 "$repo.git" (Join-Path $temp 'repo')
    if ($LASTEXITCODE -ne 0) { throw 'Could not download the Prime-OS repository.' }

    New-Item -ItemType Directory -Force -Path $appDir | Out-Null
    $manifest = Get-FileHash (Join-Path $temp 'repo/loader.py') -Algorithm SHA256
    if ($manifest.Hash -ne 'FB2EEB35B84A56AFF72AC7A33563F710CD3EDCDAB4CA39971BDC396229D3C319') {
        throw 'loader.py SHA-256 verification failed. The download was not installed.'
    }
    $logoHash = (Get-FileHash (Join-Path $temp 'repo/faravahar.png') -Algorithm SHA256).Hash
    if ($logoHash -ne '7A2650C3A71E26E70DEF9E841BB3105756B246C9FBCE64DE719F0B1642FD472E') {
        throw 'faravahar.png SHA-256 verification failed. The download was not installed.'
    }
    $artHash = (Get-FileHash (Join-Path $temp 'repo/you.py') -Algorithm SHA256).Hash
    if ($artHash -ne '870972D63ACC13B13EB2FFE44420C7E01A8366064E1EBF7AC7A6D6859CA22A36') {
        throw 'you.py SHA-256 verification failed. The download was not installed.'
    }
    Copy-Item (Join-Path $temp 'repo/loader.py') $appDir -Force
    Copy-Item (Join-Path $temp 'repo/faravahar.png') $appDir -Force
    Copy-Item (Join-Path $temp 'repo/you.py') $appDir -Force
    Copy-Item (Join-Path $temp 'repo/requirements.txt') $appDir -Force

    $venvDirectory = Join-Path $appDir 'venv'
    $venvPython = Join-Path $venvDirectory 'Scripts/python.exe'
    if (-not (Test-Path $venvPython)) {
        & $pythonCommand @pythonArgs -m venv $venvDirectory
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the Python virtual environment.' }
    }
    & $venvPython -c 'import tkinter' *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Python tkinter is required. Reinstall Python 3 from python.org and enable the Tcl/Tk feature.' }

    & $venvPython -m pip install --disable-pip-version-check -r (Join-Path $appDir 'requirements.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Could not install the Prime-OS setup dependencies.' }

    & $venvPython (Join-Path $appDir 'loader.py') --check *> $null
    if ($LASTEXITCODE -ne 0) { throw 'The Prime-OS launcher failed its self check.' }

    Write-Host 'Starting Prime-OS preview setup. This does not install or replace Windows.'
    & $venvPython (Join-Path $appDir 'loader.py')
    if ($LASTEXITCODE -ne 0) { throw 'Prime-OS setup did not start successfully.' }
} finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
