# Creative Module

AI-powered creative studio for art and music generation.

## Overview

The Creative module provides AI-driven creative tools including art generation, music composition, fractal visualization, and light show design.

## Key Components

| Component | Description |
|-----------|-------------|
| `CreativeStudioEngine` | Main creative studio orchestrator |
| `AIArtGenerator` | AI-powered visual art generation |
| `AIMusicComposer` | AI music composition engine |
| `FractalGenerator` | Procedural fractal creation |

## Features

### Art Styles (30+)

| Category | Styles |
|----------|--------|
| Classic | Impressionism, Cubism, Surrealism |
| Modern | Abstract, Minimalist, Pop Art |
| Digital | Cyberpunk, Synthwave, Glitch |
| Spiritual | Sacred Geometry, Mandala, Quantum |

### Music Genres (30+)

| Category | Genres |
|----------|--------|
| Ambient | Drone, Space, Nature |
| Electronic | Techno, House, IDM |
| World | Gamelan, Raga, Celtic |
| Experimental | Quantum Music, Bio-Reactive |

### Fractal Types (11)

- Mandelbrot, Julia, Burning Ship
- Newton, Phoenix, Buddhabrot
- Lyapunov, Quantum Perturbation

## Usage

```swift
let studio = CreativeStudioEngine()

// Generate AI art
let art = try await studio.generateArt(
    style: .sacredGeometry,
    bioData: currentBioData
)

// Compose music
let music = try await studio.composeMelody(
    genre: .ambient,
    coherence: 0.75
)

// Create fractal
let fractal = studio.generateFractal(.mandelbrot, depth: 100)
```

## Bio-Reactive Creation

Creative output automatically responds to:
- Coherence → Color harmony
- Heart rate → Tempo
- Breathing → Rhythm density

## Dependencies

- CoreML (iOS/macOS)
- Metal (GPU acceleration)
- Quantum module
