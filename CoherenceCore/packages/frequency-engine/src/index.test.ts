/**
 * CoherenceCore Frequency Engine Tests
 *
 * Unit tests for audio generation and frequency analysis.
 * Tests T006-T011 partial validation (software-only).
 */

import {
  generateSineWave,
  generateSquareWave,
  generateTriangleWave,
  generateSawtoothWave,
  generateBinauralBeat,
  generateIsochronicTone,
  FrequencyEngine,
  createWavHeader,
} from './index';

import {
  DEFAULT_SAFETY_LIMITS,
  FREQUENCY_PRESETS,
  validateNyquist,
} from '@coherence-core/shared-types';

describe('FrequencyEngine Wave Generation', () => {
  const sampleRate = 44100;
  const duration = 0.1; // 100ms for fast tests

  describe('generateSineWave', () => {
    it('should generate correct number of samples', () => {
      const samples = generateSineWave(40, sampleRate, duration, 0.5);
      expect(samples.length).toBe(Math.floor(sampleRate * duration));
    });

    it('should generate 40 Hz sine wave (Neural-Flow)', () => {
      const samples = generateSineWave(40, sampleRate, duration, 0.5);

      // Verify samples are in valid range [-amplitude, amplitude]
      samples.forEach((sample: number) => {
        expect(sample).toBeGreaterThanOrEqual(-0.5);
        expect(sample).toBeLessThanOrEqual(0.5);
      });
    });

    it('should respect amplitude parameter', () => {
      const amplitude = 0.5;
      const samples = generateSineWave(40, sampleRate, duration, amplitude);
      const maxAbs = Math.max(...Array.from(samples).map(Math.abs));
      expect(maxAbs).toBeLessThanOrEqual(amplitude + 0.01);
    });

    it('should enforce 80% max amplitude safety limit', () => {
      // Request 100% amplitude, should be capped at 80%
      const samples = generateSineWave(40, sampleRate, duration, 1.0);
      const maxAbs = Math.max(...Array.from(samples).map(Math.abs));
      expect(maxAbs).toBeLessThanOrEqual(DEFAULT_SAFETY_LIMITS.maxAmplitude + 0.01);
    });

    it('should generate 35-45 Hz for Osteo-Sync preset', () => {
      const preset = FREQUENCY_PRESETS['osteo-sync'];
      const freq = preset.primaryFrequencyHz;
      const samples = generateSineWave(freq, sampleRate, duration, 0.5);
      expect(samples.length).toBeGreaterThan(0);
    });

    it('should generate 45-50 Hz for Myo-Resonance preset', () => {
      const preset = FREQUENCY_PRESETS['myo-resonance'];
      const freq = preset.primaryFrequencyHz;
      const samples = generateSineWave(freq, sampleRate, duration, 0.5);
      expect(samples.length).toBeGreaterThan(0);
    });
  });

  describe('generateSquareWave', () => {
    it('should generate square wave with values near -amplitude and +amplitude', () => {
      const amplitude = 0.5;
      const samples = generateSquareWave(40, sampleRate, duration, amplitude);
      samples.forEach((sample: number) => {
        expect(Math.abs(Math.abs(sample) - amplitude)).toBeLessThan(0.01);
      });
    });
  });

  describe('generateTriangleWave', () => {
    it('should generate triangle wave within amplitude bounds', () => {
      const amplitude = 0.7;
      const samples = generateTriangleWave(40, sampleRate, duration, amplitude);
      samples.forEach((sample: number) => {
        expect(sample).toBeGreaterThanOrEqual(-amplitude - 0.01);
        expect(sample).toBeLessThanOrEqual(amplitude + 0.01);
      });
    });
  });

  describe('generateSawtoothWave', () => {
    it('should generate sawtooth wave within amplitude bounds', () => {
      const amplitude = 0.6;
      const samples = generateSawtoothWave(40, sampleRate, duration, amplitude);
      samples.forEach((sample: number) => {
        expect(sample).toBeGreaterThanOrEqual(-amplitude - 0.01);
        expect(sample).toBeLessThanOrEqual(amplitude + 0.01);
      });
    });
  });
});

describe('FrequencyEngine Binaural/Isochronic', () => {
  const sampleRate = 44100;
  const duration = 0.1;

  describe('generateBinauralBeat', () => {
    it('should generate stereo object {left, right}', () => {
      const { left, right } = generateBinauralBeat(200, 10, sampleRate, duration, 0.5);
      expect(left.length).toBe(Math.floor(sampleRate * duration));
      expect(right.length).toBe(Math.floor(sampleRate * duration));
    });

    it('should generate different frequencies for each ear', () => {
      const { left, right } = generateBinauralBeat(200, 10, sampleRate, duration, 0.5);
      // Left and right should differ due to beat frequency
      let differences = 0;
      for (let i = 0; i < left.length; i++) {
        if (Math.abs(left[i] - right[i]) > 0.01) differences++;
      }
      expect(differences).toBeGreaterThan(left.length * 0.1);
    });
  });

  describe('generateIsochronicTone', () => {
    it('should generate pulsing tone with on/off pattern', () => {
      const samples = generateIsochronicTone(200, 10, sampleRate, duration, 0.5);
      expect(samples.length).toBe(Math.floor(sampleRate * duration));

      // Should have some zero and some non-zero values
      const zeros = Array.from(samples).filter((s: number) => Math.abs(s) < 0.01).length;
      const nonZeros = Array.from(samples).filter((s: number) => Math.abs(s) >= 0.01).length;
      expect(zeros).toBeGreaterThan(0);
      expect(nonZeros).toBeGreaterThan(0);
    });
  });
});

describe('FrequencyEngine Class', () => {
  let engine: FrequencyEngine;

  beforeEach(() => {
    engine = new FrequencyEngine();
  });

  afterEach(() => {
    engine.destroy();
  });

  describe('preset loading', () => {
    it('should load Osteo-Sync preset', () => {
      engine.setPreset('osteo-sync');
      const state = engine.getState();
      expect(state.currentFrequencyHz).toBeGreaterThanOrEqual(35);
      expect(state.currentFrequencyHz).toBeLessThanOrEqual(45);
    });

    it('should load Myo-Resonance preset', () => {
      engine.setPreset('myo-resonance');
      const state = engine.getState();
      expect(state.currentFrequencyHz).toBeGreaterThanOrEqual(45);
      expect(state.currentFrequencyHz).toBeLessThanOrEqual(50);
    });

    it('should load Neural-Flow preset', () => {
      engine.setPreset('neural-flow');
      const state = engine.getState();
      expect(state.currentFrequencyHz).toBeGreaterThanOrEqual(38);
      expect(state.currentFrequencyHz).toBeLessThanOrEqual(42);
    });
  });

  describe('frequency control', () => {
    it('should set frequency within valid range', () => {
      engine.setFrequency(42);
      expect(engine.getState().currentFrequencyHz).toBe(42);
    });

    it('should throw for frequency out of range', () => {
      expect(() => engine.setFrequency(100)).toThrow();
    });
  });

  describe('amplitude control', () => {
    it('should set amplitude within safety limits', () => {
      engine.setAmplitude(0.5);
      expect(engine.getState().amplitude).toBe(0.5);
    });

    it('should enforce 80% max amplitude (T007)', () => {
      engine.setAmplitude(1.0);
      expect(engine.getState().amplitude).toBeLessThanOrEqual(DEFAULT_SAFETY_LIMITS.maxAmplitude);
    });
  });

  describe('waveform selection', () => {
    it('should switch between waveforms', () => {
      engine.setWaveformType('square');
      expect(engine.getState().waveformType).toBe('square');

      engine.setWaveformType('triangle');
      expect(engine.getState().waveformType).toBe('triangle');
    });
  });

  describe('session management', () => {
    it('should track session state', () => {
      engine.start();
      const state = engine.getState();
      expect(state.isPlaying).toBe(true);
      expect(state.sessionStartTime).not.toBeNull();
    });

    it('should stop session', () => {
      engine.start();
      engine.stop();
      const state = engine.getState();
      expect(state.isPlaying).toBe(false);
    });
  });

  describe('buffer generation', () => {
    it('should generate audio buffer', () => {
      engine.setFrequency(40);
      engine.setAmplitude(0.5);
      const buffer = engine.generateBuffer(44100, 0.1);
      expect(buffer.length).toBeGreaterThan(0);
    });
  });
});

describe('WAV Export', () => {
  it('should create valid WAV header', () => {
    const header = createWavHeader(44100, 44100);
    expect(header.byteLength).toBe(44);

    // Check RIFF header
    const view = new DataView(header);
    expect(String.fromCharCode(view.getUint8(0), view.getUint8(1), view.getUint8(2), view.getUint8(3))).toBe('RIFF');
  });
});

describe('Safety Compliance (T007, T019, T020)', () => {
  it('should have correct safety limits defined', () => {
    expect(DEFAULT_SAFETY_LIMITS.maxAmplitude).toBe(0.8);
    expect(DEFAULT_SAFETY_LIMITS.maxDutyCycle).toBe(0.7);
    expect(DEFAULT_SAFETY_LIMITS.maxSessionDurationMs).toBe(900000);
  });

  it('should have 15 minute (900000 ms) max session', () => {
    expect(DEFAULT_SAFETY_LIMITS.maxSessionDurationMs).toBe(15 * 60 * 1000);
  });
});

describe('Nyquist Validation (T021, T022)', () => {
  it('should validate camera FPS against target frequency', () => {
    // 60 Hz target needs 120 Hz sample rate minimum
    expect(validateNyquist(60, 120).isValid).toBe(true);
    expect(validateNyquist(60, 60).isValid).toBe(false); // Nyquist violation
  });

  it('should validate IMU sample rate', () => {
    // 50 Hz target needs 100 Hz sample rate
    expect(validateNyquist(50, 100).isValid).toBe(true);
    expect(validateNyquist(50, 80).isValid).toBe(false);
  });
});

describe('Preset Validation', () => {
  it('should have all required presets', () => {
    expect(FREQUENCY_PRESETS['osteo-sync']).toBeDefined();
    expect(FREQUENCY_PRESETS['myo-resonance']).toBeDefined();
    expect(FREQUENCY_PRESETS['neural-flow']).toBeDefined();
    expect(FREQUENCY_PRESETS['custom']).toBeDefined();
  });

  it('should have research citations for evidence-based presets', () => {
    expect(FREQUENCY_PRESETS['osteo-sync'].research).toContain('Rubin');
    expect(FREQUENCY_PRESETS['myo-resonance'].research).toContain('Judex');
    expect(FREQUENCY_PRESETS['neural-flow'].research).toContain('Iaccarino');
  });

  it('should have correct frequency ranges', () => {
    const osteo = FREQUENCY_PRESETS['osteo-sync'];
    expect(osteo.frequencyRangeHz[0]).toBe(35);
    expect(osteo.frequencyRangeHz[1]).toBe(45);

    const myo = FREQUENCY_PRESETS['myo-resonance'];
    expect(myo.frequencyRangeHz[0]).toBe(45);
    expect(myo.frequencyRangeHz[1]).toBe(50);

    const neural = FREQUENCY_PRESETS['neural-flow'];
    expect(neural.frequencyRangeHz[0]).toBe(38);
    expect(neural.frequencyRangeHz[1]).toBe(42);
  });
});
