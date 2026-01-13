import Foundation
import SwiftUI
import Combine
import CoreHaptics
import AVFoundation

// MARK: - Touch Instruments Module
/// Professional touch instrument interfaces for mobile platforms
/// Supports MIDI output, audio engine connection, and haptic feedback
/// Optimized for iPhone and iPad touch interaction

// MARK: - Musical Types

/// Extended musical scale definitions with 18 supported scales
enum TouchScale: String, CaseIterable, Identifiable {
    case major = "Major"
    case minor = "Minor"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case aeolian = "Aeolian"
    case locrian = "Locrian"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case wholeTone = "Whole Tone"
    case blues = "Blues"
    case chromatic = "Chromatic"
    case hungarianMinor = "Hungarian Minor"
    case japanese = "Japanese"
    case arabic = "Arabic"

    var id: String { rawValue }

    var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .aeolian: return [0, 2, 3, 5, 7, 8, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .wholeTone: return [0, 2, 4, 6, 8, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .chromatic: return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .hungarianMinor: return [0, 2, 3, 6, 7, 8, 11]
        case .japanese: return [0, 1, 5, 7, 8]
        case .arabic: return [0, 1, 4, 5, 7, 8, 11]
        }
    }

    func noteInScale(degree: Int, root: UInt8) -> UInt8 {
        let octaveOffset = degree / intervals.count
        let scaleIndex = ((degree % intervals.count) + intervals.count) % intervals.count
        let note = Int(root) + (octaveOffset * 12) + intervals[scaleIndex]
        return UInt8(max(0, min(127, note)))
    }

    func isNoteInScale(_ note: UInt8, root: UInt8) -> Bool {
        let noteClass = (Int(note) - Int(root) + 120) % 12
        return intervals.contains(noteClass)
    }
}

/// Extended chord type definitions with 11 chord types
enum TouchChordType: String, CaseIterable, Identifiable {
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

    var id: String { rawValue }

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

    var symbol: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "dim"
        case .augmented: return "aug"
        case .major7: return "maj7"
        case .minor7: return "m7"
        case .dominant7: return "7"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        case .add9: return "add9"
        case .power: return "5"
        }
    }
}

/// 16 drum sound types
enum TouchDrumSound: String, CaseIterable, Identifiable {
    case kick = "Kick"
    case snare = "Snare"
    case clap = "Clap"
    case hiHatClosed = "HH Closed"
    case hiHatOpen = "HH Open"
    case tomHigh = "Tom Hi"
    case tomMid = "Tom Mid"
    case tomLow = "Tom Lo"
    case crash = "Crash"
    case ride = "Ride"
    case rimshot = "Rimshot"
    case cowbell = "Cowbell"
    case shaker = "Shaker"
    case conga = "Conga"
    case bongo = "Bongo"
    case tambourine = "Tamb"

    var id: String { rawValue }

    var midiNote: UInt8 {
        switch self {
        case .kick: return 36
        case .snare: return 38
        case .clap: return 39
        case .hiHatClosed: return 42
        case .hiHatOpen: return 46
        case .tomHigh: return 50
        case .tomMid: return 47
        case .tomLow: return 45
        case .crash: return 49
        case .ride: return 51
        case .rimshot: return 37
        case .cowbell: return 56
        case .shaker: return 70
        case .conga: return 63
        case .bongo: return 61
        case .tambourine: return 54
        }
    }

    var color: Color {
        switch self {
        case .kick: return .red
        case .snare: return .orange
        case .clap: return .purple
        case .hiHatClosed, .hiHatOpen: return .yellow
        case .tomHigh, .tomMid, .tomLow: return .green
        case .crash, .ride: return .cyan
        case .rimshot: return .pink
        case .cowbell: return .brown
        case .shaker, .tambourine: return .mint
        case .conga, .bongo: return .teal
        }
    }

    /// Mute group - instruments in the same group choke each other
    var muteGroup: Int? {
        switch self {
        case .hiHatClosed, .hiHatOpen: return 1  // Hi-hats choke each other
        case .crash: return 2
        default: return nil
        }
    }
}

// MARK: - Touch Instrument Engine

/// Central engine managing all touch instruments
@MainActor
class TouchInstrumentEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentScale: TouchScale = .major
    @Published var rootNote: UInt8 = 60  // Middle C
    @Published var octave: Int = 4
    @Published var velocity: Float = 0.8
    @Published var isHapticEnabled: Bool = true

    // MARK: - Audio Connection

    weak var audioEngine: AudioEngine?
    private var hapticEngine: CHHapticEngine?

    // MARK: - Active Notes

    private var activeNotes: [UInt8: Date] = [:]
    private var activeDrums: [TouchDrumSound: Date] = [:]

    // MARK: - MIDI Output

    var onNoteOn: ((UInt8, Float) -> Void)?
    var onNoteOff: ((UInt8) -> Void)?
    var onControlChange: ((UInt8, UInt8) -> Void)?

    // MARK: - Initialization

    init() {
        setupHaptics()
    }

    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            log.audio("TouchInstrumentEngine: Haptics unavailable")
        }
    }

    // MARK: - Note Control

    func noteOn(_ note: UInt8, velocity: Float) {
        activeNotes[note] = Date()
        onNoteOn?(note, velocity)

        // Trigger haptic feedback
        if isHapticEnabled {
            triggerHaptic(intensity: velocity, sharpness: 0.5)
        }

        // Connect to InstrumentOrchestrator
        Task { @MainActor in
            InstrumentOrchestrator.shared.noteOn(midiNote: Int(note), velocity: velocity)
        }
    }

    func noteOff(_ note: UInt8) {
        activeNotes.removeValue(forKey: note)
        onNoteOff?(note)

        Task { @MainActor in
            InstrumentOrchestrator.shared.noteOff(midiNote: Int(note))
        }
    }

    func allNotesOff() {
        for note in activeNotes.keys {
            noteOff(note)
        }
        activeNotes.removeAll()

        Task { @MainActor in
            InstrumentOrchestrator.shared.allNotesOff()
        }
    }

    // MARK: - Drum Control

    func triggerDrum(_ sound: TouchDrumSound, velocity: Float) {
        // Check mute groups - choke other sounds in same group
        if let muteGroup = sound.muteGroup {
            for (activeSound, _) in activeDrums {
                if activeSound.muteGroup == muteGroup && activeSound != sound {
                    activeDrums.removeValue(forKey: activeSound)
                    // Send note off for choked sound
                    onNoteOff?(activeSound.midiNote)
                }
            }
        }

        activeDrums[sound] = Date()

        // Send MIDI note on channel 10 (drums)
        onNoteOn?(sound.midiNote, velocity)

        if isHapticEnabled {
            triggerHaptic(intensity: velocity * 0.8, sharpness: 0.8)
        }

        // Map to InstrumentOrchestrator drum type
        let drumType: InstrumentOrchestrator.DrumType
        switch sound {
        case .kick: drumType = .kick
        case .snare: drumType = .snare
        case .clap: drumType = .clap
        case .hiHatClosed: drumType = .hiHatClosed
        case .hiHatOpen: drumType = .hiHatOpen
        case .tomHigh: drumType = .tomHigh
        case .tomMid: drumType = .tomMid
        case .tomLow: drumType = .tomLow
        case .crash: drumType = .crash
        case .ride: drumType = .ride
        case .rimshot: drumType = .rimShot
        case .cowbell: drumType = .cowbell
        default: drumType = .snare
        }

        Task { @MainActor in
            InstrumentOrchestrator.shared.triggerDrum(drumType, velocity: velocity)
        }
    }

    func releaseDrum(_ sound: TouchDrumSound) {
        activeDrums.removeValue(forKey: sound)
        onNoteOff?(sound.midiNote)
    }

    // MARK: - Chord Control

    func playChord(root: UInt8, type: TouchChordType, velocity: Float) {
        let notes = type.notes(root: root)
        for note in notes {
            noteOn(note, velocity: velocity)
        }
    }

    func releaseChord(root: UInt8, type: TouchChordType) {
        let notes = type.notes(root: root)
        for note in notes {
            noteOff(note)
        }
    }

    func strumChord(root: UInt8, type: TouchChordType, velocity: Float, strumDown: Bool, speed: TimeInterval = 0.03) {
        let notes = type.notes(root: root)
        let orderedNotes = strumDown ? notes : notes.reversed()

        for (index, note) in orderedNotes.enumerated() {
            let delay = TimeInterval(index) * speed
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                let velocityVariation = velocity * (1.0 - Float(index) * 0.05)
                self?.noteOn(note, velocity: velocityVariation)
                self?.triggerHaptic(intensity: 0.2, sharpness: 0.3)
            }
        }
    }

    // MARK: - Haptic Feedback

    func triggerHaptic(intensity: Float, sharpness: Float) {
        guard isHapticEnabled, let engine = hapticEngine else { return }

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

    func triggerContinuousHaptic(intensity: Float, duration: TimeInterval) {
        guard isHapticEnabled, let engine = hapticEngine else { return }

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0,
            duration: duration
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptic failed silently
        }
    }

    // MARK: - Utility

    static func noteNameFromMIDI(_ note: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let noteName = noteNames[Int(note) % 12]
        return "\(noteName)\(octave)"
    }

    static func midiNoteToFrequency(_ note: UInt8) -> Float {
        return 440.0 * pow(2.0, Float(Int(note) - 69) / 12.0)
    }
}

// MARK: - 1. ChordPad View

/// 4x4 grid of chord pads with scale lock, strum mode, and visual feedback
struct ChordPadView: View {

    @ObservedObject var engine: TouchInstrumentEngine
    @StateObject private var viewModel = ChordPadViewModel()

    var body: some View {
        VStack(spacing: 12) {
            // Header controls
            ChordPadHeader(engine: engine, viewModel: viewModel)

            // Chord type selector
            ChordTypeSelector(viewModel: viewModel)

            // 4x4 Chord Pad Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(viewModel.chordPads) { pad in
                    ChordPadButton(
                        pad: pad,
                        isPressed: viewModel.pressedPads.contains(pad.id),
                        isHighlighted: engine.currentScale.isNoteInScale(pad.rootNote, root: engine.rootNote),
                        onPress: { location, force in
                            viewModel.padPressed(pad, location: location, force: force, engine: engine)
                        },
                        onRelease: {
                            viewModel.padReleased(pad, engine: engine)
                        },
                        onDrag: { translation, velocity in
                            viewModel.padDragged(pad, translation: translation, velocity: velocity, engine: engine)
                        }
                    )
                }
            }
            .padding(.horizontal)

            // Mode controls
            ChordPadModeControls(viewModel: viewModel)
        }
        .onAppear {
            viewModel.updatePadsForScale(engine.currentScale, root: engine.rootNote)
        }
        .onChange(of: engine.currentScale) { newScale in
            viewModel.updatePadsForScale(newScale, root: engine.rootNote)
        }
        .onChange(of: engine.rootNote) { newRoot in
            viewModel.updatePadsForScale(engine.currentScale, root: newRoot)
        }
    }
}

struct ChordPadHeader: View {
    @ObservedObject var engine: TouchInstrumentEngine
    @ObservedObject var viewModel: ChordPadViewModel

    var body: some View {
        HStack {
            Text("Chord Pad")
                .font(.headline)

            Spacer()

            // Scale selector
            Picker("Scale", selection: $engine.currentScale) {
                ForEach(TouchScale.allCases) { scale in
                    Text(scale.rawValue).tag(scale)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)

            // Root note
            Picker("Root", selection: $engine.rootNote) {
                ForEach(48...72, id: \.self) { note in
                    Text(TouchInstrumentEngine.noteNameFromMIDI(UInt8(note))).tag(UInt8(note))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
        }
        .padding(.horizontal)
    }
}

struct ChordTypeSelector: View {
    @ObservedObject var viewModel: ChordPadViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TouchChordType.allCases) { chordType in
                    Button(chordType.rawValue) {
                        viewModel.selectedChordType = chordType
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.selectedChordType == chordType ? .blue : .gray)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ChordPadModeControls: View {
    @ObservedObject var viewModel: ChordPadViewModel

    var body: some View {
        HStack(spacing: 20) {
            // Play mode
            Picker("Mode", selection: $viewModel.playMode) {
                ForEach(ChordPadViewModel.PlayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Strum speed (only in strum mode)
            if viewModel.playMode == .strum {
                VStack(spacing: 2) {
                    Text("Strum: \(Int(viewModel.strumSpeed * 100))%")
                        .font(.caption)
                    Slider(value: $viewModel.strumSpeed, in: 0.1...1.0)
                        .frame(width: 100)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Chord Pad Button

struct ChordPadButton: View {
    let pad: ChordPadModel
    let isPressed: Bool
    let isHighlighted: Bool
    var onPress: (CGPoint, Float) -> Void
    var onRelease: () -> Void
    var onDrag: (CGSize, CGFloat) -> Void

    @State private var lastDragLocation: CGPoint = .zero
    @State private var glowAmount: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with glow effect
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                padColor.opacity(isPressed ? 0.9 : 0.5),
                                padColor.opacity(isPressed ? 0.7 : 0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isHighlighted ? Color.white : padColor,
                                lineWidth: isHighlighted ? 3 : 2
                            )
                    )
                    .shadow(color: padColor.opacity(isPressed ? 0.8 : 0), radius: 10)

                // Chord label
                VStack(spacing: 2) {
                    Text(pad.chordName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(pad.chordType.symbol)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if lastDragLocation == .zero {
                            // Initial press - calculate force from vertical position
                            let normalizedY = Float(value.startLocation.y / geometry.size.height)
                            let force = max(0.3, min(1.0, 1.0 - normalizedY))
                            onPress(value.startLocation, force)
                        } else {
                            // Dragging - calculate velocity
                            let velocity = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                            onDrag(value.translation, velocity)
                        }
                        lastDragLocation = value.location
                    }
                    .onEnded { _ in
                        lastDragLocation = .zero
                        onRelease()
                    }
            )
        }
        .frame(height: 75)
    }

    private var padColor: Color {
        pad.color
    }
}

// MARK: - Chord Pad Model

struct ChordPadModel: Identifiable {
    let id = UUID()
    var rootNote: UInt8
    var chordType: TouchChordType
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

    @Published var chordPads: [ChordPadModel] = []
    @Published var pressedPads: Set<UUID> = []
    @Published var selectedChordType: TouchChordType = .major
    @Published var playMode: PlayMode = .chord
    @Published var strumSpeed: Double = 0.5

    private var strumStartLocation: CGPoint?
    private var strumDirection: Bool = true  // true = down, false = up

    enum PlayMode: String, CaseIterable {
        case chord = "Chord"
        case strum = "Strum"
        case arpeggio = "Arp"
    }

    init() {
        setupDefaultPads()
    }

    private func setupDefaultPads() {
        // Default 4x4 grid with common chord progression patterns
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .red, .cyan, .yellow,
                               .indigo, .mint, .teal, .brown, .gray, .blue, .purple, .pink]

        // I-ii-iii-IV-V-vi-vii-I progression notes
        let progressionNotes: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72,  // C to C
                                          55, 57, 59, 60, 62, 64, 65, 67]  // Lower octave
        let chordTypes: [TouchChordType] = [.major, .minor, .minor, .major, .major, .minor, .diminished, .major,
                                              .major, .minor, .minor, .major, .major, .minor, .diminished, .major]

        chordPads = zip(zip(progressionNotes, chordTypes), colors).map { (noteType, color) in
            ChordPadModel(rootNote: noteType.0, chordType: noteType.1, color: color)
        }
    }

    func updatePadsForScale(_ scale: TouchScale, root: UInt8) {
        // Update chord pads based on scale
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .red, .cyan, .yellow,
                               .indigo, .mint, .teal, .brown, .gray, .blue, .purple, .pink]

        chordPads = (0..<16).map { index in
            let degree = index % 7
            let octaveOffset = index / 7
            let note = scale.noteInScale(degree: degree, root: root + UInt8(octaveOffset * 12))

            // Determine chord type based on scale degree
            let chordType: TouchChordType
            switch degree {
            case 0, 3, 4: chordType = .major
            case 1, 2, 5: chordType = .minor
            case 6: chordType = .diminished
            default: chordType = .major
            }

            return ChordPadModel(rootNote: note, chordType: chordType, color: colors[index])
        }
    }

    func padPressed(_ pad: ChordPadModel, location: CGPoint, force: Float, engine: TouchInstrumentEngine) {
        pressedPads.insert(pad.id)

        switch playMode {
        case .chord:
            engine.playChord(root: pad.rootNote, type: selectedChordType, velocity: force)
        case .strum:
            strumStartLocation = location
        case .arpeggio:
            // Start arpeggio playback
            playArpeggio(pad: pad, velocity: force, engine: engine)
        }
    }

    func padReleased(_ pad: ChordPadModel, engine: TouchInstrumentEngine) {
        pressedPads.remove(pad.id)
        engine.releaseChord(root: pad.rootNote, type: selectedChordType)
        strumStartLocation = nil
    }

    func padDragged(_ pad: ChordPadModel, translation: CGSize, velocity: CGFloat, engine: TouchInstrumentEngine) {
        guard playMode == .strum else { return }

        // Detect strum direction from horizontal movement
        let strumThreshold: CGFloat = 20
        if abs(translation.width) > strumThreshold {
            let strumDown = translation.width > 0
            if strumDown != strumDirection {
                strumDirection = strumDown

                // Trigger strum
                let strumVelocity = min(1.0, Float(velocity / 500))
                let strumDelay = (1.0 - strumSpeed) * 0.05
                engine.strumChord(root: pad.rootNote, type: selectedChordType, velocity: strumVelocity, strumDown: strumDown, speed: strumDelay)
            }
        }
    }

    private var arpeggioTimer: Timer?
    private var arpeggioIndex = 0

    private func playArpeggio(pad: ChordPadModel, velocity: Float, engine: TouchInstrumentEngine) {
        arpeggioIndex = 0
        arpeggioTimer?.invalidate()

        let notes = selectedChordType.notes(root: pad.rootNote)
        let interval = 0.15  // 150ms between notes

        arpeggioTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self, self.pressedPads.contains(pad.id) else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                let noteIndex = self.arpeggioIndex % notes.count
                engine.noteOn(notes[noteIndex], velocity: velocity * 0.8)

                // Release previous note
                if self.arpeggioIndex > 0 {
                    let prevIndex = (self.arpeggioIndex - 1) % notes.count
                    engine.noteOff(notes[prevIndex])
                }

                self.arpeggioIndex += 1
            }
        }

        // Play first note immediately
        Task { @MainActor in
            engine.noteOn(notes[0], velocity: velocity)
        }
    }
}

// MARK: - 2. DrumPad View

/// 4x4 grid of drum pads with velocity sensitivity, mute groups, and visual feedback
struct DrumPadView: View {

    @ObservedObject var engine: TouchInstrumentEngine
    @StateObject private var viewModel = DrumPadViewModel()

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Drum Pads")
                    .font(.headline)

                Spacer()

                // Sustain/Choke toggle
                Toggle("Sustain", isOn: $viewModel.sustainMode)
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                // Velocity curve
                Picker("Velocity", selection: $viewModel.velocityCurve) {
                    ForEach(DrumPadViewModel.VelocityCurve.allCases, id: \.self) { curve in
                        Text(curve.rawValue).tag(curve)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal)

            // 4x4 Drum Pad Grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.drumPads) { pad in
                    DrumPadButton(
                        pad: pad,
                        isPressed: viewModel.pressedPads.contains(pad.id),
                        hitIntensity: viewModel.hitIntensities[pad.id] ?? 0,
                        onPress: { force in
                            viewModel.padPressed(pad, force: force, engine: engine)
                        },
                        onRelease: {
                            viewModel.padReleased(pad, engine: engine)
                        }
                    )
                }
            }
            .padding(.horizontal)

            // Mute group indicators
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Circle().fill(Color.yellow).frame(width: 10, height: 10)
                    Text("Hi-Hat Group")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Circle().fill(Color.cyan).frame(width: 10, height: 10)
                    Text("Cymbal Group")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
    }
}

struct DrumPadButton: View {
    let pad: DrumPadModel
    let isPressed: Bool
    let hitIntensity: CGFloat
    var onPress: (Float) -> Void
    var onRelease: () -> Void

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hit ripple effect
                if hitIntensity > 0 {
                    Circle()
                        .stroke(pad.sound.color.opacity(Double(1 - hitIntensity)), lineWidth: 2)
                        .scaleEffect(1 + hitIntensity * 0.5)
                }

                // Main pad
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        RadialGradient(
                            colors: [
                                pad.sound.color.opacity(isPressed ? 1.0 : 0.6),
                                pad.sound.color.opacity(isPressed ? 0.8 : 0.3)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.width / 2
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(pad.sound.color, lineWidth: 2)
                    )

                // Label
                VStack(spacing: 2) {
                    Text(pad.sound.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    if let muteGroup = pad.sound.muteGroup {
                        Circle()
                            .fill(muteGroup == 1 ? Color.yellow : Color.cyan)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.05), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressed {
                            // Calculate velocity from vertical touch position
                            let normalizedY = Float(value.startLocation.y / geometry.size.height)
                            let velocity = max(0.3, min(1.0, 1.0 - normalizedY))
                            onPress(velocity)
                        }
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
        }
        .frame(height: 70)
    }
}

struct DrumPadModel: Identifiable {
    let id = UUID()
    let sound: TouchDrumSound
}

@MainActor
class DrumPadViewModel: ObservableObject {

    @Published var drumPads: [DrumPadModel] = []
    @Published var pressedPads: Set<UUID> = []
    @Published var hitIntensities: [UUID: CGFloat] = [:]
    @Published var velocityCurve: VelocityCurve = .linear
    @Published var sustainMode: Bool = false

    private var sustainedPads: Set<UUID> = []

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
        setupDrumPads()
    }

    private func setupDrumPads() {
        // 4x4 grid of all 16 drum sounds
        drumPads = TouchDrumSound.allCases.map { DrumPadModel(sound: $0) }
    }

    func padPressed(_ pad: DrumPadModel, force: Float, engine: TouchInstrumentEngine) {
        pressedPads.insert(pad.id)

        let velocity = velocityCurve.apply(force)
        engine.triggerDrum(pad.sound, velocity: velocity)

        // Animate hit intensity
        withAnimation(.easeOut(duration: 0.3)) {
            hitIntensities[pad.id] = CGFloat(velocity)
        }

        // Reset hit intensity
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.hitIntensities[pad.id] = 0
            }
        }

        // Handle sustain mode
        if sustainMode {
            if sustainedPads.contains(pad.id) {
                // Release if already sustained
                sustainedPads.remove(pad.id)
            } else {
                sustainedPads.insert(pad.id)
            }
        }
    }

    func padReleased(_ pad: DrumPadModel, engine: TouchInstrumentEngine) {
        pressedPads.remove(pad.id)

        // Only release if not in sustain mode or not sustained
        if !sustainMode || !sustainedPads.contains(pad.id) {
            engine.releaseDrum(pad.sound)
        }
    }
}

// MARK: - 3. MelodyXY View

/// Continuous X/Y control for pitch and timbre
struct MelodyXYView: View {

    @ObservedObject var engine: TouchInstrumentEngine
    @StateObject private var viewModel = MelodyXYViewModel()

    var body: some View {
        VStack(spacing: 12) {
            // Header controls
            HStack {
                Text("Melody XY")
                    .font(.headline)

                Spacer()

                // Scale
                Picker("Scale", selection: $engine.currentScale) {
                    ForEach(TouchScale.allCases) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                // Octave range
                Stepper("Range: \(viewModel.octaveRange) oct", value: $viewModel.octaveRange, in: 1...4)
            }
            .padding(.horizontal)

            // Mode controls
            HStack(spacing: 16) {
                Toggle("Quantize", isOn: $viewModel.quantizeToScale)
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                Toggle("Ribbon", isOn: $viewModel.ribbonMode)
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                Picker("Y-Axis", selection: $viewModel.yAxisMode) {
                    Text("Filter").tag(MelodyXYViewModel.YAxisMode.filter)
                    Text("Timbre").tag(MelodyXYViewModel.YAxisMode.timbre)
                    Text("Volume").tag(MelodyXYViewModel.YAxisMode.volume)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal)

            // XY Pad
            GeometryReader { geometry in
                ZStack {
                    // Background grid showing scale notes
                    MelodyXYGrid(
                        scale: engine.currentScale,
                        root: engine.rootNote,
                        octaveRange: viewModel.octaveRange,
                        quantize: viewModel.quantizeToScale
                    )

                    // Pitch bend zones (left/right edges)
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: geometry.size.width * 0.1)
                        Spacer()
                        Rectangle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: geometry.size.width * 0.1)
                    }

                    // Touch points
                    ForEach(Array(viewModel.activeTouches.values), id: \.id) { touch in
                        MelodyXYTouchIndicator(touch: touch)
                    }

                    // Current note indicator
                    if let currentNote = viewModel.currentNote {
                        VStack {
                            Text(TouchInstrumentEngine.noteNameFromMIDI(currentNote))
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(4)
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.handleTouch(
                                location: value.location,
                                size: geometry.size,
                                engine: engine
                            )
                        }
                        .onEnded { _ in
                            viewModel.endTouch(engine: engine)
                        }
                )
            }
            .frame(height: 280)
            .padding(.horizontal)

            // Pitch bend amount indicator
            HStack {
                Text("Pitch Bend: \(Int(viewModel.pitchBendAmount * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Y Value: \(Int(viewModel.yAxisValue * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }
}

struct MelodyXYGrid: View {
    let scale: TouchScale
    let root: UInt8
    let octaveRange: Int
    let quantize: Bool

    var body: some View {
        GeometryReader { geometry in
            let totalNotes = scale.intervals.count * octaveRange
            let noteWidth = geometry.size.width / CGFloat(totalNotes)

            HStack(spacing: 0) {
                ForEach(0..<totalNotes, id: \.self) { index in
                    let isRoot = index % scale.intervals.count == 0
                    Rectangle()
                        .fill(isRoot ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1))
                        .frame(width: noteWidth)
                        .overlay(
                            Rectangle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }

            // Y-axis guide lines
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        .frame(height: geometry.size.height / 5)
                }
            }
        }
    }
}

struct MelodyXYTouchIndicator: View {
    let touch: MelodyXYViewModel.TouchInfo

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.blue, Color.blue.opacity(0.3)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 30
                )
            )
            .frame(width: 60, height: 60)
            .position(touch.location)
            .shadow(color: .blue.opacity(0.5), radius: 10)
    }
}

@MainActor
class MelodyXYViewModel: ObservableObject {

    struct TouchInfo: Identifiable {
        let id = UUID()
        var location: CGPoint
        var note: UInt8
        var velocity: Float
    }

    enum YAxisMode: String {
        case filter
        case timbre
        case volume
    }

    @Published var activeTouches: [Int: TouchInfo] = [:]
    @Published var octaveRange: Int = 2
    @Published var quantizeToScale: Bool = true
    @Published var ribbonMode: Bool = false
    @Published var yAxisMode: YAxisMode = .filter
    @Published var currentNote: UInt8?
    @Published var pitchBendAmount: Float = 0
    @Published var yAxisValue: Float = 0.5

    private var lastNote: UInt8?
    private var isGliding: Bool = false

    func handleTouch(location: CGPoint, size: CGSize, engine: TouchInstrumentEngine) {
        let normalizedX = Float(location.x / size.width)
        let normalizedY = Float(location.y / size.height)

        // Check if in pitch bend zones (10% on each side)
        let inLeftBendZone = normalizedX < 0.1
        let inRightBendZone = normalizedX > 0.9

        if inLeftBendZone || inRightBendZone {
            // Calculate pitch bend
            if inLeftBendZone {
                pitchBendAmount = -(0.1 - normalizedX) * 10  // -1 to 0
            } else {
                pitchBendAmount = (normalizedX - 0.9) * 10  // 0 to 1
            }

            // Apply pitch bend via CC
            let ccValue = UInt8((pitchBendAmount + 1) * 63.5)
            engine.onControlChange?(1, ccValue)  // CC1 for modulation/pitch bend
            return
        }

        pitchBendAmount = 0

        // Calculate note from X position (avoiding bend zones)
        let adjustedX = (normalizedX - 0.1) / 0.8  // Remap 0.1-0.9 to 0-1
        let clampedX = max(0, min(1, adjustedX))

        var note: UInt8
        if quantizeToScale {
            let totalNotes = engine.currentScale.intervals.count * octaveRange
            let noteIndex = Int(clampedX * Float(totalNotes - 1))
            note = engine.currentScale.noteInScale(degree: noteIndex, root: engine.rootNote)
        } else {
            // Chromatic mode
            let totalSemitones = octaveRange * 12
            let semitone = Int(clampedX * Float(totalSemitones))
            note = min(127, engine.rootNote + UInt8(semitone))
        }

        // Y-axis control
        yAxisValue = 1.0 - normalizedY  // Invert Y (top = high value)

        switch yAxisMode {
        case .filter:
            // Map to filter cutoff (CC74)
            let ccValue = UInt8(yAxisValue * 127)
            engine.onControlChange?(74, ccValue)
        case .timbre:
            // Map to timbre/brightness (CC71)
            let ccValue = UInt8(yAxisValue * 127)
            engine.onControlChange?(71, ccValue)
        case .volume:
            // Map to volume (CC7)
            let ccValue = UInt8(yAxisValue * 127)
            engine.onControlChange?(7, ccValue)
        }

        let touchId = 0  // Single touch for now

        if let existingTouch = activeTouches[touchId] {
            // Update existing touch
            var updatedTouch = existingTouch
            updatedTouch.location = location

            // Handle note change
            if note != existingTouch.note {
                if ribbonMode {
                    // Ribbon mode - glide between notes
                    engine.noteOff(existingTouch.note)
                    engine.noteOn(note, velocity: existingTouch.velocity)
                    updatedTouch.note = note
                } else {
                    // Standard mode - retrigger
                    engine.noteOff(existingTouch.note)
                    engine.noteOn(note, velocity: existingTouch.velocity)
                    updatedTouch.note = note
                }
            }

            activeTouches[touchId] = updatedTouch
        } else {
            // New touch
            let velocity: Float = 0.8
            engine.noteOn(note, velocity: velocity)

            activeTouches[touchId] = TouchInfo(
                location: location,
                note: note,
                velocity: velocity
            )
        }

        currentNote = note
        lastNote = note
    }

    func endTouch(engine: TouchInstrumentEngine) {
        for (_, touch) in activeTouches {
            engine.noteOff(touch.note)
        }
        activeTouches.removeAll()
        currentNote = nil
        pitchBendAmount = 0
    }
}

// MARK: - 4. KeyboardView

/// Piano keyboard with scale highlighting, velocity sensitivity, and glissando support
struct KeyboardView: View {

    @ObservedObject var engine: TouchInstrumentEngine
    @StateObject private var viewModel = KeyboardViewModel()

    var body: some View {
        VStack(spacing: 12) {
            // Header controls
            HStack {
                Text("Keyboard")
                    .font(.headline)

                Spacer()

                // Scale selector for highlighting
                Picker("Scale", selection: $engine.currentScale) {
                    ForEach(TouchScale.allCases) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                // Octave controls
                HStack(spacing: 4) {
                    Button("-") {
                        viewModel.octave = max(0, viewModel.octave - 1)
                    }
                    .buttonStyle(.bordered)

                    Text("Oct \(viewModel.octave)")
                        .frame(width: 50)

                    Button("+") {
                        viewModel.octave = min(8, viewModel.octave + 1)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)

            // Mode controls
            HStack(spacing: 16) {
                Toggle("Glissando", isOn: $viewModel.glissandoEnabled)
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                Toggle("Highlight Scale", isOn: $viewModel.highlightScale)
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                Picker("Size", selection: $viewModel.keyWidth) {
                    Text("S").tag(35.0)
                    Text("M").tag(50.0)
                    Text("L").tag(65.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding(.horizontal)

            // Scrollable keyboard
            ScrollView(.horizontal, showsIndicators: false) {
                KeyboardLayout(
                    viewModel: viewModel,
                    engine: engine
                )
            }
            .frame(height: 180)

            // Velocity indicator
            HStack {
                Text("Velocity: \(Int(viewModel.lastVelocity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let note = viewModel.lastPlayedNote {
                    Text("Note: \(TouchInstrumentEngine.noteNameFromMIDI(note))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct KeyboardLayout: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @ObservedObject var engine: TouchInstrumentEngine

    var body: some View {
        ZStack(alignment: .topLeading) {
            // White keys
            HStack(spacing: 1) {
                ForEach(viewModel.whiteKeyNotes, id: \.self) { note in
                    PianoKeyView(
                        note: note,
                        isBlack: false,
                        isPressed: viewModel.pressedNotes.contains(note),
                        isInScale: viewModel.highlightScale && engine.currentScale.isNoteInScale(note, root: engine.rootNote),
                        width: viewModel.keyWidth,
                        onPress: { velocity in
                            viewModel.keyPressed(note, velocity: velocity, engine: engine)
                        },
                        onRelease: {
                            viewModel.keyReleased(note, engine: engine)
                        },
                        onGlide: { targetNote in
                            if viewModel.glissandoEnabled {
                                viewModel.glideToNote(targetNote, engine: engine)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)

            // Black keys (overlaid)
            HStack(spacing: 1) {
                ForEach(0..<viewModel.blackKeyPositions.count, id: \.self) { index in
                    let position = viewModel.blackKeyPositions[index]
                    let note = viewModel.blackKeyNotes[index]

                    PianoKeyView(
                        note: note,
                        isBlack: true,
                        isPressed: viewModel.pressedNotes.contains(note),
                        isInScale: viewModel.highlightScale && engine.currentScale.isNoteInScale(note, root: engine.rootNote),
                        width: viewModel.keyWidth * 0.65,
                        onPress: { velocity in
                            viewModel.keyPressed(note, velocity: velocity, engine: engine)
                        },
                        onRelease: {
                            viewModel.keyReleased(note, engine: engine)
                        },
                        onGlide: { targetNote in
                            if viewModel.glissandoEnabled {
                                viewModel.glideToNote(targetNote, engine: engine)
                            }
                        }
                    )
                    .offset(x: CGFloat(position) * viewModel.keyWidth)
                }
            }
            .padding(.leading, viewModel.keyWidth * 0.68)
        }
    }
}

struct PianoKeyView: View {
    let note: UInt8
    let isBlack: Bool
    let isPressed: Bool
    let isInScale: Bool
    let width: Double
    var onPress: (Float) -> Void
    var onRelease: () -> Void
    var onGlide: (UInt8) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: isBlack ? 2 : 4)
                    .fill(keyColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: isBlack ? 2 : 4)
                            .stroke(borderColor, lineWidth: isInScale ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: isBlack ? 2 : 1, y: 2)

                // Note name for white keys
                if !isBlack {
                    Text(noteName)
                        .font(.system(size: 10))
                        .foregroundColor(isPressed ? .white : .gray)
                        .padding(.bottom, 4)
                }

                // Scale indicator dot
                if isInScale && !isBlack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .offset(y: -20)
                }
            }
            .frame(width: isBlack ? width : width, height: isBlack ? 100 : 160)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if value.translation == .zero {
                            // Calculate velocity from vertical touch position
                            let normalizedY = Float(value.startLocation.y / geometry.size.height)
                            let velocity = max(0.3, min(1.0, normalizedY))
                            onPress(velocity)
                        }
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
        }
        .frame(width: isBlack ? width : width, height: isBlack ? 100 : 160)
        .zIndex(isBlack ? 1 : 0)
    }

    private var keyColor: Color {
        if isPressed {
            return Color.blue
        }
        if isInScale {
            return isBlack ? Color.gray.opacity(0.8) : Color.blue.opacity(0.1)
        }
        return isBlack ? .black : .white
    }

    private var borderColor: Color {
        if isInScale {
            return .blue
        }
        return isBlack ? .gray : .gray.opacity(0.3)
    }

    private var noteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return noteNames[Int(note) % 12]
    }
}

@MainActor
class KeyboardViewModel: ObservableObject {

    @Published var octave: Int = 4 {
        didSet { updateVisibleNotes() }
    }
    @Published var keyWidth: Double = 50
    @Published var pressedNotes: Set<UInt8> = []
    @Published var glissandoEnabled: Bool = false
    @Published var highlightScale: Bool = true
    @Published var lastVelocity: Float = 0
    @Published var lastPlayedNote: UInt8?

    var whiteKeyNotes: [UInt8] = []
    var blackKeyNotes: [UInt8] = []
    var blackKeyPositions: [Int] = []

    private var glissandoNotes: Set<UInt8> = []

    init() {
        updateVisibleNotes()
    }

    private func updateVisibleNotes() {
        let startNote = UInt8(octave * 12)
        let endNote = min(127, startNote + 24)  // 2 octaves visible

        whiteKeyNotes = []
        blackKeyNotes = []
        blackKeyPositions = []

        var whiteKeyIndex = 0

        for note in startNote..<endNote {
            let noteClass = Int(note) % 12
            let isBlack = [1, 3, 6, 8, 10].contains(noteClass)

            if isBlack {
                blackKeyNotes.append(note)
                blackKeyPositions.append(whiteKeyIndex - 1)
            } else {
                whiteKeyNotes.append(note)
                whiteKeyIndex += 1
            }
        }
    }

    func keyPressed(_ note: UInt8, velocity: Float, engine: TouchInstrumentEngine) {
        guard !pressedNotes.contains(note) else { return }

        pressedNotes.insert(note)
        lastVelocity = velocity
        lastPlayedNote = note

        engine.noteOn(note, velocity: velocity)

        if glissandoEnabled {
            glissandoNotes.insert(note)
        }
    }

    func keyReleased(_ note: UInt8, engine: TouchInstrumentEngine) {
        pressedNotes.remove(note)
        glissandoNotes.remove(note)
        engine.noteOff(note)
    }

    func glideToNote(_ note: UInt8, engine: TouchInstrumentEngine) {
        guard !glissandoNotes.contains(note) else { return }

        // Play the new note with same velocity
        engine.noteOn(note, velocity: lastVelocity)
        glissandoNotes.insert(note)
        pressedNotes.insert(note)
        lastPlayedNote = note
    }
}

// MARK: - 5. StrumPad View

/// Guitar-style strum pad with 6 strings and chord fingering
struct StrumPadView: View {

    @ObservedObject var engine: TouchInstrumentEngine
    @StateObject private var viewModel = StrumPadViewModel()

    var body: some View {
        VStack(spacing: 12) {
            // Header controls
            HStack {
                Text("Strum Pad")
                    .font(.headline)

                Spacer()

                // Chord selector
                Picker("Chord", selection: $viewModel.currentChord) {
                    ForEach(TouchChordType.allCases) { chord in
                        Text(chord.rawValue).tag(chord)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                // Root note
                Picker("Root", selection: $viewModel.rootNote) {
                    ForEach(40...64, id: \.self) { note in
                        Text(TouchInstrumentEngine.noteNameFromMIDI(UInt8(note))).tag(UInt8(note))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 70)
            }
            .padding(.horizontal)

            // Mode controls
            HStack(spacing: 16) {
                Toggle("Auto-Chord", isOn: $viewModel.autoChordEnabled)
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                Toggle("Palm Mute", isOn: $viewModel.palmMuteEnabled)
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .tint(viewModel.palmMuteEnabled ? .orange : nil)
            }
            .padding(.horizontal)

            // Chord fingering display
            ChordFingeringView(
                chord: viewModel.currentChord,
                root: viewModel.rootNote,
                stringNotes: viewModel.stringNotes
            )
            .frame(height: 60)
            .padding(.horizontal)

            // Strum area with 6 strings
            GeometryReader { geometry in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brown.opacity(0.3))

                    // Strings
                    VStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { stringIndex in
                            GuitarStringView(
                                stringIndex: stringIndex,
                                note: viewModel.stringNotes[stringIndex],
                                isPressed: viewModel.pressedStrings.contains(stringIndex),
                                isBending: viewModel.bendingStrings.contains(stringIndex),
                                bendAmount: viewModel.stringBendAmounts[stringIndex] ?? 0,
                                isMuted: viewModel.mutedStrings.contains(stringIndex)
                            )
                            .frame(height: geometry.size.height / 6)
                        }
                    }

                    // Palm mute zone (bottom 20%)
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.black.opacity(viewModel.palmMuteEnabled ? 0.3 : 0.1))
                            .frame(height: geometry.size.height * 0.15)
                            .overlay(
                                Text("Palm Mute Zone")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }

                    // Strum direction indicator
                    if let direction = viewModel.lastStrumDirection {
                        HStack {
                            Spacer()
                            Image(systemName: direction ? "arrow.down" : "arrow.up")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.5))
                                .padding()
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            viewModel.handleStrum(
                                location: value.location,
                                translation: value.translation,
                                size: geometry.size,
                                engine: engine
                            )
                        }
                        .onEnded { value in
                            viewModel.endStrum(engine: engine)
                        }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .onEnded { _ in
                            // String bend on long press
                            viewModel.startStringBend(engine: engine)
                        }
                )
            }
            .frame(height: 200)
            .padding(.horizontal)

            // String tuning indicator
            HStack {
                ForEach(0..<6, id: \.self) { index in
                    let note = viewModel.stringNotes[index]
                    Text(TouchInstrumentEngine.noteNameFromMIDI(note))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ChordFingeringView: View {
    let chord: TouchChordType
    let root: UInt8
    let stringNotes: [UInt8]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { stringIndex in
                let note = stringNotes[stringIndex]
                let chordNotes = chord.notes(root: root)
                let isInChord = chordNotes.contains { abs(Int($0) - Int(note)) % 12 == 0 }

                VStack(spacing: 2) {
                    Circle()
                        .fill(isInChord ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(isInChord ? "o" : "x")
                                .font(.caption2)
                                .foregroundColor(.white)
                        )

                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 2, height: 30)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct GuitarStringView: View {
    let stringIndex: Int
    let note: UInt8
    let isPressed: Bool
    let isBending: Bool
    let bendAmount: Float
    let isMuted: Bool

    @State private var vibration: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // String line
                Path { path in
                    let y = geometry.size.height / 2
                    let bendOffset = CGFloat(bendAmount) * 20

                    path.move(to: CGPoint(x: 0, y: y))

                    if isBending {
                        path.addQuadCurve(
                            to: CGPoint(x: geometry.size.width, y: y),
                            control: CGPoint(x: geometry.size.width / 2, y: y + bendOffset)
                        )
                    } else {
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(stringColor, lineWidth: stringThickness)
                .offset(y: isPressed ? vibration : 0)

                // String highlight on press
                if isPressed {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: stringThickness * 3)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
        }
        .onChange(of: isPressed) { pressed in
            if pressed {
                withAnimation(.easeInOut(duration: 0.05).repeatCount(5)) {
                    vibration = 3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    vibration = 0
                }
            }
        }
    }

    private var stringColor: Color {
        if isMuted {
            return .gray.opacity(0.5)
        }
        return isPressed ? .orange : .yellow.opacity(0.8)
    }

    private var stringThickness: CGFloat {
        // Thicker strings for bass notes (higher string index)
        return CGFloat(2 + stringIndex) * 0.5
    }
}

@MainActor
class StrumPadViewModel: ObservableObject {

    @Published var currentChord: TouchChordType = .major
    @Published var rootNote: UInt8 = 52  // E2
    @Published var pressedStrings: Set<Int> = []
    @Published var bendingStrings: Set<Int> = []
    @Published var mutedStrings: Set<Int> = []
    @Published var stringBendAmounts: [Int: Float] = [:]
    @Published var autoChordEnabled: Bool = true
    @Published var palmMuteEnabled: Bool = false
    @Published var lastStrumDirection: Bool?  // true = down, false = up

    // Standard guitar tuning: E2, A2, D3, G3, B3, E4
    var stringNotes: [UInt8] {
        if autoChordEnabled {
            return calculateChordVoicing()
        }
        return [40, 45, 50, 55, 59, 64]  // Standard tuning
    }

    private var lastStrumY: CGFloat = 0
    private var strummedStrings: Set<Int> = []

    private func calculateChordVoicing() -> [UInt8] {
        let baseTuning: [UInt8] = [40, 45, 50, 55, 59, 64]
        let chordIntervals = currentChord.intervals

        return baseTuning.enumerated().map { (index, openNote) in
            // Find the nearest chord tone for each string
            let openNoteClass = Int(openNote) % 12
            let rootNoteClass = Int(rootNote) % 12

            var bestNote = openNote
            var minDistance = 12

            for interval in chordIntervals {
                let targetNoteClass = (rootNoteClass + interval) % 12
                let distance = abs(targetNoteClass - openNoteClass)
                let wrappedDistance = min(distance, 12 - distance)

                if wrappedDistance < minDistance {
                    minDistance = wrappedDistance
                    // Add or subtract to reach target
                    if (targetNoteClass - openNoteClass + 12) % 12 <= 6 {
                        bestNote = openNote + UInt8(wrappedDistance)
                    } else {
                        bestNote = openNote - UInt8(wrappedDistance)
                    }
                }
            }

            return min(127, max(0, bestNote))
        }
    }

    func handleStrum(location: CGPoint, translation: CGSize, size: CGSize, engine: TouchInstrumentEngine) {
        // Detect strum direction
        let strumDown = translation.height > 0

        if lastStrumDirection != strumDown {
            lastStrumDirection = strumDown
            strummedStrings.removeAll()
        }

        // Calculate which string is being touched
        let stringHeight = size.height / 6
        let stringIndex = Int(location.y / stringHeight)

        guard stringIndex >= 0 && stringIndex < 6 else { return }

        // Check if in palm mute zone
        let inPalmMuteZone = location.y > size.height * 0.85
        if inPalmMuteZone && !palmMuteEnabled {
            palmMuteEnabled = true
        }

        // Strum across strings
        if !strummedStrings.contains(stringIndex) {
            strummedStrings.insert(stringIndex)
            pressedStrings.insert(stringIndex)

            let note = stringNotes[stringIndex]
            let velocity: Float = palmMuteEnabled ? 0.5 : 0.8

            // Slight delay for natural strum feel
            let delay = Double(strumDown ? stringIndex : (5 - stringIndex)) * 0.015

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                engine.noteOn(note, velocity: velocity)

                // Auto-release after strum
                DispatchQueue.main.asyncAfter(deadline: .now() + (self?.palmMuteEnabled == true ? 0.1 : 0.5)) {
                    engine.noteOff(note)
                    Task { @MainActor in
                        self?.pressedStrings.remove(stringIndex)
                    }
                }
            }
        }

        lastStrumY = location.y
    }

    func endStrum(engine: TouchInstrumentEngine) {
        strummedStrings.removeAll()

        // Reset palm mute if it was auto-activated
        if palmMuteEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.palmMuteEnabled = false
            }
        }
    }

    func startStringBend(engine: TouchInstrumentEngine) {
        // Implement string bend on long press
        for stringIndex in pressedStrings {
            bendingStrings.insert(stringIndex)
            stringBendAmounts[stringIndex] = 0

            // Animate bend
            withAnimation(.easeInOut(duration: 0.3)) {
                stringBendAmounts[stringIndex] = 1.0
            }

            // Send pitch bend CC
            let ccValue = UInt8(min(127, 64 + 32))  // Bend up by ~1 semitone
            engine.onControlChange?(1, ccValue)
        }
    }

    func releaseStringBend(engine: TouchInstrumentEngine) {
        for stringIndex in bendingStrings {
            withAnimation(.easeInOut(duration: 0.2)) {
                stringBendAmounts[stringIndex] = 0
            }
        }
        bendingStrings.removeAll()

        // Reset pitch bend
        engine.onControlChange?(1, 64)
    }
}

// MARK: - Main Touch Instruments Container

/// Container view for all touch instruments with tab switching
struct TouchInstrumentsContainerView: View {

    @StateObject private var engine = TouchInstrumentEngine()
    @State private var selectedInstrument: InstrumentTab = .chordPad

    enum InstrumentTab: String, CaseIterable {
        case chordPad = "Chords"
        case drumPad = "Drums"
        case melodyXY = "XY Pad"
        case keyboard = "Keys"
        case strumPad = "Strum"

        var icon: String {
            switch self {
            case .chordPad: return "square.grid.2x2"
            case .drumPad: return "circle.grid.3x3"
            case .melodyXY: return "arrow.up.left.and.arrow.down.right"
            case .keyboard: return "pianokeys"
            case .strumPad: return "guitars"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Instrument tabs
            HStack(spacing: 0) {
                ForEach(InstrumentTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedInstrument = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                            Text(tab.rawValue)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedInstrument == tab ? Color.blue.opacity(0.2) : Color.clear)
                        .foregroundColor(selectedInstrument == tab ? .blue : .gray)
                    }
                }
            }
            .background(Color(UIColor.systemBackground))

            Divider()

            // Selected instrument view
            Group {
                switch selectedInstrument {
                case .chordPad:
                    ChordPadView(engine: engine)
                case .drumPad:
                    DrumPadView(engine: engine)
                case .melodyXY:
                    MelodyXYView(engine: engine)
                case .keyboard:
                    KeyboardView(engine: engine)
                case .strumPad:
                    StrumPadView(engine: engine)
                }
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct TouchInstruments_Previews: PreviewProvider {
    static var previews: some View {
        TouchInstrumentsContainerView()
            .preferredColorScheme(.dark)
    }
}
#endif
