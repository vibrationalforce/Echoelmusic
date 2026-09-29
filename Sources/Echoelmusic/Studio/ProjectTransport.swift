// ProjectTransport.swift
// Echoel — DMMW Phase 1 · slice 3 (founder 2026-09-29): the ONE running truth the persistent
// project header shows, and the ONE Stop every surface shares.
//
// ⭐ IT OWNS NOTHING. There is one clock (`PatternEngine`, relaying into `Transport`), one song
// player (`TimelineRegionPlayer`), one recorder (`RecordController`) and one project library
// (`ProjectStore`). This file only DERIVES the status from their existing flags and routes a
// Stop to the existing owner. No second clock, no copy of the project, no new audio path.
//
// ⚠️ WHY STOP IS ONE FUNCTION HERE AND PLAY IS NOT. A Stop has exactly two roads and both
// already end everything: the song's `stop()` stops the shared pattern itself, and a bare
// `pattern.stop()` reaches the song through the app's `addStopSubscriber("timeline")`, the
// recorder through its own stop subscriber (the take is committed there), and the instrument
// through the Studio's ONE-Stop observer (`TransportTransition.decide` → `.endSession`, the
// bio session ends with the music — the instrument's own ⏸ is the pause that keeps it). The
// Play side is NOT moved here: the song's start stays in `WorkstationView` (the one file that
// may call `player.play(`, `TheWorkstationPlaysTheTimelineTests`), and this file only picks
// WHICH existing start a Play means.

import Foundation

enum ProjectTransport {

    /// What the header says. Ordered by what the user must know first: a running take outranks
    /// a playing song, a playing song outranks the live instrument, and a bio session that is
    /// held with the music stopped is `paused`, not `stopped` — its Play resumes the music.
    enum Status: Equatable, Sendable {
        case stopped, paused, playingInstrument, playingSong, recording
    }

    /// The flags the status is derived from. Every one is an existing owner's own flag, and
    /// every one changes on a start or a stop, never per step — so the header that reads them
    /// is not a hot reader (the 10.76.41/50 freeze law).
    struct Facts: Equatable, Sendable {
        /// `Transport.isPlaying` — the one clock.
        var clockRunning: Bool
        /// `TimelineRegionPlayer.isPlaying` — the arrangement follows the clock.
        var songPlaying: Bool
        /// `RecordController.isRecording` — a take is being captured.
        var recording: Bool
        /// `EngineBus.instrumentRunning` — a bio session is live (with or without music).
        var sessionRunning: Bool
        /// The Workstation's own start guard (`WorkstationView.songCanStart`).
        var songStartable: Bool
    }

    static func status(_ facts: Facts) -> Status {
        if facts.recording { return .recording }
        if facts.songPlaying { return .playingSong }
        if facts.clockRunning { return .playingInstrument }
        if facts.sessionRunning { return .paused }
        return .stopped
    }

    /// Anything sounding on the one clock. The Workstation's Play/Stop reads THIS, not the song
    /// alone — otherwise it said "Play" while the instrument ran, a second truth beside the
    /// header's (the founder's "keine konkurrierenden Play/Stop-Wahrheiten").
    static func isRunning(clockRunning: Bool, songPlaying: Bool) -> Bool {
        clockRunning || songPlaying
    }

    static func isRunning(_ facts: Facts) -> Bool {
        isRunning(clockRunning: facts.clockRunning, songPlaying: facts.songPlaying) || facts.recording
    }

    // MARK: - Play

    enum PlayAction: Equatable, Sendable {
        /// The song, from the top, through the Workstation's one start.
        case startSong
        /// A held bio session: the music comes back, the session never left.
        case resumeInstrument
        /// Nothing to play — the button is dimmed and says why.
        case unavailable
    }

    /// The song first: the canonical project is the arrangement. A session held without music
    /// falls back to resuming the instrument, so the header's Play is never dimmed while the
    /// instrument's own ▶ would work.
    static func playAction(_ facts: Facts) -> PlayAction {
        if facts.songStartable { return .startSong }
        if facts.sessionRunning { return .resumeInstrument }
        return .unavailable
    }

    // MARK: - Stop

    enum StopAction: Equatable, Sendable {
        /// The song's own stop — it stops the shared clock in turn.
        case song
        /// The clock alone (the instrument, or a take with no song) — the stop subscribers
        /// reset the song, commit the take and end the session.
        case clock
        /// Nothing runs.
        case nothing
    }

    static func stopAction(songPlaying: Bool, clockRunning: Bool) -> StopAction {
        if songPlaying { return .song }
        if clockRunning { return .clock }
        return .nothing
    }

    /// The ONE Stop. `source` is written to the crash log BEFORE the call, so a log that ends
    /// on it names the step it died in (the lifecycle-ladder law).
    @MainActor
    static func stop(song: TimelineRegionPlayer, pattern: PatternEngine, source: String) {
        switch stopAction(songPlaying: song.isPlaying, clockRunning: pattern.isPlaying) {
        case .song:
            EchoelCrashLog.breadcrumb("stop source: \(source) (song + transport)")
            song.stop()
        case .clock:
            EchoelCrashLog.breadcrumb("stop source: \(source) (transport)")
            pattern.stop()
        case .nothing:
            break
        }
    }

    /// Resume a held session's music — the same call the instrument's own ▶ makes.
    @MainActor
    static func resumeInstrument(pattern: PatternEngine) {
        pattern.play(cause: .transportButton)
    }

    // MARK: - Words

    static func statusWord(_ status: Status) -> String {
        switch status {
        case .stopped:           return "Stopped"
        case .paused:            return "Paused"
        case .playingInstrument: return "Playing instrument"
        case .playingSong:       return "Playing song"
        case .recording:         return "Recording"
        }
    }

    /// The button's VoiceOver label: it names what the tap DOES, and a Stop stops everything.
    static func buttonLabel(running: Bool, play: PlayAction) -> String {
        if running { return "Stop all playback" }
        switch play {
        case .startSong:        return "Play the song"
        case .resumeInstrument: return "Play the instrument"
        case .unavailable:      return "Play"
        }
    }

    static func buttonHint(running: Bool, play: PlayAction) -> String {
        if running { return "Stops the song, the instrument and any recording, everywhere in the app." }
        switch play {
        case .startSong:        return "Plays the song from the top on the shared transport."
        case .resumeInstrument: return "Brings the music back. Your session and pulse reading keep running."
        case .unavailable:      return "Unavailable: add a part with notes or audio, or start the instrument."
        }
    }

    /// The Workstation's caption while the instrument (not the song) plays on the one clock —
    /// its button then reads Stop, and the song's own caption ("Plays the song's parts from the
    /// top.") would describe a tap the button no longer makes.
    static let instrumentRunningCaption = "The instrument is playing. Stop ends all playback."

    /// The header never invents a name: a run that has neither saved nor opened a project says so.
    static let unsavedName = "Unsaved session"

    static func projectName(_ current: String?) -> String {
        guard let name = current?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else { return unsavedName }
        return name
    }

    /// Where the player is working: the selected track, and the selected part's bar on it. The
    /// ids are resolved against the document the same way the Workstation resolves them, so a
    /// deleted track or a part moved by an Undo reads as "no selection", never a stale name.
    static func place(document: TimelineDocument, trackID: UUID?, regionID: UUID?) -> String {
        guard let track = WorkstationSelection.resolvedTrack(trackID, in: document),
              let lane = document.lanes.first(where: { $0.id == track }) else {
            return "No track selected"
        }
        guard let region = WorkstationSelection.resolvedRegion(regionID, track: track, in: document),
              let part = document.regions.first(where: { $0.id == region }) else {
            return lane.name
        }
        return "\(lane.name) · part at bar \(WorkstationSummary.barNumber(forTick: part.startTick))"
    }
}
