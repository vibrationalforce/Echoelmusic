// ShareSheet.swift
// Echoel — the system share sheet (UIActivityViewController) used to hand an
// exported file (e.g. a .mid from BeatTab) to another app. Tiny, self-contained
// wrapper; lives here in the active Studio flow.

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    /// GMMW VV-11 — the sheet never offers "Save Video" / "Save Image". Saving to the photo
    /// library needs `NSPhotoLibraryAddUsageDescription`, which the plist no longer carries
    /// (#1415), and iOS TERMINATES the app when that action runs without it. Today the sheet
    /// shares audio and MIDI only, so the row would not even appear; the day a movie or a picture
    /// reaches it, this keeps the crash out. `ShareLink` cannot exclude an activity, so a movie
    /// must be shared through this sheet. Restoring the key is what lifts the exclusion.
    static let excludedActivities: [UIActivity.ActivityType] = [.saveToCameraRoll]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.excludedActivityTypes = Self.excludedActivities
        return sheet
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
