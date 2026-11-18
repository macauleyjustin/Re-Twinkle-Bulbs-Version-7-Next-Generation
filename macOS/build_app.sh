#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="TwinkleBulbs"
BUNDLE_DIR="$ROOT_DIR/build/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"

echo "[1/5] Compiling ${APP_NAME} (release)..."
cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "Error: compiled binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "[2/5] Creating ${APP_NAME}.app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "[3/5] Generating Info.plist..."
sed -e 's/\$(EXECUTABLE_NAME)/TwinkleBulbs/g' \
    -e 's/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.twinklebulbs.mac.v6/g' \
    -e 's/\$(MACOSX_DEPLOYMENT_TARGET)/13.0/g' \
    "$ROOT_DIR/TwinkleBulbs/Info.plist" > "$CONTENTS_DIR/Info.plist"
plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null

echo "[4/5] Generating festive clean-room AppIcon.icns..."
ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
python3 - <<'PY' "$ICONSET_DIR"
import os, struct, zlib, sys, math

out_dir = sys.argv[1]

def write_png(path, size):
    buf = bytearray(size * size * 4)
    cx, cy = size * 0.5, size * 0.58
    rx, ry = size * 0.24, size * 0.30
    for y in range(size):
        for x in range(size):
            nx = (x - cx) / max(1.0, rx)
            ny = (y - cy) / max(1.0, ry)
            # Bulb cone + green socket at top
            r = g = b = a = 0
            # Outer card badge dark navy rounded bg
            bx = abs(x - size*0.5) / (size*0.44)
            by = abs(y - size*0.5) / (size*0.44)
            if max(bx, by) <= 1.0 and not (bx > 0.78 and by > 0.78 and ((bx-0.78)**2 + (by-0.78)**2) > 0.22**2):
                r, g, b, a = 12, 24, 48, 255
                d_glow = math.hypot(x - cx, y - cy) / (size * 0.45)
                if d_glow < 1.0:
                    glow = (1.0 - d_glow) ** 2
                    r = min(255, int(r + 190 * glow))
                    g = min(255, int(g + 165 * glow))
                    b = min(255, int(b + 55 * glow))
            # Socket at top
            if abs(x - cx) <= size * 0.11 and size * 0.14 <= y <= size * 0.30:
                r, g, b, a = 24, 128, 32, 255
            # Teardrop bulb body
            t = (y - size * 0.29) / (size * 0.60)
            if 0.0 <= t <= 1.0:
                half_w = math.sin(min(1.0, t * 0.92 + 0.12) * math.pi) * size * 0.24 * (1.0 - 0.32 * max(0.0, t - 0.4))
                dx = abs(x - cx)
                if dx <= half_w:
                    edge = dx / max(1.0, half_w)
                    shade = 1.0 - 0.35 * (edge ** 2)
                    spec = max(0.0, 1.0 - math.hypot(x - (cx - half_w*0.32), y - size*0.44) / (size*0.14))
                    r = min(255, int(255 * shade + 255 * spec * 0.6))
                    g = min(255, int(218 * shade + 255 * spec * 0.7))
                    b = min(255, int(48 * shade + 255 * spec * 0.9))
                    a = 255
            off = (y * size + x) * 4
            buf[off:off+4] = bytes((r, g, b, a))
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        raw.extend(buf[y*size*4:(y+1)*size*4])
    def chunk(ct, d):
        return struct.pack(">I4s", len(d), ct) + d + struct.pack(">I", zlib.crc32(ct + d) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)

for s in [16, 32, 64, 128, 256, 512]:
    write_png(os.path.join(out_dir, f"icon_{s}x{s}.png"), s)
    if s <= 256:
        write_png(os.path.join(out_dir, f"icon_{s}x{s}@2x.png"), s * 2)
PY
iconutil -c icns "$ICONSET_DIR" -o "$RES_DIR/AppIcon.icns" || true
rm -rf "$ICONSET_DIR"

echo "[5/5] Ad-hoc signing ${BUNDLE_DIR}..."
codesign --force --deep --sign - "$BUNDLE_DIR"
echo "Built clean native macOS bundle: $BUNDLE_DIR"
