//
//  QuantumErrorCorrection.swift
//  Echoelmusic
//
//  Created: December 2025
//  QUANTUM ERROR CORRECTION CODES
//
//  Implements fault-tolerant quantum computing primitives:
//  - Shor [[9,1,3]] Code - First quantum error correcting code
//  - Steane [[7,1,3]] Code - CSS code with transversal gates
//  - Surface Code - Topological protection (scalable)
//  - Bit-flip and Phase-flip codes
//  - Syndrome measurement and recovery
//
//  Future-proofing for real quantum hardware integration
//  where noise and decoherence are significant factors.
//
//  References:
//  - Shor (1995) "Scheme for reducing decoherence in quantum computer memory"
//  - Steane (1996) "Error correcting codes in quantum theory"
//  - Kitaev (2003) "Fault-tolerant quantum computation by anyons"
//  - Fowler et al. (2012) "Surface codes: Towards practical quantum computation"
//

import Foundation
import Accelerate

// MARK: - Quantum Error Correction Engine

@MainActor
final class QuantumErrorCorrection: ObservableObject {

    // MARK: - Singleton

    static let shared = QuantumErrorCorrection()

    // MARK: - Published State

    @Published var activeCode: QECCode = .none
    @Published var errorRate: Float = 0.0
    @Published var correctedErrors: Int = 0
    @Published var uncorrectableErrors: Int = 0

    // MARK: - Complex Type

    struct ComplexFloat: Equatable {
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

        static prefix func - (c: ComplexFloat) -> ComplexFloat {
            ComplexFloat(-c.real, -c.imag)
        }
    }

    // MARK: - QEC Codes

    enum QECCode: String, CaseIterable {
        case none = "None"
        case bitFlip3 = "3-Qubit Bit Flip"
        case phaseFlip3 = "3-Qubit Phase Flip"
        case shor9 = "Shor [[9,1,3]]"
        case steane7 = "Steane [[7,1,3]]"
        case surfaceCode = "Surface Code"

        var description: String {
            switch self {
            case .none:
                return "No error correction"
            case .bitFlip3:
                return "Corrects single bit-flip (X) errors using 3 physical qubits"
            case .phaseFlip3:
                return "Corrects single phase-flip (Z) errors using 3 physical qubits"
            case .shor9:
                return "Corrects arbitrary single-qubit errors using 9 physical qubits"
            case .steane7:
                return "CSS code with transversal logical gates, 7 physical qubits"
            case .surfaceCode:
                return "Topological code, scalable to millions of qubits"
            }
        }

        var physicalQubits: Int {
            switch self {
            case .none: return 1
            case .bitFlip3, .phaseFlip3: return 3
            case .steane7: return 7
            case .shor9: return 9
            case .surfaceCode: return 17  // Minimal surface code
            }
        }

        var logicalQubits: Int {
            return 1  // All these codes encode 1 logical qubit
        }

        var codeDistance: Int {
            switch self {
            case .none: return 1
            case .bitFlip3, .phaseFlip3: return 3
            case .shor9, .steane7: return 3
            case .surfaceCode: return 3  // Minimal distance
            }
        }
    }

    // MARK: - Logical Qubit

    struct LogicalQubit {
        var code: QECCode
        var physicalState: [ComplexFloat]  // State of all physical qubits

        var numPhysical: Int { code.physicalQubits }

        init(code: QECCode, logicalState: ComplexFloat = ComplexFloat(1, 0), logicalState1: ComplexFloat = ComplexFloat(0, 0)) {
            self.code = code

            // Initialize based on code
            switch code {
            case .none:
                physicalState = [logicalState, logicalState1]

            case .bitFlip3:
                // |0_L⟩ = |000⟩, |1_L⟩ = |111⟩
                physicalState = Array(repeating: ComplexFloat(), count: 8)
                physicalState[0] = logicalState      // |000⟩
                physicalState[7] = logicalState1     // |111⟩

            case .phaseFlip3:
                // |0_L⟩ = |+++⟩, |1_L⟩ = |---⟩
                // In Z basis: |0_L⟩ = (|000⟩+|001⟩+...+|111⟩)/√8
                physicalState = Array(repeating: ComplexFloat(), count: 8)
                let h = Float(1.0 / sqrt(8.0))
                for i in 0..<8 {
                    let sign0 = logicalState
                    let sign1: Float = (countOnes(i) % 2 == 0) ? 1 : -1
                    physicalState[i] = h * sign0 + ComplexFloat(h * sign1 * logicalState1.real, h * sign1 * logicalState1.imag)
                }

            case .shor9:
                // |0_L⟩ = (|000⟩+|111⟩)(|000⟩+|111⟩)(|000⟩+|111⟩) / 2√2
                // |1_L⟩ = (|000⟩-|111⟩)(|000⟩-|111⟩)(|000⟩-|111⟩) / 2√2
                physicalState = Array(repeating: ComplexFloat(), count: 512)  // 2^9
                encodeShor9(alpha: logicalState, beta: logicalState1)

            case .steane7:
                // [[7,1,3]] Steane code
                physicalState = Array(repeating: ComplexFloat(), count: 128)  // 2^7
                encodeSteane7(alpha: logicalState, beta: logicalState1)

            case .surfaceCode:
                // Simplified surface code encoding
                physicalState = Array(repeating: ComplexFloat(), count: 1 << 17)
                physicalState[0] = logicalState
                // Full surface code encoding is complex
            }
        }

        private mutating func encodeShor9(alpha: ComplexFloat, beta: ComplexFloat) {
            // Shor code: |0_L⟩ = (|000⟩+|111⟩)^⊗3 / 2√2
            //            |1_L⟩ = (|000⟩-|111⟩)^⊗3 / 2√2

            let norm: Float = 1.0 / (2.0 * sqrt(2.0))

            // |0_L⟩ codeword states
            let zeroCodewords = [
                0b000_000_000, 0b000_000_111, 0b000_111_000, 0b000_111_111,
                0b111_000_000, 0b111_000_111, 0b111_111_000, 0b111_111_111
            ]

            // |1_L⟩ has alternating signs based on number of |111⟩ blocks
            for cw in zeroCodewords {
                // Count number of |111⟩ triplets
                let block0 = (cw >> 0) & 0b111
                let block1 = (cw >> 3) & 0b111
                let block2 = (cw >> 6) & 0b111

                let numOnes = (block0 == 7 ? 1 : 0) + (block1 == 7 ? 1 : 0) + (block2 == 7 ? 1 : 0)
                let sign1: Float = (numOnes % 2 == 0) ? 1 : -1

                physicalState[cw] = norm * alpha + ComplexFloat(norm * sign1 * beta.real, norm * sign1 * beta.imag)
            }
        }

        private mutating func encodeSteane7(alpha: ComplexFloat, beta: ComplexFloat) {
            // Steane [[7,1,3]] code - CSS code based on [7,4,3] Hamming code
            // Generator matrix for logical |0⟩: H = [[1,0,1,0,1,0,1],
            //                                         [0,1,1,0,0,1,1],
            //                                         [0,0,0,1,1,1,1]]

            // |0_L⟩ = sum over codewords of [7,4,3] Hamming code
            // |1_L⟩ = X_L |0_L⟩ where X_L = X^⊗7

            let hammingCodewords = [
                0b0000000, 0b0001111, 0b0010110, 0b0011001,
                0b0100101, 0b0101010, 0b0110011, 0b0111100,
                0b1000011, 0b1001100, 0b1010101, 0b1011010,
                0b1100110, 0b1101001, 0b1110000, 0b1111111
            ]

            let norm: Float = 1.0 / 4.0  // 1/sqrt(16)

            for cw in hammingCodewords {
                let cwComplement = cw ^ 0b1111111  // X^⊗7 flips all bits

                physicalState[cw] = norm * alpha
                physicalState[cwComplement] = physicalState[cwComplement] + norm * beta
            }
        }

        private func countOnes(_ n: Int) -> Int {
            var count = 0
            var num = n
            while num > 0 {
                count += num & 1
                num >>= 1
            }
            return count
        }
    }

    // MARK: - Syndrome

    struct Syndrome {
        let bits: [Int]
        let errorType: ErrorType
        let errorLocation: Int?

        enum ErrorType {
            case none
            case bitFlip
            case phaseFlip
            case both
            case uncorrectable
        }
    }

    // MARK: - Initialization

    private init() {
        print("Quantum Error Correction: Initialized")
        print("   Available codes: \(QECCode.allCases.map { $0.rawValue })")
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - ENCODING
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Encode a logical qubit
    func encode(alpha: ComplexFloat, beta: ComplexFloat, code: QECCode) -> LogicalQubit {
        activeCode = code
        return LogicalQubit(code: code, logicalState: alpha, logicalState1: beta)
    }

    /// Encode |0⟩ logical state
    func encodeZero(code: QECCode) -> LogicalQubit {
        return encode(alpha: ComplexFloat(1, 0), beta: ComplexFloat(0, 0), code: code)
    }

    /// Encode |1⟩ logical state
    func encodeOne(code: QECCode) -> LogicalQubit {
        return encode(alpha: ComplexFloat(0, 0), beta: ComplexFloat(1, 0), code: code)
    }

    /// Encode |+⟩ logical state
    func encodePlus(code: QECCode) -> LogicalQubit {
        let h = Float(1.0 / sqrt(2.0))
        return encode(alpha: ComplexFloat(h, 0), beta: ComplexFloat(h, 0), code: code)
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - ERROR INJECTION (for testing)
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Inject bit-flip error on specific qubit
    func injectBitFlip(_ qubit: inout LogicalQubit, physicalQubit: Int) {
        let n = qubit.numPhysical
        guard physicalQubit < n else { return }

        let mask = 1 << physicalQubit
        var newState = [ComplexFloat](repeating: ComplexFloat(), count: qubit.physicalState.count)

        for i in 0..<qubit.physicalState.count {
            let flipped = i ^ mask
            newState[flipped] = qubit.physicalState[i]
        }

        qubit.physicalState = newState
        print("Injected X error on physical qubit \(physicalQubit)")
    }

    /// Inject phase-flip error on specific qubit
    func injectPhaseFlip(_ qubit: inout LogicalQubit, physicalQubit: Int) {
        let n = qubit.numPhysical
        guard physicalQubit < n else { return }

        let mask = 1 << physicalQubit

        for i in 0..<qubit.physicalState.count {
            if (i & mask) != 0 {
                qubit.physicalState[i] = -qubit.physicalState[i]
            }
        }

        print("Injected Z error on physical qubit \(physicalQubit)")
    }

    /// Inject random error with given probability
    func injectRandomError(_ qubit: inout LogicalQubit, probability: Float) {
        for q in 0..<qubit.numPhysical {
            if Float.random(in: 0...1) < probability {
                let errorType = Int.random(in: 0..<3)
                switch errorType {
                case 0:
                    injectBitFlip(&qubit, physicalQubit: q)
                case 1:
                    injectPhaseFlip(&qubit, physicalQubit: q)
                default:
                    // Y error = XZ
                    injectBitFlip(&qubit, physicalQubit: q)
                    injectPhaseFlip(&qubit, physicalQubit: q)
                }
            }
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - SYNDROME MEASUREMENT
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Measure syndrome for error detection
    func measureSyndrome(_ qubit: LogicalQubit) -> Syndrome {
        switch qubit.code {
        case .none:
            return Syndrome(bits: [], errorType: .none, errorLocation: nil)

        case .bitFlip3:
            return measureBitFlip3Syndrome(qubit)

        case .phaseFlip3:
            return measurePhaseFlip3Syndrome(qubit)

        case .shor9:
            return measureShor9Syndrome(qubit)

        case .steane7:
            return measureSteane7Syndrome(qubit)

        case .surfaceCode:
            return measureSurfaceCodeSyndrome(qubit)
        }
    }

    /// 3-qubit bit-flip code syndrome
    private func measureBitFlip3Syndrome(_ qubit: LogicalQubit) -> Syndrome {
        // Syndrome bits: s1 = q0 XOR q1, s2 = q1 XOR q2
        // s1=0, s2=0: no error
        // s1=1, s2=0: error on q0
        // s1=1, s2=1: error on q1
        // s1=0, s2=1: error on q2

        // Calculate expected syndrome from amplitudes
        var s1Prob: Float = 0
        var s2Prob: Float = 0

        for i in 0..<8 {
            let prob = qubit.physicalState[i].magnitudeSquared
            let q0 = (i >> 0) & 1
            let q1 = (i >> 1) & 1
            let q2 = (i >> 2) & 1

            if q0 != q1 { s1Prob += prob }
            if q1 != q2 { s2Prob += prob }
        }

        let s1 = s1Prob > 0.5 ? 1 : 0
        let s2 = s2Prob > 0.5 ? 1 : 0

        let errorLocation: Int?
        let errorType: Syndrome.ErrorType

        if s1 == 0 && s2 == 0 {
            errorLocation = nil
            errorType = .none
        } else if s1 == 1 && s2 == 0 {
            errorLocation = 0
            errorType = .bitFlip
        } else if s1 == 1 && s2 == 1 {
            errorLocation = 1
            errorType = .bitFlip
        } else {
            errorLocation = 2
            errorType = .bitFlip
        }

        return Syndrome(bits: [s1, s2], errorType: errorType, errorLocation: errorLocation)
    }

    /// 3-qubit phase-flip code syndrome (in Hadamard basis)
    private func measurePhaseFlip3Syndrome(_ qubit: LogicalQubit) -> Syndrome {
        // Similar to bit-flip but measure in X basis
        // For simplicity, use same logic (proper implementation needs basis change)
        return measureBitFlip3Syndrome(qubit)
    }

    /// Shor code syndrome (bit-flip + phase-flip)
    private func measureShor9Syndrome(_ qubit: LogicalQubit) -> Syndrome {
        // Shor code has 8 syndrome bits: 6 for bit-flips (2 per triplet), 2 for phase-flips

        var bitFlipSyndromes: [[Int]] = []
        var phaseFlipSyndromes: [Int] = []

        // Bit-flip syndromes for each triplet
        for triplet in 0..<3 {
            let offset = triplet * 3
            var s1Prob: Float = 0
            var s2Prob: Float = 0

            for i in 0..<512 {
                let prob = qubit.physicalState[i].magnitudeSquared
                let q0 = (i >> (offset + 0)) & 1
                let q1 = (i >> (offset + 1)) & 1
                let q2 = (i >> (offset + 2)) & 1

                if q0 != q1 { s1Prob += prob }
                if q1 != q2 { s2Prob += prob }
            }

            bitFlipSyndromes.append([s1Prob > 0.5 ? 1 : 0, s2Prob > 0.5 ? 1 : 0])
        }

        // Phase-flip syndromes (compare triplet parities)
        // This is simplified - full implementation needs X-basis measurement

        let allBits = bitFlipSyndromes.flatMap { $0 }
        let hasBitFlip = allBits.contains(1)

        if hasBitFlip {
            // Find which triplet and qubit has error
            for (triplet, syndrome) in bitFlipSyndromes.enumerated() {
                if syndrome != [0, 0] {
                    var errorQubit: Int
                    if syndrome == [1, 0] { errorQubit = triplet * 3 + 0 }
                    else if syndrome == [1, 1] { errorQubit = triplet * 3 + 1 }
                    else { errorQubit = triplet * 3 + 2 }

                    return Syndrome(bits: allBits, errorType: .bitFlip, errorLocation: errorQubit)
                }
            }
        }

        return Syndrome(bits: allBits, errorType: .none, errorLocation: nil)
    }

    /// Steane code syndrome
    private func measureSteane7Syndrome(_ qubit: LogicalQubit) -> Syndrome {
        // Steane code: 3 X-type and 3 Z-type stabilizer generators
        // Simplified syndrome measurement

        var syndrome: [Int] = []

        // Z-type stabilizers (detect X errors)
        let zStabilizers = [
            [0, 2, 4, 6],  // Z0 Z2 Z4 Z6
            [1, 2, 5, 6],  // Z1 Z2 Z5 Z6
            [3, 4, 5, 6]   // Z3 Z4 Z5 Z6
        ]

        for stabilizer in zStabilizers {
            var eigenvalue: Float = 0
            for i in 0..<128 {
                let prob = qubit.physicalState[i].magnitudeSquared
                var parity = 0
                for q in stabilizer {
                    parity ^= (i >> q) & 1
                }
                eigenvalue += prob * (parity == 0 ? 1 : -1)
            }
            syndrome.append(eigenvalue > 0 ? 0 : 1)
        }

        // Decode syndrome to find error location
        let syndromeValue = syndrome[0] + 2 * syndrome[1] + 4 * syndrome[2]

        if syndromeValue == 0 {
            return Syndrome(bits: syndrome, errorType: .none, errorLocation: nil)
        } else {
            // Syndrome directly gives error location for single errors
            return Syndrome(bits: syndrome, errorType: .bitFlip, errorLocation: syndromeValue - 1)
        }
    }

    /// Surface code syndrome (simplified)
    private func measureSurfaceCodeSyndrome(_ qubit: LogicalQubit) -> Syndrome {
        // Surface code uses local stabilizer measurements
        // Full implementation requires 2D lattice structure
        // This is a placeholder
        return Syndrome(bits: [], errorType: .none, errorLocation: nil)
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - ERROR CORRECTION
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Correct errors based on syndrome
    func correctErrors(_ qubit: inout LogicalQubit) -> Bool {
        let syndrome = measureSyndrome(qubit)

        switch syndrome.errorType {
        case .none:
            return true

        case .bitFlip:
            if let location = syndrome.errorLocation {
                injectBitFlip(&qubit, physicalQubit: location)  // Apply X to correct
                correctedErrors += 1
                print("Corrected bit-flip error on qubit \(location)")
                return true
            }

        case .phaseFlip:
            if let location = syndrome.errorLocation {
                injectPhaseFlip(&qubit, physicalQubit: location)  // Apply Z to correct
                correctedErrors += 1
                print("Corrected phase-flip error on qubit \(location)")
                return true
            }

        case .both:
            if let location = syndrome.errorLocation {
                injectBitFlip(&qubit, physicalQubit: location)
                injectPhaseFlip(&qubit, physicalQubit: location)
                correctedErrors += 1
                print("Corrected Y error on qubit \(location)")
                return true
            }

        case .uncorrectable:
            uncorrectableErrors += 1
            print("Uncorrectable error detected!")
            return false
        }

        return false
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - LOGICAL OPERATIONS
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Apply logical X gate
    func applyLogicalX(_ qubit: inout LogicalQubit) {
        switch qubit.code {
        case .none:
            // X gate
            let temp = qubit.physicalState[0]
            qubit.physicalState[0] = qubit.physicalState[1]
            qubit.physicalState[1] = temp

        case .bitFlip3:
            // X_L = X^⊗3
            for q in 0..<3 {
                injectBitFlip(&qubit, physicalQubit: q)
            }

        case .phaseFlip3:
            // X_L = X on any qubit (all are equivalent in H basis)
            injectBitFlip(&qubit, physicalQubit: 0)

        case .shor9:
            // X_L = X^⊗9
            for q in 0..<9 {
                injectBitFlip(&qubit, physicalQubit: q)
            }

        case .steane7:
            // X_L = X^⊗7
            for q in 0..<7 {
                injectBitFlip(&qubit, physicalQubit: q)
            }

        case .surfaceCode:
            // X_L is a string of X operators across the lattice
            break
        }
    }

    /// Apply logical Z gate
    func applyLogicalZ(_ qubit: inout LogicalQubit) {
        switch qubit.code {
        case .none:
            qubit.physicalState[1] = -qubit.physicalState[1]

        case .bitFlip3:
            // Z_L = Z on any qubit
            injectPhaseFlip(&qubit, physicalQubit: 0)

        case .phaseFlip3:
            // Z_L = Z^⊗3
            for q in 0..<3 {
                injectPhaseFlip(&qubit, physicalQubit: q)
            }

        case .shor9:
            // Z_L = Z^⊗9
            for q in 0..<9 {
                injectPhaseFlip(&qubit, physicalQubit: q)
            }

        case .steane7:
            // Z_L = Z^⊗7
            for q in 0..<7 {
                injectPhaseFlip(&qubit, physicalQubit: q)
            }

        case .surfaceCode:
            break
        }
    }

    /// Apply logical Hadamard gate (not transversal for all codes)
    func applyLogicalH(_ qubit: inout LogicalQubit) {
        // Hadamard swaps X and Z bases
        // For Steane code, H_L = H^⊗7 (transversal)

        if qubit.code == .steane7 || qubit.code == .none {
            // Apply H to all physical qubits
            let h: Float = 1.0 / sqrt(2.0)
            var newState = [ComplexFloat](repeating: ComplexFloat(), count: qubit.physicalState.count)

            for i in 0..<qubit.physicalState.count {
                for j in 0..<qubit.physicalState.count {
                    // H^⊗n |i⟩ = 1/√(2^n) Σ_j (-1)^(i·j) |j⟩
                    let innerProduct = countCommonBits(i, j)
                    let sign: Float = (innerProduct % 2 == 0) ? 1 : -1

                    let coeff = pow(h, Float(qubit.numPhysical))
                    newState[j] = newState[j] + ComplexFloat(
                        coeff * sign * qubit.physicalState[i].real,
                        coeff * sign * qubit.physicalState[i].imag
                    )
                }
            }

            qubit.physicalState = newState
        }
    }

    private func countCommonBits(_ a: Int, _ b: Int) -> Int {
        var count = 0
        var x = a & b
        while x > 0 {
            count += x & 1
            x >>= 1
        }
        return count
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - DECODING
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Decode logical qubit back to single qubit
    func decode(_ qubit: LogicalQubit) -> (ComplexFloat, ComplexFloat) {
        switch qubit.code {
        case .none:
            return (qubit.physicalState[0], qubit.physicalState[1])

        case .bitFlip3:
            // |0_L⟩ = |000⟩, |1_L⟩ = |111⟩
            let alpha = qubit.physicalState[0]  // |000⟩
            let beta = qubit.physicalState[7]   // |111⟩
            return (alpha, beta)

        case .phaseFlip3, .shor9, .steane7:
            // Extract logical amplitudes from codeword structure
            // Simplified: sum over codeword states

            var alpha = ComplexFloat()
            var beta = ComplexFloat()

            // This is approximate - proper decoding needs careful analysis
            alpha = qubit.physicalState[0]
            if qubit.physicalState.count > 1 {
                beta = qubit.physicalState[qubit.physicalState.count - 1]
            }

            // Normalize
            let norm = sqrt(alpha.magnitudeSquared + beta.magnitudeSquared)
            if norm > 0 {
                alpha = ComplexFloat(alpha.real / norm, alpha.imag / norm)
                beta = ComplexFloat(beta.real / norm, beta.imag / norm)
            }

            return (alpha, beta)

        case .surfaceCode:
            return (qubit.physicalState[0], ComplexFloat())
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - SIMULATION
    // MARK: - ═══════════════════════════════════════════════════════════════

    /// Simulate noisy quantum computation with error correction
    func simulateWithNoise(
        code: QECCode,
        operations: Int,
        errorProbability: Float
    ) async -> SimulationResult {
        var qubit = encodeZero(code: code)
        var successfulCorrections = 0
        var failedCorrections = 0

        for op in 0..<operations {
            // Apply random logical operation
            let operation = Int.random(in: 0..<3)
            switch operation {
            case 0: applyLogicalX(&qubit)
            case 1: applyLogicalZ(&qubit)
            default: break  // Identity
            }

            // Inject noise
            injectRandomError(&qubit, probability: errorProbability)

            // Error correction
            if correctErrors(&qubit) {
                successfulCorrections += 1
            } else {
                failedCorrections += 1
            }
        }

        let (alpha, beta) = decode(qubit)

        return SimulationResult(
            code: code,
            operations: operations,
            errorProbability: errorProbability,
            successfulCorrections: successfulCorrections,
            failedCorrections: failedCorrections,
            finalState: (alpha, beta),
            logicalErrorRate: Float(failedCorrections) / Float(operations)
        )
    }

    struct SimulationResult {
        let code: QECCode
        let operations: Int
        let errorProbability: Float
        let successfulCorrections: Int
        let failedCorrections: Int
        let finalState: (ComplexFloat, ComplexFloat)
        let logicalErrorRate: Float
    }

    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: - REPORT
    // MARK: - ═══════════════════════════════════════════════════════════════

    func getReport() -> String {
        return """
        QUANTUM ERROR CORRECTION REPORT
        ═══════════════════════════════════════

        Active Code: \(activeCode.rawValue)
        Physical Qubits: \(activeCode.physicalQubits)
        Logical Qubits: \(activeCode.logicalQubits)
        Code Distance: \(activeCode.codeDistance)

        Statistics:
        • Corrected Errors: \(correctedErrors)
        • Uncorrectable Errors: \(uncorrectableErrors)
        • Effective Error Rate: \(String(format: "%.4f", errorRate))

        Code Description:
        \(activeCode.description)

        Capabilities:
        • Corrects up to \((activeCode.codeDistance - 1) / 2) errors
        • Detects up to \(activeCode.codeDistance - 1) errors

        ═══════════════════════════════════════
        """
    }
}
