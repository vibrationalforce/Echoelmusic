import EchoelCore
import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// What the studio can present. One `.sheet(item:)` serves every case — the presentation
/// chain never grows (the legacy app's black screen came from a growing chain).
enum StudioSheet: Identifiable, Hashable {
    case clipEditor(TrackID)
    /// One clip of a track, as the session or a placement in the arrangement opens it.
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
    /// A new name for the open song, which its package takes too.
    case renameSong
    /// A new name for a track, a clip or a scene.
    case rename(RenameTarget)
    /// Pick a video from the photo library to place at a tick, on a video track or a new one (W7).
    case importVideoFromPhotos(TrackID?, Tick)
    /// The same from the Files app.
    case importVideoFromFiles(TrackID?, Tick)
    /// The rear camera films a take while the song plays, onto a video track or a new one.
    case cameraTake(TrackID?)
    /// The song as an MP4: frame, fit, codec, whole song or a stretch of bars.
    case exportVideo
    /// The live stream: destinations, Go Live and Stop (wave W14).
    case streaming
    /// OSC, ADM-OSC, Art-Net and sACN out, each off until switched on here (wave W4).
    case connections

    var id: Self { self }
}

/// The one owner of what is presented, so any view can ask for a sheet without a second
/// presentation modifier.
@MainActor
@Observable
final class StudioRouter {
    var sheet: StudioSheet?
    /// A finished export or share that found another sheet open. It waits for that one to close
    /// instead of taking the slot from it — an assistant's typed request, an editor in use, a
    /// file picker (audit 2026-10-23).
    @ObservationIgnored private var waitingShare: URL?

    /// The share sheet for `url`, now or as soon as the open sheet closes.
    func share(_ url: URL) {
        if sheet == nil { sheet = .share(url) } else { waitingShare = url }
    }

    /// The slot's sheet closed: a share that waited for it comes up.
    func sheetClosed() {
        guard sheet == nil, let url = waitingShare else { return }
        waitingShare = nil
        sheet = .share(url)
    }
}

/// The system file picker for one audio file — or, given other types, one video. It hands over
/// a copy the app may read freely, so no security scope outlives the pick.
struct AudioFilePicker: UIViewControllerRepresentable {
    let pick: (URL) -> Void
    let cancel: () -> Void
    var types: [UTType] = [.audio]

    func makeCoordinator() -> Coordinator { Coordinator(pick: pick, cancel: cancel) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
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
