# installer/lib/disk.sh — choose a disk, partition it, format it, mount it.
#
# This is the only destructive step. It always asks for the disk name to be typed
# back, and it refuses to touch a disk that still has mounted filesystems.

DISK=""
ROOT_PART=""
EFI_PART=""
TARGET_FS="ext4"

# /dev/sda -> /dev/sda1, /dev/nvme0n1 -> /dev/nvme0n1p1
part_path() {
    local disk=$1 num=$2
    if [[ "${disk}" =~ [0-9]$ ]]; then
        printf '%sp%s' "${disk}" "${num}"
    else
        printf '%s%s' "${disk}" "${num}"
    fi
}

mounted_parts_of() {
    local disk=$1
    lsblk -lnpo NAME,MOUNTPOINT "${disk}" 2>/dev/null | awk '$2 != "" {print $1}'
}

wait_for_part() {
    local part=$1 i
    for i in $(seq 1 40); do
        [[ -b "${part}" ]] && return 0
        sleep 0.25
    done
    return 1
}

disk_menu_items() {
    local name size model type
    while read -r name size model type; do
        [[ "${type}" == "disk" ]] || continue
        printf '%s\n' "${name}"
        printf '%s  %s\n' "${size}" "${model:-unknown model}"
    done < <(lsblk -dnpo NAME,SIZE,MODEL,TYPE)
}

step_disk() {
    local -a items=()
    local line
    while IFS= read -r line; do items+=("${line}"); done < <(disk_menu_items)

    if [[ "${#items[@]}" -eq 0 ]]; then
        die "No disk was found.\n\nIf this is a virtual machine, attach a virtual disk to it first."
    fi

    local chosen
    chosen="$(ui_menu "Choose the disk Prime-OS may use.\n\nEverything on it is erased." "${items[@]}")" \
        || die "No disk was chosen. Nothing was changed."
    DISK="${chosen}"

    if [[ -n "$(mounted_parts_of "${DISK}")" ]]; then
        die "A partition on ${DISK} is mounted:\n\n$(mounted_parts_of "${DISK}")\n\nUnmount it first (the installer never unmounts filesystems it did not mount)."
    fi

    local typed
    typed="$(ui_input "Type ERASE to wipe ${DISK} and install Prime-OS on it." "")" \
        || die "Cancelled. Nothing was changed."
    if [[ "${typed}" != "ERASE" ]]; then
        die "The word ERASE was not typed, so ${DISK} was left untouched."
    fi

    local fs_choice
    fs_choice="$(ui_menu "Filesystem for the Prime-OS partition" \
        ext4 "ext4 — mature, every tool understands it" \
        btrfs "btrfs — snapshots and compression")" || die "Cancelled. Nothing was changed."
    TARGET_FS="${fs_choice}"

    # The partition nodes are fixed by the table above; resolving them here keeps
    # the names in this shell, because the progress box runs in a subshell.
    ROOT_PART="$(part_path "${DISK}" 2)"
    EFI_PART=""
    is_uefi && EFI_PART="$(part_path "${DISK}" 1)"

    ui_program "Partitioning ${DISK}" _partition_and_format \
        || die "Partitioning or formatting ${DISK} failed. The disk is in an incomplete state; nothing else was installed."

    note "installed onto ${DISK} (${TARGET_FS}), root=${ROOT_PART}, efi=${EFI_PART:-none}"
}

_partition_and_format() {
    echo "Wiping partition table on ${DISK}"
    sgdisk --zap-all "${DISK}" >/dev/null
    wipefs --all --force "${DISK}" >/dev/null 2>&1 || true

    if is_uefi; then
        sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:EFI \
               --new=2:0:0     --typecode=2:8300 --change-name=2:PrimeOS \
               "${DISK}" >/dev/null
    else
        # 1 MiB BIOS boot partition keeps GRUB's core image outside the filesystem.
        sgdisk --new=1:0:+1M   --typecode=1:ef02 --change-name=1:BIOSBOOT \
               --new=2:0:0     --typecode=2:8300 --change-name=2:PrimeOS \
               "${DISK}" >/dev/null
    fi

    partprobe "${DISK}" >/dev/null 2>&1 || true
    udevadm settle --timeout=15 || true

    wait_for_part "${ROOT_PART}" || { echo "Root partition never appeared: ${ROOT_PART}"; return 1; }

    if is_uefi; then
        wait_for_part "${EFI_PART}" || { echo "EFI partition never appeared: ${EFI_PART}"; return 1; }
        echo "Formatting ${EFI_PART} as FAT32"
        mkfs.vfat -F32 -n PRIME_EFI "${EFI_PART}"
    fi

    echo "Formatting ${ROOT_PART} as ${TARGET_FS}"
    case "${TARGET_FS}" in
        btrfs) mkfs.btrfs -f -L PrimeOS "${ROOT_PART}" ;;
        *)     mkfs.ext4 -F -L PrimeOS "${ROOT_PART}" ;;
    esac

    echo "Mounting"
    mount "${ROOT_PART}" "${MNT}"
    if is_uefi; then
        mkdir -p "${MNT}/boot"
        mount "${EFI_PART}" "${MNT}/boot"
    fi
}
