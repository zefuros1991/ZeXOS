#!/usr/bin/env python3
"""Maintainer tool: (re)generates the ID lists in ../ids from public sources.

  NVIDIA  /usr/share/doc/nvidia/html/supportedchips.html (NVIDIA's own "supported
          GPUs" appendix, shipped with nvidia-utils): the "Current" table is the
          newest driver; "legacy_580.xx" the legacy driver; every older legacy
          table (470.xx and below) gets the open-source driver.
  AMD     GCN 1/2 (Southern/Sea Islands) chips by codename from the PCI ID
          database (/usr/share/hwdata/pci.ids).
  Intel   graphics generations by codename from pci.ids.
  Others  fixed lists (Broadcom wl, Realtek r8168, Intel low-power CPUs), with
          their source in each file's header.

Run: tools/gen-ids.py  (then review the diff and commit ids/).
"""
import os, re, sys, html, datetime
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "ids")
NV_DOC = "/usr/share/doc/nvidia/html/supportedchips.html"
PCI_IDS = "/usr/share/hwdata/pci.ids"

def write(name, ids, source):
    ids = sorted(set(i.lower() for i in ids))
    with open(os.path.join(OUT, name), "w") as f:
        f.write(f"# {name}: {len(ids)} PCI device IDs. Source: {source}\n")
        f.write(f"# Generated {datetime.date.today()} by tools/gen-ids.py. One 4-hex ID per line.\n")
        f.write("\n".join(ids) + "\n")

def nvidia():
    s = open(NV_DOC, encoding="utf-8", errors="replace").read()
    ver = re.search(r"Version\s+([\d.]+)", s)
    parts = re.split(r'<a name="([^"]+)"', s)
    tables = {}
    for i in range(1, len(parts) - 1, 2):
        tables[parts[i]] = parts[i + 1]
    def ids_in(chunk):
        # rows: <td>name</td><td>XXXX[ YYYY ZZZZ]</td>...; the first 4-hex after the name cell is the device ID
        out = set()
        for row in re.findall(r"<tr[^>]*>(.*?)</tr>", chunk, re.S | re.I):
            cells = [re.sub(r"<[^>]+>", "", c).strip() for c in re.findall(r"<td[^>]*>(.*?)</td>", row, re.S | re.I)]
            if len(cells) >= 2:
                m = re.match(r"([0-9A-Fa-f]{4})\b", cells[1])
                if m: out.add(m.group(1))
        return out
    current = ids_in(tables.get("Current", ""))
    legacy = ids_in(tables.get("legacy_580.xx", ""))
    older = set()
    for k, v in tables.items():
        if k.startswith("legacy_") and k != "legacy_580.xx":
            older |= ids_in(v)
    src = f"NVIDIA supportedchips.html{(' ' + ver.group(1)) if ver else ''}"
    if not (current and legacy and older):
        sys.exit("NVIDIA tables not found; is nvidia-utils installed?")
    write("nvidia-newest.ids", current - legacy - older, src + ' ("Current" table)')
    write("nvidia-legacy.ids", legacy - older, src + ' ("580.xx" legacy table)')
    write("nvidia-open.ids", older, src + " (470.xx and older legacy tables)")

def pci_names(vendor):
    names, cur = {}, None
    for line in open(PCI_IDS, encoding="utf-8", errors="replace"):
        if line.startswith("#") or not line.strip(): continue
        if not line.startswith("\t"):
            cur = line[:4].lower()
        elif cur == vendor and not line.startswith("\t\t"):
            names[line[1:5].lower()] = line[7:].strip()
    return names

AMD_GCN12 = r"\b(Tahiti|Pitcairn|Cape Verde|Oland|Hainan|Bonaire|Hawaii|Grenada|Kaveri|Kabini|Mullins|Temash|Beema|Spectre|Spooky|Kalindi|Godavari|Curacao|Neptune|Saturn|Mars|Venus|Opal|Strato|Sun|Tobago|Trinidad|Emerald|Topaz|Jet|Exo|Bonaire|Kauai|Liverpool)\b"
INTEL_OLD = r"\b(Sandy ?Bridge|Ivy ?Bridge|Haswell|Valley ?View|Bay ?Trail|Ironlake|Atom|GMA|Mobile 4 Series|4 Series|82[0-9]{3}[A-Z]*|945|946|965|G3[135]|Q3[35]|Q45|G4[15]|B43|Xeon E3-1200 (v2|v3)|2nd Generation Core|3rd Gen Core|4th Gen Core|Core Processor Integrated)\b"
INTEL_MEDIA = r"\b(Broadwell|Braswell|Cherry ?View|Skylake|Kaby ?Lake|Coffee ?Lake|Comet ?Lake|Whiskey ?Lake|Amber ?Lake|Gemini ?Lake|Apollo ?Lake|Cannon ?Lake|Ice ?Lake|Elkhart ?Lake|Jasper ?Lake)\b"

def amd():
    n = pci_names("1002")
    write("amd-gcn12.ids", [d for d, name in n.items() if re.search(AMD_GCN12, name)], "pci.ids codenames: GCN 1 (Southern Islands) and GCN 2 (Sea Islands)")

def intel():
    n = pci_names("8086")
    gfx = {d: name for d, name in n.items() if re.search(r"Graphics|GT[123]|\bArc\b|Iris|UHD|HD Graphics|GMA|Integrated Graphics|Xe\b", name)}
    old = [d for d, name in gfx.items() if re.search(INTEL_OLD, name)]
    media = [d for d, name in gfx.items() if re.search(INTEL_MEDIA, name) and d not in old]
    write("intel-old.ids", old, "pci.ids codenames: before Broadwell (libva-intel-driver)")
    write("intel-media.ids", media, "pci.ids codenames: Broadwell to Ice Lake (intel-media-driver)")
    # Everything else from Intel graphics = Tiger Lake and newer (intel-media-driver + vpl-gpu-rt); no list needed.

def nvidia_arch():
    n = pci_names("10de")
    write("nvidia-turing.ids", [d for d, name in n.items() if re.match(r"TU1\d\d", name)], "pci.ids codenames TU1xx (Turing)")
    write("nvidia-fermi.ids", [d for d, name in n.items() if re.match(r"GF1\d\d", name)], "pci.ids codenames GF1xx (Fermi)")

def fixed():
    write("broadcom-wl.ids", "4311 4312 4315 4727 4328 4329 432a 432b 432c 432d 0576 4353 4357 4358 4359 4365 4331 43b1 43a0 4360".split(),
          "chwd network_drivers profile (devices supported by Broadcom's wl driver); vendors 14e4/14a4")
    write("realtek-r8168.ids", ["8168"], "Manjaro mhwd-db r8168 profile (vendor 10ec)")
    with open(os.path.join(OUT, "intel-lpmd.cpus"), "w") as f:
        f.write("# Intel CPU family 6 models that get intel-lpmd. Source: chwd power_management profile (Intel's lpmd support list).\n")
        f.write("\n".join("151 154 183 186 191 170 172 189 204 213".split()) + "\n")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    nvidia(); nvidia_arch(); amd(); intel(); fixed()
    for f in sorted(os.listdir(OUT)):
        print(f, sum(1 for l in open(os.path.join(OUT, f)) if l.strip() and not l.startswith("#")))
