import Foundation

/// A style of music as a producer means it: tempo, meter and groove, scales and tone systems,
/// harmony, a drum skeleton, what the bass does, the sections in bars, sound and mix. It is
/// REFERENCE that the musician reads and applies piece by piece (founder 2026-11-27: composing help
/// is a proposal the musician keeps or drops with one undo step). A style writes nothing by itself:
/// "Use Style" (`frame(_:for:)`) is a list of existing commands the musician sends, and the key's
/// root is never among them. It is a small type of its own, not the earlier app's `MusicStyle`,
/// where a genre set tempo, harmony, rhythm and sound at once.
///
/// The values come from the research table (`StyleLibrary`): conventions and starting points, each
/// style with how certain they are (`uncertainty`) and the sources they rest on. An exact number on
/// the screen is still a convention, not a measurement of the music. Decodable only: a song never
/// stores a style, only what its commands set.
public struct StyleGuide: Decodable, Equatable, Sendable, Identifiable {
    /// Electronic music, band and acoustic music, or a tradition with its own theory of pitch and time.
    public enum Family: String, Decodable, Sendable, CaseIterable {
        case electronic, band, tradition
    }

    /// A stable snake_case name: the assistant and the screen refer to a style by it.
    public let id: String
    public let family: Family
    public let name: String
    /// Where and when the style comes from, in words.
    public let regionAndEra: String
    public let tempo: TempoWindow
    /// The pulse a player counts where it is not the quarter note; nil where it is.
    public let feltBeat: FeltBeat?
    /// How the time feels, in words: half time, four to the floor, a 12-count cycle.
    public let felt: String
    public let meter: Meter
    public let swing: SwingWindow
    /// Stored names of `Scale`, the most usual first. A name this build does not have yet is one of
    /// `StyleLibrary.pendingScales`.
    public let scales: [String]
    /// `TuningSystem` ids, the most usual first; or one of `StyleLibrary.pendingToneSystems`.
    public let toneSystems: [String]
    /// Typical progressions as Roman numerals relative to the key (upper case major, lower case
    /// minor, ° diminished, ø half-diminished), or modal practice in words.
    public let progressions: [String]
    public let harmonicRhythm: String
    /// Nil where the music has no drum kit, or no skeleton could be checked.
    public let drums: DrumSkeleton?
    /// Rhythms that are not drum lanes: the claps of a tāla cycle, a bass figure, a snare roll.
    public let rhythmFigures: [RhythmFigure]
    public let bass: String
    public let sections: [Section]
    public let soundDesign: [String]
    public let mix: [String]
    public let uncertainty: Uncertainty
    /// Where the research read it. Links kept as data, to follow; never shown as a claim.
    public let sources: [URL]

    /// A tempo window in Studio BPM: quarter notes a minute, whatever the meter counts
    /// (`TempoCalculator`), with the tempo the style is most often played at.
    public struct TempoWindow: Decodable, Equatable, Sendable {
        public let range: ClosedRange<Double>
        public let typical: Double

        private enum CodingKeys: String, CodingKey { case min, max, typical }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            range = try container.window(from: .min, to: .max)
            typical = try container.decode(Double.self, forKey: .typical)
        }
    }

    /// The pulse a player counts where it is not the quarter note (the dotted quarter of 12/8, a
    /// count of a flamenco compás, an eighth of an aksak meter), and how many of it in a minute.
    public struct FeltBeat: Decodable, Equatable, Sendable {
        /// The note value counted: "1/8", "1/4", "1/2"; with a dot, "1/4." is the dotted quarter.
        public let note: String
        public let range: ClosedRange<Double>
        public let typical: Double

        private enum CodingKeys: String, CodingKey { case note, min, max, typical }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            note = try container.decode(String.self, forKey: .note)
            range = try container.window(from: .min, to: .max)
            typical = try container.decode(Double.self, forKey: .typical)
        }

        /// The counted note's length in quarter notes: 0.5 for "1/8", 1.5 for "1/4.". Nil for a
        /// note value this does not read.
        public var quarters: Double? {
            let dotted = note.hasSuffix(".")
            let fraction = (dotted ? note.dropLast() : Substring(note)).split(separator: "/", omittingEmptySubsequences: false)
            guard fraction.count == 2, let top = Int(fraction[0]), let bottom = Int(fraction[1]),
                  (1...64).contains(top), (1...64).contains(bottom) else { return nil }
            return 4 * Double(top) / Double(bottom) * (dotted ? 1.5 : 1)
        }
    }

    /// The time signature Studio counts the style in, and how its beats group, in units of the
    /// signature's denominator: 7/8 as 2 + 2 + 3. Studio stores the signature; the groups are for
    /// reading (the click does not accent them yet).
    public struct Meter: Decodable, Equatable, Sendable {
        public let signature: TimeSignature
        public let groups: [Int]

        private enum CodingKeys: String, CodingKey { case signature, groups }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let text = try container.decode(String.self, forKey: .signature)
            let parts = text.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2, let numerator = Int(parts[0]), let denominator = Int(parts[1]) else {
                throw DecodingError.dataCorruptedError(forKey: .signature, in: container,
                                                       debugDescription: "\"\(text)\" is no time signature such as 7/8")
            }
            signature = TimeSignature(numerator, denominator)
            groups = try container.decode([Int].self, forKey: .groups)
        }
    }

    /// Where the swung note of a pair falls, in percent of the pair: 50 is straight, 66.67 the
    /// 2 : 1 triplet, 75 the dotted feel. The research's convention; the song's swing that plays a
    /// percent is `songSwing(atPercent:)`.
    public struct SwingWindow: Decodable, Equatable, Sendable {
        /// Which pairs swing: none; the 16ths of each 8th, which Studio's swing moves; or the 8ths of
        /// each quarter (jazz, a blues shuffle), which it does not. Those styles write their swing
        /// into the notes, on a triplet grid (`DrumSkeleton.Step.eighthTriplet`), and play with the
        /// song's swing straight: Studio's swing moves every second 16th, and with it the triplet
        /// steps inside each 8th (at 0.5 the step on tick 320 would sound at 346 2/3).
        public enum Grid: String, Decodable, Sendable, CaseIterable {
            case straight = "none"
            case sixteenths = "1/16"
            case eighths = "1/8"
        }

        public let grid: Grid
        public let percent: ClosedRange<Double>
        /// The research's word on how Studio writes this swing, where it needs one.
        public let note: String?
        /// The amounts the table states for the window's two ends: Studio's exact amount
        /// (`studioAmount(percent:)`), none past the triplet and none on the 8th grid, where the
        /// formula does not apply. Checked against it (`StyleLibrary`), never read in its place.
        let statedAmounts: [Double?]?
        /// Whether the table says the window reaches past the triplet Studio's swing plays. Checked
        /// the same way.
        let statedBeyondStudio: Bool?

        private enum CodingKeys: String, CodingKey {
            case grid, percent, note, statedAmounts = "studio_amount", statedBeyondStudio = "beyond_studio"
        }

        /// The song's swing (`MusicalContext.swing`) that plays the style at `percent`, which "Use
        /// Style" sets: on the 16th grid Studio's exact amount (`studioAmount(percent:)`), nil past
        /// the 2 : 1 triplet, which Studio's swing does not play; straight on a straight grid, and on
        /// the 8th grid, whose swing is in the notes. Nil for a percent that is not a number, earlier
        /// than straight, or a whole pair late.
        public func songSwing(atPercent percent: Double) -> Double? {
            guard grid == .sixteenths else { return (50..<100).contains(percent) ? 0 : nil }
            return Self.studioAmount(percent: percent)
        }

        /// Studio's swing for a pair of 16ths whose second falls at `percent` of the pair: exactly
        /// 3 · (percent − 50) / 50, because Studio's swing moves the second 16th later by up to a
        /// third of a 16th (`Swing.position(of:)`). 54 % is 0.24, 58 % 0.48, the triplet 1. Nil for
        /// a percent that is not a number, earlier than straight, or later than the triplet.
        public static func studioAmount(percent: Double) -> Double? {
            guard percent.isFinite, percent >= 50 else { return nil }
            let amount = 3 * (percent - 50) / 50
            if amount <= MusicalContext.swingRange.upperBound { return amount }
            // The triplet itself, 200/3 %, is no Double: the nearest lies a hair above it, and so
            // does its amount, which is still the triplet.
            return amount - MusicalContext.swingRange.upperBound <= tripletTolerance ? MusicalContext.swingRange.upperBound : nil
        }

        /// How far above 1 an amount may come out and still be the triplet. Far below any swing
        /// anyone hears, far above the rounding of 200/3.
        static let tripletTolerance = 1e-9
    }

    /// A drum part's skeleton: one step string per lane, in the step grammar the assistant writes
    /// drums with (`AgentTools.pattern`: x a hit, X an accent, . a rest; | marks beats and is
    /// ignored).
    public struct DrumSkeleton: Decodable, Equatable, Sendable {
        /// The note value of one step.
        public enum Step: String, Decodable, Sendable, CaseIterable {
            case sixteenth = "1/16"
            case eighthTriplet = "1/8 triplet"
            case eighth = "1/8"
            case quarter = "1/4"

            /// One step in ticks; 960 to the quarter make every one of them whole.
            public var ticks: Tick {
                switch self {
                case .sixteenth: MusicalTime.ticksPerQuarter / 4
                case .eighthTriplet: MusicalTime.ticksPerQuarter / 3
                case .eighth: MusicalTime.ticksPerQuarter / 2
                case .quarter: MusicalTime.ticksPerQuarter
                }
            }
        }

        public struct Lane: Decodable, Equatable, Sendable {
            /// What the lane plays: "kick", "closed hat", "palmas", "kenong".
            public let name: String
            /// Its General MIDI drum note; nil for pitched percussion that has none (gamelan gongs).
            public let note: Int?
            public let steps: String

            private enum CodingKeys: String, CodingKey { case name = "lane", note = "gm", steps }
        }

        public let step: Step
        public let stepsPerBar: Int
        public let bars: Int
        /// True only where a cited source states the core positions; otherwise a starting point.
        public let verifiedBySource: Bool
        public let lanes: [Lane]

        private enum CodingKeys: String, CodingKey {
            case step, stepsPerBar = "steps_per_bar", bars, verifiedBySource = "verified_by_source", lanes
        }
    }

    /// A rhythm that is not a drum lane, such as the claps of a tāla cycle or a bass figure.
    public struct RhythmFigure: Decodable, Equatable, Sendable {
        public let part: String
        /// In the step grammar of the drum lanes; nil where the figure is told in words only.
        public let steps: String?
        public let note: String
    }

    /// A section of the usual form and its length in bars; nil for one of free length (an
    /// unmetered introduction, a cycle repeated as long as the music needs).
    public struct Section: Decodable, Equatable, Sendable {
        public let name: String
        public let bars: Int?

        /// The name a marker for the section carries: the table's, with a capital first letter.
        public var markerName: String { name.prefix(1).uppercased() + String(name.dropFirst()) }
    }

    /// How sure the research is of a style's numbers, and why.
    public struct Uncertainty: Decodable, Equatable, Sendable {
        public enum Level: String, Decodable, Sendable, CaseIterable {
            /// Several sources agree on the numbers.
            case low
            /// The sources agree on the shape; the numbers are convention or vary.
            case medium
            /// Numbers no source confirmed, or no notated source at all.
            case high
        }

        public let level: Level
        /// The research's reasons, naming its sources: research metadata, never text for the screen.
        public let notes: String
    }

    private enum CodingKeys: String, CodingKey {
        case id, family, name, regionAndEra = "region_era", tempo = "tempo_bpm", feltBeat = "felt_beat", felt
        case meter, swing, scales, toneSystems = "tunings", progressions, harmonicRhythm = "harmonic_rhythm"
        case drums, rhythmFigures = "rhythm_figures", bass, sections, soundDesign = "sound_design", mix
        case uncertainty, sources
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        family = try container.decode(Family.self, forKey: .family)
        name = try container.decode(String.self, forKey: .name)
        regionAndEra = try container.decode(String.self, forKey: .regionAndEra)
        tempo = try container.decode(TempoWindow.self, forKey: .tempo)
        feltBeat = try container.decodeIfPresent(FeltBeat.self, forKey: .feltBeat)
        felt = try container.decode(String.self, forKey: .felt)
        meter = try container.decode(Meter.self, forKey: .meter)
        swing = try container.decode(SwingWindow.self, forKey: .swing)
        scales = try container.decode([String].self, forKey: .scales)
        toneSystems = try container.decode([String].self, forKey: .toneSystems)
        progressions = try container.decode([String].self, forKey: .progressions)
        harmonicRhythm = try container.decode(String.self, forKey: .harmonicRhythm)
        drums = try container.decodeIfPresent(DrumSkeleton.self, forKey: .drums)
        rhythmFigures = try container.decodeIfPresent([RhythmFigure].self, forKey: .rhythmFigures) ?? []
        bass = try container.decode(String.self, forKey: .bass)
        sections = try container.decode([Section].self, forKey: .sections)
        soundDesign = try container.decode([String].self, forKey: .soundDesign)
        mix = try container.decode([String].self, forKey: .mix)
        uncertainty = try container.decode(Uncertainty.self, forKey: .uncertainty)
        sources = try container.decode([URL].self, forKey: .sources)
    }
}

/// A vibe bends a style; it is no style of its own: a factor on the tempo, a mode, register,
/// dynamics, articulation, timbre, harmony, space and density. The cues follow research on
/// emotion in performed music where there is some (`sources`); where there is none, `evidence` says
/// it is convention.
public struct StyleVibe: Decodable, Equatable, Sendable, Identifiable {
    public enum Evidence: String, Decodable, Sendable, CaseIterable {
        case research, mixed, convention
    }

    public let id: String
    public let name: String
    public let summary: String
    /// The factor on a style's tempo.
    public let tempoFactor: ClosedRange<Double>
    /// Stored names of `Scale`, as `StyleGuide.scales`.
    public let modes: [String]
    public let register: String
    public let dynamics: String
    /// A note's length as a share of the time to the next onset: 1 legato, 0.25 short.
    public let articulation: ClosedRange<Double>
    public let timbre: String
    /// The Instrument page's mood that fits (`InstrumentMood.all`), where one does.
    public let instrumentMood: String?
    public let harmony: String
    public let space: String
    public let density: String
    public let evidence: Evidence
    public let uncertainty: StyleGuide.Uncertainty
    /// Where the research read it; links kept as data, never shown as a claim.
    public let sources: [URL]

    private enum CodingKeys: String, CodingKey {
        case id, name, summary = "description", tempoFactor = "tempo_factor", modes, register, dynamics
        case articulation, timbre, instrumentMood = "instrument_mood", harmony, space, density, evidence
        case uncertainty, sources
    }
}

// MARK: - Use Style

/// A part of a style's frame, applied with the others or on its own. The key's root is no part: it
/// stays the musician's.
public enum StylePart: CaseIterable, Sendable {
    case tempo, meter, scale, toneSystem, swing, sections

    /// What "Use Style" applies unless the musician picks otherwise: the frame without the section
    /// markers, which go on the ruler only when asked for.
    public static let frame: Set<StylePart> = [.tempo, .meter, .scale, .toneSystem, .swing]
}

/// What the musician picked of a style for "Use Style": the parts, and a value where the style
/// offers a window or a list. Nil takes the style's own: its typical tempo, its first scale, its
/// first tone system, the low end of its swing window.
public struct StyleChoice: Equatable, Sendable {
    public var parts: Set<StylePart>
    /// Studio BPM inside the style's tempo window.
    public var tempo: Double?
    /// One of the style's scales, by its stored name.
    public var scale: String?
    /// One of the style's tone systems, by id.
    public var toneSystem: String?
    /// Swing in percent of the pair, inside the style's swing window. On the 8th grid it is the
    /// feel the notes carry, and the song's swing goes straight (`SwingWindow.songSwing(atPercent:)`).
    public var swingPercent: Double?
    /// The bar, counted from 1, the first section's marker stands on.
    public var firstSectionBar: Int

    public init(parts: Set<StylePart> = StylePart.frame, tempo: Double? = nil, scale: String? = nil,
                toneSystem: String? = nil, swingPercent: Double? = nil, firstSectionBar: Int = 1) {
        self.parts = parts
        self.tempo = tempo
        self.scale = scale
        self.toneSystem = toneSystem
        self.swingPercent = swingPercent
        self.firstSectionBar = firstSectionBar
    }
}

/// "Use Style" for one song: the commands to send, the parts they set and the parts the song keeps,
/// with why. Nothing here is performed; the musician's accept sends `commands` through
/// `ProjectStore.perform(_:title:)` as one undo step.
public struct StyleFrame: Equatable, Sendable {
    /// Why the song keeps a part as it is.
    public enum Reason: Equatable, Sendable {
        /// The style names a scale or tone system this build does not have yet.
        case notInThisBuild(String)
        /// The value picked is not one the style offers: a tempo or swing outside its window, a scale
        /// or tone system it does not list, a first bar before bar 1.
        case notInTheStyle
        /// Swing on the 16th grid later than the 2 : 1 triplet, which Studio's swing does not play
        /// (UK garage's 68–69 %). Never on the 8th grid: those styles carry their swing in the notes,
        /// and the frame sets the song's swing straight.
        case swingBeyondStudio
        /// The style's form is not counted in bars (an unmetered introduction, a cycle).
        case sectionsWithoutBars
        /// A marker stands already on every bar a section starts on.
        case markersStandThere
        /// The song refused the change, as the command says (a meter its later meter changes do not
        /// fit, sections past the end of the song).
        case refused(CommandError)
    }

    public let commands: [Command]
    /// The parts `commands` set, in the order they are sent.
    public let applied: [StylePart]
    public let kept: [StylePart: Reason]
    /// The bars, counted from 1, whose section marker is left out because the song has one there.
    public let occupiedBars: [Int]

    /// The step's name in the Undo menu.
    public var title: String { "Use Style" }
}

extension StyleGuide {
    /// The commands "Use Style" sends for `choice` on `project`. Each part is tried on its own, in
    /// the order of `StylePart`, on the song as the parts before it leave it, so the section markers
    /// count the meter the frame sets: a part the song refuses is kept and the others still apply.
    /// Section markers stand on bar lines of the song's meter map and leave out a bar that already
    /// holds a marker. Only existing commands, and never the key's root.
    public func frame(_ choice: StyleChoice = StyleChoice(), for project: Project) -> StyleFrame {
        var draft = FrameDraft(song: project)
        for part in StylePart.allCases where choice.parts.contains(part) {
            switch part {
            case .tempo: draft.attempt(part, tempoPlan(choice))
            case .meter: draft.attempt(part, .send([.setTimeSignature(meter.signature)]))
            case .scale: draft.attempt(part, scalePlan(choice))
            case .toneSystem: draft.attempt(part, toneSystemPlan(choice))
            case .swing: draft.attempt(part, swingPlan(choice))
            case .sections:
                let marking = sectionPlan(choice, on: draft.song)
                draft.attempt(part, marking.plan)
                if draft.applied.last == .sections || draft.kept[.sections] == .markersStandThere {
                    draft.occupiedBars = marking.occupied
                }
            }
        }
        return StyleFrame(commands: draft.commands, applied: draft.applied, kept: draft.kept,
                          occupiedBars: draft.occupiedBars)
    }

    private func tempoPlan(_ choice: StyleChoice) -> PartPlan {
        let bpm = choice.tempo ?? tempo.typical
        guard bpm.isFinite, tempo.range.contains(bpm) else { return .keep(.notInTheStyle) }
        return .send([.setTempo(bpm: bpm)])
    }

    private func scalePlan(_ choice: StyleChoice) -> PartPlan {
        guard let stored = choice.scale ?? scales.first, scales.contains(stored) else { return .keep(.notInTheStyle) }
        guard let scale = Scale(rawValue: stored) else { return .keep(.notInThisBuild(stored)) }
        return .send([.setScale(scale)])
    }

    private func toneSystemPlan(_ choice: StyleChoice) -> PartPlan {
        guard let system = choice.toneSystem ?? toneSystems.first, toneSystems.contains(system) else {
            return .keep(.notInTheStyle)
        }
        guard TuningSystem.library.contains(where: { $0.id == system }) else { return .keep(.notInThisBuild(system)) }
        return .send([.setTuning(id: system)])
    }

    /// The song's swing for the percent picked; straight on the 8th grid, whose styles write their
    /// swing into the notes (`SwingWindow.Grid`).
    private func swingPlan(_ choice: StyleChoice) -> PartPlan {
        let percent = choice.swingPercent ?? swing.percent.lowerBound
        guard percent.isFinite, swing.percent.contains(percent) else { return .keep(.notInTheStyle) }
        guard let amount = swing.songSwing(atPercent: percent) else { return .keep(.swingBeyondStudio) }
        return .send([.setSwing(amount)])
    }

    /// A marker at the start of every section, on `song`'s bars; the bars left out because a marker
    /// stands there already.
    private func sectionPlan(_ choice: StyleChoice, on song: Project) -> (plan: PartPlan, occupied: [Int]) {
        guard choice.firstSectionBar >= 1 else { return (.keep(.notInTheStyle), []) }
        guard !sections.isEmpty, sections.allSatisfy({ ($0.bars ?? 0) >= 1 }) else {
            return (.keep(.sectionsWithoutBars), [])
        }
        let meterMap = song.meterMap
        var commands: [Command] = []
        var occupied: [Int] = []
        var bar = Int64(choice.firstSectionBar)
        for section in sections {
            // `tick(ofBar:)` saturates past any tick a song holds; the song refuses a marker there,
            // and with it the whole part (`FrameDraft.attempt`).
            let tick = meterMap.tick(ofBar: bar - 1)
            if song.marker(at: tick) != nil {
                occupied.append(Int(clamping: bar))
            } else {
                commands.append(.addMarker(at: tick, name: section.markerName))
            }
            let (next, overflow) = bar.addingReportingOverflow(Int64(section.bars ?? 0))
            bar = overflow ? .max : next
        }
        return (commands.isEmpty ? .keep(.markersStandThere) : .send(commands), occupied)
    }
}

extension KeyedDecodingContainer {
    /// A window of two numbers under `low` and `high`, refused when it is upside down: a window the
    /// table writes the wrong way round is a fault to name, never a range to build (which would trap).
    fileprivate func window(from low: Key, to high: Key) throws -> ClosedRange<Double> {
        let bottom = try decode(Double.self, forKey: low)
        let top = try decode(Double.self, forKey: high)
        guard bottom <= top else {
            throw DecodingError.dataCorruptedError(forKey: high, in: self, debugDescription: "the window's top lies below its bottom")
        }
        return bottom...top
    }
}

/// What one part of a frame sends, or why the song keeps its own.
private enum PartPlan {
    case send([Command])
    case keep(StyleFrame.Reason)
}

/// The song as the parts tried so far leave it, and what they sent.
private struct FrameDraft {
    var song: Project
    var commands: [Command] = []
    var applied: [StylePart] = []
    var kept: [StylePart: StyleFrame.Reason] = [:]
    var occupiedBars: [Int] = []

    /// Applies `plan` to the draft song, or keeps the song as it is and says why: a command the song
    /// refuses keeps the whole part, never half of it.
    mutating func attempt(_ part: StylePart, _ plan: PartPlan) {
        switch plan {
        case .keep(let reason):
            kept[part] = reason
        case .send(let partCommands):
            var trial = song
            do {
                for command in partCommands { try command.apply(to: &trial) }
            } catch {
                kept[part] = .refused(error as? CommandError ?? .invalidValue(parameter: "style", reason: "\(error)"))
                return
            }
            song = trial
            commands += partCommands
            applied.append(part)
        }
    }
}
