import SwiftUI
import AppKit
import CoreImage
import AVFoundation

struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(); view.material = .hudWindow; view.blendingMode = .behindWindow; view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// A static wallpaper texture keeps a large Gaussian blur out of the scroll compositor.
struct WallpaperBackground: View {
    let blur: Double
    @Environment(\.colorScheme) private var colorScheme
    @ViewState private var rendered: NSImage?
    var body: some View {
        GeometryReader { proxy in
            let screen = NSScreen.main ?? NSScreen.screens.first
            let request = WallpaperRequest(url: screen.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }, width: Int(proxy.size.width), height: Int(proxy.size.height), blur: blur, dark: colorScheme == .dark)
            Group {
                if let rendered { Image(nsImage: rendered).resizable().scaledToFill() }
                else { Color.clear }
            }.frame(width: proxy.size.width, height: proxy.size.height).clipped()
                .task(id: request) {
                    guard let data = await WallpaperRenderer.shared.render(request), !Task.isCancelled else { return }
                    rendered = NSImage(data: data)
                }
        }
    }
}

private struct WallpaperRequest: Hashable, Sendable {
    let url: URL?
    let width: Int
    let height: Int
    let blur: Double
    let dark: Bool
}

private actor WallpaperRenderer {
    static let shared = WallpaperRenderer()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var cache: [WallpaperRequest: Data] = [:]
    func render(_ request: WallpaperRequest) -> Data? {
        if let cached = cache[request] { return cached }
        guard request.width > 0, request.height > 0,
              let source = wallpaper(request), !source.extent.isEmpty else { return nil }
        // Blur hides fine detail; bounded resolution avoids a full Retina-screen render pass.
        let ratio = min(1, 2048 / Double(max(request.width, request.height)))
        let width = Double(request.width) * ratio, height = Double(request.height) * ratio
        let scale = max(width / source.extent.width, height / source.extent.height)
        let scaled = source.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
        let image = scaled.transformed(by: CGAffineTransform(translationX: (width - scaled.extent.width) / 2 - scaled.extent.minX, y: (height - scaled.extent.height) / 2 - scaled.extent.minY))
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let blurred = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: request.blur * ratio]).cropped(to: bounds)
        guard let cg = context.createCGImage(blurred, from: bounds),
              let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return nil }
        if cache.count >= 4 { cache.removeAll() }
        cache[request] = data
        return data
    }
    private func wallpaper(_ request: WallpaperRequest) -> CIImage? {
        // NSWorkspace can return the old static fallback for an aerial desktop. Resolve
        // the selected local aerial instead; never download or bundle OS artwork.
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.wallpaper")
        if let data = try? Data(contentsOf: root.appendingPathComponent("Store/Index.plist")),
           let index = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
           let all = index["AllSpacesAndDisplays"] as? [String: Any],
           let linked = all["Linked"] as? [String: Any], let content = linked["Content"] as? [String: Any],
           let choices = content["Choices"] as? [[String: Any]],
           let choice = choices.first, (choice["Provider"] as? String)?.contains("aerials") == true,
           let configuration = choice["Configuration"] as? Data,
           let config = (try? PropertyListSerialization.propertyList(from: configuration, format: nil)) as? [String: Any],
           let assetID = config["assetID"] as? String {
            var ids = [assetID]
            if let manifestData = try? Data(contentsOf: root.appendingPathComponent("aerials/manifest/entries.json")),
               let manifest = (try? JSONSerialization.jsonObject(with: manifestData)) as? [String: Any],
               let assets = manifest["assets"] as? [[String: Any]] {
                ids += assets.filter { asset in
                    let variant = asset["variant"] as? [String: String]
                    return (asset["subcategories"] as? [String])?.contains(assetID) == true && variant?["appearance"] == (request.dark ? "dark" : "light") && variant?["orientation"] == (request.width >= request.height ? "landscape" : "portrait")
                }.compactMap { $0["id"] as? String }
            }
            for id in ids where UUID(uuidString: id) != nil {
                let url = root.appendingPathComponent("aerials/videos/\(id).mov")
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 2048, height: 2048)
                // Aerial desktops settle on the final frame after their opening animation.
                let seconds = CMTimeGetSeconds(asset.duration)
                let time = seconds.isFinite && seconds > 1 ? CMTime(seconds: seconds - 0.1, preferredTimescale: 600) : .zero
                if let frame = try? generator.copyCGImage(at: time, actualTime: nil) { return CIImage(cgImage: frame) }
            }
        }
        return request.url.flatMap { CIImage(contentsOf: $0) }
    }
}
