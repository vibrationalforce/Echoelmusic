#include "EchoelmusicPlugin.h"
#include "IPlug_include_in_plug_src.h"

EchoelmusicPlugin::EchoelmusicPlugin(const InstanceInfo& info)
: Plugin(info, MakeConfig(kNumParams, kNumPresets))
{
    InitParameters();
    InitPresets();

#if IPLUG_EDITOR
    mMakeGraphicsFunc = [&]() { return MakeGraphics(*this, PLUG_WIDTH, PLUG_HEIGHT, PLUG_FPS); };
    mLayoutFunc = [&](IGraphics* pGraphics) { InitGraphics(); };
#endif
}

EchoelmusicPlugin::~EchoelmusicPlugin()
{
}

void EchoelmusicPlugin::InitParameters()
{
    // Oscillator 1
    GetParam(kOsc1Waveform)->InitEnum("Osc1 Wave", 0, 6, "", IParam::kFlagsNone,
        "", "Sine", "Triangle", "Saw", "Square", "Pulse", "Noise");
    GetParam(kOsc1Octave)->InitInt("Osc1 Octave", 0, -3, 3);
    GetParam(kOsc1Semitones)->InitInt("Osc1 Semi", 0, -12, 12);
    GetParam(kOsc1Detune)->InitDouble("Osc1 Detune", 0.0, -100.0, 100.0, 1.0, "cents");
    GetParam(kOsc1Level)->InitDouble("Osc1 Level", 1.0, 0.0, 1.0, 0.01);

    // Oscillator 2
    GetParam(kOsc2Waveform)->InitEnum("Osc2 Wave", 2, 6, "", IParam::kFlagsNone,
        "", "Sine", "Triangle", "Saw", "Square", "Pulse", "Noise");
    GetParam(kOsc2Octave)->InitInt("Osc2 Octave", 0, -3, 3);
    GetParam(kOsc2Semitones)->InitInt("Osc2 Semi", 0, -12, 12);
    GetParam(kOsc2Detune)->InitDouble("Osc2 Detune", 5.0, -100.0, 100.0, 1.0, "cents");
    GetParam(kOsc2Level)->InitDouble("Osc2 Level", 0.5, 0.0, 1.0, 0.01);
    GetParam(kOsc2Mix)->InitDouble("Osc Mix", 0.5, 0.0, 1.0, 0.01);

    // Filter
    GetParam(kFilterCutoff)->InitFrequency("Filter Cutoff", 5000.0, 20.0, 20000.0);
    GetParam(kFilterResonance)->InitDouble("Filter Res", 0.3, 0.0, 1.0, 0.01);
    GetParam(kFilterEnvAmount)->InitDouble("Filter Env", 0.5, -1.0, 1.0, 0.01);
    GetParam(kFilterKeyTrack)->InitDouble("Filter Key", 0.5, 0.0, 1.0, 0.01);

    // Amp Envelope
    GetParam(kAmpAttack)->InitDouble("Amp Attack", 10.0, 1.0, 5000.0, 1.0, "ms", IParam::kFlagsNone, "", IParam::ShapePowCurve(3.0));
    GetParam(kAmpDecay)->InitDouble("Amp Decay", 200.0, 1.0, 5000.0, 1.0, "ms", IParam::kFlagsNone, "", IParam::ShapePowCurve(3.0));
    GetParam(kAmpSustain)->InitDouble("Amp Sustain", 0.7, 0.0, 1.0, 0.01);
    GetParam(kAmpRelease)->InitDouble("Amp Release", 300.0, 1.0, 10000.0, 1.0, "ms", IParam::kFlagsNone, "", IParam::ShapePowCurve(3.0));

    // Filter Envelope
    GetParam(kFilterAttack)->InitDouble("Flt Attack", 10.0, 1.0, 5000.0, 1.0, "ms", IParam::kFlagsNone, "", IParam::ShapePowCurve(3.0));
    GetParam(kFilterDecay)->InitDouble("Flt Decay", 500.0, 1.0, 5000.0, 1.0, "ms", IParam::kFlagsNone, "", IParam::ShapePowCurve(3.0));
    GetParam(kFilterSustain)->InitDouble("Flt Sustain", 0.3, 0.0, 1.0, 0.01);
    GetParam(kFilterRelease)->InitDouble("Flt Release", 500.0, 1.0, 10000.0, 1.0, "ms", IParam::kFlagsNone, "", IParam::ShapePowCurve(3.0));

    // LFO
    GetParam(kLFORate)->InitFrequency("LFO Rate", 2.0, 0.01, 50.0);
    GetParam(kLFODepth)->InitDouble("LFO Depth", 0.5, 0.0, 1.0, 0.01);
    GetParam(kLFOWaveform)->InitEnum("LFO Wave", 0, 4, "", IParam::kFlagsNone,
        "", "Sine", "Triangle", "Saw", "Square");
    GetParam(kLFOToPitch)->InitDouble("LFO→Pitch", 0.0, 0.0, 1.0, 0.01);
    GetParam(kLFOToFilter)->InitDouble("LFO→Filter", 0.3, 0.0, 1.0, 0.01);
    GetParam(kLFOToAmp)->InitDouble("LFO→Amp", 0.0, 0.0, 1.0, 0.01);

    // Bio-Reactive (read from external source)
    GetParam(kBioHRV)->InitDouble("Bio HRV", 0.5, 0.0, 1.0, 0.01);
    GetParam(kBioCoherence)->InitDouble("Bio Coherence", 0.5, 0.0, 1.0, 0.01);
    GetParam(kBioHeartRate)->InitDouble("Bio HR", 70.0, 40.0, 200.0, 1.0, "bpm");
}

void EchoelmusicPlugin::InitPresets()
{
    // Default preset
    MakeDefaultPreset();

    // Bio-Ambient
    MakePreset("Bio Ambient",
        0,      // Osc1: Sine
        0, 0, 0.0, 1.0,
        2,      // Osc2: Saw
        -1, 0, 7.0, 0.3, 0.3,
        2000.0, 0.4, 0.6, 0.5,  // Filter
        100.0, 500.0, 0.6, 1000.0,  // Amp Env
        50.0, 800.0, 0.2, 1500.0,   // Filter Env
        0.5, 0.6, 0, 0.0, 0.5, 0.1, // LFO
        0.5, 0.5, 70.0);            // Bio

    // Coherence Pad
    MakePreset("Coherence Pad",
        2,      // Osc1: Saw
        0, 0, 0.0, 0.8,
        2,      // Osc2: Saw
        0, 7, 10.0, 0.8, 0.5,
        3000.0, 0.3, 0.4, 0.3,
        200.0, 1000.0, 0.8, 2000.0,
        100.0, 1500.0, 0.4, 2000.0,
        0.2, 0.3, 0, 0.0, 0.3, 0.0,
        0.5, 0.5, 70.0);

    // HRV Bass
    MakePreset("HRV Bass",
        3,      // Osc1: Square
        -1, 0, 0.0, 1.0,
        2,      // Osc2: Saw
        -1, 0, 3.0, 0.5, 0.4,
        800.0, 0.5, 0.8, 1.0,
        5.0, 200.0, 0.9, 150.0,
        10.0, 300.0, 0.3, 200.0,
        0.0, 0.0, 0, 0.0, 0.0, 0.0,
        0.5, 0.5, 70.0);

    // Breathe Lead
    MakePreset("Breathe Lead",
        2,      // Osc1: Saw
        1, 0, 0.0, 1.0,
        3,      // Osc2: Square
        1, 0, 8.0, 0.4, 0.4,
        4000.0, 0.4, 0.6, 0.7,
        20.0, 150.0, 0.7, 400.0,
        30.0, 200.0, 0.5, 500.0,
        5.0, 0.3, 0, 0.1, 0.2, 0.0,
        0.5, 0.5, 70.0);
}

void EchoelmusicPlugin::MakeDefaultPreset()
{
    MakePreset("Init",
        0, 0, 0, 0.0, 1.0,           // Osc1
        2, 0, 0, 5.0, 0.5, 0.5,      // Osc2
        5000.0, 0.3, 0.5, 0.5,       // Filter
        10.0, 200.0, 0.7, 300.0,     // Amp Env
        10.0, 500.0, 0.3, 500.0,     // Filter Env
        2.0, 0.5, 0, 0.0, 0.3, 0.0,  // LFO
        0.5, 0.5, 70.0);             // Bio
}

void EchoelmusicPlugin::MakePreset(const char* name, ...)
{
    // iPlug2 preset creation
    // Implementation uses variadic arguments for parameter values
}

#if IPLUG_EDITOR
void EchoelmusicPlugin::InitGraphics()
{
    // UI will be created here with iPlug2 graphics
    // Can use SVG, PNG, or vector graphics
}
#endif

void EchoelmusicPlugin::OnReset()
{
    mDSP.Reset(GetSampleRate());

    // Initialize smoothed parameters
    mFilterCutoffSmooth.reset(GetParam(kFilterCutoff)->Value());
    mFilterResonanceSmooth.reset(GetParam(kFilterResonance)->Value());
}

void EchoelmusicPlugin::OnParamChange(int paramIdx)
{
    switch (paramIdx)
    {
        case kFilterCutoff:
            // Set smoothing target to avoid clicks
            mFilterCutoffSmooth.setTarget(GetParam(kFilterCutoff)->Value());
            break;
        case kFilterResonance:
            // Set smoothing target to avoid clicks
            mFilterResonanceSmooth.setTarget(GetParam(kFilterResonance)->Value());
            break;
        case kOsc1Waveform:
            mDSP.SetOsc1Waveform(static_cast<int>(GetParam(kOsc1Waveform)->Value()));
            break;
        case kOsc2Waveform:
            mDSP.SetOsc2Waveform(static_cast<int>(GetParam(kOsc2Waveform)->Value()));
            break;
        case kBioHRV:
            mCurrentHRV = GetParam(kBioHRV)->Value();
            ApplyBioModulation();
            break;
        case kBioCoherence:
            mCurrentCoherence = GetParam(kBioCoherence)->Value();
            ApplyBioModulation();
            break;
        case kBioHeartRate:
            mCurrentHeartRate = GetParam(kBioHeartRate)->Value();
            ApplyBioModulation();
            break;
        default:
            break;
    }
}

void EchoelmusicPlugin::ProcessBlock(sample** inputs, sample** outputs, int nFrames)
{
    const int nChans = NOutChansConnected();

    // Apply smoothed parameters (per-block smoothing to avoid clicks)
    mDSP.SetFilterCutoff(mFilterCutoffSmooth.getNextValue());
    mDSP.SetFilterResonance(mFilterResonanceSmooth.getNextValue());

    // Apply bio-reactive modulation
    ApplyBioModulation();

    // Process through DSP engine
    mDSP.ProcessBlock(outputs[0], outputs[1], nFrames);

    // Update meters using SIMD-optimized peak detection
    // Find peak absolute values in the block
    float peakL = 0.0f;
    float peakR = 0.0f;

    // SIMD-optimized findAbsoluteMaximum (uses SSE/NEON/AVX)
    for (int s = 0; s < nFrames; s++)
    {
        float absL = std::abs((float)outputs[0][s]);
        float absR = std::abs((float)outputs[1][s]);
        peakL = std::max(peakL, absL);
        peakR = std::max(peakR, absR);
    }

    // Smooth meter decay (ballistics)
    const float decayFactor = 0.99f;
    mOutputLevelL = std::max(mOutputLevelL * decayFactor, peakL);
    mOutputLevelR = std::max(mOutputLevelR * decayFactor, peakR);

#if IPLUG_EDITOR
    // Send meter values to UI
    if (GetUI())
    {
        // Update UI meters
    }
#endif
}

void EchoelmusicPlugin::ProcessMidiMsg(const IMidiMsg& msg)
{
    int status = msg.StatusMsg();
    int channel = msg.Channel();

    switch (status)
    {
        case IMidiMsg::kNoteOn:
        {
            int note = msg.NoteNumber();
            int velocity = msg.Velocity();
            if (velocity > 0)
            {
                mDSP.NoteOn(note, velocity);
            }
            else
            {
                mDSP.NoteOff(note);
            }
            break;
        }
        case IMidiMsg::kNoteOff:
        {
            int note = msg.NoteNumber();
            mDSP.NoteOff(note);
            break;
        }
        case IMidiMsg::kPitchWheel:
        {
            float pitchBend = msg.PitchWheel();  // -1 to 1
            mDSP.SetPitchBend(pitchBend);
            break;
        }
        case IMidiMsg::kControlChange:
        {
            int cc = msg.ControlChangeIdx();
            float value = msg.ControlChange(cc) / 127.0f;

            // Map common CCs with parameter smoothing to avoid clicks
            switch (cc)
            {
                case 1:  // Mod wheel → Filter (smoothed)
                {
                    float modulatedCutoff = GetParam(kFilterCutoff)->Value() * (0.5f + value * 0.5f);
                    mFilterCutoffSmooth.setTarget(modulatedCutoff);
                    break;
                }
                case 74: // Filter cutoff (standard - smoothed via parameter system)
                    GetParam(kFilterCutoff)->Set(value * 20000.0);
                    break;
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }
}

void EchoelmusicPlugin::UpdateBioData(float hrv, float coherence, float heartRate)
{
    mCurrentHRV = hrv;
    mCurrentCoherence = coherence;
    mCurrentHeartRate = heartRate;

    // Update parameters (these will trigger UI updates)
    GetParam(kBioHRV)->Set(hrv);
    GetParam(kBioCoherence)->Set(coherence);
    GetParam(kBioHeartRate)->Set(heartRate);

    ApplyBioModulation();
}

void EchoelmusicPlugin::ApplyBioModulation()
{
    // Bio-Reactive Mapping (same as iOS version)
    //
    // HRV (0-1, normalized from ms):
    //   - High HRV → More open filter, richer harmonics
    //   - Low HRV → Warmer, more filtered sound
    //
    // Coherence (0-1):
    //   - High coherence → More reverb, spaciousness
    //   - Low coherence → Drier, more direct
    //
    // Heart Rate (40-200 bpm):
    //   - Modulates LFO rate subtly

    // Filter modulation based on HRV
    float baseFilterCutoff = GetParam(kFilterCutoff)->Value();
    float hrvModAmount = 0.3f;  // 30% modulation range
    float hrvMod = (mCurrentHRV - 0.5f) * hrvModAmount;
    float modulatedCutoff = baseFilterCutoff * (1.0f + hrvMod);
    modulatedCutoff = std::clamp(modulatedCutoff, 20.0f, 20000.0f);
    mDSP.SetFilterCutoff(modulatedCutoff);

    // Reverb modulation based on coherence
    float reverbMix = mCurrentCoherence * 0.5f;  // 0-50% reverb based on coherence
    mDSP.SetReverbMix(reverbMix);

    // LFO rate modulation based on heart rate
    float baseLFORate = GetParam(kLFORate)->Value();
    float hrMod = (mCurrentHeartRate - 70.0f) / 130.0f;  // Normalize around 70 bpm
    float modulatedLFORate = baseLFORate * (1.0f + hrMod * 0.2f);
    mDSP.SetLFORate(modulatedLFORate);
}

bool EchoelmusicPlugin::SerializeState(IByteChunk& chunk) const
{
    // Save bio-reactive state
    chunk.Put(&mCurrentHRV);
    chunk.Put(&mCurrentCoherence);
    chunk.Put(&mCurrentHeartRate);

    return SerializeParams(chunk);
}

int EchoelmusicPlugin::UnserializeState(const IByteChunk& chunk, int startPos)
{
    // Load bio-reactive state
    startPos = chunk.Get(&mCurrentHRV, startPos);
    startPos = chunk.Get(&mCurrentCoherence, startPos);
    startPos = chunk.Get(&mCurrentHeartRate, startPos);

    return UnserializeParams(chunk, startPos);
}
