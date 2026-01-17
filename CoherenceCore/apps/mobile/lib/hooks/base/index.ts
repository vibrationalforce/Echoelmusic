/**
 * CoherenceCore Mobile Base Hooks
 *
 * Reusable hook patterns extracted from domain hooks.
 * These eliminate duplication across useCoherenceEngine, useIMUAnalyzer, useSettings.
 *
 * Architecture:
 * - base/ → Generic, reusable patterns (this folder)
 * - features/ → Cross-cutting concerns (disclaimer, permissions)
 * - domain/ → Business logic hooks (coherence, IMU, settings)
 */

export { useInterval } from './useInterval';
export { usePersistentState } from './usePersistentState';
export { useHapticFeedback, type HapticFeedbackControls } from './useHapticFeedback';
export {
  useDisclaimerManagement,
  type DisclaimerState,
  type UseDisclaimerManagementReturn
} from './useDisclaimerManagement';
