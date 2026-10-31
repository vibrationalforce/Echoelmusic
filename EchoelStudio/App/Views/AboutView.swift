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
                EchoelSection("Echoel") {
                    ParagraphText("A music workstation for iPhone and iPad: instruments, effects, arrangement, a session view for live sets, mixing and export.")
                    ParagraphText("Around the music: the Field, a picture that moves with the song; the Sky, the stars above you computed for your place and time; Connections, which send OSC, ADM-OSC, Art-Net and sACN to devices you name; and Body, a heart rate strap or the rear camera as a source for modulation.")
                    ParagraphText("Body readings are for self-observation, not a medical diagnosis. Echoel is a tool for making music. It is not a medical product.")
                }
                EchoelSection("Your Data") {
                    ParagraphText("No account, no ads, no tracking, no server of ours. Songs are files on this device, in an open, documented format.")
                    ParagraphText("Echoel uses the network only for the App Store (at launch, to check whether you bought Echoel Plugins, and when you open the store: prices, buying, Restore Purchases), for Network MIDI when you turn it on, for each connection you turn on in Connections, to the address you type, and for a live stream, from Go Live to Stop, to the servers you enter.")
                    ParagraphText("A diagnostics log stays on this device: what the audio and the app did, and how earlier runs ended as iOS reports it — numbers only, never a name you typed. It leaves only when you share it.")
                    // The share comes up once this page has closed: the one sheet slot waits for it.
                    Button("Share Diagnostics") {
                        router.share(DiagnosticLog.app.url)
                        dismiss()
                    }
                    .buttonStyle(EchoelRowButtonStyle())
                }
                EchoelSection("Open Source") {
                    ParagraphText("The source code is public under the MIT licence. These links open in your browser.")
                    if let url = Self.sourceURL { Link("Source Code on GitHub", destination: url) }
                    if let url = Self.siteURL { Link("echoelmusic.com", destination: url) }
                }
                EchoelSection("Acknowledgments") {
                    ParagraphText("Echoel Studio contains the work of others. Each licence, in full:")
                    ForEach(Acknowledgment.all) { acknowledgment in
                        NavigationLink {
                            AcknowledgmentView(acknowledgment: acknowledgment)
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
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
                EchoelSection("This Build") {
                    ValueRow("Version", value: Self.versionText)
                }
            }
            .echoelList()
            .navigationTitle("About Echoel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    /// "11.0.0 (10005)", read from the bundle; a missing key says so instead of guessing.
    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }
}
