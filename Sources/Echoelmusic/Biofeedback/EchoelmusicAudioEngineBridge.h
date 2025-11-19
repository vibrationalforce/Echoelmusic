//  EchoelmusicAudioEngineBridge.h
//  Echoelmusic
//
//  Objective-C++ bridge between Swift biofeedback and C++ audio engine
//  This header can be imported into Swift via bridging header
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C++ bridge to C++ AudioEngine
/// Provides thread-safe parameter updates from Swift to C++ audio thread
@interface EchoelmusicAudioEngineBridge : NSObject

// MARK: - Parameter Setters (Thread-Safe, Atomic)

/// Set filter cutoff frequency (Hz)
+ (void)setFilterCutoff:(float)frequency;

/// Set reverb size (0.0-1.0)
+ (void)setReverbSize:(float)size;

/// Set reverb decay time (seconds)
+ (void)setReverbDecay:(float)decay;

/// Set master volume (0.0-1.0)
+ (void)setMasterVolume:(float)volume;

/// Set delay time (milliseconds)
+ (void)setDelayTime:(float)timeMs;

/// Set delay feedback (0.0-1.0)
+ (void)setDelayFeedback:(float)feedback;

/// Set modulation rate (Hz)
+ (void)setModulationRate:(float)rateHz;

/// Set modulation depth (0.0-1.0)
+ (void)setModulationDepth:(float)depth;

/// Set distortion amount (0.0-1.0)
+ (void)setDistortionAmount:(float)amount;

/// Set compressor threshold (dB)
+ (void)setCompressorThreshold:(float)thresholdDb;

/// Set compressor ratio
+ (void)setCompressorRatio:(float)ratio;

/// Batch update bio-reactive parameters (more efficient than individual calls)
+ (void)setBioReactiveParameters:(float)filterCutoff
                      reverbSize:(float)reverbSize
                          volume:(float)volume
                       delayTime:(float)delayTime
                 modulationRate:(float)modulationRate;

// MARK: - State Query

/// Check if audio engine is initialized
+ (BOOL)isEngineInitialized;

/// Get current sample rate
+ (double)getCurrentSampleRate;

/// Enable/disable parameter change logging (for debugging)
+ (void)setParameterLogging:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
