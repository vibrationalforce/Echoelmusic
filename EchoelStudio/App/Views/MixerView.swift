import EchoelCore
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
            }
            if let track, track.kind != .returnTrack {
                ForEach(store.project.tracks.filter { $0.kind == .returnTrack }) { target in
                    ParameterField(address: .send(track.id, to: target.id))
                }
            }
            PanControl(address: pan)
            Fader(address: volume)
            Text(ParameterFormat.text(store.project.value(of: volume) ?? 0, unit: .decibel))
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
                OutputMenu(track: track)
            }
        }
        .frame(width: 104)
        .padding(.vertical, Theme.Space.s)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
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
