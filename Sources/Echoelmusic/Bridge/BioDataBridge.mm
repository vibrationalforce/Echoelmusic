// BioDataBridge.mm - Swift ↔ C++ Biofeedback Data Bridge Implementation
// Copyright © 2025 Echoelmusic. All rights reserved.

#import "BioDataBridge.h"
#include <cmath>
#include <vector>
#include <mutex>
#include <algorithm>

#pragma mark - C++ Internal Implementation

namespace Echoel {
namespace BioData {

/// Internal C++ processor for bio-reactive audio
class BioProcessor {
public:
    BioProcessor() {
        reset();
    }

    void reset() {
        hrvBaseline = {60.0f, 50.0f, 30.0f, 45.0f, 15.0f, 1.5f};
        eegBaseline = {0.2f, 0.3f, 0.4f, 0.3f, 0.1f};
        gsrBaseline = 0.5f;
        breathingBaseline = 12.0f;

        calibrationData.clear();
        isCalibrated = false;
    }

    // Process biometric state and compute audio parameters
    BioAudioParams processState(const BioCombinedState& state, float sensitivity, float smoothing) {
        BioAudioParams params;

        // =============== HRV → Audio Mapping ===============
        if (state.hrv.isValid) {
            // HRV → Filter Resonance (higher HRV = more open, resonant sound)
            float hrvNorm = normalizeValue(state.hrv.hrv, hrvBaseline.hrv * 0.5f, hrvBaseline.hrv * 2.0f);
            params.filterResonance = lerp(0.1f, 0.9f, hrvNorm) * sensitivity;

            // Heart Rate → Tremolo Rate (subtle pulse with heartbeat)
            params.tremoloRate = state.hrv.heartRate / 60.0f; // Convert BPM to Hz

            // Stress (LF/HF ratio) → Distortion
            float stressNorm = normalizeValue(state.hrv.lfHfRatio, 0.5f, 4.0f);
            params.distortion = stressNorm * 0.3f * sensitivity;
        }

        // =============== EEG → Audio Mapping ===============
        if (state.eeg.isValid) {
            // Alpha waves → Reverb Size (relaxed = spacious)
            params.reverbSize = state.eeg.alpha * 0.8f * sensitivity;
            params.reverbDecay = 0.3f + (state.eeg.alpha * 0.5f);

            // Focus Level → Filter Cutoff (focus = brightness)
            params.filterCutoff = 200.0f + (state.eeg.focusLevel * 8000.0f * sensitivity);

            // Meditation Level → Delay Time (deeper = longer)
            params.delayTime = 0.1f + (state.eeg.meditationLevel * 0.9f);
            params.delayFeedback = 0.2f + (state.eeg.meditationLevel * 0.4f);
        } else {
            params.filterCutoff = 1000.0f;
            params.reverbSize = 0.3f;
            params.delayTime = 0.25f;
        }

        // =============== GSR → Audio Mapping ===============
        if (state.gsr.isValid) {
            // Arousal level adds to distortion
            params.distortion += state.gsr.arousalLevel * 0.2f * sensitivity;
            params.distortion = std::min(params.distortion, 1.0f);
        }

        // =============== Breathing → Audio Mapping ===============
        if (state.breathing.isValid) {
            // Breathing Rate → LFO Rate
            params.lfoRate = state.breathing.breathingRate / 60.0f; // Breaths/min to Hz

            // Breathing Depth → Chorus/LFO Depth
            params.lfoDepth = state.breathing.breathingDepth * 0.5f * sensitivity;
            params.chorusDepth = state.breathing.breathingDepth * 0.4f * sensitivity;

            // Coherence → Master Volume (coherent = more present)
            params.masterVolume = 0.5f + (state.breathing.coherenceScore * 0.5f);
        } else {
            params.lfoRate = 0.5f;
            params.lfoDepth = 0.2f;
            params.masterVolume = 0.7f;
        }

        // Apply smoothing to prevent sudden changes
        if (smoothing > 0.0f) {
            params = smoothParams(params, lastParams, smoothing);
        }

        lastParams = params;
        return params;
    }

    // Add calibration sample
    void addCalibrationSample(const BioCombinedState& state) {
        calibrationData.push_back(state);
    }

    // Finish calibration and compute baselines
    void finishCalibration() {
        if (calibrationData.empty()) return;

        float totalHR = 0, totalHRV = 0;
        float totalAlpha = 0, totalBeta = 0;
        float totalGSR = 0;
        float totalBreathRate = 0;
        int validHRV = 0, validEEG = 0, validGSR = 0, validBreath = 0;

        for (const auto& state : calibrationData) {
            if (state.hrv.isValid) {
                totalHR += state.hrv.heartRate;
                totalHRV += state.hrv.hrv;
                validHRV++;
            }
            if (state.eeg.isValid) {
                totalAlpha += state.eeg.alpha;
                totalBeta += state.eeg.beta;
                validEEG++;
            }
            if (state.gsr.isValid) {
                totalGSR += state.gsr.conductance;
                validGSR++;
            }
            if (state.breathing.isValid) {
                totalBreathRate += state.breathing.breathingRate;
                validBreath++;
            }
        }

        if (validHRV > 0) {
            hrvBaseline.heartRate = totalHR / validHRV;
            hrvBaseline.hrv = totalHRV / validHRV;
        }
        if (validEEG > 0) {
            eegBaseline.alpha = totalAlpha / validEEG;
            eegBaseline.beta = totalBeta / validEEG;
        }
        if (validGSR > 0) {
            gsrBaseline = totalGSR / validGSR;
        }
        if (validBreath > 0) {
            breathingBaseline = totalBreathRate / validBreath;
        }

        calibrationData.clear();
        isCalibrated = true;
    }

    bool isCalibrated = false;

private:
    struct HRVBaseline {
        float heartRate, hrv, rmssd, sdnn, pnn50, lfHf;
    } hrvBaseline;

    struct EEGBaseline {
        float delta, theta, alpha, beta, gamma;
    } eegBaseline;

    float gsrBaseline;
    float breathingBaseline;

    std::vector<BioCombinedState> calibrationData;
    BioAudioParams lastParams;

    float normalizeValue(float value, float min, float max) {
        return std::clamp((value - min) / (max - min), 0.0f, 1.0f);
    }

    float lerp(float a, float b, float t) {
        return a + t * (b - a);
    }

    BioAudioParams smoothParams(const BioAudioParams& current, const BioAudioParams& previous, float factor) {
        BioAudioParams smoothed;
        smoothed.filterCutoff = lerp(current.filterCutoff, previous.filterCutoff, factor);
        smoothed.filterResonance = lerp(current.filterResonance, previous.filterResonance, factor);
        smoothed.reverbSize = lerp(current.reverbSize, previous.reverbSize, factor);
        smoothed.reverbDecay = lerp(current.reverbDecay, previous.reverbDecay, factor);
        smoothed.lfoRate = lerp(current.lfoRate, previous.lfoRate, factor);
        smoothed.lfoDepth = lerp(current.lfoDepth, previous.lfoDepth, factor);
        smoothed.distortion = lerp(current.distortion, previous.distortion, factor);
        smoothed.masterVolume = lerp(current.masterVolume, previous.masterVolume, factor);
        smoothed.delayTime = lerp(current.delayTime, previous.delayTime, factor);
        smoothed.delayFeedback = lerp(current.delayFeedback, previous.delayFeedback, factor);
        smoothed.chorusDepth = lerp(current.chorusDepth, previous.chorusDepth, factor);
        smoothed.tremoloRate = lerp(current.tremoloRate, previous.tremoloRate, factor);
        return smoothed;
    }
};

} // namespace BioData
} // namespace Echoel

#pragma mark - Objective-C Implementation

@implementation BioDataBridge {
    Echoel::BioData::BioProcessor *_processor;
    BioCombinedState _currentState;
    BioAudioParams _currentParams;
    std::mutex _mutex;

    BioAudioParamsCallback _audioParamsCallback;
    BioCombinedStateCallback _stateCallback;

    BOOL _isCalibrating;
    NSDate *_calibrationStartTime;
}

+ (instancetype)shared {
    static BioDataBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BioDataBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _processor = new Echoel::BioData::BioProcessor();

        // Initialize state
        memset(&_currentState, 0, sizeof(_currentState));
        memset(&_currentParams, 0, sizeof(_currentParams));

        // Default configuration
        _sensitivity = 0.5f;
        _smoothing = 0.8f;
        _hrvEnabled = YES;
        _eegEnabled = YES;
        _gsrEnabled = YES;
        _breathingEnabled = YES;
        _motionEnabled = YES;
        _debugLoggingEnabled = NO;
        _isCalibrating = NO;
    }
    return self;
}

- (void)dealloc {
    delete _processor;
}

#pragma mark - Input Methods

- (void)updateHRVWithHeartRate:(float)bpm
                           hrv:(float)hrv
                         rmssd:(float)rmssd
                          sdnn:(float)sdnn
                         pnn50:(float)pnn50
                    lfHfRatio:(float)lfHfRatio {
    if (!_hrvEnabled) return;

    std::lock_guard<std::mutex> lock(_mutex);

    _currentState.hrv.heartRate = bpm;
    _currentState.hrv.hrv = hrv;
    _currentState.hrv.rmssd = rmssd;
    _currentState.hrv.sdnn = sdnn;
    _currentState.hrv.pnn50 = pnn50;
    _currentState.hrv.lfHfRatio = lfHfRatio;
    _currentState.hrv.isValid = YES;
    _currentState.timestamp = [[NSDate date] timeIntervalSince1970];

    [self processAndNotify];

    if (_debugLoggingEnabled) {
        NSLog(@"[BioDataBridge] HRV: HR=%.1f BPM, HRV=%.1f ms, RMSSD=%.1f", bpm, hrv, rmssd);
    }
}

- (void)updateEEGWithDelta:(float)delta
                    theta:(float)theta
                    alpha:(float)alpha
                     beta:(float)beta
                    gamma:(float)gamma {
    if (!_eegEnabled) return;

    std::lock_guard<std::mutex> lock(_mutex);

    _currentState.eeg.delta = delta;
    _currentState.eeg.theta = theta;
    _currentState.eeg.alpha = alpha;
    _currentState.eeg.beta = beta;
    _currentState.eeg.gamma = gamma;

    // Compute derived metrics
    _currentState.eeg.focusLevel = (beta * 0.7f) + ((1.0f - alpha) * 0.3f);
    _currentState.eeg.relaxationLevel = (alpha * 0.7f) + ((1.0f - beta) * 0.3f);
    _currentState.eeg.meditationLevel = (theta * 0.5f) + (alpha * 0.5f);

    // Clamp values
    _currentState.eeg.focusLevel = fminf(fmaxf(_currentState.eeg.focusLevel, 0.0f), 1.0f);
    _currentState.eeg.relaxationLevel = fminf(fmaxf(_currentState.eeg.relaxationLevel, 0.0f), 1.0f);
    _currentState.eeg.meditationLevel = fminf(fmaxf(_currentState.eeg.meditationLevel, 0.0f), 1.0f);

    _currentState.eeg.isValid = YES;
    _currentState.timestamp = [[NSDate date] timeIntervalSince1970];

    [self processAndNotify];

    if (_debugLoggingEnabled) {
        NSLog(@"[BioDataBridge] EEG: α=%.2f, β=%.2f, Focus=%.2f, Relax=%.2f",
              alpha, beta, _currentState.eeg.focusLevel, _currentState.eeg.relaxationLevel);
    }
}

- (void)updateGSRWithConductance:(float)conductance {
    if (!_gsrEnabled) return;

    std::lock_guard<std::mutex> lock(_mutex);

    _currentState.gsr.conductance = conductance;
    _currentState.gsr.arousalLevel = conductance; // Direct mapping
    _currentState.gsr.isValid = YES;
    _currentState.timestamp = [[NSDate date] timeIntervalSince1970];

    [self processAndNotify];
}

- (void)updateBreathingWithRate:(float)rate
                         depth:(float)depth
                    isInhaling:(BOOL)isInhaling {
    if (!_breathingEnabled) return;

    std::lock_guard<std::mutex> lock(_mutex);

    _currentState.breathing.breathingRate = rate;
    _currentState.breathing.breathingDepth = depth;
    _currentState.breathing.isInhaling = isInhaling;

    // Compute coherence (optimal is ~6 breaths/min)
    float optimalRate = 6.0f;
    float rateDeviation = fabsf(rate - optimalRate) / optimalRate;
    _currentState.breathing.coherenceScore = fmaxf(0.0f, 1.0f - rateDeviation);

    _currentState.breathing.isValid = YES;
    _currentState.timestamp = [[NSDate date] timeIntervalSince1970];

    [self processAndNotify];

    if (_debugLoggingEnabled) {
        NSLog(@"[BioDataBridge] Breathing: %.1f/min, Depth=%.2f, Coherence=%.2f",
              rate, depth, _currentState.breathing.coherenceScore);
    }
}

- (void)updateMotionWithAccelX:(float)accelX
                        accelY:(float)accelY
                        accelZ:(float)accelZ
                         rotX:(float)rotX
                         rotY:(float)rotY
                         rotZ:(float)rotZ {
    if (!_motionEnabled) return;

    std::lock_guard<std::mutex> lock(_mutex);

    _currentState.motion.accelerationX = accelX;
    _currentState.motion.accelerationY = accelY;
    _currentState.motion.accelerationZ = accelZ;
    _currentState.motion.rotationX = rotX;
    _currentState.motion.rotationY = rotY;
    _currentState.motion.rotationZ = rotZ;

    // Compute movement intensity
    float accelMag = sqrtf(accelX*accelX + accelY*accelY + accelZ*accelZ);
    float rotMag = sqrtf(rotX*rotX + rotY*rotY + rotZ*rotZ);
    _currentState.motion.movementIntensity = fminf((accelMag + rotMag * 0.5f) / 20.0f, 1.0f);

    _currentState.motion.isValid = YES;
    _currentState.timestamp = [[NSDate date] timeIntervalSince1970];

    [self processAndNotify];
}

#pragma mark - Output Methods

- (BioAudioParams)currentAudioParams {
    std::lock_guard<std::mutex> lock(_mutex);
    return _currentParams;
}

- (BioCombinedState)currentState {
    std::lock_guard<std::mutex> lock(_mutex);
    return _currentState;
}

#pragma mark - Callbacks

- (void)setAudioParamsCallback:(nullable BioAudioParamsCallback)callback {
    _audioParamsCallback = [callback copy];
}

- (void)setStateCallback:(nullable BioCombinedStateCallback)callback {
    _stateCallback = [callback copy];
}

#pragma mark - Calibration

- (void)startCalibration {
    std::lock_guard<std::mutex> lock(_mutex);
    _isCalibrating = YES;
    _calibrationStartTime = [NSDate date];
    _processor->reset();

    if (_debugLoggingEnabled) {
        NSLog(@"[BioDataBridge] Calibration started - recording 60 second baseline");
    }
}

- (void)stopCalibration {
    std::lock_guard<std::mutex> lock(_mutex);
    _isCalibrating = NO;
    _processor->finishCalibration();

    if (_debugLoggingEnabled) {
        NSLog(@"[BioDataBridge] Calibration complete");
    }
}

- (BOOL)isCalibrating {
    return _isCalibrating;
}

- (BOOL)isCalibrated {
    return _processor->isCalibrated;
}

#pragma mark - C++ Integration

- (void *)cppProcessorHandle {
    return _processor;
}

- (void)processAudioBuffer:(float *)buffer
               numSamples:(int)numSamples
              numChannels:(int)numChannels
               sampleRate:(double)sampleRate {
    // This method allows direct audio processing with bio parameters
    // Currently applies master volume and simple LFO

    BioAudioParams params = [self currentAudioParams];

    // Apply master volume
    float volume = params.masterVolume;

    // Simple LFO for demonstration
    static double lfoPhase = 0.0;
    double lfoIncrement = params.lfoRate / sampleRate;

    for (int sample = 0; sample < numSamples; ++sample) {
        float lfoValue = 1.0f - (params.lfoDepth * (0.5f + 0.5f * sinf(lfoPhase * 2.0 * M_PI)));

        for (int channel = 0; channel < numChannels; ++channel) {
            buffer[sample * numChannels + channel] *= volume * lfoValue;
        }

        lfoPhase += lfoIncrement;
        if (lfoPhase >= 1.0) lfoPhase -= 1.0;
    }
}

#pragma mark - Status & Debugging

- (NSString *)statusReport {
    std::lock_guard<std::mutex> lock(_mutex);

    NSMutableString *report = [NSMutableString string];
    [report appendString:@"🧬 BioDataBridge Status Report\n"];
    [report appendString:@"================================\n\n"];

    // HRV Status
    [report appendFormat:@"❤️  Heart Rate: %@\n", _hrvEnabled ? @"ENABLED" : @"DISABLED"];
    if (_currentState.hrv.isValid) {
        [report appendFormat:@"    HR: %.1f BPM | HRV: %.1f ms | RMSSD: %.1f\n",
         _currentState.hrv.heartRate, _currentState.hrv.hrv, _currentState.hrv.rmssd];
    }

    // EEG Status
    [report appendFormat:@"\n🧠 EEG: %@\n", _eegEnabled ? @"ENABLED" : @"DISABLED"];
    if (_currentState.eeg.isValid) {
        [report appendFormat:@"    α=%.2f β=%.2f θ=%.2f δ=%.2f γ=%.2f\n",
         _currentState.eeg.alpha, _currentState.eeg.beta, _currentState.eeg.theta,
         _currentState.eeg.delta, _currentState.eeg.gamma];
        [report appendFormat:@"    Focus: %.0f%% | Relax: %.0f%% | Meditation: %.0f%%\n",
         _currentState.eeg.focusLevel * 100, _currentState.eeg.relaxationLevel * 100,
         _currentState.eeg.meditationLevel * 100];
    }

    // Breathing Status
    [report appendFormat:@"\n🫁 Breathing: %@\n", _breathingEnabled ? @"ENABLED" : @"DISABLED"];
    if (_currentState.breathing.isValid) {
        [report appendFormat:@"    Rate: %.1f/min | Depth: %.0f%% | Coherence: %.0f%%\n",
         _currentState.breathing.breathingRate, _currentState.breathing.breathingDepth * 100,
         _currentState.breathing.coherenceScore * 100];
    }

    // Audio Parameters
    [report appendString:@"\n🎚️  Audio Parameters:\n"];
    [report appendFormat:@"    Filter: %.0f Hz @ %.2f Q\n", _currentParams.filterCutoff, _currentParams.filterResonance];
    [report appendFormat:@"    Reverb: %.0f%% size | %.0f%% decay\n", _currentParams.reverbSize * 100, _currentParams.reverbDecay * 100];
    [report appendFormat:@"    LFO: %.2f Hz @ %.0f%% depth\n", _currentParams.lfoRate, _currentParams.lfoDepth * 100];
    [report appendFormat:@"    Volume: %.0f%%\n", _currentParams.masterVolume * 100];

    // Calibration Status
    [report appendFormat:@"\n📊 Calibration: %@\n", _processor->isCalibrated ? @"✅ Complete" : @"❌ Not calibrated"];

    return report;
}

#pragma mark - Private Methods

- (void)processAndNotify {
    // Add to calibration if in progress
    if (_isCalibrating) {
        _processor->addCalibrationSample(_currentState);

        // Auto-stop after 60 seconds
        NSTimeInterval elapsed = -[_calibrationStartTime timeIntervalSinceNow];
        if (elapsed >= 60.0) {
            [self stopCalibration];
        }
    }

    // Process state and compute audio parameters
    _currentParams = _processor->processState(_currentState, _sensitivity, _smoothing);

    // Notify callbacks (on main thread)
    if (_audioParamsCallback) {
        BioAudioParams params = _currentParams;
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_audioParamsCallback(params);
        });
    }

    if (_stateCallback) {
        BioCombinedState state = _currentState;
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_stateCallback(state);
        });
    }
}

@end
