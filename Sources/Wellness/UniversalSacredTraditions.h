#pragma once

#include <JuceHeader.h>
#include <map>
#include <vector>

namespace Echoel {
namespace Unity {

//==============================================================================
/**
 * @brief Universal Sacred Traditions Integration
 *
 * "In der Stille zwischen den Tönen finden sich alle Traditionen"
 *
 * PHILOSOPHIE:
 * Nicht aneignen, sondern ehren.
 * Nicht vereinheitlichen, sondern verbinden.
 * Die universellen Elemente finden, die alle Traditionen teilen:
 *
 * 🌬️ ATEM - In jeder Tradition heilig
 * 🥁 RHYTHMUS - Der Herzschlag der Erde
 * 🎵 VIBRATION - Alles ist Schwingung
 * 🤝 GEMEINSCHAFT - Zusammen sind wir mehr
 * 🌀 BEWUSSTSEIN - Die Reise nach innen
 * 💚 HEILUNG - Ganz werden
 *
 * RESPEKT-PRINZIPIEN:
 * 1. Jede Tradition hat ihren eigenen Wert
 * 2. Wir nehmen nicht, wir lernen
 * 3. Kontext und Bedeutung werden bewahrt
 * 4. Praktiken werden nicht vermischt ohne Verständnis
 * 5. Der User wählt bewusst, was resoniert
 */

//==============================================================================
/**
 * @brief Sacred Frequency Systems
 *
 * Frequenzen, die in verschiedenen Traditionen als heilig gelten
 */
struct SacredFrequencies
{
    // Grundstimmungen
    static constexpr float CONCERT_A_432 = 432.0f;   // "Verdi-Stimmung", Naturharmonie
    static constexpr float CONCERT_A_440 = 440.0f;   // Moderne Standardstimmung
    static constexpr float CONCERT_A_444 = 444.0f;   // "Heilende" Stimmung (C=528Hz)

    // Solfeggio-Frequenzen (Gregorianische Tradition)
    struct Solfeggio
    {
        static constexpr float UT_Liberation = 396.0f;    // Befreiung von Schuld & Angst
        static constexpr float RE_Transformation = 417.0f; // Veränderung ermöglichen
        static constexpr float MI_Miracles = 528.0f;       // Transformation & DNA-Reparatur
        static constexpr float FA_Connection = 639.0f;     // Verbindung & Beziehungen
        static constexpr float SOL_Expression = 741.0f;    // Ausdruck & Lösungen
        static constexpr float LA_Intuition = 852.0f;      // Intuition & spirituelle Ordnung

        // Erweiterte Solfeggio
        static constexpr float Grounding = 174.0f;        // Erdung
        static constexpr float Safety = 285.0f;           // Sicherheit
        static constexpr float Unity = 963.0f;            // Einheit / Krone
    };

    // Om / Aum Frequenz (Vedische Tradition)
    static constexpr float OM_FUNDAMENTAL = 136.1f;   // "Om" - Erdschwingung

    // Schumann-Resonanz (Erd-Frequenz)
    static constexpr float SCHUMANN_PRIMARY = 7.83f;  // Erd-Herzschlag
    static constexpr float SCHUMANN_2ND = 14.3f;
    static constexpr float SCHUMANN_3RD = 20.8f;

    // Planetarische Frequenzen (nach Hans Cousto)
    struct Planetary
    {
        static constexpr float EARTH_DAY = 194.18f;       // Erdtag
        static constexpr float EARTH_YEAR = 136.10f;      // Erdjahr (= Om)
        static constexpr float MOON_SYNODIC = 210.42f;    // Mondmonat
        static constexpr float SUN = 126.22f;             // Sonne
    };
};

//==============================================================================
/**
 * @brief Sacred Rhythm Patterns
 *
 * Rhythmen aus verschiedenen Traditionen
 */
struct SacredRhythms
{
    struct Pattern
    {
        juce::String name;
        juce::String tradition;
        juce::String meaning;
        std::vector<float> beats;  // Relative Positionen im Zyklus (0-1)
        float cycleLength;         // In Sekunden
        bool requiresPermission;   // Manche Rhythmen sind geschützt
    };

    // Universelle Rhythmen (nicht kulturspezifisch geschützt)
    static Pattern getHeartbeat()
    {
        return {
            "Herzschlag",
            "Universal",
            "Der erste Rhythmus, den wir hören - im Mutterleib",
            { 0.0f, 0.3f },  // lub-dub
            0.8f,            // ~75 BPM
            false
        };
    }

    static Pattern getBreathCycle()
    {
        return {
            "Atem-Zyklus",
            "Universal",
            "Einatmen, Pause, Ausatmen, Pause - der Rhythmus des Lebens",
            { 0.0f, 0.25f, 0.5f, 0.75f },
            4.0f,  // 4 Sekunden pro Zyklus
            false
        };
    }

    static Pattern getWalking()
    {
        return {
            "Gehender Rhythmus",
            "Universal",
            "Der natürliche Rhythmus des menschlichen Gangs",
            { 0.0f, 0.5f },
            1.0f,  // 120 BPM
            false
        };
    }

    // Afrikanische Tradition (mit Respekt)
    static Pattern getAfricanPolyrhythm()
    {
        return {
            "3 gegen 2",
            "Westafrikanisch",
            "Die Grundlage vieler afrikanischer Rhythmen - symbolisiert die Dualität des Lebens",
            { 0.0f, 0.333f, 0.5f, 0.666f, 1.0f },
            2.0f,
            false  // Grundmuster ist universal
        };
    }

    // Indische Tradition
    static Pattern getTintal()
    {
        return {
            "Tintal",
            "Nordindisch",
            "16-Beat-Zyklus - der häufigste Tala in der Hindustani-Musik",
            { 0.0f, 0.25f, 0.5f, 0.75f },  // Sam, Khali, etc.
            16.0f,
            false
        };
    }

    // Sufi-Tradition
    static Pattern getSufiWhirl()
    {
        return {
            "Drehender Derwisch",
            "Sufi / Mevlevi",
            "Der Rhythmus der Drehung - Verbindung zwischen Erde und Himmel",
            { 0.0f, 0.333f, 0.666f },  // 3er-Rhythmus der Drehung
            3.0f,
            true  // Respekt für die Zeremonie
        };
    }

    // Schamanische Tradition
    static Pattern getShamanicDrum()
    {
        return {
            "Schamanische Trommel",
            "Verschiedene indigene Traditionen",
            "4-5 Hz Rhythmus - Theta-Gehirnwellen-Induktion",
            { 0.0f },  // Gleichmäßiger Schlag
            0.22f,     // ~4.5 Hz
            true       // Respekt für zeremonielle Nutzung
        };
    }
};

//==============================================================================
/**
 * @brief Sacred Breath Patterns
 *
 * Atemtechniken aus verschiedenen Traditionen
 */
struct SacredBreath
{
    struct BreathPattern
    {
        juce::String name;
        juce::String tradition;
        juce::String purpose;
        float inhaleSeconds;
        float holdInSeconds;
        float exhaleSeconds;
        float holdOutSeconds;
        int recommendedCycles;
    };

    // Yogische Atmung
    static BreathPattern getPranayamaBasic()
    {
        return {
            "Pranayama (Basis)",
            "Yoga / Vedisch",
            "Energie (Prana) kultivieren, Geist beruhigen",
            4.0f, 4.0f, 4.0f, 4.0f,  // Box-Atmung
            10
        };
    }

    static BreathPattern getUjjayi()
    {
        return {
            "Ujjayi",
            "Yoga",
            "Ozean-Atmung - wärmend, fokussierend",
            5.0f, 0.0f, 5.0f, 0.0f,
            20
        };
    }

    // Taoistische Atmung
    static BreathPattern getTaoistBreath()
    {
        return {
            "Bauchatmung",
            "Taoistisch / Qigong",
            "Chi kultivieren, Unteres Dantian füllen",
            6.0f, 2.0f, 8.0f, 2.0f,
            12
        };
    }

    // Christliche/Hesychastische Atmung
    static BreathPattern getHesychast()
    {
        return {
            "Herzensgebet-Atmung",
            "Östlich-Orthodox",
            "Gebet mit dem Atem verbinden",
            4.0f, 0.0f, 6.0f, 2.0f,  // Einatmen: erste Hälfte, Ausatmen: zweite Hälfte
            33  // Traditionelle Anzahl
        };
    }

    // Buddhistische Atmung
    static BreathPattern getAnapanasati()
    {
        return {
            "Anapanasati",
            "Buddhistisch",
            "Achtsamkeit auf den Atem - der Weg zur Einsicht",
            0.0f, 0.0f, 0.0f, 0.0f,  // Natürlicher Atem, nicht gesteuert
            0  // Unbegrenzt
        };
    }

    // Wim Hof (Modern)
    static BreathPattern getWimHof()
    {
        return {
            "Wim Hof Methode",
            "Modern / Niederländisch",
            "Energie, Immunsystem, Kälteresistenz",
            2.0f, 0.0f, 1.0f, 0.0f,  // Schnelle Atmung
            30  // Dann Retention
        };
    }

    // 4-7-8 (Modern/Ayurvedisch)
    static BreathPattern get478()
    {
        return {
            "4-7-8 Entspannung",
            "Modern (Dr. Weil) / Ayurvedisch",
            "Tiefe Entspannung, Schlafvorbereitung",
            4.0f, 7.0f, 8.0f, 0.0f,
            4
        };
    }
};

//==============================================================================
/**
 * @brief Universal Wisdom Themes
 *
 * Gemeinsame Weisheiten, die in allen Traditionen vorkommen
 */
struct UniversalWisdom
{
    struct Theme
    {
        juce::String concept;
        std::map<juce::String, juce::String> traditions;  // Tradition -> Ausdruck
    };

    static Theme getGoldenRule()
    {
        Theme t;
        t.concept = "Die Goldene Regel - Behandle andere, wie du behandelt werden möchtest";
        t.traditions = {
            { "Christentum", "Was ihr wollt, dass euch die Leute tun, das tut ihnen auch." },
            { "Judentum", "Was dir verhasst ist, das tue deinem Nächsten nicht an." },
            { "Islam", "Keiner von euch ist gläubig, bis er für seinen Bruder wünscht, was er für sich selbst wünscht." },
            { "Hinduismus", "Dies ist die Summe aller Pflicht: Tue nichts anderen an, was dir Schmerz bereiten würde." },
            { "Buddhismus", "Verletze nicht andere mit dem, was dich selbst verletzt." },
            { "Konfuzianismus", "Tu anderen nicht an, was du nicht willst, dass sie dir antun." },
            { "Taoismus", "Betrachte den Gewinn deines Nachbarn als deinen eigenen Gewinn." },
            { "Zoroastrismus", "Die Natur allein ist gut, die niemandem etwas antut." },
            { "Ubuntu", "Ich bin, weil wir sind." }
        };
        return t;
    }

    static Theme getOneness()
    {
        Theme t;
        t.concept = "Einheit - Alles ist verbunden";
        t.traditions = {
            { "Vedanta", "Tat Tvam Asi - Du bist Das" },
            { "Sufismus", "Ana al-Haqq - Ich bin die Wahrheit" },
            { "Buddhismus", "Interbeing - Wir inter-sind" },
            { "Christliche Mystik", "Gott ist in allem und alles ist in Gott" },
            { "Taoismus", "Das Tao, das gesprochen werden kann, ist nicht das ewige Tao" },
            { "Indigene Weisheit", "Mitakuye Oyasin - Wir sind alle verwandt" },
            { "Kabbala", "Ein Sof - Das Unendliche" },
            { "Wissenschaft", "Wir sind Sternenstaub - alles kommt aus derselben Quelle" }
        };
        return t;
    }

    static Theme getInnerJourney()
    {
        Theme t;
        t.concept = "Die Reise nach Innen - Das Königreich ist in dir";
        t.traditions = {
            { "Christentum", "Das Reich Gottes ist in euch." },
            { "Sufismus", "Wer sich selbst kennt, kennt seinen Herrn." },
            { "Hinduismus", "Atman ist Brahman - das Selbst ist das Absolute." },
            { "Buddhismus", "Sei dir selbst eine Insel, sei dir selbst ein Licht." },
            { "Taoismus", "Der Weise sucht in sich selbst." },
            { "Griechisch", "Gnothi Seauton - Erkenne dich selbst." },
            { "Ägyptisch", "Der Mensch, erkenne dich selbst." }
        };
        return t;
    }

    static Theme getImpermanence()
    {
        Theme t;
        t.concept = "Vergänglichkeit - Alles fließt, nichts bleibt";
        t.traditions = {
            { "Buddhismus", "Anicca - Nichts ist beständig" },
            { "Heraklit", "Panta Rhei - Alles fließt" },
            { "Christentum", "Alles hat seine Zeit" },
            { "Sufismus", "Diese Welt ist eine Brücke. Überquere sie, aber baue kein Haus darauf." },
            { "Stoizismus", "Memento Mori - Gedenke der Sterblichkeit" },
            { "Japanisch", "Mono no Aware - Das Pathos der Dinge" },
            { "Indigene Weisheit", "Wie der Fluss zum Meer, so fließt alles zurück." }
        };
        return t;
    }
};

//==============================================================================
/**
 * @brief Unity Sound Generator
 *
 * Generiert Klänge basierend auf universellen Prinzipien
 */
class UnitySoundGenerator
{
public:
    void setBaseFrequency(float freq)
    {
        baseFreq = freq;
    }

    void setTuningSystem(float concertA)
    {
        tuningA = concertA;
    }

    // Generiert harmonische Serie (in allen Traditionen fundamental)
    std::vector<float> getHarmonicSeries(int numHarmonics) const
    {
        std::vector<float> harmonics;
        for (int i = 1; i <= numHarmonics; ++i)
        {
            harmonics.push_back(baseFreq * i);
        }
        return harmonics;
    }

    // Generiert Oktaven (universal)
    std::vector<float> getOctaves(int numOctaves) const
    {
        std::vector<float> octaves;
        float freq = baseFreq;
        for (int i = 0; i < numOctaves; ++i)
        {
            octaves.push_back(freq);
            freq *= 2.0f;
        }
        return octaves;
    }

    // Generiert Quinten-Zyklus (Grundlage vieler Musiksysteme)
    std::vector<float> getCircleOfFifths() const
    {
        std::vector<float> fifths;
        float freq = baseFreq;
        for (int i = 0; i < 12; ++i)
        {
            fifths.push_back(freq);
            freq *= 1.5f;  // Reine Quinte
            if (freq > baseFreq * 2.0f)
                freq /= 2.0f;
        }
        return fifths;
    }

private:
    float baseFreq = 256.0f;  // C4 in 432Hz-Stimmung
    float tuningA = 432.0f;
};

//==============================================================================
/**
 * @brief Sacred Space Creator
 *
 * Schafft einen "heiligen Raum" für die Praxis - unabhängig von der Tradition
 */
class SacredSpaceCreator : public juce::Component
{
public:
    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();
        auto center = bounds.getCentre();

        // Universelle heilige Geometrie: Der Kreis
        // In jeder Tradition Symbol der Einheit und Vollkommenheit

        float radius = juce::jmin(bounds.getWidth(), bounds.getHeight()) * 0.4f;

        // Äußerer Kreis - Die Einheit
        g.setColour(juce::Colour(0xff1a1a2a));
        g.fillAll();

        // Konzentrischer Kreis-Effekt
        for (int i = 5; i >= 0; --i)
        {
            float r = radius * (1.0f - i * 0.15f);
            float alpha = 0.1f + i * 0.05f;

            g.setColour(juce::Colour(0xff4488aa).withAlpha(alpha));
            g.fillEllipse(center.x - r, center.y - r, r * 2, r * 2);
        }

        // Zentraler Punkt - Der Ursprung
        // In vielen Traditionen das Symbol des Einen
        float dotSize = 10.0f;
        g.setColour(juce::Colours::white);
        g.fillEllipse(center.x - dotSize/2, center.y - dotSize/2, dotSize, dotSize);

        // Botschaft
        g.setFont(14.0f);
        g.drawText(currentWisdom, bounds.removeFromBottom(40), juce::Justification::centred);
    }

    void setWisdom(const juce::String& wisdom)
    {
        currentWisdom = wisdom;
        repaint();
    }

private:
    juce::String currentWisdom = "In der Stille finden sich alle Traditionen.";
};

//==============================================================================
/**
 * @brief Unity Integration Panel
 *
 * Haupt-UI für die Integration aller Traditionen
 */
class UnityIntegrationPanel : public juce::Component
{
public:
    UnityIntegrationPanel()
    {
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Einheit in Vielfalt", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(20.0f, juce::Font::bold));
        titleLabel.setJustificationType(juce::Justification::centred);
        titleLabel.setColour(juce::Label::textColourId, juce::Colours::white);

        addAndMakeVisible(subtitleLabel);
        subtitleLabel.setText("\"Viele Wege, ein Berg\" - Zen-Weisheit", juce::dontSendNotification);
        subtitleLabel.setFont(juce::Font(12.0f, juce::Font::italic));
        subtitleLabel.setJustificationType(juce::Justification::centred);
        subtitleLabel.setColour(juce::Label::textColourId, juce::Colours::grey);

        addAndMakeVisible(sacredSpace);

        addAndMakeVisible(breathSelector);
        breathSelector.addItem("Pranayama (Yoga)", 1);
        breathSelector.addItem("Taoistische Atmung (Qigong)", 2);
        breathSelector.addItem("4-7-8 Entspannung", 3);
        breathSelector.addItem("Anapanasati (Buddhist)", 4);
        breathSelector.addItem("Herzensgebet (Orthodox)", 5);
        breathSelector.setSelectedId(1);

        addAndMakeVisible(wisdomBtn);
        wisdomBtn.setButtonText("Weisheit zeigen");
        wisdomBtn.onClick = [this] { showRandomWisdom(); };

        addAndMakeVisible(respectNote);
        respectNote.setText(
            "Mit Respekt und Dankbarkeit gegenüber allen Traditionen.\n"
            "Wir nehmen nicht - wir lernen und ehren.",
            juce::dontSendNotification
        );
        respectNote.setFont(juce::Font(10.0f));
        respectNote.setJustificationType(juce::Justification::centred);
        respectNote.setColour(juce::Label::textColourId, juce::Colours::grey);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(15);

        titleLabel.setBounds(bounds.removeFromTop(30));
        subtitleLabel.setBounds(bounds.removeFromTop(20));
        bounds.removeFromTop(10);

        sacredSpace.setBounds(bounds.removeFromTop(200));
        bounds.removeFromTop(10);

        breathSelector.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(10);

        wisdomBtn.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(10);

        respectNote.setBounds(bounds.removeFromBottom(40));
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff0a0a12));
    }

private:
    void showRandomWisdom()
    {
        auto themes = {
            UniversalWisdom::getGoldenRule(),
            UniversalWisdom::getOneness(),
            UniversalWisdom::getInnerJourney(),
            UniversalWisdom::getImpermanence()
        };

        int themeIdx = juce::Random::getSystemRandom().nextInt(4);
        auto theme = *(themes.begin() + themeIdx);

        std::vector<std::pair<juce::String, juce::String>> traditions(
            theme.traditions.begin(), theme.traditions.end());

        int tradIdx = juce::Random::getSystemRandom().nextInt(static_cast<int>(traditions.size()));
        auto& selected = traditions[tradIdx];

        juce::String wisdom = selected.first + ": \"" + selected.second + "\"";
        sacredSpace.setWisdom(wisdom);
    }

    juce::Label titleLabel;
    juce::Label subtitleLabel;
    SacredSpaceCreator sacredSpace;
    juce::ComboBox breathSelector;
    juce::TextButton wisdomBtn;
    juce::Label respectNote;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UnityIntegrationPanel)
};

} // namespace Unity
} // namespace Echoel
