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
            }
        }
        .frame(width: 104)
        .padding(.vertical, Theme.Space.s)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }
}
