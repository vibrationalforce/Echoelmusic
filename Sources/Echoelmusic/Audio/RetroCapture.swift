#if canImport(AVFoundation)
import AVFoundation
import Accelerate
import Foundation
import Observation
import os.log

/// Always-on audio capture with retroactive pre-roll ring buffer.
///
/// Lifecycle:
///   1. `install(on:)` — installs tap on mainMixerNode, ring buffer fills continuously.
///   2. `startRecording()` — prepends last 30s pre-roll, then begins writing live audio.
///   3. `stopRecording(completion:)` — closes file, calls completion with URL.
/// The release/acquire pair for the capture ring's cursor — the half #1413b named as NOT held.
///
/// ⛔ `nonisolated(unsafe)` IS NOT SYNCHRONISATION, and "one writer, one reader" is not a
/// memory-model guarantee. The tap fills `ring` and then stores `ringWriteFrame`; every consumer
/// loads `ringWriteFrame` and then reads `ring`. arm64 is NOT total-store-ordered, so nothing in
/// a plain store/load pair stops the cursor from becoming visible BEFORE the slots it covers.
/// The consumer then reads a slot the tap never filled — a click in a recording, not a crash,
/// which is the defect class that gets blamed on hardware for months.
///
/// ⭐ THE MECHANISM IS NOT NEW AND NEEDED NO NEW DEPENDENCY — that is the whole finding.
/// `Core/SPSCQueue.swift` already implements this exact protocol with this exact call:
/// `OSMemoryBarrier()` before publishing `tail`, and again after loading it and before touching
/// the slot, with a comment naming arm64 non-TSO as the reason. Measure, do not quote:
/// `grep -n "OSMemoryBarrier()" Sources/Echoelmusic/Core/SPSCQueue.swift`.
///
/// ⛔ AND #1413b READ THAT FILE WRONG, which is why this sat open as a "needs a new primitive"
/// slice. It said #1237 "REMOVED `OSAtomicIncrement64Barrier` — a fence per operation on the
/// lock-free spine was judged the worse trade", which reads as *this repo decided against
/// fences*. #1237 removed them from the METRICS counters and KEPT them on the publish path. The
/// repo's position is **fences where ordering is load-bearing, none on bookkeeping** — and
/// `RetroCapture` had taken neither. A retraction that describes a decision more broadly than it
/// was made costs the next session the cheap fix.
///
/// ⚠️ RT-SAFE: `OSMemoryBarrier` is a fence instruction — no lock, no allocation, no syscall, no
/// ObjC. One per tap callback against 4096 frames of work, and it already runs on an
/// audio-thread path in `SPSCQueue`.
///
/// ⚠️ THE ACCESSOR EXISTS SO THE NEXT READER CANNOT FORGET IT (#416). Eight sites touch this
/// cursor; a barrier written out at each is one refactor away from being dropped at one of
/// them, and the loss is silent. Read the cursor ONLY through `load`.
enum RetroRingCursor {

    /// Publish AFTER filling — the release half.
    @inline(__always)
    static func publish(_ cursor: UnsafeMutablePointer<Int64>, _ frame: Int64) {
        OSMemoryBarrier()
        cursor.pointee = frame
    }

    /// Load BEFORE reading slots — the acquire half. Without it the slot loads may be satisfied
    /// ahead of the cursor load, which is the same hazard from the other side.
    @inline(__always)
    static func load(_ cursor: UnsafeMutablePointer<Int64>) -> Int64 {
        let frame = cursor.pointee
        OSMemoryBarrier()
        return frame
    }
}

@MainActor @Observable
final class RetroCapture {

    // MARK: - Observable state

    private(set) var isRecording = false
    private(set) var recordingSeconds = 0
    private(set) var lastURL: URL?

    /// Set when the disk writer could not write a chunk — a full volume, a revoked
    /// container, a closed file. (Until #1413 the TAP raised this; it no longer writes.) Cleared once a recording actually STARTS (not when one
    /// is merely attempted: the file/format/pre-roll steps ahead of it can throw, and
    /// those failures are reported by `startRecording` itself, not through this latch).
    ///
    /// WHY THIS EXISTS AT ALL. The write error used to be caught and logged and NOTHING
    /// else: `isRecording` stayed true, the REC pill kept counting, and the take was
    /// quietly short or empty. That is the lying-control class — the same failure as a
    /// record button armed over a renderer that is not capturing. A performer must find
    /// out during the take, not when opening the file afterwards.
    private(set) var writeFailed = false

    /// Seconds of audio the disk writer could not keep up with (#1413). Lifted by the same
    /// 2 Hz tick as `writeFailed`, for the same reason: a performer must find out DURING the
    /// take, not when opening the file afterwards.
    private(set) var droppedSeconds: Double = 0

    /// Downsampled waveform for UI display — 200 RMS values spanning last 30s.
    /// Updated every 500ms via waveformTimer.
    private(set) var waveformSamples: [Float] = Array(repeating: 0, count: 200)

    // MARK: - Ring buffer (always-on pre-roll: 30s stereo @ 48kHz ≈ 11MB)

    private let preRollSeconds: Int = 30
    private let waveformResolution: Int = 200       // display points
    /// #1413 — `nonisolated` because the off-thread disk writer indexes the ring with it.
    nonisolated private let ringCapacity: Int

    /// The ACTUAL sample rate the tap captures at (= mixer/hardware rate, which iOS may
    /// grant as 44.1 kHz even though we request 48 kHz — e.g. once the rPPG camera route
    /// is active). Set in `install(on:)` from the tap's real format. ALL seconds↔frames
    /// math and every output-file format use this, NOT a hardcoded 48000 — otherwise the
    /// captured audio plays back pitch-shifted ("viel höher") and mistimed ("unruhig").
    /// MainActor-only (the audio-thread tap callback indexes the ring by frame and never
    /// reads this). Ring is sized for the 48 kHz max so a lower rate just yields >30 s.
    private var captureSampleRate: Double = 48000
    /// #630 — the oldest ring frame that was captured at the CURRENT `captureSampleRate`.
    ///
    /// THE DEFECT IT CLOSES. The configuration-change watchdog re-installs this tap exactly
    /// BECAUSE the hardware rate moves (the rPPG camera activating mid-session drops the
    /// route from 48 kHz to 44.1 kHz). `install(on:)` then re-read the new rate into
    /// `captureSampleRate` — but the ring still held up to 30 s of frames sampled at the OLD
    /// rate, and every reader below computes its window with `captureSampleRate` for the
    /// WHOLE window and builds the output file's format from it. So a retroactive capture
    /// spanning the switch was written with the wrong rate stamped on old frames: the exact
    /// "viel höher" pitch-shift the watchdog comment says it prevents, moved from the live
    /// tap into the pre-roll history.
    ///
    /// WHY A BOUNDARY AND NOT A RESET. Zeroing the ring on every route change is simpler and
    /// throws away up to 30 s of PERFECTLY GOOD audio whenever the rate did not actually
    /// change (a headphone unplug re-installs too). A boundary discards exactly the frames
    /// that are wrong and keeps every frame that is right — and it costs one `Int64` and no
    /// work at all on the audio thread, which a 11 MB `memset` at route-change time would not.
    ///
    /// Monotonic, like `ringWriteFrame`: once more than `ringCapacity` frames have been
    /// captured at the new rate the clamp goes inert on its own, with nothing to reset.
    ///
    /// ⚠️ WHAT THIS DOES **NOT** COVER, registered rather than implied (#630b). A rate change
    /// DURING an active take is untouched: `install(on:)` re-installs the tap with the new
    /// format while `activeFile` was opened at the OLD `captureSampleRate`, and the tap's
    /// `file.write(from:)` then meets a format mismatch. That path raises an Objective-C
    /// exception, which a Swift `try` does not catch — so the `catch` below and the
    /// `writeFailure` latch may never run at all. Pre-existing, a genuinely separate slice
    /// (it needs a decision about whether to close and re-open the file mid-take, or to end
    /// the take honestly), and named here so the retraction in `AudioEngine`'s watchdog is
    /// not read as "the rate hazard in this file is closed". It is closed for the PRE-ROLL.
    private var rateBoundaryFrame: Int64 = 0
    nonisolated(unsafe) private let ring: UnsafeMutablePointer<Float>
    nonisolated(unsafe) private let ringWriteFrame: UnsafeMutablePointer<Int64>

    // MARK: - Recording

    nonisolated(unsafe) private let activeFile: UnsafeMutablePointer<AVAudioFile?>
    nonisolated(unsafe) private let isActive: UnsafeMutablePointer<Bool>

    // MARK: - #1413 — the disk writer lives OFF the tap

    /// The one thread that ever touches `activeFile` while a take runs.
    ///
    /// WHY THIS EXISTS. Until #1413 the tap block itself called `file.write(from:)` and, on
    /// failure, formatted `error.localizedDescription` — a synchronous filesystem write and a
    /// bundle lookup inside an `AVAudioNodeTapBlock`. Apple does NOT document that block as a
    /// hard realtime callback and does not forbid `AVAudioFile.write(from:)` there, so this is
    /// not a proven API-contract violation; Apple only says the block is invoked off the main
    /// thread, in a different execution context from the one that installed it. What it IS, is
    /// a potentially blocking operation on a deadline-sensitive capture path: a stalled volume,
    /// an iCloud eviction or a full disk turns one buffer's write into an underrun. Apple's own
    /// DTS guidance for this block is to COPY the samples out and dispatch the work elsewhere,
    /// which is exactly the shape below.
    ///
    /// The tap therefore does one thing now: fill the ring, which it always did FIRST anyway.
    /// This queue follows the ring's write cursor and drains it into the file. Single producer
    /// (tap), single consumer (this queue) — the same discipline `writePreRollToFile` has used
    /// since the ring existed, only continuous.
    nonisolated private let writeQueue = DispatchQueue(label: "com.echoelmusic.retrocapture.disk",
                                                       qos: .utility)
    nonisolated(unsafe) private var drainTimer: DispatchSourceTimer?
    /// Format of the open file. Queue-owned: written before the timer starts, read only by it.
    nonisolated(unsafe) private var writeFormat: AVAudioFormat?

    /// Next ABSOLUTE ring frame the writer still owes the file. Monotonic, like `ringWriteFrame`.
    ///
    /// ⭐ INVARIANT 1 — **ABSOLUTE, NEVER MODULO.** Both cursors count frames since the tap was
    /// installed and are never wrapped; `end - start` is therefore literally
    /// `producedFrames - consumedFrames`, and `> ringCapacity` is a sound overrun test. The
    /// modulo lives in exactly one place, `writeRange`'s indexing loop. A cursor kept in
    /// `0..<capacity` would look plausible again after one full lap and could not tell a full
    /// buffer from an empty one, let alone a lost one — that is the classic ring-buffer defect
    /// and this design does not have it. `Int64` at 48 kHz overflows in about six million
    /// years, so the monotonicity is not a leak.
    ///
    /// ⚠️ INVARIANT 2 — **HALF-HELD, AND SAYING SO IS THE POINT.** Each cursor has exactly ONE
    /// writer (`ringWriteFrame` the tap, `drainFrame` this queue) and is a naturally aligned
    /// 64-bit word, so a reader can see a value one update STALE but never a TORN one. Staleness
    /// is safe here by construction: a stale `end` makes the drain write less this tick and catch
    /// up on the next. That is the same discipline `SPSCQueue` chose deliberately in #1237, when
    /// it REMOVED `OSAtomicIncrement64Barrier` — a fence per operation on the lock-free spine was
    /// judged the worse trade.
    ///
    /// ⭐ **THE ORDERING IS HELD SINCE #1429** — this paragraph used to end "what is NOT held is
    /// the ORDERING", and closing it turned out to cost far less than this note predicted. It
    /// said the fix "needs `Synchronization.Atomic` … a slice of its own, because a concurrency
    /// primitive introduced without a compiler is a guess". No new primitive was needed:
    /// `SPSCQueue` already publishes with `OSMemoryBarrier()` and acquires with it, for this
    /// same hazard, on this same platform. The pair now lives in `RetroRingCursor` at the top of
    /// this file, and every one of the eight cursor sites goes through it.
    ///
    /// ⚠️ **WHAT IS STILL NOT SYNCHRONISED, named rather than implied.** `writeFailure`,
    /// `droppedFrames` and `isActive` are still plain cells. Their second writers are
    /// TEMPORALLY exclusive by construction, not by luck — `startRecording` writes them all
    /// before `isActive` goes true and before the drain timer resumes, and `stopRecording`
    /// clears `isActive`, cancels the timer and then takes `writeQueue.sync`, which is a real
    /// happens-before edge. The ONE read left outside that edge is the `writeFailure` lift
    /// immediately before the `sync`: it can observe a stale latch, and the line two statements
    /// after the `sync` re-reads it. A late latch, never a wrong file. ⛔ The old wording here
    /// argued this from "a torn read is not expressible for a `Bool`" — that answers the wrong
    /// question. Tearing and a data race are different things; a `Bool` cannot tear and an
    /// unsynchronised concurrent read/write is still a race. The defence is the exclusion
    /// above, not the width of the word.
    nonisolated(unsafe) private let drainFrame: UnsafeMutablePointer<Int64>

    /// Frames the tap overwrote before the writer got to them.
    ///
    /// ⚠️ THIS IS A NEW FAILURE MODE AND IT IS NAMED RATHER THAN HIDDEN. The old tap-side write
    /// could not lose audio — it held the buffer in its hand. A cursor that follows the ring can
    /// fall behind, and if it ever falls more than `ringCapacity` frames behind, the tap has
    /// already overwritten what was owed. With a 30 s ring and a 200 ms drain that needs a total
    /// storage stall, in which case `writeFailure` fires as well — but a recorder that silently
    /// drops audio is the lying-control class this file already refuses (`writeFailed`), so the
    /// gap gets a counter and a surface of its own.
    nonisolated(unsafe) private let droppedFrames: UnsafeMutablePointer<Int64>

    /// Raised by the disk writer on the FIRST failed write, read by the 2 Hz waveform timer.
    ///
    /// A plain `Bool` cell, matching `isActive` next to it, because the traffic here is
    /// one writer (`writeQueue`) and one reader (the main actor) exchanging a latch that
    /// only ever goes false→true within a take. A torn read is not expressible for a Bool and
    /// a late read costs at most half a second.
    ///
    /// The writer sets it and then STOPS attempting writes. That is the point: without it,
    /// a disk that filled mid-take produced one failed write, one `localizedDescription`
    /// (a bundle lookup) and one log allocation PER ATTEMPT for the rest of a take that was
    /// already lost. ⚠️ Until #1413 those attempts happened ~12 times a second ON THE TAP
    /// THREAD, which is what made this latch urgent rather than tidy; it is now 5 times a
    /// second on a utility queue. The latch is kept anyway: error handling that gets more
    /// expensive the longer the error lasts is a load source, not a diagnostic, wherever it
    /// runs — and the one-line-then-quiet shape is also what makes the log readable.
    nonisolated(unsafe) private let writeFailure: UnsafeMutablePointer<Bool>

    private var timer: Timer?
    private var waveformTimer: Timer?

    /// The node we installed the tap on. Held weakly so deinit can remove the tap
    /// before deallocating the pointers the tap callback dereferences (use-after-free
    /// guard). nonisolated(unsafe) so the nonisolated deinit may read it.
    nonisolated(unsafe) private weak var tappedNode: AVAudioNode?

    // MARK: - Init / deinit

    init() {
        let sr = 48000
        ringCapacity = sr * preRollSeconds      // frames per channel
        let totalFloats = ringCapacity * 2      // interleaved stereo

        ring = .allocate(capacity: totalFloats)
        ring.initialize(repeating: 0, count: totalFloats)

        ringWriteFrame = .allocate(capacity: 1)
        ringWriteFrame.initialize(to: 0)

        activeFile = .allocate(capacity: 1)
        activeFile.initialize(to: nil)

        isActive = .allocate(capacity: 1)
        isActive.initialize(to: false)

        writeFailure = .allocate(capacity: 1)
        writeFailure.initialize(to: false)

        drainFrame = .allocate(capacity: 1)
        drainFrame.initialize(to: 0)

        droppedFrames = .allocate(capacity: 1)
        droppedFrames.initialize(to: 0)
    }

    deinit {
        // Stop the tap callback BEFORE freeing the buffers/flags it dereferences.
        // removeTap(onBus:) is synchronous — no callback fires after it returns — so
        // ordering it ahead of the deallocations closes the use-after-free window.
        isActive.pointee = false
        tappedNode?.removeTap(onBus: 0)
        // #1413 — the disk writer dereferences the same pointers. `cancel()` alone is not a
        // barrier (a handler already running keeps running), so drain the queue synchronously
        // afterwards: once an empty block has run to completion on a SERIAL queue, no earlier
        // block is still executing. Same use-after-free reasoning as `removeTap` above, one
        // consumer over.
        drainTimer?.cancel()
        drainTimer = nil
        writeQueue.sync { }
        activeFile.pointee = nil
        ring.deallocate()
        ringWriteFrame.deallocate()
        activeFile.deallocate()
        isActive.deallocate()
        writeFailure.deallocate()
        drainFrame.deallocate()
        droppedFrames.deallocate()
    }

    // MARK: - Tap installation

    /// Call once after AVAudioEngine has started. Removes any existing tap first.
    func install(on engine: AVAudioEngine) {
        let node = engine.mainMixerNode
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            log.log(.error, category: .audio, "RetroCapture: invalid format — tap not installed")
            return
        }

        node.removeTap(onBus: 0)    // idempotent — removes previous tap if any
        tappedNode = node           // weak ref so deinit can remove the tap

        // #630: a CHANGED rate invalidates the history, not the reinstall itself. Compare
        // before assigning — most reinstalls (headphone unplug, engine restart) keep the
        // same rate and must keep their pre-roll.
        if format.sampleRate != captureSampleRate {
            rateBoundaryFrame = RetroRingCursor.load(ringWriteFrame)
            log.log(.info, category: .audio,
                    "RetroCapture: capture rate \(captureSampleRate) → \(format.sampleRate) Hz; "
                    + "pre-roll history before frame \(rateBoundaryFrame) is no longer usable")
        }
        captureSampleRate = format.sampleRate   // real capture rate for all frame math + file format

        // Capture raw pointers only — never capture self on audio-thread callback.
        // #1413 — `filePtr`/`activePtr`/`failPtr` are NO LONGER captured. The tap fills the ring
        // and nothing else; the disk writer below follows the ring's cursor. See the `writeQueue`
        // doc for why, and for what Apple does and does not actually say about this block.
        let ringPtr  = ring
        let writePtr = ringWriteFrame
        let cap      = ringCapacity

        node.installTap(onBus: 0, bufferSize: 4096, format: format) { @Sendable buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            let chCount    = Int(buffer.format.channelCount)
            // ⚠️ RAW ON PURPOSE — this is the producer reading its OWN last publish, not a
            // cross-thread load. `RetroRingCursor.load` here would be a pointless fence in the
            // hottest loop in the app, and reading it through the accessor would also imply a
            // second consumer that does not exist. The acquire half belongs to the READERS.
            var frame      = Int(writePtr.pointee)

            for f in 0..<frameCount {
                let slot = (frame % cap) * 2
                ringPtr[slot]     = channelData[0][f]
                ringPtr[slot + 1] = chCount > 1 ? channelData[1][f] : channelData[0][f]
                frame &+= 1
            }
            // PUBLISH LAST — and #1429 finally gives that sentence its release barrier. The
            // cursor tells the writer which frames are finished, so it must never become
            // VISIBLE before the slots the loop above filled. A plain store did not ensure
            // that on arm64; `publish` does.
            RetroRingCursor.publish(writePtr, Int64(frame))
        }


        log.log(.info, category: .audio,
                "RetroCapture tap installed — \(Int(format.sampleRate))Hz \(format.channelCount)ch, \(preRollSeconds)s ring")

        // Start waveform refresh at 2Hz for UI display
        waveformTimer?.invalidate()
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateWaveform() }
        }
    }

    // MARK: - Waveform

    private func updateWaveform() {
        // The 2 Hz timer is how a failed write reaches the user DURING a take (the other
        // lift is in `stopRecording`, for a failure in the last half-second). Adding a
        // dedicated timer for a flag that flips at most once would be worse than half a
        // second of latency on a take that is already lost.
        //
        // Deliberately NOT gated on `isRecording`: the latch can only be raised while the
        // tap was armed, so that term added nothing and only created a window where a
        // late failure went unreported.
        //
        // Written only on the false→true transition — `waveformSamples` below is written
        // every tick, but `@Observable` tracks per keypath, so a view reading ONLY
        // `writeFailed` does not become a 2 Hz observer. Anything reading
        // `waveformSamples` from a floating/overlay view WOULD (freeze law).
        if writeFailure.pointee, !writeFailed {
            writeFailed = true
        }
        // #1413 — same tick, same reason: a gap has to reach the performer DURING the take.
        // Written only when it actually moves, so a view reading `droppedSeconds` does not
        // become a 2 Hz observer on a take that is fine (the freeze law).
        if captureSampleRate > 0 {
            let dropped = Double(droppedFrames.pointee) / captureSampleRate
            if dropped > droppedSeconds { droppedSeconds = dropped }
        }
        // #630 — DELIBERATELY neither clamped nor blanked, unlike every reader that produces
        // audio. This bins the whole ring into a fixed number of display bins for a level
        // meter: nothing here is written to a file or played, so an old-rate frame costs a
        // slightly compressed time axis in a picture, not a pitch-shifted export.
        //
        // ⛔ #630b: the reason first written here argued against TRUNCATING ("it would shrink
        // `totalFrames` and change what a bin means") — which nobody proposed, since the
        // honest alternative for a picture is BLANKING, and blanking would leave `totalFrames`
        // and every bin's meaning exactly as they are. So the real reason is smaller and is
        // stated as such: a level meter briefly binning pre-switch audio is not a defect
        // worth a branch on the 2 Hz path, and a visible gap in a level meter would read as
        // "the engine stopped" — the same wrong message this repo rejects elsewhere.
        let totalFrames = ringCapacity
        let endFrame   = Int(RetroRingCursor.load(ringWriteFrame))
        let startFrame = max(0, endFrame - totalFrames)
        let framesPerBin = totalFrames / waveformResolution
        guard framesPerBin > 0 else { return }

        var samples = [Float](repeating: 0, count: waveformResolution)
        for bin in 0..<waveformResolution {
            var sum: Float = 0
            for f in 0..<framesPerBin {
                let frame = startFrame + bin * framesPerBin + f
                let slot  = (frame % ringCapacity) * 2
                let l = ring[slot], r = ring[slot + 1]
                sum += l * l + r * r
            }
            samples[bin] = sqrt(sum / Float(framesPerBin * 2))
        }
        waveformSamples = samples
    }

    // MARK: - Recording control

    /// Begin a new recording: prepend the last `preRoll` seconds from the ring
    /// buffer (default: the full 30 s — "retro" capture), then enable the live tap
    /// write. Pass `preRoll: 0` for a live-only file that starts NOW — the loop
    /// exporter needs this (audit C6: the loop WAV silently began with 30 s of
    /// stale audio, and the LUFS normalisation measured that junk too).
    func startRecording(preRoll requestedPreRoll: Int? = nil) {
        guard !isRecording else { return }

        do {
            let url = try makeRecordingURL()
            guard let format = AVAudioFormat(standardFormatWithSampleRate: captureSampleRate, channels: 2) else {
                log.log(.error, category: .audio, "RetroCapture: cannot create recording format")
                return
            }
            let file = try AVAudioFile(forWriting: url,
                                       settings: format.settings,
                                       commonFormat: .pcmFormatFloat32,
                                       interleaved: false)

            // Write pre-roll BEFORE enabling live tap — file begins `preRoll`s in the past
            let preRoll = min(max(requestedPreRoll ?? preRollSeconds, 0), preRollSeconds)
            if preRoll > 0 {
                try writePreRollToFile(file, format: format, seconds: preRoll)
            }

            // Clear the latch BEFORE arming, so the first drained chunk starts from a
            // known-false state. ⛔ TWICE-CORRECTED COMMENT, and the second correction is
            // #1413's: the first version justified the order with a race that cannot happen,
            // the second said "the tap tests `activePtr.pointee` first" — and the tap does not
            // test anything any more, it fills the ring unconditionally. The ordering now
            // matters for a DIFFERENT and real reason: everything the writer reads
            // (`writeFormat`, `drainFrame`, `activeFile`) must be in place before `isActive`
            // goes true and the timer resumes, because after that point the writer may run at
            // any moment. ⭐ Lesson, for the third reader: a comment that explains an ORDERING
            // has to be re-derived whenever the consumer of that ordering changes — this one
            // survived a rewrite of its own consumer by naming a symbol that no longer exists.
            writeFailure.pointee = false
            writeFailed          = false
            droppedFrames.pointee = 0
            droppedSeconds        = 0

            // #1413 — the live drain starts HERE, at the cursor the pre-roll ended on. Reading
            // it AFTER `writePreRollToFile` is what makes the two writers meet exactly: every
            // frame before this point is already in the file, every frame after it is owed.
            drainFrame.pointee = RetroRingCursor.load(ringWriteFrame)
            writeFormat        = format

            activeFile.pointee = file
            isActive.pointee   = true
            isRecording        = true
            recordingSeconds   = 0
            lastURL            = url

            // 5 Hz. The ring holds 30 s, so the writer may fall a whole second behind without
            // losing a frame; a faster tick would only buy shorter file-flush latency at the
            // price of more, smaller writes. Deliberately NOT a `Timer`: a `Timer` runs on a
            // run loop, and this handler must run on `writeQueue` and nowhere else.
            let drain = DispatchSource.makeTimerSource(queue: writeQueue)
            drain.schedule(deadline: .now() + .milliseconds(200), repeating: .milliseconds(200))
            drain.setEventHandler { [weak self] in self?.drainToDisk() }
            drainTimer?.cancel()
            drainTimer = drain
            drain.resume()

            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.recordingSeconds += 1 }
            }

            // #630b: log what was WRITTEN, not what was asked for. After a rate switch
            // `writePreRollToFile` legitimately writes less (or nothing) — a line saying
            // "+30s pre-roll" over a two-second prepend is the same class of defect as a
            // transport line naming a tempo source it did not use.
            let prependedSeconds = captureSampleRate > 0
                ? Double(preRollWindow(requestedFrames: Int(Double(preRoll) * captureSampleRate)).count)
                    / captureSampleRate
                : 0
            log.log(.info, category: .audio,
                    "RetroCapture recording started (+\(String(format: "%.1f", prependedSeconds))s "
                    + "pre-roll of \(preRoll)s requested) → \(url.lastPathComponent)")

        } catch {
            log.log(.error, category: .audio, "RetroCapture: failed to start — \(error.localizedDescription)")
        }
    }

    /// #630 — the ONE place that decides which ring frames a pre-roll may read.
    ///
    /// ⛔ A LINE ABOVE THIS ONE CLAIMED THIS FUNCTION DEINTERLEAVES AND WRITES A FILE
    /// (#1443). It does neither — it returns two `Int`s. Swift folds adjacent `///`
    /// lines into ONE comment, so a sentence written for `writeRange` below had silently
    /// become the FIRST line of this member's doc, i.e. the line Quick Help shows.
    /// Deleted rather than moved: `writeRange`'s own header already says it better
    /// ("The ONE place frames reach disk", "one deinterleave, one chunk size"), and the
    /// chunk figure it carried is a literal that would go stale while the code holds it.
    /// ⚠️ THE DIRECTION IS WHAT MADE IT WORTH A COMMIT: this is the file #1413 cleared of
    /// disk I/O on the tap callback, so a doc claiming a windowing function writes a file
    /// points a future reader at exactly the wrong conclusion about where I/O happens.
    ///
    /// Returns the newest `requestedFrames` (capped at the ring), clamped so the window never
    /// reaches back across a sample-rate switch. Right after a switch it legitimately returns
    /// `count == 0`: there is no history at this rate yet, and every caller writes nothing
    /// rather than writing old frames under a new rate stamp. That is this file's own rule —
    /// a capture may be SHORT, it may not be WRONG.
    ///
    /// ⛔ #630b — ONE caller, not two, and the rule that decides which is which was wrong
    /// when it was written here. It said "truncating is right where the result becomes AUDIO,
    /// blanking where it becomes a PICTURE" — and `captureRecent` produces AUDIO, truncated
    /// under that rule, which cut users' videos to seconds. It also failed to describe the
    /// waveform tick, which is a picture and does NEITHER.
    ///
    /// ⭐ THE RULE IS ABOUT THE CALLER, NOT THE MEDIUM: truncate only where the caller has no
    /// LENGTH EXPECTATION. `writePreRollToFile` prepends to a take that then continues live,
    /// so a shorter prepend costs nothing and is the honest answer. Everything else here has
    /// a caller doing arithmetic on the length — `captureRecent`'s two consumers mux and trim
    /// by duration, `snapshotPreRoll`'s length is pinned by tests — so those BLANK instead.
    ///
    /// ⚠️ `RetroCaptureTests` is not the blocking bundle, which is why claim 3 of
    /// `APreRollNeverCrossesARateSwitchTests` deliberately restates two of its assertions.
    private func preRollWindow(requestedFrames: Int) -> (start: Int, count: Int) {
        let end = Int(RetroRingCursor.load(ringWriteFrame))
        let wanted = min(max(requestedFrames, 0), ringCapacity)
        let start = max(max(0, end - wanted), Int(rateBoundaryFrame))
        return (start, max(0, end - start))
    }

    /// Deinterleave an ABSOLUTE ring range into the file. The ONE place frames reach disk.
    ///
    /// #1413 — extracted from `writePreRollToFile` so the pre-roll and the live drain cannot
    /// drift apart: one deinterleave, one chunk size, one stereo guard. `nonisolated` because
    /// the live caller is `writeQueue`; it touches only the ring, `ringCapacity` and the file
    /// handed to it, never `@MainActor` state.
    nonisolated private func writeRange(_ file: AVAudioFile,
                                        format: AVAudioFormat,
                                        from startFrame: Int,
                                        count totalFrames: Int) throws {
        // This writer deinterleaves the STEREO ring buffer (L,R,L,R) into channels 0 AND 1.
        // `floatChannelData?[1]` is raw pointer indexing, NOT bounds-checked — a mono format
        // would make [1] a garbage pointer and corrupt memory. Guard the invariant explicitly
        // so a future caller passing a mono format fails loudly instead of scribbling memory.
        guard format.channelCount >= 2 else {
            throw NSError(domain: "RetroCapture", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "ring writer requires a stereo (2-channel) format"])
        }
        let chunkSize = 8192
        var written   = 0

        while written < totalFrames {
            let frames = min(chunkSize, totalFrames - written)
            guard let pcmBuf = AVAudioPCMBuffer(pcmFormat: format,
                                                frameCapacity: AVAudioFrameCount(frames)) else {
                written += frames; continue
            }
            pcmBuf.frameLength = AVAudioFrameCount(frames)

            guard let ch0 = pcmBuf.floatChannelData?[0],
                  let ch1 = pcmBuf.floatChannelData?[1] else {
                written += frames; continue
            }

            // Deinterleave from ring buffer (L, R, L, R, …)
            for f in 0..<frames {
                let src = ((startFrame + written + f) % ringCapacity) * 2
                ch0[f] = ring[src]
                ch1[f] = ring[src + 1]
            }

            try file.write(from: pcmBuf)
            written += frames
        }
    }

    /// Write every finished frame the file is still owed. Runs ONLY on `writeQueue`.
    ///
    /// The cursor pair IS the design: the tap advances `ringWriteFrame`, this advances
    /// `drainFrame`, and the gap between them is audio in flight. Both are monotonic absolute
    /// frame counts, so there is no wrap arithmetic here — `writeRange` does the modulo.
    nonisolated private func drainToDisk() {
        guard isActive.pointee, !writeFailure.pointee,
              let file = activeFile.pointee, let format = writeFormat else { return }

        let end   = Int(RetroRingCursor.load(ringWriteFrame))
        var start = Int(drainFrame.pointee)
        guard end > start else { return }

        // OVERRUN. More than a ring's worth outstanding means the tap has already overwritten
        // the oldest owed frames; they are gone and cannot be recovered by writing faster.
        // Count them, skip to the oldest frame that still EXISTS, and keep the take going — a
        // gap in a recording is bad, ending the take under the performer is worse.
        if end - start > ringCapacity {
            droppedFrames.pointee &+= Int64(end - start - ringCapacity)
            start = end - ringCapacity
        }

        do {
            try writeRange(file, format: format, from: start, count: end - start)
            drainFrame.pointee = Int64(end)
        } catch {
            // Raise the latch BEFORE logging, and log ONCE: the flag stops the next tick from
            // repeating a `localizedDescription` bundle lookup for the rest of a lost take.
            // Cheaper here than it ever was in the tap — but error handling whose cost grows
            // with the error's duration is a load source wherever it runs.
            writeFailure.pointee = true
            log.log(.error, category: .audio,
                    "RetroCapture write failed — recording stops writing: \(error.localizedDescription)")
        }
    }

    /// Must be called BEFORE activating the live tap to preserve correct chronological order.
    private func writePreRollToFile(_ file: AVAudioFile, format: AVAudioFormat, seconds: Int) throws {
        // #630: the window is clamped to frames captured at the CURRENT rate.
        let window = preRollWindow(requestedFrames: Int(Double(seconds) * captureSampleRate))
        try writeRange(file, format: format, from: window.start, count: window.count)
    }


    /// Stop recording. Calls completion on main thread with the file URL.
    func stopRecording(completion: ((URL) -> Void)? = nil) {
        guard isRecording else { return }

        isActive.pointee  = false
        timer?.invalidate()
        timer = nil
        drainTimer?.cancel()
        drainTimer = nil

        // Lift the latch HERE too, not only from the 2 Hz tick. Without this, a write
        // that failed in the last half-second of a take is never surfaced at all: stop
        // clears `isRecording`, the next tick finds nothing to report, and the caller
        // exports a truncated file as if it were good. Short takes are exactly the ones
        // a full volume produces, so this is the common case, not the corner.
        if writeFailure.pointee { writeFailed = true }

        // #1413 — FINAL DRAIN, synchronous and on the writer's own queue. `isActive` is already
        // false above, so `drainToDisk`'s own guard would refuse; this last stretch is written
        // directly. `writeQueue.sync` doubles as the barrier that guarantees no drain handler is
        // still mid-write when the file is released one line later.
        let tail = (start: Int(drainFrame.pointee), end: Int(RetroRingCursor.load(ringWriteFrame)))
        writeQueue.sync {
            guard !writeFailure.pointee, let file = activeFile.pointee, let format = writeFormat,
                  tail.end > tail.start else { return }
            let start = max(tail.start, tail.end - ringCapacity)
            if start > tail.start { droppedFrames.pointee &+= Int64(start - tail.start) }
            do { try writeRange(file, format: format, from: start, count: tail.end - start) }
            catch {
                writeFailure.pointee = true
                log.log(.error, category: .audio,
                        "RetroCapture final write failed: \(error.localizedDescription)")
            }
        }
        if writeFailure.pointee { writeFailed = true }
        if droppedFrames.pointee > 0, captureSampleRate > 0 {
            droppedSeconds = Double(droppedFrames.pointee) / captureSampleRate
            log.log(.error, category: .audio,
                    "RetroCapture dropped \(String(format: "%.2f", droppedSeconds))s — the disk "
                    + "writer fell behind the 30 s ring")
        }

        // Close file off the audio callback path
        let closedFile = activeFile.pointee
        activeFile.pointee = nil
        writeFormat = nil
        isRecording = false

        if let url = lastURL {
            let dur = recordingSeconds
            log.log(.info, category: .audio, "RetroCapture stopped — \(dur)s saved to \(url.lastPathComponent)")
            completion?(url)
        }
        _ = closedFile  // ARC releases AVAudioFile here, flushing buffers
    }

    // MARK: - Pre-roll snapshot (for external preview / waveform display)

    /// Returns the last `seconds` of ring buffer audio as interleaved stereo floats.
    /// Use for waveform preview. Recording already prepends pre-roll via writePreRollToFile().
    func snapshotPreRoll(seconds: Int = 30) -> [Float] {
        // #630 — THIS KEEPS ITS LENGTH and blanks instead of truncating. Its contract is
        // "give me `seconds` worth", zero-padded at the front before any audio has been
        // captured; `RetroCaptureTests` pins exactly that (30 s of silence from a fresh
        // instance). The frames that predate a rate switch come back as SILENCE: a gap you
        // can see, rather than old-rate audio replayed at the new rate.
        //
        // ⛔ #630b: the reason recorded here was "it would break every caller that sizes a
        // preview from the returned array" — and there is NO such caller.
        // `git grep -n snapshotPreRoll -- Sources | grep -v RetroCapture.swift` returns
        // nothing; the only things holding this length are three tests and one guard claim.
        // The DECISION stands (those tests are right, and #630b proved on `captureRecent`
        // what truncating a length contract costs); the unmeasured consumer claim does not.
        // In a repo whose whole discipline is "measure the consumers before asserting them",
        // asserting one in the same breath as a length contract is the error worth naming.
        let frames  = min(Int(Double(seconds) * captureSampleRate), ringCapacity)
        let endFrame = Int(RetroRingCursor.load(ringWriteFrame))
        let startFrame = max(0, endFrame - frames)
        let boundary = Int(rateBoundaryFrame)
        var out = [Float](repeating: 0, count: frames * 2)

        for f in 0..<frames {
            // #630: frames older than the boundary were sampled at a different rate; leave
            // them as the zeros `out` was initialised with.
            guard startFrame + f >= boundary else { continue }
            let src = ((startFrame + f) % ringCapacity) * 2
            let dst = f * 2
            out[dst]     = ring[src]
            out[dst + 1] = ring[src + 1]
        }
        return out
    }

    // MARK: - Retroactive snapshot to file ("keep what just played")

    /// Write the most recent `seconds` of the always-on ring buffer to a temp CAF —
    /// WITHOUT touching the live transport or starting a recording. This is the
    /// retroactive "die Stelle war gut → behalten" path: grab exactly what was just
    /// heard (already including reverb/delay tails). Returns the file URL, or nil.
    func captureRecent(seconds: Double) -> URL? {
        // ⛔ #630b — THIS KEEPS ITS LENGTH AND BLANKS. #630 truncated it here, and that was a
        // defect far worse than the one it fixed. It had TWO consumers then; the video one is
        // gone with #1304 and is kept named because it is the sharper illustration:
        //   · `VisualRecorder.stopAndSave` muxed this audio with the take's video, and the
        //     muxer end-aligned to `min(videoDuration, audioDuration)` — so a 3-second audio
        //     file CUT A 60-SECOND VIDEO TO THREE SECONDS, after which the full-length
        //     original was deleted. A route switch three seconds before Stop destroyed 57
        //     seconds of footage with no recovery path.
        //   · THE LIVE ONE: `LoopExporter.exportRecentLoop` passes the file to `SingleExport`, whose
        //     `resolveTrimRange` returns nil for a too-short file — and nil there means
        //     "export the whole file untrimmed", reported as SUCCESS. A 2-second WAV would be
        //     handed over as a 4-bar loop, silently.
        // Both routed AROUND honest-failure branches those callers already have.
        //
        // ⛔ AND THE BLAST RADIUS WAS NOT EVEN THE RATE SWITCH. With `boundary == 0` the
        // truncation still fired whenever the ring had not yet filled the requested window —
        // i.e. for the first ~30 seconds after EVERY engine start, with no route change
        // anywhere near it. The parent always wrote a constant-duration file, front-padded
        // with the ring's zeros; #630 changed that contract for every caller and said so
        // nowhere. The commit argued "a capture may be SHORT, it may not be WRONG" — for
        // these two consumers, short IS wrong.
        //
        // ⭐ THE RULE, corrected: truncate ONLY where the caller has no length expectation.
        // `writePreRollToFile` prepends to a take that continues live, so a shorter prepend
        // costs nothing. This method's two callers both do duration arithmetic on the result.
        // Returning nil when short was the other candidate and is REJECTED for the same
        // reason: it would also change the ring-not-yet-full case, which is not this bug.
        // ⛔ #1374 — THE CLAMP ON THE NEXT LINE CANNOT PROTECT ITS OWN CONVERSION, and that
        // is the whole finding. `Int(someDouble)` TRAPS on NaN, on ±infinity and out of
        // Int's range — it does not throw and it does not saturate, the process dies. Both
        // `min` and `max` run AFTER that conversion, so they guard the result of a step that
        // already crashed. Reordering them would not help either: this repo's own law says
        // `min(max(v, lo), hi)` passes NaN straight through (`min(NaN, 30)` returns NaN,
        // because `30 < NaN` is false), which is exactly why `clamped(to:)` exists.
        //
        // ⚠️ IT IS LATENT, NOT A DEMONSTRATED CRASH, and saying otherwise would be the
        // flattering direction. The live caller is `LoopExporter.exportRecentLoop`, whose
        // window is `min(seconds + ago, retroRingSeconds)` — NaN-permeable by the line above,
        // and so is the length guard above IT, since every comparison with NaN is false. But
        // no producer is proven to make one: a zero tempo yields ±infinity, which `min`
        // DOES catch correctly, and NaN needs a 0/0. So this guard buys the day a producer
        // starts making one, not a bug anybody has seen.
        //
        // ⭐ WHY THE GUARD SITS HERE AND NOT IN THE CALLER. A fix that is true for ONE caller
        // is not true for the TYPE. `seconds` is this method's public `Double` parameter;
        // every present and future caller reaches the same conversion, and only this side can
        // promise it is safe. The two Int-typed relatives — `snapshotPreRoll(seconds: Int)`
        // and `writePreRollToFile(seconds: Int)` — cannot receive a NaN at all and are
        // deliberately left alone; widening this to them would be a guard for a state their
        // signatures already make unreachable.
        //
        // ⚠️ REFUSED, NOT CLAMPED, and the alternative was considered. Clamping a NaN to 0 or
        // to the ring length would hand the caller a file of the WRONG DURATION while
        // reporting success — the precise defect #630b above spent a cycle undoing ("short IS
        // wrong" for both consumers, which do duration arithmetic on the result). `nil` routes
        // into the honest-failure branch each caller already has.
        guard seconds.isFinite else {
            log.log(.error, category: .audio,
                    "RetroCapture.captureRecent: non-finite seconds (\(seconds)) — refused")
            return nil
        }
        let frames = min(max(Int(seconds * captureSampleRate), 0), ringCapacity)
        guard frames > 0 else { return nil }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: captureSampleRate, channels: 2) else {
            log.log(.error, category: .audio, "RetroCapture.captureRecent: cannot create format")
            return nil
        }
        do {
            let url = try makeRecordingURL()
            let file = try AVAudioFile(forWriting: url, settings: format.settings,
                                       commonFormat: .pcmFormatFloat32, interleaved: false)
            let endFrame = Int(RetroRingCursor.load(ringWriteFrame))
            let startFrame = max(0, endFrame - frames)
            let boundary = Int(rateBoundaryFrame)
            let chunkSize = 8192
            var written = 0
            while written < frames {
                let n = min(chunkSize, frames - written)
                guard let buf = AVAudioPCMBuffer(pcmFormat: format,
                                                 frameCapacity: AVAudioFrameCount(n)) else { written += n; continue }
                buf.frameLength = AVAudioFrameCount(n)
                guard let ch0 = buf.floatChannelData?[0], let ch1 = buf.floatChannelData?[1] else {
                    written += n; continue
                }
                for f in 0..<n {
                    // #630b: frames older than the rate boundary are written as EXPLICIT
                    // zeros — `AVAudioPCMBuffer` does not promise a cleared buffer, so
                    // "skip and leave it" would emit whatever was in that allocation. A
                    // silent gap is audible and harmless; the same frames replayed under a
                    // new rate are the pitch-shift this whole slice exists to remove.
                    guard startFrame + written + f >= boundary else {
                        ch0[f] = 0; ch1[f] = 0
                        continue
                    }
                    let src = ((startFrame + written + f) % ringCapacity) * 2
                    ch0[f] = ring[src]
                    ch1[f] = ring[src + 1]
                }
                try file.write(from: buf)
                written += n
            }
            log.log(.info, category: .audio, "RetroCapture.captureRecent — \(frames) frames → \(url.lastPathComponent)")
            return url
        } catch {
            log.log(.error, category: .audio, "RetroCapture.captureRecent failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private func makeRecordingURL() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ts = Int(Date().timeIntervalSince1970)
        return dir.appendingPathComponent("echoel_\(ts).caf")
    }
}
#endif
