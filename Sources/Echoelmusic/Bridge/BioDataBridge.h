// BioDataBridge.h - Swift ↔ C++ Biofeedback Data Bridge
// Connects iOS HealthKit/CoreMotion data to C++ DSP processing
// Copyright © 2025 Echoelmusic. All rights reserved.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Data Structures

/// Heart Rate Variability metrics from HealthKit
typedef struct {
    float heartRate;        // BPM (beats per minute)
    float hrv;              // Heart Rate Variability (ms)
    float rmssd;            // Root Mean Square of Successive Differences
    float sdnn;             // Standard Deviation of NN intervals
    float pnn50;            // Percentage of successive RR > 50ms
    float lfHfRatio;        // Low/High Frequency ratio (stress indicator)
    BOOL isValid;           // Data validity flag
} BioHRVData;

/// EEG brainwave data (from compatible headsets: Muse, OpenBCI, etc.)
typedef struct {
    float delta;            // 0.5-4 Hz (deep sleep)
    float theta;            // 4-8 Hz (meditation, creativity)
    float alpha;            // 8-13 Hz (relaxed, calm)
    float beta;             // 13-30 Hz (focused, alert)
    float gamma;            // 30-100 Hz (high cognitive function)
    float focusLevel;       // Computed focus (0.0-1.0)
    float relaxationLevel;  // Computed relaxation (0.0-1.0)
    float meditationLevel;  // Computed meditation depth (0.0-1.0)
    BOOL isValid;
} BioEEGData;

/// Galvanic Skin Response (electrodermal activity)
typedef struct {
    float conductance;      // Skin conductance level
    float stressIndex;      // Computed stress (0.0-1.0)
    float arousalLevel;     // Emotional arousal (0.0-1.0)
    BOOL isValid;
} BioGSRData;

/// Breathing/Respiration data from Apple Watch or breath sensors
typedef struct {
    float breathingRate;    // Breaths per minute
    float breathingDepth;   // Depth (0.0-1.0)
    float coherenceScore;   // HRV-breathing coherence (0.0-1.0)
    BOOL isInhaling;        // Current breath phase
    BOOL isValid;
} BioBreathingData;

/// Motion data from CoreMotion
typedef struct {
    float accelerationX;
    float accelerationY;
    float accelerationZ;
    float rotationX;
    float rotationY;
    float rotationZ;
    float movementIntensity; // Computed (0.0-1.0)
    BOOL isValid;
} BioMotionData;

/// Combined biometric state
typedef struct {
    BioHRVData hrv;
    BioEEGData eeg;
    BioGSRData gsr;
    BioBreathingData breathing;
    BioMotionData motion;
    double timestamp;       // Unix timestamp
} BioCombinedState;

/// Audio parameters derived from biometric data
typedef struct {
    float filterCutoff;     // Hz (mapped from focus)
    float filterResonance;  // 0.0-1.0 (mapped from HRV)
    float reverbSize;       // 0.0-1.0 (mapped from alpha waves)
    float reverbDecay;      // 0.0-1.0
    float lfoRate;          // Hz (mapped from breathing)
    float lfoDepth;         // 0.0-1.0
    float distortion;       // 0.0-1.0 (mapped from stress)
    float masterVolume;     // 0.0-1.0 (mapped from coherence)
    float delayTime;        // seconds (mapped from relaxation)
    float delayFeedback;    // 0.0-1.0
    float chorusDepth;      // 0.0-1.0 (mapped from breathing depth)
    float tremoloRate;      // Hz (mapped from heart rate)
} BioAudioParams;

#pragma mark - Callback Types

/// Callback when audio parameters are updated
typedef void (^BioAudioParamsCallback)(BioAudioParams params);

/// Callback for raw biometric data
typedef void (^BioCombinedStateCallback)(BioCombinedState state);

#pragma mark - BioDataBridge Interface

@interface BioDataBridge : NSObject

/// Singleton instance
+ (instancetype)shared;

#pragma mark - Input: Receive data from Swift/HealthKit

/// Update heart rate data
- (void)updateHRVWithHeartRate:(float)bpm
                           hrv:(float)hrv
                         rmssd:(float)rmssd
                          sdnn:(float)sdnn
                         pnn50:(float)pnn50
                    lfHfRatio:(float)lfHfRatio;

/// Update EEG data
- (void)updateEEGWithDelta:(float)delta
                    theta:(float)theta
                    alpha:(float)alpha
                     beta:(float)beta
                    gamma:(float)gamma;

/// Update GSR/electrodermal data
- (void)updateGSRWithConductance:(float)conductance;

/// Update breathing data
- (void)updateBreathingWithRate:(float)rate
                         depth:(float)depth
                    isInhaling:(BOOL)isInhaling;

/// Update motion data
- (void)updateMotionWithAccelX:(float)accelX
                        accelY:(float)accelY
                        accelZ:(float)accelZ
                         rotX:(float)rotX
                         rotY:(float)rotY
                         rotZ:(float)rotZ;

#pragma mark - Output: Computed audio parameters

/// Get current computed audio parameters
- (BioAudioParams)currentAudioParams;

/// Get current combined biometric state
- (BioCombinedState)currentState;

#pragma mark - Callbacks

/// Set callback for audio parameter updates
- (void)setAudioParamsCallback:(nullable BioAudioParamsCallback)callback;

/// Set callback for biometric state updates
- (void)setStateCallback:(nullable BioCombinedStateCallback)callback;

#pragma mark - Calibration

/// Start calibration (60 seconds baseline recording)
- (void)startCalibration;

/// Stop calibration and compute baseline
- (void)stopCalibration;

/// Check if calibration is in progress
@property (nonatomic, readonly) BOOL isCalibrating;

/// Check if calibration is complete
@property (nonatomic, readonly) BOOL isCalibrated;

#pragma mark - Configuration

/// Sensitivity for bio-reactive mapping (0.0-1.0, default 0.5)
@property (nonatomic) float sensitivity;

/// Smoothing factor for parameter changes (0.0-1.0, default 0.8)
@property (nonatomic) float smoothing;

/// Enable/disable specific sensors
@property (nonatomic) BOOL hrvEnabled;
@property (nonatomic) BOOL eegEnabled;
@property (nonatomic) BOOL gsrEnabled;
@property (nonatomic) BOOL breathingEnabled;
@property (nonatomic) BOOL motionEnabled;

#pragma mark - C++ Integration

/// Get pointer to internal C++ processor (for direct DSP integration)
- (void *)cppProcessorHandle;

/// Process audio buffer with current bio parameters
- (void)processAudioBuffer:(float *)buffer
               numSamples:(int)numSamples
              numChannels:(int)numChannels
               sampleRate:(double)sampleRate;

#pragma mark - Status & Debugging

/// Get human-readable status report
- (NSString *)statusReport;

/// Enable debug logging
@property (nonatomic) BOOL debugLoggingEnabled;

@end

NS_ASSUME_NONNULL_END
