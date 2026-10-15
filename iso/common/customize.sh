#!/usr/bin/env bash
# Run by iso/build.sh with the profile folder as $1, after the common files
# were copied in (both sticks).
#
# Adds "ZeXOS (safe graphics)" right after the normal entry in every start
# menu of the stick (UEFI systemd-boot, BIOS syslinux, GRUB and its
# loopback menu): basic graphics (nomodeset) with NVIDIA's driver kept off,
# for graphics cards that show a black screen.
set -euo pipefail
profile="${1:?}"
safe="nomodeset module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm"

# UEFI (systemd-boot): its own entry file, sorted right after the normal one.
cat > "$profile/efiboot/loader/entries/01-zexos-safe.conf" <<EOF
title    ZeXOS (safe graphics)
sort-key 015
linux    /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
initrd   /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
options  archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% %KERNEL_PARAMS% $safe
EOF

# BIOS (syslinux): a LABEL after the first one.
python3 - "$profile/syslinux/archiso_sys-linux.cfg" "$safe" <<'EOF'
import sys
path, safe = sys.argv[1:3]
s = open(path).read()
entry = f"""LABEL zexossafe
TEXT HELP
Basic graphics, for a graphics card that shows a black screen.
ENDTEXT
MENU LABEL ZeXOS (safe graphics)
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% %KERNEL_PARAMS% {safe}

"""
marker = "\n# Accessibility boot option"
if "zexossafe" not in s:
    s = s.replace(marker, "\n" + entry + marker.lstrip("\n"), 1) if marker in s else s + "\n" + entry
open(path, "w").write(s)
EOF

# GRUB (and the menu used when the ISO file is booted from another GRUB):
# a menuentry after the first one.
for cfg in "$profile/grub/grub.cfg" "$profile/grub/loopback.cfg"; do
    [ -f "$cfg" ] || continue
    python3 - "$cfg" "$safe" <<'EOF'
import re, sys
path, safe = sys.argv[1:3]
s = open(path).read()
if "ZeXOS (safe graphics)" not in s:
    m = re.search(r'^menuentry "[^"]*" [^\n]*--id \'archlinux\' \{\n(.*?)^\}\n', s, re.M | re.S)
    if not m:
        sys.exit(f"{path}: normal menu entry not found")
    body = m.group(1)
    body = re.sub(r"^(\s*linux .*)$", lambda x: x.group(1) + " " + safe, body, count=1, flags=re.M)
    entry = "\nmenuentry \"ZeXOS (safe graphics)\" --class arch --class gnu-linux --class gnu --class os --id 'zexos-safe' {\n" + body + "}\n"
    s = s[:m.end()] + entry + s[m.end():]
open(path, "w").write(s)
EOF
done
