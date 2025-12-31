#pragma once

#include <JuceHeader.h>
#include "PsychoacousticAnalyzer.h"
#include "../Core/DSPOptimizations.h"
#include <vector>
#include <array>
#include <cmath>

//==============================================================================
/**
 * @brief Spectral Masking Detector
 *
 * Detects frequency masking using psychoacoustic models.
 * Identifies where frequencies hide each other and suggests corrections.
 *
 * **SCIENTIFIC FOUNDATION**:
 *
 * 1. **Simultaneous Masking**:
 *    - When one sound masks another at the same time
 *    - Frequency-dependent spreading function
 *    - Critical band model (Bark scale)
 *
 * 2. **Spreading Function**:
 *    - Lower frequencies mask higher frequencies more (upward spread)
 *    - Spread = -27 + 0.37 × max(SPL - 40, 0)  [dB/Bark]
 *    - Asymmetric: stronger masking upwards than downwards
 *
 * 3. **Masking Threshold**:
 *    - Threshold in quiet (hearing threshold)
 *    - Masking curve from masker
 *    - Combined threshold = max(all maskers + hearing threshold)
 *
 * 4. **Detection Algorithm**:
 *    - Analyze spectrum in critical bands
 *    - Calculate masking contribution from each band
 *    - Identify masked frequencies (signal < threshold + margin)
 *    - Generate EQ suggestions to unmask
 *
 * References:
 * - Zwicker & Fastl (1999): "Psychoacoustics"
 * - Moore (2012): "An Introduction to the Psychology of Hearing"
 * - ISO/IEC 11172-3 (MPEG-1 Audio): Psychoacoustic Model
 */

//==============================================================================
/**
 * @brief Masking Curve Calculator
 *
 * Calculates the spreading function and masking threshold.
 */
class MaskingCurveCalculator
{
public:
    //==============================================================================
    /**
     * @brief Calculate masking spread to neighboring band
     *
     * @param maskerBark Masker center frequency (Bark)
     * @param maskeeBark Maskee center frequency (Bark)
     * @param maskerLevel Masker level (dB SPL)
     * @return Masking contribution (dB)
     */
    static float calculateSpread(float maskerBark, float maskeeBark, float maskerLevel)
    {
        float deltaB bark = maskeeBark - maskerBark;  // Bark difference

        // Spreading function (Zwicker & Fastl)
        float spread = 0.0f;

        if (deltaBark >= 0.0f)
        {
            // Upward masking (lower freq masks higher freq)
            spread = -27.0f + 0.37f * juce::jmax(maskerLevel - 40.0f, 0.0f);
            spread *= deltaBark;
        }
        else
        {
            // Downward masking (weaker)
            spread = -27.0f;
            spread *= std::abs(deltaBark) * 0.5f;  // Less spreading downwards
        }

        return juce::jmax(spread, -60.0f);  // Limit to -60 dB
    }

    //==============================================================================
    /**
     * @brief Calculate masking threshold at frequency
     *
     * @param targetBark Target frequency (Bark)
     * @param maskerBark Masker frequency (Bark)
     * @param maskerLevel Masker level (dB SPL)
     * @return Masking threshold (dB SPL)
     */
    static float calculateMaskingThreshold(float targetBark, float maskerBark, float maskerLevel)
    {
        float spread = calculateSpread(maskerBark, targetBark, maskerLevel);
        return maskerLevel + spread;
    }

    //==============================================================================
    /**
     * @brief Calculate combined masking threshold from multiple maskers
     *
     * @param targetBark Target frequency (Bark)
     * @param maskerBarkLevels Array of {bark, level} pairs
     * @return Combined masking threshold (dB SPL)
     */
    static float calculateCombinedThreshold(float targetBark,
                                            const std::vector<std::pair<float, float>>& maskerBarkLevels)
    {
        // Hearing threshold in quiet
        float targetFreq = BarkScale::barkToHz(targetBark);
        float hearingThreshold = getHearingThreshold(targetFreq);

        // Calculate masking from all maskers (power sum)
        float totalMaskingPower = 0.0f;

        for (const auto& [maskerBark, maskerLevel] : maskerBarkLevels)
        {
            if (maskerLevel > 0.0f)
            {
                float maskingThreshold = calculateMaskingThreshold(targetBark, maskerBark, maskerLevel);
                float maskingPower = Echoel::DSP::FastMath::fastPow(10.0f, maskingThreshold / 10.0f);
                totalMaskingPower += maskingPower;
            }
        }

        // Convert back to dB
        float combinedMasking = 10.0f * std::log10(totalMaskingPower + 1e-10f);

        // Return max of masking and hearing threshold
        return juce::jmax(combinedMasking, hearingThreshold);
    }

private:
    static float getHearingThreshold(float frequencyHz)
    {
        // Simplified hearing threshold curve
        if (frequencyHz < 1000.0f)
            return 20.0f - 10.0f * std::log10(frequencyHz / 20.0f);
        else if (frequencyHz > 10000.0f)
            return 10.0f + 15.0f * std::log10(frequencyHz / 10000.0f);
        else
            return 0.0f;
    }
};

//==============================================================================
/**
 * @brief Spectral Masking Detector
 *
 * Detects masking between frequency bands and suggests corrections.
 */
class SpectralMaskingDetector
{
public:
    //==============================================================================
    struct MaskingInfo
    {
        int maskingBand;           // Band causing masking
        int maskedBand;            // Band being masked
        float maskingAmount;       // Masking severity (dB)
        float suggestedBoost;      // Suggested EQ boost (dB)
        float suggestedCut;        // Suggested EQ cut on masker (dB)
    };

    //==============================================================================
    SpectralMaskingDetector()
    {
        criticalBandLevels.fill(0.0f);
        maskingThresholds.fill(0.0f);
    }

    //==============================================================================
    /**
     * @brief Analyze spectrum for masking
     *
     * @param spectrumDb Spectrum in dB per critical band (24 bands)
     */
    void analyzeSpectrum(const std::array<float, 24>& spectrumDb)
    {
        criticalBandLevels = spectrumDb;

        // Calculate masking thresholds
        updateMaskingThresholds();

        // Detect masked bands
        detectMaskedBands();
    }

    //==============================================================================
    /**
     * @brief Get masking threshold for band
     *
     * @param bandIndex Band index (0-23)
     * @return Masking threshold (dB SPL)
     */
    float getMaskingThreshold(int bandIndex) const
    {
        if (bandIndex < 0 || bandIndex >= 24)
            return 0.0f;

        return maskingThresholds[bandIndex];
    }

    //==============================================================================
    /**
     * @brief Check if band is masked
     *
     * @param bandIndex Band index (0-23)
     * @param marginDb Safety margin (dB) - signal must be this much above threshold
     * @return True if band is masked
     */
    bool isBandMasked(int bandIndex, float marginDb = 6.0f) const
    {
        if (bandIndex < 0 || bandIndex >= 24)
            return false;

        float signalLevel = criticalBandLevels[bandIndex];
        float threshold = maskingThresholds[bandIndex];

        return signalLevel < (threshold + marginDb);
    }

    //==============================================================================
    /**
     * @brief Get all detected masking issues
     *
     * @param marginDb Safety margin (dB)
     * @return Vector of masking info structures
     */
    std::vector<MaskingInfo> getMaskingIssues(float marginDb = 6.0f) const
    {
        std::vector<MaskingInfo> issues;

        for (int masked = 0; masked < 24; ++masked)
        {
            if (isBandMasked(masked, marginDb))
            {
                // Find strongest masker
                int strongestMasker = -1;
                float strongestMasking = 0.0f;

                for (int masker = 0; masker < 24; ++masker)
                {
                    if (masker == masked)
                        continue;

                    float maskerBark = static_cast<float>(masker);
                    float maskedBark = static_cast<float>(masked);
                    float maskerLevel = criticalBandLevels[masker];

                    float maskingContribution = MaskingCurveCalculator::calculateMaskingThreshold(
                        maskedBark, maskerBark, maskerLevel
                    );

                    if (maskingContribution > strongestMasking)
                    {
                        strongestMasking = maskingContribution;
                        strongestMasker = masker;
                    }
                }

                if (strongestMasker >= 0)
                {
                    MaskingInfo info;
                    info.maskingBand = strongestMasker;
                    info.maskedBand = masked;
                    info.maskingAmount = maskingThresholds[masked] - criticalBandLevels[masked];
                    info.suggestedBoost = juce::jmin(info.maskingAmount + marginDb, 12.0f);  // Max +12 dB
                    info.suggestedCut = juce::jmin(info.maskingAmount * 0.5f, 6.0f);  // Max -6 dB

                    issues.push_back(info);
                }
            }
        }

        return issues;
    }

    //==============================================================================
    /**
     * @brief Get masking severity (0-1)
     *
     * 0 = no masking, 1 = severe masking
     *
     * @return Overall masking severity
     */
    float getMaskingSeverity() const
    {
        float totalMasking = 0.0f;
        int maskedCount = 0;

        for (int i = 0; i < 24; ++i)
        {
            if (isBandMasked(i))
            {
                float maskingAmount = maskingThresholds[i] - criticalBandLevels[i];
                totalMasking += maskingAmount;
                maskedCount++;
            }
        }

        if (maskedCount == 0)
            return 0.0f;

        // Normalize to 0-1 (assume 12 dB average masking = 1.0)
        return juce::jlimit(0.0f, 1.0f, totalMasking / (maskedCount * 12.0f));
    }

private:
    //==============================================================================
    void updateMaskingThresholds()
    {
        for (int target = 0; target < 24; ++target)
        {
            std::vector<std::pair<float, float>> maskers;

            for (int masker = 0; masker < 24; ++masker)
            {
                if (criticalBandLevels[masker] > 0.0f)
                {
                    maskers.push_back({static_cast<float>(masker), criticalBandLevels[masker]});
                }
            }

            float threshold = MaskingCurveCalculator::calculateCombinedThreshold(
                static_cast<float>(target), maskers
            );

            maskingThresholds[target] = threshold;
        }
    }

    void detectMaskedBands()
    {
        // Already done in getMaskingIssues() - this could update internal state if needed
    }

    //==============================================================================
    std::array<float, 24> criticalBandLevels;    // Current spectrum (dB SPL)
    std::array<float, 24> maskingThresholds;     // Calculated masking thresholds (dB SPL)

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectralMaskingDetector)
};

//==============================================================================
/**
 * @brief Multi-Track Masking Analyzer
 *
 * Analyzes masking between multiple tracks (e.g., instruments in a mix).
 */
class MultiTrackMaskingAnalyzer
{
public:
    //==============================================================================
    struct TrackMaskingInfo
    {
        juce::String trackName;
        int trackIndex;
        std::array<float, 24> spectrum;        // Spectrum per band
        float totalLoudness;                   // Total loudness (sones)
        std::vector<int> maskedByTracks;       // Track indices masking this track
        std::vector<int> maskesTracks;         // Track indices masked by this track
    };

    //==============================================================================
    /**
     * @brief Add track for analysis
     *
     * @param trackName Track name
     * @param spectrum Spectrum in dB per critical band
     */
    void addTrack(const juce::String& trackName, const std::array<float, 24>& spectrum)
    {
        TrackMaskingInfo info;
        info.trackName = trackName;
        info.trackIndex = static_cast<int>(tracks.size());
        info.spectrum = spectrum;
        info.totalLoudness = 0.0f;  // Calculate later

        tracks.push_back(info);
    }

    /**
     * @brief Clear all tracks
     */
    void clearTracks()
    {
        tracks.clear();
    }

    /**
     * @brief Analyze masking between all tracks
     */
    void analyze()
    {
        // Analyze each pair of tracks
        for (size_t i = 0; i < tracks.size(); ++i)
        {
            for (size_t j = 0; j < tracks.size(); ++j)
            {
                if (i == j)
                    continue;

                // Check if track i masks track j
                if (checkMasking(tracks[i].spectrum, tracks[j].spectrum))
                {
                    tracks[i].maskesTracks.push_back(static_cast<int>(j));
                    tracks[j].maskedByTracks.push_back(static_cast<int>(i));
                }
            }
        }
    }

    /**
     * @brief Get masking info for track
     *
     * @param trackIndex Track index
     * @return Track masking info
     */
    const TrackMaskingInfo* getTrackInfo(int trackIndex) const
    {
        if (trackIndex < 0 || trackIndex >= static_cast<int>(tracks.size()))
            return nullptr;

        return &tracks[trackIndex];
    }

    /**
     * @brief Get number of tracks
     */
    int getNumTracks() const
    {
        return static_cast<int>(tracks.size());
    }

private:
    //==============================================================================
    bool checkMasking(const std::array<float, 24>& maskerSpectrum,
                     const std::array<float, 24>& maskeeSpectrum) const
    {
        // Check if masker has significantly higher level in any band
        int maskedBands = 0;

        for (int band = 0; band < 24; ++band)
        {
            float difference = maskerSpectrum[band] - maskeeSpectrum[band];
            if (difference > 6.0f)  // 6 dB threshold
                maskedBands++;
        }

        // Consider masking if >25% of bands are masked
        return maskedBands > 6;
    }

    //==============================================================================
    std::vector<TrackMaskingInfo> tracks;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MultiTrackMaskingAnalyzer)
};
