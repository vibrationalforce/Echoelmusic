import EchoelCore
import EchoelEngine
import SwiftUI

/// The Jam page (W16; Song menu, Connect, Jam…): host a jam or join one nearby, see who is in it,
/// leave it. Echoel's list look; it reads only the jam's cold state, which changes when the jam
/// does, never with the clock (Law 6).
struct JamView: View {
    @Environment(JamSession.self) private var jam
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                content
                EchoelSection {
                    NoteText("Only timing travels between the phones: the host's tempo, time signature, Play and Stop and where its bars begin, and each phone's name. No audio, no song, no body values. The phones talk to each other directly over Wi-Fi or Bluetooth, encrypted; no router and no internet are needed.")
                }
            }
            .echoelList()
            .navigationTitle("Jam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        switch jam.role {
        case .off: offSections
        case .hosting: hostingSections
        case .looking: lookingSections(joining: nil)
        case .joining(let host): lookingSections(joining: host)
        case .joined(let host): joinedSections(host)
        }
    }

    // MARK: - Off

    @ViewBuilder private var offSections: some View {
        EchoelSection {
            ParagraphText("Play together on phones in the same room. The host sets the tempo, the time signature, Play and Stop; everyone else comes in on the host's next bar and stays in step.")
            Button("Host a Jam") { jam.host() }
                .buttonStyle(EchoelRowButtonStyle())
                .accessibilityHint("Lets phones nearby join and follow this one.")
            Button("Join a Jam") { jam.look() }
                .buttonStyle(EchoelRowButtonStyle())
                .accessibilityHint("Looks for a jam hosted on a phone nearby.")
        }
        problemSection
    }

    // MARK: - Hosting

    @ViewBuilder private var hostingSections: some View {
        EchoelSection("Hosting") {
            ParagraphText("Phones nearby join from Song menu, Jam, Join a Jam. They play your tempo, time signature, Play and Stop, and come in on your next bar.")
        }
        playersSection
        EchoelSection(footer: "Everyone else plays on at the last tempo until they leave.") {
            Button("End Jam", role: .destructive) { jam.leave() }
                .buttonStyle(EchoelRowButtonStyle())
        }
    }

    // MARK: - Looking and joining

    @ViewBuilder private func lookingSections(joining: JamPeer?) -> some View {
        let labels = JamPeer.labels(jam.nearby.map(\.name))
        EchoelSection("Jams Nearby") {
            if jam.nearby.isEmpty {
                NoteText("Looking for a jam nearby. Ask someone in the room to choose Host a Jam.")
            }
            ForEach(Array(jam.nearby.enumerated()), id: \.element.id) { index, host in
                Button { jam.join(host) } label: {
                    HStack(spacing: Theme.Space.s) {
                        Text(index < labels.count ? labels[index] : host.name)
                        Spacer(minLength: Theme.Space.s)
                        if host == joining {
                            Text("Joining…")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                }
                .buttonStyle(EchoelRowButtonStyle())
                .disabled(joining != nil)
                .accessibilityHint("Joins this jam.")
            }
        }
        problemSection
        EchoelSection {
            Button("Stop Looking") { jam.leave() }
                .buttonStyle(EchoelRowButtonStyle())
        }
    }

    // MARK: - Joined

    @ViewBuilder private func joinedSections(_ host: JamPeer) -> some View {
        EchoelSection("Following \(host.name)") {
            ValueRow("Tempo", value: jam.followedTempo.map { NumberText.string($0, decimalsUpTo: 2, unit: "BPM") } ?? "–")
            ValueRow("Time Signature", value: jam.followedSignature.map { "\($0.numerator)/\($0.denominator)" } ?? "–")
            NoteText(jam.followText, tone: jam.hostIsGone ? .warning : .note)
        }
        playersSection
        EchoelSection(footer: "Your song's own tempo and time signature come back when you leave.") {
            Button("Leave", role: .destructive) { jam.leave() }
                .buttonStyle(EchoelRowButtonStyle())
        }
    }

    // MARK: - Shared

    private var playersSection: some View {
        EchoelSection("Players") {
            ForEach(Array(jam.members.enumerated()), id: \.offset) { index, name in
                Text(index == 0 ? "\(name) (Host)" : name)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.text)
                    .frame(minHeight: Theme.Size.touch)
            }
        }
    }

    @ViewBuilder private var problemSection: some View {
        if let problem = jam.problem {
            EchoelSection {
                NoteText(problem, tone: .problem)
            }
        }
    }
}
