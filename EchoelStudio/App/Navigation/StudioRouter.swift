import EchoelCore
import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// What the studio can present. One `.sheet(item:)` serves every case — the presentation
/// chain never grows (the legacy app's black screen came from a growing chain).
enum StudioSheet: Identifiable, Hashable {
    case clipEditor(TrackID)
    /// One clip of a track, as the session opens it.
    case clip(TrackID, ClipID)
    case share(URL)
    /// Pick an audio file to place on an audio track at a tick.
    case importAudio(TrackID, Tick)
    /// Pick an audio file to become a clip in an audio track's session slot.
    case importClip(TrackID, SceneID)
    /// A track's insert effects.
    case effects(TrackID)
    /// The master's insert effects.
    case masterEffects
    /// Echoel's own Audio Units, to buy for other apps.
    case store
    /// The assistant: change the song by asking.
    case agent
    /// What Echoel is, what this build holds, and what happens to the musician's data.
    case about

    var id: Self { self }
}

/// The one owner of what is presented, so any view can ask for a sheet without a second
/// presentation modifier.
@MainActor
@Observable
final class StudioRouter {
    var sheet: StudioSheet?
}

/// The system file picker for one audio file. It hands over a copy the app may read freely,
/// so no security scope outlives the pick.
struct AudioFilePicker: UIViewControllerRepresentable {
    let pick: (URL) -> Void
    let cancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(pick: pick, cancel: cancel) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let pick: (URL) -> Void
        let cancel: () -> Void

        init(pick: @escaping (URL) -> Void, cancel: @escaping () -> Void) {
            self.pick = pick
            self.cancel = cancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { pick(url) } else { cancel() }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { cancel() }
    }
}

/// The system share sheet for an exported file: save to Files, AirDrop, open in another app.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
