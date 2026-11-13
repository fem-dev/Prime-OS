#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ISO="${1:-${ROOT}/out/os.iso}"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) ;;
    *) echo "Run this script from Git Bash on Windows." >&2; exit 1 ;;
esac

if [[ ! -f "${ISO}" ]]; then
    echo "Prime-OS ISO not found: ${ISO}" >&2
    echo "Build it first on Arch Linux with: sudo ./build.sh" >&2
    echo "Then place the generated out/os.iso in this project's out folder." >&2
    exit 1
fi

QEMU="$(command -v qemu-system-x86_64.exe || command -v qemu-system-x86_64 || true)"
if [[ -z "${QEMU}" ]]; then
    echo "QEMU for Windows was not found. Install QEMU and add its install folder to PATH." >&2
    echo "Download: https://www.qemu.org/download/#windows" >&2
    exit 1
fi

# Use a modest VM allocation; this only affects the virtual machine, not Windows.
RAM="${PRIME_OS_VM_RAM:-4G}"
CPUS="${PRIME_OS_VM_CPUS:-2}"
ISO_WIN="$(cygpath -w "${ISO}")"
echo "Starting Prime-OS in QEMU (${RAM} RAM, ${CPUS} CPUs). Windows disks are not modified."
exec "${QEMU}" -m "${RAM}" -smp "${CPUS}" \
    -drive "file=${ISO_WIN},media=cdrom,readonly=on" \
    -boot d -display sdl -accel whpx:tcg
