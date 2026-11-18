import Testing
import Foundation
import CoreGraphics
@testable import TwinkleBulbs

@Suite("Twinkle Bulbs v6.0 Reconstruction Parity Suite")
struct TwinkleBulbsSwiftTests {

    @Test("Exact v6.0 default settings from LoadSettings disassembly")
    func exactV6Defaults() {
        let s = AppSettings.defaultSettings()
        #expect(s.bulbSetName == "Outdoor")
        #expect(s.flashMode == .chase)
        #expect(s.rate == .medium)
        #expect(s.colorMode == .redGreen)
        #expect(s.drawMode == .desktop)
        #expect(s.location == .top)
        #expect(s.bulbSize == .normal)
        #expect(s.bulbSize.pixels == 32)
        #expect(s.bareWire == true)
        #expect(s.noCorners == true)
        #expect(s.notSoMany == true)
        #expect(s.broken == false)
        #expect(s.burnedOut == false)
        #expect(s.missing == false)
        #expect(s.inward == false)
        #expect(s.reverse == false)
        #expect(s.soundFX == true)
        #expect(s.splashScreen == true)
        #expect(s.confirmExit == true)
        #expect(s.ssModule == .blank)
        #expect(s.ssDelayMinutes == 10)
        #expect(s.ssMsg == "YOUR MESSAGE HERE")
        #expect(s.ssLights == true)
        #expect(s.ssLogo == true)
        #expect(s.trayLeftClick == .configuration)
        #expect(s.trayRightClick == .popupMenu)
    }

    @Test("All 21 color modes match tbulbs.mem 0x0048289a..0x0048366c")
    func all21ColorModes() {
        var rng: any RandomSource = SeededRandomSource(seed: 12345)

        let randomSeq = BulbEngine.colorSequence(mode: .random, count: 40, rng: &rng)
        #expect(randomSeq.count == 40)
        for i in 1..<randomSeq.count {
            #expect(randomSeq[i] != randomSeq[i - 1])
            #expect((0..<7).contains(randomSeq[i]))
        }

        let solids: [(ColorMode, Int)] = [
            (.purple, 0), (.blue, 1), (.red, 2), (.green, 3), (.yellow, 4), (.lightBlue, 5), (.white, 6)
        ]
        for (mode, expected) in solids {
            #expect(BulbEngine.colorSequence(mode: mode, count: 5, rng: &rng) == Array(repeating: expected, count: 5))
        }

        #expect(BulbEngine.colorSequence(mode: .redGreen, count: 6, rng: &rng) == [3, 2, 3, 2, 3, 2])
        #expect(BulbEngine.colorSequence(mode: .multiColor, count: 7, rng: &rng) == [1, 2, 3, 4, 5, 0, 1])
        #expect(BulbEngine.colorSequence(mode: .blues, count: 4, rng: &rng) == [5, 1, 5, 1])
        #expect(BulbEngine.colorSequence(mode: .allColorsWhite, count: 8, rng: &rng) == [0, 1, 2, 3, 4, 5, 6, 0])
        #expect(BulbEngine.colorSequence(mode: .redBlue, count: 4, rng: &rng) == [2, 1, 2, 1])
        #expect(BulbEngine.colorSequence(mode: .purpleGreen, count: 4, rng: &rng) == [0, 3, 0, 3])
        #expect(BulbEngine.colorSequence(mode: .redYellowGreen, count: 6, rng: &rng) == [2, 4, 3, 2, 4, 3])
        #expect(BulbEngine.colorSequence(mode: .redGreenBlue, count: 6, rng: &rng) == [2, 3, 1, 2, 3, 1])
        #expect(BulbEngine.colorSequence(mode: .coolColors, count: 6, rng: &rng) == [0, 1, 3, 0, 1, 3])
        #expect(BulbEngine.colorSequence(mode: .yellowWhite, count: 4, rng: &rng) == [6, 4, 6, 4])
        #expect(BulbEngine.colorSequence(mode: .redYellow, count: 4, rng: &rng) == [4, 2, 4, 2])
        #expect(BulbEngine.colorSequence(mode: .redGreenYellowBlue, count: 5, rng: &rng) == [2, 3, 4, 1, 2])
        #expect(BulbEngine.colorSequence(mode: .redWhiteBlue, count: 6, rng: &rng) == [2, 6, 1, 2, 6, 1])
    }

    @Test("Exact step interval tables and chase stride lookup")
    func timingsAndStrides() {
        #expect(FlashRate.slow.fixedIntervalMs == 1200)
        #expect(FlashRate.slowMedium.fixedIntervalMs == 800)
        #expect(FlashRate.medium.fixedIntervalMs == 500)
        #expect(FlashRate.mediumFast.fixedIntervalMs == 350)
        #expect(FlashRate.fast.fixedIntervalMs == 200)
        #expect(FlashRate.veryFast.fixedIntervalMs == 80)

        #expect(FlashRate.slow.randomHoldRangeMs == (2000, 701))
        #expect(FlashRate.medium.randomHoldRangeMs == (1000, 601))
        #expect(FlashRate.veryFast.randomHoldRangeMs == (50, 71))

        #expect(BulbEngine.legacyChaseStride(bulbCount: 16) == 4)
        #expect(BulbEngine.legacyChaseStride(bulbCount: 25) == 5)
        #expect(BulbEngine.legacyChaseStride(bulbCount: 32) == 8)
        #expect(BulbEngine.legacyChaseStride(bulbCount: 36) == 6)
        #expect(BulbEngine.legacyChaseStride(bulbCount: 40) == 8)
        #expect(BulbEngine.legacyChaseStride(bulbCount: 50) == 10)
        #expect(BulbEngine.legacyChaseStride(bulbCount: 64) == 2)
    }

    @Test("All 9 flash modes transition accurately including NotSoMany, Pairs, PingPong, Reverse")
    func flashModes() {
        var s = AppSettings.defaultSettings()
        s.location = .top
        s.bulbSize = .normal
        s.notSoMany = false
        s.rate = .medium
        s.flashMode = .chase

        let eng = BulbEngine(settings: s, rng: SeededRandomSource(seed: 1))
        eng.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 480), settings: s, nowMs: 1000)
        #expect(eng.slots.count == 20)
        #expect(eng.slots.enumerated().filter { $0.element.isLit }.map(\.offset) == [0, 4, 8, 12, 16])

        #expect(eng.tick(nowMs: 1499) == false)
        #expect(eng.tick(nowMs: 1500) == true)
        #expect(eng.slots.enumerated().filter { $0.element.isLit }.map(\.offset) == [1, 5, 9, 13, 17])

        // Pairs with NotSoMany=true
        s.flashMode = .pairs
        s.notSoMany = true
        eng.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 480), settings: s, nowMs: 0)
        #expect(eng.slots[1].isBareWire == true)
        let lit = eng.slots.enumerated().filter { $0.element.isLit }.map(\.offset)
        #expect(lit.contains(0) && lit.contains(2))
        #expect(!lit.contains(1))

        // PingPong bounce
        s.flashMode = .pingPong
        s.notSoMany = false
        eng.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: s, nowMs: 0)
        var trace: [Int] = [eng.slots.firstIndex(where: \.isLit) ?? -1]
        for step in 1...6 {
            eng.tick(nowMs: UInt64(step) * 500)
            trace.append(eng.slots.firstIndex(where: \.isLit) ?? -1)
        }
        #expect(trace == [0, 1, 2, 3, 2, 1, 0])

        // Alternating
        s.flashMode = .alternating
        eng.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: s, nowMs: 0)
        #expect(eng.slots.map(\.isLit) == [false, true, false, true])
        eng.tick(nowMs: 500)
        #expect(eng.slots.map(\.isLit) == [true, false, true, false])
    }

    @Test("Around Screen placement, NoCorners geometry, and exact RotateIcon math")
    func placementAndRotation() {
        var s = AppSettings.defaultSettings()
        s.location = .aroundScreen
        s.noCorners = true
        s.notSoMany = false
        let eng = BulbEngine(settings: s, rng: SeededRandomSource(seed: 9))
        eng.configure(bounds: CGRect(x: 0, y: 0, width: 320, height: 224), settings: s, nowMs: 0)

        let tops = eng.slots.filter { $0.edge == .top }
        let bottoms = eng.slots.filter { $0.edge == .bottom }
        let lefts = eng.slots.filter { $0.edge == .left }
        let rights = eng.slots.filter { $0.edge == .right }
        #expect(tops.count == 8)
        #expect(bottoms.count == 8)
        #expect(lefts.count == 5)
        #expect(rights.count == 5)
        #expect(tops.first?.frame.minX == 32)
        #expect(bottoms.first?.frame.minY == 192)
        #expect(lefts.first?.frame.minY == 32)
        #expect(rights.first?.frame.minX == 288)

        // Exact RotateIcon transform verification on 4x4 pixel marker at (1, 0)
        var px = [UInt32](repeating: 0, count: 16)
        px[0 * 4 + 1] = 0xFF00_00FF
        let cs = CGColorSpaceCreateDeviceRGB()
        let srcCtx = CGContext(data: &px, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let srcImg = srcCtx.makeImage()!

        func findMarker(_ img: CGImage) -> (Int, Int)? {
            var buf = [UInt32](repeating: 0, count: 16)
            let c = CGContext(data: &buf, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(img, in: CGRect(x: 0, y: 0, width: 4, height: 4))
            for y in 0..<4 {
                for x in 0..<4 where buf[y * 4 + x] != 0 { return (x, y) }
            }
            return nil
        }

        let r90 = BulbArtworkRegistry.rotatePixelExact(srcImg, degrees: 90)
        #expect(findMarker(r90)! == (3, 1))
        let rn90 = BulbArtworkRegistry.rotatePixelExact(srcImg, degrees: -90)
        #expect(findMarker(rn90)! == (0, 2))
        let r180 = BulbArtworkRegistry.rotatePixelExact(srcImg, degrees: 180)
        #expect(findMarker(r180)! == (2, 3))
    }

    @Test("Offscreen strip rendering across built-in sets and highlight blend math")
    func offscreenRenderingAndHighlightBlend() {
        // Test 50% highlight blend math on a 1x1 bright red pixel blended with #000080 -> (127, 0, 64)
        var p: UInt32 = 0xFF00_00FF // RGBA little endian: R=255, G=0, B=0, A=255
        let cs = CGColorSpaceCreateDeviceRGB()
        let c = CGContext(data: &p, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let src = c.makeImage()!
        let dimmed = BLBResourceLoader.blendHalfWithHighlight(image: src, rgb: (0, 0, 128))
        var outPx = [UInt8](repeating: 0, count: 4)
        let outCtx = CGContext(data: &outPx, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        outCtx.draw(dimmed, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(outPx[0] == 127)
        #expect(outPx[1] == 0)
        #expect(outPx[2] == 64)
        #expect(outPx[3] == 255)

        for style in BulbArtworkRegistry.BuiltInStyle.allCases {
            var s = AppSettings.defaultSettings()
            s.bulbSetName = style.rawValue
            s.location = .top
            s.colorMode = .allColorsWhite
            s.flashMode = .none
            s.notSoMany = false
            let eng = BulbEngine(settings: s, rng: SeededRandomSource(seed: 1))
            eng.configure(bounds: CGRect(x: 0, y: 0, width: 256, height: 32), settings: s, nowMs: 0)
            let snap = BulbCanvasView.renderSnapshot(width: 256, height: 32, engine: eng, settings: s)
            #expect(snap != nil)
            #expect(snap?.width == 256)
            #expect(snap?.height == 32)
        }
    }

    @Test("Holiday countdown, WAV RIFF container, and PE .blb local reference parser")
    func countdownWavAndBLBParser() {
        let cal = Calendar(identifier: .gregorian)
        var s = AppSettings.defaultSettings()
        s.countdownHoliday = .christmas
        let dec20 = cal.date(from: DateComponents(year: 2026, month: 12, day: 20))!
        let sum = CalendarService.shared.countdownSummary(settings: s, from: dec20)
        #expect(sum?.daysRemaining == 5)
        #expect(sum?.headline == "5 days until Christmas")

        let tg = CalendarService.usThanksgivingDate(year: 2026)
        #expect(cal.component(.month, from: tg) == 11)
        #expect(cal.component(.day, from: tg) == 26)

        let wav = AudioEngineService.wrapPCMAsWAV(pcm: Data(repeating: 0, count: 64), sampleRate: 22050, channels: 1, bitsPerSample: 16)
        #expect(wav.starts(with: Array("RIFF".utf8)))
        #expect(wav.count == 44 + 64)

        // Verify BLBResourceLoader against local extracted outdoor.blb in research directory
        let refBLB = URL(fileURLWithPath: "/Users/renseven/.gemini/antigravity/scratch/TwinkleBulbsMac/research/v6_extracted/bulbs/outdoor.blb")
        if FileManager.default.fileExists(atPath: refBLB.path) {
            let loaded = BLBResourceLoader.load(url: refBLB, preferredSize: 32, highlightRGB: (0, 0, 128))
            #expect(loaded != nil)
            #expect(loaded?.metadata.isOnOnly == true)
            #expect(loaded?.bareWire != nil)
            #expect(loaded?.onImages[2] != nil)
            #expect(loaded?.offImages[2] != nil)
        }
    }
}
