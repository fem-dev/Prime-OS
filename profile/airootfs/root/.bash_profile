# The setup ISO autologins as root on tty1 and runs the installer there.
if [ "$(tty)" = "/dev/tty1" ] && [ -z "${PRIME_OS_SETUP_DONE:-}" ]; then
    exec /usr/local/bin/prime-os-setup
fi
