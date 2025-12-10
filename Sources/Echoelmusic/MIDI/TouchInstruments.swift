import Foundation
import SwiftUI
import Combine
import CoreHaptics
import os.log

// MARK: - Touch Instruments Hub
/// Collection of professional touch interfaces for iOS/iPadOS
/// All instruments use MIDI 2.0 + MPE for maximum expressivity
/// Mobile-first design optimized for finger and Apple Pencil input

@MainActor
class TouchInstrumentsHub: ObservableObject {

    // MARK: - Logger

    private let midiLogger = Logger(subsystem: "com.echoelmusic", category: "TouchInstruments")

    // MARK: - Published State

    @Published var activeInstrument: InstrumentType = .chordPad
    @Published var isPlaying: Bool = false
    @Published var currentScale: MusicalScale = .major
    @Published var rootNote: UInt8 = 60 // Middle C
    @Published var octave: Int = 4

    // MARK: - Dependencies

    private var midi2Manager: MIDI2Manager?
    private var mpeZoneManager: MPEZoneManager?
    private var hapticEngine: CHHapticEngine?

    // MARK: - Instruments

    enum InstrumentType: String, CaseIterable {
        case chordPad = "Chord Pad"
        case drumPad = "Drum Pad"
        case melodyPad = "Melody XY"
        case keyboard = "Keyboard"
        case strumPad = "Strum Pad"
    }

    // MARK: - Initialization

    init() {
        setupHaptics()
    }

    func connect(midi2: MIDI2Manager, mpe: MPEZoneManager) {
        self.midi2Manager = midi2
        self.mpeZoneManager = mpe
        midiLogger.info("Connected to MIDI 2.0 + MPE")
    }

    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            midiLogger.debug("Haptics not available")
        }
    }

    // MARK: - Haptic Feedback

    func triggerHaptic(intensity: Float = 0.5, sharpness: Float = 0.5) {
        guard let engine = hapticEngine else { return }

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptic failed silently
        }
    }
}

// MARK: - Musical Scale

enum MusicalScale: String, CaseIterable {
    case major = "Major"
    case minor = "Minor"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues = "Blues"
    case chromatic = "Chromatic"
    case wholeNote = "Whole Tone"

    var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .chromatic: return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .wholeNote: return [0, 2, 4, 6, 8, 10]
        }
    }

    func noteInScale(degree: Int, root: UInt8) -> UInt8 {
        let octaveOffset = degree / intervals.count
        let scaleIndex = degree % intervals.count
        let note = Int(root) + (octaveOffset * 12) + intervals[scaleIndex]
        return UInt8(max(0, min(127, note)))
    }
}

// MARK: - Chord Type

enum ChordType: String, CaseIterable {
    case major = "Major"
    case minor = "Minor"
    case diminished = "Dim"
    case augmented = "Aug"
    case major7 = "Maj7"
    case minor7 = "Min7"
    case dominant7 = "7"
    case sus2 = "Sus2"
    case sus4 = "Sus4"
    case add9 = "Add9"
    case power = "5"

    var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        case .dominant7: return [0, 4, 7, 10]
        case .sus2: return [0, 2, 7]
        case .sus4: return [0, 5, 7]
        case .add9: return [0, 4, 7, 14]
        case .power: return [0, 7]
        }
    }

    func notes(root: UInt8) -> [UInt8] {
        intervals.map { interval in
            UInt8(max(0, min(127, Int(root) + interval)))
        }
    }
}

// MARK: - Chord Pad View
/// Touch interface for triggering chords with strumming and arpeggiation
/// Features: 8 chord pads, strum gesture, arpeggiator, inversions

struct ChordPadView: View {

    @ObservedObject var hub: TouchInstrumentsHub
    @StateObject private var viewModel = ChordPadViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Chord Pad")
                    .font(.headline)

                Spacer()

                // Scale selector
                Picker("Scale", selection: $hub.currentScale) {
                    ForEach(MusicalScale.allCases, id: \.self) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
                .pickerStyle(.menu)

                // Root note
                Picker("Root", selection: $hub.rootNote) {
                    ForEach(48...72, id: \.self) { note in
                        Text(noteNameFromMIDI(UInt8(note))).tag(UInt8(note))
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)

            // Mode selector
            HStack(spacing: 12) {
                ForEach(ChordPadViewModel.PlayMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) {
                        viewModel.playMode = mode
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.playMode == mode ? .blue : .gray)
                }
            }

            // Chord pads grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.chordPads) { pad in
                    ChordPadButton(
                        pad: pad,
                        isPressed: viewModel.pressedPads.contains(pad.id),
                        onPress: { location, pressure in
                            viewModel.padPressed(pad, location: location, pressure: pressure, hub: hub)
                        },
                        onRelease: {
                            viewModel.padReleased(pad, hub: hub)
                        },
                        onDrag: { translation in
                            viewModel.padDragged(pad, translation: translation, hub: hub)
                        }
                    )
                }
            }
            .padding()

            // Arpeggiator controls
            if viewModel.playMode == .arpeggio {
                ArpeggiatorControls(viewModel: viewModel)
            }
        }
    }

    private func noteNameFromMIDI(_ note: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let noteName = noteNames[Int(note) % 12]
        return "\(noteName)\(octave)"
    }
}

// MARK: - Chord Pad Button

struct ChordPadButton: View {

    let pad: ChordPad
    let isPressed: Bool
    var onPress: (CGPoint, Float) -> Void
    var onRelease: () -> Void
    var onDrag: (CGSize) -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isPressed ? pad.color.opacity(0.8) : pad.color.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(pad.color, lineWidth: 2)
                )

            VStack(spacing: 4) {
                Text(pad.chordName)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(pad.chordType.rawValue)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(height: 80)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragOffset == .zero {
                        // Initial press
                        onPress(value.startLocation, 0.8)
                    }
                    dragOffset = value.translation
                    onDrag(value.translation)
                }
                .onEnded { _ in
                    dragOffset = .zero
                    onRelease()
                }
        )
    }
}

// MARK: - Chord Pad Model

struct ChordPad: Identifiable {
    let id = UUID()
    var rootNote: UInt8
    var chordType: ChordType
    var color: Color

    var chordName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return noteNames[Int(rootNote) % 12]
    }

    var notes: [UInt8] {
        chordType.notes(root: rootNote)
    }
}

// MARK: - Chord Pad View Model

@MainActor
class ChordPadViewModel: ObservableObject {

    @Published var chordPads: [ChordPad] = []
    @Published var pressedPads: Set<UUID> = []
    @Published var playMode: PlayMode = .simultaneous
    @Published var arpRate: Double = 120 // BPM
    @Published var arpPattern: ArpPattern = .up

    // Active voices for MPE
    private var activeVoices: [UUID: [MPEZoneManager.MPEVoice]] = [:]
    private var arpTimer: Timer?

    enum PlayMode: String, CaseIterable {
        case simultaneous = "Chord"
        case strum = "Strum"
        case arpeggio = "Arp"
    }

    enum ArpPattern: String, CaseIterable {
        case up = "Up"
        case down = "Down"
        case upDown = "Up/Down"
        case random = "Random"
    }

    init() {
        setupDefaultPads()
    }

    private func setupDefaultPads() {
        // Default chord progression: I - V - vi - IV (Pop progression)
        chordPads = [
            ChordPad(rootNote: 60, chordType: .major, color: .blue),      // C
            ChordPad(rootNote: 62, chordType: .minor, color: .purple),    // Dm
            ChordPad(rootNote: 64, chordType: .minor, color: .pink),      // Em
            ChordPad(rootNote: 65, chordType: .major, color: .orange),    // F
            ChordPad(rootNote: 67, chordType: .major, color: .green),     // G
            ChordPad(rootNote: 69, chordType: .minor, color: .red),       // Am
            ChordPad(rootNote: 71, chordType: .diminished, color: .gray), // Bdim
            ChordPad(rootNote: 60, chordType: .major7, color: .cyan)      // Cmaj7
        ]
    }

    func padPressed(_ pad: ChordPad, location: CGPoint, pressure: Float, hub: TouchInstrumentsHub) {
        pressedPads.insert(pad.id)
        hub.triggerHaptic(intensity: pressure, sharpness: 0.6)

        switch playMode {
        case .simultaneous:
            playChordSimultaneous(pad, velocity: pressure, hub: hub)
        case .strum:
            playChordStrummed(pad, velocity: pressure, hub: hub)
        case .arpeggio:
            startArpeggio(pad, velocity: pressure, hub: hub)
        }
    }

    func padReleased(_ pad: ChordPad, hub: TouchInstrumentsHub) {
        pressedPads.remove(pad.id)

        // Release all voices for this pad
        if let voices = activeVoices[pad.id] {
            for voice in voices {
                hub.mpeZoneManager?.deallocateVoice(voice: voice)
            }
            activeVoices.removeValue(forKey: pad.id)
        }

        if playMode == .arpeggio {
            stopArpeggio()
        }
    }

    func padDragged(_ pad: ChordPad, translation: CGSize, hub: TouchInstrumentsHub) {
        // Y-axis drag → pitch bend for all chord notes
        guard let voices = activeVoices[pad.id] else { return }

        let bendAmount = Float(translation.height / -200.0) // Invert Y, normalize
        let clampedBend = max(-1.0, min(1.0, bendAmount))

        for voice in voices {
            hub.mpeZoneManager?.setVoicePitchBend(voice: voice, bend: clampedBend)
        }

        // X-axis drag → brightness/timbre
        let brightness = Float(0.5 + translation.width / 400.0)
        let clampedBrightness = max(0.0, min(1.0, brightness))

        for voice in voices {
            hub.mpeZoneManager?.setVoiceBrightness(voice: voice, brightness: clampedBrightness)
        }
    }

    private func playChordSimultaneous(_ pad: ChordPad, velocity: Float, hub: TouchInstrumentsHub) {
        guard let mpe = hub.mpeZoneManager else { return }

        var voices: [MPEZoneManager.MPEVoice] = []

        for note in pad.notes {
            if let voice = mpe.allocateVoice(note: note, velocity: velocity) {
                voices.append(voice)
            }
        }

        activeVoices[pad.id] = voices
    }

    private func playChordStrummed(_ pad: ChordPad, velocity: Float, hub: TouchInstrumentsHub) {
        guard let mpe = hub.mpeZoneManager else { return }

        var voices: [MPEZoneManager.MPEVoice] = []
        let strumDelay = 0.03 // 30ms between notes

        for (index, note) in pad.notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * strumDelay) {
                if let voice = mpe.allocateVoice(note: note, velocity: velocity * (1.0 - Float(index) * 0.1)) {
                    voices.append(voice)
                    hub.triggerHaptic(intensity: 0.3, sharpness: 0.3)
                }
            }
        }

        activeVoices[pad.id] = voices
    }

    private var arpNoteIndex = 0
    private var currentArpPad: ChordPad?
    private var arpVelocity: Float = 0.8

    private func startArpeggio(_ pad: ChordPad, velocity: Float, hub: TouchInstrumentsHub) {
        currentArpPad = pad
        arpVelocity = velocity
        arpNoteIndex = 0

        let interval = 60.0 / arpRate // Convert BPM to seconds

        arpTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.playNextArpNote(hub: hub)
            }
        }

        // Play first note immediately
        playNextArpNote(hub: hub)
    }

    private func playNextArpNote(hub: TouchInstrumentsHub) {
        guard let pad = currentArpPad, let mpe = hub.mpeZoneManager else { return }

        // Release previous note
        if let voices = activeVoices[pad.id], !voices.isEmpty {
            for voice in voices {
                mpe.deallocateVoice(voice: voice)
            }
        }

        // Get next note based on pattern
        let notes = getArpNotes(pad.notes)
        let note = notes[arpNoteIndex % notes.count]

        if let voice = mpe.allocateVoice(note: note, velocity: arpVelocity) {
            activeVoices[pad.id] = [voice]
            hub.triggerHaptic(intensity: 0.2, sharpness: 0.4)
        }

        arpNoteIndex += 1
    }

    private func getArpNotes(_ notes: [UInt8]) -> [UInt8] {
        switch arpPattern {
        case .up:
            return notes.sorted()
        case .down:
            return notes.sorted().reversed()
        case .upDown:
            let sorted = notes.sorted()
            return sorted + sorted.dropFirst().dropLast().reversed()
        case .random:
            return notes.shuffled()
        }
    }

    private func stopArpeggio() {
        arpTimer?.invalidate()
        arpTimer = nil
        currentArpPad = nil
    }

    // MARK: - Deinit (Memory Leak Prevention)

    deinit {
        arpTimer?.invalidate()
    }
}

// MARK: - Arpeggiator Controls

struct ArpeggiatorControls: View {
    @ObservedObject var viewModel: ChordPadViewModel

    var body: some View {
        HStack(spacing: 20) {
            // Pattern
            Picker("Pattern", selection: $viewModel.arpPattern) {
                ForEach(ChordPadViewModel.ArpPattern.allCases, id: \.self) { pattern in
                    Text(pattern.rawValue).tag(pattern)
                }
            }
            .pickerStyle(.segmented)

            // Rate
            VStack {
                Text("Rate: \(Int(viewModel.arpRate)) BPM")
                    .font(.caption)
                Slider(value: $viewModel.arpRate, in: 60...240, step: 1)
            }
            .frame(width: 150)
        }
        .padding()
    }
}

// MARK: - Drum Pad View
/// 16-pad drum machine with velocity sensitivity and per-pad MPE

struct DrumPadView: View {

    @ObservedObject var hub: TouchInstrumentsHub
    @StateObject private var viewModel = DrumPadViewModel()

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Drum Pads")
                    .font(.headline)

                Spacer()

                // Kit selector
                Picker("Kit", selection: $viewModel.currentKit) {
                    ForEach(DrumKit.allCases, id: \.self) { kit in
                        Text(kit.rawValue).tag(kit)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)

            // 4x4 Drum Pads
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.pads) { pad in
                    DrumPadButton(
                        pad: pad,
                        isPressed: viewModel.pressedPads.contains(pad.id),
                        onPress: { pressure in
                            viewModel.padPressed(pad, pressure: pressure, hub: hub)
                        },
                        onRelease: {
                            viewModel.padReleased(pad, hub: hub)
                        }
                    )
                }
            }
            .padding()

            // Velocity curve
            HStack {
                Text("Velocity Curve")
                    .font(.caption)
                Picker("", selection: $viewModel.velocityCurve) {
                    ForEach(DrumPadViewModel.VelocityCurve.allCases, id: \.self) { curve in
                        Text(curve.rawValue).tag(curve)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Drum Pad Button

struct DrumPadButton: View {

    let pad: DrumPadModel
    let isPressed: Bool
    var onPress: (Float) -> Void
    var onRelease: () -> Void

    @State private var currentPressure: Float = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isPressed ? pad.color : pad.color.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(pad.color.opacity(0.8), lineWidth: 2)
                )

            VStack(spacing: 2) {
                Text(pad.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text("Note \(pad.midiNote)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(height: 70)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeOut(duration: 0.05), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isPressed {
                        // Calculate velocity from touch location (higher = harder)
                        let velocityFromY = Float(1.0 - value.startLocation.y / 70.0)
                        let velocity = max(0.3, min(1.0, velocityFromY))
                        currentPressure = velocity
                        onPress(velocity)
                    }
                }
                .onEnded { _ in
                    onRelease()
                }
        )
    }
}

// MARK: - Drum Pad Model

struct DrumPadModel: Identifiable {
    let id = UUID()
    var name: String
    var midiNote: UInt8
    var color: Color
}

enum DrumKit: String, CaseIterable {
    case acoustic = "Acoustic"
    case electronic = "Electronic"
    case tr808 = "808"
    case tr909 = "909"
    case hiphop = "Hip Hop"
    case percussion = "Percussion"

    var pads: [DrumPadModel] {
        switch self {
        case .acoustic:
            return [
                DrumPadModel(name: "Kick", midiNote: 36, color: .red),
                DrumPadModel(name: "Snare", midiNote: 38, color: .orange),
                DrumPadModel(name: "HiHat C", midiNote: 42, color: .yellow),
                DrumPadModel(name: "HiHat O", midiNote: 46, color: .yellow),
                DrumPadModel(name: "Tom Hi", midiNote: 50, color: .green),
                DrumPadModel(name: "Tom Mid", midiNote: 47, color: .green),
                DrumPadModel(name: "Tom Lo", midiNote: 45, color: .green),
                DrumPadModel(name: "Crash", midiNote: 49, color: .cyan),
                DrumPadModel(name: "Ride", midiNote: 51, color: .blue),
                DrumPadModel(name: "Ride B", midiNote: 53, color: .blue),
                DrumPadModel(name: "Clap", midiNote: 39, color: .purple),
                DrumPadModel(name: "Rim", midiNote: 37, color: .pink),
                DrumPadModel(name: "Cowbell", midiNote: 56, color: .brown),
                DrumPadModel(name: "Tamb", midiNote: 54, color: .brown),
                DrumPadModel(name: "Shaker", midiNote: 70, color: .brown),
                DrumPadModel(name: "Perc", midiNote: 75, color: .gray)
            ]
        case .tr808, .tr909, .electronic, .hiphop, .percussion:
            // Similar structure, different note mappings
            return DrumKit.acoustic.pads // Placeholder
        }
    }
}

// MARK: - Drum Pad View Model

@MainActor
class DrumPadViewModel: ObservableObject {

    @Published var pads: [DrumPadModel] = []
    @Published var pressedPads: Set<UUID> = []
    @Published var currentKit: DrumKit = .acoustic {
        didSet {
            pads = currentKit.pads
        }
    }
    @Published var velocityCurve: VelocityCurve = .linear

    enum VelocityCurve: String, CaseIterable {
        case soft = "Soft"
        case linear = "Linear"
        case hard = "Hard"
        case fixed = "Fixed"

        func apply(_ input: Float) -> Float {
            switch self {
            case .soft: return pow(input, 0.5)
            case .linear: return input
            case .hard: return pow(input, 2.0)
            case .fixed: return 0.9
            }
        }
    }

    init() {
        pads = currentKit.pads
    }

    func padPressed(_ pad: DrumPadModel, pressure: Float, hub: TouchInstrumentsHub) {
        pressedPads.insert(pad.id)

        let velocity = velocityCurve.apply(pressure)
        hub.triggerHaptic(intensity: velocity, sharpness: 0.8)

        // For drums, we use MIDI 2.0 directly (not MPE - drums are typically on channel 10)
        hub.midi2Manager?.sendNoteOn(channel: 9, note: pad.midiNote, velocity: velocity)
    }

    func padReleased(_ pad: DrumPadModel, hub: TouchInstrumentsHub) {
        pressedPads.remove(pad.id)
        hub.midi2Manager?.sendNoteOff(channel: 9, note: pad.midiNote)
    }
}

// MARK: - Melody Pad View (XY Pad)
/// XY-style pad for melodic playing with scale quantization

struct MelodyPadView: View {

    @ObservedObject var hub: TouchInstrumentsHub
    @StateObject private var viewModel = MelodyPadViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Melody XY")
                    .font(.headline)

                Spacer()

                // Scale
                Picker("Scale", selection: $hub.currentScale) {
                    ForEach(MusicalScale.allCases, id: \.self) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
                .pickerStyle(.menu)

                // Octave range
                Stepper("Oct: \(viewModel.octaveRange)", value: $viewModel.octaveRange, in: 1...4)
            }
            .padding(.horizontal)

            // XY Pad
            GeometryReader { geometry in
                ZStack {
                    // Background grid
                    MelodyGridBackground(
                        scale: hub.currentScale,
                        root: hub.rootNote,
                        octaveRange: viewModel.octaveRange
                    )

                    // Touch visualization
                    ForEach(Array(viewModel.activeTouches.keys), id: \.self) { touchId in
                        if let touch = viewModel.activeTouches[touchId] {
                            Circle()
                                .fill(Color.blue.opacity(0.6))
                                .frame(width: 60, height: 60)
                                .position(touch.location)
                        }
                    }
                }
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.handleTouch(
                                location: value.location,
                                size: geometry.size,
                                hub: hub
                            )
                        }
                        .onEnded { _ in
                            viewModel.endAllTouches(hub: hub)
                        }
                )
            }
            .frame(height: 300)
            .padding()

            // Glide control
            HStack {
                Text("Glide")
                Toggle("", isOn: $viewModel.glideEnabled)

                if viewModel.glideEnabled {
                    Slider(value: $viewModel.glideTime, in: 0...1)
                        .frame(width: 100)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Melody Grid Background

struct MelodyGridBackground: View {
    let scale: MusicalScale
    let root: UInt8
    let octaveRange: Int

    var body: some View {
        GeometryReader { geometry in
            let totalNotes = scale.intervals.count * octaveRange
            let noteWidth = geometry.size.width / CGFloat(totalNotes)

            HStack(spacing: 0) {
                ForEach(0..<totalNotes, id: \.self) { index in
                    Rectangle()
                        .fill(index % scale.intervals.count == 0 ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: noteWidth)
                        .overlay(
                            Rectangle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                }
            }
        }
    }
}

// MARK: - Melody Pad View Model

@MainActor
class MelodyPadViewModel: ObservableObject {

    struct TouchInfo {
        var location: CGPoint
        var note: UInt8
        var voice: MPEZoneManager.MPEVoice?
    }

    @Published var activeTouches: [Int: TouchInfo] = [:]
    @Published var octaveRange: Int = 2
    @Published var glideEnabled: Bool = false
    @Published var glideTime: Double = 0.3

    private var lastNote: UInt8?

    func handleTouch(location: CGPoint, size: CGSize, hub: TouchInstrumentsHub) {
        // X = note (pitch), Y = expression (pitch bend / brightness)
        let normalizedX = Float(location.x / size.width)
        let normalizedY = Float(location.y / size.height)

        // Calculate note from X position
        let totalNotes = hub.currentScale.intervals.count * octaveRange
        let noteIndex = Int(normalizedX * Float(totalNotes))
        let note = hub.currentScale.noteInScale(degree: noteIndex, root: hub.rootNote)

        // Y controls brightness (top = bright, bottom = dark)
        let brightness = 1.0 - normalizedY

        let touchId = 0 // Single touch for now

        if let existingTouch = activeTouches[touchId] {
            // Update existing touch
            var updatedTouch = existingTouch
            updatedTouch.location = location

            // If note changed and glide is enabled
            if note != existingTouch.note {
                if glideEnabled, let voice = existingTouch.voice {
                    // Use pitch bend for glide
                    let semitones = Int(note) - Int(existingTouch.note)
                    let bendAmount = Float(semitones) / 48.0 // Assuming ±48 semitone range
                    hub.mpeZoneManager?.setVoicePitchBend(voice: voice, bend: max(-1, min(1, bendAmount)))
                } else {
                    // Retrigger note
                    if let voice = existingTouch.voice {
                        hub.mpeZoneManager?.deallocateVoice(voice: voice)
                    }
                    if let newVoice = hub.mpeZoneManager?.allocateVoice(note: note, velocity: 0.8) {
                        updatedTouch.voice = newVoice
                        updatedTouch.note = note
                        hub.triggerHaptic(intensity: 0.3, sharpness: 0.5)
                    }
                }
            }

            // Update brightness
            if let voice = updatedTouch.voice {
                hub.mpeZoneManager?.setVoiceBrightness(voice: voice, brightness: brightness)
            }

            activeTouches[touchId] = updatedTouch

        } else {
            // New touch
            if let voice = hub.mpeZoneManager?.allocateVoice(note: note, velocity: 0.8) {
                hub.mpeZoneManager?.setVoiceBrightness(voice: voice, brightness: brightness)

                activeTouches[touchId] = TouchInfo(
                    location: location,
                    note: note,
                    voice: voice
                )

                hub.triggerHaptic(intensity: 0.5, sharpness: 0.6)
            }
        }

        lastNote = note
    }

    func endAllTouches(hub: TouchInstrumentsHub) {
        for (_, touch) in activeTouches {
            if let voice = touch.voice {
                hub.mpeZoneManager?.deallocateVoice(voice: voice)
            }
        }
        activeTouches.removeAll()
        lastNote = nil
    }
}

// MARK: - Touch Keyboard View
/// Simple piano keyboard with MPE expression

struct TouchKeyboardView: View {

    @ObservedObject var hub: TouchInstrumentsHub
    @StateObject private var viewModel = TouchKeyboardViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Keyboard")
                    .font(.headline)

                Spacer()

                // Octave controls
                HStack {
                    Button("-") { viewModel.octave = max(0, viewModel.octave - 1) }
                        .buttonStyle(.bordered)
                    Text("Oct \(viewModel.octave)")
                    Button("+") { viewModel.octave = min(8, viewModel.octave + 1) }
                        .buttonStyle(.bordered)
                }

                // Key width
                Picker("Size", selection: $viewModel.keyWidth) {
                    Text("S").tag(40.0)
                    Text("M").tag(55.0)
                    Text("L").tag(70.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            .padding(.horizontal)

            // Keyboard
            ScrollView(.horizontal, showsIndicators: false) {
                PianoKeyboardLayout(
                    viewModel: viewModel,
                    hub: hub
                )
            }
            .frame(height: 180)
        }
    }
}

// MARK: - Piano Keyboard Layout

struct PianoKeyboardLayout: View {

    @ObservedObject var viewModel: TouchKeyboardViewModel
    @ObservedObject var hub: TouchInstrumentsHub

    var body: some View {
        HStack(spacing: 1) {
            ForEach(viewModel.visibleNotes, id: \.self) { note in
                PianoKey(
                    note: note,
                    isBlack: isBlackKey(note),
                    isPressed: viewModel.pressedNotes.contains(note),
                    width: viewModel.keyWidth,
                    onPress: { pressure in
                        viewModel.keyPressed(note, pressure: pressure, hub: hub)
                    },
                    onRelease: {
                        viewModel.keyReleased(note, hub: hub)
                    },
                    onDrag: { translation in
                        viewModel.keyDragged(note, translation: translation, hub: hub)
                    }
                )
            }
        }
        .padding(.horizontal)
    }

    private func isBlackKey(_ note: UInt8) -> Bool {
        let noteInOctave = Int(note) % 12
        return [1, 3, 6, 8, 10].contains(noteInOctave)
    }
}

// MARK: - Piano Key

struct PianoKey: View {

    let note: UInt8
    let isBlack: Bool
    let isPressed: Bool
    let width: Double
    var onPress: (Float) -> Void
    var onRelease: () -> Void
    var onDrag: (CGSize) -> Void

    var body: some View {
        ZStack(alignment: isBlack ? .top : .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .fill(keyColor)
                .frame(width: isBlack ? width * 0.6 : width, height: isBlack ? 100 : 160)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )

            // Note name
            if !isBlack {
                Text(noteName)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.bottom, 4)
            }
        }
        .zIndex(isBlack ? 1 : 0)
        .offset(x: isBlack ? -width * 0.3 : 0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if value.translation == .zero {
                        onPress(0.8)
                    } else {
                        onDrag(value.translation)
                    }
                }
                .onEnded { _ in
                    onRelease()
                }
        )
    }

    private var keyColor: Color {
        if isPressed {
            return isBlack ? .blue : .blue.opacity(0.7)
        }
        return isBlack ? .black : .white
    }

    private var noteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return noteNames[Int(note) % 12]
    }
}

// MARK: - Touch Keyboard View Model

@MainActor
class TouchKeyboardViewModel: ObservableObject {

    @Published var octave: Int = 4
    @Published var keyWidth: Double = 55
    @Published var pressedNotes: Set<UInt8> = []

    private var activeVoices: [UInt8: MPEZoneManager.MPEVoice] = [:]

    var visibleNotes: [UInt8] {
        let startNote = UInt8(octave * 12)
        let endNote = min(127, startNote + 24) // 2 octaves
        return Array(startNote..<endNote)
    }

    func keyPressed(_ note: UInt8, pressure: Float, hub: TouchInstrumentsHub) {
        guard !pressedNotes.contains(note) else { return }

        pressedNotes.insert(note)
        hub.triggerHaptic(intensity: pressure * 0.7, sharpness: 0.5)

        if let voice = hub.mpeZoneManager?.allocateVoice(note: note, velocity: pressure) {
            activeVoices[note] = voice
        }
    }

    func keyReleased(_ note: UInt8, hub: TouchInstrumentsHub) {
        pressedNotes.remove(note)

        if let voice = activeVoices[note] {
            hub.mpeZoneManager?.deallocateVoice(voice: voice)
            activeVoices.removeValue(forKey: note)
        }
    }

    func keyDragged(_ note: UInt8, translation: CGSize, hub: TouchInstrumentsHub) {
        guard let voice = activeVoices[note] else { return }

        // Y-axis → pitch bend
        let bendAmount = Float(translation.height / -150.0)
        let clampedBend = max(-1.0, min(1.0, bendAmount))
        hub.mpeZoneManager?.setVoicePitchBend(voice: voice, bend: clampedBend)

        // Pressure simulation from X movement
        let pressure = Float(0.5 + translation.width / 200.0)
        let clampedPressure = max(0.0, min(1.0, pressure))
        hub.mpeZoneManager?.setVoicePressure(voice: voice, pressure: clampedPressure)
    }
}

// MARK: - Extension for TouchInstrumentsHub

extension TouchInstrumentsHub {
    var mpeZoneManager: MPEZoneManager? {
        // Access would need to be passed through
        return nil // This is set via connect()
    }

    var midi2Manager: MIDI2Manager? {
        return nil // This is set via connect()
    }
}
