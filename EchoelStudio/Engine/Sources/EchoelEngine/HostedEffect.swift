import AudioToolbox
import AVFoundation
import EchoelCore
import Foundation

/// An Audio Unit effect on a track's insert chain, processed inside the engine's own render
/// pass like `HostedUnit`. The unit pulls the track's stereo bus through a pull-input block made
/// once, here; its output replaces the bus.
///
/// Built on the main thread from a unit whose render resources are allocated at the engine's
/// rate. The render thread only calls the blocks and writes buffers allocated here.
public final class HostedEffect: ParameterScheduling, @unchecked Sendable {
    public let sampleRate: Double
    public let maximumFrames: Int
    /// A bypassed effect is skipped; the bus passes through unchanged.
    public let isBypassed: Bool
    /// The insert this effect plays, so the song's automation of it finds it.
    public let insert: InsertID?
    public let parameterRanges: [UInt64: ClosedRange<Float>]

    private let renderBlock: AURenderBlock
    private let scheduleParameter: AUScheduleParameterBlock?
    private let owner: AnyObject?
    private let outLeft: UnsafeMutablePointer<Float>
    private let outRight: UnsafeMutablePointer<Float>
    private let list: UnsafeMutableAudioBufferListPointer
    /// Render thread only: what the pull-input block hands the unit during one `process` call.
    private var inLeft: UnsafeMutablePointer<Float>?
    private var inRight: UnsafeMutablePointer<Float>?
    private var sampleTime: Double = 0
    private var pullInput: AURenderPullInputBlock?

    public init(render: @escaping AURenderBlock, sampleRate: Double, maximumFrames: Int, isBypassed: Bool = false,
                owner: AnyObject?, insert: InsertID? = nil, scheduleParameter: AUScheduleParameterBlock? = nil,
                parameterRanges: [UInt64: ClosedRange<Float>] = [:]) {
        renderBlock = render
        self.insert = insert
        self.scheduleParameter = scheduleParameter
        self.parameterRanges = parameterRanges
        self.sampleRate = sampleRate
        self.maximumFrames = Swift.max(1, maximumFrames)
        self.isBypassed = isBypassed
        self.owner = owner
        outLeft = .allocate(capacity: self.maximumFrames)
        outLeft.initialize(repeating: 0, count: self.maximumFrames)
        outRight = .allocate(capacity: self.maximumFrames)
        outRight.initialize(repeating: 0, count: self.maximumFrames)
        list = AudioBufferList.allocate(maximumBuffers: 2)
        // Made once: forming a closure on the render thread would allocate.
        pullInput = { [unowned self] _, _, frames, _, input in
            self.fill(input, frames: Int(frames))
        }
    }

    deinit {
        outLeft.deallocate()
        outRight.deallocate()
        free(list.unsafeMutablePointer)
    }

    /// Render thread: the unit's input is the bus, in its own buffers or pointed at ours.
    private func fill(_ input: UnsafeMutablePointer<AudioBufferList>, frames: Int) -> AUAudioUnitStatus {
        guard let inLeft, let inRight, frames <= maximumFrames else { return kAudioUnitErr_TooManyFramesToProcess }
        var buffers = UnsafeMutableAudioBufferListPointer(input)
        for (index, buffer) in buffers.enumerated() {
            let source = index == 0 ? inLeft : inRight
            let bytes = UInt32(frames * MemoryLayout<Float>.size)
            if let data = buffer.mData {
                let count = Swift.min(frames, Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
                data.assumingMemoryBound(to: Float.self).update(from: source, count: count)
            } else {
                buffers[index].mData = UnsafeMutableRawPointer(source)
                buffers[index].mDataByteSize = bytes
            }
        }
        return noErr
    }

    public func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {
        scheduleParameter?(AUEventSampleTimeImmediate + AUEventSampleTime(Swift.max(0, offset)),
                           AUAudioFrameCount(Swift.max(0, ramp)), address, value)
    }

    /// Replaces `frames` of the bus with the effect's output. A unit that fails a block leaves
    /// the bus as it was; a sample that is not finite becomes silence.
    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        guard !isBypassed, frames > 0, frames <= maximumFrames else { return }
        inLeft = left
        inRight = right
        defer { inLeft = nil; inRight = nil }
        let bytes = UInt32(frames * MemoryLayout<Float>.size)
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: UnsafeMutableRawPointer(outLeft))
        list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: UnsafeMutableRawPointer(outRight))
        var flags = AudioUnitRenderActionFlags()
        var stamp = AudioTimeStamp()
        stamp.mSampleTime = sampleTime
        stamp.mFlags = .sampleTimeValid
        let status = renderBlock(&flags, &stamp, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, pullInput)
        sampleTime += Double(frames)
        guard status == noErr, let l = list[0].mData?.assumingMemoryBound(to: Float.self) else { return }
        let r = list.count > 1 ? (list[1].mData?.assumingMemoryBound(to: Float.self) ?? l) : l
        for i in 0..<frames {
            let a = l[i], b = r[i]
            left[i] = a.isFinite ? a : 0
            right[i] = b.isFinite ? b : 0
        }
    }
}
