#!/usr/bin/env bash
# Prime-OS — install with one line:
#
#   curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh | sudo bash
#
# Run it from an Arch live session — the official archiso image, or the Prime-OS
# setup image. It installs the few tools the wizard needs, fetches this
# repository, and starts the wizard. From there the wizard asks the questions:
# which disk, which components, which account. Nothing is chosen for you and
# nothing is installed that you did not tick.
#
# Environment:
#   PRIME_OS_REF=main   git ref (branch, tag or commit) to install from
#
# This program is destructive once the wizard runs: it partitions a disk. It
# refuses to run outside a live session, so a normal install is never touched.
set -Eeuo pipefail

REPO="fem-dev/Prime-OS"
REF="${PRIME_OS_REF:-main}"
TARBALL="https://codeload.github.com/${REPO}/tar.gz/${REF}"
API="https://api.github.com/repos/${REPO}/commits/${REF}"
IMAGE_INSTALLER="/usr/local/share/prime-os/prime-os-setup"

# Everything the wizard shells out to: dialog for the screens, pacstrap and
# arch-chroot for the install, sgdisk/wipefs/mkfs for the disk, nmtui for Wi-Fi.
REQUIRED_PACKAGES=(
    dialog
    arch-install-scripts
    gptfdisk
    dosfstools
    e2fsprogs
    btrfs-progs
    util-linux
    networkmanager
)

WORK_DIR=""

say()  { printf 'prime-os: %s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
die()  { printf '\nprime-os: %s\n' "$*" >&2; exit 1; }

cleanup() {
    if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
        rm -rf -- "${WORK_DIR}"
    fi
}
trap cleanup EXIT

# === checks =================================================================
[[ "${EUID}" -eq 0 ]] || die "Run this as root: curl -fsSL https://raw.githubusercontent.com/${REPO}/main/setup.sh | sudo bash"
command -v curl >/dev/null 2>&1 || die "curl is missing from this live session; install it with: pacman -Sy curl"
command -v pacman >/dev/null 2>&1 || die "This is not an Arch system: pacman was not found."

[[ -r /etc/arch-release ]] || die "Prime-OS is installed from an Arch live session (the Arch ISO, or the Prime-OS setup image), not from another distribution."
[[ -d /run/archiso ]] || die "This is not a live session.

Boot the Arch ISO or the Prime-OS setup image, then run this command again.
Refusing to partition the disk of a running system."

if [[ ! -t 0 || ! -t 1 ]]; then
    die "The setup wizard is interactive and needs a console.

Run this command on the machine itself (its first console), or over ssh -t."
fi

# === tools the wizard needs =================================================
step "Checking the tools the setup wizard uses"
if [[ ! -s /etc/pacman.d/gnupg/pubring.gpg ]]; then
    say "initialising the pacman keyring"
    pacman-key --init >/dev/null 2>&1 || die "pacman-key --init failed."
    pacman-key --populate archlinux >/dev/null 2>&1 || die "pacman-key --populate archlinux failed."
fi

if ! pacman -Sy --needed --noconfirm "${REQUIRED_PACKAGES[@]}" >/dev/null; then
    die "Could not install ${REQUIRED_PACKAGES[*]} from the Arch mirrors.

Check the network (wired is automatic; for Wi-Fi run nmtui), then run this
command again."
fi
say "tools ready: ${REQUIRED_PACKAGES[*]}"

# === the setup program ======================================================
# On the Prime-OS setup image the program is already on disk; use that copy
# instead of downloading the same files again.
if [[ -x "${IMAGE_INSTALLER}" ]]; then
    step "Starting the setup wizard (this image ships it)"
    "${IMAGE_INSTALLER}"
    exit 0
fi

step "Downloading ${REPO} (${REF})"
WORK_DIR="$(mktemp -d /tmp/prime-os.XXXXXX)"
chmod 700 "${WORK_DIR}"

curl -fsSL --proto '=https' --tlsv1.2 --max-time 300 "${TARBALL}" \
    -o "${WORK_DIR}/prime-os.tar.gz" 2>/dev/null \
    || die "Could not download ${REPO} from GitHub.

Check the connection and try again; a VPN is the usual fix on filtered networks."

commit="$(curl -fsS --max-time 20 "${API}" 2>/dev/null \
    | sed -n 's/^[[:space:]]*"sha": "\([0-9a-f]\{40\}\)",$/\1/p' | head -n 1)" || commit=""
[[ -n "${commit}" ]] && say "commit ${commit}"

tar -xzf "${WORK_DIR}/prime-os.tar.gz" -C "${WORK_DIR}" \
    || die "The downloaded archive could not be unpacked."

SRC_DIR="$(find "${WORK_DIR}" -maxdepth 1 -mindepth 1 -type d | head -n 1)"
[[ -n "${SRC_DIR}" && -x "${SRC_DIR}/installer/prime-os-setup" ]] \
    || die "The archive does not contain installer/prime-os-setup. The ref '${REF}' is probably not a Prime-OS commit."

# The wizard reads its components and the overlay from these two paths; both are
# the same files build.sh puts on the setup image, straight from the checkout.
export PRIME_OS_COMPONENTS="${SRC_DIR}/components"
export PRIME_OS_OVERLAY="${SRC_DIR}/installer/overlay"

step "Starting the setup wizard"
"${SRC_DIR}/installer/prime-os-setup"
