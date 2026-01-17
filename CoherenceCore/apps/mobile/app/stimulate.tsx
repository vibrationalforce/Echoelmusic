/**
 * CoherenceCore Stimulate Screen
 *
 * VAT (Vibroacoustic Therapy) audio output with frequency presets,
 * amplitude control, and session timer with safety cutoff.
 *
 * Uses unified CoherenceEngine hook for state management.
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import { useCallback, useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Platform,
} from 'react-native';
import { CymaticsVisualizer, CymaticsMode } from '../components/CymaticsVisualizer';
import Slider from '@react-native-community/slider';
import { router } from 'expo-router';
import {
  FREQUENCY_PRESETS,
  DEFAULT_SAFETY_LIMITS,
  DISCLAIMER_TEXT,
  FrequencyPresetId,
} from '@coherence-core/shared-types';
import { useCoherenceEngine, SessionState } from '../lib/useCoherenceEngine';

// Preset card component
interface PresetCardProps {
  preset: typeof FREQUENCY_PRESETS[FrequencyPresetId];
  isSelected: boolean;
  onSelect: () => void;
  disabled: boolean;
}

const PresetCard: React.FC<PresetCardProps> = ({
  preset,
  isSelected,
  onSelect,
  disabled,
}) => (
  <TouchableOpacity
    style={[styles.presetCard, isSelected && styles.presetCardSelected]}
    onPress={onSelect}
    disabled={disabled}
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
  return `${minutes.toString().padStart(2, '0')}:${seconds
    .toString()
    .padStart(2, '0')}`;
};

export default function StimulateScreen() {
  // Use unified engine hook
  const {
    session,
    safetyLimits,
    presets,
    selectPreset,
    setFrequency,
    setAmplitude,
    setWaveform,
    toggleSession,
    showDisclaimerModal,
  } = useCoherenceEngine();

  // Cymatics visualizer state
  const [cymaticsPhase, setCymaticsPhase] = useState(0);
  const [cymaticsMode, setCymaticsMode] = useState<CymaticsMode>('chladni');
  const animationRef = useRef<number | null>(null);

  // Animate cymatics when session is playing
  useEffect(() => {
    if (session.isPlaying) {
      const startTime = Date.now();
      const animate = () => {
        const elapsed = Date.now() - startTime;
        // Phase cycles based on frequency - lower frequencies = slower animation
        const cycleMs = 1000 / (session.frequencyHz / 20);
        const phase = (elapsed % cycleMs) / cycleMs;
        setCymaticsPhase(phase);
        animationRef.current = requestAnimationFrame(animate);
      };
      animationRef.current = requestAnimationFrame(animate);
    } else {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
        animationRef.current = null;
      }
    }

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [session.isPlaying, session.frequencyHz]);

  // Handle session toggle with disclaimer check
  const handleToggleSession = useCallback(async () => {
    if (!session.disclaimerAcknowledged && !session.isPlaying) {
      const accepted = await showDisclaimerModal();
      if (!accepted) return;
    }
    await toggleSession();
  }, [session.disclaimerAcknowledged, session.isPlaying, showDisclaimerModal, toggleSession]);

  // Handle preset selection
  const handlePresetSelect = useCallback(
    (presetId: FrequencyPresetId) => {
      if (session.isPlaying) return;
      selectPreset(presetId);
    },
    [session.isPlaying, selectPreset]
  );

  // Handle frequency change
  const handleFrequencyChange = useCallback(
    (value: number) => {
      setFrequency(value);
    },
    [setFrequency]
  );

  // Handle amplitude change
  const handleAmplitudeChange = useCallback(
    (value: number) => {
      setAmplitude(value);
    },
    [setAmplitude]
  );

  // Handle waveform change
  const handleWaveformChange = useCallback(
    (waveform: SessionState['waveform']) => {
      if (session.isPlaying) return;
      setWaveform(waveform);
    },
    [session.isPlaying, setWaveform]
  );

  const currentPreset = presets[session.currentPreset];

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
        {/* Cymatics Visualizer */}
        <View style={styles.cymaticsContainer}>
          <CymaticsVisualizer
            frequencyHz={session.frequencyHz}
            amplitude={session.amplitude}
            phase={cymaticsPhase}
            mode={cymaticsMode}
            isActive={session.isPlaying}
            size={200}
          />
          <View style={styles.cymaticsInfo}>
            <Text style={styles.cymaticsLabel}>
              {session.isPlaying ? 'Wave Pattern' : 'Preview'}
            </Text>
            <Text style={styles.cymaticsFreq}>
              {session.frequencyHz.toFixed(1)} Hz
            </Text>
          </View>
        </View>

        {/* Cymatics Mode Selection */}
        <View style={styles.cymaticsModeContainer}>
          <Text style={styles.cymaticsModeLabel}>Visualization Mode</Text>
          <View style={styles.cymaticsModeButtons}>
            {(['chladni', 'interference', 'ripple', 'standing'] as CymaticsMode[]).map(
              (mode) => (
                <TouchableOpacity
                  key={mode}
                  style={[
                    styles.cymaticsModeButton,
                    cymaticsMode === mode && styles.cymaticsModeButtonSelected,
                  ]}
                  onPress={() => setCymaticsMode(mode)}
                >
                  <Text
                    style={[
                      styles.cymaticsModeButtonText,
                      cymaticsMode === mode && styles.cymaticsModeButtonTextSelected,
                    ]}
                  >
                    {mode.charAt(0).toUpperCase() + mode.slice(1)}
                  </Text>
                </TouchableOpacity>
              )
            )}
          </View>
        </View>

        {/* Session Timer */}
        <View style={styles.timerContainer}>
          <View style={styles.timerCircle}>
            <Text style={styles.timerLabel}>
              {session.isPlaying ? 'Remaining' : 'Session'}
            </Text>
            <Text style={styles.timerValue}>
              {formatTime(
                session.isPlaying
                  ? session.remainingMs
                  : safetyLimits.maxSessionDurationMs
              )}
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
          {(Object.keys(presets) as FrequencyPresetId[])
            .filter(id => id !== 'custom')
            .map(presetId => (
              <PresetCard
                key={presetId}
                preset={presets[presetId]}
                isSelected={session.currentPreset === presetId}
                onSelect={() => handlePresetSelect(presetId)}
                disabled={session.isPlaying}
              />
            ))}
        </ScrollView>

        {/* Frequency Control */}
        <View style={styles.controlSection}>
          <View style={styles.controlHeader}>
            <Text style={styles.controlLabel}>Frequency</Text>
            <Text style={styles.controlValue}>
              {session.frequencyHz.toFixed(1)} Hz
            </Text>
          </View>
          <Slider
            style={styles.slider}
            minimumValue={currentPreset.frequencyRangeHz[0]}
            maximumValue={currentPreset.frequencyRangeHz[1]}
            value={session.frequencyHz}
            onValueChange={handleFrequencyChange}
            minimumTrackTintColor="#00E5FF"
            maximumTrackTintColor="#333"
            thumbTintColor="#00E5FF"
            disabled={session.isPlaying}
          />
          <View style={styles.sliderLabels}>
            <Text style={styles.sliderLabel}>
              {currentPreset.frequencyRangeHz[0]} Hz
            </Text>
            <Text style={styles.sliderLabel}>
              {currentPreset.frequencyRangeHz[1]} Hz
            </Text>
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
            maximumValue={safetyLimits.maxAmplitude}
            value={session.amplitude}
            onValueChange={handleAmplitudeChange}
            minimumTrackTintColor="#00E5FF"
            maximumTrackTintColor="#333"
            thumbTintColor="#00E5FF"
          />
          <View style={styles.sliderLabels}>
            <Text style={styles.sliderLabel}>0%</Text>
            <Text style={styles.sliderLabel}>
              {Math.round(safetyLimits.maxAmplitude * 100)}% max
            </Text>
          </View>
        </View>

        {/* Waveform Selection */}
        <View style={styles.controlSection}>
          <Text style={styles.controlLabel}>Waveform</Text>
          <View style={styles.waveformButtons}>
            {(['sine', 'square', 'triangle', 'sawtooth'] as const).map(waveform => (
              <TouchableOpacity
                key={waveform}
                style={[
                  styles.waveformButton,
                  session.waveform === waveform && styles.waveformButtonSelected,
                ]}
                onPress={() => handleWaveformChange(waveform)}
                disabled={session.isPlaying}
              >
                <Text
                  style={[
                    styles.waveformButtonText,
                    session.waveform === waveform &&
                      styles.waveformButtonTextSelected,
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
            - Max session: {safetyLimits.maxSessionDurationMs / 60000} minutes
          </Text>
          <Text style={styles.safetyText}>
            - Max amplitude: {Math.round(safetyLimits.maxAmplitude * 100)}%
          </Text>
          <Text style={styles.safetyText}>
            - Max duty cycle: {Math.round(safetyLimits.maxDutyCycle * 100)}%
          </Text>
          <Text style={styles.safetyText}>
            - Cooldown period: {safetyLimits.cooldownPeriodMs / 60000} minutes
          </Text>
        </View>

        {/* Spacer for button */}
        <View style={{ height: 100 }} />
      </ScrollView>

      {/* Play/Stop Button */}
      <View style={styles.buttonContainer}>
        <TouchableOpacity
          style={[styles.playButton, session.isPlaying && styles.stopButton]}
          onPress={handleToggleSession}
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
  cymaticsContainer: {
    alignItems: 'center',
    marginTop: 10,
    marginBottom: 15,
  },
  cymaticsInfo: {
    alignItems: 'center',
    marginTop: 10,
  },
  cymaticsLabel: {
    color: '#888',
    fontSize: 12,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  cymaticsFreq: {
    color: '#00E5FF',
    fontSize: 18,
    fontWeight: 'bold',
    marginTop: 4,
  },
  cymaticsModeContainer: {
    marginBottom: 20,
  },
  cymaticsModeLabel: {
    color: '#888',
    fontSize: 12,
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: 10,
    textAlign: 'center',
  },
  cymaticsModeButtons: {
    flexDirection: 'row',
    justifyContent: 'center',
    flexWrap: 'wrap',
  },
  cymaticsModeButton: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginHorizontal: 4,
    marginBottom: 4,
    backgroundColor: '#1a1a1a',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  cymaticsModeButtonSelected: {
    borderColor: '#00E5FF',
    backgroundColor: 'rgba(0,229,255,0.1)',
  },
  cymaticsModeButtonText: {
    color: '#666',
    fontSize: 12,
    fontWeight: '600',
  },
  cymaticsModeButtonTextSelected: {
    color: '#00E5FF',
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
    flexWrap: 'wrap',
  },
  waveformButton: {
    flex: 1,
    minWidth: 70,
    paddingVertical: 12,
    marginHorizontal: 3,
    marginBottom: 6,
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
    fontSize: 13,
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
