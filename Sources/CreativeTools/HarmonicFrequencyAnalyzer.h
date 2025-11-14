#pragma once

#include <JuceHeader.h>
#include <cmath>
#include <vector>
#include <array>

//==============================================================================
/**
 * @brief Harmonic Frequency Analyzer & Generator
 *
 * Professional harmonic analysis tools based on:
 * - Sengpielaudio.com (frequency calculations)
 * - Music theory (harmonic series, overtones)
 * - Psychoacoustics (critical bands, consonance/dissonance)
 * - Golden Ratio & Fibonacci tuning
 *
 * **Scientific Foundation**:
 * 1. **Harmonic Series**: f_n = f₀ × n (n = 1, 2, 3, ...)
 *    - Fundamental (f₀), 2nd harmonic (2×f₀), 3rd (3×f₀), etc.
 *
 * 2. **Subharmonics**: f_n = f₀ / n
 *    - Rarely occurs naturally, but useful for synthesis
 *
 * 3. **Musical Intervals**:
 *    - Octave: 2:1 ratio
 *    - Perfect Fifth: 3:2 ratio
 *    - Perfect Fourth: 4:3 ratio
 *    - Major Third: 5:4 ratio
 *
 * 4. **Golden Ratio**: φ = 1.618033988749...
 *    - Used in alternative tunings, spectral composition
 *
 * 5. **Equal Temperament**: f_n = f₀ × 2^(n/12)
 *    - Standard Western tuning (12-TET)
 *
 * References:
 * - https://www.sengpielaudio.com/calculator-notenames.htm
 * - https://www.sengpielaudio.com/calculator-centsratio.htm
 * - Helmholtz, H. (1863): "On the Sensations of Tone"
 */
class HarmonicFrequencyAnalyzer
{
public:
    //==============================================================================
    // Musical interval ratios (Just Intonation)

    static constexpr float RATIO_OCTAVE = 2.0f;
    static constexpr float RATIO_PERFECT_FIFTH = 3.0f / 2.0f;
    static constexpr float RATIO_PERFECT_FOURTH = 4.0f / 3.0f;
    static constexpr float RATIO_MAJOR_THIRD = 5.0f / 4.0f;
    static constexpr float RATIO_MINOR_THIRD = 6.0f / 5.0f;
    static constexpr float RATIO_MAJOR_SIXTH = 5.0f / 3.0f;
    static constexpr float RATIO_MINOR_SIXTH = 8.0f / 5.0f;
    static constexpr float RATIO_MAJOR_SECOND = 9.0f / 8.0f;
    static constexpr float RATIO_MINOR_SEVENTH = 16.0f / 9.0f;

    // Golden ratio & Fibonacci
    static constexpr float GOLDEN_RATIO = 1.618033988749f;
    static constexpr float INVERSE_GOLDEN_RATIO = 0.618033988749f;

    //==============================================================================
    struct HarmonicSeries
    {
        float fundamental = 440.0f;
        std::vector<float> harmonics;
        std::vector<float> amplitudes;  // Relative amplitudes (0-1)
    };

    //==============================================================================
    /**
     * @brief Generate harmonic overtone series
     *
     * Natural harmonic series: f, 2f, 3f, 4f, 5f, 6f, ...
     *
     * Amplitude decay based on typical natural sounds:
     * - Sawtooth-like: A_n = 1/n (strong harmonics)
     * - Square-like: A_n = 1/n (odd harmonics only)
     * - Triangle-like: A_n = 1/n² (soft harmonics)
     * - Natural instruments: varies, typically 1/n to 1/n²
     */
    static HarmonicSeries generateHarmonics(float fundamentalHz,
                                           int numHarmonics = 16,
                                           float amplitudeDecay = 1.0f)
    {
        HarmonicSeries series;
        series.fundamental = fundamentalHz;
        series.harmonics.reserve(numHarmonics);
        series.amplitudes.reserve(numHarmonics);

        for (int n = 1; n <= numHarmonics; ++n)
        {
            // Calculate harmonic frequency
            float harmonicFreq = fundamentalHz * static_cast<float>(n);

            // Calculate amplitude (1/n decay with adjustable exponent)
            float amplitude = 1.0f / std::pow(static_cast<float>(n), amplitudeDecay);

            series.harmonics.push_back(harmonicFreq);
            series.amplitudes.push_back(amplitude);
        }

        return series;
    }

    /**
     * @brief Generate subharmonic series
     *
     * Subharmonics: f, f/2, f/3, f/4, ...
     * Rarely occurs in nature, but useful for synthesis (bass extension).
     */
    static HarmonicSeries generateSubharmonics(float fundamentalHz,
                                              int numSubharmonics = 8)
    {
        HarmonicSeries series;
        series.fundamental = fundamentalHz;
        series.harmonics.reserve(numSubharmonics);
        series.amplitudes.reserve(numSubharmonics);

        for (int n = 1; n <= numSubharmonics; ++n)
        {
            float subharmonicFreq = fundamentalHz / static_cast<float>(n);
            float amplitude = 1.0f / static_cast<float>(n);  // Simple decay

            series.harmonics.push_back(subharmonicFreq);
            series.amplitudes.push_back(amplitude);
        }

        return series;
    }

    //==============================================================================
    /**
     * @brief Calculate musical interval frequency
     *
     * Returns frequency at given interval ratio from fundamental.
     */
    static float calculateInterval(float fundamentalHz, float ratio)
    {
        return fundamentalHz * ratio;
    }

    /**
     * @brief Generate chord frequencies (Just Intonation)
     */
    static std::vector<float> generateChord(float rootHz, const juce::String& chordType)
    {
        std::vector<float> chord;

        if (chordType == "Major")
        {
            chord.push_back(rootHz);                                    // Root
            chord.push_back(rootHz * RATIO_MAJOR_THIRD);               // Major 3rd
            chord.push_back(rootHz * RATIO_PERFECT_FIFTH);             // Perfect 5th
        }
        else if (chordType == "Minor")
        {
            chord.push_back(rootHz);                                    // Root
            chord.push_back(rootHz * RATIO_MINOR_THIRD);               // Minor 3rd
            chord.push_back(rootHz * RATIO_PERFECT_FIFTH);             // Perfect 5th
        }
        else if (chordType == "Diminished")
        {
            chord.push_back(rootHz);                                    // Root
            chord.push_back(rootHz * RATIO_MINOR_THIRD);               // Minor 3rd
            chord.push_back(rootHz * RATIO_MINOR_THIRD * RATIO_MINOR_THIRD);  // Diminished 5th
        }
        else if (chordType == "Augmented")
        {
            chord.push_back(rootHz);                                    // Root
            chord.push_back(rootHz * RATIO_MAJOR_THIRD);               // Major 3rd
            chord.push_back(rootHz * RATIO_MAJOR_THIRD * RATIO_MAJOR_THIRD);  // Augmented 5th
        }
        else if (chordType == "Sus2")
        {
            chord.push_back(rootHz);                                    // Root
            chord.push_back(rootHz * RATIO_MAJOR_SECOND);              // Major 2nd
            chord.push_back(rootHz * RATIO_PERFECT_FIFTH);             // Perfect 5th
        }
        else if (chordType == "Sus4")
        {
            chord.push_back(rootHz);                                    // Root
            chord.push_back(rootHz * RATIO_PERFECT_FOURTH);            // Perfect 4th
            chord.push_back(rootHz * RATIO_PERFECT_FIFTH);             // Perfect 5th
        }

        return chord;
    }

    //==============================================================================
    /**
     * @brief Calculate frequency from MIDI note number
     *
     * Equal Temperament: f = 440 × 2^((n-69)/12)
     * - MIDI 69 = A4 = 440 Hz
     */
    static float midiNoteToFrequency(int midiNote)
    {
        return 440.0f * std::pow(2.0f, (static_cast<float>(midiNote) - 69.0f) / 12.0f);
    }

    /**
     * @brief Calculate MIDI note from frequency (reverse)
     */
    static int frequencyToMidiNote(float frequency)
    {
        return static_cast<int>(std::round(69.0f + 12.0f * std::log2(frequency / 440.0f)));
    }

    /**
     * @brief Calculate cents deviation from nearest MIDI note
     *
     * Cents: 100 cents = 1 semitone
     */
    static float frequencyToCentsDeviation(float frequency)
    {
        int nearestMidi = frequencyToMidiNote(frequency);
        float nearestFreq = midiNoteToFrequency(nearestMidi);
        return 1200.0f * std::log2(frequency / nearestFreq);
    }

    //==============================================================================
    /**
     * @brief Golden Ratio frequency series
     *
     * Generates frequencies based on golden ratio (φ = 1.618...).
     * Used in spectral composition and alternative tunings.
     *
     * Series: f₀, f₀×φ, f₀×φ², f₀×φ³, ...
     */
    static std::vector<float> generateGoldenRatioSeries(float fundamentalHz,
                                                       int numSteps = 8)
    {
        std::vector<float> series;
        series.reserve(numSteps);

        float currentFreq = fundamentalHz;
        for (int i = 0; i < numSteps; ++i)
        {
            series.push_back(currentFreq);
            currentFreq *= GOLDEN_RATIO;

            // Fold back into audible range if needed (divide by 2)
            while (currentFreq > 20000.0f)
                currentFreq /= 2.0f;
        }

        return series;
    }

    /**
     * @brief Fibonacci frequency series
     *
     * Generates frequencies based on Fibonacci ratios.
     * Fibonacci sequence: 1, 1, 2, 3, 5, 8, 13, 21, 34, ...
     */
    static std::vector<float> generateFibonacciSeries(float fundamentalHz,
                                                     int numSteps = 8)
    {
        std::vector<float> series;
        series.reserve(numSteps);

        // Generate Fibonacci numbers
        std::vector<int> fibonacci = {1, 1};
        for (int i = 2; i < numSteps; ++i)
        {
            fibonacci.push_back(fibonacci[i - 1] + fibonacci[i - 2]);
        }

        // Convert to frequencies
        for (int i = 0; i < numSteps; ++i)
        {
            float freq = fundamentalHz * static_cast<float>(fibonacci[i]);

            // Fold back into audible range
            while (freq > 20000.0f)
                freq /= 2.0f;

            series.push_back(freq);
        }

        return series;
    }

    //==============================================================================
    /**
     * @brief Calculate wavelength from frequency
     *
     * λ = c / f
     * - c: Speed of sound (343 m/s at 20°C)
     * - f: Frequency (Hz)
     *
     * Useful for room mode calculations and speaker placement.
     */
    static float frequencyToWavelength(float frequencyHz,
                                      float speedOfSoundMs = 343.0f)
    {
        return speedOfSoundMs / frequencyHz;
    }

    /**
     * @brief Calculate room modes (standing wave frequencies)
     *
     * Room modes: f = (c/2) × √((nx/L)² + (ny/W)² + (nz/H)²)
     * - nx, ny, nz: Mode numbers (0, 1, 2, ...)
     * - L, W, H: Room dimensions (m)
     *
     * Returns first 20 axial modes (most problematic).
     */
    static std::vector<float> calculateRoomModes(float lengthM,
                                                float widthM,
                                                float heightM,
                                                float speedOfSoundMs = 343.0f)
    {
        std::vector<float> modes;

        // Axial modes (1D standing waves - most prominent)
        // Length modes
        for (int n = 1; n <= 5; ++n)
            modes.push_back((speedOfSoundMs / 2.0f) * static_cast<float>(n) / lengthM);

        // Width modes
        for (int n = 1; n <= 5; ++n)
            modes.push_back((speedOfSoundMs / 2.0f) * static_cast<float>(n) / widthM);

        // Height modes
        for (int n = 1; n <= 5; ++n)
            modes.push_back((speedOfSoundMs / 2.0f) * static_cast<float>(n) / heightM);

        // Sort by frequency
        std::sort(modes.begin(), modes.end());

        return modes;
    }

    //==============================================================================
    /**
     * @brief Calculate consonance/dissonance rating
     *
     * Based on frequency ratio simplicity:
     * - Simple ratios (2:1, 3:2, 4:3) = consonant
     * - Complex ratios (45:32, 64:45) = dissonant
     *
     * Returns rating 0-1 (0 = most consonant, 1 = most dissonant)
     */
    static float calculateDissonance(float freq1, float freq2)
    {
        float ratio = freq2 / freq1;
        if (ratio < 1.0f)
            ratio = 1.0f / ratio;  // Always use ratio > 1

        // Check against known consonant intervals
        const std::vector<float> consonantRatios = {
            2.0f,           // Octave
            3.0f / 2.0f,    // Perfect 5th
            4.0f / 3.0f,    // Perfect 4th
            5.0f / 4.0f,    // Major 3rd
            6.0f / 5.0f,    // Minor 3rd
            5.0f / 3.0f     // Major 6th
        };

        // Find closest consonant ratio
        float minDistance = 1000.0f;
        for (float consonantRatio : consonantRatios)
        {
            float distance = std::abs(ratio - consonantRatio);
            minDistance = juce::jmin(minDistance, distance);
        }

        // Map distance to dissonance rating (0-1)
        return juce::jlimit(0.0f, 1.0f, minDistance * 2.0f);
    }

    /**
     * @brief Detect beating frequency
     *
     * When two frequencies are close, they create amplitude modulation (beating).
     * Beat frequency = |f1 - f2|
     *
     * Beating is most noticeable when < 20 Hz.
     */
    static float calculateBeatFrequency(float freq1, float freq2)
    {
        return std::abs(freq1 - freq2);
    }

    //==============================================================================
    /**
     * @brief Get interval name from frequency ratio
     */
    static juce::String getIntervalName(float ratio)
    {
        // Normalize ratio to be > 1
        if (ratio < 1.0f)
            ratio = 1.0f / ratio;

        // Check against known intervals (with tolerance)
        const float tolerance = 0.02f;

        if (std::abs(ratio - 2.0f) < tolerance) return "Octave (2:1)";
        if (std::abs(ratio - RATIO_PERFECT_FIFTH) < tolerance) return "Perfect 5th (3:2)";
        if (std::abs(ratio - RATIO_PERFECT_FOURTH) < tolerance) return "Perfect 4th (4:3)";
        if (std::abs(ratio - RATIO_MAJOR_THIRD) < tolerance) return "Major 3rd (5:4)";
        if (std::abs(ratio - RATIO_MINOR_THIRD) < tolerance) return "Minor 3rd (6:5)";
        if (std::abs(ratio - RATIO_MAJOR_SIXTH) < tolerance) return "Major 6th (5:3)";
        if (std::abs(ratio - RATIO_MINOR_SIXTH) < tolerance) return "Minor 6th (8:5)";
        if (std::abs(ratio - RATIO_MAJOR_SECOND) < tolerance) return "Major 2nd (9:8)";
        if (std::abs(ratio - RATIO_MINOR_SEVENTH) < tolerance) return "Minor 7th (16:9)";
        if (std::abs(ratio - GOLDEN_RATIO) < tolerance) return "Golden Ratio (φ)";

        return "Custom ratio (" + juce::String(ratio, 3) + ":1)";
    }
};

//==============================================================================
/**
 * @brief Phase & Delay Alignment Tool
 *
 * Professional phase alignment calculations based on:
 * - Sengpielaudio.com (phase/time relationships)
 * - Speaker placement optimization
 * - Comb filtering prevention
 *
 * **Scientific Foundation**:
 * 1. **Phase-Time Relationship**: φ = 360° × (t × f)
 *    - φ: Phase shift (degrees)
 *    - t: Time delay (seconds)
 *    - f: Frequency (Hz)
 *
 * 2. **Distance-Delay**: t = d / c
 *    - d: Distance (m)
 *    - c: Speed of sound (343 m/s)
 *
 * 3. **Comb Filtering**: Occurs when signals combine with delay
 *    - Notches at: f = (2n-1) / (2×delay)
 *    - Peaks at: f = n / delay
 *
 * References:
 * - https://www.sengpielaudio.com/calculator-timedelayphase.htm
 * - https://www.sengpielaudio.com/calculator-distance.htm
 */
class PhaseAlignmentTool
{
public:
    //==============================================================================
    /**
     * @brief Calculate delay from distance
     *
     * t = d / c
     * - Speed of sound: ~343 m/s (20°C, sea level)
     * - ~1 ms per foot (~3.3 ms per meter)
     */
    static float distanceToDelay(float distanceMeters, float speedOfSoundMs = 343.0f)
    {
        return (distanceMeters / speedOfSoundMs) * 1000.0f;  // Convert to milliseconds
    }

    /**
     * @brief Calculate distance from delay (reverse)
     */
    static float delayToDistance(float delayMs, float speedOfSoundMs = 343.0f)
    {
        return (delayMs / 1000.0f) * speedOfSoundMs;
    }

    /**
     * @brief Calculate phase shift from delay
     *
     * φ = 360° × (delay × frequency)
     */
    static float delayToPhase(float delayMs, float frequencyHz)
    {
        float delaySeconds = delayMs / 1000.0f;
        float phaseShift = 360.0f * (delaySeconds * frequencyHz);

        // Wrap to 0-360°
        while (phaseShift >= 360.0f)
            phaseShift -= 360.0f;
        while (phaseShift < 0.0f)
            phaseShift += 360.0f;

        return phaseShift;
    }

    /**
     * @brief Calculate delay compensation for speaker alignment
     *
     * Given two speakers at different distances from listener,
     * calculates delay to apply to closer speaker for time alignment.
     */
    static float calculateDelayCompensation(float distance1M, float distance2M)
    {
        float delayDifference = std::abs(distance1M - distance2M);
        return distanceToDelay(delayDifference);
    }

    /**
     * @brief Detect comb filtering frequencies
     *
     * When two signals combine with delay, comb filtering occurs.
     * Returns first 10 notch frequencies.
     */
    static std::vector<float> calculateCombFilterNotches(float delayMs, int numNotches = 10)
    {
        std::vector<float> notches;
        notches.reserve(numNotches);

        float delaySeconds = delayMs / 1000.0f;

        for (int n = 1; n <= numNotches; ++n)
        {
            // Notch frequencies: f = (2n-1) / (2×delay)
            float notchFreq = static_cast<float>(2 * n - 1) / (2.0f * delaySeconds);

            if (notchFreq <= 20000.0f)  // Only audible range
                notches.push_back(notchFreq);
        }

        return notches;
    }

    /**
     * @brief Calculate polarity (phase inversion) impact
     *
     * Returns true if frequencies will cancel significantly.
     * Phase differences near 180° cause maximum cancellation.
     */
    static bool willCauseSignificantCancellation(float delayMs, float frequencyHz)
    {
        float phaseShift = delayToPhase(delayMs, frequencyHz);

        // Check if phase is near 180° (±30°)
        return (phaseShift >= 150.0f && phaseShift <= 210.0f);
    }
};
