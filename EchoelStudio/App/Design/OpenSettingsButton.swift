import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A permission turned off for Echoelmusic can only be turned on again in Settings: this opens the
/// app's own page there, next to the sentence that says so (audit 2026-11-19: five such sentences
/// named a path through Settings, and none had a way to go there).
struct OpenSettingsButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Button("Open Settings") { openURL(url) }
                .buttonStyle(ToolButtonStyle())
                .accessibilityHint("Opens Echoelmusic's page in the Settings app.")
        }
        #endif
    }
}
