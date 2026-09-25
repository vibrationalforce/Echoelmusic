//
//  EchoelInstanceLine.swift
//  Echoelmusic — Studio (WA4 path 9 follow-up: "this track's Echoel" says what it is set to)
//
//  WHY THIS EXISTS. The Echoel track's device row named the device and opened its editor, and
//  said nothing about the instance — which genre it composes in and which FX character colours
//  it. `EchoelInstanceState` (WA3 slice 2) is the read-only assembly of that state; this line
//  shows the two parts of it a player recognises a sound by, on the track that plays it.
//
//  ⭐ READ-ONLY, AND FROM THE SAME OWNERS. Both values are read through the SAME keys the
//  instrument writes (`StudioDefaultKeys.genre`, `EchoelInstanceState.fxCharacterKey`) and
//  resolved through their TYPES, so a retired raw value shows the default the instrument
//  actually plays — exactly as `EchoelInstanceState.assemble` resolves it. Nothing here writes;
//  the editor is the Sound plate behind "Open".
//  ⚠️ `.auto` repeats the instrument's declared FX default — the same one second default
//  `EchoelInstanceState` names and keeps, because `.auto` is the type's own "defer to the
//  genre" case, not a tuned number.
//
//  ⚠️ NOT THE WHOLE INSTANCE. The patch is view-private state of the instrument
//  (`currentPatch`), so its name is not shown here rather than guessed; mood, rhythm characters
//  and the role mix are left out on purpose — this is a label, not a second editor.
//
//  ⚠️ IT IS ITS OWN FILE BECAUSE THE INSPECTOR OWNS NO PERSISTENCE (its guard bans
//  `@AppStorage` there). This leaf only READS two keys, at selection rate — both change on a
//  picker, a reset or an Open, never on a clock — so it is safe in the Workstation plate.
//

import SwiftUI

struct EchoelInstanceLine: View {

    @AppStorage(StudioDefaultKeys.genre.key) private var genre: MusicStyle = StudioDefaultKeys.genre.value
    @AppStorage(EchoelInstanceState.fxCharacterKey) private var character: FXCharacter = .auto

    var body: some View {
        // One row where it fits, the two facts stacked where it does not (large type, a narrow
        // phone) — never a truncated genre name.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { genreFact; characterFact }
            VStack(alignment: .leading, spacing: 2) { genreFact; characterFact }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Echoel plays \(genre.displayName), FX character \(character.displayName)")
    }

    private var genreFact: some View { fact("Genre", genre.displayName) }
    private var characterFact: some View { fact("FX", character.displayName) }

    private func fact(_ name: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(name).font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Text(value).font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.text)
        }
        .fixedSize()
    }
}
