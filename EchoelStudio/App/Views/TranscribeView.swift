import EchoelCore
import SwiftUI

/// Transcribe (SUBS): the speech in one audio region or in the sound of one video part as subtitles
/// at the same place, recognized on this device — the audio never leaves it. Opened from the part's
/// hold menu through the one sheet slot. The file is read off the main thread and the reading can
/// be cancelled; the cues are one undo step through the one door (`placeSubtitles`), replacing the
/// subtitles they overlap.
struct TranscribeView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    @Environment(\.dismiss) private var dismiss
    let trackID: TrackID
    let regionID: RegionID

    @State private var languages: [Locale] = []
    @State private var language = Locale.current.identifier
    @State private var job: Task<Void, Never>?
    @State private var outcome: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Transcribe")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(outcome == nil ? "Cancel" : "Done") { close() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Transcribe") { transcribe() }
                            .disabled(job != nil || outcome != nil || source == nil || languages.isEmpty)
                    }
                }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: loadLanguages)
        .onDisappear { job?.cancel() }
    }

    /// The part and its file as the song has them now; nil once either is gone.
    private var source: (region: AudioRegion, file: MediaFile)? {
        guard let track = store.project.track(trackID), let index = track.regionIndex(regionID) else { return nil }
        let region = track.regions[index]
        guard let file = store.project.mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite else {
            return nil
        }
        return (region, file)
    }

    @ViewBuilder private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                if let source {
                    Text(source.file.name)
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Text("Turns the speech in this part into subtitles on the timeline. Recognition runs on this device; the audio does not leave it. Subtitles already in this stretch are replaced.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    languagePicker
                    status
                } else {
                    Text("This part is no longer in the song.")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.Color.background)
    }

    @ViewBuilder private var languagePicker: some View {
        if languages.isEmpty {
            Text("Speech recognition is not available on this device.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
        } else {
            Picker("Language", selection: $language) {
                ForEach(languages, id: \.identifier) { locale in
                    Text(SpeechTranscription.name(of: locale)).tag(locale.identifier)
                }
            }
            .pickerStyle(.menu)
            .disabled(job != nil || outcome != nil)
        }
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

    /// The device's languages, the current one chosen when it is among them.
    private func loadLanguages() {
        guard languages.isEmpty else { return }
        let found = SpeechTranscription.languages()
        languages = found
        let current = Locale.current
        if let match = found.first(where: { $0.identifier == current.identifier })
            ?? found.first(where: { $0.language.languageCode == current.language.languageCode }) {
            language = match.identifier
        } else if let first = found.first {
            language = first.identifier
        }
    }

    private func close() {
        job?.cancel()
        dismiss()
    }

    /// Hears the part off the main thread, then writes the cues through the one door.
    private func transcribe() {
        guard let source, let url = documents.mediaURL(source.file) else {
            outcome = "The file is not where the song keeps it; transcribing needs it."
            return
        }
        let rate = source.file.sampleRate
        let start = Double(source.region.offset) / rate, length = Double(source.region.length) / rate
        let locale = Locale(identifier: language)
        let project = store.project
        let origin = project.tempoMap.seconds(at: source.region.start)
        // A part that follows the tempo plays its file faster or slower: its speech lands stretched.
        var scale = 1.0
        if source.region.warpBPM != nil, let stop = Arranging.end(of: source.region, in: project), length > 0 {
            let played = project.tempoMap.seconds(at: stop) - origin
            if played.isFinite, played > 0 { scale = played / length }
        }
        job = Task {
            let hearing = Task.detached(priority: .userInitiated) { () async throws -> [Subtitles.Word] in
                try await SpeechTranscription.words(of: url, from: start, length: length, locale: locale)
            }
            let result = await withTaskCancellationHandler { await hearing.result } onCancel: { hearing.cancel() }
            job = nil
            guard !Task.isCancelled else { return }
            switch result {
            case .failure(let error):
                if error is CancellationError { return }
                outcome = (error as? SpeechTranscription.Failure)?.message ?? SpeechTranscription.Failure.recognizer.message
            case .success(let words):
                let cues = Subtitles.placed(Subtitles.cues(from: words), at: origin, scale: scale,
                                            tempoMap: store.project.tempoMap)
                guard !cues.isEmpty else {
                    outcome = "No speech was heard in this part."
                    return
                }
                do {
                    try store.perform(.placeSubtitles(cues))
                    outcome = "\(cues.count) \(cues.count == 1 ? "subtitle" : "subtitles") added. Edit them under Song, Subtitles…"
                } catch {
                    outcome = "The subtitles could not be added to the song."
                }
            }
        }
    }
}
