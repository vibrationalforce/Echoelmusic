# Echoelmusic OSC API Reference

**Version:** 1.0.0
**Date:** 2025-12-18
**Protocol:** Open Sound Control (OSC) over UDP/TCP

## Overview

Echoelmusic provides comprehensive OSC control for all major subsystems:
- **Biofeedback** - Heart rate, HRV, coherence, stress metrics
- **Session Management** - Save/load projects, tempo, project info
- **Visual Engine** - Layers, generators, effects, rendering
- **System Monitoring** - Health checks, metrics, platform info
- **Audio Modulation** - Filter, reverb, compression, delay, distortion
- **Triggers** - Heartbeat, breath, beat detection

## Default Configuration

- **Default Port (Receive):** 8000
- **Default Port (Send):** 9000
- **Address Prefix:** `/echoelmusic`
- **Update Rate:** 30-60 Hz (configurable)

## Compatible Software

- **Visual:** TouchDesigner, Resolume Arena, VDMX, MadMapper, Processing
- **Audio:** Ableton Live (Max for Live), Reaper, Bitwig Studio
- **Controllers:** TouchOSC, Lemur, Monome Grid
- **3D Engines:** Unity, Unreal Engine
- **Lighting:** QLab, ETC consoles, GrandMA

---

## 1. Biofeedback (/bio)

### 1.1 Basic Metrics

#### /echoelmusic/bio/hrv
**Type:** `float 0-1`
**Description:** Heart Rate Variability (normalized)
**Direction:** Output
**Update Rate:** 1 Hz

#### /echoelmusic/bio/coherence
**Type:** `float 0-1`
**Description:** HeartMath Coherence score
**Direction:** Output
**Update Rate:** 1 Hz

#### /echoelmusic/bio/heartrate
**Type:** `float 40-200`
**Description:** Heart rate in BPM
**Direction:** Output
**Update Rate:** 1 Hz

#### /echoelmusic/bio/stress
**Type:** `float 0-1`
**Description:** Stress index (0=calm, 1=stressed)
**Direction:** Output
**Update Rate:** 1 Hz

#### /echoelmusic/bio/breathing
**Type:** `float 0-1`
**Description:** Breathing rate (normalized)
**Direction:** Output
**Update Rate:** 1 Hz

### 1.2 Time-Domain HRV Metrics

#### /echoelmusic/bio/sdnn
**Type:** `float` (milliseconds)
**Description:** Standard Deviation of NN intervals
**Direction:** Output
**Update Rate:** 1 Hz
**Scientific Basis:** ESC/NASPE Task Force (1996) HRV Standards
**Typical Range:** 20-100 ms for adults

#### /echoelmusic/bio/rmssd
**Type:** `float` (milliseconds)
**Description:** Root Mean Square of Successive Differences
**Direction:** Output
**Update Rate:** 1 Hz
**Typical Range:** 20-80 ms for adults

### 1.3 Frequency-Domain HRV Metrics

#### /echoelmusic/bio/lfpower
**Type:** `float`
**Description:** Low Frequency Power (0.04-0.15 Hz)
**Direction:** Output
**Update Rate:** 1 Hz
**Represents:** Sympathetic + Parasympathetic activity

#### /echoelmusic/bio/hfpower
**Type:** `float`
**Description:** High Frequency Power (0.15-0.4 Hz)
**Direction:** Output
**Update Rate:** 1 Hz
**Represents:** Parasympathetic activity (respiratory sinus arrhythmia)

#### /echoelmusic/bio/lfhf
**Type:** `float`
**Description:** LF/HF Ratio (autonomic balance)
**Direction:** Output
**Update Rate:** 1 Hz
**Interpretation:**
- **< 1.0** - Parasympathetic dominance (relaxed)
- **1.0-2.0** - Balanced
- **> 2.0** - Sympathetic dominance (stressed)

---

## 2. Audio Modulation (/mod)

### 2.1 Filter

#### /echoelmusic/mod/filter
**Type:** `float 20-20000`
**Description:** Filter cutoff frequency (Hz)
**Direction:** Output
**Modulated By:** HRV, coherence

### 2.2 Effects

#### /echoelmusic/mod/reverb
**Type:** `float 0-1`
**Description:** Reverb mix amount
**Direction:** Output

#### /echoelmusic/mod/compression
**Type:** `float 1-20`
**Description:** Compression ratio
**Direction:** Output

#### /echoelmusic/mod/delay
**Type:** `float 0-2000`
**Description:** Delay time (milliseconds)
**Direction:** Output

#### /echoelmusic/mod/distortion
**Type:** `float 0-1`
**Description:** Distortion amount
**Direction:** Output

#### /echoelmusic/mod/lfo
**Type:** `float 0.1-20`
**Description:** LFO rate (Hz)
**Direction:** Output

---

## 3. Triggers (/trigger)

### 3.1 Bio Triggers

#### /echoelmusic/trigger/beat
**Type:** `bang` (no arguments)
**Description:** Triggered on each heartbeat
**Direction:** Output
**Use Case:** Sync visuals/audio to heartbeat

#### /echoelmusic/trigger/breath
**Type:** `bang` (no arguments)
**Description:** Triggered on breath detection
**Direction:** Output

---

## 4. Session Management (/session)

### 4.1 File Operations

#### /echoelmusic/session/save [path]
**Type:** `string`
**Description:** Save current session to file path
**Direction:** Input
**Response:** `/echoelmusic/session/save/result` [int 0/1]
**Example:**
```
/echoelmusic/session/save "/home/user/mysession.echoelmusic"
```

#### /echoelmusic/session/load [path]
**Type:** `string`
**Description:** Load session from file path
**Direction:** Input
**Response:** `/echoelmusic/session/load/result` [int 0/1]

#### /echoelmusic/session/new
**Type:** `bang`
**Description:** Create new empty session
**Direction:** Input

### 4.2 Project Properties

#### /echoelmusic/session/title [title]
**Type:** `string`
**Description:** Set project title (with argument) or query (without argument)
**Direction:** Bidirectional
**Response:** `/echoelmusic/session/status/title` [string]

#### /echoelmusic/session/artist [name]
**Type:** `string`
**Description:** Set artist name
**Direction:** Bidirectional

#### /echoelmusic/session/tempo [bpm]
**Type:** `float 20-999`
**Description:** Set project tempo
**Direction:** Bidirectional
**Example:**
```
/echoelmusic/session/tempo 120.0
```

#### /echoelmusic/session/timesig [numerator] [denominator]
**Type:** `int int`
**Description:** Set time signature
**Direction:** Bidirectional
**Example:**
```
/echoelmusic/session/timesig 7 8
```

### 4.3 Session Status

#### /echoelmusic/session/dirty
**Type:** `bang`
**Description:** Query if session has unsaved changes
**Direction:** Input
**Response:** `/echoelmusic/session/status/dirty` [int 0/1]

#### /echoelmusic/session/autosave [minutes]
**Type:** `int`
**Description:** Set autosave interval (0 to disable)
**Direction:** Input
**Example:**
```
/echoelmusic/session/autosave 5
```

#### /echoelmusic/session/status
**Type:** `bang`
**Description:** Get full session status as JSON
**Direction:** Input
**Response:** `/echoelmusic/session/status` [string JSON]
**JSON Format:**
```json
{
  "title": "My Project",
  "artist": "Artist Name",
  "tempo": 120.0,
  "timeSignature": {"numerator": 4, "denominator": 4},
  "sampleRate": 48000.0,
  "dirty": false,
  "file": "/path/to/session.echoelmusic"
}
```

---

## 5. Visual Engine (/visual)

### 5.1 Layer Control

#### /echoelmusic/visual/layer/[n]/enabled [0/1]
**Type:** `int`
**Description:** Enable/disable layer
**Direction:** Input
**Example:**
```
/echoelmusic/visual/layer/0/enabled 1
```

#### /echoelmusic/visual/layer/[n]/opacity [value]
**Type:** `float 0-1`
**Description:** Set layer opacity
**Direction:** Input

#### /echoelmusic/visual/layer/[n]/blend [mode]
**Type:** `int 0-8`
**Description:** Set blend mode
**Direction:** Input
**Blend Modes:**
- 0 = Normal
- 1 = Add
- 2 = Multiply
- 3 = Screen
- 4 = Overlay
- 5 = Difference
- 6 = Exclusion
- 7 = ColorDodge
- 8 = ColorBurn

#### /echoelmusic/visual/layer/[n]/x [value]
**Type:** `float -2 to 2`
**Description:** Layer position X
**Direction:** Input

#### /echoelmusic/visual/layer/[n]/y [value]
**Type:** `float -2 to 2`
**Description:** Layer position Y
**Direction:** Input

#### /echoelmusic/visual/layer/[n]/scale [value]
**Type:** `float 0.01-10`
**Description:** Uniform scale
**Direction:** Input

#### /echoelmusic/visual/layer/[n]/rotation [radians]
**Type:** `float`
**Description:** Rotation in radians
**Direction:** Input
**Note:** 2π radians = 360°

### 5.2 Master Controls

#### /echoelmusic/visual/master/brightness [value]
**Type:** `float 0-2`
**Description:** Global brightness (1.0 = normal)
**Direction:** Input

#### /echoelmusic/visual/master/contrast [value]
**Type:** `float 0-2`
**Description:** Global contrast (1.0 = normal)
**Direction:** Input

#### /echoelmusic/visual/master/saturation [value]
**Type:** `float 0-2`
**Description:** Global saturation (1.0 = normal)
**Direction:** Input

#### /echoelmusic/visual/master/hue [value]
**Type:** `float 0-1`
**Description:** Global hue shift (0-1 = 0-360°)
**Direction:** Input

### 5.3 Rendering

#### /echoelmusic/visual/resolution [width] [height]
**Type:** `int int`
**Description:** Set output resolution
**Direction:** Input
**Example:**
```
/echoelmusic/visual/resolution 1920 1080
```

#### /echoelmusic/visual/fps/target [fps]
**Type:** `int 15-240`
**Description:** Set target frame rate
**Direction:** Input

#### /echoelmusic/visual/fps/current
**Type:** `bang`
**Description:** Query current FPS
**Direction:** Input
**Response:** `/echoelmusic/visual/status/fps` [float]

### 5.4 Reactive Modes

#### /echoelmusic/visual/audio/reactive [0/1]
**Type:** `int`
**Description:** Enable audio-reactive mode
**Direction:** Input

#### /echoelmusic/visual/bio/reactive [0/1]
**Type:** `int`
**Description:** Enable bio-reactive mode
**Direction:** Input

### 5.5 Recording

#### /echoelmusic/visual/recording/start [path]
**Type:** `string`
**Description:** Start recording frames to file
**Direction:** Input
**Example:**
```
/echoelmusic/visual/recording/start "/home/user/recording.mov"
```

#### /echoelmusic/visual/recording/stop
**Type:** `bang`
**Description:** Stop recording
**Direction:** Input

#### /echoelmusic/visual/recording/status
**Type:** `bang`
**Description:** Query recording status
**Direction:** Input
**Response:** `/echoelmusic/visual/status/recording` [int 0/1]

### 5.6 Presets

#### /echoelmusic/visual/preset/load [name]
**Type:** `string`
**Description:** Load preset by name or file path
**Direction:** Input
**Example:**
```
/echoelmusic/visual/preset/load "Psychedelic Spiral"
/echoelmusic/visual/preset/load "/home/user/mypreset.json"
```

#### /echoelmusic/visual/preset/save [path]
**Type:** `string`
**Description:** Save current state as preset
**Direction:** Input

#### /echoelmusic/visual/preset/list
**Type:** `bang`
**Description:** Get list of built-in presets
**Direction:** Input
**Response:** `/echoelmusic/visual/preset/item` [string] (multiple messages)

---

## 6. System Monitoring (/system)

### 6.1 Health Checks

#### /echoelmusic/system/health
**Type:** `bang`
**Description:** Get complete health status as JSON
**Direction:** Input
**Response:** `/echoelmusic/system/status/health` [string JSON]
**JSON Format:**
```json
{
  "status": "healthy",
  "timestamp": 1702900000,
  "uptime": 3600,
  "components": {
    "application": {
      "status": "healthy",
      "message": "Application is running",
      "lastChecked": 1702900000,
      "responseTimeMs": 0
    },
    "memory": {
      "status": "healthy",
      "message": "Memory usage within limits",
      "lastChecked": 1702900000,
      "responseTimeMs": 0
    }
  }
}
```

#### /echoelmusic/system/health/live
**Type:** `bang`
**Description:** Liveness probe (Kubernetes-compatible)
**Direction:** Input
**Response:** `/echoelmusic/system/status/live` [int 0/1]
**Use Case:** Kubernetes liveness probe

#### /echoelmusic/system/health/ready
**Type:** `bang`
**Description:** Readiness probe (Kubernetes-compatible)
**Direction:** Input
**Response:** `/echoelmusic/system/status/ready` [int 0/1]
**Use Case:** Kubernetes readiness probe

### 6.2 System Info

#### /echoelmusic/system/uptime
**Type:** `bang`
**Description:** Get application uptime in seconds
**Direction:** Input
**Response:** `/echoelmusic/system/status/uptime` [int]

#### /echoelmusic/system/version
**Type:** `bang`
**Description:** Get application version
**Direction:** Input
**Response:** `/echoelmusic/system/status/version` [string]

#### /echoelmusic/system/platform
**Type:** `bang`
**Description:** Get platform info (OS, architecture)
**Direction:** Input
**Response:** `/echoelmusic/system/status/platform` [string]
**Example Response:** "Linux x64 (Release)"

### 6.3 Metrics (Prometheus)

#### /echoelmusic/system/metrics
**Type:** `bang`
**Description:** Export Prometheus metrics (text format)
**Direction:** Input
**Response:** `/echoelmusic/system/status/metrics` [string]
**Format:** Prometheus text format (compatible with Prometheus scraping)

#### /echoelmusic/system/metrics/reset
**Type:** `bang`
**Description:** Reset all metrics (for testing)
**Direction:** Input

### 6.4 Resource Monitoring

#### /echoelmusic/system/cpu
**Type:** `bang`
**Description:** Get CPU usage percentage
**Direction:** Input
**Response:** `/echoelmusic/system/status/cpu` [float 0-100]

#### /echoelmusic/system/memory
**Type:** `bang`
**Description:** Get memory usage (MB)
**Direction:** Input
**Response:** `/echoelmusic/system/status/memory` [float]

---

## 7. Integration Examples

### 7.1 TouchDesigner Setup

```python
# In TouchDesigner DAT (Python)

# Configure OSC In
op('oscin1').par.port = 9000

# Configure OSC Out
op('oscout1').par.address = '127.0.0.1'
op('oscout1').par.port = 8000

# Send message
op('oscout1').sendOSC('/echoelmusic/session/tempo', [120.0])

# Receive biofeedback
def onReceiveOSC(dat, rowIndex, message, bytes):
    if message == '/echoelmusic/bio/coherence':
        coherence = bytes[0]
        op('coherence_channel')[0] = coherence
```

### 7.2 Max/MSP Setup

```
# Max patch

[udpsend 127.0.0.1 8000]
|
[prepend /echoelmusic/visual/layer/0/opacity]
|
[pack f]

[udpreceive 9000]
|
[route /echoelmusic/bio/heartrate]
|
[scale 40. 200. 0. 127.]
|
[mtof]
```

### 7.3 Python (python-osc)

```python
from pythonosc import udp_client
from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import ThreadingOSCUDPServer

# Send OSC
client = udp_client.SimpleUDPClient("127.0.0.1", 8000)
client.send_message("/echoelmusic/session/tempo", 140.0)

# Receive OSC
def hrv_handler(address, *args):
    print(f"HRV: {args[0]}")

dispatcher = Dispatcher()
dispatcher.map("/echoelmusic/bio/hrv", hrv_handler)

server = ThreadingOSCUDPServer(("127.0.0.1", 9000), dispatcher)
server.serve_forever()
```

### 7.4 Processing Sketch

```java
import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress echoelmusic;

float coherence = 0.5;

void setup() {
  size(800, 600);

  oscP5 = new OscP5(this, 9000);  // Receive port
  echoelmusic = new NetAddress("127.0.0.1", 8000);  // Send port
}

void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/echoelmusic/bio/coherence")) {
    coherence = msg.get(0).floatValue();
  }
}

void draw() {
  background(0);

  // Visualize coherence
  fill(coherence * 255, 100, 200);
  ellipse(width/2, height/2, coherence * 400, coherence * 400);

  // Send visual layer opacity based on mouse
  OscMessage message = new OscMessage("/echoelmusic/visual/layer/0/opacity");
  message.add(mouseY / (float)height);
  oscP5.send(message, echoelmusic);
}
```

---

## 8. Best Practices

### 8.1 Message Rate Limiting

- **Biofeedback data:** 1-10 Hz is sufficient
- **Visual parameters:** 30-60 Hz for smooth animation
- **Session management:** On-demand only
- **Health checks:** 0.1-1 Hz (every 1-10 seconds)

### 8.2 Error Handling

Always check response messages:
- `/echoelmusic/session/save/result` → 0 (failed) or 1 (success)
- `/echoelmusic/session/load/result` → 0 (failed) or 1 (success)

### 8.3 Network Configuration

For remote control, ensure firewall allows UDP traffic on configured ports.

**Local (same machine):**
```
Host: 127.0.0.1 or localhost
```

**Remote (different machines):**
```
Host: [actual IP address]
Firewall: Allow UDP ports 8000, 9000
```

---

## 9. Troubleshooting

### 9.1 No OSC Messages Received

1. Check port configuration (default: receive 8000, send 9000)
2. Verify OSC receiver is running: `/echoelmusic/system/health/ready`
3. Check firewall settings
4. Use OSC monitoring tools (Protocol, OSCDataMonitor)

### 9.2 Visual Updates Not Working

1. Verify layer exists: `/echoelmusic/visual/status`
2. Check layer is enabled: `/echoelmusic/visual/layer/[n]/enabled 1`
3. Ensure target FPS is reasonable: `/echoelmusic/visual/fps/target 60`

### 9.3 Biofeedback Data Not Updating

1. Check biofeedback source is connected
2. Verify health status: `/echoelmusic/system/health`
3. Ensure update rate is enabled in configuration

---

## 10. Security Considerations

### 10.1 Network Exposure

OSC has no built-in authentication. When deploying:

- **Local development:** Use 127.0.0.1 (localhost)
- **Production:** Use firewall rules to restrict access
- **Public networks:** Consider VPN or SSH tunneling

### 10.2 Input Validation

All OSC inputs are validated:
- Numeric ranges are clamped
- File paths are sanitized (no directory traversal)
- Invalid messages are logged but don't crash the application

---

## Appendix A: Complete Address List

### Biofeedback
- `/echoelmusic/bio/hrv`
- `/echoelmusic/bio/coherence`
- `/echoelmusic/bio/heartrate`
- `/echoelmusic/bio/stress`
- `/echoelmusic/bio/breathing`
- `/echoelmusic/bio/sdnn`
- `/echoelmusic/bio/rmssd`
- `/echoelmusic/bio/lfpower`
- `/echoelmusic/bio/hfpower`
- `/echoelmusic/bio/lfhf`

### Audio Modulation
- `/echoelmusic/mod/filter`
- `/echoelmusic/mod/reverb`
- `/echoelmusic/mod/compression`
- `/echoelmusic/mod/delay`
- `/echoelmusic/mod/distortion`
- `/echoelmusic/mod/lfo`

### Triggers
- `/echoelmusic/trigger/beat`
- `/echoelmusic/trigger/breath`

### Session
- `/echoelmusic/session/save`
- `/echoelmusic/session/load`
- `/echoelmusic/session/new`
- `/echoelmusic/session/title`
- `/echoelmusic/session/artist`
- `/echoelmusic/session/tempo`
- `/echoelmusic/session/timesig`
- `/echoelmusic/session/dirty`
- `/echoelmusic/session/autosave`
- `/echoelmusic/session/status`

### Visual
- `/echoelmusic/visual/layer/[n]/enabled`
- `/echoelmusic/visual/layer/[n]/opacity`
- `/echoelmusic/visual/layer/[n]/blend`
- `/echoelmusic/visual/layer/[n]/x`
- `/echoelmusic/visual/layer/[n]/y`
- `/echoelmusic/visual/layer/[n]/scale`
- `/echoelmusic/visual/layer/[n]/rotation`
- `/echoelmusic/visual/master/brightness`
- `/echoelmusic/visual/master/contrast`
- `/echoelmusic/visual/master/saturation`
- `/echoelmusic/visual/master/hue`
- `/echoelmusic/visual/resolution`
- `/echoelmusic/visual/fps/target`
- `/echoelmusic/visual/fps/current`
- `/echoelmusic/visual/audio/reactive`
- `/echoelmusic/visual/bio/reactive`
- `/echoelmusic/visual/recording/start`
- `/echoelmusic/visual/recording/stop`
- `/echoelmusic/visual/recording/status`
- `/echoelmusic/visual/preset/load`
- `/echoelmusic/visual/preset/save`
- `/echoelmusic/visual/preset/list`

### System
- `/echoelmusic/system/health`
- `/echoelmusic/system/health/live`
- `/echoelmusic/system/health/ready`
- `/echoelmusic/system/uptime`
- `/echoelmusic/system/version`
- `/echoelmusic/system/platform`
- `/echoelmusic/system/metrics`
- `/echoelmusic/system/metrics/reset`
- `/echoelmusic/system/cpu`
- `/echoelmusic/system/memory`
- `/echoelmusic/system/status`

---

**Total OSC Endpoints:** 70+

**Documentation Maintained By:** Echoelmusic Team
**Last Updated:** 2025-12-18
**OSC Specification:** [OpenSoundControl.org](http://opensoundcontrol.org/)
