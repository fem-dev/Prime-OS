# Login shell on the installed system.
#
# tty1 starts the graphical session; every other console stays a plain shell so
# a broken compositor never locks the machine out.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ] && command -v Hyprland >/dev/null 2>&1; then
    exec Hyprland
fi
