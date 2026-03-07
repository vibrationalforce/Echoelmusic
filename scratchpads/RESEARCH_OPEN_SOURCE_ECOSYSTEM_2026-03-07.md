# Open-Source Ecosystem Research for Echoelmusic

**Date:** 2026-03-07
**Purpose:** Comprehensive survey of open-source repositories that bring Echoelmusic to its full potential
**Scope:** 100+ repositories across 6 domains, 5 parallel research agents

---

## Table of Contents

1. [Audio & DSP](#1-audio--dsp)
2. [Biofeedback & Health](#2-biofeedback--health)
3. [Visuals, Metal & Lighting](#3-visuals-metal--lighting)
4. [Networking, MIDI & AI](#4-networking-midi--ai)
5. [Build Tools & CI/CD](#5-build-tools--cicd)
6. [Integration Priority Matrix](#6-integration-priority-matrix)
7. [License Safety Guide](#7-license-safety-guide)
8. [Identified Gaps](#8-identified-gaps)

---

## 1. Audio & DSP

### 1.1 DDSP (Differentiable Digital Signal Processing)

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [magenta/ddsp](https://github.com/magenta/ddsp) | ~8,000 | Python | Apache 2.0 | **EchoelDDSP** -- Harmonic additive + subtractive noise synth. Trained models exportable to CoreML. Archived early 2025 but code/models remain. |
| [yxlllc/DDSP-SVC](https://github.com/yxlllc/DDSP-SVC) | ~2,000 | Python | MIT | **EchoelAI** -- Real-time singing voice conversion via DDSP. Low hardware requirements. Timbre transfer. |
| [acids-ircam/RAVE](https://github.com/acids-ircam/RAVE) | ~2,000+ | Python | Academic | **EchoelAI** -- Realtime Audio Variational autoEncoder, 20-80x real-time on CPU. BRAVE variant achieves sub-10ms. Neural timbre transfer. |

### 1.2 Audio Synthesis Libraries

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [AudioKit/AudioKit](https://github.com/AudioKit/AudioKit) | 11,283 | Swift | MIT | **All audio** -- Most comprehensive Swift-native audio platform. Reference architecture for Swift audio engine patterns. |
| [AudioKit/SoundpipeAudioKit](https://github.com/AudioKit/SoundpipeAudioKit) | 143 | Swift | MIT | **EchoelSynth/FX** -- C-based instruments and effects. Algorithm reference. |
| [AudioKit/Tonic](https://github.com/AudioKit/Tonic) | 200 | Swift | MIT | **EchoelSeq** -- Swift music theory library (scales, chords). |
| [surge-synthesizer/surge](https://github.com/surge-synthesizer/surge) | 3,600 | C++ | GPL-3.0 | **Study only** -- 12 oscillator algorithms, wavetable, FM, physical modeling, MPE, spectral morphing. |
| [Torsion-Audio/Scyclone](https://github.com/Torsion-Audio/Scyclone) | ~500 | C++ | Check | **EchoelSynth** -- Real-time neural timbre transfer plugin built on RAVE. |

### 1.3 Audio Effects & Analog Modeling

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [airwindows/airwindows](https://github.com/airwindows/airwindows) | ~3,000+ | C++ | **MIT** | **EchoelFX** -- Hundreds of boutique effects: console emulations (Neve/SSL), saturation, EQ, compression, reverbs. Closest open-source to analog modeling. Directly adaptable. |
| [Chowdhury-DSP/chowdsp_wdf](https://github.com/Chowdhury-DSP/chowdsp_wdf) | ~500+ | C++ | **BSD-3** | **EchoelFX** -- Header-only Wave Digital Filter library for real-time analog circuit modeling. SIMD-optimized. Most rigorous open-source Neve/SSL path. |
| [Chowdhury-DSP/chowdsp_utils](https://github.com/Chowdhury-DSP/chowdsp_utils) | ~500+ | C++ | Per-module | **EchoelFX** -- Professional DSP: Butterworth, Chebyshev, Elliptic filters, EQ, SVF, FIR with SIMD. Usable without JUCE. |

### 1.4 Stem Separation

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [facebookresearch/demucs](https://github.com/facebookresearch/demucs) | 9,500 | Python | **MIT** | **EchoelAI** -- State-of-the-art source separation (vocals, drums, bass, other). Hybrid Transformer, 9.0 dB SDR. htdemucs v4 convertible to CoreML. Primary candidate. |
| [sigsep/open-unmix-pytorch](https://github.com/sigsep/open-unmix-pytorch) | ~1,200 | Python | MIT/CC | **EchoelAI** -- Simpler LSTM separation. Easier CoreML conversion. Lighter-weight for on-device. |

### 1.5 Beat / BPM Detection

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [michaelkrzyzaniak/Beat-and-Tempo-Tracking](https://github.com/michaelkrzyzaniak/Beat-and-Tempo-Tracking) | ~200 | ANSI C | Check | **BPMGridEditEngine** -- Real-time causal beat/tempo tracker. Pure C, zero deps. |
| [introlab/MusicBeatDetector](https://github.com/introlab/MusicBeatDetector) | ~100 | C++ | Check | **EchoelSeq** -- Simple feed-audio-get-BPM API. |

### 1.6 Audio Analysis (Pitch, Onset, Spectral)

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [libAudioFlux/audioFlux](https://github.com/libAudioFlux/audioFlux) | ~2,200 | C | **MIT** | **EchoelBio** -- 8 pitch algorithms (YIN, CEP, PEF, NCF, HPS, LHS, STFT, FFP), onset detection, HPSS. C bridges to Swift. |
| [sevagh/pitch-detection](https://github.com/sevagh/pitch-detection) | ~500 | C++ | **MIT** | **EchoelBio** -- O(NlogN) autocorrelation pitch detection. Clean C++. |
| [vadymmarkov/Beethoven](https://github.com/vadymmarkov/Beethoven) | ~800 | Swift | **MIT** | **EchoelBio** -- Native Swift pitch detection for iOS. |
| [cycfi/q](https://github.com/cycfi/q) | ~1,000+ | C++ | **MIT** | **EchoelBio/MIDI** -- Real-time pitch, onset, audio-to-MIDI. Clean C++17. |
| [aubio/aubio](https://github.com/aubio/aubio) | ~3,500 | C | GPL-3.0 | **Reference only** -- Standard pitch/onset/beat library. Algorithms well-documented for reimplementation. |
| [MTG/essentia](https://github.com/MTG/essentia) | ~3,000+ | C++ | AGPL-3.0 | **Reference only** -- Comprehensive spectral/temporal/tonal analysis. |

### 1.7 Real-Time Audio Engines

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [micknoise/Maximilian](https://github.com/micknoise/Maximilian) | ~1,500 | C++ | **MIT** | **Reference** -- Self-contained DSP: synthesis, sampling, filtering, FFT, granular. Zero deps. |
| [spotify/NFDriver](https://github.com/spotify/NFDriver) | ~200 | C++ | **Apache 2.0** | **Android** -- Cross-platform low-latency audio driver by Spotify. Callback-based. |

### 1.8 DSP Resources

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [olilarkin/awesome-musicdsp](https://github.com/olilarkin/awesome-musicdsp) | ~5,000+ | List | -- | Curated music DSP resources by iPlug2 author. |
| [Jounce/Surge](https://github.com/Jounce/Surge) | 5,299 | Swift | **MIT** | **EchoelCore** -- Swift wrapper around Accelerate for matrix math, DSP. |
| [ShoYamanishi/AppleNumericalComputing](https://github.com/ShoYamanishi/AppleNumericalComputing) | ~200 | Swift/C++ | **MIT** | **EchoelCore** -- Benchmarks comparing vDSP, BLAS, NEON, Metal on Apple Silicon. Optimize 120Hz bio loop. |

### 1.9 Plugin Framework

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [iPlug2/iPlug2](https://github.com/iPlug2/iPlug2) | 2,100 | C++ | zlib (permissive) | **Desktop plugins** -- Already in tech stack. CLAP, VST2/3, AUv2/3, AAX, WASM. |

---

## 2. Biofeedback & Health

### 2.1 HRV Analysis

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [neuropsychology/NeuroKit](https://github.com/neuropsychology/NeuroKit) | ~2,100 | Python | **MIT** | **CoherenceCore** -- RMSSD, SDNN, LF/HF, pNN50, SampEn, DFA + respiratory analysis. Port algorithms to C++/Swift. |
| [PGomes92/pyhrv](https://github.com/PGomes92/pyhrv) | ~300+ | Python | **BSD-3** | **CoherenceCore** -- 78 HRV parameters. Developed at UAS Hamburg. |
| [paulvangentcom/heartrate_analysis_python](https://github.com/paulvangentcom/heartrate_analysis_python) | ~1,100 | Python | GPL-3.0 | **Reference only** -- Noisy PPG handling. |

### 2.2 EEG Processing

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [brainflow-dev/brainflow](https://github.com/brainflow-dev/brainflow) | ~1,600 | C/C++ | **MIT** | **EchoelBio** -- Most important bio repo. Uniform API for Muse, OpenBCI, NeuroSky. Band power extraction (delta/theta/alpha/beta/gamma). Maps to `/echoelmusic/bio/eeg/{band}` OSC. C++ core matches architecture. |
| [mne-tools/mne-python](https://github.com/mne-tools/mne-python) | ~3,200 | Python | **BSD-3** | **CoherenceCore** -- Scientific gold standard. Welch PSD, multitaper, ICA. Reference for spectral algorithms. |
| [braindecode/braindecode](https://github.com/braindecode/braindecode) | ~800+ | Python | **BSD-3** | **EchoelAI** -- EEGNet/ShallowConvNet convertible to CoreML for on-device EEG classification. |

### 2.3 BLE Health Device SDKs

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [polarofficial/polar-ble-sdk](https://github.com/polarofficial/polar-ble-sdk) | ~500+ | Swift/Kotlin | Proprietary | **EchoelBio** -- SPM integration. HR, RR intervals, ECG 130Hz, accel from Polar H10. Review commercial terms. |
| [NordicSemiconductor/IOS-BLE-Library](https://github.com/NordicSemiconductor/IOS-BLE-Library) | ~200+ | Swift | **BSD-3** | **EchoelBio** -- Clean CoreBluetooth wrapper with mock testing. BLE GATT HR Service (0x180D). |

### 2.4 ARKit Face Tracking

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [johnjcsmith/iPhoneMoCapiOS](https://github.com/johnjcsmith/iPhoneMoCapiOS) | moderate | Swift | open | **EchoelBio** -- Streams 52 blendshapes via UDP. Direct reference for facial-expression-to-music pipeline. |

### 2.5 Breathing Detection

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [neuropsychology/NeuroKit](https://github.com/neuropsychology/NeuroKit) | ~2,100 | Python | **MIT** | **EchoelBio** -- RSP peak/trough detection, rate, amplitude, RRV. Maps to DDSP breath phase/depth. |
| [peterhcharlton/RRest](https://github.com/peterhcharlton/RRest) | ~100+ | MATLAB/Python | open | **EchoelBio** -- ECG-derived respiration. Respiratory rate from HR sensor alone (no breathing sensor needed). |

### 2.6 Signal Deconvolution

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [ime-luebeck/ecg-removal](https://github.com/ime-luebeck/ecg-removal) | moderate | Python | open | **BioSignalDeconvolver** -- Closest match. Extended Kalman Filter + template subtraction for cardiac/respiratory separation. |
| [hooman650/BioSigKit](https://github.com/hooman650/BioSigKit) | moderate | MATLAB | open | **BioSignalDeconvolver** -- RLS adaptive filtering, Pan-Tompkins, wavelet R-peak detection. |

### 2.7 HealthKit & Wearable Integration

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [kvs-coder/HealthKitReporter](https://github.com/kvs-coder/HealthKitReporter) | ~100+ | Swift | **MIT** | **UnifiedHealthKitEngine** -- Codable HealthKit wrappers, JSON export, SPM. |
| [carekit-apple/CareKit](https://github.com/carekit-apple/CareKit) | ~2,400+ | Swift | **BSD-3** | **EchoelBio** -- Apple's health data persistence patterns. |
| [memsindustrygroup/Open-Source-Sensor-Fusion](https://github.com/memsindustrygroup/Open-Source-Sensor-Fusion) | moderate | C | open | **EchoelBio** -- Kalman + complementary filters. Fuse Apple Watch (4-5s latency), Polar H10 (real-time), ARKit (60fps), EEG (250Hz) into 120Hz BioSnapshot. |

### 2.8 OpenBCI

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [OpenBCI/OpenBCI_GUI](https://github.com/OpenBCI/OpenBCI_GUI) | ~600+ | Java | **MIT** | **EchoelVis** -- Real-time FFT, band power, EEG visualization. Reference for EEG display modes. |
| BrainFlow (above) | | | | Recommended integration path for all OpenBCI hardware. |

---

## 3. Visuals, Metal & Lighting

### 3.1 Metal Shader Libraries

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [Hi-Rez/Satin](https://github.com/Hi-Rez/Satin) | ~830 | Swift/C | **MIT** | **EchoelVis** -- 3D Metal framework (Three.js-inspired). Meshes, materials, compute kernels, PBR. SPM. Reference architecture for Metal rendering pipeline. |
| [yukiny0811/swifty-creatives](https://github.com/yukiny0811/swifty-creatives) | ~100+ | Swift | **MIT** | **EchoelVis** -- Processing-inspired Metal creative coding. visionOS support. SPM. |
| [ConfettiFX/The-Forge](https://github.com/ConfettiFX/The-Forge) | ~4,500+ | C/C++ | **Apache 2.0** | **Reference** -- Cross-platform rendering (Metal 2, Vulkan, DX12). Production-proven. |

### 3.2 Projection Mapping

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [paperManu/splash](https://github.com/paperManu/splash) | ~500+ | C++ | GPL-3.0 | **EchoelStage** -- Multi-projector video-mapping. Study warping, blending, calibration. Reference only. |
| [mapmapteam/mapmap](https://github.com/mapmapteam/mapmap) | ~300+ | C++/Qt | GPL-3.0 | **EchoelStage** -- Surface mapping UI patterns. Reference only. |

### 3.3 DMX / Art-Net

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [MillerTechnologyPeru/ArtNet](https://github.com/MillerTechnologyPeru/ArtNet) | -- | Swift | **MIT** | **EchoelLux** -- Pure Swift Art-Net library. SPM. Primary Swift Art-Net candidate. Directly usable. |
| [OpenLightingProject/ola](https://github.com/OpenLightingProject/ola) | 548 | C++ | LGPL-2.1+ | **EchoelLux** -- Industry-standard DMX framework. Art-Net, sACN, USB adapters, RDM. Client lib LGPL. |
| [OpenLightingProject/libartnet](https://github.com/OpenLightingProject/libartnet) | -- | C | LGPL | **EchoelLux** -- Standalone C Art-Net. Bridgeable to Swift. |
| [wled/WLED](https://github.com/wled/WLED) | 17,636 | C++ | EUPL-1.2 | **EchoelLux** -- De facto LED control standard. 100+ effects, Art-Net + sACN receiver. Target as endpoint device. |

### 3.4 sACN / E1.31

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [ETCLabs/sACN](https://github.com/ETCLabs/sACN) | -- | C/C++ | **Apache 2.0** | **EchoelLux** -- Official ETC sACN implementation (ANSI E1.31-2018). Production quality. Bridge to Swift. |
| [hhromic/libe131](https://github.com/hhromic/libe131) | -- | C/C++ | **MIT** | **EchoelLux** -- Lightweight E1.31. Simpler, good for embedding. |

### 3.5 Laser Control

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [brendan-w/lzr](https://github.com/brendan-w/lzr) | -- | C++17 | LGPL | **EchoelLux** -- ILDA reader/writer, frame interpolator/optimizer. Study galvo optimization. |
| [Grix/helios_dac](https://github.com/Grix/helios_dac) | -- | C/C++ | SDK OK | **EchoelLux** -- Open-source USB DAC for ILDA laser projectors. C-style exports. |

### 3.6 Smart Home Lighting

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [jnewc/Hue](https://github.com/jnewc/Hue) | -- | Swift | **MIT** | **EchoelLux** -- Philips Hue client using Combine. Aligns with Echoelmusic's Combine architecture. |
| [openhue/openhue-api](https://github.com/openhue/openhue-api) | -- | OpenAPI | **Apache 2.0** | **EchoelLux** -- OpenAPI spec for Hue CLIP API. Auto-generate Swift client. |

### 3.7 Video Processing

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [MetalPetal/MetalPetal](https://github.com/MetalPetal/MetalPetal) | ~2,100 | ObjC/Swift | **MIT** | **EchoelVid** -- GPU-accelerated image/video on Metal. Type-safe filter pipeline. SPM. Active (v1.25.2, Feb 2026). Top recommendation. |
| [BradLarson/GPUImage3](https://github.com/BradLarson/GPUImage3) | ~2,900 | Swift | **BSD** | **EchoelVid** -- Metal video processing. Clean pipeline architecture (sources -> filters -> outputs). |
| [BBMetalImage](https://github.com/Silence-GitHub/BBMetalImage) | -- | Swift | **MIT** | **EchoelVid** -- High-perf Metal image/video. Low CPU usage. |

### 3.8 Generative Visuals / Particles

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [FlexMonkey/ParticleLab](https://github.com/FlexMonkey/ParticleLab) | -- | Swift | open | **EchoelVis** -- Metal compute shader, 4M particles at 40fps+ with gravity wells. Add bio-signal inputs for bio-reactive particles. |
| [FlexMonkey/ParticleCam](https://github.com/FlexMonkey/ParticleCam) | -- | Swift | open | **EchoelVis** -- Camera luminosity drives particles via Metal compute. Swap luminosity for bio-signal coherence/HRV. |

### 3.9 Hilbert Curve

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [proxpero/Hilbert](https://github.com/proxpero/Hilbert) | -- | Swift | open | **HilbertSensorMapper** -- Swift `HilbertCurve` struct, 1D-to-2D mapping. Conforms to `Collection`. Direct match. |
| [adishavit/hilbert](https://github.com/adishavit/hilbert) | -- | C++ | open | **HilbertSensorMapper** -- Fast non-recursive multi-dimensional Hilbert. No precomputed tables. 120Hz capable. |
| [jakubcerveny/gilbert](https://github.com/jakubcerveny/gilbert) | -- | Multi | **BSD-2** | **HilbertSensorMapper** -- Generalized for arbitrary (non-power-of-two) rectangles. Critical for arbitrary sensor arrays. |

### 3.10 AirPlay / External Display

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [heestand-xyz/AirKit](https://github.com/heestand-xyz/AirKit) | -- | Swift | **MIT** | **EchoelStage** -- SwiftUI AirPlay via `.airPlay()` modifier. Modern SwiftUI approach. |

### 3.11 Creative Coding Frameworks

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [openframeworks/openFrameworks](https://github.com/openframeworks/openFrameworks) | 10,328 | C++ | **MIT** | **Reference** -- Canonical creative coding toolkit. iOS support. Algorithm inspiration. |
| [processing/p5.js](https://github.com/processing/p5.js) | ~22,000+ | JS | LGPL-2.1 | **Reference** -- Audio-visualization patterns for EchoelVis. |
| [cables-gl](https://github.com/cables-gl) | 502 | JS/WebGL | **MIT** | **Reference** -- Node-based visual programming. Study node/cable UI for effect routing. |

---

## 4. Networking, MIDI & AI

### 4.1 OSC (Open Sound Control)

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [orchetect/OSCKit](https://github.com/orchetect/OSCKit) | ~120 | Swift | **MIT** | **EchoelSync** -- 684 commits, 33 releases, Swift 6 strict concurrency, visionOS. Same author as MIDIKit. Directly supports `/echoelmusic/bio/*` address patterns over UDP. Top pick. |
| [ExistentialAudio/SwiftOSC](https://github.com/ExistentialAudio/SwiftOSC) | ~284 | Swift | **MIT** | **EchoelSync** -- Higher stars but stale (last update Aug 2022). Reference only. |

### 4.2 Ableton Link

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [Ableton/link](https://github.com/Ableton/link) | ~840 | C++ | GPLv2+ | Official header-only library. GPL for non-iOS platforms. |
| [Ableton/LinkKit](https://github.com/Ableton/LinkKit) | -- | C++ | Proprietary (free) | Required for iOS App Store. Must accept Ableton license. |
| [fwcd/swift-link](https://github.com/fwcd/swift-link) | ~30 | Swift | **MIT** (wrapper) | **EchoelNet** -- Swift-native API. Uses LinkKit on iOS, GPL Link elsewhere. Cleanest path. |

### 4.3 MIDI 2.0 / MPE

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [orchetect/MIDIKit](https://github.com/orchetect/MIDIKit) | ~320 | Swift | **MIT** | **EchoelMIDI** -- MIDI 1.0 + 2.0 + MPE. 1,583 commits, 85 releases, Swift 6. Zero deps, wraps CoreMIDI. Top pick overall. |
| [starfishmod/MIDI2_CPP](https://github.com/starfishmod/MIDI2_CPP) | ~100 | C++ | **MIT** | **C++ layer** -- MIDI 2.0 UMP for cross-platform parsing. |
| [mixedinkey-opensource/MIKMIDI](https://github.com/mixedinkey-opensource/MIKMIDI) | ~1,100 | ObjC/Swift | **MIT** | **EchoelSeq** -- Sequencing, recording, MIDI mapping. ObjC-based, MIDI 1.0 only. Architectural reference. |

### 4.4 Dante / AES67

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [teodly/inferno](https://github.com/teodly/inferno) | ~200 | Rust | **MIT** | **EchoelNet** -- Only open-source Dante implementation. Reverse-engineered protocol, PTPv1/v2. Protocol reference. |
| [bondagit/aes67-linux-daemon](https://github.com/bondagit/aes67-linux-daemon) | ~300 | C++ | GPL | **Reference** -- Production AES67 on Linux. |
| [philhartung/aes67-monitor](https://github.com/philhartung/aes67-monitor) | ~50 | Node.js | **MIT** | **EchoelNet** -- AES67/RAVENNA stream monitoring. Auto-detection via SAP. |

### 4.5 WebRTC for Audio

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [GetStream/stream-video-swift-webrtc](https://github.com/AIO-2024/stream-video-swift-webrtc) | ~200 | Swift | **BSD** | **EchoelNet** -- Pre-built WebRTC XCFramework as SPM. No C++ build chain. Easiest iOS integration. |

### 4.6 CoreML Models for Music

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [FluidInference/FluidAudio](https://github.com/FluidInference/FluidAudio) | ~50 | Swift | **MIT** | **EchoelAI** -- CoreML: TTS, STT, VAD, speaker diarization. Apple Neural Engine. |
| [likedan/Awesome-CoreML-Models](https://github.com/likedan/Awesome-CoreML-Models) | ~6,500 | List | MIT | Discovery index for music/audio CoreML models. |

### 4.7 Music Generation AI

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [facebookresearch/audiocraft](https://github.com/facebookresearch/audiocraft) | ~22,000+ | Python | MIT code / **CC-BY-NC weights** | **EchoelAI** -- Text-to-music (MusicGen). 300M model fits mobile. Weights non-commercial. |
| [haoheliu/AudioLDM2](https://github.com/haoheliu/AudioLDM2) | ~2,500 | Python | **MIT** | **EchoelAI** -- Diffusion text-to-audio/music. 48kHz. Unified speech/sound/music. |
| [Stability-AI/stable-audio-tools](https://github.com/Stability-AI/stable-audio-tools) | ~1,800+ | Python | **MIT** | **EchoelAI** -- Audio generation toolkit. Open weights for some models. |
| [riffusion/riffusion-hobby](https://github.com/riffusion/riffusion-hobby) | ~3,875 | Python | MIT/CreativeML | **EchoelAI** -- Spectrogram generation via Stable Diffusion. Aligns with EchoelVis spectral approach. |

### 4.8 Whisper / Speech

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [argmaxinc/WhisperKit](https://github.com/argmaxinc/WhisperKit) | ~5,000 | Swift | **MIT** | **EchoelAI** -- Pure Swift, CoreML/ANE optimized, streaming mic. Real-time factor <0.2 on iPhone. Voice commands + lyric transcription. Top pick. |
| [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) | ~37,000+ | C/C++ | **MIT** | **Cross-platform** -- Universal Whisper port. SPM available. Metal GPU. Android/Linux fallback. |

### 4.9 LLM On-Device

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [ml-explore/mlx-swift](https://github.com/ml-explore/mlx-swift) | ~2,443 | Swift | **MIT** | **EchoelAI** -- Apple's ML framework Swift API. LLM/VLM. WWDC 2025 featured. Powers creative assistance. Top pick for Apple. |
| [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) | ~75,000+ | C/C++ | **MIT** | **Cross-platform** -- Universal LLM inference. GGUF format. SPM available. Broader model compatibility. |
| [ml-explore/mlx](https://github.com/ml-explore/mlx) | ~19,000+ | C++/Python | **MIT** | **EchoelAI** -- Apple's ML framework. Unified memory, Metal GPU. Strategic Apple investment. |

### 4.10 Music Information Retrieval

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [dhrebeniuk/RosaKit](https://github.com/dhrebeniuk/RosaKit) | ~30 | Swift | **MIT** | **EchoelVis** -- Swift librosa port. Mel-spectrogram, STFT. Quick integration for spectrogram rendering. |

### 4.11 Cloud Sync / CRDTs

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [heckj/CRDT](https://github.com/heckj/CRDT) | ~196 | Swift | **MIT** | **EchoelNet** -- Pure Swift CRDTs: GCounter, PNCounter, GSet, ORSet, ORMap, List. Delta-state. Sendable. Session state sync across devices. |
| [automerge/automerge](https://github.com/automerge/automerge) | ~4,000+ | Rust/JS | **MIT** | **EchoelNet** -- Industry-standard CRDT. Rust core with Swift bindings. Complex document collaboration. |

### 4.12 Ableton / DAW Integration

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [ideoforms/AbletonOSC](https://github.com/ideoforms/AbletonOSC) | ~500+ | Python | **MIT** | **EchoelWorks** -- OSC control of Ableton Live: tracks, clips, devices, transport. Bio-reactive data flows via `/echoelmusic/` into Live parameters. |

### 4.13 Network Audio

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [CESNET/UltraGrid](https://github.com/CESNET/UltraGrid) | ~600 | C/C++ | **BSD** | **EchoelNet** -- Professional low-latency A/V streaming. ~100ms e2e. Adaptable code. |
| [jamulussoftware/jamulus](https://github.com/jamulussoftware/jamulus) | ~4,000+ | C++ | GPL | **Reference** -- Internet jamming standard. OPUS + UDP + server mixing. Architecture reference. |

### 4.14 Music Notation & MIDI Files

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [dn-m/MusicXML](https://github.com/dn-m/MusicXML) | ~77 | Swift | **MIT** | **EchoelTools** -- Pure Swift MusicXML parser/writer. SPM. Richly-typed Codable. |
| [matsune/MidiParser](https://github.com/matsune/MidiParser) | ~100 | Swift | **MIT** | **EchoelSeq** -- Swift MIDI file read/write. Clean API. |

---

## 5. Build Tools & CI/CD

### 5.1 Already In Use

| Tool | Stars | License | Status |
|------|------:|---------|--------|
| [tuist/tuist](https://github.com/tuist/tuist) | 5,568 | MIT | In use. Enable binary caching for `CoherenceCore` to cut CI build times. |
| [fastlane/fastlane](https://github.com/fastlane/fastlane) | 41,127 | MIT | In use. Powers TestFlight pipeline. |
| [realm/SwiftLint](https://github.com/realm/SwiftLint) | 19,487 | MIT | In use. Enable `strict: true` for Swift 6. |
| Codemagic | 443 | GPL-3.0 | In use. Cloud CI with macOS runners. |

### 5.2 Recommended Additions

| Repo | Stars | Lang | License | Echoelmusic Target |
|------|------:|------|---------|-------------------|
| [cpisciotta/xcbeautify](https://github.com/cpisciotta/xcbeautify) | 1,431 | Swift | **MIT** | **CI** -- Format xcodebuild output. GitHub Actions annotations. JUnit reports. Pre-installed on GHA runners. Zero cost. |
| [swiftlang/swift-format](https://github.com/swiftlang/swift-format) | 2,887 | Swift | **Apache 2.0** | **CI** -- Apple's official formatter. Pre-commit hook for consistent formatting. In Swift 6 toolchain. |
| [peripheryapp/periphery](https://github.com/peripheryapp/periphery) | 6,023 | Swift | **MIT** | **Code quality** -- Dead code detection. Identifies unused DSP algorithms, orphaned subscriptions. Keeps codebase lean for <200MB. |
| [ordo-one/package-benchmark](https://github.com/ordo-one/package-benchmark) | 422 | Swift | **Apache 2.0** | **Performance** -- Benchmark DSP against hard limits (<10ms latency, <30% CPU, <200MB RAM). CPU, ARC, malloc, syscalls. PR regression checks. |
| [swiftlang/swift-testing](https://github.com/swiftlang/swift-testing) | 2,112 | Swift | **Apache 2.0** | **Testing** -- Apple's macro-based testing. Parameterized tests for DSP. Parallel execution. Incremental migration from XCTest. |
| [pointfreeco/swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras) | 465 | Swift | **MIT** | **Testing** -- `withMainSerialExecutor` for deterministic async tests. Critical for 120Hz bio loop and Combine pipelines. |
| [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | 4,169 | Swift | **MIT** | **UI testing** -- Snapshot-test EchoelVis visualizations (8 modes), EchoelMix console, EchoelBio displays. |
| [cashapp/AccessibilitySnapshot](https://github.com/cashapp/AccessibilitySnapshot) | 636 | Swift | **Apache 2.0** | **A11y** -- Verify safety warnings are accessible. Bio-feedback labels for screen readers. |

---

## 6. Integration Priority Matrix

### Tier 1 -- Immediate Value (MIT/BSD, production-ready, directly usable)

| # | Repository | License | Target | Action |
|---|-----------|---------|--------|--------|
| 1 | **MIDIKit** | MIT | EchoelMIDI | MIDI 2.0 + MPE. Drop-in SPM. 85 releases. Swift 6. |
| 2 | **OSCKit** | MIT | EchoelSync | Same author as MIDIKit. Direct `/echoelmusic/bio/*` support. |
| 3 | **WhisperKit** | MIT | EchoelAI | On-device speech. CoreML/ANE. Voice commands + lyrics. |
| 4 | **MLX Swift** | MIT | EchoelAI | Apple-endorsed on-device LLM. WWDC 2025 featured. |
| 5 | **airwindows** | MIT | EchoelFX | Adapt console emulation, saturation, effects. C++ algorithms. |
| 6 | **chowdsp_wdf** | BSD-3 | EchoelFX | Header-only analog circuit modeling. Neve/SSL path. |
| 7 | **BrainFlow** | MIT | EchoelBio | C++ EEG device abstraction. Muse, OpenBCI, NeuroSky. |
| 8 | **audioFlux** | MIT | EchoelBio | C pitch/onset/HPSS. 8 pitch algorithms. Bridges to Swift. |
| 9 | **MetalPetal** | MIT | EchoelVid | GPU video processing on Metal. SPM. Active. |
| 10 | **Demucs** | MIT | EchoelAI | State-of-the-art stem separation. Convert to CoreML. |

### Tier 2 -- High Value (requires integration work)

| # | Repository | License | Target | Action |
|---|-----------|---------|--------|--------|
| 11 | **swift-link** | MIT | EchoelNet | Ableton Link tempo sync. Swift wrapper. |
| 12 | **heckj/CRDT** | MIT | EchoelNet | Cross-device session state replication. |
| 13 | **AbletonOSC** | MIT | EchoelWorks | Bidirectional Ableton Live control via OSC. |
| 14 | **MillerTechnologyPeru/ArtNet** | MIT | EchoelLux | Pure Swift Art-Net. SPM. |
| 15 | **ETCLabs/sACN** | Apache 2.0 | EchoelLux | Production sACN. Bridge to Swift via C. |
| 16 | **NeuroKit2** | MIT | CoherenceCore | Port HRV/RSP algorithms to C++/Swift. |
| 17 | **cycfi/q** | MIT | EchoelBio | C++17 pitch/onset for audio-to-MIDI. |
| 18 | **Nordic BLE Library** | BSD-3 | EchoelBio | Clean CoreBluetooth wrapper. Mock testing. |

### Tier 3 -- Algorithm Study (reimplement independently)

| # | Repository | License | Target | Action |
|---|-----------|---------|--------|--------|
| 19 | **magenta/ddsp** | Apache 2.0 | EchoelDDSP | Study harmonic+noise synth architecture. |
| 20 | **RAVE / Scyclone** | Academic | EchoelSynth | Study neural timbre transfer at sub-10ms. |
| 21 | **Surge** | GPL-3.0 | EchoelSynth | Study oscillator/spectral algorithms. |
| 22 | **aubio** | GPL-3.0 | EchoelBio | Reimplement YIN, spectral flux. |
| 23 | **essentia** | AGPL-3.0 | EchoelBio/AI | Reference MFCCs, chromagrams, rhythm. |
| 24 | **ecg-removal** | open | BioSignalDeconvolver | Study EKF + template subtraction. |

### Tier 4 -- Build & Testing Infrastructure

| # | Repository | License | Target | Action |
|---|-----------|---------|--------|--------|
| 25 | **xcbeautify** | MIT | CI | Pipe builds through for GHA annotations. Zero cost. |
| 26 | **swift-format** | Apache 2.0 | CI | Pre-commit hook. In Swift 6 toolchain. |
| 27 | **Periphery** | MIT | Code quality | Dead code sweeps. Keep codebase lean. |
| 28 | **package-benchmark** | Apache 2.0 | Performance | DSP regression testing vs hard limits. |
| 29 | **swift-concurrency-extras** | MIT | Testing | Deterministic async tests for bio loop. |
| 30 | **swift-snapshot-testing** | MIT | UI testing | Visual regression for EchoelVis/Mix/Bio. |

---

## 7. License Safety Guide

| License | Commercial Use | Repos | Action |
|---------|---------------|-------|--------|
| **MIT** | Safe, attribution only | MIDIKit, OSCKit, WhisperKit, MLX, airwindows, audioFlux, MetalPetal, Demucs, heckj/CRDT, ArtNet, xcbeautify, Periphery, etc. | Use freely |
| **BSD-2/3** | Safe, attribution | chowdsp_wdf, Nordic BLE, MNE-Python, GPUImage3, CareKit, gilbert | Use freely |
| **Apache 2.0** | Safe, patent grant | sACN, The Forge, swift-format, package-benchmark, swift-testing | Use freely |
| **LGPL** | Link OK, no modification | OLA (client lib), LZR, p5.js | Dynamic link only |
| **GPL-3.0** | Cannot link into proprietary | Surge, aubio, BrainBay, Splash, MapMap, Codemagic CLI | Study algorithms, reimplement |
| **AGPL-3.0** | Must open-source entire app | Essentia | Avoid or buy commercial license |
| **CC-BY-NC** | Non-commercial only | MusicGen weights, Riffusion model | Train custom weights for production |
| **Proprietary (free)** | Terms vary | LinkKit, Polar BLE SDK | Review commercial terms |

---

## 8. Identified Gaps

Five areas where no mature, permissively-licensed solution exists:

### Gap 1: HeartMath Coherence Protocol
No open-source implementation exists. Build from peer-reviewed literature: 0.10 Hz resonant frequency, LF/HF analysis, ~6 breaths/minute target.

### Gap 2: AES67/Dante in Swift
No native Swift implementation. Must build custom using Network.framework + PTP, with Inferno (Rust/MIT) as protocol reference.

### Gap 3: On-Device Music Generation with Open Weights
MusicGen 300M could be converted to CoreML but weights are CC-BY-NC. No MIT-licensed music generation model with production-quality open weights exists. Requires custom model training or separate licensing.

### Gap 4: Real-Time Collaborative Audio CRDTs
heckj/CRDT covers primitives but no library handles conflict-free audio session state (multi-track arrangement, automation curves). Custom CRDT types needed.

### Gap 5: DMX-512 in Swift
MillerTechnologyPeru/ArtNet covers Art-Net but no Swift library exists for raw DMX-512 over USB adapters. Build custom using IOKit or bridge OLA's C++ client.

---

## Mapping to Echoelmusic Architecture

```
EchoelCore (120Hz)
├── EchoelSynth    ← airwindows, chowdsp_wdf, magenta/ddsp, RAVE
├── EchoelMix      ← (native AVFoundation sufficient)
├── EchoelFX       ← airwindows (MIT), chowdsp_wdf (BSD-3), chowdsp_utils
├── EchoelSeq      ← MIDIKit (MIT), Tonic (MIT), MidiParser (MIT)
├── EchoelMIDI     ← MIDIKit (MIT) -- MIDI 2.0 + MPE complete solution
├── EchoelBio      ← BrainFlow (MIT), NeuroKit2 (MIT), audioFlux (MIT), Polar BLE
├── EchoelVis      ← Satin (MIT), MetalPetal (MIT), ParticleLab, Hilbert (Swift)
├── EchoelVid      ← MetalPetal (MIT), GPUImage3 (BSD)
├── EchoelLux      ← ArtNet-Swift (MIT), ETCLabs/sACN (Apache), jnewc/Hue (MIT), WLED
├── EchoelStage    ← AirKit (MIT), Splash/MapMap (study only)
├── EchoelNet      ← OSCKit (MIT), swift-link (MIT), heckj/CRDT (MIT), Inferno (MIT)
└── EchoelAI       ← WhisperKit (MIT), MLX Swift (MIT), Demucs (MIT), audioFlux (MIT)
```

---

*Research conducted 2026-03-07 via 5 parallel research agents covering Audio/DSP, Biofeedback/Health, Visuals/Lighting, Networking/AI/MIDI, and Build Tools/CI.*
