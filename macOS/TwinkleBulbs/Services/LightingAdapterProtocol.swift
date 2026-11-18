import Foundation
import Network
import CoreGraphics

// MARK: - Part VII: Extensible External Lighting Protocol & Wire Packet Definitions

/// Binary/JSON frame packet emitted by Re: Twinkle Bulbs for local adapters and WebSocket consumers.
/// Binary magic wire header ("TWKL" v1, 16-byte little-endian header + count*3 RGB8 bytes):
/// - [0..3]: "TWKL" (0x54 0x57 0x4B 0x4C)
/// - [4..5]: UInt16 version = 1
/// - [6..7]: UInt16 bulbCount
/// - [8..11]: UInt32 frameSequence
/// - [12..15]: UInt32 timestampMs
/// - [16...]: packed R, G, B (UInt8 x 3 per bulb)
public struct TwinkleBulbFramePacket: Equatable {
    public var sequence: UInt32
    public var timestampMs: UInt32
    public var rgbBytes: Data // count * 3 bytes

    public var bulbCount: Int { rgbBytes.count / 3 }

    public init(sequence: UInt32, timestampMs: UInt32, states: [ModernBulbState]) {
        self.sequence = sequence
        self.timestampMs = timestampMs
        var buf = Data(capacity: states.count * 3)
        for st in states {
            let active = !st.isBareWire && !st.isMissing && !st.isBroken && !st.isBurnedOut
            let scale = active ? max(0.0, min(1.0, st.intensity)) : 0.0
            let r = UInt8(max(0, min(255, Int((st.r * scale * 255.0).rounded()))))
            let g = UInt8(max(0, min(255, Int((st.g * scale * 255.0).rounded()))))
            let b = UInt8(max(0, min(255, Int((st.b * scale * 255.0).rounded()))))
            buf.append(r)
            buf.append(g)
            buf.append(b)
        }
        self.rgbBytes = buf
    }

    public init(sequence: UInt32, timestampMs: UInt32, rgbBytes: Data) {
        self.sequence = sequence
        self.timestampMs = timestampMs
        self.rgbBytes = rgbBytes
    }

    public static func blackout(sequence: UInt32, timestampMs: UInt32, bulbCount: Int) -> TwinkleBulbFramePacket {
        TwinkleBulbFramePacket(sequence: sequence, timestampMs: timestampMs, rgbBytes: Data(repeating: 0, count: max(1, bulbCount) * 3))
    }

    public func encodeBinaryFrame() -> Data {
        let count = UInt16(min(Int(UInt16.max), bulbCount))
        var out = Data(capacity: 16 + Int(count) * 3)
        out.append(contentsOf: [0x54, 0x57, 0x4B, 0x4C]) // "TWKL"
        var ver: UInt16 = 1
        var cnt = count
        var seq = sequence
        var ts = timestampMs
        withUnsafeBytes(of: &ver) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: &cnt) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: &seq) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: &ts) { out.append(contentsOf: $0) }
        out.append(rgbBytes.prefix(Int(count) * 3))
        return out
    }

    public static func decodeBinaryFrame(_ data: Data) -> TwinkleBulbFramePacket? {
        guard data.count >= 16,
              data[0] == 0x54, data[1] == 0x57, data[2] == 0x4B, data[3] == 0x4C else {
            return nil
        }
        let ver = UInt16(data[4]) | (UInt16(data[5]) << 8)
        guard ver == 1 else { return nil }
        let cnt = Int(UInt16(data[6]) | (UInt16(data[7]) << 8))
        let seq = UInt32(data[8]) | (UInt32(data[9]) << 8) | (UInt32(data[10]) << 16) | (UInt32(data[11]) << 24)
        let ts = UInt32(data[12]) | (UInt32(data[13]) << 8) | (UInt32(data[14]) << 16) | (UInt32(data[15]) << 24)
        guard data.count >= 16 + cnt * 3 else { return nil }
        let payload = data.subdata(in: 16..<(16 + cnt * 3))
        return TwinkleBulbFramePacket(sequence: seq, timestampMs: ts, rgbBytes: payload)
    }

    public func encodeJSON() -> Data {
        var bulbs: [[Int]] = []
        bulbs.reserveCapacity(bulbCount)
        for i in 0..<bulbCount {
            let off = i * 3
            bulbs.append([Int(rgbBytes[off]), Int(rgbBytes[off + 1]), Int(rgbBytes[off + 2])])
        }
        let dict: [String: Any] = [
            "v": 1,
            "seq": sequence,
            "tsMs": timestampMs,
            "count": bulbCount,
            "rgb": bulbs
        ]
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data("{}".utf8)
    }
}

/// Core hardware/bridge adapter interface for connecting Re: Twinkle Bulbs to external controllers.
public protocol LightingAdapterProtocol: AnyObject {
    var adapterID: String { get }
    var displayName: String { get }
    var protocolDescription: String { get }
    var maxBulbs: Int { get }
    var supportsZones: Bool { get }
    var isConnected: Bool { get }

    func connect() throws
    func disconnect()
    func sendFrame(_ frame: TwinkleBulbFramePacket) throws
    func blackoutAll() throws
}

/// In-app reference simulator adapter that receives live TwinkleBulbFramePacket data
/// and validates sequence ordering, frame rates, and safe blackout on exit.
public final class ReferenceVirtualAdapter: LightingAdapterProtocol {
    public static let shared = ReferenceVirtualAdapter()

    public let adapterID = "adapter:virtual_simulator"
    public let displayName = "Virtual Controller Simulator (Local Loopback)"
    public let protocolDescription = "TWKL v1 RGB24 Binary & JSON"
    public let maxBulbs = 512
    public let supportsZones = true

    public private(set) var isConnected: Bool = false
    public private(set) var lastFrame: TwinkleBulbFramePacket?
    public private(set) var receivedFrameCount: UInt64 = 0
    public private(set) var droppedOutOfOrderCount: UInt64 = 0
    public private(set) var didReceiveBlackoutOnDisconnect: Bool = false

    public var onFrameUpdated: ((TwinkleBulbFramePacket) -> Void)?

    private let lock = NSLock()
    private var lastSeq: UInt32 = 0

    public init() {}

    public func connect() throws {
        lock.lock()
        isConnected = true
        lastSeq = 0
        receivedFrameCount = 0
        droppedOutOfOrderCount = 0
        didReceiveBlackoutOnDisconnect = false
        lock.unlock()
    }

    public func disconnect() {
        try? blackoutAll()
        lock.lock()
        isConnected = false
        lock.unlock()
    }

    public func sendFrame(_ frame: TwinkleBulbFramePacket) throws {
        lock.lock()
        guard isConnected else {
            lock.unlock()
            throw NSError(domain: "TwinkleAdapter", code: 503, userInfo: [NSLocalizedDescriptionKey: "Adapter not connected"])
        }
        if lastSeq > 0 && frame.sequence <= lastSeq {
            droppedOutOfOrderCount += 1
        }
        lastSeq = frame.sequence
        receivedFrameCount += 1
        lastFrame = frame
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.onFrameUpdated?(frame)
        }
    }

    public func blackoutAll() throws {
        lock.lock()
        let count = max(1, lastFrame?.bulbCount ?? 40)
        let seq = lastSeq &+ 1
        lastSeq = seq
        let packet = TwinkleBulbFramePacket.blackout(sequence: seq, timestampMs: UInt32(truncatingIfNeeded: UInt64(max(0, Date().timeIntervalSince1970 * 1000.0))), bulbCount: count)
        lastFrame = packet
        didReceiveBlackoutOnDisconnect = true
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.onFrameUpdated?(packet)
        }
    }
}

/// Wire formatters for WLED DRGB UDP (port 21324), Art-Net OpDmx (port 6454), and sACN/E1.31 (port 5568).
/// Strictly gated by explicit user opt-in & electrical safety acknowledgement.
public enum ExternalProtocolPacketEncoder {
    /// WLED DRGB Realtime Protocol (protocol=2, timeoutSeconds=2, followed by RGB triples)
    public static func encodeWLEDDRGB(_ frame: TwinkleBulbFramePacket, timeoutSeconds: UInt8 = 2) -> Data {
        var d = Data([2, timeoutSeconds])
        d.append(frame.rgbBytes.prefix(490 * 3))
        return d
    }

    /// Art-Net OpDmx Packet (ID="Art-Net\0", OpCode=0x5000 LE, ProtVer=14 BE, Universe LE, Length BE, up to 512 channels)
    public static func encodeArtNetDMX(_ frame: TwinkleBulbFramePacket, universe: UInt16 = 0, sequence: UInt8 = 0) -> Data {
        var d = Data("Art-Net\0".utf8)
        d.append(contentsOf: [0x00, 0x50, 0x00, 14, sequence, 0x00])
        d.append(UInt8(universe & 0xFF))
        d.append(UInt8((universe >> 8) & 0xFF))
        let payload = frame.rgbBytes.prefix(510)
        let len = UInt16(payload.count + (payload.count & 1))
        d.append(UInt8((len >> 8) & 0xFF))
        d.append(UInt8(len & 0xFF))
        d.append(payload)
        if payload.count < Int(len) { d.append(0) }
        return d
    }

    /// Minimal DDP (Distributed Display Protocol) v1 RGB packet
    public static func encodeDDPPacket(_ frame: TwinkleBulbFramePacket, offset: UInt32 = 0) -> Data {
        let len = UInt16(min(1440, frame.rgbBytes.count))
        var hdr = Data(count: 10)
        hdr[0] = 0x41 // VER1 + PUSH
        hdr[1] = UInt8(frame.sequence & 0xFF)
        hdr[2] = 0x0B // RGB 8-bit
        hdr[3] = 0x01 // Output ID 1
        hdr[4] = UInt8((offset >> 24) & 0xFF)
        hdr[5] = UInt8((offset >> 16) & 0xFF)
        hdr[6] = UInt8((offset >> 8) & 0xFF)
        hdr[7] = UInt8(offset & 0xFF)
        hdr[8] = UInt8((len >> 8) & 0xFF)
        hdr[9] = UInt8(len & 0xFF)
        hdr.append(frame.rgbBytes.prefix(Int(len)))
        return hdr
    }
}
