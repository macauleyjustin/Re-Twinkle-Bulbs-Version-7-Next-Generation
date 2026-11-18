import Foundation
import CoreGraphics
import Compression

// MARK: - Bulb Set Metadata & Parsed Assets

public struct BulbSetMetadata: Equatable {
    public var id: String
    public var title: String
    public var author: String = "Barefoot Productions"
    public var version: String = "6.0"
    public var comment: String = ""
    public var creationDate: String = ""
    public var email: String = ""
    public var webPage: String = ""
    public var isMonochrome: Bool = false // str[5010] == "1"
    public var isBitmap: Bool = false     // str[5012] == "1"
    public var isOnOnly: Bool = false     // str[5014] == "1" (requires highlight blend for OFF state)
    public var supportsColorModes: Bool = true
    public var collection: BulbCollectionCategory = .classicBuiltIn
    public var designNumber: Int = 0
    public var isHoliday250: Bool = false
    public var sourceURL: URL? = nil
}

public struct LoadedBulbIcons {
    public var metadata: BulbSetMetadata
    public var sample: CGImage?
    public var bareWire: CGImage?
    /// Keyed by [colorIndex 0..6]
    public var onImages: [Int: CGImage] = [:]
    public var offImages: [Int: CGImage] = [:]
    public var brokenImages: [Int: CGImage] = [:]
}

// MARK: - Win32 PE / NE / ICO Clean-Room Resource Loader

public final class BLBResourceLoader {

    struct PESection {
        let virtualAddress: Int
        let virtualSize: Int
        let rawOffset: Int
        let rawSize: Int
    }

    /// Attempts to load a `.blb` (PE DLL), `.icl` (PE or NE icon library), or `.ico` file from disk.
    public static func load(url: URL, preferredSize: Int = 32, highlightRGB: (UInt8, UInt8, UInt8) = (0, 0, 128)) -> LoadedBulbIcons? {
        guard let data = try? Data(contentsOf: url), data.count >= 64 else { return nil }
        let ext = url.pathExtension.lowercased()
        let baseName = url.deletingPathExtension().lastPathComponent

        if ext == "ico" {
            guard let icon = parseStandaloneICO(data: data, preferredSize: preferredSize) else { return nil }
            let dimmed = blendHalfWithHighlight(image: icon, rgb: highlightRGB)
            var onMap: [Int: CGImage] = [:]
            var offMap: [Int: CGImage] = [:]
            for c in 0..<7 {
                onMap[c] = icon
                offMap[c] = dimmed
            }
            let meta = BulbSetMetadata(id: baseName, title: baseName, isMonochrome: true, isOnOnly: true, sourceURL: url)
            return LoadedBulbIcons(metadata: meta, sample: icon, bareWire: nil, onImages: onMap, offImages: offMap, brokenImages: [:])
        }

        if ext == "blz" {
            if let decompressed = unwrapCompressedBLZIfStandard(data: data),
               let loaded = loadFromMemory(data: decompressed, baseName: baseName, sourceURL: url, preferredSize: preferredSize, highlightRGB: highlightRGB) {
                return loaded
            }
        }

        return loadFromMemory(data: data, baseName: baseName, sourceURL: url, preferredSize: preferredSize, highlightRGB: highlightRGB)
    }

    private static func loadFromMemory(data: Data, baseName: String, sourceURL: URL, preferredSize: Int, highlightRGB: (UInt8, UInt8, UInt8)) -> LoadedBulbIcons? {
        guard data.count >= 64, readU16(data, 0) == 0x5A4D else { return nil }
        let lfanew = Int(readU32(data, 0x3C))
        guard lfanew >= 0 && lfanew + 4 <= data.count else { return nil }

        let sig = readU16(data, lfanew)
        if sig == 0x4550 && readU16(data, lfanew + 2) == 0x0000 {
            return parsePEBulbLibrary(data: data, lfanew: lfanew, fallbackTitle: baseName, sourceURL: sourceURL, preferredSize: preferredSize, highlightRGB: highlightRGB)
        } else if sig == 0x454E {
            return parseNEIconLibrary(data: data, neOff: lfanew, fallbackTitle: baseName, sourceURL: sourceURL, preferredSize: preferredSize, highlightRGB: highlightRGB)
        }
        return nil
    }

    public static func unwrapCompressedBLZIfStandard(data: Data) -> Data? {
        guard data.count >= 6 else { return nil }
        if data[0] == 0x78 {
            let maxDst = min(16 * 1024 * 1024, data.count * 24)
            var out = Data(count: maxDst)
            let decodedSize = data.subdata(in: 2..<data.count).withUnsafeBytes { srcPtr in
                out.withUnsafeMutableBytes { dstPtr in
                    guard let s = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                          let d = dstPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    return compression_decode_buffer(d, maxDst, s, data.count - 2, nil, COMPRESSION_ZLIB)
                }
            }
            if decodedSize > 64 { return out.prefix(decodedSize) }
        }
        if data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x03 && data[3] == 0x04 && data.count > 30 {
            let compMethod = readU16(data, 8)
            let compSize = Int(readU32(data, 18))
            let nameLen = Int(readU16(data, 26))
            let extraLen = Int(readU16(data, 28))
            let payloadStart = 30 + nameLen + extraLen
            if compMethod == 0 && compSize > 64 && payloadStart + compSize <= data.count {
                return data.subdata(in: payloadStart..<(payloadStart + compSize))
            }
        }
        return nil
    }

    // MARK: - 50% Highlight Blending (COMCTL32 ILD_BLEND50 equivalent)

    public static func blendHalfWithHighlight(image: CGImage, rgb: (UInt8, UInt8, UInt8)) -> CGImage {
        let w = image.width
        let h = image.height
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rgba, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        let hr = Int(rgb.0)
        let hg = Int(rgb.1)
        let hb = Int(rgb.2)
        for p in stride(from: 0, to: rgba.count, by: 4) {
            let a = Int(rgba[p + 3])
            if a > 0 {
                // Unpremultiply safely, blend 50% with highlight, re-premultiply
                let r = min(255, Int(rgba[p]) * 255 / max(1, a))
                let g = min(255, Int(rgba[p + 1]) * 255 / max(1, a))
                let b = min(255, Int(rgba[p + 2]) * 255 / max(1, a))
                let br = ((r + hr) / 2) * a / 255
                let bg = ((g + hg) / 2) * a / 255
                let bb = ((b + hb) / 2) * a / 255
                rgba[p] = UInt8(br)
                rgba[p + 1] = UInt8(bg)
                rgba[p + 2] = UInt8(bb)
            }
        }
        return ctx.makeImage() ?? image
    }

    // MARK: - PE Resource Parser

    private static func parsePEBulbLibrary(
        data: Data, lfanew: Int, fallbackTitle: String, sourceURL: URL,
        preferredSize: Int, highlightRGB: (UInt8, UInt8, UInt8)
    ) -> LoadedBulbIcons? {
        let numSec = Int(readU16(data, lfanew + 6))
        let optSize = Int(readU16(data, lfanew + 20))
        let optOff = lfanew + 24
        guard optOff + optSize <= data.count else { return nil }
        let rsrcRVA = Int(readU32(data, optOff + 96 + 2 * 8))
        guard rsrcRVA > 0 else { return nil }

        let secBase = optOff + optSize
        var sections: [PESection] = []
        for i in 0..<numSec {
            let o = secBase + i * 40
            guard o + 40 <= data.count else { break }
            let vsz = Int(readU32(data, o + 8))
            let va = Int(readU32(data, o + 12))
            let rsz = Int(readU32(data, o + 16))
            let rp = Int(readU32(data, o + 20))
            sections.append(PESection(virtualAddress: va, virtualSize: max(vsz, rsz), rawOffset: rp, rawSize: rsz))
        }

        func rvaToOff(_ rva: Int) -> Int? {
            for s in sections {
                if rva >= s.virtualAddress && rva < s.virtualAddress + max(s.rawSize, s.virtualSize) {
                    let off = s.rawOffset + (rva - s.virtualAddress)
                    return (off >= 0 && off < data.count) ? off : nil
                }
            }
            return nil
        }

        guard let rsrcRootOff = rvaToOff(rsrcRVA) else { return nil }

        struct RawResEntry { let typeID: Int; let nameID: Int; let data: Data }
        var entries: [RawResEntry] = []

        func walkDir(relOff: Int, level: Int, curType: Int, curName: Int) {
            let base = rsrcRootOff + relOff
            guard base + 16 <= data.count else { return }
            let nNamed = Int(readU16(data, base + 12))
            let nIDs = Int(readU16(data, base + 14))
            let total = nNamed + nIDs
            for i in 0..<total {
                let eo = base + 16 + i * 8
                guard eo + 8 <= data.count else { break }
                let nameOrId = Int(readU32(data, eo))
                let offToData = Int(readU32(data, eo + 4))
                let isDir = (offToData & 0x8000_0000) != 0
                let nextRel = offToData & 0x7FFF_FFFF
                let idVal = (nameOrId & 0x8000_0000) != 0 ? -1 : nameOrId

                if isDir {
                    walkDir(relOff: nextRel, level: level + 1,
                            curType: level == 0 ? idVal : curType,
                            curName: level == 1 ? idVal : curName)
                } else {
                    let deOff = rsrcRootOff + nextRel
                    guard deOff + 16 <= data.count else { continue }
                    let dataRVA = Int(readU32(data, deOff))
                    let dataSz = Int(readU32(data, deOff + 4))
                    if let rawOff = rvaToOff(dataRVA), rawOff + dataSz <= data.count {
                        entries.append(RawResEntry(
                            typeID: curType,
                            nameID: level == 1 ? idVal : curName,
                            data: data.subdata(in: rawOff..<(rawOff + dataSz))
                        ))
                    }
                }
            }
        }
        walkDir(relOff: 0, level: 0, curType: -1, curName: -1)

        var strings: [Int: String] = [:]
        var iconByID: [Int: Data] = [:]
        var groupIcons: [Int: Data] = [:]
        var bitmaps: [Int: Data] = [:]

        for e in entries {
            switch e.typeID {
            case 6: // RT_STRING
                parseStringTableBlock(blockID: e.nameID, data: e.data, into: &strings)
            case 3: // RT_ICON
                iconByID[e.nameID] = e.data
            case 14: // RT_GROUP_ICON
                groupIcons[e.nameID] = e.data
            case 2: // RT_BITMAP
                bitmaps[e.nameID] = e.data
            default:
                break
            }
        }

        let title = strings[5001]?.nilIfEmpty ?? fallbackTitle
        let meta = BulbSetMetadata(
            id: fallbackTitle,
            title: title,
            author: strings[5000]?.nilIfEmpty ?? "Barefoot Productions",
            version: strings[5002]?.nilIfEmpty ?? "6.0",
            comment: strings[5003] ?? "",
            creationDate: strings[5004] ?? "",
            email: strings[5005] ?? "",
            webPage: strings[5006] ?? "",
            isMonochrome: strings[5010] == "1",
            isBitmap: strings[5012] == "1",
            isOnOnly: strings[5014] == "1",
            sourceURL: sourceURL
        )

        func decodeIconResource(groupID: Int) -> CGImage? {
            guard let g = groupIcons[groupID], g.count >= 6 else { return nil }
            let count = Int(readU16(g, 4))
            var candidates: [(w: Int, bpp: Int, nID: Int)] = []
            for i in 0..<count {
                let eo = 6 + i * 14
                guard eo + 14 <= g.count else { break }
                let w = g[eo] == 0 ? 256 : Int(g[eo])
                let bpp = Int(readU16(g, eo + 6))
                let nID = Int(readU16(g, eo + 12))
                candidates.append((w, bpp, nID))
            }
            // Prefer exact preferredSize or 32px with highest bpp
            let chosen = candidates.sorted { a, b in
                let aMatch = a.w == preferredSize ? 2 : (a.w == 32 ? 1 : 0)
                let bMatch = b.w == preferredSize ? 2 : (b.w == 32 ? 1 : 0)
                if aMatch != bMatch { return aMatch > bMatch }
                return a.bpp > b.bpp
            }.first
            guard let c = chosen, let dib = iconByID[c.nID] else { return nil }
            return decodeDIB(data: dib, isIcon: true, blackTransparent: false)
        }

        func decodeRes(_ id: Int) -> CGImage? {
            if meta.isBitmap, let bmp = bitmaps[id] {
                return decodeDIB(data: bmp, isIcon: false, blackTransparent: true)
            }
            if let ico = decodeIconResource(groupID: id) {
                return ico
            }
            if let bmp = bitmaps[id] {
                return decodeDIB(data: bmp, isIcon: false, blackTransparent: meta.isBitmap)
            }
            return nil
        }

        var loaded = LoadedBulbIcons(
            metadata: meta,
            sample: decodeRes(6000),
            bareWire: decodeRes(6001)
        )

        if groupIcons.isEmpty && !iconByID.isEmpty && bitmaps.isEmpty {
            // PE .icl style
            let sortedIDs = iconByID.keys.sorted()
            for (idx, iconID) in sortedIDs.enumerated() where idx < 7 {
                if let dib = iconByID[iconID], let img = decodeDIB(data: dib, isIcon: true, blackTransparent: false) {
                    loaded.onImages[idx] = img
                    loaded.offImages[idx] = blendHalfWithHighlight(image: img, rgb: highlightRGB)
                }
            }
            return loaded
        }

        let maxColors = meta.isMonochrome ? 1 : 7
        for c in 0..<maxColors {
            let onID = 7001 + c * 10
            let offID = 7000 + c * 10
            let brkID = 7002 + c * 10

            let onImg = decodeRes(onID)
            var offImg = meta.isOnOnly ? nil : decodeRes(offID)
            if offImg == nil, let onImg {
                offImg = blendHalfWithHighlight(image: onImg, rgb: highlightRGB)
            }
            loaded.onImages[c] = onImg
            loaded.offImages[c] = offImg
            loaded.brokenImages[c] = decodeRes(brkID)
        }

        if meta.isMonochrome, let monoOn = loaded.onImages[0] {
            let monoOff = loaded.offImages[0]
            let monoBrk = loaded.brokenImages[0]
            for c in 1..<7 {
                loaded.onImages[c] = monoOn
                loaded.offImages[c] = monoOff
                loaded.brokenImages[c] = monoBrk
            }
        }
        return loaded
    }

    // MARK: - 16-bit NE Icon Library Parser (e.g. Big Bulbs.icl)

    private static func parseNEIconLibrary(
        data: Data, neOff: Int, fallbackTitle: String, sourceURL: URL,
        preferredSize: Int, highlightRGB: (UInt8, UInt8, UInt8)
    ) -> LoadedBulbIcons? {
        let rtabRel = Int(readU16(data, neOff + 0x24))
        let rtabOff = neOff + rtabRel
        guard rtabOff + 4 <= data.count else { return nil }
        let alignShift = Int(readU16(data, rtabOff))
        var pos = rtabOff + 2

        var iconDIBs: [(w: Int, bpp: Int, data: Data)] = []
        var posGuard = 0
        while pos + 8 <= data.count && posGuard < 256 {
            posGuard += 1
            let typeID = Int(readU16(data, pos))
            if typeID == 0 { break }
            let count = Int(readU16(data, pos + 2))
            pos += 8
            let isIcon = (typeID == 0x8003)
            for _ in 0..<count {
                guard pos + 12 <= data.count else { break }
                let offset = Int(readU16(data, pos)) << alignShift
                let length = Int(readU16(data, pos + 2)) << alignShift
                pos += 12
                if isIcon, offset + length <= data.count, length >= 40 {
                    let sub = data.subdata(in: offset..<(offset + length))
                    let w = Int(Int32(bitPattern: readU32(sub, 4)))
                    let bpp = Int(readU16(sub, 14))
                    iconDIBs.append((w, bpp, sub))
                }
            }
        }
        guard !iconDIBs.isEmpty else { return nil }
        // Group consecutive 32x32+highest-bpp icons cleanly
        let filtered = iconDIBs.filter { $0.w == 32 }
        let pickList = filtered.isEmpty ? iconDIBs : filtered
        var onMap: [Int: CGImage] = [:]
        var offMap: [Int: CGImage] = [:]
        var seenSizes = 0
        var lastBppUsed = Set<Int>()
        for (i, item) in pickList.enumerated() {
            if seenSizes >= 7 { break }
            if let img = decodeDIB(data: item.data, isIcon: true, blackTransparent: false) {
                // In NE ICL each icon slot may have 2 bitdepths; keep distinct slot index cleanly
                let slot = min(6, seenSizes)
                if item.bpp >= 8 || !lastBppUsed.contains(i / 2) {
                    onMap[slot] = img
                    offMap[slot] = blendHalfWithHighlight(image: img, rgb: highlightRGB)
                    if item.bpp >= 8 { lastBppUsed.insert(i / 2); seenSizes += 1 }
                }
            }
        }
        if onMap.isEmpty {
            for (i, item) in pickList.prefix(7).enumerated() {
                if let img = decodeDIB(data: item.data, isIcon: true, blackTransparent: false) {
                    onMap[i] = img
                    offMap[i] = blendHalfWithHighlight(image: img, rgb: highlightRGB)
                }
            }
        }
        let meta = BulbSetMetadata(id: fallbackTitle, title: fallbackTitle, isOnOnly: true, sourceURL: sourceURL)
        return LoadedBulbIcons(metadata: meta, sample: onMap[0], bareWire: nil, onImages: onMap, offImages: offMap, brokenImages: [:])
    }

    // MARK: - Standalone .ico & DIB Decoder

    private static func parseStandaloneICO(data: Data, preferredSize: Int) -> CGImage? {
        guard data.count >= 6, readU16(data, 0) == 0, readU16(data, 2) == 1 else { return nil }
        let count = Int(readU16(data, 4))
        var bestEntry: (score: Int, offset: Int, size: Int)?
        for i in 0..<count {
            let eo = 6 + i * 16
            guard eo + 16 <= data.count else { break }
            let w = data[eo] == 0 ? 256 : Int(data[eo])
            let bpp = Int(readU16(data, eo + 6))
            let sz = Int(readU32(data, eo + 8))
            let off = Int(readU32(data, eo + 12))
            let score = (w == preferredSize ? 1000 : (w == 32 ? 500 : 0)) + bpp
            if bestEntry == nil || score > bestEntry!.score {
                bestEntry = (score, off, sz)
            }
        }
        guard let e = bestEntry, e.offset + e.size <= data.count else { return nil }
        let sub = data.subdata(in: e.offset..<(e.offset + e.size))
        if sub.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            if let dp = CGDataProvider(data: sub as CFData),
               let png = CGImage(pngDataProviderSource: dp, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
                return png
            }
        }
        return decodeDIB(data: sub, isIcon: true, blackTransparent: false)
    }

    static func decodeDIB(data: Data, isIcon: Bool, blackTransparent: Bool) -> CGImage? {
        guard data.count >= 40 else { return nil }
        let biSize = Int(readU32(data, 0))
        guard biSize >= 40, biSize <= data.count else { return nil }
        let width = Int(Int32(bitPattern: readU32(data, 4)))
        let rawH = Int(Int32(bitPattern: readU32(data, 8)))
        let bpp = Int(readU16(data, 14))
        let compression = Int(readU32(data, 16))
        let clrUsed = Int(readU32(data, 32))
        guard width > 0, width <= 512, compression == 0 else { return nil }

        let height = isIcon ? abs(rawH) / 2 : abs(rawH)
        guard height > 0, height <= 512 else { return nil }
        let topDown = rawH < 0

        let paletteEntries = bpp <= 8 ? (clrUsed > 0 ? clrUsed : (1 << bpp)) : 0
        let palOff = biSize
        let xorOff = palOff + paletteEntries * 4
        let rowStride = (((width * bpp + 31) / 32) * 4)
        let xorSize = rowStride * height
        guard xorOff + xorSize <= data.count else { return nil }

        var palette: [(UInt8, UInt8, UInt8)] = []
        for i in 0..<paletteEntries {
            let o = palOff + i * 4
            if o + 4 <= data.count {
                palette.append((data[o + 2], data[o + 1], data[o]))
            }
        }

        let andOff = xorOff + xorSize
        let andStride = (((width + 31) / 32) * 4)
        let hasAndMask = isIcon && (andOff + andStride * height <= data.count)

        var hasNonZeroAlpha32 = false
        if bpp == 32 {
            for y in 0..<height {
                for x in 0..<width {
                    if data[xorOff + y * rowStride + x * 4 + 3] != 0 {
                        hasNonZeroAlpha32 = true
                        break
                    }
                }
                if hasNonZeroAlpha32 { break }
            }
        }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let srcY = topDown ? y : (height - 1 - y)
            let rowPtr = xorOff + srcY * rowStride
            let maskRowPtr = andOff + srcY * andStride
            for x in 0..<width {
                var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0, a: UInt8 = 255
                switch bpp {
                case 32:
                    let p = rowPtr + x * 4
                    b = data[p]; g = data[p + 1]; r = data[p + 2]
                    a = hasNonZeroAlpha32 ? data[p + 3] : 255
                case 24:
                    let p = rowPtr + x * 3
                    b = data[p]; g = data[p + 1]; r = data[p + 2]
                case 8:
                    let idx = Int(data[rowPtr + x])
                    if idx < palette.count { (r, g, b) = palette[idx] }
                case 4:
                    let byteVal = Int(data[rowPtr + (x >> 1)])
                    let idx = (x & 1 == 0) ? (byteVal >> 4) : (byteVal & 0x0F)
                    if idx < palette.count { (r, g, b) = palette[idx] }
                case 1:
                    let byteVal = Int(data[rowPtr + (x >> 3)])
                    let idx = (byteVal >> (7 - (x & 7))) & 1
                    if idx < palette.count { (r, g, b) = palette[idx] } else { let v: UInt8 = idx == 1 ? 255 : 0; r = v; g = v; b = v }
                default:
                    return nil
                }

                if isIcon && hasAndMask && !(bpp == 32 && hasNonZeroAlpha32) {
                    let mByte = Int(data[maskRowPtr + (x >> 3)])
                    let mBit = (mByte >> (7 - (x & 7))) & 1
                    if mBit == 1 { a = 0 }
                } else if blackTransparent && r == 0 && g == 0 && b == 0 {
                    a = 0
                }

                let dst = (y * width + x) * 4
                // Store straight->premultiplied for CGImage(premultipliedLast)
                let af = Int(a)
                rgba[dst] = UInt8(Int(r) * af / 255)
                rgba[dst + 1] = UInt8(Int(g) * af / 255)
                rgba[dst + 2] = UInt8(Int(b) * af / 255)
                rgba[dst + 3] = a
            }
        }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    private static func parseStringTableBlock(blockID: Int, data: Data, into dict: inout [Int: String]) {
        guard blockID >= 1 else { return }
        let baseID = (blockID - 1) * 16
        var off = 0
        for i in 0..<16 {
            guard off + 2 <= data.count else { break }
            let charCount = Int(readU16(data, off))
            off += 2
            let byteCount = charCount * 2
            guard off + byteCount <= data.count else { break }
            if charCount > 0 {
                let sub = data.subdata(in: off..<(off + byteCount))
                if let s = String(data: sub, encoding: .utf16LittleEndian) {
                    dict[baseID + i] = s
                }
            }
            off += byteCount
        }
    }

    private static func readU16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
