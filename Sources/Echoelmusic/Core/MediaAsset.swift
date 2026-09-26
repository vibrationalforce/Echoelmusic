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
// ⭐ THERE IS NO INDEX FILE, AND THAT IS THE DECISION, NOT AN OMISSION. The directory is the
// truth for "which files exist" and `ClipStore` is the truth for "who uses them"; an asset list
// is the JOIN of the two, computed when it is looked at. A stored registry would be a fifth
// persistence root (Ω49) that can disagree with both — a file deleted behind its back, a clip
// replaced by Open. Consequence, stated so nobody reads it as a gap to fill: an asset has no
// name, tag or rating of its own that could survive; its name is its file name.
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
    public var displayName: String {
        let name = URL(fileURLWithPath: key.fileName).deletingPathExtension().lastPathComponent
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

    // MARK: - Who uses it

    /// Where an asset is used: the clips that carry it (in slot order) and how many parts of
    /// the song play one of those clips.
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
    public static func usage(clips: [Clip], regions: [TimelineRegion]) -> [Key: Usage] {
        var clipKey: [UUID: Key] = [:]
        var result: [Key: Usage] = [:]
        for clip in clips where clip.kind == .audio {
            guard let key = key(forRef: clip.mediaRef) else { continue }
            clipKey[clip.id] = key
            result[key, default: .unused].clipIDs.append(clip.id)
        }
        for region in regions {
            guard let key = clipKey[region.clipID] else { continue }
            result[key, default: .unused].partCount += 1
        }
        return result
    }
}
