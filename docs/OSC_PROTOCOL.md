# EOEL OSC Protocol Specification

**Version:** 1.0.0
**Date:** 2025-11-25
**Status:** Draft - To be implemented

---

## Overview

This document specifies the OSC (Open Sound Control) protocol for bidirectional communication between EOEL iOS/mobile clients and the desktop audio processing engine.

**Protocol Namespace:** `/eoel/*`

**Transport:** UDP (default) or TCP
**Default Port:** 8000
**Update Rate:** 60 Hz for real-time parameters
**Message Format:** OSC 1.0 compliant

---

## Architecture

```
┌─────────────────┐                         ┌──────────────────────┐
│   iOS Client    │      OSC over UDP       │  Desktop Engine      │
│   (Swift)       │◄────────────────────────┤  (C++ / JUCE)        │
│                 │         Port 8000        │                      │
│  • Biofeedback  ├─────────────────────────►│  • Audio Processing  │
│  • Voice Input  │  /eoel/bio/*            │  • DSP Effects       │
│  • Control UI   │  /eoel/audio/*          │  • Synthesis         │
│                 │  /eoel/control/*        │  • Spatial Audio     │
│                 │◄─────────────────────────│                      │
│                 │  /eoel/analysis/*       │                      │
└─────────────────┘  /eoel/sync/*           └──────────────────────┘
```

---

## Message Categories

### 1. Biofeedback Data (iOS → Desktop)

Physiological data from HealthKit and sensors.

**Namespace:** `/eoel/bio/*`

#### `/eoel/bio/heartrate`
**Direction:** iOS → Desktop
**Type:** `float`
**Range:** 40-200 BPM
**Update Rate:** 1-5 Hz (HealthKit dependent)
**Description:** Real-time heart rate from HealthKit or PPG sensor

**Example:**
```
/eoel/bio/heartrate 72.5
```

#### `/eoel/bio/hrv`
**Direction:** iOS → Desktop
**Type:** `float`
**Range:** 0-200 ms (RMSSD)
**Update Rate:** 1-5 Hz
**Description:** Heart Rate Variability (RMSSD algorithm)

**Example:**
```
/eoel/bio/hrv 45.2
```

#### `/eoel/bio/coherence`
**Direction:** iOS → Desktop
**Type:** `float`
**Range:** 0.0-1.0 (normalized)
**Update Rate:** 1 Hz
**Description:** HeartMath coherence score (0 = low, 1 = high coherence)

**Example:**
```
/eoel/bio/coherence 0.68
```

#### `/eoel/bio/arousal`
**Direction:** iOS → Desktop
**Type:** `float`
**Range:** 0.0-1.0 (normalized)
**Update Rate:** 5-10 Hz
**Description:** Arousal level derived from HRV, HR, and respiration (0 = calm, 1 = excited)

**Example:**
```
/eoel/bio/arousal 0.42
```

#### `/eoel/bio/valence`
**Direction:** iOS → Desktop
**Type:** `float`
**Range:** -1.0 to +1.0 (normalized)
**Update Rate:** 5-10 Hz
**Description:** Emotional valence (-1 = negative, 0 = neutral, +1 = positive)

**Example:**
```
/eoel/bio/valence 0.35
```

#### `/eoel/bio/flow`
**Direction:** iOS → Desktop
**Type:** `float`
**Range:** 0.0-1.0 (normalized)
**Update Rate:** 1 Hz
**Description:** Flow state estimation (0 = no flow, 1 = deep flow)

**Example:**
```
/eoel/bio/flow 0.78
```

#### `/eoel/bio/respiration`
**Direction:** iOS → Desktop
**Type:** `float`
**Range:** 4-30 breaths/min
**Update Rate:** 0.1-1 Hz
**Description:** Respiration rate (breaths per minute)

**Example:**
```
/eoel/bio/respiration 12.5
```

---

### 2. Audio Input (iOS → Desktop)

Real-time audio analysis from microphone input.

**Namespace:** `/eoel/audio/*`

#### `/eoel/audio/pitch`
**Direction:** iOS → Desktop
**Type:** `float float` (frequency Hz, confidence 0-1)
**Update Rate:** 60 Hz
**Description:** Pitch detection (YIN algorithm)

**Example:**
```
/eoel/audio/pitch 440.0 0.92
```

#### `/eoel/audio/level`
**Direction:** iOS → Desktop
**Type:** `float`
**Range:** -96.0 to 0.0 dB
**Update Rate:** 60 Hz
**Description:** Audio input level (dBFS)

**Example:**
```
/eoel/audio/level -18.5
```

#### `/eoel/audio/spectrum`
**Direction:** iOS → Desktop
**Type:** `float[16]` (16 frequency bands)
**Update Rate:** 30-60 Hz
**Description:** FFT spectrum analysis (16 bands, log-spaced)

**Example:**
```
/eoel/audio/spectrum 0.12 0.24 0.45 0.67 0.89 0.76 0.54 0.32 ...
```

---

### 3. Control Messages (iOS → Desktop)

UI control and scene management.

**Namespace:** `/eoel/control/*`

#### `/eoel/control/scene`
**Direction:** iOS → Desktop
**Type:** `int`
**Range:** 0-99
**Description:** Load a preset scene/patch

**Example:**
```
/eoel/control/scene 5
```

#### `/eoel/control/param`
**Direction:** iOS → Desktop
**Type:** `string float` (parameter name, value 0-1)
**Description:** Set a specific parameter by name

**Example:**
```
/eoel/control/param "filter_cutoff" 0.75
/eoel/control/param "reverb_mix" 0.4
```

#### `/eoel/control/start`
**Direction:** iOS → Desktop
**Type:** (no arguments)
**Description:** Start audio processing

**Example:**
```
/eoel/control/start
```

#### `/eoel/control/stop`
**Direction:** iOS → Desktop
**Type:** (no arguments)
**Description:** Stop audio processing

**Example:**
```
/eoel/control/stop
```

#### `/eoel/control/bypass`
**Direction:** iOS → Desktop
**Type:** `string bool` (effect name, bypass state)
**Description:** Bypass a specific effect

**Example:**
```
/eoel/control/bypass "reverb" true
```

---

### 4. Analysis Feedback (Desktop → iOS)

Real-time analysis data sent back to iOS for visualization.

**Namespace:** `/eoel/analysis/*`

#### `/eoel/analysis/rms`
**Direction:** Desktop → iOS
**Type:** `float`
**Range:** -96.0 to 0.0 dB
**Update Rate:** 60 Hz
**Description:** Output RMS level (dBFS)

**Example:**
```
/eoel/analysis/rms -12.3
```

#### `/eoel/analysis/peak`
**Direction:** Desktop → iOS
**Type:** `float`
**Range:** -96.0 to 0.0 dB
**Update Rate:** 60 Hz
**Description:** Output peak level (dBFS)

**Example:**
```
/eoel/analysis/peak -6.8
```

#### `/eoel/analysis/spectrum`
**Direction:** Desktop → iOS
**Type:** `float[16]` (16 frequency bands)
**Update Rate:** 30-60 Hz
**Description:** Output spectrum for visualization

**Example:**
```
/eoel/analysis/spectrum 0.15 0.28 0.52 0.71 0.88 ...
```

#### `/eoel/analysis/cpu`
**Direction:** Desktop → iOS
**Type:** `float`
**Range:** 0.0-1.0 (percentage)
**Update Rate:** 1 Hz
**Description:** CPU usage (0 = 0%, 1 = 100%)

**Example:**
```
/eoel/analysis/cpu 0.23
```

---

### 5. Synchronization (Bidirectional)

Clock sync and connection status.

**Namespace:** `/eoel/sync/*`

#### `/eoel/sync/ping`
**Direction:** iOS → Desktop or Desktop → iOS
**Type:** `int64` (timestamp in milliseconds)
**Description:** Ping for latency measurement

**Example:**
```
/eoel/sync/ping 1732531200000
```

#### `/eoel/sync/pong`
**Direction:** Response to ping
**Type:** `int64` (original timestamp)
**Description:** Pong response with original timestamp

**Example:**
```
/eoel/sync/pong 1732531200000
```

#### `/eoel/status/connected`
**Direction:** Bidirectional
**Type:** `bool`
**Description:** Connection status notification

**Example:**
```
/eoel/status/connected true
```

#### `/eoel/status/latency`
**Direction:** Bidirectional
**Type:** `float` (milliseconds)
**Update Rate:** 1 Hz
**Description:** Round-trip latency

**Example:**
```
/eoel/status/latency 8.5
```

---

## Implementation Guidelines

### iOS Client (Swift)

**Recommended Library:** CocoaOSC or OSCKit

**Example Send:**
```swift
import OSCKit

let client = OSCClient()
client.host = "192.168.1.100"  // Desktop IP
client.port = 8000

// Send heart rate
let message = OSCMessage(
    OSCAddressPattern("/eoel/bio/heartrate"),
    arguments: [72.5]
)
client.send(message)
```

**Example Receive:**
```swift
let server = OSCServer(port: 8001)  // iOS receive port
server.delegate = self

func didReceive(message: OSCMessage) {
    if message.addressPattern == "/eoel/analysis/rms" {
        let rms = message.arguments[0] as! Float
        // Update UI
    }
}
```

### Desktop Engine (C++ / JUCE)

**Example using JUCE OSC:**
```cpp
#include "OSCManager.h"

// Initialization
OSCManager oscManager;
oscManager.startReceiver(8000);  // Listen on 8000
oscManager.addSender("iOS", "192.168.1.50", 8001);  // Send to iOS

// Receive biofeedback
oscManager.addMapping("/eoel/bio/heartrate", "heartrate", 40.0f, 200.0f,
    [this](float value) {
        // Map to audio parameter
        audioEngine.setBioParameter("heartrate", value);
    }
);

// Send analysis data
oscManager.sendFloat("/eoel/analysis/rms", currentRMS, "iOS");
```

---

## Auto-Discovery (Recommended)

Use Bonjour/Zeroconf for automatic discovery:

**Service Name:** `_eoel._udp.local.`
**Port:** 8000

**iOS (NetService):**
```swift
let browser = NetServiceBrowser()
browser.searchForServices(ofType: "_eoel._udp.", inDomain: "local.")
```

**Desktop (JUCE):**
```cpp
// Use JUCE Network Service Discovery
juce::IPAddress::findAllAddresses(addresses, true);
```

---

## Performance Requirements

| Metric | Target | Critical |
|--------|--------|----------|
| Latency (round-trip) | < 10ms | < 20ms |
| Message Rate | 60 Hz | 30 Hz minimum |
| Packet Loss | < 0.1% | < 1% |
| CPU Overhead | < 5% | < 10% |

---

## Error Handling

### Connection Loss
- iOS should detect connection loss after 3 seconds of no messages
- Automatically attempt reconnection every 5 seconds
- Display connection status to user

### Invalid Messages
- Validate all message formats before processing
- Log invalid messages for debugging
- Ignore (don't crash) on malformed data

### Value Ranges
- Clamp all values to specified ranges
- Log out-of-range values as warnings
- Apply smoothing to prevent glitches

---

## Testing

### OSC Monitor Tools
- **macOS:** OSCulator
- **Windows:** OSCData Monitor
- **Linux:** oscdump
- **Cross-platform:** TouchOSC Bridge

### Test Messages
```bash
# Using oscsend (from liblo)
oscsend localhost 8000 /eoel/bio/heartrate f 72.5
oscsend localhost 8000 /eoel/control/scene i 5
oscsend localhost 8000 /eoel/control/start
```

---

## Security Considerations

1. **Network Security:**
   - Recommend local network only (192.168.x.x)
   - No authentication by default (trusted local network)
   - For public networks: Use VPN or SSH tunnel

2. **Input Validation:**
   - Validate all message formats
   - Clamp all numerical values
   - Sanitize string parameters

3. **DoS Prevention:**
   - Rate limiting: Max 120 messages/second per client
   - Reject messages > 1KB
   - Timeout idle connections after 30 seconds

---

## Future Extensions

### Planned for v1.1:
- `/eoel/midi/*` - MIDI data forwarding
- `/eoel/video/*` - Video sync messages
- `/eoel/session/*` - Multi-client session management
- OSC Bundle support for atomic updates

### Planned for v2.0:
- TCP transport option
- TLS encryption
- Authentication/authorization
- Compression for high-bandwidth data

---

## References

- [OSC 1.0 Specification](http://opensoundcontrol.org/spec-1_0)
- [JUCE OSC Module](https://docs.juce.com/master/group__juce__osc.html)
- [CocoaOSC (Swift)](https://github.com/danieldickison/CocoaOSC)

---

## Changelog

### v1.0.0 (2025-11-25)
- Initial specification
- Core message types defined
- iOS ↔ Desktop bidirectional protocol
- 60 Hz update rate target

---

## Contact

For protocol questions or implementation support:
- Create issue on GitHub: vibrationalforce/Echoelmusic
- See: EOEL_AUDIT_REPORT.md for implementation priorities

---

**Status:** 🚧 **Specification Complete - Implementation Pending**

**Next Steps:**
1. Implement iOS OSC Client (Swift)
2. Implement Desktop OSC Protocol Handler (C++)
3. Test with OSC monitoring tools
4. Performance optimization
5. Add auto-discovery (Bonjour)

---

**EOEL — Where Biology Becomes Art** 🎵🧬✨
