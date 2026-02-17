import Foundation
import Accelerate

// MARK: - EchoelCellular — Cellular Automata Synthesis Engine
// Sound generation driven by discrete dynamical systems (cellular automata).
// Cell states evolve per timestep according to local rules, driving synthesis parameters.
//
// Paradigms:
//   1. CA-as-Wavetable: 1D CA tape IS the oscillator (circular delay line)
//   2. CA-controlled Additive: Each cell drives one oscillator amplitude
//   3. CA-controlled FM: Cell states modulate FM operator parameters
//   4. 2D CA Spectral: 2D grid (Game of Life) rows become spectral snapshots
//
// Elementary CA Rules:
//   - Rule 30: Class III chaotic — noise-like, complex
//   - Rule 90: Class III fractal — Sierpinski triangle, harmonically structured
//   - Rule 110: Class IV complex — Turing-complete, mixtures of order/chaos
//   - Rule 184: Class II periodic — traffic flow, rhythmic
//
// Bio-Reactive Integration:
//   - Coherence → Rule number (high coherence = harmonic rules, low = chaotic)
//   - HRV → Evolution speed (calm = slow, stressed = fast)
//   - Heart rate → Fundamental frequency
//
// References:
//   - Wolfram, S. (1983) "Statistical mechanics of cellular automata"
//   - Miranda, E.R. (2002) "Cellular automata music: from sound synthesis to composition"
//   - Burraston, D. (2006) "Generative music and cellular automata"

/// EchoelCellular — Cellular Automata Synthesis Engine
/// Generates audio from evolving CA patterns with bio-reactive rule selection
public final class EchoelCellular: @unchecked Sendable {

    // MARK: - Types

    /// How the CA state maps to audio
    public enum SynthMode: String, CaseIterable, Sendable {
        /// CA tape IS the oscillator — each cell = one sample in a wavetable
        case wavetable = "CA Wavetable"
        /// Each cell drives amplitude of one partial in additive synthesis
        case additive = "CA Additive"
        /// Cell states control FM modulation index and ratio
        case fm = "CA FM"
        /// 2D Game of Life grid, rows become spectral frames
        case spectral2D = "CA Spectral 2D"
    }

    /// Elementary CA rule (0-255) wrapper
    public struct CARule: Sendable {
        public let number: UInt8
        private let lookupTable: [UInt8] // 8 entries for 3-bit neighborhood

        public init(_ rule: UInt8) {
            self.number = rule
            var table = [UInt8](repeating: 0, count: 8)
            for i in 0..<8 {
                table[i] = (rule >> i) & 1
            }
            self.lookupTable = table
        }

        /// Evaluate rule for a 3-bit neighborhood (left, center, right)
        public func evaluate(left: UInt8, center: UInt8, right: UInt8) -> UInt8 {
            let index = Int((left << 2) | (center << 1) | right)
            return lookupTable[index]
        }

        // Named rules
        public static let rule30 = CARule(30)   // Chaotic
        public static let rule90 = CARule(90)   // Fractal / Sierpinski
        public static let rule110 = CARule(110) // Complex / Turing-complete
        public static let rule150 = CARule(150) // Additive (XOR neighbors)
        public static let rule184 = CARule(184) // Traffic / rhythmic
        public static let rule60 = CARule(60)   // Sierpinski variant
        public static let rule105 = CARule(105) // Complementary Sierpinski
        public static let rule73 = CARule(73)   // Complex, musical

        /// Rules ordered by musicality (harmonic → chaotic)
        public static let harmonicRules: [UInt8] = [90, 150, 60, 105, 184, 73, 110, 30]
    }

    // MARK: - Configuration

    /// Number of cells in the 1D CA (also determines wavetable size)
    public let cellCount: Int

    /// Sample rate
    public let sampleRate: Float

    // MARK: - State

    /// Current CA state (1D: each cell is 0 or 1)
    private var cells: [UInt8]

    /// Previous CA state (for double-buffering)
    private var cellsPrev: [UInt8]

    /// 2D CA grid (for spectral2D mode)
    private var grid2D: [[UInt8]]

    /// Grid size for 2D mode
    private let grid2DSize: Int = 64

    /// Current wavetable (float values derived from CA state)
    private var wavetable: [Float]

    /// Phase accumulators for additive mode
    private var phases: [Float]

    /// FM carrier phase
    private var fmCarrierPhase: Float = 0

    /// FM modulator phase
    private var fmModulatorPhase: Float = 0

    /// Current spectral frame index for 2D mode
    private var spectralFrameIndex: Int = 0

    // MARK: - Parameters

    /// Current CA rule
    public var rule: CARule = .rule90

    /// Synthesis mode
    public var synthMode: SynthMode = .wavetable

    /// Fundamental frequency (Hz)
    public var frequency: Float = 220.0

    /// CA evolution rate (steps per second)
    public var evolutionRate: Float = 60.0

    /// Number of partials for additive mode
    public var partialCount: Int = 32

    /// FM modulation index
    public var fmModIndex: Float = 3.0

    /// FM carrier:modulator ratio
    public var fmRatio: Float = 2.0

    /// Smoothing between CA states (0 = instant, 1 = very smooth)
    public var smoothing: Float = 0.3

    /// Density threshold (cells above this are "alive")
    public var density: Float = 0.5

    /// Output gain
    public var gain: Float = 0.8

    // MARK: - Bio-Reactive

    /// Coherence maps to rule selection (0-1)
    public var coherence: Float = 0.5 {
        didSet { updateRuleFromCoherence() }
    }

    /// Whether bio-reactive rule selection is enabled
    public var bioReactiveEnabled: Bool = true

    // MARK: - Internal State

    /// Samples since last CA evolution step
    private var samplesSinceEvolution: Float = 0

    /// Smoothed wavetable (interpolated between CA states)
    private var smoothedWavetable: [Float]

    /// Wavetable read phase
    private var wavetablePhase: Float = 0

    // MARK: - Init

    /// Initialize EchoelCellular
    /// - Parameters:
    ///   - cellCount: Number of cells (default 256)
    ///   - sampleRate: Audio sample rate (default 48000)
    public init(cellCount: Int = 256, sampleRate: Float = 48000.0) {
        self.cellCount = cellCount
        self.sampleRate = sampleRate

        self.cells = [UInt8](repeating: 0, count: cellCount)
        self.cellsPrev = [UInt8](repeating: 0, count: cellCount)
        self.wavetable = [Float](repeating: 0, count: cellCount)
        self.smoothedWavetable = [Float](repeating: 0, count: cellCount)
        self.phases = [Float](repeating: 0, count: cellCount)

        // Init 2D grid
        self.grid2D = [[UInt8]](repeating: [UInt8](repeating: 0, count: grid2DSize), count: grid2DSize)

        // Seed with single cell in center (classic CA initialization)
        seed(.singleCenter)
    }

    // MARK: - Seeding

    /// Seed pattern for initial CA state
    public enum SeedPattern: String, CaseIterable, Sendable {
        case singleCenter = "Single Center"
        case random = "Random"
        case alternating = "Alternating"
        case pulse = "Pulse"
        case gradient = "Gradient"
    }

    /// Seed the CA with an initial pattern
    public func seed(_ pattern: SeedPattern) {
        for i in 0..<cellCount {
            cells[i] = 0
        }

        switch pattern {
        case .singleCenter:
            cells[cellCount / 2] = 1

        case .random:
            for i in 0..<cellCount {
                cells[i] = UInt8.random(in: 0...1)
            }

        case .alternating:
            for i in 0..<cellCount {
                cells[i] = UInt8(i % 2)
            }

        case .pulse:
            let center = cellCount / 2
            let width = cellCount / 8
            for i in (center - width)..<(center + width) {
                cells[i] = 1
            }

        case .gradient:
            for i in 0..<cellCount {
                cells[i] = Float(i) / Float(cellCount) > 0.5 ? 1 : 0
            }
        }

        // Copy to prev
        cellsPrev = cells
        updateWavetableFromCells()

        // Seed 2D grid
        seed2DGrid()
    }

    private func seed2DGrid() {
        for y in 0..<grid2DSize {
            for x in 0..<grid2DSize {
                grid2D[y][x] = 0
            }
        }
        // R-pentomino seed (classic Game of Life)
        let cx = grid2DSize / 2
        let cy = grid2DSize / 2
        grid2D[cy - 1][cx] = 1
        grid2D[cy - 1][cx + 1] = 1
        grid2D[cy][cx - 1] = 1
        grid2D[cy][cx] = 1
        grid2D[cy + 1][cx] = 1
    }

    // MARK: - CA Evolution

    /// Evolve the 1D CA by one step
    private func evolve1D() {
        cellsPrev = cells
        for i in 0..<cellCount {
            let left = cells[(i - 1 + cellCount) % cellCount]
            let center = cells[i]
            let right = cells[(i + 1) % cellCount]
            cells[i] = rule.evaluate(left: left, center: center, right: right)
        }
        updateWavetableFromCells()
    }

    /// Evolve 2D Game of Life by one step
    private func evolve2D() {
        var newGrid = grid2D
        for y in 0..<grid2DSize {
            for x in 0..<grid2DSize {
                var neighbors: Int = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        if dx == 0 && dy == 0 { continue }
                        let nx = (x + dx + grid2DSize) % grid2DSize
                        let ny = (y + dy + grid2DSize) % grid2DSize
                        neighbors += Int(grid2D[ny][nx])
                    }
                }
                let alive = grid2D[y][x] == 1
                if alive {
                    newGrid[y][x] = (neighbors == 2 || neighbors == 3) ? 1 : 0
                } else {
                    newGrid[y][x] = neighbors == 3 ? 1 : 0
                }
            }
        }
        grid2D = newGrid
    }

    /// Convert cell states to wavetable values
    private func updateWavetableFromCells() {
        for i in 0..<cellCount {
            wavetable[i] = cells[i] == 1 ? 1.0 : -1.0
        }
    }

    // MARK: - Bio-Reactive Rule Selection

    private func updateRuleFromCoherence() {
        guard bioReactiveEnabled else { return }
        // Map coherence (0-1) to harmonic rules
        // High coherence → harmonic rules (90, 150, 60)
        // Low coherence → chaotic rules (110, 30)
        let ruleIndex = Int(coherence * Float(CARule.harmonicRules.count - 1))
        let clampedIndex = max(0, min(CARule.harmonicRules.count - 1, ruleIndex))
        rule = CARule(CARule.harmonicRules[clampedIndex])
    }

    // MARK: - Audio Generation

    /// Generate audio samples
    /// - Parameters:
    ///   - buffer: Output buffer to fill
    ///   - frameCount: Number of frames
    ///   - stereo: Stereo output (interleaved)
    public func render(buffer: inout [Float], frameCount: Int, stereo: Bool = false) {
        let channelCount = stereo ? 2 : 1
        guard buffer.count >= frameCount * channelCount else { return }

        let samplesPerEvolution = sampleRate / max(1, evolutionRate)

        for frame in 0..<frameCount {
            // Check if we need to evolve
            samplesSinceEvolution += 1
            if samplesSinceEvolution >= samplesPerEvolution {
                samplesSinceEvolution -= samplesPerEvolution

                switch synthMode {
                case .wavetable, .additive, .fm:
                    evolve1D()
                case .spectral2D:
                    evolve2D()
                    spectralFrameIndex = (spectralFrameIndex + 1) % grid2DSize
                }
            }

            // Smooth wavetable transition
            let smoothFactor = 1.0 - smoothing * 0.99
            for i in 0..<cellCount {
                smoothedWavetable[i] += (wavetable[i] - smoothedWavetable[i]) * smoothFactor
            }

            // Generate sample based on mode
            var sample: Float = 0

            switch synthMode {
            case .wavetable:
                sample = renderWavetable()
            case .additive:
                sample = renderAdditive()
            case .fm:
                sample = renderFM()
            case .spectral2D:
                sample = renderSpectral2D()
            }

            sample *= gain

            if stereo {
                buffer[frame * 2] = sample
                buffer[frame * 2 + 1] = sample
            } else {
                buffer[frame] = sample
            }
        }
    }

    // MARK: - Synthesis Modes

    /// Wavetable mode: CA tape IS the oscillator
    private func renderWavetable() -> Float {
        let phaseIncrement = frequency / sampleRate * Float(cellCount)
        wavetablePhase += phaseIncrement
        while wavetablePhase >= Float(cellCount) {
            wavetablePhase -= Float(cellCount)
        }

        // Linear interpolation
        let index = Int(wavetablePhase)
        let frac = wavetablePhase - Float(index)
        let i0 = index % cellCount
        let i1 = (index + 1) % cellCount
        return smoothedWavetable[i0] * (1.0 - frac) + smoothedWavetable[i1] * frac
    }

    /// Additive mode: each cell drives one partial amplitude
    private func renderAdditive() -> Float {
        var sample: Float = 0
        let count = min(partialCount, cellCount)
        let invCount = 1.0 / Float(count)

        for i in 0..<count {
            let partialFreq = frequency * Float(i + 1)
            let phaseInc = partialFreq / sampleRate * 2.0 * .pi
            phases[i] += phaseInc
            if phases[i] > 2.0 * .pi { phases[i] -= 2.0 * .pi }

            // Cell state controls amplitude, with 1/n rolloff
            let amplitude = smoothedWavetable[i] > 0 ? 1.0 / Float(i + 1) : 0
            sample += sin(phases[i]) * amplitude * invCount
        }

        return sample * 4.0 // Compensate for sparse partials
    }

    /// FM mode: cell pattern drives modulation parameters
    private func renderFM() -> Float {
        // Count alive cells to control modulation index
        var aliveCount: Float = 0
        for i in 0..<cellCount {
            if smoothedWavetable[i] > 0 { aliveCount += 1 }
        }
        let aliveRatio = aliveCount / Float(cellCount)

        // Dynamic modulation index based on CA density
        let modIndex = fmModIndex * aliveRatio

        // CA pattern drives frequency ratio modulation
        let dynamicRatio = fmRatio + (smoothedWavetable[0] + smoothedWavetable[cellCount / 4]) * 0.5

        let modFreq = frequency * dynamicRatio
        let modPhaseInc = modFreq / sampleRate * 2.0 * .pi
        fmModulatorPhase += modPhaseInc
        if fmModulatorPhase > 2.0 * .pi { fmModulatorPhase -= 2.0 * .pi }

        let modSignal = sin(fmModulatorPhase) * modIndex

        let carrierPhaseInc = (frequency + modSignal * frequency) / sampleRate * 2.0 * .pi
        fmCarrierPhase += carrierPhaseInc
        if fmCarrierPhase > 2.0 * .pi { fmCarrierPhase -= 2.0 * .pi }

        return sin(fmCarrierPhase)
    }

    /// 2D Spectral mode: Game of Life grid rows become spectral frames
    private func renderSpectral2D() -> Float {
        var sample: Float = 0
        let row = grid2D[spectralFrameIndex % grid2DSize]
        let count = min(partialCount, grid2DSize)
        let invCount = 1.0 / Float(count)

        for i in 0..<count {
            let partialFreq = frequency * Float(i + 1)
            let phaseInc = partialFreq / sampleRate * 2.0 * .pi
            phases[i] += phaseInc
            if phases[i] > 2.0 * .pi { phases[i] -= 2.0 * .pi }

            let amplitude = row[i] == 1 ? 1.0 / Float(i + 1) : Float(0)
            sample += sin(phases[i]) * amplitude * invCount
        }

        return sample * 4.0
    }

    // MARK: - State Access

    /// Get current CA state for visualization (normalized 0-1)
    public func getCellStates() -> [Float] {
        var result = [Float](repeating: 0, count: cellCount)
        for i in 0..<cellCount {
            result[i] = Float(cells[i])
        }
        return result
    }

    /// Get current 2D grid for visualization
    public func getGrid2D() -> [[Float]] {
        var result = [[Float]](repeating: [Float](repeating: 0, count: grid2DSize), count: grid2DSize)
        for y in 0..<grid2DSize {
            for x in 0..<grid2DSize {
                result[y][x] = Float(grid2D[y][x])
            }
        }
        return result
    }

    /// Get current rule number
    public func getRuleNumber() -> UInt8 {
        return rule.number
    }

    // MARK: - Reset

    /// Reset to initial state
    public func reset() {
        seed(.singleCenter)
        wavetablePhase = 0
        fmCarrierPhase = 0
        fmModulatorPhase = 0
        samplesSinceEvolution = 0
        spectralFrameIndex = 0
        for i in 0..<cellCount {
            phases[i] = 0
            smoothedWavetable[i] = 0
        }
    }
}
