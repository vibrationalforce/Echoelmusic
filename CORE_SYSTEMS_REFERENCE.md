# Echoelmusic Core Systems Reference

## Overview

This document covers the core systems that power Echoelmusic's intelligent music creation and session management capabilities.

---

## Ralph Wiggum Loop Genius

The **Ralph Wiggum Loop Genius** is the creative intelligence engine that provides musical suggestions, flow state detection, and loop management.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH WIGGUM LOOP GENIUS                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              GlobalKeyScaleManager (Singleton)             │  │
│  │  • Key detection from MIDI input                          │  │
│  │  • Scale note generation                                   │  │
│  │  • Diatonic transposition                                  │  │
│  │  • Plugin broadcast (sync all plugins to key)             │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│  ┌───────────────────────────▼───────────────────────────────┐  │
│  │              RalphWiggumFoundation (Singleton)             │  │
│  │  • Creative suggestions (chords, melodies, rhythms)       │  │
│  │  • Flow state detection                                    │  │
│  │  • Loop creation and management                           │  │
│  │  • Session metrics tracking                               │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### GlobalKeyScaleManager

Centralized key/scale management with automatic detection and plugin synchronization.

```cpp
class GlobalKeyScaleManager {
public:
    static GlobalKeyScaleManager& shared();  // Singleton

    // Key detection from MIDI input
    void processNoteOn(uint8_t note, uint8_t velocity);
    KeyInfo detectKeyFromHistory();          // Analyze note history

    // Manual key setting
    void setKey(int root, ScaleType scaleType);
    int currentKey;
    ScaleType currentScale;

    // Scale utilities
    std::vector<int> getScaleNotes();        // Get notes in current scale
    std::vector<Chord> getSuggestedChords(); // Diatonic chord suggestions
    int transposeDiatonically(int note, int steps);

    // Plugin synchronization
    std::function<void(int, ScaleType)> onKeyChange;
    void broadcastToPlugins();

    // Supported scale types
    enum ScaleType {
        major, minor, harmonicMinor, melodicMinor,
        dorian, phrygian, lydian, mixolydian,
        locrian, pentatonicMajor, pentatonicMinor, blues
    };
};
```

### RalphWiggumFoundation

The creative engine for musical suggestions and flow state detection.

```cpp
class RalphWiggumFoundation {
public:
    static RalphWiggumFoundation& shared();  // Singleton

    // Musical context
    void setMusicalContext(int key, ScaleType scale, double tempo);

    // Creative suggestions
    std::vector<ChordSuggestion> getChordSuggestions(int count);
    std::vector<uint8_t> suggestMelody(int length);
    std::vector<bool> generateRhythmPattern(int bars, Subdivision sub);

    // Flow state detection
    void recordUserAction(ActionType type);  // noteInput, parameterChange, etc.
    FlowState detectFlowState();             // Returns isActive, intensity

    // Loop management
    std::string createLoop(const std::string& name, int bars, TimeSignature ts);
    Loop* getLoop(const std::string& id);

    // Session metrics
    void startSession();
    SessionMetrics getSessionMetrics();      // totalActions, sessionDuration
};

// Subdivision options for rhythm patterns
enum Subdivision {
    whole, half, quarter, eighth, sixteenth, triplet
};
```

### Usage Example

```cpp
// Set up key detection
auto& keyManager = GlobalKeyScaleManager::shared();
keyManager.onKeyChange = [](int key, ScaleType scale) {
    // Sync all plugins to the new key
    pluginHost.broadcastKey(key, scale);
};

// Process MIDI input for key detection
void onMidiNote(uint8_t note, uint8_t velocity) {
    keyManager.processNoteOn(note, velocity);
}

// Get creative suggestions
auto& ralph = RalphWiggumFoundation::shared();
ralph.setMusicalContext(keyManager.currentKey, keyManager.currentScale, 120.0);

auto chords = ralph.getChordSuggestions(4);    // 4 chord progression
auto melody = ralph.suggestMelody(8);           // 8 note melody
auto rhythm = ralph.generateRhythmPattern(2, Subdivision::sixteenth);
```

---

## Wise Save Mode

**Wise Save Mode** is the intelligent session management system with automatic snapshots, recovery points, and smart naming.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       WISE SAVE MODE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                WiseSaveMode (Singleton)                    │  │
│  │                                                            │  │
│  │  Session Management:                                       │  │
│  │  • initialize(projectDirectory)                           │  │
│  │  • currentSessionId                                        │  │
│  │  • isInitialized                                           │  │
│  │                                                            │  │
│  │  Snapshot System:                                          │  │
│  │  • createSnapshot(name)                                    │  │
│  │  • snapshotCount                                           │  │
│  │  • loadSnapshot(id)                                        │  │
│  │                                                            │  │
│  │  Dirty Tracking:                                           │  │
│  │  • markDirty() / markClean()                              │  │
│  │  • isDirty (atomic<bool>)                                 │  │
│  │                                                            │  │
│  │  Plugin State Tracking:                                    │  │
│  │  • updatePluginState(pluginId, state)                     │  │
│  │  • getPluginState(pluginId)                               │  │
│  │                                                            │  │
│  │  Recovery System:                                          │  │
│  │  • createRecoveryPoint()                                   │  │
│  │  • getRecoveryFiles()                                      │  │
│  │  • autoRecoveryTimer (thread-safe)                        │  │
│  │                                                            │  │
│  │  Smart Naming:                                             │  │
│  │  • setKeyContext(root, scale)                             │  │
│  │  • setTempoContext(bpm)                                   │  │
│  │  • generateSmartName() → "CMaj_120_01"                    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### WiseSaveMode Class

```cpp
class WiseSaveMode {
public:
    static WiseSaveMode& shared();  // Singleton

    // Session initialization
    void initialize(const juce::File& projectDirectory);
    std::string currentSessionId;
    std::atomic<bool> initialized{false};

    // Snapshots
    void createSnapshot(const juce::String& name);
    int snapshotCount;
    void loadSnapshot(const std::string& id);
    std::vector<SnapshotInfo> listSnapshots();

    // Dirty tracking (thread-safe)
    void markDirty();
    void markClean();
    std::atomic<bool> isDirty{false};

    // Plugin state persistence
    void updatePluginState(const std::string& pluginId, const std::map<std::string, juce::var>& state);
    std::map<std::string, juce::var> getPluginState(const std::string& pluginId);

    // Recovery system
    void createRecoveryPoint();
    std::vector<juce::File> getRecoveryFiles();
    void startAutoRecovery(int intervalMs = 60000);  // Thread-safe timer

    // Smart naming
    void setKeyContext(int root, ScaleType scale);
    void setTempoContext(double bpm);
    juce::String generateSmartName();  // e.g., "FMin_128_03"
};
```

### Thread Safety

WiseSaveMode uses atomic variables and managed threads for thread-safe operation:

```cpp
// Thread-safe state access
std::atomic<bool> isDirty{false};
std::atomic<bool> initialized{false};

// Managed recovery thread (not detached)
std::unique_ptr<std::thread> autoRecoveryThread;
std::atomic<bool> shouldStopRecovery{false};

void startAutoRecovery(int intervalMs) {
    autoRecoveryThread = std::make_unique<std::thread>([this, intervalMs]() {
        while (!shouldStopRecovery.load()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(intervalMs));
            if (isDirty.load()) {
                createRecoveryPoint();
            }
        }
    });
}

~WiseSaveMode() {
    shouldStopRecovery.store(true);
    if (autoRecoveryThread && autoRecoveryThread->joinable()) {
        autoRecoveryThread->join();
    }
}
```

### Usage Example

```cpp
auto& saveMode = WiseSaveMode::shared();

// Initialize session
saveMode.initialize(projectDir);

// Track changes
void onParameterChange() {
    saveMode.markDirty();
}

// Save with smart naming
auto& keyManager = GlobalKeyScaleManager::shared();
saveMode.setKeyContext(keyManager.currentKey, keyManager.currentScale);
saveMode.setTempoContext(currentTempo);
auto name = saveMode.generateSmartName();  // "CMaj_120_01"
saveMode.createSnapshot(name);
```

---

## Performance Profiling System

Comprehensive profiling tools for monitoring and optimizing Echoelmusic's performance.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   PERFORMANCE PROFILING SYSTEM                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────┐  ┌─────────────────────┐              │
│  │ PerformanceProfiler │  │   MemoryProfiler    │              │
│  │ • Section timing    │  │ • Allocation track  │              │
│  │ • Nested profiling  │  │ • Category breakdown│              │
│  │ • Formatted reports │  │ • Memory warnings   │              │
│  └─────────────────────┘  └─────────────────────┘              │
│                                                                  │
│  ┌─────────────────────┐  ┌─────────────────────┐              │
│  │  FrameRateMonitor   │  │ AudioThreadMonitor  │              │
│  │ • FPS tracking      │  │ • Callback timing   │              │
│  │ • Frame time stats  │  │ • Underrun detection│              │
│  │ • Drop detection    │  │ • Buffer utilization│              │
│  └─────────────────────┘  └─────────────────────┘              │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   ScopedProfiler (RAII)                    │  │
│  │  PROFILE_SECTION("name")  PROFILE_FUNCTION()              │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### PerformanceProfiler

Section-based timing with statistical analysis.

```cpp
class PerformanceProfiler {
public:
    static PerformanceProfiler& shared();

    void beginSection(const juce::String& name);
    void endSection(const juce::String& name);

    std::vector<ProfilingReport> getReport();
    juce::String getFormattedReport();
    void reset();

    struct ProfilingReport {
        juce::String name;
        int callCount;
        double totalTimeMs;
        double avgTimeMs;
        double minTimeMs;
        double maxTimeMs;
    };
};

// RAII wrapper for automatic section profiling
class ScopedProfiler {
public:
    ScopedProfiler(const juce::String& name) : sectionName(name) {
        EchoelProfiler.beginSection(sectionName);
    }
    ~ScopedProfiler() {
        EchoelProfiler.endSection(sectionName);
    }
private:
    juce::String sectionName;
};

// Convenience macros
#define PROFILE_SECTION(name) ScopedProfiler _profiler_##__LINE__(name)
#define PROFILE_FUNCTION() ScopedProfiler _profiler_func(__FUNCTION__)
```

### MemoryProfiler

Track memory allocations by category.

```cpp
class MemoryProfiler {
public:
    static MemoryProfiler& shared();

    void recordAllocation(const juce::String& category, size_t bytes);
    void recordDeallocation(const juce::String& category, size_t bytes);

    size_t getCurrentUsage(const juce::String& category);
    size_t getTotalUsage();
    juce::String getFormattedReport();

    void setWarningThreshold(size_t bytes);  // Warn when exceeded
};

// Global accessor
#define EchoelMemory MemoryProfiler::shared()
```

### FrameRateMonitor

Monitor UI frame rate and detect drops.

```cpp
class FrameRateMonitor {
public:
    static FrameRateMonitor& shared();

    void frameRendered();
    double getCurrentFPS();
    double getAverageFrameTimeMs();
    int getDroppedFrameCount();

    void setTargetFPS(double fps);  // Default 60.0
    void reset();
};

// Global accessor
#define EchoelFrameRate FrameRateMonitor::shared()
```

### AudioThreadMonitor

Monitor audio callback performance and detect underruns.

```cpp
class AudioThreadMonitor {
public:
    static AudioThreadMonitor& shared();

    void callbackStarted();
    void callbackFinished();

    double getLastCallbackTimeMs();
    double getAverageCallbackTimeMs();
    double getMaxCallbackTimeMs();
    int getUnderrunCount();
    double getBufferUtilization();  // 0-1, percentage of buffer time used

    void setBufferSizeMs(double ms);
    void reset();
};

// Global accessor
#define EchoelAudioMonitor AudioThreadMonitor::shared()
```

### Usage Examples

```cpp
// Profile a section of code
void processAudio(AudioBuffer& buffer) {
    PROFILE_FUNCTION();

    {
        PROFILE_SECTION("DSP Processing");
        // ... DSP code ...
    }

    {
        PROFILE_SECTION("Effect Chain");
        // ... effects code ...
    }
}

// Track memory usage
void loadSample(const juce::File& file) {
    auto data = file.loadFileAsData();
    EchoelMemory.recordAllocation("Samples", data.getSize());
}

// Monitor frame rate
void timerCallback() override {
    EchoelFrameRate.frameRendered();
    if (EchoelFrameRate.getCurrentFPS() < 30.0) {
        DBG("Warning: Frame rate below 30 FPS");
    }
}

// Monitor audio thread
void processBlock(AudioBuffer& buffer, MidiBuffer& midi) {
    EchoelAudioMonitor.callbackStarted();
    // ... audio processing ...
    EchoelAudioMonitor.callbackFinished();

    if (EchoelAudioMonitor.getBufferUtilization() > 0.8) {
        DBG("Warning: Audio buffer utilization > 80%");
    }
}

// Generate performance report
void showPerformanceReport() {
    DBG(EchoelProfiler.getFormattedReport());
    DBG(EchoelMemory.getFormattedReport());
    DBG("FPS: " << EchoelFrameRate.getCurrentFPS());
    DBG("Audio underruns: " << EchoelAudioMonitor.getUnderrunCount());
}
```

---

## Integration Between Systems

All core systems work together seamlessly:

```cpp
// Ralph Wiggum + Wise Save Mode integration
void onKeyDetected(int key, ScaleType scale) {
    // Update Ralph Wiggum context
    auto& ralph = RalphWiggumFoundation::shared();
    ralph.setMusicalContext(key, scale, currentTempo);

    // Update Wise Save Mode for smart naming
    auto& saveMode = WiseSaveMode::shared();
    saveMode.setKeyContext(key, scale);
    saveMode.markDirty();
}

// Ralph Wiggum + Wearables integration
void onBioDataReceived(double heartRate, double hrv) {
    auto& ralph = RalphWiggumFoundation::shared();
    auto bioTempo = WearableManager::shared().getBioTempo();
    ralph.setMusicalContext(currentKey, currentScale, bioTempo);
}

// Performance monitoring across all systems
void timerCallback() override {
    PROFILE_SECTION("Main Timer");

    auto& wearables = WearableManager::shared();
    auto& ralph = RalphWiggumFoundation::shared();
    auto& saveMode = WiseSaveMode::shared();

    // Process bio-data
    {
        PROFILE_SECTION("Bio Processing");
        wearables.update();
    }

    // Update creative engine
    {
        PROFILE_SECTION("Creative Update");
        ralph.recordUserAction(ActionType::timerTick);
    }

    // Auto-save if needed
    if (saveMode.isDirty.load()) {
        PROFILE_SECTION("Auto Save");
        saveMode.createRecoveryPoint();
    }
}
```

---

## Test Coverage

Unit tests are provided in `Tests/EchoelmusicTests/`:

- **CoreSystemsTests.swift** - Tests for all core system components
- **WearableIntegrationTests.swift** - Tests for wearable device integration

Run tests:
```bash
swift test
# or in Xcode: Cmd+U
```

---

## File Locations

```
Sources/Core/
├── GlobalKeyScaleManager.h    # Key/scale management
├── RalphWiggumFoundation.h    # Creative engine
├── WiseSaveMode.h             # Session management
└── PerformanceEngine.h        # Performance profiling

Tests/EchoelmusicTests/
├── CoreSystemsTests.swift     # Core system unit tests
└── WearableIntegrationTests.swift  # Wearable tests
```

---

## Best Practices

1. **Always use singletons via .shared()** for thread-safe access
2. **Use atomic variables** for cross-thread state (isDirty, initialized)
3. **Profile performance-critical code** with PROFILE_SECTION/PROFILE_FUNCTION
4. **Monitor audio thread utilization** to prevent underruns
5. **Integrate key context** across Ralph Wiggum and Wise Save Mode
6. **Create recovery points** before potentially destructive operations

---

**Copyright (c) 2024-2025 Echoelmusic**
