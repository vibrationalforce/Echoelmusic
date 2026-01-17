/**
 * BioSimulator.ts
 * Echoelmusic - Simulated Biometric Data for Web
 *
 * Provides realistic simulated biometric data for web demo purposes.
 * Actual biometric integration requires native apps (iOS HealthKit, Android Health Connect).
 *
 * Features:
 * - Realistic heart rate simulation with natural variability
 * - HRV coherence calculation (SDNN-based)
 * - Breathing pattern detection simulation
 * - Customizable states (calm, active, meditation)
 *
 * Created: 2026-01-15
 */

// ============================================================================
// MARK: - Types
// ============================================================================

export interface BiometricData {
    heartRate: number;          // BPM (40-200)
    hrvCoherence: number;       // 0-1 coherence ratio
    hrvSDNN: number;            // SDNN in ms
    breathingRate: number;      // breaths per minute
    breathPhase: number;        // 0-1 (inhale to exhale)
    timestamp: number;          // Unix timestamp
}

export type BiometricState =
    | 'calm'          // Resting state (HR ~60-70)
    | 'active'        // Light activity (HR ~80-100)
    | 'meditation'    // Deep relaxation (HR ~55-65, high coherence)
    | 'stress'        // Elevated state (HR ~90-110, low coherence)
    | 'exercise'      // High activity (HR ~120-160)
    | 'sleep';        // Deep rest (HR ~50-60)

export interface BioSimulatorConfig {
    updateInterval: number;     // ms (default: 100)
    initialState: BiometricState;
    transitionSpeed: number;    // 0-1 (how fast to transition between states)
}

export type BiometricCallback = (data: BiometricData) => void;

// ============================================================================
// MARK: - State Parameters
// ============================================================================

interface StateParams {
    hrMin: number;
    hrMax: number;
    hrVariability: number;      // Beat-to-beat variability
    baseCoherence: number;      // Target coherence level
    breathingRate: number;      // breaths/min
    sdnnBase: number;           // Base SDNN in ms
}

const STATE_PARAMS: Record<BiometricState, StateParams> = {
    calm: {
        hrMin: 60,
        hrMax: 72,
        hrVariability: 5,
        baseCoherence: 0.6,
        breathingRate: 12,
        sdnnBase: 50
    },
    active: {
        hrMin: 80,
        hrMax: 100,
        hrVariability: 8,
        baseCoherence: 0.4,
        breathingRate: 16,
        sdnnBase: 40
    },
    meditation: {
        hrMin: 55,
        hrMax: 65,
        hrVariability: 10,
        baseCoherence: 0.85,
        breathingRate: 6,        // Slow breathing for coherence
        sdnnBase: 70
    },
    stress: {
        hrMin: 90,
        hrMax: 110,
        hrVariability: 3,
        baseCoherence: 0.2,
        breathingRate: 18,
        sdnnBase: 25
    },
    exercise: {
        hrMin: 120,
        hrMax: 160,
        hrVariability: 4,
        baseCoherence: 0.3,
        breathingRate: 24,
        sdnnBase: 20
    },
    sleep: {
        hrMin: 50,
        hrMax: 60,
        hrVariability: 12,
        baseCoherence: 0.7,
        breathingRate: 8,
        sdnnBase: 60
    }
};

// ============================================================================
// MARK: - Bio Simulator
// ============================================================================

export class BioSimulator {
    private config: BioSimulatorConfig;
    private currentState: BiometricState;
    private targetState: BiometricState;
    private currentParams: StateParams;

    private heartRate: number = 70;
    private hrvCoherence: number = 0.5;
    private hrvSDNN: number = 50;
    private breathPhase: number = 0;
    private breathingRate: number = 12;

    private callbacks: BiometricCallback[] = [];
    private intervalId: ReturnType<typeof setInterval> | null = null;
    private running: boolean = false;

    private time: number = 0;
    private rrIntervals: number[] = [];

    constructor(config: Partial<BioSimulatorConfig> = {}) {
        this.config = {
            updateInterval: 100,
            initialState: 'calm',
            transitionSpeed: 0.1,
            ...config
        };

        this.currentState = this.config.initialState;
        this.targetState = this.config.initialState;
        this.currentParams = { ...STATE_PARAMS[this.currentState] };

        this.heartRate = (this.currentParams.hrMin + this.currentParams.hrMax) / 2;
    }

    // MARK: - Lifecycle

    start(): void {
        if (this.running) return;

        this.running = true;
        this.intervalId = setInterval(() => {
            this.update();
            this.notifyCallbacks();
        }, this.config.updateInterval);

        console.log('[BioSimulator] Started');
    }

    stop(): void {
        if (!this.running) return;

        this.running = false;
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }

        console.log('[BioSimulator] Stopped');
    }

    isRunning(): boolean {
        return this.running;
    }

    // MARK: - State Control

    setState(state: BiometricState): void {
        this.targetState = state;
        console.log(`[BioSimulator] Transitioning to: ${state}`);
    }

    getState(): BiometricState {
        return this.currentState;
    }

    // MARK: - Callbacks

    onData(callback: BiometricCallback): () => void {
        this.callbacks.push(callback);

        // Return unsubscribe function
        return () => {
            const index = this.callbacks.indexOf(callback);
            if (index !== -1) {
                this.callbacks.splice(index, 1);
            }
        };
    }

    private notifyCallbacks(): void {
        const data = this.getCurrentData();
        this.callbacks.forEach(cb => cb(data));
    }

    // MARK: - Data Access

    getCurrentData(): BiometricData {
        return {
            heartRate: Math.round(this.heartRate),
            hrvCoherence: Math.round(this.hrvCoherence * 100) / 100,
            hrvSDNN: Math.round(this.hrvSDNN),
            breathingRate: Math.round(this.breathingRate * 10) / 10,
            breathPhase: Math.round(this.breathPhase * 100) / 100,
            timestamp: Date.now()
        };
    }

    // MARK: - Update Logic

    private update(): void {
        const dt = this.config.updateInterval / 1000;
        this.time += dt;

        // Smooth state transition
        this.transitionParams();

        // Update heart rate with natural variability
        this.updateHeartRate(dt);

        // Update HRV metrics
        this.updateHRV();

        // Update breathing
        this.updateBreathing(dt);
    }

    private transitionParams(): void {
        const targetParams = STATE_PARAMS[this.targetState];
        const speed = this.config.transitionSpeed;

        this.currentParams.hrMin = this.lerp(this.currentParams.hrMin, targetParams.hrMin, speed);
        this.currentParams.hrMax = this.lerp(this.currentParams.hrMax, targetParams.hrMax, speed);
        this.currentParams.hrVariability = this.lerp(this.currentParams.hrVariability, targetParams.hrVariability, speed);
        this.currentParams.baseCoherence = this.lerp(this.currentParams.baseCoherence, targetParams.baseCoherence, speed);
        this.currentParams.breathingRate = this.lerp(this.currentParams.breathingRate, targetParams.breathingRate, speed);
        this.currentParams.sdnnBase = this.lerp(this.currentParams.sdnnBase, targetParams.sdnnBase, speed);

        // Update current state if close enough
        if (Math.abs(this.currentParams.hrMin - targetParams.hrMin) < 1) {
            this.currentState = this.targetState;
        }
    }

    private updateHeartRate(dt: number): void {
        const params = this.currentParams;
        const targetHR = (params.hrMin + params.hrMax) / 2;

        // Natural fluctuation (respiratory sinus arrhythmia)
        const rsaEffect = Math.sin(this.breathPhase * Math.PI * 2) * params.hrVariability;

        // Random walk component
        const randomWalk = (Math.random() - 0.5) * 2 * dt * 5;

        // Smoothly move toward target
        this.heartRate += (targetHR - this.heartRate) * 0.1 + rsaEffect * dt * 10 + randomWalk;

        // Clamp to valid range
        this.heartRate = Math.max(params.hrMin, Math.min(params.hrMax, this.heartRate));

        // Record RR interval
        const rrInterval = 60000 / this.heartRate;  // ms between beats
        this.rrIntervals.push(rrInterval + (Math.random() - 0.5) * params.hrVariability * 2);

        // Keep last 60 intervals (~1 minute of data)
        if (this.rrIntervals.length > 60) {
            this.rrIntervals.shift();
        }
    }

    private updateHRV(): void {
        const params = this.currentParams;

        if (this.rrIntervals.length < 10) {
            this.hrvSDNN = params.sdnnBase;
            this.hrvCoherence = params.baseCoherence;
            return;
        }

        // Calculate SDNN (Standard Deviation of NN intervals)
        const mean = this.rrIntervals.reduce((a, b) => a + b, 0) / this.rrIntervals.length;
        const variance = this.rrIntervals.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / this.rrIntervals.length;
        this.hrvSDNN = Math.sqrt(variance);

        // Calculate coherence (simplified - based on how regular the pattern is)
        // In real HeartMath coherence, this is based on spectral analysis of HRV
        const targetCoherence = params.baseCoherence;
        const coherenceNoise = (Math.random() - 0.5) * 0.1;
        this.hrvCoherence = Math.max(0, Math.min(1, targetCoherence + coherenceNoise));
    }

    private updateBreathing(dt: number): void {
        // Breathing rate follows target
        this.breathingRate += (this.currentParams.breathingRate - this.breathingRate) * 0.1;

        // Update breath phase (0 = start of inhale, 0.5 = start of exhale, 1 = end of exhale)
        const breathPeriod = 60 / this.breathingRate;  // seconds per breath
        const phaseIncrement = dt / breathPeriod;

        this.breathPhase += phaseIncrement;
        if (this.breathPhase >= 1) {
            this.breathPhase -= 1;
        }
    }

    private lerp(a: number, b: number, t: number): number {
        return a + (b - a) * t;
    }

    // MARK: - Cleanup

    dispose(): void {
        this.stop();
        this.callbacks = [];
        console.log('[BioSimulator] Disposed');
    }
}

// ============================================================================
// MARK: - Breathing Guide
// ============================================================================

export interface BreathingPattern {
    name: string;
    inhale: number;     // seconds
    hold1: number;      // hold after inhale
    exhale: number;     // seconds
    hold2: number;      // hold after exhale
}

export const BREATHING_PATTERNS: Record<string, BreathingPattern> = {
    relaxation: {
        name: 'Relaxation',
        inhale: 4,
        hold1: 0,
        exhale: 6,
        hold2: 0
    },
    coherence: {
        name: 'Coherence (5-5)',
        inhale: 5,
        hold1: 0,
        exhale: 5,
        hold2: 0
    },
    box: {
        name: 'Box Breathing',
        inhale: 4,
        hold1: 4,
        exhale: 4,
        hold2: 4
    },
    '478': {
        name: '4-7-8 Sleep',
        inhale: 4,
        hold1: 7,
        exhale: 8,
        hold2: 0
    },
    energizing: {
        name: 'Energizing',
        inhale: 4,
        hold1: 0,
        exhale: 2,
        hold2: 0
    }
};

export class BreathingGuide {
    private pattern: BreathingPattern;
    private phase: 'inhale' | 'hold1' | 'exhale' | 'hold2' = 'inhale';
    private phaseTime: number = 0;
    private callback: ((phase: string, progress: number) => void) | null = null;
    private intervalId: ReturnType<typeof setInterval> | null = null;

    constructor(pattern: BreathingPattern = BREATHING_PATTERNS.coherence) {
        this.pattern = pattern;
    }

    setPattern(pattern: BreathingPattern): void {
        this.pattern = pattern;
    }

    onUpdate(callback: (phase: string, progress: number) => void): void {
        this.callback = callback;
    }

    start(): void {
        this.phase = 'inhale';
        this.phaseTime = 0;

        this.intervalId = setInterval(() => {
            this.update(0.05);
        }, 50);
    }

    stop(): void {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
    }

    private update(dt: number): void {
        this.phaseTime += dt;

        const phaseDuration = this.getPhaseDuration();

        if (this.phaseTime >= phaseDuration) {
            this.phaseTime = 0;
            this.advancePhase();
        }

        const progress = phaseDuration > 0 ? this.phaseTime / phaseDuration : 0;

        if (this.callback) {
            this.callback(this.phase, progress);
        }
    }

    private getPhaseDuration(): number {
        switch (this.phase) {
            case 'inhale': return this.pattern.inhale;
            case 'hold1': return this.pattern.hold1;
            case 'exhale': return this.pattern.exhale;
            case 'hold2': return this.pattern.hold2;
        }
    }

    private advancePhase(): void {
        switch (this.phase) {
            case 'inhale':
                this.phase = this.pattern.hold1 > 0 ? 'hold1' : 'exhale';
                break;
            case 'hold1':
                this.phase = 'exhale';
                break;
            case 'exhale':
                this.phase = this.pattern.hold2 > 0 ? 'hold2' : 'inhale';
                break;
            case 'hold2':
                this.phase = 'inhale';
                break;
        }
    }
}

// ============================================================================
// MARK: - Factory Functions
// ============================================================================

export function createBioSimulator(state: BiometricState = 'calm'): BioSimulator {
    return new BioSimulator({ initialState: state });
}

export function createBreathingGuide(patternName: keyof typeof BREATHING_PATTERNS = 'coherence'): BreathingGuide {
    return new BreathingGuide(BREATHING_PATTERNS[patternName]);
}
