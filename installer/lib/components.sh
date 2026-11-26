# installer/lib/components.sh — the part the user asked for: nothing is
# installed unless it was chosen here.
#
# Each component is a separate file: components/<name>.list holds Arch package
# names (comments allowed) and components/<name>.desc holds two lines, a title
# and a sentence. Adding a component means adding one pair of files; no code
# change, no rebuild of this script.

SELECTED_COMPONENTS=""
PKGS=()

component_names() {
    ( cd -- "${COMPONENT_DIR}" && ls -- *.list 2>/dev/null | sed 's/\.list$//' ) || true
}

component_title() {
    local desc="${COMPONENT_DIR}/$1.desc"
    if [[ -r "${desc}" ]]; then
        sed -n '1p' "${desc}"
    else
        printf '%s' "$1"
    fi
}

component_help() {
    local desc="${COMPONENT_DIR}/$1.desc"
    if [[ -r "${desc}" ]]; then
        sed -n '2,$p' "${desc}" | tr '\n' ' '
    else
        printf 'Packages from %s.list' "$1"
    fi
}

component_packages() {
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' "${COMPONENT_DIR}/$1.list" | awk 'NF'
}

human_size() {
    awk -v b="$1" 'BEGIN {
        split("B KiB MiB GiB TiB", unit, " ");
        i = 1;
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        printf (i == 1 ? "%.0f %s" : "%.1f %s"), b, unit[i]
    }'
}

# Total download size of the given packages, straight from the sync databases.
estimate_bytes() {
    local pkgs=("$@")
    [[ "${#pkgs[@]}" -gt 0 ]] || { echo 0; return; }
    pacman -Sp --print-format '%s' --noconfirm "${pkgs[@]}" 2>/dev/null \
        | awk '{s += $1} END {printf "%d", s + 0}'
}

step_components() {
    local name
    local -a items=()
    local on_off help

    if [[ -z "$(component_names)" ]]; then
        die "No components were found in ${COMPONENT_DIR}.\n\nThis is a bug in the setup image; rebuild it with build.sh."
    fi

    for name in $(component_names); do
        # base is not a choice: the system cannot boot without it.
        [[ "${name}" == "base" ]] && continue
        on_off=off
        # A sensible first boot: desktop, fonts and the AMD/Intel drivers are on
        # by default because they cover most laptops; NVIDIA, CJK and the 32-bit
        # gaming libraries stay off.
        case "${name}" in
            desktop|fonts|drivers-amd|drivers-intel|apps) on_off=on ;;
        esac
        help="$(component_help "${name}")"
        items+=("${name}" "$(component_title "${name}")" "${on_off}" "${help}")
    done

    local picked
    picked="$(ui_checklist "Choose what to install on this computer.\n\nOnly the components ticked here are downloaded and written to the disk. Space selects, TAB moves between buttons." "${items[@]}")" \
        || die "Component selection was cancelled. Nothing was installed."
    SELECTED_COMPONENTS="$(printf '%s\n' "${picked}" | awk 'NF' | tr '\n' ' ')"
    SELECTED_COMPONENTS="base ${SELECTED_COMPONENTS}"
    SELECTED_COMPONENTS="${SELECTED_COMPONENTS%" "}"

    # Dependencies between components, kept here rather than in the list files so
    # that a .list file stays a plain list of package names.
    local warnings=""
    case " ${SELECTED_COMPONENTS} " in
        *" gaming-32bit "*)
            case " ${SELECTED_COMPONENTS} " in
                *" drivers-amd "*|*" drivers-intel "*|*" drivers-nvidia "*) ;;
                *) warnings+="• gaming-32bit needs a graphics driver; tick drivers-amd, drivers-intel or drivers-nvidia.\n" ;;
            esac ;;
    esac
    case " ${SELECTED_COMPONENTS} " in
        *" apps "*)
            case " ${SELECTED_COMPONENTS} " in
                *" desktop "*) ;;
                *) warnings+="• apps are graphical programs and need the desktop component.\n" ;;
            esac ;;
    esac
    if [[ -n "${warnings}" ]]; then
        ui_msg "These choices will probably not work as expected:\n\n${warnings}\n\nYou can go back, or continue if that is what you want."
    fi

    PKGS=()
    for name in ${SELECTED_COMPONENTS}; do
        while IFS= read -r pkg; do PKGS+=("${pkg}"); done < <(component_packages "${name}")
    done

    # Drop names the mirrors do not have instead of failing the whole install on
    # one renamed package, and say which ones were dropped.
    local pkg m
    declare -A seen=()
    declare -A missing=()
    local -a unique=()
    for pkg in "${PKGS[@]}"; do
        if [[ -n "${seen[${pkg}]:-}" ]]; then
            continue
        fi
        seen["${pkg}"]=1
        unique+=("${pkg}")
    done

    for pkg in "${unique[@]}"; do
        if ! pacman -Si "${pkg}" >/dev/null 2>&1; then
            missing["${pkg}"]=1
        fi
    done

    if [[ "${#missing[@]}" -gt 0 ]]; then
        local -a keep=()
        for pkg in "${unique[@]}"; do
            if [[ -z "${missing[${pkg}]:-}" ]]; then
                keep+=("${pkg}")
            fi
        done
        PKGS=("${keep[@]}")
        local list=""
        for m in "${!missing[@]}"; do list+="• ${m}\n"; done
        ui_msg "These packages are not in the mirrors and were skipped:\n\n${list}\nEverything else installs normally."
    else
        PKGS=("${unique[@]}")
    fi

    local bytes
    bytes="$(estimate_bytes "${PKGS[@]}")"
    SELECTED_BYTES="${bytes}"
    note "components: ${SELECTED_COMPONENTS}"
    note "packages: ${#PKGS[@]}, download ≈ $(human_size "${bytes}")"

    if ! ui_yesno "This is what will be installed:\n\nComponents:\n${SELECTED_COMPONENTS}\n\n${#PKGS[@]} packages, about $(human_size "${bytes}") to download.\n\nContinue?"; then
        step_components
    fi
}
