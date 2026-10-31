import EchoelCore
import SwiftUI

/// What Echoel is, what this build holds, and what happens to the musician's data. Every
/// sentence here describes this build; nothing promises a date. The page reads nothing that
/// changes while it is open.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioRouter.self) private var router

    private static let sourceURL = URL(string: "https://github.com/vibrationalforce/Echoelmusic")
    private static let siteURL = URL(string: "https://echoelmusic.com")

    var body: some View {
        NavigationStack {
            List {
                Section("Echoel") {
                    paragraph("A music workstation for iPhone and iPad: instruments, effects, arrangement, a session view for live sets, mixing and export.")
                    paragraph("Body signals, visuals, light and spatial output are not in this build. They are planned as separate modules, each added when it works.")
                    paragraph("Echoel is a tool for making music. It is not a medical product.")
                }
                Section("Your data") {
                    paragraph("No account, no ads, no tracking, no server of ours. Songs are files on this device, in an open, documented format.")
                    paragraph("Echoel uses the network only for the App Store (at launch, to check whether you bought Echoel Plugins, and when you open the store: prices, buying, Restore Purchases), for Network MIDI when you turn it on, and for a live stream, from Go Live to Stop, to the servers you enter.")
                    paragraph("A diagnostics log stays on this device: what the audio and the app did, and how earlier runs ended as iOS reports it — numbers only, never a name you typed. It leaves only when you share it.")
                    // The share comes up once this page has closed: the one sheet slot waits for it.
                    Button("Share Diagnostics") {
                        router.share(DiagnosticLog.app.url)
                        dismiss()
                    }
                }
                Section("Open source") {
                    paragraph("The source code is public under the MIT licence. These links open in your browser.")
                    if let url = Self.sourceURL { Link("Source code on GitHub", destination: url) }
                    if let url = Self.siteURL { Link("echoelmusic.com", destination: url) }
                }
                Section("Acknowledgments") {
                    paragraph("Echoel Studio contains the work of others. Each licence, in full:")
                    ForEach(Acknowledgment.all) { acknowledgment in
                        NavigationLink {
                            AcknowledgmentView(acknowledgment: acknowledgment)
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Space.xs / 2) {
                                Text(acknowledgment.name)
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Color.text)
                                Text(acknowledgment.licence)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                Section("This build") {
                    paragraph(Self.versionLine)
                }
            }
            .navigationTitle("About Echoel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.text)
            .padding(.vertical, Theme.Space.xs)
    }

    /// "Version 11.0.0 (10005)", read from the bundle; a missing key says so instead of guessing.
    private static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return "Version \(version) (\(build))"
    }
}
