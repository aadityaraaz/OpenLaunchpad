import AppKit
import LauncherCore
import TrackpadBridge

@MainActor final class TrackpadGestures {
    static weak var current: TrackpadGestures?
    private var trackers: [UInt: PinchTracker] = [:]
    private var closing: [UInt: Bool] = [:]
    private var active = false
    private var fingers = 0
    var isVisible: (() -> Bool)?
    var progress: ((Double, Bool) -> Void)?
    var complete: ((Bool, Bool) -> Void)?
    func configure(fingers: Int, restart: Bool = false) -> Bool {
        if self.fingers == fingers && !restart { return fingers == 0 || active }
        OLTrackpadStop(); active = false; self.fingers = fingers; trackers.removeAll(); closing.removeAll()
        guard fingers >= 3 && fingers <= 5 else { return true }
        Self.current = self
        active = OLTrackpadStart { device, coordinates, count in
            guard let coordinates else { return }
            let points = (0..<Int(count)).map { TouchPoint(x: Double(coordinates[$0 * 2]), y: Double(coordinates[$0 * 2 + 1])) }
            Task { @MainActor in TrackpadGestures.current?.receive(device: device, points: points) }
        }
        return active
    }
    private func receive(device: UInt, points: [TouchPoint]) {
        guard active else { return }
        if closing[device] == nil, points.count == fingers { closing[device] = isVisible?() ?? false }
        guard let close = closing[device] else { return }
        var tracker = trackers[device] ?? PinchTracker()
        let result = tracker.update(points: points, fingers: fingers, closing: close, time: ProcessInfo.processInfo.systemUptime)
        trackers[device] = tracker
        if result.committed { complete?(true, close) }
        else if result.finished { complete?(false, close) }
        else { progress?(result.progress, close) }
        if result.finished { trackers.removeValue(forKey: device); closing.removeValue(forKey: device) }
    }
    func stop() { OLTrackpadStop(); active = false }
}
