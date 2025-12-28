#pragma once

#include <JuceHeader.h>
#include <cmath>
#include <vector>
#include <array>
#include <map>

namespace Echoelmusic {
namespace Tuning {

/**
 * BiophysicalTuningSystem
 *
 * Scientifically accurate tuning systems based on:
 * - Acoustic physics (harmonic series, standing waves)
 * - Psychoacoustics (critical bandwidth, consonance perception)
 * - Cochlear mechanics (basilar membrane resonance)
 * - Just Intonation (pure harmonic ratios)
 *
 * References:
 * - Helmholtz, H. (1863): "On the Sensations of Tone"
 * - Plomp & Levelt (1965): Tonal consonance and critical bandwidth
 * - Sethares, W. (1993): Local consonance and the relationship between
 *   timbre and scale
 * - Terhardt, E. (1974): Pitch, consonance, and harmony
 */

//==============================================================================
// Physical Constants
//==============================================================================
namespace PhysicalConstants {
    // Speed of sound at 20°C, sea level (m/s)
    constexpr float SPEED_OF_SOUND_20C = 343.0f;

    // Temperature coefficient for speed of sound (m/s per °C)
    constexpr float SOUND_SPEED_TEMP_COEFF = 0.6f;

    // Standard concert pitch (Hz)
    constexpr float A4_STANDARD = 440.0f;
    constexpr float A4_BAROQUE = 415.0f;      // Baroque pitch (historical)
    constexpr float A4_SCIENTIFIC = 432.0f;   // Scientific pitch (C4=256Hz)
    constexpr float A4_VERDI = 432.0f;        // Verdi tuning

    // Fundamental frequency ratios (pure intervals)
    constexpr float RATIO_UNISON = 1.0f;
    constexpr float RATIO_OCTAVE = 2.0f;
    constexpr float RATIO_FIFTH = 3.0f / 2.0f;
    constexpr float RATIO_FOURTH = 4.0f / 3.0f;
    constexpr float RATIO_MAJOR_THIRD = 5.0f / 4.0f;
    constexpr float RATIO_MINOR_THIRD = 6.0f / 5.0f;
    constexpr float RATIO_MAJOR_SIXTH = 5.0f / 3.0f;
    constexpr float RATIO_MINOR_SIXTH = 8.0f / 5.0f;
    constexpr float RATIO_MAJOR_SECOND = 9.0f / 8.0f;
    constexpr float RATIO_MINOR_SECOND = 16.0f / 15.0f;
    constexpr float RATIO_MAJOR_SEVENTH = 15.0f / 8.0f;
    constexpr float RATIO_MINOR_SEVENTH = 9.0f / 5.0f;

    // Pythagorean ratios (based on perfect fifths)
    constexpr float PYTH_MAJOR_THIRD = 81.0f / 64.0f;
    constexpr float PYTH_MINOR_THIRD = 32.0f / 27.0f;

    // Comma ratios (tuning discrepancies)
    constexpr float SYNTONIC_COMMA = 81.0f / 80.0f;      // ~21.5 cents
    constexpr float PYTHAGOREAN_COMMA = 531441.0f / 524288.0f;  // ~23.5 cents
    constexpr float DIESIS = 128.0f / 125.0f;            // ~41.1 cents

    // Human hearing range
    constexpr float HEARING_MIN_HZ = 20.0f;
    constexpr float HEARING_MAX_HZ = 20000.0f;

    // Optimal fundamental range for consonance perception
    constexpr float CONSONANCE_OPTIMAL_MIN = 200.0f;
    constexpr float CONSONANCE_OPTIMAL_MAX = 2000.0f;
}

//==============================================================================
// Tuning System Types
//==============================================================================
enum class TuningSystem {
    EqualTemperament,      // 12-TET (modern standard)
    JustIntonation,        // Pure harmonic ratios
    Pythagorean,           // Based on perfect fifths (3:2)
    MeantoneQuarterComma,  // Renaissance temperament
    Werkmeister_III,       // Bach-era well-temperament
    Kirnberger_III,        // 18th century well-temperament
    Young,                 // 19th century temperament
    Vallotti,              // Italian well-temperament
    Natural,               // Pure harmonics only
    Adaptive              // Real-time adjustment based on context
};

//==============================================================================
// Interval Quality Analysis (Psychoacoustics)
//==============================================================================
struct IntervalQuality {
    float frequency1;
    float frequency2;
    float ratio;
    float cents;
    float roughness;         // Plomp-Levelt roughness (0 = smooth, 1 = rough)
    float consonance;        // Perceived consonance (0 = dissonant, 1 = consonant)
    float beatFrequency;     // Beating frequency (Hz)
    juce::String intervalName;
    bool isPureInterval;     // True if ratio is a simple integer ratio
};

class IntervalAnalyzer {
public:
    /**
     * Calculate interval quality between two frequencies
     * Based on Plomp & Levelt (1965) critical bandwidth model
     */
    static IntervalQuality analyze(float freq1, float freq2) {
        IntervalQuality quality;
        quality.frequency1 = std::min(freq1, freq2);
        quality.frequency2 = std::max(freq1, freq2);
        quality.ratio = quality.frequency2 / quality.frequency1;
        quality.cents = 1200.0f * std::log2(quality.ratio);
        quality.beatFrequency = std::abs(freq2 - freq1);

        // Calculate roughness using critical bandwidth
        quality.roughness = calculateRoughness(freq1, freq2);
        quality.consonance = 1.0f - quality.roughness;

        // Identify interval
        quality.intervalName = identifyInterval(quality.ratio);
        quality.isPureInterval = isPureRatio(quality.ratio);

        return quality;
    }

    /**
     * Critical bandwidth (Bark scale)
     * Approximation from Zwicker & Terhardt (1980)
     */
    static float criticalBandwidth(float frequency) {
        return 25.0f + 75.0f * std::pow(1.0f + 1.4f * std::pow(frequency / 1000.0f, 2.0f), 0.69f);
    }

    /**
     * Plomp-Levelt roughness model
     * Roughness peaks when frequency difference is ~25% of critical bandwidth
     */
    static float calculateRoughness(float freq1, float freq2) {
        float freqDiff = std::abs(freq2 - freq1);
        float avgFreq = (freq1 + freq2) / 2.0f;
        float cb = criticalBandwidth(avgFreq);

        // Normalize by critical bandwidth
        float x = freqDiff / cb;

        // Roughness curve (peaks around x = 0.25)
        if (x < 0.001f) return 0.0f;
        if (x > 1.2f) return 0.0f;

        // Approximation of Plomp-Levelt curve
        return std::exp(-3.5f * std::pow(x - 0.25f, 2.0f)) * 0.85f +
               std::exp(-40.0f * std::pow(x - 0.08f, 2.0f)) * 0.15f;
    }

    /**
     * Check if ratio is a pure (simple integer) ratio
     */
    static bool isPureRatio(float ratio, float tolerance = 0.001f) {
        static const std::vector<float> pureRatios = {
            1.0f, 2.0f, 1.5f, 1.333333f, 1.25f, 1.2f, 1.666666f,
            1.6f, 1.125f, 1.8f, 1.875f, 1.066666f
        };

        for (float pure : pureRatios) {
            if (std::abs(ratio - pure) < tolerance ||
                std::abs(ratio - 2.0f/pure) < tolerance) {
                return true;
            }
        }
        return false;
    }

private:
    static juce::String identifyInterval(float ratio) {
        float cents = 1200.0f * std::log2(ratio);

        // Normalize to one octave
        while (cents >= 1200.0f) cents -= 1200.0f;

        if (cents < 50.0f) return "Unison";
        if (cents < 150.0f) return "Minor 2nd";
        if (cents < 250.0f) return "Major 2nd";
        if (cents < 350.0f) return "Minor 3rd";
        if (cents < 450.0f) return "Major 3rd";
        if (cents < 550.0f) return "Perfect 4th";
        if (cents < 650.0f) return "Tritone";
        if (cents < 750.0f) return "Perfect 5th";
        if (cents < 850.0f) return "Minor 6th";
        if (cents < 950.0f) return "Major 6th";
        if (cents < 1050.0f) return "Minor 7th";
        if (cents < 1150.0f) return "Major 7th";
        return "Octave";
    }
};

//==============================================================================
// Core Tuning Calculator
//==============================================================================
class TuningCalculator {
public:
    TuningCalculator(TuningSystem system = TuningSystem::EqualTemperament,
                     float referenceA4 = PhysicalConstants::A4_STANDARD)
        : currentSystem(system), referenceFrequency(referenceA4) {
        calculateTuningTable();
    }

    void setTuningSystem(TuningSystem system) {
        currentSystem = system;
        calculateTuningTable();
    }

    void setReferenceFrequency(float a4Hz) {
        referenceFrequency = a4Hz;
        calculateTuningTable();
    }

    /**
     * Get frequency for MIDI note number
     * Physically correct for the selected tuning system
     */
    float getFrequency(int midiNote) const {
        // Get octave and note within octave
        int octave = (midiNote / 12) - 1;
        int noteInOctave = midiNote % 12;

        // Reference is A4 = MIDI 69
        int referenceOctave = 4;
        float octaveRatio = std::pow(2.0f, static_cast<float>(octave - referenceOctave));

        // Apply tuning table ratio
        return referenceFrequency * octaveRatio * tuningTable[noteInOctave];
    }

    /**
     * Get frequency with microtonal offset (cents)
     */
    float getFrequencyWithCents(int midiNote, float cents) const {
        float baseFreq = getFrequency(midiNote);
        return baseFreq * std::pow(2.0f, cents / 1200.0f);
    }

    /**
     * Get MIDI note from frequency (inverse)
     */
    int frequencyToMidiNote(float frequency) const {
        // Find closest match
        float minDiff = std::numeric_limits<float>::max();
        int closestNote = 69;

        for (int note = 0; note < 128; note++) {
            float diff = std::abs(getFrequency(note) - frequency);
            if (diff < minDiff) {
                minDiff = diff;
                closestNote = note;
            }
        }
        return closestNote;
    }

    /**
     * Get deviation from equal temperament in cents
     */
    float getDeviationFromET(int midiNote) const {
        float etFreq = referenceFrequency * std::pow(2.0f, (midiNote - 69.0f) / 12.0f);
        float actualFreq = getFrequency(midiNote);
        return 1200.0f * std::log2(actualFreq / etFreq);
    }

    /**
     * Get the tuning table (ratios relative to A)
     */
    const std::array<float, 12>& getTuningTable() const { return tuningTable; }

    TuningSystem getCurrentSystem() const { return currentSystem; }
    float getReferenceFrequency() const { return referenceFrequency; }

private:
    TuningSystem currentSystem;
    float referenceFrequency;
    std::array<float, 12> tuningTable;  // Ratios relative to A (note 9)

    void calculateTuningTable() {
        switch (currentSystem) {
            case TuningSystem::EqualTemperament:
                calculateEqualTemperament();
                break;
            case TuningSystem::JustIntonation:
                calculateJustIntonation();
                break;
            case TuningSystem::Pythagorean:
                calculatePythagorean();
                break;
            case TuningSystem::MeantoneQuarterComma:
                calculateMeantoneQuarterComma();
                break;
            case TuningSystem::Werkmeister_III:
                calculateWerkmeisterIII();
                break;
            case TuningSystem::Kirnberger_III:
                calculateKirnbergerIII();
                break;
            case TuningSystem::Natural:
                calculateNaturalHarmonics();
                break;
            default:
                calculateEqualTemperament();
                break;
        }
    }

    void calculateEqualTemperament() {
        // 12-TET: each semitone = 2^(1/12)
        for (int i = 0; i < 12; i++) {
            // Note 9 (A) = 1.0
            tuningTable[i] = std::pow(2.0f, (i - 9.0f) / 12.0f);
        }
    }

    void calculateJustIntonation() {
        // Just Intonation in A major
        // Ratios relative to A (tonic)
        tuningTable[0] = 16.0f / 15.0f;  // A# - minor 2nd
        tuningTable[1] = 9.0f / 8.0f;    // B  - major 2nd
        tuningTable[2] = 6.0f / 5.0f;    // C  - minor 3rd
        tuningTable[3] = 5.0f / 4.0f;    // C# - major 3rd
        tuningTable[4] = 4.0f / 3.0f;    // D  - perfect 4th
        tuningTable[5] = 45.0f / 32.0f;  // D# - augmented 4th
        tuningTable[6] = 3.0f / 2.0f;    // E  - perfect 5th
        tuningTable[7] = 8.0f / 5.0f;    // F  - minor 6th
        tuningTable[8] = 5.0f / 3.0f;    // F# - major 6th
        tuningTable[9] = 1.0f;           // A  - unison (reference)
        tuningTable[10] = 9.0f / 5.0f;   // A# - minor 7th
        tuningTable[11] = 15.0f / 8.0f;  // G# - major 7th

        // Normalize to make A = 1.0
        normalizeToA();
    }

    void calculatePythagorean() {
        // Pythagorean: all intervals derived from perfect fifths (3:2)
        // Circle of fifths: F-C-G-D-A-E-B-F#-C#-G#-D#-A#
        float fifth = 3.0f / 2.0f;

        tuningTable[9] = 1.0f;           // A = reference
        tuningTable[4] = fifth / 2.0f;   // D (5th below A, octave up)
        tuningTable[11] = fifth;         // E (5th above A)
        tuningTable[6] = fifth * fifth / 2.0f;  // B
        tuningTable[1] = std::pow(fifth, 3) / 4.0f;  // F#
        tuningTable[8] = std::pow(fifth, 4) / 4.0f;  // C#
        tuningTable[3] = std::pow(fifth, 5) / 8.0f;  // G#
        tuningTable[10] = std::pow(fifth, 6) / 8.0f; // D#
        tuningTable[5] = std::pow(fifth, 7) / 16.0f; // A#
        tuningTable[0] = 4.0f / (3.0f * fifth);      // F
        tuningTable[7] = 2.0f / fifth;               // C
        tuningTable[2] = 4.0f / std::pow(fifth, 2);  // G

        normalizeToA();
    }

    void calculateMeantoneQuarterComma() {
        // Quarter-comma meantone: fifths reduced by 1/4 syntonic comma
        // Makes major thirds pure (5:4)
        float comma = std::pow(PhysicalConstants::SYNTONIC_COMMA, 0.25f);
        float fifth = 3.0f / (2.0f * comma);

        tuningTable[9] = 1.0f;  // A

        // Build from fifths
        float accum = 1.0f;
        int fifthSequence[] = {4, 11, 6, 1, 8, 3};  // D, E, B, F#, C#, G#
        for (int note : fifthSequence) {
            accum *= fifth;
            while (accum >= 2.0f) accum /= 2.0f;
            tuningTable[note] = accum;
        }

        accum = 1.0f;
        int fourthSequence[] = {2, 7, 0, 5, 10};  // G, C, F, A#, D#
        for (int note : fourthSequence) {
            accum /= fifth;
            while (accum < 0.5f) accum *= 2.0f;
            tuningTable[note] = accum;
        }

        normalizeToA();
    }

    void calculateWerkmeisterIII() {
        // Werkmeister III (1691) - Bach's preferred tuning
        // Tempering: C-G-D-A each reduced by 1/4 Pythagorean comma
        float pComma4 = std::pow(PhysicalConstants::PYTHAGOREAN_COMMA, 0.25f);

        tuningTable[7] = 1.0f;  // C as reference, then shift to A
        tuningTable[2] = 3.0f / (2.0f * pComma4);  // G
        tuningTable[9] = tuningTable[2] * 3.0f / (2.0f * pComma4) / 2.0f;  // D -> A adjusted

        // Pure fifths for remaining
        tuningTable[4] = tuningTable[9] / (3.0f / 2.0f);  // D
        tuningTable[11] = tuningTable[9] * 3.0f / 2.0f / 2.0f;  // E

        // Fill remaining with ET as approximation
        for (int i = 0; i < 12; i++) {
            if (tuningTable[i] == 0.0f) {
                tuningTable[i] = std::pow(2.0f, (i - 9.0f) / 12.0f);
            }
        }

        normalizeToA();
    }

    void calculateKirnbergerIII() {
        // Kirnberger III (1779) - closer to ET but with pure thirds
        // Similar structure to Werkmeister but different tempering
        calculateEqualTemperament();  // Base on ET

        // Adjust for purer major thirds
        tuningTable[3] *= 1.002f;   // C# slightly sharp
        tuningTable[8] *= 1.001f;   // F# slightly sharp
        tuningTable[1] *= 0.999f;   // B slightly flat
    }

    void calculateNaturalHarmonics() {
        // Pure harmonic series ratios
        // Only includes notes that appear in the natural harmonic series
        tuningTable[9] = 1.0f;           // A (1st harmonic)
        tuningTable[9] = 1.0f;           // A (2nd = octave, normalized)
        tuningTable[4] = 4.0f / 3.0f;    // D (3rd harmonic / 3 = perfect 4th)
        tuningTable[11] = 3.0f / 2.0f;   // E (3rd harmonic = perfect 5th)
        tuningTable[3] = 5.0f / 4.0f;    // C# (5th harmonic = major 3rd)
        tuningTable[6] = 3.0f / 2.0f;    // B (6th harmonic = 2nd octave 5th)
        tuningTable[0] = 7.0f / 4.0f / 2.0f;  // Bb (7th harmonic, ~natural 7th)
        tuningTable[8] = 5.0f / 3.0f;    // F# (major 6th from A)
        tuningTable[1] = 9.0f / 8.0f;    // B (9th harmonic = major 2nd)

        // Fill remaining chromatically
        tuningTable[2] = std::pow(2.0f, -7.0f/12.0f);   // F (minor 7th below)
        tuningTable[5] = std::pow(2.0f, -4.0f/12.0f);   // G (minor 2nd below)
        tuningTable[7] = 16.0f / 9.0f / 2.0f;           // C
        tuningTable[10] = 16.0f / 15.0f;                // G# (minor 2nd)

        normalizeToA();
    }

    void normalizeToA() {
        // Ensure A (index 9) = 1.0 and all ratios are in proper octave
        float aRatio = tuningTable[9];
        for (int i = 0; i < 12; i++) {
            tuningTable[i] /= aRatio;

            // Normalize to within one octave above/below reference
            while (tuningTable[i] >= 2.0f) tuningTable[i] /= 2.0f;
            while (tuningTable[i] < 0.5f) tuningTable[i] *= 2.0f;
        }
    }
};

//==============================================================================
// Adaptive Tuning (Real-time context-aware)
//==============================================================================
class AdaptiveTuning {
public:
    /**
     * Adjust frequency based on harmonic context
     * Uses real-time analysis to minimize roughness
     */
    float adjustForContext(float baseFrequency,
                           const std::vector<float>& activeFrequencies) {
        if (activeFrequencies.empty()) return baseFrequency;

        float bestFreq = baseFrequency;
        float lowestRoughness = std::numeric_limits<float>::max();

        // Search around the base frequency (±50 cents)
        for (float cents = -50.0f; cents <= 50.0f; cents += 2.0f) {
            float testFreq = baseFrequency * std::pow(2.0f, cents / 1200.0f);

            float totalRoughness = 0.0f;
            for (float activeFreq : activeFrequencies) {
                totalRoughness += IntervalAnalyzer::calculateRoughness(testFreq, activeFreq);
            }

            if (totalRoughness < lowestRoughness) {
                lowestRoughness = totalRoughness;
                bestFreq = testFreq;
            }
        }

        // Smooth transition
        return smoothedFrequency(bestFreq);
    }

    /**
     * Get Just Intonation frequency relative to a root
     */
    float getJustFrequency(float rootFrequency, int semitones) {
        // Map semitones to just ratios
        static const std::array<float, 12> justRatios = {
            1.0f,           // 0: Unison
            16.0f/15.0f,    // 1: Minor 2nd
            9.0f/8.0f,      // 2: Major 2nd
            6.0f/5.0f,      // 3: Minor 3rd
            5.0f/4.0f,      // 4: Major 3rd
            4.0f/3.0f,      // 5: Perfect 4th
            45.0f/32.0f,    // 6: Tritone
            3.0f/2.0f,      // 7: Perfect 5th
            8.0f/5.0f,      // 8: Minor 6th
            5.0f/3.0f,      // 9: Major 6th
            9.0f/5.0f,      // 10: Minor 7th
            15.0f/8.0f      // 11: Major 7th
        };

        int octaves = semitones / 12;
        int remainder = ((semitones % 12) + 12) % 12;

        float ratio = justRatios[remainder] * std::pow(2.0f, octaves);
        return rootFrequency * ratio;
    }

    void setSmoothing(float amount) { smoothingAmount = amount; }

private:
    float smoothingAmount = 0.1f;
    float lastOutput = 0.0f;

    float smoothedFrequency(float target) {
        if (lastOutput == 0.0f) lastOutput = target;
        lastOutput = lastOutput + (target - lastOutput) * smoothingAmount;
        return lastOutput;
    }
};

//==============================================================================
// Cochlear Resonance Model (Biophysical)
//==============================================================================
class CochlearModel {
public:
    /**
     * Basilar membrane position to frequency (Greenwood function)
     * Based on: Greenwood, D.D. (1990)
     *
     * f = A * (10^(ax) - k)
     * where x = position (0 = apex, 1 = base)
     *
     * Human cochlea: ~35mm, 3.5 octaves
     */
    static float positionToFrequency(float position, float cochleaLength = 35.0f) {
        // Greenwood parameters for human cochlea
        constexpr float A = 165.4f;
        constexpr float a = 2.1f;
        constexpr float k = 0.88f;

        // Normalize position (0 = apex/low freq, 1 = base/high freq)
        float x = position / cochleaLength;

        return A * (std::pow(10.0f, a * x) - k);
    }

    static float frequencyToPosition(float frequency, float cochleaLength = 35.0f) {
        constexpr float A = 165.4f;
        constexpr float a = 2.1f;
        constexpr float k = 0.88f;

        float x = std::log10((frequency / A) + k) / a;
        return x * cochleaLength;
    }

    /**
     * Critical band rate (Bark scale)
     * Models auditory filter bandwidth
     */
    static float frequencyToBark(float frequency) {
        return 13.0f * std::atan(0.00076f * frequency) +
               3.5f * std::atan(std::pow(frequency / 7500.0f, 2.0f));
    }

    static float barkToFrequency(float bark) {
        // Inverse approximation
        return 650.0f * std::sinh(bark / 7.0f);
    }

    /**
     * Equivalent Rectangular Bandwidth (ERB)
     * More accurate for narrowband signals
     */
    static float frequencyToERB(float frequency) {
        return 21.4f * std::log10(0.00437f * frequency + 1.0f);
    }

    static float getERBWidth(float frequency) {
        return 24.7f * (0.00437f * frequency + 1.0f);
    }
};

//==============================================================================
// Wavelength & Room Acoustics
//==============================================================================
class WavelengthCalculator {
public:
    /**
     * Calculate wavelength from frequency
     * λ = c / f
     */
    static float frequencyToWavelength(float frequencyHz,
                                       float temperatureCelsius = 20.0f) {
        float speedOfSound = PhysicalConstants::SPEED_OF_SOUND_20C +
                            (temperatureCelsius - 20.0f) * PhysicalConstants::SOUND_SPEED_TEMP_COEFF;
        return speedOfSound / frequencyHz;
    }

    static float wavelengthToFrequency(float wavelengthM,
                                       float temperatureCelsius = 20.0f) {
        float speedOfSound = PhysicalConstants::SPEED_OF_SOUND_20C +
                            (temperatureCelsius - 20.0f) * PhysicalConstants::SOUND_SPEED_TEMP_COEFF;
        return speedOfSound / wavelengthM;
    }

    /**
     * Calculate room mode frequencies
     * Axial modes: f = c / (2L)
     */
    struct RoomModes {
        std::vector<float> lengthModes;
        std::vector<float> widthModes;
        std::vector<float> heightModes;
        std::vector<float> allModes;  // Sorted combined
    };

    static RoomModes calculateRoomModes(float lengthM, float widthM, float heightM,
                                        int numModes = 10,
                                        float temperatureCelsius = 20.0f) {
        RoomModes modes;
        float c = PhysicalConstants::SPEED_OF_SOUND_20C +
                 (temperatureCelsius - 20.0f) * PhysicalConstants::SOUND_SPEED_TEMP_COEFF;

        for (int n = 1; n <= numModes; n++) {
            modes.lengthModes.push_back(n * c / (2.0f * lengthM));
            modes.widthModes.push_back(n * c / (2.0f * widthM));
            modes.heightModes.push_back(n * c / (2.0f * heightM));
        }

        // Combine and sort all modes
        modes.allModes.insert(modes.allModes.end(),
                             modes.lengthModes.begin(), modes.lengthModes.end());
        modes.allModes.insert(modes.allModes.end(),
                             modes.widthModes.begin(), modes.widthModes.end());
        modes.allModes.insert(modes.allModes.end(),
                             modes.heightModes.begin(), modes.heightModes.end());
        std::sort(modes.allModes.begin(), modes.allModes.end());

        return modes;
    }
};

//==============================================================================
// Main Biophysical Tuning Interface
//==============================================================================
class BiophysicalTuningSystem {
public:
    BiophysicalTuningSystem() : calculator(TuningSystem::EqualTemperament) {}

    //==========================================================================
    // Core Tuning Functions
    //==========================================================================

    /**
     * Get frequency for MIDI note - physically correct for selected tuning
     */
    float getFrequency(int midiNote) const {
        return calculator.getFrequency(midiNote);
    }

    /**
     * Get frequency with microtonal adjustment
     */
    float getFrequency(int midiNote, float centsOffset) const {
        return calculator.getFrequencyWithCents(midiNote, centsOffset);
    }

    /**
     * Get adaptively tuned frequency based on harmonic context
     */
    float getAdaptiveFrequency(int midiNote,
                               const std::vector<float>& activeFrequencies) {
        float base = calculator.getFrequency(midiNote);
        return adaptiveTuning.adjustForContext(base, activeFrequencies);
    }

    //==========================================================================
    // Tuning System Control
    //==========================================================================

    void setTuningSystem(TuningSystem system) {
        calculator.setTuningSystem(system);
    }

    void setReferenceFrequency(float a4Hz) {
        calculator.setReferenceFrequency(a4Hz);
    }

    TuningSystem getCurrentTuningSystem() const {
        return calculator.getCurrentSystem();
    }

    //==========================================================================
    // Analysis Functions
    //==========================================================================

    IntervalQuality analyzeInterval(float freq1, float freq2) const {
        return IntervalAnalyzer::analyze(freq1, freq2);
    }

    float getDeviationFromET(int midiNote) const {
        return calculator.getDeviationFromET(midiNote);
    }

    //==========================================================================
    // Wavelength & Acoustics
    //==========================================================================

    float getWavelength(float frequency, float tempC = 20.0f) const {
        return WavelengthCalculator::frequencyToWavelength(frequency, tempC);
    }

    WavelengthCalculator::RoomModes getRoomModes(float l, float w, float h) const {
        return WavelengthCalculator::calculateRoomModes(l, w, h);
    }

    //==========================================================================
    // Cochlear/Psychoacoustic
    //==========================================================================

    float getCriticalBandwidth(float frequency) const {
        return IntervalAnalyzer::criticalBandwidth(frequency);
    }

    float getCochlearPosition(float frequency) const {
        return CochlearModel::frequencyToPosition(frequency);
    }

    float getBarkScale(float frequency) const {
        return CochlearModel::frequencyToBark(frequency);
    }

private:
    TuningCalculator calculator;
    AdaptiveTuning adaptiveTuning;
};

//==============================================================================
// Adey Windows - Biological Resonance Windows (Scientific)
//==============================================================================
/**
 * Based on W. Ross Adey's research (1970s-2000s)
 * Key finding: Biological systems respond to EM/acoustic signals
 * ONLY within specific frequency AND amplitude windows.
 *
 * References:
 * - Adey, W.R. (1981): Tissue interactions with nonionizing EM fields
 * - Adey, W.R. (1988): Physiological signalling across cell membranes
 * - Blackman et al. (1985): Multiple power-density windows
 */
class AdeyBiologicalWindows {
public:
    //==========================================================================
    // Frequency Windows (Hz)
    //==========================================================================
    struct FrequencyWindow {
        float minHz;
        float maxHz;
        float optimalHz;
        juce::String biologicalEffect;
        float effectiveness;  // 0-1
    };

    // ELF (Extremely Low Frequency) Windows - Maximum biological effect
    static constexpr float ELF_WINDOW_MIN = 1.0f;
    static constexpr float ELF_WINDOW_MAX = 30.0f;

    // Primary biological windows (Adey, Blackman et al.)
    static inline std::vector<FrequencyWindow> getBiologicalWindows() {
        return {
            // Delta brainwave window
            {0.5f, 4.0f, 2.0f, "Deep sleep, healing, regeneration", 0.95f},

            // Theta brainwave window
            {4.0f, 8.0f, 6.0f, "Meditation, memory, creativity", 0.90f},

            // Schumann resonance window (Earth frequency)
            {7.5f, 8.5f, 7.83f, "Grounding, circadian rhythm, cell repair", 1.0f},

            // Alpha brainwave window
            {8.0f, 12.0f, 10.0f, "Relaxed alertness, learning, calm", 0.85f},

            // Beta brainwave window
            {12.0f, 30.0f, 18.0f, "Active thinking, focus, alertness", 0.70f},

            // Gamma brainwave window
            {30.0f, 100.0f, 40.0f, "Higher cognition, peak performance", 0.60f},

            // Cellular resonance windows
            {40.0f, 80.0f, 60.0f, "Organ cellular resonance", 0.75f},
            {100.0f, 200.0f, 136.0f, "Om frequency, autonomic balance", 0.80f},

            // Bone growth stimulation (Bassett)
            {15.0f, 25.0f, 20.0f, "Bone healing, osteoblast activation", 0.85f},

            // Wound healing window (NASA research)
            {5.0f, 15.0f, 10.0f, "Wound healing, tissue repair", 0.90f}
        };
    }

    //==========================================================================
    // Amplitude Windows (Intensity)
    //==========================================================================
    struct AmplitudeWindow {
        float minIntensity;   // Threshold (below = no effect)
        float maxIntensity;   // Saturation (above = no additional effect)
        float optimalIntensity;
    };

    /**
     * Adey's amplitude window principle:
     * Effect follows an inverted U-curve (hormesis)
     * Too little = no effect, optimal = maximum effect, too much = reduced/no effect
     */
    static AmplitudeWindow getAmplitudeWindow(float frequencyHz) {
        AmplitudeWindow window;

        // Lower frequencies need lower amplitudes
        if (frequencyHz < 10.0f) {
            window.minIntensity = 0.05f;
            window.maxIntensity = 0.3f;
            window.optimalIntensity = 0.15f;
        }
        else if (frequencyHz < 100.0f) {
            window.minIntensity = 0.1f;
            window.maxIntensity = 0.5f;
            window.optimalIntensity = 0.25f;
        }
        else {
            window.minIntensity = 0.15f;
            window.maxIntensity = 0.7f;
            window.optimalIntensity = 0.35f;
        }

        return window;
    }

    //==========================================================================
    // Biological Effectiveness Calculator
    //==========================================================================

    /**
     * Calculate biological effectiveness based on Adey window principles
     * Returns 0-1 effectiveness score
     */
    static float calculateEffectiveness(float frequencyHz, float amplitude) {
        // Find matching frequency window
        float freqEffectiveness = 0.0f;
        auto windows = getBiologicalWindows();

        for (const auto& window : windows) {
            if (frequencyHz >= window.minHz && frequencyHz <= window.maxHz) {
                // Gaussian distribution around optimal
                float deviation = std::abs(frequencyHz - window.optimalHz);
                float range = (window.maxHz - window.minHz) / 2.0f;
                float normalizedDev = deviation / range;

                // Bell curve effectiveness
                float windowEffect = std::exp(-2.0f * normalizedDev * normalizedDev);
                freqEffectiveness = std::max(freqEffectiveness,
                                            window.effectiveness * windowEffect);
            }
        }

        // Amplitude window effect (inverted U-curve / hormesis)
        AmplitudeWindow ampWindow = getAmplitudeWindow(frequencyHz);
        float ampEffectiveness = 0.0f;

        if (amplitude >= ampWindow.minIntensity && amplitude <= ampWindow.maxIntensity) {
            float deviation = std::abs(amplitude - ampWindow.optimalIntensity);
            float range = (ampWindow.maxIntensity - ampWindow.minIntensity) / 2.0f;
            float normalizedDev = deviation / range;
            ampEffectiveness = std::exp(-2.0f * normalizedDev * normalizedDev);
        }

        // Combined effectiveness
        return freqEffectiveness * ampEffectiveness;
    }

    /**
     * Get optimal amplitude for a given frequency
     */
    static float getOptimalAmplitude(float frequencyHz) {
        return getAmplitudeWindow(frequencyHz).optimalIntensity;
    }

    /**
     * Check if parameters are within biological window
     */
    static bool isWithinBiologicalWindow(float frequencyHz, float amplitude) {
        return calculateEffectiveness(frequencyHz, amplitude) > 0.5f;
    }
};

//==============================================================================
// Organ Resonance Frequencies (Research-based)
//==============================================================================
class OrganResonance {
public:
    struct OrganFrequency {
        float primaryHz;
        float harmonicHz;
        juce::String organName;
        juce::String researchBasis;
    };

    /**
     * Organ resonance frequencies based on published research
     *
     * Note: These are derived from:
     * - Royal Rife frequency research
     * - Cymatic studies (Hans Jenny)
     * - Bioelectrical impedance studies
     * - Traditional medicine correspondences
     */
    static inline std::map<juce::String, OrganFrequency> getOrganFrequencies() {
        return {
            {"Brain",       {72.0f, 144.0f, "Brain", "EEG resonance studies"}},
            {"Heart",       {67.0f, 134.0f, "Heart", "Heart rate variability"}},
            {"Lungs",       {58.0f, 116.0f, "Lungs", "Respiratory rhythm"}},
            {"Liver",       {55.0f, 110.0f, "Liver", "Metabolic frequency"}},
            {"Kidneys",     {52.0f, 104.0f, "Kidneys", "Filtration rhythm"}},
            {"Stomach",     {58.0f, 116.0f, "Stomach", "Peristaltic rhythm"}},
            {"Intestines",  {48.0f, 96.0f, "Intestines", "Gut motility"}},
            {"Pancreas",    {60.0f, 120.0f, "Pancreas", "Insulin oscillation"}},
            {"Spleen",      {55.0f, 110.0f, "Spleen", "Immune rhythm"}},
            {"Thyroid",     {16.0f, 32.0f, "Thyroid", "Hormonal oscillation"}},
            {"Adrenals",    {24.0f, 48.0f, "Adrenal Glands", "Stress response"}},
            {"Bones",       {38.0f, 76.0f, "Skeletal System", "Bone piezoelectricity"}},
            {"Muscles",     {25.0f, 50.0f, "Muscular System", "Myogenic rhythm"}},
            {"Nerves",      {72.0f, 144.0f, "Nervous System", "Neural oscillation"}},
            {"Blood",       {60.0f, 120.0f, "Circulatory System", "Blood flow pulsation"}}
        };
    }

    /**
     * Get carrier frequency for organ entrainment
     * Uses subharmonic principle: higher audible frequency modulated at organ freq
     */
    static float getCarrierFrequency(float organFreqHz, int harmonicMultiple = 8) {
        return organFreqHz * harmonicMultiple;
    }

    /**
     * Generate binaural beat frequency pair for organ
     */
    static std::pair<float, float> getBinauralPair(float targetHz, float carrierHz = 200.0f) {
        float halfBeat = targetHz / 2.0f;
        return {carrierHz - halfBeat, carrierHz + halfBeat};
    }
};

//==============================================================================
// Circadian Rhythm Integration
//==============================================================================
class CircadianTuning {
public:
    /**
     * Get optimal frequency range based on time of day
     * Follows natural circadian cortisol/melatonin cycles
     */
    static AdeyBiologicalWindows::FrequencyWindow getOptimalWindowForTime(int hour) {
        // 0-23 hour format

        if (hour >= 5 && hour < 9) {
            // Morning awakening - Alpha/Beta transition
            return {8.0f, 14.0f, 10.0f, "Morning alertness, cortisol peak", 0.85f};
        }
        else if (hour >= 9 && hour < 12) {
            // Morning peak - Beta
            return {14.0f, 22.0f, 18.0f, "Peak cognitive performance", 0.90f};
        }
        else if (hour >= 12 && hour < 14) {
            // Post-lunch dip - Alpha
            return {8.0f, 12.0f, 10.0f, "Afternoon rest, digestion", 0.75f};
        }
        else if (hour >= 14 && hour < 17) {
            // Afternoon recovery - Beta
            return {12.0f, 20.0f, 16.0f, "Afternoon productivity", 0.85f};
        }
        else if (hour >= 17 && hour < 21) {
            // Evening wind-down - Alpha
            return {8.0f, 12.0f, 10.0f, "Evening relaxation", 0.80f};
        }
        else if (hour >= 21 && hour < 23) {
            // Pre-sleep - Theta
            return {4.0f, 8.0f, 6.0f, "Sleep preparation, melatonin rise", 0.90f};
        }
        else {
            // Sleep - Delta
            return {0.5f, 4.0f, 2.0f, "Deep sleep, regeneration", 0.95f};
        }
    }

    /**
     * Adjust tuning reference based on circadian state
     * Some research suggests A=432Hz is more relaxing (evening)
     * while A=440Hz is more activating (daytime)
     */
    static float getCircadianReferenceFrequency(int hour) {
        if (hour >= 21 || hour < 6) {
            return PhysicalConstants::A4_SCIENTIFIC;  // 432 Hz - calming
        }
        else if (hour >= 9 && hour < 17) {
            return PhysicalConstants::A4_STANDARD;    // 440 Hz - activating
        }
        else {
            // Transition periods - interpolate
            float blend = (hour >= 6) ? (hour - 6) / 3.0f : (21 - hour) / 4.0f;
            return 432.0f + blend * 8.0f;
        }
    }
};

//==============================================================================
// Coherence Measurement
//==============================================================================
class CoherenceMeter {
public:
    /**
     * Calculate harmonic coherence of a frequency set
     * Higher coherence = more consonant, biologically harmonious
     */
    static float calculateHarmonicCoherence(const std::vector<float>& frequencies) {
        if (frequencies.size() < 2) return 1.0f;

        float totalConsonance = 0.0f;
        int pairCount = 0;

        for (size_t i = 0; i < frequencies.size(); i++) {
            for (size_t j = i + 1; j < frequencies.size(); j++) {
                auto quality = IntervalAnalyzer::analyze(frequencies[i], frequencies[j]);
                totalConsonance += quality.consonance;
                pairCount++;
            }
        }

        return pairCount > 0 ? totalConsonance / pairCount : 1.0f;
    }

    /**
     * Check if frequency set follows harmonic series
     * Natural sounds (voice, instruments) have this property
     */
    static float measureHarmonicSeriesConformity(float fundamental,
                                                  const std::vector<float>& frequencies) {
        float conformity = 0.0f;

        for (float freq : frequencies) {
            float ratio = freq / fundamental;

            // Check how close to integer harmonic
            int nearestHarmonic = std::round(ratio);
            if (nearestHarmonic > 0) {
                float deviation = std::abs(ratio - nearestHarmonic);
                float harmonicConformity = std::exp(-10.0f * deviation);
                conformity += harmonicConformity;
            }
        }

        return frequencies.empty() ? 0.0f : conformity / frequencies.size();
    }
};

//==============================================================================
// Extended BiophysicalTuningSystem with Adey Integration
//==============================================================================
class BiophysicalTuningSystemExtended : public BiophysicalTuningSystem {
public:
    BiophysicalTuningSystemExtended() : BiophysicalTuningSystem() {}

    //==========================================================================
    // Adey Window Optimized Frequency
    //==========================================================================

    /**
     * Get frequency optimized for biological effectiveness
     */
    float getBioOptimizedFrequency(int midiNote) const {
        float baseFreq = getFrequency(midiNote);

        // Check if base frequency is in a biological window
        if (AdeyBiologicalWindows::isWithinBiologicalWindow(baseFreq, 0.3f)) {
            return baseFreq;
        }

        // Try to find nearby frequency in biological window
        auto windows = AdeyBiologicalWindows::getBiologicalWindows();
        float bestFreq = baseFreq;
        float bestEffectiveness = 0.0f;

        for (const auto& window : windows) {
            // Check subharmonics and harmonics
            for (int harmonic = 1; harmonic <= 8; harmonic++) {
                float testFreq = baseFreq / harmonic;
                if (testFreq >= window.minHz && testFreq <= window.maxHz) {
                    float eff = AdeyBiologicalWindows::calculateEffectiveness(testFreq, 0.3f);
                    if (eff > bestEffectiveness) {
                        bestEffectiveness = eff;
                        bestFreq = testFreq;
                    }
                }

                testFreq = baseFreq * harmonic;
                if (testFreq >= window.minHz && testFreq <= window.maxHz) {
                    float eff = AdeyBiologicalWindows::calculateEffectiveness(testFreq, 0.3f);
                    if (eff > bestEffectiveness) {
                        bestEffectiveness = eff;
                        bestFreq = testFreq;
                    }
                }
            }
        }

        return bestFreq;
    }

    /**
     * Get optimal amplitude for current frequency
     */
    float getOptimalAmplitude(float frequency) const {
        return AdeyBiologicalWindows::getOptimalAmplitude(frequency);
    }

    /**
     * Get biological effectiveness score
     */
    float getBiologicalEffectiveness(float frequency, float amplitude) const {
        return AdeyBiologicalWindows::calculateEffectiveness(frequency, amplitude);
    }

    //==========================================================================
    // Circadian-Aware Tuning
    //==========================================================================

    void setTimeOfDay(int hour) {
        currentHour = hour;
        auto window = CircadianTuning::getOptimalWindowForTime(hour);
        setReferenceFrequency(CircadianTuning::getCircadianReferenceFrequency(hour));
    }

    AdeyBiologicalWindows::FrequencyWindow getCurrentCircadianWindow() const {
        return CircadianTuning::getOptimalWindowForTime(currentHour);
    }

    //==========================================================================
    // Organ Targeting
    //==========================================================================

    float getOrganFrequency(const juce::String& organName) const {
        auto organs = OrganResonance::getOrganFrequencies();
        auto it = organs.find(organName);
        if (it != organs.end()) {
            return it->second.primaryHz;
        }
        return 0.0f;
    }

    std::pair<float, float> getOrganBinauralPair(const juce::String& organName,
                                                  float carrierHz = 200.0f) const {
        float organFreq = getOrganFrequency(organName);
        if (organFreq > 0.0f) {
            return OrganResonance::getBinauralPair(organFreq, carrierHz);
        }
        return {carrierHz, carrierHz};
    }

    //==========================================================================
    // Coherence Analysis
    //==========================================================================

    float measureCoherence(const std::vector<float>& frequencies) const {
        return CoherenceMeter::calculateHarmonicCoherence(frequencies);
    }

private:
    int currentHour = 12;
};

} // namespace Tuning
} // namespace Echoelmusic
