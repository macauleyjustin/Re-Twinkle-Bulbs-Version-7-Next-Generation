import Foundation
import AppKit
import CoreGraphics

public struct WallpaperItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let category: WallpaperThemeCategory
    public let url: URL
    public let isTileRecommended: Bool
    public let isBuiltIn130: Bool
}

/// Clean-room wallpaper generator, previewer, and macOS desktop wallpaper setter (130 seasonal collections + user import).
public final class WallpaperService: ObservableObject {
    public static let shared = WallpaperService()

    @Published public private(set) var items: [WallpaperItem] = []
    private var previewThumbCache: [String: CGImage] = [:]

    public static var wallpaperStorageDir: URL {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSup.appendingPathComponent("TwinkleBulbs/Wallpapers", isDirectory: true)
    }

    public static var importedWallpaperDir: URL {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSup.appendingPathComponent("TwinkleBulbs/ImportedWallpapers", isDirectory: true)
    }

    init() {
        try? FileManager.default.createDirectory(at: Self.wallpaperStorageDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: Self.importedWallpaperDir, withIntermediateDirectories: true)
        ensureOriginalFiveGenerated()
        reloadList()
    }

    public func reloadList() {
        var result: [WallpaperItem] = []
        for spec in WallpaperPack130.allSpecs {
            let url = Self.wallpaperStorageDir.appendingPathComponent("\(spec.id).png")
            result.append(WallpaperItem(
                id: spec.id,
                title: spec.title,
                category: spec.category,
                url: url,
                isTileRecommended: spec.isTile,
                isBuiltIn130: true
            ))
        }
        if let imported = try? FileManager.default.contentsOfDirectory(at: Self.importedWallpaperDir, includingPropertiesForKeys: nil) {
            let exts = Set(["jpg", "jpeg", "png", "heic", "tiff", "bmp"])
            for f in imported.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                if exts.contains(f.pathExtension.lowercased()) {
                    result.append(WallpaperItem(
                        id: "imported:\(f.lastPathComponent)",
                        title: f.deletingPathExtension().lastPathComponent,
                        category: .all,
                        url: f,
                        isTileRecommended: f.lastPathComponent.lowercased().contains("tile"),
                        isBuiltIn130: false
                    ))
                }
            }
        }
        items = result
    }

    public func previewImage(for item: WallpaperItem) -> NSImage? {
        if let cached = previewThumbCache[item.id] {
            return NSImage(cgImage: cached, size: NSSize(width: cached.width, height: cached.height))
        }
        if FileManager.default.fileExists(atPath: item.url.path), let img = NSImage(contentsOf: item.url) {
            return img
        }
        if let spec = WallpaperPack130.allSpecs.first(where: { $0.id == item.id }),
           let cg = WallpaperPack130.renderWallpaper(spec, width: 280, height: 180) {
            previewThumbCache[item.id] = cg
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
        return nil
    }

    @discardableResult
    public func ensureImageFileOnDisk(id: String) -> URL? {
        guard let item = items.first(where: { $0.id == id }) else { return nil }
        if FileManager.default.fileExists(atPath: item.url.path) { return item.url }
        guard let spec = WallpaperPack130.allSpecs.first(where: { $0.id == id }) else { return nil }
        let sz = spec.isTile ? (256, 256) : (1280, 800)
        if let cg = WallpaperPack130.renderWallpaper(spec, width: sz.0, height: sz.1),
           let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
            try? png.write(to: item.url)
            return item.url
        }
        return nil
    }

    @discardableResult
    public func applyWallpaper(id: String, style: WallpaperStyle, screen: NSScreen? = nil) -> Bool {
        guard let fileURL = ensureImageFileOnDisk(id: id) else { return false }
        let targetScreens = screen.map { [$0] } ?? NSScreen.screens
        var options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        switch style {
        case .tile:
            options[.imageScaling] = NSImageScaling.scaleNone.rawValue
            options[.allowClipping] = true
        case .center:
            options[.imageScaling] = NSImageScaling.scaleNone.rawValue
            options[.allowClipping] = false
        case .stretch:
            options[.imageScaling] = NSImageScaling.scaleAxesIndependently.rawValue
            options[.allowClipping] = true
        case .fit:
            options[.imageScaling] = NSImageScaling.scaleProportionallyUpOrDown.rawValue
            options[.allowClipping] = false
        }
        options[.fillColor] = NSColor(srgbRed: 0.04, green: 0.07, blue: 0.14, alpha: 1.0)

        var ok = true
        for scr in targetScreens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(fileURL, for: scr, options: options)
            } catch {
                ok = false
            }
        }
        return ok
    }

    private func ensureOriginalFiveGenerated() {
        for spec in WallpaperPack130.allSpecs.prefix(5) {
            let url = Self.wallpaperStorageDir.appendingPathComponent("\(spec.id).png")
            if FileManager.default.fileExists(atPath: url.path) { continue }
            let sz = spec.isTile ? (256, 256) : (1280, 800)
            if let cg = WallpaperPack130.renderWallpaper(spec, width: sz.0, height: sz.1),
               let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
        }
    }
}
