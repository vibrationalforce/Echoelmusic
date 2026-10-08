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
        /// The SAME start, while a bio session is held with its music paused. It is its own case
        /// only so the words can say what the tap does (review of 09d35f56e, MED-1): the song's
        /// start runs the one clock, and the Studio's ONE-Stop observer reads a clock start
        /// during a held session as `.resume` (`TransportTransition.decide`) — so the
        /// instrument's music comes back WITH the song. "Play the song" alone hid that half.
        case startSongAndInstrument
        /// A held bio session: the music comes back, the session never left.
        case resumeInstrument
        /// DAW shell S7a (founder 2026-10-02, „Ja, so bauen" — one control bar on top): the
        /// instrument from silence, while the Instrument stage is in front. Until S7a the plate
        /// carried its own ▶ (`EchoelStudioView.startButton`) right under this one, so the
        /// Instrument stage showed TWO Plays — the confusion the founder named three times
        /// (`OneStartControlTests`). The head's Play is now the one start; the studio runs it
        /// through its own `startBiofeedback()` (`startInstrumentDoor`), because only the studio
        /// owns the session's state.
        case startInstrument
        /// Nothing to play — the button is dimmed and says why.
        case unavailable
    }

    /// WHAT IS IN FRONT DECIDES, and then the song first. On the Instrument stage the one Play
    /// plays the instrument — it starts the session, or brings a held session's music back — and
    /// is never dimmed, because the instrument can always start (S7a). On every other surface the
    /// canonical project is the arrangement: the song, and a session held without music falls
    /// back to resuming the instrument.
    ///
    /// ⚠️ `instrumentInFront` HAS NO DEFAULT (#431/#440/#443): a defaulted argument no call site
    /// writes appears in no diff, and a Play that guessed the stage would start the wrong thing.
    /// The caller asks `StudioStage.playStartsTheInstrument` — the one place the rule lives.
    static func playAction(_ facts: Facts, instrumentInFront: Bool) -> PlayAction {
        if instrumentInFront { return facts.sessionRunning ? .resumeInstrument : .startInstrument }
        if facts.songStartable { return facts.sessionRunning ? .startSongAndInstrument : .startSong }
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

    /// Resume a held session's music. (⛔ "the same call the instrument's own ▶ makes" stood
    /// here; that ▶ is gone with S7a, and this is the one resume.)
    @MainActor
    static func resumeInstrument(pattern: PatternEngine) {
        pattern.play(cause: .transportButton)
    }

    /// The chrome door the head's Play posts to start the instrument (S7a). ONE definition, read
    /// by the poster below and by the studio's `.echoelChromeDoor` receiver (#416) — a spelling
    /// on each side could drift apart and leave a Play that compiles and does nothing.
    static let startInstrumentDoor = "startInstrument"

    /// Start the instrument. It does not start anything itself: the studio owns the session
    /// (camera, composer, bio source), so this asks it through the door the header monitors
    /// already use, and the studio's arm runs its own `startBiofeedback()` — refusing when a
    /// session already runs. No second start path, no state of its own.
    @MainActor
    static func startInstrument() {
        NotificationCenter.default.post(name: .echoelChromeDoor, object: startInstrumentDoor)
    }

    // MARK: - Words

    static func statusWord(_ status: Status) -> String {
        switch status {
        case .stopped:           return String(localized: "Stopped")
        case .paused:            return String(localized: "Paused")
        case .playingInstrument: return String(localized: "Playing instrument")
        case .playingSong:       return String(localized: "Playing piece")
        case .recording:         return String(localized: "Recording")
        }
    }

    /// The button's VoiceOver label: it names what the tap DOES, and a Stop stops everything.
    static func buttonLabel(running: Bool, play: PlayAction) -> String {
        if running { return String(localized: "Stop all playback") }
        switch play {
        case .startSong:        return String(localized: "Play the piece")
        case .startSongAndInstrument: return String(localized: "Play the piece and the instrument")
        case .resumeInstrument: return String(localized: "Play the instrument")
        case .startInstrument:  return String(localized: "Play the instrument")
        case .unavailable:      return String(localized: "Play")
        }
    }

    /// The word the ONE Play / Stop WEARS beside its glyph (interface audit 2026-09-30, "ein
    /// Kopf, der spricht"). A glyph-only transport is read by a producer and guessed by a
    /// beginner, and the header is the first control a fresh install meets. It is the FIRST WORD
    /// of `buttonLabel` — the drawn word and the spoken label may not disagree, and the guard
    /// holds them to that rather than to a second copy of the sentence. ONE word on purpose: the
    /// compact Record beside it stays a glyph, because "Stop" there and "Stop" here while a take
    /// runs would be two identical claims with two different effects — the confusion
    /// `OneStartControlTests` names on the instrument's own row.
    static func buttonWord(running: Bool) -> String {
        running ? String(localized: "Stop") : String(localized: "Play")
    }

    /// `fromTick` is the bar Play starts on — `TimelineRegionPlayer.playStartTick(forCue:in:)`,
    /// the fold `play` applies (GMMW AE-7). REQUIRED (#431): a defaulted 0 would keep saying
    /// "from the top" over a Play that starts where the ruler was tapped. The bar is named by
    /// the one bar-number rule; bar 1 keeps the whole-sentence keys it always had.
    static func buttonHint(running: Bool, play: PlayAction, fromTick: Int) -> String {
        if running { return stopHint }
        let bar = WorkstationSummary.barNumber(forTick: fromTick)
        // E4-61: the bar number is seamed between catalog keys, in typed steps (≤ 4 operands).
        let fromBar: String = String(localized: "Plays the piece from bar ") + "\(bar)"
        switch play {
        case .startSong:
            let cued: String = fromBar + String(localized: " on the shared transport.")
            return bar > 1 ? cued : String(localized: "Plays the piece from the top on the shared transport.")
        case .startSongAndInstrument:
            let cued: String = fromBar + String(localized: ". The instrument's held music comes back with it.")
            return bar > 1 ? cued
                           : String(localized: "Plays the piece from the top. The instrument's held music comes back with it.")
        case .resumeInstrument: return String(localized: "Brings the music back. Your pulse reading keeps running.")
        // The words the plate's own ▶ spoke until S7a, moved with the start they describe.
        case .startInstrument:  return String(localized: "Starts biofeedback; your body then composes and plays the music.")
        case .unavailable:      return String(localized: "Unavailable: add a part with notes or audio, or start the instrument.")
        }
    }

    /// The ONE Stop's hint, on every surface that wears it (the header and the Workstation).
    /// It names the pulse reading because the Stop ends it (review of 09d35f56e, MED-2): the clock
    /// stop reaches the Studio's ONE-Stop observer as `.endSession`, which turns the camera off
    /// and costs a pulse re-lock. The instrument's own pause is the control that keeps it, and
    /// the hint names it by ITS label ("Pause the music", `PlaybackToggleButton`) rather than
    /// letting a listener find out afterwards.
    static let stopHint = String(localized: "Stops the piece, the instrument and any recording, everywhere in the app. A running pulse reading ends too; Pause the music keeps it.")

    /// The Workstation's caption while the instrument (not the piece) plays on the one clock —
    /// its button then reads Stop, and the piece's own caption ("Plays the piece's parts from the
    /// top.") would describe a tap the button no longer makes.
    static let instrumentRunningCaption = String(localized: "The instrument is playing. Stop ends all playback and the pulse reading.")

    /// The header never invents a name: a run that has neither saved nor opened a piece says so.
    /// ⭐ "piece", not "session" or "project" — `docs/dev/GLOSSARY.md` (rule 1, one word per
    /// thing); `TheChromeSpeaksOneWordPerThingTests` scans this file for the struck words.
    static let unsavedName = String(localized: "Unsaved piece")

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
            return String(localized: "No track selected")
        }
        guard let region = WorkstationSelection.resolvedRegion(regionID, track: track, in: document),
              let part = document.regions.first(where: { $0.id == region }) else {
            return lane.name
        }
        let bar = WorkstationSummary.barNumber(forTick: part.startTick)
        return lane.name + String(localized: " · part at bar ") + "\(bar)"
    }
}
