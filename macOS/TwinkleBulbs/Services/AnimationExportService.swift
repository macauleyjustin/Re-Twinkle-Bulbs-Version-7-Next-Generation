import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AVFoundation
import AppKit

// MARK: - Part XII: Animation Recording & Export (.gif, .mp4, .twinkleanim, .twinkleframes)

public struct ExportedFrameRecord: Codable {
    public var frameIndex: Int
    public var timestampSeconds: Double
    public var bulbs: [[Int]] // [r, g, b, intensity_0_255]
}

public struct TwinkleFramesExportDocument: Codable {
    public var formatVersion: Int = 1
    public var title: String
    public var fps: Double
    public var durationSeconds: Double
    public var bulbSet: String
    public var frames: [ExportedFrameRecord]
}

public final class AnimationExportService {
    public static let shared = AnimationExportService()

    public init() {}

    /// Renders deterministic frames straight from the production ModernLightingEngine / EffectTimelineEngine.
    public func renderFrames(
        settings: AppSettings,
        timeline: TimelineEffectDocument? = nil,
        width: Int = 640,
        height: Int = 96,
        fps: Double = 15.0,
        durationSeconds: Double = 3.0
    ) -> (images: [CGImage], frameData: TwinkleFramesExportDocument) {
        let totalFrames = max(2, Int((durationSeconds * fps).rounded()))
        let dt = 1.0 / max(1.0, fps)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)

        var renderSettings = settings
        renderSettings.lightsEnabled = true
        renderSettings.lightingCategory = .modern
        renderSettings.location = .top

        let engine = ModernLightingEngine(seed: 7772026)
        engine.configure(bounds: bounds, settings: renderSettings, nowMs: 0)
        let tlEngine = timeline.map { EffectTimelineEngine(document: $0) }

        var cgImages: [CGImage] = []
        var frameRecords: [ExportedFrameRecord] = []

        for idx in 0..<totalFrames {
            let t = Double(idx) * dt
            let states: [ModernBulbState]
            if let tl = tlEngine {
                states = tl.evaluateStates(atTimeSeconds: t, dt: dt, bounds: bounds, settings: renderSettings)
            } else {
                engine.stepDeterministic(dt: dt)
                states = engine.states
            }

            if let img = renderBulbFrameCGImage(width: width, height: height, states: states, settings: renderSettings) {
                cgImages.append(img)
            }
            let bulbTuples = states.map { st -> [Int] in
                [
                    Int((st.r * 255).rounded()),
                    Int((st.g * 255).rounded()),
                    Int((st.b * 255).rounded()),
                    Int((st.intensity * 255).rounded())
                ]
            }
            frameRecords.append(ExportedFrameRecord(frameIndex: idx, timestampSeconds: t, bulbs: bulbTuples))
        }

        let doc = TwinkleFramesExportDocument(
            title: timeline?.name ?? renderSettings.modernEffects.effect.displayName,
            fps: fps,
            durationSeconds: durationSeconds,
            bulbSet: renderSettings.bulbSetName,
            frames: frameRecords
        )
        return (cgImages, doc)
    }

    private func renderBulbFrameCGImage(width: Int, height: Int, states: [ModernBulbState], settings: AppSettings) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.setFillColor(NSColor(srgbRed: 0.04, green: 0.07, blue: 0.14, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        BulbCanvasView.drawModernStates(states, settings: settings, in: ctx)
        return ctx.makeImage()
    }

    /// Exports an Animated GIF directly using Apple ImageIO.
    public func exportGIF(images: [CGImage], fps: Double, to destinationURL: URL) throws {
        guard !images.isEmpty else {
            throw NSError(domain: "TwinkleExport", code: 400, userInfo: [NSLocalizedDescriptionKey: "No rendered frames"])
        }
        guard let dest = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.gif.identifier as CFString, images.count, nil) else {
            throw NSError(domain: "TwinkleExport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to create GIF writer"])
        }
        let gifFileProps: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]
        ]
        CGImageDestinationSetProperties(dest, gifFileProps as CFDictionary)
        let frameDelay = 1.0 / max(1.0, fps)
        let frameProps: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: frameDelay]
        ]
        for img in images {
            CGImageDestinationAddImage(dest, img, frameProps as CFDictionary)
        }
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "TwinkleExport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed finalizing GIF"])
        }
    }

    /// Exports an H.264 MP4 movie cleanly via AVAssetWriter.
    public func exportMP4(images: [CGImage], fps: Double, to destinationURL: URL) throws {
        guard let first = images.first else {
            throw NSError(domain: "TwinkleExport", code: 400, userInfo: [NSLocalizedDescriptionKey: "No rendered frames"])
        }
        try? FileManager.default.removeItem(at: destinationURL)
        let width = first.width
        let height = first.height

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptorAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: adaptorAttrs)
        guard writer.canAdd(input) else {
            throw NSError(domain: "TwinkleExport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Cannot attach H.264 video input"])
        }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let timescale: Int32 = 600
        let ticksPerFrame = Int64((Double(timescale) / max(1.0, fps)).rounded())

        for (i, img) in images.enumerated() {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            var pbOpt: CVPixelBuffer?
            CVPixelBufferCreate(
                kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB,
                [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
                &pbOpt
            )
            if let pb = pbOpt {
                CVPixelBufferLockBaseAddress(pb, [])
                if let ctx = CGContext(
                    data: CVPixelBufferGetBaseAddress(pb),
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                ) {
                    ctx.draw(img, in: CGRect(x: 0, y: 0, width: width, height: height))
                }
                CVPixelBufferUnlockBaseAddress(pb, [])
                let pts = CMTime(value: Int64(i) * ticksPerFrame, timescale: timescale)
                adaptor.append(pb, withPresentationTime: pts)
            }
        }
        input.markAsFinished()
        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()
        if let err = writer.error {
            throw err
        }
    }

    public func exportTwinkleFrames(_ doc: TwinkleFramesExportDocument, to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(doc).write(to: url, options: .atomic)
    }
}
