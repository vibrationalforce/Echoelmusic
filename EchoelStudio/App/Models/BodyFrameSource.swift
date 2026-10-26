import Foundation

/// Observable bridge for BodyFrame values.
/// BodyFrameView reads from this.
/// A future publisher (ported from Sources/Echoelmusic/Bio) writes into it.
/// Keeps the UI independent of the full publisher port.
@Observable
final class BodyFrameSource {
    var heartRate: Double = 72
    var hrvNormalized: Double = 0.45
    var coherence: Double = 0.62
    var isActive: Bool = true
    
    /// Placeholder update for testing. Replace with real publisher writes.
    func updatePlaceholder() {
        // Demo values; real source will overwrite.
        heartRate = 72
        hrvNormalized = 0.45
        coherence = 0.62
        isActive = true
    }
}
