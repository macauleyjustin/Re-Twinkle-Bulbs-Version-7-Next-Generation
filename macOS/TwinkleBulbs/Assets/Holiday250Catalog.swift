import Foundation
import CoreGraphics
import AppKit

// MARK: - Complete Holiday Edition 250-Set Catalog Definition

public struct HolidayBulbDefinition: Equatable {
    public let number: Int // 1...250
    public let id: String
    public let title: String
    public let collection: BulbCollectionCategory
    public let tintable: Bool // Whether 7-color ColorMode shifts primary palette cleanly
}

public enum Holiday250Catalog {
    public static let allDefinitions: [HolidayBulbDefinition] = {
        let raw: [(BulbCollectionCategory, String, Bool)] = [
            // Collection 1 — Classic Christmas Lights (1..10)
            (.classicChristmasLights, "C7 Incandescent", true),
            (.classicChristmasLights, "C9 Incandescent", true),
            (.classicChristmasLights, "Miniature Incandescent", true),
            (.classicChristmasLights, "Faceted LED", true),
            (.classicChristmasLights, "Frosted Glass Bulb", true),
            (.classicChristmasLights, "Transparent Glass Globe", true),
            (.classicChristmasLights, "Ceramic Opaque Bulb", true),
            (.classicChristmasLights, "Icicle Light", true),
            (.classicChristmasLights, "Candle-Tip Light", true),
            (.classicChristmasLights, "Vintage Bubble Lamp", true),
            // Collection 2 — Christmas Decorations (11..20)
            (.christmasDecorations, "Candy Cane", false),
            (.christmasDecorations, "Holly Sprig", false),
            (.christmasDecorations, "Mistletoe", false),
            (.christmasDecorations, "Poinsettia", true),
            (.christmasDecorations, "Pine Cone", false),
            (.christmasDecorations, "Glass Ornament", true),
            (.christmasDecorations, "Christmas Bell", false),
            (.christmasDecorations, "Decorative Bow", true),
            (.christmasDecorations, "Christmas Stocking", true),
            (.christmasDecorations, "Wrapped Present", true),
            // Collection 3 — Winter Wonderland (21..30)
            (.winterWonderland, "Snowflake", true),
            (.winterWonderland, "Icicle", false),
            (.winterWonderland, "Winter Mitten", true),
            (.winterWonderland, "Knitted Winter Hat", true),
            (.winterWonderland, "Winter Scarf", true),
            (.winterWonderland, "Wooden Sled", false),
            (.winterWonderland, "Ice Skate", true),
            (.winterWonderland, "Snowman", false),
            (.winterWonderland, "Penguin", false),
            (.winterWonderland, "Snow Globe", true),
            // Collection 4 — Traditional Christmas Symbols (31..40)
            (.traditionalChristmasSymbols, "Bethlehem Star", true),
            (.traditionalChristmasSymbols, "Angel", true),
            (.traditionalChristmasSymbols, "Manger", false),
            (.traditionalChristmasSymbols, "Shepherd's Staff", false),
            (.traditionalChristmasSymbols, "Lamb", false),
            (.traditionalChristmasSymbols, "Dove", false),
            (.traditionalChristmasSymbols, "Wise Man's Crown", false),
            (.traditionalChristmasSymbols, "Camel", false),
            (.traditionalChristmasSymbols, "Christmas Lantern", true),
            (.traditionalChristmasSymbols, "Candle", true),
            // Collection 5 — Santa's Workshop (41..50)
            (.santasWorkshop, "Toy Soldier", false),
            (.santasWorkshop, "Nutcracker", false),
            (.santasWorkshop, "Rocking Horse", false),
            (.santasWorkshop, "Toy Train", true),
            (.santasWorkshop, "Teddy Bear", false),
            (.santasWorkshop, "Toy Drum", true),
            (.santasWorkshop, "Wooden Alphabet Blocks", true),
            (.santasWorkshop, "Santa's Sleigh", false),
            (.santasWorkshop, "Reindeer", false),
            (.santasWorkshop, "Elf Boots", false),
            // Collection 6 — Christmas Candy (51..60)
            (.christmasCandy, "Peppermint Disk", true),
            (.christmasCandy, "Gumdrop", true),
            (.christmasCandy, "Lollipop", true),
            (.christmasCandy, "Gingerbread Person", false),
            (.christmasCandy, "Christmas Cookie", false),
            (.christmasCandy, "Candy Drop", true),
            (.christmasCandy, "Sugar Plum", true),
            (.christmasCandy, "Chocolate Bell", false),
            (.christmasCandy, "Candy Ribbon", true),
            (.christmasCandy, "Wrapped Bonbon", true),
            // Collection 7 — Valentine's Day (61..70)
            (.valentinesDay, "Red Heart", false),
            (.valentinesDay, "Pink Heart", false),
            (.valentinesDay, "Cupid Arrow", true),
            (.valentinesDay, "Love Letter", false),
            (.valentinesDay, "Red Rose", true),
            (.valentinesDay, "Lovebirds", true),
            (.valentinesDay, "Heart-Shaped Lock", false),
            (.valentinesDay, "Chocolate Heart", false),
            (.valentinesDay, "Romantic Ribbon", true),
            (.valentinesDay, "Conversation Heart Candy", true),
            // Collection 8 — St. Patrick's Day (71..80)
            (.stPatricksDay, "Shamrock", false),
            (.stPatricksDay, "Four-Leaf Clover", false),
            (.stPatricksDay, "Pot of Gold", false),
            (.stPatricksDay, "Leprechaun Hat", false),
            (.stPatricksDay, "Rainbow", false),
            (.stPatricksDay, "Gold Coin", false),
            (.stPatricksDay, "Celtic Harp", false),
            (.stPatricksDay, "Celtic Knot", true),
            (.stPatricksDay, "Horseshoe", true),
            (.stPatricksDay, "Green Lantern", false),
            // Collection 9 — Easter (81..90)
            (.easter, "Painted Easter Egg", true),
            (.easter, "Pastel Easter Egg", true),
            (.easter, "Easter Bunny", false),
            (.easter, "Baby Chick", false),
            (.easter, "Easter Basket", true),
            (.easter, "Daffodil", false),
            (.easter, "Tulip", true),
            (.easter, "Spring Butterfly", true),
            (.easter, "Easter Lily", false),
            (.easter, "Jelly Bean", true),
            // Collection 10 — Spring Garden (91..100)
            (.springGarden, "Crocus", true),
            (.springGarden, "Hyacinth", true),
            (.springGarden, "Cherry Blossoms", false),
            (.springGarden, "Flower Bud", true),
            (.springGarden, "Pink Tulip", false),
            (.springGarden, "Daisy", false),
            (.springGarden, "Yellow Daffodil", false),
            (.springGarden, "Peony", true),
            (.springGarden, "Watering Can", true),
            (.springGarden, "Ladybug", false),
            // Collection 11 — Spring Rain (101..110)
            (.springRain, "Raindrop", true),
            (.springRain, "Rain Boot", true),
            (.springRain, "Umbrella", true),
            (.springRain, "Puddle", false),
            (.springRain, "Fluffy Cloud", false),
            (.springRain, "Dewdrop", true),
            (.springRain, "Frog", false),
            (.springRain, "Snail", true),
            (.springRain, "Rainbow Cloud", false),
            (.springRain, "Lightning Bolt", false),
            // Collection 12 — Summer Beach (111..120)
            (.summerBeach, "Sunshine", false),
            (.summerBeach, "Seashell", true),
            (.summerBeach, "Starfish", true),
            (.summerBeach, "Palm Tree", false),
            (.summerBeach, "Flip-Flops", true),
            (.summerBeach, "Beach Ball", false),
            (.summerBeach, "Surfboard", true),
            (.summerBeach, "Ice Pop", true),
            (.summerBeach, "Sunglasses", true),
            (.summerBeach, "Lighthouse", false),
            // Collection 13 — Summer Outdoors (121..130)
            (.summerOutdoors, "Firefly", false),
            (.summerOutdoors, "Campfire", false),
            (.summerOutdoors, "Camping Tent", true),
            (.summerOutdoors, "Camping Lantern", true),
            (.summerOutdoors, "Pine Tree", false),
            (.summerOutdoors, "Mountain", false),
            (.summerOutdoors, "Canoe", true),
            (.summerOutdoors, "Hiking Boot", false),
            (.summerOutdoors, "Binoculars", false),
            (.summerOutdoors, "Star Constellation", true),
            // Collection 14 — Flags and Patriotic Designs (131..140)
            (.flagsAndPatriotic, "American Flag", false),
            (.flagsAndPatriotic, "Canadian Flag", false),
            (.flagsAndPatriotic, "British Flag", false),
            (.flagsAndPatriotic, "French Flag", false),
            (.flagsAndPatriotic, "German Flag", false),
            (.flagsAndPatriotic, "Italian Flag", false),
            (.flagsAndPatriotic, "Japanese Flag", false),
            (.flagsAndPatriotic, "European Union Flag", false),
            (.flagsAndPatriotic, "Rainbow Flag", false),
            (.flagsAndPatriotic, "Festive Bunting", true),
            // Collection 15 — Birthdays and Celebrations (141..150)
            (.birthdaysAndCelebrations, "Birthday Cake", true),
            (.birthdaysAndCelebrations, "Birthday Candle", true),
            (.birthdaysAndCelebrations, "Party Balloon", true),
            (.birthdaysAndCelebrations, "Party Hat", true),
            (.birthdaysAndCelebrations, "Confetti Cluster", true),
            (.birthdaysAndCelebrations, "Cupcake", true),
            (.birthdaysAndCelebrations, "Gift Bow", true),
            (.birthdaysAndCelebrations, "Party Horn", true),
            (.birthdaysAndCelebrations, "Celebration Star", true),
            (.birthdaysAndCelebrations, "Streamer", true),
            // Collection 16 — Autumn Leaves (151..160)
            (.autumnLeaves, "Red Maple Leaf", false),
            (.autumnLeaves, "Orange Maple Leaf", false),
            (.autumnLeaves, "Yellow Oak Leaf", false),
            (.autumnLeaves, "Bronze Oak Leaf", false),
            (.autumnLeaves, "Birch Leaf", false),
            (.autumnLeaves, "Aspen Leaf", false),
            (.autumnLeaves, "Ginkgo Leaf", false),
            (.autumnLeaves, "Elm Leaf", false),
            (.autumnLeaves, "Red Ivy Leaf", false),
            (.autumnLeaves, "Multicolored Leaf Cluster", false),
            // Collection 17 — Autumn Harvest (161..170)
            (.autumnHarvest, "Orange Pumpkin", false),
            (.autumnHarvest, "Decorative Gourd", false),
            (.autumnHarvest, "Corn Cob", false),
            (.autumnHarvest, "Red Apple", false),
            (.autumnHarvest, "Golden Pear", false),
            (.autumnHarvest, "Wheat Stalk", false),
            (.autumnHarvest, "Acorn", false),
            (.autumnHarvest, "Scarecrow", false),
            (.autumnHarvest, "Hay Bale", false),
            (.autumnHarvest, "Harvest Basket", false),
            // Collection 18 — Halloween Classics (171..180)
            (.halloweenClassics, "Jack-o'-Lantern", false),
            (.halloweenClassics, "Ghost", false),
            (.halloweenClassics, "Bat", false),
            (.halloweenClassics, "Black Cat", false),
            (.halloweenClassics, "Witch Hat", true),
            (.halloweenClassics, "Witch Broom", false),
            (.halloweenClassics, "Cauldron", true),
            (.halloweenClassics, "Skull", false),
            (.halloweenClassics, "Spider", false),
            (.halloweenClassics, "Spiderweb", true),
            // Collection 19 — Haunted Halloween (181..190)
            (.hauntedHalloween, "Haunted House", false),
            (.hauntedHalloween, "Tombstone", false),
            (.hauntedHalloween, "Raven", false),
            (.hauntedHalloween, "Full Moon", false),
            (.hauntedHalloween, "Zombie Hand", false),
            (.hauntedHalloween, "Haunted Lantern", true),
            (.hauntedHalloween, "Purple Potion Bottle", true),
            (.hauntedHalloween, "Halloween Candy Bucket", false),
            (.hauntedHalloween, "Gargoyle", false),
            (.hauntedHalloween, "Glowing Spooky Eye", true),
            // Collection 20 — Thanksgiving (191..200)
            (.thanksgiving, "Turkey", false),
            (.thanksgiving, "Cornucopia", false),
            (.thanksgiving, "Pumpkin Pie", false),
            (.thanksgiving, "Cranberry Sprig", false),
            (.thanksgiving, "Autumn Wreath", false),
            (.thanksgiving, "Warm Cider Mug", false),
            (.thanksgiving, "Decorated Autumn Plate", false),
            (.thanksgiving, "Gratitude Scroll", false),
            (.thanksgiving, "Harvest Candle", true),
            (.thanksgiving, "Fall Centerpiece", false),
            // Collection 21 — New Year's Eve (201..210)
            (.newYearsEve, "Firework", true),
            (.newYearsEve, "Sparkling Party Glass", true),
            (.newYearsEve, "Midnight Clock", false),
            (.newYearsEve, "NYE Party Horn", true),
            (.newYearsEve, "Silver Star", false),
            (.newYearsEve, "Golden Star", false),
            (.newYearsEve, "Sparkler", true),
            (.newYearsEve, "Midnight Moon", false),
            (.newYearsEve, "Calendar Page", false),
            (.newYearsEve, "Disco Ball", true),
            // Collection 22 — Celestial Lights (211..220)
            (.celestialLights, "Five-Pointed Star", true),
            (.celestialLights, "Crescent Moon", true),
            (.celestialLights, "Full Moon Cratered", false),
            (.celestialLights, "Blue Planet", false),
            (.celestialLights, "Comet", true),
            (.celestialLights, "Nebula", true),
            (.celestialLights, "Ringed Planet", true),
            (.celestialLights, "Shooting Star", true),
            (.celestialLights, "Constellation", true),
            (.celestialLights, "Radiant Sun", false),
            // Collection 23 — Animals (221..230)
            (.animals, "Cat", true),
            (.animals, "Dog", false),
            (.animals, "Fox", false),
            (.animals, "Owl", false),
            (.animals, "Rabbit", true),
            (.animals, "Deer", false),
            (.animals, "Dolphin", false),
            (.animals, "Butterfly", true),
            (.animals, "Hummingbird", true),
            (.animals, "Turtle", false),
            // Collection 24 — Flowers and Plants (231..240)
            (.flowersAndPlants, "Rose", true),
            (.flowersAndPlants, "Sunflower", false),
            (.flowersAndPlants, "Lavender", false),
            (.flowersAndPlants, "Orchid", true),
            (.flowersAndPlants, "Lily", true),
            (.flowersAndPlants, "Fern", false),
            (.flowersAndPlants, "Ivy", false),
            (.flowersAndPlants, "Flowering Cactus", true),
            (.flowersAndPlants, "Succulent", true),
            (.flowersAndPlants, "Cherry Blossom Branch", false),
            // Collection 25 — Retro and Novelty Lighting (241..250)
            (.retroAndNovelty, "Vintage Marquee Bulb", true),
            (.retroAndNovelty, "Arcade Pixel Light", true),
            (.retroAndNovelty, "Eight-Bit Star", true),
            (.retroAndNovelty, "CRT Glow", true),
            (.retroAndNovelty, "Neon Tube", true),
            (.retroAndNovelty, "Prism LED", true),
            (.retroAndNovelty, "Stained-Glass Bulb", true),
            (.retroAndNovelty, "Steampunk Filament", false),
            (.retroAndNovelty, "Copper Edison Bulb", false),
            (.retroAndNovelty, "Fiber-Optic Sparkle", true)
        ]
        return raw.enumerated().map { idx, item in
            let num = idx + 1
            return HolidayBulbDefinition(
                number: num,
                id: String(format: "holiday250:%03d", num),
                title: item.1,
                collection: item.0,
                tintable: item.2
            )
        }
    }()

    public static func definition(for id: String) -> HolidayBulbDefinition? {
        allDefinitions.first { $0.id == id || $0.title.caseInsensitiveCompare(id) == .orderedSame }
    }

    // MARK: - Complete Sprite Pack Synthesis for Any of the 250 Designs

    public static func renderSetPack(definition: HolidayBulbDefinition, size: Int) -> LoadedBulbIcons {
        let meta = BulbSetMetadata(
            id: definition.id,
            title: definition.title,
            author: "Twinkle Bulbs Complete Holiday Edition",
            version: "7.0",
            comment: "Collection \(definition.collection.displayName) — Design #\(definition.number) of 250",
            isMonochrome: !definition.tintable,
            isBitmap: false,
            isOnOnly: false,
            supportsColorModes: definition.tintable,
            collection: definition.collection,
            designNumber: definition.number,
            isHoliday250: true,
            sourceURL: nil
        )

        let bareWire = makeTile(size: size) { ctx, s in
            drawTopWireAndHook(ctx: ctx, s: s, drawHook: false)
        }

        var onMap: [Int: CGImage] = [:]
        var offMap: [Int: CGImage] = [:]
        var brkMap: [Int: CGImage] = [:]

        for c in 0..<7 {
            let colorTuple = BulbArtworkRegistry.slotColors[c]
            let primary = NSColor(srgbRed: CGFloat(colorTuple.onCore.0)/255, green: CGFloat(colorTuple.onCore.1)/255, blue: CGFloat(colorTuple.onCore.2)/255, alpha: 1)
            let glow = NSColor(srgbRed: CGFloat(colorTuple.onGlow.0)/255, green: CGFloat(colorTuple.onGlow.1)/255, blue: CGFloat(colorTuple.onGlow.2)/255, alpha: 1)

            onMap[c] = makeTile(size: size) { ctx, s in
                drawTopWireAndHook(ctx: ctx, s: s, drawHook: true)
                drawDesign(ctx: ctx, number: definition.number, s: s, primary: primary, glow: glow, lit: true, broken: false)
            }
            offMap[c] = makeTile(size: size) { ctx, s in
                drawTopWireAndHook(ctx: ctx, s: s, drawHook: true)
                drawDesign(ctx: ctx, number: definition.number, s: s, primary: primary, glow: glow, lit: false, broken: false)
            }
            brkMap[c] = makeTile(size: size) { ctx, s in
                drawTopWireAndHook(ctx: ctx, s: s, drawHook: true)
                drawDesign(ctx: ctx, number: definition.number, s: s, primary: primary, glow: glow, lit: false, broken: true)
            }
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

    public static func makeTile(size: Int, draw: (CGContext, CGFloat) -> Void) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.translateBy(x: 0, y: CGFloat(size))
        ctx.scaleBy(x: 1, y: -1)
        ctx.setAllowsAntialiasing(true)
        draw(ctx, CGFloat(size) / 32.0)
        return ctx.makeImage()!
    }

    public static func drawTopWireAndHook(ctx: CGContext, s: CGFloat, drawHook: Bool) {
        let wireCol = NSColor(srgbRed: 0.04, green: 0.45, blue: 0.08, alpha: 1.0)
        ctx.setFillColor(wireCol.cgColor)
        // Draped wire curve spanning full x = 0..32 matching classic v6 connectivity
        ctx.fill(CGRect(x: 0, y: 1.5 * s, width: 32 * s, height: 1.8 * s))
        if drawHook {
            ctx.fill(CGRect(x: 14.5 * s, y: 3.0 * s, width: 3.0 * s, height: 2.2 * s))
        }
    }

    /// Dispatches to each of the 250 distinct designs (1..250).
    static func drawDesign(ctx: CGContext, number: Int, s: CGFloat, primary: NSColor, glow: NSColor, lit: Bool, broken: Bool) {
        let activeColor = lit ? glow : (primary.blended(withFraction: 0.58, of: .black) ?? primary)
        let rimColor = NSColor(white: lit ? 0.12 : 0.08, alpha: 0.92)
        if lit {
            ctx.saveGState()
            let aura = activeColor.withAlphaComponent(0.32)
            ctx.setFillColor(aura.cgColor)
            ctx.fillEllipse(in: CGRect(x: 5 * s, y: 6 * s, width: 22 * s, height: 24 * s))
            ctx.restoreGState()
        }

        switch number {
        case 1...50:
            drawBatch1_01_to_50(ctx: ctx, n: number, s: s, col: activeColor, rawPrimary: primary, rim: rimColor, lit: lit, broken: broken)
        case 51...120:
            drawBatch2_51_to_120(ctx: ctx, n: number, s: s, col: activeColor, rawPrimary: primary, rim: rimColor, lit: lit, broken: broken)
        case 121...190:
            drawBatch3_121_to_190(ctx: ctx, n: number, s: s, col: activeColor, rawPrimary: primary, rim: rimColor, lit: lit, broken: broken)
        default:
            drawBatch4_191_to_250(ctx: ctx, n: number, s: s, col: activeColor, rawPrimary: primary, rim: rimColor, lit: lit, broken: broken)
        }

        if broken {
            // Jagged fracture crack & missing lower chunk overlay
            ctx.setStrokeColor(NSColor(white: 0.95, alpha: 0.85).cgColor)
            ctx.setLineWidth(max(1.0, 1.3 * s))
            ctx.move(to: CGPoint(x: 11 * s, y: 12 * s))
            ctx.addLine(to: CGPoint(x: 16 * s, y: 16 * s))
            ctx.addLine(to: CGPoint(x: 13 * s, y: 21 * s))
            ctx.addLine(to: CGPoint(x: 20 * s, y: 26 * s))
            ctx.strokePath()
        }
    }

    // Shared clean-room vector primitives used across the 250 designs
    static func fillAndStroke(_ ctx: CGContext, path: CGPath, fill: NSColor, stroke: NSColor, lineW: CGFloat = 1.1) {
        ctx.addPath(path)
        ctx.setFillColor(fill.cgColor)
        ctx.fillPath()
        ctx.addPath(path)
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(lineW)
        ctx.strokePath()
    }

    static func shade(_ c: NSColor, lit: Bool, darkFraction: CGFloat = 0.56) -> NSColor {
        lit ? c : (c.blended(withFraction: darkFraction, of: .black) ?? c)
    }

    static func starPath(center: CGPoint, outerR: CGFloat, innerR: CGFloat, points: Int) -> CGPath {
        let p = CGMutablePath()
        let total = points * 2
        for i in 0..<total {
            let r = (i % 2 == 0) ? outerR : innerR
            let a = (CGFloat(i) * .pi / CGFloat(points)) - (.pi / 2.0)
            let pt = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    static func heartPath(cx: CGFloat, topY: CGFloat, w: CGFloat, h: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: cx, y: topY + h))
        p.addCurve(to: CGPoint(x: cx - w * 0.5, y: topY + h * 0.35),
                   control1: CGPoint(x: cx - w * 0.52, y: topY + h * 0.72),
                   control2: CGPoint(x: cx - w * 0.52, y: topY + h * 0.48))
        p.addArc(center: CGPoint(x: cx - w * 0.25, y: topY + h * 0.28), radius: w * 0.25, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addArc(center: CGPoint(x: cx + w * 0.25, y: topY + h * 0.28), radius: w * 0.25, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addCurve(to: CGPoint(x: cx, y: topY + h),
                   control1: CGPoint(x: cx + w * 0.52, y: topY + h * 0.48),
                   control2: CGPoint(x: cx + w * 0.52, y: topY + h * 0.72))
        p.closeSubpath()
        return p
    }
}
