# Shaders Module

Metal GPU shaders for real-time visualization and effects.

## Overview

This module contains Metal shaders for GPU-accelerated rendering of quantum visualizations, bio-reactive effects, and real-time graphics processing.

## Shader Files

### QuantumPhotonicsShader.metal

Main shader for quantum light visualization:

- Interference patterns
- Wave functions
- Photon particles
- Coherence fields
- Sacred geometry

### Features

- 60 Hz real-time rendering
- Bio-reactive color modulation
- Coherence-driven effects
- 300%+ performance vs CPU rendering

## Shader Functions

### Vertex Shaders

```metal
vertex VertexOut quantumVertex(
    const device VertexIn* vertices [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
);
```

### Fragment Shaders

```metal
fragment float4 interferenceFragment(
    VertexOut in [[stage_in]],
    constant FragmentUniforms& uniforms [[buffer(0)]]
);

fragment float4 waveFunction Fragment(
    VertexOut in [[stage_in]],
    constant WaveUniforms& uniforms [[buffer(0)]]
);

fragment float4 coherenceFieldFragment(
    VertexOut in [[stage_in]],
    constant BioUniforms& uniforms [[buffer(0)]]
);
```

## Uniforms

### Vertex Uniforms

```metal
struct Uniforms {
    float4x4 modelViewProjection;
    float time;
    float coherenceLevel;
};
```

### Bio-Reactive Uniforms

```metal
struct BioUniforms {
    float coherence;      // 0-1
    float heartRate;      // BPM
    float hrvVariability; // 0-1
    float breathPhase;    // 0-2π
};
```

## Visualization Modes

| Mode | Description |
|------|-------------|
| Interference Pattern | Wave interaction display |
| Wave Function | Probability amplitude |
| Coherence Field | Order vs chaos |
| Photon Flow | Particle system |
| Sacred Geometry | Flower of Life, Metatron's Cube |
| Quantum Tunnel | Vortex effect |
| Biophoton Aura | Energy layers |
| Light Mandala | Rotating patterns |
| Holographic | Interference fringes |
| Cosmic Web | Universe structure |

## Color Schemes

Color-blind safe palettes:

```metal
constant float3 normalPalette[] = {...};
constant float3 protanopiaPalette[] = {...};
constant float3 deuteranopiaPalette[] = {...};
constant float3 tritanopiaPalette[] = {...};
constant float3 monochromePalette[] = {...};
constant float3 highContrastPalette[] = {...};
```

## Performance

- Optimized for Apple Silicon
- Dynamic LOD (Level of Detail)
- Frustum culling
- Instanced rendering for particles

## Integration

```swift
// Create Metal pipeline
let library = device.makeDefaultLibrary()!
let vertexFunction = library.makeFunction(name: "quantumVertex")
let fragmentFunction = library.makeFunction(name: "interferenceFragment")

// Set uniforms
var uniforms = Uniforms()
uniforms.coherenceLevel = coherence
uniforms.time = Float(CACurrentMediaTime())
```

## Files

| File | Description |
|------|-------------|
| `QuantumPhotonicsShader.metal` | Main shader collection |
| `QuantumPhotonicsVisionOS.metal` | visionOS-specific shaders |
