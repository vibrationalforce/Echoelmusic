# Echoelmusic + Max/MSP Integration

**Bio-Reactive Audio Processing and Performance Control**

This document shows how to build bio-reactive audio systems using Echoelmusic's OSC API and Max/MSP (or Max for Live).

---

## Network Setup

### OSC Configuration

**Echoelmusic:**
- Receive Port: 8000
- Send Port: 9000

**Max/MSP:**
- `[udpreceive 9000]` - Receive from Echoelmusic
- `[udpsend 127.0.0.1 8000]` - Send to Echoelmusic

---

## Basic Setup (5 minutes)

### Max Patch Structure

```
[udpreceive 9000]
    |
    v
[OSCroute /echoelmusic/bio /echoelmusic/audio]
    |                    |
    v                    v
[route hrv coherence]  [route transport/playing tempo]
    |        |              |           |
    v        v              v           v
  [hrv]   [coherence]   [playing]   [tempo]
```

### 1. Create OSC Receiver

```
[udpreceive 9000]
|
[prepend set]
|
[OSCroute /echoelmusic/bio /echoelmusic/mod /echoelmusic/trigger]
```

### 2. Parse Biofeedback Data

```
[OSCroute hrv coherence heartrate stress sdnn rmssd lfhf]
    |       |         |          |       |     |      |
    |       |         |          |       |     |      [lfhf_value]
    |       |         |          |       |     [rmssd_value]
    |       |         |          |       [sdnn_value]
    |       |         |          [stress_value]
    |       |         [heartrate_value]
    |       [coherence_value]
    [hrv_value]
```

### 3. Map to Audio Parameters

```
# Map HRV to filter cutoff (20-20000 Hz)
[hrv_value]
|
[scale 0. 1. 20. 20000.]
|
[mtof]
|
[filtergraph~]


# Map coherence to reverb mix
[coherence_value]
|
[scale 0. 1. 0. 1.]
|
[*~ ]  # Mix dry/wet


# Map heart rate to tempo sync
[heartrate_value]
|
[/ 60.]  # BPM to Hz
|
[metro]
```

---

## Advanced Techniques

### 1. Bio-Reactive Synthesizer

```
# Main oscillator controlled by HRV
[phasor~ ]
|
[*~ ]  <-- [coherence] (waveshaping amount)
|
[clip~ -1. 1.]
|
[filtergraph~]  <-- [hrv * 20000] (cutoff)
|
[*~ 0.5]
|
[dac~]


# Heartbeat trigger -> kick drum
[udpreceive 9000]
|
[OSCroute /echoelmusic/trigger/beat]
|
[t b]
|
[metro 50]  # Envelope decay
|
[line~ 0 50]
|
[*~ 100]
|
[+~ 50]
|
[cycle~]
|
[*~]  <-- [line~ 1 0 50] (amplitude envelope)
|
[dac~]
```

### 2. LF/HF Ratio → Timbre Morphing

The LF/HF ratio indicates autonomic balance:
- Low (<1.0) = Relaxed (parasympathetic)
- High (>2.0) = Stressed (sympathetic)

```
# Morph between two timbres based on LF/HF
[lfhf_value]
|
[clip 0. 3.]
|
[/ 3.]  # Normalize to 0-1
|
[t f f]
|       |
|       [- 1.]
|       [abs]
|       [timbre_B_amount]
|
[timbre_A_amount]


# Oscillator A (warm, sine-like)
[cycle~ 440]
|
[*~]  <-- [timbre_A_amount]


# Oscillator B (bright, complex)
[saw~ 440]
|
[filtergraph~]  # High-pass
|
[*~]  <-- [timbre_B_amount]


# Mix
[+~]
|
[*~ 0.5]
|
[dac~]
```

### 3. SDNN & RMSSD → Rhythmic Variation

SDNN and RMSSD measure heart rate variability:

```
# RMSSD (short-term variability) → Rhythmic complexity
[rmssd_value]
|
[scale 0. 100. 1 16]  # 1-16 subdivisions
|
[int]
|
[metro]  <-- [* ]  <-- [tempo / 60.]


# SDNN (long-term variability) → Pattern length
[sdnn_value]
|
[scale 0. 100. 4 32]
|
[int]
|
[counter 0 ]  # Pattern length
|
[itable pattern]  # Read from pattern table
|
[makenote 60 100]
|
[noteout]
```

---

## Transport Synchronization

### Sync Max/MSP to Echoelmusic Transport

```
# Receive transport status
[udpreceive 9000]
|
[OSCroute /echoelmusic/audio/transport /echoelmusic/audio/tempo]
    |                                       |
    v                                       v
[route playing position]                [tempo_value]
    |          |                            |
    v          v                            v
[playing]  [position]                   [transport tempo]


# Update Max transport
[playing]
|
[sel 1 0]
|    |
|    [stop]
[play]


[tempo]
|
[prepend tempo]
|
[transport]
```

### Send Max Transport to Echoelmusic

```
# When Max transport starts
[transport]
|
[route playing tempo]
    |          |
    v          v
[sel 1]     [prepend /echoelmusic/audio/tempo]
|           |
[t b]       [udpsend 127.0.0.1 8000]
|
[prepend /echoelmusic/audio/transport/play]
|
[udpsend 127.0.0.1 8000]
```

---

## Max for Live Integration

### Device: Bio-Filter

Create a Max for Live audio effect:

```
# Audio input
[plugin~]
|
[filtergraph~]
    ^
    |
    [pack f f f]  # Cutoff, Resonance, Type
        ^  ^  ^
        |  |  [1]  # Lowpass
        |  [scale 0. 1. 0. 0.99]  <-- [coherence]
        [scale 0. 1. 20. 20000.]  <-- [hrv]


# OSC receiver (background process)
[udpreceive 9000]
|
[OSCroute /echoelmusic/bio/hrv /echoelmusic/bio/coherence]
    |                              |
    v                              v
[s hrv_global]                  [s coherence_global]


# In audio thread
[r hrv_global]      [r coherence_global]
    |                      |
    v                      v
[scale...]          [scale...]
```

### Device: Bio-LFO

Map biofeedback to Ableton parameters:

```
[udpreceive 9000]
|
[OSCroute /echoelmusic/bio/heartrate]
|
[/ 60.]  # BPM to Hz
|
[phasor~]
|
[cycle~]
|
[scale~ -1. 1. 0. 127.]
|
[plugout~]  # Mapped to any Ableton parameter
```

---

## Session Control

### Save/Load Sessions from Max

```
# Save session button
[button Save Session]
|
[prepend /echoelmusic/session/save]
|
[prepend send]
|
[prepend "/Users/music/sessions/session1.echoelmusic"]
|
[udpsend 127.0.0.1 8000]


# Set tempo from Max
[number]  # Tempo slider
|
[prepend /echoelmusic/audio/tempo]
|
[prepend send]
|
[udpsend 127.0.0.1 8000]
```

---

## DMX Lighting Control

### Sync Lighting to Biofeedback

```
# Map coherence to scene selection
[coherence_value]
|
[scale 0. 1. 0 10]  # 10 lighting scenes
|
[int]
|
[prepend /echoelmusic/dmx/scene/recall/]
|
[prepend send]
|
[udpsend 127.0.0.1 8000]


# Flash on heartbeat
[udpreceive 9000]
|
[OSCroute /echoelmusic/trigger/beat]
|
[t b]
|
[prepend /echoelmusic/dmx/universe/blackout]
|
[prepend send]
|
[udpsend 127.0.0.1 8000]
|
[delay 50]
|
[prepend /echoelmusic/dmx/scene/recall/default]
|
[prepend send]
|
[udpsend 127.0.0.1 8000]
```

---

## Performance Tips

### 1. Smooth Value Changes

Biofeedback can be noisy - smooth it:

```
[hrv_value]
|
[line 0 100]  # 100ms smoothing
|
[scale...]
```

### 2. Threshold Detection

Create zones for different states:

```
[coherence_value]
|
[sel 0.8]  # High coherence threshold
|
[t b]
|
[print "Flow State Achieved!"]
```

### 3. Data Recording

Log biofeedback for analysis:

```
[metro 1000]  # 1 Hz
|
[prepend dump]
|
[textfile]  # Writes to text file
    ^
    |
[pak hrv coherence heartrate]
    ^       ^          ^
    |       |          |
[hrv]  [coherence] [heartrate]
```

---

## Troubleshooting

**Problem:** OSC messages not received

**Solution:**
1. Check Max console for errors
2. Test with `[print]` after `[udpreceive 9000]`
3. Verify firewall allows UDP 9000
4. Use `[OSCroute]` from CNMAT externals

**Problem:** Values jump erratically

**Solution:**
1. Add `[line]` for smoothing
2. Use `[clip]` to limit range
3. Filter with `[scale]` and `[!/ ]` for averaging

**Problem:** Max freezes with high OSC rate

**Solution:**
1. Reduce Echoelmusic OSC update rate to 20-30 Hz
2. Use `[speedlim]` to throttle incoming messages
3. Process OSC in lower-priority thread

---

## Example Patches

### Patch 1: Bio-Drone
- 3 oscillators with slightly detuned frequencies
- Cutoff modulated by HRV (slow LFO)
- Reverb mix controlled by coherence
- Amplitude envelope from heartbeat trigger

### Patch 2: Generative Sequencer
- Step count determined by SDNN (4-16 steps)
- Step probability from coherence (0-100%)
- Note duration from RMSSD (50-500ms)
- Tempo locked to heart rate

### Patch 3: Live Effect Chain
- Auto-filter (HRV → cutoff)
- Delay (heart rate → delay time)
- Reverb (coherence → mix)
- Compression (stress → ratio)

---

## Resources

- **Echoelmusic OSC API:** `OSC_API.md`
- **CNMAT OSC Externals:** https://github.com/CNMAT/CNMAT-Externs
- **Max for Live SDK:** Included with Ableton Live Suite
- **Example Patches:** `Examples/Max_BioReactive.maxpat` (would be included)

---

**Created By:** Echoelmusic Team
**Last Updated:** 2025-12-18
**Compatible With:** Max/MSP 8.0+, Max for Live, Echoelmusic 1.0+
