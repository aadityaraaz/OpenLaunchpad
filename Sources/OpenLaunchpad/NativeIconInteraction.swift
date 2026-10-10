import AppKit
import SwiftUI
import LauncherCore

/// Native mouse tracking avoids competition between buttons, page swipes and app drags.
struct NativeIconInteraction: NSViewRepresentable {
    let store: LibraryStore
    let item: LayoutItem
    func makeNSView(context: Context) -> IconInteractionView { IconInteractionView() }
    func updateNSView(_ view: IconInteractionView, context: Context) { view.store = store; view.item = item }
}

final class IconInteractionView: NSView, NSDraggingSource {
    weak var store: LibraryStore?
    var item: LayoutItem?
    override init(frame: NSRect) { super.init(frame: frame); IconDragController.shared.targets.add(self) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { IconDragController.shared.begin(self, event: event) }
    override func mouseDragged(with event: NSEvent) { _ = IconDragController.shared.handle(event) }
    override func mouseUp(with event: NSEvent) { _ = IconDragController.shared.handle(event) }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { context == .withinApplication ? .move : .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) { IconDragController.shared.cancel() }
}

@MainActor final class IconDragController {
    static let shared = IconDragController()
    let targets = NSHashTable<IconInteractionView>.weakObjects()
    private var source: IconInteractionView?
    private weak var dragWindow: NSWindow?
    private var start = NSPoint.zero
    private var point = NSPoint.zero
    private var ids: [String] = []
    private var preview: DragPreview?
    private weak var highlighted: IconInteractionView?
    private var pageTimer: Timer?
    private var edgeDirection = 0
    private var external = false
    var tracking: Bool { source != nil }
    func begin(_ view: IconInteractionView, event: NSEvent) {
        cancel()
        guard let item = view.item, let store = view.store else { return }
        source = view; dragWindow = view.window; start = event.locationInWindow; point = start
        ids = store.selection.contains(item.id) ? store.displayedItems.filter { store.selection.contains($0.id) }.map(\.id) : [item.id]
    }
    func handle(_ event: NSEvent) -> Bool {
        guard let source, let store = source.store, let window = dragWindow, !external else { return false }
        if event.type == .keyDown && event.keyCode == 53 { cancel(); return true }
        guard event.window === window else { return false }
        if event.type == .leftMouseDragged {
            point = event.locationInWindow
            if preview == nil && hypot(point.x - start.x, point.y - start.y) < 5 { return true }
            if preview == nil {
                store.dragging = true
                let image = source.item?.apps.first.flatMap { store.app($0) }.map { IconCache.shared.icon($0) }
                let view = DragPreview(frame: NSRect(origin: .zero, size: source.bounds.size))
                view.image = image; view.imageScaling = .scaleProportionallyUpOrDown; view.alphaValue = 0.85
                window.contentView?.addSubview(view); preview = view
            }
            if let preview, let parent = preview.superview {
                let position = parent.convert(point, from: nil)
                preview.setFrameOrigin(NSPoint(x: position.x - preview.frame.width / 2, y: position.y - preview.frame.height / 2))
            }
            setHighlight(destination(point, window: window))
            source.enclosingScrollView?.autoscroll(with: event)
            updatePageEdge(point: point, window: window, store: store)
            if !window.contentLayoutRect.contains(point) && source.item?.isFolder == false { startExternalDrag(event, source: source, store: store) }
            return true
        }
        if event.type == .leftMouseUp {
            if preview != nil {
                let destination = destination(event.locationInWindow, window: window)
                let payload = ids
                let group = destination.map { $0.bounds.contains($0.convert(event.locationInWindow, from: nil)) } ?? false
                if let target = destination?.item, !payload.contains(target.id) {
                    cancel(); store.drop(payload, target: target.id, group: group)
                } else if destination == nil {
                    let inFolder = source.enclosingScrollView.map { $0.visibleRect.contains($0.convert(event.locationInWindow, from: nil)) } ?? false
                    cancel()
                    if store.folderID != nil && !inFolder { store.moveToFolder(Set(payload), folder: nil); store.closeFolder() }
                    else { store.drop(payload, target: nil, group: false) }
                } else { cancel() }
            } else {
                let item = source.item; cancel()
                if let item { store.activate(item, command: event.modifierFlags.contains(.command)) }
            }
            return true
        }
        return false
    }
    private func destination(_ point: NSPoint, window: NSWindow) -> IconInteractionView? {
        let candidates = targets.allObjects.filter { $0.window === window && !$0.visibleRect.isEmpty && $0.item != nil }
        return candidates.first { $0.bounds.contains($0.convert(point, from: nil)) }
            ?? candidates.first { $0.bounds.insetBy(dx: -16, dy: -35).contains($0.convert(point, from: nil)) }
    }
    private func setHighlight(_ view: IconInteractionView?) {
        if highlighted === view { return }
        highlighted?.layer?.borderWidth = 0; highlighted = view
        view?.wantsLayer = true; view?.layer?.cornerRadius = 20
        view?.layer?.borderColor = NSColor.controlAccentColor.cgColor; view?.layer?.borderWidth = 2
    }
    private func updatePageEdge(point: NSPoint, window: NSWindow, store: LibraryStore) {
        guard store.preferences.browse == .pages, store.query.isEmpty else { return }
        let direction = point.x < 32 ? -1 : point.x > window.contentLayoutRect.width - 32 ? 1 : 0
        guard direction != edgeDirection else { return }
        pageTimer?.invalidate(); edgeDirection = direction
        guard direction != 0 else { return }
        pageTimer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self, weak store] _ in
            MainActor.assumeIsolated {
                guard let self, let store, self.preview != nil else { return }
                if direction > 0 && store.page == store.pageCount - 1 && !store.extraPage { store.extraPage = true }
                store.turnPage(direction)
            }
        }
    }
    private func startExternalDrag(_ event: NSEvent, source: IconInteractionView, store: LibraryStore) {
        guard let id = source.item?.apps.first, let app = store.app(id) else { return }
        let pasteboard = NSPasteboardItem()
        pasteboard.setString(URL(fileURLWithPath: app.path).absoluteString, forType: .fileURL)
        if let data = try? JSONEncoder().encode(ids) { pasteboard.setData(data, forType: NSPasteboard.PasteboardType(launchpadDragType.identifier)) }
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboard)
        draggingItem.setDraggingFrame(source.bounds, contents: IconCache.shared.icon(app))
        preview?.removeFromSuperview(); preview = nil; setHighlight(nil); pageTimer?.invalidate(); external = true
        source.beginDraggingSession(with: [draggingItem], event: event, source: source).animatesToStartingPositionsOnCancelOrFail = true
    }
    func cancel() {
        source?.store?.dragging = false
        preview?.removeFromSuperview(); preview = nil; setHighlight(nil)
        pageTimer?.invalidate(); pageTimer = nil; edgeDirection = 0
        source = nil; dragWindow = nil; ids = []; external = false
    }
    private final class DragPreview: NSImageView { override func hitTest(_ point: NSPoint) -> NSView? { nil } }
}
