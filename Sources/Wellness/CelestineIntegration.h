#pragma once

#include <JuceHeader.h>
#include "../Biofeedback/BioMetrics.h"

namespace Echoel {
namespace Wellness {

//==============================================================================
/**
 * @brief Celestine Energy Integration
 *
 * Basierend auf den 9 Einsichten der Prophezeiung von Celestine:
 * Integration von Energie-Bewusstsein in die Musikproduktion
 *
 * DIE 9 EINSICHTEN:
 * 1. Kritische Masse - Bedeutungsvolle Zufälle häufen sich
 * 2. Das längere Jetzt - Geschichte als spirituelle Reise
 * 3. Eine Frage der Energie - Alles ist wahrnehmbare Energie
 * 4. Der Kampf um Macht - Menschen konkurrieren um Energie
 * 5. Die Botschaft der Mystiker - Verbindung zur göttlichen Energie
 * 6. Die Vergangenheit klären - Kontrolldramen erkennen
 * 7. Den Fluss aktivieren - Intuition und Synchronizitäten folgen
 * 8. Die zwischenmenschliche Ethik - Andere erheben
 * 9. Die entstehende Kultur - Gemeinsam die Einsichten leben
 *
 * ANWENDUNG IN DER SOFTWARE:
 * - Energie-Visualisierung und -Messung
 * - Flow-State-Erkennung
 * - Synchronizitäts-Awareness
 * - Erhebende Interaktionen (keine Energie-Vampire-Patterns)
 */

//==============================================================================
/**
 * @brief Energy State - Based on Insight 3
 * "Alles ist Energie, die wir wahrnehmen können"
 */
enum class EnergyLevel
{
    Depleted,      // Erschöpft - braucht Aufladung
    Low,           // Niedrig - achtsam arbeiten
    Balanced,      // Ausgeglichen - optimal
    Elevated,      // Erhöht - kreativer Flow
    Peak           // Spitze - höchste Kreativität
};

//==============================================================================
/**
 * @brief Control Drama Types - Based on Insight 6
 * Die 4 Kontrolldramen, die wir in der UI VERMEIDEN
 */
enum class ControlDrama
{
    None,          // Keine - gesunde Interaktion

    // Diese vermeiden wir aktiv in der UI:
    Intimidator,   // Einschüchtern (aggressive Popups, Warnungen)
    Interrogator,  // Ausfragen (zu viele Fragen, komplexe Formulare)
    Aloof,         // Unnahbar (versteckte Features, kryptische UI)
    PoorMe         // Armer Ich (Guilt-Trips, Schuldzuweisungen)
};

//==============================================================================
/**
 * @brief Celestine Energy Monitor
 *
 * Überwacht und visualisiert die Energie des Users
 * basierend auf Biofeedback und Interaktionsmustern
 */
class CelestineEnergyMonitor
{
public:
    static CelestineEnergyMonitor& getInstance()
    {
        static CelestineEnergyMonitor instance;
        return instance;
    }

    //==========================================================================
    // Insight 3: Energy Perception

    struct EnergyState
    {
        EnergyLevel level = EnergyLevel::Balanced;
        float rawEnergy = 0.5f;           // 0-1
        float flowIntensity = 0.0f;       // Flow-State Intensität
        float creativePotential = 0.5f;   // Kreatives Potenzial
        float coherence = 0.0f;           // HRV-basierte Kohärenz
        bool inFlow = false;              // Im Flow-Zustand?
        double flowDuration = 0.0;        // Sekunden im Flow
    };

    void updateFromBiometrics(float heartRate, float hrv, float breathRate)
    {
        // Kohärenz aus HRV ableiten (höhere HRV = bessere Kohärenz)
        float normalizedHRV = juce::jlimit(0.0f, 1.0f, hrv / 100.0f);
        state.coherence = state.coherence * 0.9f + normalizedHRV * 0.1f;

        // Energie-Level aus Kohärenz und Herzfrequenz
        float calmness = 1.0f - juce::jlimit(0.0f, 1.0f, (heartRate - 60.0f) / 40.0f);
        state.rawEnergy = (state.coherence * 0.6f + calmness * 0.4f);

        // Kreatives Potenzial: Hohe Kohärenz + moderate Aktivierung
        float optimalArousal = 1.0f - std::abs(heartRate - 75.0f) / 25.0f;
        state.creativePotential = state.coherence * 0.7f + optimalArousal * 0.3f;

        updateEnergyLevel();
        detectFlowState();
    }

    void updateFromInteraction(float interactionRate, float undoRate)
    {
        // Fluss-Intensität: Viele Interaktionen, wenige Undos = im Flow
        float flowIndicator = interactionRate * (1.0f - undoRate * 2.0f);
        state.flowIntensity = juce::jlimit(0.0f, 1.0f,
            state.flowIntensity * 0.95f + flowIndicator * 0.05f);
    }

    const EnergyState& getState() const { return state; }
    EnergyLevel getLevel() const { return state.level; }
    bool isInFlow() const { return state.inFlow; }

    //==========================================================================
    // Insight 5: Connection to Divine Energy

    struct EnergySourceRecommendation
    {
        juce::String activity;
        juce::String description;
        float potentialBoost;
    };

    std::vector<EnergySourceRecommendation> getEnergyRecommendations() const
    {
        std::vector<EnergySourceRecommendation> recs;

        if (state.level == EnergyLevel::Depleted)
        {
            recs.push_back({
                "Naturverbindung",
                "5 Minuten Pause, Blick ins Grüne oder Naturgeräusche",
                0.3f
            });
            recs.push_back({
                "Tiefes Atmen",
                "10 langsame, tiefe Atemzüge",
                0.2f
            });
        }
        else if (state.level == EnergyLevel::Low)
        {
            recs.push_back({
                "Bewegung",
                "Kurzes Stretching oder Spaziergang",
                0.25f
            });
            recs.push_back({
                "Hydration",
                "Ein Glas Wasser trinken",
                0.1f
            });
        }
        else if (state.level == EnergyLevel::Elevated || state.level == EnergyLevel::Peak)
        {
            recs.push_back({
                "Flow nutzen",
                "Perfekte Zeit für kreative Arbeit!",
                0.0f
            });
            recs.push_back({
                "Dokumentieren",
                "Ideen festhalten während die Energie hoch ist",
                0.0f
            });
        }

        return recs;
    }

    //==========================================================================
    // Insight 7: Engaging the Flow

    struct SynchronicityEvent
    {
        juce::String description;
        double timestamp;
        float significance;
    };

    void logSynchronicity(const juce::String& event, float significance = 0.5f)
    {
        SynchronicityEvent sync;
        sync.description = event;
        sync.timestamp = juce::Time::getMillisecondCounterHiRes() / 1000.0;
        sync.significance = significance;

        synchronicities.push_back(sync);

        // Nur die letzten 20 behalten
        if (synchronicities.size() > 20)
            synchronicities.erase(synchronicities.begin());
    }

    // Erkennt Muster in der kreativen Arbeit
    void checkForPatterns(const juce::String& currentAction)
    {
        // Beispiel: Wenn der User wiederholt ähnliche Aktionen macht,
        // könnte das ein Hinweis auf einen tieferen kreativen Impuls sein
        recentActions.push_back(currentAction);
        if (recentActions.size() > 10)
            recentActions.erase(recentActions.begin());

        // Pattern-Erkennung (vereinfacht)
        int repeatCount = 0;
        for (const auto& action : recentActions)
        {
            if (action == currentAction)
                repeatCount++;
        }

        if (repeatCount >= 3)
        {
            logSynchronicity("Wiederkehrendes Muster erkannt: " + currentAction, 0.7f);
        }
    }

    const std::vector<SynchronicityEvent>& getSynchronicities() const
    {
        return synchronicities;
    }

private:
    CelestineEnergyMonitor() = default;

    void updateEnergyLevel()
    {
        if (state.rawEnergy < 0.2f)
            state.level = EnergyLevel::Depleted;
        else if (state.rawEnergy < 0.4f)
            state.level = EnergyLevel::Low;
        else if (state.rawEnergy < 0.6f)
            state.level = EnergyLevel::Balanced;
        else if (state.rawEnergy < 0.8f)
            state.level = EnergyLevel::Elevated;
        else
            state.level = EnergyLevel::Peak;
    }

    void detectFlowState()
    {
        // Flow = hohe Kohärenz + hohe Flow-Intensität + moderates Energie-Level
        bool potentialFlow = state.coherence > 0.6f &&
                            state.flowIntensity > 0.5f &&
                            state.level >= EnergyLevel::Balanced;

        if (potentialFlow && !state.inFlow)
        {
            state.inFlow = true;
            flowStartTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
            logSynchronicity("Flow-Zustand begonnen", 0.8f);
        }
        else if (!potentialFlow && state.inFlow)
        {
            state.inFlow = false;
            state.flowDuration = 0.0;
        }

        if (state.inFlow)
        {
            state.flowDuration = juce::Time::getMillisecondCounterHiRes() / 1000.0 - flowStartTime;
        }
    }

    EnergyState state;
    double flowStartTime = 0.0;
    std::vector<SynchronicityEvent> synchronicities;
    std::vector<juce::String> recentActions;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CelestineEnergyMonitor)
};

//==============================================================================
/**
 * @brief Interpersonal Ethics Manager - Based on Insight 8
 *
 * "In Gesprächen andere erheben statt Energie zu stehlen"
 *
 * Überwacht UI-Interaktionen auf "Energie-Vampir"-Patterns
 * und fördert erhebende Interaktionen
 */
class InterpersonalEthicsManager
{
public:
    static InterpersonalEthicsManager& getInstance()
    {
        static InterpersonalEthicsManager instance;
        return instance;
    }

    //==========================================================================
    // Prüft ob eine UI-Nachricht ein Kontrolldrama darstellt

    struct MessageAnalysis
    {
        ControlDrama drama = ControlDrama::None;
        juce::String suggestion;
        bool isEthical = true;
    };

    MessageAnalysis analyzeMessage(const juce::String& message) const
    {
        MessageAnalysis analysis;
        juce::String lowerMsg = message.toLowerCase();

        // Intimidator-Patterns (Einschüchterung)
        if (lowerMsg.contains("warnung") || lowerMsg.contains("fehler") ||
            lowerMsg.contains("achtung") || lowerMsg.contains("!"))
        {
            if (lowerMsg.contains("!!") || lowerMsg.containsOnly("ABCDEFGHIJKLMNOPQRSTUVWXYZ "))
            {
                analysis.drama = ControlDrama::Intimidator;
                analysis.suggestion = "Sanftere Formulierung verwenden";
                analysis.isEthical = false;
            }
        }

        // Interrogator-Patterns (Ausfragen)
        int questionMarks = 0;
        for (auto c : message)
            if (c == '?') questionMarks++;

        if (questionMarks > 2)
        {
            analysis.drama = ControlDrama::Interrogator;
            analysis.suggestion = "Weniger Fragen auf einmal stellen";
            analysis.isEthical = false;
        }

        // PoorMe-Patterns (Schuldgefühle)
        if (lowerMsg.contains("schade") || lowerMsg.contains("leider") ||
            lowerMsg.contains("enttäuscht") || lowerMsg.contains("verloren"))
        {
            analysis.drama = ControlDrama::PoorMe;
            analysis.suggestion = "Positive Formulierung finden";
            analysis.isEthical = false;
        }

        // Aloof-Patterns (Unnahbar)
        if (lowerMsg.contains("fortgeschritten") || lowerMsg.contains("experte") ||
            lowerMsg.contains("komplex"))
        {
            analysis.drama = ControlDrama::Aloof;
            analysis.suggestion = "Zugänglichere Sprache verwenden";
            analysis.isEthical = false;
        }

        return analysis;
    }

    //==========================================================================
    // Generiert erhebende Nachrichten

    juce::String getUpliftingMessage(EnergyLevel level) const
    {
        switch (level)
        {
            case EnergyLevel::Depleted:
                return "Zeit für eine kleine Pause - dein Körper spricht zu dir.";

            case EnergyLevel::Low:
                return "Sanft weitermachen - jeder Schritt zählt.";

            case EnergyLevel::Balanced:
                return "Schöner Flow - du bist auf einem guten Weg.";

            case EnergyLevel::Elevated:
                return "Deine Energie ist hoch - perfekt für Kreatives!";

            case EnergyLevel::Peak:
                return "Magischer Moment - lass die Kreativität fließen!";

            default:
                return "";
        }
    }

    //==========================================================================
    // Feedback ohne Kontrolldrama geben

    juce::String getConstructiveFeedback(bool success, const juce::String& context) const
    {
        if (success)
        {
            // Keine übertriebene Belohnung (vermeidet variable reward addiction)
            return "Gespeichert.";
        }
        else
        {
            // Keine Schuldzuweisung, konstruktiv
            return "Nicht gespeichert - " + context + ". Versuch es nochmal wenn du bereit bist.";
        }
    }

private:
    InterpersonalEthicsManager() = default;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(InterpersonalEthicsManager)
};

//==============================================================================
/**
 * @brief Celestine Energy Visualizer Component
 */
class CelestineEnergyVisualizer : public juce::Component,
                                   private juce::Timer
{
public:
    CelestineEnergyVisualizer()
    {
        startTimerHz(30);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();
        auto& monitor = CelestineEnergyMonitor::getInstance();
        auto state = monitor.getState();

        // Hintergrund
        g.fillAll(juce::Colour(0xff0a0a12));

        // Energie-Aura (Insight 3)
        drawEnergyAura(g, bounds, state);

        // Flow-Indikator (Insight 7)
        if (state.inFlow)
        {
            drawFlowIndicator(g, bounds, state);
        }

        // Energie-Level Text
        g.setColour(juce::Colours::white);
        g.setFont(14.0f);

        juce::String levelText;
        switch (state.level)
        {
            case EnergyLevel::Depleted: levelText = "Energie: Erschöpft"; break;
            case EnergyLevel::Low: levelText = "Energie: Niedrig"; break;
            case EnergyLevel::Balanced: levelText = "Energie: Ausgeglichen"; break;
            case EnergyLevel::Elevated: levelText = "Energie: Erhöht"; break;
            case EnergyLevel::Peak: levelText = "Energie: Spitze!"; break;
        }

        g.drawText(levelText, bounds.removeFromTop(25), juce::Justification::centred);

        // Erhebende Nachricht (Insight 8)
        auto& ethics = InterpersonalEthicsManager::getInstance();
        g.setFont(12.0f);
        g.setColour(juce::Colours::lightgrey);
        g.drawText(ethics.getUpliftingMessage(state.level),
                   bounds.removeFromBottom(20), juce::Justification::centred);
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    void drawEnergyAura(juce::Graphics& g, juce::Rectangle<float> bounds,
                        const CelestineEnergyMonitor::EnergyState& state)
    {
        auto center = bounds.getCentre();
        float maxRadius = juce::jmin(bounds.getWidth(), bounds.getHeight()) * 0.4f;
        float radius = maxRadius * state.rawEnergy;

        // Aura-Farbe basierend auf Level
        juce::Colour auraColor;
        switch (state.level)
        {
            case EnergyLevel::Depleted:
                auraColor = juce::Colour(0xff404040);
                break;
            case EnergyLevel::Low:
                auraColor = juce::Colour(0xff606080);
                break;
            case EnergyLevel::Balanced:
                auraColor = juce::Colour(0xff4488aa);
                break;
            case EnergyLevel::Elevated:
                auraColor = juce::Colour(0xff44aaff);
                break;
            case EnergyLevel::Peak:
                auraColor = juce::Colour(0xffffff88);
                break;
        }

        // Pulsierendes Glühen
        float pulse = 0.8f + 0.2f * std::sin(animPhase * juce::MathConstants<float>::twoPi);
        radius *= pulse;

        // Mehrere Schichten für Aura-Effekt
        for (int i = 3; i >= 0; --i)
        {
            float layerRadius = radius * (1.0f + i * 0.15f);
            float alpha = 0.3f / (i + 1);

            g.setColour(auraColor.withAlpha(alpha));
            g.fillEllipse(center.x - layerRadius, center.y - layerRadius,
                         layerRadius * 2, layerRadius * 2);
        }

        // Kohärenz-Ring
        if (state.coherence > 0.5f)
        {
            g.setColour(juce::Colours::white.withAlpha(state.coherence * 0.5f));
            g.drawEllipse(center.x - radius, center.y - radius,
                         radius * 2, radius * 2, 2.0f);
        }
    }

    void drawFlowIndicator(juce::Graphics& g, juce::Rectangle<float> bounds,
                           const CelestineEnergyMonitor::EnergyState& state)
    {
        auto center = bounds.getCentre();

        // "FLOW" Text mit Glow
        g.setColour(juce::Colours::cyan.withAlpha(0.8f));
        g.setFont(juce::Font(20.0f, juce::Font::bold));
        g.drawText("FLOW", bounds.withY(center.y - 40).withHeight(30),
                   juce::Justification::centred);

        // Flow-Dauer
        int minutes = static_cast<int>(state.flowDuration / 60.0);
        int seconds = static_cast<int>(state.flowDuration) % 60;
        g.setFont(12.0f);
        g.drawText(juce::String::formatted("%d:%02d", minutes, seconds),
                   bounds.withY(center.y - 15).withHeight(20),
                   juce::Justification::centred);
    }

    float animPhase = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CelestineEnergyVisualizer)
};

//==============================================================================
/**
 * @brief The Nine Insights Applied to Software
 *
 * Dokumentation der Anwendung jeder Einsicht:
 */
struct CelestineInsights
{
    static constexpr const char* Insight1_CriticalMass =
        "Die Software ist Teil einer kritischen Masse von Werkzeugen, "
        "die Kreativität und Wohlbefinden fördern.";

    static constexpr const char* Insight2_LongerNow =
        "Wir verstehen Software-Entwicklung als Teil einer längeren Reise "
        "zu bewussterem Technologie-Design.";

    static constexpr const char* Insight3_Energy =
        "Alles in der UI repräsentiert und beeinflusst Energie. "
        "Wir visualisieren die Energie des Users und respektieren sie.";

    static constexpr const char* Insight4_PowerStruggle =
        "Wir vermeiden alle Kontrolldramen in der UI: "
        "Keine Einschüchterung, kein Ausfragen, keine Unnahbarkeit, keine Schuld.";

    static constexpr const char* Insight5_MysticMessage =
        "Die Software ermöglicht Verbindung zu kreativer Quelle "
        "durch Flow-Zustände und meditative Features.";

    static constexpr const char* Insight6_ClearingPast =
        "Wir erkennen unsere eigenen Kontrolldramen als Entwickler "
        "und bauen sie nicht in die Software ein.";

    static constexpr const char* Insight7_EngagingFlow =
        "Die Software erkennt und unterstützt den natürlichen Fluss "
        "der Kreativität, zeigt Synchronizitäten auf.";

    static constexpr const char* Insight8_InterpersonalEthic =
        "Jede UI-Interaktion erhebt den User statt Energie zu stehlen. "
        "Konstruktives Feedback statt Kritik.";

    static constexpr const char* Insight9_EmergingCulture =
        "Die Software ist Teil einer entstehenden Kultur "
        "von ethischer, bewusster Technologie.";
};

} // namespace Wellness
} // namespace Echoel
