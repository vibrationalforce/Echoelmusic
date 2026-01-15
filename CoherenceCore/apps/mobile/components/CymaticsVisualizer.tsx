/**
 * CymaticsVisualizer Component
 *
 * Real-time wave interference pattern visualization using react-native-skia.
 * Renders Chladni-style patterns based on frequency and amplitude inputs.
 *
 * Uses shared algorithms from @coherence-core/cymatics-patterns
 *
 * WELLNESS VISUALIZATION - NO MEDICAL CLAIMS
 */

import React, { useMemo } from 'react';
import { View, StyleSheet, useWindowDimensions } from 'react-native';
import {
  Canvas,
  Circle,
  Group,
  BlurMask,
  LinearGradient,
  vec,
  RoundedRect,
} from '@shopify/react-native-skia';

// Import shared cymatics algorithms (eliminates 150+ lines of duplication)
import {
  CymaticsMode,
  generatePatternPoints,
  valueToColor,
  PatternPoint,
} from '@coherence-core/cymatics-patterns';

// Re-export type for consumers
export type { CymaticsMode } from '@coherence-core/cymatics-patterns';

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
