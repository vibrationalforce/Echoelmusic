import Foundation

/// The oscilloscope's trigger, as a bench scope does it: the trace starts at the first rising zero
/// crossing, so a steady tone stands still on screen instead of running across it. Pure and
/// allocation-free; the Field's scope meter reads the master through it.
public enum ScopeTrace {
    /// Copies `length` samples of `samples` (holding `count`) into `trace`, starting at the first
    /// rising zero crossing that leaves room for them, or at the start when there is none (silence,
    /// noise below the hysteresis). Non-finite samples become 0. Returns whether it triggered.
    @discardableResult
    public static func capture(_ samples: UnsafePointer<Float>, count: Int,
                               into trace: UnsafeMutablePointer<Float>, length: Int) -> Bool {
        guard length > 0 else { return false }
        let usable = Swift.max(0, count - length)
        var start = 0
        var triggered = false
        if usable > 0 {
            var armed = false
            for index in 0..<usable {
                let value = samples[index].isFinite ? samples[index] : 0
                if value < -hysteresis { armed = true }
                if armed, value >= 0, index > 0 {
                    start = index
                    triggered = true
                    break
                }
            }
        }
        for index in 0..<length {
            let source = start + index
            let value = source < count ? samples[source] : 0
            trace[index] = value.isFinite ? value : 0
        }
        return triggered
    }

    /// The trigger arms only after the signal has gone this far below zero: noise near zero does
    /// not retrigger it.
    public static let hysteresis: Float = 0.001
}
