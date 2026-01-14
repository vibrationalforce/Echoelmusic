/**
 * Echoelmusic Holographic Shader
 *
 * Features:
 * - Scanlines with configurable density and speed
 * - Chromatic aberration
 * - Holographic noise and glitch effects
 * - Bio-reactive coherence modulation
 * - Beat-reactive pulsing
 *
 * Optimized for mobile: FPS > 30 target
 */

// ═══════════════════════════════════════════════════════════════════════════════
// VERTEX SHADER
// ═══════════════════════════════════════════════════════════════════════════════

export const holographicVertexShader = /* glsl */ `
precision highp float;

// Attributes
attribute vec3 position;
attribute vec3 normal;
attribute vec2 uv;

// Uniforms
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat3 normalMatrix;
uniform float time;
uniform float distortionAmount;
uniform float beatPhase;
uniform float coherence;

// Varyings
varying vec2 vUv;
varying vec3 vNormal;
varying vec3 vPosition;
varying vec3 vWorldPosition;
varying float vFresnel;

// Noise function for vertex displacement
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

void main() {
  vUv = uv;
  vNormal = normalize(normalMatrix * normal);

  // Calculate vertex displacement for holographic wobble
  vec3 displacedPosition = position;

  // Beat-reactive displacement
  float beatPulse = sin(beatPhase * 6.28318) * 0.5 + 0.5;
  float displacement = noise(position.xy * 2.0 + time * 0.5) * distortionAmount;
  displacement *= mix(0.3, 1.0, coherence);  // Coherence reduces distortion
  displacement *= mix(0.8, 1.2, beatPulse);  // Beat adds pulse

  displacedPosition += normal * displacement * 0.1;

  vec4 mvPosition = modelViewMatrix * vec4(displacedPosition, 1.0);
  vPosition = mvPosition.xyz;
  vWorldPosition = (modelMatrix * vec4(displacedPosition, 1.0)).xyz;

  // Fresnel for rim lighting
  vec3 viewDir = normalize(-mvPosition.xyz);
  vFresnel = pow(1.0 - max(dot(viewDir, vNormal), 0.0), 3.0);

  gl_Position = projectionMatrix * mvPosition;
}
`;

// ═══════════════════════════════════════════════════════════════════════════════
// FRAGMENT SHADER
// ═══════════════════════════════════════════════════════════════════════════════

export const holographicFragmentShader = /* glsl */ `
precision highp float;

// Uniforms
uniform float time;
uniform float scanlineIntensity;
uniform float scanlineSpeed;
uniform float scanlineCount;
uniform float chromaticAberration;
uniform float glitchIntensity;
uniform float glitchSpeed;
uniform float noiseScale;
uniform float noiseIntensity;
uniform vec3 hologramColor;
uniform float rimLightIntensity;
uniform float flickerSpeed;
uniform float flickerIntensity;
uniform float distortionAmount;
uniform float coherence;
uniform float beatPhase;

uniform sampler2D map;          // Base texture (if any)
uniform bool hasMap;
uniform vec3 baseColor;
uniform float opacity;

// Varyings
varying vec2 vUv;
varying vec3 vNormal;
varying vec3 vPosition;
varying vec3 vWorldPosition;
varying float vFresnel;

// ─────────────────────────────────────────────────────────────────────────────
// NOISE FUNCTIONS (Optimized for mobile)
// ─────────────────────────────────────────────────────────────────────────────

float hash(float n) {
  return fract(sin(n) * 43758.5453123);
}

float hash2D(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);  // Smoothstep

  float a = hash2D(i);
  float b = hash2D(i + vec2(1.0, 0.0));
  float c = hash2D(i + vec2(0.0, 1.0));
  float d = hash2D(i + vec2(1.0, 1.0));

  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCANLINE EFFECT
// ─────────────────────────────────────────────────────────────────────────────

float scanlines(vec2 uv, float count, float speed, float intensity) {
  float scanline = sin((uv.y + time * speed) * count * 3.14159) * 0.5 + 0.5;
  scanline = pow(scanline, 2.0);
  return 1.0 - scanline * intensity;
}

// ─────────────────────────────────────────────────────────────────────────────
// CHROMATIC ABERRATION
// ─────────────────────────────────────────────────────────────────────────────

vec3 chromaticAberrationEffect(vec2 uv, float amount) {
  // Beat-reactive aberration
  float beatBoost = sin(beatPhase * 6.28318) * 0.5 + 0.5;
  float dynamicAmount = amount * mix(1.0, 1.5, beatBoost);

  vec2 offset = vec2(dynamicAmount * 0.01, 0.0);

  vec3 color;
  if (hasMap) {
    color.r = texture2D(map, uv + offset).r;
    color.g = texture2D(map, uv).g;
    color.b = texture2D(map, uv - offset).b;
  } else {
    // For non-textured, create RGB shift from base color
    color.r = baseColor.r * (1.0 + offset.x * 10.0);
    color.g = baseColor.g;
    color.b = baseColor.b * (1.0 - offset.x * 10.0);
  }

  return color;
}

// ─────────────────────────────────────────────────────────────────────────────
// GLITCH EFFECT
// ─────────────────────────────────────────────────────────────────────────────

float glitchBlock(vec2 uv, float intensity, float speed) {
  float t = floor(time * speed * 10.0);
  float blockY = floor(uv.y * 20.0);
  float glitchNoise = hash(blockY + t);

  // Only glitch occasionally, reduced by coherence
  float glitchThreshold = mix(0.85, 0.98, coherence);
  if (glitchNoise > glitchThreshold) {
    return hash(blockY * 0.1 + t) * intensity;
  }
  return 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// HOLOGRAPHIC NOISE
// ─────────────────────────────────────────────────────────────────────────────

float holographicNoise(vec2 uv, float scale, float intensity) {
  vec2 noiseUv = uv * scale + time * 0.1;
  float n = noise(noiseUv);

  // Add subtle movement
  n += noise(noiseUv * 2.0 - time * 0.15) * 0.5;
  n += noise(noiseUv * 4.0 + time * 0.2) * 0.25;

  return n * intensity;
}

// ─────────────────────────────────────────────────────────────────────────────
// FLICKER EFFECT
// ─────────────────────────────────────────────────────────────────────────────

float flicker(float speed, float intensity) {
  float f = sin(time * speed * 20.0) * sin(time * speed * 15.3) * sin(time * speed * 31.7);
  f = f * 0.5 + 0.5;
  return 1.0 - f * intensity * (1.0 - coherence);  // High coherence = stable
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  vec2 uv = vUv;

  // Apply glitch UV distortion
  float glitch = glitchBlock(uv, glitchIntensity, glitchSpeed);
  uv.x += glitch * 0.1;

  // Get base color with chromatic aberration
  vec3 color = chromaticAberrationEffect(uv, chromaticAberration);

  // Apply holographic tint
  color = mix(color, hologramColor, 0.3);

  // Add scanlines
  float scanline = scanlines(uv, scanlineCount, scanlineSpeed, scanlineIntensity);
  color *= scanline;

  // Add holographic noise
  float holoNoise = holographicNoise(uv, noiseScale, noiseIntensity);
  color += hologramColor * holoNoise * 0.2;

  // Rim lighting (fresnel)
  vec3 rimColor = hologramColor * 1.5;
  color += rimColor * vFresnel * rimLightIntensity;

  // Beat-reactive glow
  float beatGlow = sin(beatPhase * 6.28318) * 0.5 + 0.5;
  color += hologramColor * beatGlow * 0.15;

  // Apply flicker
  color *= flicker(flickerSpeed, flickerIntensity);

  // Coherence-based color shift (high coherence = more stable, pure color)
  vec3 coherenceColor = mix(vec3(0.4, 0.6, 1.0), vec3(0.3, 1.0, 0.5), coherence);
  color = mix(color, color * coherenceColor, 0.2);

  // Final alpha with fresnel edge enhancement
  float alpha = opacity * (0.6 + vFresnel * 0.4);
  alpha *= (0.8 + holoNoise * 0.2);

  gl_FragColor = vec4(color, alpha);
}
`;

// ═══════════════════════════════════════════════════════════════════════════════
// GAUSSIAN SPLAT HOLOGRAPHIC SHADER
// ═══════════════════════════════════════════════════════════════════════════════

export const gaussianSplatVertexShader = /* glsl */ `
precision highp float;

// Splat attributes
attribute vec3 position;
attribute vec3 scale;
attribute vec4 rotation;     // Quaternion
attribute vec4 color;        // SH0 + opacity

// Standard uniforms
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform float time;
uniform float beatPhase;
uniform float coherence;
uniform float splatScale;
uniform vec2 viewport;

// Varyings
varying vec4 vColor;
varying vec2 vUv;
varying float vOpacity;

// Quaternion to rotation matrix
mat3 quatToMat3(vec4 q) {
  float x = q.x, y = q.y, z = q.z, w = q.w;
  return mat3(
    1.0 - 2.0*(y*y + z*z), 2.0*(x*y - w*z), 2.0*(x*z + w*y),
    2.0*(x*y + w*z), 1.0 - 2.0*(x*x + z*z), 2.0*(y*z - w*x),
    2.0*(x*z - w*y), 2.0*(y*z + w*x), 1.0 - 2.0*(x*x + y*y)
  );
}

void main() {
  // Beat-reactive scale
  float beatPulse = sin(beatPhase * 6.28318) * 0.1 + 1.0;
  vec3 scaledScale = scale * splatScale * beatPulse;

  // Apply coherence to stability
  scaledScale *= mix(0.9, 1.0, coherence);

  // Transform to camera space
  vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);

  // Billboard the splat
  mat3 rotMat = quatToMat3(rotation);
  vec3 cameraRight = vec3(modelViewMatrix[0][0], modelViewMatrix[1][0], modelViewMatrix[2][0]);
  vec3 cameraUp = vec3(modelViewMatrix[0][1], modelViewMatrix[1][1], modelViewMatrix[2][1]);

  // Expand to quad
  vec2 quadOffset = (uv - 0.5) * 2.0;
  mvPosition.xy += quadOffset * scaledScale.xy;

  vColor = color;
  vOpacity = color.a;
  vUv = uv;

  gl_Position = projectionMatrix * mvPosition;
}
`;

export const gaussianSplatFragmentShader = /* glsl */ `
precision highp float;

uniform float time;
uniform float scanlineIntensity;
uniform float chromaticAberration;
uniform float coherence;
uniform float beatPhase;
uniform vec3 hologramColor;
uniform float hologramMix;

varying vec4 vColor;
varying vec2 vUv;
varying float vOpacity;

void main() {
  // Gaussian falloff
  vec2 centered = vUv - 0.5;
  float dist = dot(centered, centered);
  float gaussian = exp(-dist * 8.0);

  if (gaussian < 0.01) discard;

  vec3 color = vColor.rgb;

  // Mix with hologram color based on setting
  color = mix(color, hologramColor, hologramMix);

  // Subtle scanlines for holographic effect
  float scanline = sin((vUv.y + time * 0.5) * 50.0) * 0.5 + 0.5;
  color *= 1.0 - scanline * scanlineIntensity * 0.3;

  // Beat glow
  float beatGlow = sin(beatPhase * 6.28318) * 0.5 + 0.5;
  color += hologramColor * beatGlow * 0.1;

  // Chromatic shift
  float shift = chromaticAberration * 0.02;
  vec3 shifted = vec3(
    color.r * (1.0 + shift),
    color.g,
    color.b * (1.0 - shift)
  );
  color = mix(color, shifted, 0.5);

  float alpha = gaussian * vOpacity;
  alpha *= mix(0.8, 1.0, coherence);

  gl_FragColor = vec4(color, alpha);
}
`;

// ═══════════════════════════════════════════════════════════════════════════════
// SHADER DEFAULTS
// ═══════════════════════════════════════════════════════════════════════════════

export const defaultHolographicUniforms = {
  time: 0,
  scanlineIntensity: 0.15,
  scanlineSpeed: 0.5,
  scanlineCount: 100.0,
  chromaticAberration: 0.5,
  glitchIntensity: 0.3,
  glitchSpeed: 1.0,
  noiseScale: 5.0,
  noiseIntensity: 0.1,
  hologramColor: [0.3, 0.7, 1.0] as [number, number, number],
  rimLightIntensity: 1.0,
  flickerSpeed: 1.0,
  flickerIntensity: 0.05,
  distortionAmount: 0.1,
  coherence: 0.7,
  beatPhase: 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE-OPTIMIZED SIMPLE SHADER (Fallback for low-end devices)
// ═══════════════════════════════════════════════════════════════════════════════

export const simplifiedFragmentShader = /* glsl */ `
precision mediump float;

uniform float time;
uniform float scanlineIntensity;
uniform vec3 hologramColor;
uniform float coherence;
uniform float beatPhase;

varying vec2 vUv;
varying float vFresnel;

void main() {
  vec3 color = hologramColor;

  // Simple scanlines
  float scanline = sin((vUv.y + time * 0.3) * 80.0) * 0.5 + 0.5;
  color *= 1.0 - scanline * scanlineIntensity;

  // Simple fresnel rim
  color += hologramColor * vFresnel * 0.5;

  // Beat pulse
  float beat = sin(beatPhase * 6.28318) * 0.5 + 0.5;
  color += hologramColor * beat * 0.1;

  float alpha = 0.8 + vFresnel * 0.2;

  gl_FragColor = vec4(color, alpha);
}
`;
