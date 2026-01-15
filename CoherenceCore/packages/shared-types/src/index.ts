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
// ORGAN RESONANCE FREQUENCIES (Clinical Research)
// Source: MRE studies, PMC6223825, PMC3066083
// ============================================================================

export interface OrganResonanceData {
  organ: string;
  clinicalFrequencyHz: number;
  frequencyRangeHz: [number, number];
  pathologies: string[];
  measurementParameter: string;
  source: string;
}

/**
 * Clinical organ resonance frequencies from peer-reviewed MR Elastography studies
 * These are the frequencies used for CLINICAL measurement, not detection targets
 */
export const ORGAN_RESONANCE_TABLE: Record<string, OrganResonanceData> = {
  liver: {
    organ: 'Liver',
    clinicalFrequencyHz: 60,
    frequencyRangeHz: [50, 70],
    pathologies: ['Fibrosis', 'Cirrhosis', 'Steatosis'],
    measurementParameter: 'Shear Modulus (kPa)',
    source: 'PMC6223825 - MR Elastography',
  },
  heart: {
    organ: 'Heart',
    clinicalFrequencyHz: 110,
    frequencyRangeHz: [80, 140],
    pathologies: ['Myocardial Stiffness', 'HOCM'],
    measurementParameter: 'Myocardial Strain',
    source: 'PMC3066083 - MRE Review',
  },
  spleen: {
    organ: 'Spleen',
    clinicalFrequencyHz: 100,
    frequencyRangeHz: [80, 120],
    pathologies: ['Portal Hypertension'],
    measurementParameter: 'Spleen Stiffness (SSM)',
    source: 'PMC6223825',
  },
  brain: {
    organ: 'Brain',
    clinicalFrequencyHz: 45,
    frequencyRangeHz: [25, 62.5],
    pathologies: ['Neurodegenerative Processes'],
    measurementParameter: 'Viscoelasticity',
    source: 'PMC3066083',
  },
};

/**
 * Body eigenfrequencies in sitting/standing position
 * Source: FAA Technical Report AM63-30pt11
 */
export const BODY_EIGENFREQUENCY_RANGE: [number, number] = [1, 20];

// ============================================================================
// TISSUE ACOUSTIC IMPEDANCE (Biophysical Constants)
// Source: Medical ultrasound reference values
// ============================================================================

export interface TissueAcousticProperties {
  tissue: string;
  density: number; // kg/m³
  soundVelocity: number; // m/s
  impedance: number; // 10^6 kg/m²s (MRayl)
}

export const TISSUE_ACOUSTIC_TABLE: Record<string, TissueAcousticProperties> = {
  liver: { tissue: 'Liver', density: 1050, soundVelocity: 1570, impedance: 1.65 },
  muscle: { tissue: 'Muscle', density: 1040, soundVelocity: 1580, impedance: 1.64 },
  fat: { tissue: 'Fat', density: 925, soundVelocity: 1450, impedance: 1.34 },
  skin: { tissue: 'Skin', density: 1100, soundVelocity: 1600, impedance: 1.76 },
  air: { tissue: 'Air', density: 1.2, soundVelocity: 343, impedance: 0.0004 },
};

/**
 * Calculate intensity reflection coefficient at tissue boundary
 * Returns fraction of energy reflected (0-1)
 */
export function calculateReflectionCoefficient(
  tissue1: TissueAcousticProperties,
  tissue2: TissueAcousticProperties
): number {
  const z1 = tissue1.impedance;
  const z2 = tissue2.impedance;
  const coefficient = Math.pow((z2 - z1) / (z2 + z1), 2);
  return coefficient;
}

// ============================================================================
// SENSOR CAPABILITIES (Research-Backed Limits)
// Source: MDPI Sensors 23(18):7832, PMC10537187
// ============================================================================

/**
 * iPhone LiDAR actual capabilities
 * CRITICAL: Effective sampling rate is 15Hz, NOT 60Hz as API suggests
 */
export const LIDAR_CAPABILITIES = {
  resolution: { width: 256, height: 192 },
  effectiveSamplingRateHz: 15, // NOT 60Hz! Source: PMC10537187
  maxDetectableFrequencyHz: 7.5, // Nyquist limit: 15/2
  rangeMeters: { min: 0.3, max: 5, optimal: { min: 0.3, max: 2 } },
  staticAccuracyCm: 1,
  wavelengthNm: 940,
} as const;

/**
 * iPhone Camera capabilities for EVM analysis
 */
export const CAMERA_CAPABILITIES = {
  maxFps4K: 60,
  maxFps1080p: 120,
  maxFpsSlowMo: 240,
  maxDetectableFrequency4K: 30, // Nyquist: 60/2
  maxDetectableFrequency1080p: 60, // Nyquist: 120/2
  maxDetectableFrequencySlowMo: 120, // Nyquist: 240/2
} as const;

/**
 * IMU capabilities
 */
export const IMU_CAPABILITIES = {
  typicalSampleRateHz: 100,
  maxDetectableFrequencyHz: 50, // Nyquist: 100/2
} as const;

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

// ============================================================================
// ACTIVE HAPTIC MEASUREMENT (Taptic Engine + IMU)
// Source: ResearchGate - Material Recognition using Smartphone Vibrations
// ============================================================================

export type ChirpType = 'linear' | 'exponential' | 'logarithmic';

export interface ActiveHapticConfig {
  /** Measurement mode */
  mode: 'active' | 'passive';
  /** Chirp signal type for active measurement */
  chirpType: ChirpType;
  /** Start frequency for chirp (Hz) */
  chirpStartHz: number;
  /** End frequency for chirp (Hz) */
  chirpEndHz: number;
  /** Chirp duration (ms) */
  chirpDurationMs: number;
  /** Number of chirp repetitions */
  chirpRepetitions: number;
  /** Wait time between chirps (ms) */
  chirpIntervalMs: number;
  /** IMU recording duration after chirp (ms) */
  responseWindowMs: number;
}

export const DEFAULT_ACTIVE_HAPTIC_CONFIG: ActiveHapticConfig = {
  mode: 'passive',
  chirpType: 'linear',
  chirpStartHz: 10,
  chirpEndHz: 100,
  chirpDurationMs: 500,
  chirpRepetitions: 3,
  chirpIntervalMs: 1000,
  responseWindowMs: 200,
};

export interface ActiveHapticResult {
  timestamp: number;
  chirpsSent: number;
  responseSignal: Float32Array;
  dampingCoefficient: number;
  dominantFrequencyHz: number;
  tissueStiffnessEstimate: number; // Arbitrary units, NOT kPa
  qualityScore: number;
}

// ============================================================================
// MULTI-SENSOR FUSION ENGINE
// Source: Deep Research - Multisensor-Fusions-Modell
// ============================================================================

export type SensorSource = 'camera' | 'lidar' | 'imu' | 'haptic' | 'audio';

export interface SensorWeight {
  source: SensorSource;
  weight: number; // 0-1
  confidence: number; // 0-1
  lastUpdateMs: number;
}

export interface FusionConfig {
  /** Enabled sensor sources */
  enabledSources: SensorSource[];
  /** Sensor weights (auto-adjusted based on confidence) */
  weights: Record<SensorSource, number>;
  /** Kalman filter process noise */
  processNoise: number;
  /** Kalman filter measurement noise */
  measurementNoise: number;
  /** Maximum sensor age before exclusion (ms) */
  maxSensorAgeMs: number;
  /** Minimum confidence threshold */
  minConfidenceThreshold: number;
}

export const DEFAULT_FUSION_CONFIG: FusionConfig = {
  enabledSources: ['camera', 'imu'],
  weights: {
    camera: 0.4,
    lidar: 0.1, // Low weight due to 15Hz limit
    imu: 0.3,
    haptic: 0.15,
    audio: 0.05,
  },
  processNoise: 0.01,
  measurementNoise: 0.1,
  maxSensorAgeMs: 500,
  minConfidenceThreshold: 0.3,
};

export interface FusionResult {
  timestamp: number;
  /** Fused frequency estimate (Hz) */
  fusedFrequencyHz: number;
  /** Fused amplitude estimate (0-1) */
  fusedAmplitude: number;
  /** Overall confidence (0-1) */
  confidence: number;
  /** Individual sensor contributions */
  sensorContributions: Record<SensorSource, { frequency: number; weight: number; confidence: number }>;
  /** Estimated tissue properties */
  tissueEstimates: {
    stiffness: number; // Arbitrary units
    damping: number; // Arbitrary units
    resonanceFrequency: number; // Hz
  };
}

// ============================================================================
// USER BIOMETRIC CALIBRATION
// For individual variance compensation (BMI, age correction)
// ============================================================================

export interface UserCalibration {
  /** User identifier (anonymous) */
  userId: string;
  /** Age range (for tissue property estimation) */
  ageRange: '18-30' | '30-45' | '45-60' | '60+';
  /** BMI category (affects subcutaneous fat damping) */
  bmiCategory: 'underweight' | 'normal' | 'overweight' | 'obese';
  /** Estimated fat layer thickness multiplier (1.0 = average) */
  fatLayerMultiplier: number;
  /** Skin elasticity multiplier (1.0 = average, decreases with age) */
  skinElasticityMultiplier: number;
  /** Calibration timestamp */
  calibratedAt: number;
}

export const DEFAULT_USER_CALIBRATION: UserCalibration = {
  userId: 'anonymous',
  ageRange: '30-45',
  bmiCategory: 'normal',
  fatLayerMultiplier: 1.0,
  skinElasticityMultiplier: 1.0,
  calibratedAt: 0,
};

/**
 * Calculate tissue damping correction factor based on user calibration
 */
export function calculateDampingCorrection(calibration: UserCalibration): number {
  // Base damping factor
  let damping = 1.0;

  // Age correction (older = more damping)
  const ageCorrection: Record<string, number> = {
    '18-30': 0.85,
    '30-45': 1.0,
    '45-60': 1.15,
    '60+': 1.3,
  };
  damping *= ageCorrection[calibration.ageRange] || 1.0;

  // BMI correction (higher BMI = more fat layer damping)
  const bmiCorrection: Record<string, number> = {
    underweight: 0.8,
    normal: 1.0,
    overweight: 1.25,
    obese: 1.5,
  };
  damping *= bmiCorrection[calibration.bmiCategory] || 1.0;

  // Apply user-specific multipliers
  damping *= calibration.fatLayerMultiplier;

  return damping;
}

// ============================================================================
// SHARED UTILITY FUNCTIONS (Consolidated to eliminate cross-hook duplication)
// ============================================================================

/**
 * Validate frequency is within safe operating range
 */
export function validateFrequencyRange(
  frequencyHz: number,
  minHz: number = 1,
  maxHz: number = 60
): { isValid: boolean; error?: string } {
  if (frequencyHz < minHz || frequencyHz > maxHz) {
    return {
      isValid: false,
      error: `Frequency ${frequencyHz} Hz out of range (${minHz}-${maxHz} Hz)`,
    };
  }
  return { isValid: true };
}

/**
 * Clamp amplitude to safety limits
 */
export function clampAmplitude(
  amplitude: number,
  limits: SafetyLimits = DEFAULT_SAFETY_LIMITS
): number {
  return Math.max(0, Math.min(limits.maxAmplitude, amplitude));
}

/**
 * Calculate remaining session time
 */
export function calculateRemainingTime(
  elapsedMs: number,
  maxDurationMs: number = DEFAULT_SAFETY_LIMITS.maxSessionDurationMs
): number {
  return Math.max(0, maxDurationMs - elapsedMs);
}

/**
 * Check if session duration exceeded safety limits
 */
export function isSessionTimeoutReached(
  elapsedMs: number,
  limits: SafetyLimits = DEFAULT_SAFETY_LIMITS
): boolean {
  return elapsedMs >= limits.maxSessionDurationMs;
}

/**
 * Format duration in ms to MM:SS string
 */
export function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

/**
 * Get frequency preset by ID, with fallback
 */
export function getFrequencyPreset(presetId: FrequencyPresetId): FrequencyPreset {
  return FREQUENCY_PRESETS[presetId] || FREQUENCY_PRESETS['osteo-sync'];
}

/**
 * Validate preset frequency is within range
 */
export function validatePresetFrequency(
  presetId: FrequencyPresetId,
  frequencyHz: number
): boolean {
  const preset = FREQUENCY_PRESETS[presetId];
  if (!preset) return false;

  const [min, max] = preset.frequencyRangeHz;
  return frequencyHz >= min && frequencyHz <= max;
}

/**
 * Estimate signal quality from variance
 * Higher quality when variance near optimalVariance
 */
export function estimateSignalQuality(signal: number[], optimalVariance: number = 0.01): number {
  if (signal.length < 32) return 0;

  const mean = signal.reduce((a, b) => a + b, 0) / signal.length;
  const variance = signal.reduce((sum, val) => sum + (val - mean) ** 2, 0) / signal.length;

  // Exponential decay from optimal variance
  const quality = Math.exp(-Math.abs(Math.log10(variance / optimalVariance)));
  return Math.max(0, Math.min(1, quality));
}

/**
 * Estimate noise level from high-frequency content
 */
export function estimateNoiseLevel(signal: number[]): number {
  if (signal.length < 2) return 0;

  let highFreqEnergy = 0;
  let totalEnergy = 0;

  for (let i = 1; i < signal.length; i++) {
    const diff = signal[i] - signal[i - 1];
    highFreqEnergy += diff * diff;
    totalEnergy += signal[i] * signal[i];
  }

  return totalEnergy < 0.0001 ? 0 : Math.min(1, highFreqEnergy / totalEnergy);
}
