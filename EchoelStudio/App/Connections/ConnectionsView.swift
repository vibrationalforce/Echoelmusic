import EchoelCore
import SwiftUI

/// The Connections panel: one row of switches per protocol, each with the address it sends to,
/// the one switch that lets the body out, and a status line per live connection. Every switch
/// starts off at launch and says what it sends before it is turned on. The panel body reads only
/// cold settings; the moving counters are read by `ConnectionActivityLine`, a leaf (Law 6).
struct ConnectionsView: View {
    @Environment(ConnectionsController.self) private var connections
    @Environment(HeartRateStrap.self) private var strap
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                bodySection
                ForEach(ConnectionsController.Kind.allCases) { kind in
                    ConnectionSection(kind: kind)
                }
                Section {
                    note("Every connection is off when Echoel starts, and its socket exists only while it is on. All four protocols are plain UDP, unencrypted by their standards: use them on a network you trust. Each packet goes to the one address you type.")
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private var bodySection: some View {
        Section {
            Toggle(isOn: Binding(get: { connections.consent.sharesBody }, set: { connections.setSharesBody($0) })) {
                Label("Share body data", systemImage: "heart.text.square")
            }
            .tint(Theme.Color.accent)
            note(bodyExplanation)
        } header: {
            Text("Body")
        }
    }

    private var bodyExplanation: String {
        var lines = [
            "Off at every start. On, the strap's pulse, HRV and coherence go to the OSC receiver as /echoelmusic/bio/… and a measured coherence lifts the light. Nothing read from Apple Health ever leaves this device.",
        ]
        lines.append(strap.isOn ? "The heart rate strap is on." : "The heart rate strap is off (Song menu), so there is nothing to share yet.")
        return lines.joined(separator: " ")
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textSecondary)
            .padding(.vertical, Theme.Space.xs)
    }
}

/// One protocol: its switch, its receiver, what it sends and, while on, how it is doing.
private struct ConnectionSection: View {
    let kind: ConnectionsController.Kind
    @Environment(ConnectionsController.self) private var connections

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { connections.isOn(kind) }, set: { connections.setOn($0, kind) })) {
                Label(kind.title, systemImage: kind.isLight ? "lightbulb" : "antenna.radiowaves.left.and.right")
            }
            .tint(Theme.Color.accent)
            ReceiverFields(kind: kind)
            if kind.isLight { lightFields }
            Text(kind.sends)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .padding(.vertical, Theme.Space.xs)
            if let refusal = connections.refusals[kind] {
                Text(refusal)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
            }
            if connections.isOn(kind) {
                ConnectionActivityLine(kind: kind)
            }
        }
    }

    @ViewBuilder
    private var lightFields: some View {
        NumberField(title: kind == .sacn ? "Universe" : "Port address (Net·SubUni)",
                    value: connections.universe(kind),
                    range: kind == .sacn ? E131Packet.universeRange : ArtDMXPacket.universeRange) { connections.setUniverse($0, for: kind) }
        NumberField(title: "First channel", value: connections.startChannel, range: connections.startChannelRange) {
            connections.setStartChannel($0)
        }
        Picker("Resolution", selection: Binding(get: { connections.resolution }, set: { connections.setResolution($0) })) {
            Text("8-bit (4 channels)").tag(LightFixture.Resolution.eightBit)
            Text("16-bit (8 channels)").tag(LightFixture.Resolution.sixteenBit)
        }
        .pickerStyle(.menu)
    }
}

/// Host and port, committed when the field is submitted or left, so a live connection does not
/// reopen on every keystroke.
private struct ReceiverFields: View {
    let kind: ConnectionsController.Kind
    @Environment(ConnectionsController.self) private var connections
    @State private var host = ""
    @State private var port = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable { case host, port }

    var body: some View {
        LabeledContent("Receiver") {
            TextField("Address", text: $host)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .multilineTextAlignment(.trailing)
                .focused($focus, equals: .host)
                .submitLabel(.done)
                .onSubmit { commitHost() }
                .accessibilityLabel("\(kind.title) receiver address")
        }
        LabeledContent("Port") {
            TextField("Port", text: $port)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($focus, equals: .port)
                .onSubmit { commitPort() }
                .accessibilityLabel("\(kind.title) port")
        }
        .onAppear {
            host = connections.target(kind).host
            port = String(connections.target(kind).port)
        }
        .onChange(of: focus) { old, _ in
            if old == .host { commitHost() }
            if old == .port { commitPort() }
        }
    }

    private func commitHost() {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != connections.target(kind).host else { return }
        connections.setHost(trimmed, for: kind)
        host = connections.target(kind).host
    }

    private func commitPort() {
        if let value = UInt16(port.trimmingCharacters(in: .whitespaces)), value > 0, value != connections.target(kind).port {
            connections.setPort(value, for: kind)
        }
        port = String(connections.target(kind).port)
    }
}

/// An integer setting with a range, committed on submit or when the field is left.
private struct NumberField: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let commit: (Int) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent(title) {
            TextField(title, text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .onSubmit { apply() }
                .accessibilityLabel(title)
        }
        .onAppear { text = String(value) }
        .onChange(of: value) { _, now in text = String(now) }
        .onChange(of: focused) { was, now in if was, !now { apply() } }
    }

    private func apply() {
        if let typed = Int(text.trimmingCharacters(in: .whitespaces)) {
            commit(Swift.min(range.upperBound, Swift.max(range.lowerBound, typed)))
        }
        text = String(value)
    }
}

/// The status of one live connection, as its own leaf: it moves about once a second and nothing
/// else in the panel moves with it.
struct ConnectionActivityLine: View {
    let kind: ConnectionsController.Kind
    @Environment(ConnectionsController.self) private var connections

    var body: some View {
        let activity = connections.activity[kind]
        HStack(spacing: Theme.Space.xs) {
            Circle()
                .fill(Self.colour(for: activity?.state))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(Self.text(for: activity))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .monospacedDigit()
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title) status")
        .accessibilityValue(Self.text(for: activity))
    }

    static func text(for activity: ConnectionsController.Activity?) -> String {
        guard let activity else { return "Off" }
        let counters = activity.counters
        var parts: [String]
        switch activity.state {
        case .preparing: parts = ["Connecting…"]
        case .ready: parts = ["Sending"]
        case .waiting(let reason): parts = ["Waiting: \(reason)"]
        case .failed(let reason): parts = ["Failed: \(reason)"]
        case .cancelled: parts = ["Closed"]
        }
        parts.append("\(counters.handedOver) sent")
        if counters.dropped > 0 { parts.append("\(counters.dropped) dropped") }
        if counters.failed > 0 { parts.append("\(counters.failed) refused") }
        return parts.joined(separator: " · ")
    }

    static func colour(for state: UDPSender.State?) -> Color {
        switch state {
        case .ready: Theme.Color.play
        case .failed: Theme.Color.record
        case .waiting, .preparing, .cancelled, nil: Theme.Color.textTertiary
        }
    }
}
