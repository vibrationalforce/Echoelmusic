#include "SpectralSculptor.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

SpectralSculptor::SpectralSculptor()
{
    noiseProfile.resize(fftSize / 2 + 1, 0.0f);
    gateEnvelopes.resize(fftSize / 2 + 1, 1.0f);
    visualSpectrum.resize(1024, 0.0f);
    visualNoiseProfile.resize(1024, 0.0f);
}

//==============================================================================
// Processing Mode
//==============================================================================

void SpectralSculptor::setProcessingMode(ProcessingMode mode)
{
    if (currentMode != mode)
    {
        currentMode = mode;
        reset();
    }
}

//==============================================================================
// Parameters - Denoise
//==============================================================================

void SpectralSculptor::setNoiseThreshold(float threshold)
{
    noiseThreshold = juce::jlimit(0.0f, 1.0f, threshold);
}

void SpectralSculptor::setNoiseReduction(float amount)
{
    noiseReduction = juce::jlimit(0.0f, 1.0f, amount);
}

void SpectralSculptor::learnNoiseProfile(const juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = juce::jmin(buffer.getNumChannels(), 2);

    // Accumulate noise spectrum over multiple frames
    if (noiseLearnFrames == 0)
    {
        std::fill(noiseProfile.begin(), noiseProfile.end(), 0.0f);
    }

    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto& state = channelStates[ch];
        const float* channelData = buffer.getReadPointer(ch);

        // Copy to FFT buffer
        std::copy(channelData, channelData + juce::jmin(numSamples, fftSize),
                  state.fftData.begin());

        // Apply window
        window.multiplyWithWindowingTable(state.fftData.data(), fftSize);

        // Forward FFT
        forwardFFT.perform(state.fftData.data(), reinterpret_cast<float*>(state.freqData.data()), false);

        // Accumulate magnitude
        for (size_t i = 0; i < noiseProfile.size(); ++i)
        {
            float magnitude = std::abs(state.freqData[i]);
            noiseProfile[i] += magnitude;
        }
    }

    noiseLearnFrames++;

    // Average after collecting enough frames
    if (noiseLearnFrames >= numNoiseLearnFrames)
    {
        for (auto& mag : noiseProfile)
        {
            mag /= static_cast<float>(noiseLearnFrames * numChannels);
        }

        noiseProfileLearned = true;
        noiseLearnFrames = 0;

        // Update visualization (use try_lock to avoid blocking audio thread)
        std::unique_lock<std::mutex> lock(spectrumMutex, std::try_to_lock);
        if (lock.owns_lock())
        {
            const float scale = 1024.0f / static_cast<float>(noiseProfile.size());
            for (size_t i = 0; i < visualNoiseProfile.size(); ++i)
            {
                int bin = static_cast<int>(i / scale);
                visualNoiseProfile[i] = noiseProfile[bin];
            }
        }
        // If we couldn't get the lock, skip visualization update (non-critical)
    }
}

void SpectralSculptor::clearNoiseProfile()
{
    std::fill(noiseProfile.begin(), noiseProfile.end(), 0.0f);
    noiseProfileLearned = false;
    noiseLearnFrames = 0;
}

//==============================================================================
// Parameters - Spectral Gate
//==============================================================================

void SpectralSculptor::setGateThreshold(float thresholdDb)
{
    gateThresholdDb = juce::jlimit(-60.0f, 0.0f, thresholdDb);
}

void SpectralSculptor::setGateAttack(float attackMs)
{
    gateAttackMs = juce::jlimit(0.1f, 100.0f, attackMs);
}

void SpectralSculptor::setGateRelease(float releaseMs)
{
    gateReleaseMs = juce::jlimit(10.0f, 1000.0f, releaseMs);
}

//==============================================================================
// Parameters - Harmonic Processing
//==============================================================================

void SpectralSculptor::setHarmonicAmount(float amount)
{
    harmonicAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void SpectralSculptor::setFundamentalFrequency(float freq)
{
    fundamentalFreq = juce::jlimit(20.0f, 2000.0f, freq);
}

void SpectralSculptor::setNumHarmonics(int num)
{
    numHarmonics = juce::jlimit(1, 16, num);
}

//==============================================================================
// Parameters - De-Click
//==============================================================================

void SpectralSculptor::setDeClickSensitivity(float sensitivity)
{
    deClickSensitivity = juce::jlimit(0.0f, 1.0f, sensitivity);
}

//==============================================================================
// Parameters - Spectral Freeze
//==============================================================================

void SpectralSculptor::setFreezeEnabled(bool enabled)
{
    freezeEnabled = enabled;
}

void SpectralSculptor::captureSpectrum()
{
    // Capture current spectrum from first channel
    auto& state = channelStates[0];
    if (!state.freqData.empty())
    {
        state.frozenSpectrum = state.freqData;
    }
}

//==============================================================================
// Parameters - Spectral Morph
//==============================================================================

void SpectralSculptor::setMorphAmount(float amount)
{
    morphAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void SpectralSculptor::setBioData(float hrv, float coherence)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
}

//==============================================================================
// Common Parameters
//==============================================================================

void SpectralSculptor::setMix(float mixAmount)
{
    mix = juce::jlimit(0.0f, 1.0f, mixAmount);
}

void SpectralSculptor::setFFTSize(int size)
{
    // Validate power of 2 between 512 and 8192
    if (size >= 512 && size <= 8192 && (size & (size - 1)) == 0)
    {
        int newOrder = static_cast<int>(std::log2(size));
        if (newOrder != fftOrder)
        {
            fftOrder = newOrder;
            fftSize = size;
            hopSize = fftSize / 4;
            updateFFTSize();
        }
    }
}

void SpectralSculptor::setZeroLatencyMode(bool enabled)
{
    zeroLatency = enabled;
}

//==============================================================================
// Processing
//==============================================================================

void SpectralSculptor::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    // ✅ Pre-allocate dry buffer to avoid allocation in audio thread
    dryBuffer.setSize(2, maxBlockSize);
    dryBuffer.clear();

    updateFFTSize();
    reset();
}

void SpectralSculptor::reset()
{
    for (auto& state : channelStates)
    {
        std::fill(state.inputFIFO.begin(), state.inputFIFO.end(), 0.0f);
        std::fill(state.outputFIFO.begin(), state.outputFIFO.end(), 0.0f);
        std::fill(state.fftData.begin(), state.fftData.end(), 0.0f);
        std::fill(state.freqData.begin(), state.freqData.end(), std::complex<float>(0.0f, 0.0f));
        state.inputFIFOIndex = 0;
        state.outputFIFOIndex = 0;
    }

    std::fill(gateEnvelopes.begin(), gateEnvelopes.end(), 1.0f);
    std::fill(previousSamples.begin(), previousSamples.end(), 0.0f);
}

void SpectralSculptor::process(juce::AudioBuffer<float>& buffer)
{
    // De-click mode processes in time domain
    if (currentMode == ProcessingMode::DeClick)
    {
        processDeClick(buffer);
        return;
    }

    const int numSamples = buffer.getNumSamples();
    const int numChannels = juce::jmin(buffer.getNumChannels(), 2);

    // ✅ Use pre-allocated dry buffer (NO ALLOCATION in audio thread)
    jassert(dryBuffer.getNumChannels() >= numChannels);
    jassert(dryBuffer.getNumSamples() >= numSamples);

    // Store dry signal for mixing
    for (int ch = 0; ch < numChannels; ++ch)
    {
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);
    }

    // Process each channel
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto& state = channelStates[ch];
        float* channelData = buffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
        {
            // Add input sample to FIFO
            state.inputFIFO[state.inputFIFOIndex] = channelData[i];
            state.inputFIFOIndex++;

            // Process frame when FIFO is full
            if (state.inputFIFOIndex >= hopSize)
            {
                processFrame(state);
                state.inputFIFOIndex = 0;
            }

            // Read from output FIFO
            channelData[i] = state.outputFIFO[state.outputFIFOIndex];
            state.outputFIFO[state.outputFIFOIndex] = 0.0f;
            state.outputFIFOIndex = (state.outputFIFOIndex + 1) % fftSize;
        }
    }

    // Mix dry/wet
    if (mix < 0.999f)
    {
        for (int ch = 0; ch < numChannels; ++ch)
        {
            float* wetData = buffer.getWritePointer(ch);
            const float* dryData = dryBuffer.getReadPointer(ch);

            for (int i = 0; i < numSamples; ++i)
            {
                wetData[i] = dryData[i] * (1.0f - mix) + wetData[i] * mix;
            }
        }
    }
}

//==============================================================================
// Visualization
//==============================================================================

std::vector<float> SpectralSculptor::getSpectrumData() const
{
    std::lock_guard<std::mutex> lock(spectrumMutex);
    return visualSpectrum;
}

std::vector<float> SpectralSculptor::getNoiseProfileData() const
{
    std::lock_guard<std::mutex> lock(spectrumMutex);
    return visualNoiseProfile;
}

//==============================================================================
// Internal Methods - Frame Processing
//==============================================================================

void SpectralSculptor::processFrame(ChannelState& state)
{
    // Copy input FIFO to FFT buffer (with overlap)
    const int copySize = fftSize - hopSize;
    std::copy(state.fftData.begin() + hopSize, state.fftData.end(), state.fftData.begin());
    std::copy(state.inputFIFO.begin(), state.inputFIFO.begin() + hopSize,
              state.fftData.begin() + copySize);

    // Apply window
    std::vector<float> windowedData = state.fftData;
    window.multiplyWithWindowingTable(windowedData.data(), fftSize);

    // Forward FFT
    forwardFFT.perform(windowedData.data(), reinterpret_cast<float*>(state.freqData.data()), false);

    // Process frequency domain based on mode
    switch (currentMode)
    {
        case ProcessingMode::Denoise:
            processDenoise(state.freqData);
            break;

        case ProcessingMode::SpectralGate:
            processSpectralGate(state.freqData);
            break;

        case ProcessingMode::HarmonicEnhance:
            processHarmonicEnhance(state.freqData);
            break;

        case ProcessingMode::HarmonicSuppress:
            processHarmonicSuppress(state.freqData);
            break;

        case ProcessingMode::SpectralFreeze:
            processSpectralFreeze(state.freqData);
            break;

        case ProcessingMode::SpectralMorph:
            processSpectralMorph(state.freqData);
            break;

        case ProcessingMode::Restore:
            processRestore(state.freqData);
            break;

        default:
            break;
    }

    // Update visualization
    updateVisualization(state.freqData);

    // Inverse FFT
    std::vector<float> timeData(fftSize * 2);
    inverseFFT.perform(reinterpret_cast<float*>(state.freqData.data()), timeData.data(), true);

    // Apply window again for overlap-add
    window.multiplyWithWindowingTable(timeData.data(), fftSize);

    // Overlap-add to output FIFO
    for (int i = 0; i < fftSize; ++i)
    {
        state.outputFIFO[i] += timeData[i] / static_cast<float>(fftSize / hopSize);
    }
}

//==============================================================================
// Processing Modes
//==============================================================================

void SpectralSculptor::processDenoise(std::vector<std::complex<float>>& freqData)
{
    if (!noiseProfileLearned)
        return;

    const int numBins = static_cast<int>(noiseProfile.size());

    for (int i = 0; i < numBins; ++i)
    {
        float magnitude = std::abs(freqData[i]);
        float phase = std::arg(freqData[i]);

        // Spectral subtraction
        float noiseLevel = noiseProfile[i] * noiseThreshold;
        float cleanMagnitude = magnitude - noiseLevel;

        // Apply reduction
        if (cleanMagnitude < 0.0f)
        {
            cleanMagnitude = magnitude * (1.0f - noiseReduction);
        }

        // Reconstruct complex value
        freqData[i] = std::polar(cleanMagnitude, phase);
    }
}

void SpectralSculptor::processSpectralGate(std::vector<std::complex<float>>& freqData)
{
    const float threshold = Echoel::DSP::FastMath::dbToGain(gateThresholdDb);
    const float attackCoeff = Echoel::DSP::FastMath::fastExp(-1000.0f / (gateAttackMs * static_cast<float>(currentSampleRate)));
    const float releaseCoeff = Echoel::DSP::FastMath::fastExp(-1000.0f / (gateReleaseMs * static_cast<float>(currentSampleRate)));

    const int numBins = juce::jmin(static_cast<int>(freqData.size()), static_cast<int>(gateEnvelopes.size()));

    for (int i = 0; i < numBins; ++i)
    {
        float magnitude = std::abs(freqData[i]);
        float phase = std::arg(freqData[i]);

        // Gate envelope per bin
        float targetGain = (magnitude > threshold) ? 1.0f : 0.0f;

        if (targetGain > gateEnvelopes[i])
            gateEnvelopes[i] = attackCoeff * gateEnvelopes[i] + (1.0f - attackCoeff) * targetGain;
        else
            gateEnvelopes[i] = releaseCoeff * gateEnvelopes[i] + (1.0f - releaseCoeff) * targetGain;

        // Apply gate
        float gatedMagnitude = magnitude * gateEnvelopes[i];
        freqData[i] = std::polar(gatedMagnitude, phase);
    }
}

void SpectralSculptor::processHarmonicEnhance(std::vector<std::complex<float>>& freqData)
{
    const int fundamentalBin = frequencyToBin(fundamentalFreq);

    for (int h = 1; h <= numHarmonics; ++h)
    {
        int harmonicBin = fundamentalBin * h;
        if (harmonicBin >= static_cast<int>(freqData.size()))
            break;

        // Enhance harmonic
        float magnitude = std::abs(freqData[harmonicBin]);
        float phase = std::arg(freqData[harmonicBin]);

        float enhancedMagnitude = magnitude * (1.0f + harmonicAmount);
        freqData[harmonicBin] = std::polar(enhancedMagnitude, phase);
    }
}

void SpectralSculptor::processHarmonicSuppress(std::vector<std::complex<float>>& freqData)
{
    const int fundamentalBin = frequencyToBin(fundamentalFreq);

    for (int h = 1; h <= numHarmonics; ++h)
    {
        int harmonicBin = fundamentalBin * h;
        if (harmonicBin >= static_cast<int>(freqData.size()))
            break;

        // Suppress harmonic
        float magnitude = std::abs(freqData[harmonicBin]);
        float phase = std::arg(freqData[harmonicBin]);

        float suppressedMagnitude = magnitude * (1.0f - harmonicAmount);
        freqData[harmonicBin] = std::polar(suppressedMagnitude, phase);
    }
}

void SpectralSculptor::processDeClick(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = juce::jmin(buffer.getNumChannels(), 2);
    const int numSamples = buffer.getNumSamples();
    const float threshold = deClickSensitivity * 0.5f;

    for (int ch = 0; ch < numChannels; ++ch)
    {
        float* channelData = buffer.getWritePointer(ch);
        float& prevSample = previousSamples[ch];

        for (int i = 0; i < numSamples; ++i)
        {
            float currentSample = channelData[i];
            float diff = std::abs(currentSample - prevSample);

            // Detect click (large discontinuity)
            if (diff > threshold)
            {
                // Interpolate to remove click
                channelData[i] = prevSample + (currentSample - prevSample) * 0.1f;
            }

            prevSample = channelData[i];
        }
    }
}

void SpectralSculptor::processSpectralFreeze(std::vector<std::complex<float>>& freqData)
{
    if (!freezeEnabled)
        return;

    auto& frozenSpectrum = channelStates[0].frozenSpectrum;
    if (frozenSpectrum.empty())
        return;

    // Replace current spectrum with frozen spectrum
    const int numBins = juce::jmin(static_cast<int>(freqData.size()),
                                     static_cast<int>(frozenSpectrum.size()));

    for (int i = 0; i < numBins; ++i)
    {
        freqData[i] = frozenSpectrum[i];
    }
}

void SpectralSculptor::processSpectralMorph(std::vector<std::complex<float>>& freqData)
{
    // Bio-reactive spectral morphing
    // HRV controls frequency shift amount
    // Coherence controls magnitude modulation

    const float freqShift = bioHRV * morphAmount * 0.1f;  // ±10% frequency shift
    const float magModulation = bioCoherence * morphAmount;

    const int numBins = static_cast<int>(freqData.size());

    std::vector<std::complex<float>> morphedData(numBins);

    for (int i = 0; i < numBins; ++i)
    {
        // Frequency shift
        int shiftedBin = i + static_cast<int>(i * freqShift);
        shiftedBin = juce::jlimit(0, numBins - 1, shiftedBin);

        // Magnitude modulation
        float magnitude = std::abs(freqData[i]);
        float phase = std::arg(freqData[i]);

        // Using fast sine for spectral modulation
        const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
        float modulatedMagnitude = magnitude * (1.0f + magModulation * trigTables.fastSin(static_cast<float>(i) * 0.1f / (2.0f * juce::MathConstants<float>::pi)));

        morphedData[shiftedBin] = std::polar(modulatedMagnitude, phase);
    }

    freqData = morphedData;
}

void SpectralSculptor::processRestore(std::vector<std::complex<float>>& freqData)
{
    // Intelligent restoration: combine denoising + harmonic enhancement
    processDenoise(freqData);
    processHarmonicEnhance(freqData);
}

//==============================================================================
// Utilities
//==============================================================================

void SpectralSculptor::updateFFTSize()
{
    forwardFFT = juce::dsp::FFT(fftOrder);
    inverseFFT = juce::dsp::FFT(fftOrder);
    window = juce::dsp::WindowingFunction<float>(fftSize, juce::dsp::WindowingFunction<float>::hann);

    noiseProfile.resize(fftSize / 2 + 1, 0.0f);
    gateEnvelopes.resize(fftSize / 2 + 1, 1.0f);

    for (auto& state : channelStates)
    {
        state.inputFIFO.resize(fftSize, 0.0f);
        state.outputFIFO.resize(fftSize, 0.0f);
        state.fftData.resize(fftSize, 0.0f);
        state.freqData.resize(fftSize / 2 + 1);
        state.frozenSpectrum.resize(fftSize / 2 + 1);
        state.inputFIFOIndex = 0;
        state.outputFIFOIndex = 0;
    }
}

void SpectralSculptor::updateGateEnvelopes()
{
    gateEnvelopes.resize(fftSize / 2 + 1, 1.0f);
}

float SpectralSculptor::binToFrequency(int bin) const
{
    return static_cast<float>(bin * currentSampleRate / fftSize);
}

int SpectralSculptor::frequencyToBin(float freq) const
{
    return static_cast<int>(freq * fftSize / currentSampleRate);
}

void SpectralSculptor::updateVisualization(const std::vector<std::complex<float>>& freqData)
{
    // Use try_lock to avoid blocking audio thread (called from process loop)
    std::unique_lock<std::mutex> lock(spectrumMutex, std::try_to_lock);
    if (!lock.owns_lock())
        return;  // Skip visualization update if UI is reading (non-critical)

    const float scale = 1024.0f / static_cast<float>(freqData.size());

    for (size_t i = 0; i < visualSpectrum.size(); ++i)
    {
        int bin = static_cast<int>(i / scale);
        if (bin < static_cast<int>(freqData.size()))
        {
            float magnitude = std::abs(freqData[bin]);
            visualSpectrum[i] = magnitude;
        }
    }
}
