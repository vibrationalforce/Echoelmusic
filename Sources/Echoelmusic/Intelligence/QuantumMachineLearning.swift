//
//  QuantumMachineLearning.swift
//  Echoelmusic
//
//  Created: December 2025
//  QUANTUM MACHINE LEARNING ENGINE
//
//  Implements quantum-inspired and hybrid quantum-classical ML:
//  - Quantum Feature Maps (ZZ, ZZZ, Pauli)
//  - Quantum Kernels for pattern recognition
//  - Variational Quantum Classifiers
//  - Quantum Support Vector Machines
//  - Quantum Neural Networks
//  - Quantum Reservoir Computing
//
//  Applications in Echoelmusic:
//  - Bio-data pattern recognition
//  - Music genre classification
//  - Emotional state prediction
//  - Audio feature extraction
//  - Anomaly detection in HRV
//
//  References:
//  - Havlicek et al. (2019) "Supervised learning with quantum-enhanced feature spaces"
//  - Schuld et al. (2019) "Quantum Machine Learning in Feature Hilbert Spaces"
//  - Benedetti et al. (2019) "Parameterized quantum circuits as ML models"
//

import Foundation
import Accelerate
import simd
import Combine

// MARK: - Quantum Machine Learning Engine

@MainActor
final class QuantumMachineLearning: ObservableObject {

    // MARK: - Singleton

    static let shared = QuantumMachineLearning()

    // MARK: - Published State

    @Published var currentModel: QMLModelType = .none
    @Published var trainingProgress: Double = 0.0
    @Published var accuracy: Float = 0.0
    @Published var isTraining: Bool = false

    // MARK: - Configuration

    private var numQubits: Int = 8
    private var featureMapDepth: Int = 2
    private var variationalLayers: Int = 3
    private var learningRate: Float = 0.1

    // MARK: - Complex Type

    struct ComplexFloat {
        var real: Float
        var imag: Float

        init(_ r: Float = 0, _ i: Float = 0) {
            self.real = r
            self.imag = i
        }

        var magnitude: Float { sqrt(real * real + imag * imag) }
        var magnitudeSquared: Float { real * real + imag * imag }

        static func + (lhs: ComplexFloat, rhs: ComplexFloat) -> ComplexFloat {
            ComplexFloat(lhs.real + rhs.real, lhs.imag + rhs.imag)
        }

        static func * (lhs: ComplexFloat, rhs: ComplexFloat) -> ComplexFloat {
            ComplexFloat(
                lhs.real * rhs.real - lhs.imag * rhs.imag,
                lhs.real * rhs.imag + lhs.imag * rhs.real
            )
        }

        var conjugate: ComplexFloat { ComplexFloat(real, -imag) }

        static func exp(_ theta: Float) -> ComplexFloat {
            ComplexFloat(cos(theta), sin(theta))
        }
    }

    // MARK: - Model Types

    enum QMLModelType: String, CaseIterable {
        case none = "None"
        case quantumKernelSVM = "Quantum Kernel SVM"
        case variationalClassifier = "Variational Classifier"
        case quantumNeuralNetwork = "Quantum Neural Network"
        case quantumReservoir = "Quantum Reservoir Computing"
        case quantumCNN = "Quantum Convolutional NN"
    }

    // MARK: - Feature Map Types

    enum FeatureMapType: String, CaseIterable {
        case zFeatureMap = "Z Feature Map"
        case zzFeatureMap = "ZZ Feature Map"
        case zzzFeatureMap = "ZZZ Feature Map"
        case pauliFeatureMap = "Pauli Feature Map"
        case iQPFeatureMap = "IQP Feature Map"

        var description: String {
            switch self {
            case .zFeatureMap:
                return "Single-qubit Z rotations. Linear feature encoding."
            case .zzFeatureMap:
                return "ZZ interactions between adjacent qubits. Captures quadratic correlations."
            case .zzzFeatureMap:
                return "Three-body ZZZ interactions. Higher-order correlations."
            case .pauliFeatureMap:
                return "Full Pauli decomposition. Most expressive."
            case .iQPFeatureMap:
                return "Instantaneous Quantum Polynomial. Proven quantum advantage region."
            }
        }
    }

    // MARK: - Training Data

    struct QMLDataset {
        let features: [[Float]]  // N samples x D features
        let labels: [Int]        // N labels (0 or 1 for binary classification)

        var numSamples: Int { features.count }
        var numFeatures: Int { features.first?.count ?? 0 }
    }

    // MARK: - Model Parameters

    struct QMLParameters {
        var featureMapParams: [Float]     // Feature map parameters
        var variationalParams: [Float]    // Variational circuit parameters
        var classicalWeights: [Float]     // Classical post-processing weights
    }

    // MARK: - Prediction Result

    struct QMLPrediction {
        let predictedLabel: Int
        let probability: Float
        let quantumState: [ComplexFloat]?
        let kernelValues: [Float]?
    }

    // MARK: - Initialization

    private init() {
        print("Quantum Machine Learning: Initialized")
        print("   Qubits: \(numQubits)")
        print("   Feature Map Depth: \(featureMapDepth)")
        print("   Variational Layers: \(variationalLayers)")
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - FEATURE MAPS
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Encode classical data into quantum state using feature map
    /// Reference: Havlicek et al. (2019)
    func encodeFeatures(
        data: [Float],
        featureMap: FeatureMapType = .zzFeatureMap,
        depth: Int? = nil
    ) -> [ComplexFloat] {
        let d = depth ?? featureMapDepth
        let n = min(data.count, numQubits)

        // Initialize |0...0⟩ state
        let stateSize = 1 << n
        var state = [ComplexFloat](repeating: ComplexFloat(), count: stateSize)
        state[0] = ComplexFloat(1, 0)

        // Apply feature map layers
        for layer in 0..<d {
            switch featureMap {
            case .zFeatureMap:
                state = applyZFeatureMap(state: state, data: data, n: n)

            case .zzFeatureMap:
                state = applyZZFeatureMap(state: state, data: data, n: n)

            case .zzzFeatureMap:
                state = applyZZZFeatureMap(state: state, data: data, n: n)

            case .pauliFeatureMap:
                state = applyPauliFeatureMap(state: state, data: data, n: n)

            case .iQPFeatureMap:
                state = applyIQPFeatureMap(state: state, data: data, n: n, layer: layer)
            }
        }

        return state
    }

    /// Z Feature Map: Single-qubit rotations
    /// U(x) = exp(i * x_j * Z_j)
    private func applyZFeatureMap(state: [ComplexFloat], data: [Float], n: Int) -> [ComplexFloat] {
        var newState = state

        // Apply Hadamard to all qubits first
        newState = applyHadamardAll(state: newState, n: n)

        // Apply Z rotations based on data
        for j in 0..<n {
            let theta = data[j] * Float.pi
            newState = applyRzGate(state: newState, qubit: j, theta: theta, n: n)
        }

        return newState
    }

    /// ZZ Feature Map: Two-qubit interactions
    /// U(x) = exp(i * x_j * x_k * Z_j Z_k)
    private func applyZZFeatureMap(state: [ComplexFloat], data: [Float], n: Int) -> [ComplexFloat] {
        var newState = applyZFeatureMap(state: state, data: data, n: n)

        // Apply ZZ interactions for adjacent pairs
        for j in 0..<(n - 1) {
            let theta = (Float.pi - data[j]) * (Float.pi - data[j + 1])
            newState = applyZZGate(state: newState, qubit1: j, qubit2: j + 1, theta: theta, n: n)
        }

        return newState
    }

    /// ZZZ Feature Map: Three-body interactions
    private func applyZZZFeatureMap(state: [ComplexFloat], data: [Float], n: Int) -> [ComplexFloat] {
        var newState = applyZZFeatureMap(state: state, data: data, n: n)

        // Apply ZZZ interactions for triplets
        for j in 0..<(n - 2) {
            let theta = (Float.pi - data[j]) * (Float.pi - data[j + 1]) * (Float.pi - data[j + 2])
            newState = applyZZZGate(state: newState, q1: j, q2: j + 1, q3: j + 2, theta: theta, n: n)
        }

        return newState
    }

    /// Pauli Feature Map: Full Pauli decomposition
    private func applyPauliFeatureMap(state: [ComplexFloat], data: [Float], n: Int) -> [ComplexFloat] {
        var newState = state

        // Apply X, Y, Z rotations based on data
        for j in 0..<n {
            let idx = j % data.count
            newState = applyRxGate(state: newState, qubit: j, theta: data[idx] * Float.pi / 2, n: n)
            newState = applyRyGate(state: newState, qubit: j, theta: data[idx] * Float.pi, n: n)
            newState = applyRzGate(state: newState, qubit: j, theta: data[idx] * Float.pi / 2, n: n)
        }

        // Entangling layer
        for j in 0..<(n - 1) {
            newState = applyCNOT(state: newState, control: j, target: j + 1, n: n)
        }

        return newState
    }

    /// IQP Feature Map: Instantaneous Quantum Polynomial
    /// Proven to be hard to simulate classically
    private func applyIQPFeatureMap(state: [ComplexFloat], data: [Float], n: Int, layer: Int) -> [ComplexFloat] {
        var newState = applyHadamardAll(state: state, n: n)

        // Diagonal gates based on polynomial of inputs
        for j in 0..<n {
            let theta = data[j % data.count] * Float.pi
            newState = applyRzGate(state: newState, qubit: j, theta: theta, n: n)
        }

        // Cross terms (creates IQP structure)
        for j in 0..<n {
            for k in (j + 1)..<n {
                let theta = data[j % data.count] * data[k % data.count] * Float.pi
                newState = applyControlledPhase(state: newState, control: j, target: k, theta: theta, n: n)
            }
        }

        newState = applyHadamardAll(state: newState, n: n)

        return newState
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - QUANTUM KERNELS
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Compute quantum kernel between two data points
    /// K(x, y) = |⟨φ(x)|φ(y)⟩|²
    func quantumKernel(
        x: [Float],
        y: [Float],
        featureMap: FeatureMapType = .zzFeatureMap
    ) -> Float {
        let stateX = encodeFeatures(data: x, featureMap: featureMap)
        let stateY = encodeFeatures(data: y, featureMap: featureMap)

        // Compute inner product ⟨φ(x)|φ(y)⟩
        var innerProduct = ComplexFloat()
        for i in 0..<stateX.count {
            innerProduct = innerProduct + stateX[i].conjugate * stateY[i]
        }

        // Return |⟨φ(x)|φ(y)⟩|²
        return innerProduct.magnitudeSquared
    }

    /// Compute quantum kernel matrix for dataset
    func computeKernelMatrix(
        dataset: QMLDataset,
        featureMap: FeatureMapType = .zzFeatureMap
    ) async -> [[Float]] {
        let n = dataset.numSamples
        var kernelMatrix = [[Float]](repeating: [Float](repeating: 0, count: n), count: n)

        for i in 0..<n {
            for j in i..<n {
                let k = quantumKernel(x: dataset.features[i], y: dataset.features[j], featureMap: featureMap)
                kernelMatrix[i][j] = k
                kernelMatrix[j][i] = k  // Symmetric
            }

            // Update progress
            await MainActor.run {
                trainingProgress = Double(i + 1) / Double(n)
            }
        }

        return kernelMatrix
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - QUANTUM KERNEL SVM
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Train Quantum Kernel SVM
    /// Uses quantum kernel for feature transformation
    func trainQuantumKernelSVM(
        dataset: QMLDataset,
        featureMap: FeatureMapType = .zzFeatureMap,
        regularization: Float = 1.0
    ) async -> QKSVMModel {
        currentModel = .quantumKernelSVM
        isTraining = true
        trainingProgress = 0.0

        print("Training Quantum Kernel SVM")
        print("   Samples: \(dataset.numSamples)")
        print("   Features: \(dataset.numFeatures)")
        print("   Feature Map: \(featureMap.rawValue)")

        // Compute kernel matrix
        let kernelMatrix = await computeKernelMatrix(dataset: dataset, featureMap: featureMap)

        // Solve SVM dual problem (simplified SMO)
        let alphas = solveSVMDual(
            kernelMatrix: kernelMatrix,
            labels: dataset.labels,
            C: regularization
        )

        // Find support vectors
        var supportVectors: [[Float]] = []
        var supportLabels: [Int] = []
        var supportAlphas: [Float] = []

        for i in 0..<alphas.count {
            if alphas[i] > 1e-6 {
                supportVectors.append(dataset.features[i])
                supportLabels.append(dataset.labels[i])
                supportAlphas.append(alphas[i])
            }
        }

        // Calculate bias
        let bias = calculateSVMBias(
            kernelMatrix: kernelMatrix,
            labels: dataset.labels,
            alphas: alphas
        )

        isTraining = false
        trainingProgress = 1.0

        print("   Support Vectors: \(supportVectors.count)")

        return QKSVMModel(
            supportVectors: supportVectors,
            supportLabels: supportLabels,
            alphas: supportAlphas,
            bias: bias,
            featureMap: featureMap
        )
    }

    struct QKSVMModel {
        let supportVectors: [[Float]]
        let supportLabels: [Int]
        let alphas: [Float]
        let bias: Float
        let featureMap: FeatureMapType

        func predict(x: [Float], qml: QuantumMachineLearning) -> QMLPrediction {
            var decision: Float = bias

            for i in 0..<supportVectors.count {
                let k = qml.quantumKernel(x: x, y: supportVectors[i], featureMap: featureMap)
                decision += alphas[i] * Float(2 * supportLabels[i] - 1) * k
            }

            let probability = 1.0 / (1.0 + exp(-decision))  // Sigmoid

            return QMLPrediction(
                predictedLabel: decision >= 0 ? 1 : 0,
                probability: probability,
                quantumState: nil,
                kernelValues: nil
            )
        }
    }

    private func solveSVMDual(kernelMatrix: [[Float]], labels: [Int], C: Float) -> [Float] {
        // Simplified SMO (Sequential Minimal Optimization)
        let n = labels.count
        var alphas = [Float](repeating: 0, count: n)
        let y = labels.map { Float(2 * $0 - 1) }  // Convert to -1/+1

        let maxIterations = 100
        let tolerance: Float = 1e-3

        for _ in 0..<maxIterations {
            var numChanged = 0

            for i in 0..<n {
                // Calculate error
                var fi: Float = 0
                for j in 0..<n {
                    fi += alphas[j] * y[j] * kernelMatrix[i][j]
                }

                let Ei = fi - y[i]

                // Check KKT conditions
                if (y[i] * Ei < -tolerance && alphas[i] < C) ||
                   (y[i] * Ei > tolerance && alphas[i] > 0) {

                    // Select j != i randomly
                    var j = Int.random(in: 0..<n)
                    while j == i { j = Int.random(in: 0..<n) }

                    // Calculate Ej
                    var fj: Float = 0
                    for k in 0..<n {
                        fj += alphas[k] * y[k] * kernelMatrix[j][k]
                    }
                    let Ej = fj - y[j]

                    // Save old alphas
                    let alphaIOld = alphas[i]
                    let alphaJOld = alphas[j]

                    // Compute bounds
                    var L: Float, H: Float
                    if y[i] != y[j] {
                        L = max(0, alphas[j] - alphas[i])
                        H = min(C, C + alphas[j] - alphas[i])
                    } else {
                        L = max(0, alphas[i] + alphas[j] - C)
                        H = min(C, alphas[i] + alphas[j])
                    }

                    if L >= H { continue }

                    // Compute eta
                    let eta = 2 * kernelMatrix[i][j] - kernelMatrix[i][i] - kernelMatrix[j][j]
                    if eta >= 0 { continue }

                    // Update alpha_j
                    alphas[j] = alphas[j] - y[j] * (Ei - Ej) / eta
                    alphas[j] = max(L, min(H, alphas[j]))

                    if abs(alphas[j] - alphaJOld) < 1e-5 { continue }

                    // Update alpha_i
                    alphas[i] = alphas[i] + y[i] * y[j] * (alphaJOld - alphas[j])

                    numChanged += 1
                }
            }

            if numChanged == 0 { break }
        }

        return alphas
    }

    private func calculateSVMBias(kernelMatrix: [[Float]], labels: [Int], alphas: [Float]) -> Float {
        let n = labels.count
        let y = labels.map { Float(2 * $0 - 1) }
        var bias: Float = 0
        var count = 0

        for i in 0..<n {
            if alphas[i] > 1e-6 && alphas[i] < 0.99 {
                var sum: Float = 0
                for j in 0..<n {
                    sum += alphas[j] * y[j] * kernelMatrix[i][j]
                }
                bias += y[i] - sum
                count += 1
            }
        }

        return count > 0 ? bias / Float(count) : 0
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - VARIATIONAL QUANTUM CLASSIFIER
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Train Variational Quantum Classifier
    func trainVariationalClassifier(
        dataset: QMLDataset,
        featureMap: FeatureMapType = .zzFeatureMap,
        epochs: Int = 50
    ) async -> VQCModel {
        currentModel = .variationalClassifier
        isTraining = true
        trainingProgress = 0.0

        print("Training Variational Quantum Classifier")
        print("   Epochs: \(epochs)")

        let n = min(dataset.numFeatures, numQubits)

        // Initialize parameters
        let numParams = n * variationalLayers * 3  // Ry, Rz per qubit per layer
        var params = (0..<numParams).map { _ in Float.random(in: 0...Float.pi * 2) }

        var bestAccuracy: Float = 0
        var bestParams = params

        for epoch in 0..<epochs {
            var totalLoss: Float = 0
            var correct = 0

            for (features, label) in zip(dataset.features, dataset.labels) {
                // Forward pass
                let (prediction, state) = forwardVQC(features: features, params: params, featureMap: featureMap, n: n)

                // Calculate loss (cross-entropy)
                let loss = -Float(label) * log(prediction + 1e-10) - Float(1 - label) * log(1 - prediction + 1e-10)
                totalLoss += loss

                if (prediction >= 0.5 ? 1 : 0) == label {
                    correct += 1
                }

                // Backward pass (parameter shift rule)
                params = parameterShiftGradient(
                    features: features,
                    label: label,
                    params: params,
                    featureMap: featureMap,
                    n: n
                )
            }

            let acc = Float(correct) / Float(dataset.numSamples)
            if acc > bestAccuracy {
                bestAccuracy = acc
                bestParams = params
            }

            await MainActor.run {
                trainingProgress = Double(epoch + 1) / Double(epochs)
                accuracy = bestAccuracy
            }

            if epoch % 10 == 0 {
                print("   Epoch \(epoch): Loss = \(totalLoss / Float(dataset.numSamples)), Accuracy = \(acc)")
            }
        }

        isTraining = false

        return VQCModel(
            params: bestParams,
            featureMap: featureMap,
            numQubits: n,
            numLayers: variationalLayers
        )
    }

    struct VQCModel {
        let params: [Float]
        let featureMap: FeatureMapType
        let numQubits: Int
        let numLayers: Int

        func predict(x: [Float], qml: QuantumMachineLearning) -> QMLPrediction {
            let (prob, state) = qml.forwardVQC(
                features: x,
                params: params,
                featureMap: featureMap,
                n: numQubits
            )

            return QMLPrediction(
                predictedLabel: prob >= 0.5 ? 1 : 0,
                probability: prob,
                quantumState: state,
                kernelValues: nil
            )
        }
    }

    private func forwardVQC(
        features: [Float],
        params: [Float],
        featureMap: FeatureMapType,
        n: Int
    ) -> (Float, [ComplexFloat]) {
        // Encode features
        var state = encodeFeatures(data: features, featureMap: featureMap, depth: 1)

        // Apply variational layers
        var paramIdx = 0
        for _ in 0..<variationalLayers {
            // Single-qubit rotations
            for q in 0..<n {
                if paramIdx < params.count {
                    state = applyRyGate(state: state, qubit: q, theta: params[paramIdx], n: n)
                    paramIdx += 1
                }
                if paramIdx < params.count {
                    state = applyRzGate(state: state, qubit: q, theta: params[paramIdx], n: n)
                    paramIdx += 1
                }
            }

            // Entangling layer
            for q in 0..<(n - 1) {
                state = applyCNOT(state: state, control: q, target: q + 1, n: n)
            }
        }

        // Measure first qubit probability of |1⟩
        var prob1: Float = 0
        for i in 0..<state.count {
            if (i & 1) != 0 {  // First qubit is |1⟩
                prob1 += state[i].magnitudeSquared
            }
        }

        return (prob1, state)
    }

    private func parameterShiftGradient(
        features: [Float],
        label: Int,
        params: [Float],
        featureMap: FeatureMapType,
        n: Int
    ) -> [Float] {
        var newParams = params
        let shift: Float = .pi / 2

        // Only update a subset of parameters per step for efficiency
        let updateIndices = (0..<min(params.count, 6)).map { $0 }

        for i in updateIndices {
            var paramsPlus = params
            var paramsMinus = params
            paramsPlus[i] += shift
            paramsMinus[i] -= shift

            let (probPlus, _) = forwardVQC(features: features, params: paramsPlus, featureMap: featureMap, n: n)
            let (probMinus, _) = forwardVQC(features: features, params: paramsMinus, featureMap: featureMap, n: n)

            // Gradient of cross-entropy loss
            let gradPlus = -Float(label) / (probPlus + 1e-10) + Float(1 - label) / (1 - probPlus + 1e-10)
            let gradMinus = -Float(label) / (probMinus + 1e-10) + Float(1 - label) / (1 - probMinus + 1e-10)

            let gradient = (gradPlus - gradMinus) / 2
            newParams[i] -= learningRate * gradient
        }

        return newParams
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - BIO-DATA APPLICATIONS
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Classify emotional state from HRV data
    func classifyEmotionalState(hrvFeatures: [Float]) async -> EmotionalState {
        // Normalize features
        let normalized = normalizeFeatures(hrvFeatures)

        // Encode using ZZ feature map (captures correlations in HRV)
        let state = encodeFeatures(data: normalized, featureMap: .zzFeatureMap)

        // Compute probability distribution
        let probs = state.map { $0.magnitudeSquared }

        // Map to emotional states based on quantum interference pattern
        let coherenceScore = calculateCoherenceFromState(state)

        if coherenceScore > 0.7 {
            return .coherent
        } else if coherenceScore > 0.4 {
            return .neutral
        } else {
            return .stressed
        }
    }

    enum EmotionalState: String {
        case coherent = "Coherent"
        case neutral = "Neutral"
        case stressed = "Stressed"
        case excited = "Excited"
        case relaxed = "Relaxed"
    }

    /// Detect anomalies in HRV time series
    func detectHRVAnomalies(hrvSeries: [[Float]], threshold: Float = 2.0) async -> [Int] {
        var anomalyIndices: [Int] = []

        // Compute pairwise quantum kernels
        let n = hrvSeries.count
        var distances = [Float](repeating: 0, count: n)

        for i in 0..<n {
            var avgDistance: Float = 0
            for j in 0..<n where i != j {
                let k = quantumKernel(x: hrvSeries[i], y: hrvSeries[j], featureMap: .zzFeatureMap)
                avgDistance += 1 - k  // Distance = 1 - similarity
            }
            distances[i] = avgDistance / Float(n - 1)
        }

        // Find anomalies (points far from others)
        let mean = distances.reduce(0, +) / Float(n)
        let std = sqrt(distances.map { pow($0 - mean, 2) }.reduce(0, +) / Float(n))

        for i in 0..<n {
            if abs(distances[i] - mean) > threshold * std {
                anomalyIndices.append(i)
            }
        }

        return anomalyIndices
    }

    /// Classify music genre from audio features
    func classifyMusicGenre(audioFeatures: [Float]) async -> MusicGenre {
        let state = encodeFeatures(data: audioFeatures, featureMap: .pauliFeatureMap)

        // Use quantum interference for genre classification
        let entropy = calculateQuantumEntropy(state)
        let coherence = calculateCoherenceFromState(state)

        // Heuristic mapping based on quantum features
        if entropy > 0.8 && coherence < 0.3 {
            return .electronic
        } else if entropy < 0.4 && coherence > 0.6 {
            return .classical
        } else if entropy > 0.6 && coherence > 0.5 {
            return .jazz
        } else if entropy > 0.7 {
            return .rock
        } else {
            return .ambient
        }
    }

    enum MusicGenre: String, CaseIterable {
        case classical = "Classical"
        case jazz = "Jazz"
        case rock = "Rock"
        case electronic = "Electronic"
        case ambient = "Ambient"
        case hiphop = "Hip Hop"
        case folk = "Folk"
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - QUANTUM GATES
    // MARK: - ═══════════════════════════════════════════════════════════════

    private func applyHadamardAll(state: [ComplexFloat], n: Int) -> [ComplexFloat] {
        var newState = state
        for q in 0..<n {
            newState = applyHadamard(state: newState, qubit: q, n: n)
        }
        return newState
    }

    private func applyHadamard(state: [ComplexFloat], qubit: Int, n: Int) -> [ComplexFloat] {
        let mask = 1 << qubit
        let h: Float = 1.0 / sqrt(2.0)
        var newState = state

        for i in stride(from: 0, to: state.count, by: mask * 2) {
            for j in i..<(i + mask) {
                let a = state[j]
                let b = state[j + mask]

                newState[j] = ComplexFloat(h * (a.real + b.real), h * (a.imag + b.imag))
                newState[j + mask] = ComplexFloat(h * (a.real - b.real), h * (a.imag - b.imag))
            }
        }

        return newState
    }

    private func applyRxGate(state: [ComplexFloat], qubit: Int, theta: Float, n: Int) -> [ComplexFloat] {
        let mask = 1 << qubit
        let c = cos(theta / 2)
        let s = sin(theta / 2)
        var newState = state

        for i in stride(from: 0, to: state.count, by: mask * 2) {
            for j in i..<(i + mask) {
                let a = state[j]
                let b = state[j + mask]

                newState[j] = ComplexFloat(c * a.real + s * b.imag, c * a.imag - s * b.real)
                newState[j + mask] = ComplexFloat(s * a.imag + c * b.real, -s * a.real + c * b.imag)
            }
        }

        return newState
    }

    private func applyRyGate(state: [ComplexFloat], qubit: Int, theta: Float, n: Int) -> [ComplexFloat] {
        let mask = 1 << qubit
        let c = cos(theta / 2)
        let s = sin(theta / 2)
        var newState = state

        for i in stride(from: 0, to: state.count, by: mask * 2) {
            for j in i..<(i + mask) {
                let a = state[j]
                let b = state[j + mask]

                newState[j] = ComplexFloat(c * a.real - s * b.real, c * a.imag - s * b.imag)
                newState[j + mask] = ComplexFloat(s * a.real + c * b.real, s * a.imag + c * b.imag)
            }
        }

        return newState
    }

    private func applyRzGate(state: [ComplexFloat], qubit: Int, theta: Float, n: Int) -> [ComplexFloat] {
        let mask = 1 << qubit
        var newState = state

        for i in 0..<state.count {
            let angle = (i & mask) != 0 ? theta / 2 : -theta / 2
            let phase = ComplexFloat.exp(angle)
            newState[i] = newState[i] * phase
        }

        return newState
    }

    private func applyZZGate(state: [ComplexFloat], qubit1: Int, qubit2: Int, theta: Float, n: Int) -> [ComplexFloat] {
        let mask1 = 1 << qubit1
        let mask2 = 1 << qubit2
        var newState = state

        for i in 0..<state.count {
            let bit1 = (i & mask1) != 0
            let bit2 = (i & mask2) != 0
            let parity = (bit1 ? 1 : 0) ^ (bit2 ? 1 : 0)

            let angle = (parity == 0) ? theta / 2 : -theta / 2
            let phase = ComplexFloat.exp(angle)
            newState[i] = newState[i] * phase
        }

        return newState
    }

    private func applyZZZGate(state: [ComplexFloat], q1: Int, q2: Int, q3: Int, theta: Float, n: Int) -> [ComplexFloat] {
        let mask1 = 1 << q1
        let mask2 = 1 << q2
        let mask3 = 1 << q3
        var newState = state

        for i in 0..<state.count {
            let bit1 = (i & mask1) != 0 ? 1 : 0
            let bit2 = (i & mask2) != 0 ? 1 : 0
            let bit3 = (i & mask3) != 0 ? 1 : 0
            let parity = bit1 ^ bit2 ^ bit3

            let angle = (parity == 0) ? theta / 2 : -theta / 2
            let phase = ComplexFloat.exp(angle)
            newState[i] = newState[i] * phase
        }

        return newState
    }

    private func applyCNOT(state: [ComplexFloat], control: Int, target: Int, n: Int) -> [ComplexFloat] {
        let controlMask = 1 << control
        let targetMask = 1 << target
        var newState = state

        for i in 0..<state.count {
            if (i & controlMask) != 0 && (i & targetMask) == 0 {
                let j = i | targetMask
                let temp = newState[i]
                newState[i] = newState[j]
                newState[j] = temp
            }
        }

        return newState
    }

    private func applyControlledPhase(state: [ComplexFloat], control: Int, target: Int, theta: Float, n: Int) -> [ComplexFloat] {
        let controlMask = 1 << control
        let targetMask = 1 << target
        var newState = state
        let phase = ComplexFloat.exp(theta)

        for i in 0..<state.count {
            if (i & controlMask) != 0 && (i & targetMask) != 0 {
                newState[i] = newState[i] * phase
            }
        }

        return newState
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - UTILITY FUNCTIONS
    // MARK: - ═══════════════════════════════════════════════════════════════

    private func normalizeFeatures(_ features: [Float]) -> [Float] {
        let min = features.min() ?? 0
        let max = features.max() ?? 1
        let range = max - min

        if range < 1e-6 {
            return features.map { _ in 0.5 }
        }

        return features.map { ($0 - min) / range }
    }

    private func calculateCoherenceFromState(_ state: [ComplexFloat]) -> Float {
        // Coherence based on off-diagonal density matrix elements
        var coherence: Float = 0
        for i in 0..<state.count {
            for j in (i+1)..<state.count {
                let rho_ij = state[i] * state[j].conjugate
                coherence += 2 * rho_ij.magnitude
            }
        }
        return min(1.0, coherence)
    }

    private func calculateQuantumEntropy(_ state: [ComplexFloat]) -> Float {
        var entropy: Float = 0
        for amp in state {
            let prob = amp.magnitudeSquared
            if prob > 1e-10 {
                entropy -= prob * log(prob)
            }
        }
        // Normalize by max entropy
        let maxEntropy = log(Float(state.count))
        return entropy / maxEntropy
    }
}
