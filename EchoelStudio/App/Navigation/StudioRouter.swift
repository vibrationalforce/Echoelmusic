import EchoelCore
import Observation
import SwiftUI
import UIKit

/// What the studio can present. One `.sheet(item:)` serves every case — the presentation
/// chain never grows (the legacy app's black screen came from a growing chain).
enum StudioSheet: Identifiable, Hashable {
    case clipEditor(TrackID)
    case share(URL)

    var id: Self { self }
}

/// The one owner of what is presented, so any view can ask for a sheet without a second
/// presentation modifier.
@MainActor
@Observable
final class StudioRouter {
    var sheet: StudioSheet?
}

/// The system share sheet for an exported file: save to Files, AirDrop, open in another app.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
