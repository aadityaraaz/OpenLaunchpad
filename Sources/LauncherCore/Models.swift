import Foundation

public struct AppRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var path: String
    public var bundleID: String
    public var added: Date
    public var lastOpened: Date?
    public var alias: String?
    public var hidden: Bool
    public var favorite: Bool?
    public var displayName: String { alias?.isEmpty == false ? alias! : name }
    public init(id: String, name: String, path: String, bundleID: String = "", added: Date = Date(), lastOpened: Date? = nil, alias: String? = nil, hidden: Bool = false) {
        self.id = id; self.name = name; self.path = path; self.bundleID = bundleID
        self.added = added; self.lastOpened = lastOpened; self.alias = alias; self.hidden = hidden
    }
}
public struct LayoutItem: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String?
    public var apps: [String]
    public var spacer: Bool?
    public var isSpacer: Bool { spacer == true }
    public var isFolder: Bool { name != nil }
    public init(spacer: Bool) { id = UUID().uuidString; name = nil; apps = []; self.spacer = spacer }
    public init(app: String) { id = app; name = nil; apps = [app] }
    public init(folder: String, apps: [String], id: String = UUID().uuidString) { self.id = id; name = folder; self.apps = apps }
}
public enum SortMode: String, Codable, CaseIterable, Sendable { case manual = "Manual", name = "Name", added = "Date added", recent = "Last opened", color = "Icon color" }
public enum BrowseMode: String, Codable, CaseIterable, Sendable { case pages = "Pages", scroll = "Scroll" }
public enum DisplayMode: String, Codable, CaseIterable, Sendable { case pointer = "Under pointer", active = "Active display", main = "Main display" }
public struct Preferences: Codable, Equatable, Sendable {
    public var columns = 7
    public var rows = 5
    public var sort: SortMode = .manual
    public var browse: BrowseMode = .scroll
    public var fullscreen = false
    public var display: DisplayMode = .pointer
    public var showAppNames = true
    public var showFolderNames = true
    public var wallpaper = false
    public var blur = 24.0
    public var tint = 0.16
    public var iconStyle = "Default"
    public var appearance = "System"
    public var launcherIcon = "Grid"
    public var hideDock = false
    public var resetAfter = -1.0
    public var naturalScroll = true
    public var hotCorner = "Off"
    public var hotCornerDelay = 0.5
    public var shortcutKey: UInt32 = 49
    public var shortcutModifiers: UInt32 = 2304 // control + option (Carbon)
    public var shortcutLabel = "⌃⌥Space"
    public var useF4 = false
    public var gestureFingers = 0
    public var interfaceStyle = "Classic"
    public var showHiddenInSearch = false
    public var descendingSort = false
    public var optionToUninstall = true
    public var showFavorites = true
    public var showMenuBarIcon = true
    public var updateFeedURL = ""
    public var customSources: [String] = []
    public init() {}
    private enum CodingKeys: String, CodingKey { case columns, rows, sort, browse, fullscreen, display, showAppNames, showFolderNames, wallpaper, blur, tint, iconStyle, appearance, launcherIcon, hideDock, resetAfter, naturalScroll, hotCorner, hotCornerDelay, shortcutKey, shortcutModifiers, shortcutLabel, useF4, gestureFingers, interfaceStyle, showHiddenInSearch, descendingSort, optionToUninstall, showFavorites, showMenuBarIcon, updateFeedURL, customSources }
    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        columns = try values.decodeIfPresent(type(of: columns), forKey: .columns) ?? columns
        rows = try values.decodeIfPresent(type(of: rows), forKey: .rows) ?? rows
        sort = try values.decodeIfPresent(type(of: sort), forKey: .sort) ?? sort
        browse = try values.decodeIfPresent(type(of: browse), forKey: .browse) ?? browse
        fullscreen = try values.decodeIfPresent(type(of: fullscreen), forKey: .fullscreen) ?? fullscreen
        display = try values.decodeIfPresent(type(of: display), forKey: .display) ?? display
        showAppNames = try values.decodeIfPresent(type(of: showAppNames), forKey: .showAppNames) ?? showAppNames
        showFolderNames = try values.decodeIfPresent(type(of: showFolderNames), forKey: .showFolderNames) ?? showFolderNames
        wallpaper = try values.decodeIfPresent(type(of: wallpaper), forKey: .wallpaper) ?? wallpaper
        blur = try values.decodeIfPresent(type(of: blur), forKey: .blur) ?? blur
        tint = try values.decodeIfPresent(type(of: tint), forKey: .tint) ?? tint
        iconStyle = try values.decodeIfPresent(type(of: iconStyle), forKey: .iconStyle) ?? iconStyle
        appearance = try values.decodeIfPresent(type(of: appearance), forKey: .appearance) ?? appearance
        launcherIcon = try values.decodeIfPresent(type(of: launcherIcon), forKey: .launcherIcon) ?? launcherIcon
        hideDock = try values.decodeIfPresent(type(of: hideDock), forKey: .hideDock) ?? hideDock
        resetAfter = try values.decodeIfPresent(type(of: resetAfter), forKey: .resetAfter) ?? resetAfter
        naturalScroll = try values.decodeIfPresent(type(of: naturalScroll), forKey: .naturalScroll) ?? naturalScroll
        hotCorner = try values.decodeIfPresent(type(of: hotCorner), forKey: .hotCorner) ?? hotCorner
        hotCornerDelay = try values.decodeIfPresent(type(of: hotCornerDelay), forKey: .hotCornerDelay) ?? hotCornerDelay
        shortcutKey = try values.decodeIfPresent(type(of: shortcutKey), forKey: .shortcutKey) ?? shortcutKey
        shortcutModifiers = try values.decodeIfPresent(type(of: shortcutModifiers), forKey: .shortcutModifiers) ?? shortcutModifiers
        shortcutLabel = try values.decodeIfPresent(type(of: shortcutLabel), forKey: .shortcutLabel) ?? shortcutLabel
        useF4 = try values.decodeIfPresent(type(of: useF4), forKey: .useF4) ?? useF4
        gestureFingers = try values.decodeIfPresent(type(of: gestureFingers), forKey: .gestureFingers) ?? gestureFingers
        interfaceStyle = try values.decodeIfPresent(type(of: interfaceStyle), forKey: .interfaceStyle) ?? interfaceStyle
        showHiddenInSearch = try values.decodeIfPresent(type(of: showHiddenInSearch), forKey: .showHiddenInSearch) ?? showHiddenInSearch
        descendingSort = try values.decodeIfPresent(type(of: descendingSort), forKey: .descendingSort) ?? descendingSort
        optionToUninstall = try values.decodeIfPresent(type(of: optionToUninstall), forKey: .optionToUninstall) ?? optionToUninstall
        showFavorites = try values.decodeIfPresent(type(of: showFavorites), forKey: .showFavorites) ?? showFavorites
        showMenuBarIcon = try values.decodeIfPresent(type(of: showMenuBarIcon), forKey: .showMenuBarIcon) ?? showMenuBarIcon
        updateFeedURL = try values.decodeIfPresent(String.self, forKey: .updateFeedURL) ?? ""
        customSources = try values.decodeIfPresent(type(of: customSources), forKey: .customSources) ?? customSources
    }
    public var pageSize: Int { max(1, columns * rows) }
}
public struct LibraryState: Codable, Equatable, Sendable {
    public var version = 1
    public var apps: [AppRecord] = []
    public var items: [LayoutItem] = []
    public var preferences = Preferences()
    public var profiles: [LayoutProfile]?
    public init() {}
    public mutating func reconcile(_ discovered: [AppRecord], preservingMissingFrom sources: [String] = []) {
        let old = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        apps = discovered.map { app in
            var result = app
            if let saved = old[app.id] {
                result.alias = saved.alias; result.hidden = saved.hidden; result.favorite = saved.favorite
                result.lastOpened = saved.lastOpened; result.added = saved.added
            }
            return result
        }
        let discoveredIDs = Set(apps.map(\.id))
        apps += old.values.filter { saved in !discoveredIDs.contains(saved.id) && sources.contains(where: { saved.path.hasPrefix($0 + "/") }) }.sorted { $0.name < $1.name }
        normalize()
    }
    public mutating func normalize() {
        preferences.columns = min(15, max(3, preferences.columns))
        preferences.rows = min(15, max(2, preferences.rows))
        preferences.blur = min(60, max(0, preferences.blur))
        preferences.tint = min(0.9, max(0, preferences.tint))
        preferences.hotCornerDelay = min(1.5, max(0.2, preferences.hotCornerDelay))
        if ![0, 3, 4, 5].contains(preferences.gestureFingers) { preferences.gestureFingers = 0 }
        if !["System", "Light", "Dark"].contains(preferences.appearance) { preferences.appearance = "System" }
        if !["Default", "Monochrome", "Tinted"].contains(preferences.iconStyle) { preferences.iconStyle = "Default" }
        let valid = Set(apps.filter { !$0.hidden }.map(\.id))
        var seen = Set<String>(); var itemIDs = Set<String>()
        items = items.compactMap { item in
            var next = item
            if item.isSpacer { next.apps = []; next.name = nil; if !itemIDs.insert(next.id).inserted { next.id = UUID().uuidString }; return next }
            next.apps = item.apps.filter { valid.contains($0) && seen.insert($0).inserted }
            guard !next.apps.isEmpty else { return nil }
            if next.apps.count == 1 { next = LayoutItem(app: next.apps[0]) }
            if !itemIDs.insert(next.id).inserted { next.id = UUID().uuidString }
            return next
        }
        while items.last?.isSpacer == true { items.removeLast() }
        for app in apps where valid.contains(app.id) && !seen.contains(app.id) { items.append(LayoutItem(app: app.id)); seen.insert(app.id) }
    }
    public mutating func move(_ ids: [String], before target: String?) {
        let wanted = Set(ids)
        let moving = items.filter { wanted.contains($0.id) }
        guard !moving.isEmpty, target.map({ !wanted.contains($0) }) ?? true else { return }
        items.removeAll { wanted.contains($0.id) }
        let index = target.flatMap { id in items.firstIndex { $0.id == id } } ?? items.count
        items.insert(contentsOf: moving, at: index)
    }
    public mutating func moveToPage(_ ids: [String], page: Int, pageSize: Int) {
        guard page >= 0, page < 1000, pageSize > 0 else { return }
        let wanted = Set(ids)
        let moving = items.filter { wanted.contains($0.id) && !$0.isSpacer }
        guard !moving.isEmpty else { return }
        // Leave slots behind to keep other pages in their existing positions.
        items = items.map { wanted.contains($0.id) ? LayoutItem(spacer: true) : $0 }
        let start = page * pageSize
        while items.count < start { items.append(LayoutItem(spacer: true)) }
        var cursor = start
        for item in moving {
            while cursor < min(items.count, start + pageSize) && !items[cursor].isSpacer { cursor += 1 }
            if cursor < items.count && cursor < start + pageSize { items[cursor] = item }
            else { items.insert(item, at: min(cursor, items.count)) }
            cursor += 1
        }
        normalize()
    }
    public mutating func group(_ ids: [String], into targetID: String?) {
        let wanted = Set(ids)
        guard targetID.map({ !wanted.contains($0) }) ?? true else { return }
        let moving = items.filter { wanted.contains($0.id) }.flatMap(\.apps)
        guard !moving.isEmpty else { return }
        let targetIndex = targetID.flatMap { id in items.firstIndex { $0.id == id } }
        let originalIndex = targetIndex ?? items.firstIndex { wanted.contains($0.id) } ?? items.count
        var folder: LayoutItem
        if let index = targetIndex {
            let target = items[index]
            folder = target.isFolder ? target : LayoutItem(folder: "New folder", apps: target.apps)
            folder.apps += moving
        } else { folder = LayoutItem(folder: "New folder", apps: moving) }
        let removedBefore = items.prefix(originalIndex).filter { wanted.contains($0.id) }.count
        items.removeAll { wanted.contains($0.id) || $0.id == targetID }
        items.insert(folder, at: min(max(0, originalIndex - removedBefore), items.count)); normalize()
    }
    public mutating func moveApps(_ appIDs: [String], into folderID: String?) {
        let wanted = Set(appIDs)
        if let folderID, !items.contains(where: { $0.id == folderID && $0.isFolder }) { return }
        for i in items.indices { items[i].apps.removeAll { wanted.contains($0) } }
        if let folderID, let index = items.firstIndex(where: { $0.id == folderID }) { items[index].apps += appIDs }
        else { items += appIDs.map { LayoutItem(app: $0) } }
        normalize()
    }
    public mutating func moveWithinFolder(_ appIDs: [String], folderID: String, before target: String?) {
        guard let index = items.firstIndex(where: { $0.id == folderID && $0.isFolder }) else { return }
        let wanted = Set(appIDs)
        guard target.map({ !wanted.contains($0) }) ?? true else { return }
        let moving = items[index].apps.filter { wanted.contains($0) }
        items[index].apps.removeAll { wanted.contains($0) }
        let insertion = target.flatMap { items[index].apps.firstIndex(of: $0) } ?? items[index].apps.count
        items[index].apps.insert(contentsOf: moving, at: insertion)
    }
    /// Replace selected page slots while preserving every unselected item and its relative order.
    public mutating func reorganizePages(_ pages: Set<Int>?, pageSize: Int, transform: ([LayoutItem]) -> [LayoutItem]) {
        guard pageSize > 0 else { return }
        guard let pages else { items = transform(items.filter { !$0.isSpacer }); normalize(); return }
        let indices = items.indices.filter { pages.contains($0 / pageSize) }
        guard let last = indices.last else { return }
        let replacements = transform(indices.map { items[$0] }.filter { !$0.isSpacer })
        let chosen = Set(indices); var cursor = 0; var result: [LayoutItem] = []
        for index in items.indices {
            if chosen.contains(index) {
                result.append(cursor < replacements.count ? replacements[cursor] : LayoutItem(spacer: true)); cursor += 1
            } else { result.append(items[index]) }
            if index == last && cursor < replacements.count { result.append(contentsOf: replacements[cursor...]); cursor = replacements.count }
        }
        items = result; normalize()
    }
    public mutating func dissolve(_ id: String) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.isFolder }) else { return }
        let children = items.remove(at: index).apps.map { LayoutItem(app: $0) }
        items.insert(contentsOf: children, at: index)
    }
    public mutating func restoreLayout(from backup: LibraryState) {
        let sources = preferences.customSources
        func matching(_ previous: AppRecord) -> AppRecord? {
            apps.first { $0.id == previous.id } ?? apps.first { !$0.bundleID.isEmpty && $0.bundleID == previous.bundleID }
        }
        let remap = Dictionary(uniqueKeysWithValues: backup.apps.compactMap { old in matching(old).map { (old.id, $0.id) } })
        func remappedItems(_ items: [LayoutItem], mapping: [String: String]) -> [LayoutItem] {
            items.compactMap { old in
                if old.isSpacer { return old }
                var item = old; item.apps = old.apps.compactMap { mapping[$0] }
                if !item.isFolder, let id = item.apps.first { item.id = id }
                return item.apps.isEmpty ? nil : item
            }
        }
        for previous in backup.apps {
            if let current = matching(previous), let i = apps.firstIndex(where: { $0.id == current.id }) {
                apps[i].alias = previous.alias; apps[i].hidden = previous.hidden
                apps[i].favorite = previous.favorite; apps[i].lastOpened = previous.lastOpened
            }
        }
        items = remappedItems(backup.items, mapping: remap)
        preferences = backup.preferences; preferences.customSources = sources
        profiles = backup.profiles?.map { saved in
            var result = saved
            let mapping = Dictionary(saved.apps.compactMap { old in matching(old).map { (old.id, $0.id) } }, uniquingKeysWith: { _, latest in latest })
            result.items = remappedItems(saved.items, mapping: mapping)
            result.apps = saved.apps.compactMap { previous in
                matching(previous).map { current in var current = current; current.alias = previous.alias; current.hidden = previous.hidden; current.favorite = previous.favorite; return current }
            }
            result.preferences.customSources = sources
            return result
        }
        normalize()
    }
    public mutating func saveProfile(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let profile = LayoutProfile(name: clean, items: items, preferences: preferences, apps: apps)
        if profiles == nil { profiles = [] }
        profiles?.append(profile)
    }
    public mutating func applyProfile(_ id: String) {
        guard let profile = profiles?.first(where: { $0.id == id }) else { return }
        items = profile.items; preferences = profile.preferences
        let metadata = Dictionary(profile.apps.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for i in apps.indices {
            if let saved = metadata[apps[i].id] { apps[i].alias = saved.alias; apps[i].hidden = saved.hidden; apps[i].favorite = saved.favorite }
        }
        normalize()
    }
    public func validated() throws -> LibraryState {
        guard version == 1 else { throw ValidationError.unsupportedVersion }
        guard Set(apps.map(\.id)).count == apps.count else { throw ValidationError.duplicateApps }
        guard apps.allSatisfy({ !$0.id.isEmpty && $0.path.hasPrefix("/") && $0.path.hasSuffix(".app") }) else { throw ValidationError.invalidPath }
        var copy = self; copy.normalize(); return copy
    }
    public enum ValidationError: Error { case unsupportedVersion, duplicateApps, invalidPath }
}
public enum AppSearch {
    public static func score(_ query: String, app: AppRecord) -> Int? {
        let q = fold(query).replacingOccurrences(of: " ", with: "")
        guard !q.isEmpty else { return 0 }
        let names = [app.displayName, app.name]
        return names.compactMap { name -> Int? in
            let plain = fold(name)
            let compact = plain.replacingOccurrences(of: " ", with: "")
            if compact == q { return 1000 }
            if compact.hasPrefix(q) { return 800 - compact.count }
            if compact.contains(q) { return 600 - compact.count }
            let words = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            let camel = name.enumerated().filter { $0.offset == 0 || $0.element.isUppercase }.map { String($0.element) }.joined()
            let initials = words.compactMap(\.first).map(String.init).joined()
            if fold(initials).hasPrefix(q) || fold(camel).hasPrefix(q) { return 500 }
            let pinyin = name.applyingTransform(.toLatin, reverse: false) ?? name
            let latin = fold(pinyin).replacingOccurrences(of: " ", with: "")
            if latin.hasPrefix(q) { return 450 }
            let pinyinInitials = pinyin.split(separator: " ").compactMap(\.first).map(String.init).joined()
            if fold(pinyinInitials).hasPrefix(q) { return 400 }
            var cursor = q.startIndex
            for c in compact where cursor != q.endIndex { if c == q[cursor] { cursor = q.index(after: cursor) } }
            return cursor == q.endIndex ? 100 - compact.count : nil
        }.max()
    }
    private static func fold(_ value: String) -> String { value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
}

public struct LayoutProfile: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID().uuidString
    public var name: String
    public var items: [LayoutItem]
    public var preferences: Preferences
    public var apps: [AppRecord]
    public init(name: String, items: [LayoutItem], preferences: Preferences, apps: [AppRecord]) {
        self.name = name; self.items = items; self.preferences = preferences; self.apps = apps
    }
}
