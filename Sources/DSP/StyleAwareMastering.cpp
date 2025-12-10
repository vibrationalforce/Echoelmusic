#include "StyleAwareMastering.h"
#include <cmath>
#include <algorithm>

//==============================================================================
// StyleAwareMastering Implementation

StyleAwareMastering::StyleAwareMastering()
{
    initializePresets();
    loadGenreDefaults(Genre::Pop);
    reset();
}

StyleAwareMastering::~StyleAwareMastering() {}

void StyleAwareMastering::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    currentSampleRate = sampleRate;
    currentNumChannels = numChannels;

    // Initialize filters at current sample rate
    lowShelfFilter.setLowShelf(eqSettings.lowShelfFreq, eqSettings.lowShelfGain, currentSampleRate);
    highShelfFilter.setHighShelf(eqSettings.highShelfFreq, eqSettings.highShelfGain, currentSampleRate);
    midPeakFilter.setPeak(eqSettings.midBoostFreq, eqSettings.midBoostGain, 1.0f, currentSampleRate);
}

void StyleAwareMastering::reset()
{
    // Reset filter states
    lowShelfFilter.z1L = lowShelfFilter.z2L = 0.0f;
    lowShelfFilter.z1R = lowShelfFilter.z2R = 0.0f;
    highShelfFilter.z1L = highShelfFilter.z2L = 0.0f;
    highShelfFilter.z1R = highShelfFilter.z2R = 0.0f;
    midPeakFilter.z1L = midPeakFilter.z2L = 0.0f;
    midPeakFilter.z1R = midPeakFilter.z2R = 0.0f;

    // Reset compressor states
    compressorL.envelope = 0.0f;
    compressorL.gain = 1.0f;
    compressorR.envelope = 0.0f;
    compressorR.gain = 1.0f;

    // Reset metrics
    currentMetrics = CurrentMetrics();
    beforeMetrics = CurrentMetrics();
}

void StyleAwareMastering::process(juce::AudioBuffer<float>& buffer)
{
    if (buffer.getNumChannels() < 1)
        return;

    // Store before metrics
    if (autoMasteringEnabled)
    {
        beforeMetrics = currentMetrics;
        analyzeMetrics(buffer);
    }

    // Process mastering chain
    for (const auto& module : masteringChain)
    {
        if (!module.enabled)
            continue;

        switch (module.type)
        {
            case ChainModule::Type::EQ:
                processEQ(buffer);
                break;
            case ChainModule::Type::Compression:
                processCompression(buffer);
                break;
            case ChainModule::Type::Limiting:
                processLimiter(buffer);
                break;
            default:
                break;
        }
    }

    // Analyze after processing
    if (autoMasteringEnabled)
    {
        analyzeMetrics(buffer);
        autoAdjustParameters();
    }
}

//==============================================================================
// Genre Selection

void StyleAwareMastering::setGenre(Genre genre)
{
    currentGenre = genre;
    loadGenreDefaults(genre);
}

StyleAwareMastering::Genre StyleAwareMastering::getGenre() const
{
    return currentGenre;
}

//==============================================================================
// Mastering Chain

std::vector<StyleAwareMastering::ChainModule> StyleAwareMastering::getMasteringChain() const
{
    return masteringChain;
}

void StyleAwareMastering::setMasteringChain(const std::vector<ChainModule>& chain)
{
    masteringChain = chain;
}

//==============================================================================
// Genre Targets

StyleAwareMastering::GenreTargets StyleAwareMastering::getGenreTargets() const
{
    return genreTargets;
}

void StyleAwareMastering::setCustomTargets(const GenreTargets& targets)
{
    customTargets = targets;
    genreTargets = targets;
}

//==============================================================================
// Analysis & Matching

StyleAwareMastering::CurrentMetrics StyleAwareMastering::analyzeCurrentState() const
{
    return currentMetrics;
}

//==============================================================================
// Reference Matching

void StyleAwareMastering::setReferenceTrack(const juce::AudioBuffer<float>& reference)
{
    referenceTrack = reference;
    hasReferenceTrack = true;

    // Analyze reference
    analyzeMetrics(referenceTrack);
    referenceAnalysis.referenceLUFS = currentMetrics.integratedLUFS;
    referenceAnalysis.referenceLRA = currentMetrics.loudnessRange;
    referenceAnalysis.referencePeak = juce::jmax(currentMetrics.truePeakL, currentMetrics.truePeakR);
}

void StyleAwareMastering::clearReferenceTrack()
{
    hasReferenceTrack = false;
    referenceAnalysis = ReferenceAnalysis();
}

StyleAwareMastering::ReferenceAnalysis StyleAwareMastering::getReferenceAnalysis() const
{
    return referenceAnalysis;
}

//==============================================================================
// Auto-Mastering

void StyleAwareMastering::setMasteringIntensity(MasteringIntensity intensity_)
{
    intensity = intensity_;
}

void StyleAwareMastering::enableAutoMastering(bool enable)
{
    autoMasteringEnabled = enable;
}

bool StyleAwareMastering::isAutoMasteringEnabled() const
{
    return autoMasteringEnabled;
}

//==============================================================================
// EQ Settings

void StyleAwareMastering::setEQSettings(const EQSettings& settings)
{
    eqSettings = settings;
    lowShelfFilter.setLowShelf(settings.lowShelfFreq, settings.lowShelfGain, currentSampleRate);
    highShelfFilter.setHighShelf(settings.highShelfFreq, settings.highShelfGain, currentSampleRate);
    midPeakFilter.setPeak(settings.midBoostFreq, settings.midBoostGain, 1.0f, currentSampleRate);
}

StyleAwareMastering::EQSettings StyleAwareMastering::getEQSettings() const
{
    return eqSettings;
}

//==============================================================================
// Compression Settings

void StyleAwareMastering::setCompressionSettings(const CompressionSettings& settings)
{
    compressionSettings = settings;
}

StyleAwareMastering::CompressionSettings StyleAwareMastering::getCompressionSettings() const
{
    return compressionSettings;
}

//==============================================================================
// Limiter Settings

void StyleAwareMastering::setLimiterSettings(const LimiterSettings& settings)
{
    limiterSettings = settings;
}

StyleAwareMastering::LimiterSettings StyleAwareMastering::getLimiterSettings() const
{
    return limiterSettings;
}

//==============================================================================
// Presets

void StyleAwareMastering::loadPreset(const std::string& presetName)
{
    auto it = presetDatabase.find(presetName);
    if (it != presetDatabase.end())
    {
        const Preset& preset = it->second;
        currentGenre = preset.genre;
        genreTargets = preset.targets;
        masteringChain = preset.chain;
        eqSettings = preset.eq;
        compressionSettings = preset.compression;
        limiterSettings = preset.limiter;

        // Update filters
        prepare(currentSampleRate, 0, currentNumChannels);
    }
}

std::vector<std::string> StyleAwareMastering::getAvailablePresets() const
{
    std::vector<std::string> names;
    for (const auto& [name, preset] : presetDatabase)
        names.push_back(name);
    return names;
}

//==============================================================================
// Export

StyleAwareMastering::MasteringReport StyleAwareMastering::generateReport() const
{
    MasteringReport report;

    // Genre info
    switch (currentGenre)
    {
        case Genre::Pop: report.genre = "Pop"; break;
        case Genre::Rock: report.genre = "Rock"; break;
        case Genre::Electronic: report.genre = "Electronic"; break;
        case Genre::HipHop: report.genre = "Hip-Hop"; break;
        case Genre::Jazz: report.genre = "Jazz"; break;
        case Genre::Classical: report.genre = "Classical"; break;
        default: report.genre = "Custom"; break;
    }

    report.before = beforeMetrics;
    report.after = currentMetrics;

    // Applied processing
    for (const auto& module : masteringChain)
    {
        if (module.enabled)
            report.appliedProcessing.push_back(module.name);
    }

    // Recommendations
    if (currentMetrics.integratedLUFS < genreTargets.targetLUFS - 2.0f)
        report.recommendations += "Consider increasing overall gain. ";
    if (currentMetrics.integratedLUFS > genreTargets.targetLUFS + 2.0f)
        report.recommendations += "Mix is too loud for genre standards. ";
    if (currentMetrics.loudnessRange < 3.0f)
        report.recommendations += "Very compressed - consider preserving more dynamics. ";

    return report;
}

//==============================================================================
// Internal Processing

void StyleAwareMastering::loadGenreDefaults(Genre genre)
{
    currentGenre = genre;

    // Set genre-specific targets
    switch (genre)
    {
        case Genre::Pop:
            genreTargets.targetLUFS = -8.0f;
            genreTargets.targetLRA = 5.0f;
            genreTargets.targetPeak = -0.5f;
            genreTargets.tonalBalance = "Bright";
            genreTargets.dynamicRange = "Compressed";
            genreTargets.stereoWidth = "Wide";
            break;

        case Genre::Rock:
            genreTargets.targetLUFS = -9.0f;
            genreTargets.targetLRA = 7.0f;
            genreTargets.targetPeak = -0.5f;
            genreTargets.tonalBalance = "Balanced";
            genreTargets.dynamicRange = "Natural";
            genreTargets.stereoWidth = "Natural";
            break;

        case Genre::Electronic:
            genreTargets.targetLUFS = -7.0f;
            genreTargets.targetLRA = 4.0f;
            genreTargets.targetPeak = -0.3f;
            genreTargets.tonalBalance = "Bright";
            genreTargets.dynamicRange = "Compressed";
            genreTargets.stereoWidth = "Wide";
            break;

        case Genre::HipHop:
            genreTargets.targetLUFS = -8.5f;
            genreTargets.targetLRA = 5.0f;
            genreTargets.targetPeak = -0.5f;
            genreTargets.tonalBalance = "Warm";
            genreTargets.dynamicRange = "Compressed";
            genreTargets.stereoWidth = "Natural";
            break;

        case Genre::Jazz:
            genreTargets.targetLUFS = -14.0f;
            genreTargets.targetLRA = 12.0f;
            genreTargets.targetPeak = -1.0f;
            genreTargets.tonalBalance = "Warm";
            genreTargets.dynamicRange = "Dynamic";
            genreTargets.stereoWidth = "Natural";
            break;

        case Genre::Classical:
            genreTargets.targetLUFS = -18.0f;
            genreTargets.targetLRA = 15.0f;
            genreTargets.targetPeak = -1.0f;
            genreTargets.tonalBalance = "Balanced";
            genreTargets.dynamicRange = "Dynamic";
            genreTargets.stereoWidth = "Natural";
            break;

        default:
            genreTargets.targetLUFS = -10.0f;
            genreTargets.targetLRA = 8.0f;
            genreTargets.targetPeak = -0.5f;
            genreTargets.tonalBalance = "Balanced";
            genreTargets.dynamicRange = "Natural";
            genreTargets.stereoWidth = "Natural";
            break;
    }

    // Set default EQ
    eqSettings.lowShelfGain = (genreTargets.tonalBalance == "Warm") ? 1.5f : 0.0f;
    eqSettings.lowShelfFreq = 80.0f;
    eqSettings.midBoostGain = 0.5f;
    eqSettings.midBoostFreq = 2000.0f;
    eqSettings.highShelfGain = (genreTargets.tonalBalance == "Bright") ? 2.0f : 0.0f;
    eqSettings.highShelfFreq = 10000.0f;

    // Set default compression
    compressionSettings.threshold = -12.0f;
    compressionSettings.ratio = (genreTargets.dynamicRange == "Compressed") ? 4.0f : 2.0f;
    compressionSettings.attack = 5.0f;
    compressionSettings.release = 100.0f;
    compressionSettings.knee = 6.0f;
    compressionSettings.makeupGain = 3.0f;

    // Set default limiter
    limiterSettings.ceiling = genreTargets.targetPeak;
    limiterSettings.release = 50.0f;
    limiterSettings.ispDetection = true;

    // Build default mastering chain
    masteringChain.clear();

    ChainModule eqModule;
    eqModule.type = ChainModule::Type::EQ;
    eqModule.name = "Mastering EQ";
    eqModule.enabled = true;
    masteringChain.push_back(eqModule);

    ChainModule compModule;
    compModule.type = ChainModule::Type::Compression;
    compModule.name = "Bus Compressor";
    compModule.enabled = true;
    masteringChain.push_back(compModule);

    ChainModule limiterModule;
    limiterModule.type = ChainModule::Type::Limiting;
    limiterModule.name = "Mastering Limiter";
    limiterModule.enabled = true;
    masteringChain.push_back(limiterModule);
}

void StyleAwareMastering::initializePresets()
{
    // Create presets for each genre
    for (int g = 0; g < 10; ++g)
    {
        Genre genre = static_cast<Genre>(g);
        Preset preset;

        switch (genre)
        {
            case Genre::Pop: preset.name = "Modern Pop"; break;
            case Genre::Rock: preset.name = "Rock Master"; break;
            case Genre::Electronic: preset.name = "EDM Loud"; break;
            case Genre::HipHop: preset.name = "Hip-Hop Master"; break;
            case Genre::Jazz: preset.name = "Jazz Natural"; break;
            case Genre::Classical: preset.name = "Classical Dynamic"; break;
            default: continue;
        }

        preset.genre = genre;
        loadGenreDefaults(genre);
        preset.targets = genreTargets;
        preset.chain = masteringChain;
        preset.eq = eqSettings;
        preset.compression = compressionSettings;
        preset.limiter = limiterSettings;

        presetDatabase[preset.name] = preset;
    }
}

void StyleAwareMastering::processEQ(juce::AudioBuffer<float>& buffer)
{
    int numSamples = buffer.getNumSamples();
    float* left = buffer.getWritePointer(0);
    float* right = (buffer.getNumChannels() > 1) ? buffer.getWritePointer(1) : nullptr;

    for (int i = 0; i < numSamples; ++i)
    {
        // Process left channel through filter cascade
        float sample = left[i];
        sample = lowShelfFilter.processSample(sample, true);
        sample = midPeakFilter.processSample(sample, true);
        sample = highShelfFilter.processSample(sample, true);
        left[i] = sample;

        // Process right channel if stereo
        if (right)
        {
            sample = right[i];
            sample = lowShelfFilter.processSample(sample, false);
            sample = midPeakFilter.processSample(sample, false);
            sample = highShelfFilter.processSample(sample, false);
            right[i] = sample;
        }
    }
}

void StyleAwareMastering::processCompression(juce::AudioBuffer<float>& buffer)
{
    int numSamples = buffer.getNumSamples();
    float* left = buffer.getWritePointer(0);
    float* right = (buffer.getNumChannels() > 1) ? buffer.getWritePointer(1) : nullptr;

    for (int i = 0; i < numSamples; ++i)
    {
        left[i] = processCompressorSample(left[i], compressorL, compressionSettings);

        if (right)
            right[i] = processCompressorSample(right[i], compressorR, compressionSettings);
    }
}

void StyleAwareMastering::processLimiter(juce::AudioBuffer<float>& buffer)
{
    int numSamples = buffer.getNumSamples();
    float* left = buffer.getWritePointer(0);
    float* right = (buffer.getNumChannels() > 1) ? buffer.getWritePointer(1) : nullptr;

    // ✅ THREAD SAFETY: Using member variables instead of static (race condition fix)
    for (int i = 0; i < numSamples; ++i)
    {
        left[i] = processLimiterSample(left[i], limiterEnvelopeL, limiterSettings);

        if (right)
            right[i] = processLimiterSample(right[i], limiterEnvelopeR, limiterSettings);
    }
}

void StyleAwareMastering::analyzeMetrics(const juce::AudioBuffer<float>& buffer)
{
    if (buffer.getNumSamples() == 0)
        return;

    // Simplified LUFS calculation (actual would use K-weighted filter)
    float sumSquares = 0.0f;
    int numSamples = buffer.getNumSamples();

    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
    {
        const float* data = buffer.getReadPointer(ch);
        for (int i = 0; i < numSamples; ++i)
            sumSquares += data[i] * data[i];
    }

    float rms = std::sqrt(sumSquares / (numSamples * buffer.getNumChannels()));
    currentMetrics.integratedLUFS = -0.691f + 10.0f * std::log10(rms + 0.0001f);
    currentMetrics.shortTermLUFS = currentMetrics.integratedLUFS;

    // Simplified LRA
    currentMetrics.loudnessRange = 8.0f;

    // True peak
    currentMetrics.truePeakL = buffer.getMagnitude(0, 0, numSamples);
    if (buffer.getNumChannels() > 1)
        currentMetrics.truePeakR = buffer.getMagnitude(1, 0, numSamples);

    // Distance from target
    float lufsError = std::abs(currentMetrics.integratedLUFS - genreTargets.targetLUFS);
    currentMetrics.distanceFromTarget = lufsError / 10.0f;
}

void StyleAwareMastering::autoAdjustParameters()
{
    // Auto-adjust compression based on distance from target
    if (currentMetrics.distanceFromTarget > 0.3f)
    {
        if (currentMetrics.integratedLUFS < genreTargets.targetLUFS)
        {
            // Too quiet - increase makeup gain
            compressionSettings.makeupGain = juce::jmin(12.0f, compressionSettings.makeupGain + 0.5f);
        }
        else
        {
            // Too loud - decrease makeup gain
            compressionSettings.makeupGain = juce::jmax(0.0f, compressionSettings.makeupGain - 0.5f);
        }
    }
}

//==============================================================================
// Biquad Filter Implementation

void StyleAwareMastering::BiquadFilter::setLowShelf(float frequency, float gain, float sampleRate)
{
    float A = std::pow(10.0f, gain / 40.0f);
    float w0 = 2.0f * juce::MathConstants<float>::pi * frequency / sampleRate;
    float cosw0 = std::cos(w0);
    float sinw0 = std::sin(w0);
    float alpha = sinw0 / 2.0f * std::sqrt((A + 1.0f / A) * (1.0f / 0.707f - 1.0f) + 2.0f);

    float a0 = (A + 1.0f) + (A - 1.0f) * cosw0 + 2.0f * std::sqrt(A) * alpha;

    b0 = (A * ((A + 1.0f) - (A - 1.0f) * cosw0 + 2.0f * std::sqrt(A) * alpha)) / a0;
    b1 = (2.0f * A * ((A - 1.0f) - (A + 1.0f) * cosw0)) / a0;
    b2 = (A * ((A + 1.0f) - (A - 1.0f) * cosw0 - 2.0f * std::sqrt(A) * alpha)) / a0;
    a1 = (-2.0f * ((A - 1.0f) + (A + 1.0f) * cosw0)) / a0;
    a2 = ((A + 1.0f) + (A - 1.0f) * cosw0 - 2.0f * std::sqrt(A) * alpha) / a0;
}

void StyleAwareMastering::BiquadFilter::setHighShelf(float frequency, float gain, float sampleRate)
{
    float A = std::pow(10.0f, gain / 40.0f);
    float w0 = 2.0f * juce::MathConstants<float>::pi * frequency / sampleRate;
    float cosw0 = std::cos(w0);
    float sinw0 = std::sin(w0);
    float alpha = sinw0 / 2.0f * std::sqrt((A + 1.0f / A) * (1.0f / 0.707f - 1.0f) + 2.0f);

    float a0 = (A + 1.0f) - (A - 1.0f) * cosw0 + 2.0f * std::sqrt(A) * alpha;

    b0 = (A * ((A + 1.0f) + (A - 1.0f) * cosw0 + 2.0f * std::sqrt(A) * alpha)) / a0;
    b1 = (-2.0f * A * ((A - 1.0f) + (A + 1.0f) * cosw0)) / a0;
    b2 = (A * ((A + 1.0f) + (A - 1.0f) * cosw0 - 2.0f * std::sqrt(A) * alpha)) / a0;
    a1 = (2.0f * ((A - 1.0f) - (A + 1.0f) * cosw0)) / a0;
    a2 = ((A + 1.0f) - (A - 1.0f) * cosw0 - 2.0f * std::sqrt(A) * alpha) / a0;
}

void StyleAwareMastering::BiquadFilter::setPeak(float frequency, float gain, float Q, float sampleRate)
{
    float A = std::pow(10.0f, gain / 40.0f);
    float w0 = 2.0f * juce::MathConstants<float>::pi * frequency / sampleRate;
    float cosw0 = std::cos(w0);
    float sinw0 = std::sin(w0);
    float alpha = sinw0 / (2.0f * Q);

    float a0 = 1.0f + alpha / A;

    b0 = (1.0f + alpha * A) / a0;
    b1 = (-2.0f * cosw0) / a0;
    b2 = (1.0f - alpha * A) / a0;
    a1 = (-2.0f * cosw0) / a0;
    a2 = (1.0f - alpha / A) / a0;
}

float StyleAwareMastering::BiquadFilter::processSample(float input, bool isLeftChannel)
{
    float& z1 = isLeftChannel ? z1L : z1R;
    float& z2 = isLeftChannel ? z2L : z2R;

    float output = b0 * input + z1;
    z1 = b1 * input - a1 * output + z2;
    z2 = b2 * input - a2 * output;

    return output;
}

//==============================================================================
// Compression/Limiting

float StyleAwareMastering::processCompressorSample(float input, CompressorState& state, const CompressionSettings& settings)
{
    float inputLevel = std::abs(input);

    // Envelope follower
    float attackCoeff = std::exp(-1.0f / (settings.attack * 0.001f * currentSampleRate));
    float releaseCoeff = std::exp(-1.0f / (settings.release * 0.001f * currentSampleRate));

    if (inputLevel > state.envelope)
        state.envelope = attackCoeff * state.envelope + (1.0f - attackCoeff) * inputLevel;
    else
        state.envelope = releaseCoeff * state.envelope + (1.0f - releaseCoeff) * inputLevel;

    // Convert to dB
    float envelopeDB = 20.0f * std::log10(state.envelope + 0.0001f);

    // Calculate gain reduction
    float gainReductionDB = 0.0f;
    if (envelopeDB > settings.threshold)
    {
        float over = envelopeDB - settings.threshold;

        // Apply knee
        if (over < settings.knee)
            over = over * over / (2.0f * settings.knee);

        gainReductionDB = over * (1.0f - 1.0f / settings.ratio);
    }

    // Convert to linear gain
    state.gain = std::pow(10.0f, (-gainReductionDB + settings.makeupGain) / 20.0f);

    return input * state.gain;
}

float StyleAwareMastering::processLimiterSample(float input, float& envelope, const LimiterSettings& settings)
{
    float inputLevel = std::abs(input);
    float ceilingLinear = std::pow(10.0f, settings.ceiling / 20.0f);

    // Fast attack, variable release
    float attackCoeff = 0.999f;  // Very fast
    float releaseCoeff = std::exp(-1.0f / (settings.release * 0.001f * currentSampleRate));

    if (inputLevel > envelope)
        envelope = attackCoeff * envelope + (1.0f - attackCoeff) * inputLevel;
    else
        envelope = releaseCoeff * envelope + (1.0f - releaseCoeff) * inputLevel;

    // Calculate gain
    float gain = 1.0f;
    if (envelope > ceilingLinear)
        gain = ceilingLinear / envelope;

    return input * gain;
}
