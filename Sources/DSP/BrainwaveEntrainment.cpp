/**
 * BrainwaveEntrainment.cpp - Full Implementation
 *
 * ╔══════════════════════════════════════════════════════════════════════════╗
 * ║  DEVICE COMPATIBILITY                                                    ║
 * ╠══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                          ║
 * ║  STEREO HEADPHONES REQUIRED:                                             ║
 * ║    • BinauralBeatGenerator - Requires separate L/R ear signals           ║
 * ║                                                                          ║
 * ║  ANY SPEAKER / MONO COMPATIBLE:                                          ║
 * ║    • IsochronicToneGenerator - Pulsed tones work on any output           ║
 * ║    • MonauralBeatGenerator - Acoustic beating in air                     ║
 * ║    • PlanetaryToneGenerator - Pure tones                                 ║
 * ║    • SolfeggioGenerator - Pure frequency tones                           ║
 * ║    • SchumannGenerator - Multiple output modes including mono            ║
 * ║                                                                          ║
 * ╚══════════════════════════════════════════════════════════════════════════╝
 *
 * ╔══════════════════════════════════════════════════════════════════════════╗
 * ║  VALIDATED THERAPEUTIC FREQUENCIES                                       ║
 * ╠══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                          ║
 * ║  [FDA APPROVED / STRONG EVIDENCE]:                                       ║
 * ║    • 40 Hz Gamma - MIT/Nature 2024 Alzheimer's research                  ║
 * ║    • 20-30 Hz VNS - FDA-approved vagus nerve stimulation                 ║
 * ║                                                                          ║
 * ║  [MODERATE EVIDENCE - Meta-analyses]:                                    ║
 * ║    • Binaural Beats anxiety reduction (SMD -1.38)                        ║
 * ║    • Alpha entrainment for relaxation                                    ║
 * ║    • Theta entrainment for meditation states                             ║
 * ║                                                                          ║
 * ║  [ESOTERIC - NO CONTROLLED EVIDENCE]:                                    ║
 * ║    • Solfeggio frequency healing claims                                  ║
 * ║    • Planetary frequency effects                                         ║
 * ║    • "528 Hz DNA repair" - NO EVIDENCE                                   ║
 * ║                                                                          ║
 * ╚══════════════════════════════════════════════════════════════════════════╝
 */

#include "BrainwaveEntrainment.h"
#include <cmath>

namespace Echoel::DSP
{

//==============================================================================
// Mathematical Constants
//==============================================================================
namespace
{
    constexpr double TWO_PI = 6.283185307179586476925286766559;

    // Schumann resonance frequencies (measured)
    constexpr std::array<double, 8> SCHUMANN_HARMONICS = {
        7.83,   // Fundamental
        14.3,   // 2nd
        20.8,   // 3rd
        27.3,   // 4th
        33.8,   // 5th
        39.0,   // 6th
        45.0,   // 7th
        51.0    // 8th
    };

    // Solfeggio frequencies (esoteric tradition)
    constexpr std::array<double, 9> SOLFEGGIO_FREQUENCIES = {
        396.0,  // UT
        417.0,  // RE
        528.0,  // MI
        639.0,  // FA
        741.0,  // SOL
        852.0,  // LA
        963.0,  // SI
        174.0,  // Base 1
        285.0   // Base 2
    };
}

//==============================================================================
// BinauralBeatGenerator Implementation
// [REQUIRES STEREO HEADPHONES]
//==============================================================================

BinauralBeatGenerator::BinauralBeatGenerator()
{
    updateFrequencies();
}

void BinauralBeatGenerator::prepare(double newSampleRate, int /*samplesPerBlock*/)
{
    sampleRate = newSampleRate;
    reset();
}

void BinauralBeatGenerator::reset()
{
    leftPhase = 0.0;
    rightPhase = 0.0;
}

void BinauralBeatGenerator::setTargetFrequency(double hz)
{
    beatFreq = juce::jlimit(0.5, 100.0, hz);
    updateFrequencies();
}

void BinauralBeatGenerator::setBrainwaveBand(BrainwaveFrequencies::Band band)
{
    auto info = BrainwaveFrequencies::getBandInfo(band);
    beatFreq = (info.minHz + info.maxHz) * 0.5;
    updateFrequencies();
}

void BinauralBeatGenerator::setCarrierFrequency(double hz)
{
    carrierFreq = juce::jlimit(100.0, 500.0, hz);
    updateFrequencies();
}

void BinauralBeatGenerator::updateFrequencies()
{
    // Left ear gets carrier - beat/2, right ear gets carrier + beat/2
    leftFreq = carrierFreq - (beatFreq * 0.5);
    rightFreq = carrierFreq + (beatFreq * 0.5);
}

void BinauralBeatGenerator::loadPreset(Preset preset)
{
    switch (preset)
    {
        // Brainwave states
        case Preset::DeepSleep:
            setTargetFrequency(2.0);
            setCarrierFrequency(200.0);
            break;

        case Preset::Meditation:
            setTargetFrequency(6.0);
            setCarrierFrequency(250.0);
            break;

        case Preset::Relaxation:
            setTargetFrequency(10.0);
            setCarrierFrequency(300.0);
            break;

        case Preset::Focus:
            setTargetFrequency(18.0);
            setCarrierFrequency(300.0);
            break;

        case Preset::Creativity:
            setTargetFrequency(7.83);  // Schumann fundamental
            setCarrierFrequency(280.0);
            break;

        case Preset::PeakPerformance:
            // [VALIDATED] 40 Hz Gamma - MIT Alzheimer's research
            setTargetFrequency(40.0);
            setCarrierFrequency(300.0);
            break;

        // Schumann resonance
        case Preset::SchumannFundamental:
            setTargetFrequency(7.83);
            setCarrierFrequency(250.0);
            break;

        case Preset::SchumannSecond:
            setTargetFrequency(14.3);
            setCarrierFrequency(280.0);
            break;

        case Preset::SchumannThird:
            setTargetFrequency(20.8);
            setCarrierFrequency(300.0);
            break;

        // Solfeggio-aligned (carrier at solfeggio, beat to brainwave)
        case Preset::Solfeggio396:
            setCarrierFrequency(396.0);
            setTargetFrequency(7.83);
            break;

        case Preset::Solfeggio528:
            setCarrierFrequency(350.0);  // Near 528/2
            setTargetFrequency(10.0);
            break;

        case Preset::Solfeggio639:
            setCarrierFrequency(320.0);
            setTargetFrequency(6.0);
            break;

        case Preset::Solfeggio741:
            setCarrierFrequency(370.0);
            setTargetFrequency(10.0);
            break;

        // Planetary
        case Preset::EarthDay:
            setCarrierFrequency(194.18);
            setTargetFrequency(7.83);
            break;

        case Preset::SunTone:
            setCarrierFrequency(126.22);
            setTargetFrequency(10.0);
            break;

        case Preset::MoonTone:
            setCarrierFrequency(210.42);
            setTargetFrequency(6.0);
            break;
    }
}

void BinauralBeatGenerator::process(float* leftChannel, float* rightChannel, int numSamples)
{
    if (!enabled)
        return;

    const double leftInc = (leftFreq * TWO_PI) / sampleRate;
    const double rightInc = (rightFreq * TWO_PI) / sampleRate;

    for (int i = 0; i < numSamples; ++i)
    {
        leftChannel[i] += static_cast<float>(std::sin(leftPhase)) * outputVolume;
        rightChannel[i] += static_cast<float>(std::sin(rightPhase)) * outputVolume;

        leftPhase += leftInc;
        rightPhase += rightInc;

        // Wrap phases
        if (leftPhase >= TWO_PI) leftPhase -= TWO_PI;
        if (rightPhase >= TWO_PI) rightPhase -= TWO_PI;
    }
}

//==============================================================================
// IsochronicToneGenerator Implementation
// [MONO COMPATIBLE - Works on ANY speaker/headphone]
//==============================================================================

IsochronicToneGenerator::IsochronicToneGenerator()
{
}

void IsochronicToneGenerator::prepare(double newSampleRate, int /*samplesPerBlock*/)
{
    sampleRate = newSampleRate;
    reset();
}

void IsochronicToneGenerator::reset()
{
    tonePhase = 0.0;
    pulsePhase = 0.0;
}

void IsochronicToneGenerator::setPulseRate(double hz)
{
    pulseRate = juce::jlimit(0.5, 100.0, hz);
}

float IsochronicToneGenerator::calculatePulseEnvelope(double phase)
{
    // Phase is 0-1 within one pulse period
    // dutyCycle determines how much of the period is "on"

    if (phase > static_cast<double>(dutyCycle))
        return 0.0f;

    // Normalize phase to 0-1 within the "on" portion
    double normalizedPhase = phase / static_cast<double>(dutyCycle);

    switch (pulseShape)
    {
        case PulseShape::Square:
            return 1.0f;

        case PulseShape::Sine:
            // Sine fade in and out
            return static_cast<float>(std::sin(normalizedPhase * 3.14159265359));

        case PulseShape::Triangle:
            // Linear rise and fall
            if (normalizedPhase < 0.5)
                return static_cast<float>(normalizedPhase * 2.0);
            else
                return static_cast<float>((1.0 - normalizedPhase) * 2.0);

        case PulseShape::Exponential:
            // Fast attack, exponential decay
            if (normalizedPhase < 0.1)
                return static_cast<float>(normalizedPhase * 10.0);
            else
                return static_cast<float>(std::exp(-(normalizedPhase - 0.1) * 5.0));

        default:
            return 1.0f;
    }
}

void IsochronicToneGenerator::process(float* output, int numSamples)
{
    if (!enabled)
        return;

    const double toneInc = (toneFreq * TWO_PI) / sampleRate;
    const double pulseInc = pulseRate / sampleRate;

    for (int i = 0; i < numSamples; ++i)
    {
        // Generate carrier tone
        float tone = static_cast<float>(std::sin(tonePhase));

        // Apply pulse envelope
        float envelope = calculatePulseEnvelope(pulsePhase);

        output[i] += tone * envelope * outputVolume;

        // Advance phases
        tonePhase += toneInc;
        pulsePhase += pulseInc;

        // Wrap phases
        if (tonePhase >= TWO_PI) tonePhase -= TWO_PI;
        if (pulsePhase >= 1.0) pulsePhase -= 1.0;
    }
}

void IsochronicToneGenerator::processStereo(float* left, float* right, int numSamples)
{
    if (!enabled)
        return;

    const double toneInc = (toneFreq * TWO_PI) / sampleRate;
    const double pulseInc = pulseRate / sampleRate;

    for (int i = 0; i < numSamples; ++i)
    {
        float tone = static_cast<float>(std::sin(tonePhase));
        float envelope = calculatePulseEnvelope(pulsePhase);
        float sample = tone * envelope * outputVolume;

        // Same signal to both channels (mono-compatible)
        left[i] += sample;
        right[i] += sample;

        tonePhase += toneInc;
        pulsePhase += pulseInc;

        if (tonePhase >= TWO_PI) tonePhase -= TWO_PI;
        if (pulsePhase >= 1.0) pulsePhase -= 1.0;
    }
}

//==============================================================================
// MonauralBeatGenerator Implementation
// [MONO COMPATIBLE - Creates acoustic beating in air, no headphones needed]
//==============================================================================

MonauralBeatGenerator::MonauralBeatGenerator()
{
    updateBeatFreq();
}

void MonauralBeatGenerator::prepare(double newSampleRate, int /*samplesPerBlock*/)
{
    sampleRate = newSampleRate;
    reset();
}

void MonauralBeatGenerator::reset()
{
    phase1 = 0.0;
    phase2 = 0.0;
}

void MonauralBeatGenerator::setTargetBeatFrequency(double beatHz)
{
    // Keep freq1 fixed, adjust freq2 to achieve target beat
    beatHz = juce::jlimit(0.5, 50.0, beatHz);
    freq2 = freq1 + beatHz;
    updateBeatFreq();
}

void MonauralBeatGenerator::process(float* output, int numSamples)
{
    if (!enabled)
        return;

    const double inc1 = (freq1 * TWO_PI) / sampleRate;
    const double inc2 = (freq2 * TWO_PI) / sampleRate;

    for (int i = 0; i < numSamples; ++i)
    {
        // Mix two tones together - creates acoustic beating
        // This beating happens in the air, not requiring stereo separation
        float tone1 = static_cast<float>(std::sin(phase1));
        float tone2 = static_cast<float>(std::sin(phase2));

        // Equal mix of both tones creates audible beating
        output[i] += (tone1 + tone2) * 0.5f * outputVolume;

        phase1 += inc1;
        phase2 += inc2;

        if (phase1 >= TWO_PI) phase1 -= TWO_PI;
        if (phase2 >= TWO_PI) phase2 -= TWO_PI;
    }
}

//==============================================================================
// PlanetaryToneGenerator Implementation
// [ESOTERIC] Based on Cousto's Cosmic Octave - no health evidence
//==============================================================================

PlanetaryToneGenerator::PlanetaryToneGenerator()
{
    updateFrequency();
}

void PlanetaryToneGenerator::prepare(double newSampleRate, int /*samplesPerBlock*/)
{
    sampleRate = newSampleRate;
    reset();
}

void PlanetaryToneGenerator::reset()
{
    phase = 0.0;
}

void PlanetaryToneGenerator::setPlanet(Planet planet)
{
    currentPlanet = planet;
    updateFrequency();
}

const CosmicOctave::PlanetaryBody* PlanetaryToneGenerator::getPlanetaryInfo() const
{
    // Map our Planet enum to CosmicOctave planetary bodies
    const auto& bodies = CosmicOctave::getPlanetaryBodies();

    static const std::array<juce::String, 11> planetNames = {
        "Sun", "Moon", "Mercury", "Venus", "Earth",
        "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"
    };

    int index = static_cast<int>(currentPlanet);
    if (index >= 0 && index < static_cast<int>(planetNames.size()))
    {
        for (const auto& body : bodies)
        {
            if (body.name == planetNames[static_cast<size_t>(index)])
                return &body;
        }
    }
    return nullptr;
}

void PlanetaryToneGenerator::updateFrequency()
{
    const auto* info = getPlanetaryInfo();
    if (info)
    {
        double baseFreq = useRotation ? info->rotationalFreqHz : info->orbitalFreqHz;
        currentFreq = baseFreq * std::pow(2.0, static_cast<double>(octaveOffset));
    }
}

float PlanetaryToneGenerator::generateSample(double ph)
{
    switch (waveShape)
    {
        case WaveShape::Sine:
            return static_cast<float>(std::sin(ph));

        case WaveShape::Triangle:
        {
            double t = std::fmod(ph, TWO_PI) / TWO_PI;
            return static_cast<float>(4.0 * std::abs(t - 0.5) - 1.0);
        }

        case WaveShape::SoftSquare:
        {
            // Soft square using tanh saturation
            double sine = std::sin(ph);
            return static_cast<float>(std::tanh(sine * 3.0));
        }

        case WaveShape::Choir:
        {
            // Multiple harmonics for choir-like sound
            float sum = static_cast<float>(std::sin(ph));
            sum += static_cast<float>(std::sin(ph * 2.0)) * 0.5f;
            sum += static_cast<float>(std::sin(ph * 3.0)) * 0.3f;
            sum += static_cast<float>(std::sin(ph * 4.0)) * 0.15f;
            sum += static_cast<float>(std::sin(ph * 5.0)) * 0.1f;
            return sum * 0.4f;  // Normalize
        }

        default:
            return static_cast<float>(std::sin(ph));
    }
}

void PlanetaryToneGenerator::process(float* output, int numSamples)
{
    if (!enabled)
        return;

    const double inc = (currentFreq * TWO_PI) / sampleRate;

    for (int i = 0; i < numSamples; ++i)
    {
        output[i] += generateSample(phase) * outputVolume;

        phase += inc;
        if (phase >= TWO_PI) phase -= TWO_PI;
    }
}

//==============================================================================
// SolfeggioGenerator Implementation
// [ESOTERIC] No scientific evidence for healing claims
//==============================================================================

SolfeggioGenerator::SolfeggioGenerator()
{
    activeTones.push_back(currentTone);
    phases.resize(1, 0.0);
}

void SolfeggioGenerator::prepare(double newSampleRate, int /*samplesPerBlock*/)
{
    sampleRate = newSampleRate;
    reset();
}

void SolfeggioGenerator::reset()
{
    for (auto& p : phases)
        p = 0.0;
    subOctavePhase = 0.0;
}

void SolfeggioGenerator::setTone(Tone tone)
{
    currentTone = tone;
    activeTones.clear();
    activeTones.push_back(tone);
    phases.resize(1, 0.0);
}

void SolfeggioGenerator::setTones(const std::vector<Tone>& tones)
{
    activeTones = tones;
    phases.resize(tones.size(), 0.0);
}

void SolfeggioGenerator::setSubOctave(bool enabled, float level)
{
    subOctaveEnabled = enabled;
    subOctaveLevel = level;
}

double SolfeggioGenerator::getToneFrequency(Tone tone) const
{
    int index = static_cast<int>(tone);
    if (index >= 0 && index < static_cast<int>(SOLFEGGIO_FREQUENCIES.size()))
        return SOLFEGGIO_FREQUENCIES[static_cast<size_t>(index)];
    return 528.0;  // Default to MI
}

std::vector<double> SolfeggioGenerator::getCurrentFrequencies() const
{
    std::vector<double> freqs;
    for (const auto& tone : activeTones)
        freqs.push_back(getToneFrequency(tone));
    return freqs;
}

float SolfeggioGenerator::generateSample(double ph)
{
    switch (waveShape)
    {
        case WaveShape::Sine:
            return static_cast<float>(std::sin(ph));

        case WaveShape::Triangle:
        {
            double t = std::fmod(ph, TWO_PI) / TWO_PI;
            return static_cast<float>(4.0 * std::abs(t - 0.5) - 1.0);
        }

        case WaveShape::SoftSaw:
        {
            // Soft sawtooth
            double t = std::fmod(ph, TWO_PI) / TWO_PI;
            float saw = static_cast<float>(2.0 * t - 1.0);
            return static_cast<float>(std::tanh(saw * 2.0));
        }

        default:
            return static_cast<float>(std::sin(ph));
    }
}

void SolfeggioGenerator::process(float* output, int numSamples)
{
    if (!enabled || activeTones.empty())
        return;

    float toneScale = 1.0f / static_cast<float>(activeTones.size());

    for (int i = 0; i < numSamples; ++i)
    {
        float sample = 0.0f;

        // Generate each active tone
        for (size_t t = 0; t < activeTones.size(); ++t)
        {
            double freq = getToneFrequency(activeTones[t]);
            double inc = (freq * TWO_PI) / sampleRate;

            sample += generateSample(phases[t]) * toneScale;

            phases[t] += inc;
            if (phases[t] >= TWO_PI) phases[t] -= TWO_PI;
        }

        // Add sub-octave if enabled
        if (subOctaveEnabled && !activeTones.empty())
        {
            double mainFreq = getToneFrequency(activeTones[0]);
            double subInc = ((mainFreq * 0.5) * TWO_PI) / sampleRate;

            sample += static_cast<float>(std::sin(subOctavePhase)) * subOctaveLevel * toneScale;

            subOctavePhase += subInc;
            if (subOctavePhase >= TWO_PI) subOctavePhase -= TWO_PI;
        }

        output[i] += sample * outputVolume;
    }
}

//==============================================================================
// SchumannGenerator Implementation
// [SCIENTIFIC] Schumann resonance is real; entrainment effects have limited evidence
//==============================================================================

SchumannGenerator::SchumannGenerator()
{
}

void SchumannGenerator::prepare(double newSampleRate, int /*samplesPerBlock*/)
{
    sampleRate = newSampleRate;
    reset();
}

void SchumannGenerator::reset()
{
    for (auto& p : schumannPhases) p = 0.0;
    carrierPhase = 0.0;
    leftCarrierPhase = 0.0;
    rightCarrierPhase = 0.0;
}

void SchumannGenerator::setHarmonic(int harmonic)
{
    activeHarmonics.clear();
    activeHarmonics.push_back(juce::jlimit(0, 7, harmonic));
}

void SchumannGenerator::setHarmonics(const std::vector<int>& harmonics)
{
    activeHarmonics.clear();
    for (int h : harmonics)
    {
        if (h >= 0 && h < 8)
            activeHarmonics.push_back(h);
    }
    if (activeHarmonics.empty())
        activeHarmonics.push_back(0);  // Ensure at least fundamental
}

void SchumannGenerator::setHarmonicAmplitude(int harmonic, float amplitude)
{
    if (harmonic >= 0 && harmonic < 8)
        harmonicAmplitudes[static_cast<size_t>(harmonic)] = juce::jlimit(0.0f, 1.0f, amplitude);
}

void SchumannGenerator::process(float* output, int numSamples)
{
    if (!enabled)
        return;

    for (int i = 0; i < numSamples; ++i)
    {
        float sample = 0.0f;

        switch (mode)
        {
            case Mode::PureTone:
            {
                // Generate Schumann frequencies directly (sub-audio, needs to modulate something)
                // Use as AM on carrier
                float modulator = 0.0f;
                for (int h : activeHarmonics)
                {
                    double freq = SCHUMANN_HARMONICS[static_cast<size_t>(h)];
                    double inc = (freq * TWO_PI) / sampleRate;
                    modulator += static_cast<float>(std::sin(schumannPhases[static_cast<size_t>(h)]))
                                 * harmonicAmplitudes[static_cast<size_t>(h)];
                    schumannPhases[static_cast<size_t>(h)] += inc;
                    if (schumannPhases[static_cast<size_t>(h)] >= TWO_PI)
                        schumannPhases[static_cast<size_t>(h)] -= TWO_PI;
                }

                // Modulate carrier
                float carrier = static_cast<float>(std::sin(carrierPhase));
                double carrierInc = (carrierFreq * TWO_PI) / sampleRate;
                carrierPhase += carrierInc;
                if (carrierPhase >= TWO_PI) carrierPhase -= TWO_PI;

                sample = carrier * (0.5f + modulator * 0.5f);
                break;
            }

            case Mode::IsochronicPulse:
            {
                // Pulse the carrier at Schumann rate
                // Use primary Schumann frequency for pulsing
                double schumannFreq = activeHarmonics.empty() ? 7.83 :
                                      SCHUMANN_HARMONICS[static_cast<size_t>(activeHarmonics[0])];
                double schumannInc = schumannFreq / sampleRate;
                double pulsePhase = std::fmod(schumannPhases[0], 1.0);
                schumannPhases[0] += schumannInc;
                if (schumannPhases[0] >= 1.0) schumannPhases[0] -= 1.0;

                // Sine envelope
                float envelope = (pulsePhase < 0.5) ?
                    static_cast<float>(std::sin(pulsePhase * 3.14159265359 * 2.0)) : 0.0f;

                // Carrier tone
                float carrier = static_cast<float>(std::sin(carrierPhase));
                double carrierInc = (carrierFreq * TWO_PI) / sampleRate;
                carrierPhase += carrierInc;
                if (carrierPhase >= TWO_PI) carrierPhase -= TWO_PI;

                sample = carrier * envelope;
                break;
            }

            case Mode::AmplitudeModulation:
            {
                // Classic AM with Schumann as modulator
                float modulator = 0.0f;
                for (int h : activeHarmonics)
                {
                    double freq = SCHUMANN_HARMONICS[static_cast<size_t>(h)];
                    double inc = (freq * TWO_PI) / sampleRate;
                    modulator += static_cast<float>((1.0 + std::sin(schumannPhases[static_cast<size_t>(h)])) * 0.5)
                                 * harmonicAmplitudes[static_cast<size_t>(h)];
                    schumannPhases[static_cast<size_t>(h)] += inc;
                    if (schumannPhases[static_cast<size_t>(h)] >= TWO_PI)
                        schumannPhases[static_cast<size_t>(h)] -= TWO_PI;
                }

                float carrier = static_cast<float>(std::sin(carrierPhase));
                double carrierInc = (carrierFreq * TWO_PI) / sampleRate;
                carrierPhase += carrierInc;
                if (carrierPhase >= TWO_PI) carrierPhase -= TWO_PI;

                sample = carrier * modulator;
                break;
            }

            case Mode::BinauralBeat:
                // Handled in processStereo
                break;
        }

        output[i] += sample * outputVolume;
    }
}

void SchumannGenerator::processStereo(float* left, float* right, int numSamples)
{
    if (!enabled)
        return;

    if (mode != Mode::BinauralBeat)
    {
        // Non-binaural modes: process mono and copy to both channels
        process(left, numSamples);
        std::copy(left, left + numSamples, right);
        return;
    }

    // Binaural mode: different frequencies to each ear
    double schumannFreq = activeHarmonics.empty() ? 7.83 :
                          SCHUMANN_HARMONICS[static_cast<size_t>(activeHarmonics[0])];

    double leftFreq = carrierFreq - (schumannFreq * 0.5);
    double rightFreq = carrierFreq + (schumannFreq * 0.5);

    const double leftInc = (leftFreq * TWO_PI) / sampleRate;
    const double rightInc = (rightFreq * TWO_PI) / sampleRate;

    for (int i = 0; i < numSamples; ++i)
    {
        left[i] += static_cast<float>(std::sin(leftCarrierPhase)) * outputVolume;
        right[i] += static_cast<float>(std::sin(rightCarrierPhase)) * outputVolume;

        leftCarrierPhase += leftInc;
        rightCarrierPhase += rightInc;

        if (leftCarrierPhase >= TWO_PI) leftCarrierPhase -= TWO_PI;
        if (rightCarrierPhase >= TWO_PI) rightCarrierPhase -= TWO_PI;
    }
}

//==============================================================================
// BrainwaveEntrainmentEngine Implementation
//==============================================================================

BrainwaveEntrainmentEngine::BrainwaveEntrainmentEngine()
{
}

BrainwaveEntrainmentEngine::~BrainwaveEntrainmentEngine()
{
}

void BrainwaveEntrainmentEngine::prepare(double newSampleRate, int newSamplesPerBlock)
{
    sampleRate = newSampleRate;
    samplesPerBlock = newSamplesPerBlock;

    // Prepare all generators
    binaural.prepare(sampleRate, samplesPerBlock);
    isochronic.prepare(sampleRate, samplesPerBlock);
    monaural.prepare(sampleRate, samplesPerBlock);
    planetary.prepare(sampleRate, samplesPerBlock);
    solfeggio.prepare(sampleRate, samplesPerBlock);
    schumann.prepare(sampleRate, samplesPerBlock);

    // Allocate work buffers
    tempBufferL.resize(static_cast<size_t>(samplesPerBlock), 0.0f);
    tempBufferR.resize(static_cast<size_t>(samplesPerBlock), 0.0f);
    mixBufferL.resize(static_cast<size_t>(samplesPerBlock), 0.0f);
    mixBufferR.resize(static_cast<size_t>(samplesPerBlock), 0.0f);
}

void BrainwaveEntrainmentEngine::reset()
{
    binaural.reset();
    isochronic.reset();
    monaural.reset();
    planetary.reset();
    solfeggio.reset();
    schumann.reset();

    sessionActive = false;
    sessionElapsed = 0.0;
}

void BrainwaveEntrainmentEngine::loadSessionPreset(SessionPreset preset)
{
    // Reset mix
    mix = ModuleMix();

    switch (preset)
    {
        //======================================================================
        // [SCIENTIFICALLY VALIDATED] - Peer-reviewed research support
        //======================================================================

        case SessionPreset::Gamma40Hz_MIT:
            // [VALIDATED] MIT/Nature 2024 - 40 Hz Gamma for Alzheimer's
            // Uses both binaural (headphones) and isochronic (any speaker)
            binaural.setTargetFrequency(40.0);
            binaural.setCarrierFrequency(300.0);
            binaural.setEnabled(true);
            // Isochronic for mono/speaker compatibility
            isochronic.setPulseRate(40.0);
            isochronic.setToneFrequency(300.0);
            isochronic.setPulseShape(IsochronicToneGenerator::PulseShape::Sine);
            isochronic.setEnabled(true);
            // Monaural backup
            monaural.setFrequency1(280.0);
            monaural.setTargetBeatFrequency(40.0);
            monaural.setEnabled(true);
            mix.binaural = 0.4f;
            mix.isochronic = 0.3f;
            mix.monaural = 0.2f;
            break;

        case SessionPreset::VNS_20Hz:
            // [FDA APPROVED] Lower VNS range - 20 Hz
            binaural.setTargetFrequency(20.0);
            binaural.setCarrierFrequency(250.0);
            binaural.setEnabled(true);
            isochronic.setPulseRate(20.0);
            isochronic.setToneFrequency(250.0);
            isochronic.setPulseShape(IsochronicToneGenerator::PulseShape::Sine);
            isochronic.setEnabled(true);
            mix.binaural = 0.5f;
            mix.isochronic = 0.4f;
            break;

        case SessionPreset::VNS_25Hz:
            // [FDA APPROVED] Mid VNS range - 25 Hz
            binaural.setTargetFrequency(25.0);
            binaural.setCarrierFrequency(275.0);
            binaural.setEnabled(true);
            isochronic.setPulseRate(25.0);
            isochronic.setToneFrequency(275.0);
            isochronic.setPulseShape(IsochronicToneGenerator::PulseShape::Sine);
            isochronic.setEnabled(true);
            mix.binaural = 0.5f;
            mix.isochronic = 0.4f;
            break;

        case SessionPreset::VNS_30Hz:
            // [FDA APPROVED] Upper VNS range - 30 Hz
            binaural.setTargetFrequency(30.0);
            binaural.setCarrierFrequency(300.0);
            binaural.setEnabled(true);
            isochronic.setPulseRate(30.0);
            isochronic.setToneFrequency(300.0);
            isochronic.setPulseShape(IsochronicToneGenerator::PulseShape::Sine);
            isochronic.setEnabled(true);
            mix.binaural = 0.5f;
            mix.isochronic = 0.4f;
            break;

        case SessionPreset::AlphaRelaxation_Validated:
            // [META-ANALYSIS] Alpha 10 Hz - validated for anxiety reduction
            binaural.setTargetFrequency(10.0);
            binaural.setCarrierFrequency(300.0);
            binaural.setEnabled(true);
            isochronic.setPulseRate(10.0);
            isochronic.setToneFrequency(280.0);
            isochronic.setPulseShape(IsochronicToneGenerator::PulseShape::Sine);
            isochronic.setEnabled(true);
            monaural.setFrequency1(290.0);
            monaural.setTargetBeatFrequency(10.0);
            monaural.setEnabled(true);
            mix.binaural = 0.4f;
            mix.isochronic = 0.3f;
            mix.monaural = 0.2f;
            break;

        //======================================================================
        // [LIMITED EVIDENCE] - Some research, mixed results
        //======================================================================

        case SessionPreset::DeepRelaxation:
            binaural.setTargetFrequency(8.0);  // Alpha
            binaural.setEnabled(true);
            schumann.setHarmonic(0);  // 7.83 Hz fundamental
            schumann.setMode(SchumannGenerator::Mode::AmplitudeModulation);
            schumann.setEnabled(true);
            mix.binaural = 0.6f;
            mix.schumann = 0.3f;
            break;

        case SessionPreset::StressRelief:
            binaural.setTargetFrequency(10.0);  // Alpha
            binaural.setEnabled(true);
            solfeggio.setTone(SolfeggioGenerator::Tone::MI_528);
            solfeggio.setEnabled(true);
            mix.binaural = 0.5f;
            mix.solfeggio = 0.4f;
            break;

        case SessionPreset::SleepInduction:
            binaural.setTargetFrequency(3.0);  // Delta
            binaural.setEnabled(true);
            // Use isochronic as fallback (mono compatible)
            isochronic.setPulseRate(3.0);
            isochronic.setToneFrequency(150.0);
            isochronic.setPulseShape(IsochronicToneGenerator::PulseShape::Sine);
            isochronic.setEnabled(true);
            mix.binaural = 0.4f;
            mix.isochronic = 0.4f;
            break;

        case SessionPreset::MeditationBasic:
            binaural.setTargetFrequency(6.0);  // Theta
            binaural.setEnabled(true);
            planetary.setPlanet(PlanetaryToneGenerator::Planet::Earth);
            planetary.setEnabled(true);
            mix.binaural = 0.5f;
            mix.planetary = 0.3f;
            break;

        case SessionPreset::MeditationDeep:
            binaural.setTargetFrequency(4.0);  // Deep Theta
            binaural.setEnabled(true);
            planetary.setPlanet(PlanetaryToneGenerator::Planet::Earth);
            planetary.setEnabled(true);
            solfeggio.setTone(SolfeggioGenerator::Tone::FA_639);
            solfeggio.setEnabled(true);
            mix.binaural = 0.4f;
            mix.planetary = 0.25f;
            mix.solfeggio = 0.25f;
            break;

        case SessionPreset::MeditationTranscendent:
            // [VALIDATED] 40 Hz Gamma - supported by MIT research
            binaural.setTargetFrequency(40.0);
            binaural.setEnabled(true);
            solfeggio.setTones({
                SolfeggioGenerator::Tone::MI_528,
                SolfeggioGenerator::Tone::LA_852,
                SolfeggioGenerator::Tone::SI_963
            });
            solfeggio.setEnabled(true);
            mix.binaural = 0.5f;
            mix.solfeggio = 0.4f;
            break;

        case SessionPreset::FocusStudy:
            // [VALIDATED] Beta range supported for focus
            isochronic.setPulseRate(14.0);  // Low Beta
            isochronic.setToneFrequency(250.0);
            isochronic.setPulseShape(IsochronicToneGenerator::PulseShape::Sine);
            isochronic.setEnabled(true);
            binaural.setTargetFrequency(14.0);
            binaural.setEnabled(true);
            mix.isochronic = 0.5f;
            mix.binaural = 0.4f;
            break;

        case SessionPreset::FocusCreative:
            // Alpha/Theta border - creative state
            binaural.setTargetFrequency(7.83);  // Schumann frequency
            binaural.setEnabled(true);
            monaural.setFrequency1(200.0);
            monaural.setTargetBeatFrequency(7.83);
            monaural.setEnabled(true);
            mix.binaural = 0.4f;
            mix.monaural = 0.4f;
            break;

        case SessionPreset::FocusPerformance:
            // [VALIDATED] 40 Hz Low Gamma - peak performance
            isochronic.setPulseRate(40.0);
            isochronic.setToneFrequency(300.0);
            isochronic.setPulseShape(IsochronicToneGenerator::PulseShape::Sine);
            isochronic.setEnabled(true);
            binaural.setTargetFrequency(40.0);
            binaural.setEnabled(true);
            mix.isochronic = 0.5f;
            mix.binaural = 0.4f;
            break;

        case SessionPreset::HealingPhysical:
            binaural.setTargetFrequency(2.0);  // Delta
            binaural.setEnabled(true);
            solfeggio.setTone(SolfeggioGenerator::Tone::MI_528);
            solfeggio.setEnabled(true);
            mix.binaural = 0.4f;
            mix.solfeggio = 0.5f;
            break;

        case SessionPreset::HealingEmotional:
            binaural.setTargetFrequency(6.0);  // Theta
            binaural.setEnabled(true);
            solfeggio.setTone(SolfeggioGenerator::Tone::FA_639);
            solfeggio.setEnabled(true);
            mix.binaural = 0.4f;
            mix.solfeggio = 0.5f;
            break;

        case SessionPreset::HealingSpiritual:
            binaural.setTargetFrequency(7.83);
            binaural.setEnabled(true);
            solfeggio.setTones({
                SolfeggioGenerator::Tone::SOL_741,
                SolfeggioGenerator::Tone::LA_852,
                SolfeggioGenerator::Tone::SI_963
            });
            solfeggio.setEnabled(true);
            schumann.setHarmonics({0, 1, 2});
            schumann.setEnabled(true);
            mix.binaural = 0.3f;
            mix.solfeggio = 0.4f;
            mix.schumann = 0.2f;
            break;

        case SessionPreset::Custom:
            // Leave settings as-is
            break;
    }
}

void BrainwaveEntrainmentEngine::startSession(double durationMinutes)
{
    sessionDuration = durationMinutes * 60.0;  // Convert to seconds
    sessionElapsed = 0.0;
    sessionActive = true;
}

void BrainwaveEntrainmentEngine::stopSession()
{
    sessionActive = false;
}

double BrainwaveEntrainmentEngine::getSessionProgress() const
{
    if (!sessionActive || sessionDuration <= 0.0)
        return 0.0;
    return juce::jlimit(0.0, 1.0, sessionElapsed / sessionDuration);
}

void BrainwaveEntrainmentEngine::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numSamples <= 0 || numChannels <= 0)
        return;

    // Ensure work buffers are sized
    if (tempBufferL.size() < static_cast<size_t>(numSamples))
    {
        tempBufferL.resize(static_cast<size_t>(numSamples), 0.0f);
        tempBufferR.resize(static_cast<size_t>(numSamples), 0.0f);
        mixBufferL.resize(static_cast<size_t>(numSamples), 0.0f);
        mixBufferR.resize(static_cast<size_t>(numSamples), 0.0f);
    }

    // Clear mix buffers
    std::fill(mixBufferL.begin(), mixBufferL.begin() + numSamples, 0.0f);
    std::fill(mixBufferR.begin(), mixBufferR.begin() + numSamples, 0.0f);

    // Process binaural (stereo only)
    if (mix.binaural > 0.0f)
    {
        std::fill(tempBufferL.begin(), tempBufferL.begin() + numSamples, 0.0f);
        std::fill(tempBufferR.begin(), tempBufferR.begin() + numSamples, 0.0f);
        binaural.process(tempBufferL.data(), tempBufferR.data(), numSamples);
        for (int i = 0; i < numSamples; ++i)
        {
            mixBufferL[static_cast<size_t>(i)] += tempBufferL[static_cast<size_t>(i)] * mix.binaural;
            mixBufferR[static_cast<size_t>(i)] += tempBufferR[static_cast<size_t>(i)] * mix.binaural;
        }
    }

    // Process isochronic (mono compatible)
    if (mix.isochronic > 0.0f)
    {
        std::fill(tempBufferL.begin(), tempBufferL.begin() + numSamples, 0.0f);
        isochronic.process(tempBufferL.data(), numSamples);
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = tempBufferL[static_cast<size_t>(i)] * mix.isochronic;
            mixBufferL[static_cast<size_t>(i)] += sample;
            mixBufferR[static_cast<size_t>(i)] += sample;
        }
    }

    // Process monaural (mono compatible)
    if (mix.monaural > 0.0f)
    {
        std::fill(tempBufferL.begin(), tempBufferL.begin() + numSamples, 0.0f);
        monaural.process(tempBufferL.data(), numSamples);
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = tempBufferL[static_cast<size_t>(i)] * mix.monaural;
            mixBufferL[static_cast<size_t>(i)] += sample;
            mixBufferR[static_cast<size_t>(i)] += sample;
        }
    }

    // Process planetary (mono compatible)
    if (mix.planetary > 0.0f)
    {
        std::fill(tempBufferL.begin(), tempBufferL.begin() + numSamples, 0.0f);
        planetary.process(tempBufferL.data(), numSamples);
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = tempBufferL[static_cast<size_t>(i)] * mix.planetary;
            mixBufferL[static_cast<size_t>(i)] += sample;
            mixBufferR[static_cast<size_t>(i)] += sample;
        }
    }

    // Process solfeggio (mono compatible)
    if (mix.solfeggio > 0.0f)
    {
        std::fill(tempBufferL.begin(), tempBufferL.begin() + numSamples, 0.0f);
        solfeggio.process(tempBufferL.data(), numSamples);
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = tempBufferL[static_cast<size_t>(i)] * mix.solfeggio;
            mixBufferL[static_cast<size_t>(i)] += sample;
            mixBufferR[static_cast<size_t>(i)] += sample;
        }
    }

    // Process schumann (mono or stereo depending on mode)
    if (mix.schumann > 0.0f)
    {
        std::fill(tempBufferL.begin(), tempBufferL.begin() + numSamples, 0.0f);
        std::fill(tempBufferR.begin(), tempBufferR.begin() + numSamples, 0.0f);
        schumann.processStereo(tempBufferL.data(), tempBufferR.data(), numSamples);
        for (int i = 0; i < numSamples; ++i)
        {
            mixBufferL[static_cast<size_t>(i)] += tempBufferL[static_cast<size_t>(i)] * mix.schumann;
            mixBufferR[static_cast<size_t>(i)] += tempBufferR[static_cast<size_t>(i)] * mix.schumann;
        }
    }

    // Apply master volume and write to output buffer
    float* leftOut = buffer.getWritePointer(0);
    for (int i = 0; i < numSamples; ++i)
    {
        leftOut[i] += mixBufferL[static_cast<size_t>(i)] * masterVolume;
    }

    if (numChannels > 1)
    {
        float* rightOut = buffer.getWritePointer(1);
        for (int i = 0; i < numSamples; ++i)
        {
            rightOut[i] += mixBufferR[static_cast<size_t>(i)] * masterVolume;
        }
    }

    // Update session timing
    if (sessionActive)
    {
        sessionElapsed += static_cast<double>(numSamples) / sampleRate;
        if (sessionElapsed >= sessionDuration)
        {
            sessionActive = false;
        }
    }
}

}  // namespace Echoel::DSP
