#!/usr/bin/env bash
# Works out which Linux you are on, so the installer knows which extra
# steps to run. Source it, then call zexos_detect_distro.
#
# How other big dotfile projects do this, and what we took from each:
#   - end-4/dots-hyprland reads ID and ID_LIKE from /etc/os-release and
#     picks one folder of install scripts per distro family.
#   - HyDE uses a single script and asks pacman, package by package,
#     whether something is in the repos before installing it.
# ZeXOS does both: os-release picks the distro script (scripts/distro/),
# and inside it every package that is not in every repo is checked with
# pacman first.
#
# After zexos_detect_distro runs:
#   ZEXOS_DISTRO       cachyos | arch | unsupported
#   ZEXOS_DISTRO_NAME  the distro's own name, for messages
#   ZEXOS_DISTRO_WHY   why it is unsupported (empty otherwise)
#
# You can force a choice with ZEXOS_DISTRO=cachyos or ZEXOS_DISTRO=arch
# before running install.sh, for a distro we don't know by name.

zexos_detect_distro() {
    local id="" id_like="" name=""

    # Read the file in a subshell so its variables don't leak into ours.
    if [ -r /etc/os-release ]; then
        IFS=$'\t' read -r id id_like name < <(
            . /etc/os-release
            printf '%s\t%s\t%s\n' "${ID:-}" "${ID_LIKE:-}" "${PRETTY_NAME:-${NAME:-}}"
        )
    fi
    ZEXOS_DISTRO_NAME="${name:-${id:-unknown Linux}}"
    ZEXOS_DISTRO_WHY=""

    # A choice made by hand wins.
    case "${ZEXOS_DISTRO:-}" in
        cachyos|arch) export ZEXOS_DISTRO ZEXOS_DISTRO_NAME ZEXOS_DISTRO_WHY; return 0 ;;
    esac

    if ! command -v pacman >/dev/null 2>&1; then
        ZEXOS_DISTRO=unsupported
        ZEXOS_DISTRO_WHY="it has no pacman, so it is not Arch-based"
    elif [ ! -d /run/systemd/system ]; then
        # Artix and friends: ZeXOS turns on SDDM, Bluetooth and its own
        # services with systemd, so none of that would work.
        ZEXOS_DISTRO=unsupported
        ZEXOS_DISTRO_WHY="it does not run systemd (Artix and similar), and ZeXOS needs it"
    else
        case "$id" in
            manjaro*)
                # Manjaro uses its own repos, held back a week or two behind
                # Arch's, so the packages ZeXOS builds may not match.
                ZEXOS_DISTRO=unsupported
                ZEXOS_DISTRO_WHY="Manjaro's repos lag behind Arch's, so ZeXOS's own packages may not build or run"
                ;;
            artix*)
                ZEXOS_DISTRO=unsupported
                ZEXOS_DISTRO_WHY="Artix does not use systemd, and ZeXOS needs it"
                ;;
            cachyos)
                ZEXOS_DISTRO=cachyos
                ;;
            arch|endeavouros)
                ZEXOS_DISTRO=arch
                ;;
            *)
                # Anything else that says it is "like arch" uses Arch's repos.
                # ID_LIKE is a space-separated list, e.g. "arch" or "cachyos arch".
                case " $id_like " in
                    *" arch "*) ZEXOS_DISTRO=arch ;;
                    *)
                        ZEXOS_DISTRO=unsupported
                        ZEXOS_DISTRO_WHY="it does not say it is based on Arch (ID=$id, ID_LIKE=$id_like)"
                        ;;
                esac
                ;;
        esac
    fi

    export ZEXOS_DISTRO ZEXOS_DISTRO_NAME ZEXOS_DISTRO_WHY
}

# Stops the install on a distro ZeXOS can't support, with the reason.
zexos_require_supported_distro() {
    zexos_detect_distro
    if [ "$ZEXOS_DISTRO" = unsupported ]; then
        echo -e "\e[31m✖ ZeXOS can't install on ${ZEXOS_DISTRO_NAME}: ${ZEXOS_DISTRO_WHY}.\e[0m" >&2
        echo "  It supports CachyOS, Arch Linux and distros that use Arch's own repos (EndeavourOS, ...)." >&2
        echo "  If yours does use Arch's repos and systemd, run it again with ZEXOS_DISTRO=arch in front." >&2
        return 1
    fi
    echo -e "\e[32m✔ Detected ${ZEXOS_DISTRO_NAME} (using the ${ZEXOS_DISTRO} steps)\e[0m"
}

# True if pacman can install this package from the repos you have.
zexos_in_repos() {
    pacman -Si "$1" >/dev/null 2>&1
}
