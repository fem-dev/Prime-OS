# installer/lib/network.sh — the setup image carries no packages, so a working
# connection is not optional: everything the user chose comes from the mirrors.

step_preflight() {
    local mem_mb
    mem_mb="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
    if [[ "${mem_mb}" -lt 900 ]]; then
        die "Only ${mem_mb} MiB of memory was found.\n\nInstalling needs about 1 GiB free; the live session itself needs a few hundred MiB."
    fi

    if ! command -v pacstrap >/dev/null 2>&1; then
        die "pacstrap is missing from this image (arch-install-scripts).\n\nThis is a bug in the setup image; rebuild it with build.sh."
    fi

    local mode="BIOS/legacy"
    is_uefi && mode="UEFI"
    note "boot mode: ${mode}, memory: ${mem_mb} MiB"
}

step_network() {
    note "starting NetworkManager"
    systemctl start NetworkManager 2>/dev/null || true
    # Give a wired connection a moment before showing the wireless UI.
    for _ in 1 2 3 4 5; do
        have_network && break
        sleep 2
    done

    local attempt=1
    while ! have_network; do
        if [[ "${attempt}" -gt 3 ]]; then
            die "Still no connection to an Arch mirror.\n\nConnect the machine and run the installer again. If the network works but mirrors are blocked, a VPN is the usual fix."
        fi
        ui_msg "There is no connection to an Arch mirror yet.\n\nA wired connection is picked up automatically. For Wi-Fi, the network screen opens next: pick the network, enter the password, then quit it (Quit / Esc) and the installer will retry.\n\nAttempt ${attempt} of 3."
        clear
        nmtui || true
        clear
        systemctl restart NetworkManager 2>/dev/null || true
        for _ in 1 2 3 4 5; do
            have_network && break
            sleep 2
        done
        attempt=$((attempt + 1))
    done
    note "mirror reachable"
}
