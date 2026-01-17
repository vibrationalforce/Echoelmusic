/**
 * CoherenceCore Settings Hook
 *
 * Provides persistent settings storage using AsyncStorage.
 * Settings are automatically loaded on mount and saved on change.
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import { useState, useEffect, useCallback } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

// ============================================================================
// TYPES
// ============================================================================

export interface Settings {
  // Audio
  hapticFeedback: boolean;
  backgroundAudio: boolean;
  autoStopOnBackground: boolean;
  lowLatencyMode: boolean;

  // Display
  showResearchCitations: boolean;
  darkMode: boolean;

  // Session
  defaultPreset: string;
  defaultAmplitude: number;

  // Compliance
  disclaimerAccepted: boolean;
  lastDisclaimerAcceptedAt: number | null;
}

// ============================================================================
// CONSTANTS
// ============================================================================

const SETTINGS_KEY = '@coherence_core_settings';

const DEFAULT_SETTINGS: Settings = {
  // Audio
  hapticFeedback: true,
  backgroundAudio: true,
  autoStopOnBackground: false,
  lowLatencyMode: Platform.OS === 'ios',

  // Display
  showResearchCitations: true,
  darkMode: true,

  // Session
  defaultPreset: 'osteo-sync',
  defaultAmplitude: 0.5,

  // Compliance
  disclaimerAccepted: false,
  lastDisclaimerAcceptedAt: null,
};

// ============================================================================
// HOOK
// ============================================================================

export function useSettings() {
  const [settings, setSettingsState] = useState<Settings>(DEFAULT_SETTINGS);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load settings on mount
  useEffect(() => {
    loadSettings();
  }, []);

  // Load settings from AsyncStorage
  const loadSettings = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);

      const stored = await AsyncStorage.getItem(SETTINGS_KEY);
      if (stored) {
        const parsed = JSON.parse(stored) as Partial<Settings>;
        // Merge with defaults to handle new settings fields
        setSettingsState({ ...DEFAULT_SETTINGS, ...parsed });
        console.log('[Settings] Loaded from storage');
      } else {
        console.log('[Settings] Using defaults (no stored settings)');
      }
    } catch (err) {
      console.error('[Settings] Failed to load:', err);
      setError('Failed to load settings');
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Save settings to AsyncStorage
  const saveSettings = useCallback(async (newSettings: Settings) => {
    try {
      await AsyncStorage.setItem(SETTINGS_KEY, JSON.stringify(newSettings));
      console.log('[Settings] Saved to storage');
    } catch (err) {
      console.error('[Settings] Failed to save:', err);
      setError('Failed to save settings');
    }
  }, []);

  // Update a single setting
  const setSetting = useCallback(<K extends keyof Settings>(
    key: K,
    value: Settings[K]
  ) => {
    setSettingsState(prev => {
      const newSettings = { ...prev, [key]: value };
      saveSettings(newSettings);
      return newSettings;
    });
  }, [saveSettings]);

  // Update multiple settings at once
  const setSettings = useCallback((updates: Partial<Settings>) => {
    setSettingsState(prev => {
      const newSettings = { ...prev, ...updates };
      saveSettings(newSettings);
      return newSettings;
    });
  }, [saveSettings]);

  // Reset to defaults
  const resetSettings = useCallback(async () => {
    try {
      await AsyncStorage.removeItem(SETTINGS_KEY);
      setSettingsState(DEFAULT_SETTINGS);
      console.log('[Settings] Reset to defaults');
    } catch (err) {
      console.error('[Settings] Failed to reset:', err);
      setError('Failed to reset settings');
    }
  }, []);

  // Mark disclaimer as accepted
  const acceptDisclaimer = useCallback(() => {
    const now = Date.now();
    setSettingsState(prev => {
      const newSettings = {
        ...prev,
        disclaimerAccepted: true,
        lastDisclaimerAcceptedAt: now,
      };
      saveSettings(newSettings);
      return newSettings;
    });
  }, [saveSettings]);

  return {
    settings,
    isLoading,
    error,

    // Actions
    setSetting,
    setSettings,
    resetSettings,
    loadSettings,
    acceptDisclaimer,

    // Convenience accessors
    isDisclaimerAccepted: settings.disclaimerAccepted,
  };
}

export default useSettings;
