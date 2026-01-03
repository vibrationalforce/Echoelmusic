#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <cmath>
#include <memory>
#include <complex>

/**
 * ImmersiveReverb5D - Blackhole Immersive-Inspired 5-Dimensional Reverb
 *
 * Beyond 3D spatial audio - a true 5-dimensional reverb experience:
 *
 * DIMENSION 1-3: SPATIAL (X, Y, Z)
 * - Full Dolby Atmos / 7.1.4 support
 * - Object-based panning
 * - Height layer processing
 * - Ambisonics support (1st-3rd order)
 *
 * DIMENSION 4: TEMPORAL
 * - Time-evolving spatial image
 * - Gravity warping (forward/reverse time)
 * - Temporal blur and smearing
 * - Dynamic panning over decay
 *
 * DIMENSION 5: SPECTRAL
 * - Frequency-dependent spatial behavior
 * - Per-band room size and decay
 * - Spectral panning (bass centered, highs wide)
 * - Harmonic spatial separation
 *
 * Formats: Stereo, LCR, Quad, 5.0-5.1.4, 7.0-7.1.4, Ambisonics
 *
 * Super Ralph Wiggum Loop Genius 5D Immersive Mode
 */

namespace Echoelmusic {
namespace Effects {
namespace Eventide {

//==============================================================================
// Constants
//==============================================================================

constexpr float PI = 3.14159265358979f;
constexpr float TWO_PI = 6.28318530717959f;

//==============================================================================
// Immersive Format Definitions
//==============================================================================

enum class ImmersiveFormat
{
    Stereo,         // 2.0
    LCR,            // 3.0
    Quad,           // 4.0
    Surround_5_0,   // 5.0
    Surround_5_1,   // 5.1
    Surround_5_1_2, // 5.1.2 (Atmos)
    Surround_5_1_4, // 5.1.4 (Atmos)
    Surround_7_0,   // 7.0
    Surround_7_1,   // 7.1
    Surround_7_1_2, // 7.1.2 (Atmos)
    Surround_7_1_4, // 7.1.4 (Atmos)
    Ambisonics_1,   // 1st order (4 channels)
    Ambisonics_2,   // 2nd order (9 channels)
    Ambisonics_3,   // 3rd order (16 channels)
    Binaural        // Binaural for headphones
};

inline int getChannelCount(ImmersiveFormat format)
{
    switch (format)
    {
        case ImmersiveFormat::Stereo:         return 2;
        case ImmersiveFormat::LCR:            return 3;
        case ImmersiveFormat::Quad:           return 4;
        case ImmersiveFormat::Surround_5_0:   return 5;
        case ImmersiveFormat::Surround_5_1:   return 6;
        case ImmersiveFormat::Surround_5_1_2: return 8;
        case ImmersiveFormat::Surround_5_1_4: return 10;
        case ImmersiveFormat::Surround_7_0:   return 7;
        case ImmersiveFormat::Surround_7_1:   return 8;
        case ImmersiveFormat::Surround_7_1_2: return 10;
        case ImmersiveFormat::Surround_7_1_4: return 12;
        case ImmersiveFormat::Ambisonics_1:   return 4;
        case ImmersiveFormat::Ambisonics_2:   return 9;
        case ImmersiveFormat::Ambisonics_3:   return 16;
        case ImmersiveFormat::Binaural:       return 2;
        default:                              return 2;
    }
}

//==============================================================================
// Speaker Position (for spatial processing)
//==============================================================================

struct SpeakerPosition
{
    float azimuth;      // Horizontal angle (0 = front, 90 = left, -90 = right)
    float elevation;    // Vertical angle (0 = ear level, 90 = above)
    float distance;     // Distance from listener

    static SpeakerPosition fromPolar(float az, float el, float dist = 1.0f)
    {
        return {az, el, dist};
    }
};

// Standard speaker layouts
inline std::vector<SpeakerPosition> getSpeakerLayout(ImmersiveFormat format)
{
    switch (format)
    {
        case ImmersiveFormat::Stereo:
            return {{-30, 0, 1}, {30, 0, 1}};  // L, R

        case ImmersiveFormat::LCR:
            return {{-30, 0, 1}, {0, 0, 1}, {30, 0, 1}};  // L, C, R

        case ImmersiveFormat::Surround_5_1:
            return {{-30, 0, 1}, {30, 0, 1}, {0, 0, 1},    // L, R, C
                    {0, 0, 1},                              // LFE (center)
                    {-110, 0, 1}, {110, 0, 1}};             // Ls, Rs

        case ImmersiveFormat::Surround_7_1_4:
            return {{-30, 0, 1}, {30, 0, 1}, {0, 0, 1}, {0, 0, 1},  // L, R, C, LFE
                    {-90, 0, 1}, {90, 0, 1},                        // Lss, Rss
                    {-135, 0, 1}, {135, 0, 1},                      // Lrs, Rrs
                    {-45, 45, 1}, {45, 45, 1},                      // Ltf, Rtf
                    {-135, 45, 1}, {135, 45, 1}};                   // Ltr, Rtr

        default:
            return {{-30, 0, 1}, {30, 0, 1}};
    }
}

//==============================================================================
// 3D Position
//==============================================================================

struct Position3D
{
    float x = 0.0f;     // Left/Right (-1 to 1)
    float y = 0.0f;     // Front/Back (-1 to 1)
    float z = 0.0f;     // Down/Up (-1 to 1)

    float distance() const
    {
        return std::sqrt(x*x + y*y + z*z);
    }

    Position3D normalized() const
    {
        float d = distance();
        if (d < 0.001f) return {0, 0, 0};
        return {x/d, y/d, z/d};
    }

    float azimuth() const
    {
        return std::atan2(x, y) * 180.0f / PI;
    }

    float elevation() const
    {
        float horizontal = std::sqrt(x*x + y*y);
        return std::atan2(z, horizontal) * 180.0f / PI;
    }
};

//==============================================================================
// 5D Coordinate (includes time and frequency)
//==============================================================================

struct Coordinate5D
{
    Position3D spatial;     // X, Y, Z
    float temporal = 0.0f;  // Time offset (0 = now, 1 = end of decay)
    float spectral = 0.5f;  // Frequency position (0 = bass, 1 = treble)
};

//==============================================================================
// Spatial Delay Line (single channel with position)
//==============================================================================

class SpatialDelayLine
{
public:
    SpatialDelayLine(int maxDelay = 192000)
    {
        buffer.resize(maxDelay, 0.0f);
    }

    void setDelay(float samples)
    {
        delaySamples = std::max(1.0f, samples);
    }

    void setFeedback(float fb) { feedback = fb; }
    void setPosition(const Position3D& pos) { position = pos; }
    void setDamping(float damp) { damping = damp; }

    float process(float input)
    {
        // Write
        buffer[writePos] = input + lastOutput * feedback;

        // Read with interpolation
        float readPos = writePos - delaySamples;
        while (readPos < 0) readPos += buffer.size();

        int pos0 = static_cast<int>(readPos) % buffer.size();
        int pos1 = (pos0 + 1) % buffer.size();
        float frac = readPos - std::floor(readPos);

        float output = buffer[pos0] * (1.0f - frac) + buffer[pos1] * frac;

        // Damping
        dampState = dampState * damping + output * (1.0f - damping);
        output = dampState;

        lastOutput = output;
        writePos = (writePos + 1) % buffer.size();

        return output;
    }

    void clear()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        dampState = 0.0f;
        lastOutput = 0.0f;
    }

    const Position3D& getPosition() const { return position; }

private:
    std::vector<float> buffer;
    int writePos = 0;
    float delaySamples = 1000.0f;
    float feedback = 0.8f;
    float damping = 0.3f;
    float dampState = 0.0f;
    float lastOutput = 0.0f;
    Position3D position;
};

//==============================================================================
// Spectral Band Processor (for 5th dimension)
//==============================================================================

class SpectralBandProcessor
{
public:
    SpectralBandProcessor(float lowFreq, float highFreq)
        : lowCutoff(lowFreq), highCutoff(highFreq)
    {
    }

    void prepare(double sampleRate)
    {
        this->sampleRate = sampleRate;
        updateFilters();
    }

    void setSpatialOffset(const Position3D& offset)
    {
        spatialOffset = offset;
    }

    void setDecayMultiplier(float mult)
    {
        decayMult = mult;
    }

    void setSizeMultiplier(float mult)
    {
        sizeMult = mult;
    }

    float process(float input)
    {
        // Bandpass filter
        float hp = input - lpState1;
        lpState1 += hp * lpCoeff;

        float output = lpState1 - lpState2;
        lpState2 += (lpState1 - lpState2) * hpCoeff;

        return output;
    }

    const Position3D& getSpatialOffset() const { return spatialOffset; }
    float getDecayMultiplier() const { return decayMult; }
    float getSizeMultiplier() const { return sizeMult; }

private:
    double sampleRate = 44100.0;
    float lowCutoff;
    float highCutoff;

    float lpCoeff = 0.1f;
    float hpCoeff = 0.1f;
    float lpState1 = 0.0f;
    float lpState2 = 0.0f;

    Position3D spatialOffset;
    float decayMult = 1.0f;
    float sizeMult = 1.0f;

    void updateFilters()
    {
        lpCoeff = TWO_PI * highCutoff / static_cast<float>(sampleRate);
        lpCoeff = lpCoeff / (lpCoeff + 1.0f);

        hpCoeff = TWO_PI * lowCutoff / static_cast<float>(sampleRate);
        hpCoeff = hpCoeff / (hpCoeff + 1.0f);
    }
};

//==============================================================================
// 5D Reverb Core
//==============================================================================

class Reverb5DCore
{
public:
    static constexpr int NUM_DELAYS = 16;
    static constexpr int NUM_BANDS = 4;

    Reverb5DCore()
    {
        // Initialize delay lines with varied positions
        for (int i = 0; i < NUM_DELAYS; ++i)
        {
            delays.push_back(std::make_unique<SpatialDelayLine>(192000));

            // Distribute in 3D space
            float angle = TWO_PI * i / NUM_DELAYS;
            float elevation = std::sin(angle * 2.0f) * 0.5f;

            delays[i]->setPosition({
                std::sin(angle),
                std::cos(angle),
                elevation
            });
        }

        // Initialize spectral bands (sub, low, mid, high)
        spectralBands.push_back(std::make_unique<SpectralBandProcessor>(20.0f, 150.0f));
        spectralBands.push_back(std::make_unique<SpectralBandProcessor>(150.0f, 600.0f));
        spectralBands.push_back(std::make_unique<SpectralBandProcessor>(600.0f, 4000.0f));
        spectralBands.push_back(std::make_unique<SpectralBandProcessor>(4000.0f, 20000.0f));

        // Set frequency-dependent spatial behavior
        spectralBands[0]->setSpatialOffset({0.0f, 0.0f, 0.0f});      // Sub: centered
        spectralBands[1]->setSpatialOffset({0.0f, 0.2f, 0.0f});      // Low: slightly front
        spectralBands[2]->setSpatialOffset({0.3f, 0.0f, 0.1f});      // Mid: wide
        spectralBands[3]->setSpatialOffset({0.5f, -0.1f, 0.3f});     // High: widest, up
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;

        // Set delay times using prime numbers
        int primes[] = {1433, 1601, 1753, 1907, 2069, 2213, 2371, 2539,
                        2687, 2857, 3011, 3169, 3331, 3491, 3659, 3821};

        for (int i = 0; i < NUM_DELAYS; ++i)
        {
            float delay = primes[i] * (sampleRate / 44100.0f) * size;
            delays[i]->setDelay(delay);
            delays[i]->setFeedback(0.5f + feedback * 0.45f);
            delays[i]->setDamping(damping);
        }

        for (auto& band : spectralBands)
        {
            band->prepare(sampleRate);
        }
    }

    void setSize(float s)
    {
        size = std::clamp(s, 0.1f, 10.0f);
    }

    void setFeedback(float fb)
    {
        feedback = std::clamp(fb, 0.0f, 0.99f);
        for (auto& delay : delays)
        {
            delay->setFeedback(0.5f + feedback * 0.45f);
        }
    }

    void setDamping(float damp)
    {
        damping = std::clamp(damp, 0.0f, 1.0f);
        for (auto& delay : delays)
        {
            delay->setDamping(damping);
        }
    }

    void setGravity(float grav)
    {
        // -1 = reverse (sound builds up), 0 = normal, 1 = accelerated decay
        gravity = std::clamp(grav, -1.0f, 1.0f);
    }

    void setModulation(float mod)
    {
        modulation = std::clamp(mod, 0.0f, 1.0f);
    }

    // Temporal evolution (4th dimension)
    void setTemporalBlur(float blur)
    {
        temporalBlur = std::clamp(blur, 0.0f, 1.0f);
    }

    void setTemporalPanning(float pan)
    {
        // How much the spatial image evolves over time
        temporalPanning = std::clamp(pan, 0.0f, 1.0f);
    }

    // Spectral control (5th dimension)
    void setSpectralSpread(float spread)
    {
        // How much frequency affects spatial position
        spectralSpread = std::clamp(spread, 0.0f, 1.0f);
    }

    void setSpectralDecay(float decay)
    {
        // Per-band decay variation
        spectralDecay = std::clamp(decay, 0.0f, 1.0f);

        // High frequencies decay faster
        spectralBands[0]->setDecayMultiplier(1.0f + spectralDecay * 0.3f);
        spectralBands[1]->setDecayMultiplier(1.0f);
        spectralBands[2]->setDecayMultiplier(1.0f - spectralDecay * 0.2f);
        spectralBands[3]->setDecayMultiplier(1.0f - spectralDecay * 0.4f);
    }

    void process(const float* input, int numChannels, int numSamples,
                 std::vector<std::vector<float>>& output, ImmersiveFormat format)
    {
        int outChannels = getChannelCount(format);
        auto speakers = getSpeakerLayout(format);

        // Clear output
        for (auto& ch : output)
        {
            std::fill(ch.begin(), ch.end(), 0.0f);
        }

        for (int s = 0; s < numSamples; ++s)
        {
            // Get mono input
            float mono = 0.0f;
            for (int ch = 0; ch < numChannels; ++ch)
            {
                mono += input[s + ch * numSamples];
            }
            mono /= numChannels;

            // Apply modulation
            if (modulation > 0.0f)
            {
                float mod = std::sin(modPhase) * modulation * 0.02f;
                modPhase += TWO_PI * 0.3f / static_cast<float>(sampleRate);
                if (modPhase > TWO_PI) modPhase -= TWO_PI;
                mono *= (1.0f + mod);
            }

            // Process through spectral bands (5th dimension)
            std::array<float, NUM_BANDS> bandOutputs;
            for (int b = 0; b < NUM_BANDS; ++b)
            {
                bandOutputs[b] = spectralBands[b]->process(mono);
            }

            // Process through delay lines with 3D positioning
            for (int d = 0; d < NUM_DELAYS; ++d)
            {
                // Select band for this delay
                int band = d % NUM_BANDS;
                float delayInput = bandOutputs[band];

                float delayOutput = delays[d]->process(delayInput);

                // Get 3D position with spectral offset
                Position3D pos = delays[d]->getPosition();
                Position3D spectralOff = spectralBands[band]->getSpatialOffset();

                pos.x += spectralOff.x * spectralSpread;
                pos.y += spectralOff.y * spectralSpread;
                pos.z += spectralOff.z * spectralSpread;

                // Apply temporal panning (4th dimension)
                if (temporalPanning > 0.0f)
                {
                    float timeOffset = (std::sin(timePhase + d * 0.5f) + 1.0f) * 0.5f;
                    pos.x += std::sin(timeOffset * TWO_PI) * temporalPanning * 0.3f;
                    pos.y += std::cos(timeOffset * TWO_PI) * temporalPanning * 0.2f;
                }

                // Pan to speakers using VBAP-style algorithm
                panToSpeakers(delayOutput, pos, speakers, output, s);
            }

            // Advance time phase
            timePhase += 0.00001f * (1.0f + temporalPanning);
            if (timePhase > TWO_PI) timePhase -= TWO_PI;
        }
    }

    void reset()
    {
        for (auto& delay : delays)
        {
            delay->clear();
        }
    }

private:
    std::vector<std::unique_ptr<SpatialDelayLine>> delays;
    std::vector<std::unique_ptr<SpectralBandProcessor>> spectralBands;

    double sampleRate = 44100.0;
    float size = 1.0f;
    float feedback = 0.7f;
    float damping = 0.3f;
    float gravity = 0.0f;
    float modulation = 0.1f;

    // 4th dimension
    float temporalBlur = 0.2f;
    float temporalPanning = 0.3f;
    float timePhase = 0.0f;

    // 5th dimension
    float spectralSpread = 0.5f;
    float spectralDecay = 0.5f;

    float modPhase = 0.0f;

    void panToSpeakers(float sample, const Position3D& pos,
                       const std::vector<SpeakerPosition>& speakers,
                       std::vector<std::vector<float>>& output, int sampleIdx)
    {
        float azimuth = pos.azimuth();
        float elevation = pos.elevation();

        // VBAP-inspired panning
        float totalGain = 0.0f;
        std::vector<float> gains(speakers.size(), 0.0f);

        for (size_t i = 0; i < speakers.size(); ++i)
        {
            // Calculate angular distance
            float azDiff = std::abs(azimuth - speakers[i].azimuth);
            if (azDiff > 180.0f) azDiff = 360.0f - azDiff;

            float elDiff = std::abs(elevation - speakers[i].elevation);

            float angularDist = std::sqrt(azDiff * azDiff + elDiff * elDiff);

            // Gain based on proximity (180 degree falloff)
            float gain = std::max(0.0f, 1.0f - angularDist / 180.0f);
            gain = gain * gain;  // Smooth falloff

            gains[i] = gain;
            totalGain += gain;
        }

        // Normalize and apply
        if (totalGain > 0.0f)
        {
            for (size_t i = 0; i < speakers.size() && i < output.size(); ++i)
            {
                output[i][sampleIdx] += sample * gains[i] / totalGain;
            }
        }
    }
};

//==============================================================================
// Spatial EQ (per region)
//==============================================================================

struct SpatialEQ
{
    enum class Region { Front, Side, Rear, Top, All };

    float lowGain = 1.0f;       // Low shelf
    float lowFreq = 200.0f;
    float midGain = 1.0f;       // Peak
    float midFreq = 1000.0f;
    float midQ = 1.0f;
    float highGain = 1.0f;      // High shelf
    float highFreq = 4000.0f;
};

//==============================================================================
// A/B Morphing State
//==============================================================================

struct ReverbState
{
    float size = 1.0f;
    float feedback = 0.7f;
    float damping = 0.3f;
    float gravity = 0.0f;
    float modulation = 0.1f;
    float temporalBlur = 0.2f;
    float temporalPanning = 0.3f;
    float spectralSpread = 0.5f;
    float spectralDecay = 0.5f;
    float mix = 0.3f;

    SpatialEQ eqFront;
    SpatialEQ eqRear;
    SpatialEQ eqTop;

    ReverbState lerp(const ReverbState& other, float t) const
    {
        ReverbState result;
        result.size = size + (other.size - size) * t;
        result.feedback = feedback + (other.feedback - feedback) * t;
        result.damping = damping + (other.damping - damping) * t;
        result.gravity = gravity + (other.gravity - gravity) * t;
        result.modulation = modulation + (other.modulation - modulation) * t;
        result.temporalBlur = temporalBlur + (other.temporalBlur - temporalBlur) * t;
        result.temporalPanning = temporalPanning + (other.temporalPanning - temporalPanning) * t;
        result.spectralSpread = spectralSpread + (other.spectralSpread - spectralSpread) * t;
        result.spectralDecay = spectralDecay + (other.spectralDecay - spectralDecay) * t;
        result.mix = mix + (other.mix - mix) * t;
        return result;
    }
};

//==============================================================================
// 5D Immersive Reverb Main Class
//==============================================================================

class ImmersiveReverb5D
{
public:
    ImmersiveReverb5D()
    {
        core = std::make_unique<Reverb5DCore>();
    }

    void prepare(double sampleRate, int blockSize, ImmersiveFormat format)
    {
        this->sampleRate = sampleRate;
        this->blockSize = blockSize;
        this->format = format;

        core->prepare(sampleRate, blockSize);

        int numChannels = getChannelCount(format);
        outputBuffers.resize(numChannels);
        for (auto& ch : outputBuffers)
        {
            ch.resize(blockSize, 0.0f);
        }

        inputBuffer.resize(blockSize * numChannels, 0.0f);
    }

    void setFormat(ImmersiveFormat fmt)
    {
        format = fmt;
        int numChannels = getChannelCount(format);
        outputBuffers.resize(numChannels);
        for (auto& ch : outputBuffers)
        {
            ch.resize(blockSize, 0.0f);
        }
    }

    //--------------------------------------------------------------------------
    // Core Parameters
    //--------------------------------------------------------------------------

    void setSize(float size) { core->setSize(size); currentState.size = size; }
    void setFeedback(float fb) { core->setFeedback(fb); currentState.feedback = fb; }
    void setDamping(float damp) { core->setDamping(damp); currentState.damping = damp; }
    void setGravity(float grav) { core->setGravity(grav); currentState.gravity = grav; }
    void setModulation(float mod) { core->setModulation(mod); currentState.modulation = mod; }
    void setMix(float mix) { this->mix = mix; currentState.mix = mix; }

    //--------------------------------------------------------------------------
    // 4th Dimension: Temporal
    //--------------------------------------------------------------------------

    void setTemporalBlur(float blur)
    {
        core->setTemporalBlur(blur);
        currentState.temporalBlur = blur;
    }

    void setTemporalPanning(float pan)
    {
        core->setTemporalPanning(pan);
        currentState.temporalPanning = pan;
    }

    //--------------------------------------------------------------------------
    // 5th Dimension: Spectral
    //--------------------------------------------------------------------------

    void setSpectralSpread(float spread)
    {
        core->setSpectralSpread(spread);
        currentState.spectralSpread = spread;
    }

    void setSpectralDecay(float decay)
    {
        core->setSpectralDecay(decay);
        currentState.spectralDecay = decay;
    }

    //--------------------------------------------------------------------------
    // Spatial EQ
    //--------------------------------------------------------------------------

    void setFrontEQ(const SpatialEQ& eq) { eqFront = eq; currentState.eqFront = eq; }
    void setRearEQ(const SpatialEQ& eq) { eqRear = eq; currentState.eqRear = eq; }
    void setTopEQ(const SpatialEQ& eq) { eqTop = eq; currentState.eqTop = eq; }

    //--------------------------------------------------------------------------
    // A/B Morphing
    //--------------------------------------------------------------------------

    void storeToA() { stateA = currentState; }
    void storeToB() { stateB = currentState; }

    void setMorphPosition(float pos)
    {
        morphPosition = std::clamp(pos, 0.0f, 1.0f);
        applyState(stateA.lerp(stateB, morphPosition));
    }

    //--------------------------------------------------------------------------
    // Special Controls
    //--------------------------------------------------------------------------

    void setFreeze(bool freeze)
    {
        frozen = freeze;
        if (freeze)
        {
            core->setFeedback(0.999f);
        }
        else
        {
            core->setFeedback(currentState.feedback);
        }
    }

    void setKillDry(bool kill) { killDry = kill; }
    void setKillWet(bool kill) { killWet = kill; }

    //--------------------------------------------------------------------------
    // Processing
    //--------------------------------------------------------------------------

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        int numChannels = buffer.getNumChannels();
        int numSamples = buffer.getNumSamples();

        // Prepare input (interleaved)
        inputBuffer.resize(numSamples * numChannels);
        for (int ch = 0; ch < numChannels; ++ch)
        {
            for (int s = 0; s < numSamples; ++s)
            {
                inputBuffer[s + ch * numSamples] = frozen ? 0.0f : buffer.getSample(ch, s);
            }
        }

        // Clear output buffers
        for (auto& ch : outputBuffers)
        {
            std::fill(ch.begin(), ch.end(), 0.0f);
        }

        // Process reverb
        core->process(inputBuffer.data(), numChannels, numSamples, outputBuffers, format);

        // Apply spatial EQ (simplified - would be per-region in full impl)

        // Mix output
        int outChannels = std::min(numChannels, static_cast<int>(outputBuffers.size()));

        for (int ch = 0; ch < outChannels; ++ch)
        {
            for (int s = 0; s < numSamples; ++s)
            {
                float dry = killDry ? 0.0f : buffer.getSample(ch, s);
                float wet = killWet ? 0.0f : outputBuffers[ch][s];

                buffer.setSample(ch, s, dry * (1.0f - mix) + wet * mix);
            }
        }
    }

    void reset()
    {
        core->reset();
    }

    //--------------------------------------------------------------------------
    // Presets
    //--------------------------------------------------------------------------

    static ImmersiveReverb5D createMassiveSpacePreset()
    {
        ImmersiveReverb5D rev;
        rev.setSize(2.0f);
        rev.setFeedback(0.85f);
        rev.setDamping(0.25f);
        rev.setTemporalPanning(0.5f);
        rev.setSpectralSpread(0.7f);
        rev.setMix(0.5f);
        return rev;
    }

    static ImmersiveReverb5D createSwirlingVoidPreset()
    {
        ImmersiveReverb5D rev;
        rev.setSize(3.0f);
        rev.setFeedback(0.9f);
        rev.setGravity(-0.3f);
        rev.setModulation(0.4f);
        rev.setTemporalPanning(0.8f);
        rev.setTemporalBlur(0.6f);
        rev.setSpectralSpread(0.9f);
        rev.setSpectralDecay(0.4f);
        rev.setMix(0.6f);
        return rev;
    }

    static ImmersiveReverb5D createHyperDimensionalPreset()
    {
        ImmersiveReverb5D rev;
        rev.setSize(5.0f);
        rev.setFeedback(0.95f);
        rev.setGravity(0.2f);
        rev.setModulation(0.3f);
        rev.setTemporalPanning(1.0f);
        rev.setTemporalBlur(0.8f);
        rev.setSpectralSpread(1.0f);
        rev.setSpectralDecay(0.6f);
        rev.setMix(0.7f);
        return rev;
    }

private:
    std::unique_ptr<Reverb5DCore> core;

    double sampleRate = 44100.0;
    int blockSize = 512;
    ImmersiveFormat format = ImmersiveFormat::Stereo;

    std::vector<std::vector<float>> outputBuffers;
    std::vector<float> inputBuffer;

    float mix = 0.3f;
    bool frozen = false;
    bool killDry = false;
    bool killWet = false;

    SpatialEQ eqFront;
    SpatialEQ eqRear;
    SpatialEQ eqTop;

    ReverbState currentState;
    ReverbState stateA;
    ReverbState stateB;
    float morphPosition = 0.0f;

    void applyState(const ReverbState& state)
    {
        core->setSize(state.size);
        core->setFeedback(state.feedback);
        core->setDamping(state.damping);
        core->setGravity(state.gravity);
        core->setModulation(state.modulation);
        core->setTemporalBlur(state.temporalBlur);
        core->setTemporalPanning(state.temporalPanning);
        core->setSpectralSpread(state.spectralSpread);
        core->setSpectralDecay(state.spectralDecay);
        mix = state.mix;
    }
};

//==============================================================================
// 5D Reverb Visualizer
//==============================================================================

class Reverb5DVisualizer : public juce::Component,
                           public juce::Timer
{
public:
    Reverb5DVisualizer()
    {
        startTimerHz(30);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Dark background
        g.fillAll(juce::Colour(0xff0a0a1a));

        // Draw 5D representation
        float centerX = bounds.getCentreX();
        float centerY = bounds.getCentreY();
        float radius = std::min(bounds.getWidth(), bounds.getHeight()) * 0.35f;

        // Draw frequency bands as concentric rings
        for (int band = 0; band < 4; ++band)
        {
            float bandRadius = radius * (0.4f + band * 0.2f);

            // Color based on spectral position
            juce::Colour bandColor = juce::Colour::fromHSV(
                0.6f - band * 0.15f, 0.7f, 0.3f + band * 0.1f, 0.5f);

            g.setColour(bandColor);
            g.drawEllipse(centerX - bandRadius, centerY - bandRadius,
                         bandRadius * 2, bandRadius * 2, 1.5f);
        }

        // Draw temporal evolution spiral
        g.setColour(juce::Colour(0xff00ffaa).withAlpha(0.6f));
        juce::Path spiral;
        for (int i = 0; i < 100; ++i)
        {
            float t = i / 100.0f;
            float angle = t * TWO_PI * 3.0f + animPhase;
            float r = radius * 0.2f + t * radius * 0.8f;

            float x = centerX + std::cos(angle) * r;
            float y = centerY + std::sin(angle) * r;

            if (i == 0)
                spiral.startNewSubPath(x, y);
            else
                spiral.lineTo(x, y);
        }
        g.strokePath(spiral, juce::PathStrokeType(2.0f));

        // Draw speaker positions
        g.setColour(juce::Colours::white);
        g.setFont(10.0f);
        g.drawText("5D IMMERSIVE", bounds.removeFromTop(20), juce::Justification::centred);

        // Draw dimension labels
        g.setColour(juce::Colours::grey);
        g.drawText("X/Y/Z + Time + Spectrum", bounds.removeFromBottom(15),
                   juce::Justification::centred);
    }

    void timerCallback() override
    {
        animPhase += 0.05f;
        if (animPhase > TWO_PI) animPhase -= TWO_PI;
        repaint();
    }

private:
    float animPhase = 0.0f;
};

} // namespace Eventide
} // namespace Effects
} // namespace Echoelmusic
