#pragma once

#include <JuceHeader.h>
#include "SuperIntelligenceTouch.h"
#include "TouchOptimizedControls.h"

namespace Echoel {
namespace Touch {

//==============================================================================
/**
 * @brief Enhanced Accessibility Touch Profiles
 *
 * Erweiterte Touch-Profile für verschiedene motorische Zustände:
 * - Hyperaktive Bewegungen (schnell, zittrig, überschießend)
 * - Verlangsamte Bewegungen (träge, dissoziert)
 * - Allgemeine motorische Beeinträchtigung
 *
 * Design-Philosophie:
 * "Jeder soll performen können - in jedem Zustand"
 */

enum class MotorProfile
{
    Normal,              // Standard-Einstellungen

    // Hyperaktive Profile (schnelle, überschießende Bewegungen)
    Hyperactive,         // Erhöhte Aktivität, überschießende Gesten
    HighEnergy,          // Sehr schnelle, zittrige Bewegungen
    Erratic,             // Unvorhersehbare, sprunghafte Bewegungen

    // Verlangsamte Profile
    Relaxed,             // Verlangsamte Reaktionen
    Dissociated,         // Verzögerte, "schwimmende" Bewegungen
    HeavyHands,          // Träge, schwere Bewegungen

    // Spezial-Profile
    AutoPilot,           // Maximale Stabilisierung
    PerformanceMode,     // Große Ziele, tolerante Erkennung

    NumProfiles
};

//==============================================================================
/**
 * @brief Motor Profile Configuration
 */
struct MotorProfileConfig
{
    juce::String name;
    juce::String description;

    // Tremor/Jitter Filtering
    float tremorFilterStrength;     // 0-1, höher = mehr Glättung
    float jitterThreshold;          // Pixel, ab wann als Jitter erkannt

    // Sensitivity
    float fineAdjustSensitivity;    // 0.1-1.0
    float fastMorphSensitivity;     // 1.0-5.0
    float overallSensitivity;       // Globaler Multiplikator

    // Timing
    float holdDelay;                // Sekunden bis Hold erkannt
    float intentDetectionSpeed;     // 0-1, schneller = reaktiver
    float debounceTime;             // Sekunden, verhindert Doppel-Taps

    // Target Sizing
    float touchTargetScale;         // 1.0 = normal, 2.0 = doppelt
    float magnetRadius;             // Pixel, "Snap-to" Radius

    // Phase-Jump Prevention
    float maxSlewRate;              // Max Änderung pro Sekunde
    bool aggressiveSmoothing;       // Extra Glättung

    // Visual Feedback
    float visualFeedbackIntensity;  // 0-1
    bool showGuideLines;            // Hilfslinien anzeigen
    bool highContrastMode;          // Hoher Kontrast

    // Safety
    float accidentalTouchThreshold; // Bewegung nötig für Aktivierung
    bool confirmLargeChanges;       // Bestätigung bei großen Änderungen
};

//==============================================================================
/**
 * @brief Enhanced Accessibility Touch Manager
 */
class AccessibilityTouchManager : public juce::ChangeBroadcaster
{
public:
    static AccessibilityTouchManager& getInstance()
    {
        static AccessibilityTouchManager instance;
        return instance;
    }

    //==========================================================================
    // Profile Management

    void setProfile(MotorProfile profile)
    {
        currentProfile = profile;
        currentConfig = getProfileConfig(profile);
        applyConfigToTouchSystem();
        sendChangeMessage();
    }

    MotorProfile getCurrentProfile() const { return currentProfile; }
    const MotorProfileConfig& getCurrentConfig() const { return currentConfig; }

    MotorProfileConfig getProfileConfig(MotorProfile profile) const
    {
        switch (profile)
        {
            case MotorProfile::Normal:
                return createNormalProfile();

            case MotorProfile::Hyperactive:
                return createHyperactiveProfile();

            case MotorProfile::HighEnergy:
                return createHighEnergyProfile();

            case MotorProfile::Erratic:
                return createErraticProfile();

            case MotorProfile::Relaxed:
                return createRelaxedProfile();

            case MotorProfile::Dissociated:
                return createDissociatedProfile();

            case MotorProfile::HeavyHands:
                return createHeavyHandsProfile();

            case MotorProfile::AutoPilot:
                return createAutoPilotProfile();

            case MotorProfile::PerformanceMode:
                return createPerformanceModeProfile();

            default:
                return createNormalProfile();
        }
    }

    //==========================================================================
    // Custom Profile

    void setCustomConfig(const MotorProfileConfig& config)
    {
        currentProfile = MotorProfile::Normal;  // Mark as custom
        currentConfig = config;
        applyConfigToTouchSystem();
        sendChangeMessage();
    }

    //==========================================================================
    // Quick Adjustments

    void increaseTremorFilter()
    {
        currentConfig.tremorFilterStrength = juce::jmin(1.0f,
            currentConfig.tremorFilterStrength + 0.1f);
        applyConfigToTouchSystem();
        sendChangeMessage();
    }

    void decreaseTremorFilter()
    {
        currentConfig.tremorFilterStrength = juce::jmax(0.0f,
            currentConfig.tremorFilterStrength - 0.1f);
        applyConfigToTouchSystem();
        sendChangeMessage();
    }

    void increaseTargetSize()
    {
        currentConfig.touchTargetScale = juce::jmin(3.0f,
            currentConfig.touchTargetScale + 0.25f);
        sendChangeMessage();
    }

    void decreaseTargetSize()
    {
        currentConfig.touchTargetScale = juce::jmax(0.5f,
            currentConfig.touchTargetScale - 0.25f);
        sendChangeMessage();
    }

    //==========================================================================
    // Auto-Detection (experimental)

    void enableAutoDetection(bool enable)
    {
        autoDetectionEnabled = enable;
    }

    void analyzeUserBehavior(float velocity, float jitter, float acceleration)
    {
        if (!autoDetectionEnabled) return;

        // Sammle Statistiken
        velocityHistory.push_back(velocity);
        jitterHistory.push_back(jitter);

        if (velocityHistory.size() > 100)
        {
            velocityHistory.erase(velocityHistory.begin());
            jitterHistory.erase(jitterHistory.begin());
        }

        // Analysiere nach genug Daten
        if (velocityHistory.size() >= 50)
        {
            suggestProfile();
        }
    }

private:
    AccessibilityTouchManager()
    {
        currentProfile = MotorProfile::Normal;
        currentConfig = createNormalProfile();
    }

    //==========================================================================
    // Profile Definitions

    MotorProfileConfig createNormalProfile() const
    {
        return {
            "Normal",
            "Standard touch settings",
            0.5f,   // tremorFilterStrength
            3.0f,   // jitterThreshold
            0.5f,   // fineAdjustSensitivity
            1.5f,   // fastMorphSensitivity
            1.0f,   // overallSensitivity
            0.3f,   // holdDelay
            0.5f,   // intentDetectionSpeed
            0.05f,  // debounceTime
            1.0f,   // touchTargetScale
            0.0f,   // magnetRadius
            5.0f,   // maxSlewRate
            false,  // aggressiveSmoothing
            0.7f,   // visualFeedbackIntensity
            false,  // showGuideLines
            false,  // highContrastMode
            5.0f,   // accidentalTouchThreshold
            false   // confirmLargeChanges
        };
    }

    MotorProfileConfig createHyperactiveProfile() const
    {
        return {
            "Hyperactive",
            "For fast, overshooting movements - extra smoothing & larger targets",
            0.85f,  // tremorFilterStrength - Sehr hohe Glättung
            8.0f,   // jitterThreshold - Toleranter
            0.25f,  // fineAdjustSensitivity - Reduziert
            1.0f,   // fastMorphSensitivity - Normal
            0.6f,   // overallSensitivity - Reduziert
            0.5f,   // holdDelay - Länger
            0.3f,   // intentDetectionSpeed - Langsamer
            0.15f,  // debounceTime - Länger
            1.5f,   // touchTargetScale - Größer
            15.0f,  // magnetRadius - Magnetische Ziele
            3.0f,   // maxSlewRate - Langsamer
            true,   // aggressiveSmoothing
            1.0f,   // visualFeedbackIntensity - Maximal
            true,   // showGuideLines
            false,  // highContrastMode
            10.0f,  // accidentalTouchThreshold - Mehr Bewegung nötig
            false   // confirmLargeChanges
        };
    }

    MotorProfileConfig createHighEnergyProfile() const
    {
        return {
            "High Energy",
            "Maximum tremor filtering for very shaky hands",
            0.95f,  // tremorFilterStrength - Maximum
            12.0f,  // jitterThreshold - Sehr tolerant
            0.15f,  // fineAdjustSensitivity - Stark reduziert
            0.8f,   // fastMorphSensitivity - Reduziert
            0.4f,   // overallSensitivity - Stark reduziert
            0.7f,   // holdDelay - Viel länger
            0.2f,   // intentDetectionSpeed - Sehr langsam
            0.2f,   // debounceTime - Lang
            2.0f,   // touchTargetScale - Doppelt so groß
            25.0f,  // magnetRadius - Starker Magnet
            2.0f,   // maxSlewRate - Sehr langsam
            true,   // aggressiveSmoothing
            1.0f,   // visualFeedbackIntensity
            true,   // showGuideLines
            true,   // highContrastMode
            15.0f,  // accidentalTouchThreshold
            true    // confirmLargeChanges
        };
    }

    MotorProfileConfig createErraticProfile() const
    {
        return {
            "Erratic",
            "For unpredictable, jumping movements - stabilization mode",
            0.9f,   // tremorFilterStrength
            15.0f,  // jitterThreshold - Sehr tolerant
            0.2f,   // fineAdjustSensitivity
            0.7f,   // fastMorphSensitivity
            0.5f,   // overallSensitivity
            0.8f,   // holdDelay - Lang
            0.25f,  // intentDetectionSpeed
            0.25f,  // debounceTime - Lang
            2.5f,   // touchTargetScale - Sehr groß
            30.0f,  // magnetRadius - Maximaler Magnet
            1.5f,   // maxSlewRate - Sehr begrenzt
            true,   // aggressiveSmoothing
            1.0f,   // visualFeedbackIntensity
            true,   // showGuideLines
            true,   // highContrastMode
            20.0f,  // accidentalTouchThreshold
            true    // confirmLargeChanges
        };
    }

    MotorProfileConfig createRelaxedProfile() const
    {
        return {
            "Relaxed",
            "For slow, relaxed movements - increased sensitivity",
            0.3f,   // tremorFilterStrength - Weniger Filterung
            2.0f,   // jitterThreshold
            0.8f,   // fineAdjustSensitivity - Erhöht
            2.5f,   // fastMorphSensitivity - Erhöht
            1.5f,   // overallSensitivity - Erhöht
            0.5f,   // holdDelay
            0.7f,   // intentDetectionSpeed - Schneller
            0.03f,  // debounceTime - Kurz
            1.3f,   // touchTargetScale - Etwas größer
            10.0f,  // magnetRadius
            8.0f,   // maxSlewRate - Schneller
            false,  // aggressiveSmoothing
            0.8f,   // visualFeedbackIntensity
            false,  // showGuideLines
            false,  // highContrastMode
            3.0f,   // accidentalTouchThreshold - Weniger nötig
            false   // confirmLargeChanges
        };
    }

    MotorProfileConfig createDissociatedProfile() const
    {
        return {
            "Dissociated",
            "For delayed, floating movements - predictive assistance",
            0.6f,   // tremorFilterStrength
            5.0f,   // jitterThreshold
            0.7f,   // fineAdjustSensitivity
            2.0f,   // fastMorphSensitivity
            1.8f,   // overallSensitivity - Erhöht wegen Trägheit
            1.0f,   // holdDelay - Sehr lang (verzögerte Reaktion)
            0.4f,   // intentDetectionSpeed
            0.1f,   // debounceTime
            1.8f,   // touchTargetScale - Größer
            20.0f,  // magnetRadius - Hilft bei "Schwimmen"
            4.0f,   // maxSlewRate
            true,   // aggressiveSmoothing - Hilft bei verzögerter Wahrnehmung
            1.0f,   // visualFeedbackIntensity - Maximum für bessere Orientierung
            true,   // showGuideLines - Hilft bei Orientierung
            true,   // highContrastMode - Bessere Sichtbarkeit
            5.0f,   // accidentalTouchThreshold
            false   // confirmLargeChanges
        };
    }

    MotorProfileConfig createHeavyHandsProfile() const
    {
        return {
            "Heavy Hands",
            "For sluggish, heavy movements - reduced inertia",
            0.4f,   // tremorFilterStrength
            4.0f,   // jitterThreshold
            0.9f,   // fineAdjustSensitivity - Hoch
            3.0f,   // fastMorphSensitivity - Hoch
            2.0f,   // overallSensitivity - Doppelt
            0.6f,   // holdDelay
            0.6f,   // intentDetectionSpeed
            0.05f,  // debounceTime
            1.5f,   // touchTargetScale
            15.0f,  // magnetRadius
            10.0f,  // maxSlewRate - Schnell
            false,  // aggressiveSmoothing
            0.9f,   // visualFeedbackIntensity
            false,  // showGuideLines
            false,  // highContrastMode
            8.0f,   // accidentalTouchThreshold
            false   // confirmLargeChanges
        };
    }

    MotorProfileConfig createAutoPilotProfile() const
    {
        return {
            "AutoPilot",
            "Maximum stabilization - the UI does the work",
            0.98f,  // tremorFilterStrength - Maximum
            20.0f,  // jitterThreshold
            0.1f,   // fineAdjustSensitivity - Minimal
            0.5f,   // fastMorphSensitivity - Reduziert
            0.3f,   // overallSensitivity - Stark reduziert
            1.5f,   // holdDelay - Sehr lang
            0.15f,  // intentDetectionSpeed - Sehr langsam
            0.3f,   // debounceTime - Lang
            3.0f,   // touchTargetScale - 3x Größe
            50.0f,  // magnetRadius - Maximaler Magnet
            1.0f,   // maxSlewRate - Sehr langsam
            true,   // aggressiveSmoothing
            1.0f,   // visualFeedbackIntensity
            true,   // showGuideLines
            true,   // highContrastMode
            25.0f,  // accidentalTouchThreshold
            true    // confirmLargeChanges
        };
    }

    MotorProfileConfig createPerformanceModeProfile() const
    {
        return {
            "Performance Mode",
            "Large targets, forgiving detection - for live performance",
            0.7f,   // tremorFilterStrength
            6.0f,   // jitterThreshold
            0.4f,   // fineAdjustSensitivity
            1.8f,   // fastMorphSensitivity
            1.2f,   // overallSensitivity
            0.4f,   // holdDelay
            0.5f,   // intentDetectionSpeed
            0.1f,   // debounceTime
            2.0f,   // touchTargetScale - Große Ziele
            20.0f,  // magnetRadius
            4.0f,   // maxSlewRate
            true,   // aggressiveSmoothing
            1.0f,   // visualFeedbackIntensity - Maximum
            true,   // showGuideLines
            true,   // highContrastMode - Bessere Sichtbarkeit in Clubs
            8.0f,   // accidentalTouchThreshold
            false   // confirmLargeChanges - Schnelle Aktionen
        };
    }

    //==========================================================================

    void applyConfigToTouchSystem()
    {
        TouchSettingsManager::Settings settings;

        settings.tremorFilterStrength = currentConfig.tremorFilterStrength;
        settings.intentDetectionSpeed = currentConfig.intentDetectionSpeed;
        settings.fineAdjustSensitivity = currentConfig.fineAdjustSensitivity;
        settings.fastMorphSensitivity = currentConfig.fastMorphSensitivity;
        settings.maxParameterSlewRate = currentConfig.maxSlewRate;
        settings.touchHoldDelay = currentConfig.holdDelay;

        settings.autoIntentDetection = true;
        settings.tremorFilterEnabled = currentConfig.tremorFilterStrength > 0.1f;
        settings.phaseJumpPrevention = currentConfig.aggressiveSmoothing;
        settings.extraLargeTouchTargets = currentConfig.touchTargetScale > 1.5f;
        settings.fingerSizeCalibration = currentConfig.touchTargetScale;

        TouchSettingsManager::getInstance().updateSettings(settings);
    }

    void suggestProfile()
    {
        if (velocityHistory.empty() || jitterHistory.empty()) return;

        // Berechne Durchschnitte
        float avgVelocity = 0.0f;
        float avgJitter = 0.0f;

        for (auto v : velocityHistory) avgVelocity += v;
        for (auto j : jitterHistory) avgJitter += j;

        avgVelocity /= velocityHistory.size();
        avgJitter /= jitterHistory.size();

        // Profil-Vorschlag basierend auf Analyse
        MotorProfile suggested = MotorProfile::Normal;

        if (avgJitter > 15.0f && avgVelocity > 300.0f)
        {
            suggested = MotorProfile::HighEnergy;
        }
        else if (avgJitter > 10.0f && avgVelocity > 200.0f)
        {
            suggested = MotorProfile::Hyperactive;
        }
        else if (avgJitter > 12.0f)
        {
            suggested = MotorProfile::Erratic;
        }
        else if (avgVelocity < 50.0f && avgJitter < 3.0f)
        {
            suggested = MotorProfile::Dissociated;
        }
        else if (avgVelocity < 80.0f)
        {
            suggested = MotorProfile::Relaxed;
        }

        if (suggested != currentProfile && onProfileSuggestion)
        {
            onProfileSuggestion(suggested);
        }
    }

    //==========================================================================

    MotorProfile currentProfile;
    MotorProfileConfig currentConfig;
    bool autoDetectionEnabled = false;

    std::vector<float> velocityHistory;
    std::vector<float> jitterHistory;

public:
    std::function<void(MotorProfile)> onProfileSuggestion;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AccessibilityTouchManager)
};

//==============================================================================
/**
 * @brief Profile Selector UI Component
 */
class ProfileSelectorPanel : public juce::Component,
                              public juce::ChangeListener
{
public:
    ProfileSelectorPanel()
    {
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Motor Profile", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(16.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colours::white);

        addAndMakeVisible(profileCombo);
        profileCombo.addItem("Normal", 1);
        profileCombo.addItem("Hyperactive", 2);
        profileCombo.addItem("High Energy", 3);
        profileCombo.addItem("Erratic", 4);
        profileCombo.addItem("Relaxed", 5);
        profileCombo.addItem("Dissociated", 6);
        profileCombo.addItem("Heavy Hands", 7);
        profileCombo.addItem("AutoPilot", 8);
        profileCombo.addItem("Performance Mode", 9);

        profileCombo.setSelectedId(1);
        profileCombo.onChange = [this]
        {
            int id = profileCombo.getSelectedId();
            if (id > 0)
            {
                AccessibilityTouchManager::getInstance().setProfile(
                    static_cast<MotorProfile>(id - 1));
            }
        };

        addAndMakeVisible(descriptionLabel);
        descriptionLabel.setFont(juce::Font(12.0f));
        descriptionLabel.setColour(juce::Label::textColourId, juce::Colours::grey);
        updateDescription();

        // Quick adjust buttons
        addAndMakeVisible(moreFilterBtn);
        moreFilterBtn.setButtonText("+ Filter");
        moreFilterBtn.onClick = []
        {
            AccessibilityTouchManager::getInstance().increaseTremorFilter();
        };

        addAndMakeVisible(lessFilterBtn);
        lessFilterBtn.setButtonText("- Filter");
        lessFilterBtn.onClick = []
        {
            AccessibilityTouchManager::getInstance().decreaseTremorFilter();
        };

        addAndMakeVisible(biggerBtn);
        biggerBtn.setButtonText("+ Size");
        biggerBtn.onClick = []
        {
            AccessibilityTouchManager::getInstance().increaseTargetSize();
        };

        addAndMakeVisible(smallerBtn);
        smallerBtn.setButtonText("- Size");
        smallerBtn.onClick = []
        {
            AccessibilityTouchManager::getInstance().decreaseTargetSize();
        };

        AccessibilityTouchManager::getInstance().addChangeListener(this);
    }

    ~ProfileSelectorPanel() override
    {
        AccessibilityTouchManager::getInstance().removeChangeListener(this);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);

        titleLabel.setBounds(bounds.removeFromTop(25));
        bounds.removeFromTop(5);

        profileCombo.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(5);

        descriptionLabel.setBounds(bounds.removeFromTop(40));
        bounds.removeFromTop(10);

        auto buttonRow = bounds.removeFromTop(35);
        int btnWidth = buttonRow.getWidth() / 4 - 5;

        lessFilterBtn.setBounds(buttonRow.removeFromLeft(btnWidth));
        buttonRow.removeFromLeft(5);
        moreFilterBtn.setBounds(buttonRow.removeFromLeft(btnWidth));
        buttonRow.removeFromLeft(5);
        smallerBtn.setBounds(buttonRow.removeFromLeft(btnWidth));
        buttonRow.removeFromLeft(5);
        biggerBtn.setBounds(buttonRow);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff1a1a2a));
        g.setColour(juce::Colour(0xff303045));
        g.drawRoundedRectangle(getLocalBounds().toFloat().reduced(2), 8, 1);
    }

    void changeListenerCallback(juce::ChangeBroadcaster*) override
    {
        updateDescription();
    }

private:
    void updateDescription()
    {
        auto& config = AccessibilityTouchManager::getInstance().getCurrentConfig();
        descriptionLabel.setText(config.description, juce::dontSendNotification);
    }

    juce::Label titleLabel;
    juce::ComboBox profileCombo;
    juce::Label descriptionLabel;
    juce::TextButton moreFilterBtn, lessFilterBtn, biggerBtn, smallerBtn;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ProfileSelectorPanel)
};

} // namespace Touch
} // namespace Echoel
