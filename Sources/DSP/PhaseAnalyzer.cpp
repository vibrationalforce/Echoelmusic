#include "PhaseAnalyzer.h"
#include <cmath>
#include <algorithm>

//==============================================================================
// PhaseAnalyzer Implementation

PhaseAnalyzer::PhaseAnalyzer()
    : forwardFFT(fftOrder),
      window(fftSize, juce::dsp::WindowingFunction<float>::hann)
{
    correlationHistory.maxSize = 1000;
    correlationHistory.timePerSample = 0.1;  // 100ms per sample
    reset();
}

PhaseAnalyzer::~PhaseAnalyzer() {}

void PhaseAnalyzer::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    currentSampleRate = sampleRate;
    currentNumChannels = numChannels;

    correlationHistory.timePerSample = samplesPerBlock / sampleRate;
}

void PhaseAnalyzer::reset()
{
    instantCorrelation = 1.0f;
    shortTermCorrelation = 1.0f;
    longTermCorrelation = 1.0f;
    minCorrelation = 1.0f;
    maxCorrelation = 1.0f;

    goniometerHistory.clear();
    correlationHistory.values.clear();
    detectedIssues.clear();
    frequencyPhaseData.clear();
}

void PhaseAnalyzer::process(const juce::AudioBuffer<float>& buffer)
{
    if (buffer.getNumChannels() < 2)
        return;

    calculatePhaseCorrelation(buffer);
    updateGoniometer(buffer);
    performFFTAnalysis(buffer);
    analyzeFrequencyPhase();
    detectIssues();
    calculateMonoCompatibility();
}

//==============================================================================
// Phase Correlation

PhaseAnalyzer::PhaseCorrelation PhaseAnalyzer::getPhaseCorrelation() const
{
    PhaseCorrelation corr;
    corr.instant = instantCorrelation;
    corr.shortTerm = shortTermCorrelation;
    corr.longTerm = longTermCorrelation;
    corr.minimum = minCorrelation;
    corr.maximum = maxCorrelation;
    corr.monoCompatible = longTermCorrelation > monoCompatibilityThreshold;
    corr.hasPhaseIssues = longTermCorrelation < 0.0f;
    return corr;
}

//==============================================================================
// Goniometer

std::vector<PhaseAnalyzer::GoniometerPoint> PhaseAnalyzer::getGoniometerData(int maxPoints) const
{
    int numPoints = juce::jmin(maxPoints, static_cast<int>(goniometerHistory.size()));
    std::vector<GoniometerPoint> points;

    for (int i = goniometerHistory.size() - numPoints; i < static_cast<int>(goniometerHistory.size()); ++i)
        points.push_back(goniometerHistory[i]);

    return points;
}

void PhaseAnalyzer::clearGoniometerHistory()
{
    goniometerHistory.clear();
}

//==============================================================================
// Frequency Phase Analysis

std::vector<PhaseAnalyzer::FrequencyPhase> PhaseAnalyzer::getFrequencyPhaseAnalysis() const
{
    return frequencyPhaseData;
}

//==============================================================================
// Phase Issues

std::vector<PhaseAnalyzer::PhaseIssue> PhaseAnalyzer::detectPhaseIssues() const
{
    return detectedIssues;
}

//==============================================================================
// Mono Compatibility

PhaseAnalyzer::MonoCompatibility PhaseAnalyzer::getMonoCompatibility() const
{
    return monoCompat;
}

//==============================================================================
// Auto-Fix Suggestions

std::vector<PhaseAnalyzer::FixSuggestion> PhaseAnalyzer::getAutoFixSuggestions() const
{
    std::vector<FixSuggestion> suggestions;

    // Polarity flip suggestion
    if (longTermCorrelation < -0.5f)
    {
        FixSuggestion flip;
        flip.type = "Flip polarity";
        flip.description = "One channel appears to be inverted. Flip the polarity of one channel.";
        flip.expectedImprovement = 0.9f;
        flip.autoApply = true;
        flip.parameters["channel"] = 1.0f;  // Flip right channel
        suggestions.push_back(flip);
    }

    // Mid/Side EQ suggestion
    if (monoCompat.lowFreqScore < 0.5f)
    {
        FixSuggestion midSideEQ;
        midSideEQ.type = "Mid/Side EQ";
        midSideEQ.description = "Low frequencies have phase issues. Apply mid/side EQ to center bass.";
        midSideEQ.expectedImprovement = 0.6f;
        midSideEQ.autoApply = false;
        midSideEQ.parameters["frequency"] = 150.0f;
        midSideEQ.parameters["boost_mid"] = 2.0f;
        midSideEQ.parameters["cut_side"] = -3.0f;
        suggestions.push_back(midSideEQ);
    }

    // Phase rotation suggestion
    if (monoCompat.overallScore < 0.6f && longTermCorrelation > 0.0f)
    {
        FixSuggestion phaseRot;
        phaseRot.type = "Phase rotation";
        phaseRot.description = "Apply linear-phase rotation to align stereo image.";
        phaseRot.expectedImprovement = 0.4f;
        phaseRot.autoApply = false;
        suggestions.push_back(phaseRot);
    }

    return suggestions;
}

//==============================================================================
// Settings

void PhaseAnalyzer::setCorrelationMeterSpeed(float speed)
{
    correlationMeterSpeed = juce::jlimit(0.0f, 1.0f, speed);
    correlationAlpha = 0.01f + correlationMeterSpeed * 0.3f;
}

void PhaseAnalyzer::setGoniometerPersistence(float seconds)
{
    goniometerPersistence = juce::jlimit(0.1f, 10.0f, seconds);
    maxGoniometerPoints = static_cast<int>(seconds * currentSampleRate / 512);
}

void PhaseAnalyzer::setFrequencyResolution(int bands)
{
    frequencyResolution = juce::jlimit(12, 48, bands);
}

void PhaseAnalyzer::setMonoCompatibilityThreshold(float threshold)
{
    monoCompatibilityThreshold = juce::jlimit(0.0f, 1.0f, threshold);
}

//==============================================================================
// Visualization Data

PhaseAnalyzer::CorrelationHistory PhaseAnalyzer::getCorrelationHistory() const
{
    return correlationHistory;
}

//==============================================================================
// Internal Analysis

void PhaseAnalyzer::calculatePhaseCorrelation(const juce::AudioBuffer<float>& buffer)
{
    const float* left = buffer.getReadPointer(0);
    const float* right = buffer.getReadPointer(1);
    int numSamples = buffer.getNumSamples();

    // Calculate instant correlation
    instantCorrelation = calculateCorrelationCoefficient(left, right, numSamples);

    // Update short-term (fast smoothing)
    float shortAlpha = 0.2f;
    shortTermCorrelation = shortAlpha * instantCorrelation + (1.0f - shortAlpha) * shortTermCorrelation;

    // Update long-term (slow smoothing)
    float longAlpha = 0.02f;
    longTermCorrelation = longAlpha * instantCorrelation + (1.0f - longAlpha) * longTermCorrelation;

    // Track min/max
    minCorrelation = juce::jmin(minCorrelation, instantCorrelation);
    maxCorrelation = juce::jmax(maxCorrelation, instantCorrelation);

    // Add to history
    correlationHistory.values.push_back(instantCorrelation);
    if (correlationHistory.values.size() > static_cast<size_t>(correlationHistory.maxSize))
        correlationHistory.values.erase(correlationHistory.values.begin());
}

void PhaseAnalyzer::updateGoniometer(const juce::AudioBuffer<float>& buffer)
{
    const float* left = buffer.getReadPointer(0);
    const float* right = buffer.getReadPointer(1);
    int numSamples = buffer.getNumSamples();

    // Sample every N samples to avoid too many points
    int stride = numSamples / 32;
    if (stride < 1) stride = 1;

    for (int i = 0; i < numSamples; i += stride)
    {
        GoniometerPoint point;

        // Calculate Mid/Side
        point.mid = (left[i] + right[i]) * 0.5f;
        point.side = (left[i] - right[i]) * 0.5f;

        // Calculate polar coordinates
        point.magnitude = std::sqrt(point.mid * point.mid + point.side * point.side);
        point.angle = std::atan2(point.side, point.mid);

        goniometerHistory.push_back(point);
    }

    // Limit history size
    while (goniometerHistory.size() > static_cast<size_t>(maxGoniometerPoints))
        goniometerHistory.erase(goniometerHistory.begin());
}

void PhaseAnalyzer::performFFTAnalysis(const juce::AudioBuffer<float>& buffer)
{
    int numSamples = juce::jmin(buffer.getNumSamples(), fftSize);

    // OPTIMIZATION: Cache read pointers to avoid per-sample virtual calls
    const float* leftPtr = buffer.getReadPointer(0);
    const float* rightPtr = buffer.getReadPointer(1);

    // Copy left channel
    leftFFTData.fill(0.0f);
    for (int i = 0; i < numSamples; ++i)
        leftFFTData[i] = leftPtr[i];

    // Copy right channel
    rightFFTData.fill(0.0f);
    for (int i = 0; i < numSamples; ++i)
        rightFFTData[i] = rightPtr[i];

    // Apply window to both
    window.multiplyWithWindowingTable(leftFFTData.data(), fftSize);
    window.multiplyWithWindowingTable(rightFFTData.data(), fftSize);

    // Perform FFT
    forwardFFT.performFrequencyOnlyForwardTransform(leftFFTData.data());
    forwardFFT.performFrequencyOnlyForwardTransform(rightFFTData.data());

    // Store magnitudes
    for (int i = 0; i < fftSize; ++i)
    {
        leftMagnitudes[i] = leftFFTData[i];
        rightMagnitudes[i] = rightFFTData[i];
    }
}

void PhaseAnalyzer::analyzeFrequencyPhase()
{
    frequencyPhaseData.clear();

    float binFrequency = static_cast<float>(currentSampleRate) / fftSize;
    int binsPerBand = fftSize / (2 * frequencyResolution);

    for (int band = 0; band < frequencyResolution; ++band)
    {
        int startBin = band * binsPerBand;
        int endBin = startBin + binsPerBand;

        if (endBin >= fftSize / 2)
            break;

        FrequencyPhase fp;

        // Center frequency
        fp.frequency = (startBin + endBin) * 0.5f * binFrequency;

        // Average magnitudes in this band
        fp.leftMagnitude = 0.0f;
        fp.rightMagnitude = 0.0f;
        for (int bin = startBin; bin < endBin; ++bin)
        {
            fp.leftMagnitude += leftMagnitudes[bin];
            fp.rightMagnitude += rightMagnitudes[bin];
        }
        fp.leftMagnitude /= binsPerBand;
        fp.rightMagnitude /= binsPerBand;

        // Simple correlation estimate (magnitude difference)
        float magDiff = std::abs(fp.leftMagnitude - fp.rightMagnitude);
        float magSum = fp.leftMagnitude + fp.rightMagnitude;
        fp.correlation = (magSum > 0.001f) ? (1.0f - magDiff / magSum) : 1.0f;

        // Phase difference (simplified - would need complex FFT for accuracy)
        fp.phaseDifference = magDiff * 90.0f;  // Rough estimate

        // Determine status
        if (fp.phaseDifference < 30.0f)
            fp.status = FrequencyPhase::Status::Good;
        else if (fp.phaseDifference < 90.0f)
            fp.status = FrequencyPhase::Status::Warning;
        else
            fp.status = FrequencyPhase::Status::Problem;

        frequencyPhaseData.push_back(fp);
    }
}

void PhaseAnalyzer::detectIssues()
{
    detectedIssues.clear();

    // Check overall correlation
    if (longTermCorrelation < -0.5f)
    {
        PhaseIssue issue;
        issue.description = "Severe phase cancellation detected";
        issue.location = "Entire stereo field";
        issue.severity = 1.0f;
        issue.suggestion = "One channel may be inverted. Try flipping the polarity of one channel.";
        issue.technicalDetails = "Correlation: " + juce::String(longTermCorrelation, 2).toStdString();
        detectedIssues.push_back(issue);
    }

    // Check low-frequency phase
    if (!frequencyPhaseData.empty())
    {
        int lowFreqIssues = 0;
        for (const auto& fp : frequencyPhaseData)
        {
            if (fp.frequency < 250.0f && fp.status == FrequencyPhase::Status::Problem)
                lowFreqIssues++;
        }

        if (lowFreqIssues > 2)
        {
            PhaseIssue issue;
            issue.description = "Low-frequency phase issues";
            issue.location = "Below 250Hz";
            issue.severity = 0.7f;
            issue.suggestion = "Use mid/side processing to center low frequencies (bass should be mono).";
            issue.technicalDetails = juce::String(lowFreqIssues).toStdString() + " frequency bands affected";
            detectedIssues.push_back(issue);
        }
    }

    // Check mono compatibility
    if (!monoCompat.passesRadioTest)
    {
        PhaseIssue issue;
        issue.description = "Poor mono compatibility";
        issue.location = "When summed to mono";
        issue.severity = 0.6f;
        issue.suggestion = "Check for out-of-phase stereo widening effects. Reduce stereo width on bass.";
        issue.technicalDetails = "Mono compatibility score: " + juce::String(monoCompat.overallScore, 2).toStdString();
        detectedIssues.push_back(issue);
    }
}

void PhaseAnalyzer::calculateMonoCompatibility()
{
    // Calculate scores based on frequency phase data
    float lowScore = 1.0f;
    float midScore = 1.0f;
    float highScore = 1.0f;

    int lowCount = 0, midCount = 0, highCount = 0;

    for (const auto& fp : frequencyPhaseData)
    {
        if (fp.frequency < 250.0f)
        {
            lowScore += fp.correlation;
            lowCount++;
        }
        else if (fp.frequency < 2000.0f)
        {
            midScore += fp.correlation;
            midCount++;
        }
        else
        {
            highScore += fp.correlation;
            highCount++;
        }
    }

    monoCompat.lowFreqScore = (lowCount > 0) ? (lowScore / lowCount) : 1.0f;
    monoCompat.midFreqScore = (midCount > 0) ? (midScore / midCount) : 1.0f;
    monoCompat.highFreqScore = (highCount > 0) ? (highScore / highCount) : 1.0f;

    // Overall score (weighted towards low frequencies)
    monoCompat.overallScore = (monoCompat.lowFreqScore * 0.5f +
                              monoCompat.midFreqScore * 0.3f +
                              monoCompat.highFreqScore * 0.2f);

    // Radio test
    monoCompat.passesRadioTest = (monoCompat.overallScore > 0.7f && monoCompat.lowFreqScore > 0.8f);

    // Generate warnings
    monoCompat.warnings.clear();

    if (monoCompat.lowFreqScore < 0.7f)
        monoCompat.warnings.push_back("Bass frequencies have poor mono compatibility");

    if (monoCompat.midFreqScore < 0.6f)
        monoCompat.warnings.push_back("Mid-range has phase cancellation issues");

    if (longTermCorrelation < 0.0f)
        monoCompat.warnings.push_back("Severe phase cancellation - audio may disappear in mono");

    if (!monoCompat.passesRadioTest)
        monoCompat.warnings.push_back("May sound thin or hollow on mono playback devices");
}

//==============================================================================
// Helper Functions

float PhaseAnalyzer::calculateCorrelationCoefficient(const float* left, const float* right, int numSamples)
{
    // Pearson correlation coefficient
    float sumL = 0.0f, sumR = 0.0f;
    float sumLL = 0.0f, sumRR = 0.0f, sumLR = 0.0f;

    for (int i = 0; i < numSamples; ++i)
    {
        float l = left[i];
        float r = right[i];

        sumL += l;
        sumR += r;
        sumLL += l * l;
        sumRR += r * r;
        sumLR += l * r;
    }

    float n = static_cast<float>(numSamples);
    float numerator = n * sumLR - sumL * sumR;
    float denominator = std::sqrt((n * sumLL - sumL * sumL) * (n * sumRR - sumR * sumR));

    if (denominator < 0.0001f)
        return 1.0f;

    return juce::jlimit(-1.0f, 1.0f, numerator / denominator);
}

float PhaseAnalyzer::calculatePhaseDifference(std::complex<float> leftSpectrum, std::complex<float> rightSpectrum)
{
    float leftPhase = std::arg(leftSpectrum);
    float rightPhase = std::arg(rightSpectrum);

    float diff = std::abs(leftPhase - rightPhase);

    // Convert to degrees
    return diff * 180.0f / juce::MathConstants<float>::pi;
}
