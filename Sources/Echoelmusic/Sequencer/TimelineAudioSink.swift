// TimelineAudioSink.swift
// Echoelmusic — Sequencer
//
// A1 of the healing block (founder 2026-07-15 ultracode; audit wf_9c6f33b7
// verified CRITICAL: "Audio regions on the arrange timeline are SILENT during
// song playback — AudioLanePlayer is dead code, never instantiated"). This is
// the missing DEVICE half of `AudioRegionSink`: player nodes for one audio
// lane, attached additively into the master mix (never the output path), driven
// by the tested `AudioLanePlayer` coordinator from the timeline transport.
//
// Streaming by design: `scheduleSegment(_:startingFrame:frameCount:at:)` plays
// straight from the file — no whole-region PCM buffer on the main actor (a
// 3-minute region would be ~70 MB against the 200 MB cap; AudioClipPlayer's
// bake-into-buffer path is right for short auditions/fades, wrong here).
// ⚠️ #1381 — THE THREE `AudioClipPlayer` POINTERS IN THIS FILE (here, at the warp
// chain, and at the Beats cap) POINT AT A DEAD FILE: zero callers, zero tests. They
// are kept because each cites a real design fact whose provenance is written there —
// but nothing in that file runs, so do not read one as "the other executor does X
// today", and do not verify a number by observing it. Stated ONCE, here (#416); the
// other two carry a bare `(dead)`.
// Control-plane only: scheduling happens on @MainActor; AVAudioPlayerNode does
// its own rendering and file I/O off our threads.
//
// PERF-01 (multi-format lanes): AVAudioPlayerNode sample-rate-converts scheduled
// files but does NOT convert channel counts, and re-attaching a node PAUSES the
// whole engine (full-mix dropout). Pre-PERF-01 this sink held ONE node and
// re-attached whenever a region's file format differed from the connection —
// audible at EVERY boundary between (say) a 48 kHz mono mic take and a 44.1 kHz
// stereo loop, re-firing on every loop wrap. Now the sink keeps ONE NODE PER
// DISTINCT processingFormat, attached at PRIME time (transport parked — the
// pause is inaudible); a mid-song region switch just schedules on the format's
// own, already-attached node. A single-format lane behaves exactly as before
// (one node, same paths). Only a file format NEVER seen at prime (a region
// added live mid-song) still attaches mid-song — same cost as the old first
// attach, bounded, and the next prime absorbs it.
//
// Live mixer (H4): `setGain`/`setPan` land mid-region on the node's AVAudioMixing
// volume/pan — control-plane, no re-scheduling (the coordinator decides when a
// mute/unmute needs a real stop/restart instead).
// Stretch (Slice B): a region placed warped renders through a per-format warp
// chain (player → AVAudioUnitTimePitch → master) — Clean holds pitch, Tape lets
// it ride the tempo — while UNWARPED regions keep the plain, uncolored node
// (the spectral unit is not bit-transparent even at rate 1.0). Warp chains
// attach at prime time via `preload(url:warped:)`.
// Pitch (#165): a TRANSPOSED lane also plays through that chain, the transpose added to
// the node's `pitch` (`AudioTranspose`); the Beats buffer is bypassed while transposed,
// because it plays on the plain node. The chain's own delay is not compensated.
// Fades (audio editor W4b — closes audit A5 for the timeline): a part's fade-in/out arrive as a
// `PartFadePlan` through `setFades` right before `play`. The frames inside a fade are read from a
// fresh handle, multiplied by the ramp and scheduled as short buffers; the frames between play
// straight from the file, all back to back on one node (`playFaded`). A Beats part bakes the
// ramps into its pre-render instead (off the main actor; its cache key carries the fades). Honest
// limit: the plain path's read happens on the main actor — the first faded piece is kept short so
// the part starts on time, and the rest is read while it sounds.
// Grain (GMMW GA-10c): a part on a track with an enabled grain insert is rendered ONCE at prime
// time, off the main actor (`GrainBake` over the part's window, its fades baked in), and its onset
// schedules that READY buffer on the plain node — the Beats pattern. Not ready yet, entered
// mid-part (a seek, an unmute), stretched or pitched: the part plays exactly as before.
// GA-10d: each dry channel keeps its side (a stereo part keeps its image); the cloud reads the
// channels' mean. An edit while the piece plays requests a rendering at once (`prepareGrains` on
// the mixer refresh); the rest wait in a short per-lane queue, newest request per part winning.
// Honest limits: a mono file hears the cloud's L+R sum; a part longer than `grainMaxPartFrames`
// plays dry; one render runs per lane at a time; and a part already sounding when its rendering
// lands stays dry until its next onset (mix 0 never gets here — `grainToPlay` answers nil).
// Headphone space (Restructure S3c): while `AudioEngine.headphoneSpaceEnabled` is on, every
// node of this lane plays into ONE mono space bus that Apple's HRTF environment node places
// at the lane's point (`setSpacePosition`, from the piece's scene). The mode is read at PRIME
// time only — `preload` rebuilds the lane's nodes when it changed, because moving a node
// pauses the engine. The lane's pan has no effect inside the space: its position replaces it.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

@MainActor
final class TimelineAudioSink: AudioRegionSink {

    /// A distinct connection format (channel layout + rate) → its own node.
    private struct FormatKey: Hashable {
        let channels: AVAudioChannelCount
        let rate: Double
    }

    /// One attached player node per distinct format this lane's media needs.
    private var nodes: [FormatKey: AVAudioPlayerNode] = [:]
    /// Slice B: one warp chain (player → AVAudioUnitTimePitch → master) per format
    /// that this lane plays WARPED. Kept SEPARATE from the plain nodes on purpose:
    /// the spectral node is not bit-transparent even at rate 1.0 (overlap-add
    /// latency, faint coloration — see AudioClipPlayer, dead), so unwarped timeline
    /// audio must keep its plain, uncolored path. Attached at PRIME time via
    /// `preload(url:warped:)`; a warped region whose format was never primed
    /// still attaches mid-song — same bounded cost as the plain unseen-format
    /// path, absorbed by the next prime.
    private var warpChains: [FormatKey: (player: AVAudioPlayerNode,
                                         timePitch: AVAudioUnitTimePitch)] = [:]
    /// URLs whose file was already opened once → their format key, so a loop-wrap
    /// prime (which re-preloads every lane URL) is a pure no-op instead of
    /// re-opening files each round.
    private var knownURLs: [URL: FormatKey] = [:]
    private weak var engine: AudioEngine?
    /// The most recently loaded file (play() schedules from it). Single-slot —
    /// the transport plays one region per lane at a time.
    private var file: AVAudioFile?
    /// Last applied mixer values — a node attached AFTER a live edit (unseen
    /// format mid-song) must join at the lane's current level, not a stale one.
    private var gain: Float = 1
    private var pan: Float = 0
    /// #165: this lane's pitch in whole semitones, set by `AudioLanePlayer.start` before `play`.
    private var transposeSemitones = 0
    /// S3c: the mode the attached nodes were built for, the lane's space bus (only while that
    /// mode is on), and the last point the coordinator handed over — kept so a bus attached
    /// LATER (first preload, a rebuild) starts at the lane's place, not at the listener.
    private var wiredInSpace = false
    private var spaceBus: AVAudioMixerNode?
    private var spacePoint: HeadphoneSpace.Point?
    /// S3c review: set by the coordinator before each prime's preloads — true only for the prime
    /// that starts playback. True until first told, so a sink driven without a coordinator
    /// behaves as before.
    private var mayRewire = true

    func setMayRewire(_ allowed: Bool) { mayRewire = allowed }

    func setSpacePosition(_ point: HeadphoneSpace.Point) {
        spacePoint = point
        if let spaceBus { place(spaceBus, at: point) }
    }

    private func place(_ bus: AVAudioMixerNode, at point: HeadphoneSpace.Point) {
        bus.position = AVAudio3DPoint(x: point.x, y: point.y, z: point.z)
    }

    func setTranspose(_ semitones: Int) {
        transposeSemitones = AudioTranspose.clamped(semitones)
    }

    /// Audio editor W4b: the fades of the part the next `play` starts. `play` takes it and
    /// clears it, so a plan belongs to exactly one part and can never reach a later `play`.
    private var pendingFades: PartFadePlan?
    /// The most a FADED first piece may be before `play()`: its read delays the part's start,
    /// so a longer fade is split and the rest is read while this much already sounds.
    private static let firstFadedChunkSeconds = 0.25

    func setFades(_ plan: PartFadePlan?) {
        pendingFades = plan
    }

    // MARK: Grain (GMMW GA-10c — prime-time offline bake per part)

    /// GA-10c: the grain the next `play` sounds; taken and cleared by that `play`, like the fades.
    private var pendingGrain: GrainSettings?

    func setGrain(_ settings: GrainSettings?) {
        pendingGrain = settings
    }

    /// One rendering: the part's window (start + length, 1/1000 s), the settings as their stored
    /// bytes (sorted-key JSON, so equal settings are one key) and the fades baked into it.
    private struct GrainKey: Hashable {
        let url: URL
        let fromMilli: Int
        let lengthMilli: Int
        let settings: Data
        let fadeInMilli: Int
        let fadeOutMilli: Int
        init(url: URL, fromSeconds: Double, lengthSeconds: Double, settings: GrainSettings,
             fades: PartFadePlan?) {
            self.url = url
            self.fromMilli = Int((fromSeconds * 1000).rounded())
            self.lengthMilli = Int((lengthSeconds * 1000).rounded())
            self.settings = DeviceInsert.grainBlob(settings.sanitized)
            self.fadeInMilli = Int(((fades?.fadeIn ?? 0) * 1000).rounded())
            self.fadeOutMilli = Int(((fades?.fadeOut ?? 0) * 1000).rounded())
        }
    }
    private var grainBuffers: [GrainKey: AVAudioPCMBuffer] = [:]
    private var grainInFlight: Set<GrainKey> = []
    /// Renderings that cannot be made (unreadable, past the file's end, too long, a layout the
    /// node cannot take): not retried at every loop wrap. Cleared with the lane.
    private var grainFailed: Set<GrainKey> = []
    /// GA-10d: what was asked for while a rendering was in flight, ONE entry per part window — a
    /// later request for the same window replaces the earlier (a knob drag keeps only its last
    /// value), and a lane with several parts keeps each. Started one at a time as each rendering
    /// lands. Capped (a window past the cap waits for the next prime); cleared with the lane.
    private struct GrainWindow: Hashable {
        let url: URL
        let fromMilli: Int
        let lengthMilli: Int
    }
    private struct GrainRequest {
        let url: URL
        let fromSeconds: Double
        let lengthSeconds: Double
        let settings: GrainSettings
        let fades: PartFadePlan?
    }
    private var grainQueued: [GrainWindow: GrainRequest] = [:]
    private static let grainQueueCap = 16
    /// The longest part rendered, in frames — the Beats cap, asked rather than restated (~31 s at
    /// 48 kHz). A render's working set peaks near five arrays of this length off the main actor
    /// (≈ 30 MB); a longer part plays dry.
    nonisolated static let grainMaxPartFrames = beatsMaxOutputFrames
    /// The most frames of renderings one lane keeps: two parts at the cap (≈ 24 MB stereo). A new
    /// rendering evicts others until it fits; an evicted part plays dry until a prime renders it.
    private static let grainFrameBudget = 2 * grainMaxPartFrames

    func prepareGrain(url: URL, fromSeconds: Double, lengthSeconds: Double,
                      settings: GrainSettings, fades: PartFadePlan?) {
        guard fromSeconds.isFinite, lengthSeconds.isFinite, lengthSeconds > 0 else { return }
        let key = GrainKey(url: url, fromSeconds: fromSeconds, lengthSeconds: lengthSeconds,
                           settings: settings, fades: fades)
        let window = GrainWindow(url: url, fromMilli: key.fromMilli, lengthMilli: key.lengthMilli)
        // GA-10d review: the NEWEST request for a window wins, also when it is one already rendered,
        // failed or in flight — an older value left waiting would render after it and evict it.
        if grainBuffers[key] != nil || grainFailed.contains(key) || grainInFlight.contains(key) {
            grainQueued[window] = nil
            return
        }
        // ONE render per lane at a time: each holds several part-length arrays, and prime asks for
        // every part at once. The rest wait in `grainQueued` and start as each one lands; past the
        // cap a new window is not kept, and the next prime asks for it again.
        guard grainInFlight.isEmpty else {
            guard grainQueued[window] != nil || grainQueued.count < Self.grainQueueCap else { return }
            grainQueued[window] = GrainRequest(url: url, fromSeconds: fromSeconds, lengthSeconds: lengthSeconds,
                                               settings: settings, fades: fades)
            return
        }
        // GA-10d review: NEVER open a file here. Prime's `preload` has warmed every file of the lane
        // before it asks; this is also the EDIT path (`prepareGrains`) and the queue, mid-song, where
        // `ensureLoaded` could attach a node (the engine pause) or, on an unreadable file, `stop()`
        // the part that is playing. A file prime could not open simply gets no rendering (not marked
        // failed: a later prime may open it).
        guard knownURLs[url] != nil, let format = urlFormats[url] else { return }
        guard format.channelCount == 1 || format.channelCount == 2 else {
            grainFailed.insert(key)   // a layout the rendering cannot be built in
            return
        }
        grainInFlight.insert(key)
        Task.detached(priority: .userInitiated) { [weak self] in
            // Read + render in a helper, so the file's PCM and the mono sum are freed before the
            // fades are baked — and `channels` is the only owner, so the bake copies nothing.
            var channels: [[Float]] = []
            var sampleRate = 0.0
            if let rendered = Self.renderGrain(url: url, fromSeconds: fromSeconds,
                                               lengthSeconds: lengthSeconds, settings: settings) {
                channels = rendered.channels
                sampleRate = rendered.sampleRate
            }
            if sampleRate > 0 {
                fades?.bake(into: &channels, fromSeconds: fromSeconds, mediaSecondsPerFrame: 1 / sampleRate)
            }
            await self?.storeGrain(key: key, channels: channels)
        }
    }

    /// Off the main actor: the part's window of `url`, read on a FRESH handle (the Beats V3
    /// rule), and rendered by `GrainBake` with each dry channel on its own side (GA-10d: a stereo
    /// file keeps its image; a mono file plays its one channel on both) — or nil (unreadable, past
    /// the end, longer than `grainMaxPartFrames`).
    private nonisolated static func renderGrain(url: URL, fromSeconds: Double, lengthSeconds: Double,
                                                settings: GrainSettings) -> (channels: [[Float]], sampleRate: Double)? {
        // The file's PCM lives only inside `readGrainWindow`, so it is freed before the bake.
        guard let window = readGrainWindow(url: url, fromSeconds: fromSeconds, lengthSeconds: lengthSeconds),
              let baked = GrainBake.render(left: window.left, right: window.right, sampleRate: window.sampleRate,
                                           frameCount: window.partFrames, settings: settings) else { return nil }
        return ([baked.left, baked.right], window.sampleRate)
    }

    /// The part's window as one array per side (a mono file's one channel as both — the same
    /// array, nothing copied), with the part's length in frames.
    private nonisolated static func readGrainWindow(url: URL, fromSeconds: Double, lengthSeconds: Double)
        -> (left: [Float], right: [Float], sampleRate: Double, partFrames: Int)? {
        guard let f = try? AVAudioFile(forReading: url) else { return nil }
        let sr = f.processingFormat.sampleRate
        guard sr > 0 else { return nil }
        let startFrame = AVAudioFramePosition((max(0, fromSeconds) * sr).rounded())
        let partFrames = Int((lengthSeconds * sr).rounded())
        guard startFrame < f.length, partFrames > 0, partFrames <= grainMaxPartFrames else { return nil }
        let frames = AVAudioFrameCount(min(Double(f.length - startFrame), Double(partFrames)))
        guard frames > 0,
              let raw = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: frames) else { return nil }
        f.framePosition = startFrame
        guard (try? f.read(into: raw, frameCount: frames)) != nil,
              let data = raw.floatChannelData, raw.format.channelCount > 0 else { return nil }
        let n = Int(raw.frameLength)
        let left = Array(UnsafeBufferPointer(start: data[0], count: n))
        let right = raw.format.channelCount > 1 ? Array(UnsafeBufferPointer(start: data[1], count: n)) : left
        return (left, right, sr, partFrames)
    }

    /// The rendering as a buffer in the URL's NODE-CONNECTION format: stereo as it is, a mono
    /// connection as the L+R mean. Any other layout, or an empty rendering (read / cap / rate
    /// failed off-main): nothing is stored and the part plays dry.
    private func storeGrain(key: GrainKey, channels: [[Float]]) {
        grainInFlight.remove(key)
        // Whatever this rendering's outcome, the next request that waited for it starts.
        defer { startNextQueuedGrain() }
        guard knownURLs[key.url] != nil, let fmt = urlFormats[key.url],
              channels.count == 2, let left = channels.first, !left.isEmpty,
              channels[1].count == left.count,
              fmt.channelCount == 1 || fmt.channelCount == 2,
              let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(left.count)),
              let dst = out.floatChannelData else {
            // A detached lane (no known file) is not a failure; anything else is, until detach.
            if knownURLs[key.url] != nil {
                grainFailed.insert(key)
                log.log(.info, category: .audio, "Grain rendering unavailable (read/cap/format) — part plays dry")
            }
            return
        }
        let right = channels[1]
        if fmt.channelCount == 1 {
            for i in 0..<left.count { dst[0][i] = (left[i] + right[i]) * 0.5 }
        } else {
            left.withUnsafeBufferPointer { src in
                if let s = src.baseAddress { dst[0].update(from: s, count: left.count) }
            }
            right.withUnsafeBufferPointer { src in
                if let s = src.baseAddress { dst[1].update(from: s, count: right.count) }
            }
        }
        out.frameLength = AVAudioFrameCount(left.count)
        // `out` is still local: no node can be reading it (the Beats fill-time rule).
        AudioOutputGuard.sweepNonFinite(out)
        // The same part with other settings or fades is stale; then keep the lane in budget.
        for k in grainBuffers.keys where k.url == key.url && k.fromMilli == key.fromMilli
            && k.lengthMilli == key.lengthMilli && k != key {
            grainBuffers[k] = nil
        }
        var held = grainBuffers.values.reduce(0) { $0 + Int($1.frameLength) }
        for k in grainBuffers.keys where held + left.count > Self.grainFrameBudget {
            held -= Int(grainBuffers[k]?.frameLength ?? 0)
            grainBuffers[k] = nil
        }
        grainBuffers[key] = out
    }

    /// GA-10d: start the waiting requests until one is really rendering — a request that is
    /// already ready, failed or unloadable returns at once, and the next is tried.
    private func startNextQueuedGrain() {
        while grainInFlight.isEmpty, let (window, request) = grainQueued.first {
            grainQueued[window] = nil
            prepareGrain(url: request.url, fromSeconds: request.fromSeconds,
                         lengthSeconds: request.lengthSeconds, settings: request.settings, fades: request.fades)
        }
    }

    // MARK: Beats-Executor (prime-time offline WSOLA per region)

    private struct BeatsKey: Hashable {
        let url: URL
        /// Rate + window start quantized to 1/1000 so prime and play resolve the
        /// same entry (audio-review V3b: fromSeconds IS part of the key, so two
        /// same-file/same-rate regions with different trims each keep their own
        /// window instead of ping-ponging one entry every loop wrap).
        let rateMilli: Int
        let fromMilli: Int
        /// Audio editor W4b: the fades baked into the rendering (media seconds, 1/1000; 0 =
        /// none). A fade edit is a different rendering, so it resolves a different entry.
        let fadeInMilli: Int
        let fadeOutMilli: Int
        init(url: URL, rate: Double, fromSeconds: Double, fades: PartFadePlan?) {
            self.url = url
            self.rateMilli = Int((rate * 1000).rounded())
            self.fromMilli = Int((fromSeconds * 1000).rounded())
            self.fadeInMilli = Int(((fades?.fadeIn ?? 0) * 1000).rounded())
            self.fadeOutMilli = Int(((fades?.fadeOut ?? 0) * 1000).rounded())
        }
    }
    /// Rendered windows: the OUTPUT buffer (already stretched, plays at rate 1 on
    /// the plain node) plus the prepared media length (audio-review V6: play()
    /// requires the length to match too — a region trimmed after prime falls back
    /// to Clean instead of overplaying the cached tail).
    private var beatsBuffers: [BeatsKey: (lengthSeconds: Double, buffer: AVAudioPCMBuffer)] = [:]
    /// The node-connection format per URL, captured in `ensureLoaded` (audio-review
    /// V1/V2: the rebuild must use the SOURCE file's processingFormat — never the
    /// shared single-slot `file`, which may point at another URL by the time the
    /// detached render lands, and never `standardFormatWithSampleRate`, which can
    /// drop a channel layout the node connection carries → scheduleBuffer NSException).
    private var urlFormats: [URL: AVAudioFormat] = [:]
    /// Matches AudioClipPlayer's preview cap (dead file; ~31 s @48 k output, ~60 MB stereo
    /// transient): a longer Beats region is not pre-rendered and plays Clean.
    /// `nonisolated`: read inside the detached render task — Xcode's toolchain
    /// isolates a plain `static let` on a @MainActor class (SwiftPM CI did not;
    /// the toolchains disagree on SE-0434 inference, so state it explicitly).
    private nonisolated static let beatsMaxOutputFrames = 1_500_000

    init(engine: AudioEngine?) {
        self.engine = engine
    }

    /// Open `url` (if not seen before) and attach a node for ITS format. The
    /// attach pattern pauses the whole engine, so this belongs at PRIME time
    /// (before playback), never lazily at a mid-song onset (review HIGH 2).
    /// PERF-01: the coordinator now preloads EVERY distinct URL a lane will
    /// play, so every needed format has its node before the song runs.
    func preload(url: URL, warped: Bool) {
        // S3c: only the prime that STARTS playback may change mode (`mayRewire`, set by the
        // coordinator). A wrap, a structure edit or a relocate primes while the song plays —
        // a rewire there would pause the whole engine and stop a launched loop (review MED-1/2).
        if mayRewire, let engine, engine.headphoneSpaceEnabled != wiredInSpace {
            releaseNodes()
            wiredInSpace = engine.headphoneSpaceEnabled
        }
        if let key = knownURLs[url], nodes[key] != nil,
           !warped || warpChains[key] != nil { return }   // wrap re-prime: no-op
        guard ensureLoaded(url) != nil else { return }
        // Slice B: this URL plays warped somewhere on the lane — attach its warp
        // chain now, while the transport is parked (the attach pause is inaudible).
        if warped, let key = knownURLs[url] {
            _ = ensureWarpChain(for: key)
        }
    }

    /// Beats-Executor: offline-render the media window through the coherent
    /// multichannel WSOLA at prime time (transport parked; the render itself is
    /// detached so prime never blocks on DSP). play() schedules the READY buffer
    /// at rate 1 on the plain node; not-ready / mismatched windows fall back to
    /// the Clean chain — honest, never silent. Idempotent per (url, rate, window).
    /// Renders in flight (audio-review V3: a loop-wrap re-prime before the render
    /// lands must not re-read + re-render the same window).
    private var beatsInFlight: Set<BeatsKey> = []

    func prepareBeats(url: URL, fromSeconds: Double, lengthSeconds: Double, rate: Double,
                      fades: PartFadePlan?) {
        guard rate.isFinite, rate > 0, rate != 1.0, lengthSeconds > 0 else { return }
        let key = BeatsKey(url: url, rate: rate, fromSeconds: fromSeconds, fades: fades)
        // Idempotent per WINDOW: same start AND same length (code-review HIGH 2 —
        // a region lengthened after prime must re-render, or its cached tail
        // would exhaust into silence forever). In-flight windows are not re-spawned.
        if let existing = beatsBuffers[key],
           abs(existing.lengthSeconds - lengthSeconds) < 0.001 { return }
        if beatsInFlight.contains(key) { return }
        // Attach the plain node + capture the CONNECTION format NOW (audio-review
        // V1/V2): the async completion must never derive it from the shared
        // single-slot `file`, which may point at another URL by then.
        guard ensureLoaded(url) != nil else { return }
        beatsInFlight.insert(key)
        Task.detached(priority: .userInitiated) { [weak self] in
            // Audio-review V3: open + read on a FRESH handle OFF the main actor —
            // prime also fires at loop wrap / relocate-while-playing, where a
            // synchronous main-actor decode would delay the transport step.
            var inputs: [[Float]] = []
            var sampleRate = 0.0
            if let f = try? AVAudioFile(forReading: url) {
                let sr = f.processingFormat.sampleRate
                sampleRate = sr
                let startFrame = AVAudioFramePosition((max(0, fromSeconds) * sr).rounded())
                if sr > 0, startFrame < f.length {
                    let frames = AVAudioFrameCount(min(Double(f.length - startFrame),
                                                       (lengthSeconds * sr).rounded()))
                    if frames > 0, Int(Double(frames) / rate) <= Self.beatsMaxOutputFrames,
                       let raw = AVAudioPCMBuffer(pcmFormat: f.processingFormat,
                                                  frameCapacity: frames) {
                        f.framePosition = startFrame
                        if (try? f.read(into: raw, frameCount: frames)) != nil,
                           let data = raw.floatChannelData {
                            let n = Int(raw.frameLength)
                            inputs = (0..<Int(raw.format.channelCount)).map {
                                Array(UnsafeBufferPointer(start: data[$0], count: n))
                            }
                        }
                    }
                }
            }
            var rendered = inputs.isEmpty
                ? []
                : WSOLAStretcher().stretchMultichannel(inputs, rate: Float(rate))
            // W4b: the part's fades, baked into the OUTPUT — it plays at rate 1, so output frame
            // i is the file's moment fromSeconds + i × rate / sampleRate. Off the main actor.
            if let fades, sampleRate > 0 {
                fades.bake(into: &rendered, fromSeconds: fromSeconds,
                           mediaSecondsPerFrame: rate / sampleRate)
            }
            await self?.storeBeats(key: key, lengthSeconds: lengthSeconds, channels: rendered)
        }
    }

    /// Rebuild the rendered channels as a PCM buffer in the URL's NODE-CONNECTION
    /// format (captured in `ensureLoaded` — audio-review V1/V2) and cache it.
    /// Main actor — the cache is control-plane state. Empty channels = the read/
    /// cap/render failed off-main: clear the in-flight marker, log, play Clean.
    private func storeBeats(key: BeatsKey, lengthSeconds: Double, channels: [[Float]]) {
        beatsInFlight.remove(key)
        guard knownURLs[key.url] != nil, let fmt = urlFormats[key.url] else { return }
        guard let first = channels.first, !first.isEmpty,
              channels.count == Int(fmt.channelCount),
              let out = AVAudioPCMBuffer(pcmFormat: fmt,
                                         frameCapacity: AVAudioFrameCount(first.count)),
              let dst = out.floatChannelData else {
            // Symmetric logging (code-review LOW 7): every skip explains a Clean play.
            log.log(.info, category: .audio,
                    "Beats pre-render unavailable (read/cap/format) — region plays Clean")
            return
        }
        for (c, channel) in channels.enumerated() {
            channel.withUnsafeBufferPointer { src in
                guard let s = src.baseAddress else { return }
                dst[c].update(from: s, count: channel.count)
            }
        }
        out.frameLength = AVAudioFrameCount(first.count)
        // Fill-time sweep: `out` is still local here — it reaches `beatsBuffers`
        // only on the line below, so no node can be reading it. Doing this at
        // schedule time instead would re-walk the whole clip on every region onset
        // AND mutate a buffer a previously-scheduled node may still hold.
        AudioOutputGuard.sweepNonFinite(out)
        // Audio-review V4: a tempo edit changes the rate — evict this URL's
        // other-rate entries (only one rate can be current), bounding the cache.
        for k in beatsBuffers.keys where k.url == key.url && k.rateMilli != key.rateMilli {
            beatsBuffers[k] = nil
        }
        // W4b: likewise a fade edit — the same window at the same rate with other ramps is stale.
        for k in beatsBuffers.keys where k.url == key.url && k.rateMilli == key.rateMilli
            && k.fromMilli == key.fromMilli && k != key {
            beatsBuffers[k] = nil
        }
        beatsBuffers[key] = (lengthSeconds: lengthSeconds, buffer: out)
    }

    func play(url: URL, fromSeconds: Double, lengthSeconds: Double, gain: Float,
              stretch: StretchPlan) {
        // W4b: this part's fades, taken now so no exit below can leave them for the next part.
        let fades = pendingFades
        pendingFades = nil
        let grain = pendingGrain   // GA-10c: likewise, once per play
        pendingGrain = nil
        guard lengthSeconds > 0 else { stop(); return }
        guard let plainNode = ensureLoaded(url), let file else { return }
        // Beats-Executor: a prepared region onset schedules the READY stretched
        // buffer at rate 1 on the plain node (no spectral coloration). Only the
        // exact prepared window qualifies (onset entry, |Δ| < 1 ms) — a mid-region
        // entry (seek / unmute restart) falls through to the Clean chain below
        // (honest; the next onset is transient-locked again).
        // W4b: the key carries the part's fades, so a faded part finds only a rendering with
        // THOSE ramps baked in; until it is ready the part plays its Clean chain, fades and all.
        if stretch.rate != 1.0, stretch.mode == .beats, transposeSemitones == 0,
           let entry = beatsBuffers[BeatsKey(url: url, rate: stretch.rate, fromSeconds: fromSeconds,
                                             fades: fades)],
           abs(entry.lengthSeconds - lengthSeconds) < 0.001,
           plainNode.engine?.isRunning == true {
            stop()
            plainNode.scheduleBuffer(entry.buffer, at: nil)
            setGain(gain)
            plainNode.play()
            return
        }
        // GA-10c: a part with a grain plays its READY rendering on the plain node — only at its
        // onset (the exact window prime rendered, fades included), only unstretched and unpitched.
        // Anything else — not ready, a mid-part entry — falls through and plays dry, never silent.
        if let grain, stretch.rate == 1.0, transposeSemitones == 0,
           fromSeconds.isFinite, lengthSeconds.isFinite,
           let buffer = grainBuffers[GrainKey(url: url, fromSeconds: fromSeconds,
                                              lengthSeconds: lengthSeconds, settings: grain, fades: fades)],
           plainNode.engine?.isRunning == true {
            stop()
            plainNode.scheduleBuffer(buffer, at: nil)
            setGain(gain)
            plainNode.play()
            return
        }
        // Slice B: rate ≠ 1.0 renders through the warp chain (rate 1.0 tape ≡
        // clean by design — tapePitchCents(1) = 0 — so the plain path is honest).
        // Unwarped playback stays on the plain node: bit-identical to pre-Slice-B.
        // AE-10 review (MED): a chain needed ONLY for a pitch (rate 1) is never ATTACHED here —
        // an attach pauses the whole engine, and mid-song (an Undo that pitched a part while the
        // piece plays) that is an audible dropout. The starting prime attaches it
        // (`AudioLanePlayer.prime`); without one the part plays on the plain node, unpitched,
        // until the next Play — the Beats fallback's honesty. A WARPED plan keeps its lazy attach.
        let node: AVAudioPlayerNode
        if AudioTranspose.needsTimePitchChain(plan: stretch, semitones: transposeSemitones),
           let key = knownURLs[url],
           let chain = stretch.rate != 1.0 ? ensureWarpChain(for: key) : warpChains[key] {
            chain.timePitch.rate = Float(stretch.rate)
            chain.timePitch.pitch = AudioTranspose.nodePitchCents(plan: stretch,
                                                                  semitones: transposeSemitones)
            node = chain.player
        } else {
            node = plainNode
        }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return }
        let startFrame = AVAudioFramePosition((max(0, fromSeconds) * sampleRate).rounded())
        guard startFrame < file.length else { stop(); return }   // trim-in past the media end
        let remaining = Double(file.length - startFrame)
        let wanted = (lengthSeconds * sampleRate).rounded()
        let frames = AVAudioFrameCount(min(remaining, wanted))
        guard frames > 0 else { stop(); return }
        // `play()` on a node whose engine is not running raises an NSException
        // (hard crash) — reachable through an audio-session interruption while the
        // transport keeps stepping (review MEDIUM 1). Degrade to silence instead;
        // the next region onset re-drives the lane once the engine is back.
        guard node.engine?.isRunning == true else { return }
        stop()   // one region per lane: silence every node before the new segment
        if let fades, playFaded(fades, url: url, file: file, on: node, startFrame: startFrame,
                                frames: frames, sampleRate: sampleRate, gain: gain) { return }
        node.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil)
        setGain(gain)
        node.play()
    }

    /// Audio editor W4b: play the part's stretch of `file` with its fades. `PartFadePlan.pieces`
    /// cuts the frames at the two fade edges; a faded piece is read from a FRESH handle (the node
    /// streams the shared `file` on its own thread), multiplied by the ramp and scheduled as a
    /// buffer, and the middle plays straight from the file. Every piece goes on ONE node, back to
    /// back, so they play gapless and in order. Only the first piece is scheduled before `play()`
    /// — a faded one cut to `firstFadedChunkSeconds` — so a long fade-in never delays the part's
    /// start by its whole read; the rest is read while that first piece sounds.
    /// Returns false, having scheduled NOTHING, when the fresh handle cannot be opened or reads
    /// another format: the caller then plays the part unfaded — never silent.
    private func playFaded(_ fades: PartFadePlan, url: URL, file: AVAudioFile,
                           on node: AVAudioPlayerNode, startFrame: AVAudioFramePosition,
                           frames: AVAudioFrameCount, sampleRate: Double, gain: Float) -> Bool {
        guard let reader = try? AVAudioFile(forReading: url),
              reader.processingFormat.isEqual(file.processingFormat) else { return false }
        let cut = fades.pieces(startFrame: startFrame, frameCount: Int64(frames), sampleRate: sampleRate)
        var queue: [(frames: Range<Int64>, faded: Bool)] = []
        if let head = cut.head { queue.append((head, true)) }
        if let middle = cut.middle { queue.append((middle, false)) }
        if let tail = cut.tail { queue.append((tail, true)) }
        guard let first = queue.first else { return false }
        let chunk = Int64((Self.firstFadedChunkSeconds * sampleRate).rounded())
        if first.faded, chunk > 0, Int64(first.frames.count) > chunk {
            let cutAt = first.frames.lowerBound + chunk
            queue[0] = (first.frames.lowerBound..<cutAt, true)
            queue.insert((cutAt..<first.frames.upperBound, true), at: 1)
        }
        for (index, piece) in queue.enumerated() {
            if piece.faded, let buffer = baked(piece.frames, from: reader, plan: fades, sampleRate: sampleRate) {
                node.scheduleBuffer(buffer, at: nil)
            } else {
                // The middle — or a faded piece whose read failed: an unfaded edge, never a hole.
                node.scheduleSegment(file, startingFrame: piece.frames.lowerBound,
                                     frameCount: AVAudioFrameCount(piece.frames.count), at: nil)
            }
            if index == 0 {
                setGain(gain)
                node.play()
            }
        }
        return true
    }

    /// `frames` of `reader`, each multiplied by the part's fade at its own moment in the file —
    /// a fresh buffer the node owns from here on (never one it already holds). nil when the
    /// buffer cannot be made or the read comes back short: the caller then schedules those
    /// frames from the file, so the timing stays exact.
    private func baked(_ frames: Range<Int64>, from reader: AVAudioFile, plan: PartFadePlan,
                       sampleRate: Double) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(frames.count)
        guard count > 0, !reader.processingFormat.isInterleaved,
              let buffer = AVAudioPCMBuffer(pcmFormat: reader.processingFormat, frameCapacity: count)
        else { return nil }
        reader.framePosition = frames.lowerBound
        guard (try? reader.read(into: buffer, frameCount: count)) != nil,
              buffer.frameLength == count, let data = buffer.floatChannelData else { return nil }
        let channels = Int(buffer.format.channelCount)
        for i in 0..<Int(count) {
            let level = Float(plan.gain(atMediaSeconds: Double(frames.lowerBound + Int64(i)) / sampleRate))
            for channel in 0..<channels { data[channel][i] *= level }
        }
        return buffer
    }

    func stop() {
        for node in nodes.values where node.isPlaying { node.stop() }
        for chain in warpChains.values where chain.player.isPlaying { chain.player.stop() }
    }

    /// H4 live mixer: level/solo edits mid-region land on the nodes' mixer volume —
    /// control-plane only (AVAudioMixing downstream), no re-scheduling. Applied to
    /// every node (only one is audible at a time; a later format switch must not
    /// resurrect a stale level).
    func setGain(_ gain: Float) {
        let g = min(2, max(0, gain.isFinite ? gain : 0))   // non-finite ⇒ silent
        self.gain = g
        for node in nodes.values { node.volume = g }
        for chain in warpChains.values { chain.player.volume = g }
    }

    /// H4 live mixer: the lane's stereo position (B2 pan finally reaches audio lanes).
    func setPan(_ pan: Float) {
        // Non-finite ⇒ centre, the sibling of `setGain`'s non-finite ⇒ silent one line up. The
        // bare clamp sent NaN to HARD RIGHT (`min(1, NaN)` is 1) and stored it for every later
        // region start (overnight P8, #416).
        let p = max(-1, min(1, pan.isFinite ? pan : 0))
        self.pan = p
        for node in nodes.values { node.pan = p }
        for chain in warpChains.values { chain.player.pan = p }
    }

    /// Release every engine node (lane removed). Detach mutates the graph without
    /// pausing (disconnect+detach only) — permitted for removal.
    func detach() {
        releaseNodes()
        beatsBuffers.removeAll()
        beatsInFlight.removeAll()
        grainBuffers.removeAll()
        grainInFlight.removeAll()
        grainFailed.removeAll()
        grainQueued.removeAll()
        urlFormats.removeAll()
        file = nil
    }

    /// Detach every node this lane attached — players first, then the space bus they fed — and
    /// forget which node serves which file, so the next `ensureLoaded` attaches afresh in the
    /// current mode. (`urlFormats` is kept: it records the FILES' formats, not the nodes'.)
    /// Rendered Beats windows survive: they are in the FILE's format, not the node's.
    private func releaseNodes() {
        stop()
        if let engine {
            for node in nodes.values { engine.detachPlayerNode(node) }
            for chain in warpChains.values {
                engine.detachPlayerNode(chain.player, timePitch: chain.timePitch)
            }
            if let spaceBus { engine.detachSpaceBus(spaceBus) }
        }
        nodes.removeAll()
        warpChains.removeAll()
        knownURLs.removeAll()
        spaceBus = nil
    }

    /// S3c: the lane's space bus, attached on first need and placed at the last point handed
    /// over. nil outside the space, or when the engine has no valid rate — the lane then plays
    /// in the stereo mix, as before S3c, rather than not at all.
    // NEEDS-FOUNDER-VERIFY (S3c, G6): headphones on, Mixer → "Headphone space" on, a piece with
    // two audio tracks — they sound from different places, and from the same places after the
    // piece is reopened. The distance roll-off (reference 1 m, rolloff 0.5) is an estimate.
    private func spaceBusIfWired() -> AVAudioMixerNode? {
        guard wiredInSpace, let engine else { return nil }
        if let spaceBus { return spaceBus }
        guard let bus = engine.attachSpaceBus() else { return nil }
        if let spacePoint { place(bus, at: spacePoint) }
        spaceBus = bus
        return bus
    }

    /// Open `url` if it isn't the loaded file, and return the ATTACHED node for
    /// its format — creating + attaching one on the format's first appearance
    /// (attach pauses the engine; by construction that happens at prime time,
    /// or mid-song only for a format never seen at prime — see header).
    /// Returns nil when the file can't be read.
    private func ensureLoaded(_ url: URL) -> AVAudioPlayerNode? {
        guard let engine else { return nil }
        if file == nil || file?.url != url {
            guard let f = try? AVAudioFile(forReading: url) else {
                log.log(.error, category: .audio,
                        "TimelineAudioSink: cannot read \(url.lastPathComponent)")
                stop()
                return nil
            }
            file = f
        }
        guard let file else { return nil }
        let format = file.processingFormat
        let key = FormatKey(channels: format.channelCount, rate: format.sampleRate)
        knownURLs[url] = key
        // Audio-review V1/V2: remember the exact connection format per URL — the
        // Beats rebuild must use it (never the shared `file` slot at completion time).
        // Verify-pass LOW: a file REPLACED in-place with a different format must
        // also drop its cached Beats windows (an old-format buffer scheduled on
        // the new-format node would raise the scheduleBuffer NSException). The
        // app's import/record flow mints new URLs, so this is belt-and-braces.
        if let old = urlFormats[url], !old.isEqual(format) {
            for k in beatsBuffers.keys where k.url == url { beatsBuffers[k] = nil }
            for k in grainBuffers.keys where k.url == url { grainBuffers[k] = nil }   // GA-10c, same reason
        }
        urlFormats[url] = format
        if let existing = nodes[key] { return existing }
        let node = AVAudioPlayerNode()
        // S3c review LOW-2: a space attach that refuses falls back to the stereo path, so the
        // node in `nodes` is always an ATTACHED one (a detach of a never-attached node raises).
        var inSpace = false
        if let bus = spaceBusIfWired() {
            inSpace = engine.attachSpacePlayer(node, timePitch: nil, format: format, bus: bus)
        }
        if !inSpace { engine.attachPlayerNode(node, format: format) }
        node.volume = gain
        node.pan = pan
        nodes[key] = node
        return node
    }

    /// Slice B: the ATTACHED warp chain (player → timePitch → master) for `key`,
    /// creating + attaching one on first need. By construction that happens at
    /// prime time (`preload(url:warped:)`); mid-song only for a region warped
    /// live after the last prime — bounded, like the plain unseen-format path.
    /// The player joins at the lane's CURRENT mixer state (a chain attached
    /// after a live edit must not resurrect a stale level — same rule as
    /// `ensureLoaded`). Returns nil when no engine is available.
    private func ensureWarpChain(for key: FormatKey)
        -> (player: AVAudioPlayerNode, timePitch: AVAudioUnitTimePitch)? {
        if let existing = warpChains[key] { return existing }
        guard let engine, let file else { return nil }
        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        var inSpace = false
        if let bus = spaceBusIfWired() {
            inSpace = engine.attachSpacePlayer(player, timePitch: timePitch, format: file.processingFormat, bus: bus)
        }
        if !inSpace { engine.attachPlayerNode(player, through: timePitch, format: file.processingFormat) }
        player.volume = gain
        // S3c review LOW-3: inside the mono space bus `pan` has no audible effect — the bus
        // position places the track; the value is kept so the stereo path resumes it.
        player.pan = pan
        let chain = (player: player, timePitch: timePitch)
        warpChains[key] = chain
        return chain
    }
}
#endif
