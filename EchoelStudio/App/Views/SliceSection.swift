import EchoelCore
import SwiftUI

/// Slice to Pads, on the sampler's page (the break slicer, EchoelTools A11): cuts the track's file
/// at the hits it finds — up to 16 pads on consecutive notes from 36 — and, if asked, writes the
/// pattern the loop played as a clip after the track's last one, so the break plays at the song's
/// tempo. One undo step takes all of it back. Each pad's start, tune and direction can be edited;
/// every edit is the same command with the new list.
struct SliceSection: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    let track: Track
    let file: MediaFile

    @State private var writesPattern = true
    @State private var isSlicing = false
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.s) {
                Button {
                    slice()
                } label: {
                    Label(isSlicing ? "Slicing…" : "Slice to Pads", systemImage: "square.grid.4x3.fill")
                        .font(Theme.Font.label)
                        .frame(minHeight: Theme.Size.touch)
                }
                .disabled(isSlicing)
                .accessibilityHint("Cuts the file at its hits into pads on notes 36 and up.")
                if track.instrument.slices != nil {
                    Button("Remove Slices") {
                        try? store.perform(.setSamplerSlices(track.id, []))
                    }
                    .font(Theme.Font.label)
                    .frame(minHeight: Theme.Size.touch)
                }
            }
            Toggle("Write the pattern as a clip", isOn: $writesPattern)
                .font(Theme.Font.body)
            if let problem {
                Text(problem)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            if let slices = track.instrument.slices {
                Text("\(slices.count) pads from \(NoteEditing.name(of: SampleSlice.firstNote)) (MIDI \(SampleSlice.firstNote)), each to the next pad's start, at the file's own speed.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                ForEach(slices.indices, id: \.self) { index in
                    padRow(index, slices)
                }
            }
        }
    }

    /// One pad: its start in milliseconds of the file (between its neighbours), its tune, its direction.
    private func padRow(_ index: Int, _ slices: [SampleSlice]) -> some View {
        let rate = file.sampleRate > 0 ? file.sampleRate : 48_000
        let ms = { (frame: Int) -> Int in Int((Double(frame) / rate * 1_000).rounded()) }
        let lower = index == 0 ? 0 : ms(slices[index - 1].start) + 1
        let upper = Swift.max(lower, (index + 1 < slices.count ? ms(slices[index + 1].start) : ms(file.frameCount)) - 1)
        let slice = slices[index]
        return HStack(alignment: .bottom, spacing: Theme.Space.s) {
            Text("\(index + 1)")
                .font(Theme.Font.value)
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(minWidth: 24)
                .accessibilityLabel("Pad \(index + 1), note \(SampleSlice.firstNote + index)")
            SettingField(title: "Start", value: Swift.min(Swift.max(ms(slice.start), lower), upper), range: lower...upper,
                         unit: "ms", spokenUnit: "milliseconds",
                         commit: { value in
                             var next = slices
                             next[index].start = Swift.min(Int((Double(value) / 1_000 * rate).rounded()), file.frameCount - 1)
                             try? store.perform(.setSamplerSlices(track.id, next), coalescingKey: "slices.\(track.id).\(index).start")
                         },
                         ended: { store.endGesture() })
            SettingField(title: "Tune", value: Int(slice.tune.rounded()),
                         range: Int(SampleSlice.tuneRange.lowerBound)...Int(SampleSlice.tuneRange.upperBound),
                         unit: "st", standard: 0, spokenUnit: "semitones",
                         commit: { value in
                             var next = slices
                             next[index].tune = Double(value)
                             try? store.perform(.setSamplerSlices(track.id, next), coalescingKey: "slices.\(track.id).\(index).tune")
                         },
                         ended: { store.endGesture() })
            Toggle("Reverse", isOn: Binding(
                get: { slice.reverse },
                set: { on in
                    var next = slices
                    next[index].reverse = on
                    try? store.perform(.setSamplerSlices(track.id, next))
                }
            ))
            .font(Theme.Font.caption)
            .fixedSize()
        }
    }

    /// Reads the file for its hits off the main thread, then cuts it through the one door.
    private func slice() {
        guard let url = documents.mediaURL(file) else {
            problem = "The file is not where the song keeps it; slicing needs it."
            return
        }
        isSlicing = true
        problem = nil
        let target = track.id
        let source = file
        let pattern = writesPattern
        Task {
            let onsets = await Task.detached(priority: .userInitiated) { BreakOnsets.onsets(of: url) }.value
            let starts = BreakSlicing.starts(onsets: onsets, frameCount: source.frameCount, sampleRate: source.sampleRate)
            if let current = store.project.track(target) {
                let commands = BreakSlicing.commands(track: target, file: source, starts: starts, writePattern: pattern,
                                                     at: Self.afterLastClip(current, signature: store.project.timeSignature))
                do {
                    try store.perform(commands, title: "Slice to Pads")
                } catch {
                    problem = "The file could not be sliced."
                }
            }
            isSlicing = false
        }
    }

    /// Where a new clip goes: the bar after the track's last placed clip ends, or the song's start.
    static func afterLastClip(_ track: Track, signature: TimeSignature) -> Tick {
        let end = track.placements.compactMap { placement -> Tick? in
            track.clips.first { $0.id == placement.clip }.map { placement.start + $0.length }
        }.max() ?? 0
        let bar = MusicalTime.ticksPerBar(signature)
        guard bar > 0 else { return end }
        return (end + bar - 1) / bar * bar
    }
}
