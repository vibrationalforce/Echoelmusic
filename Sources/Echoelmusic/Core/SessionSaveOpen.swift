//
//  SessionSaveOpen.swift
//  Echoelmusic — Core (WA4-S3: Save captures the song, Open restores it)
//
//  WHY THIS EXISTS. WA4-S2 gave the project row a Session; this is what fills it and reads
//  it. Before, "Save Project" kept only the Echoel take, and opening a saved project left
//  whatever song the Workstation held — its tracks, parts and clips — in place: the leak the
//  WA4 forensic review confirmed (`SESSION_OWNERSHIP_CENSUS.md` §E).
//
//  THE RULES, each decided once here:
//  · SAVE captures the song through the ONE importer (`DMMWProjectImport.envelope`) — the
//    Session is the take plus the Workstation's timeline, clip grid, song form and automation.
//  · OPEN FROM THE LIBRARY is "open this project": the song it was saved with replaces the
//    current one. A project saved before Sessions existed carries no song, so it opens on a
//    fresh, empty song rather than inheriting the previous project's — the legacy take is an
//    import source, never a window onto someone else's timeline.
//  · A take that ARRIVES LIVE (Live Colabo) is not a project: today's senders share the take
//    WITHOUT the song (`currentSession` builds it with no `withSession`), and Load puts it
//    into the instrument without touching the song — that caller never reaches
//    `restoreSong`. Its Save goes through `ProjectStore.adoptArriving`, which strips any
//    Session another build might send and gives the row a fresh id. (⛔ This line said
//    "no Session by construction (`sharedDocumentData` strips it)" — the Live Colabo path
//    never passes through `sharedDocumentData`; review LOW-2.) ⚠️ A shared DOCUMENT imported
//    through the Import button becomes a library ROW (its Session stripped on import, so no
//    foreign media paths arrive); opening that row IS "open this project", so it opens on a
//    fresh song like any pre-Session row — and the song it replaces is kept by the recovery
//    slot (`recoveryRow`). (⛔ The first wording said a shared document never replaces the
//    song; the review of `2eb3cb84d` measured the import door and it does.)
//  · A Session this build cannot open — newer, damaged, or with a clip grid LARGER than this build's —
//    REFUSES the whole Open before anything changes, and says why. Never half an open.
//  · The SPATIAL SCENE travels with the piece (Restructure A3a, 2026-10-04): Save captures it,
//    Open puts it back after the song is installed (`restoreSpatialScene`). Its keys are the
//    document's lane ids, so it is the piece's state, not the app's (the session census puts
//    spatial positions in the Session). The modulation matrix and the signal routes stay APP
//    roots on purpose — `TheProjectEnvelopeImportsWithoutRestructuringTests` claim 6.
//  · Song form is CAPTURED and not yet restored (its store has no replace API; it is the legacy
//    root the timeline superseded). The player's automation lanes are NOT captured by the
//    Studio's Save today — that view may not hold the player (the freeze law) — so they stay an
//    app root. Stated here so nobody reads the envelope's compartments as a promise that
//    either comes back.
//

import Foundation

public enum SessionSaveOpen {

    // MARK: Save

    /// `take` with the Workstation's song attached as its Session. If the song cannot be
    /// encoded (a non-finite value, #512) the take is returned WITHOUT a Session and the
    /// failure is logged by `attachSession` — the take still saves; the song does not
    /// pretend to.
    public static func capturing(_ take: Project, timeline: TimelineDocument, clipSlots: [Clip?],
                                 songForm: Arrangement, playerAutomation: [AutomationLane],
                                 sampleRate: Double) -> Project {
        capture(take, timeline: timeline, clipSlots: clipSlots, songForm: songForm,
                playerAutomation: playerAutomation, sampleRate: sampleRate, spatial: nil)
    }

    /// Restructure A3a — the same capture, plus the piece's spatial scene. The Studio's Save
    /// calls THIS form (`TheSpatialSceneTravelsWithThePieceTests` holds every `Sources/` call
    /// site to it); the form above stays for a caller that holds no scene, and writes none.
    public static func capturing(_ take: Project, timeline: TimelineDocument, clipSlots: [Clip?],
                                 songForm: Arrangement, playerAutomation: [AutomationLane],
                                 sampleRate: Double, spatial: SpatialScene) -> Project {
        capture(take, timeline: timeline, clipSlots: clipSlots, songForm: songForm,
                playerAutomation: playerAutomation, sampleRate: sampleRate, spatial: spatial)
    }

    private static func capture(_ take: Project, timeline: TimelineDocument, clipSlots: [Clip?],
                                songForm: Arrangement, playerAutomation: [AutomationLane],
                                sampleRate: Double, spatial: SpatialScene?) -> Project {
        var saved = take
        var session = DMMWProjectImport.envelope(project: take, timeline: timeline,
                                                 clipSlots: clipSlots, songForm: songForm,
                                                 playerAutomation: playerAutomation,
                                                 ppq: Note.ticksPerQuarter,
                                                 sampleRate: sampleRate)
        session.spatial = spatial
        saved.attachSession(session)
        return saved
    }

    // MARK: Open

    /// Why this project cannot be opened by this build, or nil when it can. Asked BEFORE
    /// anything changes, so a refused Open leaves the take, the song and the recovery slot
    /// exactly as they were.
    @MainActor
    public static func refusal(for project: Project) -> String? {
        switch project.readSession() {
        case .absent:
            return nil
        case .restorable(let session):
            guard ClipStore.migratedGrid(session.content.clipSlots) != nil else {
                // E4-65: the quoted name and the two counts are seamed between catalog keys (≤ 4 operands per step).
                let head: String = "“\(project.name)”" + String(localized: " was saved with a part grid of ") + "\(session.content.clipSlots.count)"
                let tail: String = String(localized: " cells; this version has ") + "\(ClipStore.slotCount)" + String(localized: ". Nothing was changed.")
                return head + tail
            }
            return nil
        case .newer(let version):
            let head: String = "“\(project.name)”" + String(localized: " was saved by a newer version of Echoel (piece format ") + "\(version)"
            return head + String(localized: "). Update Echoel to open it. Nothing was changed.")
        case .unreadable:
            return "“\(project.name)”" + String(localized: "'s piece could not be read by this version of Echoel. ")
                + String(localized: "Nothing was changed.")
        }
    }

    /// Replace the Workstation's song with the one `project` was saved with — or with a
    /// fresh, empty song when it was saved before Sessions existed. Returns false (and changes
    /// nothing) for a project `refusal(for:)` would refuse.
    ///
    /// Order is load-bearing: the timeline player stops FIRST (it holds the previous song's
    /// regions and launch state), the clip grid is installed BEFORE the timeline (so the
    /// timeline never points at clips that are not there yet), and both write through at once.
    @MainActor
    @discardableResult
    public static func restoreSong(of project: Project, timeline: TimelineStore,
                                   clips: ClipStore, player: TimelineRegionPlayer) -> Bool {
        let song: (document: TimelineDocument, slots: [Clip?])
        switch project.readSession() {
        case .absent:
            song = emptySong
        case .restorable(let session):
            guard let slots = ClipStore.migratedGrid(session.content.clipSlots) else { return false }
            song = (session.content.timeline, slots)
        case .newer, .unreadable:
            return false
        }
        player.stop()
        guard clips.replaceSlots(song.slots) else { return false }
        timeline.replaceDocument(song.document)
        return true
    }

    /// Restructure A3a — put back the spatial scene `project` was saved with. A project saved
    /// before A3a, or a scene this build could not read, carries none: the scene the song
    /// install already rebuilt from defaults stays, which is what opening always did. Call it
    /// AFTER `restoreSong` — installing the song rebuilds the scene, and a scene restored first
    /// would be fitted to the previous piece's lanes.
    @MainActor
    public static func restoreSpatialScene(of project: Project, into store: SpatialSceneStore,
                                           lanes: [TimelineLane]) {
        guard case .restorable(let session) = project.readSession(),
              let scene = session.spatial else { return }
        store.restore(scene, lanes: lanes)
    }

    /// The song a project saved before Sessions opens into, and the song "New piece" starts —
    /// ONE definition (#416): the default MIDI and audio track, no parts, an empty clip grid.
    /// `@MainActor` because `TimelineStore.migrate` is main-actor isolated (review of
    /// 04551fa36, HIGH: without it this does not compile under Swift 6; `ClipStore.slotCount`
    /// is `nonisolated` since B1);
    /// every caller — `restoreSong`, `startEmptySong`, the guard — already runs there.
    @MainActor
    public static var emptySong: (document: TimelineDocument, slots: [Clip?]) {
        (TimelineStore.migrate(sections: []), [Clip?](repeating: nil, count: ClipStore.slotCount))
    }

    /// DMMW Phase 5 · slice 1 — "New piece": replace the Workstation's song with `emptySong`,
    /// in `restoreSong`'s load-bearing order (player stopped, grid before timeline). The caller
    /// rescues the live take and song into the recovery slot FIRST, exactly as Open does; this
    /// function only replaces. Returns false (and changes nothing past the stop) when the grid
    /// refuses its slots.
    @MainActor
    @discardableResult
    public static func startEmptySong(timeline: TimelineStore, clips: ClipStore,
                                      player: TimelineRegionPlayer) -> Bool {
        let song = emptySong
        player.stop()
        guard clips.replaceSlots(song.slots) else { return false }
        timeline.replaceDocument(song.document)
        return true
    }

    // MARK: Rescue

    /// What the ONE recovery slot should hold after a departure or an Open's rescue — or nil to
    /// leave it untouched. `live` is the current take already carrying the live song as its
    /// Session (slot id and name set). Two rules, each closing a way the slot LOST data
    /// (review of `2eb3cb84d`, H1/H2):
    /// · No live take, but the song holds the user's parts → keep the slot's TAKE and replace
    ///   only its Session. Before, a launch with an empty roll wrote an empty take over the
    ///   last composed one the first time the app left the foreground.
    /// · A live take, but the song holds none of the user's parts → keep the slot's SESSION.
    ///   Before, opening two pre-Session projects in a row traded the user's song (rescued by
    ///   the first Open) for the blank one the first Open installed.
    /// The slot is a recovery point: in doubt it keeps the richer of the two, never the emptier.
    public static func recoveryRow(live: Project, takeIsLive: Bool, songHasUserParts: Bool,
                                   existingSlot: Project?) -> Project? {
        guard takeIsLive || songHasUserParts else { return nil }
        guard let slot = existingSlot else { return live }
        // A live Session of nil while the song holds the user's parts is an encode FAILURE, not
        // an empty song — it must not replace the slot's good one (review LOW-1).
        let session = songHasUserParts ? (live.sessionEnvelope ?? slot.sessionEnvelope)
                                       : live.sessionEnvelope
        if !takeIsLive {
            var kept = slot
            kept.setSessionEnvelope(session)
            return kept
        }
        if !songHasUserParts, slot.sessionEnvelope != nil {
            var row = live
            row.setSessionEnvelope(slot.sessionEnvelope)
            return row
        }
        var row = live
        row.setSessionEnvelope(session)
        return row
    }

    /// Whether the song holds anything the USER put there — a part whose clip is not the
    /// composer's. The composer's own part is re-made on the next Start, so a song holding
    /// only that is nothing to rescue; an imported loop or MIDI file is (H3: before this,
    /// the recovery slot skipped a song with no composed take, and Open then replaced it).
    public static func songHasUserParts(_ document: TimelineDocument, clips: [Clip]) -> Bool {
        let composed = Set(clips.filter(\.composerOwned).map(\.id))
        let known = Set(clips.map(\.id))
        return document.regions.contains { known.contains($0.clipID) && !composed.contains($0.clipID) }
    }
}
