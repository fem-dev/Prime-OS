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
    if ($manifest.Hash -ne '171923E0A4B92CC799E6D865BE64B8C438337B5C05731101A512ACAE52A43A2D') {
        throw 'loader.py SHA-256 verification failed. The download was not installed.'
    }
    Copy-Item (Join-Path $temp 'repo/loader.py') $appDir -Force
    Copy-Item (Join-Path $temp 'repo/faravahar.png') $appDir -Force
    $artHash = (Get-FileHash (Join-Path $temp 'repo/you.py') -Algorithm SHA256).Hash
    if ($artHash -ne '3C2E7A85E8AAF1FE5BB3B944E8EFB87E57A0E8B9E5CA39F64F22C5E175339676') {
        throw 'you.py SHA-256 verification failed. The download was not installed.'
    }
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

    Write-Host 'Starting Prime-OS preview setup. This does not install or replace Windows.'
    & $venvPython (Join-Path $appDir 'loader.py')
    if ($LASTEXITCODE -ne 0) { throw 'Prime-OS setup did not start successfully.' }
} finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
