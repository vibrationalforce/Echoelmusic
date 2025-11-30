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
        // From Audio
        var audioLevel: Float = 0               // 0-1 RMS level
        var bassLevel: Float = 0                // 0-1 low frequency energy
        var midLevel: Float = 0                 // 0-1 mid frequency energy
        var highLevel: Float = 0                // 0-1 high frequency energy
        var frequency: Float = 0                // Dominant frequency Hz
        var tempo: Float = 120                  // Detected BPM
        var beatPhase: Float = 0                // 0-1 beat cycle

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

        // Copy and window
        var windowedBuffer = Array(buffer.prefix(fftSize))
        vDSP_vmul(windowedBuffer, 1, hannWindow, 1, &windowedBuffer, 1, vDSP_Length(fftSize))

        // Prepare for FFT
        var realIn = windowedBuffer
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)

        // Perform DFT
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        for i in 0..<fftSize/2 {
            magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }

        // Normalize
        var maxMag: Float = 0
        vDSP_maxv(magnitudes, 1, &maxMag, vDSP_Length(magnitudes.count))
        if maxMag > 0 {
            var scale = 1.0 / maxMag
            vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(magnitudes.count))
        }

        // Map to 64 bands (logarithmic scale)
        spectrumData = mapToLogBands(magnitudes, bandCount: 64)

        // Calculate band energies
        let bandSize = spectrumData.count / 3
        visualParams.bassLevel = spectrumData[0..<bandSize].reduce(0, +) / Float(bandSize)
        visualParams.midLevel = spectrumData[bandSize..<bandSize*2].reduce(0, +) / Float(bandSize)
        visualParams.highLevel = spectrumData[bandSize*2..<spectrumData.count].reduce(0, +) / Float(bandSize)

        // Find dominant frequency
        if let maxIndex = magnitudes.indices.max(by: { magnitudes[$0] < magnitudes[$1] }) {
            visualParams.frequency = Float(maxIndex) * 44100.0 / Float(fftSize)
        }
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

    /// Get OSC-ready parameter dictionary
    func getOSCParameters() -> [String: Float] {
        return [
            "audioLevel": visualParams.audioLevel,
            "bassLevel": visualParams.bassLevel,
            "midLevel": visualParams.midLevel,
            "highLevel": visualParams.highLevel,
            "frequency": visualParams.frequency,
            "beatPhase": visualParams.beatPhase,
            "hrv": visualParams.hrv,
            "coherence": visualParams.coherence,
            "heartRate": visualParams.heartRate,
            "stress": visualParams.stress,
            "energy": visualParams.energy,
            "flow": visualParams.flow,
            "intensity": visualParams.intensity,
            "colorHue": visualParams.colorHue,
            "time": Float(visualParams.time)
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
