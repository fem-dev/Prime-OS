# installer/lib/account.sh — user, password, hostname and time zone.

USERNAME=""
USER_PASSWORD=""
HOSTNAME="prime-os"
TIMEZONE="UTC"

step_account() {
    local value attempt

    while :; do
        value="$(ui_input "Username for the new account.\n\nLowercase letters, digits, _ and -." "${USERNAME:-prime}")" \
            || die "Account setup was cancelled. Nothing was installed."
        if [[ "${value}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
            USERNAME="${value}"
            break
        fi
        ui_msg "'${value}' cannot be a username.\n\nUse lowercase letters, digits, _ and -, starting with a letter or _."
    done

    while :; do
        value="$(ui_input "Computer name (hostname)" "${HOSTNAME}")" \
            || die "Account setup was cancelled. Nothing was installed."
        if [[ "${value}" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]]; then
            HOSTNAME="${value}"
            break
        fi
        ui_msg "'${value}' cannot be a hostname."
    done

    local tz_list=(
        UTC "UTC — coordinated universal time"
        Asia/Tehran "Asia/Tehran"
        Europe/London "Europe/London"
        Europe/Berlin "Europe/Berlin"
        America/New_York "America/New_York"
        Asia/Dubai "Asia/Dubai"
        Asia/Tokyo "Asia/Tokyo"
        other "Another zone — type it"
    )
    value="$(ui_menu "Time zone" "${tz_list[@]}")" \
        || die "Account setup was cancelled. Nothing was installed."
    if [[ "${value}" == "other" ]]; then
        while :; do
            value="$(ui_input "Time zone, as a Zoneinfo name (for example Europe/Paris)" "")" \
                || die "Account setup was cancelled. Nothing was installed."
            if [[ -f "/usr/share/zoneinfo/${value}" ]]; then
                TIMEZONE="${value}"
                break
            fi
            ui_msg "/usr/share/zoneinfo/${value} does not exist."
        done
    else
        TIMEZONE="${value}"
    fi

    attempt=0
    while :; do
        attempt=$((attempt + 1))
        if [[ "${attempt}" -gt 5 ]]; then
            die "The password boxes kept disagreeing. Run the installer again."
        fi
        local first second
        first="$(ui_password "Password for ${USERNAME}")" \
            || die "Account setup was cancelled. Nothing was installed."
        second="$(ui_password "Password for ${USERNAME} again")" \
            || die "Account setup was cancelled. Nothing was installed."
        if [[ "${first}" != "${second}" ]]; then
            ui_msg "The two passwords are different."
            continue
        fi
        if [[ "${#first}" -lt 6 ]]; then
            ui_msg "Use at least 6 characters."
            continue
        fi
        USER_PASSWORD="${first}"
        break
    done

    note "account: ${USERNAME}@${HOSTNAME}, ${TIMEZONE}"
}
