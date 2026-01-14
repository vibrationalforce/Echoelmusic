/**
 * CoherenceCore Multi-Sensor Fusion Engine
 *
 * Fuses data from multiple sensors (Camera EVM, LiDAR, IMU, Haptic, Audio)
 * using Kalman filtering and weighted averaging for robust frequency estimation.
 *
 * Based on: Deep Research - Multisensor-Fusions-Modell
 * Architecture follows blind source separation principles from PMC 392218674
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import {
  SensorSource,
  FusionConfig,
  DEFAULT_FUSION_CONFIG,
  FusionResult,
  UserCalibration,
  DEFAULT_USER_CALIBRATION,
  calculateDampingCorrection,
  LIDAR_CAPABILITIES,
  CAMERA_CAPABILITIES,
  IMU_CAPABILITIES,
  validateNyquist,
} from '@coherence-core/shared-types';

// ============================================================================
// SENSOR DATA TYPES
// ============================================================================

export interface SensorReading {
  source: SensorSource;
  timestamp: number;
  frequencyHz: number;
  amplitude: number;
  confidence: number;
  rawData?: Float32Array;
}

export interface KalmanState {
  estimate: number;
  errorCovariance: number;
}

// ============================================================================
// KALMAN FILTER
// ============================================================================

/**
 * Simple 1D Kalman filter for sensor fusion
 */
export class KalmanFilter {
  private state: KalmanState;
  private processNoise: number;
  private measurementNoise: number;

  constructor(
    initialEstimate: number = 0,
    initialError: number = 1,
    processNoise: number = 0.01,
    measurementNoise: number = 0.1
  ) {
    this.state = {
      estimate: initialEstimate,
      errorCovariance: initialError,
    };
    this.processNoise = processNoise;
    this.measurementNoise = measurementNoise;
  }

  /**
   * Predict step (time update)
   */
  predict(): void {
    // State prediction (assume constant model)
    // x_k = x_{k-1}

    // Error covariance prediction
    this.state.errorCovariance += this.processNoise;
  }

  /**
   * Update step (measurement update)
   */
  update(measurement: number, measurementNoise?: number): number {
    const R = measurementNoise ?? this.measurementNoise;

    // Kalman gain
    const K = this.state.errorCovariance / (this.state.errorCovariance + R);

    // State update
    this.state.estimate = this.state.estimate + K * (measurement - this.state.estimate);

    // Error covariance update
    this.state.errorCovariance = (1 - K) * this.state.errorCovariance;

    return this.state.estimate;
  }

  /**
   * Get current estimate
   */
  getEstimate(): number {
    return this.state.estimate;
  }

  /**
   * Get current error covariance
   */
  getErrorCovariance(): number {
    return this.state.errorCovariance;
  }

  /**
   * Reset filter state
   */
  reset(estimate: number = 0, errorCovariance: number = 1): void {
    this.state.estimate = estimate;
    this.state.errorCovariance = errorCovariance;
  }
}

// ============================================================================
// BLIND SOURCE SEPARATION (Simplified)
// ============================================================================

/**
 * Extract independent signal components from mixed sensor readings
 * Simplified version of ICA (Independent Component Analysis)
 */
export function separateSignalSources(
  readings: SensorReading[],
  windowSizeMs: number = 1000
): SensorReading[] {
  if (readings.length === 0) return readings;

  // Group readings by source
  const bySource = new Map<SensorSource, SensorReading[]>();
  for (const reading of readings) {
    const existing = bySource.get(reading.source) || [];
    existing.push(reading);
    bySource.set(reading.source, existing);
  }

  // For each source, compute mean and variance
  const separated: SensorReading[] = [];

  for (const [source, sourceReadings] of bySource) {
    if (sourceReadings.length === 0) continue;

    // Filter to window
    const now = Date.now();
    const windowedReadings = sourceReadings.filter(
      (r) => now - r.timestamp < windowSizeMs
    );

    if (windowedReadings.length === 0) continue;

    // Calculate weighted average
    let sumFreq = 0;
    let sumAmp = 0;
    let sumConf = 0;
    let weightSum = 0;

    for (const r of windowedReadings) {
      const weight = r.confidence;
      sumFreq += r.frequencyHz * weight;
      sumAmp += r.amplitude * weight;
      sumConf += r.confidence;
      weightSum += weight;
    }

    if (weightSum > 0) {
      separated.push({
        source,
        timestamp: now,
        frequencyHz: sumFreq / weightSum,
        amplitude: sumAmp / weightSum,
        confidence: sumConf / windowedReadings.length,
      });
    }
  }

  return separated;
}

// ============================================================================
// SENSOR VALIDATION
// ============================================================================

/**
 * Validate sensor reading against Nyquist constraints
 */
export function validateSensorReading(reading: SensorReading): boolean {
  const sensorLimits: Record<SensorSource, number> = {
    camera: CAMERA_CAPABILITIES.maxDetectableFrequency4K, // 30 Hz
    lidar: LIDAR_CAPABILITIES.maxDetectableFrequencyHz, // 7.5 Hz
    imu: IMU_CAPABILITIES.maxDetectableFrequencyHz, // 50 Hz
    haptic: IMU_CAPABILITIES.maxDetectableFrequencyHz, // Uses IMU
    audio: 22050, // 44100 / 2
  };

  const maxFreq = sensorLimits[reading.source] || 60;
  return reading.frequencyHz <= maxFreq && reading.frequencyHz > 0;
}

/**
 * Get maximum detectable frequency for a sensor source
 */
export function getMaxDetectableFrequency(source: SensorSource): number {
  switch (source) {
    case 'camera':
      return CAMERA_CAPABILITIES.maxDetectableFrequency4K;
    case 'lidar':
      return LIDAR_CAPABILITIES.maxDetectableFrequencyHz;
    case 'imu':
    case 'haptic':
      return IMU_CAPABILITIES.maxDetectableFrequencyHz;
    case 'audio':
      return 22050;
    default:
      return 60;
  }
}

// ============================================================================
// MULTI-SENSOR FUSION ENGINE
// ============================================================================

export interface FusionEngineState {
  config: FusionConfig;
  userCalibration: UserCalibration;
  kalmanFilters: Record<string, KalmanFilter>;
  readingBuffer: SensorReading[];
  latestResult: FusionResult | null;
  isRunning: boolean;
}

/**
 * Multi-Sensor Fusion Engine
 *
 * Combines data from multiple sensors using Kalman filtering
 * and weighted averaging for robust frequency and amplitude estimation.
 */
export class FusionEngine {
  private state: FusionEngineState;
  private maxBufferSize = 1000;
  private onResult?: (result: FusionResult) => void;

  constructor(
    config: FusionConfig = DEFAULT_FUSION_CONFIG,
    onResult?: (result: FusionResult) => void
  ) {
    this.state = {
      config,
      userCalibration: DEFAULT_USER_CALIBRATION,
      kalmanFilters: {
        frequency: new KalmanFilter(40, 1, config.processNoise, config.measurementNoise),
        amplitude: new KalmanFilter(0.5, 1, config.processNoise, config.measurementNoise),
      },
      readingBuffer: [],
      latestResult: null,
      isRunning: false,
    };
    this.onResult = onResult;
  }

  /**
   * Get current configuration
   */
  getConfig(): FusionConfig {
    return { ...this.state.config };
  }

  /**
   * Update configuration
   */
  setConfig(config: Partial<FusionConfig>): void {
    this.state.config = { ...this.state.config, ...config };
  }

  /**
   * Set user calibration data
   */
  setUserCalibration(calibration: UserCalibration): void {
    this.state.userCalibration = calibration;
  }

  /**
   * Get user calibration
   */
  getUserCalibration(): UserCalibration {
    return { ...this.state.userCalibration };
  }

  /**
   * Start the fusion engine
   */
  start(): void {
    this.state.isRunning = true;
  }

  /**
   * Stop the fusion engine
   */
  stop(): void {
    this.state.isRunning = false;
  }

  /**
   * Check if engine is running
   */
  isRunning(): boolean {
    return this.state.isRunning;
  }

  /**
   * Add a sensor reading to the fusion buffer
   */
  addReading(reading: SensorReading): void {
    // Validate the reading
    if (!validateSensorReading(reading)) {
      console.warn(
        `Invalid reading from ${reading.source}: ${reading.frequencyHz} Hz exceeds Nyquist limit`
      );
      return;
    }

    // Check if sensor is enabled
    if (!this.state.config.enabledSources.includes(reading.source)) {
      return;
    }

    // Check confidence threshold
    if (reading.confidence < this.state.config.minConfidenceThreshold) {
      return;
    }

    // Add to buffer
    this.state.readingBuffer.push(reading);

    // Trim buffer
    if (this.state.readingBuffer.length > this.maxBufferSize) {
      this.state.readingBuffer = this.state.readingBuffer.slice(-this.maxBufferSize);
    }
  }

  /**
   * Process all buffered readings and produce a fused result
   */
  process(): FusionResult | null {
    if (!this.state.isRunning) return null;

    const now = Date.now();
    const maxAge = this.state.config.maxSensorAgeMs;

    // Filter to recent readings
    const recentReadings = this.state.readingBuffer.filter(
      (r) => now - r.timestamp < maxAge
    );

    if (recentReadings.length === 0) {
      return null;
    }

    // Separate sources
    const separatedReadings = separateSignalSources(recentReadings, maxAge);

    // Calculate weighted fusion
    const sensorContributions: Record<
      SensorSource,
      { frequency: number; weight: number; confidence: number }
    > = {
      camera: { frequency: 0, weight: 0, confidence: 0 },
      lidar: { frequency: 0, weight: 0, confidence: 0 },
      imu: { frequency: 0, weight: 0, confidence: 0 },
      haptic: { frequency: 0, weight: 0, confidence: 0 },
      audio: { frequency: 0, weight: 0, confidence: 0 },
    };

    let totalWeight = 0;
    let weightedFreqSum = 0;
    let weightedAmpSum = 0;
    let totalConfidence = 0;

    for (const reading of separatedReadings) {
      const baseWeight = this.state.config.weights[reading.source] || 0;
      const effectiveWeight = baseWeight * reading.confidence;

      sensorContributions[reading.source] = {
        frequency: reading.frequencyHz,
        weight: effectiveWeight,
        confidence: reading.confidence,
      };

      weightedFreqSum += reading.frequencyHz * effectiveWeight;
      weightedAmpSum += reading.amplitude * effectiveWeight;
      totalWeight += effectiveWeight;
      totalConfidence += reading.confidence;
    }

    if (totalWeight === 0) {
      return null;
    }

    // Calculate fused values
    const rawFrequency = weightedFreqSum / totalWeight;
    const rawAmplitude = weightedAmpSum / totalWeight;
    const avgConfidence = totalConfidence / separatedReadings.length;

    // Apply Kalman filtering
    this.state.kalmanFilters.frequency.predict();
    this.state.kalmanFilters.amplitude.predict();

    const fusedFrequency = this.state.kalmanFilters.frequency.update(
      rawFrequency,
      this.state.config.measurementNoise / avgConfidence
    );
    const fusedAmplitude = this.state.kalmanFilters.amplitude.update(
      rawAmplitude,
      this.state.config.measurementNoise / avgConfidence
    );

    // Apply user calibration damping correction
    const dampingCorrection = calculateDampingCorrection(this.state.userCalibration);

    // Estimate tissue properties (arbitrary units, NOT medical)
    const tissueEstimates = {
      stiffness: fusedAmplitude * 100 / dampingCorrection,
      damping: dampingCorrection,
      resonanceFrequency: fusedFrequency,
    };

    const result: FusionResult = {
      timestamp: now,
      fusedFrequencyHz: fusedFrequency,
      fusedAmplitude: Math.min(1, Math.max(0, fusedAmplitude)),
      confidence: Math.min(1, avgConfidence),
      sensorContributions,
      tissueEstimates,
    };

    this.state.latestResult = result;
    this.onResult?.(result);

    return result;
  }

  /**
   * Get the latest fusion result
   */
  getLatestResult(): FusionResult | null {
    return this.state.latestResult;
  }

  /**
   * Clear all buffers and reset filters
   */
  reset(): void {
    this.state.readingBuffer = [];
    this.state.latestResult = null;
    this.state.kalmanFilters.frequency.reset(40, 1);
    this.state.kalmanFilters.amplitude.reset(0.5, 1);
  }

  /**
   * Get sensor statistics
   */
  getSensorStats(): Record<SensorSource, { count: number; avgConfidence: number; lastUpdate: number }> {
    const stats: Record<SensorSource, { count: number; avgConfidence: number; lastUpdate: number }> = {
      camera: { count: 0, avgConfidence: 0, lastUpdate: 0 },
      lidar: { count: 0, avgConfidence: 0, lastUpdate: 0 },
      imu: { count: 0, avgConfidence: 0, lastUpdate: 0 },
      haptic: { count: 0, avgConfidence: 0, lastUpdate: 0 },
      audio: { count: 0, avgConfidence: 0, lastUpdate: 0 },
    };

    const now = Date.now();
    const maxAge = this.state.config.maxSensorAgeMs;

    for (const reading of this.state.readingBuffer) {
      if (now - reading.timestamp > maxAge) continue;

      const sourceStat = stats[reading.source];
      sourceStat.count++;
      sourceStat.avgConfidence += reading.confidence;
      if (reading.timestamp > sourceStat.lastUpdate) {
        sourceStat.lastUpdate = reading.timestamp;
      }
    }

    // Calculate averages
    for (const source of Object.keys(stats) as SensorSource[]) {
      if (stats[source].count > 0) {
        stats[source].avgConfidence /= stats[source].count;
      }
    }

    return stats;
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

export {
  FusionConfig,
  DEFAULT_FUSION_CONFIG,
  FusionResult,
  UserCalibration,
  DEFAULT_USER_CALIBRATION,
  SensorSource,
} from '@coherence-core/shared-types';
