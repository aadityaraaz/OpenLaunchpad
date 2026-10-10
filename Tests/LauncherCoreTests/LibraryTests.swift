import Foundation
import LauncherCore

private func library(_ count: Int = 5) -> LibraryState {
    var state = LibraryState()
    state.apps = (0..<count).map { AppRecord(id: "app\($0)", name: "App \($0)", path: "/Applications/App\($0).app") }
    state.normalize(); return state
}
func groupingAndDissolvingPreservesOrder() {
    var state = library()
    state.group(["app1", "app2"], into: "app0")
    expect(state.items.count == 3)
    expect(state.items[0].apps == ["app0", "app1", "app2"])
    let folder = state.items[0].id; state.dissolve(folder)
    expect(state.items.map(\.id) == ["app0", "app1", "app2", "app3", "app4"])
}
func movingOutOfFolderDissolvesLastChild() {
    var state = library(); state.group(["app1"], into: "app0")
    state.moveApps(["app1"], into: nil)
    expect(!state.items.contains(where: \.isFolder))
    expect(state.items.flatMap(\.apps).count == 5)
    expect(Set(state.items.flatMap(\.apps)).count == 5)
}
func mergeFoldersNeverDuplicatesApps() {
    var state = library(6); state.group(["app1"], into: "app0"); let a = state.items[0].id
    state.group(["app3"], into: "app2"); let b = state.items.first { $0.apps.contains("app2") }!.id
    state.group([a], into: b)
    expect(state.items.filter(\.isFolder).count == 1)
    expect(Set(state.items.flatMap(\.apps)).count == 6)
}
func hideAndRestoreMaintainsInvariant() {
    var state = library(); state.group(["app1"], into: "app0")
    state.apps[0].hidden = true; state.normalize()
    expect(!state.items.flatMap(\.apps).contains("app0"))
    expect(!state.items.contains(where: \.isFolder))
    state.apps[0].hidden = false; state.normalize()
    expect(Set(state.items.flatMap(\.apps)).count == 5)
}
func normalizationRepairsMalformedLayout() {
    var state = library()
    state.items = [LayoutItem(folder: "Bad", apps: ["app0", "app0", "missing"]), LayoutItem(app: "app1"), LayoutItem(app: "app1")]
    state.preferences.columns = -8; state.preferences.rows = 900; state.normalize()
    expect(state.items.count == 5)
    expect(Set(state.items.flatMap(\.apps)).count == 5)
    expect(state.preferences.columns == 3)
    expect(state.preferences.rows == 15)
}
func batchMoveUsesVisualOrder() {
    var state = library(); state.move(["app3", "app1"], before: "app0")
    expect(state.items.map(\.id) == ["app1", "app3", "app0", "app2", "app4"])
    let before = state; state.move(["app1"], before: "app1"); expect(state == before)
}
func backupRoundTripAndValidation() throws {
    var state = library(); state.group(["app1"], into: "app0"); state.apps[2].alias = "My editor"
    let data = try JSONEncoder().encode(state)
    try expect(try JSONDecoder().decode(LibraryState.self, from: data).validated() == state)
    state.apps.append(state.apps[0]); expectThrows { try state.validated() }
}
func scannerReconciliationPreservesAliasesAndRecentTimes() {
    var state = library(); state.apps[0].alias = "Favourite"; state.apps[0].lastOpened = Date(timeIntervalSince1970: 99)
    state.reconcile([AppRecord(id: "app0", name: "Updated App", path: "/Applications/New.app"), AppRecord(id: "new", name: "New", path: "/Applications/New2.app")])
    expect(state.apps[0].alias == "Favourite"); expect(state.apps[0].lastOpened == Date(timeIntervalSince1970: 99))
    expect(state.items.map(\.id) == ["app0", "new"])
}
func searchRanksExactPrefixAndInitials() {
    let app = AppRecord(id: "a", name: "Visual Studio Code", path: "/Applications/Code.app", alias: "Editor")
    expect(AppSearch.score("editor", app: app) == 1000)
    expect(AppSearch.score("vsc", app: app) == 500)
    expect(AppSearch.score("studio", app: app) != nil)
    expect(AppSearch.score("zzzz", app: app) == nil)
    expect(AppSearch.score("vis", app: app)! > AppSearch.score("studio", app: app)!)
}
func searchHandlesAccentsCamelCaseAndChinese() {
    expect(AppSearch.score("cafe", app: AppRecord(id: "a", name: "Café", path: "/a.app")) == 1000)
    expect(AppSearch.score("qc", app: AppRecord(id: "b", name: "QuickCapture", path: "/b.app")) == 500)
    let chinese = AppRecord(id: "c", name: "计算器", path: "/c.app")
    expect(AppSearch.score("jisuanqi", app: chinese) != nil)
    expect(AppSearch.score("jsq", app: chinese) != nil)
}
private func fingers(radius: Double) -> [TouchPoint] { (0..<4).map { i in let a = Double(i) * .pi / 2; return TouchPoint(x: 0.5 + cos(a) * radius, y: 0.5 + sin(a) * radius) } }
func pinchCommitsOnceAndIgnoresWrongFingerCount() {
    var tracker = PinchTracker(); _ = tracker.update(points: fingers(radius: 0.3), fingers: 4, closing: false, time: 0)
    let result = tracker.update(points: fingers(radius: 0.17), fingers: 4, closing: false, time: 0.2)
    expect(result.committed)
    expect(!tracker.update(points: fingers(radius: 0.15), fingers: 4, closing: false, time: 0.3).committed)
    expect(tracker.update(points: [], fingers: 4, closing: false, time: 0.4).finished)
    expect(!tracker.update(points: fingers(radius: 0.1), fingers: 3, closing: false, time: 0.5).committed)
}
func spreadCommitsAndSmallPinchCancels() {
    var tracker = PinchTracker(); _ = tracker.update(points: fingers(radius: 0.15), fingers: 4, closing: true, time: 0)
    expect(tracker.update(points: fingers(radius: 0.23), fingers: 4, closing: true, time: 0.2).committed)
    tracker = PinchTracker(); _ = tracker.update(points: fingers(radius: 0.3), fingers: 4, closing: false, time: 0)
    _ = tracker.update(points: fingers(radius: 0.29), fingers: 4, closing: false, time: 0.2)
    expect(!tracker.update(points: [], fingers: 4, closing: false, time: 0.3).committed)
}

func explicitPageMovePreservesOtherPages() {
    var state = library(5)
    state.moveToPage(["app0"], page: 2, pageSize: 4)
    expect(state.items[0].isSpacer)
    expect(state.items[8].id == "app0")
    expect(state.items[4].id == "app4")
    expect(Set(state.items.flatMap(\.apps)).count == 5)
    state.normalize(); expect(state.items[8].id == "app0")
}
func olderPreferencesDecodeWithNewDefaults() throws {
    let preferences = try JSONDecoder().decode(Preferences.self, from: Data("{\"columns\":5}".utf8))
    expect(preferences.columns == 5 && preferences.gestureFingers == 0 && preferences.rows == 5)
}
func disconnectedSourceRetainsLayout() {
    var state = library(2); state.apps[1].path = "/Volumes/External/Example.app"
    state.reconcile([state.apps[0]], preservingMissingFrom: ["/Volumes/External"])
    expect(state.items.map(\.id) == ["app0", "app1"])
}
func profilesRestoreLayoutAndPreferences() {
    var state = library(); state.saveProfile(name: "Work")
    let id = state.profiles![0].id
    state.group(["app1"], into: "app0"); state.preferences.rows = 8; state.apps[0].hidden = true
    state.applyProfile(id)
    expect(state.items.map(\.id) == ["app0", "app1", "app2", "app3", "app4"])
    expect(state.preferences.rows == 5 && !state.apps[0].hidden)
    expect(state.profiles?.count == 1)
}
func restoreRemapsAppsPreservesPageSlotsAndLocalSources() {
    var backup = library(2); backup.apps[0].bundleID = "one"; backup.apps[1].bundleID = "two"
    backup.apps[0].alias = "My app"; backup.moveToPage(["app1"], page: 1, pageSize: 4)
    var local = LibraryState(); local.apps = [AppRecord(id: "local-one", name: "One", path: "/Applications/One.app", bundleID: "one"), AppRecord(id: "local-two", name: "Two", path: "/Applications/Two.app", bundleID: "two")]
    local.preferences.customSources = ["/Volumes/Trusted"]
    local.restoreLayout(from: backup)
    expect(local.apps[0].path == "/Applications/One.app" && local.apps[0].alias == "My app")
    expect(local.items[4].id == "local-two" && local.items[1].isSpacer)
    expect(local.preferences.customSources == ["/Volumes/Trusted"])
}
private var failures = 0
private func expect(_ condition: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) rethrows {
    if try !condition() { failures += 1; print("FAIL \(file):\(line)") }
}
private func expectThrows<T>(_ body: () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try body(); failures += 1; print("FAIL expected error \(file):\(line)") } catch { }
}
@main struct CoreChecks {
    static func main() throws {
        let checks: [(String, () throws -> Void)] = [
            ("group + dissolve", groupingAndDissolvingPreservesOrder),
            ("folder extraction", movingOutOfFolderDissolvesLastChild),
            ("merge folders", mergeFoldersNeverDuplicatesApps),
            ("hide + restore", hideAndRestoreMaintainsInvariant),
            ("repair malformed layouts", normalizationRepairsMalformedLayout),
            ("batch order", batchMoveUsesVisualOrder),
            ("backup validation", backupRoundTripAndValidation),
            ("reconcile", scannerReconciliationPreservesAliasesAndRecentTimes),
            ("search ranking", searchRanksExactPrefixAndInitials),
            ("unicode search", searchHandlesAccentsCamelCaseAndChinese),
            ("pinch gesture", pinchCommitsOnceAndIgnoresWrongFingerCount),
            ("spread gesture", spreadCommitsAndSmallPinchCancels),
            ("explicit pages", explicitPageMovePreservesOtherPages),
            ("older preferences", olderPreferencesDecodeWithNewDefaults),
            ("disconnected sources", disconnectedSourceRetainsLayout),
            ("layout profiles", profilesRestoreLayoutAndPreferences),
            ("backup remapping + slots", restoreRemapsAppsPreservesPageSlotsAndLocalSources)
        ]
        for (name, check) in checks { let before = failures; do { try check() } catch { failures += 1; print("FAIL \(name): \(error)") }; if failures == before { print("PASS \(name)") } }
        print("\(checks.count) checks, \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
