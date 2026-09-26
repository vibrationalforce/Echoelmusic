//
//  SessionLaunchView.swift
//  Echoelmusic — Studio (WA4.2: the Session projection — launch parts while the song plays)
//
//  WHY THIS EXISTS. The WA4 journey has two views of ONE song: Arrange (the timeline the
//  Workstation lists and plays) and Session (parts launched live, per track, on the bar).
//  The engine half was done and doorless: `ClipLaunchEngine` (pure, tested) sits inside
//  `TimelineRegionPlayer`, and `launchRegion` · `stopLaunched` · `launchState` ·
//  `launchGeneration` had ZERO production callers. This is the door.
//
//  ⭐ A PROJECTION, NOT A SECOND SONG. Tracks are the document's lanes, cells are the
//  document's regions, scenes are the bars where parts start. Nothing here is persisted:
//  launch state is runtime-only in the engine (reset on play/stop/relocate), and the grid is
//  recomputed from `timeline.document` on every edit. No new Session owner (WA2 §O).
//
//  ⚠️ ONE DEFINITION OF "WHAT PLAYS HERE" (#1440). A scene's cell on a track is the region
//  `TimelineScheduling.activeRegion` picks at the scene's tick — the same overlap precedence
//  the player uses — never a second rule about which of two overlapping parts wins.
//
//  ⚠️ ONLY AUDIBLE, LAUNCHABLE TRACKS ARE SHOWN (the #164/#227 "no control that does nothing"
//  law). `launchRegion` refuses bio, video and visual lanes, and an extra MIDI lane past the
//  lane rack's capacity has no voice — a launch there would read "Playing" in silence. Both
//  are decided ONCE, by `TrackMix.role` (the inspector's rule), so the two Workstation views
//  can never disagree about which tracks sound. And launching is disabled while the song is
//  stopped, because the engine no-ops then; the caption says so.
//
//  ⚠️ ONLY PARTS THAT WOULD SOUND GET A CELL (WA4.2c, the same law one level down). A
//  region whose audio file no longer resolves, or whose MIDI clip is missing or empty,
//  would launch into silence while the cell read "Playing". The verdict is the player's
//  own `TimelineRegionPlayer.isExecutable` — the per-region question behind the Play
//  button — with the same resolver `AudioLanePlayer` plays through (#1439). Never a
//  second rule.
//
//  ⚠️ PHASE, STATED RATHER THAN IMPLIED. A launched part on the Echoel track picks up
//  where the song is inside that part (`loadClip` follows the arrangement position); on
//  every other track it starts from its own top (the player's PHASE CAVEAT). So a scene
//  is the SET of parts the song plays at that bar, not a guarantee that they line up the
//  way the arrangement had them. The caption says so.
//
//  ⭐ A SCENE IS A SWITCH (Phase 3 / S1). "Launch scene" makes ONE player call
//  (`launchScene`): its parts launch and every other launched track returns to the song, all
//  on the same bar — before, a per-cell loop left the other tracks looping, so two scenes in a
//  row played as their union. "Back to song" (`stopAllLaunched`) returns every track at once.
//  A track a scene leaves out goes back to the SONG, never to silence: that is what stop means
//  in this lane-override model, and the caption says so.
//
//  Cold reads only. `launchGeneration` bumps on a tap or a fired bar boundary, never per
//  step, and `isPlaying` changes twice per take — both are safe in a leaf body. The playhead
//  (`currentTick`) is not read here.
//

import SwiftUI

/// The pure half: which tracks can launch, which scenes the song offers, and what state a
/// cell is in. Foundation-only value logic, so a test drives it end to end.
enum SessionGrid {

    /// Launches land on the next bar — the same unit the arrangement and the loop point use.
    static let quantize: LaunchQuantize = .bar
    /// Rows shown before the rest is summarised in one line (never silently dropped).
    static let sceneLimit = 32

    struct Track: Identifiable, Equatable, Sendable {
        let id: UUID
        let name: String
    }

    struct LaunchScene: Identifiable, Equatable, Sendable {
        /// The song tick the scene starts at. Unique per scene, so it is the identity.
        let startTick: Int
        /// Track id → the region the song plays on that track at `startTick`. A track with
        /// nothing playing there has no entry.
        let cells: [UUID: UUID]
        var id: Int { startTick }
    }

    enum CellState: Equatable, Sendable {
        case idle
        case queued
        case playing
        case stopping
    }

    /// Tracks a launch is HEARD on, in document order: the roles `TrackMix.role` gives a
    /// voice — the Echoel track, a rack-voiced MIDI lane, an audio lane. That excludes what
    /// `TimelineRegionPlayer.launchRegion` refuses (bio, video, visual) and a MIDI lane with no
    /// rack voice. `voiceCapacity` is `TimelineRegionPlayer.laneVoiceCapacity`, never defaulted.
    nonisolated static func tracks(in document: TimelineDocument, voiceCapacity: Int) -> [Track] {
        document.lanes
            .filter { lane in
                guard let role = TrackMix.role(of: lane.id, in: document,
                                               voiceCapacity: voiceCapacity) else { return false }
                switch role {
                case .echoelInstrument, .laneSynth, .audio: return true
                case .bio, .unplayed, .noVoice:             return false
                }
            }
            .map { Track(id: $0.id, name: $0.name) }
    }

    /// One scene per distinct tick at which a PLAYABLE part starts on a launchable track,
    /// ascending. Each cell is `activeRegion`'s answer at that tick, so a part that started
    /// earlier and is still playing belongs to the scene too. A winner that would not sound
    /// (not in `playable`) gets no cell — never a different part in its place, because that
    /// would not be what the song plays there.
    nonisolated static func scenes(in document: TimelineDocument,
                                   voiceCapacity: Int,
                                   playable: Set<UUID>) -> [LaunchScene] {
        let trackIDs = tracks(in: document, voiceCapacity: voiceCapacity).map(\.id)
        let launchable = Set(trackIDs)
        let starts = Set(document.regions
            .filter { launchable.contains($0.laneID) && playable.contains($0.id) }
            .map(\.startTick))
        return starts.sorted().compactMap { tick in
            var cells: [UUID: UUID] = [:]
            for laneID in trackIDs {
                if let region = TimelineScheduling.activeRegion(in: document, laneID: laneID, at: tick),
                   playable.contains(region.id) {
                    cells[laneID] = region.id
                }
            }
            return cells.isEmpty ? nil : LaunchScene(startTick: tick, cells: cells)
        }
    }

    /// The regions that would put something through the engine if launched: the player's
    /// own per-region verdict (`TimelineRegionPlayer.isExecutable`), asked with the same
    /// clip values and audio resolver the playing path uses. Bio lanes and lanes whose kind
    /// the timeline engine does not play are never playable. `@MainActor` because the verdict
    /// it asks lives on the (main-actor) player.
    @MainActor
    static func playableRegionIDs(in document: TimelineDocument,
                                  clips: [Clip],
                                  bpm: Double,
                                  resolveAudio: (UUID) -> URL?) -> Set<UUID> {
        var byID: [UUID: Clip] = [:]
        for clip in clips where byID[clip.id] == nil { byID[clip.id] = clip }
        var kinds: [UUID: ClipKind] = [:]
        for lane in document.lanes
        where !lane.isBio && ClipKind.timelineEngineKinds.contains(lane.kind) {
            kinds[lane.id] = lane.kind
        }
        var playable = Set<UUID>()
        for region in document.regions {
            guard let kind = kinds[region.laneID], let clip = byID[region.clipID] else { continue }
            if TimelineRegionPlayer.isExecutable(region: region, onLaneOfKind: kind, clip: clip,
                                                 bpm: bpm, resolveAudio: resolveAudio) {
                playable.insert(region.id)
            }
        }
        return playable
    }

    /// What a cell shows, given its track's launch state. Only the region the state names
    /// lights up; every other cell on the track stays idle.
    nonisolated static func cellState(_ state: LaneLaunchState, regionID: UUID) -> CellState {
        switch state {
        case .idle:
            return .idle
        case .queued(let queued, _, let current):
            if queued == regionID { return .queued }
            if current?.regionID == regionID { return .playing }
            return .idle
        case .playing(let launched):
            return launched.regionID == regionID ? .playing : .idle
        case .queuedStop(let current, _):
            return current.regionID == regionID ? .stopping : .idle
        }
    }

    /// Phase 3 / S1 — whether a SCENE is what the tracks play now (`.playing`), is about to be
    /// on the next bar (`.queued`), or neither (nil). Playing = every cell's track loops that
    /// cell's part AND every other track is back on the song; queued = everything is either
    /// there or on its way there at the boundary. A track still leaving a DIFFERENT part, or
    /// switching away, makes it neither — never a scene marked live over a track it does not own.
    /// `states` holds each track's launch state; a missing entry is `.idle`.
    nonisolated static func sceneState(_ scene: LaunchScene, tracks: [Track],
                                       states: [UUID: LaneLaunchState]) -> CellState? {
        var arriving = false
        for track in tracks {
            let state = states[track.id] ?? .idle
            if let regionID = scene.cells[track.id] {
                switch state {
                case .playing(let launched) where launched.regionID == regionID:
                    continue
                case .queued(let queued, _, _) where queued == regionID:
                    arriving = true
                default:
                    return nil
                }
            } else {
                switch state {
                case .idle:       continue
                case .queuedStop: arriving = true
                default:          return nil
                }
            }
        }
        return arriving ? .queued : .playing
    }

    /// A track has something to stop when anything is launched or queued on it.
    nonisolated static func isLaunched(_ state: LaneLaunchState) -> Bool {
        state != .idle
    }

    /// "Bar 5", or "Bar 5 beat 3" for a part that does not start on a downbeat.
    nonisolated static func label(forTick tick: Int) -> String {
        let t = Swift.max(0, tick)
        let bar = t / TimelineTime.ticksPerBar + 1
        let inBar = t % TimelineTime.ticksPerBar
        guard inBar != 0 else { return "Bar \(bar)" }
        return "Bar \(bar) beat \(inBar / TimelineTime.ticksPerBeat + 1)"
    }

    /// Where a scene STARTS a stopped song (S2 review, MED-2): the transport starts on a bar,
    /// so a scene at "Bar 5 beat 3" starts the song at "Bar 5" — the label of the floored tick,
    /// never the scene's own. The floor here matches the transport's (`barStartTick`) only for a
    /// tick inside the song, which a scene tick always is (it is a region's start); the
    /// transport's loop fold has no song length to fold by here.
    nonisolated static func songStartLabel(forTick tick: Int) -> String {
        let t = Swift.max(0, tick)
        return label(forTick: t - t % TimelineTime.ticksPerBar)
    }

    nonisolated static func word(_ state: CellState) -> String? {
        switch state {
        case .idle:     return nil
        case .queued:   return "Queued"
        case .playing:  return "Playing"
        case .stopping: return "Stopping"
        }
    }
}

/// The Session view of the Workstation's song: launch a part, or a whole scene, on the bar.
@MainActor
struct SessionLaunchView: View {

    @Environment(TimelineStore.self) private var timeline
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(ClipStore.self) private var clipStore

    /// Phase 3 / S2 — start the stopped song at a bar WITH a scene's parts. HANDED IN by the
    /// Workstation, whose transport stays the ONE caller of `player.play(`
    /// (`TheWorkstationPlaysTheTimelineTests` A/B): this view never starts the transport itself,
    /// it asks the owner to. The parts ride along (S2 review, MED-1) so the scene lands on the
    /// start bar inside that one call instead of one step later.
    let playFrom: (_ tick: Int, _ parts: [UUID]) -> Void

    var body: some View {
        let document = timeline.document
        let capacity = player.laneVoiceCapacity
        let tracks = SessionGrid.tracks(in: document, voiceCapacity: capacity)
        // Cold inputs only, the transport row's own (#1439): `filledClips` changes on
        // generate/evolve or an import, `preflightTempo` and `audioLanes` are
        // `@ObservationIgnored`. The resolver probes the file system once per audio part.
        let playable = SessionGrid.playableRegionIDs(
            in: document,
            clips: clipStore.filledClips,
            bpm: player.preflightTempo,
            resolveAudio: { player.audioLanes?.resolvedURL(forClipID: $0) })
        let scenes = SessionGrid.scenes(in: document, voiceCapacity: capacity, playable: playable)
        // Subscribes this leaf to launch changes: a tap or a fired bar, never a step.
        let _ = player.launchGeneration
        let playing = player.isPlaying
        if !tracks.isEmpty && !scenes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session")
                    .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
                Text(playing
                     ? "Tap a part to loop it on its track from the next bar. A launched part starts from its top — on the Echoel track it continues where the song is. Launch scene switches: its parts start and every other launched track returns to the song on the same bar."
                     : "Launch a scene to start the song at its bar and loop it, or press Play for the song from the top.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)

                // One read per track per repaint (the repaint is a tap or a fired bar).
                let states = Dictionary(tracks.map { ($0.id, player.launchState(laneID: $0.id)) },
                                        uniquingKeysWith: { first, _ in first })
                let launched = tracks.filter { SessionGrid.isLaunched(states[$0.id] ?? .idle) }
                if playing && !launched.isEmpty {
                    // With one launched track its own Stop row IS "back to song" — one 44-pt row.
                    if launched.count > 1 {
                        backToSongButton
                    }
                    ForEach(launched) { track in
                        stopButton(track)
                    }
                }

                ForEach(scenes.prefix(SessionGrid.sceneLimit)) { scene in
                    sceneBlock(scene, tracks: tracks, playing: playing,
                               state: SessionGrid.sceneState(scene, tracks: tracks, states: states))
                }
                if scenes.count > SessionGrid.sceneLimit {
                    Text("\(scenes.count - SessionGrid.sceneLimit) later scenes are not shown.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                }
            }
            .padding(.top, 4)
        }
    }

    private func sceneBlock(_ scene: SessionGrid.LaunchScene, tracks: [SessionGrid.Track],
                            playing: Bool, state: SessionGrid.CellState?) -> some View {
        let title = SessionGrid.label(forTick: scene.startTick)
        let songStart = SessionGrid.songStartLabel(forTick: scene.startTick)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                if let word = state.flatMap(SessionGrid.word) {
                    Text(word)
                        .font(EchoelTheme.font(11, .semibold))
                        .foregroundStyle(state == .playing ? EchoelTheme.text : EchoelTheme.dim)
                }
                Spacer(minLength: 8)
                Button {
                    launchScene(scene)
                } label: {
                    Text("Launch scene")
                        .font(EchoelTheme.font(12, .semibold))
                        .foregroundStyle(EchoelTheme.text)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                            .fill(EchoelTheme.fill))
                        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                            .strokeBorder(EchoelTheme.border, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // S2: enabled while stopped too — a scene starts the song at its bar. A single
                // PART stays disabled then: which part starts the whole song is not a question
                // one cell can answer.
                .accessibilityLabel("Launch scene at \(title)")
                .accessibilityValue(state.flatMap(SessionGrid.word) ?? "Not the current scene")
                .accessibilityHint(playing
                                   ? "From the next bar, loops every part listed at \(title) and returns every other launched track to the song"
                                   : "Starts the song at the start of \(songStart) and loops every part listed at \(title)")
            }
            ForEach(tracks.filter { scene.cells[$0.id] != nil }) { track in
                if let regionID = scene.cells[track.id] {
                    cellButton(track: track, regionID: regionID, title: title, playing: playing)
                }
            }
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
            .strokeBorder(EchoelTheme.border, lineWidth: 1))
    }

    private func cellButton(track: SessionGrid.Track, regionID: UUID, title: String,
                            playing: Bool) -> some View {
        let state = SessionGrid.cellState(player.launchState(laneID: track.id), regionID: regionID)
        let lit = state == .playing || state == .queued
        return Button {
            player.launchRegion(regionID, quantize: SessionGrid.quantize)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: lit ? "play.fill" : "play")
                    .font(.system(size: 11, weight: .semibold))
                Text(track.name)
                    .font(EchoelTheme.font(12))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let word = SessionGrid.word(state) {
                    Text(word).font(EchoelTheme.font(11, .semibold))
                }
            }
            .foregroundStyle(state == .playing ? EchoelTheme.onPrimary
                                               : (playing ? EchoelTheme.text : EchoelTheme.dim))
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            // Monochrome primary fill, never a green area behind a label (EchoelTheme).
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(state == .playing ? EchoelTheme.text : EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(state == .queued ? EchoelTheme.accent : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!playing)
        .accessibilityLabel("\(track.name), part at \(title)")
        .accessibilityValue(SessionGrid.word(state) ?? "Not launched")
        .accessibilityHint(state == .playing
                           ? "Already looping. Stop the track to hand it back to the song"
                           : "Loops this part on its track from the next bar")
    }

    private func stopButton(_ track: SessionGrid.Track) -> some View {
        Button {
            player.stopLaunched(laneID: track.id, quantize: SessionGrid.quantize)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill").font(.system(size: 11, weight: .semibold))
                Text("Stop \(track.name)").font(EchoelTheme.font(12, .semibold)).lineLimit(1)
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop the launched part on \(track.name)")
        .accessibilityHint("From the next bar the track plays the song again")
    }

    /// A scene is a SWITCH (Phase 3 / S1): one player call, so its parts and the other tracks'
    /// return to the song land on the same bar.
    /// S2: a stopped song is started by the owner at the scene's bar WITH the scene's parts —
    /// one call, so the parts land on that bar before anything sounds (S2 review, MED-1: a
    /// launch after `play` restarted an audio part from the top one step in).
    private func launchScene(_ scene: SessionGrid.LaunchScene) {
        let parts = Array(scene.cells.values)
        if player.isPlaying {
            player.launchScene(parts, quantize: SessionGrid.quantize)
        } else {
            playFrom(scene.startTick, parts)
        }
    }

    /// "Back to song": every launched track returns to the arrangement on the next bar.
    private var backToSongButton: some View {
        Button {
            player.stopAllLaunched(quantize: SessionGrid.quantize)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 11, weight: .semibold))
                Text("Back to song").font(EchoelTheme.font(12, .semibold)).lineLimit(1)
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to song")
        .accessibilityHint("From the next bar every launched track plays the song again")
    }
}
