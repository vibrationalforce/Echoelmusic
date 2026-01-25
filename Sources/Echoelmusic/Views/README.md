# Views Module

SwiftUI views and UI components for the Echoelmusic app.

## Overview

This module contains all SwiftUI views used across the application, including visualization views, onboarding flows, settings interfaces, and specialized component views.

## Key Components

### Visualization Views

- **`QuantumVisualizationView`** - Main quantum photonics visualization with coherence-reactive gradients
- **`VisualizerContainerView`** - Container for multiple visualization modes
- **`BioModulatorVisualization`** - Bio-reactive parameter visualization
- **`WeatherReactiveView`** - Weather-aware ambient visualizations

### Onboarding

- **`OnboardingFlow`** - Complete 5-step onboarding experience
- **`OnboardingManager`** - Singleton managing onboarding state and permissions

### App Components

- **`HardwarePickerView`** - Hardware device selection UI
- **`StreamingView`** - Live streaming controls and preview
- **`AppStoreScreenshots`** - Marketing screenshot generation views

### Vaporwave Theme

- **`VaporwavePalace`** - Main vaporwave-themed interface
- **`VaporwaveApp`** - App entry point with vaporwave styling
- **`VaporwaveExport`** - Export with vaporwave aesthetics
- **`VaporwaveSessions`** - Session browser with retro styling
- **`VaporwaveSettings`** - Settings with vaporwave theme

### Phase 8000 Views

- **`Phase8000Views`** - Demo views for Phase 8000 features including video processing, creative studio, and wellness interfaces

## Architecture

Views follow the MVVM pattern with:
- `@StateObject` for owned view models
- `@ObservedObject` for injected dependencies
- `@Environment` for system values
- `@State` for local view state

## Accessibility

All views implement WCAG 2.2 AAA compliance:
- VoiceOver labels and hints
- Dynamic Type support
- Reduced Motion support
- High Contrast support

## Usage

```swift
// Quantum visualization
let emulator = QuantumLightEmulator()
QuantumVisualizationView(emulator: emulator)

// Onboarding
if !OnboardingManager.shared.hasCompletedOnboarding {
    OnboardingView()
}

// Step sequencer
VisualStepSequencerView()
```

## Files

| File | Description |
|------|-------------|
| `OnboardingFlow.swift` | 5-step user onboarding |
| `QuantumVisualizationView.swift` | Quantum light visualization |
| `VisualStepSequencerView.swift` | Bio-reactive sequencer UI |
| `HardwarePickerView.swift` | Device selection interface |
| `StreamingView.swift` | Live streaming controls |
| `Phase8000Views.swift` | Phase 8000 demo interfaces |

## Dependencies

- SwiftUI
- Combine
- MetalKit (for GPU rendering)
- AVFoundation (for streaming)
