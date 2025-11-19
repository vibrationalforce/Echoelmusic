#include "HybridSampleAnalyzer.h"
#include <cmath>
#include <algorithm>
#include <numeric>

//==============================================================================
// HybridSampleAnalyzer Implementation
//==============================================================================

HybridSampleAnalyzer::HybridSampleAnalyzer()
{
}

HybridSampleAnalyzer::~HybridSampleAnalyzer()
{
}

//==============================================================================
// Initialization
//==============================================================================

void HybridSampleAnalyzer::initialize(double sampleRate)
{
    currentSampleRate = sampleRate;
}

void HybridSampleAnalyzer::setSampleRate(double sampleRate)
{
    currentSampleRate = sampleRate;
}

//==============================================================================
// Sample Analysis
//==============================================================================

SynthesisModel HybridSampleAnalyzer::analyzeSample(
    const juce::AudioBuffer<float>& sample,
    const juce::String& name,
    bool keepOriginal)
{
    SynthesisModel model;
    model.name = name;
    model.sampleRate = currentSampleRate;
    model.duration = sample.getNumSamples() / (float)currentSampleRate;
    model.keepOriginal = keepOriginal;

    if (keepOriginal)
    {
        model.originalSample = sample;
    }

    // 1. Spectral Analysis
    model.spectral = analyzeSpectrum(sample);

    // 2. Envelope Analysis
    model.envelope = analyzeEnvelope(sample);

    // 3. Timbre Analysis
    model.timbre = analyzeTimbre(sample);

    // 4. Create Wavetable from harmonics
    model.wavetable = createWavetable(model.spectral, 2048);

    // 5. Determine category based on analysis
    if (model.spectral.fundamentalFreq < 100.0f && model.envelope.attack < 0.01f)
        model.category = "kick";
    else if (model.spectral.fundamentalFreq < 150.0f)
        model.category = "bass";
    else if (model.timbre.brightness > 0.7f && model.envelope.attack < 0.05f)
        model.category = "hihat";
    else if (model.spectral.inharmonicity > 0.5f)
        model.category = "snare";
    else
        model.category = "melodic";

    // 6. Evaluate quality
    model.analysisQuality = evaluateSynthesisQuality(model, sample);

    // 7. Calculate compression ratio
    model.compressionRatio = getCompressionRatio(model);

    // Store original pitch
    model.originalPitch = model.spectral.fundamentalFreq;

    return model;
}

//==============================================================================
// Spectral Analysis
//==============================================================================

SpectralAnalysis HybridSampleAnalyzer::analyzeSpectrum(
    const juce::AudioBuffer<float>& sample)
{
    SpectralAnalysis result;

    // Get mono mix
    std::vector<float> mono(sample.getNumSamples());
    for (int i = 0; i < sample.getNumSamples(); ++i)
    {
        float sum = 0.0f;
        for (int ch = 0; ch < sample.getNumChannels(); ++ch)
            sum += sample.getSample(ch, i);
        mono[i] = sum / sample.getNumChannels();
    }

    // Perform FFT
    std::vector<std::complex<float>> fftResult;
    performFFT(mono, fftResult);

    // Extract magnitude spectrum
    int numBins = fftResult.size() / 2;
    result.frequencies.resize(numBins);
    result.amplitudes.resize(numBins);
    result.phases.resize(numBins);

    for (int i = 0; i < numBins; ++i)
    {
        result.frequencies[i] = (i * currentSampleRate) / (2.0f * numBins);
        result.amplitudes[i] = std::abs(fftResult[i]);
        result.phases[i] = std::arg(fftResult[i]);
    }

    // Detect fundamental frequency
    result.fundamentalFreq = detectPitch(sample);

    // Extract harmonics
    if (result.fundamentalFreq > 0.0f)
    {
        extractHarmonics(sample, result.fundamentalFreq,
                        result.harmonics, result.harmonicAmps);
    }

    // Compute spectral features
    result.brightness = computeSpectralCentroid(result.amplitudes, result.frequencies);

    // Harmonic richness (ratio of harmonic to total energy)
    float harmonicEnergy = 0.0f;
    float totalEnergy = 0.0f;
    for (float amp : result.amplitudes)
        totalEnergy += amp * amp;
    for (float amp : result.harmonicAmps)
        harmonicEnergy += amp * amp;
    result.richness = (totalEnergy > 0.0f) ? (harmonicEnergy / totalEnergy) : 0.0f;

    // Inharmonicity (how much non-harmonic content)
    result.inharmonicity = 1.0f - result.richness;

    return result;
}

//==============================================================================
// Envelope Analysis
//==============================================================================

EnvelopeAnalysis HybridSampleAnalyzer::analyzeEnvelope(
    const juce::AudioBuffer<float>& sample)
{
    EnvelopeAnalysis result;

    // Extract envelope curve
    result.envelope = extractEnvelope(sample);

    if (result.envelope.empty())
        return result;

    // Find peak
    float peak = *std::max_element(result.envelope.begin(), result.envelope.end());
    result.peakAmplitude = peak;

    if (peak < 0.001f)
        return result;

    // Find attack time (time to reach 90% of peak)
    float attackThreshold = peak * 0.9f;
    int attackSamples = 0;
    for (size_t i = 0; i < result.envelope.size(); ++i)
    {
        if (result.envelope[i] >= attackThreshold)
        {
            attackSamples = i;
            break;
        }
    }
    result.attack = attackSamples / (float)currentSampleRate;

    // Find peak position
    int peakPos = std::distance(result.envelope.begin(),
                               std::max_element(result.envelope.begin(), result.envelope.end()));

    // Find sustain level (average of middle 20% of sound)
    int sustainStart = result.envelope.size() * 0.4f;
    int sustainEnd = result.envelope.size() * 0.6f;
    float sustainSum = 0.0f;
    int sustainCount = 0;
    for (int i = sustainStart; i < sustainEnd && i < (int)result.envelope.size(); ++i)
    {
        sustainSum += result.envelope[i];
        sustainCount++;
    }
    result.sustainAmplitude = (sustainCount > 0) ? (sustainSum / sustainCount) : 0.0f;
    result.sustain = result.sustainAmplitude / peak;

    // Find decay time (peak to sustain level)
    float decayThreshold = peak * result.sustain + (peak - peak * result.sustain) * 0.1f;
    int decaySamples = 0;
    for (int i = peakPos; i < (int)result.envelope.size(); ++i)
    {
        if (result.envelope[i] <= decayThreshold)
        {
            decaySamples = i - peakPos;
            break;
        }
    }
    result.decay = decaySamples / (float)currentSampleRate;

    // Find release time (last 20% of sound)
    int releaseStart = result.envelope.size() * 0.8f;
    float releaseStartLevel = result.envelope[releaseStart];
    result.release = (result.envelope.size() - releaseStart) / (float)currentSampleRate;

    // Clamp values
    result.attack = juce::jlimit(0.0f, 2.0f, result.attack);
    result.decay = juce::jlimit(0.0f, 5.0f, result.decay);
    result.sustain = juce::jlimit(0.0f, 1.0f, result.sustain);
    result.release = juce::jlimit(0.0f, 10.0f, result.release);

    return result;
}

//==============================================================================
// Timbre Analysis
//==============================================================================

TimbreAnalysis HybridSampleAnalyzer::analyzeTimbre(
    const juce::AudioBuffer<float>& sample)
{
    TimbreAnalysis result;

    // Get spectral analysis
    SpectralAnalysis spectral = analyzeSpectrum(sample);

    // Warmth: Low-frequency content (< 500 Hz)
    float lowEnergy = 0.0f;
    float midEnergy = 0.0f;
    float highEnergy = 0.0f;
    float totalEnergy = 0.0f;

    for (size_t i = 0; i < spectral.frequencies.size(); ++i)
    {
        float energy = spectral.amplitudes[i] * spectral.amplitudes[i];
        totalEnergy += energy;

        if (spectral.frequencies[i] < 500.0f)
            lowEnergy += energy;
        else if (spectral.frequencies[i] < 2000.0f)
            midEnergy += energy;
        else
            highEnergy += energy;
    }

    if (totalEnergy > 0.0f)
    {
        result.warmth = lowEnergy / totalEnergy;
        result.presence = midEnergy / totalEnergy;
        result.brightness = highEnergy / totalEnergy;
    }

    // Attack character: Rate of initial amplitude rise
    EnvelopeAnalysis env = analyzeEnvelope(sample);
    result.attack = (env.attack > 0.0f) ? juce::jlimit(0.0f, 1.0f, 1.0f - env.attack) : 0.5f;

    // Body: Mid-frequency fullness
    result.body = result.presence;

    // Tail: Decay/release character
    result.tail = juce::jlimit(0.0f, 1.0f, env.release / 5.0f);

    // Analog character: Inharmonicity + low-frequency content
    result.analogCharacter = (spectral.inharmonicity * 0.3f) + (result.warmth * 0.7f);

    // Digital character: High harmonic richness + brightness
    result.digitalCharacter = (spectral.richness * 0.5f) + (result.brightness * 0.5f);

    return result;
}

//==============================================================================
// Pitch Detection
//==============================================================================

float HybridSampleAnalyzer::detectPitch(const juce::AudioBuffer<float>& sample)
{
    // Get mono mix
    std::vector<float> mono(sample.getNumSamples());
    for (int i = 0; i < sample.getNumSamples(); ++i)
    {
        float sum = 0.0f;
        for (int ch = 0; ch < sample.getNumChannels(); ++ch)
            sum += sample.getSample(ch, i);
        mono[i] = sum / sample.getNumChannels();
    }

    return detectPitchYIN(mono);
}

void HybridSampleAnalyzer::extractHarmonics(
    const juce::AudioBuffer<float>& sample,
    float fundamentalFreq,
    std::vector<float>& harmonics,
    std::vector<float>& amplitudes)
{
    harmonics.clear();
    amplitudes.clear();

    // Get spectral analysis
    SpectralAnalysis spectral = analyzeSpectrum(sample);

    // Extract up to 16 harmonics
    for (int h = 1; h <= 16; ++h)
    {
        float targetFreq = fundamentalFreq * h;

        // Find closest bin
        int closestBin = -1;
        float closestDist = std::numeric_limits<float>::max();

        for (size_t i = 0; i < spectral.frequencies.size(); ++i)
        {
            float dist = std::abs(spectral.frequencies[i] - targetFreq);
            if (dist < closestDist)
            {
                closestDist = dist;
                closestBin = i;
            }
        }

        if (closestBin >= 0 && isHarmonic(spectral.frequencies[closestBin], fundamentalFreq, 0.05f))
        {
            harmonics.push_back(spectral.frequencies[closestBin]);
            amplitudes.push_back(spectral.amplitudes[closestBin]);
        }
    }
}

//==============================================================================
// Model Creation
//==============================================================================

std::vector<float> HybridSampleAnalyzer::createWavetable(
    const SpectralAnalysis& spectral,
    int tableSize)
{
    std::vector<float> wavetable(tableSize, 0.0f);

    if (spectral.harmonics.empty() || spectral.fundamentalFreq <= 0.0f)
    {
        // No harmonics detected - use sine wave
        for (int i = 0; i < tableSize; ++i)
        {
            float phase = (i / (float)tableSize) * 2.0f * juce::MathConstants<float>::pi;
            wavetable[i] = std::sin(phase);
        }
        return wavetable;
    }

    // Synthesize from harmonics
    for (size_t h = 0; h < spectral.harmonics.size(); ++h)
    {
        float harmonic = spectral.harmonics[h];
        float amplitude = spectral.harmonicAmps[h];
        float ratio = harmonic / spectral.fundamentalFreq;

        for (int i = 0; i < tableSize; ++i)
        {
            float phase = (i / (float)tableSize) * 2.0f * juce::MathConstants<float>::pi * ratio;
            wavetable[i] += amplitude * std::sin(phase);
        }
    }

    // Normalize
    float maxVal = *std::max_element(wavetable.begin(), wavetable.end());
    float minVal = *std::min_element(wavetable.begin(), wavetable.end());
    float range = std::max(std::abs(maxVal), std::abs(minVal));

    if (range > 0.0f)
    {
        for (float& sample : wavetable)
            sample /= range;
    }

    return wavetable;
}

float HybridSampleAnalyzer::evaluateSynthesisQuality(
    const SynthesisModel& model,
    const juce::AudioBuffer<float>& original)
{
    float quality = 0.0f;
    int criteria = 0;

    // 1. Spectral quality (do we have harmonics?)
    if (!model.spectral.harmonics.empty())
    {
        quality += 0.2f;
        criteria++;
    }

    // 2. Pitch detection quality
    if (model.spectral.fundamentalFreq > 20.0f && model.spectral.fundamentalFreq < 20000.0f)
    {
        quality += 0.2f;
        criteria++;
    }

    // 3. Envelope quality
    if (model.envelope.attack >= 0.0f && model.envelope.decay >= 0.0f)
    {
        quality += 0.2f;
        criteria++;
    }

    // 4. Timbre analysis quality
    if (model.timbre.warmth + model.timbre.brightness + model.timbre.presence > 0.1f)
    {
        quality += 0.2f;
        criteria++;
    }

    // 5. Wavetable quality
    if (!model.wavetable.empty())
    {
        quality += 0.2f;
        criteria++;
    }

    return quality;
}

//==============================================================================
// Synthesis from Model
//==============================================================================

juce::AudioBuffer<float> HybridSampleAnalyzer::synthesizeFromModel(
    const SynthesisModel& model,
    float pitch,
    float duration,
    const AnalogBehavior& analog)
{
    // Use original pitch if not specified
    if (pitch == 0.0f)
        pitch = model.originalPitch;

    // Use original duration if not specified
    if (duration == 0.0f)
        duration = model.duration;

    int numSamples = duration * currentSampleRate;
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    // Synthesize from wavetable
    float phase = 0.0f;
    float phaseIncrement = pitch / (float)currentSampleRate;

    for (int i = 0; i < numSamples; ++i)
    {
        // Get wavetable sample
        float tablePos = phase * model.wavetable.size();
        int index = (int)tablePos;
        float frac = tablePos - index;

        // Linear interpolation
        float sample1 = model.wavetable[index % model.wavetable.size()];
        float sample2 = model.wavetable[(index + 1) % model.wavetable.size()];
        float sample = sample1 + frac * (sample2 - sample1);

        // Apply envelope
        float time = i / (float)currentSampleRate;
        float env = 1.0f;

        if (time < model.envelope.attack)
            env = time / model.envelope.attack;
        else if (time < model.envelope.attack + model.envelope.decay)
            env = 1.0f - (1.0f - model.envelope.sustain) *
                  ((time - model.envelope.attack) / model.envelope.decay);
        else if (time > duration - model.envelope.release)
            env = model.envelope.sustain *
                  (1.0f - (time - (duration - model.envelope.release)) / model.envelope.release);
        else
            env = model.envelope.sustain;

        sample *= env;

        // Write to both channels
        buffer.setSample(0, i, sample);
        buffer.setSample(1, i, sample);

        // Advance phase
        phase += phaseIncrement;
        if (phase >= 1.0f)
            phase -= 1.0f;
    }

    return buffer;
}

//==============================================================================
// Batch Processing
//==============================================================================

std::vector<SynthesisModel> HybridSampleAnalyzer::analyzeSampleLibrary(
    const juce::Array<juce::File>& sampleFiles,
    std::function<void(int, int)> progressCallback)
{
    std::vector<SynthesisModel> models;
    models.reserve(sampleFiles.size());

    for (int i = 0; i < sampleFiles.size(); ++i)
    {
        const auto& file = sampleFiles[i];

        // Load audio file
        juce::AudioFormatManager formatManager;
        formatManager.registerBasicFormats();

        auto* reader = formatManager.createReaderFor(file);
        if (reader != nullptr)
        {
            juce::AudioBuffer<float> buffer(reader->numChannels, (int)reader->lengthInSamples);
            reader->read(&buffer, 0, (int)reader->lengthInSamples, 0, true, true);

            // Analyze
            auto model = analyzeSample(buffer, file.getFileNameWithoutExtension(), false);
            models.push_back(model);

            delete reader;
        }

        // Progress callback
        if (progressCallback)
            progressCallback(i + 1, sampleFiles.size());
    }

    return models;
}

std::vector<SynthesisModel> HybridSampleAnalyzer::selectBestSamples(
    const std::vector<SynthesisModel>& models,
    int maxCount)
{
    // Create scored list
    std::vector<std::pair<float, SynthesisModel>> scored;
    scored.reserve(models.size());

    for (const auto& model : models)
    {
        float score = model.analysisQuality;
        scored.push_back({score, model});
    }

    // Sort by score (descending)
    std::sort(scored.begin(), scored.end(),
             [](const auto& a, const auto& b) { return a.first > b.first; });

    // Take top N
    std::vector<SynthesisModel> result;
    result.reserve(maxCount);

    for (int i = 0; i < maxCount && i < (int)scored.size(); ++i)
    {
        result.push_back(scored[i].second);
    }

    return result;
}

//==============================================================================
// I/O
//==============================================================================

bool HybridSampleAnalyzer::saveModel(const SynthesisModel& model, const juce::File& file)
{
    juce::XmlElement xml("SynthesisModel");

    xml.setAttribute("name", model.name);
    xml.setAttribute("category", model.category);
    xml.setAttribute("originalPitch", model.originalPitch);
    xml.setAttribute("sampleRate", model.sampleRate);
    xml.setAttribute("duration", model.duration);
    xml.setAttribute("analysisQuality", model.analysisQuality);
    xml.setAttribute("compressionRatio", model.compressionRatio);

    // Save wavetable
    auto* wavetableXml = xml.createNewChildElement("Wavetable");
    juce::String wavetableData;
    for (float sample : model.wavetable)
        wavetableData += juce::String(sample) + " ";
    wavetableXml->setAttribute("data", wavetableData);

    // Save envelope
    auto* envXml = xml.createNewChildElement("Envelope");
    envXml->setAttribute("attack", model.envelope.attack);
    envXml->setAttribute("decay", model.envelope.decay);
    envXml->setAttribute("sustain", model.envelope.sustain);
    envXml->setAttribute("release", model.envelope.release);

    return xml.writeTo(file);
}

SynthesisModel HybridSampleAnalyzer::loadModel(const juce::File& file)
{
    SynthesisModel model;

    auto xml = juce::XmlDocument::parse(file);
    if (xml == nullptr)
        return model;

    model.name = xml->getStringAttribute("name");
    model.category = xml->getStringAttribute("category");
    model.originalPitch = xml->getDoubleAttribute("originalPitch");
    model.sampleRate = xml->getDoubleAttribute("sampleRate");
    model.duration = xml->getDoubleAttribute("duration");
    model.analysisQuality = xml->getDoubleAttribute("analysisQuality");
    model.compressionRatio = xml->getDoubleAttribute("compressionRatio");

    // Load wavetable
    auto* wavetableXml = xml->getChildByName("Wavetable");
    if (wavetableXml)
    {
        juce::String data = wavetableXml->getStringAttribute("data");
        juce::StringArray tokens;
        tokens.addTokens(data, " ", "");

        model.wavetable.clear();
        for (const auto& token : tokens)
            model.wavetable.push_back(token.getFloatValue());
    }

    // Load envelope
    auto* envXml = xml->getChildByName("Envelope");
    if (envXml)
    {
        model.envelope.attack = envXml->getDoubleAttribute("attack");
        model.envelope.decay = envXml->getDoubleAttribute("decay");
        model.envelope.sustain = envXml->getDoubleAttribute("sustain");
        model.envelope.release = envXml->getDoubleAttribute("release");
    }

    return model;
}

bool HybridSampleAnalyzer::saveLibrary(
    const std::vector<SynthesisModel>& models,
    const juce::File& directory)
{
    if (!directory.exists())
        directory.createDirectory();

    for (const auto& model : models)
    {
        juce::File file = directory.getChildFile(model.name + ".xml");
        if (!saveModel(model, file))
            return false;
    }

    return true;
}

//==============================================================================
// Utilities
//==============================================================================

size_t HybridSampleAnalyzer::getModelSize(const SynthesisModel& model) const
{
    size_t size = 0;

    // Wavetable
    size += model.wavetable.size() * sizeof(float);

    // Spectral data
    size += model.spectral.frequencies.size() * sizeof(float);
    size += model.spectral.amplitudes.size() * sizeof(float);
    size += model.spectral.phases.size() * sizeof(float);
    size += model.spectral.harmonics.size() * sizeof(float);
    size += model.spectral.harmonicAmps.size() * sizeof(float);

    // Envelope
    size += model.envelope.envelope.size() * sizeof(float);
    size += sizeof(EnvelopeAnalysis);

    // Timbre
    size += sizeof(TimbreAnalysis);

    // Metadata
    size += 256; // Approximate for strings and other data

    return size;
}

float HybridSampleAnalyzer::getCompressionRatio(const SynthesisModel& model) const
{
    size_t modelSize = getModelSize(model);
    size_t originalSize = model.duration * currentSampleRate * 2 * sizeof(float); // Stereo

    if (originalSize == 0)
        return 0.0f;

    return (float)modelSize / (float)originalSize;
}

//==============================================================================
// DSP Helpers
//==============================================================================

void HybridSampleAnalyzer::performFFT(
    const std::vector<float>& input,
    std::vector<std::complex<float>>& output)
{
    int size = juce::nextPowerOfTwo((int)input.size());
    size = std::min(size, fftSize);

    output.resize(size);

    // Simple DFT (for demonstration - should use proper FFT library in production)
    for (int k = 0; k < size; ++k)
    {
        std::complex<float> sum(0.0f, 0.0f);
        for (int n = 0; n < std::min((int)input.size(), size); ++n)
        {
            float angle = -2.0f * juce::MathConstants<float>::pi * k * n / size;
            sum += input[n] * std::complex<float>(std::cos(angle), std::sin(angle));
        }
        output[k] = sum;
    }
}

void HybridSampleAnalyzer::performIFFT(
    const std::vector<std::complex<float>>& input,
    std::vector<float>& output)
{
    int size = input.size();
    output.resize(size);

    // Simple IDFT
    for (int n = 0; n < size; ++n)
    {
        std::complex<float> sum(0.0f, 0.0f);
        for (int k = 0; k < size; ++k)
        {
            float angle = 2.0f * juce::MathConstants<float>::pi * k * n / size;
            sum += input[k] * std::complex<float>(std::cos(angle), std::sin(angle));
        }
        output[n] = sum.real() / size;
    }
}

float HybridSampleAnalyzer::detectPitchYIN(const std::vector<float>& samples)
{
    // YIN pitch detection algorithm
    int minPeriod = currentSampleRate / 1000.0f; // 1000 Hz max
    int maxPeriod = currentSampleRate / 40.0f;   // 40 Hz min

    std::vector<float> difference(maxPeriod);

    // Calculate difference function
    for (int tau = minPeriod; tau < maxPeriod; ++tau)
    {
        float sum = 0.0f;
        int count = std::min((int)samples.size() - tau, 1024);

        for (int i = 0; i < count; ++i)
        {
            float delta = samples[i] - samples[i + tau];
            sum += delta * delta;
        }

        difference[tau] = sum / count;
    }

    // Find minimum
    int bestPeriod = minPeriod;
    float minDiff = difference[minPeriod];

    for (int tau = minPeriod + 1; tau < maxPeriod; ++tau)
    {
        if (difference[tau] < minDiff)
        {
            minDiff = difference[tau];
            bestPeriod = tau;
        }
    }

    // Convert period to frequency
    if (bestPeriod > 0)
        return currentSampleRate / bestPeriod;

    return 0.0f;
}

std::vector<float> HybridSampleAnalyzer::extractEnvelope(
    const juce::AudioBuffer<float>& sample)
{
    int hopSize = 512;
    int numHops = sample.getNumSamples() / hopSize;

    std::vector<float> envelope(numHops);

    for (int hop = 0; hop < numHops; ++hop)
    {
        float rms = 0.0f;
        int start = hop * hopSize;
        int end = std::min(start + hopSize, sample.getNumSamples());

        for (int i = start; i < end; ++i)
        {
            for (int ch = 0; ch < sample.getNumChannels(); ++ch)
            {
                float s = sample.getSample(ch, i);
                rms += s * s;
            }
        }

        rms = std::sqrt(rms / ((end - start) * sample.getNumChannels()));
        envelope[hop] = rms;
    }

    return envelope;
}

float HybridSampleAnalyzer::computeSpectralCentroid(
    const std::vector<float>& spectrum,
    const std::vector<float>& frequencies)
{
    float weightedSum = 0.0f;
    float sum = 0.0f;

    for (size_t i = 0; i < spectrum.size() && i < frequencies.size(); ++i)
    {
        weightedSum += frequencies[i] * spectrum[i];
        sum += spectrum[i];
    }

    if (sum > 0.0f)
        return weightedSum / sum;

    return 0.0f;
}

float HybridSampleAnalyzer::computeSpectralRolloff(
    const std::vector<float>& spectrum,
    float threshold)
{
    float totalEnergy = 0.0f;
    for (float amp : spectrum)
        totalEnergy += amp;

    float cumulativeEnergy = 0.0f;
    float targetEnergy = totalEnergy * threshold;

    for (size_t i = 0; i < spectrum.size(); ++i)
    {
        cumulativeEnergy += spectrum[i];
        if (cumulativeEnergy >= targetEnergy)
            return i / (float)spectrum.size();
    }

    return 1.0f;
}

bool HybridSampleAnalyzer::isHarmonic(float freq, float fundamental, float tolerance)
{
    if (fundamental <= 0.0f)
        return false;

    float ratio = freq / fundamental;
    float nearestHarmonic = std::round(ratio);
    float error = std::abs(ratio - nearestHarmonic) / nearestHarmonic;

    return error < tolerance;
}

//==============================================================================
// HybridSynthesisEngine Implementation
//==============================================================================

HybridSynthesisEngine::HybridSynthesisEngine()
{
}

HybridSynthesisEngine::~HybridSynthesisEngine()
{
}

void HybridSynthesisEngine::initialize(double sampleRate)
{
    currentSampleRate = sampleRate;
}

void HybridSynthesisEngine::loadLibrary(const std::vector<SynthesisModel>& models)
{
    modelLibrary.clear();

    for (const auto& model : models)
    {
        modelLibrary[model.name] = model;
    }
}

const SynthesisModel* HybridSynthesisEngine::getModel(const juce::String& name) const
{
    auto it = modelLibrary.find(name);
    if (it != modelLibrary.end())
        return &it->second;

    return nullptr;
}

juce::AudioBuffer<float> HybridSynthesisEngine::synthesize(
    const juce::String& modelName,
    float pitch,
    const AnalogBehavior& analog)
{
    auto* model = getModel(modelName);
    if (model == nullptr)
        return juce::AudioBuffer<float>(2, 0);

    // Synthesize from wavetable
    float duration = model->duration;
    int numSamples = duration * currentSampleRate;
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    // Wavetable synthesis
    float phase = 0.0f;
    float phaseIncrement = pitch / (float)currentSampleRate;

    for (int i = 0; i < numSamples; ++i)
    {
        // Get wavetable sample
        float tablePos = phase * model->wavetable.size();
        int index = (int)tablePos;
        float frac = tablePos - index;

        float sample1 = model->wavetable[index % model->wavetable.size()];
        float sample2 = model->wavetable[(index + 1) % model->wavetable.size()];
        float sample = sample1 + frac * (sample2 - sample1);

        // Apply envelope
        float time = i / (float)currentSampleRate;
        float env = 1.0f;

        if (time < model->envelope.attack)
            env = time / model->envelope.attack;
        else if (time < model->envelope.attack + model->envelope.decay)
            env = 1.0f - (1.0f - model->envelope.sustain) *
                  ((time - model->envelope.attack) / model->envelope.decay);
        else if (time > duration - model->envelope.release)
            env = model->envelope.sustain *
                  (1.0f - (time - (duration - model->envelope.release)) / model->envelope.release);
        else
            env = model->envelope.sustain;

        sample *= env;

        buffer.setSample(0, i, sample);
        buffer.setSample(1, i, sample);

        phase += phaseIncrement;
        if (phase >= 1.0f)
            phase -= 1.0f;
    }

    // Apply analog behavior
    applyAnalogBehavior(buffer, analog);

    return buffer;
}

void HybridSynthesisEngine::applyAnalogBehavior(
    juce::AudioBuffer<float>& audio,
    const AnalogBehavior& analog)
{
    if (analog.tape.enabled)
        applyTapeSaturation(audio, analog.tape);

    if (analog.tube.enabled)
        applyTubeWarmth(audio, analog.tube);

    if (analog.vintage.enabled)
        applyVintageCharacter(audio, analog.vintage);
}

void HybridSynthesisEngine::applyTapeSaturation(
    juce::AudioBuffer<float>& audio,
    const AnalogBehavior::Tape& tape)
{
    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        auto* data = audio.getWritePointer(ch);

        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            float sample = data[i];

            // Soft saturation (tanh)
            sample = std::tanh(sample * (1.0f + tape.saturation * 2.0f));

            // Warmth (low-frequency boost) - simple shelf filter approximation
            static float lpState = 0.0f;
            float cutoff = 0.01f;
            lpState += cutoff * (sample - lpState);
            sample += lpState * tape.warmth * 0.3f;

            // High-frequency rolloff
            static float hfState = 0.0f;
            float hfCutoff = 0.3f * (1.0f - tape.hfRolloff);
            hfState += hfCutoff * (sample - hfState);
            sample = hfState;

            data[i] = sample;
        }
    }
}

void HybridSynthesisEngine::applyTubeWarmth(
    juce::AudioBuffer<float>& audio,
    const AnalogBehavior::Tube& tube)
{
    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        auto* data = audio.getWritePointer(ch);

        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            float sample = data[i];

            // Asymmetric waveshaping (tube characteristic)
            float driven = sample * (1.0f + tube.drive * 3.0f);

            // Bias adds DC offset before saturation
            driven += tube.bias * 0.2f;

            // Asymmetric saturation
            float saturated;
            if (driven >= 0.0f)
                saturated = std::tanh(driven * (1.0f + tube.asymmetry));
            else
                saturated = std::tanh(driven * (1.0f - tube.asymmetry * 0.5f));

            // Remove DC bias
            saturated -= tube.bias * 0.2f;

            data[i] = saturated;
        }
    }
}

void HybridSynthesisEngine::applyVintageCharacter(
    juce::AudioBuffer<float>& audio,
    const AnalogBehavior::Vintage& vintage)
{
    std::mt19937 rng(42);
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);

    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        auto* data = audio.getWritePointer(ch);

        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            float sample = data[i];

            // Background noise
            sample += dist(rng) * vintage.noise * 0.01f;

            // Pitch drift (slight modulation)
            // Simplified - in production would use interpolated delay line

            // Component aging (slight high-frequency loss)
            static float agingState = 0.0f;
            float agingCutoff = 0.5f * (1.0f - vintage.aging * 0.3f);
            agingState += agingCutoff * (sample - agingState);
            sample = agingState;

            data[i] = sample;
        }
    }
}
