import Foundation
import CoreGraphics

// MARK: - Part VI: Virtual Lighting Layout Coordinate & Rendering Engine

public struct VirtualBulbNode {
    public var strandID: String
    public var zoneID: String
    public var bulbSetID: String
    public var state: ModernBulbState
}

public final class VirtualLightingLayoutEngine {
    public static var layoutAssetsDirectory: URL {
        NextGenStateStore.storageDirectory.appendingPathComponent("LayoutAssets", isDirectory: true)
    }

    /// Generates normalized 2D coordinates along any of the 9 supported strand geometries.
    public static func sampleStrandPoints(item: VirtualStrandItem, inCanvasBounds bounds: CGRect) -> [CGPoint] {
        let count = max(4, min(300, item.bulbCount))
        let rx = CGFloat(item.originX) * bounds.width
        let ry = CGFloat(item.originY) * bounds.height
        let rw = max(12, CGFloat(item.width) * bounds.width)
        let rh = max(12, CGFloat(item.height) * bounds.height)
        let cx = rx + rw * 0.5
        let cy = ry + rh * 0.5

        var rawPts: [CGPoint] = []
        rawPts.reserveCapacity(count)

        switch item.shape {
        case .line, .porch:
            let sag = (item.shape == .porch) ? rh * 0.25 : 0
            for i in 0..<count {
                let u = count > 1 ? Double(i) / Double(count - 1) : 0.5
                let x = rx + CGFloat(u) * rw
                let curve = sin(u * .pi) * Double(sag)
                rawPts.append(CGPoint(x: x, y: cy + CGFloat(curve)))
            }
        case .roofline:
            for i in 0..<count {
                let u = count > 1 ? Double(i) / Double(count - 1) : 0.5
                let x = rx + CGFloat(u) * rw
                let peak = u < 0.5 ? (1.0 - u * 2.0) : ((u - 0.5) * 2.0)
                let y = ry + CGFloat(peak) * rh
                rawPts.append(CGPoint(x: x, y: y))
            }
        case .tree:
            // Classic spiral/zig-zag garland down a conifer silhouette
            let rows = max(3, min(8, Int(sqrt(Double(count)))))
            for i in 0..<count {
                let u = count > 1 ? Double(i) / Double(count - 1) : 0.5
                let rowFrac = (u * Double(rows)).truncatingRemainder(dividingBy: 1.0)
                let dir = (Int(u * Double(rows)) % 2 == 0) ? rowFrac : (1.0 - rowFrac)
                let halfSpan = (0.12 + 0.88 * u) * Double(rw) * 0.5
                let x = cx + CGFloat((dir - 0.5) * 2.0 * halfSpan)
                let y = ry + CGFloat(u) * rh
                rawPts.append(CGPoint(x: x, y: y))
            }
        case .wreath:
            for i in 0..<count {
                let ang = (Double(i) / Double(count)) * .pi * 2.0 - (.pi * 0.5)
                let x = cx + cos(ang) * rw * 0.45
                let y = cy + sin(ang) * rh * 0.45
                rawPts.append(CGPoint(x: x, y: y))
            }
        case .window, .yard:
            for i in 0..<count {
                let p = Double(i) / Double(count)
                let seg = p * 4.0
                let x: CGFloat
                let y: CGFloat
                if seg < 1.0 {
                    x = rx + CGFloat(seg) * rw; y = ry
                } else if seg < 2.0 {
                    x = rx + rw; y = ry + CGFloat(seg - 1.0) * rh
                } else if seg < 3.0 {
                    x = rx + rw - CGFloat(seg - 2.0) * rw; y = ry + rh
                } else {
                    x = rx; y = ry + rh - CGFloat(seg - 3.0) * rh
                }
                rawPts.append(CGPoint(x: x, y: y))
            }
        case .door:
            for i in 0..<count {
                let u = count > 1 ? Double(i) / Double(count - 1) : 0.5
                if u < 0.35 {
                    let t = u / 0.35
                    rawPts.append(CGPoint(x: rx, y: ry + rh - CGFloat(t) * rh))
                } else if u < 0.65 {
                    let t = (u - 0.35) / 0.30
                    rawPts.append(CGPoint(x: rx + CGFloat(t) * rw, y: ry))
                } else {
                    let t = (u - 0.65) / 0.35
                    rawPts.append(CGPoint(x: rx + rw, y: ry + CGFloat(t) * rh))
                }
            }
        case .custom:
            for i in 0..<count {
                let u = count > 1 ? Double(i) / Double(count - 1) : 0.5
                let x = rx + CGFloat(u) * rw
                let wave = 0.5 + 0.42 * sin(u * .pi * 2.5)
                let y = ry + CGFloat(wave) * rh
                rawPts.append(CGPoint(x: x, y: y))
            }
        }

        // Apply rotation around strand bounding center
        let rad = item.rotationDegrees * .pi / 180.0
        guard abs(rad) > 0.0001 else { return rawPts }
        let ca = cos(rad), sa = sin(rad)
        return rawPts.map { p in
            let dx = Double(p.x - cx), dy = Double(p.y - cy)
            return CGPoint(x: cx + CGFloat(dx * ca - dy * sa), y: cy + CGFloat(dx * sa + dy * ca))
        }
    }

    public static func buildBulbNodes(for doc: VirtualLayoutDocument, canvasBounds: CGRect, timeSeconds: Double, brightnessScale: Double = 1.0) -> [VirtualBulbNode] {
        var nodes: [VirtualBulbNode] = []
        for item in doc.strands {
            let pts = sampleStrandPoints(item: item, inCanvasBounds: canvasBounds)
            let tileSize: CGFloat = max(12.0, min(28.0, 22.0 / CGFloat(max(0.5, item.spacingScale))))
            let pal = item.palette.colors
            let count = max(1, pts.count)

            for (idx, pt) in pts.enumerated() {
                let c = pal[idx % max(1, pal.count)]
                let u = Double(idx) / Double(count)
                let phase = (timeSeconds * 1.4 - u * 4.0)
                let wave = 0.5 + 0.5 * sin(phase * .pi)
                let intensity: Double
                var outColor = c

                switch item.assignedEffect {
                case .twinklefox, .gentleTwinkle, .glitter:
                    let seed = Double((idx * 17 + item.name.hashValue) & 31) / 31.0
                    intensity = max(0.18, 0.55 + 0.45 * sin((timeSeconds * 2.2 + seed * 6.28)))
                case .rainbowChase, .colorWave, .scanner:
                    let active = (Int(timeSeconds * 6.0) % max(2, min(6, count))) == (idx % max(2, min(6, count)))
                    intensity = active ? 1.0 : 0.28
                    if item.assignedEffect == .rainbowChase {
                        let c2 = pal[(idx + Int(timeSeconds * 3.0)) % max(1, pal.count)]
                        outColor = c2
                    }
                case .candleFlicker:
                    intensity = max(0.35, 0.72 + 0.28 * sin(timeSeconds * 9.0 + Double(idx) * 1.7))
                default:
                    intensity = max(0.22, wave)
                }

                let frame = CGRect(x: pt.x - tileSize * 0.5, y: pt.y - tileSize * 0.5, width: tileSize, height: tileSize)
                let st = ModernBulbState(
                    index: nodes.count,
                    frame: frame,
                    edge: .top,
                    isBareWire: false,
                    isMissing: false,
                    isBroken: false,
                    isBurnedOut: false,
                    r: outColor.0,
                    g: outColor.1,
                    b: outColor.2,
                    intensity: max(0.0, min(1.0, intensity * brightnessScale))
                )
                nodes.append(VirtualBulbNode(strandID: item.id, zoneID: item.zoneID, bulbSetID: item.bulbSetID, state: st))
            }
        }
        return nodes
    }

    public static func builtInSampleLayouts() -> [VirtualLayoutDocument] {
        var roof = VirtualStrandItem(name: "Main Roofline Gables", shape: .roofline, zoneID: "roofline", originX: 0.08, originY: 0.12, width: 0.84, height: 0.24, bulbCount: 40)
        roof.assignedEffect = .twinklefox
        roof.palette = .warmWhite

        var tree = VirtualStrandItem(name: "Front Yard Evergreens", shape: .tree, zoneID: "tree", originX: 0.12, originY: 0.42, width: 0.26, height: 0.46, bulbCount: 36)
        tree.assignedEffect = .rainbowChase
        tree.palette = .classicHoliday

        var win = VirtualStrandItem(name: "Bay Window Outline", shape: .window, zoneID: "window", originX: 0.44, originY: 0.44, width: 0.22, height: 0.28, bulbCount: 24)
        win.assignedEffect = .gentleTwinkle
        win.palette = .coolIce

        var door = VirtualStrandItem(name: "Entry Door Arch", shape: .door, zoneID: "door", originX: 0.72, originY: 0.44, width: 0.16, height: 0.36, bulbCount: 22)
        door.assignedEffect = .candleFlicker
        door.palette = .candyCane

        return [
            VirtualLayoutDocument(id: "layout:classic_home", name: "Holiday House Front", strands: [roof, tree, win, door])
        ]
    }

    public static func saveBackgroundImageLocalCopy(from sourceURL: URL) -> String? {
        let dir = layoutAssetsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
        let filename = "bg_\(UUID().uuidString.prefix(8)).\(ext)"
        let dst = dir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: sourceURL) else { return nil }
        do {
            try data.write(to: dst, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    public static func exportLayout(_ doc: VirtualLayoutDocument) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(doc)
    }

    public static func importLayout(data: Data) throws -> VirtualLayoutDocument {
        try JSONDecoder().decode(VirtualLayoutDocument.self, from: data)
    }
}
