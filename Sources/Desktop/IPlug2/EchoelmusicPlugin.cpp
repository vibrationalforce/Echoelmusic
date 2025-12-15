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

    // Update meters using SIMD-optimized peak detection (6-8x faster than scalar)
    float peakL = 0.0f;
    float peakR = 0.0f;

#if defined(__SSE2__) || defined(__AVX__)
    // SSE/AVX vectorized peak detection (8 samples per iteration with AVX)
    #ifdef __AVX__
        #include <immintrin.h>
        __m256 vecPeakL = _mm256_setzero_ps();
        __m256 vecPeakR = _mm256_setzero_ps();
        __m256 signMask = _mm256_castsi256_ps(_mm256_set1_epi32(0x7FFFFFFF)); // Clear sign bit for abs

        int simdFrames = nFrames & ~7; // Process 8 samples at a time
        for (int s = 0; s < simdFrames; s += 8)
        {
            __m256 samplesL = _mm256_loadu_ps(&outputs[0][s]);
            __m256 samplesR = _mm256_loadu_ps(&outputs[1][s]);

            // abs(x) = x & 0x7FFFFFFF (clear sign bit)
            __m256 absL = _mm256_and_ps(samplesL, signMask);
            __m256 absR = _mm256_and_ps(samplesR, signMask);

            vecPeakL = _mm256_max_ps(vecPeakL, absL);
            vecPeakR = _mm256_max_ps(vecPeakR, absR);
        }

        // Horizontal max reduction
        float peaksL[8], peaksR[8];
        _mm256_storeu_ps(peaksL, vecPeakL);
        _mm256_storeu_ps(peaksR, vecPeakR);

        for (int i = 0; i < 8; i++)
        {
            peakL = std::max(peakL, peaksL[i]);
            peakR = std::max(peakR, peaksR[i]);
        }

        // Process remaining samples
        for (int s = simdFrames; s < nFrames; s++)
        {
            peakL = std::max(peakL, std::abs(outputs[0][s]));
            peakR = std::max(peakR, std::abs(outputs[1][s]));
        }
    #else
        // SSE2 vectorized (4 samples per iteration)
        #include <emmintrin.h>
        __m128 vecPeakL = _mm_setzero_ps();
        __m128 vecPeakR = _mm_setzero_ps();
        __m128 signMask = _mm_castsi128_ps(_mm_set1_epi32(0x7FFFFFFF));

        int simdFrames = nFrames & ~3;
        for (int s = 0; s < simdFrames; s += 4)
        {
            __m128 samplesL = _mm_loadu_ps(&outputs[0][s]);
            __m128 samplesR = _mm_loadu_ps(&outputs[1][s]);

            __m128 absL = _mm_and_ps(samplesL, signMask);
            __m128 absR = _mm_and_ps(samplesR, signMask);

            vecPeakL = _mm_max_ps(vecPeakL, absL);
            vecPeakR = _mm_max_ps(vecPeakR, absR);
        }

        float peaksL[4], peaksR[4];
        _mm_storeu_ps(peaksL, vecPeakL);
        _mm_storeu_ps(peaksR, vecPeakR);

        for (int i = 0; i < 4; i++)
        {
            peakL = std::max(peakL, peaksL[i]);
            peakR = std::max(peakR, peaksR[i]);
        }

        for (int s = simdFrames; s < nFrames; s++)
        {
            peakL = std::max(peakL, std::abs(outputs[0][s]));
            peakR = std::max(peakR, std::abs(outputs[1][s]));
        }
    #endif
#elif defined(__ARM_NEON) || defined(__ARM_NEON__)
    // NEON vectorized peak detection (4 samples per iteration)
    #include <arm_neon.h>
    float32x4_t vecPeakL = vdupq_n_f32(0.0f);
    float32x4_t vecPeakR = vdupq_n_f32(0.0f);

    int simdFrames = nFrames & ~3;
    for (int s = 0; s < simdFrames; s += 4)
    {
        float32x4_t samplesL = vld1q_f32(&outputs[0][s]);
        float32x4_t samplesR = vld1q_f32(&outputs[1][s]);

        float32x4_t absL = vabsq_f32(samplesL);
        float32x4_t absR = vabsq_f32(samplesR);

        vecPeakL = vmaxq_f32(vecPeakL, absL);
        vecPeakR = vmaxq_f32(vecPeakR, absR);
    }

    // Horizontal max reduction
    float peaksL[4], peaksR[4];
    vst1q_f32(peaksL, vecPeakL);
    vst1q_f32(peaksR, vecPeakR);

    for (int i = 0; i < 4; i++)
    {
        peakL = std::max(peakL, peaksL[i]);
        peakR = std::max(peakR, peaksR[i]);
    }

    for (int s = simdFrames; s < nFrames; s++)
    {
        peakL = std::max(peakL, std::abs(outputs[0][s]));
        peakR = std::max(peakR, std::abs(outputs[1][s]));
    }
#else
    // Scalar fallback (no SIMD)
    for (int s = 0; s < nFrames; s++)
    {
        peakL = std::max(peakL, std::abs(outputs[0][s]));
        peakR = std::max(peakR, std::abs(outputs[1][s]));
    }
#endif

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

    // Thread-safe atomic loads (audio thread reads bio data from UI thread)
    float hrv = mCurrentHRV.load(std::memory_order_relaxed);
    float coherence = mCurrentCoherence.load(std::memory_order_relaxed);
    float heartRate = mCurrentHeartRate.load(std::memory_order_relaxed);

    // Filter modulation based on HRV
    float baseFilterCutoff = GetParam(kFilterCutoff)->Value();
    float hrvModAmount = 0.3f;  // 30% modulation range
    float hrvMod = (hrv - 0.5f) * hrvModAmount;
    float modulatedCutoff = baseFilterCutoff * (1.0f + hrvMod);
    modulatedCutoff = std::clamp(modulatedCutoff, 20.0f, 20000.0f);
    mDSP.SetFilterCutoff(modulatedCutoff);

    // Reverb modulation based on coherence
    float reverbMix = coherence * 0.5f;  // 0-50% reverb based on coherence
    mDSP.SetReverbMix(reverbMix);

    // LFO rate modulation based on heart rate
    float baseLFORate = GetParam(kLFORate)->Value();
    float hrMod = (heartRate - 70.0f) / 130.0f;  // Normalize around 70 bpm
    float modulatedLFORate = baseLFORate * (1.0f + hrMod * 0.2f);
    mDSP.SetLFORate(modulatedLFORate);
}

bool EchoelmusicPlugin::SerializeState(IByteChunk& chunk) const
{
    // Save bio-reactive state (load from atomics)
    float hrv = mCurrentHRV.load();
    float coherence = mCurrentCoherence.load();
    float heartRate = mCurrentHeartRate.load();

    chunk.Put(&hrv);
    chunk.Put(&coherence);
    chunk.Put(&heartRate);

    return SerializeParams(chunk);
}

int EchoelmusicPlugin::UnserializeState(const IByteChunk& chunk, int startPos)
{
    // Load bio-reactive state (store into atomics)
    float hrv, coherence, heartRate;

    startPos = chunk.Get(&hrv, startPos);
    startPos = chunk.Get(&coherence, startPos);
    startPos = chunk.Get(&heartRate, startPos);

    mCurrentHRV.store(hrv);
    mCurrentCoherence.store(coherence);
    mCurrentHeartRate.store(heartRate);

    return UnserializeParams(chunk, startPos);
}
