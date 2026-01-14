/**
 * CoherenceCore Home Screen
 *
 * Main dashboard with access to Scan (EVM) and Stimulate (VAT) features.
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import { View, Text, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';
import { Link } from 'expo-router';
import { FREQUENCY_PRESETS, DISCLAIMER_TEXT } from '@coherence-core/shared-types';

export default function HomeScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerIcon}>🔬</Text>
        <Text style={styles.headerTitle}>CoherenceCore</Text>
        <Text style={styles.headerSubtitle}>Biophysical Resonance Framework</Text>
      </View>

      {/* Disclaimer Banner */}
      <View style={styles.disclaimerBanner}>
        <Text style={styles.disclaimerText}>{DISCLAIMER_TEXT}</Text>
      </View>

      {/* Main Actions */}
      <View style={styles.actionsContainer}>
        <Link href="/scan" asChild>
          <TouchableOpacity style={[styles.actionCard, styles.scanCard]}>
            <Text style={styles.actionIcon}>📷</Text>
            <Text style={styles.actionTitle}>Scan</Text>
            <Text style={styles.actionSubtitle}>EVM Analysis (1-60 Hz)</Text>
            <Text style={styles.actionDescription}>
              Detect micro-vibrations using Eulerian Video Magnification
            </Text>
          </TouchableOpacity>
        </Link>

        <Link href="/stimulate" asChild>
          <TouchableOpacity style={[styles.actionCard, styles.stimulateCard]}>
            <Text style={styles.actionIcon}>🔊</Text>
            <Text style={styles.actionTitle}>Stimulate</Text>
            <Text style={styles.actionSubtitle}>VAT Output (35-50 Hz)</Text>
            <Text style={styles.actionDescription}>
              Generate coherent frequencies via sound & haptics
            </Text>
          </TouchableOpacity>
        </Link>
      </View>

      {/* Preset Quick Access */}
      <View style={styles.presetsContainer}>
        <Text style={styles.sectionTitle}>Evidence-Based Presets</Text>

        {Object.values(FREQUENCY_PRESETS).filter(p => p.id !== 'custom').map((preset) => (
          <View key={preset.id} style={styles.presetCard}>
            <View style={styles.presetHeader}>
              <Text style={styles.presetName}>{preset.name}</Text>
              <Text style={styles.presetFrequency}>
                {preset.frequencyRangeHz[0]}-{preset.frequencyRangeHz[1]} Hz
              </Text>
            </View>
            <Text style={styles.presetTarget}>{preset.target}</Text>
            <Text style={styles.presetResearch}>{preset.research}</Text>
          </View>
        ))}
      </View>

      {/* Safety Info */}
      <View style={styles.safetyContainer}>
        <Text style={styles.sectionTitle}>Safety Limits</Text>
        <View style={styles.safetyGrid}>
          <View style={styles.safetyItem}>
            <Text style={styles.safetyIcon}>⏱️</Text>
            <Text style={styles.safetyLabel}>Max Session</Text>
            <Text style={styles.safetyValue}>15 min</Text>
          </View>
          <View style={styles.safetyItem}>
            <Text style={styles.safetyIcon}>📊</Text>
            <Text style={styles.safetyLabel}>Max Amplitude</Text>
            <Text style={styles.safetyValue}>80%</Text>
          </View>
          <View style={styles.safetyItem}>
            <Text style={styles.safetyIcon}>⚡</Text>
            <Text style={styles.safetyLabel}>Duty Cycle</Text>
            <Text style={styles.safetyValue}>70%</Text>
          </View>
          <View style={styles.safetyItem}>
            <Text style={styles.safetyIcon}>❄️</Text>
            <Text style={styles.safetyLabel}>Cooldown</Text>
            <Text style={styles.safetyValue}>5 min</Text>
          </View>
        </View>
      </View>

      {/* Footer Disclaimer */}
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          This is a wellness exploration tool. Not a medical device.
          Consult healthcare professionals for medical concerns.
        </Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  content: {
    padding: 16,
  },
  header: {
    alignItems: 'center',
    marginBottom: 24,
    paddingTop: 16,
  },
  headerIcon: {
    fontSize: 48,
    marginBottom: 8,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
  },
  headerSubtitle: {
    fontSize: 14,
    color: '#888',
  },
  disclaimerBanner: {
    backgroundColor: 'rgba(255,165,0,0.1)',
    borderRadius: 8,
    padding: 12,
    marginBottom: 24,
    borderWidth: 1,
    borderColor: 'rgba(255,165,0,0.3)',
  },
  disclaimerText: {
    color: '#FFA500',
    fontSize: 12,
    textAlign: 'center',
    fontWeight: 'bold',
  },
  actionsContainer: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 24,
  },
  actionCard: {
    flex: 1,
    borderRadius: 16,
    padding: 16,
    alignItems: 'center',
  },
  scanCard: {
    backgroundColor: 'rgba(0,206,209,0.2)',
    borderWidth: 1,
    borderColor: 'rgba(0,206,209,0.5)',
  },
  stimulateCard: {
    backgroundColor: 'rgba(255,99,71,0.2)',
    borderWidth: 1,
    borderColor: 'rgba(255,99,71,0.5)',
  },
  actionIcon: {
    fontSize: 32,
    marginBottom: 8,
  },
  actionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#fff',
  },
  actionSubtitle: {
    fontSize: 12,
    color: '#888',
    marginBottom: 8,
  },
  actionDescription: {
    fontSize: 11,
    color: '#666',
    textAlign: 'center',
  },
  presetsContainer: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 12,
  },
  presetCard: {
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
  },
  presetHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  presetName: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#fff',
  },
  presetFrequency: {
    fontSize: 12,
    color: '#00CED1',
    fontWeight: 'bold',
  },
  presetTarget: {
    fontSize: 12,
    color: '#888',
    marginBottom: 4,
  },
  presetResearch: {
    fontSize: 10,
    color: '#666',
    fontStyle: 'italic',
  },
  safetyContainer: {
    marginBottom: 24,
  },
  safetyGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  safetyItem: {
    flex: 1,
    minWidth: '45%',
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
  },
  safetyIcon: {
    fontSize: 24,
    marginBottom: 4,
  },
  safetyLabel: {
    fontSize: 10,
    color: '#888',
  },
  safetyValue: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#fff',
  },
  footer: {
    paddingVertical: 16,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.1)',
  },
  footerText: {
    fontSize: 10,
    color: '#666',
    textAlign: 'center',
    lineHeight: 14,
  },
});
