/**
 * CoherenceCore Scan Screen
 *
 * EVM (Eulerian Video Magnification) camera scanner for detecting
 * micro-vibrations in tissue (1-60 Hz range).
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import React, { useState, useRef, useCallback, useEffect } from 'react';
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
import {
  DEFAULT_EVM_CONFIG,
  DISCLAIMER_TEXT,
  validateNyquist,
} from '@coherence-core/shared-types';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// Analysis state
interface AnalysisState {
  isAnalyzing: boolean;
  frameCount: number;
  detectedFrequencies: number[];
  qualityScore: number;
  fps: number;
  nyquistValid: boolean;
}

export default function ScanScreen() {
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [facing, setFacing] = useState<CameraType>('back');
  const [analysis, setAnalysis] = useState<AnalysisState>({
    isAnalyzing: false,
    frameCount: 0,
    detectedFrequencies: [],
    qualityScore: 0,
    fps: 30,
    nyquistValid: false,
  });

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

  // Validate Nyquist for current FPS
  useEffect(() => {
    const maxTargetFreq = DEFAULT_EVM_CONFIG.frequencyRangeHz[1];
    const validation = validateNyquist(maxTargetFreq, analysis.fps);
    setAnalysis(prev => ({
      ...prev,
      nyquistValid: validation.isValid,
    }));
  }, [analysis.fps]);

  // Start/stop analysis
  const toggleAnalysis = useCallback(() => {
    setAnalysis(prev => ({
      ...prev,
      isAnalyzing: !prev.isAnalyzing,
      frameCount: 0,
      detectedFrequencies: [],
      qualityScore: 0,
    }));
    frameCountRef.current = 0;
  }, []);

  // Toggle camera facing
  const toggleCameraFacing = useCallback(() => {
    setFacing(current => (current === 'back' ? 'front' : 'back'));
  }, []);

  // Calculate FPS from frame timing
  const updateFPS = useCallback(() => {
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

      setAnalysis(prev => ({
        ...prev,
        fps: Math.round(avgFps),
        frameCount: frameCountRef.current,
      }));
    }
  }, []);

  // Simulated frame processing (actual EVM would use WebGL)
  const onCameraReady = useCallback(() => {
    console.log('Camera ready');
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
                <Text style={styles.statusValue}>{analysis.fps}</Text>
              </View>
              <View style={styles.statusItem}>
                <Text style={styles.statusLabel}>Nyquist</Text>
                <Text
                  style={[
                    styles.statusValue,
                    { color: analysis.nyquistValid ? '#4CAF50' : '#FF9800' },
                  ]}
                >
                  {analysis.nyquistValid ? 'OK' : 'LOW FPS'}
                </Text>
              </View>
              <View style={styles.statusItem}>
                <Text style={styles.statusLabel}>Frames</Text>
                <Text style={styles.statusValue}>{analysis.frameCount}</Text>
              </View>
            </View>

            {/* Frequency Range */}
            <View style={styles.frequencyRange}>
              <Text style={styles.frequencyLabel}>Target Range:</Text>
              <Text style={styles.frequencyValue}>
                {DEFAULT_EVM_CONFIG.frequencyRangeHz[0]}-
                {DEFAULT_EVM_CONFIG.frequencyRangeHz[1]} Hz
              </Text>
            </View>

            {/* Quality Score */}
            <View style={styles.qualityContainer}>
              <Text style={styles.qualityLabel}>Signal Quality</Text>
              <View style={styles.qualityBar}>
                <View
                  style={[
                    styles.qualityFill,
                    { width: `${analysis.qualityScore * 100}%` },
                  ]}
                />
              </View>
              <Text style={styles.qualityValue}>
                {Math.round(analysis.qualityScore * 100)}%
              </Text>
            </View>

            {/* Detected Frequencies */}
            {analysis.detectedFrequencies.length > 0 && (
              <View style={styles.detectedContainer}>
                <Text style={styles.detectedLabel}>Detected:</Text>
                <Text style={styles.detectedValue}>
                  {analysis.detectedFrequencies
                    .map(f => `${f.toFixed(1)} Hz`)
                    .join(', ')}
                </Text>
              </View>
            )}

            {/* Start/Stop Button */}
            <TouchableOpacity
              style={[
                styles.analyzeButton,
                analysis.isAnalyzing && styles.analyzeButtonActive,
              ]}
              onPress={toggleAnalysis}
            >
              <Text style={styles.analyzeButtonText}>
                {analysis.isAnalyzing ? 'Stop Analysis' : 'Start Analysis'}
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
  qualityValue: {
    color: '#fff',
    fontSize: 12,
    textAlign: 'right',
    marginTop: 4,
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
