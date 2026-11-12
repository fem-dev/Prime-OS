# Start the live graphical session only on the first local text console.
if [[ -z "${WAYLAND_DISPLAY:-}" && "$(tty 2>/dev/null || true)" == "/dev/tty1" ]]; then
    exec Hyprland
fi
