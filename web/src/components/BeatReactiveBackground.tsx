/**
 * Echoelmusic Beat-Reactive Background
 *
 * Animated background that responds to audio beats and biometric data.
 * Integrates with Model Orchestrator for dynamic style changes.
 */

import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useGaussianSplatStore } from '../store/gaussianSplatStore';
import { BeatReactiveBackgroundProps, BackgroundStyle } from '../types';

// ═══════════════════════════════════════════════════════════════════════════════
// BACKGROUND SHADERS
// ═══════════════════════════════════════════════════════════════════════════════

const backgroundVertexShader = /* glsl */ `
varying vec2 vUv;
varying vec3 vPosition;

void main() {
  vUv = uv;
  vPosition = position;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
`;

const backgroundFragmentShader = /* glsl */ `
precision highp float;

uniform float time;
uniform float beatPhase;
uniform float coherence;
uniform float energy;
uniform vec3 primaryColor;
uniform vec3 secondaryColor;
uniform float intensity;
uniform float speed;
uniform float complexity;

varying vec2 vUv;
varying vec3 vPosition;

// Noise functions
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

float fbm(vec2 p, int octaves) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 6; i++) {
    if (i >= octaves) break;
    value += amplitude * noise(p);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

void main() {
  vec2 uv = vUv;

  // Animate UV
  vec2 animUv = uv + time * speed * 0.1;

  // Create layered noise
  int octaves = int(2.0 + complexity * 4.0);
  float n1 = fbm(animUv * 3.0, octaves);
  float n2 = fbm(animUv * 5.0 + vec2(100.0), octaves);

  // Beat reactive pulse
  float pulse = sin(beatPhase * 6.28318) * 0.5 + 0.5;
  pulse = pow(pulse, 2.0) * energy;

  // Color mixing
  float colorMix = n1 * 0.5 + pulse * 0.3 + coherence * 0.2;
  vec3 color = mix(primaryColor, secondaryColor, colorMix);

  // Add glow on beat
  color += primaryColor * pulse * 0.3 * intensity;

  // Coherence-based color adjustment
  color = mix(color, color * vec3(0.8, 1.0, 0.9), coherence * 0.3);

  // Vignette
  float vignette = 1.0 - length(uv - 0.5) * 0.8;
  color *= vignette;

  // Final intensity
  color *= intensity;

  gl_FragColor = vec4(color, 1.0);
}
`;

// ═══════════════════════════════════════════════════════════════════════════════
// COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

export const BeatReactiveBackground: React.FC<BeatReactiveBackgroundProps> = ({
  style = 'holographic',
  intensity = 0.8,
  reactivity = 0.7,
  colors,
}) => {
  const materialRef = useRef<THREE.ShaderMaterial>(null);
  const { beatData, biometricData, backgroundState } = useGaussianSplatStore();

  const uniforms = useMemo(() => ({
    time: { value: 0 },
    beatPhase: { value: 0 },
    coherence: { value: 0.7 },
    energy: { value: 0 },
    primaryColor: { value: new THREE.Color(
      ...(colors?.primary || backgroundState.parameters.primaryColor)
    )},
    secondaryColor: { value: new THREE.Color(
      ...(colors?.secondary || backgroundState.parameters.secondaryColor)
    )},
    intensity: { value: intensity },
    speed: { value: backgroundState.parameters.speed },
    complexity: { value: backgroundState.parameters.complexity },
  }), [colors, intensity, backgroundState.parameters]);

  useFrame((state) => {
    if (!materialRef.current) return;

    const u = materialRef.current.uniforms;
    u.time.value = state.clock.elapsedTime;
    u.beatPhase.value = beatData.phase;
    u.coherence.value = biometricData.coherence;
    u.energy.value = beatData.energy * reactivity;
    u.intensity.value = intensity * (0.8 + beatData.energy * 0.2 * reactivity);
  });

  return (
    <mesh position={[0, 0, -10]} scale={[30, 20, 1]}>
      <planeGeometry args={[1, 1]} />
      <shaderMaterial
        ref={materialRef}
        vertexShader={backgroundVertexShader}
        fragmentShader={backgroundFragmentShader}
        uniforms={uniforms}
        transparent={false}
        depthWrite={false}
      />
    </mesh>
  );
};

// ═══════════════════════════════════════════════════════════════════════════════
// STYLE-SPECIFIC BACKGROUNDS
// ═══════════════════════════════════════════════════════════════════════════════

export const NebulaBackground: React.FC<{ intensity?: number }> = ({ intensity = 0.8 }) => (
  <BeatReactiveBackground
    style="nebula"
    intensity={intensity}
    colors={{
      primary: [0.1, 0.2, 0.5],
      secondary: [0.5, 0.1, 0.3],
    }}
  />
);

export const HolographicBackground: React.FC<{ intensity?: number }> = ({ intensity = 1.0 }) => (
  <BeatReactiveBackground
    style="holographic"
    intensity={intensity}
    colors={{
      primary: [0.3, 0.7, 1.0],
      secondary: [1.0, 0.3, 0.7],
    }}
  />
);

export const SacredGeometryBackground: React.FC<{ intensity?: number }> = ({ intensity = 0.7 }) => (
  <BeatReactiveBackground
    style="sacred-geometry"
    intensity={intensity}
    colors={{
      primary: [1.0, 0.8, 0.3],
      secondary: [0.3, 0.8, 1.0],
    }}
  />
);
