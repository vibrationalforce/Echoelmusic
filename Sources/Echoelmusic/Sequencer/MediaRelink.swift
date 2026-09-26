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
// ⭐ MA4.5 — THE DURABLE RECORD FOLLOWS THE FILE, WITH ITS ID. When the clip links a record the
// registry holds, the record must not contradict the chosen file (`recordRefusal`: another length
// or, once both sides are hashed, another digest). Then `identity(…)` decides what the clip links,
// in this order (MA4.5 review, both MED):
// 1. the chosen file has its OWN record, not refuted by its measurement → the clip ADOPTS it. A
//    compatible length never overwrites a file's own identity, and the clip's former record stays
//    where it is (moving it would give the file two records, the newer carrying another file's
//    evidence);
// 2. else the clip's record still describes the missing file THIS clip played → it MOVES there
//    with its id — record id, clip id, region ids, tempo and automation all stay;
// 3. else the record has moved on (another project relinked it) → the link is RELEASED; taking the
//    record back would pull it away from a file another clip plays.
// The record only refutes; it never upgrades "same length" into "same recording". A record must
// never name a file its clip no longer plays.
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
        /// source, whatever its length (MA4.5). Reached only when BOTH sides were hashed — the
        /// relink itself never hashes on the tap.
        case differentSource

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
    /// `contentDigest` is the chosen file's digest when one is already known — the relink itself
    /// passes nil, because it never hashes on the tap (MA4.4 hashes off the main actor).
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

    /// What the clip links after a relink to `asset` — the three steps in the header, in order.
    /// `linked` is the clip's own record when this registry holds it (already checked by
    /// `recordRefusal`).
    @MainActor
    static func identity(for clip: Clip, linked: MediaAssetRecord?, to asset: MediaAsset,
                         measurement: AudioImport.Measurement,
                         assets: MediaAssetStore) -> MediaAssetStore.RelinkIdentity {
        let chosen = MediaAssetRecord.Evidence(byteSize: 0,
                                               sampleRate: measurement.sampleRate,
                                               frameCount: measurement.frameCount,
                                               channelCount: measurement.channelCount,
                                               contentDigest: nil)
        if let own = assets.record(boundTo: asset.key), !own.isContradicted(by: chosen) {
            return .adopt(own.id)
        }
        let playedName = clip.mediaRef.map { URL(fileURLWithPath: $0).lastPathComponent }
        if let linked, linked.fileName == playedName {
            return .move(MediaAssetStore.Rebinding(store: assets, recordID: linked.id,
                                                   fileName: asset.key.fileName))
        }
        return .release
    }

    /// Relink `clipID` to `asset`, through the song's one undoable writer. `measure` and `fileExists` are
    /// injected so the blocking bundle can drive the whole path on paths that exist only as
    /// strings; production passes the real ones (`MediaBrowserView`).
    ///
    /// MA4.5 — `assets` (REQUIRED, #431; nil = no registry, the link is released): when the clip
    /// links a record this registry holds, the record is checked against the file
    /// (`recordRefusal`); then `identity(…)` adopts the file's own record, moves the clip's
    /// record with its id, or releases the link. One Undo restores clip, link and binding. A clip
    /// with no link, or a link this registry does not hold (a project from another device),
    /// adopts the file's own record when it has one, else ends unlinked.
    @MainActor
    public static func relink(_ clipID: UUID,
                              to asset: MediaAsset,
                              clipStore: ClipStore,
                              timeline: TimelineStore,
                              assets: MediaAssetStore?,
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
               let refusal = recordRefusal(linked, measurement: measurement, contentDigest: nil) {
                return .failure(refusal)
            }
            identity = Self.identity(for: clip, linked: linked, to: asset, measurement: measurement,
                                     assets: assets)
        }
        guard timeline.relinkClipSource(clipID: clipID, mediaRef: asset.url.path,
                                        nativeDurationSeconds: seconds, identity: identity,
                                        clips: clipStore) else {
            return .failure(.noAudioClip)
        }
        return .success(seconds)
    }

    #if canImport(AVFoundation)

    /// The production entry point — the browser's Relink: the real existence check and the
    /// import's own measurement (one header read of the chosen file, on the tap).
    @MainActor
    public static func perform(_ clipID: UUID, to asset: MediaAsset,
                               clipStore: ClipStore, timeline: TimelineStore,
                               assets: MediaAssetStore) -> Result<Double, Refusal> {
        relink(clipID, to: asset, clipStore: clipStore, timeline: timeline, assets: assets,
               fileExists: { FileManager.default.fileExists(atPath: $0) },
               measure: AudioImport.measureWithAVFoundation)
    }

    #endif
}
