import Foundation

/// Minimal adapter that a real publisher (ported from Sources/Echoelmusic/Bio)
/// can write into. BodyFrameView reads from BodyFrameSource.
/// This keeps the UI slice independent of the full camera/BLE port.
/// 
/// Usage (future):
/// adapter.update(heartRate: ..., hrv: ..., coherence: ...)
/// 
/// For now it can be called with placeholders or from a test.
@MainActor
final class BodyFramePublisherAdapter {
    private let source: BodyFrameSource
    
    init(source: BodyFrameSource) {
        self.source = source
    }
    
    func update(heartRate: Double, hrvNormalized: Double, coherence: Double, isActive: Bool = true) {
        source.heartRate = heartRate
        source.hrvNormalized = hrvNormalized
        source.coherence = coherence
        source.isActive = isActive
    }
    
    /// Demo call for testing the chain.
    func pushPlaceholder() {
        update(heartRate: 72, hrvNormalized: 0.45, coherence: 0.62, isActive: true)
    }
}
