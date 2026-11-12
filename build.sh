#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SOURCE="${ROOT}/profile"
BUILD_DIR="${ROOT}/.build"
PROFILE_WORK="${BUILD_DIR}/profile"
WORK_DIR="${BUILD_DIR}/work"
OUT_DIR="${ROOT}/out"

fail() {
    printf 'Prime-OS build: %s\n' "$*" >&2
    exit 1
}

# This script is intended to run as root only inside the disposable Arch container.
[[ "$(uname -s)" == Linux ]] || fail "Run this build in the Arch Linux Docker container from README.md."
[[ -r /etc/os-release ]] || fail "Cannot identify the Linux distribution."
# shellcheck source=/etc/os-release
. /etc/os-release
[[ "${ID:-}" == arch ]] || fail "The ISO builder requires Arch Linux inside the build container."
[[ "${EUID}" -eq 0 ]] || fail "The Arch build container must run as root. See README.md."
[[ "${PRIME_OS_BUILD_CONTAINER:-}" == 1 ]] || fail "Refusing to build outside the explicitly marked container."
command -v mkarchiso >/dev/null 2>&1 || fail "Install archiso in the container before building."
[[ -d /usr/share/archiso/configs/releng ]] || fail "Arch's releng profile is missing; reinstall archiso."

# Do not let generated paths redirect cleanup or ISO output outside this checkout.
for path in "${BUILD_DIR}" "${PROFILE_WORK}" "${WORK_DIR}" "${OUT_DIR}"; do
    [[ ! -L "${path}" ]] || fail "Refusing to use a symlink as a build/output directory: ${path}"
done
[[ -d "${PROFILE_SOURCE}/airootfs" ]] || fail "Prime-OS profile files are missing."
[[ -f "${PROFILE_SOURCE}/packages.x86_64" ]] || fail "Prime-OS package list is missing."

mkdir -p -- "${BUILD_DIR}" "${OUT_DIR}"
rm -rf -- "${PROFILE_WORK}"
mkdir -p -- "${PROFILE_WORK}" "${WORK_DIR}"
cp -a /usr/share/archiso/configs/releng/. "${PROFILE_WORK}/"
cp -a "${PROFILE_SOURCE}/airootfs/." "${PROFILE_WORK}/airootfs/"

cat /usr/share/archiso/configs/releng/packages.x86_64 \
    "${PROFILE_SOURCE}/packages.x86_64" \
    | awk 'NF && !seen[$0]++' > "${PROFILE_WORK}/packages.x86_64"
chmod 0755 \
    "${PROFILE_WORK}/airootfs/root/.automated_script.sh" \
    "${PROFILE_WORK}/airootfs/usr/local/bin/prime-os-live-setup"

# Steam is in multilib; enable it only in this temporary build profile.
PACMAN_CONF="${PROFILE_WORK}/pacman.conf"
if grep -q '^#\[multilib\]' "${PACMAN_CONF}"; then
    sed -i \
        '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' \
        "${PACMAN_CONF}"
elif ! grep -q '^\[multilib\]' "${PACMAN_CONF}"; then
    fail "Could not find the multilib section in Arch's pacman.conf."
fi

PROFILE_DEF="${PROFILE_WORK}/profiledef.sh"
sed -i \
    -e 's|^iso_name=.*|iso_name="prime-os"|' \
    -e 's|^iso_label=.*|iso_label="PRIME_OS_$(date +%Y%m)"|' \
    -e 's|^iso_publisher=.*|iso_publisher="Prime-OS <https://github.com/fem-dev/Prime-OS>"|' \
    -e 's|^iso_application=.*|iso_application="Prime-OS Gaming Live Environment"|' \
    "${PROFILE_DEF}"

printf 'Building Prime-OS ISO (this downloads Arch packages)…\n'
mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_WORK}"

ISO="$(find "${OUT_DIR}" -maxdepth 1 -type f -name 'prime-os-*-x86_64.iso' \
    -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
[[ -n "${ISO}" && -f "${ISO}" ]] || fail "Build completed without producing a Prime-OS ISO."

if [[ "${ISO}" != "${OUT_DIR}/os.iso" ]]; then
    mv -f -- "${ISO}" "${OUT_DIR}/os.iso"
fi

printf '\nBuild complete: %s\n' "${OUT_DIR}/os.iso"
printf 'Test the ISO in a virtual machine before using it on physical hardware.\n'
