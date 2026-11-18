import Foundation
import CoreGraphics

// MARK: - Bulb Slot & Deterministic RNG

public struct BulbSlot: Equatable {
    public let index: Int
    public let frame: CGRect
    public let edge: BulbEdge
    public let colorIndex: Int
    public let isBareWire: Bool
    public let isMissing: Bool
    public let isBroken: Bool
    public let isBurnedOut: Bool
    public var isLit: Bool
    public var flashable: Bool
    public var nextToggleMs: UInt64

    public init(
        index: Int, frame: CGRect, edge: BulbEdge, colorIndex: Int,
        isBareWire: Bool, isMissing: Bool, isBroken: Bool, isBurnedOut: Bool,
        isLit: Bool, flashable: Bool, nextToggleMs: UInt64
    ) {
        self.index = index
        self.frame = frame
        self.edge = edge
        self.colorIndex = colorIndex
        self.isBareWire = isBareWire
        self.isMissing = isMissing
        self.isBroken = isBroken
        self.isBurnedOut = isBurnedOut
        self.isLit = isLit
        self.flashable = flashable
        self.nextToggleMs = nextToggleMs
    }

    /// Visual slot state used during rendering
    public enum VisualState: Equatable {
        case empty
        case bareWire
        case broken(colorIndex: Int)
        case bulb(colorIndex: Int, lit: Bool)
    }

    public var visualState: VisualState {
        if isMissing {
            return isBareWire ? .bareWire : .empty
        }
        if isBareWire {
            return .bareWire
        }
        if isBroken {
            return .broken(colorIndex: colorIndex)
        }
        return .bulb(colorIndex: colorIndex, lit: isLit && !isBurnedOut)
    }
}

public protocol RandomSource {
    mutating func nextInt(upperBound: Int) -> Int
}

public struct SystemRandomSource: RandomSource {
    public init() {}
    public mutating func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int.random(in: 0..<upperBound)
    }
}

public struct SeededRandomSource: RandomSource {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        // SplitMix64 for reproducible tests
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Int(z % UInt64(upperBound))
    }
}

// MARK: - BulbEngine

/// Clean-room reconstruction of Twinkle Bulbs v6.0 strip layout, color sequences, and flash algorithms.
public final class BulbEngine {
    public private(set) var slots: [BulbSlot] = []
    public private(set) var bounds: CGRect = .zero
    public private(set) var settings: AppSettings

    private var headIndex: Int = 0
    private var pingPongDirection: Int = 1
    private var globalToggleState: Bool = false
    private var nextFixedStepMs: UInt64 = 0
    private var rng: any RandomSource

    public init(settings: AppSettings = .defaultSettings(), rng: any RandomSource = SystemRandomSource()) {
        self.settings = settings
        self.rng = rng
    }

    /// Computes canonical C/Win32-equivalent color index for slot `slotIdx`, matching InitLights @ 0x0048289a.
    public static func colorSequence(mode: ColorMode, count: Int, rng: inout any RandomSource) -> [Int] {
        var result: [Int] = []
        result.reserveCapacity(count)

        var c2 = 0 // toggles 1, 0, 1, 0 via (1 - c2) BEFORE switch
        var c6 = 0 // increments (c6 + 1) % 6 BEFORE switch
        var c7 = -1 // increments (c7 + 1) % 7 BEFORE switch
        var c3 = 0 // increments AFTER switch mod 3
        var c4 = 0 // increments AFTER switch mod 4
        var prevRandom = -1

        for _ in 0..<count {
            c2 = 1 - c2
            c6 = (c6 + 1) % 6
            c7 = (c7 + 1) % 7

            let chosen: Int
            switch mode {
            case .random:
                var pick = rng.nextInt(upperBound: 7)
                var guardCount = 0
                while pick == prevRandom && guardCount < 16 {
                    pick = rng.nextInt(upperBound: 7)
                    guardCount += 1
                }
                chosen = pick
                prevRandom = pick
            case .purple: chosen = 0
            case .blue: chosen = 1
            case .red: chosen = 2
            case .green: chosen = 3
            case .yellow: chosen = 4
            case .lightBlue: chosen = 5
            case .white: chosen = 6
            case .redGreen:
                // 0x482969: c2 + 2 -> 3 (Green), 2 (Red)
                chosen = c2 + 2
            case .multiColor:
                chosen = c6
            case .blues:
                // 0x48299c: c2*4 + 1 -> 5 (Light Blue), 1 (Blue)
                chosen = c2 * 4 + 1
            case .allColorsWhite:
                chosen = c7
            case .redBlue:
                // 0x4829d3: c2 + 1 -> 2 (Red), 1 (Blue)
                chosen = c2 + 1
            case .purpleGreen:
                // 0x4829ee: c2 == 0 ? 3 : 0 -> 0 (Purple), 3 (Green)
                chosen = (c2 == 0) ? 3 : 0
            case .redYellowGreen:
                chosen = [2, 4, 3][c3]
            case .redGreenBlue:
                chosen = [2, 3, 1][c3]
            case .coolColors:
                chosen = [0, 1, 3][c3]
            case .yellowWhite:
                chosen = (c2 == 0) ? 4 : 6
            case .redYellow:
                chosen = (c2 == 0) ? 2 : 4
            case .redGreenYellowBlue:
                chosen = [2, 3, 4, 1][c4]
            case .redWhiteBlue:
                chosen = [2, 6, 1][c3]
            }

            c3 = (c3 + 1) % 3
            c4 = (c4 + 1) % 4
            result.append(chosen)
        }
        return result
    }

    /// Computes exact chase stride matching UpdateLights @ 0x004846d8.
    /// For > 50 bulbs on modern high-resolution displays, falls back cleanly to 10 (or 8) when > 50 instead of 2 when NotSoMany is active so Chase remains crisp.
    public static func chaseStride(bulbCount n: Int, notSoMany: Bool = false) -> Int {
        if n <= 20 { return 4 }
        if n <= 25 { return 5 }
        if n <= 32 { return 8 }
        if n <= 36 { return 6 }
        if n <= 40 { return 8 }
        if n <= 50 { return 10 }
        return notSoMany ? 8 : 6
    }

    /// Original binary exact stride lookup for testing compatibility
    public static func legacyChaseStride(bulbCount n: Int) -> Int {
        if n <= 20 { return 4 }
        if n <= 25 { return 5 }
        if n <= 32 { return 8 }
        if n <= 36 { return 6 }
        if n <= 40 { return 8 }
        if n <= 50 { return 10 }
        return 2
    }

    /// Rebuilds the entire bulb layout and initializes bulb states.
    public func configure(bounds: CGRect, settings: AppSettings, nowMs: UInt64 = 0) {
        self.bounds = bounds
        self.settings = settings
        self.slots.removeAll()

        let sz = CGFloat(settings.bulbSize.pixels)
        let width = Int(floor(bounds.width))
        let height = Int(floor(bounds.height))
        let szi = Int(sz)
        guard width >= szi, height >= szi, szi > 0 else { return }

        let loc = settings.location
        let hasTop = (loc == .top || loc == .topAndBottom || loc == .aroundScreen || loc == .topAndSides)
        let hasBottom = (loc == .topAndBottom || loc == .aroundScreen || loc == .bottomOnly)
        let hasSides = (loc == .aroundScreen || loc == .sidesOnly || loc == .topAndSides)

        // Exact edge column/row math from InitLights @ 0x004822c4..0x004826e4
        let cols: Int
        if loc == .aroundScreen && settings.noCorners {
            cols = max(0, (width - 2 * szi) / szi)
        } else if loc == .topAndSides && settings.noCorners {
            cols = max(0, (width - 2 * szi) / szi)
        } else {
            cols = max(0, width / szi)
        }

        let rows: Int
        if loc == .sidesOnly {
            rows = max(0, height / szi)
        } else if loc == .topAndSides {
            // Top bar uses top szi band; sides extend to bottom
            rows = max(0, (height - szi) / szi)
        } else {
            rows = max(0, (height - 2 * szi) / szi)
        }

        let horizOffset: CGFloat
        if settings.noCorners || loc == .aroundScreen || loc == .topAndSides {
            horizOffset = bounds.minX + floor(CGFloat(width - cols * szi) / 2.0)
        } else {
            horizOffset = bounds.minX + floor(CGFloat(width - cols * szi) / 2.0)
        }

        let vertStartOffset: CGFloat
        if loc == .sidesOnly {
            vertStartOffset = bounds.minY + floor(CGFloat(height - rows * szi) / 2.0)
        } else if loc == .topAndSides {
            vertStartOffset = bounds.minY + sz + floor(CGFloat((height - szi) - rows * szi) / 2.0)
        } else {
            vertStartOffset = bounds.minY + sz + floor(CGFloat((height - 2 * szi) - rows * szi) / 2.0)
        }

        var placements: [(frame: CGRect, edge: BulbEdge, isEdgeSlotOdd: Bool)] = []

        if hasTop {
            for j in 0..<cols {
                let rect = CGRect(x: horizOffset + CGFloat(j) * sz, y: bounds.minY, width: sz, height: sz)
                placements.append((rect, .top, j % 2 == 1))
            }
        }
        if hasBottom {
            for j in 0..<cols {
                let rect = CGRect(x: horizOffset + CGFloat(j) * sz, y: bounds.maxY - sz, width: sz, height: sz)
                placements.append((rect, .bottom, j % 2 == 1))
            }
        }
        if hasSides {
            for j in 0..<rows {
                let rect = CGRect(x: bounds.minX, y: vertStartOffset + CGFloat(j) * sz, width: sz, height: sz)
                placements.append((rect, .left, j % 2 == 1))
            }
            for j in 0..<rows {
                let rect = CGRect(x: bounds.maxX - sz, y: vertStartOffset + CGFloat(j) * sz, width: sz, height: sz)
                placements.append((rect, .right, j % 2 == 1))
            }
        }

        // Assign colors across active (non-bare-wire) bulb positions
        let activePositions = placements.indices.filter { !(settings.notSoMany && placements[$0].isEdgeSlotOdd) }
        let colorSeq = Self.colorSequence(mode: settings.colorMode, count: activePositions.count, rng: &rng)
        var colorLookup = [Int: Int]()
        for (k, pos) in activePositions.enumerated() {
            colorLookup[pos] = colorSeq[k]
        }

        var built: [BulbSlot] = []
        built.reserveCapacity(placements.count)

        for (i, item) in placements.enumerated() {
            let isWireSlot = settings.notSoMany && item.isEdgeSlotOdd
            if isWireSlot {
                built.append(BulbSlot(
                    index: i,
                    frame: item.frame,
                    edge: item.edge,
                    colorIndex: 0,
                    isBareWire: settings.bareWire,
                    isMissing: !settings.bareWire,
                    isBroken: false,
                    isBurnedOut: false,
                    isLit: false,
                    flashable: false,
                    nextToggleMs: 0
                ))
                continue
            }

            let cIdx = colorLookup[i] ?? 2
            let missing = settings.missing && (rng.nextInt(upperBound: 101) < 20)
            let broken = !missing && settings.broken && (rng.nextInt(upperBound: 101) < 16)
            let burnedOut = !missing && !broken && settings.burnedOut && (rng.nextInt(upperBound: 101) < 30)

            let flashable: Bool
            if settings.flashMode == .someFlash {
                flashable = rng.nextInt(upperBound: 51) < 15
            } else {
                flashable = true
            }

            let initialLit: Bool
            switch settings.flashMode {
            case .none:
                initialLit = true
            case .random:
                initialLit = rng.nextInt(upperBound: 2) == 1
            case .allTogether:
                initialLit = false
            case .alternating:
                let activeOrdinal = (i / (settings.notSoMany ? 2 : 1))
                initialLit = (activeOrdinal % 2 == 1)
            case .someFlash:
                initialLit = flashable ? (rng.nextInt(upperBound: 2) == 1) : true
            case .chase, .single, .pairs, .pingPong:
                initialLit = false
            }

            let holdRange = settings.rate.randomHoldRangeMs
            let nextHold = holdRange.min + UInt64(rng.nextInt(upperBound: Int(holdRange.span)))

            built.append(BulbSlot(
                index: i,
                frame: item.frame,
                edge: item.edge,
                colorIndex: cIdx,
                isBareWire: false,
                isMissing: missing,
                isBroken: broken,
                isBurnedOut: burnedOut,
                isLit: (missing || broken || burnedOut) ? false : initialLit,
                flashable: flashable,
                nextToggleMs: nowMs + nextHold
            ))
        }

        self.slots = built
        let step = settings.notSoMany ? 2 : 1
        if settings.reverse && !built.isEmpty {
            let lastEven = ((built.count - 1) / step) * step
            self.headIndex = max(0, lastEven)
            self.pingPongDirection = -1
        } else {
            self.headIndex = 0
            self.pingPongDirection = 1
        }
        self.globalToggleState = false
        self.nextFixedStepMs = nowMs + settings.rate.fixedIntervalMs

        if settings.flashMode == .chase || settings.flashMode == .single || settings.flashMode == .pairs || settings.flashMode == .pingPong {
            applyPatternFrame()
        }
    }

    /// Advances the animation state at `nowMs` (matching 50ms WM_TIMER tick in tbulbs.mem).
    /// Returns `true` if any visual bulb state changed.
    @discardableResult
    public func tick(nowMs: UInt64) -> Bool {
        guard settings.lightsEnabled, !slots.isEmpty else { return false }

        switch settings.flashMode {
        case .none:
            return false

        case .random:
            var changed = false
            let hold = settings.rate.randomHoldRangeMs
            for idx in slots.indices {
                let s = slots[idx]
                if s.isBareWire || s.isMissing || s.isBroken || s.isBurnedOut { continue }
                if nowMs >= s.nextToggleMs {
                    slots[idx].isLit.toggle()
                    let nextDur = hold.min + UInt64(rng.nextInt(upperBound: Int(hold.span)))
                    slots[idx].nextToggleMs = nowMs + nextDur
                    changed = true
                }
            }
            return changed

        case .someFlash:
            var changed = false
            let hold = settings.rate.randomHoldRangeMs
            for idx in slots.indices {
                let s = slots[idx]
                if s.isBareWire || s.isMissing || s.isBroken || s.isBurnedOut || !s.flashable { continue }
                if nowMs >= s.nextToggleMs {
                    slots[idx].isLit.toggle()
                    let nextDur = hold.min + UInt64(rng.nextInt(upperBound: Int(hold.span)))
                    slots[idx].nextToggleMs = nowMs + nextDur
                    changed = true
                }
            }
            return changed

        case .allTogether, .alternating:
            guard nowMs >= nextFixedStepMs else { return false }
            nextFixedStepMs = nowMs + settings.rate.fixedIntervalMs
            globalToggleState.toggle()
            for idx in slots.indices {
                let s = slots[idx]
                if s.isBareWire || s.isMissing || s.isBroken || s.isBurnedOut { continue }
                slots[idx].isLit.toggle()
            }
            return true

        case .chase, .single, .pairs, .pingPong:
            guard nowMs >= nextFixedStepMs else { return false }
            nextFixedStepMs = nowMs + settings.rate.fixedIntervalMs
            advanceHead()
            applyPatternFrame()
            return true
        }
    }

    private func advanceHead() {
        let count = slots.count
        guard count > 0 else { return }
        let step = settings.notSoMany ? 2 : 1
        let maxValid = ((count - 1) / step) * step

        if settings.flashMode == .pingPong {
            if maxValid <= 0 {
                headIndex = 0
                return
            }
            var next = headIndex + pingPongDirection * step
            if next > maxValid {
                pingPongDirection = -1
                next = max(0, maxValid - step)
            } else if next < 0 {
                pingPongDirection = 1
                next = min(maxValid, step)
            }
            headIndex = next
        } else {
            let delta = settings.reverse ? -step : step
            var next = headIndex + delta
            if next > maxValid {
                next = 0
            } else if next < 0 {
                next = maxValid
            }
            headIndex = next
        }
    }

    private func applyPatternFrame() {
        let count = slots.count
        guard count > 0 else { return }

        for idx in slots.indices {
            slots[idx].isLit = false
        }

        let step = settings.notSoMany ? 2 : 1

        switch settings.flashMode {
        case .single, .pingPong:
            setLitIfFunctional(headIndex)

        case .chase, .pairs:
            let stride = Self.chaseStride(bulbCount: count, notSoMany: settings.notSoMany)
            var idx = headIndex
            var wrapped = false
            var safety = 0
            while !(wrapped && idx >= headIndex) && safety <= count {
                safety += 1
                setLitIfFunctional(idx)
                if settings.flashMode == .pairs {
                    let partner = idx + step
                    if partner < count {
                        setLitIfFunctional(partner)
                    }
                }
                idx += stride
                if idx >= count {
                    idx -= count
                    wrapped = true
                    if idx >= headIndex { break }
                }
            }

        default:
            break
        }
    }

    private func setLitIfFunctional(_ idx: Int) {
        guard idx >= 0, idx < slots.count else { return }
        let s = slots[idx]
        guard !s.isBareWire, !s.isMissing, !s.isBroken, !s.isBurnedOut else { return }
        slots[idx].isLit = true
    }

    /// Tray icon sync state (`bulb[0].isLit`, matching 0x00484f51)
    var traySyncLitState: Bool {
        guard settings.lightsEnabled, settings.flashIcon else { return true }
        return slots.first?.isLit ?? true
    }
}
