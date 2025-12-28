#include "ResonanceHealer.h"
#include "../Core/DSPOptimizations.h"

ResonanceHealer::ResonanceHealer()
    : fft(FFT_ORDER)
    , window(FFT_SIZE, juce::dsp::WindowingFunction<float>::hann)
{
    fftData.fill(0.0f);
    magnitudeSpectrum.fill(0.0f);
    phaseSpectrum.fill(0.0f);

    // Initialize resonance bands
    for (int i = 0; i < NUM_BANDS; ++i)
    {
        resonanceBands[i].frequency = 20.0f * std::pow(20000.0f / 20.0f, static_cast<float>(i) / NUM_BANDS);
        resonanceBands[i].magnitude = 0.0f;
        resonanceBands[i].threshold = 0.5f;
        resonanceBands[i].reduction = 0.0f;
        resonanceBands[i].envelope = 0.0f;
    }

    // Initialize band compressors
    for (auto& comp : bandCompressors)
    {
        comp.attack = 0.99f;
        comp.release = 0.995f;
        comp.threshold = 0.5f;
        comp.ratio = 4.0f;
        comp.envelope = 0.0f;
    }
}

ResonanceHealer::~ResonanceHealer()
{
}

void ResonanceHealer::prepare(double sr, int maxBlockSize)
{
    sampleRate = sr;
    blockSize = maxBlockSize;

    // Prepare FIFOs
    inputFifo.setSize(2, FFT_SIZE * 2);
    outputFifo.setSize(2, FFT_SIZE * 2);
    inputFifo.clear();
    outputFifo.clear();

    // Pre-allocate dry buffer
    dryBuffer.setSize(2, maxBlockSize);

    inputFifoWritePos = 0;
    outputFifoReadPos = 0;

    // Initialize cached coefficients
    updateCoefficients();

    reset();
}

void ResonanceHealer::updateCoefficients()
{
    // Pre-compute attack/release coefficients for HOP_SIZE grain
    float hopTime = static_cast<float>(HOP_SIZE) / static_cast<float>(sampleRate);
    cachedAttackCoeff = 1.0f - Echoel::DSP::FastMath::fastExp(-hopTime / (currentAttack * 0.001f));
    cachedReleaseCoeff = 1.0f - Echoel::DSP::FastMath::fastExp(-hopTime / (currentRelease * 0.001f));
}

void ResonanceHealer::reset()
{
    fftData.fill(0.0f);
    magnitudeSpectrum.fill(0.0f);
    phaseSpectrum.fill(0.0f);

    inputFifo.clear();
    outputFifo.clear();

    for (auto& band : resonanceBands)
    {
        band.magnitude = 0.0f;
        band.reduction = 0.0f;
        band.envelope = 0.0f;
    }

    for (auto& comp : bandCompressors)
        comp.envelope = 0.0f;

    smoothedSpectrum.fill(0.0f);
}

void ResonanceHealer::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0)
        return;

    // Ensure dry buffer is large enough (avoid per-frame allocation)
    if (dryBuffer.getNumSamples() < numSamples || dryBuffer.getNumChannels() < numChannels)
        dryBuffer.setSize(numChannels, numSamples, false, false, true);

    // Store dry signal
    for (int ch = 0; ch < numChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Process each channel
    for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        // Fill input FIFO
        for (int sample = 0; sample < numSamples; ++sample)
        {
            inputFifo.setSample(channel, inputFifoWritePos, channelData[sample]);
            inputFifoWritePos = (inputFifoWritePos + 1) % inputFifo.getNumSamples();

            // Process when we have enough samples
            if (inputFifoWritePos % HOP_SIZE == 0)
            {
                // Copy to FFT buffer
                for (int i = 0; i < FFT_SIZE; ++i)
                {
                    int readPos = (inputFifoWritePos - FFT_SIZE + i + inputFifo.getNumSamples())
                                 % inputFifo.getNumSamples();
                    fftData[i] = inputFifo.getSample(channel, readPos);
                    fftData[i + FFT_SIZE] = 0.0f;  // Zero imaginary part
                }

                // Apply window
                window.multiplyWithWindowingTable(fftData.data(), FFT_SIZE);

                // Forward FFT
                fft.performFrequencyOnlyForwardTransform(fftData.data());

                // Extract magnitude & phase using fast math
                for (int i = 0; i < FFT_SIZE / 2; ++i)
                {
                    float real = fftData[i];
                    float imag = fftData[i + FFT_SIZE / 2];
                    magnitudeSpectrum[i] = Echoel::DSP::FastMath::fastSqrt(real * real + imag * imag);
                    // Fast atan2 approximation
                    phaseSpectrum[i] = Echoel::DSP::FastMath::fastAtan(imag / (real + 1e-10f));
                    if (real < 0.0f) phaseSpectrum[i] += (imag >= 0.0f) ? 3.14159265f : -3.14159265f;
                }

                // Detect resonances
                detectResonances();

                // Apply reduction
                applyReduction();

                // Reconstruct complex spectrum using fast trig
                const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
                for (int i = 0; i < FFT_SIZE / 2; ++i)
                {
                    fftData[i] = magnitudeSpectrum[i] * trigTables.fastCosRad(phaseSpectrum[i]);
                    fftData[i + FFT_SIZE / 2] = magnitudeSpectrum[i] * trigTables.fastSinRad(phaseSpectrum[i]);
                }

                // Inverse FFT
                fft.performRealOnlyInverseTransform(fftData.data());

                // Overlap-add to output FIFO
                for (int i = 0; i < FFT_SIZE; ++i)
                {
                    int writePos = (outputFifoReadPos + i) % outputFifo.getNumSamples();
                    float existing = outputFifo.getSample(channel, writePos);
                    outputFifo.setSample(channel, writePos, existing + fftData[i] / FFT_SIZE);
                }

                outputFifoReadPos = (outputFifoReadPos + HOP_SIZE) % outputFifo.getNumSamples();
            }

            // Read from output FIFO
            channelData[sample] = outputFifo.getSample(channel, outputFifoReadPos);
            outputFifo.setSample(channel, outputFifoReadPos, 0.0f);  // Clear after reading
            outputFifoReadPos = (outputFifoReadPos + 1) % outputFifo.getNumSamples();
        }
    }

    // Mix dry/wet
    if (deltaMode)
    {
        // Delta mode: output only what was removed
        for (int ch = 0; ch < numChannels; ++ch)
        {
            auto* wet = buffer.getReadPointer(ch);
            auto* dry = dryBuffer.getReadPointer(ch);
            auto* out = buffer.getWritePointer(ch);

            for (int i = 0; i < numSamples; ++i)
                out[i] = dry[i] - wet[i];
        }
    }
    else
    {
        // Normal mode: blend dry/wet
        for (int ch = 0; ch < numChannels; ++ch)
        {
            auto* wet = buffer.getReadPointer(ch);
            auto* dry = dryBuffer.getReadPointer(ch);
            auto* out = buffer.getWritePointer(ch);

            for (int i = 0; i < numSamples; ++i)
                out[i] = dry[i] * (1.0f - currentMix) + wet[i] * currentMix;
        }
    }
}

//==============================================================================
// Resonance Detection

void ResonanceHealer::detectResonances()
{
    // Calculate spectral envelope using pre-allocated smoothedSpectrum buffer
    constexpr int windowSize = FFT_SIZE / 64;  // Smoothing window

    for (int i = 0; i < FFT_SIZE / 2; ++i)
    {
        float sum = 0.0f;
        int count = 0;

        for (int j = -windowSize / 2; j <= windowSize / 2; ++j)
        {
            int idx = i + j;
            if (idx >= 0 && idx < FFT_SIZE / 2)
            {
                sum += magnitudeSpectrum[idx];
                count++;
            }
        }

        smoothedSpectrum[i] = sum / count;
    }

    // Detect resonances (peaks above smoothed envelope)
    for (auto& band : resonanceBands)
    {
        int bin = getFrequencyBin(band.frequency);

        if (bin < 0 || bin >= FFT_SIZE / 2)
            continue;

        // Check if frequency is in range
        if (band.frequency < lowFreq || band.frequency > highFreq)
        {
            band.reduction = 0.0f;
            continue;
        }

        // Sibilance mode: boost sensitivity in 4-10kHz
        float sensitivityMultiplier = 1.0f;
        if (sibilanceMode && band.frequency >= 4000.0f && band.frequency <= 10000.0f)
            sensitivityMultiplier = 2.0f;

        // Get magnitude and smoothed envelope
        float magnitude = magnitudeSpectrum[bin];
        float envelope = smoothedSpectrum[bin];

        // Detect resonance (magnitude significantly above envelope)
        float threshold = envelope * (1.0f + currentSensitivity * sensitivityMultiplier);

        if (magnitude > threshold)
        {
            // Calculate reduction amount
            float excess = magnitude - threshold;
            float reductionTarget = juce::jlimit(0.0f, 1.0f, excess / threshold * currentDepth);

            // Smooth reduction with cached attack/release coefficients
            if (reductionTarget > band.reduction)
                band.reduction += cachedAttackCoeff * (reductionTarget - band.reduction);
            else
                band.reduction += cachedReleaseCoeff * (reductionTarget - band.reduction);
        }
        else
        {
            // Release using cached coefficient
            band.reduction += cachedReleaseCoeff * (0.0f - band.reduction);
        }

        band.magnitude = magnitude;
    }
}

void ResonanceHealer::applyReduction()
{
    // Apply reduction to spectrum
    for (const auto& band : resonanceBands)
    {
        if (band.reduction < 0.01f)
            continue;

        int centerBin = getFrequencyBin(band.frequency);

        // Calculate bandwidth based on sharpness
        float Q = juce::jmap(currentSharpness, 0.0f, 1.0f, 2.0f, 20.0f);
        float bandwidth = band.frequency / Q;
        int binWidth = static_cast<int>(bandwidth / (static_cast<float>(sampleRate) / FFT_SIZE));
        binWidth = juce::jmax(1, binWidth);

        // Apply bell-shaped reduction
        for (int i = -binWidth; i <= binWidth; ++i)
        {
            int bin = centerBin + i;

            if (bin < 0 || bin >= FFT_SIZE / 2)
                continue;

            // Calculate bell curve using fast exp
            float x = static_cast<float>(i) / binWidth;
            float bellCurve = Echoel::DSP::FastMath::fastExp(-4.0f * x * x);  // Gaussian

            // Apply reduction
            float gain = 1.0f - (band.reduction * bellCurve);
            magnitudeSpectrum[bin] *= gain;
        }
    }
}

float ResonanceHealer::calculateSpectralCentroid()
{
    float numerator = 0.0f;
    float denominator = 0.0f;

    for (int i = 0; i < FFT_SIZE / 2; ++i)
    {
        float freq = getBinFrequency(i);
        float mag = magnitudeSpectrum[i];

        numerator += freq * mag;
        denominator += mag;
    }

    return (denominator > 0.0f) ? (numerator / denominator) : 1000.0f;
}

int ResonanceHealer::getFrequencyBin(float frequency)
{
    return static_cast<int>(frequency * FFT_SIZE / static_cast<float>(sampleRate));
}

float ResonanceHealer::getBinFrequency(int bin)
{
    return bin * static_cast<float>(sampleRate) / FFT_SIZE;
}

//==============================================================================
// Parameters

void ResonanceHealer::setDepth(float depth)
{
    currentDepth = juce::jlimit(0.0f, 1.0f, depth);
}

void ResonanceHealer::setAttack(float ms)
{
    currentAttack = juce::jlimit(1.0f, 100.0f, ms);
    updateCoefficients();  // Update cached coefficients
}

void ResonanceHealer::setRelease(float ms)
{
    currentRelease = juce::jlimit(10.0f, 1000.0f, ms);
    updateCoefficients();  // Update cached coefficients
}

void ResonanceHealer::setFrequencyRange(float lowHz, float highHz)
{
    lowFreq = juce::jlimit(20.0f, 20000.0f, lowHz);
    highFreq = juce::jlimit(lowFreq, 20000.0f, highHz);
}

void ResonanceHealer::setSensitivity(float sensitivity)
{
    currentSensitivity = juce::jlimit(0.0f, 1.0f, sensitivity);
}

void ResonanceHealer::setSharpness(float sharpness)
{
    currentSharpness = juce::jlimit(0.0f, 1.0f, sharpness);
}

void ResonanceHealer::setDeltaMode(bool enabled)
{
    deltaMode = enabled;
}

void ResonanceHealer::setSibilanceMode(bool enabled)
{
    sibilanceMode = enabled;
}

void ResonanceHealer::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
