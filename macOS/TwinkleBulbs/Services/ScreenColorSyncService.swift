import Cocoa
import CoreGraphics
import ScreenCaptureKit

// MARK: - Part X: Ambient Screen Color Sync (Strictly Opt-In & Privacy-Preserving)

public final class ScreenColorSyncService {
    public static let shared = ScreenColorSyncService()

    public private(set) var isSyncActive: Bool = false
    public private(set) var smoothedColor: TimelineColorRGB = TimelineColorRGB(r: 1.0, g: 0.78, b: 0.45)
    public private(set) var lastStatusNote: String = "Stopped (Privacy Protected)"

    private var timer: Timer?
    private let store: NextGenStateStore

    public init(store: NextGenStateStore = .shared) {
        self.store = store
    }

    deinit {
        stopSync()
    }

    /// Requires explicit user action & privacy notice acknowledgement before sampling.
    @discardableResult
    public func startSyncIfAuthorized() -> Bool {
        let cfg = store.state.screenSync
        guard cfg.enabled, cfg.privacyNoticeAccepted else {
            stopSync()
            return false
        }

        // Check Screen Recording status silently without nagging at startup
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            lastStatusNote = "Awaiting macOS Screen Recording approval (using desktop backdrop fallback)"
        } else {
            lastStatusNote = "Active (Downsampled Dominant Color Only — Never Stored)"
        }

        isSyncActive = true
        timer?.invalidate()
        let interval = max(0.08, 1.0 / max(1.0, min(15.0, cfg.sampleRateHz)))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sampleTick()
        }
        return true
    }

    public func stopSync() {
        timer?.invalidate()
        timer = nil
        isSyncActive = false
        var next = store.state
        next.screenSync.enabled = false
        store.state = next
        lastStatusNote = "Stopped"
    }

    public func sampleTick() {
        let cfg = store.state.screenSync
        guard cfg.enabled, cfg.privacyNoticeAccepted else {
            stopSync()
            return
        }

        if CGPreflightScreenCaptureAccess(), #available(macOS 14.0, *) {
            Task.detached(priority: .utility) { [weak self] in
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    guard let disp = content.displays.first else { return }
                    let filter = SCContentFilter(display: disp, excludingWindows: [])
                    let sCfg = SCStreamConfiguration()
                    sCfg.width = 24
                    sCfg.height = 16
                    sCfg.showsCursor = false
                    let img = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: sCfg)
                    let sampled = Self.extractDominantColor(from: img)
                    let strongSelf = self
                    await MainActor.run {
                        strongSelf?.ingestSampledColor(sampled, smoothing: cfg.smoothing)
                    }
                } catch {
                    let strongSelf = self
                    await MainActor.run {
                        strongSelf?.sampleWallpaperFallback(smoothing: cfg.smoothing)
                    }
                }
            }
        } else {
            sampleWallpaperFallback(smoothing: cfg.smoothing)
        }
    }

    private func sampleWallpaperFallback(smoothing: Double) {
        guard let screen = NSScreen.main,
              let wpURL = NSWorkspace.shared.desktopImageURL(for: screen),
              let img = NSImage(contentsOf: wpURL),
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let c = Self.extractDominantColor(from: cg)
        ingestSampledColor(c, smoothing: smoothing)
    }

    public func ingestSampledColor(_ sampled: TimelineColorRGB, smoothing: Double) {
        let alpha = 1.0 - max(0.05, min(0.95, smoothing))
        smoothedColor = TimelineColorRGB(
            r: smoothedColor.r + (sampled.r - smoothedColor.r) * alpha,
            g: smoothedColor.g + (sampled.g - smoothedColor.g) * alpha,
            b: smoothedColor.b + (sampled.b - smoothedColor.b) * alpha
        )
    }

    /// Downsamples any CGImage into a 16x16 sRGB buffer in-memory and computes weighted dominant color.
    /// Zero frame images are ever retained or persisted to disk.
    public static func extractDominantColor(from image: CGImage) -> TimelineColorRGB {
        let w = 16, h = 16
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return TimelineColorRGB(r: 0.8, g: 0.7, b: 0.5)
        }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        var sumR = 0.0, sumG = 0.0, sumB = 0.0, totalW = 0.0
        for idx in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[idx]) / 255.0
            let g = Double(pixels[idx + 1]) / 255.0
            let b = Double(pixels[idx + 2]) / 255.0
            let maxC = max(r, max(g, b)), minC = min(r, min(g, b))
            let sat = maxC > 0 ? (maxC - minC) / maxC : 0
            // Emphasize vibrant midtone pixels slightly over flat black/white
            let weight = 0.25 + sat * 1.5
            sumR += r * weight
            sumG += g * weight
            sumB += b * weight
            totalW += weight
        }
        guard totalW > 0 else { return TimelineColorRGB(r: 0.8, g: 0.7, b: 0.5) }
        return TimelineColorRGB(
            r: max(0, min(1, sumR / totalW)),
            g: max(0, min(1, sumG / totalW)),
            b: max(0, min(1, sumB / totalW))
        )
    }
}
