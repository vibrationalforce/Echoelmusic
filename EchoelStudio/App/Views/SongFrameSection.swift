import EchoelCore
import SwiftUI

/// The song's groove and its tempo changes, on the Song page: swing as a value field, and each
/// tempo change as a bar with its tempo, typed on the number pad. Every edit is one command, so
/// one undo step. The page hosts the pad; the playhead is read only when a change is added,
/// never in a body, so nothing here rebuilds while the song plays.
struct SongFrameSection: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(NumberPadController.self) private var pad: NumberPadController?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            heading("Groove")
            ParameterField(address: .swing)
            caption("Swing delays every second sixteenth note; 0 plays them straight.")
            heading("Tempo Changes")
                .padding(.top, Theme.Space.m)
            caption("From bar 1 the song plays at \(bpmText(store.project.tempo)), the tempo in the transport.")
            ForEach(store.project.tempoChanges, id: \.tick) { change in
                row(change)
            }
            Button(action: addAtPlayhead) {
                Label("Add at Playhead Bar", systemImage: "plus")
                    .font(Theme.Font.label)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(Theme.Color.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Color.text)
            .accessibilityHint("Adds a tempo change at the bar nearest the playhead, at the tempo playing there.")
        }
    }

    private func row(_ change: TempoChange) -> some View {
        let place = Self.placeText(change.tick, signature: store.project.timeSignature)
        return HStack(spacing: Theme.Space.s) {
            Text(place)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { type(change, place: place) } label: {
                Text(bpmText(change.bpm))
                    .font(Theme.Font.value)
                    .foregroundStyle(pad?.request?.owner == Self.owner(change) ? Theme.Color.accent : Theme.Color.text)
                    .frame(minHeight: Theme.Size.touch)
                    .padding(.horizontal, Theme.Space.s)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .strokeBorder(Theme.Color.borderStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tempo at \(place)")
            .accessibilityValue(bpmText(change.bpm))
            .accessibilityHint("Type a tempo.")
            Button {
                try? store.perform(.removeTempoChange(at: change.tick))
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(ToolButtonStyle())
            .accessibilityLabel("Remove the tempo change at \(place)")
        }
    }

    /// Types the change's tempo on the page's pad; the typed tempo replaces it at the same tick.
    private func type(_ change: TempoChange, place: String) {
        let tick = change.tick
        pad?.open(NumberPadRequest(owner: Self.owner(change), title: "Tempo at \(place)",
                                   format: NumberEntryFormat(scale: 1, decimals: 1, unit: "BPM"),
                                   range: Tempo.range, value: change.bpm, standard: nil) { typed in
            try? store.perform(.setTempoChange(at: tick, bpm: typed))
        })
    }

    /// A change at the bar nearest the playhead, at the tempo that plays there. At bar 1 — where
    /// the transport's tempo rules — it goes one bar after the last change instead.
    private func addAtPlayhead() {
        let project = store.project
        let signature = project.timeSignature
        let bar = MusicalTime.ticksPerBar(signature)
        var tick = Arranging.nearestBar(engine.playheadTick(in: project), signature: signature)
        if tick == 0 { tick = (project.tempoChanges.map(\.tick).max() ?? 0) / bar * bar + bar }
        try? store.perform(.setTempoChange(at: tick, bpm: project.tempoMap.bpm(at: tick)))
    }

    private static func owner(_ change: TempoChange) -> String { "tempoChange/\(change.tick)" }

    /// "Bar 9", or "Bar 9, beat 3" for a change that does not fall on a bar line (an assistant's
    /// or an imported file's), counted in the song's time signature.
    static func placeText(_ tick: Tick, signature: TimeSignature) -> String {
        let bar = MusicalTime.ticksPerBar(signature), beat = MusicalTime.ticksPerBeat(signature)
        guard bar > 0, beat > 0 else { return "Tick \(tick)" }
        let within = tick % bar
        let barText = "Bar \(tick / bar + 1)"
        guard within != 0 else { return barText }
        let beats = Double(within) / Double(beat) + 1
        return barText + ", beat " + NumberText.string(beats, decimalsUpTo: 2)
    }

    private func bpmText(_ bpm: Double) -> String {
        NumberText.string(bpm, decimals: 1, unit: "BPM")
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.label)
            .foregroundStyle(Theme.Color.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textSecondary)
    }
}
