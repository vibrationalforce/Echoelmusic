/**
 * useDisclaimerManagement Hook
 *
 * SINGLE SOURCE OF TRUTH for disclaimer state.
 *
 * Fixes critical bug where disclaimer was tracked in two places:
 * - useCoherenceEngine.session.disclaimerAcknowledged (ephemeral)
 * - useSettings.settings.disclaimerAccepted (persisted)
 *
 * Now: One persisted state, one modal, one API.
 */

import { useState, useCallback, useEffect } from 'react';
import { Alert } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { DISCLAIMER_TEXT } from '@coherence-core/shared-types';

const DISCLAIMER_STORAGE_KEY = '@coherence_core_disclaimer';

export interface DisclaimerState {
  /** Whether user has acknowledged the disclaimer */
  isAcknowledged: boolean;
  /** Timestamp when disclaimer was acknowledged (null if never) */
  acknowledgedAt: number | null;
  /** Whether disclaimer state is still loading from storage */
  isLoading: boolean;
}

interface DisclaimerActions {
  /** Show the disclaimer modal and wait for response */
  showModal: () => Promise<boolean>;
  /** Programmatically acknowledge (for testing/reset) */
  acknowledge: () => void;
  /** Reset disclaimer (for testing/settings) */
  reset: () => void;
  /** Check if disclaimer is required before action, show modal if needed */
  requireAcknowledgment: () => Promise<boolean>;
}

export type UseDisclaimerManagementReturn = DisclaimerState & DisclaimerActions;

const FULL_DISCLAIMER_MESSAGE = `${DISCLAIMER_TEXT}

This application is designed for wellness and informational purposes only. It is NOT a medical device and should not be used to diagnose, treat, cure, or prevent any disease or health condition.

By proceeding, you acknowledge that:
• You have read and understood this disclaimer
• You will not use this tool as a substitute for professional medical advice
• You will stop use immediately if you experience any discomfort`;

/**
 * Unified disclaimer management hook.
 *
 * SINGLE SOURCE OF TRUTH - persisted to AsyncStorage.
 *
 * @example
 * const disclaimer = useDisclaimerManagement();
 *
 * // Check before starting session
 * const canProceed = await disclaimer.requireAcknowledgment();
 * if (!canProceed) return;
 *
 * // Or check state directly
 * if (disclaimer.isAcknowledged) {
 *   startSession();
 * }
 */
export function useDisclaimerManagement(): UseDisclaimerManagementReturn {
  const [state, setState] = useState<DisclaimerState>({
    isAcknowledged: false,
    acknowledgedAt: null,
    isLoading: true,
  });

  // Load persisted state on mount
  useEffect(() => {
    const loadState = async () => {
      try {
        const stored = await AsyncStorage.getItem(DISCLAIMER_STORAGE_KEY);
        if (stored) {
          const parsed = JSON.parse(stored) as Pick<DisclaimerState, 'isAcknowledged' | 'acknowledgedAt'>;
          setState({
            isAcknowledged: parsed.isAcknowledged ?? false,
            acknowledgedAt: parsed.acknowledgedAt ?? null,
            isLoading: false,
          });
        } else {
          setState(prev => ({ ...prev, isLoading: false }));
        }
      } catch (error) {
        console.error('[DisclaimerManagement] Failed to load state:', error);
        setState(prev => ({ ...prev, isLoading: false }));
      }
    };

    loadState();
  }, []);

  // Persist state changes
  const persistState = useCallback(async (newState: Pick<DisclaimerState, 'isAcknowledged' | 'acknowledgedAt'>) => {
    try {
      await AsyncStorage.setItem(DISCLAIMER_STORAGE_KEY, JSON.stringify(newState));
    } catch (error) {
      console.error('[DisclaimerManagement] Failed to persist state:', error);
    }
  }, []);

  // Acknowledge the disclaimer
  const acknowledge = useCallback(() => {
    const now = Date.now();
    const newState = {
      isAcknowledged: true,
      acknowledgedAt: now,
    };
    setState(prev => ({ ...prev, ...newState }));
    persistState(newState);
    console.log('[DisclaimerManagement] Disclaimer acknowledged');
  }, [persistState]);

  // Reset the disclaimer (for testing/settings)
  const reset = useCallback(() => {
    const newState = {
      isAcknowledged: false,
      acknowledgedAt: null,
    };
    setState(prev => ({ ...prev, ...newState }));
    persistState(newState);
    console.log('[DisclaimerManagement] Disclaimer reset');
  }, [persistState]);

  // Show disclaimer modal
  const showModal = useCallback((): Promise<boolean> => {
    return new Promise<boolean>((resolve) => {
      Alert.alert(
        'Wellness Tool Disclaimer',
        FULL_DISCLAIMER_MESSAGE,
        [
          {
            text: 'Cancel',
            style: 'cancel',
            onPress: () => {
              console.log('[DisclaimerManagement] User cancelled disclaimer');
              resolve(false);
            },
          },
          {
            text: 'I Understand',
            onPress: () => {
              acknowledge();
              resolve(true);
            },
          },
        ],
        { cancelable: false }
      );
    });
  }, [acknowledge]);

  // Require acknowledgment before proceeding
  const requireAcknowledgment = useCallback(async (): Promise<boolean> => {
    if (state.isAcknowledged) {
      return true;
    }
    return showModal();
  }, [state.isAcknowledged, showModal]);

  return {
    ...state,
    showModal,
    acknowledge,
    reset,
    requireAcknowledgment,
  };
}

export default useDisclaimerManagement;
