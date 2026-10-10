import AppKit
import SwiftUI
import LauncherCore
import UniformTypeIdentifiers

@MainActor final class LibraryStore: ObservableObject {
    @Published var state = LibraryState() {
        didSet {
            appIndex = Dictionary(state.apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            sortedCache = nil
        }
    }
    private var appIndex: [String: AppRecord] = [:]
    private var sortedCache: [LayoutItem]?
    @Published var query = "" {
        didSet {
            if oldValue.isEmpty && !query.isEmpty { searchReturnPage = page; searchReturnFolder = folderID; page = 0; selection.removeAll() }
            else if !oldValue.isEmpty && query.isEmpty { folderID = searchReturnFolder; page = min(searchReturnPage, pageCount - 1); selection.removeAll() }
        }
    }
    private var searchReturnPage = 0
    private var searchReturnFolder: String?
    @Published var page = 0 { willSet { if newValue != page { pageDirection = newValue > page ? 1 : -1 } } }
    private(set) var pageDirection = 1
    @Published var selection = Set<String>()
    private var folderReturnPage = 0
    @Published var folderID: String?
    @Published var editing = false
    @Published var extraPage = false
    @Published var uninstallMode = false
    @Published var dragging = false
    @Published var pagingOffset: CGFloat = 0
    @Published var infoApp: AppRecord?
    @Published var profileName = ""
    @Published var canUndo = false
    @Published var canRedo = false
    private var undoStack: [LibraryState] = []
    private var redoStack: [LibraryState] = []
    @Published var checkingUpdates = false
    @Published var updateURL: URL?
    @Published var scanning = false
    @Published var message: String?
    @Published var renameID: String?
    @Published var renameValue = ""
    @Published var uninstallApp: AppRecord?
    @Published var uninstallFiles: [URL] = []
    var restart: (() -> Void)?
    var dismiss: (() -> Void)?
    var showReorganization: (() -> Void)?
    var showSettings: (() -> Void)?
    var preferencesChanged: (() -> Void)?
    private let storage: URL
    private var saveWork: DispatchWorkItem?
    init(storage: URL? = nil) {
        self.storage = storage ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OpenLaunchpad/library.json")
        if let data = try? Data(contentsOf: self.storage) {
            do { state = try JSONDecoder().decode(LibraryState.self, from: data).validated() }
            catch { message = "The saved layout could not be read. A fresh layout will be created; your file is preserved as library.recovery.json."; try? FileManager.default.copyItem(at: self.storage, to: self.storage.deletingLastPathComponent().appendingPathComponent("library.recovery.json")) }
        }
        appIndex = Dictionary(state.apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    var preferences: Preferences { state.preferences }
    var visibleCount: Int { state.apps.filter { !$0.hidden }.count }
    var favorites: [AppRecord] { state.apps.filter { $0.favorite == true && !$0.hidden } }
    var folders: [LayoutItem] { state.items.filter(\.isFolder) }
    func app(_ id: String) -> AppRecord? { appIndex[id] }
    func item(_ id: String) -> LayoutItem? { state.items.first { $0.id == id } }
    var sortedItems: [LayoutItem] {
        if let sortedCache { return sortedCache }
        var items = state.items
        guard preferences.sort != .manual else { sortedCache = items; return items }
        items.removeAll(where: \.isSpacer)
        items.sort { a, b in
            switch preferences.sort {
            case .name: return title(a).localizedStandardCompare(title(b)) == .orderedAscending
            case .added: return date(a, recent: false) < date(b, recent: false)
            case .recent: return date(a, recent: true) < date(b, recent: true)
            case .color: return hue(a) < hue(b)
            case .manual: return false
            }
        }
        let result = preferences.descendingSort ? Array(items.reversed()) : items
        sortedCache = result; return result
    }
    var displayedItems: [LayoutItem] {
        if !query.isEmpty {
            return state.apps.filter { !$0.hidden || preferences.showHiddenInSearch }.compactMap { app -> (AppRecord, Int)? in AppSearch.score(query, app: app).map { (app, $0) } }
                .sorted { $0.1 == $1.1 ? $0.0.displayName.localizedStandardCompare($1.0.displayName) == .orderedAscending : $0.1 > $1.1 }.map { LayoutItem(app: $0.0.id) }
        }
        if let folderID { return item(folderID)?.apps.map { LayoutItem(app: $0) } ?? [] }
        return preferences.browse == .scroll ? sortedItems.filter { !$0.isSpacer } : sortedItems
    }
    var pageCount: Int { max(1, Int(ceil(Double(displayedItems.count) / Double(preferences.pageSize)))) + (extraPage ? 1 : 0) }
    func title(_ item: LayoutItem) -> String { item.name ?? app(item.apps.first ?? "")?.displayName ?? "App" }
    private func date(_ item: LayoutItem, recent: Bool) -> Date { item.apps.compactMap { id in app(id).map { recent ? ($0.lastOpened ?? .distantPast) : $0.added } }.max() ?? .distantPast }
    private func hue(_ item: LayoutItem) -> Double { item.apps.first.flatMap { app($0) }.map { IconCache.shared.hue($0) } ?? 0 }
    func refreshIcons() {
        IconCache.shared.clear(); sortedCache = nil
        IconCache.shared.prefetch(state.apps); objectWillChange.send()
    }
    func checkForUpdates() {
        updateURL = nil
        guard let url = URL(string: preferences.updateFeedURL), url.scheme == "https", url.host != nil else {
            message = "No release feed is configured. Add your project's HTTPS update manifest in Advanced settings to check published versions."; return
        }
        guard !checkingUpdates else { return }; checkingUpdates = true
        Task {
            defer { checkingUpdates = false }
            do {
                let release = try await ReleaseUpdates.fetch(url)
                let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
                if release.version.compare(current, options: .numeric) == .orderedDescending {
                    updateURL = release.url; message = "OpenLaunchpad \(release.version) is available. Installed version: \(current)."
                } else { message = "You're up to date (\(current))." }
            } catch { message = "Could not check for updates: \(error.localizedDescription)" }
        }
    }
    func refresh() {
        guard !scanning else { return }; scanning = true
        let sources = AppScanner.defaultSources + preferences.customSources
        Task {
            let apps = await Task.detached(priority: .userInitiated) { AppScanner.scan(sources: sources) }.value
            var refreshed = state
            refreshed.reconcile(apps, preservingMissingFrom: preferences.customSources.filter { !FileManager.default.fileExists(atPath: $0) })
            if refreshed != state { state = refreshed; save() }
            IconCache.shared.prefetch(state.apps)
            scanning = false
            page = min(page, pageCount - 1)
        }
    }
    func save() {
        saveWork?.cancel()
        let snapshot = state; let url = storage
        let work = DispatchWorkItem { [weak self] in
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(snapshot).write(to: url, options: .atomic)
            } catch { Task { @MainActor [weak self] in self?.message = "Could not save the layout: \(error.localizedDescription)" } }
        }
        saveWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
    func flush() {
        saveWork?.cancel(); saveWork = nil
        do {
            try FileManager.default.createDirectory(at: storage.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: storage, options: .atomic)
        } catch { message = "Could not save the layout: \(error.localizedDescription)" }
    }
    func updatePreferences(_ change: (inout Preferences) -> Void) { change(&state.preferences); state.normalize(); page = min(page, pageCount - 1); save(); preferencesChanged?() }
    func checkpoint() {
        undoStack.append(state); if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll(); canUndo = true; canRedo = false
    }
    func undo() {
        guard var previous = undoStack.popLast() else { return }
        redoStack.append(state); previous.reconcile(state.apps); state = previous
        resetNavigation(); canUndo = !undoStack.isEmpty; canRedo = true; save(); preferencesChanged?()
    }
    func redo() {
        guard var next = redoStack.popLast() else { return }
        undoStack.append(state); next.reconcile(state.apps); state = next
        resetNavigation(); canRedo = !redoStack.isEmpty; canUndo = true; save(); preferencesChanged?()
    }
    private func resetNavigation() { page = 0; extraPage = false; query = ""; folderID = nil; selection.removeAll() }
    func toggleFavorite(_ id: String) {
        guard let index = state.apps.firstIndex(where: { $0.id == id }) else { return }
        checkpoint(); state.apps[index].favorite = state.apps[index].favorite != true; save()
    }
    func saveProfile() { checkpoint(); state.saveProfile(name: profileName); profileName = ""; save() }
    func applyProfile(_ id: String) { checkpoint(); state.applyProfile(id); resetNavigation(); save(); preferencesChanged?() }
    func removeProfile(_ id: String) { checkpoint(); state.profiles?.removeAll { $0.id == id }; save() }
    func activate(_ item: LayoutItem, command: Bool = false) {
        if uninstallMode, !item.isFolder, let app = app(item.apps[0]) { previewUninstall(app); return }
        if command || editing {
            if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
        } else if item.isFolder {
            folderReturnPage = page
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { folderID = item.id; page = 0; selection = Set(item.apps.prefix(1)) }
        } else if let app = app(item.apps[0]) { launch(app) }
    }
    func launch(_ app: AppRecord) {
        guard FileManager.default.fileExists(atPath: app.path) else { message = "This app has moved or was removed. Refresh the library to find it again."; return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: app.path), configuration: configuration) { _, error in
            Task { @MainActor in
                if let error { self.message = "Could not open \(app.displayName): \(error.localizedDescription)" }
                else { if let index = self.state.apps.firstIndex(where: { $0.id == app.id }) { self.state.apps[index].lastOpened = Date() }; self.save(); self.dismiss?() }
            }
        }
    }
    func turnPage(_ delta: Int) {
        let destination = min(max(page + delta, 0), pageCount - 1)
        guard destination != page else { return }
        withAnimation(.easeOut(duration: 0.24)) { page = destination; selection.removeAll() }
    }
    func navigate(_ delta: Int) {
        let items = displayedItems; guard !items.isEmpty else { return }
        guard let selected = selection.first, let current = items.firstIndex(where: { $0.id == selected }) else {
            if let first = items.dropFirst(page * preferences.pageSize).first(where: { !$0.isSpacer }) ?? items.first(where: { !$0.isSpacer }) { selection = [first.id] }
            return
        }
        var index = min(max(current + delta, 0), items.count - 1)
        while items[index].isSpacer {
            let next = index + (delta > 0 ? 1 : -1)
            guard items.indices.contains(next) else { return }; index = next
        }
        selection = [items[index].id]; page = index / preferences.pageSize
    }
    func openSelection() {
        let id = selection.first
        if let selected = displayedItems.first(where: { $0.id == id }) ?? displayedItems.first(where: { !$0.isSpacer }) { activate(selected) }
    }
    func escape() {
        if renameID != nil { renameID = nil }
        else if !query.isEmpty { query = ""; selection.removeAll() }
        else if folderID != nil { closeFolder() }
        else if dragging { dragging = false }
        else if editing { editing = false; selection.removeAll() }
        else { dismiss?() }
    }
    func closeFolder() { folderID = nil; selection.removeAll(); page = min(folderReturnPage, pageCount - 1) }
    func rename(_ id: String) { renameID = id; renameValue = item(id).map(title) ?? app(id)?.displayName ?? "" }
    func commitRename() {
        guard let id = renameID else { return }; checkpoint()
        let value = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = state.items.firstIndex(where: { $0.id == id && $0.isFolder }), !value.isEmpty { state.items[i].name = value }
        else if let i = state.apps.firstIndex(where: { $0.id == id }) { state.apps[i].alias = value.isEmpty || value == state.apps[i].name ? nil : value }
        renameID = nil; save()
    }
    func hide(_ ids: Set<String>) {
        checkpoint()
        let appIDs = Set(ids.flatMap { item($0)?.apps ?? [$0] })
        for i in state.apps.indices where appIDs.contains(state.apps[i].id) { state.apps[i].hidden = true }
        state.normalize(); selection.removeAll(); page = min(page, pageCount - 1); save()
    }
    func restore(_ id: String) { checkpoint(); if let i = state.apps.firstIndex(where: { $0.id == id }) { state.apps[i].hidden = false }; state.normalize(); save() }
    func groupSelection() { checkpoint(); state.group(Array(selection), into: nil); selection.removeAll(); save() }
    func dissolve(_ id: String) { checkpoint(); state.dissolve(id); if folderID == id { folderID = nil }; save() }
    func moveToFolder(_ ids: Set<String>, folder: String?) { checkpoint(); let apps = ids.flatMap { item($0)?.apps ?? [$0] }; state.moveApps(apps, into: folder); selection.removeAll(); save() }
    func moveToPage(_ ids: [String], page: Int) {
        dragging = false; checkpoint()
        if preferences.sort != .manual { state.items = sortedItems }; state.preferences.sort = .manual
        let loose = ids.filter { item($0) == nil }
        if !loose.isEmpty { state.moveApps(loose, into: nil) }
        state.moveToPage(ids, page: page, pageSize: preferences.pageSize)
        extraPage = false; self.page = min(page, pageCount - 1); selection.removeAll(); save()
    }
    func drop(_ ids: [String], target: String?, group: Bool) {
        dragging = false
        guard query.isEmpty else { return }
        if extraPage { moveToPage(ids, page: page); return }; checkpoint()
        if preferences.sort != .manual { state.items = sortedItems }; state.preferences.sort = .manual
        if let folderID { state.moveWithinFolder(ids, folderID: folderID, before: target) }
        else if group { state.group(ids, into: target) }
        else {
            let loose = ids.filter { item($0) == nil }
            if !loose.isEmpty { state.moveApps(loose, into: nil) }
            state.move(ids, before: target)
        }
        selection.removeAll(); page = min(page, pageCount - 1); save()
    }
    func organize(_ action: String) {
        checkpoint()
        switch action {
        case "Fill empty slots": state.items.removeAll(where: \.isSpacer)
        case "Apple apps first": state.items = state.items.filter { $0.apps.first.flatMap { app($0) }?.bundleID.hasPrefix("com.apple.") == true } + state.items.filter { $0.apps.first.flatMap { app($0) }?.bundleID.hasPrefix("com.apple.") != true }
        case "Ungroup folders": for folder in folders { state.dissolve(folder.id) }
        case "Folders first": state.items = state.items.filter(\.isFolder) + state.items.filter { !$0.isFolder }
        case "Folders last": state.items = state.items.filter { !$0.isFolder } + state.items.filter(\.isFolder)
        default: state.items = sortedItems
        }
        state.preferences.sort = .manual; save()
    }
    func reorganize(sort: SortMode, descending: Bool, applePlacement: String, folderPlacement: String, ungroup: Bool, pages: Set<Int>?) {
        checkpoint()
        var snapshot = state
        if preferences.sort != .manual { snapshot.items = sortedItems }
        snapshot.reorganizePages(pages, pageSize: preferences.pageSize) { source in
            var items = ungroup ? source.flatMap { $0.apps.map { LayoutItem(app: $0) } } : source
            if sort != .manual {
                items = items.enumerated().sorted { a, b in
                    let comparison: ComparisonResult
                    switch sort {
                    case .name: comparison = title(a.element).localizedStandardCompare(title(b.element))
                    case .added, .recent:
                        let left = date(a.element, recent: sort == .recent), right = date(b.element, recent: sort == .recent)
                        comparison = left == right ? .orderedSame : left < right ? .orderedAscending : .orderedDescending
                    case .color:
                        let left = hue(a.element), right = hue(b.element)
                        comparison = left == right ? .orderedSame : left < right ? .orderedAscending : .orderedDescending
                    case .manual: comparison = .orderedSame
                    }
                    return comparison == .orderedSame ? a.offset < b.offset : comparison == (descending ? .orderedDescending : .orderedAscending)
                }.map(\.element)
            }
            if applePlacement != "Mixed" {
                let isApple: (LayoutItem) -> Bool = { item in !item.apps.isEmpty && item.apps.allSatisfy { self.app($0)?.bundleID.hasPrefix("com.apple.") == true } }
                let apple = items.filter(isApple), others = items.filter { !isApple($0) }
                items = applePlacement == "First" ? apple + others : others + apple
            }
            if folderPlacement != "Mixed" {
                let folders = items.filter(\.isFolder), apps = items.filter { !$0.isFolder }
                items = folderPlacement == "First" ? folders + apps : apps + folders
            }
            return items
        }
        snapshot.preferences.sort = .manual; state = snapshot
        selection.removeAll(); page = min(page, pageCount - 1); save()
    }
    func exportDiagnostics() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "OpenLaunchpad-diagnostics.txt"
        if panel.runModal() == .OK, let url = panel.url {
            let report = """
            OpenLaunchpad 0.1.0
            Date: \(Date().formatted())
            System: \(ProcessInfo.processInfo.operatingSystemVersionString)
            Applications: \(state.apps.count) (\(visibleCount) visible)
            Folders: \(folders.count)
            Profiles: \((state.profiles ?? []).count)
            Grid: \(preferences.columns) × \(preferences.rows)
            Browse: \(preferences.browse.rawValue)
            Interface: \(preferences.interfaceStyle)
            Global pinch: \(preferences.gestureFingers) fingers (0 = disabled)
            Custom source count: \(preferences.customSources.count)
            No installed app names, paths, or personal identifiers included.
            """
            do { try report.write(to: url, atomically: true, encoding: .utf8) } catch { message = error.localizedDescription }
        }
    }
    func exportBackup() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "OpenLaunchpad-layout.json"; panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(state).write(to: url, options: .atomic) }
            catch { message = error.localizedDescription }
        }
    }
    func importBackup() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let restored = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: url)).validated()
                // Match saved bundle identifiers against this Mac; never trust imported launch paths.
                var merged = state; merged.restoreLayout(from: restored)
                merged.normalize(); checkpoint(); state = merged; page = 0; folderID = nil; selection.removeAll(); save(); preferencesChanged?()
            } catch { message = "This backup is invalid or unsupported: \(error.localizedDescription)" }
        }
    }
    func addSource() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url, !preferences.customSources.contains(url.path) { updatePreferences { $0.customSources.append(url.path) }; refresh() }
    }
    func previewUninstall(_ app: AppRecord) {
        guard !app.path.hasPrefix("/System/"), !app.bundleID.isEmpty else { message = "System applications cannot be uninstalled."; return }
        uninstallApp = app; uninstallFiles = CleanUninstaller.candidates(for: app)
    }
    func confirmUninstall() {
        guard let app = uninstallApp else { return }
        do {
            if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == app.bundleID }) { throw NSError(domain: "OpenLaunchpad", code: 1, userInfo: [NSLocalizedDescriptionKey: "Quit the application before uninstalling it."]) }
            try CleanUninstaller.trash(app: app, selected: uninstallFiles)
            uninstallApp = nil; refresh()
        } catch { message = error.localizedDescription }
    }
}
