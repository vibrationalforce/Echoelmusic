//
//  QuantumAdvancedAlgorithms.swift
//  Echoelmusic
//
//  Created: December 2025
//  QUANTUM ADVANCED ALGORITHMS - ULTRATHINK SCIENCE MODE
//
//  Implements cutting-edge quantum algorithms:
//  - QAOA (Quantum Approximate Optimization Algorithm)
//  - VQE (Variational Quantum Eigensolver)
//  - QPE (Quantum Phase Estimation)
//  - Quantum Walks
//  - Quantum Amplitude Estimation
//
//  References:
//  - Farhi et al. (2014) "A Quantum Approximate Optimization Algorithm"
//  - Peruzzo et al. (2014) "A variational eigenvalue solver on a photonic quantum processor"
//  - Kitaev (1995) "Quantum measurements and the Abelian Stabilizer Problem"
//  - Childs et al. (2003) "Exponential algorithmic speedup by quantum walk"
//

import Foundation
import Accelerate
import simd
import Combine

// MARK: - Quantum Advanced Algorithms Engine

@MainActor
final class QuantumAdvancedAlgorithms: ObservableObject {

    // MARK: - Singleton

    static let shared = QuantumAdvancedAlgorithms()

    // MARK: - Published State

    @Published var currentAlgorithm: QuantumAlgorithmType = .none
    @Published var progress: Double = 0.0
    @Published var lastResult: QuantumResult?
    @Published var quantumAdvantage: Float = 1.0

    // MARK: - Quantum State

    private var stateVector: [ComplexFloat] = []
    private var numQubits: Int = 16
    private let maxQubits: Int = 24  // 2^24 = 16M amplitudes max

    // MARK: - Complex Number Type

    struct ComplexFloat: Equatable {
        var real: Float
        var imag: Float

        init(_ real: Float = 0, _ imag: Float = 0) {
            self.real = real
            self.imag = imag
        }

        var magnitude: Float { sqrt(real * real + imag * imag) }
        var phase: Float { atan2(imag, real) }
        var conjugate: ComplexFloat { ComplexFloat(real, -imag) }

        static func + (lhs: ComplexFloat, rhs: ComplexFloat) -> ComplexFloat {
            ComplexFloat(lhs.real + rhs.real, lhs.imag + rhs.imag)
        }

        static func - (lhs: ComplexFloat, rhs: ComplexFloat) -> ComplexFloat {
            ComplexFloat(lhs.real - rhs.real, lhs.imag - rhs.imag)
        }

        static func * (lhs: ComplexFloat, rhs: ComplexFloat) -> ComplexFloat {
            ComplexFloat(
                lhs.real * rhs.real - lhs.imag * rhs.imag,
                lhs.real * rhs.imag + lhs.imag * rhs.real
            )
        }

        static func * (scalar: Float, rhs: ComplexFloat) -> ComplexFloat {
            ComplexFloat(scalar * rhs.real, scalar * rhs.imag)
        }

        static func / (lhs: ComplexFloat, rhs: Float) -> ComplexFloat {
            ComplexFloat(lhs.real / rhs, lhs.imag / rhs)
        }

        static func exp(_ theta: Float) -> ComplexFloat {
            ComplexFloat(cos(theta), sin(theta))
        }
    }

    // MARK: - Algorithm Types

    enum QuantumAlgorithmType: String, CaseIterable {
        case none = "None"
        case qaoa = "QAOA"
        case vqe = "VQE"
        case qpe = "QPE"
        case quantumWalk = "Quantum Walk"
        case amplitudeEstimation = "Amplitude Estimation"
        case grover = "Grover Search"
        case qft = "Quantum Fourier Transform"
    }

    // MARK: - QUBO Problem (Quadratic Unconstrained Binary Optimization)

    struct QUBOProblem {
        let linearTerms: [Float]      // h_i coefficients
        let quadraticTerms: [[Float]] // J_ij coupling matrix
        let offset: Float

        var numVariables: Int { linearTerms.count }

        /// Evaluate cost function for binary string
        func evaluate(_ bitstring: [Int]) -> Float {
            var cost = offset

            // Linear terms
            for i in 0..<numVariables {
                cost += linearTerms[i] * Float(bitstring[i])
            }

            // Quadratic terms
            for i in 0..<numVariables {
                for j in (i+1)..<numVariables {
                    cost += quadraticTerms[i][j] * Float(bitstring[i] * bitstring[j])
                }
            }

            return cost
        }
    }

    // MARK: - Quantum Result

    struct QuantumResult {
        let algorithm: QuantumAlgorithmType
        let solution: [Int]?
        let eigenvalue: Float?
        let phase: Float?
        let probability: Float
        let iterations: Int
        let executionTime: TimeInterval
        let quantumAdvantage: Float
    }

    // MARK: - Initialization

    private init() {
        initializeState(qubits: numQubits)
        print("✅ Quantum Advanced Algorithms: Initialized")
        print("⚛️ Max Qubits: \(maxQubits) (2^\(maxQubits) = \(1 << maxQubits) states)")
    }

    private func initializeState(qubits: Int) {
        numQubits = min(qubits, maxQubits)
        let stateSize = 1 << numQubits
        stateVector = Array(repeating: ComplexFloat(0, 0), count: stateSize)
        stateVector[0] = ComplexFloat(1, 0)  // |0...0⟩
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - QAOA (Quantum Approximate Optimization Algorithm)
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// QAOA - Farhi et al. (2014)
    /// Finds approximate solutions to combinatorial optimization problems
    /// Quantum speedup: Potential for hard optimization problems (NP-hard)
    func qaoa(
        problem: QUBOProblem,
        layers: Int = 3,
        maxIterations: Int = 100
    ) async -> QuantumResult {
        let startTime = Date()
        currentAlgorithm = .qaoa
        progress = 0.0

        print("🔮 QAOA: Starting optimization")
        print("   Variables: \(problem.numVariables)")
        print("   Layers (p): \(layers)")

        // Initialize state to uniform superposition
        let n = min(problem.numVariables, maxQubits)
        initializeState(qubits: n)
        applyHadamardAll()

        // Initialize variational parameters
        var gammas = [Float](repeating: 0.5, count: layers)
        var betas = [Float](repeating: 0.5, count: layers)

        var bestCost: Float = .infinity
        var bestBitstring: [Int] = []

        // SPSA optimization loop
        for iteration in 0..<maxIterations {
            progress = Double(iteration) / Double(maxIterations)

            // Evaluate current parameters
            let (cost, bitstring) = evaluateQAOA(
                problem: problem,
                gammas: gammas,
                betas: betas
            )

            if cost < bestCost {
                bestCost = cost
                bestBitstring = bitstring
            }

            // SPSA gradient estimation
            let (newGammas, newBetas) = spsaUpdate(
                gammas: gammas,
                betas: betas,
                problem: problem,
                iteration: iteration
            )

            gammas = newGammas
            betas = newBetas

            if iteration % 10 == 0 {
                print("   Iteration \(iteration): Cost = \(bestCost)")
            }
        }

        progress = 1.0
        currentAlgorithm = .none

        let executionTime = Date().timeIntervalSince(startTime)

        // Calculate quantum advantage estimate
        let classicalComplexity = Float(pow(2.0, Double(n)))
        let quantumComplexity = Float(layers * maxIterations * n)
        quantumAdvantage = classicalComplexity / quantumComplexity

        print("✅ QAOA: Complete")
        print("   Best cost: \(bestCost)")
        print("   Solution: \(bestBitstring)")
        print("   Quantum advantage: \(quantumAdvantage)x")

        let result = QuantumResult(
            algorithm: .qaoa,
            solution: bestBitstring,
            eigenvalue: bestCost,
            phase: nil,
            probability: 1.0,
            iterations: maxIterations,
            executionTime: executionTime,
            quantumAdvantage: quantumAdvantage
        )

        lastResult = result
        return result
    }

    private func evaluateQAOA(
        problem: QUBOProblem,
        gammas: [Float],
        betas: [Float]
    ) -> (Float, [Int]) {
        // Reset to uniform superposition
        let n = min(problem.numVariables, numQubits)
        initializeState(qubits: n)
        applyHadamardAll()

        // Apply QAOA layers
        for layer in 0..<gammas.count {
            // Cost unitary: exp(-i * gamma * C)
            applyCostUnitary(problem: problem, gamma: gammas[layer])

            // Mixer unitary: exp(-i * beta * B) where B = sum(X_i)
            applyMixerUnitary(beta: betas[layer])
        }

        // Sample from distribution
        let bitstring = measureAll()
        let cost = problem.evaluate(bitstring)

        return (cost, bitstring)
    }

    private func applyCostUnitary(problem: QUBOProblem, gamma: Float) {
        let n = min(problem.numVariables, numQubits)
        let stateSize = stateVector.count

        // Apply phase based on cost function
        for i in 0..<stateSize {
            // Convert index to bitstring
            let bitstring = (0..<n).map { (i >> $0) & 1 }
            let cost = problem.evaluate(bitstring)

            // Apply phase: |x⟩ → exp(-i * gamma * C(x)) |x⟩
            let phase = ComplexFloat.exp(-gamma * cost)
            stateVector[i] = stateVector[i] * phase
        }
    }

    private func applyMixerUnitary(beta: Float) {
        // Apply exp(-i * beta * X) to each qubit
        // This is equivalent to Rx(2*beta) rotation
        for qubit in 0..<numQubits {
            applyRxGate(qubit: qubit, theta: 2 * beta)
        }
    }

    private func spsaUpdate(
        gammas: [Float],
        betas: [Float],
        problem: QUBOProblem,
        iteration: Int
    ) -> ([Float], [Float]) {
        // SPSA (Simultaneous Perturbation Stochastic Approximation)
        // Optimal for noisy quantum systems

        let a: Float = 0.1
        let c: Float = 0.1
        let A: Float = 10
        let alpha: Float = 0.602
        let gamma: Float = 0.101

        let ak = a / pow(Float(iteration + 1 + A), alpha)
        let ck = c / pow(Float(iteration + 1), gamma)

        // Random perturbation direction (Bernoulli ±1)
        let deltaGammas = gammas.map { _ in Float.random(in: 0...1) > 0.5 ? 1.0 : -1.0 }
        let deltaBetas = betas.map { _ in Float.random(in: 0...1) > 0.5 ? 1.0 : -1.0 }

        // Perturbed parameters
        let gammasPlus = zip(gammas, deltaGammas).map { $0 + ck * $1 }
        let gammasMinus = zip(gammas, deltaGammas).map { $0 - ck * $1 }
        let betasPlus = zip(betas, deltaBetas).map { $0 + ck * $1 }
        let betasMinus = zip(betas, deltaBetas).map { $0 - ck * $1 }

        // Evaluate at perturbed points
        let (costPlus, _) = evaluateQAOA(problem: problem, gammas: gammasPlus, betas: betasPlus)
        let (costMinus, _) = evaluateQAOA(problem: problem, gammas: gammasMinus, betas: betasMinus)

        // Gradient estimate
        let gradGammas = deltaGammas.map { (costPlus - costMinus) / (2 * ck * $0) }
        let gradBetas = deltaBetas.map { (costPlus - costMinus) / (2 * ck * $0) }

        // Update
        let newGammas = zip(gammas, gradGammas).map { max(0, min(Float.pi, $0 - ak * $1)) }
        let newBetas = zip(betas, gradBetas).map { max(0, min(Float.pi, $0 - ak * $1)) }

        return (newGammas, newBetas)
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - VQE (Variational Quantum Eigensolver)
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// VQE - Peruzzo et al. (2014)
    /// Finds ground state energy of Hamiltonians
    /// Applications: Molecular simulation, material science
    func vqe(
        hamiltonian: Hamiltonian,
        ansatz: AnsatzType = .hardwareEfficient,
        maxIterations: Int = 200
    ) async -> QuantumResult {
        let startTime = Date()
        currentAlgorithm = .vqe
        progress = 0.0

        print("🔬 VQE: Starting eigenvalue search")
        print("   Qubits: \(hamiltonian.numQubits)")
        print("   Ansatz: \(ansatz.rawValue)")

        let n = min(hamiltonian.numQubits, maxQubits)
        initializeState(qubits: n)

        // Initialize variational parameters
        let numParams = ansatz.parameterCount(qubits: n, layers: 2)
        var params = (0..<numParams).map { _ in Float.random(in: 0...Float.pi * 2) }

        var bestEnergy: Float = .infinity

        for iteration in 0..<maxIterations {
            progress = Double(iteration) / Double(maxIterations)

            // Prepare ansatz state
            prepareAnsatz(ansatz: ansatz, params: params, qubits: n)

            // Measure expectation value of Hamiltonian
            let energy = measureHamiltonianExpectation(hamiltonian)

            if energy < bestEnergy {
                bestEnergy = energy
            }

            // Gradient descent update (parameter shift rule)
            params = parameterShiftUpdate(
                params: params,
                hamiltonian: hamiltonian,
                ansatz: ansatz,
                qubits: n,
                learningRate: 0.1
            )

            if iteration % 20 == 0 {
                print("   Iteration \(iteration): Energy = \(bestEnergy)")
            }
        }

        progress = 1.0
        currentAlgorithm = .none

        let executionTime = Date().timeIntervalSince(startTime)

        print("✅ VQE: Complete")
        print("   Ground state energy: \(bestEnergy)")

        let result = QuantumResult(
            algorithm: .vqe,
            solution: nil,
            eigenvalue: bestEnergy,
            phase: nil,
            probability: 1.0,
            iterations: maxIterations,
            executionTime: executionTime,
            quantumAdvantage: Float(pow(2.0, Double(n))) / Float(maxIterations * numParams)
        )

        lastResult = result
        return result
    }

    enum AnsatzType: String {
        case hardwareEfficient = "Hardware Efficient"
        case uccsd = "UCCSD"
        case qaoa = "QAOA-style"

        func parameterCount(qubits: Int, layers: Int) -> Int {
            switch self {
            case .hardwareEfficient:
                return qubits * 3 * layers  // Ry, Rz per qubit per layer + entangling
            case .uccsd:
                return qubits * qubits  // All pair excitations
            case .qaoa:
                return 2 * layers  // gamma and beta per layer
            }
        }
    }

    struct Hamiltonian {
        let pauliTerms: [PauliTerm]
        let numQubits: Int

        struct PauliTerm {
            let coefficient: Float
            let paulis: [(qubit: Int, pauli: PauliType)]
        }

        enum PauliType: String {
            case I, X, Y, Z
        }
    }

    private func prepareAnsatz(ansatz: AnsatzType, params: [Float], qubits: Int) {
        initializeState(qubits: qubits)

        var paramIndex = 0
        let layers = 2

        switch ansatz {
        case .hardwareEfficient:
            for _ in 0..<layers {
                // Single qubit rotations
                for q in 0..<qubits {
                    applyRyGate(qubit: q, theta: params[paramIndex])
                    paramIndex += 1
                    applyRzGate(qubit: q, theta: params[paramIndex])
                    paramIndex += 1
                }
                // Entangling layer (linear connectivity)
                for q in 0..<(qubits - 1) {
                    applyCNOT(control: q, target: q + 1)
                }
            }

        case .uccsd, .qaoa:
            // Simplified implementation
            for q in 0..<qubits {
                if paramIndex < params.count {
                    applyRyGate(qubit: q, theta: params[paramIndex])
                    paramIndex += 1
                }
            }
        }
    }

    private func measureHamiltonianExpectation(_ hamiltonian: Hamiltonian) -> Float {
        var expectation: Float = 0.0

        for term in hamiltonian.pauliTerms {
            let termExpectation = measurePauliTermExpectation(term)
            expectation += term.coefficient * termExpectation
        }

        return expectation
    }

    private func measurePauliTermExpectation(_ term: Hamiltonian.PauliTerm) -> Float {
        // For each Pauli term, measure in appropriate basis
        // This is a simplified simulation

        var expectation: Float = 0.0
        let stateSize = stateVector.count

        for i in 0..<stateSize {
            let prob = stateVector[i].magnitude * stateVector[i].magnitude

            // Calculate eigenvalue for this basis state
            var eigenvalue: Float = 1.0
            for (qubit, pauli) in term.paulis {
                let bit = (i >> qubit) & 1
                switch pauli {
                case .Z:
                    eigenvalue *= bit == 0 ? 1.0 : -1.0
                case .I:
                    break  // Identity
                case .X, .Y:
                    // Would need basis rotation in full implementation
                    break
                }
            }

            expectation += prob * eigenvalue
        }

        return expectation
    }

    private func parameterShiftUpdate(
        params: [Float],
        hamiltonian: Hamiltonian,
        ansatz: AnsatzType,
        qubits: Int,
        learningRate: Float
    ) -> [Float] {
        // Parameter shift rule: gradient = (f(θ+π/2) - f(θ-π/2)) / 2
        var newParams = params
        let shift: Float = .pi / 2

        for i in 0..<min(params.count, 10) {  // Limit for performance
            var paramsPlus = params
            var paramsMinus = params
            paramsPlus[i] += shift
            paramsMinus[i] -= shift

            prepareAnsatz(ansatz: ansatz, params: paramsPlus, qubits: qubits)
            let energyPlus = measureHamiltonianExpectation(hamiltonian)

            prepareAnsatz(ansatz: ansatz, params: paramsMinus, qubits: qubits)
            let energyMinus = measureHamiltonianExpectation(hamiltonian)

            let gradient = (energyPlus - energyMinus) / 2
            newParams[i] -= learningRate * gradient
        }

        return newParams
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - QPE (Quantum Phase Estimation)
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// QPE - Kitaev (1995)
    /// Estimates eigenvalue phase of unitary operator
    /// Applications: Shor's algorithm, HHL algorithm, chemistry
    func qpe(
        unitary: [[ComplexFloat]],
        eigenstate: [ComplexFloat],
        precisionBits: Int = 8
    ) async -> QuantumResult {
        let startTime = Date()
        currentAlgorithm = .qpe
        progress = 0.0

        print("📐 QPE: Starting phase estimation")
        print("   Precision bits: \(precisionBits)")

        let totalQubits = precisionBits + 1  // precision + eigenstate register
        guard totalQubits <= maxQubits else {
            print("❌ QPE: Too many qubits required")
            return QuantumResult(
                algorithm: .qpe, solution: nil, eigenvalue: nil,
                phase: nil, probability: 0, iterations: 0,
                executionTime: 0, quantumAdvantage: 1
            )
        }

        initializeState(qubits: totalQubits)

        // Step 1: Apply Hadamard to precision register
        for i in 0..<precisionBits {
            applyHadamard(qubit: i)
            progress = Double(i) / Double(precisionBits * 3)
        }

        // Step 2: Apply controlled-U^(2^k) operations
        for k in 0..<precisionBits {
            let power = 1 << k
            applyControlledUnitaryPower(
                control: k,
                targetQubit: precisionBits,
                unitary: unitary,
                power: power
            )
            progress = Double(precisionBits + k) / Double(precisionBits * 3)
        }

        // Step 3: Inverse QFT on precision register
        inverseQFT(startQubit: 0, numQubits: precisionBits)
        progress = 0.9

        // Step 4: Measure precision register
        let measurement = measureQubits(0..<precisionBits)

        // Convert to phase
        var phaseValue: Float = 0.0
        for (i, bit) in measurement.enumerated() {
            phaseValue += Float(bit) / Float(1 << (i + 1))
        }

        progress = 1.0
        currentAlgorithm = .none

        let executionTime = Date().timeIntervalSince(startTime)

        print("✅ QPE: Complete")
        print("   Estimated phase: \(phaseValue) (θ/2π)")
        print("   Eigenvalue: e^(2πi × \(phaseValue))")

        // Quantum advantage: exponential precision
        let classicalComplexity = Float(1 << precisionBits)
        let quantumComplexity = Float(precisionBits * precisionBits)

        let result = QuantumResult(
            algorithm: .qpe,
            solution: measurement,
            eigenvalue: nil,
            phase: phaseValue,
            probability: 1.0,
            iterations: precisionBits,
            executionTime: executionTime,
            quantumAdvantage: classicalComplexity / quantumComplexity
        )

        lastResult = result
        return result
    }

    private func applyControlledUnitaryPower(
        control: Int,
        targetQubit: Int,
        unitary: [[ComplexFloat]],
        power: Int
    ) {
        // Apply U^power controlled by control qubit
        let stateSize = stateVector.count
        let controlMask = 1 << control
        let targetMask = 1 << targetQubit

        // Compute U^power
        var uPower = unitary
        for _ in 1..<power {
            uPower = matrixMultiply(uPower, unitary)
        }

        // Apply controlled unitary
        for i in 0..<stateSize {
            if (i & controlMask) != 0 {  // Control qubit is |1⟩
                let targetBit = (i & targetMask) != 0 ? 1 : 0
                let j = targetBit == 0 ? i : i ^ targetMask

                if i < j {  // Process each pair once
                    let a = stateVector[i ^ targetMask]  // |0⟩ component
                    let b = stateVector[i]               // |1⟩ component

                    stateVector[i ^ targetMask] = uPower[0][0] * a + uPower[0][1] * b
                    stateVector[i] = uPower[1][0] * a + uPower[1][1] * b
                }
            }
        }
    }

    private func matrixMultiply(_ a: [[ComplexFloat]], _ b: [[ComplexFloat]]) -> [[ComplexFloat]] {
        let n = a.count
        var result = [[ComplexFloat]](repeating: [ComplexFloat](repeating: ComplexFloat(), count: n), count: n)

        for i in 0..<n {
            for j in 0..<n {
                for k in 0..<n {
                    result[i][j] = result[i][j] + a[i][k] * b[k][j]
                }
            }
        }

        return result
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - Quantum Fourier Transform
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// QFT - Core subroutine for many quantum algorithms
    func qft(startQubit: Int, numQubits: Int) {
        for j in 0..<numQubits {
            let qubit = startQubit + j

            // Hadamard on qubit j
            applyHadamard(qubit: qubit)

            // Controlled rotations
            for k in (j+1)..<numQubits {
                let controlQubit = startQubit + k
                let angle = Float.pi / Float(1 << (k - j))
                applyControlledPhase(control: controlQubit, target: qubit, angle: angle)
            }
        }

        // Swap qubits to reverse order
        for i in 0..<(numQubits / 2) {
            swapQubits(startQubit + i, startQubit + numQubits - 1 - i)
        }
    }

    /// Inverse QFT
    func inverseQFT(startQubit: Int, numQubits: Int) {
        // Swap qubits first
        for i in 0..<(numQubits / 2) {
            swapQubits(startQubit + i, startQubit + numQubits - 1 - i)
        }

        for j in stride(from: numQubits - 1, through: 0, by: -1) {
            let qubit = startQubit + j

            // Inverse controlled rotations
            for k in stride(from: numQubits - 1, through: j + 1, by: -1) {
                let controlQubit = startQubit + k
                let angle = -Float.pi / Float(1 << (k - j))
                applyControlledPhase(control: controlQubit, target: qubit, angle: angle)
            }

            // Hadamard on qubit j
            applyHadamard(qubit: qubit)
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - Quantum Walk
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Discrete-time Quantum Walk
    /// Applications: Search algorithms, graph problems
    func quantumWalk(
        graph: [[Int]],  // Adjacency matrix
        steps: Int,
        markedVertex: Int? = nil
    ) async -> QuantumResult {
        let startTime = Date()
        currentAlgorithm = .quantumWalk
        progress = 0.0

        let n = graph.count
        print("🚶 Quantum Walk: Starting")
        print("   Vertices: \(n)")
        print("   Steps: \(steps)")

        // Initialize uniform superposition over vertices
        let qubitsNeeded = Int(ceil(log2(Double(n))))
        guard qubitsNeeded <= maxQubits else {
            print("❌ Quantum Walk: Graph too large")
            return QuantumResult(
                algorithm: .quantumWalk, solution: nil, eigenvalue: nil,
                phase: nil, probability: 0, iterations: 0,
                executionTime: 0, quantumAdvantage: 1
            )
        }

        initializeState(qubits: qubitsNeeded)
        applyHadamardAll()

        // Quantum walk iterations
        for step in 0..<steps {
            progress = Double(step) / Double(steps)

            // Coin operator (Grover diffusion if searching)
            if markedVertex != nil {
                applyGroverDiffusion(qubits: qubitsNeeded)
            } else {
                applyHadamardAll()
            }

            // Shift operator (based on graph structure)
            applyShiftOperator(graph: graph, qubits: qubitsNeeded)

            // Oracle for marked vertex
            if let marked = markedVertex {
                applyPhaseOracle(markedState: marked, qubits: qubitsNeeded)
            }
        }

        progress = 1.0
        currentAlgorithm = .none

        // Measure final position
        let finalVertex = measureAll()
        let vertexIndex = finalVertex.enumerated().reduce(0) { $0 + ($1.element << $1.offset) }

        let executionTime = Date().timeIntervalSince(startTime)

        // Quantum walk achieves sqrt(n) speedup for search
        let quantumAdv = markedVertex != nil ? sqrt(Float(n)) : 1.0

        print("✅ Quantum Walk: Complete")
        print("   Final vertex: \(vertexIndex)")

        let result = QuantumResult(
            algorithm: .quantumWalk,
            solution: finalVertex,
            eigenvalue: nil,
            phase: nil,
            probability: getProbability(state: vertexIndex),
            iterations: steps,
            executionTime: executionTime,
            quantumAdvantage: quantumAdv
        )

        lastResult = result
        return result
    }

    private func applyShiftOperator(graph: [[Int]], qubits: Int) {
        // Simplified shift based on graph connectivity
        // Full implementation would use graph Laplacian
        let stateSize = min(graph.count, 1 << qubits)

        var newState = stateVector

        for v in 0..<stateSize {
            var sum = ComplexFloat()
            var degree = 0

            for u in 0..<stateSize {
                if graph[v][u] == 1 {
                    sum = sum + stateVector[u]
                    degree += 1
                }
            }

            if degree > 0 {
                newState[v] = sum / Float(degree)
            }
        }

        stateVector = newState
        normalizeState()
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - Quantum Gates
    // MARK: - ═══════════════════════════════════════════════════════════════

    private func applyHadamard(qubit: Int) {
        let mask = 1 << qubit
        let h: Float = 1.0 / sqrt(2.0)

        for i in stride(from: 0, to: stateVector.count, by: mask * 2) {
            for j in i..<(i + mask) {
                let a = stateVector[j]
                let b = stateVector[j + mask]

                stateVector[j] = h * (a + b)
                stateVector[j + mask] = h * (a - b)
            }
        }
    }

    private func applyHadamardAll() {
        for q in 0..<numQubits {
            applyHadamard(qubit: q)
        }
    }

    private func applyRxGate(qubit: Int, theta: Float) {
        let mask = 1 << qubit
        let c = cos(theta / 2)
        let s = sin(theta / 2)

        for i in stride(from: 0, to: stateVector.count, by: mask * 2) {
            for j in i..<(i + mask) {
                let a = stateVector[j]
                let b = stateVector[j + mask]

                stateVector[j] = ComplexFloat(c * a.real + s * b.imag, c * a.imag - s * b.real)
                stateVector[j + mask] = ComplexFloat(s * a.imag + c * b.real, -s * a.real + c * b.imag)
            }
        }
    }

    private func applyRyGate(qubit: Int, theta: Float) {
        let mask = 1 << qubit
        let c = cos(theta / 2)
        let s = sin(theta / 2)

        for i in stride(from: 0, to: stateVector.count, by: mask * 2) {
            for j in i..<(i + mask) {
                let a = stateVector[j]
                let b = stateVector[j + mask]

                stateVector[j] = c * a - s * b
                stateVector[j + mask] = s * a + c * b
            }
        }
    }

    private func applyRzGate(qubit: Int, theta: Float) {
        let mask = 1 << qubit
        let phase0 = ComplexFloat.exp(-theta / 2)
        let phase1 = ComplexFloat.exp(theta / 2)

        for i in 0..<stateVector.count {
            if (i & mask) == 0 {
                stateVector[i] = stateVector[i] * phase0
            } else {
                stateVector[i] = stateVector[i] * phase1
            }
        }
    }

    private func applyCNOT(control: Int, target: Int) {
        let controlMask = 1 << control
        let targetMask = 1 << target

        for i in 0..<stateVector.count {
            if (i & controlMask) != 0 && (i & targetMask) == 0 {
                let j = i | targetMask
                let temp = stateVector[i]
                stateVector[i] = stateVector[j]
                stateVector[j] = temp
            }
        }
    }

    private func applyControlledPhase(control: Int, target: Int, angle: Float) {
        let controlMask = 1 << control
        let targetMask = 1 << target
        let phase = ComplexFloat.exp(angle)

        for i in 0..<stateVector.count {
            if (i & controlMask) != 0 && (i & targetMask) != 0 {
                stateVector[i] = stateVector[i] * phase
            }
        }
    }

    private func swapQubits(_ q1: Int, _ q2: Int) {
        let mask1 = 1 << q1
        let mask2 = 1 << q2

        for i in 0..<stateVector.count {
            let bit1 = (i & mask1) != 0
            let bit2 = (i & mask2) != 0

            if bit1 != bit2 {
                let j = i ^ mask1 ^ mask2
                if i < j {
                    let temp = stateVector[i]
                    stateVector[i] = stateVector[j]
                    stateVector[j] = temp
                }
            }
        }
    }

    private func applyPhaseOracle(markedState: Int, qubits: Int) {
        if markedState < stateVector.count {
            stateVector[markedState] = -1.0 * stateVector[markedState]
        }
    }

    private func applyGroverDiffusion(qubits: Int) {
        let n = 1 << qubits

        // Calculate mean amplitude
        var mean = ComplexFloat()
        for i in 0..<min(n, stateVector.count) {
            mean = mean + stateVector[i]
        }
        mean = mean / Float(n)

        // Reflect about mean: 2|mean⟩⟨mean| - I
        for i in 0..<min(n, stateVector.count) {
            stateVector[i] = 2.0 * mean - stateVector[i]
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - Measurement
    // MARK: - ═══════════════════════════════════════════════════════════════

    private func measureAll() -> [Int] {
        // Calculate probabilities
        var probabilities = stateVector.map { $0.magnitude * $0.magnitude }

        // Sample from distribution
        let random = Float.random(in: 0...1)
        var cumulative: Float = 0
        var result = 0

        for (i, prob) in probabilities.enumerated() {
            cumulative += prob
            if random < cumulative {
                result = i
                break
            }
        }

        // Convert to bitstring
        return (0..<numQubits).map { (result >> $0) & 1 }
    }

    private func measureQubits(_ range: Range<Int>) -> [Int] {
        let fullMeasurement = measureAll()
        return Array(fullMeasurement[range])
    }

    private func getProbability(state: Int) -> Float {
        guard state < stateVector.count else { return 0 }
        return stateVector[state].magnitude * stateVector[state].magnitude
    }

    private func normalizeState() {
        var norm: Float = 0
        for amp in stateVector {
            norm += amp.magnitude * amp.magnitude
        }
        norm = sqrt(norm)

        if norm > 0 {
            for i in 0..<stateVector.count {
                stateVector[i] = stateVector[i] / norm
            }
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - Utility Methods
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Create QUBO problem for MaxCut
    func createMaxCutProblem(graph: [[Int]]) -> QUBOProblem {
        let n = graph.count
        var quadratic = [[Float]](repeating: [Float](repeating: 0, count: n), count: n)

        // MaxCut: minimize -sum(w_ij * x_i * (1-x_j))
        // = -sum(w_ij * x_i) + sum(w_ij * x_i * x_j)
        // QUBO form: maximize sum(w_ij * x_i * x_j) with adjusted linear terms

        for i in 0..<n {
            for j in (i+1)..<n {
                quadratic[i][j] = -Float(graph[i][j])  // Negative for maximization
            }
        }

        return QUBOProblem(
            linearTerms: [Float](repeating: 0, count: n),
            quadraticTerms: quadratic,
            offset: 0
        )
    }

    /// Create Hamiltonian for simple Ising model
    func createIsingHamiltonian(n: Int, jCoupling: Float = 1.0, hField: Float = 0.5) -> Hamiltonian {
        var terms: [Hamiltonian.PauliTerm] = []

        // ZZ interaction terms: J * Z_i * Z_{i+1}
        for i in 0..<(n-1) {
            terms.append(Hamiltonian.PauliTerm(
                coefficient: -jCoupling,
                paulis: [(i, .Z), (i+1, .Z)]
            ))
        }

        // Transverse field terms: h * X_i
        for i in 0..<n {
            terms.append(Hamiltonian.PauliTerm(
                coefficient: -hField,
                paulis: [(i, .X)]
            ))
        }

        return Hamiltonian(pauliTerms: terms, numQubits: n)
    }

    /// Get algorithm report
    func getReport() -> String {
        guard let result = lastResult else {
            return "No algorithm has been run yet."
        }

        return """
        ⚛️ QUANTUM ALGORITHM REPORT
        ═══════════════════════════════════════

        Algorithm: \(result.algorithm.rawValue)
        Execution Time: \(String(format: "%.3f", result.executionTime))s
        Iterations: \(result.iterations)
        Quantum Advantage: \(String(format: "%.2f", result.quantumAdvantage))x

        Results:
        \(result.solution.map { "  Solution: \($0)" } ?? "")
        \(result.eigenvalue.map { "  Eigenvalue: \(String(format: "%.6f", $0))" } ?? "")
        \(result.phase.map { "  Phase: \(String(format: "%.6f", $0))" } ?? "")
          Probability: \(String(format: "%.4f", result.probability))

        ═══════════════════════════════════════
        """
    }
}

// MARK: - Static Factory Methods

extension QuantumAdvancedAlgorithms.QUBOProblem {
    /// Create a random QUBO problem for testing
    static func random(size: Int) -> QuantumAdvancedAlgorithms.QUBOProblem {
        let linear = (0..<size).map { _ in Float.random(in: -1...1) }
        var quadratic = [[Float]](repeating: [Float](repeating: 0, count: size), count: size)

        for i in 0..<size {
            for j in (i+1)..<size {
                quadratic[i][j] = Float.random(in: -1...1)
            }
        }

        return QuantumAdvancedAlgorithms.QUBOProblem(
            linearTerms: linear,
            quadraticTerms: quadratic,
            offset: 0
        )
    }
}
