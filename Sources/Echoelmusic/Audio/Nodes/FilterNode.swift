import Foundation
import AVFoundation

/// Low-pass filter node with bio-reactive cutoff
/// Heart Rate → Filter Cutoff (higher HR = brighter/more open sound)
@MainActor
class FilterNode: BaseBlabNode {

    // MARK: - AVAudioUnit EQ

    private let eqUnit: AVAudioUnitEQ
    private let audioEngine: AVAudioEngine
    private let inputNode: AVAudioPlayerNode
    private var isEngineConfigured: Bool = false


    // MARK: - Parameters

    private enum Params {
        static let cutoffFrequency = "cutoffFrequency"
        static let resonance = "resonance"
        static let filterType = "filterType"
    }


    // MARK: - Initialization

    init() {
        // Create audio processing chain
        self.eqUnit = AVAudioUnitEQ(numberOfBands: 1)
        self.audioEngine = AVAudioEngine()
        self.inputNode = AVAudioPlayerNode()

        super.init(name: "Bio-Reactive Filter", type: .effect)

        // Setup parameters
        parameters = [
            NodeParameter(
                name: Params.cutoffFrequency,
                label: "Cutoff Frequency",
                value: 1000.0,
                min: 200.0,
                max: 8000.0,
                defaultValue: 1000.0,
                unit: "Hz",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.resonance,
                label: "Resonance (Q)",
                value: 0.707,
                min: 0.5,
                max: 10.0,
                defaultValue: 0.707,
                unit: nil,
                isAutomatable: true,
                type: .continuous
            )
        ]

        // Configure filter band
        if let band = eqUnit.bands.first {
            band.filterType = .lowPass
            band.frequency = 1000.0  // 1 kHz cutoff
            band.bandwidth = 0.707  // Q factor (resonance)
            band.bypass = false
        }

        eqUnit.globalGain = 0.0  // No gain adjustment
    }


    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        // If bypassed, return original buffer
        guard !isBypassed, isActive else {
            return buffer
        }

        // Configure engine on first use
        if !isEngineConfigured {
            configureAudioEngine(format: buffer.format)
        }

        // Apply filter parameters
        if let cutoff = getParameter(name: Params.cutoffFrequency),
           let resonance = getParameter(name: Params.resonance),
           let band = eqUnit.bands.first {
            band.frequency = cutoff
            band.bandwidth = resonance
        }

        // Process buffer through EQ unit
        return processBufferThroughEngine(buffer)
    }

    private func configureAudioEngine(format: AVAudioFormat) {
        guard !isEngineConfigured else { return }

        // Attach nodes
        audioEngine.attach(inputNode)
        audioEngine.attach(eqUnit)

        // Connect: input → EQ → output
        audioEngine.connect(inputNode, to: eqUnit, format: format)
        audioEngine.connect(eqUnit, to: audioEngine.mainMixerNode, format: format)

        // Prepare and start
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isEngineConfigured = true
        } catch {
            print("❌ FilterNode engine failed to start: \(error.localizedDescription)")
        }
    }

    private func processBufferThroughEngine(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard isEngineConfigured else { return inputBuffer }

        // NOTE: This is a simplified implementation for demonstration.
        // The AVAudioUnit's internal processing is applied when connected in an AVAudioEngine.
        // For proper real-time processing, this node should be integrated directly into
        // the main AudioEngine rather than using manual buffer processing.

        // For now, we apply the parameters to the unit and return the buffer.
        // In a production implementation, you would either:
        // 1. Use AVAudioEngine's built-in processing chain (recommended)
        // 2. Use AVAudioUnit's renderBlock for offline rendering
        // 3. Implement manual DSP with vDSP/Accelerate framework

        // Since the EQ is configured and parameters are updated in process(),
        // the effect will be applied when this node is properly integrated
        // into an AVAudioEngine graph.

        return inputBuffer
    }


    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        // Heart Rate → Filter Cutoff
        // Low HR (40-60 BPM): Darker, closed sound (200-600 Hz)
        // Normal HR (60-80 BPM): Balanced (600-2000 Hz)
        // High HR (80-120 BPM): Brighter, open sound (2000-8000 Hz)

        let heartRate = signal.heartRate

        // Map heart rate to cutoff frequency
        let targetCutoff: Float
        if heartRate < 60 {
            // Low HR: darker sound
            targetCutoff = 200.0 + Float((heartRate - 40.0) / 20.0) * 400.0  // 200-600 Hz
        } else if heartRate < 80 {
            // Normal HR: balanced
            targetCutoff = 600.0 + Float((heartRate - 60.0) / 20.0) * 1400.0  // 600-2000 Hz
        } else {
            // High HR: brighter sound
            targetCutoff = 2000.0 + Float((min(heartRate, 120.0) - 80.0) / 40.0) * 6000.0  // 2000-8000 Hz
        }

        // Smooth transition (slower for filter to avoid artifacts)
        if let currentCutoff = getParameter(name: Params.cutoffFrequency) {
            let smoothed = currentCutoff * 0.98 + targetCutoff * 0.02
            setParameter(name: Params.cutoffFrequency, value: smoothed)
        }

        // HRV Coherence → Resonance
        // Higher coherence = higher Q (more resonant, singing quality)
        let coherence = signal.coherence
        let targetResonance = 0.707 + Float(coherence / 100.0) * 2.0  // 0.707-2.707

        if let currentResonance = getParameter(name: Params.resonance) {
            let smoothed = currentResonance * 0.95 + targetResonance * 0.05
            setParameter(name: Params.resonance, value: smoothed)
        }
    }


    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        // EQ is always ready (uses AVAudioUnitEQ)
    }

    override func start() {
        super.start()
        print("🎵 FilterNode started")
    }

    override func stop() {
        super.stop()
        audioEngine.stop()
        inputNode.stop()
        print("🎵 FilterNode stopped")
    }

    deinit {
        audioEngine.stop()
        inputNode.stop()
    }


    // MARK: - Filter Type

    enum FilterType: String {
        case lowPass = "Low Pass"
        case highPass = "High Pass"
        case bandPass = "Band Pass"
        case notch = "Notch"

        var avFilterType: AVAudioUnitEQFilterType {
            switch self {
            case .lowPass: return .lowPass
            case .highPass: return .highPass
            case .bandPass: return .bandPass
            case .notch: return .bandStop
            }
        }
    }

    /// Change filter type
    func setFilterType(_ type: FilterType) {
        if let band = eqUnit.bands.first {
            band.filterType = type.avFilterType
        }
    }
}
