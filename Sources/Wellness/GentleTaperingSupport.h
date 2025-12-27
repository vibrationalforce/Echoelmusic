#pragma once

#include <JuceHeader.h>
#include "CelestineIntegration.h"

namespace Echoel {
namespace Wellness {

//==============================================================================
/**
 * @brief Gentle Tapering Support System
 *
 * Ein sanftes, nicht-wertendes Unterstützungssystem
 * für Menschen, die ausschleichen möchten.
 *
 * PHILOSOPHIE:
 * - Kein Urteil, keine Schuld
 * - Sanfte Begleitung
 * - Der User hat die Kontrolle
 * - Rückfälle sind Teil des Weges
 * - Jeder kleine Schritt zählt
 *
 * "Du bist mehr als deine Gewohnheiten"
 */

//==============================================================================
enum class TaperingPhase
{
    Curious,        // Interessiert, noch nicht entschieden
    Preparing,      // Vorbereitung, Selbstbeobachtung
    Reducing,       // Aktive Reduktion
    Stabilizing,    // Stabilisierung auf niedrigerem Level
    FreeFromIt,     // Frei davon
    Maintenance     // Langfristige Pflege
};

//==============================================================================
/**
 * @brief Craving Wave - Modelliert den Verlauf eines Verlangens
 *
 * Wissenschaftlich: Cravings kommen in Wellen, die nach 15-30 Min abebben
 */
struct CravingWave
{
    double startTime = 0.0;
    float peakIntensity = 0.0f;
    float currentIntensity = 0.0f;
    bool survived = false;

    // Craving-Wellen dauern typischerweise 15-30 Minuten
    static constexpr double TYPICAL_DURATION = 20.0 * 60.0;  // 20 Minuten

    float getProgress(double currentTime) const
    {
        double elapsed = currentTime - startTime;
        return juce::jlimit(0.0f, 1.0f, static_cast<float>(elapsed / TYPICAL_DURATION));
    }

    bool hasPassedPeak(double currentTime) const
    {
        return getProgress(currentTime) > 0.5f;
    }

    bool isOver(double currentTime) const
    {
        return getProgress(currentTime) >= 1.0f;
    }
};

//==============================================================================
/**
 * @brief Gentle Tapering Manager
 */
class GentleTaperingManager
{
public:
    static GentleTaperingManager& getInstance()
    {
        static GentleTaperingManager instance;
        return instance;
    }

    //==========================================================================
    // Opt-in System - User entscheidet

    void enableSupport(bool enable)
    {
        supportEnabled = enable;
        if (enable)
        {
            sessionStartTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
        }
    }

    bool isSupportEnabled() const { return supportEnabled; }

    void setPhase(TaperingPhase phase)
    {
        currentPhase = phase;
    }

    TaperingPhase getPhase() const { return currentPhase; }

    //==========================================================================
    // Craving Support

    void reportCraving(float intensity = 0.7f)
    {
        if (!supportEnabled) return;

        CravingWave wave;
        wave.startTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
        wave.peakIntensity = intensity;
        wave.currentIntensity = intensity;

        activeCravings.push_back(wave);
        totalCravingsReported++;
    }

    void updateCravings()
    {
        double now = juce::Time::getMillisecondCounterHiRes() / 1000.0;

        for (auto& wave : activeCravings)
        {
            float progress = wave.getProgress(now);

            // Craving-Intensität folgt einer Wellen-Kurve
            // Steigt schnell an, fällt langsam ab
            if (progress < 0.3f)
            {
                // Anstieg
                wave.currentIntensity = wave.peakIntensity * (progress / 0.3f);
            }
            else
            {
                // Abfall
                float fallProgress = (progress - 0.3f) / 0.7f;
                wave.currentIntensity = wave.peakIntensity * (1.0f - fallProgress);
            }

            if (wave.isOver(now) && !wave.survived)
            {
                wave.survived = true;
                cravingsSurvived++;
            }
        }

        // Abgeschlossene Wellen entfernen
        activeCravings.erase(
            std::remove_if(activeCravings.begin(), activeCravings.end(),
                [now](const CravingWave& w) {
                    return w.isOver(now) && w.survived;
                }),
            activeCravings.end()
        );
    }

    bool hasActiveCraving() const { return !activeCravings.empty(); }

    float getCurrentCravingIntensity() const
    {
        if (activeCravings.empty()) return 0.0f;

        float maxIntensity = 0.0f;
        for (const auto& wave : activeCravings)
        {
            maxIntensity = juce::jmax(maxIntensity, wave.currentIntensity);
        }
        return maxIntensity;
    }

    //==========================================================================
    // Supportive Messages - Keine Schuld, nur Unterstützung

    juce::String getSupportMessage() const
    {
        if (!supportEnabled) return "";

        if (hasActiveCraving())
        {
            return getCravingSupportMessage();
        }

        return getGeneralSupportMessage();
    }

    juce::String getCravingSupportMessage() const
    {
        float intensity = getCurrentCravingIntensity();
        double now = juce::Time::getMillisecondCounterHiRes() / 1000.0;

        // Finde die älteste aktive Welle
        float progress = 0.0f;
        for (const auto& wave : activeCravings)
        {
            progress = juce::jmax(progress, wave.getProgress(now));
        }

        if (progress < 0.3f)
        {
            // Frühe Phase - Anerkennung
            const char* messages[] = {
                "Ich spüre, dass es gerade schwer ist.",
                "Es ist okay, das zu fühlen.",
                "Du bist nicht allein damit.",
                "Atme. Du schaffst das."
            };
            return messages[juce::Random::getSystemRandom().nextInt(4)];
        }
        else if (progress < 0.6f)
        {
            // Mittlere Phase - Ermutigung
            const char* messages[] = {
                "Du bist schon über die Hälfte.",
                "Die Welle beginnt abzuebben.",
                "Jede Minute, die vergeht, macht es leichter.",
                "Dein Körper reguliert sich gerade."
            };
            return messages[juce::Random::getSystemRandom().nextInt(4)];
        }
        else
        {
            // Späte Phase - Fast geschafft
            const char* messages[] = {
                "Fast geschafft. Die Welle geht vorbei.",
                "Du hast das Schlimmste überstanden.",
                "Siehst du? Es wird besser.",
                "Stolz auf dich. Gleich ist es vorbei."
            };
            return messages[juce::Random::getSystemRandom().nextInt(4)];
        }
    }

    juce::String getGeneralSupportMessage() const
    {
        switch (currentPhase)
        {
            case TaperingPhase::Curious:
                return "Nimm dir Zeit. Es gibt keinen Druck.";

            case TaperingPhase::Preparing:
                return "Selbstbeobachtung ist ein wichtiger Schritt.";

            case TaperingPhase::Reducing:
            {
                const char* messages[] = {
                    "Jeder Tag ist ein Erfolg.",
                    "Kleine Schritte führen weit.",
                    "Sei sanft mit dir selbst.",
                    "Du machst das richtig."
                };
                return messages[juce::Random::getSystemRandom().nextInt(4)];
            }

            case TaperingPhase::Stabilizing:
                return "Stabilität braucht Zeit. Du bist auf einem guten Weg.";

            case TaperingPhase::FreeFromIt:
                return "Du hast es geschafft. Jeden Tag aufs Neue.";

            case TaperingPhase::Maintenance:
                return "Weiter so. Du lebst dein neues Leben.";

            default:
                return "";
        }
    }

    //==========================================================================
    // Coping Strategies

    struct CopingStrategy
    {
        juce::String name;
        juce::String description;
        int durationSeconds;
        bool usesBiofeedback;
    };

    std::vector<CopingStrategy> getCopingStrategies() const
    {
        return {
            {
                "4-7-8 Atmung",
                "Einatmen (4s), Halten (7s), Ausatmen (8s). 3 Wiederholungen.",
                60,
                true
            },
            {
                "Körper-Scan",
                "Spüre deinen Körper von Kopf bis Fuß. Wo ist Anspannung?",
                120,
                true
            },
            {
                "Wasser trinken",
                "Ein großes Glas Wasser, langsam trinken.",
                60,
                false
            },
            {
                "Bewegung",
                "10 Hampelmänner oder ein kurzer Spaziergang.",
                120,
                false
            },
            {
                "Musik machen",
                "Öffne ein Instrument und spiele etwas. Egal was.",
                300,
                true
            },
            {
                "HALT-Check",
                "Bist du Hungry, Angry, Lonely, Tired? Kümmere dich darum.",
                60,
                false
            },
            {
                "Surf the Urge",
                "Beobachte das Verlangen wie eine Welle. Es wird vorbeigehen.",
                300,
                true
            },
            {
                "Grounding 5-4-3-2-1",
                "5 Dinge sehen, 4 hören, 3 fühlen, 2 riechen, 1 schmecken.",
                120,
                false
            }
        };
    }

    //==========================================================================
    // Progress Tracking - Positiv, nicht strafend

    struct Progress
    {
        int cravingsSurvived = 0;
        int totalCravings = 0;
        double longestStreakSeconds = 0.0;
        double currentStreakSeconds = 0.0;
        std::vector<juce::String> achievements;
    };

    Progress getProgress() const
    {
        Progress p;
        p.cravingsSurvived = cravingsSurvived;
        p.totalCravings = totalCravingsReported;

        double now = juce::Time::getMillisecondCounterHiRes() / 1000.0;
        p.currentStreakSeconds = now - lastCravingTime;

        // Achievements - kleine Erfolge feiern
        if (cravingsSurvived >= 1)
            p.achievements.push_back("Erste Welle überlebt 🌊");
        if (cravingsSurvived >= 5)
            p.achievements.push_back("5 Wellen gemeistert 💪");
        if (cravingsSurvived >= 10)
            p.achievements.push_back("Wellen-Surfer 🏄");
        if (p.currentStreakSeconds > 3600)
            p.achievements.push_back("1 Stunde Klarheit ✨");
        if (p.currentStreakSeconds > 86400)
            p.achievements.push_back("24 Stunden Stärke 🌟");

        return p;
    }

    //==========================================================================
    // Relapse Support - Kein Urteil bei Rückfall

    void reportRelapse()
    {
        if (!supportEnabled) return;

        relapseCount++;
        lastRelapseTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;

        // Kein Reset der positiven Statistiken - jeder Fortschritt zählt
    }

    juce::String getRelapseSupport() const
    {
        const char* messages[] = {
            "Ein Rückfall ist kein Versagen. Es ist Teil des Weges.",
            "Du hast es einmal geschafft. Du kannst es wieder schaffen.",
            "Sei jetzt besonders sanft mit dir.",
            "Was kannst du aus diesem Moment lernen?",
            "Morgen ist ein neuer Tag.",
            "Du bist nicht dein Rückfall.",
            "Jeder Versuch macht dich stärker.",
            "Vergebung beginnt bei dir selbst."
        };
        return messages[juce::Random::getSystemRandom().nextInt(8)];
    }

    //==========================================================================
    // Integration with Biofeedback

    void updateFromBiometrics(float heartRate, float hrv, float breathRate)
    {
        // Erhöhte Herzfrequenz + niedrige HRV kann auf Craving hindeuten
        bool potentialCraving = heartRate > 85.0f && hrv < 30.0f;

        if (potentialCraving && !hasActiveCraving() && supportEnabled)
        {
            // Sanfter Hinweis, keine Annahme
            potentialCravingDetected = true;
        }
        else
        {
            potentialCravingDetected = false;
        }

        // Für Beruhigungsübungen
        currentBreathRate = breathRate;
        currentHRV = hrv;
    }

    bool isPotentialCravingDetected() const { return potentialCravingDetected; }

    // Biofeedback-gestützte Beruhigung
    juce::String getBreathingGuidance() const
    {
        if (currentBreathRate > 16.0f)
        {
            return "Versuche, langsamer zu atmen. Dein Atem ist bei " +
                   juce::String(currentBreathRate, 1) + "/min.";
        }
        else if (currentBreathRate < 8.0f)
        {
            return "Schöne, tiefe Atmung. Weiter so.";
        }
        return "Atme ruhig weiter.";
    }

private:
    GentleTaperingManager() = default;

    bool supportEnabled = false;
    TaperingPhase currentPhase = TaperingPhase::Curious;

    std::vector<CravingWave> activeCravings;
    int totalCravingsReported = 0;
    int cravingsSurvived = 0;
    double lastCravingTime = 0.0;

    int relapseCount = 0;
    double lastRelapseTime = 0.0;

    double sessionStartTime = 0.0;

    // Biofeedback
    float currentBreathRate = 12.0f;
    float currentHRV = 50.0f;
    bool potentialCravingDetected = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GentleTaperingManager)
};

//==============================================================================
/**
 * @brief Craving Wave Visualizer
 *
 * Zeigt die Craving-Welle und ihren Verlauf
 * "Surf the Urge" - Visualisierung
 */
class CravingWaveVisualizer : public juce::Component,
                               private juce::Timer
{
public:
    CravingWaveVisualizer()
    {
        startTimerHz(30);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();
        auto& manager = GentleTaperingManager::getInstance();

        // Hintergrund
        g.fillAll(juce::Colour(0xff0a0a12));

        if (!manager.isSupportEnabled())
        {
            g.setColour(juce::Colours::grey);
            g.setFont(14.0f);
            g.drawText("Support nicht aktiviert", bounds, juce::Justification::centred);
            return;
        }

        if (manager.hasActiveCraving())
        {
            drawActiveWave(g, bounds, manager);
        }
        else
        {
            drawCalmState(g, bounds);
        }

        // Support-Nachricht
        g.setColour(juce::Colours::white);
        g.setFont(14.0f);
        g.drawText(manager.getSupportMessage(),
                   bounds.removeFromBottom(40), juce::Justification::centred);
    }

private:
    void timerCallback() override
    {
        GentleTaperingManager::getInstance().updateCravings();
        repaint();
    }

    void drawActiveWave(juce::Graphics& g, juce::Rectangle<float> bounds,
                        const GentleTaperingManager& manager)
    {
        float intensity = manager.getCurrentCravingIntensity();

        // Wellen-Animation
        juce::Path wavePath;
        float waveHeight = bounds.getHeight() * 0.3f * intensity;
        float centerY = bounds.getCentreY();

        wavePath.startNewSubPath(bounds.getX(), centerY);

        for (float x = bounds.getX(); x < bounds.getRight(); x += 2.0f)
        {
            float normalizedX = (x - bounds.getX()) / bounds.getWidth();
            float wave = std::sin((normalizedX * 4.0f + animPhase) * juce::MathConstants<float>::pi);
            float y = centerY - wave * waveHeight;
            wavePath.lineTo(x, y);
        }

        wavePath.lineTo(bounds.getRight(), bounds.getBottom());
        wavePath.lineTo(bounds.getX(), bounds.getBottom());
        wavePath.closeSubPath();

        // Farbe basierend auf Intensität (blau = ruhig, rot = intensiv)
        juce::Colour waveColor = juce::Colour::fromHSV(
            0.6f - intensity * 0.5f,  // Hue: blau -> rot
            0.6f,
            0.7f,
            0.6f
        );

        g.setColour(waveColor);
        g.fillPath(wavePath);

        // Progress-Anzeige
        g.setColour(juce::Colours::white);
        g.setFont(12.0f);

        juce::String progressText = "Die Welle wird vorbeigehen...";
        g.drawText(progressText, bounds.removeFromTop(30), juce::Justification::centred);

        animPhase += 0.05f;
    }

    void drawCalmState(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        // Ruhiger Ozean
        float centerY = bounds.getCentreY() + bounds.getHeight() * 0.1f;

        juce::Path calmPath;
        calmPath.startNewSubPath(bounds.getX(), centerY);

        for (float x = bounds.getX(); x < bounds.getRight(); x += 5.0f)
        {
            float normalizedX = (x - bounds.getX()) / bounds.getWidth();
            float wave = std::sin((normalizedX * 2.0f + animPhase * 0.3f) * juce::MathConstants<float>::pi);
            float y = centerY - wave * 5.0f;  // Kleine, sanfte Wellen
            calmPath.lineTo(x, y);
        }

        calmPath.lineTo(bounds.getRight(), bounds.getBottom());
        calmPath.lineTo(bounds.getX(), bounds.getBottom());
        calmPath.closeSubPath();

        g.setColour(juce::Colour(0xff2a4a6a).withAlpha(0.5f));
        g.fillPath(calmPath);

        // Sterne / Ruhe-Symbol
        g.setColour(juce::Colours::white.withAlpha(0.3f));
        for (int i = 0; i < 5; ++i)
        {
            float x = bounds.getX() + (i + 0.5f) * bounds.getWidth() / 5.0f;
            float y = bounds.getY() + 30.0f + std::sin(animPhase + i) * 10.0f;
            g.fillEllipse(x - 2, y - 2, 4, 4);
        }

        g.setColour(juce::Colours::white);
        g.setFont(16.0f);
        g.drawText("Ruhige See", bounds.removeFromTop(50), juce::Justification::centred);

        animPhase += 0.02f;
    }

    float animPhase = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CravingWaveVisualizer)
};

//==============================================================================
/**
 * @brief Gentle Support Panel
 */
class GentleSupportPanel : public juce::Component
{
public:
    GentleSupportPanel()
    {
        addAndMakeVisible(waveVisualizer);

        addAndMakeVisible(enableToggle);
        enableToggle.setButtonText("Sanfte Unterstützung aktivieren");
        enableToggle.onClick = [this]
        {
            GentleTaperingManager::getInstance().enableSupport(enableToggle.getToggleState());
        };

        addAndMakeVisible(reportCravingBtn);
        reportCravingBtn.setButtonText("Ich spüre ein Verlangen");
        reportCravingBtn.onClick = []
        {
            GentleTaperingManager::getInstance().reportCraving();
        };

        addAndMakeVisible(copingBtn);
        copingBtn.setButtonText("Zeige mir eine Strategie");
        copingBtn.onClick = [this] { showRandomCopingStrategy(); };

        addAndMakeVisible(strategyLabel);
        strategyLabel.setFont(juce::Font(12.0f));
        strategyLabel.setColour(juce::Label::textColourId, juce::Colours::lightgrey);
        strategyLabel.setJustificationType(juce::Justification::centred);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);

        enableToggle.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(10);

        waveVisualizer.setBounds(bounds.removeFromTop(150));
        bounds.removeFromTop(10);

        auto buttonRow = bounds.removeFromTop(35);
        reportCravingBtn.setBounds(buttonRow.removeFromLeft(buttonRow.getWidth() / 2 - 5));
        buttonRow.removeFromLeft(10);
        copingBtn.setBounds(buttonRow);

        bounds.removeFromTop(10);
        strategyLabel.setBounds(bounds.removeFromTop(60));
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff0d1117));
    }

private:
    void showRandomCopingStrategy()
    {
        auto strategies = GentleTaperingManager::getInstance().getCopingStrategies();
        int idx = juce::Random::getSystemRandom().nextInt(static_cast<int>(strategies.size()));

        auto& strategy = strategies[idx];
        strategyLabel.setText(strategy.name + "\n" + strategy.description,
                              juce::dontSendNotification);
    }

    CravingWaveVisualizer waveVisualizer;
    juce::ToggleButton enableToggle;
    juce::TextButton reportCravingBtn;
    juce::TextButton copingBtn;
    juce::Label strategyLabel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GentleSupportPanel)
};

} // namespace Wellness
} // namespace Echoel
