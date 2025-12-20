# Echoelmusic Feature Inspiration from Minimal Audio

## Research Date: December 2025

Based on analysis of [Minimal Audio](https://www.minimal.audio/) products including:
- [Current Flagship Synthesizer](https://www.minimal.audio/products/current)
- [Rift Hybrid Distortion](https://www.minimal.audio/products/rift)

---

## Key Inspirations for Echoelmusic

### 1. Stream - Cloud Content Platform
**Minimal's Approach:** Cloud-connected content browser integrated directly into the instrument. Automatically discovers and delivers new presets, samples, and wavetables as you work.

**Echoelmusic Implementation Ideas:**
- `StreamBrowser` - Real-time browsing of community video presets
- Automatic style/effect updates without leaving generation flow
- Trending prompts and generation settings
- Cloud-synced favorite styles and LoRAs

### 2. Multi-Engine Architecture
**Minimal's Approach:** Five simultaneous sound engines (2x spectral wavetable, additive, granular, time-stretching sampler)

**Echoelmusic Parallel:**
- T2V Engine (Text-to-Video)
- I2V Engine (Image-to-Video) ✅ Implemented
- S2V Engine (Sound-to-Video) - Audio-reactive generation
- M2V Engine (Motion-to-Video) - Motion capture to video
- R2V Engine (Reference-to-Video) - Style transfer

### 3. Morphing Filter System
**Minimal's Approach:** 50+ filter modes with smooth morphing between types (classic, vowel, comb, formant)

**Echoelmusic Implementation:**
```python
class VideoMorphFilter:
    """Morph between video styles/effects smoothly"""
    modes = [
        "cinematic", "anime", "realistic", "artistic",
        "documentary", "music_video", "abstract", "nature"
    ]

    def morph(self, style_a: str, style_b: str, amount: float):
        """Interpolate between two visual styles"""
        pass
```

### 4. Intelligent Randomization
**Minimal's Approach:** 400+ presets with intelligent random variations

**Echoelmusic Ideas:**
- `SmartRandomizer` - Generate variations of successful prompts
- Style DNA extraction from reference videos
- Controlled chaos parameters (0-100% randomness)
- Seed-based reproducible randomization

### 5. Warp Effects System
**Minimal's Approach:** 40+ warp effects for wavetable transformation

**Video Warp Equivalents:**
- Temporal Warp (time-stretch, reverse, loop)
- Spatial Warp (zoom, pan, rotate, perspective)
- Color Warp (palette shift, gradient mapping)
- Motion Warp (speed curves, motion blur, stabilization)
- Style Warp (cross-style interpolation)

### 6. Modulation Matrix
**Minimal's Approach:** Drag-and-drop modulation with unlimited connections, visual feedback

**Echoelmusic Modulation Ideas:**
- Audio → Video parameter mapping (beat → zoom, bass → color)
- LFO-style automated parameter changes
- Envelope followers for dynamic effects
- Cross-parameter linking (brightness ↔ motion speed)

### 7. Arpeggiator & Sequencer
**Minimal's Approach:** 40+ melodic/rhythmic modes, chord presets

**Video Sequence Ideas:**
- Shot sequencer with transitions
- Beat-synced cut patterns
- Preset transition rhythms (4-bar, 8-bar patterns)
- Chord-like multi-layer compositions

---

## Implementation Priority

### Phase 1: Core Enhancements
1. ✅ I2V Engine (Completed)
2. ⏳ StreamBrowser for cloud presets
3. ⏳ Style Morphing system

### Phase 2: Advanced Features
4. Audio-reactive generation (S2V)
5. Modulation matrix for video parameters
6. Smart Randomizer

### Phase 3: Pro Features
7. Motion capture to video (M2V)
8. Full warp effects suite
9. Video sequencer with transitions

---

## Technical Notes

### Style Morphing Architecture
```
User selects: Style A (Cinematic) → Style B (Anime)
Morph Amount: 0.0 ───────────────────── 1.0
                 ↓
Interpolated prompt embedding
                 ↓
Blended generation parameters
                 ↓
Smooth visual transition
```

### Audio-Reactive Pipeline
```
Audio Input → Beat Detection → Parameter Mapping
     ↓              ↓                 ↓
 FFT Analysis   Transients      Video Controls
     ↓              ↓                 ↓
 Spectrum      Beat Sync       Motion/Color/Zoom
```

---

## References

- [Minimal Audio Current](https://www.minimal.audio/products/current) - Flagship synth inspiration
- [Minimal Audio Rift](https://www.minimal.audio/products/rift) - Effects architecture
- [Sound On Sound Review](https://www.soundonsound.com/reviews/minimal-audio-current)
- [CDM Current Overview](https://cdm.link/minimal-audio-current-synth/)
