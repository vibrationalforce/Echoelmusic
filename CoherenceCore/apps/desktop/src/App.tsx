/**
 * CoherenceCore Desktop App
 *
 * Tauri 2.0 frontend for Windows and Linux.
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import { useState, useEffect, useCallback } from 'react';
import { invoke } from '@tauri-apps/api/core';

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

  // Load initial data
  useEffect(() => {
    const loadData = async () => {
      try {
        const [presetsData, sessionData, limitsData, disclaimerData] = await Promise.all([
          invoke<FrequencyPreset[]>('get_presets'),
          invoke<SessionState>('get_session_state'),
          invoke<SafetyLimits>('get_safety_limits'),
          invoke<string>('get_disclaimer'),
        ]);
        setPresets(presetsData);
        setSession(sessionData);
        setSafetyLimits(limitsData);
        setDisclaimer(disclaimerData);
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
            <div className="placeholder">
              <h2>EVM Scanner</h2>
              <p>Camera-based micro-vibration detection</p>
              <p className="note">
                Requires camera access. Use crabcamera for desktop capture.
              </p>
            </div>
          </div>
        )}

        {activeTab === 'settings' && safetyLimits && (
          <div className="settings-view">
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
