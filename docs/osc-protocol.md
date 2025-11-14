# OSC Protocol Specification - Echoelmusic

Version: 1.0.0
Last Updated: November 2025

## Overview

Das Echoelmusic OSC Protocol verbindet die iOS App (Client) mit dem Desktop Audio Engine (Server) über UDP. Es ermöglicht bidirektionale Kommunikation für Biofeedback-Daten, Audio-Analyse und System-Kontrolle.

## Connection Details

- **Protocol**: OSC (Open Sound Control) over UDP
- **Port**: 8000 (Desktop Server)
- **Discovery**: Bonjour `_echoel._udp` (optional)
- **Latency Target**: < 10ms
- **Packet Size**: Max 1024 bytes

## Message Types

### 1. Biofeedback Messages (iOS → Desktop)

#### Herzrate
```
Address: /echoel/bio/heartrate
Arguments: [float: bpm]
Range: 40.0 - 200.0
Rate: ~1 Hz (when available from HealthKit)
```

**Beispiel**:
```
/echoel/bio/heartrate 72.5
```

#### Heart Rate Variability (HRV)
```
Address: /echoel/bio/hrv
Arguments: [float: ms]
Range: 0.0 - 200.0
Rate: ~1 Hz
```

**Beispiel**:
```
/echoel/bio/hrv 45.2
```

#### Atemrate
```
Address: /echoel/bio/breathrate
Arguments: [float: breaths_per_minute]
Range: 5.0 - 30.0
Rate: ~0.5 Hz
```

**Beispiel**:
```
/echoel/bio/breathrate 16.0
```

#### Voice Pitch (Echtzeit)
```
Address: /echoel/audio/pitch
Arguments: [float: frequency_hz, float: confidence]
Range:
  - frequency: 80.0 - 1000.0 Hz
  - confidence: 0.0 - 1.0
Rate: ~60 Hz (audio buffer rate)
```

**Beispiel**:
```
/echoel/audio/pitch 220.0 0.85
```

#### Voice Amplitude
```
Address: /echoel/audio/amplitude
Arguments: [float: db]
Range: -80.0 - 0.0 dB
Rate: ~60 Hz
```

---

### 2. Control Messages (iOS → Desktop)

#### Scene Selection
```
Address: /echoel/scene/select
Arguments: [int: scene_id]
Range: 0 - 4
```

**Scene IDs**:
- 0: Ambient Drone
- 1: Rhythmic Pulse
- 2: Granular Texture
- 3: Spatial Movement
- 4: Harmonic Layers

**Beispiel**:
```
/echoel/scene/select 2
```

#### Parameter Control
```
Address: /echoel/param/<parameter_name>
Arguments: [float: value]
Range: 0.0 - 1.0 (normalized)
```

**Common Parameters**:
- `/echoel/param/reverb` - Reverb amount
- `/echoel/param/delay` - Delay amount
- `/echoel/param/filter_cutoff` - Filter cutoff (normalized)
- `/echoel/param/spatial_spread` - Spatial audio spread

**Beispiel**:
```
/echoel/param/reverb 0.65
```

#### System Control
```
Address: /echoel/system/start
Arguments: none
```

```
Address: /echoel/system/stop
Arguments: none
```

```
Address: /echoel/system/reset
Arguments: none
```

---

### 3. Analysis Messages (Desktop → iOS)

#### Audio Level (RMS)
```
Address: /echoel/analysis/rms
Arguments: [float: db]
Range: -80.0 - 0.0 dB
Rate: ~30 Hz
```

**Beispiel**:
```
/echoel/analysis/rms -12.5
```

#### Peak Level
```
Address: /echoel/analysis/peak
Arguments: [float: db]
Range: -80.0 - 0.0 dB
Rate: ~30 Hz
```

#### Spektrum (Multi-Band)
```
Address: /echoel/analysis/spectrum
Arguments: [float: band0, float: band1, ..., float: bandN]
Bands: 8 frequency bands (logarithmic spacing)
Range per band: -80.0 - 0.0 dB
Rate: ~30 Hz
```

**Beispiel**:
```
/echoel/analysis/spectrum -20.0 -15.0 -18.0 -25.0 -30.0 -35.0 -40.0 -45.0
```

**Frequency Bands**:
- Band 0: 20-80 Hz (Sub Bass)
- Band 1: 80-200 Hz (Bass)
- Band 2: 200-500 Hz (Low Mids)
- Band 3: 500-1k Hz (Mids)
- Band 4: 1k-2k Hz (High Mids)
- Band 5: 2k-5k Hz (Presence)
- Band 6: 5k-10k Hz (Brilliance)
- Band 7: 10k-20k Hz (Air)

#### CPU Load
```
Address: /echoel/status/cpu
Arguments: [float: percentage]
Range: 0.0 - 100.0
Rate: ~1 Hz
```

---

### 4. Sync Protocol

#### Ping (iOS → Desktop)
```
Address: /echoel/sync/ping
Arguments: [int: timestamp_ms]
```

**Beispiel**:
```
/echoel/sync/ping 1699876543210
```

#### Pong (Desktop → iOS)
```
Address: /echoel/sync/pong
Arguments: [int: original_timestamp_ms]
```

iOS kann damit Round-Trip-Time berechnen:
```swift
let rtt = currentTime - originalTimestamp
let latency = rtt / 2
```

---

## Connection Setup

### Desktop (Server)

1. **Bind OSC Server zu Port 8000**:
```cpp
oscReceiver.connect(8000);
```

2. **Bonjour Service registrieren** (optional):
```cpp
// Service Name: "Echoel Desktop"
// Type: _echoel._udp
// Port: 8000
```

3. **Callbacks registrieren**:
```cpp
oscReceiver.addListener(this);
```

### iOS (Client)

1. **Desktop IP ermitteln**:
   - Manuell eingeben (UI)
   - Auto-Discovery via Bonjour

2. **UDP Connection erstellen**:
```swift
let connection = NWConnection(
    host: NWEndpoint.Host(desktopIP),
    port: 8000,
    using: .udp
)
```

3. **OSC Messages senden**:
```swift
let oscMessage = OSCMessage(
    address: "/echoel/bio/heartrate",
    arguments: [72.5]
)
connection.send(oscMessage.data)
```

---

## Implementation Examples

### iOS (Swift)

```swift
import Foundation
import Network

class OSCManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var latencyMs: Double = 0

    private var connection: NWConnection?
    private let serverPort: UInt16 = 8000

    func connect(to host: String) {
        let endpoint = NWEndpoint.Host(host)
        connection = NWConnection(
            host: endpoint,
            port: NWEndpoint.Port(rawValue: serverPort)!,
            using: .udp
        )

        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.isConnected = true
            case .failed(_), .cancelled:
                self.isConnected = false
            default:
                break
            }
        }

        connection?.start(queue: .global())
    }

    func sendHeartRate(_ bpm: Float) {
        send(address: "/echoel/bio/heartrate", [.float(bpm)])
    }

    func sendHRV(_ ms: Float) {
        send(address: "/echoel/bio/hrv", [.float(ms)])
    }

    func sendPitch(frequency: Float, confidence: Float) {
        send(address: "/echoel/audio/pitch",
             [.float(frequency), .float(confidence)])
    }

    private func send(address: String, _ args: [OSCArgument]) {
        let message = OSCMessage(address: address, arguments: args)
        connection?.send(
            content: message.encode(),
            completion: .contentProcessed { error in
                if let error = error {
                    print("OSC send error: \(error)")
                }
            }
        )
    }
}

// OSC Encoding
struct OSCMessage {
    let address: String
    let arguments: [OSCArgument]

    func encode() -> Data {
        var data = Data()

        // Address (null-terminated, 4-byte aligned)
        data.append(address.data(using: .utf8)!)
        data.append(0)
        while data.count % 4 != 0 { data.append(0) }

        // Type tag string
        var typeTag = ","
        for arg in arguments {
            typeTag += arg.typeTag
        }
        data.append(typeTag.data(using: .utf8)!)
        data.append(0)
        while data.count % 4 != 0 { data.append(0) }

        // Arguments
        for arg in arguments {
            data.append(arg.encode())
        }

        return data
    }
}

enum OSCArgument {
    case float(Float)
    case int(Int32)

    var typeTag: String {
        switch self {
        case .float: return "f"
        case .int: return "i"
        }
    }

    func encode() -> Data {
        var data = Data()
        switch self {
        case .float(let value):
            var bigEndian = value.bitPattern.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &bigEndian) { Data($0) })
        case .int(let value):
            var bigEndian = value.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &bigEndian) { Data($0) })
        }
        return data
    }
}
```

### Desktop (JUCE C++)

**OSCManager.h**:
```cpp
#pragma once
#include <JuceHeader.h>
#include <functional>

class OSCManager : public juce::OSCReceiver,
                   private juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback>
{
public:
    OSCManager();
    ~OSCManager() override;

    bool initialize(int port = 8000);
    void shutdown();

    // Callbacks für empfangene Daten
    std::function<void(float bpm)> onHeartRateReceived;
    std::function<void(float ms)> onHRVReceived;
    std::function<void(float rate)> onBreathRateReceived;
    std::function<void(float freq, float conf)> onPitchReceived;
    std::function<void(int sceneId)> onSceneSelected;

    // Analyse-Daten zurück an iOS senden
    void sendAudioAnalysis(float rmsDb, float peakDb);
    void sendSpectrum(const std::vector<float>& bands);
    void sendCPULoad(float percentage);

private:
    void oscMessageReceived(const juce::OSCMessage& message) override;

    juce::OSCSender oscSender;
    juce::String clientAddress;
    int clientPort = 8001; // iOS lauscht auf 8001

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OSCManager)
};
```

**OSCManager.cpp**:
```cpp
#include "OSCManager.h"

OSCManager::OSCManager() {}

OSCManager::~OSCManager() {
    shutdown();
}

bool OSCManager::initialize(int port) {
    if (!connect(port)) {
        DBG("Failed to connect OSC receiver on port " + juce::String(port));
        return false;
    }

    addListener(this);
    DBG("OSC Server listening on port " + juce::String(port));
    return true;
}

void OSCManager::shutdown() {
    disconnect();
}

void OSCManager::oscMessageReceived(const juce::OSCMessage& message) {
    auto address = message.getAddressPattern().toString();

    // Biofeedback
    if (address == "/echoel/bio/heartrate" && message.size() == 1) {
        if (auto* arg = message[0].getFloat32()) {
            if (onHeartRateReceived) onHeartRateReceived(*arg);
        }
    }
    else if (address == "/echoel/bio/hrv" && message.size() == 1) {
        if (auto* arg = message[0].getFloat32()) {
            if (onHRVReceived) onHRVReceived(*arg);
        }
    }
    else if (address == "/echoel/bio/breathrate" && message.size() == 1) {
        if (auto* arg = message[0].getFloat32()) {
            if (onBreathRateReceived) onBreathRateReceived(*arg);
        }
    }
    else if (address == "/echoel/audio/pitch" && message.size() == 2) {
        if (auto* freq = message[0].getFloat32()) {
            if (auto* conf = message[1].getFloat32()) {
                if (onPitchReceived) onPitchReceived(*freq, *conf);
            }
        }
    }
    // Scene control
    else if (address == "/echoel/scene/select" && message.size() == 1) {
        if (auto* arg = message[0].getInt32()) {
            if (onSceneSelected) onSceneSelected(*arg);
        }
    }
    // Parameter control
    else if (address.startsWith("/echoel/param/")) {
        // Extract parameter name and value
        // Forward to parameter manager
    }
    // System control
    else if (address == "/echoel/system/start") {
        // Start audio processing
    }
    else if (address == "/echoel/system/stop") {
        // Stop audio processing
    }
}

void OSCManager::sendAudioAnalysis(float rmsDb, float peakDb) {
    if (!oscSender.isConnected()) return;

    oscSender.send("/echoel/analysis/rms", rmsDb);
    oscSender.send("/echoel/analysis/peak", peakDb);
}

void OSCManager::sendSpectrum(const std::vector<float>& bands) {
    if (!oscSender.isConnected() || bands.size() != 8) return;

    juce::OSCMessage msg("/echoel/analysis/spectrum");
    for (float band : bands) {
        msg.addFloat32(band);
    }
    oscSender.send(msg);
}

void OSCManager::sendCPULoad(float percentage) {
    if (!oscSender.isConnected()) return;
    oscSender.send("/echoel/status/cpu", percentage);
}
```

---

## Error Handling

### Connection Loss
- iOS sollte regelmäßig `/echoel/sync/ping` senden (z.B. alle 2 Sekunden)
- Wenn kein `/echoel/sync/pong` innerhalb von 5 Sekunden: Connection als lost markieren
- Auto-Reconnect-Strategie implementieren

### Invalid Messages
- Desktop sollte ungültige Messages loggen aber nicht crashen
- Werte außerhalb des Ranges sollten geclampt werden

### Packet Loss
- UDP garantiert keine Zustellung
- Kritische Messages (z.B. Scene-Changes) können mit Bestätigung implementiert werden
- Nicht-kritische Messages (z.B. Biofeedback) können Packet Loss tolerieren

---

## Performance Guidelines

### iOS
- Bundle mehrere Parameter-Changes in einem Frame
- Limitiere Biofeedback-Rate auf sinnvolle Werte (1 Hz für Herzrate ist ausreichend)
- Pitch-Daten können mit höherer Rate gesendet werden (60 Hz)

### Desktop
- Process OSC auf dediziertem Thread (nicht Audio-Thread!)
- Use lock-free queues für Parameter-Updates zum Audio-Thread
- Spectrum-Analyse mit FFT auf nicht-Echtzeit-Thread

---

## Testing

### OSC Message Viewer
Für Debugging kann man Tools wie **OSCulator** (macOS) verwenden:
1. OSCulator als Server starten (Port 8000)
2. iOS App verbinden
3. Alle gesendeten Messages werden angezeigt

### Manual Testing
Mit Command-Line-Tools wie `oscsend`:
```bash
oscsend localhost 8000 /echoel/bio/heartrate f 75.0
```

---

## Future Extensions

Geplante Erweiterungen:
- **MIDI over OSC**: `/echoel/midi/note`, `/echoel/midi/cc`
- **Visual Sync**: `/echoel/visual/scene`, `/echoel/visual/param/*`
- **LED Control**: `/echoel/led/color`, `/echoel/led/pattern`
- **Session Recording**: `/echoel/session/record`, `/echoel/session/stop`

---

**Version History**:
- 1.0.0 (Nov 2025): Initial specification
