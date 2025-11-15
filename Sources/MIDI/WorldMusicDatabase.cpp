#include "WorldMusicDatabase.h"
#include <algorithm>

WorldMusicDatabase::WorldMusicDatabase()
{
    initializeDatabase();
}

WorldMusicDatabase::~WorldMusicDatabase()
{
}

void WorldMusicDatabase::initializeDatabase()
{
    addModernStyles();
    addClassicalStyles();
    addJazzStyles();
    addWorldMusicStyles();
    addLatinStyles();
    addAfricanStyles();
    addAsianStyles();
    addMiddleEasternStyles();
    addEuropeanFolkStyles();
}

//==============================================================================
// Modern Popular Styles

void WorldMusicDatabase::addModernStyles()
{
    // Pop
    styleDatabase[StyleCategory::Pop] = {
        "Pop", StyleCategory::Pop, "Global", "1950s-Present",
        {{0, 4, 5, 3}, {5, 3, 0, 4}},  // I-V-vi-IV, vi-IV-I-V
        {ChordGenius::Scale::Major, ChordGenius::Scale::MinorPentatonic},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Dominant7},
        100.0f, 130.0f,
        "Straight", "Arch",
        {"Vocals", "Guitar", "Piano", "Bass", "Drums", "Synth"},
        "Catchy melodies, simple harmonies, verse-chorus structure",
        0.2f, 0.2f, 0.4f, 0.3f
    };

    // Rock
    styleDatabase[StyleCategory::Rock] = {
        "Rock", StyleCategory::Rock, "USA/UK", "1950s-Present",
        {{0, 3, 4}, {0, 5, 3, 4}},  // I-IV-V, I-vi-IV-V
        {ChordGenius::Scale::MinorPentatonic, ChordGenius::Scale::Blues},
        {ChordGenius::ChordQuality::Power, ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Dominant7},
        110.0f, 160.0f,
        "Straight with backbeat", "Leap-friendly",
        {"Electric Guitar", "Bass", "Drums", "Vocals"},
        "Power chords, blues scale, guitar-driven",
        0.3f, 0.4f, 0.5f, 0.2f
    };

    // Hip-Hop
    styleDatabase[StyleCategory::HipHop] = {
        "Hip-Hop", StyleCategory::HipHop, "USA", "1970s-Present",
        {{5, 3}, {0, 5}},  // vi-IV, I-vi
        {ChordGenius::Scale::MinorPentatonic, ChordGenius::Scale::Dorian},
        {ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Minor7},
        80.0f, 110.0f,
        "Heavily syncopated", "Plateau",
        {"Drums", "Bass", "Samples", "Synth", "Vocals"},
        "Sample-based, strong beat, sparse chords",
        0.3f, 0.3f, 0.3f, 0.8f
    };

    // R&B/Soul
    styleDatabase[StyleCategory::RnB] = {
        "R&B/Soul", StyleCategory::RnB, "USA", "1940s-Present",
        {{1, 4, 0}, {0, 3, 1, 4}},  // ii-V-I, I-IV-ii-V
        {ChordGenius::Scale::Dorian, ChordGenius::Scale::Mixolydian},
        {ChordGenius::ChordQuality::Major7, ChordGenius::ChordQuality::Minor7, ChordGenius::ChordQuality::Dominant9},
        70.0f, 110.0f,
        "Swing/shuffle", "Smooth stepwise",
        {"Vocals", "Piano", "Bass", "Drums", "Horns"},
        "Extended chords, gospel influence, emotional vocals",
        0.4f, 0.3f, 0.6f, 0.5f
    };

    // House
    styleDatabase[StyleCategory::House] = {
        "House", StyleCategory::House, "USA/Europe", "1980s-Present",
        {{0}, {5, 3}},  // Single chord or vi-IV vamps
        {ChordGenius::Scale::NaturalMinor, ChordGenius::Scale::Dorian},
        {ChordGenius::ChordQuality::Minor7, ChordGenius::ChordQuality::Major7},
        120.0f, 130.0f,
        "Four-on-the-floor", "Repetitive",
        {"Kick", "Claps", "Synth", "Bass"},
        "Four-on-the-floor kick, repetitive hooks, 120-130 BPM",
        0.2f, 0.2f, 0.3f, 0.1f
    };

    // Techno
    styleDatabase[StyleCategory::Techno] = {
        "Techno", StyleCategory::Techno, "Germany/USA", "1980s-Present",
        {{0}, {5}},  // Minimal chord changes
        {ChordGenius::Scale::MinorPentatonic, ChordGenius::Scale::Chromatic},
        {ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Power},
        120.0f, 150.0f,
        "Straight 16ths", "Minimal",
        {"Kick", "Hi-hat", "Synth", "Bass"},
        "Repetitive 4/4, industrial sounds, minimalist",
        0.3f, 0.4f, 0.3f, 0.1f
    };

    // DubStep
    styleDatabase[StyleCategory::DubStep] = {
        "DubStep", StyleCategory::DubStep, "UK", "2000s-Present",
        {{5, 3, 0}, {0, 5}},  // vi-IV-I, I-vi
        {ChordGenius::Scale::MinorPentatonic, ChordGenius::Scale::Phrygian},
        {ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Power},
        135.0f, 145.0f,
        "Half-time feel (70 BPM feel)", "Dark descending",
        {"Sub Bass", "Wobble Bass", "Drums", "Synth"},
        "Half-time feel, wobble bass, heavy sub bass, 140 BPM",
        0.4f, 0.6f, 0.5f, 0.3f
    };
}

//==============================================================================
// Classical Periods

void WorldMusicDatabase::addClassicalStyles()
{
    // Baroque (1600-1750)
    styleDatabase[StyleCategory::Baroque] = {
        "Baroque", StyleCategory::Baroque, "Europe", "1600-1750",
        {{0, 4, 0}, {0, 3, 4, 0}},  // I-V-I, I-IV-V-I
        {ChordGenius::Scale::Major, ChordGenius::Scale::HarmonicMinor},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Diminished7},
        90.0f, 140.0f,
        "Steady pulse, ornamentation", "Contrapuntal, sequential",
        {"Harpsichord", "Violin", "Cello", "Organ", "Flute"},
        "Contrapuntal, ornamentation, figured bass (Bach, Vivaldi, Handel)",
        0.5f, 0.4f, 0.8f, 0.2f
    };

    // Classical (1750-1820)
    styleDatabase[StyleCategory::Classical] = {
        "Classical", StyleCategory::Classical, "Europe", "1750-1820",
        {{0, 4, 0}, {0, 3, 1, 4, 0}},  // I-V-I, I-IV-ii-V-I
        {ChordGenius::Scale::Major, ChordGenius::Scale::NaturalMinor},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Dominant7},
        100.0f, 160.0f,
        "Clear phrasing", "Balanced, symmetrical",
        {"Piano", "Violin", "Viola", "Cello", "Clarinet"},
        "Balance, clarity, sonata form (Mozart, Haydn, Beethoven)",
        0.3f, 0.3f, 0.7f, 0.1f
    };

    // Romantic (1820-1900)
    styleDatabase[StyleCategory::Romantic] = {
        "Romantic", StyleCategory::Romantic, "Europe", "1820-1900",
        {{0, 3, 1, 4}, {0, 5, 3, 4}},
        {ChordGenius::Scale::Major, ChordGenius::Scale::HarmonicMinor, ChordGenius::Scale::WholeTone},
        {ChordGenius::ChordQuality::Major7, ChordGenius::ChordQuality::Augmented, ChordGenius::ChordQuality::Diminished7},
        60.0f, 140.0f,
        "Rubato, expressive", "Wide leaps, chromatic",
        {"Piano", "Orchestra", "Voice"},
        "Emotional expression, chromaticism, large forms (Chopin, Brahms, Wagner)",
        0.7f, 0.6f, 0.9f, 0.3f
    };

    // Impressionist
    styleDatabase[StyleCategory::Impressionist] = {
        "Impressionist", StyleCategory::Impressionist, "France", "1890-1920",
        {{0, 1, 0}, {0, 6, 0}},  // Unconventional progressions
        {ChordGenius::Scale::WholeTone, ChordGenius::Scale::MajorPentatonic, ChordGenius::Scale::Lydian},
        {ChordGenius::ChordQuality::Major9, ChordGenius::ChordQuality::Dominant9, ChordGenius::ChordQuality::Augmented},
        60.0f, 100.0f,
        "Floating, atmospheric", "Ambiguous, coloristic",
        {"Piano", "Orchestra", "Harp", "Flute"},
        "Whole-tone scales, parallel chords, atmospheric (Debussy, Ravel)",
        0.8f, 0.7f, 0.9f, 0.2f
    };
}

//==============================================================================
// Jazz Styles

void WorldMusicDatabase::addJazzStyles()
{
    // Bebop
    styleDatabase[StyleCategory::Bebop] = {
        "Bebop", StyleCategory::Bebop, "USA", "1940s",
        {{1, 4, 0}, {0, 3, 1, 4}},  // ii-V-I, I-IV-ii-V
        {ChordGenius::Scale::Dorian, ChordGenius::Scale::Mixolydian, ChordGenius::Scale::Diminished},
        {ChordGenius::ChordQuality::Dominant7, ChordGenius::ChordQuality::Minor7, ChordGenius::ChordQuality::Major7},
        180.0f, 300.0f,
        "Swing", "Chromatic, angular",
        {"Saxophone", "Trumpet", "Piano", "Bass", "Drums"},
        "Fast tempo, complex harmony, virtuosic improvisation (Parker, Gillespie)",
        0.8f, 0.7f, 0.9f, 0.7f
    };

    // Modal Jazz
    styleDatabase[StyleCategory::ModalJazz] = {
        "Modal Jazz", StyleCategory::ModalJazz, "USA", "1960s",
        {{0}, {0, 1}},  // Static harmony, modal interchange
        {ChordGenius::Scale::Dorian, ChordGenius::Scale::Phrygian, ChordGenius::Scale::Mixolydian},
        {ChordGenius::ChordQuality::Minor7, ChordGenius::ChordQuality::Dominant7},
        120.0f, 180.0f,
        "Swing or straight", "Modal, scalar",
        {"Saxophone", "Trumpet", "Piano", "Bass", "Drums"},
        "Modal scales, static harmony, modal improvisation (Davis, Coltrane)",
        0.3f, 0.3f, 0.7f, 0.4f
    };

    // Smooth Jazz
    styleDatabase[StyleCategory::SmoothJazz] = {
        "Smooth Jazz", StyleCategory::SmoothJazz, "USA", "1980s-Present",
        {{0, 3, 1, 4}, {5, 3, 0, 4}},
        {ChordGenius::Scale::Major, ChordGenius::Scale::Dorian},
        {ChordGenius::ChordQuality::Major9, ChordGenius::ChordQuality::Minor9, ChordGenius::ChordQuality::Dominant13},
        90.0f, 120.0f,
        "Straight 8ths", "Smooth, lyrical",
        {"Saxophone", "Guitar", "Keys", "Bass", "Drums"},
        "Accessible melodies, pop influence, polished production",
        0.4f, 0.2f, 0.6f, 0.3f
    };
}

//==============================================================================
// Latin American Styles

void WorldMusicDatabase::addLatinStyles()
{
    // Bossa Nova
    styleDatabase[StyleCategory::BossaNova] = {
        "Bossa Nova", StyleCategory::BossaNova, "Brazil", "1950s-Present",
        {{0, 1, 4, 0}, {0, 3, 1, 4}},  // Jazz-influenced
        {ChordGenius::Scale::Major, ChordGenius::Scale::Dorian},
        {ChordGenius::ChordQuality::Major7, ChordGenius::ChordQuality::Minor7, ChordGenius::ChordQuality::Dominant9},
        120.0f, 140.0f,
        "Samba rhythm (syncopated)", "Smooth, chromatic",
        {"Guitar", "Piano", "Bass", "Percussion", "Voice"},
        "Samba rhythm, jazz harmony, gentle feel (Jobim, Gilberto)",
        0.6f, 0.3f, 0.7f, 0.5f
    };

    // Salsa
    styleDatabase[StyleCategory::Salsa] = {
        "Salsa", StyleCategory::Salsa, "Cuba/Puerto Rico/USA", "1960s-Present",
        {{0, 4}, {0, 3, 4}},  // Simple progressions, rhythmic focus
        {ChordGenius::Scale::Major, ChordGenius::Scale::Dorian},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Dominant7},
        160.0f, 220.0f,
        "Clave rhythm (3-2 or 2-3)", "Montuno patterns",
        {"Piano", "Bass", "Congas", "Timbales", "Horns", "Voice"},
        "Clave rhythm, piano montuno, Afro-Cuban percussion",
        0.3f, 0.3f, 0.6f, 0.7f
    };

    // Tango
    styleDatabase[StyleCategory::Tango] = {
        "Tango", StyleCategory::Tango, "Argentina", "1880s-Present",
        {{0, 5, 0}, {5, 0, 5, 0}},  // i-V-i, V-i-V-i
        {ChordGenius::Scale::HarmonicMinor, ChordGenius::Scale::Phrygian},
        {ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Dominant7, ChordGenius::ChordQuality::Diminished},
        120.0f, 140.0f,
        "Syncopated, staccato", "Dramatic, chromatic",
        {"Bandoneón", "Violin", "Piano", "Bass", "Guitar"},
        "Dramatic, passionate, syncopated rhythm (Piazzolla)",
        0.6f, 0.5f, 0.8f, 0.6f
    };

    // Reggaeton
    styleDatabase[StyleCategory::Reggaeton] = {
        "Reggaeton", StyleCategory::Reggaeton, "Puerto Rico/Panama", "1990s-Present",
        {{5, 3}, {0, 5}},  // Simple progressions
        {ChordGenius::Scale::MinorPentatonic, ChordGenius::Scale::Dorian},
        {ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Major},
        85.0f, 105.0f,
        "Dembow rhythm", "Simple, repetitive",
        {"Synth", "Bass", "Drums", "Vocals"},
        "Dembow rhythm, reggae/hip-hop fusion, Latin vocals",
        0.2f, 0.2f, 0.3f, 0.6f
    };
}

//==============================================================================
// African Styles

void WorldMusicDatabase::addAfricanStyles()
{
    // Afrobeat
    styleDatabase[StyleCategory::Afrobeat] = {
        "Afrobeat", StyleCategory::Afrobeat, "Nigeria/Ghana", "1960s-Present",
        {{0}, {0, 3}},  // Repetitive vamps
        {ChordGenius::Scale::MinorPentatonic, ChordGenius::Scale::Dorian},
        {ChordGenius::ChordQuality::Minor7, ChordGenius::ChordQuality::Dominant7},
        100.0f, 130.0f,
        "Complex polyrhythms", "Repetitive riffs",
        {"Horns", "Guitar", "Bass", "Percussion", "Keyboards", "Vocals"},
        "Complex polyrhythms, funk influence, political themes (Fela Kuti)",
        0.3f, 0.3f, 0.6f, 0.8f
    };

    // Highlife
    styleDatabase[StyleCategory::Highlife] = {
        "Highlife", StyleCategory::Highlife, "Ghana", "1900s-Present",
        {{0, 3, 4}, {0, 4, 0}},  // I-IV-V, I-V-I
        {ChordGenius::Scale::MajorPentatonic, ChordGenius::Scale::Major},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Major7},
        110.0f, 140.0f,
        "Swung, jazzy", "Guitar highlife patterns",
        {"Guitar", "Horns", "Percussion", "Vocals"},
        "Guitar-based, jazz influence, dance music",
        0.3f, 0.2f, 0.5f, 0.5f
    };
}

//==============================================================================
// Asian Styles

void WorldMusicDatabase::addAsianStyles()
{
    // Indian Classical
    styleDatabase[StyleCategory::IndianClassical] = {
        "Indian Classical", StyleCategory::IndianClassical, "India", "Ancient-Present",
        {{0}, {0, 3}},  // Raga-based (not Western chord progressions)
        {ChordGenius::Scale::Major, ChordGenius::Scale::Phrygian},  // Approximations
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Minor},
        60.0f, 180.0f,
        "Complex rhythmic cycles (tala)", "Microtonal, ornamented",
        {"Sitar", "Tabla", "Tanpura", "Bansuri", "Sarod"},
        "Raga system, microtones, improvisation, rhythmic cycles",
        0.9f, 0.3f, 0.9f, 0.8f
    };

    // Gamelan (Indonesian)
    styleDatabase[StyleCategory::Gamelan] = {
        "Gamelan", StyleCategory::Gamelan, "Indonesia", "Ancient-Present",
        {{0}, {0, 4}},  // Cyclical patterns
        {ChordGenius::Scale::MajorPentatonic, ChordGenius::Scale::Major},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Power},
        100.0f, 150.0f,
        "Interlocking patterns", "Cyclical, layered",
        {"Metallophones", "Gongs", "Drums", "Flute", "Rebab"},
        "Interlocking rhythms, metallophones, cyclical structure",
        0.4f, 0.4f, 0.8f, 0.7f
    };

    // K-Pop
    styleDatabase[StyleCategory::KPop] = {
        "K-Pop", StyleCategory::KPop, "South Korea", "1990s-Present",
        {{0, 4, 5, 3}, {5, 3, 0, 4}},  // Western pop progressions
        {ChordGenius::Scale::Major, ChordGenius::Scale::MinorPentatonic},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Dominant7},
        120.0f, 140.0f,
        "EDM-influenced", "Catchy, wide range",
        {"Vocals", "Synth", "Bass", "Drums"},
        "Pop/EDM fusion, choreography-focused, catchy hooks",
        0.3f, 0.2f, 0.5f, 0.4f
    };
}

//==============================================================================
// Middle Eastern Styles

void WorldMusicDatabase::addMiddleEasternStyles()
{
    // Arabic
    styleDatabase[StyleCategory::Arabic] = {
        "Arabic", StyleCategory::Arabic, "Middle East/North Africa", "Ancient-Present",
        {{0}, {0, 4}},  // Maqam-based
        {ChordGenius::Scale::Phrygian, ChordGenius::Scale::HarmonicMinor},  // Approximation of maqam
        {ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Augmented},
        80.0f, 140.0f,
        "Complex ornamentations", "Microtonal, melismatic",
        {"Oud", "Qanun", "Ney", "Darbuka", "Vocals"},
        "Maqam system, quarter tones, improvisation (taqasim)",
        0.9f, 0.5f, 0.9f, 0.6f
    };

    // Turkish
    styleDatabase[StyleCategory::Turkish] = {
        "Turkish", StyleCategory::Turkish, "Turkey", "Ancient-Present",
        {{0}, {0, 4}},  // Makam-based
        {ChordGenius::Scale::Phrygian, ChordGenius::Scale::DoubleHarmonic},
        {ChordGenius::ChordQuality::Minor, ChordGenius::ChordQuality::Augmented},
        90.0f, 150.0f,
        "Aksak rhythms (asymmetric)", "Microtonal",
        {"Saz", "Ney", "Kanun", "Darbuka", "Kemençe"},
        "Makam system, aksak rhythms, microtones",
        0.9f, 0.5f, 0.9f, 0.7f
    };
}

//==============================================================================
// European Folk Styles

void WorldMusicDatabase::addEuropeanFolkStyles()
{
    // Celtic
    styleDatabase[StyleCategory::Celtic] = {
        "Celtic", StyleCategory::Celtic, "Ireland/Scotland", "Traditional",
        {{0, 3, 4}, {0, 4, 0}},
        {ChordGenius::Scale::Dorian, ChordGenius::Scale::Mixolydian, ChordGenius::Scale::MajorPentatonic},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Minor},
        100.0f, 180.0f,
        "Jigs/reels (6/8, 4/4)", "Ornamented, modal",
        {"Fiddle", "Tin Whistle", "Bodhrán", "Uilleann Pipes", "Harp"},
        "Modal scales, ornamentation, dance rhythms",
        0.4f, 0.3f, 0.6f, 0.5f
    };

    // Flamenco
    styleDatabase[StyleCategory::Flamenco] = {
        "Flamenco", StyleCategory::Flamenco, "Spain (Andalusia)", "Traditional",
        {{0, 6, 5, 4}, {0, 3, 6, 5}},  // Phrygian progressions
        {ChordGenius::Scale::Phrygian, ChordGenius::Scale::HarmonicMinor},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Minor},
        100.0f, 200.0f,
        "Complex, syncopated", "Melismatic, dramatic",
        {"Guitar", "Cajón", "Palmas", "Vocals"},
        "Phrygian mode, rasgueado guitar, passionate vocals",
        0.6f, 0.5f, 0.8f, 0.7f
    };

    // Reggae
    styleDatabase[StyleCategory::Reggae] = {
        "Reggae", StyleCategory::Reggae, "Jamaica", "1960s-Present",
        {{0, 3, 4}, {0, 4, 0}},
        {ChordGenius::Scale::MajorPentatonic, ChordGenius::Scale::Dorian},
        {ChordGenius::ChordQuality::Major, ChordGenius::ChordQuality::Minor7},
        60.0f, 90.0f,
        "One-drop, off-beat skank", "Simple, repetitive",
        {"Bass", "Drums", "Guitar", "Keys", "Vocals"},
        "Off-beat chords, heavy bass, one-drop rhythm (Marley)",
        0.2f, 0.2f, 0.4f, 0.6f
    };
}

//==============================================================================
// World Music Category

void WorldMusicDatabase::addWorldMusicStyles()
{
    addLatinStyles();
    addAfricanStyles();
    addAsianStyles();
    addMiddleEasternStyles();
    addEuropeanFolkStyles();
}

//==============================================================================
// Database Access

WorldMusicDatabase::MusicStyle WorldMusicDatabase::getStyle(WorldMusicDatabase::StyleCategory category)
{
    auto it = styleDatabase.find(category);
    if (it != styleDatabase.end())
        return it->second;

    return styleDatabase[StyleCategory::Pop];  // Default
}

std::vector<WorldMusicDatabase::MusicStyle> WorldMusicDatabase::getStylesByRegion(const std::string& region)
{
    std::vector<WorldMusicDatabase::MusicStyle> styles;

    for (const auto& [category, style] : styleDatabase)
    {
        if (style.region.find(region) != std::string::npos)
            styles.push_back(style);
    }

    return styles;
}

std::vector<WorldMusicDatabase::MusicStyle> WorldMusicDatabase::getStylesByPeriod(const std::string& period)
{
    std::vector<WorldMusicDatabase::MusicStyle> styles;

    for (const auto& [category, style] : styleDatabase)
    {
        if (style.period.find(period) != std::string::npos)
            styles.push_back(style);
    }

    return styles;
}

std::vector<WorldMusicDatabase::MusicStyle> WorldMusicDatabase::searchStyles(const std::string& query)
{
    std::vector<WorldMusicDatabase::MusicStyle> styles;

    std::string lowerQuery = query;
    std::transform(lowerQuery.begin(), lowerQuery.end(), lowerQuery.begin(), ::tolower);

    for (const auto& [category, style] : styleDatabase)
    {
        std::string lowerName = style.name;
        std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), ::tolower);

        if (lowerName.find(lowerQuery) != std::string::npos ||
            style.description.find(lowerQuery) != std::string::npos)
        {
            styles.push_back(style);
        }
    }

    return styles;
}

std::vector<WorldMusicDatabase::MusicStyle> WorldMusicDatabase::getAllStyles()
{
    std::vector<WorldMusicDatabase::MusicStyle> styles;

    for (const auto& [category, style] : styleDatabase)
        styles.push_back(style);

    return styles;
}

std::vector<std::string> WorldMusicDatabase::getStyleNames()
{
    std::vector<std::string> names;

    for (const auto& [category, style] : styleDatabase)
        names.push_back(style.name);

    return names;
}

WorldMusicDatabase::MusicStyle WorldMusicDatabase::getRandomStyle()
{
    if (styleDatabase.empty())
        return styleDatabase[StyleCategory::Pop];

    int randomIndex = rand() % styleDatabase.size();
    auto it = styleDatabase.begin();
    std::advance(it, randomIndex);

    return it->second;
}

//==============================================================================
// Integration with MIDI Tools

std::vector<ChordGenius::Chord> WorldMusicDatabase::getProgressionForStyle(
    WorldMusicDatabase::StyleCategory category, int key, int length)
{
    std::vector<ChordGenius::Chord> chords;
    // Implementation would use ChordGenius to generate progression based on style
    return chords;
}

ChordGenius::Scale WorldMusicDatabase::getScaleForStyle(WorldMusicDatabase::StyleCategory category)
{
    auto style = getStyle(category);

    if (!style.typicalScales.empty())
        return style.typicalScales[0];

    return ChordGenius::Scale::Major;
}

std::pair<float, float> WorldMusicDatabase::getTempoRangeForStyle(WorldMusicDatabase::StyleCategory category)
{
    auto style = getStyle(category);
    return {style.minTempo, style.maxTempo};
}
