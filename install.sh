#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/fem-dev/Prime-OS.git"
APP_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/prime-os"
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf -- "${TMP_DIR}"; }
trap cleanup EXIT

fail() { printf '\nPrime-OS setup: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || fail "Git is required. Install Git, then run this command again."
command -v python3 >/dev/null 2>&1 || fail "Python 3 is required. Install Python 3, then run this command again."

printf 'Downloading the Prime-OS launcher from GitHub…\n'
git clone --depth 1 "${REPO_URL}" "${TMP_DIR}/repo" \
    || fail "Could not clone ${REPO_URL}. Check your internet connection."

mkdir -p "${APP_DIR}"
printf '%s  %s\n' \
    "7c7c55dab38ec33cc4ea1217447340c947ca316226fd605dd15cf9cd11511b18" \
    "${TMP_DIR}/repo/loader.py" | sha256sum --check --status \
    || fail "loader.py SHA-256 verification failed. The download was not installed."
printf '%s  %s\n' \
    "b1cf786a7c6781ea6093dc829b7d56d08b424d34c23caea3b2427101ae09eb86" \
    "${TMP_DIR}/repo/you.py" | sha256sum --check --status \
    || fail "you.py SHA-256 verification failed. The download was not installed."
install -m 0644 "${TMP_DIR}/repo/loader.py" "${APP_DIR}/loader.py"
printf '%s  %s\n' \
    "7a2650c3a71e26e70def9e841bb3105756b246c9fbce64de719f0b1642fd472e" \
    "${TMP_DIR}/repo/faravahar.png" | sha256sum --check --status \
    || fail "Faravahar image SHA-256 verification failed. The download was not installed."
install -m 0644 "${TMP_DIR}/repo/faravahar.png" "${APP_DIR}/faravahar.png"
install -m 0644 "${TMP_DIR}/repo/you.py" "${APP_DIR}/you.py"
install -m 0644 "${TMP_DIR}/repo/requirements.txt" "${APP_DIR}/requirements.txt"

if [[ "$(uname -s)" == Linux ]] && ! python3 -c 'import tkinter' >/dev/null 2>&1; then
    if [[ -f /etc/arch-release ]]; then
        command -v pacman >/dev/null 2>&1 || fail "Install tkinter first: sudo pacman -S tk"
        pacman -Q tk >/dev/null 2>&1 || fail "Install tkinter first: sudo pacman -S tk"
    else
        fail "Python tkinter is required. Install your distribution's python tkinter package, then retry."
    fi
fi

PYTHON="${APP_DIR}/venv/bin/python"
if [[ ! -x "${PYTHON}" ]]; then
    python3 -m venv "${APP_DIR}/venv" \
        || fail "Could not create a Python virtual environment. On Arch Linux install python and python-pip."
fi
"${PYTHON}" -m pip install --disable-pip-version-check -r "${APP_DIR}/requirements.txt" \
    || fail "Could not install the graphical loader dependencies."

printf '\nStarting Prime-OS setup. This downloads code and a logo, not an operating system.\n'
exec "${PYTHON}" "${APP_DIR}/loader.py"
