// MediaContentDigest.swift
// Echoel — the strong content evidence of a managed media file (MA4.4; founder decision
// 2026-09-26, "MA4.4 APPROVED WITH CRYPTOKIT"; plan `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md`).
//
// ⭐ PORTABLE PERSISTENCE. What is stored is text, never a CryptoKit type:
//
//     "sha256:" + 64 lower-case hex digits   (the 32-byte SHA-256 of the file's bytes)
//
// in `MediaAssetRecord.Evidence.contentDigest`. Any SHA-256 implementation on any platform
// produces the same string for the same bytes — CryptoKit is the implementation on Apple, not
// the format. `MediaAssetRecord.match` compares digests only under the SAME algorithm name.
//
// ⭐ WHAT IT PROVES AND WHAT DOES NOT. Equal digests = the same bytes: the one "same content"
// evidence this app has. A duration only says compatible or contradicted, never "same source";
// a file name, size or date is never identity evidence (founder 2026-09-26).
//
// ⚠️ STREAMING AND OFF THE MAIN ACTOR. The file is read in bounded chunks (`chunkSize`) into
// `SHA256.update`, with a cancellation check before every chunk — a large file is never held
// whole. `learn(recordID:from:into:hash:)` runs the hash in a detached task and writes the
// result back on the main actor; a cancelled caller cancels the hash.
//
// ⛔ WHEN A DIGEST IS COMPUTED — only where identity evidence is needed on ONE file: after a new
// managed import lands (the Workstation's post-import analysis) and when a relink must prove
// that a chosen file is its clip's source (`MediaRelink`). Never at launch, never as a library
// scan, never periodically, never because the browser opened. A legacy record without a digest
// stays readable and gains one only when such a workflow touches its file.

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// SHA-256 content evidence for a media file, in its portable persisted form.
public enum MediaContentDigest {

    /// The algorithm name written before the colon.
    public static let algorithm = "sha256"

    /// One read: 1 MiB. Bounded memory whatever the file's length.
    public static let chunkSize = 1 << 20

    /// The persisted form of a 32-byte digest, or nil for any other length.
    public static func evidence(digestBytes: [UInt8]) -> String? {
        guard digestBytes.count == 32 else { return nil }
        let hexDigits = Array("0123456789abcdef")
        var hex = ""
        hex.reserveCapacity(64)
        for byte in digestBytes {
            hex.append(hexDigits[Int(byte >> 4)])
            hex.append(hexDigits[Int(byte & 0x0f)])
        }
        return algorithm + ":" + hex
    }

    /// Whether `text` is a well-formed persisted SHA-256 digest: the algorithm name, a colon and
    /// 64 hex digits (either case — `MediaAssetRecord.match` lower-cases before comparing).
    public static func isEvidence(_ text: String) -> Bool {
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].lowercased() == algorithm, parts[1].count == 64 else {
            return false
        }
        return parts[1].allSatisfy(\.isHexDigit)
    }

    #if canImport(CryptoKit)

    /// Hash the chunks `readChunk` hands over until it returns nil or an empty chunk, checking
    /// `isCancelled` before every read. Pure over the reader, so the blocking bundle drives it
    /// with in-memory chunks and the known SHA-256 vectors.
    public static func sha256(readChunk: () throws -> Data?,
                              isCancelled: () -> Bool) throws -> String {
        var hasher = SHA256()
        while true {
            if isCancelled() { throw CancellationError() }
            guard let chunk = try readChunk(), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        guard let text = evidence(digestBytes: Array(hasher.finalize())) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return text
    }

    /// The file's digest, read in `chunkSize` chunks. Blocking I/O: call it off the main actor
    /// (`learn` does). Throws if the file cannot be opened or read, or the task is cancelled.
    public static func sha256(fileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try sha256(readChunk: { try handle.read(upToCount: chunkSize) },
                          isCancelled: { Task.isCancelled })
    }

    #endif

    /// Hash `url` off the main actor with `hash` and return the result, or nil when the hash
    /// failed or the caller was cancelled. Cancelling the caller cancels the detached hash.
    public static func compute(_ url: URL,
                               hash: @escaping @Sendable (URL) throws -> String) async -> String? {
        let work = Task.detached(priority: .utility) { () -> String? in
            guard let text = try? hash(url), isEvidence(text) else { return nil }
            return text
        }
        let result = await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
        return Task.isCancelled ? nil : result
    }

    /// Records whose digest is being computed right now — at most one hash per record.
    @MainActor private static var inFlight: Set<UUID> = []

    /// Give `recordID` its content digest, hashed from `url` off the main actor. Does nothing
    /// (false) when the record is gone, already carries a digest, or is already being hashed;
    /// the store refuses to overwrite a digest the record gained meanwhile.
    @MainActor
    @discardableResult
    public static func learn(recordID: UUID, from url: URL, into assets: MediaAssetStore,
                             hash: @escaping @Sendable (URL) throws -> String) async -> Bool {
        guard let record = assets.record(id: recordID), record.evidence.contentDigest == nil,
              !inFlight.contains(recordID) else { return false }
        inFlight.insert(recordID)
        defer { inFlight.remove(recordID) }
        guard let digest = await compute(url, hash: hash) else { return false }
        return assets.learnDigest(id: recordID, digest: digest)
    }
}
