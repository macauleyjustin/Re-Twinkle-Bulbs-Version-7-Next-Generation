import Foundation
import CoreGraphics
import AppKit

public enum WallpaperThemeCategory: String, CaseIterable, Codable, Identifiable {
    case all = "All Collections"
    case christmas = "Christmas"
    case winter = "Winter"
    case autumn = "Autumn"
    case halloween = "Halloween"
    case spring = "Spring"
    case summer = "Summer"
    case valentines = "Valentine's Day"
    case easter = "Easter"
    case thanksgiving = "Thanksgiving"
    case newYears = "New Year's"
    case celestial = "Celestial & Holiday Folk"

    public var id: String { rawValue }
}

public struct BuiltInWallpaperSpec {
    public let id: String
    public let title: String
    public let category: WallpaperThemeCategory
    public let isTile: Bool
    public let variantSeed: Int
    public let motifKind: Int
}

public enum WallpaperPack130 {
    /// Exactly 130 distinct seasonal desktop wallpapers across 11 themed collections.
    public static let allSpecs: [BuiltInWallpaperSpec] = {
        var specs: [BuiltInWallpaperSpec] = [
            // 5 Original Classic presets (preserving exact v1 IDs!)
            BuiltInWallpaperSpec(id: "dark_snowflakes", title: "Dark Snowflakes (Tile)", category: .winter, isTile: true, variantSeed: 1, motifKind: 0),
            BuiltInWallpaperSpec(id: "holiday_bulbs_dark", title: "Holiday Bulbs Night", category: .christmas, isTile: false, variantSeed: 2, motifKind: 1),
            BuiltInWallpaperSpec(id: "candy_canes", title: "Candy Canes Stripes (Tile)", category: .christmas, isTile: true, variantSeed: 3, motifKind: 2),
            BuiltInWallpaperSpec(id: "holly_berries", title: "Holly & Berries", category: .christmas, isTile: true, variantSeed: 4, motifKind: 3),
            BuiltInWallpaperSpec(id: "starlight_pine", title: "Starlight Pine", category: .christmas, isTile: false, variantSeed: 5, motifKind: 4)
        ]

        let themedSets: [(WallpaperThemeCategory, [(String, Bool, Int)])] = [
            (.christmas, [
                ("Evergreen Garland", true, 5), ("Silent Night Village", false, 6), ("Fireside Hearth", false, 7),
                ("Golden Tinsel Bokeh", false, 8), ("Red Velvet Ribbon", true, 9), ("Gingerbread Frosting", true, 10),
                ("North Star Meadow", false, 11), ("Toyshop Window", false, 12), ("Pinecone Tartan", true, 13),
                ("Poinsettia Velvet", false, 14), ("Ornaments on Pine", false, 15), ("Sleigh Bells Ridge", false, 16),
                ("Mint Swirl Tile", true, 17), ("Bethlehem Glow", false, 18), ("Cozy Stockings", false, 19),
                ("Warm Candlelit Glass", false, 20)
            ]),
            (.winter, [
                ("Aurora Borealis Pines", false, 11), ("Frosted Windowpane", true, 21), ("Midnight Blizzard", false, 0),
                ("Arctic Ice Crystals", true, 22), ("Moonlit Snowy Valley", false, 6), ("Crystal Icicle Fringe", true, 23),
                ("Glacier Blue Horizon", false, 24), ("Silver Fir Dusk", false, 4), ("Polar Constellation", false, 25),
                ("Powder Drift Meadow", false, 16), ("Knitted Sweater Argyle", true, 13)
            ]),
            (.autumn, [
                ("Maple Ridge Sunset", false, 26), ("Golden Birch Woods", false, 27), ("Amber Falling Leaves", true, 28),
                ("Russet Oak Canopy", false, 26), ("Misty Harvest Dawn", false, 27), ("Cinnamon Spice Plaid", true, 13),
                ("Copper Foliage Tile", true, 28), ("Acorn & Oak Pattern", true, 28), ("October Twilight", false, 26),
                ("Crimson Vine Tapestry", true, 28), ("Warm Orchard Gold", false, 26)
            ]),
            (.halloween, [
                ("Midnight Jack-o'-Lantern", false, 29), ("Haunted Manor Hill", false, 30), ("Purple Spiderweb Lace", true, 31),
                ("Bats at Full Moon", false, 30), ("Harvest Witch Sky", false, 29), ("Candlelit Pumpkin Row", false, 29),
                ("Eerie Mist Graveyard", false, 30), ("Potion Bokeh Purple", false, 8), ("Spooky Cat Silhouettes", true, 31),
                ("Haunted Lantern Path", false, 29), ("Black & Orange Argyle", true, 13)
            ]),
            (.spring, [
                ("Cherry Blossom Breeze", false, 32), ("Morning Rain Window", false, 33), ("Pastel Meadow Flowers", false, 34),
                ("Sunlit Dewdrops", true, 35), ("Sakura Petal Tile", true, 32), ("Bluebird Sky Clouds", false, 36),
                ("Rainbow Over Hills", false, 37), ("Emerald Fern Canopy", true, 38), ("Spring Tulip Garden", false, 34),
                ("Apricot Dawn Horizon", false, 24), ("Wildflower Confetti", true, 35), ("Refreshing Brook", false, 33)
            ]),
            (.summer, [
                ("Firefly Twilight Field", false, 39), ("Golden Beach Sunset", false, 40), ("Starry Milky Way", false, 25),
                ("Ocean Wave Shimmer", false, 40), ("Campfire Pine Clearing", false, 7), ("Tropical Palm Horizon", false, 41),
                ("Coastal Lighthouse Glow", false, 40), ("Warm Horizon Rays", false, 42), ("Coral Reef Tile", true, 43),
                ("Sunburst Citrus Tile", true, 42), ("Midsummer Meteor", false, 25), ("Turquoise Tide", false, 43)
            ]),
            (.valentines, [
                ("Velvet Crimson Hearts", true, 44), ("Rose Petal Silk", false, 45), ("Blush Romance Bokeh", false, 8),
                ("Sweetheart Stripes", true, 2), ("Golden Cupid Arrow", false, 44), ("Lavender Love Notes", true, 44),
                ("Candlelit Wine Satin", false, 45), ("Pink Heart Confetti", true, 44), ("Midnight Ruby Glow", false, 45),
                ("Soft Blush Gradient", false, 24)
            ]),
            (.easter, [
                ("Pastel Egg Meadow", false, 46), ("Spring Daffodil Sun", false, 34), ("Lilac Gingham Check", true, 13),
                ("Painted Egg Pattern", true, 46), ("Sunrise Lily Horizon", false, 34), ("Mint & Lemon Dots", true, 35),
                ("Butterfly Garden", false, 32), ("Easter Morning Sky", false, 36), ("Pastel Ribbon Weave", true, 2),
                ("Clover & Daisies", true, 34)
            ]),
            (.thanksgiving, [
                ("Autumn Cider Warmth", false, 27), ("Harvest Moon Field", false, 26), ("Cranberry & Gold Leaf", true, 28),
                ("Rustic Cornucopia", false, 27), ("Amber Candle Table", false, 20), ("Warm Hearth Glow", false, 7),
                ("Wheat Field Golden", false, 27), ("Gourd & Acorn Mosaic", true, 28), ("Deep Copper Plume", true, 13),
                ("November Sunbeam", false, 24)
            ]),
            (.newYears, [
                ("Midnight Fireworks", false, 47), ("Champagne Fizz Gold", false, 8), ("Clock Strike Gold Tile", true, 48),
                ("Silver Disco Mosaic", true, 48), ("Starburst Countdown", false, 47), ("Patriotic Sparkle", false, 47),
                ("Confetti Streamers", true, 48), ("Sapphire Midnight Sky", false, 25), ("Diamond Sparkle Dots", true, 48),
                ("Festive Horizon Glow", false, 47)
            ]),
            (.celestial, [
                ("Crescent Moon Indigo", false, 25), ("Cosmic Violet Nebula", false, 49), ("Ringed Saturn Horizon", false, 25),
                ("Stained Glass Mosaic", true, 50), ("Marquee Bulb Glow", false, 8), ("Celtic Emerald Knot", true, 51),
                ("Shamrock Gold Clover", true, 51), ("Sunburst Retro Stripes", true, 2), ("Cobalt Prism Lattice", true, 50),
                ("Cyber Neon Waves", false, 11), ("Copper Steam Gear", true, 48), ("Northern Frost Silk", false, 21)
            ])
        ]

        var seq = 6
        for (cat, list) in themedSets {
            for (title, isTile, motif) in list {
                let id = String(format: "holiday_wp_%03d", seq)
                specs.append(BuiltInWallpaperSpec(id: id, title: title, category: cat, isTile: isTile, variantSeed: seq, motifKind: motif))
                seq += 1
            }
        }
        return specs
    }()

    public static func renderWallpaper(_ spec: BuiltInWallpaperSpec, width w: Int, height h: Int) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let palettes: [(NSColor, NSColor, NSColor)] = [
            // 0 Winter midnight
            (NSColor(srgbRed: 0.03, green: 0.08, blue: 0.20, alpha: 1), NSColor(srgbRed: 0.12, green: 0.28, blue: 0.52, alpha: 1), NSColor(srgbRed: 0.85, green: 0.94, blue: 1.0, alpha: 1)),
            // 1 Christmas deep emerald/ruby
            (NSColor(srgbRed: 0.04, green: 0.14, blue: 0.08, alpha: 1), NSColor(srgbRed: 0.12, green: 0.34, blue: 0.16, alpha: 1), NSColor(srgbRed: 0.95, green: 0.22, blue: 0.24, alpha: 1)),
            // 2 Autumn warm
            (NSColor(srgbRed: 0.24, green: 0.08, blue: 0.04, alpha: 1), NSColor(srgbRed: 0.68, green: 0.30, blue: 0.06, alpha: 1), NSColor(srgbRed: 0.98, green: 0.78, blue: 0.22, alpha: 1)),
            // 3 Halloween violet/pumpkin
            (NSColor(srgbRed: 0.08, green: 0.02, blue: 0.16, alpha: 1), NSColor(srgbRed: 0.26, green: 0.08, blue: 0.38, alpha: 1), NSColor(srgbRed: 0.98, green: 0.50, blue: 0.08, alpha: 1)),
            // 4 Spring pastel sky/blossom
            (NSColor(srgbRed: 0.24, green: 0.58, blue: 0.88, alpha: 1), NSColor(srgbRed: 0.68, green: 0.88, blue: 0.96, alpha: 1), NSColor(srgbRed: 1.0, green: 0.74, blue: 0.85, alpha: 1)),
            // 5 Summer twilight/sunset
            (NSColor(srgbRed: 0.22, green: 0.08, blue: 0.38, alpha: 1), NSColor(srgbRed: 0.92, green: 0.42, blue: 0.14, alpha: 1), NSColor(srgbRed: 1.0, green: 0.84, blue: 0.26, alpha: 1)),
            // 6 Valentine ruby/rose
            (NSColor(srgbRed: 0.34, green: 0.02, blue: 0.10, alpha: 1), NSColor(srgbRed: 0.68, green: 0.10, blue: 0.28, alpha: 1), NSColor(srgbRed: 1.0, green: 0.55, blue: 0.75, alpha: 1))
        ]

        let palIdx: Int
        switch spec.category {
        case .winter: palIdx = 0
        case .christmas, .celestial: palIdx = spec.variantSeed % 2 == 0 ? 1 : 0
        case .autumn, .thanksgiving: palIdx = 2
        case .halloween: palIdx = 3
        case .spring, .easter: palIdx = 4
        case .summer: palIdx = 5
        case .valentines: palIdx = 6
        default: palIdx = spec.variantSeed % palettes.count
        }
        let pal = palettes[palIdx]

        // Shift hue slightly per variantSeed so every wallpaper is visually distinct
        let hueShift = CGFloat((spec.variantSeed * 37) % 100) / 1000.0
        let cTop = pal.0.blended(withFraction: hueShift, of: pal.1) ?? pal.0
        let cBot = pal.1.blended(withFraction: hueShift * 1.4, of: pal.2) ?? pal.1
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [cTop.cgColor, cBot.cgColor] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: CGFloat((spec.variantSeed % 3) * w / 3), y: CGFloat(h)), options: [])
        }

        // Seeded deterministic artwork layer matching motifKind & variantSeed
        var rng = SeededRandomSource(seed: UInt64(spec.variantSeed * 2654435761))
        let wf = CGFloat(w), hf = CGFloat(h)

        switch spec.motifKind % 10 {
        case 0, 1, 2: // Snowflakes, Bokeh Stars & Festoon Bulbs
            let count = spec.isTile ? 14 : 46
            for i in 0..<count {
                let cx = CGFloat(rng.nextInt(upperBound: w))
                let cy = CGFloat(rng.nextInt(upperBound: h))
                let rad = CGFloat(6 + rng.nextInt(upperBound: spec.isTile ? 14 : 38))
                ctx.setFillColor(pal.2.withAlphaComponent(0.18 + CGFloat(i % 4) * 0.08).cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2))
                if spec.motifKind % 3 == 0 {
                    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.55).cgColor)
                    ctx.setLineWidth(1.5)
                    for b in 0..<6 {
                        let a = CGFloat(b) * .pi / 3.0
                        ctx.move(to: CGPoint(x: cx, y: cy)); ctx.addLine(to: CGPoint(x: cx + cos(a) * rad, y: cy + sin(a) * rad))
                    }
                    ctx.strokePath()
                }
            }
        case 3, 4, 5: // Diagonal stripes, Plaid / Tartan weave, or Ribbon patterns
            let stripes = spec.isTile ? 6 : 14
            ctx.setStrokeColor(pal.2.withAlphaComponent(0.28).cgColor)
            ctx.setLineWidth(max(4, wf / CGFloat(stripes * 3)))
            for i in -stripes...(stripes * 2) {
                let x = CGFloat(i) * (wf / CGFloat(stripes))
                ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x + wf * 0.5, y: hf))
                if spec.motifKind % 2 == 0 {
                    ctx.move(to: CGPoint(x: x + wf * 0.5, y: 0)); ctx.addLine(to: CGPoint(x: x, y: hf))
                }
            }
            ctx.strokePath()
        case 6, 7: // Layered Rolling Horizon / Tree Silhouettes / Village
            for layer in 0..<3 {
                let yBase = hf * (0.35 + CGFloat(layer) * 0.16)
                let colLayer = cTop.blended(withFraction: 0.25 * CGFloat(layer), of: .black) ?? cTop
                ctx.setFillColor(colLayer.withAlphaComponent(0.88).cgColor)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: 0)); path.addLine(to: CGPoint(x: wf, y: 0))
                path.addLine(to: CGPoint(x: wf, y: yBase))
                path.addCurve(to: CGPoint(x: 0, y: yBase * 0.9),
                              control1: CGPoint(x: wf * 0.65, y: yBase + hf * 0.12),
                              control2: CGPoint(x: wf * 0.35, y: yBase - hf * 0.10))
                path.closeSubpath(); ctx.addPath(path); ctx.fillPath()
            }
            // Scattered glowing lights or stars in sky
            for _ in 0..<32 {
                let sx = CGFloat(rng.nextInt(upperBound: w))
                let sy = hf * 0.45 + CGFloat(rng.nextInt(upperBound: max(1, Int(hf * 0.52))))
                ctx.setFillColor(pal.2.withAlphaComponent(0.75).cgColor)
                ctx.fillEllipse(in: CGRect(x: sx, y: sy, width: 3.5, height: 3.5))
            }
        default: // Radiant Aurora, Heart/Star Mosaic, or Burst Pattern
            let center = CGPoint(x: wf * CGFloat(25 + (spec.variantSeed % 50)) / 100.0, y: hf * 0.55)
            for ring in 1...8 {
                let rad = wf * CGFloat(ring) * 0.08
                ctx.setStrokeColor(pal.2.withAlphaComponent(0.24).cgColor)
                ctx.setLineWidth(3.0)
                ctx.strokeEllipse(in: CGRect(x: center.x - rad, y: center.y - rad, width: rad * 2, height: rad * 2))
            }
            for _ in 0..<24 {
                let px = CGFloat(rng.nextInt(upperBound: w))
                let py = CGFloat(rng.nextInt(upperBound: h))
                let starP = Holiday250Catalog.starPath(center: CGPoint(x: px, y: py), outerR: 12, innerR: 5, points: 5)
                ctx.addPath(starP); ctx.setFillColor(pal.2.withAlphaComponent(0.45).cgColor); ctx.fillPath()
            }
        }
        return ctx.makeImage()
    }
}
