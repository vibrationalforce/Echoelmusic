//
//  BroadcastMasterPump.swift
//  Echoelmusic — Stream
//
//  Moves sound and picture from the app to a stream encoder, on ITS OWN queue, at ~100 Hz.
//
//  SOUND comes from the master ring the recorder already keeps (`RetroCapture`, tapped on
//  `mainMixerNode` — after EQ, auto-gain, limiter and the −1 dB output trim, i.e. exactly what
//  the speakers get). The pump reads the ring behind the tap's write head and never writes
//  to it, so the real-time render thread does not know a stream exists: no lock, no
//  allocation, no network, no actor hop ever reaches it. The only line the stream added to
//  the tap is the four-cell host-time anchor (`RetroCapture.masterAnchor`).
//
//  PICTURE comes from `BroadcastVideoTap` (the one Metal view's second draw).
//
//  BOTH are released to the sink only from the shared start `T0` (`BroadcastStartGate`), so
//  the two tracks begin together; afterwards each carries its own real time on the host
//  clock. When no new picture arrives (the visual's unchanged-frame skip, a hidden window),
//  the last picture is repeated so the encoder keeps a steady picture track; when there has
//  never been one, a black picture is sent and `pictureState` says so.
//
//  ⚠️ THE HANDOFF TO THE SINK IS BOUNDED BY THE SINK. `BroadcastMediaSink` implementations
//  must not block and must shed when their own queue is full (the RTMP adapter does). The
//  pump never waits on the network.
//

#if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
import AVFoundation
import Foundation

/// One chunk of the master mix for the encoder. `@unchecked Sendable`: built on the pump
/// queue, handed over once, never touched by the pump again.
struct BroadcastAudioChunk: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    /// Host time of the chunk's first frame.
    let hostTicks: UInt64
}

/// Where the pump delivers. Called on the pump's queue; must return immediately.
protocol BroadcastMediaSink: AnyObject, Sendable {
    func appendAudio(_ chunk: BroadcastAudioChunk)
    func appendVideo(_ frame: BroadcastVideoFrame, stampTicks: UInt64)
}

/// The master ring as the pump sees it — `RetroCapture` in the app, a synthetic ring in tests.
protocol MasterRingSource: AnyObject, Sendable {
    func masterRingView() -> MasterRingView
    func copyMasterFrames(from start: Int64, count: Int,
                          left: UnsafeMutablePointer<Float>,
                          right: UnsafeMutablePointer<Float>) -> Bool
}

/// What the picture track is carrying right now — shown to the person, so a frozen or black
/// stream picture is never a surprise.
enum BroadcastPictureState: Equatable, Sendable {
    case waiting
    case rendering
    case holding
    case black
}

final class BroadcastMasterPump: @unchecked Sendable {

    static let tickSeconds: Double = 0.01
    static let audioChunkFrames = 1024
    /// At most this many audio chunks per tick — a bound on catch-up work after a stall.
    static let maxChunksPerTick = 16
    /// Repeat the last picture when none arrived for this many frame intervals.
    static let holdAfterIntervals: Double = 2
    /// Send black when no picture at all arrived this long after `T0`.
    static let blackAfterSeconds: Double = 0.5

    private let queue = DispatchQueue(label: "com.echoelmusic.broadcast.pump", qos: .userInitiated)
    private let ring: MasterRingSource
    private let video: BroadcastVideoTap
    private let timebase: BroadcastTimebase
    private let now: @Sendable () -> UInt64

    // Queue-owned state. Touched only inside `queue`.
    private var timer: DispatchSourceTimer?
    private var sink: BroadcastMediaSink?
    private var spec: BroadcastVideoSpec = .standard
    private var startTicks: UInt64 = 0
    private var readFrame: Int64?
    private var audioFormat: AVAudioFormat?
    private var lastAnchor: BroadcastAudioAnchor?
    private var sentFirstPicture = false
    private var lastPicture: BroadcastVideoFrame?
    private var lastPictureStamp: UInt64 = 0
    private var blackPicture: BroadcastVideoFrame?
    private var lastIsBlack = false

    // Counters, read from the main actor through `snapshot()`.
    private let statsLock = NSLock()
    private var silencedFrames: Int64 = 0
    private var sentAudioFrames: Int64 = 0
    private var sentPictures = 0
    private var picture: BroadcastPictureState = .waiting

    init(ring: MasterRingSource,
         video: BroadcastVideoTap = .shared,
         timebase: BroadcastTimebase = .host,
         now: @escaping @Sendable () -> UInt64 = { mach_absolute_time() }) {
        self.ring = ring
        self.video = video
        self.timebase = timebase
        self.now = now
    }

    /// Begin delivering to `sink` from `startTicks` on. Replaces any running delivery.
    func start(sink: BroadcastMediaSink, spec: BroadcastVideoSpec, startTicks: UInt64) {
        video.enable(spec, timebase: timebase)
        queue.async { [self] in
            stopOnQueue()
            self.sink = sink
            self.spec = spec
            self.startTicks = startTicks
            readFrame = nil
            audioFormat = nil
            lastAnchor = nil
            sentFirstPicture = false
            lastPicture = nil
            lastPictureStamp = 0
            blackPicture = nil
            lastIsBlack = false
            statsLock.lock()
            silencedFrames = 0; sentAudioFrames = 0; sentPictures = 0; picture = .waiting
            statsLock.unlock()
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now(), repeating: Self.tickSeconds, leeway: .milliseconds(2))
            t.setEventHandler { [weak self] in self?.tick() }
            timer = t
            t.resume()
        }
    }

    /// Stop delivering. Synchronous: once this returns, the sink receives nothing more.
    func stop() {
        video.disable()
        queue.sync { stopOnQueue() }
    }

    private func stopOnQueue() {
        timer?.cancel()
        timer = nil
        sink = nil
        lastPicture = nil
        blackPicture = nil
    }

    struct Snapshot: Equatable, Sendable {
        let sentAudioSeconds: Double
        let silencedSeconds: Double
        let sentPictures: Int
        let droppedPictures: Int
        let picture: BroadcastPictureState
    }

    func snapshot() -> Snapshot {
        statsLock.lock(); defer { statsLock.unlock() }
        let rate = lastAnchorRate
        return Snapshot(sentAudioSeconds: rate > 0 ? Double(sentAudioFrames) / rate : 0,
                        silencedSeconds: rate > 0 ? Double(silencedFrames) / rate : 0,
                        sentPictures: sentPictures,
                        droppedPictures: video.droppedFrames,
                        picture: picture)
    }

    /// Written under `statsLock` by the queue, read by `snapshot()`.
    private var lastAnchorRate: Double = 0

    // MARK: - Tick (queue only)

    /// Exposed for tests: one tick, run synchronously on the pump's queue.
    func tickForTesting() { queue.sync { tick() } }

    private func tick() {
        guard let sink else { return }
        pumpAudio(into: sink)
        pumpPicture(into: sink)
    }

    private func pumpAudio(into sink: BroadcastMediaSink) {
        let view = ring.masterRingView()
        guard let anchor = view.anchor, anchor.isUsable else { return }
        lastAnchor = anchor
        if readFrame == nil {
            guard let first = BroadcastStartGate.firstAudioFrame(anchor: anchor, startTicks: startTicks,
                                                                 timebase: timebase) else { return }
            readFrame = first
        }
        guard var position = readFrame else { return }
        if audioFormat?.sampleRate != anchor.sampleRate {
            audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: anchor.sampleRate,
                                        channels: 2, interleaved: false)
        }
        guard let format = audioFormat else { return }
        statsLock.lock(); lastAnchorRate = anchor.sampleRate; statsLock.unlock()

        for _ in 0..<Self.maxChunksPerTick {
            let plan = MasterRingReadPlan.next(readFrame: position, view: view,
                                               maxChunk: Self.audioChunkFrames)
            let from: Int64
            let count: Int
            var silent = false
            switch plan {
            case .wait:
                readFrame = position
                return
            case .read(let f, let c):
                from = f; count = c
            case .silence(let f, let c):
                from = f; count = c; silent = true
            }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
                  let channels = buffer.floatChannelData else { readFrame = position; return }
            buffer.frameLength = AVAudioFrameCount(count)
            if !silent {
                silent = !ring.copyMasterFrames(from: from, count: count,
                                                left: channels[0], right: channels[1])
            }
            if silent {
                channels[0].update(repeating: 0, count: count)
                channels[1].update(repeating: 0, count: count)
            }
            let stamp = anchor.hostTicks(forFrame: from, timebase: timebase) ?? startTicks
            sink.appendAudio(BroadcastAudioChunk(buffer: buffer, hostTicks: stamp))
            position = from + Int64(count)
            statsLock.lock()
            sentAudioFrames += Int64(count)
            if silent { silencedFrames += Int64(count) }
            statsLock.unlock()
        }
        readFrame = position
    }

    private func pumpPicture(into sink: BroadcastMediaSink) {
        for frame in video.drain() {
            guard let stamp = BroadcastStartGate.videoStamp(renderedAt: frame.hostTicks,
                                                            startTicks: startTicks,
                                                            isFirst: !sentFirstPicture),
                  stamp > lastPictureStamp else { continue }
            lastIsBlack = false
            send(frame, stamp: stamp, state: .rendering, to: sink)
        }
        let t = now()
        guard t > startTicks else { return }
        let interval = timebase.ticks(seconds: 1.0 / spec.framesPerSecond)
        if let last = lastPicture {
            // No new picture for a while: repeat the last one so the picture track stays steady.
            let holdAfter = UInt64(Double(interval) * Self.holdAfterIntervals)
            if t > lastPictureStamp &+ holdAfter {
                send(last, stamp: t, state: lastIsBlack ? .black : .holding, to: sink)
            }
        } else if t > startTicks &+ timebase.ticks(seconds: Self.blackAfterSeconds) {
            if blackPicture == nil, let pb = BroadcastFrameTarget.blackFrame(width: spec.width, height: spec.height) {
                blackPicture = BroadcastVideoFrame(pixelBuffer: pb, hostTicks: t, metalTexture: nil)
            }
            if let black = blackPicture {
                lastIsBlack = true
                send(black, stamp: sentFirstPicture ? t : startTicks, state: .black, to: sink)
            }
        }
    }

    private func send(_ frame: BroadcastVideoFrame, stamp: UInt64, state: BroadcastPictureState,
                      to sink: BroadcastMediaSink) {
        sink.appendVideo(frame, stampTicks: stamp)
        sentFirstPicture = true
        lastPicture = frame
        lastPictureStamp = stamp
        statsLock.lock(); sentPictures += 1; picture = state; statsLock.unlock()
    }
}

extension RetroCapture: MasterRingSource {}
#endif
