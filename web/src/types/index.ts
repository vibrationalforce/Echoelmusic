/**
 * Echoelmusic Web 3DGS Pipeline - Type Definitions
 */

import type { Object3D, Vector3 } from 'three';

// ═══════════════════════════════════════════════════════════════════════════════
// GAUSSIAN SPLATTING TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface GaussianSplatData {
  positions: Float32Array;      // x, y, z per splat
  scales: Float32Array;         // sx, sy, sz per splat
  rotations: Float32Array;      // quaternion (w, x, y, z) per splat
  colors: Float32Array;         // r, g, b, a per splat (SH coefficients)
  opacities: Float32Array;      // opacity per splat
  count: number;
}

export interface SplatLoadOptions {
  url: string;
  format: 'splat' | 'spz' | 'ply' | 'gltf';
  maxSplats?: number;
  sortFrequency?: number;       // How often to sort splats (frames)
  frustumCulling?: boolean;
  lodBias?: number;             // Level of detail bias
}

export interface SplatRenderConfig {
  splatScale: number;
  opacity: number;
  depthTest: boolean;
  depthWrite: boolean;
  transparent: boolean;
  blending: number;
  sortMode: 'cpu' | 'gpu' | 'hybrid';
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOLOGRAPHIC SHADER TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface HolographicShaderUniforms {
  time: number;
  scanlineIntensity: number;
  scanlineSpeed: number;
  scanlineCount: number;
  chromaticAberration: number;
  glitchIntensity: number;
  glitchSpeed: number;
  noiseScale: number;
  noiseIntensity: number;
  hologramColor: [number, number, number];
  rimLightIntensity: number;
  flickerSpeed: number;
  flickerIntensity: number;
  distortionAmount: number;
  coherence: number;           // Bio-reactive: 0-1
  beatPhase: number;           // Audio-reactive: 0-1
}

export interface ShaderEffect {
  name: string;
  enabled: boolean;
  intensity: number;
  uniforms: Record<string, unknown>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL ORCHESTRATOR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface OrchestratorConfig {
  enabled: boolean;
  updateInterval: number;       // ms between updates
  beatSensitivity: number;      // 0-1
  coherenceSensitivity: number; // 0-1
  transitionDuration: number;   // ms for parameter transitions
  apiEndpoint?: string;         // Optional external API
}

export interface BeatData {
  bpm: number;
  phase: number;               // 0-1 within current beat
  energy: number;              // 0-1 current energy level
  frequency: {
    bass: number;              // 0-1
    mid: number;               // 0-1
    high: number;              // 0-1
  };
  onset: boolean;              // True on beat onset
  timestamp: number;
}

export interface BiometricData {
  coherence: number;           // 0-1 HRV coherence
  heartRate: number;           // BPM
  breathingRate: number;       // Breaths per minute
  breathPhase: number;         // 0-1 in breath cycle
}

export interface BackgroundState {
  currentStyle: BackgroundStyle;
  transitionProgress: number;
  targetStyle: BackgroundStyle | null;
  parameters: BackgroundParameters;
}

export type BackgroundStyle =
  | 'nebula'
  | 'particles'
  | 'waves'
  | 'grid'
  | 'holographic'
  | 'bio-reactive'
  | 'quantum-field'
  | 'sacred-geometry';

export interface BackgroundParameters {
  primaryColor: [number, number, number];
  secondaryColor: [number, number, number];
  intensity: number;
  speed: number;
  complexity: number;
  depth: number;
  reactivity: number;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface PerformanceMetrics {
  fps: number;
  frameTime: number;           // ms
  gpuTime: number;             // ms
  drawCalls: number;
  triangles: number;
  splatCount: number;
  memoryUsage: number;         // MB
  isMobile: boolean;
  qualityLevel: QualityLevel;
}

export type QualityLevel = 'low' | 'medium' | 'high' | 'ultra';

export interface QualityPreset {
  level: QualityLevel;
  maxSplats: number;
  shaderComplexity: 'simple' | 'standard' | 'complex';
  postProcessing: boolean;
  shadowQuality: 'off' | 'low' | 'medium' | 'high';
  antialias: boolean;
  pixelRatio: number;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STORE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface GaussianSplatStore {
  // State
  isLoading: boolean;
  error: string | null;
  splatData: GaussianSplatData | null;
  renderConfig: SplatRenderConfig;
  shaderUniforms: HolographicShaderUniforms;
  beatData: BeatData;
  biometricData: BiometricData;
  backgroundState: BackgroundState;
  performanceMetrics: PerformanceMetrics;

  // Actions
  loadSplat: (options: SplatLoadOptions) => Promise<void>;
  updateRenderConfig: (config: Partial<SplatRenderConfig>) => void;
  updateShaderUniforms: (uniforms: Partial<HolographicShaderUniforms>) => void;
  updateBeatData: (data: Partial<BeatData>) => void;
  updateBiometricData: (data: Partial<BiometricData>) => void;
  setBackgroundStyle: (style: BackgroundStyle) => void;
  updatePerformanceMetrics: (metrics: Partial<PerformanceMetrics>) => void;
  reset: () => void;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPONENT PROPS
// ═══════════════════════════════════════════════════════════════════════════════

export interface GaussianSplatProps {
  url: string;
  format?: 'splat' | 'spz' | 'ply' | 'gltf';
  position?: [number, number, number];
  rotation?: [number, number, number];
  scale?: number | [number, number, number];
  holographic?: boolean;
  holographicIntensity?: number;
  beatReactive?: boolean;
  bioReactive?: boolean;
  onLoad?: () => void;
  onError?: (error: Error) => void;
  onProgress?: (progress: number) => void;
}

export interface HolographicMaterialProps {
  uniforms?: Partial<HolographicShaderUniforms>;
  transparent?: boolean;
  depthTest?: boolean;
  depthWrite?: boolean;
  side?: number;
}

export interface BeatReactiveBackgroundProps {
  style?: BackgroundStyle;
  intensity?: number;
  reactivity?: number;
  colors?: {
    primary?: [number, number, number];
    secondary?: [number, number, number];
  };
}

export interface PerformanceMonitorProps {
  visible?: boolean;
  position?: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';
  targetFPS?: number;
  onBelowTarget?: () => void;
}
