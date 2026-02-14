import Foundation
import Accelerate
import Combine

/// Pro Vocal Processing Chain — Master Orchestrator
///
/// Connects ALL vocal processing components into a unified chain:
///
/// Signal Flow (Real-Time):
/// ```
/// Input → Pitch Detection → Pitch Correction → Vibrato → Formant → Bio-Reactive → Output
///                              ↑                   ↑          ↑           ↑
///                           Scale/Key          Per-Note    Preserve    Biometrics
///                           MIDI Target        Shape/Rate  Throat      Coherence
/// ```
///
/// Signal Flow (Post-Production):
/// ```
/// Audio File → Analysis → Note Detection → Per-Note Editing → Render
///                ↓             ↓                  ↓
///           Pitch Contour  Note Segments     Pitch/Vibrato/
///           Energy/Onset   Vibrato Analysis  Formant/Timing
/// ```
///
/// Modes:
/// - **Live**: Real-time processing with minimal latency
/// - **Studio**: Post-production with full editing capabilities
/// - **Bio-Reactive**: Live processing modulated by biometrics
@MainActor
class ProVocalChain: ObservableObject {

    // MARK: - Published State

    @Published var mode: ProcessingMode = .live
    @Published var isActive: Bool = false
    @Published var inputLevel: Float = 0
    @Published var outputLevel: Float = 0

    // Module bypass
    @Published var pitchCorrectionEnabled: Bool = true
    @Published var vibratoEnabled: Bool = true
    @Published var formantEnabled: Bool = true
    @Published var bioReactiveEnabled: Bool = true
    @Published var deEsserEnabled: Bool = false
    @Published var compressorEnabled: Bool = false
    @Published var breathDetectionEnabled: Bool = false
    @Published var harmonyEnabled: Bool = false
    @Published var doublingEnabled: Bool = false

    // MARK: - Processing Chain Components

    let pitchCorrector: RealTimePitchCorrector
    let vibratoEngine: VibratoEngine
    let phaseVocoder: PhaseVocoder
    let postProcessor: VocalPostProcessor
    let bioReactiveEngine: BioReactiveVocalEngine
    let breathDetector: BreathDetector
    let harmonyGenerator: VocalHarmonyGenerator
    let doublingEngine: VocalDoublingEngine

    // MARK: - Types

    enum ProcessingMode: String, CaseIterable, Identifiable {
        case live = "Live"                  // Real-time, low latency
        case studio = "Studio"              // Post-production editing
        case bioReactive = "Bio-Reactive"   // Live + biometric modulation

        var id: String { rawValue }
    }

    /// Processing statistics
    struct ProcessingStats {
        var latencyMs: Float = 0
        var cpuUsage: Float = 0
        var pitchDetectionConfidence: Float = 0
        var correctionApplied: Float = 0
        var bioModulationActive: Bool = false
    }

    @Published var stats: ProcessingStats = ProcessingStats()

    // MARK: - Configuration

    struct ChainConfiguration {
        var sampleRate: Float = 48000.0
        var blockSize: Int = 512
        var fftSize: Int = 4096

        // Quality presets
        static let lowLatency = ChainConfiguration(sampleRate: 48000, blockSize: 256, fftSize: 2048)
        static let balanced = ChainConfiguration(sampleRate: 48000, blockSize: 512, fftSize: 4096)
        static let highQuality = ChainConfiguration(sampleRate: 48000, blockSize: 1024, fftSize: 8192)
    }

    private let config: ChainConfiguration
    private var cancellables = Set<AnyCancellable>()

    // Active note tracking (for real-time vibrato)
    private var activeNoteId: UUID?
    private var noteStartTime: Date?
    private var currentNoteVibrato: VibratoEngine.VibratoParameters = .default()

    // MARK: - Initialization

    init(config: ChainConfiguration = .balanced) {
        self.config = config

        // Initialize all components
        self.pitchCorrector = RealTimePitchCorrector(sampleRate: config.sampleRate)
        self.vibratoEngine = VibratoEngine(sampleRate: config.sampleRate)
        self.phaseVocoder = PhaseVocoder(config: PhaseVocoder.Configuration(
            fftSize: config.fftSize,
            hopSize: config.fftSize / 4,
            sampleRate: config.sampleRate,
            preserveFormants: true,
            preserveTransients: true
        ))
        self.postProcessor = VocalPostProcessor(sampleRate: config.sampleRate)
        self.bioReactiveEngine = BioReactiveVocalEngine()
        self.breathDetector = BreathDetector(sampleRate: Double(config.sampleRate), fftSize: config.fftSize)
        self.harmonyGenerator = VocalHarmonyGenerator(sampleRate: Double(config.sampleRate), fftSize: config.fftSize)
        self.doublingEngine = VocalDoublingEngine(sampleRate: Double(config.sampleRate))

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // When bio-reactive engine updates, propagate to pitch corrector
        bioReactiveEngine.$modulationValues
            .receive(on: RunLoop.main)
            .sink { [weak self] values in
                guard let self = self, self.bioReactiveEnabled else { return }
                self.bioReactiveEngine.applyToPitchCorrector(self.pitchCorrector)
            }
            .store(in: &cancellables)
    }

    // MARK: - Real-Time Processing

    /// Process a block of audio in real-time
    /// - Parameter input: Mono audio samples
    /// - Returns: Processed audio samples
    func processBlock(_ input: [Float]) -> [Float] {
        guard input.count > 0 else { return input }

        var output = input

        // 1. Input metering
        var rms: Float = 0
        vDSP_rmsqv(input, 1, &rms, vDSP_Length(input.count))

        // 2. Pitch Correction
        if pitchCorrectionEnabled {
            output = pitchCorrector.processBlock(output, sampleRate: config.sampleRate)
        }

        // 3. Vibrato (add/modify)
        if vibratoEnabled, let noteId = activeNoteId, let startTime = noteStartTime {
            let noteTime = Float(Date().timeIntervalSince(startTime))
            let vibrato = vibratoEngine.generateVibrato(
                noteId: noteId,
                params: currentNoteVibrato,
                noteTime: noteTime,
                noteDuration: 0,  // Unknown in real-time
                frameCount: output.count
            )

            // Apply vibrato modulation
            output = vibratoEngine.applyVibratoToAudio(
                audio: output,
                modulationCents: vibrato,
                phaseVocoder: phaseVocoder
            )
        }

        // 4. Breath Detection/Removal
        if breathDetectionEnabled {
            output = breathDetector.processBuffer(output)
        }

        // 5. Bio-Reactive Processing
        if bioReactiveEnabled {
            output = bioReactiveEngine.processAudio(output, modValues: bioReactiveEngine.modulationValues)
        }

        // 6. Harmony Generation
        if harmonyEnabled {
            let detectedPitch = pitchCorrector.currentInputPitch
            output = harmonyGenerator.processBuffer(output, detectedPitchHz: detectedPitch)
        }

        // 7. Vocal Doubling
        if doublingEnabled {
            output = doublingEngine.processMono(output)
        }

        return output
    }

    // MARK: - Post-Production Processing

    /// Analyze a vocal track for post-production editing
    /// - Parameter audio: Complete vocal track (mono)
    /// - Returns: Detected notes ready for editing
    func analyzeForEditing(_ audio: [Float]) async -> [VocalPostProcessor.VocalNote] {
        mode = .studio
        return await postProcessor.analyzeVocal(audio)
    }

    /// Render all post-production edits
    /// - Parameter originalAudio: Original unprocessed audio
    /// - Returns: Fully processed audio with all edits
    func renderEdits(originalAudio: [Float]) async -> [Float] {
        var output = await postProcessor.render(originalAudio: originalAudio)

        // Apply bio-reactive layer if active
        if bioReactiveEnabled && bioReactiveEngine.isActive {
            output = bioReactiveEngine.processAudio(
                output, modValues: bioReactiveEngine.modulationValues
            )
        }

        return output
    }

    // MARK: - Quick Actions

    /// Auto-correct all notes to scale
    func autoCorrectAll() {
        postProcessor.correctAllPitches()
    }

    /// Set the musical key for pitch correction
    func setKey(root: Int, scale: RealTimePitchCorrector.ScaleType) {
        pitchCorrector.rootNote = root
        pitchCorrector.scaleType = scale
    }

    /// Set correction speed (0ms = hard-tune, 200ms = natural)
    func setCorrectionSpeed(_ ms: Float) {
        pitchCorrector.correctionSpeed = ms
    }

    /// Set vibrato style for all new notes
    func setVibratoStyle(_ style: VibratoEngine.VibratoShape) {
        currentNoteVibrato.shape = style
    }

    // MARK: - Note Tracking (Real-Time)

    /// Signal that a new vocal note has started
    func noteOn() {
        let id = UUID()
        activeNoteId = id
        noteStartTime = Date()
        vibratoEngine.registerNote(id: id, params: currentNoteVibrato)
    }

    /// Signal that the current vocal note has ended
    func noteOff() {
        if let id = activeNoteId {
            vibratoEngine.unregisterNote(id: id)
        }
        activeNoteId = nil
        noteStartTime = nil
    }

    // MARK: - Bio-Reactive Control

    /// Update biometric data from HealthKit/sensors
    func updateBiometrics(_ state: BioReactiveVocalEngine.BioState) {
        bioReactiveEngine.updateBioState(state)
    }

    /// Enable/disable bio-reactive processing
    func setBioReactive(_ enabled: Bool) {
        bioReactiveEnabled = enabled
        if enabled {
            bioReactiveEngine.start()
            mode = .bioReactive
        } else {
            bioReactiveEngine.stop()
            if mode == .bioReactive { mode = .live }
        }
    }

    /// Load a bio-reactive preset
    func loadBioPreset(_ preset: BioReactiveVocalEngine.MappingPreset) {
        bioReactiveEngine.loadPreset(preset)
    }

    // MARK: - Chain Control

    func start() {
        isActive = true
        log.log(.info, category: .audio, "ProVocalChain: Started in \(mode.rawValue) mode")
    }

    func stop() {
        isActive = false
        noteOff()
        bioReactiveEngine.stop()
        log.log(.info, category: .audio, "ProVocalChain: Stopped")
    }

    // MARK: - Presets

    /// Quick setup presets for common use cases
    enum VocalPreset: String, CaseIterable, Identifiable {
        case natural = "Natural"
        case pop = "Pop"
        case autoTune = "Auto-Tune"
        case hardTune = "Hard Tune"
        case warmVintage = "Warm Vintage"
        case operatic = "Operatic"
        case meditation = "Meditation"
        case bioReactivePerformance = "Bio Performance"

        var id: String { rawValue }
    }

    func loadPreset(_ preset: VocalPreset) {
        switch preset {
        case .natural:
            pitchCorrector.correctionSpeed = 150
            pitchCorrector.correctionStrength = 0.5
            pitchCorrector.humanize = 0.5
            pitchCorrector.flexTuneThreshold = 20
            currentNoteVibrato = .default()
            bioReactiveEnabled = false

        case .pop:
            pitchCorrector.correctionSpeed = 50
            pitchCorrector.correctionStrength = 0.8
            pitchCorrector.humanize = 0.2
            pitchCorrector.flexTuneThreshold = 10
            currentNoteVibrato = .pop()
            bioReactiveEnabled = false

        case .autoTune:
            pitchCorrector.correctionSpeed = 10
            pitchCorrector.correctionStrength = 0.95
            pitchCorrector.humanize = 0.05
            pitchCorrector.flexTuneThreshold = 5
            currentNoteVibrato = .straight()
            bioReactiveEnabled = false

        case .hardTune:
            pitchCorrector.correctionSpeed = 0
            pitchCorrector.correctionStrength = 1.0
            pitchCorrector.humanize = 0
            pitchCorrector.flexTuneThreshold = 0
            pitchCorrector.vibratoDepth = 0
            currentNoteVibrato = .straight()
            bioReactiveEnabled = false

        case .warmVintage:
            pitchCorrector.correctionSpeed = 100
            pitchCorrector.correctionStrength = 0.6
            pitchCorrector.humanize = 0.4
            pitchCorrector.flexTuneThreshold = 15
            currentNoteVibrato = .default()
            bioReactiveEnabled = false

        case .operatic:
            pitchCorrector.correctionSpeed = 200
            pitchCorrector.correctionStrength = 0.3
            pitchCorrector.humanize = 0.6
            pitchCorrector.flexTuneThreshold = 25
            currentNoteVibrato = .operatic()
            bioReactiveEnabled = false

        case .meditation:
            pitchCorrector.correctionSpeed = 100
            pitchCorrector.correctionStrength = 0.7
            pitchCorrector.humanize = 0.3
            currentNoteVibrato = .default()
            bioReactiveEnabled = true
            bioReactiveEngine.loadPreset(.meditation)
            bioReactiveEngine.start()
            mode = .bioReactive

        case .bioReactivePerformance:
            pitchCorrector.correctionSpeed = 50
            pitchCorrector.correctionStrength = 0.8
            pitchCorrector.humanize = 0.2
            currentNoteVibrato = .default()
            bioReactiveEnabled = true
            bioReactiveEngine.loadPreset(.performance)
            bioReactiveEngine.start()
            mode = .bioReactive
        }

        log.log(.info, category: .audio, "ProVocalChain: Loaded preset '\(preset.rawValue)'")
    }
}
