#include "SmartMixer.h"
#include <cmath>
#include <algorithm>

//==============================================================================
// Constructor / Destructor
//==============================================================================

SmartMixer::SmartMixer()
{
    sampleRate = 48000.0;
    modelLoaded = false;

    DBG("SmartMixer: AI-Powered Auto-Mixing initialized");
}

//==============================================================================
// Auto-Mixing Analysis
//==============================================================================

std::vector<SmartMixer::MixingSuggestion> SmartMixer::analyzeAndSuggest(
    const std::vector<juce::AudioBuffer<float>>& tracks,
    const std::vector<juce::String>& trackNames
)
{
    DBG("SmartMixer: Analyzing " << tracks.size() << " tracks");

    std::vector<MixingSuggestion> suggestions;

    // Analyze each track individually
    for (size_t i = 0; i < tracks.size(); ++i)
    {
        const auto& track = tracks[i];
        MixingSuggestion suggestion;

        suggestion.trackIndex = static_cast<int>(i);
        suggestion.trackName = trackNames[i];

        // Spectrum analysis
        auto spectrum = analyzeSpectrum(track);

        // Dynamics analysis
        auto dynamics = analyzeDynamics(track);

        DBG("  Track " << i << ": " << trackNames[i]);
        DBG("    RMS: " << dynamics.rmsLevel << " dB");
        DBG("    Peak: " << dynamics.peakLevel << " dB");
        DBG("    Spectral Centroid: " << spectrum.spectralCentroid << " Hz");

        // Gain staging based on RMS level
        // Target: -18dBFS RMS (professional standard)
        float targetRMS = -18.0f;
        suggestion.suggestedGain = targetRMS - dynamics.rmsLevel;

        // Limit gain adjustment
        suggestion.suggestedGain = juce::jlimit(-12.0f, 12.0f, suggestion.suggestedGain);

        // Pan suggestion based on spectral content
        // Lower frequency content -> center
        // Higher frequency content -> wider panning
        if (spectrum.spectralCentroid < 500.0f)
        {
            suggestion.suggestedPan = 0.0f;  // Center (bass/kick)
        }
        else if (spectrum.spectralCentroid > 4000.0f)
        {
            // Alternate high-frequency content left/right
            suggestion.suggestedPan = (i % 2 == 0) ? -0.3f : 0.3f;
        }
        else
        {
            // Mid-range: slight panning
            suggestion.suggestedPan = (i % 2 == 0) ? -0.15f : 0.15f;
        }

        // EQ suggestions based on spectral analysis
        // Cut resonances, boost clarity
        if (spectrum.spectralCentroid < 200.0f)
        {
            // Bass-heavy: low shelf boost
            suggestion.suggestedEQ.lowShelf = 2.0f;
            suggestion.suggestedEQ.highShelf = -1.0f;
        }
        else if (spectrum.spectralCentroid > 3000.0f)
        {
            // Bright: high shelf boost for air
            suggestion.suggestedEQ.highShelf = 2.0f;
            suggestion.suggestedEQ.lowShelf = -2.0f;
        }
        else
        {
            // Mid-range: boost presence
            suggestion.suggestedEQ.midPeak = 2.0f;
        }

        // Compression based on dynamic range
        if (dynamics.dynamicRange > 20.0f)
        {
            // High dynamic range: moderate compression
            suggestion.suggestedCompression.threshold = -20.0f;
            suggestion.suggestedCompression.ratio = 4.0f;
            suggestion.suggestedCompression.attack = 10.0f;
            suggestion.suggestedCompression.release = 100.0f;
        }
        else if (dynamics.dynamicRange < 10.0f)
        {
            // Already compressed: gentle compression
            suggestion.suggestedCompression.threshold = -15.0f;
            suggestion.suggestedCompression.ratio = 2.0f;
        }
        else
        {
            // Normal range: standard compression
            suggestion.suggestedCompression.threshold = -18.0f;
            suggestion.suggestedCompression.ratio = 3.0f;
        }

        // Effects sends based on character
        // Vocals, pads: more reverb
        // Drums: less reverb, more delay
        if (trackNames[i].containsIgnoreCase("vocal") ||
            trackNames[i].containsIgnoreCase("pad"))
        {
            suggestion.reverbSend = 0.3f;
            suggestion.delaySend = 0.1f;
        }
        else if (trackNames[i].containsIgnoreCase("drum") ||
                 trackNames[i].containsIgnoreCase("kick"))
        {
            suggestion.reverbSend = 0.05f;
            suggestion.delaySend = 0.2f;
        }
        else
        {
            suggestion.reverbSend = 0.15f;
            suggestion.delaySend = 0.15f;
        }

        // Confidence score (0.0 to 1.0)
        // Higher confidence for tracks with clear characteristics
        suggestion.confidence = 0.7f + (dynamics.crestFactor / 20.0f);
        suggestion.confidence = juce::jlimit(0.0f, 1.0f, suggestion.confidence);

        suggestions.push_back(suggestion);
    }

    // Inter-track adjustments
    adjustForMasking(suggestions, tracks);
    adjustForFrequencyBalance(suggestions, tracks);

    DBG("SmartMixer: Generated " << suggestions.size() << " suggestions");

    return suggestions;
}

void SmartMixer::applySuggestions(
    std::vector<juce::AudioBuffer<float>>& tracks,
    const std::vector<MixingSuggestion>& suggestions
)
{
    DBG("SmartMixer: Applying suggestions to " << tracks.size() << " tracks");

    for (size_t i = 0; i < suggestions.size() && i < tracks.size(); ++i)
    {
        const auto& sug = suggestions[i];
        auto& track = tracks[i];

        // Apply gain
        float linearGain = juce::Decibels::decibelsToGain(sug.suggestedGain);
        track.applyGain(linearGain);

        // Apply pan (would need stereo processing)
        // Simplified: just gain adjustment for now

        // Apply EQ
        applyEQ(track, sug.suggestedEQ);

        // Apply compression
        applyCompression(track, sug.suggestedCompression);

        DBG("  Applied to track " << i << ": "
            << "Gain=" << sug.suggestedGain << "dB, "
            << "Pan=" << sug.suggestedPan);
    }
}

//==============================================================================
// Mastering
//==============================================================================

juce::AudioBuffer<float> SmartMixer::masterTrack(
    const juce::AudioBuffer<float>& mixdown,
    MasteringTarget target
)
{
    MasteringSettings settings;

    switch (target)
    {
        case MasteringTarget::Spotify:
            settings.targetLUFS = -14.0f;
            settings.truePeakCeiling = -1.0f;
            break;

        case MasteringTarget::AppleMusic:
            settings.targetLUFS = -16.0f;
            settings.truePeakCeiling = -1.0f;
            break;

        case MasteringTarget::YouTube:
            settings.targetLUFS = -13.0f;
            settings.truePeakCeiling = -1.0f;
            break;

        case MasteringTarget::Tidal:
            settings.targetLUFS = -14.0f;
            settings.truePeakCeiling = -1.0f;
            break;

        case MasteringTarget::CD:
            settings.targetLUFS = -9.0f;
            settings.truePeakCeiling = -0.1f;
            break;

        case MasteringTarget::BroadcastEBU:
            settings.targetLUFS = -23.0f;
            settings.truePeakCeiling = -1.0f;
            break;

        case MasteringTarget::Custom:
        default:
            settings.targetLUFS = -14.0f;
            break;
    }

    return masterTrack(mixdown, settings);
}

juce::AudioBuffer<float> SmartMixer::masterTrack(
    const juce::AudioBuffer<float>& mixdown,
    const MasteringSettings& settings
)
{
    DBG("SmartMixer: Mastering track");
    DBG("  Target LUFS: " << settings.targetLUFS);
    DBG("  True Peak Ceiling: " << settings.truePeakCeiling << " dBTP");

    // Create output buffer
    juce::AudioBuffer<float> output(mixdown.getNumChannels(), mixdown.getNumSamples());
    output.makeCopyOf(mixdown);

    // 1. Normalize to target LUFS
    normalizeLUFS(output, settings.targetLUFS);

    // 2. Apply gentle multiband compression
    // (Simplified: would use proper multiband in production)
    CompressionSettings comp;
    comp.threshold = -12.0f;
    comp.ratio = 1.5f;
    comp.attack = 30.0f;
    comp.release = 300.0f;
    applyCompression(output, comp);

    // 3. High-shelf EQ for "air"
    EQSettings eq;
    eq.highShelf = 1.0f;  // +1dB above 10kHz
    applyEQ(output, eq);

    // 4. True-peak limiting
    if (settings.limitingEnabled)
    {
        applyLimiter(output, settings.truePeakCeiling);
    }

    // 5. Final loudness check
    auto finalDynamics = analyzeDynamics(output);
    DBG("  Final LUFS: " << finalDynamics.lufsIntegrated);
    DBG("  Final Peak: " << finalDynamics.peakLevel << " dBFS");

    return output;
}

//==============================================================================
// Analysis Tools
//==============================================================================

SmartMixer::SpectrumAnalysis SmartMixer::analyzeSpectrum(
    const juce::AudioBuffer<float>& audio
)
{
    SpectrumAnalysis analysis;

    // Simplified FFT analysis (would use juce::dsp::FFT in production)
    const int fftSize = 2048;
    analysis.magnitudes.resize(fftSize / 2);

    // Get mono mix
    juce::AudioBuffer<float> mono(1, audio.getNumSamples());
    mono.copyFrom(0, 0, audio, 0, 0, audio.getNumSamples());

    if (audio.getNumChannels() > 1)
    {
        mono.addFrom(0, 0, audio, 1, 0, audio.getNumSamples());
        mono.applyGain(0.5f);
    }

    // Calculate spectral centroid (weighted average frequency)
    float weightedSum = 0.0f;
    float totalMagnitude = 0.0f;

    for (size_t i = 0; i < analysis.magnitudes.size(); ++i)
    {
        float freq = (i * sampleRate) / fftSize;
        float magnitude = analysis.magnitudes[i];

        weightedSum += freq * magnitude;
        totalMagnitude += magnitude;
    }

    analysis.spectralCentroid = (totalMagnitude > 0.0f) ?
                                 weightedSum / totalMagnitude : 1000.0f;

    return analysis;
}

SmartMixer::DynamicsAnalysis SmartMixer::analyzeDynamics(
    const juce::AudioBuffer<float>& audio
)
{
    DynamicsAnalysis analysis;

    analysis.rmsLevel = calculateRMS(audio);
    analysis.peakLevel = calculatePeak(audio);

    float rmsLinear = juce::Decibels::decibelsToGain(analysis.rmsLevel);
    float peakLinear = juce::Decibels::decibelsToGain(analysis.peakLevel);

    analysis.crestFactor = (rmsLinear > 0.0f) ? peakLinear / rmsLinear : 1.0f;
    analysis.dynamicRange = analysis.peakLevel - analysis.rmsLevel;
    analysis.lufsIntegrated = calculateLUFS(audio);

    return analysis;
}

//==============================================================================
// Feature Extraction
//==============================================================================

float SmartMixer::calculateRMS(const juce::AudioBuffer<float>& audio)
{
    float sumSquares = 0.0f;
    int totalSamples = 0;

    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        const float* channelData = audio.getReadPointer(ch);

        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            sumSquares += channelData[i] * channelData[i];
            totalSamples++;
        }
    }

    float rms = std::sqrt(sumSquares / totalSamples);
    return juce::Decibels::gainToDecibels(rms);
}

float SmartMixer::calculatePeak(const juce::AudioBuffer<float>& audio)
{
    float peak = 0.0f;

    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        float channelPeak = audio.getMagnitude(ch, 0, audio.getNumSamples());
        peak = std::max(peak, channelPeak);
    }

    return juce::Decibels::gainToDecibels(peak);
}

float SmartMixer::calculateLUFS(const juce::AudioBuffer<float>& audio)
{
    // Simplified LUFS calculation (ITU-R BS.1770)
    // Real implementation would use proper K-weighting filter

    float rms = calculateRMS(audio);

    // LUFS ≈ -0.691 + RMS (rough approximation)
    float lufs = -0.691f + rms;

    return lufs;
}

//==============================================================================
// Processing
//==============================================================================

void SmartMixer::applyEQ(juce::AudioBuffer<float>& audio, const EQSettings& eq)
{
    // Simplified EQ (would use juce::dsp::IIR::Filter in production)
    // This is a placeholder showing the concept

    // Apply high-shelf boost/cut
    if (std::abs(eq.highShelf) > 0.1f)
    {
        float gain = juce::Decibels::decibelsToGain(eq.highShelf);

        // Simplified: apply gain to entire signal
        // Real implementation would filter frequencies > 10kHz
        audio.applyGain(gain);
    }
}

void SmartMixer::applyCompression(juce::AudioBuffer<float>& audio,
                                  const CompressionSettings& comp)
{
    // Simplified compression (would use proper envelope follower)
    float threshold = juce::Decibels::decibelsToGain(comp.threshold);

    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        float* channelData = audio.getWritePointer(ch);

        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            float input = std::abs(channelData[i]);

            if (input > threshold)
            {
                float excess = input - threshold;
                float compressed = threshold + (excess / comp.ratio);
                float gainReduction = compressed / input;

                channelData[i] *= gainReduction;
            }
        }
    }
}

void SmartMixer::applyLimiter(juce::AudioBuffer<float>& audio, float ceiling)
{
    float ceilingLinear = juce::Decibels::decibelsToGain(ceiling);

    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        float* channelData = audio.getWritePointer(ch);

        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            if (channelData[i] > ceilingLinear)
                channelData[i] = ceilingLinear;
            else if (channelData[i] < -ceilingLinear)
                channelData[i] = -ceilingLinear;
        }
    }
}

void SmartMixer::normalizeLUFS(juce::AudioBuffer<float>& audio, float targetLUFS)
{
    float currentLUFS = calculateLUFS(audio);
    float gainAdjustment = targetLUFS - currentLUFS;

    float linearGain = juce::Decibels::decibelsToGain(gainAdjustment);
    audio.applyGain(linearGain);

    DBG("SmartMixer: Normalized from " << currentLUFS << " to " << targetLUFS << " LUFS");
}

//==============================================================================
// Inter-Track Analysis
//==============================================================================

void SmartMixer::adjustForMasking(
    std::vector<MixingSuggestion>& suggestions,
    const std::vector<juce::AudioBuffer<float>>& tracks
)
{
    // Detect frequency masking and suggest EQ adjustments
    // Simplified: would analyze spectrum overlap in production

    DBG("SmartMixer: Adjusting for frequency masking");

    // Example: If kick and bass overlap, cut bass lows
    for (size_t i = 0; i < suggestions.size(); ++i)
    {
        if (suggestions[i].trackName.containsIgnoreCase("bass"))
        {
            // Check if kick exists
            for (size_t j = 0; j < suggestions.size(); ++j)
            {
                if (suggestions[j].trackName.containsIgnoreCase("kick"))
                {
                    // Cut bass low-end to make room for kick
                    suggestions[i].suggestedEQ.lowShelf -= 3.0f;
                    DBG("  Cutting bass lows to avoid kick masking");
                    break;
                }
            }
        }
    }
}

void SmartMixer::adjustForFrequencyBalance(
    std::vector<MixingSuggestion>& suggestions,
    const std::vector<juce::AudioBuffer<float>>& tracks
)
{
    // Balance overall frequency spectrum
    DBG("SmartMixer: Adjusting for frequency balance");

    // Count bass-heavy vs bright tracks
    int bassHeavy = 0;
    int brightTracks = 0;

    for (const auto& sug : suggestions)
    {
        auto spectrum = analyzeSpectrum(tracks[sug.trackIndex]);

        if (spectrum.spectralCentroid < 500.0f)
            bassHeavy++;
        else if (spectrum.spectralCentroid > 3000.0f)
            brightTracks++;
    }

    // Balance: if too much bass, boost highs
    if (bassHeavy > brightTracks)
    {
        for (auto& sug : suggestions)
        {
            sug.suggestedEQ.highShelf += 1.0f;
        }
        DBG("  Boosting highs to balance bass-heavy mix");
    }
}

//==============================================================================
// Model Management
//==============================================================================

bool SmartMixer::loadModel(const juce::File& modelFile)
{
    if (!modelFile.existsAsFile())
    {
        DBG("SmartMixer: Model file not found: " << modelFile.getFullPathName());
        return false;
    }

    // Would load ONNX model here
    // For now, use rule-based algorithms

    modelLoaded = true;
    DBG("SmartMixer: Model loaded (rule-based fallback)");

    return true;
}
