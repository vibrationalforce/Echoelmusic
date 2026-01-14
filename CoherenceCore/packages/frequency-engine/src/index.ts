/**
 * CoherenceCore Frequency Engine
 *
 * Generates precise sine waves for vibroacoustic therapy (VAT).
 * Cross-platform support for mobile (expo-av) and desktop (cpal).
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import {
  AudioConfig,
  DEFAULT_AUDIO_CONFIG,
  DEFAULT_SAFETY_LIMITS,
  SafetyLimits,
  FREQUENCY_PRESETS,
  FrequencyPresetId,
  validateNyquist,
} from '@coherence-core/shared-types';

// ============================================================================
// SINE WAVE GENERATION
// ============================================================================

/**
 * Generate a sine wave buffer at the specified frequency
 */
export function generateSineWave(
  frequencyHz: number,
  sampleRate: number,
  durationSeconds: number,
  amplitude: number = 0.5
): Float32Array {
  const numSamples = Math.floor(sampleRate * durationSeconds);
  const buffer = new Float32Array(numSamples);
  const omega = 2 * Math.PI * frequencyHz;

  // Apply safety limit to amplitude
  const safeAmplitude = Math.min(amplitude, DEFAULT_SAFETY_LIMITS.maxAmplitude);

  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    buffer[i] = safeAmplitude * Math.sin(omega * t);
  }

  return buffer;
}

/**
 * Generate a square wave buffer
 */
export function generateSquareWave(
  frequencyHz: number,
  sampleRate: number,
  durationSeconds: number,
  amplitude: number = 0.5
): Float32Array {
  const numSamples = Math.floor(sampleRate * durationSeconds);
  const buffer = new Float32Array(numSamples);
  const period = sampleRate / frequencyHz;

  const safeAmplitude = Math.min(amplitude, DEFAULT_SAFETY_LIMITS.maxAmplitude);

  for (let i = 0; i < numSamples; i++) {
    const phase = (i % period) / period;
    buffer[i] = phase < 0.5 ? safeAmplitude : -safeAmplitude;
  }

  return buffer;
}

/**
 * Generate a triangle wave buffer
 */
export function generateTriangleWave(
  frequencyHz: number,
  sampleRate: number,
  durationSeconds: number,
  amplitude: number = 0.5
): Float32Array {
  const numSamples = Math.floor(sampleRate * durationSeconds);
  const buffer = new Float32Array(numSamples);
  const period = sampleRate / frequencyHz;

  const safeAmplitude = Math.min(amplitude, DEFAULT_SAFETY_LIMITS.maxAmplitude);

  for (let i = 0; i < numSamples; i++) {
    const phase = (i % period) / period;
    // Triangle wave: goes from -1 to 1 in first half, 1 to -1 in second half
    buffer[i] = safeAmplitude * (phase < 0.5
      ? 4 * phase - 1
      : 3 - 4 * phase);
  }

  return buffer;
}

/**
 * Generate a sawtooth wave buffer
 */
export function generateSawtoothWave(
  frequencyHz: number,
  sampleRate: number,
  durationSeconds: number,
  amplitude: number = 0.5
): Float32Array {
  const numSamples = Math.floor(sampleRate * durationSeconds);
  const buffer = new Float32Array(numSamples);
  const period = sampleRate / frequencyHz;

  const safeAmplitude = Math.min(amplitude, DEFAULT_SAFETY_LIMITS.maxAmplitude);

  for (let i = 0; i < numSamples; i++) {
    const phase = (i % period) / period;
    buffer[i] = safeAmplitude * (2 * phase - 1);
  }

  return buffer;
}

// ============================================================================
// WAVEFORM GENERATION
// ============================================================================

export type WaveformType = 'sine' | 'square' | 'triangle' | 'sawtooth';

/**
 * Generate waveform buffer based on type
 */
export function generateWaveform(
  type: WaveformType,
  frequencyHz: number,
  sampleRate: number,
  durationSeconds: number,
  amplitude: number = 0.5
): Float32Array {
  switch (type) {
    case 'sine':
      return generateSineWave(frequencyHz, sampleRate, durationSeconds, amplitude);
    case 'square':
      return generateSquareWave(frequencyHz, sampleRate, durationSeconds, amplitude);
    case 'triangle':
      return generateTriangleWave(frequencyHz, sampleRate, durationSeconds, amplitude);
    case 'sawtooth':
      return generateSawtoothWave(frequencyHz, sampleRate, durationSeconds, amplitude);
    default:
      return generateSineWave(frequencyHz, sampleRate, durationSeconds, amplitude);
  }
}

// ============================================================================
// BINAURAL BEATS
// ============================================================================

/**
 * Generate binaural beat (stereo: left and right frequencies differ)
 */
export function generateBinauralBeat(
  baseFrequencyHz: number,
  beatFrequencyHz: number,
  sampleRate: number,
  durationSeconds: number,
  amplitude: number = 0.5
): { left: Float32Array; right: Float32Array } {
  const numSamples = Math.floor(sampleRate * durationSeconds);
  const left = new Float32Array(numSamples);
  const right = new Float32Array(numSamples);

  const safeAmplitude = Math.min(amplitude, DEFAULT_SAFETY_LIMITS.maxAmplitude);

  const leftFreq = baseFrequencyHz - beatFrequencyHz / 2;
  const rightFreq = baseFrequencyHz + beatFrequencyHz / 2;

  const omegaLeft = 2 * Math.PI * leftFreq;
  const omegaRight = 2 * Math.PI * rightFreq;

  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    left[i] = safeAmplitude * Math.sin(omegaLeft * t);
    right[i] = safeAmplitude * Math.sin(omegaRight * t);
  }

  return { left, right };
}

/**
 * Generate isochronic tones (amplitude-modulated at beat frequency)
 */
export function generateIsochronicTone(
  carrierFrequencyHz: number,
  modulationFrequencyHz: number,
  sampleRate: number,
  durationSeconds: number,
  amplitude: number = 0.5
): Float32Array {
  const numSamples = Math.floor(sampleRate * durationSeconds);
  const buffer = new Float32Array(numSamples);

  const safeAmplitude = Math.min(amplitude, DEFAULT_SAFETY_LIMITS.maxAmplitude);

  const carrierOmega = 2 * Math.PI * carrierFrequencyHz;
  const modulationOmega = 2 * Math.PI * modulationFrequencyHz;

  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    // Isochronic: carrier modulated by half-rectified sine
    const modulation = Math.max(0, Math.sin(modulationOmega * t));
    buffer[i] = safeAmplitude * modulation * Math.sin(carrierOmega * t);
  }

  return buffer;
}

// ============================================================================
// FREQUENCY ENGINE CLASS
// ============================================================================

export interface FrequencyEngineState {
  isPlaying: boolean;
  currentFrequencyHz: number;
  currentPreset: FrequencyPresetId;
  sessionStartTime: number | null;
  sessionDurationMs: number;
  amplitude: number;
  waveformType: WaveformType;
}

/**
 * Frequency Engine for managing audio generation and playback
 */
export class FrequencyEngine {
  private state: FrequencyEngineState = {
    isPlaying: false,
    currentFrequencyHz: 40,
    currentPreset: 'osteo-sync',
    sessionStartTime: null,
    sessionDurationMs: 0,
    amplitude: 0.5,
    waveformType: 'sine',
  };

  private safetyLimits: SafetyLimits;
  private updateInterval: ReturnType<typeof setInterval> | null = null;
  private onSessionTimeout?: () => void;
  private onStateChange?: (state: FrequencyEngineState) => void;

  constructor(
    safetyLimits: SafetyLimits = DEFAULT_SAFETY_LIMITS,
    onSessionTimeout?: () => void,
    onStateChange?: (state: FrequencyEngineState) => void
  ) {
    this.safetyLimits = safetyLimits;
    this.onSessionTimeout = onSessionTimeout;
    this.onStateChange = onStateChange;
  }

  /**
   * Get current state
   */
  getState(): FrequencyEngineState {
    return { ...this.state };
  }

  /**
   * Set frequency preset
   */
  setPreset(presetId: FrequencyPresetId): void {
    const preset = FREQUENCY_PRESETS[presetId];
    this.state.currentPreset = presetId;
    this.state.currentFrequencyHz = preset.primaryFrequencyHz;
    this.notifyStateChange();
  }

  /**
   * Set custom frequency
   */
  setFrequency(frequencyHz: number): void {
    if (frequencyHz < 1 || frequencyHz > 60) {
      throw new Error(`Frequency ${frequencyHz} Hz out of range (1-60 Hz)`);
    }
    this.state.currentFrequencyHz = frequencyHz;
    this.state.currentPreset = 'custom';
    this.notifyStateChange();
  }

  /**
   * Set amplitude (capped by safety limits)
   */
  setAmplitude(amplitude: number): void {
    this.state.amplitude = Math.min(amplitude, this.safetyLimits.maxAmplitude);
    this.notifyStateChange();
  }

  /**
   * Set waveform type
   */
  setWaveformType(type: WaveformType): void {
    this.state.waveformType = type;
    this.notifyStateChange();
  }

  /**
   * Start playback session
   */
  start(): void {
    if (this.state.isPlaying) {
      return;
    }

    this.state.isPlaying = true;
    this.state.sessionStartTime = Date.now();
    this.state.sessionDurationMs = 0;

    // Start session timer for safety cutoff
    this.updateInterval = setInterval(() => {
      this.updateSessionDuration();
    }, 1000);

    this.notifyStateChange();
  }

  /**
   * Stop playback session
   */
  stop(): void {
    if (!this.state.isPlaying) {
      return;
    }

    this.state.isPlaying = false;

    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }

    this.notifyStateChange();
  }

  /**
   * Generate current waveform buffer
   */
  generateBuffer(sampleRate: number, durationSeconds: number): Float32Array {
    return generateWaveform(
      this.state.waveformType,
      this.state.currentFrequencyHz,
      sampleRate,
      durationSeconds,
      this.state.amplitude
    );
  }

  /**
   * Validate frequency against Nyquist theorem
   */
  validateNyquist(sampleRateHz: number): boolean {
    const validation = validateNyquist(this.state.currentFrequencyHz, sampleRateHz);
    return validation.isValid;
  }

  /**
   * Get remaining session time in ms
   */
  getRemainingTimeMs(): number {
    if (!this.state.sessionStartTime) {
      return this.safetyLimits.maxSessionDurationMs;
    }

    const elapsed = Date.now() - this.state.sessionStartTime;
    return Math.max(0, this.safetyLimits.maxSessionDurationMs - elapsed);
  }

  /**
   * Cleanup resources
   */
  destroy(): void {
    this.stop();
    this.onSessionTimeout = undefined;
    this.onStateChange = undefined;
  }

  // Private methods

  private updateSessionDuration(): void {
    if (!this.state.sessionStartTime) {
      return;
    }

    this.state.sessionDurationMs = Date.now() - this.state.sessionStartTime;

    // Check for safety timeout
    if (this.state.sessionDurationMs >= this.safetyLimits.maxSessionDurationMs) {
      this.stop();
      this.onSessionTimeout?.();
    }

    this.notifyStateChange();
  }

  private notifyStateChange(): void {
    this.onStateChange?.(this.getState());
  }
}

// ============================================================================
// WAV FILE UTILITIES
// ============================================================================

/**
 * Create WAV file header
 */
export function createWavHeader(
  numSamples: number,
  sampleRate: number,
  numChannels: number = 1,
  bitsPerSample: number = 16
): ArrayBuffer {
  const byteRate = sampleRate * numChannels * bitsPerSample / 8;
  const blockAlign = numChannels * bitsPerSample / 8;
  const dataSize = numSamples * numChannels * bitsPerSample / 8;
  const fileSize = 36 + dataSize;

  const buffer = new ArrayBuffer(44);
  const view = new DataView(buffer);

  // RIFF header
  writeString(view, 0, 'RIFF');
  view.setUint32(4, fileSize, true);
  writeString(view, 8, 'WAVE');

  // fmt chunk
  writeString(view, 12, 'fmt ');
  view.setUint32(16, 16, true); // chunk size
  view.setUint16(20, 1, true); // PCM format
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bitsPerSample, true);

  // data chunk
  writeString(view, 36, 'data');
  view.setUint32(40, dataSize, true);

  return buffer;
}

function writeString(view: DataView, offset: number, str: string): void {
  for (let i = 0; i < str.length; i++) {
    view.setUint8(offset + i, str.charCodeAt(i));
  }
}

/**
 * Convert Float32Array to WAV blob
 */
export function createWavBlob(
  samples: Float32Array,
  sampleRate: number
): Blob {
  const header = createWavHeader(samples.length, sampleRate);
  const headerArray = new Uint8Array(header);

  // Convert float samples to 16-bit PCM
  const pcmData = new Int16Array(samples.length);
  for (let i = 0; i < samples.length; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    pcmData[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
  }

  const pcmArray = new Uint8Array(pcmData.buffer);

  // Type assertion needed due to React Native type conflicts
  type StandardBlobConstructor = new (blobParts?: ArrayBuffer[], options?: { type?: string }) => Blob;
  const BlobCtor = (globalThis.Blob ?? Blob) as unknown as StandardBlobConstructor;
  return new BlobCtor([header, pcmData.buffer], { type: 'audio/wav' });
}

/**
 * Create data URI from WAV blob
 */
export async function createWavDataUri(
  samples: Float32Array,
  sampleRate: number
): Promise<string> {
  const blob = createWavBlob(samples, sampleRate);
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}
