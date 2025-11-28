#pragma once

#include <JuceHeader.h>
#include "ChordGenius.h"
#include <string>
#include <vector>
#include <map>

/**
 * WorldMusicDatabase - Global Music Style Database
 *
 * Comprehensive database of musical styles from around the world:
 * - Modern genres (Pop, Rock, Hip-Hop, EDM, etc.)
 * - Classical periods (Baroque, Classical, Romantic, Contemporary)
 * - World music (African, Asian, Latin American, Middle Eastern, etc.)
 * - Jazz traditions (Bebop, Modal, Fusion, etc.)
 * - Folk traditions (Celtic, Nordic, Slavic, etc.)
 *
 * Each style contains:
 * - Typical chord progressions
 * - Characteristic scales/modes
 * - Rhythmic patterns
 * - Melodic contours
 * - Tempo ranges
 * - Instrumentation
 * - Historical context
 *
 * Used by: ChordGenius, MelodyForge, BasslineArchitect, ArpWeaver
 */
class WorldMusicDatabase
{
public:
    WorldMusicDatabase();
    ~WorldMusicDatabase();

    //==============================================================================
    // Music Style Categories

    enum class StyleCategory
    {
        // Modern Popular
        Pop,
        Rock,
        HipHop,
        RnB,
        Soul,
        Funk,
        Disco,

        // Electronic/Dance
        House,
        Techno,
        Trance,
        DubStep,
        DrumAndBass,
        Ambient,
        Synthwave,

        // Classical Periods
        Medieval,           // 500-1400
        Renaissance,        // 1400-1600
        Baroque,            // 1600-1750
        Classical,          // 1750-1820
        Romantic,           // 1820-1900
        Impressionist,      // 1890-1920
        ModernClassical,    // 1900-present

        // Jazz
        DixielandJazz,      // 1910s-1920s
        Swing,              // 1930s-1940s
        Bebop,              // 1940s
        CoolJazz,           // 1950s
        ModalJazz,          // 1960s
        FreeJazz,           // 1960s
        FusionJazz,         // 1970s
        SmoothJazz,         // 1980s-present

        // Blues & Country
        DeltaBlues,
        ChicagoBlues,
        Country,
        Bluegrass,

        // Latin American
        Salsa,
        BossaNova,
        Tango,
        Cumbia,
        Reggaeton,
        Samba,
        Mambo,

        // African
        Afrobeat,
        Highlife,
        Soukous,
        Mbalax,

        // Caribbean
        Reggae,
        Ska,
        Calypso,
        Soca,

        // Asian
        IndianClassical,
        ChineseTraditional,
        JapaneseTraditional,
        Gamelan,            // Indonesian
        KPop,
        JPop,

        // Middle Eastern
        Arabic,
        Persian,
        Turkish,

        // European Folk
        Celtic,
        Nordic,
        Slavic,
        Flamenco,           // Spanish
        Fado,               // Portuguese
        Balkan,             // Balkan traditional

        // Sacred/Spiritual/Ritual
        GregorianChant,     // Medieval church music
        TibetanBuddhist,    // Tibetan chanting, singing bowls
        SufiMusic,          // Sufi/Dervish whirling, Qawwali
        HinduDevotional,    // Kirtan, Bhajan, Vedic chanting
        NativeAmerican,     // Indigenous North American
        AfricanTribal,      // Traditional African ceremonial
        ShamanicHealing,    // Shamanic/healing traditions worldwide
        ThroatSinging,      // Tuvan, Mongolian, Inuit overtone singing
        NewAge,             // Modern spiritual/meditation music

        // Modern Electronic (Extended)
        LoFiHipHop,         // Chillhop, study beats
        Vaporwave,          // Aesthetic, nostalgic electronic
        Hyperpop,           // Experimental pop, PC Music style
        Drill,              // UK Drill, NY Drill
        DarkAmbient,        // Drone, dark atmospheric
        Chiptune,           // 8-bit, video game music
        IDM,                // Intelligent Dance Music
        Glitch,             // Glitch electronic
        Microhouse,         // Minimal house

        // Other
        Gospel,
        Metal,
        Punk,
        Grunge,
        Indie,
        Alternative,
        WorldFusion         // Cross-cultural fusion
    };

    //==============================================================================
    // Music Style Definition

    struct MusicStyle
    {
        std::string name;
        StyleCategory category;
        std::string region;             // Geographic origin
        std::string period;             // Historical period

        // Musical characteristics
        std::vector<std::vector<int>> typicalProgressions;  // Common chord progressions (Roman numerals)
        std::vector<ChordGenius::Scale> typicalScales;
        std::vector<ChordGenius::ChordQuality> preferredChords;

        float minTempo;                 // BPM range
        float maxTempo;

        std::string rhythmicFeel;       // Straight, swing, shuffle, etc.
        std::string melodicContour;     // Stepwise, leap-friendly, chromatic, etc.

        std::vector<std::string> typicalInstruments;
        std::string description;

        // Composition rules
        float chromaticismAmount;       // 0-1: diatonic to chromatic
        float dissonanceAmount;         // 0-1: consonant to dissonant
        float complexityLevel;          // 0-1: simple to complex
        float syncopationAmount;        // 0-1: straight to heavily syncopated
    };

    //==============================================================================
    // Database Access

    /** Get style by category */
    MusicStyle getStyle(StyleCategory category);

    /** Get all styles in region */
    std::vector<MusicStyle> getStylesByRegion(const std::string& region);

    /** Get all styles in period */
    std::vector<MusicStyle> getStylesByPeriod(const std::string& period);

    /** Search styles by name */
    std::vector<MusicStyle> searchStyles(const std::string& query);

    /** Get all available styles */
    std::vector<MusicStyle> getAllStyles();

    /** Get style names list */
    std::vector<std::string> getStyleNames();

    /** Get random style */
    MusicStyle getRandomStyle();

    //==============================================================================
    // Integration with MIDI Tools

    /** Get chord progression for style */
    std::vector<ChordGenius::Chord> getProgressionForStyle(StyleCategory category,
                                                            int key,
                                                            int length = 4);

    /** Get scale for style */
    ChordGenius::Scale getScaleForStyle(StyleCategory category);

    /** Get tempo range for style */
    std::pair<float, float> getTempoRangeForStyle(StyleCategory category);

private:
    //==============================================================================
    // Style Database
    std::map<StyleCategory, MusicStyle> styleDatabase;

    void initializeDatabase();
    void addModernStyles();
    void addClassicalStyles();
    void addJazzStyles();
    void addWorldMusicStyles();
    void addLatinStyles();
    void addAfricanStyles();
    void addAsianStyles();
    void addMiddleEasternStyles();
    void addEuropeanFolkStyles();
    void addSacredSpiritualStyles();    // NEW: Sacred/Ritual/Healing music
    void addModernElectronicStyles();   // NEW: Extended electronic genres

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (WorldMusicDatabase)
};
