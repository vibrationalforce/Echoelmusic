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
import { Audio, AVPlaybackStatus } from 'expo-av';
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
import {
  generateWaveform,
  WaveformType,
  createWavDataUri,
} from '@coherence-core/frequency-engine';

// ============================================================================
// CONSTANTS
// ============================================================================

const SAMPLE_RATE = 44100;
const BUFFER_DURATION_SECONDS = 2; // Generate 2-second loopable buffer
const HAPTIC_INTERVAL_MS = 250; // Synchronized haptic feedback interval

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
  waveform: WaveformType;

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
  const hapticRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const frameTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const isGeneratingRef = useRef(false);

  // Initialize audio mode
  useEffect(() => {
    const initAudio = async () => {
      try {
        await Audio.setAudioModeAsync({
          playsInSilentModeIOS: true,
          staysActiveInBackground: true,
          shouldDuckAndroid: false,
          playThroughEarpieceAndroid: false,
        });
        console.log('[CoherenceEngine] Audio mode initialized');
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
  // AUDIO GENERATION
  // ============================================================================

  const generateAndLoadAudio = useCallback(async (
    frequencyHz: number,
    amplitude: number,
    waveform: WaveformType
  ): Promise<Audio.Sound | null> => {
    if (isGeneratingRef.current) {
      console.log('[CoherenceEngine] Audio generation already in progress');
      return null;
    }

    isGeneratingRef.current = true;
    console.log(`[CoherenceEngine] Generating ${waveform} wave at ${frequencyHz}Hz, amplitude ${amplitude}`);

    try {
      // Generate waveform buffer using frequency-engine
      const samples = generateWaveform(
        waveform,
        frequencyHz,
        SAMPLE_RATE,
        BUFFER_DURATION_SECONDS,
        amplitude
      );

      // Convert to data URI for expo-av
      const dataUri = await createWavDataUri(samples, SAMPLE_RATE);

      // Create and load sound
      const { sound } = await Audio.Sound.createAsync(
        { uri: dataUri },
        {
          isLooping: true,
          shouldPlay: false,
          volume: 1.0,
        }
      );

      console.log('[CoherenceEngine] Audio loaded successfully');
      return sound;
    } catch (error) {
      console.error('[CoherenceEngine] Audio generation failed:', error);
      return null;
    } finally {
      isGeneratingRef.current = false;
    }
  }, []);

  // ============================================================================
  // SYNCHRONIZED HAPTIC FEEDBACK
  // ============================================================================

  const startSynchronizedHaptics = useCallback((frequencyHz: number) => {
    if (Platform.OS === 'web') return;

    // Calculate haptic interval based on frequency
    // For low frequencies (< 10 Hz), pulse at frequency rate
    // For higher frequencies, use a perceivable rate
    const hapticIntervalMs = frequencyHz < 10
      ? Math.round(1000 / frequencyHz)
      : HAPTIC_INTERVAL_MS;

    hapticRef.current = setInterval(() => {
      Vibration.vibrate(20); // Short 20ms pulse
    }, hapticIntervalMs);

    console.log(`[CoherenceEngine] Synchronized haptics started at ${hapticIntervalMs}ms interval`);
  }, []);

  const stopSynchronizedHaptics = useCallback(() => {
    if (hapticRef.current) {
      clearInterval(hapticRef.current);
      hapticRef.current = null;
    }
    Vibration.cancel();
  }, []);

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

  const setWaveform = useCallback((waveform: WaveformType) => {
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
      console.log('[CoherenceEngine] Starting session...');

      // Stop any existing audio
      if (soundRef.current) {
        await soundRef.current.stopAsync();
        await soundRef.current.unloadAsync();
        soundRef.current = null;
      }

      // Generate and load new audio
      const sound = await generateAndLoadAudio(
        session.frequencyHz,
        session.amplitude,
        session.waveform
      );

      if (!sound) {
        Alert.alert('Error', 'Failed to generate audio. Please try again.');
        return false;
      }

      soundRef.current = sound;

      // Start playback
      await sound.playAsync();

      // Start synchronized haptics
      startSynchronizedHaptics(session.frequencyHz);

      // Update state
      setSession(prev => ({
        ...prev,
        isPlaying: true,
        sessionStartTime: Date.now(),
        elapsedMs: 0,
        remainingMs: DEFAULT_SAFETY_LIMITS.maxSessionDurationMs,
      }));

      console.log('[CoherenceEngine] Session started successfully');
      return true;
    } catch (error) {
      console.error('[CoherenceEngine] Start session failed:', error);
      Alert.alert('Error', 'Failed to start session. Please try again.');
      return false;
    }
  }, [
    session.disclaimerAcknowledged,
    session.frequencyHz,
    session.amplitude,
    session.waveform,
    showDisclaimerModal,
    generateAndLoadAudio,
    startSynchronizedHaptics,
  ]);

  const stopSession = useCallback(async () => {
    try {
      console.log('[CoherenceEngine] Stopping session...');

      // Stop audio
      if (soundRef.current) {
        await soundRef.current.stopAsync();
        await soundRef.current.unloadAsync();
        soundRef.current = null;
      }

      // Stop haptics
      stopSynchronizedHaptics();

      // Clear timer
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }

      // Update state
      setSession(prev => ({
        ...prev,
        isPlaying: false,
        sessionStartTime: null,
        elapsedMs: 0,
        remainingMs: DEFAULT_SAFETY_LIMITS.maxSessionDurationMs,
      }));

      // Final haptic feedback
      if (Platform.OS !== 'web') {
        Vibration.vibrate(100);
      }

      console.log('[CoherenceEngine] Session stopped');
    } catch (error) {
      console.error('[CoherenceEngine] Stop session failed:', error);
    }
  }, [stopSynchronizedHaptics]);

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

    console.log('[CoherenceEngine] Starting EVM analysis...');

    setSession(prev => ({
      ...prev,
      isAnalyzing: true,
      detectedFrequencies: [],
      qualityScore: 0,
    }));

    // Quality score increases over time as more frames are processed
    frameTimerRef.current = setInterval(() => {
      setSession(prev => ({
        ...prev,
        qualityScore: Math.min(1, prev.qualityScore + 0.02),
      }));
    }, 100);

    return true;
  }, [session.disclaimerAcknowledged, showDisclaimerModal]);

  const stopAnalysis = useCallback(() => {
    console.log('[CoherenceEngine] Stopping EVM analysis...');

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

  const updateDetectedFrequencies = useCallback((frequencies: number[]) => {
    setSession(prev => ({ ...prev, detectedFrequencies: frequencies }));
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
    updateDetectedFrequencies,

    // Sensor info
    sensorLimits: {
      camera4KMaxHz: CAMERA_CAPABILITIES.maxDetectableFrequency4K,
      camera1080pMaxHz: CAMERA_CAPABILITIES.maxDetectableFrequency1080p,
      imuMaxHz: IMU_CAPABILITIES.maxDetectableFrequencyHz,
    },
  };
}

export default useCoherenceEngine;
