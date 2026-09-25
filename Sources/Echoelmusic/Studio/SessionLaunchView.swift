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
//  ⚠️ ONLY LAUNCHABLE TRACKS ARE SHOWN, by the engine's own gate: `launchRegion` refuses bio,
//  video and visual lanes, so they get no column here (the #164/#227 "no control that does
//  nothing" law). And launching is disabled while the song is stopped, because the engine
//  no-ops then; the caption says so instead of offering a tap that does nothing.
//  ⚠️ KNOWN LIMIT, stated rather than hidden: a secondary MIDI track beyond the lane rack's
//  capacity has no physical voice. Its launch is recorded (the state reads "Playing") but it
//  stays as silent as it is in the arrangement. The rack capacity is private to the player;
//  exposing it is a separate slice.
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

    /// Tracks the engine will launch on: MIDI and audio lanes that are not bio, in
    /// document order. Mirrors the refusal in `TimelineRegionPlayer.launchRegion`.
    nonisolated static func tracks(in document: TimelineDocument) -> [Track] {
        document.lanes
            .filter { !$0.isBio && ($0.kind == .midi || $0.kind == .audio) }
            .map { Track(id: $0.id, name: $0.name) }
    }

    /// One scene per distinct tick at which a part starts on a launchable track, ascending.
    /// Each cell is `activeRegion`'s answer at that tick, so a part that started earlier and
    /// is still playing belongs to the scene too — the scene is "what the song plays here".
    nonisolated static func scenes(in document: TimelineDocument) -> [LaunchScene] {
        let trackIDs = tracks(in: document).map(\.id)
        let launchable = Set(trackIDs)
        let starts = Set(document.regions
            .filter { launchable.contains($0.laneID) && $0.lengthTicks > 0 }
            .map(\.startTick))
        return starts.sorted().map { tick in
            var cells: [UUID: UUID] = [:]
            for laneID in trackIDs {
                if let region = TimelineScheduling.activeRegion(in: document, laneID: laneID, at: tick) {
                    cells[laneID] = region.id
                }
            }
            return LaunchScene(startTick: tick, cells: cells)
        }
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

    var body: some View {
        let document = timeline.document
        let tracks = SessionGrid.tracks(in: document)
        let scenes = SessionGrid.scenes(in: document)
        // Subscribes this leaf to launch changes: a tap or a fired bar, never a step.
        let _ = player.launchGeneration
        let playing = player.isPlaying
        if !tracks.isEmpty && !scenes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session")
                    .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
                Text(playing
                     ? "Tap a part to loop it on its track from the next bar. Stop hands the track back to the song."
                     : "Play the song to launch parts.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)

                let launched = tracks.filter { SessionGrid.isLaunched(player.launchState(laneID: $0.id)) }
                if playing && !launched.isEmpty {
                    ForEach(launched) { track in
                        stopButton(track)
                    }
                }

                ForEach(scenes.prefix(SessionGrid.sceneLimit)) { scene in
                    sceneBlock(scene, tracks: tracks, playing: playing)
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
                            playing: Bool) -> some View {
        let title = SessionGrid.label(forTick: scene.startTick)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                Spacer(minLength: 8)
                Button {
                    launchScene(scene)
                } label: {
                    Text("Launch scene")
                        .font(EchoelTheme.font(12, .semibold))
                        .foregroundStyle(playing ? EchoelTheme.text : EchoelTheme.dim)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                            .fill(EchoelTheme.fill))
                        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                            .strokeBorder(playing ? EchoelTheme.border : Color.clear, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!playing)
                .accessibilityLabel("Launch scene at \(title)")
                .accessibilityHint("Loops every part the song plays at \(title), from the next bar")
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
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(state == .playing ? EchoelTheme.accent : EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(state == .queued ? EchoelTheme.accent : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!playing)
        .accessibilityLabel("\(track.name), part at \(title)")
        .accessibilityValue(SessionGrid.word(state) ?? "Not launched")
        .accessibilityHint("Loops this part on its track from the next bar")
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

    private func launchScene(_ scene: SessionGrid.LaunchScene) {
        for (_, regionID) in scene.cells.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            player.launchRegion(regionID, quantize: SessionGrid.quantize)
        }
    }
}
