/**
 * CoherenceCore Scan Screen
 *
 * EVM (Eulerian Video Magnification) camera scanner for detecting
 * micro-vibrations in tissue (1-60 Hz range).
 *
 * Uses unified CoherenceEngine hook for state management.
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import { useState, useRef, useCallback, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Dimensions,
  Platform,
} from 'react-native';
import { Camera, CameraType, CameraView } from 'expo-camera';
import { router } from 'expo-router';
import { DISCLAIMER_TEXT } from '@coherence-core/shared-types';
import { useCoherenceEngine } from '../lib/useCoherenceEngine';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

export default function ScanScreen() {
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [facing, setFacing] = useState<CameraType>('back');

  // Use unified engine hook
  const {
    session,
    evmConfig,
    sensorLimits,
    toggleAnalysis,
    updateFrameRate,
    showDisclaimerModal,
  } = useCoherenceEngine();

  const cameraRef = useRef<CameraView>(null);
  const frameCountRef = useRef(0);
  const lastFrameTimeRef = useRef(Date.now());
  const fpsHistoryRef = useRef<number[]>([]);

  // Request camera permissions
  useEffect(() => {
    (async () => {
      const { status } = await Camera.requestCameraPermissionsAsync();
      setHasPermission(status === 'granted');
    })();
  }, []);

  // Toggle camera facing
  const toggleCameraFacing = useCallback(() => {
    setFacing(current => (current === 'back' ? 'front' : 'back'));
  }, []);

  // Handle analysis toggle with disclaimer check
  const handleToggleAnalysis = useCallback(async () => {
    if (!session.disclaimerAcknowledged && !session.isAnalyzing) {
      const accepted = await showDisclaimerModal();
      if (!accepted) return;
    }
    await toggleAnalysis();
  }, [session.disclaimerAcknowledged, session.isAnalyzing, showDisclaimerModal, toggleAnalysis]);

  // Calculate FPS from frame timing
  const onFrameProcessed = useCallback(() => {
    const now = Date.now();
    const elapsed = now - lastFrameTimeRef.current;
    lastFrameTimeRef.current = now;

    if (elapsed > 0) {
      const instantFps = 1000 / elapsed;
      fpsHistoryRef.current.push(instantFps);
      if (fpsHistoryRef.current.length > 30) {
        fpsHistoryRef.current.shift();
      }

      const avgFps =
        fpsHistoryRef.current.reduce((a, b) => a + b, 0) /
        fpsHistoryRef.current.length;

      updateFrameRate(avgFps);
    }
    frameCountRef.current++;
  }, [updateFrameRate]);

  // Camera ready callback
  const onCameraReady = useCallback(() => {
    console.log('[ScanScreen] Camera ready');
  }, []);

  // Render permission states
  if (hasPermission === null) {
    return (
      <View style={styles.container}>
        <Text style={styles.text}>Requesting camera permission...</Text>
      </View>
    );
  }

  if (hasPermission === false) {
    return (
      <View style={styles.container}>
        <Text style={styles.text}>Camera access denied</Text>
        <Text style={styles.subtext}>
          Please enable camera permissions in Settings
        </Text>
        <TouchableOpacity style={styles.button} onPress={() => router.back()}>
          <Text style={styles.buttonText}>Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Camera View */}
      <CameraView
        ref={cameraRef}
        style={styles.camera}
        facing={facing}
        onCameraReady={onCameraReady}
      >
        {/* Overlay UI */}
        <View style={styles.overlay}>
          {/* Header */}
          <View style={styles.header}>
            <TouchableOpacity
              style={styles.backButton}
              onPress={() => router.back()}
            >
              <Text style={styles.backButtonText}>← Back</Text>
            </TouchableOpacity>
            <Text style={styles.title}>EVM Scanner</Text>
            <TouchableOpacity
              style={styles.flipButton}
              onPress={toggleCameraFacing}
            >
              <Text style={styles.flipButtonText}>Flip</Text>
            </TouchableOpacity>
          </View>

          {/* Target Reticle */}
          <View style={styles.reticleContainer}>
            <View style={styles.reticle}>
              <View style={styles.reticleCorner} />
              <View style={[styles.reticleCorner, styles.topRight]} />
              <View style={[styles.reticleCorner, styles.bottomLeft]} />
              <View style={[styles.reticleCorner, styles.bottomRight]} />
            </View>
            <Text style={styles.reticleText}>Position target in frame</Text>
          </View>

          {/* Analysis Panel */}
          <View style={styles.analysisPanel}>
            {/* FPS and Nyquist Status */}
            <View style={styles.statusRow}>
              <View style={styles.statusItem}>
                <Text style={styles.statusLabel}>FPS</Text>
                <Text style={styles.statusValue}>{session.frameRate}</Text>
              </View>
              <View style={styles.statusItem}>
                <Text style={styles.statusLabel}>Nyquist</Text>
                <Text
                  style={[
                    styles.statusValue,
                    { color: session.nyquistValid ? '#4CAF50' : '#FF9800' },
                  ]}
                >
                  {session.nyquistValid ? 'OK' : 'LOW FPS'}
                </Text>
              </View>
              <View style={styles.statusItem}>
                <Text style={styles.statusLabel}>Quality</Text>
                <Text style={styles.statusValue}>
                  {Math.round(session.qualityScore * 100)}%
                </Text>
              </View>
            </View>

            {/* Frequency Range */}
            <View style={styles.frequencyRange}>
              <Text style={styles.frequencyLabel}>Target Range:</Text>
              <Text style={styles.frequencyValue}>
                {evmConfig.frequencyRangeHz[0]}-
                {evmConfig.frequencyRangeHz[1]} Hz
              </Text>
            </View>

            {/* Sensor Limits Info */}
            <View style={styles.sensorInfo}>
              <Text style={styles.sensorInfoTitle}>Max Detectable (Nyquist):</Text>
              <View style={styles.sensorInfoRow}>
                <Text style={styles.sensorInfoLabel}>4K Camera:</Text>
                <Text style={styles.sensorInfoValue}>{sensorLimits.camera4KMaxHz} Hz</Text>
              </View>
              <View style={styles.sensorInfoRow}>
                <Text style={styles.sensorInfoLabel}>1080p Camera:</Text>
                <Text style={styles.sensorInfoValue}>{sensorLimits.camera1080pMaxHz} Hz</Text>
              </View>
              <View style={styles.sensorInfoRow}>
                <Text style={styles.sensorInfoLabel}>IMU (100Hz):</Text>
                <Text style={styles.sensorInfoValue}>{sensorLimits.imuMaxHz} Hz</Text>
              </View>
            </View>

            {/* Quality Score Bar */}
            <View style={styles.qualityContainer}>
              <Text style={styles.qualityLabel}>Signal Quality</Text>
              <View style={styles.qualityBar}>
                <View
                  style={[
                    styles.qualityFill,
                    { width: `${session.qualityScore * 100}%` },
                  ]}
                />
              </View>
            </View>

            {/* Detected Frequencies */}
            {session.detectedFrequencies.length > 0 && (
              <View style={styles.detectedContainer}>
                <Text style={styles.detectedLabel}>Detected:</Text>
                <Text style={styles.detectedValue}>
                  {session.detectedFrequencies
                    .map(f => `${f.toFixed(1)} Hz`)
                    .join(', ')}
                </Text>
              </View>
            )}

            {/* Start/Stop Button */}
            <TouchableOpacity
              style={[
                styles.analyzeButton,
                session.isAnalyzing && styles.analyzeButtonActive,
              ]}
              onPress={handleToggleAnalysis}
            >
              <Text style={styles.analyzeButtonText}>
                {session.isAnalyzing ? 'Stop Analysis' : 'Start Analysis'}
              </Text>
            </TouchableOpacity>
          </View>

          {/* Disclaimer */}
          <View style={styles.disclaimerContainer}>
            <Text style={styles.disclaimer}>{DISCLAIMER_TEXT}</Text>
          </View>
        </View>
      </CameraView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    justifyContent: 'center',
    alignItems: 'center',
  },
  camera: {
    flex: 1,
    width: SCREEN_WIDTH,
  },
  overlay: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: Platform.OS === 'ios' ? 60 : 40,
    paddingHorizontal: 20,
  },
  backButton: {
    padding: 10,
  },
  backButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  title: {
    color: '#fff',
    fontSize: 20,
    fontWeight: 'bold',
  },
  flipButton: {
    padding: 10,
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderRadius: 8,
  },
  flipButtonText: {
    color: '#fff',
    fontSize: 14,
  },
  reticleContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  reticle: {
    width: 250,
    height: 250,
    position: 'relative',
  },
  reticleCorner: {
    position: 'absolute',
    width: 40,
    height: 40,
    borderColor: '#00E5FF',
    borderTopWidth: 3,
    borderLeftWidth: 3,
    top: 0,
    left: 0,
  },
  topRight: {
    top: 0,
    left: undefined,
    right: 0,
    borderLeftWidth: 0,
    borderRightWidth: 3,
  },
  bottomLeft: {
    top: undefined,
    bottom: 0,
    borderTopWidth: 0,
    borderBottomWidth: 3,
  },
  bottomRight: {
    top: undefined,
    left: undefined,
    bottom: 0,
    right: 0,
    borderTopWidth: 0,
    borderLeftWidth: 0,
    borderBottomWidth: 3,
    borderRightWidth: 3,
  },
  reticleText: {
    color: '#00E5FF',
    fontSize: 14,
    marginTop: 10,
    textAlign: 'center',
  },
  analysisPanel: {
    backgroundColor: 'rgba(0,0,0,0.8)',
    padding: 20,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 15,
  },
  statusItem: {
    alignItems: 'center',
  },
  statusLabel: {
    color: '#888',
    fontSize: 12,
    marginBottom: 4,
  },
  statusValue: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  frequencyRange: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 15,
  },
  frequencyLabel: {
    color: '#888',
    fontSize: 14,
    marginRight: 8,
  },
  frequencyValue: {
    color: '#00E5FF',
    fontSize: 16,
    fontWeight: '600',
  },
  sensorInfo: {
    backgroundColor: 'rgba(0,229,255,0.1)',
    padding: 10,
    borderRadius: 8,
    marginBottom: 15,
  },
  sensorInfoTitle: {
    color: '#00E5FF',
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 6,
  },
  sensorInfoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 2,
  },
  sensorInfoLabel: {
    color: '#888',
    fontSize: 11,
  },
  sensorInfoValue: {
    color: '#fff',
    fontSize: 11,
    fontWeight: '500',
  },
  qualityContainer: {
    marginBottom: 15,
  },
  qualityLabel: {
    color: '#888',
    fontSize: 12,
    marginBottom: 6,
  },
  qualityBar: {
    height: 8,
    backgroundColor: '#333',
    borderRadius: 4,
    overflow: 'hidden',
  },
  qualityFill: {
    height: '100%',
    backgroundColor: '#00E5FF',
    borderRadius: 4,
  },
  detectedContainer: {
    backgroundColor: 'rgba(0,229,255,0.1)',
    padding: 10,
    borderRadius: 8,
    marginBottom: 15,
  },
  detectedLabel: {
    color: '#00E5FF',
    fontSize: 12,
    marginBottom: 4,
  },
  detectedValue: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  analyzeButton: {
    backgroundColor: '#00E5FF',
    paddingVertical: 15,
    borderRadius: 12,
    alignItems: 'center',
  },
  analyzeButtonActive: {
    backgroundColor: '#FF5252',
  },
  analyzeButtonText: {
    color: '#000',
    fontSize: 18,
    fontWeight: 'bold',
  },
  disclaimerContainer: {
    padding: 10,
    backgroundColor: 'rgba(0,0,0,0.9)',
  },
  disclaimer: {
    color: '#888',
    fontSize: 10,
    textAlign: 'center',
  },
  text: {
    color: '#fff',
    fontSize: 18,
    textAlign: 'center',
  },
  subtext: {
    color: '#888',
    fontSize: 14,
    textAlign: 'center',
    marginTop: 10,
  },
  button: {
    backgroundColor: '#00E5FF',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 12,
    marginTop: 20,
  },
  buttonText: {
    color: '#000',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
