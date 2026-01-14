/**
 * CymaticsCanvas Component
 *
 * Real-time wave interference pattern visualization using HTML5 Canvas.
 * Renders Chladni-style patterns based on frequency and amplitude inputs.
 *
 * WELLNESS VISUALIZATION - NO MEDICAL CLAIMS
 */

import { useRef, useEffect, useCallback } from 'react';

export type CymaticsMode = 'chladni' | 'interference' | 'ripple' | 'standing';

interface CymaticsCanvasProps {
  /** Current frequency in Hz (1-60) */
  frequencyHz: number;
  /** Amplitude 0-1 */
  amplitude: number;
  /** Whether currently active */
  isActive: boolean;
  /** Visualization mode */
  mode?: CymaticsMode;
  /** Canvas size */
  size?: number;
}

/**
 * Calculate Chladni pattern value at a point
 * Based on Ernst Chladni's vibrating plate equations
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

  const k = frequency * 0.5;
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
 * Convert value to RGB color
 */
const valueToColor = (
  value: number,
  isActive: boolean
): { r: number; g: number; b: number } => {
  if (!isActive) {
    const gray = Math.abs(value) * 100 + 20;
    return { r: gray, g: gray, b: gray };
  }

  const intensity = Math.abs(value);
  if (value > 0.05) {
    // Cyan for positive
    return {
      r: Math.floor(intensity * 50),
      g: Math.floor(180 + intensity * 75),
      b: 255,
    };
  } else if (value < -0.05) {
    // Magenta for negative
    return {
      r: Math.floor(180 + intensity * 75),
      g: Math.floor(intensity * 50),
      b: 255,
    };
  } else {
    // Dark for nodal lines
    return { r: 20, g: 20, b: 30 };
  }
};

export function CymaticsCanvas({
  frequencyHz,
  amplitude,
  isActive,
  mode = 'chladni',
  size = 200,
}: CymaticsCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animationRef = useRef<number | null>(null);
  const phaseRef = useRef(0);
  const startTimeRef = useRef(Date.now());

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Calculate phase
    if (isActive) {
      const elapsed = Date.now() - startTimeRef.current;
      const cycleMs = 1000 / (frequencyHz / 20);
      phaseRef.current = (elapsed % cycleMs) / cycleMs;
    }

    const phase = phaseRef.current;

    // Derive mode parameters from frequency
    const n = Math.floor(frequencyHz / 8) + 2;
    const m = Math.floor(frequencyHz / 12) + 2;

    // Create image data
    const imageData = ctx.createImageData(size, size);
    const data = imageData.data;

    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const normalizedX = x / size;
        const normalizedY = y / size;

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

        const color = valueToColor(value, isActive);

        const idx = (y * size + x) * 4;
        data[idx] = color.r;
        data[idx + 1] = color.g;
        data[idx + 2] = color.b;
        data[idx + 3] = 255;
      }
    }

    ctx.putImageData(imageData, 0, 0);

    // Draw center point
    ctx.fillStyle = isActive ? '#00E5FF' : '#444';
    ctx.beginPath();
    ctx.arc(size / 2, size / 2, 3, 0, Math.PI * 2);
    ctx.fill();

    // Continue animation if active
    if (isActive) {
      animationRef.current = requestAnimationFrame(draw);
    }
  }, [frequencyHz, amplitude, isActive, mode, size]);

  useEffect(() => {
    if (isActive) {
      startTimeRef.current = Date.now();
      animationRef.current = requestAnimationFrame(draw);
    } else {
      // Draw one static frame
      draw();
    }

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [isActive, draw]);

  // Redraw when parameters change
  useEffect(() => {
    if (!isActive) {
      draw();
    }
  }, [frequencyHz, amplitude, mode, draw, isActive]);

  return (
    <canvas
      ref={canvasRef}
      width={size}
      height={size}
      className="cymatics-canvas"
      style={{
        borderRadius: '12px',
        border: isActive ? '2px solid #00E5FF' : '2px solid #333',
      }}
    />
  );
}

export default CymaticsCanvas;
