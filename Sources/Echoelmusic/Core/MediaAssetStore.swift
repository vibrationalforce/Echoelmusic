// MediaAssetStore.swift
// Echoel — the registry of durable media identities (MA4.2; founder media decision 2026-09-26;
// plan `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md` §MA4).
//
// ⭐ AN APP ROOT, NOT A PROJECT COMPARTMENT — the same line `DMMWProject` draws for the patch
// library. The managed media home is app-wide: one file is used by many projects, and opening a
// project must not replace what the library knows about its files. A project carries only the
// LINK (`Clip.mediaAssetID`, inside `clipSlots`); the record it points at lives here.
// ⚠️ Consequence, stated so nobody reads it as covered: a project opened on ANOTHER device finds
// no record for its links. Its clips still play by `mediaRef` (the legacy path), exactly as
// before this slice. Carrying records across devices is a collect/archive question, not this one.
//
// ⭐ WHAT IT DOES AND DOES NOT DO.
// · One small JSON file, read once when the store is constructed at launch and written on each
//   change. It never lists the media directory, never opens a media file, never hashes — the
//   founder's "inactive domain ≈ near-zero recurring cost".
// · Availability is not stored: "is the file there" is asked of the resolver when needed.
// · One name, one answer: when two records carry the same binding, `record(boundTo:)` returns
//   the NEWEST — the latest import or rebind of a name is what that name means now; the older
//   record keeps its id, so a clip linked to it is not rewritten. (The library picks
//   collision-free names, this app deletes no media, and a relink never moves a record onto a
//   file that already has its own (`MediaRelink`, MA4.5 review MED-2) — so this happens only when
//   a file was removed behind the app's back and the name reused; the digest slice MA4.4 is what
//   can tell the two files apart.)
// · Element-tolerant decode: one damaged record is dropped, the others survive. Unlike the clip
//   grid, position means nothing here, so compacting is correct.

import Foundation
import Observation

@MainActor
@Observable
public final class MediaAssetStore {

    /// Every known record, in registration order.
    public private(set) var records: [MediaAssetRecord]

    @ObservationIgnored private let store: AppGroupStore?
    @ObservationIgnored private static let fileName = "assets"

    /// The app's registry, persisted in the App Group.
    public convenience init() {
        self.init(store: AppGroupStore(subdirectory: "MediaAssets"))
    }

    /// `store: nil` keeps everything in memory — the blocking bundle drives the store this way so
    /// a test never writes into the running app's saved state.
    public init(store: AppGroupStore?) {
        self.store = store
        let saved = store?.loadLossyArray(MediaAssetRecord.self, name: Self.fileName) ?? []
        self.records = saved.compactMap { $0 }
    }

    /// The record with this identity, or nil.
    public func record(id: UUID) -> MediaAssetRecord? {
        records.first(where: { $0.id == id })
    }

    /// The record that currently holds this binding, or nil. The newest wins (see the header).
    public func record(boundTo key: MediaAsset.Key) -> MediaAssetRecord? {
        records.last(where: { $0.key == key })
    }

    /// Add a record, or replace the one with the same id. A record with an empty binding is
    /// refused (it could never resolve). Returns false, writing nothing, when refused.
    @discardableResult
    public func register(_ record: MediaAssetRecord) -> Bool {
        guard !record.fileName.isEmpty else { return false }
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            guard records[index] != record else { return true }
            records[index] = record
        } else {
            records.append(record)
        }
        persist()
        return true
    }

    /// MA4.5 — point a record at another file of its kind's home, KEEPING ITS ID: a relink of a
    /// missing source moves the binding, never the identity every linked clip names. The record
    /// becomes the newest holder of the new name, so `record(boundTo:)` answers it there (a
    /// record another file already had under that name keeps its own id; nothing is merged or
    /// deleted). Returns false, writing nothing, for an unknown id or an empty name.
    @discardableResult
    public func rebind(id: UUID, toFileName fileName: String) -> Bool {
        guard !fileName.isEmpty, let index = records.firstIndex(where: { $0.id == id }) else {
            return false
        }
        var record = records.remove(at: index)
        record.fileName = fileName
        records.append(record)
        persist()
        return true
    }

    /// What a relink does to the clip's durable link (MA4.5 review): the writer
    /// (`TimelineStore.relinkClipSource`) takes exactly one, so "move a record AND link another"
    /// cannot be spelled.
    /// · `.release` — the clip ends unlinked: no registry, or no record describes the chosen file.
    /// · `.adopt(id)` — the chosen file's OWN record (its binding is that file and its measurement
    ///   does not refute it); the clip's former record stays where it is.
    /// · `.move(rebinding)` — the clip's own record still describes the missing file this clip
    ///   played, so it follows the file with its id; the clip keeps its link.
    public enum RelinkIdentity {
        case release
        case adopt(UUID)
        case move(Rebinding)
    }

    /// One record's binding, as a relink moves it and its Undo moves it back — carried by the
    /// song's history (`TimelineStore.relinkClipSource`) so the clip and its source change in ONE
    /// step. The store travels with it for the reason `ClipStore` travels with a notes step: the
    /// history keeps its parameterless `undo()`.
    public struct Rebinding {
        public let store: MediaAssetStore
        public let recordID: UUID
        public let fileName: String

        public init(store: MediaAssetStore, recordID: UUID, fileName: String) {
            self.store = store
            self.recordID = recordID
            self.fileName = fileName
        }
    }

    private func persist() {
        _ = store?.save(records, name: Self.fileName)
    }
}
