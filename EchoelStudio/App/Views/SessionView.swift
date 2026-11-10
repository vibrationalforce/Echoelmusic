import EchoelCore
import SwiftUI

/// The session: instrument and audio tracks as columns, scenes as rows. Tap a clip to launch it
/// on the next bar, a scene to launch its row, an empty slot to make a clip — a MIDI clip, or on
/// an audio track a loop from a file. Launch state comes from the engine; every document change
/// is a command.
struct SessionView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    /// Opens a clip in the editor.
    let open: (TrackID, ClipID) -> Void
    /// Picks a file for an audio track's empty slot.
    let importClip: (TrackID, SceneID) -> Void

    /// Wide enough for a track's name of about twelve letters beside its stop button (device
    /// video 10021: "Instr…").
    static let columnWidth: CGFloat = 152
    static let sceneWidth: CGFloat = 112

    var body: some View {
        let tracks = store.project.tracks.filter { $0.kind == .instrument || $0.kind == .audio }
        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    header(tracks)
                    ForEach(store.project.scenes) { scene in
                        row(scene, tracks)
                    }
                    addScene
                }
                .padding(Theme.Space.s)
            }
            // Anchored top left, where a grid starts, rather than floating small in the middle
            // of the screen while it is smaller than the view (device video 10021).
            .defaultScrollAnchor(.topLeading)
            Divider().overlay(Theme.Color.border)
            SessionFooter()
        }
        .background(Theme.Color.background)
    }

    private func header(_ tracks: [Track]) -> some View {
        HStack(spacing: Theme.Space.hairline) {
            Color.clear.frame(width: Self.sceneWidth, height: 1)
            ForEach(tracks) { track in
                SessionTrackHeader(track: track)
            }
        }
    }

    private func row(_ scene: EchoelCore.Scene, _ tracks: [Track]) -> some View {
        HStack(spacing: Theme.Space.hairline) {
            SceneButton(scene: scene)
            ForEach(tracks) { track in
                SessionCell(track: track, scene: scene, open: open, importClip: importClip)
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
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { engine.stopClip(on: track.id) } label: { Image(systemName: "stop.fill") }
                // A clip sounds on this track: the glyph turns green, as Play's does.
                .buttonStyle(ToolButtonStyle(isRunning: isPlaying))
                .disabled(!isPlaying)
                .accessibilityLabel("Stop Clip on \(track.name)")
        }
        .padding(.horizontal, Theme.Space.xs)
        .frame(width: SessionView.columnWidth)
        .frame(minHeight: Theme.Size.touch)
        .background(Theme.Color.surface)
    }
}

/// Launches every clip of its row.
struct SceneButton: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(StudioRouter.self) private var router
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
            Button("Rename Scene…", systemImage: "pencil") { router.sheet = .rename(.scene(scene.id)) }
            Button("Delete Scene", systemImage: "trash", role: .destructive) {
                try? store.perform(.removeScene(scene.id))
            }
        }
        .accessibilityLabel("Launch \(scene.name)")
        .accessibilityAction(named: "Rename Scene") { router.sheet = .rename(.scene(scene.id)) }
    }
}

/// One slot: a clip to launch, or an empty slot that makes one.
struct SessionCell: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(StudioRouter.self) private var router
    let track: Track
    let scene: EchoelCore.Scene
    let open: (TrackID, ClipID) -> Void
    let importClip: (TrackID, SceneID) -> Void

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
                Image(systemName: clip.audio != nil ? "waveform" : isPlaying ? "play.fill" : "play")
                    .font(Theme.Font.caption)
                    .foregroundStyle(isPlaying ? Theme.Color.play : Theme.Color.textSecondary)
                Text(clip.name)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                // What is left until it starts, its own leaf: only it reads the playhead.
                if isQueued, let launch = engine.session.launchTicks[track.id] {
                    LaunchCountdownLabel(launch: launch)
                }
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
            if clip.audio == nil {
                Button("Edit Notes", systemImage: "pianokeys") { open(track.id, clip.id) }
            } else {
                loopMenu(clip)
            }
            Button("Rename Clip…", systemImage: "pencil") { router.sheet = .rename(.clip(clip.id)) }
            Button("Remove from Slot", systemImage: "minus.circle") {
                try? store.perform(.setSlot(track: track.id, scene: scene.id, clip: nil))
            }
            // The clip itself: out of every slot and every place in the arrangement (undoable).
            Button("Delete Clip", systemImage: "trash", role: .destructive) {
                try? store.perform(.deleteClip(clip.id))
            }
        }
        .accessibilityLabel("\(clip.name) on \(track.name)")
        .accessibilityValue(isPlaying ? "Playing" : isQueued ? "Starts on the next bar" : "Stopped")
        .accessibilityHint("Launches the clip.")
        .accessibilityActions {
            if clip.audio == nil { Button("Edit Notes") { open(track.id, clip.id) } }
            Button("Rename Clip") { router.sheet = .rename(.clip(clip.id)) }
            Button("Delete Clip") { try? store.perform(.deleteClip(clip.id)) }
        }
    }

    /// An audio clip's loop, in whole bars.
    private func loopMenu(_ clip: Clip) -> some View {
        // Bars of the clip's own meter: the song's from where the clip is placed, else the first
        // bar's signature (a session-only clip has no place in the song).
        let meter = store.project.clipMeter(clip.id)
        return Menu("Loop", systemImage: "repeat") {
            ForEach([1, 2, 4, 8, 16], id: \.self) { bars in
                let length = Swift.max(Arranging.ticks(movingBars: Int64(bars), from: 0, meter: meter), 1)
                Button {
                    try? store.perform(.setClipLength(clip.id, length: length))
                } label: {
                    let title = bars == 1 ? "1 Bar" : "\(bars) Bars"
                    if clip.length == length { Label(title, systemImage: "checkmark") } else { Text(title) }
                }
            }
        }
    }

    private var empty: some View {
        Button(action: track.kind == .audio ? { importClip(track.id, scene.id) } : makeClip) {
            Image(systemName: "plus")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
                .frame(width: SessionView.columnWidth, height: Theme.Size.trackRowHeight)
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Empty Slot, \(track.name), \(scene.name)")
        .accessibilityHint(track.kind == .audio ? "Picks an audio file to loop here." : "Makes a new clip here and opens it.")
    }

    /// A one-bar clip in this slot, as one undo step, then the editor.
    private func makeClip() {
        let clip = ClipID()
        let length = MusicalTime.ticksPerBar(store.project.timeSignature)
        let name = Names.derived(track.name, suffix: "\(track.clips.count + 1)")
        do {
            try store.perform([.createClip(track: track.id, id: clip, name: name, length: length),
                               .setSlot(track: track.id, scene: scene.id, clip: clip)], title: "New Clip")
            open(track.id, clip)
        } catch {}
    }
}

/// "3 beats" on a queued clip: what is left until the tick the render thread fixed for its launch,
/// from where the song is heard — bars while more than one is left, then beats. Its own leaf
/// (Law 6): it polls the playhead ten times a second while the clip waits, and only then. The
/// number steps down once a beat in the same colour and size; nothing blinks.
private struct LaunchCountdownLabel: View {
    let launch: Tick
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        // Read outside the timeline: a stop redraws it.
        let playing = engine.isPlaying
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            if playing, let text = countdown() {
                Text(text)
                    .font(Theme.Font.caption.monospacedDigit())
                    .foregroundStyle(Theme.Color.accent)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel("Starts in \(text)")
            }
        }
    }

    private func countdown() -> String? {
        let project = store.project
        let heard = engine.heardTick(in: project)
        let meter = engine.playedMeterMap(of: project)
        return LaunchCountdown.text(LaunchCountdown.remaining(until: launch, from: heard, meter: meter))
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
        // One row where it fits; on a phone in portrait the launch choice takes a row of its own
        // rather than squeezing the buttons (device video 10021).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Space.s) {
                buttons
                Spacer(minLength: Theme.Space.s)
                quantization
            }
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack(spacing: Theme.Space.s) { buttons }
                quantization
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface)
    }

    private var buttons: some View {
        Group {
            Button("Stop All", systemImage: "stop.fill") { engine.stopAllClips() }
                .buttonStyle(ToolButtonStyle())
                .disabled(engine.session.playing.isEmpty)
            Button("Back to Arrangement", systemImage: "arrow.uturn.backward.circle") { engine.backToArrangement() }
                .buttonStyle(ToolButtonStyle(isActive: !engine.session.detached.isEmpty))
                .disabled(engine.session.detached.isEmpty)
        }
    }

    private var quantization: some View {
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
            HStack(spacing: Theme.Space.xs) {
                Text("Launch")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.textSecondary)
                Text(Self.choices.first { $0.ticks == engine.session.quantum }?.name ?? "1 Bar")
                    .font(Theme.Font.value)
                    .foregroundStyle(Theme.Color.text)
                Image(systemName: "chevron.down")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.Size.touch)
        }
        .accessibilityLabel("Launch Quantization")
        .accessibilityValue(Self.choices.first { $0.ticks == engine.session.quantum }?.name ?? "1 Bar")
    }
}
