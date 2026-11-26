# installer/lib/common.sh — console handling, prompts, shared helpers.
#
# Everything the user sees goes through dialog, so the wizard has exactly one
# look on a bare Linux console (no X, no Wayland, no fonts to install).

BACKTITLE="Prime-OS Setup"
SCREEN_TITLE="Prime-OS"
MNT="/mnt"

init_screen() {
    if ! command -v dialog >/dev/null 2>&1; then
        printf 'dialog is not installed in this live session.\n' >&2
        printf 'This is a bug in the setup image; rebuild it with build.sh.\n' >&2
        exit 1
    fi
    # Plain ASCII frames: a bare console has no guarantee of a font with lines.
    export NCURSES_NO_UTF8_ACS=1
    export TERM="${TERM:-linux}"
    clear
    trap _on_exit EXIT
}

_on_exit() {
    local rc=$?
    clear
    if [[ "${rc}" -ne 0 ]]; then
        printf '\nPrime-OS Setup exited (status %s). Nothing else was changed.\n' "${rc}"
    fi
}

note()  { printf 'prime-os-setup: %s\n' "$*"; }
fail()  { printf 'prime-os-setup: %s\n' "$*" >&2; return 1; }

# dialog exits 1 on Cancel and 255 on Escape; both mean "the user stopped here".
_dialog() { dialog --backtitle "${BACKTITLE}" --title "${SCREEN_TITLE}" "$@"; }

ui_msg() {
    _dialog --msgbox "$1" 0 0
}

ui_info() {
    _dialog --infobox "$1" 0 0
}

ui_yesno() {
    _dialog --yesno "$1" 0 0
}

ui_input() {
    _dialog --stdout --inputbox "$1" 0 0 "${2:-}"
}

ui_password() {
    _dialog --stdout --insecure --passwordbox "$1" 0 0
}

# ui_menu "prompt" tag label tag label ...
ui_menu() {
    local prompt=$1; shift
    _dialog --stdout --nocancel --menu "$prompt" 0 0 12 "$@"
}

# ui_checklist "prompt" tag label state help tag label state help ...
ui_checklist() {
    local prompt=$1; shift
    _dialog --stdout --separate-output --checklist "$prompt" 0 0 14 "$@"
}

ui_text() {
    _dialog --textbox "$1" 0 0
}

die() {
    ui_msg "$1\n\nSetup stops here. The disk has not been changed unless a step above said so."
    exit 1
}

# A dialog that shows the output of the command it is given, and keeps the exit
# status of that command (not of dialog).
ui_program() {
    local title=$1; shift
    local rc
    set +e
    "$@" 2>&1 | _dialog --programbox "${title}" 20 78
    rc=${PIPESTATUS[0]}
    set -e
    return "${rc}"
}

is_uefi() { [[ -d /sys/firmware/efi ]]; }

# True when the live session can reach an Arch mirror.
have_network() {
    curl -fsS --max-time 10 -o /dev/null https://geo.mirror.pkgbuild.com/ 2>/dev/null
}
