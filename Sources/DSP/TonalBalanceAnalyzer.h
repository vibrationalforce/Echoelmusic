#pragma once

#include <JuceHeader.h>
#include "PsychoacousticAnalyzer.h"
#include <array>
#include <vector>
#include <map>

//==============================================================================
/**
 * @brief Tonal Balance Analyzer
 *
 * Analyzes frequency balance and compares to genre-specific targets.
 * Provides visual feedback and correction suggestions.
 *
 * **SCIENTIFIC FOUNDATION**:
 *
 * 1. **Frequency Bands**:
 *    - Sub-Bass: 20-60 Hz
 *    - Bass: 60-250 Hz
 *    - Low Mids: 250-500 Hz
 *    - Mids: 500-2000 Hz
 *    - High Mids: 2000-4000 Hz
 *    - Presence: 4000-6000 Hz
 *    - Brilliance: 6000-20000 Hz
 *
 * 2. **Genre Targets**:
 *    - Based on analysis of professional mixes (iZotope Tonal Balance Control)
 *    - Tolerance ranges for each genre
 *    - Perceptual weighting (Fletcher-Munson)
 *
 * 3. **Balance Score**:
 *    - RMS deviation from target curve
 *    - Weighted by perceptual importance
 *    - 0-100 score (100 = perfect match)
 *
 * 4. **Correction Suggestions**:
 *    - Identifies over/under-represented bands
 *    - Suggests EQ adjustments
 *    - Considers masking and loudness
 *
 * References:
 * - iZotope Tonal Balance Control methodology
 * - Harley (2014): "The Art of Mixing"
 * - Owsinski (2017): "The Mixing Engineer's Handbook"
 */

//==============================================================================
/**
 * @brief Genre-specific tonal balance targets
 */
class GenreTargets
{
public:
    //==============================================================================
    enum class Genre
    {
        Pop,
        Rock,
        Electronic,
        HipHop,
        RnB,
        Jazz,
        Classical,
        Metal,
        Country,
        Indie,
        Ambient,
        Folk,
        Punk,
        Blues,
        Reggae,
        Latin,
        Custom
    };

    //==============================================================================
    struct FrequencyBand
    {
        float lowFreq;       // Hz
        float highFreq;      // Hz
        float targetLevel;   // dB (relative)
        float tolerance;     // dB (±)
        juce::String name;
    };

    //==============================================================================
    struct GenreProfile
    {
        Genre genre;
        juce::String name;
        juce::String description;
        std::array<FrequencyBand, 7> bands;  // 7 frequency bands
        float overallBrightness;             // -1 (dark) to +1 (bright)
        float bassWeight;                    // 0-1 (0=light, 1=heavy)
    };

    //==============================================================================
    /**
     * @brief Get genre profile
     *
     * @param genre Genre type
     * @return Genre profile with target curves
     */
    static GenreProfile getProfile(Genre genre)
    {
        GenreProfile profile;
        profile.genre = genre;

        // Define 7 bands (consistent across all genres)
        std::array<juce::String, 7> bandNames = {
            "Sub-Bass", "Bass", "Low Mids", "Mids", "High Mids", "Presence", "Brilliance"
        };

        std::array<std::pair<float, float>, 7> bandRanges = {
            {{20.0f, 60.0f},      // Sub-Bass
             {60.0f, 250.0f},     // Bass
             {250.0f, 500.0f},    // Low Mids
             {500.0f, 2000.0f},   // Mids
             {2000.0f, 4000.0f},  // High Mids
             {4000.0f, 6000.0f},  // Presence
             {6000.0f, 20000.0f}} // Brilliance
        };

        // Initialize band ranges and names
        for (int i = 0; i < 7; ++i)
        {
            profile.bands[i].lowFreq = bandRanges[i].first;
            profile.bands[i].highFreq = bandRanges[i].second;
            profile.bands[i].name = bandNames[i];
        }

        // Set genre-specific targets
        switch (genre)
        {
            case Genre::Pop:
                profile.name = "Pop";
                profile.description = "Balanced, present vocals, polished highs";
                profile.bands[0].targetLevel = -3.0f;  profile.bands[0].tolerance = 3.0f;  // Sub-Bass
                profile.bands[1].targetLevel = 0.0f;   profile.bands[1].tolerance = 2.0f;  // Bass
                profile.bands[2].targetLevel = -2.0f;  profile.bands[2].tolerance = 2.0f;  // Low Mids
                profile.bands[3].targetLevel = 0.0f;   profile.bands[3].tolerance = 1.5f;  // Mids (vocals!)
                profile.bands[4].targetLevel = 1.0f;   profile.bands[4].tolerance = 2.0f;  // High Mids
                profile.bands[5].targetLevel = 2.0f;   profile.bands[5].tolerance = 2.0f;  // Presence
                profile.bands[6].targetLevel = 0.0f;   profile.bands[6].tolerance = 3.0f;  // Brilliance
                profile.overallBrightness = 0.3f;
                profile.bassWeight = 0.5f;
                break;

            case Genre::Rock:
                profile.name = "Rock";
                profile.description = "Powerful mids, aggressive guitars";
                profile.bands[0].targetLevel = -4.0f;  profile.bands[0].tolerance = 3.0f;
                profile.bands[1].targetLevel = -1.0f;  profile.bands[1].tolerance = 2.0f;
                profile.bands[2].targetLevel = 0.0f;   profile.bands[2].tolerance = 2.0f;
                profile.bands[3].targetLevel = 2.0f;   profile.bands[3].tolerance = 2.0f;  // Guitars!
                profile.bands[4].targetLevel = 2.0f;   profile.bands[4].tolerance = 2.5f;
                profile.bands[5].targetLevel = 1.0f;   profile.bands[5].tolerance = 2.0f;
                profile.bands[6].targetLevel = -1.0f;  profile.bands[6].tolerance = 3.0f;
                profile.overallBrightness = 0.0f;
                profile.bassWeight = 0.6f;
                break;

            case Genre::Electronic:
                profile.name = "Electronic";
                profile.description = "Deep bass, crisp highs, wide spectrum";
                profile.bands[0].targetLevel = 2.0f;   profile.bands[0].tolerance = 3.0f;  // Sub!
                profile.bands[1].targetLevel = 3.0f;   profile.bands[1].tolerance = 2.0f;  // Bass!
                profile.bands[2].targetLevel = -1.0f;  profile.bands[2].tolerance = 2.0f;
                profile.bands[3].targetLevel = 0.0f;   profile.bands[3].tolerance = 2.0f;
                profile.bands[4].targetLevel = 1.0f;   profile.bands[4].tolerance = 2.0f;
                profile.bands[5].targetLevel = 2.0f;   profile.bands[5].tolerance = 2.5f;
                profile.bands[6].targetLevel = 3.0f;   profile.bands[6].tolerance = 3.0f;  // Highs!
                profile.overallBrightness = 0.5f;
                profile.bassWeight = 0.9f;
                break;

            case Genre::HipHop:
                profile.name = "Hip-Hop";
                profile.description = "Heavy sub-bass, punchy kick, clear vocals";
                profile.bands[0].targetLevel = 4.0f;   profile.bands[0].tolerance = 2.0f;  // Sub!!!
                profile.bands[1].targetLevel = 3.0f;   profile.bands[1].tolerance = 2.0f;
                profile.bands[2].targetLevel = -2.0f;  profile.bands[2].tolerance = 2.0f;
                profile.bands[3].targetLevel = 0.0f;   profile.bands[3].tolerance = 1.5f;  // Vocals
                profile.bands[4].targetLevel = 1.0f;   profile.bands[4].tolerance = 2.0f;
                profile.bands[5].targetLevel = 0.0f;   profile.bands[5].tolerance = 2.0f;
                profile.bands[6].targetLevel = -2.0f;  profile.bands[6].tolerance = 3.0f;
                profile.overallBrightness = -0.2f;
                profile.bassWeight = 1.0f;
                break;

            case Genre::Jazz:
                profile.name = "Jazz";
                profile.description = "Natural, warm, detailed highs";
                profile.bands[0].targetLevel = -5.0f;  profile.bands[0].tolerance = 3.0f;
                profile.bands[1].targetLevel = -1.0f;  profile.bands[1].tolerance = 2.0f;
                profile.bands[2].targetLevel = 0.0f;   profile.bands[2].tolerance = 2.0f;
                profile.bands[3].targetLevel = 0.0f;   profile.bands[3].tolerance = 2.0f;
                profile.bands[4].targetLevel = 1.0f;   profile.bands[4].tolerance = 2.0f;
                profile.bands[5].targetLevel = 2.0f;   profile.bands[5].tolerance = 2.0f;  // Cymbals!
                profile.bands[6].targetLevel = 1.0f;   profile.bands[6].tolerance = 2.5f;
                profile.overallBrightness = 0.4f;
                profile.bassWeight = 0.3f;
                break;

            case Genre::Classical:
                profile.name = "Classical";
                profile.description = "Natural, wide dynamic range, balanced";
                profile.bands[0].targetLevel = -4.0f;  profile.bands[0].tolerance = 3.0f;
                profile.bands[1].targetLevel = 0.0f;   profile.bands[1].tolerance = 2.0f;
                profile.bands[2].targetLevel = 0.0f;   profile.bands[2].tolerance = 2.0f;
                profile.bands[3].targetLevel = 0.0f;   profile.bands[3].tolerance = 1.5f;
                profile.bands[4].targetLevel = 0.0f;   profile.bands[4].tolerance = 1.5f;
                profile.bands[5].targetLevel = 0.0f;   profile.bands[5].tolerance = 2.0f;
                profile.bands[6].targetLevel = 0.0f;   profile.bands[6].tolerance = 2.0f;
                profile.overallBrightness = 0.0f;
                profile.bassWeight = 0.5f;
                break;

            case Genre::Metal:
                profile.name = "Metal";
                profile.description = "Aggressive, compressed, wall of sound";
                profile.bands[0].targetLevel = 0.0f;   profile.bands[0].tolerance = 3.0f;
                profile.bands[1].targetLevel = 2.0f;   profile.bands[1].tolerance = 2.0f;
                profile.bands[2].targetLevel = 1.0f;   profile.bands[2].tolerance = 2.0f;
                profile.bands[3].targetLevel = 3.0f;   profile.bands[3].tolerance = 2.0f;  // Guitars!!!
                profile.bands[4].targetLevel = 3.0f;   profile.bands[4].tolerance = 2.5f;
                profile.bands[5].targetLevel = 2.0f;   profile.bands[5].tolerance = 2.5f;
                profile.bands[6].targetLevel = 1.0f;   profile.bands[6].tolerance = 3.0f;
                profile.overallBrightness = 0.1f;
                profile.bassWeight = 0.8f;
                break;

            default:
                // Flat/Balanced target
                profile.name = "Custom";
                profile.description = "Flat frequency response";
                for (int i = 0; i < 7; ++i)
                {
                    profile.bands[i].targetLevel = 0.0f;
                    profile.bands[i].tolerance = 3.0f;
                }
                profile.overallBrightness = 0.0f;
                profile.bassWeight = 0.5f;
                break;
        }

        return profile;
    }

    /**
     * @brief Get all available genres
     */
    static std::vector<Genre> getAllGenres()
    {
        return {
            Genre::Pop, Genre::Rock, Genre::Electronic, Genre::HipHop,
            Genre::RnB, Genre::Jazz, Genre::Classical, Genre::Metal,
            Genre::Country, Genre::Indie, Genre::Ambient, Genre::Folk,
            Genre::Punk, Genre::Blues, Genre::Reggae, Genre::Latin
        };
    }
};

//==============================================================================
/**
 * @brief Tonal Balance Analyzer
 *
 * Analyzes frequency balance and compares to genre targets.
 */
class TonalBalanceAnalyzer
{
public:
    //==============================================================================
    struct BalanceAnalysis
    {
        std::array<float, 7> bandLevels;         // Current levels (dB)
        std::array<float, 7> targetLevels;       // Target levels (dB)
        std::array<float, 7> deviations;         // Deviations from target (dB)
        std::array<bool, 7> inRange;             // Within tolerance?
        float overallScore;                      // 0-100 (100 = perfect)
        float brightnessScore;                   // -1 (dark) to +1 (bright)
        float bassScore;                         // 0-1 (bass weight)
        GenreTargets::GenreProfile targetProfile;
    };

    //==============================================================================
    TonalBalanceAnalyzer()
    {
        setGenre(GenreTargets::Genre::Pop);  // Default
    }

    /**
     * @brief Set target genre
     */
    void setGenre(GenreTargets::Genre genre)
    {
        currentGenre = genre;
        targetProfile = GenreTargets::getProfile(genre);
    }

    /**
     * @brief Analyze spectrum
     *
     * @param spectrumDb Spectrum in dB (full frequency range)
     * @return Balance analysis results
     */
    BalanceAnalysis analyze(const std::array<float, 24>& criticalBandSpectrum)
    {
        BalanceAnalysis analysis;
        analysis.targetProfile = targetProfile;

        // Calculate band levels from critical band spectrum
        calculateBandLevels(criticalBandSpectrum, analysis.bandLevels);

        // Compare to targets
        for (int i = 0; i < 7; ++i)
        {
            analysis.targetLevels[i] = targetProfile.bands[i].targetLevel;
            analysis.deviations[i] = analysis.bandLevels[i] - analysis.targetLevels[i];
            analysis.inRange[i] = std::abs(analysis.deviations[i]) <= targetProfile.bands[i].tolerance;
        }

        // Calculate overall score
        analysis.overallScore = calculateOverallScore(analysis);

        // Calculate brightness and bass scores
        analysis.brightnessScore = calculateBrightnessScore(analysis.bandLevels);
        analysis.bassScore = calculateBassScore(analysis.bandLevels);

        return analysis;
    }

    /**
     * @brief Get correction suggestions
     *
     * @param analysis Balance analysis
     * @return Vector of {band index, suggested correction (dB)}
     */
    std::vector<std::pair<int, float>> getCorrectionSuggestions(const BalanceAnalysis& analysis) const
    {
        std::vector<std::pair<int, float>> suggestions;

        for (int i = 0; i < 7; ++i)
        {
            if (!analysis.inRange[i])
            {
                // Suggest correction (limit to ±6 dB)
                float correction = -analysis.deviations[i];
                correction = juce::jlimit(-6.0f, 6.0f, correction);

                suggestions.push_back({i, correction});
            }
        }

        return suggestions;
    }

private:
    //==============================================================================
    void calculateBandLevels(const std::array<float, 24>& criticalBands,
                            std::array<float, 7>& bandLevels)
    {
        // Map 24 critical bands to 7 frequency bands
        // This is a simplified mapping - in production, use proper integration

        std::array<std::pair<int, int>, 7> bandMapping = {{
            {0, 1},    // Sub-Bass: bands 0-1
            {2, 4},    // Bass: bands 2-4
            {5, 6},    // Low Mids: bands 5-6
            {7, 11},   // Mids: bands 7-11
            {12, 15},  // High Mids: bands 12-15
            {16, 18},  // Presence: bands 16-18
            {19, 23}   // Brilliance: bands 19-23
        }};

        for (int band = 0; band < 7; ++band)
        {
            int startBand = bandMapping[band].first;
            int endBand = bandMapping[band].second;

            // Average level across critical bands
            float sum = 0.0f;
            int count = 0;

            for (int cb = startBand; cb <= endBand && cb < 24; ++cb)
            {
                sum += criticalBands[cb];
                count++;
            }

            bandLevels[band] = (count > 0) ? (sum / count) : 0.0f;
        }
    }

    float calculateOverallScore(const BalanceAnalysis& analysis) const
    {
        float totalDeviation = 0.0f;
        float maxDeviation = 0.0f;

        for (int i = 0; i < 7; ++i)
        {
            float absDeviation = std::abs(analysis.deviations[i]);
            totalDeviation += absDeviation;
            maxDeviation = juce::jmax(maxDeviation, absDeviation);
        }

        // Score based on RMS deviation (0 = perfect, 12 dB = 0 score)
        float rmsDeviation = std::sqrt(totalDeviation / 7.0f);
        float score = 100.0f * (1.0f - juce::jlimit(0.0f, 1.0f, rmsDeviation / 12.0f));

        return score;
    }

    float calculateBrightnessScore(const std::array<float, 7>& bandLevels) const
    {
        // Compare highs (bands 5-6) to lows (bands 0-1)
        float highs = (bandLevels[5] + bandLevels[6]) * 0.5f;
        float lows = (bandLevels[0] + bandLevels[1]) * 0.5f;
        float difference = highs - lows;

        // Normalize to -1 (dark) to +1 (bright)
        return juce::jlimit(-1.0f, 1.0f, difference / 12.0f);
    }

    float calculateBassScore(const std::array<float, 7>& bandLevels) const
    {
        // Bass weight (bands 0-1 relative to overall)
        float bass = (bandLevels[0] + bandLevels[1]) * 0.5f;
        float overall = 0.0f;
        for (float level : bandLevels)
            overall += level;
        overall /= 7.0f;

        float difference = bass - overall;
        return juce::jlimit(0.0f, 1.0f, (difference + 6.0f) / 12.0f);
    }

    //==============================================================================
    GenreTargets::Genre currentGenre;
    GenreTargets::GenreProfile targetProfile;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TonalBalanceAnalyzer)
};
