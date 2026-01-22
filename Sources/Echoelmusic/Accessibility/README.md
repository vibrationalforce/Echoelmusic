# Accessibility Module

WCAG 2.2 AAA compliant accessibility features.

## Overview

The Accessibility module ensures Echoelmusic is usable by everyone, regardless of ability. It implements 20+ accessibility profiles and supports all major assistive technologies.

## Key Components

| Component | Description |
|-----------|-------------|
| `AccessibilityManager` | Central accessibility coordinator |
| `QuantumAccessibility` | Quantum-aware accessibility |
| `InclusiveMobilityManager` | 40+ accessibility features |

## Accessibility Profiles (20+)

| Profile | Description |
|---------|-------------|
| `.low_vision` | Large text, high contrast |
| `.blind` | Full VoiceOver/TalkBack |
| `.color_blind` | 6 color-safe palettes |
| `.deaf` | Visual alerts, captions |
| `.motor_limited` | Large targets, voice control |
| `.cognitive` | Simplified UI |
| `.autism_friendly` | Calm, predictable |
| `.photosensitive` | Safe animations |

## Usage

```swift
let manager = AccessibilityManager()
manager.applyProfile(.low_vision)

// Announce state changes
manager.announce("Coherence is 85 percent")
```

## Color Schemes

| Scheme | Description |
|--------|-------------|
| `.protanopia` | Red-blind safe |
| `.deuteranopia` | Green-blind safe |
| `.tritanopia` | Blue-blind safe |
| `.monochrome` | Full grayscale |
| `.highContrast` | Maximum contrast |

## Input Modes

- Touch
- Voice commands
- Switch access
- Eye tracking
- Head tracking
- External keyboard

## WCAG Compliance

- Level AAA conformance
- 4.5:1 minimum contrast ratio
- Focus indicators on all interactive elements
