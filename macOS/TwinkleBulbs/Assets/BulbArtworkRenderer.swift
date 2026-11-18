import Foundation
import CoreGraphics
import AppKit

// MARK: - Bulb Palette & Clean-Room Sprite Synthesizer

public final class BulbArtworkRegistry: ObservableObject {
    public static let shared = BulbArtworkRegistry()

    public enum BuiltInStyle: String, CaseIterable {
        case outdoor = "Outdoor"
        case normal = "Normal"
        case large = "Large"
        case bare = "Bare Bulbs"
        case peppers = "Peppers"
        case candyCanes = "Candy Canes"
        case candles = "Candles"
        case stars = "Stars"
        case holly = "Holly"
        case icicles = "Icicles"
        case minibulbs = "Minibulbs"
        case trees = "Trees"
        case presents = "Presents"
        case stockings = "Stockings"
        case flowers = "Flowers"

        var isMonochrome: Bool {
            self == .trees
        }

        var isOnOnlyHighlightDim: Bool {
            self == .outdoor || self == .bare
        }

        var wireColor: (UInt8, UInt8, UInt8) {
            self == .outdoor ? (0, 102, 0) : (0, 128, 0)
        }
    }

    /// Exact 7-slot RGB palette matching Twinkle Bulbs v6.0 .blb icons
    /// (Purple, Blue, Red, Green, Yellow, Light Blue/Cyan, White)
    static let slotColors: [(onCore: (UInt8, UInt8, UInt8), onGlow: (UInt8, UInt8, UInt8), onSpec: (UInt8, UInt8, UInt8), offCore: (UInt8, UInt8, UInt8))] = [
        // 0: Purple
        ((204, 51, 204), (255, 153, 255), (255, 224, 255), (96, 28, 96)),
        // 1: Blue
        ((40, 110, 240), (102, 168, 255), (210, 232, 255), (24, 46, 110)),
        // 2: Red
        ((225, 32, 32), (255, 72, 72), (255, 200, 196), (108, 24, 24)),
        // 3: Green
        ((44, 205, 36), (153, 255, 48), (226, 255, 190), (24, 96, 24)),
        // 4: Yellow
        ((238, 198, 24), (255, 255, 130), (255, 255, 224), (112, 92, 18)),
        // 5: Light Blue / Cyan
        ((32, 210, 224), (96, 255, 255), (220, 255, 255), (22, 95, 108)),
        // 6: White
        ((226, 226, 232), (255, 255, 255), (255, 255, 255), (120, 120, 128))
    ]

    @Published public private(set) var availableSets: [BulbSetMetadata] = []
    private var loadedByID: [String: LoadedBulbIcons] = [:]
    private var rotatedCache: [String: CGImage] = [:]
    private var modernTintCache: [String: CGImage] = [:]
    private var thumbnailCache: [String: CGImage] = [:]
    private var lastHighlightKey: String = ""
    private var lastSize: Int = 32

    public static var importedBulbsDirectory: URL {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSup.appendingPathComponent("TwinkleBulbs/ImportedBulbs", isDirectory: true)
    }

    init() {
        try? FileManager.default.createDirectory(at: Self.importedBulbsDirectory, withIntermediateDirectories: true)
        reloadAllSets(size: 32, highlightHex: "#000080")
    }

    public func reloadAllSets(size: Int = 32, highlightHex: String = "#000080") {
        let keyChanged = (lastHighlightKey != highlightHex || lastSize != size)
        if keyChanged {
            rotatedCache.removeAll()
            modernTintCache.removeAll()
            thumbnailCache.removeAll()
            lastHighlightKey = highlightHex
            lastSize = size
        }

        let hl = Self.rgbTuple(hex: highlightHex)
        var newMeta: [BulbSetMetadata] = []
        var newLoaded: [String: LoadedBulbIcons] = [:]

        // 1. Built-in 15 Classic v6.0 clean-room sets
        for style in BuiltInStyle.allCases {
            let set = synthesizeBuiltInSet(style: style, size: size, highlightRGB: hl)
            newMeta.append(set.metadata)
            newLoaded[set.metadata.id] = set
        }

        // 2. Register all 250 Complete Holiday Edition sets (synthesized lazily per selected size for fast startup)
        for def in Holiday250Catalog.allDefinitions {
            newMeta.append(BulbSetMetadata(
                id: def.id,
                title: def.title,
                author: "Twinkle Bulbs Complete Holiday Edition",
                version: "7.0",
                comment: "Collection \(def.collection.displayName) — Design #\(def.number) of 250",
                isMonochrome: !def.tintable,
                isBitmap: false,
                isOnOnly: false,
                supportsColorModes: def.tintable,
                collection: def.collection,
                designNumber: def.number,
                isHoliday250: true,
                sourceURL: nil
            ))
        }

        // 3. User-imported .blb / .icl / .ico / .blz sets from Application Support (if present)
        if let files = try? FileManager.default.contentsOfDirectory(at: Self.importedBulbsDirectory, includingPropertiesForKeys: nil) {
            let validExts = Set(["blb", "icl", "ico", "blz"])
            for file in files.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                guard validExts.contains(file.pathExtension.lowercased()) else { continue }
                if let custom = BLBResourceLoader.load(url: file, preferredSize: size, highlightRGB: hl) {
                    let key = "imported:\(file.lastPathComponent)"
                    var meta = custom.metadata
                    meta.id = key
                    var stored = custom
                    stored.metadata = meta
                    newMeta.append(meta)
                    newLoaded[key] = stored
                }
            }
        }

        DispatchQueue.main.async {
            self.availableSets = newMeta
            for (k, v) in newLoaded { self.loadedByID[k] = v }
        }
        // Also update synchronously for headless / init calls
        self.availableSets = newMeta
        self.loadedByID = newLoaded
    }

    public func ensurePackLoaded(_ id: String) -> LoadedBulbIcons? {
        let resolved = resolveSetID(id)
        if let existing = loadedByID[resolved] { return existing }
        if let def = Holiday250Catalog.definition(for: resolved) {
            let pack = Holiday250Catalog.renderSetPack(definition: def, size: lastSize)
            loadedByID[def.id] = pack
            return pack
        }
        return loadedByID[BuiltInStyle.outdoor.rawValue]
    }

    public func metadata(for id: String) -> BulbSetMetadata? {
        let resolved = resolveSetID(id)
        if let m = availableSets.first(where: { $0.id == resolved }) { return m }
        return loadedByID[resolved]?.metadata
    }

    public func sampleImage(for id: String) -> CGImage? {
        let resolvedID = resolveSetID(id)
        if let hit = thumbnailCache[resolvedID] { return hit }
        if let loaded = loadedByID[resolvedID], let img = loaded.sample ?? loaded.onImages[2] {
            thumbnailCache[resolvedID] = img
            return img
        }
        if let def = Holiday250Catalog.definition(for: resolvedID) {
            let colorTuple = Self.slotColors[2]
            let primary = NSColor(srgbRed: CGFloat(colorTuple.onCore.0)/255, green: CGFloat(colorTuple.onCore.1)/255, blue: CGFloat(colorTuple.onCore.2)/255, alpha: 1)
            let glow = NSColor(srgbRed: CGFloat(colorTuple.onGlow.0)/255, green: CGFloat(colorTuple.onGlow.1)/255, blue: CGFloat(colorTuple.onGlow.2)/255, alpha: 1)
            let thumb = Holiday250Catalog.makeTile(size: 32) { ctx, s in
                Holiday250Catalog.drawTopWireAndHook(ctx: ctx, s: s, drawHook: true)
                Holiday250Catalog.drawDesign(ctx: ctx, number: def.number, s: s, primary: primary, glow: glow, lit: true, broken: false)
            }
            thumbnailCache[resolvedID] = thumb
            return thumb
        }
        return ensurePackLoaded(resolvedID)?.sample
    }

    public func resolveSetID(_ name: String) -> String {
        if loadedByID[name] != nil { return name }
        let stem = (name as NSString).deletingPathExtension
        if let match = availableSets.first(where: {
            $0.id.caseInsensitiveCompare(name) == .orderedSame ||
            $0.id.caseInsensitiveCompare(stem) == .orderedSame ||
            $0.title.caseInsensitiveCompare(name) == .orderedSame ||
            $0.title.caseInsensitiveCompare(stem) == .orderedSame
        }) {
            return match.id
        }
        return BuiltInStyle.outdoor.rawValue
    }

    public func image(for slot: BulbSlot, settings: AppSettings) -> CGImage? {
        let size = settings.bulbSize.pixels
        let hlKey = settings.sysColorHighlight ? "#000080" : settings.highlightColorHex
        if size != lastSize || hlKey != lastHighlightKey {
            reloadAllSets(size: size, highlightHex: hlKey)
        }

        let setID: String
        if settings.mixBulbs && !settings.mixedSetNames.isEmpty {
            let pool = settings.mixedSetNames
            setID = resolveSetID(pool[slot.index % pool.count])
        } else {
            setID = resolveSetID(settings.bulbSetName)
        }

        guard let pack = ensurePackLoaded(setID) else { return nil }
        let angle = slot.edge.inwardRotationDegrees(inward: settings.inward)

        switch slot.visualState {
        case .empty:
            return nil

        case .bareWire:
            guard let wire = pack.bareWire else { return nil }
            return cachedRotated(image: wire, cacheKey: "\(setID)|wire|\(size)|\(angle)", degrees: angle, size: size)

        case .broken(let c):
            let base = pack.brokenImages[c] ?? pack.brokenImages[0] ?? pack.offImages[c] ?? pack.onImages[c]
            guard let base else { return nil }
            return cachedRotated(image: base, cacheKey: "\(setID)|brk|\(c)|\(size)|\(angle)", degrees: angle, size: size)

        case .bulb(let c, let lit):
            let raw: CGImage?
            if lit {
                raw = pack.onImages[c] ?? pack.onImages[0]
            } else {
                raw = pack.offImages[c] ?? pack.offImages[0] ?? pack.onImages[c]
            }
            guard let raw else { return nil }
            return cachedRotated(image: raw, cacheKey: "\(setID)|\(lit ? "on" : "off")|\(c)|\(size)|\(angle)", degrees: angle, size: size)
        }
    }

    // MARK: - Exact Pixel Rotation (RotateIcon @ 0x0043e100)

    private func cachedRotated(image: CGImage, cacheKey: String, degrees: Int, size: Int) -> CGImage {
        if let hit = rotatedCache[cacheKey] {
            return hit
        }
        let prepared: CGImage
        if image.width != size || image.height != size {
            prepared = Self.scaleImage(image, to: CGSize(width: size, height: size))
        } else {
            prepared = image
        }
        let rotated = Self.rotatePixelExact(prepared, degrees: degrees)
        rotatedCache[cacheKey] = rotated
        return rotated
    }

    static func scaleImage(_ src: CGImage, to size: CGSize) -> CGImage {
        let w = Int(size.width), h = Int(size.height)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return src }
        ctx.interpolationQuality = .high
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? src
    }

    /// Exact pixel transform matching RotateIcon() @ 0x0043e100 in tbulbs.mem:
    /// +90° -> dst(W-1-y, x), -90° -> dst(y, H-1-x), 180° -> dst(W-1-x, H-1-y)
    public static func rotatePixelExact(_ src: CGImage, degrees: Int) -> CGImage {
        guard degrees != 0 else { return src }
        let w = src.width, h = src.height
        var inPx = [UInt32](repeating: 0, count: w * h)
        var outPx = [UInt32](repeating: 0, count: w * h)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let inCtx = CGContext(
            data: &inPx, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return src }
        inCtx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))

        for y in 0..<h {
            for x in 0..<w {
                let dstX: Int
                let dstY: Int
                switch degrees {
                case 90:
                    dstX = w - 1 - y
                    dstY = x
                case -90:
                    dstX = y
                    dstY = h - 1 - x
                case 180:
                    dstX = w - 1 - x
                    dstY = h - 1 - y
                default:
                    dstX = x
                    dstY = y
                }
                outPx[dstY * w + dstX] = inPx[y * w + x]
            }
        }

        guard let outCtx = CGContext(
            data: &outPx, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return src }
        return outCtx.makeImage() ?? src
    }

    // MARK: - Clean-Room Bulb Sprite Generator (32x32 base, scaled crisp if 48x48)

    private func synthesizeBuiltInSet(style: BuiltInStyle, size: Int, highlightRGB: (UInt8, UInt8, UInt8)) -> LoadedBulbIcons {
        let meta = BulbSetMetadata(
            id: style.rawValue,
            title: style.rawValue,
            author: "Twinkle Bulbs Mac Reconstruction",
            version: "6.0",
            comment: "Clean-room native rendition modeled on Twinkle Bulbs v6.0 specifications.",
            isMonochrome: style.isMonochrome,
            isBitmap: false,
            isOnOnly: style.isOnOnlyHighlightDim,
            sourceURL: nil
        )

        let bareWire = synthesizeWireTile(style: style, size: size)
        var onMap: [Int: CGImage] = [:]
        var offMap: [Int: CGImage] = [:]
        var brkMap: [Int: CGImage] = [:]

        for c in 0..<7 {
            let colorIdx = style.isMonochrome ? 3 : c
            let onImg = synthesizeBulbTile(style: style, colorIndex: colorIdx, state: .on, size: size)
            let offImg: CGImage
            if style.isOnOnlyHighlightDim {
                offImg = Self.dimGlassKeepingWireAndSocket(image: onImg, style: style, highlightRGB: highlightRGB, size: size)
            } else {
                offImg = synthesizeBulbTile(style: style, colorIndex: colorIdx, state: .off, size: size)
            }
            let brkImg = synthesizeBulbTile(style: style, colorIndex: colorIdx, state: .broken, size: size)
            onMap[c] = onImg
            offMap[c] = offImg
            brkMap[c] = brkImg
        }

        return LoadedBulbIcons(
            metadata: meta,
            sample: onMap[2] ?? onMap[0],
            bareWire: bareWire,
            onImages: onMap,
            offImages: offMap,
            brokenImages: brkMap
        )
    }

    private enum RenderState { case on, off, broken }

    private func synthesizeWireTile(style: BuiltInStyle, size: Int) -> CGImage? {
        if style == .bare || style == .icicles {
            return makeCanvas(size: size) { _ in }
        }
        return makeCanvas(size: size) { ctx in
            drawWireSegment(ctx: ctx, style: style, size: CGFloat(size))
        }
    }

    private func drawWireSegment(ctx: CGContext, style: BuiltInStyle, size: CGFloat) {
        let s = size / 32.0
        let (wr, wg, wb) = style.wireColor
        let wireNS = NSColor(srgbRed: CGFloat(wr)/255, green: CGFloat(wg)/255, blue: CGFloat(wb)/255, alpha: 1.0)
        ctx.setFillColor(wireNS.cgColor)
        ctx.setStrokeColor(wireNS.cgColor)

        switch style {
        case .outdoor:
            // Straight horizontal 2px green wire at y=1..2
            ctx.fill(CGRect(x: 0, y: 1 * s, width: size, height: 2 * s))
        case .peppers:
            // Slight dip wire y=1..2
            ctx.fill(CGRect(x: 0, y: 1 * s, width: size, height: 2 * s))
        case .candles:
            // Bottom mounting wire y=28..30
            ctx.setLineWidth(max(1.5, 2.0 * s))
            ctx.move(to: CGPoint(x: 0, y: 30 * s))
            ctx.addQuadCurve(to: CGPoint(x: size, y: 30 * s), control: CGPoint(x: size * 0.5, y: 26.5 * s))
            ctx.strokePath()
        case .bare:
            break
        default:
            // Classic catenary cord dipping from (0,1) -> (16,4.5) -> (32,1)
            ctx.setLineWidth(max(1.6, 2.0 * s))
            ctx.move(to: CGPoint(x: 0, y: 0.8 * s))
            ctx.addQuadCurve(to: CGPoint(x: size, y: 0.8 * s), control: CGPoint(x: size * 0.5, y: 5.0 * s))
            ctx.strokePath()
        }
    }

    private static func dimGlassKeepingWireAndSocket(image: CGImage, style: BuiltInStyle, highlightRGB: (UInt8, UInt8, UInt8), size: Int) -> CGImage {
        let dimmed = BLBResourceLoader.blendHalfWithHighlight(image: image, rgb: highlightRGB)
        let k = CGFloat(size) / 32.0
        let keepTopY = (style == .outdoor ? 10.5 : 9.0) * k
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return dimmed
        }
        // Draw highlighted dimmed glass for lower portion, keep crisp wire+socket at top
        ctx.draw(dimmed, in: CGRect(x: 0, y: 0, width: size, height: size))
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: CGFloat(size) - keepTopY, width: CGFloat(size), height: keepTopY))
        ctx.clear(CGRect(x: 0, y: CGFloat(size) - keepTopY, width: CGFloat(size), height: keepTopY))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        ctx.restoreGState()
        return ctx.makeImage() ?? dimmed
    }

    private func synthesizeBulbTile(style: BuiltInStyle, colorIndex: Int, state: RenderState, size: Int) -> CGImage {
        let pal = Self.slotColors[colorIndex % Self.slotColors.count]
        return makeCanvas(size: size) { ctx in
            let S = CGFloat(size)
            let k = S / 32.0

            // Draw wire first so socket sits cleanly on top
            drawWireSegment(ctx: ctx, style: style, size: S)

            // Resolve fill & glow colors
            let baseTuple = (state == .on) ? pal.onCore : pal.offCore
            let baseColor = NSColor(srgbRed: CGFloat(baseTuple.0)/255, green: CGFloat(baseTuple.1)/255, blue: CGFloat(baseTuple.2)/255, alpha: 1.0)
            let glowColor = NSColor(srgbRed: CGFloat(pal.onGlow.0)/255, green: CGFloat(pal.onGlow.1)/255, blue: CGFloat(pal.onGlow.2)/255, alpha: 1.0)
            let specColor = NSColor(srgbRed: CGFloat(pal.onSpec.0)/255, green: CGFloat(pal.onSpec.1)/255, blue: CGFloat(pal.onSpec.2)/255, alpha: 0.92)
            let outline = NSColor(white: 0.08, alpha: 1.0)

            let (wr, wg, wb) = style.wireColor
            let socketFill = NSColor(srgbRed: CGFloat(wr)/255, green: CGFloat(wg)/255, blue: CGFloat(wb)/255, alpha: 1.0)
            let socketDark = NSColor(srgbRed: CGFloat(wr)/380, green: CGFloat(wg)/380, blue: CGFloat(wb)/380, alpha: 1.0)

            // Soft radial glow halo when lit
            if state == .on {
                ctx.saveGState()
                let glowAlpha: CGFloat = (style == .large || style == .stars) ? 0.38 : 0.30
                let glowCols = [glowColor.withAlphaComponent(glowAlpha).cgColor, glowColor.withAlphaComponent(0).cgColor] as CFArray
                if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowCols, locations: [0.0, 1.0]) {
                    let center = CGPoint(x: 16 * k, y: (style == .candles ? 11 : 19) * k)
                    let radius = (style == .candles ? 10 : 15) * k
                    ctx.drawRadialGradient(grad, startCenter: center, startRadius: 1 * k, endCenter: center, endRadius: radius, options: [])
                }
                ctx.restoreGState()
            }

            switch style {
            case .outdoor:
                drawOutdoorBulb(ctx: ctx, k: k, state: state, socketFill: socketFill, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline)
            case .normal:
                drawTeardropBulb(ctx: ctx, k: k, wide: false, state: state, socketFill: socketFill, socketDark: socketDark, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline)
            case .large:
                drawTeardropBulb(ctx: ctx, k: k, wide: true, state: state, socketFill: socketFill, socketDark: socketDark, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline)
            case .bare:
                drawBareBulb(ctx: ctx, k: k, state: state, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline)
            case .peppers:
                drawPepperBulb(ctx: ctx, k: k, state: state, socketFill: socketFill, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline)
            case .candyCanes:
                drawCandyCane(ctx: ctx, k: k, state: state, baseColor: baseColor, glowColor: glowColor, outline: outline)
            case .candles:
                drawCandle(ctx: ctx, k: k, state: state, baseColor: baseColor, glowColor: glowColor, socketFill: socketFill, outline: outline)
            case .stars:
                drawStar(ctx: ctx, k: k, state: state, socketFill: socketFill, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline)
            case .icicles:
                drawIcicle(ctx: ctx, k: k, state: state, baseColor: baseColor, glowColor: glowColor, outline: outline)
            case .minibulbs:
                drawMiniBulb(ctx: ctx, k: k, state: state, socketFill: socketFill, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline)
            case .holly:
                drawHolly(ctx: ctx, k: k, state: state, socketFill: socketFill, baseColor: baseColor, glowColor: glowColor, outline: outline)
            case .flowers:
                drawFlower(ctx: ctx, k: k, state: state, socketFill: socketFill, baseColor: baseColor, glowColor: glowColor, outline: outline)
            case .trees:
                drawChristmasTree(ctx: ctx, k: k, state: state, baseColor: baseColor, glowColor: glowColor, outline: outline)
            case .presents:
                drawPresent(ctx: ctx, k: k, state: state, socketFill: socketFill, baseColor: baseColor, glowColor: glowColor, outline: outline)
            case .stockings:
                drawStocking(ctx: ctx, k: k, state: state, socketFill: socketFill, baseColor: baseColor, glowColor: glowColor, outline: outline)
            }
        }
    }

    // MARK: - Individual Shape Drawers Matching v6.0 Silhouettes

    private func drawOutdoorBulb(
        ctx: CGContext, k: CGFloat, state: RenderState,
        socketFill: NSColor, baseColor: NSColor, glowColor: NSColor, specColor: NSColor, outline: NSColor
    ) {
        // Tall green outdoor socket y=0..10, flared collar
        ctx.setFillColor(socketFill.cgColor)
        ctx.fill(CGRect(x: 11 * k, y: 0, width: 10 * k, height: 8 * k))
        ctx.fill(CGRect(x: 9.5 * k, y: 8 * k, width: 13 * k, height: 3 * k))
        ctx.setFillColor(outline.cgColor)
        ctx.fill(CGRect(x: 9.5 * k, y: 10.2 * k, width: 13 * k, height: 1 * k))

        // Cone/Teardrop glass y=11..31, width x=8..24
        let bulbPath = CGMutablePath()
        if state == .broken {
            bulbPath.move(to: CGPoint(x: 10 * k, y: 11 * k))
            bulbPath.addLine(to: CGPoint(x: 22 * k, y: 11 * k))
            bulbPath.addLine(to: CGPoint(x: 23 * k, y: 17 * k))
            bulbPath.addLine(to: CGPoint(x: 19 * k, y: 15 * k))
            bulbPath.addLine(to: CGPoint(x: 16 * k, y: 19 * k))
            bulbPath.addLine(to: CGPoint(x: 12.5 * k, y: 15.5 * k))
            bulbPath.addLine(to: CGPoint(x: 9 * k, y: 17 * k))
            bulbPath.closeSubpath()
        } else {
            bulbPath.move(to: CGPoint(x: 10 * k, y: 11 * k))
            bulbPath.addLine(to: CGPoint(x: 22 * k, y: 11 * k))
            bulbPath.addCurve(to: CGPoint(x: 16 * k, y: 31 * k),
                              control1: CGPoint(x: 25.5 * k, y: 18 * k),
                              control2: CGPoint(x: 20.5 * k, y: 27 * k))
            bulbPath.addCurve(to: CGPoint(x: 10 * k, y: 11 * k),
                              control1: CGPoint(x: 11.5 * k, y: 27 * k),
                              control2: CGPoint(x: 6.5 * k, y: 18 * k))
            bulbPath.closeSubpath()
        }
        fillAndShineBulbPath(ctx: ctx, path: bulbPath, k: k, state: state, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline, shineRect: CGRect(x: 12 * k, y: 13.5 * k, width: 3.2 * k, height: 7 * k))
    }

    private func drawTeardropBulb(
        ctx: CGContext, k: CGFloat, wide: Bool, state: RenderState,
        socketFill: NSColor, socketDark: NSColor,
        baseColor: NSColor, glowColor: NSColor, specColor: NSColor, outline: NSColor
    ) {
        // Catenary saddle socket y=3..9.5
        ctx.setFillColor(socketFill.cgColor)
        ctx.fill(CGRect(x: 12.2 * k, y: 3.5 * k, width: 7.6 * k, height: 6.2 * k))
        ctx.setFillColor(socketDark.cgColor)
        ctx.fill(CGRect(x: 18.2 * k, y: 3.5 * k, width: 1.6 * k, height: 6.2 * k))

        let maxX: CGFloat = wide ? 24.5 : 23.0
        let minX: CGFloat = wide ? 7.5 : 9.0
        let bulbPath = CGMutablePath()
        if state == .broken {
            bulbPath.move(to: CGPoint(x: 12.5 * k, y: 9.5 * k))
            bulbPath.addLine(to: CGPoint(x: 19.5 * k, y: 9.5 * k))
            bulbPath.addLine(to: CGPoint(x: 21.5 * k, y: 16 * k))
            bulbPath.addLine(to: CGPoint(x: 17.5 * k, y: 13 * k))
            bulbPath.addLine(to: CGPoint(x: 15 * k, y: 17.5 * k))
            bulbPath.addLine(to: CGPoint(x: 12 * k, y: 13.5 * k))
            bulbPath.addLine(to: CGPoint(x: 10.5 * k, y: 15.5 * k))
            bulbPath.closeSubpath()
        } else {
            bulbPath.move(to: CGPoint(x: 13 * k, y: 9.5 * k))
            bulbPath.addLine(to: CGPoint(x: 19 * k, y: 9.5 * k))
            bulbPath.addCurve(to: CGPoint(x: 16 * k, y: 31 * k),
                              control1: CGPoint(x: maxX * k, y: 15 * k),
                              control2: CGPoint(x: (wide ? 22 : 20.5) * k, y: 26 * k))
            bulbPath.addCurve(to: CGPoint(x: 13 * k, y: 9.5 * k),
                              control1: CGPoint(x: (wide ? 10 : 11.5) * k, y: 26 * k),
                              control2: CGPoint(x: minX * k, y: 15 * k))
            bulbPath.closeSubpath()
        }

        fillAndShineBulbPath(ctx: ctx, path: bulbPath, k: k, state: state, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline, shineRect: CGRect(x: 12.2 * k, y: 13 * k, width: 3.0 * k, height: 6.5 * k))

        if wide && state == .on {
            // Facet sparkle highlights matching Large bulb
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.fill(CGRect(x: 15.2 * k, y: 11.5 * k, width: 1.6 * k, height: 3.2 * k))
            ctx.fill(CGRect(x: 12.5 * k, y: 16 * k, width: 1.8 * k, height: 2.2 * k))
            ctx.fill(CGRect(x: 17.8 * k, y: 16 * k, width: 1.8 * k, height: 2.2 * k))
        }
    }

    private func drawBareBulb(
        ctx: CGContext, k: CGFloat, state: RenderState,
        baseColor: NSColor, glowColor: NSColor, specColor: NSColor, outline: NSColor
    ) {
        // Metallic screw cap
        let silver = NSColor(white: 0.72, alpha: 1.0)
        let darkSilver = NSColor(white: 0.42, alpha: 1.0)
        ctx.setFillColor(darkSilver.cgColor)
        ctx.fill(CGRect(x: 13.5 * k, y: 0.5 * k, width: 5 * k, height: 2.5 * k))
        ctx.setFillColor(silver.cgColor)
        ctx.fill(CGRect(x: 11 * k, y: 3 * k, width: 10 * k, height: 6.5 * k))
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(max(1.0, k))
        ctx.stroke(CGRect(x: 11 * k, y: 3 * k, width: 10 * k, height: 6.5 * k))

        // Oval rounded C7 glass y=9.5..31
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: 8.5 * k, y: 9.5 * k, width: 15 * k, height: 21.5 * k))
        fillAndShineBulbPath(ctx: ctx, path: path, k: k, state: state, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline, shineRect: CGRect(x: 11 * k, y: 12.5 * k, width: 3.2 * k, height: 6.5 * k))
    }

    private func drawPepperBulb(
        ctx: CGContext, k: CGFloat, state: RenderState,
        socketFill: NSColor, baseColor: NSColor, glowColor: NSColor, specColor: NSColor, outline: NSColor
    ) {
        ctx.setFillColor(socketFill.cgColor)
        ctx.fill(CGRect(x: 12.5 * k, y: 2.5 * k, width: 7 * k, height: 4.5 * k))
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 13 * k, y: 6.5 * k))
        path.addLine(to: CGPoint(x: 19 * k, y: 6.5 * k))
        path.addCurve(to: CGPoint(x: 8.5 * k, y: 30.5 * k),
                      control1: CGPoint(x: 20.5 * k, y: 17 * k),
                      control2: CGPoint(x: 15.5 * k, y: 28 * k))
        path.addCurve(to: CGPoint(x: 13 * k, y: 6.5 * k),
                      control1: CGPoint(x: 6.0 * k, y: 27 * k),
                      control2: CGPoint(x: 13.5 * k, y: 15 * k))
        path.closeSubpath()
        fillAndShineBulbPath(ctx: ctx, path: path, k: k, state: state, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline, shineRect: CGRect(x: 13.5 * k, y: 9.5 * k, width: 2.4 * k, height: 6 * k))
    }

    private func drawCandyCane(
        ctx: CGContext, k: CGFloat, state: RenderState,
        baseColor: NSColor, glowColor: NSColor, outline: NSColor
    ) {
        let cane = CGMutablePath()
        cane.move(to: CGPoint(x: 9.5 * k, y: 12 * k))
        cane.addArc(center: CGPoint(x: 15.0 * k, y: 11.5 * k), radius: 5.5 * k, startAngle: .pi, endAngle: 0, clockwise: false)
        cane.addLine(to: CGPoint(x: 20.5 * k, y: 29.5 * k))
        let stroked = cane.copy(strokingWithWidth: 4.6 * k, lineCap: .round, lineJoin: .round, miterLimit: 4)
        ctx.saveGState()
        ctx.addPath(stroked)
        ctx.clip()
        ctx.setFillColor(state == .on ? NSColor.white.cgColor : NSColor(white: 0.65, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 32 * k, height: 32 * k))
        ctx.setFillColor((state == .on ? glowColor : baseColor).cgColor)
        for stripeY in stride(from: -10.0, to: 38.0, by: 6.0) {
            ctx.saveGState()
            ctx.translateBy(x: 16 * k, y: CGFloat(stripeY) * k)
            ctx.rotate(by: -.pi / 4)
            ctx.fill(CGRect(x: -20 * k, y: 0, width: 40 * k, height: 2.6 * k))
            ctx.restoreGState()
        }
        ctx.restoreGState()
        ctx.addPath(stroked)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(max(0.8, 0.9 * k))
        ctx.strokePath()
    }

    private func drawCandle(
        ctx: CGContext, k: CGFloat, state: RenderState,
        baseColor: NSColor, glowColor: NSColor, socketFill: NSColor, outline: NSColor
    ) {
        // Candle wax stick
        let waxRect = CGRect(x: 13 * k, y: 8 * k, width: 6 * k, height: 19 * k)
        ctx.setFillColor((state == .on ? glowColor : baseColor).withAlphaComponent(0.95).cgColor)
        ctx.fill(waxRect)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(k)
        ctx.stroke(waxRect)

        // Green base cup
        ctx.setFillColor(socketFill.cgColor)
        ctx.fill(CGRect(x: 11.5 * k, y: 26 * k, width: 9 * k, height: 4.5 * k))

        // Flame
        if state != .broken {
            let flame = CGMutablePath()
            flame.move(to: CGPoint(x: 16 * k, y: 0.5 * k))
            flame.addCurve(to: CGPoint(x: 16 * k, y: 8 * k), control1: CGPoint(x: 19.8 * k, y: 4 * k), control2: CGPoint(x: 19 * k, y: 7.8 * k))
            flame.addCurve(to: CGPoint(x: 16 * k, y: 0.5 * k), control1: CGPoint(x: 13 * k, y: 7.8 * k), control2: CGPoint(x: 12.2 * k, y: 4 * k))
            ctx.addPath(flame)
            ctx.setFillColor(state == .on ? NSColor(srgbRed: 1, green: 0.92, blue: 0.35, alpha: 1).cgColor : NSColor(white: 0.35, alpha: 1).cgColor)
            ctx.fillPath()
        }
    }

    private func drawStar(
        ctx: CGContext, k: CGFloat, state: RenderState,
        socketFill: NSColor, baseColor: NSColor, glowColor: NSColor, specColor: NSColor, outline: NSColor
    ) {
        ctx.setFillColor(socketFill.cgColor)
        ctx.fill(CGRect(x: 14 * k, y: 2 * k, width: 4 * k, height: 4 * k))
        let star = CGMutablePath()
        let center = CGPoint(x: 16 * k, y: 18.5 * k)
        let outerR = 13.0 * k
        let innerR = 5.4 * k
        for i in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let r = (i % 2 == 0) ? outerR : innerR
            let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        fillAndShineBulbPath(ctx: ctx, path: star, k: k, state: state, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline, shineRect: CGRect(x: 13.5 * k, y: 13.5 * k, width: 3 * k, height: 4 * k))
    }

    private func drawIcicle(
        ctx: CGContext, k: CGFloat, state: RenderState,
        baseColor: NSColor, glowColor: NSColor, outline: NSColor
    ) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 10 * k, y: 0))
        p.addLine(to: CGPoint(x: 22 * k, y: 0))
        p.addLine(to: CGPoint(x: 19 * k, y: 14 * k))
        p.addLine(to: CGPoint(x: 16 * k, y: 31 * k))
        p.addLine(to: CGPoint(x: 13 * k, y: 14 * k))
        p.closeSubpath()
        fillAndShineBulbPath(ctx: ctx, path: p, k: k, state: state, baseColor: baseColor, glowColor: glowColor, specColor: .white, outline: outline, shineRect: CGRect(x: 13 * k, y: 4 * k, width: 2.2 * k, height: 10 * k))
    }

    private func drawMiniBulb(
        ctx: CGContext, k: CGFloat, state: RenderState,
        socketFill: NSColor, baseColor: NSColor, glowColor: NSColor, specColor: NSColor, outline: NSColor
    ) {
        ctx.setFillColor(socketFill.cgColor)
        ctx.fill(CGRect(x: 13.5 * k, y: 3 * k, width: 5 * k, height: 5 * k))
        let p = CGMutablePath()
        p.addEllipse(in: CGRect(x: 11.5 * k, y: 8 * k, width: 9 * k, height: 15 * k))
        fillAndShineBulbPath(ctx: ctx, path: p, k: k, state: state, baseColor: baseColor, glowColor: glowColor, specColor: specColor, outline: outline, shineRect: CGRect(x: 13 * k, y: 10 * k, width: 2 * k, height: 4 * k))
    }

    private func drawHolly(
        ctx: CGContext, k: CGFloat, state: RenderState,
        socketFill: NSColor, baseColor: NSColor, glowColor: NSColor, outline: NSColor
    ) {
        // Two scalloped green leaves
        ctx.setFillColor(socketFill.cgColor)
        ctx.fillEllipse(in: CGRect(x: 5 * k, y: 6 * k, width: 12 * k, height: 10 * k))
        ctx.fillEllipse(in: CGRect(x: 15 * k, y: 6 * k, width: 12 * k, height: 10 * k))
        // Glowing colored cluster berries below
        let col = (state == .on ? glowColor : baseColor).cgColor
        for b in [CGPoint(x: 12 * k, y: 17 * k), CGPoint(x: 17 * k, y: 16 * k), CGPoint(x: 14.5 * k, y: 22 * k)] {
            ctx.setFillColor(col)
            ctx.fillEllipse(in: CGRect(x: b.x, y: b.y, width: 6.5 * k, height: 6.5 * k))
            ctx.setStrokeColor(outline.cgColor)
            ctx.setLineWidth(0.9 * k)
            ctx.strokeEllipse(in: CGRect(x: b.x, y: b.y, width: 6.5 * k, height: 6.5 * k))
        }
    }

    private func drawFlower(
        ctx: CGContext, k: CGFloat, state: RenderState,
        socketFill: NSColor, baseColor: NSColor, glowColor: NSColor, outline: NSColor
    ) {
        ctx.setFillColor(socketFill.cgColor)
        ctx.fill(CGRect(x: 15 * k, y: 2 * k, width: 2 * k, height: 8 * k))
        let col = (state == .on ? glowColor : baseColor).cgColor
        for i in 0..<5 {
            let ang = CGFloat(i) * 2 * .pi / 5 - .pi / 2
            let cx = 16 * k + cos(ang) * 6.5 * k - 4 * k
            let cy = 18 * k + sin(ang) * 6.5 * k - 4 * k
            ctx.setFillColor(col)
            ctx.fillEllipse(in: CGRect(x: cx, y: cy, width: 8 * k, height: 8 * k))
        }
        ctx.setFillColor(state == .on ? NSColor.yellow.cgColor : NSColor(white: 0.45, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: 13 * k, y: 15 * k, width: 6 * k, height: 6 * k))
    }

    private func drawChristmasTree(
        ctx: CGContext, k: CGFloat, state: RenderState,
        baseColor: NSColor, glowColor: NSColor, outline: NSColor
    ) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 16 * k, y: 3 * k))
        p.addLine(to: CGPoint(x: 26 * k, y: 25 * k))
        p.addLine(to: CGPoint(x: 6 * k, y: 25 * k))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor(state == .on ? NSColor(srgbRed: 0.1, green: 0.65, blue: 0.18, alpha: 1).cgColor : NSColor(srgbRed: 0.05, green: 0.30, blue: 0.08, alpha: 1).cgColor)
        ctx.fillPath()
        ctx.addPath(p)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(k)
        ctx.strokePath()
        ctx.setFillColor(NSColor.brown.cgColor)
        ctx.fill(CGRect(x: 14 * k, y: 25 * k, width: 4 * k, height: 5.5 * k))
        if state == .on {
            for (pt, col) in [(CGPoint(x: 14 * k, y: 12 * k), NSColor.red), (CGPoint(x: 18 * k, y: 18 * k), NSColor.yellow), (CGPoint(x: 11 * k, y: 21 * k), NSColor.cyan)] {
                ctx.setFillColor(col.cgColor)
                ctx.fillEllipse(in: CGRect(x: pt.x, y: pt.y, width: 3 * k, height: 3 * k))
            }
        }
    }

    private func drawPresent(
        ctx: CGContext, k: CGFloat, state: RenderState,
        socketFill: NSColor, baseColor: NSColor, glowColor: NSColor, outline: NSColor
    ) {
        ctx.setFillColor(socketFill.cgColor)
        ctx.fill(CGRect(x: 15 * k, y: 2 * k, width: 2 * k, height: 6 * k))
        let box = CGRect(x: 7 * k, y: 9 * k, width: 18 * k, height: 19 * k)
        ctx.setFillColor((state == .on ? glowColor : baseColor).cgColor)
        ctx.fill(box)
        ctx.setFillColor(state == .on ? NSColor.yellow.withAlphaComponent(0.95).cgColor : NSColor(white: 0.5, alpha: 0.8).cgColor)
        ctx.fill(CGRect(x: 14.5 * k, y: 9 * k, width: 3 * k, height: 19 * k))
        ctx.fill(CGRect(x: 7 * k, y: 16.5 * k, width: 18 * k, height: 3 * k))
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(k)
        ctx.stroke(box)
    }

    private func drawStocking(
        ctx: CGContext, k: CGFloat, state: RenderState,
        socketFill: NSColor, baseColor: NSColor, glowColor: NSColor, outline: NSColor
    ) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 10 * k, y: 6 * k))
        p.addLine(to: CGPoint(x: 20 * k, y: 6 * k))
        p.addLine(to: CGPoint(x: 20 * k, y: 20 * k))
        p.addCurve(to: CGPoint(x: 24 * k, y: 28 * k), control1: CGPoint(x: 25 * k, y: 22 * k), control2: CGPoint(x: 27 * k, y: 27 * k))
        p.addLine(to: CGPoint(x: 10 * k, y: 28 * k))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor((state == .on ? glowColor : baseColor).cgColor)
        ctx.fillPath()
        ctx.setFillColor(state == .on ? NSColor.white.cgColor : NSColor(white: 0.6, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 9 * k, y: 5 * k, width: 12 * k, height: 5 * k))
        ctx.addPath(p)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(k)
        ctx.strokePath()
    }

    // MARK: - Shared Glass Shading & Specular Helper

    private func fillAndShineBulbPath(
        ctx: CGContext, path: CGPath, k: CGFloat, state: RenderState,
        baseColor: NSColor, glowColor: NSColor, specColor: NSColor, outline: NSColor, shineRect: CGRect
    ) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        let fillCol = (state == .on) ? glowColor : baseColor
        let gradCols = [fillCol.cgColor, baseColor.blended(withFraction: 0.35, of: .black)?.cgColor ?? baseColor.cgColor] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradCols, locations: [0.25, 1.0]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 12 * k, y: 12 * k), end: CGPoint(x: 24 * k, y: 30 * k), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        if state == .on {
            ctx.setFillColor(specColor.cgColor)
            ctx.fillEllipse(in: shineRect)
        }
        ctx.restoreGState()

        ctx.addPath(path)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(max(1.0, k))
        ctx.strokePath()
    }

    private func makeCanvas(size: Int, draw: (CGContext) -> Void) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // Flip top-down so GDI pixel Y matches CGContext Y cleanly
        ctx.translateBy(x: 0, y: CGFloat(size))
        ctx.scaleBy(x: 1, y: -1)
        ctx.setAllowsAntialiasing(true)
        draw(ctx)
        return ctx.makeImage()!
    }

    static func rgbTuple(hex: String) -> (UInt8, UInt8, UInt8) {
        let c = NSColor(hex: hex, fallback: NSColor(srgbRed: 0, green: 0, blue: 0.5, alpha: 1))
        let rgb = c.usingColorSpace(.sRGB) ?? c
        return (
            UInt8(min(255, max(0, Int(round(rgb.redComponent * 255))))),
            UInt8(min(255, max(0, Int(round(rgb.greenComponent * 255))))),
            UInt8(min(255, max(0, Int(round(rgb.blueComponent * 255)))))
        )
    }

    // MARK: - Modern Lighting Sprite Tint Pipeline (Preserves Exact Bulb Artwork, Wire & Socket)

    public func modernImages(for state: ModernBulbState, settings: AppSettings) -> (base: CGImage?, lit: CGImage?) {
        let size = settings.bulbSize.pixels
        let hlKey = settings.sysColorHighlight ? "#000080" : settings.highlightColorHex
        if size != lastSize || hlKey != lastHighlightKey {
            reloadAllSets(size: size, highlightHex: hlKey)
        }

        let setID: String
        if settings.mixBulbs && !settings.mixedSetNames.isEmpty {
            let pool = settings.mixedSetNames
            setID = resolveSetID(pool[state.index % pool.count])
        } else {
            setID = resolveSetID(settings.bulbSetName)
        }
        guard let pack = ensurePackLoaded(setID) else { return (nil, nil) }
        let angle = state.edge.inwardRotationDegrees(inward: settings.inward)

        if state.isMissing {
            if state.isBareWire, let w = pack.bareWire {
                return (cachedRotated(image: w, cacheKey: "\(setID)|wire|\(size)|\(angle)", degrees: angle, size: size), nil)
            }
            return (nil, nil)
        }
        if state.isBareWire {
            guard let w = pack.bareWire else { return (nil, nil) }
            return (cachedRotated(image: w, cacheKey: "\(setID)|wire|\(size)|\(angle)", degrees: angle, size: size), nil)
        }
        if state.isBroken {
            let brk = pack.brokenImages[2] ?? pack.brokenImages[0] ?? pack.offImages[2] ?? pack.onImages[6]
            guard let brk else { return (nil, nil) }
            return (cachedRotated(image: brk, cacheKey: "\(setID)|brk|0|\(size)|\(angle)", degrees: angle, size: size), nil)
        }

        let offRaw = pack.offImages[6] ?? pack.offImages[2] ?? pack.offImages[0]
        let baseImg = offRaw.map { cachedRotated(image: $0, cacheKey: "\(setID)|modoff|\(size)|\(angle)", degrees: angle, size: size) }

        if state.isBurnedOut || state.intensity <= 0.01 {
            return (baseImg, nil)
        }

        // Quantize RGB into 13 discrete levels per channel (~2197 hues) so 60fps waves reuse cached CGImages smoothly
        let qr = max(0, min(12, Int(round(state.r * 12.0))))
        let qg = max(0, min(12, Int(round(state.g * 12.0))))
        let qb = max(0, min(12, Int(round(state.b * 12.0))))
        let cacheKey = "\(setID)|mod|\(qr)_\(qg)_\(qb)|\(size)|\(angle)"

        if let hit = modernTintCache[cacheKey] {
            return (baseImg, hit)
        }

        guard let whiteOn = pack.onImages[6] ?? pack.onImages[4] ?? pack.onImages[2] ?? pack.onImages[0] else {
            return (baseImg, nil)
        }
        let prepared = (whiteOn.width == size && whiteOn.height == size) ? whiteOn : Self.scaleImage(whiteOn, to: CGSize(width: size, height: size))
        let tinted = Self.tintSpriteGlass(prepared, r: Double(qr) / 12.0, g: Double(qg) / 12.0, b: Double(qb) / 12.0)
        let rotated = Self.rotatePixelExact(tinted, degrees: angle)

        if modernTintCache.count > 1800 {
            modernTintCache.removeAll(keepingCapacity: true)
        }
        modernTintCache[cacheKey] = rotated
        return (baseImg, rotated)
    }

    private static func tintSpriteGlass(_ src: CGImage, r tr: Double, g tg: Double, b tb: Double) -> CGImage {
        let w = src.width, h = src.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return src }
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))

        for y in 0..<h {
            for x in 0..<w {
                let off = (y * w + x) * 4
                let a = Double(px[off + 3])
                guard a > 0 else { continue }
                // Unpremultiply safely
                let invA = 255.0 / a
                let pr = min(255.0, Double(px[off]) * invA)
                let pg = min(255.0, Double(px[off + 1]) * invA)
                let pb = min(255.0, Double(px[off + 2]) * invA)

                // Preserve green top wire & dark socket cap intact
                let isTopWireGreen = (y < h / 3) && (pg > pr + 18.0) && (pg > pb + 18.0)
                let isDarkSocket = (y < (h * 42) / 100) && (max(pr, max(pg, pb)) < 75.0)
                if isTopWireGreen || isDarkSocket { continue }

                // Tint luminous glass pixels while retaining white specular shine
                let luma = max(pr, max(pg, pb)) / 255.0
                let minCh = min(pr, min(pg, pb)) / 255.0
                let whiteShine = max(0.0, min(1.0, (minCh - 0.72) / 0.28))

                let nr = min(1.0, luma * tr + whiteShine * 0.45)
                let ng = min(1.0, luma * tg + whiteShine * 0.45)
                let nb = min(1.0, luma * tb + whiteShine * 0.45)

                let alphaScale = a / 255.0
                px[off]     = UInt8(min(255, max(0, Int(round(nr * 255.0 * alphaScale)))))
                px[off + 1] = UInt8(min(255, max(0, Int(round(ng * 255.0 * alphaScale)))))
                px[off + 2] = UInt8(min(255, max(0, Int(round(nb * 255.0 * alphaScale)))))
            }
        }

        return ctx.makeImage() ?? src
    }
}
