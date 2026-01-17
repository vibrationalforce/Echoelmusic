/**
 * @coherence-core/cymatics-patterns
 *
 * Shared Chladni plate and wave interference pattern algorithms.
 * Used by both mobile (react-native-skia) and desktop (HTML5 Canvas).
 *
 * These are the mathematical foundations for visualizing acoustic resonance
 * patterns, inspired by Ernst Chladni's vibrating plate experiments (1787).
 *
 * WELLNESS VISUALIZATION - NO MEDICAL CLAIMS
 */

// ============================================================================
// TYPES
// ============================================================================

export type CymaticsMode = 'chladni' | 'interference' | 'ripple' | 'standing';

export interface PatternPoint {
  x: number;
  y: number;
  value: number;
}

export interface RGB {
  r: number;
  g: number;
  b: number;
}

// ============================================================================
// PATTERN ALGORITHMS
// ============================================================================

/**
 * Calculate Chladni pattern value at a point.
 *
 * Based on Ernst Chladni's vibrating plate equations (1787).
 * Pattern = cos(n*pi*x) * cos(m*pi*y) - cos(m*pi*x) * cos(n*pi*y)
 *
 * The pattern shows nodal lines (zero amplitude) where the plate doesn't
 * vibrate, and antinodes (maximum amplitude) where it vibrates most.
 *
 * @param x - Normalized x coordinate (0-1)
 * @param y - Normalized y coordinate (0-1)
 * @param n - Mode number in x direction (derived from frequency)
 * @param m - Mode number in y direction (derived from frequency)
 * @param phase - Animation phase (0-1)
 * @returns Pattern value (-1 to 1)
 */
export function chladniValue(
  x: number,
  y: number,
  n: number,
  m: number,
  phase: number
): number {
  const term1 = Math.cos(n * Math.PI * x) * Math.cos(m * Math.PI * y);
  const term2 = Math.cos(m * Math.PI * x) * Math.cos(n * Math.PI * y);
  return Math.sin(phase * 2 * Math.PI) * (term1 - term2);
}

/**
 * Calculate wave interference pattern.
 *
 * Two circular waves emanating from different source points.
 * Creates classic constructive/destructive interference patterns.
 *
 * @param x - Normalized x coordinate (0-1)
 * @param y - Normalized y coordinate (0-1)
 * @param frequency - Frequency in Hz (affects wave number)
 * @param phase - Animation phase (0-1)
 * @returns Pattern value (-1 to 1)
 */
export function interferenceValue(
  x: number,
  y: number,
  frequency: number,
  phase: number
): number {
  // Two source points
  const source1 = { x: 0.3, y: 0.5 };
  const source2 = { x: 0.7, y: 0.5 };

  // Distance from each source
  const r1 = Math.sqrt(
    Math.pow(x - source1.x, 2) + Math.pow(y - source1.y, 2)
  );
  const r2 = Math.sqrt(
    Math.pow(x - source2.x, 2) + Math.pow(y - source2.y, 2)
  );

  // Wave number scaled to frequency
  const k = frequency * 0.5;

  // Superposition of two waves
  const wave1 = Math.sin(k * r1 * 20 - phase * 2 * Math.PI);
  const wave2 = Math.sin(k * r2 * 20 - phase * 2 * Math.PI);

  return (wave1 + wave2) / 2;
}

/**
 * Calculate ripple pattern from center.
 *
 * Single circular wave emanating from the center with exponential damping.
 * Simulates dropping a stone in still water.
 *
 * @param x - Normalized x coordinate (0-1)
 * @param y - Normalized y coordinate (0-1)
 * @param frequency - Frequency in Hz (affects wave number)
 * @param phase - Animation phase (0-1)
 * @returns Pattern value (-1 to 1)
 */
export function rippleValue(
  x: number,
  y: number,
  frequency: number,
  phase: number
): number {
  // Center point
  const cx = 0.5;
  const cy = 0.5;

  // Distance from center
  const r = Math.sqrt(Math.pow(x - cx, 2) + Math.pow(y - cy, 2));

  // Wave number
  const k = frequency * 0.8;

  // Circular wave with exponential damping
  return Math.sin(k * r * 30 - phase * 2 * Math.PI) * Math.exp(-r * 2);
}

/**
 * Calculate standing wave pattern.
 *
 * Product of spatial and temporal sine waves, creating a standing wave
 * that oscillates in place without propagating.
 *
 * @param x - Normalized x coordinate (0-1)
 * @param y - Normalized y coordinate (0-1)
 * @param frequency - Frequency in Hz (affects mode numbers)
 * @param phase - Animation phase (0-1)
 * @returns Pattern value (-1 to 1)
 */
export function standingWaveValue(
  x: number,
  y: number,
  frequency: number,
  phase: number
): number {
  // Mode numbers derived from frequency
  const n = Math.floor(frequency / 10) + 2;
  const m = Math.floor(frequency / 15) + 2;

  // Spatial components
  const spatialX = Math.sin(n * Math.PI * x);
  const spatialY = Math.sin(m * Math.PI * y);

  // Temporal component
  const temporal = Math.cos(phase * 2 * Math.PI);

  return spatialX * spatialY * temporal;
}

// ============================================================================
// PATTERN GENERATION
// ============================================================================

/**
 * Generate pattern points for visualization.
 *
 * Creates a grid of points with calculated pattern values.
 *
 * @param mode - Pattern mode (chladni, interference, ripple, standing)
 * @param frequencyHz - Frequency in Hz (1-60)
 * @param amplitude - Amplitude (0-1)
 * @param phase - Animation phase (0-1)
 * @param size - Output size in pixels
 * @param resolution - Grid resolution (number of points per dimension)
 * @returns Array of pattern points with x, y, and value
 */
export function generatePatternPoints(
  mode: CymaticsMode,
  frequencyHz: number,
  amplitude: number,
  phase: number,
  size: number,
  resolution: number = 40
): PatternPoint[] {
  const points: PatternPoint[] = [];

  // Derive Chladni mode parameters from frequency
  const n = Math.floor(frequencyHz / 8) + 2;
  const m = Math.floor(frequencyHz / 12) + 2;

  for (let i = 0; i <= resolution; i++) {
    for (let j = 0; j <= resolution; j++) {
      const normalizedX = i / resolution;
      const normalizedY = j / resolution;

      let value: number;

      switch (mode) {
        case 'chladni':
          value = chladniValue(normalizedX, normalizedY, n, m, phase);
          break;
        case 'interference':
          value = interferenceValue(normalizedX, normalizedY, frequencyHz, phase);
          break;
        case 'ripple':
          value = rippleValue(normalizedX, normalizedY, frequencyHz, phase);
          break;
        case 'standing':
          value = standingWaveValue(normalizedX, normalizedY, frequencyHz, phase);
          break;
        default:
          value = chladniValue(normalizedX, normalizedY, n, m, phase);
      }

      // Scale by amplitude
      value *= amplitude;

      points.push({
        x: normalizedX * size,
        y: normalizedY * size,
        value,
      });
    }
  }

  return points;
}

// ============================================================================
// COLOR MAPPING
// ============================================================================

/**
 * Convert pattern value to RGB color.
 *
 * - Positive values → Cyan (wave peaks)
 * - Negative values → Magenta (wave troughs)
 * - Near zero → Dark (nodal lines)
 *
 * @param value - Pattern value (-1 to 1)
 * @param isActive - Whether the visualization is active
 * @returns RGB color object
 */
export function valueToRGB(value: number, isActive: boolean): RGB {
  if (!isActive) {
    const gray = Math.abs(value) * 100 + 20;
    return { r: gray, g: gray, b: gray };
  }

  const intensity = Math.abs(value);

  if (value > 0.05) {
    // Cyan for positive (wave peaks)
    return {
      r: Math.floor(intensity * 50),
      g: Math.floor(180 + intensity * 75),
      b: 255,
    };
  } else if (value < -0.05) {
    // Magenta for negative (wave troughs)
    return {
      r: Math.floor(180 + intensity * 75),
      g: Math.floor(intensity * 50),
      b: 255,
    };
  } else {
    // Dark for nodal lines (near zero)
    return { r: 20, g: 20, b: 30 };
  }
}

/**
 * Convert pattern value to CSS color string.
 *
 * @param value - Pattern value (-1 to 1)
 * @param isActive - Whether the visualization is active
 * @returns CSS rgb() color string
 */
export function valueToColor(value: number, isActive: boolean): string {
  const { r, g, b } = valueToRGB(value, isActive);
  return `rgb(${r}, ${g}, ${b})`;
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Get Chladni mode numbers from frequency.
 *
 * Higher frequencies create more complex patterns with more nodal lines.
 *
 * @param frequencyHz - Frequency in Hz
 * @returns Object with n and m mode numbers
 */
export function getModeNumbers(frequencyHz: number): { n: number; m: number } {
  return {
    n: Math.floor(frequencyHz / 8) + 2,
    m: Math.floor(frequencyHz / 12) + 2,
  };
}

/**
 * Calculate phase from elapsed time for animation.
 *
 * @param elapsedMs - Elapsed time in milliseconds
 * @param frequencyHz - Frequency in Hz
 * @returns Phase value (0-1)
 */
export function calculatePhase(elapsedMs: number, frequencyHz: number): number {
  // Cycle duration based on frequency (scaled for visible animation)
  const cycleMs = 1000 / (frequencyHz / 20);
  return (elapsedMs % cycleMs) / cycleMs;
}
