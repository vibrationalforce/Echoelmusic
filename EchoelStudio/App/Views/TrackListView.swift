import EchoelCore
import SwiftUI

/// The tracks of the song. Adding, renaming, recolouring, muting, soloing and deleting all
/// go through commands.
struct TrackListView: View {
    @Environment(ProjectStore.self) private var store
    /// Opens a track's editor.
    let open: (TrackID) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(store.project.tracks) { track in
                    TrackRow(track: track, open: open)
                }
                AddTrackMenu()
                    .padding(Theme.Space.m)
            }
        }
        .background(Theme.Color.background)
    }
}

struct TrackRow: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let track: Track
    let open: (TrackID) -> Void

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(Theme.Color.track(track.colorIndex))
                .frame(width: 6)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Space.xs / 2) {
                Text(track.name)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                Text(track.typeName)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { if track.kind == .instrument { open(track.id) } }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(track.kind == .instrument ? .isButton : [])
            .accessibilityHint(track.kind == .instrument ? "Opens the editor." : "")
            .accessibilityLabel("\(track.name), \(track.typeName), \(Theme.Color.trackName(track.colorIndex))")
            .accessibilityAction(named: "Delete Track") {
                try? store.perform(.removeTrack(track.id))
            }

            if track.kind == .audio { ArmButton(track: track) }
            if track.kind == .instrument {
                let isLive = engine.liveTrackID(in: store.project) == track.id
                Button {
                    engine.setLiveTrack(track.id)
                } label: {
                    Image(systemName: "pianokeys")
                }
                .buttonStyle(ToolButtonStyle(isActive: isLive))
                .accessibilityLabel("Play \(track.name) from MIDI")
                .accessibilityValue(isLive ? "On" : "Off")
            }

            Button {
                try? store.perform(.setMute(track.id, !track.mixer.isMuted))
            } label: {
                Text("M")
            }
            .buttonStyle(ToolButtonStyle(isActive: track.mixer.isMuted, activeColor: Theme.Color.accent))
            .accessibilityLabel("Mute \(track.name)")
            .accessibilityValue(track.mixer.isMuted ? "On" : "Off")

            Button {
                try? store.perform(.setSolo(track.id, !track.mixer.isSoloed))
            } label: {
                Text("S")
            }
            .buttonStyle(ToolButtonStyle(isActive: track.mixer.isSoloed, activeColor: Theme.Color.play))
            .accessibilityLabel("Solo \(track.name)")
            .accessibilityValue(track.mixer.isSoloed ? "On" : "Off")
        }
        .padding(.horizontal, Theme.Space.m)
        .frame(minHeight: Theme.Size.trackRowHeight)
        .background(Theme.Color.surface)
        .contextMenu {
            Menu("Color") {
                ForEach(0..<Palette.trackColorCount, id: \.self) { index in
                    Button(Theme.Color.trackName(index)) {
                        try? store.perform(.setTrackColor(track.id, colorIndex: index))
                    }
                }
            }
            Button("Delete Track", role: .destructive) {
                try? store.perform(.removeTrack(track.id))
            }
        }
    }
}

/// Arms an audio track for recording; one track at a time. Arming opens the input.
struct ArmButton: View {
    @Environment(RecordController.self) private var recording
    let track: Track

    var body: some View {
        let armed = recording.armedTrack == track.id
        Button {
            Task { await recording.toggleArm(track.id) }
        } label: {
            Image(systemName: "record.circle")
        }
        .buttonStyle(ToolButtonStyle(isActive: armed, activeColor: Theme.Color.record))
        .accessibilityLabel("Arm \(track.name) for Recording")
        .accessibilityValue(armed ? "On" : "Off")
    }
}

struct AddTrackMenu: View {
    @Environment(ProjectStore.self) private var store

    var body: some View {
        Menu {
            ForEach(TrackKind.allCases, id: \.self) { kind in
                Button(kind.displayName) { add(kind) }
            }
            Button("Drums") { addDrums() }
        } label: {
            Label("Add Track", systemImage: "plus")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.text)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(Theme.Color.border, lineWidth: 1)
                )
        }
    }

    /// An instrument track playing the drum kit, with an empty one-bar pattern ready to fill.
    private func addDrums() {
        let track = TrackID(), clip = ClipID()
        let count = store.project.tracks.filter { $0.instrument.device == .drums && $0.kind == .instrument }.count + 1
        try? store.perform([
            .addTrack(id: track, name: "Drums \(count)", kind: .instrument, index: nil),
            .setInstrumentDevice(track, .drums),
            .createClip(track: track, id: clip, name: "Beat", length: MusicalTime.ticksPerBar(store.project.timeSignature)),
            .placeClip(track: track, id: PlacementID(), clip: clip, start: 0),
        ], title: "Add Drums")
    }

    private func add(_ kind: TrackKind) {
        let count = store.project.tracks.filter { $0.kind == kind }.count + 1
        try? store.perform(.addTrack(id: TrackID(), name: "\(kind.displayName) \(count)", kind: kind, index: nil))
    }
}

extension TrackKind {
    var displayName: String {
        switch self {
        case .instrument: "Instrument"
        case .audio: "Audio"
        case .returnTrack: "Return"
        }
    }
}

extension Track {
    /// What the track list calls it: an instrument track says which instrument it plays.
    var typeName: String {
        kind == .instrument ? instrument.device.title : kind.displayName
    }
}
