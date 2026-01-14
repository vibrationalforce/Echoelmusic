/**
 * CoherenceCore EVM Engine Tests
 *
 * Unit tests for Eulerian Video Magnification algorithms.
 * Tests T001-T003 partial validation (software-only).
 */

import {
  buildGaussianPyramid,
  buildLaplacianPyramid,
  reconstructFromLaplacian,
  computeDFT,
  findDominantFrequency,
  applyTemporalFilter,
  createFilterState,
  EVMEngine,
  PyramidLevel,
  LAPLACIAN_DOWNSAMPLE_SHADER,
  TEMPORAL_FILTER_SHADER,
  AMPLIFICATION_SHADER,
} from './index';

import {
  DEFAULT_EVM_CONFIG,
  validateNyquist,
} from '@coherence-core/shared-types';

describe('Laplacian Pyramid (T003)', () => {
  // Create a simple test image (RGB)
  const createTestImage = (width: number, height: number, channels: number = 3): Float32Array => {
    const data = new Float32Array(width * height * channels);
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        for (let c = 0; c < channels; c++) {
          // Create a gradient pattern
          data[(y * width + x) * channels + c] = (x + y) / (width + height - 2);
        }
      }
    }
    return data;
  };

  describe('buildGaussianPyramid', () => {
    it('should build pyramid with correct number of levels', () => {
      const image = createTestImage(64, 64, 3);
      const pyramid = buildGaussianPyramid(image, 64, 64, 3, 4);

      expect(pyramid.length).toBe(4);
    });

    it('should reduce resolution at each level', () => {
      const image = createTestImage(64, 64, 3);
      const pyramid = buildGaussianPyramid(image, 64, 64, 3, 4);

      // Each level should have width/height info
      expect(pyramid[0].width).toBe(64);
      expect(pyramid[1].width).toBeLessThanOrEqual(pyramid[0].width);
    });
  });

  describe('buildLaplacianPyramid', () => {
    it('should build Laplacian from Gaussian pyramid', () => {
      const image = createTestImage(64, 64, 3);
      const gaussianPyramid = buildGaussianPyramid(image, 64, 64, 3, 4);
      const laplacianPyramid = buildLaplacianPyramid(gaussianPyramid);

      expect(laplacianPyramid.length).toBe(4);
    });

    it('should preserve image dimensions at each level', () => {
      const image = createTestImage(32, 32, 3);
      const gaussianPyramid = buildGaussianPyramid(image, 32, 32, 3, 3);
      const laplacianPyramid = buildLaplacianPyramid(gaussianPyramid);

      laplacianPyramid.forEach((level: PyramidLevel, idx: number) => {
        expect(level.data.length).toBeGreaterThan(0);
        expect(level.width).toBeGreaterThan(0);
        expect(level.height).toBeGreaterThan(0);
      });
    });
  });

  describe('reconstructFromLaplacian', () => {
    it('should reconstruct image from pyramid', () => {
      const width = 32;
      const height = 32;
      const channels = 3;
      const image = createTestImage(width, height, channels);
      const gaussianPyramid = buildGaussianPyramid(image, width, height, channels, 3);
      const laplacianPyramid = buildLaplacianPyramid(gaussianPyramid);
      const reconstructed = reconstructFromLaplacian(laplacianPyramid);

      expect(reconstructed.length).toBe(width * height * channels);
    });

    it('should approximately preserve original values', () => {
      const width = 16;
      const height = 16;
      const channels = 3;
      const image = createTestImage(width, height, channels);
      const gaussianPyramid = buildGaussianPyramid(image, width, height, channels, 2);
      const laplacianPyramid = buildLaplacianPyramid(gaussianPyramid);
      const reconstructed = reconstructFromLaplacian(laplacianPyramid);

      // Sum of squared differences should be small
      let ssd = 0;
      for (let i = 0; i < image.length; i++) {
        ssd += (image[i] - reconstructed[i]) ** 2;
      }
      const rmse = Math.sqrt(ssd / image.length);

      // Allow some reconstruction error
      expect(rmse).toBeLessThan(0.5);
    });
  });
});

describe('Temporal Filtering', () => {
  it('should create filter state with correct size', () => {
    const size = 100;
    const state = createFilterState(size);
    expect(state.lowpass1.length).toBe(size);
    expect(state.lowpass2.length).toBe(size);
  });

  it('should apply temporal filter to data', () => {
    const size = 100;
    const data = new Float32Array(size);
    for (let i = 0; i < size; i++) {
      data[i] = Math.sin(2 * Math.PI * 10 * i / 30); // 10 Hz signal at 30 fps
    }

    const state = createFilterState(size);
    const filtered = applyTemporalFilter(data, state, 5, 15, 30);

    expect(filtered.length).toBe(size);
  });
});

describe('DFT Frequency Analysis', () => {
  describe('computeDFT', () => {
    it('should compute DFT with correct output size', () => {
      const signal = new Float32Array(64);
      for (let i = 0; i < 64; i++) {
        signal[i] = Math.sin(2 * Math.PI * 4 * i / 64);
      }

      const result = computeDFT(signal);
      expect(result.magnitudes.length).toBe(32); // N/2 frequency bins
      expect(result.frequencies.length).toBe(32);
    });

    it('should detect dominant frequency', () => {
      const N = 128;
      const sampleRate = 60;
      const targetFreq = 10; // 10 Hz

      const signal = new Float32Array(N);
      for (let i = 0; i < N; i++) {
        const t = i / sampleRate;
        signal[i] = Math.sin(2 * Math.PI * targetFreq * t);
      }

      const { magnitudes } = computeDFT(signal);

      // Find peak bin
      let maxMag = 0;
      let maxBin = 0;
      for (let i = 0; i < magnitudes.length; i++) {
        if (magnitudes[i] > maxMag) {
          maxMag = magnitudes[i];
          maxBin = i;
        }
      }

      // Convert bin to frequency
      const detectedFreq = maxBin * sampleRate / N;

      // Should be close to target frequency
      expect(Math.abs(detectedFreq - targetFreq)).toBeLessThan(2);
    });
  });

  describe('findDominantFrequency', () => {
    it('should find dominant frequency in signal', () => {
      const sampleRate = 60;
      const targetFreq = 10;
      const signal = new Float32Array(128);

      for (let i = 0; i < signal.length; i++) {
        const t = i / sampleRate;
        signal[i] = Math.sin(2 * Math.PI * targetFreq * t);
      }

      const dominant = findDominantFrequency(signal, sampleRate, 1, 30);
      expect(Math.abs(dominant - targetFreq)).toBeLessThan(2);
    });
  });
});

describe('EVMEngine Class', () => {
  let engine: EVMEngine;

  beforeEach(() => {
    engine = new EVMEngine(DEFAULT_EVM_CONFIG);
  });

  describe('initialization', () => {
    it('should initialize with default config', () => {
      const config = engine.getConfig();
      expect(config.pyramidLevels).toBeDefined();
      expect(config.frequencyRangeHz).toBeDefined();
    });
  });

  describe('configuration', () => {
    it('should update config', () => {
      engine.setConfig({ pyramidLevels: 5 });
      const config = engine.getConfig();
      expect(config.pyramidLevels).toBe(5);
    });

    it('should validate frame rate against Nyquist', () => {
      engine.setConfig({ frequencyRangeHz: [1, 30] });
      // Default analysis frame rate should work for low frequencies
      expect(engine.validateFrameRate()).toBeDefined();
    });
  });

  describe('frame processing', () => {
    it('should process frame and return result', () => {
      const width = 64;
      const height = 64;
      const frameData = new Uint8Array(width * height * 4);

      // Fill with random data
      for (let i = 0; i < frameData.length; i++) {
        frameData[i] = Math.floor(Math.random() * 256);
      }

      const result = engine.processFrame(frameData, width, height);

      expect(result).not.toBeNull();
      if (result) {
        expect(result.timestamp).toBeDefined();
        expect(result.detectedFrequencies).toBeDefined();
        expect(result.spatialAmplitudes).toBeDefined();
        expect(result.qualityScore).toBeDefined();
      }
    });

    it('should accumulate multiple frames', () => {
      const width = 32;
      const height = 32;

      for (let frame = 0; frame < 10; frame++) {
        const frameData = new Uint8Array(width * height * 4);
        for (let i = 0; i < frameData.length; i++) {
          frameData[i] = Math.floor(Math.random() * 256);
        }
        engine.processFrame(frameData, width, height);
      }

      const result = engine.getLatestResult();
      expect(result).not.toBeNull();
    });
  });

  describe('reset', () => {
    it('should reset state', () => {
      const width = 32;
      const height = 32;
      const frameData = new Uint8Array(width * height * 4);
      engine.processFrame(frameData, width, height);

      engine.reset();

      // After reset, latest result should be null
      expect(engine.getLatestResult()).toBeNull();
    });
  });
});

describe('EVM Configuration Validation', () => {
  it('should have valid default config', () => {
    expect(DEFAULT_EVM_CONFIG.pyramidLevels).toBeGreaterThanOrEqual(1);
    expect(DEFAULT_EVM_CONFIG.pyramidLevels).toBeLessThanOrEqual(8);
    expect(DEFAULT_EVM_CONFIG.frequencyRangeHz[0]).toBeLessThan(DEFAULT_EVM_CONFIG.frequencyRangeHz[1]);
    expect(DEFAULT_EVM_CONFIG.amplificationFactor).toBeGreaterThan(0);
  });

  it('should support 1-60 Hz detection range', () => {
    expect(DEFAULT_EVM_CONFIG.frequencyRangeHz[0]).toBeGreaterThanOrEqual(1);
    expect(DEFAULT_EVM_CONFIG.frequencyRangeHz[1]).toBeLessThanOrEqual(60);
  });
});

describe('Nyquist Validation for EVM (T021)', () => {
  it('should require adequate frame rate for 60 Hz detection', () => {
    // 60 Hz target needs 120 Hz sample rate minimum
    expect(validateNyquist(60, 120).isValid).toBe(true);
    expect(validateNyquist(60, 60).isValid).toBe(false);
  });

  it('should accept 60 fps for 30 Hz detection', () => {
    expect(validateNyquist(30, 60).isValid).toBe(true);
  });

  it('should validate typical 30 fps cameras', () => {
    // 30 fps can only detect up to 15 Hz reliably
    expect(validateNyquist(15, 30).isValid).toBe(true);
    expect(validateNyquist(20, 30).isValid).toBe(false);
  });
});

describe('WebGL Shader Validation', () => {
  it('should have valid GLSL shader sources', () => {
    expect(LAPLACIAN_DOWNSAMPLE_SHADER).toBeDefined();
    expect(TEMPORAL_FILTER_SHADER).toBeDefined();
    expect(AMPLIFICATION_SHADER).toBeDefined();
  });

  it('should contain required shader components', () => {
    expect(LAPLACIAN_DOWNSAMPLE_SHADER).toContain('precision');
    expect(LAPLACIAN_DOWNSAMPLE_SHADER).toContain('void main()');
    expect(LAPLACIAN_DOWNSAMPLE_SHADER).toContain('gl_FragColor');
  });

  it('should include texture uniforms', () => {
    expect(LAPLACIAN_DOWNSAMPLE_SHADER).toContain('u_texture');
    expect(LAPLACIAN_DOWNSAMPLE_SHADER).toContain('u_resolution');
  });

  it('should have temporal filter with alpha uniform', () => {
    expect(TEMPORAL_FILTER_SHADER).toContain('u_alpha');
    expect(TEMPORAL_FILTER_SHADER).toContain('u_current');
    expect(TEMPORAL_FILTER_SHADER).toContain('u_previous');
  });

  it('should have amplification shader', () => {
    expect(AMPLIFICATION_SHADER).toContain('u_amplification');
    expect(AMPLIFICATION_SHADER).toContain('u_original');
    expect(AMPLIFICATION_SHADER).toContain('u_filtered');
  });
});

describe('Performance Benchmarks (T003)', () => {
  it('should build pyramid in reasonable time', () => {
    const width = 320;
    const height = 240;
    const channels = 3;
    const image = new Float32Array(width * height * channels);
    for (let i = 0; i < image.length; i++) {
      image[i] = Math.random();
    }

    const start = Date.now();
    const gaussianPyramid = buildGaussianPyramid(image, width, height, channels, 4);
    const laplacianPyramid = buildLaplacianPyramid(gaussianPyramid);
    const elapsed = Date.now() - start;

    // Should complete in under 200ms for software implementation
    expect(elapsed).toBeLessThan(200);
    expect(laplacianPyramid.length).toBe(4);
  });

  it('should process DFT efficiently', () => {
    const N = 256;
    const signal = new Float32Array(N);
    for (let i = 0; i < N; i++) {
      signal[i] = Math.sin(2 * Math.PI * 10 * i / N);
    }

    const start = Date.now();
    for (let i = 0; i < 10; i++) {
      computeDFT(signal);
    }
    const elapsed = Date.now() - start;

    // 10 DFTs should complete in under 500ms (environment-dependent)
    expect(elapsed).toBeLessThan(500);
  });
});

describe('IMU Integration Types (T004, T005)', () => {
  // Type/interface tests for IMU config validation

  it('should have correct IMU config structure', () => {
    const imuConfig = {
      sampleRateHz: 100,
      lowFrequencyHz: 30,
      highFrequencyHz: 50,
      bufferSizeSeconds: 2,
      axes: ['x', 'y', 'z'] as const,
    };

    expect(imuConfig.sampleRateHz).toBe(100);
    expect(validateNyquist(imuConfig.highFrequencyHz, imuConfig.sampleRateHz).isValid).toBe(true);
  });

  it('should validate 100 Hz for 50 Hz detection', () => {
    expect(validateNyquist(50, 100).isValid).toBe(true);
    expect(validateNyquist(50, 80).isValid).toBe(false);
  });
});
