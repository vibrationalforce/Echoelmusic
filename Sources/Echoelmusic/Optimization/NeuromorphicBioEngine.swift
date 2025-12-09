import Foundation
import Accelerate
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// NEUROMORPHIC BIO-PROCESSING ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Bio-inspired signal processing:
// • Spiking neural networks for pattern detection
// • Hebbian learning for bio-reactive adaptation
// • Cochlear model for perceptual audio
// • HRV coherence neural classifier
// • Predictive bio-state estimation
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Leaky Integrate-and-Fire Neuron

/// Bio-inspired spiking neuron for pattern detection
@frozen
public struct LIFNeuron {

    // Membrane parameters
    private var membrane: Float = 0
    private let tau: Float           // Membrane time constant
    private let threshold: Float     // Spike threshold
    private let resetPotential: Float
    private let restingPotential: Float

    // Refractory period
    private var refractoryCounter: Int = 0
    private let refractoryPeriod: Int

    public init(
        tau: Float = 20.0,           // ms
        threshold: Float = 1.0,
        resetPotential: Float = 0.0,
        restingPotential: Float = 0.0,
        refractoryPeriod: Int = 2    // samples
    ) {
        self.tau = tau
        self.threshold = threshold
        self.resetPotential = resetPotential
        self.restingPotential = restingPotential
        self.refractoryPeriod = refractoryPeriod
        self.membrane = restingPotential
    }

    /// Process input and return spike (true/false)
    @inlinable
    public mutating func process(input: Float, dt: Float = 1.0) -> Bool {
        // Refractory check
        if refractoryCounter > 0 {
            refractoryCounter -= 1
            return false
        }

        // Leaky integration: dV/dt = (V_rest - V + I) / tau
        let leak = (restingPotential - membrane) / tau
        membrane += (leak + input) * dt

        // Check for spike
        if membrane >= threshold {
            membrane = resetPotential
            refractoryCounter = refractoryPeriod
            return true
        }

        return false
    }

    /// Reset neuron state
    @inlinable
    public mutating func reset() {
        membrane = restingPotential
        refractoryCounter = 0
    }
}

// MARK: - Spiking Neural Network Layer

/// Layer of spiking neurons for audio feature detection
public final class SpikingNeuralLayer {

    private var neurons: [LIFNeuron]
    private var weights: [[Float]]
    private let inputSize: Int
    private let outputSize: Int

    // Spike history for STDP learning
    private var preSpikes: [[Int]]   // Input spike times
    private var postSpikes: [Int]    // Output spike times
    private var timeStep: Int = 0

    public init(inputSize: Int, outputSize: Int) {
        self.inputSize = inputSize
        self.outputSize = outputSize

        // Initialize neurons
        neurons = (0..<outputSize).map { _ in
            LIFNeuron(tau: 20, threshold: 1.0)
        }

        // Initialize random weights
        weights = (0..<outputSize).map { _ in
            (0..<inputSize).map { _ in Float.random(in: 0...0.5) }
        }

        preSpikes = [[Int]](repeating: [], count: inputSize)
        postSpikes = [Int](repeating: -1000, count: outputSize)
    }

    /// Process input spikes and return output spikes
    public func process(inputSpikes: [Bool], dt: Float = 1.0) -> [Bool] {
        timeStep += 1

        // Record pre-synaptic spikes
        for i in 0..<inputSize {
            if inputSpikes[i] {
                preSpikes[i].append(timeStep)
                if preSpikes[i].count > 100 {
                    preSpikes[i].removeFirst()
                }
            }
        }

        // Compute weighted input for each neuron
        var outputSpikes = [Bool](repeating: false, count: outputSize)

        for n in 0..<outputSize {
            var totalInput: Float = 0
            for i in 0..<inputSize {
                if inputSpikes[i] {
                    totalInput += weights[n][i]
                }
            }

            outputSpikes[n] = neurons[n].process(input: totalInput, dt: dt)

            if outputSpikes[n] {
                postSpikes[n] = timeStep
            }
        }

        return outputSpikes
    }

    /// Apply STDP (Spike-Timing Dependent Plasticity) learning
    public func applySTDP(learningRate: Float = 0.01) {
        let tauPlus: Float = 20.0   // LTP time constant
        let tauMinus: Float = 20.0  // LTD time constant
        let aPlus: Float = 0.1      // LTP amplitude
        let aMinus: Float = 0.12    // LTD amplitude

        for n in 0..<outputSize {
            let tPost = Float(postSpikes[n])

            for i in 0..<inputSize {
                for tPre in preSpikes[i].suffix(20) {
                    let dt = tPost - Float(tPre)

                    let dw: Float
                    if dt > 0 {
                        // LTP: post after pre
                        dw = aPlus * exp(-dt / tauPlus)
                    } else {
                        // LTD: pre after post
                        dw = -aMinus * exp(dt / tauMinus)
                    }

                    weights[n][i] = max(0, min(1, weights[n][i] + learningRate * dw))
                }
            }
        }
    }

    /// Reset layer state
    public func reset() {
        for i in 0..<neurons.count {
            neurons[i].reset()
        }
        preSpikes = [[Int]](repeating: [], count: inputSize)
        postSpikes = [Int](repeating: -1000, count: outputSize)
        timeStep = 0
    }
}

// MARK: - Cochlear Model

/// Bio-inspired cochlear filterbank for perceptual audio
public final class CochlearModel {

    /// Gammatone filter bank parameters
    public struct GammatoneFilter {
        let centerFreq: Float
        let bandwidth: Float
        let order: Int
        var state: [Float]  // Filter state

        init(centerFreq: Float, sampleRate: Float, order: Int = 4) {
            self.centerFreq = centerFreq
            self.order = order

            // ERB (Equivalent Rectangular Bandwidth)
            self.bandwidth = 24.7 * (4.37 * centerFreq / 1000 + 1)

            // Initialize state
            self.state = [Float](repeating: 0, count: order * 2)
        }
    }

    private var filters: [GammatoneFilter]
    private let sampleRate: Float
    private let numChannels: Int

    public init(numChannels: Int = 64, sampleRate: Float = 44100) {
        self.numChannels = numChannels
        self.sampleRate = sampleRate

        // Create filterbank with logarithmically spaced center frequencies
        let minFreq: Float = 50
        let maxFreq: Float = min(sampleRate / 2 - 100, 16000)

        filters = (0..<numChannels).map { i in
            let ratio = Float(i) / Float(numChannels - 1)
            let freq = minFreq * pow(maxFreq / minFreq, ratio)
            return GammatoneFilter(centerFreq: freq, sampleRate: sampleRate)
        }
    }

    /// Process audio through cochlear filterbank
    public func process(_ input: [Float]) -> [[Float]] {
        var outputs = [[Float]](repeating: [Float](repeating: 0, count: input.count),
                                 count: numChannels)

        for ch in 0..<numChannels {
            outputs[ch] = processChannel(input, channel: ch)
        }

        return outputs
    }

    /// Process single channel with gammatone filter
    private func processChannel(_ input: [Float], channel: Int) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)
        let cf = filters[channel].centerFreq
        let bw = filters[channel].bandwidth

        // Gammatone impulse response coefficients
        let t = 1.0 / sampleRate
        let a = exp(-2 * .pi * bw * t)
        let b = 2 * .pi * cf * t

        // 4th order gammatone (cascade of 4 first-order filters)
        var y1: Float = 0, y2: Float = 0, y3: Float = 0, y4: Float = 0

        for i in 0..<input.count {
            let x = input[i]

            // First stage
            let cosB = CORDICEngine.cos(b * Float(i))
            let sinB = CORDICEngine.sin(b * Float(i))

            y1 = a * y1 + (1 - a) * x * cosB
            y2 = a * y2 + (1 - a) * y1
            y3 = a * y3 + (1 - a) * y2
            y4 = a * y4 + (1 - a) * y3

            // Envelope extraction (half-wave rectification + smoothing)
            output[i] = max(0, y4)
        }

        return output
    }

    /// Get basilar membrane response (simplified)
    public func getBasilarResponse(_ input: [Float]) -> [Float] {
        let channels = process(input)

        // Sum across time to get channel energies
        return channels.map { channel in
            var energy: Float = 0
            vDSP_measqv(channel, 1, &energy, vDSP_Length(channel.count))
            return sqrt(energy / Float(channel.count))
        }
    }
}

// MARK: - HRV Neural Classifier

/// Neural network for HRV coherence state classification
public final class HRVNeuralClassifier {

    /// Coherence state
    public enum CoherenceState: Int, CaseIterable {
        case veryLow = 0
        case low = 1
        case medium = 2
        case high = 3
        case veryHigh = 4
    }

    // Network architecture: input(8) -> hidden(16) -> output(5)
    private var weightsIH: [[Float]]  // Input to hidden
    private var weightsHO: [[Float]]  // Hidden to output
    private var biasH: [Float]
    private var biasO: [Float]

    private let inputSize = 8
    private let hiddenSize = 16
    private let outputSize = 5

    // Feature extraction
    private var rrHistory: [Float] = []
    private let historySize = 60  // Last 60 RR intervals (~1 minute)

    public init() {
        // Initialize with pre-trained weights (simplified random init for demo)
        weightsIH = (0..<hiddenSize).map { _ in
            (0..<inputSize).map { _ in Float.random(in: -0.5...0.5) }
        }
        weightsHO = (0..<outputSize).map { _ in
            (0..<hiddenSize).map { _ in Float.random(in: -0.5...0.5) }
        }
        biasH = [Float](repeating: 0.1, count: hiddenSize)
        biasO = [Float](repeating: 0.1, count: outputSize)
    }

    /// Add RR interval and classify coherence
    public func addRRInterval(_ rr: Float) -> (state: CoherenceState, confidence: Float) {
        rrHistory.append(rr)
        if rrHistory.count > historySize {
            rrHistory.removeFirst()
        }

        guard rrHistory.count >= 10 else {
            return (.medium, 0.5)
        }

        // Extract features
        let features = extractFeatures()

        // Forward pass
        let (state, confidence) = classify(features)

        return (state, confidence)
    }

    /// Extract HRV features from RR history
    private func extractFeatures() -> [Float] {
        var features = [Float](repeating: 0, count: inputSize)

        let count = Float(rrHistory.count)

        // Time-domain features
        // 1. Mean RR
        var meanRR: Float = 0
        vDSP_meanv(rrHistory, 1, &meanRR, vDSP_Length(rrHistory.count))
        features[0] = meanRR / 1000  // Normalize to seconds

        // 2. SDNN (Standard deviation)
        var variance: Float = 0
        var mean: Float = 0
        vDSP_normalize(rrHistory, 1, nil, 1, &mean, &variance, vDSP_Length(rrHistory.count))
        features[1] = sqrt(variance) / 100  // Normalize

        // 3. RMSSD
        var diffs = [Float](repeating: 0, count: rrHistory.count - 1)
        for i in 0..<diffs.count {
            diffs[i] = rrHistory[i + 1] - rrHistory[i]
        }
        var rmssd: Float = 0
        vDSP_rmsqv(diffs, 1, &rmssd, vDSP_Length(diffs.count))
        features[2] = rmssd / 100

        // 4. pNN50 (percentage of successive differences > 50ms)
        let nn50 = diffs.filter { abs($0) > 50 }.count
        features[3] = Float(nn50) / Float(diffs.count)

        // Frequency-domain features (simplified)
        // 5. LF/HF ratio estimate
        let shortTermVar = diffs.suffix(10).map { $0 * $0 }.reduce(0, +) / 10
        let longTermVar = variance
        features[4] = shortTermVar / max(longTermVar, 0.001)

        // 6. Coherence score (simplified spectral analysis)
        features[5] = computeCoherenceScore()

        // 7. Trend (increasing/decreasing RR)
        if rrHistory.count >= 10 {
            let recent = Array(rrHistory.suffix(10))
            let old = Array(rrHistory.prefix(10))
            features[6] = (recent.reduce(0, +) - old.reduce(0, +)) / 10000
        }

        // 8. Breathing rate estimate
        features[7] = estimateBreathingRate() / 30  // Normalize to [0, 1]

        return features
    }

    /// Simplified coherence score based on spectral power concentration
    private func computeCoherenceScore() -> Float {
        guard rrHistory.count >= 30 else { return 0.5 }

        // Autocorrelation at breathing frequency (~0.1 Hz)
        let targetLag = Int(Float(rrHistory.count) * 0.1)  // ~10% of window
        guard targetLag > 0 && targetLag < rrHistory.count else { return 0.5 }

        var correlation: Float = 0
        for i in 0..<(rrHistory.count - targetLag) {
            correlation += rrHistory[i] * rrHistory[i + targetLag]
        }
        correlation /= Float(rrHistory.count - targetLag)

        // Normalize by variance
        var variance: Float = 0
        var mean: Float = 0
        vDSP_normalize(rrHistory, 1, nil, 1, &mean, &variance, vDSP_Length(rrHistory.count))

        return min(1, max(0, correlation / max(variance, 0.001)))
    }

    /// Estimate breathing rate from RR intervals
    private func estimateBreathingRate() -> Float {
        guard rrHistory.count >= 20 else { return 12 }

        // Count zero-crossings of detrended signal
        var detrended = rrHistory
        var mean: Float = 0
        vDSP_meanv(rrHistory, 1, &mean, vDSP_Length(rrHistory.count))
        var negMean = -mean
        vDSP_vsadd(detrended, 1, &negMean, &detrended, 1, vDSP_Length(detrended.count))

        var zeroCrossings = 0
        for i in 1..<detrended.count {
            if (detrended[i-1] < 0 && detrended[i] >= 0) ||
               (detrended[i-1] >= 0 && detrended[i] < 0) {
                zeroCrossings += 1
            }
        }

        // Convert to breaths per minute
        let totalTime = rrHistory.reduce(0, +) / 1000  // seconds
        let breathsPerSecond = Float(zeroCrossings) / (2 * totalTime)
        return breathsPerSecond * 60
    }

    /// Neural network forward pass
    private func classify(_ features: [Float]) -> (CoherenceState, Float) {
        // Hidden layer
        var hidden = [Float](repeating: 0, count: hiddenSize)
        for h in 0..<hiddenSize {
            var sum: Float = biasH[h]
            for i in 0..<inputSize {
                sum += features[i] * weightsIH[h][i]
            }
            hidden[h] = tanh(sum)  // Activation
        }

        // Output layer
        var output = [Float](repeating: 0, count: outputSize)
        for o in 0..<outputSize {
            var sum: Float = biasO[o]
            for h in 0..<hiddenSize {
                sum += hidden[h] * weightsHO[o][h]
            }
            output[o] = sum
        }

        // Softmax
        var maxOut: Float = -Float.infinity
        for o in 0..<outputSize {
            maxOut = max(maxOut, output[o])
        }

        var expSum: Float = 0
        for o in 0..<outputSize {
            output[o] = exp(output[o] - maxOut)
            expSum += output[o]
        }

        for o in 0..<outputSize {
            output[o] /= expSum
        }

        // Find max probability
        var maxProb: Float = 0
        var maxIdx = 0
        for o in 0..<outputSize {
            if output[o] > maxProb {
                maxProb = output[o]
                maxIdx = o
            }
        }

        return (CoherenceState(rawValue: maxIdx) ?? .medium, maxProb)
    }

    /// Reset classifier state
    public func reset() {
        rrHistory.removeAll()
    }
}

// MARK: - Predictive Bio-State Estimator

/// Predicts future bio-states using recurrent neural patterns
public final class PredictiveBioEstimator {

    public struct BioState {
        public var coherence: Float
        public var heartRate: Float
        public var breathingRate: Float
        public var stressLevel: Float
        public var energyLevel: Float
        public var timestamp: TimeInterval
    }

    // State history for prediction
    private var stateHistory: [BioState] = []
    private let maxHistory = 120  // 2 minutes at 1 Hz

    // LSTM-like gating (simplified)
    private var cellState: [Float]
    private var hiddenState: [Float]
    private let stateSize = 16

    public init() {
        cellState = [Float](repeating: 0, count: stateSize)
        hiddenState = [Float](repeating: 0, count: stateSize)
    }

    /// Add current bio-state observation
    public func observe(_ state: BioState) {
        stateHistory.append(state)
        if stateHistory.count > maxHistory {
            stateHistory.removeFirst()
        }

        // Update LSTM cell
        updateLSTM(state)
    }

    /// Update simplified LSTM cell
    private func updateLSTM(_ state: BioState) {
        let input: [Float] = [
            state.coherence,
            state.heartRate / 200,  // Normalize
            state.breathingRate / 30,
            state.stressLevel,
            state.energyLevel
        ]

        // Simplified LSTM update (forget + input + output gates)
        for i in 0..<stateSize {
            // Forget gate
            let f = sigmoid(input[i % input.count] + hiddenState[i] * 0.5)

            // Input gate
            let inputGate = sigmoid(input[i % input.count] * 0.7 + 0.3)
            let candidate = tanh(input[i % input.count] + hiddenState[i] * 0.3)

            // Update cell
            cellState[i] = f * cellState[i] + inputGate * candidate

            // Output gate
            let o = sigmoid(input[i % input.count] * 0.5 + cellState[i] * 0.3)
            hiddenState[i] = o * tanh(cellState[i])
        }
    }

    /// Predict bio-state N seconds into the future
    public func predict(secondsAhead: Int) -> BioState {
        guard !stateHistory.isEmpty else {
            return BioState(coherence: 0.5, heartRate: 70, breathingRate: 12,
                           stressLevel: 0.3, energyLevel: 0.5, timestamp: Date().timeIntervalSince1970)
        }

        let current = stateHistory.last!

        // Use hidden state to predict trends
        let coherenceTrend = hiddenState[0] * 0.1
        let hrTrend = hiddenState[1] * 2
        let brTrend = hiddenState[2] * 0.5
        let stressTrend = hiddenState[3] * 0.05
        let energyTrend = hiddenState[4] * 0.05

        // Project forward with damping
        let damping = exp(-Float(secondsAhead) / 60)  // Decay over 1 minute

        return BioState(
            coherence: clamp(current.coherence + coherenceTrend * Float(secondsAhead) * damping, 0, 1),
            heartRate: clamp(current.heartRate + hrTrend * Float(secondsAhead) * damping, 40, 200),
            breathingRate: clamp(current.breathingRate + brTrend * Float(secondsAhead) * damping, 4, 30),
            stressLevel: clamp(current.stressLevel + stressTrend * Float(secondsAhead) * damping, 0, 1),
            energyLevel: clamp(current.energyLevel + energyTrend * Float(secondsAhead) * damping, 0, 1),
            timestamp: current.timestamp + Double(secondsAhead)
        )
    }

    /// Get trend direction for each metric
    public func getTrends() -> (coherence: Float, heartRate: Float, breathing: Float) {
        guard stateHistory.count >= 10 else {
            return (0, 0, 0)
        }

        let recent = Array(stateHistory.suffix(10))
        let older = Array(stateHistory.prefix(10))

        let coherenceTrend = recent.map { $0.coherence }.reduce(0, +) / 10 -
                            older.map { $0.coherence }.reduce(0, +) / 10
        let hrTrend = recent.map { $0.heartRate }.reduce(0, +) / 10 -
                     older.map { $0.heartRate }.reduce(0, +) / 10
        let brTrend = recent.map { $0.breathingRate }.reduce(0, +) / 10 -
                     older.map { $0.breathingRate }.reduce(0, +) / 10

        return (coherenceTrend, hrTrend, brTrend)
    }

    /// Reset estimator state
    public func reset() {
        stateHistory.removeAll()
        cellState = [Float](repeating: 0, count: stateSize)
        hiddenState = [Float](repeating: 0, count: stateSize)
    }

    // MARK: - Helper Functions

    @inlinable
    private func sigmoid(_ x: Float) -> Float {
        return 1.0 / (1.0 + exp(-x))
    }

    @inlinable
    private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
        return Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Entrainment Pattern Detector

/// Detects entrainment between bio-signals and audio
public final class EntrainmentDetector {

    public struct EntrainmentResult {
        public let phase: Float           // Phase alignment (0-1)
        public let coherence: Float       // Phase coherence (0-1)
        public let frequency: Float       // Entrainment frequency (Hz)
        public let strength: Float        // Overall entrainment strength
    }

    private var audioPhaseHistory: [Float] = []
    private var bioPhaseHistory: [Float] = []
    private let historySize = 256

    public init() {}

    /// Detect entrainment between audio beat and bio-rhythm
    public func detect(
        audioPhase: Float,    // Current audio beat phase (0-1)
        bioPhase: Float       // Current bio-rhythm phase (0-1)
    ) -> EntrainmentResult {
        // Add to history
        audioPhaseHistory.append(audioPhase)
        bioPhaseHistory.append(bioPhase)

        if audioPhaseHistory.count > historySize {
            audioPhaseHistory.removeFirst()
            bioPhaseHistory.removeFirst()
        }

        guard audioPhaseHistory.count >= 32 else {
            return EntrainmentResult(phase: 0, coherence: 0, frequency: 0, strength: 0)
        }

        // Calculate phase difference
        var phaseDiffs = [Float](repeating: 0, count: audioPhaseHistory.count)
        for i in 0..<audioPhaseHistory.count {
            var diff = audioPhaseHistory[i] - bioPhaseHistory[i]
            // Wrap to [-0.5, 0.5]
            while diff > 0.5 { diff -= 1 }
            while diff < -0.5 { diff += 1 }
            phaseDiffs[i] = diff
        }

        // Phase coherence (circular mean)
        var sumCos: Float = 0
        var sumSin: Float = 0
        for diff in phaseDiffs {
            let angle = diff * 2 * .pi
            sumCos += CORDICEngine.cos(angle)
            sumSin += CORDICEngine.sin(angle)
        }
        let n = Float(phaseDiffs.count)
        let coherence = sqrt(sumCos * sumCos + sumSin * sumSin) / n

        // Mean phase
        let meanPhase = atan2(sumSin / n, sumCos / n) / (2 * .pi)

        // Estimate entrainment frequency
        var frequency: Float = 0
        if audioPhaseHistory.count >= 2 {
            var totalDelta: Float = 0
            for i in 1..<audioPhaseHistory.count {
                var delta = audioPhaseHistory[i] - audioPhaseHistory[i-1]
                if delta < 0 { delta += 1 }  // Handle wrap
                totalDelta += delta
            }
            frequency = totalDelta / Float(audioPhaseHistory.count - 1)
        }

        // Overall strength (coherence weighted by stability)
        let stability = 1.0 - min(1.0, phaseDiffs.map { abs($0) }.reduce(0, +) / n)
        let strength = coherence * stability

        return EntrainmentResult(
            phase: (meanPhase + 1).truncatingRemainder(dividingBy: 1),
            coherence: coherence,
            frequency: frequency,
            strength: strength
        )
    }

    /// Reset detector state
    public func reset() {
        audioPhaseHistory.removeAll()
        bioPhaseHistory.removeAll()
    }
}
