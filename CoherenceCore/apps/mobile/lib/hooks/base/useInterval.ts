/**
 * useInterval Hook
 *
 * Safe interval management with automatic cleanup.
 * Eliminates duplicate timer/interval patterns across hooks.
 *
 * Replaces manual setInterval/clearInterval in:
 * - useCoherenceEngine (session timer, frame timer)
 * - useIMUAnalyzer (analysis loop)
 */

import { useEffect, useRef, useCallback } from 'react';

/**
 * Safe interval hook with automatic cleanup.
 *
 * @param callback - Function to call on each interval
 * @param intervalMs - Interval duration in milliseconds
 * @param enabled - Whether the interval is active (default: true)
 * @returns Object with manual start/stop controls
 *
 * @example
 * // Auto-run when enabled
 * useInterval(() => updateTime(), 1000, session.isPlaying);
 *
 * @example
 * // Manual control
 * const { start, stop } = useInterval(callback, 500, false);
 */
export function useInterval(
  callback: () => void,
  intervalMs: number,
  enabled: boolean = true
): { start: () => void; stop: () => void; isRunning: boolean } {
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const callbackRef = useRef(callback);
  const isRunningRef = useRef(false);

  // Update callback ref on each render to get latest closure
  useEffect(() => {
    callbackRef.current = callback;
  }, [callback]);

  const stop = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
      isRunningRef.current = false;
    }
  }, []);

  const start = useCallback(() => {
    // Prevent double-starting
    if (intervalRef.current) return;

    intervalRef.current = setInterval(() => {
      callbackRef.current();
    }, intervalMs);
    isRunningRef.current = true;
  }, [intervalMs]);

  // Auto-manage based on enabled flag
  useEffect(() => {
    if (enabled) {
      start();
    } else {
      stop();
    }

    return stop;
  }, [enabled, start, stop]);

  return {
    start,
    stop,
    isRunning: isRunningRef.current,
  };
}

export default useInterval;
