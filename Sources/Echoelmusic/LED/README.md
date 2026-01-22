# LED Module

Ableton Push 3 LED control and DMX/Art-Net lighting.

## Overview

The LED module controls hardware lighting systems including Ableton Push 3 RGB LEDs and professional DMX/Art-Net fixtures.

## Key Components

| Component | Description |
|-----------|-------------|
| `Push3LEDController` | Ableton Push 3 LED matrix control |
| `MIDIToLightMapper` | MIDI to lighting parameter mapping |
| `DMXController` | DMX-512 output via Art-Net |

## Push 3 LED Control

```swift
let controller = Push3LEDController()

// Set pad color
controller.setPadColor(row: 0, col: 0, color: .red)

// Bio-reactive mode
controller.enableBioMode(coherence: 0.85)
```

## DMX/Art-Net

| Feature | Support |
|---------|---------|
| DMX Channels | 512 per universe |
| Art-Net | v4 compatible |
| sACN | E1.31 support |
| Fixtures | Moving heads, PARs, LEDs, Lasers |

## Bio-Reactive Lighting

| Bio Input | Light Effect |
|-----------|-------------|
| Heart Rate | Pulse intensity |
| HRV Coherence | Color warmth |
| Breathing | Scan speed |

## Network Configuration

- Default IP: 192.168.1.100
- Art-Net Port: 6454
- Universe: 0-15
