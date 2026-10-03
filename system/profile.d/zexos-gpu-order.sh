# ZeXOS: on two-GPU laptops, make Mango draw on the GPU the screen is wired to.
#
# Mango (wlroots) picks its main GPU by the "boot_vga" flag. Some laptops
# (ASUS Zephyrus G16: AMD + NVIDIA) don't set that flag on either GPU, so
# wlroots just takes the first card, which can be the NVIDIA one while the
# built-in screen hangs off the AMD one. Every frame then has to cross GPUs
# and the screen fails: solid colour, no mouse pointer, "Atomic commit
# failed: Cannot allocate memory" in the log.
#
# Fix: list the GPU that drives the built-in screen (eDP) first in
# WLR_DRM_DEVICES. wlroots' docs: "The first existing device in this list
# is considered the primary DRM device." We only step in when there are
# two or more GPUs and none is flagged boot_vga=1, so normal machines (and
# GPU MUX "dGPU only" mode, where only one GPU shows up) are left alone.
# niri ignores this; it has its own render-drm-device setting.
if [ -z "$WLR_DRM_DEVICES" ]; then
    _zx_primary=""
    _zx_others=""
    _zx_count=0
    _zx_bootvga=0
    for _zx_card in /sys/class/drm/card[0-9]*; do
        case "$_zx_card" in *-*) continue ;; esac
        [ -e "$_zx_card/device" ] || continue
        _zx_count=$((_zx_count + 1))
        [ "$(cat "$_zx_card/device/boot_vga" 2>/dev/null)" = "1" ] && _zx_bootvga=1
        _zx_dev="/dev/dri/${_zx_card##*/}"
        _zx_edp=0
        for _zx_conn in "$_zx_card"-eDP-*; do
            [ "$(cat "$_zx_conn/status" 2>/dev/null)" = "connected" ] && _zx_edp=1
        done
        if [ "$_zx_edp" = 1 ] && [ -z "$_zx_primary" ]; then
            _zx_primary="$_zx_dev"
        else
            _zx_others="$_zx_others:$_zx_dev"
        fi
    done
    if [ "$_zx_count" -ge 2 ] && [ "$_zx_bootvga" = 0 ] && [ -n "$_zx_primary" ]; then
        WLR_DRM_DEVICES="$_zx_primary$_zx_others"
        export WLR_DRM_DEVICES
        # AMD Strix Point (Radeon 890M) laptops with an NVIDIA card still
        # refuse Mango's "atomic" screen updates on the built-in panel
        # ("Cannot allocate memory"), even on the right GPU. The older
        # update method and a software mouse pointer work. Mango's wiki
        # (monitors.md, GPU Compatibility) gives WLR_DRM_NO_ATOMIC; the
        # same fix for the same chip: github.com/omacom/omarchy/issues/9720
        : "${WLR_DRM_NO_ATOMIC:=1}" "${WLR_NO_HARDWARE_CURSORS:=1}"
        export WLR_DRM_NO_ATOMIC WLR_NO_HARDWARE_CURSORS
    fi
    unset _zx_primary _zx_others _zx_count _zx_bootvga _zx_card _zx_dev _zx_edp _zx_conn
fi
