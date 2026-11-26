#!/usr/bin/env bash
# Build the Prime-OS setup image.
#
# The result is a small bootable installer, not a desktop: it holds dial(1) and
# pacstrap, and it asks the user which components to install. Everything the
# user chooses comes from the Arch mirrors at install time, which is why this
# image stays a few hundred megabytes instead of a couple of gigabytes.
#
# Run it inside the Arch container described in DOCS.md:
#   docker run --rm -it --privileged -e PRIME_OS_BUILD_CONTAINER=1 \
#     -v "$PWD:/work" -w /work archlinux:latest
#   # then, in the container:
#   pacman -Syu --noconfirm archiso && bash build.sh
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SOURCE="${ROOT}/profile"
INSTALLER_SOURCE="${ROOT}/installer"
COMPONENT_SOURCE="${ROOT}/components"
BUILD_DIR="${ROOT}/.build"
PROFILE_WORK="${BUILD_DIR}/profile"
WORK_DIR="${BUILD_DIR}/work"
OUT_DIR="${ROOT}/out"

fail() {
    printf 'Prime-OS build: %s\n' "$*" >&2
    exit 1
}
log() {
    printf 'Prime-OS build: %s\n' "$*"
}

[[ "$(uname -s)" == Linux ]] || fail "Run this build on Linux, in the Arch container from DOCS.md."
# shellcheck source=/etc/os-release
. /etc/os-release
[[ "${ID:-}" == arch ]] || fail "The image builder needs Arch Linux (archiso) inside the build container."
[[ "${EUID}" -eq 0 ]] || fail "The Arch build container must run as root."
[[ "${PRIME_OS_BUILD_CONTAINER:-}" == 1 ]] || fail "Refusing to build outside the marked build container."
command -v mkarchiso >/dev/null 2>&1 || fail "archiso is not installed: pacman -S archiso"
[[ -d /usr/share/archiso/configs/releng ]] || fail "Arch's releng profile is missing; reinstall archiso."

for path in "${BUILD_DIR}" "${PROFILE_WORK}" "${WORK_DIR}" "${OUT_DIR}"; do
    [[ ! -L "${path}" ]] || fail "Refusing to use a symlink as a build or output directory: ${path}"
done
for required in "${PROFILE_SOURCE}/airootfs" "${INSTALLER_SOURCE}/prime-os-setup" \
                "${INSTALLER_SOURCE}/lib" "${INSTALLER_SOURCE}/overlay" "${COMPONENT_SOURCE}"; do
    [[ -e "${required}" ]] || fail "Missing source: ${required}"
done
[[ -f "${PROFILE_SOURCE}/live-packages.list" ]] || fail "profile/live-packages.list is missing."

# === package list ===========================================================
# Only what the installer itself needs. The list is filtered against the sync
# databases so a firmware package that Arch renamed cannot break the build.
log "refreshing the package databases"
pacman -Sy --noconfirm >/dev/null 2>&1 || fail "Could not refresh the package databases."

PACKAGES=()
MISSING=()
while IFS= read -r line; do
    pkg="${line%%#*}"
    pkg="$(printf '%s' "${pkg}" | tr -d '[:space:]')"
    [[ -n "${pkg}" ]] || continue
    if pacman -Si "${pkg}" >/dev/null 2>&1; then
        PACKAGES+=("${pkg}")
    else
        MISSING+=("${pkg}")
    fi
done < "${PROFILE_SOURCE}/live-packages.list"

[[ "${#PACKAGES[@]}" -gt 0 ]] || fail "No package from profile/live-packages.list exists in the mirrors."
if [[ "${#MISSING[@]}" -gt 0 ]]; then
    log "skipping packages the mirrors do not have: ${MISSING[*]}"
fi

# The firmware packages were split and renamed more than once. If most of the
# vendor names above are gone, fall back to the meta package: an installer with
# no firmware for the network card cannot install anything at all.
FIRMWARE_COUNT=0
for pkg in "${PACKAGES[@]}"; do
    case "${pkg}" in linux-firmware-*) FIRMWARE_COUNT=$((FIRMWARE_COUNT + 1)) ;; esac
done
if [[ "${FIRMWARE_COUNT}" -lt 3 ]]; then
    if pacman -Si linux-firmware >/dev/null 2>&1; then
        log "vendor firmware names are gone: adding the linux-firmware meta package"
        PACKAGES+=("linux-firmware")
    else
        fail "Neither vendor firmware packages nor linux-firmware exist; this mirror looks wrong."
    fi
fi

# === work profile ===========================================================
log "preparing the build profile"
mkdir -p -- "${BUILD_DIR}" "${OUT_DIR}"
rm -rf -- "${PROFILE_WORK}"
mkdir -p -- "${PROFILE_WORK}" "${WORK_DIR}"
cp -a /usr/share/archiso/configs/releng/. "${PROFILE_WORK}/"
# Our files win over releng's: same paths, copied after.
cp -a "${PROFILE_SOURCE}/airootfs/." "${PROFILE_WORK}/airootfs/"

AIROOT="${PROFILE_WORK}/airootfs"
install -d "${AIROOT}/usr/local/bin" "${AIROOT}/usr/local/lib/prime-os" \
           "${AIROOT}/usr/local/share/prime-os"

# The installer is copied as separate files: the program, its modules, the
# component descriptions and the overlay that is laid down on the target disk.
cp -a "${INSTALLER_SOURCE}/prime-os-setup" "${AIROOT}/usr/local/lib/prime-os/prime-os-setup"
cp -a "${INSTALLER_SOURCE}/lib/." "${AIROOT}/usr/local/lib/prime-os/lib/"
cp -a "${COMPONENT_SOURCE}/." "${AIROOT}/usr/local/share/prime-os/components/"
cp -a "${INSTALLER_SOURCE}/overlay/." "${AIROOT}/usr/local/share/prime-os/overlay/"
ln -sf ../lib/prime-os/prime-os-setup "${AIROOT}/usr/local/bin/prime-os-setup"

chmod 0755 "${AIROOT}/usr/local/lib/prime-os/prime-os-setup" \
           "${AIROOT}/usr/local/lib/prime-os/lib/"*.sh \
           "${AIROOT}/root/.bash_profile"

{
    printf '# Generated by Prime-OS build.sh — %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' "${PACKAGES[@]}"
} > "${PROFILE_WORK}/packages.x86_64"

# === image identity =========================================================
PROFILE_DEF="${PROFILE_WORK}/profiledef.sh"
sed -i \
    -e 's|^iso_name=.*|iso_name="prime-os"|' \
    -e "s|^iso_label=.*|iso_label=\"PRIME_SETUP_$(date +%y%m)\"|" \
    -e 's|^iso_publisher=.*|iso_publisher="Prime-OS <https://github.com/fem-dev/Prime-OS>"|' \
    -e 's|^iso_application=.*|iso_application="Prime-OS Setup"|' \
    "${PROFILE_DEF}"

log "packages in the image: ${#PACKAGES[@]}"
log "building (this downloads the live environment and compresses it)"

mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_WORK}"

ISO="$(find "${OUT_DIR}" -maxdepth 1 -type f -name 'prime-os-*-x86_64.iso' \
    -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
[[ -n "${ISO}" && -f "${ISO}" ]] || fail "The build finished without producing an ISO."
if [[ "${ISO}" != "${OUT_DIR}/os.iso" ]]; then
    mv -f -- "${ISO}" "${OUT_DIR}/os.iso"
fi

SIZE="$(stat -c%s "${OUT_DIR}/os.iso")"
log "written: ${OUT_DIR}/os.iso ($(numfmt --to=iec "${SIZE}"))"
log "components offered by this build: $(cd "${COMPONENT_SOURCE}" && ls -- *.list | sed 's/\.list$//' | tr '\n' ' ')"
log "the image is an installer: boot it in a VM and complete the wizard before flashing hardware."
