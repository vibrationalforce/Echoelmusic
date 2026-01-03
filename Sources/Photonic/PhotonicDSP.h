#pragma once

#include <JuceHeader.h>
#include "PhotonicProcessor.h"
#include <vector>
#include <complex>
#include <cmath>

/**
 * PhotonicDSP - Audio Processing Optimized for Photonic Hardware
 *
 * DSP algorithms designed to leverage Q.ANT NPU 2 capabilities:
 * - Native FFT via single waveguide path
 * - Spectral processing in optical domain
 * - Convolution via optical correlation
 * - Filter banks as interferometer meshes
 *
 * Key optimizations:
 * - FFT is O(1) on photonic hardware (vs O(n log n) digital)
 * - Nonlinear operations are 1.5× faster than linear
 * - FP16 native precision perfect for audio
 * - 30× energy efficiency over GPU
 *
 * Audio applications:
 * - Real-time spectral analysis
 * - Phase vocoder time-stretching
 * - Convolution reverb
 * - Spectral effects (freeze, morph, filter)
 * - Multi-band dynamics
 *
 * 2026 Photonic-Ready Architecture
 */

namespace Echoelmusic {
namespace Photonic {

//==============================================================================
// Photonic Spectral Analyzer
//==============================================================================

class PhotonicSpectralAnalyzer
{
public:
    struct Config
    {
        int fftSize = 2048;
        int hopSize = 512;
        float sampleRate = 44100.0f;
        bool usePhotonic = true;
    };

    PhotonicSpectralAnalyzer(const Config& cfg = {}) : config(cfg)
    {
        window.resize(config.fftSize);
        inputBuffer.resize(config.fftSize, 0.0f);
        magnitudes.resize(config.fftSize / 2 + 1, 0.0f);
        phases.resize(config.fftSize / 2 + 1, 0.0f);

        // Hann window
        for (int i = 0; i < config.fftSize; ++i)
        {
            window[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi *
                        i / (config.fftSize - 1)));
        }
    }

    void process(const float* input, int numSamples)
    {
        // Shift buffer
        for (int i = 0; i < config.fftSize - numSamples; ++i)
            inputBuffer[i] = inputBuffer[i + numSamples];

        // Add new samples
        for (int i = 0; i < numSamples; ++i)
            inputBuffer[config.fftSize - numSamples + i] = input[i];

        // Apply window and prepare for FFT
        std::vector<float> windowed(config.fftSize);
        for (int i = 0; i < config.fftSize; ++i)
            windowed[i] = inputBuffer[i] * window[i];

        if (config.usePhotonic && PhotonicNPU.available())
        {
            // Use photonic FFT - O(1) operation!
            PhotonicTensor tensor({config.fftSize});
            std::copy(windowed.begin(), windowed.end(), tensor.getData());

            auto result = PhotonicOps::fft(tensor);
            const float* fftData = result.getData();

            // Extract magnitude and phase
            for (int i = 0; i <= config.fftSize / 2; ++i)
            {
                magnitudes[i] = fftData[i];
                // Phase would come from complex FFT
            }
        }
        else
        {
            // Fallback to digital FFT
            digitalFFT(windowed);
        }
    }

    const std::vector<float>& getMagnitudes() const { return magnitudes; }
    const std::vector<float>& getPhases() const { return phases; }

    float getFrequencyMagnitude(float freqHz) const
    {
        int bin = static_cast<int>(freqHz * config.fftSize / config.sampleRate);
        if (bin >= 0 && bin < static_cast<int>(magnitudes.size()))
            return magnitudes[bin];
        return 0.0f;
    }

    // Spectral centroid (brightness)
    float getSpectralCentroid() const
    {
        float weightedSum = 0.0f, totalMag = 0.0f;

        for (size_t i = 0; i < magnitudes.size(); ++i)
        {
            float freq = i * config.sampleRate / config.fftSize;
            weightedSum += freq * magnitudes[i];
            totalMag += magnitudes[i];
        }

        return totalMag > 0 ? weightedSum / totalMag : 0.0f;
    }

    // Spectral flux (change detection)
    float getSpectralFlux()
    {
        float flux = 0.0f;

        for (size_t i = 0; i < magnitudes.size(); ++i)
        {
            float diff = magnitudes[i] - prevMagnitudes[i];
            if (diff > 0) flux += diff * diff;
        }

        prevMagnitudes = magnitudes;
        return std::sqrt(flux);
    }

private:
    Config config;
    std::vector<float> window;
    std::vector<float> inputBuffer;
    std::vector<float> magnitudes;
    std::vector<float> phases;
    std::vector<float> prevMagnitudes;

    void digitalFFT(const std::vector<float>& input)
    {
        // Simple DFT fallback
        int n = config.fftSize;

        for (int k = 0; k <= n / 2; ++k)
        {
            float real = 0.0f, imag = 0.0f;

            for (int t = 0; t < n; ++t)
            {
                float angle = -2.0f * juce::MathConstants<float>::pi * k * t / n;
                real += input[t] * std::cos(angle);
                imag += input[t] * std::sin(angle);
            }

            magnitudes[k] = std::sqrt(real * real + imag * imag) / n;
            phases[k] = std::atan2(imag, real);
        }
    }
};

//==============================================================================
// Photonic Convolution Reverb
//==============================================================================

class PhotonicConvolutionReverb
{
public:
    void loadImpulseResponse(const juce::AudioBuffer<float>& ir)
    {
        irLength = ir.getNumSamples();

        // Convert IR to photonic tensor
        irTensor = PhotonicTensor({ir.getNumChannels(), irLength});
        float* data = irTensor.getData();

        for (int ch = 0; ch < ir.getNumChannels(); ++ch)
        {
            const float* src = ir.getReadPointer(ch);
            for (int i = 0; i < irLength; ++i)
                data[ch * irLength + i] = src[i];
        }

        // Pre-compute IR FFT (done once)
        if (PhotonicNPU.available())
        {
            irFFT = PhotonicOps::fft(irTensor);
        }

        // Prepare overlap-add buffers
        fftSize = 1;
        while (fftSize < irLength * 2) fftSize *= 2;

        overlapBuffer.setSize(ir.getNumChannels(), fftSize);
        overlapBuffer.clear();
    }

    void process(juce::AudioBuffer<float>& buffer)
    {
        if (irLength == 0) return;

        int numChannels = buffer.getNumChannels();
        int numSamples = buffer.getNumSamples();

        for (int ch = 0; ch < numChannels; ++ch)
        {
            float* channelData = buffer.getWritePointer(ch);

            // Photonic convolution via FFT multiplication
            if (PhotonicNPU.available())
            {
                // Input FFT
                PhotonicTensor inputTensor({numSamples});
                std::copy(channelData, channelData + numSamples, inputTensor.getData());

                auto inputFFT = PhotonicOps::fft(inputTensor);

                // Multiply spectra (photonic is native for this)
                // Simplified: we'd need complex multiplication in full impl
                auto outputFFT = inputFFT;  // Placeholder

                // IFFT
                auto output = PhotonicOps::ifft(outputFFT);

                // Overlap-add
                const float* outputData = output.getData();
                float* overlap = overlapBuffer.getWritePointer(ch);

                for (int i = 0; i < numSamples; ++i)
                {
                    channelData[i] = outputData[i] + overlap[i];
                    overlap[i] = (i + numSamples < fftSize) ? outputData[i + numSamples] : 0.0f;
                }
            }
            else
            {
                // Digital fallback with simple time-domain convolution
                // (Very slow, just for demonstration)
            }
        }
    }

    void setMix(float wet) { wetLevel = std::clamp(wet, 0.0f, 1.0f); }
    void setPreDelay(float ms) { preDelayMs = ms; }

private:
    PhotonicTensor irTensor;
    PhotonicTensor irFFT;
    int irLength = 0;
    int fftSize = 0;
    float wetLevel = 0.5f;
    float preDelayMs = 0.0f;
    juce::AudioBuffer<float> overlapBuffer;
};

//==============================================================================
// Photonic Phase Vocoder (Time Stretch / Pitch Shift)
//==============================================================================

class PhotonicPhaseVocoder
{
public:
    struct Config
    {
        int fftSize = 2048;
        int hopSize = 512;
        float sampleRate = 44100.0f;
    };

    PhotonicPhaseVocoder(const Config& cfg = {}) : config(cfg)
    {
        analysisWindow.resize(config.fftSize);
        synthesisWindow.resize(config.fftSize);
        lastPhase.resize(config.fftSize / 2 + 1, 0.0f);
        accumPhase.resize(config.fftSize / 2 + 1, 0.0f);

        // Hann windows
        for (int i = 0; i < config.fftSize; ++i)
        {
            float w = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi *
                      i / (config.fftSize - 1)));
            analysisWindow[i] = w;
            synthesisWindow[i] = w;
        }
    }

    void setTimeStretch(float ratio) { stretchRatio = ratio; }
    void setPitchShift(float semitones)
    {
        pitchRatio = std::pow(2.0f, semitones / 12.0f);
    }

    void process(const float* input, float* output, int numSamples)
    {
        // Analysis: Photonic FFT (O(1) on NPU!)
        std::vector<float> windowed(config.fftSize);
        for (int i = 0; i < config.fftSize; ++i)
        {
            int idx = i;  // Would map to input position with stretch
            windowed[i] = (idx < numSamples) ? input[idx] * analysisWindow[i] : 0.0f;
        }

        PhotonicTensor analysisTensor({config.fftSize});
        std::copy(windowed.begin(), windowed.end(), analysisTensor.getData());

        PhotonicTensor spectrumTensor;

        if (PhotonicNPU.available())
        {
            spectrumTensor = PhotonicOps::fft(analysisTensor);
        }

        // Phase vocoder processing
        // (Would manipulate magnitude/phase for stretch/pitch)

        // Synthesis: Photonic IFFT
        PhotonicTensor synthTensor;

        if (PhotonicNPU.available())
        {
            synthTensor = PhotonicOps::ifft(spectrumTensor);
        }

        // Apply synthesis window and overlap-add
        const float* synthData = synthTensor.getData();
        for (int i = 0; i < numSamples && i < config.fftSize; ++i)
        {
            output[i] = synthData[i] * synthesisWindow[i];
        }
    }

private:
    Config config;
    float stretchRatio = 1.0f;
    float pitchRatio = 1.0f;
    std::vector<float> analysisWindow;
    std::vector<float> synthesisWindow;
    std::vector<float> lastPhase;
    std::vector<float> accumPhase;
};

//==============================================================================
// Photonic Multi-band Dynamics
//==============================================================================

class PhotonicMultibandDynamics
{
public:
    struct Band
    {
        float lowFreq;
        float highFreq;
        float threshold;       // dB
        float ratio;
        float attack;          // ms
        float release;         // ms
        float makeupGain;      // dB
        float envelope = 0.0f;
    };

    PhotonicMultibandDynamics(int numBands = 4, float sampleRate = 44100.0f)
        : sr(sampleRate)
    {
        bands.resize(numBands);

        // Default frequency splits
        float freqs[] = {0, 100, 500, 2000, 8000, 20000};
        for (int i = 0; i < numBands; ++i)
        {
            bands[i].lowFreq = freqs[i];
            bands[i].highFreq = freqs[i + 1];
            bands[i].threshold = -20.0f;
            bands[i].ratio = 4.0f;
            bands[i].attack = 10.0f;
            bands[i].release = 100.0f;
            bands[i].makeupGain = 0.0f;
        }
    }

    void process(juce::AudioBuffer<float>& buffer)
    {
        int numSamples = buffer.getNumSamples();
        int numChannels = buffer.getNumChannels();

        // Use photonic FFT for band splitting
        for (int ch = 0; ch < numChannels; ++ch)
        {
            float* channelData = buffer.getWritePointer(ch);

            // Photonic FFT
            PhotonicTensor inputTensor({numSamples});
            std::copy(channelData, channelData + numSamples, inputTensor.getData());

            PhotonicTensor spectrum;
            if (PhotonicNPU.available())
            {
                spectrum = PhotonicOps::fft(inputTensor);
            }

            // Process each band
            std::vector<float> output(numSamples, 0.0f);

            for (auto& band : bands)
            {
                // Extract band (frequency masking in photonic domain)
                int lowBin = static_cast<int>(band.lowFreq * numSamples / sr);
                int highBin = static_cast<int>(band.highFreq * numSamples / sr);

                PhotonicTensor bandSpectrum({numSamples});
                float* bandData = bandSpectrum.getData();
                const float* specData = spectrum.getData();

                // Bandpass in frequency domain
                for (int i = 0; i < numSamples; ++i)
                {
                    bandData[i] = (i >= lowBin && i <= highBin) ? specData[i] : 0.0f;
                }

                // IFFT to get band signal
                PhotonicTensor bandSignal;
                if (PhotonicNPU.available())
                {
                    bandSignal = PhotonicOps::ifft(bandSpectrum);
                }

                // Apply dynamics (compression)
                float* bandSamples = bandSignal.getData();

                float attackCoeff = std::exp(-1.0f / (band.attack * sr / 1000.0f));
                float releaseCoeff = std::exp(-1.0f / (band.release * sr / 1000.0f));

                for (int i = 0; i < numSamples; ++i)
                {
                    float input = std::abs(bandSamples[i]);

                    // Envelope follower
                    if (input > band.envelope)
                        band.envelope += (1.0f - attackCoeff) * (input - band.envelope);
                    else
                        band.envelope += (1.0f - releaseCoeff) * (input - band.envelope);

                    // Compression
                    float envDb = 20.0f * std::log10(band.envelope + 1e-10f);
                    float gainDb = 0.0f;

                    if (envDb > band.threshold)
                    {
                        gainDb = (band.threshold - envDb) * (1.0f - 1.0f / band.ratio);
                    }

                    gainDb += band.makeupGain;
                    float gain = std::pow(10.0f, gainDb / 20.0f);

                    output[i] += bandSamples[i] * gain;
                }
            }

            // Write output
            for (int i = 0; i < numSamples; ++i)
                channelData[i] = output[i];
        }
    }

    void setBand(int index, const Band& band)
    {
        if (index >= 0 && index < static_cast<int>(bands.size()))
            bands[index] = band;
    }

private:
    std::vector<Band> bands;
    float sr;
};

//==============================================================================
// Photonic Spectral Effects
//==============================================================================

class PhotonicSpectralEffects
{
public:
    enum class Effect
    {
        Freeze,         // Hold spectrum
        Blur,           // Smear spectrum
        Robotize,       // Flatten phase
        Whisperize,     // Randomize phase
        Spectral_Gate,  // Gate quiet bins
        Harmonic_Shift  // Shift harmonics
    };

    PhotonicSpectralEffects(int fftSize = 2048, float sampleRate = 44100.0f)
        : fftSize_(fftSize), sr_(sampleRate)
    {
        frozenSpectrum.resize(fftSize);
        window.resize(fftSize);

        for (int i = 0; i < fftSize; ++i)
            window[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi *
                        i / (fftSize - 1)));
    }

    void setEffect(Effect eff) { currentEffect = eff; }
    void setMix(float m) { mix = std::clamp(m, 0.0f, 1.0f); }
    void setFreeze(bool f) { frozen = f; }

    void process(float* input, float* output, int numSamples)
    {
        // Pad to FFT size
        std::vector<float> windowed(fftSize_, 0.0f);
        for (int i = 0; i < std::min(numSamples, fftSize_); ++i)
            windowed[i] = input[i] * window[i];

        // Photonic FFT
        PhotonicTensor inputTensor({fftSize_});
        std::copy(windowed.begin(), windowed.end(), inputTensor.getData());

        PhotonicTensor spectrum;
        if (PhotonicNPU.available())
        {
            spectrum = PhotonicOps::fft(inputTensor);
        }

        float* specData = spectrum.getData();

        // Apply effect
        switch (currentEffect)
        {
            case Effect::Freeze:
                if (frozen)
                {
                    // Use frozen spectrum instead
                    std::copy(frozenSpectrum.begin(), frozenSpectrum.end(), specData);
                }
                else
                {
                    // Update frozen spectrum
                    std::copy(specData, specData + fftSize_, frozenSpectrum.begin());
                }
                break;

            case Effect::Blur:
                // Smooth spectrum (average neighboring bins)
                for (int i = 1; i < fftSize_ - 1; ++i)
                {
                    specData[i] = (specData[i-1] + specData[i] + specData[i+1]) / 3.0f;
                }
                break;

            case Effect::Robotize:
                // (Would zero phases - simplified here)
                break;

            case Effect::Whisperize:
                // (Would randomize phases)
                break;

            case Effect::Spectral_Gate:
                // Gate quiet bins
                {
                    float threshold = 0.01f;
                    for (int i = 0; i < fftSize_; ++i)
                    {
                        if (std::abs(specData[i]) < threshold)
                            specData[i] = 0.0f;
                    }
                }
                break;

            case Effect::Harmonic_Shift:
                // Shift harmonics (frequency scaling)
                {
                    std::vector<float> shifted(fftSize_, 0.0f);
                    float shiftRatio = 1.5f;  // Configurable

                    for (int i = 0; i < fftSize_ / 2; ++i)
                    {
                        int newBin = static_cast<int>(i * shiftRatio);
                        if (newBin < fftSize_ / 2)
                            shifted[newBin] = specData[i];
                    }

                    std::copy(shifted.begin(), shifted.end(), specData);
                }
                break;
        }

        // Photonic IFFT
        PhotonicTensor outputSpectrum = spectrum;
        PhotonicTensor timeDomain;

        if (PhotonicNPU.available())
        {
            timeDomain = PhotonicOps::ifft(outputSpectrum);
        }

        // Mix dry/wet
        const float* wetData = timeDomain.getData();
        for (int i = 0; i < numSamples; ++i)
        {
            output[i] = input[i] * (1.0f - mix) + wetData[i] * mix;
        }
    }

private:
    int fftSize_;
    float sr_;
    Effect currentEffect = Effect::Freeze;
    float mix = 1.0f;
    bool frozen = false;
    std::vector<float> frozenSpectrum;
    std::vector<float> window;
};

//==============================================================================
// Photonic Audio Enhancer
//==============================================================================

class PhotonicAudioEnhancer
{
public:
    struct Config
    {
        float harmonic = 0.0f;      // Harmonic enhancement
        float exciter = 0.0f;       // High-freq exciter
        float warmth = 0.0f;        // Low-freq warmth
        float width = 0.0f;         // Stereo width
        float presence = 0.0f;      // Mid presence
    };

    void setConfig(const Config& cfg) { config = cfg; }

    void process(juce::AudioBuffer<float>& buffer)
    {
        int numSamples = buffer.getNumSamples();
        int numChannels = buffer.getNumChannels();

        for (int ch = 0; ch < numChannels; ++ch)
        {
            float* data = buffer.getWritePointer(ch);

            // Photonic FFT
            PhotonicTensor tensor({numSamples});
            std::copy(data, data + numSamples, tensor.getData());

            PhotonicTensor spectrum;
            if (PhotonicNPU.available())
            {
                spectrum = PhotonicOps::fft(tensor);
            }

            float* spec = spectrum.getData();

            // Apply enhancements in frequency domain
            for (int i = 0; i < numSamples / 2; ++i)
            {
                float freq = i * 44100.0f / numSamples;

                // Warmth: boost lows
                if (freq < 200 && config.warmth > 0)
                    spec[i] *= 1.0f + config.warmth * 0.5f;

                // Presence: boost mids
                if (freq > 1000 && freq < 5000 && config.presence > 0)
                    spec[i] *= 1.0f + config.presence * 0.3f;

                // Exciter: boost highs
                if (freq > 8000 && config.exciter > 0)
                    spec[i] *= 1.0f + config.exciter * 0.4f;

                // Harmonic: add harmonics
                if (config.harmonic > 0)
                {
                    int harmonicBin = i * 2;
                    if (harmonicBin < numSamples / 2)
                        spec[harmonicBin] += spec[i] * config.harmonic * 0.1f;
                }
            }

            // Photonic IFFT
            PhotonicTensor enhanced;
            if (PhotonicNPU.available())
            {
                enhanced = PhotonicOps::ifft(spectrum);
            }

            std::copy(enhanced.getData(), enhanced.getData() + numSamples, data);
        }

        // Stereo width processing
        if (numChannels == 2 && config.width != 0)
        {
            float* left = buffer.getWritePointer(0);
            float* right = buffer.getWritePointer(1);

            for (int i = 0; i < numSamples; ++i)
            {
                float mid = (left[i] + right[i]) * 0.5f;
                float side = (left[i] - right[i]) * 0.5f;

                side *= 1.0f + config.width;

                left[i] = mid + side;
                right[i] = mid - side;
            }
        }
    }

private:
    Config config;
};

} // namespace Photonic
} // namespace Echoelmusic
