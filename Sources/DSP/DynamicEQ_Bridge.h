/**
 * DynamicEQ_Bridge.h
 * C-compatible bridge for DynamicEQ.cpp
 *
 * Allows Swift to call the C++ DynamicEQ via opaque pointer.
 * Used by AUv3 plugins for host-automatable dynamic EQ.
 */

#ifndef DYNAMIC_EQ_BRIDGE_H
#define DYNAMIC_EQ_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

/// Opaque handle to a DynamicEQ instance
typedef void* DynamicEQRef;

/// Filter types matching C++ FilterType enum
typedef enum {
    DynEQ_Bell = 0,
    DynEQ_LowShelf,
    DynEQ_HighShelf,
    DynEQ_LowCut,
    DynEQ_HighCut,
    DynEQ_Notch,
    DynEQ_BandPass,
    DynEQ_TiltShelf
} DynEQFilterType;

/// Create a new DynamicEQ instance
DynamicEQRef DynamicEQ_Create(void);

/// Destroy a DynamicEQ instance
void DynamicEQ_Destroy(DynamicEQRef ref);

/// Set sample rate
void DynamicEQ_SetSampleRate(DynamicEQRef ref, float sampleRate);

/// Per-band configuration
void DynamicEQ_SetBandEnabled(DynamicEQRef ref, int band, bool enabled);
void DynamicEQ_SetBandType(DynamicEQRef ref, int band, DynEQFilterType type);
void DynamicEQ_SetBandFrequency(DynamicEQRef ref, int band, float freq);
void DynamicEQ_SetBandGain(DynamicEQRef ref, int band, float gainDb);
void DynamicEQ_SetBandQ(DynamicEQRef ref, int band, float q);

/// Per-band dynamics
void DynamicEQ_SetBandDynamicEnabled(DynamicEQRef ref, int band, bool enabled);
void DynamicEQ_SetBandThreshold(DynamicEQRef ref, int band, float thresholdDb);
void DynamicEQ_SetBandRatio(DynamicEQRef ref, int band, float ratio);
void DynamicEQ_SetBandAttack(DynamicEQRef ref, int band, float attackMs);
void DynamicEQ_SetBandRelease(DynamicEQRef ref, int band, float releaseMs);

/// Bio-reactive modulation
void DynamicEQ_SetBioModulation(DynamicEQRef ref, float coherence, float heartRate, float breathPhase);
void DynamicEQ_SetBioModulationEnabled(DynamicEQRef ref, bool enabled);

/// Process stereo audio in-place
void DynamicEQ_Process(DynamicEQRef ref, float* leftChannel, float* rightChannel, int numSamples);

#ifdef __cplusplus
}
#endif

#endif /* DYNAMIC_EQ_BRIDGE_H */
