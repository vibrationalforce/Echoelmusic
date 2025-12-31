#pragma once

#include "QuantumFrequencyScience.h"
#include <JuceHeader.h>
#include <array>
#include <vector>
#include <map>

/**
 * CosmicTuningSystem - Physically Correct Instrument Tuning
 *
 * Features:
 * - Multiple reference pitches (440, 432, 256 Hz scientific)
 * - Cousto planetary-based tuning
 * - Pythagorean, Just Intonation, Equal Temperament
 * - Solfeggio-aligned scales
 * - Micro-tuning with cent precision
 * - Scala file format support
 * - Chakra-frequency instrument tuning
 *
 * Based on:
 * - Hans Cousto "The Cosmic Octave"
 * - Pythagorean mathematics
 * - Modern scientific pitch standards
 */
namespace Echoel::DSP
{

//==============================================================================
// Scale Definition
//==============================================================================

struct ScaleDefinition
{
    juce::String name;
    juce::String description;

    // Intervals as ratios or cents from root
    std::vector<double> intervals;  // Ratios (1.0 = unison)
    std::vector<double> cents;      // Cents from root

    // Scale properties
    int notesPerOctave = 12;
    bool isEquallyDivided = true;

    // Reference note (which degree is the "root")
    int rootDegree = 0;

    /** Create from ratio list */
    static ScaleDefinition fromRatios(const juce::String& name,
                                       const std::vector<double>& ratios);

    /** Create from cents list */
    static ScaleDefinition fromCents(const juce::String& name,
                                      const std::vector<double>& centsList);

    /** Get frequency for scale degree */
    double getFrequency(int degree, double rootFrequency) const;
};

//==============================================================================
// Tuning Table
//==============================================================================

class TuningTable
{
public:
    TuningTable();

    //==========================================================================
    // Reference Configuration
    //==========================================================================

    /** Set reference note and frequency */
    void setReference(int midiNote, double frequencyHz);

    /** Set reference A4 */
    void setReferenceA4(double hz) { setReference(69, hz); }

    /** Use preset reference */
    enum class ReferencePreset
    {
        A440,               // Modern concert pitch
        A432,               // Natural/Verdi tuning
        ScientificC256,     // C4 = 256 Hz
        BaroqueA415,        // Baroque pitch
        FrenchA435,         // 1859 French standard
        EarthFrequency,     // Based on Earth day (194.18 Hz)
        SchumannAligned     // Based on Schumann resonance octaved
    };

    void setReferencePreset(ReferencePreset preset);

    //==========================================================================
    // Scale/Tuning System
    //==========================================================================

    void setScale(const ScaleDefinition& scale);

    /** Built-in scales */
    enum class BuiltInScale
    {
        EqualTemperament12,     // Standard 12-TET
        Pythagorean,            // 3-limit just
        JustIntonation5Limit,   // 5-limit just (ptolemaic)
        JustIntonation7Limit,   // 7-limit just
        MeantoneQuarterComma,   // 1/4 comma meantone
        WerckmeisterIII,        // Well temperament
        Kirnberger III,         // Another well temperament
        Young,                  // Thomas Young temperament

        // Non-Western
        ArabicMaqam,            // 24-TET quarter tones
        Indian22Shruti,         // 22 shruti system
        Thai7TET,               // 7 equal divisions
        Slendro,                // Javanese pentatonic
        Pelog,                  // Javanese heptatonic

        // Experimental
        Bohlen Pierce,          // Tritave-based (3:1)
        EqualTemperament19,     // 19-TET
        EqualTemperament31,     // 31-TET
        EqualTemperament53,     // 53-TET (approximates just)

        // Cosmic
        SolfeggioScale,         // Based on Solfeggio frequencies
        PlanetaryScale,         // Based on planetary frequencies
        ChakraScale             // Based on chakra frequencies
    };

    void setBuiltInScale(BuiltInScale scale);

    //==========================================================================
    // Frequency Lookup
    //==========================================================================

    /** Get frequency for MIDI note */
    double getMIDIFrequency(int midiNote) const;

    /** Get frequency for scale degree in octave */
    double getScaleDegreeFrequency(int degree, int octave) const;

    /** Get all frequencies for an octave (for instrument tuning) */
    std::vector<double> getOctaveFrequencies(int octave) const;

    /** Get cents deviation from 12-TET for display */
    double getCentsDeviation(int midiNote) const;

    //==========================================================================
    // Micro-tuning
    //==========================================================================

    /** Apply cents offset to specific note */
    void setNoteCentsOffset(int midiNote, double cents);

    /** Get note offset */
    double getNoteCentsOffset(int midiNote) const;

    /** Clear all offsets */
    void clearCentsOffsets();

    /** Apply pitch bend (for real-time use) */
    double applyPitchBend(double baseFreq, float bendNormalized, int bendRangeSemitones = 2) const;

    //==========================================================================
    // Scala Format Support
    //==========================================================================

    /** Load tuning from Scala .scl file */
    bool loadScalaFile(const juce::File& sclFile);

    /** Load keyboard mapping from Scala .kbm file */
    bool loadKeyboardMapping(const juce::File& kbmFile);

    /** Export current tuning to Scala format */
    juce::String exportToScala() const;

private:
    // Reference
    int referenceMidiNote = 69;     // A4
    double referenceFrequency = 440.0;

    // Scale
    ScaleDefinition currentScale;

    // Note-specific offsets (cents)
    std::array<double, 128> noteOffsets;

    // Keyboard mapping
    std::array<int, 128> keyToScaleDegree;
    int octaveRepeat = 12;

    // Cached frequencies
    mutable std::array<double, 128> frequencyCache;
    mutable bool cacheValid = false;

    void invalidateCache() { cacheValid = false; }
    void rebuildCache() const;

    // Built-in scale definitions
    static ScaleDefinition getBuiltInScaleDefinition(BuiltInScale scale);
};

//==============================================================================
// Planetary Tuning
//==============================================================================

/**
 * Tuning system based on Cousto's planetary frequencies
 * Each note can be aligned to a planetary frequency
 */
class PlanetaryTuning
{
public:
    PlanetaryTuning();

    //==========================================================================
    // Configuration
    //==========================================================================

    /** Set root planet for scale */
    void setRootPlanet(const juce::String& planetName);

    /** Set octave (how many times to double/halve planetary frequency) */
    void setOctaveFromPlanetary(int octaves);

    /** Map scale degrees to planets */
    struct PlanetaryMapping
    {
        int scaleDegree;
        juce::String planet;
        bool useRotational = false;  // Use rotation freq instead of orbital
    };

    void setMapping(const std::vector<PlanetaryMapping>& mapping);

    //==========================================================================
    // Presets
    //==========================================================================

    enum class PlanetaryScalePreset
    {
        SolarSystem,        // All planets in order
        InnerPlanets,       // Sun, Mercury, Venus, Earth, Mars
        OuterPlanets,       // Jupiter, Saturn, Uranus, Neptune, Pluto
        EarthMoon,          // Earth-centric with Moon
        ChakraAlignment,    // Planets aligned to chakras
        ZodiacAlignment     // 12 signs, 12 notes
    };

    void loadPreset(PlanetaryScalePreset preset);

    //==========================================================================
    // Tuning Table Generation
    //==========================================================================

    /** Get tuning table based on planetary alignment */
    TuningTable generateTuningTable() const;

    /** Get frequency for planet */
    double getPlanetaryFrequency(const juce::String& planet, int octaveOffset = 0) const;

private:
    juce::String rootPlanet = "Earth";
    int octaveOffset = 0;
    std::vector<PlanetaryMapping> mappings;
};

//==============================================================================
// Chakra Tuning System
//==============================================================================

/**
 * Tuning based on chakra frequency associations
 */
class ChakraTuning
{
public:
    struct ChakraInfo
    {
        juce::String name;
        juce::String sanskritName;
        double baseFrequency;       // Hz
        juce::Colour colour;
        int associatedNote;         // Scale degree (0-6 or 0-11)

        // Related frequencies
        double solfeggioHz = 0.0;
        juce::String planet;
    };

    static const std::array<ChakraInfo, 7>& getChakras()
    {
        static const std::array<ChakraInfo, 7> chakras = {{
            {"Root",         "Muladhara",     396.0, juce::Colours::red,        0, 396.0, "Mars"},
            {"Sacral",       "Svadhisthana",  417.0, juce::Colours::orange,     1, 417.0, "Venus"},
            {"Solar Plexus", "Manipura",      528.0, juce::Colours::yellow,     2, 528.0, "Sun"},
            {"Heart",        "Anahata",       639.0, juce::Colours::green,      3, 639.0, "Earth"},
            {"Throat",       "Vishuddha",     741.0, juce::Colours::cyan,       4, 741.0, "Mercury"},
            {"Third Eye",    "Ajna",          852.0, juce::Colours::indigo,     5, 852.0, "Moon"},
            {"Crown",        "Sahasrara",     963.0, juce::Colours::violet,     6, 963.0, "Jupiter"}
        }};
        return chakras;
    }

    /** Generate 7-note scale based on chakra frequencies */
    static TuningTable generateChakraScale();

    /** Generate 12-note scale with chakras mapped to specific notes */
    static TuningTable generateChakraChromaticScale();

    /** Get chakra for frequency (finds nearest) */
    static const ChakraInfo& getChakraForFrequency(double hz);
};

//==============================================================================
// Harmonic Series Tuning
//==============================================================================

/**
 * Generate tunings based on harmonic series
 */
class HarmonicSeriesTuning
{
public:
    /** Generate scale from first N harmonics */
    static ScaleDefinition fromHarmonicSeries(double fundamental, int numHarmonics);

    /** Generate scale from specific harmonic numbers */
    static ScaleDefinition fromHarmonicNumbers(double fundamental,
                                                const std::vector<int>& harmonicNumbers);

    /** Generate subharmonic scale */
    static ScaleDefinition fromSubharmonicSeries(double fundamental, int numSubharmonics);

    /** Generate combination tone scale (sum and difference tones) */
    static ScaleDefinition fromCombinationTones(double freq1, double freq2, int depth);
};

//==============================================================================
// Instrument Tuner Interface
//==============================================================================

class InstrumentTuner
{
public:
    InstrumentTuner();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    //==========================================================================
    // Tuning Configuration
    //==========================================================================

    void setTuningTable(const TuningTable& table) { tuningTable = table; }
    TuningTable& getTuningTable() { return tuningTable; }

    //==========================================================================
    // Pitch Detection
    //==========================================================================

    struct TuningReading
    {
        bool detected = false;

        double frequencyHz = 0.0;
        double confidence = 0.0;

        // Target note info
        int targetMidiNote = 0;
        juce::String targetNoteName;
        double targetFrequencyHz = 0.0;

        // Deviation
        double centsFromTarget = 0.0;
        bool isFlat = false;
        bool isSharp = false;
        bool inTune = false;

        // For display (-50 to +50 range, clamped)
        float needlePosition = 0.0f;

        // Multi-system comparison
        double centsFromET = 0.0;
        double centsFromPythagorean = 0.0;
        double centsFromJustIntonation = 0.0;
    };

    void processBlock(const float* samples, int numSamples);
    TuningReading getReading() const { return reading; }

    //==========================================================================
    // Configuration
    //==========================================================================

    /** Set tolerance for "in tune" (cents) */
    void setInTuneTolerance(double cents) { inTuneTolerance = cents; }

    /** Set pitch detection range */
    void setPitchRange(double minHz, double maxHz);

    /** Set transposition (for transposing instruments) */
    void setTransposition(int semitones) { transposition = semitones; }

private:
    double sampleRate = 48000.0;
    TuningTable tuningTable;
    TuningReading reading;

    double inTuneTolerance = 5.0;  // cents
    double minPitchHz = 20.0;
    double maxPitchHz = 5000.0;
    int transposition = 0;

    // Pitch detection buffer
    std::vector<float> inputBuffer;
    int inputWritePos = 0;
    int bufferSize = 4096;

    void detectPitch();
    int frequencyToNearestMidiNote(double freq) const;
};

//==============================================================================
// Cymatics Pattern Generator
//==============================================================================

/**
 * Generates Chladni patterns for visualization of frequencies
 */
class CymaticsPatternGenerator
{
public:
    /**
     * Generate Chladni pattern
     * @param frequency - frequency in Hz (determines pattern complexity)
     * @param resolution - grid resolution
     * @param plateSize - virtual plate size in meters
     * @return 2D array of values (0-1)
     */
    static std::vector<float> generateChladniPattern(double frequency,
                                                      int resolution = 64,
                                                      float plateSize = 0.3f);

    /**
     * Calculate Chladni pattern value at point
     * Uses formula: cos(n*π*x/L) * cos(m*π*y/L) - cos(m*π*x/L) * cos(n*π*y/L)
     */
    static float chladniFunction(float x, float y, float m, float n);

    /**
     * Get mode numbers (m, n) for approximate frequency
     * Higher frequencies = higher mode numbers = more complex patterns
     */
    static std::pair<float, float> frequencyToModeNumbers(double frequency,
                                                           float plateSize = 0.3f);

    /**
     * Generate circular cymatics pattern (as seen in water/sand on speaker)
     */
    static std::vector<float> generateCircularPattern(double frequency,
                                                       int resolution = 64);

    /**
     * Animate pattern over time
     * @param time - animation time in seconds
     * @param animationSpeed - speed multiplier
     */
    static std::vector<float> generateAnimatedPattern(double frequency,
                                                       double time,
                                                       int resolution = 64,
                                                       float animationSpeed = 1.0f);
};

//==============================================================================
// Frequency Color Mapper (Synesthesia)
//==============================================================================

/**
 * Maps frequencies to colors using various scientific models
 */
class FrequencyColorMapper
{
public:
    enum class MappingMethod
    {
        OctaveToSpectrum,   // Map octaves to visible light spectrum
        Logarithmic,        // Logarithmic mapping
        ChakraColors,       // Chakra-based color associations
        SynaestheticStandard, // Scriabin-inspired
        Physical            // Based on E=hf wavelength
    };

    /**
     * Map audio frequency to color
     */
    static juce::Colour frequencyToColour(double frequencyHz,
                                           MappingMethod method = MappingMethod::OctaveToSpectrum);

    /**
     * Map MIDI note to color
     */
    static juce::Colour midiNoteToColour(int midiNote,
                                          MappingMethod method = MappingMethod::OctaveToSpectrum);

    /**
     * Get spectrum visualization colors for frequency range
     */
    static std::vector<juce::Colour> getSpectrumColors(int numBands,
                                                        double minHz = 20.0,
                                                        double maxHz = 20000.0,
                                                        MappingMethod method = MappingMethod::OctaveToSpectrum);

    /**
     * Alexander Scriabin's color associations (Prometheus chord)
     */
    static juce::Colour scriabinNoteToColour(int noteClass);  // 0-11

private:
    static juce::Colour wavelengthToRGB(double wavelengthNm);
    static double frequencyToWavelength(double audioHz);
};

}  // namespace Echoel::DSP
