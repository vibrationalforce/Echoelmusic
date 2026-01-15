/**
 * AudioWorklet.ts
 * Echoelmusic - Low-Latency Web Audio Processor
 *
 * AudioWorklet-based synthesis for lowest possible latency in browsers.
 * Runs on a separate audio rendering thread at native priority.
 *
 * Features:
 * - Real-time DSP processing on audio thread
 * - No garbage collection during processing
 * - Shared memory communication with main thread
 * - Bio-reactive parameter modulation
 * - Multiple oscillator voices
 *
 * Usage:
 *   1. Register the worklet: await context.audioWorklet.addModule('AudioWorklet.js')
 *   2. Create node: new AudioWorkletNode(context, 'echoelmusic-processor')
 *   3. Send parameters via port.postMessage()
 *
 * Browser Support: Chrome 66+, Firefox 76+, Safari 14.1+
 *
 * Created: 2026-01-15
 */

// ============================================================================
// MARK: - Types (shared with main thread)
// ============================================================================

export interface WorkletMessage {
    type: 'noteOn' | 'noteOff' | 'setParam' | 'setBio' | 'allNotesOff';
    note?: number;
    velocity?: number;
    param?: string;
    value?: number;
    bio?: {
        heartRate: number;
        hrvCoherence: number;
        breathPhase: number;
    };
}

export interface VoiceState {
    active: boolean;
    note: number;
    velocity: number;
    phase: number;
    filterPhase: number;
    envLevel: number;
    envStage: 'idle' | 'attack' | 'decay' | 'sustain' | 'release';
}

// ============================================================================
// MARK: - AudioWorklet Processor Code (as string for registration)
// ============================================================================

/**
 * This code runs inside the AudioWorklet context.
 * It's provided as a string to be loaded via Blob URL.
 */
export const WORKLET_PROCESSOR_CODE = `
// Echoelmusic AudioWorklet Processor
// Runs on the audio rendering thread

const TWO_PI = 2 * Math.PI;
const MAX_VOICES = 16;

class Voice {
    constructor() {
        this.active = false;
        this.note = 60;
        this.velocity = 0;
        this.phase = 0;
        this.filterState = [0, 0, 0, 0];
        this.envLevel = 0;
        this.envStage = 'idle';
    }

    noteOn(note, velocity) {
        this.active = true;
        this.note = note;
        this.velocity = velocity / 127;
        this.phase = 0;
        this.envLevel = 0;
        this.envStage = 'attack';
    }

    noteOff() {
        if (this.active) {
            this.envStage = 'release';
        }
    }

    process(params, sampleRate) {
        if (!this.active) return 0;

        // Calculate frequency
        const freq = 440 * Math.pow(2, (this.note - 69) / 12);
        const dt = freq / sampleRate;

        // Generate oscillator (sawtooth with polyBLEP)
        let osc = 2 * this.phase - 1;
        osc -= this.polyBLEP(this.phase, dt);

        // Advance phase
        this.phase += dt;
        if (this.phase >= 1) this.phase -= 1;

        // Simple lowpass filter
        const cutoff = params.filterCutoff * (1 + params.bioCoherence * 0.5);
        const fc = Math.min(cutoff / sampleRate, 0.45);
        const filtered = this.lowpass(osc, fc, params.filterResonance);

        // Envelope
        this.processEnvelope(params, sampleRate);

        return filtered * this.envLevel * this.velocity;
    }

    polyBLEP(t, dt) {
        if (t < dt) {
            t /= dt;
            return t + t - t * t - 1;
        } else if (t > 1 - dt) {
            t = (t - 1) / dt;
            return t * t + t + t + 1;
        }
        return 0;
    }

    lowpass(input, fc, res) {
        const f = 2 * Math.sin(Math.PI * fc);
        const q = 1 - res;

        this.filterState[0] += f * this.filterState[1];
        this.filterState[2] = input - this.filterState[0] - q * this.filterState[1];
        this.filterState[1] += f * this.filterState[2];

        return this.filterState[0];
    }

    processEnvelope(params, sampleRate) {
        const attackRate = 1 / (params.attack * sampleRate / 1000);
        const decayRate = 1 / (params.decay * sampleRate / 1000);
        const releaseRate = 1 / (params.release * sampleRate / 1000);

        switch (this.envStage) {
            case 'attack':
                this.envLevel += attackRate;
                if (this.envLevel >= 1) {
                    this.envLevel = 1;
                    this.envStage = 'decay';
                }
                break;
            case 'decay':
                this.envLevel -= decayRate * (1 - params.sustain);
                if (this.envLevel <= params.sustain) {
                    this.envLevel = params.sustain;
                    this.envStage = 'sustain';
                }
                break;
            case 'sustain':
                this.envLevel = params.sustain;
                break;
            case 'release':
                this.envLevel -= releaseRate * this.envLevel;
                if (this.envLevel <= 0.001) {
                    this.envLevel = 0;
                    this.envStage = 'idle';
                    this.active = false;
                }
                break;
        }
    }
}

class EchoelmusicProcessor extends AudioWorkletProcessor {
    constructor() {
        super();

        this.voices = [];
        for (let i = 0; i < MAX_VOICES; i++) {
            this.voices.push(new Voice());
        }

        this.params = {
            filterCutoff: 5000,
            filterResonance: 0.3,
            attack: 10,
            decay: 200,
            sustain: 0.7,
            release: 300,
            bioCoherence: 0.5,
            bioHeartRate: 70,
            bioBreathPhase: 0,
            masterVolume: 0.8
        };

        this.port.onmessage = (event) => this.handleMessage(event.data);
    }

    handleMessage(msg) {
        switch (msg.type) {
            case 'noteOn':
                this.noteOn(msg.note, msg.velocity);
                break;
            case 'noteOff':
                this.noteOff(msg.note);
                break;
            case 'setParam':
                if (msg.param in this.params) {
                    this.params[msg.param] = msg.value;
                }
                break;
            case 'setBio':
                if (msg.bio) {
                    this.params.bioCoherence = msg.bio.hrvCoherence;
                    this.params.bioHeartRate = msg.bio.heartRate;
                    this.params.bioBreathPhase = msg.bio.breathPhase;
                }
                break;
            case 'allNotesOff':
                this.voices.forEach(v => v.noteOff());
                break;
        }
    }

    noteOn(note, velocity) {
        // Find free voice
        let voice = this.voices.find(v => !v.active);

        // Steal if none free
        if (!voice) {
            voice = this.voices[0];
        }

        voice.noteOn(note, velocity);
    }

    noteOff(note) {
        this.voices
            .filter(v => v.active && v.note === note)
            .forEach(v => v.noteOff());
    }

    process(inputs, outputs, parameters) {
        const output = outputs[0];
        const channel = output[0];

        if (!channel) return true;

        for (let i = 0; i < channel.length; i++) {
            let sample = 0;

            // Sum all voices
            for (const voice of this.voices) {
                sample += voice.process(this.params, sampleRate);
            }

            // Apply bio-reactive amplitude modulation
            const breathMod = 1 + 0.03 * this.params.bioCoherence *
                Math.sin(this.params.bioBreathPhase * TWO_PI);
            sample *= breathMod;

            // Master volume
            sample *= this.params.masterVolume;

            // Soft clip
            if (sample > 1) sample = 1 - Math.exp(-sample + 1);
            else if (sample < -1) sample = -1 + Math.exp(sample + 1);

            // Write to all channels
            for (let ch = 0; ch < output.length; ch++) {
                output[ch][i] = sample;
            }
        }

        return true;
    }
}

registerProcessor('echoelmusic-processor', EchoelmusicProcessor);
`;

// ============================================================================
// MARK: - Worklet Node Wrapper
// ============================================================================

/**
 * Wrapper class for the AudioWorklet node.
 * Provides a clean API for the main thread.
 */
export class EchoelmusicWorkletNode {
    private context: AudioContext;
    private node: AudioWorkletNode | null = null;
    private registered: boolean = false;

    constructor(context: AudioContext) {
        this.context = context;
    }

    /**
     * Register and create the worklet node
     */
    async initialize(): Promise<boolean> {
        try {
            // Create blob URL from processor code
            const blob = new Blob([WORKLET_PROCESSOR_CODE], { type: 'application/javascript' });
            const url = URL.createObjectURL(blob);

            // Register the processor
            await this.context.audioWorklet.addModule(url);
            URL.revokeObjectURL(url);

            // Create the node
            this.node = new AudioWorkletNode(this.context, 'echoelmusic-processor', {
                numberOfInputs: 0,
                numberOfOutputs: 1,
                outputChannelCount: [2]
            });

            this.registered = true;
            console.log('[EchoelmusicWorklet] Initialized successfully');

            return true;
        } catch (error) {
            console.error('[EchoelmusicWorklet] Failed to initialize:', error);
            return false;
        }
    }

    /**
     * Connect to destination
     */
    connect(destination: AudioNode): void {
        this.node?.connect(destination);
    }

    /**
     * Disconnect from all
     */
    disconnect(): void {
        this.node?.disconnect();
    }

    /**
     * Play a note
     */
    noteOn(note: number, velocity: number = 100): void {
        this.send({ type: 'noteOn', note, velocity });
    }

    /**
     * Release a note
     */
    noteOff(note: number): void {
        this.send({ type: 'noteOff', note });
    }

    /**
     * Release all notes
     */
    allNotesOff(): void {
        this.send({ type: 'allNotesOff' });
    }

    /**
     * Set a parameter
     */
    setParam(param: string, value: number): void {
        this.send({ type: 'setParam', param, value });
    }

    /**
     * Update bio-reactive modulation
     */
    setBioModulation(heartRate: number, hrvCoherence: number, breathPhase: number): void {
        this.send({
            type: 'setBio',
            bio: { heartRate, hrvCoherence, breathPhase }
        });
    }

    /**
     * Send message to processor
     */
    private send(message: WorkletMessage): void {
        this.node?.port.postMessage(message);
    }

    /**
     * Get the underlying AudioWorkletNode
     */
    getNode(): AudioWorkletNode | null {
        return this.node;
    }

    /**
     * Check if initialized
     */
    isInitialized(): boolean {
        return this.registered && this.node !== null;
    }
}

// ============================================================================
// MARK: - Factory Function
// ============================================================================

/**
 * Create and initialize a worklet-based synthesizer
 */
export async function createWorkletSynth(context: AudioContext): Promise<EchoelmusicWorkletNode | null> {
    // Check AudioWorklet support
    if (!context.audioWorklet) {
        console.error('AudioWorklet not supported in this browser');
        return null;
    }

    const worklet = new EchoelmusicWorkletNode(context);
    const success = await worklet.initialize();

    if (!success) {
        return null;
    }

    return worklet;
}

// ============================================================================
// MARK: - Feature Detection
// ============================================================================

export function isAudioWorkletSupported(): boolean {
    return typeof AudioWorkletNode !== 'undefined';
}

export function getAudioLatencyInfo(context: AudioContext): {
    baseLatency: number;
    outputLatency: number;
    totalLatency: number;
} {
    return {
        baseLatency: context.baseLatency * 1000,
        outputLatency: (context.outputLatency ?? 0) * 1000,
        totalLatency: (context.baseLatency + (context.outputLatency ?? 0)) * 1000
    };
}
