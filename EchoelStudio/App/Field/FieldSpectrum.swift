import AVFoundation
import EchoelDSP
import Foundation

/// The Field's ear on the master for the Chladni plate, the looks and the meters: the strongest
/// partials of the mix as the musician hears it, its spectrum and its triggered waveform, no
/// microphone. `AudioEngine` feeds it from the same tap on the source node as
/// the live stream (`AudioEngine.listenForSpectrum`), only while a picture or a meter that listens is shown.
///
/// AVFoundation delivers a tap on its own thread, never the render thread, so the render block is
/// never touched. That thread sums the block to mono, pushes it into the analyzer and runs the
/// analysis (`SpectrumAnalyzer`: preallocated, about ten times a second); the lock only guards the
/// analyzer and the last result, and the Field's draw loop takes the result on the main thread.
final class FieldSpectrum: @unchecked Sendable {
    private let lock = NSLock()
    private var analyzer: SpectrumAnalyzer?
    private var mono: UnsafeMutablePointer<Float>
    private var monoCapacity = 0
    private var latest = SpectralPeaks.silent
    /// The meters' last reading (`FieldMeter`): the spectrum's bands, the triggered trace, and the
    /// phase meter's goniometer points (side, mid, …) and correlation (nil: a side is silent).
    private let bands: UnsafeMutablePointer<Double>
    private let trace: UnsafeMutablePointer<Float>
    private let phase: UnsafeMutablePointer<Float>
    private var correlation: Float?

    /// Bands across 20 Hz … 20 kHz on the spectrum meter: a third of an octave each.
    static let bandCount = 30
    /// Samples the scope draws: about 10 ms at 48 kHz, two periods of a low A.
    static let traceLength = 512
    /// Points the goniometer draws from each block.
    static let phasePairs = 256

    init() {
        mono = .allocate(capacity: 1)
        monoCapacity = 1
        bands = .allocate(capacity: Self.bandCount)
        bands.initialize(repeating: 0, count: Self.bandCount)
        trace = .allocate(capacity: Self.traceLength)
        trace.initialize(repeating: 0, count: Self.traceLength)
        phase = .allocate(capacity: 2 * Self.phasePairs)
        phase.initialize(repeating: 0, count: 2 * Self.phasePairs)
    }

    deinit {
        mono.deallocate()
        bands.deallocate()
        trace.deallocate()
        phase.deallocate()
    }

    /// The meters' newest reading, copied out on the caller's thread (a meter's leaf, at most 30
    /// times a second): the spectrum's bands 0 … 1, the scope's trace −1 … 1, the goniometer's
    /// points and the correlation.
    func meterReading() -> MeterReading {
        lock.lock()
        defer { lock.unlock() }
        return MeterReading(bands: Array(UnsafeBufferPointer(start: bands, count: Self.bandCount)),
                            trace: Array(UnsafeBufferPointer(start: trace, count: Self.traceLength)),
                            phase: Array(UnsafeBufferPointer(start: phase, count: 2 * Self.phasePairs)),
                            correlation: correlation, peaks: latest)
    }

    struct MeterReading {
        var bands: [Double]
        var trace: [Float]
        var phase: [Float]
        var correlation: Float?
        var peaks: SpectralPeaks = .silent
        /// The partials meter's held reading (`FieldMeterListener`), not the raw analysis.
        var partials: PartialRatios = .silent
    }

    /// The newest partials; silence before the first block and after `reset`.
    var peaks: SpectralPeaks {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }

    /// Forgets the sound: a plate shown after a stop starts calm.
    func reset() {
        lock.lock()
        analyzer?.reset()
        latest = .silent
        bands.update(repeating: 0, count: Self.bandCount)
        trace.update(repeating: 0, count: Self.traceLength)
        phase.update(repeating: 0, count: 2 * Self.phasePairs)
        correlation = nil
        lock.unlock()
    }

    /// One block from the tap's thread.
    func receive(_ buffer: AVAudioPCMBuffer) {
        guard let input = buffer.floatChannelData, buffer.format.channelCount > 0 else { return }
        let frames = Int(buffer.frameLength)
        let rate = buffer.format.sampleRate
        guard frames > 0, rate > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        if analyzer?.sampleRate != rate { analyzer = SpectrumAnalyzer(sampleRate: rate) }
        if monoCapacity < frames {
            mono.deallocate()
            mono = .allocate(capacity: frames)
            monoCapacity = frames
        }
        let right = buffer.format.channelCount > 1 ? 1 : 0
        for index in 0..<frames {
            mono[index] = 0.5 * (input[0][index] + input[right][index])
        }
        guard let analyzer else { return }
        analyzer.push(mono, count: frames)
        latest = analyzer.analyze()
        analyzer.bandLevels(into: bands, count: Self.bandCount)
        ScopeTrace.capture(mono, count: frames, into: trace, length: Self.traceLength)
        // The two sides apart, for the phase meter (a mono tap reads as mono).
        StereoPhase.capture(left: input[0], right: input[right], count: frames, into: phase, pairs: Self.phasePairs)
        correlation = StereoPhase.correlation(left: input[0], right: input[right], count: frames)
    }
}
