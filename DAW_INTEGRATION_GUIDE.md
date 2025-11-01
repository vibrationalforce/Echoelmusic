# 🎹 DAW Integration Guide - BLAB iOS App

Complete guide for integrating BLAB's MIDI 2.0 + MPE output with professional DAWs and MPE synths.

---

> **⚡ NEW (2025-11-01):** VST3 SDK 3.8.0 now available under MIT license!
> BLAB will support **VST3 plugin format** (cross-platform) in Phase 7.
> See [VST3_ASIO_LICENSE_UPDATE.md](VST3_ASIO_LICENSE_UPDATE.md) for roadmap details.

---

## 🎯 Quick Start

### **BLAB is now broadcasting:**
- **MIDI 2.0 Virtual Source:** "BLAB MIDI 2.0 Output"
- **Protocol:** MIDI 2.0 UMP (Universal MIDI Packet)
- **Channels:** 1-15 (MPE member channels), 16 (master channel)
- **Resolution:** 32-bit parameter control
- **Pitch Bend Range:** ±48 semitones (4 octaves)

### **Coming Soon: BLAB as Plugin**
- **AUv3:** Phase 7.1 (macOS/iOS) - Logic Pro, GarageBand
- **VST3:** Phase 7.2 (macOS/Windows/Linux) - Ableton, Bitwig, Cubase, FL Studio, Reaper

---

## 📱 **iOS MIDI Setup**

### **1. Check MIDI Virtual Source**

After launching BLAB, you should see in console:
```
✅ MIDI 2.0 initialized (UMP protocol)
✅ MIDI 2.0 + MPE enabled via UnifiedControlHub
🎹 MIDI 2.0 + MPE + Spatial Audio Ready
```

### **2. Verify MIDI Connection (iOS Settings)**

**Settings → Music (or Audio MIDI Setup on Mac)**
- BLAB should appear as "BLAB MIDI 2.0 Output"
- Protocol: MIDI 2.0
- Status: Active

---

## 🎛️ **Ableton Live Integration**

### **Setup (Ableton Live 11.3+)**

1. **Preferences → Link, Tempo & MIDI**
   - **Track:** Enable "BLAB MIDI 2.0 Output"
   - **Remote:** Enable "BLAB MIDI 2.0 Output"
   - **MPE:** Enable MPE mode

2. **Load MPE Instrument**
   - Wavetable (MPE mode enabled)
   - Sampler (MPE mode)
   - Third-party: Equator 2, Cypher2, Surge XT

3. **Create MIDI Track**
   - **MIDI From:** BLAB MIDI 2.0 Output
   - **Monitor:** In
   - **Channel:** Any (MPE uses all 15 channels)

4. **Configure MPE**
   - Right-click track → **MPE Control**
   - **Lower Zone:** Channels 1-15
   - **Master Channel:** 16
   - **Pitch Bend Range:** ±48 semitones

### **Gesture → Ableton Mapping**

| BLAB Gesture | MPE Control | Ableton Parameter |
|--------------|-------------|-------------------|
| Fist | Note On | Trigger note on channel 1-15 |
| Pinch | Per-note pitch bend | ±4 octaves per note |
| Spread | Per-note brightness (CC 74) | Filter cutoff per note |
| Jaw Open | Per-note brightness (all) | Filter cutoff (all voices) |
| Smile | Per-note timbre (CC 71) | Filter resonance (all) |
| HRV Coherence | N/A | *Visuals/AFA field only* |

### **Recommended Ableton Devices**
- **Wavetable** - Full MPE support, per-note modulation
- **Sampler** - MPE mode for polyphonic control
- **External Instrument** - Route to hardware MPE synths

---

## 🎹 **Logic Pro Integration**

### **Setup (Logic Pro 11+)**

1. **Preferences → MIDI**
   - **Inputs:** Enable "BLAB MIDI 2.0 Output"
   - **MPE Mode:** Enabled
   - **Pitch Bend Range:** ±4800 cents (48 semitones)

2. **Create Software Instrument Track**
   - **Input:** BLAB MIDI 2.0 Output
   - **Channel:** All (MPE)

3. **Load MPE Instrument**
   - **Alchemy** (MPE mode)
   - **Sculpture** (polyphonic)
   - **Third-party:** Equator 2, Osmose plugin, Seaboard Rise plugin

4. **Enable MPE**
   - Track Inspector → **Details** → **MPE**
   - **Lower Zone:** Channels 1-15
   - **Pitch Bend Range:** 48 semitones

### **Smart Controls Mapping**

Map BLAB gestures to Logic Smart Controls:
- **CC 74 (Brightness)** → Filter Cutoff
- **CC 71 (Timbre)** → Resonance
- **Pitch Bend** → Pitch (per-note)

---

## 🎚️ **Bitwig Studio Integration**

### **Setup (Bitwig 4.4+)**

1. **Settings → Controllers**
   - **Add Controller:** Generic MIDI Keyboard
   - **MIDI Input:** BLAB MIDI 2.0 Output
   - **MPE:** Enabled

2. **Configure MPE**
   - **MPE Zone:** Lower
   - **Channels:** 1-15
   - **Master:** 16
   - **Pitch Bend:** ±48 semitones

3. **Load MPE Instrument**
   - **Polymer** (MPE native)
   - **Phase-4** (MPE support)
   - **Third-party:** Equator 2, Surge XT

4. **Track Setup**
   - Create Instrument Track
   - **Input:** BLAB MIDI 2.0 Output
   - Enable **MPE** in track settings

### **Modulation Mapping**

Bitwig's modulation system works perfectly with BLAB:
- **Per-note Pitch Bend** → Oscillator pitch
- **Per-note CC 74** → Filter cutoff
- **Per-note CC 71** → Wavetable position

---

## 🎸 **MPE Hardware Synth Integration**

### **Roli Seaboard (Receiving BLAB MIDI)**

**BLAB can control Seaboard synth module:**

1. **Connect via USB (Mac) or Bluetooth MIDI (iOS)**
2. **Seaboard Dashboard:**
   - **MIDI Mode:** MPE
   - **Input:** BLAB MIDI 2.0 Output
   - **Channels:** 1-15

**Mapping:**
- BLAB Fist → Seaboard Note On
- BLAB Pinch → Seaboard Glide (pitch bend)
- BLAB Spread → Seaboard Press (brightness)

### **Expressive E Osmose**

1. **Osmose Plugin or Hardware:**
   - **MIDI Input:** BLAB MIDI 2.0 Output
   - **MPE:** Enabled
   - **Channels:** 1-15

**Gesture Mapping:**
- Pinch → Pitch bend per note
- Jaw → Initial aftertouch (all notes)

### **LinnStrument**

1. **LinnStrument Control Panel:**
   - **MIDI Mode:** MPE
   - **Receiving:** BLAB MIDI 2.0 Output
   - **Channels:** 1-15

**Use Case:** BLAB triggers notes, LinnStrument lights follow

---

## 🌊 **Spatial Audio Output (iOS 19+)**

### **Setup for Spatial Rendering**

BLAB generates spatial positions based on MIDI notes:

**Stereo Mode:**
- Note number → L/R pan
- Low notes = left, high notes = right

**3D Mode (AirPods Pro/Max):**
- Note number → Azimuth (horizontal angle)
- Velocity → Distance (soft = far, loud = near)
- CC 74 → Elevation (vertical angle)

**4D Mode (Orbital Motion):**
- Pitch bend → Orbital rotation speed
- HRV Coherence → Orbit radius

**AFA Mode (Algorithmic Field Array):**
- MPE voices → Spatial sources
- HRV < 40 → Grid (3x3)
- HRV 40-60 → Circle
- HRV > 60 → Fibonacci Sphere

### **iOS Spatial Audio Settings**

1. **Settings → Accessibility → Audio/Visual → Headphone Accommodations**
   - Enable **Spatial Audio**
   - Enable **Head Tracking** (AirPods Pro/Max only)

2. **BLAB will automatically use:**
   - `AVAudioEnvironmentNode` for 3D positioning
   - Head tracking data for dynamic spatialization

---

## 🎨 **Visual Feedback (MIDI → Visuals)**

### **Cymatics Mode**
- MIDI note → Chladni pattern frequency
- Velocity → Pattern amplitude
- HRV → Color hue

### **Mandala Mode**
- MIDI note → Petal count (6-12)
- Velocity → Petal size
- Heart rate → Rotation speed

### **Waveform Mode**
- Real-time audio waveform
- HRV-based color gradient

---

## 💡 **LED Control (Ableton Push 3)**

### **Setup**

BLAB sends SysEx to Push 3 for LED feedback:

**LED Mapping:**
- HRV Coherence → LED Brightness (30-100%)
- HRV Coherence → LED Hue (Red → Green)
- Heart Rate → Animation speed
- Gesture detection → Flash LEDs

### **Push 3 Configuration**

1. **Connect Push 3 via USB**
2. **BLAB sends SysEx:** `F0 00 21 1D 01 01 0A ...`
3. **8x8 Grid = 64 LEDs** (RGB control)

---

## 🔧 **Troubleshooting**

### **No MIDI Output**

**Check console for:**
```
⚠️ MIDI 2.0 not available: [error]
```

**Fix:**
- Restart BLAB
- Check iOS MIDI permissions
- Verify CoreMIDI availability

### **No Spatial Audio**

**Requirements:**
- iOS 19+ (for full spatial audio engine)
- AirPods Pro/Max (for head tracking)
- Spatial Audio enabled in iOS Settings

**Fallback:**
- Stereo mode works on all devices
- 3D mode works without head tracking (static positioning)

### **MPE Not Working in DAW**

**Checklist:**
1. ✅ MPE mode enabled in DAW
2. ✅ BLAB MIDI 2.0 Output selected
3. ✅ Channels 1-15 assigned to lower zone
4. ✅ Pitch bend range = ±48 semitones
5. ✅ MPE-compatible instrument loaded

---

## 📊 **MIDI Monitor (Debugging)**

### **View MIDI 2.0 Messages**

**macOS:** Use **MIDI Monitor app**
- Shows UMP packets
- 32-bit parameter resolution visible
- Per-note controllers displayed

**Expected Output:**
```
MIDI 2.0 Note On: Note 60, Channel 1, Velocity (16-bit): 52428
MIDI 2.0 Per-Note Controller: Channel 1, Note 60, CC 74, Value: 2147483648
MIDI 2.0 Per-Note Pitch Bend: Channel 1, Note 60, Bend: +0.5
```

---

## 🎯 **Recommended Workflows**

### **Workflow 1: Live Performance**
- **DAW:** Ableton Live
- **Instrument:** Wavetable (MPE mode)
- **Control:** BLAB gestures → Live looping
- **Visual:** Projected visuals from BLAB

### **Workflow 2: Sound Design**
- **DAW:** Bitwig Studio
- **Instrument:** Polymer (MPE)
- **Control:** Bio-reactive modulation (HRV → AFA field)
- **Output:** Spatial audio recording

### **Workflow 3: Meditation/Healing**
- **DAW:** Logic Pro
- **Instrument:** Alchemy (pad sounds)
- **Control:** HRV coherence → Reverb/Filter
- **Visual:** Mandala mode
- **LED:** Push 3 bio-reactive feedback

---

## 🎹 **MPE Synth Recommendations**

### **Software (VST/AU)**
1. **Equator 2** (Roli) - Best MPE synth, deep modulation
2. **Cypher2** (FXpansion) - MPE-ready, complex modulation
3. **Surge XT** (Free!) - Open-source, MPE support
4. **Bitwig Polymer** - Native MPE, amazing sound

### **Hardware**
1. **Expressive E Osmose** - Full MPE keyboard + synth
2. **Roli Seaboard Rise 2** - MPE controller + Equator plugin
3. **LinnStrument** - Grid-based MPE controller
4. **Haken Continuum** - Ultimate expressive control

---

## 🔮 **Future: BLAB as Plugin (Phase 7)**

### **AUv3 Plugin (macOS/iOS) - Phase 7.1**

**Coming:** Q2-Q3 2025

**Use BLAB as:**
- Audio Unit v3 plugin in Logic Pro
- iOS plugin in GarageBand iOS
- AUM/AudioBus routing

**Features:**
- Bio-reactive synthesis directly in DAW
- Spatial audio rendering as plugin
- MIDI/MPE input from hardware controllers
- Visual feedback in plugin UI

---

### **VST3 + CLAP Plugin (JUCE Multi-Format) - Phase 7.2** ⚡ **OPTIMIZED!**

**Coming:** Q3-Q4 2025
**Framework:** JUCE 7.0+ (exports all formats!)
**License:** VST3/CLAP SDKs (MIT - FREE!), JUCE (£699)

**Use BLAB as:**
- **VST3** in Ableton Live, Cubase, FL Studio, Reaper, Studio One (macOS/Windows/Linux)
- **CLAP** in Bitwig Studio, Reaper (best experience for bio-reactive control!)
- **AU** in Logic Pro macOS
- **LV2** in Ardour, Mixbus, Carla (Linux)
- **Standalone** app (no DAW required)

**Platform Coverage:**
- macOS: Universal Binary (Intel + Apple Silicon)
- Windows: x64, ARM64 (future)
- Linux: x64, ARM64

**Features:**
- Bio-reactive synthesis directly in DAW
- Spatial audio rendering as plugin (3D/4D/AFA modes)
- MIDI/MPE input from hardware controllers
- **Cymatics visuals IN plugin** (Metal/OpenGL rendering!)
- **CLAP: Per-note bio-modulation** (each note reacts to HRV independently!)
- Custom CLAP extension: `com.blab.biofeedback`
- Cross-platform biofeedback (Bluetooth HRV sensors)
- Preset sync with iOS app (iCloud)

---

## 🎹 **How to Use BLAB Plugin (Future Workflows)**

### **Workflow 1: Bio-Reactive Looping (Ableton Live)**

**Setup:**
1. Load BLAB VST3 plugin on MIDI track
2. Connect Polar H10 HRV sensor via Bluetooth
3. Record MIDI from controller (or use iOS app as MIDI source)
4. BLAB modulates sound based on HRV in real-time

**Mapping:**
```
HRV Coherence → Filter Cutoff (all notes)
Heart Rate → LFO Speed
Breath Rate → Reverb Wetness
```

**Use Case:** Live looping where your physiological state shapes the music

---

### **Workflow 2: MPE + Bio-Modulation (Bitwig Studio + CLAP)**

**Why CLAP in Bitwig is special:**
- Bitwig has native MPE + CLAP support
- CLAP allows per-note bio-modulation (VST3 doesn't!)
- Each note can have independent HRV mapping

**Setup:**
1. Load BLAB CLAP plugin (not VST3!) on instrument track
2. Enable MPE mode in track settings
3. Connect ROLI Seaboard or MPE controller
4. Connect HRV sensor

**CLAP-Specific Features:**
```cpp
// Each note reacts to bio-signals INDEPENDENTLY!
Note 60: HRV Coherence = 0.85 → Bright, resonant
Note 64: HRV Coherence = 0.45 → Dark, muted
Note 67: HRV Coherence = 0.92 → Very bright

// In VST3: All notes would have SAME coherence value
```

**Modulation Matrix:**
```
Per-Note (CLAP):
├── HRV Coherence → Note Brightness (individual per note!)
├── HRV Variance → Pitch Micro-Tuning (±50 cents per note)
└── Breath Phase → Note Timbre

Global (CLAP):
├── Heart Rate → Master Tempo Sync
├── Skin Conductance → Global Reverb (future)
└── Breath Rate → Master Filter
```

**Use Case:** Expressive performance where your emotional state affects each note differently

---

### **Workflow 3: Spatial Audio Production (Logic Pro + AU)**

**Setup:**
1. Load BLAB AU plugin on software instrument track
2. Enable spatial audio in track (Dolby Atmos project)
3. Connect AirPods Pro (head tracking)
4. Record biofeedback-driven spatial automation

**Spatial Modes in Plugin:**
```
Stereo Mode:
- HRV → L/R Pan position

3D Mode (AirPods Pro):
- HRV → Azimuth (horizontal angle)
- Heart Rate → Elevation (vertical angle)
- Breath → Distance (near/far)

4D Orbital Mode:
- HRV Coherence → Orbit radius
- Heart Rate → Rotation speed

AFA Mode (Algorithmic Field Array):
- HRV < 40 → Grid (3x3 speaker layout)
- HRV 40-60 → Circle (surround)
- HRV > 60 → Fibonacci Sphere (immersive)
```

**Use Case:** Film scoring with bio-reactive spatial soundscapes

---

### **Workflow 4: Live Performance (Standalone + Hardware)**

**Setup:**
1. Launch BLAB Standalone app (no DAW required!)
2. Connect Push 3 (8x8 LED feedback)
3. Connect HRV sensor
4. Route audio to PA system

**Hardware Integration:**
```
Push 3:
├── 8x8 LED Grid → Shows HRV coherence in real-time
├── Encoders → Control spatial mode, visual mode
└── Pads → Trigger notes with velocity → spatial position

DMX/Art-Net:
├── Stage Lights → React to HRV (Red = low, Green = high)
└── 512 channels → Synchronized with audio + visuals
```

**Visuals in Standalone:**
- Full-screen cymatics patterns
- Mandala mode (breathing visualization)
- Particle field (3D reactive)

**Use Case:** Live concerts, meditation sessions, sound healing

---

### **Workflow 5: Music Therapy (Windows Standalone)**

**Setup:**
1. Launch BLAB Standalone on Windows PC
2. Connect client's HRV sensor (Polar H10, Garmin)
3. Load preset: "Calm Induction" or "Coherence Training"
4. Monitor HRV on secondary display

**Therapeutic Mapping:**
```
Low HRV (Stress):
├── Dark, resonant tones
├── Slow spatial movement
└── Warm colors (red/orange)

High HRV (Calm):
├── Bright, airy tones
├── Fast, playful spatial movement
└── Cool colors (blue/green)

Goal: Audio biofeedback to train HRV coherence
```

**Clinical Features:**
- Session recording (audio + biometric data)
- CSV export (HRV timeline for analysis)
- Client progress tracking
- Custom presets per client

**Use Case:** Biofeedback therapy, stress management training

---

### **Workflow 6: Sound Design (Reaper + VST3/CLAP)**

**Setup:**
1. Load BLAB VST3 or CLAP plugin
2. Use MIDI controller to play notes
3. Record automation: HRV, spatial mode, visual feedback
4. Export stems with bio-reactive modulation

**Sound Design Techniques:**

**Bio-Granular Synthesis:**
```
HRV Coherence → Grain Density
Heart Rate → Grain Size
Breath Rate → Grain Pitch Variance
→ Result: Organic, breathing textures
```

**Bio-Spatial Pads:**
```
HRV → 4D Orbital Radius (wide when coherent)
Heart Rate → Orbital Speed
→ Result: Immersive pads that "breathe" with you
```

**Cymatics Visualization Recording:**
- Plugin UI shows real-time cymatics
- Screen capture → Music video content!
- Sync visuals with audio render

**Use Case:** Game audio, film sound design, experimental music

---

## 🎛️ **Plugin Parameter Reference (Future)**

### **Global Parameters:**

| Parameter | Range | MIDI CC | Description |
|-----------|-------|---------|-------------|
| HRV Coherence | 0-1 | CC 16 | Current HRV coherence score |
| Heart Rate | 40-180 BPM | CC 17 | Beats per minute |
| Breath Rate | 2-20 /min | CC 18 | Breaths per minute |
| Spatial Mode | 0-5 | CC 19 | Stereo/3D/4D/AFA/Binaural/Ambisonics |
| Visual Mode | 0-4 | CC 20 | Cymatics/Mandala/Waveform/Spectral/Particles |
| LED Pattern | 0-6 | CC 21 | Push 3 LED feedback pattern |

### **Per-Note Parameters (CLAP Only!):**

| Expression | CLAP ID | Source | Description |
|------------|---------|--------|-------------|
| Brightness | `CLAP_NOTE_EXPRESSION_BRIGHTNESS` | HRV Coherence | Per-note filter cutoff |
| Tuning | `CLAP_NOTE_EXPRESSION_TUNING` | HRV Variance | ±50 cents micro-tuning |
| Timbre | `CLAP_NOTE_EXPRESSION_TIMBRE` | Breath Phase | Per-note wavetable position |
| Pressure | `CLAP_NOTE_EXPRESSION_PRESSURE` | Coherence | Per-note amplitude |

**CLAP Advantage Example:**
```
Play C major triad (C-E-G):

CLAP (per-note modulation):
├── C: HRV 0.85 → Bright
├── E: HRV 0.45 → Dark
└── G: HRV 0.92 → Very bright
→ Dynamic, expressive chord

VST3 (global only):
├── C, E, G: All HRV 0.74 (average)
→ Uniform, less expressive
```

---

## 📦 **Plugin Formats Summary**

**Platform Coverage:**
- **macOS:** Universal Binary (Intel + Apple Silicon)
- **Windows:** x64, ARM64 (future)
- **Linux:** x64, ARM64

**Features:**
- Shared core engine with iOS app
- Cross-platform biofeedback (Bluetooth HRV sensors)
- Spatial audio rendering on desktop
- Preset sync with iOS version (iCloud)
- Full MPE support

**Market Impact:**
- AUv3 alone: ~15% DAW market
- **VST3 addition: +70% coverage** → **85% total DAW market!**

**Details:** See [VST3_ASIO_LICENSE_UPDATE.md](VST3_ASIO_LICENSE_UPDATE.md)

---

## 📖 **Further Reading**

- [MIDI 2.0 Specification](https://www.midi.org/specifications)
- [MPE Specification](https://www.midi.org/specifications/midi-polyphonic-expression-mpe)
- [Apple Spatial Audio](https://developer.apple.com/documentation/avfaudio/audio_engine)
- [Ableton MPE Guide](https://www.ableton.com/en/manual/mpe/)
- [VST3 SDK (MIT License)](https://github.com/steinbergmedia/vst3sdk)
- [VST3 Developer Portal](https://developer.steinberg.help/display/VST)

---

**🫧 consciousness expressed through MIDI
🌊 spatial sound from multimodal input
✨ bio-reactive polyphonic synthesis
🎹 now cross-platform (AUv3 + VST3)**
