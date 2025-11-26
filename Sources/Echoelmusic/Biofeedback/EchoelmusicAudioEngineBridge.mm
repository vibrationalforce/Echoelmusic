//  EchoelmusicAudioEngineBridge.mm
//  Echoelmusic
//
//  Objective-C++ implementation of bridge between Swift and C++ audio engine
//

#import "EchoelmusicAudioEngineBridge.h"
#include "AudioEngine.h"  // C++ audio engine
#include <atomic>
#include <cmath>

// MARK: - Global Bio-Reactive Parameters (Lock-Free, Atomic)

namespace EchoelmusicBioReactive {
    // Filter parameters
    std::atomic<float> filterCutoffHz { 1000.0f };

    // Reverb parameters
    std::atomic<float> reverbSize { 0.5f };
    std::atomic<float> reverbDecay { 2.0f };

    // Volume parameters
    std::atomic<float> bioVolume { 1.0f };

    // Delay parameters
    std::atomic<float> delayTimeMs { 250.0f };
    std::atomic<float> delayFeedback { 0.3f };

    // Modulation parameters (LFO)
    std::atomic<float> modulationRateHz { 0.5f };
    std::atomic<float> modulationDepth { 0.3f };

    // Distortion/Saturation
    std::atomic<float> distortionAmount { 0.0f };

    // Compressor
    std::atomic<float> compressorThresholdDb { -20.0f };
    std::atomic<float> compressorRatio { 4.0f };

    // Debugging
    std::atomic<bool> parameterLoggingEnabled { false };

    // Engine state
    std::atomic<bool> engineInitialized { false };
    std::atomic<double> currentSampleRate { 48000.0 };
}

// MARK: - Helper Functions

static void logParameterChange(const char* paramName, float value) {
    if (EchoelmusicBioReactive::parameterLoggingEnabled.load(std::memory_order_relaxed)) {
        NSLog(@"[BioFeedback] %s = %.2f", paramName, value);
    }
}

static float clampValue(float value, float min, float max) {
    return std::max(min, std::min(max, value));
}

// MARK: - Objective-C++ Bridge Implementation

@implementation EchoelmusicAudioEngineBridge

// MARK: - Parameter Setters

+ (void)setFilterCutoff:(float)frequency {
    // Clamp to valid range (20Hz - 20kHz)
    float clamped = clampValue(frequency, 20.0f, 20000.0f);
    EchoelmusicBioReactive::filterCutoffHz.store(clamped, std::memory_order_relaxed);
    logParameterChange("FilterCutoff", clamped);
}

+ (void)setReverbSize:(float)size {
    // Clamp to 0-1 range
    float clamped = clampValue(size, 0.0f, 1.0f);
    EchoelmusicBioReactive::reverbSize.store(clamped, std::memory_order_relaxed);
    logParameterChange("ReverbSize", clamped);
}

+ (void)setReverbDecay:(float)decay {
    // Clamp to reasonable range (0.1s - 10s)
    float clamped = clampValue(decay, 0.1f, 10.0f);
    EchoelmusicBioReactive::reverbDecay.store(clamped, std::memory_order_relaxed);
    logParameterChange("ReverbDecay", clamped);
}

+ (void)setMasterVolume:(float)volume {
    // Clamp to 0-1 range
    float clamped = clampValue(volume, 0.0f, 1.0f);
    EchoelmusicBioReactive::bioVolume.store(clamped, std::memory_order_relaxed);
    logParameterChange("BioVolume", clamped);
}

+ (void)setDelayTime:(float)timeMs {
    // Clamp to reasonable range (1ms - 2000ms)
    float clamped = clampValue(timeMs, 1.0f, 2000.0f);
    EchoelmusicBioReactive::delayTimeMs.store(clamped, std::memory_order_relaxed);
    logParameterChange("DelayTime", clamped);
}

+ (void)setDelayFeedback:(float)feedback {
    // Clamp to 0-0.95 range (prevent runaway feedback)
    float clamped = clampValue(feedback, 0.0f, 0.95f);
    EchoelmusicBioReactive::delayFeedback.store(clamped, std::memory_order_relaxed);
    logParameterChange("DelayFeedback", clamped);
}

+ (void)setModulationRate:(float)rateHz {
    // Clamp to 0.01Hz - 20Hz
    float clamped = clampValue(rateHz, 0.01f, 20.0f);
    EchoelmusicBioReactive::modulationRateHz.store(clamped, std::memory_order_relaxed);
    logParameterChange("ModulationRate", clamped);
}

+ (void)setModulationDepth:(float)depth {
    // Clamp to 0-1 range
    float clamped = clampValue(depth, 0.0f, 1.0f);
    EchoelmusicBioReactive::modulationDepth.store(clamped, std::memory_order_relaxed);
    logParameterChange("ModulationDepth", clamped);
}

+ (void)setDistortionAmount:(float)amount {
    // Clamp to 0-1 range
    float clamped = clampValue(amount, 0.0f, 1.0f);
    EchoelmusicBioReactive::distortionAmount.store(clamped, std::memory_order_relaxed);
    logParameterChange("DistortionAmount", clamped);
}

+ (void)setCompressorThreshold:(float)thresholdDb {
    // Clamp to -60dB to 0dB
    float clamped = clampValue(thresholdDb, -60.0f, 0.0f);
    EchoelmusicBioReactive::compressorThresholdDb.store(clamped, std::memory_order_relaxed);
    logParameterChange("CompressorThreshold", clamped);
}

+ (void)setCompressorRatio:(float)ratio {
    // Clamp to 1:1 to 20:1
    float clamped = clampValue(ratio, 1.0f, 20.0f);
    EchoelmusicBioReactive::compressorRatio.store(clamped, std::memory_order_relaxed);
    logParameterChange("CompressorRatio", clamped);
}

+ (void)setBioReactiveParameters:(float)filterCutoff
                      reverbSize:(float)reverbSize
                          volume:(float)volume
                       delayTime:(float)delayTime
                 modulationRate:(float)modulationRate {
    // Batch update (more efficient than individual calls)
    [self setFilterCutoff:filterCutoff];
    [self setReverbSize:reverbSize];
    [self setMasterVolume:volume];
    [self setDelayTime:delayTime];
    [self setModulationRate:modulationRate];

    if (EchoelmusicBioReactive::parameterLoggingEnabled.load(std::memory_order_relaxed)) {
        NSLog(@"[BioFeedback] Batch update: Filter=%.0fHz Reverb=%.2f Vol=%.2f Delay=%.0fms Mod=%.2fHz",
              filterCutoff, reverbSize, volume, delayTime, modulationRate);
    }
}

// MARK: - State Query

+ (BOOL)isEngineInitialized {
    return EchoelmusicBioReactive::engineInitialized.load(std::memory_order_relaxed);
}

+ (double)getCurrentSampleRate {
    return EchoelmusicBioReactive::currentSampleRate.load(std::memory_order_relaxed);
}

+ (void)setParameterLogging:(BOOL)enabled {
    EchoelmusicBioReactive::parameterLoggingEnabled.store(enabled, std::memory_order_relaxed);
    NSLog(@"[BioFeedback] Parameter logging %@", enabled ? @"enabled" : @"disabled");
}

// MARK: - Internal: Engine Initialization (Called from C++)

+ (void)notifyEngineInitialized:(BOOL)initialized sampleRate:(double)sampleRate {
    EchoelmusicBioReactive::engineInitialized.store(initialized, std::memory_order_relaxed);
    EchoelmusicBioReactive::currentSampleRate.store(sampleRate, std::memory_order_relaxed);
    NSLog(@"[BioFeedback] Engine initialized: %@ @ %.0fHz", initialized ? @"YES" : @"NO", sampleRate);
}

@end

// MARK: - C++ Access Functions (For AudioEngine to Read Parameters)

namespace EchoelmusicBioReactive {

    /// Get filter cutoff frequency (called from audio thread)
    float getFilterCutoffHz() {
        return filterCutoffHz.load(std::memory_order_relaxed);
    }

    /// Get reverb size
    float getReverbSize() {
        return reverbSize.load(std::memory_order_relaxed);
    }

    /// Get reverb decay time
    float getReverbDecay() {
        return reverbDecay.load(std::memory_order_relaxed);
    }

    /// Get bio-reactive volume
    float getBioVolume() {
        return bioVolume.load(std::memory_order_relaxed);
    }

    /// Get delay time
    float getDelayTimeMs() {
        return delayTimeMs.load(std::memory_order_relaxed);
    }

    /// Get delay feedback
    float getDelayFeedback() {
        return delayFeedback.load(std::memory_order_relaxed);
    }

    /// Get modulation rate
    float getModulationRateHz() {
        return modulationRateHz.load(std::memory_order_relaxed);
    }

    /// Get modulation depth
    float getModulationDepth() {
        return modulationDepth.load(std::memory_order_relaxed);
    }

    /// Get distortion amount
    float getDistortionAmount() {
        return distortionAmount.load(std::memory_order_relaxed);
    }

    /// Get compressor threshold
    float getCompressorThresholdDb() {
        return compressorThresholdDb.load(std::memory_order_relaxed);
    }

    /// Get compressor ratio
    float getCompressorRatio() {
        return compressorRatio.load(std::memory_order_relaxed);
    }
}
