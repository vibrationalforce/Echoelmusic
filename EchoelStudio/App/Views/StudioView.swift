import EchoelCore
import SwiftUI

/// The root surface: transport on top, tracks below. Every edit goes through the store as a
/// command, so every edit is undoable — the transport's Undo/Redo show that from day one.
struct StudioView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            TransportBar()
            Divider().overlay(Theme.Color.border)
            TrackListView()
        }
        .background(Theme.Color.background)
        .onAppear { engine.update(store.project) }
        .onChange(of: store.project) { _, project in engine.update(project) }
    }
}

/// Play/Stop, tempo, click, undo/redo. Reads only cold state (tempo, flags), never the
/// playhead, so an open menu elsewhere is never rebuilt by the clock.
struct TransportBar: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @State private var clickOn = true

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Button {
                engine.isPlaying ? engine.stop() : engine.play()
            } label: {
                Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
            }
            .buttonStyle(ToolButtonStyle(isActive: engine.isPlaying, activeColor: Theme.Color.play))
            .accessibilityLabel(engine.isPlaying ? "Stop" : "Play")
            .disabled(!engine.isRunning)

            TempoField()

            Button {
                clickOn.toggle()
                engine.setClickEnabled(clickOn)
            } label: {
                Image(systemName: "metronome")
            }
            .buttonStyle(ToolButtonStyle(isActive: clickOn))
            .accessibilityLabel("Click")
            .accessibilityValue(clickOn ? "On" : "Off")

            Spacer(minLength: Theme.Space.s)

            Text(store.project.name)
                .font(Theme.Font.title)
                .foregroundStyle(Theme.Color.text)
                .lineLimit(1)

            Spacer(minLength: Theme.Space.s)

            Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(ToolButtonStyle())
                .disabled(!store.canUndo)
                .accessibilityLabel(store.undoTitle.map { "Undo \($0)" } ?? "Undo")

            Button { store.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(ToolButtonStyle())
                .disabled(!store.canRedo)
                .accessibilityLabel(store.redoTitle.map { "Redo \($0)" } ?? "Redo")
        }
        .padding(.horizontal, Theme.Space.m)
        .frame(minHeight: Theme.Size.transportHeight)
        .dynamicTypeSize(...Theme.Accessibility.denseStripLimit)
        .background(Theme.Color.surface)
        .overlay(alignment: .bottom) {
            if let error = engine.lastError {
                Text(error)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, 2)
            }
        }
    }
}

/// Tempo as a number you drag vertically (up = faster) or step with the buttons. One drag is
/// one undo step.
struct TempoField: View {
    @Environment(ProjectStore.self) private var store
    @State private var dragStart: Double?
    @ScaledMetric(relativeTo: .title2) private var valueWidth: CGFloat = 72

    private static let gestureKey = "project.tempo"

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Button { nudge(-1) } label: { Image(systemName: "minus") }
                .buttonStyle(ToolButtonStyle())
                .accessibilityLabel("Slower")

            VStack(spacing: 0) {
                Text(store.project.tempo, format: .number.precision(.fractionLength(1)))
                    .font(Theme.Font.valueLarge)
                    .foregroundStyle(Theme.Color.text)
                Text("BPM")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .frame(minWidth: valueWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let start = dragStart ?? store.project.tempo
                        dragStart = start
                        // 4 pt per BPM, rounded to tenths.
                        let target = ((start - Double(value.translation.height) / 4) * 10).rounded() / 10
                        set(target)
                    }
                    .onEnded { _ in
                        dragStart = nil
                        store.endGesture()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(Int(store.project.tempo.rounded())) BPM")
            .accessibilityAdjustableAction { direction in
                nudge(direction == .increment ? 1 : -1)
            }

            Button { nudge(1) } label: { Image(systemName: "plus") }
                .buttonStyle(ToolButtonStyle())
                .accessibilityLabel("Faster")
        }
    }

    private func nudge(_ delta: Double) {
        set((store.project.tempo + delta).rounded())
        store.endGesture()
    }

    private func set(_ bpm: Double) {
        let clamped = min(max(bpm, Tempo.range.lowerBound), Tempo.range.upperBound)
        try? store.perform(.setTempo(bpm: clamped), coalescingKey: Self.gestureKey)
    }
}
