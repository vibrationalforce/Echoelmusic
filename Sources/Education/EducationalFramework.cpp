#include "EducationalFramework.h"

//==============================================================================
// EducationalFramework Implementation
//==============================================================================

EducationalFramework::EducationalFramework()
{
    DBG("EducationalFramework initialized - Music History + Science Education");

    initializeMusicHistory();
    initializeWorldMusic();
    initializeFrequencyResearch();
    initializePsychoacoustics();
    initializeQuantumConcepts();
    initializeColorSound();
    initializeLocalization();
}

EducationalFramework::~EducationalFramework()
{
}

//==============================================================================
// Music History Initialization
//==============================================================================

void EducationalFramework::initializeMusicHistory()
{
    // Baroque Era (1600-1750)
    {
        MusicEraInfo baroque;
        baroque.era = MusicEra::Baroque;
        baroque.name = "Baroque";
        baroque.timeperiod = "1600 - 1750";
        baroque.description = "Characterized by ornate musical embellishment, contrast, and the development of tonality. "
                             "Birth of opera, concerto, and sonata forms.";

        baroque.keyComposers.add("Johann Sebastian Bach");
        baroque.keyComposers.add("George Frideric Handel");
        baroque.keyComposers.add("Antonio Vivaldi");
        baroque.keyComposers.add("Claudio Monteverdi");

        baroque.keyWorks.add("Bach: Brandenburg Concertos");
        baroque.keyWorks.add("Vivaldi: The Four Seasons");
        baroque.keyWorks.add("Handel: Messiah");

        baroque.musicalCharacteristics.add("Basso continuo (figured bass)");
        baroque.musicalCharacteristics.add("Terraced dynamics");
        baroque.musicalCharacteristics.add("Ornamentation (trills, mordents)");
        baroque.musicalCharacteristics.add("Counterpoint and fugue");

        baroque.instruments.add("Harpsichord");
        baroque.instruments.add("Baroque violin");
        baroque.instruments.add("Recorder");
        baroque.instruments.add("Lute");

        addMusicEra(baroque);
    }

    // Classical Era (1750-1820)
    {
        MusicEraInfo classical;
        classical.era = MusicEra::Classical;
        classical.name = "Classical";
        classical.timeperiod = "1750 - 1820";
        classical.description = "Emphasis on clarity, balance, and formal structure. "
                               "Development of symphony and string quartet.";

        classical.keyComposers.add("Wolfgang Amadeus Mozart");
        classical.keyComposers.add("Ludwig van Beethoven (early)");
        classical.keyComposers.add("Franz Joseph Haydn");

        classical.keyWorks.add("Mozart: Symphony No. 40");
        classical.keyWorks.add("Beethoven: Symphony No. 5");
        classical.keyWorks.add("Haydn: The Creation");

        classical.musicalCharacteristics.add("Sonata form");
        classical.musicalCharacteristics.add("Balanced phrases");
        classical.musicalCharacteristics.add("Clear melodic lines");
        classical.musicalCharacteristics.add("Gradual dynamics");

        classical.instruments.add("Fortepiano (early piano)");
        classical.instruments.add("String quartet");
        classical.instruments.add("Orchestra (standardized)");

        addMusicEra(classical);
    }

    // Electronic Era (1970s-present)
    {
        MusicEraInfo electronic;
        electronic.era = MusicEra::Electronic;
        electronic.name = "Electronic Music";
        electronic.timeperiod = "1970s - Present";
        electronic.description = "Music created using electronic instruments, synthesizers, and digital technology. "
                                "Revolutionized music production and performance.";

        electronic.keyComposers.add("Kraftwerk");
        electronic.keyComposers.add("Jean-Michel Jarre");
        electronic.keyComposers.add("Aphex Twin");
        electronic.keyComposers.add("Daft Punk");

        electronic.musicalCharacteristics.add("Synthesized sounds");
        electronic.musicalCharacteristics.add("Electronic beats");
        electronic.musicalCharacteristics.add("Sound design");
        electronic.musicalCharacteristics.add("Digital effects");

        electronic.instruments.add("Synthesizers (Moog, Prophet, etc.)");
        electronic.instruments.add("Drum machines (TR-808, TR-909)");
        electronic.instruments.add("Samplers");
        electronic.instruments.add("DAWs (Digital Audio Workstations)");

        addMusicEra(electronic);
    }

    // Hip-Hop (1970s-present)
    {
        MusicEraInfo hiphop;
        hiphop.era = MusicEra::HipHop;
        hiphop.name = "Hip-Hop";
        hiphop.timeperiod = "1970s - Present";
        hiphop.description = "Cultural movement born in the Bronx, combining rapping, DJing, breakdancing, and graffiti. "
                            "Revolutionized popular music and global culture.";

        hiphop.keyComposers.add("Grandmaster Flash");
        hiphop.keyComposers.add("Dr. Dre");
        hiphop.keyComposers.add("Metro Boomin");
        hiphop.keyComposers.add("Kanye West");

        hiphop.musicalCharacteristics.add("Sampling");
        hiphop.musicalCharacteristics.add("Breakbeats");
        hiphop.musicalCharacteristics.add("808 bass");
        hiphop.musicalCharacteristics.add("Vocal rhythm (rap)");

        hiphop.instruments.add("Turntables (DJ equipment)");
        hiphop.instruments.add("MPC (Akai samplers)");
        hiphop.instruments.add("TR-808 drum machine");

        hiphop.worldwideInfluences.add("African drumming traditions");
        hiphop.worldwideInfluences.add("Jamaican sound systems");
        hiphop.worldwideInfluences.add("Funk and soul");

        addMusicEra(hiphop);
    }
}

//==============================================================================
// Worldwide Music Initialization
//==============================================================================

void EducationalFramework::initializeWorldMusic()
{
    // West African Music
    {
        WorldMusicStyle westAfrican;
        westAfrican.culture = MusicCulture::WestAfrican;
        westAfrican.name = "West African Polyrhythm";
        westAfrican.region = "West Africa (Ghana, Senegal, Mali, Nigeria)";
        westAfrican.description = "Complex polyrhythmic traditions using djembe, talking drums, and balafon. "
                                 "Foundation of many modern musical genres.";

        westAfrican.scales.add("Pentatonic scales");
        westAfrican.scales.add("Heptatonic scales");

        westAfrican.rhythms.add("12/8 polyrhythm");
        westAfrican.rhythms.add("Clave patterns");
        westAfrican.rhythms.add("Call-and-response");

        westAfrican.instruments.add("Djembe");
        westAfrican.instruments.add("Talking drum (tama)");
        westAfrican.instruments.add("Balafon");
        westAfrican.instruments.add("Kora");

        westAfrican.culturalSignificance = "Music integral to ceremonies, storytelling, and social communication";
        westAfrican.historicalOrigin = "Ancient traditions passed down through griots (oral historians)";

        westAfrican.modernGenres.add("Afrobeat");
        westAfrican.modernGenres.add("Jazz");
        westAfrican.modernGenres.add("Hip-Hop");
        westAfrican.modernGenres.add("Latin music");

        addWorldMusicStyle(westAfrican);
    }

    // Indian Classical Music
    {
        WorldMusicStyle indian;
        indian.culture = MusicCulture::Indian_Classical;
        indian.name = "Indian Classical Music (Hindustani & Carnatic)";
        indian.region = "India, Pakistan, Bangladesh";
        indian.description = "Ancient tradition based on ragas (melodic frameworks) and talas (rhythmic cycles). "
                            "Emphasizes improvisation and spiritual expression.";

        indian.scales.add("Ragas (72 melakartas in Carnatic)");
        indian.scales.add("Microtonal variations (shruti)");

        indian.rhythms.add("Tala cycles (Teental 16 beats, etc.)");
        indian.rhythms.add("Rhythmic patterns (tihai)");

        indian.instruments.add("Sitar");
        indian.instruments.add("Tabla");
        indian.instruments.add("Sarod");
        indian.instruments.add("Tanpura");
        indian.instruments.add("Veena");

        indian.culturalSignificance = "Deep spiritual and philosophical connections, linked to yoga and meditation";
        indian.historicalOrigin = "Over 2000 years old, documented in ancient texts (Natya Shastra)";

        indian.modernGenres.add("World fusion");
        indian.modernGenres.add("Psychedelic rock");
        indian.modernGenres.add("Ambient music");

        addWorldMusicStyle(indian);
    }

    // Arabic Maqam
    {
        WorldMusicStyle arabic;
        arabic.culture = MusicCulture::Arabic_Maqam;
        arabic.name = "Arabic Maqam System";
        arabic.region = "Middle East, North Africa";
        arabic.description = "Modal system using quarter-tones and specific melodic patterns. "
                            "Rich ornamental tradition and emotional expression.";

        arabic.scales.add("Maqamat (modal scales with microtones)");
        arabic.scales.add("Bayati, Rast, Hijaz, Saba, etc.");

        arabic.rhythms.add("Iqa'at (rhythmic modes)");
        arabic.rhythms.add("Complex time signatures (10/8, 7/8, etc.)");

        arabic.instruments.add("Oud");
        arabic.instruments.add("Qanun");
        arabic.instruments.add("Ney");
        arabic.instruments.add("Riq");

        arabic.culturalSignificance = "Central to Islamic culture, Sufi traditions, and poetry";
        arabic.historicalOrigin = "Golden Age of Islam (8th-13th centuries)";

        arabic.modernGenres.add("World music fusion");
        arabic.modernGenres.add("Jazz (quarter-tone jazz)");

        addWorldMusicStyle(arabic);
    }

    // Brazilian Music
    {
        WorldMusicStyle brazilian;
        brazilian.culture = MusicCulture::Brazilian;
        brazilian.name = "Brazilian Music (Samba, Bossa Nova)";
        brazilian.region = "Brazil";
        brazilian.description = "Fusion of African, Portuguese, and Indigenous influences. "
                               "Characterized by syncopated rhythms and rich harmonies.";

        brazilian.rhythms.add("Samba rhythm");
        brazilian.rhythms.add("Bossa nova groove");
        brazilian.rhythms.add("Batucada");

        brazilian.instruments.add("Berimbau");
        brazilian.instruments.add("Pandeiro");
        brazilian.instruments.add("Cuica");
        brazilian.instruments.add("Cavaquinho");

        brazilian.culturalSignificance = "Expression of Brazilian identity, carnival culture";
        brazilian.historicalOrigin = "African slave traditions merged with Portuguese colonizers";

        brazilian.modernGenres.add("Jazz (Bossa Nova)");
        brazilian.modernGenres.add("Electronic music");
        brazilian.modernGenres.add("Tropicália");

        addWorldMusicStyle(brazilian);
    }

    // Japanese Traditional
    {
        WorldMusicStyle japanese;
        japanese.culture = MusicCulture::Japanese_Traditional;
        japanese.name = "Japanese Traditional Music (Gagaku, Min'yō)";
        japanese.region = "Japan";
        japanese.description = "Ancient court music and folk traditions. Emphasis on space, silence, and timbral exploration.";

        japanese.scales.add("Pentatonic (In, Yo scales)");
        japanese.scales.add("Ritsu, Ryo modes");

        japanese.instruments.add("Koto");
        japanese.instruments.add("Shamisen");
        japanese.instruments.add("Shakuhachi");
        japanese.instruments.add("Taiko drums");

        japanese.culturalSignificance = "Linked to Buddhism, Shinto, tea ceremony, martial arts";
        japanese.historicalOrigin = "Gagaku: 7th century, Min'yō: folk traditions";

        japanese.modernGenres.add("Ambient music");
        japanese.modernGenres.add("Experimental music");
        japanese.modernGenres.add("Video game music");

        addWorldMusicStyle(japanese);
    }
}

//==============================================================================
// Frequency Research Initialization (NO HEALTH CLAIMS!)
//==============================================================================

void EducationalFramework::initializeFrequencyResearch()
{
    // NASA Adey Windows
    {
        FrequencyResearch adey;
        adey.name = "Adey Windows";
        adey.frequencyHz = 10.0f;  // ELF range 6-16 Hz
        adey.category = FrequencyResearch::Category::NASA_Research;

        adey.scientificDescription =
            "Dr. W. Ross Adey (NASA, 1970s-1980s) discovered specific frequency windows (6-16 Hz) "
            "that showed measurable effects on calcium ion flux in cell membranes during in-vitro experiments.";

        adey.observableEffects =
            "Documented: Measurable changes in calcium ion transport across cell membranes in laboratory conditions. "
            "Measured using scientific instruments in controlled settings.";

        adey.measurementMethods =
            "In-vitro cell culture experiments, calcium ion flux measurement, electromagnetic field exposure protocols.";

        adey.disclaimer =
            "⚠️ EDUCATIONAL ONLY - NO HEALTH CLAIMS!\n"
            "This research documents observable phenomena in laboratory settings. "
            "This information is for educational purposes only and does not constitute medical advice or health claims.";

        ScientificReference ref1;
        ref1.topic = "Adey Windows";
        ref1.title = "Tissue interactions with nonionizing electromagnetic fields";
        ref1.authors = "Adey, W.R.";
        ref1.publication = "Physiological Reviews";
        ref1.year = 1981;
        ref1.evidenceLevel = ScientificReference::EvidenceLevel::PeerReviewed;
        ref1.keyFindings = "Specific frequency windows show amplitude-dependent effects on calcium efflux";

        adey.references.add(ref1);

        addFrequencyResearch(adey);
    }

    // Schumann Resonance
    {
        FrequencyResearch schumann;
        schumann.name = "Schumann Resonance";
        schumann.frequencyHz = 7.83f;
        schumann.category = FrequencyResearch::Category::Geophysical;

        schumann.scientificDescription =
            "Electromagnetic resonances in Earth-ionosphere cavity, first predicted by Schumann (1952). "
            "Fundamental frequency approximately 7.83 Hz, with harmonics at ~14, 20, 26, 33 Hz.";

        schumann.observableEffects =
            "Physically measurable electromagnetic phenomena. Can be detected worldwide using sensitive electromagnetic sensors. "
            "Well-documented in geophysical research.";

        schumann.measurementMethods =
            "ELF (Extremely Low Frequency) receivers, magnetometers, global monitoring stations.";

        schumann.disclaimer =
            "⚠️ SCIENTIFIC PHENOMENON - NO HEALTH CLAIMS!\n"
            "Schumann Resonance is a measurable geophysical phenomenon. "
            "Educational information only.";

        ScientificReference ref1;
        ref1.topic = "Schumann Resonance";
        ref1.title = "On the free oscillations of a conducting sphere";
        ref1.authors = "Schumann, W.O.";
        ref1.publication = "Zeitschrift für Naturforschung A";
        ref1.year = 1952;
        ref1.evidenceLevel = ScientificReference::EvidenceLevel::PeerReviewed;

        schumann.references.add(ref1);

        addFrequencyResearch(schumann);
    }

    // 432 Hz (Historical tuning)
    {
        FrequencyResearch hz432;
        hz432.name = "432 Hz Tuning";
        hz432.frequencyHz = 432.0f;
        hz432.category = FrequencyResearch::Category::Musical;

        hz432.scientificDescription =
            "Alternative concert pitch where A4 = 432 Hz (vs standard A440 Hz). "
            "Historical tuning used in some periods, mathematical relationships to nature sometimes cited.";

        hz432.observableEffects =
            "Documented: Slight difference in timbre and feel compared to A440. "
            "Some musicians report subjective preference. No scientifically proven universal benefits.";

        hz432.disclaimer =
            "⚠️ MUSICAL PREFERENCE - NOT SCIENTIFIC FACT!\n"
            "432 Hz is a tuning choice. Many claims about '432 Hz healing' lack scientific evidence. "
            "Use what sounds good to you!";

        addFrequencyResearch(hz432);
    }
}

//==============================================================================
// Psychoacoustics Initialization
//==============================================================================

void EducationalFramework::initializePsychoacoustics()
{
    // Fletcher-Munson Curves
    {
        PsychoAcousticInfo fletcher;
        fletcher.name = "Fletcher-Munson Equal-Loudness Contours";
        fletcher.description =
            "Human hearing is not equally sensitive to all frequencies. "
            "We hear midrange (1-5 kHz) better than bass or treble at low volumes.";

        fletcher.scientificBasis =
            "Experimental measurements of perceived loudness vs frequency at different SPLs (Sound Pressure Levels). "
            "Standardized as ISO 226:2003.";

        fletcher.frequencyRangeStart = 20.0f;
        fletcher.frequencyRangeEnd = 20000.0f;

        fletcher.musicalApplication =
            "Explains why music sounds 'thin' at low volume. "
            "Loudness buttons on old stereos boosted bass/treble. "
            "Critical for mixing and mastering.";

        ScientificReference ref;
        ref.topic = "Equal-loudness contours";
        ref.title = "Loudness, its definition, measurement and calculation";
        ref.authors = "Fletcher, H. & Munson, W.A.";
        ref.publication = "Journal of the Acoustical Society of America";
        ref.year = 1933;
        ref.evidenceLevel = ScientificReference::EvidenceLevel::Replicated;

        fletcher.references.add(ref);

        psychoacousticDatabase["Fletcher-Munson"] = fletcher;
    }

    // Critical Bands
    {
        PsychoAcousticInfo critical;
        critical.name = "Critical Bands (Bark Scale)";
        critical.description =
            "Human hearing organizes frequencies into approximately 24 critical bands. "
            "Frequencies within the same band can mask each other.";

        critical.scientificBasis =
            "Psychoacoustic research by Zwicker, Fastl, and others. "
            "Relates to basilar membrane mechanics in cochlea.";

        critical.musicalApplication =
            "Explains frequency masking in mixing. "
            "Why certain EQ choices work better. "
            "Foundation of perceptual audio coding (MP3, AAC).";

        psychoacousticDatabase["Critical Bands"] = critical;
    }
}

//==============================================================================
// Quantum Concepts Initialization (Educational Analogies!)
//==============================================================================

void EducationalFramework::initializeQuantumConcepts()
{
    // Superposition Analogy
    {
        QuantumAudioConcept superposition;
        superposition.name = "Superposition Analogy";
        superposition.quantumPhysicsPrinciple =
            "Quantum superposition: A particle can exist in multiple states simultaneously until measured.";

        superposition.audioAnalogy =
            "Multiple audio waveforms can exist in the same space (additive synthesis). "
            "When you play two notes together, both frequencies exist simultaneously.";

        superposition.educationalDisclaimer =
            "⚠️ EDUCATIONAL ANALOGY ONLY!\n"
            "This is NOT real quantum physics in audio. It's a teaching analogy to understand wave behavior.";

        superposition.practicalExample =
            "Chord = superposition of multiple frequencies. "
            "Fourier transform shows all frequency components simultaneously present.";

        addQuantumConcept(superposition);
    }

    // Entanglement Analogy
    {
        QuantumAudioConcept entanglement;
        entanglement.name = "Entanglement Analogy";
        entanglement.quantumPhysicsPrinciple =
            "Quantum entanglement: Two particles can be correlated such that measuring one affects the other.";

        entanglement.audioAnalogy =
            "Phase-locked signals: Two oscillators synchronized so changing one affects the other. "
            "Sidechain compression: One signal controls processing of another.";

        entanglement.educationalDisclaimer =
            "⚠️ EDUCATIONAL ANALOGY ONLY!\n"
            "Not real quantum entanglement - just correlated audio signals!";

        entanglement.practicalExample =
            "Sidechain compression on bass triggered by kick drum. "
            "FM synthesis: modulator frequency affects carrier.";

        addQuantumConcept(entanglement);
    }

    // Wave-Particle Duality Analogy
    {
        QuantumAudioConcept duality;
        duality.name = "Wave-Particle Duality Analogy";
        duality.quantumPhysicsPrinciple =
            "Light/matter exhibits both wave and particle properties.";

        duality.audioAnalogy =
            "Audio can be viewed as continuous waveform (wave) or discrete samples (particle-like). "
            "Time domain vs frequency domain (Fourier duality).";

        duality.educationalDisclaimer =
            "⚠️ EDUCATIONAL ANALOGY!\n"
            "Digital audio sampling is NOT quantum mechanics, just a useful comparison.";

        duality.practicalExample =
            "44.1 kHz sampling: Continuous sound represented as discrete samples.";

        addQuantumConcept(duality);
    }
}

//==============================================================================
// Color-Sound Theory Initialization
//==============================================================================

void EducationalFramework::initializeColorSound()
{
    // Scriabin's Color Organ
    {
        ColorSoundTheory scriabin;
        scriabin.theorist = "Alexander Scriabin";
        scriabin.theory = "Clavier à lumières (Color Organ)";
        scriabin.year = 1911;

        ColorSoundTheory::ColorFrequencyMapping cMapping;

        cMapping.color = juce::Colour(255, 0, 0);  // Red
        cMapping.note = "C";
        cMapping.description = "C = Red";
        scriabin.mappings.add(cMapping);

        cMapping.color = juce::Colour(255, 165, 0);  // Orange
        cMapping.note = "D";
        cMapping.description = "D = Orange";
        scriabin.mappings.add(cMapping);

        cMapping.color = juce::Colour(255, 255, 0);  // Yellow
        cMapping.note = "E";
        cMapping.description = "E = Yellow";
        scriabin.mappings.add(cMapping);

        cMapping.color = juce::Colour(0, 128, 0);  // Green
        cMapping.note = "F#";
        cMapping.description = "F# = Green";
        scriabin.mappings.add(cMapping);

        cMapping.color = juce::Colour(0, 0, 255);  // Blue
        cMapping.note = "A";
        cMapping.description = "A = Blue";
        scriabin.mappings.add(cMapping);

        scriabin.culturalContext = "Early 20th century synesthesia exploration";
        scriabin.modernApplication = "Visual music, VJ performances, multimedia art";

        addColorSoundTheory(scriabin);
    }

    // Kandinsky
    {
        ColorSoundTheory kandinsky;
        kandinsky.theorist = "Wassily Kandinsky";
        kandinsky.theory = "Color-Sound Synesthesia Theory";
        kandinsky.year = 1912;

        kandinsky.culturalContext =
            "Abstract art pioneer who experienced synesthesia. "
            "Associated specific instruments with colors and shapes.";

        kandinsky.modernApplication =
            "Foundation for abstract visual music, generative art";

        addColorSoundTheory(kandinsky);
    }
}

//==============================================================================
// Localization Initialization
//==============================================================================

void EducationalFramework::initializeLocalization()
{
    // English
    localizationStrings["welcome"][Language::English] = "Welcome to Echoelmusic Educational Framework";
    localizationStrings["music_history"][Language::English] = "Music History";
    localizationStrings["world_music"][Language::English] = "World Music";
    localizationStrings["science"][Language::English] = "Scientific Research";

    // German
    localizationStrings["welcome"][Language::German] = "Willkommen zum Echoelmusic Bildungs-Framework";
    localizationStrings["music_history"][Language::German] = "Musikgeschichte";
    localizationStrings["world_music"][Language::German] = "Weltmusik";
    localizationStrings["science"][Language::German] = "Wissenschaftliche Forschung";

    // Spanish
    localizationStrings["welcome"][Language::Spanish] = "Bienvenido al Marco Educativo Echoelmusic";
    localizationStrings["music_history"][Language::Spanish] = "Historia de la Música";

    // More languages can be added...
}

//==============================================================================
// Music History Methods
//==============================================================================

MusicEraInfo EducationalFramework::getMusicEra(MusicEra era) const
{
    auto it = musicErasDatabase.find(era);
    if (it != musicErasDatabase.end())
        return it->second;

    return MusicEraInfo();
}

juce::Array<MusicEraInfo> EducationalFramework::getAllMusicEras() const
{
    juce::Array<MusicEraInfo> eras;

    for (const auto& pair : musicErasDatabase)
        eras.add(pair.second);

    return eras;
}

juce::Array<MusicEraInfo> EducationalFramework::searchMusicHistory(const juce::String& query) const
{
    juce::Array<MusicEraInfo> results;

    for (const auto& pair : musicErasDatabase)
    {
        if (pair.second.name.containsIgnoreCase(query) ||
            pair.second.description.containsIgnoreCase(query))
        {
            results.add(pair.second);
        }
    }

    return results;
}

//==============================================================================
// World Music Methods
//==============================================================================

WorldMusicStyle EducationalFramework::getWorldMusicStyle(MusicCulture culture) const
{
    auto it = worldMusicDatabase.find(culture);
    if (it != worldMusicDatabase.end())
        return it->second;

    return WorldMusicStyle();
}

juce::Array<WorldMusicStyle> EducationalFramework::getAllWorldMusicStyles() const
{
    juce::Array<WorldMusicStyle> styles;

    for (const auto& pair : worldMusicDatabase)
        styles.add(pair.second);

    return styles;
}

juce::Array<WorldMusicStyle> EducationalFramework::getStylesByRegion(const juce::String& region) const
{
    juce::Array<WorldMusicStyle> results;

    for (const auto& pair : worldMusicDatabase)
    {
        if (pair.second.region.containsIgnoreCase(region))
            results.add(pair.second);
    }

    return results;
}

juce::String EducationalFramework::getCulturalContext(const juce::String& styleName) const
{
    for (const auto& pair : worldMusicDatabase)
    {
        if (pair.second.name.equalsIgnoreCase(styleName))
            return pair.second.culturalSignificance;
    }

    return "Cultural context not found.";
}

//==============================================================================
// Scientific Research Methods
//==============================================================================

FrequencyResearch EducationalFramework::getFrequencyResearch(const juce::String& name) const
{
    auto it = frequencyResearchDatabase.find(name);
    if (it != frequencyResearchDatabase.end())
        return it->second;

    return FrequencyResearch();
}

juce::Array<FrequencyResearch> EducationalFramework::getAllFrequencyResearch() const
{
    juce::Array<FrequencyResearch> research;

    for (const auto& pair : frequencyResearchDatabase)
        research.add(pair.second);

    return research;
}

juce::Array<ScientificReference> EducationalFramework::getPeerReviewedReferences(const juce::String& topic) const
{
    juce::Array<ScientificReference> refs;

    for (const auto& pair : frequencyResearchDatabase)
    {
        if (pair.second.name.containsIgnoreCase(topic))
        {
            for (const auto& ref : pair.second.references)
            {
                if (ref.isPeerReviewed())
                    refs.add(ref);
            }
        }
    }

    return refs;
}

juce::Array<FrequencyResearch> EducationalFramework::getNASAResearch() const
{
    juce::Array<FrequencyResearch> nasa;

    for (const auto& pair : frequencyResearchDatabase)
    {
        if (pair.second.category == FrequencyResearch::Category::NASA_Research)
            nasa.add(pair.second);
    }

    return nasa;
}

FrequencyResearch EducationalFramework::getSchumannResonance() const
{
    return getFrequencyResearch("Schumann Resonance");
}

//==============================================================================
// Psychoacoustics Methods
//==============================================================================

PsychoAcousticInfo EducationalFramework::getPsychoAcousticInfo(const juce::String& phenomenon) const
{
    auto it = psychoacousticDatabase.find(phenomenon);
    if (it != psychoacousticDatabase.end())
        return it->second;

    return PsychoAcousticInfo();
}

PsychoAcousticInfo EducationalFramework::getFletcherMunsonCurves() const
{
    return getPsychoAcousticInfo("Fletcher-Munson");
}

PsychoAcousticInfo EducationalFramework::getCriticalBands() const
{
    return getPsychoAcousticInfo("Critical Bands");
}

//==============================================================================
// Quantum Concepts Methods
//==============================================================================

QuantumAudioConcept EducationalFramework::getQuantumConcept(const juce::String& name) const
{
    auto it = quantumConceptsDatabase.find(name);
    if (it != quantumConceptsDatabase.end())
        return it->second;

    return QuantumAudioConcept();
}

juce::Array<QuantumAudioConcept> EducationalFramework::getAllQuantumConcepts() const
{
    juce::Array<QuantumAudioConcept> concepts;

    for (const auto& pair : quantumConceptsDatabase)
        concepts.add(pair.second);

    return concepts;
}

//==============================================================================
// Color-Sound Theory Methods
//==============================================================================

ColorSoundTheory EducationalFramework::getColorSoundTheory(const juce::String& theorist) const
{
    auto it = colorSoundDatabase.find(theorist);
    if (it != colorSoundDatabase.end())
        return it->second;

    return ColorSoundTheory();
}

juce::Array<ColorSoundTheory> EducationalFramework::getAllColorSoundTheories() const
{
    juce::Array<ColorSoundTheory> theories;

    for (const auto& pair : colorSoundDatabase)
        theories.add(pair.second);

    return theories;
}

//==============================================================================
// Educational Content Methods
//==============================================================================

juce::String EducationalFramework::getEducationalArticle(const juce::String& topic) const
{
    juce::String article;
    article << "=== " << topic << " ===\n\n";

    // Search all databases
    auto musicResults = searchMusicHistory(topic);
    if (musicResults.size() > 0)
        article << musicResults[0].description << "\n\n";

    return article;
}

juce::StringArray EducationalFramework::getLearningPath(const juce::String& topic) const
{
    juce::StringArray path;

    if (topic.containsIgnoreCase("music history"))
    {
        path.add("1. Ancient Music");
        path.add("2. Medieval Music");
        path.add("3. Renaissance Music");
        path.add("4. Baroque Music");
        path.add("5. Classical Period");
        path.add("6. Romantic Era");
        path.add("7. 20th Century");
        path.add("8. Contemporary Music");
    }

    return path;
}

juce::StringArray EducationalFramework::getQuizQuestions(const juce::String& topic) const
{
    juce::StringArray questions;

    if (topic.containsIgnoreCase("baroque"))
    {
        questions.add("Who composed the Brandenburg Concertos?");
        questions.add("What years define the Baroque period?");
        questions.add("What is basso continuo?");
    }

    return questions;
}

//==============================================================================
// Language Support Methods
//==============================================================================

void EducationalFramework::setLanguage(Language language)
{
    currentLanguage = language;
    DBG("Language set to: " + juce::String((int)language));
}

Language EducationalFramework::getCurrentLanguage() const
{
    return currentLanguage;
}

juce::String EducationalFramework::getLocalizedString(const juce::String& key) const
{
    auto keyIt = localizationStrings.find(key);
    if (keyIt != localizationStrings.end())
    {
        auto langIt = keyIt->second.find(currentLanguage);
        if (langIt != keyIt->second.end())
            return langIt->second;
    }

    return key;  // Return key if not found
}

juce::Array<Language> EducationalFramework::getAvailableLanguages() const
{
    juce::Array<Language> languages;
    languages.add(Language::English);
    languages.add(Language::German);
    languages.add(Language::Spanish);
    // Add more as implemented...

    return languages;
}

//==============================================================================
// Search & Discovery Methods
//==============================================================================

juce::StringArray EducationalFramework::searchAllContent(const juce::String& query) const
{
    juce::StringArray results;

    // Search music history
    for (const auto& pair : musicErasDatabase)
    {
        if (pair.second.name.containsIgnoreCase(query))
            results.add("Music Era: " + pair.second.name);
    }

    // Search world music
    for (const auto& pair : worldMusicDatabase)
    {
        if (pair.second.name.containsIgnoreCase(query))
            results.add("World Music: " + pair.second.name);
    }

    // Search frequency research
    for (const auto& pair : frequencyResearchDatabase)
    {
        if (pair.second.name.containsIgnoreCase(query))
            results.add("Research: " + pair.second.name);
    }

    return results;
}

juce::StringArray EducationalFramework::getRelatedTopics(const juce::String& topic) const
{
    juce::StringArray related;

    if (topic.containsIgnoreCase("Baroque"))
    {
        related.add("Classical Era");
        related.add("Counterpoint");
        related.add("Figured Bass");
    }

    return related;
}

juce::StringArray EducationalFramework::getRecommendedLearning(const juce::String& userLevel) const
{
    juce::StringArray recommendations;

    if (userLevel == "beginner")
    {
        recommendations.add("Music History Basics");
        recommendations.add("Understanding Frequency");
        recommendations.add("World Music Introduction");
    }

    return recommendations;
}

//==============================================================================
// Disclaimer Methods
//==============================================================================

juce::String EducationalFramework::getHealthDisclaimer() const
{
    return "⚠️ NO HEALTH CLAIMS!\n\n"
           "Echoelmusic provides educational information about documented scientific research. "
           "This information is NOT medical advice and makes NO health claims. "
           "Frequency research is presented for educational purposes only. "
           "Consult qualified medical professionals for health concerns.";
}

juce::String EducationalFramework::getScientificDisclaimer() const
{
    return "Scientific information presented is based on peer-reviewed research where available. "
           "We strive for accuracy but science evolves. "
           "References provided for verification.";
}

juce::String EducationalFramework::getEducationalDisclaimer() const
{
    return "Educational content for learning purposes. "
           "Always verify information and consult primary sources.";
}

//==============================================================================
// Helper Methods
//==============================================================================

void EducationalFramework::addMusicEra(const MusicEraInfo& info)
{
    musicErasDatabase[info.era] = info;
}

void EducationalFramework::addWorldMusicStyle(const WorldMusicStyle& style)
{
    worldMusicDatabase[style.culture] = style;
}

void EducationalFramework::addFrequencyResearch(const FrequencyResearch& research)
{
    frequencyResearchDatabase[research.name] = research;
}

void EducationalFramework::addPsychoAcoustic(const PsychoAcousticInfo& info)
{
    psychoacousticDatabase[info.name] = info;
}

void EducationalFramework::addQuantumConcept(const QuantumAudioConcept& concept)
{
    quantumConceptsDatabase[concept.name] = concept;
}

void EducationalFramework::addColorSoundTheory(const ColorSoundTheory& theory)
{
    colorSoundDatabase[theory.theorist] = theory;
}
