/*
 *  EchoelAudioReactive.frag
 *  Echoelmusic — GLSL Fragment Shader
 *
 *  Created: February 2026
 *  Cross-platform audio-reactive visual effects.
 *  Runs on: OpenGL 3.3+ / OpenGL ES 3.0+ / WebGL 2.0
 *
 *  Features:
 *  - Audio spectrum visualization (FFT bins → color bands)
 *  - Bio-reactive aura generation
 *  - Cymatics overlay patterns
 *  - Beat-sync pulsation
 *  - Waveform display
 *
 *  Uniform inputs from host application or OFX plugin.
 */

#version 330 core

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Uniforms                                                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

/* Audio analysis */
uniform float u_audioRMS;               /* 0-1: overall audio energy */
uniform float u_audioPeak;              /* 0-1: peak transient */
uniform float u_audioBass;              /* 0-1: low frequency energy (20-200 Hz) */
uniform float u_audioMid;               /* 0-1: mid frequency energy (200-2000 Hz) */
uniform float u_audioHigh;              /* 0-1: high frequency energy (2000-20000 Hz) */
uniform float u_audioSpectrum[64];      /* FFT magnitude bins */

/* Bio-reactive data */
uniform float u_bioCoherence;           /* 0-1: cardiac coherence */
uniform float u_bioHeartRate;           /* BPM (40-220) */
uniform float u_bioBreathPhase;         /* 0-1: inhale/exhale cycle */
uniform float u_bioHRV;                 /* Heart rate variability (ms) */

/* Time */
uniform float u_time;                   /* Seconds since start */
uniform float u_beatPhase;              /* 0-1: position within current beat */
uniform float u_bpm;                    /* Tempo in BPM */

/* Resolution */
uniform vec2 u_resolution;             /* Viewport size in pixels */

/* Source texture (if processing video) */
uniform sampler2D u_sourceTexture;
uniform bool u_hasSourceTexture;

/* Effect controls */
uniform float u_auraIntensity;          /* 0-1 */
uniform float u_cymaticsIntensity;      /* 0-1 */
uniform float u_spectrumIntensity;      /* 0-1 */
uniform float u_waveformIntensity;      /* 0-1 */
uniform float u_glowIntensity;          /* 0-1 */
uniform float u_mix;                    /* 0-1: overall effect mix */

/* I/O */
in vec2 v_texCoord;
out vec4 fragColor;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Constants                                                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

const float PI = 3.14159265359;
const float TAU = 6.28318530718;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Utility Functions                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

/* HSV → RGB conversion */
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

/* Smooth noise (value noise) */
float hash(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

/* Signed distance to circle */
float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Audio Spectrum Visualization                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

vec3 spectrumBars(vec2 uv) {
    float barCount = 64.0;
    float barWidth = 1.0 / barCount;
    int bin = int(uv.x * barCount);
    bin = clamp(bin, 0, 63);

    float magnitude = u_audioSpectrum[bin];
    float barHeight = magnitude * 0.8;

    /* Bar from bottom */
    if (uv.y < barHeight) {
        float hue = float(bin) / barCount * 0.7;  /* rainbow: red → violet */
        float brightness = 0.5 + magnitude * 0.5;
        return hsv2rgb(vec3(hue, 0.8, brightness)) * u_spectrumIntensity;
    }

    return vec3(0.0);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Bio-Reactive Aura                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

vec3 bioAura(vec2 uv) {
    vec2 center = vec2(0.5);
    float dist = length(uv - center);

    /* Aura radius pulsates with breath cycle */
    float breathMod = sin(u_bioBreathPhase * TAU) * 0.05;
    float baseRadius = 0.2 + u_bioCoherence * 0.15 + breathMod;

    /* Heart rate creates rhythmic pulsation */
    float heartPulse = sin(u_time * u_bioHeartRate / 60.0 * TAU) * 0.03;
    baseRadius += heartPulse;

    /* Coherence-driven color */
    vec3 auraColor;
    if (u_bioCoherence > 0.7) {
        /* High coherence: golden/green (heart chakra) */
        auraColor = vec3(0.9, 0.8, 0.2);
    } else if (u_bioCoherence > 0.4) {
        /* Medium coherence: blue/purple (calm) */
        auraColor = vec3(0.3, 0.4, 0.9);
    } else {
        /* Low coherence: red/orange (activating) */
        auraColor = vec3(0.9, 0.3, 0.2);
    }

    /* Organic edge with noise */
    float noiseVal = noise(uv * 8.0 + u_time * 0.5) * 0.1;
    float auraEdge = smoothstep(baseRadius + 0.1, baseRadius - 0.05, dist + noiseVal);

    /* Inner glow */
    float innerGlow = exp(-dist * dist * 12.0) * 0.3;

    return auraColor * (auraEdge * 0.6 + innerGlow) * u_auraIntensity;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Cymatics Pattern                                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

vec3 cymaticsPattern(vec2 uv) {
    vec2 p = (uv - 0.5) * 6.0;

    /* Mode numbers from audio frequency content */
    float m = 2.0 + u_audioMid * 6.0;
    float n = 2.0 + u_audioHigh * 4.0;

    /* Chladni pattern */
    float pattern = cos(m * PI * p.x) * cos(n * PI * p.y)
                  - cos(n * PI * p.x) * cos(m * PI * p.y);

    pattern = abs(pattern);
    pattern = pow(pattern, 1.0 + u_bioCoherence);  /* coherence sharpens */
    pattern *= u_audioBass * 2.0;                   /* bass drives intensity */

    /* Color: coherence-dependent palette */
    float hue = 0.55 + u_bioCoherence * 0.15;      /* cyan → green range */
    vec3 color = hsv2rgb(vec3(hue, 0.7, pattern));

    return color * u_cymaticsIntensity;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Beat-Sync Glow                                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

vec3 beatGlow(vec2 uv) {
    /* Flash on beat (peak transient) */
    float flash = pow(u_audioPeak, 3.0);

    /* Radial gradient from center */
    float dist = length(uv - 0.5);
    float glow = exp(-dist * dist * 8.0) * flash;

    /* Color shifts with tempo */
    float hue = fract(u_time * u_bpm / 60.0 / 4.0);
    vec3 color = hsv2rgb(vec3(hue, 0.6, 1.0));

    return color * glow * u_glowIntensity;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Main Shader                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

void main() {
    vec2 uv = v_texCoord;

    /* Base color: source texture or black */
    vec3 baseColor = vec3(0.0);
    if (u_hasSourceTexture) {
        baseColor = texture(u_sourceTexture, uv).rgb;
    }

    /* Accumulate effects */
    vec3 effects = vec3(0.0);

    /* 1. Audio spectrum bars */
    effects += spectrumBars(uv);

    /* 2. Bio-reactive aura */
    effects += bioAura(uv);

    /* 3. Cymatics overlay */
    effects += cymaticsPattern(uv);

    /* 4. Beat-sync glow */
    effects += beatGlow(uv);

    /* Mix with base */
    vec3 finalColor = mix(baseColor, baseColor + effects, u_mix);

    /* Tonemap (prevent HDR blowout) */
    finalColor = finalColor / (finalColor + vec3(1.0));

    fragColor = vec4(finalColor, 1.0);
}
