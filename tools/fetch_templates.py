#!/usr/bin/env python3
"""Scarica SOLO i template di esportazione di Godot che servono dall'archivio ufficiale .tpz (~1.3 GB),
leggendo il file zip remoto a pezzi con richieste HTTP Range (~70 MB per piattaforma).

Uso: python3 tools/fetch_templates.py 4.7.2 [linux] [windows]   (senza piattaforme: solo linux)
Installa in ~/.local/share/godot/export_templates/<versione>.stable/
"""
import os
import struct
import sys
import urllib.request
import zlib

PLATFORMS = {
    "linux": "templates/linux_release.x86_64",
    "windows": "templates/windows_release_x86_64.exe",
}


def http_range(url: str, start: int, end: int) -> bytes:
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}", "User-Agent": "dawn-and-ash"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def total_size(url: str) -> int:
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "dawn-and-ash"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return int(r.headers["Content-Length"])


def main() -> int:
    ver = sys.argv[1] if len(sys.argv) > 1 else "4.7.2"
    platforms = sys.argv[2:] or ["linux"]
    unknown = [p for p in platforms if p not in PLATFORMS]
    if unknown:
        print(f"piattaforme sconosciute: {unknown} (disponibili: {list(PLATFORMS)})")
        return 1
    wanted = {PLATFORMS[p] for p in platforms} | {"templates/version.txt"}
    url = f"https://github.com/godotengine/godot/releases/download/{ver}-stable/Godot_v{ver}-stable_export_templates.tpz"
    dest = os.path.expanduser(f"~/.local/share/godot/export_templates/{ver}.stable")
    os.makedirs(dest, exist_ok=True)
    size = total_size(url)
    tail = http_range(url, size - 65536 - 22, size - 1)
    # End Of Central Directory (eventualmente zip64)
    eocd = tail.rfind(b"PK\x05\x06")
    if eocd < 0:
        print("EOCD non trovato")
        return 1
    cd_size, cd_off = struct.unpack("<II", tail[eocd + 12:eocd + 20])
    loc64 = tail.rfind(b"PK\x06\x07")
    if cd_off == 0xFFFFFFFF and loc64 >= 0:
        (z64_off,) = struct.unpack("<Q", tail[loc64 + 8:loc64 + 16])
        z64 = http_range(url, z64_off, z64_off + 56 - 1)
        cd_size, cd_off = struct.unpack("<QQ", z64[40:56])
    cd = http_range(url, cd_off, cd_off + cd_size - 1)
    i = 0
    found = 0
    while i < len(cd) and cd[i:i + 4] == b"PK\x01\x02":
        method, = struct.unpack("<H", cd[i + 10:i + 12])
        csize, usize = struct.unpack("<II", cd[i + 20:i + 28])
        nlen, xlen, clen = struct.unpack("<HHH", cd[i + 28:i + 34])
        loff, = struct.unpack("<I", cd[i + 42:i + 46])
        name = cd[i + 46:i + 46 + nlen].decode()
        extra = cd[i + 46 + nlen:i + 46 + nlen + xlen]
        # campi zip64 negli extra
        j = 0
        while j + 4 <= len(extra):
            hid, hsz = struct.unpack("<HH", extra[j:j + 4])
            if hid == 1:
                vals = extra[j + 4:j + 4 + hsz]
                k = 0
                if usize == 0xFFFFFFFF:
                    usize, = struct.unpack("<Q", vals[k:k + 8]); k += 8
                if csize == 0xFFFFFFFF:
                    csize, = struct.unpack("<Q", vals[k:k + 8]); k += 8
                if loff == 0xFFFFFFFF:
                    loff, = struct.unpack("<Q", vals[k:k + 8]); k += 8
            j += 4 + hsz
        if name in wanted:
            lh = http_range(url, loff, loff + 30 - 1)
            ln, lx = struct.unpack("<HH", lh[26:30])
            data_start = loff + 30 + ln + lx
            print(f"scarico {name} ({csize / 1e6:.1f} MB compressi)")
            comp = http_range(url, data_start, data_start + csize - 1)
            raw = comp if method == 0 else zlib.decompress(comp, -15)
            out = os.path.join(dest, os.path.basename(name))
            with open(out, "wb") as f:
                f.write(raw)
            if out.endswith(".x86_64"):
                os.chmod(out, 0o755)
            found += 1
        i += 46 + nlen + xlen + clen
    print(f"installati {found} file in {dest}")
    return 0 if found == len(wanted) else 1


if __name__ == "__main__":
    sys.exit(main())
