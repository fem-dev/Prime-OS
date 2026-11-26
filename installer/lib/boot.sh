# installer/lib/boot.sh — make the new system start on its own.
#
# UEFI uses systemd-boot (it is part of systemd, so no extra package beyond
# efibootmgr); legacy BIOS uses GRUB with a BIOS boot partition.

step_bootloader() {
    local root_uuid microcode_initrd=""
    root_uuid="$(blkid -s UUID -o value "${ROOT_PART}")"
    if [[ -z "${root_uuid}" ]]; then
        die "Could not read the UUID of ${ROOT_PART}.\n\nThe system is installed but will not boot without it."
    fi

    if is_uefi; then
        ui_program "Installing the boot loader (systemd-boot)" _install_systemd_boot "${root_uuid}" \
            || die "systemd-boot could not be installed.\n\nThe system is on disk but may not start. A UEFI machine needs its firmware set to boot from ${DISK}, and the EFI partition must be FAT32."
    else
        ui_program "Installing the boot loader (GRUB)" _install_grub \
            || die "GRUB could not be installed.\n\nThe system is on disk but may not start."
    fi
}

_install_systemd_boot() {
    local root_uuid=$1
    local entries="${MNT}/boot/loader/entries"

    echo "Installing systemd-boot on the EFI partition"
    arch-chroot "${MNT}" bootctl --esp-path=/boot install

    mkdir -p "${entries}"
    printf 'default  prime-os.conf\ntimeout  3\neditor   no\n' > "${MNT}/boot/loader/loader.conf"

    if [[ -f "${MNT}/boot/intel-ucode.img" ]]; then
        printf 'initrd  /intel-ucode.img\n' > "${MNT}/boot/prime-os-initrd"
    elif [[ -f "${MNT}/boot/amd-ucode.img" ]]; then
        printf 'initrd  /amd-ucode.img\n' > "${MNT}/boot/prime-os-initrd"
    else
        : > "${MNT}/boot/prime-os-initrd"
    fi

    cat > "${entries}/prime-os.conf" <<ENTRY
title   Prime-OS
linux   /vmlinuz-linux
$(cat "${MNT}/boot/prime-os-initrd")
initrd  /initramfs-linux.img
options root=UUID=${root_uuid} rw quiet
ENTRY
    rm -f "${MNT}/boot/prime-os-initrd"

    echo "Boot entry written:"
    cat "${entries}/prime-os.conf"
}

_install_grub() {
    echo "Installing GRUB for legacy BIOS on ${DISK}"
    arch-chroot "${MNT}" grub-install --target=i386-pc --recheck "${DISK}"
    arch-chroot "${MNT}" grub-mkconfig -o /boot/grub/grub.cfg
}

step_finish() {
    sync
    note "unmounting the target"
    umount -R "${MNT}" 2>/dev/null || true

    local summary
    summary="Prime-OS is installed on ${DISK}.\n\n"
    summary+="User: ${USERNAME}\n"
    summary+="Computer name: ${HOSTNAME}\n"
    summary+="Components: ${SELECTED_COMPONENTS}\n"
    summary+="Packages: ${#INSTALL_PKGS[@]} (about $(human_size "${SELECTED_BYTES:-0}") downloaded)\n\n"
    summary+="Remove the installation media and start the computer."
    if has_component desktop; then
        summary+="\n\nThe Hyprland session starts on tty1 after you log in. Super+Enter opens a terminal, Super+D the launcher, Super+/ the key list."
    fi
    ui_msg "${summary}"

    if ui_yesno "Restart the computer now?"; then
        reboot
    fi
    ui_msg "The disk was synced and unmounted. It is safe to power off."
}
