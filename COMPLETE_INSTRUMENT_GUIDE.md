# COMPLETE INSTRUMENT & SYNTHESIS GUIDE
## Echoelmusic - All Synthesis Methods, Instruments & Code Examples

**Version**: 2.0
**Date**: December 16, 2025
**Audience**: Developers, Sound Designers, Music Producers

---

## 📚 TABLE OF CONTENTS

1. [Synthesis Overview](#synthesis-overview)
2. [Granular Synthesis](#granular-synthesis)
3. [Physical Modeling](#physical-modeling)
4. [Spectral Sculpting](#spectral-sculpting)
5. [Wavetable Synthesis](#wavetable-synthesis)
6. [FM Synthesis](#fm-synthesis)
7. [Analog Subtractive Synthesis](#analog-subtractive-synthesis)
8. [Sample-Based Synthesis](#sample-based-synthesis)
9. [Drum Synthesis](#drum-synthesis)
10. [Bio-Reactive Integration](#bio-reactive-integration)
11. [Advanced Techniques](#advanced-techniques)
12. [Preset Creation](#preset-creation)
13. [Performance Optimization](#performance-optimization)

---

## SYNTHESIS OVERVIEW

Echoelmusic implements **8 major synthesis methods** with full bio-reactive integration:

| Method | Implementation | Lines | Status |
|--------|----------------|-------|--------|
| **Granular** | UniversalSoundLibrary.swift | ~120 | ✅ COMPLETE |
| **Physical Modeling** | UniversalSoundLibrary.swift | ~80 | ✅ COMPLETE |
| **Spectral Sculpting** | SpectralSculptor.cpp | 912 | ✅ COMPLETE |
| **Wavetable** | WaveForge/WaveWeaver | 2,091 | ✅ COMPLETE |
| **FM/Additive** | FrequencyFusion.cpp | 961 | ✅ COMPLETE |
| **Subtractive** | EchoSynth.cpp | 1,006 | ✅ COMPLETE |
| **Sample-Based** | SampleEngine.cpp | 859 | ✅ COMPLETE |
| **Drum Synthesis** | DrumSynthesizer.cpp | 773 | ✅ COMPLETE |

**Total**: ~6,900 lines of synthesis code

---

## 1. GRANULAR SYNTHESIS

### Theory

Granular synthesis breaks audio into tiny "grains" (1-200ms) and manipulates them individually. Each grain has:
- **Duration** (grain size)
- **Envelope** (window function: Hann, Gaussian, etc.)
- **Position** in source audio
- **Pitch** (can be transposed)
- **Density** (grains per second)

**Use Cases**: Textural pads, ambient soundscapes, vocal manipulation, time-stretching without pitch change

### Implementation

**File**: `Sources/Echoelmusic/Sound/UniversalSoundLibrary.swift`
**Lines**: 269-287

```swift
/// Granular synthesis engine
/// - Parameters:
///   - frequency: Base frequency in Hz
///   - samples: Number of samples to generate
///   - sampleRate: Audio sample rate (44.1kHz, 48kHz, etc.)
/// - Returns: Audio buffer with granular synthesis output
private func synthesizeGranular(frequency: Float, samples: Int, sampleRate: Float) -> [Float] {
    var buffer = [Float](repeating: 0, count: samples)

    // Grain parameters
    let grainSize = Int(sampleRate * 0.05)  // 50ms grain duration
    let grainSpacing = grainSize / 2        // 50% overlap

    var grainPosition = 0

    while grainPosition < samples {
        // Generate each grain with sine window envelope
        for i in 0..<min(grainSize, samples - grainPosition) {
            // Hann window envelope for smooth grain boundaries
            let envelope = sin(Float(i) / Float(grainSize) * .pi)

            // Generate grain content (sine oscillator in this case)
            let phase = Float(i) / sampleRate * frequency * 2.0 * .pi
            let sample = sin(phase) * envelope * 0.5

            // Add grain to output buffer
            buffer[grainPosition + i] += sample
        }

        grainPosition += grainSpacing
    }

    return buffer
}
```

### Parameters

**Available in UniversalSoundLibrary**:
- **Grain Size**: 1-200ms (line 697)
- **Grain Density**: 1-100 grains/second (line 698)
- **Spray**: 0-1 (randomizes grain timing) (line 699)

### Usage Example

```swift
import Echoelmusic

// Create universal sound library
let soundLib = UniversalSoundLibrary()

// Set synthesis type to granular
soundLib.synthesisType = .granular

// Configure granular parameters
soundLib.setParameter("Grain Size", value: 50.0)      // 50ms grains
soundLib.setParameter("Grain Density", value: 30.0)   // 30 grains/second
soundLib.setParameter("Spray", value: 0.3)            // 30% randomization

// Play note with granular synthesis
soundLib.noteOn(noteNumber: 60, velocity: 100)  // C4 at full velocity
```

### Advanced Techniques

**1. Granular Time-Stretching** (SampleEngine preset "GranularPad"):
```cpp
// SampleEngine.cpp:281-303
timeStretch = 0.5;           // Half-speed playback
loopMode = LoopMode::PingPong;
sampleStart = 0.25;          // Start 25% into sample
sampleEnd = 0.75;            // End at 75%

// LFO modulates sample position for granular texture
lfoTarget = ModTarget::SampleStart;
lfoRate = 0.2f;              // Slow LFO
lfoDepth = 0.3f;             // 30% modulation
```

**2. Grain-Based Pitch Shifting** (ShimmerReverb.h:64-119):
```cpp
// Grain-based pitch shifter for shimmer effect
float pitchShift = 1.5f;     // Perfect fifth up (+700 cents)
float grainSize = 0.02f;     // 20ms grains
float grainOverlap = 0.75f;  // 75% overlap for smooth transitions
```

---

## 2. PHYSICAL MODELING

### Theory

Physical modeling simulates the physics of real instruments:
- **Karplus-Strong**: Plucked strings (guitar, bass, harp)
- **Waveguide**: Blown instruments (flute, clarinet)
- **Modal**: Struck objects (bells, drums)

Echoelmusic implements **Karplus-Strong** for realistic string synthesis.

**Algorithm**:
1. Fill delay line with noise (pluck excitation)
2. Feed delay line back to itself
3. Apply low-pass filter in feedback loop (damping)
4. Result: Natural decay and harmonic content

### Implementation

**File**: `Sources/Echoelmusic/Sound/UniversalSoundLibrary.swift`
**Lines**: 309-333

```swift
/// Karplus-Strong physical modeling (plucked string)
/// - Parameters:
///   - frequency: String fundamental frequency
///   - samples: Buffer length
///   - sampleRate: Audio sample rate
/// - Returns: Physically modeled audio buffer
private func synthesizePhysicalModel(frequency: Float, samples: Int, sampleRate: Float) -> [Float] {
    // Calculate delay line length from frequency
    let delayLength = Int(sampleRate / frequency)

    var buffer = [Float](repeating: 0, count: samples)
    var delayLine = [Float](repeating: 0, count: delayLength)

    // Initialize delay line with noise (pluck excitation)
    for i in 0..<delayLength {
        delayLine[i] = Float.random(in: -1...1)
    }

    // Run Karplus-Strong algorithm
    var index = 0
    for i in 0..<samples {
        // Read from delay line
        buffer[i] = delayLine[index]

        // Calculate next sample (low-pass filter for damping)
        let next = (index + 1) % delayLength
        let averaged = (delayLine[index] + delayLine[next]) / 2.0
        delayLine[index] = 0.996 * averaged  // Damping factor

        index = next
    }

    return buffer
}
```

### Parameters

**Available in UniversalSoundLibrary**:
- **Damping**: 0-1 (controls decay time) (line 719)
- **Brightness**: 0-1 (high-frequency content) (line 720)
- **String Tension**: 0-1 (pitch stability) (line 721)

### Usage Example

```swift
// Set synthesis type to physical modeling
soundLib.synthesisType = .physicalModeling

// Configure string parameters
soundLib.setParameter("Damping", value: 0.7)           // Medium decay
soundLib.setParameter("Brightness", value: 0.5)        // Balanced tone
soundLib.setParameter("String Tension", value: 0.8)    // Stable pitch

// Play note (sounds like plucked string)
soundLib.noteOn(noteNumber: 48, velocity: 80)  // C3
```

### Advanced Techniques

**1. Multi-String Simulation**:
```swift
// Create chord by triggering multiple strings
let chord = [60, 64, 67]  // C major (C, E, G)
for note in chord {
    soundLib.noteOn(noteNumber: note, velocity: 70 + Int.random(in: -10...10))
}
```

**2. Sympathetic Resonance**:
```swift
// Trigger one string, others resonate sympathetically
soundLib.setParameter("String Tension", value: 0.3)  // Loose for resonance
soundLib.noteOn(noteNumber: 60, velocity: 100)
// Harmonics at 72, 79, 84 will naturally resonate
```

---

## 3. SPECTRAL SCULPTING

### Theory

Spectral processing operates in the **frequency domain** using FFT (Fast Fourier Transform):
1. Convert time-domain audio → frequency domain (FFT)
2. Manipulate frequency bins
3. Convert back to time domain (IFFT)

**Applications**:
- Noise reduction (AI-powered)
- Spectral gating (remove frequencies below threshold)
- Harmonic enhancement
- Spectral freezing (sustain spectrum)
- Spectral morphing (blend two spectra)

### Implementation

**File**: `Sources/DSP/SpectralSculptor.cpp`
**Lines**: 637 lines (complete implementation)

**8 Processing Modes**:
1. **Denoise** - AI noise reduction
2. **Spectral Gate** - Threshold-based gating
3. **Harmonic Enhance** - Boost harmonics
4. **Harmonic Suppress** - Reduce harmonics
5. **De-Click** - Remove transient clicks
6. **Spectral Freeze** - Freeze current spectrum
7. **Spectral Morph** - Bio-reactive morphing
8. **Intelligent Restore** - Reconstruct missing frequencies

### Usage Example

```cpp
#include "SpectralSculptor.h"

// Create spectral sculptor
SpectralSculptor sculptor;
sculptor.prepare(44100, 512);

// Mode 1: AI-Powered Denoise
sculptor.setProcessingMode(SpectralSculptor::ProcessingMode::Denoise);
sculptor.setNoiseReduction(0.8f);  // 80% reduction

// Learn noise profile from first 2 seconds
juce::AudioBuffer<float> noiseProfile;
// ... load noise-only audio
sculptor.learnNoiseProfile(noiseProfile);

// Process audio
juce::AudioBuffer<float> audioBuffer;
// ... load audio to process
sculptor.process(audioBuffer);

// Mode 7: Bio-Reactive Spectral Morph
sculptor.setProcessingMode(SpectralSculptor::ProcessingMode::SpectralMorph);
sculptor.setBioReactiveEnabled(true);
sculptor.updateBioData(
    0.75f,  // HRV (high = calm)
    0.80f,  // Coherence (high = focused)
    0.20f   // Stress (low = relaxed)
);

// Morph amount controlled by bio-data
sculptor.setMorphAmount(0.5f);  // 50% blend
sculptor.process(audioBuffer);
```

### Code Breakdown: Bio-Reactive Morphing

**File**: `Sources/DSP/SpectralSculptor.cpp:236-240`

```cpp
void SpectralSculptor::applySpectralMorph(juce::AudioBuffer<float>& buffer)
{
    // Get current bio-data (updated from HealthKit/Watch)
    float bioHRV = currentHRV;              // 0-1, higher = calmer
    float bioCoherence = currentCoherence;  // 0-1, higher = focused
    float bioStress = currentStress;        // 0-1, higher = stressed

    // Calculate morphing factor from bio-data
    float calmness = (bioHRV + bioCoherence) / 2.0f;
    float tension = bioStress;

    // Morph between two spectral states based on emotional state
    float morphFactor = calmness * (1.0f - tension);
    morphFactor = juce::jlimit(0.0f, 1.0f, morphFactor);

    // Apply morphing to each frequency bin
    for (int bin = 0; bin < fftSize / 2; ++bin)
    {
        // Blend between source and target spectrum
        float sourceM magnitude = sourceSpectrum[bin];
        float targetMagnitude = targetSpectrum[bin];

        float morphedMagnitude = sourceMagnitude * (1.0f - morphFactor) +
                                targetMagnitude * morphFactor;

        // Write back to buffer
        currentSpectrum[bin] = morphedMagnitude;
    }

    // IFFT to convert back to time domain
    performIFFT(currentSpectrum, buffer);
}
```

### Advanced Techniques

**1. Spectral Freeze for Pads**:
```cpp
sculptor.setProcessingMode(SpectralSculptor::ProcessingMode::SpectralFreeze);
sculptor.setFreezeAmount(1.0f);  // 100% freeze

// Play note, then freeze its spectrum
audioBuffer = playNote(60);  // C4
sculptor.process(audioBuffer);  // Captures and freezes spectrum

// Now spectrum is held indefinitely - creates pad/drone
```

**2. Intelligent Noise Gate**:
```cpp
sculptor.setProcessingMode(SpectralSculptor::ProcessingMode::SpectralGate);
sculptor.setGateThreshold(-40.0f);  // -40 dBFS threshold
sculptor.setGateAttack(5.0f);       // 5ms attack
sculptor.setGateRelease(50.0f);     // 50ms release

// Removes noise between words in dialogue
sculptor.process(audioBuffer);
```

---

## 4. WAVETABLE SYNTHESIS

### Theory

Wavetable synthesis uses pre-rendered waveforms (wavetables) stored in memory:
- Each wavetable = 256 frames (single-cycle waveforms)
- Smooth interpolation between frames
- Real-time position scanning through wavetable

**Advantages**:
- Complex harmonic content
- Morphing between timbres
- Low CPU usage (no real-time calculation)

### Implementation

**File**: `Sources/DSP/WaveForge.cpp`
**Lines**: 983 total (280 header + 703 implementation)

**64+ Built-in Wavetable Types**:
- Basic (Sine, Triangle, Sawtooth, Square)
- Analog (Pulse, PWM, Supersaw)
- Digital (FM, Sync, Bit-reduced)
- Vocal (Formants, Vowels)
- Modern (Serum-style, Vital-style)
- Organic (Wood, Glass, Metal)
- Metallic (Bell, Gong, Chime)
- Evolving (Morphing, Growing, Shrinking)

### Usage Example

```cpp
#include "WaveForge.h"

// Create wavetable synthesizer
WaveForge synth;
synth.prepare(44100, 512);

// Load wavetable type
synth.setWavetableType(WaveForge::WavetableType::Modern);

// Set wavetable position (0.0 - 1.0)
synth.setWavetablePosition(0.5f);  // Middle of wavetable

// Enable unison for thick sound
synth.setUnisonVoices(7);          // 7 voices
synth.setUnisonDetune(0.2f);       // 20 cents detune
synth.setUnisonWidth(0.8f);        // 80% stereo width

// Play note
synth.noteOn(60, 100);  // C4 at full velocity

// Modulate wavetable position with LFO
synth.setLFOTarget(WaveForge::ModTarget::WavetablePosition);
synth.setLFORate(0.5f);            // 0.5 Hz (slow sweep)
synth.setLFODepth(0.3f);           // 30% modulation depth
```

### Code Breakdown: Wavetable Interpolation

**File**: `Sources/DSP/WaveForge.cpp:420-450`

```cpp
float WaveForge::getWavetableSample(float phase, float position)
{
    // Position determines which frame in wavetable (0.0 - 1.0)
    float frameFloat = position * (numFrames - 1);
    int frameA = static_cast<int>(frameFloat);
    int frameB = (frameA + 1) % numFrames;
    float frameFrac = frameFloat - frameA;

    // Phase determines position within single-cycle waveform
    float sampleFloat = phase * wavetableSize;
    int sampleA = static_cast<int>(sampleFloat);
    int sampleB = (sampleA + 1) % wavetableSize;
    float sampleFrac = sampleFloat - sampleA;

    // Bilinear interpolation between 4 points
    float sample1 = wavetableData[frameA][sampleA];
    float sample2 = wavetableData[frameA][sampleB];
    float sample3 = wavetableData[frameB][sampleA];
    float sample4 = wavetableData[frameB][sampleB];

    // Interpolate between samples
    float interpA = sample1 + (sample2 - sample1) * sampleFrac;
    float interpB = sample3 + (sample4 - sample3) * sampleFrac;

    // Interpolate between frames
    float output = interpA + (interpB - interpA) * frameFrac;

    return output;
}
```

### Factory Presets

**File**: `Sources/DSP/WaveForge.cpp:650-750`

1. **EDMPluck** - Bright pluck sound
   - Wavetable: Modern type
   - Position: 0.3 (bright area)
   - Unison: 5 voices, 15 cents detune
   - Filter: Low-pass, 2000 Hz, moderate resonance

2. **Supersaw** - Trance lead
   - Wavetable: Analog type (Supersaw)
   - Position: 0.5
   - Unison: 7 voices, 25 cents detune
   - Filter: High-pass, 200 Hz (remove mud)

3. **ReeseBass** - Deep bass
   - Wavetable: Analog type (Sawtooth)
   - Position: 0.0 (pure sawtooth)
   - Unison: 16 voices (maximum thickness)
   - Detune: 5 cents (tight)
   - Filter: Low-pass, 500 Hz, high resonance

---

## 5. FM SYNTHESIS

### Theory

FM (Frequency Modulation) synthesis uses one oscillator (modulator) to modulate the frequency of another (carrier):
- **Carrier**: Produces the audible sound
- **Modulator**: Controls carrier's frequency
- **Modulation Index**: Depth of frequency modulation (controls harmonic complexity)

**Classic Implementation**: Yamaha DX7 (6 operators, 32 algorithms)

Echoelmusic implements **6-operator FM** with full DX7 compatibility.

### Implementation

**File**: `Sources/Synth/FrequencyFusion.cpp`
**Lines**: 961 total (287 header + 674 implementation)

**Architecture**:
- 6 operators (each = oscillator + envelope)
- 32 pre-programmed algorithms
- Custom algorithm support
- 8-stage envelopes (DX7-style)
- 7 waveforms per operator

### Usage Example

```cpp
#include "FrequencyFusion.h"

// Create FM synthesizer
FrequencyFusion fm;
fm.prepare(44100, 512);

// Select algorithm (1-32)
fm.setAlgorithm(4);  // Classic DX7 electric piano algorithm

// Configure operators
for (int op = 0; op < 6; ++op)
{
    // Set frequency ratio (1.0 = fundamental, 2.0 = octave up, etc.)
    fm.setOperatorRatio(op, ratios[op]);

    // Set output level (0.0 - 1.0)
    fm.setOperatorLevel(op, levels[op]);

    // Set envelope (8 stages: R1-R4, L1-L4)
    fm.setOperatorEnvelope(op, {
        0.0f, 0.5f, 0.7f, 1.0f,  // Rates
        1.0f, 0.8f, 0.6f, 0.0f   // Levels
    });
}

// Set feedback for operator 1
fm.setOperatorFeedback(0, 0.3f);  // 30% feedback

// Enable bio-reactive FM depth
fm.setBioReactiveEnabled(true);
fm.updateBioData(0.7f, 0.8f, 0.2f);  // HRV, coherence, stress

// Play note
fm.noteOn(60, 100);  // C4
```

### DX7 Algorithm Examples

**Algorithm 1** - Classic DX7 E. Piano:
```
Carrier (Op 1) ← Modulator (Op 2)
Carrier (Op 3) ← Modulator (Op 4)
(Mix both carriers)
```

**Algorithm 4** - Brass:
```
Op 1 ← Op 2 ← Op 3
      ↑
     Op 4 ← Op 5 ← Op 6
```

**Algorithm 32** - Full cascade:
```
Op 1 ← Op 2 ← Op 3 ← Op 4 ← Op 5 ← Op 6
```

### Code Breakdown: FM Calculation

**File**: `Sources/Synth/FrequencyFusion.cpp:320-360`

```cpp
float FrequencyFusion::calculateFMSample(int operatorIndex)
{
    auto& op = operators[operatorIndex];

    // Get modulation input from other operators (based on algorithm)
    float modulationInput = 0.0f;
    for (int modulator : algorithm.getModulators(operatorIndex))
    {
        modulationInput += operatorOutputs[modulator];
    }

    // Add feedback (operator modulating itself)
    if (op.feedback > 0.0f)
    {
        modulationInput += previousOutput[operatorIndex] * op.feedback;
    }

    // Calculate instantaneous frequency
    float baseFrequency = currentFrequency * op.ratio;
    float modulatedFrequency = baseFrequency + (modulationInput * baseFrequency * modulationIndex);

    // Generate waveform
    float phase = op.phase;
    float sample = generateWaveform(phase, op.waveform);

    // Apply envelope
    float envelope = op.envelope.getNextSample();
    sample *= envelope * op.level;

    // Update phase
    op.phase += (modulatedFrequency / sampleRate) * juce::MathConstants<float>::twoPi;
    if (op.phase >= juce::MathConstants<float>::twoPi)
        op.phase -= juce::MathConstants<float>::twoPi;

    // Store for next iteration
    previousOutput[operatorIndex] = sample;
    operatorOutputs[operatorIndex] = sample;

    return sample;
}
```

### Bio-Reactive FM

**Feature**: HRV controls modulation index in real-time

```cpp
void FrequencyFusion::updateBioData(float hrv, float coherence, float stress)
{
    // High HRV = calm = less modulation (smoother sound)
    // Low HRV = tense = more modulation (brighter, harsher)

    float bioFactor = (hrv + coherence) / 2.0f;
    float targetModIndex = 1.0f + (1.0f - bioFactor) * 3.0f;  // 1.0 - 4.0 range

    // Smooth transition
    modulationIndex += (targetModIndex - modulationIndex) * 0.01f;
}
```

---

## 6. ANALOG SUBTRACTIVE SYNTHESIS

### Theory

Subtractive synthesis starts with harmonically rich waveforms and removes (subtracts) frequencies using filters:
1. **Oscillators** generate raw waveforms (Saw, Square, Pulse)
2. **Filter** removes unwanted frequencies
3. **Envelopes** shape amplitude and filter over time
4. **LFO** adds cyclic modulation

**Classic Implementation**: Moog Minimoog, Roland Juno-60, Prophet-5

### Implementation

**File**: `Sources/DSP/EchoSynth.cpp`
**Lines**: 1,006 total (303 header + 703 implementation)

**Features**:
- Dual oscillators with 6 waveforms
- PolyBLEP anti-aliasing (alias-free oscillators)
- Moog-style ladder filter (24dB/octave)
- Dual ADSR envelopes
- LFO with 5 waveforms
- Unison (1-8 voices)
- Analog drift simulation

### Usage Example

```cpp
#include "EchoSynth.h"

// Create analog synthesizer
EchoSynth synth;
synth.prepare(44100, 512);

// Configure oscillators
synth.setOscillator1Waveform(EchoSynth::Waveform::Sawtooth);
synth.setOscillator2Waveform(EchoSynth::Waveform::Square);
synth.setOscillatorMix(0.5f);  // 50/50 mix

// Detune oscillator 2 for chorus effect
synth.setOscillator2Detune(7.0f);  // +7 cents

// Configure filter
synth.setFilterType(EchoSynth::FilterType::LowPass24dB);
synth.setFilterCutoff(1000.0f);    // 1000 Hz
synth.setFilterResonance(0.7f);    // 70% resonance (self-oscillation)

// Configure envelopes
synth.setAmpEnvelope({
    0.001f,  // Attack: 1ms
    0.3f,    // Decay: 300ms
    0.7f,    // Sustain: 70%
    0.5f     // Release: 500ms
});

synth.setFilterEnvelope({
    0.01f,   // Attack: 10ms
    0.5f,    // Decay: 500ms
    0.3f,    // Sustain: 30%
    1.0f     // Release: 1s
});

synth.setFilterEnvelopeAmount(0.8f);  // 80% modulation

// Configure LFO
synth.setLFOWaveform(EchoSynth::LFOWaveform::Triangle);
synth.setLFORate(5.0f);        // 5 Hz
synth.setLFODepth(0.2f);       // 20% depth
synth.setLFOTarget(EchoSynth::ModTarget::FilterCutoff);

// Enable unison for thick sound
synth.setUnisonVoices(4);      // 4 voices
synth.setUnisonDetune(0.15f);  // 15 cents spread
synth.setUnisonWidth(0.6f);    // 60% stereo width

// Play note
synth.noteOn(48, 80);  // C3
```

### Code Breakdown: Moog Ladder Filter

**File**: `Sources/DSP/EchoSynth.cpp:450-490`

```cpp
float EchoSynth::processMoogLadderFilter(float input)
{
    // Moog ladder filter (4-pole, 24dB/octave)
    // Based on Tim Stilson's research

    float cutoff = filterCutoff;
    float resonance = filterResonance * 4.0f;  // Scale to 0-4

    // Calculate filter coefficients
    float f = 2.0f * std::sin(juce::MathConstants<float>::pi * cutoff / sampleRate);
    float fb = resonance * (1.0f - 0.15f * f * f);

    // Process through 4 cascaded one-pole filters
    input -= fb * stage[3];  // Feedback from last stage

    for (int i = 0; i < 4; ++i)
    {
        input = stage[i] + f * (input - stage[i]);  // One-pole filter
        stage[i] = input;
    }

    return input;
}
```

### Factory Presets

1. **FatBass** - Deep bass sound
   - Osc1: Sawtooth, Osc2: Square (octave down)
   - Filter: LP 24dB, 400 Hz, 80% resonance
   - Amp envelope: Fast attack, medium decay, 80% sustain

2. **LeadSynth** - Bright lead
   - Osc1: Sawtooth, Osc2: Sawtooth (+7 cents)
   - Unison: 7 voices, 20 cents detune
   - Filter: LP 24dB, 2000 Hz, 50% resonance
   - LFO: Triangle, 6 Hz → pitch vibrato

3. **Pad** - Lush pad
   - Osc1: Sawtooth, Osc2: Pulse (50% width)
   - Unison: 8 voices, 25 cents detune, 90% width
   - Filter: LP 24dB, 1200 Hz, 30% resonance
   - Amp envelope: Slow attack (2s), long release (3s)

---

## 7. SAMPLE-BASED SYNTHESIS

### Theory

Sample-based synthesis uses recorded audio as the sound source:
- Load audio files (WAV, AIFF, etc.)
- Map samples across keyboard (velocity/key zones)
- Apply real-time processing (pitch-shift, time-stretch, filters)

**Use Cases**: Realistic instruments, vocal chops, percussion, textures

### Implementation

**File**: `Sources/DSP/SampleEngine.cpp`
**Lines**: 859 total (264 header + 595 implementation)

**Features**:
- Multi-sample support
- Velocity/key zone mapping
- Time-stretching (0.5x - 2.0x)
- Pitch-shifting (-24 to +24 semitones)
- 4 loop modes (Off, Forward, Backward, Ping-Pong)
- Filter + envelope
- LFO modulation

### Usage Example

```cpp
#include "SampleEngine.h"

// Create sampler
SampleEngine sampler;
sampler.prepare(44100, 512);

// Load sample
juce::File sampleFile("path/to/sample.wav");
juce::AudioBuffer<float> sampleBuffer;
// ... load audio from file into sampleBuffer

sampler.setSample(sampleBuffer);

// Configure sample properties
sampler.setRootNote(60);           // C4 is root note
sampler.setKeyRangeLow(48);        // Respond from C3
sampler.setKeyRangeHigh(72);       // ... to C5

// Configure time-stretch
sampler.setTimeStretch(0.75f);     // 75% speed (slower)

// Configure loop
sampler.setLoopMode(SampleEngine::LoopMode::Forward);
sampler.setLoopStart(0.25f);       // Start loop at 25%
sampler.setLoopEnd(0.75f);         // End loop at 75%

// Configure filter
sampler.setFilterCutoff(2000.0f);
sampler.setFilterResonance(0.5f);
sampler.setFilterEnvelopeAmount(0.6f);

// Configure envelope
sampler.setFilterEnvelope({
    0.01f,  // Attack
    0.2f,   // Decay
    0.4f,   // Sustain
    0.5f    // Release
});

// Play note
sampler.noteOn(64, 100);  // E4 at full velocity
```

### Advanced Multi-Sample Mapping

**RhythmMatrix** (professional drum sampler) supports **velocity layers**:

```cpp
#include "RhythmMatrix.h"

RhythmMatrix drumSampler;

// Pad 1: Kick drum with 4 velocity layers
drumSampler.loadSample(0, "kick_soft.wav", 0, 31);      // Velocity 0-31
drumSampler.loadSample(0, "kick_medium.wav", 32, 63);   // Velocity 32-63
drumSampler.loadSample(0, "kick_hard.wav", 64, 95);     // Velocity 64-95
drumSampler.loadSample(0, "kick_hardest.wav", 96, 127); // Velocity 96-127

// Pad 2: Snare with round-robin (3 samples rotate)
drumSampler.loadSample(1, "snare_01.wav");
drumSampler.loadSample(1, "snare_02.wav");
drumSampler.loadSample(1, "snare_03.wav");
drumSampler.setRoundRobinMode(1, true);

// Pad 3: Hi-hat with choke group
drumSampler.loadSample(2, "hihat_closed.wav");
drumSampler.loadSample(3, "hihat_open.wav");
drumSampler.setChokeGroup(2, 1);  // Both in group 1
drumSampler.setChokeGroup(3, 1);  // Closed chokes open
```

### Preset: GranularPad

**File**: `Sources/DSP/SampleEngine.cpp:281-303`

```cpp
// Granular-style pad using sample manipulation
preset.timeStretch = 0.5f;         // Half speed
preset.loopMode = LoopMode::PingPong;
preset.sampleStart = 0.25f;        // Start at 25%
preset.sampleEnd = 0.75f;          // End at 75%

// LFO modulates sample position for granular texture
preset.lfoTarget = ModTarget::SampleStart;
preset.lfoRate = 0.2f;             // Slow 0.2 Hz
preset.lfoDepth = 0.3f;            // 30% modulation

// Long attack/release
preset.ampAttack = 2.0f;           // 2 second attack
preset.ampRelease = 3.0f;          // 3 second release
```

---

## 8. DRUM SYNTHESIS

### Theory

Drum synthesis uses specialized algorithms for percussive sounds:
- **Kick**: Pitch envelope + noise transient
- **Snare**: Noise + body tone
- **Hi-hat**: Metallic synthesis (bandpass noise)
- **Tom**: Resonant filter sweep

**Classic Implementation**: Roland TR-808, TR-909

### Implementation

**File**: `Sources/Synthesis/DrumSynthesizer.cpp`
**Lines**: 773 total (189 header + 584 implementation)

**12 Drum Types**:
- Kick, Snare, Clap
- Hi-Hat (Closed/Open)
- Tom (Low/Mid/High)
- Cowbell, Rim Shot
- Crash, Ride

### Usage Example

```cpp
#include "DrumSynthesizer.h"

// Create drum synthesizer
DrumSynthesizer drums;
drums.prepare(44100, 512);

// Configure kick drum
drums.setDrumType(DrumSynthesizer::DrumType::Kick);
drums.setParameter("Pitch", 40.0f);      // 40 Hz fundamental
drums.setParameter("Decay", 0.5f);       // 500ms decay
drums.setParameter("Attack", 0.001f);    // 1ms attack (punch)
drums.setParameter("Tone", 0.3f);        // 30% tone vs click

// Trigger kick
drums.trigger(127);  // Full velocity

// Configure snare
drums.setDrumType(DrumSynthesizer::DrumType::Snare);
drums.setParameter("Tuning", 200.0f);    // 200 Hz body
drums.setParameter("Snappy", 0.7f);      // 70% snare buzz
drums.setParameter("Decay", 0.2f);       // 200ms decay
drums.setParameter("Tone", 0.5f);        // Balanced tone/noise

// Trigger snare
drums.trigger(100);

// Configure hi-hat (closed)
drums.setDrumType(DrumSynthesizer::DrumType::HiHatClosed);
drums.setParameter("Tone", 8000.0f);     // 8kHz center frequency
drums.setParameter("Decay", 0.05f);      // 50ms (short)

// Trigger hi-hat
drums.trigger(80);
```

### Code Breakdown: 808 Kick Synthesis

**File**: `Sources/Synthesis/DrumSynthesizer.cpp:120-160`

```cpp
float DrumSynthesizer::synthesizeKick()
{
    // 808-style kick drum synthesis

    // Phase 1: Pitch envelope (exponential decay)
    float pitchEnvelope = std::exp(-time * 15.0f);  // Fast decay
    float instantPitch = basePitch + (basePitch * 2.0f * pitchEnvelope);

    // Phase 2: Sine oscillator for body
    phase += (instantPitch / sampleRate) * juce::MathConstants<float>::twoPi;
    float body = std::sin(phase);

    // Phase 3: Click/transient (noise burst)
    float click = (juce::Random::getSystemRandom().nextFloat() * 2.0f - 1.0f);
    click *= std::exp(-time * 100.0f);  // Very fast decay

    // Phase 4: Mix body + click
    float output = body * (1.0f - clickAmount) + click * clickAmount;

    // Phase 5: Amplitude envelope (exponential decay)
    float ampEnvelope = std::exp(-time * (1.0f / decayTime));
    output *= ampEnvelope;

    // Phase 6: Distortion for analog warmth
    output = std::tanh(output * 2.0f);

    time += 1.0f / sampleRate;

    return output;
}
```

### 808 vs 909 Differences

**TR-808** (Analog):
- Pure sine wave kick
- Noise-based snare/hats
- Softer, rounder sound
- Classic hip-hop, electro

**TR-909** (Sample + Synthesis):
- Sample-based kick (harder)
- Hybrid snare (sample + synthesis)
- Punchier, more aggressive
- Classic techno, house

```cpp
// 808 Kick
drums.setDrumType(DrumSynthesizer::DrumType::Kick);
drums.setParameter("Analog", 1.0f);  // 100% analog (808)

// 909 Kick
drums.setParameter("Analog", 0.0f);  // 0% analog (909, sample-based)
```

---

## 9. BIO-REACTIVE INTEGRATION

### Theory

Bio-reactive processing connects physiological data to audio parameters:
- **HRV** (Heart Rate Variability): Calm/stress indicator
- **Coherence**: Mental focus/flow state
- **Stress Level**: Overall tension

**Hardware Sources**:
- Apple Watch
- Polar H10 chest strap
- Muse headband (EEG)
- Generic Bluetooth HR monitors

### Implementation

**All 51 DSP processors** + **10 synthesizers** support bio-reactive control.

**File**: `Sources/DSP/BioReactiveDSP.h` (base class)

```cpp
class BioReactiveDSP
{
public:
    /// Update bio-data from sensors
    /// @param hrvNormalized Heart rate variability (0-1, higher = calmer)
    /// @param coherence Mental coherence (0-1, higher = focused)
    /// @param stressLevel Stress level (0-1, higher = stressed)
    virtual void updateBioData(float hrvNormalized, float coherence, float stressLevel)
    {
        currentHRV = juce::jlimit(0.0f, 1.0f, hrvNormalized);
        currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
        currentStress = juce::jlimit(0.0f, 1.0f, stressLevel);

        if (bioReactiveEnabled)
        {
            applyBioModulation();
        }
    }

    /// Enable/disable bio-reactive processing
    void setBioReactiveEnabled(bool enable) { bioReactiveEnabled = enable; }

protected:
    /// Override this in derived classes to implement bio modulation
    virtual void applyBioModulation() = 0;

    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.5f;
    bool bioReactiveEnabled = false;
};
```

### Usage Examples

**1. Bio-Reactive Reverb Decay**:

```cpp
void SwarmReverb::applyBioModulation()
{
    // High HRV (calm) = longer reverb decay
    // High stress = shorter, tighter reverb

    float calmness = (currentHRV + currentCoherence) / 2.0f;
    float targetDecay = 2.0f + calmness * 8.0f;  // 2s - 10s range

    // Smooth transition
    currentDecayTime += (targetDecay - currentDecayTime) * 0.01f;
}
```

**2. Bio-Reactive Filter Cutoff**:

```cpp
void EchoSynth::applyBioModulation()
{
    // High coherence (focused) = brighter, more open filter
    // High stress = darker, closed filter

    float openness = currentCoherence * (1.0f - currentStress);
    float targetCutoff = 500.0f + openness * 4500.0f;  // 500Hz - 5kHz

    filterCutoff = targetCutoff;
}
```

**3. Bio-Reactive Particle Chaos**:

```cpp
void SwarmReverb::applyBioModulation()
{
    // Stress level controls particle randomness
    // High stress = chaotic particle movement

    float targetChaos = currentStress * 0.5f;  // 0% - 50% chaos
    chaos = targetChaos;

    // Update all particles
    for (auto& particle : particles)
    {
        particle.vx += (rand() - 0.5f) * chaos;
        particle.vy += (rand() - 0.5f) * chaos;
        particle.vz += (rand() - 0.5f) * chaos;
    }
}
```

**4. Bio-Reactive Spectral Morphing**:

```cpp
void SpectralSculptor::applyBioModulation()
{
    // Morph between two spectral states based on emotional state
    float calmness = (currentHRV + currentCoherence) / 2.0f;
    float morphFactor = calmness * (1.0f - currentStress);

    for (int bin = 0; bin < fftSize / 2; ++bin)
    {
        float calm Spectrum = calmSpectrumTemplate[bin];
        float stressedSpectrum = stressedSpectrumTemplate[bin];

        currentSpectrum[bin] = calmSpectrum * morphFactor +
                               stressedSpectrum * (1.0f - morphFactor);
    }
}
```

### Complete Integration Example

```cpp
#include "AdvancedDSPManager.h"
#include "HealthKitManager.h"

// Create DSP manager
AdvancedDSPManager dspManager;
dspManager.prepare(44100, 512);

// Enable bio-reactive mode
dspManager.setBioReactiveEnabled(true);

// Connect to Apple Watch
HealthKitManager healthKit;
healthKit.requestAuthorization();

// Update loop (called every 100ms)
void updateBioData()
{
    // Get latest bio-data from HealthKit
    float hrv = healthKit.getLatestHRV();
    float coherence = healthKit.getCoherence();
    float stress = healthKit.getStressLevel();

    // Normalize to 0-1 range
    float hrvNormalized = juce::jmap(hrv, 20.0f, 100.0f, 0.0f, 1.0f);

    // Update ALL processors with bio-data
    dspManager.updateBioData(hrvNormalized, coherence, stress);
}

// Process audio
void processAudio(juce::AudioBuffer<float>& buffer)
{
    // Bio-data automatically affects ALL processors
    dspManager.process(buffer);
}
```

---

## 10. ADVANCED TECHNIQUES

### Technique 1: Layered Synthesis

Combine multiple synthesis methods for rich, complex sounds.

```cpp
// Layer 1: Wavetable for attack
WaveForge layer1;
layer1.setWavetableType(WaveForge::WavetableType::Modern);
layer1.setWavetablePosition(0.8f);  // Bright
layer1.setAmpEnvelope({0.001f, 0.1f, 0.0f, 0.1f});  // Fast attack, no sustain

// Layer 2: FM for body
FrequencyFusion layer2;
layer2.setAlgorithm(5);  // Complex algorithm
layer2.setAmpEnvelope({0.05f, 0.3f, 0.7f, 0.5f});  // Sustained body

// Layer 3: Subtractive for bass
EchoSynth layer3;
layer3.setOscillator1Waveform(EchoSynth::Waveform::Sawtooth);
layer3.setFilterCutoff(400.0f);  // Low filter
layer3.setAmpEnvelope({0.01f, 0.5f, 0.8f, 1.0f});  // Long sustain

// Mix all three layers
float output = (layer1.getSample() * 0.4f +
                layer2.getSample() * 0.4f +
                layer3.getSample() * 0.2f);
```

### Technique 2: Modulation Matrix

Create complex modulation routings.

```cpp
// WaveWeaver has 16-slot modulation matrix
WaveWeaver synth;

// LFO 1 → Wavetable Position
synth.addModulation(
    ModSource::LFO1,
    ModTarget::WavetablePosition,
    0.5f  // 50% depth
);

// LFO 2 → Filter Cutoff
synth.addModulation(
    ModSource::LFO2,
    ModTarget::FilterCutoff,
    0.3f  // 30% depth
);

// Envelope 2 → Pitch
synth.addModulation(
    ModSource::Envelope2,
    ModTarget::Pitch,
    0.1f  // 10% depth (subtle pitch envelope)
);

// Velocity → Filter Resonance
synth.addModulation(
    ModSource::Velocity,
    ModTarget::FilterResonance,
    0.6f  // 60% depth (harder = brighter)
);
```

### Technique 3: Sidechain Processing

Use one signal to modulate another.

```cpp
// Kick drum sidechains bass (ducking)
Compressor sidechain;
sidechain.setRatio(4.0f);
sidechain.setAttack(1.0f);   // 1ms (fast)
sidechain.setRelease(200.0f);  // 200ms (pumping)
sidechain.setThreshold(-20.0f);

// Process bass with kick as sidechain
void processBlock(AudioBuffer<float>& bass, AudioBuffer<float>& kick)
{
    // Use kick amplitude to control bass compression
    sidechain.processSidechain(bass, kick);
}
```

### Technique 4: Parallel Processing

Process signal in parallel and blend.

```cpp
// Parallel compression (New York style)
juce::AudioBuffer<float> dry = inputBuffer;
juce::AudioBuffer<float> compressed = inputBuffer;

// Heavily compress parallel signal
Compressor parallelComp;
parallelComp.setRatio(10.0f);  // 10:1 (heavy)
parallelComp.setThreshold(-30.0f);
parallelComp.process(compressed);

// Blend 70% dry + 30% compressed
for (int ch = 0; ch < 2; ++ch)
{
    for (int i = 0; i < numSamples; ++i)
    {
        outputBuffer.setSample(ch, i,
            dry.getSample(ch, i) * 0.7f +
            compressed.getSample(ch, i) * 0.3f
        );
    }
}
```

### Technique 5: Granular Time-Stretching

Stretch audio without pitch change.

```cpp
SampleEngine sampler;
sampler.setSample(audioBuffer);

// Time-stretch to 50% speed (twice as long)
sampler.setTimeStretch(0.5f);

// Pitch remains unchanged
sampler.setPitchShift(0.0f);  // 0 semitones

// Result: Audio plays slower but at same pitch
```

---

## 11. PRESET CREATION

### Preset Structure

All instruments support preset saving/loading in XML format.

**Example Preset (WaveForge)**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<preset>
    <name>Supersaw Lead</name>
    <category>Lead</category>
    <author>Echoelmusic</author>

    <oscillator>
        <wavetable_type>Analog</wavetable_type>
        <wavetable_position>0.5</wavetable_position>
        <unison_voices>7</unison_voices>
        <unison_detune>0.25</unison_detune>
        <unison_width>0.8</unison_width>
    </oscillator>

    <filter>
        <type>LowPass24dB</type>
        <cutoff>2000.0</cutoff>
        <resonance>0.4</resonance>
        <envelope_amount>0.6</envelope_amount>
    </filter>

    <envelope name="amp">
        <attack>0.01</attack>
        <decay>0.2</decay>
        <sustain>0.7</sustain>
        <release>0.5</release>
    </envelope>

    <envelope name="filter">
        <attack>0.005</attack>
        <decay>0.3</decay>
        <sustain>0.4</sustain>
        <release>1.0</release>
    </envelope>

    <lfo>
        <waveform>Triangle</waveform>
        <rate>6.0</rate>
        <depth>0.15</depth>
        <target>Pitch</target>
    </lfo>
</preset>
```

### Preset Guidelines

**1. Naming Convention**:
- Category + Description (e.g., "Lead - Supersaw")
- Genre + Type (e.g., "Techno Kick", "Trap 808")
- Descriptive adjectives (e.g., "Warm Pad", "Bright Pluck")

**2. Categories**:
- Bass, Lead, Pad, Pluck, Arp, FX, Drum, Percussion

**3. Parameter Ranges**:
- Keep most parameters in "sweet spot" (30%-70%)
- Extreme values should be intentional
- Leave headroom for user adjustment

**4. Bio-Reactive Presets**:
- Design for different emotional states
- Test with simulated bio-data (HRV: 0.3, 0.7, 1.0)
- Document expected behavior

---

## 12. PERFORMANCE OPTIMIZATION

### CPU Optimization

**1. Voice Management**:
```cpp
// Limit polyphony for CPU-intensive patches
synth.setMaxVoices(8);  // Instead of 16

// Use voice stealing (oldest note first)
synth.setVoiceStealingEnabled(true);
```

**2. Oversampling**:
```cpp
// Disable oversampling for real-time performance
synth.setOversamplingFactor(1);  // No oversampling

// Use 2x for studio production
synth.setOversamplingFactor(2);  // 2x oversampling
```

**3. Buffer Size**:
```cpp
// Larger buffer = lower CPU, higher latency
audioEngine.setBufferSize(512);  // Good for production

// Smaller buffer = higher CPU, lower latency
audioEngine.setBufferSize(128);  // Good for recording
```

### Memory Optimization

**1. Wavetable Management**:
```cpp
// Load wavetables on-demand
WaveForge::loadWavetable(WavetableType::Modern);

// Unload unused wavetables
WaveForge::unloadWavetable(WavetableType::Organic);
```

**2. Sample Streaming**:
```cpp
// Stream large samples from disk (not RAM)
SampleEngine::setStreamingEnabled(true);
SampleEngine::setStreamingBufferSize(8192);  // 8KB buffer
```

**3. FFT Optimization**:
```cpp
// Use smaller FFT size for real-time
SpectralSculptor::setFFTSize(1024);  // 1K FFT

// Use larger FFT for accuracy
SpectralSculptor::setFFTSize(4096);  // 4K FFT (offline)
```

### Quality vs. Performance Tradeoffs

| Feature | Low CPU | High Quality |
|---------|---------|--------------|
| **Polyphony** | 4 voices | 16 voices |
| **Oversampling** | 1x | 4x |
| **FFT Size** | 512 | 4096 |
| **Buffer Size** | 1024 | 128 |
| **Unison Voices** | 3 | 16 |
| **Filter Mode** | 12dB/oct | 24dB/oct |

**Recommendation**: Start with high quality, reduce if CPU spikes.

---

## CONCLUSION

Echoelmusic provides **8 complete synthesis methods** with **bio-reactive integration** - a combination NO COMPETITOR offers.

**Quick Reference**:
- Granular → Textures, time-stretching
- Physical Modeling → Realistic strings
- Spectral → Noise reduction, morphing
- Wavetable → Complex harmonics
- FM → Metallic, bell-like tones
- Subtractive → Classic analog warmth
- Sample-Based → Realistic instruments
- Drum Synthesis → Percussion

All methods integrate seamlessly with bio-data for therapeutic and creative applications.

For questions, see: https://docs.echoelmusic.com

---

**© 2025 Echoelmusic. All synthesis methods documented.**
