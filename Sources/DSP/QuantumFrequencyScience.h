#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>
#include <map>

/**
 * QuantumFrequencyScience - Frequency Systems with Scientific Classification
 *
 * ╔══════════════════════════════════════════════════════════════════════════╗
 * ║  IMPORTANT: SCIENTIFIC vs ESOTERIC CONTENT CLASSIFICATION               ║
 * ╠══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                          ║
 * ║  [SCIENTIFIC] - Peer-reviewed, experimentally verified:                  ║
 * ║    • Planck constant (E = hf) - Nobel Prize physics                      ║
 * ║    • Schumann resonance - Measured EM phenomenon (Schumann 1952)         ║
 * ║    • Pythagorean/Just Intonation tuning - Mathematical ratios            ║
 * ║    • Brainwave EEG bands - Neuroscience (Berger 1924)                    ║
 * ║    • Golden ratio - Pure mathematics                                     ║
 * ║    • Harmonic series - Acoustic physics                                  ║
 * ║    • Cymatics/Chladni patterns - Verified wave physics                   ║
 * ║    • CIE color matching - Standardized colorimetry                       ║
 * ║                                                                          ║
 * ║  [ESOTERIC] - Traditional/spiritual beliefs, NOT scientifically proven:  ║
 * ║    • Solfeggio frequencies "healing" claims - No peer-reviewed evidence  ║
 * ║    • 528 Hz "DNA repair" - No scientific validation                      ║
 * ║    • Chakra frequencies - Hindu spiritual tradition, not physics         ║
 * ║    • Planetary frequency "healing" - Cousto's math is valid,             ║
 * ║      but therapeutic claims are unproven                                 ║
 * ║    • 432 Hz "natural tuning" benefits - Minimal scientific support       ║
 * ║    • Binaural beat specific benefits - Limited/mixed research            ║
 * ║                                                                          ║
 * ╚══════════════════════════════════════════════════════════════════════════╝
 *
 * Sources:
 * - [SCIENTIFIC] Planck relation: CODATA 2018, NIST
 * - [SCIENTIFIC] Schumann resonance: Schumann, W.O. (1952) Z. Naturforsch
 * - [SCIENTIFIC] EEG bands: Niedermeyer & da Silva, Electroencephalography
 * - [ESOTERIC] Solfeggio: Puleo/Horowitz - No peer-reviewed validation
 * - [MATH VALID, CLAIMS ESOTERIC] Cousto: planetware.de/octave
 */
namespace Echoel::DSP
{

//==============================================================================
// Physical Constants [SCIENTIFIC - VERIFIED]
// Source: CODATA 2018, NIST, ISO standards
//==============================================================================

namespace PhysicalConstants
{
    // [SCIENTIFIC] Planck's constant - CODATA 2018 exact value
    constexpr double h = 6.62607015e-34;              // J·Hz⁻¹ (Joule-seconds)
    constexpr double hbar = 1.054571817e-34;          // ℏ = h / 2π (reduced Planck)

    // [SCIENTIFIC] Speed of light - SI definition exact value
    constexpr double c = 299792458.0;                 // m/s

    // [SCIENTIFIC] Planck units - derived from fundamental constants
    constexpr double planckTime = 5.391247e-44;       // seconds
    constexpr double planckLength = 1.616255e-35;     // meters
    constexpr double planckFrequency = 1.854858e43;   // Hz (1/planckTime)

    // [SCIENTIFIC] Golden ratio - pure mathematics, irrational constant
    constexpr double phi = 1.6180339887498948482;     // φ = (1 + √5) / 2
    constexpr double phiInverse = 0.6180339887498948; // 1/φ = φ - 1

    // [SCIENTIFIC] Schumann resonances - measured EM phenomenon
    // Source: Schumann, W.O. (1952), measured by various geophysical stations
    // NOTE: These are real electromagnetic cavity resonances, but claims about
    // health benefits from exposure are [ESOTERIC] and not scientifically proven
    constexpr std::array<double, 8> schumannResonances = {
        7.83, 14.3, 20.8, 27.3, 33.8, 39.0, 45.0, 51.0  // Hz
    };

    // [SCIENTIFIC] Scientific pitch - mathematical definition (C = 2^n Hz)
    // Historical use, convenient for calculations, but NOT "more natural"
    constexpr double scientificC4 = 256.0;            // 2⁸ Hz
    constexpr double scientificA4 = 430.539;          // Derived from C4 = 256 Hz

    // [SCIENTIFIC] Concert pitch standards - historical/conventional
    constexpr double concertA4_440 = 440.0;           // ISO 16:1975 standard
    constexpr double concertA4_432 = 432.0;           // Historical; [ESOTERIC] health claims unproven
    constexpr double concertA4_415 = 415.0;           // Baroque pitch (historical)
    constexpr double concertA4_435 = 435.0;           // French standard 1859

    // [SCIENTIFIC] Equal temperament - mathematical derivation
    constexpr double semitoneRatio = 1.0594630943592953;  // 2^(1/12)

    // [SCIENTIFIC] Speed of sound at 20°C, 1 atm - measured value
    constexpr double speedOfSound = 343.0;            // m/s
}

//==============================================================================
// Cousto Cosmic Octave - Planetary Frequencies
// [MATH: SCIENTIFIC] - Octave formula f × 2ⁿ is valid mathematics
// [CLAIMS: ESOTERIC] - Therapeutic/healing claims are NOT scientifically proven
//==============================================================================

/**
 * Hans Cousto's Cosmic Octave system (1978)
 *
 * [SCIENTIFIC ASPECTS]:
 * - The octave formula f × 2ⁿ is mathematically valid
 * - Astronomical orbital periods are accurately measured
 * - Frequency calculation from period (f = 1/T) is physics
 *
 * [ESOTERIC ASPECTS - NOT SCIENTIFICALLY PROVEN]:
 * - Claims that planetary frequencies have healing properties
 * - Chakra associations with planets
 * - Color-frequency correspondences beyond visible light physics
 * - Any therapeutic or spiritual benefits
 *
 * The math is correct; the metaphysical claims are belief-based.
 */
class CosmicOctave
{
public:
    //==========================================================================
    // Planetary Data (based on Cousto's calculations)
    //==========================================================================

    struct PlanetaryBody
    {
        juce::String name;

        // Astronomical data
        double orbitalPeriodDays;      // Synodic or sidereal period
        double rotationPeriodHours;    // Rotational period

        // Derived frequencies (octaved to audible range)
        double orbitalFrequencyHz;     // From orbital period
        double rotationFrequencyHz;    // From rotation period

        // Associated properties
        double wavelengthNm;           // Color wavelength (visible light)
        juce::Colour colour;           // Associated color
        int chakra;                    // [ESOTERIC] Chakra association - spiritual tradition, not science

        // MIDI note approximation
        int midiNote;
        int centOffset;                // Cents deviation from MIDI note
    };

    //==========================================================================
    // Planetary Frequency Table (Cousto values)
    //==========================================================================

    static const std::map<juce::String, PlanetaryBody>& getPlanetaryBodies()
    {
        static const std::map<juce::String, PlanetaryBody> bodies = {
            // Sun - based on mean solar day
            {"Sun", {"Sun", 365.242199, 609.12,
                     126.22, 32.31,
                     607.6, juce::Colour(0xFFFFCC00), 3,
                     60, +34}},

            // Moon - synodic month (new moon to new moon)
            {"Moon", {"Moon", 29.530589, 655.72,
                      210.42, 187.61,
                      475.4, juce::Colour(0xFFE8E8FF), 6,
                      68, -31}},

            // Earth - synodic day (24 hours)
            {"Earth", {"Earth", 1.0, 23.9345,
                       194.18, 388.36,
                       515.6, juce::Colour(0xFF00FF00), 4,
                       67, +2}},

            // Mercury
            {"Mercury", {"Mercury", 87.969, 1407.6,
                         141.27, 563.19,
                         555.0, juce::Colour(0xFF4169E1), 5,
                         62, +45}},

            // Venus - synodic period
            {"Venus", {"Venus", 224.701, 5832.5,
                       221.23, 442.46,
                       475.0, juce::Colour(0xFFFFD700), 3,
                       69, +32}},

            // Mars
            {"Mars", {"Mars", 686.971, 24.6229,
                      144.72, 289.44,
                      544.0, juce::Colour(0xFFFF4500), 1,
                       62, +84}},

            // Jupiter
            {"Jupiter", {"Jupiter", 4332.59, 9.925,
                         183.58, 367.16,
                         525.0, juce::Colour(0xFFFF6347), 2,
                         66, +12}},

            // Saturn
            {"Saturn", {"Saturn", 10759.22, 10.656,
                        147.85, 295.7,
                        539.0, juce::Colour(0xFF0000CD), 6,
                         63, +17}},

            // Uranus
            {"Uranus", {"Uranus", 30688.5, 17.24,
                        207.36, 414.72,
                        485.0, juce::Colour(0xFF00CED1), 5,
                         68, +15}},

            // Neptune
            {"Neptune", {"Neptune", 60182.0, 16.11,
                         211.44, 422.88,
                         478.0, juce::Colour(0xFF9400D3), 7,
                         68, +22}},

            // Pluto
            {"Pluto", {"Pluto", 90560.0, 153.3,
                       140.25, 280.5,
                       557.0, juce::Colour(0xFF8B0000), 1,
                       62, +38}}
        };
        return bodies;
    }

    //==========================================================================
    // Octavation Functions
    //==========================================================================

    /**
     * Convert period (in seconds) to frequency
     */
    static double periodToFrequency(double periodSeconds)
    {
        return 1.0 / periodSeconds;
    }

    /**
     * Octave a frequency into audible range (20-20000 Hz)
     * Uses f × 2ⁿ formula
     */
    static double octaveToAudible(double frequencyHz,
                                   double minHz = 20.0,
                                   double maxHz = 20000.0)
    {
        if (frequencyHz <= 0.0) return 0.0;

        double f = frequencyHz;

        // Octave up if too low
        while (f < minHz)
            f *= 2.0;

        // Octave down if too high
        while (f > maxHz)
            f /= 2.0;

        return f;
    }

    /**
     * Calculate how many octaves to shift
     */
    static int octavesRequired(double sourceHz, double targetHz)
    {
        if (sourceHz <= 0.0 || targetHz <= 0.0) return 0;
        return static_cast<int>(std::round(std::log2(targetHz / sourceHz)));
    }

    /**
     * Calculate planetary orbital frequency
     * @param orbitalPeriodDays - orbital period in days
     * @return base frequency in Hz (very low, needs octavation)
     */
    static double orbitalToBaseFrequency(double orbitalPeriodDays)
    {
        double periodSeconds = orbitalPeriodDays * 24.0 * 60.0 * 60.0;
        return 1.0 / periodSeconds;
    }

    /**
     * Get audible frequency for planetary body
     */
    static double getPlanetaryFrequency(const juce::String& bodyName,
                                         bool useRotation = false)
    {
        auto& bodies = getPlanetaryBodies();
        auto it = bodies.find(bodyName);
        if (it == bodies.end()) return 0.0;

        return useRotation ? it->second.rotationFrequencyHz
                           : it->second.orbitalFrequencyHz;
    }

    /**
     * Get all planetary frequencies as array
     */
    static std::vector<std::pair<juce::String, double>> getAllPlanetaryFrequencies()
    {
        std::vector<std::pair<juce::String, double>> result;
        for (const auto& [name, body] : getPlanetaryBodies())
        {
            result.push_back({name, body.orbitalFrequencyHz});
        }
        return result;
    }
};

//==============================================================================
// Tuning Systems - Physically Correct Intervals
// [SCIENTIFIC] - Pure mathematics, acoustic physics, historical standards
//==============================================================================

/**
 * Tuning Systems [SCIENTIFIC]
 *
 * All tuning systems here are based on:
 * - Mathematical ratios (Pythagorean: 3:2, Just: 5:4, etc.)
 * - Acoustic physics (harmonic series, beat frequencies)
 * - Historical musical practice
 *
 * These are NOT esoteric - they are verifiable mathematics and acoustics.
 */
class TuningSystem
{
public:
    enum class Type
    {
        EqualTemperament,     // 12√2 semitones (modern standard)
        Pythagorean,          // Based on 3:2 fifths
        JustIntonation,       // Pure harmonic ratios
        MeantoneQuarterComma, // Compromise tuning
        WerckmeisterIII,      // Well temperament
        Scientific            // C = 256 Hz (powers of 2)
    };

    //==========================================================================
    // Interval Ratios
    //==========================================================================

    struct IntervalRatios
    {
        juce::String name;
        double pythagorean;     // 3-limit ratios
        double justIntonation;  // 5-limit ratios
        double equalTemperament;// 12-TET
        int cents;              // Equal temperament cents
    };

    static const std::array<IntervalRatios, 13>& getIntervalRatios()
    {
        static const std::array<IntervalRatios, 13> intervals = {{
            {"Unison (P1)",      1.0/1.0,      1.0/1.0,      1.0,           0},
            {"Minor 2nd (m2)",   256.0/243.0,  16.0/15.0,    1.059463,    100},
            {"Major 2nd (M2)",   9.0/8.0,      9.0/8.0,      1.122462,    200},
            {"Minor 3rd (m3)",   32.0/27.0,    6.0/5.0,      1.189207,    300},
            {"Major 3rd (M3)",   81.0/64.0,    5.0/4.0,      1.259921,    400},
            {"Perfect 4th (P4)", 4.0/3.0,      4.0/3.0,      1.334840,    500},
            {"Tritone (TT)",     729.0/512.0,  45.0/32.0,    1.414214,    600},
            {"Perfect 5th (P5)", 3.0/2.0,      3.0/2.0,      1.498307,    700},
            {"Minor 6th (m6)",   128.0/81.0,   8.0/5.0,      1.587401,    800},
            {"Major 6th (M6)",   27.0/16.0,    5.0/3.0,      1.681793,    900},
            {"Minor 7th (m7)",   16.0/9.0,     9.0/5.0,      1.781797,   1000},
            {"Major 7th (M7)",   243.0/128.0,  15.0/8.0,     1.887749,   1100},
            {"Octave (P8)",      2.0/1.0,      2.0/1.0,      2.0,        1200}
        }};
        return intervals;
    }

    //==========================================================================
    // Frequency Calculations
    //==========================================================================

    /**
     * Calculate frequency from MIDI note using specified tuning
     */
    static double midiToFrequency(int midiNote,
                                   Type tuning = Type::EqualTemperament,
                                   double referenceA4 = 440.0)
    {
        switch (tuning)
        {
            case Type::Scientific:
                // C4 = 256 Hz, derive A4
                return scientificMidiToFrequency(midiNote);

            case Type::Pythagorean:
                return pythagoreanMidiToFrequency(midiNote, referenceA4);

            case Type::JustIntonation:
                return justIntonationMidiToFrequency(midiNote, referenceA4);

            case Type::EqualTemperament:
            default:
                return referenceA4 * std::pow(2.0, (midiNote - 69) / 12.0);
        }
    }

    /**
     * Scientific pitch: C4 = 256 Hz (2⁸)
     * All C notes are powers of 2
     */
    static double scientificMidiToFrequency(int midiNote)
    {
        // C4 = MIDI 60 = 256 Hz
        // Every C is a power of 2
        int octave = (midiNote / 12) - 1;
        int noteInOctave = midiNote % 12;

        // C of this octave
        double cFreq = 256.0 * std::pow(2.0, octave - 4);

        // Use equal temperament from C
        return cFreq * std::pow(2.0, noteInOctave / 12.0);
    }

    /**
     * Pythagorean tuning based on pure fifths (3:2)
     */
    static double pythagoreanMidiToFrequency(int midiNote, double refA4 = 440.0)
    {
        // Circle of fifths from reference
        static const std::array<double, 12> pythagoreanRatios = {{
            1.0,                    // C  (unison)
            256.0/243.0,            // C# (minor 2nd)
            9.0/8.0,                // D  (major 2nd)
            32.0/27.0,              // D# (minor 3rd)
            81.0/64.0,              // E  (major 3rd)
            4.0/3.0,                // F  (perfect 4th)
            729.0/512.0,            // F# (tritone)
            3.0/2.0,                // G  (perfect 5th)
            128.0/81.0,             // G# (minor 6th)
            27.0/16.0,              // A  (major 6th)
            16.0/9.0,               // A# (minor 7th)
            243.0/128.0             // B  (major 7th)
        }};

        int octave = (midiNote / 12) - 1;
        int noteInOctave = midiNote % 12;

        // Get C4 from A4 reference (A is 9 semitones above C)
        double c4Freq = refA4 / pythagoreanRatios[9];

        // C of target octave
        double cFreq = c4Freq * std::pow(2.0, octave - 4);

        return cFreq * pythagoreanRatios[noteInOctave];
    }

    /**
     * Just intonation based on harmonic series (5-limit)
     */
    static double justIntonationMidiToFrequency(int midiNote, double refA4 = 440.0)
    {
        static const std::array<double, 12> justRatios = {{
            1.0,        // C  (1/1)
            16.0/15.0,  // C# (16/15)
            9.0/8.0,    // D  (9/8)
            6.0/5.0,    // D# (6/5)
            5.0/4.0,    // E  (5/4)
            4.0/3.0,    // F  (4/3)
            45.0/32.0,  // F# (45/32)
            3.0/2.0,    // G  (3/2)
            8.0/5.0,    // G# (8/5)
            5.0/3.0,    // A  (5/3)
            9.0/5.0,    // A# (9/5)
            15.0/8.0    // B  (15/8)
        }};

        int octave = (midiNote / 12) - 1;
        int noteInOctave = midiNote % 12;

        // Get C4 from A4 reference
        double c4Freq = refA4 / justRatios[9];

        // C of target octave
        double cFreq = c4Freq * std::pow(2.0, octave - 4);

        return cFreq * justRatios[noteInOctave];
    }

    /**
     * Convert frequency to cents deviation from equal temperament
     */
    static double frequencyToCents(double freq, double refFreq)
    {
        return 1200.0 * std::log2(freq / refFreq);
    }

    /**
     * Apply cents offset to frequency
     */
    static double applyCentsOffset(double freq, double cents)
    {
        return freq * std::pow(2.0, cents / 1200.0);
    }

    //==========================================================================
    // Commas and Temperament Adjustments
    //==========================================================================

    // Pythagorean comma: (3/2)^12 / 2^7 ≈ 1.0136
    static constexpr double pythagoreanComma = 531441.0 / 524288.0;  // ~23.46 cents

    // Syntonic comma: 81/80 (difference between Pythagorean and just major third)
    static constexpr double syntonicComma = 81.0 / 80.0;  // ~21.51 cents

    // Diaschisma: difference between 4 perfect fifths and 2 octaves + major third
    static constexpr double diaschisma = 2048.0 / 2025.0;  // ~19.55 cents
};

//==============================================================================
// Brainwave Frequencies
// [SCIENTIFIC] - EEG frequency bands are measured and verified
// Source: Hans Berger (1924), Niedermeyer & da Silva "Electroencephalography"
//==============================================================================

/**
 * EEG Brainwave Bands
 *
 * [SCIENTIFIC]:
 * - Frequency ranges are measured via electroencephalography
 * - Correlation with sleep stages is well-documented
 * - Band definitions are standardized in neuroscience
 *
 * [PARTIALLY ESOTERIC]:
 * - Specific "benefits" listed are simplified; actual effects vary
 * - Brainwave entrainment efficacy has mixed research results
 * - Claims of specific healing/enhancement often exceed evidence
 */
class BrainwaveFrequencies
{
public:
    enum class Band
    {
        Delta,      // < 4 Hz - Deep sleep [SCIENTIFIC: verified in sleep studies]
        Theta,      // 4-8 Hz - Drowsiness, light sleep [SCIENTIFIC]
        Alpha,      // 8-13 Hz - Relaxed wakefulness [SCIENTIFIC]
        Beta,       // 13-30 Hz - Active concentration [SCIENTIFIC]
        Gamma       // 30-100+ Hz - High-level processing [SCIENTIFIC]
    };

    struct BandInfo
    {
        Band band;
        juce::String name;
        double lowHz;
        double highHz;
        double centerHz;
        juce::String mentalState;
        juce::String benefits;
    };

    static const std::array<BandInfo, 5>& getBands()
    {
        static const std::array<BandInfo, 5> bands = {{
            {Band::Delta, "Delta", 0.5, 4.0, 2.0,
             "Deep dreamless sleep",
             "Physical healing, regeneration, immune boost"},

            {Band::Theta, "Theta", 4.0, 8.0, 6.0,
             "Light sleep, deep meditation",
             "Creativity, intuition, memory consolidation"},

            {Band::Alpha, "Alpha", 8.0, 13.0, 10.0,
             "Relaxed wakefulness",
             "Calm focus, reduced anxiety, learning readiness"},

            {Band::Beta, "Beta", 13.0, 30.0, 20.0,
             "Active concentration",
             "Problem solving, decision making, alertness"},

            {Band::Gamma, "Gamma", 30.0, 100.0, 40.0,
             "Peak cognitive processing",
             "Higher learning, perception, consciousness expansion"}
        }};
        return bands;
    }

    /**
     * Get Schumann resonance aligned with brainwave bands
     * 7.83 Hz fundamental is in Alpha/Theta boundary
     */
    static double getSchumannAlignedFrequency(Band targetBand)
    {
        // Schumann resonances: 7.83, 14.3, 20.8, 27.3, 33.8 Hz
        switch (targetBand)
        {
            case Band::Delta: return 3.91;   // 7.83 / 2 (sub-harmonic)
            case Band::Theta: return 7.83;   // Fundamental Schumann
            case Band::Alpha: return 7.83;   // At Alpha/Theta border
            case Band::Beta:  return 14.3;   // 2nd Schumann harmonic
            case Band::Gamma: return 33.8;   // 5th Schumann harmonic
            default: return 7.83;
        }
    }

    /**
     * Calculate binaural beat carrier frequencies
     * @param targetHz - desired brainwave frequency
     * @param carrierHz - base carrier frequency (typically 200-400 Hz)
     * @return pair of left/right frequencies
     */
    static std::pair<double, double> calculateBinauralBeat(double targetHz,
                                                            double carrierHz = 300.0)
    {
        double halfBeat = targetHz / 2.0;
        return {carrierHz - halfBeat, carrierHz + halfBeat};
    }

    /**
     * Calculate isochronic pulse timing
     * @param targetHz - desired entrainment frequency
     * @return pulse period in seconds
     */
    static double calculateIsochronicPeriod(double targetHz)
    {
        return 1.0 / targetHz;
    }
};

//==============================================================================
// Solfeggio Frequencies
// ⚠️ [ESOTERIC] - NO SCIENTIFIC EVIDENCE for healing claims
//==============================================================================

/**
 * Solfeggio Frequencies
 *
 * ╔════════════════════════════════════════════════════════════════════════╗
 * ║  ⚠️  WARNING: ESOTERIC CONTENT - NOT SCIENTIFICALLY VALIDATED  ⚠️     ║
 * ╠════════════════════════════════════════════════════════════════════════╣
 * ║                                                                        ║
 * ║  These frequencies were popularized by Dr. Joseph Puleo and           ║
 * ║  Dr. Leonard Horowitz based on numerological interpretation of        ║
 * ║  biblical texts. There is NO peer-reviewed scientific evidence        ║
 * ║  supporting claims of:                                                 ║
 * ║                                                                        ║
 * ║  • DNA repair (528 Hz)                                                 ║
 * ║  • Healing properties                                                  ║
 * ║  • Chakra activation                                                   ║
 * ║  • Spiritual transformation                                            ║
 * ║                                                                        ║
 * ║  The frequencies themselves are just frequencies - any specific       ║
 * ║  effects beyond normal audio perception are unproven.                 ║
 * ║                                                                        ║
 * ║  Included for: Creative/artistic use, user preference, completeness   ║
 * ╚════════════════════════════════════════════════════════════════════════╝
 */
class SolfeggioFrequencies
{
public:
    struct SolfeggioTone
    {
        double frequencyHz;
        juce::String syllable;
        juce::String description;
        juce::String claimedBenefit;  // Renamed: these are CLAIMS, not proven benefits
        int digitSum;  // Numerological property (not scientific)
    };

    static const std::array<SolfeggioTone, 9>& getTones()
    {
        // [ESOTERIC] Original 6 + 3 additional tones
        // Benefits listed are TRADITIONAL CLAIMS, not scientific facts
        static const std::array<SolfeggioTone, 9> tones = {{
            {174.0, "—", "Foundation", "[CLAIM] Grounding, pain reduction", 3},
            {285.0, "—", "Quantum Cognition", "[CLAIM] Energy field healing", 6},
            {396.0, "UT", "Liberating", "[CLAIM] Release guilt and fear", 9},
            {417.0, "RE", "Resonating", "[CLAIM] Facilitate change", 3},
            {528.0, "MI", "Transformation", "[CLAIM] DNA repair - NO EVIDENCE", 6},
            {639.0, "FA", "Connecting", "[CLAIM] Relationships, harmony", 9},
            {741.0, "SOL", "Awakening", "[CLAIM] Expression, solutions", 3},
            {852.0, "LA", "Returning", "[CLAIM] Spiritual order", 6},
            {963.0, "SI", "Divine", "[CLAIM] Pineal activation", 9}
        }};
        return tones;
    }

    /**
     * Get frequency by index (0-8)
     */
    static double getFrequency(int index)
    {
        if (index >= 0 && index < 9)
            return getTones()[index].frequencyHz;
        return 0.0;
    }

    /**
     * Find nearest solfeggio frequency
     */
    static const SolfeggioTone& findNearest(double frequencyHz)
    {
        const auto& tones = getTones();
        size_t nearestIndex = 0;
        double minDiff = std::abs(frequencyHz - tones[0].frequencyHz);

        for (size_t i = 1; i < tones.size(); ++i)
        {
            double diff = std::abs(frequencyHz - tones[i].frequencyHz);
            if (diff < minDiff)
            {
                minDiff = diff;
                nearestIndex = i;
            }
        }
        return tones[nearestIndex];
    }

    /**
     * Check if frequency is close to a solfeggio tone (within tolerance)
     */
    static bool isSolfeggioTone(double frequencyHz, double toleranceHz = 2.0)
    {
        for (const auto& tone : getTones())
        {
            if (std::abs(frequencyHz - tone.frequencyHz) <= toleranceHz)
                return true;
        }
        return false;
    }
};

//==============================================================================
// Golden Ratio Harmonics
// [SCIENTIFIC] - Pure mathematics (φ = (1+√5)/2 is an irrational constant)
//==============================================================================

/**
 * Golden Ratio in Music [SCIENTIFIC MATH, MIXED APPLICATION]
 *
 * [SCIENTIFIC]:
 * - Golden ratio φ = 1.618... is a mathematical constant
 * - Fibonacci sequence is pure mathematics
 * - φ does appear in nature (phyllotaxis, shell spirals)
 * - Some composers have used φ for structural proportions
 *
 * [PARTIALLY ESOTERIC]:
 * - Claims that φ creates "more pleasing" music are subjective
 * - "Sacred geometry" associations are spiritual, not scientific
 * - φ-based frequencies are not inherently "better" than others
 */
class GoldenRatioHarmonics
{
public:
    /**
     * Generate Fibonacci sequence [SCIENTIFIC - pure math]
     */
    static std::vector<int> fibonacciSequence(int count)
    {
        std::vector<int> fib;
        fib.reserve(count);

        if (count > 0) fib.push_back(0);
        if (count > 1) fib.push_back(1);

        for (int i = 2; i < count; ++i)
            fib.push_back(fib[i-1] + fib[i-2]);

        return fib;
    }

    /**
     * Apply golden ratio to frequency
     * f × φ or f / φ
     */
    static double goldenMultiply(double freq)
    {
        return freq * PhysicalConstants::phi;
    }

    static double goldenDivide(double freq)
    {
        return freq * PhysicalConstants::phiInverse;
    }

    /**
     * Generate golden ratio frequency series
     * Each frequency is φ times the previous
     */
    static std::vector<double> goldenSeries(double baseFreq, int count, bool ascending = true)
    {
        std::vector<double> series;
        series.reserve(count);

        double f = baseFreq;
        double ratio = ascending ? PhysicalConstants::phi : PhysicalConstants::phiInverse;

        for (int i = 0; i < count; ++i)
        {
            series.push_back(f);
            f *= ratio;
        }
        return series;
    }

    /**
     * Calculate golden point in duration
     * Where climax/transition should occur for maximum impact
     * @param totalDuration - total length
     * @return position at φ ratio (≈61.8% through)
     */
    static double goldenPoint(double totalDuration)
    {
        return totalDuration * PhysicalConstants::phiInverse;
    }

    /**
     * Fibonacci-based rhythm pattern
     * Generates time intervals based on Fibonacci sequence
     */
    static std::vector<double> fibonacciRhythm(double baseUnit, int count)
    {
        auto fib = fibonacciSequence(count + 2);  // Skip 0, 1
        std::vector<double> durations;

        for (int i = 2; i < static_cast<int>(fib.size()); ++i)
            durations.push_back(fib[i] * baseUnit);

        return durations;
    }
};

//==============================================================================
// Planck Quantum Energy Calculator
// [SCIENTIFIC] - Nobel Prize physics (Planck 1918, Einstein 1921)
//==============================================================================

/**
 * Quantum Energy Relations [SCIENTIFIC]
 *
 * E = hf (Planck-Einstein relation) is fundamental physics:
 * - Verified experimentally (photoelectric effect, blackbody radiation)
 * - Foundation of quantum mechanics
 * - Used in lasers, semiconductors, spectroscopy
 *
 * NOTE: E = hf applies to photons (EM radiation).
 * Sound waves are mechanical, not electromagnetic - they don't have
 * "quantum energy" in the same sense. The audio-to-color mapping
 * here is an artistic visualization, not physics.
 */
class QuantumEnergyCalculator
{
public:
    /**
     * [SCIENTIFIC] Calculate photon energy from frequency (E = hf)
     * @param frequencyHz - frequency in Hz
     * @return energy in Joules
     */
    static double frequencyToEnergy(double frequencyHz)
    {
        return PhysicalConstants::h * frequencyHz;
    }

    /**
     * Calculate photon energy in electron volts
     */
    static double frequencyToEnergyEV(double frequencyHz)
    {
        double joules = frequencyToEnergy(frequencyHz);
        return joules / 1.602176634e-19;  // eV conversion
    }

    /**
     * Calculate frequency from energy
     */
    static double energyToFrequency(double energyJoules)
    {
        return energyJoules / PhysicalConstants::h;
    }

    /**
     * Calculate wavelength from frequency (λ = c/f)
     * For electromagnetic waves
     */
    static double frequencyToWavelength(double frequencyHz)
    {
        return PhysicalConstants::c / frequencyHz;
    }

    /**
     * Calculate acoustic wavelength
     * For sound waves in air at 20°C
     */
    static double frequencyToAcousticWavelength(double frequencyHz)
    {
        return PhysicalConstants::speedOfSound / frequencyHz;
    }

    /**
     * [ARTISTIC/VISUALIZATION] Scale audio frequency to visible light spectrum
     * Maps audible range to visible wavelengths (380-780 nm)
     *
     * NOTE: This is an ARTISTIC mapping for visualization purposes.
     * There is no physical connection between audio frequencies (20-20000 Hz)
     * and visible light frequencies (430-750 THz). This is synesthesia
     * simulation, not physics.
     *
     * For TRUE physical octavation, use audioToLightOctave() instead!
     */
    static double audioToVisibleWavelength(double audioHz,
                                            double minAudioHz = 20.0,
                                            double maxAudioHz = 20000.0)
    {
        // Logarithmic mapping - ARTISTIC, not physical
        double logPos = std::log2(audioHz / minAudioHz) /
                        std::log2(maxAudioHz / minAudioHz);
        logPos = juce::jlimit(0.0, 1.0, logPos);

        // Map to visible spectrum (780nm red to 380nm violet)
        return 780.0 - logPos * 400.0;  // nm
    }

    //==========================================================================
    // TRUE PHYSICAL OCTAVATION (Cousto-style f × 2ⁿ)
    // [SCIENTIFIC] - This is the mathematically correct octave relationship
    //==========================================================================

    /**
     * [SCIENTIFIC] True octave relationship between audio and visible light
     *
     * This uses the Cousto formula f × 2ⁿ to find the TRUE octave of an
     * audio frequency in the visible light spectrum.
     *
     * Visible light: ~430 THz (red, 700nm) to ~750 THz (violet, 400nm)
     *
     * Example: A4 = 440 Hz
     *   440 Hz × 2^40 = 484 THz = 619 nm (orange-red)
     *   This is the TRUE 40th octave of A4!
     *
     * Like sunlight through a prism - each frequency has ONE correct color.
     */
    struct AudioLightOctave
    {
        double audioFrequencyHz;
        double lightFrequencyTHz;    // Terahertz
        double wavelengthNm;         // Nanometers
        int octavesUp;               // Number of doublings
        bool inVisibleRange;         // 380-780 nm
        juce::Colour colour;         // RGB color
    };

    static AudioLightOctave audioToLightOctave(double audioHz)
    {
        AudioLightOctave result;
        result.audioFrequencyHz = audioHz;

        // Visible light range in Hz
        constexpr double visibleMinHz = 384e12;   // ~780nm (red)
        constexpr double visibleMaxHz = 789e12;   // ~380nm (violet)

        // Octave up until we reach visible range
        double freq = audioHz;
        int octaves = 0;

        while (freq < visibleMinHz)
        {
            freq *= 2.0;
            octaves++;
        }

        result.lightFrequencyTHz = freq / 1e12;
        result.octavesUp = octaves;

        // Calculate wavelength: λ = c / f
        result.wavelengthNm = (PhysicalConstants::c / freq) * 1e9;

        // Check if in visible range
        result.inVisibleRange = (result.wavelengthNm >= 380.0 && result.wavelengthNm <= 780.0);

        // Get color
        result.colour = wavelengthToColour(result.wavelengthNm);

        return result;
    }

    /**
     * [SCIENTIFIC] Get the true octave color for any audio frequency
     *
     * This is physically correct - like a prism separating sunlight.
     * Each audio frequency has exactly ONE corresponding visible color
     * based on the octave relationship f × 2ⁿ.
     */
    static juce::Colour audioToTrueOctaveColour(double audioHz)
    {
        return audioToLightOctave(audioHz).colour;
    }

    /**
     * [SCIENTIFIC] Musical note to true octave color
     *
     * Examples (using A4 = 440 Hz):
     *   C4 (261.63 Hz) × 2^40 = 287 THz → ~1044nm (infrared, below visible)
     *   C4 × 2^41 = 574 THz → 522nm (green)
     *   A4 (440 Hz) × 2^40 = 484 THz → 619nm (orange)
     *   A5 (880 Hz) × 2^39 = 484 THz → 619nm (same color - octave!)
     */
    static juce::Colour midiNoteToTrueOctaveColour(int midiNote, double refA4 = 440.0)
    {
        double freq = refA4 * std::pow(2.0, (midiNote - 69) / 12.0);
        return audioToTrueOctaveColour(freq);
    }

    /**
     * [SCIENTIFIC] Get octave-related notes for a color
     *
     * Since octaves produce the same color (just like they sound "the same"
     * in music), this returns the base audio frequency for a wavelength.
     */
    static double wavelengthToAudioOctave(double wavelengthNm)
    {
        // Light frequency
        double lightFreq = PhysicalConstants::c / (wavelengthNm * 1e-9);

        // Octave down until we reach audio range
        while (lightFreq > 20000.0)
            lightFreq /= 2.0;

        return lightFreq;
    }

    /**
     * Convert wavelength to RGB color
     * Based on CIE 1931 color matching
     */
    static juce::Colour wavelengthToColour(double wavelengthNm)
    {
        double r = 0.0, g = 0.0, b = 0.0;
        double wl = wavelengthNm;

        if (wl >= 380.0 && wl < 440.0)
        {
            r = -(wl - 440.0) / (440.0 - 380.0);
            g = 0.0;
            b = 1.0;
        }
        else if (wl >= 440.0 && wl < 490.0)
        {
            r = 0.0;
            g = (wl - 440.0) / (490.0 - 440.0);
            b = 1.0;
        }
        else if (wl >= 490.0 && wl < 510.0)
        {
            r = 0.0;
            g = 1.0;
            b = -(wl - 510.0) / (510.0 - 490.0);
        }
        else if (wl >= 510.0 && wl < 580.0)
        {
            r = (wl - 510.0) / (580.0 - 510.0);
            g = 1.0;
            b = 0.0;
        }
        else if (wl >= 580.0 && wl < 645.0)
        {
            r = 1.0;
            g = -(wl - 645.0) / (645.0 - 580.0);
            b = 0.0;
        }
        else if (wl >= 645.0 && wl <= 780.0)
        {
            r = 1.0;
            g = 0.0;
            b = 0.0;
        }

        // Intensity correction
        double intensity = 1.0;
        if (wl >= 380.0 && wl < 420.0)
            intensity = 0.3 + 0.7 * (wl - 380.0) / (420.0 - 380.0);
        else if (wl >= 700.0 && wl <= 780.0)
            intensity = 0.3 + 0.7 * (780.0 - wl) / (780.0 - 700.0);

        return juce::Colour::fromFloatRGBA(
            static_cast<float>(r * intensity),
            static_cast<float>(g * intensity),
            static_cast<float>(b * intensity),
            1.0f
        );
    }

    /**
     * Audio frequency to synesthetic color
     * Octaves audible range to visible spectrum
     */
    static juce::Colour audioFrequencyToColour(double frequencyHz)
    {
        double wavelength = audioToVisibleWavelength(frequencyHz);
        return wavelengthToColour(wavelength);
    }
};

//==============================================================================
// Harmonic Series Generator
// [SCIENTIFIC] - Acoustic physics, verified by Fourier analysis
//==============================================================================

/**
 * Harmonic Series [SCIENTIFIC]
 *
 * The harmonic series (f, 2f, 3f, 4f...) is fundamental acoustic physics:
 * - Physically produced by vibrating strings, air columns, membranes
 * - Mathematically described by Fourier analysis
 * - Basis for musical intervals and timbre perception
 * - Verified experimentally since antiquity (Pythagoras)
 */
class HarmonicSeries
{
public:
    /**
     * [SCIENTIFIC] Generate natural harmonic series
     * @param fundamental - base frequency in Hz
     * @param numHarmonics - number of harmonics (including fundamental)
     * @return vector of {harmonic number, frequency, amplitude}
     */
    struct Harmonic
    {
        int number;
        double frequencyHz;
        double amplitude;     // 1/n falloff by default
        double interval;      // Ratio to fundamental
        juce::String note;    // Nearest note name
    };

    static std::vector<Harmonic> generate(double fundamental, int numHarmonics)
    {
        std::vector<Harmonic> harmonics;
        harmonics.reserve(numHarmonics);

        for (int n = 1; n <= numHarmonics; ++n)
        {
            Harmonic h;
            h.number = n;
            h.frequencyHz = fundamental * n;
            h.amplitude = 1.0 / n;  // Natural rolloff
            h.interval = static_cast<double>(n);

            // Find nearest note
            double midiNote = 69.0 + 12.0 * std::log2(h.frequencyHz / 440.0);
            int roundedMidi = static_cast<int>(std::round(midiNote));
            static const char* noteNames[] = {"C", "C#", "D", "D#", "E", "F",
                                               "F#", "G", "G#", "A", "A#", "B"};
            int noteName = roundedMidi % 12;
            int octave = (roundedMidi / 12) - 1;
            h.note = juce::String(noteNames[noteName]) + juce::String(octave);

            harmonics.push_back(h);
        }
        return harmonics;
    }

    /**
     * Calculate subharmonics (below fundamental)
     */
    static std::vector<double> subharmonics(double fundamental, int numSubharmonics)
    {
        std::vector<double> subs;
        for (int n = 2; n <= numSubharmonics + 1; ++n)
        {
            subs.push_back(fundamental / n);
        }
        return subs;
    }

    /**
     * Generate combination tones (sum and difference)
     */
    static std::pair<double, double> combinationTones(double freq1, double freq2)
    {
        return {freq1 + freq2, std::abs(freq1 - freq2)};
    }
};

}  // namespace Echoel::DSP
