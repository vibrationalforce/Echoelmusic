import EchoelCore
import SwiftUI

/// The song's subtitles (SUBS): each cue's text and its times, to correct or delete. Every change
/// is one undo step through the one door; a change the song cannot hold — text for a third line,
/// a cue running into the next — is refused and said. Opened from the Song menu ("Subtitles…").
struct SubtitlesView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Subtitles")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            store.endGesture()
                            dismiss()
                        }
                    }
                }
        }
        .numberPadHost()
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.l) {
                if store.project.subtitles.isEmpty {
                    Text("No subtitles yet. Hold an audio or video part and choose Transcribe… to make them from its speech.")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                if let problem {
                    Text(problem)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.warning)
                }
                ForEach(store.project.subtitles) { cue in
                    SubtitleRow(cue: cue, map: store.project.tempoMap, perform: perform)
                }
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.Color.background)
    }

    private func perform(_ command: Command, coalescing key: String?) {
        do {
            try store.perform(command, coalescingKey: key)
            problem = nil
        } catch {
            switch command {
            case .setSubtitleText:
                problem = "A subtitle holds at most two lines of \(Subtitles.maximumLineLength) characters, and not nothing."
            case .setSubtitleTiming:
                problem = "A subtitle ends after it starts and never runs into the next one."
            default:
                problem = "The change could not be made."
            }
        }
    }
}

/// One cue: its text, typed and kept on Return or when the field lets go, and its start and end in
/// seconds on Echoel's value fields.
private struct SubtitleRow: View {
    let cue: SubtitleCue
    let map: TempoMap
    let perform: (Command, String?) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    /// The longest time a field offers: ten hours, in milliseconds.
    private static let range = 0...36_000_000

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            textField
            HStack(spacing: Theme.Space.m) {
                time("Start", milliseconds(cue.start)) { perform(.setSubtitleTiming(cue.id, start: $0, end: cue.end), "subtitle.start.\(cue.id)") }
                time("End", milliseconds(cue.end)) { perform(.setSubtitleTiming(cue.id, start: cue.start, end: $0), "subtitle.end.\(cue.id)") }
                Button("Delete", systemImage: "trash", role: .destructive) { perform(.removeSubtitle(cue.id), nil) }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                    .accessibilityLabel("Delete subtitle")
            }
        }
        .onAppear { draft = cue.text }
        .onChange(of: cue.text) { _, text in if !focused { draft = text } }
    }

    private var textField: some View {
        TextField("Text", text: $draft, axis: .vertical)
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.text)
            .lineLimit(1...3)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit(commitText)
            .onChange(of: focused) { _, now in if !now { commitText() } }
            .padding(Theme.Space.s)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.Color.border, lineWidth: 1))
    }

    private func commitText() {
        let clean = Subtitles.normalized(draft)
        guard clean != cue.text else { return }
        perform(.setSubtitleText(cue.id, text: draft), nil)
    }

    private func time(_ title: String, _ value: Int, commit: @escaping (Tick) -> Void) -> some View {
        SettingField(title: title, value: Swift.min(Swift.max(value, Self.range.lowerBound), Self.range.upperBound),
                     range: Self.range, unit: "s", decimals: 3, step: 10, spokenUnit: "seconds", drags: false,
                     commit: { commit(tick(milliseconds: $0)) })
    }

    private func milliseconds(_ tick: Tick) -> Int { Subtitles.milliseconds(map.seconds(at: tick)) }

    private func tick(milliseconds: Int) -> Tick {
        MusicalTime.integer(map.position(atSeconds: Double(milliseconds) / 1_000).rounded())
    }
}
