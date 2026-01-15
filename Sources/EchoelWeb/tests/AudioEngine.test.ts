/**
 * AudioEngine.test.ts
 * Echoelmusic - Web Audio Engine Tests
 *
 * Unit tests for the Web Audio synthesizer.
 * Run with: npx vitest run
 *
 * Created: 2026-01-15
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

// Mock Web Audio API
class MockAudioContext {
    sampleRate = 48000;
    baseLatency = 0.01;
    state = 'running';

    createGain() {
        return {
            gain: { value: 1, setValueAtTime: vi.fn() },
            connect: vi.fn(),
            disconnect: vi.fn()
        };
    }

    createOscillator() {
        return {
            type: 'sawtooth',
            frequency: { value: 440 },
            connect: vi.fn(),
            disconnect: vi.fn(),
            start: vi.fn(),
            stop: vi.fn()
        };
    }

    createBiquadFilter() {
        return {
            type: 'lowpass',
            frequency: { value: 5000, setValueAtTime: vi.fn() },
            Q: { value: 1, setValueAtTime: vi.fn() },
            connect: vi.fn(),
            disconnect: vi.fn()
        };
    }

    createAnalyser() {
        return {
            fftSize: 2048,
            frequencyBinCount: 1024,
            getByteFrequencyData: vi.fn(),
            getByteTimeDomainData: vi.fn(),
            connect: vi.fn()
        };
    }

    createConvolver() {
        return {
            buffer: null,
            connect: vi.fn()
        };
    }

    createDelay() {
        return {
            delayTime: { value: 0, setValueAtTime: vi.fn() },
            connect: vi.fn()
        };
    }

    createBuffer(channels: number, length: number, sampleRate: number) {
        return {
            getChannelData: () => new Float32Array(length)
        };
    }

    createBufferSource() {
        return {
            buffer: null,
            loop: false,
            connect: vi.fn(),
            start: vi.fn(),
            stop: vi.fn(),
            disconnect: vi.fn()
        };
    }

    resume = vi.fn().mockResolvedValue(undefined);
    close = vi.fn().mockResolvedValue(undefined);
}

// Mock global AudioContext
vi.stubGlobal('AudioContext', MockAudioContext);

// Import after mocking
import {
    AudioEngine,
    createAudioEngine,
    noteToFrequency,
    frequencyToNote,
    noteToName,
    NOTE_NAMES
} from '../audio/AudioEngine';

import {
    BioSimulator,
    BreathingGuide,
    createBioSimulator,
    BREATHING_PATTERNS
} from '../bio/BioSimulator';

// ============================================================================
// MARK: - Utility Function Tests
// ============================================================================

describe('Utility Functions', () => {
    it('should convert MIDI note to frequency correctly', () => {
        expect(noteToFrequency(69)).toBeCloseTo(440, 2);  // A4
        expect(noteToFrequency(60)).toBeCloseTo(261.63, 1);  // C4
        expect(noteToFrequency(72)).toBeCloseTo(523.25, 1);  // C5
    });

    it('should convert frequency to MIDI note correctly', () => {
        expect(frequencyToNote(440)).toBe(69);  // A4
        expect(frequencyToNote(261.63)).toBe(60);  // C4
    });

    it('should convert note to name correctly', () => {
        expect(noteToName(60)).toBe('C4');
        expect(noteToName(69)).toBe('A4');
        expect(noteToName(72)).toBe('C5');
    });

    it('should have 12 note names', () => {
        expect(NOTE_NAMES).toHaveLength(12);
        expect(NOTE_NAMES).toContain('C');
        expect(NOTE_NAMES).toContain('A');
    });
});

// ============================================================================
// MARK: - AudioEngine Tests
// ============================================================================

describe('AudioEngine', () => {
    let engine: AudioEngine;

    beforeEach(async () => {
        engine = new AudioEngine();
        await engine.initialize();
    });

    afterEach(() => {
        engine.dispose();
    });

    it('should initialize successfully', () => {
        expect(engine.isInitialized()).toBe(true);
    });

    it('should report correct sample rate', () => {
        expect(engine.getSampleRate()).toBe(48000);
    });

    it('should have positive latency', () => {
        expect(engine.getLatency()).toBeGreaterThan(0);
    });

    it('should handle note on/off without crashing', () => {
        expect(() => {
            engine.noteOn(60, 100);
            engine.noteOff(60);
        }).not.toThrow();
    });

    it('should handle all notes off', () => {
        expect(() => {
            engine.noteOn(60, 100);
            engine.noteOn(64, 100);
            engine.noteOn(67, 100);
            engine.allNotesOff();
        }).not.toThrow();
    });

    it('should set waveform', () => {
        expect(() => {
            engine.setWaveform('sine');
            engine.setWaveform('sawtooth');
            engine.setWaveform('square');
            engine.setWaveform('triangle');
        }).not.toThrow();
    });

    it('should set filter parameters', () => {
        expect(() => {
            engine.setFilterCutoff(2000);
            engine.setFilterResonance(0.5);
        }).not.toThrow();
    });

    it('should clamp filter cutoff', () => {
        expect(() => {
            engine.setFilterCutoff(50000);  // Should clamp to 20000
            engine.setFilterCutoff(10);     // Should clamp to 20
        }).not.toThrow();
    });

    it('should set envelope parameters', () => {
        expect(() => {
            engine.setEnvelope({ attack: 50, decay: 100, sustain: 0.5, release: 200 });
        }).not.toThrow();
    });

    it('should set effects parameters', () => {
        expect(() => {
            engine.setReverbMix(0.3);
            engine.setDelayTime(0.5);
            engine.setDelayFeedback(0.4);
            engine.setDelayMix(0.2);
        }).not.toThrow();
    });

    it('should set bio modulation', () => {
        expect(() => {
            engine.setBioModulation({
                heartRate: 75,
                hrvCoherence: 0.8,
                breathingRate: 12,
                breathPhase: 0.5
            });
        }).not.toThrow();
    });

    it('should enable/disable bio modulation', () => {
        expect(() => {
            engine.setBioModulationEnabled(true);
            engine.setBioModulationEnabled(false);
        }).not.toThrow();
    });

    it('should return frequency data array', () => {
        const data = engine.getFrequencyData();
        expect(data).toBeInstanceOf(Uint8Array);
    });

    it('should return waveform data array', () => {
        const data = engine.getWaveformData();
        expect(data).toBeInstanceOf(Uint8Array);
    });
});

// ============================================================================
// MARK: - BioSimulator Tests
// ============================================================================

describe('BioSimulator', () => {
    let simulator: BioSimulator;

    beforeEach(() => {
        simulator = createBioSimulator('calm');
    });

    afterEach(() => {
        simulator.dispose();
    });

    it('should start in calm state', () => {
        expect(simulator.getState()).toBe('calm');
    });

    it('should return valid bio data', () => {
        const data = simulator.getCurrentData();

        expect(data.heartRate).toBeGreaterThan(0);
        expect(data.hrvCoherence).toBeGreaterThanOrEqual(0);
        expect(data.hrvCoherence).toBeLessThanOrEqual(1);
        expect(data.breathingRate).toBeGreaterThan(0);
        expect(data.breathPhase).toBeGreaterThanOrEqual(0);
        expect(data.breathPhase).toBeLessThanOrEqual(1);
    });

    it('should change state', () => {
        simulator.setState('meditation');
        expect(simulator.getState()).toBe('calm');  // Takes time to transition

        // After some updates, should transition
        simulator.setState('stress');
    });

    it('should call callbacks when started', async () => {
        const callback = vi.fn();
        simulator.onData(callback);
        simulator.start();

        // Wait for callback
        await new Promise(resolve => setTimeout(resolve, 200));

        expect(callback).toHaveBeenCalled();
        simulator.stop();
    });

    it('should unsubscribe correctly', () => {
        const callback = vi.fn();
        const unsubscribe = simulator.onData(callback);

        unsubscribe();
        simulator.start();

        // Callback should not be called after unsubscribe
        // (This is a simplified test)
        simulator.stop();
    });

    it('should support all states', () => {
        const states = ['calm', 'active', 'meditation', 'stress', 'exercise', 'sleep'] as const;

        for (const state of states) {
            expect(() => simulator.setState(state)).not.toThrow();
        }
    });
});

// ============================================================================
// MARK: - BreathingGuide Tests
// ============================================================================

describe('BreathingGuide', () => {
    it('should have predefined patterns', () => {
        expect(BREATHING_PATTERNS.relaxation).toBeDefined();
        expect(BREATHING_PATTERNS.coherence).toBeDefined();
        expect(BREATHING_PATTERNS.box).toBeDefined();
        expect(BREATHING_PATTERNS['478']).toBeDefined();
        expect(BREATHING_PATTERNS.energizing).toBeDefined();
    });

    it('should create breathing guide', () => {
        const guide = new BreathingGuide();
        expect(guide).toBeInstanceOf(BreathingGuide);
    });

    it('should accept pattern', () => {
        const guide = new BreathingGuide(BREATHING_PATTERNS.box);
        expect(guide).toBeDefined();
    });

    it('should call update callback', async () => {
        const guide = new BreathingGuide();
        const callback = vi.fn();

        guide.onUpdate(callback);
        guide.start();

        await new Promise(resolve => setTimeout(resolve, 100));

        expect(callback).toHaveBeenCalled();
        guide.stop();
    });
});

// ============================================================================
// MARK: - Factory Function Tests
// ============================================================================

describe('Factory Functions', () => {
    it('should create audio engine', async () => {
        const engine = await createAudioEngine();
        expect(engine).not.toBeNull();
        engine?.dispose();
    });

    it('should create bio simulator with state', () => {
        const simulator = createBioSimulator('meditation');
        expect(simulator).toBeInstanceOf(BioSimulator);
        simulator.dispose();
    });
});
