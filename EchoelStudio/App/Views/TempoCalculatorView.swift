import EchoelCore
import SwiftUI
import UIKit

/// The tempo calculator (2026-11-27), from the Song menu: the song's tempo — or one typed or tapped
/// here — as exact lengths. One bar in seconds, samples and video frames; every note value from 1/2
/// to 1/64, straight, dotted and triplet, in s, ms or Hz; the same values sorted, longest first;
/// the tempo a loop's length implies; and pitch at the song's concert pitch. Nothing is rounded: a
/// repeating digit carries a bar, a shortened value ends in "…", and a long press on any value shows
/// and copies the full one (`TempoCalculator`, `ExactText`). The page changes the song only through
/// Use for Song, one undo step.
struct TempoCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TempoCalculatorPage()
                .navigationTitle("Tempo Calculator")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                    }
                }
                // Inside the page, so its fields type on Echoel's number pad without a sheet of
                // their own (Law 7).
                .numberPadHost()
        }
        .preferredColorScheme(.dark)
    }
}

/// The video frame rates the page offers; 29.97 is 30000/1001 frames per second, exactly.
private enum CalculatorFrameRate: Hashable, CaseIterable {
    case film, pal, ntsc, thirty, sixty

    var rate: Rational {
        switch self {
        case .film: 24
        case .pal: 25
        case .ntsc: Rational(numerator: 30_000, denominator: 1_001) ?? 30
        case .thirty: 30
        case .sixty: 60
        }
    }

    var title: String {
        switch self {
        case .film: "24"
        case .pal: "25"
        case .ntsc: "29.97"
        case .thirty: "30"
        case .sixty: "60"
        }
    }
}

/// The page, inside the number pad's host.
private struct TempoCalculatorPage: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(NumberPadController.self) private var pad: NumberPadController?
    /// The tempo the page works with: the song's when the page opens, then what is typed or tapped.
    @State private var tempo: Rational?
    @State private var unit: TempoCalculator.DelayUnit = .milliseconds
    @State private var frameRate: CalculatorFrameRate = .thirty
    @State private var taps = TapTempo()
    /// A loop's length in seconds, typed, and how many bars it holds.
    @State private var length: Rational?
    @State private var lengthBars = 1

    private let marks = NumberMarks(locale: .current)

    var body: some View {
        List {
            tempoSection
            if let calculator {
                barSection(calculator)
                tableSection(calculator)
                sortedSection(calculator)
                lengthSection(calculator)
            }
            pitchSection
        }
        .echoelList()
        .onAppear {
            if tempo == nil { tempo = songTempo }
        }
    }

    private var songTempo: Rational? { Rational(stored: store.project.tempo) }

    /// The rate the audio runs at now; 48 kHz before the engine has started.
    private var sampleRate: Rational {
        engine.sampleRate.flatMap { Rational(roundTripping: $0) } ?? 48_000
    }

    private var calculator: TempoCalculator? {
        guard let tempo else { return nil }
        let signature = store.project.timeSignature
        return TempoCalculator(bpm: tempo, sampleRate: sampleRate, beatsPerBar: signature.numerator,
                               beatUnit: signature.denominator, frameRate: frameRate.rate)
    }

    // MARK: Tempo

    private var tempoSection: some View {
        EchoelSection("Tempo", footer: "Typed to a thousandth of a BPM, tapped to a tenth. The song keeps its own tempo until Use for Song.") {
            HStack(spacing: Theme.Space.m) {
                Text("Tempo")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.text)
                Spacer(minLength: Theme.Space.s)
                if let tempo {
                    ExactValueText(ExactText(tempo, marks: marks), unit: "BPM", name: "Tempo")
                }
            }
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
            .onTapGesture { typeTempo() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Types a tempo on the number pad.")
            .accessibilityAction { typeTempo() }
            Button("Tap", systemImage: "hand.tap") { tap() }
                .buttonStyle(EchoelRowButtonStyle())
                .accessibilityHint("Tap in time, twice or more.")
            Button("Song Tempo", systemImage: "arrow.uturn.backward") { tempo = songTempo }
                .buttonStyle(EchoelRowButtonStyle())
                .disabled(tempo == songTempo)
            Button("Use for Song", systemImage: "checkmark") { useForSong() }
                .buttonStyle(EchoelRowButtonStyle())
                .disabled(tempo == nil || tempo == songTempo)
        }
    }

    private func typeTempo() {
        guard let pad else { return }
        pad.open(NumberPadRequest(owner: "calculator.tempo", title: "Tempo",
                                  format: NumberEntryFormat(scale: 1, decimals: 3, unit: "BPM"),
                                  range: Tempo.range, value: tempo?.doubleValue ?? store.project.tempo,
                                  standard: store.project.tempo) { typed in
            tempo = Rational(roundTripping: typed)
        })
    }

    private func tap() {
        if let bpm = taps.tap(at: ProcessInfo.processInfo.systemUptime) {
            tempo = Rational(roundTripping: bpm)
        }
    }

    private func useForSong() {
        guard let tempo else { return }
        documents.attempt(.setTempo(bpm: tempo.doubleValue))
    }

    // MARK: One bar

    private func barSection(_ calculator: TempoCalculator) -> some View {
        let signature = "\(calculator.beatsPerBar)/\(calculator.beatUnit)"
        return EchoelSection("One Bar", footer: "In \(signature), at the \(ExactText(sampleRate, marks: marks).full) Hz the audio runs at. 29.97 frames per second is 30000/1001.") {
            if let seconds = calculator.barSeconds {
                let time = ExactUnits.time(seconds, marks: marks)
                ExactValueRow("Length", time.text, unit: time.unit)
                if let samples = calculator.samples(ofSeconds: seconds) {
                    ExactValueRow("Samples", ExactText(samples, marks: marks))
                }
                if let frames = calculator.frames(ofSeconds: seconds) {
                    ExactValueRow("Frames", ExactText(frames, marks: marks))
                }
            }
            EchoelSegments("Frame Rate", selection: $frameRate,
                           options: CalculatorFrameRate.allCases.map { SegmentOption($0, $0.title) })
                .padding(.vertical, Theme.Space.xs)
        }
    }

    // MARK: Note values

    private func tableSection(_ calculator: TempoCalculator) -> some View {
        EchoelSection("Note Values", footer: "A long press on a value shows all its digits and copies it.") {
            EchoelSegments("Unit", selection: $unit,
                           options: TempoCalculator.DelayUnit.allCases.map { SegmentOption($0, $0.symbol) })
                .padding(.vertical, Theme.Space.xs)
            tableHeader
            ForEach(NoteValue.denominators.filter { $0 >= 2 }, id: \.self) { denominator in
                tableRow(calculator, denominator: denominator)
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: Theme.Space.s) {
            Color.clear.frame(width: 44, height: 1)
            ForEach(NoteValue.Feel.allCases, id: \.self) { feel in
                Text(feelTitle(feel))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityHidden(true)
    }

    private func feelTitle(_ feel: NoteValue.Feel) -> String {
        switch feel {
        case .straight: "Normal"
        case .dotted: "Dotted"
        case .triplet: "Triplet"
        }
    }

    private func tableRow(_ calculator: TempoCalculator, denominator: Int) -> some View {
        HStack(spacing: Theme.Space.s) {
            Text("1/\(denominator)")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(width: 44, alignment: .leading)
                .accessibilityHidden(true)
            ForEach(NoteValue.Feel.allCases, id: \.self) { feel in
                tableCell(calculator, note: NoteValue(denominator: denominator, feel: feel))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: Theme.Size.touch)
    }

    @ViewBuilder
    private func tableCell(_ calculator: TempoCalculator, note: NoteValue?) -> some View {
        if let note, let value = calculator.value(of: note, in: unit) {
            ExactValueText(ExactText(value, marks: marks, compactDigits: 5), unit: unit.symbol, name: note.name)
        } else {
            Text("–")
                .font(Theme.Font.value)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    // MARK: Sorted

    private func sortedSection(_ calculator: TempoCalculator) -> some View {
        let values: [ExactText] = calculator.sortedDelays.compactMap { row in
            calculator.value(of: row.note, in: unit).map { ExactText($0, marks: marks, compactDigits: 5) }
        }
        let compact = values.map(\.compact).joined(separator: " · ")
        let full = values.map(\.full).joined(separator: " · ") + " " + unit.symbol
        return EchoelSection("Sorted", footer: "Every note value above in \(unit.symbol), longest note first. A long press copies the list.") {
            Text(compact)
                .font(Theme.Font.value)
                .foregroundStyle(Theme.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Theme.Space.xs)
                .contextMenu {
                    Button("Copy List", systemImage: "doc.on.doc") { UIPasteboard.general.string = full }
                }
                .accessibilityLabel("Sorted, in \(unit.symbol)")
                .accessibilityValue(values.map(\.spoken).joined(separator: "; "))
        }
    }

    // MARK: Tempo from a length

    private func lengthSection(_ calculator: TempoCalculator) -> some View {
        EchoelSection("Tempo from a Length", footer: "A loop's length in seconds and the bars it holds give its tempo, exactly.") {
            HStack(spacing: Theme.Space.m) {
                Text("Length")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.text)
                Spacer(minLength: Theme.Space.s)
                if let length {
                    ExactValueText(ExactText(length, marks: marks), unit: "s", name: "Length")
                } else {
                    Text("Tap to type")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
            .onTapGesture { typeLength() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { typeLength() }
            EchoelSegments("Bars", selection: $lengthBars, options: [1, 2, 4, 8].map { SegmentOption($0, "\($0)") })
                .padding(.vertical, Theme.Space.xs)
            if let length, let quarters = calculator.barQuarters.multiplied(by: Rational(integerLiteral: Int64(lengthBars))),
               let implied = TempoCalculator.bpm(quarters: quarters, lasting: length) {
                ExactValueRow("Tempo", ExactText(implied, marks: marks), unit: "BPM")
                Button("Use This Tempo", systemImage: "arrow.up") { tempo = implied }
                    .buttonStyle(EchoelRowButtonStyle())
                    .disabled(implied == tempo)
            }
        }
    }

    private func typeLength() {
        guard let pad else { return }
        pad.open(NumberPadRequest(owner: "calculator.length", title: "Length",
                                  format: NumberEntryFormat(scale: 1, decimals: 4, unit: "s"),
                                  range: 0.001...3_600, value: length?.doubleValue ?? 2, standard: nil) { typed in
            length = Rational(roundTripping: typed)
        })
    }

    // MARK: Pitch

    private var pitchSection: some View {
        let concert = store.project.context.concertPitch
        return EchoelSection("Pitch", footer: "Twelve equal steps from A at the song's concert pitch. An A is exact; every other note's digits go on, which the … says. Wavelength in air at 343 m/s.") {
            if let a = Rational(roundTripping: concert) {
                ExactValueRow("A4", ExactText(a, marks: marks), unit: "Hz")
                if let wave = TempoCalculator.wavelength(ofHertz: a) {
                    ExactValueRow("A4 Wavelength", ExactText(wave, marks: marks), unit: "m")
                }
            }
            ExactValueRow("C4", ExactText(approximately: TempoCalculator.approximateHertz(ofMIDINote: 60, concertPitch: concert),
                                          marks: marks), unit: "Hz")
        }
    }
}
