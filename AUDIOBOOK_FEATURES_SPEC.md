# 🎧 ECHOELMUSIC AUDIOBOOK EDITION - FEATURE SPECIFICATION

**Version:** 1.0 MVP
**Target Release:** Q1 2026
**Estimated Development:** 10-15 days
**Market Positioning:** Professional Audiobook Production for Independent Narrators

---

## 🎯 EXECUTIVE SUMMARY

**Opportunity:** Audiobook market growing 25% annually (Audible, Storytel, etc.), but professional tools expensive (Adobe Audition €24.99/month) or limited (Audacity free but basic).

**Solution:** Echoelmusic Audiobook Edition - **ACX-ready audiobook production in one click**

**Target Users:**
- Independent narrators (Fiverr, ACX Direct)
- Podcast producers (upgrading to audiobook)
- Voice actors (demo reels, audiobooks)
- Small publishing houses

**Unique Selling Points:**
1. ✅ **One-Click ACX Compliance** (Peak, RMS, Noise Floor auto-check)
2. ✅ **Batch Processing** (Process entire book in queue)
3. ✅ **Professional VocalChain** (Already implemented!)
4. ✅ **Speech Enhancement** (De-Reverb, Breath Removal, Plosive Reduction)
5. ✅ **Chapter Management** (M4B format with chapter marks)
6. ✅ **Affordable** (€29.99 one-time vs. €24.99/month Adobe)

---

## 📊 MARKET ANALYSIS

### **Competitors:**

| Tool | Price | Pros | Cons |
|------|-------|------|------|
| **Adobe Audition** | €24.99/month | Industry standard, full DAW | Expensive, overkill for narration |
| **Audacity** | Free | Open source | Basic UI, limited automation |
| **Reaper** | €60 one-time | Affordable, customizable | Steep learning curve |
| **Hindenburg Narrator** | €95 | Audiobook-specific | Limited features |
| **Echoelmusic** | **€29.99 one-time** | ACX-ready, batch processing | **NEW** (needs marketing) |

### **Market Size:**

- **Audible Narrators:** 50,000+ active (2024)
- **ACX Marketplace:** 10,000+ titles/year
- **Podcast Producers → Audiobook:** Growing segment
- **Estimated TAM:** €10-15M (niche but profitable)

---

## 🛠️ FEATURE SPECIFICATION

### **PHASE 1: ACX COMPLIANCE TOOLS (Priority: P0)**

#### **Feature 1.1: ACX Standards Validator**

**Objective:** One-click pass/fail report for ACX audiobook standards

**ACX Requirements:**
```yaml
Peak Level:
  - Max: -3.0 dB (True Peak)
  - Reason: Prevent clipping on all playback systems

RMS (Loudness):
  - Range: -18.0 dB to -23.0 dB
  - Reason: Consistent loudness across all audiobooks

Noise Floor:
  - Max: -60.0 dB
  - Measurement: Between spoken words (room tone)
  - Reason: Professional quiet background

Format:
  - Sample Rate: 44.1 kHz or 48 kHz
  - Bit Depth: 16-bit minimum (24-bit recommended)
  - Channels: Mono (preferred) or Stereo

File Duration:
  - Max: 120 minutes per file (ACX limit)
```

**Implementation:**

```cpp
// Header: Sources/DSP/ACXValidator.h
class ACXValidator
{
public:
    struct ACXReport
    {
        // Peak Level Analysis
        float truePeakLevel;           // True Peak (dBTP)
        bool peakPassed;               // < -3.0 dBTP

        // RMS Analysis
        float rmsLevel;                // RMS (dB)
        bool rmsPassed;                // -23.0 to -18.0 dB

        // Noise Floor Analysis
        float noiseFloor;              // Noise floor (dB)
        bool noiseFloorPassed;         // < -60.0 dB

        // Format Check
        double sampleRate;
        int bitDepth;
        int numChannels;
        bool formatPassed;

        // Duration Check
        double durationMinutes;
        bool durationPassed;           // < 120 minutes

        // Overall Result
        bool overallPassed;

        // Detailed Messages
        std::vector<std::string> warnings;
        std::vector<std::string> errors;
    };

    // Validate entire audio file
    ACXReport validate(const juce::AudioBuffer<float>& buffer,
                       double sampleRate);

    // Batch validation (multiple files)
    std::vector<ACXReport> validateBatch(
        const std::vector<juce::File>& audioFiles);

private:
    float calculateTruePeak(const juce::AudioBuffer<float>& buffer);
    float calculateRMS(const juce::AudioBuffer<float>& buffer);
    float calculateNoiseFloor(const juce::AudioBuffer<float>& buffer);
};
```

**UI (Swift):**

```swift
struct ACXValidatorView: View {
    @State private var validationReport: ACXReport?

    var body: some View {
        VStack {
            // File Selection
            Button("Select Audio File") {
                selectFile()
            }

            // Validation Results
            if let report = validationReport {
                VStack(alignment: .leading) {
                    // Peak Level
                    HStack {
                        Image(systemName: report.peakPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foreground Color(report.peakPassed ? .green : .red)
                        Text("Peak Level: \(report.truePeakLevel, specifier: "%.2f") dBTP")
                        Spacer()
                        Text(report.peakPassed ? "PASS" : "FAIL")
                    }

                    // RMS Level
                    HStack {
                        Image(systemName: report.rmsPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(report.rmsPassed ? .green : .red)
                        Text("RMS Level: \(report.rmsLevel, specifier: "%.2f") dB")
                        Spacer()
                        Text(report.rmsPassed ? "PASS" : "FAIL")
                    }

                    // Noise Floor
                    HStack {
                        Image(systemName: report.noiseFloorPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(report.noiseFloorPassed ? .green : .red)
                        Text("Noise Floor: \(report.noiseFloor, specifier: "%.2f") dB")
                        Spacer()
                        Text(report.noiseFloorPassed ? "PASS" : "FAIL")
                    }

                    Divider()

                    // Overall Result
                    HStack {
                        Text("Overall ACX Compliance:")
                            .font(.headline)
                        Spacer()
                        Text(report.overallPassed ? "✅ PASSED" : "❌ FAILED")
                            .font(.title2)
                            .foregroundColor(report.overallPassed ? .green : .red)
                    }

                    // Export Report
                    Button("Export PDF Report") {
                        exportPDFReport(report)
                    }
                }
                .padding()
            }
        }
    }
}
```

**Time Estimate:** 2-3 days

---

#### **Feature 1.2: ACX Auto-Mastering**

**Objective:** Automatically process audio to meet ACX standards

**Processing Chain:**

```yaml
Step 1: Noise Gate
  - Threshold: -50 dB
  - Attack: 1 ms
  - Release: 100 ms
  - Purpose: Remove background noise between words

Step 2: De-Esser
  - Frequency: 6-8 kHz
  - Threshold: -12 dB
  - Purpose: Reduce sibilance

Step 3: Compression
  - Ratio: 3:1
  - Threshold: -12 dB
  - Attack: 5 ms
  - Release: 100 ms
  - Purpose: Even out dynamics

Step 4: EQ
  - High-Pass: 80 Hz (remove rumble)
  - Low-Mid Cut: -3 dB @ 200-400 Hz (reduce muddiness)
  - Presence Boost: +2 dB @ 3 kHz (clarity)
  - Purpose: Speech intelligibility

Step 5: Limiting
  - Ceiling: -3.1 dBTP (ACX safe)
  - Release: 100 ms
  - Purpose: Prevent peaks

Step 6: RMS Normalization
  - Target: -20.0 dB RMS (ACX sweet spot)
  - Purpose: Consistent loudness
```

**Implementation:**

```cpp
class ACXAutoMastering
{
public:
    void process(juce::AudioBuffer<float>& buffer, double sampleRate);

    // Customizable parameters
    void setTargetRMS(float rmsDB);     // Default: -20.0 dB
    void setTargetPeak(float peakDB);   // Default: -3.1 dBTP
    void setAggressiveness(float level); // 0.0 (gentle) - 1.0 (aggressive)

private:
    // DSP Chain (re-use existing Echoelmusic effects!)
    NoiseGate noiseGate;
    DeEsser deEsser;
    Compressor compressor;
    ParametricEQ eq;
    BrickWallLimiter limiter;
};
```

**Time Estimate:** 2-3 days (mostly UI integration)

---

### **PHASE 2: BATCH PROCESSING (Priority: P0)**

#### **Feature 2.1: Queue-Based Processing**

**Objective:** Process entire audiobook (20+ chapters) in one session

**Workflow:**

```
User adds files → Queue system → Apply ACX Auto-Mastering → Export
```

**UI:**

```swift
struct BatchProcessorView: View {
    @State private var fileQueue: [AudioFile] = []
    @State private var currentProcessing: AudioFile?
    @State private var progress: Double = 0.0

    var body: some View {
        VStack {
            // File Queue
            List {
                ForEach(fileQueue) { file in
                    HStack {
                        Text(file.name)
                        Spacer()
                        if file == currentProcessing {
                            ProgressView(value: progress)
                                .frame(width: 100)
                        } else if file.isProcessed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "clock")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

            // Controls
            HStack {
                Button("Add Files") { addFiles() }
                Button("Start Batch") { startBatch() }
                Button("Clear Queue") { clearQueue() }
            }

            // Overall Progress
            ProgressView("Processing Chapter \(currentChapter) of \(totalChapters)",
                        value: Double(currentChapter),
                        total: Double(totalChapters))
        }
    }
}
```

**Implementation:**

```cpp
class BatchProcessor
{
public:
    void addToQueue(const juce::File& audioFile);
    void startProcessing();
    void pauseProcessing();
    void cancelProcessing();

    // Progress callback
    std::function<void(int current, int total, double progress)> onProgress;

private:
    std::vector<juce::File> queue;
    std::atomic<bool> isProcessing { false };
    std::atomic<int> currentFileIndex { 0 };
};
```

**Time Estimate:** 2-3 days

---

### **PHASE 3: SPEECH ENHANCEMENT (Priority: P1)**

#### **Feature 3.1: De-Reverb Filter**

**Objective:** Remove room reflections for professional studio sound

**Algorithm:** Spectral Subtraction

```cpp
class DeReverb
{
public:
    void process(juce::AudioBuffer<float>& buffer);

    void setRoomToneProfile(const juce::AudioBuffer<float>& roomTone);
    void setReductionAmount(float amount);  // 0.0 - 1.0

private:
    juce::dsp::FFT fft { 11 };  // 2048 samples
    std::vector<float> roomToneSpectrum;

    // Spectral subtraction: Clean = Original - (RoomTone * Amount)
};
```

**Time Estimate:** 1-2 days

---

#### **Feature 3.2: Advanced Breath Removal**

**Objective:** Automatically detect and reduce breath sounds

**Algorithm:**

```cpp
class BreathRemover
{
public:
    struct BreathEvent
    {
        int startSample;
        int endSample;
        float intensity;  // 0.0 (soft) - 1.0 (loud)
    };

    std::vector<BreathEvent> detectBreaths(const juce::AudioBuffer<float>& buffer);
    void removeBreaths(juce::AudioBuffer<float>& buffer,
                       const std::vector<BreathEvent>& breaths,
                       float reduction = 0.8f);  // 0.0 (none) - 1.0 (full)

private:
    // Detection: Energy in 100-500 Hz band (breath frequency range)
    float detectBreathEnergy(const float* samples, int numSamples);

    // Removal: Fade-out/in around breath
};
```

**Time Estimate:** 2-3 days

---

#### **Feature 3.3: Plosive Reduction**

**Objective:** Reduce "P", "B", "T", "K" pops

**Algorithm:** Transient Detection + Dynamic EQ

```cpp
class PlosiveReducer
{
public:
    void process(juce::AudioBuffer<float>& buffer);

    void setSensitivity(float sensitivity);  // 0.0 - 1.0
    void setReduction(float reduction);      // 0.0 - 1.0

private:
    // Detect transients (sharp attack)
    bool isPlosive(const float* samples, int numSamples);

    // Reduce low-frequency energy (< 200 Hz) at plosive
    void reduceLowFrequency(float* samples, int numSamples, float amount);
};
```

**Time Estimate:** 1-2 days

---

### **PHASE 4: CHAPTER MANAGEMENT (Priority: P1)**

#### **Feature 4.1: Chapter Markers & M4B Export**

**Objective:** Create audiobook files with chapter navigation

**Formats:**

1. **M4B (AAC + Chapters)** - Preferred by Apple Books
2. **MP3 with ID3v2 CHAP** - Compatible with most players

**Implementation:**

```cpp
class AudiobookExporter
{
public:
    struct Chapter
    {
        std::string title;
        double startTime;    // Seconds
        double endTime;
        juce::File audioFile;
    };

    // Export single file with chapter marks
    void exportM4B(const std::vector<Chapter>& chapters,
                   const juce::File& outputFile,
                   int bitrate = 64);  // kbps (ACX recommends 64-128)

    // Export MP3 with ID3v2 CHAP tags
    void exportMP3WithChapters(const std::vector<Chapter>& chapters,
                               const juce::File& outputFile,
                               int bitrate = 128);

    // Metadata
    void setTitle(const std::string& title);
    void setAuthor(const std::string& author);
    void setNarrator(const std::string& narrator);
    void setCoverArt(const juce::File& imageFile);
    void setISBN(const std::string& isbn);

private:
    juce::AudioFormatManager formatManager;
};
```

**UI:**

```swift
struct ChapterEditorView: View {
    @State private var chapters: [Chapter] = []

    var body: some View {
        VStack {
            // Chapter List
            List {
                ForEach(chapters.indices, id: \.self) { index in
                    HStack {
                        TextField("Chapter \(index + 1)", text: $chapters[index].title)
                        Text("\(chapters[index].duration, specifier: "%.1f") min")
                    }
                }
            }

            // Metadata
            Form {
                TextField("Book Title", text: $bookTitle)
                TextField("Author", text: $author)
                TextField("Narrator", text: $narrator)
                TextField("ISBN", text: $isbn)
            }

            // Export
            Button("Export M4B Audiobook") {
                exportM4B()
            }
        }
    }
}
```

**Time Estimate:** 3-4 days

---

## 📊 FEATURE PRIORITY MATRIX

| Feature | Priority | Days | ROI | Complexity |
|---------|----------|------|-----|------------|
| ACX Validator | P0 | 2-3 | ⭐⭐⭐⭐⭐ | Low |
| ACX Auto-Mastering | P0 | 2-3 | ⭐⭐⭐⭐⭐ | Medium |
| Batch Processing | P0 | 2-3 | ⭐⭐⭐⭐ | Low |
| De-Reverb | P1 | 1-2 | ⭐⭐⭐ | Medium |
| Breath Removal | P1 | 2-3 | ⭐⭐⭐⭐ | Medium |
| Plosive Reduction | P1 | 1-2 | ⭐⭐⭐ | Low |
| Chapter Manager | P1 | 3-4 | ⭐⭐⭐⭐ | High |
| M4B Export | P1 | 2-3 | ⭐⭐⭐⭐ | Medium |

**Total MVP:** 15-23 days

---

## 🎯 MVP SCOPE (10-15 Days)

**Deliverable:** "Echoelmusic Audiobook Edition v1.0"

**Included:**
1. ✅ ACX Validator (one-click compliance check)
2. ✅ ACX Auto-Mastering (one-click processing)
3. ✅ Batch Processing (queue system)
4. ✅ Basic Chapter Manager (manual markers)
5. ✅ M4B Export (with metadata)

**Not Included (v2.0):**
- De-Reverb (nice-to-have)
- Advanced Breath Removal (basic version in VocalChain already exists)
- Plosive Reduction (nice-to-have)
- Automatic Chapter Detection (AI-based, complex)

---

## 💰 PRICING STRATEGY

### **Option A: One-Time Purchase**
- Price: €29.99
- Includes: All features, lifetime updates
- Target: Independent narrators, hobbyists

### **Option B: Freemium**
- Free: ACX Validator only
- Pro (€19.99/month): All features + priority support

### **Option C: Bundle**
- Echoelmusic Pro + Audiobook Edition: €49.99 one-time

**Recommendation:** **Option A** (simpler, builds customer base)

---

## 📈 SUCCESS METRICS

**Launch (3 months):**
- 500 downloads
- 100 paid users (€2,999 revenue)
- 50 ACX-submitted audiobooks

**Year 1:**
- 5,000 downloads
- 1,000 paid users (€29,990 revenue)
- 500 ACX-submitted audiobooks
- 10 reviews on ACX forums

---

## 🚀 GO-TO-MARKET STRATEGY

### **Marketing Channels:**

1. **ACX Forums/Reddit**
   - Post: "I built an affordable ACX compliance tool - here's my story"
   - Offer: 30-day free trial

2. **Fiverr Narrator Community**
   - Sponsor: "Top Narrators use Echoelmusic"
   - Affiliate: 20% commission for narrators

3. **Podcast Producer Groups**
   - Angle: "Turn your podcast into an audiobook in 1 hour"

4. **YouTube Tutorials**
   - "How to Pass ACX Quality Check (Free Tool)"
   - "Audiobook Production 101"

5. **Content Marketing**
   - Blog: "ACX Standards Explained"
   - Newsletter: Weekly narration tips

---

## 📋 DEVELOPMENT CHECKLIST

### **Week 1-2: Core Features**
```
[ ] ACXValidator.cpp (2-3 days)
[ ] ACXAutoMastering.cpp (2-3 days)
[ ] BatchProcessor.cpp (2-3 days)
[ ] Swift UI integration (2 days)
[ ] Testing (2 days)
```

### **Week 3: Polish & Launch**
```
[ ] Chapter Manager UI (2 days)
[ ] M4B Export (2-3 days)
[ ] Documentation (1 day)
[ ] Beta Testing (3 days)
[ ] App Store submission (1 day)
```

---

## 📚 TECHNICAL REQUIREMENTS

**Dependencies:**
- JUCE 7.x (already used)
- lame (MP3 encoding, MIT license)
- fdkaac (AAC encoding for M4B, Apache 2.0)

**Platform Support:**
- macOS: Full support
- Windows: Full support
- Linux: ACX Validator + Auto-Mastering (no M4B export)
- iOS: Not applicable (desktop-focused)

---

## 🎓 TRAINING & SUPPORT

**Documentation:**
- Quick Start Guide (5 minutes to first audiobook)
- ACX Standards Explained (detailed)
- Troubleshooting FAQ

**Video Tutorials:**
- "Your First Audiobook in 10 Minutes"
- "Advanced Vocal Processing Tips"
- "Batch Processing 20 Chapters"

**Support:**
- Email: support@echoelmusic.com
- Discord: Community channel
- FAQ: Common ACX issues

---

## 🏁 CONCLUSION

**Audiobook Edition is a HIGH-ROI, LOW-RISK feature addition for Echoelmusic:**

✅ **Leverages Existing VocalChain** (70% code reuse)
✅ **Clear Market Need** (ACX narrators need affordable tools)
✅ **Quick Development** (10-15 days to MVP)
✅ **Differentiated** (One-click ACX compliance unique)
✅ **Scalable** (Batch processing, automation)

**Next Steps:**
1. Approve spec
2. Allocate 2-3 weeks development time
3. Beta test with 10 narrators
4. Launch on App Store + ProductHunt
5. Marketing campaign (ACX forums, Fiverr)

---

**Created:** 2025-11-19
**Version:** 1.0
**Status:** Ready for Development
**Estimated Revenue Year 1:** €30,000 (conservative)
