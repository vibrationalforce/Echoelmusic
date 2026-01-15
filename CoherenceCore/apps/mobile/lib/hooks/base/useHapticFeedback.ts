/**
 * useHapticFeedback Hook
 *
 * Unified haptic control with frequency synchronization.
 * Consolidates haptic patterns from useCoherenceEngine.
 *
 * Features:
 * - Frequency-synchronized haptics
 * - Single pulse feedback
 * - Platform-safe (no-op on web)
 * - Auto-cleanup on unmount
 */

import { useRef, useCallback, useEffect } from 'react';
import { Platform, Vibration } from 'react-native';

// Default haptic interval for general feedback
const DEFAULT_HAPTIC_INTERVAL_MS = 250;
const MIN_HAPTIC_DURATION_MS = 20;

export interface HapticFeedbackControls {
  /** Start synchronized haptics at given frequency */
  startSynchronized: (frequencyHz: number) => void;
  /** Stop all haptics */
  stop: () => void;
  /** Single pulse feedback */
  pulse: (durationMs?: number) => void;
  /** Selection feedback (light pulse) */
  selection: () => void;
  /** Success feedback (double pulse) */
  success: () => void;
  /** Warning feedback (strong pulse) */
  warning: () => void;
}

/**
 * Unified haptic feedback hook.
 *
 * @returns Haptic control methods
 *
 * @example
 * const haptic = useHapticFeedback();
 *
 * // Synchronized with frequency
 * haptic.startSynchronized(40); // 40 Hz
 *
 * // Feedback pulses
 * haptic.selection();
 * haptic.success();
 * haptic.pulse(50);
 */
export function useHapticFeedback(): HapticFeedbackControls {
  const hapticRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (hapticRef.current) {
        clearInterval(hapticRef.current);
        hapticRef.current = null;
      }
      if (Platform.OS !== 'web') {
        Vibration.cancel();
      }
    };
  }, []);

  const stop = useCallback(() => {
    if (hapticRef.current) {
      clearInterval(hapticRef.current);
      hapticRef.current = null;
    }
    if (Platform.OS !== 'web') {
      Vibration.cancel();
    }
  }, []);

  const startSynchronized = useCallback((frequencyHz: number) => {
    if (Platform.OS === 'web') return;

    // Stop any existing haptic loop
    stop();

    // Calculate interval from frequency
    // For low frequencies (<10Hz), use actual period
    // For higher frequencies, use fixed interval (haptics can't keep up)
    const hapticIntervalMs = frequencyHz < 10
      ? Math.round(1000 / frequencyHz)
      : DEFAULT_HAPTIC_INTERVAL_MS;

    hapticRef.current = setInterval(() => {
      Vibration.vibrate(MIN_HAPTIC_DURATION_MS);
    }, hapticIntervalMs);

    console.log(`[HapticFeedback] Started at ${hapticIntervalMs}ms intervals`);
  }, [stop]);

  const pulse = useCallback((durationMs: number = MIN_HAPTIC_DURATION_MS) => {
    if (Platform.OS === 'web') return;
    Vibration.vibrate(durationMs);
  }, []);

  const selection = useCallback(() => {
    pulse(10);
  }, [pulse]);

  const success = useCallback(() => {
    if (Platform.OS === 'web') return;
    // Double pulse pattern
    Vibration.vibrate([0, 30, 50, 30]);
  }, []);

  const warning = useCallback(() => {
    pulse(100);
  }, [pulse]);

  return {
    startSynchronized,
    stop,
    pulse,
    selection,
    success,
    warning,
  };
}

export default useHapticFeedback;
