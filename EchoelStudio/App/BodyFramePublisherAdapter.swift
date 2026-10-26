import Foundation

/// Minimal Publisher-Adapter.
/// Writes live values into BodyFrameSource.
/// Can be called from the existing Bio publishers or a demo timer.
enum BodyFramePublisherAdapter {
    static func update(_ source: BodyFrameSource, heartRate: Double, hrvMs: Double, coherence: Double, isActive: Bool = true) {
        source.heartRate = heartRate
        source.hrvMs = hrvMs
        source.coherence = coherence
        source.isActive = isActive
    }
}
