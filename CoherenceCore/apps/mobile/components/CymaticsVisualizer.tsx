/**
 * CymaticsVisualizer Component
 *
 * Real-time wave interference pattern visualization using react-native-skia.
 * Renders Chladni-style patterns based on frequency and amplitude inputs.
 *
 * WELLNESS VISUALIZATION - NO MEDICAL CLAIMS
 */

import React, { useMemo } from 'react';
import { View, StyleSheet, useWindowDimensions } from 'react-native';
import {
  Canvas,
  Path,
  Skia,
  useValue,
  useComputedValue,
  useTouchHandler,
  Circle,
  Group,
  BlurMask,
  LinearGradient,
  vec,
  Paint,
  RoundedRect,
} from '@shopify/react-native-skia';

export type CymaticsMode = 'chladni' | 'interference' | 'ripple' | 'standing';

interface CymaticsVisualizerProps {
  /** Current frequency in Hz (1-60) */
  frequencyHz: number;
  /** Amplitude 0-1 */
  amplitude: number;
  /** Animation phase 0-1 (changes over time) */
  phase: number;
  /** Visualization mode */
  mode?: CymaticsMode;
  /** Whether currently active */
  isActive?: boolean;
  /** Size of the visualizer (square) */
  size?: number;
}

/**
 * Calculate Chladni pattern value at a point
 * Based on Ernst Chladni's vibrating plate equations
 * Pattern = cos(n*pi*x/L) * cos(m*pi*y/L) - cos(m*pi*x/L) * cos(n*pi*y/L)
 */
const chladniValue = (
  x: number,
  y: number,
  n: number,
  m: number,
  phase: number
): number => {
  const term1 = Math.cos(n * Math.PI * x) * Math.cos(m * Math.PI * y);
  const term2 = Math.cos(m * Math.PI * x) * Math.cos(n * Math.PI * y);
  return Math.sin(phase * 2 * Math.PI) * (term1 - term2);
};

/**
 * Calculate wave interference pattern
 * Two circular waves emanating from different points
 */
const interferenceValue = (
  x: number,
  y: number,
  frequency: number,
  phase: number
): number => {
  const source1 = { x: 0.3, y: 0.5 };
  const source2 = { x: 0.7, y: 0.5 };

  const r1 = Math.sqrt(
    Math.pow(x - source1.x, 2) + Math.pow(y - source1.y, 2)
  );
  const r2 = Math.sqrt(
    Math.pow(x - source2.x, 2) + Math.pow(y - source2.y, 2)
  );

  const k = frequency * 0.5; // Wave number scaled to frequency
  const wave1 = Math.sin(k * r1 * 20 - phase * 2 * Math.PI);
  const wave2 = Math.sin(k * r2 * 20 - phase * 2 * Math.PI);

  return (wave1 + wave2) / 2;
};

/**
 * Calculate ripple pattern from center
 */
const rippleValue = (
  x: number,
  y: number,
  frequency: number,
  phase: number
): number => {
  const cx = 0.5;
  const cy = 0.5;
  const r = Math.sqrt(Math.pow(x - cx, 2) + Math.pow(y - cy, 2));
  const k = frequency * 0.8;
  return Math.sin(k * r * 30 - phase * 2 * Math.PI) * Math.exp(-r * 2);
};

/**
 * Calculate standing wave pattern
 */
const standingWaveValue = (
  x: number,
  y: number,
  frequency: number,
  phase: number
): number => {
  const n = Math.floor(frequency / 10) + 2;
  const m = Math.floor(frequency / 15) + 2;
  const spatialX = Math.sin(n * Math.PI * x);
  const spatialY = Math.sin(m * Math.PI * y);
  const temporal = Math.cos(phase * 2 * Math.PI);
  return spatialX * spatialY * temporal;
};

/**
 * Generate pattern points for visualization
 */
const generatePatternPoints = (
  mode: CymaticsMode,
  frequencyHz: number,
  amplitude: number,
  phase: number,
  size: number,
  resolution: number = 40
): { x: number; y: number; value: number }[] => {
  const points: { x: number; y: number; value: number }[] = [];

  // Derive mode parameters from frequency
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
};

/**
 * Convert value to color
 * Positive values are cyan, negative are magenta, zero is dark
 */
const valueToColor = (value: number, isActive: boolean): string => {
  if (!isActive) {
    const gray = Math.abs(value) * 100 + 20;
    return `rgb(${gray}, ${gray}, ${gray})`;
  }

  const intensity = Math.abs(value);
  if (value > 0.05) {
    // Cyan for positive
    const r = Math.floor(intensity * 50);
    const g = Math.floor(180 + intensity * 75);
    const b = 255;
    return `rgb(${r}, ${g}, ${b})`;
  } else if (value < -0.05) {
    // Magenta for negative
    const r = Math.floor(180 + intensity * 75);
    const g = Math.floor(intensity * 50);
    const b = 255;
    return `rgb(${r}, ${g}, ${b})`;
  } else {
    // Dark for nodal lines (near zero)
    return 'rgb(20, 20, 30)';
  }
};

export const CymaticsVisualizer: React.FC<CymaticsVisualizerProps> = ({
  frequencyHz,
  amplitude,
  phase,
  mode = 'chladni',
  isActive = false,
  size: propSize,
}) => {
  const { width } = useWindowDimensions();
  const size = propSize ?? Math.min(width - 40, 300);

  // Generate pattern points
  const points = useMemo(
    () => generatePatternPoints(mode, frequencyHz, amplitude, phase, size, 35),
    [mode, frequencyHz, amplitude, phase, size]
  );

  // Calculate point radius based on resolution
  const pointRadius = size / 70;

  return (
    <View style={[styles.container, { width: size, height: size }]}>
      <Canvas style={{ width: size, height: size }}>
        {/* Background */}
        <RoundedRect x={0} y={0} width={size} height={size} r={16} color="#0a0a0a" />

        {/* Border glow when active */}
        {isActive && (
          <RoundedRect
            x={2}
            y={2}
            width={size - 4}
            height={size - 4}
            r={14}
            color="transparent"
            style="stroke"
            strokeWidth={2}
          >
            <LinearGradient
              start={vec(0, 0)}
              end={vec(size, size)}
              colors={['#00E5FF', '#FF00FF', '#00E5FF']}
            />
          </RoundedRect>
        )}

        {/* Pattern points */}
        <Group>
          {points.map((point, index) => {
            const color = valueToColor(point.value, isActive);
            const radius = pointRadius * (0.5 + Math.abs(point.value) * 1.5);

            return (
              <Circle
                key={index}
                cx={point.x}
                cy={point.y}
                r={radius}
                color={color}
              >
                {isActive && Math.abs(point.value) > 0.3 && (
                  <BlurMask blur={3} style="solid" />
                )}
              </Circle>
            );
          })}
        </Group>

        {/* Center indicator */}
        <Circle cx={size / 2} cy={size / 2} r={3} color={isActive ? '#00E5FF' : '#444'} />
      </Canvas>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    borderRadius: 16,
    overflow: 'hidden',
    backgroundColor: '#0a0a0a',
  },
});

export default CymaticsVisualizer;
