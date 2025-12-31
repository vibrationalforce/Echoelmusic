#pragma once

#include <JuceHeader.h>

namespace Echoel {

//==============================================================================
/**
 * @brief Fair & Sustainable Design System
 *
 * DESIGN-PHILOSOPHIE:
 * "Respektvolle Software - für Mensch und Umwelt"
 *
 * PSYCHOLOGISCH FAIR:
 * - Keine Dark Patterns (keine Suchtmechanismen)
 * - Beruhigende Farbpaletten
 * - Reduzierte kognitive Belastung
 * - Respektiert Aufmerksamkeit des Users
 * - Keine künstliche Dringlichkeit
 *
 * ENERGIESPAREND:
 * - Adaptive Framerate (reduziert wenn inaktiv)
 * - Effiziente Repaint-Strategien
 * - Battery-Saver Mode
 * - Minimale GPU/CPU-Nutzung
 * - Dark Mode = weniger Stromverbrauch (OLED)
 */

//==============================================================================
/**
 * @brief Energy Efficiency Manager
 */
class EnergyEfficiencyManager : public juce::Timer
{
public:
    static EnergyEfficiencyManager& getInstance()
    {
        static EnergyEfficiencyManager instance;
        return instance;
    }

    //==========================================================================
    enum class PowerMode
    {
        HighPerformance,   // 60 FPS, alle Effekte
        Balanced,          // 30 FPS, reduzierte Effekte
        PowerSaver,        // 15 FPS, minimale Effekte
        UltraSaver         // 5 FPS, nur essenzielle Updates
    };

    struct EnergyStats
    {
        float cpuUsage = 0.0f;
        float gpuUsage = 0.0f;
        float batteryLevel = 1.0f;
        bool isOnBattery = false;
        int activeAnimations = 0;
        int repaintsPerSecond = 0;
    };

    //==========================================================================

    void setPowerMode(PowerMode mode)
    {
        currentMode = mode;
        applyPowerMode();
    }

    PowerMode getPowerMode() const { return currentMode; }

    void setAutoPowerManagement(bool enable)
    {
        autoPowerManagement = enable;
        if (enable)
            startTimer(5000);  // Check every 5 seconds
        else
            stopTimer();
    }

    //==========================================================================
    // Framerate Management

    int getTargetFrameRate() const
    {
        switch (currentMode)
        {
            case PowerMode::HighPerformance: return 60;
            case PowerMode::Balanced: return 30;
            case PowerMode::PowerSaver: return 15;
            case PowerMode::UltraSaver: return 5;
            default: return 30;
        }
    }

    bool shouldSkipFrame() const
    {
        // Skip frames based on power mode
        frameCounter++;
        int skipRate = 1;

        switch (currentMode)
        {
            case PowerMode::HighPerformance: skipRate = 1; break;
            case PowerMode::Balanced: skipRate = 2; break;
            case PowerMode::PowerSaver: skipRate = 4; break;
            case PowerMode::UltraSaver: skipRate = 12; break;
        }

        return (frameCounter % skipRate) != 0;
    }

    //==========================================================================
    // Animation Budget

    bool canStartAnimation() const
    {
        int maxAnimations = 10;

        switch (currentMode)
        {
            case PowerMode::HighPerformance: maxAnimations = 20; break;
            case PowerMode::Balanced: maxAnimations = 10; break;
            case PowerMode::PowerSaver: maxAnimations = 3; break;
            case PowerMode::UltraSaver: maxAnimations = 0; break;
        }

        return stats.activeAnimations < maxAnimations;
    }

    void registerAnimation() { stats.activeAnimations++; }
    void unregisterAnimation() { stats.activeAnimations = juce::jmax(0, stats.activeAnimations - 1); }

    //==========================================================================
    // Visual Quality

    bool shouldUseSimplifiedRendering() const
    {
        return currentMode >= PowerMode::PowerSaver;
    }

    bool shouldDisableShadows() const
    {
        return currentMode >= PowerMode::Balanced;
    }

    bool shouldDisableBlur() const
    {
        return currentMode >= PowerMode::PowerSaver;
    }

    bool shouldDisableGradients() const
    {
        return currentMode >= PowerMode::UltraSaver;
    }

    float getAnimationSpeed() const
    {
        switch (currentMode)
        {
            case PowerMode::HighPerformance: return 1.0f;
            case PowerMode::Balanced: return 0.8f;
            case PowerMode::PowerSaver: return 0.5f;
            case PowerMode::UltraSaver: return 0.0f;  // Instant transitions
            default: return 1.0f;
        }
    }

    //==========================================================================

    const EnergyStats& getStats() const { return stats; }

private:
    EnergyEfficiencyManager()
    {
        currentMode = PowerMode::Balanced;
    }

    void timerCallback() override
    {
        if (!autoPowerManagement) return;

        updateStats();

        // Auto-adjust power mode based on conditions
        if (stats.isOnBattery)
        {
            if (stats.batteryLevel < 0.1f)
                setPowerMode(PowerMode::UltraSaver);
            else if (stats.batteryLevel < 0.3f)
                setPowerMode(PowerMode::PowerSaver);
            else if (stats.batteryLevel < 0.5f)
                setPowerMode(PowerMode::Balanced);
        }
        else
        {
            // On AC power - check CPU usage
            if (stats.cpuUsage > 0.8f)
                setPowerMode(PowerMode::Balanced);
            else
                setPowerMode(PowerMode::HighPerformance);
        }
    }

    void updateStats()
    {
        // Platform-specific battery check would go here
        #if JUCE_IOS || JUCE_ANDROID
            // Mobile platforms have battery APIs
            stats.isOnBattery = true;
            stats.batteryLevel = 0.8f;  // Would call platform API
        #else
            // Desktop - assume AC power
            stats.isOnBattery = false;
            stats.batteryLevel = 1.0f;
        #endif
    }

    void applyPowerMode()
    {
        // Notify components to update their rendering
    }

    PowerMode currentMode = PowerMode::Balanced;
    bool autoPowerManagement = true;
    mutable int frameCounter = 0;
    EnergyStats stats;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EnergyEfficiencyManager)
};

//==============================================================================
/**
 * @brief Psychological Wellness Color System
 *
 * Farben basierend auf Farbpsychologie:
 * - Beruhigende Töne für Hauptinteraktion
 * - Warme Farben für positive Aktionen
 * - Sanfte Kontraste (nicht grell)
 * - Zirkadiane Anpassung (warmer am Abend)
 */
class WellnessColorSystem
{
public:
    static WellnessColorSystem& getInstance()
    {
        static WellnessColorSystem instance;
        return instance;
    }

    //==========================================================================
    enum class ColorMood
    {
        Calm,          // Beruhigend - Blau/Grün-Töne
        Focused,       // Konzentriert - Neutrale Töne
        Energetic,     // Energetisch - Warme Töne (sparsam verwenden)
        Night          // Nachtmodus - Sehr gedämpft, warm
    };

    struct WellnessPalette
    {
        juce::Colour background;
        juce::Colour backgroundAlt;
        juce::Colour surface;
        juce::Colour primary;
        juce::Colour secondary;
        juce::Colour accent;
        juce::Colour text;
        juce::Colour textSecondary;
        juce::Colour success;
        juce::Colour warning;
        juce::Colour error;
    };

    //==========================================================================

    void setMood(ColorMood mood)
    {
        currentMood = mood;
        currentPalette = getPaletteForMood(mood);
    }

    void enableCircadianRhythm(bool enable)
    {
        circadianEnabled = enable;
        if (enable)
            updateCircadianColors();
    }

    const WellnessPalette& getPalette() const { return currentPalette; }

    //==========================================================================
    // Convenience accessors

    juce::Colour getBackground() const { return currentPalette.background; }
    juce::Colour getSurface() const { return currentPalette.surface; }
    juce::Colour getPrimary() const { return currentPalette.primary; }
    juce::Colour getSecondary() const { return currentPalette.secondary; }
    juce::Colour getAccent() const { return currentPalette.accent; }
    juce::Colour getText() const { return currentPalette.text; }

    //==========================================================================
    // OLED-optimized dark colors (true black = pixels off = saves energy)

    juce::Colour getOLEDBlack() const { return juce::Colour(0xff000000); }
    juce::Colour getOLEDDark() const { return juce::Colour(0xff0a0a0a); }

    bool isOLEDOptimized() const { return oledOptimized; }
    void setOLEDOptimized(bool enable) { oledOptimized = enable; }

private:
    WellnessColorSystem()
    {
        currentMood = ColorMood::Calm;
        currentPalette = getPaletteForMood(ColorMood::Calm);
    }

    WellnessPalette getPaletteForMood(ColorMood mood) const
    {
        switch (mood)
        {
            case ColorMood::Calm:
                return {
                    juce::Colour(0xff0d1117),  // background - sehr dunkel
                    juce::Colour(0xff161b22),  // backgroundAlt
                    juce::Colour(0xff21262d),  // surface
                    juce::Colour(0xff58a6ff),  // primary - sanftes Blau
                    juce::Colour(0xff388bfd),  // secondary
                    juce::Colour(0xff56d4dd),  // accent - beruhigendes Türkis
                    juce::Colour(0xffc9d1d9),  // text
                    juce::Colour(0xff8b949e),  // textSecondary
                    juce::Colour(0xff3fb950),  // success - sanftes Grün
                    juce::Colour(0xffd29922),  // warning - gedämpftes Orange
                    juce::Colour(0xfff85149)   // error - nicht zu grell
                };

            case ColorMood::Focused:
                return {
                    juce::Colour(0xff1a1a1a),  // Neutrales Dunkel
                    juce::Colour(0xff242424),
                    juce::Colour(0xff2d2d2d),
                    juce::Colour(0xff9ca3af),  // Neutrales Grau
                    juce::Colour(0xff6b7280),
                    juce::Colour(0xffa78bfa),  // Sanftes Violett
                    juce::Colour(0xfff3f4f6),
                    juce::Colour(0xff9ca3af),
                    juce::Colour(0xff34d399),
                    juce::Colour(0xfffbbf24),
                    juce::Colour(0xfff87171)
                };

            case ColorMood::Energetic:
                return {
                    juce::Colour(0xff1c1917),  // Warmes Dunkel
                    juce::Colour(0xff292524),
                    juce::Colour(0xff44403c),
                    juce::Colour(0xfffb923c),  // Warmes Orange
                    juce::Colour(0xfff97316),
                    juce::Colour(0xfffbbf24),  // Gold
                    juce::Colour(0xfffef3c7),
                    juce::Colour(0xffd6d3d1),
                    juce::Colour(0xff4ade80),
                    juce::Colour(0xfffacc15),
                    juce::Colour(0xffef4444)
                };

            case ColorMood::Night:
                return {
                    juce::Colour(0xff000000),  // True Black (OLED)
                    juce::Colour(0xff0a0a0a),
                    juce::Colour(0xff141414),
                    juce::Colour(0xffff9f7a),  // Warmes gedämpftes Orange
                    juce::Colour(0xffcc7a5c),
                    juce::Colour(0xffff8866),  // Sehr warm
                    juce::Colour(0xffa0a0a0),  // Gedämpfter Text
                    juce::Colour(0xff707070),
                    juce::Colour(0xff66aa66),  // Gedämpft
                    juce::Colour(0xffaa8844),
                    juce::Colour(0xffaa5555)
                };

            default:
                return getPaletteForMood(ColorMood::Calm);
        }
    }

    void updateCircadianColors()
    {
        if (!circadianEnabled) return;

        auto now = juce::Time::getCurrentTime();
        int hour = now.getHours();

        // Abends (20-6 Uhr): Nachtmodus
        if (hour >= 20 || hour < 6)
            setMood(ColorMood::Night);
        // Morgens (6-10 Uhr): Energetisch
        else if (hour >= 6 && hour < 10)
            setMood(ColorMood::Energetic);
        // Tagsüber: Fokussiert
        else
            setMood(ColorMood::Focused);
    }

    ColorMood currentMood = ColorMood::Calm;
    WellnessPalette currentPalette;
    bool circadianEnabled = false;
    bool oledOptimized = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WellnessColorSystem)
};

//==============================================================================
/**
 * @brief Fair UX Design Principles
 *
 * Anti-Dark-Patterns:
 * - Keine falschen Countdown-Timer
 * - Keine Guilt-Trip-Nachrichten
 * - Keine versteckten Optionen
 * - Keine Suchtmechanismen (variable rewards)
 * - Klare, ehrliche Kommunikation
 */
class FairUXManager
{
public:
    static FairUXManager& getInstance()
    {
        static FairUXManager instance;
        return instance;
    }

    //==========================================================================
    // Attention Respect

    struct AttentionBudget
    {
        int notificationsShown = 0;
        int maxNotificationsPerHour = 3;
        double lastNotificationTime = 0.0;
        double minTimeBetweenNotifications = 300.0;  // 5 Minuten
    };

    bool canShowNotification()
    {
        double now = juce::Time::getMillisecondCounterHiRes() / 1000.0;

        // Respektiere Mindestabstand
        if (now - attentionBudget.lastNotificationTime < attentionBudget.minTimeBetweenNotifications)
            return false;

        // Respektiere Stundenlimit
        if (attentionBudget.notificationsShown >= attentionBudget.maxNotificationsPerHour)
            return false;

        return true;
    }

    void registerNotification()
    {
        attentionBudget.notificationsShown++;
        attentionBudget.lastNotificationTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
    }

    //==========================================================================
    // Break Reminders (opt-in only)

    void enableBreakReminders(bool enable, int intervalMinutes = 60)
    {
        breakRemindersEnabled = enable;
        breakIntervalMinutes = intervalMinutes;
    }

    bool shouldSuggestBreak() const
    {
        if (!breakRemindersEnabled) return false;

        double now = juce::Time::getMillisecondCounterHiRes() / 1000.0;
        double sessionDuration = now - sessionStartTime;

        return sessionDuration > (breakIntervalMinutes * 60.0) && !breakSuggested;
    }

    void markBreakSuggested() { breakSuggested = true; }
    void resetBreakTimer()
    {
        sessionStartTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
        breakSuggested = false;
    }

    //==========================================================================
    // Usage Stats (transparent to user)

    struct UsageStats
    {
        double totalSessionTime = 0.0;
        int controlsInteracted = 0;
        int undoCount = 0;
        int redoCount = 0;
    };

    void logInteraction() { usageStats.controlsInteracted++; }
    void logUndo() { usageStats.undoCount++; }
    void logRedo() { usageStats.redoCount++; }

    const UsageStats& getUsageStats() const { return usageStats; }

    // User can always see their stats
    juce::String getUsageSummary() const
    {
        auto duration = juce::Time::getMillisecondCounterHiRes() / 1000.0 - sessionStartTime;
        int minutes = static_cast<int>(duration / 60.0);

        return "Session: " + juce::String(minutes) + " min, " +
               juce::String(usageStats.controlsInteracted) + " interactions";
    }

    //==========================================================================
    // Cognitive Load Reduction

    bool isSimplifiedModeEnabled() const { return simplifiedMode; }
    void setSimplifiedMode(bool enable) { simplifiedMode = enable; }

    int getMaxVisibleOptions() const
    {
        return simplifiedMode ? 5 : 15;
    }

    bool shouldHideAdvancedOption() const
    {
        return simplifiedMode;
    }

private:
    FairUXManager()
    {
        sessionStartTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
    }

    AttentionBudget attentionBudget;
    UsageStats usageStats;

    double sessionStartTime = 0.0;
    bool breakRemindersEnabled = false;
    int breakIntervalMinutes = 60;
    bool breakSuggested = false;
    bool simplifiedMode = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FairUXManager)
};

//==============================================================================
/**
 * @brief Efficient Repaint Manager
 *
 * Vermeidet unnötige Repaints durch:
 * - Dirty-Region-Tracking
 * - Repaint-Coalescing
 * - Visibility-Culling
 */
class EfficientRepaintManager
{
public:
    static EfficientRepaintManager& getInstance()
    {
        static EfficientRepaintManager instance;
        return instance;
    }

    // Request repaint with dirty region
    void requestRepaint(juce::Component* component, const juce::Rectangle<int>& dirtyRegion)
    {
        if (!component || !component->isVisible()) return;

        // Coalesce nearby repaints
        auto& pending = pendingRepaints[component];

        if (pending.isEmpty())
            pending = dirtyRegion;
        else
            pending = pending.getUnion(dirtyRegion);
    }

    // Flush pending repaints
    void flushRepaints()
    {
        for (auto& pair : pendingRepaints)
        {
            if (pair.first && !pair.second.isEmpty())
            {
                pair.first->repaint(pair.second);
            }
        }
        pendingRepaints.clear();
    }

    // Check if component needs repaint
    bool needsRepaint(juce::Component* component) const
    {
        auto it = pendingRepaints.find(component);
        return it != pendingRepaints.end() && !it->second.isEmpty();
    }

private:
    EfficientRepaintManager() = default;

    std::map<juce::Component*, juce::Rectangle<int>> pendingRepaints;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EfficientRepaintManager)
};

//==============================================================================
/**
 * @brief Sustainable UI Component Base
 *
 * Basisklasse für energieeffiziente, psychologisch faire Komponenten
 */
class SustainableComponent : public juce::Component,
                              private juce::Timer
{
public:
    SustainableComponent()
    {
        // Start with balanced refresh rate
        updateRefreshRate();
    }

    ~SustainableComponent() override
    {
        stopTimer();
    }

protected:
    // Override for custom painting (called at appropriate frame rate)
    virtual void paintSustainable(juce::Graphics& g) {}

    // Override for animation updates
    virtual void updateAnimation(float deltaTime) {}

    void paint(juce::Graphics& g) override
    {
        auto& energy = EnergyEfficiencyManager::getInstance();

        // Skip frame if energy saving
        if (energy.shouldSkipFrame() && !forceFullQuality)
            return;

        // Apply wellness colors
        auto& colors = WellnessColorSystem::getInstance();

        if (energy.shouldUseSimplifiedRendering())
        {
            paintSimplified(g);
        }
        else
        {
            paintSustainable(g);
        }
    }

    // Simplified painting for power-saving mode
    virtual void paintSimplified(juce::Graphics& g)
    {
        // Default: just fill with background
        auto& colors = WellnessColorSystem::getInstance();
        g.fillAll(colors.getBackground());
    }

    void startAnimating()
    {
        if (!EnergyEfficiencyManager::getInstance().canStartAnimation())
            return;

        EnergyEfficiencyManager::getInstance().registerAnimation();
        isAnimating = true;
        updateRefreshRate();
        startTimer(1000 / EnergyEfficiencyManager::getInstance().getTargetFrameRate());
    }

    void stopAnimating()
    {
        if (isAnimating)
        {
            EnergyEfficiencyManager::getInstance().unregisterAnimation();
            isAnimating = false;
            stopTimer();
        }
    }

    void setForceFullQuality(bool force) { forceFullQuality = force; }

private:
    void timerCallback() override
    {
        float deltaTime = 1.0f / EnergyEfficiencyManager::getInstance().getTargetFrameRate();
        deltaTime *= EnergyEfficiencyManager::getInstance().getAnimationSpeed();

        updateAnimation(deltaTime);
        repaint();
    }

    void updateRefreshRate()
    {
        int fps = EnergyEfficiencyManager::getInstance().getTargetFrameRate();
        if (isTimerRunning())
        {
            stopTimer();
            startTimer(1000 / fps);
        }
    }

    bool isAnimating = false;
    bool forceFullQuality = false;
};

} // namespace Echoel
