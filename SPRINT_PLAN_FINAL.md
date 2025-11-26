# 🏃 FINALER 8-WOCHEN SPRINT PLAN (iOS-FIRST + AUv3)

**Version:** FINAL (nach ULTRATHINK ANALYZER)
**Entscheidung:** iOS-FIRST mit AUv3 Extension
**Timeline:** 8 Wochen bis App Store Launch
**Target:** Ende Januar 2026

---

## 📋 FEATURE-PRIORISIERUNG (FINAL)

### **MUST-HAVE (P0 - Launch-Blocking):**
```
✅ Apple Watch HRV → Audio Modulation
✅ 46+ DSP Effects (bereits implementiert)
✅ 7 Synthesizer (bereits implementiert)
✅ Multi-Track Recording
✅ Video Export (H.264/HEVC, TikTok/Instagram Presets)
✅ AUv3 Extension (GarageBand Integration)
✅ Audio Thread Safety behoben (7 Locations)
✅ Spatial Audio (AirPods Pro/Max)
```

### **NICE-TO-HAVE (P1 - v1.1 Post-Launch):**
```
⚠️ Kamera-Biofeedback (rPPG) - Beta-Feature
⚠️ Erweiterte Gesture Control (Rotate, Pinch)
⚠️ Apple Watch Companion App
⚠️ Face Tracking → Audio Parameter Control
```

### **FUTURE (v2.0+):**
```
🔮 Desktop VST3/AU (Q2 2026)
🔮 Android App (Q4 2026)
🔮 AI Composition (Q3 2026)
🔮 Cloud Collaboration (Q4 2026)
```

---

## 🗓️ SPRINT 1: STABILITÄT (Woche 1-2)

**Ziel:** Crash-Free iOS App, Audio Thread Safety behoben
**Deliverable:** v0.8.1-beta

### **Tag 1-3: Audio Thread Safety** ⛔

#### **Task 1.1: Fix PluginProcessor.cpp** (6-8h)
```
Datei: Sources/Plugin/PluginProcessor.cpp:276,396
Problem: std::mutex in updateSpectrumData()
Lösung: juce::AbstractFifo

Checklist:
[ ] Replace spectrumMutex with AbstractFifo
[ ] Test: No dropouts during UI updates
[ ] Verify: ThreadSanitizer clean
```

#### **Task 1.2: Fix SpectralSculptor.cpp (4 Locations)** (4-6h)
```
Dateien: Sources/DSP/SpectralSculptor.cpp:90,314,320,618
Lösung: std::atomic parameters

Checklist:
[ ] Replace all 4 mutex locks
[ ] Test: Real-time parameter changes smooth
[ ] Verify: TSan clean
```

#### **Task 1.3: Fix DynamicEQ.cpp** (2-3h)
```
Datei: Sources/DSP/DynamicEQ.cpp:429
Lösung: Atomic parameters

Checklist:
[ ] Replace mutex
[ ] Test: EQ changes smooth
```

#### **Task 1.4: Fix HarmonicForge.cpp** (2-3h)
```
Datei: Sources/DSP/HarmonicForge.cpp:222
Lösung: Atomic parameters

Checklist:
[ ] Replace mutex
[ ] Test: Saturation changes smooth
```

#### **Task 1.5: Fix SpatialForge.cpp** (4-6h)
```
Datei: Sources/Audio/SpatialForge.cpp (multiple locations)
Lösung: Double-buffering für HRTF

Checklist:
[ ] Implement double-buffering
[ ] Test: Spatial position updates smooth
[ ] Verify: TSan clean
```

---

### **Tag 4-5: Memory Allocation Audit** (6-8h)

#### **Task 2.1: Audit DSP Effects**
```
Objective: Find all heap allocations in audio thread

Files to audit:
[ ] Sources/DSP/SpectralSculptor.cpp:260
[ ] Sources/DSP/ConvolutionReverb.cpp
[ ] Sources/DSP/ShimmerReverb.cpp
[ ] Sources/Synthesis/FrequencyFusion.cpp
[ ] Sources/Instrument/RhythmMatrix.cpp

Fix: Move buffers to member variables, allocate in prepareToPlay()
```

#### **Task 2.2: Audit String Operations**
```
Grep for:
[ ] std::string in processBlock()
[ ] std::cout/printf in processBlock()

Fix: Replace with atomic flags
```

---

### **Tag 6-8: iOS Performance Profiling** (6-8h)

#### **Task 3.1: Instruments Profiling**
```
Scenarios:
1. Light: 4 tracks, 5 effects → CPU < 20%
2. Medium: 8 tracks, 10 effects, biofeedback → CPU < 40%
3. Heavy: 16 tracks, 15 effects, biofeedback, spatial → CPU < 60%

Devices:
[ ] iPhone 12 (A14)
[ ] iPhone 13 Pro (A15)
[ ] iPhone 14 Pro (A16)
[ ] iPhone 15 Pro (A17)

Tools:
- Xcode Instruments: Time Profiler
- Xcode Instruments: Allocations
- Xcode Instruments: Core Audio
```

#### **Task 3.2: Audio Latency Test**
```
Measure processBlock() execution time

Targets:
- iPhone 15 Pro: < 5ms
- iPhone 14 Pro: < 7ms
- iPhone 13 Pro: < 10ms
- iPhone 12: < 12ms
```

---

### **Tag 9-10: Stability Testing** (24h + 4h)

#### **Task 4.1: 24-Hour Stress Test**
```
Setup:
- Device: iPhone 13 Pro
- Project: 8 tracks, 10 effects, biofeedback ON
- Duration: 24 hours continuous

Monitor:
[ ] CPU usage (log every 60s)
[ ] Memory usage (detect leaks)
[ ] Audio dropouts (count - should be ZERO)
[ ] Crashes (should be ZERO)

Pass Criteria:
✅ Zero crashes
✅ Zero dropouts
✅ Memory stable
✅ CPU < 50% average
```

#### **Task 4.2: iOS Watchdog Test**
```
Test background audio + biofeedback

Checklist:
[ ] Background audio continues
[ ] HealthKit HRV continues
[ ] No excessive CPU
[ ] Re-open after 30 min works
```

---

## 🗓️ SPRINT 2: BIOFEEDBACK INTEGRATION (Woche 3-4)

**Ziel:** Apple Watch HRV steuert Audio in Echtzeit
**Deliverable:** v0.9.0-beta

### **Tag 1-2: Swift → C++ Audio Bridge** (12-16h)

#### **Task 1: Create Objective-C++ Bridge**

**File 1:** `Sources/Echoelmusic/Audio/AudioEngineParameterBridge.swift`
```swift
import Foundation

@objc class AudioEngineParameterBridge: NSObject {
    @objc static let shared = AudioEngineParameterBridge()

    // Filter
    @objc func setFilterCutoff(_ frequency: Float) {
        EchoelmusicAudioEngineBridge.setFilterCutoff(frequency)
    }

    @objc func setFilterResonance(_ resonance: Float) {
        EchoelmusicAudioEngineBridge.setFilterResonance(resonance)
    }

    // Reverb
    @objc func setReverbSize(_ size: Float) {
        EchoelmusicAudioEngineBridge.setReverbSize(size)
    }

    @objc func setReverbDamping(_ damping: Float) {
        EchoelmusicAudioEngineBridge.setReverbDamping(damping)
    }

    @objc func setReverbWetMix(_ mix: Float) {
        EchoelmusicAudioEngineBridge.setReverbWetMix(mix)
    }

    // Master
    @objc func setMasterVolume(_ volume: Float) {
        EchoelmusicAudioEngineBridge.setMasterVolume(volume)
    }
}
```

**File 2:** `Sources/Echoelmusic/Audio/EchoelmusicAudioEngineBridge.h` (Objective-C)
```objc
#import <Foundation/Foundation.h>

@interface EchoelmusicAudioEngineBridge : NSObject
+ (void)setFilterCutoff:(float)frequency;
+ (void)setFilterResonance:(float)resonance;
+ (void)setReverbSize:(float)size;
+ (void)setReverbDamping:(float)damping;
+ (void)setReverbWetMix:(float)mix;
+ (void)setMasterVolume:(float)volume;
@end
```

**File 3:** `Sources/Echoelmusic/Audio/EchoelmusicAudioEngineBridge.mm` (Objective-C++)
```objc++
#import "EchoelmusicAudioEngineBridge.h"
#include "AudioEngine.h"

@implementation EchoelmusicAudioEngineBridge

+ (void)setFilterCutoff:(float)frequency {
    auto& engine = AudioEngine::getInstance();
    engine.setFilterCutoff(frequency);
}

+ (void)setFilterResonance:(float)resonance {
    auto& engine = AudioEngine::getInstance();
    engine.setFilterResonance(resonance);
}

+ (void)setReverbSize:(float)size {
    auto& engine = AudioEngine::getInstance();
    engine.setReverbSize(size);
}

// ... etc
@end
```

**Checklist:**
```
[ ] Create 3 bridge files
[ ] Add to Xcode project
[ ] Test: Swift can call C++ functions
[ ] Verify: No crashes
```

---

### **Tag 3-4: C++ AudioEngine Parameter Control** (12-16h)

#### **Task 2: Modify AudioEngine.h**

**Add methods:**
```cpp
class AudioEngine {
public:
    static AudioEngine& getInstance();

    // Thread-safe parameter setters
    void setFilterCutoff(float frequency);
    void setFilterResonance(float resonance);
    void setReverbSize(float size);
    void setReverbDamping(float damping);
    void setReverbWetMix(float mix);
    void setMasterVolume(float volume);

private:
    // Atomic parameters
    std::atomic<float> filterCutoff { 1000.0f };
    std::atomic<float> filterResonance { 1.0f };
    std::atomic<float> reverbSize { 0.5f };
    std::atomic<float> reverbDamping { 0.5f };
    std::atomic<float> reverbWetMix { 0.3f };
    std::atomic<float> masterVolume { 1.0f };

    // DSP instances
    juce::dsp::StateVariableTPTFilter<float> lowPassFilter;
    juce::Reverb reverb;
};
```

**Add implementations in AudioEngine.cpp:**
```cpp
void AudioEngine::setFilterCutoff(float frequency) {
    frequency = juce::jlimit(20.0f, 20000.0f, frequency);
    filterCutoff.store(frequency, std::memory_order_relaxed);
}

void AudioEngine::processBlock(juce::AudioBuffer<float>& buffer, ...) {
    // Read atomic values (lock-free)
    const float cutoff = filterCutoff.load(std::memory_order_relaxed);
    const float resonance = filterResonance.load(std::memory_order_relaxed);

    // Apply to DSP
    lowPassFilter.setCutoffFrequency(cutoff);
    lowPassFilter.setResonance(resonance);

    auto audioBlock = juce::dsp::AudioBlock<float>(buffer);
    auto context = juce::dsp::ProcessContextReplacing<float>(audioBlock);
    lowPassFilter.process(context);

    // ... reverb, master volume, etc.
}
```

**Checklist:**
```
[ ] Add atomic parameters to AudioEngine
[ ] Implement setter methods
[ ] Apply parameters in processBlock()
[ ] Test: Parameters change audio in real-time
[ ] Verify: No audio glitches
```

---

### **Tag 5-6: Wire UnifiedControlHub to AudioEngine** (12-16h)

#### **Task 3: Update UnifiedControlHub.swift**

**Replace TODOs with actual calls:**
```swift
private func applyBioReactiveModulation(hrv: Float, coherence: Float, heartRate: Float) {
    // Calculate modulation
    let hrvModulation = mapHRVToModulation(hrv)
    let coherenceModulation = mapCoherenceToModulation(coherence)
    let heartRateModulation = mapHeartRateToModulation(heartRate)

    // Base values
    let baseFilterCutoff: Float = 1000.0  // Hz
    let baseReverbSize: Float = 0.5
    let baseMasterVolume: Float = 1.0

    // Compute modulated values
    let filterCutoff = baseFilterCutoff * hrvModulation
    let reverbSize = baseReverbSize * coherenceModulation
    let masterVolume = baseMasterVolume * heartRateModulation

    // ✅ APPLY TO AUDIO ENGINE (NEW!)
    AudioEngineParameterBridge.shared.setFilterCutoff(filterCutoff)
    AudioEngineParameterBridge.shared.setReverbSize(reverbSize)
    AudioEngineParameterBridge.shared.setMasterVolume(masterVolume)

    print("✅ Bio-Reactive Modulation Applied:")
    print("  Filter Cutoff: \(filterCutoff) Hz")
    print("  Reverb Size: \(reverbSize)")
    print("  Master Volume: \(masterVolume)")
}
```

**Checklist:**
```
[ ] Replace all TODOs (lines 376-424)
[ ] Test with Apple Watch
[ ] Verify: HRV changes affect audio
[ ] Record demo video (for marketing)
```

---

### **Tag 7-8: Testing & Polish** (12-16h)

#### **Task 4: Apple Watch Integration Test**
```
Scenarios:
1. Deep breathing → HRV increases → Filter opens, Reverb expands
2. Exercise → Heart rate increases → Volume increases
3. Calm meditation → Coherence increases → Reverb size grows

Devices:
[ ] Apple Watch Series 8
[ ] Apple Watch Series 9
[ ] Apple Watch Ultra

Test Duration: 2h continuous per device
```

#### **Task 5: Live HRV Visualization (SwiftUI)**
```swift
struct HRVVisualizationView: View {
    @State private var hrvValue: Float = 50.0
    @State private var coherence: Float = 0.5

    var body: some View {
        VStack {
            // Real-time line chart
            LineChart(data: hrvHistory)
                .frame(height: 200)

            // Coherence gauge
            Gauge(value: coherence, in: 0...1) {
                Text("Coherence")
            }
            .gaugeStyle(.accessoryCircular)

            // Current values
            HStack {
                VStack {
                    Text("\(Int(hrvValue))")
                        .font(.largeTitle)
                    Text("HRV (ms)")
                }

                VStack {
                    Text("\(Int(coherence * 100))%")
                        .font(.largeTitle)
                    Text("Coherence")
                }
            }
        }
    }
}
```

**Checklist:**
```
[ ] Implement SwiftUI Charts
[ ] Test: Visualization updates in real-time
[ ] Polish: Colors, animations
```

---

## 🗓️ SPRINT 3: VIDEO + AUv3 (Woche 5-6)

**Ziel:** Video Export funktioniert + GarageBand Integration
**Deliverable:** v1.0-rc

### **Tag 1-3: Video Encoding** (18-24h)

#### **Task 1: VTCompressionSession Integration**

**File:** `Sources/Echoelmusic/Stream/StreamEngine.swift`

**Replace placeholder with real encoding:**
```swift
import VideoToolbox
import AVFoundation

class VideoEncoder {
    private var compressionSession: VTCompressionSession?

    func setupEncoder(width: Int, height: Int, fps: Int32) {
        var session: VTCompressionSession?

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: { _, sourceFrameRefCon, status, infoFlags, sampleBuffer in
                // Handle encoded frame
            },
            refcon: nil,
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            print("❌ Failed to create compression session")
            return
        }

        // Configure bitrate
        VTSessionSetProperty(session,
                            key: kVTCompressionPropertyKey_AverageBitRate,
                            value: 5_000_000 as CFNumber)  // 5 Mbps

        // Configure keyframe interval
        VTSessionSetProperty(session,
                            key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
                            value: 60 as CFNumber)

        compressionSession = session
    }

    func encodeFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard let session = compressionSession else { return }

        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefCon: nil,
            infoFlagsOut: nil
        )
    }
}
```

**Checklist:**
```
[ ] Implement VTCompressionSession setup
[ ] Implement frame encoding
[ ] Test: 1080p @ 30 FPS encodes smoothly
[ ] Verify: No frame drops
```

---

#### **Task 2: Audio/Video Muxing**
```swift
class VideoExporter {
    func exportVideo(videoFrames: [CVPixelBuffer],
                     audioBuffer: AVAudioPCMBuffer,
                     outputURL: URL) async throws {

        let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

        // Video track
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 1920,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 5_000_000,
                AVVideoMaxKeyFrameIntervalKey: 60
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)

        // Audio track
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192000
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)

        writer.add(videoInput)
        writer.add(audioInput)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Append frames...
    }
}
```

**Checklist:**
```
[ ] Implement AVAssetWriter
[ ] Add video + audio tracks
[ ] Test: Audio/video sync perfect
[ ] Verify: Export time < 2x real-time
```

---

### **Tag 4-6: AUv3 Extension** (18-24h)

#### **Task 3: Create AUv3 Target in Xcode**

**Steps:**
```
1. Xcode → File → New → Target
2. Select: Audio Unit Extension
3. Name: Echoelmusic AUv3
4. Bundle ID: com.echoelmusic.auv3

5. Configure Info.plist:
   - AudioComponents:
     - name: Echoelmusic
     - manufacturer: Ech0
     - type: aufx (effect) or aumu (instrument)
     - subtype: Ech1
     - version: 1
```

**Checklist:**
```
[ ] Create AUv3 target
[ ] Configure Info.plist
[ ] Share code with main app (via framework)
[ ] Build: AUv3 extension compiles
```

---

#### **Task 4: AUv3 Parameter Tree**

**File:** `Sources/Plugin/PluginProcessor.cpp`

**Add AU parameters:**
```cpp
juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout() {
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> params;

    // Filter Cutoff
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "filterCutoff",
        "Filter Cutoff",
        juce::NormalisableRange<float>(20.0f, 20000.0f, 1.0f, 0.3f),
        1000.0f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value, 0) + " Hz"; }
    ));

    // Reverb Size
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "reverbSize",
        "Reverb Size",
        0.0f, 1.0f, 0.5f
    ));

    // Master Volume
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        "masterVolume",
        "Master Volume",
        juce::NormalisableRange<float>(0.0f, 2.0f, 0.01f, 1.0f),
        1.0f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value * 100.0f, 1) + " %"; }
    ));

    return { params.begin(), params.end() };
}
```

**Checklist:**
```
[ ] Implement parameter tree
[ ] Test: Parameters show in GarageBand
[ ] Test: Automation works
[ ] Verify: Preset save/load works
```

---

#### **Task 5: Test in GarageBand, Cubasis, AUM**

**Devices:**
- iPad Pro 12.9" (2021)
- iPad Air (2022)
- iPhone 15 Pro Max

**Host Apps:**
- GarageBand (free)
- Cubasis 3 (€49.99)
- AUM (€20.99)

**Test Scenarios:**
```
GarageBand:
[ ] Load Echoelmusic AUv3 as insert effect
[ ] Parameters controllable
[ ] Audio processes correctly
[ ] No crashes

Cubasis:
[ ] Load as MIDI instrument
[ ] Multiple instances (4+)
[ ] Save/recall preset
[ ] Export mixdown

AUM:
[ ] Load in complex routing
[ ] Inter-app audio
[ ] MIDI learn
[ ] Stable for 30 min session
```

---

### **Tag 7-8: Social Media Presets** (12-16h)

#### **Task 6: Video Export Presets**

```swift
enum VideoPreset {
    case tikTok       // 1080x1920 (9:16)
    case instagram    // 1080x1080 (1:1)
    case youTube      // 1920x1080 (16:9)
    case story        // 1080x1920 (9:16)

    var resolution: (width: Int, height: Int) {
        switch self {
        case .tikTok, .story: return (1080, 1920)
        case .instagram: return (1080, 1080)
        case .youTube: return (1920, 1080)
        }
    }

    var bitrate: Int {
        switch self {
        case .tikTok: return 5_000_000   // 5 Mbps
        case .instagram: return 4_000_000
        case .youTube: return 8_000_000
        case .story: return 4_000_000
        }
    }
}

class VideoExportManager {
    func exportForSocialMedia(preset: VideoPreset,
                             visualEngine: VisualForge,
                             audioEngine: AudioEngine) async throws -> URL {
        // Configure encoder
        let (width, height) = preset.resolution
        let encoder = setupEncoder(width: width, height: height, bitrate: preset.bitrate)

        // Render + Export
        // ...
    }
}
```

**Checklist:**
```
[ ] Implement 4 presets
[ ] Test each preset
[ ] Verify: TikTok accepts file
[ ] Verify: Instagram accepts file
[ ] Test upload to each platform
```

---

## 🗓️ SPRINT 4: POLISH + LAUNCH (Woche 7-8)

**Ziel:** App Store-ready, Marketing-Kampagne
**Deliverable:** v1.0 (PUBLIC LAUNCH)

### **Tag 1-4: SwiftUI UI Polish** (24-32h)

#### **Task 1: Main Interface**
```swift
struct MainView: View {
    var body: some View {
        NavigationView {
            VStack {
                // Top: Biofeedback Status
                BiofeedbackStatusView()
                    .frame(height: 100)

                // Middle: Track List
                TrackListView()

                // Bottom: Transport Controls
                TransportControlsView()
                    .frame(height: 80)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Settings") { showSettings = true }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") { showExport = true }
                }
            }
        }
    }
}
```

**Checklist:**
```
[ ] Design main interface (Figma/Sketch)
[ ] Implement in SwiftUI
[ ] Test: All gestures work
[ ] Polish: Animations, transitions
[ ] Dark mode support
```

---

#### **Task 2: Onboarding Flow**
```swift
struct OnboardingView: View {
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            // Page 1: Welcome
            OnboardingPage(
                title: "Welcome to Echoelmusic",
                description: "The first music app that listens to your heart",
                image: "heart.fill"
            ).tag(0)

            // Page 2: Apple Watch Setup
            OnboardingPage(
                title: "Connect Your Apple Watch",
                description: "Enable HealthKit to measure HRV",
                action: { requestHealthKitPermissions() }
            ).tag(1)

            // Page 3: Camera/Microphone
            OnboardingPage(
                title: "Grant Permissions",
                description: "Camera for visuals, microphone for recording",
                action: { requestAVPermissions() }
            ).tag(2)

            // Page 4: Tutorial
            OnboardingPage(
                title: "Create Your First Track",
                description: "Tap to start tutorial",
                action: { startTutorial() }
            ).tag(3)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
```

**Checklist:**
```
[ ] Design 4 onboarding pages
[ ] Implement permission requests
[ ] Test: First-time user flow
[ ] Polish: Smooth transitions
```

---

### **Tag 5-6: App Store Preparation** (12-16h)

#### **Task 3: App Icon + Screenshots**

**App Icon:**
```
Sizes needed:
- 1024x1024 (App Store)
- 180x180 (iPhone)
- 167x167 (iPad Pro)
- 152x152 (iPad)
- 120x120 (iPhone)
- 87x87 (iPhone @3x)
- 80x80 (iPad @2x)
- 76x76 (iPad)
- 60x60 (iPhone)
- 58x58 (iPad @2x)
- 40x40 (iPad)
- 29x29 (Settings)
- 20x20 (Notifications)

Tool: Figma/Sketch → Export all sizes
```

**Screenshots:**
```
iPhone 15 Pro Max (6.7"):
1. Main interface with HRV visualization
2. Video export (TikTok preview)
3. AUv3 in GarageBand
4. Biofeedback modulation (animated)
5. Social media integration

iPad Pro 12.9":
1. Multi-track view
2. Effect chain
3. AUv3 in Cubasis

Create in: Figma with actual app screenshots + marketing overlay
```

**Checklist:**
```
[ ] Design app icon (hire designer OR use Figma)
[ ] Export all icon sizes
[ ] Capture 5 iPhone screenshots
[ ] Capture 3 iPad screenshots
[ ] Add marketing text overlay
[ ] Localize for German (optional)
```

---

#### **Task 4: App Store Listing**

**Title:** "Echoelmusic - Bio-Reactive Music"

**Subtitle:** "Your heart controls the music"

**Description:**
```
Create music with your heart! Echoelmusic is the first music production app that uses Apple Watch HRV (heart rate variability) to control audio in real-time.

UNIQUE FEATURES:
• Apple Watch HRV → Audio Modulation
• 46+ Professional DSP Effects
• 7 Synthesizers (Analog, Wavetable, FM)
• Video Export (TikTok, Instagram, YouTube)
• AUv3 Extension (works in GarageBand)
• Spatial Audio (AirPods Pro/Max)

PERFECT FOR:
• Content Creators (TikTok, Instagram)
• Music Producers (Professional DSP)
• Performers (Live biofeedback)
• Wellness (HeartMath coherence)

HOW IT WORKS:
1. Wear your Apple Watch
2. Create music with 46+ effects & 7 synths
3. Your heart rate & HRV modulate filters, reverbs, volume in real-time
4. Export audio-reactive videos for social media

SCIENTIFICALLY VALIDATED:
• HRV: Established cardiovascular metric (peer-reviewed)
• HeartMath coherence algorithm
• No pseudoscience, just real biometrics

FREE TIER:
• 3 tracks
• 10 effects
• Basic biofeedback
• 720p video export

PRO SUBSCRIPTION (€9.99/month):
• Unlimited tracks
• 46+ effects & 7 synths
• Full biofeedback
• 4K video export
• AUv3 extension
• iCloud sync

REQUIREMENTS:
• iOS 15.0+
• Apple Watch Series 6+ (for HRV)
• iPhone 12+ (recommended)
```

**Keywords:**
```
music production, biofeedback, HRV, Apple Watch, GarageBand, AUv3, TikTok, Instagram, video, effects, synthesizer, DAW, audio, wellness, HeartMath
```

**Checklist:**
```
[ ] Write app description (English)
[ ] Write app description (German)
[ ] Select 30 keywords
[ ] Choose primary category (Music)
[ ] Choose secondary category (Health & Fitness)
[ ] Set age rating (4+)
[ ] Configure in-app purchases (Pro subscription)
```

---

### **Tag 7: TestFlight Beta** (8h)

#### **Task 5: Beta Deployment**

**Steps:**
```
1. Xcode → Product → Archive
2. Organizer → Distribute App → TestFlight
3. Upload build
4. Wait for processing (2-24h)
5. Add Beta Testers
```

**Beta Testing Groups:**

**Internal (10 testers):**
- Team members
- Close friends

**External (500 testers):**
- ProductHunt "Coming Soon" subscribers
- Reddit r/iOSBeta users
- Twitter/X followers
- Discord community

**Beta Testing Notes:**
```
WHAT TO TEST:
✅ Apple Watch HRV → Audio modulation
✅ Video export (TikTok/Instagram)
✅ AUv3 in GarageBand/Cubasis
✅ Stability (no crashes)
✅ Performance (CPU, battery)

KNOWN ISSUES:
⚠️ Kamera-Biofeedback not yet implemented (v1.1)
⚠️ Desktop sync not available (Q2 2026)

FEEDBACK:
Please report bugs via TestFlight or email: [email protected]
```

**Checklist:**
```
[ ] Archive build
[ ] Upload to TestFlight
[ ] Add internal testers (10)
[ ] Add external testers (500)
[ ] Send invitation emails
[ ] Monitor crash reports (Xcode Organizer)
```

---

### **Tag 8: App Store Submission** (8h)

#### **Task 6: Submit for Review**

**Pre-Submission Checklist:**
```
App Completeness:
[ ] All features work
[ ] No crashes (< 0.1% crash rate)
[ ] No placeholder content
[ ] Privacy Policy URL
[ ] Support URL

App Store Connect:
[ ] App icon uploaded
[ ] Screenshots uploaded (iPhone + iPad)
[ ] Description written
[ ] Keywords selected
[ ] Pricing set (Freemium)
[ ] In-App Purchases configured (Pro subscription)
[ ] Age rating: 4+

Build:
[ ] Latest TestFlight build promoted
[ ] Version: 1.0
[ ] Build number: 1

Legal:
[ ] Privacy Policy (HealthKit data usage)
[ ] Terms of Service
[ ] EULA (End User License Agreement)

HealthKit Justification:
"Echoelmusic uses HealthKit to read HRV (heart rate variability) from Apple Watch. This data modulates audio parameters in real-time, creating bio-reactive music. No health data is stored or shared."

Submit for Review!
```

**Review Time:** Typically 24-48 hours

---

### **Tag 8-10: Marketing Campaign** (Parallel)

#### **Task 7: Launch Strategy**

**Day 1: ProductHunt Launch**
```
Time: 00:01 PST (maximize votes)
Title: "Echoelmusic - Music production controlled by your heartbeat"
Tagline: "The first iOS app that turns Apple Watch HRV into audio"
Description: [Copy from App Store]
Media:
  - Hero image (iPhone + Apple Watch)
  - Demo video (30s)
  - 3 GIFs (HRV modulation, video export, AUv3)

Goal: #1 Product of the Day
```

**Day 1-3: Social Media Blitz**
```
Twitter/X:
- Launch announcement
- Demo video (TikTok-style)
- Behind-the-scenes development thread

Reddit:
- r/WeAreTheMusicMakers
- r/iOSBeta
- r/AppleWatch
- r/Biohacking

Instagram:
- Reel (30s demo)
- Stories (developer Q&A)

TikTok:
- "Watch my heart control music" (viral potential)
- #Biofeedback #AppleWatch #MusicProduction

YouTube:
- Full demo (5-10 min)
- Tutorial series (3 videos)
```

**Week 1: Outreach**
```
Music Tech Press:
- Sound on Sound
- MusicTech
- Gearnews
- Ask Audio

Tech Press:
- 9to5Mac
- MacRumors
- Cult of Mac
- iMore

Influencers:
- Andrew Huang (YouTube: 2M subs)
- BENN (TikTok music producer)
- Casey Neistat (tech angle)
- Dave Asprey (biohacking)
```

**Checklist:**
```
[ ] ProductHunt launch (Day 1, 00:01 PST)
[ ] Reddit posts (5 subreddits)
[ ] Twitter/X thread
[ ] Instagram Reel
[ ] TikTok viral video
[ ] YouTube demo
[ ] Press outreach (10 outlets)
[ ] Influencer outreach (5 creators)
```

---

## 📊 SUCCESS METRICS (Week-by-Week)

### **Week 1-2 (Sprint 1):**
```
Technical:
✅ 0 audio thread safety violations
✅ 0 crashes in 24h test
✅ CPU < 50% (8 tracks)
✅ Latency < 10ms
```

### **Week 3-4 (Sprint 2):**
```
Technical:
✅ Biofeedback → Audio wiring works
✅ HRV changes affect audio in real-time
✅ Apple Watch integration stable

User:
✅ 10 beta testers confirm "it works!"
```

### **Week 5-6 (Sprint 3):**
```
Technical:
✅ Video export works (TikTok/Instagram)
✅ AUv3 loads in GarageBand/Cubasis
✅ Export time < 2x real-time

User:
✅ 50 beta testers active
✅ First user-generated content (TikTok)
```

### **Week 7-8 (Sprint 4):**
```
Business:
✅ App Store approved
✅ 500 TestFlight beta testers
✅ ProductHunt #1 Product of the Day
✅ 1,000 downloads (Week 1)
✅ 100 Pro subscriptions (€999 MRR)

Community:
✅ 100+ App Store reviews (4.5+ stars)
✅ 5 press mentions
✅ 1 viral TikTok (100k+ views)
```

---

## 🎯 DEFINITION OF DONE (v1.0)

**v1.0 is COMPLETE when:**

```
Technical:
✅ All P0 features implemented
✅ 0 known crashes
✅ 0 audio thread safety violations
✅ Performance targets met (CPU, latency, battery)
✅ AUv3 works in GarageBand/Cubasis

Business:
✅ App Store approved
✅ Freemium model live (€9.99/mo Pro)
✅ 500+ TestFlight beta testers
✅ Privacy Policy published
✅ Support email active

Marketing:
✅ ProductHunt launched
✅ Social media presence (Twitter, Instagram, TikTok)
✅ Demo video published (YouTube)
✅ 5+ press mentions

Community:
✅ 50+ App Store reviews
✅ Discord server active
✅ First user-generated content (TikTok/Instagram)
```

---

**THEN:** We are LIVE! 🚀

**Next Phase:** Monitor metrics, fix bugs, plan v1.1 (Kamera-Biofeedback, Desktop)

---

**Erstellt:** 2025-11-19
**Version:** FINAL (nach ULTRATHINK ANALYZER)
**Timeline:** 8 Wochen
**Target Launch:** Ende Januar 2026
**Projected Revenue:** €461k/year (mit AUv3)

---

# 🏁 LET'S SHIP THIS! 🏁
