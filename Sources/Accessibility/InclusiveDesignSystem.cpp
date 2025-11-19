#include "InclusiveDesignSystem.h"

//==============================================================================
// AccessibilityProfile Implementation
//==============================================================================

juce::String AccessibilityProfile::toJSON() const
{
    juce::DynamicObject::Ptr root = new juce::DynamicObject();

    root->setProperty("name", name);
    root->setProperty("description", description);

    // Visual
    root->setProperty("screenReaderEnabled", screenReaderEnabled);
    root->setProperty("highContrastMode", highContrastMode);
    root->setProperty("textSize", (int)textSize);
    root->setProperty("colorBlindMode", (int)colorBlindMode);
    root->setProperty("reduceMotion", reduceMotion);

    // Motor
    root->setProperty("oneHandedMode", oneHandedMode);
    root->setProperty("voiceControlEnabled", voiceControlEnabled);
    root->setProperty("eyeTrackingEnabled", eyeTrackingEnabled);

    // Auditory
    root->setProperty("visualFeedback", visualFeedback);
    root->setProperty("captionsEnabled", captionsEnabled);
    root->setProperty("hapticFeedbackEnabled", hapticFeedbackEnabled);

    // Cognitive
    root->setProperty("simplifiedUI", simplifiedUI);
    root->setProperty("guidedMode", guidedMode);

    return juce::JSON::toString(juce::var(root.get()), true);
}

AccessibilityProfile AccessibilityProfile::fromJSON(const juce::String& json)
{
    AccessibilityProfile profile;

    auto var = juce::JSON::parse(json);
    if (!var.isObject())
        return profile;

    auto obj = var.getDynamicObject();

    profile.name = obj->getProperty("name").toString();
    profile.description = obj->getProperty("description").toString();

    // Visual
    profile.screenReaderEnabled = obj->getProperty("screenReaderEnabled");
    profile.highContrastMode = obj->getProperty("highContrastMode");
    profile.textSize = (TextSize)(int)obj->getProperty("textSize");
    profile.colorBlindMode = (ColorBlindMode)(int)obj->getProperty("colorBlindMode");
    profile.reduceMotion = obj->getProperty("reduceMotion");

    // Motor
    profile.oneHandedMode = obj->getProperty("oneHandedMode");
    profile.voiceControlEnabled = obj->getProperty("voiceControlEnabled");
    profile.eyeTrackingEnabled = obj->getProperty("eyeTrackingEnabled");

    // Auditory
    profile.visualFeedback = obj->getProperty("visualFeedback");
    profile.captionsEnabled = obj->getProperty("captionsEnabled");
    profile.hapticFeedbackEnabled = obj->getProperty("hapticFeedbackEnabled");

    // Cognitive
    profile.simplifiedUI = obj->getProperty("simplifiedUI");
    profile.guidedMode = obj->getProperty("guidedMode");

    return profile;
}

//==============================================================================
// ScreenReaderSupport Implementation
//==============================================================================

ScreenReaderSupport::ScreenReaderSupport()
{
}

void ScreenReaderSupport::enable(bool enable)
{
    enabled = enable;
    DBG("Screen reader " + juce::String(enable ? "enabled" : "disabled"));
}

bool ScreenReaderSupport::isEnabled() const
{
    return enabled;
}

void ScreenReaderSupport::announce(const juce::String& text, bool interrupt)
{
    if (!enabled)
        return;

    DBG("Screen reader announcement: " + text);

    if (onAnnouncement)
        onAnnouncement(text);

    // Would integrate with system screen readers (VoiceOver, TalkBack, NVDA)
}

void ScreenReaderSupport::describeElement(juce::Component* component)
{
    if (!enabled || !component)
        return;

    juce::String description = component->getName();
    if (description.isEmpty())
        description = "Unnamed component";

    announce(description, false);
}

void ScreenReaderSupport::setAccessibleName(juce::Component* component, const juce::String& name)
{
    if (!component)
        return;

    component->setTitle(name);
    component->setDescription(name);
}

void ScreenReaderSupport::setAccessibleDescription(juce::Component* component, const juce::String& description)
{
    if (!component)
        return;

    component->setDescription(description);
}

void ScreenReaderSupport::setAccessibleRole(juce::Component* component, const juce::String& role)
{
    if (!component)
        return;

    // Would set ARIA role for component
    DBG("Setting accessible role: " + role + " for " + component->getName());
}

//==============================================================================
// VoiceControlSystem Implementation
//==============================================================================

VoiceControlSystem::VoiceControlSystem()
{
    // Register common commands
    registerCommand("play", []() { DBG("Voice: Play"); });
    registerCommand("stop", []() { DBG("Voice: Stop"); });
    registerCommand("record", []() { DBG("Voice: Record"); });
    registerCommand("save", []() { DBG("Voice: Save"); });
}

VoiceControlSystem::~VoiceControlSystem()
{
}

void VoiceControlSystem::enable(bool enable)
{
    enabled = enable;
    DBG("Voice control " + juce::String(enable ? "enabled" : "disabled"));
}

bool VoiceControlSystem::isEnabled() const
{
    return enabled;
}

void VoiceControlSystem::startListening()
{
    if (!enabled)
        return;

    listening = true;
    DBG("Voice control listening started");
}

void VoiceControlSystem::stopListening()
{
    listening = false;
    DBG("Voice control listening stopped");
}

void VoiceControlSystem::registerCommand(const juce::String& command, std::function<void()> action)
{
    commands[command.toLowerCase()] = action;
    DBG("Voice command registered: " + command);
}

void VoiceControlSystem::unregisterCommand(const juce::String& command)
{
    commands.erase(command.toLowerCase());
}

juce::StringArray VoiceControlSystem::getRegisteredCommands() const
{
    juce::StringArray commandList;

    for (const auto& pair : commands)
        commandList.add(pair.first);

    return commandList;
}

void VoiceControlSystem::processSpokenText(const juce::String& text)
{
    if (!enabled)
        return;

    DBG("Processing speech: " + text);

    auto lowercaseText = text.toLowerCase().trim();

    // Check for exact match
    auto it = commands.find(lowercaseText);
    if (it != commands.end())
    {
        if (onCommandRecognized)
            onCommandRecognized(lowercaseText);

        it->second();
        return;
    }

    // Check for partial match
    for (const auto& pair : commands)
    {
        if (lowercaseText.contains(pair.first))
        {
            if (onCommandRecognized)
                onCommandRecognized(pair.first);

            pair.second();
            return;
        }
    }

    DBG("Voice command not recognized: " + text);
}

void VoiceControlSystem::enableVoiceFeedback(bool enable)
{
    voiceFeedbackEnabled = enable;
}

//==============================================================================
// EyeTrackingSystem Implementation
//==============================================================================

EyeTrackingSystem::EyeTrackingSystem()
{
}

void EyeTrackingSystem::enable(bool enable)
{
    enabled = enable;
    DBG("Eye tracking " + juce::String(enable ? "enabled" : "disabled"));
}

bool EyeTrackingSystem::isEnabled() const
{
    return enabled;
}

juce::Point<float> EyeTrackingSystem::getGazePosition() const
{
    return gazePosition;
}

void EyeTrackingSystem::setDwellTime(int milliseconds)
{
    dwellTimeMs = milliseconds;
}

int EyeTrackingSystem::getDwellTime() const
{
    return dwellTimeMs;
}

bool EyeTrackingSystem::isDwellingOn(juce::Component* component)
{
    if (!enabled || !component)
        return false;

    // Would check if gaze has been on component for dwell time
    return false;  // Placeholder
}

void EyeTrackingSystem::enableClickOnDwell(bool enable)
{
    clickOnDwell = enable;
}

//==============================================================================
// KeyboardNavigationSystem Implementation
//==============================================================================

KeyboardNavigationSystem::KeyboardNavigationSystem()
{
}

void KeyboardNavigationSystem::enable(bool enable)
{
    enabled = enable;
    DBG("Keyboard navigation " + juce::String(enable ? "enabled" : "disabled"));
}

bool KeyboardNavigationSystem::isEnabled() const
{
    return enabled;
}

void KeyboardNavigationSystem::setFocus(juce::Component* component)
{
    if (!component)
        return;

    focusedComponent = component;
    component->grabKeyboardFocus();

    if (onFocusChanged)
        onFocusChanged(component);

    DBG("Focus set to: " + component->getName());
}

void KeyboardNavigationSystem::focusNext()
{
    if (!enabled || !focusedComponent)
        return;

    auto* next = focusedComponent->getNextKeyboardComponent(true);
    if (next)
        setFocus(next);
}

void KeyboardNavigationSystem::focusPrevious()
{
    if (!enabled || !focusedComponent)
        return;

    auto* prev = focusedComponent->getNextKeyboardComponent(false);
    if (prev)
        setFocus(prev);
}

void KeyboardNavigationSystem::activateFocused()
{
    if (!enabled || !focusedComponent)
        return;

    // Simulate click on focused component
    DBG("Activating focused component: " + focusedComponent->getName());
}

void KeyboardNavigationSystem::showFocusIndicator(bool show)
{
    showIndicator = show;
}

void KeyboardNavigationSystem::setFocusIndicatorColor(juce::Colour color)
{
    focusColor = color;
}

//==============================================================================
// InclusiveDesignSystem Implementation
//==============================================================================

InclusiveDesignSystem::InclusiveDesignSystem()
{
    DBG("InclusiveDesignSystem initialized - Accessibility for all");

    loadSystemAccessibilitySettings();
}

InclusiveDesignSystem::~InclusiveDesignSystem()
{
}

//==============================================================================
// Accessibility Mode
//==============================================================================

void InclusiveDesignSystem::setAccessibilityMode(AccessibilityMode mode)
{
    currentMode = mode;

    DBG("Accessibility mode: " + juce::String((int)mode));

    // Apply appropriate settings for each mode
    switch (mode)
    {
        case AccessibilityMode::Visual:
            enableScreenReader(true);
            setContrastMode(ContrastMode::High);
            setTextSize(TextSize::Large);
            break;

        case AccessibilityMode::Motor:
            enableVoiceControl(true);
            enableOneHandedMode(true);
            currentProfile.largerClickTargets = true;
            break;

        case AccessibilityMode::Auditory:
            enableVisualFeedback(true);
            enableCaptions(true);
            enableHapticFeedback(true);
            break;

        case AccessibilityMode::Cognitive:
            enableSimplifiedUI(true);
            enableGuidedMode(true);
            enableEnhancedTooltips(true);
            break;

        case AccessibilityMode::FullAccessibility:
            enableAccessibility(true);
            break;

        default:
            break;
    }

    if (onAccessibilityModeChanged)
        onAccessibilityModeChanged(mode);
}

AccessibilityMode InclusiveDesignSystem::getAccessibilityMode() const
{
    return currentMode;
}

void InclusiveDesignSystem::enableAccessibility(bool enable)
{
    accessibilityEnabled = enable;

    if (enable)
    {
        enableScreenReader(true);
        setContrastMode(ContrastMode::High);
        enableKeyboardNavigation(true);
    }

    DBG("Accessibility " + juce::String(enable ? "enabled" : "disabled"));
}

bool InclusiveDesignSystem::isAccessibilityActive() const
{
    return accessibilityEnabled;
}

//==============================================================================
// Profile Management
//==============================================================================

bool InclusiveDesignSystem::loadProfile(const juce::String& name)
{
    auto profileFile = getProfilesDirectory().getChildFile(name + ".json");

    if (!profileFile.existsAsFile())
        return false;

    auto jsonText = profileFile.loadFileAsString();
    auto profile = AccessibilityProfile::fromJSON(jsonText);

    setProfile(profile);

    DBG("Loaded accessibility profile: " + name);
    return true;
}

bool InclusiveDesignSystem::saveProfile(const juce::String& name)
{
    currentProfile.name = name;

    auto profilesDir = getProfilesDirectory();
    if (!profilesDir.exists())
        profilesDir.createDirectory();

    auto profileFile = profilesDir.getChildFile(name + ".json");
    auto json = currentProfile.toJSON();

    return profileFile.replaceWithText(json);
}

AccessibilityProfile InclusiveDesignSystem::getCurrentProfile() const
{
    return currentProfile;
}

void InclusiveDesignSystem::setProfile(const AccessibilityProfile& profile)
{
    currentProfile = profile;
    applyProfile(profile);
}

juce::StringArray InclusiveDesignSystem::getAvailableProfiles() const
{
    juce::StringArray profiles;

    auto profilesDir = getProfilesDirectory();
    if (profilesDir.exists())
    {
        auto files = profilesDir.findChildFiles(juce::File::findFiles, false, "*.json");

        for (const auto& file : files)
            profiles.add(file.getFileNameWithoutExtension());
    }

    return profiles;
}

bool InclusiveDesignSystem::deleteProfile(const juce::String& name)
{
    auto profileFile = getProfilesDirectory().getChildFile(name + ".json");
    return profileFile.deleteFile();
}

//==============================================================================
// Screen Reader
//==============================================================================

void InclusiveDesignSystem::enableScreenReader(bool enable)
{
    currentProfile.screenReaderEnabled = enable;
    screenReader.enable(enable);
}

bool InclusiveDesignSystem::isScreenReaderEnabled() const
{
    return screenReader.isEnabled();
}

void InclusiveDesignSystem::announce(const juce::String& text, bool interrupt)
{
    screenReader.announce(text, interrupt);

    if (onAnnouncement)
        onAnnouncement(text);
}

void InclusiveDesignSystem::makeAccessible(juce::Component* component, const juce::String& name, const juce::String& description)
{
    screenReader.setAccessibleName(component, name);
    screenReader.setAccessibleDescription(component, description);
}

//==============================================================================
// Visual Accessibility
//==============================================================================

void InclusiveDesignSystem::setContrastMode(ContrastMode mode)
{
    currentProfile.contrastLevel = mode;
    currentProfile.highContrastMode = (mode != ContrastMode::Standard);

    DBG("Contrast mode: " + juce::String((int)mode));
}

ContrastMode InclusiveDesignSystem::getContrastMode() const
{
    return currentProfile.contrastLevel;
}

void InclusiveDesignSystem::setTextSize(TextSize size)
{
    currentProfile.textSize = size;
}

float InclusiveDesignSystem::getTextSizeMultiplier() const
{
    switch (currentProfile.textSize)
    {
        case TextSize::Small:       return 0.85f;
        case TextSize::Medium:      return 1.0f;
        case TextSize::Large:       return 1.3f;
        case TextSize::ExtraLarge:  return 1.7f;
        case TextSize::Huge:        return 2.3f;
        default:                    return 1.0f;
    }
}

void InclusiveDesignSystem::setColorBlindMode(ColorBlindMode mode)
{
    currentProfile.colorBlindMode = mode;

    DBG("Color blind mode: " + juce::String((int)mode));
}

juce::Colour InclusiveDesignSystem::transformColorForAccessibility(const juce::Colour& color) const
{
    if (currentProfile.colorBlindMode == ColorBlindMode::None)
        return color;

    // Simplified color transformation
    // Real implementation would use proper color blind simulation algorithms

    switch (currentProfile.colorBlindMode)
    {
        case ColorBlindMode::Protanopia:  // Red-blind
            return juce::Colour(0, color.getGreen(), color.getBlue());

        case ColorBlindMode::Deuteranopia:  // Green-blind
            return juce::Colour(color.getRed(), 0, color.getBlue());

        case ColorBlindMode::Tritanopia:  // Blue-blind
            return juce::Colour(color.getRed(), color.getGreen(), 0);

        case ColorBlindMode::Monochromacy:  // Grayscale
            return juce::Colour::greyLevel(color.getBrightness());

        default:
            return color;
    }
}

void InclusiveDesignSystem::enableReduceMotion(bool enable)
{
    currentProfile.reduceMotion = enable;
}

bool InclusiveDesignSystem::shouldReduceMotion() const
{
    return currentProfile.reduceMotion;
}

//==============================================================================
// Motor Accessibility
//==============================================================================

void InclusiveDesignSystem::enableOneHandedMode(bool enable)
{
    currentProfile.oneHandedMode = enable;
    DBG("One-handed mode " + juce::String(enable ? "enabled" : "disabled"));
}

bool InclusiveDesignSystem::isOneHandedMode() const
{
    return currentProfile.oneHandedMode;
}

void InclusiveDesignSystem::enableVoiceControl(bool enable)
{
    currentProfile.voiceControlEnabled = enable;
    voiceControl.enable(enable);
}

void InclusiveDesignSystem::registerVoiceCommand(const juce::String& command, std::function<void()> action)
{
    voiceControl.registerCommand(command, action);
}

void InclusiveDesignSystem::enableEyeTracking(bool enable)
{
    currentProfile.eyeTrackingEnabled = enable;
    eyeTracking.enable(enable);
}

void InclusiveDesignSystem::setEyeTrackingDwellTime(int milliseconds)
{
    currentProfile.dwellTimeMs = milliseconds;
    eyeTracking.setDwellTime(milliseconds);
}

void InclusiveDesignSystem::enableSwitchAccess(bool enable)
{
    currentProfile.switchAccessEnabled = enable;
}

//==============================================================================
// Auditory Accessibility
//==============================================================================

void InclusiveDesignSystem::enableVisualFeedback(bool enable)
{
    currentProfile.visualFeedback = enable;
}

void InclusiveDesignSystem::enableCaptions(bool enable)
{
    currentProfile.captionsEnabled = enable;
}

void InclusiveDesignSystem::addCaption(const juce::String& text)
{
    if (currentProfile.captionsEnabled)
    {
        DBG("Caption: " + text);
        // Would display caption on screen
    }
}

void InclusiveDesignSystem::enableHapticFeedback(bool enable)
{
    currentProfile.hapticFeedbackEnabled = enable;
}

void InclusiveDesignSystem::triggerHaptic(const juce::String& pattern)
{
    if (currentProfile.hapticFeedbackEnabled)
    {
        DBG("Haptic feedback: " + pattern);
        // Would trigger device haptic
    }
}

//==============================================================================
// Cognitive Accessibility
//==============================================================================

void InclusiveDesignSystem::enableSimplifiedUI(bool enable)
{
    currentProfile.simplifiedUI = enable;
}

bool InclusiveDesignSystem::isSimplifiedUIActive() const
{
    return currentProfile.simplifiedUI;
}

void InclusiveDesignSystem::enableGuidedMode(bool enable)
{
    currentProfile.guidedMode = enable;
}

void InclusiveDesignSystem::showInstructions(const juce::String& step)
{
    if (currentProfile.stepByStepInstructions)
    {
        announce(step, false);
        DBG("Instruction: " + step);
    }
}

void InclusiveDesignSystem::enableEnhancedTooltips(bool enable)
{
    currentProfile.enhancedTooltips = enable;
}

//==============================================================================
// Keyboard Navigation
//==============================================================================

void InclusiveDesignSystem::enableKeyboardNavigation(bool enable)
{
    currentProfile.keyboardOnlyNavigation = enable;
    keyboardNav.enable(enable);
}

void InclusiveDesignSystem::focusNext()
{
    keyboardNav.focusNext();
}

void InclusiveDesignSystem::focusPrevious()
{
    keyboardNav.focusPrevious();
}

void InclusiveDesignSystem::activateFocused()
{
    keyboardNav.activateFocused();
}

//==============================================================================
// UI Adaptation
//==============================================================================

int InclusiveDesignSystem::getMinimumTouchTargetSize() const
{
    return currentProfile.minimumTargetSize;
}

bool InclusiveDesignSystem::shouldUseLargeTargets() const
{
    return currentProfile.largerClickTargets;
}

float InclusiveDesignSystem::getSpacingMultiplier() const
{
    if (currentProfile.simplifiedUI)
        return 1.5f;

    return 1.0f;
}

float InclusiveDesignSystem::getRequiredContrastRatio() const
{
    switch (currentProfile.contrastLevel)
    {
        case ContrastMode::High:       return 7.0f;  // WCAG AAA
        case ContrastMode::ExtraHigh:  return 10.0f;
        default:                       return 4.5f;  // WCAG AA
    }
}

//==============================================================================
// Compliance
//==============================================================================

juce::String InclusiveDesignSystem::getWCAGComplianceLevel() const
{
    float contrastRatio = getRequiredContrastRatio();

    if (contrastRatio >= 7.0f && currentProfile.textSize >= TextSize::Large)
        return "WCAG 2.1 AAA";
    else if (contrastRatio >= 4.5f)
        return "WCAG 2.1 AA";
    else
        return "WCAG 2.1 A";
}

juce::String InclusiveDesignSystem::generateAccessibilityReport() const
{
    juce::String report;
    report << "=== ACCESSIBILITY REPORT ===\n\n";
    report << "Profile: " << currentProfile.name << "\n";
    report << "WCAG Compliance: " << getWCAGComplianceLevel() << "\n\n";

    report << "Visual Accessibility:\n";
    report << "- Screen Reader: " << (currentProfile.screenReaderEnabled ? "ON" : "OFF") << "\n";
    report << "- High Contrast: " << (currentProfile.highContrastMode ? "ON" : "OFF") << "\n";
    report << "- Text Size: " << (int)currentProfile.textSize << "\n\n";

    report << "Motor Accessibility:\n";
    report << "- Voice Control: " << (currentProfile.voiceControlEnabled ? "ON" : "OFF") << "\n";
    report << "- Eye Tracking: " << (currentProfile.eyeTrackingEnabled ? "ON" : "OFF") << "\n";
    report << "- One-Handed Mode: " << (currentProfile.oneHandedMode ? "ON" : "OFF") << "\n\n";

    report << "Auditory Accessibility:\n";
    report << "- Visual Feedback: " << (currentProfile.visualFeedback ? "ON" : "OFF") << "\n";
    report << "- Captions: " << (currentProfile.captionsEnabled ? "ON" : "OFF") << "\n";
    report << "- Haptic Feedback: " << (currentProfile.hapticFeedbackEnabled ? "ON" : "OFF") << "\n\n";

    return report;
}

bool InclusiveDesignSystem::checkComponentAccessibility(juce::Component* component) const
{
    if (!component)
        return false;

    // Check if component has accessible name
    if (component->getTitle().isEmpty())
        return false;

    // Check if component meets minimum size
    if (shouldUseLargeTargets() && component->getWidth() < getMinimumTouchTargetSize())
        return false;

    return true;
}

//==============================================================================
// Private Methods
//==============================================================================

void InclusiveDesignSystem::applyProfile(const AccessibilityProfile& profile)
{
    enableScreenReader(profile.screenReaderEnabled);
    setContrastMode(profile.contrastLevel);
    setTextSize(profile.textSize);
    setColorBlindMode(profile.colorBlindMode);
    enableReduceMotion(profile.reduceMotion);

    enableOneHandedMode(profile.oneHandedMode);
    enableVoiceControl(profile.voiceControlEnabled);
    enableEyeTracking(profile.eyeTrackingEnabled);

    enableVisualFeedback(profile.visualFeedback);
    enableCaptions(profile.captionsEnabled);
    enableHapticFeedback(profile.hapticFeedbackEnabled);

    enableSimplifiedUI(profile.simplifiedUI);
    enableGuidedMode(profile.guidedMode);
    enableEnhancedTooltips(profile.enhancedTooltips);

    DBG("Applied accessibility profile: " + profile.name);
}

void InclusiveDesignSystem::loadSystemAccessibilitySettings()
{
    // Would load system accessibility preferences
    DBG("Loading system accessibility settings");
}

juce::File InclusiveDesignSystem::getProfilesDirectory() const
{
    auto appData = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);
    return appData.getChildFile("Echoelmusic").getChildFile("AccessibilityProfiles");
}
