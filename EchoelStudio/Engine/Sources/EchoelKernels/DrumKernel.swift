import EchoelCore
import EchoelDSP
import Foundation
import Synchronization

/// The built-in drum kit as a plugin plays it: General MIDI drum notes in, stereo out, one level.
/// Shared by the Echoel Drums Audio Unit and its tests. Nothing allocates after `init`.
public final class DrumKernel: InstrumentKernel, @unchecked Sendable {
    /// The drums' Core table (`InstrumentDevice.drums`): one row, the level, at address 0.
    public static let parameters = InstrumentDevice.drums.parameters.map(InstrumentKernelParameter.init)
    public let sampleRate: Double
    public let maximumFrames: Int

    private let level: Atomic<UInt32>
    /// The level's range, copied from the table once.
    private let range: ClosedRange<Float>
    private var kit: DrumKit
    private let mono: UnsafeMutablePointer<Float>
    /// The level the output is at; it glides toward the parameter so a move never clicks.
    private var gain: Float
    private let glide: Float

    public convenience init(sampleRate: Double, maximumFrames: Int = 4_096) {
        self.init(sampleRate: sampleRate, maximumFrames: maximumFrames, level: Float(Self.parameters.first?.defaultValue ?? 0.8))
    }

    /// The kit at `level` from its first sample: the output starts there instead of gliding to it.
    /// The app's engine plays its drums at the song's default, 1 (unity, as it always has); the
    /// plugin starts at the table's default. A glide from 0.8 never quite reaches 1 in `Float`, so a level the engine
    /// needs exactly has to be set here, not through `setParameter`.
    public init(sampleRate: Double, maximumFrames: Int, level start: Float) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        self.maximumFrames = Swift.max(1, maximumFrames)
        let row = Self.parameters.first
        range = row.map { Float($0.range.lowerBound)...Float($0.range.upperBound) } ?? 0...1
        let clamped = start.isFinite ? Swift.min(Swift.max(start, range.lowerBound), range.upperBound) : range.upperBound
        level = Atomic(clamped.bitPattern)
        gain = clamped
        kit = DrumKit(sampleRate: Float(rate))
        mono = .allocate(capacity: self.maximumFrames)
        mono.initialize(repeating: 0, count: self.maximumFrames)
        glide = 1 - expf(-1 / (0.005 * Float(rate)))
    }

    deinit { mono.deallocate() }

    /// Any thread. Clamped to the level's range; a value that is not finite is ignored.
    public func setParameter(_ address: Int, _ value: Float) {
        guard address == 0, value.isFinite else { return }
        level.store(Swift.min(Swift.max(value, range.lowerBound), range.upperBound).bitPattern, ordering: .relaxed)
    }

    public func parameter(_ address: Int) -> Float {
        address == 0 ? Float(bitPattern: level.load(ordering: .relaxed)) : 0
    }

    // MARK: - Render thread

    /// Render thread. Whether a piece is ringing.
    public var isSounding: Bool { kit.activeVoiceCount > 0 }

    /// The level is read at the top of every render; there is nothing to commit.
    public func commitParameters() {}

    /// Render thread. All sound off (CC 120).
    public func reset() { kit.reset() }

    /// Note on plays a piece; note off is ignored (drums are one-shots); CC 120 silences the kit.
    /// A hit on a silent kit starts at the level, not gliding from an old one: the app's engine
    /// renders no silent kernel, so a level set in a break would otherwise reach the next hit
    /// only after its transient.
    public func receive(status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        switch status & 0xF0 {
        case 0x90:
            if !isSounding { gain = Float(bitPattern: level.load(ordering: .relaxed)) }
            kit.noteOn(pitch: data1 & 0x7F, velocity: data2 & 0x7F)
        case 0xB0 where data1 == 120: kit.reset()
        default: break
        }
    }

    public func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, gain demo: Float) {
        let target = Float(bitPattern: level.load(ordering: .relaxed))
        var done = 0
        while done < frames {
            let n = Swift.min(frames - done, maximumFrames)
            mono.update(repeating: 0, count: n)
            kit.render(into: UnsafeMutableBufferPointer(start: mono, count: n))
            for i in 0..<n {
                gain += (target - gain) * glide
                let sample = mono[i].isFinite ? mono[i] * gain * demo : 0
                left[done + i] = sample
                right[done + i] = sample
            }
            done += n
        }
    }
}
