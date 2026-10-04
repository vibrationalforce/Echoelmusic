//
//  PieceLightLookField.swift
//  Echoelmusic — Restructure P2 (founder 2026-10-04: "Speichere lookIntensity als kreativen
//  Zustand des Stücks über den bestehenden Projektpfad").
//
//  The ONE door to the piece's light look: a number field on the Project plate. It writes the
//  DOCUMENT (`TimelineStore.editLightLook` / `commitLightLook`), never `LightingStore` — the app
//  projects the document into the owner through the canonical parameter, so the rig follows an
//  edit, an Undo, an Open and a switch between two pieces by the same road.
//
//  Accessibility, all from `EchoelValueField`: a named row ("Light look"), the value drawn as a
//  number, a tap opens the keypad (the alternative to the vertical drag), VoiceOver adjusts by
//  swipe, "Default" puts back 1.00, and at accessibility text sizes the label stacks above the
//  box. One gesture is one Undo step (`.lightLook`), the mixer's contract.
//
//  ⚠️ Not hot: the document changes on a gesture, never per frame, so this leaf reads it in its
//  own body (10.76.50 law — and it would be safe one level up as well).
//  ⚠️ What a person SEES move is the rig, and only with a light output connected (Routing). The
//  senders ramp to the new look at the flash-law rate (`LightingStore.maxLookChangePerSecond`),
//  so a jump arrives as a fade. NEEDS-FOUNDER-VERIFY: a fixture on Art-Net or sACN dims when the
//  field goes down, and a second piece opens at its own look.
//

import SwiftUI

struct PieceLightLookField: View {
    @Environment(TimelineStore.self) private var timeline

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            EchoelValueField(
                label: "Light look",
                value: Binding(
                    get: { Double(timeline.lightLook) },
                    set: { newLook in timeline.editLightLook(Float(newLook)) }),
                range: 0...1,
                decimals: 2,
                hint: String(localized: "How bright this piece lets the light rig go. 1 is full, 0 is dark."),
                standard: Double(LightingStore.defaultLookIntensity),
                onCommit: { timeline.commitLightLook() })
            Text("Saved with the piece. A connected light rig fades to it.")
                .font(EchoelTheme.font(12))
                .foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
