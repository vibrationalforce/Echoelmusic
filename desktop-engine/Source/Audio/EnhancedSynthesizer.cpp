// EnhancedSynthesizer.cpp
// Implementation of enhanced synthesizer with effects chain

#include "EnhancedSynthesizer.h"

EnhancedSynthesizer::EnhancedSynthesizer()
{
    // Create all components
    basicSynth = std::make_unique<BasicSynthesizer>();
    filterEffect = std::make_unique<FilterEffect>();
    delayEffect = std::make_unique<DelayEffect>();
    reverbEffect = std::make_unique<ReverbEffect>();
    fftAnalyzer = std::make_unique<FFTAnalyzer>();

    // Set default filter mode to LowPass
    filterEffect->setFilterType(FilterEffect::FilterType::LowPass);
}

EnhancedSynthesizer::~EnhancedSynthesizer()
{
}

void EnhancedSynthesizer::prepareToPlay(int samplesPerBlockExpected, double sampleRate)
{
    // Prepare all components
    basicSynth->prepareToPlay(samplesPerBlockExpected, sampleRate);
    filterEffect->prepare(sampleRate, samplesPerBlockExpected);
    delayEffect->prepare(sampleRate, samplesPerBlockExpected);
    reverbEffect->prepare(sampleRate, samplesPerBlockExpected);
    fftAnalyzer->prepare(sampleRate, samplesPerBlockExpected);

    // Allocate processing buffer
    processingBuffer.setSize(2, samplesPerBlockExpected);
}

void EnhancedSynthesizer::getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill)
{
    // 1. Generate basic synthesis
    basicSynth->getNextAudioBlock(bufferToFill);

    // 2. Apply effects chain: Filter → Delay → Reverb
    filterEffect->process(*bufferToFill.buffer);
    delayEffect->process(*bufferToFill.buffer);
    reverbEffect->process(*bufferToFill.buffer);

    // 3. Analyze output with FFT
    fftAnalyzer->process(*bufferToFill.buffer);
}

void EnhancedSynthesizer::releaseResources()
{
    basicSynth->releaseResources();
    filterEffect->reset();
    delayEffect->reset();
    reverbEffect->reset();
    fftAnalyzer->reset();
}

void EnhancedSynthesizer::setHeartRate(float bpm)
{
    currentHeartRate.store(bpm);
    basicSynth->setHeartRate(bpm);
}

void EnhancedSynthesizer::setHRV(float ms)
{
    currentHRV.store(ms);
    basicSynth->setHRV(ms);

    // HRV controls reverb wetness and room size
    reverbEffect->setFromHRV(ms);
}

void EnhancedSynthesizer::setBreathRate(float breathsPerMinute)
{
    currentBreathRate.store(breathsPerMinute);

    // Breath rate controls filter cutoff
    filterEffect->setFromBreathRate(breathsPerMinute);
}

void EnhancedSynthesizer::setHRVCoherence(float coherence)
{
    currentCoherence.store(coherence);
    basicSynth->setHRVCoherence(coherence);

    // Coherence could also affect delay feedback (optional enhancement)
    // Higher coherence = more feedback (more rhythmic)
    float feedbackAmount = 0.3f + (0.4f * coherence);  // 0.3 - 0.7 range
    delayEffect->setFeedback(feedbackAmount);
}

void EnhancedSynthesizer::setPitch(float frequency, float confidence)
{
    basicSynth->setPitch(frequency, confidence);
}

std::vector<float> EnhancedSynthesizer::getSpectrum() const
{
    return fftAnalyzer->getSpectrum();
}

float EnhancedSynthesizer::getRMS() const
{
    return fftAnalyzer->getRMS();
}

float EnhancedSynthesizer::getPeak() const
{
    return fftAnalyzer->getPeak();
}
