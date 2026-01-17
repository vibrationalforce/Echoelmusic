/**
 * CoherenceCore Mobile App Layout
 *
 * Root layout with navigation and disclaimer enforcement.
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { DISCLAIMER_TEXT } from '@coherence-core/shared-types';

export default function RootLayout() {
  const [disclaimerAccepted, setDisclaimerAccepted] = useState(false);

  if (!disclaimerAccepted) {
    return <DisclaimerOverlay onAccept={() => setDisclaimerAccepted(true)} />;
  }

  return (
    <>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: '#000' },
          headerTintColor: '#fff',
          headerTitleStyle: { fontWeight: 'bold' },
          contentStyle: { backgroundColor: '#000' },
        }}
      >
        <Stack.Screen
          name="index"
          options={{
            title: 'CoherenceCore',
            headerRight: () => <DisclaimerBadge />,
          }}
        />
        <Stack.Screen
          name="scan"
          options={{ title: 'Scan (EVM)' }}
        />
        <Stack.Screen
          name="stimulate"
          options={{ title: 'Stimulate (VAT)' }}
        />
        <Stack.Screen
          name="settings"
          options={{ title: 'Settings' }}
        />
      </Stack>
    </>
  );
}

function DisclaimerOverlay({ onAccept }: { onAccept: () => void }) {
  return (
    <View style={styles.overlay}>
      <View style={styles.overlayContent}>
        <Text style={styles.overlayIcon}>🔬</Text>
        <Text style={styles.overlayTitle}>CoherenceCore</Text>
        <Text style={styles.overlaySubtitle}>Biophysical Resonance Tool</Text>

        <View style={styles.disclaimerBox}>
          <Text style={styles.disclaimerItem}>ℹ️ Wellness & Informational Use Only</Text>
          <Text style={styles.disclaimerItem}>⚠️ No Medical Claims Made</Text>
          <Text style={styles.disclaimerItem}>🏥 Consult Healthcare Professionals</Text>
          <Text style={styles.disclaimerItem}>⏱️ 15 Minute Session Limit</Text>
        </View>

        <Text style={styles.disclaimerText}>
          This tool explores frequency-based biofeedback for wellness purposes.
          It is NOT a medical device and makes no medical claims.
        </Text>

        <TouchableOpacity style={styles.acceptButton} onPress={onAccept}>
          <Text style={styles.acceptButtonText}>I Understand - Continue</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

function DisclaimerBadge() {
  return (
    <View style={styles.badge}>
      <Text style={styles.badgeText}>{DISCLAIMER_TEXT}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: '#000',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  overlayContent: {
    alignItems: 'center',
    maxWidth: 400,
  },
  overlayIcon: {
    fontSize: 64,
    marginBottom: 16,
  },
  overlayTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 8,
  },
  overlaySubtitle: {
    fontSize: 16,
    color: '#888',
    marginBottom: 32,
  },
  disclaimerBox: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 12,
    padding: 16,
    marginBottom: 24,
    width: '100%',
  },
  disclaimerItem: {
    color: '#fff',
    fontSize: 14,
    marginBottom: 8,
  },
  disclaimerText: {
    color: '#888',
    fontSize: 12,
    textAlign: 'center',
    marginBottom: 32,
    lineHeight: 18,
  },
  acceptButton: {
    backgroundColor: '#00CED1',
    paddingVertical: 16,
    paddingHorizontal: 32,
    borderRadius: 12,
    width: '100%',
  },
  acceptButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  badge: {
    backgroundColor: 'rgba(255,165,0,0.2)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    marginRight: 8,
  },
  badgeText: {
    color: '#FFA500',
    fontSize: 8,
    fontWeight: 'bold',
  },
});
