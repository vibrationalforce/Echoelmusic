/**
 * CoherenceCore Shared Types
 *
 * Biophysical resonance framework types for quad-platform support.
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

// ============================================================================
// SAFETY & COMPLIANCE
// ============================================================================

export const DISCLAIMER_TEXT = "Wellness/Informational Tool - No Medical Advice" as const;

export interface SafetyLimits {
  /** Maximum session duration in milliseconds (default: 15 minutes) */
  maxSessionDurationMs: number;
  /** Maximum duty cycle 0-1 (default: 0.7 = 70%) */
  maxDutyCycle: number;
  /** Maximum amplitude 0-1 (default: 0.8 = 80%) */
  maxAmplitude: number;
  /** Cooldown period between sessions in milliseconds */
  cooldownPeriodMs: number;
}

export const DEFAULT_SAFETY_LIMITS: SafetyLimits = {
  maxSessionDurationMs: 15 * 60 * 1000, // 15 minutes
  maxDutyCycle: 0.7,
  maxAmplitude: 0.8,
  cooldownPeriodMs: 5 * 60 * 1000, // 5 minutes
};

// ============================================================================
// BIOPHYSICAL FREQUENCY PRESETS
// ============================================================================

export type FrequencyPresetId = 'osteo-sync' | 'myo-resonance' | 'neural-flow' | 'custom';

export interface FrequencyPreset {
  id: FrequencyPresetId;
  name: string;
  description: string;
  frequencyRangeHz: [number, number];
  primaryFrequencyHz: number;
  research: string;
  target: string;
}

export const FREQUENCY_PRESETS: Record<FrequencyPresetId, FrequencyPreset> = {
  'osteo-sync': {
    id: 'osteo-sync',
    name: 'Osteo-Sync',
    description: '35-45 Hz for bone tissue resonance',
    frequencyRangeHz: [35, 45],
    primaryFrequencyHz: 40,
    research: 'Rubin et al. (2006) - Low-magnitude mechanical signals',
    target: 'Osteoblast activity optimization',
  },
  'myo-resonance': {
    id: 'myo-resonance',
    name: 'Myo-Resonance',
    description: '45-50 Hz for muscle fiber coherence',
    frequencyRangeHz: [45, 50],
    primaryFrequencyHz: 47.5,
    research: 'Judex & Rubin (2010) - Mechanical influences',
    target: 'Myofibril coherence, fibrosis reduction',
  },
  'neural-flow': {
    id: 'neural-flow',
    name: 'Neural-Flow',
    description: '40 Hz gamma entrainment',
    frequencyRangeHz: [38, 42],
    primaryFrequencyHz: 40,
    research: 'Iaccarino et al. (2016) - Gamma entrainment',
    target: 'Neural gamma oscillation, focus',
  },
  custom: {
    id: 'custom',
    name: 'Custom',
    description: 'Custom frequency range',
    frequencyRangeHz: [1, 60],
    primaryFrequencyHz: 40,
    research: 'User-defined',
    target: 'Custom application',
  },
};

// ============================================================================
// EVM (EULERIAN VIDEO MAGNIFICATION)
// ============================================================================

export interface EVMConfig {
  /** Target frequency range to detect (Hz) */
  frequencyRangeHz: [number, number];
  /** Amplification factor for visualization */
  amplificationFactor: number;
  /** Number of Laplacian pyramid levels */
  pyramidLevels: number;
  /** Temporal filter order */
  filterOrder: number;
  /** Analysis frame rate */
  analysisFrameRate: number;
}

export const DEFAULT_EVM_CONFIG: EVMConfig = {
  frequencyRangeHz: [1, 60],
  amplificationFactor: 50,
  pyramidLevels: 4,
  filterOrder: 2,
  analysisFrameRate: 30,
};

export interface EVMAnalysisResult {
  timestamp: number;
  detectedFrequencies: number[];
  spatialAmplitudes: number[];
  qualityScore: number; // 0-1
  frameRate: number;
}

// ============================================================================
// IMU (INERTIAL MEASUREMENT UNIT)
// ============================================================================

export interface IMUConfig {
  /** Sample rate in Hz */
  sampleRateHz: number;
  /** FFT window size (power of 2) */
  fftWindowSize: number;
  /** Target frequency range for analysis */
  targetFrequencyRangeHz: [number, number];
  /** Noise floor threshold */
  noiseFloorThreshold: number;
}

export const DEFAULT_IMU_CONFIG: IMUConfig = {
  sampleRateHz: 100,
  fftWindowSize: 256,
  targetFrequencyRangeHz: [30, 50],
  noiseFloorThreshold: 0.001,
};

export interface IMUAnalysisResult {
  timestamp: number;
  dominantFrequencyHz: number;
  frequencySpectrum: number[];
  peakAcceleration: number;
  rmsVibration: number;
  isInTargetRange: boolean;
}

export interface AccelerometerSample {
  timestamp: number;
  x: number;
  y: number;
  z: number;
}

// ============================================================================
// AUDIO OUTPUT (VAT - VIBROACOUSTIC THERAPY)
// ============================================================================

export interface AudioConfig {
  /** Sample rate in Hz */
  sampleRate: number;
  /** Target frequency to generate */
  frequencyHz: number;
  /** Amplitude 0-1 (capped by safety limits) */
  amplitude: number;
  /** Waveform type */
  waveform: 'sine' | 'square' | 'triangle' | 'sawtooth';
  /** Duration in seconds */
  durationSeconds: number;
}

export const DEFAULT_AUDIO_CONFIG: AudioConfig = {
  sampleRate: 44100,
  frequencyHz: 40,
  amplitude: 0.5,
  waveform: 'sine',
  durationSeconds: 60,
};

// ============================================================================
// HAPTIC FEEDBACK
// ============================================================================

export type HapticPatternType =
  | 'continuous'
  | 'pulsed'
  | 'ramping'
  | 'binaural'
  | 'coherent'
  | 'breathing';

export interface HapticConfig {
  /** Target frequency in Hz */
  frequencyHz: number;
  /** Intensity 0-1 (capped by safety limits) */
  intensity: number;
  /** Pattern type */
  patternType: HapticPatternType;
  /** Duty cycle 0-1 for pulsed patterns */
  dutyCycle: number;
}

export const DEFAULT_HAPTIC_CONFIG: HapticConfig = {
  frequencyHz: 40,
  intensity: 0.5,
  patternType: 'continuous',
  dutyCycle: 0.5,
};

// ============================================================================
// CYMATICS VISUALIZATION
// ============================================================================

export type CymaticsPattern =
  | 'hexagonal'
  | 'muscular-wave'
  | 'neural'
  | 'flowing-water'
  | 'vortex'
  | 'geometric'
  | 'mandala'
  | 'cellular';

export type CymaticsColorMode =
  | 'coherence'
  | 'frequency'
  | 'amplitude'
  | 'rainbow'
  | 'monochrome'
  | 'thermal';

export interface CymaticsConfig {
  /** Current frequency being visualized */
  frequencyHz: number;
  /** Wave amplitude 0-1 */
  amplitude: number;
  /** Pattern type */
  pattern: CymaticsPattern;
  /** Color mode */
  colorMode: CymaticsColorMode;
  /** Number of symmetry axes */
  symmetry: number;
  /** Wave propagation speed */
  waveSpeed: number;
  /** Damping factor */
  damping: number;
}

export const DEFAULT_CYMATICS_CONFIG: CymaticsConfig = {
  frequencyHz: 40,
  amplitude: 0.5,
  pattern: 'geometric',
  colorMode: 'coherence',
  symmetry: 6,
  waveSpeed: 1.0,
  damping: 0.98,
};

// ============================================================================
// SESSION STATE
// ============================================================================

export interface SessionState {
  isActive: boolean;
  startTime: number | null;
  durationMs: number;
  preset: FrequencyPresetId;
  customFrequencyHz: number;
  vibrationEnabled: boolean;
  soundEnabled: boolean;
  visualsEnabled: boolean;
  evmEnabled: boolean;
  imuEnabled: boolean;
  coherenceHistory: number[];
  frequencyHistory: number[];
  disclaimerAcknowledged: boolean;
}

export const DEFAULT_SESSION_STATE: SessionState = {
  isActive: false,
  startTime: null,
  durationMs: 0,
  preset: 'osteo-sync',
  customFrequencyHz: 40,
  vibrationEnabled: true,
  soundEnabled: true,
  visualsEnabled: true,
  evmEnabled: false,
  imuEnabled: true,
  coherenceHistory: [],
  frequencyHistory: [],
  disclaimerAcknowledged: false,
};

// ============================================================================
// HARDWARE VALIDATION
// ============================================================================

export interface HardwareCapabilities {
  platform: 'ios' | 'android' | 'windows' | 'linux';
  cameraMaxFps: number;
  imuSampleRateHz: number | null;
  hasHaptics: boolean;
  hasLidar: boolean;
  lidarMaxHz: number | null;
  supportsLowLatencyAudio: boolean;
}

export interface NyquistValidation {
  targetFrequencyHz: number;
  sampleRateHz: number;
  nyquistFrequencyHz: number;
  isValid: boolean;
  warningMessage: string | null;
}

/**
 * Validate sample rate against Nyquist theorem
 */
export function validateNyquist(
  targetFrequencyHz: number,
  sampleRateHz: number
): NyquistValidation {
  const nyquistFrequencyHz = sampleRateHz / 2;
  const isValid = targetFrequencyHz <= nyquistFrequencyHz;

  let warningMessage: string | null = null;
  if (!isValid) {
    warningMessage = `Target frequency ${targetFrequencyHz} Hz exceeds Nyquist limit ${nyquistFrequencyHz} Hz (sample rate: ${sampleRateHz} Hz). Aliasing will occur.`;
  }

  return {
    targetFrequencyHz,
    sampleRateHz,
    nyquistFrequencyHz,
    isValid,
    warningMessage,
  };
}

// ============================================================================
// ERROR TYPES
// ============================================================================

export type CoherenceCoreErrorCode =
  | 'DISCLAIMER_NOT_ACKNOWLEDGED'
  | 'SESSION_ALREADY_ACTIVE'
  | 'SESSION_TIMEOUT'
  | 'SENSOR_NOT_AVAILABLE'
  | 'HAPTIC_NOT_AVAILABLE'
  | 'CAMERA_ACCESS_DENIED'
  | 'FREQUENCY_OUT_OF_RANGE'
  | 'NYQUIST_VIOLATION'
  | 'SAFETY_LIMIT_EXCEEDED';

export interface CoherenceCoreError {
  code: CoherenceCoreErrorCode;
  message: string;
  details?: unknown;
}

// ============================================================================
// PLATFORM DETECTION
// ============================================================================

export type Platform = 'ios' | 'android' | 'windows' | 'linux' | 'web' | 'unknown';

export function detectPlatform(): Platform {
  if (typeof window === 'undefined') {
    // Node.js environment - check process.platform for Tauri
    if (typeof process !== 'undefined' && process.platform) {
      if (process.platform === 'win32') return 'windows';
      if (process.platform === 'linux') return 'linux';
      if (process.platform === 'darwin') return 'ios'; // macOS treated as iOS for now
    }
    return 'unknown';
  }

  // Browser/React Native environment
  const userAgent = navigator.userAgent.toLowerCase();

  if (/iphone|ipad|ipod/.test(userAgent)) return 'ios';
  if (/android/.test(userAgent)) return 'android';
  if (/windows/.test(userAgent)) return 'windows';
  if (/linux/.test(userAgent)) return 'linux';

  return 'web';
}
