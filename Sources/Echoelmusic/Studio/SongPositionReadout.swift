//
//  SongPositionReadout.swift
//  Echoelmusic
//
//  The Workstation's song position as a NUMBER — "Bar 12 · Beat 3" — beside Play/Stop while the
//  timeline plays (modes census 2026-09-26, design D1: the canvas playhead says WHERE on the
//  picture, nothing said WHICH bar). It is the arrangement's position, not the instrument's
//  loop position (`TransportPositionView` in the header, which folds by `loopBars`).
//
//  ⭐ A LEAF IN ITS OWN FILE, AND THAT IS THE WHOLE DESIGN. `TimelineRegionPlayer.currentTick` is
//  `@ObservationIgnored`, so a body that reads it neither subscribes nor updates — it would show
//  a stale number forever. This leaf self-drives at 15 Hz with a `TimelineView` exactly like
//  `ArrangePlayheadView`, paused while stopped, so no ancestor ever reads the position (the
//  10.76.41/50 freeze law). `WorkstationView` may not name `currentTick` at all
//  (`TheWorkstationPlaysTheTimelineTests` claim J); it mounts this view and nothing else.
//
//  The words come from `WorkstationSummary.positionText(forTick:)` — one bar-number rule
//  (`barNumber(forTick:)`), driven by the blocking bundle.
//

import SwiftUI

struct SongPositionReadout: View {

    @Environment(TimelineRegionPlayer.self) private var player

    var body: some View {
        let playing = player.isPlaying
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing)) { _ in
            if playing {
                let text = WorkstationSummary.positionText(forTick: player.currentTick)
                Text(text)
                    .font(EchoelTheme.font(13, .semibold).monospacedDigit())
                    .foregroundStyle(EchoelTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel("Position in the piece")
                    .accessibilityValue(text)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }
}
