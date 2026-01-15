/**
 * usePersistentState Hook
 *
 * Generic persistent state with AsyncStorage.
 * Replaces boilerplate load/save patterns in useSettings.
 *
 * Features:
 * - Automatic load on mount
 * - Automatic save on state change
 * - Type-safe defaults
 * - Loading state tracking
 */

import { useState, useEffect, useCallback, useRef } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * Persistent state hook with AsyncStorage backing.
 *
 * @param storageKey - AsyncStorage key
 * @param defaults - Default values when no stored data exists
 * @returns Tuple of [state, setState, isLoading]
 *
 * @example
 * const [settings, setSettings, isLoading] = usePersistentState(
 *   '@coherence_settings',
 *   DEFAULT_SETTINGS
 * );
 *
 * // Update (auto-persists)
 * setSettings(prev => ({ ...prev, volume: 0.8 }));
 */
export function usePersistentState<T extends object>(
  storageKey: string,
  defaults: T
): [T, (value: T | ((prev: T) => T)) => Promise<void>, boolean] {
  const [state, setState] = useState<T>(defaults);
  const [isLoading, setIsLoading] = useState(true);
  const isInitialized = useRef(false);

  // Load from storage on mount
  useEffect(() => {
    const load = async () => {
      try {
        const stored = await AsyncStorage.getItem(storageKey);
        if (stored) {
          const parsed = JSON.parse(stored) as Partial<T>;
          // Merge with defaults to handle schema migrations
          setState({ ...defaults, ...parsed });
        }
      } catch (error) {
        console.error(`[PersistentState] Failed to load ${storageKey}:`, error);
      } finally {
        setIsLoading(false);
        isInitialized.current = true;
      }
    };

    load();
  }, [storageKey]); // Only depend on key, not defaults (defaults are initial value)

  // Persistent setState that also saves to storage
  const setStateAndPersist = useCallback(
    async (value: T | ((prev: T) => T)) => {
      setState((prevState) => {
        const newState = typeof value === 'function'
          ? (value as (prev: T) => T)(prevState)
          : value;

        // Save to storage async (don't await)
        AsyncStorage.setItem(storageKey, JSON.stringify(newState)).catch(
          (error) => {
            console.error(`[PersistentState] Failed to save ${storageKey}:`, error);
          }
        );

        return newState;
      });
    },
    [storageKey]
  );

  return [state, setStateAndPersist, isLoading];
}

export default usePersistentState;
