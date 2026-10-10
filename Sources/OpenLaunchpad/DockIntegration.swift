import AppKit
import LauncherCore

@MainActor enum DockIntegration {
    private static let domain = "com.apple.dock" as CFString
    private static var entries: [[String: Any]] { CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]] ?? [] }
    static func isPinned(_ app: AppRecord) -> Bool {
        entries.contains { entry in
            guard let tile = entry["tile-data"] as? [String: Any], let file = tile["file-data"] as? [String: Any], let string = file["_CFURLString"] as? String else { return false }
            return URL(string: string)?.resolvingSymlinksInPath().path == URL(fileURLWithPath: app.path).resolvingSymlinksInPath().path
        }
    }
    static func add(_ app: AppRecord) throws {
        guard !isPinned(app), FileManager.default.fileExists(atPath: app.path) else { return }
        var next = entries
        let url = URL(fileURLWithPath: app.path, isDirectory: true)
        var tile: [String: Any] = ["file-data": ["_CFURLString": url.absoluteString, "_CFURLStringType": 15], "file-label": app.name, "bundle-identifier": app.bundleID, "file-type": 32]
        tile["book"] = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        next.append(["GUID": Int64.random(in: 1...Int64(UInt32.max)), "tile-type": "file-tile", "tile-data": tile])
        CFPreferencesSetAppValue("persistent-apps" as CFString, next as CFPropertyList, domain)
        guard CFPreferencesAppSynchronize(domain) else { throw CocoaError(.fileWriteUnknown) }
        let restart = Process(); restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall"); restart.arguments = ["-u", NSUserName(), "Dock"]
        try restart.run()
    }
}
