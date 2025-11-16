# 🌊 SpectralGranularSynth Demo Presets

## World's Most Advanced Spectral Granular Synthesis Engine

This directory contains 10 professionally-crafted presets showcasing the revolutionary capabilities of SpectralGranularSynth - featuring 32 independent grain streams, FFT-based spectral processing, bio-reactive control, and AI-assisted grain evolution.

---

## 📚 Preset Catalog

### **01 - Celestial Clouds**
**Mode:** Hybrid (Classic + Spectral)
**Streams:** 16 | **Grain Size:** 150ms | **Density:** 32 Hz
**Description:** Ethereal ambient clouds with bio-reactive swarm behavior
**Key Features:**
- High position spray (0.7) for wandering grains
- Swarm mode enabled for organic movement
- Texture mode creates evolving complexity
- Bio-reactive: HRV → density, coherence → size
**Use Cases:** Ambient music, meditation, film underscores

---

### **02 - Frozen Moment**
**Mode:** Spectral (FFT-based)
**Streams:** 24 | **Grain Size:** 200ms | **Density:** 64 Hz
**Description:** Time-frozen spectral clouds with bio-reactive blur
**Key Features:**
- **FREEZE MODE ENABLED** - captures and holds spectral moment
- Spectral blur (0.6) smears frozen spectrum
- BiDirectional playback for shimmer effect
- Tonality filter (0.9) isolates harmonic content
**Use Cases:** Cinematic drones, soundscapes, experimental music

---

### **03 - Rhythmic Glitch**
**Mode:** Classic (Time-domain)
**Streams:** 8 | **Grain Size:** 15ms | **Density:** 128 Hz
**Description:** Chaotic glitch textures with extreme bio-reactivity
**Key Features:**
- Ultra-short grains (15ms) for glitchy textures
- High swarm chaos (0.9) creates unpredictable behavior
- Random direction for stuttering effects
- Noisiness filter (0.7) emphasizes transients
- **100% HRV control** for heart-driven rhythms
**Use Cases:** IDM, glitch-hop, experimental electronica

---

### **04 - Tonal Shimmer**
**Mode:** Spectral (FFT-based)
**Streams:** 20 | **Grain Size:** 100ms | **Density:** 40 Hz
**Description:** Pure tonal grains with gentle swarm behavior
**Key Features:**
- Tonality filter (1.0) = **100% tonal grains only**
- High attraction (0.8) keeps grains cohesive
- Pitch shifted +12 semitones for shimmer
- Low noisiness (0) for crystal clarity
**Use Cases:** Pads, ambient chords, ethereal textures

---

### **05 - Reverse Dreams**
**Mode:** Hybrid
**Streams:** 12 | **Grain Size:** 250ms | **Density:** 24 Hz
**Description:** Backward-moving grains create reverse ambiences
**Key Features:**
- **REVERSE direction** for all grains
- Large grain size (250ms) for smooth swells
- Pitch shifted +5 semitones
- Medium tonality (0.6) balances harmonic/inharmonic
**Use Cases:** Reverse FX, cinematic build-ups, ambient swells

---

### **06 - Micro Rhythms**
**Mode:** Classic
**Streams:** 4 | **Grain Size:** 8ms | **Density:** 200 Hz
**Description:** Ultra-fast micro-rhythmic patterns with chaotic swarm
**Key Features:**
- **Ultra-short 8ms grains** for micro-rhythms
- Extreme density (200 Hz) = 200 grains/second
- Very high chaos (0.85) for unpredictable patterns
- Position spray (0.95) maximizes variation
**Use Cases:** Rhythmic textures, percussion design, IDM

---

### **07 - Orchestra Ghost**
**Mode:** Spectral
**Streams:** 32 | **Grain Size:** 180ms | **Density:** 48 Hz
**Description:** Ghostly orchestral textures from frozen spectral moments
**Key Features:**
- **ALL 32 STREAMS ACTIVE** for maximum density
- Freeze mode captures orchestral moments
- BiDirectional for ghost-like reversals
- Low spectral mask (80-4000 Hz) for orchestral range
- Bio-reactive: Breath → pitch (0.65)
**Use Cases:** Film scores, horror soundtracks, experimental orchestral

---

### **08 - Noise Garden**
**Mode:** Hybrid
**Streams:** 16 | **Grain Size:** 75ms | **Density:** 80 Hz
**Description:** Organic noisy textures - great for sound design
**Key Features:**
- High noisiness (0.9) emphasizes noise components
- Random direction for chaotic evolution
- High-frequency spectral mask (2-18 kHz)
- Swarm repulsion (0.5) spreads grains apart
**Use Cases:** Sound design, atmospheres, noise music

---

### **09 - Cinematic Swell**
**Mode:** Spectral
**Streams:** 24 | **Grain Size:** 300ms | **Density:** 16 Hz
**Description:** Massive cinematic builds controlled by breath
**Key Features:**
- Large grains (300ms) for smooth swells
- Exponential envelope for natural crescendo
- High attraction (0.9) keeps grains unified
- **95% breath → pitch control** for performance
- Pitch shifted +7 semitones for epic quality
**Use Cases:** Film trailers, dramatic builds, cinematic scores

---

### **10 - Bio-Reactive Swarm**
**Mode:** Neural (AI-assisted grain selection)
**Streams:** 32 | **Grain Size:** 120ms | **Density:** 60 Hz
**Description:** 100% bio-reactive chaos - your heart creates the sound!
**Key Features:**
- **NEURAL MODE** - AI selects optimal grains
- **ALL 32 STREAMS ACTIVE**
- **100% bio-reactive on all parameters:**
  - HRV → density (1.0)
  - HRV → position (1.0)
  - Coherence → size (1.0)
  - Breath → pitch (1.0)
- Maximum swarm chaos (0.95) and repulsion (0.9)
- Maximum texture complexity (1.0)
**Use Cases:** Bio-feedback therapy, meditation, experimental performance

---

## 🎮 How to Use

### **Loading Presets**

1. **Via Plugin UI:**
   - Open SpectralGranularSynth in your DAW
   - Click "Preset Browser"
   - Select desired preset
   - Click "Load"

2. **Via Code:**
   ```cpp
   SpectralGranularSynth synth;
   synth.loadPreset("CelestialClouds");
   ```

---

## 🔬 Understanding the Parameters

### **Grain Modes**

| Mode | Description | Best For |
|------|-------------|----------|
| **Classic** | Time-domain granular synthesis | Traditional grains, rhythmic textures |
| **Spectral** | FFT-based frequency-domain grains | Smooth pads, frozen moments, tonal sounds |
| **Hybrid** | Mix of classic + spectral | Versatile, best of both worlds |
| **Neural** | AI-assisted grain selection | Intelligent, adaptive textures |
| **Texture** | ML-generated evolving grains | Experimental, generative music |

### **Global Parameters**

| Parameter | Range | Description |
|-----------|-------|-------------|
| **Grain Size** | 1-1000ms | Duration of each grain |
| **Density** | 1-256 Hz | Grains generated per second |
| **Position** | 0-1 | Playback position in source buffer |
| **Pitch** | -24 to +24 | Pitch shift in semitones |

### **Spray Parameters** (Randomization)

| Parameter | Range | Effect |
|-----------|-------|--------|
| **Position Spray** | 0-1 | Random variation in grain start position |
| **Pitch Spray** | 0-1 | Random pitch variation (±12 semitones max) |
| **Pan Spray** | 0-1 | Random stereo placement |
| **Size Spray** | 0-1 | Random grain size variation |

### **Spectral Parameters**

| Parameter | Range | Description |
|-----------|-------|-------------|
| **Mask Low** | 20-20000 Hz | Low-frequency cutoff |
| **Mask High** | 20-20000 Hz | High-frequency cutoff |
| **Tonality** | 0-1 | 0=all, 1=only tonal content |
| **Noisiness** | 0-1 | 0=tonal only, 1=noisy only |

### **Envelope Shapes**

- **Linear:** Simple linear ramp
- **Exponential:** Natural attack/release curves
- **Gaussian:** Bell-curve (smooth, no clicks)
- **Hann:** Raised cosine (classic windowing)
- **Hamming:** Modified cosine (minimal side lobes)
- **Welch:** Parabolic window
- **Triangle:** Sharp attack/release
- **Trapezoid:** Flat sustain with attack/release

### **Special Modes**

#### **Freeze Mode**
- Captures spectral moment and holds it
- **Blur** parameter smears frozen spectrum
- Perfect for creating drones from transients

#### **Swarm Mode**
- Grains behave like particle swarm
- **Chaos:** Random movement amount
- **Attraction:** Pull toward center position
- **Repulsion:** Push away from other grains

#### **Texture Mode**
- ML generates evolving grain patterns
- **Complexity:** Detail level
- **Evolution:** Auto-change speed
- **Randomness:** Unpredictability amount

---

## 🫀 Bio-Reactive Control

All presets include bio-reactive mappings:

| Bio Signal | Typical Mapping | Effect |
|------------|-----------------|---------|
| **HRV (Heart Rate Variability)** | Grain Density | Faster heart → more grains |
| **HRV** | Position | Heart rate shifts playback position |
| **Coherence** | Grain Size | Coherent heart → larger, smoother grains |
| **Breath** | Pitch | Breathing controls pitch shifts |

### **Bio-Reactive Setup**

1. Connect bio-sensor (HeartMath, Muse, etc.)
2. Enable "Bio-Reactive" mode
3. Adjust mapping amounts (0-1.0)
4. Play and let your physiology shape the grains!

---

## 💡 Creative Techniques

### **1. Frozen Orchestra**
- Load orchestral sample
- Use preset: **07_OrchestraGhost**
- Enable Freeze Mode
- Capture dramatic chord moment
- Bio-reactive breath controls pitch
**Result:** Infinite orchestral drone from single chord

### **2. Glitch Percussion**
- Load percussive sample
- Use preset: **03_RhythmicGlitch**
- Set grain size 5-20ms
- High density (100+ Hz)
- Bio-reactive HRV controls rhythm
**Result:** Heart-driven glitch percussion

### **3. Reverse Build**
- Load impact sound
- Use preset: **05_ReverseDreams**
- Set reverse direction
- Large grains (200-300ms)
- Breath controls intensity
**Result:** Cinematic reverse build-up

### **4. Shimmer Pad**
- Load vocal or guitar sample
- Use preset: **04_TonalShimmer**
- Pitch +7 or +12 semitones
- Tonality = 1.0 (pure tones)
- Low density for clarity
**Result:** Angelic shimmer pad

### **5. Bio-Feedback Meditation**
- Load nature sounds
- Use preset: **10_BioReactiveSwarm**
- 100% bio-reactivity
- Let heart guide the sound
**Result:** Physiological soundscape

---

## 📊 Performance Notes

### **CPU Usage**

| Configuration | CPU Load | Recommendations |
|---------------|----------|-----------------|
| **1-8 streams** | Low | Safe for all systems |
| **9-16 streams** | Medium | Modern CPU recommended |
| **17-32 streams** | High | Powerful CPU required |
| **+ Spectral Mode** | +20% | FFT processing overhead |
| **+ Freeze Mode** | +10% | Spectral blur processing |

### **Latency**

- **Classic Mode:** < 1ms
- **Spectral Mode:** 2-5ms (FFT window)
- **Neural Mode:** 5-10ms (AI inference)
- **Overall:** Suitable for real-time performance

### **Buffer Size**

Recommended settings:
- **256 samples:** Low-latency performance
- **512 samples:** Balanced
- **1024+ samples:** Complex multi-stream setups

---

## 🎨 Customization Tips

### **Creating Your Own Presets**

1. **Start with a Base:**
   - Choose similar existing preset
   - Modify one parameter at a time

2. **Grain Size Strategy:**
   - **Small (1-50ms):** Rhythmic, glitchy
   - **Medium (50-150ms):** Musical, textured
   - **Large (150-1000ms):** Smooth, drone-like

3. **Density Strategy:**
   - **Sparse (1-20 Hz):** Individual grains audible
   - **Medium (20-80 Hz):** Textured, granular
   - **Dense (80-256 Hz):** Continuous, smooth

4. **Stream Count:**
   - **1-4 streams:** Focused, clear
   - **8-16 streams:** Rich, complex
   - **24-32 streams:** Massive, cloud-like

5. **Spray Amount:**
   - **Low (0-0.3):** Tight, controlled
   - **Medium (0.3-0.7):** Balanced variation
   - **High (0.7-1.0):** Chaotic, unpredictable

---

## 🚀 Advanced Uses

### **Live Performance**
- Map MIDI CC to key parameters
- Use bio-sensors for physiological control
- Assign grain density to modulation wheel
- Map breath to pitch for expressive performance

### **Sound Design**
- Layer multiple presets
- Automate freeze mode captures
- Use swarm mode for organic movement
- Neural mode for AI-assisted selection

### **Film Scoring**
- Cinematic Swell for builds
- Orchestra Ghost for eerie moments
- Frozen Moment for time-freeze effects
- Celestial Clouds for ambient beds

### **Experimental Music**
- Bio-Reactive Swarm for generative pieces
- Rhythmic Glitch for IDM
- Noise Garden for harsh noise
- Micro Rhythms for complex patterns

---

## 🤖 Source File Requirements

To use these presets, you'll need audio source files:

1. **Load into Buffer:**
   ```cpp
   synth.loadFile(File("/path/to/audio.wav"));
   ```

2. **Recommended Sources:**
   - **Orchestral:** Strings, brass, choirs
   - **Percussive:** Drums, impacts, transients
   - **Harmonic:** Vocals, guitars, synths
   - **Natural:** Field recordings, ambiences

3. **Source Locations:**
   - Load via plugin UI
   - Drag & drop audio files
   - Use live audio input mode

---

## 📚 Further Learning

### **Key Concepts**

1. **Granular Synthesis:** Breaking audio into tiny grains
2. **Spectral Processing:** Frequency-domain manipulation via FFT
3. **Bio-Reactivity:** Physiological control of synthesis
4. **Swarm Behavior:** Particle systems applied to grains
5. **Neural Selection:** AI chooses optimal grains

### **Recommended Reading**
- Curtis Roads - "Microsound"
- Trevor Wishart - "Audible Design"
- Barry Truax - "Real-Time Granular Synthesis"

---

## 🎯 Preset Quick Reference

| Preset | Mode | Streams | Grain Size | Use Case |
|--------|------|---------|------------|----------|
| **01 Celestial Clouds** | Hybrid | 16 | 150ms | Ambient clouds |
| **02 Frozen Moment** | Spectral | 24 | 200ms | Time-frozen drones |
| **03 Rhythmic Glitch** | Classic | 8 | 15ms | Glitch textures |
| **04 Tonal Shimmer** | Spectral | 20 | 100ms | Shimmer pads |
| **05 Reverse Dreams** | Hybrid | 12 | 250ms | Reverse swells |
| **06 Micro Rhythms** | Classic | 4 | 8ms | Micro-patterns |
| **07 Orchestra Ghost** | Spectral | 32 | 180ms | Orchestral drones |
| **08 Noise Garden** | Hybrid | 16 | 75ms | Noise design |
| **09 Cinematic Swell** | Spectral | 24 | 300ms | Epic builds |
| **10 Bio-Reactive Swarm** | Neural | 32 | 120ms | Bio-feedback |

---

**Happy Granular Synthesis!** 🌊✨

*Echoelmusic - Where Heart Meets Sound™*
