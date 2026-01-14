/**
 * CoherenceCore Engine Hook
 *
 * Provides unified access to frequency generation, EVM analysis, and sensor fusion.
 * Manages session state, safety limits, and disclaimer acknowledgment.
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import { useState, useCallback, useRef, useEffect } from 'react';
import { Alert, Platform, Vibration } from 'react-native';
import { Audio } from 'expo-av';
import {
  FREQUENCY_PRESETS,
  DEFAULT_SAFETY_LIMITS,
  DEFAULT_EVM_CONFIG,
  FrequencyPresetId,
  DISCLAIMER_TEXT,
  validateNyquist,
  CAMERA_CAPABILITIES,
  IMU_CAPABILITIES,
} from '@coherence-core/shared-types';

// ============================================================================
// TYPES
// ============================================================================

export interface SessionState {
  // Playback state
  isPlaying: boolean;
  sessionStartTime: number | null;
  elapsedMs: number;
  remainingMs: number;

  // Frequency settings
  currentPreset: FrequencyPresetId;
  frequencyHz: number;
  amplitude: number;
  waveform: 'sine' | 'square' | 'triangle' | 'sawtooth';

  // EVM analysis
  isAnalyzing: boolean;
  detectedFrequencies: number[];
  qualityScore: number;
  frameRate: number;
  nyquistValid: boolean;

  // Compliance
  disclaimerAcknowledged: boolean;
}

export interface CoherenceEngineState {
  session: SessionState;
  safetyLimits: typeof DEFAULT_SAFETY_LIMITS;
  evmConfig: typeof DEFAULT_EVM_CONFIG;
}

// ============================================================================
// DEFAULT STATE
// ============================================================================

const createDefaultSession = (): SessionState => ({
  isPlaying: false,
  sessionStartTime: null,
  elapsedMs: 0,
  remainingMs: DEFAULT_SAFETY_LIMITS.maxSessionDurationMs,
  currentPreset: 'osteo-sync',
  frequencyHz: FREQUENCY_PRESETS['osteo-sync'].primaryFrequencyHz,
  amplitude: 0.5,
  waveform: 'sine',
  isAnalyzing: false,
  detectedFrequencies: [],
  qualityScore: 0,
  frameRate: 30,
  nyquistValid: false,
  disclaimerAcknowledged: false,
});

// ============================================================================
// HOOK
// ============================================================================

export function useCoherenceEngine() {
  const [session, setSession] = useState<SessionState>(createDefaultSession);
  const soundRef = useRef<Audio.Sound | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const frameTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Initialize audio mode
  useEffect(() => {
    const initAudio = async () => {
      try {
        await Audio.setAudioModeAsync({
          playsInSilentModeIOS: true,
          staysActiveInBackground: true,
          shouldDuckAndroid: false,
        });
      } catch (error) {
        console.error('[CoherenceEngine] Audio init failed:', error);
      }
    };
    initAudio();

    return () => {
      stopSession();
      stopAnalysis();
    };
  }, []);

  // Session timer effect
  useEffect(() => {
    if (session.isPlaying && session.sessionStartTime) {
      timerRef.current = setInterval(() => {
        const elapsed = Date.now() - session.sessionStartTime!;
        const remaining = DEFAULT_SAFETY_LIMITS.maxSessionDurationMs - elapsed;

        if (remaining <= 0) {
          // Safety cutoff reached
          stopSession();
          Alert.alert(
            'Session Complete',
            'Maximum session duration of 15 minutes reached. Please take a break before starting another session.',
            [{ text: 'OK' }]
          );
          return;
        }

        setSession(prev => ({
          ...prev,
          elapsedMs: elapsed,
          remainingMs: remaining,
        }));
      }, 1000);
    }

    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
    };
  }, [session.isPlaying, session.sessionStartTime]);

  // Nyquist validation for frame rate
  useEffect(() => {
    const maxTargetFreq = DEFAULT_EVM_CONFIG.frequencyRangeHz[1];
    const validation = validateNyquist(maxTargetFreq, session.frameRate);
    setSession(prev => ({
      ...prev,
      nyquistValid: validation.isValid,
    }));
  }, [session.frameRate]);

  // ============================================================================
  // DISCLAIMER
  // ============================================================================

  const showDisclaimerModal = useCallback(() => {
    return new Promise<boolean>((resolve) => {
      Alert.alert(
        'Wellness Tool Disclaimer',
        `${DISCLAIMER_TEXT}\n\nThis application is designed for wellness and informational purposes only. It is NOT a medical device and should not be used to diagnose, treat, cure, or prevent any disease or health condition.\n\nBy proceeding, you acknowledge that:\n• You have read and understood this disclaimer\n• You will not use this tool as a substitute for professional medical advice\n• You will stop use immediately if you experience any discomfort`,
        [
          {
            text: 'Cancel',
            style: 'cancel',
            onPress: () => resolve(false),
          },
          {
            text: 'I Understand',
            onPress: () => {
              setSession(prev => ({ ...prev, disclaimerAcknowledged: true }));
              resolve(true);
            },
          },
        ]
      );
    });
  }, []);

  // ============================================================================
  // PRESET MANAGEMENT
  // ============================================================================

  const selectPreset = useCallback((presetId: FrequencyPresetId) => {
    const preset = FREQUENCY_PRESETS[presetId];
    if (!preset) return;

    setSession(prev => ({
      ...prev,
      currentPreset: presetId,
      frequencyHz: preset.primaryFrequencyHz,
    }));

    // Haptic feedback
    if (Platform.OS !== 'web') {
      Vibration.vibrate(10);
    }
  }, []);

  // ============================================================================
  // FREQUENCY/AMPLITUDE CONTROL
  // ============================================================================

  const setFrequency = useCallback((hz: number) => {
    setSession(prev => {
      const preset = FREQUENCY_PRESETS[prev.currentPreset];
      const clamped = Math.max(
        preset.frequencyRangeHz[0],
        Math.min(preset.frequencyRangeHz[1], hz)
      );
      return { ...prev, frequencyHz: clamped };
    });
  }, []);

  const setAmplitude = useCallback((amp: number) => {
    const safeAmp = Math.max(0, Math.min(DEFAULT_SAFETY_LIMITS.maxAmplitude, amp));
    setSession(prev => ({ ...prev, amplitude: safeAmp }));
  }, []);

  const setWaveform = useCallback((waveform: SessionState['waveform']) => {
    setSession(prev => ({ ...prev, waveform }));
    if (Platform.OS !== 'web') {
      Vibration.vibrate(10);
    }
  }, []);

  // ============================================================================
  // SESSION CONTROL
  // ============================================================================

  const startSession = useCallback(async () => {
    // Check disclaimer
    if (!session.disclaimerAcknowledged) {
      const accepted = await showDisclaimerModal();
      if (!accepted) return false;
    }

    try {
      /**
       * NOTE: In a production implementation, we would:
       * 1. Import FrequencyEngine from @coherence-core/frequency-engine
       * 2. Generate audio buffer: engine.generateBuffer(44100, 60)
       * 3. Convert to base64 and load with expo-av
       *
       * For now, we simulate the session state management.
       * The actual audio generation would require native module integration.
       */

      setSession(prev => ({
        ...prev,
        isPlaying: true,
        sessionStartTime: Date.now(),
        elapsedMs: 0,
        remainingMs: DEFAULT_SAFETY_LIMITS.maxSessionDurationMs,
      }));

      // Haptic feedback
      if (Platform.OS !== 'web') {
        Vibration.vibrate([0, 50, 50, 50]);
      }

      return true;
    } catch (error) {
      console.error('[CoherenceEngine] Start session failed:', error);
      Alert.alert('Error', 'Failed to start session');
      return false;
    }
  }, [session.disclaimerAcknowledged, showDisclaimerModal]);

  const stopSession = useCallback(async () => {
    try {
      if (soundRef.current) {
        await soundRef.current.stopAsync();
        await soundRef.current.unloadAsync();
        soundRef.current = null;
      }

      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }

      setSession(prev => ({
        ...prev,
        isPlaying: false,
        sessionStartTime: null,
        elapsedMs: 0,
        remainingMs: DEFAULT_SAFETY_LIMITS.maxSessionDurationMs,
      }));

      if (Platform.OS !== 'web') {
        Vibration.vibrate(100);
      }
    } catch (error) {
      console.error('[CoherenceEngine] Stop session failed:', error);
    }
  }, []);

  const toggleSession = useCallback(async () => {
    if (session.isPlaying) {
      await stopSession();
    } else {
      await startSession();
    }
  }, [session.isPlaying, startSession, stopSession]);

  // ============================================================================
  // EVM ANALYSIS
  // ============================================================================

  const startAnalysis = useCallback(async () => {
    // Check disclaimer
    if (!session.disclaimerAcknowledged) {
      const accepted = await showDisclaimerModal();
      if (!accepted) return false;
    }

    /**
     * NOTE: In production, we would:
     * 1. Import EVMEngine from @coherence-core/evm-engine
     * 2. Get camera frames via expo-camera
     * 3. Process frames through engine.processFrame()
     * 4. Update detectedFrequencies from results
     *
     * Current implementation simulates analysis state.
     */

    setSession(prev => ({
      ...prev,
      isAnalyzing: true,
      detectedFrequencies: [],
      qualityScore: 0,
    }));

    // Simulate frame rate updates
    frameTimerRef.current = setInterval(() => {
      setSession(prev => ({
        ...prev,
        // Simulated quality score increases over time
        qualityScore: Math.min(1, prev.qualityScore + 0.05),
      }));
    }, 500);

    return true;
  }, [session.disclaimerAcknowledged, showDisclaimerModal]);

  const stopAnalysis = useCallback(() => {
    if (frameTimerRef.current) {
      clearInterval(frameTimerRef.current);
      frameTimerRef.current = null;
    }

    setSession(prev => ({
      ...prev,
      isAnalyzing: false,
    }));
  }, []);

  const toggleAnalysis = useCallback(async () => {
    if (session.isAnalyzing) {
      stopAnalysis();
    } else {
      await startAnalysis();
    }
  }, [session.isAnalyzing, startAnalysis, stopAnalysis]);

  const updateFrameRate = useCallback((fps: number) => {
    setSession(prev => ({ ...prev, frameRate: Math.round(fps) }));
  }, []);

  // ============================================================================
  // RETURN
  // ============================================================================

  return {
    // State
    session,
    safetyLimits: DEFAULT_SAFETY_LIMITS,
    evmConfig: DEFAULT_EVM_CONFIG,
    presets: FREQUENCY_PRESETS,

    // Disclaimer
    showDisclaimerModal,

    // Preset management
    selectPreset,

    // Frequency control
    setFrequency,
    setAmplitude,
    setWaveform,

    // Session control
    startSession,
    stopSession,
    toggleSession,

    // EVM analysis
    startAnalysis,
    stopAnalysis,
    toggleAnalysis,
    updateFrameRate,

    // Sensor info
    sensorLimits: {
      camera4KMaxHz: CAMERA_CAPABILITIES.maxDetectableFrequency4K,
      camera1080pMaxHz: CAMERA_CAPABILITIES.maxDetectableFrequency1080p,
      imuMaxHz: IMU_CAPABILITIES.maxDetectableFrequencyHz,
    },
  };
}

export default useCoherenceEngine;
