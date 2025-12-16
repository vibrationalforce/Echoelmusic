#include "AudioHumanizer.h"
#include <cmath>

//==============================================================================
// Constructor
//==============================================================================

AudioHumanizer::AudioHumanizer()
    : rng(std::random_device{}())
    , normalDist(0.0f, 1.0f)
{
    // Initialize spectral gains
    currentSpectralGains.resize(NUM_SPECTRAL_BANDS, 1.0f);
    nextSpectralGains.resize(NUM_SPECTRAL_BANDS, 1.0f);
    smoothedSpectralGains.resize(NUM_SPECTRAL_BANDS, 1.0f);
}

//==============================================================================
// Master Controls
//==============================================================================

void AudioHumanizer::setHumanizationAmount(float amount)
{
    humanizationAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setTimeDivision(TimeDivision division)
{
    currentDivision = division;
    updateSliceTiming();
}

void AudioHumanizer::setTempo(float bpm)
{
    currentTempo = juce::jlimit(20.0f, 300.0f, bpm);
    updateSliceTiming();
}

void AudioHumanizer::setTempoSyncEnabled(bool enable)
{
    tempoSyncEnabled = enable;
    updateSliceTiming();
}

void AudioHumanizer::setSliceTimeMs(float timeMs)
{
    manualSliceTimeMs = juce::jlimit(10.0f, 4000.0f, timeMs);
    updateSliceTiming();
}

void AudioHumanizer::setDetectMode(DetectMode mode)
{
    detectMode = mode;
}

//==============================================================================
// Dimension Controls
//==============================================================================

void AudioHumanizer::setSpectralAmount(float amount)
{
    spectralAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setTransientAmount(float amount)
{
    transientAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setColourAmount(float amount)
{
    colourAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setNoiseAmount(float amount)
{
    noiseAmount = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Smoothing
//==============================================================================

void AudioHumanizer::setSmoothAmount(float amount)
{
    smoothAmount = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// LFO
//==============================================================================

void AudioHumanizer::setLFOEnabled(bool enable)
{
    lfoEnabled = enable;
}

void AudioHumanizer::setLFORate(float rateHz)
{
    lfoRate = juce::jlimit(0.01f, 10.0f, rateHz);
}

void AudioHumanizer::setLFODepth(float depth)
{
    lfoDepth = juce::jlimit(0.0f, 1.0f, depth);
}

//==============================================================================
// Bio-Reactive
//==============================================================================

void AudioHumanizer::setBioReactiveEnabled(bool enable)
{
    bioReactiveEnabled = enable;
}

void AudioHumanizer::updateBioData(float hrvNormalized, float coherence, float stressLevel)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrvNormalized);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentStress = juce::jlimit(0.0f, 1.0f, stressLevel);
}

void AudioHumanizer::applyBioReactiveModulation()
{
    if (!bioReactiveEnabled)
        return;

    // Bio-reactive logic:
    // High HRV + High Coherence = Subtle, slow variations (calm, flowing)
    // Low HRV + High Stress = More intense, faster variations (energetic, varied)

    float bioFactor = (currentHRV + currentCoherence) * 0.5f;

    // Modulate humanization amount
    float bioModulation = (1.0f - bioFactor) * 0.3f + currentStress * 0.2f;
    float effectiveAmount = humanizationAmount + bioModulation;
    effectiveAmount = juce::jlimit(0.0f, 1.0f, effectiveAmount);

    // Apply to all dimensions
    spectralAmount = effectiveAmount;
    transientAmount = effectiveAmount * 0.8f;  // Slightly less aggressive
    colourAmount = effectiveAmount * 0.6f;
    noiseAmount = effectiveAmount * 0.4f;
}

//==============================================================================
// Processing
//==============================================================================

void AudioHumanizer::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;
    updateSliceTiming();
    reset();
}

void AudioHumanizer::reset()
{
    samplesSinceSliceStart = 0;
    currentSliceIndex = 0;

    lfoPhase = 0.0f;
    previousSample = 0.0f;
    envelopeFollower = 0.0f;
    transientCount = 0;
    samplesSinceLastTransient = 0;

    std::fill(smoothedSpectralGains.begin(), smoothedSpectralGains.end(), 1.0f);
    smoothedTransientScale = 1.0f;
    smoothedColourShift = 0.0f;
    smoothedNoiseLevel = 0.0f;

    generateNewVariations();
}

void AudioHumanizer::process(juce::AudioBuffer<float>& buffer)
{
    if (humanizationAmount < 0.01f)
        return;  // Bypassed

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Apply bio-reactive modulation
    applyBioReactiveModulation();

    // Update LFO
    updateLFO();

    // Process each sample
    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Check if we're starting a new slice
        if (samplesSinceSliceStart >= samplesPerSlice)
        {
            // Move to next slice
            currentSliceIndex++;
            samplesSinceSliceStart = 0;

            // Copy next variations to current
            currentSpectralGains = nextSpectralGains;
            currentTransientScale = nextTransientScale;
            currentColourShift = nextColourShift;
            currentNoiseLevel = nextNoiseLevel;

            // Generate new variations for next slice
            generateNewVariations();

            // Reset smoothing
            std::copy(currentSpectralGains.begin(), currentSpectralGains.end(),
                     smoothedSpectralGains.begin());
            smoothedTransientScale = currentTransientScale;
            smoothedColourShift = currentColourShift;
            smoothedNoiseLevel = currentNoiseLevel;
        }

        // Calculate smooth interpolation factor (within current slice)
        float sliceProgress = static_cast<float>(samplesSinceSliceStart) / samplesPerSlice;
        float smoothFactor = smoothAmount * sliceProgress;

        // Smooth spectral gains
        for (int band = 0; band < NUM_SPECTRAL_BANDS; ++band)
        {
            smoothedSpectralGains[band] = currentSpectralGains[band] * (1.0f - smoothFactor) +
                                         nextSpectralGains[band] * smoothFactor;
        }

        // Smooth other parameters
        smoothedTransientScale = currentTransientScale * (1.0f - smoothFactor) +
                                nextTransientScale * smoothFactor;
        smoothedColourShift = currentColourShift * (1.0f - smoothFactor) +
                            nextColourShift * smoothFactor;
        smoothedNoiseLevel = currentNoiseLevel * (1.0f - smoothFactor) +
                           nextNoiseLevel * smoothFactor;

        // Detect transients (for advanced mode)
        if (detectMode == DetectMode::Advanced && numChannels > 0)
        {
            float monoSample = 0.0f;
            for (int ch = 0; ch < numChannels; ++ch)
            {
                monoSample += buffer.getSample(ch, sample);
            }
            monoSample /= numChannels;

            if (detectTransient(monoSample))
            {
                transientCount++;
                samplesSinceLastTransient = 0;
            }
            else
            {
                samplesSinceLastTransient++;
            }
        }

        samplesSinceSliceStart++;
    }

    // Apply variations to entire buffer
    applySpectralVariations(buffer);
    applyTransientVariations(buffer);
    applyColourVariations(buffer);
    applyNoiseVariations(buffer);

    // Update metering
    currentSpectralVar = 0.0f;
    for (int i = 0; i < NUM_SPECTRAL_BANDS; ++i)
    {
        currentSpectralVar += std::abs(smoothedSpectralGains[i] - 1.0f);
    }
    currentSpectralVar /= NUM_SPECTRAL_BANDS;

    currentTransientVar = std::abs(smoothedTransientScale - 1.0f);

    transientRate = transientCount / (numSamples / currentSampleRate);
}

//==============================================================================
// Internal Methods - Slice Timing
//==============================================================================

void AudioHumanizer::updateSliceTiming()
{
    if (tempoSyncEnabled)
    {
        // Calculate based on tempo and time division
        float quarterNotesPerSecond = currentTempo / 60.0f;
        float divisionMultiplier = getTimeDivisionMultiplier();
        float slicesPerSecond = quarterNotesPerSecond / divisionMultiplier;
        float secondsPerSlice = 1.0f / slicesPerSecond;

        samplesPerSlice = static_cast<int>(secondsPerSlice * currentSampleRate);
    }
    else
    {
        // Use manual slice time
        float secondsPerSlice = manualSliceTimeMs / 1000.0f;
        samplesPerSlice = static_cast<int>(secondsPerSlice * currentSampleRate);
    }

    samplesPerSlice = juce::jlimit(100, MAX_SLICE_SAMPLES, samplesPerSlice);
}

float AudioHumanizer::getTimeDivisionMultiplier() const
{
    switch (currentDivision)
    {
        case TimeDivision::Sixteenth:   return 0.25f;   // 1/16 note
        case TimeDivision::Eighth:      return 0.5f;    // 1/8 note
        case TimeDivision::Quarter:     return 1.0f;    // 1/4 note
        case TimeDivision::Half:        return 2.0f;    // 1/2 note
        case TimeDivision::Whole:       return 4.0f;    // Whole note
        case TimeDivision::TwoBar:      return 8.0f;    // 2 bars
        case TimeDivision::FourBar:     return 16.0f;   // 4 bars
        default:                        return 1.0f;
    }
}

//==============================================================================
// Variation Generation
//==============================================================================

void AudioHumanizer::generateNewVariations()
{
    // Spectral variations (50 bands)
    for (int band = 0; band < NUM_SPECTRAL_BANDS; ++band)
    {
        // ±0.5dB variation per band
        float variation = getRandomVariation(spectralAmount);
        float gainDb = variation * 0.5f;  // ±0.5dB max
        float gain = juce::Decibels::decibelsToGain(gainDb);

        nextSpectralGains[band] = gain;
    }

    // Transient variations (±10% timing)
    float transientVar = getRandomVariation(transientAmount);
    nextTransientScale = 1.0f + transientVar * 0.1f;  // ±10%

    // Colour variations (±2% filter shift)
    float colourVar = getRandomVariation(colourAmount);
    nextColourShift = colourVar * 0.02f;  // ±2%

    // Noise variations (±3dB noise floor)
    float noiseVar = getRandomVariation(noiseAmount);
    nextNoiseLevel = noiseVar * 3.0f;  // ±3dB
}

float AudioHumanizer::getRandomVariation(float amount)
{
    // Normal distribution with mean=0, stddev=1
    float value = normalDist(rng);

    // Scale by amount and clamp to ±2 standard deviations
    value = juce::jlimit(-2.0f, 2.0f, value);

    return value * amount;
}

//==============================================================================
// LFO
//==============================================================================

void AudioHumanizer::updateLFO()
{
    if (!lfoEnabled)
        return;

    // Update LFO phase
    float lfoIncrement = lfoRate / currentSampleRate;
    lfoPhase += lfoIncrement;

    if (lfoPhase >= 1.0f)
        lfoPhase -= 1.0f;

    // Calculate LFO value (sine wave, 0 to 1)
    float lfoValue = (std::sin(lfoPhase * juce::MathConstants<float>::twoPi) + 1.0f) * 0.5f;

    // Modulate variation amounts
    float modAmount = lfoValue * lfoDepth;

    spectralAmount = juce::jlimit(0.0f, 1.0f, spectralAmount + modAmount - lfoDepth * 0.5f);
    transientAmount = juce::jlimit(0.0f, 1.0f, transientAmount + modAmount - lfoDepth * 0.5f);
}

//==============================================================================
// Transient Detection
//==============================================================================

bool AudioHumanizer::detectTransient(float sample)
{
    // Simple envelope follower
    float sampleAbs = std::abs(sample);
    float attack = 0.001f;
    float release = 0.1f;

    if (sampleAbs > envelopeFollower)
    {
        envelopeFollower = envelopeFollower * (1.0f - attack) + sampleAbs * attack;
    }
    else
    {
        envelopeFollower = envelopeFollower * (1.0f - release) + sampleAbs * release;
    }

    // Detect transient (sharp attack)
    float delta = sampleAbs - previousSample;
    previousSample = sampleAbs;

    bool isTransient = (delta > transientThreshold) && (samplesSinceLastTransient > 100);

    // Adaptive threshold (increases if too many transients, decreases if too few)
    if (transientRate > 20.0f)
    {
        transientThreshold *= 1.01f;  // Increase threshold
    }
    else if (transientRate < 1.0f)
    {
        transientThreshold *= 0.99f;  // Decrease threshold
    }

    transientThreshold = juce::jlimit(0.01f, 0.5f, transientThreshold);

    return isTransient;
}

//==============================================================================
// Variation Application
//==============================================================================

void AudioHumanizer::applySpectralVariations(juce::AudioBuffer<float>& buffer)
{
    if (spectralAmount < 0.01f)
        return;

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Simple spectral variation: apply frequency-dependent gains
    // (In production, would use FFT for precise per-band control)

    for (int channel = 0; channel < numChannels; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        // Apply average spectral gain (simplified)
        float avgGain = 0.0f;
        for (int band = 0; band < NUM_SPECTRAL_BANDS; ++band)
        {
            avgGain += smoothedSpectralGains[band];
        }
        avgGain /= NUM_SPECTRAL_BANDS;

        for (int sample = 0; sample < numSamples; ++sample)
        {
            channelData[sample] *= avgGain;
        }
    }
}

void AudioHumanizer::applyTransientVariations(juce::AudioBuffer<float>& buffer)
{
    if (transientAmount < 0.01f)
        return;

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Apply transient scaling (simplified - scales amplitude based on transient detection)
    for (int channel = 0; channel < numChannels; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            channelData[sample] *= smoothedTransientScale;
        }
    }
}

void AudioHumanizer::applyColourVariations(juce::AudioBuffer<float>& buffer)
{
    if (colourAmount < 0.01f)
        return;

    // Colour variation: subtle tone/timbre changes
    // (Simplified: applies slight high-frequency emphasis/de-emphasis)

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    float colourGain = 1.0f + smoothedColourShift;

    for (int channel = 0; channel < numChannels; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            channelData[sample] *= colourGain;
        }
    }
}

void AudioHumanizer::applyNoiseVariations(juce::AudioBuffer<float>& buffer)
{
    if (noiseAmount < 0.01f)
        return;

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Add subtle noise (very quiet, ±3dB variation)
    float noiseGain = juce::Decibels::decibelsToGain(-80.0f + smoothedNoiseLevel);

    for (int channel = 0; channel < numChannels; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float noise = normalDist(rng) * noiseGain;
            channelData[sample] += noise;
        }
    }
}
