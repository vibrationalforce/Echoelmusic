/**
 * CoherenceCore Stimulate Screen
 *
 * VAT (Vibroacoustic Therapy) audio output with frequency presets,
 * amplitude control, and session timer with safety cutoff.
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Platform,
  Vibration,
  Alert,
} from 'react-native';
import Slider from '@react-native-community/slider';
import { router } from 'expo-router';
import { Audio } from 'expo-av';
import {
  FREQUENCY_PRESETS,
  DEFAULT_SAFETY_LIMITS,
  DISCLAIMER_TEXT,
  FrequencyPresetId,
} from '@coherence-core/shared-types';

// Session state
interface SessionState {
  isPlaying: boolean;
  currentPreset: FrequencyPresetId;
  frequency: number;
  amplitude: number;
  waveform: 'sine' | 'square' | 'triangle';
  sessionStartTime: number | null;
  elapsedMs: number;
  remainingMs: number;
}

// Preset card component
interface PresetCardProps {
  preset: typeof FREQUENCY_PRESETS[FrequencyPresetId];
  isSelected: boolean;
  onSelect: () => void;
}

const PresetCard: React.FC<PresetCardProps> = ({ preset, isSelected, onSelect }) => (
  <TouchableOpacity
    style={[styles.presetCard, isSelected && styles.presetCardSelected]}
    onPress={onSelect}
  >
    <Text style={[styles.presetName, isSelected && styles.presetNameSelected]}>
      {preset.name}
    </Text>
    <Text style={styles.presetFrequency}>
      {preset.frequencyRangeHz[0]}-{preset.frequencyRangeHz[1]} Hz
    </Text>
    <Text style={styles.presetDescription} numberOfLines={2}>
      {preset.description}
    </Text>
    <Text style={styles.presetResearch} numberOfLines={1}>
      {preset.research}
    </Text>
  </TouchableOpacity>
);

// Format time as MM:SS
const formatTime = (ms: number): string => {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
};

export default function StimulateScreen() {
  const [session, setSession] = useState<SessionState>({
    isPlaying: false,
    currentPreset: 'osteo-sync',
    frequency: FREQUENCY_PRESETS['osteo-sync'].primaryFrequencyHz,
    amplitude: 0.5,
    waveform: 'sine',
    sessionStartTime: null,
    elapsedMs: 0,
    remainingMs: DEFAULT_SAFETY_LIMITS.maxSessionDurationMs,
  });

  const soundRef = useRef<Audio.Sound | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Setup audio
  useEffect(() => {
    const setupAudio = async () => {
      try {
        await Audio.setAudioModeAsync({
          playsInSilentModeIOS: true,
          staysActiveInBackground: true,
          shouldDuckAndroid: false,
        });
      } catch (error) {
        console.error('Failed to setup audio:', error);
      }
    };
    setupAudio();

    return () => {
      stopSession();
    };
  }, []);

  // Session timer
  useEffect(() => {
    if (session.isPlaying && session.sessionStartTime) {
      timerRef.current = setInterval(() => {
        const elapsed = Date.now() - session.sessionStartTime!;
        const remaining = DEFAULT_SAFETY_LIMITS.maxSessionDurationMs - elapsed;

        if (remaining <= 0) {
          // Safety cutoff
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
      }
    };
  }, [session.isPlaying, session.sessionStartTime]);

  // Select preset
  const selectPreset = useCallback((presetId: FrequencyPresetId) => {
    const preset = FREQUENCY_PRESETS[presetId];
    setSession(prev => ({
      ...prev,
      currentPreset: presetId,
      frequency: preset.primaryFrequencyHz,
    }));

    // Haptic feedback
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      Vibration.vibrate(10);
    }
  }, []);

  // Start session
  const startSession = useCallback(async () => {
    try {
      // In a real implementation, we would generate and play the audio
      // For now, we'll just simulate the session
      setSession(prev => ({
        ...prev,
        isPlaying: true,
        sessionStartTime: Date.now(),
        elapsedMs: 0,
        remainingMs: DEFAULT_SAFETY_LIMITS.maxSessionDurationMs,
      }));

      // Haptic feedback to indicate start
      if (Platform.OS === 'ios' || Platform.OS === 'android') {
        Vibration.vibrate([0, 50, 50, 50]);
      }
    } catch (error) {
      console.error('Failed to start session:', error);
      Alert.alert('Error', 'Failed to start audio session');
    }
  }, [session.frequency, session.amplitude, session.waveform]);

  // Stop session
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

      // Haptic feedback to indicate stop
      if (Platform.OS === 'ios' || Platform.OS === 'android') {
        Vibration.vibrate(100);
      }
    } catch (error) {
      console.error('Failed to stop session:', error);
    }
  }, []);

  // Toggle session
  const toggleSession = useCallback(() => {
    if (session.isPlaying) {
      stopSession();
    } else {
      startSession();
    }
  }, [session.isPlaying, startSession, stopSession]);

  // Update frequency
  const updateFrequency = useCallback((value: number) => {
    const preset = FREQUENCY_PRESETS[session.currentPreset];
    const clampedValue = Math.max(
      preset.frequencyRangeHz[0],
      Math.min(preset.frequencyRangeHz[1], value)
    );
    setSession(prev => ({
      ...prev,
      frequency: clampedValue,
    }));
  }, [session.currentPreset]);

  // Update amplitude (with safety limit)
  const updateAmplitude = useCallback((value: number) => {
    const safeValue = Math.min(value, DEFAULT_SAFETY_LIMITS.maxAmplitude);
    setSession(prev => ({
      ...prev,
      amplitude: safeValue,
    }));
  }, []);

  // Update waveform
  const updateWaveform = useCallback((waveform: 'sine' | 'square' | 'triangle') => {
    setSession(prev => ({
      ...prev,
      waveform,
    }));

    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      Vibration.vibrate(10);
    }
  }, []);

  const currentPreset = FREQUENCY_PRESETS[session.currentPreset];

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity style={styles.backButton} onPress={() => router.back()}>
          <Text style={styles.backButtonText}>← Back</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Stimulate</Text>
        <View style={styles.placeholder} />
      </View>

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Session Timer */}
        <View style={styles.timerContainer}>
          <View style={styles.timerCircle}>
            <Text style={styles.timerLabel}>
              {session.isPlaying ? 'Remaining' : 'Session'}
            </Text>
            <Text style={styles.timerValue}>
              {formatTime(session.isPlaying ? session.remainingMs : DEFAULT_SAFETY_LIMITS.maxSessionDurationMs)}
            </Text>
            {session.isPlaying && (
              <Text style={styles.timerElapsed}>
                Elapsed: {formatTime(session.elapsedMs)}
              </Text>
            )}
          </View>
        </View>

        {/* Presets */}
        <Text style={styles.sectionTitle}>Frequency Presets</Text>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.presetsContainer}
        >
          {(Object.keys(FREQUENCY_PRESETS) as FrequencyPresetId[])
            .filter(id => id !== 'custom')
            .map(presetId => (
              <PresetCard
                key={presetId}
                preset={FREQUENCY_PRESETS[presetId]}
                isSelected={session.currentPreset === presetId}
                onSelect={() => selectPreset(presetId)}
              />
            ))}
        </ScrollView>

        {/* Frequency Control */}
        <View style={styles.controlSection}>
          <View style={styles.controlHeader}>
            <Text style={styles.controlLabel}>Frequency</Text>
            <Text style={styles.controlValue}>{session.frequency.toFixed(1)} Hz</Text>
          </View>
          <Slider
            style={styles.slider}
            minimumValue={currentPreset.frequencyRangeHz[0]}
            maximumValue={currentPreset.frequencyRangeHz[1]}
            value={session.frequency}
            onValueChange={updateFrequency}
            minimumTrackTintColor="#00E5FF"
            maximumTrackTintColor="#333"
            thumbTintColor="#00E5FF"
            disabled={session.isPlaying}
          />
          <View style={styles.sliderLabels}>
            <Text style={styles.sliderLabel}>{currentPreset.frequencyRangeHz[0]} Hz</Text>
            <Text style={styles.sliderLabel}>{currentPreset.frequencyRangeHz[1]} Hz</Text>
          </View>
        </View>

        {/* Amplitude Control */}
        <View style={styles.controlSection}>
          <View style={styles.controlHeader}>
            <Text style={styles.controlLabel}>Amplitude</Text>
            <Text style={styles.controlValue}>
              {Math.round(session.amplitude * 100)}%
            </Text>
          </View>
          <Slider
            style={styles.slider}
            minimumValue={0}
            maximumValue={DEFAULT_SAFETY_LIMITS.maxAmplitude}
            value={session.amplitude}
            onValueChange={updateAmplitude}
            minimumTrackTintColor="#00E5FF"
            maximumTrackTintColor="#333"
            thumbTintColor="#00E5FF"
          />
          <View style={styles.sliderLabels}>
            <Text style={styles.sliderLabel}>0%</Text>
            <Text style={styles.sliderLabel}>
              {Math.round(DEFAULT_SAFETY_LIMITS.maxAmplitude * 100)}% max
            </Text>
          </View>
        </View>

        {/* Waveform Selection */}
        <View style={styles.controlSection}>
          <Text style={styles.controlLabel}>Waveform</Text>
          <View style={styles.waveformButtons}>
            {(['sine', 'square', 'triangle'] as const).map(waveform => (
              <TouchableOpacity
                key={waveform}
                style={[
                  styles.waveformButton,
                  session.waveform === waveform && styles.waveformButtonSelected,
                ]}
                onPress={() => updateWaveform(waveform)}
                disabled={session.isPlaying}
              >
                <Text
                  style={[
                    styles.waveformButtonText,
                    session.waveform === waveform && styles.waveformButtonTextSelected,
                  ]}
                >
                  {waveform.charAt(0).toUpperCase() + waveform.slice(1)}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Current Preset Info */}
        <View style={styles.infoSection}>
          <Text style={styles.infoTitle}>{currentPreset.name}</Text>
          <Text style={styles.infoDescription}>{currentPreset.description}</Text>
          <Text style={styles.infoResearch}>{currentPreset.research}</Text>
          <Text style={styles.infoTarget}>Target: {currentPreset.target}</Text>
        </View>

        {/* Safety Info */}
        <View style={styles.safetyInfo}>
          <Text style={styles.safetyTitle}>Safety Limits</Text>
          <Text style={styles.safetyText}>
            • Max session: {DEFAULT_SAFETY_LIMITS.maxSessionDurationMs / 60000} minutes
          </Text>
          <Text style={styles.safetyText}>
            • Max amplitude: {Math.round(DEFAULT_SAFETY_LIMITS.maxAmplitude * 100)}%
          </Text>
          <Text style={styles.safetyText}>
            • Max duty cycle: {Math.round(DEFAULT_SAFETY_LIMITS.maxDutyCycle * 100)}%
          </Text>
        </View>

        {/* Spacer for button */}
        <View style={{ height: 100 }} />
      </ScrollView>

      {/* Play/Stop Button */}
      <View style={styles.buttonContainer}>
        <TouchableOpacity
          style={[styles.playButton, session.isPlaying && styles.stopButton]}
          onPress={toggleSession}
        >
          <Text style={styles.playButtonText}>
            {session.isPlaying ? 'Stop Session' : 'Start Session'}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Disclaimer */}
      <View style={styles.disclaimerContainer}>
        <Text style={styles.disclaimer}>{DISCLAIMER_TEXT}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: Platform.OS === 'ios' ? 60 : 40,
    paddingHorizontal: 20,
    paddingBottom: 15,
  },
  backButton: {
    padding: 10,
  },
  backButtonText: {
    color: '#00E5FF',
    fontSize: 16,
    fontWeight: '600',
  },
  title: {
    color: '#fff',
    fontSize: 20,
    fontWeight: 'bold',
  },
  placeholder: {
    width: 60,
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
  },
  timerContainer: {
    alignItems: 'center',
    marginVertical: 20,
  },
  timerCircle: {
    width: 180,
    height: 180,
    borderRadius: 90,
    borderWidth: 4,
    borderColor: '#00E5FF',
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,229,255,0.1)',
  },
  timerLabel: {
    color: '#888',
    fontSize: 14,
  },
  timerValue: {
    color: '#fff',
    fontSize: 36,
    fontWeight: 'bold',
  },
  timerElapsed: {
    color: '#666',
    fontSize: 12,
    marginTop: 5,
  },
  sectionTitle: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 15,
  },
  presetsContainer: {
    marginBottom: 25,
  },
  presetCard: {
    width: 160,
    padding: 15,
    marginRight: 12,
    backgroundColor: '#1a1a1a',
    borderRadius: 12,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  presetCardSelected: {
    borderColor: '#00E5FF',
    backgroundColor: 'rgba(0,229,255,0.1)',
  },
  presetName: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  presetNameSelected: {
    color: '#00E5FF',
  },
  presetFrequency: {
    color: '#00E5FF',
    fontSize: 14,
    marginBottom: 5,
  },
  presetDescription: {
    color: '#888',
    fontSize: 12,
    marginBottom: 5,
  },
  presetResearch: {
    color: '#666',
    fontSize: 10,
    fontStyle: 'italic',
  },
  controlSection: {
    marginBottom: 25,
  },
  controlHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  controlLabel: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  controlValue: {
    color: '#00E5FF',
    fontSize: 18,
    fontWeight: 'bold',
  },
  slider: {
    width: '100%',
    height: 40,
  },
  sliderLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sliderLabel: {
    color: '#666',
    fontSize: 12,
  },
  waveformButtons: {
    flexDirection: 'row',
    marginTop: 10,
  },
  waveformButton: {
    flex: 1,
    paddingVertical: 12,
    marginHorizontal: 5,
    backgroundColor: '#1a1a1a',
    borderRadius: 8,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  waveformButtonSelected: {
    borderColor: '#00E5FF',
    backgroundColor: 'rgba(0,229,255,0.1)',
  },
  waveformButtonText: {
    color: '#888',
    fontSize: 14,
    fontWeight: '600',
  },
  waveformButtonTextSelected: {
    color: '#00E5FF',
  },
  infoSection: {
    backgroundColor: '#1a1a1a',
    padding: 15,
    borderRadius: 12,
    marginBottom: 20,
  },
  infoTitle: {
    color: '#00E5FF',
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  infoDescription: {
    color: '#fff',
    fontSize: 14,
    marginBottom: 8,
  },
  infoResearch: {
    color: '#888',
    fontSize: 12,
    fontStyle: 'italic',
    marginBottom: 8,
  },
  infoTarget: {
    color: '#666',
    fontSize: 12,
  },
  safetyInfo: {
    backgroundColor: 'rgba(255,152,0,0.1)',
    padding: 15,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,152,0,0.3)',
    marginBottom: 20,
  },
  safetyTitle: {
    color: '#FF9800',
    fontSize: 14,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  safetyText: {
    color: '#888',
    fontSize: 12,
    marginBottom: 3,
  },
  buttonContainer: {
    position: 'absolute',
    bottom: 50,
    left: 20,
    right: 20,
  },
  playButton: {
    backgroundColor: '#00E5FF',
    paddingVertical: 18,
    borderRadius: 12,
    alignItems: 'center',
  },
  stopButton: {
    backgroundColor: '#FF5252',
  },
  playButtonText: {
    color: '#000',
    fontSize: 18,
    fontWeight: 'bold',
  },
  disclaimerContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: 10,
    backgroundColor: '#0a0a0a',
  },
  disclaimer: {
    color: '#666',
    fontSize: 10,
    textAlign: 'center',
  },
});
