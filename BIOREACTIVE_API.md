# Echoelmusic Bio-Reactive API

## Overview

The Bio-Reactive System is the **core innovation** of Echoelmusic - real-time audio/visual modulation based on physiological signals (HRV, Coherence, Heart Rate).

**Unique Selling Point:** No other DAW or audio tool offers this.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ECHOELMUSIC BIO-REACTIVE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────┐  │
│  │  BIO INPUT  │────▶│   MODULATOR      │────▶│   OUTPUT    │  │
│  │             │     │                  │     │             │  │
│  │ • Apple Watch│     │ • HRV → Filter   │     │ • Audio DSP │  │
│  │ • Polar H10 │     │ • Coherence→Reverb│    │ • OSC/MIDI  │  │
│  │ • Bluetooth │     │ • Stress → Comp  │     │ • Visuals   │  │
│  │ • Simulated │     │ • HR → Delay     │     │ • Lighting  │  │
│  └─────────────┘     └──────────────────┘     └─────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. BioDataInput (Sources/BioData/ + Sources/Wearable/)
```cpp
// Supported input sources
enum class SourceType {
    AppleWatch,      // HealthKit + WatchConnectivity (iOS/watchOS)
    PolarH10,        // Bluetooth BLE HR sensor (standard HR profile)
    OuraRing,        // Oura Ring via OAuth2 REST API
    BluetoothHR,     // Generic BLE heart rate devices
    Simulated        // For testing/demo
};

// Bio-data types available
enum class BioDataType {
    HeartRate,       // BPM (real-time)
    HRV,             // Heart Rate Variability (RMSSD)
    EnergyLevel,     // Computed from HRV + activity
    StressLevel,     // Derived from HRV metrics
    SleepQuality,    // Oura Ring sleep data
    Readiness,       // Oura Ring readiness score
    SpO2,            // Blood oxygen (Apple Watch)
    Motion           // Accelerometer/Gyro data
};
```

### 2. HRVProcessor (Sources/BioData/HRVProcessor.h)
```cpp
// HeartMath-inspired coherence algorithm
class HRVProcessor {
    float calculateCoherence();  // 0-1 coherence score
    float calculateRMSSD();      // HRV variability
    float getStressIndex();      // Derived stress level
};
```

### 3. BioReactiveModulator (Sources/BioData/BioReactiveModulator.h)
```cpp
// Maps bio-data to audio parameters
struct ModulatedParameters {
    float filterCutoff;      // 20-20000 Hz (HRV)
    float reverbMix;         // 0-1 (Coherence)
    float compressionRatio;  // 1-20 (Stress)
    float delayTime;         // 0-2000ms (Heart Rate sync)
    float distortionAmount;  // 0-1 (Stress)
    float lfoRate;           // 0.1-20 Hz (Breathing)
};
```

### 4. BioReactiveAudioProcessor (Sources/DSP/BioReactiveAudioProcessor.h)
```cpp
// Real-time DSP with bio-modulation
class BioReactiveAudioProcessor {
    void prepare(double sampleRate, int blockSize, int channels);
    void process(AudioBuffer& buffer, ModulatedParameters& params);
};
```

---

## Integration Points

### For Plugin Developers (VST3/AU)
```cpp
// In your PluginProcessor::processBlock()
bioFeedback.update();
auto params = bioFeedback.getModulatedParameters();
bioProcessor.process(buffer, params);
```

### For Visual Artists (OSC Output)
```
/echoelmusic/bio/hrv          [float 0-1]
/echoelmusic/bio/coherence    [float 0-1]
/echoelmusic/bio/heartrate    [float 40-200]
/echoelmusic/bio/stress       [float 0-1]
/echoelmusic/mod/filter       [float 20-20000]
/echoelmusic/mod/reverb       [float 0-1]
```

### For Mobile (Swift/iOS)
```swift
// HealthKitManager provides:
healthKitManager.heartRate      // Double (BPM)
healthKitManager.hrvRMSSD       // Double (ms)
healthKitManager.hrvCoherence   // Double (0-100)
```

---

## Modulation Mappings

| Bio Signal | Audio Parameter | Relationship |
|------------|-----------------|--------------|
| HRV (high) | Filter Cutoff | Higher HRV = brighter sound |
| Coherence (high) | Reverb Mix | Higher coherence = more spacious |
| Stress (high) | Compression | Higher stress = more controlled |
| Heart Rate | Delay Time | Synced to heartbeat rhythm |
| Breathing | LFO Rate | Synced to breath cycle |

---

## Use Cases

### 1. Live Performance (DJ/Producer)
- Performer's heart rate controls the energy
- Coherence affects the "vibe" (reverb/space)
- Audience sees the connection (visuals sync)

### 2. Meditation/Wellness App
- Coherence guides the user to calm state
- Audio becomes more harmonious as user relaxes
- Gamification through sound quality

### 3. Therapeutic Music
- Binaural beats synced to HRV
- Solfeggio frequencies modulated by coherence
- Personalized healing soundscapes

### 4. Creative Tool
- "Happy accidents" from bio-modulation
- Unique, unrepeatable recordings
- Human element in electronic music

---

## External Integration

### Ableton Live (via Max for Live)
```
[receive echoelmusic_hrv] → [scale 0 1 0.5 4] → [live.dial @varname filter]
```

### TouchDesigner / Resolume (via OSC)
```python
# Receive OSC from Echoelmusic
coherence = args[0]  # /echoelmusic/bio/coherence
visual_intensity = coherence * glow_amount
```

### Lighting (DMX via OSC)
```
/echoelmusic/bio/coherence → DMX Channel 1 (intensity)
/echoelmusic/bio/heartrate → DMX Channel 2 (strobe rate)
```

---

## Wearable Integration System (Sources/Wearable/)

### Device Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    WEARABLE INTEGRATION LAYER                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │  WearableManager│    │   BLEScanner    │                     │
│  │    (Singleton)  │    │   (Singleton)   │                     │
│  └────────┬────────┘    └────────┬────────┘                     │
│           │                      │                               │
│  ┌────────▼────────────────────▼─────────────────────────────┐ │
│  │                    DEVICE DRIVERS                          │ │
│  ├───────────────┬───────────────┬───────────────────────────┤ │
│  │ AppleWatch    │ OuraRing      │ PolarH10                  │ │
│  │ WCSession +   │ OAuth2 +      │ BLE Heart Rate            │ │
│  │ HealthKit     │ REST API      │ Measurement Char.         │ │
│  └───────────────┴───────────────┴───────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Apple Watch Integration (WatchConnectivityBridge)

```cpp
// Real-time bio-data via WCSession
class WatchConnectivityBridge {
    void activate();                          // Start WCSession
    bool isReachable();                       // Watch connected?
    void sendHaptic(int pattern, float intensity);

    // Callbacks
    std::function<void(double)> onHeartRateReceived;
    std::function<void(double)> onHRVReceived;
    std::function<void(double, double, double)> onMotionReceived;
};
```

### Oura Ring OAuth2 Integration

```cpp
// Complete OAuth2 flow with token management
class OuraOAuth2Handler {
    std::string getAuthorizationUrl();        // Generate auth URL with CSRF state
    bool exchangeCodeForToken(const std::string& code, const std::string& state);
    bool refreshAccessToken();                // Auto-refresh before expiry
    std::string serializeTokens();            // Persist tokens to keychain
    void deserializeTokens(const std::string& data);
};

// API Endpoints:
// GET /v2/usercollection/daily_readiness
// GET /v2/usercollection/daily_sleep
// GET /v2/usercollection/heartrate
```

### BLE Scanner

```cpp
// Generic BLE device discovery and connection
class BLEScanner {
    void startScanning(const std::vector<std::string>& serviceUUIDs);
    void stopScanning();
    void connectDevice(const std::string& deviceId);

    // Standard BLE Services:
    static constexpr const char* HEART_RATE_SERVICE = "180D";
    static constexpr const char* HEART_RATE_MEASUREMENT = "2A37";
    static constexpr const char* BODY_SENSOR_LOCATION = "2A38";
};
```

### Polar H10 HR Parsing (Bluetooth Spec Compliant)

```cpp
// Proper HR Measurement Characteristic parsing per Bluetooth SIG spec
void parseHeartRateMeasurement(const uint8_t* data, size_t len) {
    uint8_t flags = data[0];
    bool isUint16 = (flags & 0x01);           // Bit 0: HR format
    bool hasRRInterval = (flags & 0x10);      // Bit 4: RR present

    // Extract heart rate (UINT8 or UINT16)
    double heartRate = isUint16 ?
        (data[1] | (data[2] << 8)) : data[1];

    // Extract RR intervals for HRV calculation
    if (hasRRInterval) {
        // RR values are in 1/1024 second units
        for each RR value:
            rrIntervalMs = (rrValue / 1024.0) * 1000.0;
    }
}
```

### Bio-Modulation Mapping

```cpp
// Map bio-signals to audio parameters
struct BioModulationMapping {
    BioDataType sourceType;        // e.g., HeartRate
    std::string targetParameter;   // e.g., "filterCutoff"
    double inputMin, inputMax;     // e.g., 60.0, 100.0 BPM
    double outputMin, outputMax;   // e.g., 0.0, 1.0
    CurveType curve;               // Linear, Exponential, Logarithmic
    double smoothingFactor;        // EMA smoothing (0-1)
};

// Example: Heart rate → filter cutoff
BioModulationMapping hrToFilter = {
    .sourceType = BioDataType::HeartRate,
    .targetParameter = "filterCutoff",
    .inputMin = 60.0, .inputMax = 100.0,
    .outputMin = 0.0, .outputMax = 1.0
};
// At 80 BPM → filter = 0.5
```

---

## Files

```
Sources/
├── BioData/
│   ├── BioReactiveModulator.h    # Parameter mapping
│   └── HRVProcessor.h            # Coherence algorithm
├── DSP/
│   ├── BioReactiveDSP.h/.cpp     # Core DSP engine
│   └── BioReactiveAudioProcessor.h # JUCE integration
├── Wearable/
│   └── WearableIntegration.h     # Complete wearable integration
│       ├── WearableDevice (base) # Abstract device interface
│       ├── AppleWatchDevice      # HealthKit + WCSession
│       ├── OuraRingDevice        # OAuth2 + REST API
│       ├── PolarH10Device        # BLE HR + HRV
│       ├── SimulatorDevice       # Testing device
│       ├── WearableManager       # Device orchestration
│       ├── BLEScanner            # BLE discovery
│       ├── OuraOAuth2Handler     # OAuth2 flow
│       └── WatchConnectivityBridge # iOS ↔ watchOS
├── Visualization/
│   ├── BioReactiveVisualizer.h/.cpp # Visual feedback
└── Echoelmusic/ (Swift)
    ├── Biofeedback/
    │   └── HealthKitManager.swift # Apple Watch integration
    └── Platforms/watchOS/
        └── WatchApp.swift         # watchOS app
```

---

## License & IP

**Copyright (c) 2024-2025 Echoelmusic**

The Bio-Reactive System is proprietary technology.
Contact for licensing: [TBD]

---

## For Potential Partners

This technology is ready for:
- [ ] Plugin integration (VST3/AU/AAX)
- [ ] Mobile app (iOS/watchOS)
- [ ] Hardware integration (wearables)
- [ ] Visual software (TouchDesigner, Resolume)
- [ ] DAW integration (Ableton, Logic)

**Interested? Let's talk.**
