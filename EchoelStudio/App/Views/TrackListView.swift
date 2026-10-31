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
            LazyVStack(spacing: Theme.Space.hairline) {
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
    @Environment(StudioRouter.self) private var router
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
            .accessibilityAction(named: "Rename Track") { router.sheet = .rename(.track(track.id)) }
            .accessibilityAction(named: "Move Track Up") { move(by: -1) }
            .accessibilityAction(named: "Move Track Down") { move(by: 1) }
            .accessibilityAction(named: "Delete Track") {
                try? store.perform(.removeTrack(track.id))
            }

            if track.kind == .audio || track.kind == .instrument { ArmButton(track: track) }
            if track.kind == .video { VideoTrackButtons(track: track) }
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
            Button("Rename…", systemImage: "pencil") { router.sheet = .rename(.track(track.id)) }
            Button("Move Up", systemImage: "arrow.up") { move(by: -1) }
                .disabled(index == 0)
            Button("Move Down", systemImage: "arrow.down") { move(by: 1) }
                .disabled(index.map { $0 >= store.project.tracks.count - 1 } ?? true)
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

    private var index: Int? { store.project.trackIndex(track.id) }

    /// One place up or down the list (and the arrangement, the mixer and the session with it).
    private func move(by step: Int) {
        guard let position = index else { return }
        let target = position + step
        guard store.project.tracks.indices.contains(target) else { return }
        try? store.perform(.moveTrack(track.id, toIndex: target))
    }
}

/// Arms a track for recording; one track at a time. Arming an audio track opens the input; an
/// instrument track records MIDI and plays it live.
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
                Button(title(kind)) { add(kind) }
                    .disabled(!store.project.canAddTrack(kind))
            }
            Button(store.project.canAddTrack(.instrument) ? "Drums" : "Drums (\(Track.limit(for: .instrument)) instruments is the limit)") {
                addDrums()
            }
            .disabled(!store.project.canAddTrack(.instrument))
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

    /// The menu says why an entry is off: the song is full for that kind.
    private func title(_ kind: TrackKind) -> String {
        store.project.canAddTrack(kind) ? kind.displayName
            : "\(kind.displayName) (\(Track.limit(for: kind)) is the limit)"
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
        case .video: "Video"
        }
    }
}

extension Track {
    /// What the track list calls it: an instrument track says which instrument it plays.
    var typeName: String {
        kind == .instrument ? instrument.device.title : kind.displayName
    }
}

/// A video track's doors (wave W7): film a take with the rear camera, import a video from the
/// photo library or the Files app at the end of the track, and show the video window again.
struct VideoTrackButtons: View {
    @Environment(ProjectStore.self) private var store
    @Environment(StudioRouter.self) private var router
    @AppStorage(VideoWindow.shownKey) private var showsVideoWindow = true
    let track: Track

    var body: some View {
        Button { router.sheet = .cameraTake(track.id) } label: { Image(systemName: "video") }
            .buttonStyle(ToolButtonStyle())
            .accessibilityLabel("Film a Take on \(track.name)")
            .accessibilityHint("Plays the song and films with the rear camera.")
        Menu {
            Button("From Photos", systemImage: "photo.on.rectangle") { router.sheet = .importVideoFromPhotos(track.id, end) }
            Button("From Files", systemImage: "folder") { router.sheet = .importVideoFromFiles(track.id, end) }
            Button(showsVideoWindow ? "Hide Video Window" : "Show Video Window", systemImage: "film") {
                showsVideoWindow.toggle()
            }
        } label: {
            Image(systemName: "plus.rectangle.on.rectangle")
        }
        .buttonStyle(ToolButtonStyle())
        .accessibilityLabel("Add Video to \(track.name)")
    }

    /// The first bar after the track's last part.
    private var end: Tick {
        let project = store.project
        let last = track.regions.compactMap { Arranging.end(of: $0, in: project) }.max() ?? 0
        return Arranging.barStart(last + MusicalTime.ticksPerBar(project.timeSignature) - 1, signature: project.timeSignature)
    }
}
