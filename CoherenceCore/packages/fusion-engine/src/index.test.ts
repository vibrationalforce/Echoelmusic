/**
 * CoherenceCore Fusion Engine Tests
 *
 * Comprehensive test suite for multi-sensor fusion engine.
 */

import {
  FusionEngine,
  KalmanFilter,
  separateSignalSources,
  validateSensorReading,
  getMaxDetectableFrequency,
  SensorReading,
  DEFAULT_FUSION_CONFIG,
  DEFAULT_USER_CALIBRATION,
  UserCalibration,
} from './index';

// Import constants and utilities from shared-types (consolidated - no local duplicates)
import {
  ORGAN_RESONANCE_TABLE,
  TISSUE_ACOUSTIC_TABLE,
  LIDAR_CAPABILITIES,
  CAMERA_CAPABILITIES,
  IMU_CAPABILITIES,
  TissueAcousticProperties,
  calculateReflectionCoefficient,
} from '@coherence-core/shared-types';

function calculateDampingCorrection(calibration: UserCalibration): number {
  let damping = 1.0;
  const ageCorrection: Record<string, number> = {
    '18-30': 0.85, '30-45': 1.0, '45-60': 1.15, '60+': 1.3,
  };
  damping *= ageCorrection[calibration.ageRange] || 1.0;
  const bmiCorrection: Record<string, number> = {
    underweight: 0.8, normal: 1.0, overweight: 1.25, obese: 1.5,
  };
  damping *= bmiCorrection[calibration.bmiCategory] || 1.0;
  damping *= calibration.fatLayerMultiplier;
  return damping;
}

// ============================================================================
// KALMAN FILTER TESTS
// ============================================================================

describe('KalmanFilter', () => {
  it('should initialize with default values', () => {
    const filter = new KalmanFilter();
    expect(filter.getEstimate()).toBe(0);
    expect(filter.getErrorCovariance()).toBe(1);
  });

  it('should initialize with custom values', () => {
    const filter = new KalmanFilter(40, 0.5, 0.01, 0.1);
    expect(filter.getEstimate()).toBe(40);
    expect(filter.getErrorCovariance()).toBe(0.5);
  });

  it('should converge to measurement over time', () => {
    const filter = new KalmanFilter(0, 1, 0.01, 0.1);
    const targetValue = 40;

    // Apply several measurements
    for (let i = 0; i < 20; i++) {
      filter.predict();
      filter.update(targetValue);
    }

    // Should converge to target
    expect(filter.getEstimate()).toBeCloseTo(targetValue, 1);
  });

  it('should handle noisy measurements', () => {
    const filter = new KalmanFilter(40, 1, 0.01, 0.5);
    const trueValue = 40;

    // Apply noisy measurements
    const estimates: number[] = [];
    for (let i = 0; i < 50; i++) {
      const noise = (Math.random() - 0.5) * 10; // ±5 Hz noise
      filter.predict();
      filter.update(trueValue + noise);
      estimates.push(filter.getEstimate());
    }

    // Final estimate should be close to true value
    const finalEstimate = estimates[estimates.length - 1];
    expect(Math.abs(finalEstimate - trueValue)).toBeLessThan(3);
  });

  it('should reset correctly', () => {
    const filter = new KalmanFilter(50, 0.5, 0.01, 0.1);
    filter.update(60);
    filter.reset(0, 1);

    expect(filter.getEstimate()).toBe(0);
    expect(filter.getErrorCovariance()).toBe(1);
  });
});

// ============================================================================
// SENSOR VALIDATION TESTS
// ============================================================================

describe('Sensor Validation', () => {
  it('should validate camera readings within Nyquist limit', () => {
    const validReading: SensorReading = {
      source: 'camera',
      timestamp: Date.now(),
      frequencyHz: 25, // Within 30 Hz limit
      amplitude: 0.5,
      confidence: 0.8,
    };
    expect(validateSensorReading(validReading)).toBe(true);
  });

  it('should reject camera readings above Nyquist limit', () => {
    const invalidReading: SensorReading = {
      source: 'camera',
      timestamp: Date.now(),
      frequencyHz: 35, // Above 30 Hz limit
      amplitude: 0.5,
      confidence: 0.8,
    };
    expect(validateSensorReading(invalidReading)).toBe(false);
  });

  it('should validate LiDAR readings within 7.5 Hz limit', () => {
    const validReading: SensorReading = {
      source: 'lidar',
      timestamp: Date.now(),
      frequencyHz: 5, // Within 7.5 Hz limit
      amplitude: 0.5,
      confidence: 0.8,
    };
    expect(validateSensorReading(validReading)).toBe(true);
  });

  it('should reject LiDAR readings above 7.5 Hz limit', () => {
    const invalidReading: SensorReading = {
      source: 'lidar',
      timestamp: Date.now(),
      frequencyHz: 10, // Above 7.5 Hz limit
      amplitude: 0.5,
      confidence: 0.8,
    };
    expect(validateSensorReading(invalidReading)).toBe(false);
  });

  it('should validate IMU readings within 50 Hz limit', () => {
    const validReading: SensorReading = {
      source: 'imu',
      timestamp: Date.now(),
      frequencyHz: 40, // Within 50 Hz limit
      amplitude: 0.5,
      confidence: 0.8,
    };
    expect(validateSensorReading(validReading)).toBe(true);
  });

  it('should reject zero or negative frequencies', () => {
    const zeroReading: SensorReading = {
      source: 'imu',
      timestamp: Date.now(),
      frequencyHz: 0,
      amplitude: 0.5,
      confidence: 0.8,
    };
    expect(validateSensorReading(zeroReading)).toBe(false);

    const negativeReading: SensorReading = {
      source: 'imu',
      timestamp: Date.now(),
      frequencyHz: -10,
      amplitude: 0.5,
      confidence: 0.8,
    };
    expect(validateSensorReading(negativeReading)).toBe(false);
  });

  it('should return correct max detectable frequencies', () => {
    expect(getMaxDetectableFrequency('camera')).toBe(30);
    expect(getMaxDetectableFrequency('lidar')).toBe(7.5);
    expect(getMaxDetectableFrequency('imu')).toBe(50);
    expect(getMaxDetectableFrequency('haptic')).toBe(50);
    expect(getMaxDetectableFrequency('audio')).toBe(22050);
  });
});

// ============================================================================
// SIGNAL SEPARATION TESTS
// ============================================================================

describe('Signal Separation', () => {
  it('should separate readings by source', () => {
    const now = Date.now();
    const readings: SensorReading[] = [
      { source: 'camera', timestamp: now, frequencyHz: 25, amplitude: 0.5, confidence: 0.8 },
      { source: 'camera', timestamp: now - 100, frequencyHz: 26, amplitude: 0.6, confidence: 0.7 },
      { source: 'imu', timestamp: now, frequencyHz: 40, amplitude: 0.4, confidence: 0.9 },
    ];

    const separated = separateSignalSources(readings, 1000);

    expect(separated.length).toBe(2); // Camera and IMU
    expect(separated.some(r => r.source === 'camera')).toBe(true);
    expect(separated.some(r => r.source === 'imu')).toBe(true);
  });

  it('should calculate weighted average for multiple readings', () => {
    const now = Date.now();
    const readings: SensorReading[] = [
      { source: 'camera', timestamp: now, frequencyHz: 20, amplitude: 0.5, confidence: 1.0 },
      { source: 'camera', timestamp: now - 100, frequencyHz: 30, amplitude: 0.5, confidence: 1.0 },
    ];

    const separated = separateSignalSources(readings, 1000);
    const cameraResult = separated.find(r => r.source === 'camera');

    expect(cameraResult).toBeDefined();
    expect(cameraResult!.frequencyHz).toBe(25); // Average of 20 and 30
  });

  it('should handle empty input', () => {
    const separated = separateSignalSources([], 1000);
    expect(separated.length).toBe(0);
  });

  it('should filter out old readings', () => {
    // Use a timestamp that is definitely outside the window
    const veryOldTimestamp = Date.now() - 10000; // 10 seconds ago
    const readings: SensorReading[] = [
      { source: 'camera', timestamp: veryOldTimestamp, frequencyHz: 25, amplitude: 0.5, confidence: 0.8 },
    ];

    const separated = separateSignalSources(readings, 1000);
    expect(separated.length).toBe(0);
  });
});

// ============================================================================
// FUSION ENGINE TESTS
// ============================================================================

describe('FusionEngine', () => {
  let engine: FusionEngine;

  beforeEach(() => {
    engine = new FusionEngine();
  });

  it('should initialize with default configuration', () => {
    const config = engine.getConfig();
    expect(config.enabledSources).toEqual(['camera', 'imu']);
    expect(config.weights.camera).toBe(0.4);
    expect(config.weights.lidar).toBe(0.1);
  });

  it('should start and stop correctly', () => {
    expect(engine.isRunning()).toBe(false);
    engine.start();
    expect(engine.isRunning()).toBe(true);
    engine.stop();
    expect(engine.isRunning()).toBe(false);
  });

  it('should add valid readings to buffer', () => {
    engine.start();

    const reading: SensorReading = {
      source: 'camera',
      timestamp: Date.now(),
      frequencyHz: 25,
      amplitude: 0.5,
      confidence: 0.8,
    };

    engine.addReading(reading);
    const stats = engine.getSensorStats();
    expect(stats.camera.count).toBe(1);
  });

  it('should reject readings from disabled sources', () => {
    engine.setConfig({ enabledSources: ['imu'] }); // Disable camera
    engine.start();

    const reading: SensorReading = {
      source: 'camera',
      timestamp: Date.now(),
      frequencyHz: 25,
      amplitude: 0.5,
      confidence: 0.8,
    };

    engine.addReading(reading);
    const stats = engine.getSensorStats();
    expect(stats.camera.count).toBe(0);
  });

  it('should reject low confidence readings', () => {
    engine.start();

    const reading: SensorReading = {
      source: 'camera',
      timestamp: Date.now(),
      frequencyHz: 25,
      amplitude: 0.5,
      confidence: 0.1, // Below threshold (0.3)
    };

    engine.addReading(reading);
    const stats = engine.getSensorStats();
    expect(stats.camera.count).toBe(0);
  });

  it('should produce fusion result from multiple sensors', () => {
    engine.start();

    const now = Date.now();
    // Use frequencies within Nyquist limits (camera: 30Hz, IMU: 50Hz)
    engine.addReading({
      source: 'camera',
      timestamp: now,
      frequencyHz: 25, // Within camera 30 Hz limit
      amplitude: 0.5,
      confidence: 0.9,
    });
    engine.addReading({
      source: 'imu',
      timestamp: now,
      frequencyHz: 42, // Within IMU 50 Hz limit
      amplitude: 0.6,
      confidence: 0.8,
    });

    const result = engine.process();

    expect(result).not.toBeNull();
    expect(result!.fusedFrequencyHz).toBeGreaterThan(0);
    expect(result!.fusedAmplitude).toBeGreaterThanOrEqual(0);
    expect(result!.fusedAmplitude).toBeLessThanOrEqual(1);
    expect(result!.confidence).toBeGreaterThan(0);
  });

  it('should return null when not running', () => {
    const reading: SensorReading = {
      source: 'camera',
      timestamp: Date.now(),
      frequencyHz: 25,
      amplitude: 0.5,
      confidence: 0.8,
    };

    engine.addReading(reading);
    const result = engine.process();

    expect(result).toBeNull();
  });

  it('should apply user calibration to results', () => {
    engine.start();

    const calibration: UserCalibration = {
      userId: 'test',
      ageRange: '60+',
      bmiCategory: 'overweight',
      fatLayerMultiplier: 1.2,
      skinElasticityMultiplier: 0.8,
      calibratedAt: Date.now(),
    };

    engine.setUserCalibration(calibration);

    const now = Date.now();
    // Use IMU which supports up to 50 Hz (unlike camera which caps at 30 Hz)
    engine.addReading({
      source: 'imu',
      timestamp: now,
      frequencyHz: 40, // IMU supports up to 50 Hz
      amplitude: 0.5,
      confidence: 0.9,
    });

    const result = engine.process();
    expect(result).not.toBeNull();
    expect(result!.tissueEstimates.damping).toBeGreaterThan(1.0); // Higher damping for older, higher BMI
  });

  it('should reset all state', () => {
    engine.start();

    engine.addReading({
      source: 'camera',
      timestamp: Date.now(),
      frequencyHz: 40,
      amplitude: 0.5,
      confidence: 0.9,
    });

    engine.process();
    engine.reset();

    expect(engine.getLatestResult()).toBeNull();
    const stats = engine.getSensorStats();
    expect(stats.camera.count).toBe(0);
  });
});

// ============================================================================
// ORGAN RESONANCE TABLE TESTS
// ============================================================================

describe('Organ Resonance Table', () => {
  it('should have liver resonance data', () => {
    const liver = ORGAN_RESONANCE_TABLE.liver;
    expect(liver).toBeDefined();
    expect(liver.clinicalFrequencyHz).toBe(60);
    expect(liver.frequencyRangeHz).toEqual([50, 70]);
    expect(liver.pathologies).toContain('Fibrosis');
  });

  it('should have heart resonance data', () => {
    const heart = ORGAN_RESONANCE_TABLE.heart;
    expect(heart).toBeDefined();
    expect(heart.clinicalFrequencyHz).toBe(110);
    expect(heart.frequencyRangeHz).toEqual([80, 140]);
  });

  it('should have brain resonance data', () => {
    const brain = ORGAN_RESONANCE_TABLE.brain;
    expect(brain).toBeDefined();
    expect(brain.clinicalFrequencyHz).toBe(45);
    expect(brain.frequencyRangeHz).toEqual([25, 62.5]);
  });

  it('should have all organs with valid data', () => {
    const organs = Object.values(ORGAN_RESONANCE_TABLE);
    for (const organ of organs) {
      expect(organ.organ).toBeTruthy();
      expect(organ.clinicalFrequencyHz).toBeGreaterThan(0);
      expect(organ.frequencyRangeHz[0]).toBeLessThan(organ.frequencyRangeHz[1]);
      expect(organ.source).toBeTruthy();
    }
  });
});

// ============================================================================
// TISSUE ACOUSTIC PROPERTIES TESTS
// ============================================================================

describe('Tissue Acoustic Properties', () => {
  it('should have correct liver impedance', () => {
    const liver = TISSUE_ACOUSTIC_TABLE.liver;
    expect(liver.impedance).toBeCloseTo(1.65, 1);
  });

  it('should have vastly different air impedance', () => {
    const air = TISSUE_ACOUSTIC_TABLE.air;
    expect(air.impedance).toBeLessThan(0.001);
  });

  it('should calculate reflection coefficient correctly', () => {
    const skin = TISSUE_ACOUSTIC_TABLE.skin;
    const air = TISSUE_ACOUSTIC_TABLE.air;

    const reflection = calculateReflectionCoefficient(skin, air);
    // Nearly 100% reflection at skin-air boundary
    expect(reflection).toBeGreaterThan(0.99);
  });

  it('should calculate low reflection between similar tissues', () => {
    const liver = TISSUE_ACOUSTIC_TABLE.liver;
    const muscle = TISSUE_ACOUSTIC_TABLE.muscle;

    const reflection = calculateReflectionCoefficient(liver, muscle);
    // Very low reflection between similar impedances
    expect(reflection).toBeLessThan(0.01);
  });
});

// ============================================================================
// SENSOR CAPABILITIES CONSTANTS TESTS
// ============================================================================

describe('Sensor Capabilities', () => {
  it('should have correct LiDAR effective sampling rate (NOT 60Hz)', () => {
    // This is the critical finding from PMC10537187
    expect(LIDAR_CAPABILITIES.effectiveSamplingRateHz).toBe(15);
    expect(LIDAR_CAPABILITIES.maxDetectableFrequencyHz).toBe(7.5);
  });

  it('should have correct camera capabilities', () => {
    expect(CAMERA_CAPABILITIES.maxFps4K).toBe(60);
    expect(CAMERA_CAPABILITIES.maxDetectableFrequency4K).toBe(30);
    expect(CAMERA_CAPABILITIES.maxFps1080p).toBe(120);
    expect(CAMERA_CAPABILITIES.maxDetectableFrequency1080p).toBe(60);
  });

  it('should have correct IMU capabilities', () => {
    expect(IMU_CAPABILITIES.typicalSampleRateHz).toBe(100);
    expect(IMU_CAPABILITIES.maxDetectableFrequencyHz).toBe(50);
  });
});

// ============================================================================
// USER CALIBRATION TESTS
// ============================================================================

describe('User Calibration', () => {
  it('should return base damping for normal user', () => {
    const damping = calculateDampingCorrection(DEFAULT_USER_CALIBRATION);
    expect(damping).toBe(1.0);
  });

  it('should increase damping for older users', () => {
    const oldUser: UserCalibration = {
      ...DEFAULT_USER_CALIBRATION,
      ageRange: '60+',
    };
    const damping = calculateDampingCorrection(oldUser);
    expect(damping).toBeGreaterThan(1.0);
  });

  it('should increase damping for higher BMI', () => {
    const obeseUser: UserCalibration = {
      ...DEFAULT_USER_CALIBRATION,
      bmiCategory: 'obese',
    };
    const damping = calculateDampingCorrection(obeseUser);
    expect(damping).toBeGreaterThan(1.0);
  });

  it('should decrease damping for younger, underweight users', () => {
    const youngThinUser: UserCalibration = {
      ...DEFAULT_USER_CALIBRATION,
      ageRange: '18-30',
      bmiCategory: 'underweight',
    };
    const damping = calculateDampingCorrection(youngThinUser);
    expect(damping).toBeLessThan(1.0);
  });

  it('should apply fat layer multiplier', () => {
    const thickFatUser: UserCalibration = {
      ...DEFAULT_USER_CALIBRATION,
      fatLayerMultiplier: 1.5,
    };
    const damping = calculateDampingCorrection(thickFatUser);
    expect(damping).toBe(1.5);
  });
});

// ============================================================================
// PERFORMANCE TESTS
// ============================================================================

describe('Performance', () => {
  it('should process 100 readings in under 100ms', () => {
    const engine = new FusionEngine();
    engine.start();

    const start = performance.now();

    for (let i = 0; i < 100; i++) {
      // Use IMU which has 50Hz limit (camera is only 30Hz)
      engine.addReading({
        source: 'imu',
        timestamp: Date.now(),
        frequencyHz: 25 + Math.random() * 10, // 25-35 Hz range
        amplitude: 0.5,
        confidence: 0.8,
      });
    }
    engine.process();

    const duration = performance.now() - start;
    expect(duration).toBeLessThan(100);
  });

  it('should initialize Kalman filter quickly', () => {
    const start = performance.now();

    for (let i = 0; i < 1000; i++) {
      new KalmanFilter(40, 1, 0.01, 0.1);
    }

    const duration = performance.now() - start;
    expect(duration).toBeLessThan(50);
  });
});
