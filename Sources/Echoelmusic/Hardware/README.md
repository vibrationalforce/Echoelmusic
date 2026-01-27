# Hardware Module

Universal hardware ecosystem integration for Echoelmusic.

## Overview

The Hardware module provides a universal device registry and cross-platform session management, enabling ANY device combination to work together seamlessly.

## Key Components

| Component | Description |
|-----------|-------------|
| `HardwareEcosystem` | Universal device registry |
| `CrossPlatformSessionManager` | Multi-device session orchestration |
| `HardwarePickerView` | SwiftUI device selection UI |

## Supported Hardware

### Audio Interfaces (60+)

| Brand | Examples |
|-------|----------|
| Universal Audio | Apollo, Arrow, Volt |
| Focusrite | Scarlett, Clarett |
| RME | Fireface, Babyface |
| MOTU | M-Series, UltraLite |

### MIDI Controllers (40+)

| Brand | Examples |
|-------|----------|
| Ableton | Push 3 |
| Native Instruments | Maschine, Komplete Kontrol |
| Akai | MPC, APC |
| Novation | Launchpad, Circuit |

### Lighting

- DMX/Art-Net fixtures
- Moving heads, PARs
- LED strips, Laser systems

### Wearables

- Apple Watch, Garmin, Whoop
- Oura Ring, Polar, Fitbit

## Usage

```swift
let ecosystem = HardwareEcosystem.shared

// Discover devices
let devices = ecosystem.discoverDevices()

// Start cross-platform session
let session = CrossPlatformSessionManager()
session.addDevice(.iPhone)
session.addDevice(.windowsPC)
session.start()
```

## Platform-Specific Audio APIs

| Platform | API |
|----------|-----|
| iOS/macOS | Core Audio |
| Windows | WASAPI/ASIO |
| Linux | PipeWire/JACK |
| Android | AAudio/Oboe |

## Device Combinations

- iPhone + Windows PC
- MacBook + Meta Quest
- Apple Watch + Android
- Any combination works!
