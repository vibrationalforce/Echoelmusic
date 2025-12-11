/**
 * Echoelmusic Quantum Engine - WebAssembly
 *
 * TypeScript wrapper for the WebAssembly quantum simulation module.
 *
 * Features:
 * - Full quantum simulation in browser
 * - Up to 20 qubits
 * - Standard quantum gates (H, X, Y, Z, Rx, Ry, Rz, CNOT, CZ, SWAP)
 * - Quantum algorithms (Grover, QFT, Bell states)
 * - Bio-data quantum encoding
 *
 * Usage:
 * ```typescript
 * const qe = await QuantumEngine.create();
 * qe.initialize(4);
 * qe.hadamard(0);
 * qe.cnot(0, 1);
 * const result = qe.measureAll();
 * ```
 */

interface QuantumModule {
  _quantum_initialize(numQubits: number): number;
  _quantum_shutdown(): void;
  _quantum_get_num_qubits(): number;
  _quantum_get_state_size(): number;
  _quantum_initialize_superposition(): void;
  _quantum_reset(): void;

  // Single-qubit gates
  _quantum_hadamard(qubit: number): void;
  _quantum_pauli_x(qubit: number): void;
  _quantum_pauli_y(qubit: number): void;
  _quantum_pauli_z(qubit: number): void;
  _quantum_phase(qubit: number, theta: number): void;
  _quantum_rx(qubit: number, theta: number): void;
  _quantum_ry(qubit: number, theta: number): void;
  _quantum_rz(qubit: number, theta: number): void;
  _quantum_t_gate(qubit: number): void;
  _quantum_s_gate(qubit: number): void;

  // Two-qubit gates
  _quantum_cnot(control: number, target: number): void;
  _quantum_cz(control: number, target: number): void;
  _quantum_swap(qubit1: number, qubit2: number): void;
  _quantum_controlled_phase(control: number, target: number, theta: number): void;

  // Three-qubit gates
  _quantum_toffoli(control1: number, control2: number, target: number): void;

  // Measurement
  _quantum_get_probabilities(): number;
  _quantum_measure_all(): number;
  _quantum_measure_qubit(qubit: number): number;

  // Algorithms
  _quantum_grover_diffusion(): void;
  _quantum_phase_oracle(markedState: number): void;
  _quantum_qft(): void;
  _quantum_inverse_qft(): void;

  // State access
  _quantum_get_amplitude_real(index: number): number;
  _quantum_get_amplitude_imag(index: number): number;
  _quantum_set_amplitude(index: number, real: number, imag: number): void;
  _quantum_normalize(): void;

  // Benchmark
  _quantum_benchmark(qubits: number, gates: number): number;

  // Memory
  _malloc(size: number): number;
  _free(ptr: number): void;
  HEAPF32: Float32Array;
}

export interface Complex {
  real: number;
  imag: number;
}

export interface GroverResult {
  searchTarget: number;
  measuredState: number;
  success: boolean;
  iterations: number;
  probability: number;
}

export interface BenchmarkResult {
  qubits: number;
  gates: number;
  timeMs: number;
  gatesPerSecond: number;
}

export class QuantumEngine {
  private module: QuantumModule;
  private initialized: boolean = false;
  private numQubits: number = 0;

  private constructor(module: QuantumModule) {
    this.module = module;
  }

  /**
   * Create and load the quantum engine
   */
  static async create(wasmPath: string = '/quantum.js'): Promise<QuantumEngine> {
    // Load the Emscripten module
    const Module = await import(wasmPath);
    const module = await Module.default() as QuantumModule;
    return new QuantumEngine(module);
  }

  /**
   * Initialize quantum state with specified number of qubits
   */
  initialize(numQubits: number): boolean {
    if (numQubits <= 0 || numQubits > 20) {
      console.error(`Invalid qubit count: ${numQubits} (max: 20)`);
      return false;
    }

    const result = this.module._quantum_initialize(numQubits);
    if (result !== 0) {
      console.error(`Quantum initialization failed with code: ${result}`);
      return false;
    }

    this.numQubits = numQubits;
    this.initialized = true;
    console.log(`Quantum engine initialized with ${numQubits} qubits (${1 << numQubits} amplitudes)`);
    return true;
  }

  /**
   * Shutdown and free resources
   */
  shutdown(): void {
    this.module._quantum_shutdown();
    this.initialized = false;
    this.numQubits = 0;
  }

  /**
   * Initialize to uniform superposition |+...+>
   */
  initializeSuperposition(): void {
    this.checkInitialized();
    this.module._quantum_initialize_superposition();
  }

  /**
   * Reset to |0...0> state
   */
  reset(): void {
    this.checkInitialized();
    this.module._quantum_reset();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLE-QUBIT GATES
  // ═══════════════════════════════════════════════════════════════════════════

  hadamard(qubit: number): void {
    this.validateQubit(qubit);
    this.module._quantum_hadamard(qubit);
  }

  hadamardAll(): void {
    for (let q = 0; q < this.numQubits; q++) {
      this.hadamard(q);
    }
  }

  pauliX(qubit: number): void {
    this.validateQubit(qubit);
    this.module._quantum_pauli_x(qubit);
  }

  pauliY(qubit: number): void {
    this.validateQubit(qubit);
    this.module._quantum_pauli_y(qubit);
  }

  pauliZ(qubit: number): void {
    this.validateQubit(qubit);
    this.module._quantum_pauli_z(qubit);
  }

  phase(qubit: number, theta: number): void {
    this.validateQubit(qubit);
    this.module._quantum_phase(qubit, theta);
  }

  rx(qubit: number, theta: number): void {
    this.validateQubit(qubit);
    this.module._quantum_rx(qubit, theta);
  }

  ry(qubit: number, theta: number): void {
    this.validateQubit(qubit);
    this.module._quantum_ry(qubit, theta);
  }

  rz(qubit: number, theta: number): void {
    this.validateQubit(qubit);
    this.module._quantum_rz(qubit, theta);
  }

  tGate(qubit: number): void {
    this.validateQubit(qubit);
    this.module._quantum_t_gate(qubit);
  }

  sGate(qubit: number): void {
    this.validateQubit(qubit);
    this.module._quantum_s_gate(qubit);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TWO-QUBIT GATES
  // ═══════════════════════════════════════════════════════════════════════════

  cnot(control: number, target: number): void {
    this.validateQubit(control);
    this.validateQubit(target);
    if (control === target) throw new Error('Control and target must be different');
    this.module._quantum_cnot(control, target);
  }

  cz(control: number, target: number): void {
    this.validateQubit(control);
    this.validateQubit(target);
    this.module._quantum_cz(control, target);
  }

  swap(qubit1: number, qubit2: number): void {
    this.validateQubit(qubit1);
    this.validateQubit(qubit2);
    if (qubit1 === qubit2) throw new Error('Qubits must be different');
    this.module._quantum_swap(qubit1, qubit2);
  }

  controlledPhase(control: number, target: number, theta: number): void {
    this.validateQubit(control);
    this.validateQubit(target);
    this.module._quantum_controlled_phase(control, target, theta);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // THREE-QUBIT GATES
  // ═══════════════════════════════════════════════════════════════════════════

  toffoli(control1: number, control2: number, target: number): void {
    this.validateQubit(control1);
    this.validateQubit(control2);
    this.validateQubit(target);
    this.module._quantum_toffoli(control1, control2, target);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEASUREMENT
  // ═══════════════════════════════════════════════════════════════════════════

  getProbabilities(): Float32Array {
    this.checkInitialized();
    const stateSize = 1 << this.numQubits;
    const ptr = this.module._quantum_get_probabilities();

    if (ptr === 0) {
      throw new Error('Failed to get probabilities');
    }

    const probs = new Float32Array(stateSize);
    for (let i = 0; i < stateSize; i++) {
      probs[i] = this.module.HEAPF32[(ptr >> 2) + i];
    }

    this.module._free(ptr);
    return probs;
  }

  measureAll(): number {
    this.checkInitialized();
    return this.module._quantum_measure_all();
  }

  measureQubit(qubit: number): number {
    this.validateQubit(qubit);
    return this.module._quantum_measure_qubit(qubit);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUANTUM ALGORITHMS
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Grover's search algorithm
   */
  groverSearch(markedState: number, iterations?: number): GroverResult {
    this.checkInitialized();

    const stateSize = 1 << this.numQubits;
    if (markedState < 0 || markedState >= stateSize) {
      throw new Error('Marked state out of range');
    }

    const optimalIterations = iterations ?? Math.floor(Math.PI / 4 * Math.sqrt(stateSize));

    // Initialize to uniform superposition
    this.reset();
    this.hadamardAll();

    // Grover iterations
    for (let i = 0; i < optimalIterations; i++) {
      this.module._quantum_phase_oracle(markedState);
      this.module._quantum_grover_diffusion();
    }

    // Get probability of marked state before measurement
    const probs = this.getProbabilities();
    const probability = probs[markedState];

    // Measure
    const measuredState = this.measureAll();

    return {
      searchTarget: markedState,
      measuredState,
      success: measuredState === markedState,
      iterations: optimalIterations,
      probability
    };
  }

  /**
   * Quantum Fourier Transform
   */
  qft(): void {
    this.checkInitialized();
    this.module._quantum_qft();
  }

  /**
   * Inverse Quantum Fourier Transform
   */
  inverseQft(): void {
    this.checkInitialized();
    this.module._quantum_inverse_qft();
  }

  /**
   * Create Bell state (maximally entangled pair)
   */
  createBellState(): number[] {
    if (this.numQubits < 2) {
      throw new Error('Need at least 2 qubits for Bell state');
    }

    this.reset();
    this.hadamard(0);
    this.cnot(0, 1);

    const result = this.measureAll();
    return this.stateToBitstring(result);
  }

  /**
   * Create GHZ state (maximally entangled n qubits)
   */
  createGHZState(): number[] {
    if (this.numQubits < 2) {
      throw new Error('Need at least 2 qubits for GHZ state');
    }

    this.reset();
    this.hadamard(0);
    for (let i = 0; i < this.numQubits - 1; i++) {
      this.cnot(i, i + 1);
    }

    const result = this.measureAll();
    return this.stateToBitstring(result);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BIO-DATA INTEGRATION
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Encode bio-data into quantum state using angle encoding
   */
  encodeBioData(hrvFeatures: number[]): void {
    const n = Math.min(hrvFeatures.length, this.numQubits);

    this.reset();

    // Encode each feature as rotation angle
    for (let i = 0; i < n; i++) {
      const theta = hrvFeatures[i] * Math.PI;
      this.ry(i, theta);
    }

    // Add entanglement layer
    for (let i = 0; i < n - 1; i++) {
      this.cnot(i, i + 1);
    }
  }

  /**
   * Quantum kernel evaluation for bio-data classification
   */
  quantumKernel(x: number[], y: number[]): number {
    if (x.length !== y.length) {
      throw new Error('Feature vectors must have same length');
    }

    // Encode x
    this.encodeBioData(x);
    const probsX = this.getProbabilities();

    // Encode y
    this.encodeBioData(y);
    const probsY = this.getProbabilities();

    // Compute kernel as probability overlap (fidelity)
    let kernel = 0;
    for (let i = 0; i < probsX.length; i++) {
      kernel += Math.sqrt(probsX[i] * probsY[i]);
    }

    return kernel * kernel;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE ACCESS
  // ═══════════════════════════════════════════════════════════════════════════

  getAmplitude(index: number): Complex {
    this.checkInitialized();
    const stateSize = 1 << this.numQubits;
    if (index < 0 || index >= stateSize) {
      throw new Error('Index out of range');
    }

    return {
      real: this.module._quantum_get_amplitude_real(index),
      imag: this.module._quantum_get_amplitude_imag(index)
    };
  }

  setAmplitude(index: number, amplitude: Complex): void {
    this.checkInitialized();
    this.module._quantum_set_amplitude(index, amplitude.real, amplitude.imag);
  }

  normalize(): void {
    this.checkInitialized();
    this.module._quantum_normalize();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BENCHMARK
  // ═══════════════════════════════════════════════════════════════════════════

  benchmark(qubits: number, gates: number = 10000): BenchmarkResult {
    const start = performance.now();
    const completedGates = this.module._quantum_benchmark(qubits, gates);
    const elapsed = performance.now() - start;

    return {
      qubits,
      gates: completedGates,
      timeMs: elapsed,
      gatesPerSecond: completedGates / (elapsed / 1000)
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY
  // ═══════════════════════════════════════════════════════════════════════════

  get stateSize(): number {
    return 1 << this.numQubits;
  }

  get qubitCount(): number {
    return this.numQubits;
  }

  get isInitialized(): boolean {
    return this.initialized;
  }

  private checkInitialized(): void {
    if (!this.initialized) {
      throw new Error('Quantum state not initialized');
    }
  }

  private validateQubit(qubit: number): void {
    this.checkInitialized();
    if (qubit < 0 || qubit >= this.numQubits) {
      throw new Error(`Qubit ${qubit} out of range (0-${this.numQubits - 1})`);
    }
  }

  private stateToBitstring(state: number): number[] {
    const bits: number[] = [];
    for (let i = 0; i < this.numQubits; i++) {
      bits.push((state >> i) & 1);
    }
    return bits;
  }

  /**
   * Get human-readable state info
   */
  getInfo(): string {
    return `Quantum Engine Status:
    - Initialized: ${this.initialized}
    - Qubits: ${this.numQubits}
    - State Size: ${this.stateSize} amplitudes
    - Memory: ${(this.stateSize * 8 / 1024).toFixed(2)} KB`;
  }
}

export default QuantumEngine;
