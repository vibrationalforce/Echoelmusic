import AudioToolbox
import AVFoundation
import Foundation

/// An Audio Unit instrument the engine plays from inside its own render pass: the sequencer
/// schedules each note through the unit's MIDI block at its exact frame in the block, then the
/// unit renders the block into buffers allocated here. One graph, one render thread, the same
/// sample accuracy as the built-in instruments — and nothing for AVAudioEngine to reconnect.
///
/// Built on the main thread from a unit whose render resources are allocated at the engine's
/// rate. The render thread only calls the two blocks and writes the buffers; it allocates
/// nothing and never releases the last reference (the snapshot that holds this keeps it).
public final class HostedUnit: @unchecked Sendable {
    public let sampleRate: Double
    public let maximumFrames: Int

    private let renderBlock: AURenderBlock
    private let scheduleMIDI: AUScheduleMIDIEventBlock?
    /// What must outlive the blocks — the `AUAudioUnit` itself.
    private let owner: AnyObject?
    private let leftBuffer: UnsafeMutablePointer<Float>
    private let rightBuffer: UnsafeMutablePointer<Float>
    private let list: UnsafeMutableAudioBufferListPointer
    /// Render thread only: the unit's own clock, one step per rendered frame.
    private var sampleTime: Double = 0

    public init(render: @escaping AURenderBlock, scheduleMIDI: AUScheduleMIDIEventBlock?, sampleRate: Double,
                maximumFrames: Int, owner: AnyObject?) {
        renderBlock = render
        self.scheduleMIDI = scheduleMIDI
        self.sampleRate = sampleRate
        self.maximumFrames = Swift.max(1, maximumFrames)
        self.owner = owner
        leftBuffer = .allocate(capacity: self.maximumFrames)
        leftBuffer.initialize(repeating: 0, count: self.maximumFrames)
        rightBuffer = .allocate(capacity: self.maximumFrames)
        rightBuffer.initialize(repeating: 0, count: self.maximumFrames)
        list = AudioBufferList.allocate(maximumBuffers: 2)
    }

    deinit {
        leftBuffer.deallocate()
        rightBuffer.deallocate()
        free(list.unsafeMutablePointer)
    }

    // MARK: - Render thread

    /// A note-on `offset` frames into the next `render` call, on MIDI channel 1.
    func noteOn(pitch: UInt8, velocity: UInt8, offset: Int) {
        send(0x90, pitch & 0x7F, Swift.max(1, velocity & 0x7F), offset: offset)
    }

    func noteOff(pitch: UInt8, offset: Int) {
        send(0x80, pitch & 0x7F, 0, offset: offset)
    }

    /// All Notes Off (controller 123), at the start of the next `render` call.
    func allNotesOff() {
        send(0xB0, 123, 0, offset: 0)
    }

    private func send(_ status: UInt8, _ data1: UInt8, _ data2: UInt8, offset: Int) {
        guard let scheduleMIDI else { return }
        let bytes: (UInt8, UInt8, UInt8) = (status, data1, data2)
        withUnsafeBytes(of: bytes) { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            scheduleMIDI(AUEventSampleTimeImmediate + AUEventSampleTime(Swift.max(0, offset)), 0, 3, base)
        }
    }

    /// Renders `frames` and adds them into `left` and `right` at the lane's gains. A unit that
    /// fails a block, or returns a value that is not finite, contributes nothing for that frame.
    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
                gainLeft: Float, gainRight: Float) {
        guard frames > 0, frames <= maximumFrames else { return }
        let bytes = UInt32(frames * MemoryLayout<Float>.size)
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: UnsafeMutableRawPointer(leftBuffer))
        list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: UnsafeMutableRawPointer(rightBuffer))
        var flags = AudioUnitRenderActionFlags()
        var stamp = AudioTimeStamp()
        stamp.mSampleTime = sampleTime
        stamp.mFlags = .sampleTimeValid
        let status = renderBlock(&flags, &stamp, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, nil)
        sampleTime += Double(frames)
        guard status == noErr else { return }
        // A unit may point the buffers at its own memory instead of filling ours.
        guard let l = list[0].mData?.assumingMemoryBound(to: Float.self) else { return }
        let r = list.count > 1 ? (list[1].mData?.assumingMemoryBound(to: Float.self) ?? l) : l
        for i in 0..<frames {
            let a = l[i], b = r[i]
            if a.isFinite { left[i] += a * gainLeft }
            if b.isFinite { right[i] += b * gainRight }
        }
    }
}
