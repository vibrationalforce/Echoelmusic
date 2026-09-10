#if canImport(AVFoundation) && canImport(Metal)
import AVFoundation
import Metal
import CoreVideo
import CoreMedia
#if canImport(CoreImage)
import CoreImage
#endif
import QuartzCore
#if canImport(Observation)
import Observation
#endif
#if canImport(Photos)
import Photos
#endif

/// P3 · Video — records the bio-reactive Metal visual (the image the body drives)
/// to an H.264 `.mp4`. This is the on-brand video source: it does NOT touch the
/// low-res, bio-critical rPPG camera path, and there is no camera-session
/// conflict with a running pulse measurement.
///
/// How: from the Metal draw loop (main thread), after the shader has rendered the
/// frame into the drawable, `capture(from:in:device:)` blits that drawable texture
/// into a pooled BGRA `CVPixelBuffer` **inside the same command buffer** (so it
/// records this exact frame), then feeds the buffer to `VideoRecorder` on GPU
/// completion. `VideoRecorder.ingest` is lock-safe + nonisolated, so the
/// completion handler (a background GPU thread) can call it directly.
///
/// UI observes `video.recordState`.
@MainActor @Observable
final class VisualRecorder {

    /// The underlying file sink (H.264 mp4). Its `recordState` is the observable UI state.
    let video = VideoRecorder()

    @ObservationIgnored private var textureCache: CVMetalTextureCache?
    @ObservationIgnored private var pool: CVPixelBufferPool?
    @ObservationIgnored private var poolWidth = 0
    @ObservationIgnored private var poolHeight = 0

    var isRecording: Bool { video.recordState.isRecording }

    /// #985 — ONE frame wanted as a still image. Set by `requestStill()`, cleared by the very
    /// next `capture(...)` that actually blits, so a tap can never arm more than one frame.
    ///
    /// WHY A FLAG AND NOT A FUNCTION THAT GRABS: the drawable is only blit-readable on a frame
    /// that came in with `framebufferOnly == false`, and `MetalBioView` keeps the FAST path
    /// (`true`) unless something wants capture — flipping it mid-frame is the validation failure
    /// that once forced the flag permanently false, and writing it every frame made the picture
    /// shimmer. So a still uses the SAME two-frame dance the recorder already documents: this flag
    /// makes the next frame readable, the frame after that is the one that gets copied
    /// (~16 ms later, imperceptible). No new mechanism, no second code path into the drawable.
    private(set) var stillRequested = false

    /// True while either a video take or a pending still needs a blit-readable drawable.
    /// `MetalBioView.draw` reads exactly this — it must not learn about stills separately.
    var wantsFrameCapture: Bool { isRecording || stillRequested }

    /// Ask for the next available frame as a still image. Idempotent while one is pending.
    func requestStill() { stillRequested = true }

    // MARK: - Take outcome (#990)

    /// What became of the last VIDEO take. Same defect as the still button had before #986, on the
    /// artefact that costs far more to lose: `stop()` returns nil on several paths and all three
    /// stop doors discard it, so an unrepeatable performance capture could end with no share
    /// sheet, no library row and no sentence. The worst shape is the EMPTY take — the REC badge
    /// counts wall-clock seconds off a `Date` while no frame ever reached the writer, so the
    /// performer watches a running timer for a recording that wrote nothing.
    ///
    /// `.empty` and `.failed` are deliberately separate: one is "nothing arrived to record" (retry
    /// is likely to work), the other is "the writer refused" (it probably will not). Collapsing
    /// them into "failed" throws away the half the user can act on.
    enum TakeOutcome: Equatable, Sendable { case saved, empty, failed(String) }

    /// The last outcome, or nil if no take has finished this session.
    private(set) var lastTakeOutcome: TakeOutcome?

    /// Bumped once per finished take — the same reason the still has one: two takes ending the
    /// same way are two events, and an `onChange` on the value alone shows only the first.
    private(set) var takeOutcomeToken: UInt = 0

    private func publishTake(_ outcome: TakeOutcome) {
        lastTakeOutcome = outcome
        takeOutcomeToken &+= 1
    }

    // MARK: - Still outcome (#986)

    /// What became of the last still. #985 shipped the picture and told the user NOTHING:
    /// success, a denied photo-library permission and an encode failure were all indistinguishable
    /// from a dead button, and the only trace was an `os_log` line the founder cannot see. That is
    /// the "permission denials handled gracefully" and "buttons respond, states change" items of
    /// the CLEAR-SOFTWARE checklist, both open on a shipped feature.
    enum StillOutcome: Equatable, Sendable { case saved, denied, failed }

    /// The last outcome, or nil if no still has completed this session.
    private(set) var lastStillOutcome: StillOutcome?

    /// Bumped once per completed still. A view CANNOT watch `lastStillOutcome` alone: two stills in
    /// a row with the SAME outcome produce no change, so the second one would flash nothing. The
    /// token is the thing that always moves.
    private(set) var stillOutcomeToken: UInt = 0

    /// One writer for both. Called on the main actor from the GPU completion's hop.
    private func publishStill(_ outcome: StillOutcome) {
        lastStillOutcome = outcome
        stillOutcomeToken &+= 1
    }

    @ObservationIgnored private weak var audioEngine: AudioEngine?

    // MARK: - Control

    /// Start recording the visual. The master-mix audio is grabbed from the
    /// always-on ring buffer on `stop()` (last N seconds), so nothing to start here
    /// but remembering the engine to pull from.
    func start(audio: AudioEngine? = nil) {
        audioEngine = audio
        video.startRecording()
    }

    /// Finish the video, grab the matching tail of master-mix audio, and mux them.
    /// Returns the final .mp4 (video-only if there was no audio engine, nil only if
    /// the video itself failed).
    @discardableResult
    func stop() async -> URL? {
        // ⛔ RE-ENTRY GUARD (#387 Nachlese) — WITHOUT IT A SECOND STOP SILENCES THE FIRST ONE'S
        // CLIP. `video.stopRecording()` rejects the second caller and returns nil, but THIS
        // function used to carry on past it and reach `audioEngine = nil` below. Two calls
        // enqueued in the same run-loop turn therefore interleaved like this: A sets
        // `.finishing` synchronously and suspends inside `stopRecording`'s continuation → B
        // falls straight through and nils the engine → A resumes, reads `audioEngine` as nil,
        // takes the `guard let audioURL else { saveToPhotoLibrary(videoURL) }` escape and saves
        // the take WITHOUT ITS AUDIO. Silent, unrepeatable, and it looks like a muxer bug.
        //
        // The hole is older than #387 — `FloatingVisualWindow.toggleRecording` could always
        // reach it — but #387 added a SECOND tappable Stop (the Video panel's row), so the fix
        // belongs here, at the one place both doors go through, and not in either caller.
        // Found by the reviewer on `691f213`; the tap timing is tight (after A runs the row has
        // already swapped), which is exactly why it would have shipped.
        // #990: this exit publishes NOTHING on purpose. It is the SECOND caller of a
        // double-tap, and the first one is mid-flight — writing an outcome here would overwrite
        // the real answer with "nothing happened" a moment before the true one arrives.
        guard video.recordState == .recording else { return nil }
        // #1198 — HAND THE POOLED FRAME MEMORY BACK, ON EVERY EXIT OF THIS FUNCTION.
        //
        // `ensureResources` built `pool` and `textureCache` on the first captured frame and
        // NOTHING ever released them. A `CVPixelBufferPool` RECYCLES rather than frees: every
        // buffer it has handed out and taken back stays resident, and one 1080p BGRA buffer is
        // 1920 × 1080 × 4 ≈ 8.3 MB of IOSurface. So a single finished take left tens of
        // megabytes held for the rest of the process — and held OUTSIDE the heap, which is why
        // it does not show up where a session would look for it.
        //
        // `defer`, not a line at the end: `stop()` has FIVE returns, and the two easiest to
        // forget are the failure ones (the writer refused / no frame ever arrived) — exactly
        // the runs where a user is most likely to try again straight away and build a second
        // pool on top of the first.
        //
        // ⛔ THE CONDITION IS THE #1198b REPAIR, AND THE FIRST VERSION'S REASONING FOR LEAVING
        // IT OUT WAS WRONG. That version argued placement was enough: "it sits BELOW the
        // re-entry guard, so a second caller returns above this line while the first is still
        // mid-flight." The guard proves the state was `.recording` AT ENTRY. The `defer` fires
        // at EXIT — after `stopRecording()` and after `VideoMuxer.mux`, which is a full
        // `AVAssetExportSession` re-encode and runs for SECONDS.
        //
        // In that window `video.recordState` is already terminal, so the floating window's
        // button has flipped back to "record" and a tap arms a NEW take
        // (`VideoRecorder.startRecording` accepts every terminal state, deliberately). The
        // mux then finishes and this `defer` tears down the pool belonging to the take that is
        // now running. Self-healing — `ensureResources` runs at the top of every frame — but
        // it is a pool + cache reallocation mid-take on a 60 Hz path, at the start of a
        // performance. Found by the mandatory review, not by a guard.
        //
        // Asking the state AT FIRE TIME answers the question the placement only appeared to.
        defer { if !video.recordState.isRecording { releaseResources() } }
        let videoURL = await video.stopRecording()
        // Pull the last `duration` seconds of the mix NOW (ends ≈ the video's end →
        // best-effort alignment). Ring is ~30 s; longer videos get their last 30 s.
        let duration = video.recordedSeconds()
        let audioURL = duration > 0.2 ? audioEngine?.captureRecentMixAudio(seconds: duration) : nil
        audioEngine = nil
        // The captured mix audio is a temp intermediate. Once VideoMuxer has baked it
        // into the final .mp4 (or if we bail before muxing), delete it so temp audio
        // files don't accumulate in tmp. Runs at scope exit — AFTER the awaited mux
        // completes below — so it never pulls the file out from under the export.
        defer { if let audioURL { try? FileManager.default.removeItem(at: audioURL) } }
        guard let videoURL else {
            // Which nil this is, read from the sink's own state rather than guessed: `.error`
            // means the writer refused and carries its reason; anything else means the take was
            // armed and no frame ever arrived (`stopRecording` sets `.idle` on that path).
            if case .error(let message) = video.recordState { publishTake(.failed(message)) }
            else { publishTake(.empty) }
            return nil
        }
        guard let audioURL else {
            Self.saveToPhotoLibrary(videoURL)
            publishTake(.saved)
            return videoURL
        }
        if let muxed = await VideoMuxer.mux(video: videoURL, audio: audioURL) {
            // The muxed clip is the durable library entry (Documents/Videos) —
            // drop the silent intermediate so the Video window never lists a
            // soundless twin of every recording.
            try? FileManager.default.removeItem(at: videoURL)
            Self.saveToPhotoLibrary(muxed)
            publishTake(.saved)
            return muxed
        }
        Self.saveToPhotoLibrary(videoURL)
        publishTake(.saved)
        return videoURL   // mux failed → return at least the silent video
    }

    /// Every finished recording is ALSO added to the user's photo library, so it lands
    /// where they keep and share video; the app-private Documents/Videos copy stays the
    /// durable fallback either way. (The original 2026-07-17 reason was re-import onto a
    /// video LANE — those lanes were deleted with the video-cut surface, so only the
    /// keep-and-share half survives. The permission string says exactly that now.)
    /// Best-effort and add-only (`.addOnly` — the narrowest
    /// permission; denial just logs, nothing else changes, and the Documents copy
    /// is never deleted before Photos has copied the file, because stop() never
    /// deletes the FINAL url at all).
    private static func saveToPhotoLibrary(_ url: URL) {
        #if canImport(Photos) && !os(macOS)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                log.log(.info, category: .video,
                        "VisualRecorder: photo-library add not authorized — clip stays in-app only")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                if !success {
                    log.log(.error, category: .video,
                            "VisualRecorder: photo-library save failed: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
        #endif
    }

    // MARK: - Frame tap (main thread, from the Metal draw loop)

    /// Blit the just-rendered `source` (the drawable texture) into a pooled pixel
    /// buffer within `commandBuffer`, then ingest it on GPU completion. No-op unless
    /// recording. Requires the source texture to be blit-readable — the renderer
    /// sets `framebufferOnly = false` while recording so the drawable qualifies.
    func capture(from source: MTLTexture, in commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        // #985: a pending still is a second reason to copy this frame. Sampled ONCE here so the
        // rest of the function sees one consistent answer even though `stillRequested` is cleared
        // below — reading it twice would be the classic half-armed state.
        let wantsStill = stillRequested
        guard video.recordState.isRecording || wantsStill else { return }
        // H.264 requires even dimensions; drawables are normally even — guard anyway.
        let w = source.width & ~1
        let h = source.height & ~1
        guard w > 0, h > 0 else { return }

        // #1198b — SAME SHAPE AS `stop()`, and for the same reason the first version got wrong
        // there. `capture` has five returns too, and THREE of them are after
        // `ensureResources` has already built the pool and the cache: the pool/cache pair
        // failing to appear, the buffer dequeue failing, and the texture-or-encoder creation
        // failing. The first version released on the success path only, with a trailing line —
        // i.e. it reproduced the exact defect it was written to remove, one branch deeper and
        // silently. Found by the mandatory review.
        //
        // The condition is what keeps a running take's pool alive: during a take the next
        // frame is 1/60 s away, so tearing down and rebuilding per frame would be the opposite
        // trade. A still taken while NOT recording is a one-off and gives everything straight
        // back.
        //
        // Safe with the blit in flight — see the note on `releaseResources`.
        defer { if !video.recordState.isRecording { releaseResources() } }

        ensureResources(width: w, height: h, device: device)
        guard let cache = textureCache, let pool else { return }

        var pbOut: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut) == kCVReturnSuccess,
              let pb = pbOut else { return }

        var cvTexOut: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, pb, nil, .bgra8Unorm, w, h, 0, &cvTexOut)
        guard status == kCVReturnSuccess, let cvTex = cvTexOut,
              let dst = CVMetalTextureGetTexture(cvTex),
              let blit = commandBuffer.makeBlitCommandEncoder() else { return }

        blit.copy(from: source, sourceSlice: 0, sourceLevel: 0,
                  sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: w, height: h, depth: 1),
                  to: dst, destinationSlice: 0, destinationLevel: 0,
                  destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()

        // Ferry recorder + buffer + timestamp through the @unchecked Sendable box so the
        // @Sendable GPU-completion closure captures ONLY that box. The timestamp is
        // sampled NOW (at capture), not in the async handler.
        // INVARIANT: the pooled `pb` must not be recycled until this handler runs — it
        // isn't, because each frame dequeues a fresh buffer and every reference to it lives in
        // the box, which releases them after `ingest`. (⛔ This said "its ONLY reference" and
        // #1204 made that literally false one line later: `tex` wraps the SAME buffer, so the
        // box now holds two. Harmless — they die together — but a sentence amended by the very
        // diff that falsified its neighbour is how a comment starts lying.)
        // #1204 puts the CoreVideo texture wrapper AND its cache in the same box, for the same
        // reason one and two hazards over: see `FrameBox`.
        let box = FrameBox(sink: video, pb: pb,
                           pts: CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600),
                           tex: cvTex, cache: cache)
        // #985: the still is consumed HERE, not in the completion handler — the flag must fall on
        // the frame that was actually blitted, and this line runs on the main-thread draw loop
        // where the flag lives. Clearing it inside the @Sendable GPU closure would be a
        // main-actor write from a background thread AND could arm a second frame in between.
        let recording = video.recordState.isRecording
        if wantsStill { stillRequested = false }
        commandBuffer.addCompletedHandler { [self] _ in
            // #986: ONE actor hop per STILL — not per frame. The 30 fps rule bans a hop per
            // captured frame (it starves the SwiftUI executor); this closure only hops when a
            // human has just tapped, which is at most a few times a minute.
            if wantsStill {
                VisualRecorder.saveStillToPhotoLibrary(box.pb) { outcome in
                    Task { @MainActor in self.publishStill(outcome) }
                }
            }
            // A still asked for on a NON-recording frame must not be fed to the file sink:
            // `ingest` would open a writer for a take nobody started.
            if recording { box.sink.ingest(box.pb, at: box.pts) }
            // #1204 — THE BOX'S TEXTURE FIELD HAS TO BE USED, OR OWNING IT PROVES NOTHING.
            // A stored field that nothing ever reads is a dead capture, and a dead capture is
            // precisely what a compiler may drop; "the struct is captured whole so ARC keeps
            // it" is a belief about optimisation, and this file has already paid for one of
            // those. `withExtendedLifetime` is the documented way to say KEEP THIS UNTIL HERE.
            // It emits no work — it exists to make the field live all the way to GPU
            // completion, which is the only moment the destination texture stops being needed.
            // TWO calls, not one over a tuple: `_fixLifetime` on an aggregate keeping every
            // element alive is a belief about lowering, and the block above spends a paragraph
            // refusing to lean on exactly that class of belief. Two lines, no belief.
            withExtendedLifetime(box.tex) {}
            withExtendedLifetime(box.cache) {}
        }
    }

    // MARK: - Still image (#985)

    /// Convert one BGRA pixel buffer to a JPEG-backed asset in the photo library.
    ///
    /// Same permission posture as the video path: `.addOnly`, best-effort, a denial only logs.
    /// Nothing is written to Documents — a still that cannot reach Photos leaves no orphan file.
    ///
    /// ⚠️ Runs on the GPU completion thread, NOT the main actor: `nonisolated static` on purpose,
    /// and it touches only the buffer handed to it plus Photos, never `self`.
    nonisolated static func saveStillToPhotoLibrary(
        _ pb: CVPixelBuffer,
        completion: @escaping @Sendable (StillOutcome) -> Void
    ) {
        #if canImport(Photos) && canImport(CoreImage) && !os(macOS)
        // ⛔ THE FIRST VERSION OF THIS FUNCTION BUILT THE CONTEXT TWICE and went
        // CIImage → CGImage → CIImage → JPEG. The CGImage step buys nothing: `jpegRepresentation`
        // takes the CIImage directly. One context, one conversion, and the encode happens BEFORE
        // the permission prompt so a slow tap on the dialog cannot outlive the pooled buffer —
        // which is the real reason the order matters, not tidiness. The buffer is only guaranteed
        // alive for the duration of this call.
        guard let data = CIContext(options: nil)
            .jpegRepresentation(of: CIImage(cvPixelBuffer: pb),
                                colorSpace: CGColorSpaceCreateDeviceRGB(),
                                options: [:]) else {
            log.log(.error, category: .video, "VisualRecorder: still could not be encoded")
            completion(.failed)
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                log.log(.info, category: .video,
                        "VisualRecorder: photo-library add not authorized — still discarded")
                completion(.denied)
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.forAsset()
                    .addResource(with: .photo, data: data, options: nil)
            }) { success, error in
                if !success {
                    log.log(.error, category: .video,
                            "VisualRecorder: still save failed: \(error?.localizedDescription ?? "unknown")")
                }
                completion(success ? .saved : .failed)
            }
        }
        #else
        // No Photos/CoreImage on this platform. Report the failure rather than returning without
        // ever calling back: a caller that waits forever for a callback that cannot come looks
        // exactly like the dead button this slice exists to remove.
        completion(.failed)
        #endif
    }

    // MARK: - Resources

    /// Give back what `ensureResources` took. A `CVPixelBufferPool` recycles instead of
    /// freeing, so "not used any more" and "not resident any more" are different things here.
    ///
    /// ⚠️ HOW MUCH — corrected by the mandatory review, because the first version quoted
    /// `1080p → 8.3 MB` and this app never captures at 1080p. The recorded texture is the
    /// FLOATING WINDOW'S drawable, sized from its on-screen bounds (`MetalBioView` sets
    /// `drawableSize` from `bounds × screen.scale`, `autoResizeDrawable = false`), and the
    /// window offers four sizes. On a modern phone that spans roughly **0.7 MB per buffer at
    /// the small size to ~12 MB at fullscreen** — the window's own tooltip says the same thing
    /// from the user's side ("the video is rendered at the window's on-screen size"). The pool
    /// settles at the high-water mark of simultaneously-live buffers (a handful) and never
    /// ages them out: `CVPixelBufferPoolCreate` is called with nil pool attributes, so there is
    /// no maximum-age key, and nothing in `Sources/` ever calls `CVPixelBufferPoolFlush`. So
    /// "tens of megabytes" is honest for a fullscreen take and an order of magnitude too high
    /// for a small one. Quote the range, not one number.
    ///
    /// The flush is not redundant with dropping the reference. `CVMetalTextureCacheFlush`
    /// releases the cache's textures for buffers that are no longer in use; releasing the
    /// cache object alone leaves that to whenever the last texture reference dies.
    ///
    /// ⚠️ THE FLUSH IS DETERMINISTIC, THE POOL DEALLOCATION IS NOT — the first version said
    /// both were, which contradicts this file's own safety argument. An outstanding
    /// `CVPixelBuffer` keeps its pool alive, so `pool = nil` frees nothing until the last
    /// in-flight buffer's completion handler retires. That is exactly why the release is safe;
    /// it is also why it is not instant.
    ///
    /// ⚠️ WHY RELEASING IS SAFE WHILE A BLIT IS IN FLIGHT — two reasons for two DIFFERENT
    /// hazards, not belt-and-braces (the first version presented them as interchangeable, and
    /// a reader who invalidated one would have believed the other still covered them):
    ///  · the TEXTURE-CACHE FLUSH is safe because the frame's own `CVMetalTexture` wrapper
    ///    travels in the `FrameBox` and is released only after the GPU-completion handler has
    ///    run (#1204). A flush releases the cache's textures for buffers NO LONGER IN USE, and
    ///    this one demonstrably still is. ⛔ Until #1204 this bullet rested on something else:
    ///    that `MetalBioView` builds its command buffer with RETAINED references
    ///    (`makeCommandBuffer()`, not `makeCommandBufferWithUnretainedReferences()`) — an
    ///    invariant in ANOTHER FILE that no guard pins and that nothing there warns about.
    ///    ⚠️ THAT INVARIANT IS STILL LIVE FOR THE OTHER HALF OF THE BLIT: the SOURCE texture
    ///    is `MetalBioView`'s drawable, which this file does not own and cannot box. So the
    ///    line still matters — it is just no longer the only thing holding the destination up.
    ///  · the POOL RELEASE is safe because a `CVPixelBuffer` keeps its own pool alive, so
    ///    `box.pb` cannot lose its backing when our reference goes away.
    ///  · the CACHE RELEASE (`textureCache = nil`) is safe because the frame's box holds the
    ///    cache too (#1204). This bullet did not exist before that slice and did not need to:
    ///    no `CVMetalTexture` provably outlived `capture`, so nothing could be orphaned. Now
    ///    one does, and `stop()`'s release can fire with a blit in flight — so the question
    ///    "does a `CVMetalTexture` retain its cache?" became load-bearing. It is answered by
    ///    owning the cache rather than by assuming the answer.
    /// ⛔ THE SENTENCE THAT STOOD HERE WAS RIGHT AND WAS BEING USED AS AN EXCUSE: "do not
    /// reason from the local `cvTex` surviving to the end of `capture` — Swift ARC is not
    /// scope-based and may release it at last use". Correct, and the answer to it is to give
    /// the wrapper an owner that outlives the GPU, not to lean on a neighbouring file.
    ///
    /// The width/height reset is not cosmetic either: `ensureResources` decides on
    /// `pool == nil || poolWidth != width`, so a stale size beside a nil pool is a state that
    /// reads as "wrong size" when it means "no pool". Both halves cleared together.
    private func releaseResources() {
        if let textureCache { CVMetalTextureCacheFlush(textureCache, 0) }
        textureCache = nil
        pool = nil
        poolWidth = 0
        poolHeight = 0
    }

    private func ensureResources(width: Int, height: Int, device: MTLDevice) {
        if textureCache == nil {
            var cacheOut: CVMetalTextureCache?
            CVMetalTextureCacheCreate(nil, nil, device, nil, &cacheOut)
            textureCache = cacheOut
        }
        if pool == nil || poolWidth != width || poolHeight != height {
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            ]
            var poolOut: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &poolOut)
            pool = poolOut
            poolWidth = width
            poolHeight = height
        }
    }

    /// Recorder + non-Sendable pixel buffer + timestamp ferried into the @Sendable
    /// GPU completion handler (same escape hatch as the RGB sample queue).
    ///
    /// ⭐ `tex` AND `cache` ARE NOT READ BY THE HANDLER, AND THAT IS THE WHOLE POINT (#1204).
    /// They are here to be OWNED until the GPU finishes. `CVMetalTextureGetTexture` hands back
    /// a texture CoreVideo owns, valid only while its `CVMetalTexture` wrapper lives; Swift ARC
    /// is not scope-based, so in `capture` the wrapper's last USE is that one getter call and
    /// it may be released there — before the blit it is the destination of has run.
    ///
    /// ⛔ SAY THE HAZARD NARROWLY. The first draft of this block said the destination "stayed
    /// alive by accident" of `MetalBioView` using `makeCommandBuffer()`, i.e. that the texture
    /// would otherwise have been DEALLOCATED. That over-claims, and the mandatory review
    /// measured why: `pb` in this same box already pins the IOSurface the texture is backed
    /// by, and `dst` is a strong Swift reference the retained command buffer also holds. Both
    /// the object and its backing were held. What was NOT held is the thing Apple's contract
    /// is actually about — the WRAPPER, which is what tells the texture cache the entry is
    /// still in use. Release it early and `CVMetalTextureCacheFlush` (which this file calls,
    /// see `releaseResources`) is free to treat the entry as unused and recycle it while the
    /// GPU is still writing. That is the real hazard, it is enough on its own, and it does not
    /// need the bigger claim.
    ///
    /// ⚠️ `cache` IS HERE BECAUSE THIS SLICE CREATED ITS NEED — it is not tidiness. Before
    /// #1204 no `CVMetalTexture` provably outlived `capture`, so `releaseResources()` setting
    /// `textureCache = nil` was uncontroversial. Now one demonstrably does: `stop()`'s
    /// conditional release fires while the last take's blit can still be in flight. Whether a
    /// `CVMetalTexture` retains its cache is exactly the question this file answers explicitly
    /// for the pool one bullet below ("a `CVPixelBuffer` keeps its own pool alive") — so it is
    /// answered here by OWNERSHIP rather than by assumption, at the cost of one field.
    ///
    /// ⚠️ IT DOES NOT MAKE THE COMMAND BUFFER'S RETENTION IRRELEVANT — say which texture, or
    /// this is the #1198b mistake again (an argument true of ONE thing, asserted generally).
    /// The blit has two textures. This box covers the DESTINATION. The SOURCE is the drawable,
    /// owned by the `CAMetalLayer` and held by `MetalBioView` only as a local for the duration
    /// of its `draw`, and it still depends on that call. Do not delete the warning at
    /// `releaseResources` on the strength of this one.
    ///
    /// ⚠️ `CVPixelBuffer` and `CVMetalTexture` are BOTH typealiases of `CVImageBuffer`, so
    /// `pb:` and `tex:` are the same Swift type and swapping them at the call site COMPILES.
    /// The field names are the only thing keeping them apart; there is no type-checker here.
    private struct FrameBox: @unchecked Sendable {
        let sink: VideoRecorder
        let pb: CVPixelBuffer
        let pts: CMTime
        let tex: CVMetalTexture
        let cache: CVMetalTextureCache
    }
}
#endif
