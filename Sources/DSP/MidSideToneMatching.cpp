#include "MidSideToneMatching.h"
#include <cmath>
#include <algorithm>

//==============================================================================
// Constructor
//==============================================================================

MidSideToneMatching::MidSideToneMatching()
{
    // Initialize spectral storage
    referenceMidSpectrum.resize(NUM_BANDS, 0.0f);
    referenceSideSpectrum.resize(NUM_BANDS, 0.0f);

    // Initialize EQ curves
    midEQCurve.resize(NUM_BANDS, 1.0f);  // 0dB (unity gain)
    sideEQCurve.resize(NUM_BANDS, 1.0f);
    targetMidEQ.resize(NUM_BANDS, 1.0f);
    targetSideEQ.resize(NUM_BANDS, 1.0f);
    midEQSmoothState.resize(NUM_BANDS, 1.0f);
    sideEQSmoothState.resize(NUM_BANDS, 1.0f);

    // Initialize FFT buffers
    fftDataMid.resize(FFT_SIZE * 2, 0.0f);
    fftDataSide.resize(FFT_SIZE * 2, 0.0f);
    fftBufferMid.resize(FFT_SIZE, 0.0f);
    fftBufferSide.resize(FFT_SIZE, 0.0f);
}

//==============================================================================
// Reference Track Analysis
//==============================================================================

void MidSideToneMatching::learnReferenceProfile(const juce::AudioBuffer<float>& referenceBuffer)
{
    if (referenceBuffer.getNumChannels() < 2)
    {
        jassertfalse;  // Must be stereo
        return;
    }

    std::vector<float> newMidSpectrum(NUM_BANDS, 0.0f);
    std::vector<float> newSideSpectrum(NUM_BANDS, 0.0f);

    // Analyze reference track
    analyzeSpectrum(referenceBuffer, newMidSpectrum, newSideSpectrum);

    if (continuousLearning && referenceProfileLearned)
    {
        // Average with existing profile
        float alpha = 1.0f / (learningCount + 1.0f);

        for (int i = 0; i < NUM_BANDS; ++i)
        {
            referenceMidSpectrum[i] = referenceMidSpectrum[i] * (1.0f - alpha) + newMidSpectrum[i] * alpha;
            referenceSideSpectrum[i] = referenceSideSpectrum[i] * (1.0f - alpha) + newSideSpectrum[i] * alpha;
        }

        learningCount++;
    }
    else
    {
        // First reference or overwrite mode
        referenceMidSpectrum = newMidSpectrum;
        referenceSideSpectrum = newSideSpectrum;
        learningCount = 1;
    }

    referenceProfileLearned = true;

    DBG("Mid/Side Tone Matching: Reference profile learned (count: " + juce::String(learningCount) + ")");
}

void MidSideToneMatching::clearReferenceProfile()
{
    std::fill(referenceMidSpectrum.begin(), referenceMidSpectrum.end(), 0.0f);
    std::fill(referenceSideSpectrum.begin(), referenceSideSpectrum.end(), 0.0f);
    referenceProfileLearned = false;
    learningCount = 0;

    DBG("Mid/Side Tone Matching: Reference profile cleared");
}

//==============================================================================
// Matching Parameters
//==============================================================================

void MidSideToneMatching::setMatchingStrength(float strength)
{
    matchingStrength = juce::jlimit(0.0f, 1.0f, strength);
}

void MidSideToneMatching::setMidMatchingAmount(float amount)
{
    midMatchingAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void MidSideToneMatching::setSideMatchingAmount(float amount)
{
    sideMatchingAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void MidSideToneMatching::setMatchingMode(MatchingMode mode)
{
    currentMode = mode;
}

void MidSideToneMatching::setCustomFrequencyRange(float lowFreq, float highFreq)
{
    customLowFreq = juce::jlimit(20.0f, 20000.0f, lowFreq);
    customHighFreq = juce::jlimit(customLowFreq, 20000.0f, highFreq);
}

void MidSideToneMatching::setSmoothingAmount(float amount)
{
    smoothingAmount = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Bio-Reactive Integration
//==============================================================================

void MidSideToneMatching::updateBioData(float hrvNormalized, float coherence, float stressLevel)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrvNormalized);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentStress = juce::jlimit(0.0f, 1.0f, stressLevel);
}

void MidSideToneMatching::applyBioReactiveModulation()
{
    if (!bioReactiveEnabled)
        return;

    // Bio-reactive logic:
    // High HRV + High Coherence = More gentle matching (preserve dynamics)
    // Low HRV + High Stress = More aggressive matching (stabilize sound)

    float bioFactor = (currentHRV + currentCoherence) * 0.5f;
    float stressFactor = currentStress;

    // Modulate matching strength: stress increases, coherence decreases it
    float bioModulation = (1.0f - bioFactor) * 0.3f + stressFactor * 0.2f;
    float effectiveStrength = matchingStrength + bioModulation;
    effectiveStrength = juce::jlimit(0.0f, 1.0f, effectiveStrength);

    // Apply to both mid and side (could be separate in future)
    midMatchingAmount = effectiveStrength;
    sideMatchingAmount = effectiveStrength;
}

//==============================================================================
// Processing
//==============================================================================

void MidSideToneMatching::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;
    reset();
}

void MidSideToneMatching::reset()
{
    fftInputPos = 0;
    fftReady = false;

    std::fill(fftBufferMid.begin(), fftBufferMid.end(), 0.0f);
    std::fill(fftBufferSide.begin(), fftBufferSide.end(), 0.0f);
    std::fill(midEQSmoothState.begin(), midEQSmoothState.end(), 1.0f);
    std::fill(sideEQSmoothState.begin(), sideEQSmoothState.end(), 1.0f);
}

void MidSideToneMatching::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();

    if (numChannels < 2)
        return;  // Requires stereo

    if (!referenceProfileLearned)
        return;  // No reference to match

    if (matchingStrength < 0.01f)
        return;  // Bypassed

    const int numSamples = buffer.getNumSamples();

    // Apply bio-reactive modulation
    applyBioReactiveModulation();

    // Analyze current audio
    std::vector<float> currentMidSpectrum(NUM_BANDS, 0.0f);
    std::vector<float> currentSideSpectrum(NUM_BANDS, 0.0f);
    analyzeSpectrum(buffer, currentMidSpectrum, currentSideSpectrum);

    // Calculate target EQ curves
    calculateTargetEQ(currentMidSpectrum, referenceMidSpectrum, targetMidEQ);
    calculateTargetEQ(currentSideSpectrum, referenceSideSpectrum, targetSideEQ);

    // Smooth EQ curves (prevents abrupt changes)
    float smoothFactor = 0.05f + smoothingAmount * 0.15f;  // 0.05 to 0.20

    for (int i = 0; i < NUM_BANDS; ++i)
    {
        midEQSmoothState[i] = midEQSmoothState[i] * (1.0f - smoothFactor) + targetMidEQ[i] * smoothFactor;
        sideEQSmoothState[i] = sideEQSmoothState[i] * (1.0f - smoothFactor) + targetSideEQ[i] * smoothFactor;

        // Apply matching strength
        midEQCurve[i] = 1.0f + (midEQSmoothState[i] - 1.0f) * matchingStrength * midMatchingAmount;
        sideEQCurve[i] = 1.0f + (sideEQSmoothState[i] - 1.0f) * matchingStrength * sideMatchingAmount;
    }

    // Apply EQ curves to Mid and Side channels separately
    // This is done by converting L/R to M/S, applying EQ, converting back

    float* leftChannel = buffer.getWritePointer(0);
    float* rightChannel = buffer.getWritePointer(1);

    // Simple per-sample M/S conversion and EQ application
    // (In production, would use FFT-based filtering for better quality)

    for (int i = 0; i < numSamples; ++i)
    {
        float left = leftChannel[i];
        float right = rightChannel[i];

        // Convert to Mid/Side
        float mid = (left + right) * 0.5f;
        float side = (left - right) * 0.5f;

        // Apply frequency-dependent gains (simplified - uses average across spectrum)
        float midGain = 0.0f;
        float sideGain = 0.0f;

        for (int band = 0; band < NUM_BANDS; ++band)
        {
            midGain += midEQCurve[band];
            sideGain += sideEQCurve[band];
        }

        midGain /= NUM_BANDS;
        sideGain /= NUM_BANDS;

        mid *= midGain;
        side *= sideGain;

        // Convert back to Left/Right
        leftChannel[i] = mid + side;
        rightChannel[i] = mid - side;
    }

    // Update metering
    updateMetering();
}

//==============================================================================
// Internal Methods - Spectrum Analysis
//==============================================================================

void MidSideToneMatching::analyzeSpectrum(const juce::AudioBuffer<float>& buffer,
                                         std::vector<float>& midSpectrum,
                                         std::vector<float>& sideSpectrum)
{
    const int numSamples = buffer.getNumSamples();
    const float* leftChannel = buffer.getReadPointer(0);
    const float* rightChannel = buffer.getReadPointer(1);

    // Clear accumulators
    std::fill(fftDataMid.begin(), fftDataMid.end(), 0.0f);
    std::fill(fftDataSide.begin(), fftDataSide.end(), 0.0f);

    // Fill FFT buffer with M/S data
    int samplesProcessed = 0;
    int fftCount = 0;

    while (samplesProcessed + FFT_SIZE <= numSamples)
    {
        // Fill FFT buffer
        for (int i = 0; i < FFT_SIZE; ++i)
        {
            int sampleIdx = samplesProcessed + i;

            float left = leftChannel[sampleIdx];
            float right = rightChannel[sampleIdx];

            // Convert to M/S
            float mid = (left + right) * 0.5f;
            float side = (left - right) * 0.5f;

            fftBufferMid[i] = mid;
            fftBufferSide[i] = side;
        }

        // Apply window
        window.multiplyWithWindowingTable(fftBufferMid.data(), FFT_SIZE);
        window.multiplyWithWindowingTable(fftBufferSide.data(), FFT_SIZE);

        // Copy to FFT data (complex format: real, imag, real, imag, ...)
        for (int i = 0; i < FFT_SIZE; ++i)
        {
            fftDataMid[i * 2] = fftBufferMid[i];
            fftDataMid[i * 2 + 1] = 0.0f;  // Imaginary = 0

            fftDataSide[i * 2] = fftBufferSide[i];
            fftDataSide[i * 2 + 1] = 0.0f;
        }

        // Perform FFT
        fftProcessor.performFrequencyOnlyForwardTransform(fftDataMid.data());
        fftProcessor.performFrequencyOnlyForwardTransform(fftDataSide.data());

        // Accumulate magnitude spectrum
        std::vector<float> tempMidBands(NUM_BANDS, 0.0f);
        std::vector<float> tempSideBands(NUM_BANDS, 0.0f);

        binsToBands(fftDataMid, tempMidBands);
        binsToBands(fftDataSide, tempSideBands);

        for (int i = 0; i < NUM_BANDS; ++i)
        {
            midSpectrum[i] += tempMidBands[i];
            sideSpectrum[i] += tempSideBands[i];
        }

        samplesProcessed += HOP_SIZE;
        fftCount++;
    }

    // Average over all FFT frames
    if (fftCount > 0)
    {
        for (int i = 0; i < NUM_BANDS; ++i)
        {
            midSpectrum[i] /= fftCount;
            sideSpectrum[i] /= fftCount;
        }
    }
}

void MidSideToneMatching::binsToBands(const std::vector<float>& fftData, std::vector<float>& bands)
{
    // Convert FFT bins to perceptual frequency bands (mel-scale inspired)
    // 32 bands logarithmically spaced from 20 Hz to 20 kHz

    std::fill(bands.begin(), bands.end(), 0.0f);

    for (int band = 0; band < NUM_BANDS; ++band)
    {
        float centerFreq = getBandFrequency(band);
        float binWidth = currentSampleRate / FFT_SIZE;

        int centerBin = static_cast<int>(centerFreq / binWidth);
        int bandWidth = std::max(1, static_cast<int>(centerFreq * 0.1f / binWidth));  // 10% bandwidth

        int startBin = std::max(0, centerBin - bandWidth / 2);
        int endBin = std::min(FFT_SIZE / 2 - 1, centerBin + bandWidth / 2);

        float sumMagnitude = 0.0f;
        int binCount = 0;

        for (int bin = startBin; bin <= endBin; ++bin)
        {
            // Magnitude from complex FFT data
            float magnitude = fftData[bin * 2];  // For frequency-only transform, real part is magnitude
            sumMagnitude += magnitude;
            binCount++;
        }

        if (binCount > 0)
        {
            bands[band] = sumMagnitude / binCount;
        }
    }
}

void MidSideToneMatching::calculateTargetEQ(const std::vector<float>& currentSpectrum,
                                           const std::vector<float>& referenceSpectrum,
                                           std::vector<float>& targetEQ)
{
    for (int i = 0; i < NUM_BANDS; ++i)
    {
        float current = currentSpectrum[i] + 0.0001f;  // Avoid division by zero
        float reference = referenceSpectrum[i] + 0.0001f;

        // Calculate gain needed to match reference
        float gain = reference / current;

        // Limit gain range to ±12dB
        gain = juce::jlimit(0.25f, 4.0f, gain);  // 0.25 = -12dB, 4.0 = +12dB

        // Check if band is in active frequency range (based on mode)
        float frequency = getBandFrequency(i);
        bool inRange = true;

        switch (currentMode)
        {
            case MatchingMode::FullSpectrum:
                inRange = true;
                break;

            case MatchingMode::LowMids:
                inRange = (frequency >= 20.0f && frequency <= 500.0f);
                break;

            case MatchingMode::Midrange:
                inRange = (frequency >= 500.0f && frequency <= 4000.0f);
                break;

            case MatchingMode::HighFrequencies:
                inRange = (frequency >= 4000.0f && frequency <= 20000.0f);
                break;

            case MatchingMode::Custom:
                inRange = (frequency >= customLowFreq && frequency <= customHighFreq);
                break;
        }

        // Apply gain only if in range, otherwise unity gain
        targetEQ[i] = inRange ? gain : 1.0f;
    }
}

float MidSideToneMatching::getBandFrequency(int bandIndex) const
{
    // Logarithmic frequency distribution (mel-scale inspired)
    // 32 bands from 20 Hz to 20 kHz

    float minFreq = 20.0f;
    float maxFreq = 20000.0f;

    float logMin = std::log10(minFreq);
    float logMax = std::log10(maxFreq);

    float logFreq = logMin + (logMax - logMin) * bandIndex / (NUM_BANDS - 1);

    return std::pow(10.0f, logFreq);
}

int MidSideToneMatching::getFrequencyBand(float frequency) const
{
    float minFreq = 20.0f;
    float maxFreq = 20000.0f;

    float logMin = std::log10(minFreq);
    float logMax = std::log10(maxFreq);
    float logFreq = std::log10(juce::jlimit(minFreq, maxFreq, frequency));

    int band = static_cast<int>((logFreq - logMin) / (logMax - logMin) * (NUM_BANDS - 1));

    return juce::jlimit(0, NUM_BANDS - 1, band);
}

//==============================================================================
// Metering
//==============================================================================

void MidSideToneMatching::updateMetering()
{
    // Calculate spectral difference (how far we are from reference)
    float midDiff = 0.0f;
    float sideDiff = 0.0f;

    for (int i = 0; i < NUM_BANDS; ++i)
    {
        float midDeviation = std::abs(midEQCurve[i] - 1.0f);
        float sideDeviation = std::abs(sideEQCurve[i] - 1.0f);

        midDiff += midDeviation;
        sideDiff += sideDeviation;
    }

    midSpectralDiff = midDiff / NUM_BANDS;
    sideSpectralDiff = sideDiff / NUM_BANDS;

    // Calculate overall matching accuracy (inverse of difference)
    float totalDiff = (midSpectralDiff + sideSpectralDiff) * 0.5f;
    matchingAccuracy = 1.0f - juce::jlimit(0.0f, 1.0f, totalDiff);
}
