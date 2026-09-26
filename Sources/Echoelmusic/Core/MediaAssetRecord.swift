// MediaAssetRecord.swift
// Echoel — the DURABLE identity of one media file (MA4.1; founder media decision 2026-09-26:
// "MediaAsset = durable media/source identity · Clip = creative use/reference · TimelineRegion =
// placement · BrowserItem = lightweight projection · Derivative = waveform/thumbnail/proxy/analysis").
// Plan: `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md` §MA4.
//
// ⚠️ TWO NAMES FOR TWO THINGS, AND THE MAPPING IS STATED ONCE HERE. The founder's "MediaAsset" is
// THIS type. The shipped `MediaAsset` (`Core/MediaAsset.swift`) is the founder's "BrowserItem": a
// row the directory listing computes when the browser looks, never stored. It keeps its name in
// this slice because a rename moves every reference to it, guard needles included (measure:
// `git grep -wn MediaAsset -- Sources Tests | wc -l`); the rename is its own mechanical slice,
// not a side effect of this one.
//
// ⭐ WHAT A RECORD HOLDS, AND WHAT IT DELIBERATELY DOES NOT.
// · A stable `id` that no relink, rebind or rename changes — the identity a Clip points at.
// · The BINDING: the file's name inside its kind's managed home (`MediaAsset.Kind.home`). A name,
//   not an absolute path: the App Group container's path changes across updates and device
//   migrations, and the resolver already re-roots by file name (H6).
// · PROVENANCE: the name the file had when it was picked, and when it was imported.
// · EVIDENCE: what was measured about the bytes — size, sample rate, frames, channels, and a
//   content digest once one has been computed (nil until then; computing it is expensive and
//   happens off the main actor in its own slice).
// · NOT availability — "is the file there" is DERIVED each time it is asked, never stored, so a
//   record cannot claim a file that was deleted behind its back.
// · NOT placement, tempo, automation or device state — those belong to the Clip and the Region.
//   A record describes the SOURCE, never a use of it.
//
// ⭐ THE ONE LENGTH RULE LIVES HERE (#416). `compatibleDuration` is the provisional compatibility
// guard a relink applies; `MediaRelink.sameLength` asks it. ⚠️ A COMPATIBLE DURATION IS NOT MEDIA
// IDENTITY: two different recordings of the same length pass (two 4-bar loops at one tempo are
// both 8 s). Only a matching content digest says "same content", and `match` keeps the two
// verdicts apart so no caller can read one as the other.
//
// Foundation-only and pure: no store, no file access, no clock. Constructed nowhere in the app
// yet — the registry, the Clip link and the import write are the next slices.

import Foundation

/// The durable identity of one managed media file.
public struct MediaAssetRecord: Codable, Sendable, Equatable, Identifiable {

    public var id: UUID
    /// `MediaAsset.Kind.rawValue`, stored raw so a record of a kind a later build removes still
    /// decodes instead of taking its neighbours down with it.
    public var kindRaw: String
    /// The file's name inside the kind's managed home — the current binding.
    public var fileName: String
    /// The file name the person picked, before the library made it unique. Provenance only.
    public var originalName: String
    public var importedAt: Date
    public var evidence: Evidence

    public init(id: UUID = UUID(), kind: MediaAsset.Kind, fileName: String,
                originalName: String, importedAt: Date, evidence: Evidence) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.fileName = fileName
        self.originalName = originalName
        self.importedAt = importedAt
        self.evidence = evidence
    }

    /// nil for a kind this build does not know.
    public var kind: MediaAsset.Kind? { MediaAsset.Kind(rawValue: kindRaw) }

    /// The key the browser's listing and every stored reference resolve to — nil for an unknown
    /// kind, which no listing can show.
    public var key: MediaAsset.Key? {
        kind.map { MediaAsset.Key(kind: $0, fileName: fileName) }
    }

    // MARK: - Evidence

    /// What was measured about the bytes of the file.
    public struct Evidence: Codable, Sendable, Equatable {
        public var byteSize: Int64
        public var sampleRate: Double
        public var frameCount: Int64
        public var channelCount: Int
        /// `"sha256:<hex>"` once computed; nil until then. The algorithm is in the value so a
        /// later build can change it without misreading an old record.
        public var contentDigest: String?

        public init(byteSize: Int64, sampleRate: Double, frameCount: Int64, channelCount: Int,
                    contentDigest: String? = nil) {
            self.byteSize = Swift.max(0, byteSize)
            self.sampleRate = sampleRate
            self.frameCount = Swift.max(0, frameCount)
            self.channelCount = Swift.max(0, channelCount)
            self.contentDigest = contentDigest
        }

        /// Seconds of audio, computed from the frames and the rate it came from so the three
        /// can never disagree. 0 for anything unmeasurable, never NaN.
        public var durationSeconds: Double {
            guard sampleRate.isFinite, sampleRate > 0, frameCount > 0 else { return 0 }
            return Double(frameCount) / sampleRate
        }

        /// The digest split into its algorithm and its lower-cased value, or nil when either half
        /// is empty. Two digests are comparable only under the SAME algorithm (see `match`).
        var comparableDigest: (algorithm: String, value: String)? {
            guard let digest = contentDigest,
                  let colon = digest.firstIndex(of: ":") else { return nil }
            let algorithm = digest[..<colon].lowercased()
            let value = digest[digest.index(after: colon)...].lowercased()
            guard !algorithm.isEmpty, !value.isEmpty else { return nil }
            return (algorithm, value)
        }
    }

    // MARK: - Matching a candidate file

    /// What a candidate file's evidence says about this record's source.
    public enum Match: Equatable, Sendable {
        /// Both digests are known and equal: the same bytes.
        case sameContent
        /// Both digests are known and differ: another file, whatever its length.
        case differentContent
        /// No digest comparison is possible, and the lengths are compatible. Provisional — it
        /// is NOT identity (see the header).
        case compatibleDuration
        /// No digest comparison is possible, and the lengths are not compatible.
        case differentDuration
        /// Either side has no measurable length and no digest to compare.
        case unmeasured
    }

    /// Two lengths that could belong to one source: a re-export moves the end by a few
    /// milliseconds, so the tolerance is 50 ms or 1 % of the longer length, whichever is larger.
    /// The one definition of that rule; `MediaRelink.sameLength` asks it.
    public static func compatibleDuration(_ a: Double, _ b: Double) -> Bool {
        guard a.isFinite, b.isFinite else { return false }
        return abs(a - b) <= Swift.max(0.05, 0.01 * Swift.max(a, b))
    }

    /// Compare a candidate's evidence with this record's. The digest decides when both sides
    /// have one under the SAME algorithm; only then is "same content" possible. Digests of two
    /// different algorithms say nothing about each other, so they fall through to the length
    /// rule — a compatibility verdict, never an identity one.
    ///
    /// ⚠️ Equal digests win over the lengths: the digest is the authority, so a record whose
    /// measured length disagrees with an identical-bytes candidate is not flagged here.
    public func match(_ candidate: Evidence) -> Match {
        if let mine = evidence.comparableDigest, let theirs = candidate.comparableDigest,
           mine.algorithm == theirs.algorithm {
            return mine.value == theirs.value ? .sameContent : .differentContent
        }
        let expected = evidence.durationSeconds
        let found = candidate.durationSeconds
        guard expected > 0, found > 0 else { return .unmeasured }
        return Self.compatibleDuration(expected, found) ? .compatibleDuration : .differentDuration
    }

    // MARK: - Codable (lossy per field, required identity)

    private enum CodingKeys: String, CodingKey {
        case id, kindRaw, fileName, originalName, importedAt, evidence
    }

    /// A record without an id or a binding is nothing and fails to decode; every other field
    /// falls back to a neutral value, so one damaged field never loses the identity.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        fileName = try c.decode(String.self, forKey: .fileName)
        kindRaw = (try? c.decode(String.self, forKey: .kindRaw)) ?? MediaAsset.Kind.audio.rawValue
        originalName = (try? c.decode(String.self, forKey: .originalName)) ?? fileName
        importedAt = (try? c.decode(Date.self, forKey: .importedAt)) ?? Date(timeIntervalSince1970: 0)
        evidence = (try? c.decode(Evidence.self, forKey: .evidence))
            ?? Evidence(byteSize: 0, sampleRate: 0, frameCount: 0, channelCount: 0)
    }
}
