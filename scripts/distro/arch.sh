# Steps for Arch Linux and distros that use Arch's own repos (EndeavourOS,
# ...). Sourced by packages.sh after install_pacman and install_local
# exist; not meant to be run on its own.
#
# These systems don't have the three CachyOS-only packages ZeXOS uses, so
# each one gets a stand-in. If you added the CachyOS repos yourself, the
# real package is used instead (every step asks pacman first).

# 1. zsh setup. CachyOS bundles these as cachyos-zsh-config; here they are
#    installed one by one and .zshrc loads them itself (its step 4).
ZSH_PLUGINS_PACMAN=(
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
    zsh-completions
    fzf
    pkgfile
)
install_pacman "zsh plugins" "${ZSH_PLUGINS_PACMAN[@]}"

# pkgfile answers "command not found" with the package that has it. It
# needs its file list downloaded first, then a timer keeps it fresh.
if command -v pkgfile >/dev/null 2>&1; then
    sudo systemctl enable --now pkgfile-update.timer >/dev/null 2>&1 || true
    [ -n "$(ls -A /var/cache/pkgfile 2>/dev/null)" ] || sudo pkgfile --update >/dev/null 2>&1 || true
fi

# The Powerlevel10k prompt left Arch's repos, so build Arch's old recipe.
if zexos_in_repos zsh-theme-powerlevel10k; then
    install_pacman "zsh prompt (Powerlevel10k)" zsh-theme-powerlevel10k
else
    install_local "zsh prompt (Powerlevel10k)" zsh-theme-powerlevel10k-zexos
fi

# 2. Zen browser (Mod+B). Not in Arch's repos, so it is repacked from
#    Zen's official release. pacman won't update it by itself: running
#    install.sh again does, once packaging/zen-browser-zexos moves on.
if zexos_in_repos zen-browser-bin; then
    install_pacman "Web browser (Zen)" zen-browser-bin
else
    install_local "Web browser (Zen)" zen-browser-zexos
fi

# 3. App store (Mod+M). Shelly is CachyOS-only; KDE Discover (installed by
#    bootstrap.sh) does the same job, and zexos-app-store picks whichever
#    one is there.
if zexos_in_repos shelly; then
    install_pacman "Package manager app (Shelly)" shelly
else
    echo -e "${CYAN}ℹ Shelly is CachyOS-only -- Mod+M opens KDE Discover instead${RESET}"
fi
