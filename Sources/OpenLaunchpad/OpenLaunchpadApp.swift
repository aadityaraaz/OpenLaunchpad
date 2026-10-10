import SwiftUI
import AppKit
import LauncherCore

@main struct OpenLaunchpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { SettingsView(store: delegate.store) }
            .commands {
                CommandGroup(replacing: .appSettings) { Button("Settings…") { delegate.showSettings() }.keyboardShortcut(",") }
                CommandGroup(after: .appSettings) { Button("Show OpenLaunchpad") { delegate.toggle() }.keyboardShortcut("l", modifiers: [.command, .shift]); Button("Search applications") { delegate.show(); NotificationCenter.default.post(name: .launcherDidShow, object: nil) }.keyboardShortcut("k") }
            }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = LibraryStore()
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private let shortcut = GlobalShortcut()
    private let corners = HotCorners()
    private let gestures = TrackpadGestures()
    private var gesturePreview = false
    private var eventMonitor: Any?
    private var outsideMonitor: Any?
    private var rememberedFrame: NSRect? = UserDefaults.standard.string(forKey: "launcherWindowFrame").map(NSRectFromString)
    private var positioning = false
    private var windowDragStart: (pointer: NSPoint, origin: NSPoint)?
    private var appliedPreferences: Preferences?
    private var refreshTimer: Timer?
    private var closedAt: Date?
    private var lastScroll = Date.distantPast
    private var scrollAccumulation: CGFloat = 0
    private var wheelGestureLatched = false
    private var horizontalSwipe = false
    private var observers: [NSObjectProtocol] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--self-test") { exit(IntegrationChecks.run()) }
        NSApp.setActivationPolicy(.regular)
        store.dismiss = { [weak self] in self?.hide() }
        store.showReorganization = { [weak self] in self?.showReorganization() }
        store.showSettings = { [weak self] in self?.showSettings() }
        store.restart = { [weak self] in self?.restart() }
        store.preferencesChanged = { [weak self] in self?.applyPreferences() }
        shortcut.action = { [weak self] in self?.toggle() }
        corners.action = { [weak self] in self?.toggle() }; corners.start()
        gestures.isVisible = { [weak self] in self?.window?.isVisible == true && self?.gesturePreview == false }
        gestures.progress = { [weak self] progress, closing in self?.previewGesture(progress: progress, closing: closing) }
        gestures.complete = { [weak self] committed, closing in
            guard let self else { return }
            if committed { self.gesturePreview = false; self.window?.alphaValue = 1; closing ? self.hide() : self.show() }
            else if self.gesturePreview { self.gesturePreview = false; self.window?.orderOut(nil); self.window?.alphaValue = 1 }
            else { self.window?.alphaValue = 1 }
        }
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength); statusItem = status
        status.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "OpenLaunchpad")
        status.button?.target = self; status.button?.action = #selector(statusClick); status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        let content = LauncherView(store: store)
        let panel = LauncherWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760), styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        panel.title = "OpenLaunchpad"; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.isReleasedWhenClosed = false; panel.delegate = self; panel.minSize = NSSize(width: 780, height: 560)
        panel.contentView = NSHostingView(rootView: content); panel.isMovableByWindowBackground = false; panel.isMovable = true
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]; window = panel
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged, .keyDown, .scrollWheel, .otherMouseDown]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, let window = self.window, window.isVisible, window.attachedSheet == nil,
                      !window.frame.contains(NSEvent.mouseLocation) else { return }
                self.hide()
            }
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.store.refresh() } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.store.refresh() } })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in if self?.window?.isVisible == true { self?.positionWindow() } } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.applyPreferences(); if let self { _ = self.gestures.configure(fingers: self.store.preferences.gestureFingers, restart: true) }; self?.store.refresh() } })
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in Task { @MainActor in self?.store.refresh() } }
        applyPreferences(); store.refresh()
        if !CommandLine.arguments.contains("--background") { show() }
    }
    @objc private func statusClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            for (title, action) in [("Open Launchpad", #selector(toggleFromMenu)), ("Settings…", #selector(settingsFromMenu)), ("Refresh applications", #selector(refreshFromMenu)), ("Quit OpenLaunchpad", #selector(quitFromMenu))] { let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item) }
            statusItem?.menu = menu; statusItem?.button?.performClick(nil); statusItem?.menu = nil
        } else { toggle() }
    }
    @objc private func toggleFromMenu() { toggle() }
    @objc private func settingsFromMenu() { showSettings() }
    @objc private func refreshFromMenu() { store.refresh() }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }
    func toggle() { window?.isVisible == true ? hide() : show() }
    func show() {
        if store.preferences.resetAfter >= 0, closedAt.map({ Date().timeIntervalSince($0) >= store.preferences.resetAfter }) ?? true { store.page = 0 }
        store.extraPage = false; store.page = min(store.page, store.pageCount - 1); store.query = ""; store.folderID = nil; store.editing = false; store.uninstallMode = false; store.selection.removeAll()
        positionWindow(); NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
        if store.preferences.fullscreen && store.preferences.hideDock { NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar] }
        NotificationCenter.default.post(name: .launcherDidShow, object: nil)
    }
    func hide() { window?.orderOut(nil); closedAt = Date(); NSApp.presentationOptions = []; store.flush() }
    func positionWindow() {
        guard let window else { return }
        let screen: NSScreen
        switch store.preferences.display {
        case .main: screen = NSScreen.screens.first ?? NSScreen.main!
        case .active: screen = NSScreen.main ?? NSScreen.screens[0]
        case .pointer: screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
        }
        if !store.preferences.fullscreen, let frame = rememberedFrame,
           NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) && $0.visibleFrame.intersection(frame).width >= 120 && $0.visibleFrame.intersection(frame).height >= 100 }) {
            positioning = true; window.setFrame(frame, display: true); positioning = false; window.level = .normal; return
        }
        let rect = store.preferences.fullscreen ? screen.frame : screen.visibleFrame
        let width = store.preferences.fullscreen ? rect.width : min(store.preferences.interfaceStyle == "Classic" ? 900 : 1140, rect.width - 100)
        let height = store.preferences.fullscreen ? rect.height : min(store.preferences.interfaceStyle == "Classic" ? 700 : 790, rect.height - 80)
        window.level = store.preferences.fullscreen ? .floating : .normal
        positioning = true
        window.setFrame(NSRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height), display: true)
        positioning = false
    }
    func applyPreferences() {
        let next = store.preferences; let previous = appliedPreferences
        if previous == nil || previous?.shortcutKey != next.shortcutKey || previous?.shortcutModifiers != next.shortcutModifiers || previous?.useF4 != next.useF4 {
            if !shortcut.register(next) { store.message = "That shortcut or F4 is already in use. Choose another shortcut." }
        }
        corners.preferences = next
        if previous?.gestureFingers != next.gestureFingers, !gestures.configure(fingers: next.gestureFingers) {
            store.message = "No compatible multitouch trackpad was found, or this macOS version does not expose the required interface."
        }
        if previous == nil || previous?.launcherIcon != next.launcherIcon {
            // nil restores the bundle icon, allowing macOS to render its native
            // light/dark/tinted asset-catalog variants instead of a fixed bitmap.
            NSApp.applicationIconImage = next.launcherIcon == "Rocket" ? LauncherIcon.rocket() : nil
            statusItem?.button?.image = NSImage(systemSymbolName: next.launcherIcon == "Rocket" ? "paperplane.fill" : "square.grid.3x3.fill", accessibilityDescription: "OpenLaunchpad")
        }
        statusItem?.isVisible = next.showMenuBarIcon
        if previous == nil || previous?.fullscreen != next.fullscreen || previous?.display != next.display || previous?.interfaceStyle != next.interfaceStyle {
            if previous != nil && (previous?.display != next.display || previous?.interfaceStyle != next.interfaceStyle) {
                rememberedFrame = nil; UserDefaults.standard.removeObject(forKey: "launcherWindowFrame")
            } else if previous?.fullscreen == false && next.fullscreen { rememberedFrame = window?.frame }
            if window?.isVisible == true { positionWindow() }
        }
        if window?.isVisible == true { NSApp.presentationOptions = next.fullscreen && next.hideDock ? [.autoHideDock, .autoHideMenuBar] : [] }
        if previous?.appearance != next.appearance {
            NSApp.appearance = next.appearance == "System" ? nil : NSAppearance(named: next.appearance == "Dark" ? .darkAqua : .aqua)
        }
        appliedPreferences = next
    }
    func windowDidMove(_ notification: Notification) {
        if !positioning && !store.preferences.fullscreen, notification.object as? NSWindow === window { rememberedFrame = window?.frame; if let rememberedFrame { UserDefaults.standard.set(NSStringFromRect(rememberedFrame), forKey: "launcherWindowFrame") } }
    }
    func applicationDidResignActive(_ notification: Notification) {
        if window?.isVisible == true && window?.attachedSheet == nil && !store.dragging { hide() }
    }
    private func restart() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { store.message = "Restart is available in the built .app bundle."; return }
        store.flush(); shortcut.unregister(); gestures.stop()
        let configuration = NSWorkspace.OpenConfiguration(); configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if let error { if let self { _ = self.shortcut.register(self.store.preferences); _ = self.gestures.configure(fingers: self.store.preferences.gestureFingers) }; self?.store.message = "Could not restart: \(error.localizedDescription)" }
                else { NSApp.terminate(nil) }
            }
        }
    }
    func showSettings() {
        hide()
        if settingsWindow == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: store.preferences.interfaceStyle == "Classic" ? 400 : 790, height: store.preferences.interfaceStyle == "Classic" ? 560 : 620), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            panel.title = "OpenLaunchpad Settings"; panel.titlebarAppearsTransparent = true; panel.isReleasedWhenClosed = false
            panel.titleVisibility = store.preferences.interfaceStyle == "Classic" ? .hidden : .visible
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = store.preferences.interfaceStyle == "Classic"
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.contentView = NSHostingView(rootView: SettingsView(store: store)); panel.center(); settingsWindow = panel
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    private func showReorganization() {
        guard let parent = settingsWindow?.isVisible == true ? settingsWindow : window, parent.attachedSheet == nil else { return }
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 440), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "Reorganize Layout"; panel.titlebarAppearsTransparent = true; panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: ReorganizationView(store: store) { parent.endSheet(panel); panel.orderOut(nil) })
        parent.beginSheet(panel)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hide(); return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { toggle(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { gestures.stop(); store.flush(); NSApp.presentationOptions = [] }
    private func previewGesture(progress: Double, closing: Bool) {
        guard window?.attachedSheet == nil, settingsWindow?.isVisible != true else { return }
        if closing { window?.alphaValue = max(0.1, 1 - progress * 0.8) }
        else if progress > 0.08 {
            if !gesturePreview && window?.isVisible != true { gesturePreview = true; positionWindow(); window?.orderFrontRegardless() }
            if gesturePreview { window?.alphaValue = max(0.1, progress) }
        }
    }
    private func handle(_ event: NSEvent) -> NSEvent? {
        if IconDragController.shared.handle(event) { return nil }
        if event.type == .leftMouseDown || event.type == .leftMouseUp { store.dragging = false }
        if event.type == .leftMouseUp && windowDragStart != nil { windowDragStart = nil; return nil }
        if event.type == .leftMouseDragged, let start = windowDragStart, let window {
            let pointer = window.convertPoint(toScreen: event.locationInWindow)
            window.setFrameOrigin(NSPoint(x: start.origin.x + pointer.x - start.pointer.x, y: start.origin.y + pointer.y - start.pointer.y))
            return nil
        }
        guard event.window === window, window?.isVisible == true, window?.attachedSheet == nil else { return event }
        if event.type == .leftMouseDown && !store.preferences.fullscreen, let window {
            let point = event.locationInWindow
            if point.y >= window.contentLayoutRect.height - 14 || point.y <= 14 {
                windowDragStart = (window.convertPoint(toScreen: event.locationInWindow), window.frame.origin); return nil
            }
        }
        if event.type == .flagsChanged && store.preferences.optionToUninstall { store.uninstallMode = event.modifierFlags.contains(.option); return event }
        if event.type == .keyDown {
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 6: if !(window?.firstResponder is NSTextView) || store.query.isEmpty { event.modifierFlags.contains(.shift) ? store.redo() : store.undo(); return nil }
                case 12: NSApp.terminate(nil); return nil
                case 43: showSettings(); return nil
                case 40: NotificationCenter.default.post(name: .launcherDidShow, object: nil); return nil
                case 123: store.turnPage(-1); return nil
                case 124: store.turnPage(1); return nil
                case 0: if store.editing { store.selection = Set(store.displayedItems.map(\.id)); return nil }
                default: break
                }
            }
            // Do not intercept Return while a text input method is composing.
            if let text = window?.firstResponder as? NSTextView, text.hasMarkedText() { return event }
            switch event.keyCode {
            case 53: store.escape(); return nil
            case 123: store.navigate(-1); return nil
            case 124: store.navigate(1); return nil
            case 125: store.navigate(store.preferences.columns); return nil
            case 126: store.navigate(-store.preferences.columns); return nil
            default: break
            }
        }
        if event.type == .otherMouseDown { if event.buttonNumber == 3 { store.turnPage(-1); return nil }; if event.buttonNumber == 4 { store.turnPage(1); return nil } }
        if event.type == .scrollWheel && store.preferences.browse == .pages && store.query.isEmpty {
            if event.momentumPhase != [] { return nil }
            if event.hasPreciseScrollingDeltas && event.phase != [] {
                if event.phase.contains(.began) { horizontalSwipe = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY); store.pagingOffset = 0 }
                if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) && abs(event.scrollingDeltaX) > 2 { horizontalSwipe = true }
                if horizontalSwipe {
                    if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                        if !event.phase.contains(.cancelled) && abs(store.pagingOffset) > 55 { store.turnPage(store.pagingOffset < 0 ? 1 : -1) }
                        withAnimation(.easeOut(duration: 0.24)) { store.pagingOffset = 0 }; horizontalSwipe = false
                    } else { store.pagingOffset = min(250, max(-250, store.pagingOffset + event.scrollingDeltaX * (store.preferences.naturalScroll ? 1 : -1))) }
                    return nil
                }
            }
            if event.phase.contains(.began) { wheelGestureLatched = false; scrollAccumulation = 0 }
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) { wheelGestureLatched = false; scrollAccumulation = 0; return nil }
            let now = Date(); if now.timeIntervalSince(lastScroll) > 0.4 { scrollAccumulation = 0 }
            if wheelGestureLatched { return nil }
            let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
            let sign: CGFloat = store.preferences.naturalScroll ? 1 : -1
            scrollAccumulation += delta * sign
            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 45 : 2
            if abs(scrollAccumulation) > threshold && now.timeIntervalSince(lastScroll) > 0.25 { store.turnPage(scrollAccumulation < 0 ? 1 : -1); lastScroll = now; scrollAccumulation = 0; if event.phase != [] { wheelGestureLatched = true } }
            return nil
        }
        return event
    }
}

final class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
