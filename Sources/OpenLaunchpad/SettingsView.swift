import SwiftUI
import AppKit
import Carbon
import LauncherCore
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store: LibraryStore
    @ViewState private var section = "General"
    @ViewState private var appFilter = ""
    @ViewState private var recording = false
    @ViewState private var keyMonitor: Any?
    @ViewState private var loginEnabled = SMAppService.mainApp.status == .enabled
    private let sections = [("General", "slider.horizontal.3"), ("Appearance", "paintpalette"), ("Layout", "square.grid.3x3"), ("Applications", "app.badge"), ("Sources", "externaldrive"), ("Profiles", "square.stack"), ("Backups", "arrow.triangle.2.circlepath"), ("About", "info.circle")]
    private var classic: Bool { store.preferences.interfaceStyle == "Classic" }
    var body: some View {
        Group { if classic { classicSettings } else { sidebarSettings } }
            .frame(width: classic ? 400 : 790, height: classic ? 560 : 620)
            .toggleStyle(SettingsSwitchStyle())
            .font(.system(size: 13))
            .controlSize(.small)
            .alert("OpenLaunchpad", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) { if let url = store.updateURL { Button("View Release") { NSWorkspace.shared.open(url); store.updateURL = nil; store.message = nil } }; Button("OK") { store.message = nil } } message: { Text(store.message ?? "") }
            .onDisappear { stopRecording() }
    }
    private var classicSettings: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach([( "General", "gearshape"), ("Interface", "circles.hexagongrid"), ("Apps", "app"), ("Advanced", "slider.horizontal.3"), ("About", "info.circle")], id: \.0) { tab in
                    Button { section = tab.0 } label: {
                        VStack(spacing: 6) { Image(systemName: tab.1).font(.system(size: 20, weight: .regular)); Text(tab.0).font(.system(size: 12, weight: .medium)) }
                            .foregroundStyle(section == tab.0 ? Color.accentColor : Color.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(section == tab.0 ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
            Divider()
            ScrollView { LazyVStack(alignment: .leading, spacing: 24) {
                switch section {
                case "Interface", "Appearance", "Layout": referenceInterface
                case "Apps", "Applications", "Sources": sources; applications
                case "Advanced", "Backups", "Profiles": profiles; backups
                case "About": about
                default: general
                }
            }.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 24) }
            .background(Color.primary.opacity(0.015))
        }
    }
    private var sidebarSettings: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Label("OpenLaunchpad", systemImage: "square.grid.3x3.fill").font(.headline).padding(.vertical, 23).padding(.horizontal, 16)
                ForEach(sections, id: \.0) { entry in
                    Button { section = entry.0 } label: { Label(entry.0, systemImage: entry.1).font(.system(size: 13, weight: section == entry.0 ? .semibold : .regular)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 10).background(section == entry.0 ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain)
                }
                Spacer()
                Text("FREE. FOREVER.").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.6).foregroundStyle(.secondary).padding(18)
            }.padding(.horizontal, 10).frame(width: 190).background(.ultraThinMaterial)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) { Text(section).font(.system(size: 28, weight: .semibold, design: .rounded)); Text(subtitle).font(.callout).foregroundStyle(.secondary) }
                    content
                }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
            }
        }

    }
    private var subtitle: String {
        switch section {
        case "General": return "Make it part of your everyday flow."
        case "Appearance": return "A familiar feel. A space that’s yours."
        case "Layout": return "Keep everything right where you want it."
        case "Applications": return "Your library, without the clutter."
        case "Sources": return "Find apps wherever they live."
        case "Backups": return "Take your organization with you."
        default: return "An open home for your applications."
        }
    }
    private func binding<T>(_ path: WritableKeyPath<Preferences, T>) -> Binding<T> { Binding(get: { store.preferences[keyPath: path] }, set: { value in store.updatePreferences { $0[keyPath: path] = value } }) }
    @ViewBuilder private var content: some View {
        switch section {
        case "General": general
        case "Appearance": appearance
        case "Layout": layout
        case "Applications": applications
        case "Sources": sources
        case "Profiles": profiles
        case "Backups": backups
        default: about
        }
    }
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 10)
            Group(subviews: content()) { rows in
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        row.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 10)
                        if row.id != rows.last?.id { Divider().opacity(0.45).padding(.horizontal, 12) }
                    }
                }
            }
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
        }
    }
    private func choice<Value: Hashable, Options: View>(_ title: String, selection: Binding<Value>, @ViewBuilder options: () -> Options) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 4)
            Picker(title, selection: selection, content: options).labelsHidden().fixedSize()
        }
    }
    private var loginBinding: Binding<Bool> { Binding(get: { loginEnabled }, set: { enabled in
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginEnabled = SMAppService.mainApp.status == .enabled }
        catch { store.message = "Login item could not be changed: \(error.localizedDescription)" }
    }) }
    private var general: some View {
        VStack(spacing: 24) {
            card("Launch") { Toggle("Start at Login", isOn: loginBinding) }
            card("Controls") {
                HStack { Text("Hotkey"); Spacer(); Button(recording ? "Press shortcut…" : store.preferences.shortcutLabel) { recording ? stopRecording() : startRecording() }.frame(minWidth: 100) }
                Toggle("System F4 Key", isOn: binding(\.useF4)).help("Use Fn–F4 if F4 is assigned to Spotlight.")
                choice("Trackpad", selection: binding(\.gestureFingers)) { Text("Off").tag(0); Text("Pinch with 3 fingers").tag(3); Text("Pinch with 4 fingers").tag(4); Text("Pinch with 5 fingers").tag(5) }
                if store.preferences.gestureFingers != 0 { Text("Experimental. Choose a gesture unused by macOS. System gestures are not blocked.").font(.caption).foregroundStyle(.secondary) }
                choice("Hot Corner", selection: binding(\.hotCorner)) { ForEach(["Off", "Top left", "Top right", "Bottom left", "Bottom right"], id: \.self) { Text($0) } }
                if store.preferences.hotCorner != "Off" { HStack { Text("Corner delay"); Slider(value: binding(\.hotCornerDelay), in: 0.2...1.5); Text(String(format: "%.1f s", store.preferences.hotCornerDelay)).monospacedDigit() } }
                HStack { Text("Multi-Select"); Spacer(); Text("⌘ + Click or Drag").foregroundStyle(.secondary) }
            }
            card("Appearance") {
                Toggle("Show Menu Bar Icon", isOn: binding(\.showMenuBarIcon))
                HStack {
                    Text("App Icon"); Spacer()
                    ForEach(["Grid", "Rocket"], id: \.self) { mode in
                        Button { store.updatePreferences { $0.launcherIcon = mode } } label: {
                            Image(nsImage: mode == "Grid" ? LauncherIcon.grid() ?? NSImage() : LauncherIcon.rocket()).resizable().scaledToFit().frame(width: 28, height: 28)
                                .padding(3).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.preferences.launcherIcon == mode ? Color.accentColor : .clear, lineWidth: 1.5))
                        }.buttonStyle(.plain).accessibilityLabel(mode == "Grid" ? "Apps Icon" : "Rocket Icon")
                    }
                }
            }
            card("Window") {
                Toggle("Fullscreen", isOn: binding(\.fullscreen))
                choice("Open on", selection: binding(\.display)) { ForEach(DisplayMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Toggle("Hide Dock in Fullscreen", isOn: binding(\.hideDock)).disabled(!store.preferences.fullscreen)
                choice("Return to First Page", selection: binding(\.resetAfter)) { Text("Never").tag(-1.0); Text("Every time").tag(0.0); Text("After 30 seconds").tag(30.0); Text("After 5 minutes").tag(300.0) }
            }
        }
    }
    private var referenceInterface: some View {
        VStack(alignment: .leading, spacing: 26) {
            grouped {
                HStack(alignment: .top, spacing: 12) {
                    Text("Display Mode").padding(.top, 3)
                    Spacer(minLength: 0)
                    displayChoice("Full Screen", fullscreen: true)
                    displayChoice("Window", fullscreen: false)
                }.padding(.vertical, 4)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Layout").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 10)
                grouped {
                    HStack {
                        Text("Sort By")
                        Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(.secondary).help("Sort the visible apps. Custom keeps your manual layout.")
                        Spacer()
                        // A native single-selection picker avoids inheriting the
                        // settings switch style inside the popup's menu rows.
                        Picker("Sort By", selection: binding(\.sort)) {
                            ForEach(SortMode.allCases, id: \.self) { mode in
                                Text(mode == .manual ? "Custom" : mode.rawValue).tag(mode)
                            }
                        }.pickerStyle(.menu).labelsHidden().fixedSize()
                    }
                    HStack {
                        Text("Order"); Spacer()
                        radio("A → Z", selected: !store.preferences.descendingSort) { store.updatePreferences { $0.descendingSort = false } }
                        radio("Z → A", selected: store.preferences.descendingSort) { store.updatePreferences { $0.descendingSort = true } }
                    }.disabled(store.preferences.sort == .manual)
                }
                grouped {
                    HStack {
                        Text("Browsing Style"); Spacer(minLength: 6)
                        radio("Paged", selected: store.preferences.browse == .pages) { store.updatePreferences { $0.browse = .pages } }
                        radio("Scroll", selected: store.preferences.browse == .scroll) { store.updatePreferences { $0.browse = .scroll } }
                    }
                    HStack {
                        Text("Icon Grid"); Spacer()
                        gridField(binding(\.columns), range: 3...15, label: "Columns")
                        Image(systemName: "multiply").foregroundStyle(.tertiary)
                        gridField(binding(\.rows), range: 2...15, label: "Rows")
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack { Text("Fill Empty Slots"); Spacer(); Button("Reorganize") { store.organize("Fill empty slots") } }
                        Text("Moves apps forward to fill empty slots based on the current row and column layout.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                grouped {
                    Toggle("Hide Names", isOn: Binding(get: { !store.preferences.showAppNames && !store.preferences.showFolderNames }, set: { hidden in store.updatePreferences { $0.showAppNames = !hidden; $0.showFolderNames = !hidden } }))
                }
            }
            DisclosureGroup("More Appearance Options") {
                VStack(spacing: 18) { appearance; extraOrganization }.padding(.top, 14)
            }.font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 8)
        }
    }
    private func grouped<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Group(subviews: content()) { rows in
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    row.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 11).padding(.vertical, 9)
                    if row.id != rows.last?.id { Divider().opacity(0.4).padding(.horizontal, 11) }
                }
            }
        }.background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
    }
    private func radio(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ZStack {
                    Circle().fill(Color.primary.opacity(selected ? 0.24 : 0.11)).frame(width: 16, height: 16)
                    if selected { Circle().fill(Color.primary.opacity(0.9)).frame(width: 5, height: 5) }
                }
                Text(title).fixedSize()
            }
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func gridField(_ value: Binding<Int>, range: ClosedRange<Int>, label: String) -> some View {
        HStack(spacing: 0) {
            TextField(label, value: value, format: .number).textFieldStyle(.plain).multilineTextAlignment(.center).frame(width: 30)
                .onSubmit { value.wrappedValue = min(range.upperBound, max(range.lowerBound, value.wrappedValue)) }
            Stepper(label, value: value, in: range).labelsHidden().controlSize(.mini).frame(width: 17)
        }.padding(.vertical, 2).padding(.horizontal, 3).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.12)))
            .accessibilityElement(children: .contain).accessibilityLabel(label)
    }
    private func displayChoice(_ title: String, fullscreen: Bool) -> some View {
        Button { store.updatePreferences { $0.fullscreen = fullscreen } } label: {
            VStack(spacing: 5) {
                DisplayModePreview(windowed: !fullscreen)
                    .frame(width: 72, height: 48)
                    .padding(2)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.preferences.fullscreen == fullscreen ? Color.accentColor : .clear, lineWidth: 2))
                Text(title).font(.system(size: 12)).fixedSize()
            }
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(store.preferences.fullscreen == fullscreen ? .isSelected : [])
    }
    private var extraOrganization: some View {
        card("Organization") {
            Toggle("Reverse paging direction", isOn: Binding(get: { !store.preferences.naturalScroll }, set: { value in store.updatePreferences { $0.naturalScroll = !value } }))
            Button("Reorganize Layout…") { store.showReorganization?() }
            Button("Apply Current Sort to Custom Layout") { store.organize("Apply") }
            HStack { Button("Folders First") { store.organize("Folders first") }; Button("Folders Last") { store.organize("Folders last") } }
            Button("Apple Apps First") { store.organize("Apple apps first") }
            Button("Ungroup All Folders") { store.organize("Ungroup folders") }
        }
    }
    private var appearance: some View {
        VStack(spacing: 18) {
            card("Material") {
                choice("Interface style", selection: binding(\.interfaceStyle)) { Text("Classic Launchpad").tag("Classic"); Text("Workspace").tag("Workspace") }
                Toggle("Show pinned favorites", isOn: binding(\.showFavorites))
                choice("Appearance", selection: binding(\.appearance)) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }
                Toggle("Use desktop wallpaper", isOn: binding(\.wallpaper))
                HStack { Text("Wallpaper blur").frame(width: 115, alignment: .leading); Slider(value: binding(\.blur), in: 0...60); Text("\(Int(store.preferences.blur))").monospacedDigit().frame(width: 30) }.disabled(!store.preferences.wallpaper)
                HStack { Text("Material intensity").frame(width: 115, alignment: .leading); Slider(value: binding(\.tint), in: 0...0.9); Text("\(Int(store.preferences.tint * 100))%").monospacedDigit().frame(width: 38) }
                Text("Native Liquid Glass controls inherit macOS 27’s material rendering. Reduce Motion and Reduce Transparency are respected.").font(.caption).foregroundStyle(.secondary)
            }
            card("Icons & labels") {
                choice("Application icons", selection: binding(\.iconStyle)) { ForEach(["Default", "Monochrome", "Tinted"], id: \.self) { Text($0) } }
                choice("Launcher icon", selection: binding(\.launcherIcon)) { ForEach(["Grid", "Rocket"], id: \.self) { Text($0) } }
                Toggle("Show application names", isOn: binding(\.showAppNames))
                Toggle("Show folder names", isOn: binding(\.showFolderNames))
                Button("Refresh icon cache", systemImage: "arrow.clockwise") { store.refreshIcons() }.buttonStyle(.glass)
            }
        }
    }
    private var layout: some View {
        VStack(spacing: 18) {
            card("Grid") {
                choice("Scrolling", selection: binding(\.browse)) { Text("Vertical").tag(BrowseMode.scroll); Text("Horizontal pages").tag(BrowseMode.pages) }
                Stepper("Columns: \(store.preferences.columns)", value: binding(\.columns), in: 3...15)
                Stepper("Rows: \(store.preferences.rows)", value: binding(\.rows), in: 2...15)
                Toggle("Reverse paging direction", isOn: Binding(get: { !store.preferences.naturalScroll }, set: { value in store.updatePreferences { $0.naturalScroll = !value } }))
                Text("Icon sizes adjust automatically to the window, row count, and column count.").font(.caption).foregroundStyle(.secondary)
            }
            card("Organization") {
                choice("Sort by", selection: binding(\.sort)) { ForEach(SortMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Toggle("Descending order", isOn: binding(\.descendingSort)).disabled(store.preferences.sort == .manual)
                Button("Apply current sort to manual layout") { store.organize("Apply") }.buttonStyle(.glass)
                HStack { Button("Folders first") { store.organize("Folders first") }; Button("Folders last") { store.organize("Folders last") } }.buttonStyle(.glass)
                HStack { Button("Fill empty slots") { store.organize("Fill empty slots") }; Button("Apple apps first") { store.organize("Apple apps first") } }.buttonStyle(.glass)
                Button("Ungroup all folders") { store.organize("Ungroup folders") }.buttonStyle(.glass)
                Text("Drag an icon onto the center of another to create a folder. Drop beside an icon to reorder. ⌘ click selects several items.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var applications: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            Toggle("Hold Option to Uninstall", isOn: binding(\.optionToUninstall))
            Toggle("Include hidden apps in search", isOn: binding(\.showHiddenInSearch))
            HStack { TextField("Filter applications", text: $appFilter).textFieldStyle(.roundedBorder); Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.glass) }
            Text("\(store.state.apps.count) installed · \(store.state.apps.filter(\.hidden).count) hidden").font(.caption).foregroundStyle(.secondary)
            ForEach(store.state.apps.filter { appFilter.isEmpty || $0.displayName.localizedCaseInsensitiveContains(appFilter) }) { app in
                HStack(spacing: 12) {
                    Image(nsImage: IconCache.shared.icon(app)).resizable().frame(width: 35, height: 35)
                    VStack(alignment: .leading, spacing: 3) { Text(app.displayName).font(.callout.weight(.medium)); Text(app.path).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle) }
                    Spacer()
                    Button(app.hidden ? "Restore" : "Hide") { app.hidden ? store.restore(app.id) : store.hide([app.id]) }.buttonStyle(.glass)
                }.padding(10).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    private var sources: some View {
        VStack(alignment: .leading, spacing: 18) {
            card("Default locations") { ForEach(AppScanner.defaultSources, id: \.self) { Label($0.replacingOccurrences(of: NSHomeDirectory(), with: "~"), systemImage: "folder").font(.callout) } }
            card("Custom locations") {
                if store.preferences.customSources.isEmpty { Text("Add external drives, shared folders, or other app directories.").foregroundStyle(.secondary) }
                ForEach(store.preferences.customSources, id: \.self) { path in HStack { Label(path, systemImage: "externaldrive").font(.caption).lineLimit(1).truncationMode(.middle); Spacer(); Button { store.updatePreferences { $0.customSources.removeAll { $0 == path } }; store.refresh() } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain) } }
                Button("Add application folder…", systemImage: "plus") { store.addSource() }.buttonStyle(.glass)
                Text("Apps are deduplicated by resolved path; distinct versions are kept. Apps nested inside another app bundle are excluded. Aliases are resolved.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var profiles: some View {
        VStack(spacing: 18) {
            card("Save this space") {
                Text("Keep separate layouts for work, personal time, or presentations. Profiles save folders, aliases, hidden apps, favorites, and appearance preferences.").foregroundStyle(.secondary)
                HStack { TextField("Profile name", text: $store.profileName).textFieldStyle(.roundedBorder); Button("Save profile") { store.saveProfile() }.buttonStyle(.glass).disabled(store.profileName.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            card("Your profiles") {
                if (store.state.profiles ?? []).isEmpty { Text("Your saved layouts will appear here.").foregroundStyle(.secondary) }
                ForEach(store.state.profiles ?? []) { profile in
                    HStack { Image(systemName: "square.stack"); Text(profile.name); Spacer(); Button("Apply") { store.applyProfile(profile.id) }.buttonStyle(.glass); Button { store.removeProfile(profile.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain).help("Delete profile") }
                }
                TextField("HTTPS update manifest URL", text: binding(\.updateFeedURL)).textFieldStyle(.roundedBorder)
                Button(store.checkingUpdates ? "Checking…" : "Check for Updates…") { store.checkForUpdates() }.disabled(store.checkingUpdates)
                Text("Optional: your release feed. Downloads open for review; updates are not installed automatically.").font(.caption).foregroundStyle(.secondary)
                Button("Export diagnostics…") { store.exportDiagnostics() }.buttonStyle(.glass)
                Text("Applying or deleting a profile can be undone with ⌘Z from the launcher.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var backups: some View {
        VStack(spacing: 18) {
            card("Layout backups") {
                Text("Save folders, ordering, hidden apps, aliases, and preferences as an ordinary JSON file.").foregroundStyle(.secondary)
                HStack { Button("Export backup…", systemImage: "square.and.arrow.up") { store.exportBackup() }; Button("Restore backup…", systemImage: "square.and.arrow.down") { store.importBackup() } }.buttonStyle(.glass)
                Text("Restore matches apps installed on this Mac. Missing apps are skipped; new apps are appended. Imported paths are never used to launch applications.").font(.caption).foregroundStyle(.secondary)
            }
            card("Coming from Launchpad") {
                Text("Import ordering and folders from a legacy Launchpad SQLite database backup.").foregroundStyle(.secondary)
                Button("Import native Launchpad layout…") { NativeLayoutImporter.choose(store: store) }.buttonStyle(.glass)
                Text("Choose a db file from a pre-macOS 26 Dock database. Make a layout backup first. The system database is opened read-only.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var about: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "square.grid.3x3.fill").font(.system(size: 42)).foregroundStyle(.mint).padding(22).glassEffect(.regular, in: .rect(cornerRadius: 24))
            Text("Your apps. Your space.").font(.title.weight(.semibold))
            Text("OpenLaunchpad is an independent, native, open-source application launcher for macOS 26 and 27. All implemented features are free, with no licenses, subscriptions, or activation servers.").foregroundStyle(.secondary)
            card("Version 0.1.0 · MIT License") {
                Label("Works offline", systemImage: "wifi.slash")
                Label("No analytics or tracking", systemImage: "hand.raised")
                Label("SwiftUI + AppKit · no third-party dependencies", systemImage: "swift")
            }
            Text("Inspired by the classic Launchpad workflow. Not affiliated with Apple or LaunchOS. Global multifinger gestures are experimental. System icon-mode integration, localization, and signed automatic updates remain development work.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func startRecording() {
        recording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stopRecording(); return nil }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else { return nil }
            var modifiers: UInt32 = 0; var label = ""
            if flags.contains(.control) { modifiers |= UInt32(controlKey); label += "⌃" }
            if flags.contains(.option) { modifiers |= UInt32(optionKey); label += "⌥" }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey); label += "⇧" }
            if flags.contains(.command) { modifiers |= UInt32(cmdKey); label += "⌘" }
            label += event.keyCode == 49 ? "Space" : (event.charactersIgnoringModifiers ?? "Key \(event.keyCode)").uppercased()
            store.updatePreferences { $0.shortcutKey = UInt32(event.keyCode); $0.shortcutModifiers = modifiers; $0.shortcutLabel = label }
            stopRecording(); return nil
        }
    }
    private func stopRecording() { if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }; keyMonitor = nil; recording = false }
}

struct UninstallSheet: View {
    @ObservedObject var store: LibraryStore
    @ViewState private var selected = Set<String>()
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) { if let app = store.uninstallApp { Image(nsImage: IconCache.shared.icon(app)).resizable().frame(width: 54, height: 54); VStack(alignment: .leading) { Text("Uninstall \(app.displayName)?").font(.title2.weight(.semibold)); Text("Move the app and selected data to Trash.").foregroundStyle(.secondary) } } }
            Text("Only exact bundle-identifier matches in your Library are listed. Shared data and unrelated files are left alone. Containers can hold documents: review the list before continuing.").font(.caption).foregroundStyle(.secondary)
            if let app = store.uninstallApp { Label(app.path, systemImage: "app").font(.caption) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.uninstallFiles, id: \.path) { url in Toggle(url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"), isOn: Binding(get: { selected.contains(url.path) }, set: { if $0 { selected.insert(url.path) } else { selected.remove(url.path) } })).font(.caption) }
                    if store.uninstallFiles.isEmpty { Text("No matching leftover files found.").foregroundStyle(.secondary) }
                }
            }.frame(maxHeight: 180)
            HStack { Spacer(); Button("Cancel") { store.uninstallApp = nil }.keyboardShortcut(.cancelAction); Button("Move to Trash", role: .destructive) { store.uninstallFiles = store.uninstallFiles.filter { selected.contains($0.path) }; store.confirmUninstall() }.keyboardShortcut(.defaultAction) }
        }.padding(28).frame(width: 580).onAppear { selected = Set(store.uninstallFiles.filter { !$0.path.contains("/Containers/") }.map(\.path)) }
    }
}

struct AppInfoSheet: View {
    @ObservedObject var store: LibraryStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let app = store.infoApp {
                HStack(spacing: 16) { Image(nsImage: IconCache.shared.icon(app)).resizable().frame(width: 64, height: 64); VStack(alignment: .leading, spacing: 4) { Text(app.displayName).font(.title2.weight(.semibold)); Text(app.bundleID).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) } }
                let bundle = Bundle(path: app.path)
                LabeledContent("Version", value: bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                LabeledContent("Original name", value: app.name)
                LabeledContent("Added", value: app.added.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Last opened", value: app.lastOpened?.formatted() ?? "Not opened here yet")
                Text(app.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                HStack { Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) }; Spacer(); Button("Done") { store.infoApp = nil }.keyboardShortcut(.defaultAction) }
            }
        }.padding(28).frame(width: 450)
    }
}

private struct SettingsSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 16)
            Toggle("", isOn: configuration.$isOn).labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(Color(nsColor: .systemGray))
        }
    }
}

private struct DisplayModePreview: View {
    let windowed: Bool
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.07, blue: 0.48), Color(red: 0.07, green: 0.16, blue: 0.48), Color(red: 0.2, green: 0.3, blue: 0.53)], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.88)); path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.22))
                }.stroke(.white.opacity(0.25), lineWidth: 1).blur(radius: 1)
            }
            previewGrid.padding(windowed ? 8 : 5)
                .background { if windowed { RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.6)).overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.25))) } }
                .padding(windowed ? 11 : 1)
        }.clipShape(RoundedRectangle(cornerRadius: 5))
    }
    private var previewGrid: some View {
        VStack(spacing: 4) {
            ForEach(0..<(windowed ? 3 : 4), id: \.self) { _ in
                HStack(spacing: 5) { ForEach(0..<5, id: \.self) { _ in RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.45)).frame(width: windowed ? 4 : 5, height: windowed ? 4 : 5) } }
            }
        }
    }
}
