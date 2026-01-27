# Wellness Module

General wellness tracking and guided experiences.

## Overview

The Wellness module provides non-medical wellness tracking including guided meditations, breathing exercises, journaling, and sound bath generation.

**DISCLAIMER: For general wellness only, NOT medical advice.**

## Key Components

| Component | Description |
|-----------|-------------|
| `WellnessTrackingEngine` | Core wellness session management |
| `BreathingPatternGuide` | Guided breathing exercises |
| `SoundBathGenerator` | Ambient sound generation |
| `WellnessJournal` | Personal reflection journaling |

## Wellness Categories (25+)

| Category | Examples |
|----------|----------|
| Relaxation | Stress relief, calm |
| Mindfulness | Present awareness |
| Focus | Concentration, clarity |
| Energy | Vitality, alertness |
| Rest | Sleep preparation |

## Breathing Patterns (6)

| Pattern | Timing | Purpose |
|---------|--------|---------|
| Box | 4-4-4-4 | Balance, focus |
| 4-7-8 | 4-7-8 | Sleep, relaxation |
| Energizing | 1-1 rapid | Energy boost |
| Calming | 4-6 | Anxiety relief |
| Coherence | 5-5 | Heart coherence |
| Custom | Variable | User-defined |

## Sound Bath Types (12)

- Singing Bowls, Gong
- Binaural Beats, Isochronic Tones
- Nature Sounds, White/Pink Noise
- Tibetan Bells, Crystal Bowls

## Usage

```swift
let wellness = WellnessTrackingEngine()

// Start breathing session
wellness.startBreathing(pattern: .coherence, duration: 300)

// Generate sound bath
wellness.playSoundBath(type: .singingBowls)

// Track session
wellness.onSessionComplete { summary in
    print("Duration: \(summary.duration)")
    print("Avg coherence: \(summary.avgCoherence)")
}

// Add journal entry
wellness.addJournalEntry(
    mood: .calm,
    notes: "Felt very relaxed today"
)
```

## Goals & Progress

Track wellness goals:
- Daily meditation minutes
- Coherence sessions per week
- Breathing practice streaks

## Health Disclaimer

This module is for general wellness purposes only:
- NOT a medical device
- NOT for diagnosing conditions
- NOT a substitute for professional care

Consult healthcare providers for health concerns.
