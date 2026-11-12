#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SOURCE="${ROOT}/profile"
PROFILE_WORK="${ROOT}/.build/profile"
WORK_DIR="${ROOT}/.build/work"
OUT_DIR="${ROOT}/out"

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Linux ]] || fail "Build the ISO on native Arch Linux (or a compatible Arch Linux VM), not directly on Windows/macOS."
[[ -r /etc/os-release ]] || fail "Cannot identify the Linux distribution."
. /etc/os-release
[[ "${ID:-}" == arch ]] || fail "The ISO builder currently requires Arch Linux. See README.md for setup."
[[ "${EUID}" -eq 0 ]] || fail "Run with sudo: sudo ./build.sh"
command -v mkarchiso >/dev/null || fail "Install the archiso package first: sudo pacman -S --needed archiso"
[[ -d /usr/share/archiso/configs/releng ]] || fail "The Arch Linux releng profile is missing; reinstall archiso."

rm -rf -- "${PROFILE_WORK}"
mkdir -p -- "${PROFILE_WORK}" "${WORK_DIR}" "${OUT_DIR}"
cp -a /usr/share/archiso/configs/releng/. "${PROFILE_WORK}/"
cp -a "${PROFILE_SOURCE}/airootfs/." "${PROFILE_WORK}/airootfs/"
cat /usr/share/archiso/configs/releng/packages.x86_64 "${PROFILE_SOURCE}/packages.x86_64" \
    | awk 'NF && !seen[$0]++' > "${PROFILE_WORK}/packages.x86_64"
chmod 0755 "${PROFILE_WORK}/airootfs/root/.automated_script.sh"
chmod 0755 "${PROFILE_WORK}/airootfs/usr/local/bin/prime-os-live-setup"

# Steam is in Arch's multilib repository; enable it only in this disposable build profile.
PACMAN_CONF="${PROFILE_WORK}/pacman.conf"
if grep -q '^#\[multilib\]' "${PACMAN_CONF}"; then
    sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' "${PACMAN_CONF}"
elif ! grep -q '^\[multilib\]' "${PACMAN_CONF}"; then
    fail "Could not find the multilib section in the Arch releng pacman.conf"
fi

PROFILE_DEF="${PROFILE_WORK}/profiledef.sh"
sed -i \
    -e 's|^iso_name=.*|iso_name="prime-os"|' \
    -e 's|^iso_label=.*|iso_label="PRIME_OS_$(date +%Y%m)"|' \
    -e 's|^iso_publisher=.*|iso_publisher="Prime-OS <https://github.com/fem-dev/Prime-OS>"|' \
    -e 's|^iso_application=.*|iso_application="Prime-OS Gaming Live Environment"|' \
    "${PROFILE_DEF}"

printf 'Building the Prime-OS live ISO. This downloads packages and may take a while.\n'
mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_WORK}"

ISO="$(find "${OUT_DIR}" -maxdepth 1 -type f -name 'prime-os-*-x86_64.iso' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
[[ -n "${ISO}" && -f "${ISO}" ]] || fail "mkarchiso finished but no Prime-OS ISO was found in ${OUT_DIR}"
if [[ "${ISO}" != "${OUT_DIR}/os.iso" ]]; then
    mv -f -- "${ISO}" "${OUT_DIR}/os.iso"
fi

printf '\nBuild complete: %s\n' "${OUT_DIR}/os.iso"
printf 'Test it in a virtual machine before writing it to a USB drive.\n'
