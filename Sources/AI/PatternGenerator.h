#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <map>
#include <random>

/**
 * AI Pattern Generator
 *
 * Intelligent drum pattern generation using:
 * - Markov chains for style-aware patterns
 * - Bio-data integration (HRV → complexity, Coherence → density)
 * - Genre-specific templates (House, Techno, Hip-Hop, Drum & Bass, etc.)
 * - Pattern mutation and evolution
 * - Humanization (velocity, timing micro-variations)
 * - Groove templates
 * - Fill generation
 *
 * Inspired by: Native Instruments Battery, Ableton Live Rhythm Generator,
 * XLN Audio XO, AI-powered tools like LANDR, AIVA
 */
class PatternGenerator
{
public:
    //==========================================================================
    // Music Genres
    //==========================================================================

    enum class Genre
    {
        House,          // 4-on-floor kick, open hats on offbeats
        Techno,         // Driving kick, minimal, hypnotic
        HipHop,         // Boom-bap, swing, snare on 2/4
        DrumAndBass,    // Fast (170 BPM), syncopated, complex
        Trap,           // 808 kicks, hi-hat rolls, snare on 3
        Funk,           // Swing, ghost notes, syncopation
        Ambient,        // Sparse, textural, minimal
        Rock,           // Straight 8ths, backbeat on 2/4
        Jazz,           // Complex swing, ride patterns
        Experimental    // Random, glitchy, unpredictable
    };

    //==========================================================================
    // Pattern Structure
    //==========================================================================

    struct Note
    {
        int step = 0;               // 0-15 (for 16-step pattern)
        int drum = 0;               // Drum index (0-11: kick, snare, hats, etc.)
        float velocity = 0.8f;      // 0.0-1.0
        float timing = 0.0f;        // -0.1 to +0.1 (timing micro-shift in beats)
        bool accent = false;        // Emphasized note

        Note(int s, int d, float v = 0.8f) : step(s), drum(d), velocity(v) {}
    };

    struct Pattern
    {
        std::vector<Note> notes;
        int length = 16;            // Steps (typically 16 for 1 bar)
        float swing = 0.0f;         // 0.0-1.0 (shuffle amount)
        Genre genre = Genre::House;
        float complexity = 0.5f;    // 0.0-1.0
        float density = 0.5f;       // 0.0-1.0 (how many notes)
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    PatternGenerator();
    ~PatternGenerator() = default;

    //==========================================================================
    // Pattern Generation
    //==========================================================================

    /** Generate pattern based on genre and parameters */
    Pattern generatePattern(Genre genre, float complexity = 0.5f, float density = 0.5f);

    /** Generate pattern with bio-data influence */
    Pattern generateBioReactivePattern(Genre genre, float hrv, float coherence);

    /** Generate fill pattern (transition between patterns) */
    Pattern generateFill(const Pattern& basePattern, int fillLength = 4);

    /** Mutate existing pattern (variation) */
    Pattern mutatePattern(const Pattern& pattern, float mutationAmount = 0.3f);

    /** Humanize pattern (add timing and velocity variations) */
    void humanizePattern(Pattern& pattern, float amount = 0.5f);

    //==========================================================================
    // Groove & Feel
    //==========================================================================

    /** Set global swing amount (0.0 = straight, 1.0 = full triplet swing) */
    void setSwing(float amount);

    /** Set humanization amount (0.0 = robotic, 1.0 = very human) */
    void setHumanization(float amount);

    /** Set random seed for reproducible patterns */
    void setSeed(unsigned int seed);

    //==========================================================================
    // Genre Templates
    //==========================================================================

    /** Get typical BPM range for genre */
    static std::pair<int, int> getBPMRange(Genre genre);

    /** Get typical instruments used in genre */
    static std::vector<int> getGenreInstruments(Genre genre);

    //==========================================================================
    // Pattern Analysis
    //==========================================================================

    /** Calculate pattern complexity (0.0-1.0) */
    static float analyzeComplexity(const Pattern& pattern);

    /** Calculate pattern density (notes per step, 0.0-1.0) */
    static float analyzeDensity(const Pattern& pattern);

    /** Detect pattern groove/feel */
    static float analyzeSwing(const Pattern& pattern);

private:
    //==========================================================================
    // Markov Chain Pattern Generation
    //==========================================================================

    struct MarkovState
    {
        std::map<int, float> nextProbabilities;  // Next step drum → probability
    };

    std::map<Genre, std::map<int, MarkovState>> markovChains;  // [genre][drum][state]

    void initializeMarkovChains();
    int selectNextDrum(Genre genre, int currentDrum);

    //==========================================================================
    // Genre-Specific Generators
    //==========================================================================

    Pattern generateHousePattern(float complexity, float density);
    Pattern generateTechnoPattern(float complexity, float density);
    Pattern generateHipHopPattern(float complexity, float density);
    Pattern generateDrumAndBassPattern(float complexity, float density);
    Pattern generateTrapPattern(float complexity, float density);

    //==========================================================================
    // Pattern Building Helpers
    //==========================================================================

    void addKickPattern(Pattern& pattern, Genre genre, float density);
    void addSnarePattern(Pattern& pattern, Genre genre, float density);
    void addHiHatPattern(Pattern& pattern, Genre genre, float complexity);

    void addGrooveVariation(Pattern& pattern, float complexity);
    void addSyncopation(Pattern& pattern, float amount);
    void addGhostNotes(Pattern& pattern, float amount);

    //==========================================================================
    // Randomization
    //==========================================================================

    float swing = 0.0f;
    float humanization = 0.5f;

    std::mt19937 randomGenerator;
    std::uniform_real_distribution<float> distribution {0.0f, 1.0f};

    float random() { return distribution(randomGenerator); }
    int randomInt(int min, int max) { return min + (randomGenerator() % (max - min + 1)); }

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (PatternGenerator)
};
