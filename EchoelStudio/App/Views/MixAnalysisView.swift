import EchoelCore
import EchoelDSP
import EchoelKernels
import SwiftUI

/// Mix Analysis, pushed from the master's effects: measures the song offline (loudness, true
/// peak, tilt against the target's reference, stereo image, stems that share an octave), then
/// proposes a master chain with every number and the measurement it comes from. Nothing changes
/// until Apply, which replaces the master's effects as one undo step. Measurement and arithmetic
/// only — no model runs here, and the page says "Analysis", never "AI".
struct MixAnalysisView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @AppStorage("master.assistant.target") private var target = MasterTarget.streaming
    @AppStorage("master.assistant.tone") private var tone = MasterTone.balanced

    @State private var report: DocumentController.MixReport?
    @State private var isMeasuring = false
    @State private var failed = false
    @State private var applied = false

    var body: some View {
        List {
            measureSection
            if let report {
                measuredSection(report.mix)
                if !report.hints.isEmpty || report.stemNames.count > 1 { maskingSection(report) }
                choiceSection
                if let suggestion = suggestion(for: report) {
                    ForEach(Array(suggestion.stages.enumerated()), id: \.offset) { _, stage in
                        stageSection(stage)
                    }
                    applySection(suggestion, song: report.song)
                }
            }
        }
        .echoelList()
        .navigationTitle("Mix Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func suggestion(for report: DocumentController.MixReport) -> MasterSuggestion? {
        MasterAssistant.suggest(from: report.mix, target: target, tone: tone,
                                masterVolume: store.project.master.volumeDB)
    }

    private var measureSection: some View {
        EchoelSection(footer: "Renders the song offline, without the master's effects, and measures it: "
                      + "the same song always measures the same. Nothing is changed until you apply.") {
            Button(isMeasuring ? "Measuring…" : (report == nil ? "Analyse Mix" : "Analyse Again")) {
                Task { await measure() }
            }
            .buttonStyle(EchoelRowButtonStyle())
            .disabled(isMeasuring || documents.isExporting)
            if isMeasuring, let progress = documents.exportProgress { NoteText(progress) }
            if failed { NoteText("Nothing plays in the song yet, or another song was opened.", tone: .warning) }
            if let missing = report?.missing, !missing.isEmpty {
                NoteText("Measured without \(missing.joined(separator: ", ")), which could not load.", tone: .warning)
            }
        }
    }

    private func measure() async {
        isMeasuring = true
        applied = false
        defer { isMeasuring = false }
        let result = await documents.analyzeMix(plugins: engine.plugins)
        failed = result == nil
        if let result { report = result }
    }

    private func measuredSection(_ mix: MixAnalysis) -> some View {
        EchoelSection("Measured") {
            ValueRow("Integrated Loudness", value: Self.number(mix.integratedLoudness, "LUFS"))
            ValueRow("True Peak", value: Self.number(mix.truePeak, "dBTP"))
            ValueRow("Tilt, 125 Hz–8 kHz", value: mix.tilt.map { Self.number($0, "dB/oct") } ?? "—")
            ValueRow("Reference Tilt", value: Self.number(target.referenceTilt, "dB/oct"))
            ValueRow("Correlation", value: mix.correlation.map { String(format: "%.2f", $0) } ?? "—")
            ValueRow("Correlation below 150 Hz", value: mix.lowCorrelation.map { String(format: "%.2f", $0) } ?? "—")
            ValueRow("Side to Mid", value: mix.sideToMid.map { Self.number($0, "dB") } ?? "—")
            ValueRow("Mono Sum", value: mix.monoLoss.map { Self.number($0, "dB") } ?? "—")
            ForEach(Array(MixAnalysis.bandCenters.enumerated()), id: \.offset) { index, hz in
                ValueRow("Band \(Self.hertz(hz))", value: Self.number(mix.bandLevels[index], "dBFS"))
            }
        }
    }

    private func maskingSection(_ report: DocumentController.MixReport) -> some View {
        EchoelSection("Masking", footer: "Tracks whose strongest octave is the same, within "
                      + "\(Int(MaskingHint.closeWithin)) dB of each other there. Which one gives way is yours to decide.") {
            if report.hints.isEmpty {
                NoteText("No two tracks share their strongest octave.")
            }
            ForEach(Array(report.hints.enumerated()), id: \.offset) { _, hint in
                let names = hint.stems.compactMap { report.stemNames.indices.contains($0) ? report.stemNames[$0] : nil }
                ValueRow("\(Self.hertz(hint.bandCenter)) octave",
                         value: names.joined(separator: " · ") + "  (" + Self.number(hint.spread, "dB") + ")")
            }
        }
    }

    private var choiceSection: some View {
        EchoelSection("Suggest Master", footer: "Tone characters are the earlier Echoelmusic master's curves, "
                      + "added on top of the measured tilt correction.") {
            Picker("Target", selection: $target) {
                ForEach(MasterTarget.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            Picker("Tone", selection: $tone) {
                ForEach(MasterTone.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
        }
    }

    private func stageSection(_ stage: MasterSuggestion.Stage) -> some View {
        EchoelSection(stage.effect.title) {
            ForEach(Array(stage.values.enumerated()), id: \.offset) { _, value in
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    ValueRow(value.title, value: Self.format(value))
                    NoteText(value.reason)
                }
            }
        }
    }

    private func applySection(_ suggestion: MasterSuggestion, song: Int) -> some View {
        let replaced = store.project.masterInserts.count
        return EchoelSection(footer: replaced == 0
                             ? "Adds these effects to the master. Undo takes them away in one step."
                             : "Replaces the master's \(replaced) effect\(replaced == 1 ? "" : "s") with these. Undo brings them back in one step.") {
            if let volume = suggestion.masterVolume, let reason = suggestion.masterVolumeReason {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    ValueRow("Master Fader", value: Self.number(volume, "dB"))
                    NoteText(reason)
                }
            }
            ForEach(Array(suggestion.notes.enumerated()), id: \.offset) { _, note in NoteText(note) }
            Button("Apply to Master") {
                applied = documents.apply(suggestion, measuredOn: song)
            }
            .buttonStyle(EchoelRowButtonStyle())
            if applied { NoteText("Applied. Play the song, or export at \(target.loudness.title) to measure the result.") }
        }
    }

    private static func number(_ value: Double, _ unit: String) -> String {
        value.isFinite ? String(format: "%.1f %@", value, unit) : "−∞ \(unit)"
    }

    private static func hertz(_ hz: Double) -> String {
        hz >= 1_000 ? String(format: "%g kHz", hz / 1_000) : String(format: "%g Hz", hz)
    }

    private static func format(_ value: MasterSuggestion.Value) -> String {
        let number = Double(value.value)
        switch value.unit {
        case .hertz: return hertz(number)
        case .decibels: return Self.number(number, "dB")
        case .seconds: return String(format: "%.0f ms", number * 1_000)
        case .ratio: return String(format: "%.2f", number)
        case .amount, .boolean, .choice: return String(format: "%.2f", number)
        }
    }
}
