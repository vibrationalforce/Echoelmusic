# EchoelmusicMIDI

**Purpose:** MIDI 2.0 / MPE handling.

## Responsibilities

- Parse/construct MIDI2 Universal MIDI Packets (UMP)
- Route MIDI to tracks and parameters
- Provide MPE mapping helpers

## Getting Started

```swift
import EchoelmusicMIDI

// Send MIDI 2.0 message
let message = MIDI2Message.noteOn(
    channel: 0,
    note: 60,
    velocity: 0x8000_0000, // 32-bit velocity
    attributeType: 0,
    attributeData: 0
)
try midiManager.send(message)

// Register handler
midiManager.onReceive { message in
    print("MIDI received: \(message)")
}
```

## Testing

MIDI parsing tests in `Tests/EchoelmusicMIDITests`

## Notes

- Keep API compatible with Cortex/MIDI stacks
- Full MIDI 2.0 UMP support
- MPE zone management included
