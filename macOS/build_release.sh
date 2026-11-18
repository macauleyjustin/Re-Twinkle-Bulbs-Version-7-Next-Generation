#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DISPLAY="Re Twinkle Bulbs"
VERSION="7.0.0"
BUILD_NUM="700"
BUNDLE_ID="com.twinklebulbs.mac.v6"

DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$ROOT_DIR/build/release_stage"
APP_BUNDLE="$DIST_DIR/${APP_DISPLAY}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS="$ROOT_DIR/TwinkleBulbs/TwinkleBulbs.entitlements"

echo "=== [Phase 3] Building Release Binary ($APP_DISPLAY v$VERSION build $BUILD_NUM) ==="
cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/TwinkleBulbs"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "Error: Release binary not found at $BIN_PATH" >&2
    exit 1
fi

rm -rf "$DIST_DIR" "$STAGE_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR" "$STAGE_DIR"

cp "$BIN_PATH" "$MACOS_DIR/${APP_DISPLAY}"
chmod +x "$MACOS_DIR/${APP_DISPLAY}"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

sed -e "s|\$(EXECUTABLE_NAME)|${APP_DISPLAY}|g" \
    -e "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|${BUNDLE_ID}|g" \
    -e "s|\$(MACOSX_DEPLOYMENT_TARGET)|13.0|g" \
    "$ROOT_DIR/TwinkleBulbs/Info.plist" > "$CONTENTS_DIR/Info.plist"
plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null

echo "=== Generating AppIcon.icns ==="
ICONSET_DIR="$STAGE_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
python3 - <<'PY' "$ICONSET_DIR"
import os, struct, zlib, sys, math

out_dir = sys.argv[1]

def write_png(path, size):
    buf = bytearray(size * size * 4)
    cx, cy = size * 0.5, size * 0.58
    for y in range(size):
        for x in range(size):
            r = g = b = a = 0
            bx = abs(x - size * 0.5) / (size * 0.44)
            by = abs(y - size * 0.5) / (size * 0.44)
            if max(bx, by) <= 1.0 and not (bx > 0.78 and by > 0.78 and ((bx - 0.78) ** 2 + (by - 0.78) ** 2) > 0.22 ** 2):
                r, g, b, a = 12, 24, 48, 255
                d_glow = math.hypot(x - cx, y - cy) / (size * 0.45)
                if d_glow < 1.0:
                    glow = (1.0 - d_glow) ** 2
                    r = min(255, int(r + 190 * glow))
                    g = min(255, int(g + 165 * glow))
                    b = min(255, int(b + 55 * glow))
            if abs(x - cx) <= size * 0.11 and size * 0.14 <= y <= size * 0.30:
                r, g, b, a = 24, 128, 32, 255
            t = (y - size * 0.29) / (size * 0.60)
            if 0.0 <= t <= 1.0:
                half_w = math.sin(min(1.0, t * 0.92 + 0.12) * math.pi) * size * 0.24 * (1.0 - 0.32 * max(0.0, t - 0.4))
                dx = abs(x - cx)
                if dx <= half_w:
                    edge = dx / max(1.0, half_w)
                    shade = 1.0 - 0.35 * (edge ** 2)
                    spec = max(0.0, 1.0 - math.hypot(x - (cx - half_w * 0.32), y - size * 0.44) / (size * 0.14))
                    r = min(255, int(255 * shade + 255 * spec * 0.6))
                    g = min(255, int(218 * shade + 255 * spec * 0.7))
                    b = min(255, int(48 * shade + 255 * spec * 0.9))
                    a = 255
            off = (y * size + x) * 4
            buf[off:off + 4] = bytes((r, g, b, a))
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        raw.extend(buf[y * size * 4:(y + 1) * size * 4])
    def chunk(ct, d):
        return struct.pack(">I4s", len(d), ct) + d + struct.pack(">I", zlib.crc32(ct + d) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)

for s in [16, 32, 64, 128, 256, 512]:
    write_png(os.path.join(out_dir, f"icon_{s}x{s}.png"), s)
    if s <= 256:
        write_png(os.path.join(out_dir, f"icon_{s}x{s}@2x.png"), s * 2)
PY
iconutil -c icns "$ICONSET_DIR" -o "$RES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"
xattr -cr "$APP_BUNDLE"

echo "=== [Phase 4 & 5] Checking Apple Developer ID Signing Identity ==="
DEV_ID="${DEVELOPER_ID:-}"
if [[ -z "$DEV_ID" ]]; then
    DEV_ID="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
fi

SIGNED_STATUS="UNSIGNED"
if [[ -n "$DEV_ID" ]]; then
    echo "Signing with Developer ID: $DEV_ID"
    codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$DEV_ID" "$MACOS_DIR/${APP_DISPLAY}"
    codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$DEV_ID" "$APP_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        echo "Submitting app bundle for Apple notarization via profile: $NOTARY_PROFILE"
        APP_ZIP="$STAGE_DIR/ReTwinkleBulbs_notarize.zip"
        ditto -c -k --keepParent "$APP_BUNDLE" "$APP_ZIP"
        xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$APP_BUNDLE"
        xcrun stapler validate "$APP_BUNDLE"
        spctl -a -vvv -t exec "$APP_BUNDLE"
    fi
    SIGNED_STATUS="DEVELOPER_ID"
    DMG_NAME="Re-Twinkle-Bulbs-v${VERSION}-NextGen-macOS-arm64.dmg"
else
    echo "NOTE: No 'Developer ID Application' certificate in Keychain. Producing clearly labeled UNSIGNED testing package (ad-hoc signature)."
    codesign --force --sign - "$MACOS_DIR/${APP_DISPLAY}"
    codesign --force --sign - "$APP_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
    DMG_NAME="Re-Twinkle-Bulbs-v${VERSION}-NextGen-macOS-arm64-UNSIGNED.dmg"
fi

echo "=== [Phase 6] Creating Styled Drag-and-Drop DMG ($DMG_NAME) ==="
DMG_SRC="$STAGE_DIR/dmg_root"
DMG_BG_DIR="$DMG_SRC/.background"
RW_DMG="$STAGE_DIR/temp_rw.dmg"
FINAL_DMG="$DIST_DIR/${DMG_NAME}"

mkdir -p "$DMG_BG_DIR"
cp -R "$APP_BUNDLE" "$DMG_SRC/"
ln -s /Applications "$DMG_SRC/Applications"

# Render nostalgic Christmas DMG background (660x420) via CoreGraphics/Swift (zero external Python deps)
swift - "$DMG_BG_DIR/background.png" <<'SWIFT'
import AppKit
import CoreGraphics

let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
let w = 660, h = 420
guard let ctx = CGContext(
    data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let gCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = gCtx

// Midnight blue gradient sky
let bgColors = [
    NSColor(srgbRed: 0.03, green: 0.07, blue: 0.16, alpha: 1).cgColor,
    NSColor(srgbRed: 0.07, green: 0.16, blue: 0.32, alpha: 1).cgColor
] as CFArray
if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0, 1]) {
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(h)), options: [])
}

// Gentle falling snow dots
var rngState: UInt64 = 12252026
func nextRand() -> CGFloat {
    rngState = rngState &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((rngState >> 32) & 0xFFFF) / 65535.0
}
for _ in 0..<70 {
    let sx = nextRand() * CGFloat(w)
    let sy = nextRand() * CGFloat(h)
    let sz = 1.5 + nextRand() * 3.0
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.25 + nextRand() * 0.45).cgColor)
    ctx.fillEllipse(in: CGRect(x: sx, y: sy, width: sz, height: sz))
}

// Festive wire & glowing Christmas lights along top edge
ctx.setStrokeColor(NSColor(srgbRed: 0.05, green: 0.42, blue: 0.12, alpha: 1).cgColor)
ctx.setLineWidth(3.0)
ctx.move(to: CGPoint(x: 0, y: CGFloat(h - 14)))
ctx.addLine(to: CGPoint(x: CGFloat(w), y: CGFloat(h - 14)))
ctx.strokePath()

let palette: [NSColor] = [
    NSColor(srgbRed: 0.95, green: 0.18, blue: 0.18, alpha: 1),
    NSColor(srgbRed: 0.22, green: 0.88, blue: 0.30, alpha: 1),
    NSColor(srgbRed: 0.98, green: 0.84, blue: 0.22, alpha: 1),
    NSColor(srgbRed: 0.25, green: 0.65, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 0.86, green: 0.32, blue: 0.92, alpha: 1)
]
for i in 0..<15 {
    let bx = 22.0 + CGFloat(i) * 44.0
    let by = CGFloat(h - 38)
    let c = palette[i % palette.count]
    ctx.setFillColor(c.withAlphaComponent(0.26).cgColor)
    ctx.fillEllipse(in: CGRect(x: bx - 10, y: by - 8, width: 28, height: 28))
    ctx.setFillColor(NSColor(srgbRed: 0.08, green: 0.42, blue: 0.12, alpha: 1).cgColor)
    ctx.fill(CGRect(x: bx + 1, y: CGFloat(h - 20), width: 6, height: 8))
    ctx.setFillColor(c.cgColor)
    ctx.fillEllipse(in: CGRect(x: bx - 1, y: by - 1, width: 10, height: 15))
}

// Header Title
let titlePara = NSMutableParagraphStyle()
titlePara.alignment = .center
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 22),
    .foregroundColor: NSColor(srgbRed: 1.0, green: 0.91, blue: 0.42, alpha: 1),
    .paragraphStyle: titlePara
]
("Re: Twinkle Bulbs — Complete Holiday Edition" as NSString).draw(
    in: CGRect(x: 20, y: CGFloat(h - 92), width: CGFloat(w - 40), height: 32),
    withAttributes: titleAttrs
)

// Drag & drop arrow + prompt
ctx.setStrokeColor(NSColor(srgbRed: 1.0, green: 0.90, blue: 0.40, alpha: 0.9).cgColor)
ctx.setLineWidth(4.0)
ctx.move(to: CGPoint(x: 268, y: 200))
ctx.addLine(to: CGPoint(x: 386, y: 200))
ctx.addLine(to: CGPoint(x: 368, y: 214))
ctx.move(to: CGPoint(x: 386, y: 200))
ctx.addLine(to: CGPoint(x: 368, y: 186))
ctx.strokePath()

let instAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 15),
    .foregroundColor: NSColor.white,
    .paragraphStyle: titlePara
]
("Drag Re: Twinkle Bulbs to Applications" as NSString).draw(
    in: CGRect(x: 20, y: 54, width: CGFloat(w - 40), height: 26),
    withAttributes: instAttrs
)

let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11.5),
    .foregroundColor: NSColor(white: 0.80, alpha: 0.9),
    .paragraphStyle: titlePara
]
("Version 7.0.0 Next Generation • Freeware Tribute to Don Metzler & Barefoot Productions" as NSString).draw(
    in: CGRect(x: 20, y: 28, width: CGFloat(w - 40), height: 20),
    withAttributes: subAttrs
)

guard let img = ctx.makeImage(),
      let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: outURL)
SWIFT

hdiutil create -srcfolder "$DMG_SRC" -volname "Re Twinkle Bulbs" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW "$RW_DMG" >/dev/null

MOUNT_DEV="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk '/\/Volumes\/Re Twinkle Bulbs/ {print $1; exit}')"
MOUNT_POINT="/Volumes/Re Twinkle Bulbs"

if [[ -d "$MOUNT_POINT" ]]; then
    # Style Finder window icons & background via AppleScript (best-effort if Finder accepts automation)
    osascript <<APPLESCRIPT || echo "NOTE: Finder AppleEvent styling skipped/unavailable; DMG content & symlink remain valid."
tell application "Finder"
    tell disk "Re Twinkle Bulbs"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {240, 180, 900, 600}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 104
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.png"
        set position of item "Re Twinkle Bulbs.app" of container window to {175, 220}
        set position of item "Applications" of container window to {485, 220}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
    sync
    hdiutil detach "$MOUNT_DEV" -quiet || hdiutil detach "$MOUNT_POINT" -force -quiet
fi

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null
if [[ "$SIGNED_STATUS" == "DEVELOPER_ID" && -n "${NOTARY_PROFILE:-}" ]]; then
    codesign --force --sign "$DEV_ID" --timestamp "$FINAL_DMG"
    xcrun notarytool submit "$FINAL_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$FINAL_DMG"
    xcrun stapler validate "$FINAL_DMG"
fi
rm -rf "$STAGE_DIR"

echo "=== Generating SHA-256 Checksums ==="
(cd "$DIST_DIR" && shasum -a 256 "$DMG_NAME" "${APP_DISPLAY}.app/Contents/MacOS/${APP_DISPLAY}" > SHA256SUMS.txt)
cat "$DIST_DIR/SHA256SUMS.txt"

echo "=== Done: $FINAL_DMG ($SIGNED_STATUS) ==="
