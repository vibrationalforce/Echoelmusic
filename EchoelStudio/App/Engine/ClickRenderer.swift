import AVFoundation
import Synchronization

/// State the main thread writes and the render thread reads. Atomics only: the render
/// thread never takes a lock and never waits.
final class TransportState: Sendable {
    let isPlaying = Atomic<Bool>(false)
    let clickEnabled = Atomic<Bool>(true)
    let bpmBits = Atomic<UInt64>(120.0.bitPattern)
    let beatsPerBar = Atomic<Int>(4)
    /// Set by the main thread to move the playhead back to the start; the render thread
    /// clears it when it has done so.
    let rewindRequested = Atomic<Bool>(false)
    /// Written by the render thread once per buffer: samples since the song start.
    let samplePosition = Atomic<Int64>(0)

    var bpm: Double {
        get { Double(bitPattern: bpmBits.load(ordering: .relaxed)) }
        set { bpmBits.store(newValue.bitPattern, ordering: .relaxed) }
    }
}

/// The metronome voice. Runs on the render thread: no allocation, no locks, no ObjC calls,
/// no I/O. All its mutable state lives here and is touched only from that thread.
final class ClickRenderer: @unchecked Sendable {
    private let state: TransportState
    private let sampleRate: Double

    private var position: Int64 = 0
    private var lastBeat: Int64 = -1
    private var clickRemaining = 0
    private var clickPhase = 0.0
    private var clickIncrement = 0.0
    private var clickAmplitude: Float = 0

    /// 30 ms click with a fast exponential decay.
    private let clickLength: Int
    private let decayPerSample: Float

    init(state: TransportState, sampleRate: Double) {
        self.state = state
        self.sampleRate = sampleRate
        self.clickLength = Int(sampleRate * 0.03)
        self.decayPerSample = Float(exp(-1.0 / (sampleRate * 0.006)))
    }

    func render(frameCount: AVAudioFrameCount, into bufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        if state.rewindRequested.exchange(false, ordering: .acquiringAndReleasing) {
            position = 0
            lastBeat = -1
        }
        let playing = state.isPlaying.load(ordering: .relaxed)
        let clickOn = state.clickEnabled.load(ordering: .relaxed)
        let bpm = state.bpm
        let samplesPerBeat = bpm.isFinite && bpm > 0 ? sampleRate * 60 / bpm : sampleRate / 2
        let beatsPerBar = Int64(max(1, state.beatsPerBar.load(ordering: .relaxed)))

        for frame in 0..<Int(frameCount) {
            if playing {
                let beat = Int64(Double(position) / samplesPerBeat)
                if beat != lastBeat {
                    lastBeat = beat
                    if clickOn {
                        let downbeat = beat % beatsPerBar == 0
                        clickIncrement = 2 * Double.pi * (downbeat ? 1_760 : 1_100) / sampleRate
                        clickAmplitude = downbeat ? 0.5 : 0.32
                        clickPhase = 0
                        clickRemaining = clickLength
                    }
                }
                position += 1
            }

            var sample: Float = 0
            if clickRemaining > 0 {
                sample = Float(sin(clickPhase)) * clickAmplitude
                clickPhase += clickIncrement
                clickAmplitude *= decayPerSample
                clickRemaining -= 1
            }

            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                data[frame] = sample
            }
        }
        state.samplePosition.store(position, ordering: .relaxed)
        return noErr
    }
}
