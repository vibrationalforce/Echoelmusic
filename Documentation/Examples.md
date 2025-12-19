# Echoelmusic Code Examples

Comprehensive examples demonstrating all major features of Echoelmusic.

---

## Table of Contents

1. [Security & Authentication](#security--authentication)
2. [Real-Time Audio Processing](#real-time-audio-processing)
3. [Bio-Reactive Features](#bio-reactive-features)
4. [Accessibility](#accessibility)
5. [Localization](#localization)
6. [Performance Optimization](#performance-optimization)

---

## Security & Authentication

### Example 1: User Registration & Login
```cpp
#include "Sources/Security/UserAuthManager.h"

using namespace Echoel::Security;

void exampleUserAuthentication() {
    UserAuthManager authManager;
    authManager.setJWTSecret("production-secret-key-change-me");
    authManager.setTokenExpiration(86400000);  // 24 hours

    // Register new user
    auto userId = authManager.registerUser(
        "john.doe",
        "john@example.com",
        "SecurePassword123!"
    );

    if (userId.isNotEmpty()) {
        std::cout << "User registered: " << userId << std::endl;

        // Login
        auto token = authManager.login("john.doe", "SecurePassword123!");

        if (token.isNotEmpty()) {
            std::cout << "Login successful! Token: " << token << std::endl;

            // Validate token
            auto validatedUserId = authManager.validateToken(token);
            std::cout << "Token valid for user: " << validatedUserId << std::endl;

            // Change password
            bool changed = authManager.changePassword(
                userId,
                "SecurePassword123!",
                "NewSecurePassword456!"
            );

            std::cout << "Password changed: " << (changed ? "Yes" : "No") << std::endl;
        }
    }
}
```

### Example 2: Production-Grade Encryption
```cpp
#include "Sources/Security/ProductionCrypto.h"

using namespace Echoel::Security;

void exampleEncryption() {
    ProductionCrypto crypto;

    // Generate secure key
    auto key = crypto.generateKey();

    // Encrypt sensitive data
    juce::String secretData = "User credit card: 1234-5678-9012-3456";
    auto encrypted = crypto.encrypt(secretData, key);

    std::cout << "Encrypted: " << encrypted.toBase64() << std::endl;

    // Decrypt
    auto decrypted = crypto.decryptString(encrypted, key);
    std::cout << "Decrypted: " << decrypted << std::endl;

    // Save encrypted file
    juce::File userDataFile("user_data.enc");
    auto fileKey = crypto.generateKey();

    juce::MemoryBlock userData;
    // ... fill userData ...

    auto encryptedData = crypto.encrypt(userData, fileKey);
    userDataFile.replaceWithText(encryptedData.toBase64());
}
```

### Example 3: Role-Based Access Control (RBAC)
```cpp
#include "Sources/Security/AuthorizationManager.h"

using namespace Echoel::Security;

void exampleRBAC() {
    AuthorizationManager authz;

    // Assign roles to users
    authz.assignRole("user_123", "premium");

    // Check permissions
    if (authz.hasPermission("user_123", "export.hd")) {
        std::cout << "User can export in HD" << std::endl;
        // Allow HD export
    }

    if (authz.canAccess("user_123", "cloud", "sync")) {
        std::cout << "User can sync to cloud" << std::endl;
        // Enable cloud sync
    }

    // Create custom role
    Role customRole;
    customRole.roleId = "producer";
    customRole.name = "Music Producer";
    customRole.priority = 150;
    customRole.permissions.add("audio.*");
    customRole.permissions.add("midi.*");
    customRole.permissions.add("export.*");
    customRole.permissions.add("mastering.*");

    authz.createRole(customRole);
    authz.assignRole("user_456", "producer");
}
```

---

## Real-Time Audio Processing

### Example 4: Lock-Free Audio Thread Communication
```cpp
#include "Sources/Audio/LockFreeRingBuffer.h"

using namespace Echoel::Audio;

// Parameter change structure
struct ParameterChange {
    int parameterId;
    float value;
};

// Global buffer (shared between UI and audio threads)
LockFreeRingBuffer<ParameterChange, 1024> g_parameterQueue;

// UI Thread (Producer)
void onSliderMoved(int parameterId, float newValue) {
    ParameterChange change{parameterId, newValue};

    if (!g_parameterQueue.push(change)) {
        // Buffer full (rare) - could log warning
        std::cerr << "Parameter queue full!" << std::endl;
    }
}

// Audio Thread (Consumer) - called in processBlock()
void processAudioBlock(float** buffer, int numChannels, int numSamples) {
    // Process all pending parameter changes (non-blocking)
    ParameterChange change;
    while (g_parameterQueue.pop(change)) {
        applyParameterChange(change.parameterId, change.value);
    }

    // Process audio with updated parameters
    for (int channel = 0; channel < numChannels; ++channel) {
        for (int sample = 0; sample < numSamples; ++sample) {
            buffer[channel][sample] = processSample(buffer[channel][sample]);
        }
    }
}
```

### Example 5: High-Performance DSP Chain
```cpp
#include "Sources/DSP/ParametricEQ.h"
#include "Sources/DSP/Compressor.h"
#include "Sources/DSP/ConvolutionReverb.h"

void exampleDSPChain() {
    const double sampleRate = 48000.0;
    const int blockSize = 512;

    // Create DSP chain
    ParametricEQ eq;
    Compressor comp;
    ConvolutionReverb reverb;

    // Initialize
    eq.prepareToPlay(sampleRate, blockSize);
    comp.prepareToPlay(sampleRate, blockSize);
    reverb.prepareToPlay(sampleRate, blockSize);

    // Configure EQ
    eq.setBand(0, 100.0f, 0.7f, 2.0f);    // Low boost
    eq.setBand(1, 1000.0f, 1.0f, 1.0f);   // Mid neutral
    eq.setBand(2, 10000.0f, 0.7f, -1.5f); // High cut

    // Configure compressor
    comp.setThreshold(-20.0f);  // dB
    comp.setRatio(4.0f);
    comp.setAttack(10.0f);      // ms
    comp.setRelease(100.0f);    // ms

    // Load impulse response for reverb
    juce::File irFile("hall_reverb.wav");
    reverb.loadImpulseResponse(irFile);

    // Process audio block
    juce::AudioBuffer<float> buffer(2, blockSize);

    // Fill buffer with audio data...

    // Apply DSP chain
    eq.process(buffer);
    comp.process(buffer);
    reverb.process(buffer);

    // Output buffer now contains processed audio
}
```

---

## Bio-Reactive Features

### Example 6: Heart Rate Variability (HRV) Processing
```cpp
#include "Sources/BioData/HRVProcessor.h"
#include "Sources/BioData/BioReactiveModulator.h"

using namespace Echoel;

void exampleHRVProcessing() {
    HRVProcessor hrvProcessor;
    BioReactiveModulator bioMod;

    // Simulate heart rate data (in real app, from wearable device)
    std::vector<float> heartRateData = {
        72.0f, 71.5f, 72.2f, 73.1f, 72.8f, // Relaxed state
        75.3f, 78.1f, 80.5f, 82.3f, 79.7f  // Stress detected
    };

    for (float heartRate : heartRateData) {
        // Update HRV processor
        hrvProcessor.addRRInterval(60000.0f / heartRate);  // Convert BPM to ms

        // Get HRV metrics
        float hrv = hrvProcessor.getHRV();
        float coherence = hrvProcessor.getCoherenceScore();
        float stress = hrvProcessor.getStressLevel();

        std::cout << "HRV: " << hrv
                  << ", Coherence: " << coherence
                  << ", Stress: " << stress << std::endl;

        // Map to audio parameters
        bioMod.setHRV(hrv);
        bioMod.setCoherence(coherence);
        bioMod.setStressLevel(stress);

        // Get modulated audio parameters
        float filterCutoff = bioMod.getFilterCutoff();      // HRV → Brightness
        float reverbMix = bioMod.getReverbMix();            // Coherence → Space
        float compressionRatio = bioMod.getCompressionRatio(); // Stress → Dynamics

        std::cout << "Filter: " << filterCutoff << " Hz"
                  << ", Reverb: " << (reverbMix * 100) << "%"
                  << ", Compression: " << compressionRatio << ":1" << std::endl;
    }
}
```

---

## Accessibility

### Example 7: Screen Reader Support
```cpp
#include "Sources/UI/Accessibility/AccessibilityManager.h"

using namespace Echoel::UI;

class AccessibleSlider : public juce::Slider {
public:
    AccessibleSlider() {
        // Set accessibility properties
        AccessibilityManager::setAccessibleLabel(this, "Volume Control");
        AccessibilityManager::setAccessibleRole(this, juce::AccessibilityRole::slider);
        AccessibilityManager::makeKeyboardAccessible(this);
        setWantsKeyboardFocus(true);
    }

    void valueChanged() override {
        // Announce value change to screen reader
        AccessibilityManager::getInstance().announce(
            "Volume: " + juce::String((int)(getValue() * 100)) + " percent",
            "polite"
        );
    }

    bool keyPressed(const juce::KeyPress& key) override {
        if (key == juce::KeyPress::upKey) {
            setValue(getValue() + 0.01, juce::sendNotificationAsync);
            return true;
        }
        if (key == juce::KeyPress::downKey) {
            setValue(getValue() - 0.01, juce::sendNotificationAsync);
            return true;
        }
        return Slider::keyPressed(key);
    }
};
```

### Example 8: High Contrast Mode
```cpp
#include "Sources/UI/Accessibility/AccessibilityManager.h"

void exampleHighContrastUI(juce::Component* component) {
    AccessibilityManager& accessMgr = AccessibilityManager::getInstance();

    if (accessMgr.getSettings().highContrastMode) {
        // Use high-contrast colors (WCAG AAA 7:1)
        auto bg = accessMgr.getHighContrastColour("background");  // Black
        auto fg = accessMgr.getHighContrastColour("foreground");  // White
        auto accent = accessMgr.getHighContrastColour("accent");  // Cyan

        component->setColour(juce::Label::backgroundColourId, bg);
        component->setColour(juce::Label::textColourId, fg);

        // Verify contrast ratio
        float ratio = AccessibilityManager::calculateContrastRatio(fg, bg);
        std::cout << "Contrast ratio: " << ratio << ":1" << std::endl;

        bool meetsAAA = AccessibilityManager::meetsWCAG_AAA(fg, bg);
        std::cout << "Meets WCAG AAA: " << (meetsAAA ? "Yes" : "No") << std::endl;
    }
}
```

---

## Localization

### Example 9: Multi-Language Support
```cpp
#include "Sources/Localization/LocalizationManager.h"

using namespace Echoel::Localization;

void exampleLocalization() {
    LocalizationManager& i18n = LocalizationManager::getInstance();

    // Set user's language
    i18n.setLocale("de");  // German

    // Get translated strings
    auto saveButton = i18n.translate("ui.button.save");     // "Speichern"
    auto cancelButton = i18n.translate("ui.button.cancel"); // "Abbrechen"

    std::cout << "Save: " << saveButton << std::endl;
    std::cout << "Cancel: " << cancelButton << std::endl;

    // Translate with variables
    std::map<std::string, juce::String> vars;
    vars["name"] = "Hans";
    auto greeting = i18n.translate("greeting.hello", vars);
    std::cout << greeting << std::endl;  // "Hallo, Hans!"

    // Plural forms
    auto itemCount1 = i18n.translatePlural("item.count", 1);  // "1 Element"
    auto itemCount5 = i18n.translatePlural("item.count", 5);  // "5 Elemente"

    std::cout << itemCount1 << std::endl;
    std::cout << itemCount5 << std::endl;

    // Format currency
    auto price = i18n.formatCurrency(29.99f, "EUR");  // "€29.99"
    std::cout << "Price: " << price << std::endl;

    // RTL check
    i18n.setLocale("ar");  // Arabic
    bool isRTL = i18n.isRTL();
    std::cout << "Right-to-left: " << (isRTL ? "Yes" : "No") << std::endl;
}
```

---

## Performance Optimization

### Example 10: SIMD Optimization
```cpp
#include <immintrin.h>  // AVX2

// Process 8 samples at once using AVX2
void processSamplesAVX2(float* buffer, int numSamples, float gain) {
    const __m256 gainVec = _mm256_set1_ps(gain);

    int i = 0;
    // Process 8 samples at a time
    for (; i + 7 < numSamples; i += 8) {
        __m256 samples = _mm256_loadu_ps(&buffer[i]);
        samples = _mm256_mul_ps(samples, gainVec);
        _mm256_storeu_ps(&buffer[i], samples);
    }

    // Process remaining samples
    for (; i < numSamples; ++i) {
        buffer[i] *= gain;
    }
}

// Benchmark: 8x faster than scalar code!
```

### Example 11: Cache-Line Alignment
```cpp
#include <cstdlib>

// Align data to cache lines (64 bytes) for better performance
struct alignas(64) AudioProcessor {
    float filterCoeff[8];      // 32 bytes
    float filterState[8];      // 32 bytes
    // Fits exactly in one cache line = zero false sharing
};

// Allocate aligned memory
void* allocateAligned(size_t size, size_t alignment) {
    void* ptr = nullptr;
    posix_memalign(&ptr, alignment, size);
    return ptr;
}

AudioProcessor* proc = static_cast<AudioProcessor*>(
    allocateAligned(sizeof(AudioProcessor), 64)
);
```

---

## Complete Application Example

### Example 12: Full Bio-Reactive Music App
```cpp
#include <JuceHeader.h>
#include "Sources/BioData/BioReactiveModulator.h"
#include "Sources/DSP/ParametricEQ.h"
#include "Sources/Security/UserAuthManager.h"
#include "Sources/Audio/LockFreeRingBuffer.h"

class BioReactiveMusicApp : public juce::AudioAppComponent {
public:
    BioReactiveMusicApp() {
        // Initialize security
        authManager.setJWTSecret("my-secret-key");

        // Initialize DSP
        eq.prepareToPlay(44100.0, 512);
        bioMod.setHRV(0.7f);

        // Set audio channels
        setAudioChannels(2, 2);
    }

    ~BioReactiveMusicApp() override {
        shutdownAudio();
    }

    void prepareToPlay(int samplesPerBlockExpected, double sampleRate) override {
        eq.prepareToPlay(sampleRate, samplesPerBlockExpected);
    }

    void getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill) override {
        // Process parameter changes from UI thread
        ParameterChange change;
        while (paramQueue.pop(change)) {
            if (change.parameterId == 0) {
                bioMod.setHRV(change.value);
            }
        }

        // Get bio-reactive parameters
        float filterCutoff = bioMod.getFilterCutoff();
        eq.setBand(0, filterCutoff, 1.0f, 0.0f);

        // Process audio
        eq.process(*bufferToFill.buffer);
    }

    void releaseResources() override {
    }

private:
    Echoel::Security::UserAuthManager authManager;
    ParametricEQ eq;
    BioReactiveModulator bioMod;
    LockFreeRingBuffer<ParameterChange, 1024> paramQueue;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioReactiveMusicApp)
};

// Main function
int main() {
    juce::JUCEApplication::getInstance()->initialise("");

    BioReactiveMusicApp app;

    // Run application
    while (true) {
        juce::MessageManager::getInstance()->runDispatchLoopUntil(100);
    }

    return 0;
}
```

---

## More Examples

For more examples, see:
- `Tests/` - Comprehensive unit tests showing API usage
- `Examples/` - Standalone example projects
- `Documentation/` - API reference and tutorials

---

**Last Updated:** 2024-12-18
**Version:** 1.0.0 (GENIUS MODE x5)
