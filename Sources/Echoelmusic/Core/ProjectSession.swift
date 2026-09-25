//
//  ProjectSession.swift
//  Echoelmusic — Core (WA4-S2: the canonical Session rides in the project row)
//
//  WHY THIS EXISTS. "Save Project" persisted only the Echoel take (`Project`); the
//  Workstation's song — tracks, parts, the clip grid — lived in two app-wide files that Open
//  never touched, so opening a saved project played whatever song was loaded before it
//  (`SESSION_OWNERSHIP_CENSUS.md` §E). The approved ownership (census §O) is:
//  **ProjectStore → DMMWProject → the existing canonical children.** No new persistence root
//  and no new Session type: the envelope is stored INSIDE the existing `projects.json` row,
//  as `Project.sessionEnvelope`, and the legacy take fields stay beside it as the import
//  source every older build can still open.
//
//  ⭐ THE UNKNOWN-FUTURE RULE, decided here once: an envelope whose `envelopeVersion` is newer
//  than this build's is REFUSED, never downgraded — `readSession()` answers `.newer` without
//  decoding it, and the bytes stay in the row untouched (see `Project.sessionEnvelope` for
//  why they are opaque). An envelope this build cannot decode is `.unreadable` and is
//  likewise preserved. Neither case may be opened as if the song were empty: the caller
//  must say so and leave the current song alone.
//
//  Foundation-only, like the envelope it carries.
//

import Foundation

/// What a saved project's Session can do when it is opened. Exhaustive on purpose — a
/// caller must decide every case, including the two that mean "do not touch the song".
public enum SessionRead: Equatable, Sendable {
    /// Saved before the Session writer, or with no song beyond the take: open the take only.
    case absent
    /// A Session this build can restore whole.
    case restorable(DMMWProject)
    /// Written by a NEWER build (its version is carried). Refused, never downgraded.
    case newer(version: Int)
    /// Present but not decodable by this build. Refused; the bytes stay in the row.
    case unreadable
}

public extension Project {

    /// Encode `session` into this take's row. Returns false — and leaves the row unchanged —
    /// when the envelope cannot be encoded (a non-finite value anywhere in the song:
    /// `JSONEncoder` throws on NaN, #512), so a caller never believes a song was saved that
    /// was not. The error is logged with its coding path.
    @discardableResult
    mutating func attachSession(_ session: DMMWProject) -> Bool {
        do {
            setSessionEnvelope(try JSONEncoder().encode(session))
            return true
        } catch {
            log.log(.error, category: .system,
                    "Project '\(name)' — Session not attached, it failed to encode: \(error)")
            return false
        }
    }

    /// What Open may do with this take's Session. Reads the version FIRST, so a newer
    /// envelope is refused without being decoded by a build that does not know its shape.
    func readSession() -> SessionRead {
        guard let data = sessionEnvelope else { return .absent }
        guard let peek = try? JSONDecoder().decode(EnvelopeVersionPeek.self, from: data) else {
            return .unreadable
        }
        let version = peek.envelopeVersion ?? 1
        if version > DMMWProject.currentEnvelopeVersion { return .newer(version: version) }
        guard let session = try? JSONDecoder().decode(DMMWProject.self, from: data) else {
            return .unreadable
        }
        return .restorable(session)
    }
}

/// Only the version, so a newer envelope's shape is never interpreted.
private struct EnvelopeVersionPeek: Decodable {
    let envelopeVersion: Int?
}
