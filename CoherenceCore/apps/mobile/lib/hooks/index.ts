/**
 * CoherenceCore Mobile Hooks
 *
 * Consolidated hook exports for mobile app.
 *
 * Structure:
 * - Base hooks: useInterval, usePersistentState, useHapticFeedback
 * - Domain hooks: useCoherenceEngine, useIMUAnalyzer, useSettings
 */

// Base hooks (shared patterns)
export * from './base';

// Domain hooks will be refactored to use base hooks in a future iteration
// For now, they remain in the parent lib/ directory
