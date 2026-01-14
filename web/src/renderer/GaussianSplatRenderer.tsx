/**
 * Echoelmusic 3D Gaussian Splatting Renderer
 *
 * React Three Fiber component for rendering .splat/.spz volumetric data
 * with holographic effects and beat-reactive animations.
 *
 * Uses @react-three/drei for optimized rendering.
 * Target: FPS > 30 on mobile browsers.
 */

import React, { useRef, useEffect, useMemo, useCallback, useState } from 'react';
import { useFrame, useThree, extend } from '@react-three/fiber';
import { useGLTF, Splat } from '@react-three/drei';
import * as THREE from 'three';
import {
  GaussianSplatProps,
  GaussianSplatData,
  SplatRenderConfig,
  PerformanceMetrics,
} from '../types';
import {
  gaussianSplatVertexShader,
  gaussianSplatFragmentShader,
  defaultHolographicUniforms,
} from '../shaders/holographic.glsl';
import { useGaussianSplatStore } from '../store/gaussianSplatStore';

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOM HOLOGRAPHIC SPLAT MATERIAL
// ═══════════════════════════════════════════════════════════════════════════════

class HolographicSplatMaterial extends THREE.ShaderMaterial {
  constructor() {
    super({
      vertexShader: gaussianSplatVertexShader,
      fragmentShader: gaussianSplatFragmentShader,
      uniforms: {
        time: { value: 0 },
        scanlineIntensity: { value: defaultHolographicUniforms.scanlineIntensity },
        chromaticAberration: { value: defaultHolographicUniforms.chromaticAberration },
        coherence: { value: defaultHolographicUniforms.coherence },
        beatPhase: { value: 0 },
        hologramColor: { value: new THREE.Color(...defaultHolographicUniforms.hologramColor) },
        hologramMix: { value: 0.3 },
        splatScale: { value: 1.0 },
        viewport: { value: new THREE.Vector2(1920, 1080) },
      },
      transparent: true,
      depthTest: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    });
  }
}

extend({ HolographicSplatMaterial });

// ═══════════════════════════════════════════════════════════════════════════════
// SPLAT LOADER
// ═══════════════════════════════════════════════════════════════════════════════

interface SplatLoaderResult {
  data: GaussianSplatData | null;
  error: Error | null;
  progress: number;
}

async function loadSplatFile(
  url: string,
  format: 'splat' | 'spz' | 'ply' | 'gltf',
  onProgress?: (progress: number) => void
): Promise<GaussianSplatData> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to load splat file: ${response.statusText}`);
  }

  const contentLength = response.headers.get('content-length');
  const total = contentLength ? parseInt(contentLength, 10) : 0;
  let loaded = 0;

  const reader = response.body?.getReader();
  const chunks: Uint8Array[] = [];

  if (!reader) {
    throw new Error('Failed to get response reader');
  }

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    loaded += value.length;
    if (total > 0 && onProgress) {
      onProgress(loaded / total);
    }
  }

  const buffer = new Uint8Array(loaded);
  let offset = 0;
  for (const chunk of chunks) {
    buffer.set(chunk, offset);
    offset += chunk.length;
  }

  return parseSplatData(buffer, format);
}

function parseSplatData(
  buffer: Uint8Array,
  format: 'splat' | 'spz' | 'ply' | 'gltf'
): GaussianSplatData {
  // Parse based on format
  // For .splat format (standard 3DGS format)
  if (format === 'splat' || format === 'spz') {
    return parseSplatFormat(buffer);
  }

  // For PLY format
  if (format === 'ply') {
    return parsePlyFormat(buffer);
  }

  // For glTF with extension
  throw new Error(`Format ${format} not yet implemented for direct parsing`);
}

function parseSplatFormat(buffer: Uint8Array): GaussianSplatData {
  // .splat binary format:
  // Each splat is 32 bytes:
  // - position: 3 x float32 (12 bytes)
  // - scale: 3 x float32 (12 bytes)
  // - color: 4 x uint8 (4 bytes)
  // - rotation: 4 x uint8 normalized (4 bytes)

  const splatSize = 32;
  const count = Math.floor(buffer.length / splatSize);

  const positions = new Float32Array(count * 3);
  const scales = new Float32Array(count * 3);
  const colors = new Float32Array(count * 4);
  const rotations = new Float32Array(count * 4);
  const opacities = new Float32Array(count);

  const dataView = new DataView(buffer.buffer);

  for (let i = 0; i < count; i++) {
    const offset = i * splatSize;

    // Position
    positions[i * 3 + 0] = dataView.getFloat32(offset + 0, true);
    positions[i * 3 + 1] = dataView.getFloat32(offset + 4, true);
    positions[i * 3 + 2] = dataView.getFloat32(offset + 8, true);

    // Scale (log scale in file, need to exp)
    scales[i * 3 + 0] = Math.exp(dataView.getFloat32(offset + 12, true));
    scales[i * 3 + 1] = Math.exp(dataView.getFloat32(offset + 16, true));
    scales[i * 3 + 2] = Math.exp(dataView.getFloat32(offset + 20, true));

    // Color (RGBA as uint8, normalize to 0-1)
    colors[i * 4 + 0] = buffer[offset + 24] / 255;
    colors[i * 4 + 1] = buffer[offset + 25] / 255;
    colors[i * 4 + 2] = buffer[offset + 26] / 255;
    colors[i * 4 + 3] = buffer[offset + 27] / 255;

    // Rotation (quaternion as uint8, normalize to -1 to 1)
    const rw = (buffer[offset + 28] / 128) - 1;
    const rx = (buffer[offset + 29] / 128) - 1;
    const ry = (buffer[offset + 30] / 128) - 1;
    const rz = (buffer[offset + 31] / 128) - 1;

    // Normalize quaternion
    const len = Math.sqrt(rw*rw + rx*rx + ry*ry + rz*rz);
    rotations[i * 4 + 0] = rw / len;
    rotations[i * 4 + 1] = rx / len;
    rotations[i * 4 + 2] = ry / len;
    rotations[i * 4 + 3] = rz / len;

    // Opacity from alpha
    opacities[i] = colors[i * 4 + 3];
  }

  return { positions, scales, rotations, colors, opacities, count };
}

function parsePlyFormat(buffer: Uint8Array): GaussianSplatData {
  // PLY parsing for 3DGS
  const text = new TextDecoder().decode(buffer.slice(0, 10000));  // Header in first 10KB
  const headerEnd = text.indexOf('end_header');

  if (headerEnd === -1) {
    throw new Error('Invalid PLY file: no end_header found');
  }

  // Parse header to get vertex count
  const header = text.slice(0, headerEnd);
  const vertexMatch = header.match(/element vertex (\d+)/);
  const count = vertexMatch ? parseInt(vertexMatch[1], 10) : 0;

  if (count === 0) {
    throw new Error('Invalid PLY file: no vertices found');
  }

  // For now, return empty data structure - real implementation would parse binary PLY
  return {
    positions: new Float32Array(count * 3),
    scales: new Float32Array(count * 3),
    rotations: new Float32Array(count * 4),
    colors: new Float32Array(count * 4),
    opacities: new Float32Array(count),
    count,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE MONITOR HOOK
// ═══════════════════════════════════════════════════════════════════════════════

function usePerformanceMonitor(targetFPS = 30) {
  const frameTimesRef = useRef<number[]>([]);
  const lastTimeRef = useRef(performance.now());
  const [metrics, setMetrics] = useState<PerformanceMetrics>({
    fps: 60,
    frameTime: 16.67,
    gpuTime: 0,
    drawCalls: 0,
    triangles: 0,
    splatCount: 0,
    memoryUsage: 0,
    isMobile: /iPhone|iPad|iPod|Android/i.test(navigator.userAgent),
    qualityLevel: 'high',
  });

  const updateMetrics = useCallback((info: THREE.WebGLInfo) => {
    const now = performance.now();
    const frameTime = now - lastTimeRef.current;
    lastTimeRef.current = now;

    frameTimesRef.current.push(frameTime);
    if (frameTimesRef.current.length > 60) {
      frameTimesRef.current.shift();
    }

    const avgFrameTime = frameTimesRef.current.reduce((a, b) => a + b, 0) / frameTimesRef.current.length;
    const fps = 1000 / avgFrameTime;

    setMetrics(prev => ({
      ...prev,
      fps: Math.round(fps),
      frameTime: avgFrameTime,
      drawCalls: info.render.calls,
      triangles: info.render.triangles,
    }));
  }, []);

  const isBelowTarget = metrics.fps < targetFPS;

  return { metrics, updateMetrics, isBelowTarget };
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAUSSIAN SPLAT COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

export const GaussianSplatRenderer: React.FC<GaussianSplatProps> = ({
  url,
  format = 'splat',
  position = [0, 0, 0],
  rotation = [0, 0, 0],
  scale = 1,
  holographic = true,
  holographicIntensity = 0.5,
  beatReactive = true,
  bioReactive = true,
  onLoad,
  onError,
  onProgress,
}) => {
  const groupRef = useRef<THREE.Group>(null);
  const materialRef = useRef<THREE.ShaderMaterial>(null);
  const { gl, size } = useThree();

  // Store access
  const {
    beatData,
    biometricData,
    shaderUniforms,
    updatePerformanceMetrics,
  } = useGaussianSplatStore();

  // Performance monitoring
  const { metrics, updateMetrics, isBelowTarget } = usePerformanceMonitor(30);

  // Load splat data
  const [splatData, setSplatData] = useState<GaussianSplatData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);
        const data = await loadSplatFile(url, format, onProgress);
        if (!cancelled) {
          setSplatData(data);
          setLoading(false);
          onLoad?.();
        }
      } catch (err) {
        if (!cancelled) {
          const error = err instanceof Error ? err : new Error(String(err));
          setError(error);
          setLoading(false);
          onError?.(error);
        }
      }
    }

    load();

    return () => {
      cancelled = true;
    };
  }, [url, format, onLoad, onError, onProgress]);

  // Create geometry from splat data
  const geometry = useMemo(() => {
    if (!splatData) return null;

    const geo = new THREE.BufferGeometry();

    // For proper 3DGS rendering, we'd create instanced quads
    // Simplified: create point cloud representation
    geo.setAttribute('position', new THREE.BufferAttribute(splatData.positions, 3));
    geo.setAttribute('color', new THREE.BufferAttribute(splatData.colors, 4));

    // Store additional attributes for shader
    geo.setAttribute('scale', new THREE.BufferAttribute(splatData.scales, 3));
    geo.setAttribute('rotation', new THREE.BufferAttribute(splatData.rotations, 4));

    return geo;
  }, [splatData]);

  // Animation frame
  useFrame((state, delta) => {
    if (!materialRef.current) return;

    const uniforms = materialRef.current.uniforms;

    // Update time
    uniforms.time.value = state.clock.elapsedTime;

    // Beat reactivity
    if (beatReactive) {
      uniforms.beatPhase.value = beatData.phase;
    }

    // Bio reactivity
    if (bioReactive) {
      uniforms.coherence.value = biometricData.coherence;
    }

    // Update viewport
    uniforms.viewport.value.set(size.width, size.height);

    // Update performance metrics
    updateMetrics(gl.info);
    updatePerformanceMetrics(metrics);

    // Adaptive quality based on FPS
    if (isBelowTarget && holographicIntensity > 0.2) {
      // Reduce effect intensity on low FPS
      uniforms.scanlineIntensity.value *= 0.95;
    }
  });

  if (loading) {
    return null;  // Or loading indicator
  }

  if (error || !geometry) {
    console.error('GaussianSplatRenderer error:', error);
    return null;
  }

  const scaleArray = Array.isArray(scale) ? scale : [scale, scale, scale];

  return (
    <group
      ref={groupRef}
      position={position}
      rotation={rotation}
      scale={scaleArray as [number, number, number]}
    >
      {holographic ? (
        <points geometry={geometry}>
          <shaderMaterial
            ref={materialRef}
            vertexShader={gaussianSplatVertexShader}
            fragmentShader={gaussianSplatFragmentShader}
            uniforms={{
              time: { value: 0 },
              scanlineIntensity: { value: shaderUniforms.scanlineIntensity * holographicIntensity },
              chromaticAberration: { value: shaderUniforms.chromaticAberration * holographicIntensity },
              coherence: { value: biometricData.coherence },
              beatPhase: { value: beatData.phase },
              hologramColor: { value: new THREE.Color(...shaderUniforms.hologramColor) },
              hologramMix: { value: holographicIntensity },
              splatScale: { value: 1.0 },
              viewport: { value: new THREE.Vector2(size.width, size.height) },
            }}
            transparent
            depthTest
            depthWrite={false}
            blending={THREE.AdditiveBlending}
          />
        </points>
      ) : (
        <points geometry={geometry}>
          <pointsMaterial
            size={0.01}
            vertexColors
            transparent
            opacity={0.8}
            sizeAttenuation
          />
        </points>
      )}
    </group>
  );
};

// ═══════════════════════════════════════════════════════════════════════════════
// DREI SPLAT WRAPPER (Uses @react-three/drei's built-in Splat)
// ═══════════════════════════════════════════════════════════════════════════════

interface DreiSplatProps {
  src: string;
  position?: [number, number, number];
  rotation?: [number, number, number];
  scale?: number;
  toneMapped?: boolean;
  alphaTest?: number;
}

export const DreiGaussianSplat: React.FC<DreiSplatProps> = ({
  src,
  position = [0, 0, 0],
  rotation = [0, 0, 0],
  scale = 1,
  toneMapped = false,
  alphaTest = 0,
}) => {
  return (
    <Splat
      src={src}
      position={position}
      rotation={rotation}
      scale={scale}
      toneMapped={toneMapped}
      alphaTest={alphaTest}
    />
  );
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

export { loadSplatFile, parseSplatData };
export type { SplatLoaderResult };
