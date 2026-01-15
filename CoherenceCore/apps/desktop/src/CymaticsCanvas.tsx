/**
 * CymaticsCanvas Component
 *
 * Real-time wave interference pattern visualization using HTML5 Canvas.
 * Renders Chladni-style patterns based on frequency and amplitude inputs.
 *
 * Uses shared algorithms from @coherence-core/cymatics-patterns
 *
 * WELLNESS VISUALIZATION - NO MEDICAL CLAIMS
 */

import { useRef, useEffect, useCallback } from 'react';
import {
  CymaticsMode,
  chladniValue,
  interferenceValue,
  rippleValue,
  standingWaveValue,
  valueToRGB,
  getModeNumbers,
  calculatePhase,
} from '@coherence-core/cymatics-patterns';

// Re-export type for consumers
export type { CymaticsMode } from '@coherence-core/cymatics-patterns';

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

    // Calculate phase using shared utility
    if (isActive) {
      const elapsed = Date.now() - startTimeRef.current;
      phaseRef.current = calculatePhase(elapsed, frequencyHz);
    }

    const phase = phaseRef.current;

    // Derive mode parameters from frequency using shared utility
    const { n, m } = getModeNumbers(frequencyHz);

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

        // Use shared color mapping
        const color = valueToRGB(value, isActive);

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
