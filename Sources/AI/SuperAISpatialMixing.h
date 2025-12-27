#pragma once

#include <JuceHeader.h>
#include "GeniusWiseOptimizations.h"
#include "../Platform/XRSpatialInterface.h"
#include <vector>
#include <map>
#include <cmath>

namespace Echoel {
namespace AI {

//==============================================================================
/**
 * @brief Super AI Spatial Mixing Engine
 *
 * Intelligentes räumliches Mixing mit:
 * - Automatische LUFS-Angleichung über alle Positionen
 * - KI-gesteuerte Mix-Entscheidungen
 * - Spatial Audio Loudness Compensation
 * - Intelligente Panorama & Tiefe
 * - Mix-Assistent mit Verbesserungsvorschlägen
 *
 * "Der Mix soll überall gleich laut klingen - egal wo im Raum"
 */

//==============================================================================
/**
 * @brief Spatial Audio Position with Loudness Data
 */
struct SpatialSource
{
    juce::String id;

    // 3D Position
    float x = 0.0f;      // -1 (left) to 1 (right)
    float y = 0.0f;      // -1 (back) to 1 (front)
    float z = 0.0f;      // -1 (below) to 1 (above)
    float distance = 1.0f;  // 0 (near) to infinity

    // Loudness
    float lufs = -18.0f;
    float truePeak = -1.0f;
    float rms = -20.0f;

    // Perceived loudness (distance-compensated)
    float perceivedLufs = -18.0f;

    // AI-suggested adjustments
    float suggestedGainDb = 0.0f;
    float suggestedPan = 0.0f;
    float suggestedDistance = 1.0f;

    // Frequency content (for intelligent mixing)
    float lowEnergy = 0.0f;     // 20-200 Hz
    float midEnergy = 0.0f;     // 200-2000 Hz
    float highEnergy = 0.0f;    // 2000-20000 Hz
    float presence = 0.0f;      // 2-5 kHz (vocal clarity)

    // Dynamics
    float dynamicRange = 0.0f;
    float crestFactor = 0.0f;

    // Spatial characteristics
    float width = 0.0f;         // Stereo width
    float depth = 0.0f;         // Front-back depth
    float height = 0.0f;        // Vertical spread
};

//==============================================================================
/**
 * @brief AI Mix Analysis Result
 */
struct MixAnalysis
{
    // Overall loudness
    float masterLufs = -14.0f;
    float masterTruePeak = -1.0f;
    float loudnessRange = 8.0f;

    // Spatial balance
    float leftRightBalance = 0.0f;    // -1 to 1
    float frontBackBalance = 0.0f;    // -1 to 1
    float verticalBalance = 0.0f;     // -1 to 1

    // Frequency balance
    float lowMidRatio = 0.0f;
    float midHighRatio = 0.0f;
    float overallBalance = 0.0f;      // -1 (dark) to 1 (bright)

    // Issues detected
    struct Issue
    {
        juce::String type;
        juce::String description;
        juce::String suggestion;
        float severity;  // 0-1
        juce::String affectedSourceId;
    };

    std::vector<Issue> issues;

    // Quality scores (0-100)
    int overallScore = 0;
    int loudnessScore = 0;
    int spatialScore = 0;
    int frequencyScore = 0;
    int dynamicsScore = 0;
    int clarityScore = 0;
};

//==============================================================================
/**
 * @brief Spatial LUFS Equalizer
 *
 * Gleicht Lautheit über alle räumlichen Positionen an
 */
class SpatialLUFSEqualizer
{
public:
    static SpatialLUFSEqualizer& getInstance()
    {
        static SpatialLUFSEqualizer instance;
        return instance;
    }

    void setTargetLUFS(float lufs)
    {
        targetLufs = lufs;
    }

    void setDistanceCompensation(bool enabled)
    {
        distanceCompensation = enabled;
    }

    void setDistanceAttenuation(float dbPerDoubling)
    {
        // Natürlich: -6dB pro Verdopplung der Entfernung
        // Räume: -3 bis -4dB (Reflexionen helfen)
        distanceAttenuationDb = dbPerDoubling;
    }

    // Berechnet Gain-Adjustment für eine Source
    float calculateGainAdjustment(const SpatialSource& source)
    {
        float adjustment = 0.0f;

        // 1. LUFS auf Target angleichen
        adjustment = targetLufs - source.lufs;

        // 2. Distanz-Kompensation
        if (distanceCompensation && source.distance > 0.0f)
        {
            // Natürliche Dämpfung ausgleichen
            float distanceDb = distanceAttenuationDb * std::log2(source.distance);
            adjustment += distanceDb;
        }

        // 3. True Peak Limiting beachten
        float headroom = -1.0f - source.truePeak;
        if (adjustment > headroom)
        {
            adjustment = headroom;
        }

        return adjustment;
    }

    // Batch-Verarbeitung für alle Sources
    void equalizeAllSources(std::vector<SpatialSource>& sources)
    {
        for (auto& source : sources)
        {
            source.suggestedGainDb = calculateGainAdjustment(source);

            // Perceived LUFS nach Adjustment
            source.perceivedLufs = source.lufs + source.suggestedGainDb;
        }
    }

    // Berechnet optimale Position für Loudness-Balance
    void optimizeSpatialPositions(std::vector<SpatialSource>& sources)
    {
        // Sortiere nach Wichtigkeit (Loudness + Presence)
        std::vector<size_t> indices(sources.size());
        std::iota(indices.begin(), indices.end(), 0);

        std::sort(indices.begin(), indices.end(), [&](size_t a, size_t b) {
            float importanceA = sources[a].lufs + sources[a].presence * 10.0f;
            float importanceB = sources[b].lufs + sources[b].presence * 10.0f;
            return importanceA > importanceB;
        });

        // Wichtigste Sources näher positionieren
        float baseDistance = 1.0f;
        for (size_t i = 0; i < indices.size(); ++i)
        {
            float importance = 1.0f - (static_cast<float>(i) / sources.size());
            sources[indices[i]].suggestedDistance = baseDistance + (1.0f - importance) * 2.0f;
        }
    }

private:
    float targetLufs = -14.0f;
    bool distanceCompensation = true;
    float distanceAttenuationDb = -6.0f;  // dB pro Verdopplung
};

//==============================================================================
/**
 * @brief Super AI Mix Assistant
 *
 * KI-gestützter Mix-Assistent mit:
 * - Automatische Problemerkennung
 * - Intelligente Verbesserungsvorschläge
 * - Genre-spezifische Optimierung
 * - Referenz-Track-Vergleich
 */
class SuperAIMixAssistant
{
public:
    enum class Genre
    {
        Electronic,
        HipHop,
        Rock,
        Pop,
        Classical,
        Jazz,
        Ambient,
        Film,
        Podcast,
        Meditation
    };

    struct GenreProfile
    {
        float targetLufs;
        float targetTruePeak;
        float lowEndDb;          // Relative to mid
        float highEndDb;         // Relative to mid
        float dynamicRange;
        float stereoWidth;
        float reverb;
        bool heavyCompression;
    };

    static SuperAIMixAssistant& getInstance()
    {
        static SuperAIMixAssistant instance;
        return instance;
    }

    void setGenre(Genre genre)
    {
        currentGenre = genre;
        profile = getGenreProfile(genre);
    }

    GenreProfile getGenreProfile(Genre genre)
    {
        switch (genre)
        {
            case Genre::Electronic:
                return { -9.0f, -0.5f, 3.0f, 1.0f, 6.0f, 0.8f, 0.3f, true };
            case Genre::HipHop:
                return { -10.0f, -0.5f, 4.0f, 0.0f, 8.0f, 0.6f, 0.2f, true };
            case Genre::Rock:
                return { -12.0f, -1.0f, 1.0f, 1.0f, 10.0f, 0.7f, 0.4f, false };
            case Genre::Pop:
                return { -11.0f, -1.0f, 1.0f, 2.0f, 8.0f, 0.7f, 0.3f, true };
            case Genre::Classical:
                return { -18.0f, -3.0f, 0.0f, 0.0f, 20.0f, 0.9f, 0.6f, false };
            case Genre::Jazz:
                return { -16.0f, -2.0f, 0.0f, 0.0f, 15.0f, 0.8f, 0.5f, false };
            case Genre::Ambient:
                return { -16.0f, -2.0f, 1.0f, -1.0f, 12.0f, 1.0f, 0.8f, false };
            case Genre::Film:
                return { -24.0f, -2.0f, 2.0f, 0.0f, 18.0f, 0.9f, 0.7f, false };
            case Genre::Podcast:
                return { -16.0f, -1.0f, -2.0f, 1.0f, 10.0f, 0.0f, 0.1f, true };
            case Genre::Meditation:
                return { -20.0f, -3.0f, 1.0f, -2.0f, 15.0f, 0.9f, 0.9f, false };
            default:
                return { -14.0f, -1.0f, 0.0f, 0.0f, 10.0f, 0.7f, 0.4f, false };
        }
    }

    // Vollständige Mix-Analyse
    MixAnalysis analyzeMix(const std::vector<SpatialSource>& sources)
    {
        MixAnalysis analysis;

        if (sources.empty()) return analysis;

        // 1. Gesamt-Loudness berechnen
        float sumLinear = 0.0f;
        float maxTruePeak = -100.0f;
        float minLufs = 0.0f, maxLufs = -100.0f;

        float leftEnergy = 0.0f, rightEnergy = 0.0f;
        float frontEnergy = 0.0f, backEnergy = 0.0f;
        float lowTotal = 0.0f, midTotal = 0.0f, highTotal = 0.0f;

        for (const auto& source : sources)
        {
            float linear = std::pow(10.0f, source.lufs / 10.0f);
            sumLinear += linear;

            if (source.truePeak > maxTruePeak) maxTruePeak = source.truePeak;
            if (source.lufs > maxLufs) maxLufs = source.lufs;
            if (source.lufs < minLufs) minLufs = source.lufs;

            // Spatial balance
            float energy = linear;
            leftEnergy += energy * (1.0f - source.x) * 0.5f;
            rightEnergy += energy * (1.0f + source.x) * 0.5f;
            frontEnergy += energy * (1.0f + source.y) * 0.5f;
            backEnergy += energy * (1.0f - source.y) * 0.5f;

            // Frequency content
            lowTotal += source.lowEnergy * energy;
            midTotal += source.midEnergy * energy;
            highTotal += source.highEnergy * energy;
        }

        analysis.masterLufs = 10.0f * std::log10(sumLinear);
        analysis.masterTruePeak = maxTruePeak;
        analysis.loudnessRange = maxLufs - minLufs;

        // Spatial balance (-1 to 1)
        float totalLR = leftEnergy + rightEnergy;
        if (totalLR > 0.0f)
            analysis.leftRightBalance = (rightEnergy - leftEnergy) / totalLR;

        float totalFB = frontEnergy + backEnergy;
        if (totalFB > 0.0f)
            analysis.frontBackBalance = (frontEnergy - backEnergy) / totalFB;

        // Frequency balance
        float totalFreq = lowTotal + midTotal + highTotal;
        if (totalFreq > 0.0f)
        {
            analysis.lowMidRatio = lowTotal / midTotal;
            analysis.midHighRatio = midTotal / highTotal;
            analysis.overallBalance = (highTotal - lowTotal) / totalFreq;
        }

        // 2. Probleme erkennen
        detectIssues(analysis, sources);

        // 3. Scores berechnen
        calculateScores(analysis);

        return analysis;
    }

    // KI-Vorschläge generieren
    struct MixSuggestion
    {
        juce::String category;
        juce::String description;
        juce::String action;
        float importance;  // 0-1
        std::function<void()> apply;
    };

    std::vector<MixSuggestion> generateSuggestions(const MixAnalysis& analysis,
                                                    std::vector<SpatialSource>& sources)
    {
        std::vector<MixSuggestion> suggestions;

        // Loudness-Vorschläge
        if (analysis.masterLufs > profile.targetLufs + 2.0f)
        {
            float reduction = analysis.masterLufs - profile.targetLufs;
            suggestions.push_back({
                "Loudness",
                "Mix ist " + juce::String(reduction, 1) + " dB zu laut für " + getGenreName(),
                "Master-Gain um " + juce::String(reduction, 1) + " dB reduzieren",
                0.9f,
                nullptr
            });
        }
        else if (analysis.masterLufs < profile.targetLufs - 2.0f)
        {
            float increase = profile.targetLufs - analysis.masterLufs;
            suggestions.push_back({
                "Loudness",
                "Mix ist " + juce::String(increase, 1) + " dB zu leise für " + getGenreName(),
                "Master-Gain um " + juce::String(increase, 1) + " dB erhöhen",
                0.8f,
                nullptr
            });
        }

        // Spatial Balance Vorschläge
        if (std::abs(analysis.leftRightBalance) > 0.15f)
        {
            juce::String side = analysis.leftRightBalance > 0 ? "rechts" : "links";
            suggestions.push_back({
                "Spatial",
                "Mix ist nach " + side + " unbalanciert",
                "Elemente zur Mitte oder Gegenseite verschieben",
                0.7f,
                nullptr
            });
        }

        // Frequenz-Vorschläge
        if (analysis.lowMidRatio > 1.5f)
        {
            suggestions.push_back({
                "Frequenz",
                "Zu viel Bass im Verhältnis zu Mitten",
                "Low-End um 2-3 dB reduzieren oder Mid-Präsenz erhöhen",
                0.6f,
                nullptr
            });
        }

        if (analysis.midHighRatio < 0.5f)
        {
            suggestions.push_back({
                "Frequenz",
                "Zu viele Höhen im Verhältnis zu Mitten",
                "High-Shelf um 2-3 dB reduzieren",
                0.5f,
                nullptr
            });
        }

        // Pro Issue einen Vorschlag
        for (const auto& issue : analysis.issues)
        {
            suggestions.push_back({
                issue.type,
                issue.description,
                issue.suggestion,
                issue.severity,
                nullptr
            });
        }

        // Nach Wichtigkeit sortieren
        std::sort(suggestions.begin(), suggestions.end(),
            [](const MixSuggestion& a, const MixSuggestion& b) {
                return a.importance > b.importance;
            });

        return suggestions;
    }

    // Auto-Mix: Wendet alle Vorschläge automatisch an
    void autoMix(std::vector<SpatialSource>& sources)
    {
        MixAnalysis analysis = analyzeMix(sources);

        // 1. LUFS angleichen
        SpatialLUFSEqualizer::getInstance().setTargetLUFS(profile.targetLufs);
        SpatialLUFSEqualizer::getInstance().equalizeAllSources(sources);

        // 2. Spatial Balance optimieren
        optimizeSpatialBalance(sources, analysis);

        // 3. Frequenz-Balance korrigieren
        optimizeFrequencyBalance(sources, analysis);

        // 4. Dynamik anpassen
        optimizeDynamics(sources, analysis);
    }

private:
    void detectIssues(MixAnalysis& analysis, const std::vector<SpatialSource>& sources)
    {
        // Clipping
        if (analysis.masterTruePeak > -0.3f)
        {
            analysis.issues.push_back({
                "Clipping",
                "True Peak ist zu hoch: " + juce::String(analysis.masterTruePeak, 1) + " dBTP",
                "Limiter Threshold senken oder Mix-Gain reduzieren",
                1.0f,
                ""
            });
        }

        // Masking (mehrere Sources mit ähnlicher Position + Frequenz)
        for (size_t i = 0; i < sources.size(); ++i)
        {
            for (size_t j = i + 1; j < sources.size(); ++j)
            {
                float posDist = std::sqrt(
                    std::pow(sources[i].x - sources[j].x, 2) +
                    std::pow(sources[i].y - sources[j].y, 2)
                );

                float freqSim = 1.0f - std::abs(
                    sources[i].midEnergy - sources[j].midEnergy
                );

                if (posDist < 0.2f && freqSim > 0.7f)
                {
                    analysis.issues.push_back({
                        "Masking",
                        sources[i].id + " und " + sources[j].id + " maskieren sich gegenseitig",
                        "Räumliche Trennung erhöhen oder EQ anwenden",
                        0.7f,
                        sources[i].id
                    });
                }
            }
        }

        // Mono-Kompatibilität
        // (würde Phase-Korrelation prüfen)

        // Dynamik-Probleme
        if (analysis.loudnessRange < 4.0f)
        {
            analysis.issues.push_back({
                "Dynamik",
                "Mix ist überkomprimiert (LRA: " + juce::String(analysis.loudnessRange, 1) + " LU)",
                "Kompression reduzieren für mehr Lebendigkeit",
                0.5f,
                ""
            });
        }
        else if (analysis.loudnessRange > 20.0f)
        {
            analysis.issues.push_back({
                "Dynamik",
                "Mix hat zu viel Dynamik (LRA: " + juce::String(analysis.loudnessRange, 1) + " LU)",
                "Sanfte Kompression für bessere Durchsetzungskraft",
                0.4f,
                ""
            });
        }
    }

    void calculateScores(MixAnalysis& analysis)
    {
        // Loudness Score
        float lufsDiff = std::abs(analysis.masterLufs - profile.targetLufs);
        analysis.loudnessScore = juce::jmax(0, 100 - static_cast<int>(lufsDiff * 10));

        // Spatial Score
        float spatialImbalance = std::abs(analysis.leftRightBalance) +
                                  std::abs(analysis.frontBackBalance);
        analysis.spatialScore = juce::jmax(0, 100 - static_cast<int>(spatialImbalance * 100));

        // Frequency Score
        float freqDeviation = std::abs(analysis.overallBalance);
        analysis.frequencyScore = juce::jmax(0, 100 - static_cast<int>(freqDeviation * 100));

        // Dynamics Score
        float targetLRA = profile.dynamicRange;
        float lraDiff = std::abs(analysis.loudnessRange - targetLRA);
        analysis.dynamicsScore = juce::jmax(0, 100 - static_cast<int>(lraDiff * 5));

        // Clarity Score (based on presence and masking issues)
        int maskingIssues = 0;
        for (const auto& issue : analysis.issues)
        {
            if (issue.type == "Masking") maskingIssues++;
        }
        analysis.clarityScore = juce::jmax(0, 100 - maskingIssues * 20);

        // Overall Score
        analysis.overallScore = (
            analysis.loudnessScore * 25 +
            analysis.spatialScore * 20 +
            analysis.frequencyScore * 20 +
            analysis.dynamicsScore * 15 +
            analysis.clarityScore * 20
        ) / 100;
    }

    void optimizeSpatialBalance(std::vector<SpatialSource>& sources, const MixAnalysis& analysis)
    {
        if (std::abs(analysis.leftRightBalance) > 0.1f)
        {
            // Verschiebe Sources zur Balance
            float correction = -analysis.leftRightBalance * 0.5f;
            for (auto& source : sources)
            {
                source.x = juce::jlimit(-1.0f, 1.0f, source.x + correction);
            }
        }
    }

    void optimizeFrequencyBalance(std::vector<SpatialSource>& sources, const MixAnalysis& analysis)
    {
        // Hier würden EQ-Adjustments berechnet
    }

    void optimizeDynamics(std::vector<SpatialSource>& sources, const MixAnalysis& analysis)
    {
        // Hier würde Kompression angepasst
    }

    juce::String getGenreName() const
    {
        switch (currentGenre)
        {
            case Genre::Electronic: return "Electronic";
            case Genre::HipHop: return "Hip-Hop";
            case Genre::Rock: return "Rock";
            case Genre::Pop: return "Pop";
            case Genre::Classical: return "Classical";
            case Genre::Jazz: return "Jazz";
            case Genre::Ambient: return "Ambient";
            case Genre::Film: return "Film";
            case Genre::Podcast: return "Podcast";
            case Genre::Meditation: return "Meditation";
            default: return "Unknown";
        }
    }

    Genre currentGenre = Genre::Electronic;
    GenreProfile profile = getGenreProfile(Genre::Electronic);
};

//==============================================================================
/**
 * @brief Immersive Spatial Mix Renderer
 *
 * Rendert den Mix für verschiedene Formate:
 * - Stereo (mit Binaural)
 * - Surround 5.1 / 7.1
 * - Atmos / Spatial Audio
 * - Ambisonics (1st-3rd order)
 * - Binaural für Kopfhörer
 */
class SpatialMixRenderer
{
public:
    enum class OutputFormat
    {
        Stereo,
        Binaural,
        Surround51,
        Surround71,
        Atmos,
        AmbisonicsFirstOrder,
        AmbisonicsSecondOrder,
        AmbisonicsThirdOrder
    };

    struct RenderConfig
    {
        OutputFormat format = OutputFormat::Stereo;
        double sampleRate = 48000.0;
        int blockSize = 512;
        bool useHRTF = true;
        float roomSize = 1.0f;
        float reverbMix = 0.2f;
    };

    static SpatialMixRenderer& getInstance()
    {
        static SpatialMixRenderer instance;
        return instance;
    }

    void setConfig(const RenderConfig& cfg)
    {
        config = cfg;
        updateOutputChannels();
    }

    int getOutputChannelCount() const
    {
        switch (config.format)
        {
            case OutputFormat::Stereo: return 2;
            case OutputFormat::Binaural: return 2;
            case OutputFormat::Surround51: return 6;
            case OutputFormat::Surround71: return 8;
            case OutputFormat::Atmos: return 16;  // 7.1.4 + objects
            case OutputFormat::AmbisonicsFirstOrder: return 4;
            case OutputFormat::AmbisonicsSecondOrder: return 9;
            case OutputFormat::AmbisonicsThirdOrder: return 16;
            default: return 2;
        }
    }

    // Rendert alle Sources in Output-Buffer
    void render(const std::vector<SpatialSource>& sources,
                juce::AudioBuffer<float>& outputBuffer)
    {
        int numChannels = outputBuffer.getNumChannels();
        int numSamples = outputBuffer.getNumSamples();

        outputBuffer.clear();

        for (const auto& source : sources)
        {
            // Temporärer Source-Buffer (würde echte Audio-Daten enthalten)
            juce::AudioBuffer<float> sourceBuffer(1, numSamples);

            // Gain anwenden (inkl. AI-Suggestion)
            float gain = juce::Decibels::decibelsToGain(source.suggestedGainDb);

            // Räumliche Positionierung
            switch (config.format)
            {
                case OutputFormat::Stereo:
                    renderToStereo(source, sourceBuffer, outputBuffer, gain);
                    break;

                case OutputFormat::Binaural:
                    renderToBinaural(source, sourceBuffer, outputBuffer, gain);
                    break;

                case OutputFormat::Surround51:
                    renderToSurround51(source, sourceBuffer, outputBuffer, gain);
                    break;

                case OutputFormat::AmbisonicsFirstOrder:
                    renderToAmbisonics(source, sourceBuffer, outputBuffer, gain, 1);
                    break;

                default:
                    renderToStereo(source, sourceBuffer, outputBuffer, gain);
                    break;
            }
        }
    }

private:
    void updateOutputChannels()
    {
        outputChannels = getOutputChannelCount();
    }

    void renderToStereo(const SpatialSource& source,
                        const juce::AudioBuffer<float>& input,
                        juce::AudioBuffer<float>& output,
                        float gain)
    {
        float pan = (source.x + 1.0f) * 0.5f;  // 0-1
        float leftGain = std::sqrt(1.0f - pan) * gain;
        float rightGain = std::sqrt(pan) * gain;

        // Distance attenuation
        float distAtten = 1.0f / (1.0f + source.distance);
        leftGain *= distAtten;
        rightGain *= distAtten;

        // Mix in
        const float* src = input.getReadPointer(0);
        float* left = output.getWritePointer(0);
        float* right = output.getWritePointer(1);
        int numSamples = input.getNumSamples();

        for (int i = 0; i < numSamples; ++i)
        {
            left[i] += src[i] * leftGain;
            right[i] += src[i] * rightGain;
        }
    }

    void renderToBinaural(const SpatialSource& source,
                          const juce::AudioBuffer<float>& input,
                          juce::AudioBuffer<float>& output,
                          float gain)
    {
        // HRTF-based binaural rendering
        // Würde HRTF-Convolution verwenden

        // Berechne Azimuth und Elevation
        float azimuth = std::atan2(source.x, source.y);  // Radians
        float elevation = std::atan2(source.z,
            std::sqrt(source.x * source.x + source.y * source.y));

        // ITD (Interaural Time Difference)
        float itdSamples = 0.0f;
        if (config.useHRTF)
        {
            // ~0.7ms max ITD bei 17cm Kopfbreite
            float headWidth = 0.17f;
            float speedOfSound = 343.0f;
            float itdSeconds = (headWidth / speedOfSound) * std::sin(azimuth);
            itdSamples = static_cast<float>(itdSeconds * config.sampleRate);
        }

        // Vereinfachtes Rendering (vollständige Implementierung würde HRTF-Filter verwenden)
        renderToStereo(source, input, output, gain);
    }

    void renderToSurround51(const SpatialSource& source,
                             const juce::AudioBuffer<float>& input,
                             juce::AudioBuffer<float>& output,
                             float gain)
    {
        // 5.1 Channel Layout: L, R, C, LFE, Ls, Rs
        float x = source.x;
        float y = source.y;

        float distAtten = 1.0f / (1.0f + source.distance);
        gain *= distAtten;

        // VBAP-ähnliche Gains
        float leftGain = 0.0f, rightGain = 0.0f, centerGain = 0.0f;
        float lsGain = 0.0f, rsGain = 0.0f, lfeGain = 0.0f;

        if (y >= 0)  // Front
        {
            if (x < -0.5f)
                leftGain = gain;
            else if (x > 0.5f)
                rightGain = gain;
            else
            {
                centerGain = gain * (1.0f - std::abs(x) * 2.0f);
                leftGain = gain * juce::jmax(0.0f, -x);
                rightGain = gain * juce::jmax(0.0f, x);
            }
        }
        else  // Rear
        {
            if (x < 0)
                lsGain = gain;
            else
                rsGain = gain;
        }

        // LFE (Low Frequency Effects)
        lfeGain = gain * source.lowEnergy * 0.5f;

        // Apply to channels
        // (Full implementation would process sample buffers)
    }

    void renderToAmbisonics(const SpatialSource& source,
                             const juce::AudioBuffer<float>& input,
                             juce::AudioBuffer<float>& output,
                             float gain,
                             int order)
    {
        // Ambisonics encoding
        float azimuth = std::atan2(source.x, source.y);
        float elevation = std::atan2(source.z,
            std::sqrt(source.x * source.x + source.y * source.y));

        float distAtten = 1.0f / (1.0f + source.distance);
        gain *= distAtten;

        // First-order Ambisonics (W, X, Y, Z)
        float W = gain;  // Omnidirectional
        float X = gain * std::cos(azimuth) * std::cos(elevation);
        float Y = gain * std::sin(azimuth) * std::cos(elevation);
        float Z = gain * std::sin(elevation);

        // Encode into output channels
        const float* src = input.getReadPointer(0);
        int numSamples = input.getNumSamples();

        if (output.getNumChannels() >= 4)
        {
            float* w = output.getWritePointer(0);
            float* x = output.getWritePointer(1);
            float* y = output.getWritePointer(2);
            float* z = output.getWritePointer(3);

            for (int i = 0; i < numSamples; ++i)
            {
                w[i] += src[i] * W;
                x[i] += src[i] * X;
                y[i] += src[i] * Y;
                z[i] += src[i] * Z;
            }
        }
    }

    RenderConfig config;
    int outputChannels = 2;
};

//==============================================================================
/**
 * @brief AI Mix Visualization
 */
class AIMixVisualization : public juce::Component, private juce::Timer
{
public:
    AIMixVisualization()
    {
        startTimerHz(30);
    }

    void setAnalysis(const MixAnalysis& a)
    {
        analysis = a;
        repaint();
    }

    void setSources(const std::vector<SpatialSource>& s)
    {
        sources = s;
        repaint();
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        g.fillAll(juce::Colour(0xff0a0a12));

        // Spatial Map (top half)
        auto mapBounds = bounds.removeFromTop(bounds.getHeight() * 0.6f);
        drawSpatialMap(g, mapBounds);

        // Scores (bottom half)
        auto scoreBounds = bounds;
        drawScores(g, scoreBounds);
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    void drawSpatialMap(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        bounds = bounds.reduced(10);
        auto center = bounds.getCentre();
        float radius = juce::jmin(bounds.getWidth(), bounds.getHeight()) * 0.4f;

        // Grid
        g.setColour(juce::Colour(0xff303040));
        g.drawEllipse(center.x - radius, center.y - radius, radius * 2, radius * 2, 1.0f);
        g.drawEllipse(center.x - radius * 0.5f, center.y - radius * 0.5f, radius, radius, 0.5f);
        g.drawLine(center.x - radius, center.y, center.x + radius, center.y, 0.5f);
        g.drawLine(center.x, center.y - radius, center.x, center.y + radius, 0.5f);

        // Labels
        g.setColour(juce::Colours::grey);
        g.setFont(10.0f);
        g.drawText("Front", bounds.removeFromTop(15), juce::Justification::centred);
        g.drawText("L", juce::Rectangle<float>(bounds.getX(), center.y - 5, 15, 10), juce::Justification::centred);
        g.drawText("R", juce::Rectangle<float>(bounds.getRight() - 15, center.y - 5, 15, 10), juce::Justification::centred);

        // Sources
        for (const auto& source : sources)
        {
            float x = center.x + source.x * radius;
            float y = center.y - source.y * radius;  // Y is inverted

            // Size based on loudness
            float size = 10.0f + (source.lufs + 30.0f) * 0.3f;
            size = juce::jlimit(5.0f, 30.0f, size);

            // Color based on frequency content
            juce::Colour col = juce::Colour::fromHSV(
                source.highEnergy * 0.3f,  // Hue
                0.7f,
                0.9f,
                0.8f
            );

            g.setColour(col);
            g.fillEllipse(x - size/2, y - size/2, size, size);

            g.setColour(juce::Colours::white);
            g.setFont(8.0f);
            g.drawText(source.id, x - 20, y + size/2, 40, 12, juce::Justification::centred);
        }

        // Balance indicator
        if (std::abs(analysis.leftRightBalance) > 0.05f)
        {
            float indicatorX = center.x + analysis.leftRightBalance * radius;
            g.setColour(juce::Colours::yellow.withAlpha(0.5f));
            g.fillRect(indicatorX - 2, center.y - radius, 4.0f, radius * 2);
        }
    }

    void drawScores(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        bounds = bounds.reduced(10);

        g.setColour(juce::Colours::white);
        g.setFont(14.0f);
        g.drawText("Mix Score: " + juce::String(analysis.overallScore) + "/100",
                   bounds.removeFromTop(20), juce::Justification::centred);

        // Score bars
        struct ScoreBar { juce::String name; int score; juce::Colour colour; };
        std::vector<ScoreBar> bars = {
            { "Loudness", analysis.loudnessScore, juce::Colours::cyan },
            { "Spatial", analysis.spatialScore, juce::Colours::orange },
            { "Frequency", analysis.frequencyScore, juce::Colours::green },
            { "Dynamics", analysis.dynamicsScore, juce::Colours::purple },
            { "Clarity", analysis.clarityScore, juce::Colours::yellow }
        };

        float barHeight = 15.0f;
        float maxWidth = bounds.getWidth() * 0.6f;

        for (const auto& bar : bars)
        {
            auto row = bounds.removeFromTop(barHeight + 5);

            g.setColour(juce::Colours::grey);
            g.setFont(10.0f);
            g.drawText(bar.name, row.removeFromLeft(80), juce::Justification::right);
            row.removeFromLeft(10);

            auto barBounds = row.removeFromLeft(maxWidth);
            g.setColour(juce::Colour(0xff303040));
            g.fillRoundedRectangle(barBounds, 3.0f);

            float fillWidth = barBounds.getWidth() * bar.score / 100.0f;
            g.setColour(bar.colour);
            g.fillRoundedRectangle(barBounds.withWidth(fillWidth), 3.0f);

            g.setColour(juce::Colours::white);
            g.drawText(juce::String(bar.score), row, juce::Justification::left);
        }
    }

    MixAnalysis analysis;
    std::vector<SpatialSource> sources;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AIMixVisualization)
};

} // namespace AI
} // namespace Echoel
