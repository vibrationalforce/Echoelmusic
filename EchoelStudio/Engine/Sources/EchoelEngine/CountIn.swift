import EchoelCore
import Foundation

/// The count-in before Record: `bars` bars of click at the tempo and in the meter of the bar the
/// take starts in, the transport starting on the sample after the last of them. Pure arithmetic,
/// worked out on the main thread; the render thread gets it as ONE word (`packed`) and counts it
/// down sample by sample (`EngineCore.startCountIn`), so the downbeat never depends on when a
/// main-actor timer wakes or on the buffer size.
///
/// Each beat lasts a whole number of samples, so the pre-roll is exactly `beats` of them and the
/// last click is one beat before the downbeat. How many bars is a setting of this device, never of
/// the song (Law 3).
public struct CountIn: Equatable, Sendable {
    /// The choices on the Click button's menu.
    public enum Length: Int, CaseIterable, Sendable {
        case off = 0, oneBar = 1, twoBars = 2

        public var title: String {
            switch self {
            case .off: "No Count-in"
            case .oneBar: "Count-in 1 Bar"
            case .twoBars: "Count-in 2 Bars"
            }
        }
    }

    /// Clicks before the downbeat.
    public let beats: Int
    /// Beats in a bar of the meter counted in: the first click of each bar is accented.
    public let beatsPerBar: Int
    /// Samples one beat lasts.
    public let beatSamples: Int64

    /// The most beats one count-in clicks, and the longest beat: both fit `packed`.
    public static let beatLimit = 255
    static let beatSampleLimit: Int64 = 1 << 39

    /// `bars` of the beat sounding at `tick`. Nil for no bars, or when the tempo there gives no
    /// beat a sample long.
    public init?(bars: Int, at tick: Tick, tempoMap: TempoMap, meterMap: MeterMap, sampleRate: Double) {
        guard bars > 0 else { return nil }
        let at = Swift.min(Swift.max(0, tick), MusicalTime.maximumTick)
        let beatTicks = Swift.max(meterMap.ticksPerBeat(at: at), 1)
        let perBar = Swift.max(Int(meterMap.ticksPerBar(at: at) / beatTicks), 1)
        let time = TimeConversion(tempoMap: tempoMap, sampleRate: sampleRate)
        let length = (time.samplesPerTick(at: at) * Double(beatTicks)).rounded()
        guard length.isFinite, length >= 1, length < Double(Self.beatSampleLimit) else { return nil }
        self.init(beats: bars * perBar, beatsPerBar: perBar, beatSamples: Int64(length))
    }

    init?(beats: Int, beatsPerBar: Int, beatSamples: Int64) {
        guard beats > 0, beatsPerBar > 0, beatSamples > 0, beatSamples < Self.beatSampleLimit else { return nil }
        self.beats = Swift.min(beats, Self.beatLimit)
        self.beatsPerBar = Swift.min(beatsPerBar, Self.beatLimit)
        self.beatSamples = beatSamples
    }

    /// Samples from the first click to the downbeat.
    public var preRollSamples: Int64 { Int64(beats) * beatSamples }

    /// Where each click starts, in samples from the first one.
    public var onsets: [Int64] { (0..<beats).map { Int64($0) * beatSamples } }

    /// The first click of each bar is accented.
    public func isAccented(beat: Int) -> Bool { beat % beatsPerBar == 0 }

    /// Beats still to click when `remaining` samples are left before the downbeat: 4, 3, 2, 1.
    public func beatsLeft(remaining: Int64) -> Int {
        guard remaining > 0 else { return 0 }
        return Int(Swift.min((remaining + beatSamples - 1) / beatSamples, Int64(beats)))
    }

    /// The count-in as one word for the render thread: beats, beats per bar and the beat length.
    /// Never 0 (no request) and never `UInt64.max` (a cancel).
    var packed: UInt64 {
        UInt64(beats) << 48 | UInt64(beatsPerBar) << 40 | UInt64(beatSamples)
    }

    /// The count-in a word carries, or nil for a word no count-in packs.
    init?(packed: UInt64) {
        self.init(beats: Int(packed >> 48 & 0xFF), beatsPerBar: Int(packed >> 40 & 0xFF),
                  beatSamples: Int64(packed & (1 << 40 - 1)))
    }
}
