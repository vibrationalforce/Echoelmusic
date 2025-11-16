# 🎹 NeuralSoundSynth Demo Presets

## World's First Bio-Reactive Neural Synthesizer Presets

This directory contains 10 carefully crafted demo presets showcasing the revolutionary NeuralSoundSynth capabilities.

---

## 📚 Preset Catalog

### **01 - Bright Piano**
**Category:** Keyboards
**Description:** Bright, articulate piano perfect for pop and classical music
**Bio-Reactive Focus:** Moderate HRV control for expressive dynamics
**Use Cases:** Pop ballads, classical pieces, jazz chords

### **02 - Warm Strings**
**Category:** Strings
**Description:** Lush, warm orchestral strings with rich harmonic content
**Bio-Reactive Focus:** High breath control for natural swells
**Use Cases:** Film scores, ambient music, orchestral arrangements

### **03 - Brass Ensemble**
**Category:** Brass
**Description:** Powerful brass section with punchy attack and rich harmonics
**Bio-Reactive Focus:** Breath-reactive dynamics for brass articulation
**Use Cases:** Big band, orchestral hits, fanfares

### **04 - Ethereal Pad**
**Category:** Synth
**Description:** Evolving ambient pad with bio-reactive movement and space
**Bio-Reactive Focus:** Maximum bio-reactivity for evolving textures
**Use Cases:** Ambient music, meditation, film underscores

### **05 - Synth Bass**
**Category:** Bass
**Description:** Punchy, modern synth bass with powerful low-end
**Bio-Reactive Focus:** Moderate control for groove dynamics
**Use Cases:** EDM, pop, hip-hop production

### **06 - Vocal Choir**
**Category:** Vocal
**Description:** Lush vocal ensemble with natural breathing and expression
**Bio-Reactive Focus:** Maximum breath control (95%) for natural phrasing
**Use Cases:** Cinematic scores, choral arrangements, ambient vocals

### **07 - Electric Guitar**
**Category:** Guitar
**Description:** Expressive electric guitar with natural articulation
**Bio-Reactive Focus:** HRV for pick dynamics and expressiveness
**Use Cases:** Rock, blues, indie production

### **08 - Organic Percussion**
**Category:** Percussion
**Description:** Natural percussion with expressive dynamics and texture
**Bio-Reactive Focus:** High HRV (80%) for rhythmic expressiveness
**Use Cases:** World music, organic beats, cinematic percussion

### **09 - Cinematic Atmosphere**
**Category:** FX
**Description:** Evolving cinematic soundscape with bio-reactive depth
**Bio-Reactive Focus:** Maximum bio-reactivity (95-100%) across all parameters
**Use Cases:** Film scores, trailers, ambient soundscapes

### **10 - Bio-Reactive Exploration**
**Category:** Custom
**Mode:** Latent Explore (Mode 5)
**Description:** Fully bio-reactive preset - let your heart guide the sound!
**Bio-Reactive Focus:** 100% bio-reactivity on all three axes
**Use Cases:** Meditation, bio-feedback therapy, experimental music

---

## 🎮 How to Use

### **Loading Presets**

1. **Via Plugin UI:**
   - Open NeuralSoundSynth in your DAW
   - Click "Preset Browser"
   - Select desired preset
   - Click "Load"

2. **Via Code:**
   ```cpp
   NeuralSoundSynth synth;
   synth.loadPreset("BrightPiano");
   ```

### **Bio-Reactive Control**

All presets include custom bio-reactive mappings:

- **HRV (Heart Rate Variability)** → Controls timbre evolution
- **Coherence** → Controls harmonic richness
- **Breath** → Controls dynamics and expression

To enable bio-reactive mode:
1. Connect bio-data sensor (HeartMath, Muse, etc.)
2. Enable "Bio-Reactive" in plugin settings
3. Adjust bio-mapping sensitivity (0-100%)
4. Play and let your physiology shape the sound!

---

## 🔬 Latent Space Parameters

Each preset defines 8 semantic controls that map to the 128-dimensional latent space:

| Parameter | Range | Controls |
|-----------|-------|----------|
| **Brightness** | 0.0 - 1.0 | High-frequency content, spectral centroid |
| **Warmth** | 0.0 - 1.0 | Mid-frequency content, analog character |
| **Richness** | 0.0 - 1.0 | Harmonic complexity, overtones |
| **Attack** | 0.0 - 1.0 | Temporal envelope, transient speed |
| **Texture** | 0.0 - 1.0 | Spectral roughness, noise content |
| **Movement** | 0.0 - 1.0 | Modulation depth, temporal variation |
| **Space** | 0.0 - 1.0 | Reverb, spatial depth |
| **Character** | 0.0 - 1.0 | Nonlinearity, saturation |

---

## 🎨 Customization Tips

### **Tweaking Presets**

1. **Adjust Semantic Controls:**
   - Brightness: Make sounds darker/brighter
   - Warmth: Add analog warmth or digital clarity
   - Richness: Control harmonic complexity

2. **Modify Bio-Mappings:**
   ```xml
   <BioMapping hrvDimension="64" hrvAmount="0.5"
               coherenceDimension="80" coherenceAmount="0.7"
               breathDimension="96" breathAmount="0.8"/>
   ```
   - `hrvDimension`: Which latent dimension HRV controls (0-127)
   - `hrvAmount`: Modulation intensity (0.0-1.0)

3. **Experiment with Synthesis Modes:**
   - Mode 0: Neural Direct (default)
   - Mode 1: Timbre Transfer
   - Mode 2: Style Transfer
   - Mode 3: Interpolation
   - Mode 4: Generative
   - Mode 5: Latent Explore

---

## 💡 Creative Uses

### **Ambient Music Production**
Use: 04_EtherealPad, 09_CinematicAtmosphere
Enable high bio-reactivity for evolving textures

### **Pop/Rock Production**
Use: 01_BrightPiano, 05_SynthBass, 07_ElectricGuitar
Moderate bio-reactivity for expressive performances

### **Film Scoring**
Use: 02_WarmStrings, 03_BrassEnsemble, 09_CinematicAtmosphere
High breath control for cinematic swells

### **Meditation/Wellness**
Use: 10_BioReactiveExploration
Maximum bio-reactivity for bio-feedback therapy

---

## 📊 Performance Notes

All presets are optimized for real-time performance:

- **GPU Acceleration:** < 5ms latency
- **CPU Fallback:** < 15ms latency
- **16-Voice Polyphony:** Stable at 512-sample buffer
- **Bio-Reactive Latency:** < 10ms from sensor to sound

---

## 🚀 Next Steps

1. **Load a Preset:** Start with "01_BrightPiano"
2. **Connect Bio-Sensor:** Enable bio-reactive mode
3. **Experiment:** Tweak semantic controls
4. **Create:** Save your own custom presets!

---

## 🤖 Neural Model Requirements

These presets require ONNX neural models to function. Download models from:
- **Echoelmusic Model Library:** Coming soon
- **Community Models:** [GitHub - echoelmusic/models](https://github.com/echoelmusic/models)

Install models to:
- **macOS:** `~/Library/Application Support/Echoelmusic/Models/`
- **Windows:** `C:\Users\{username}\AppData\Roaming\Echoelmusic\Models\`
- **Linux:** `~/.config/Echoelmusic/Models/`

---

**Happy Neural Synthesis!** 🎹🤖✨

*Echoelmusic - Where Heart Meets Sound™*
