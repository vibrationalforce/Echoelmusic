import Foundation

/// The reference table of styles and vibes (`StyleGuide`, `StyleVibe`), decoded once from
/// `StyleLibraryData` and checked entry by entry against what Studio's commands accept: tempo
/// windows inside `Tempo.range`, meters Studio counts, step strings in the assistant's grammar that
/// fill their bars, swing amounts that are Studio's, names of scales and tone systems this build
/// knows. An entry a check refuses is left out and named in `problems`, never guessed; the table
/// that ships has none (`StyleLibraryTests`).
///
/// A style may name a scale or tone system this build does not have yet, if the name is a known
/// pending one (`pendingScales`, `pendingToneSystems`): new scales arrive on their own (TH-4), and the
/// table need not wait for them. Such a style loads; "Use Style" leaves the song's scale or tone
/// system as it is until a build has the name (`StyleFrame.Reason.notInThisBuild`). Any other
/// unknown name is a fault of the table.
///
/// The table, its sources and its conventions come from the genre research of 2026-11-27, filed as
/// `research_notes/2026-11-27_genres-and-vibes.md` in the private repo echoelmusic-intern.
public struct StyleLibrary: Equatable, Sendable {
    public let guides: [StyleGuide]
    public let vibes: [StyleVibe]
    /// One line per fault, the entry's id first. Empty for the table that ships.
    public let problems: [String]

    /// The table that ships, decoded and checked on first use.
    public static let standard = StyleLibrary(json: StyleLibraryData.json)

    public func guide(_ id: String) -> StyleGuide? { guides.first { $0.id == id } }
    public func vibe(_ id: String) -> StyleVibe? { vibes.first { $0.id == id } }

    /// Scale names the table uses that a build may not have yet, with the semitones above the root
    /// the research gives each (§6 of `research_notes/2026-11-27_genres-and-vibes.md`,
    /// echoelmusic-intern: 22 from the earlier app's scales, ryukyu and anchihoye new). Once a build
    /// has a name, its scale must be these notes, so a name can never come back meaning another pitch
    /// set.
    public static let pendingScales: [String: [Int]] = [
        "phrygianDominant": [0, 1, 4, 5, 7, 8, 10],
        "doubleHarmonic": [0, 1, 4, 5, 7, 8, 11],
        "hungarianMinor": [0, 2, 3, 6, 7, 8, 11],
        "romanianMinor": [0, 2, 3, 6, 7, 9, 10],
        "lydianDominant": [0, 2, 4, 6, 7, 9, 10],
        "altered": [0, 1, 3, 4, 6, 8, 10],
        "bebopDominant": [0, 2, 4, 5, 7, 9, 10, 11],
        "bebopMajor": [0, 2, 4, 5, 7, 8, 9, 11],
        "bluesMajor": [0, 2, 3, 4, 7, 9],
        "diminishedHalfWhole": [0, 1, 3, 4, 6, 7, 9, 10],
        "diminishedWholeHalf": [0, 2, 3, 5, 6, 8, 9, 11],
        "spanishEightTone": [0, 1, 3, 4, 5, 6, 8, 10],
        "hirajoshi": [0, 2, 3, 7, 8],
        "insen": [0, 1, 5, 7, 10],
        "yo": [0, 2, 5, 7, 9],
        "inSakura": [0, 1, 5, 7, 8],
        "kumoi": [0, 2, 3, 7, 9],
        "egyptian": [0, 2, 5, 7, 10],
        "malkauns": [0, 3, 5, 8, 10],
        "marwa": [0, 1, 4, 6, 7, 9, 11],
        "purvi": [0, 1, 4, 6, 7, 8, 11],
        "todi": [0, 1, 3, 6, 7, 8, 11],
        "ryukyu": [0, 4, 5, 7, 11],
        "anchihoye": [0, 1, 5, 6, 9],
    ]

    /// Tone systems the table uses that a build may not have yet: `just-12`, a twelve-note 5-limit
    /// just chromatic, the textbook approximation the rāga rows name (§6 of
    /// `research_notes/2026-11-27_genres-and-vibes.md`, echoelmusic-intern). It approximates; it is
    /// not the 22-śruti system.
    public static let pendingToneSystems: Set<String> = ["just-12"]

    init(json: String) {
        let entries: [Entry]
        do {
            entries = try JSONDecoder().decode([Entry].self, from: Data(json.utf8))
        } catch {
            guides = []
            vibes = []
            problems = ["the table is no list of styles: \(Self.describe(error))"]
            return
        }
        var keptGuides: [StyleGuide] = []
        var keptVibes: [StyleVibe] = []
        var found: [String] = []
        var seen = Set<String>()
        for entry in entries {
            switch entry {
            case let .unreadable(id, reason):
                found.append("\(id): \(reason)")
            case let .guide(candidate):
                let wrong = Self.idFaults(candidate.id, seen: seen) + Self.faults(of: candidate)
                seen.insert(candidate.id)
                if wrong.isEmpty { keptGuides.append(candidate) } else { found += wrong }
            case let .vibe(candidate):
                let wrong = Self.idFaults(candidate.id, seen: seen) + Self.faults(of: candidate)
                seen.insert(candidate.id)
                if wrong.isEmpty { keptVibes.append(candidate) } else { found += wrong }
            }
        }
        guides = keptGuides
        vibes = keptVibes
        problems = found
    }

    /// One object of the table: a style, a vibe, or what reads as neither, with why.
    private enum Entry: Decodable {
        case guide(StyleGuide)
        case vibe(StyleVibe)
        case unreadable(id: String, reason: String)

        private enum CodingKeys: String, CodingKey { case id, kind }

        init(from decoder: any Decoder) throws {
            let container = try? decoder.container(keyedBy: CodingKeys.self)
            let id = (try? container?.decode(String.self, forKey: .id)) ?? "an entry without an id"
            do {
                switch try container?.decode(String.self, forKey: .kind) {
                case "genre"?: self = .guide(try StyleGuide(from: decoder))
                case "vibe"?: self = .vibe(try StyleVibe(from: decoder))
                case let kind: self = .unreadable(id: id, reason: "the kind \(kind ?? "(none)") is neither genre nor vibe")
                }
            } catch {
                self = .unreadable(id: id, reason: StyleLibrary.describe(error))
            }
        }
    }

    // MARK: - Checks

    /// Lower-case ASCII letters and digits, in words joined by single underscores, starting with a
    /// letter: `deep_house`.
    private static func isSnakeCase(_ id: String) -> Bool {
        let letters = Set("abcdefghijklmnopqrstuvwxyz")
        let digits = Set("0123456789")
        guard let first = id.first, letters.contains(first) else { return false }
        return id.split(separator: "_", omittingEmptySubsequences: false).allSatisfy { word in
            !word.isEmpty && word.allSatisfy { letters.contains($0) || digits.contains($0) }
        }
    }

    private static func idFaults(_ id: String, seen: Set<String>) -> [String] {
        var wrong: [String] = []
        if !isSnakeCase(id) { wrong.append("\(id): the id is not one snake_case name") }
        if seen.contains(id) { wrong.append("\(id): a second entry with this id") }
        return wrong
    }

    /// Nil when `name` is a scale of this build with the notes the table means, or a pending one.
    private static func scaleFault(_ name: String) -> String? {
        if let scale = Scale(rawValue: name) {
            guard let expected = pendingScales[name], Set(expected) != scale.intervals else { return nil }
            return "the scale \(name) of this build is not the pitch set \(expected) the table means"
        }
        return pendingScales[name] == nil ? "\(name) names no scale" : nil
    }

    private static func toneSystemFault(_ id: String) -> String? {
        TuningSystem.library.contains(where: { $0.id == id }) || pendingToneSystems.contains(id)
            ? nil : "\(id) names no tone system"
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Every link an https address with a host.
    private static func sourceFaults(_ sources: [URL]) -> [String] {
        guard !sources.isEmpty else { return ["no source"] }
        return sources.compactMap { url in
            url.scheme == "https" && !(url.host ?? "").isEmpty ? nil : "\(url.absoluteString) is no https link"
        }
    }

    /// What is wrong with `guide`, one line each; empty when nothing is.
    private static func faults(of guide: StyleGuide) -> [String] {
        var found: [String] = []
        let texts = [guide.name, guide.regionAndEra, guide.felt, guide.harmonicRhythm, guide.bass, guide.uncertainty.notes]
            + guide.progressions + guide.soundDesign + guide.mix
        if texts.contains(where: isBlank) { found.append("a text is empty") }
        if guide.progressions.isEmpty || guide.soundDesign.isEmpty || guide.mix.isEmpty {
            found.append("progressions, sound design and mix each need a line")
        }

        let tempo = guide.tempo
        if !Tempo.range.contains(tempo.range.lowerBound) || !Tempo.range.contains(tempo.range.upperBound) {
            found.append("the tempo window \(tempo.range) leaves Studio's \(Tempo.range)")
        }
        if !tempo.range.contains(tempo.typical) { found.append("the typical tempo \(tempo.typical) lies outside \(tempo.range)") }
        if let felt = guide.feltBeat {
            if let quarters = felt.quarters {
                // The pulse counted at its typical rate is the style's typical tempo, in quarters.
                if felt.typical * quarters != tempo.typical { found.append("the felt beat does not count the typical tempo") }
            } else {
                found.append("the felt beat \(felt.note) is no note value")
            }
            if !felt.range.contains(felt.typical) { found.append("the typical felt beat lies outside its window") }
        }

        let meter = guide.meter
        let signature = "\(meter.signature.numerator)/\(meter.signature.denominator)"
        if !meter.signature.isValid { found.append("the meter \(signature) is no time signature Studio counts") }
        if meter.groups.isEmpty || !meter.groups.allSatisfy({ (1...32).contains($0) })
            || meter.groups.reduce(0, +) != meter.signature.numerator {
            found.append("the beat groups \(meter.groups) do not fill a bar of \(signature)")
        }

        found += swingFaults(guide.swing)

        if guide.scales.isEmpty { found.append("no scale") }
        found += guide.scales.compactMap(scaleFault)
        if guide.toneSystems.isEmpty { found.append("no tone system") }
        found += guide.toneSystems.compactMap(toneSystemFault)

        if let drums = guide.drums { found += drumFaults(drums, meter: meter.signature) }
        for figure in guide.rhythmFigures {
            if isBlank(figure.part) || isBlank(figure.note) { found.append("a rhythm figure without a name or a note") }
            if let steps = figure.steps, (try? AgentTools.pattern(steps)) == nil {
                found.append("the figure \(figure.part) is no step string")
            }
        }

        if guide.sections.isEmpty { found.append("no section") }
        for section in guide.sections {
            if (try? Names.validated(section.markerName, parameter: "name")) == nil {
                found.append("the section \"\(section.name)\" is no marker name")
            }
            if let bars = section.bars, bars < 1 { found.append("the section \(section.name) has \(bars) bars") }
        }

        found += sourceFaults(guide.sources)
        return found.map { "\(guide.id): \($0)" }
    }

    /// A straight grid stays at 50 %, the window lies between straight and a pair's whole length,
    /// and the amounts the table states for its ends are Studio's exact ones: none past the triplet,
    /// which Studio's swing does not play, and none on the 8th grid, whose swing is in the notes.
    private static func swingFaults(_ swing: StyleGuide.SwingWindow) -> [String] {
        var found: [String] = []
        if swing.percent.lowerBound < 50 || swing.percent.upperBound >= 100 {
            found.append("the swing window \(swing.percent) leaves 50 … 100 %")
        }
        if swing.grid == .straight, swing.percent != 50...50 { found.append("a straight grid swings \(swing.percent)") }
        let ends = [swing.percent.lowerBound, swing.percent.upperBound]
        let amounts = ends.map { (percent: Double) -> Double? in
            swing.grid == .eighths ? nil : StyleGuide.SwingWindow.studioAmount(percent: percent)
        }
        let stated = swing.statedAmounts ?? [nil, nil]
        if stated != amounts {
            let written = stated.map { (amount: Double?) -> String in amount.map { "\($0)" } ?? "none" }
            found.append("the stated Studio swing \(written.joined(separator: ", ")) is not 3 · (percent − 50) / 50")
        }
        let beyond = swing.grid == .sixteenths && amounts.contains(where: { $0 == nil })
        if (swing.statedBeyondStudio ?? false) != beyond { found.append("beyond_studio says otherwise than the window") }
        return found
    }

    /// Steps that fill a bar of `meter` exactly, at most `AgentTools.maximumSteps` to a lane, every
    /// lane a step string of that length on a MIDI note.
    private static func drumFaults(_ drums: StyleGuide.DrumSkeleton, meter: TimeSignature) -> [String] {
        var found: [String] = []
        let steps = 1...AgentTools.maximumSteps
        guard steps.contains(drums.stepsPerBar), steps.contains(drums.bars),
              steps.contains(drums.stepsPerBar * drums.bars) else {
            return ["\(drums.bars) bars of \(drums.stepsPerBar) steps are more than a lane holds"]
        }
        if meter.isValid {
            let bar = MusicalTime.ticksPerBar(meter)
            if Tick(drums.stepsPerBar) * drums.step.ticks != bar {
                found.append("\(drums.stepsPerBar) steps of \(drums.step.rawValue) do not fill a bar")
            }
        }
        if drums.lanes.isEmpty { found.append("a drum skeleton without lanes") }
        for lane in drums.lanes {
            if isBlank(lane.name) { found.append("a lane without a name") }
            if let note = lane.note, !Note.pitchRange.contains(note) { found.append("the lane \(lane.name) plays note \(note)") }
            if let hits = try? AgentTools.pattern(lane.steps) {
                if hits.count != drums.stepsPerBar * drums.bars {
                    found.append("the lane \(lane.name) has \(hits.count) steps, not \(drums.stepsPerBar * drums.bars)")
                }
            } else {
                found.append("the lane \(lane.name) is no step string")
            }
        }
        return found
    }

    /// What is wrong with `vibe`, one line each; empty when nothing is.
    private static func faults(of vibe: StyleVibe) -> [String] {
        var found: [String] = []
        let texts = [vibe.name, vibe.summary, vibe.register, vibe.dynamics, vibe.timbre, vibe.harmony, vibe.space,
                     vibe.density, vibe.uncertainty.notes]
        if texts.contains(where: isBlank) { found.append("a text is empty") }
        if vibe.tempoFactor.lowerBound <= 0 { found.append("the tempo factor \(vibe.tempoFactor) stops the music") }
        if vibe.modes.isEmpty { found.append("no mode") }
        found += vibe.modes.compactMap(scaleFault)
        if vibe.articulation.lowerBound <= 0 || vibe.articulation.upperBound > 1 {
            found.append("the articulation \(vibe.articulation) leaves the note")
        }
        if let mood = vibe.instrumentMood, !InstrumentMood.all.contains(where: { $0.name == mood }) {
            found.append("\(mood) is no mood of the Instrument page")
        }
        found += sourceFaults(vibe.sources)
        return found.map { "\(vibe.id): \($0)" }
    }

    /// A decoding error as one line: where in the entry, and what.
    private static func describe(_ error: any Error) -> String {
        guard let decoding = error as? DecodingError else { return "\(error)" }
        func place(_ path: [any CodingKey]) -> String {
            path.isEmpty ? "the entry" : path.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
        }
        switch decoding {
        case let .keyNotFound(key, context):
            return "\(place(context.codingPath + [key])) is missing"
        case let .valueNotFound(_, context):
            return "\(place(context.codingPath)) is empty"
        case let .typeMismatch(_, context), let .dataCorrupted(context):
            return "\(place(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return "\(decoding)"
        }
    }
}
