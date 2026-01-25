# NeuroSpiritual Module

Psychosomatic data science integration for embodied consciousness.

## Overview

The NeuroSpiritual module integrates facial expression analysis, gesture recognition, body movement, and biofeedback into a unified psychosomatic state model based on scientific research.

## Key Components

| Component | Description |
|-----------|-------------|
| `NeuroSpiritualEngine` | Main psychosomatic integration engine |
| `FacialExpressionAnalyzer` | FACS-based expression analysis |
| `GestureAnalyzer` | Hand and body gesture recognition |
| `PolyvagalStateTracker` | Stephen Porges theory integration |

## Consciousness States (10)

| State | Frequency | Description |
|-------|-----------|-------------|
| Delta | 0.5-4 Hz | Deep sleep |
| Theta | 4-8 Hz | Meditation |
| Alpha | 8-12 Hz | Relaxation |
| SMR | 12-15 Hz | Calm focus |
| Beta | 15-30 Hz | Active thinking |
| Gamma | 30-100 Hz | Peak cognition |
| Flow | Variable | Optimal performance |
| Unitive | Variable | Transcendent experience |

## Polyvagal States (5)

Based on Stephen Porges' Polyvagal Theory:

| State | Description |
|-------|-------------|
| Ventral Vagal | Social engagement, safety |
| Sympathetic | Fight/flight activation |
| Dorsal Vagal | Shutdown, freeze |
| Blended Safe | Mixed safe states |
| Blended Threat | Mixed threat states |

## FACS (Facial Action Coding System)

8 Action Units tracked:
- AU1: Inner Brow Raise
- AU2: Outer Brow Raise
- AU4: Brow Lower
- AU5: Upper Lid Raise
- AU6: Cheek Raise
- AU12: Lip Corner Pull
- AU26: Jaw Drop
- Duchenne Smile (AU6+AU12)

## Reich/Lowen Body Segments (7)

| Segment | Location |
|---------|----------|
| Ocular | Eyes, forehead |
| Oral | Mouth, jaw |
| Cervical | Neck, throat |
| Thoracic | Chest, shoulders |
| Diaphragm | Diaphragm area |
| Abdominal | Belly |
| Pelvic | Pelvis, legs |

## Usage

```swift
let neuro = NeuroSpiritualEngine()

// Analyze facial expression
let expression = neuro.analyzeFacialExpression(faceAnchor)

// Track polyvagal state
let polyvagal = neuro.trackPolyvagalState(bioData)

// Get integrated psychosomatic state
let state = neuro.getPsychosomaticState()
```

## Scientific Basis

- **Polyvagal Theory** - Stephen Porges
- **FACS** - Paul Ekman
- **Embodied Cognition** - Varela, Thompson, Rosch
- **HeartMath Institute** - Heart-brain coherence

## Disclaimer

Spiritual features are for creative and meditative purposes only. Not medical advice.
