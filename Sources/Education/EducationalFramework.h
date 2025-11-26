#pragma once

#include <JuceHeader.h>

/**
 * EducationalFramework - Music History + Science Education
 *
 * EDUCATIONAL CONTENT:
 * - Music History: Ancient to Modern, worldwide cultures
 * - Scientific Foundation: NASA research, psychoacoustics, quantum physics
 * - Frequency Research: Documented scientific studies (NO HEALTH CLAIMS!)
 * - Worldwide Music Styles: African, Asian, Latin American, Middle Eastern, etc.
 * - Cultural Context: Historical and social significance
 *
 * SCIENTIFIC RIGOR:
 * ⚠️ NO HEALTH CLAIMS! Only peer-reviewed, documented research
 * ✅ All references cite published studies
 * ✅ Clear distinction between scientific fact and theory
 * ✅ Educational purpose only
 *
 * Usage:
 * ```cpp
 * EducationalFramework education;
 *
 * // Music history
 * auto baroque = education.getMusicEra(MusicEra::Baroque);
 * DBG(baroque.description);
 *
 * // Scientific info
 * auto adey = education.getFrequencyResearch("Adey Windows");
 * DBG(adey.scientificEvidence);
 *
 * // Worldwide music
 * auto african = education.getWorldMusicStyle("West African Polyrhythm");
 * DBG(african.culturalContext);
 * ```
 */

//==============================================================================
// Music History Eras
//==============================================================================

enum class MusicEra
{
    // Ancient
    Prehistoric,        // Before 3000 BCE
    Ancient,            // 3000 BCE - 500 CE
    Medieval,           // 500 - 1400
    Renaissance,        // 1400 - 1600

    // Classical Period
    Baroque,            // 1600 - 1750
    Classical,          // 1750 - 1820
    Romantic,           // 1820 - 1900

    // Modern
    Impressionist,      // 1890 - 1920
    Modernist,          // 1900 - 1975
    Contemporary,       // 1975 - present

    // Popular
    Blues_Jazz,         // 1890 - present
    Rock,               // 1950s - present
    Electronic,         // 1970s - present
    HipHop,            // 1970s - present
    WorldMusic,        // All eras, non-Western

    Unknown
};

struct MusicEraInfo
{
    MusicEra era;
    juce::String name;
    juce::String timeperiod;
    juce::String description;
    juce::StringArray keyComposers;
    juce::StringArray keyWorks;
    juce::StringArray musicalCharacteristics;
    juce::StringArray culturalContext;
    juce::StringArray instruments;

    // Worldwide variations
    juce::StringArray worldwideInfluences;
};

//==============================================================================
// Worldwide Music Styles
//==============================================================================

enum class MusicCulture
{
    // Africa
    WestAfrican,
    EastAfrican,
    SouthAfrican,

    // Asia
    Indian_Classical,
    Chinese_Traditional,
    Japanese_Traditional,
    Arabic_Maqam,
    Persian_Dastgah,
    Indonesian_Gamelan,

    // Europe
    Western_Classical,
    Flamenco,
    Celtic,
    Slavic,

    // Americas
    Native_American,
    Andean,
    Brazilian,
    Caribbean,
    Blues_Gospel,

    // Oceania
    Aboriginal_Australian,
    Polynesian,

    // Modern Fusion
    AfroCaribbean,
    LatinJazz,
    WorldFusion,

    Unknown
};

struct WorldMusicStyle
{
    MusicCulture culture;
    juce::String name;
    juce::String region;
    juce::String description;

    // Musical characteristics
    juce::StringArray scales;           // Pentatonic, Raga, Maqam, etc.
    juce::StringArray rhythms;          // Polyrhythm, Clave, Tala, etc.
    juce::StringArray instruments;

    // Cultural context
    juce::String culturalSignificance;
    juce::String historicalOrigin;
    juce::StringArray socialFunctions;  // Ritual, celebration, storytelling

    // Modern influence
    juce::StringArray modernGenres;     // How it influenced contemporary music
};

//==============================================================================
// Scientific Research
//==============================================================================

struct ScientificReference
{
    juce::String topic;
    juce::String title;
    juce::String authors;
    juce::String publication;
    int year = 0;
    juce::String doi;                   // Digital Object Identifier
    juce::String summary;
    juce::String keyFindings;

    // Evidence level
    enum class EvidenceLevel
    {
        PeerReviewed,       // Published in peer-reviewed journal
        Replicated,         // Multiple independent studies
        Theoretical,        // Theoretical framework
        Preliminary,        // Early research
        Historical          // Historical document
    };

    EvidenceLevel evidenceLevel = EvidenceLevel::Theoretical;

    bool isPeerReviewed() const { return evidenceLevel == EvidenceLevel::PeerReviewed ||
                                         evidenceLevel == EvidenceLevel::Replicated; }
};

//==============================================================================
// Frequency Research (NO HEALTH CLAIMS!)
//==============================================================================

struct FrequencyResearch
{
    juce::String name;
    float frequencyHz = 0.0f;
    juce::String scientificDescription;

    // Documented research (peer-reviewed only!)
    juce::Array<ScientificReference> references;

    // Observable phenomena (NOT health claims!)
    juce::String observableEffects;     // Only documented, measurable effects
    juce::String measurementMethods;    // How effects were measured

    // ⚠️ DISCLAIMER
    juce::String disclaimer;

    // Categories
    enum class Category
    {
        NASA_Research,          // NASA Adey Windows, etc.
        Geophysical,           // Schumann Resonance
        Psychoacoustic,        // Fletcher-Munson, Critical Bands
        Musical,               // Concert pitch, tuning systems
        Theoretical            // Quantum analogies, theoretical
    };

    Category category = Category::Theoretical;
};

//==============================================================================
// Psychoacoustic Phenomena
//==============================================================================

struct PsychoAcousticInfo
{
    juce::String name;
    juce::String description;
    juce::String scientificBasis;

    // Examples
    float frequencyRangeStart = 0.0f;
    float frequencyRangeEnd = 0.0f;

    // References
    juce::Array<ScientificReference> references;

    // Application in music
    juce::String musicalApplication;
};

//==============================================================================
// Quantum Audio Concepts (Educational Analogies!)
//==============================================================================

struct QuantumAudioConcept
{
    juce::String name;
    juce::String quantumPhysicsPrinciple;
    juce::String audioAnalogy;          // How it relates to audio (educational!)

    // ⚠️ IMPORTANT: These are ANALOGIES for education, NOT real quantum effects!
    juce::String educationalDisclaimer;

    // Examples
    juce::String practicalExample;
};

//==============================================================================
// Color-Sound Synesthesia
//==============================================================================

struct ColorSoundTheory
{
    juce::String theorist;              // Kandinsky, Scriabin, etc.
    juce::String theory;
    int year = 0;

    struct ColorFrequencyMapping
    {
        juce::Colour color;
        float frequencyHz = 0.0f;
        juce::String note;
        juce::String description;
    };

    juce::Array<ColorFrequencyMapping> mappings;

    juce::String culturalContext;
    juce::String modernApplication;
};

//==============================================================================
// Language Support
//==============================================================================

enum class Language
{
    English,
    German,
    Spanish,
    French,
    Italian,
    Portuguese,
    Mandarin,
    Japanese,
    Korean,
    Arabic,
    Hindi,
    Russian,
    // Add more as needed
    Unknown
};

//==============================================================================
// EducationalFramework - Main Class
//==============================================================================

class EducationalFramework
{
public:
    EducationalFramework();
    ~EducationalFramework();

    //==========================================================================
    // Music History
    //==========================================================================

    /** Get information about a music era */
    MusicEraInfo getMusicEra(MusicEra era) const;

    /** Get all music eras */
    juce::Array<MusicEraInfo> getAllMusicEras() const;

    /** Search music history */
    juce::Array<MusicEraInfo> searchMusicHistory(const juce::String& query) const;

    //==========================================================================
    // Worldwide Music Styles
    //==========================================================================

    /** Get world music style information */
    WorldMusicStyle getWorldMusicStyle(MusicCulture culture) const;

    /** Get all world music styles */
    juce::Array<WorldMusicStyle> getAllWorldMusicStyles() const;

    /** Search by region */
    juce::Array<WorldMusicStyle> getStylesByRegion(const juce::String& region) const;

    /** Get cultural context */
    juce::String getCulturalContext(const juce::String& styleName) const;

    //==========================================================================
    // Scientific Research (NO HEALTH CLAIMS!)
    //==========================================================================

    /** Get frequency research (NASA Adey Windows, etc.) */
    FrequencyResearch getFrequencyResearch(const juce::String& name) const;

    /** Get all frequency research */
    juce::Array<FrequencyResearch> getAllFrequencyResearch() const;

    /** Get peer-reviewed references only */
    juce::Array<ScientificReference> getPeerReviewedReferences(const juce::String& topic) const;

    /** Get NASA research specifically */
    juce::Array<FrequencyResearch> getNASAResearch() const;

    /** Get Schumann Resonance info */
    FrequencyResearch getSchumannResonance() const;

    //==========================================================================
    // Psychoacoustics
    //==========================================================================

    /** Get psychoacoustic phenomenon info */
    PsychoAcousticInfo getPsychoAcousticInfo(const juce::String& phenomenon) const;

    /** Get Fletcher-Munson curves */
    PsychoAcousticInfo getFletcherMunsonCurves() const;

    /** Get critical bands info */
    PsychoAcousticInfo getCriticalBands() const;

    //==========================================================================
    // Quantum Audio Concepts (Educational Analogies!)
    //==========================================================================

    /** Get quantum audio concept */
    QuantumAudioConcept getQuantumConcept(const juce::String& name) const;

    /** Get all quantum concepts */
    juce::Array<QuantumAudioConcept> getAllQuantumConcepts() const;

    //==========================================================================
    // Color-Sound Theory
    //==========================================================================

    /** Get color-sound theory */
    ColorSoundTheory getColorSoundTheory(const juce::String& theorist) const;

    /** Get all color-sound theories */
    juce::Array<ColorSoundTheory> getAllColorSoundTheories() const;

    //==========================================================================
    // Educational Content
    //==========================================================================

    /** Get educational article */
    juce::String getEducationalArticle(const juce::String& topic) const;

    /** Get learning path for topic */
    juce::StringArray getLearningPath(const juce::String& topic) const;

    /** Get quiz questions */
    juce::StringArray getQuizQuestions(const juce::String& topic) const;

    //==========================================================================
    // Language Support
    //==========================================================================

    /** Set UI language */
    void setLanguage(Language language);

    /** Get current language */
    Language getCurrentLanguage() const;

    /** Get translated string */
    juce::String getLocalizedString(const juce::String& key) const;

    /** Get available languages */
    juce::Array<Language> getAvailableLanguages() const;

    //==========================================================================
    // Search & Discovery
    //==========================================================================

    /** Search all educational content */
    juce::StringArray searchAllContent(const juce::String& query) const;

    /** Get related topics */
    juce::StringArray getRelatedTopics(const juce::String& topic) const;

    /** Get recommended learning */
    juce::StringArray getRecommendedLearning(const juce::String& userLevel) const;

    //==========================================================================
    // Disclaimer & Ethics
    //==========================================================================

    /** Get health disclaimer (NO HEALTH CLAIMS!) */
    juce::String getHealthDisclaimer() const;

    /** Get scientific disclaimer */
    juce::String getScientificDisclaimer() const;

    /** Get educational disclaimer */
    juce::String getEducationalDisclaimer() const;

private:
    // Database
    std::map<MusicEra, MusicEraInfo> musicErasDatabase;
    std::map<MusicCulture, WorldMusicStyle> worldMusicDatabase;
    std::map<juce::String, FrequencyResearch> frequencyResearchDatabase;
    std::map<juce::String, PsychoAcousticInfo> psychoacousticDatabase;
    std::map<juce::String, QuantumAudioConcept> quantumConceptsDatabase;
    std::map<juce::String, ColorSoundTheory> colorSoundDatabase;

    // Localization
    Language currentLanguage = Language::English;
    std::map<juce::String, std::map<Language, juce::String>> localizationStrings;

    // Initialization
    void initializeMusicHistory();
    void initializeWorldMusic();
    void initializeFrequencyResearch();
    void initializePsychoacoustics();
    void initializeQuantumConcepts();
    void initializeColorSound();
    void initializeLocalization();

    // Helpers
    void addMusicEra(const MusicEraInfo& info);
    void addWorldMusicStyle(const WorldMusicStyle& style);
    void addFrequencyResearch(const FrequencyResearch& research);
    void addPsychoAcoustic(const PsychoAcousticInfo& info);
    void addQuantumConcept(const QuantumAudioConcept& concept);
    void addColorSoundTheory(const ColorSoundTheory& theory);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EducationalFramework)
};
