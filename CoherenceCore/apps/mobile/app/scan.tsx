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
  ScrollView,
} from 'react-native';
import { Camera, CameraType, CameraView } from 'expo-camera';
import { router } from 'expo-router';
import { DISCLAIMER_TEXT } from '@coherence-core/shared-types';
import { useCoherenceEngine } from '../lib/useCoherenceEngine';
import { useIMUAnalyzer } from '../lib/useIMUAnalyzer';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

type ScanMode = 'camera' | 'imu' | 'fusion';

export default function ScanScreen() {
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [facing, setFacing] = useState<CameraType>('back');
  const [scanMode, setScanMode] = useState<ScanMode>('camera');

  // Use unified engine hook
  const {
    session,
    evmConfig,
    sensorLimits,
    toggleAnalysis,
    updateFrameRate,
    showDisclaimerModal,
  } = useCoherenceEngine();

  // IMU Analyzer hook - THE CONNECTION: Both detect micro-vibrations!
  const imu = useIMUAnalyzer();

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

    // Toggle based on scan mode
    if (scanMode === 'camera') {
      await toggleAnalysis();
    } else if (scanMode === 'imu') {
      await imu.toggleAnalysis();
    } else if (scanMode === 'fusion') {
      // Fusion mode: toggle both
      await toggleAnalysis();
      await imu.toggleAnalysis();
    }
  }, [
    session.disclaimerAcknowledged,
    session.isAnalyzing,
    showDisclaimerModal,
    toggleAnalysis,
    scanMode,
    imu,
  ]);

  // Check if any analysis is running
  const isAnyAnalyzing = session.isAnalyzing || imu.isAnalyzing;

  // Convert Hz to BPM for display
  const formatHeartRate = (hz: number | null): string => {
    if (hz === null) return '--';
    return `${Math.round(hz * 60)} BPM`;
  };

  // Convert Hz to breaths/min for display
  const formatBreathingRate = (hz: number | null): string => {
    if (hz === null) return '--';
    return `${(hz * 60).toFixed(1)}/min`;
  };

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
            <Text style={styles.title}>
              {scanMode === 'camera' ? 'EVM Scanner' : scanMode === 'imu' ? 'IMU Analyzer' : 'Sensor Fusion'}
            </Text>
            <TouchableOpacity
              style={styles.flipButton}
              onPress={toggleCameraFacing}
            >
              <Text style={styles.flipButtonText}>Flip</Text>
            </TouchableOpacity>
          </View>

          {/* Mode Tabs - THE CONNECTION between EVM and IMU */}
          <View style={styles.modeTabs}>
            <TouchableOpacity
              style={[styles.modeTab, scanMode === 'camera' && styles.modeTabActive]}
              onPress={() => setScanMode('camera')}
            >
              <Text style={[styles.modeTabText, scanMode === 'camera' && styles.modeTabTextActive]}>
                📷 Camera
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modeTab, scanMode === 'imu' && styles.modeTabActive]}
              onPress={() => setScanMode('imu')}
            >
              <Text style={[styles.modeTabText, scanMode === 'imu' && styles.modeTabTextActive]}>
                📱 IMU
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modeTab, scanMode === 'fusion' && styles.modeTabActive]}
              onPress={() => setScanMode('fusion')}
            >
              <Text style={[styles.modeTabText, scanMode === 'fusion' && styles.modeTabTextActive]}>
                🔗 Fusion
              </Text>
            </TouchableOpacity>
          </View>

          {/* Target Reticle (Camera mode) or IMU Display */}
          <View style={styles.reticleContainer}>
            {scanMode === 'imu' ? (
              /* IMU Mode: Show accelerometer visualization */
              <View style={styles.imuDisplay}>
                <Text style={styles.imuTitle}>Accelerometer</Text>
                {imu.currentData ? (
                  <>
                    <View style={styles.imuAxes}>
                      <View style={styles.imuAxis}>
                        <Text style={styles.imuAxisLabel}>X</Text>
                        <View style={styles.imuBar}>
                          <View
                            style={[
                              styles.imuBarFill,
                              styles.imuBarX,
                              { width: `${Math.min(100, Math.abs(imu.currentData.x) * 50)}%` },
                            ]}
                          />
                        </View>
                        <Text style={styles.imuAxisValue}>
                          {imu.currentData.x.toFixed(3)}
                        </Text>
                      </View>
                      <View style={styles.imuAxis}>
                        <Text style={styles.imuAxisLabel}>Y</Text>
                        <View style={styles.imuBar}>
                          <View
                            style={[
                              styles.imuBarFill,
                              styles.imuBarY,
                              { width: `${Math.min(100, Math.abs(imu.currentData.y) * 50)}%` },
                            ]}
                          />
                        </View>
                        <Text style={styles.imuAxisValue}>
                          {imu.currentData.y.toFixed(3)}
                        </Text>
                      </View>
                      <View style={styles.imuAxis}>
                        <Text style={styles.imuAxisLabel}>Z</Text>
                        <View style={styles.imuBar}>
                          <View
                            style={[
                              styles.imuBarFill,
                              styles.imuBarZ,
                              { width: `${Math.min(100, Math.abs(imu.currentData.z) * 50)}%` },
                            ]}
                          />
                        </View>
                        <Text style={styles.imuAxisValue}>
                          {imu.currentData.z.toFixed(3)}
                        </Text>
                      </View>
                    </View>
                    <Text style={styles.imuMagnitude}>
                      Magnitude: {imu.currentData.magnitude.toFixed(3)} g
                    </Text>
                  </>
                ) : (
                  <Text style={styles.imuHint}>
                    {imu.isAvailable ? 'Start analysis to see data' : 'IMU not available'}
                  </Text>
                )}
                {imu.isAnalyzing && (
                  <View style={styles.imuBuffer}>
                    <Text style={styles.imuBufferLabel}>Buffer:</Text>
                    <View style={styles.imuBufferBar}>
                      <View
                        style={[styles.imuBufferFill, { width: `${imu.bufferFillPercent}%` }]}
                      />
                    </View>
                    <Text style={styles.imuBufferPercent}>
                      {Math.round(imu.bufferFillPercent)}%
                    </Text>
                  </View>
                )}
              </View>
            ) : (
              /* Camera mode: Show target reticle */
              <>
                <View style={styles.reticle}>
                  <View style={styles.reticleCorner} />
                  <View style={[styles.reticleCorner, styles.topRight]} />
                  <View style={[styles.reticleCorner, styles.bottomLeft]} />
                  <View style={[styles.reticleCorner, styles.bottomRight]} />
                </View>
                <Text style={styles.reticleText}>
                  {scanMode === 'fusion'
                    ? 'Position target + Hold device steady'
                    : 'Position target in frame'}
                </Text>
              </>
            )}
          </View>

          {/* Analysis Panel */}
          <View style={styles.analysisPanel}>
            {/* Mode-specific status row */}
            {scanMode === 'imu' ? (
              /* IMU Mode Status */
              <View style={styles.statusRow}>
                <View style={styles.statusItem}>
                  <Text style={styles.statusLabel}>Sample Rate</Text>
                  <Text style={styles.statusValue}>{imu.analysis.sampleRateHz} Hz</Text>
                </View>
                <View style={styles.statusItem}>
                  <Text style={styles.statusLabel}>Nyquist</Text>
                  <Text
                    style={[
                      styles.statusValue,
                      { color: imu.analysis.isNyquistValid ? '#4CAF50' : '#FF9800' },
                    ]}
                  >
                    {imu.analysis.isNyquistValid ? 'OK' : 'LIMIT'}
                  </Text>
                </View>
                <View style={styles.statusItem}>
                  <Text style={styles.statusLabel}>Quality</Text>
                  <Text style={styles.statusValue}>
                    {Math.round(imu.analysis.signalQuality * 100)}%
                  </Text>
                </View>
              </View>
            ) : (
              /* Camera Mode Status */
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
            )}

            {/* IMU Biometric Estimates (IMU mode only) */}
            {(scanMode === 'imu' || scanMode === 'fusion') && imu.isAnalyzing && (
              <View style={styles.biometricEstimates}>
                <View style={styles.biometricItem}>
                  <Text style={styles.biometricIcon}>❤️</Text>
                  <Text style={styles.biometricLabel}>Heart Rate</Text>
                  <Text style={styles.biometricValue}>
                    {formatHeartRate(imu.analysis.estimatedHeartRateHz)}
                  </Text>
                </View>
                <View style={styles.biometricItem}>
                  <Text style={styles.biometricIcon}>🌬️</Text>
                  <Text style={styles.biometricLabel}>Breathing</Text>
                  <Text style={styles.biometricValue}>
                    {formatBreathingRate(imu.analysis.estimatedBreathingRateHz)}
                  </Text>
                </View>
              </View>
            )}

            {/* Frequency Range */}
            <View style={styles.frequencyRange}>
              <Text style={styles.frequencyLabel}>Target Range:</Text>
              <Text style={styles.frequencyValue}>
                {scanMode === 'imu'
                  ? `${imu.frequencyRanges.heartRate[0]}-${imu.frequencyRanges.heartRate[1]} Hz`
                  : `${evmConfig.frequencyRangeHz[0]}-${evmConfig.frequencyRangeHz[1]} Hz`}
              </Text>
            </View>

            {/* Sensor Limits Info */}
            <View style={styles.sensorInfo}>
              <Text style={styles.sensorInfoTitle}>
                {scanMode === 'fusion' ? 'Sensor Fusion (Max Detectable):' : 'Max Detectable (Nyquist):'}
              </Text>
              {(scanMode === 'camera' || scanMode === 'fusion') && (
                <>
                  <View style={styles.sensorInfoRow}>
                    <Text style={styles.sensorInfoLabel}>4K Camera:</Text>
                    <Text style={styles.sensorInfoValue}>{sensorLimits.camera4KMaxHz} Hz</Text>
                  </View>
                  <View style={styles.sensorInfoRow}>
                    <Text style={styles.sensorInfoLabel}>1080p Camera:</Text>
                    <Text style={styles.sensorInfoValue}>{sensorLimits.camera1080pMaxHz} Hz</Text>
                  </View>
                </>
              )}
              {(scanMode === 'imu' || scanMode === 'fusion') && (
                <View style={styles.sensorInfoRow}>
                  <Text style={[styles.sensorInfoLabel, scanMode === 'imu' && styles.sensorInfoActive]}>
                    IMU ({imu.capabilities.typicalSampleRateHz}Hz):
                  </Text>
                  <Text style={[styles.sensorInfoValue, scanMode === 'imu' && styles.sensorInfoActive]}>
                    {imu.capabilities.maxDetectableFrequencyHz} Hz
                  </Text>
                </View>
              )}
            </View>

            {/* Quality Score Bar */}
            <View style={styles.qualityContainer}>
              <Text style={styles.qualityLabel}>
                Signal Quality {scanMode === 'imu' && imu.analysis.noiseLevel > 0.5 ? '(Noisy)' : ''}
              </Text>
              <View style={styles.qualityBar}>
                <View
                  style={[
                    styles.qualityFill,
                    {
                      width: `${(scanMode === 'imu' ? imu.analysis.signalQuality : session.qualityScore) * 100}%`,
                    },
                  ]}
                />
              </View>
            </View>

            {/* Detected Frequencies */}
            {((scanMode === 'camera' && session.detectedFrequencies.length > 0) ||
              (scanMode === 'imu' && imu.analysis.dominantFrequencies.length > 0) ||
              (scanMode === 'fusion' && (session.detectedFrequencies.length > 0 || imu.analysis.dominantFrequencies.length > 0))) && (
              <View style={styles.detectedContainer}>
                <Text style={styles.detectedLabel}>Detected:</Text>
                <Text style={styles.detectedValue}>
                  {scanMode === 'camera'
                    ? session.detectedFrequencies.map(f => `${f.toFixed(1)} Hz`).join(', ')
                    : scanMode === 'imu'
                    ? imu.analysis.dominantFrequencies.map(f => `${f.toFixed(1)} Hz`).join(', ')
                    : [...new Set([...session.detectedFrequencies, ...imu.analysis.dominantFrequencies])]
                        .sort((a, b) => a - b)
                        .map(f => `${f.toFixed(1)} Hz`)
                        .join(', ')}
                </Text>
              </View>
            )}

            {/* Start/Stop Button */}
            <TouchableOpacity
              style={[
                styles.analyzeButton,
                isAnyAnalyzing && styles.analyzeButtonActive,
              ]}
              onPress={handleToggleAnalysis}
            >
              <Text style={styles.analyzeButtonText}>
                {isAnyAnalyzing ? 'Stop Analysis' : 'Start Analysis'}
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

  // Mode Tabs - THE CONNECTION between sensors
  modeTabs: {
    flexDirection: 'row',
    justifyContent: 'center',
    paddingHorizontal: 20,
    paddingVertical: 10,
    gap: 8,
  },
  modeTab: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.1)',
  },
  modeTabActive: {
    backgroundColor: '#00E5FF',
  },
  modeTabText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '500',
  },
  modeTabTextActive: {
    color: '#000',
  },

  // IMU Display
  imuDisplay: {
    width: 280,
    padding: 20,
    backgroundColor: 'rgba(0,0,0,0.7)',
    borderRadius: 16,
    alignItems: 'center',
  },
  imuTitle: {
    color: '#00E5FF',
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 15,
  },
  imuAxes: {
    width: '100%',
    gap: 10,
  },
  imuAxis: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  imuAxisLabel: {
    color: '#888',
    fontSize: 14,
    fontWeight: '600',
    width: 20,
  },
  imuBar: {
    flex: 1,
    height: 8,
    backgroundColor: '#333',
    borderRadius: 4,
    overflow: 'hidden',
  },
  imuBarFill: {
    height: '100%',
    borderRadius: 4,
  },
  imuBarX: {
    backgroundColor: '#FF5252',
  },
  imuBarY: {
    backgroundColor: '#4CAF50',
  },
  imuBarZ: {
    backgroundColor: '#2196F3',
  },
  imuAxisValue: {
    color: '#fff',
    fontSize: 11,
    width: 50,
    textAlign: 'right',
  },
  imuMagnitude: {
    color: '#fff',
    fontSize: 14,
    marginTop: 15,
  },
  imuHint: {
    color: '#888',
    fontSize: 14,
    textAlign: 'center',
  },
  imuBuffer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 15,
    width: '100%',
    gap: 8,
  },
  imuBufferLabel: {
    color: '#888',
    fontSize: 11,
  },
  imuBufferBar: {
    flex: 1,
    height: 4,
    backgroundColor: '#333',
    borderRadius: 2,
    overflow: 'hidden',
  },
  imuBufferFill: {
    height: '100%',
    backgroundColor: '#00E5FF',
    borderRadius: 2,
  },
  imuBufferPercent: {
    color: '#888',
    fontSize: 11,
    width: 35,
    textAlign: 'right',
  },

  // Biometric Estimates
  biometricEstimates: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 15,
    paddingVertical: 10,
    backgroundColor: 'rgba(0,229,255,0.05)',
    borderRadius: 12,
  },
  biometricItem: {
    alignItems: 'center',
  },
  biometricIcon: {
    fontSize: 24,
    marginBottom: 4,
  },
  biometricLabel: {
    color: '#888',
    fontSize: 11,
    marginBottom: 2,
  },
  biometricValue: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },

  // Active sensor highlight
  sensorInfoActive: {
    color: '#00E5FF',
    fontWeight: '600',
  },
});
