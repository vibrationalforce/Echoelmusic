// EchoelmusicAUv3Bridge.h
// Objective-C++ Bridge for AUv3 ↔ C++ AudioEngine Integration
//
// This header exposes C++ AudioEngine functionality to Swift AUv3 code
// via Objective-C++ bridging. Include this in your Bridging Header.
//
// Usage in Xcode:
// 1. Add this file to AUv3 Extension target
// 2. Add to Bridging Header: #import "EchoelmusicAUv3Bridge.h"
// 3. Call from Swift: EchoelmusicAUv3Bridge.shared.prepare(sampleRate: 48000, blockSize: 512)

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C wrapper for C++ AudioEngine (for Swift interop)
@interface EchoelmusicAUv3Bridge : NSObject

/// Shared singleton instance
@property (class, readonly, strong) EchoelmusicAUv3Bridge *shared;

// MARK: - Audio Engine Lifecycle

/// Prepare audio engine with sample rate and block size
- (void)prepareWithSampleRate:(double)sampleRate blockSize:(int)blockSize;

/// Release audio engine resources
- (void)releaseResources;

// MARK: - Transport Control

/// Start playback
- (void)play;

/// Stop playback
- (void)stop;

/// Check if playing
- (BOOL)isPlaying;

// MARK: - Audio Processing

/// Process audio buffer (effect mode)
/// @param audioBufferList Input/output audio buffer
/// @param frameCount Number of frames to process
- (void)processAudioBuffer:(AudioBufferList *)audioBufferList
                frameCount:(UInt32)frameCount;

/// Generate audio (instrument mode)
/// @param audioBufferList Output audio buffer
/// @param frameCount Number of frames to generate
- (void)generateAudioBuffer:(AudioBufferList *)audioBufferList
                 frameCount:(UInt32)frameCount;

// MARK: - Bio-Reactive Parameters

/// Set filter cutoff frequency (Hz)
- (void)setFilterCutoff:(float)cutoffHz;

/// Set reverb size (0.0 - 1.0)
- (void)setReverbSize:(float)size;

/// Set delay time (milliseconds)
- (void)setDelayTime:(float)timeMs;

/// Set delay feedback (0.0 - 0.95)
- (void)setDelayFeedback:(float)feedback;

/// Set modulation rate (Hz)
- (void)setModulationRate:(float)rateHz;

/// Set modulation depth (0.0 - 1.0)
- (void)setModulationDepth:(float)depth;

/// Set bio volume (0.0 - 1.0)
- (void)setBioVolume:(float)volume;

// MARK: - Biofeedback Data

/// Update heart rate (BPM)
- (void)updateHeartRate:(float)bpm;

/// Update HRV value (milliseconds)
- (void)updateHRV:(float)hrvMs;

/// Update cardiac coherence (0.0 - 1.0)
- (void)updateCoherence:(float)coherence;

// MARK: - Preset Management

/// Load factory preset by index
/// @param presetIndex Preset number (0-4)
- (void)loadPreset:(int)presetIndex;

/// Save current state to UserDefaults (App Group)
- (void)saveState;

/// Restore state from UserDefaults (App Group)
- (void)restoreState;

@end

NS_ASSUME_NONNULL_END
