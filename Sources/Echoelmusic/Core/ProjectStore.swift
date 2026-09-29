// ProjectStore.swift
// Echoel — the saved-projects library. Persists Projects as one JSON array in the
// App Group container (survives relaunch, shared with extensions). Newest first.

import Foundation

@MainActor
@Observable
public final class ProjectStore {

    /// Saved projects, newest first.
    public private(set) var projects: [Project] = []
    public private(set) var saveError: String?
    public private(set) var lastSavedAt: Date?
    /// DMMW Phase 1 · slice 3 — the name of the project the player last SAVED or OPENED from
    /// the library, which the persistent project header shows. nil = this run has neither
    /// saved nor opened a named project, and the header says so instead of inventing a name.
    /// The recovery slot never becomes it: a row the user did not name is not "the project".
    /// Cold — written on Save and Open only. Not persisted: after a relaunch the working copy
    /// is the recovery slot, not a named project, and claiming otherwise would be a guess.
    public private(set) var currentProjectName: String?
    /// The row `currentProjectName` came from, so deleting THAT row takes the name back
    /// (review of 09d35f56e, LOW) — a header must not name a project the library no longer has.
    @ObservationIgnored private var currentProjectID: UUID?

    @ObservationIgnored private var pendingProjects: [Project]?
    @ObservationIgnored private let writeProjects: ([Project]) -> Bool
    public var hasPendingSave: Bool { saveError != nil }

    @ObservationIgnored private let store: AppGroupStore
    @ObservationIgnored private let fileName = "projects.json"

    public init(store: AppGroupStore = AppGroupStore(),
                writeProjects: (([Project]) -> Bool)? = nil) {
        self.store = store
        self.writeProjects = writeProjects ?? { store.save($0, name: "projects.json") }
        // Element-tolerant (see AppGroupStore.loadLossyArray): one unreadable project is
        // dropped instead of taking the whole library down with it — the previous decode
        // returned nil for the entire file and the next save wrote the emptied list back.
        // These are re-sorted anyway, so a hole cannot mean anything positional.
        projects = (store.loadLossyArray(Project.self, name: fileName) ?? [])
            .compactMap { $0 }
            .sorted { $0.savedAt > $1.savedAt }
    }

    /// Attempt to save a project. The returned snapshot has a refreshed date;
    /// only a successful write updates the confirmed library. Failure is retained
    /// in saveError and can be retried without discarding the pending snapshots.
    @discardableResult
    public func save(_ project: Project) -> Project {
        let p = storeRow(project)
        noteCurrent(p)
        return p
    }

    /// Writes a row WITHOUT making it the project the player works on. `save` is this plus
    /// `noteCurrent`; an ARRIVAL (`adoptArriving`: a file import or a Live Colabo peer's Save)
    /// is this alone — review of 09d35f56e, MED-4: it only adds a row to the library, the
    /// working take is unchanged, so the header must keep naming what the player works on.
    private func storeRow(_ project: Project) -> Project {
        var p = project
        p.savedAt = Date()
        var next = pendingProjects ?? projects
        next.removeAll { $0.id == p.id }
        next.insert(p, at: 0)
        persist(next)
        return p
    }

    /// Record `project` as the one the player is working on (Save and library Open). The
    /// recovery slot is skipped — see `currentProjectName`.
    public func noteCurrent(_ project: Project) {
        guard project.id != Project.autosaveSlotID else { return }
        currentProjectName = project.name
        currentProjectID = project.id
    }

    public func delete(id: UUID) {
        let next = (pendingProjects ?? projects).filter { $0.id != id }
        persist(next)
        if currentProjectID == id {
            currentProjectName = nil
            currentProjectID = nil
        }
    }

    public func project(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    /// Recovery must also see snapshots retained after a failed disk write.
    /// The visible library continues to contain confirmed writes only.
    public func recoveryProject(id: UUID) -> Project? {
        (pendingProjects ?? projects).first { $0.id == id }
    }

    // MARK: - Sharing (cross-device / community)

    /// Encode a project to portable, human-diffable JSON for sharing (AirDrop,
    /// Files, Messages) or cross-device transfer. Self-contained: style, key, tempo,
    /// the synth patch, the notes and the drum grid all travel in one document.
    ///
    /// ⛔ THE FORMAT IS NO LONGER DECIDED HERE (#519). It moved to
    /// `Project.sharedDocumentData()`, because this method had ZERO production callers —
    /// measured, not assumed — while the path a user actually reaches (`SharedEchoelProject`,
    /// the `ShareLink` in every library row) printed its own bare `JSONEncoder()`. The
    /// "human-diffable" promise in the line above was made here and broken there. Read that
    /// method for what the decision is and, just as importantly, what it is NOT the decision
    /// for (the on-disk library and the colab wire payload are separate and must stay so).
    ///
    /// ⚠️ THE `Data?` CONTRACT IS UNCHANGED ON PURPOSE. This method's only callers are two
    /// round-trip tests in the non-blocking suite; widening its signature in the same slice
    /// would touch a second surface for no behavioural gain. What a caller LOSES by using
    /// this form rather than the throwing one is the field name inside `EncodingError` —
    /// which is exactly why the reachable share path uses the throwing one.
    public func exportData(_ project: Project) -> Data? {
        try? project.sharedDocumentData()
    }

    /// Import a shared project document. The decoded project gets a FRESH id (so
    /// importing your own export never overwrites the original) and is saved to the
    /// top of the library.
    ///
    /// ⭐ THIS IS THE RECEIVING TWIN OF `Project.sharedDocumentData()` (#520), and it exists
    /// because #519's own prose named a message this app never printed. That doc block says
    /// an empty share "surfaces on SOMEONE ELSE'S device, days later, as `importProject`
    /// returning `nil` — 'not a valid Echoel session'." Measured: that sentence lives in TWO
    /// doc comments and NOWHERE else. `git grep "importFailure\|importError\|showImport"` over
    /// `Sources/` returned nothing; the one production call site discarded the return value
    /// AND ignored `case .failure` entirely. The receiving device said nothing at all — pick a
    /// file, the sheet closes, the library is unchanged, and the only available reading is
    /// "I must have tapped wrong".
    ///
    /// ⚠️ IT THROWS FOR THE #514/#518/#519 REASON: `DecodingError` names the FIELD through
    /// `codingPath`. "This isn't an Echoel session at all", "it is one, but from a build that
    /// writes a field this one cannot read" and "the file could not be read off disk" are
    /// three different problems with three different answers, and `try?` folds all three onto
    /// `nil`. The `Data(contentsOf:)` throw is kept separate for the same reason — a
    /// permission/IO failure must not read as a corrupt document.
    ///
    /// ⛔ THE `Project?` FORMS BELOW ARE KEPT DELIBERATELY, and NOT because they are pretty.
    /// They have four callers in `Tests/EchoelmusicTests/ProjectStoreTests.swift` — the suite
    /// **no gate compiles** (#208) — so changing their signature is a break no CI run can show
    /// (#494 shipped exactly that, undetected). This is the same split `exportData` carries
    /// one screen up: the yes/no form stays for its existing callers, the throwing form is
    /// what the reachable door uses.
    public func importProject(fromDocument data: Data) throws -> Project {
        let p = try JSONDecoder().decode(Project.self, from: data)
        let imported = adoptArriving(p)
        if saveError != nil { throw PersistenceFailure() }
        return imported
    }

    /// Saves a take that came from OUTSIDE this device — a file or a Live Colabo peer — as a
    /// NEW row. The ONE rule for every arrival door (review LOW-2: the Live Colabo Save kept the
    /// peer's id and Session): a fresh id, because a row saved under the sender's id
    /// overwrites the original of an export you import back (`save` replaces by id); and never
    /// a song — a Session names another device's media paths and clip grid (WA4-S2/H5;
    /// `sharedDocumentData` strips it on the way out, but a hand-made or future file, or
    /// another build's peer, may still carry one, and it would be installed on Open).
    @discardableResult
    public func adoptArriving(_ project: Project) -> Project {
        var p = project
        p.id = UUID()
        p.setSessionEnvelope(nil)
        return storeRow(p)
    }

    /// Import from a (security-scoped) file URL — the `fileImporter` path, throwing.
    public func importProject(fromDocument url: URL) throws -> Project {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        // NOT `guard scoped else { throw }`: a document picked with `.import` is copied to a
        // temp location the app already owns, where `startAccessingSecurityScopedResource()`
        // returns false and reading succeeds anyway. Failing on the Bool would reject the
        // ordinary case. Behaviour unchanged from the `Project?` form on purpose — this slice
        // surfaces the error, it does not re-decide when to read.
        let data = try Data(contentsOf: url)
        return try importProject(fromDocument: data)
    }

    /// Yes/no import. See the throwing twin above for what a caller gives up by using this.
    @discardableResult
    public func importProject(from data: Data) -> Project? {
        try? importProject(fromDocument: data)
    }

    /// Yes/no import from a URL. See the throwing twin above.
    @discardableResult
    public func importProject(from url: URL) -> Project? {
        try? importProject(fromDocument: url)
    }

    /// The one sentence the Import door shows when a file could not become a take.
    ///
    /// ⭐ `nonisolated` so the blocking bundle can drive it end to end. `ProjectStore` is
    /// `@MainActor @Observable` and its init touches the App Group container, so a test that
    /// had to instantiate the store to reach this decision would be a source scan wearing a
    /// behaviour test's clothes. A `static` member of a `@MainActor` type is main-actor
    /// isolated unless it says otherwise — that is the documented Xcode-vs-SwiftPM trap in
    /// CLAUDE.md's build-error table, and the reason the keyword is written out here.
    ///
    /// ⚠️ IT NAMES THE FIELD WHERE ONE EXISTS AND INVENTS NOTHING WHERE ONE DOES NOT.
    /// `DecodingError.keyNotFound`/`.typeMismatch`/`.valueNotFound` carry a `codingPath`;
    /// `.dataCorrupted` on a non-JSON file has an EMPTY path (there is no field — the bytes
    /// were never a document), and printing "field: " with nothing after it would be the
    /// fabricated-detail defect this repo has paid for repeatedly (#424/#426/#433/#461).
    nonisolated public static func importFailureNote(_ error: Error) -> String {
        if error is PersistenceFailure {
            return "The file was read, but could not be saved. Retry the pending save."
        }
        guard let decoding = error as? DecodingError else {
            // Everything that is not a decode problem: unreadable file, revoked permission,
            // a deleted iCloud placeholder. Deliberately NOT called "invalid session" — the
            // document may be perfect and simply unreachable.
            return "Couldn't read that file."
        }
        // ⚠️ AN `if case` CHAIN RATHER THAN A `switch`, AND THAT IS A BUILD DECISION, not a
        // style one. A `switch` over `DecodingError` needs either `default` or
        // `@unknown default`, and which one warns depends on whether the stdlib ships that
        // enum as frozen — the wrong guess is a WARNING, and this project builds with
        // `-warnings-as-errors`. There is no local Swift toolchain in this environment, so a
        // coin-flip there costs a full CI round trip. This form has no exhaustiveness
        // question at all and reads the same.
        var path: [CodingKey] = []
        if case .keyNotFound(_, let c) = decoding { path = c.codingPath }
        else if case .typeMismatch(_, let c) = decoding { path = c.codingPath }
        else if case .valueNotFound(_, let c) = decoding { path = c.codingPath }
        else if case .dataCorrupted(let c) = decoding { path = c.codingPath }
        // `stringValue` covers both keyed and unkeyed containers; an array index arrives as
        // "Index 3", which reads correctly in this sentence.
        let field = path.map(\.stringValue).joined(separator: " › ")
        return field.isEmpty
            ? "That file isn't an Echoel session."
            : "That file isn't a readable Echoel session — \(field)."
    }

    /// Retry the exact pending library, including projects queued by later saves.
    @discardableResult
    public func retrySave() -> Bool {
        guard let pendingProjects else { return true }
        return persist(pendingProjects)
    }

    private struct PersistenceFailure: Error {}

    nonisolated public static func isPersistenceFailure(_ error: Error) -> Bool {
        error is PersistenceFailure
    }

    @discardableResult
    private func persist(_ next: [Project]) -> Bool {
        guard writeProjects(next) else {
            pendingProjects = next
            saveError = "Could not save this project. Your changes are still here. Free device storage or retry."
            return false
        }
        projects = next
        pendingProjects = nil
        saveError = nil
        lastSavedAt = Date()
        return true
    }
}
