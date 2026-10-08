//
//  TrackComposeRows.swift
//  Echoelmusic — Studio (GMMW GA-1: a track composes in its own style)
//
//  WHY THIS EXISTS. The per-track composer was built (Slice A/A2, 2026-07-17): the instrument's
//  every take fans out to each rack track that carries its own style, mood or variation
//  (`LaneComposerInput.composeLaneOverrides`) and writes that track's notes into its composer
//  part (`ClipStore.updateComposerMelody`). Its three lane setters had no caller, so no track
//  could ask for it. These rows are the door, on the Device page of a rack track only.
//
//  WHAT THE ROWS DO.
//  · "Compose here" on: the track gets a composer part in the loop (`ensureComposerRegion`, one
//    undo step) and, when it carries no choice yet, a variation of its own — so it composes a
//    different line from the instrument against the SAME body. Its notes arrive the next time
//    the instrument composes (on Start, and as it evolves); nothing composes from here.
//  · Off: the track's style and variation go back to "follow the piece" and the fan-out leaves
//    it alone. The composer's part keeps its last notes — Edit a copy and Remove are on the part bar.
//  · Style: "Follow the piece" or one offered style. New variation: a fresh detail seed.
//
//  ⚠️ ON IS ONE RULE: the track carries a choice (the fan-out's own `hasOverride`) AND has a
//  composer part in the loop (`TimelineStore.hasComposerPart`, the question `ensureComposerRegion`
//  asks). An Undo that removes the part therefore shows Off, and a tap places it again.
//  ⚠️ REFUSED, WITH A SENTENCE, WHERE IT WOULD SILENCE THE PERSON'S OWN PART: a user part that starts
//  inside the loop would lose every tick the composer's part covers (`activeRegion` gives the tie to
//  the later region) — the import's rule, asked here (`MIDIImport.userPartWouldBeShadowed`). And on a
//  full part grid, where nothing is displaced.
//  ⚠️ The lane fields are not on Undo (`setLaneGenreOverride`'s own contract); the part is.
//
//  Cold reads only. The part grid moves when the instrument composes (~25–45 s), never on a clock,
//  and it is read in `TrackComposeRows`'s body only — the Style menu lives in its own leaf
//  (`TrackComposeStylePicker`), which reads the timeline alone, so a take landing never rebuilds an
//  open menu (10.76.41/50).
//

import SwiftUI

/// The pure half of "Compose here".
enum TrackCompose {

    /// Why "Compose here" cannot turn on.
    enum Refusal: Equatable, Sendable {
        /// A part of the person's own starts inside the loop; the composer's part would play over it.
        case ownPart
        /// Every part slot is in use; nothing is displaced.
        case gridFull

        var sentence: String {
            switch self {
            case .ownPart:
                return String(localized: "Compose here is off: this track has a part of your own in the loop, and the composer's part would play over it.")
            case .gridFull:
                return String(localized: "Compose here is off: the part grid is full.")
            }
        }
    }

    /// The rows are offered on a rack track only: the Echoel track IS the instrument's own part, a
    /// track past the rack has no voice to play what it composes, and audio, bio and video tracks
    /// hold no notes.
    nonisolated static func offered(_ role: TrackMix.Role) -> Bool {
        if case .laneSynth = role { return true }
        return false
    }

    /// The loop the composer writes into, in ticks — the instrument's loop length.
    nonisolated static func windowTicks(loopBars: Int) -> Int {
        Swift.max(1, loopBars) * TimelineTime.ticksPerBar
    }

    /// On: the track carries a choice of its own AND has a composer part in the loop.
    nonisolated static func isComposing(_ laneID: UUID, in document: TimelineDocument,
                                        clips: [Clip], loopBars: Int) -> Bool {
        guard let lane = document.lanes.first(where: { $0.id == laneID }) else { return false }
        return LaneComposerInput.hasOverride(lane)
            && TimelineStore.hasComposerPart(onLane: laneID, in: document, clips: clips,
                                             windowTicks: windowTicks(loopBars: loopBars))
    }

    /// Whether turning on would play over the person's own part — the import's rule (#416).
    nonisolated static func wouldCoverOwnPart(_ laneID: UUID, in document: TimelineDocument,
                                              clips: [Clip], loopBars: Int) -> Bool {
        MIDIImport.userPartWouldBeShadowed(onLane: laneID, in: document, clips: clips,
                                           windowTicks: windowTicks(loopBars: loopBars))
    }

    /// Turn the track's composer on: the part first (one undo step), then — only if the part is
    /// there and the track carries no choice yet — a variation of its own, so nothing composes for
    /// a track with nowhere to land. Returns why it refused, or nil.
    @MainActor
    static func turnOn(_ laneID: UUID, timeline: TimelineStore, clips: ClipStore, loopBars: Int,
                       seed: UInt64) -> Refusal? {
        guard let lane = timeline.document.lanes.first(where: { $0.id == laneID }) else { return nil }
        if wouldCoverOwnPart(laneID, in: timeline.document, clips: clips.filledClips, loopBars: loopBars) {
            return .ownPart
        }
        guard timeline.ensureComposerRegion(for: laneID, clipStore: clips,
                                            loopBars: Swift.max(1, loopBars)) else { return .gridFull }
        if !LaneComposerInput.hasOverride(lane) {
            timeline.setLaneVariationSeed(laneID, seed: seed)
        }
        return nil
    }

    /// Turn it off: the style and the variation back to "follow the piece". The composer's part
    /// stays as it is. ⚠️ The lane's MOOD is not touched on purpose: no row sets it, so it is nil on
    /// every document, and leaving `setLaneMood` without a caller keeps that provable
    /// (`ALaneSurvivesAFieldItDoesNotKnowTests`). A mood row would clear it here too.
    @MainActor
    static func turnOff(_ laneID: UUID, timeline: TimelineStore) {
        timeline.setLaneGenreOverride(laneID, genre: nil)
        timeline.setLaneVariationSeed(laneID, seed: nil)
    }

    /// A fresh detail seed. Random in the UI on purpose; the engine stays deterministic because
    /// the rolled value is stored and replayed (`setLaneVariationSeed`'s own contract).
    nonisolated static func freshSeed() -> UInt64 {
        UInt64.random(in: UInt64.min...UInt64.max)
    }
}

/// GA-1 — "Compose here", its Style and New variation, on a rack track's Device page.
@MainActor
struct TrackComposeRows: View {
    let laneID: UUID
    @Environment(TimelineStore.self) private var timeline
    /// Cold: the grid moves when the instrument composes, never on a clock — read here, never in
    /// the Style menu's leaf.
    @Environment(ClipStore.self) private var clipStore
    @AppStorage(StudioDefaultKeys.loopBars.key) private var loopBars: LoopBarLength = StudioDefaultKeys.loopBars.value
    /// The last refusal, shown under the switch until the next tap.
    @State private var refusal: TrackCompose.Refusal?

    var body: some View {
        let document = timeline.document
        let composing = TrackCompose.isComposing(laneID, in: document, clips: clipStore.filledClips,
                                                 loopBars: loopBars.rawValue)
        let covers = !composing && TrackCompose.wouldCoverOwnPart(laneID, in: document,
                                                                  clips: clipStore.filledClips,
                                                                  loopBars: loopBars.rawValue)
        VStack(alignment: .leading, spacing: EchoelTheme.spaceS) {
            Toggle(isOn: Binding(get: { composing }, set: { on in toggle(on) })) {
                Text("Compose here")
                    .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
            }
            .tint(EchoelTheme.accent)
            .disabled(covers)
            .accessibilityHint(covers
                ? TrackCompose.Refusal.ownPart.sentence
                : String(localized: "The instrument also composes this track, in its own style, from the same body. Its notes arrive the next time the instrument composes: on Start, and as it evolves."))
            if covers {
                Text(TrackCompose.Refusal.ownPart.sentence)
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            } else if let refusal {
                Text(refusal.sentence)
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if composing {
                TrackComposeStylePicker(laneID: laneID)
                Button {
                    timeline.setLaneVariationSeed(laneID, seed: TrackCompose.freshSeed())
                } label: {
                    HStack(spacing: EchoelTheme.spaceXS) {
                        Image(systemName: "dice").font(EchoelTheme.font(11, .semibold))
                        Text("New variation").font(EchoelTheme.font(11, .semibold)).lineLimit(1).fixedSize()
                    }
                }
                .buttonStyle(EchoelToolButtonStyle())
                .accessibilityLabel("New variation: this track composes a different line the next time the instrument composes; its style stays")
                Text("Its notes arrive the next time the instrument composes. Off keeps the composer's part as it is.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func toggle(_ on: Bool) {
        if on {
            refusal = TrackCompose.turnOn(laneID, timeline: timeline, clips: clipStore,
                                          loopBars: loopBars.rawValue, seed: TrackCompose.freshSeed())
        } else {
            refusal = nil
            TrackCompose.turnOff(laneID, timeline: timeline)
        }
    }
}

/// The track's own Style — its own leaf, so the menu's host reads the timeline and nothing that
/// moves when the instrument composes (10.76.41/50).
@MainActor
private struct TrackComposeStylePicker: View {
    let laneID: UUID
    @Environment(TimelineStore.self) private var timeline

    var body: some View {
        let current = timeline.document.lanes.first(where: { $0.id == laneID })?.genreOverride
        HStack(spacing: EchoelTheme.spaceS) {
            Text("Style")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Picker("Style", selection: Binding<MusicStyle?>(
                get: { current },
                set: { timeline.setLaneGenreOverride(laneID, genre: $0) })) {
                Text("Follow the piece").tag(MusicStyle?.none)
                // A style an older build stored and the menu no longer offers stays visible as
                // the current value, never offered anew (the instrument row's rule).
                if let current, !MusicStyle.offered.contains(current) {
                    Text(current.displayName).tag(MusicStyle?.some(current))
                }
                ForEach(MusicStyle.Subcategory.allCases) { shelf in
                    if !shelf.offeredGenres.isEmpty {
                        Section(shelf.title) {
                            ForEach(shelf.offeredGenres) { style in
                                Text(style.displayName).tag(MusicStyle?.some(style))
                            }
                        }
                    }
                }
            }
            .pickerStyle(.menu).tint(EchoelTheme.text)
            .accessibilityHint("The style this track composes in. Follow the piece uses the instrument's style")
            Spacer(minLength: 0)
        }
    }
}
