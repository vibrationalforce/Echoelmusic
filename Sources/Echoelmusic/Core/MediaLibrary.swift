// MediaLibrary.swift
// Echoel — durable home for IMPORTED media files (audio today; video next) inside
// the App Group container, so a timeline region's `mediaRef` survives relaunch and
// is reachable from the AUv3/widget processes (the same container AppGroupStore
// uses for JSON). Copying the picked file in is the ONE impure step of the import
// path; the placement math (AudioClipFactory + TimelineDocument.nextStartTick)
// stays pure and unit-tested. No logger dependency — failures throw so the calling
// surface decides how loud to be.

import Foundation

public enum MediaLibrary {

    public enum MediaImportError: Error, Equatable {
        case noContainer   // couldn't resolve any writable directory
        case copyFailed    // the file copy itself failed (permissions / disk)
    }

    /// App Group identifier — matches the `group.com.echoelmusic` entitlement
    /// (same value AppGroupStore uses; kept local so this helper stays standalone).
    static let appGroupID = "group.com.echoelmusic"

    /// Resolve (creating if needed) a media subdirectory. Prefers the App Group
    /// container; falls back to Application Support (unit tests / Linux CI) then
    /// the temporary dir, mirroring AppGroupStore so media and JSON co-locate.
    static func directory(_ sub: String) -> URL? {
        let fm = FileManager.default
        let base: URL
        if let group = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            base = group
        } else if let support = try? fm.url(for: .applicationSupportDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil, create: true) {
            base = support
        } else {
            base = fm.temporaryDirectory
        }
        let dir = base.appendingPathComponent(sub, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
            catch { return nil }
        }
        return dir
    }

    /// Copy a user-picked audio file (already security-scope-accessed by the
    /// caller) into `Media/Audio` under a fresh unique name, preserving its
    /// extension. Returns the destination URL — its absolute path becomes the
    /// region's `mediaRef`. The caller owns start/stopAccessingSecurityScopedResource.
    public static func importAudio(from source: URL) throws -> URL {
        try copyIn(source, subdirectory: "Media/Audio", fallbackExt: "wav")
    }

    /// Copy a user-picked VIDEO file into `Media/Video` (same contract as
    /// importAudio). Its absolute path becomes the video region's `mediaRef`.
    public static func importVideo(from source: URL) throws -> URL {
        try copyIn(source, subdirectory: "Media/Video", fallbackExt: "mov")
    }

    /// Copy a user-picked IMAGE into `Media/Image` (V3 — stills land on video lanes
    /// as fixed-length clips; same contract as importVideo).
    public static func importImage(from source: URL) throws -> URL {
        try copyIn(source, subdirectory: "Media/Image", fallbackExt: "jpg")
    }

    /// Every file in the Audio home, as assets in the browser's order — nil when the home
    /// cannot be read at all, which is a different answer from an empty library and is shown
    /// as one (a silent `[]` would read as "you have imported nothing").
    ///
    /// ⚠️ ONE directory call, sizes included (`includingPropertiesForKeys`), no decoding: the
    /// list is what a person scrolls, and durations belong to the rows they reach (MA3). It is
    /// still disk I/O, so the browser runs it DETACHED — `MediaBrowserView`, never a `body`.
    /// The one other caller is `existingAudio(matching:)` (MA2), on the import path, which is
    /// already main-actor file I/O (it copies the picked file) and runs once per import.
    /// Hidden files and anything that is not a regular file (a directory someone made, a
    /// symlink) are not assets.
    public static func listAudio() -> [MediaAsset]? {
        guard let dir = directory(MediaAsset.Kind.audio.home) else { return nil }
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return nil
        }
        let assets: [MediaAsset] = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { return nil }
            return MediaAsset(kind: .audio, fileName: url.lastPathComponent, url: url,
                              byteSize: Int64(values.fileSize ?? 0))
        }
        return MediaAsset.sorted(assets)
    }

    // MARK: - MA2: the same bytes are the same sound

    /// Every managed audio file whose CONTENT equals `source`, in the browser's order — empty
    /// when there is none, when the home cannot be read, or when `source` has no readable size.
    ///
    /// ⚠️ IT RUNS ON THE MAIN ACTOR, SO ITS COST IS CAPPED, NOT ARGUED AWAY (review of
    /// 7b691faf8). The copy it can replace is NOT a full read: `FileManager.copyItem` clones on
    /// APFS, so a same-volume pick used to cost about nothing — a byte compare of a long file
    /// would be a new, visible freeze. So: only a file of at most `dedupByteCeiling` bytes is
    /// compared (a larger one takes the copy path exactly as before MA2 — de-dup simply does not
    /// apply to it), only against library files of the EXACT same size, and every compare
    /// reads a small head first, so two different same-length loops part after 64 KB, not after
    /// 2 MB. Worst case per candidate: 2 × the ceiling. Moving the whole import off-main is its
    /// own slice (plan MA2). ⚠️ It never writes, never deletes, and never decodes.
    public static func existingAudio(matching source: URL) -> [MediaAsset] {
        guard let assets = listAudio() else { return [] }
        return identicalAudio(to: source, among: assets)
    }

    /// The pure-over-files half of `existingAudio`: size first (one stat), bytes second, and
    /// only for the survivors of the size filter.
    static func identicalAudio(to source: URL, among assets: [MediaAsset],
                               chunkSize: Int = 1 << 20,
                               byteCeiling: Int = MediaLibrary.dedupByteCeiling) -> [MediaAsset] {
        guard let size = (try? source.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
              size > 0, size <= byteCeiling else { return [] }
        return assets.filter { $0.byteSize == Int64(size) && sameBytes(source, $0.url, chunkSize: chunkSize) }
    }

    /// The largest file the import compares on the main actor: 32 MiB, about three minutes of
    /// 16-bit 44.1 kHz stereo — a loop or a stem, the thing a person imports twice. A larger
    /// file is copied (cloned) as it always was.
    static let dedupByteCeiling = 32 << 20

    /// The first read of every compare: small, so files that differ early part cheaply.
    static let headProbeBytes = 64 << 10

    /// Byte-for-byte equality, read in bounded chunks so a long file is never held whole.
    /// A file that cannot be opened or read is never "the same" — the import then copies,
    /// which is exactly what it did before MA2.
    static func sameBytes(_ a: URL, _ b: URL, chunkSize: Int = 1 << 20) -> Bool {
        guard chunkSize > 0,
              let first = try? FileHandle(forReadingFrom: a),
              let second = try? FileHandle(forReadingFrom: b) else { return false }
        defer {
            try? first.close()
            try? second.close()
        }
        var readSize = min(chunkSize, headProbeBytes)
        while true {
            let left: Data
            let right: Data
            do {
                left = try first.read(upToCount: readSize) ?? Data()
                right = try second.read(upToCount: readSize) ?? Data()
            } catch {
                return false
            }
            guard left == right else { return false }
            if left.isEmpty { return true }
            readSize = chunkSize
        }
    }

    /// Resolve a clip's `mediaRef` to an EXISTING file URL — nil for empty refs or
    /// truly vanished files. THE single resolver for every surface that turns a
    /// region into playable media (timeline audition, audio lanes, the Video
    /// Monitor; ⛔ "ArrangeTimelineView" stood in this list until #1107 — deleted by
    /// #121 Slice 4). Handles all conventions:
    /// 1. an absolute path that still exists (timeline imports, pre-update),
    /// 2. H6 re-rooting: an absolute path whose CONTAINER PREFIX died — an app
    ///    update/device migration changes the app-group container UUID, but the
    ///    file itself still sits under the same media subdirectory in the NEW
    ///    container. Re-resolve by file name against every media home, FIRST match
    ///    wins in the Audio→Video→Image order. (Import names are readable + only
    ///    per-directory-unique since O11, no longer globally-unique UUIDs; a full
    ///    name+extension clash across two homes is effectively unreachable because
    ///    the audio/video/image picker extension sets are disjoint — but do not
    ///    assume global filename uniqueness here.) Without this re-root, every
    ///    imported clip silently lost its audio/video on the first app update
    ///    (audit CRITICAL H6).
    /// 3. a bare file name against Documents/Videos. (Its writer was the visual recorder,
    ///    removed with video capture in #1304; the probe stays because a document persisted
    ///    by an older build can still carry such a ref — #95/#527.)
    /// Side effect: probing creates the media home directories if missing (the
    /// same dirs import would create) — not a pure function by design.
    public static func resolveRef(_ ref: String?) -> URL? {
        guard let ref, !ref.isEmpty else { return nil }
        let fm = FileManager.default
        let url = URL(fileURLWithPath: ref)
        if fm.fileExists(atPath: url.path) { return url }
        let name = url.lastPathComponent
        guard !name.isEmpty else { return nil }
        for sub in ["Media/Audio", "Media/Video", "Media/Image"] {
            if let dir = directory(sub) {
                let candidate = dir.appendingPathComponent(name, isDirectory: false)
                if fm.fileExists(atPath: candidate.path) { return candidate }
            }
        }
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let candidate = docs.appendingPathComponent("Videos", isDirectory: true)
                .appendingPathComponent(name, isDirectory: false)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    /// Shared copy: resolve the media subdir, pick a READABLE collision-free name
    /// (O11 — the founder saw a raw UUID where a sample name belonged, because the
    /// old `<UUID>.<ext>` filename is what `BeatPlayer.sampleRefDisplayName` shows
    /// for an imported ref), copy the file in. Throws on no container / copy fail.
    private static func copyIn(_ source: URL, subdirectory: String, fallbackExt: String) throws -> URL {
        guard let dir = directory(subdirectory) else { throw MediaImportError.noContainer }
        let ext = source.pathExtension.isEmpty ? fallbackExt : source.pathExtension
        let base = source.deletingPathExtension().lastPathComponent
        let name = uniqueName(base: base, ext: ext, taken: { candidate in
            FileManager.default.fileExists(atPath: dir.appendingPathComponent(candidate).path)
        })
        let dest = dir.appendingPathComponent(name, isDirectory: false)
        do {
            try FileManager.default.copyItem(at: source, to: dest)
        } catch {
            throw MediaImportError.copyFailed
        }
        return dest
    }

    /// A readable, filesystem-safe, collision-free filename for an imported media
    /// file (O11). Sanitizes the source base name (drops path separators + reserved
    /// characters, trims, caps length), keeps the extension, and disambiguates with
    /// a numeric suffix ONLY on an actual clash — so `sampleRefDisplayName` shows
    /// "MyLoop" (or "MyLoop-1") instead of a UUID. An empty/garbage base falls back
    /// to "sample". Pure (the filesystem check is injected) → unit-tested.
    static func uniqueName(base: String, ext: String, taken: (String) -> Bool) -> String {
        let cleaned = base
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = cleaned.isEmpty ? "sample" : String(cleaned.prefix(60))
        var candidate = "\(safe).\(ext)"
        var n = 1
        while taken(candidate) {
            candidate = "\(safe)-\(n).\(ext)"
            n += 1
        }
        return candidate
    }
}
