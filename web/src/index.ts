/**
 * Echoelmusic Web 3DGS Pipeline
 *
 * React Three Fiber based 3D Gaussian Splatting renderer
 * with holographic effects and beat-reactive animations.
 *
 * @packageDocumentation
 */

// ═══════════════════════════════════════════════════════════════════════════════
// RENDERER
// ═══════════════════════════════════════════════════════════════════════════════

export {
  GaussianSplatRenderer,
  DreiGaussianSplat,
  loadSplatFile,
  parseSplatData,
} from './renderer/GaussianSplatRenderer';

// ═══════════════════════════════════════════════════════════════════════════════
// SHADERS
// ═══════════════════════════════════════════════════════════════════════════════

export {
  holographicVertexShader,
  holographicFragmentShader,
  gaussianSplatVertexShader,
  gaussianSplatFragmentShader,
  simplifiedFragmentShader,
  defaultHolographicUniforms,
} from './shaders/holographic.glsl';

// ═══════════════════════════════════════════════════════════════════════════════
// AGENTS
// ═══════════════════════════════════════════════════════════════════════════════

export {
  ModelOrchestrator,
  BeatDetector,
  getOrchestrator,
  disposeOrchestrator,
} from './agents/ModelOrchestrator';

export type {
  GenerationRequest,
  GenerationResult,
} from './agents/ModelOrchestrator';

// ═══════════════════════════════════════════════════════════════════════════════
// STORE
// ═══════════════════════════════════════════════════════════════════════════════

export {
  useGaussianSplatStore,
  selectIsLoading,
  selectError,
  selectSplatData,
  selectBeatData,
  selectBiometricData,
  selectPerformanceMetrics,
  selectQualityLevel,
} from './store/gaussianSplatStore';

// ═══════════════════════════════════════════════════════════════════════════════
// COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

export {
  BeatReactiveBackground,
  NebulaBackground,
  HolographicBackground,
  SacredGeometryBackground,
} from './components/BeatReactiveBackground';

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export type {
  // Gaussian Splatting
  GaussianSplatData,
  SplatLoadOptions,
  SplatRenderConfig,

  // Shaders
  HolographicShaderUniforms,
  ShaderEffect,

  // Orchestrator
  OrchestratorConfig,
  BeatData,
  BiometricData,
  BackgroundState,
  BackgroundStyle,
  BackgroundParameters,

  // Performance
  PerformanceMetrics,
  QualityLevel,
  QualityPreset,

  // Store
  GaussianSplatStore,

  // Component Props
  GaussianSplatProps,
  HolographicMaterialProps,
  BeatReactiveBackgroundProps,
  PerformanceMonitorProps,
} from './types';

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION
// ═══════════════════════════════════════════════════════════════════════════════

export const VERSION = '1.0.0';
