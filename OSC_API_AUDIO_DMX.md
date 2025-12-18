# Echoelmusic OSC API - Audio & DMX Supplement

**Extension to OSC_API.md**
**Version:** 1.0.0
**Date:** 2025-12-18

This document provides complete documentation for the Audio Engine and DMX Lighting OSC interfaces.

---

## 7. Audio Engine (/audio)

### 7.1 Transport Control

#### /echoelmusic/audio/transport/play
**Type:** `bang`
**Description:** Start audio playback
**Direction:** Input
**Example:**
```
/echoelmusic/audio/transport/play
```

#### /echoelmusic/audio/transport/stop
**Type:** `bang`
**Description:** Stop audio playback
**Direction:** Input

#### /echoelmusic/audio/transport/toggle
**Type:** `bang`
**Description:** Toggle play/stop state
**Direction:** Input

#### /echoelmusic/audio/transport/position [samples]
**Type:** `int` (samples)
**Description:** Set playback position in samples
**Direction:** Bidirectional (set with argument, query without)
**Response:** `/echoelmusic/audio/status/position` [int]
**Example:**
```
# Set position to 44100 samples (1 second at 44.1kHz)
/echoelmusic/audio/transport/position 44100

# Query current position
/echoelmusic/audio/transport/position
```

#### /echoelmusic/audio/transport/position/beats [beats]
**Type:** `float` (musical time)
**Description:** Set playback position in beats
**Direction:** Input
**Calculation:** `samples = (beats / tempo) * 60.0 * sampleRate`
**Example:**
```
# Jump to beat 16
/echoelmusic/audio/transport/position/beats 16.0
```

#### /echoelmusic/audio/transport/loop [0/1]
**Type:** `int`
**Description:** Enable/disable transport looping
**Direction:** Input
**Example:**
```
/echoelmusic/audio/transport/loop 1
```

#### /echoelmusic/audio/transport/loop/region [start] [end]
**Type:** `int int` (samples)
**Description:** Set loop region in samples
**Direction:** Input
**Example:**
```
# Loop from 0 to 441000 samples (10 sec at 44.1kHz)
/echoelmusic/audio/transport/loop/region 0 441000
```

---

### 7.2 Tempo & Sync

#### /echoelmusic/audio/tempo [bpm]
**Type:** `float 20-999`
**Description:** Set project tempo in BPM
**Direction:** Bidirectional
**Response:** `/echoelmusic/audio/status/tempo` [float]
**Example:**
```
/echoelmusic/audio/tempo 140.5
```

#### /echoelmusic/audio/timesig [numerator] [denominator]
**Type:** `int int`
**Description:** Set time signature
**Direction:** Bidirectional
**Response:**
- `/echoelmusic/audio/status/timesig_num` [int]
- `/echoelmusic/audio/status/timesig_den` [int]
**Example:**
```
# Set to 7/8 time
/echoelmusic/audio/timesig 7 8
```

#### /echoelmusic/audio/sync [0/1]
**Type:** `int`
**Description:** Enable external sync (Ableton Link, MIDI Clock, etc.)
**Direction:** Input
**Example:**
```
/echoelmusic/audio/sync 1
```

---

### 7.3 Master Bus

#### /echoelmusic/audio/master/volume [value]
**Type:** `float 0-1`
**Description:** Set master output volume
**Direction:** Bidirectional
**Response:** `/echoelmusic/audio/status/volume` [float]
**Example:**
```
/echoelmusic/audio/master/volume 0.75
```

#### /echoelmusic/audio/master/level
**Type:** `bang`
**Description:** Query master output level in LUFS
**Direction:** Input
**Response:** `/echoelmusic/audio/status/level` [float]
**Update Rate:** 30-60 Hz (for metering)
**Use Case:** Level meters, loudness monitoring

#### /echoelmusic/audio/master/peak
**Type:** `bang`
**Description:** Query master peak level in dBFS
**Direction:** Input
**Response:** `/echoelmusic/audio/status/peak` [float]
**Update Rate:** 30-60 Hz (for metering)
**Use Case:** Peak meters, clipping detection

---

### 7.4 Track Control

#### /echoelmusic/audio/track/[n]/volume [value]
**Type:** `float 0-1`
**Description:** Set track volume (fader)
**Direction:** Bidirectional
**Example:**
```
# Set track 0 volume to 50%
/echoelmusic/audio/track/0/volume 0.5
```

#### /echoelmusic/audio/track/[n]/mute [0/1]
**Type:** `int`
**Description:** Mute/unmute track
**Direction:** Bidirectional
**Example:**
```
/echoelmusic/audio/track/2/mute 1
```

#### /echoelmusic/audio/track/[n]/solo [0/1]
**Type:** `int`
**Description:** Solo/unsolo track
**Direction:** Bidirectional

#### /echoelmusic/audio/track/[n]/arm [0/1]
**Type:** `int`
**Description:** Arm track for recording
**Direction:** Bidirectional
**Response:** `/echoelmusic/audio/track/[n]/arm` [int]
**Example:**
```
# Arm track 1 for recording
/echoelmusic/audio/track/1/arm 1
```

#### /echoelmusic/audio/track/[n]/name [string]
**Type:** `string`
**Description:** Set track name
**Direction:** Bidirectional
**Example:**
```
/echoelmusic/audio/track/0/name "Vocals"
```

---

### 7.5 Recording

#### /echoelmusic/audio/recording/start
**Type:** `bang`
**Description:** Start recording on all armed tracks
**Direction:** Input
**Prerequisite:** At least one track must be armed
**Example:**
```
# Arm track 0, then start recording
/echoelmusic/audio/track/0/arm 1
/echoelmusic/audio/recording/start
```

#### /echoelmusic/audio/recording/stop
**Type:** `bang`
**Description:** Stop recording (playback continues)
**Direction:** Input

#### /echoelmusic/audio/recording/status
**Type:** `bang`
**Description:** Query recording status
**Direction:** Input
**Response:** `/echoelmusic/audio/status/recording` [int 0/1]

---

### 7.6 Status Query

#### /echoelmusic/audio/status
**Type:** `bang`
**Description:** Get complete audio engine status
**Direction:** Input
**Response:** Multiple status messages:
- `/echoelmusic/audio/status/playing` [int 0/1]
- `/echoelmusic/audio/status/position` [int samples]
- `/echoelmusic/audio/status/tempo` [float]
- `/echoelmusic/audio/status/recording` [int 0/1]
- `/echoelmusic/audio/status/level` [float LUFS]
- `/echoelmusic/audio/status/peak` [float dBFS]
- `/echoelmusic/audio/status/volume` [float]
- `/echoelmusic/audio/status/tracks` [int]

---

## 8. DMX Lighting (/dmx)

### 8.1 Direct Channel Control

#### /echoelmusic/dmx/channel/[n] [value]
**Type:** `int 0-255`
**Description:** Set DMX channel value (channels 1-512)
**Direction:** Input
**Example:**
```
# Set DMX channel 1 to full intensity
/echoelmusic/dmx/channel/1 255

# Set DMX channel 10 to 50%
/echoelmusic/dmx/channel/10 127
```

#### /echoelmusic/dmx/channel/[n]/fade [value] [time_ms]
**Type:** `int 0-255, int milliseconds`
**Description:** Fade DMX channel to value over time
**Direction:** Input
**Example:**
```
# Fade channel 5 to 200 over 2 seconds
/echoelmusic/dmx/channel/5/fade 200 2000
```

---

### 8.2 Universe Control

#### /echoelmusic/dmx/universe/clear
**Type:** `bang`
**Description:** Clear all DMX channels to 0
**Direction:** Input
**Use Case:** Reset before loading new scene

#### /echoelmusic/dmx/universe/blackout
**Type:** `bang`
**Description:** Instant blackout (clears and sends immediately)
**Direction:** Input
**Use Case:** Emergency stop, performance blackout

---

### 8.3 Scene Management

#### /echoelmusic/dmx/scene/recall [name_or_id]
**Type:** `string`
**Description:** Recall scene by name or UUID
**Direction:** Input
**Example:**
```
/echoelmusic/dmx/scene/recall "warm_wash"
/echoelmusic/dmx/scene/recall "550e8400-e29b-41d4-a716-446655440000"
```

#### /echoelmusic/dmx/scene/recall/[n]
**Type:** `bang`
**Description:** Recall scene by index (0-based)
**Direction:** Input
**Example:**
```
# Recall first scene
/echoelmusic/dmx/scene/recall/0
```

#### /echoelmusic/dmx/scene/save [name]
**Type:** `string`
**Description:** Save current DMX state as new scene
**Direction:** Input
**Response:** `/echoelmusic/dmx/scene/save/result` [string "success" or "error"]
**Example:**
```
/echoelmusic/dmx/scene/save "my_new_look"
```

#### /echoelmusic/dmx/scene/delete [name]
**Type:** `string`
**Description:** Delete scene by name
**Direction:** Input
**Example:**
```
/echoelmusic/dmx/scene/delete "old_scene"
```

#### /echoelmusic/dmx/scene/list
**Type:** `bang`
**Description:** Get list of all scenes
**Direction:** Input
**Response:** `/echoelmusic/dmx/scene/item` [string] (multiple messages, one per scene)
**Example:**
```
# Request list
/echoelmusic/dmx/scene/list

# Response:
/echoelmusic/dmx/scene/item "warm_wash"
/echoelmusic/dmx/scene/item "cool_blue"
/echoelmusic/dmx/scene/item "strobes"
```

#### /echoelmusic/dmx/scene/fade [milliseconds]
**Type:** `int 0-10000`
**Description:** Set default scene crossfade time
**Direction:** Input
**Default:** 1000ms
**Example:**
```
# Set fade time to 3 seconds
/echoelmusic/dmx/scene/fade 3000
```

---

### 8.4 Art-Net Configuration

#### /echoelmusic/dmx/artnet/ip [address]
**Type:** `string` (IPv4)
**Description:** Set Art-Net target IP address
**Direction:** Input
**Default:** `255.255.255.255` (broadcast)
**Example:**
```
# Unicast to specific device
/echoelmusic/dmx/artnet/ip "192.168.1.100"

# Broadcast
/echoelmusic/dmx/artnet/ip "255.255.255.255"
```

#### /echoelmusic/dmx/artnet/universe [n]
**Type:** `int 0-32767`
**Description:** Set Art-Net universe number
**Direction:** Input
**Default:** 0
**Example:**
```
/echoelmusic/dmx/artnet/universe 1
```

#### /echoelmusic/dmx/artnet/enable [0/1]
**Type:** `int`
**Description:** Enable/disable Art-Net output
**Direction:** Input
**Example:**
```
/echoelmusic/dmx/artnet/enable 1
```

---

### 8.5 Fixture Control (High-Level)

Simplified control for intelligent fixtures. Requires fixture definitions.

#### /echoelmusic/dmx/fixture/[name]/intensity [value]
**Type:** `float 0-1`
**Description:** Set fixture intensity/dimmer
**Direction:** Input
**Example:**
```
/echoelmusic/dmx/fixture/par1/intensity 0.75
```

#### /echoelmusic/dmx/fixture/[name]/color [r] [g] [b]
**Type:** `float float float` (0-1 each)
**Description:** Set RGB color
**Direction:** Input
**Example:**
```
# Magenta color
/echoelmusic/dmx/fixture/led1/color 1.0 0.0 1.0
```

#### /echoelmusic/dmx/fixture/[name]/strobe [Hz]
**Type:** `float 0-25`
**Description:** Set strobe frequency
**Direction:** Input
**Safety:** Max 25 Hz (photosensitive seizure risk above)
**Example:**
```
/echoelmusic/dmx/fixture/strobe1/strobe 10.0
```

---

### 8.6 Status Query

#### /echoelmusic/dmx/status
**Type:** `bang`
**Description:** Get DMX system status
**Direction:** Input
**Response:**
- `/echoelmusic/dmx/status/scene` [string]
- `/echoelmusic/dmx/status/artnet` [int 0/1]
- `/echoelmusic/dmx/status/artnet/ip` [string]
- `/echoelmusic/dmx/status/artnet/universe` [int]
- `/echoelmusic/dmx/status/fadetime` [int ms]

---

## Integration Examples

### Audio + Bio Sync

Sync audio transport to heart rate:

```python
# Python with python-osc
from pythonosc import udp_client

client = udp_client.SimpleUDPClient("127.0.0.1", 8000)

def on_heartrate(address, heartrate):
    # Set audio tempo to heart rate BPM
    client.send_message("/echoelmusic/audio/tempo", heartrate)

def on_heartbeat(address):
    # Trigger on every heartbeat
    client.send_message("/echoelmusic/audio/transport/toggle", [])
```

### DMX + Bio Reactive Lighting

Map biofeedback to lighting:

```python
def on_coherence(address, coherence):
    # High coherence = warm colors
    # Low coherence = cool colors
    if coherence > 0.7:
        scene = "warm_glow"
    elif coherence > 0.4:
        scene = "neutral"
    else:
        scene = "cool_blue"

    client.send_message("/echoelmusic/dmx/scene/recall", scene)

def on_lfhf_ratio(address, lfhf):
    # High LF/HF (stress) = red intensity
    # Low LF/HF (relaxed) = blue intensity
    red_intensity = min(1.0, lfhf / 3.0)
    blue_intensity = max(0.0, 1.0 - lfhf / 3.0)

    client.send_message("/echoelmusic/dmx/fixture/par1/color",
                       [red_intensity, 0.0, blue_intensity])
```

### Complete Performance Control

```python
# Setup
client.send_message("/echoelmusic/audio/tempo", 120.0)
client.send_message("/echoelmusic/audio/timesig", [4, 4])
client.send_message("/echoelmusic/dmx/artnet/enable", 1)
client.send_message("/echoelmusic/visual/bio/reactive", 1)

# Start performance
client.send_message("/echoelmusic/audio/transport/play", [])
client.send_message("/echoelmusic/dmx/scene/recall", "intro")

# During performance - sync visuals/lights to audio position
def update_loop():
    # Query audio position (returns via OSC callback)
    client.send_message("/echoelmusic/audio/transport/position", [])

    # Based on position, trigger scene changes
    # (Implementation depends on receiving OSC responses)
```

---

## Performance Considerations

### Audio OSC Update Rates

- **Transport position:** 10-30 Hz (sufficient for visual sync)
- **Level meters:** 30-60 Hz (smooth metering)
- **Tempo/status:** On-demand only (not continuous)

### DMX Refresh Rate

- **Standard DMX:** 44 Hz maximum (every 22.7ms)
- **Art-Net:** Typically 40-44 Hz
- **Scene changes:** On-demand with fade times

### Network Optimization

1. **Use OSC bundles** for batch updates (enabled in MasterOSCRouter)
2. **Filter unnecessary messages** at receiver (OSCRoute in Max, filter in TD)
3. **Limit status queries** to essential updates only
4. **Use local network** (127.0.0.1) when possible

---

## Appendix: Complete Audio & DMX Address List

### Audio
- `/echoelmusic/audio/transport/play`
- `/echoelmusic/audio/transport/stop`
- `/echoelmusic/audio/transport/toggle`
- `/echoelmusic/audio/transport/position`
- `/echoelmusic/audio/transport/position/beats`
- `/echoelmusic/audio/transport/loop`
- `/echoelmusic/audio/transport/loop/region`
- `/echoelmusic/audio/tempo`
- `/echoelmusic/audio/timesig`
- `/echoelmusic/audio/sync`
- `/echoelmusic/audio/master/volume`
- `/echoelmusic/audio/master/level`
- `/echoelmusic/audio/master/peak`
- `/echoelmusic/audio/track/[n]/volume`
- `/echoelmusic/audio/track/[n]/mute`
- `/echoelmusic/audio/track/[n]/solo`
- `/echoelmusic/audio/track/[n]/arm`
- `/echoelmusic/audio/track/[n]/name`
- `/echoelmusic/audio/recording/start`
- `/echoelmusic/audio/recording/stop`
- `/echoelmusic/audio/recording/status`
- `/echoelmusic/audio/status`

### DMX
- `/echoelmusic/dmx/channel/[n]`
- `/echoelmusic/dmx/channel/[n]/fade`
- `/echoelmusic/dmx/universe/clear`
- `/echoelmusic/dmx/universe/blackout`
- `/echoelmusic/dmx/scene/recall`
- `/echoelmusic/dmx/scene/recall/[n]`
- `/echoelmusic/dmx/scene/save`
- `/echoelmusic/dmx/scene/delete`
- `/echoelmusic/dmx/scene/list`
- `/echoelmusic/dmx/scene/fade`
- `/echoelmusic/dmx/artnet/ip`
- `/echoelmusic/dmx/artnet/universe`
- `/echoelmusic/dmx/artnet/enable`
- `/echoelmusic/dmx/fixture/[name]/intensity`
- `/echoelmusic/dmx/fixture/[name]/color`
- `/echoelmusic/dmx/fixture/[name]/strobe`
- `/echoelmusic/dmx/status`

**Total NEW Endpoints (Audio + DMX):** 38

**Grand Total OSC Endpoints:** 108+

---

**Documentation Maintained By:** Echoelmusic Team
**Last Updated:** 2025-12-18
**See Also:** `OSC_API.md`, `TouchDesigner_Integration.md`, `MaxMSP_Integration.md`
