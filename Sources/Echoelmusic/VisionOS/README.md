# VisionOS Module

visionOS immersive space experiences for Echoelmusic.

## Overview

The VisionOS module provides full 360° quantum light immersive experiences for Apple Vision Pro, including spatial audio, gesture handling, and bio-reactive visualizations.

## Key Components

| Component | Description |
|-----------|-------------|
| `ImmersiveQuantumSpace` | Main 360° immersive experience |
| `VisionOSAnimationController` | Heart-sync, breathing animations |
| `VisionOSGestureHandler` | Spatial gesture recognition |
| `VisionOSHapticEngine` | Haptic feedback patterns |
| `VisionOSParticleLOD` | Adaptive particle rendering |

## Animation Types

| Animation | Description |
|-----------|-------------|
| Heart Sync | Pulsing synced to BPM |
| Floating | Smooth orbital motion |
| Breathing | 4-7-8 breathing cycle |
| Coherence Color | Dynamic hue from coherence |

## Gesture Effects (10)

- `harmonize` - Fibonacci spiral alignment
- `expand` / `contract` - Scale light field
- `spiral` - Vortex animation
- `pulse` - Radial wave
- `collapse` - Quantum state collapse
- `scatter` / `converge` - Particle dispersion
- `ripple` - Surface wave
- `vortex` - 3D tornado

## Usage

```swift
// Create immersive space
ImmersiveQuantumSpace(emulator: quantumEmulator)
    .colorBlindSafe(.protanopia)

// Handle gestures
VisionOSGestureHandler { gesture in
    switch gesture {
    case .pinch: applyEffect(.harmonize)
    case .rotate: applyEffect(.spiral)
    }
}
```

## Color-Blind Safe Palettes

| Mode | Description |
|------|-------------|
| Protanopia | Red-blind safe |
| Deuteranopia | Green-blind safe |
| Tritanopia | Blue-blind safe |
| Monochrome | Full grayscale |
| High Contrast | Maximum visibility |

## Performance

- Target: 60 FPS sustained
- Particle LOD: 5 levels (10K → 1K)
- Frustum culling enabled
- Adaptive quality based on frame rate

## Dependencies

- RealityKit
- Quantum module
- Biofeedback module
