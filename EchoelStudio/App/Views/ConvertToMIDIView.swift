import EchoelCore
import SwiftUI

/// Convert to MIDI (A2M): the melody of one audio region as a MIDI clip at the same place, on a
/// new instrument track or a chosen one. Opened from the region's hold menu through the one sheet
/// slot. The file is read off the main thread and the reading can be cancelled; the result is one
/// undo step through the one door (`AudioToMIDI.commands`). One voice only — said on the page.
struct ConvertToMIDIView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    @Environment(\.dismiss) private var dismiss
    let trackID: TrackID
    let regionID: RegionID

    /// nil is a new instrument track.
    @State private var destination: TrackID?
    @State private var snap: SnapGrid = .off
    @State private var snapsToKey = false
    @State private var job: Task<Void, Never>?
    @State private var outcome: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Convert to MIDI")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(outcome == nil ? "Cancel" : "Done") { close() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Convert") { convert() }
                            .disabled(job != nil || outcome != nil || source == nil)
                    }
                }
        }
        .preferredColorScheme(.dark)
        .onDisappear { job?.cancel() }
    }

    /// The region and its file as the song has them now; nil once either is gone.
    private var source: (region: AudioRegion, file: MediaFile)? {
        guard let track = store.project.track(trackID), let index = track.regionIndex(regionID) else { return nil }
        let region = track.regions[index]
        guard let file = store.project.mediaFile(region.media), file.kind == .audio else { return nil }
        return (region, file)
    }

    private var instrumentTracks: [Track] { store.project.tracks.filter { $0.kind == .instrument } }

    @ViewBuilder private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                if let source {
                    Text(source.file.name)
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Text("Hears one voice: a melody sung, whistled or played one note at a time. In a chord or a mix only the leading voice is found; drums are not converted.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    options
                    status
                } else {
                    Text("This region is no longer in the song.")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.Color.background)
    }

    @ViewBuilder private var options: some View {
        Picker("Track", selection: $destination) {
            Text("New Instrument Track").tag(TrackID?.none)
            ForEach(instrumentTracks) { track in
                Text(track.name).tag(TrackID?.some(track.id))
            }
        }
        .pickerStyle(.menu)
        .disabled(job != nil || outcome != nil)
        SnapPicker(snap: $snap)
            .disabled(job != nil || outcome != nil)
        Toggle("Snap to Key (\(store.project.context.title))", isOn: $snapsToKey)
            .toggleStyle(EchoelToggleStyle())
            .disabled(store.project.context.scale == .chromatic || job != nil || outcome != nil)
            .accessibilityHint("Moves every note into the song's key and scale.")
    }

    @ViewBuilder private var status: some View {
        if job != nil {
            HStack(spacing: Theme.Space.s) {
                ProgressView().accessibilityLabel("Listening")
                Text("Listening…")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        if let outcome {
            Text(outcome)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
        }
    }

    private func close() {
        job?.cancel()
        dismiss()
    }

    /// Reads the region off the main thread, then writes the clip through the one door.
    private func convert() {
        guard let source, let url = documents.mediaURL(source.file) else {
            outcome = "The file is not where the song keeps it; converting needs it."
            return
        }
        let offset = source.region.offset, length = source.region.length
        let track = trackID, region = regionID
        let target: AudioToMIDI.Destination = destination.map { .track($0) } ?? .newTrack(TrackID())
        let chosen = AudioToMIDI.Options(snap: snap, snapsToKey: snapsToKey && store.project.context.scale != .chromatic)
        job = Task {
            let reading = Task.detached(priority: .userInitiated) {
                RegionNotes.notes(of: url, offset: offset, length: length, isCancelled: { Task.isCancelled })
            }
            let heard = await withTaskCancellationHandler { await reading.value } onCancel: { reading.cancel() }
            job = nil
            guard !Task.isCancelled else { return }
            guard let heard else {
                outcome = "The file could not be read."
                return
            }
            guard let commands = AudioToMIDI.commands(heard: heard.notes, region: region, on: track, in: store.project,
                                                      destination: target, options: chosen) else {
                outcome = heard.notes.isEmpty ? "No notes were heard in this region." : "The notes could not be added to the song."
                return
            }
            do {
                try store.perform(commands, title: AudioToMIDI.title)
                let count = heard.notes.count
                var line = "\(count) \(count == 1 ? "note" : "notes") heard."
                if heard.voicedShare < 0.5 {
                    line += " Much of this region has no single clear pitch, so only the leading voice was taken."
                }
                outcome = line
            } catch {
                outcome = "The notes could not be added to the song."
            }
        }
    }
}
