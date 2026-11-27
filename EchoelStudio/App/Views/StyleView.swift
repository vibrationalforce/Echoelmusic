import EchoelCore
import SwiftUI

/// "Styles…" from the Song menu (S8): genres as reference data. A style names what its music is
/// usually made of — a tempo window, a meter, scales, a tone system, a swing, a form — and "Use
/// Style" sets the parts the musician ticks, as one undo step (`StyleGuide.frame`). It never writes
/// a note, never touches the key's root, and nothing is applied until the button is pressed. The
/// notes on sound and mix under it are reference text, not rules.
struct StyleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StyleListPage()
                .navigationTitle("Styles")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

/// Every style of the library, by family. Reads no song: the list is the same for every song.
private struct StyleListPage: View {
    private let library = StyleLibrary.standard

    var body: some View {
        List {
            ForEach(StyleGuide.Family.allCases, id: \.self) { family in
                EchoelSection(Self.title(of: family)) {
                    ForEach(library.guides.filter { $0.family == family }) { guide in
                        NavigationLink(value: guide.id) {
                            row(guide)
                        }
                    }
                }
            }
        }
        .echoelList()
        .navigationDestination(for: String.self) { id in
            if let guide = library.guide(id) {
                StylePage(guide: guide)
            }
        }
    }

    private func row(_ guide: StyleGuide) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(guide.name)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
            Text(StylePage.tempoLine(guide))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(minHeight: Theme.Size.touch, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private static func title(of family: StyleGuide.Family) -> String {
        switch family {
        case .electronic: "Electronic"
        case .band: "Band"
        case .tradition: "Traditions"
        }
    }
}

/// One style: the parts of its frame, each with the value "Use Style" would set and a switch, and
/// under them how it is usually made. Reads the song only where it is cold — what an edit changes —
/// to say which parts the song would keep and why (Law 6).
private struct StylePage: View {
    let guide: StyleGuide

    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    @State private var parts: Set<StylePart> = StylePart.frame
    /// What the last press set, for the line under the button.
    @State private var lastSet: [StylePart] = []

    private static let marks = NumberMarks(locale: .current)

    var body: some View {
        let plan = guide.frame(StyleChoice(parts: parts), for: store.project)
        List {
            EchoelSection("Frame", footer: "Use Style sets the ticked parts in one step, and one Undo takes them back. The key's root stays yours. No note is written.") {
                ForEach(StylePart.allCases, id: \.self) { part in
                    partRow(part, in: plan)
                }
                Button("Use Style", systemImage: "checkmark") { use(plan) }
                    .buttonStyle(EchoelRowButtonStyle())
                    .disabled(plan.commands.isEmpty)
                    .accessibilityHint("Sets the ticked parts of this style in the song.")
                if !lastSet.isEmpty {
                    NoteText("Set: " + lastSet.map(Self.title).joined(separator: ", ") + ".")
                }
            }
            reference
        }
        .echoelList()
        .navigationTitle(guide.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Frame

    private func partRow(_ part: StylePart, in plan: StyleFrame) -> some View {
        Toggle(isOn: Binding(get: { parts.contains(part) }, set: { isOn in
            if isOn { parts.insert(part) } else { parts.remove(part) }
            lastSet = []
        })) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(Self.title(part))
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.text)
                Text(value(of: part))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                if parts.contains(part), let reason = plan.kept[part] {
                    Text("The song keeps its own: " + Self.sentence(reason))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.text)
                }
            }
        }
        .frame(minHeight: Theme.Size.touch)
    }

    private func use(_ plan: StyleFrame) {
        guard !plan.commands.isEmpty else { return }
        if documents.attempt(plan.commands, title: plan.title) {
            lastSet = plan.applied
            Theme.Accessibility.announce(Announcement("Style set", priority: .normal))
        }
    }

    /// What a part would set, in the style's own numbers.
    private func value(of part: StylePart) -> String {
        switch part {
        case .tempo: Self.tempoLine(guide)
        case .meter: "\(guide.meter.signature.numerator)/\(guide.meter.signature.denominator)"
        case .scale: guide.scales.first.map { (stored: String) -> String in Scale(rawValue: stored)?.title ?? stored } ?? "None named"
        case .toneSystem: guide.toneSystems.first.map { (id: String) -> String in
            TuningSystem.library.first { $0.id == id }?.name ?? id
        } ?? "None named"
        case .swing: swingLine
        case .sections: guide.sections.isEmpty ? "None named" : guide.sections.map(\.markerName).joined(separator: ", ")
        }
    }

    private var swingLine: String {
        let window = guide.swing.percent
        let low = Self.number(window.lowerBound), high = Self.number(window.upperBound)
        let span = low == high ? "\(low) %" : "\(low) to \(high) %"
        switch guide.swing.grid {
        case .straight: return "Straight"
        case .sixteenths: return "\(span) of each pair of 16ths; the low end is set"
        case .eighths: return "\(span) of each pair of 8ths, written into the notes; the song's swing goes straight"
        }
    }

    static func tempoLine(_ guide: StyleGuide) -> String {
        let window = guide.tempo.range
        return "\(number(guide.tempo.typical)) BPM, usually \(number(window.lowerBound)) to \(number(window.upperBound))"
    }

    /// A number as the library states it, never rounded.
    private static func number(_ value: Double) -> String {
        ExactText(printed: value, marks: marks).full
    }

    private static func title(_ part: StylePart) -> String {
        switch part {
        case .tempo: "Tempo"
        case .meter: "Time Signature"
        case .scale: "Scale"
        case .toneSystem: "Tone System"
        case .swing: "Swing"
        case .sections: "Section Markers"
        }
    }

    private static func sentence(_ reason: StyleFrame.Reason) -> String {
        switch reason {
        case .notInThisBuild(let name): "“\(name)” is not in this build yet."
        case .notInTheStyle: "that value is not one this style names."
        case .swingBeyondStudio: "this swing is later than the triplet, further than the song's swing goes."
        case .sectionsWithoutBars: "its form is not counted in bars."
        case .markersStandThere: "markers already stand on those bars."
        case .refused(let error): error.sentence
        }
    }

    // MARK: Reference

    /// How the style is usually made: reference text from the library, applied by nothing.
    @ViewBuilder private var reference: some View {
        EchoelSection("How It Is Usually Made", footer: "Reference notes from the style library, not rules. Nothing here changes the song.") {
            ParagraphText(guide.regionAndEra)
            if !guide.felt.isEmpty { ParagraphText(guide.felt) }
            if !guide.progressions.isEmpty {
                NoteText("Chords: " + guide.progressions.joined(separator: " · "))
            }
            if !guide.harmonicRhythm.isEmpty { NoteText("Chord changes: " + guide.harmonicRhythm) }
            if !guide.bass.isEmpty { NoteText("Bass: " + guide.bass) }
        }
        if !guide.soundDesign.isEmpty {
            EchoelSection("Sound") {
                ForEach(guide.soundDesign, id: \.self) { NoteText($0) }
            }
        }
        if !guide.mix.isEmpty {
            EchoelSection("Mix") {
                ForEach(guide.mix, id: \.self) { NoteText($0) }
            }
        }
    }
}
