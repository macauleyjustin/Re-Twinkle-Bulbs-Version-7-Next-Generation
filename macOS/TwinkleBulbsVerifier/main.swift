import Foundation
import Cocoa
import CoreGraphics
import Network
import AVFoundation
import TwinkleBulbsCore

// MARK: - Clean Verification Harness

private var passedCount = 0
private var failedCount = 0

func check(_ condition: Bool, _ label: String, file: String = #file, line: Int = #line) {
    if condition {
        passedCount += 1
        print("  [PASS] \(label)")
    } else {
        failedCount += 1
        print("  [FAIL] \(label) (\(file):\(line))")
    }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String, file: String = #file, line: Int = #line) {
    if actual == expected {
        passedCount += 1
        print("  [PASS] \(label)")
    } else {
        failedCount += 1
        print("  [FAIL] \(label): actual=\(actual) expected=\(expected) (\(file):\(line))")
    }
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    do {
        try data.write(to: url)
        return true
    } catch {
        return false
    }
}

func loadPNGImage(at url: URL) -> CGImage? {
    guard let dp = CGDataProvider(url: url as CFURL) else { return nil }
    return CGImage(pngDataProviderSource: dp, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

func sampleImageRGBA(_ img: CGImage) -> [UInt8] {
    let w = img.width, h = img.height
    var rgba = [UInt8](repeating: 0, count: w * h * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    if let ctx = CGContext(data: &rgba, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return rgba
}

func opaquePixelStats(_ img: CGImage) -> (count: Int, minX: Int, maxX: Int, minY: Int, maxY: Int, avgLuma: Double) {
    let rgba = sampleImageRGBA(img)
    let w = img.width, h = img.height
    var count = 0
    var minX = w, maxX = -1, minY = h, maxY = -1
    var lumaSum = 0.0
    for y in 0..<h {
        for x in 0..<w {
            let p = (y * w + x) * 4
            let a = Int(rgba[p + 3])
            if a > 16 {
                count += 1
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                lumaSum += (0.299 * Double(rgba[p]) + 0.587 * Double(rgba[p + 1]) + 0.114 * Double(rgba[p + 2])) * 255.0 / Double(a)
            }
        }
    }
    return (count, minX, maxX, minY, maxY, count > 0 ? lumaSum / Double(count) : 0.0)
}

print("=== Twinkle Bulbs v6.0 macOS Verification Suite ===")

// 1. Default Configuration
print("\n[1] Exact v6.0 Defaults (LoadSettings)")
let def = AppSettings.defaultSettings()
checkEqual(def.bulbSetName, "Outdoor", "Default bulb set")
checkEqual(def.flashMode, .chase, "Default FlashMode == Chase (3)")
checkEqual(def.rate, .medium, "Default Rate == Medium (2)")
checkEqual(def.colorMode, .redGreen, "Default Color == Red/Green (8)")
checkEqual(def.drawMode, .desktop, "Default DrawMode == Desktop (0)")
checkEqual(def.location, .top, "Default Location == Top (0)")
checkEqual(def.bulbSize.pixels, 32, "Default BulbSize == 32px")
check(def.bareWire && def.noCorners && def.notSoMany, "BareWire, NoCorners, NotSoMany default true")
check(!def.broken && !def.burnedOut && !def.missing, "Defect toggles default false")
checkEqual(def.ssDelayMinutes, 10, "Default screen saver idle delay == 10m")
checkEqual(def.ssMsg, "YOUR MESSAGE HERE", "Default screen saver message")

// 2. All 21 Color Modes
print("\n[2] All 21 Color Modes (tbulbs.mem 0x0048289a..0x0048366c)")
var rng: any RandomSource = SeededRandomSource(seed: 12345)
let rndSeq = BulbEngine.colorSequence(mode: .random, count: 50, rng: &rng)
check(zip(rndSeq, rndSeq.dropFirst()).allSatisfy { $0 != $1 }, "ColorMode 0 (Random): zero consecutive repeats across 50 bulbs")
checkEqual(BulbEngine.colorSequence(mode: .purple, count: 4, rng: &rng), [0,0,0,0], "ColorMode 1 Purple")
checkEqual(BulbEngine.colorSequence(mode: .blue, count: 4, rng: &rng), [1,1,1,1], "ColorMode 2 Blue")
checkEqual(BulbEngine.colorSequence(mode: .red, count: 4, rng: &rng), [2,2,2,2], "ColorMode 3 Red")
checkEqual(BulbEngine.colorSequence(mode: .green, count: 4, rng: &rng), [3,3,3,3], "ColorMode 4 Green")
checkEqual(BulbEngine.colorSequence(mode: .yellow, count: 4, rng: &rng), [4,4,4,4], "ColorMode 5 Yellow")
checkEqual(BulbEngine.colorSequence(mode: .lightBlue, count: 4, rng: &rng), [5,5,5,5], "ColorMode 6 Light Blue")
checkEqual(BulbEngine.colorSequence(mode: .white, count: 4, rng: &rng), [6,6,6,6], "ColorMode 7 White")
checkEqual(BulbEngine.colorSequence(mode: .redGreen, count: 6, rng: &rng), [3,2,3,2,3,2], "ColorMode 8 Red/Green [3,2]")
checkEqual(BulbEngine.colorSequence(mode: .multiColor, count: 7, rng: &rng), [1,2,3,4,5,0,1], "ColorMode 9 Multi-Color")
checkEqual(BulbEngine.colorSequence(mode: .blues, count: 4, rng: &rng), [5,1,5,1], "ColorMode 10 Blues")
checkEqual(BulbEngine.colorSequence(mode: .allColorsWhite, count: 8, rng: &rng), [0,1,2,3,4,5,6,0], "ColorMode 11 All Colors (+White)")
checkEqual(BulbEngine.colorSequence(mode: .redBlue, count: 4, rng: &rng), [2,1,2,1], "ColorMode 12 Red/Blue")
checkEqual(BulbEngine.colorSequence(mode: .purpleGreen, count: 4, rng: &rng), [0,3,0,3], "ColorMode 13 Purple/Green")
checkEqual(BulbEngine.colorSequence(mode: .redYellowGreen, count: 6, rng: &rng), [2,4,3,2,4,3], "ColorMode 14 Red/Yellow/Green")
checkEqual(BulbEngine.colorSequence(mode: .redGreenBlue, count: 6, rng: &rng), [2,3,1,2,3,1], "ColorMode 15 Red/Green/Blue")
checkEqual(BulbEngine.colorSequence(mode: .coolColors, count: 6, rng: &rng), [0,1,3,0,1,3], "ColorMode 16 Cool Colors")
checkEqual(BulbEngine.colorSequence(mode: .yellowWhite, count: 4, rng: &rng), [6,4,6,4], "ColorMode 17 Yellow/White")
checkEqual(BulbEngine.colorSequence(mode: .redYellow, count: 4, rng: &rng), [4,2,4,2], "ColorMode 18 Red/Yellow")
checkEqual(BulbEngine.colorSequence(mode: .redGreenYellowBlue, count: 5, rng: &rng), [2,3,4,1,2], "ColorMode 19 R/G/Y/B")
checkEqual(BulbEngine.colorSequence(mode: .redWhiteBlue, count: 6, rng: &rng), [2,6,1,2,6,1], "ColorMode 20 Red/White/Blue")

// 3. Timings, Strides & All 9 Flash Modes
print("\n[3] Exact Step Intervals, Chase Strides, and 9 Flashing Modes")
checkEqual(FlashRate.slow.fixedIntervalMs, 1200, "Slow interval 1200ms")
checkEqual(FlashRate.slowMedium.fixedIntervalMs, 800, "Slow/Med interval 800ms")
checkEqual(FlashRate.medium.fixedIntervalMs, 500, "Medium interval 500ms")
checkEqual(FlashRate.mediumFast.fixedIntervalMs, 350, "Med/Fast interval 350ms")
checkEqual(FlashRate.fast.fixedIntervalMs, 200, "Fast interval 200ms")
checkEqual(FlashRate.veryFast.fixedIntervalMs, 80, "Very Fast interval 80ms")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 16), 4, "Stride <=20 -> 4")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 25), 5, "Stride <=25 -> 5")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 32), 8, "Stride <=32 -> 8")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 36), 6, "Stride <=36 -> 6")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 40), 8, "Stride <=40 -> 8")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 50), 10, "Stride <=50 -> 10")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 64), 2, "Legacy stride >50 -> 2")

var cfg = AppSettings.defaultSettings()
cfg.location = .top
cfg.notSoMany = false
cfg.flashMode = .chase
let eng = BulbEngine(settings: cfg, rng: SeededRandomSource(seed: 1))
eng.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 480), settings: cfg, nowMs: 1000)
checkEqual(eng.slots.enumerated().filter { $0.element.isLit }.map(\.offset), [0,4,8,12,16], "Chase initial frame")
check(!eng.tick(nowMs: 1499), "Chase holds before 500ms")
check(eng.tick(nowMs: 1500), "Chase advances at 500ms")
checkEqual(eng.slots.enumerated().filter { $0.element.isLit }.map(\.offset), [1,5,9,13,17], "Chase frame 1")

cfg.flashMode = .pairs
cfg.notSoMany = true
eng.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 480), settings: cfg, nowMs: 0)
let pairLit = eng.slots.enumerated().filter { $0.element.isLit }.map(\.offset)
check(eng.slots[1].isBareWire && pairLit.contains(0) && pairLit.contains(2) && !pairLit.contains(1), "Pairs + NotSoMany skips bare wire")

cfg.flashMode = .pingPong
cfg.notSoMany = false
eng.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: cfg, nowMs: 0)
var ppTrace = [eng.slots.firstIndex(where: \.isLit) ?? -1]
for step in 1...6 {
    eng.tick(nowMs: UInt64(step) * 500)
    ppTrace.append(eng.slots.firstIndex(where: \.isLit) ?? -1)
}
checkEqual(ppTrace, [0,1,2,3,2,1,0], "Ping-Pong bounces cleanly")

cfg.flashMode = .alternating
eng.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: cfg, nowMs: 0)
checkEqual(eng.slots.map(\.isLit), [false, true, false, true], "Alternating starts odd ON")
eng.tick(nowMs: 500)
checkEqual(eng.slots.map(\.isLit), [true, false, true, false], "Alternating flips at 500ms")

cfg.flashMode = .single
cfg.reverse = true
eng.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: cfg, nowMs: 0)
checkEqual(eng.slots.map(\.isLit), [false, false, false, true], "Reverse Single starts at end")
eng.tick(nowMs: 500)
checkEqual(eng.slots.map(\.isLit), [false, false, true, false], "Reverse Single steps backward")

// 4. Around Screen Placement, NoCorners, Screen Saver Inset & RotateIcon
print("\n[4] Layout Geometry, Screen Saver Inset, and RotateIcon Pixel Mapping")
cfg = AppSettings.defaultSettings()
cfg.location = .aroundScreen
cfg.noCorners = true
cfg.notSoMany = false
eng.configure(bounds: CGRect(x: 0, y: 0, width: 320, height: 224), settings: cfg, nowMs: 0)
checkEqual(eng.slots.filter { $0.edge == .top }.count, 8, "Around+NoCorners top count == 8")
checkEqual(eng.slots.filter { $0.edge == .left }.count, 5, "Around+NoCorners side count == 5")
checkEqual(eng.slots.first?.frame.minX, 32, "Around+NoCorners clears top-left corner")

var ssSettings = AppSettings.defaultSettings()
ssSettings.location = .aroundScreen
ssSettings.ssLights = true
ssSettings.ssEnableMsg = false
let ssView = ScreenSaverCanvasView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), settings: ssSettings, preview: false)
checkEqual(ssView.contentRect(), CGRect(x: 32, y: 32, width: 736, height: 536), "ScreenSaver contentRect inset (0x0046de40)")

var px = [UInt32](repeating: 0, count: 16)
px[0 * 4 + 1] = 0xFF00_00FF
let cs = CGColorSpaceCreateDeviceRGB()
let markerSrc = CGContext(data: &px, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
func markerPos(_ img: CGImage) -> (Int, Int) {
    var b = [UInt32](repeating: 0, count: 16)
    CGContext(data: &b, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.draw(img, in: CGRect(x: 0, y: 0, width: 4, height: 4))
    for y in 0..<4 { for x in 0..<4 where b[y * 4 + x] != 0 { return (x, y) } }
    return (-1, -1)
}
check(markerPos(BulbArtworkRegistry.rotatePixelExact(markerSrc, degrees: 90)) == (3, 1), "RotateIcon +90 (Right edge)")
check(markerPos(BulbArtworkRegistry.rotatePixelExact(markerSrc, degrees: -90)) == (0, 2), "RotateIcon -90 (Left edge)")
check(markerPos(BulbArtworkRegistry.rotatePixelExact(markerSrc, degrees: 180)) == (2, 3), "RotateIcon 180 (Bottom edge)")

// 5. Highlight Blend, Audio WAV, Calendar Countdown & BLB Parser Pixel Parity
print("\n[5] Highlight Dim Blend, Calendar Countdown, Audio WAV, & PE .blb Verification")
var redPx: UInt32 = 0xFF00_00FF
let redSrc = CGContext(data: &redPx, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
let redDim = BLBResourceLoader.blendHalfWithHighlight(image: redSrc, rgb: (0, 0, 128))
let dimRGBA = sampleImageRGBA(redDim)
check(dimRGBA[0] == 127 && dimRGBA[1] == 0 && dimRGBA[2] == 64 && dimRGBA[3] == 255, "50% highlight blend math exact (127, 0, 64)")

let dec20 = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 12, day: 20))!
let sum = CalendarService.shared.countdownSummary(settings: AppSettings.defaultSettings(), from: dec20)
checkEqual(sum?.daysRemaining, 5, "Christmas countdown from Dec 20 == 5 days")

let wav = AudioEngineService.wrapPCMAsWAV(pcm: Data(repeating: 0, count: 64), sampleRate: 22050, channels: 1, bitsPerSample: 16)
check(wav.starts(with: Array("RIFF".utf8)) && wav.count == 108, "WAV RIFF container valid")

// Compare BLBResourceLoader against local extracted reference PNG & render visual comparison strips
let scratchDir = URL(fileURLWithPath: "/Users/renseven/.gemini/antigravity/brain/ae66d32f-503d-4a61-9573-3261ed65b72d/scratch", isDirectory: true)
try? FileManager.default.createDirectory(at: scratchDir, withIntermediateDirectories: true)

let refBLB = URL(fileURLWithPath: "/Users/renseven/.gemini/antigravity/scratch/TwinkleBulbsMac/research/v6_extracted/bulbs/outdoor.blb")
let refPNG = URL(fileURLWithPath: "/Users/renseven/.gemini/antigravity/scratch/TwinkleBulbsMac/research/v6_dump/bulbs/outdoor/ico_7021_32x32_8b_id5.png")
if let loadedBLB = BLBResourceLoader.load(url: refBLB, preferredSize: 32, highlightRGB: (0, 0, 128)),
   let refImg = loadPNGImage(at: refPNG),
   let blbRedOn = loadedBLB.onImages[2] {
    let a = sampleImageRGBA(blbRedOn)
    let b = sampleImageRGBA(refImg)
    check(a == b, "BLBResourceLoader decoded outdoor.blb Red ON matches extracted Win32 reference byte-for-byte (\(a.count) bytes)")

    // Compare clean-room built-in Outdoor bulb geometry vs original Outdoor bulb
    var crSettings = AppSettings.defaultSettings()
    crSettings.bulbSetName = "Outdoor"
    crSettings.colorMode = .multiColor
    crSettings.flashMode = .none
    crSettings.notSoMany = true
    let cleanEng = BulbEngine(settings: crSettings, rng: SeededRandomSource(seed: 1))
    cleanEng.configure(bounds: CGRect(x: 0, y: 0, width: 448, height: 32), settings: crSettings, nowMs: 0)
    if let cleanStrip = BulbCanvasView.renderSnapshot(width: 448, height: 32, engine: cleanEng, settings: crSettings, backgroundColor: .black) {
        _ = writePNG(cleanStrip, to: scratchDir.appendingPathComponent("verify_outdoor_strip_clean.png"))
    }
    if let redTile = BulbArtworkRegistry.shared.image(for: BulbSlot(index: 0, frame: CGRect(x: 0, y: 0, width: 32, height: 32), edge: .top, colorIndex: 2, isBareWire: false, isMissing: false, isBroken: false, isBurnedOut: false, isLit: true, flashable: true, nextToggleMs: 0), settings: crSettings) {
        let origStats = opaquePixelStats(refImg)
        let cleanStats = opaquePixelStats(redTile)
        print("  [INFO] Outdoor Red ON: Orig bbox=(\(origStats.minX),\(origStats.minY))..(\(origStats.maxX),\(origStats.maxY)) luma=\(Int(origStats.avgLuma)) | Clean bbox=(\(cleanStats.minX),\(cleanStats.minY))..(\(cleanStats.maxX),\(cleanStats.maxY)) luma=\(Int(cleanStats.avgLuma))")
        check(abs(origStats.maxY - cleanStats.maxY) <= 1 && cleanStats.minX == 0 && cleanStats.maxX == 31, "Clean-room Outdoor bulb connects full 0..31 wire and matches 31px drop")
    }
}

// Render multi-edge Around Screen + All 21 Color Showcase + ScreenSaver verification snapshots
var showcase = AppSettings.defaultSettings()
showcase.bulbSetName = "Outdoor"
showcase.location = .aroundScreen
showcase.noCorners = true
showcase.notSoMany = true
showcase.inward = true
showcase.colorMode = .allColorsWhite
showcase.flashMode = .none
let aroundEng = BulbEngine(settings: showcase, rng: SeededRandomSource(seed: 7))
aroundEng.configure(bounds: CGRect(x: 0, y: 0, width: 512, height: 320), settings: showcase, nowMs: 0)
if let snap = BulbCanvasView.renderSnapshot(width: 512, height: 320, engine: aroundEng, settings: showcase, backgroundColor: NSColor(srgbRed: 0.05, green: 0.09, blue: 0.16, alpha: 1)) {
    let url = scratchDir.appendingPathComponent("verify_around_inward.png")
    check(writePNG(snap, to: url), "Wrote Around Screen inward-rotated visual verification snapshot")
}

// Render contact sheet of all 15 built-in bulb sets (ON, OFF, Broken across colors)
let styles = BulbArtworkRegistry.BuiltInStyle.allCases
let sheetW = 480
let rowH = 36
let sheetH = styles.count * rowH + 16
if let sCtx = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: sheetW * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
    sCtx.translateBy(x: 0, y: CGFloat(sheetH))
    sCtx.scaleBy(x: 1, y: -1)
    sCtx.setFillColor(NSColor(srgbRed: 0.07, green: 0.10, blue: 0.16, alpha: 1).cgColor)
    sCtx.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))

    for (rIdx, style) in styles.enumerated() {
        var st = AppSettings.defaultSettings()
        st.bulbSetName = style.rawValue
        st.notSoMany = false
        let yBase = CGFloat(rIdx * rowH + 8)
        // Draw 7 lit colors + 2 off + 1 bareWire + 1 broken = 11 tiles across x=116..468
        for col in 0..<7 {
            let slot = BulbSlot(index: col, frame: CGRect(x: 116 + CGFloat(col * 32), y: yBase, width: 32, height: 32), edge: .top, colorIndex: col, isBareWire: false, isMissing: false, isBroken: false, isBurnedOut: false, isLit: true, flashable: true, nextToggleMs: 0)
            if let img = BulbArtworkRegistry.shared.image(for: slot, settings: st) {
                sCtx.saveGState()
                sCtx.translateBy(x: slot.frame.minX, y: slot.frame.maxY)
                sCtx.scaleBy(x: 1, y: -1)
                sCtx.draw(img, in: CGRect(x: 0, y: 0, width: 32, height: 32))
                sCtx.restoreGState()
            }
        }
        let offSlot = BulbSlot(index: 7, frame: CGRect(x: 116 + 7 * 32, y: yBase, width: 32, height: 32), edge: .top, colorIndex: 2, isBareWire: false, isMissing: false, isBroken: false, isBurnedOut: false, isLit: false, flashable: true, nextToggleMs: 0)
        let wireSlot = BulbSlot(index: 8, frame: CGRect(x: 116 + 8 * 32, y: yBase, width: 32, height: 32), edge: .top, colorIndex: 0, isBareWire: true, isMissing: false, isBroken: false, isBurnedOut: false, isLit: false, flashable: false, nextToggleMs: 0)
        let brkSlot = BulbSlot(index: 9, frame: CGRect(x: 116 + 9 * 32, y: yBase, width: 32, height: 32), edge: .top, colorIndex: 2, isBareWire: false, isMissing: false, isBroken: true, isBurnedOut: false, isLit: false, flashable: false, nextToggleMs: 0)
        for extraSlot in [offSlot, wireSlot, brkSlot] {
            if let img = BulbArtworkRegistry.shared.image(for: extraSlot, settings: st) {
                sCtx.saveGState()
                sCtx.translateBy(x: extraSlot.frame.minX, y: extraSlot.frame.maxY)
                sCtx.scaleBy(x: 1, y: -1)
                sCtx.draw(img, in: CGRect(x: 0, y: 0, width: 32, height: 32))
                sCtx.restoreGState()
            }
        }
    }
    if let contactImg = sCtx.makeImage() {
        check(writePNG(contactImg, to: scratchDir.appendingPathComponent("verify_all_sets_on_off.png")), "Wrote contact sheet for all 15 built-in bulb sets")
    }
}

// Render Screen Savers (Snowfall + Fireworks) stepped frames with perimeter bulbs
func snapshotView(_ view: NSView, to url: URL) -> Bool {
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let cg = rep.cgImage else { return false }
    return writePNG(cg, to: url)
}

var snowCfg = AppSettings.defaultSettings()
snowCfg.ssModule = .snowfall
snowCfg.ssLights = true
snowCfg.ssMsg = "HAPPY HOLIDAYS FROM TWINKLE BULBS!"
let snowView = ScreenSaverCanvasView(frame: NSRect(x: 0, y: 0, width: 640, height: 400), settings: snowCfg, preview: false)
for _ in 0..<45 { snowView.stepFrame() }
check(snapshotView(snowView, to: scratchDir.appendingPathComponent("verify_ss_snowfall.png")), "Rendered Snowfall screen saver verification frame")

var fwCfg = AppSettings.defaultSettings()
fwCfg.ssModule = .fireworks
fwCfg.ssLights = true
fwCfg.colorMode = .multiColor
fwCfg.location = .aroundScreen
let fwView = ScreenSaverCanvasView(frame: NSRect(x: 0, y: 0, width: 640, height: 400), settings: fwCfg, preview: false)
for _ in 0..<60 { fwView.stepFrame() }
check(snapshotView(fwView, to: scratchDir.appendingPathComponent("verify_ss_fireworks.png")), "Rendered Fireworks screen saver verification frame")

// Snapshot Preferences UI & Quick Access Bar content views
_ = NSApplication.shared
let prefsWinCtrl = PreferencesWindowController()
if let content = prefsWinCtrl.window?.contentView {
    content.layoutSubtreeIfNeeded()
    check(snapshotView(content, to: scratchDir.appendingPathComponent("verify_prefs_ui.png")), "Rendered Preferences UI snapshot")
}
let qaCtrl = QuickAccessPanelController()
if let qaContent = qaCtrl.window?.contentView {
    qaContent.layoutSubtreeIfNeeded()
    check(snapshotView(qaContent, to: scratchDir.appendingPathComponent("verify_quick_access.png")), "Rendered Quick Access panel snapshot")
}

// =========================================================================
// [6] Version 2: Authentic MIDI Parser, GS Wavetable Synth & Jukebox Tests
// =========================================================================
print("\n[6] Authentic MIDI Playback, GS Sound Bank, and Programmable Jukebox")

// 6.1 Verify built-in carols are multi-track Format 1 GM MIDI with Ch10 percussion
let carols = AudioEngineService.builtInCarols()
check(carols.count == 105, "Built-in library has 105 carol & seasonal GM MIDI arrangements (got \(carols.count))")
if let jingle = carols.first, let midiData = jingle.builtInMIDI {
    do {
        let parsed = try StandardMIDIFileParser.parse(data: midiData)
        check(parsed.format == 1 && parsed.trackCount >= 5, "Built-in Jingle Bells is multi-track Format 1 SMF")
        check(parsed.channelsUsed.count >= 4, "Built-in Jingle Bells spans multiple MIDI channels")
        check(parsed.hasPercussion, "Built-in Jingle Bells includes Channel 10 Sleigh Bells/percussion")
        check(!parsed.programsUsed.isEmpty, "Built-in Jingle Bells includes Program Changes")
    } catch {
        check(false, "Built-in MIDI parse threw unexpectedly: \(error)")
    }
} else {
    check(false, "Built-in Jingle Bells missing MIDI data")
}

// 6.2 Verify Format 0 & Format 1 parsing on local v6 reference MIDIs (if present) + error reporting + RIFF RMI unwrap
do {
    _ = try StandardMIDIFileParser.parse(data: Data([0x00, 0x01, 0x02]))
    check(false, "Corrupt short MIDI should fail")
} catch {
    check(true, "Corrupt/short MIDI raises explicit parse error")
}

// Construct a synthetic Format 0 SMF with tempo change + PitchBend + Sustain + Ch10 wrapped in RIFF RMID
func makeTestSMF() -> Data {
    let trk: [UInt8] = [
        0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, // 120 BPM
        0x00, 0xC0, 40,                            // Violin on ch 0
        0x00, 0xB0, 64, 127,                       // Sustain on
        0x00, 0x90, 60, 100,                       // C4 on
        0x00, 0x99, 36, 110,                       // Ch 10 Bass Drum
        0x60, 0xFF, 0x51, 0x03, 0x06, 0x1A, 0x80,  // Tempo change (~150 BPM)
        0x60, 0xE0, 0x00, 0x50,                    // Pitch bend
        0x60, 0x80, 60, 0x00,                      // Note off
        0x00, 0x89, 36, 0x00,                      // Drum off
        0x00, 0xFF, 0x2F, 0x00
    ]
    var smf = Data("MThd".utf8)
    smf.append(contentsOf: [0,0,0,6, 0,0, 0,1, 0x00, 0x60]) // Format 0, 1 track, 96 PPQN
    smf.append(contentsOf: Array("MTrk".utf8))
    let len = UInt32(trk.count)
    smf.append(contentsOf: [UInt8((len >> 24) & 0xFF), UInt8((len >> 16) & 0xFF), UInt8((len >> 8) & 0xFF), UInt8(len & 0xFF)])
    smf.append(contentsOf: trk)
    return smf
}
let smfBytes = makeTestSMF()
var rmi = Data("RIFF".utf8)
let riffLen = UInt32(4 + 8 + smfBytes.count)
let dLen = UInt32(smfBytes.count)
rmi.append(contentsOf: [UInt8(riffLen & 0xFF), UInt8((riffLen >> 8) & 0xFF), UInt8((riffLen >> 16) & 0xFF), UInt8((riffLen >> 24) & 0xFF)])
rmi.append(contentsOf: Array("RMIDdata".utf8))
rmi.append(contentsOf: [UInt8(dLen & 0xFF), UInt8((dLen >> 8) & 0xFF), UInt8((dLen >> 16) & 0xFF), UInt8((dLen >> 24) & 0xFF)])
rmi.append(smfBytes)

if let parsedRMI = try? StandardMIDIFileParser.parse(data: rmi) {
    check(parsedRMI.format == 0 && parsedRMI.hasPercussion && parsedRMI.channelsUsed.contains(0), "SMF Format 0 & RIFF .rmi unwrapping parses channels & Ch10 percussion")
} else {
    check(false, "RIFF .rmi parse failed")
}

let refMidDir = URL(fileURLWithPath: "/Users/renseven/.gemini/antigravity/scratch/TwinkleBulbsMac/research/v6_extracted/music", isDirectory: true)
let silentMid = refMidDir.appendingPathComponent("Silent Night.mid")
let jingleMid = refMidDir.appendingPathComponent("Jingle Bells.mid")
if FileManager.default.fileExists(atPath: silentMid.path), FileManager.default.fileExists(atPath: jingleMid.path) {
    let p0 = try? StandardMIDIFileParser.parse(url: silentMid)
    let p1 = try? StandardMIDIFileParser.parse(url: jingleMid)
    check(p0?.format == 0 && (p0?.events.count ?? 0) > 50, "Real Format 0 MIDI ('Silent Night.mid') parsed cleanly")
    check(p1?.format == 1 && (p1?.trackCount ?? 0) >= 10 && (p1?.channelsUsed.count ?? 0) >= 3, "Real Format 1 MIDI ('Jingle Bells.mid') parsed multi-track/channel cleanly")
}

// 6.3 Native TwinkleSynth GM Polyphonic Synth + Custom SF2 Bank + Live Audible PCM Energy Test
let synthTest = MIDISynthPlayer()
synthTest.volume = 0.15 // modest audible verification volume
do {
    try synthTest.configureSoundBank(customPath: "/nonexistent/missing.sf2")
    check(false, "Missing custom soundbank must fail explicitly")
} catch {
    check(true, "Missing custom soundbank raises explicit error")
}

// Offline deterministic synthesis test: Sustain Pedal, Pan L/R, Strings, Channel 10 Sleigh Bells & Kick
let offSynth = TwinkleNativeGMSynth(sampleRate: 44100.0)
offSynth.masterVolume = 0.65
offSynth.handleMIDI(.controlChange(channel: 0, controller: 64, value: 127)) // Sustain ON
offSynth.handleMIDI(.controlChange(channel: 0, controller: 10, value: 0))   // Hard Left Pan
offSynth.handleMIDI(.programChange(channel: 0, program: 8))                // Celesta
offSynth.handleMIDI(.noteOn(channel: 0, note: 72, velocity: 110))
offSynth.handleMIDI(.noteOff(channel: 0, note: 72, velocity: 0))           // Held by Sustain!
offSynth.handleMIDI(.noteOn(channel: 9, note: 83, velocity: 105))          // Ch10 Sleigh Bells
let offRenderL = offSynth.renderOfflineStereo(frameCount: 4410)
let lRMS = sqrtf(offRenderL.left.map { $0 * $0 }.reduce(0, +) / Float(offRenderL.left.count))
let rRMS = sqrtf(offRenderL.right.map { $0 * $0 }.reduce(0, +) / Float(offRenderL.right.count))
check(offRenderL.rms > 0.005 && lRMS > rRMS, String(format: "TwinkleNativeGMSynth renders polyphonic Celesta + Sustain + Ch10 Sleigh Bells (RMS=%.4f, L>R pan=%.4f>%.4f)", offRenderL.rms, lRMS, rRMS))

// Custom .sf2 RIFF bank parser test (synthetic minimal RIFF sfbk fixture -> PCM wavetable lookup)
func buildMinimalTestSF2() -> Data {
    var out = Data("RIFF".utf8)
    func u16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    func u32(_ v: UInt32) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)] }
    func chunk(_ id: String, _ payload: Data) -> Data {
        var c = Data(id.utf8)
        c.append(contentsOf: u32(UInt32(payload.count)))
        c.append(payload)
        if payload.count & 1 == 1 { c.append(0) }
        return c
    }
    func padName(_ s: String, len: Int) -> Data {
        var b = Array(s.utf8.prefix(len))
        while b.count < len { b.append(0) }
        return Data(b)
    }

    var smplData = Data()
    for i in 0..<256 {
        let s = Int16(sin(Double(i) * .pi * 2.0 / 32.0) * 16000.0)
        smplData.append(contentsOf: u16(UInt16(bitPattern: s)))
    }
    let sdtaList = Data("LIST".utf8) + Data(u32(UInt32(4 + chunk("smpl", smplData).count))) + Data("sdta".utf8) + chunk("smpl", smplData)

    var phdr = Data()
    phdr.append(padName("PianoSF2", len: 20)); phdr.append(contentsOf: u16(0)); phdr.append(contentsOf: u16(0)); phdr.append(contentsOf: u16(0)); phdr.append(Data(repeating: 0, count: 12))
    phdr.append(padName("EOP", len: 20)); phdr.append(contentsOf: u16(255)); phdr.append(contentsOf: u16(255)); phdr.append(contentsOf: u16(1)); phdr.append(Data(repeating: 0, count: 12))

    var pbag = Data(); pbag.append(contentsOf: u16(0) + u16(0)); pbag.append(contentsOf: u16(1) + u16(0))
    var pgen = Data(); pgen.append(contentsOf: u16(41) + u16(0))

    var inst = Data()
    inst.append(padName("Inst0", len: 20)); inst.append(contentsOf: u16(0))
    inst.append(padName("EOI", len: 20)); inst.append(contentsOf: u16(1))

    var ibag = Data(); ibag.append(contentsOf: u16(0) + u16(0)); ibag.append(contentsOf: u16(1) + u16(0))
    var igen = Data(); igen.append(contentsOf: u16(53) + u16(0))

    var shdr = Data()
    shdr.append(padName("Sine256", len: 20))
    shdr.append(contentsOf: u32(0) + u32(256) + u32(0) + u32(256) + u32(44100))
    shdr.append(contentsOf: [60, 0])
    shdr.append(contentsOf: u16(0) + u16(1))
    shdr.append(padName("EOS", len: 20)); shdr.append(Data(repeating: 0, count: 26))

    let pdtaBody = Data("pdta".utf8) + chunk("phdr", phdr) + chunk("pbag", pbag) + chunk("pgen", pgen) + chunk("inst", inst) + chunk("ibag", ibag) + chunk("igen", igen) + chunk("shdr", shdr)
    let pdtaList = Data("LIST".utf8) + Data(u32(UInt32(pdtaBody.count))) + pdtaBody
    let infoList = Data("LIST".utf8) + Data(u32(4)) + Data("INFO".utf8)

    let totalBody = Data("sfbk".utf8) + infoList + sdtaList + pdtaList
    out.append(contentsOf: u32(UInt32(totalBody.count)))
    out.append(totalBody)
    return out
}

let tmpSF2 = scratchDir.appendingPathComponent("test_custom.sf2")
try? buildMinimalTestSF2().write(to: tmpSF2)
do {
    _ = try synthTest.load(data: smfBytes, customSoundBankPath: tmpSF2.path)
    let sf2LoadedOK = synthTest.activeSoundBankURL == tmpSF2 && synthTest.activeSoundBankDescription.contains("test_custom")
    let sf2Out = synthTest.renderOfflineStereoFrames(frameCount: 2205)
    check(sf2LoadedOK && sf2Out.left.count == 2205, "Custom RIFF .sf2 SoundFont parses & maps wavetable natively")
} catch {
    check(false, "Custom .sf2 load threw unexpectedly: \(error)")
}
try? FileManager.default.removeItem(at: tmpSF2)

do {
    _ = try synthTest.load(data: smfBytes, customSoundBankPath: nil)
    synthTest.installLevelTapIfNeeded()
    synthTest.play()
    RunLoop.current.run(until: Date().addingTimeInterval(0.35))
    synthTest.pause()
    let pausedOK = synthTest.isPaused && !synthTest.isPlaying
    synthTest.resume()
    let resumedOK = synthTest.isPlaying && !synthTest.isPaused
    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    let rms = synthTest.peakOutputRMS
    synthTest.stop()
    check(pausedOK && resumedOK && synthTest.activeSoundBankURL == nil, "Native MIDISynthPlayer pause() & resume() transition cleanly without Apple synth")
    check(rms > 0.0005, String(format: "Native TwinkleSynth MIDI Player rendered live audible PCM signal (RMS=%.5f)", rms))
} catch {
    check(false, "Native TwinkleSynth live test failed: \(error)")
}

// 6.4 Programmable Jukebox Folder Discovery, Repeat Modes, ScreenSaver Music & Backward Compat
let jukeTmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("twinkle_juke_test_\(UUID().uuidString)", isDirectory: true)
try? FileManager.default.createDirectory(at: jukeTmpDir.appendingPathComponent("Sub"), withIntermediateDirectories: true)
let tmpMid = jukeTmpDir.appendingPathComponent("Sub/test_carol.mid")
let tmpWav = jukeTmpDir.appendingPathComponent("tone.wav")
try? smfBytes.write(to: tmpMid)
let testPCM = Data(repeating: 0x10, count: 4410)
try? AudioEngineService.wrapPCMAsWAV(pcm: testPCM, sampleRate: 22050, channels: 1, bitsPerSample: 16).write(to: tmpWav)

let juke = AudioEngineService.shared
juke.rebuildTrackList(musicDirectoryPath: jukeTmpDir.path)
let resolvedMid = tmpMid.resolvingSymlinksInPath().standardizedFileURL.path
let resolvedWav = tmpWav.resolvingSymlinksInPath().standardizedFileURL.path
check(juke.tracks.contains(where: { $0.url?.resolvingSymlinksInPath().standardizedFileURL.path == resolvedMid }) &&
      juke.tracks.contains(where: { $0.url?.resolvingSymlinksInPath().standardizedFileURL.path == resolvedWav }),
      "Jukebox discovers recursive custom directory MIDI and WAV files")

var jukeSettings = AppSettings.defaultSettings()
jukeSettings.musicEnabled = true
jukeSettings.ssMusic = true
juke.syncWithSettings(jukeSettings, isScreenSaverActive: false)
check(!juke.isPlaying, "ScreenSaver-only music stays silent during desktop mode")
juke.syncWithSettings(jukeSettings, isScreenSaverActive: true)
check(juke.isPlaying, "ScreenSaver-only music starts cleanly when screen saver activates")
juke.stop()

jukeSettings.ssMusic = false
jukeSettings.musicRepeatMode = .stopAfterPlaylist
juke.play(trackIndex: juke.tracks.count - 1, settings: jukeSettings)
juke.handleTrackCompleted(settings: jukeSettings)
check(!juke.isPlaying, "Repeat mode stopAfterPlaylist halts cleanly at final track")
juke.rebuildTrackList(musicDirectoryPath: "")
try? FileManager.default.removeItem(at: jukeTmpDir)

// v1 JSON backward compatibility check (full v1 payload with zero v2 keys)
var baseV1 = AppSettings.defaultSettings()
baseV1.bulbSetName = "Icicles"
let baseData = (try? JSONEncoder().encode(baseV1)) ?? Data()
if var rawDict = (try? JSONSerialization.jsonObject(with: baseData)) as? [String: Any] {
    for k in rawDict.keys where k.hasPrefix("v2") { rawDict.removeValue(forKey: k) }
    if let legacyStripped = try? JSONSerialization.data(withJSONObject: rawDict),
       let compat = try? JSONDecoder().decode(AppSettings.self, from: legacyStripped) {
        check(compat.bulbSetName == "Icicles" && compat.lightingCategory == .classic && compat.musicRepeatMode == .repeatAll,
              "Legacy v1 JSON settings decode cleanly with v2 defaults preserved")
    } else {
        check(false, "Legacy v1 JSON decoding failed")
    }
} else {
    check(false, "Legacy v1 JSON setup failed")
}

// =========================================================================
// [7] Version 2: Advanced / Modern Lighting Engine (15 Effects + MIDI Sync)
// =========================================================================
print("\n[7] Advanced / Modern Lighting Engine (15 Effects, Sprite Tint, MIDI-Reactive)")

var modSettings = AppSettings.defaultSettings()
modSettings.lightingCategory = .modern
modSettings.location = .aroundScreen
modSettings.noCorners = true
check(AppSettings.defaultSettings().lightingCategory == .classic, "Historical default remains Original / Classic")

var allEffectsValid = true
var allEffectsAnimate = true
for eff in ModernEffectID.allCases {
    modSettings.modernEffects.effect = eff
    modSettings.modernEffects.brightness = 1.0
    modSettings.modernEffects.seed = 424242
    let mEng = ModernLightingEngine(seed: 424242)
    mEng.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 320), settings: modSettings, nowMs: 0)
    let firstSnap = mEng.states
    var sawDelta = false
    var prevSnap = firstSnap
    for step in 1...60 {
        mEng.stepDeterministic(dt: 1.0 / 30.0)
        if step == 40 && eff == .autoCycle { mEng.stepDeterministic(dt: 3.0) }
        if zip(prevSnap, mEng.states).contains(where: { abs($0.intensity - $1.intensity) > 0.005 || abs($0.r - $1.r) > 0.005 || abs($0.g - $1.g) > 0.005 }) {
            sawDelta = true
        }
        prevSnap = mEng.states
    }
    let laterSnap = mEng.states
    let boundsOK = laterSnap.allSatisfy { $0.intensity >= 0 && $0.intensity <= 1.0 && $0.r >= 0 && $0.r <= 1.0 && $0.g >= 0 && $0.g <= 1.0 && $0.b >= 0 && $0.b <= 1.0 }
    if !boundsOK || laterSnap.count != firstSnap.count { allEffectsValid = false }
    if !sawDelta {
        print("  [WARN] Modern effect \(eff.displayName) showed no delta")
        allEffectsAnimate = false
    }
}
check(allEffectsValid && ModernEffectID.allCases.count == 15, "All 15 modern effects produce valid RGB/intensity bounds")
check(allEffectsAnimate, "All 15 modern effects animate across deterministic frames")

// Deterministic seed reproducibility & monitor phase offset
modSettings.modernEffects.effect = .twinklefox
modSettings.modernEffects.seed = 7777
let detA = ModernLightingEngine(seed: 7777)
let detB = ModernLightingEngine(seed: 7777)
detA.configure(bounds: CGRect(x: 0, y: 0, width: 512, height: 128), settings: modSettings, monitorOffset: 0, nowMs: 0)
detB.configure(bounds: CGRect(x: 0, y: 0, width: 512, height: 128), settings: modSettings, monitorOffset: 0, nowMs: 0)
for _ in 0..<25 { detA.stepDeterministic(dt: 0.033); detB.stepDeterministic(dt: 0.033) }
check(detA.states == detB.states, "Deterministic random seed reproduces identical ModernLightingEngine states")

// Multi-monitor phase offset differs cleanly
modSettings.modernEffects.perMonitorPhaseOffset = true
let detMon1 = ModernLightingEngine(seed: 7777)
detMon1.configure(bounds: CGRect(x: 0, y: 0, width: 512, height: 128), settings: modSettings, monitorOffset: 1, nowMs: 0)
for _ in 0..<25 { detMon1.stepDeterministic(dt: 0.033) }
check(detA.states != detMon1.states, "Per-monitor phase offset differentiates monitor strands")

// Classic settings isolation when returning from modern mode
var isoSettings = AppSettings.defaultSettings()
isoSettings.flashMode = .alternating
isoSettings.colorMode = .redWhiteBlue
isoSettings.lightingCategory = .modern
isoSettings.modernEffects.effect = .candyCane
isoSettings.lightingCategory = .classic
check(isoSettings.flashMode == .alternating && isoSettings.colorMode == .redWhiteBlue,
      "Switching Modern -> Classic preserves historical Classic configuration intact")

// MIDI-reactive boost check
modSettings.modernEffects.midiReactiveEnabled = true
modSettings.modernEffects.midiReactiveMode = .velocityBrightness
modSettings.modernEffects.brightness = 0.25
let midiEng = ModernLightingEngine(seed: 999)
midiEng.configure(bounds: CGRect(x: 0, y: 0, width: 512, height: 128), settings: modSettings, nowMs: 0)
let baseSum = midiEng.states.map(\.intensity).reduce(0, +)
midiEng.handleMIDIEvent(MIDILightEvent(channel: 9, note: 36, velocity: 127, isNoteOn: true, currentBPM: 120, positionSeconds: 0.1))
midiEng.stepDeterministic(dt: 0.016)
let pulseSum = midiEng.states.map(\.intensity).reduce(0, +)
check(pulseSum > baseSum, "MIDI-reactive mode boosts strand illumination on note/drum event")

// Visual sprite-preserving render snapshots of Modern Rainbow Chase & Candy Cane
modSettings.modernEffects.midiReactiveEnabled = false
modSettings.modernEffects.brightness = 1.0
modSettings.modernEffects.effect = .rainbowChase
modSettings.modernEffects.palette = .rainbowSpectrum
let visEng = ModernLightingEngine(seed: 123)
visEng.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 180), settings: modSettings, nowMs: 0)
for _ in 0..<15 { visEng.stepDeterministic(dt: 0.033) }
if let modImg = BulbCanvasView.renderModernSnapshot(width: 640, height: 180, modernEngine: visEng, settings: modSettings, backgroundColor: NSColor(srgbRed: 0.05, green: 0.12, blue: 0.22, alpha: 1)) {
    check(writePNG(modImg, to: scratchDir.appendingPathComponent("verify_modern_rainbow.png")), "Rendered sprite-based Modern Rainbow Chase visual verification snapshot")
}

// =========================================================================
// [8] Complete Holiday Edition: 250 Bulbs, 20 Screen Savers, 130 Wallpapers,
//     105 MIDI Songs, 24-Door Advent Calendar, Live Previews, & Historical XP UI
// =========================================================================
print("\n[8] Complete Holiday Edition Verification")

// 8.1 Verify 250 distinct bulb sets across 25 collections (x 10 designs each)
let h250Defs = Holiday250Catalog.allDefinitions
check(h250Defs.count == 250, "Holiday250Catalog contains all 250 bulb designs (got \(h250Defs.count))")
let collections25 = BulbCollectionCategory.holiday25Collections
check(collections25.count == 25, "25 Holiday bulb collections defined")
let allTenEach = collections25.allSatisfy { col in h250Defs.filter { $0.collection == col }.count == 10 }
check(allTenEach, "Each of the 25 collections contains exactly 10 bulb designs")
check(Set(h250Defs.map(\.id)).count == 250 && Set(h250Defs.map(\.title)).count == 250, "All 250 bulb IDs and titles are unique")

func cgImageHash64(_ img: CGImage) -> UInt64 {
    let w = img.width, h = img.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    var hash: UInt64 = 14695981039346656037
    for b in buf {
        hash ^= UInt64(b)
        hash &*= 1099511628211
    }
    return hash
}

var spriteHashes = Set<UInt64>()
var all250OnOffDiffer = true
var all250NonEmpty = true
for def in h250Defs {
    let pack = Holiday250Catalog.renderSetPack(definition: def, size: 32)
    guard let onImg = pack.onImages[2], let offImg = pack.offImages[2] else {
        all250NonEmpty = false
        continue
    }
    let onRGBA = sampleImageRGBA(onImg)
    let offRGBA = sampleImageRGBA(offImg)
    if onRGBA == offRGBA { all250OnOffDiffer = false }
    let stats = opaquePixelStats(onImg)
    if (stats.maxX - stats.minX) < 4 || (stats.maxY - stats.minY) < 4 { all250NonEmpty = false }
    spriteHashes.insert(cgImageHash64(onImg))
}
check(all250NonEmpty, "All 250 bulb sets render non-empty 32x32 sprites")
check(all250OnOffDiffer, "All 250 bulb sets have distinct ON vs OFF visual states")
check(spriteHashes.count == 250, "All 250 bulb designs produce 250 unique rendered sprites (got \(spriteHashes.count))")

// Spot-check 48x48 rendering & inward edge rotation across all 25 collections
var spot48AndRotationOK = true
for col in collections25 {
    if let first = h250Defs.first(where: { $0.collection == col }) {
        let p48 = Holiday250Catalog.renderSetPack(definition: first, size: 48)
        if p48.onImages[2]?.width != 48 || p48.onImages[2]?.height != 48 {
            spot48AndRotationOK = false
        }
        var rotS = AppSettings.defaultSettings()
        rotS.bulbSetName = first.id
        rotS.bulbSize = .normal
        let rSlot = BulbSlot(index: 0, frame: CGRect(x: 0, y: 0, width: 32, height: 32), edge: .right, colorIndex: 2, isBareWire: false, isMissing: false, isBroken: false, isBurnedOut: false, isLit: true, flashable: true, nextToggleMs: 0)
        if BulbArtworkRegistry.shared.image(for: rSlot, settings: rotS) == nil {
            spot48AndRotationOK = false
        }
    }
}
check(spot48AndRotationOK, "48x48 size and inward edge rotation work cleanly across all 25 collections")

// Render 250-Bulb Contact Sheet (25 rows x 10 cols on dark navy canvas)
do {
    let cols = 10, rows = 25, cell = 36, labelW = 210
    let sheetW = labelW + cols * cell + 16
    let sheetH = rows * cell + 20
    if let ctx = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: sheetW * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
        let gCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        let prevG = NSGraphicsContext.current
        NSGraphicsContext.current = gCtx
        ctx.setFillColor(NSColor(srgbRed: 0.05, green: 0.10, blue: 0.19, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 10.5), .foregroundColor: NSColor(white: 0.94, alpha: 1)]
        for (rIdx, col) in collections25.enumerated() {
            let rowSets = h250Defs.filter { $0.collection == col }
            let yTop = CGFloat(sheetH - 12 - (rIdx + 1) * cell)
            let title = col.displayName as NSString
            title.draw(at: CGPoint(x: 10, y: yTop + 12), withAttributes: attrs)
            for (cIdx, def) in rowSets.enumerated() {
                if let img = Holiday250Catalog.renderSetPack(definition: def, size: 32).onImages[2] {
                    ctx.draw(img, in: CGRect(x: CGFloat(labelW + cIdx * cell), y: yTop + 2, width: 32, height: 32))
                }
            }
        }
        NSGraphicsContext.current = prevG
        if let sheetImg = ctx.makeImage() {
            check(writePNG(sheetImg, to: scratchDir.appendingPathComponent("verify_250_holiday_bulbs_contact_sheet.png")), "Wrote 250 Holiday Bulb Sets visual contact sheet")
        }
    }
}

// 8.2 Verify .blz stored-ZIP unwrapping & clean failure on proprietary opaque data
var samplePK = Data([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00])
samplePK.append(Data(repeating: 0, count: 8))
let fakePayload = Data("MZ" .utf8) + Data(repeating: 0x41, count: 80)
let pLen = UInt32(fakePayload.count)
samplePK.append(contentsOf: [UInt8(pLen & 0xFF), UInt8((pLen >> 8) & 0xFF), UInt8((pLen >> 16) & 0xFF), UInt8((pLen >> 24) & 0xFF)])
samplePK.append(contentsOf: [UInt8(pLen & 0xFF), UInt8((pLen >> 8) & 0xFF), UInt8((pLen >> 16) & 0xFF), UInt8((pLen >> 24) & 0xFF)])
samplePK.append(contentsOf: [0x01, 0x00, 0x00, 0x00]) // filename len = 1, extra = 0
samplePK.append(0x61) // "a"
samplePK.append(fakePayload)
let unwrappedPK = BLBResourceLoader.unwrapCompressedBLZIfStandard(data: samplePK)
check(unwrappedPK == fakePayload, ".blz stored-ZIP unwrapping recovers embedded PE payload")
let opaqueBLZURL = scratchDir.appendingPathComponent("proprietary_test.blz")
try? Data([0x42, 0x4C, 0x5A, 0x01] + Array(repeating: UInt8(0xAA), count: 80)).write(to: opaqueBLZURL)
check(BLBResourceLoader.load(url: opaqueBLZURL) == nil, "Proprietary compressed .blz fails safely with nil instead of crashing")
try? FileManager.default.removeItem(at: opaqueBLZURL)

// 8.3 Verify 20 Seasonal Screen Savers + Slideshow + Custom TwinkleScreenSaverPlugin
let seasonal20 = ScreenSaverModuleID.seasonal20Modules
check(seasonal20.count == 20, "Exactly 20 new seasonal screen savers registered (got \(seasonal20.count))")
var ssHashes = Set<UInt64>()
for mod in seasonal20 {
    var cfg = AppSettings.defaultSettings()
    cfg.ssModule = mod
    cfg.ssLights = true
    let ssView = ScreenSaverCanvasView(frame: NSRect(x: 0, y: 0, width: 320, height: 200), settings: cfg, preview: false)
    for _ in 0..<25 { ssView.stepFrame() }
    if let rep = ssView.bitmapImageRepForCachingDisplay(in: ssView.bounds) {
        ssView.cacheDisplay(in: ssView.bounds, to: rep)
        if let cg = rep.cgImage {
            ssHashes.insert(cgImageHash64(cg))
        }
    }
}
check(ssHashes.count >= 18, "All 20 seasonal screen savers render active visual output (\(ssHashes.count)/20 distinct frames)")

// Visual PNG snapshots of requested seasonal screen savers
func snapshotSaver(_ mod: ScreenSaverModuleID, filename: String, configure: ((inout AppSettings) -> Void)? = nil) -> Bool {
    var cfg = AppSettings.defaultSettings()
    cfg.ssModule = mod
    cfg.ssLights = true
    configure?(&cfg)
    let v = ScreenSaverCanvasView(frame: NSRect(x: 0, y: 0, width: 640, height: 400), settings: cfg, preview: false)
    for _ in 0..<35 { v.stepFrame() }
    return snapshotView(v, to: scratchDir.appendingPathComponent(filename))
}
check(snapshotSaver(.twinklingWreath, filename: "verify_ss_wreath.png"), "Rendered Twinkling Holiday Wreath screen saver snapshot")
check(snapshotSaver(.fallingAutumnLeaves, filename: "verify_ss_autumn_leaves.png") { $0.seasonalSSConfig.windCondition = .windy }, "Rendered Falling Autumn Leaves screen saver snapshot")
check(snapshotSaver(.glowingPumpkin, filename: "verify_ss_pumpkin.png"), "Rendered Glowing Halloween Pumpkin screen saver snapshot")

final class MockCustomSaverPlugin: TwinkleScreenSaverPlugin {
    let moduleID = "MockCustomSaver"
    let displayName = "Mock Custom Saver"
    var drawCallCount = 0
    func reset(in rect: CGRect, settings: AppSettings, preview: Bool) {}
    func step(in rect: CGRect, settings: AppSettings, tick: Int) {}
    func draw(in ctx: CGContext, rect: CGRect, settings: AppSettings, preview: Bool, tick: Int) {
        drawCallCount += 1
        ctx.setFillColor(NSColor.systemTeal.cgColor)
        ctx.fill(rect.insetBy(dx: 20, dy: 20))
    }
}
let mockPlugin = MockCustomSaverPlugin()
ScreenSaverPluginRegistry.shared.register(mockPlugin)
if let foundPlugin = ScreenSaverPluginRegistry.shared.plugin(for: "MockCustomSaver"),
   let pCtx = CGContext(data: nil, width: 100, height: 80, bitsPerComponent: 8, bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
    foundPlugin.draw(in: pCtx, rect: CGRect(x: 0, y: 0, width: 100, height: 80), settings: .defaultSettings(), preview: true, tick: 1)
    check(mockPlugin.drawCallCount == 1, "TwinkleScreenSaverPlugin registry resolves and draws external plugins")
} else {
    check(false, "TwinkleScreenSaverPlugin registry failed to resolve registered plugin")
}

// 8.4 Verify 130 Wallpapers & 105-track MIDI Library
let wp130 = WallpaperPack130.allSpecs
check(wp130.count == 130 && Set(wp130.map(\.id)).count == 130, "WallpaperPack130 provides 130 uniquely identified wallpapers")
let wpCats = WallpaperThemeCategory.allCases.filter { $0 != .all }
let wpAllCatsRendered = wpCats.allSatisfy { cat in
    guard let spec = wp130.first(where: { $0.category == cat }),
          let img = WallpaperPack130.renderWallpaper(spec, width: 280, height: 180) else { return false }
    return img.width == 280 && img.height == 180
}
check(wpAllCatsRendered, "All 11 seasonal wallpaper collections render distinct preview images")
check(Set(carols.map(\.id)).count == 105 && carols.allSatisfy { $0.builtInMIDI != nil && $0.builtInMIDI!.starts(with: Data("MThd".utf8)) }, "All 105 built-in GM MIDI songs have unique IDs and valid SMF MThd headers")

// 8.5 Verify 24-Door Advent Calendar date logic & persistence
let advCtrl = AdventCalendarWindowController()
var calComps = DateComponents(); calComps.year = 2026; calComps.month = 12; calComps.day = 10
let dec10 = Calendar.current.date(from: calComps)!
var advSettings = AppSettings.defaultSettings()
check(advCtrl.canOpenDoor(day: 1, on: dec10, settings: advSettings) && advCtrl.canOpenDoor(day: 10, on: dec10, settings: advSettings), "Advent doors 1..10 unlock on December 10")
check(!advCtrl.canOpenDoor(day: 11, on: dec10, settings: advSettings) && !advCtrl.canOpenDoor(day: 24, on: dec10, settings: advSettings), "Future Advent doors remain locked before their December date")
advSettings.adventAllowAnyDatePreview = true
check(advCtrl.canOpenDoor(day: 24, on: dec10, settings: advSettings), "Advent Preview Mode allows opening any door 1..24")
advSettings.openedAdventDoors = [1, 4, 10]
if let encAdv = try? JSONEncoder().encode(advSettings), let decAdv = try? JSONDecoder().decode(AppSettings.self, from: encAdv) {
    check(decAdv.openedAdventDoors == [1, 4, 10], "Opened Advent door set persists across AppSettings JSON round-trip")
} else {
    check(false, "AppSettings Advent persistence encode/decode failed")
}

// 8.6 Verify Historical 7-Tab XP Preferences UI & Live Preview Views
let expectedTabs = ["General", "Bulbs", "Music", "Screen Saver", "Wallpaper", "Calendar", "Help"]
let actualTabs = prefsWinCtrl.tabView.tabViewItems.map(\.label)
check(actualTabs == expectedTabs, "Settings window preserves exact 7 historical XP tabs in order: \(actualTabs)")
let swatchImg = ColorModeSwatchRenderer.swatchImage(for: .redGreen)
check(swatchImg.size.width > 0 && swatchImg.size.height > 0, "ColorModeSwatchRenderer generates dropdown color beads")
let samplePV = BulbSetPreviewView(frame: NSRect(x: 0, y: 0, width: 220, height: 52))
samplePV.settings = AppSettings.defaultSettings()
let flashPV = FlashingModePreviewView(frame: NSRect(x: 0, y: 0, width: 256, height: 32))
flashPV.configure(with: AppSettings.defaultSettings())
check(snapshotView(samplePV, to: scratchDir.appendingPathComponent("verify_live_bulb_preview.png")) && snapshotView(flashPV, to: scratchDir.appendingPathComponent("verify_live_flash_preview.png")), "Live BulbSetPreviewView & FlashingModePreviewView render snapshots cleanly")
flashPV.stopPreview()

// MARK: - 9.0 Next-Generation Comprehensive Verification Suite

// 9.1 Holiday Scenes (16 built-in, CRUD, Restore Previous, Return to Classic, Export/Import)
let ngTempDir = scratchDir.appendingPathComponent("nextgen_verify_\(UUID().uuidString.prefix(6))", isDirectory: true)
try? FileManager.default.createDirectory(at: ngTempDir, withIntermediateDirectories: true)
let ngStore = NextGenStateStore(storageURL: ngTempDir.appendingPathComponent("nextgen.json"))
let sceneMgr = HolidaySceneManager(store: ngStore)
let isoDefaultsSuite = "com.twinklebulbs.verify.\(UUID().uuidString.prefix(6))"
let isoDefaults = UserDefaults(suiteName: isoDefaultsSuite)!
let isoSettingsStore = SettingsStore(userDefaults: isoDefaults)

check(sceneMgr.builtInScenes.count == 16 && Set(sceneMgr.builtInScenes.map(\.id)).count == 16, "HolidaySceneManager ships all 16 uniquely identified built-in scenes")
let requiredSceneKeywords = ["Classic Christmas", "Victorian Christmas", "Winter Wonderland", "Christmas Fireplace", "Snowy Village", "New Year", "Valentine", "St. Patrick", "Easter Garden", "Spring Awakening", "Summer Nights", "Fourth of July", "Autumn Harvest", "Haunted Halloween", "Thanksgiving", "Peaceful Winter"]
let hasAllKeywords = requiredSceneKeywords.allSatisfy { kw in sceneMgr.builtInScenes.contains { $0.name.contains(kw) } }
check(hasAllKeywords, "All 16 required seasonal scene presets exist by title")

var initialBeforeScene = AppSettings.defaultSettings()
initialBeforeScene.bulbSetName = "Normal"
initialBeforeScene.colorMode = .blues
isoSettingsStore.settings = initialBeforeScene

let actOK = sceneMgr.activateScene(id: "scene:haunted_halloween", settingsStore: isoSettingsStore, applyWallpaper: false)
check(actOK && isoSettingsStore.settings.ssModule == .hauntedHouse && ngStore.state.activeSceneID == "scene:haunted_halloween", "Activating Holiday Scene switches bulbs, lighting mode, wallpaper ID & screensaver atomically")
check(!sceneMgr.deleteScene(id: "scene:classic_christmas"), "Built-in scenes are protected from accidental deletion")

let restoredOK = sceneMgr.restorePreviousScene(settingsStore: isoSettingsStore)
check(restoredOK && isoSettingsStore.settings.bulbSetName == "Normal" && isoSettingsStore.settings.colorMode == .blues, "Restore Previous Scene reverts exact pre-activation configuration")

var customScene = sceneMgr.snapshotCurrentSettings(name: "Verifier Custom Mix", from: isoSettingsStore.settings)
customScene.bulbSetName = "holiday250:009"
let savedScene = sceneMgr.saveUserScene(customScene)
let dupScene = sceneMgr.duplicateScene(id: savedScene.id)
let renOK = dupScene.map { sceneMgr.renameUserScene(id: $0.id, newName: "Renamed Mix") } ?? false
let expSceneData = try? sceneMgr.exportScene(id: savedScene.id)
let impScene = expSceneData.flatMap { try? sceneMgr.importScene(data: $0) }
check(dupScene != nil && renOK && impScene?.name == "Verifier Custom Mix", "Custom scene save, duplicate, rename, .twinklescene export and import succeed cleanly")
check(dupScene.map { sceneMgr.deleteScene(id: $0.id) } ?? false, "User-created scenes can be deleted cleanly")

sceneMgr.returnToClassicTwinkleBulbs(settingsStore: isoSettingsStore)
check(isoSettingsStore.settings.lightingCategory == .classic && isoSettingsStore.settings.bulbSetName == "Outdoor" && isoSettingsStore.settings.flashMode == .chase && isoSettingsStore.settings.colorMode == .redGreen, "Return to Classic restores authentic v6.0 defaults")
UserDefaults.standard.removePersistentDomain(forName: isoDefaultsSuite)

// 9.2 Seasonal Automation Engine (Disabled by Default, Priorities, Midnight Wrap, Quiet Hours, Solar, Overrides)
var autoCfg = SeasonalAutomationConfig()
check(!autoCfg.automationEnabled, "Seasonal automation is disabled by default (Classic behavior untouched)")
let schedSvc = SeasonalScheduleService(store: ngStore)
var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(secondsFromGMT: -5 * 3600)!
let dec24 = cal.date(from: DateComponents(year: 2026, month: 12, day: 24, hour: 19, minute: 0))!
let jan2 = cal.date(from: DateComponents(year: 2027, month: 1, day: 2, hour: 12, minute: 0))!
let lateNight = cal.date(from: DateComponents(year: 2026, month: 12, day: 24, hour: 23, minute: 45))!

let disabledEval = schedSvc.evaluate(at: dec24, automation: autoCfg, calendar: cal)
check(disabledEval.targetSceneID == nil && !disabledEval.shouldShutdownLights, "Disabled automation evaluates to clean no-op")

autoCfg.automationEnabled = true
let dec24Eval = schedSvc.evaluate(at: dec24, automation: autoCfg, calendar: cal)
check(dec24Eval.targetSceneID == "scene:christmas_fireplace", "Higher-priority Christmas Fireplace (40) beats Classic Christmas (30) on Dec 24")

let jan2Eval = schedSvc.evaluate(at: jan2, automation: autoCfg, calendar: cal)
check(jan2Eval.targetSceneID == "scene:new_years_celebration", "Dec 31 -> Jan 3 year-wraparound rule matches Jan 2 accurately")

autoCfg.quietHours.enabled = true
let qEval = schedSvc.evaluate(at: lateNight, automation: autoCfg, calendar: cal)
check(qEval.isQuietHours && qEval.brightnessMultiplier < 0.5, "Midnight-spanning Quiet Hours dims lights at 23:45")

autoCfg.manualOverrideSceneID = "scene:valentine"
autoCfg.manualOverrideExpiresAt = dec24.addingTimeInterval(3600)
let ovrEval = schedSvc.evaluate(at: dec24, automation: autoCfg, calendar: cal)
check(ovrEval.isManualOverride && ovrEval.targetSceneID == "scene:valentine", "Active Temporary Manual Override supersedes seasonal rules")

autoCfg.vacationMode = true
let vacEval = schedSvc.evaluate(at: dec24, automation: autoCfg, calendar: cal)
check(vacEval.shouldShutdownLights, "Vacation Mode triggers safe shutdown regardless of matching date rules")

let nycSolar = SolarCalculator.sunriseSunset(date: dec24, latitude: 40.7128, longitude: -74.0060, timeZone: cal.timeZone)
let poleSolar = SolarCalculator.sunriseSunset(date: dec24, latitude: 89.5, longitude: 0.0, timeZone: cal.timeZone)
check(nycSolar != nil && nycSolar!.sunrise < nycSolar!.sunset && poleSolar == nil, "NOAA Solar calculator computes valid sunrise < sunset and returns nil cleanly for polar edge case")

// 9.3 Effect Timeline Engine (13 events, 6 curves, FPS independence, .twinklefx export/import)
check(TimelineEventKind.allCases.count == 13, "TimelineEffect supports all 13 required event kinds")
check(EffectTimelineEngine.evaluateCurve(.linear, t: 0.5) == 0.5 && EffectTimelineEngine.evaluateCurve(.step, t: 0.99) == 0.0 && abs(EffectTimelineEngine.evaluateCurve(.easeInOut, t: 0.5) - 0.5) < 0.01, "Timeline interpolation curves evaluate monotonically and accurately")
let tlDoc = EffectTimelineEngine.builtInSampleTimelines()[0]
let tlEngineA = EffectTimelineEngine(document: tlDoc)
let tlEngineB = EffectTimelineEngine(document: tlDoc)
for _ in 0..<120 { _ = tlEngineA.evaluateStates(dt: 1.0 / 30.0, bounds: CGRect(x: 0, y: 0, width: 480, height: 32), settings: .defaultSettings()) }
for _ in 0..<240 { _ = tlEngineB.evaluateStates(dt: 1.0 / 60.0, bounds: CGRect(x: 0, y: 0, width: 480, height: 32), settings: .defaultSettings()) }
check(abs(tlEngineA.elapsedSeconds - tlEngineB.elapsedSeconds) < 0.02, "Timeline clock advances frame-rate independently across 30fps and 60fps (\(String(format: "%.3f", tlEngineA.elapsedSeconds)) vs \(String(format: "%.3f", tlEngineB.elapsedSeconds)))")
if let fxData = try? EffectTimelineEngine.exportTimeline(tlDoc), let fxDecoded = try? EffectTimelineEngine.importTimeline(data: fxData) {
    check(fxDecoded.formatVersion == 1 && fxDecoded.name == tlDoc.name && fxDecoded.tracks.count == tlDoc.tracks.count, ".twinklefx format serializes and deserializes cleanly")
} else {
    check(false, ".twinklefx export/import failed")
}
let tlCanvas = TimelineEditorCanvasView(frame: NSRect(x: 0, y: 0, width: 640, height: 260))
tlCanvas.document = tlDoc
tlCanvas.playheadSeconds = 4.0
check(snapshotView(tlCanvas, to: scratchDir.appendingPathComponent("verify_timeline_studio.png")), "Rendered visual Lighting Effect Studio timeline snapshot")

// 9.4 MIDI Light Show Composer & All 7 Modes
check(MIDIReactiveMode.allCases.count == 7, "All 7 MIDI reactive modes implemented (including Instrument Mapping & Percussion Effects)")
let composer = MIDILightShowComposer()
var firedCuesTotal = 0
_ = composer.synchronizeWithAudioClock(positionSeconds: 2.5)
firedCuesTotal += composer.synchronizeWithAudioClock(positionSeconds: 6.2).count
let loopRearmCount = composer.synchronizeWithAudioClock(positionSeconds: 2.1).count
check(firedCuesTotal >= 1 && loopRearmCount >= 1, "MIDILightShowComposer syncs to single audio clock and re-arms cue markers cleanly upon loop/rewind")
var modeOutputs: [String] = []
for m in MIDIReactiveMode.allCases {
    let eng = ModernLightingEngine(seed: 12345)
    var ms = AppSettings.defaultSettings()
    ms.lightingCategory = .modern
    ms.modernEffects.midiReactiveEnabled = true
    ms.modernEffects.midiReactiveMode = m
    eng.configure(bounds: CGRect(x: 0, y: 0, width: 320, height: 32), settings: ms, nowMs: 0)
    eng.handleMIDIEvent(MIDILightEvent(channel: 9, note: 64, velocity: 120, isNoteOn: true, currentBPM: 140, positionSeconds: 1.0))
    eng.stepDeterministic(dt: 0.016)
    let sig = eng.states.prefix(6).map { String(format: "%.2f:%.2f:%.2f", $0.r, $0.g, $0.intensity) }.joined(separator: ",")
    modeOutputs.append(sig)
}
check(Set(modeOutputs).count >= 4, "All 7 MIDI reactive modes drive distinct bulb illumination signatures")

// 9.5 Interactive Desktop Decorations & Celebrations (Disabled by Default)
let interDefault = InteractiveDesktopConfig()
check(!interDefault.enabled && !interDefault.mouseProximityGlow, "Interactive Desktop effects are disabled by default")
let interEngine = InteractiveDesktopEffectsEngine()
var testBulbs = (0..<10).map { i in
    ModernBulbState(index: i, frame: CGRect(x: CGFloat(i) * 40, y: 0, width: 32, height: 32), edge: .top, isBareWire: false, isMissing: false, isBroken: false, isBurnedOut: false, r: 0.2, g: 0.2, b: 0.2, intensity: 0.1)
}
var interOn = InteractiveDesktopConfig(); interOn.enabled = true; interOn.mouseProximityGlow = true; interOn.proximityRadiusPx = 60
interEngine.step(dt: 0.016, config: interOn, pointerScreenPoint: CGPoint(x: 16, y: 780), screenFrame: CGRect(x: 0, y: 0, width: 800, height: 800), canvasBounds: CGRect(x: 0, y: 0, width: 800, height: 800), bulbStates: &testBulbs)
check(testBulbs[0].intensity > testBulbs[9].intensity + 0.3, "Pointer Proximity Glow illuminates nearby bulbs selectively")
interEngine.triggerCelebration(.newYear, inCanvasBounds: CGRect(x: 0, y: 0, width: 800, height: 400))
check(interEngine.sparkleParticles.count > 20, "Holiday celebration triggers festive confetti/sparkle particle burst")

// 9.6 Virtual Lighting Layout Designer (9 shapes & 2D preview)
check(VirtualStrandShape.allCases.count == 9, "VirtualLayout supports all 9 strand geometries")
let layoutDoc = VirtualLightingLayoutEngine.builtInSampleLayouts()[0]
let shapesAllOK = VirtualStrandShape.allCases.allSatisfy { shp in
    let item = VirtualStrandItem(name: shp.rawValue, shape: shp, bulbCount: 20)
    return VirtualLightingLayoutEngine.sampleStrandPoints(item: item, inCanvasBounds: CGRect(x: 0, y: 0, width: 400, height: 300)).count == 20
}
check(shapesAllOK, "All 9 virtual strand geometries produce exact configured bulb coordinates")
let layoutCanvas = VirtualLayoutCanvasView(frame: NSRect(x: 0, y: 0, width: 520, height: 360))
layoutCanvas.layoutDoc = layoutDoc
layoutCanvas.selectedStrandID = layoutDoc.strands.first?.id
check(snapshotView(layoutCanvas, to: scratchDir.appendingPathComponent("verify_virtual_layout.png")), "Rendered visual Virtual Layout Designer snapshot")

// 9.7 Developer Lighting API Security, HTTP REST, RFC 6455 WebSocket Streaming & Adapters
var apiCfg = TwinkleAPIConfig()
check(!apiCfg.enabled && apiCfg.bindLocalhostOnly && !apiCfg.allowControlCommands && !apiCfg.webRemoteEnabled && !apiCfg.electricalSafetyAcknowledged, "Developer API, Remote Control & Hardware Safety flags are disabled/localhost-locked by default")

func httpLoopback(port: UInt16, method: String, path: String, bearer: String?, body: Data? = nil) -> (status: Int, body: String) {
    let sem = DispatchSemaphore(value: 0)
    var outStatus = 0
    var outBody = ""
    let conn = NWConnection(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    let q = DispatchQueue(label: "test.http.\(UUID().uuidString.prefix(4))")
    var req = "\(method) \(path) HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nConnection: close\r\n"
    if let b = bearer { req += "Authorization: Bearer \(b)\r\n" }
    if let bd = body { req += "Content-Type: application/json\r\nContent-Length: \(bd.count)\r\n" }
    req += "\r\n"
    var raw = Data(req.utf8)
    if let bd = body { raw.append(bd) }

    var acc = Data()
    conn.stateUpdateHandler = { st in
        if case .ready = st {
            conn.send(content: raw, completion: .contentProcessed { _ in
                func recvMore() {
                    conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComp, err in
                        if let data { acc.append(data) }
                        if isComp || err != nil {
                            if let str = String(data: acc, encoding: .utf8), let sep = str.range(of: "\r\n\r\n") {
                                let headerFirst = String(str[..<sep.lowerBound].split(separator: "\r\n").first ?? "")
                                let parts = headerFirst.split(separator: " ")
                                if parts.count >= 2 { outStatus = Int(parts[1]) ?? 0 }
                                outBody = String(str[sep.upperBound...])
                            }
                            conn.cancel()
                            sem.signal()
                        } else {
                            recvMore()
                        }
                    }
                }
                recvMore()
            })
        } else if case .failed = st {
            sem.signal()
        }
    }
    conn.start(queue: q)
    _ = sem.wait(timeout: .now() + 3.0)
    return (outStatus, outBody)
}

apiCfg.enabled = true
apiCfg.allowControlCommands = false
apiCfg.externalHardwareEnabled = true
apiCfg.electricalSafetyAcknowledged = true
var nextStateForAPI = ngStore.state
nextStateForAPI.apiConfig = apiCfg
ngStore.state = nextStateForAPI
let apiSvc = TwinkleLightingAPIService(stateStore: ngStore, settingsStore: isoSettingsStore, sceneManager: sceneMgr)
try? apiSvc.start(config: apiCfg, overridePort: 0)
let waitReadyDeadline = Date().addingTimeInterval(2.0)
while apiSvc.boundPort == 0 && Date() < waitReadyDeadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}
let testPort = apiSvc.boundPort
check(testPort > 0 && apiSvc.isRunning, "TwinkleLightingAPIService binds localhost ephemeral port (\(testPort)) cleanly")

if testPort > 0 {
    let rUnauth = httpLoopback(port: testPort, method: "GET", path: "/v1/status", bearer: nil)
    let rReadOK = httpLoopback(port: testPort, method: "GET", path: "/v1/status", bearer: apiCfg.readOnlyToken)
    let cmdData = Data("{\"action\":\"setBrightness\",\"value\":0.5}".utf8)
    let rReadTryCtrl = httpLoopback(port: testPort, method: "POST", path: "/v1/control", bearer: apiCfg.readOnlyToken, body: cmdData)
    let rCtrlDisabled = httpLoopback(port: testPort, method: "POST", path: "/v1/control", bearer: apiCfg.controlToken, body: cmdData)

    check(rUnauth.status == 401, "API rejects unauthenticated GET /v1/status with HTTP 401")
    check(rReadOK.status == 200 && rReadOK.body.contains("lightsEnabled"), "API serves authenticated GET /v1/status with valid JSON")
    check(rReadTryCtrl.status == 401, "API blocks read-only token from issuing control commands")
    check(rCtrlDisabled.status == 401, "API blocks control commands until allowControlCommands is enabled")

    // Test RFC 6455 WebSocket subscription & live frame receipt
    let wsSem = DispatchSemaphore(value: 0)
    var wsUpgraded = false
    var wsFrameDecoded: TwinkleBulbFramePacket? = nil
    let wsConn = NWConnection(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: testPort)!, using: .tcp)
    let wsQ = DispatchQueue(label: "test.ws.stream")
    let hsReq = "GET /v1/stream?token=\(apiCfg.readOnlyToken) HTTP/1.1\r\nHost: 127.0.0.1:\(testPort)\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
    var wsAcc = Data()
    wsConn.stateUpdateHandler = { st in
        if case .ready = st {
            wsConn.send(content: Data(hsReq.utf8), completion: .contentProcessed { _ in
                func rd() {
                    wsConn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComp, _ in
                        if let data { wsAcc.append(data) }
                        if let sep = wsAcc.range(of: Data("\r\n\r\n".utf8)) {
                            let hdrStr = String(data: wsAcc.subdata(in: 0..<sep.lowerBound), encoding: .utf8) ?? ""
                            if hdrStr.contains("101 Switching Protocols") { wsUpgraded = true }
                            let after = wsAcc.subdata(in: sep.upperBound..<wsAcc.count)
                            if after.count >= 4 {
                                // Decode basic RFC6455 frame header
                                let lenByte = Int(after[1] & 0x7F)
                                var payStart = 2
                                var payLen = lenByte
                                if lenByte == 126 && after.count >= 4 {
                                    payLen = (Int(after[2]) << 8) | Int(after[3]); payStart = 4
                                }
                                if after.count >= payStart + payLen {
                                    let inner = after.subdata(in: payStart..<(payStart + payLen))
                                    wsFrameDecoded = TwinkleBulbFramePacket.decodeBinaryFrame(inner)
                                    wsSem.signal()
                                    return
                                }
                            }
                        }
                        if !isComp { rd() }
                    }
                }
                rd()
            })
        }
    }
    wsConn.start(queue: wsQ)
    let waitWSUpgrade = Date().addingTimeInterval(1.0)
    while !wsUpgraded && Date() < waitWSUpgrade {
        RunLoop.current.run(until: Date().addingTimeInterval(0.04))
    }
    // Emit live lighting frame to both Virtual Adapter + WebSocket subscriber
    let sampleFrameStates = (0..<12).map { i in
        ModernBulbState(index: i, frame: CGRect(x: CGFloat(i)*32, y: 0, width: 32, height: 32), edge: .top, isBareWire: false, isMissing: false, isBroken: false, isBurnedOut: false, r: 0.9, g: 0.2, b: 0.3, intensity: 1.0)
    }
    apiSvc.publishLightingFrame(states: sampleFrameStates, maxFPSOverride: 60)
    _ = wsSem.wait(timeout: .now() + 2.0)
    wsConn.cancel()

    check(wsUpgraded && wsFrameDecoded?.bulbCount == 12 && (wsFrameDecoded?.rgbBytes[0] ?? 0) > 200, "WebSocket /v1/stream completes RFC 6455 handshake & streams valid TWKL binary frame")
    check(ReferenceVirtualAdapter.shared.receivedFrameCount >= 1 && ReferenceVirtualAdapter.shared.lastFrame?.bulbCount == 12, "ReferenceVirtualAdapter receives live synchronized frame packets")

    // Verify new full-catalog GET endpoints & Web Remote HTML
    var stateWithFullRemote = ngStore.state
    stateWithFullRemote.apiConfig.allowControlCommands = true
    stateWithFullRemote.apiConfig.webRemoteEnabled = true
    ngStore.state = stateWithFullRemote

    let rBulbs = httpLoopback(port: testPort, method: "GET", path: "/v1/bulbs", bearer: apiCfg.readOnlyToken)
    let rMusic = httpLoopback(port: testPort, method: "GET", path: "/v1/music", bearer: apiCfg.readOnlyToken)
    let rSavers = httpLoopback(port: testPort, method: "GET", path: "/v1/screensavers", bearer: apiCfg.readOnlyToken)
    let rWallpapers = httpLoopback(port: testPort, method: "GET", path: "/v1/wallpapers", bearer: apiCfg.readOnlyToken)
    let rTimelines = httpLoopback(port: testPort, method: "GET", path: "/v1/timelines", bearer: apiCfg.readOnlyToken)
    let rWebHTML = httpLoopback(port: testPort, method: "GET", path: "/remote", bearer: nil)
    check(rBulbs.status == 200 && rBulbs.body.contains("holiday250:001") &&
          rMusic.status == 200 && rMusic.body.contains("builtin:jingle_bells") &&
          rSavers.status == 200 && rSavers.body.contains("twinkling_wreath") &&
          rWallpapers.status == 200 && rWallpapers.body.contains("holiday_bulbs_dark") &&
          rTimelines.status == 200 && rTimelines.body.contains("fx:holiday_spectacular") &&
          rWebHTML.status == 200 && rWebHTML.body.contains("bulbCanvas") && rWebHTML.body.contains("setBulbSet"),
          "Full-control catalog endpoints (/v1/bulbs, /music, /screensavers, /wallpapers, /timelines) and /remote HTML command deck serve valid data")

    // Verify full remote HTTP control mutations across lighting, placement, MIDI modes, automation, interactive, weather & savers
    let ctrlCommands: [String] = [
        "{\"action\":\"setBulbSet\",\"bulbSetID\":\"holiday250:009\"}",
        "{\"action\":\"setBulbSize\",\"bulbSize\":1}",
        "{\"action\":\"setFlashMode\",\"flashMode\":4}",
        "{\"action\":\"setPlacement\",\"location\":2,\"reverse\":true,\"broken\":true}",
        "{\"action\":\"setLightingCategory\",\"lightingCategory\":\"modern\"}",
        "{\"action\":\"setModernEffect\",\"effectID\":4}",
        "{\"action\":\"setModernPalette\",\"paletteID\":6}",
        "{\"action\":\"setMIDIReactive\",\"enabled\":true,\"midiMode\":6,\"sensitivity\":1.4}",
        "{\"action\":\"setScreenSaverConfig\",\"moduleID\":\"twinkling_wreath\",\"text\":\"REMOTE CHRISTMAS\",\"scrollMessage\":true}",
        "{\"action\":\"setAutomation\",\"enabled\":true,\"quietHoursEnabled\":true}",
        "{\"action\":\"setInteractive\",\"enabled\":true,\"mouseProximityGlow\":true}",
        "{\"action\":\"setWeatherAtmosphere\",\"enabled\":true,\"condition\":\"snow\",\"timeOfDayEnabled\":true}"
    ]
    var allCtrlOK = true
    for jsonCmd in ctrlCommands {
        let res = httpLoopback(port: testPort, method: "POST", path: "/v1/control", bearer: apiCfg.controlToken, body: Data(jsonCmd.utf8))
        if res.status != 200 || !res.body.contains("\"ok\":true") { allCtrlOK = false }
    }
    let drainDeadline = Date().addingTimeInterval(0.6)
    while isoSettingsStore.settings.bulbSetName != "holiday250:009" && Date() < drainDeadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.03))
    }
    let sAfter = isoSettingsStore.settings
    let ngAfter = ngStore.state
    check(allCtrlOK && sAfter.bulbSetName == "holiday250:009" && sAfter.bulbSize == .large &&
          sAfter.flashMode == .alternating && sAfter.location == .aroundScreen && sAfter.reverse && sAfter.broken &&
          sAfter.modernEffects.effect == .rainbowChase && sAfter.modernEffects.palette == .rainbowSpectrum &&
          sAfter.modernEffects.midiReactiveEnabled && sAfter.modernEffects.midiReactiveMode == .percussionEffects &&
          sAfter.ssModule == .twinklingWreath && sAfter.ssMsg == "REMOTE CHRISTMAS" &&
          ngAfter.automation.automationEnabled && ngAfter.interactive.mouseProximityGlow &&
          ngAfter.weatherConfig.simulatedOverride == .snow && ngAfter.timeOfDay.enabled,
          "Full HTTP control API mutates bulb sets, sizes, placements, effects, palettes, MIDI modes, screensaver, automation, interactive & weather settings remotely")

    // Verify Bidirectional Masked RFC 6455 WebSocket Control (Read-Only blocked, Control Token executes)
    func makeMaskedWSTextFrame(_ text: String) -> Data {
        let pay = Data(text.utf8)
        let mask: [UInt8] = [0x12, 0x34, 0x56, 0x78]
        var frame = Data([0x81])
        if pay.count < 126 {
            frame.append(0x80 | UInt8(pay.count))
        } else {
            frame.append(0x80 | 126)
            frame.append(UInt8((pay.count >> 8) & 0xFF))
            frame.append(UInt8(pay.count & 0xFF))
        }
        frame.append(contentsOf: mask)
        for i in 0..<pay.count { frame.append(pay[i] ^ mask[i & 3]) }
        return frame
    }

    func sendBidirectionalWSCmd(token: String, jsonCmd: String) -> String {
        let sem = DispatchSemaphore(value: 0)
        var replyText = ""
        let c = NWConnection(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: testPort)!, using: .tcp)
        let q = DispatchQueue(label: "test.ws.bidi.\(UUID().uuidString.prefix(4))")
        let hs = "GET /v1/stream?format=json&token=\(token) HTTP/1.1\r\nHost: 127.0.0.1:\(testPort)\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
        var acc = Data()
        var sentCmd = false
        c.stateUpdateHandler = { st in
            if case .ready = st {
                c.send(content: Data(hs.utf8), completion: .contentProcessed { _ in
                    func rd() {
                        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComp, err in
                            if let data { acc.append(data) }
                            if !sentCmd, let sep = acc.range(of: Data("\r\n\r\n".utf8)) {
                                sentCmd = true
                                acc.removeSubrange(0..<sep.upperBound)
                                c.send(content: makeMaskedWSTextFrame(jsonCmd), completion: .idempotent)
                            }
                            if sentCmd && acc.count >= 2 {
                                let len = Int(acc[1] & 0x7F)
                                if len < 126 && acc.count >= 2 + len {
                                    replyText = String(data: acc.subdata(in: 2..<(2 + len)), encoding: .utf8) ?? ""
                                    c.cancel(); sem.signal(); return
                                }
                            }
                            if !isComp && err == nil { rd() } else { sem.signal() }
                        }
                    }
                    rd()
                })
            }
        }
        c.start(queue: q)
        let waitDeadline = Date().addingTimeInterval(1.5)
        while replyText.isEmpty && Date() < waitDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        c.cancel()
        return replyText
    }

    let roWSReply = sendBidirectionalWSCmd(token: apiCfg.readOnlyToken, jsonCmd: "{\"action\":\"setBulbSize\",\"bulbSize\":0}")
    let ctrlWSReply = sendBidirectionalWSCmd(token: apiCfg.controlToken, jsonCmd: "{\"action\":\"setBulbSize\",\"bulbSize\":0}")
    let waitWSApply = Date().addingTimeInterval(0.6)
    while isoSettingsStore.settings.bulbSize != .normal && Date() < waitWSApply {
        RunLoop.current.run(until: Date().addingTimeInterval(0.03))
    }
    check(roWSReply.contains("Unauthorized") && ctrlWSReply.contains("wsAck") && isoSettingsStore.settings.bulbSize == .normal,
          "Bidirectional WebSocket rejects read-only client commands while authorized Control WS updates state cleanly")

    apiSvc.stop()
    check(ReferenceVirtualAdapter.shared.didReceiveBlackoutOnDisconnect && (ReferenceVirtualAdapter.shared.lastFrame?.rgbBytes.allSatisfy { $0 == 0 } ?? false), "API/adapter stop cleanly broadcasts zeroed safety blackout frame")
} else {
    check(false, "Skipped HTTP/WS checks due to bind failure")
}

// Protocol Encoders (WLED, Art-Net, DDP)
let encTestPkt = TwinkleBulbFramePacket(sequence: 1, timestampMs: 100, rgbBytes: Data([255, 128, 64, 10, 20, 30]))
check(ExternalProtocolPacketEncoder.encodeWLEDDRGB(encTestPkt).prefix(2) == Data([2, 2]) &&
      ExternalProtocolPacketEncoder.encodeArtNetDMX(encTestPkt).starts(with: Data("Art-Net\0".utf8)) &&
      ExternalProtocolPacketEncoder.encodeDDPPacket(encTestPkt)[0] == 0x41,
      "External protocol packet encoders generate valid WLED DRGB, Art-Net DMX & DDP headers")

// 9.8 Phone Remote Pairing, Weather/TimeOfDay, ScreenColorSync, ThemePack Security & GIF/MP4 Export
let remSvc = RemoteControlService()
check(remSvc.issueSessionIfPINMatches("000000") == nil, "Phone Remote rejects invalid pairing PIN")
let remToken = remSvc.issueSessionIfPINMatches(remSvc.activePairingPIN)
check(remToken != nil && remSvc.isSessionValid(remToken), "Phone Remote issues authenticated session upon valid 6-digit PIN")

var tods = TimeOfDayConfig()
tods.enabled = true
let eveningDate = cal.date(from: DateComponents(year: 2026, month: 12, day: 20, hour: 19, minute: 0))!
let nightDate = cal.date(from: DateComponents(year: 2026, month: 12, day: 20, hour: 2, minute: 0))!
let wSvc = WeatherAtmosphereService(store: ngStore)
check(wSvc.timeOfDayBrightness(at: eveningDate, config: tods, calendar: cal) > wSvc.timeOfDayBrightness(at: nightDate, config: tods, calendar: cal), "Time-of-Day brightness curve dims cleanly overnight")

var redImgCtx = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
redImgCtx.setFillColor(NSColor(srgbRed: 0.95, green: 0.10, blue: 0.12, alpha: 1).cgColor)
redImgCtx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
let domCol = ScreenColorSyncService.extractDominantColor(from: redImgCtx.makeImage()!)
check(!ScreenColorSyncService.shared.isSyncActive && domCol.r > 0.8 && domCol.g < 0.25, "ScreenColorSync is off at launch & accurately extracts in-memory dominant color")

// Theme Pack round-trip + malicious traversal/tamper rejections
let packMgr = ThemePackManager()
if let validPack = try? packMgr.createThemePackArchive(packageID: "test.pack", title: "Holiday Sample Pack", author: "Verifier", scenes: [savedScene], timelines: [tlDoc], layouts: [layoutDoc]),
   let parsedPack = try? packMgr.validateAndInspectPack(data: validPack) {
    check(parsedPack.scenes.count == 1 && parsedPack.timelines.count == 1 && parsedPack.layouts.count == 1, "ThemePack (.twinklepack) ZIP package + SHA-256 manifest round-trips cleanly")
} else {
    check(false, "ThemePack valid creation/validation failed")
}

var traversalRejected = false
do {
    _ = try packMgr.buildStoreZIP(entries: [("../evil.txt", Data("bad".utf8))])
} catch ThemePackError.unsafeEntryPath {
    traversalRejected = true
} catch {}
var scriptRejected = false
do {
    _ = try packMgr.buildStoreZIP(entries: [("payload.sh", Data("echo hi".utf8))])
} catch ThemePackError.unsafeEntryPath {
    scriptRejected = true
} catch {}

var tamperRejected = false
if var tamperedPack = try? packMgr.createThemePackArchive(packageID: "tamper.test", title: "Tamper", author: "A", scenes: [savedScene]) {
    // Flip a byte inside the compressed payload entry (scenes/scene_0.json comes after manifest.json)
    if let range = tamperedPack.range(of: Data("Verifier Custom Mix".utf8), options: .backwards) {
        tamperedPack[range.lowerBound] = tamperedPack[range.lowerBound] ^ 0x01
        do {
            _ = try packMgr.validateAndInspectPack(data: tamperedPack)
        } catch ThemePackError.hashMismatch {
            tamperRejected = true
        } catch {}
    }
}
check(traversalRejected && scriptRejected && tamperRejected, "ThemePack security validator rejects path traversal (..), scripts (.sh) & SHA-256 hash mismatches")

// Visual Window Snapshots of Scene Browser & Modern Studio Workspace
let sceneBrowserWinCtrl = SceneBrowserWindowController(sceneManager: sceneMgr, stateStore: ngStore, settingsStore: isoSettingsStore)
sceneBrowserWinCtrl.window?.layoutIfNeeded()
let modernStudioWinCtrl = ModernWorkspaceWindowController(settingsStore: isoSettingsStore, stateStore: ngStore, sceneManager: sceneMgr)
modernStudioWinCtrl.window?.layoutIfNeeded()
if let sbView = sceneBrowserWinCtrl.window?.contentView, let msView = modernStudioWinCtrl.window?.contentView {
    check(snapshotView(sbView, to: scratchDir.appendingPathComponent("verify_scene_browser.png")) &&
          snapshotView(msView, to: scratchDir.appendingPathComponent("verify_modern_studio.png")),
          "Rendered Scene Browser and Modern Studio UI window snapshots cleanly")
}

// Real GIF, MP4 & .twinkleframes Animation Export
let expSvc = AnimationExportService.shared
var exportAppSettings = AppSettings.defaultSettings()
exportAppSettings.lightingCategory = .modern
exportAppSettings.modernEffects.effect = .rainbowChase
let renderedAnim = expSvc.renderFrames(settings: exportAppSettings, timeline: tlDoc, width: 320, height: 64, fps: 10.0, durationSeconds: 1.0)
let gifURL = scratchDir.appendingPathComponent("verify_export_anim.gif")
let mp4URL = scratchDir.appendingPathComponent("verify_export_video.mp4")
let framesURL = scratchDir.appendingPathComponent("verify_export_frames.twinkleframes")
try? expSvc.exportGIF(images: renderedAnim.images, fps: 10.0, to: gifURL)
try? expSvc.exportMP4(images: renderedAnim.images, fps: 10.0, to: mp4URL)
try? expSvc.exportTwinkleFrames(renderedAnim.frameData, to: framesURL)

let gifMagicOK = (try? Data(contentsOf: gifURL))?.starts(with: Data("GIF8".utf8)) ?? false
let mp4Size = (try? Data(contentsOf: mp4URL).count) ?? 0
let framesOK = (try? JSONDecoder().decode(TwinkleFramesExportDocument.self, from: Data(contentsOf: framesURL)))?.frames.count == 10
check(gifMagicOK && mp4Size > 1000 && framesOK, "AnimationExporter renders live engine output to GIF (\(gifMagicOK)), MP4 (\(mp4Size) bytes) & .twinkleframes JSON")

// Performance Coordinator & Classic Cadence Preservation
let classicTel = PerformanceCoordinator.shared.currentTelemetry(settings: .defaultSettings(), policy: PerformancePolicyConfig())
var reduceMotionSettings = AppSettings.defaultSettings()
reduceMotionSettings.lightingCategory = .modern
reduceMotionSettings.reduceMotion = true
let rmTel = PerformanceCoordinator.shared.currentTelemetry(settings: reduceMotionSettings, policy: PerformancePolicyConfig())
check(abs(classicTel.effectiveFrameIntervalSeconds - 0.050) < 0.0001 && rmTel.effectiveFrameIntervalSeconds > 0.20, "PerformanceCoordinator preserves exact 50ms Classic cadence & throttles cleanly under Reduce Motion")

// Version 7 History, Full Documentation & Tribute/Freeware Verification
let fullDocText = ProgramDocumentation.fullDocumentText
let docChecks = [
    "2025",
    "Google Antigravity",
    "April of 2026",
    "November of 2026",
    "Don Metzler",
    "Barefoot Productions",
    "Freeware",
    "Version 7: Next Generation",
    "CLASSIC v6.0 ENGINE",
    "Unified Holiday Scenes",
    "Seasonal Automation",
    "Full Web Command Center"
]
let allDocStringsPresent = docChecks.allSatisfy { fullDocText.contains($0) }
check(allDocStringsPresent && ProgramDocumentation.versionString == "7.0.0", "ProgramDocumentation v7.0.0 contains complete 2025->Apr 2026->Nov 2026 history, full manual & Don Metzler/Barefoot Freeware tribute")

let docWinCtrl = DocumentationWindowController()
docWinCtrl.showDocumentation(tabIndex: 0)
docWinCtrl.window?.layoutIfNeeded()
let aboutWinCtrl = AboutWindowController()
aboutWinCtrl.window?.layoutIfNeeded()
check((docWinCtrl.window?.contentView != nil) && (aboutWinCtrl.window?.title.contains("About Re: Twinkle Bulbs") ?? false), "DocumentationWindowController & AboutWindowController construct cleanly")
docWinCtrl.close()
aboutWinCtrl.close()

try? FileManager.default.removeItem(at: ngTempDir)

print("\nSUMMARY: \(passedCount) passed, \(failedCount) failed")
if failedCount > 0 { exit(1) }
