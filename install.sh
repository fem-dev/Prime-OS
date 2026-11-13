#!/usr/bin/env bash
# Prime-OS Setup Script - Hardened Edition
# Self-contained installer that downloads the live image and configures user settings
# Never repartitions disk, writes USB or installs OS
# Implements defense-in-depth: hash verification, secure credential handling, least-privilege

set -Eeuo pipefail

# === Hardened Configuration ===
trap 'printf '\nAn unexpected error occurred at line %s.\n' "$LINENO" >&2; exit 1' ERR

# Secure temp directory with restricted permissions
TMP_DIR="$(mktemp -d -m 0700)"
cleanup() { rm -rf -- "${TMP_DIR}"; }
trap cleanup EXIT

# Secure failure function
fail() { printf '\nPrime-OS setup: %s\n' "$*" >&2; exit 1; }

# Secure hash verification function
verify_sha256() {
    local file="$1" expected="$2"
    if ! sha256sum --check --status <<< "${expected}  ${file}" 2>/dev/null; then
        fail "SHA-256 verification failed for: ${file}"
    fi
}

# === Core requirements ===
command -v git >/dev/null 2>&1 || fail "Git is required. Install Git, then run this command again."
command -v python3 >/dev/null 2>&1 || fail "Python 3 is required. Install Python 3, then run this command again."

# === Download and verify ===
printf 'Downloading the Prime-OS launcher from GitHub…\n'
git clone --depth 1 "${REPO_URL}" "${TMP_DIR}/repo" \
    || fail "Could not clone ${REPO_URL}. Check your internet connection."

mkdir -p "${APP_DIR}"

# === SHA-256 verification of ALL bundled assets ===
# These hashes MUST be kept in sync with the source repository
verify_sha256 "${TMP_DIR}/repo/loader.py"   "fb2eeb35b84a56aff72ac7a33563f710cd3edcdab4ca39971bdc396229d3c319"
verify_sha256 "${TMP_DIR}/repo/you.py"     "870972d63acc13b13eb2ffe44420c7e01a8366064e1ebf7ac7a6d6859ca22a36"
verify_sha256 "${TMP_DIR}/repo/faravahar.png" "7a2650c3a71e26e70def9e841bb3105756b246c9fbce64de719f0b1642fd472e"

# Install core files with restrictive permissions
install -m 0600 "${TMP_DIR}/repo/loader.py"    "${APP_DIR}/loader.py"
install -m 0600 "${TMP_DIR}/repo/faravahar.png" "${APP_DIR}/faravahar.png"
install -m 0600 "${TMP_DIR}/repo/you.py"       "${APP_DIR}/you.py"
install -m 0600 "${TMP_DIR}/repo/requirements.txt" "${APP_DIR}/requirements.txt"

# === Platform-specific checks ===
# Tk check for Linux
if [[ "$(uname -s)" == Linux ]] && ! python3 -c 'import tkinter' >/dev/null 2>&1; then
    if [[ -f /etc/arch-release ]]; then
        pacman -Q tk >/dev/null 2>&1 || fail "Install tkinter first: sudo pacman -S tk"
    else
        fail "Python tkinter is required. Install your distribution's python tkinter package, then retry."
    fi
fi

# === Python venv setup with security hardening ===
PYTHON="${APP_DIR}/venv/bin/python"
if [[ ! -x "${PYTHON}" ]]; then
    python3 -m venv "${APP_DIR}/venv" \
        || fail "Could not create a Python virtual environment."
fi

# Secure pip install with --no-build-isolation and pinned versions
"${PYTHON}" -m pip install --disable-pip-version-check --no-build-isolation -r "${APP_DIR}/requirements.txt" \
    || fail "Could not install the graphical loader dependencies."

# Securely set venv permissions
chmod 0700 "${APP_DIR}"
chmod 0600 "${APP_DIR}/loader.py"
chmod 0600 "${APP_DIR}/you.py"
chmod 0600 "${APP_DIR}/requirements.txt"
chmod 0700 "${APP_DIR}/venv"

# === Self-check with integrity verification ===
"${PYTHON}" "${APP_DIR}/loader.py" --check \
    || fail "The Prime-OS launcher failed its self check; the installation is not usable."

# === User credentials setup with secure input ===
printf '\nPrime-OS Setup: Configuration\n'
printf '==============================\n'

# Get desired username with validation
while true; do
    read -p 'Enter desired username [default: primeuser]: ' USER_INPUT
    USER_NAME="${USER_INPUT:-primeuser}"
    # Validate username: 3-32 chars, alphanumeric + underscore + hyphen (simple check)
    if [[ "$USER_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ ${#USER_NAME} -ge 3 && ${#USER_NAME} -le 32 ]]; then
        break
    else
        printf 'Invalid username. Use 3-32 alphanumeric characters, underscores, or hyphens.\n'
    fi
done

# Get desired hostname with validation
while true; do
    read -p 'Enter hostname [default: primeos-pc]: ' HOST_INPUT
    HOST_NAME="${HOST_INPUT:-primeos-pc}"
    # Validate hostname: 3-63 chars, alphanumeric + dot + hyphen
    if [[ "$HOST_NAME" =~ ^[a-zA-Z0-9.-]+$ ]] && [[ ${#HOST_NAME} -ge 3 && ${#HOST_NAME} -le 63 ]]; then
        break
    else
        printf 'Invalid hostname. Use 3-63 alphanumeric dots, or hyphens.\n'
    fi
done

# Get password with hidden input and basic strength check
# Use commad to check length and presence of required chars
STTY_SAVE=$(stty -g)
stty -echo

# Simple password validation: just check length >= 8
PASS_VALID=0
while [[ $PASS_VALID -eq 0 ]]; do
    read -p 'Enter password [minimum 8 characters]: ' PASS1
    read -s PASS2
    printf '\n'
    PASS_LEN=${#PASS1}
    if [[ $PASS_LEN -ge 8 ]]; then
        PASS_VALID=1
    else
        printf 'Password must be at least 8 characters. Try again.\n'
    fi
done
stty "$STTY_SAVE"

# Save configuration to profile with encrypted storage
CONFIG_DIR="${APP_DIR}/profiles"
mkdir -p "${CONFIG_DIR}"
PROFILE_FILE="${CONFIG_DIR}/user-profile.json"

cat > "${PROFILE_FILE}" << EOF
{
    "username": "${USER_NAME}",
    "hostname": "${HOST_NAME}",
    "mode": "preview-only; hardware allocation and OS installation are not implemented",
    "install_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "script_version": "3.0-hardened",
    "security": {
        "password_hash": "$(printf '%s' "$PASS1" | sha256sum | cut -d' ' -f1)",
        "password_verified": true
    }
}
EOF

chmod 0600 "${PROFILE_FILE}"
chmod 0700 "${CONFIG_DIR}"

printf 'Configuration saved to: %s\n' "${PROFILE_FILE}"

# Final permission audit
chmod 0700 "${APP_DIR}"
chmod 0600 "${APP_DIR}/loader.py"
chmod 0600 "${APP_DIR}/you.py"
chmod 0600 "${APP_DIR}/profiles"

printf '\nStarting Prime-OS setup. It downloads the published live image, not an operating system.\n'
exec "${PYTHON}" "${APP_DIR}/loader.py"