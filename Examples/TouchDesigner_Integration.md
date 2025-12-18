# Echoelmusic + TouchDesigner Integration

**Complete Bio-Reactive Visual System**

This document shows how to build a professional bio-reactive visual system using Echoelmusic's OSC API and TouchDesigner.

---

## Network Setup

### 1. OSC Configuration

**In Echoelmusic:**
- Receive Port: 8000
- Send Port: 9000
- Update Rate: 60 Hz (for smooth visuals)

**In TouchDesigner:**
- OSC In DAT: Port 9000
- OSC Out CHOP: IP `127.0.0.1`, Port 8000

---

## Basic Setup (5 minutes)

### TouchDesigner Network (Simplified)

```
[oscin1 DAT]              [oscout1 CHOP]
    |                          |
    v                          v
[table1 DAT]            [constant1 CHOP]
    |                          |
    v                          |
[select1 CHOP] <---------------+
    |
    v
[circle1 SOP]
    |
    v
[geo1 COMP]
```

### 1. Create OSC In DAT

- Add **OSC In DAT** (`oscin1`)
- Parameters:
  - Protocol: UDP
  - Port: `9000`
  - Translate Messages: ON

### 2. Create OSC Out CHOP

- Add **OSC Out CHOP** (`oscout1`)
- Parameters:
  - Network Address: `127.0.0.1`
  - Network Port: `8000`
  - Active: ON

### 3. Request Biofeedback Data (Python Script)

Add **DAT Execute** connected to `oscin1`:

```python
# Request biofeedback data on startup
def onStart(dat):
    # Configure Echoelmusic for TouchDesigner
    op('oscout1').sendOSC('/echoelmusic/system/status', [])

    # Enable bio-reactive mode
    op('oscout1').sendOSC('/echoelmusic/visual/bio/reactive', [1])

    # Request initial status
    op('oscout1').sendOSC('/echoelmusic/audio/status', [])

# Process incoming biofeedback
def onReceiveOSC(dat, rowIndex, message, bytes):
    # Store all OSC messages in a table
    op('table1').appendRow([message] + list(bytes))

    # Map coherence to visual parameter
    if message == '/echoelmusic/bio/coherence':
        coherence = bytes[0]
        op('constant_coherence').par.value0 = coherence

    # Map heart rate to animation speed
    elif message == '/echoelmusic/bio/heartrate':
        hr = bytes[0]
        bpm_normalized = (hr - 60.0) / 120.0  # Normalize 60-180 BPM
        op('constant_speed').par.value0 = bpm_normalized

    # Map HRV to color
    elif message == '/echoelmusic/bio/hrv':
        hrv = bytes[0]
        op('constant_hrv').par.value0 = hrv

    # LF/HF ratio (autonomic balance)
    elif message == '/echoelmusic/bio/lfhf':
        lfhf = bytes[0]
        op('constant_lfhf').par.value0 = lfhf

    # Heartbeat trigger
    elif message == '/echoelmusic/trigger/beat':
        # Trigger flash effect
        op('flasher').par.trigger.pulse()
```

### 4. Create Visual Feedback

**Basic Coherence Circle:**

1. Add **Circle SOP** (`circle1`)
   - Expression for `radius`: `op('constant_coherence')[0] * 2.0`
   - Expression for `divs`: `max(3, int(op('constant_coherence')[0] * 64))`

2. Add **Phong MAT** (`phong1`)
   - Color R: `op('constant_hrv')[0]`
   - Color G: `0.5`
   - Color B: `1.0 - op('constant_hrv')[0]`

3. Add **Geo COMP** (`geo1`)
   - Connect `circle1` to geometry input
   - Assign `phong1` material

**Result:** Circle size/complexity driven by coherence, color by HRV

---

## Advanced Setup (Bio-Reactive Particle System)

### TouchDesigner Network

```
[oscin1] → [select_bio CHOP] → [instancing_controls CHOP]
                                        |
                                        v
[noise1 TOP] ← [feedback1 TOP] ← [composite1 TOP] ← [geo1 COMP]
     |                                                      |
     v                                                      v
[displace1 MAT] ---------------------------------> [sphere1 SOP]
                                                           |
                                                           v
                                                   [instance1 SOP]
```

### 1. Setup Biofeedback Channels

Add **Select CHOP** (`select_bio`):
- Input: `oscin1`
- Channel Names: `coherence heartrate hrv lfhf`

### 2. Particle Instancing Controlled by HRV

**Sphere Base:**
```python
# sphere1 SOP
# Expression for 'radius':
op('select_bio')['hrv'] * 0.5 + 0.1
```

**Instance Count by Coherence:**
```python
# instance1 SOP
# Expression for 'npts':
max(10, int(op('select_bio')['coherence'] * 1000))
```

**Position Noise Controlled by LF/HF:**
```python
# noise1 TOP
# Expression for 'amplitude':
op('select_bio')['lfhf'] * 100.0

# Expression for 'period':
max(0.1, 1.0 / (op('select_bio')['heartrate'] / 60.0))
```

### 3. Color Mapping (Advanced)

Add **Ramp TOP** (`ramp_color`):
- Type: RGB Color Ramp
- Keys:
  - 0.0: Red (high stress, low HRV)
  - 0.5: Yellow (neutral)
  - 1.0: Blue/Green (calm, high coherence)

**Apply Color:**
```python
# constantMAT or phongMAT
# Color R Expression:
op('ramp_color').sample(x=op('select_bio')['hrv'], y=0.5)[0]

# Color G Expression:
op('ramp_color').sample(x=op('select_bio')['hrv'], y=0.5)[1]

# Color B Expression:
op('ramp_color').sample(x=op('select_bio')['hrv'], y=0.5)[2]
```

### 4. Heartbeat Pulse Effect

Add **LFO CHOP** triggered by heartbeat:

```python
# In OSC callback:
def onReceiveOSC(dat, rowIndex, message, bytes):
    if message == '/echoelmusic/trigger/beat':
        # Reset LFO phase to create pulse
        op('lfo_heartbeat').par.reset.pulse()

        # Flash effect
        op('level_flash').par.opacity = 1.0
```

Add **Speed CHOP** to fade out flash:
```python
# speed1 CHOP
op('level_flash').par.opacity = max(0, op('level_flash').par.opacity - 0.05)
```

---

## Professional Features

### 1. Audio-Reactive + Bio-Reactive Fusion

Combine audio analysis with biofeedback:

```python
# audioanalysis1 CHOP (from TD's AudioDeviceIn)
bass = op('audioanalysis1')['band1']
mid = op('audioanalysis1')['band10']
high = op('audioanalysis1')['band20']

# Biofeedback
coherence = op('select_bio')['coherence']
hrv = op('select_bio')['hrv']

# Fusion: Scale audio reactivity by coherence
# High coherence = more audio influence
# Low coherence = more biofeedback influence
audio_weight = coherence
bio_weight = 1.0 - coherence

final_scale = (bass * audio_weight) + (hrv * bio_weight)
```

### 2. Session Control from TouchDesigner

Control Echoelmusic session via OSC:

```python
# Save session
op('oscout1').sendOSC('/echoelmusic/session/save', ['/path/to/session.echoelmusic'])

# Set tempo
op('oscout1').sendOSC('/echoelmusic/audio/tempo', [140.0])

# Play/Stop transport
op('oscout1').sendOSC('/echoelmusic/audio/transport/play', [])
op('oscout1').sendOSC('/echoelmusic/audio/transport/stop', [])

# Recall DMX lighting scene
op('oscout1').sendOSC('/echoelmusic/dmx/scene/recall', ['high_energy'])
```

### 3. Visual Presets Synchronized

Sync TouchDesigner compositions with Echoelmusic:

```python
def loadVisualPreset(presetName):
    # Load Echoelmusic visual preset
    op('oscout1').sendOSC('/echoelmusic/visual/preset/load', [presetName])

    # Load corresponding TD composition
    if presetName == 'Calm':
        op('/project1').par.compname = 'calm_comp'
    elif presetName == 'Energetic':
        op('/project1').par.compname = 'energy_comp'
```

---

## Recording & Export

### 1. Record Bio-Data to DAT

Log all biofeedback for later analysis:

```python
# Create table DAT with columns: time, message, value
op('bio_log').clear()
op('bio_log').appendRow(['Time', 'Message', 'Value'])

def onReceiveOSC(dat, rowIndex, message, bytes):
    if message.startswith('/echoelmusic/bio/'):
        timestamp = absTime.seconds
        op('bio_log').appendRow([timestamp, message, bytes[0]])

# Export to CSV
def exportBioData():
    op('bio_log').save('/path/to/biodata.csv')
```

### 2. Render Output with Bio-Metadata

Add metadata to video renders:

```python
# moviefileout1 TOP
# Pre-render script:
coherence = op('select_bio')['coherence']
hrv = op('select_bio')['hrv']
heartrate = op('select_bio')['heartrate']

metadata_text = f"Coherence:{coherence:.2f} HRV:{hrv:.2f} HR:{heartrate:.1f}bpm"

op('text_overlay').par.text = metadata_text
```

---

## Performance Tips

1. **OSC Update Rate:**
   - Biofeedback: 10-30 Hz (sufficient)
   - Audio meters: 30-60 Hz
   - Avoid 100+ Hz unless necessary

2. **Network Efficiency:**
   - Use OSC bundles for batch updates (configured in Echoelmusic)
   - Filter unwanted messages in `select_bio`

3. **TouchDesigner Optimization:**
   - Use Select CHOP to filter only needed channels
   - Cache constant values instead of recalculating
   - Use expressions sparingly in real-time loops

---

## Troubleshooting

**Problem:** No OSC messages received

**Solution:**
1. Check firewall (allow UDP 9000)
2. Verify Echoelmusic OSC is active: send `/echoelmusic/system/health/ready`
3. Use OSC Monitor in TD to see all incoming messages

**Problem:** Visuals lag behind biofeedback

**Solution:**
1. Increase OSC update rate in Echoelmusic to 60 Hz
2. Reduce TD network cook time (Project → Performance → Network Cook)
3. Use Timer CHOP for frame-accurate timing

**Problem:** Values jitter too much

**Solution:**
1. Add Filter CHOP after `select_bio`
2. Set filter width to 0.1-0.5 seconds for smoothing
3. Echoelmusic HRV already includes smoothing, but TD-side is helpful

---

## Example Projects

### Project 1: Bio-Mandala
- Geometry complexity driven by coherence
- Rotation speed by heart rate
- Color palette by HRV
- Pulse effect on heartbeat trigger

### Project 2: Particle Flow
- Particle count: coherence × 1000
- Flow velocity: heart rate / 60
- Turbulence: LF/HF ratio
- Color transition: HRV spectrum

### Project 3: Audio-Bio Fusion
- Bass response scaled by coherence
- Visual complexity: audio energy × (1 - stress)
- Feedback delay: synchronized to heart rate
- Flash on beat + heartbeat coincidence

---

## Resources

- **Echoelmusic OSC API:** See `OSC_API.md`
- **TouchDesigner Forums:** https://forum.derivative.ca
- **HeartMath Coherence:** McCraty et al. (2009)
- **Example .toe File:** `Examples/TouchDesigner_BioReactive.toe` (would be included)

---

**Created By:** Echoelmusic Team
**Last Updated:** 2025-12-18
**Compatible With:** TouchDesigner 2023.11+, Echoelmusic 1.0+
