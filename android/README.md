# Echoelmusic Android

Bio-Reactive Audio-Visual Platform for Android

## Features

- **Ultra-Low-Latency Audio**: Oboe (AAudio/OpenSL ES) with < 10ms latency on supported devices
- **16-Voice Polyphonic Synth**: Band-limited oscillators, Moog filter, ADSR envelopes
- **Pulse Drum Bass Engine**: Authentic 808 bass with pitch glide
- **MIDI Support**: USB and Bluetooth MIDI with MPE
- **Bio-Reactive**: Health Connect integration for heart rate, HRV, coherence
- **Quantum AI**: Quantum-inspired composition and pattern generation

## Requirements

- Android Studio Hedgehog (2023.1.1) or later
- Android SDK 34
- NDK 25.2 or later
- Kotlin 1.9+
- CMake 3.22+

## Build Instructions

```bash
# Clone and open in Android Studio
cd android
./gradlew assembleDebug

# Or build release
./gradlew assembleRelease
```

## Architecture

```
android/
├── app/
│   ├── src/main/
│   │   ├── java/com/echoelmusic/app/
│   │   │   ├── audio/         # Kotlin audio engine wrapper
│   │   │   ├── midi/          # MIDI manager
│   │   │   ├── bio/           # Health Connect integration
│   │   │   └── ui/            # Jetpack Compose UI
│   │   ├── cpp/               # Native audio (Oboe)
│   │   │   ├── EchoelmusicEngine.cpp
│   │   │   ├── Synth.cpp
│   │   │   ├── TR808Engine.cpp
│   │   │   └── jni_bridge.cpp
│   │   └── res/               # Resources
│   └── build.gradle.kts
└── build.gradle.kts
```

## Audio Latency

| Device Type | Expected Latency |
|-------------|-----------------|
| Pixel Pro (AAudio) | 5-10ms |
| Samsung Galaxy (AAudio) | 10-20ms |
| Older devices (OpenSL ES) | 30-50ms |

## Health Connect Permissions

The app requests read access to:
- Heart Rate
- Heart Rate Variability (HRV)
- Respiratory Rate

These are used for bio-reactive audio modulation.

## License

MIT License - See LICENSE file
