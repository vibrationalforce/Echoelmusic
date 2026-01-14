/**
 * CoherenceCore EVM Engine
 *
 * Eulerian Video Magnification for detecting micro-vibrations (1-60 Hz)
 * in video streams. Cross-platform support for mobile (WebGL) and desktop (wgpu).
 *
 * Based on: Wu et al. (2012) "Eulerian Video Magnification for Revealing
 * Subtle Changes in the World" - MIT CSAIL
 *
 * WELLNESS ONLY - NO MEDICAL CLAIMS
 */

import {
  EVMConfig,
  DEFAULT_EVM_CONFIG,
  EVMAnalysisResult,
  validateNyquist,
} from '@coherence-core/shared-types';

// ============================================================================
// LAPLACIAN PYRAMID
// ============================================================================

/**
 * Single level of the Laplacian pyramid
 */
export interface PyramidLevel {
  data: Float32Array;
  width: number;
  height: number;
  channels: number;
}

/**
 * Build Gaussian pyramid by successive downsampling
 */
export function buildGaussianPyramid(
  imageData: Float32Array,
  width: number,
  height: number,
  channels: number,
  levels: number
): PyramidLevel[] {
  const pyramid: PyramidLevel[] = [];

  let currentData = imageData;
  let currentWidth = width;
  let currentHeight = height;

  for (let level = 0; level < levels; level++) {
    pyramid.push({
      data: currentData,
      width: currentWidth,
      height: currentHeight,
      channels,
    });

    if (level < levels - 1) {
      const { data, newWidth, newHeight } = downsample(
        currentData,
        currentWidth,
        currentHeight,
        channels
      );
      currentData = data;
      currentWidth = newWidth;
      currentHeight = newHeight;
    }
  }

  return pyramid;
}

/**
 * Build Laplacian pyramid from Gaussian pyramid
 */
export function buildLaplacianPyramid(
  gaussianPyramid: PyramidLevel[]
): PyramidLevel[] {
  const laplacianPyramid: PyramidLevel[] = [];

  for (let i = 0; i < gaussianPyramid.length - 1; i++) {
    const current = gaussianPyramid[i];
    const next = gaussianPyramid[i + 1];

    // Upsample the next (smaller) level
    const upsampled = upsample(
      next.data,
      next.width,
      next.height,
      next.channels,
      current.width,
      current.height
    );

    // Laplacian = Current - Upsampled(Next)
    const laplacian = new Float32Array(current.data.length);
    for (let j = 0; j < current.data.length; j++) {
      laplacian[j] = current.data[j] - upsampled[j];
    }

    laplacianPyramid.push({
      data: laplacian,
      width: current.width,
      height: current.height,
      channels: current.channels,
    });
  }

  // Add the smallest level (residual)
  const last = gaussianPyramid[gaussianPyramid.length - 1];
  laplacianPyramid.push({
    data: new Float32Array(last.data),
    width: last.width,
    height: last.height,
    channels: last.channels,
  });

  return laplacianPyramid;
}

/**
 * Reconstruct image from Laplacian pyramid
 */
export function reconstructFromLaplacian(
  laplacianPyramid: PyramidLevel[]
): Float32Array {
  if (laplacianPyramid.length === 0) {
    return new Float32Array(0);
  }

  // Start from the smallest level (residual)
  let current = new Float32Array(laplacianPyramid[laplacianPyramid.length - 1].data);
  let currentWidth = laplacianPyramid[laplacianPyramid.length - 1].width;
  let currentHeight = laplacianPyramid[laplacianPyramid.length - 1].height;
  const channels = laplacianPyramid[0].channels;

  // Work up the pyramid
  for (let i = laplacianPyramid.length - 2; i >= 0; i--) {
    const level = laplacianPyramid[i];

    // Upsample current result
    const upsampled = upsample(
      current,
      currentWidth,
      currentHeight,
      channels,
      level.width,
      level.height
    );

    // Add the Laplacian level
    current = new Float32Array(level.data.length);
    for (let j = 0; j < level.data.length; j++) {
      current[j] = upsampled[j] + level.data[j];
    }

    currentWidth = level.width;
    currentHeight = level.height;
  }

  return current;
}

// ============================================================================
// IMAGE OPERATIONS
// ============================================================================

/**
 * Downsample image by 2x using Gaussian blur
 */
function downsample(
  data: Float32Array,
  width: number,
  height: number,
  channels: number
): { data: Float32Array; newWidth: number; newHeight: number } {
  const newWidth = Math.floor(width / 2);
  const newHeight = Math.floor(height / 2);

  if (newWidth === 0 || newHeight === 0) {
    return { data, newWidth: width, newHeight: height };
  }

  const result = new Float32Array(newWidth * newHeight * channels);

  // 5x5 Gaussian kernel (approximation using 2x2 averaging for simplicity)
  for (let y = 0; y < newHeight; y++) {
    for (let x = 0; x < newWidth; x++) {
      for (let c = 0; c < channels; c++) {
        const srcX = x * 2;
        const srcY = y * 2;

        // Average 2x2 block with Gaussian weights
        let sum = 0;
        let count = 0;

        for (let dy = 0; dy < 2; dy++) {
          for (let dx = 0; dx < 2; dx++) {
            const sx = srcX + dx;
            const sy = srcY + dy;

            if (sx < width && sy < height) {
              const idx = (sy * width + sx) * channels + c;
              sum += data[idx];
              count++;
            }
          }
        }

        const dstIdx = (y * newWidth + x) * channels + c;
        result[dstIdx] = count > 0 ? sum / count : 0;
      }
    }
  }

  return { data: result, newWidth, newHeight };
}

/**
 * Upsample image to target size using bilinear interpolation
 */
function upsample(
  data: Float32Array,
  srcWidth: number,
  srcHeight: number,
  channels: number,
  dstWidth: number,
  dstHeight: number
): Float32Array {
  const result = new Float32Array(dstWidth * dstHeight * channels);

  const scaleX = srcWidth / dstWidth;
  const scaleY = srcHeight / dstHeight;

  for (let y = 0; y < dstHeight; y++) {
    for (let x = 0; x < dstWidth; x++) {
      const srcX = x * scaleX;
      const srcY = y * scaleY;

      const x0 = Math.floor(srcX);
      const y0 = Math.floor(srcY);
      const x1 = Math.min(x0 + 1, srcWidth - 1);
      const y1 = Math.min(y0 + 1, srcHeight - 1);

      const fx = srcX - x0;
      const fy = srcY - y0;

      for (let c = 0; c < channels; c++) {
        const v00 = data[(y0 * srcWidth + x0) * channels + c];
        const v10 = data[(y0 * srcWidth + x1) * channels + c];
        const v01 = data[(y1 * srcWidth + x0) * channels + c];
        const v11 = data[(y1 * srcWidth + x1) * channels + c];

        // Bilinear interpolation
        const value =
          v00 * (1 - fx) * (1 - fy) +
          v10 * fx * (1 - fy) +
          v01 * (1 - fx) * fy +
          v11 * fx * fy;

        result[(y * dstWidth + x) * channels + c] = value;
      }
    }
  }

  return result;
}

// ============================================================================
// TEMPORAL FILTERING
// ============================================================================

/**
 * IIR bandpass filter state
 */
export interface FilterState {
  lowpass1: Float32Array;
  lowpass2: Float32Array;
}

/**
 * Create initial filter state
 */
export function createFilterState(size: number): FilterState {
  return {
    lowpass1: new Float32Array(size),
    lowpass2: new Float32Array(size),
  };
}

/**
 * Apply IIR bandpass filter to pyramid level
 *
 * Uses a simple difference-of-lowpass approximation
 */
export function applyTemporalFilter(
  data: Float32Array,
  state: FilterState,
  lowCutoffHz: number,
  highCutoffHz: number,
  frameRate: number
): Float32Array {
  // Calculate filter coefficients
  const alpha1 = Math.exp(-2 * Math.PI * lowCutoffHz / frameRate);
  const alpha2 = Math.exp(-2 * Math.PI * highCutoffHz / frameRate);

  const filtered = new Float32Array(data.length);

  for (let i = 0; i < data.length; i++) {
    // Update lowpass filters
    state.lowpass1[i] = alpha1 * state.lowpass1[i] + (1 - alpha1) * data[i];
    state.lowpass2[i] = alpha2 * state.lowpass2[i] + (1 - alpha2) * data[i];

    // Bandpass = difference of lowpass outputs
    filtered[i] = state.lowpass1[i] - state.lowpass2[i];
  }

  return filtered;
}

// ============================================================================
// FFT ANALYSIS
// ============================================================================

/**
 * Simple DFT for frequency analysis (for small windows)
 * For production, use a proper FFT library
 */
export function computeDFT(signal: Float32Array): { magnitudes: Float32Array; frequencies: number[] } {
  const N = signal.length;
  const magnitudes = new Float32Array(Math.floor(N / 2));
  const frequencies: number[] = [];

  for (let k = 0; k < N / 2; k++) {
    let real = 0;
    let imag = 0;

    for (let n = 0; n < N; n++) {
      const angle = (2 * Math.PI * k * n) / N;
      real += signal[n] * Math.cos(angle);
      imag -= signal[n] * Math.sin(angle);
    }

    magnitudes[k] = Math.sqrt(real * real + imag * imag) / N;
    frequencies.push(k);
  }

  return { magnitudes, frequencies };
}

/**
 * Find dominant frequency in signal
 */
export function findDominantFrequency(
  signal: Float32Array,
  sampleRate: number,
  minFreqHz: number = 1,
  maxFreqHz: number = 60
): number {
  const { magnitudes } = computeDFT(signal);
  const binWidth = sampleRate / signal.length;

  const minBin = Math.floor(minFreqHz / binWidth);
  const maxBin = Math.min(Math.ceil(maxFreqHz / binWidth), magnitudes.length - 1);

  let maxMagnitude = 0;
  let dominantBin = minBin;

  for (let bin = minBin; bin <= maxBin; bin++) {
    if (magnitudes[bin] > maxMagnitude) {
      maxMagnitude = magnitudes[bin];
      dominantBin = bin;
    }
  }

  return dominantBin * binWidth;
}

// ============================================================================
// EVM ENGINE CLASS
// ============================================================================

export interface EVMEngineState {
  isAnalyzing: boolean;
  frameRate: number;
  config: EVMConfig;
  frameBuffer: Float32Array[];
  pyramidBuffer: PyramidLevel[][];
  filterStates: FilterState[];
  latestResult: EVMAnalysisResult | null;
}

/**
 * Eulerian Video Magnification Engine
 */
export class EVMEngine {
  private state: EVMEngineState;
  private maxBufferSize = 256;
  private onAnalysisResult?: (result: EVMAnalysisResult) => void;

  constructor(
    config: EVMConfig = DEFAULT_EVM_CONFIG,
    onAnalysisResult?: (result: EVMAnalysisResult) => void
  ) {
    this.state = {
      isAnalyzing: false,
      frameRate: config.analysisFrameRate,
      config,
      frameBuffer: [],
      pyramidBuffer: [],
      filterStates: [],
      latestResult: null,
    };
    this.onAnalysisResult = onAnalysisResult;
  }

  /**
   * Get current configuration
   */
  getConfig(): EVMConfig {
    return { ...this.state.config };
  }

  /**
   * Update configuration
   */
  setConfig(config: Partial<EVMConfig>): void {
    this.state.config = { ...this.state.config, ...config };
    // Reset filter states when config changes
    this.state.filterStates = [];
  }

  /**
   * Validate frame rate against Nyquist theorem
   */
  validateFrameRate(): boolean {
    const maxTargetFreq = this.state.config.frequencyRangeHz[1];
    const validation = validateNyquist(maxTargetFreq, this.state.frameRate);
    return validation.isValid;
  }

  /**
   * Process a single video frame
   *
   * @param frameData - Raw RGBA pixel data
   * @param width - Frame width
   * @param height - Frame height
   */
  processFrame(
    frameData: Uint8Array | Float32Array,
    width: number,
    height: number
  ): EVMAnalysisResult | null {
    const channels = 3; // RGB

    // Convert to float if necessary
    let floatData: Float32Array;
    if (frameData instanceof Uint8Array) {
      floatData = this.uint8ToFloat32(frameData, width, height);
    } else {
      floatData = frameData;
    }

    // Build Laplacian pyramid
    const gaussianPyramid = buildGaussianPyramid(
      floatData,
      width,
      height,
      channels,
      this.state.config.pyramidLevels
    );

    const laplacianPyramid = buildLaplacianPyramid(gaussianPyramid);

    // Store in buffer
    this.state.pyramidBuffer.push(laplacianPyramid);
    if (this.state.pyramidBuffer.length > this.maxBufferSize) {
      this.state.pyramidBuffer.shift();
    }

    // Initialize filter states if needed
    while (this.state.filterStates.length < laplacianPyramid.length) {
      const level = laplacianPyramid[this.state.filterStates.length];
      this.state.filterStates.push(createFilterState(level.data.length));
    }

    // Apply temporal filtering and analyze
    const detectedFrequencies: number[] = [];
    const spatialAmplitudes: number[] = [];

    for (let i = 0; i < laplacianPyramid.length; i++) {
      const level = laplacianPyramid[i];
      const filterState = this.state.filterStates[i];

      // Apply bandpass filter
      const filtered = applyTemporalFilter(
        level.data,
        filterState,
        this.state.config.frequencyRangeHz[0],
        this.state.config.frequencyRangeHz[1],
        this.state.frameRate
      );

      // Calculate RMS amplitude
      let sumSquares = 0;
      for (let j = 0; j < filtered.length; j++) {
        sumSquares += filtered[j] * filtered[j];
      }
      const rms = Math.sqrt(sumSquares / filtered.length);
      spatialAmplitudes.push(rms);

      // Find dominant frequency in this level
      if (filtered.length >= 64) {
        const dominantFreq = findDominantFrequency(
          filtered.slice(0, 256),
          this.state.frameRate,
          this.state.config.frequencyRangeHz[0],
          this.state.config.frequencyRangeHz[1]
        );

        if (dominantFreq > 0) {
          detectedFrequencies.push(dominantFreq);
        }
      }
    }

    // Calculate quality score
    const avgAmplitude = spatialAmplitudes.reduce((a, b) => a + b, 0) / spatialAmplitudes.length;
    const qualityScore = Math.min(1, avgAmplitude * 100);

    const result: EVMAnalysisResult = {
      timestamp: Date.now(),
      detectedFrequencies: [...new Set(detectedFrequencies)].sort((a, b) => a - b),
      spatialAmplitudes,
      qualityScore,
      frameRate: this.state.frameRate,
    };

    this.state.latestResult = result;
    this.onAnalysisResult?.(result);

    return result;
  }

  /**
   * Get latest analysis result
   */
  getLatestResult(): EVMAnalysisResult | null {
    return this.state.latestResult;
  }

  /**
   * Clear buffers and reset state
   */
  reset(): void {
    this.state.frameBuffer = [];
    this.state.pyramidBuffer = [];
    this.state.filterStates = [];
    this.state.latestResult = null;
  }

  // Private methods

  private uint8ToFloat32(
    data: Uint8Array,
    width: number,
    height: number
  ): Float32Array {
    // Assume RGBA input, convert to RGB float
    const floatData = new Float32Array(width * height * 3);

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const srcIdx = (y * width + x) * 4;
        const dstIdx = (y * width + x) * 3;

        floatData[dstIdx + 0] = data[srcIdx + 0] / 255;
        floatData[dstIdx + 1] = data[srcIdx + 1] / 255;
        floatData[dstIdx + 2] = data[srcIdx + 2] / 255;
      }
    }

    return floatData;
  }
}

// ============================================================================
// WEBGL SHADER SOURCE
// ============================================================================

export const LAPLACIAN_DOWNSAMPLE_SHADER = `
precision highp float;

uniform sampler2D u_texture;
uniform vec2 u_resolution;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec2 texel = 1.0 / u_resolution;

  // 2x2 Gaussian averaging
  vec4 color =
    texture2D(u_texture, uv) * 0.25 +
    texture2D(u_texture, uv + vec2(texel.x, 0.0)) * 0.25 +
    texture2D(u_texture, uv + vec2(0.0, texel.y)) * 0.25 +
    texture2D(u_texture, uv + texel) * 0.25;

  gl_FragColor = color;
}
`;

export const TEMPORAL_FILTER_SHADER = `
precision highp float;

uniform sampler2D u_current;
uniform sampler2D u_previous;
uniform float u_alpha;
uniform vec2 u_resolution;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;

  vec4 current = texture2D(u_current, uv);
  vec4 previous = texture2D(u_previous, uv);

  // IIR lowpass filter
  vec4 filtered = u_alpha * previous + (1.0 - u_alpha) * current;

  gl_FragColor = filtered;
}
`;

export const AMPLIFICATION_SHADER = `
precision highp float;

uniform sampler2D u_original;
uniform sampler2D u_filtered;
uniform float u_amplification;
uniform vec2 u_resolution;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;

  vec4 original = texture2D(u_original, uv);
  vec4 filtered = texture2D(u_filtered, uv);

  // Add amplified motion to original
  vec4 result = original + filtered * u_amplification;

  // Clamp to valid range
  gl_FragColor = clamp(result, 0.0, 1.0);
}
`;
