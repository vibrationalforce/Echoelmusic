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
        case rainbow = "Rainbow"               // Oktav-analoges Regenbogen-Spektrum
        case particles = "Particles"           // Bio-reactive particles
        case spectrum = "Spectrum"             // FFT analyzer
        case waveform = "Waveform"            // Oscilloscope
        case mandala = "Mandala"              // Sacred geometry
        case cymatics = "Cymatics"            // Chladni patterns
        case vaporwave = "Vaporwave"          // Neon grid aesthetic
        case nebula = "Nebula"                // Space clouds
        case kaleidoscope = "Kaleidoscope"    // Mirror symmetry
        case flowField = "Flow Field"         // Vector field particles
        case octaveMap = "Octave Map"         // Bio→Audio→Licht Transposition

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .liquidLight: return "drop.fill"
            case .rainbow: return "rainbow"
            case .particles: return "sparkles"
            case .spectrum: return "chart.bar.fill"
            case .waveform: return "waveform.path"
            case .mandala: return "circle.hexagongrid.fill"
            case .cymatics: return "waveform.circle.fill"
            case .vaporwave: return "square.grid.3x3.fill"
            case .nebula: return "cloud.fill"
            case .kaleidoscope: return "camera.filters"
            case .flowField: return "wind"
            case .octaveMap: return "arrow.up.arrow.down"
            }
        }

        var description: String {
            switch self {
            case .liquidLight: return "Flowing light streams synced to coherence"
            case .rainbow: return "Physikalisch korrektes Regenbogen-Spektrum"
            case .particles: return "Bio-reactive particle physics"
            case .spectrum: return "Real-time frequency analyzer"
            case .waveform: return "Audio oscilloscope display"
            case .mandala: return "Sacred geometry with radial symmetry"
            case .cymatics: return "Sound-driven Chladni patterns"
            case .vaporwave: return "Retro neon grid aesthetic"
            case .nebula: return "Cosmic gas clouds"
            case .kaleidoscope: return "Mirrored audio-reactive patterns"
            case .flowField: return "Particles following vector fields"
            case .octaveMap: return "Bio→Audio→Licht Oktav-Transposition"
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

    // MARK: - Oktav-Analoge Frequenz-Übersetzung

    /// Physikalisch korrekte Oktav-Transposition zwischen Frequenzbereichen
    /// Basierend auf dem Prinzip: Oktave = Frequenz × 2
    struct OctaveTransposition {

        // === Frequenzbereiche ===

        // Bio-Frequenzen (Infraschall)
        static let breathMin: Float = 0.1        // ~6 Atemzüge/min
        static let breathMax: Float = 0.5        // ~30 Atemzüge/min
        static let heartRateMin: Float = 0.5     // ~30 BPM
        static let heartRateMax: Float = 3.5     // ~210 BPM
        static let hrvMin: Float = 0.04          // 0.04-0.4 Hz HRV Band
        static let hrvMax: Float = 0.4

        // Audio-Frequenzen
        static let audioMin: Float = 20          // Untere Hörgrenze
        static let audioMax: Float = 20000       // Obere Hörgrenze
        static let audioOctaves: Float = 9.97    // log2(20000/20) ≈ 10 Oktaven

        // Sichtbares Licht (Elektromagnetisches Spektrum)
        static let lightMinTHz: Float = 400      // Rot (750 nm)
        static let lightMaxTHz: Float = 750      // Violett (400 nm)
        static let lightOctaves: Float = 0.91    // log2(750/400) ≈ 1 Oktave

        // Wellenlängen in nm
        static let redWavelength: Float = 700
        static let violetWavelength: Float = 400

        // === Bio → Audio Transposition ===

        /// Transponiert eine Bio-Frequenz in den hörbaren Bereich
        /// Heart Rate 1 Hz → ~64 Hz (6 Oktaven hoch) = tiefes C
        static func bioToAudio(bioFrequency: Float, targetOctave: Int = 6) -> Float {
            // Oktaven nach oben transponieren
            return bioFrequency * pow(2.0, Float(targetOctave))
        }

        /// Heart Rate (BPM) zu Audio-Frequenz
        /// 60 BPM = 1 Hz → 64 Hz (tiefes Sub-Bass C)
        /// 120 BPM = 2 Hz → 128 Hz (tiefes C)
        static func heartRateToAudio(bpm: Float) -> Float {
            let heartFrequency = bpm / 60.0  // BPM zu Hz
            return bioToAudio(bioFrequency: heartFrequency, targetOctave: 6)
        }

        /// Atem-Frequenz zu Audio
        /// 12 Atemzüge/min = 0.2 Hz → 51.2 Hz (6 Oktaven hoch)
        static func breathToAudio(breathsPerMinute: Float) -> Float {
            let breathFrequency = breathsPerMinute / 60.0
            return bioToAudio(bioFrequency: breathFrequency, targetOctave: 8)
        }

        /// HRV-Frequenz zu Audio (für Modulation)
        /// HRV 0.1 Hz → 409.6 Hz (12 Oktaven hoch, im Vocal-Bereich)
        static func hrvToAudio(hrvFrequency: Float) -> Float {
            return bioToAudio(bioFrequency: hrvFrequency, targetOctave: 12)
        }

        // === Audio → Licht (Regenbogen) Transposition ===

        /// Konvertiert Audio-Frequenz zu sichtbarer Licht-Frequenz
        /// 20 Hz - 20 kHz (~10 Oktaven) → 400-750 THz (~1 Oktave)
        /// Die 10 Audio-Oktaven werden auf die 1 Licht-Oktave komprimiert
        static func audioToLight(audioFrequency: Float) -> Float {
            // Position im Audio-Spektrum (0-1, logarithmisch)
            let audioPosition = log2(audioFrequency / audioMin) / audioOctaves
            let clampedPosition = max(0, min(1, audioPosition))

            // Auf Licht-Spektrum mappen (logarithmisch)
            return lightMinTHz * pow(lightMaxTHz / lightMinTHz, clampedPosition)
        }

        /// Konvertiert Licht-Frequenz (THz) zu Wellenlänge (nm)
        static func frequencyToWavelength(thz: Float) -> Float {
            // c = λ × f → λ = c / f
            // c = 299792458 m/s, f in THz = 10^12 Hz
            return 299792.458 / thz  // Ergebnis in nm
        }

        /// Konvertiert Audio-Frequenz direkt zu Wellenlänge (nm)
        static func audioToWavelength(audioFrequency: Float) -> Float {
            let lightFreq = audioToLight(audioFrequency: audioFrequency)
            return frequencyToWavelength(thz: lightFreq)
        }

        // === Wellenlänge → Farbe (Regenbogen) ===

        /// Konvertiert Wellenlänge (380-780 nm) zu RGB
        /// Basierend auf CIE 1931 Farbwahrnehmung
        static func wavelengthToRGB(wavelength: Float) -> (r: Float, g: Float, b: Float) {
            var r: Float = 0, g: Float = 0, b: Float = 0

            let wl = wavelength

            if wl >= 380 && wl < 440 {
                r = -(wl - 440) / (440 - 380)
                g = 0
                b = 1
            } else if wl >= 440 && wl < 490 {
                r = 0
                g = (wl - 440) / (490 - 440)
                b = 1
            } else if wl >= 490 && wl < 510 {
                r = 0
                g = 1
                b = -(wl - 510) / (510 - 490)
            } else if wl >= 510 && wl < 580 {
                r = (wl - 510) / (580 - 510)
                g = 1
                b = 0
            } else if wl >= 580 && wl < 645 {
                r = 1
                g = -(wl - 645) / (645 - 580)
                b = 0
            } else if wl >= 645 && wl <= 780 {
                r = 1
                g = 0
                b = 0
            }

            // Intensitätsanpassung an den Rändern des sichtbaren Spektrums
            var intensity: Float = 1.0
            if wl >= 380 && wl < 420 {
                intensity = 0.3 + 0.7 * (wl - 380) / (420 - 380)
            } else if wl >= 700 && wl <= 780 {
                intensity = 0.3 + 0.7 * (780 - wl) / (780 - 700)
            }

            return (r * intensity, g * intensity, b * intensity)
        }

        /// Audio-Frequenz direkt zu RGB Farbe (Regenbogen-Mapping)
        static func audioToRGB(audioFrequency: Float) -> (r: Float, g: Float, b: Float) {
            let wavelength = audioToWavelength(audioFrequency: audioFrequency)
            return wavelengthToRGB(wavelength: wavelength)
        }

        /// Audio-Frequenz zu SwiftUI Color
        static func audioToColor(audioFrequency: Float) -> Color {
            let rgb = audioToRGB(audioFrequency: audioFrequency)
            return Color(red: Double(rgb.r), green: Double(rgb.g), blue: Double(rgb.b))
        }

        // === Regenbogen-Farbpalette für Frequenzbänder ===

        /// Gibt die physikalisch korrekte Regenbogenfarbe für ein Frequenzband zurück
        static func bandToRainbowColor(bandCenterFrequency: Float) -> Color {
            return audioToColor(audioFrequency: bandCenterFrequency)
        }

        /// Standard-Frequenzband Mitten mit ihren Regenbogenfarben
        static let bandCenters: [(name: String, freq: Float, wavelength: Float)] = [
            ("Sub-Bass", 40, 695),     // 20-60 Hz → Rot
            ("Bass", 125, 640),        // 60-250 Hz → Orange
            ("Low-Mid", 355, 585),     // 250-500 Hz → Gelb
            ("Mid", 1000, 530),        // 500-2000 Hz → Grün
            ("Upper-Mid", 2830, 485),  // 2000-4000 Hz → Cyan
            ("High", 5660, 450),       // 4000-8000 Hz → Blau
            ("Air", 12650, 415)        // 8000-20000 Hz → Violett
        ]

        // === Bio zu Regenbogen (über Audio-Transposition) ===

        /// Heart Rate zu Regenbogenfarbe
        /// Niedriger Puls (60 BPM) → Rot (ruhig)
        /// Hoher Puls (180 BPM) → Violett (aktiv)
        static func heartRateToColor(bpm: Float) -> Color {
            // Normalisiere BPM auf 0-1 (40-200 BPM Bereich)
            let normalized = (bpm - 40) / 160
            let clamped = max(0, min(1, normalized))

            // Mappe auf Wellenlänge (Rot → Violett)
            let wavelength = redWavelength - clamped * (redWavelength - violetWavelength)
            let rgb = wavelengthToRGB(wavelength: wavelength)
            return Color(red: Double(rgb.r), green: Double(rgb.g), blue: Double(rgb.b))
        }

        /// Coherence zu Regenbogenfarbe
        /// Niedrige Coherence (0) → Rot (Stress)
        /// Hohe Coherence (1) → Grün (Flow)
        static func coherenceToColor(coherence: Float) -> Color {
            // Mappe 0-1 auf Rot-Gelb-Grün
            let wavelength = 650 - coherence * 120  // 650nm (rot) → 530nm (grün)
            let rgb = wavelengthToRGB(wavelength: wavelength)
            return Color(red: Double(rgb.r), green: Double(rgb.g), blue: Double(rgb.b))
        }

        // === Oktaven-Rechner ===

        /// Berechnet die Anzahl der Oktaven zwischen zwei Frequenzen
        static func octavesBetween(freq1: Float, freq2: Float) -> Float {
            return log2(freq2 / freq1)
        }

        /// Transponiert eine Frequenz um n Oktaven
        static func transpose(frequency: Float, octaves: Float) -> Float {
            return frequency * pow(2.0, octaves)
        }
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
            vDSP_DFT_DestroySetup(setup)
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
            visualizerForCurrentMode

            // Beat flash overlay
            if engine.beatDetected {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .animation(.easeOut(duration: 0.1), value: engine.beatDetected)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var visualizerForCurrentMode: some View {
        switch engine.currentMode {
        case .liquidLight:
            LiquidLightVisualizer(params: engine.visualParams)
        case .rainbow:
            RainbowSpectrumVisualizer(params: engine.visualParams, spectrum: engine.spectrumData)
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
        case .octaveMap:
            OctaveTranspositionVisualizer(params: engine.visualParams)
        }
    }
}
