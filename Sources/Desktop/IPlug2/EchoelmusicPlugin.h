#pragma once

/**
 * Echoelmusic Desktop Plugin - iPlug2 Implementation
 *
 * MIT License - No JUCE dependency!
 * Supports: VST3, AU, AAX, CLAP, Standalone
 *
 * Features:
 * - Bio-Reactive DSP (HRV → Audio Parameters)
 * - Professional Synthesis Engine
 * - Multi-format plugin export
 */

#include "IPlug_include_in_plug_hdr.h"
#include "IControls.h"

// Include our JUCE-free DSP
#include "../DSP/EchoelmusicDSP.h"

// Plugin configuration
const int kNumPresets = 64;
const int kNumParams = 32;

// Parameter IDs
enum EParams
{
    // Oscillator 1
    kOsc1Waveform = 0,
    kOsc1Octave,
    kOsc1Semitones,
    kOsc1Detune,
    kOsc1Level,

    // Oscillator 2
    kOsc2Waveform,
    kOsc2Octave,
    kOsc2Semitones,
    kOsc2Detune,
    kOsc2Level,
    kOsc2Mix,

    // Filter
    kFilterCutoff,
    kFilterResonance,
    kFilterEnvAmount,
    kFilterKeyTrack,

    // Amp Envelope
    kAmpAttack,
    kAmpDecay,
    kAmpSustain,
    kAmpRelease,

    // Filter Envelope
    kFilterAttack,
    kFilterDecay,
    kFilterSustain,
    kFilterRelease,

    // LFO
    kLFORate,
    kLFODepth,
    kLFOWaveform,
    kLFOToPitch,
    kLFOToFilter,
    kLFOToAmp,

    // Bio-Reactive
    kBioHRV,
    kBioCoherence,
    kBioHeartRate,

    kNumParams
};

// Control Tags for UI
enum EControlTags
{
    kCtrlTagMeter = 0,
    kCtrlTagScope,
    kCtrlTagBioDisplay,
    kNumCtrlTags
};

using namespace iplug;
using namespace igraphics;

class EchoelmusicPlugin final : public Plugin
{
public:
    EchoelmusicPlugin(const InstanceInfo& info);
    ~EchoelmusicPlugin();

    // Audio Processing
    void ProcessBlock(sample** inputs, sample** outputs, int nFrames) override;
    void ProcessMidiMsg(const IMidiMsg& msg) override;
    void OnReset() override;
    void OnParamChange(int paramIdx) override;

    // State
    bool SerializeState(IByteChunk& chunk) const override;
    int UnserializeState(const IByteChunk& chunk, int startPos) override;

    // Bio-Reactive Interface
    void UpdateBioData(float hrv, float coherence, float heartRate);

    // Preset Management
    void MakePreset(const char* name, ...);
    void MakeDefaultPreset();

private:
    // DSP Engine (JUCE-free!)
    EchoelmusicDSP mDSP;

    // Voice Management
    static const int kMaxVoices = 16;

    // Bio-Reactive State
    float mCurrentHRV = 0.5f;
    float mCurrentCoherence = 0.5f;
    float mCurrentHeartRate = 70.0f;

    // Parameter smoothing
    float mFilterCutoffSmooth = 1000.0f;
    float mFilterResonanceSmooth = 0.5f;

    // Metering
    float mOutputLevelL = 0.0f;
    float mOutputLevelR = 0.0f;

    // Internal
    void InitParameters();
    void InitPresets();
    void InitGraphics();
    void ApplyBioModulation();
};
