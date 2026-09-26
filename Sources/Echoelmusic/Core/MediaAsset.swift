// MediaAsset.swift
// Echoel — the identity of a file in the managed media library (Phase 3, founder order
// 2026-09-25: "MediaAsset + lazy Browser"). Pure and Foundation-only; the one impure step,
// listing the directory, is `MediaLibrary.listAudio()`.
//
// ⭐ THE IDENTITY IS (home, file name) — THE KEY THE RESOLVER ALREADY HONOURS. It is not the
// absolute path: an app update or a device migration changes the App Group container's UUID,
// and `MediaLibrary.resolveRef` survives that by re-rooting a dead path BY FILE NAME against
// the media homes (H6). A key built from the absolute path would call the same file two assets
// after every update. Nor is it a content hash: hashing reads the whole file, and nothing here
// may do that on the main actor. De-duplication of identical CONTENT is its own slice (MA2,
// `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md`), done off-main.
//
// ⭐ THIS TYPE IS THE BROWSER'S ROW, NOT THE DURABLE IDENTITY (founder media decision 2026-09-26).
// The directory is the truth for "which files exist" and `ClipStore` for "who uses them"; a row
// is the JOIN of the two, computed when the browser looks and never stored — the founder's
// "BrowserItem". The durable identity (stable id, binding, provenance, evidence) is
// `MediaAssetRecord`, held by the ONE registry `MediaAssetStore` (MA4.2). ⛔ Until MA4.2 this
// paragraph said "there is no index file, and that is the decision"; the MA1 decision behind it
// is superseded in `decisions.csv`. The row's key is still built here, and the record's `key`
// is built from it, so "when are two references the same file" keeps ONE answer.
//
// ⚠️ ONLY THE AUDIO HOME IS AN ASSET HOME. `MediaLibrary` also creates `Media/Video` and
// `Media/Image`, but nothing in this build plays either since video was withdrawn (#1304). A
// kind case for them would let a surface list files the app cannot use — a capability claim
// with no consumer. They join `Kind` together with their consumer.
//
// ⚠️ `Clip` STAYS THE CREATIVE IDENTITY. This type does not replace `Clip.id`, does not move
// `mediaRef`, and changes no persisted format: a clip still points at its file by path, and
// `key(forRef:)` reads that path. What is new is only that the same file is now ONE thing
// wherever it is referenced.

import Foundation

/// One file in the managed media library, and the key every stored reference to it resolves to.
public struct MediaAsset: Sendable, Equatable, Identifiable {

    /// The media homes that are asset homes. Audio only — see the header.
    public enum Kind: String, Sendable, CaseIterable {
        case audio

        /// The home directory under the container, exactly as `MediaLibrary` writes it.
        public var home: String {
            switch self {
            case .audio: return "Media/Audio"
            }
        }
    }

    /// What makes two references the same asset.
    public struct Key: Hashable, Sendable {
        public var kind: Kind
        public var fileName: String

        public init(kind: Kind, fileName: String) {
            self.kind = kind
            self.fileName = fileName
        }
    }

    public var key: Key
    /// Where the file is NOW, in this container. Never persisted — it is the listing's answer.
    public var url: URL
    public var byteSize: Int64

    public var id: Key { key }

    /// The file name without its extension — what the import already named the clip.
    /// String work, not `URL(fileURLWithPath:)`: that initialiser stats the path to decide
    /// whether it is a directory, and this is read per row in a `body` (review of ae3faa1c5).
    public var displayName: String {
        let name = (key.fileName as NSString).deletingPathExtension
        return name.isEmpty ? key.fileName : name
    }

    public init(kind: Kind, fileName: String, url: URL, byteSize: Int64) {
        self.key = Key(kind: kind, fileName: fileName)
        self.url = url
        self.byteSize = max(0, byteSize)
    }

    // MARK: - Identity from a stored reference

    /// The asset a stored `mediaRef` names, or nil when it names no asset.
    ///
    /// Reads the TAIL of the path — `…/Media/Audio/<name>` — and nothing before it, so a path
    /// written under an older container resolves to the same key as today's (H6). Pure string
    /// work on purpose: `URL(fileURLWithPath:)` would resolve a bare name against the process's
    /// working directory, which is a fact about the process, not about the reference.
    ///
    /// nil for: an empty or missing ref, a bare file name (it carries no home), a path whose
    /// last directories are not an asset home (bundle resources, the legacy `Documents/Videos`),
    /// and a path that ends in a separator.
    ///
    /// ⚠️ NARROWER THAN `MediaLibrary.resolveRef`, on purpose. The resolver also re-roots a BARE
    /// name, or a dead path under another home, by file name — so a legacy clip whose ref is
    /// just `Loop.wav` PLAYS `Media/Audio/Loop.wav` while this says it names no asset, and the
    /// browser then counts that file as unused. No writer in this build makes such a ref
    /// (`AudioImport` writes the managed absolute path); only an old document can carry one.
    /// Guessing the home from a name alone would be the wider error: it would call two
    /// different files one asset the day a name repeats across homes.
    public static func key(forRef ref: String?) -> Key? {
        guard let ref, !ref.isEmpty, !ref.hasSuffix("/") else { return nil }
        let parts = ref.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 3 else { return nil }
        let name = parts[parts.count - 1]
        let home = parts[parts.count - 3] + "/" + parts[parts.count - 2]
        guard let kind = Kind.allCases.first(where: { $0.home == home }) else { return nil }
        return Key(kind: kind, fileName: name)
    }

    // MARK: - Order

    /// The browser's order: by name as a person reads it (case-insensitive, locale-aware,
    /// "Take 2" before "Take 10"), the file name breaking a tie so the order is total.
    public static func sorted(_ assets: [MediaAsset]) -> [MediaAsset] {
        assets.sorted { a, b in
            let order = a.displayName.localizedStandardCompare(b.displayName)
            if order != .orderedSame { return order == .orderedAscending }
            return a.key.fileName < b.key.fileName
        }
    }

    // MARK: - Filter

    /// The assets whose shown name contains `query` (B1, the browser's name filter): case- and
    /// diacritic-insensitive and locale-aware, as the Files app searches, over the NAME the row
    /// shows — never the extension, which the row does not show. A query of only spaces keeps
    /// every asset, and the order is kept (the caller's, `sorted`). A projection of a listing
    /// already in memory: no disk, and nothing to do while the browser is closed.
    public static func matching(_ assets: [MediaAsset], query: String) -> [MediaAsset] {
        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return assets }
        return assets.filter { $0.displayName.localizedStandardContains(wanted) }
    }

    // MARK: - Who uses it

    /// Where an asset is used: the clips that carry it (in slot order) and how many parts of
    /// the song play one of those clips — counted on the PLAYABLE audio lanes only
    /// (`audioLaneIDs`, the set `AudioLanePlayer` walks), so a part whose lane is gone or is a
    /// bio lane is not a use (review of ae3faa1c5).
    public struct Usage: Equatable, Sendable {
        public var clipIDs: [UUID]
        public var partCount: Int

        public init(clipIDs: [UUID], partCount: Int) {
            self.clipIDs = clipIDs
            self.partCount = partCount
        }

        public static let unused = Usage(clipIDs: [], partCount: 0)
    }

    /// The usage of every asset key that at least one clip carries. A key absent from the
    /// result is carried by no clip. One pass over the clips and one over the regions, so the
    /// browser can ask it once per listing instead of once per row.
    ///
    /// ⚠️ ONLY AUDIO CLIPS COUNT. A MIDI clip has no `mediaRef` (its notes live in the clip),
    /// and any other kind with a stray ref would still not be played from this file by the
    /// audio lanes — counting it would say "in use" about a file nothing plays.
    public static func usage(clips: [Clip], document: TimelineDocument) -> [Key: Usage] {
        var clipKey: [UUID: Key] = [:]
        var result: [Key: Usage] = [:]
        for clip in clips where clip.kind == .audio {
            guard let key = key(forRef: clip.mediaRef) else { continue }
            clipKey[clip.id] = key
            result[key, default: .unused].clipIDs.append(clip.id)
        }
        let playable = Set(document.audioLaneIDs)
        for region in document.regions where playable.contains(region.laneID) {
            guard let key = clipKey[region.clipID] else { continue }
            result[key, default: .unused].partCount += 1
        }
        return result
    }

    // MARK: - Missing on this device (B2)

    /// An audio clip whose file this device cannot find. The creative structure SURVIVES — the
    /// clip keeps its id, name and settings, its parts stay where they are — only the sound is
    /// missing, so the name of the clip and of the file it expects is what the user needs to put
    /// it back (founder media law 2026-09-26: "availability becomes missing, relink stays
    /// possible").
    public struct Missing: Equatable, Identifiable, Sendable {
        public let clipID: UUID
        public let clipName: String
        /// The last path component of the stored ref — the file the clip expects to find.
        public let fileName: String
        /// Parts on the PLAYABLE audio lanes that play this clip (the `usage` count).
        public let partCount: Int
        public var id: UUID { clipID }
    }

    /// The audio clips that carry a file reference `resolves` cannot find, in slot order.
    ///
    /// ⚠️ `resolves` MUST BE THE PLAYING PATH'S OWN RESOLVER (`AudioLanePlayer.resolvedURL`,
    /// the #1439 law): a second opinion about which file a clip plays would be a second truth
    /// about what the user hears. The question is RESOLUTION, not decodability — a file that is
    /// there but will not decode is not "missing" (that stays a playback fact).
    /// A clip with no ref at all is not listed: it names no file to look for.
    public static func missing(clips: [Clip], document: TimelineDocument,
                               resolves: (UUID) -> Bool) -> [Missing] {
        let playable = Set(document.audioLaneIDs)
        var parts: [UUID: Int] = [:]
        for region in document.regions where playable.contains(region.laneID) {
            parts[region.clipID, default: 0] += 1
        }
        return clips.compactMap { clip in
            guard clip.kind == .audio, let ref = clip.mediaRef, !ref.isEmpty,
                  !resolves(clip.id) else { return nil }
            return Missing(clipID: clip.id, clipName: clip.name,
                           // String work, not `URL(fileURLWithPath:)`, which stats the path —
                           // this runs in the browser's body (review of `6bf47f8b9`, L1).
                           fileName: ref.split(separator: "/").last.map(String.init) ?? ref,
                           partCount: parts[clip.id] ?? 0)
        }
    }
}
