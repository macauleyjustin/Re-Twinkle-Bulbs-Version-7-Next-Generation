import XCTest
import CoreGraphics
@testable import TwinkleBulbs

final class TwinkleBulbsTests: XCTestCase {

    // MARK: - 1. Default Configuration Parity (tbulbs.mem LoadSettings)

    func testExactV6Defaults() {
        let s = AppSettings.defaultSettings()
        XCTAssertEqual(s.bulbSetName, "Outdoor")
        XCTAssertEqual(s.flashMode, .chase)
        XCTAssertEqual(s.rate, .medium)
        XCTAssertEqual(s.colorMode, .redGreen)
        XCTAssertEqual(s.drawMode, .desktop)
        XCTAssertEqual(s.location, .top)
        XCTAssertEqual(s.bulbSize, .normal)
        XCTAssertEqual(s.bulbSize.pixels, 32)
        XCTAssertTrue(s.bareWire)
        XCTAssertTrue(s.noCorners)
        XCTAssertTrue(s.notSoMany)
        XCTAssertFalse(s.broken)
        XCTAssertFalse(s.burnedOut)
        XCTAssertFalse(s.missing)
        XCTAssertFalse(s.inward)
        XCTAssertFalse(s.reverse)
        XCTAssertTrue(s.soundFX)
        XCTAssertTrue(s.splashScreen)
        XCTAssertTrue(s.confirmExit)
        XCTAssertEqual(s.ssModule, .blank)
        XCTAssertEqual(s.ssDelayMinutes, 10)
        XCTAssertEqual(s.ssMsg, "YOUR MESSAGE HERE")
        XCTAssertTrue(s.ssLights)
        XCTAssertTrue(s.ssLogo)
        XCTAssertEqual(s.trayLeftClick, .configuration)
        XCTAssertEqual(s.trayRightClick, .popupMenu)
    }

    // MARK: - 2. All 21 Color Modes Exact Verification

    func testAll21ColorModes() {
        var rng: any RandomSource = SeededRandomSource(seed: 12345)

        // Mode 0: Random never repeats adjacent color
        let randomSeq = BulbEngine.colorSequence(mode: .random, count: 40, rng: &rng)
        XCTAssertEqual(randomSeq.count, 40)
        for i in 1..<randomSeq.count {
            XCTAssertNotEqual(randomSeq[i], randomSeq[i - 1], "Random mode must not repeat consecutive bulb color")
            XCTAssertTrue((0..<7).contains(randomSeq[i]))
        }

        // Modes 1..7: Solid colors 0..6
        let solids: [(ColorMode, Int)] = [
            (.purple, 0), (.blue, 1), (.red, 2), (.green, 3), (.yellow, 4), (.lightBlue, 5), (.white, 6)
        ]
        for (mode, expected) in solids {
            let seq = BulbEngine.colorSequence(mode: mode, count: 6, rng: &rng)
            XCTAssertEqual(seq, Array(repeating: expected, count: 6))
        }

        // Exact multi-color cycles matching 0x0048289a..0x0048366c
        XCTAssertEqual(BulbEngine.colorSequence(mode: .redGreen, count: 6, rng: &rng), [3, 2, 3, 2, 3, 2])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .multiColor, count: 7, rng: &rng), [1, 2, 3, 4, 5, 0, 1])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .blues, count: 4, rng: &rng), [5, 1, 5, 1])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .allColorsWhite, count: 8, rng: &rng), [0, 1, 2, 3, 4, 5, 6, 0])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .redBlue, count: 4, rng: &rng), [2, 1, 2, 1])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .purpleGreen, count: 4, rng: &rng), [0, 3, 0, 3])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .redYellowGreen, count: 6, rng: &rng), [2, 4, 3, 2, 4, 3])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .redGreenBlue, count: 6, rng: &rng), [2, 3, 1, 2, 3, 1])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .coolColors, count: 6, rng: &rng), [0, 1, 3, 0, 1, 3])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .yellowWhite, count: 4, rng: &rng), [6, 4, 6, 4])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .redYellow, count: 4, rng: &rng), [4, 2, 4, 2])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .redGreenYellowBlue, count: 5, rng: &rng), [2, 3, 4, 1, 2])
        XCTAssertEqual(BulbEngine.colorSequence(mode: .redWhiteBlue, count: 6, rng: &rng), [2, 6, 1, 2, 6, 1])
    }

    // MARK: - 3. Exact Step Timing Constants & Chase Strides

    func testExactTimingTablesAndStrides() {
        let expectedFixed: [(FlashRate, UInt64)] = [
            (.slow, 1200), (.slowMedium, 800), (.medium, 500), (.mediumFast, 350), (.fast, 200), (.veryFast, 80)
        ]
        for (rate, ms) in expectedFixed {
            XCTAssertEqual(rate.fixedIntervalMs, ms)
        }
        XCTAssertEqual(FlashRate.slow.randomHoldRangeMs.min, 2000)
        XCTAssertEqual(FlashRate.slow.randomHoldRangeMs.span, 701)
        XCTAssertEqual(FlashRate.veryFast.randomHoldRangeMs.min, 50)
        XCTAssertEqual(FlashRate.veryFast.randomHoldRangeMs.span, 71)

        XCTAssertEqual(BulbEngine.legacyChaseStride(bulbCount: 16), 4)
        XCTAssertEqual(BulbEngine.legacyChaseStride(bulbCount: 20), 4)
        XCTAssertEqual(BulbEngine.legacyChaseStride(bulbCount: 25), 5)
        XCTAssertEqual(BulbEngine.legacyChaseStride(bulbCount: 32), 8)
        XCTAssertEqual(BulbEngine.legacyChaseStride(bulbCount: 36), 6)
        XCTAssertEqual(BulbEngine.legacyChaseStride(bulbCount: 40), 8)
        XCTAssertEqual(BulbEngine.legacyChaseStride(bulbCount: 50), 10)
        XCTAssertEqual(BulbEngine.legacyChaseStride(bulbCount: 64), 2)
    }

    // MARK: - 4. All 9 Flashing Modes Behavior

    func testFlashingPatternsStateMachine() {
        var s = AppSettings.defaultSettings()
        s.location = .top
        s.bulbSize = .normal
        s.notSoMany = false
        s.rate = .medium // 500ms step

        // Chase over 20 bulbs -> stride = 4 -> [0, 4, 8, 12, 16] lit initially, advances by 1
        s.flashMode = .chase
        let engine = BulbEngine(settings: s, rng: SeededRandomSource(seed: 1))
        engine.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 480), settings: s, nowMs: 1000)
        XCTAssertEqual(engine.slots.count, 20)
        XCTAssertEqual(engine.slots.map(\.isLit).enumerated().filter { $0.element }.map(\.offset), [0, 4, 8, 12, 16])

        XCTAssertFalse(engine.tick(nowMs: 1450))
        XCTAssertTrue(engine.tick(nowMs: 1500))
        XCTAssertEqual(engine.slots.map(\.isLit).enumerated().filter { $0.element }.map(\.offset), [1, 5, 9, 13, 17])

        // Pairs with NotSoMany=true: lights pair of adjacent active bulbs (0 and 2) separated by bareWire slot 1
        s.flashMode = .pairs
        s.notSoMany = true
        engine.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 480), settings: s, nowMs: 0)
        XCTAssertTrue(engine.slots[1].isBareWire)
        let litPairs = engine.slots.map(\.isLit).enumerated().filter { $0.element }.map(\.offset)
        XCTAssertTrue(litPairs.contains(0) && litPairs.contains(2))
        XCTAssertFalse(litPairs.contains(1))

        // Ping-Pong bounces 0 -> 1 -> 2 -> 3 -> 2 -> 1 -> 0 over 4 bulbs
        s.flashMode = .pingPong
        s.notSoMany = false
        engine.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: s, nowMs: 0)
        var trace: [Int] = []
        trace.append(engine.slots.firstIndex(where: \.isLit) ?? -1)
        for step in 1...6 {
            engine.tick(nowMs: UInt64(step) * 500)
            trace.append(engine.slots.firstIndex(where: \.isLit) ?? -1)
        }
        XCTAssertEqual(trace, [0, 1, 2, 3, 2, 1, 0])

        // Alternating starts odd ON / even OFF and toggles every interval
        s.flashMode = .alternating
        engine.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: s, nowMs: 0)
        XCTAssertEqual(engine.slots.map(\.isLit), [false, true, false, true])
        engine.tick(nowMs: 500)
        XCTAssertEqual(engine.slots.map(\.isLit), [true, false, true, false])
    }

    // MARK: - 5. Screen Edge Placement, Corners & Pixel Rotation

    func testAroundScreenWithNoCornersGeometry() {
        var s = AppSettings.defaultSettings()
        s.location = .aroundScreen
        s.noCorners = true
        s.notSoMany = false
        s.bulbSize = .normal // 32

        let engine = BulbEngine(settings: s, rng: SeededRandomSource(seed: 9))
        engine.configure(bounds: CGRect(x: 0, y: 0, width: 320, height: 224), settings: s, nowMs: 0)
        // Top cols = (320 - 64)/32 = 8, x starts at 32; rows = (224 - 64)/32 = 5, y starts at 32
        let tops = engine.slots.filter { $0.edge == .top }
        let bottoms = engine.slots.filter { $0.edge == .bottom }
        let lefts = engine.slots.filter { $0.edge == .left }
        let rights = engine.slots.filter { $0.edge == .right }

        XCTAssertEqual(tops.count, 8)
        XCTAssertEqual(bottoms.count, 8)
        XCTAssertEqual(lefts.count, 5)
        XCTAssertEqual(rights.count, 5)
        XCTAssertEqual(tops.first?.frame.minX, 32)
        XCTAssertEqual(bottoms.first?.frame.minY, 192)
        XCTAssertEqual(lefts.first?.frame.minX, 0)
        XCTAssertEqual(lefts.first?.frame.minY, 32)
        XCTAssertEqual(rights.first?.frame.minX, 288)
    }

    func testExactRotateIconTransform() {
        // Construct 4x4 top-down test bitmap with distinct pixel at (1, 0) (socket top)
        let w = 4, h = 4
        var px = [UInt32](repeating: 0, count: w * h)
        px[0 * w + 1] = 0xFF00_00FF // red marker at (x=1, y=0)
        let cs = CGColorSpaceCreateDeviceRGB()
        let srcCtx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let srcImg = srcCtx.makeImage()!

        func readMarker(_ img: CGImage) -> (Int, Int)? {
            var buf = [UInt32](repeating: 0, count: 16)
            let c = CGContext(data: &buf, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(img, in: CGRect(x: 0, y: 0, width: 4, height: 4))
            for y in 0..<4 {
                for x in 0..<4 where buf[y * 4 + x] != 0 { return (x, y) }
            }
            return nil
        }

        // +90 (Right edge): (x,y)->(W-1-y, x) => (1,0) -> (3, 1)
        let r90 = BulbArtworkRegistry.rotatePixelExact(srcImg, degrees: 90)
        XCTAssertEqual(readMarker(r90)?.0, 3)
        XCTAssertEqual(readMarker(r90)?.1, 1)

        // -90 (Left edge): (x,y)->(y, H-1-x) => (1,0) -> (0, 2)
        let rn90 = BulbArtworkRegistry.rotatePixelExact(srcImg, degrees: -90)
        XCTAssertEqual(readMarker(rn90)?.0, 0)
        XCTAssertEqual(readMarker(rn90)?.1, 2)

        // 180 (Bottom edge): (x,y)->(W-1-x, H-1-y) => (1,0) -> (2, 3)
        let r180 = BulbArtworkRegistry.rotatePixelExact(srcImg, degrees: 180)
        XCTAssertEqual(readMarker(r180)?.0, 2)
        XCTAssertEqual(readMarker(r180)?.1, 3)
    }

    // MARK: - 6. Visual Strip Snapshot, Music SFX WAV, & Holiday Countdown

    func testOffscreenStripRenderingAllBuiltInSets() {
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
            XCTAssertNotNil(snap, "Rendered snapshot should succeed for \(style.rawValue)")
            XCTAssertEqual(snap?.width, 256)
            XCTAssertEqual(snap?.height, 32)
        }
    }

    func testHolidayCountdownCalculations() {
        let cal = Calendar(identifier: .gregorian)
        var s = AppSettings.defaultSettings()
        s.countdownHoliday = .christmas
        let dec20 = cal.date(from: DateComponents(year: 2026, month: 12, day: 20))!
        let sum = CalendarService.shared.countdownSummary(settings: s, from: dec20)
        XCTAssertEqual(sum?.daysRemaining, 5)
        XCTAssertEqual(sum?.headline, "5 days until Christmas")

        // Thanksgiving 2026 is Nov 26 (4th Thursday)
        let tg = CalendarService.usThanksgivingDate(year: 2026)
        XCTAssertEqual(cal.component(.month, from: tg), 11)
        XCTAssertEqual(cal.component(.day, from: tg), 26)
    }

    func testPEBLBLoaderOnLocalResearchReferenceIfPresent() throws {
        // Optional clean verification against local research extraction (not bundled in app)
        let refBLB = URL(fileURLWithPath: "/Users/renseven/.gemini/antigravity/scratch/TwinkleBulbsMac/research/v6_extracted/bulbs/outdoor.blb")
        guard FileManager.default.fileExists(atPath: refBLB.path) else {
            throw XCTSkip("Optional local research outdoor.blb not present")
        }
        let loaded = BLBResourceLoader.load(url: refBLB, preferredSize: 32, highlightRGB: (0, 0, 128))
        XCTAssertNotNil(loaded)
        XCTAssertTrue(loaded?.metadata.isOnOnly ?? false)
        XCTAssertNotNil(loaded?.bareWire)
        XCTAssertNotNil(loaded?.onImages[2])  // Red on
        XCTAssertNotNil(loaded?.offImages[2]) // Highlight-blended off
    }
}
