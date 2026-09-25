//
//  NoteNamingReader.swift
//  Echoelmusic — Studio (Phase 3 / MIDI editor, M4 review)
//
//  Hands the reader's note-name system (the "Note names" setting, `StudioDefaultKeys.noteNaming`)
//  to a view that must not own a preference itself. The note editor names the session key on its
//  key row; `MusicalKey.name` is the ENGLISH interop spelling, so with German selected that row
//  said "B Minor" while the key picker said "H Minor" (M4 review). The editor's files are held to
//  "no `UserDefaults` / `@AppStorage`" by their guards — they edit through one writer and persist
//  nothing — so the one read of this DISPLAY preference lives here, in a leaf of its own, and the
//  editor receives a plain `NoteNaming` value. It changes only when the setting does.
//

import SwiftUI

/// Reads the note-name setting and hands it to `content`.
struct NoteNamingReader<Content: View>: View {

    @AppStorage(StudioDefaultKeys.noteNaming.key)
    private var noteNamingRaw = StudioDefaultKeys.noteNaming.value
    private let content: (NoteNaming) -> Content

    init(@ViewBuilder content: @escaping (NoteNaming) -> Content) {
        self.content = content
    }

    var body: some View {
        content(NoteNaming(stored: noteNamingRaw))
    }
}
