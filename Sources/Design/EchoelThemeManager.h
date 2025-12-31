#pragma once

/**
 * EchoelThemeManager.h - Dark/Light Theme System
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - ADAPTIVE THEMING
 * ============================================================================
 *
 *   THEMES:
 *     - Dark Mode (default): Neon on dark background
 *     - Light Mode: Soft pastels on light background
 *     - Auto Mode: Follows system preference
 *     - High Contrast: WCAG AAA accessibility mode
 *
 *   FEATURES:
 *     - Smooth theme transitions (300ms)
 *     - Per-component theme overrides
 *     - Custom theme creation
 *     - Theme persistence
 *     - System preference sync
 *
 * ============================================================================
 */

#include "EchoelDesignSystem.h"
#include <JuceHeader.h>
#include <string>
#include <map>
#include <functional>
#include <memory>

namespace Echoel::Design
{

//==============================================================================
// Theme Mode
//==============================================================================

enum class ThemeMode
{
    Dark,
    Light,
    Auto,
    HighContrast
};

//==============================================================================
// Color Scheme
//==============================================================================

struct ColorScheme
{
    // Backgrounds
    juce::Colour background;
    juce::Colour backgroundSecondary;
    juce::Colour backgroundTertiary;
    juce::Colour surface;
    juce::Colour surfaceElevated;

    // Text
    juce::Colour textPrimary;
    juce::Colour textSecondary;
    juce::Colour textDisabled;
    juce::Colour textInverse;

    // Accents (Echoel brand colors)
    juce::Colour accentPrimary;
    juce::Colour accentSecondary;
    juce::Colour accentTertiary;

    // Semantic
    juce::Colour success;
    juce::Colour warning;
    juce::Colour error;
    juce::Colour info;

    // Interactive
    juce::Colour buttonPrimary;
    juce::Colour buttonSecondary;
    juce::Colour buttonHover;
    juce::Colour buttonPressed;
    juce::Colour buttonDisabled;

    // Borders
    juce::Colour border;
    juce::Colour borderFocus;
    juce::Colour borderError;

    // Neon glow colors
    juce::Colour glowPink;
    juce::Colour glowCyan;
    juce::Colour glowPurple;
    juce::Colour glowGreen;

    // Bio-data colors
    juce::Colour bioCoherence;
    juce::Colour bioStress;
    juce::Colour bioNeutral;

    // Shadow colors
    juce::Colour shadowLight;
    juce::Colour shadowMedium;
    juce::Colour shadowDark;
};

//==============================================================================
// Theme Definition
//==============================================================================

struct Theme
{
    std::string name;
    ThemeMode mode;
    ColorScheme colors;
    float glowIntensity = 1.0f;
    float animationSpeed = 1.0f;
    bool reduceMotion = false;
    bool reduceTransparency = false;
};

//==============================================================================
// Built-in Themes
//==============================================================================

namespace Themes
{
    inline Theme dark()
    {
        Theme theme;
        theme.name = "Dark";
        theme.mode = ThemeMode::Dark;

        auto& c = theme.colors;

        // Backgrounds
        c.background = juce::Colour(0xFF0D0D1A);
        c.backgroundSecondary = juce::Colour(0xFF151528);
        c.backgroundTertiary = juce::Colour(0xFF1A1A2E);
        c.surface = juce::Colour(0xFF1E1E32);
        c.surfaceElevated = juce::Colour(0xFF252540);

        // Text
        c.textPrimary = juce::Colour(0xFFF0F0F0);
        c.textSecondary = juce::Colour(0xFFB0B0B0);
        c.textDisabled = juce::Colour(0xFF606060);
        c.textInverse = juce::Colour(0xFF0D0D1A);

        // Accents (Echoel neon)
        c.accentPrimary = juce::Colour(0xFFFF71CE);   // Neon Pink
        c.accentSecondary = juce::Colour(0xFF01CDFE); // Neon Cyan
        c.accentTertiary = juce::Colour(0xFFB967FF);  // Neon Purple

        // Semantic
        c.success = juce::Colour(0xFF00FF88);
        c.warning = juce::Colour(0xFFFFAA00);
        c.error = juce::Colour(0xFFFF4757);
        c.info = juce::Colour(0xFF00D9FF);

        // Interactive
        c.buttonPrimary = juce::Colour(0xFFFF71CE);
        c.buttonSecondary = juce::Colour(0xFF2A2A4A);
        c.buttonHover = juce::Colour(0xFFFF8FD8);
        c.buttonPressed = juce::Colour(0xFFE060B0);
        c.buttonDisabled = juce::Colour(0xFF404060);

        // Borders
        c.border = juce::Colour(0xFF3A3A5A);
        c.borderFocus = juce::Colour(0xFF01CDFE);
        c.borderError = juce::Colour(0xFFFF4757);

        // Glow
        c.glowPink = juce::Colour(0xFFFF71CE);
        c.glowCyan = juce::Colour(0xFF01CDFE);
        c.glowPurple = juce::Colour(0xFFB967FF);
        c.glowGreen = juce::Colour(0xFF00FF88);

        // Bio
        c.bioCoherence = juce::Colour(0xFF00FF88);
        c.bioStress = juce::Colour(0xFFFF4757);
        c.bioNeutral = juce::Colour(0xFFFFAA00);

        // Shadows
        c.shadowLight = juce::Colour(0x20000000);
        c.shadowMedium = juce::Colour(0x40000000);
        c.shadowDark = juce::Colour(0x60000000);

        return theme;
    }

    inline Theme light()
    {
        Theme theme;
        theme.name = "Light";
        theme.mode = ThemeMode::Light;

        auto& c = theme.colors;

        // Backgrounds
        c.background = juce::Colour(0xFFF5F5FA);
        c.backgroundSecondary = juce::Colour(0xFFEEEEF4);
        c.backgroundTertiary = juce::Colour(0xFFE8E8F0);
        c.surface = juce::Colour(0xFFFFFFFF);
        c.surfaceElevated = juce::Colour(0xFFFFFFFF);

        // Text
        c.textPrimary = juce::Colour(0xFF1A1A2E);
        c.textSecondary = juce::Colour(0xFF4A4A6A);
        c.textDisabled = juce::Colour(0xFF9A9AB0);
        c.textInverse = juce::Colour(0xFFFFFFFF);

        // Accents (muted for light mode)
        c.accentPrimary = juce::Colour(0xFFE060A0);   // Softer pink
        c.accentSecondary = juce::Colour(0xFF00A0C8); // Softer cyan
        c.accentTertiary = juce::Colour(0xFF9050D0);  // Softer purple

        // Semantic
        c.success = juce::Colour(0xFF00B060);
        c.warning = juce::Colour(0xFFD08000);
        c.error = juce::Colour(0xFFD02040);
        c.info = juce::Colour(0xFF0090C0);

        // Interactive
        c.buttonPrimary = juce::Colour(0xFFE060A0);
        c.buttonSecondary = juce::Colour(0xFFE8E8F0);
        c.buttonHover = juce::Colour(0xFFD050A0);
        c.buttonPressed = juce::Colour(0xFFC04090);
        c.buttonDisabled = juce::Colour(0xFFD0D0E0);

        // Borders
        c.border = juce::Colour(0xFFD0D0E0);
        c.borderFocus = juce::Colour(0xFF00A0C8);
        c.borderError = juce::Colour(0xFFD02040);

        // Glow (subtle for light mode)
        c.glowPink = juce::Colour(0xFFE060A0);
        c.glowCyan = juce::Colour(0xFF00A0C8);
        c.glowPurple = juce::Colour(0xFF9050D0);
        c.glowGreen = juce::Colour(0xFF00B060);

        // Bio
        c.bioCoherence = juce::Colour(0xFF00B060);
        c.bioStress = juce::Colour(0xFFD02040);
        c.bioNeutral = juce::Colour(0xFFD08000);

        // Shadows
        c.shadowLight = juce::Colour(0x10000000);
        c.shadowMedium = juce::Colour(0x20000000);
        c.shadowDark = juce::Colour(0x30000000);

        theme.glowIntensity = 0.5f;  // Reduced glow for light mode

        return theme;
    }

    inline Theme highContrast()
    {
        Theme theme;
        theme.name = "High Contrast";
        theme.mode = ThemeMode::HighContrast;

        auto& c = theme.colors;

        // Pure black/white backgrounds
        c.background = juce::Colour(0xFF000000);
        c.backgroundSecondary = juce::Colour(0xFF000000);
        c.backgroundTertiary = juce::Colour(0xFF111111);
        c.surface = juce::Colour(0xFF000000);
        c.surfaceElevated = juce::Colour(0xFF1A1A1A);

        // High contrast text
        c.textPrimary = juce::Colour(0xFFFFFFFF);
        c.textSecondary = juce::Colour(0xFFFFFFFF);
        c.textDisabled = juce::Colour(0xFF888888);
        c.textInverse = juce::Colour(0xFF000000);

        // Bright accents
        c.accentPrimary = juce::Colour(0xFFFFFF00);   // Yellow
        c.accentSecondary = juce::Colour(0xFF00FFFF); // Cyan
        c.accentTertiary = juce::Colour(0xFFFF00FF);  // Magenta

        // Semantic (bright)
        c.success = juce::Colour(0xFF00FF00);
        c.warning = juce::Colour(0xFFFFFF00);
        c.error = juce::Colour(0xFFFF0000);
        c.info = juce::Colour(0xFF00FFFF);

        // Interactive
        c.buttonPrimary = juce::Colour(0xFFFFFF00);
        c.buttonSecondary = juce::Colour(0xFF333333);
        c.buttonHover = juce::Colour(0xFFFFFFFF);
        c.buttonPressed = juce::Colour(0xFFCCCC00);
        c.buttonDisabled = juce::Colour(0xFF444444);

        // Borders (thick white)
        c.border = juce::Colour(0xFFFFFFFF);
        c.borderFocus = juce::Colour(0xFF00FFFF);
        c.borderError = juce::Colour(0xFFFF0000);

        // Glow (disabled)
        c.glowPink = juce::Colours::transparentBlack;
        c.glowCyan = juce::Colours::transparentBlack;
        c.glowPurple = juce::Colours::transparentBlack;
        c.glowGreen = juce::Colours::transparentBlack;

        // Bio
        c.bioCoherence = juce::Colour(0xFF00FF00);
        c.bioStress = juce::Colour(0xFFFF0000);
        c.bioNeutral = juce::Colour(0xFFFFFF00);

        // No shadows
        c.shadowLight = juce::Colours::transparentBlack;
        c.shadowMedium = juce::Colours::transparentBlack;
        c.shadowDark = juce::Colours::transparentBlack;

        theme.glowIntensity = 0.0f;
        theme.reduceMotion = true;
        theme.reduceTransparency = true;

        return theme;
    }
}

//==============================================================================
// Theme Manager (Singleton)
//==============================================================================

class EchoelThemeManager
{
public:
    using ThemeChangeCallback = std::function<void(const Theme&)>;

    static EchoelThemeManager& getInstance()
    {
        static EchoelThemeManager instance;
        return instance;
    }

    //==========================================================================
    // Theme Selection
    //==========================================================================

    void setTheme(ThemeMode mode)
    {
        currentMode_ = mode;

        switch (mode)
        {
            case ThemeMode::Dark:
                currentTheme_ = Themes::dark();
                break;
            case ThemeMode::Light:
                currentTheme_ = Themes::light();
                break;
            case ThemeMode::HighContrast:
                currentTheme_ = Themes::highContrast();
                break;
            case ThemeMode::Auto:
                currentTheme_ = isSystemDarkMode() ? Themes::dark() : Themes::light();
                break;
        }

        notifyThemeChange();
        saveThemePreference();
    }

    void setCustomTheme(const Theme& theme)
    {
        currentTheme_ = theme;
        currentMode_ = theme.mode;
        notifyThemeChange();
    }

    ThemeMode getThemeMode() const { return currentMode_; }
    const Theme& getCurrentTheme() const { return currentTheme_; }
    const ColorScheme& getColors() const { return currentTheme_.colors; }

    //==========================================================================
    // Convenience Color Access
    //==========================================================================

    juce::Colour background() const { return currentTheme_.colors.background; }
    juce::Colour surface() const { return currentTheme_.colors.surface; }
    juce::Colour textPrimary() const { return currentTheme_.colors.textPrimary; }
    juce::Colour textSecondary() const { return currentTheme_.colors.textSecondary; }
    juce::Colour accentPrimary() const { return currentTheme_.colors.accentPrimary; }
    juce::Colour accentSecondary() const { return currentTheme_.colors.accentSecondary; }
    juce::Colour success() const { return currentTheme_.colors.success; }
    juce::Colour warning() const { return currentTheme_.colors.warning; }
    juce::Colour error() const { return currentTheme_.colors.error; }

    //==========================================================================
    // Theme Properties
    //==========================================================================

    bool isDarkMode() const
    {
        return currentMode_ == ThemeMode::Dark ||
               (currentMode_ == ThemeMode::Auto && isSystemDarkMode());
    }

    float getGlowIntensity() const { return currentTheme_.glowIntensity; }
    bool shouldReduceMotion() const { return currentTheme_.reduceMotion || isSystemReduceMotion(); }
    bool shouldReduceTransparency() const { return currentTheme_.reduceTransparency; }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void onThemeChange(ThemeChangeCallback callback)
    {
        themeChangeCallbacks_.push_back(std::move(callback));
    }

    //==========================================================================
    // System Detection
    //==========================================================================

    static bool isSystemDarkMode()
    {
#if JUCE_MAC
        return juce::Desktop::getInstance().isDarkModeActive();
#elif JUCE_WINDOWS
        // Windows dark mode detection
        return juce::Desktop::getInstance().isDarkModeActive();
#else
        return true;  // Default to dark on other platforms
#endif
    }

    static bool isSystemReduceMotion()
    {
        // System accessibility preference
        return false;  // TODO: Implement platform-specific detection
    }

    //==========================================================================
    // Persistence
    //==========================================================================

    void loadThemePreference()
    {
        juce::PropertiesFile::Options options;
        options.applicationName = "Echoel";
        options.folderName = "Echoel";
        options.filenameSuffix = ".settings";

        juce::ApplicationProperties props;
        props.setStorageParameters(options);

        if (auto* settings = props.getUserSettings())
        {
            int mode = settings->getIntValue("themeMode", static_cast<int>(ThemeMode::Dark));
            setTheme(static_cast<ThemeMode>(mode));
        }
    }

    void saveThemePreference()
    {
        juce::PropertiesFile::Options options;
        options.applicationName = "Echoel";
        options.folderName = "Echoel";
        options.filenameSuffix = ".settings";

        juce::ApplicationProperties props;
        props.setStorageParameters(options);

        if (auto* settings = props.getUserSettings())
        {
            settings->setValue("themeMode", static_cast<int>(currentMode_));
            settings->saveIfNeeded();
        }
    }

    //==========================================================================
    // JUCE LookAndFeel Integration
    //==========================================================================

    void applyToLookAndFeel(juce::LookAndFeel& laf)
    {
        const auto& c = currentTheme_.colors;

        laf.setColour(juce::ResizableWindow::backgroundColourId, c.background);
        laf.setColour(juce::DocumentWindow::backgroundColourId, c.background);

        laf.setColour(juce::TextButton::buttonColourId, c.buttonSecondary);
        laf.setColour(juce::TextButton::buttonOnColourId, c.buttonPrimary);
        laf.setColour(juce::TextButton::textColourOffId, c.textPrimary);
        laf.setColour(juce::TextButton::textColourOnId, c.textInverse);

        laf.setColour(juce::Slider::backgroundColourId, c.surface);
        laf.setColour(juce::Slider::thumbColourId, c.accentPrimary);
        laf.setColour(juce::Slider::trackColourId, c.accentSecondary);

        laf.setColour(juce::Label::textColourId, c.textPrimary);
        laf.setColour(juce::Label::backgroundColourId, juce::Colours::transparentBlack);

        laf.setColour(juce::TextEditor::backgroundColourId, c.surface);
        laf.setColour(juce::TextEditor::textColourId, c.textPrimary);
        laf.setColour(juce::TextEditor::outlineColourId, c.border);
        laf.setColour(juce::TextEditor::focusedOutlineColourId, c.borderFocus);

        laf.setColour(juce::ComboBox::backgroundColourId, c.surface);
        laf.setColour(juce::ComboBox::textColourId, c.textPrimary);
        laf.setColour(juce::ComboBox::outlineColourId, c.border);

        laf.setColour(juce::PopupMenu::backgroundColourId, c.surfaceElevated);
        laf.setColour(juce::PopupMenu::textColourId, c.textPrimary);
        laf.setColour(juce::PopupMenu::highlightedBackgroundColourId, c.accentPrimary);
        laf.setColour(juce::PopupMenu::highlightedTextColourId, c.textInverse);

        laf.setColour(juce::ScrollBar::thumbColourId, c.accentSecondary.withAlpha(0.5f));
        laf.setColour(juce::ScrollBar::trackColourId, c.surface);
    }

private:
    EchoelThemeManager()
    {
        currentTheme_ = Themes::dark();
        currentMode_ = ThemeMode::Dark;
    }

    void notifyThemeChange()
    {
        for (const auto& callback : themeChangeCallbacks_)
        {
            callback(currentTheme_);
        }
    }

    Theme currentTheme_;
    ThemeMode currentMode_ = ThemeMode::Dark;
    std::vector<ThemeChangeCallback> themeChangeCallbacks_;
};

//==============================================================================
// Convenience Macros
//==============================================================================

#define ECHOEL_THEME Echoel::Design::EchoelThemeManager::getInstance()
#define ECHOEL_COLORS ECHOEL_THEME.getColors()

}  // namespace Echoel::Design
