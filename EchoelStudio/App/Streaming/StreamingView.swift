import EchoelCore
import SwiftUI

/// The streaming page (wave W14), one case of the one sheet: the destinations kept on this
/// device, Go Live and Stop, and — while live — each destination's state, upload and the time on
/// air in a leaf of its own (Law 6). Everything is off until Go Live.
struct StreamingView: View {
    @Environment(StreamingController.self) private var streaming
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var editing: StreamTarget?

    var body: some View {
        NavigationStack {
            List {
                liveSection
                destinationsSection
                uploadSection
                aboutSection
            }
            .navigationTitle("Go Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .navigationDestination(item: $editing) { target in
                StreamTargetEditor(target: target)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Regions

    @ViewBuilder private var liveSection: some View {
        Section {
            if streaming.isLive || streaming.isStarting {
                StreamLiveReadout()
                Button(role: .destructive) {
                    Task { await streaming.stop() }
                } label: {
                    Label("Stop Stream", systemImage: "stop.fill")
                }
            } else {
                Button {
                    Task { await streaming.goLive(store: store, engine: engine) }
                } label: {
                    Label("Go Live", systemImage: "dot.radiowaves.left.and.right")
                }
                .disabled(streaming.plan.refusal != nil)
            }
            if let notice = streaming.notice {
                Text(notice)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
            }
        } footer: {
            Text("Picture: the Field. Sound: the master mix. Nothing else leaves the phone, and nothing at all until Go Live.")
        }
    }

    private var destinationsSection: some View {
        Section("Destinations") {
            ForEach(streaming.plan.targets) { target in
                destinationRow(target)
            }
            .onDelete { offsets in
                for index in offsets {
                    let targets = streaming.plan.targets
                    guard targets.indices.contains(index) else { continue }
                    streaming.remove(targets[index].id)
                }
            }
            Menu {
                ForEach(StreamPlatform.allCases, id: \.self) { platform in
                    Button(platform.title) { editing = streaming.add(platform) }
                }
            } label: {
                Label("Add Destination", systemImage: "plus")
            }
            .disabled(streaming.isLive || streaming.isStarting)
        }
    }

    private func destinationRow(_ target: StreamTarget) -> some View {
        HStack(spacing: Theme.Space.m) {
            Toggle(isOn: Binding(get: { target.isEnabled }, set: { on in
                var changed = target
                changed.isEnabled = on
                streaming.update(changed)
            })) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(target.name).font(Theme.Font.label)
                    Text(summary(target))
                        .font(Theme.Font.caption)
                        .foregroundStyle(streaming.addressProblem(of: target) == nil ? Theme.Color.textSecondary : Theme.Color.record)
                        .lineLimit(2)
                }
            }
            .disabled(streaming.isLive || streaming.isStarting)
            Button {
                editing = target
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(target.name)")
            .disabled(streaming.isLive || streaming.isStarting)
        }
    }

    private func summary(_ target: StreamTarget) -> String {
        if let problem = streaming.addressProblem(of: target) { return problem }
        return "\(target.platform.title) · \(target.format.title) · \(target.quality.videoKbps + target.quality.audioKbps) kbit/s"
    }

    private var uploadSection: some View {
        Section {
            Picker("At once", selection: Binding(get: { streaming.plan.simultaneousLimit },
                                                 set: { streaming.setSimultaneousLimit($0) })) {
                ForEach(Array(StreamPlan.limitRange), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(streaming.isLive || streaming.isStarting)
            LabeledContent("Upload Needed", value: Self.megabits(streaming.plan.uploadKbps))
            if let refusal = streaming.plan.refusal, refusal != .noTarget {
                Text(refusal.explanation)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
            }
        } header: {
            Text("Destinations at Once")
        } footer: {
            Text("Each destination is its own upload from the phone. To reach many platforms, stream once to a relay — Restream, or your own MediaMTX server (open source) — and let it forward the stream.")
        }
    }

    private var aboutSection: some View {
        Section {
            Text("Stream keys stay in this device's keychain: never in a song, a backup of the app's settings or the diagnostic log.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
            Text("Streaming stops when Echoel leaves the screen or a call takes the audio; iOS does not encode video in the background.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    static func megabits(_ kbps: Int) -> String {
        String(format: "%.1f Mbit/s", Double(kbps) / 1_000)
    }
}

/// While live: each destination's state and upload, and the time on air. Its own leaf, so the
/// once-a-second readings and the clock rebuild only these rows (Law 6).
struct StreamLiveReadout: View {
    @Environment(StreamingController.self) private var streaming

    var body: some View {
        if let started = streaming.startedAt {
            TimelineView(.periodic(from: started, by: 1)) { context in
                LabeledContent("On Air", value: Self.duration(context.date.timeIntervalSince(started)))
                    .monospacedDigit()
            }
        } else {
            LabeledContent("On Air", value: "Connecting")
        }
        ForEach(streaming.plan.enabledTargets) { target in
            let report = streaming.reports[target.id]
            LabeledContent(target.name, value: Self.reading(report))
                .foregroundStyle(report?.isCongested == true ? Theme.Color.record : Theme.Color.text)
        }
    }

    private static func reading(_ report: StreamPublisher.Report?) -> String {
        guard let report else { return "Waiting" }
        switch report.state {
        case .connecting: return "Connecting"
        case .closed: return "Off"
        case .failed(let reason): return reason
        case .live:
            guard let kbps = report.sentKbps else { return "Live" }
            return (report.isCongested ? "Network too slow · " : "Live · ") + StreamingView.megabits(kbps)
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(Swift.max(0, seconds))
        return String(format: "%d:%02d:%02d", total / 3_600, total / 60 % 60, total % 60)
    }
}

/// One destination: its name, server, key, shape and bit rates. The key goes straight to the
/// keychain and is never shown again — only whether one is stored.
struct StreamTargetEditor: View {
    @Environment(StreamingController.self) private var streaming
    @State private var target: StreamTarget
    @State private var key = ""
    @State private var hasKey: Bool
    @State private var keyRefused = false

    private static let audioRates = [96, 128, 160, 192, 256, 320]

    init(target: StreamTarget) {
        _target = State(initialValue: target)
        _hasKey = State(initialValue: StreamKeyStore.hasKey(for: target.id))
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $target.name)
                TextField(target.platform.defaultServer ?? "rtmp://server/app", text: $target.server)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text(target.platform.title)
            } footer: {
                Text(target.platform.whereToFind)
            }
            keySection
            shapeSection
            rateSection
            if let problem = streaming.addressProblem(of: target) {
                Section { Text(problem).foregroundStyle(Theme.Color.record) }
            }
        }
        // The video rate is typed on Echoel's number pad, docked at the page's bottom edge.
        .numberPadHost()
        .navigationTitle(target.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: target) { _, changed in streaming.update(changed) }
    }

    private var keySection: some View {
        Section {
            SecureField(hasKey ? "Stored, type to replace" : "Stream key", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(storeKey)
            Button("Keep Key", action: storeKey).disabled(key.isEmpty)
            if hasKey {
                Button("Remove Key", role: .destructive) {
                    StreamKeyStore.removeKey(for: target.id)
                    hasKey = false
                }
            }
            if keyRefused {
                Text("The keychain did not keep the key. Tap Keep Key to try again.").foregroundStyle(Theme.Color.record)
            }
        } header: {
            Text("Stream Key")
        } footer: {
            Text(target.platform.needsKey ? "Kept in this device's keychain only." : "Optional: the server address may carry everything.")
        }
    }

    private var shapeSection: some View {
        Section {
            Picker("Shape", selection: $target.format) {
                ForEach(StreamFormat.allCases, id: \.self) { format in
                    Text(format.title).tag(format)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Picture")
        } footer: {
            Text("\(target.format.pixelWidth) × \(target.format.pixelHeight), 30 frames a second. Recommended for \(target.platform.title): \(target.platform.recommendedFormats.map(\.title).joined(separator: ", ")).")
        }
    }

    private var rateSection: some View {
        Section {
            SettingField(title: "Video", value: target.quality.videoKbps, range: StreamQuality.videoRange,
                         unit: "kbit/s", step: 100, standard: target.platform.recommendedVideoKbps,
                         spokenUnit: "kilobits a second") { target.quality.videoKbps = $0 }
            Picker("Audio", selection: $target.quality.audioKbps) {
                ForEach(Self.audioRates, id: \.self) { Text("\($0) kbit/s").tag($0) }
            }
        } header: {
            Text("Bit Rate")
        } footer: {
            Text("Recommended video for \(target.platform.title): \(target.platform.recommendedVideoKbps) kbit/s. If the network cannot carry it, the stream steps down by itself.")
        }
    }

    private func storeKey() {
        guard !key.isEmpty else { return }
        keyRefused = !StreamKeyStore.setKey(key, for: target.id)
        hasKey = StreamKeyStore.hasKey(for: target.id)
        key = ""
    }
}

/// A small mark over the studio while a stream is on air, so the musician sees it with the page
/// closed; a tap opens the page. The clock ticks in this leaf only.
struct StreamLiveBadge: View {
    @Environment(StreamingController.self) private var streaming
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: Theme.Space.xs) {
                Circle().fill(Theme.Color.record).frame(width: 8, height: 8)
                if let started = streaming.startedAt {
                    TimelineView(.periodic(from: started, by: 1)) { context in
                        Text("LIVE " + StreamLiveReadout.duration(context.date.timeIntervalSince(started)))
                    }
                } else {
                    Text("Connecting")
                }
            }
            .font(Theme.Font.caption.monospacedDigit())
            .foregroundStyle(Theme.Color.text)
            .padding(.horizontal, Theme.Space.s)
            .padding(.vertical, Theme.Space.xs)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Live stream on air. Open the streaming page.")
    }
}
