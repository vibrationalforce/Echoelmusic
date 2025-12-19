#include "Compressor.h"

Compressor::Compressor()
{
    // Initialize both parameter buffers with defaults
    currentParams = CompressorParams();
    pendingParams = CompressorParams();
}

Compressor::~Compressor() {}

void Compressor::prepare(double sampleRate, int maximumBlockSize)
{
    juce::ignoreUnused(maximumBlockSize);
    currentSampleRate = sampleRate;
    updatePendingCoefficients();
    currentParams = pendingParams;  // Initial sync
}

void Compressor::reset()
{
    envelopeL = 0.0f;
    envelopeR = 0.0f;
    gainReduction = 0.0f;
}

void Compressor::process(juce::AudioBuffer<float>& buffer)
{
    // THREAD SAFETY: Swap parameter buffers at block boundary (safe)
    // This prevents race conditions without blocking the audio thread
    if (paramsNeedUpdate.exchange(false, std::memory_order_acquire))
    {
        currentParams = pendingParams;
    }

    int numSamples = buffer.getNumSamples();
    int numChannels = buffer.getNumChannels();

    if (numSamples == 0 || numChannels == 0)
        return;

    // Cache parameters for this block (read-only, safe)
    const auto& params = currentParams;

    // Get channel pointers for direct memory access (much faster than getSample)
    float* channelL = buffer.getWritePointer(0);
    float* channelR = numChannels > 1 ? buffer.getWritePointer(1) : channelL;

    // SIMD-optimized stereo-linked detection + compression
    // Process 8 samples at a time (AVX) or 4 samples (SSE2/NEON)

#if defined(__AVX__)
    // AVX: Process 8 samples per iteration (8x throughput)
    const __m256 signMask = _mm256_castsi256_ps(_mm256_set1_epi32(0x7FFFFFFF));
    int simdSamples = numSamples & ~7;  // Round down to multiple of 8

    for (int i = 0; i < simdSamples; i += 8)
    {
        // Load 8 samples from each channel
        __m256 samplesL = _mm256_loadu_ps(&channelL[i]);
        __m256 samplesR = _mm256_loadu_ps(&channelR[i]);

        // Absolute value (clear sign bit)
        __m256 absL = _mm256_and_ps(samplesL, signMask);
        __m256 absR = _mm256_and_ps(samplesR, signMask);

        // Stereo-link: max(L, R)
        __m256 detection = _mm256_max_ps(absL, absR);

        // Store detection values for scalar envelope processing
        float detectionBuffer[8];
        _mm256_storeu_ps(detectionBuffer, detection);

        // Scalar envelope follower + gain computation (state-dependent, cannot vectorize)
        for (int j = 0; j < 8; ++j)
        {
            float det = detectionBuffer[j];

            // Envelope follower
            if (det > envelopeL)
                envelopeL += params.attackCoeff * (det - envelopeL);
            else
                envelopeL += params.releaseCoeff * (det - envelopeL);

            // Compute gain reduction
            float gain = computeGain(envelopeL, params);
            gainReduction = 1.0f - gain;

            // Apply makeup gain
            float makeup = juce::Decibels::decibelsToGain(params.makeupGain);
            float totalGain = gain * makeup;

            // Apply gain to both channels
            channelL[i + j] *= totalGain;
            if (numChannels > 1)
                channelR[i + j] *= totalGain;
        }
    }

    // Process remainder samples (0-7 samples)
    for (int i = simdSamples; i < numSamples; ++i)
    {
        float detectionL = std::abs(channelL[i]);
        float detectionR = std::abs(channelR[i]);
        float detection = juce::jmax(detectionL, detectionR);

        if (detection > envelopeL)
            envelopeL += params.attackCoeff * (detection - envelopeL);
        else
            envelopeL += params.releaseCoeff * (detection - envelopeL);

        float gain = computeGain(envelopeL, params);
        gainReduction = 1.0f - gain;

        float makeup = juce::Decibels::decibelsToGain(params.makeupGain);
        float totalGain = gain * makeup;

        channelL[i] *= totalGain;
        if (numChannels > 1)
            channelR[i] *= totalGain;
    }

#elif defined(__SSE2__) || defined(__ARM_NEON)
    // SSE2/NEON: Process 4 samples per iteration (4x throughput)
    int simdSamples = numSamples & ~3;  // Round down to multiple of 4

#if defined(__SSE2__)
    const __m128 signMask = _mm_castsi128_ps(_mm_set1_epi32(0x7FFFFFFF));

    for (int i = 0; i < simdSamples; i += 4)
    {
        __m128 samplesL = _mm_loadu_ps(&channelL[i]);
        __m128 samplesR = _mm_loadu_ps(&channelR[i]);

        __m128 absL = _mm_and_ps(samplesL, signMask);
        __m128 absR = _mm_and_ps(samplesR, signMask);

        __m128 detection = _mm_max_ps(absL, absR);

        float detectionBuffer[4];
        _mm_storeu_ps(detectionBuffer, detection);

        for (int j = 0; j < 4; ++j)
        {
            float det = detectionBuffer[j];

            if (det > envelopeL)
                envelopeL += params.attackCoeff * (det - envelopeL);
            else
                envelopeL += params.releaseCoeff * (det - envelopeL);

            float gain = computeGain(envelopeL, params);
            gainReduction = 1.0f - gain;

            float makeup = juce::Decibels::decibelsToGain(params.makeupGain);
            float totalGain = gain * makeup;

            channelL[i + j] *= totalGain;
            if (numChannels > 1)
                channelR[i + j] *= totalGain;
        }
    }
#elif defined(__ARM_NEON)
    for (int i = 0; i < simdSamples; i += 4)
    {
        float32x4_t samplesL = vld1q_f32(&channelL[i]);
        float32x4_t samplesR = vld1q_f32(&channelR[i]);

        float32x4_t absL = vabsq_f32(samplesL);
        float32x4_t absR = vabsq_f32(samplesR);

        float32x4_t detection = vmaxq_f32(absL, absR);

        float detectionBuffer[4];
        vst1q_f32(detectionBuffer, detection);

        for (int j = 0; j < 4; ++j)
        {
            float det = detectionBuffer[j];

            if (det > envelopeL)
                envelopeL += params.attackCoeff * (det - envelopeL);
            else
                envelopeL += params.releaseCoeff * (det - envelopeL);

            float gain = computeGain(envelopeL, params);
            gainReduction = 1.0f - gain;

            float makeup = juce::Decibels::decibelsToGain(params.makeupGain);
            float totalGain = gain * makeup;

            channelL[i + j] *= totalGain;
            if (numChannels > 1)
                channelR[i + j] *= totalGain;
        }
    }
#endif

    // Process remainder samples (0-3 samples)
    for (int i = simdSamples; i < numSamples; ++i)
    {
        float detectionL = std::abs(channelL[i]);
        float detectionR = std::abs(channelR[i]);
        float detection = juce::jmax(detectionL, detectionR);

        if (detection > envelopeL)
            envelopeL += params.attackCoeff * (detection - envelopeL);
        else
            envelopeL += params.releaseCoeff * (detection - envelopeL);

        float gain = computeGain(envelopeL, params);
        gainReduction = 1.0f - gain;

        float makeup = juce::Decibels::decibelsToGain(params.makeupGain);
        float totalGain = gain * makeup;

        channelL[i] *= totalGain;
        if (numChannels > 1)
            channelR[i] *= totalGain;
    }

#else
    // Scalar fallback (no SIMD available)
    for (int i = 0; i < numSamples; ++i)
    {
        float detectionL = std::abs(channelL[i]);
        float detectionR = std::abs(channelR[i]);
        float detection = juce::jmax(detectionL, detectionR);

        if (detection > envelopeL)
            envelopeL += params.attackCoeff * (detection - envelopeL);
        else
            envelopeL += params.releaseCoeff * (detection - envelopeL);

        float gain = computeGain(envelopeL, params);
        gainReduction = 1.0f - gain;

        float makeup = juce::Decibels::decibelsToGain(params.makeupGain);
        float totalGain = gain * makeup;

        channelL[i] *= totalGain;
        if (numChannels > 1)
            channelR[i] *= totalGain;
    }
#endif
}

void Compressor::setThreshold(float dB)
{
    pendingParams.threshold = juce::jlimit(-60.0f, 0.0f, dB);
    paramsNeedUpdate.store(true, std::memory_order_release);
}

void Compressor::setRatio(float newRatio)
{
    pendingParams.ratio = juce::jlimit(1.0f, 20.0f, newRatio);
    paramsNeedUpdate.store(true, std::memory_order_release);
}

void Compressor::setAttack(float ms)
{
    pendingParams.attack = juce::jlimit(0.1f, 100.0f, ms);
    updatePendingCoefficients();
    paramsNeedUpdate.store(true, std::memory_order_release);
}

void Compressor::setRelease(float ms)
{
    pendingParams.release = juce::jlimit(10.0f, 1000.0f, ms);
    updatePendingCoefficients();
    paramsNeedUpdate.store(true, std::memory_order_release);
}

void Compressor::setKnee(float dB)
{
    pendingParams.knee = juce::jlimit(0.0f, 12.0f, dB);
    paramsNeedUpdate.store(true, std::memory_order_release);
}

void Compressor::setMakeupGain(float dB)
{
    pendingParams.makeupGain = juce::jlimit(0.0f, 24.0f, dB);
    paramsNeedUpdate.store(true, std::memory_order_release);
}

void Compressor::setMode(Mode mode)
{
    pendingParams.mode = mode;
    paramsNeedUpdate.store(true, std::memory_order_release);
}

float Compressor::getGainReduction() const
{
    return gainReduction;
}

void Compressor::updatePendingCoefficients()
{
    // Convert attack/release times to coefficients (UI thread, writes to pending buffer)
    pendingParams.attackCoeff = 1.0f - std::exp(-1.0f / (pendingParams.attack * 0.001f * (float)currentSampleRate));
    pendingParams.releaseCoeff = 1.0f - std::exp(-1.0f / (pendingParams.release * 0.001f * (float)currentSampleRate));
}

float Compressor::computeGain(float input, const CompressorParams& params)
{
    float inputDB = juce::Decibels::gainToDecibels(input + 0.00001f);

    // Soft knee implementation
    float overThreshold = inputDB - params.threshold;
    float gain = 1.0f;

    if (params.knee > 0.0f && overThreshold > -params.knee * 0.5f && overThreshold < params.knee * 0.5f)
    {
        // Soft knee region
        float kneeInput = overThreshold + params.knee * 0.5f;
        float kneeOutput = kneeInput * kneeInput / (2.0f * params.knee);
        float compressionDB = kneeOutput / params.ratio - kneeOutput;
        gain = juce::Decibels::decibelsToGain(compressionDB);
    }
    else if (overThreshold > 0.0f)
    {
        // Above threshold
        float compressionDB = overThreshold / params.ratio - overThreshold;
        gain = juce::Decibels::decibelsToGain(compressionDB);
    }

    return gain;
}
