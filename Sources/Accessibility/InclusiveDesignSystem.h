#pragma once

#include <JuceHeader.h>

/**
 * InclusiveDesignSystem - Universal Accessibility for All Users
 *
 * MISSION: Music creation accessible to EVERYONE, regardless of ability
 *
 * ACCESSIBILITY FEATURES:
 * - Visual: Screen readers, high contrast, large text, color blind modes
 * - Motor: One-handed mode, eye tracking, voice control, switch access
 * - Auditory: Visual feedback, captions, haptic feedback
 * - Cognitive: Simplified UI, guided workflows, tooltips
 * - Custom: Fully customizable accessibility profiles
 *
 * COMPLIANCE:
 * - WCAG 2.1 AAA (Web Content Accessibility Guidelines)
 * - Section 508 (US Federal accessibility standards)
 * - EN 301 549 (European accessibility standard)
 * - ADA (Americans with Disabilities Act)
 *
 * Usage:
 * ```cpp
 * InclusiveDesignSystem accessibility;
 *
 * // Enable screen reader
 * accessibility.enableScreenReader(true);
 *
 * // High contrast mode
 * accessibility.setContrastMode(ContrastMode::High);
 *
 * // Voice control
 * accessibility.enableVoiceControl(true);
 *
 * // Create custom profile
 * auto profile = accessibility.createAccessibilityProfile("My Setup");
 * ```
 */

//==============================================================================
// Accessibility Modes
//==============================================================================

enum class AccessibilityMode
{
    None,                   // No accessibility features
    Visual,                 // Visual impairments
    Motor,                  // Motor/mobility impairments
    Auditory,               // Hearing impairments
    Cognitive,              // Cognitive/learning disabilities
    FullAccessibility       // All features enabled
};

enum class ContrastMode
{
    Standard,               // Normal contrast
    High,                   // High contrast (WCAG AAA)
    ExtraHigh,             // Maximum contrast
    Custom                  // User-defined
};

enum class TextSize
{
    Small,                  // 12pt
    Medium,                 // 14pt (default)
    Large,                  // 18pt
    ExtraLarge,            // 24pt
    Huge                    // 32pt
};

enum class ColorBlindMode
{
    None,
    Protanopia,            // Red-blind
    Deuteranopia,          // Green-blind
    Tritanopia,            // Blue-blind
    Monochromacy           // Complete color blindness
};

//==============================================================================
// Accessibility Profile
//==============================================================================

struct AccessibilityProfile
{
    juce::String name;
    juce::String description;

    // Visual
    bool screenReaderEnabled = false;
    bool highContrastMode = false;
    ContrastMode contrastLevel = ContrastMode::Standard;
    TextSize textSize = TextSize::Medium;
    ColorBlindMode colorBlindMode = ColorBlindMode::None;
    bool reduceMotion = false;
    bool increaseCursorSize = false;

    // Motor
    bool oneHandedMode = false;
    bool eyeTrackingEnabled = false;
    bool voiceControlEnabled = false;
    bool switchAccessEnabled = false;
    bool stickyKeysEnabled = false;
    bool slowKeysEnabled = false;
    int dwellTimeMs = 1000;            // For eye tracking

    // Auditory
    bool visualFeedback = true;
    bool captionsEnabled = false;
    bool hapticFeedbackEnabled = false;
    bool signLanguageVideo = false;

    // Cognitive
    bool simplifiedUI = false;
    bool guidedMode = false;
    bool enhancedTooltips = true;
    bool reduceClutter = false;
    bool stepByStepInstructions = false;

    // Input
    bool keyboardOnlyNavigation = false;
    bool largerClickTargets = false;
    int minimumTargetSize = 44;        // iOS HIG minimum

    // Timing
    bool extendedTimeouts = false;
    bool noAutoDismiss = false;

    // Feedback
    bool audioDescriptions = false;
    bool confirmActions = true;

    juce::String toJSON() const;
    static AccessibilityProfile fromJSON(const juce::String& json);
};

//==============================================================================
// Screen Reader Support
//==============================================================================

class ScreenReaderSupport
{
public:
    ScreenReaderSupport();

    /** Enable screen reader */
    void enable(bool enabled);

    /** Is screen reader active? */
    bool isEnabled() const;

    /** Announce text */
    void announce(const juce::String& text, bool interrupt = false);

    /** Describe UI element */
    void describeElement(juce::Component* component);

    /** Set accessible name for component */
    void setAccessibleName(juce::Component* component, const juce::String& name);

    /** Set accessible description */
    void setAccessibleDescription(juce::Component* component, const juce::String& description);

    /** Set accessible role */
    void setAccessibleRole(juce::Component* component, const juce::String& role);

    std::function<void(const juce::String& text)> onAnnouncement;

private:
    bool enabled = false;
};

//==============================================================================
// Voice Control
//==============================================================================

class VoiceControlSystem
{
public:
    VoiceControlSystem();
    ~VoiceControlSystem();

    /** Enable voice control */
    void enable(bool enabled);

    /** Is voice control active? */
    bool isEnabled() const;

    /** Start listening */
    void startListening();

    /** Stop listening */
    void stopListening();

    /** Register voice command */
    void registerCommand(const juce::String& command, std::function<void()> action);

    /** Remove command */
    void unregisterCommand(const juce::String& command);

    /** Get all registered commands */
    juce::StringArray getRegisteredCommands() const;

    /** Process spoken text */
    void processSpokenText(const juce::String& text);

    /** Enable voice feedback */
    void enableVoiceFeedback(bool enabled);

    std::function<void(const juce::String& command)> onCommandRecognized;
    std::function<void(const juce::String& text)> onSpeechDetected;

private:
    bool enabled = false;
    bool listening = false;
    bool voiceFeedbackEnabled = true;

    std::map<juce::String, std::function<void()>> commands;
};

//==============================================================================
// Eye Tracking Support
//==============================================================================

class EyeTrackingSystem
{
public:
    EyeTrackingSystem();

    /** Enable eye tracking */
    void enable(bool enabled);

    /** Is eye tracking active? */
    bool isEnabled() const;

    /** Get current gaze position (normalized 0-1) */
    juce::Point<float> getGazePosition() const;

    /** Set dwell time (ms to activate) */
    void setDwellTime(int milliseconds);

    /** Get dwell time */
    int getDwellTime() const;

    /** Check if dwelling on component */
    bool isDwellingOn(juce::Component* component);

    /** Enable click on dwell */
    void enableClickOnDwell(bool enabled);

    std::function<void(const juce::Point<float>& position)> onGazeMove;
    std::function<void(juce::Component* component)> onDwellActivate;

private:
    bool enabled = false;
    juce::Point<float> gazePosition;
    int dwellTimeMs = 1000;
    bool clickOnDwell = true;
};

//==============================================================================
// Keyboard Navigation
//==============================================================================

class KeyboardNavigationSystem
{
public:
    KeyboardNavigationSystem();

    /** Enable keyboard-only navigation */
    void enable(bool enabled);

    /** Is keyboard navigation active? */
    bool isEnabled() const;

    /** Set focus to component */
    void setFocus(juce::Component* component);

    /** Move focus to next component */
    void focusNext();

    /** Move focus to previous component */
    void focusPrevious();

    /** Activate focused component */
    void activateFocused();

    /** Show focus indicator */
    void showFocusIndicator(bool show);

    /** Set focus indicator color */
    void setFocusIndicatorColor(juce::Colour color);

    std::function<void(juce::Component* component)> onFocusChanged;

private:
    bool enabled = false;
    bool showIndicator = true;
    juce::Colour focusColor = juce::Colours::blue;
    juce::Component* focusedComponent = nullptr;
};

//==============================================================================
// InclusiveDesignSystem - Main Class
//==============================================================================

class InclusiveDesignSystem
{
public:
    InclusiveDesignSystem();
    ~InclusiveDesignSystem();

    //==========================================================================
    // Accessibility Mode
    //==========================================================================

    /** Set accessibility mode */
    void setAccessibilityMode(AccessibilityMode mode);

    /** Get current accessibility mode */
    AccessibilityMode getAccessibilityMode() const;

    /** Enable/disable all accessibility */
    void enableAccessibility(bool enable);

    /** Is accessibility active? */
    bool isAccessibilityActive() const;

    //==========================================================================
    // Profile Management
    //==========================================================================

    /** Load accessibility profile */
    bool loadProfile(const juce::String& name);

    /** Save current settings as profile */
    bool saveProfile(const juce::String& name);

    /** Get current profile */
    AccessibilityProfile getCurrentProfile() const;

    /** Set profile */
    void setProfile(const AccessibilityProfile& profile);

    /** Get available profiles */
    juce::StringArray getAvailableProfiles() const;

    /** Delete profile */
    bool deleteProfile(const juce::String& name);

    //==========================================================================
    // Screen Reader
    //==========================================================================

    /** Enable screen reader */
    void enableScreenReader(bool enable);

    /** Is screen reader enabled? */
    bool isScreenReaderEnabled() const;

    /** Announce to screen reader */
    void announce(const juce::String& text, bool interrupt = false);

    /** Make component accessible */
    void makeAccessible(juce::Component* component, const juce::String& name, const juce::String& description);

    //==========================================================================
    // Visual Accessibility
    //==========================================================================

    /** Set contrast mode */
    void setContrastMode(ContrastMode mode);

    /** Get contrast mode */
    ContrastMode getContrastMode() const;

    /** Set text size */
    void setTextSize(TextSize size);

    /** Get text size multiplier */
    float getTextSizeMultiplier() const;

    /** Set color blind mode */
    void setColorBlindMode(ColorBlindMode mode);

    /** Transform color for color blind mode */
    juce::Colour transformColorForAccessibility(const juce::Colour& color) const;

    /** Enable reduce motion */
    void enableReduceMotion(bool enable);

    /** Should reduce motion? */
    bool shouldReduceMotion() const;

    //==========================================================================
    // Motor Accessibility
    //==========================================================================

    /** Enable one-handed mode */
    void enableOneHandedMode(bool enable);

    /** Is one-handed mode active? */
    bool isOneHandedMode() const;

    /** Enable voice control */
    void enableVoiceControl(bool enable);

    /** Register voice command */
    void registerVoiceCommand(const juce::String& command, std::function<void()> action);

    /** Enable eye tracking */
    void enableEyeTracking(bool enable);

    /** Set dwell time for eye tracking */
    void setEyeTrackingDwellTime(int milliseconds);

    /** Enable switch access */
    void enableSwitchAccess(bool enable);

    //==========================================================================
    // Auditory Accessibility
    //==========================================================================

    /** Enable visual feedback */
    void enableVisualFeedback(bool enable);

    /** Enable captions */
    void enableCaptions(bool enable);

    /** Add caption */
    void addCaption(const juce::String& text);

    /** Enable haptic feedback */
    void enableHapticFeedback(bool enable);

    /** Trigger haptic */
    void triggerHaptic(const juce::String& pattern);

    //==========================================================================
    // Cognitive Accessibility
    //==========================================================================

    /** Enable simplified UI */
    void enableSimplifiedUI(bool enable);

    /** Is simplified UI active? */
    bool isSimplifiedUIActive() const;

    /** Enable guided mode */
    void enableGuidedMode(bool enable);

    /** Show step-by-step instructions */
    void showInstructions(const juce::String& step);

    /** Enable enhanced tooltips */
    void enableEnhancedTooltips(bool enable);

    //==========================================================================
    // Keyboard Navigation
    //==========================================================================

    /** Enable keyboard-only navigation */
    void enableKeyboardNavigation(bool enable);

    /** Focus next element */
    void focusNext();

    /** Focus previous element */
    void focusPrevious();

    /** Activate focused element */
    void activateFocused();

    //==========================================================================
    // UI Adaptation
    //==========================================================================

    /** Get minimum touch target size */
    int getMinimumTouchTargetSize() const;

    /** Should use large click targets? */
    bool shouldUseLargeTargets() const;

    /** Get UI spacing multiplier */
    float getSpacingMultiplier() const;

    /** Get contrast ratio requirement */
    float getRequiredContrastRatio() const;

    //==========================================================================
    // Compliance
    //==========================================================================

    /** Check WCAG compliance level */
    juce::String getWCAGComplianceLevel() const;

    /** Generate accessibility report */
    juce::String generateAccessibilityReport() const;

    /** Check component accessibility */
    bool checkComponentAccessibility(juce::Component* component) const;

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(AccessibilityMode mode)> onAccessibilityModeChanged;
    std::function<void(const juce::String& announcement)> onAnnouncement;
    std::function<void(const juce::String& command)> onVoiceCommand;
    std::function<void(juce::Component* component)> onFocusChanged;

private:
    AccessibilityProfile currentProfile;
    AccessibilityMode currentMode = AccessibilityMode::None;

    ScreenReaderSupport screenReader;
    VoiceControlSystem voiceControl;
    EyeTrackingSystem eyeTracking;
    KeyboardNavigationSystem keyboardNav;

    bool accessibilityEnabled = false;

    void applyProfile(const AccessibilityProfile& profile);
    void loadSystemAccessibilitySettings();

    juce::File getProfilesDirectory() const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(InclusiveDesignSystem)
};
