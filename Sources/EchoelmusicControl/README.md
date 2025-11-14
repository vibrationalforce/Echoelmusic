# EchoelmusicControl

**Purpose:** UnifiedControlHub, multi-modal inputs, command routing.

## Responsibilities

- Input providers (touch, voice, MIDI, gesture, bio)
- Command routing & priority handling
- Control loop (60Hz) for parameter updates and mapping

## Getting Started

```swift
import EchoelmusicControl

// Create unified control hub
let hub = UnifiedControlHub()
hub.start()

// Register input provider
let voiceProvider = VoiceInputProvider()
hub.registerInput(voiceProvider)

// Enable specific modality
try await hub.enableInput(.voice)
```

## Testing

ControlHub tick tests verify loop frequency and command dispatch.

## Architecture

- **Hub/**: UnifiedControlHub implementation
- **Voice/**: Voice command engine
- **Gesture/**: Gesture recognition
- **Prediction/**: Predictive input (Phase 4)

## Notes

- 60Hz control loop target
- Priority-based input conflict resolution
