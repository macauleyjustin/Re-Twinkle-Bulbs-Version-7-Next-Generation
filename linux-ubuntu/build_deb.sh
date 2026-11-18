#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist-artifacts"
CROSS_DIR="$ROOT_DIR/cross-platform"
VERSION="7.0.0"

mkdir -p "$DIST_DIR"

# Generate 256x256 RGBA PNG app icon using Pure Python stdlib (no Pillow needed)
ICON_PNG="$ROOT_DIR/linux-ubuntu/re-twinkle-bulbs.png"
python3 - "$ICON_PNG" <<'PY'
import math, struct, sys, zlib

w, h = 256, 256
buf = bytearray(w * h * 4)
cx = w * 0.5
cy = h * 0.54
for y in range(h):
    for x in range(w):
        idx = (y * w + x) * 4
        # Dark midnight navy rounded icon badge
        dx, dy = abs(x - 127.5), abs(y - 127.5)
        edge = max(dx, dy)
        corner_d = math.hypot(max(0, dx - 92), max(0, dy - 92))
        if corner_d > 34:
            continue
        r, g, b, a = 14, 24, 46, 255
        # Soft radial aura
        d_glow = math.hypot(x - cx, y - cy)
        if d_glow < 106:
            t = (1.0 - d_glow / 106.0) ** 2
            r = min(255, int(r + 120 * t))
            g = min(255, int(g + 35 * t))
            b = min(255, int(b + 20 * t))
        # Green wire across top
        if 22 <= y <= 34:
            r, g, b = 26, 108, 44
        # Gold socket
        if 34 <= y <= 62 and abs(x - cx) <= 24:
            shade = 1.0 - abs(x - cx) / 36.0
            r, g, b = int(212 * shade), int(170 * shade), int(56 * shade)
        # C9 Ruby Red bulb glass
        if y >= 62:
            t = (y - 62) / 162.0
            if 0.0 <= t <= 1.0:
                max_rad = 64 * (0.48 + 0.52 * (t / 0.36)) if t < 0.36 else 64 * math.cos(((t - 0.36) / 0.64) * math.pi * 0.5)
                if abs(x - cx) <= max_rad:
                    rel_x = (x - cx) / max(1, max_rad)
                    rim = max(0.35, 1.0 - 0.3 * rel_x * rel_x)
                    r, g, b = int(242 * rim), int(40 * rim), int(40 * rim)
                    if -0.58 < rel_x < -0.15 and 0.14 < t < 0.58:
                        r = min(255, r + 150)
                        g = min(255, g + 140)
                        b = min(255, b + 140)
        buf[idx:idx+4] = bytes((r, g, b, a))

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

raw_rows = b"".join(b"\x00" + bytes(buf[y*w*4:(y+1)*w*4]) for y in range(h))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw_rows, 9)) + chunk(b"IEND", b"")
with open(sys.argv[1], "wb") as f:
    f.write(png)
PY

build_arch() {
    local GOARCH="$1"
    local DEB_ARCH="$2"
    local STAGE="$ROOT_DIR/build_deb_${DEB_ARCH}"
    rm -rf "$STAGE"
    mkdir -p "$STAGE/DEBIAN" \
             "$STAGE/usr/bin" \
             "$STAGE/usr/lib/twinklebulbs" \
             "$STAGE/usr/share/applications" \
             "$STAGE/usr/share/icons/hicolor/256x256/apps" \
             "$STAGE/usr/share/doc/re-twinkle-bulbs"

    echo "=== Building Linux binary ($GOARCH -> Debian $DEB_ARCH) ==="
    (cd "$CROSS_DIR" && GOOS=linux GOARCH="$GOARCH" CGO_ENABLED=0 /opt/homebrew/bin/go build -trimpath -ldflags="-s -w" -o "$STAGE/usr/bin/twinklebulbs" ./cmd/twinklebulbs-linux)
    chmod 0755 "$STAGE/usr/bin/twinklebulbs"

    cp "$ROOT_DIR/linux-ubuntu/twinkle-overlay.py" "$STAGE/usr/lib/twinklebulbs/twinkle-overlay.py"
    chmod 0755 "$STAGE/usr/lib/twinklebulbs/twinkle-overlay.py"

    cp "$ICON_PNG" "$STAGE/usr/share/icons/hicolor/256x256/apps/re-twinkle-bulbs.png"
    chmod 0644 "$STAGE/usr/share/icons/hicolor/256x256/apps/re-twinkle-bulbs.png"

    cat > "$STAGE/usr/share/applications/re-twinkle-bulbs.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Version=1.0
Name=Re: Twinkle Bulbs
GenericName=Holiday Desktop Lights
Comment=Restored classic Twinkle Bulbs & Next Generation lighting (Tribute to Don Metzler & Barefoot Productions)
Exec=/usr/bin/twinklebulbs
Icon=re-twinkle-bulbs
Terminal=false
Categories=Utility;Amusement;AudioVideo;
StartupNotify=false
Actions=WebRemote;Docs;

[Desktop Action WebRemote]
Name=Open Web Command Center
Exec=/usr/bin/twinklebulbs --open-web

[Desktop Action Docs]
Name=Show History & Manual in Terminal
Exec=sh -c "/usr/bin/twinklebulbs --docs | less"
DESK
    chmod 0644 "$STAGE/usr/share/applications/re-twinkle-bulbs.desktop"

    cat > "$STAGE/usr/share/doc/re-twinkle-bulbs/copyright" <<'COPY'
Re: Twinkle Bulbs — Version 7: Next Generation (Ubuntu Edition)

Original Program Credit:
  Don Metzler & Barefoot Productions

Restoration Chronicle:
  This restored version brings Twinkle Bulbs back from the dead for a new era.
  Work started in 2025 with Google Antigravity, continued with intermediate
  versions in April of 2026 that did not yet function like the original, and
  achieved a complete, faithful original recreation in November of 2026 —
  expanded into Version 7: Next Generation.

License (Freeware):
  Distributed out of love for the original program to keep the memory and love
  for Twinkle Bulbs alive. Distributed freely as Freeware and may be used,
  shared, and modified as desired.
COPY
    chmod 0644 "$STAGE/usr/share/doc/re-twinkle-bulbs/copyright"
    cp "$ROOT_DIR/linux-ubuntu/README_UBUNTU.txt" "$STAGE/usr/share/doc/re-twinkle-bulbs/README" 2>/dev/null || true

    local SIZE_KB
    SIZE_KB="$(du -sk "$STAGE/usr" | awk '{print $1}')"

    cat > "$STAGE/DEBIAN/control" <<CTRL
Package: re-twinkle-bulbs
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${DEB_ARCH}
Installed-Size: ${SIZE_KB}
Maintainer: Re: Twinkle Bulbs Tribute Project <community@twinklebulbs.local>
Depends: libc6
Recommends: python3, python3-gi, gir1.2-gtk-3.0, python3-cairo, pipewire-bin | pulseaudio-utils | alsa-utils
Homepage: https://github.com/macauleyjustin/Re-Twinkle-Bulbs-Version-7-Next-Generation
Description: Restored holiday desktop lights & synthesizer (Tribute to Don Metzler & Barefoot Productions)
 Re: Twinkle Bulbs Version 7: Next Generation brings the classic Barefoot
 Productions desktop perimeter lights back from the dead across macOS,
 Windows, and Ubuntu Linux — complete with Classic v6.0 50ms flashing modes,
 Modern 60fps shaders, 16 Holiday Scenes, TwinkleSynth carols, and a Remote
 Web Command Center. Distributed as Freeware.
CTRL
    chmod 0644 "$STAGE/DEBIAN/control"

    cat > "$STAGE/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
POST
    chmod 0755 "$STAGE/DEBIAN/postinst"

    local DEB_TMP="$ROOT_DIR/deb_pack_${DEB_ARCH}"
    rm -rf "$DEB_TMP"
    mkdir -p "$DEB_TMP"
    printf "2.0\n" > "$DEB_TMP/debian-binary"

    local DEB_OUT="$DIST_DIR/re-twinkle-bulbs_${VERSION}_${DEB_ARCH}.deb"
    rm -f "$DEB_OUT"
    python3 - "$DEB_OUT" "$STAGE" "$DEB_TMP" <<'PY'
import os, sys, tarfile, time

deb_out, stage_dir, tmp_dir = sys.argv[1:4]
mtime = int(time.time())

def make_ustar_gz(src_dir, out_gz, include_root_prefix, skip_top=None):
    with tarfile.open(out_gz, "w:gz", format=tarfile.USTAR_FORMAT) as tf:
        for cur, dirs, files in os.walk(src_dir):
            dirs.sort()
            files.sort()
            rel = os.path.relpath(cur, src_dir)
            if skip_top and (rel == skip_top or rel.startswith(skip_top + os.sep)):
                continue
            entries = sorted(dirs + files)
            for name in entries:
                if skip_top and rel == "." and name == skip_top:
                    continue
                full = os.path.join(cur, name)
                rpath = os.path.relpath(full, src_dir).replace(os.sep, "/")
                arc = "./" + rpath if include_root_prefix else rpath
                ti = tf.gettarinfo(full, arcname=arc)
                ti.uid = 0
                ti.gid = 0
                ti.uname = "root"
                ti.gname = "root"
                ti.mtime = mtime
                if ti.isdir():
                    ti.mode = 0o755
                    tf.addfile(ti)
                else:
                    ti.mode = 0o755 if os.access(full, os.X_OK) else 0o644
                    with open(full, "rb") as fh:
                        tf.addfile(ti, fh)

ctrl_gz = os.path.join(tmp_dir, "control.tar.gz")
data_gz = os.path.join(tmp_dir, "data.tar.gz")
make_ustar_gz(os.path.join(stage_dir, "DEBIAN"), ctrl_gz, include_root_prefix=False)
make_ustar_gz(stage_dir, data_gz, include_root_prefix=True, skip_top="DEBIAN")

members = [os.path.join(tmp_dir, "debian-binary"), ctrl_gz, data_gz]
with open(deb_out, "wb") as out:
    out.write(b"!<arch>\n")
    for p in members:
        name = os.path.basename(p).encode("ascii")
        data = open(p, "rb").read()
        hdr = (
            name.ljust(16, b" ")
            + str(mtime).encode("ascii").ljust(12, b" ")
            + b"0     "
            + b"0     "
            + b"100644  "
            + str(len(data)).encode("ascii").ljust(10, b" ")
            + b"`\n"
        )
        assert len(hdr) == 60
        out.write(hdr)
        out.write(data)
        if len(data) % 2 == 1:
            out.write(b"\n")
PY

    rm -rf "$STAGE" "$DEB_TMP"
    echo "=== Built $DEB_OUT ==="
}

build_arch "amd64" "amd64"
build_arch "arm64" "arm64"
