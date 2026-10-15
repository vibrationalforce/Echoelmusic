// PieceRoll.swift
// Echoel — Roll + Lock (founder 2026-10-15, after Synth Palace's Synth Shaper: one dice re-rolls
// every layer that is not locked). Here a "layer" is a composer track: "Roll" gives every composing
// track that is not locked a fresh variation, and "Keep on Roll" on a track's Device page keeps it.
//
// ⭐ NOTHING NEW COMPOSES HERE. A roll only stores fresh variation seeds through the one writer
// "New variation" already uses (`TrackCompose.setVariation`), then asks the instrument to compose
// once (`.echoelCompositionEdited` "roll" → `recomposeIfRunning`). The notes arrive the way they do
// for "New variation": at once while the instrument runs, otherwise on its next Start.
//
// ⚠️ THE ECHOEL TRACK IS NOT ROLLED: it follows the body, and the note says so. A roll makes no
// track and turns no composer on — on a piece with nothing composing, it says where to start.
// Like "New variation", a roll is not on Undo; "Keep take" is how a take you like is kept.

import Foundation

enum PieceRoll {

    /// The field the studio's composition-edit handler answers with one recompose (#416).
    static let rollField = "roll"

    struct Outcome: Equatable, Sendable {
        /// Tracks that got a fresh variation.
        var rolled: Int
        /// Composing tracks a lock kept.
        var kept: Int
    }

    /// The composing tracks a roll changes, and those a lock keeps — in track order. Pure.
    nonisolated static func split(in document: TimelineDocument, clips: [Clip],
                                  loopBars: Int) -> (roll: [UUID], kept: [UUID]) {
        var roll: [UUID] = []
        var kept: [UUID] = []
        for lane in document.lanes where lane.id != document.rollLaneID {
            guard TrackCompose.isComposing(lane.id, in: document, clips: clips, loopBars: loopBars) else { continue }
            if lane.isRollLocked { kept.append(lane.id) } else { roll.append(lane.id) }
        }
        return (roll, kept)
    }

    /// Roll: a fresh variation for every composing track that is not locked.
    @MainActor
    static func roll(timeline: TimelineStore, clips: [Clip], loopBars: Int,
                     seed: () -> UInt64 = TrackCompose.freshSeed) -> Outcome {
        let tracks = split(in: timeline.document, clips: clips, loopBars: loopBars)
        for laneID in tracks.roll {
            TrackCompose.setVariation(laneID, seed: seed(), timeline: timeline)
        }
        return Outcome(rolled: tracks.roll.count, kept: tracks.kept.count)
    }

    /// Ask the instrument to compose once — only when something was rolled.
    @MainActor
    static func requestCompose(after outcome: Outcome) {
        guard outcome.rolled > 0 else { return }
        NotificationCenter.default.post(name: .echoelCompositionEdited, object: rollField)
    }

    /// "Keep on Roll" — the lock's one writer, so the Device page touches the store through here.
    @MainActor
    static func setLocked(_ laneID: UUID, locked: Bool, timeline: TimelineStore) {
        timeline.setLaneRollLocked(laneID, locked: locked)
    }

    /// The sentence after a roll.
    nonisolated static func note(_ outcome: Outcome) -> String {
        if outcome.rolled == 0 && outcome.kept == 0 {
            return String(localized: "Nothing to roll yet: turn on Compose here on a synth track's Device page.")
        }
        if outcome.rolled == 0 {
            return String(localized: "Every composing track is kept. Turn off Keep on Roll to roll one.")
        }
        var sentence = String(localized: "Rolled tracks: ") + "\(outcome.rolled)."
        if outcome.kept > 0 {
            sentence += " " + String(localized: "Kept: ") + "\(outcome.kept)."
        }
        return sentence + " " + String(localized: "The new lines play when the instrument composes. The Echoel track follows your body.")
    }
}
