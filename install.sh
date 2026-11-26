#!/usr/bin/env bash
# Prime-OS setup for Linux and macOS.
#
# Downloads the launcher, verifies every file against its pinned SHA-256, sets up
# a private Python environment and starts the wizard, which downloads the live
# image from the source you pick. It never repartitions a disk, writes a USB
# drive or installs an operating system.

set -Eeuo pipefail

REPO_RAW="https://raw.githubusercontent.com/fem-dev/Prime-OS"
# The launcher files are fetched from this exact commit, never from the moving
# "main" branch, so the SHA-256 values below always describe what arrives.
PINNED_COMMIT="76b1acff08b610fc73a69d1a625309933fc590b6"
APP_DIR="${PRIME_OS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/prime-os}"

# The launcher hash is refreshed with every loader.py change; you.py and the
# logo are pinned artwork that changes only when the artwork changes.
LOADER_SHA256="7c75272073714880e8a9afca250b782de3136259ddfc7341ecca3186a1a03ca5"
ART_SHA256="870972d63acc13b13eb2ffe44420c7e01a8366064e1ebf7ac7a6d6859ca22a36"
LOGO_SHA256="7a2650c3a71e26e70def9e841bb3105756b246c9fbce64de719f0b1642fd472e"
REQUIREMENTS_SHA256="b4506838c7be3c862ac0da2886cdf9dc7dc056f8c25edf5d47038803ac21ae9a"

# === presentation ===========================================================
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
    GOLD=$'\033[33m'; PURPLE=$'\033[35m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
    BOLD=""; DIM=""; RED=""; GREEN=""; GOLD=""; PURPLE=""; CYAN=""; RESET=""
fi

STEP_TOTAL=6
STEP=0
step() {
    STEP=$((STEP + 1))
    printf '\n%s[%d/%d]%s %s%s%s\n' "$PURPLE" "$STEP" "$STEP_TOTAL" "$RESET" "$BOLD" "$1" "$RESET"
}
ok()   { printf '%s  ✓%s %s\n' "$GREEN" "$RESET" "$1"; }
info() { printf '%s  ·%s %s\n' "$DIM" "$RESET" "$1"; }
warn() { printf '%s  !%s %s\n' "$GOLD" "$RESET" "$1"; }
fail() {
    printf '\n%s✗ Prime-OS setup stopped:%s %s\n' "$RED$BOLD" "$RESET" "$*" >&2
    printf '%s  Nothing was installed. Fix the problem above and run the command again.%s\n' "$DIM" "$RESET" >&2
    exit 1
}

# An animated spinner keeps the long clone and pip steps from looking frozen.
spin() {
    local pid=$1 label=$2 frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' index=0
    if [ ! -t 1 ]; then
        wait "$pid" || return $?
        return 0
    fi
    while kill -0 "$pid" 2>/dev/null; do
        index=$(( (index + 1) % ${#frames} ))
        printf '\r%s  %s%s %s…' "$CYAN" "${frames:$index:1}" "$RESET" "$label"
        sleep 0.12
    done
    printf '\r\033[K'
    wait "$pid"
}

banner() {
    printf '%s\n' "${PURPLE}${BOLD}  ╭──────────────────────────────────────╮${RESET}"
    printf '%s\n' "${PURPLE}${BOLD}  │        PRIME-OS  ·  SETUP            │${RESET}"
    printf '%s\n' "${PURPLE}${BOLD}  ╰──────────────────────────────────────╯${RESET}"
    printf '%s\n' "${DIM}  Preview release. This never installs over your OS.${RESET}"
}

trap 'printf "\n%sAn unexpected error occurred at line %s.%s\n" "$RED" "$LINENO" "$RESET" >&2' ERR

TMP_DIR="$(mktemp -d -t prime-os.XXXXXX)"
chmod 700 "$TMP_DIR"
cleanup() { rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT

# === hash verification ======================================================
sha256_of() { sha256sum -- "$1" 2>/dev/null | cut -d' ' -f1; }

verify_sha256() {
    local file="$1" expected="$2" name
    name="$(basename "$file")"
    if [ "$(sha256_of "$file")" = "$expected" ]; then
        ok "$name verified"
        return 0
    fi
    # A checkout made with core.autocrlf=true has CRLF line endings, which
    # changes the SHA-256 without changing the file. Normalise to LF and retry.
    local normalised="${file}.lf"
    if sed 's/\r$//' "$file" > "$normalised" 2>/dev/null && [ "$(sha256_of "$normalised")" = "$expected" ]; then
        mv "$normalised" "$file"
        ok "$name verified (converted CRLF → LF)"
        return 0
    fi
    rm -f "$normalised"
    fail "SHA-256 mismatch for $name. The download is not trustworthy; try again, or ask on GitHub issues."
}

# === prerequisites ==========================================================
banner
step "Checking prerequisites"
command -v curl >/dev/null 2>&1 || fail "curl is required. Install it (Debian/Ubuntu: sudo apt install curl), then run this command again."
command -v python3 >/dev/null 2>&1 || fail "python3 is required. Install it, then run this command again."
ok "curl and python3 are available"

# === download ===============================================================
step "Downloading the Prime-OS launcher"
info "from github.com/fem-dev/Prime-OS (pinned commit)"
mkdir -p "${TMP_DIR}/repo"
for file in loader.py you.py faravahar.png requirements.txt; do
    curl -fsSL --proto '=https' --tlsv1.2 --max-time 120 \
        "${REPO_RAW}/${PINNED_COMMIT}/${file}" -o "${TMP_DIR}/repo/${file}" 2>/dev/null \
        || fail "Could not download ${file} from GitHub. Check your internet connection, then try again. If GitHub is blocked on your network, turn a VPN on and retry, or turn an existing VPN off and retry."
    ok "${file} downloaded"
done

step "Verifying the downloaded files"
verify_sha256 "${TMP_DIR}/repo/loader.py"     "$LOADER_SHA256"
verify_sha256 "${TMP_DIR}/repo/you.py"        "$ART_SHA256"
verify_sha256 "${TMP_DIR}/repo/faravahar.png" "$LOGO_SHA256"
verify_sha256 "${TMP_DIR}/repo/requirements.txt" "$REQUIREMENTS_SHA256"

# === install files ==========================================================
step "Installing into ${APP_DIR}"
mkdir -p "$APP_DIR"
install -m 0600 "${TMP_DIR}/repo/loader.py"        "${APP_DIR}/loader.py"
install -m 0600 "${TMP_DIR}/repo/faravahar.png"    "${APP_DIR}/faravahar.png"
install -m 0600 "${TMP_DIR}/repo/you.py"           "${APP_DIR}/you.py"
install -m 0600 "${TMP_DIR}/repo/requirements.txt" "${APP_DIR}/requirements.txt"
chmod 0700 "$APP_DIR"
ok "launcher and artwork installed"

# === python environment =====================================================
step "Preparing the Python environment"
PYTHON="${APP_DIR}/venv/bin/python"
if [ ! -x "$PYTHON" ]; then
    python3 -m venv "${APP_DIR}/venv" &
    spin $! "creating the virtual environment"
    [ -x "$PYTHON" ] || fail "Could not create a Python virtual environment. Install the python3-venv package and retry."
fi
ok "virtual environment ready"

python3 -c 'import tkinter' >/dev/null 2>&1 || {
    if [ -f /etc/arch-release ]; then
        warn "Tk is missing; install it with: sudo pacman -S tk"
    else
        warn "Python Tk is missing (Debian/Ubuntu: sudo apt install python3-tk)"
    fi
    fail "The Prime-OS window needs Tk. Install it and run this command again."
}

# The wizard only needs Pillow; exa-py belongs to the optional web_search.py helper.
"$PYTHON" -m pip install --quiet --disable-pip-version-check --no-input \
    --progress-bar off --timeout 30 --retries 2 "Pillow>=10.0,<14" &
spin $! "installing Pillow"
ok "Pillow installed"

"$PYTHON" "${APP_DIR}/loader.py" --check >/dev/null \
    || fail "The launcher failed its self check. Reinstall Python with Tk and try again."
ok "self check passed"

# === profile ================================================================
step "Saving your profile"
printf '%s\n' "${BOLD}Username${RESET} ${DIM}(3-32 characters: letters, digits, _ or -)${RESET}"
USER_NAME=""
while [ -z "$USER_NAME" ]; do
    printf '  username [%sprimeuser%s]: ' "$DIM" "$RESET"
    read -r REPLY || true
    candidate="${REPLY:-primeuser}"
    if [[ "$candidate" =~ ^[a-zA-Z0-9_-]{3,32}$ ]]; then
        USER_NAME="$candidate"
    else
        warn "Invalid username, try again."
    fi
done

printf '%s\n' "${BOLD}Hostname${RESET} ${DIM}(3-63 characters: letters, digits, . or -)${RESET}"
HOST_NAME=""
while [ -z "$HOST_NAME" ]; do
    printf '  hostname [%sprimeos-pc%s]: ' "$DIM" "$RESET"
    read -r REPLY || true
    candidate="${REPLY:-primeos-pc}"
    if [[ "$candidate" =~ ^[a-zA-Z0-9.-]{3,63}$ ]]; then
        HOST_NAME="$candidate"
    else
        warn "Invalid hostname, try again."
    fi
done

printf '%s\n' "${BOLD}Password${RESET} ${DIM}(at least 8 characters, one digit and one special character)${RESET}"
PASS1=""
while :; do
    printf '  password: '
    IFS= read -rs PASS1 || true
    printf '\n  confirm : '
    IFS= read -rs PASS2 || true
    printf '\n'
    if [ "${#PASS1}" -lt 8 ]; then
        warn "Too short — at least 8 characters."
    elif ! [[ "$PASS1" =~ [0-9] ]]; then
        warn "Add at least one digit."
    elif ! [[ "$PASS1" =~ [^a-zA-Z0-9] ]]; then
        warn "Add at least one special character."
    elif [ "$PASS1" != "$PASS2" ]; then
        warn "The two passwords do not match."
    else
        break
    fi
done

CONFIG_DIR="${APP_DIR}/profiles"
mkdir -p "$CONFIG_DIR"
PROFILE_FILE="${CONFIG_DIR}/user-profile.json"
PASSWORD_HASH="$(printf '%s' "$PASS1" | sha256sum | cut -d' ' -f1)"
unset PASS1 PASS2

cat > "$PROFILE_FILE" << EOF
{
    "username": "${USER_NAME}",
    "hostname": "${HOST_NAME}",
    "mode": "preview-only; hardware allocation and OS installation are not implemented",
    "install_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "script_version": "3.2",
    "security": {
        "password_hash": "${PASSWORD_HASH}",
        "password_verified": true
    }
}
EOF
chmod 0600 "$PROFILE_FILE"
chmod 0700 "$CONFIG_DIR"
ok "profile saved to $PROFILE_FILE"

# === launch =================================================================
step "Starting the wizard"
printf '%s\n' "${DIM}  Pick a download source with ↑ ↓ (or 1–3) and press Enter.${RESET}"
printf '%s\n' "${DIM}  Echoing the setup window; close it when you are done.${RESET}\n"
exec "$PYTHON" "${APP_DIR}/loader.py"
