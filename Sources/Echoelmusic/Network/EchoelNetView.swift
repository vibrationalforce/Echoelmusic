#if canImport(SwiftUI)
import SwiftUI

/// EchoelNet panel — OSC networking + Ableton Link sync
struct EchoelNetView: View {

    var body: some View {
        VStack(spacing: EchoelSpacing.lg) {
            VaporwaveSectionHeader("EchoelNet", icon: "network")

            // OSC Settings
            OSCSettingsView()

            // Ableton Link
            AbletonLinkView(client: EchoelCreativeWorkspace.shared.linkClient)

            Spacer(minLength: 0)
        }
        .padding(EchoelSpacing.md)
    }
}
#endif
