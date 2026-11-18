import Foundation
import CryptoKit

// MARK: - Part XI: Portable Security-Validated Theme & Effect Packages (.twinklepack)

public enum ThemePackError: LocalizedError, Equatable {
    case invalidArchive(String)
    case unsafeEntryPath(String)
    case symlinkRejected(String)
    case sizeLimitExceeded(String)
    case missingManifest
    case unsupportedVersion(Int)
    case hashMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArchive(let m): return "Invalid .twinklepack archive: \(m)"
        case .unsafeEntryPath(let p): return "Rejected unsafe path in package: \(p)"
        case .symlinkRejected(let p): return "Rejected symbolic link in package: \(p)"
        case .sizeLimitExceeded(let m): return "Package exceeds safe size limits: \(m)"
        case .missingManifest: return "Missing manifest.json in .twinklepack."
        case .unsupportedVersion(let v): return "Unsupported formatVersion \(v)."
        case .hashMismatch(let f): return "SHA-256 verification failed for \(f)."
        }
    }
}

/// Pure-Swift Store-method ZIP packager & strict security verifier for `.twinklepack` bundles.
/// Never unpacks outside memory/safe staging, never executes code, and verifies SHA-256 hashes.
public final class ThemePackManager {
    public static let shared = ThemePackManager()

    public static let maxEntries = 64
    public static let maxSingleEntryBytes = 4 * 1024 * 1024
    public static let maxTotalPackageBytes = 16 * 1024 * 1024

    public init() {}

    public func createThemePackArchive(
        packageID: String,
        title: String,
        author: String,
        scenes: [HolidayScene] = [],
        timelines: [TimelineEffectDocument] = [],
        layouts: [VirtualLayoutDocument] = []
    ) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]

        var files: [(name: String, data: Data)] = []
        var hashes: [String: String] = [:]

        for (i, sc) in scenes.enumerated() {
            let fn = "scenes/scene_\(i).json"
            let d = try enc.encode(sc)
            files.append((fn, d))
            hashes[fn] = sha256Hex(d)
        }
        for (i, tl) in timelines.enumerated() {
            let fn = "timelines/timeline_\(i).twinklefx"
            let d = try enc.encode(tl)
            files.append((fn, d))
            hashes[fn] = sha256Hex(d)
        }
        for (i, lay) in layouts.enumerated() {
            let fn = "layouts/layout_\(i).twinklelayout"
            let d = try enc.encode(lay)
            files.append((fn, d))
            hashes[fn] = sha256Hex(d)
        }

        var manifest = ThemePackManifest(packageID: packageID, title: title, author: author)
        manifest.scenes = scenes
        manifest.timelines = timelines
        manifest.layouts = layouts
        manifest.contentHashes = hashes
        let manifestData = try enc.encode(manifest)
        files.insert(("manifest.json", manifestData), at: 0)

        return try buildStoreZIP(entries: files)
    }

    public func validateAndInspectPack(data: Data) throws -> ThemePackManifest {
        guard data.count <= Self.maxTotalPackageBytes else {
            throw ThemePackError.sizeLimitExceeded("Archive exceeds \(Self.maxTotalPackageBytes) bytes")
        }
        let entries = try parseAndValidateStoreZIP(data: data)
        guard let manifestData = entries["manifest.json"] else {
            throw ThemePackError.missingManifest
        }
        let manifest = try JSONDecoder().decode(ThemePackManifest.self, from: manifestData)
        guard manifest.formatVersion <= 1 else {
            throw ThemePackError.unsupportedVersion(manifest.formatVersion)
        }
        // Verify SHA-256 digests of every hashed payload file
        for (relPath, expectedDigest) in manifest.contentHashes {
            try validateSafeRelativePath(relPath)
            guard let entryData = entries[relPath] else {
                throw ThemePackError.hashMismatch("\(relPath) (missing entry)")
            }
            if sha256Hex(entryData).lowercased() != expectedDigest.lowercased() {
                throw ThemePackError.hashMismatch(relPath)
            }
        }
        return manifest
    }

    public func importPackIntoStateStore(data: Data, stateStore: NextGenStateStore = .shared, sceneManager: HolidaySceneManager = .shared) throws -> ThemePackManifest {
        let manifest = try validateAndInspectPack(data: data)
        for sc in manifest.scenes {
            var copy = sc
            copy.isBuiltIn = false
            _ = sceneManager.saveUserScene(copy)
        }
        var next = stateStore.state
        for tl in manifest.timelines {
            if !next.timelines.contains(where: { $0.id == tl.id }) {
                next.timelines.append(tl)
            }
        }
        for lay in manifest.layouts {
            if !next.layouts.contains(where: { $0.id == lay.id }) {
                next.layouts.append(lay)
            }
        }
        stateStore.state = next
        return manifest
    }

    // MARK: - Path & Security Helpers

    public func validateSafeRelativePath(_ path: String) throws {
        if path.isEmpty || path.hasPrefix("/") || path.hasPrefix("\\") || path.contains("\\") {
            throw ThemePackError.unsafeEntryPath(path)
        }
        let comps = path.split(separator: "/", omittingEmptySubsequences: false)
        for c in comps {
            if c == ".." || c == "." || c.isEmpty {
                throw ThemePackError.unsafeEntryPath(path)
            }
        }
        // Never allow executable scripts or native libraries inside theme packs
        let lower = path.lowercased()
        let forbidden = [".sh", ".py", ".rb", ".js", ".scpt", ".dylib", ".app", ".command", ".exe"]
        if forbidden.contains(where: { lower.hasSuffix($0) }) {
            throw ThemePackError.unsafeEntryPath("Executable/script file forbidden: \(path)")
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Pure-Swift Validated ZIP Store Writer/Reader

    public func buildStoreZIP(entries: [(name: String, data: Data)]) throws -> Data {
        struct CDR {
            let nameData: Data
            let crc: UInt32
            let size: UInt32
            let offset: UInt32
        }
        var out = Data()
        var centralDirs: [CDR] = []

        for entry in entries {
            try validateSafeRelativePath(entry.name)
            let nameData = Data(entry.name.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let localOffset = UInt32(out.count)

            out.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Local file header signature
            appendU16(&out, 20) // version needed
            appendU16(&out, 0x0800) // UTF-8 filename flag
            appendU16(&out, 0)  // store method 0
            appendU16(&out, 0)
            appendU16(&out, 0x5421)
            appendU32(&out, crc)
            appendU32(&out, size)
            appendU32(&out, size)
            appendU16(&out, UInt16(nameData.count))
            appendU16(&out, 0) // extra len
            out.append(nameData)
            out.append(entry.data)

            centralDirs.append(CDR(nameData: nameData, crc: crc, size: size, offset: localOffset))
        }

        let cdOffset = UInt32(out.count)
        for c in centralDirs {
            out.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            appendU16(&out, (3 << 8) | 20) // UNIX + ver 2.0
            appendU16(&out, 20)
            appendU16(&out, 0x0800)
            appendU16(&out, 0)
            appendU16(&out, 0)
            appendU16(&out, 0x5421)
            appendU32(&out, c.crc)
            appendU32(&out, c.size)
            appendU32(&out, c.size)
            appendU16(&out, UInt16(c.nameData.count))
            appendU16(&out, 0)
            appendU16(&out, 0)
            appendU16(&out, 0)
            appendU16(&out, 0)
            appendU32(&out, 0o100644 << 16) // regular file mode
            appendU32(&out, c.offset)
            out.append(c.nameData)
        }
        let cdSize = UInt32(out.count) - cdOffset
        out.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // EOCD
        appendU16(&out, 0); appendU16(&out, 0)
        appendU16(&out, UInt16(centralDirs.count))
        appendU16(&out, UInt16(centralDirs.count))
        appendU32(&out, cdSize)
        appendU32(&out, cdOffset)
        appendU16(&out, 0)
        return out
    }

    public func parseAndValidateStoreZIP(data: Data) throws -> [String: Data] {
        // Locate End of Central Directory (0x06054b50)
        var eocdPos: Int? = nil
        let minScan = max(0, data.count - 65557)
        if data.count >= 22 {
            for pos in stride(from: data.count - 22, through: minScan, by: -1) {
                if data[pos] == 0x50 && data[pos + 1] == 0x4B && data[pos + 2] == 0x05 && data[pos + 3] == 0x06 {
                    eocdPos = pos; break
                }
            }
        }
        guard let eocd = eocdPos else {
            throw ThemePackError.invalidArchive("Missing ZIP End of Central Directory")
        }

        let totalEntries = Int(readU16(data, eocd + 10))
        let cdSize = Int(readU32(data, eocd + 12))
        let cdOffset = Int(readU32(data, eocd + 16))
        guard totalEntries <= Self.maxEntries else {
            throw ThemePackError.sizeLimitExceeded("Entry count \(totalEntries) > \(Self.maxEntries)")
        }
        guard cdOffset >= 0, cdSize >= 0, cdOffset + cdSize <= data.count else {
            throw ThemePackError.invalidArchive("Corrupt Central Directory bounds")
        }

        var result: [String: Data] = [:]
        var totalDecoded = 0
        var p = cdOffset
        for _ in 0..<totalEntries {
            guard p + 46 <= data.count,
                  data[p] == 0x50, data[p + 1] == 0x4B, data[p + 2] == 0x01, data[p + 3] == 0x02 else {
                throw ThemePackError.invalidArchive("Corrupt Central Directory header")
            }
            let method = readU16(data, p + 10)
            let compSize = Int(readU32(data, p + 20))
            let uncompSize = Int(readU32(data, p + 24))
            let nameLen = Int(readU16(data, p + 28))
            let extraLen = Int(readU16(data, p + 30))
            let commentLen = Int(readU16(data, p + 32))
            let extAttrs = readU32(data, p + 38)
            let localOff = Int(readU32(data, p + 42))

            guard p + 46 + nameLen + extraLen + commentLen <= data.count else {
                throw ThemePackError.invalidArchive("Truncated Central Directory entry")
            }
            let nameData = data.subdata(in: (p + 46)..<(p + 46 + nameLen))
            let entryName = String(data: nameData, encoding: .utf8) ?? ""
            p += 46 + nameLen + extraLen + commentLen

            // Reject UNIX symlinks (0xA000 >> 12 == 10)
            let unixFileType = (extAttrs >> 16) & 0xF000
            if unixFileType == 0xA000 {
                throw ThemePackError.symlinkRejected(entryName)
            }
            try validateSafeRelativePath(entryName)

            guard uncompSize <= Self.maxSingleEntryBytes, compSize <= Self.maxSingleEntryBytes else {
                throw ThemePackError.sizeLimitExceeded("Entry \(entryName) exceeds size cap")
            }
            // Also guard zip-bomb ratios & running total
            if compSize == 0 && uncompSize > 0 {
                throw ThemePackError.sizeLimitExceeded("Zero compressed bytes for non-empty \(entryName)")
            }
            totalDecoded += uncompSize
            guard totalDecoded <= Self.maxTotalPackageBytes else {
                throw ThemePackError.sizeLimitExceeded("Total unpacked bytes exceed limit")
            }
            guard method == 0, compSize == uncompSize else {
                throw ThemePackError.invalidArchive("Unsupported compression method on \(entryName)")
            }

            // Read Local Header & verify offset
            guard localOff + 30 <= data.count,
                  data[localOff] == 0x50, data[localOff + 1] == 0x4B, data[localOff + 2] == 0x03, data[localOff + 3] == 0x04 else {
                throw ThemePackError.invalidArchive("Corrupt local header for \(entryName)")
            }
            let lNameLen = Int(readU16(data, localOff + 26))
            let lExtraLen = Int(readU16(data, localOff + 28))
            let payloadStart = localOff + 30 + lNameLen + lExtraLen
            guard payloadStart + compSize <= data.count else {
                throw ThemePackError.invalidArchive("Truncated payload for \(entryName)")
            }
            result[entryName] = data.subdata(in: payloadStart..<(payloadStart + compSize))
        }
        return result
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : (crc >> 1)
            }
        }
        return ~crc
    }

    private func appendU16(_ d: inout Data, _ v: UInt16) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
    }

    private func appendU32(_ d: inout Data, _ v: UInt32) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
    }

    private func readU16(_ d: Data, _ o: Int) -> UInt16 {
        UInt16(d[o]) | (UInt16(d[o + 1]) << 8)
    }

    private func readU32(_ d: Data, _ o: Int) -> UInt32 {
        UInt32(d[o]) | (UInt32(d[o + 1]) << 8) | (UInt32(d[o + 2]) << 16) | (UInt32(d[o + 3]) << 24)
    }
}
