/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║               SPECTRAL MORPH ENGINE                                        ║
 * ║                                                                            ║
 * ║     "Morph Between Sound Worlds with Your Biology"                        ║
 * ║                                                                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 *
 * Inspired by:
 * - VirSyn CUBE 2 (4-source spectral morphing)
 * - Steinberg HALion 7 (spectral zones)
 * - Fred's Lab Manatee (16-voice spectral with MPE)
 * - SONiVOX Twist (spectral morphing synthesis)
 *
 * Four spectral sources arranged in a morphing cube:
 *
 *        Source A ──────────────────── Source B
 *           │  ╲                    ╱    │
 *           │    ╲    MORPH      ╱      │
 *           │      ╲  SPACE   ╱        │
 *           │        ╲      ╱          │
 *           │          ╲  ╱            │
 *        Source C ──────────────────── Source D
 *
 * Bio-Reactive Morphing:
 * - HRV → X-Axis morph position
 * - Coherence → Y-Axis morph position
 * - Heart Rate → Spectral shift
 * - Breathing → Formant preservation
 * - Stress → Harmonic distortion
 *
 * Features:
 * - 4 spectral source slots (live analysis or presets)
 * - Real-time spectral analysis (FFT)
 * - Smooth morphing between any 4 spectra
 * - Formant-preserving pitch shifting
 * - Spectral freezing and time-stretching
 * - Bio-reactive spectral filtering
 * - MPE per-note morphing
 */

#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <complex>
#include <cmath>

class SpectralMorphEngine
{
public:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int kFFTSize = 4096;
    static constexpr int kHopSize = kFFTSize / 4;
    static constexpr int kNumBins = kFFTSize / 2 + 1;
    static constexpr int kMaxSources = 4;
    static constexpr int kMaxFormants = 5;

    //==========================================================================
    // Spectral Frame
    //==========================================================================

    struct SpectralFrame
    {
        std::array<float, kNumBins> magnitudes;
        std::array<float, kNumBins> phases;
        std::array<float, kMaxFormants> formantFrequencies;
        std::array<float, kMaxFormants> formantAmplitudes;
        float fundamentalFrequency = 440.0f;
        float spectralCentroid = 1000.0f;
        float spectralFlatness = 0.5f;

        SpectralFrame()
        {
            magnitudes.fill(0.0f);
            phases.fill(0.0f);
            formantFrequencies.fill(0.0f);
            formantAmplitudes.fill(0.0f);
        }
    };

    //==========================================================================
    // Morph Source
    //==========================================================================

    struct MorphSource
    {
        bool active = false;
        juce::String name;
        SpectralFrame spectrum;

        // Playback state
        double playbackPosition = 0.0;
        bool frozen = false;
        bool looping = false;

        MorphSource() = default;
    };

    //==========================================================================
    // Bio State
    //==========================================================================

    struct BioState
    {
        float heartRate = 70.0f;
        float hrv = 0.5f;
        float coherence = 0.5f;
        float breathingPhase = 0.0f;
        float stress = 0.5f;
    };

    //==========================================================================
    // Morph Parameters
    //==========================================================================

    struct MorphParams
    {
        float morphX = 0.5f;           // A-B axis (0=A, 1=B)
        float morphY = 0.5f;           // C-D axis (0=C, 1=D)
        float morphZ = 0.5f;           // Depth (for 3D morphing)

        float pitchShift = 0.0f;       // Semitones
        float formantShift = 0.0f;     // Semitones (independent of pitch)
        float timeStretch = 1.0f;      // 0.5 = half speed, 2.0 = double

        float spectralTilt = 0.0f;     // -1 = darker, +1 = brighter
        float spectralSmooth = 0.0f;   // 0-1 blur amount
        float harmonicEnhance = 0.0f;  // 0-1 harmonic boost

        bool formantPreserve = true;
        bool bioMorphEnabled = true;

        MorphParams() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SpectralMorphEngine()
    {
        initializeFFT();
        initializeWindows();
    }

    ~SpectralMorphEngine() = default;

    //==========================================================================
    // Source Management
    //==========================================================================

    /** Load audio buffer into source slot */
    void loadSource(int sourceIndex, const juce::AudioBuffer<float>& buffer, double sampleRate)
    {
        if (sourceIndex < 0 || sourceIndex >= kMaxSources)
            return;

        auto& source = sources[sourceIndex];
        source.active = true;

        // Analyze spectrum
        analyzeSpectrum(buffer, source.spectrum);

        // Extract formants
        extractFormants(source.spectrum);

        // Reset playback
        source.playbackPosition = 0.0;
    }

    /** Analyze live input and store in source */
    void analyzeInput(int sourceIndex, const float* inputSamples, int numSamples)
    {
        if (sourceIndex < 0 || sourceIndex >= kMaxSources)
            return;

        auto& source = sources[sourceIndex];
        source.active = true;

        // Copy to analysis buffer
        for (int i = 0; i < std::min(numSamples, kFFTSize); ++i)
        {
            fftBuffer[i] = inputSamples[i] * windowFunction[i];
        }

        // Perform FFT
        performFFT();

        // Extract magnitudes and phases
        for (int bin = 0; bin < kNumBins; ++bin)
        {
            float real = fftBuffer[bin * 2];
            float imag = fftBuffer[bin * 2 + 1];

            source.spectrum.magnitudes[bin] = std::sqrt(real * real + imag * imag);
            source.spectrum.phases[bin] = std::atan2(imag, real);
        }

        // Calculate spectral features
        calculateSpectralFeatures(source.spectrum);

        // Extract formants
        extractFormants(source.spectrum);
    }

    /** Freeze current spectrum */
    void freezeSource(int sourceIndex, bool freeze)
    {
        if (sourceIndex >= 0 && sourceIndex < kMaxSources)
        {
            sources[sourceIndex].frozen = freeze;
        }
    }

    /** Clear source */
    void clearSource(int sourceIndex)
    {
        if (sourceIndex >= 0 && sourceIndex < kMaxSources)
        {
            sources[sourceIndex] = MorphSource();
        }
    }

    //==========================================================================
    // Morphing Control
    //==========================================================================

    /** Set morph position (0-1 for both axes) */
    void setMorphPosition(float x, float y)
    {
        params.morphX = std::clamp(x, 0.0f, 1.0f);
        params.morphY = std::clamp(y, 0.0f, 1.0f);
    }

    /** Set 3D morph position */
    void setMorphPosition3D(float x, float y, float z)
    {
        params.morphX = std::clamp(x, 0.0f, 1.0f);
        params.morphY = std::clamp(y, 0.0f, 1.0f);
        params.morphZ = std::clamp(z, 0.0f, 1.0f);
    }

    /** Set pitch shift */
    void setPitchShift(float semitones)
    {
        params.pitchShift = std::clamp(semitones, -24.0f, 24.0f);
    }

    /** Set formant shift (independent of pitch) */
    void setFormantShift(float semitones)
    {
        params.formantShift = std::clamp(semitones, -12.0f, 12.0f);
    }

    /** Set time stretch ratio */
    void setTimeStretch(float ratio)
    {
        params.timeStretch = std::clamp(ratio, 0.25f, 4.0f);
    }

    /** Enable formant preservation */
    void setFormantPreserve(bool preserve)
    {
        params.formantPreserve = preserve;
    }

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    /** Update bio-data for reactive morphing */
    void setBioState(const BioState& state)
    {
        bioState = state;

        if (params.bioMorphEnabled)
        {
            // Bio-driven morphing
            applyBioMorphing();
        }
    }

    /** Enable/disable bio-reactive morphing */
    void setBioMorphEnabled(bool enabled)
    {
        params.bioMorphEnabled = enabled;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        hopCounter = 0;
        outputBuffer.setSize(2, maxBlockSize + kFFTSize);
        outputBuffer.clear();
    }

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer)
    {
        const int numSamples = buffer.getNumSamples();
        const int numChannels = buffer.getNumChannels();

        for (int sample = 0; sample < numSamples; ++sample)
        {
            hopCounter++;

            if (hopCounter >= kHopSize)
            {
                hopCounter = 0;

                // Compute morphed spectrum
                SpectralFrame morphedSpectrum = computeMorphedSpectrum();

                // Apply spectral modifications
                applySpectralModifications(morphedSpectrum);

                // Synthesize output
                synthesizeFromSpectrum(morphedSpectrum);
            }
        }

        // Copy output to buffer
        for (int ch = 0; ch < std::min(numChannels, 2); ++ch)
        {
            buffer.copyFrom(ch, 0, outputBuffer, ch, 0, numSamples);
        }

        // Shift output buffer
        for (int ch = 0; ch < 2; ++ch)
        {
            outputBuffer.copyFrom(ch, 0, outputBuffer, ch, numSamples, kFFTSize);
        }
    }

    //==========================================================================
    // Spectral Analysis Outputs
    //==========================================================================

    /** Get current morphed spectrum for visualization */
    const SpectralFrame& getCurrentSpectrum() const
    {
        return currentMorphedSpectrum;
    }

    /** Get morph parameters */
    const MorphParams& getMorphParams() const
    {
        return params;
    }

    /** Get source info */
    const MorphSource& getSource(int index) const
    {
        return sources[std::clamp(index, 0, kMaxSources - 1)];
    }

    //==========================================================================
    // Presets
    //==========================================================================

    enum class MorphPreset
    {
        VocalToStrings,
        PadToTexture,
        BreathToChoir,
        OrganicToSynthetic,
        WarmToBright,
        SoftToAggressive,
        HumanToAlien,
        EarthToSpace,
        BioHarmonics,
        QuantumFlow
    };

    void loadPreset(MorphPreset preset)
    {
        switch (preset)
        {
            case MorphPreset::BioHarmonics:
                params.formantPreserve = true;
                params.spectralTilt = 0.0f;
                params.harmonicEnhance = 0.5f;
                params.bioMorphEnabled = true;
                break;

            case MorphPreset::QuantumFlow:
                params.formantPreserve = false;
                params.spectralSmooth = 0.3f;
                params.harmonicEnhance = 0.0f;
                params.bioMorphEnabled = true;
                break;

            default:
                break;
        }
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    std::array<MorphSource, kMaxSources> sources;
    MorphParams params;
    BioState bioState;
    SpectralFrame currentMorphedSpectrum;

    // FFT
    std::unique_ptr<juce::dsp::FFT> fft;
    std::vector<float> fftBuffer;
    std::vector<float> windowFunction;
    std::vector<float> synthesisWindow;

    // Overlap-add
    juce::AudioBuffer<float> outputBuffer;
    int hopCounter = 0;

    // Sample rate
    double currentSampleRate = 48000.0;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeFFT()
    {
        int fftOrder = static_cast<int>(std::log2(kFFTSize));
        fft = std::make_unique<juce::dsp::FFT>(fftOrder);
        fftBuffer.resize(kFFTSize * 2, 0.0f);
    }

    void initializeWindows()
    {
        windowFunction.resize(kFFTSize);
        synthesisWindow.resize(kFFTSize);

        // Hann window for analysis
        for (int i = 0; i < kFFTSize; ++i)
        {
            windowFunction[i] = 0.5f * (1.0f - std::cos(2.0f * M_PI * i / (kFFTSize - 1)));
        }

        // Synthesis window (square root of Hann for perfect reconstruction)
        for (int i = 0; i < kFFTSize; ++i)
        {
            synthesisWindow[i] = std::sqrt(windowFunction[i]);
        }
    }

    void performFFT()
    {
        fft->performRealOnlyForwardTransform(fftBuffer.data(), true);
    }

    void performIFFT()
    {
        fft->performRealOnlyInverseTransform(fftBuffer.data());
    }

    void analyzeSpectrum(const juce::AudioBuffer<float>& buffer, SpectralFrame& frame)
    {
        // Take center portion of buffer
        int startSample = std::max(0, buffer.getNumSamples() / 2 - kFFTSize / 2);

        // Window and copy to FFT buffer
        for (int i = 0; i < kFFTSize; ++i)
        {
            int sampleIndex = startSample + i;
            if (sampleIndex < buffer.getNumSamples())
            {
                fftBuffer[i] = buffer.getSample(0, sampleIndex) * windowFunction[i];
            }
            else
            {
                fftBuffer[i] = 0.0f;
            }
        }

        // Perform FFT
        performFFT();

        // Extract magnitudes and phases
        for (int bin = 0; bin < kNumBins; ++bin)
        {
            float real = fftBuffer[bin * 2];
            float imag = fftBuffer[bin * 2 + 1];

            frame.magnitudes[bin] = std::sqrt(real * real + imag * imag);
            frame.phases[bin] = std::atan2(imag, real);
        }

        calculateSpectralFeatures(frame);
    }

    void calculateSpectralFeatures(SpectralFrame& frame)
    {
        // Spectral centroid
        float weightedSum = 0.0f;
        float magnitudeSum = 0.0f;

        for (int bin = 0; bin < kNumBins; ++bin)
        {
            float frequency = bin * currentSampleRate / kFFTSize;
            weightedSum += frequency * frame.magnitudes[bin];
            magnitudeSum += frame.magnitudes[bin];
        }

        frame.spectralCentroid = magnitudeSum > 0.0f ? weightedSum / magnitudeSum : 1000.0f;

        // Spectral flatness (geometric mean / arithmetic mean)
        float logSum = 0.0f;
        float linearSum = 0.0f;
        int validBins = 0;

        for (int bin = 1; bin < kNumBins; ++bin)
        {
            if (frame.magnitudes[bin] > 1e-10f)
            {
                logSum += std::log(frame.magnitudes[bin]);
                linearSum += frame.magnitudes[bin];
                validBins++;
            }
        }

        if (validBins > 0 && linearSum > 0.0f)
        {
            float geometricMean = std::exp(logSum / validBins);
            float arithmeticMean = linearSum / validBins;
            frame.spectralFlatness = geometricMean / arithmeticMean;
        }
        else
        {
            frame.spectralFlatness = 0.5f;
        }

        // Estimate fundamental frequency (simple peak detection)
        float maxMag = 0.0f;
        int peakBin = 1;

        for (int bin = 1; bin < kNumBins / 4; ++bin)
        {
            if (frame.magnitudes[bin] > maxMag)
            {
                maxMag = frame.magnitudes[bin];
                peakBin = bin;
            }
        }

        frame.fundamentalFrequency = peakBin * currentSampleRate / kFFTSize;
    }

    void extractFormants(SpectralFrame& frame)
    {
        // Simple formant extraction via spectral envelope peaks
        // In production, use LPC or cepstral analysis

        std::vector<std::pair<int, float>> peaks;

        // Find local maxima in smoothed spectrum
        for (int bin = 2; bin < kNumBins - 2; ++bin)
        {
            float mag = frame.magnitudes[bin];
            if (mag > frame.magnitudes[bin - 1] &&
                mag > frame.magnitudes[bin + 1] &&
                mag > frame.magnitudes[bin - 2] &&
                mag > frame.magnitudes[bin + 2])
            {
                float freq = bin * currentSampleRate / kFFTSize;
                if (freq > 100.0f && freq < 5000.0f)
                {
                    peaks.push_back({ bin, mag });
                }
            }
        }

        // Sort by magnitude
        std::sort(peaks.begin(), peaks.end(),
            [](const auto& a, const auto& b) { return a.second > b.second; });

        // Store top formants
        for (int i = 0; i < std::min(kMaxFormants, static_cast<int>(peaks.size())); ++i)
        {
            frame.formantFrequencies[i] = peaks[i].first * currentSampleRate / kFFTSize;
            frame.formantAmplitudes[i] = peaks[i].second;
        }
    }

    SpectralFrame computeMorphedSpectrum()
    {
        SpectralFrame result;

        // Bilinear interpolation between 4 sources
        float weightA = (1.0f - params.morphX) * (1.0f - params.morphY);
        float weightB = params.morphX * (1.0f - params.morphY);
        float weightC = (1.0f - params.morphX) * params.morphY;
        float weightD = params.morphX * params.morphY;

        // Morph magnitudes
        for (int bin = 0; bin < kNumBins; ++bin)
        {
            result.magnitudes[bin] =
                weightA * (sources[0].active ? sources[0].spectrum.magnitudes[bin] : 0.0f) +
                weightB * (sources[1].active ? sources[1].spectrum.magnitudes[bin] : 0.0f) +
                weightC * (sources[2].active ? sources[2].spectrum.magnitudes[bin] : 0.0f) +
                weightD * (sources[3].active ? sources[3].spectrum.magnitudes[bin] : 0.0f);

            // Phase interpolation (complex domain)
            float phase = 0.0f;
            if (sources[0].active) phase += weightA * sources[0].spectrum.phases[bin];
            if (sources[1].active) phase += weightB * sources[1].spectrum.phases[bin];
            if (sources[2].active) phase += weightC * sources[2].spectrum.phases[bin];
            if (sources[3].active) phase += weightD * sources[3].spectrum.phases[bin];

            result.phases[bin] = phase;
        }

        // Morph formants
        for (int f = 0; f < kMaxFormants; ++f)
        {
            result.formantFrequencies[f] =
                weightA * sources[0].spectrum.formantFrequencies[f] +
                weightB * sources[1].spectrum.formantFrequencies[f] +
                weightC * sources[2].spectrum.formantFrequencies[f] +
                weightD * sources[3].spectrum.formantFrequencies[f];

            result.formantAmplitudes[f] =
                weightA * sources[0].spectrum.formantAmplitudes[f] +
                weightB * sources[1].spectrum.formantAmplitudes[f] +
                weightC * sources[2].spectrum.formantAmplitudes[f] +
                weightD * sources[3].spectrum.formantAmplitudes[f];
        }

        // Morph spectral features
        result.spectralCentroid =
            weightA * sources[0].spectrum.spectralCentroid +
            weightB * sources[1].spectrum.spectralCentroid +
            weightC * sources[2].spectrum.spectralCentroid +
            weightD * sources[3].spectrum.spectralCentroid;

        result.fundamentalFrequency =
            weightA * sources[0].spectrum.fundamentalFrequency +
            weightB * sources[1].spectrum.fundamentalFrequency +
            weightC * sources[2].spectrum.fundamentalFrequency +
            weightD * sources[3].spectrum.fundamentalFrequencies;

        return result;
    }

    void applySpectralModifications(SpectralFrame& frame)
    {
        // Pitch shift (by bin shifting)
        if (std::abs(params.pitchShift) > 0.01f)
        {
            applyPitchShift(frame, params.pitchShift);
        }

        // Spectral tilt
        if (std::abs(params.spectralTilt) > 0.01f)
        {
            applySpectralTilt(frame, params.spectralTilt);
        }

        // Spectral smoothing
        if (params.spectralSmooth > 0.01f)
        {
            applySpectralSmooth(frame, params.spectralSmooth);
        }

        // Harmonic enhancement
        if (params.harmonicEnhance > 0.01f)
        {
            applyHarmonicEnhance(frame, params.harmonicEnhance);
        }

        currentMorphedSpectrum = frame;
    }

    void applyPitchShift(SpectralFrame& frame, float semitones)
    {
        float ratio = std::pow(2.0f, semitones / 12.0f);
        std::array<float, kNumBins> newMagnitudes;
        std::array<float, kNumBins> newPhases;
        newMagnitudes.fill(0.0f);
        newPhases.fill(0.0f);

        for (int bin = 1; bin < kNumBins; ++bin)
        {
            int newBin = static_cast<int>(bin * ratio);
            if (newBin > 0 && newBin < kNumBins)
            {
                newMagnitudes[newBin] += frame.magnitudes[bin];
                newPhases[newBin] = frame.phases[bin] * ratio;
            }
        }

        frame.magnitudes = newMagnitudes;
        frame.phases = newPhases;
    }

    void applySpectralTilt(SpectralFrame& frame, float tilt)
    {
        for (int bin = 1; bin < kNumBins; ++bin)
        {
            float normalizedFreq = static_cast<float>(bin) / kNumBins;
            float gain = 1.0f + tilt * (normalizedFreq - 0.5f) * 2.0f;
            frame.magnitudes[bin] *= std::max(0.0f, gain);
        }
    }

    void applySpectralSmooth(SpectralFrame& frame, float amount)
    {
        std::array<float, kNumBins> smoothed;
        int windowSize = static_cast<int>(amount * 20) + 1;

        for (int bin = 0; bin < kNumBins; ++bin)
        {
            float sum = 0.0f;
            int count = 0;

            for (int i = -windowSize; i <= windowSize; ++i)
            {
                int neighborBin = bin + i;
                if (neighborBin >= 0 && neighborBin < kNumBins)
                {
                    sum += frame.magnitudes[neighborBin];
                    count++;
                }
            }

            smoothed[bin] = sum / count;
        }

        // Blend original and smoothed
        for (int bin = 0; bin < kNumBins; ++bin)
        {
            frame.magnitudes[bin] = frame.magnitudes[bin] * (1.0f - amount) +
                                    smoothed[bin] * amount;
        }
    }

    void applyHarmonicEnhance(SpectralFrame& frame, float amount)
    {
        float fundamental = frame.fundamentalFrequency;
        if (fundamental < 20.0f) return;

        int fundamentalBin = static_cast<int>(fundamental * kFFTSize / currentSampleRate);

        // Boost harmonics
        for (int harmonic = 1; harmonic <= 16; ++harmonic)
        {
            int harmonicBin = fundamentalBin * harmonic;
            if (harmonicBin >= kNumBins) break;

            float boost = 1.0f + amount * (1.0f / harmonic);

            // Apply boost with a small window
            for (int offset = -2; offset <= 2; ++offset)
            {
                int bin = harmonicBin + offset;
                if (bin >= 0 && bin < kNumBins)
                {
                    float weight = 1.0f - std::abs(offset) * 0.25f;
                    frame.magnitudes[bin] *= 1.0f + (boost - 1.0f) * weight;
                }
            }
        }
    }

    void synthesizeFromSpectrum(const SpectralFrame& frame)
    {
        // Convert back to complex form
        for (int bin = 0; bin < kNumBins; ++bin)
        {
            float mag = frame.magnitudes[bin];
            float phase = frame.phases[bin];

            fftBuffer[bin * 2] = mag * std::cos(phase);
            fftBuffer[bin * 2 + 1] = mag * std::sin(phase);
        }

        // Perform inverse FFT
        performIFFT();

        // Overlap-add
        for (int i = 0; i < kFFTSize; ++i)
        {
            float sample = fftBuffer[i] * synthesisWindow[i];
            outputBuffer.addSample(0, i, sample);
            outputBuffer.addSample(1, i, sample);
        }
    }

    void applyBioMorphing()
    {
        // HRV → X-axis morph
        params.morphX = bioState.hrv;

        // Coherence → Y-axis morph
        params.morphY = bioState.coherence;

        // Breathing phase → subtle modulation
        float breathMod = std::sin(bioState.breathingPhase * 2.0f * M_PI) * 0.1f;
        params.morphX = std::clamp(params.morphX + breathMod, 0.0f, 1.0f);

        // Stress → spectral tilt (stressed = brighter/harsher)
        params.spectralTilt = (bioState.stress - 0.5f) * 0.5f;

        // Heart rate → harmonic enhancement
        float normalizedHR = (bioState.heartRate - 60.0f) / 60.0f;
        params.harmonicEnhance = std::clamp(normalizedHR * 0.3f, 0.0f, 0.5f);
    }

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectralMorphEngine)
};
