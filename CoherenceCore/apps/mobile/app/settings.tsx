/**
 * CoherenceCore Settings Screen
 *
 * Configuration options for audio output, safety limits,
 * and general app preferences with persistent storage.
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Switch,
  Platform,
  Linking,
  ActivityIndicator,
} from 'react-native';
import { router } from 'expo-router';
import { DEFAULT_SAFETY_LIMITS, DISCLAIMER_TEXT } from '@coherence-core/shared-types';
import { useSettings } from '../lib/useSettings';

export default function SettingsScreen() {
  const {
    settings,
    isLoading,
    setSetting,
    resetSettings,
  } = useSettings();

  const openLink = (url: string) => {
    Linking.openURL(url);
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#00E5FF" />
        <Text style={styles.loadingText}>Loading settings...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity style={styles.backButton} onPress={() => router.back()}>
          <Text style={styles.backButtonText}>← Back</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Settings</Text>
        <View style={styles.placeholder} />
      </View>

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Audio Settings */}
        <Text style={styles.sectionTitle}>Audio</Text>
        <View style={styles.settingsGroup}>
          <View style={styles.settingRow}>
            <View>
              <Text style={styles.settingLabel}>Background Audio</Text>
              <Text style={styles.settingDescription}>
                Continue playing when app is backgrounded
              </Text>
            </View>
            <Switch
              value={settings.backgroundAudio}
              onValueChange={(value) => setSetting('backgroundAudio', value)}
              trackColor={{ false: '#333', true: '#00E5FF' }}
              thumbColor="#fff"
            />
          </View>

          <View style={styles.settingRow}>
            <View>
              <Text style={styles.settingLabel}>Low Latency Mode</Text>
              <Text style={styles.settingDescription}>
                Reduce audio latency (may increase CPU usage)
              </Text>
            </View>
            <Switch
              value={settings.lowLatencyMode}
              onValueChange={(value) => setSetting('lowLatencyMode', value)}
              trackColor={{ false: '#333', true: '#00E5FF' }}
              thumbColor="#fff"
            />
          </View>

          <View style={styles.settingRow}>
            <View>
              <Text style={styles.settingLabel}>Auto-Stop on Background</Text>
              <Text style={styles.settingDescription}>
                Automatically stop session when leaving app
              </Text>
            </View>
            <Switch
              value={settings.autoStopOnBackground}
              onValueChange={(value) => setSetting('autoStopOnBackground', value)}
              trackColor={{ false: '#333', true: '#00E5FF' }}
              thumbColor="#fff"
            />
          </View>
        </View>

        {/* Feedback Settings */}
        <Text style={styles.sectionTitle}>Feedback</Text>
        <View style={styles.settingsGroup}>
          <View style={styles.settingRow}>
            <View>
              <Text style={styles.settingLabel}>Haptic Feedback</Text>
              <Text style={styles.settingDescription}>
                Vibration feedback for interactions
              </Text>
            </View>
            <Switch
              value={settings.hapticFeedback}
              onValueChange={(value) => setSetting('hapticFeedback', value)}
              trackColor={{ false: '#333', true: '#00E5FF' }}
              thumbColor="#fff"
            />
          </View>
        </View>

        {/* Display Settings */}
        <Text style={styles.sectionTitle}>Display</Text>
        <View style={styles.settingsGroup}>
          <View style={styles.settingRow}>
            <View>
              <Text style={styles.settingLabel}>Show Research Citations</Text>
              <Text style={styles.settingDescription}>
                Display scientific references for presets
              </Text>
            </View>
            <Switch
              value={settings.showResearchCitations}
              onValueChange={(value) => setSetting('showResearchCitations', value)}
              trackColor={{ false: '#333', true: '#00E5FF' }}
              thumbColor="#fff"
            />
          </View>
        </View>

        {/* Safety Limits (Read Only) */}
        <Text style={styles.sectionTitle}>Safety Limits</Text>
        <View style={styles.settingsGroup}>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Max Session Duration</Text>
            <Text style={styles.infoValue}>
              {DEFAULT_SAFETY_LIMITS.maxSessionDurationMs / 60000} minutes
            </Text>
          </View>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Max Amplitude</Text>
            <Text style={styles.infoValue}>
              {Math.round(DEFAULT_SAFETY_LIMITS.maxAmplitude * 100)}%
            </Text>
          </View>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Max Duty Cycle</Text>
            <Text style={styles.infoValue}>
              {Math.round(DEFAULT_SAFETY_LIMITS.maxDutyCycle * 100)}%
            </Text>
          </View>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Cooldown Period</Text>
            <Text style={styles.infoValue}>
              {DEFAULT_SAFETY_LIMITS.cooldownPeriodMs / 60000} minutes
            </Text>
          </View>
          <Text style={styles.safetyNote}>
            These limits are enforced for your safety and cannot be changed.
          </Text>
        </View>

        {/* About */}
        <Text style={styles.sectionTitle}>About</Text>
        <View style={styles.settingsGroup}>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Version</Text>
            <Text style={styles.infoValue}>0.1.0</Text>
          </View>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Build</Text>
            <Text style={styles.infoValue}>2026.01.14</Text>
          </View>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Platform</Text>
            <Text style={styles.infoValue}>{Platform.OS}</Text>
          </View>
        </View>

        {/* Links */}
        <Text style={styles.sectionTitle}>Resources</Text>
        <View style={styles.settingsGroup}>
          <TouchableOpacity
            style={styles.linkRow}
            onPress={() => openLink('https://github.com/coherence-core')}
          >
            <Text style={styles.linkLabel}>Documentation</Text>
            <Text style={styles.linkArrow}>→</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.linkRow}
            onPress={() => openLink('https://github.com/coherence-core/issues')}
          >
            <Text style={styles.linkLabel}>Report an Issue</Text>
            <Text style={styles.linkArrow}>→</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.linkRow}
            onPress={() => openLink('https://coherence-core.dev/privacy')}
          >
            <Text style={styles.linkLabel}>Privacy Policy</Text>
            <Text style={styles.linkArrow}>→</Text>
          </TouchableOpacity>
        </View>

        {/* Reset Settings */}
        <Text style={styles.sectionTitle}>Data</Text>
        <View style={styles.settingsGroup}>
          <TouchableOpacity
            style={styles.dangerRow}
            onPress={resetSettings}
          >
            <Text style={styles.dangerLabel}>Reset All Settings</Text>
            <Text style={styles.dangerDescription}>
              Restore default settings and clear saved data
            </Text>
          </TouchableOpacity>
        </View>

        {/* Disclaimer */}
        <View style={styles.disclaimerSection}>
          <Text style={styles.disclaimerTitle}>Important Disclaimer</Text>
          <Text style={styles.disclaimerText}>{DISCLAIMER_TEXT}</Text>
          <Text style={styles.disclaimerText}>
            This application is designed for general wellness purposes only.
            It is not intended to diagnose, treat, cure, or prevent any disease.
            Always consult with a healthcare professional before starting any
            new wellness program.
          </Text>
        </View>

        <View style={{ height: 50 }} />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  loadingContainer: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    color: '#888',
    marginTop: 12,
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
  sectionTitle: {
    color: '#888',
    fontSize: 14,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginTop: 25,
    marginBottom: 10,
  },
  settingsGroup: {
    backgroundColor: '#1a1a1a',
    borderRadius: 12,
    overflow: 'hidden',
  },
  settingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a2a',
  },
  settingLabel: {
    color: '#fff',
    fontSize: 16,
    marginBottom: 3,
  },
  settingDescription: {
    color: '#666',
    fontSize: 12,
    maxWidth: 250,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a2a',
  },
  infoLabel: {
    color: '#888',
    fontSize: 14,
  },
  infoValue: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  safetyNote: {
    color: '#666',
    fontSize: 12,
    fontStyle: 'italic',
    padding: 15,
    paddingTop: 10,
  },
  linkRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a2a',
  },
  linkLabel: {
    color: '#00E5FF',
    fontSize: 16,
  },
  linkArrow: {
    color: '#00E5FF',
    fontSize: 18,
  },
  dangerRow: {
    padding: 15,
  },
  dangerLabel: {
    color: '#FF5252',
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  dangerDescription: {
    color: '#888',
    fontSize: 12,
  },
  disclaimerSection: {
    backgroundColor: 'rgba(255,152,0,0.1)',
    padding: 15,
    borderRadius: 12,
    marginTop: 25,
    borderWidth: 1,
    borderColor: 'rgba(255,152,0,0.3)',
  },
  disclaimerTitle: {
    color: '#FF9800',
    fontSize: 14,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  disclaimerText: {
    color: '#888',
    fontSize: 12,
    lineHeight: 18,
    marginBottom: 10,
  },
});
