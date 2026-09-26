// MediaRelink.swift
// Echoel — point a clip whose file is MISSING at a file in the media library (Phase 3 / B2b; plan
// `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md`, founder media law 2026-09-26: "missing media keeps
// its creative structure … relink stays possible").
//
//     "Missing on this device" row → Relink → a library file
//         → the clip's `mediaRef` (and its measured length) now name that file
//         → every part that plays the clip plays it again; nothing else about the song moves
//
// ⭐ THE CLIP IS THE CREATIVE USE, THE FILE IS THE SOURCE — AND ONLY THE SOURCE CHANGES. The clip
// keeps its id (every region points at it), its name, its tempo (`nativeBPM`), its automation;
// no region is written. That is the whole reason a relink exists instead of "Place it again":
// placing makes a NEW part and leaves the silent ones where they were.
//
// ⚠️ SAME LENGTH ONLY — A GUARD AGAINST THE OBVIOUS MISTAKE, NOT A PROOF OF IDENTITY. A clip that
// knows its length refuses a file of another length (`sameLength`): a relink to a different sound
// keeps the old tempo and part lengths, so the song would play it warped and cut for the one that
// is gone — silently. Two different recordings of the SAME length pass (two 4-bar loops at one
// tempo are both exactly 8 s; 1 % of a long take is seconds). The clip stores no second
// fingerprint, so this rule cannot tell them apart; the words the user sees say "same length",
// never "same recording". A clip that never learned its length takes the file's.
//
// ⭐ MA4.5 + MA4.4 — WHAT THE CLIP LINKS, AND WHEN A SHARED IDENTITY MAY MOVE. The registry is
// app-wide: one `MediaAssetRecord` can be linked by clips in several saved projects, so moving
// its binding repairs or corrupts ALL of them at once. The record therefore moves only on
// PROOF — equal SHA-256 digests (MA4.4, founder 2026-09-26) — never on a compatible length.
// First the record may REFUSE the file (`recordRefusal`): another digest → `.differentSource`,
// an incompatible length → `.differentLength`. Then `identity(…)`, in this order:
// A. the clip's record carries a digest and the chosen file's EQUALS it — same bytes, proven:
//    the chosen file's own record, if it has another one, is adopted (never hidden); else the
//    record keeps the clip's link and, while it still names this clip's missing file, its
//    BINDING MOVES there with its id (record, clip and region ids all stay); a record that
//    already names another file keeps that binding (it holds the same bytes);
// C. otherwise, the chosen file has its OWN unrefuted record → the clip ADOPTS it (never
//    hidden, never stolen);
// D. otherwise nothing proves the source: the chosen file gets its own new record and the clip
//    links THAT — a compatible length establishes compatibility, never a move of a shared record.
//    Without a registry the link is released.
// (B — digests differ — is the refusal above.) The chosen file is hashed only when the clip's
// record has a digest to compare (`needsContentProof`), off the main actor, after the cheap
// length check (`perform`). A digest computed for the relink is also written to the chosen
// file's own record when that record has none — the one backfill a relink does.
// ⚠️ Steps A-with-own-record, C and D give the clip ANOTHER MediaAsset id than it had: the
// chosen file already has, or now gets, its own identity, and the old record keeps describing
// the missing source for every project that still links it.
//
// ⭐ ONE UNDO STEP IN THE CURRENT SESSION (founder 2026-09-26, after review M1 found the first
// header's "undone by relinking again" false). The write goes through
// `TimelineStore.relinkClipSource`, which records the old binding as a `.clipSource` history step:
// Undo restores the old `mediaRef` and length, Redo the new ones. The old reference is NOT kept
// on the clip — no schema debt before MediaAsset owns identity — so it does not survive a
// relaunch. Relink stays a MISSING-media repair: offered only on a missing clip, never on a
// healthy one (a deliberate substitution would be a future "Replace Source", founder).
//
// ⚠️ NOT WHILE THE SONG PLAYS (M3): a lane whose only clip was missing has no preloaded file, so
// the next onset after a relink would attach a node — and an attach pauses the engine. The
// browser refuses first (`MediaBrowserView.relinkRefusal`); the next Play preloads it silently.
//
// ⛔ NEVER A FILE OPERATION. Nothing here copies, moves or deletes; the chosen file is used where
// it already is in the library, as `MediaPlacement`'s orphan path uses it.

import Foundation

/// Relinking a missing clip to a library file.
public enum MediaRelink {

    /// Why a relink was refused. Nothing is written in any of these cases.
    public enum Refusal: Error, Equatable, Sendable {
        /// No clip with that id, or it is not an audio clip.
        case noAudioClip
        /// The library file vanished between the listing and the tap.
        case fileGone
        /// The file could not be measured as audio.
        case unreadable
        /// The clip knows its length and the file is another recording.
        case differentLength(expected: Double, found: Double)
        /// The clip's durable record carries a content digest and the file's differs: another
        /// source, whatever its length. Reached only when BOTH sides were hashed — since MA4.4 the
        /// relink hashes the chosen file itself, off the main actor, when the record has a digest.
        case differentSource
        /// The song is playing: the relinked clip's lane was never preloaded, and its next onset
        /// would attach a node mid-song — an attach pauses the engine (B2b review M3).
        case songPlaying

        /// The words the browser shows.
        public var userMessage: String {
            switch self {
            case .noAudioClip:
                return "That clip can't be relinked."
            case .fileGone:
                return "That file is no longer in the library."
            case .unreadable:
                return "That file isn't audio this app can read."
            case .differentLength(let expected, let found):
                return String(format: "That file is %.1f s long and the clip's file was %.1f s. "
                              + "Relink only to the same length — Place a different sound as a new part.",
                              found, expected)
            case .differentSource:
                return "That file's content differs from the clip's source. "
                    + "Place a different sound as a new part."
            case .songPlaying:
                return "Stop the song to relink a file."
            }
        }
    }

    /// Two lengths compatible with one source — the same expected length, never the same
    /// recording (see the header). The rule has ONE definition since MA4.1,
    /// `MediaAssetRecord.compatibleDuration` (50 ms or 1 % of the longer length); this asks it
    /// so the relink and the durable record can never disagree (#416).
    public static func sameLength(_ a: Double, _ b: Double) -> Bool {
        MediaAssetRecord.compatibleDuration(a, b)
    }

    /// The pure decision: the length the clip will record, or why not.
    public static func decide(_ clip: Clip, measuredSeconds: Double?) -> Result<Double, Refusal> {
        guard clip.kind == .audio else { return .failure(.noAudioClip) }
        guard let found = measuredSeconds, found.isFinite, found > 0 else {
            return .failure(.unreadable)
        }
        if let expected = clip.nativeDurationSeconds, expected.isFinite, expected > 0,
           !sameLength(expected, found) {
            return .failure(.differentLength(expected: expected, found: found))
        }
        return .success(found)
    }

    /// MA4.5 — what the clip's durable record says about the chosen file, or nil when it has
    /// nothing against it. The record REFUTES only; it never makes a file "the same" (founder
    /// 2026-09-26: a compatible length is not identity) — the same-length rule above still runs.
    ///
    /// `contentDigest` is the chosen file's digest when the relink computed one (`perform` does
    /// so only when the record has a digest to compare), else nil.
    public static func recordRefusal(_ record: MediaAssetRecord,
                                     measurement: AudioImport.Measurement,
                                     contentDigest: String?) -> Refusal? {
        let candidate = MediaAssetRecord.Evidence(byteSize: 0,
                                                  sampleRate: measurement.sampleRate,
                                                  frameCount: measurement.frameCount,
                                                  channelCount: measurement.channelCount,
                                                  contentDigest: contentDigest)
        switch record.match(candidate) {
        case .differentContent:
            return .differentSource
        case .differentDuration:
            return .differentLength(expected: record.evidence.durationSeconds,
                                    found: candidate.durationSeconds)
        case .sameContent, .compatibleDuration, .unmeasured:
            return nil
        }
    }

    /// Whether a relink of `clip` needs the chosen file's digest: only when its record, held by
    /// this registry, carries a SHA-256 digest to compare. Pure; the answer decides whether
    /// `perform` hashes at all.
    @MainActor
    public static func needsContentProof(_ clip: Clip, assets: MediaAssetStore?) -> Bool {
        guard let assets, let record = clip.mediaAssetID.flatMap({ assets.record(id: $0) }),
              let digest = record.evidence.contentDigest else { return false }
        return MediaContentDigest.isEvidence(digest)
    }

    /// What the clip links after a relink to `asset` — steps A, C and D of the header, in order.
    /// `linked` is the clip's own record when this registry holds it (already checked by
    /// `recordRefusal`); `candidateDigest` is the chosen file's digest when one was computed.
    /// Step D registers a new record for the chosen file (it describes that file, whatever the
    /// relink's Undo later does with the clip).
    @MainActor
    static func identity(for clip: Clip, linked: MediaAssetRecord?, to asset: MediaAsset,
                         measurement: AudioImport.Measurement, candidateDigest: String?,
                         assets: MediaAssetStore) -> MediaAssetStore.RelinkIdentity {
        let chosen = MediaAssetRecord.Evidence(byteSize: asset.byteSize,
                                               sampleRate: measurement.sampleRate,
                                               frameCount: measurement.frameCount,
                                               channelCount: measurement.channelCount,
                                               contentDigest: candidateDigest)
        let own = assets.record(boundTo: asset.key).flatMap { $0.isContradicted(by: chosen) ? nil : $0 }
        if let own, let candidateDigest, own.evidence.contentDigest == nil {
            assets.learnDigest(id: own.id, digest: candidateDigest)
        }
        // A — the same bytes, proven.
        if let linked, linked.evidence.contentDigest != nil, linked.match(chosen) == .sameContent {
            if let own, own.id != linked.id { return .adopt(own.id) }
            let playedName = clip.mediaRef.map { URL(fileURLWithPath: $0).lastPathComponent }
            if linked.fileName == playedName, linked.fileName != asset.key.fileName {
                return .move(MediaAssetStore.Rebinding(store: assets, recordID: linked.id,
                                                       fileName: asset.key.fileName))
            }
            return .adopt(linked.id)
        }
        // C — the chosen file's own identity.
        if let own { return .adopt(own.id) }
        // D — nothing proves the source: the chosen file gets its own identity.
        var created = AudioImport.assetRecord(managed: asset.url, originalName: asset.key.fileName,
                                              measurement: measurement, byteSize: asset.byteSize,
                                              importedAt: Date())
        created.evidence.contentDigest = candidateDigest
        return assets.register(created) ? .adopt(created.id) : .release
    }

    /// Relink `clipID` to `asset`, through the song's one undoable writer. `measure` and `fileExists` are
    /// injected so the blocking bundle can drive the whole path on paths that exist only as
    /// strings; production passes the real ones (`MediaBrowserView`).
    ///
    /// MA4.5/MA4.4 — `assets` (REQUIRED, #431; nil = no registry, the link is released) and
    /// `candidateDigest` (REQUIRED; the chosen file's digest, nil when none was computed): when
    /// the clip links a record this registry holds, the record is checked against the file
    /// (`recordRefusal`); then `identity(…)` decides the link — see the header. Without a digest
    /// nothing is proven, so a shared record never moves. One Undo restores clip and link (and
    /// the binding, when one moved).
    @MainActor
    public static func relink(_ clipID: UUID,
                              to asset: MediaAsset,
                              clipStore: ClipStore,
                              timeline: TimelineStore,
                              assets: MediaAssetStore?,
                              candidateDigest: String?,
                              fileExists: (String) -> Bool,
                              measure: (URL) -> AudioImport.Measurement?) -> Result<Double, Refusal> {
        guard let clip = clipStore.clip(id: clipID) else { return .failure(.noAudioClip) }
        guard clip.kind == .audio else { return .failure(.noAudioClip) }
        // The list is a snapshot: the file must still be there before anything is measured.
        guard fileExists(asset.url.path) else { return .failure(.fileGone) }
        let measurement = measure(asset.url)
        let decision = decide(clip, measuredSeconds: measurement?.durationSeconds)
        guard case .success(let seconds) = decision else { return decision }
        var identity = MediaAssetStore.RelinkIdentity.release
        if let assets, let measurement {
            let linked = clip.mediaAssetID.flatMap { assets.record(id: $0) }
                .flatMap { $0.kind == asset.key.kind ? $0 : nil }
            if let linked,
               let refusal = recordRefusal(linked, measurement: measurement, contentDigest: candidateDigest) {
                return .failure(refusal)
            }
            identity = Self.identity(for: clip, linked: linked, to: asset, measurement: measurement,
                                     candidateDigest: candidateDigest, assets: assets)
        }
        guard timeline.relinkClipSource(clipID: clipID, mediaRef: asset.url.path,
                                        nativeDurationSeconds: seconds, identity: identity,
                                        clips: clipStore) else {
            return .failure(.noAudioClip)
        }
        return .success(seconds)
    }

    /// The relink with its digest step, every impure part injected: when `needsContentProof`, the
    /// chosen file is checked for length FIRST (a file that fails it is never hashed), then
    /// hashed off the main actor by `hash`; a hash that fails or is cancelled refuses the relink
    /// as unreadable — the file could not be read to the end, so nothing is proven or written.
    /// `isSongPlaying` is asked before and again after the hash: no relink under a playing song.
    @MainActor
    public static func relinkProvingContent(_ clipID: UUID, to asset: MediaAsset,
                                            clipStore: ClipStore, timeline: TimelineStore,
                                            assets: MediaAssetStore,
                                            isSongPlaying: () -> Bool,
                                            fileExists: (String) -> Bool,
                                            measure: (URL) -> AudioImport.Measurement?,
                                            hash: @escaping @Sendable (URL) throws -> String) async
        -> Result<Double, Refusal> {
        guard !isSongPlaying() else { return .failure(.songPlaying) }
        var candidateDigest: String?
        if let clip = clipStore.clip(id: clipID), needsContentProof(clip, assets: assets) {
            guard fileExists(asset.url.path) else { return .failure(.fileGone) }
            let precheck = decide(clip, measuredSeconds: measure(asset.url)?.durationSeconds)
            guard case .success = precheck else { return precheck }
            guard let digest = await MediaContentDigest.compute(asset.url, hash: hash) else {
                return .failure(.unreadable)
            }
            candidateDigest = digest
            // The hash took time: the song may have started meanwhile (M3 holds for the write).
            guard !isSongPlaying() else { return .failure(.songPlaying) }
        }
        return relink(clipID, to: asset, clipStore: clipStore, timeline: timeline, assets: assets,
                      candidateDigest: candidateDigest, fileExists: fileExists, measure: measure)
    }

    #if canImport(AVFoundation)

    /// The production entry point — the browser's Relink: the real existence check, the
    /// import's own measurement (one header read of the chosen file) and, only when the clip's
    /// record has a digest to compare, CryptoKit's streamed SHA-256 off the main actor.
    @MainActor
    public static func perform(_ clipID: UUID, to asset: MediaAsset,
                               clipStore: ClipStore, timeline: TimelineStore,
                               assets: MediaAssetStore,
                               isSongPlaying: () -> Bool) async -> Result<Double, Refusal> {
        #if canImport(CryptoKit)
        let hash: @Sendable (URL) throws -> String = { try MediaContentDigest.sha256(fileAt: $0) }
        #else
        let hash: @Sendable (URL) throws -> String = { _ in throw CocoaError(.featureUnsupported) }
        #endif
        return await relinkProvingContent(clipID, to: asset, clipStore: clipStore, timeline: timeline,
                                          assets: assets, isSongPlaying: isSongPlaying,
                                          fileExists: { FileManager.default.fileExists(atPath: $0) },
                                          measure: AudioImport.measureWithAVFoundation, hash: hash)
    }

    #endif
}
