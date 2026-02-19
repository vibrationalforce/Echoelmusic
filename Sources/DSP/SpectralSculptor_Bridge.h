/**
 * SpectralSculptor_Bridge.h
 * C-compatible bridge for SpectralSculptor.cpp
 *
 * Allows Swift to call the C++ SpectralSculptor via opaque pointer.
 * Used by AUv3 plugins for spectral processing effects.
 */

#ifndef SPECTRAL_SCULPTOR_BRIDGE_H
#define SPECTRAL_SCULPTOR_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

/// Opaque handle to a SpectralSculptor instance
typedef void* SpectralSculptorRef;

/// Processing modes matching C++ SpectralMode enum
typedef enum {
    Spectral_Bypass = 0,
    Spectral_Freeze,
    Spectral_Blur,
    Spectral_FrequencyShift,
    Spectral_SpectralGate,
    Spectral_SpectralFilter,
    Spectral_HarmonicEnhance,
    Spectral_Robotize,
    Spectral_Whisper,
    Spectral_BioReactive
} SpectralProcessingMode;

/// Create a new SpectralSculptor instance
SpectralSculptorRef SpectralSculptor_Create(void);

/// Destroy a SpectralSculptor instance
void SpectralSculptor_Destroy(SpectralSculptorRef ref);

/// Set sample rate
void SpectralSculptor_SetSampleRate(SpectralSculptorRef ref, float sampleRate);

/// Set processing mode
void SpectralSculptor_SetMode(SpectralSculptorRef ref, SpectralProcessingMode mode);

/// Parameter control
void SpectralSculptor_SetBlurAmount(SpectralSculptorRef ref, float amount);
void SpectralSculptor_SetFrequencyShift(SpectralSculptorRef ref, float shiftHz);
void SpectralSculptor_SetGateThreshold(SpectralSculptorRef ref, float thresholdDb);
void SpectralSculptor_SetFilterCutoff(SpectralSculptorRef ref, float cutoffHz);
void SpectralSculptor_SetFilterResonance(SpectralSculptorRef ref, float q);
void SpectralSculptor_SetHarmonicBoost(SpectralSculptorRef ref, float boostDb);
void SpectralSculptor_SetRobotizePitch(SpectralSculptorRef ref, float pitchHz);
void SpectralSculptor_SetFreeze(SpectralSculptorRef ref, bool freeze);

/// Bio-reactive modulation
void SpectralSculptor_SetBioModulation(SpectralSculptorRef ref, float coherence, float heartRate, float breathPhase);

/// Process mono audio (input → output)
void SpectralSculptor_Process(SpectralSculptorRef ref, float* input, float* output, int numSamples);

#ifdef __cplusplus
}
#endif

#endif /* SPECTRAL_SCULPTOR_BRIDGE_H */
