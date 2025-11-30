import SwiftUI
import Combine
import Accelerate

// MARK: - Unified Visual Sound Engine
// Verbindet alle visuellen Komponenten mit der Audio/Bio Welt
// "Flüssiges Licht für deine Musik"

/// Central hub that connects audio, bio-data, and visuals
@MainActor
class UnifiedVisualSoundEngine: ObservableObject {

    // MARK: - Published State

    /// Current visualization mode
    @Published var currentMode: VisualMode = .liquidLight

    /// Active visual parameters (derived from audio + bio)
    @Published var visualParams = VisualParameters()

    /// FFT spectrum data (64 bands)
    @Published var spectrumData: [Float] = Array(repeating: 0, count: 64)

    /// Waveform buffer
    @Published var waveformData: [Float] = Array(repeating: 0, count: 256)

    /// Beat detected flag
    @Published var beatDetected = false

    /// Current dominant frequency
    @Published var dominantFrequency: Float = 0

    // MARK: - Visualization Modes

    enum VisualMode: String, CaseIterable, Identifiable {
        case liquidLight = "Liquid Light"      // Flüssiges Licht - Nia9ara style
        case particles = "Particles"           // Bio-reactive particles
        case spectrum = "Spectrum"             // FFT analyzer
        case waveform = "Waveform"            // Oscilloscope
        case mandala = "Mandala"              // Sacred geometry
        case cymatics = "Cymatics"            // Chladni patterns
        case vaporwave = "Vaporwave"          // Neon grid aesthetic
        case nebula = "Nebula"                // Space clouds
        case kaleidoscope = "Kaleidoscope"    // Mirror symmetry
        case flowField = "Flow Field"         // Vector field particles

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .liquidLight: return "drop.fill"
            case .particles: return "sparkles"
            case .spectrum: return "chart.bar.fill"
            case .waveform: return "waveform.path"
            case .mandala: return "circle.hexagongrid.fill"
            case .cymatics: return "waveform.circle.fill"
            case .vaporwave: return "square.grid.3x3.fill"
            case .nebula: return "cloud.fill"
            case .kaleidoscope: return "camera.filters"
            case .flowField: return "wind"
            }
        }

        var description: String {
            switch self {
            case .liquidLight: return "Flowing light streams synced to coherence"
            case .particles: return "Bio-reactive particle physics"
            case .spectrum: return "Real-time frequency analyzer"
            case .waveform: return "Audio oscilloscope display"
            case .mandala: return "Sacred geometry with radial symmetry"
            case .cymatics: return "Sound-driven Chladni patterns"
            case .vaporwave: return "Retro neon grid aesthetic"
            case .nebula: return "Cosmic gas clouds"
            case .kaleidoscope: return "Mirrored audio-reactive patterns"
            case .flowField: return "Particles following vector fields"
            }
        }
    }

    // MARK: - Visual Parameters

    struct VisualParameters {
        // From Audio - Physikalisch korrekte Frequenzbänder
        var audioLevel: Float = 0               // 0-1 RMS level

        // === Detaillierte Frequenzbänder (physikalisch korrekt) ===
        // Basierend auf menschlicher Hörwahrnehmung und Musikproduktion

        // Sub-Bass: 20-60 Hz - Wird mehr gefühlt als gehört
        // Kick Drum Fundament, 808 Sub, Erdbeben-artige Vibrationen
        var subBassLevel: Float = 0

        // Bass: 60-250 Hz - Musikalisches Fundament
        // Kick Body, Bass-Gitarre, Synth Bass, tiefe Vocals
        var bassLevel: Float = 0

        // Low-Mid: 250-500 Hz - Wärme und Körper
        // Instrument-Body, männliche Vocals, Snare Body
        var lowMidLevel: Float = 0

        // Mid: 500-2000 Hz - Kernbereich der Musik
        // Vocals, Gitarren, Keyboards, die meisten Instrumente
        var midLevel: Float = 0

        // Upper-Mid: 2000-4000 Hz - Präsenz und Klarheit
        // Vocal Presence, Gitarren-Attack, Snare Crack
        var upperMidLevel: Float = 0

        // High: 4000-8000 Hz - Brillanz und Definition
        // Hi-Hats, Becken Attack, Vocal Sibilanz, Synth Sparkle
        var highLevel: Float = 0

        // Air: 8000-20000 Hz - Luft und Glanz
        // Becken Shimmer, Raum-Ambience, "Air", Obertöne
        var airLevel: Float = 0

        // === Vereinfachte 3-Band Zusammenfassung ===
        var bassTotal: Float = 0                // Sub-Bass + Bass (20-250 Hz)
        var midTotal: Float = 0                 // Low-Mid + Mid + Upper-Mid (250-4000 Hz)
        var highTotal: Float = 0                // High + Air (4000-20000 Hz)

        // === Musikalische Analyse ===
        var frequency: Float = 0                // Dominante Frequenz Hz
        var pitch: Float = 0                    // Geschätzte Tonhöhe (MIDI Note)
        var tempo: Float = 120                  // Detected BPM
        var beatPhase: Float = 0                // 0-1 beat cycle
        var spectralCentroid: Float = 0         // "Helligkeit" des Sounds (Hz)
        var spectralFlatness: Float = 0         // 0=tonal, 1=noise

        // From Bio
        var hrv: Float = 0.5                    // 0-1 heart rate variability
        var coherence: Float = 0.5              // 0-1 HeartMath coherence
        var heartRate: Float = 70               // BPM
        var stress: Float = 0.5                 // 0-1 stress index
        var breathPhase: Float = 0              // 0-1 breath cycle

        // Combined/Derived
        var energy: Float = 0.5                 // Overall energy level
        var flow: Float = 0.5                   // Flow state indicator
        var intensity: Float = 0.5              // Visual intensity
        var colorHue: Float = 0.5               // 0-1 hue based on state

        // Timing
        var time: Double = 0                    // Animation time
        var deltaTime: Double = 0               // Frame delta
    }

    // MARK: - Physikalische Frequenzband-Definitionen

    /// Standard-Frequenzbänder basierend auf Psychoakustik und Musikproduktion
    struct FrequencyBands {
        // Untere Grenze jedes Bandes in Hz
        static let subBassMin: Float = 20
        static let subBassMax: Float = 60

        static let bassMin: Float = 60
        static let bassMax: Float = 250

        static let lowMidMin: Float = 250
        static let lowMidMax: Float = 500

        static let midMin: Float = 500
        static let midMax: Float = 2000

        static let upperMidMin: Float = 2000
        static let upperMidMax: Float = 4000

        static let highMin: Float = 4000
        static let highMax: Float = 8000

        static let airMin: Float = 8000
        static let airMax: Float = 20000

        /// Berechnet den FFT-Bin-Index für eine Frequenz
        static func binForFrequency(_ freq: Float, fftSize: Int, sampleRate: Float) -> Int {
            return Int(freq * Float(fftSize) / sampleRate)
        }

        /// A-Gewichtung für wahrgenommene Lautstärke (vereinfacht)
        /// Basierend auf ISO 226:2003 Equal-Loudness Contours
        static func aWeighting(frequency: Float) -> Float {
            // Vereinfachte A-Gewichtung Kurve
            let f2 = frequency * frequency
            let numerator = 12194.0 * 12194.0 * f2 * f2
            let denominator = (f2 + 20.6 * 20.6) *
                             sqrt((f2 + 107.7 * 107.7) * (f2 + 737.9 * 737.9)) *
                             (f2 + 12194.0 * 12194.0)
            let ra = numerator / Float(denominator)
            // Normalisieren auf 0dB bei 1kHz
            let ra1k: Float = 0.7943  // A(1000Hz)
            return 20 * log10(ra / ra1k + 1e-10)
        }
    }

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var lastUpdateTime = Date()

    // FFT
    private let fftSize = 2048
    private var fftSetup: vDSP_DFT_Setup?
    private var fftBuffer: [Float] = []
    private var hannWindow: [Float] = []

    // Beat Detection
    private var beatHistory: [Float] = []
    private let beatHistorySize = 43  // ~1 second at 44100/1024
    private var lastBeatTime: Date = Date()

    // MARK: - Initialization

    init() {
        setupFFT()
        startUpdateLoop()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_Destroy(setup)
        }
    }

    // MARK: - Setup

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        fftBuffer = Array(repeating: 0, count: fftSize)

        // Create Hann window
        hannWindow = Array(repeating: 0, count: fftSize)
        vDSP_hann_window(&hannWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    private func startUpdateLoop() {
        // 60 FPS update loop
        Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateVisualParams()
            }
            .store(in: &cancellables)
    }

    // MARK: - Audio Input

    /// Process incoming audio buffer
    func processAudioBuffer(_ buffer: [Float]) {
        guard buffer.count >= 256 else { return }

        // Update waveform (downsample to 256 samples)
        let stride = buffer.count / 256
        waveformData = (0..<256).map { i in
            buffer[min(i * stride, buffer.count - 1)]
        }

        // Calculate RMS level
        var rms: Float = 0
        vDSP_rmsqv(buffer, 1, &rms, vDSP_Length(buffer.count))
        visualParams.audioLevel = min(rms * 5, 1.0)  // Scale for visibility

        // Perform FFT
        performFFT(buffer)

        // Beat detection
        detectBeat()
    }

    private func performFFT(_ buffer: [Float]) {
        guard let setup = fftSetup, buffer.count >= fftSize else { return }

        // Copy and window (Hann-Window reduziert Spectral Leakage)
        var windowedBuffer = Array(buffer.prefix(fftSize))
        vDSP_vmul(windowedBuffer, 1, hannWindow, 1, &windowedBuffer, 1, vDSP_Length(fftSize))

        // Prepare for FFT
        var realIn = windowedBuffer
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)

        // Perform DFT
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        // Calculate magnitudes (Power Spectrum)
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        for i in 0..<fftSize/2 {
            magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }

        // === Physikalisch korrekte Frequenzband-Berechnung ===

        let sampleRate: Float = 44100
        let binWidth = sampleRate / Float(fftSize)  // Hz pro Bin (~21.5 Hz bei 2048/44100)

        // Berechne Energie pro Band mit korrekten Frequenzgrenzen
        visualParams.subBassLevel = calculateBandEnergy(
            magnitudes: magnitudes,
            minFreq: FrequencyBands.subBassMin,
            maxFreq: FrequencyBands.subBassMax,
            binWidth: binWidth
        )

        visualParams.bassLevel = calculateBandEnergy(
            magnitudes: magnitudes,
            minFreq: FrequencyBands.bassMin,
            maxFreq: FrequencyBands.bassMax,
            binWidth: binWidth
        )

        visualParams.lowMidLevel = calculateBandEnergy(
            magnitudes: magnitudes,
            minFreq: FrequencyBands.lowMidMin,
            maxFreq: FrequencyBands.lowMidMax,
            binWidth: binWidth
        )

        visualParams.midLevel = calculateBandEnergy(
            magnitudes: magnitudes,
            minFreq: FrequencyBands.midMin,
            maxFreq: FrequencyBands.midMax,
            binWidth: binWidth
        )

        visualParams.upperMidLevel = calculateBandEnergy(
            magnitudes: magnitudes,
            minFreq: FrequencyBands.upperMidMin,
            maxFreq: FrequencyBands.upperMidMax,
            binWidth: binWidth
        )

        visualParams.highLevel = calculateBandEnergy(
            magnitudes: magnitudes,
            minFreq: FrequencyBands.highMin,
            maxFreq: FrequencyBands.highMax,
            binWidth: binWidth
        )

        visualParams.airLevel = calculateBandEnergy(
            magnitudes: magnitudes,
            minFreq: FrequencyBands.airMin,
            maxFreq: FrequencyBands.airMax,
            binWidth: binWidth
        )

        // Zusammenfassung für 3-Band Visualisierung
        visualParams.bassTotal = (visualParams.subBassLevel + visualParams.bassLevel) / 2.0
        visualParams.midTotal = (visualParams.lowMidLevel + visualParams.midLevel + visualParams.upperMidLevel) / 3.0
        visualParams.highTotal = (visualParams.highLevel + visualParams.airLevel) / 2.0

        // Normalisierung auf 0-1 Bereich
        let maxBand = max(visualParams.bassTotal, max(visualParams.midTotal, visualParams.highTotal))
        if maxBand > 0 {
            let normalizer = 1.0 / maxBand
            visualParams.bassTotal = min(1.0, visualParams.bassTotal * normalizer)
            visualParams.midTotal = min(1.0, visualParams.midTotal * normalizer)
            visualParams.highTotal = min(1.0, visualParams.highTotal * normalizer)
        }

        // Map to 64 bands (logarithmic scale für Spektrum-Anzeige)
        spectrumData = mapToLogBands(magnitudes, bandCount: 64)

        // === Erweiterte Spektralanalyse ===

        // Dominante Frequenz (mit parabolischer Interpolation für Genauigkeit)
        if let maxIndex = magnitudes.indices.max(by: { magnitudes[$0] < magnitudes[$1] }), maxIndex > 0 && maxIndex < magnitudes.count - 1 {
            // Parabolische Interpolation für sub-bin Genauigkeit
            let alpha = magnitudes[maxIndex - 1]
            let beta = magnitudes[maxIndex]
            let gamma = magnitudes[maxIndex + 1]
            let p = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma)
            visualParams.frequency = (Float(maxIndex) + p) * binWidth
        }

        // Pitch-Schätzung (Frequenz zu MIDI-Note)
        if visualParams.frequency > 20 {
            visualParams.pitch = 69 + 12 * log2(visualParams.frequency / 440.0)
        }

        // Spectral Centroid - "Helligkeit" des Sounds
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        for i in 0..<magnitudes.count {
            let freq = Float(i) * binWidth
            weightedSum += freq * magnitudes[i]
            magnitudeSum += magnitudes[i]
        }
        if magnitudeSum > 0 {
            visualParams.spectralCentroid = weightedSum / magnitudeSum
        }

        // Spectral Flatness - Tonalität vs. Rauschen (Wiener Entropy)
        let geometricMean = exp(magnitudes.map { log($0 + 1e-10) }.reduce(0, +) / Float(magnitudes.count))
        let arithmeticMean = magnitudes.reduce(0, +) / Float(magnitudes.count)
        if arithmeticMean > 0 {
            visualParams.spectralFlatness = geometricMean / arithmeticMean
        }
    }

    /// Berechnet die Energie in einem Frequenzband
    private func calculateBandEnergy(magnitudes: [Float], minFreq: Float, maxFreq: Float, binWidth: Float) -> Float {
        let minBin = max(0, Int(minFreq / binWidth))
        let maxBin = min(magnitudes.count - 1, Int(maxFreq / binWidth))

        guard maxBin > minBin else { return 0 }

        // RMS der Magnitudes im Band
        var sumSquares: Float = 0
        for i in minBin...maxBin {
            sumSquares += magnitudes[i] * magnitudes[i]
        }

        return sqrt(sumSquares / Float(maxBin - minBin + 1))
    }

    private func mapToLogBands(_ linear: [Float], bandCount: Int) -> [Float] {
        var bands = [Float](repeating: 0, count: bandCount)
        let minFreq: Float = 20
        let maxFreq: Float = 20000
        let sampleRate: Float = 44100

        for band in 0..<bandCount {
            // Logarithmic frequency mapping
            let lowFreq = minFreq * pow(maxFreq / minFreq, Float(band) / Float(bandCount))
            let highFreq = minFreq * pow(maxFreq / minFreq, Float(band + 1) / Float(bandCount))

            let lowBin = Int(lowFreq * Float(fftSize) / sampleRate)
            let highBin = Int(highFreq * Float(fftSize) / sampleRate)

            let clampedLow = max(0, min(lowBin, linear.count - 1))
            let clampedHigh = max(clampedLow, min(highBin, linear.count - 1))

            if clampedHigh > clampedLow {
                bands[band] = linear[clampedLow...clampedHigh].reduce(0, +) / Float(clampedHigh - clampedLow + 1)
            }
        }

        return bands
    }

    private func detectBeat() {
        let energy = visualParams.bassLevel

        beatHistory.append(energy)
        if beatHistory.count > beatHistorySize {
            beatHistory.removeFirst()
        }

        guard beatHistory.count >= beatHistorySize else { return }

        let average = beatHistory.reduce(0, +) / Float(beatHistory.count)
        let variance = beatHistory.map { ($0 - average) * ($0 - average) }.reduce(0, +) / Float(beatHistory.count)
        let threshold = average + sqrt(variance) * 1.5

        let timeSinceLastBeat = Date().timeIntervalSince(lastBeatTime)

        if energy > threshold && energy > 0.3 && timeSinceLastBeat > 0.2 {
            beatDetected = true
            lastBeatTime = Date()

            // Update beat phase
            visualParams.beatPhase = 0
        } else {
            beatDetected = false
            visualParams.beatPhase = min(1, visualParams.beatPhase + Float(visualParams.deltaTime) * 2)
        }
    }

    // MARK: - Bio Input

    /// Update bio-data from HealthKit
    func updateBioData(hrv: Double, coherence: Double, heartRate: Double) {
        visualParams.hrv = Float(hrv / 100.0)  // Normalize to 0-1
        visualParams.coherence = Float(coherence / 100.0)
        visualParams.heartRate = Float(heartRate)
        visualParams.stress = 1.0 - visualParams.coherence  // Inverse of coherence
    }

    // MARK: - Update Loop

    private func updateVisualParams() {
        let now = Date()
        visualParams.deltaTime = now.timeIntervalSince(lastUpdateTime)
        visualParams.time += visualParams.deltaTime
        lastUpdateTime = now

        // Calculate derived parameters
        visualParams.energy = (visualParams.audioLevel + visualParams.bassLevel * 0.5) *
                             (1.0 + visualParams.coherence * 0.5)

        visualParams.flow = visualParams.coherence * 0.7 + visualParams.hrv * 0.3

        visualParams.intensity = visualParams.energy * (1.0 + (1.0 - visualParams.flow) * 0.5)

        // Color hue based on coherence (red=stress, green=flow)
        visualParams.colorHue = visualParams.coherence * 0.4  // 0=red, 0.4=green

        // Breath phase simulation (if no real data)
        visualParams.breathPhase = Float((sin(visualParams.time * 0.5) + 1) / 2)
    }

    // MARK: - OSC Output

    /// Get OSC-ready parameter dictionary - Alle Parameter für externe Software
    func getOSCParameters() -> [String: Float] {
        return [
            // === Audio Level ===
            "audio/level": visualParams.audioLevel,

            // === 7-Band Frequenzanalyse (physikalisch korrekt) ===
            "audio/bands/subBass": visualParams.subBassLevel,    // 20-60 Hz
            "audio/bands/bass": visualParams.bassLevel,          // 60-250 Hz
            "audio/bands/lowMid": visualParams.lowMidLevel,      // 250-500 Hz
            "audio/bands/mid": visualParams.midLevel,            // 500-2000 Hz
            "audio/bands/upperMid": visualParams.upperMidLevel,  // 2000-4000 Hz
            "audio/bands/high": visualParams.highLevel,          // 4000-8000 Hz
            "audio/bands/air": visualParams.airLevel,            // 8000-20000 Hz

            // === 3-Band Zusammenfassung ===
            "audio/bassTotal": visualParams.bassTotal,           // 20-250 Hz
            "audio/midTotal": visualParams.midTotal,             // 250-4000 Hz
            "audio/highTotal": visualParams.highTotal,           // 4000-20000 Hz

            // === Spektralanalyse ===
            "audio/frequency": visualParams.frequency,           // Dominante Frequenz Hz
            "audio/pitch": visualParams.pitch,                   // MIDI Note (69 = A4)
            "audio/centroid": visualParams.spectralCentroid,     // Helligkeit Hz
            "audio/flatness": visualParams.spectralFlatness,     // 0=tonal, 1=noise

            // === Rhythmus ===
            "audio/beatPhase": visualParams.beatPhase,           // 0-1 Beat Zyklus
            "audio/tempo": visualParams.tempo,                   // BPM

            // === Bio-Daten ===
            "bio/hrv": visualParams.hrv,                         // 0-1 HRV normalisiert
            "bio/coherence": visualParams.coherence,             // 0-1 HeartMath Score
            "bio/heartRate": visualParams.heartRate,             // BPM
            "bio/stress": visualParams.stress,                   // 0-1 Stress Index
            "bio/breathPhase": visualParams.breathPhase,         // 0-1 Atem Zyklus

            // === Kombinierte Parameter ===
            "combined/energy": visualParams.energy,              // Audio × Bio Energie
            "combined/flow": visualParams.flow,                  // Flow State
            "combined/intensity": visualParams.intensity,        // Visual Intensität
            "combined/colorHue": visualParams.colorHue,          // 0-1 Farbe

            // === Timing ===
            "time": Float(visualParams.time)
        ]
    }

    /// Get detailed frequency band data for visualization
    func getFrequencyBandData() -> [(name: String, range: String, level: Float, color: String)] {
        return [
            ("Sub-Bass", "20-60 Hz", visualParams.subBassLevel, "#FF0066"),      // Magenta
            ("Bass", "60-250 Hz", visualParams.bassLevel, "#FF3366"),            // Pink
            ("Low-Mid", "250-500 Hz", visualParams.lowMidLevel, "#FF6600"),      // Orange
            ("Mid", "500-2k Hz", visualParams.midLevel, "#FFCC00"),              // Gold
            ("Upper-Mid", "2k-4k Hz", visualParams.upperMidLevel, "#66FF00"),    // Lime
            ("High", "4k-8k Hz", visualParams.highLevel, "#00FFCC"),             // Cyan
            ("Air", "8k-20k Hz", visualParams.airLevel, "#00CCFF")               // Sky Blue
        ]
    }
}

// MARK: - Unified Visualizer View

/// Master visualizer that renders the current mode
struct UnifiedVisualizer: View {
    @ObservedObject var engine: UnifiedVisualSoundEngine

    var body: some View {
        ZStack {
            // Background
            Color.black

            // Active visualization mode
            Group {
                switch engine.currentMode {
                case .liquidLight:
                    LiquidLightVisualizer(params: engine.visualParams)
                case .particles:
                    ParticleVisualizer(params: engine.visualParams)
                case .spectrum:
                    SpectrumVisualizer(data: engine.spectrumData, params: engine.visualParams)
                case .waveform:
                    WaveformVisualizer(data: engine.waveformData, params: engine.visualParams)
                case .mandala:
                    MandalaVisualizer(params: engine.visualParams)
                case .cymatics:
                    CymaticsVisualizer(params: engine.visualParams)
                case .vaporwave:
                    VaporwaveVisualizer(params: engine.visualParams, spectrum: engine.spectrumData)
                case .nebula:
                    NebulaVisualizer(params: engine.visualParams)
                case .kaleidoscope:
                    KaleidoscopeVisualizer(params: engine.visualParams)
                case .flowField:
                    FlowFieldVisualizer(params: engine.visualParams)
                }
            }

            // Beat flash overlay
            if engine.beatDetected {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .animation(.easeOut(duration: 0.1), value: engine.beatDetected)
            }
        }
        .clipped()
    }
}
