// EchoelmusicAUv3Bridge.mm
// Objective-C++ Implementation of AUv3 ↔ C++ AudioEngine Bridge
//
// This file contains the actual C++ integration code.
// Compile with Objective-C++ (.mm extension)

#import "EchoelmusicAUv3Bridge.h"
#import "../Audio/AudioEngine.h" // C++ AudioEngine
#import <atomic>

@implementation EchoelmusicAUv3Bridge {
    // C++ AudioEngine instance (wrapped in unique_ptr)
    std::unique_ptr<AudioEngine> _audioEngine;

    // Atomic parameters (lock-free, real-time safe)
    std::atomic<float> _filterCutoff;
    std::atomic<float> _reverbSize;
    std::atomic<float> _delayTime;
    std::atomic<float> _delayFeedback;
    std::atomic<float> _modulationRate;
    std::atomic<float> _modulationDepth;
    std::atomic<float> _bioVolume;
    std::atomic<float> _heartRate;
    std::atomic<float> _hrvValue;
    std::atomic<float> _coherence;
}

// MARK: - Singleton

+ (EchoelmusicAUv3Bridge *)shared {
    static EchoelmusicAUv3Bridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[EchoelmusicAUv3Bridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Create C++ AudioEngine
        _audioEngine = std::make_unique<AudioEngine>();

        // Initialize atomic parameters with defaults
        _filterCutoff.store(1000.0f, std::memory_order_relaxed);
        _reverbSize.store(0.5f, std::memory_order_relaxed);
        _delayTime.store(500.0f, std::memory_order_relaxed);
        _delayFeedback.store(0.3f, std::memory_order_relaxed);
        _modulationRate.store(1.0f, std::memory_order_relaxed);
        _modulationDepth.store(0.5f, std::memory_order_relaxed);
        _bioVolume.store(1.0f, std::memory_order_relaxed);
        _heartRate.store(72.0f, std::memory_order_relaxed);
        _hrvValue.store(50.0f, std::memory_order_relaxed);
        _coherence.store(0.5f, std::memory_order_relaxed);
    }
    return self;
}

// MARK: - Audio Engine Lifecycle

- (void)prepareWithSampleRate:(double)sampleRate blockSize:(int)blockSize {
    if (_audioEngine) {
        _audioEngine->prepare(sampleRate, blockSize);
        NSLog(@"✅ EchoelmusicAUv3Bridge: AudioEngine prepared (SR: %.0f Hz, Block: %d)", sampleRate, blockSize);
    }
}

- (void)releaseResources {
    if (_audioEngine) {
        _audioEngine->releaseResources();
        NSLog(@"✅ EchoelmusicAUv3Bridge: AudioEngine resources released");
    }
}

// MARK: - Transport Control

- (void)play {
    if (_audioEngine) {
        _audioEngine->play();
    }
}

- (void)stop {
    if (_audioEngine) {
        _audioEngine->stop();
    }
}

- (BOOL)isPlaying {
    if (_audioEngine) {
        return _audioEngine->isPlaying();
    }
    return NO;
}

// MARK: - Audio Processing

- (void)processAudioBuffer:(AudioBufferList *)audioBufferList
                frameCount:(UInt32)frameCount {
    if (!_audioEngine || !audioBufferList) return;

    // Convert AudioBufferList to JUCE AudioBuffer
    juce::AudioBuffer<float> buffer(audioBufferList->mNumberBuffers, frameCount);

    for (UInt32 channel = 0; channel < audioBufferList->mNumberBuffers; ++channel) {
        float *channelData = (float *)audioBufferList->mBuffers[channel].mData;
        buffer.copyFrom(channel, 0, channelData, frameCount);
    }

    // Process audio block (applies bio-reactive DSP)
    _audioEngine->processAudioBlock(buffer, frameCount);

    // Copy back to AudioBufferList
    for (UInt32 channel = 0; channel < audioBufferList->mNumberBuffers; ++channel) {
        float *channelData = (float *)audioBufferList->mBuffers[channel].mData;
        buffer.copyTo(channel, 0, channelData, frameCount);
    }
}

- (void)generateAudioBuffer:(AudioBufferList *)audioBufferList
                 frameCount:(UInt32)frameCount {
    if (!_audioEngine || !audioBufferList) return;

    // Create JUCE AudioBuffer
    juce::AudioBuffer<float> buffer(audioBufferList->mNumberBuffers, frameCount);
    buffer.clear();

    // Generate audio (instrument mode)
    // In full implementation: Call synthesizer/generator
    // For now: AudioEngine processes silence → bio-reactive effects
    _audioEngine->processAudioBlock(buffer, frameCount);

    // Copy to AudioBufferList
    for (UInt32 channel = 0; channel < audioBufferList->mNumberBuffers; ++channel) {
        float *channelData = (float *)audioBufferList->mBuffers[channel].mData;
        const float *sourceData = buffer.getReadPointer(channel);
        memcpy(channelData, sourceData, frameCount * sizeof(float));
    }
}

// MARK: - Bio-Reactive Parameters

- (void)setFilterCutoff:(float)cutoffHz {
    _filterCutoff.store(cutoffHz, std::memory_order_relaxed);
    // Note: AudioEngine reads from EchoelmusicBioReactive namespace
    // This would need to update those atomics as well
}

- (void)setReverbSize:(float)size {
    _reverbSize.store(size, std::memory_order_relaxed);
}

- (void)setDelayTime:(float)timeMs {
    _delayTime.store(timeMs, std::memory_order_relaxed);
}

- (void)setDelayFeedback:(float)feedback {
    _delayFeedback.store(feedback, std::memory_order_relaxed);
}

- (void)setModulationRate:(float)rateHz {
    _modulationRate.store(rateHz, std::memory_order_relaxed);
}

- (void)setModulationDepth:(float)depth {
    _modulationDepth.store(depth, std::memory_order_relaxed);
}

- (void)setBioVolume:(float)volume {
    _bioVolume.store(volume, std::memory_order_relaxed);
}

// MARK: - Biofeedback Data

- (void)updateHeartRate:(float)bpm {
    _heartRate.store(bpm, std::memory_order_relaxed);
}

- (void)updateHRV:(float)hrvMs {
    _hrvValue.store(hrvMs, std::memory_order_relaxed);
}

- (void)updateCoherence:(float)coherence {
    _coherence.store(coherence, std::memory_order_relaxed);
}

// MARK: - Preset Management

- (void)loadPreset:(int)presetIndex {
    switch (presetIndex) {
        case 0: // Relaxed State
            [self setFilterCutoff:800.0f];
            [self setReverbSize:0.7f];
            [self setModulationRate:0.5f];
            break;

        case 1: // Focused State
            [self setFilterCutoff:2000.0f];
            [self setReverbSize:0.3f];
            [self setModulationRate:2.0f];
            break;

        case 2: // Creative Flow
            [self setFilterCutoff:1500.0f];
            [self setReverbSize:0.5f];
            [self setModulationRate:1.5f];
            break;

        case 3: // Deep Meditation
            [self setFilterCutoff:400.0f];
            [self setReverbSize:0.9f];
            [self setModulationRate:0.2f];
            break;

        case 4: // High Energy
            [self setFilterCutoff:5000.0f];
            [self setReverbSize:0.2f];
            [self setModulationRate:5.0f];
            break;

        default:
            break;
    }

    NSLog(@"✅ EchoelmusicAUv3Bridge: Loaded preset %d", presetIndex);
}

- (void)saveState {
    // Save to App Group UserDefaults (shared with main app)
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.echoelmusic.shared"];

    [sharedDefaults setFloat:_filterCutoff.load() forKey:@"filterCutoff"];
    [sharedDefaults setFloat:_reverbSize.load() forKey:@"reverbSize"];
    [sharedDefaults setFloat:_delayTime.load() forKey:@"delayTime"];
    [sharedDefaults setFloat:_delayFeedback.load() forKey:@"delayFeedback"];
    [sharedDefaults setFloat:_modulationRate.load() forKey:@"modulationRate"];
    [sharedDefaults setFloat:_modulationDepth.load() forKey:@"modulationDepth"];
    [sharedDefaults setFloat:_bioVolume.load() forKey:@"bioVolume"];

    [sharedDefaults synchronize];

    NSLog(@"✅ EchoelmusicAUv3Bridge: State saved to App Group");
}

- (void)restoreState {
    // Restore from App Group UserDefaults
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.echoelmusic.shared"];

    if ([sharedDefaults objectForKey:@"filterCutoff"]) {
        _filterCutoff.store([sharedDefaults floatForKey:@"filterCutoff"], std::memory_order_relaxed);
        _reverbSize.store([sharedDefaults floatForKey:@"reverbSize"], std::memory_order_relaxed);
        _delayTime.store([sharedDefaults floatForKey:@"delayTime"], std::memory_order_relaxed);
        _delayFeedback.store([sharedDefaults floatForKey:@"delayFeedback"], std::memory_order_relaxed);
        _modulationRate.store([sharedDefaults floatForKey:@"modulationRate"], std::memory_order_relaxed);
        _modulationDepth.store([sharedDefaults floatForKey:@"modulationDepth"], std::memory_order_relaxed);
        _bioVolume.store([sharedDefaults floatForKey:@"bioVolume"], std::memory_order_relaxed);

        NSLog(@"✅ EchoelmusicAUv3Bridge: State restored from App Group");
    } else {
        NSLog(@"⚠️ EchoelmusicAUv3Bridge: No saved state found");
    }
}

@end

// MARK: - C++ Namespace for AudioEngine Integration

// These functions are called by AudioEngine.cpp::applyBioReactiveDSP()
namespace EchoelmusicBioReactive {
    float getFilterCutoffHz() {
        return [EchoelmusicAUv3Bridge.shared valueForKey:@"_filterCutoff"];
    }

    float getReverbSize() {
        return [EchoelmusicAUv3Bridge.shared valueForKey:@"_reverbSize"];
    }

    float getBioVolume() {
        return [EchoelmusicAUv3Bridge.shared valueForKey:@"_bioVolume"];
    }

    float getDelayTimeMs() {
        return [EchoelmusicAUv3Bridge.shared valueForKey:@"_delayTime"];
    }

    float getDelayFeedback() {
        return [EchoelmusicAUv3Bridge.shared valueForKey:@"_delayFeedback"];
    }

    float getModulationRateHz() {
        return [EchoelmusicAUv3Bridge.shared valueForKey:@"_modulationRate"];
    }

    float getModulationDepth() {
        return [EchoelmusicAUv3Bridge.shared valueForKey:@"_modulationDepth"];
    }

    // Additional parameters (not yet implemented in AudioEngine)
    float getReverbDecay() { return 0.5f; }
    float getDistortionAmount() { return 0.0f; }
    float getCompressorThresholdDb() { return -12.0f; }
    float getCompressorRatio() { return 4.0f; }
}
