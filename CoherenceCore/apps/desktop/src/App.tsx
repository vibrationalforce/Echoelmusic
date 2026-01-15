/**
 * CoherenceCore Desktop App
 *
 * Tauri 2.0 frontend for Windows and Linux.
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import { useState, useEffect, useCallback } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { CymaticsCanvas, CymaticsMode } from './CymaticsCanvas';

interface FrequencyPreset {
  id: string;
  name: string;
  frequency_range_hz: [number, number];
  primary_frequency_hz: number;
  research: string;
  target: string;
}

interface SessionState {
  is_playing: boolean;
  current_frequency_hz: number;
  amplitude: number;
  waveform: string;
  session_start_ms: number | null;
  elapsed_ms: number;
}

interface SafetyLimits {
  maxSessionDurationMs: number;
  maxAmplitude: number;
  maxDutyCycle: number;
  cooldownPeriodMs: number;
}

interface AudioDeviceInfo {
  id: string;
  name: string;
  host_id: string;
  is_default: boolean;
  is_usb: boolean;
  sample_rates: number[];
  min_buffer_size: number;
  max_buffer_size: number;
  channels: number;
}

interface AudioConfig {
  device_id: string | null;
  sample_rate: number;
  buffer_size: number;
}

const formatTime = (ms: number): string => {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
};

export default function App() {
  const [presets, setPresets] = useState<FrequencyPreset[]>([]);
  const [session, setSession] = useState<SessionState | null>(null);
  const [safetyLimits, setSafetyLimits] = useState<SafetyLimits | null>(null);
  const [disclaimer, setDisclaimer] = useState<string>('');
  const [selectedPreset, setSelectedPreset] = useState<string>('osteo-sync');
  const [activeTab, setActiveTab] = useState<'stimulate' | 'scan' | 'settings'>('stimulate');
  const [cymaticsMode, setCymaticsMode] = useState<CymaticsMode>('chladni');

  // Audio device state (class-compliant USB support)
  const [audioDevices, setAudioDevices] = useState<AudioDeviceInfo[]>([]);
  const [audioConfig, setAudioConfig] = useState<AudioConfig | null>(null);
  const [loadingDevices, setLoadingDevices] = useState(false);

  // Load initial data
  useEffect(() => {
    const loadData = async () => {
      try {
        const [presetsData, sessionData, limitsData, disclaimerData, devicesData, configData] = await Promise.all([
          invoke<FrequencyPreset[]>('get_presets'),
          invoke<SessionState>('get_session_state'),
          invoke<SafetyLimits>('get_safety_limits'),
          invoke<string>('get_disclaimer'),
          invoke<AudioDeviceInfo[]>('get_audio_devices'),
          invoke<AudioConfig>('get_audio_config'),
        ]);
        setPresets(presetsData);
        setSession(sessionData);
        setSafetyLimits(limitsData);
        setDisclaimer(disclaimerData);
        setAudioDevices(devicesData);
        setAudioConfig(configData);
      } catch (error) {
        console.error('Failed to load data:', error);
      }
    };
    loadData();
  }, []);

  // Poll session state when playing
  useEffect(() => {
    if (!session?.is_playing) return;

    const interval = setInterval(async () => {
      try {
        const sessionData = await invoke<SessionState>('get_session_state');
        setSession(sessionData);
      } catch (error) {
        console.error('Failed to get session state:', error);
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [session?.is_playing]);

  const handlePresetSelect = useCallback(async (presetId: string) => {
    const preset = presets.find(p => p.id === presetId);
    if (!preset) return;

    try {
      await invoke('set_frequency', { frequencyHz: preset.primary_frequency_hz });
      setSelectedPreset(presetId);
      const sessionData = await invoke<SessionState>('get_session_state');
      setSession(sessionData);
    } catch (error) {
      console.error('Failed to set preset:', error);
    }
  }, [presets]);

  const handleFrequencyChange = useCallback(async (value: number) => {
    try {
      await invoke('set_frequency', { frequencyHz: value });
      const sessionData = await invoke<SessionState>('get_session_state');
      setSession(sessionData);
    } catch (error) {
      console.error('Failed to set frequency:', error);
    }
  }, []);

  const handleAmplitudeChange = useCallback(async (value: number) => {
    try {
      await invoke('set_amplitude', { amplitude: value });
      const sessionData = await invoke<SessionState>('get_session_state');
      setSession(sessionData);
    } catch (error) {
      console.error('Failed to set amplitude:', error);
    }
  }, []);

  const handleToggleSession = useCallback(async () => {
    try {
      if (session?.is_playing) {
        await invoke('stop_session');
      } else {
        await invoke('start_session');
      }
      const sessionData = await invoke<SessionState>('get_session_state');
      setSession(sessionData);
    } catch (error) {
      console.error('Failed to toggle session:', error);
    }
  }, [session?.is_playing]);

  // Audio device handlers (class-compliant USB)
  const handleDeviceChange = useCallback(async (deviceId: string) => {
    try {
      await invoke('set_audio_config', { deviceId, sampleRate: null, bufferSize: null });
      const configData = await invoke<AudioConfig>('get_audio_config');
      setAudioConfig(configData);
    } catch (error) {
      console.error('Failed to set audio device:', error);
    }
  }, []);

  const handleSampleRateChange = useCallback(async (sampleRate: number) => {
    try {
      await invoke('set_audio_config', { deviceId: null, sampleRate, bufferSize: null });
      const configData = await invoke<AudioConfig>('get_audio_config');
      setAudioConfig(configData);
    } catch (error) {
      console.error('Failed to set sample rate:', error);
    }
  }, []);

  const handleBufferSizeChange = useCallback(async (bufferSize: number) => {
    try {
      await invoke('set_audio_config', { deviceId: null, sampleRate: null, bufferSize });
      const configData = await invoke<AudioConfig>('get_audio_config');
      setAudioConfig(configData);
    } catch (error) {
      console.error('Failed to set buffer size:', error);
    }
  }, []);

  const refreshAudioDevices = useCallback(async () => {
    setLoadingDevices(true);
    try {
      const devicesData = await invoke<AudioDeviceInfo[]>('get_audio_devices');
      setAudioDevices(devicesData);
    } catch (error) {
      console.error('Failed to refresh devices:', error);
    }
    setLoadingDevices(false);
  }, []);

  const currentPreset = presets.find(p => p.id === selectedPreset);

  return (
    <div className="app">
      {/* Header */}
      <header className="header">
        <h1 className="logo">CoherenceCore</h1>
        <nav className="nav">
          <button
            className={`nav-btn ${activeTab === 'stimulate' ? 'active' : ''}`}
            onClick={() => setActiveTab('stimulate')}
          >
            Stimulate
          </button>
          <button
            className={`nav-btn ${activeTab === 'scan' ? 'active' : ''}`}
            onClick={() => setActiveTab('scan')}
          >
            Scan
          </button>
          <button
            className={`nav-btn ${activeTab === 'settings' ? 'active' : ''}`}
            onClick={() => setActiveTab('settings')}
          >
            Settings
          </button>
        </nav>
      </header>

      {/* Main Content */}
      <main className="main">
        {activeTab === 'stimulate' && session && safetyLimits && (
          <div className="stimulate-view">
            {/* Cymatics Visualizer */}
            <div className="cymatics-section">
              <CymaticsCanvas
                frequencyHz={session.current_frequency_hz}
                amplitude={session.amplitude}
                isActive={session.is_playing}
                mode={cymaticsMode}
                size={180}
              />
              <div className="cymatics-info">
                <span className="cymatics-label">
                  {session.is_playing ? 'Wave Pattern' : 'Preview'}
                </span>
                <span className="cymatics-freq">
                  {session.current_frequency_hz.toFixed(1)} Hz
                </span>
              </div>
              <div className="cymatics-modes">
                {(['chladni', 'interference', 'ripple', 'standing'] as CymaticsMode[]).map(
                  (mode) => (
                    <button
                      key={mode}
                      className={`cymatics-mode-btn ${cymaticsMode === mode ? 'active' : ''}`}
                      onClick={() => setCymaticsMode(mode)}
                    >
                      {mode.charAt(0).toUpperCase() + mode.slice(1)}
                    </button>
                  )
                )}
              </div>
            </div>

            {/* Timer */}
            <div className="timer-section">
              <div className="timer-circle">
                <span className="timer-label">
                  {session.is_playing ? 'Remaining' : 'Session'}
                </span>
                <span className="timer-value">
                  {formatTime(
                    session.is_playing
                      ? Math.max(0, safetyLimits.maxSessionDurationMs - session.elapsed_ms)
                      : safetyLimits.maxSessionDurationMs
                  )}
                </span>
              </div>
            </div>

            {/* Presets */}
            <div className="presets-section">
              <h2>Frequency Presets</h2>
              <div className="presets-grid">
                {presets.map(preset => (
                  <button
                    key={preset.id}
                    className={`preset-card ${selectedPreset === preset.id ? 'selected' : ''}`}
                    onClick={() => handlePresetSelect(preset.id)}
                    disabled={session.is_playing}
                  >
                    <span className="preset-name">{preset.name}</span>
                    <span className="preset-freq">
                      {preset.frequency_range_hz[0]}-{preset.frequency_range_hz[1]} Hz
                    </span>
                    <span className="preset-research">{preset.research}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Controls */}
            <div className="controls-section">
              {/* Frequency */}
              <div className="control-group">
                <div className="control-header">
                  <span className="control-label">Frequency</span>
                  <span className="control-value">
                    {session.current_frequency_hz.toFixed(1)} Hz
                  </span>
                </div>
                <input
                  type="range"
                  min={currentPreset?.frequency_range_hz[0] || 1}
                  max={currentPreset?.frequency_range_hz[1] || 60}
                  step="0.1"
                  value={session.current_frequency_hz}
                  onChange={e => handleFrequencyChange(parseFloat(e.target.value))}
                  disabled={session.is_playing}
                  className="slider"
                />
              </div>

              {/* Amplitude */}
              <div className="control-group">
                <div className="control-header">
                  <span className="control-label">Amplitude</span>
                  <span className="control-value">
                    {Math.round(session.amplitude * 100)}%
                  </span>
                </div>
                <input
                  type="range"
                  min="0"
                  max={safetyLimits.maxAmplitude}
                  step="0.01"
                  value={session.amplitude}
                  onChange={e => handleAmplitudeChange(parseFloat(e.target.value))}
                  className="slider"
                />
              </div>
            </div>

            {/* Play Button */}
            <button
              className={`play-button ${session.is_playing ? 'stop' : ''}`}
              onClick={handleToggleSession}
            >
              {session.is_playing ? 'Stop Session' : 'Start Session'}
            </button>
          </div>
        )}

        {activeTab === 'scan' && (
          <div className="scan-view">
            {/* Camera Preview */}
            <div className="camera-section">
              <div className="camera-preview">
                <div className="camera-placeholder">
                  <span className="camera-icon">📷</span>
                  <span className="camera-text">Camera Preview</span>
                  <span className="camera-hint">Position target area in frame</span>
                </div>
              </div>
              <div className="camera-controls">
                <button className="scan-btn">Start Scan</button>
                <select className="camera-select">
                  <option value="">Select Camera...</option>
                  <option value="default">Default Webcam</option>
                </select>
              </div>
            </div>

            {/* Analysis Results */}
            <div className="analysis-section">
              <h3>EVM Analysis</h3>
              <div className="analysis-grid">
                <div className="analysis-card">
                  <span className="analysis-label">Detected Frequency</span>
                  <span className="analysis-value">-- Hz</span>
                  <span className="analysis-range">Target: 1-60 Hz</span>
                </div>
                <div className="analysis-card">
                  <span className="analysis-label">Amplitude</span>
                  <span className="analysis-value">-- μm</span>
                  <span className="analysis-range">Micro-displacement</span>
                </div>
                <div className="analysis-card">
                  <span className="analysis-label">Signal Quality</span>
                  <span className="analysis-value">--%</span>
                  <span className="analysis-range">SNR indicator</span>
                </div>
                <div className="analysis-card">
                  <span className="analysis-label">Frame Rate</span>
                  <span className="analysis-value">-- fps</span>
                  <span className="analysis-range">Min: 60 fps for Nyquist</span>
                </div>
              </div>
            </div>

            {/* Frequency Spectrum */}
            <div className="spectrum-section">
              <h3>Frequency Spectrum</h3>
              <div className="spectrum-chart">
                <div className="spectrum-placeholder">
                  <div className="spectrum-bar" style={{ height: '20%' }} />
                  <div className="spectrum-bar" style={{ height: '35%' }} />
                  <div className="spectrum-bar" style={{ height: '60%' }} />
                  <div className="spectrum-bar" style={{ height: '80%' }} />
                  <div className="spectrum-bar" style={{ height: '45%' }} />
                  <div className="spectrum-bar" style={{ height: '30%' }} />
                  <div className="spectrum-bar" style={{ height: '15%' }} />
                  <div className="spectrum-bar" style={{ height: '10%' }} />
                </div>
                <div className="spectrum-labels">
                  <span>0 Hz</span>
                  <span>15 Hz</span>
                  <span>30 Hz</span>
                  <span>45 Hz</span>
                  <span>60 Hz</span>
                </div>
              </div>
            </div>

            {/* Info */}
            <div className="scan-info">
              <p>EVM (Eulerian Video Magnification) detects micro-vibrations invisible to the naked eye.</p>
              <p className="note">Requires stable camera mount and good lighting for optimal results.</p>
            </div>
          </div>
        )}

        {activeTab === 'settings' && safetyLimits && (
          <div className="settings-view">
            {/* Audio Device Settings */}
            <h2>Audio Device</h2>
            <div className="settings-group">
              <div className="setting-row">
                <span>Output Device</span>
                <div className="setting-control">
                  <select
                    className="device-select"
                    value={audioConfig?.device_id || ''}
                    onChange={e => handleDeviceChange(e.target.value)}
                    disabled={session?.is_playing}
                  >
                    <option value="">System Default</option>
                    {audioDevices.map(device => (
                      <option key={device.id} value={device.id}>
                        {device.is_usb ? '🎛️ ' : ''}{device.name}
                        {device.is_default ? ' (Default)' : ''}
                      </option>
                    ))}
                  </select>
                  <button
                    className="refresh-btn"
                    onClick={refreshAudioDevices}
                    disabled={loadingDevices}
                    title="Refresh devices"
                  >
                    {loadingDevices ? '...' : '↻'}
                  </button>
                </div>
              </div>
              <div className="setting-row">
                <span>Sample Rate</span>
                <select
                  className="rate-select"
                  value={audioConfig?.sample_rate || 44100}
                  onChange={e => handleSampleRateChange(parseInt(e.target.value))}
                  disabled={session?.is_playing}
                >
                  <option value={44100}>44.1 kHz</option>
                  <option value={48000}>48 kHz</option>
                  <option value={88200}>88.2 kHz</option>
                  <option value={96000}>96 kHz</option>
                  <option value={176400}>176.4 kHz</option>
                  <option value={192000}>192 kHz</option>
                </select>
              </div>
              <div className="setting-row">
                <span>Buffer Size</span>
                <select
                  className="buffer-select"
                  value={audioConfig?.buffer_size || 512}
                  onChange={e => handleBufferSizeChange(parseInt(e.target.value))}
                  disabled={session?.is_playing}
                >
                  <option value={64}>64 samples (~1.5ms)</option>
                  <option value={128}>128 samples (~3ms)</option>
                  <option value={256}>256 samples (~6ms)</option>
                  <option value={512}>512 samples (~12ms)</option>
                  <option value={1024}>1024 samples (~23ms)</option>
                  <option value={2048}>2048 samples (~46ms)</option>
                </select>
              </div>
              {audioDevices.length > 0 && (
                <div className="device-info">
                  <span className="device-count">
                    {audioDevices.filter(d => d.is_usb).length} USB interface(s) detected
                  </span>
                </div>
              )}
            </div>

            <h2>Safety Limits</h2>
            <div className="settings-group">
              <div className="setting-row">
                <span>Max Session Duration</span>
                <span>{safetyLimits.maxSessionDurationMs / 60000} minutes</span>
              </div>
              <div className="setting-row">
                <span>Max Amplitude</span>
                <span>{Math.round(safetyLimits.maxAmplitude * 100)}%</span>
              </div>
              <div className="setting-row">
                <span>Max Duty Cycle</span>
                <span>{Math.round(safetyLimits.maxDutyCycle * 100)}%</span>
              </div>
            </div>

            <h2>About</h2>
            <div className="settings-group">
              <div className="setting-row">
                <span>Version</span>
                <span>0.1.0</span>
              </div>
              <div className="setting-row">
                <span>Platform</span>
                <span>Tauri 2.0</span>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Disclaimer */}
      <footer className="footer">
        <p className="disclaimer">{disclaimer}</p>
      </footer>
    </div>
  );
}
