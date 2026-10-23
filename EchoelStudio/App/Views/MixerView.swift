import EchoelCore
import EchoelEngine
import SwiftUI

/// One channel strip per track and the master: level, pan, mute and solo, all through the
/// parameter controls and commands.
struct MixerView: View {
    @Environment(ProjectStore.self) private var store

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 1) {
                ForEach(store.project.tracks) { track in
                    ChannelStrip(title: track.name, color: Theme.Color.track(track.colorIndex),
                                 volume: .volume(track.id), pan: .pan(track.id), track: track)
                }
                ChannelStrip(title: "Master", color: Theme.Color.text,
                             volume: .masterVolume, pan: .masterPan, track: nil)
                    .padding(.leading, Theme.Space.s)
            }
            .padding(Theme.Space.m)
        }
        .background(Theme.Color.background)
    }
}

struct ChannelStrip: View {
    @Environment(ProjectStore.self) private var store
    @Environment(StudioRouter.self) private var router
    let title: String
    let color: Color
    let volume: ParameterAddress
    let pan: ParameterAddress
    /// Nil for the master, which has no mute or solo.
    let track: Track?
    /// The level an automation pass is writing under the fader, for the readout below it.
    @State private var passedVolume: Double?

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            Rectangle().fill(color).frame(height: 3).accessibilityHidden(true)
            Text(title)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.text)
                .lineLimit(1)
            if let track {
                let active = track.inserts.filter { !$0.isBypassed }.count
                Button(track.inserts.isEmpty ? "FX" : "FX \(active)/\(track.inserts.count)") {
                    router.sheet = .effects(track.id)
                }
                .buttonStyle(ToolButtonStyle(isActive: active > 0))
                .accessibilityLabel("Effects on \(track.name)")
                .accessibilityValue(track.inserts.isEmpty ? "None" : "\(active) of \(track.inserts.count) on")
            } else {
                let inserts = store.project.masterInserts
                let active = inserts.filter { !$0.isBypassed }.count
                Button(inserts.isEmpty ? "FX" : "FX \(active)/\(inserts.count)") {
                    router.sheet = .masterEffects
                }
                .buttonStyle(ToolButtonStyle(isActive: active > 0))
                .accessibilityLabel("Master effects")
                .accessibilityValue(inserts.isEmpty ? "None" : "\(active) of \(inserts.count) on")
            }
            if let track, track.kind != .returnTrack {
                ForEach(store.project.tracks.filter { $0.kind == .returnTrack }) { target in
                    ParameterField(address: .send(track.id, to: target.id))
                }
            }
            PanControl(address: pan)
            HStack(alignment: .bottom, spacing: Theme.Space.xs) {
                Fader(address: volume, passed: $passedVolume)
                PeakMeter(track: track?.id, height: 180)
            }
            Text(ParameterFormat.text(passedVolume ?? store.project.value(of: volume) ?? 0, unit: .decibel))
                .font(Theme.Font.caption.monospacedDigit())
                .foregroundStyle(Theme.Color.textSecondary)
                .accessibilityHidden(true)
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
        .frame(width: 104)
        .padding(.vertical, Theme.Space.s)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }
}

/// A strip's level after its fader, left and right, from −60 dB to +6 dB with 0 dB marked. Red
/// at the top once the signal passed full scale. Polled in its own leaf, never in a strip body.
struct PeakMeter: View {
    @Environment(AudioEngine.self) private var engine
    /// Nil for the master.
    let track: TrackID?
    let height: CGFloat

    static let floor: Float = -60
    static let ceiling: Float = 6

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30)) { _ in
            let level = engine.meterLevel(track)
            HStack(spacing: 2) {
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
            .accessibilityLabel("Level")
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
        return String(format: "%.0f decibels", 20 * Foundation.log10(peak))
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
                .font(Theme.Font.caption)
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

/// Which interface input an audio track records from. The inputs are known while one is open
/// (a track is armed); a chosen input the interface lacks is kept and shown, and the first records.
struct InputMenu: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(RecordController.self) private var recording
    let track: Track

    var body: some View {
        let chosen = track.input ?? 0
        let count = Swift.max(engine.inputChannels, chosen + 1)
        Menu {
            ForEach(0..<count, id: \.self) { channel in
                Button { set(channel) } label: {
                    if channel == chosen { Label("Input \(channel + 1)", systemImage: "checkmark") } else { Text("Input \(channel + 1)") }
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
                .font(Theme.Font.caption)
                .foregroundStyle(isMissing ? Theme.Color.record : Theme.Color.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
        }
        .accessibilityLabel("Input of \(track.name)")
        .accessibilityValue(label)
        .accessibilityHint(engine.inputChannels == 0 ? "Arm the track to see every input of the interface." : "")
    }

    private var isMissing: Bool {
        engine.inputChannels > 0 && (track.input ?? 0) >= engine.inputChannels
    }

    private var label: String {
        let name = "In \((track.input ?? 0) + 1)"
        if isMissing { return "\(name) missing" }
        switch track.monitor {
        case .auto: return name
        case .input: return "\(name) · Mon"
        case .off: return "\(name) · No Mon"
        }
    }

    static func title(_ mode: MonitorMode) -> String {
        switch mode {
        case .auto: "Auto (while armed, in headphones or an interface)"
        case .input: "Always (in headphones or an interface)"
        case .off: "Off (the interface monitors)"
        }
    }

    private func set(_ channel: Int) {
        try? store.perform(.setInput(track.id, channel: channel == 0 ? nil : channel))
    }
}
