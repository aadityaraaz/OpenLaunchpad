import AppKit
import Carbon
import CSQLite
import LauncherCore
import ServiceManagement

@MainActor final class GlobalShortcut {
    private var handler: EventHandlerRef?
    private var refs: [EventHotKeyRef] = []
    var action: (() -> Void)?
    func unregister() { for ref in refs { UnregisterEventHotKey(ref) }; refs.removeAll() }
    func register(_ preferences: Preferences) -> Bool {
        unregister()
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
                guard let pointer else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<GlobalShortcut>.fromOpaque(pointer).takeUnretainedValue()
                Task { @MainActor in service.action?() }; return noErr
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(preferences.shortcutKey, preferences.shortcutModifiers, EventHotKeyID(signature: 0x4F4C5044, id: 1), GetApplicationEventTarget(), 0, &ref)
        if let ref { refs.append(ref) }
        if preferences.useF4 {
            var f4: EventHotKeyRef?
            let result = RegisterEventHotKey(UInt32(kVK_F4), 0, EventHotKeyID(signature: 0x4F4C5044, id: 2), GetApplicationEventTarget(), 0, &f4)
            if let f4 { refs.append(f4) }
            if result != noErr { return false }
        }
        return status == noErr
    }
    deinit { for ref in refs { UnregisterEventHotKey(ref) }; if let handler { RemoveEventHandler(handler) } }
}

@MainActor final class HotCorners {
    private var timer: Timer?
    private var entered: Date?
    private var latched = false
    var action: (() -> Void)?
    var preferences = Preferences()
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in Task { @MainActor in self?.poll() } }
    }
    private func poll() {
        guard preferences.hotCorner != "Off" else { entered = nil; latched = false; return }
        let point = NSEvent.mouseLocation
        let hit = NSScreen.screens.contains { screen in
            let r = screen.frame
            let top = preferences.hotCorner.contains("Top")
            let left = preferences.hotCorner.contains("left")
            let corner = NSPoint(x: left ? r.minX : r.maxX - 1, y: top ? r.maxY - 1 : r.minY)
            // Ignore internal display corners bordering another monitor.
            let adjacent = NSScreen.screens.contains { other in
                other !== screen && other.frame.insetBy(dx: -2, dy: -2).contains(corner)
            }
            return !adjacent && abs(point.x - corner.x) < 6 && abs(point.y - corner.y) < 6
        }
        if hit {
            if entered == nil { entered = Date() }
            if !latched, Date().timeIntervalSince(entered!) >= preferences.hotCornerDelay { latched = true; action?() }
        } else { entered = nil; latched = false }
    }
}

struct CleanUninstaller {
    static func candidates(for app: AppRecord) -> [URL] {
        guard !app.bundleID.isEmpty else { return [] }
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let relative = ["Preferences/\(app.bundleID).plist", "Caches/\(app.bundleID)", "Application Support/\(app.bundleID)", "Saved Application State/\(app.bundleID).savedState", "HTTPStorages/\(app.bundleID)", "WebKit/\(app.bundleID)", "Containers/\(app.bundleID)"]
        return relative.map { library.appendingPathComponent($0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
    static func trash(app: AppRecord, selected: [URL]) throws {
        let url = URL(fileURLWithPath: app.path).standardizedFileURL
        guard !url.path.hasPrefix("/System/"), url.pathExtension == "app", FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileWriteNoPermission) }
        let approved = Set(candidates(for: app).map { $0.standardizedFileURL.path })
        guard selected.allSatisfy({ approved.contains($0.standardizedFileURL.path) }) else { throw CocoaError(.fileWriteNoPermission) }
        // Trash the application first. If it is protected, leave its data intact.
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        for leftover in selected { try FileManager.default.trashItem(at: leftover, resultingItemURL: nil) }
    }
}

struct NativeLayoutImporter {
    static func importLayout(from url: URL, apps: [AppRecord]) throws -> [LayoutItem] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else { if let db { sqlite3_close(db) }; throw ImportError.unreadable }
        defer { sqlite3_close(db) }
        func rows(_ sql: String) throws -> [[String]] {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw ImportError.schema }
            defer { sqlite3_finalize(statement) }
            var result: [[String]] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                result.append((0..<sqlite3_column_count(statement)).map { index in sqlite3_column_text(statement, index).map { String(cString: $0) } ?? "" })
            }
            return result
        }
        let appRows = try rows("SELECT item_id, title, bundleid FROM apps")
        let itemRows = try rows("SELECT rowid, parent_id, ordering, type FROM items ORDER BY ordering")
        let groupRows = try rows("SELECT item_id, title FROM groups")
        let appMap = Dictionary(uniqueKeysWithValues: appRows.compactMap { row -> (String, String)? in
            let match = apps.first { $0.bundleID == row[2] || $0.name == row[1] }
            return match.map { (row[0], $0.id) }
        })
        let titles = Dictionary(uniqueKeysWithValues: groupRows.map { ($0[0], $0[1]) })
        var parents: [String: String] = [:]
        for row in itemRows { parents[row[0]] = row[1] }
        // Legacy databases contain a root, pages, then apps/folder pages.
        // Named groups are folders; unnamed groups are page containers.
        var result: [LayoutItem] = []; var seen = Set<String>(); var seenFolders = Set<String>()
        let rowMap = Dictionary(uniqueKeysWithValues: itemRows.map { ($0[0], $0) })
        let children = Dictionary(grouping: itemRows, by: { $0[1] })
        var traversal: [[String]] = []; var visitedItems = Set<String>()
        func walk(_ row: [String]) {
            guard visitedItems.insert(row[0]).inserted else { return }
            traversal.append(row)
            for child in children[row[0]] ?? [] { walk(child) }
        }
        for root in itemRows where rowMap[root[1]] == nil { walk(root) }
        // Tolerate orphaned nodes without dropping their matched apps.
        for row in itemRows where !visitedItems.contains(row[0]) { walk(row) }
        for row in traversal {
            guard let appID = appMap[row[0]], seen.insert(appID).inserted else { continue }
            var parent = row[1]; var folder: String?; var visited = Set<String>()
            while !parent.isEmpty && visited.insert(parent).inserted {
                if let title = titles[parent], !title.isEmpty { folder = parent; break }
                parent = parents[parent] ?? ""
            }
            if let folder {
                if seenFolders.insert(folder).inserted { result.append(LayoutItem(folder: titles[folder] ?? "Folder", apps: [appID], id: "native-" + folder)) }
                else if let index = result.firstIndex(where: { $0.id == "native-" + folder }) { result[index].apps.append(appID) }
            } else { result.append(LayoutItem(app: appID)) }
        }
        guard !result.isEmpty else { throw ImportError.empty }
        return result
    }
    enum ImportError: LocalizedError {
        case unreadable, schema, empty
        var errorDescription: String? {
            switch self {
            case .unreadable: return "The Launchpad database could not be opened. Choose a readable backup copy."
            case .schema: return "This file does not use the supported legacy Launchpad database schema."
            case .empty: return "No apps in this layout match the applications installed on this Mac."
            }
        }
    }
    @MainActor static func choose(store: LibraryStore) {
        let panel = NSOpenPanel(); panel.title = "Import a legacy Launchpad database"; panel.message = "Choose a db file from a pre-Tahoe Dock database backup. Your current layout will be replaced."
        if panel.runModal() == .OK, let url = panel.url {
            do { store.state.items = try importLayout(from: url, apps: store.state.apps); store.state.normalize(); store.page = 0; store.save() }
            catch { store.message = error.localizedDescription }
        }
    }
}
