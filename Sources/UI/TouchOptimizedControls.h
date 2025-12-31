#pragma once

#include <JuceHeader.h>
#include "SuperIntelligenceTouch.h"
#include "ResponsiveLayout.h"

namespace Echoel {
namespace Touch {

//==============================================================================
/**
 * @brief Global Touch Settings Manager
 *
 * Zentrale Konfiguration für Touch-Verhalten in der gesamten App
 */
class TouchSettingsManager : public juce::ChangeBroadcaster
{
public:
    static TouchSettingsManager& getInstance()
    {
        static TouchSettingsManager instance;
        return instance;
    }

    struct Settings
    {
        // Tremor filtering sensitivity (0 = off, 1 = maximum filtering)
        float tremorFilterStrength = 0.7f;

        // How quickly the system detects intent change
        float intentDetectionSpeed = 0.5f;

        // Fine adjustment sensitivity multiplier
        float fineAdjustSensitivity = 0.3f;

        // Fast morph sensitivity multiplier
        float fastMorphSensitivity = 2.0f;

        // Maximum slew rate for phase-jump prevention (units/sec)
        float maxParameterSlewRate = 5.0f;

        // Enable/disable features
        bool autoIntentDetection = true;
        bool tremorFilterEnabled = true;
        bool phaseJumpPrevention = true;
        bool hapticFeedback = true;

        // Touch size calibration (larger fingers need different settings)
        float fingerSizeCalibration = 1.0f;

        // Accessibility settings
        bool extraLargeTouchTargets = false;
        float touchHoldDelay = 0.3f;  // seconds before hold is recognized
    };

    const Settings& getSettings() const { return settings; }

    void updateSettings(const Settings& newSettings)
    {
        settings = newSettings;
        applyToGlobalConfig();
        sendChangeMessage();
    }

    void setTremorFilterStrength(float strength)
    {
        settings.tremorFilterStrength = juce::jlimit(0.0f, 1.0f, strength);
        applyToGlobalConfig();
        sendChangeMessage();
    }

    void setFineAdjustSensitivity(float sens)
    {
        settings.fineAdjustSensitivity = juce::jlimit(0.1f, 1.0f, sens);
        sendChangeMessage();
    }

    void setFastMorphSensitivity(float sens)
    {
        settings.fastMorphSensitivity = juce::jlimit(1.0f, 5.0f, sens);
        sendChangeMessage();
    }

    // Get configured SuperIntelligenceTouch::Config
    SuperIntelligenceTouch::Config getTouchConfig() const
    {
        SuperIntelligenceTouch::Config config;

        // Map tremor filter strength to Kalman parameters
        // Higher strength = lower process noise = more smoothing
        config.kalmanProcessNoise = 0.01f * (1.0f - settings.tremorFilterStrength * 0.99f);
        config.kalmanMeasurementNoise = 0.05f + settings.tremorFilterStrength * 0.2f;

        // Slew rates based on sensitivity settings
        config.maxSlewRateFine = 100.0f + (1.0f - settings.fineAdjustSensitivity) * 400.0f;
        config.maxSlewRateFast = 1000.0f + settings.fastMorphSensitivity * 500.0f;

        // Intent detection config
        config.intentConfig.fineAdjustMaxVelocity = 30.0f + (1.0f - settings.intentDetectionSpeed) * 40.0f;
        config.intentConfig.fastMorphMinVelocity = 150.0f + settings.intentDetectionSpeed * 100.0f;
        config.intentConfig.holdMinDuration = settings.touchHoldDelay;
        config.intentConfig.stableFramesRequired = static_cast<int>(3 + (1.0f - settings.intentDetectionSpeed) * 7);

        config.adaptiveResponseEnabled = settings.autoIntentDetection;

        return config;
    }

    // Persistence
    void saveToFile(const juce::File& file)
    {
        juce::ValueTree tree("TouchSettings");
        tree.setProperty("tremorFilterStrength", settings.tremorFilterStrength, nullptr);
        tree.setProperty("intentDetectionSpeed", settings.intentDetectionSpeed, nullptr);
        tree.setProperty("fineAdjustSensitivity", settings.fineAdjustSensitivity, nullptr);
        tree.setProperty("fastMorphSensitivity", settings.fastMorphSensitivity, nullptr);
        tree.setProperty("maxParameterSlewRate", settings.maxParameterSlewRate, nullptr);
        tree.setProperty("autoIntentDetection", settings.autoIntentDetection, nullptr);
        tree.setProperty("tremorFilterEnabled", settings.tremorFilterEnabled, nullptr);
        tree.setProperty("phaseJumpPrevention", settings.phaseJumpPrevention, nullptr);
        tree.setProperty("hapticFeedback", settings.hapticFeedback, nullptr);
        tree.setProperty("fingerSizeCalibration", settings.fingerSizeCalibration, nullptr);
        tree.setProperty("extraLargeTouchTargets", settings.extraLargeTouchTargets, nullptr);
        tree.setProperty("touchHoldDelay", settings.touchHoldDelay, nullptr);

        std::unique_ptr<juce::XmlElement> xml(tree.createXml());
        if (xml)
            xml->writeTo(file);
    }

    void loadFromFile(const juce::File& file)
    {
        if (auto xml = juce::XmlDocument::parse(file))
        {
            juce::ValueTree tree = juce::ValueTree::fromXml(*xml);
            if (tree.isValid())
            {
                settings.tremorFilterStrength = tree.getProperty("tremorFilterStrength", 0.7f);
                settings.intentDetectionSpeed = tree.getProperty("intentDetectionSpeed", 0.5f);
                settings.fineAdjustSensitivity = tree.getProperty("fineAdjustSensitivity", 0.3f);
                settings.fastMorphSensitivity = tree.getProperty("fastMorphSensitivity", 2.0f);
                settings.maxParameterSlewRate = tree.getProperty("maxParameterSlewRate", 5.0f);
                settings.autoIntentDetection = tree.getProperty("autoIntentDetection", true);
                settings.tremorFilterEnabled = tree.getProperty("tremorFilterEnabled", true);
                settings.phaseJumpPrevention = tree.getProperty("phaseJumpPrevention", true);
                settings.hapticFeedback = tree.getProperty("hapticFeedback", true);
                settings.fingerSizeCalibration = tree.getProperty("fingerSizeCalibration", 1.0f);
                settings.extraLargeTouchTargets = tree.getProperty("extraLargeTouchTargets", false);
                settings.touchHoldDelay = tree.getProperty("touchHoldDelay", 0.3f);

                sendChangeMessage();
            }
        }
    }

private:
    TouchSettingsManager() = default;

    void applyToGlobalConfig()
    {
        globalConfig = getTouchConfig();
    }

    Settings settings;
    SuperIntelligenceTouch::Config globalConfig;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TouchSettingsManager)
};

//==============================================================================
/**
 * @brief TouchOptimizedKnob - Rotary control with full touch intelligence
 *
 * Features:
 * - Tremor-filtered rotation
 * - Automatic fine/coarse adjustment
 * - Visual intent feedback
 * - Phase-jump prevention
 * - Accessibility support
 */
class TouchOptimizedKnob : public ResponsiveComponent,
                           public SuperIntelligenceTouch::Listener,
                           public juce::ChangeListener
{
public:
    TouchOptimizedKnob(const juce::String& name = "",
                       const juce::String& unit = "",
                       float minValue = 0.0f,
                       float maxValue = 1.0f,
                       float defaultValue = 0.5f)
        : paramName(name), unitSuffix(unit),
          minVal(minValue), maxVal(maxValue), defaultVal(defaultValue)
    {
        currentValue = defaultValue;
        displayValue = defaultValue;

        // Configure touch controller from global settings
        touchController.setConfig(TouchSettingsManager::getInstance().getTouchConfig());
        touchController.addListener(this);
        TouchSettingsManager::getInstance().addChangeListener(this);

        setRepaintsOnMouseActivity(true);
    }

    ~TouchOptimizedKnob() override
    {
        TouchSettingsManager::getInstance().removeChangeListener(this);
        touchController.removeListener(this);
    }

    // Value access
    float getValue() const { return currentValue; }

    void setValue(float value, juce::NotificationType notification = juce::sendNotificationAsync)
    {
        float newValue = juce::jlimit(minVal, maxVal, value);
        if (std::abs(newValue - currentValue) > 0.0001f)
        {
            currentValue = newValue;
            displayValue = newValue;
            repaint();

            if (notification != juce::dontSendNotification && onValueChange)
                onValueChange(currentValue, currentIntent);
        }
    }

    void setRange(float min, float max, float def)
    {
        minVal = min;
        maxVal = max;
        defaultVal = def;
        currentValue = juce::jlimit(min, max, currentValue);
        repaint();
    }

    // Callbacks
    std::function<void(float value, TouchIntent intent)> onValueChange;
    std::function<void()> onDoubleClick;

    // Visual customization
    void setColour(juce::Colour c) { accentColour = c; repaint(); }

    //==========================================================================
    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();
        auto& settings = TouchSettingsManager::getInstance().getSettings();

        // Adjust for large touch targets
        float padding = settings.extraLargeTouchTargets ? 10.0f : 4.0f;
        bounds = bounds.reduced(padding);

        auto knobBounds = bounds.removeFromTop(bounds.getHeight() - 35.0f);
        auto labelBounds = bounds;

        float size = juce::jmin(knobBounds.getWidth(), knobBounds.getHeight());
        auto knobArea = knobBounds.withSizeKeepingCentre(size, size);

        // Background circle
        g.setColour(juce::Colour(0xff252530));
        g.fillEllipse(knobArea);

        // Arc background
        float arcThickness = size * 0.12f;
        juce::Path arcBg;
        float startAngle = juce::MathConstants<float>::pi * 1.25f;
        float endAngle = juce::MathConstants<float>::pi * 2.75f;
        arcBg.addCentredArc(knobArea.getCentreX(), knobArea.getCentreY(),
                            size * 0.4f, size * 0.4f, 0,
                            startAngle, endAngle, true);
        g.setColour(juce::Colour(0xff404050));
        g.strokePath(arcBg, juce::PathStrokeType(arcThickness, juce::PathStrokeType::curved,
                                                  juce::PathStrokeType::rounded));

        // Value arc
        float normalizedValue = (displayValue - minVal) / (maxVal - minVal);
        float valueAngle = startAngle + normalizedValue * (endAngle - startAngle);

        juce::Path arcValue;
        arcValue.addCentredArc(knobArea.getCentreX(), knobArea.getCentreY(),
                               size * 0.4f, size * 0.4f, 0,
                               startAngle, valueAngle, true);

        // Colour based on intent
        juce::Colour arcColour = accentColour;
        if (isDragging)
        {
            switch (currentIntent)
            {
                case TouchIntent::FineAdjust:
                    arcColour = juce::Colours::cyan;
                    break;
                case TouchIntent::FastMorph:
                    arcColour = juce::Colours::orange;
                    break;
                default:
                    break;
            }
        }
        g.setColour(arcColour);
        g.strokePath(arcValue, juce::PathStrokeType(arcThickness, juce::PathStrokeType::curved,
                                                     juce::PathStrokeType::rounded));

        // Center indicator
        g.setColour(juce::Colour(0xff606070));
        g.fillEllipse(knobArea.reduced(size * 0.25f));

        // Pointer line
        float pointerLength = size * 0.2f;
        float pointerAngle = startAngle + normalizedValue * (endAngle - startAngle);
        float cx = knobArea.getCentreX();
        float cy = knobArea.getCentreY();
        float px = cx + std::sin(pointerAngle) * pointerLength;
        float py = cy - std::cos(pointerAngle) * pointerLength;

        g.setColour(juce::Colours::white);
        g.drawLine(cx, cy, px, py, 3.0f);

        // Intent indicator (top of knob)
        if (isDragging)
        {
            g.setColour(arcColour.withAlpha(0.9f));
            g.setFont(10.0f);
            juce::String intentText;
            switch (currentIntent)
            {
                case TouchIntent::FineAdjust: intentText = "FINE"; break;
                case TouchIntent::FastMorph: intentText = "MORPH"; break;
                default: break;
            }
            if (intentText.isNotEmpty())
            {
                g.drawText(intentText, knobArea.removeFromTop(15), juce::Justification::centred);
            }
        }

        // Labels
        g.setColour(juce::Colours::lightgrey);
        g.setFont(11.0f);
        g.drawText(paramName, labelBounds.removeFromTop(15), juce::Justification::centred);

        g.setFont(13.0f);
        juce::String valueText;
        float range = maxVal - minVal;
        if (range > 100)
            valueText = juce::String(static_cast<int>(displayValue));
        else if (range > 10)
            valueText = juce::String(displayValue, 1);
        else
            valueText = juce::String(displayValue, 2);
        valueText += " " + unitSuffix;
        g.setColour(juce::Colours::white);
        g.drawText(valueText, labelBounds, juce::Justification::centred);
    }

    //==========================================================================
    void mouseDown(const juce::MouseEvent& e) override
    {
        if (e.getNumberOfClicks() == 2)
        {
            // Double-click to reset
            setValue(defaultVal);
            if (onDoubleClick) onDoubleClick();
            return;
        }

        isDragging = true;
        dragStartY = e.position.y;
        dragStartValue = currentValue;

        // Initialize slew limiter at current value
        valueSlewLimiter.reset(currentValue);

        touchController.processTouch(e.source.getIndex(), e.position, true);
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        // Get filtered position from touch controller
        auto filtered = touchController.processTouch(e.source.getIndex(), e.position, true);

        // Calculate delta from filtered Y position
        float deltaY = dragStartY - filtered.y;

        // Get sensitivity based on intent
        float sensitivity = 0.005f;
        auto& settings = TouchSettingsManager::getInstance().getSettings();

        switch (currentIntent)
        {
            case TouchIntent::FineAdjust:
                sensitivity = 0.001f * settings.fineAdjustSensitivity;
                break;
            case TouchIntent::FastMorph:
                sensitivity = 0.01f * settings.fastMorphSensitivity;
                break;
            default:
                sensitivity = 0.005f;
                break;
        }

        // Calculate target value
        float range = maxVal - minVal;
        float targetValue = dragStartValue + deltaY * sensitivity * range;
        targetValue = juce::jlimit(minVal, maxVal, targetValue);

        // Apply slew rate limiting for phase-jump prevention
        if (settings.phaseJumpPrevention)
        {
            float slewRate = (currentIntent == TouchIntent::FineAdjust)
                ? settings.maxParameterSlewRate * 0.5f
                : settings.maxParameterSlewRate * 2.0f;
            valueSlewLimiter.setMaxRate(slewRate * range);

            float deltaTime = 1.0f / 60.0f;  // Assume 60 FPS
            displayValue = valueSlewLimiter.process(targetValue, deltaTime);
        }
        else
        {
            displayValue = targetValue;
        }

        currentValue = displayValue;
        repaint();

        if (onValueChange)
            onValueChange(currentValue, currentIntent);
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        touchController.processTouch(e.source.getIndex(), e.position, false);
        isDragging = false;
        currentIntent = TouchIntent::Unknown;
        repaint();
    }

    //==========================================================================
    // SuperIntelligenceTouch::Listener
    void onTouchMove(int id, juce::Point<float> position, TouchIntent intent) override
    {
        // Intent might be updated during drag
    }

    void onIntentChanged(int id, TouchIntent oldIntent, TouchIntent newIntent) override
    {
        currentIntent = newIntent;
        repaint();

        // Haptic feedback could be triggered here
        #if JUCE_IOS
            // iOS haptic feedback API
        #endif
    }

    // ChangeListener for settings updates
    void changeListenerCallback(juce::ChangeBroadcaster* source) override
    {
        if (source == &TouchSettingsManager::getInstance())
        {
            touchController.setConfig(TouchSettingsManager::getInstance().getTouchConfig());
        }
    }

    void performResponsiveLayout() override
    {
        // Auto-size based on content
    }

private:
    juce::String paramName;
    juce::String unitSuffix;
    float minVal, maxVal, defaultVal;
    float currentValue;
    float displayValue;

    SuperIntelligenceTouch touchController;
    SlewRateLimiter valueSlewLimiter { 5.0f };

    bool isDragging = false;
    float dragStartY = 0.0f;
    float dragStartValue = 0.0f;
    TouchIntent currentIntent = TouchIntent::Unknown;

    juce::Colour accentColour { 0xff00d4ff };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TouchOptimizedKnob)
};

//==============================================================================
/**
 * @brief TouchOptimizedFader - Linear fader with touch intelligence
 */
class TouchOptimizedFader : public ResponsiveComponent,
                            public SuperIntelligenceTouch::Listener,
                            public juce::ChangeListener
{
public:
    enum class Orientation { Vertical, Horizontal };

    TouchOptimizedFader(Orientation orient = Orientation::Vertical,
                        const juce::String& name = "",
                        float minValue = 0.0f,
                        float maxValue = 1.0f)
        : orientation(orient), paramName(name), minVal(minValue), maxVal(maxValue)
    {
        currentValue = minValue;
        displayValue = minValue;

        touchController.setConfig(TouchSettingsManager::getInstance().getTouchConfig());
        touchController.addListener(this);
        TouchSettingsManager::getInstance().addChangeListener(this);
    }

    ~TouchOptimizedFader() override
    {
        TouchSettingsManager::getInstance().removeChangeListener(this);
        touchController.removeListener(this);
    }

    float getValue() const { return currentValue; }

    void setValue(float value)
    {
        currentValue = juce::jlimit(minVal, maxVal, value);
        displayValue = currentValue;
        repaint();
    }

    std::function<void(float value, TouchIntent intent)> onValueChange;

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(4);

        bool isVert = (orientation == Orientation::Vertical);
        float trackWidth = isVert ? bounds.getWidth() * 0.3f : bounds.getHeight() * 0.3f;

        // Track background
        juce::Rectangle<float> trackBounds;
        if (isVert)
        {
            trackBounds = bounds.withSizeKeepingCentre(trackWidth, bounds.getHeight());
        }
        else
        {
            trackBounds = bounds.withSizeKeepingCentre(bounds.getWidth(), trackWidth);
        }

        g.setColour(juce::Colour(0xff303040));
        g.fillRoundedRectangle(trackBounds, 4.0f);

        // Value fill
        float normalizedValue = (displayValue - minVal) / (maxVal - minVal);
        juce::Rectangle<float> fillBounds;

        if (isVert)
        {
            float fillHeight = trackBounds.getHeight() * normalizedValue;
            fillBounds = trackBounds.withTop(trackBounds.getBottom() - fillHeight);
        }
        else
        {
            float fillWidth = trackBounds.getWidth() * normalizedValue;
            fillBounds = trackBounds.withWidth(fillWidth);
        }

        juce::Colour fillColour = accentColour;
        if (isDragging)
        {
            switch (currentIntent)
            {
                case TouchIntent::FineAdjust: fillColour = juce::Colours::cyan; break;
                case TouchIntent::FastMorph: fillColour = juce::Colours::orange; break;
                default: break;
            }
        }
        g.setColour(fillColour);
        g.fillRoundedRectangle(fillBounds, 4.0f);

        // Handle/thumb
        float handleSize = isVert ? bounds.getWidth() * 0.8f : bounds.getHeight() * 0.8f;
        juce::Rectangle<float> handleBounds;

        if (isVert)
        {
            float handleY = trackBounds.getBottom() - normalizedValue * trackBounds.getHeight() - handleSize / 2;
            handleBounds = juce::Rectangle<float>(
                trackBounds.getCentreX() - handleSize / 2,
                handleY,
                handleSize,
                handleSize
            );
        }
        else
        {
            float handleX = trackBounds.getX() + normalizedValue * trackBounds.getWidth() - handleSize / 2;
            handleBounds = juce::Rectangle<float>(
                handleX,
                trackBounds.getCentreY() - handleSize / 2,
                handleSize,
                handleSize
            );
        }

        g.setColour(juce::Colour(0xffa0a0b0));
        g.fillRoundedRectangle(handleBounds, handleSize * 0.2f);
        g.setColour(juce::Colours::white);
        g.drawRoundedRectangle(handleBounds, handleSize * 0.2f, 2.0f);

        // Intent indicator
        if (isDragging && currentIntent != TouchIntent::Unknown)
        {
            g.setColour(fillColour.withAlpha(0.9f));
            g.setFont(9.0f);
            juce::String intentText = (currentIntent == TouchIntent::FineAdjust) ? "FINE" : "MORPH";
            auto textBounds = isVert ? bounds.removeFromTop(12) : bounds.removeFromLeft(30);
            g.drawText(intentText, textBounds, juce::Justification::centred);
        }

        // Label
        if (paramName.isNotEmpty())
        {
            g.setColour(juce::Colours::lightgrey);
            g.setFont(10.0f);
            auto labelBounds = isVert ? bounds.removeFromBottom(15) : bounds.removeFromRight(50);
            g.drawText(paramName, labelBounds, juce::Justification::centred);
        }
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        isDragging = true;
        dragStart = e.position;
        dragStartValue = currentValue;
        valueSlewLimiter.reset(currentValue);
        touchController.processTouch(e.source.getIndex(), e.position, true);
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        auto filtered = touchController.processTouch(e.source.getIndex(), e.position, true);

        bool isVert = (orientation == Orientation::Vertical);
        auto bounds = getLocalBounds().toFloat();

        float normalizedPos;
        if (isVert)
        {
            normalizedPos = 1.0f - (filtered.y / bounds.getHeight());
        }
        else
        {
            normalizedPos = filtered.x / bounds.getWidth();
        }

        normalizedPos = juce::jlimit(0.0f, 1.0f, normalizedPos);
        float targetValue = minVal + normalizedPos * (maxVal - minVal);

        // Apply slew limiting
        auto& settings = TouchSettingsManager::getInstance().getSettings();
        if (settings.phaseJumpPrevention)
        {
            float slewRate = (currentIntent == TouchIntent::FineAdjust)
                ? settings.maxParameterSlewRate * 0.5f
                : settings.maxParameterSlewRate * 2.0f;
            valueSlewLimiter.setMaxRate(slewRate * (maxVal - minVal));
            displayValue = valueSlewLimiter.process(targetValue, 1.0f / 60.0f);
        }
        else
        {
            displayValue = targetValue;
        }

        currentValue = displayValue;
        repaint();

        if (onValueChange)
            onValueChange(currentValue, currentIntent);
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        touchController.processTouch(e.source.getIndex(), e.position, false);
        isDragging = false;
        currentIntent = TouchIntent::Unknown;
        repaint();
    }

    void onIntentChanged(int id, TouchIntent oldIntent, TouchIntent newIntent) override
    {
        currentIntent = newIntent;
        repaint();
    }

    void changeListenerCallback(juce::ChangeBroadcaster*) override
    {
        touchController.setConfig(TouchSettingsManager::getInstance().getTouchConfig());
    }

    void performResponsiveLayout() override {}

private:
    Orientation orientation;
    juce::String paramName;
    float minVal, maxVal;
    float currentValue, displayValue;

    SuperIntelligenceTouch touchController;
    SlewRateLimiter valueSlewLimiter { 5.0f };

    bool isDragging = false;
    juce::Point<float> dragStart;
    float dragStartValue = 0.0f;
    TouchIntent currentIntent = TouchIntent::Unknown;

    juce::Colour accentColour { 0xff00d4ff };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TouchOptimizedFader)
};

//==============================================================================
/**
 * @brief TouchSettingsPanel - UI for configuring touch behavior
 */
class TouchSettingsPanel : public juce::Component,
                           public juce::ChangeListener
{
public:
    TouchSettingsPanel()
    {
        // Title
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Touch Intelligence Settings", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(18.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colours::white);

        // Tremor filter
        addAndMakeVisible(tremorLabel);
        tremorLabel.setText("Tremor Filter:", juce::dontSendNotification);
        addAndMakeVisible(tremorSlider);
        tremorSlider.setRange(0.0, 1.0, 0.01);
        tremorSlider.setValue(0.7);
        tremorSlider.onValueChange = [this] { updateSettings(); };

        // Fine sensitivity
        addAndMakeVisible(fineLabel);
        fineLabel.setText("Fine Adjust Sensitivity:", juce::dontSendNotification);
        addAndMakeVisible(fineSlider);
        fineSlider.setRange(0.1, 1.0, 0.01);
        fineSlider.setValue(0.3);
        fineSlider.onValueChange = [this] { updateSettings(); };

        // Fast sensitivity
        addAndMakeVisible(fastLabel);
        fastLabel.setText("Fast Morph Sensitivity:", juce::dontSendNotification);
        addAndMakeVisible(fastSlider);
        fastSlider.setRange(1.0, 5.0, 0.1);
        fastSlider.setValue(2.0);
        fastSlider.onValueChange = [this] { updateSettings(); };

        // Phase jump prevention
        addAndMakeVisible(phaseJumpToggle);
        phaseJumpToggle.setButtonText("Phase-Jump Prevention");
        phaseJumpToggle.setToggleState(true, juce::dontSendNotification);
        phaseJumpToggle.onClick = [this] { updateSettings(); };

        // Auto intent detection
        addAndMakeVisible(autoIntentToggle);
        autoIntentToggle.setButtonText("Auto Intent Detection");
        autoIntentToggle.setToggleState(true, juce::dontSendNotification);
        autoIntentToggle.onClick = [this] { updateSettings(); };

        // Large touch targets
        addAndMakeVisible(largeTouchToggle);
        largeTouchToggle.setButtonText("Extra Large Touch Targets");
        largeTouchToggle.setToggleState(false, juce::dontSendNotification);
        largeTouchToggle.onClick = [this] { updateSettings(); };

        // Load current settings
        loadFromManager();
        TouchSettingsManager::getInstance().addChangeListener(this);
    }

    ~TouchSettingsPanel() override
    {
        TouchSettingsManager::getInstance().removeChangeListener(this);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);

        titleLabel.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(10);

        auto rowHeight = 30;
        auto sliderWidth = bounds.getWidth() * 0.6f;

        auto row = bounds.removeFromTop(rowHeight);
        tremorLabel.setBounds(row.removeFromLeft(static_cast<int>(bounds.getWidth() * 0.4f)));
        tremorSlider.setBounds(row);
        bounds.removeFromTop(5);

        row = bounds.removeFromTop(rowHeight);
        fineLabel.setBounds(row.removeFromLeft(static_cast<int>(bounds.getWidth() * 0.4f)));
        fineSlider.setBounds(row);
        bounds.removeFromTop(5);

        row = bounds.removeFromTop(rowHeight);
        fastLabel.setBounds(row.removeFromLeft(static_cast<int>(bounds.getWidth() * 0.4f)));
        fastSlider.setBounds(row);
        bounds.removeFromTop(10);

        phaseJumpToggle.setBounds(bounds.removeFromTop(rowHeight));
        autoIntentToggle.setBounds(bounds.removeFromTop(rowHeight));
        largeTouchToggle.setBounds(bounds.removeFromTop(rowHeight));
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff1a1a2a));
    }

    void changeListenerCallback(juce::ChangeBroadcaster*) override
    {
        loadFromManager();
    }

private:
    void loadFromManager()
    {
        auto& settings = TouchSettingsManager::getInstance().getSettings();
        tremorSlider.setValue(settings.tremorFilterStrength, juce::dontSendNotification);
        fineSlider.setValue(settings.fineAdjustSensitivity, juce::dontSendNotification);
        fastSlider.setValue(settings.fastMorphSensitivity, juce::dontSendNotification);
        phaseJumpToggle.setToggleState(settings.phaseJumpPrevention, juce::dontSendNotification);
        autoIntentToggle.setToggleState(settings.autoIntentDetection, juce::dontSendNotification);
        largeTouchToggle.setToggleState(settings.extraLargeTouchTargets, juce::dontSendNotification);
    }

    void updateSettings()
    {
        TouchSettingsManager::Settings settings;
        settings.tremorFilterStrength = static_cast<float>(tremorSlider.getValue());
        settings.fineAdjustSensitivity = static_cast<float>(fineSlider.getValue());
        settings.fastMorphSensitivity = static_cast<float>(fastSlider.getValue());
        settings.phaseJumpPrevention = phaseJumpToggle.getToggleState();
        settings.autoIntentDetection = autoIntentToggle.getToggleState();
        settings.extraLargeTouchTargets = largeTouchToggle.getToggleState();

        TouchSettingsManager::getInstance().updateSettings(settings);
    }

    juce::Label titleLabel;
    juce::Label tremorLabel, fineLabel, fastLabel;
    juce::Slider tremorSlider, fineSlider, fastSlider;
    juce::ToggleButton phaseJumpToggle, autoIntentToggle, largeTouchToggle;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TouchSettingsPanel)
};

} // namespace Touch
} // namespace Echoel
