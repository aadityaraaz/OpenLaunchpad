import AppKit
import LauncherCore

struct AppScanner {
    static let defaultSources = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]
    static func scan(sources: [String]) -> [AppRecord] {
        let fm = FileManager.default
        var records: [AppRecord] = []; var paths = Set<String>(); var identities = Set<String>()
        for source in sources {
            let root = URL(fileURLWithPath: source).resolvingSymlinksInPath()
            guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isAliasFileKey, .creationDateKey], options: [.skipsHiddenFiles]) else { continue }
            while let raw = walker.nextObject() as? URL {
                var url = raw
                if (try? raw.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile) == true {
                    url = (try? URL(resolvingAliasFileAt: raw, options: [.withoutUI, .withoutMounting])) ?? raw
                }
                guard url.pathExtension.lowercased() == "app" else { continue }
                walker.skipDescendants()
                url = url.resolvingSymlinksInPath().standardizedFileURL
                guard paths.insert(url.path).inserted, let bundle = Bundle(url: url) else { continue }
                let identifier = bundle.bundleIdentifier ?? url.path
                let stableID = identities.insert(identifier).inserted ? identifier : identifier + ":" + url.path
                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
                let added = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                records.append(AppRecord(id: stableID, name: name, path: url.path, bundleID: bundle.bundleIdentifier ?? "", added: added))
            }
        }
        return records.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

@MainActor final class IconCache {
    static let shared = IconCache()
    private var cache: [String: NSImage] = [:]
    private var hues: [String: Double] = [:]
    private var generation = 0
    private let loader = DispatchQueue(label: "org.openlaunchpad.icons", qos: .utility)
    func prefetch(_ apps: [AppRecord]) {
        let missing = apps.filter { cache[$0.path] == nil }
        let currentGeneration = generation
        loader.async { [weak self] in
            for app in missing {
                autoreleasepool {
                    let image = NSWorkspace.shared.icon(forFile: app.path)
                    image.size = NSSize(width: 128, height: 128)
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == currentGeneration, self.cache[app.path] == nil else { return }
                        self.cache[app.path] = image
                    }
                }
            }
        }
    }
    func icon(_ app: AppRecord) -> NSImage {
        if let result = cache[app.path] { return result }
        let result = NSWorkspace.shared.icon(forFile: app.path)
        result.size = NSSize(width: 128, height: 128); cache[app.path] = result
        return result
    }
    func hue(_ app: AppRecord) -> Double {
        if let result = hues[app.path] { return result }
        let image = icon(app)
        var rect = NSRect(x: 0, y: 0, width: 16, height: 16)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return 0 }
        let rep = NSBitmapImageRep(cgImage: cg)
        var r = 0.0, g = 0.0, b = 0.0, weight = 0.0
        for x in stride(from: 0, to: rep.pixelsWide, by: max(1, rep.pixelsWide / 12)) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: max(1, rep.pixelsHigh / 12)) {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                    r += c.redComponent * c.alphaComponent; g += c.greenComponent * c.alphaComponent
                    b += c.blueComponent * c.alphaComponent; weight += c.alphaComponent
                }
            }
        }
        let result = weight == 0 ? 0 : NSColor(red: r / weight, green: g / weight, blue: b / weight, alpha: 1).hueComponent
        hues[app.path] = result; return result
    }
    func clear() { generation += 1; cache.removeAll(); hues.removeAll() }
}
