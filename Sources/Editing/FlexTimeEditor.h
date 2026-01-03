#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <cmath>
#include <algorithm>

/**
 * FlexTimeEditor - Beat-Aware Non-Destructive Time Editing
 *
 * Professional flex time / elastic audio editing:
 * - Transient detection and markers
 * - Beat-aware time quantization
 * - Non-destructive time stretching
 * - Individual transient manipulation
 * - Groove templates
 * - Audio quantize to MIDI/grid
 * - Phase-coherent multi-track editing
 * - Real-time and offline modes
 *
 * Inspired by: Pro Tools Elastic Audio, Logic Flex Time, Ableton Warp
 */

namespace Echoelmusic {
namespace Editing {

//==============================================================================
// Flex Marker
//==============================================================================

struct FlexMarker
{
    double originalSample = 0;       // Position in original audio
    double warpedSample = 0;         // Position after warping
    double strength = 1.0;           // Transient strength (0-1)

    bool isLocked = false;           // User-locked marker
    bool isTransient = true;         // Auto-detected transient
    bool isDownbeat = false;         // Beat/bar boundary

    juce::String label;

    FlexMarker() = default;

    FlexMarker(double original, double warped = -1, double str = 1.0)
        : originalSample(original)
        , warpedSample(warped < 0 ? original : warped)
        , strength(str) {}
};

//==============================================================================
// Flex Mode
//==============================================================================

enum class FlexMode
{
    Polyphonic,          // Best for complex audio, chords
    Rhythmic,            // Best for drums, percussion
    Monophonic,          // Best for vocals, bass
    Slicing,             // Slice at transients, no time-stretch
    Tempophone,          // Extreme time manipulation (experimental)
    Speed                // Simple varispeed (changes pitch)
};

//==============================================================================
// Quantize Settings
//==============================================================================

struct QuantizeSettings
{
    enum class Grid { Off, Bar, Beat, Eighth, Sixteenth, Thirtysecond, Triplet };

    Grid grid = Grid::Sixteenth;
    float strength = 100.0f;         // 0-100%
    float sensitivity = 50.0f;       // Transient detection sensitivity

    bool quantizeStart = true;
    bool quantizeEnd = false;

    // Humanize
    float humanizeAmount = 0.0f;     // 0-100%

    // Swing
    float swingAmount = 0.0f;        // 0-100%
    Grid swingBase = Grid::Eighth;
};

//==============================================================================
// Groove Template
//==============================================================================

struct GrooveTemplate
{
    juce::String name;
    std::vector<double> timingOffsets;   // Deviation from grid (in beats)
    std::vector<float> velocityScales;   // Velocity modifiers

    int resolution = 16;                  // Divisions per bar

    GrooveTemplate() = default;

    GrooveTemplate(const juce::String& n, int res = 16)
        : name(n), resolution(res)
    {
        timingOffsets.resize(res, 0.0);
        velocityScales.resize(res, 1.0f);
    }
};

//==============================================================================
// Flex Region
//==============================================================================

struct FlexRegion
{
    double startSample = 0;
    double endSample = 0;

    std::vector<FlexMarker> markers;

    FlexMode mode = FlexMode::Polyphonic;

    // Original audio reference
    juce::AudioBuffer<float> originalAudio;
    double originalSampleRate = 48000.0;
    double originalTempo = 120.0;

    // Processed audio cache
    juce::AudioBuffer<float> processedAudio;
    bool cacheValid = false;
};

//==============================================================================
// Flex Time Editor
//==============================================================================

class FlexTimeEditor
{
public:
    //==========================================================================
    // Constructor
    //==========================================================================

    FlexTimeEditor() = default;

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        this->maxBlockSize = maxBlockSize;

        // Initialize FFT for analysis
        fftSize = 2048;
        fft = std::make_unique<juce::dsp::FFT>(static_cast<int>(std::log2(fftSize)));
        window.resize(fftSize);
        for (int i = 0; i < fftSize; ++i)
        {
            window[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * i / (fftSize - 1)));
        }
    }

    //==========================================================================
    // Load Audio
    //==========================================================================

    void loadAudio(const juce::AudioBuffer<float>& audio, double sampleRate, double tempo = 120.0)
    {
        region.originalAudio = audio;
        region.originalSampleRate = sampleRate;
        region.originalTempo = tempo;
        region.startSample = 0;
        region.endSample = audio.getNumSamples();
        region.markers.clear();
        region.cacheValid = false;

        // Auto-detect transients
        detectTransients();
    }

    //==========================================================================
    // Flex Mode
    //==========================================================================

    void setFlexMode(FlexMode mode)
    {
        region.mode = mode;
        region.cacheValid = false;
    }

    FlexMode getFlexMode() const { return region.mode; }

    //==========================================================================
    // Transient Detection
    //==========================================================================

    void detectTransients(float sensitivity = 0.5f)
    {
        region.markers.clear();

        if (region.originalAudio.getNumSamples() == 0)
            return;

        const int hopSize = fftSize / 4;
        const int numHops = (region.originalAudio.getNumSamples() - fftSize) / hopSize;

        std::vector<float> onsetFunction(numHops, 0.0f);
        std::vector<float> fftBuffer(fftSize * 2, 0.0f);
        std::vector<float> prevMagnitudes(fftSize / 2, 0.0f);

        // Compute spectral flux
        for (int hop = 0; hop < numHops; ++hop)
        {
            int startSample = hop * hopSize;

            // Copy and window
            for (int i = 0; i < fftSize; ++i)
            {
                int idx = startSample + i;
                if (idx < region.originalAudio.getNumSamples())
                    fftBuffer[i] = region.originalAudio.getSample(0, idx) * window[i];
                else
                    fftBuffer[i] = 0.0f;
            }

            // FFT
            fft->performRealOnlyForwardTransform(fftBuffer.data());

            // Compute spectral flux
            float flux = 0.0f;
            for (int i = 0; i < fftSize / 2; ++i)
            {
                float real = fftBuffer[i * 2];
                float imag = fftBuffer[i * 2 + 1];
                float mag = std::sqrt(real * real + imag * imag);

                float diff = mag - prevMagnitudes[i];
                if (diff > 0)
                    flux += diff;

                prevMagnitudes[i] = mag;
            }

            onsetFunction[hop] = flux;
        }

        // Peak picking with adaptive threshold
        float threshold = sensitivity * 1000.0f;
        float adaptiveThreshold = 0.0f;
        float adaptiveAlpha = 0.1f;

        for (int hop = 1; hop < numHops - 1; ++hop)
        {
            adaptiveThreshold = adaptiveThreshold * (1.0f - adaptiveAlpha) +
                               onsetFunction[hop] * adaptiveAlpha;

            float peakThreshold = std::max(threshold, adaptiveThreshold * 1.5f);

            if (onsetFunction[hop] > peakThreshold &&
                onsetFunction[hop] > onsetFunction[hop - 1] &&
                onsetFunction[hop] > onsetFunction[hop + 1])
            {
                double samplePos = hop * hopSize;
                float strength = onsetFunction[hop] / (threshold * 10.0f);
                strength = std::min(1.0f, strength);

                region.markers.emplace_back(samplePos, samplePos, strength);
            }
        }

        // Add start and end markers
        if (region.markers.empty() || region.markers.front().originalSample > hopSize)
        {
            region.markers.insert(region.markers.begin(),
                FlexMarker(0, 0, 1.0));
        }

        if (region.markers.empty() ||
            region.markers.back().originalSample < region.originalAudio.getNumSamples() - hopSize)
        {
            double endPos = region.originalAudio.getNumSamples();
            region.markers.emplace_back(endPos, endPos, 1.0);
        }

        if (onTransientsDetected)
            onTransientsDetected(static_cast<int>(region.markers.size()));
    }

    //==========================================================================
    // Marker Manipulation
    //==========================================================================

    int getNumMarkers() const { return static_cast<int>(region.markers.size()); }

    FlexMarker* getMarker(int index)
    {
        if (index >= 0 && index < static_cast<int>(region.markers.size()))
            return &region.markers[index];
        return nullptr;
    }

    /** Move a marker to new position */
    void moveMarker(int index, double newWarpedPosition)
    {
        if (index >= 0 && index < static_cast<int>(region.markers.size()))
        {
            region.markers[index].warpedSample = newWarpedPosition;
            region.cacheValid = false;
        }
    }

    /** Lock/unlock marker */
    void setMarkerLocked(int index, bool locked)
    {
        if (index >= 0 && index < static_cast<int>(region.markers.size()))
            region.markers[index].isLocked = locked;
    }

    /** Add marker at position */
    int addMarker(double samplePosition)
    {
        FlexMarker marker(samplePosition, samplePosition, 0.5);
        marker.isTransient = false;

        // Insert sorted
        auto it = std::lower_bound(region.markers.begin(), region.markers.end(), marker,
            [](const FlexMarker& a, const FlexMarker& b) {
                return a.originalSample < b.originalSample;
            });

        it = region.markers.insert(it, marker);
        region.cacheValid = false;

        return static_cast<int>(std::distance(region.markers.begin(), it));
    }

    /** Remove marker */
    void removeMarker(int index)
    {
        if (index >= 0 && index < static_cast<int>(region.markers.size()))
        {
            // Don't remove first or last marker
            if (index == 0 || index == static_cast<int>(region.markers.size()) - 1)
                return;

            region.markers.erase(region.markers.begin() + index);
            region.cacheValid = false;
        }
    }

    //==========================================================================
    // Quantization
    //==========================================================================

    void setQuantizeSettings(const QuantizeSettings& settings)
    {
        quantizeSettings = settings;
    }

    /** Quantize all unlocked markers to grid */
    void quantizeToGrid(double tempo)
    {
        if (quantizeSettings.grid == QuantizeSettings::Grid::Off)
            return;

        double samplesPerBeat = currentSampleRate * 60.0 / tempo;
        double gridSamples = getGridSamples(quantizeSettings.grid, samplesPerBeat);

        for (auto& marker : region.markers)
        {
            if (marker.isLocked)
                continue;

            // Find nearest grid position
            double nearestGrid = std::round(marker.originalSample / gridSamples) * gridSamples;

            // Apply with strength
            double delta = nearestGrid - marker.originalSample;
            double strength = quantizeSettings.strength / 100.0;

            marker.warpedSample = marker.originalSample + delta * strength;

            // Apply humanize
            if (quantizeSettings.humanizeAmount > 0)
            {
                double humanize = (static_cast<double>(rand()) / RAND_MAX - 0.5) * 2.0;
                humanize *= gridSamples * 0.1 * (quantizeSettings.humanizeAmount / 100.0);
                marker.warpedSample += humanize;
            }
        }

        region.cacheValid = false;
    }

    //==========================================================================
    // Groove Templates
    //==========================================================================

    void applyGrooveTemplate(const GrooveTemplate& groove, double tempo)
    {
        double samplesPerBar = currentSampleRate * 60.0 / tempo * 4.0;  // Assuming 4/4
        double samplesPerStep = samplesPerBar / groove.resolution;

        for (auto& marker : region.markers)
        {
            if (marker.isLocked)
                continue;

            // Find position in bar
            double posInBar = std::fmod(marker.originalSample, samplesPerBar);
            int stepIndex = static_cast<int>(posInBar / samplesPerStep) % groove.resolution;

            // Apply groove offset
            double offset = groove.timingOffsets[stepIndex] * samplesPerStep;
            marker.warpedSample = marker.originalSample + offset;
        }

        region.cacheValid = false;
    }

    /** Extract groove from current audio */
    GrooveTemplate extractGroove(double tempo, int resolution = 16)
    {
        GrooveTemplate groove("Extracted", resolution);

        double samplesPerBar = currentSampleRate * 60.0 / tempo * 4.0;
        double samplesPerStep = samplesPerBar / resolution;

        std::vector<std::vector<double>> stepDeviations(resolution);

        for (const auto& marker : region.markers)
        {
            if (!marker.isTransient)
                continue;

            double posInBar = std::fmod(marker.originalSample, samplesPerBar);
            int nearestStep = static_cast<int>(std::round(posInBar / samplesPerStep)) % resolution;
            double expectedPos = nearestStep * samplesPerStep;
            double deviation = (marker.originalSample - expectedPos) / samplesPerStep;

            stepDeviations[nearestStep].push_back(deviation);
        }

        // Average deviations
        for (int i = 0; i < resolution; ++i)
        {
            if (!stepDeviations[i].empty())
            {
                double sum = 0;
                for (double d : stepDeviations[i])
                    sum += d;
                groove.timingOffsets[i] = sum / stepDeviations[i].size();
            }
        }

        return groove;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Get processed audio buffer */
    const juce::AudioBuffer<float>& getProcessedAudio()
    {
        if (!region.cacheValid)
            processAudio();

        return region.processedAudio;
    }

    /** Process real-time block */
    void processBlock(juce::AudioBuffer<float>& buffer, double playheadSample)
    {
        // For real-time use, interpolate from processed cache
        if (!region.cacheValid)
            processAudio();

        int numSamples = buffer.getNumSamples();

        for (int i = 0; i < numSamples; ++i)
        {
            double sourceSample = playheadSample + i;

            // Convert warped position to original position
            double originalPos = warpedToOriginal(sourceSample);

            // Interpolate from original audio
            for (int ch = 0; ch < std::min(buffer.getNumChannels(),
                                           region.originalAudio.getNumChannels()); ++ch)
            {
                float sample = interpolateSample(region.originalAudio, ch, originalPos);
                buffer.setSample(ch, i, sample);
            }
        }
    }

    //==========================================================================
    // Preset Groove Templates
    //==========================================================================

    static GrooveTemplate createSwingGroove(float swingAmount)
    {
        GrooveTemplate groove("Swing", 16);

        // Apply swing to off-beats (odd indices)
        for (int i = 1; i < 16; i += 2)
        {
            groove.timingOffsets[i] = swingAmount * 0.33;  // Delay off-beats
        }

        return groove;
    }

    static GrooveTemplate createHumanizeGroove(float amount)
    {
        GrooveTemplate groove("Humanize", 16);

        for (int i = 0; i < 16; ++i)
        {
            groove.timingOffsets[i] = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * amount * 0.1;
        }

        return groove;
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(int)> onTransientsDetected;
    std::function<void(int, double)> onMarkerMoved;

private:
    double currentSampleRate = 48000.0;
    int maxBlockSize = 512;

    FlexRegion region;
    QuantizeSettings quantizeSettings;

    // FFT for analysis
    int fftSize = 2048;
    std::unique_ptr<juce::dsp::FFT> fft;
    std::vector<float> window;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    double getGridSamples(QuantizeSettings::Grid grid, double samplesPerBeat)
    {
        switch (grid)
        {
            case QuantizeSettings::Grid::Bar:          return samplesPerBeat * 4;
            case QuantizeSettings::Grid::Beat:         return samplesPerBeat;
            case QuantizeSettings::Grid::Eighth:       return samplesPerBeat / 2;
            case QuantizeSettings::Grid::Sixteenth:    return samplesPerBeat / 4;
            case QuantizeSettings::Grid::Thirtysecond: return samplesPerBeat / 8;
            case QuantizeSettings::Grid::Triplet:      return samplesPerBeat / 3;
            default:                                   return samplesPerBeat;
        }
    }

    double warpedToOriginal(double warpedPos)
    {
        if (region.markers.size() < 2)
            return warpedPos;

        // Find surrounding markers
        for (size_t i = 0; i < region.markers.size() - 1; ++i)
        {
            const auto& m0 = region.markers[i];
            const auto& m1 = region.markers[i + 1];

            if (warpedPos >= m0.warpedSample && warpedPos <= m1.warpedSample)
            {
                // Linear interpolation
                double t = (warpedPos - m0.warpedSample) / (m1.warpedSample - m0.warpedSample);
                return m0.originalSample + t * (m1.originalSample - m0.originalSample);
            }
        }

        return warpedPos;
    }

    float interpolateSample(const juce::AudioBuffer<float>& buffer, int channel, double position)
    {
        if (position < 0 || position >= buffer.getNumSamples() - 1)
            return 0.0f;

        int pos0 = static_cast<int>(position);
        int pos1 = pos0 + 1;
        float frac = static_cast<float>(position - pos0);

        float s0 = buffer.getSample(channel, pos0);
        float s1 = buffer.getSample(channel, pos1);

        return s0 + frac * (s1 - s0);
    }

    void processAudio()
    {
        if (region.originalAudio.getNumSamples() == 0)
            return;

        // Calculate output length based on last marker
        int outputLength = static_cast<int>(region.markers.back().warpedSample) + 1024;
        region.processedAudio.setSize(region.originalAudio.getNumChannels(), outputLength);
        region.processedAudio.clear();

        // Process based on mode
        switch (region.mode)
        {
            case FlexMode::Slicing:
                processSlicing();
                break;

            case FlexMode::Speed:
                processSpeed();
                break;

            case FlexMode::Polyphonic:
            case FlexMode::Rhythmic:
            case FlexMode::Monophonic:
            default:
                processTimeStretch();
                break;
        }

        region.cacheValid = true;
    }

    void processSlicing()
    {
        // Simple slice-based processing (no time-stretch)
        for (size_t i = 0; i < region.markers.size() - 1; ++i)
        {
            const auto& m0 = region.markers[i];
            const auto& m1 = region.markers[i + 1];

            int srcStart = static_cast<int>(m0.originalSample);
            int srcEnd = static_cast<int>(m1.originalSample);
            int destStart = static_cast<int>(m0.warpedSample);

            int length = srcEnd - srcStart;

            for (int ch = 0; ch < region.originalAudio.getNumChannels(); ++ch)
            {
                for (int j = 0; j < length; ++j)
                {
                    int destPos = destStart + j;
                    if (destPos >= 0 && destPos < region.processedAudio.getNumSamples())
                    {
                        float sample = region.originalAudio.getSample(ch, srcStart + j);
                        region.processedAudio.addSample(ch, destPos, sample);
                    }
                }
            }
        }
    }

    void processSpeed()
    {
        // Simple varispeed (changes pitch)
        for (int i = 0; i < region.processedAudio.getNumSamples(); ++i)
        {
            double srcPos = warpedToOriginal(i);

            for (int ch = 0; ch < region.originalAudio.getNumChannels(); ++ch)
            {
                float sample = interpolateSample(region.originalAudio, ch, srcPos);
                region.processedAudio.setSample(ch, i, sample);
            }
        }
    }

    void processTimeStretch()
    {
        // Phase vocoder time stretch (simplified)
        const int hopSize = fftSize / 4;
        const int numChannels = region.originalAudio.getNumChannels();

        std::vector<float> fftIn(fftSize * 2, 0.0f);
        std::vector<float> fftOut(fftSize * 2, 0.0f);
        std::vector<float> prevPhase(fftSize / 2, 0.0f);
        std::vector<float> synthPhase(fftSize / 2, 0.0f);

        for (int ch = 0; ch < numChannels; ++ch)
        {
            std::fill(prevPhase.begin(), prevPhase.end(), 0.0f);
            std::fill(synthPhase.begin(), synthPhase.end(), 0.0f);

            for (int outHop = 0; outHop < region.processedAudio.getNumSamples() / hopSize; ++outHop)
            {
                double outCenter = outHop * hopSize;
                double srcCenter = warpedToOriginal(outCenter);

                // Analysis
                for (int i = 0; i < fftSize; ++i)
                {
                    double srcPos = srcCenter - fftSize / 2 + i;
                    if (srcPos >= 0 && srcPos < region.originalAudio.getNumSamples())
                        fftIn[i] = interpolateSample(region.originalAudio, ch, srcPos) * window[i];
                    else
                        fftIn[i] = 0.0f;
                }

                fft->performRealOnlyForwardTransform(fftIn.data());

                // Phase vocoder processing
                for (int bin = 0; bin < fftSize / 2; ++bin)
                {
                    float real = fftIn[bin * 2];
                    float imag = fftIn[bin * 2 + 1];

                    float mag = std::sqrt(real * real + imag * imag);
                    float phase = std::atan2(imag, real);

                    // Phase advance
                    synthPhase[bin] += phase - prevPhase[bin];
                    prevPhase[bin] = phase;

                    fftOut[bin * 2] = mag * std::cos(synthPhase[bin]);
                    fftOut[bin * 2 + 1] = mag * std::sin(synthPhase[bin]);
                }

                // Synthesis
                fft->performRealOnlyInverseTransform(fftOut.data());

                // Overlap-add
                for (int i = 0; i < fftSize; ++i)
                {
                    int outPos = static_cast<int>(outCenter) - fftSize / 2 + i;
                    if (outPos >= 0 && outPos < region.processedAudio.getNumSamples())
                    {
                        region.processedAudio.addSample(ch, outPos,
                            fftOut[i] * window[i] / (fftSize / 2));
                    }
                }
            }
        }
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FlexTimeEditor)
};

} // namespace Editing
} // namespace Echoelmusic
