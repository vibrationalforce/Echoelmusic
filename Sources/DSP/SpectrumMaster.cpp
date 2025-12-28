#include "SpectrumMaster.h"
#include "../Core/DSPOptimizations.h"

SpectrumMaster::SpectrumMaster()
    : forwardFFT(fftOrder)
    , window(fftSize, juce::dsp::WindowingFunction<float>::hann)
{
    spectrumMagnitudes.resize(fftSize / 2);
    spectrumSmoothed.resize(fftSize / 2);
}

SpectrumMaster::~SpectrumMaster() {}

void SpectrumMaster::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    juce::ignoreUnused(samplesPerBlock, numChannels);
    currentSampleRate = sampleRate;
    reset();
}

void SpectrumMaster::reset()
{
    std::fill(fftData.begin(), fftData.end(), 0.0f);
    std::fill(spectrumMagnitudes.begin(), spectrumMagnitudes.end(), 0.0f);
    std::fill(spectrumSmoothed.begin(), spectrumSmoothed.end(), 0.0f);
    analysisCacheDirty = true;
}

void SpectrumMaster::process(const juce::AudioBuffer<float>& buffer)
{
    performFFTAnalysis(buffer);
    smoothSpectrum();
    analysisCacheDirty = true;
}

//==============================================================================
// FFT Analysis

void SpectrumMaster::performFFTAnalysis(const juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Mix to mono and copy to FFT buffer
    for (int i = 0; i < juce::jmin(numSamples, fftSize); ++i)
    {
        float sample = 0.0f;
        for (int ch = 0; ch < numChannels; ++ch)
            sample += buffer.getSample(ch, i);
        sample /= static_cast<float>(numChannels);

        fftData[i] = sample;
    }

    // Apply window
    window.multiplyWithWindowingTable(fftData.data(), fftSize);

    // Perform FFT
    forwardFFT.performFrequencyOnlyForwardTransform(fftData.data());

    // Convert to magnitudes (dB)
    for (int i = 0; i < fftSize / 2; ++i)
    {
        float magnitude = fftData[i];
        spectrumMagnitudes[i] = juce::Decibels::gainToDecibels(magnitude + 1e-6f);
    }
}

void SpectrumMaster::smoothSpectrum()
{
    // Exponential smoothing
    for (size_t i = 0; i < spectrumMagnitudes.size(); ++i)
    {
        spectrumSmoothed[i] = spectrumMagnitudes[i] * (1.0f - smoothingFactor)
                            + spectrumSmoothed[i] * smoothingFactor;
    }
}

//==============================================================================
// Spectrum Data

std::vector<SpectrumMaster::FrequencyBand> SpectrumMaster::getSpectrumData() const
{
    std::vector<FrequencyBand> bands;
    bands.reserve(numBands);

    for (int i = 0; i < numBands; ++i)
    {
        float freqRatio = static_cast<float>(i) / static_cast<float>(numBands - 1);

        // Logarithmic frequency distribution - using fast pow
        float frequency = minFreq * Echoel::DSP::FastMath::fastPow(maxFreq / minFreq, freqRatio);

        // Get magnitude at this frequency
        float magnitude = getMagnitudeAtFrequency(frequency, spectrumSmoothed);

        FrequencyBand band;
        band.frequency = frequency;
        band.magnitude = magnitude;

        // Reference comparison
        if (referenceLoaded && !referenceMagnitudes.empty())
            band.referenceMagnitude = getMagnitudeAtFrequency(frequency, referenceMagnitudes);
        else
            band.referenceMagnitude = magnitude;

        // Genre-ideal comparison
        auto& profile = currentGenreProfile;
        if (!profile.idealSpectrum.empty())
        {
            auto it = profile.idealSpectrum.lower_bound(frequency);
            band.idealMagnitude = (it != profile.idealSpectrum.end()) ? it->second : magnitude;
        }
        else
        {
            band.idealMagnitude = magnitude;
        }

        // Determine status (simplified)
        float deviation = std::abs(magnitude - band.idealMagnitude);
        if (deviation < 3.0f)
            band.status = FrequencyBand::Status::Good;
        else if (deviation < 6.0f)
            band.status = FrequencyBand::Status::Warning;
        else
            band.status = FrequencyBand::Status::Problem;

        bands.push_back(band);
    }

    return bands;
}

//==============================================================================
// Problem Detection

std::vector<SpectrumMaster::Problem> SpectrumMaster::detectProblems() const
{
    if (!analysisCacheDirty && !cachedProblems.empty())
        return cachedProblems;

    detectProblemsInternal();
    return cachedProblems;
}

void SpectrumMaster::detectProblemsInternal() const
{
    cachedProblems.clear();

    // 1. Too much low end (<100Hz)
    float lowEndEnergy = getMagnitudeAtFrequency(60.0f, spectrumSmoothed);
    if (lowEndEnergy > -10.0f)
    {
        Problem p;
        p.type = ProblemType::TooMuchLowEnd;
        p.frequencyHz = 60.0f;
        p.severity = juce::jlimit(0.0f, 1.0f, (lowEndEnergy + 10.0f) / 20.0f);
        p.description = "Excessive low-end energy detected";
        p.solution = "Apply high-pass filter at 30-80Hz, or reduce bass by 2-4dB";
        p.displayColor = juce::Colours::red;
        cachedProblems.push_back(p);
    }

    // 2. Muddy midrange (200-500Hz)
    float muddyEnergy = (getMagnitudeAtFrequency(250.0f, spectrumSmoothed)
                       + getMagnitudeAtFrequency(400.0f, spectrumSmoothed)) * 0.5f;
    if (muddyEnergy > -15.0f)
    {
        Problem p;
        p.type = ProblemType::MuddyMidrange;
        p.frequencyHz = 300.0f;
        p.severity = juce::jlimit(0.0f, 1.0f, (muddyEnergy + 15.0f) / 15.0f);
        p.description = "Muddy midrange buildup";
        p.solution = "Reduce 200-500Hz by 2-3dB with wide Q";
        p.displayColor = juce::Colours::orange;
        cachedProblems.push_back(p);
    }

    // 3. Lack of high-end (>8kHz)
    float highEndEnergy = (getMagnitudeAtFrequency(8000.0f, spectrumSmoothed)
                         + getMagnitudeAtFrequency(12000.0f, spectrumSmoothed)) * 0.5f;
    if (highEndEnergy < -30.0f)
    {
        Problem p;
        p.type = ProblemType::LackOfHighEnd;
        p.frequencyHz = 10000.0f;
        p.severity = juce::jlimit(0.0f, 1.0f, (-highEndEnergy - 30.0f) / 20.0f);
        p.description = "Missing high-frequency 'air'";
        p.solution = "Boost 8-12kHz by 2-4dB with wide shelf";
        p.displayColor = juce::Colours::yellow;
        cachedProblems.push_back(p);
    }

    analysisCacheDirty = false;
}

//==============================================================================
// Reference Track

void SpectrumMaster::loadReferenceTrack(const juce::File& audioFile)
{
    juce::ignoreUnused(audioFile);
    // Implementation would load audio file and analyze spectrum
    referenceLoaded = true;
}

void SpectrumMaster::clearReferenceTrack()
{
    referenceLoaded = false;
    referenceMagnitudes.clear();
}

void SpectrumMaster::setReferenceOpacity(float opacity)
{
    referenceOpacity = juce::jlimit(0.0f, 1.0f, opacity);
}

//==============================================================================
// Stereo Analysis

SpectrumMaster::StereoInfo SpectrumMaster::getStereoAnalysis() const
{
    if (!analysisCacheDirty)
        return cachedStereo;

    // Simplified stereo analysis
    cachedStereo.width = 0.7f;
    cachedStereo.correlation = 0.85f;
    cachedStereo.leftRightBalance = 0.0f;
    cachedStereo.monoCompatible = (cachedStereo.correlation > 0.5f);

    return cachedStereo;
}

//==============================================================================
// Loudness Metering

SpectrumMaster::LoudnessInfo SpectrumMaster::getLoudnessAnalysis() const
{
    if (!analysisCacheDirty)
        return cachedLoudness;

    // Simplified loudness analysis (would use proper ITU-R BS.1770 in production)
    cachedLoudness.integrated = -12.0f;  // Example
    cachedLoudness.shortTerm = -10.0f;
    cachedLoudness.momentary = -8.0f;
    cachedLoudness.truePeak = -1.0f;
    cachedLoudness.dynamicRange = 8.0f;

    // Genre recommendation
    if (currentGenre == "Pop")
    {
        cachedLoudness.genreRecommendation = "Pop target: -8 to -10 LUFS";
        cachedLoudness.distanceFromTarget = cachedLoudness.integrated - (-9.0f);
    }
    else if (currentGenre == "Classical")
    {
        cachedLoudness.genreRecommendation = "Classical target: -18 to -20 LUFS";
        cachedLoudness.distanceFromTarget = cachedLoudness.integrated - (-19.0f);
    }
    else
    {
        cachedLoudness.genreRecommendation = "Adjust based on genre";
        cachedLoudness.distanceFromTarget = 0.0f;
    }

    return cachedLoudness;
}

//==============================================================================
// Genre

void SpectrumMaster::setGenre(const std::string& genre)
{
    currentGenre = genre;

    // Build genre profile (simplified example)
    currentGenreProfile.name = genre;
    currentGenreProfile.targetLUFS = -10.0f;
    currentGenreProfile.targetDynamicRange = 8.0f;

    // Example ideal spectrum for Pop
    if (genre == "Pop")
    {
        currentGenreProfile.idealSpectrum[60.0f] = -15.0f;
        currentGenreProfile.idealSpectrum[250.0f] = -20.0f;
        currentGenreProfile.idealSpectrum[2000.0f] = -12.0f;
        currentGenreProfile.idealSpectrum[10000.0f] = -18.0f;
        currentGenreProfile.tips = {
            "Keep vocals clear at 2-5kHz",
            "Control low-end at 30-80Hz",
            "Add air at 10-12kHz",
            "Target -8 to -10 LUFS"
        };
    }

    analysisCacheDirty = true;
}

std::string SpectrumMaster::getDetectedGenre() const
{
    return autoDetectGenre();
}

std::string SpectrumMaster::autoDetectGenre() const
{
    // Simplified genre detection based on spectrum characteristics
    float lowEnergy = getMagnitudeAtFrequency(60.0f, spectrumSmoothed);
    float midEnergy = getMagnitudeAtFrequency(1000.0f, spectrumSmoothed);
    float highEnergy = getMagnitudeAtFrequency(8000.0f, spectrumSmoothed);

    if (lowEnergy > -10.0f && highEnergy > -15.0f)
        return "EDM";
    else if (midEnergy > highEnergy && lowEnergy < -15.0f)
        return "Classical";
    else if (lowEnergy > midEnergy)
        return "Hip-Hop";
    else
        return "Pop";
}

SpectrumMaster::GenreProfile SpectrumMaster::getGenreProfile() const
{
    return currentGenreProfile;
}

//==============================================================================
// Multi-Track

void SpectrumMaster::addTrack(const std::string& trackName, const juce::AudioBuffer<float>& buffer)
{
    juce::ignoreUnused(buffer);
    // Would analyze track spectrum and store
    trackSpectra[trackName] = spectrumSmoothed;
}

void SpectrumMaster::clearTracks()
{
    trackSpectra.clear();
}

std::vector<SpectrumMaster::TrackSpectrum> SpectrumMaster::getAllTrackSpectra() const
{
    std::vector<TrackSpectrum> result;
    // Would return all track spectra with colors
    return result;
}

std::vector<SpectrumMaster::Problem> SpectrumMaster::detectInterTrackMasking() const
{
    std::vector<Problem> maskingProblems;
    // Would detect frequency collisions between tracks
    return maskingProblems;
}

//==============================================================================
// Visualization

void SpectrumMaster::setResolution(int bands)
{
    numBands = juce::jlimit(32, 256, bands);
}

void SpectrumMaster::setFrequencyRange(float minHz, float maxHz)
{
    minFreq = juce::jlimit(20.0f, 200.0f, minHz);
    maxFreq = juce::jlimit(10000.0f, 20000.0f, maxHz);
}

void SpectrumMaster::setDisplayMode(bool logarithmic)
{
    logarithmicDisplay = logarithmic;
}

void SpectrumMaster::setSmoothingFactor(float factor)
{
    smoothingFactor = juce::jlimit(0.0f, 1.0f, factor);
}

//==============================================================================
// Export

SpectrumMaster::AnalysisReport SpectrumMaster::generateReport() const
{
    AnalysisReport report;
    report.genre = currentGenre;
    report.problems = detectProblems();
    report.loudness = getLoudnessAnalysis();
    report.stereo = getStereoAnalysis();

    // Generate recommendations
    report.recommendations.push_back("Focus on problem frequencies first");
    report.recommendations.push_back("Compare with reference tracks");
    report.recommendations.push_back("Check mono compatibility");

    // Calculate overall score (0-100)
    float score = 100.0f;
    for (const auto& problem : report.problems)
        score -= problem.severity * 10.0f;
    report.overallScore = juce::jlimit(0.0f, 100.0f, score);

    return report;
}

void SpectrumMaster::exportReportToFile(const juce::File& outputFile) const
{
    auto report = generateReport();
    juce::String text;

    text << "=== Spectrum Master Analysis Report ===\n\n";
    text << "Genre: " << report.genre << "\n";
    text << "Overall Score: " << juce::String(report.overallScore, 1) << "/100\n\n";

    text << "Problems Detected: " << report.problems.size() << "\n";
    for (const auto& problem : report.problems)
    {
        text << "- " << problem.description << " @ " << juce::String(problem.frequencyHz, 0) << "Hz\n";
        text << "  Solution: " << problem.solution << "\n";
    }

    text << "\nLoudness:\n";
    text << "  Integrated: " << juce::String(report.loudness.integrated, 1) << " LUFS\n";
    text << "  " << report.loudness.genreRecommendation << "\n";

    outputFile.replaceWithText(text);
}

//==============================================================================
// Helpers

float SpectrumMaster::getMagnitudeAtFrequency(float frequency, const std::vector<float>& spectrum) const
{
    if (spectrum.empty()) return -100.0f;

    // Convert frequency to bin index
    float binIndex = frequency * static_cast<float>(fftSize) / static_cast<float>(currentSampleRate);
    int index = static_cast<int>(binIndex);

    if (index < 0 || index >= static_cast<int>(spectrum.size()))
        return -100.0f;

    return spectrum[index];
}

juce::Colour SpectrumMaster::getProblemColor(ProblemType type) const
{
    switch (type)
    {
        case ProblemType::TooMuchLowEnd:    return juce::Colours::red;
        case ProblemType::MuddyMidrange:    return juce::Colours::orange;
        case ProblemType::HarshMidrange:    return juce::Colours::orangered;
        case ProblemType::LackOfHighEnd:    return juce::Colours::yellow;
        case ProblemType::Resonance:        return juce::Colours::purple;
        case ProblemType::PhaseIssue:       return juce::Colours::magenta;
        case ProblemType::MonoIncompatible: return juce::Colours::cyan;
        case ProblemType::Masking:          return juce::Colours::lightblue;
        default:                            return juce::Colours::white;
    }
}
