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
    Copy-Item (Join-Path $temp 'repo/loader.py') $appDir -Force
    Copy-Item (Join-Path $temp 'repo/faravahar.png') $appDir -Force
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
