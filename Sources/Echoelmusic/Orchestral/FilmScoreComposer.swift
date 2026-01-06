// FilmScoreComposer.swift
// Echoelmusic - 10000% Ralph Wiggum Loop Mode
//
// AI Film Score Composer - Walt Disney & Classic Hollywood Inspired
// Automatic cinematic composition based on scene mood and bio-reactivity
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

// MARK: - Film Score Constants

/// Constants for film score composition
public enum FilmScoreConstants {
    // Classic Disney tempos
    public static let whimsicalTempo: Float = 120.0
    public static let magicalTempo: Float = 92.0
    public static let adventureTempo: Float = 140.0
    public static let romanticTempo: Float = 72.0
    public static let triumphantTempo: Float = 108.0

    // Golden age Hollywood chord voicings
    public static let disneyMagicIntervals: [Int] = [0, 4, 7, 11, 14]  // Maj7 + 9
    public static let wonderIntervals: [Int] = [0, 4, 7, 9, 14]        // Maj6/9
    public static let epicIntervals: [Int] = [0, 7, 12, 16, 19]        // Power + octave
    public static let mysteryIntervals: [Int] = [0, 3, 6, 10, 15]      // Dim7 + b9
}

// MARK: - Scene Type

/// Types of film scenes for scoring
public enum FilmSceneType: String, CaseIterable, Identifiable, Sendable {
    // Disney Classic Scenes
    case magicalMoment = "Magical Moment"          // Fairy godmother, transformation
    case wishSequence = "Wish Upon a Star"         // Opening wishes, dreams
    case villainEntrance = "Villain Entrance"       // Dramatic villain reveal
    case romanticDuet = "Romantic Duet"            // Love ballad
    case comedyChase = "Comedy Chase"              // Slapstick action
    case triumphantFinale = "Triumphant Finale"    // Happy ending
    case emotionalGoodbye = "Emotional Goodbye"    // Tearful farewell
    case adventureBegins = "Adventure Begins"      // Journey starts
    case mysteriousDiscovery = "Mysterious Discovery"
    case battleScene = "Battle Scene"
    case quietReflection = "Quiet Reflection"
    case celebration = "Celebration"
    case nighttimeDream = "Nighttime Dream"
    case morningAwakening = "Morning Awakening"
    case underwaterWonder = "Underwater Wonder"    // Little Mermaid style
    case flyingSequence = "Flying Sequence"        // Peter Pan / Aladdin
    case transformationScene = "Transformation"    // Cinderella / Beauty & Beast

    public var id: String { rawValue }

    /// Suggested tempo for this scene type
    public var suggestedTempo: Float {
        switch self {
        case .magicalMoment: return 84
        case .wishSequence: return 72
        case .villainEntrance: return 66
        case .romanticDuet: return 76
        case .comedyChase: return 140
        case .triumphantFinale: return 108
        case .emotionalGoodbye: return 60
        case .adventureBegins: return 120
        case .mysteriousDiscovery: return 54
        case .battleScene: return 150
        case .quietReflection: return 58
        case .celebration: return 132
        case .nighttimeDream: return 66
        case .morningAwakening: return 88
        case .underwaterWonder: return 78
        case .flyingSequence: return 96
        case .transformationScene: return 72
        }
    }

    /// Primary sections to use
    public var primarySections: Set<OrchestraSection> {
        switch self {
        case .magicalMoment: return [.strings, .woodwinds, .celesta, .harp]
        case .wishSequence: return [.strings, .woodwinds, .choir]
        case .villainEntrance: return [.brass, .strings, .percussion]
        case .romanticDuet: return [.strings, .woodwinds, .harp]
        case .comedyChase: return [.woodwinds, .brass, .percussion, .strings]
        case .triumphantFinale: return [.brass, .strings, .choir, .percussion]
        case .emotionalGoodbye: return [.strings, .piano, .woodwinds]
        case .adventureBegins: return [.brass, .strings, .percussion]
        case .mysteriousDiscovery: return [.strings, .woodwinds, .celesta]
        case .battleScene: return [.brass, .percussion, .strings]
        case .quietReflection: return [.piano, .strings]
        case .celebration: return [.brass, .strings, .percussion, .woodwinds]
        case .nighttimeDream: return [.strings, .celesta, .harp]
        case .morningAwakening: return [.woodwinds, .strings, .harp]
        case .underwaterWonder: return [.harp, .woodwinds, .strings, .celesta]
        case .flyingSequence: return [.strings, .brass, .woodwinds]
        case .transformationScene: return [.strings, .choir, .celesta, .brass]
        }
    }
}

// MARK: - Compositional Technique

/// Classic film scoring techniques
public enum CompositionalTechnique: String, CaseIterable, Sendable {
    // Melody techniques
    case leitmotif = "Leitmotif"                    // Character/theme association
    case mickeyMousing = "Mickey Mousing"          // Direct action sync
    case underscore = "Underscore"                  // Subtle background
    case sourceMusic = "Source Music"              // Diegetic music

    // Harmonic techniques
    case chromaticMediant = "Chromatic Mediant"    // Dramatic key shifts
    case deceptiveCadence = "Deceptive Cadence"    // Surprise resolution
    case plagalCadence = "Plagal Cadence"          // "Amen" cadence
    case suspendedResolution = "Suspended Resolution"
    case modalInterchange = "Modal Interchange"

    // Textural techniques
    case orchestralSwell = "Orchestral Swell"
    case stringTremolo = "String Tremolo"
    case brassStabs = "Brass Stabs"
    case woodwindRuns = "Woodwind Runs"
    case choirPad = "Choir Pad"
    case ostinato = "Ostinato"
    case countermelody = "Countermelody"

    // Disney-specific
    case waltTime = "Waltz Time"                   // 3/4 dance
    case marchingBand = "Marching Band"            // Parade style
    case lullaby = "Lullaby"                       // Gentle 6/8
    case fanfare = "Fanfare"                       // Brass announcement
}

// MARK: - Leitmotif

/// A recurring musical theme associated with a character or concept
public struct Leitmotif: Identifiable, Sendable {
    public let id = UUID()
    public var name: String
    public var associatedWith: String  // Character, concept, or location
    public var melody: [Int]           // MIDI pitches
    public var rhythm: [Float]         // Note durations in beats
    public var keyCenter: Int          // Root MIDI note
    public var mode: MusicalMode
    public var primaryInstrument: String
    public var dynamics: ScoreEvent.DynamicMarking
    public var tempo: Float

    public enum MusicalMode: String, CaseIterable, Sendable {
        case major = "Major"
        case minor = "Minor"
        case dorian = "Dorian"
        case phrygian = "Phrygian"
        case lydian = "Lydian"
        case mixolydian = "Mixolydian"
        case aeolian = "Aeolian"
        case locrian = "Locrian"
    }

    public init(
        name: String,
        associatedWith: String,
        melody: [Int] = [],
        rhythm: [Float] = [],
        keyCenter: Int = 60,
        mode: MusicalMode = .major,
        primaryInstrument: String = "Violins I",
        dynamics: ScoreEvent.DynamicMarking = .mf,
        tempo: Float = 90
    ) {
        self.name = name
        self.associatedWith = associatedWith
        self.melody = melody
        self.rhythm = rhythm
        self.keyCenter = keyCenter
        self.mode = mode
        self.primaryInstrument = primaryInstrument
        self.dynamics = dynamics
        self.tempo = tempo
    }
}

// MARK: - Harmonic Progression

/// Pre-built harmonic progressions for different moods
public struct HarmonicProgression: Identifiable, Sendable {
    public let id = UUID()
    public var name: String
    public var chords: [ChordSymbol]
    public var style: ProgressionStyle

    public struct ChordSymbol: Sendable {
        public var root: Int           // 0-11 (C=0, C#=1, etc.)
        public var quality: ChordQuality
        public var bass: Int?          // Slash chord bass note
        public var duration: Float     // In beats

        public enum ChordQuality: String, CaseIterable, Sendable {
            case major = "Maj"
            case minor = "min"
            case diminished = "dim"
            case augmented = "aug"
            case major7 = "Maj7"
            case minor7 = "min7"
            case dominant7 = "7"
            case halfDiminished = "ø7"
            case diminished7 = "°7"
            case sus2 = "sus2"
            case sus4 = "sus4"
            case add9 = "add9"
            case major9 = "Maj9"
            case minor9 = "min9"
        }

        public init(root: Int, quality: ChordQuality, bass: Int? = nil, duration: Float = 4) {
            self.root = root
            self.quality = quality
            self.bass = bass
            self.duration = duration
        }
    }

    public enum ProgressionStyle: String, CaseIterable, Sendable {
        case disneyMagic = "Disney Magic"          // I - iii - IV - V
        case heroicJourney = "Heroic Journey"      // I - V - vi - IV
        case mysteriousTension = "Mysterious"       // i - bVI - bVII - i
        case romanticSweep = "Romantic Sweep"      // I - vi - IV - V
        case villainTheme = "Villain Theme"        // i - bII - V - i
        case triumphantReturn = "Triumphant"       // I - IV - V - I
        case emotionalPeak = "Emotional Peak"      // vi - IV - I - V
        case whimsicalWaltz = "Whimsical Waltz"   // I - V7 - I - IV
        case epicBattle = "Epic Battle"           // i - iv - V - i
    }

    public init(name: String, style: ProgressionStyle) {
        self.name = name
        self.style = style
        self.chords = HarmonicProgression.getChords(for: style)
    }

    private static func getChords(for style: ProgressionStyle) -> [ChordSymbol] {
        switch style {
        case .disneyMagic:
            return [
                ChordSymbol(root: 0, quality: .major7, duration: 4),      // CMaj7
                ChordSymbol(root: 4, quality: .minor7, duration: 4),      // Emin7
                ChordSymbol(root: 5, quality: .major7, duration: 4),      // FMaj7
                ChordSymbol(root: 7, quality: .dominant7, duration: 4)    // G7
            ]
        case .heroicJourney:
            return [
                ChordSymbol(root: 0, quality: .major, duration: 4),
                ChordSymbol(root: 7, quality: .major, duration: 4),
                ChordSymbol(root: 9, quality: .minor, duration: 4),
                ChordSymbol(root: 5, quality: .major, duration: 4)
            ]
        case .mysteriousTension:
            return [
                ChordSymbol(root: 0, quality: .minor, duration: 4),
                ChordSymbol(root: 8, quality: .major, duration: 4),       // bVI
                ChordSymbol(root: 10, quality: .major, duration: 4),      // bVII
                ChordSymbol(root: 0, quality: .minor, duration: 4)
            ]
        case .romanticSweep:
            return [
                ChordSymbol(root: 0, quality: .major9, duration: 4),
                ChordSymbol(root: 9, quality: .minor7, duration: 4),
                ChordSymbol(root: 5, quality: .major7, duration: 4),
                ChordSymbol(root: 7, quality: .dominant7, duration: 4)
            ]
        case .villainTheme:
            return [
                ChordSymbol(root: 0, quality: .minor, duration: 4),
                ChordSymbol(root: 1, quality: .major, duration: 4),       // bII (Neapolitan)
                ChordSymbol(root: 7, quality: .dominant7, duration: 4),
                ChordSymbol(root: 0, quality: .minor, duration: 4)
            ]
        case .triumphantReturn:
            return [
                ChordSymbol(root: 0, quality: .major, duration: 2),
                ChordSymbol(root: 5, quality: .major, duration: 2),
                ChordSymbol(root: 7, quality: .major, duration: 2),
                ChordSymbol(root: 0, quality: .major, duration: 2)
            ]
        case .emotionalPeak:
            return [
                ChordSymbol(root: 9, quality: .minor7, duration: 4),
                ChordSymbol(root: 5, quality: .major, duration: 4),
                ChordSymbol(root: 0, quality: .major, duration: 4),
                ChordSymbol(root: 7, quality: .major, duration: 4)
            ]
        case .whimsicalWaltz:
            return [
                ChordSymbol(root: 0, quality: .major, duration: 3),
                ChordSymbol(root: 7, quality: .dominant7, duration: 3),
                ChordSymbol(root: 0, quality: .major, duration: 3),
                ChordSymbol(root: 5, quality: .major, duration: 3)
            ]
        case .epicBattle:
            return [
                ChordSymbol(root: 0, quality: .minor, duration: 2),
                ChordSymbol(root: 5, quality: .minor, duration: 2),
                ChordSymbol(root: 7, quality: .major, duration: 2),
                ChordSymbol(root: 0, quality: .minor, duration: 2)
            ]
        }
    }
}

// MARK: - Film Score Composer

/// AI-powered film score composition engine
@MainActor
public final class FilmScoreComposer: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isComposing: Bool = false
    @Published public private(set) var currentScene: FilmSceneType = .magicalMoment
    @Published public private(set) var currentTechnique: CompositionalTechnique = .underscore
    @Published public private(set) var generatedEvents: [ScoreEvent] = []

    @Published public var leitmotifs: [Leitmotif] = []
    @Published public var activeProgression: HarmonicProgression?
    @Published public var bioReactivityEnabled: Bool = true
    @Published public var coherenceInfluence: Float = 0.5

    // MARK: - Bio Data

    public var coherence: Float = 0.5
    public var heartRate: Float = 70.0
    public var breathPhase: Float = 0.0

    // MARK: - Private Properties

    private var scoringEngine: CinematicScoringEngine?
    private var compositionTimer: Timer?
    private var measureCount: Int = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupDefaultLeitmotifs()
    }

    // MARK: - Setup

    private func setupDefaultLeitmotifs() {
        // Hero's Theme - Major, ascending, triumphant
        leitmotifs.append(Leitmotif(
            name: "Hero's Theme",
            associatedWith: "Protagonist",
            melody: [0, 4, 7, 12, 11, 7, 4],  // Intervals from root
            rhythm: [1, 0.5, 0.5, 2, 0.5, 0.5, 2],
            keyCenter: 60,
            mode: .major,
            primaryInstrument: "French Horns",
            dynamics: .f,
            tempo: 100
        ))

        // Love Theme - Romantic, flowing
        leitmotifs.append(Leitmotif(
            name: "Love Theme",
            associatedWith: "Romance",
            melody: [0, 2, 4, 7, 9, 7, 4, 2],
            rhythm: [1, 1, 1, 2, 1, 1, 1, 2],
            keyCenter: 65,  // F
            mode: .major,
            primaryInstrument: "Violins I",
            dynamics: .mp,
            tempo: 72
        ))

        // Mystery Theme - Chromatic, unsettling
        leitmotifs.append(Leitmotif(
            name: "Mystery Theme",
            associatedWith: "Unknown",
            melody: [0, 1, 3, 6, 5, 3, 1],
            rhythm: [2, 1, 1, 2, 1, 1, 2],
            keyCenter: 64,  // E
            mode: .phrygian,
            primaryInstrument: "Cellos",
            dynamics: .p,
            tempo: 60
        ))

        // Villain Theme - Minor, dramatic
        leitmotifs.append(Leitmotif(
            name: "Villain Theme",
            associatedWith: "Antagonist",
            melody: [0, 3, 7, 6, 3, 0, -1],
            rhythm: [1, 1, 2, 1, 1, 2, 2],
            keyCenter: 62,  // D
            mode: .minor,
            primaryInstrument: "Trombones",
            dynamics: .ff,
            tempo: 66
        ))

        // Magic Theme - Ethereal, sparkling
        leitmotifs.append(Leitmotif(
            name: "Magic Theme",
            associatedWith: "Wonder",
            melody: [0, 7, 12, 16, 19, 16, 12, 7],
            rhythm: [0.5, 0.5, 0.5, 0.5, 1, 0.5, 0.5, 1],
            keyCenter: 60,
            mode: .lydian,
            primaryInstrument: "Celesta",
            dynamics: .p,
            tempo: 84
        ))
    }

    // MARK: - Composition Control

    /// Start composing for a scene
    public func composeForScene(_ sceneType: FilmSceneType) {
        currentScene = sceneType
        isComposing = true

        // Select appropriate technique
        selectTechnique(for: sceneType)

        // Create harmonic progression
        activeProgression = createProgression(for: sceneType)

        // Start composition loop
        startCompositionLoop()

        print("🎬 FilmScoreComposer: Composing for '\(sceneType.rawValue)'")
    }

    /// Stop composing
    public func stopComposing() {
        isComposing = false
        stopCompositionLoop()
        print("🎬 FilmScoreComposer: Stopped")
    }

    // MARK: - Composition Logic

    private func selectTechnique(for scene: FilmSceneType) {
        switch scene {
        case .magicalMoment, .wishSequence:
            currentTechnique = .orchestralSwell
        case .villainEntrance:
            currentTechnique = .leitmotif
        case .comedyChase:
            currentTechnique = .mickeyMousing
        case .romanticDuet:
            currentTechnique = .underscore
        case .triumphantFinale:
            currentTechnique = .fanfare
        case .battleScene:
            currentTechnique = .ostinato
        case .quietReflection:
            currentTechnique = .underscore
        case .flyingSequence:
            currentTechnique = .orchestralSwell
        case .transformationScene:
            currentTechnique = .chromaticMediant
        default:
            currentTechnique = .underscore
        }
    }

    private func createProgression(for scene: FilmSceneType) -> HarmonicProgression {
        let style: HarmonicProgression.ProgressionStyle

        switch scene {
        case .magicalMoment, .wishSequence, .transformationScene:
            style = .disneyMagic
        case .villainEntrance:
            style = .villainTheme
        case .romanticDuet:
            style = .romanticSweep
        case .triumphantFinale, .celebration:
            style = .triumphantReturn
        case .adventureBegins, .flyingSequence:
            style = .heroicJourney
        case .mysteriousDiscovery:
            style = .mysteriousTension
        case .emotionalGoodbye, .quietReflection:
            style = .emotionalPeak
        case .comedyChase:
            style = .whimsicalWaltz
        case .battleScene:
            style = .epicBattle
        default:
            style = .disneyMagic
        }

        return HarmonicProgression(name: "\(scene.rawValue) Progression", style: style)
    }

    // MARK: - Composition Loop

    private func startCompositionLoop() {
        let tempo = currentScene.suggestedTempo
        let beatInterval = 60.0 / Double(tempo)

        compositionTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.composeBeat()
            }
        }
    }

    private func stopCompositionLoop() {
        compositionTimer?.invalidate()
        compositionTimer = nil
        measureCount = 0
    }

    private func composeBeat() {
        guard isComposing else { return }

        measureCount += 1
        let beatInMeasure = measureCount % 4

        // Apply bio-reactivity
        var dynamicModifier: Float = 1.0
        if bioReactivityEnabled {
            dynamicModifier = 0.7 + coherenceInfluence * coherence * 0.6
        }

        // Generate events based on technique
        switch currentTechnique {
        case .leitmotif:
            if beatInMeasure == 0 {
                generateLeitmotifPhrase()
            }

        case .orchestralSwell:
            generateOrchestralSwell(beat: beatInMeasure, modifier: dynamicModifier)

        case .ostinato:
            generateOstinato(beat: beatInMeasure)

        case .fanfare:
            if measureCount % 8 == 0 {
                generateFanfare()
            }

        case .mickeyMousing:
            generateMickeyMousing(beat: beatInMeasure)

        default:
            generateUnderscore(beat: beatInMeasure, modifier: dynamicModifier)
        }
    }

    // MARK: - Generation Methods

    private func generateLeitmotifPhrase() {
        guard let motif = selectLeitmotif() else { return }

        // Generate events from leitmotif
        var time: TimeInterval = 0
        for (index, interval) in motif.melody.enumerated() {
            let pitch = motif.keyCenter + interval
            let duration = Double(motif.rhythm[safe: index] ?? 1.0)

            let event = ScoreEvent(
                type: .note,
                time: time,
                duration: duration,
                dynamics: motif.dynamics
            )

            generatedEvents.append(event)
            time += duration
        }
    }

    private func selectLeitmotif() -> Leitmotif? {
        // Select based on scene type
        switch currentScene {
        case .villainEntrance:
            return leitmotifs.first { $0.associatedWith == "Antagonist" }
        case .romanticDuet:
            return leitmotifs.first { $0.associatedWith == "Romance" }
        case .magicalMoment, .wishSequence:
            return leitmotifs.first { $0.associatedWith == "Wonder" }
        case .adventureBegins, .triumphantFinale:
            return leitmotifs.first { $0.associatedWith == "Protagonist" }
        case .mysteriousDiscovery:
            return leitmotifs.first { $0.associatedWith == "Unknown" }
        default:
            return leitmotifs.randomElement()
        }
    }

    private func generateOrchestralSwell(beat: Int, modifier: Float) {
        // Build intensity over 4 beats
        let intensity = Float(beat + 1) / 4.0 * modifier

        let dynamics: ScoreEvent.DynamicMarking
        if intensity < 0.3 {
            dynamics = .p
        } else if intensity < 0.6 {
            dynamics = .mf
        } else if intensity < 0.85 {
            dynamics = .f
        } else {
            dynamics = .ff
        }

        let event = ScoreEvent(
            type: .chord,
            time: TimeInterval(measureCount),
            duration: 1.0,
            dynamics: dynamics
        )

        generatedEvents.append(event)
    }

    private func generateOstinato(beat: Int) {
        // Repeating rhythmic pattern
        let pattern: [ScoreEvent.DynamicMarking] = [.f, .mp, .mf, .mp]
        let dynamics = pattern[beat % pattern.count]

        let event = ScoreEvent(
            type: .note,
            time: TimeInterval(measureCount),
            duration: 0.5,
            dynamics: dynamics
        )

        generatedEvents.append(event)
    }

    private func generateFanfare() {
        // Brass fanfare pattern
        let event = ScoreEvent(
            type: .chord,
            time: TimeInterval(measureCount),
            duration: 2.0,
            dynamics: .ff
        )

        generatedEvents.append(event)
    }

    private func generateMickeyMousing(beat: Int) {
        // Syncopated, playful patterns
        let offbeat = beat % 2 == 1

        let event = ScoreEvent(
            type: .note,
            time: TimeInterval(measureCount) + (offbeat ? 0.25 : 0),
            duration: 0.25,
            dynamics: offbeat ? .f : .mf
        )

        generatedEvents.append(event)
    }

    private func generateUnderscore(beat: Int, modifier: Float) {
        // Subtle background scoring
        if beat == 0 {
            let dynamics: ScoreEvent.DynamicMarking = modifier > 0.7 ? .mp : .p

            let event = ScoreEvent(
                type: .chord,
                time: TimeInterval(measureCount),
                duration: 4.0,
                dynamics: dynamics
            )

            generatedEvents.append(event)
        }
    }

    // MARK: - Bio-Reactivity

    /// Update bio data for reactive composition
    public func updateBioData(coherence: Float? = nil, heartRate: Float? = nil, breathPhase: Float? = nil) {
        if let c = coherence { self.coherence = c }
        if let hr = heartRate { self.heartRate = hr }
        if let bp = breathPhase { self.breathPhase = bp }
    }

    // MARK: - Leitmotif Management

    /// Add a custom leitmotif
    public func addLeitmotif(_ motif: Leitmotif) {
        leitmotifs.append(motif)
    }

    /// Get leitmotif by association
    public func getLeitmotif(for association: String) -> Leitmotif? {
        leitmotifs.first { $0.associatedWith.lowercased() == association.lowercased() }
    }

    // MARK: - Presets

    /// Load Walt Disney Classic preset
    public func loadDisneyClassicPreset() {
        leitmotifs.removeAll()
        setupDefaultLeitmotifs()

        // Add Disney-specific motifs
        leitmotifs.append(Leitmotif(
            name: "When You Wish",
            associatedWith: "Dreams",
            melody: [0, 4, 7, 12, 11, 9, 7],
            rhythm: [2, 1, 1, 2, 1, 1, 2],
            keyCenter: 60,
            mode: .major,
            primaryInstrument: "Violins I",
            dynamics: .mp,
            tempo: 72
        ))

        leitmotifs.append(Leitmotif(
            name: "Transformation Magic",
            associatedWith: "Magic",
            melody: [0, 4, 7, 11, 12, 16, 19],
            rhythm: [0.5, 0.5, 0.5, 0.5, 1, 1, 2],
            keyCenter: 65,
            mode: .lydian,
            primaryInstrument: "Celesta",
            dynamics: .p,
            tempo: 84
        ))

        print("🏰 Loaded Walt Disney Classic preset")
    }

    /// Load John Williams Epic preset
    public func loadEpicAdventurePreset() {
        leitmotifs.removeAll()

        leitmotifs.append(Leitmotif(
            name: "Adventure Fanfare",
            associatedWith: "Adventure",
            melody: [0, 7, 12, 7, 12, 16, 19, 24],
            rhythm: [0.5, 0.5, 1, 0.5, 0.5, 1, 1, 2],
            keyCenter: 55,  // G
            mode: .major,
            primaryInstrument: "Trumpets",
            dynamics: .ff,
            tempo: 140
        ))

        leitmotifs.append(Leitmotif(
            name: "Hero March",
            associatedWith: "Protagonist",
            melody: [0, 0, 4, 7, 7, 12, 11, 7],
            rhythm: [0.5, 0.5, 1, 0.5, 0.5, 1, 1, 2],
            keyCenter: 60,
            mode: .major,
            primaryInstrument: "French Horns",
            dynamics: .f,
            tempo: 108
        ))

        print("⚔️ Loaded Epic Adventure preset")
    }

    /// Load Hans Zimmer Modern preset
    public func loadModernCinematicPreset() {
        leitmotifs.removeAll()

        leitmotifs.append(Leitmotif(
            name: "Inception Pulse",
            associatedWith: "Time",
            melody: [0, 0, 0, 0, 7, 7, 7, 7],
            rhythm: [1, 1, 1, 1, 1, 1, 1, 1],
            keyCenter: 48,  // C2
            mode: .minor,
            primaryInstrument: "Cellos",
            dynamics: .f,
            tempo: 60
        ))

        leitmotifs.append(Leitmotif(
            name: "Rising Tension",
            associatedWith: "Tension",
            melody: [0, 1, 2, 3, 4, 5, 6, 7],
            rhythm: [2, 2, 2, 2, 2, 2, 2, 4],
            keyCenter: 52,
            mode: .phrygian,
            primaryInstrument: "Strings",
            dynamics: .crescendo,
            tempo: 80
        ))

        print("🌊 Loaded Modern Cinematic preset")
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
