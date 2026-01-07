// CinematicScoringEngine.swift
// Echoelmusic - 10000% Ralph Wiggum Loop Mode
//
// Professional Cinematic Orchestral Scoring Engine
// Inspired by: Spitfire Audio, BBCSO, Berlin Series, Cinematic Studio Series
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine
import AVFoundation

// MARK: - Cinematic Constants

/// Constants for cinematic scoring
public enum CinematicConstants {
    // Concert pitch
    public static let concertPitch: Float = 440.0  // A4 = 440 Hz
    public static let viennaPitch: Float = 443.0   // Vienna tuning
    public static let baroquePitch: Float = 415.0  // Baroque tuning

    // Orchestral ranges (MIDI notes)
    public static let violinRange: ClosedRange<Int> = 55...103      // G3 to G7
    public static let violaRange: ClosedRange<Int> = 48...91        // C3 to G6
    public static let celloRange: ClosedRange<Int> = 36...76        // C2 to E5
    public static let bassRange: ClosedRange<Int> = 28...60         // E1 to C4

    public static let trumpetRange: ClosedRange<Int> = 52...82      // E3 to A#5
    public static let hornRange: ClosedRange<Int> = 34...77         // A#1 to F5
    public static let tromboneRange: ClosedRange<Int> = 40...72     // E2 to C5
    public static let tubaRange: ClosedRange<Int> = 28...58         // E1 to A#3

    public static let fluteRange: ClosedRange<Int> = 60...96        // C4 to C7
    public static let oboeRange: ClosedRange<Int> = 58...91         // A#3 to G6
    public static let clarinetRange: ClosedRange<Int> = 50...91     // D3 to G6
    public static let bassoonRange: ClosedRange<Int> = 34...75      // A#1 to D#5

    // Section sizes
    public static let firstViolins: Int = 16
    public static let secondViolins: Int = 14
    public static let violas: Int = 12
    public static let cellos: Int = 10
    public static let basses: Int = 8

    // Dynamics (velocity ranges)
    public static let ppp: ClosedRange<Float> = 0.0...0.15
    public static let pp: ClosedRange<Float> = 0.15...0.30
    public static let p: ClosedRange<Float> = 0.30...0.45
    public static let mp: ClosedRange<Float> = 0.45...0.55
    public static let mf: ClosedRange<Float> = 0.55...0.70
    public static let f: ClosedRange<Float> = 0.70...0.85
    public static let ff: ClosedRange<Float> = 0.85...0.95
    public static let fff: ClosedRange<Float> = 0.95...1.0
}

// MARK: - Articulation Types

/// Professional articulation types for orchestral instruments
public enum ArticulationType: String, CaseIterable, Identifiable, Sendable {
    // Core articulations
    case legato = "Legato"
    case sustain = "Sustain"
    case staccato = "Staccato"
    case staccatissimo = "Staccatissimo"
    case spiccato = "Spiccato"
    case pizzicato = "Pizzicato"
    case tremolo = "Tremolo"
    case trill = "Trill"
    case marcato = "Marcato"
    case tenuto = "Tenuto"
    case accent = "Accent"

    // Extended techniques
    case colLegno = "Col Legno"
    case sulPonticello = "Sul Ponticello"
    case sulTasto = "Sul Tasto"
    case harmonics = "Harmonics"
    case flautando = "Flautando"
    case conSordino = "Con Sordino"
    case bartok = "Bartók Pizzicato"

    // Brass specific
    case sforzando = "Sforzando"
    case rip = "Rip"
    case fall = "Fall"
    case shake = "Shake"
    case flutter = "Flutter Tongue"
    case muted = "Muted"
    case stopped = "Stopped"
    case cuivre = "Cuivré"

    // Woodwind specific
    case multiphonic = "Multiphonic"
    case keyClicks = "Key Clicks"
    case airTone = "Air Tone"
    case overblown = "Overblown"

    public var id: String { rawValue }

    /// Attack time in seconds
    public var attackTime: Float {
        switch self {
        case .legato: return 0.15
        case .sustain: return 0.08
        case .staccato: return 0.02
        case .staccatissimo: return 0.01
        case .spiccato: return 0.015
        case .pizzicato: return 0.005
        case .tremolo: return 0.03
        case .marcato: return 0.04
        case .sforzando: return 0.02
        default: return 0.05
        }
    }

    /// Release time in seconds
    public var releaseTime: Float {
        switch self {
        case .legato: return 0.2
        case .sustain: return 0.3
        case .staccato: return 0.05
        case .staccatissimo: return 0.02
        case .pizzicato: return 0.8
        default: return 0.15
        }
    }
}

// MARK: - Expression Controller

/// MIDI CC expression controllers
public enum ExpressionController: Int, CaseIterable, Sendable {
    case modWheel = 1          // CC1 - Dynamics/Vibrato
    case breath = 2            // CC2 - Breath controller
    case expression = 11       // CC11 - Expression
    case vibrato = 21          // CC21 - Vibrato depth
    case vibratoRate = 22      // CC22 - Vibrato rate
    case attack = 73           // CC73 - Attack time
    case release = 72          // CC72 - Release time
    case brightness = 74       // CC74 - Filter cutoff
    case timbre = 71           // CC71 - Timbre/Resonance
    case dynamics = 7          // CC7 - Volume
}

// MARK: - Orchestral Section

/// Types of orchestral sections
public enum OrchestraSection: String, CaseIterable, Identifiable, Sendable {
    case strings = "Strings"
    case brass = "Brass"
    case woodwinds = "Woodwinds"
    case percussion = "Percussion"
    case choir = "Choir"
    case piano = "Piano"
    case harp = "Harp"
    case celesta = "Celesta"

    public var id: String { rawValue }

    /// Section weight in the mix (0-1)
    public var defaultMixWeight: Float {
        switch self {
        case .strings: return 0.35
        case .brass: return 0.20
        case .woodwinds: return 0.15
        case .percussion: return 0.10
        case .choir: return 0.10
        case .piano: return 0.05
        case .harp: return 0.03
        case .celesta: return 0.02
        }
    }
}

// MARK: - Instrument Definition

/// Professional orchestral instrument definition
public struct OrchestraInstrument: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var section: OrchestraSection
    public var range: ClosedRange<Int>
    public var transposition: Int  // Semitones from concert pitch
    public var supportedArticulations: Set<ArticulationType>
    public var defaultArticulation: ArticulationType
    public var position: StagePosition
    public var sectionSize: Int  // Number of players

    public struct StagePosition: Equatable, Sendable {
        public var x: Float  // -1 (left) to 1 (right)
        public var y: Float  // 0 (front) to 1 (back)
        public var width: Float  // Stereo width

        public init(x: Float = 0, y: Float = 0.5, width: Float = 0.3) {
            self.x = x
            self.y = y
            self.width = width
        }
    }

    public init(
        name: String,
        section: OrchestraSection,
        range: ClosedRange<Int>,
        transposition: Int = 0,
        supportedArticulations: Set<ArticulationType>,
        defaultArticulation: ArticulationType = .sustain,
        position: StagePosition = StagePosition(),
        sectionSize: Int = 1
    ) {
        self.id = UUID()
        self.name = name
        self.section = section
        self.range = range
        self.transposition = transposition
        self.supportedArticulations = supportedArticulations
        self.defaultArticulation = defaultArticulation
        self.position = position
        self.sectionSize = sectionSize
    }
}

// MARK: - Orchestral Voice

/// A single orchestral voice with expression
public struct OrchestraVoice: Identifiable, Sendable {
    public let id = UUID()
    public var instrument: OrchestraInstrument
    public var pitch: Int
    public var velocity: Float
    public var articulation: ArticulationType
    public var expression: Float  // CC11
    public var vibrato: Float     // CC21
    public var dynamics: Float    // CC1
    public var pan: Float         // -1 to 1
    public var startTime: TimeInterval
    public var duration: TimeInterval

    public init(
        instrument: OrchestraInstrument,
        pitch: Int,
        velocity: Float = 0.7,
        articulation: ArticulationType? = nil,
        duration: TimeInterval = 1.0
    ) {
        self.instrument = instrument
        self.pitch = pitch.clamped(to: instrument.range)
        self.velocity = velocity.clamped(to: 0...1)
        self.articulation = articulation ?? instrument.defaultArticulation
        self.expression = 1.0
        self.vibrato = 0.3
        self.dynamics = velocity
        self.pan = instrument.position.x
        self.startTime = 0
        self.duration = duration
    }

    /// Frequency in Hz
    public var frequency: Float {
        CinematicConstants.concertPitch * pow(2.0, Float(pitch - 69) / 12.0)
    }
}

// MARK: - Score Event

/// A musical event in the score
public struct ScoreEvent: Identifiable, Sendable {
    public let id = UUID()
    public var type: EventType
    public var time: TimeInterval
    public var duration: TimeInterval
    public var voices: [OrchestraVoice]
    public var dynamics: DynamicMarking
    public var tempo: Float?
    public var tempoChange: TempoChange?

    public enum EventType: String, Sendable {
        case note = "Note"
        case chord = "Chord"
        case rest = "Rest"
        case fermata = "Fermata"
        case crescendo = "Crescendo"
        case decrescendo = "Decrescendo"
        case tempoChange = "Tempo Change"
        case keyChange = "Key Change"
        case meterChange = "Meter Change"
    }

    public enum DynamicMarking: String, CaseIterable, Sendable {
        case ppp, pp, p, mp, mf, f, ff, fff
        case sfz, sfp, fp, rf, rfz

        public var velocityRange: ClosedRange<Float> {
            switch self {
            case .ppp: return CinematicConstants.ppp
            case .pp: return CinematicConstants.pp
            case .p: return CinematicConstants.p
            case .mp: return CinematicConstants.mp
            case .mf: return CinematicConstants.mf
            case .f: return CinematicConstants.f
            case .ff: return CinematicConstants.ff
            case .fff: return CinematicConstants.fff
            case .sfz, .sfp, .fp, .rf, .rfz: return CinematicConstants.ff
            }
        }
    }

    public enum TempoChange: String, Sendable {
        case accelerando = "Accelerando"
        case ritardando = "Ritardando"
        case rallentando = "Rallentando"
        case allargando = "Allargando"
        case stringendo = "Stringendo"
        case rubato = "Rubato"
        case aTempo = "A Tempo"
    }

    public init(type: EventType, time: TimeInterval, duration: TimeInterval = 1.0, voices: [OrchestraVoice] = [], dynamics: DynamicMarking = .mf) {
        self.type = type
        self.time = time
        self.duration = duration
        self.voices = voices
        self.dynamics = dynamics
    }
}

// MARK: - Score Configuration

/// Configuration for a cinematic score
public struct ScoreConfiguration: Sendable {
    public var title: String
    public var composer: String
    public var tempo: Float  // BPM
    public var timeSignature: TimeSignature
    public var keySignature: KeySignature
    public var style: ScoringStyle
    public var mood: ScoreMood
    public var orchestraSize: OrchestraSize
    public var mixPreset: MixPreset
    public var reverbType: ReverbType
    public var masterVolume: Float

    public struct TimeSignature: Equatable, Sendable {
        public var numerator: Int
        public var denominator: Int

        public static let fourFour = TimeSignature(numerator: 4, denominator: 4)
        public static let threeFour = TimeSignature(numerator: 3, denominator: 4)
        public static let sixEight = TimeSignature(numerator: 6, denominator: 8)
        public static let twelvEight = TimeSignature(numerator: 12, denominator: 8)

        public init(numerator: Int, denominator: Int) {
            self.numerator = numerator
            self.denominator = denominator
        }
    }

    public enum KeySignature: String, CaseIterable, Sendable {
        case cMajor = "C Major"
        case gMajor = "G Major"
        case dMajor = "D Major"
        case aMajor = "A Major"
        case eMajor = "E Major"
        case bMajor = "B Major"
        case fMajor = "F Major"
        case bbMajor = "Bb Major"
        case ebMajor = "Eb Major"
        case abMajor = "Ab Major"
        case aMinor = "A Minor"
        case eMinor = "E Minor"
        case dMinor = "D Minor"
        case gMinor = "G Minor"
        case cMinor = "C Minor"
        case fMinor = "F Minor"
    }

    public enum ScoringStyle: String, CaseIterable, Sendable {
        case cinematic = "Cinematic"
        case classical = "Classical"
        case romantic = "Romantic"
        case modern = "Modern"
        case minimalist = "Minimalist"
        case epic = "Epic"
        case intimate = "Intimate"
        case action = "Action"
        case horror = "Horror"
        case fantasy = "Fantasy"
        case sciFi = "Sci-Fi"
        case documentary = "Documentary"
        case animation = "Animation"  // Disney-style
        case adventure = "Adventure"
    }

    public enum ScoreMood: String, CaseIterable, Sendable {
        case triumphant = "Triumphant"
        case melancholic = "Melancholic"
        case mysterious = "Mysterious"
        case heroic = "Heroic"
        case romantic = "Romantic"
        case tense = "Tense"
        case peaceful = "Peaceful"
        case playful = "Playful"
        case majestic = "Majestic"
        case ethereal = "Ethereal"
        case dramatic = "Dramatic"
        case whimsical = "Whimsical"  // Disney
        case magical = "Magical"      // Disney
        case adventurous = "Adventurous"
    }

    public enum OrchestraSize: String, CaseIterable, Sendable {
        case chamber = "Chamber (20-30)"
        case small = "Small (40-50)"
        case medium = "Medium (60-70)"
        case large = "Large (80-100)"
        case hollywood = "Hollywood (100+)"
    }

    public enum MixPreset: String, CaseIterable, Sendable {
        case close = "Close Mics"
        case tree = "Decca Tree"
        case room = "Room"
        case outriggers = "Outriggers"
        case surround = "Surround"
        case mixed = "Mixed"
    }

    public enum ReverbType: String, CaseIterable, Sendable {
        case studio = "Studio"
        case concertHall = "Concert Hall"
        case cathedral = "Cathedral"
        case airStudios = "Air Studios"
        case abbeyRoad = "Abbey Road"
        case soundstage = "Soundstage"
        case intimate = "Intimate"
    }

    public init(
        title: String = "Untitled Score",
        composer: String = "Unknown",
        tempo: Float = 90,
        style: ScoringStyle = .cinematic
    ) {
        self.title = title
        self.composer = composer
        self.tempo = tempo
        self.timeSignature = .fourFour
        self.keySignature = .cMajor
        self.style = style
        self.mood = .dramatic
        self.orchestraSize = .large
        self.mixPreset = .tree
        self.reverbType = .concertHall
        self.masterVolume = 0.8
    }
}

// MARK: - Cinematic Scoring Engine

/// Main professional cinematic scoring engine
@MainActor
public final class CinematicScoringEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var totalDuration: TimeInterval = 0
    @Published public private(set) var activeVoices: [OrchestraVoice] = []
    @Published public private(set) var currentDynamics: ScoreEvent.DynamicMarking = .mf

    @Published public var configuration = ScoreConfiguration()
    @Published public var events: [ScoreEvent] = []

    // MARK: - Orchestral Instruments

    public private(set) var instruments: [OrchestraInstrument] = []

    // MARK: - Private Properties

    private var playbackTimer: Timer?
    private var audioEngine: AVAudioEngine?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupInstruments()
        setupAudioEngine()
    }

    // MARK: - Instrument Setup

    private func setupInstruments() {
        instruments = [
            // STRINGS - Spitfire Chamber Strings / BBCSO / CSS inspired
            OrchestraInstrument(
                name: "Violins I",
                section: .strings,
                range: CinematicConstants.violinRange,
                supportedArticulations: [.legato, .sustain, .staccato, .spiccato, .tremolo, .pizzicato, .colLegno, .sulPonticello, .harmonics, .conSordino],
                position: OrchestraInstrument.StagePosition(x: -0.6, y: 0.3, width: 0.4),
                sectionSize: CinematicConstants.firstViolins
            ),
            OrchestraInstrument(
                name: "Violins II",
                section: .strings,
                range: CinematicConstants.violinRange,
                supportedArticulations: [.legato, .sustain, .staccato, .spiccato, .tremolo, .pizzicato, .colLegno, .conSordino],
                position: OrchestraInstrument.StagePosition(x: -0.3, y: 0.35, width: 0.35),
                sectionSize: CinematicConstants.secondViolins
            ),
            OrchestraInstrument(
                name: "Violas",
                section: .strings,
                range: CinematicConstants.violaRange,
                supportedArticulations: [.legato, .sustain, .staccato, .spiccato, .tremolo, .pizzicato, .colLegno, .conSordino],
                position: OrchestraInstrument.StagePosition(x: 0.1, y: 0.4, width: 0.3),
                sectionSize: CinematicConstants.violas
            ),
            OrchestraInstrument(
                name: "Cellos",
                section: .strings,
                range: CinematicConstants.celloRange,
                supportedArticulations: [.legato, .sustain, .staccato, .spiccato, .tremolo, .pizzicato, .harmonics, .conSordino],
                position: OrchestraInstrument.StagePosition(x: 0.4, y: 0.35, width: 0.35),
                sectionSize: CinematicConstants.cellos
            ),
            OrchestraInstrument(
                name: "Basses",
                section: .strings,
                range: CinematicConstants.bassRange,
                supportedArticulations: [.legato, .sustain, .staccato, .pizzicato, .tremolo],
                position: OrchestraInstrument.StagePosition(x: 0.7, y: 0.5, width: 0.3),
                sectionSize: CinematicConstants.basses
            ),

            // BRASS - Spitfire Symphonic Brass inspired
            OrchestraInstrument(
                name: "Trumpets",
                section: .brass,
                range: CinematicConstants.trumpetRange,
                supportedArticulations: [.sustain, .staccato, .marcato, .sforzando, .muted, .flutter, .rip, .fall],
                position: OrchestraInstrument.StagePosition(x: 0.2, y: 0.7, width: 0.25),
                sectionSize: 3
            ),
            OrchestraInstrument(
                name: "French Horns",
                section: .brass,
                range: CinematicConstants.hornRange,
                transposition: -7,  // F horn
                supportedArticulations: [.sustain, .staccato, .marcato, .sforzando, .stopped, .muted, .cuivre, .rip],
                position: OrchestraInstrument.StagePosition(x: -0.3, y: 0.75, width: 0.35),
                sectionSize: 4
            ),
            OrchestraInstrument(
                name: "Trombones",
                section: .brass,
                range: CinematicConstants.tromboneRange,
                supportedArticulations: [.sustain, .staccato, .marcato, .sforzando, .muted, .flutter],
                position: OrchestraInstrument.StagePosition(x: 0.4, y: 0.75, width: 0.3),
                sectionSize: 3
            ),
            OrchestraInstrument(
                name: "Tuba",
                section: .brass,
                range: CinematicConstants.tubaRange,
                supportedArticulations: [.sustain, .staccato, .marcato, .sforzando],
                position: OrchestraInstrument.StagePosition(x: 0.6, y: 0.8, width: 0.2),
                sectionSize: 1
            ),

            // WOODWINDS - Berlin Woodwinds / Spitfire Symphonic WW inspired
            OrchestraInstrument(
                name: "Flutes",
                section: .woodwinds,
                range: CinematicConstants.fluteRange,
                supportedArticulations: [.legato, .sustain, .staccato, .trill, .flutter, .harmonics],
                position: OrchestraInstrument.StagePosition(x: -0.5, y: 0.55, width: 0.2),
                sectionSize: 3
            ),
            OrchestraInstrument(
                name: "Oboes",
                section: .woodwinds,
                range: CinematicConstants.oboeRange,
                supportedArticulations: [.legato, .sustain, .staccato, .trill],
                position: OrchestraInstrument.StagePosition(x: -0.3, y: 0.55, width: 0.15),
                sectionSize: 2
            ),
            OrchestraInstrument(
                name: "Clarinets",
                section: .woodwinds,
                range: CinematicConstants.clarinetRange,
                transposition: -2,  // Bb clarinet
                supportedArticulations: [.legato, .sustain, .staccato, .trill, .multiphonic],
                position: OrchestraInstrument.StagePosition(x: -0.1, y: 0.55, width: 0.15),
                sectionSize: 2
            ),
            OrchestraInstrument(
                name: "Bassoons",
                section: .woodwinds,
                range: CinematicConstants.bassoonRange,
                supportedArticulations: [.legato, .sustain, .staccato, .trill],
                position: OrchestraInstrument.StagePosition(x: 0.1, y: 0.6, width: 0.15),
                sectionSize: 2
            ),

            // CHOIR - Dominus Pro / Requiem Light inspired
            OrchestraInstrument(
                name: "Sopranos",
                section: .choir,
                range: 60...84,  // C4 to C6
                supportedArticulations: [.legato, .sustain, .staccato],
                position: OrchestraInstrument.StagePosition(x: -0.4, y: 0.9, width: 0.3),
                sectionSize: 12
            ),
            OrchestraInstrument(
                name: "Altos",
                section: .choir,
                range: 53...77,  // F3 to F5
                supportedArticulations: [.legato, .sustain, .staccato],
                position: OrchestraInstrument.StagePosition(x: -0.1, y: 0.9, width: 0.3),
                sectionSize: 10
            ),
            OrchestraInstrument(
                name: "Tenors",
                section: .choir,
                range: 48...72,  // C3 to C5
                supportedArticulations: [.legato, .sustain, .staccato],
                position: OrchestraInstrument.StagePosition(x: 0.2, y: 0.9, width: 0.3),
                sectionSize: 8
            ),
            OrchestraInstrument(
                name: "Basses (Choir)",
                section: .choir,
                range: 40...64,  // E2 to E4
                supportedArticulations: [.legato, .sustain, .staccato],
                position: OrchestraInstrument.StagePosition(x: 0.5, y: 0.9, width: 0.3),
                sectionSize: 8
            ),

            // PIANO - Alicia's Keys / Nils Frahm Piano / Max Richter Piano inspired
            OrchestraInstrument(
                name: "Grand Piano",
                section: .piano,
                range: 21...108,  // Full piano range
                supportedArticulations: [.sustain, .staccato, .legato],
                position: OrchestraInstrument.StagePosition(x: -0.7, y: 0.2, width: 0.4),
                sectionSize: 1
            ),

            // HARP
            OrchestraInstrument(
                name: "Concert Harp",
                section: .harp,
                range: 24...103,  // Concert harp range
                supportedArticulations: [.sustain, .staccato, .harmonics],
                position: OrchestraInstrument.StagePosition(x: -0.8, y: 0.4, width: 0.2),
                sectionSize: 1
            ),

            // CELESTA
            OrchestraInstrument(
                name: "Celesta",
                section: .celesta,
                range: 60...108,  // Celesta range
                supportedArticulations: [.sustain, .staccato],
                position: OrchestraInstrument.StagePosition(x: -0.6, y: 0.25, width: 0.15),
                sectionSize: 1
            ),

            // PERCUSSION
            OrchestraInstrument(
                name: "Timpani",
                section: .percussion,
                range: 40...57,  // Timpani range
                supportedArticulations: [.sustain, .staccato, .tremolo],
                position: OrchestraInstrument.StagePosition(x: 0.0, y: 0.85, width: 0.4),
                sectionSize: 4
            )
        ]
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        // Audio engine setup for real-time orchestral synthesis
    }

    // MARK: - Playback Control

    /// Start score playback
    public func play() {
        guard !isPlaying else { return }

        isPlaying = true
        startPlaybackTimer()

        log.orchestral("🎼 CinematicScoringEngine: Playing '\(configuration.title)' at \(configuration.tempo) BPM")
    }

    /// Stop playback
    public func stop() {
        isPlaying = false
        stopPlaybackTimer()
        currentTime = 0
        activeVoices.removeAll()

        log.orchestral("🎼 CinematicScoringEngine: Stopped")
    }

    /// Pause playback
    public func pause() {
        isPlaying = false
        stopPlaybackTimer()
    }

    /// Seek to time
    public func seek(to time: TimeInterval) {
        currentTime = max(0, min(time, totalDuration))
    }

    // MARK: - Playback Timer

    private func startPlaybackTimer() {
        let beatInterval = 60.0 / Double(configuration.tempo)

        playbackTimer = Timer.scheduledTimer(withTimeInterval: beatInterval / 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlayback()
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updatePlayback() {
        let beatInterval = 60.0 / Double(configuration.tempo)
        currentTime += beatInterval / 4

        // Process events at current time
        for event in events where abs(event.time - currentTime) < beatInterval / 8 {
            processEvent(event)
        }

        // Check for end
        if currentTime >= totalDuration {
            stop()
        }
    }

    private func processEvent(_ event: ScoreEvent) {
        currentDynamics = event.dynamics

        switch event.type {
        case .note, .chord:
            activeVoices.append(contentsOf: event.voices)

        case .rest:
            break

        case .crescendo, .decrescendo:
            // Handle dynamic changes
            break

        case .tempoChange:
            if let tempo = event.tempo {
                configuration.tempo = tempo
            }

        default:
            break
        }
    }

    // MARK: - Score Building

    /// Add an event to the score
    public func addEvent(_ event: ScoreEvent) {
        events.append(event)
        events.sort { $0.time < $1.time }
        updateDuration()
    }

    /// Create a chord from pitches
    public func createChord(
        instrument: OrchestraInstrument,
        pitches: [Int],
        time: TimeInterval,
        duration: TimeInterval,
        articulation: ArticulationType? = nil,
        dynamics: ScoreEvent.DynamicMarking = .mf
    ) -> ScoreEvent {
        let voices = pitches.map { pitch in
            OrchestraVoice(
                instrument: instrument,
                pitch: pitch,
                velocity: Float.random(in: dynamics.velocityRange),
                articulation: articulation,
                duration: duration
            )
        }

        return ScoreEvent(
            type: .chord,
            time: time,
            duration: duration,
            voices: voices,
            dynamics: dynamics
        )
    }

    /// Create a full orchestral chord
    public func createOrchestralChord(
        pitches: [Int],
        time: TimeInterval,
        duration: TimeInterval,
        sections: Set<OrchestraSection> = [.strings],
        dynamics: ScoreEvent.DynamicMarking = .mf
    ) -> ScoreEvent {
        var voices: [OrchestraVoice] = []

        for section in sections {
            let sectionInstruments = instruments.filter { $0.section == section }

            for instrument in sectionInstruments {
                // Find pitches in this instrument's range
                let validPitches = pitches.filter { instrument.range.contains($0) }

                for pitch in validPitches {
                    let voice = OrchestraVoice(
                        instrument: instrument,
                        pitch: pitch,
                        velocity: Float.random(in: dynamics.velocityRange),
                        duration: duration
                    )
                    voices.append(voice)
                }
            }
        }

        return ScoreEvent(
            type: .chord,
            time: time,
            duration: duration,
            voices: voices,
            dynamics: dynamics
        )
    }

    private func updateDuration() {
        totalDuration = events.map { $0.time + $0.duration }.max() ?? 0
    }

    // MARK: - Instrument Access

    /// Get instrument by name
    public func getInstrument(named name: String) -> OrchestraInstrument? {
        instruments.first { $0.name == name }
    }

    /// Get all instruments in a section
    public func getInstruments(in section: OrchestraSection) -> [OrchestraInstrument] {
        instruments.filter { $0.section == section }
    }

    // MARK: - Presets

    /// Load a Disney-style animation preset
    public func loadDisneyAnimationPreset() {
        configuration.style = .animation
        configuration.mood = .magical
        configuration.orchestraSize = .large
        configuration.reverbType = .soundstage
        configuration.tempo = 100

        log.orchestral("🏰 Loaded Disney Animation preset")
    }

    /// Load an epic adventure preset
    public func loadEpicAdventurePreset() {
        configuration.style = .epic
        configuration.mood = .heroic
        configuration.orchestraSize = .hollywood
        configuration.reverbType = .soundstage
        configuration.tempo = 85

        log.orchestral("⚔️ Loaded Epic Adventure preset")
    }

    /// Load a romantic score preset
    public func loadRomanticPreset() {
        configuration.style = .romantic
        configuration.mood = .romantic
        configuration.orchestraSize = .medium
        configuration.reverbType = .concertHall
        configuration.tempo = 72

        log.orchestral("💕 Loaded Romantic preset")
    }

    /// Load an intimate piano preset (Max Richter style)
    public func loadIntimatePreset() {
        configuration.style = .intimate
        configuration.mood = .melancholic
        configuration.orchestraSize = .chamber
        configuration.reverbType = .intimate
        configuration.tempo = 60

        log.orchestral("🎹 Loaded Intimate Piano preset")
    }
}

// MARK: - Int Extension

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        max(range.lowerBound, min(range.upperBound, self))
    }
}

// MARK: - Float Extension

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
