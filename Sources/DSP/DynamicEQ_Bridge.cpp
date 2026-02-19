/**
 * DynamicEQ_Bridge.cpp
 * C-compatible wrapper implementations for DynamicEQ
 */

#include "DynamicEQ_Bridge.h"
#include "DynamicEQ.cpp"  // Include the implementation directly (header-only style)

using namespace Echoelmusic::DSP;

extern "C" {

DynamicEQRef DynamicEQ_Create(void) {
    return new DynamicEQ();
}

void DynamicEQ_Destroy(DynamicEQRef ref) {
    delete static_cast<DynamicEQ*>(ref);
}

void DynamicEQ_SetSampleRate(DynamicEQRef ref, float sampleRate) {
    static_cast<DynamicEQ*>(ref)->setSampleRate(sampleRate);
}

void DynamicEQ_SetBandEnabled(DynamicEQRef ref, int band, bool enabled) {
    static_cast<DynamicEQ*>(ref)->setBandEnabled(band, enabled);
}

void DynamicEQ_SetBandType(DynamicEQRef ref, int band, DynEQFilterType type) {
    static_cast<DynamicEQ*>(ref)->setBandType(band, static_cast<FilterType>(type));
}

void DynamicEQ_SetBandFrequency(DynamicEQRef ref, int band, float freq) {
    static_cast<DynamicEQ*>(ref)->setBandFrequency(band, freq);
}

void DynamicEQ_SetBandGain(DynamicEQRef ref, int band, float gainDb) {
    static_cast<DynamicEQ*>(ref)->setBandGain(band, gainDb);
}

void DynamicEQ_SetBandQ(DynamicEQRef ref, int band, float q) {
    static_cast<DynamicEQ*>(ref)->setBandQ(band, q);
}

void DynamicEQ_SetBandDynamicEnabled(DynamicEQRef ref, int band, bool enabled) {
    static_cast<DynamicEQ*>(ref)->setBandDynamicEnabled(band, enabled);
}

void DynamicEQ_SetBandThreshold(DynamicEQRef ref, int band, float thresholdDb) {
    static_cast<DynamicEQ*>(ref)->setBandThreshold(band, thresholdDb);
}

void DynamicEQ_SetBandRatio(DynamicEQRef ref, int band, float ratio) {
    static_cast<DynamicEQ*>(ref)->setBandRatio(band, ratio);
}

void DynamicEQ_SetBandAttack(DynamicEQRef ref, int band, float attackMs) {
    static_cast<DynamicEQ*>(ref)->setBandAttack(band, attackMs);
}

void DynamicEQ_SetBandRelease(DynamicEQRef ref, int band, float releaseMs) {
    static_cast<DynamicEQ*>(ref)->setBandRelease(band, releaseMs);
}

void DynamicEQ_SetBioModulation(DynamicEQRef ref, float coherence, float heartRate, float breathPhase) {
    static_cast<DynamicEQ*>(ref)->setBioModulation(coherence, heartRate, breathPhase);
}

void DynamicEQ_SetBioModulationEnabled(DynamicEQRef ref, bool enabled) {
    static_cast<DynamicEQ*>(ref)->setBioModulationEnabled(enabled);
}

void DynamicEQ_Process(DynamicEQRef ref, float* leftChannel, float* rightChannel, int numSamples) {
    static_cast<DynamicEQ*>(ref)->process(leftChannel, rightChannel, numSamples);
}

} // extern "C"
