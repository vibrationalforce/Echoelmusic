import AVFoundation
import EchoelDSP
import Foundation

/// The Field's ear on the master for the Chladni plate: the strongest partials of the mix as the
/// musician hears it, no microphone. `AudioEngine` feeds it from the same tap on the source node as
/// the live stream (`AudioEngine.listenForSpectrum`), only while a plate is drawn.
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

    init() {
        mono = .allocate(capacity: 1)
        monoCapacity = 1
    }

    deinit {
        mono.deallocate()
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
    }
}
