import EchoelCore
import EchoelEngine
import SwiftUI

/// One channel strip per track and the master: level, pan, mute and solo, all through the
/// parameter controls and commands.
struct MixerView: View {
    @Environment(ProjectStore.self) private var store
    /// The height of a strip's rows other than the fader — colour bar, name, effects, pan, level,
    /// mute/solo and output, with their gaps — and of each send, at the standard text size and
    /// growing with it: the fader takes what is left of the view, so with large text it shortens
    /// rather than push the rest of the strip off the screen.
    @ScaledMetric(relativeTo: .subheadline) private var stripRows: CGFloat = 360
    @ScaledMetric(relativeTo: .subheadline) private var sendRow: CGFloat = 76

    var body: some View {
        // The faders take the height the view has (device video 10021: small faders under a lot
        // of empty space); the strips scroll both ways when the screen is shorter than a strip.
        GeometryReader { geometry in
            let height = faderHeight(in: geometry.size.height)
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: Theme.Space.hairline) {
                    // A video track is never heard, so it has no strip.
                    ForEach(store.project.tracks.filter { $0.kind != .video }) { track in
                        ChannelStrip(title: track.name, color: Theme.Color.track(track.colorIndex),
                                     volume: .volume(track.id), pan: .pan(track.id), track: track,
                                     faderHeight: height)
                    }
                    ChannelStrip(title: "Master", color: Theme.Color.text,
                                 volume: .masterVolume, pan: .masterPan, track: nil, faderHeight: height)
                        .padding(.leading, Theme.Space.s)
                }
                .padding(Theme.Space.m)
            }
            .defaultScrollAnchor(.topLeading)
        }
        .background(Theme.Color.background)
        // No pad host of its own: the mixer is only ever a surface of the studio, whose host
        // serves it, so a level and the tempo never open two pads at once.
    }

    /// The strip's rows other than the fader take about this much height; each return adds a
    /// send field. What is left is the fader's, between a usable minimum and a reach a thumb
    /// still covers.
    private func faderHeight(in available: CGFloat) -> CGFloat {
        let returns = store.project.tracks.filter { $0.kind == .returnTrack }.count
        let rows = stripRows + CGFloat(returns) * sendRow + 2 * Theme.Space.m
        return Swift.min(Swift.max(available - rows, ChannelStrip.minimumFader), ChannelStrip.maximumFader)
    }
}

struct ChannelStrip: View {
    @Environment(ProjectStore.self) private var store
    @Environment(StudioRouter.self) private var router
    @Environment(ParameterWriter.self) private var writer
    @Environment(NumberPadController.self) private var pad: NumberPadController?
    let title: String
    let color: Color
    let volume: ParameterAddress
    let pan: ParameterAddress
    /// Nil for the master, which has no mute or solo.
    let track: Track?
    var faderHeight: CGFloat = 180

    /// Wide enough for a name, "Effects 2/3" and a send at the standard text size, and wider as
    /// the text grows: a fixed 120 pt cut the strip's words from the second accessibility size on
    /// (W18, M9).
    @ScaledMetric(relativeTo: .subheadline) private var width: CGFloat = 120
    static let minimumFader: CGFloat = 160
    static let maximumFader: CGFloat = 420
    /// The level an automation pass is writing under the fader, for the readout below it.
    @State private var passedVolume: Double?

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            Rectangle().fill(color).frame(height: 3).accessibilityHidden(true)
            // The strip's heading: VoiceOver's Headings rotor goes strip by strip (W18, m7).
            Text(title)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let track {
                let active = track.inserts.filter { !$0.isBypassed }.count
                Button(track.inserts.isEmpty ? "Effects" : "Effects \(active)/\(track.inserts.count)") {
                    router.sheet = .effects(track.id)
                }
                .buttonStyle(ToolButtonStyle(isActive: active > 0))
                .accessibilityLabel("Effects on \(track.name)")
                .accessibilityValue(track.inserts.isEmpty ? "None" : "\(active) of \(track.inserts.count) on")
            } else {
                let inserts = store.project.masterInserts
                let active = inserts.filter { !$0.isBypassed }.count
                Button(inserts.isEmpty ? "Effects" : "Effects \(active)/\(inserts.count)") {
                    router.sheet = .masterEffects
                }
                .buttonStyle(ToolButtonStyle(isActive: active > 0))
                .accessibilityLabel("Master Effects")
                .accessibilityValue(inserts.isEmpty ? "None" : "\(active) of \(inserts.count) on")
            }
            if let track, track.kind != .returnTrack {
                ForEach(store.project.tracks.filter { $0.kind == .returnTrack }) { target in
                    ParameterField(address: .send(track.id, to: target.id))
                }
            }
            PanControl(address: pan)
            HStack(alignment: .bottom, spacing: Theme.Space.xs) {
                Fader(address: volume, passed: $passedVolume, height: faderHeight)
                PeakMeter(title: title, track: track?.id, height: faderHeight)
            }
            levelReadout
            if let track {
                HStack(spacing: Theme.Space.xs) {
                    Button("M") { try? store.perform(.setMute(track.id, !track.mixer.isMuted)) }
                        .buttonStyle(ToolButtonStyle(isActive: track.mixer.isMuted))
                        .accessibilityLabel("Mute \(track.name)")
                        .accessibilityValue(track.mixer.isMuted ? "On" : "Off")
                    Button("S") { try? store.perform(.setSolo(track.id, !track.mixer.isSoloed)) }
                        .buttonStyle(ToolButtonStyle(isActive: track.mixer.isSoloed, activeColor: Theme.Color.play))
                        .accessibilityLabel("Solo \(track.name)")
                        .accessibilityValue(track.mixer.isSoloed ? "On" : "Off")
                }
                if track.kind == .audio { InputMenu(track: track) }
                OutputMenu(track: track)
            }
        }
        .frame(width: width)
        .padding(.vertical, Theme.Space.s)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    /// The level in dB under the fader; tap it to type an exact level on the number pad.
    private var levelReadout: some View {
        let level = passedVolume ?? store.project.value(of: volume) ?? 0
        let typed = pad?.request?.owner == "\(volume)"
        return Button {
            guard let descriptor = store.project.descriptor(for: volume) else { return }
            pad?.type(volume, descriptor: descriptor, value: store.project.value(of: volume) ?? level,
                      title: "\(title) Level", owner: "\(volume)", writer: writer)
        } label: {
            Text(ParameterFormat.text(level, unit: .decibel))
                .font(Theme.Font.value)
                .foregroundStyle(typed ? Theme.Color.accent : Theme.Color.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(pad == nil)
        .accessibilityLabel("\(title) level")
        .accessibilityValue(ParameterFormat.text(level, unit: .decibel))
        .accessibilityHint("Type an exact level.")
    }
}

/// A strip's level after its fader, left and right, from −60 dB to +6 dB with 0 dB marked. Red
/// at the top once the signal passed full scale. Polled in its own leaf, never in a strip body.
struct PeakMeter: View {
    @Environment(AudioEngine.self) private var engine
    /// The strip's name, so VoiceOver says whose meter it is ("Bass Meter"), not only "Level".
    let title: String
    /// Nil for the master.
    let track: TrackID?
    let height: CGFloat

    static let floor: Float = -60
    static let ceiling: Float = 6

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30)) { _ in
            let level = engine.meterLevel(track)
            HStack(spacing: Theme.Space.xxs) {
                bar(level.left)
                bar(level.right)
            }
            .frame(height: height)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.Color.textSecondary)
                    .frame(height: 1)
                    .offset(y: -height * CGFloat(Self.position(1)))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) Meter")
            .accessibilityValue(Self.spoken(Swift.max(level.left, level.right)))
        }
    }

    private func bar(_ peak: Float) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Theme.Color.surfaceRaised)
            Rectangle().fill(peak > 1 ? Theme.Color.record : Theme.Color.play)
                .frame(height: height * CGFloat(Self.position(peak)))
        }
        .frame(width: 4)
    }

    /// 0 at the floor, 1 at the ceiling, linear in decibels.
    static func position(_ peak: Float) -> Float {
        guard peak > 0, peak.isFinite else { return 0 }
        let db = 20 * Foundation.log10(peak)
        return Swift.min(Swift.max((db - floor) / (ceiling - floor), 0), 1)
    }

    static func spoken(_ peak: Float) -> String {
        guard peak > 0, peak.isFinite, 20 * Foundation.log10(peak) > floor else { return "Silent" }
        return NumberText.string(Double(20 * Foundation.log10(peak)), decimals: 0, unit: "decibels")
    }
}

/// Where a track plays: the master, or a stereo pair of the interface (3/4, 5/6 …). A pair the
/// interface lacks is kept and shown, and the track plays in the master until it is back.
struct OutputMenu: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let track: Track

    var body: some View {
        let pairs = Array(stride(from: 2, to: engine.outputChannels - 1, by: 2))
        Menu {
            Button { set(nil) } label: { choice("Master", selected: track.output == nil) }
            ForEach(pairs, id: \.self) { channel in
                Button { set(channel) } label: { choice(Self.name(channel), selected: track.output == channel) }
            }
        } label: {
            Text(label)
                .font(Theme.Font.label)
                .foregroundStyle(isMissing ? Theme.Color.record : Theme.Color.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
        }
        .disabled(pairs.isEmpty && track.output == nil)
        .accessibilityLabel("Output of \(track.name)")
        .accessibilityValue(label)
        .accessibilityHint(pairs.isEmpty ? "The interface has only outputs 1/2." : "")
    }

    private var isMissing: Bool {
        guard let output = track.output else { return false }
        return output + 1 >= engine.outputChannels
    }

    private var label: String {
        guard let output = track.output else { return "Out Master" }
        return isMissing ? "\(Self.name(output)) missing" : "Out \(Self.name(output))"
    }

    @ViewBuilder private func choice(_ title: String, selected: Bool) -> some View {
        if selected { Label(title, systemImage: "checkmark") } else { Text(title) }
    }

    private func set(_ channel: Int?) {
        try? store.perform(.setOutput(track.id, channel: channel))
    }

    /// Channel 2 is "3/4": outputs are counted from 1 on the interface.
    static func name(_ channel: Int) -> String { "\(channel + 1)/\(channel + 2)" }
}

/// Which interface input — or input pair, left and right — an audio track records from. The inputs are known while one is open
/// (a track is armed); a chosen input the interface lacks is kept and shown, and the first records;
/// a pair without its right input records its left alone, and says so.
struct InputMenu: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(RecordController.self) private var recording
    let track: Track

    var body: some View {
        let chosen = track.input ?? 0
        let count = Swift.max(engine.inputChannels, chosen + width)
        let starts = Self.pairs(count: count, chosen: isPair ? chosen : nil)
        Menu {
            ForEach(0..<count, id: \.self) { channel in
                Button { set(channel, pair: false) } label: {
                    if !isPair, channel == chosen { Label("Input \(channel + 1)", systemImage: "checkmark") } else { Text("Input \(channel + 1)") }
                }
            }
            if !starts.isEmpty {
                Section("Stereo") {
                    ForEach(starts, id: \.self) { start in
                        Button { set(start, pair: true) } label: {
                            let name = "Input \(OutputMenu.name(start))"
                            if isPair, start == chosen { Label(name, systemImage: "checkmark") } else { Text(name) }
                        }
                    }
                }
            }
            Section("Monitor") {
                ForEach(MonitorMode.allCases, id: \.self) { mode in
                    Button { Task { await recording.setMonitor(mode, on: track.id) } } label: {
                        if mode == track.monitor { Label(Self.title(mode), systemImage: "checkmark") } else { Text(Self.title(mode)) }
                    }
                }
            }
        } label: {
            Text(label)
                .font(Theme.Font.label)
                .foregroundStyle(isMissing ? Theme.Color.record : Theme.Color.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
        }
        .accessibilityLabel("Input of \(track.name)")
        .accessibilityValue(label)
        .accessibilityHint(engine.inputChannels == 0 ? "Arm the track to see every input of the interface." : "")
    }

    /// Whether the track records an input pair rather than one input.
    private var isPair: Bool { track.inputChannels == Track.maximumInputChannels }
    private var width: Int { isPair ? Track.maximumInputChannels : 1 }

    private var isMissing: Bool {
        engine.inputChannels > 0 && (track.input ?? 0) >= engine.inputChannels
    }

    /// A pair whose right input the interface lacks: its left records alone, as a mono take.
    private var isMono: Bool {
        isPair && engine.inputChannels > 0 && !isMissing && (track.input ?? 0) + 1 >= engine.inputChannels
    }

    private var label: String {
        let first = track.input ?? 0
        let name = isPair ? "In \(OutputMenu.name(first))" : "In \(first + 1)"
        if isMissing { return "\(name) missing" }
        if isMono { return "\(name) · Mono" }
        switch track.monitor {
        case .auto: return name
        case .input: return "\(name) · Mon"
        case .off: return "\(name) · No Mon"
        }
    }

    static func title(_ mode: MonitorMode) -> String {
        switch mode {
        case .auto: "Auto (while armed, in wired headphones or an interface)"
        case .input: "Always (in wired headphones or an interface)"
        case .off: "Off (the interface monitors)"
        }
    }

    /// The pairs the menu offers: every one that starts on an odd input (1/2, 3/4, …) and fits in
    /// `count`, and a stored pair that starts elsewhere (2/3) as its own entry.
    static func pairs(count: Int, chosen: Int?) -> [Int] {
        var starts = Array(stride(from: 0, to: Swift.max(0, count - 1), by: 2))
        if let chosen, chosen >= 0, !starts.contains(chosen) {
            starts.append(chosen)
            starts.sort()
        }
        return starts
    }

    private func set(_ channel: Int, pair: Bool) {
        try? store.perform(.setInput(track.id, channel: channel == 0 ? nil : channel, stereo: pair))
    }
}
