import Observation

/// Observable bridge for BodyFrame metrics.
/// The existing Bio publishers can write live values here.
@Observable
final class BodyFrameSource {
    var heartRate: Double = 72
    var hrvMs: Double = 48
    var coherence: Double = 0.62
    var isActive: Bool = true
}
