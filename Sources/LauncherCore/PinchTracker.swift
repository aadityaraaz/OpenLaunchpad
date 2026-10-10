import Foundation
public struct TouchPoint: Sendable {
    public var x: Double; public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}
public struct PinchTracker: Sendable {
    public struct Result: Equatable, Sendable {
        public var progress: Double
        public var committed: Bool
        public var finished: Bool
    }
    private var baseline: Double?
    private var center: TouchPoint?
    private var began: Double = 0
    private var peak: Double = 0
    private var triggered = false
    public init() {}
    public mutating func update(points: [TouchPoint], fingers: Int, closing: Bool, time: Double) -> Result {
        guard points.count == fingers else {
            let result = Result(progress: peak, committed: !triggered && peak >= 0.85, finished: true)
            self = PinchTracker(); return result
        }
        let centroid = TouchPoint(x: points.map(\.x).reduce(0, +) / Double(points.count), y: points.map(\.y).reduce(0, +) / Double(points.count))
        let radius = points.map { hypot($0.x - centroid.x, $0.y - centroid.y) }.reduce(0, +) / Double(points.count)
        guard radius > 0.01 else { return Result(progress: 0, committed: false, finished: false) }
        guard let baseline, let center else { self.baseline = radius; self.center = centroid; began = time; return Result(progress: 0, committed: false, finished: false) }
        if hypot(centroid.x - center.x, centroid.y - center.y) > 0.18 { self = PinchTracker(); return Result(progress: 0, committed: false, finished: true) }
        let fraction = closing ? (radius / baseline - 1) / 0.45 : (1 - radius / baseline) / 0.40
        let progress = max(0, min(1, fraction)); peak = max(peak, progress)
        let commit = !triggered && progress >= 1 && time - began > 0.10
        if commit { triggered = true }
        return Result(progress: progress, committed: commit, finished: false)
    }
}
