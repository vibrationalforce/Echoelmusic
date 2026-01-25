# DSP Module

EchoelCore - Pure Native DSP framework. 100% Swift/Kotlin with zero external dependencies.

## Philosophy

*"breath → sound → light → consciousness"*

EchoelCore provides professional-grade audio processing without JUCE or any external dependencies. Everything is implemented natively using Apple's Accelerate framework for SIMD optimization.

## Components

### EchoelCore
The central configuration and namespace for all DSP components.

### EchoelWarmth
Analog hardware emulations with "one knob to rule them all":

| Legend | Inspiration | Vibe |
|--------|-------------|------|
| SSL Glue | SSL 4000G Bus Compressor | Punchy. Glue. Modern. |
| API Punch | API 2500 | Thrust. Power. Drums. |
| Neve Magic | Neve 1073/33609 | Silk. Warmth. Magic. |
| Pultec Silk | Pultec EQP-1A | Air. Bottom. Classic. |
| Fairchild Dream | Fairchild 670 | Smooth. Vintage. Rare. |
| LA-2A Love | Teletronix LA-2A | Vocals. Bass. Butter. |
| 1176 Bite | UREI 1176 | Fast. Aggressive. Bite. |
| Manley Velvet | Manley Vari-Mu | Master. Tube. Velvet. |

### EchoelVibe
Creative effects suite:

- **ThePunisher** - Saturation that goes to 11 (with THE BUTTON)
- **TheTimeMachine** - Delay with character (tape, analog, lo-fi)
- **TheVoiceChanger** - Formant/pitch shifting with robot mode

### EchoelSeed
Genetic/organic synthesis (Synplant-inspired):

- **SoundDNA** - 16 harmonic genes defining a voice
- `plantSeed()` - Create random sound
- `mutate(chaos:)` - Evolve the sound
- `breed(with:)` - Combine two sounds

### EchoelPulse
Bio-reactive audio processing:

- Heart rate → Filter brightness
- HRV → Reverb amount
- Coherence → Warmth/saturation
- Breathing → Delay time & volume envelope

### ClassicAnalogEmulations
Detailed recreations of vintage hardware:

- SSL 4000G VCA Bus Compressor
- API 2500 Bus Compressor
- Pultec EQP-1A Passive EQ
- Fairchild 670 Variable-Mu Limiter
- Teletronix LA-2A Optical Compressor
- UREI 1176 FET Limiter
- Manley Vari-Mu Mastering Compressor

### NeveInspiredDSP
Neve-inspired processing:

- Transformer saturation (MBT)
- Inductor EQ (1073-style)
- Feedback compressor (33609-style)
- Silk circuit emulation

### AdvancedDSPEffects
Professional effects suite:

- 32-band parametric EQ
- Multiband dynamics
- Convolution reverb
- Granular delay
- Spectral processing

## Usage

```swift
// Create a console with one knob
let console = EchoelWarmth.TheConsole()
console.legend = .neve
console.vibe = 60.0  // 0-100

// Process audio
let output = console.process(inputBuffer)
```

## Performance

All DSP uses Apple's Accelerate framework for SIMD optimization:
- vDSP for signal processing
- vImage for 2D operations
- BNNS for neural network inference

Typical latency: <1.3ms at 64 samples/48kHz

## Platform Support

- iOS 17+
- macOS 14+
- watchOS 10+
- tvOS 17+
- visionOS 1+
