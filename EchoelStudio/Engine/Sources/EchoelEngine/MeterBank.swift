import Foundation
import Synchronization

/// Peak levels the render thread leaves for the screen: one stereo reading per mix point —
/// instrument tracks, audio tracks, returns — and the master. A reading is the loudest sample
/// after the fader, falling at `fallDecibelsPerSecond` once the signal drops, so a screen that
/// looks a few times a second still sees every peak and any number of views may read it.
/// No locks, no allocation after `init`.
public final class MeterBank: @unchecked Sendable {
    public struct Level: Equatable, Sendable {
        /// Linear peak per side, 1 = full scale; louder than 1 means the mix clips there.
        public let left: Float
        public let right: Float

        public init(left: Float, right: Float) {
            self.left = left
            self.right = right
        }

        public static let silent = Level(left: 0, right: 0)
    }

    /// How fast a reading falls: about what a DAW's peak meter does.
    public static let fallDecibelsPerSecond: Float = 20

    private final class Cell: @unchecked Sendable {
        let left = Atomic<UInt32>(0)
        let right = Atomic<UInt32>(0)
    }

    private let cells: [Cell]

    init(count: Int) {
        cells = (0..<Swift.max(0, count)).map { _ in Cell() }
    }

    /// The factor a reading falls by over `frames` at `sampleRate`.
    static func fall(frames: Int, sampleRate: Double) -> Float {
        guard frames > 0, sampleRate > 0 else { return 1 }
        return Float(pow(10, -Double(fallDecibelsPerSecond) / 20 * Double(frames) / sampleRate))
    }

    /// Render thread: this block's peaks into reading `index`, the old reading fallen by `fall`.
    func record(_ index: Int, left: Float, right: Float, fall: Float) {
        guard index >= 0, index < cells.count else { return }
        let cell = cells[index]
        store(left, fall: fall, in: cell.left)
        store(right, fall: fall, in: cell.right)
    }

    private func store(_ peak: Float, fall: Float, in value: borrowing Atomic<UInt32>) {
        let old = Float(bitPattern: value.load(ordering: .relaxed))
        let fresh = peak.isFinite ? Swift.abs(peak) : 0
        value.store(Swift.max(fresh, old.isFinite ? old * fall : 0).bitPattern, ordering: .relaxed)
    }

    /// Any thread: reading `index`, silent for an index without one.
    public func level(_ index: Int) -> Level {
        guard index >= 0, index < cells.count else { return .silent }
        let cell = cells[index]
        return Level(left: Float(bitPattern: cell.left.load(ordering: .relaxed)),
                     right: Float(bitPattern: cell.right.load(ordering: .relaxed)))
    }

    /// The largest absolute sample of `frames` samples; 0 for none.
    static func peak(_ samples: UnsafePointer<Float>, frames: Int) -> Float {
        var peak: Float = 0
        for i in 0..<Swift.max(0, frames) { peak = Swift.max(peak, Swift.abs(samples[i])) }
        return peak
    }
}
