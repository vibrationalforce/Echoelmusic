import EchoelCore
import SwiftUI

/// The session: instrument tracks as columns, scenes as rows. Tap a clip to launch it on the
/// next bar, a scene to launch its row, an empty slot to make a clip. Launch state comes from
/// the engine; every document change is a command.
struct SessionView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    /// Opens a clip in the editor.
    let open: (TrackID, ClipID) -> Void

    static let columnWidth: CGFloat = 120
    static let sceneWidth: CGFloat = 104

    var body: some View {
        let tracks = store.project.tracks.filter { $0.kind == .instrument }
        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 1) {
                    header(tracks)
                    ForEach(store.project.scenes) { scene in
                        row(scene, tracks)
                    }
                    addScene
                }
                .padding(Theme.Space.s)
            }
            Divider().overlay(Theme.Color.border)
            SessionFooter()
        }
        .background(Theme.Color.background)
    }

    private func header(_ tracks: [Track]) -> some View {
        HStack(spacing: 1) {
            Color.clear.frame(width: Self.sceneWidth, height: 1)
            ForEach(tracks) { track in
                SessionTrackHeader(track: track)
            }
        }
    }

    private func row(_ scene: EchoelCore.Scene, _ tracks: [Track]) -> some View {
        HStack(spacing: 1) {
            SceneButton(scene: scene)
            ForEach(tracks) { track in
                SessionCell(track: track, scene: scene, open: open)
            }
        }
    }

    private var addScene: some View {
        Button("Add Scene", systemImage: "plus") {
            let name = "Scene \(store.project.scenes.count + 1)"
            try? store.perform(.addScene(id: SceneID(), name: name, index: nil))
        }
        .buttonStyle(ToolButtonStyle())
        .padding(.top, Theme.Space.s)
    }
}

/// A track's name and the button that stops its clip.
struct SessionTrackHeader: View {
    @Environment(AudioEngine.self) private var engine
    let track: Track

    var body: some View {
        let isPlaying = engine.session.playing[track.id] != nil
        HStack(spacing: Theme.Space.xs) {
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(Theme.Color.track(track.colorIndex))
                .frame(width: 4, height: 20)
                .accessibilityHidden(true)
            Text(track.name)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { engine.stopClip(on: track.id) } label: { Image(systemName: "stop.fill") }
                .buttonStyle(ToolButtonStyle(isActive: isPlaying))
                .disabled(!isPlaying)
                .accessibilityLabel("Stop clip on \(track.name)")
        }
        .padding(.horizontal, Theme.Space.xs)
        .frame(width: SessionView.columnWidth, height: Theme.Size.touch)
        .background(Theme.Color.surface)
    }
}

/// Launches every clip of its row.
struct SceneButton: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let scene: EchoelCore.Scene

    var body: some View {
        Button { engine.launch(scene.id, in: store.project) } label: {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: "play.fill").font(Theme.Font.caption)
                Text(scene.name).font(Theme.Font.label).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.Color.text)
            .padding(.horizontal, Theme.Space.s)
            .frame(width: SessionView.sceneWidth, height: Theme.Size.trackRowHeight)
            .background(Theme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete Scene", systemImage: "trash", role: .destructive) {
                try? store.perform(.removeScene(scene.id))
            }
        }
        .accessibilityLabel("Launch \(scene.name)")
    }
}

/// One slot: a clip to launch, or an empty slot that makes one.
struct SessionCell: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let track: Track
    let scene: EchoelCore.Scene
    let open: (TrackID, ClipID) -> Void

    var body: some View {
        if let id = track.clipInSlot(scene.id), let index = track.clipIndex(id) {
            filled(track.clips[index])
        } else {
            empty
        }
    }

    private func filled(_ clip: Clip) -> some View {
        let isPlaying = engine.session.playing[track.id] == clip.id
        let isQueued = engine.session.queued[track.id] == clip.id
        let color = Theme.Color.track(track.colorIndex)
        return Button { engine.launch(clip.id, on: track.id) } label: {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: isPlaying ? "play.fill" : "play")
                    .font(Theme.Font.caption)
                    .foregroundStyle(isPlaying ? Theme.Color.play : Theme.Color.textSecondary)
                Text(clip.name)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Space.s)
            .frame(width: SessionView.columnWidth, height: Theme.Size.trackRowHeight)
            .background(color.opacity(isPlaying ? 0.45 : 0.22))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(isQueued ? Theme.Color.accent : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pianokeys") { open(track.id, clip.id) }
            Button("Remove from Slot", systemImage: "minus.circle") {
                try? store.perform(.setSlot(track: track.id, scene: scene.id, clip: nil))
            }
        }
        .accessibilityLabel("\(clip.name) on \(track.name)")
        .accessibilityValue(isPlaying ? "Playing" : isQueued ? "Starts on the next bar" : "Stopped")
        .accessibilityHint("Launches the clip.")
        .accessibilityAction(named: "Edit") { open(track.id, clip.id) }
    }

    private var empty: some View {
        Button(action: makeClip) {
            Image(systemName: "plus")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
                .frame(width: SessionView.columnWidth, height: Theme.Size.trackRowHeight)
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Empty slot, \(track.name), \(scene.name)")
        .accessibilityHint("Makes a new clip here and opens it.")
    }

    /// A one-bar clip in this slot, as one undo step, then the editor.
    private func makeClip() {
        let clip = ClipID()
        let length = MusicalTime.ticksPerBar(store.project.timeSignature)
        let name = "\(track.name) \(track.clips.count + 1)"
        do {
            try store.perform([.createClip(track: track.id, id: clip, name: name, length: length),
                               .setSlot(track: track.id, scene: scene.id, clip: clip)], title: "New Clip")
            open(track.id, clip)
        } catch {}
    }
}

/// Stop all, back to the arrangement, and the launch quantization.
struct SessionFooter: View {
    @Environment(AudioEngine.self) private var engine

    private struct Choice: Hashable {
        let name: String
        let ticks: Tick?
    }

    private static let choices = [
        Choice(name: "1 Bar", ticks: nil), Choice(name: "1/4", ticks: MusicalTime.ticksPerQuarter),
        Choice(name: "None", ticks: 0),
    ]

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Button("Stop All", systemImage: "stop.fill") { engine.stopAllClips() }
                .buttonStyle(ToolButtonStyle())
                .disabled(engine.session.playing.isEmpty)
            Button("Back to Arrangement", systemImage: "arrow.uturn.backward.circle") { engine.backToArrangement() }
                .buttonStyle(ToolButtonStyle(isActive: !engine.session.detached.isEmpty, activeColor: Theme.Color.accent))
                .disabled(engine.session.detached.isEmpty)
            Spacer(minLength: Theme.Space.s)
            Menu {
                ForEach(Self.choices, id: \.self) { choice in
                    Button {
                        engine.setLaunchQuantum(choice.ticks)
                    } label: {
                        if engine.session.quantum == choice.ticks {
                            Label(choice.name, systemImage: "checkmark")
                        } else {
                            Text(choice.name)
                        }
                    }
                }
            } label: {
                Text("Launch: \(Self.choices.first { $0.ticks == engine.session.quantum }?.name ?? "1 Bar")")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(minHeight: Theme.Size.touch)
            }
            .accessibilityLabel("Launch quantization")
        }
        .padding(.horizontal, Theme.Space.m)
        .background(Theme.Color.surface)
    }
}
