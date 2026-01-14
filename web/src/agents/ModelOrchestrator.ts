/**
 * Echoelmusic Model Orchestrator
 *
 * Manages beat-reactive backgrounds and API-driven content generation.
 * Adapts visual parameters dynamically based on audio analysis.
 *
 * Features:
 * - Beat detection and phase tracking
 * - Background style transitions
 * - External API integration (Runway Gen-4 compatible)
 * - Bio-reactive parameter modulation
 */

import {
  OrchestratorConfig,
  BeatData,
  BiometricData,
  BackgroundState,
  BackgroundStyle,
  BackgroundParameters,
} from '../types';

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface GenerationRequest {
  prompt: string;
  style: BackgroundStyle;
  duration: number;
  beatSync: boolean;
  parameters: Partial<BackgroundParameters>;
}

export interface GenerationResult {
  success: boolean;
  textureUrl?: string;
  parameters?: BackgroundParameters;
  error?: string;
}

type OrchestratorCallback = (state: BackgroundState) => void;

// ═══════════════════════════════════════════════════════════════════════════════
// BACKGROUND STYLE PRESETS
// ═══════════════════════════════════════════════════════════════════════════════

const STYLE_PRESETS: Record<BackgroundStyle, BackgroundParameters> = {
  nebula: {
    primaryColor: [0.1, 0.2, 0.5],
    secondaryColor: [0.5, 0.1, 0.3],
    intensity: 0.8,
    speed: 0.3,
    complexity: 0.7,
    depth: 0.9,
    reactivity: 0.6,
  },
  particles: {
    primaryColor: [0.3, 0.7, 1.0],
    secondaryColor: [1.0, 0.5, 0.2],
    intensity: 1.0,
    speed: 0.8,
    complexity: 0.5,
    depth: 0.6,
    reactivity: 0.9,
  },
  waves: {
    primaryColor: [0.2, 0.6, 0.9],
    secondaryColor: [0.1, 0.3, 0.5],
    intensity: 0.7,
    speed: 0.5,
    complexity: 0.4,
    depth: 0.5,
    reactivity: 0.7,
  },
  grid: {
    primaryColor: [0.0, 1.0, 0.5],
    secondaryColor: [0.0, 0.5, 1.0],
    intensity: 0.9,
    speed: 0.6,
    complexity: 0.3,
    depth: 0.8,
    reactivity: 0.8,
  },
  holographic: {
    primaryColor: [0.3, 0.7, 1.0],
    secondaryColor: [1.0, 0.3, 0.7],
    intensity: 1.0,
    speed: 0.7,
    complexity: 0.8,
    depth: 0.7,
    reactivity: 1.0,
  },
  'bio-reactive': {
    primaryColor: [0.2, 0.8, 0.4],
    secondaryColor: [0.8, 0.2, 0.4],
    intensity: 0.6,
    speed: 0.2,
    complexity: 0.5,
    depth: 0.6,
    reactivity: 1.0,
  },
  'quantum-field': {
    primaryColor: [0.5, 0.2, 0.8],
    secondaryColor: [0.2, 0.8, 0.5],
    intensity: 0.9,
    speed: 0.4,
    complexity: 0.9,
    depth: 1.0,
    reactivity: 0.8,
  },
  'sacred-geometry': {
    primaryColor: [1.0, 0.8, 0.3],
    secondaryColor: [0.3, 0.8, 1.0],
    intensity: 0.7,
    speed: 0.2,
    complexity: 1.0,
    depth: 0.8,
    reactivity: 0.5,
  },
};

// ═══════════════════════════════════════════════════════════════════════════════
// BEAT DETECTOR
// ═══════════════════════════════════════════════════════════════════════════════

export class BeatDetector {
  private audioContext: AudioContext | null = null;
  private analyser: AnalyserNode | null = null;
  private source: MediaStreamAudioSourceNode | null = null;
  private dataArray: Uint8Array = new Uint8Array(0);

  private lastBeatTime = 0;
  private beatThreshold = 0.6;
  private minBeatInterval = 200;  // ms
  private beatHistory: number[] = [];

  private bpm = 120;
  private phase = 0;
  private lastTime = 0;

  async initialize(stream?: MediaStream): Promise<void> {
    this.audioContext = new AudioContext();
    this.analyser = this.audioContext.createAnalyser();
    this.analyser.fftSize = 256;
    this.analyser.smoothingTimeConstant = 0.3;

    this.dataArray = new Uint8Array(this.analyser.frequencyBinCount);

    if (stream) {
      this.source = this.audioContext.createMediaStreamSource(stream);
      this.source.connect(this.analyser);
    }
  }

  connectSource(source: AudioNode): void {
    source.connect(this.analyser!);
  }

  analyze(): BeatData {
    if (!this.analyser) {
      return this.getDefaultBeatData();
    }

    const now = performance.now();
    const deltaTime = now - this.lastTime;
    this.lastTime = now;

    // Get frequency data
    this.analyser.getByteFrequencyData(this.dataArray);

    // Calculate frequency bands
    const bass = this.getAverageInRange(0, 10) / 255;
    const mid = this.getAverageInRange(10, 50) / 255;
    const high = this.getAverageInRange(50, 128) / 255;

    // Overall energy
    const energy = (bass * 0.5 + mid * 0.3 + high * 0.2);

    // Beat detection based on bass
    const onset = this.detectOnset(bass, now);

    // Update BPM from beat history
    if (this.beatHistory.length >= 4) {
      this.bpm = this.calculateBPM();
    }

    // Update phase based on BPM
    const beatDuration = 60000 / this.bpm;  // ms
    this.phase += deltaTime / beatDuration;
    this.phase = this.phase % 1;  // Keep in 0-1 range

    // Reset phase on beat
    if (onset) {
      this.phase = 0;
    }

    return {
      bpm: this.bpm,
      phase: this.phase,
      energy,
      frequency: { bass, mid, high },
      onset,
      timestamp: now,
    };
  }

  private getAverageInRange(start: number, end: number): number {
    let sum = 0;
    for (let i = start; i < end && i < this.dataArray.length; i++) {
      sum += this.dataArray[i];
    }
    return sum / (end - start);
  }

  private detectOnset(bass: number, now: number): boolean {
    if (bass > this.beatThreshold && now - this.lastBeatTime > this.minBeatInterval) {
      this.lastBeatTime = now;
      this.beatHistory.push(now);

      // Keep last 16 beats
      if (this.beatHistory.length > 16) {
        this.beatHistory.shift();
      }

      return true;
    }
    return false;
  }

  private calculateBPM(): number {
    if (this.beatHistory.length < 2) return 120;

    const intervals: number[] = [];
    for (let i = 1; i < this.beatHistory.length; i++) {
      intervals.push(this.beatHistory[i] - this.beatHistory[i - 1]);
    }

    const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
    const bpm = 60000 / avgInterval;

    // Clamp to reasonable range
    return Math.max(60, Math.min(200, bpm));
  }

  private getDefaultBeatData(): BeatData {
    return {
      bpm: 120,
      phase: 0,
      energy: 0,
      frequency: { bass: 0, mid: 0, high: 0 },
      onset: false,
      timestamp: performance.now(),
    };
  }

  dispose(): void {
    this.source?.disconnect();
    this.analyser?.disconnect();
    this.audioContext?.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL ORCHESTRATOR
// ═══════════════════════════════════════════════════════════════════════════════

export class ModelOrchestrator {
  private config: OrchestratorConfig;
  private beatDetector: BeatDetector;
  private currentState: BackgroundState;
  private callbacks: Set<OrchestratorCallback> = new Set();
  private updateInterval: number | null = null;
  private transitionStartTime = 0;
  private transitionStartState: BackgroundParameters | null = null;

  constructor(config: Partial<OrchestratorConfig> = {}) {
    this.config = {
      enabled: true,
      updateInterval: 16,  // ~60fps
      beatSensitivity: 0.7,
      coherenceSensitivity: 0.5,
      transitionDuration: 500,
      apiEndpoint: undefined,
      ...config,
    };

    this.beatDetector = new BeatDetector();

    this.currentState = {
      currentStyle: 'holographic',
      transitionProgress: 1,
      targetStyle: null,
      parameters: { ...STYLE_PRESETS.holographic },
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────────

  async start(audioStream?: MediaStream): Promise<void> {
    await this.beatDetector.initialize(audioStream);

    this.updateInterval = window.setInterval(() => {
      this.update();
    }, this.config.updateInterval);
  }

  stop(): void {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }
    this.beatDetector.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // UPDATE LOOP
  // ─────────────────────────────────────────────────────────────────────────────

  private update(): void {
    if (!this.config.enabled) return;

    const beatData = this.beatDetector.analyze();

    // Update parameters based on beat
    this.updateParametersFromBeat(beatData);

    // Handle style transitions
    this.updateTransition();

    // Notify listeners
    this.notifyCallbacks();
  }

  private updateParametersFromBeat(beat: BeatData): void {
    const { parameters } = this.currentState;
    const sensitivity = this.config.beatSensitivity;

    // Modulate intensity on beat
    if (beat.onset) {
      parameters.intensity = Math.min(1, parameters.intensity + 0.2 * sensitivity);
    } else {
      parameters.intensity = Math.max(0.3, parameters.intensity - 0.01);
    }

    // Modulate speed with energy
    parameters.speed = 0.2 + beat.energy * 0.8 * sensitivity;

    // Modulate complexity with frequency distribution
    parameters.complexity = 0.3 + (beat.frequency.high * 0.7) * sensitivity;

    // Color shift on strong bass
    if (beat.frequency.bass > 0.7) {
      const shift = beat.frequency.bass * 0.1 * sensitivity;
      parameters.primaryColor = [
        Math.min(1, parameters.primaryColor[0] + shift),
        parameters.primaryColor[1],
        Math.max(0, parameters.primaryColor[2] - shift),
      ];
    }
  }

  private updateTransition(): void {
    if (!this.currentState.targetStyle || this.currentState.transitionProgress >= 1) {
      return;
    }

    const elapsed = performance.now() - this.transitionStartTime;
    const progress = Math.min(1, elapsed / this.config.transitionDuration);

    // Eased progress
    const easedProgress = this.easeInOutCubic(progress);
    this.currentState.transitionProgress = easedProgress;

    // Interpolate parameters
    if (this.transitionStartState) {
      const targetParams = STYLE_PRESETS[this.currentState.targetStyle];

      this.currentState.parameters = {
        primaryColor: this.lerpColor(
          this.transitionStartState.primaryColor,
          targetParams.primaryColor,
          easedProgress
        ),
        secondaryColor: this.lerpColor(
          this.transitionStartState.secondaryColor,
          targetParams.secondaryColor,
          easedProgress
        ),
        intensity: this.lerp(this.transitionStartState.intensity, targetParams.intensity, easedProgress),
        speed: this.lerp(this.transitionStartState.speed, targetParams.speed, easedProgress),
        complexity: this.lerp(this.transitionStartState.complexity, targetParams.complexity, easedProgress),
        depth: this.lerp(this.transitionStartState.depth, targetParams.depth, easedProgress),
        reactivity: this.lerp(this.transitionStartState.reactivity, targetParams.reactivity, easedProgress),
      };
    }

    // Complete transition
    if (progress >= 1) {
      this.currentState.currentStyle = this.currentState.targetStyle;
      this.currentState.targetStyle = null;
      this.transitionStartState = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STYLE CONTROL
  // ─────────────────────────────────────────────────────────────────────────────

  setStyle(style: BackgroundStyle): void {
    if (style === this.currentState.currentStyle) return;

    this.currentState.targetStyle = style;
    this.currentState.transitionProgress = 0;
    this.transitionStartTime = performance.now();
    this.transitionStartState = { ...this.currentState.parameters };
  }

  getState(): BackgroundState {
    return { ...this.currentState };
  }

  getBeatData(): BeatData {
    return this.beatDetector.analyze();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // API INTEGRATION
  // ─────────────────────────────────────────────────────────────────────────────

  async generateBackground(request: GenerationRequest): Promise<GenerationResult> {
    if (!this.config.apiEndpoint) {
      // Use local preset instead
      this.setStyle(request.style);
      return {
        success: true,
        parameters: { ...STYLE_PRESETS[request.style] },
      };
    }

    try {
      const response = await fetch(this.config.apiEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          prompt: request.prompt,
          style: request.style,
          duration: request.duration,
          beat_sync: request.beatSync,
          parameters: request.parameters,
        }),
      });

      if (!response.ok) {
        throw new Error(`API error: ${response.statusText}`);
      }

      const result = await response.json();

      return {
        success: true,
        textureUrl: result.texture_url,
        parameters: result.parameters,
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BIO-REACTIVE INTEGRATION
  // ─────────────────────────────────────────────────────────────────────────────

  updateBiometrics(data: BiometricData): void {
    const sensitivity = this.config.coherenceSensitivity;
    const { parameters } = this.currentState;

    // High coherence = calmer, more stable visuals
    parameters.speed *= (1 - data.coherence * sensitivity * 0.5);
    parameters.complexity *= (1 - data.coherence * sensitivity * 0.3);

    // Heart rate affects intensity
    const normalizedHR = Math.min(1, Math.max(0, (data.heartRate - 60) / 60));
    parameters.intensity = 0.5 + normalizedHR * 0.5 * sensitivity;

    // Breathing affects depth
    parameters.depth = 0.5 + Math.sin(data.breathPhase * Math.PI * 2) * 0.3 * sensitivity;

    // Color shift based on coherence
    if (data.coherence > 0.7) {
      // Shift toward green/blue (calm)
      parameters.primaryColor = [
        parameters.primaryColor[0] * 0.9,
        Math.min(1, parameters.primaryColor[1] * 1.1),
        Math.min(1, parameters.primaryColor[2] * 1.05),
      ];
    } else if (data.coherence < 0.3) {
      // Shift toward red/orange (alert)
      parameters.primaryColor = [
        Math.min(1, parameters.primaryColor[0] * 1.1),
        parameters.primaryColor[1] * 0.95,
        parameters.primaryColor[2] * 0.9,
      ];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CALLBACKS
  // ─────────────────────────────────────────────────────────────────────────────

  subscribe(callback: OrchestratorCallback): () => void {
    this.callbacks.add(callback);
    return () => this.callbacks.delete(callback);
  }

  private notifyCallbacks(): void {
    const state = this.getState();
    this.callbacks.forEach(cb => cb(state));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────────────────────

  private lerp(a: number, b: number, t: number): number {
    return a + (b - a) * t;
  }

  private lerpColor(
    a: [number, number, number],
    b: [number, number, number],
    t: number
  ): [number, number, number] {
    return [
      this.lerp(a[0], b[0], t),
      this.lerp(a[1], b[1], t),
      this.lerp(a[2], b[2], t),
    ];
  }

  private easeInOutCubic(t: number): number {
    return t < 0.5
      ? 4 * t * t * t
      : 1 - Math.pow(-2 * t + 2, 3) / 2;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SINGLETON INSTANCE
// ═══════════════════════════════════════════════════════════════════════════════

let orchestratorInstance: ModelOrchestrator | null = null;

export function getOrchestrator(config?: Partial<OrchestratorConfig>): ModelOrchestrator {
  if (!orchestratorInstance) {
    orchestratorInstance = new ModelOrchestrator(config);
  }
  return orchestratorInstance;
}

export function disposeOrchestrator(): void {
  if (orchestratorInstance) {
    orchestratorInstance.stop();
    orchestratorInstance = null;
  }
}
