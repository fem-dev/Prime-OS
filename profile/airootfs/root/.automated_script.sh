#!/usr/bin/env bash
set -Eeuo pipefail

# The upstream Arch live ISO autologs root on tty1. Switch to a regular live
# user before starting Hyprland; never run the graphical session as root.
if [[ "$(tty)" == "/dev/tty1" ]]; then
    id prime >/dev/null 2>&1 || useradd --create-home --groups wheel,audio,video,storage,optical --shell /bin/bash prime
    printf 'prime ALL=(ALL:ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/prime-live
    chmod 0440 /etc/sudoers.d/prime-live
    install -d -o prime -g prime /home/prime/.config/hypr
    install -m 0644 -o prime -g prime /etc/prime-os/hyprland.conf /home/prime/.config/hypr/hyprland.conf
    exec su - prime -c 'exec Hyprland'
fi
