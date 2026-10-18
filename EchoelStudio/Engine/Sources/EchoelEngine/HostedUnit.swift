import AudioToolbox
import AVFoundation
import Foundation

/// A hosted unit whose parameters automation moves. The ranges are read once, on the main
/// thread; `schedule` is called on the render thread, for the unit's next render call.
public protocol ParameterScheduling: AnyObject, Sendable {
    /// The unit's writable parameters by address, each with its range.
    var parameterRanges: [UInt64: ClosedRange<Float>] { get }
    /// Moves `address` to `value`, `offset` frames into the next render call, gliding over
    /// `ramp` frames where the unit can.
    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int)
}

/// An Audio Unit instrument the engine plays from inside its own render pass: the sequencer
/// schedules each note through the unit's MIDI block at its exact frame in the block, then the
/// unit renders the block into buffers allocated here. One graph, one render thread, the same
/// sample accuracy as the built-in instruments — and nothing for AVAudioEngine to reconnect.
///
/// Built on the main thread from a unit whose render resources are allocated at the engine's
/// rate. The render thread only calls the two blocks and writes the buffers; it allocates
/// nothing and never releases the last reference (the snapshot that holds this keeps it).
public final class HostedUnit: ParameterScheduling, @unchecked Sendable {
    public let sampleRate: Double
    public let maximumFrames: Int
    public let parameterRanges: [UInt64: ClosedRange<Float>]

    private let renderBlock: AURenderBlock
    private let scheduleMIDI: AUScheduleMIDIEventBlock?
    private let scheduleParameter: AUScheduleParameterBlock?
    /// What must outlive the blocks — the `AUAudioUnit` itself.
    private let owner: AnyObject?
    private let leftBuffer: UnsafeMutablePointer<Float>
    private let rightBuffer: UnsafeMutablePointer<Float>
    private let list: UnsafeMutableAudioBufferListPointer
    /// Render thread only: the unit's own clock, one step per rendered frame.
    private var sampleTime: Double = 0

    /// `parameterRanges` holds the unit's writable parameters that automation may move, by
    /// address; `scheduleParameter` moves them.
    public init(render: @escaping AURenderBlock, scheduleMIDI: AUScheduleMIDIEventBlock?, sampleRate: Double,
                maximumFrames: Int, owner: AnyObject?, scheduleParameter: AUScheduleParameterBlock? = nil,
                parameterRanges: [UInt64: ClosedRange<Float>] = [:]) {
        renderBlock = render
        self.scheduleMIDI = scheduleMIDI
        self.scheduleParameter = scheduleParameter
        self.parameterRanges = parameterRanges
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

    /// A pitch bend or controller, `offset` frames into the next `render` call.
    func control(status: UInt8, _ data1: UInt8, _ data2: UInt8, offset: Int = 0) {
        let kind = status & 0xF0
        guard kind == 0xB0 || kind == 0xE0 else { return }
        send(kind, data1 & 0x7F, data2 & 0x7F, offset: offset)
    }

    /// All Notes Off (controller 123), with the pedal lifted and the wheel centred, at the start
    /// of the next `render` call — a stop in the middle of a bent, held phrase leaves neither.
    func allNotesOff() {
        send(0xB0, 64, 0, offset: 0)
        send(0xE0, 0, 0x40, offset: 0)
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

    public func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {
        scheduleParameter?(AUEventSampleTimeImmediate + AUEventSampleTime(Swift.max(0, offset)),
                           AUAudioFrameCount(Swift.max(0, ramp)), address, value)
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
