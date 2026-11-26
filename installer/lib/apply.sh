# installer/lib/apply.sh — write the chosen components onto the target disk.
#
# pacstrap installs only what components.sh resolved, so a machine that asked for
# "base + desktop" never downloads NVIDIA, CJK fonts or the 32-bit libraries.

PACMAN_CONF=""
INSTALL_PKGS=()

has_component() {
    case " ${SELECTED_COMPONENTS} " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

# Firmware package names changed when Arch split linux-firmware; ask the
# mirrors which ones exist instead of guessing, then fall back to the meta
# package so a target machine always has firmware for its network card.
firmware_packages() {
    local candidates=(
        linux-firmware-amd
        linux-firmware-intel
        linux-firmware-realtek
        linux-firmware-atheros
        linux-firmware-broadcom
        linux-firmware-nvidia
        linux-firmware-other
    )
    local -a found=()
    local pkg
    for pkg in "${candidates[@]}"; do
        if pacman -Si "${pkg}" >/dev/null 2>&1; then
            found+=("${pkg}")
        fi
    done
    if [[ "${#found[@]}" -eq 0 ]]; then
        printf 'linux-firmware\n'
        return
    fi
    printf '%s\n' "${found[@]}"
}

microcode_package() {
    if grep -qm1 '^vendor_id[[:space:]]*:[[:space:]]*GenuineIntel' /proc/cpuinfo; then
        printf 'intel-ucode\n'
    elif grep -qm1 '^vendor_id[[:space:]]*:[[:space:]]*AuthenticAMD' /proc/cpuinfo; then
        printf 'amd-ucode\n'
    fi
}

build_pacman_conf() {
    PACMAN_CONF="/tmp/prime-os-pacman.conf"
    cp /etc/pacman.conf "${PACMAN_CONF}"
    if has_component gaming-32bit; then
        if grep -q '^#\[multilib\]' "${PACMAN_CONF}"; then
            sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' "${PACMAN_CONF}"
        fi
    fi
    # Always install the newest packages at install time: the ISO ships no
    # package payload, so the target should start on today's mirrors.
    sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 8/' "${PACMAN_CONF}"
}

collect_packages() {
    local -a pkgs=(base linux sudo nano less networkmanager dosfstools)
    local pkg

    while IFS= read -r pkg; do [[ -n "${pkg}" ]] && pkgs+=("${pkg}"); done < <(firmware_packages)
    pkg="$(microcode_package)"
    [[ -n "${pkg}" ]] && pkgs+=("${pkg}")

    # A bootloader for the machine we are on: systemd-boot ships inside systemd,
    # so UEFI only needs efibootmgr; legacy BIOS needs GRUB.
    if is_uefi; then
        pkgs+=(efibootmgr)
    else
        pkgs+=(grub)
    fi

    pkgs+=("${PKGS[@]}")

    local -A seen=()
    local -a unique=()
    for pkg in "${pkgs[@]}"; do
        if [[ -n "${seen[${pkg}]:-}" ]]; then
            continue
        fi
        seen["${pkg}"]=1
        unique+=("${pkg}")
    done
    INSTALL_PKGS=("${unique[@]}")
}

step_apply() {
    build_pacman_conf
    collect_packages
    note "installing ${#INSTALL_PKGS[@]} packages"

    ui_program "Installing Prime-OS — downloading and unpacking packages" _install_everything \
        || die "The installation failed.\n\nThe log above shows the first error. Nothing was started and the target disk is incomplete: run the installer again from the beginning."
}

_install_everything() {
    echo "Target: ${DISK} (${TARGET_FS}) at ${MNT}"
    echo "Filesystem in use:"
    findmnt -no FSTYPE,SOURCE "${MNT}" || true

    echo
    echo "=== pacstrap: ${#INSTALL_PKGS[@]} packages ==="
    pacstrap -K -C "${PACMAN_CONF}" "${MNT}" "${INSTALL_PKGS[@]}"

    echo
    echo "=== recording the filesystems ==="
    mkdir -p "${MNT}/etc"
    : > "${MNT}/etc/fstab"
    genfstab -U "${MNT}" >> "${MNT}/etc/fstab"
    cat "${MNT}/etc/fstab"

    echo
    echo "=== copying the Prime-OS overlay ==="
    if [[ -d "${OVERLAY_DIR}" ]]; then
        cp -a "${OVERLAY_DIR}/." "${MNT}/"
    else
        echo "warning: no overlay directory at ${OVERLAY_DIR}"
    fi

    echo
    echo "=== writing the installation record ==="
    mkdir -p "${MNT}/etc/prime-os"
    {
        printf 'components: %s\n' "${SELECTED_COMPONENTS}"
        printf 'disk: %s\n' "${DISK}"
        printf 'filesystem: %s\n' "${TARGET_FS}"
        printf 'boot: %s\n' "$(is_uefi && echo uefi || echo bios)"
        printf 'packages: %s\n' "${#INSTALL_PKGS[@]}"
        printf 'installed: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "${MNT}/etc/prime-os/install.conf"
    printf '%s\n' "${SELECTED_COMPONENTS}" > "${MNT}/etc/prime-os/components.txt"

    echo
    echo "=== configuring the new system ==="
    _write_target_script
    arch-chroot "${MNT}" /bin/bash /root/.prime-os-configure \
        "${USERNAME}" "${HOSTNAME}" "${TIMEZONE}" "$(is_uefi && echo uefi || echo bios)"
    rm -f "${MNT}/root/.prime-os-configure"

    echo
    echo "=== setting the password ==="
    printf '%s:%s\n' "${USERNAME}" "${USER_PASSWORD}" | arch-chroot "${MNT}" chpasswd
    echo "password set for ${USERNAME}; root login is locked (use sudo)"
}

_write_target_script() {
    cat > "${MNT}/root/.prime-os-configure" <<'TARGET_SCRIPT'
#!/usr/bin/env bash
# Runs inside the new system (arch-chroot). It has no access to the live
# session's variables: everything arrives as an argument.
set -Eeuo pipefail

username=$1
hostname=$2
timezone=$3
bootmode=$4

echo "Localtime: ${timezone}"
ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
hwclock --systohc || echo "warning: could not write the hardware clock"

echo "Locale: en_US.UTF-8"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf
printf 'KEYMAP=us\n' > /etc/vconsole.conf

echo "Hostname: ${hostname}"
printf '%s\n' "${hostname}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
HOSTS

echo "User: ${username}"
if ! id "${username}" >/dev/null 2>&1; then
    useradd --create-home --groups wheel --shell /bin/bash "${username}"
fi
# The live ISO never leaves a passwordless root behind on disk.
passwd -l root >/dev/null 2>&1 || true

echo "sudo for the wheel group"
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel

echo "Enabling services"
systemctl enable NetworkManager.service >/dev/null 2>&1 || true
systemctl enable fstrim.timer >/dev/null 2>&1 || true

echo "Building the initramfs"
mkinitcpio -P
TARGET_SCRIPT
    chmod 0755 "${MNT}/root/.prime-os-configure"
}
