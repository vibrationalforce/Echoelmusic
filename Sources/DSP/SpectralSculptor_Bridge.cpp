/**
 * SpectralSculptor_Bridge.cpp
 * C-compatible wrapper implementations for SpectralSculptor
 */

#include "SpectralSculptor_Bridge.h"
#include "SpectralSculptor.cpp"  // Include the implementation directly (header-only style)

using namespace Echoelmusic::DSP;

extern "C" {

SpectralSculptorRef SpectralSculptor_Create(void) {
    return new SpectralSculptor();
}

void SpectralSculptor_Destroy(SpectralSculptorRef ref) {
    delete static_cast<SpectralSculptor*>(ref);
}

void SpectralSculptor_SetSampleRate(SpectralSculptorRef ref, float sampleRate) {
    static_cast<SpectralSculptor*>(ref)->setSampleRate(sampleRate);
}

void SpectralSculptor_SetMode(SpectralSculptorRef ref, SpectralProcessingMode mode) {
    static_cast<SpectralSculptor*>(ref)->setMode(static_cast<SpectralMode>(mode));
}

void SpectralSculptor_SetBlurAmount(SpectralSculptorRef ref, float amount) {
    static_cast<SpectralSculptor*>(ref)->setBlurAmount(amount);
}

void SpectralSculptor_SetFrequencyShift(SpectralSculptorRef ref, float shiftHz) {
    static_cast<SpectralSculptor*>(ref)->setFrequencyShift(shiftHz);
}

void SpectralSculptor_SetGateThreshold(SpectralSculptorRef ref, float thresholdDb) {
    static_cast<SpectralSculptor*>(ref)->setGateThreshold(thresholdDb);
}

void SpectralSculptor_SetFilterCutoff(SpectralSculptorRef ref, float cutoffHz) {
    static_cast<SpectralSculptor*>(ref)->setFilterCutoff(cutoffHz);
}

void SpectralSculptor_SetFilterResonance(SpectralSculptorRef ref, float q) {
    static_cast<SpectralSculptor*>(ref)->setFilterResonance(q);
}

void SpectralSculptor_SetHarmonicBoost(SpectralSculptorRef ref, float boostDb) {
    static_cast<SpectralSculptor*>(ref)->setHarmonicBoost(boostDb);
}

void SpectralSculptor_SetRobotizePitch(SpectralSculptorRef ref, float pitchHz) {
    static_cast<SpectralSculptor*>(ref)->setRobotizePitch(pitchHz);
}

void SpectralSculptor_SetFreeze(SpectralSculptorRef ref, bool freeze) {
    static_cast<SpectralSculptor*>(ref)->setFreeze(freeze);
}

void SpectralSculptor_SetBioModulation(SpectralSculptorRef ref, float coherence, float heartRate, float breathPhase) {
    static_cast<SpectralSculptor*>(ref)->setBioModulation(coherence, heartRate, breathPhase);
}

void SpectralSculptor_Process(SpectralSculptorRef ref, float* input, float* output, int numSamples) {
    static_cast<SpectralSculptor*>(ref)->process(input, output, numSamples);
}

} // extern "C"
