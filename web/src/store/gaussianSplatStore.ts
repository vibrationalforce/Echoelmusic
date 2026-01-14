/**
 * Echoelmusic Gaussian Splat Store
 *
 * Zustand store for managing 3DGS rendering state.
 * Provides reactive state management for:
 * - Splat data and loading
 * - Shader uniforms
 * - Beat and biometric data
 * - Background state
 * - Performance metrics
 */

import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';
import {
  GaussianSplatStore,
  GaussianSplatData,
  SplatRenderConfig,
  HolographicShaderUniforms,
  BeatData,
  BiometricData,
  BackgroundState,
  BackgroundStyle,
  PerformanceMetrics,
  SplatLoadOptions,
  QualityLevel,
} from '../types';
import { defaultHolographicUniforms } from '../shaders/holographic.glsl';

// ═══════════════════════════════════════════════════════════════════════════════
// DEFAULT VALUES
// ═══════════════════════════════════════════════════════════════════════════════

const defaultRenderConfig: SplatRenderConfig = {
  splatScale: 1.0,
  opacity: 1.0,
  depthTest: true,
  depthWrite: false,
  transparent: true,
  blending: 2,  // THREE.AdditiveBlending
  sortMode: 'cpu',
};

const defaultBeatData: BeatData = {
  bpm: 120,
  phase: 0,
  energy: 0,
  frequency: { bass: 0, mid: 0, high: 0 },
  onset: false,
  timestamp: 0,
};

const defaultBiometricData: BiometricData = {
  coherence: 0.7,
  heartRate: 70,
  breathingRate: 12,
  breathPhase: 0,
};

const defaultBackgroundState: BackgroundState = {
  currentStyle: 'holographic',
  transitionProgress: 1,
  targetStyle: null,
  parameters: {
    primaryColor: [0.3, 0.7, 1.0],
    secondaryColor: [1.0, 0.3, 0.7],
    intensity: 0.8,
    speed: 0.5,
    complexity: 0.6,
    depth: 0.7,
    reactivity: 0.8,
  },
};

const defaultPerformanceMetrics: PerformanceMetrics = {
  fps: 60,
  frameTime: 16.67,
  gpuTime: 0,
  drawCalls: 0,
  triangles: 0,
  splatCount: 0,
  memoryUsage: 0,
  isMobile: typeof navigator !== 'undefined' && /iPhone|iPad|iPod|Android/i.test(navigator.userAgent),
  qualityLevel: 'high' as QualityLevel,
};

// ═══════════════════════════════════════════════════════════════════════════════
// STORE IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

export const useGaussianSplatStore = create<GaussianSplatStore>()(
  subscribeWithSelector((set, get) => ({
    // ─────────────────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────────────────

    isLoading: false,
    error: null,
    splatData: null,
    renderConfig: defaultRenderConfig,
    shaderUniforms: defaultHolographicUniforms as HolographicShaderUniforms,
    beatData: defaultBeatData,
    biometricData: defaultBiometricData,
    backgroundState: defaultBackgroundState,
    performanceMetrics: defaultPerformanceMetrics,

    // ─────────────────────────────────────────────────────────────────────────
    // ACTIONS
    // ─────────────────────────────────────────────────────────────────────────

    loadSplat: async (options: SplatLoadOptions) => {
      set({ isLoading: true, error: null });

      try {
        const response = await fetch(options.url);
        if (!response.ok) {
          throw new Error(`Failed to load: ${response.statusText}`);
        }

        const buffer = await response.arrayBuffer();
        const data = parseSplatBuffer(buffer, options);

        set({
          splatData: data,
          isLoading: false,
          performanceMetrics: {
            ...get().performanceMetrics,
            splatCount: data.count,
          },
        });
      } catch (error) {
        set({
          isLoading: false,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    },

    updateRenderConfig: (config: Partial<SplatRenderConfig>) => {
      set(state => ({
        renderConfig: { ...state.renderConfig, ...config },
      }));
    },

    updateShaderUniforms: (uniforms: Partial<HolographicShaderUniforms>) => {
      set(state => ({
        shaderUniforms: { ...state.shaderUniforms, ...uniforms },
      }));
    },

    updateBeatData: (data: Partial<BeatData>) => {
      set(state => ({
        beatData: { ...state.beatData, ...data },
      }));
    },

    updateBiometricData: (data: Partial<BiometricData>) => {
      set(state => ({
        biometricData: { ...state.biometricData, ...data },
      }));
    },

    setBackgroundStyle: (style: BackgroundStyle) => {
      set(state => ({
        backgroundState: {
          ...state.backgroundState,
          targetStyle: style,
          transitionProgress: 0,
        },
      }));
    },

    updatePerformanceMetrics: (metrics: Partial<PerformanceMetrics>) => {
      const current = get().performanceMetrics;
      const updated = { ...current, ...metrics };

      // Adaptive quality based on FPS
      if (updated.fps < 25 && current.qualityLevel !== 'low') {
        updated.qualityLevel = 'low';
      } else if (updated.fps > 50 && current.qualityLevel !== 'high') {
        updated.qualityLevel = 'high';
      }

      set({ performanceMetrics: updated });
    },

    reset: () => {
      set({
        isLoading: false,
        error: null,
        splatData: null,
        renderConfig: defaultRenderConfig,
        shaderUniforms: defaultHolographicUniforms as HolographicShaderUniforms,
        beatData: defaultBeatData,
        biometricData: defaultBiometricData,
        backgroundState: defaultBackgroundState,
        performanceMetrics: defaultPerformanceMetrics,
      });
    },
  }))
);

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

function parseSplatBuffer(buffer: ArrayBuffer, options: SplatLoadOptions): GaussianSplatData {
  const uint8 = new Uint8Array(buffer);
  const splatSize = 32;
  let count = Math.floor(uint8.length / splatSize);

  // Apply max splats limit
  if (options.maxSplats && count > options.maxSplats) {
    count = options.maxSplats;
  }

  const positions = new Float32Array(count * 3);
  const scales = new Float32Array(count * 3);
  const colors = new Float32Array(count * 4);
  const rotations = new Float32Array(count * 4);
  const opacities = new Float32Array(count);

  const view = new DataView(buffer);

  for (let i = 0; i < count; i++) {
    const offset = i * splatSize;

    // Position
    positions[i * 3 + 0] = view.getFloat32(offset + 0, true);
    positions[i * 3 + 1] = view.getFloat32(offset + 4, true);
    positions[i * 3 + 2] = view.getFloat32(offset + 8, true);

    // Scale (exp of log scale)
    scales[i * 3 + 0] = Math.exp(view.getFloat32(offset + 12, true));
    scales[i * 3 + 1] = Math.exp(view.getFloat32(offset + 16, true));
    scales[i * 3 + 2] = Math.exp(view.getFloat32(offset + 20, true));

    // Color
    colors[i * 4 + 0] = uint8[offset + 24] / 255;
    colors[i * 4 + 1] = uint8[offset + 25] / 255;
    colors[i * 4 + 2] = uint8[offset + 26] / 255;
    colors[i * 4 + 3] = uint8[offset + 27] / 255;

    // Rotation
    const qw = (uint8[offset + 28] - 128) / 128;
    const qx = (uint8[offset + 29] - 128) / 128;
    const qy = (uint8[offset + 30] - 128) / 128;
    const qz = (uint8[offset + 31] - 128) / 128;
    const qlen = Math.sqrt(qw * qw + qx * qx + qy * qy + qz * qz);

    rotations[i * 4 + 0] = qw / qlen;
    rotations[i * 4 + 1] = qx / qlen;
    rotations[i * 4 + 2] = qy / qlen;
    rotations[i * 4 + 3] = qz / qlen;

    opacities[i] = colors[i * 4 + 3];
  }

  return { positions, scales, rotations, colors, opacities, count };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELECTORS
// ═══════════════════════════════════════════════════════════════════════════════

export const selectIsLoading = (state: GaussianSplatStore) => state.isLoading;
export const selectError = (state: GaussianSplatStore) => state.error;
export const selectSplatData = (state: GaussianSplatStore) => state.splatData;
export const selectBeatData = (state: GaussianSplatStore) => state.beatData;
export const selectBiometricData = (state: GaussianSplatStore) => state.biometricData;
export const selectPerformanceMetrics = (state: GaussianSplatStore) => state.performanceMetrics;
export const selectQualityLevel = (state: GaussianSplatStore) => state.performanceMetrics.qualityLevel;
