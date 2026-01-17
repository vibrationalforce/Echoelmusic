/**
 * CoherenceCore IMU Analyzer Hook
 *
 * Uses device accelerometer (expo-sensors) to detect micro-vibrations.
 * Complements EVM camera-based detection for sensor fusion.
 *
 * Connection: Both IMU and EVM detect the same physiological signals
 * (heartbeat, breathing) through different modalities:
 * - EVM: Optical detection of skin micro-motion via camera
 * - IMU: Inertial detection of body micro-motion via accelerometer
 *
 * Nyquist limit: 100Hz sample rate → max 50Hz detectable frequency
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import { useState, useCallback, useRef, useEffect } from 'react';
import { Platform } from 'react-native';
import {
  Accelerometer,
  AccelerometerMeasurement,
} from 'expo-sensors';
import { IMU_CAPABILITIES, validateNyquist } from '@coherence-core/shared-types';

// ============================================================================
// CONSTANTS
// ============================================================================

const SAMPLE_RATE_HZ = IMU_CAPABILITIES.typicalSampleRateHz; // 100 Hz
const UPDATE_INTERVAL_MS = 1000 / SAMPLE_RATE_HZ; // 10ms
const BUFFER_SIZE = 256; // FFT window size (2.56 seconds at 100Hz)
const FREQUENCY_RESOLUTION = SAMPLE_RATE_HZ / BUFFER_SIZE; // ~0.39 Hz

// Target frequency ranges for biometric signals
const HEART_RATE_RANGE_HZ = [0.8, 3.5] as const; // 48-210 BPM
const BREATHING_RANGE_HZ = [0.1, 0.5] as const; // 6-30 breaths/min

// ============================================================================
// TYPES
// ============================================================================

export interface IMUData {
  x: number;
  y: number;
  z: number;
  magnitude: number;
  timestamp: number;
}

export interface IMUAnalysisResult {
  // Detected frequencies from FFT analysis
  dominantFrequencies: number[];

  // Estimated biometric signals (if detected)
  estimatedHeartRateHz: number | null;
  estimatedBreathingRateHz: number | null;

  // Signal quality metrics
  signalQuality: number; // 0-1
  noiseLevel: number; // 0-1

  // Hardware info
  sampleRateHz: number;
  nyquistLimitHz: number;
  isNyquistValid: boolean;
}

export interface IMUAnalyzerState {
  isAvailable: boolean;
  isAnalyzing: boolean;
  permission: 'undetermined' | 'granted' | 'denied';
  currentData: IMUData | null;
  analysis: IMUAnalysisResult;
  bufferFillPercent: number;
}

// ============================================================================
// DEFAULT STATE
// ============================================================================

const createDefaultAnalysis = (): IMUAnalysisResult => ({
  dominantFrequencies: [],
  estimatedHeartRateHz: null,
  estimatedBreathingRateHz: null,
  signalQuality: 0,
  noiseLevel: 0,
  sampleRateHz: SAMPLE_RATE_HZ,
  nyquistLimitHz: IMU_CAPABILITIES.maxDetectableFrequencyHz,
  isNyquistValid: true,
});

const createDefaultState = (): IMUAnalyzerState => ({
  isAvailable: false,
  isAnalyzing: false,
  permission: 'undetermined',
  currentData: null,
  analysis: createDefaultAnalysis(),
  bufferFillPercent: 0,
});

// ============================================================================
// SIGNAL PROCESSING UTILITIES
// ============================================================================

/**
 * Compute magnitude from XYZ accelerometer data
 */
function computeMagnitude(x: number, y: number, z: number): number {
  return Math.sqrt(x * x + y * y + z * z);
}

/**
 * Remove DC offset (gravity) from signal using high-pass filter
 */
function removeGravity(buffer: number[], alpha: number = 0.1): number[] {
  const filtered: number[] = [];
  let baseline = buffer[0] || 0;

  for (let i = 0; i < buffer.length; i++) {
    // Exponential moving average for baseline
    baseline = alpha * buffer[i] + (1 - alpha) * baseline;
    // Remove baseline (high-pass filter)
    filtered.push(buffer[i] - baseline);
  }

  return filtered;
}

/**
 * Simple DFT-based frequency detection (no external FFT library needed)
 * Returns dominant frequencies in specified range
 */
function detectDominantFrequencies(
  signal: number[],
  sampleRate: number,
  minFreq: number,
  maxFreq: number,
  numPeaks: number = 3
): number[] {
  const n = signal.length;
  if (n < 32) return [];

  const nyquist = sampleRate / 2;
  const freqResolution = sampleRate / n;

  // Compute power spectrum using DFT (Goertzel-like approach for efficiency)
  const minBin = Math.floor(minFreq / freqResolution);
  const maxBin = Math.min(Math.ceil(maxFreq / freqResolution), Math.floor(n / 2));

  const spectrum: Array<{ freq: number; power: number }> = [];

  for (let k = minBin; k <= maxBin; k++) {
    const freq = k * freqResolution;
    let real = 0;
    let imag = 0;

    for (let t = 0; t < n; t++) {
      const angle = (2 * Math.PI * k * t) / n;
      real += signal[t] * Math.cos(angle);
      imag -= signal[t] * Math.sin(angle);
    }

    const power = (real * real + imag * imag) / (n * n);
    spectrum.push({ freq, power });
  }

  // Sort by power and extract top peaks
  spectrum.sort((a, b) => b.power - a.power);

  // Find peaks with minimum separation (0.5 Hz)
  const peaks: number[] = [];
  const minSeparation = 0.5;

  for (const { freq, power } of spectrum) {
    if (peaks.length >= numPeaks) break;

    // Check separation from existing peaks
    const isDistinct = peaks.every(p => Math.abs(p - freq) >= minSeparation);
    if (isDistinct && power > 0.0001) { // Minimum power threshold
      peaks.push(freq);
    }
  }

  return peaks.sort((a, b) => a - b);
}

/**
 * Estimate signal quality from variance and spectral characteristics
 */
function estimateSignalQuality(signal: number[]): number {
  if (signal.length < 32) return 0;

  // Compute variance
  const mean = signal.reduce((a, b) => a + b, 0) / signal.length;
  const variance = signal.reduce((sum, val) => sum + (val - mean) ** 2, 0) / signal.length;

  // Quality is higher when variance is in optimal range
  // Too low = no signal, too high = too much noise/movement
  const optimalVariance = 0.01; // Empirical value for micro-vibrations
  const quality = Math.exp(-Math.abs(Math.log10(variance / optimalVariance)));

  return Math.max(0, Math.min(1, quality));
}

/**
 * Estimate noise level from high-frequency content
 */
function estimateNoiseLevel(signal: number[], sampleRate: number): number {
  // Simple high-frequency energy estimation
  const highFreqThreshold = sampleRate / 4; // Above 25Hz for 100Hz sample rate

  // Compute high-frequency energy using difference filter (approximates derivative)
  let highFreqEnergy = 0;
  let totalEnergy = 0;

  for (let i = 1; i < signal.length; i++) {
    const diff = signal[i] - signal[i - 1];
    highFreqEnergy += diff * diff;
    totalEnergy += signal[i] * signal[i];
  }

  if (totalEnergy < 0.0001) return 0;

  return Math.min(1, highFreqEnergy / totalEnergy);
}

// ============================================================================
// HOOK
// ============================================================================

export function useIMUAnalyzer() {
  const [state, setState] = useState<IMUAnalyzerState>(createDefaultState);

  // Circular buffer for accelerometer magnitude samples
  const bufferRef = useRef<number[]>([]);
  const subscriptionRef = useRef<ReturnType<typeof Accelerometer.addListener> | null>(null);
  const analysisIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  useEffect(() => {
    // Check availability
    const checkAvailability = async () => {
      try {
        const available = await Accelerometer.isAvailableAsync();
        setState(prev => ({ ...prev, isAvailable: available }));

        if (available) {
          // Request permission
          const { status } = await Accelerometer.requestPermissionsAsync();
          setState(prev => ({
            ...prev,
            permission: status === 'granted' ? 'granted' : 'denied',
          }));
        }
      } catch (error) {
        console.error('[IMUAnalyzer] Availability check failed:', error);
        setState(prev => ({ ...prev, isAvailable: false }));
      }
    };

    checkAvailability();

    return () => {
      stopAnalysis();
    };
  }, []);

  // ============================================================================
  // ACCELEROMETER DATA HANDLER
  // ============================================================================

  const handleAccelerometerData = useCallback((data: AccelerometerMeasurement) => {
    const magnitude = computeMagnitude(data.x, data.y, data.z);
    const timestamp = Date.now();

    // Update current data
    setState(prev => ({
      ...prev,
      currentData: {
        x: data.x,
        y: data.y,
        z: data.z,
        magnitude,
        timestamp,
      },
    }));

    // Add to circular buffer
    bufferRef.current.push(magnitude);
    if (bufferRef.current.length > BUFFER_SIZE) {
      bufferRef.current.shift();
    }

    // Update buffer fill percentage
    setState(prev => ({
      ...prev,
      bufferFillPercent: (bufferRef.current.length / BUFFER_SIZE) * 100,
    }));
  }, []);

  // ============================================================================
  // ANALYSIS LOOP
  // ============================================================================

  const runAnalysis = useCallback(() => {
    const buffer = bufferRef.current;

    if (buffer.length < BUFFER_SIZE / 2) {
      // Not enough data yet
      return;
    }

    // Remove gravity/DC offset
    const filtered = removeGravity(buffer);

    // Detect dominant frequencies in biometric ranges
    const heartFreqs = detectDominantFrequencies(
      filtered,
      SAMPLE_RATE_HZ,
      HEART_RATE_RANGE_HZ[0],
      HEART_RATE_RANGE_HZ[1],
      2
    );

    const breathFreqs = detectDominantFrequencies(
      filtered,
      SAMPLE_RATE_HZ,
      BREATHING_RANGE_HZ[0],
      BREATHING_RANGE_HZ[1],
      1
    );

    // Combine all detected frequencies
    const allFreqs = [...new Set([...heartFreqs, ...breathFreqs])].sort((a, b) => a - b);

    // Estimate biometric signals
    const estimatedHeartRateHz = heartFreqs.length > 0 ? heartFreqs[0] : null;
    const estimatedBreathingRateHz = breathFreqs.length > 0 ? breathFreqs[0] : null;

    // Compute quality metrics
    const signalQuality = estimateSignalQuality(filtered);
    const noiseLevel = estimateNoiseLevel(filtered, SAMPLE_RATE_HZ);

    // Validate Nyquist for heart rate detection
    const nyquistValidation = validateNyquist(HEART_RATE_RANGE_HZ[1], SAMPLE_RATE_HZ);

    // Update state
    setState(prev => ({
      ...prev,
      analysis: {
        dominantFrequencies: allFreqs,
        estimatedHeartRateHz,
        estimatedBreathingRateHz,
        signalQuality,
        noiseLevel,
        sampleRateHz: SAMPLE_RATE_HZ,
        nyquistLimitHz: IMU_CAPABILITIES.maxDetectableFrequencyHz,
        isNyquistValid: nyquistValidation.isValid,
      },
    }));
  }, []);

  // ============================================================================
  // START/STOP ANALYSIS
  // ============================================================================

  const startAnalysis = useCallback(async (): Promise<boolean> => {
    if (state.isAnalyzing) {
      console.log('[IMUAnalyzer] Already analyzing');
      return true;
    }

    if (!state.isAvailable) {
      console.error('[IMUAnalyzer] Accelerometer not available');
      return false;
    }

    if (state.permission !== 'granted') {
      console.error('[IMUAnalyzer] Permission not granted');
      return false;
    }

    console.log('[IMUAnalyzer] Starting analysis...');

    try {
      // Set update interval for high-frequency sampling
      await Accelerometer.setUpdateInterval(UPDATE_INTERVAL_MS);

      // Clear buffer
      bufferRef.current = [];

      // Subscribe to accelerometer data
      subscriptionRef.current = Accelerometer.addListener(handleAccelerometerData);

      // Start analysis loop (run every 500ms for smoother updates)
      analysisIntervalRef.current = setInterval(runAnalysis, 500);

      setState(prev => ({
        ...prev,
        isAnalyzing: true,
        bufferFillPercent: 0,
        analysis: createDefaultAnalysis(),
      }));

      console.log('[IMUAnalyzer] Analysis started');
      return true;
    } catch (error) {
      console.error('[IMUAnalyzer] Failed to start:', error);
      return false;
    }
  }, [state.isAvailable, state.isAnalyzing, state.permission, handleAccelerometerData, runAnalysis]);

  const stopAnalysis = useCallback(() => {
    console.log('[IMUAnalyzer] Stopping analysis...');

    // Remove accelerometer listener
    if (subscriptionRef.current) {
      subscriptionRef.current.remove();
      subscriptionRef.current = null;
    }

    // Stop analysis loop
    if (analysisIntervalRef.current) {
      clearInterval(analysisIntervalRef.current);
      analysisIntervalRef.current = null;
    }

    setState(prev => ({
      ...prev,
      isAnalyzing: false,
    }));

    console.log('[IMUAnalyzer] Analysis stopped');
  }, []);

  const toggleAnalysis = useCallback(async () => {
    if (state.isAnalyzing) {
      stopAnalysis();
    } else {
      await startAnalysis();
    }
  }, [state.isAnalyzing, startAnalysis, stopAnalysis]);

  // ============================================================================
  // RETURN
  // ============================================================================

  return {
    // State
    ...state,

    // Actions
    startAnalysis,
    stopAnalysis,
    toggleAnalysis,

    // Constants
    capabilities: IMU_CAPABILITIES,
    frequencyRanges: {
      heartRate: HEART_RATE_RANGE_HZ,
      breathing: BREATHING_RANGE_HZ,
    },
  };
}

export default useIMUAnalyzer;
