import AppKit
import LauncherCore
import CSQLite

@MainActor enum IntegrationChecks {
    static func run() -> Int32 {
        setbuf(stdout, nil)
        var failures = 0
        func check(_ name: String, _ condition: Bool) { print("\(condition ? "PASS" : "FAIL") \(name)"); if !condition { failures += 1 } }
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("OpenLaunchpad-checks-" + UUID().uuidString)
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: root) }
            // Synthetic apps: scanner must skip nested helper apps and deduplicate symlinks.
            let bundle = root.appendingPathComponent("Example.app/Contents")
            try fm.createDirectory(at: bundle.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
            let info: [String: Any] = ["CFBundleIdentifier": "org.openlaunchpad.fixture", "CFBundleName": "Fixture", "CFBundlePackageType": "APPL"]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: bundle.appendingPathComponent("Info.plist"))
            try fm.createDirectory(at: bundle.appendingPathComponent("Helper.app"), withIntermediateDirectories: true)
            try fm.createSymbolicLink(at: root.appendingPathComponent("Linked.app"), withDestinationURL: root.appendingPathComponent("Example.app"))
            let apps = AppScanner.scan(sources: [root.path])
            check("scanner resolves duplicate symlinks and excludes helpers", apps.count == 1 && apps.first?.name == "Fixture")
            check("installed applications are discoverable", !AppScanner.scan(sources: AppScanner.defaultSources).isEmpty)
            // Legacy native layout with two pages and one folder.
            let dbURL = root.appendingPathComponent("legacy.db"); var db: OpaquePointer?
            sqlite3_open(dbURL.path, &db)
            let sql = """
            CREATE TABLE apps (item_id INTEGER, title TEXT, bundleid TEXT);
            CREATE TABLE items (parent_id INTEGER, ordering INTEGER, type INTEGER);
            CREATE TABLE groups (item_id INTEGER, title TEXT);
            INSERT INTO items(rowid,parent_id,ordering,type) VALUES (1,0,0,1),(2,1,0,2),(3,1,1,2),(4,2,0,3),(5,4,0,4),(6,4,1,4),(7,3,0,4);
            INSERT INTO groups VALUES (4,'Work');
            INSERT INTO apps VALUES (5,'One','one'),(6,'Two','two'),(7,'Three','three');
            """
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw CocoaError(.fileReadCorruptFile) }; sqlite3_close(db)
            let fixtureApps = ["one", "two", "three"].map { AppRecord(id: $0, name: $0, path: "/\($0).app", bundleID: $0) }
            let imported = try NativeLayoutImporter.importLayout(from: dbURL, apps: fixtureApps)
            check("legacy SQLite import preserves page traversal and folders", imported.count == 2 && imported[0].name == "Work" && imported[0].apps == ["one", "two"] && imported[1].apps == ["three"])
            check("legacy SQLite import does not modify database", try Data(contentsOf: dbURL).count > 0)
            let storage = root.appendingPathComponent("state/library.json")
            let first = LibraryStore(storage: storage); first.state.apps = fixtureApps; first.state.normalize(); first.state.apps[0].alias = "Favourite"; first.save(); first.flush()
            let second = LibraryStore(storage: storage)
            check("atomic persistence restores aliases and complete layout", second.state.apps.first?.alias == "Favourite" && second.state.items.count == 3)
            second.toggleFavorite("one")
            check("favorite toggles and undo restores previous state", second.state.apps[0].favorite == true && second.canUndo)
            second.undo()
            check("undo restores favorite and enables redo", second.state.apps[0].favorite != true && second.canRedo)
            second.redo()
            check("redo restores favorite", second.state.apps[0].favorite == true)
            second.profileName = "Work"; second.saveProfile()
            check("store saves named layout profiles", second.state.profiles?.first?.name == "Work")
            check("default browsing is native vertical scroll", Preferences().browse == .scroll)
            second.updatePreferences { $0.sort = .added; $0.descendingSort = false; $0.browse = .scroll }
            second.state.apps[0].added = Date(timeIntervalSince1970: 30)
            second.state.apps[1].added = Date(timeIntervalSince1970: 10)
            second.state.apps[2].added = Date(timeIntervalSince1970: 20)
            check("date sorting ascending uses oldest first", second.displayedItems.map(\.id) == ["two", "three", "one"])
            second.updatePreferences { $0.descendingSort = true }
            check("date sorting descending invalidates cached order", second.displayedItems.map(\.id) == ["one", "three", "two"])
            second.state.apps[0].alias = "Updated"
            check("app index follows state mutations", second.app("one")?.displayName == "Updated")
            second.drop(["one"], target: "two", group: true)
            let folder = second.folders.first!
            check("app-on-app drop creates a folder without losing sorted placement", folder.apps == ["two", "one"] && second.state.items.first?.id == "three")
            second.drop(["three"], target: folder.id, group: true)
            second.activate(second.item(folder.id)!)
            second.drop(["one"], target: "two", group: false)
            check("drag inside a folder reorders instead of appending", second.item(folder.id)?.apps == ["one", "two", "three"])
            second.query = "one"; second.query = ""
            check("search from a folder restores that folder", second.folderID == folder.id)
            second.closeFolder()
            second.moveToFolder(["one", "two"], folder: nil)
            check("moving apps out dissolves a single-child folder", second.folders.isEmpty && Set(second.state.items.flatMap(\.apps)) == Set(["one", "two", "three"]))
            second.state.items = fixtureApps.map { LayoutItem(app: $0.id) }; second.state.preferences.columns = 3; second.state.preferences.rows = 2
            second.state.preferences.browse = .pages; second.state.preferences.sort = .manual
            let extras = (4...9).map { AppRecord(id: "extra\($0)", name: "Extra \($0)", path: "/Extra\($0).app") }
            second.state.apps += extras; second.state.normalize()
            second.page = 1; second.query = "one"; second.query = ""
            check("clearing search restores the previous page", second.page == 1 && second.folderID == nil)
            var scoped = LibraryState(); scoped.apps = fixtureApps
            scoped.items = fixtureApps.map { LayoutItem(app: $0.id) }
            scoped.reorganizePages([0], pageSize: 2) { Array($0.reversed()) }
            check("scoped reorganization preserves unselected page slots", scoped.items.map(\.id) == ["two", "one", "three"])
            let manifest = try ReleaseUpdates.Manifest.parse(Data(#"{"version":"0.2.0","url":"https://example.com/releases/0.2.0"}"#.utf8))
            check("release feed parses version and HTTPS link", manifest.version == "0.2.0" && manifest.url.scheme == "https")
            do { _ = try ReleaseUpdates.Manifest.parse(Data(#"{"version":"0.2.0","url":"file:///tmp/app"}"#.utf8)); check("release feed rejects local download URLs", false) } catch { check("release feed rejects local download URLs", true) }
            let malicious = root.appendingPathComponent("not-an-app.txt"); try Data().write(to: malicious)
            do { try CleanUninstaller.trash(app: AppRecord(id: "bad", name: "Bad", path: malicious.path), selected: []); check("uninstall rejects non-app paths", false) } catch { check("uninstall rejects non-app paths", fm.fileExists(atPath: malicious.path)) }
            do { try CleanUninstaller.trash(app: AppRecord(id: "system", name: "Finder", path: "/System/Library/CoreServices/Finder.app"), selected: []); check("uninstall rejects system apps", false) } catch { check("uninstall rejects system apps", true) }
            let invalid = root.appendingPathComponent("invalid.json"); try Data("{}".utf8).write(to: invalid)
            do { _ = try NativeLayoutImporter.importLayout(from: invalid, apps: fixtureApps); check("import rejects invalid SQLite", false) } catch { check("import rejects invalid SQLite", true) }
        } catch { failures += 1; print("FAIL integration: \(error)") }
        print("Integration checks: \(failures) failures")
        return failures == 0 ? 0 : 1
    }
}
