#include "VisualizerBase.h"

//==============================================================================
// VisualizerBase Implementation
//==============================================================================

VisualizerBase::VisualizerBase()
{
    setOpaque(false);
    renderTimes.fill(0.0);
    startTimer(1000 / targetFPS);
}

VisualizerBase::~VisualizerBase()
{
    stopTimer();
}

void VisualizerBase::timerCallback()
{
    updateVisualizationData();
    repaint();
}

void VisualizerBase::updateAudioData(const float* data, int numSamples)
{
    if (data == nullptr || numSamples == 0)
        return;

    juce::ScopedLock lock(bufferLock);
    audioBuffer.assign(data, data + numSamples);
}

void VisualizerBase::updateFFTData(const float* data, int numBins)
{
    if (data == nullptr || numBins == 0)
        return;

    juce::ScopedLock lock(bufferLock);
    fftBuffer.assign(data, data + numBins);
}

void VisualizerBase::setTargetFPS(int fps)
{
    targetFPS = juce::jlimit(1, 120, fps);
    stopTimer();
    startTimer(1000 / targetFPS);
}

void VisualizerBase::paint(juce::Graphics& g)
{
    auto startTime = juce::Time::getMillisecondCounterHiRes();

    // Call derived class rendering
    renderVisualization(g);

    // Update performance metrics
    auto endTime = juce::Time::getMillisecondCounterHiRes();
    double renderTime = endTime - startTime;
    updatePerformanceMetrics(renderTime);

    // Calculate FPS
    if (lastFrameTime > 0)
    {
        double frameTime = startTime - static_cast<double>(lastFrameTime);
        if (frameTime > 0.0)
        {
            actualFPS = 1000.0 / frameTime;
        }
    }
    lastFrameTime = static_cast<juce::int64>(startTime);
}

void VisualizerBase::updatePerformanceMetrics(double renderTime)
{
    renderTimes[renderTimeIndex] = renderTime;
    renderTimeIndex = (renderTimeIndex + 1) % performanceSampleCount;

    double sum = 0.0;
    for (double time : renderTimes)
    {
        sum += time;
    }
    averageRenderTime = sum / static_cast<double>(performanceSampleCount);
}

void VisualizerBase::drawGlow(juce::Graphics& g, const juce::Rectangle<float>& area,
                              const juce::Colour& color, float intensity)
{
    const int glowSteps = 5;
    for (int i = glowSteps; i > 0; --i)
    {
        float alpha = (intensity / static_cast<float>(glowSteps)) * (static_cast<float>(glowSteps - i) / static_cast<float>(glowSteps));
        float expansion = static_cast<float>(i) * 2.0f;

        g.setColour(color.withAlpha(alpha));
        g.fillEllipse(area.expanded(expansion));
    }
}

void VisualizerBase::drawGradientBackground(juce::Graphics& g, const juce::Colour& color1,
                                           const juce::Colour& color2)
{
    g.setGradientFill(juce::ColourGradient(
        color1, 0.0f, 0.0f,
        color2, static_cast<float>(getWidth()), static_cast<float>(getHeight()), false));
    g.fillAll();
}

//==============================================================================
// CustomLookAndFeel Implementation
//==============================================================================

CustomLookAndFeel::CustomLookAndFeel()
{
    // Set default colors
    setColour(juce::Slider::thumbColourId, primaryColor);
    setColour(juce::Slider::rotarySliderFillColourId, secondaryColor);
    setColour(juce::Slider::rotarySliderOutlineColourId, backgroundColor.brighter(0.2f));
    setColour(juce::Slider::trackColourId, secondaryColor);

    setColour(juce::TextButton::buttonColourId, backgroundColor);
    setColour(juce::TextButton::textColourOffId, primaryColor);
    setColour(juce::TextButton::textColourOnId, textColor);

    setColour(juce::Label::textColourId, textColor);
    setColour(juce::ComboBox::backgroundColourId, backgroundColor);
    setColour(juce::ComboBox::textColourId, textColor);
    setColour(juce::ComboBox::outlineColourId, primaryColor);
}

CustomLookAndFeel::~CustomLookAndFeel() = default;

void CustomLookAndFeel::drawRotarySlider(juce::Graphics& g, int x, int y, int width, int height,
                                        float sliderPos, float rotaryStartAngle, float rotaryEndAngle,
                                        juce::Slider& slider)
{
    auto bounds = juce::Rectangle<int>(x, y, width, height).toFloat().reduced(10);
    auto radius = juce::jmin(bounds.getWidth(), bounds.getHeight()) / 2.0f;
    auto toAngle = rotaryStartAngle + sliderPos * (rotaryEndAngle - rotaryStartAngle);
    auto lineW = juce::jmin(8.0f, radius * 0.5f);
    auto arcRadius = radius - lineW * 0.5f;

    // Background arc
    juce::Path backgroundArc;
    backgroundArc.addCentredArc(bounds.getCentreX(), bounds.getCentreY(),
                               arcRadius, arcRadius, 0.0f,
                               rotaryStartAngle, rotaryEndAngle, true);

    g.setColour(backgroundColor.brighter(0.2f));
    g.strokePath(backgroundArc, juce::PathStrokeType(lineW, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    // Value arc with gradient
    if (sliderPos > 0.0f)
    {
        juce::Path valueArc;
        valueArc.addCentredArc(bounds.getCentreX(), bounds.getCentreY(),
                              arcRadius, arcRadius, 0.0f,
                              rotaryStartAngle, toAngle, true);

        juce::ColourGradient gradient(secondaryColor, bounds.getCentreX(), bounds.getY(),
                                     primaryColor, bounds.getCentreX(), bounds.getBottom(), false);
        g.setGradientFill(gradient);
        g.strokePath(valueArc, juce::PathStrokeType(lineW, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
    }

    // Thumb
    juce::Point<float> thumbPoint(bounds.getCentreX() + arcRadius * std::cos(toAngle - juce::MathConstants<float>::halfPi),
                                 bounds.getCentreY() + arcRadius * std::sin(toAngle - juce::MathConstants<float>::halfPi));

    // Glow effect
    g.setColour(primaryColor.withAlpha(0.3f));
    g.fillEllipse(juce::Rectangle<float>(lineW * 2, lineW * 2).withCentre(thumbPoint).expanded(2.0f));

    // Main thumb
    g.setColour(primaryColor);
    g.fillEllipse(juce::Rectangle<float>(lineW * 2, lineW * 2).withCentre(thumbPoint));
}

void CustomLookAndFeel::drawLinearSlider(juce::Graphics& g, int x, int y, int width, int height,
                                        float sliderPos, float minSliderPos, float maxSliderPos,
                                        const juce::Slider::SliderStyle style, juce::Slider& slider)
{
    auto trackWidth = juce::jmin(6.0f, static_cast<float>(height) * 0.25f);
    juce::Point<float> startPoint(static_cast<float>(x) + static_cast<float>(width) * 0.5f, static_cast<float>(height) - 8.0f);
    juce::Point<float> endPoint(static_cast<float>(x) + static_cast<float>(width) * 0.5f, 8.0f);

    juce::Path track;
    track.startNewSubPath(startPoint);
    track.lineTo(endPoint);

    // Background track
    g.setColour(backgroundColor.brighter(0.2f));
    g.strokePath(track, juce::PathStrokeType(trackWidth, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    // Value track
    juce::Path valueTrack;
    juce::Point<float> minPoint, maxPoint;

    if (slider.isHorizontal())
    {
        minPoint = {sliderPos, static_cast<float>(y) + static_cast<float>(height) * 0.5f};
        maxPoint = {static_cast<float>(x) + static_cast<float>(width), static_cast<float>(y) + static_cast<float>(height) * 0.5f};
    }
    else
    {
        minPoint = {static_cast<float>(x) + static_cast<float>(width) * 0.5f, sliderPos};
        maxPoint = {static_cast<float>(x) + static_cast<float>(width) * 0.5f, static_cast<float>(y) + static_cast<float>(height)};
    }

    valueTrack.startNewSubPath(minPoint);
    valueTrack.lineTo(maxPoint);

    g.setColour(secondaryColor);
    g.strokePath(valueTrack, juce::PathStrokeType(trackWidth, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    // Thumb with glow
    auto thumbWidth = static_cast<float>(getSliderThumbRadius(slider));
    juce::Point<float> thumbPoint;

    if (slider.isHorizontal())
        thumbPoint = {sliderPos, static_cast<float>(y) + static_cast<float>(height) * 0.5f};
    else
        thumbPoint = {static_cast<float>(x) + static_cast<float>(width) * 0.5f, sliderPos};

    g.setColour(primaryColor.withAlpha(0.3f));
    g.fillEllipse(juce::Rectangle<float>(thumbWidth * 2, thumbWidth * 2).withCentre(thumbPoint).expanded(2.0f));

    g.setColour(primaryColor);
    g.fillEllipse(juce::Rectangle<float>(thumbWidth * 2, thumbWidth * 2).withCentre(thumbPoint));
}

void CustomLookAndFeel::drawButtonBackground(juce::Graphics& g, juce::Button& button,
                                             const juce::Colour& backgroundColour,
                                             bool shouldDrawButtonAsHighlighted,
                                             bool shouldDrawButtonAsDown)
{
    auto bounds = button.getLocalBounds().toFloat().reduced(0.5f, 0.5f);
    auto baseColour = backgroundColour;

    if (shouldDrawButtonAsDown || shouldDrawButtonAsHighlighted)
        baseColour = baseColour.brighter(shouldDrawButtonAsDown ? 0.3f : 0.1f);

    // Button fill with gradient
    g.setGradientFill(juce::ColourGradient(
        baseColour, 0.0f, bounds.getY(),
        baseColour.darker(0.2f), 0.0f, bounds.getBottom(), false));
    g.fillRoundedRectangle(bounds, 4.0f);

    // Outline
    g.setColour(primaryColor.withAlpha(shouldDrawButtonAsHighlighted ? 1.0f : 0.5f));
    g.drawRoundedRectangle(bounds, 4.0f, 1.5f);

    // Glow effect when highlighted
    if (shouldDrawButtonAsHighlighted)
    {
        g.setColour(primaryColor.withAlpha(0.2f));
        g.drawRoundedRectangle(bounds.expanded(2.0f), 6.0f, 2.0f);
    }
}

void CustomLookAndFeel::drawLabel(juce::Graphics& g, juce::Label& label)
{
    g.fillAll(label.findColour(juce::Label::backgroundColourId));

    if (!label.isBeingEdited())
    {
        auto alpha = label.isEnabled() ? 1.0f : 0.5f;
        const juce::Font font(getLabelFont(label));

        g.setColour(label.findColour(juce::Label::textColourId).withMultipliedAlpha(alpha));
        g.setFont(font);

        auto textArea = getLabelBorderSize(label).subtractedFrom(label.getLocalBounds());

        g.drawFittedText(label.getText(), textArea, label.getJustificationType(),
                        juce::jmax(1, (int)(static_cast<float>(textArea.getHeight()) / font.getHeight())),
                        label.getMinimumHorizontalScale());
    }
}

void CustomLookAndFeel::drawComboBox(juce::Graphics& g, int width, int height,
                                     bool isButtonDown, int buttonX, int buttonY,
                                     int buttonW, int buttonH, juce::ComboBox& box)
{
    auto bounds = juce::Rectangle<int>(0, 0, width, height).toFloat().reduced(0.5f, 0.5f);

    // Background
    g.setColour(backgroundColor);
    g.fillRoundedRectangle(bounds, 4.0f);

    // Outline
    g.setColour(primaryColor.withAlpha(box.hasKeyboardFocus(true) ? 1.0f : 0.5f));
    g.drawRoundedRectangle(bounds, 4.0f, 1.5f);

    // Arrow
    juce::Path path;
    auto arrowZone = juce::Rectangle<int>(buttonX, buttonY, buttonW, buttonH).toFloat().reduced(3.0f);
    path.startNewSubPath(arrowZone.getX(), arrowZone.getY());
    path.lineTo(arrowZone.getCentreX(), arrowZone.getBottom());
    path.lineTo(arrowZone.getRight(), arrowZone.getY());

    g.setColour(primaryColor);
    g.strokePath(path, juce::PathStrokeType(2.0f));
}

void CustomLookAndFeel::drawPopupMenuBackground(juce::Graphics& g, int width, int height)
{
    g.fillAll(backgroundColor.darker(0.2f));

    g.setColour(primaryColor.withAlpha(0.5f));
    g.drawRect(0, 0, width, height);
}

//==============================================================================
// ParameterBridge Implementation
//==============================================================================

ParameterBridge::ParameterBridge(juce::AudioProcessorValueTreeState& vts)
    : valueTreeState(vts)
{
}

ParameterBridge::~ParameterBridge()
{
    unregisterAll();
}

void ParameterBridge::parameterChanged(const juce::String& parameterID, float newValue)
{
    juce::MessageManager::callAsync([this, parameterID, newValue]
    {
        updateUIComponent(parameterID, newValue);
    });
}

void ParameterBridge::registerSlider(const juce::String& parameterID, juce::Slider* slider)
{
    if (slider == nullptr)
        return;

    juce::ScopedLock lock(mappingLock);

    UIComponentMapping mapping;
    mapping.component = slider;
    mapping.parameterID = parameterID;
    mapping.lastValue = 0.0f;
    mapping.lastUpdateTime = 0;

    mappings.push_back(mapping);

    // Add parameter listener
    valueTreeState.addParameterListener(parameterID, this);
}

void ParameterBridge::registerButton(const juce::String& parameterID, juce::Button* button)
{
    if (button == nullptr)
        return;

    juce::ScopedLock lock(mappingLock);

    UIComponentMapping mapping;
    mapping.component = button;
    mapping.parameterID = parameterID;
    mapping.lastValue = 0.0f;
    mapping.lastUpdateTime = 0;

    mappings.push_back(mapping);

    valueTreeState.addParameterListener(parameterID, this);
}

void ParameterBridge::registerComboBox(const juce::String& parameterID, juce::ComboBox* comboBox)
{
    if (comboBox == nullptr)
        return;

    juce::ScopedLock lock(mappingLock);

    UIComponentMapping mapping;
    mapping.component = comboBox;
    mapping.parameterID = parameterID;
    mapping.lastValue = 0.0f;
    mapping.lastUpdateTime = 0;

    mappings.push_back(mapping);

    valueTreeState.addParameterListener(parameterID, this);
}

void ParameterBridge::unregisterAll()
{
    juce::ScopedLock lock(mappingLock);

    for (const auto& mapping : mappings)
    {
        valueTreeState.removeParameterListener(mapping.parameterID, this);
    }

    mappings.clear();
}

void ParameterBridge::updateAllUIComponents()
{
    juce::ScopedLock lock(mappingLock);

    for (auto& mapping : mappings)
    {
        if (auto* param = valueTreeState.getParameter(mapping.parameterID))
        {
            updateUIComponent(mapping.parameterID, param->getValue());
        }
    }
}

void ParameterBridge::updateUIComponent(const juce::String& parameterID, float value)
{
    juce::ScopedLock lock(mappingLock);

    // 60 FPS limiter
    auto currentTime = juce::Time::getMillisecondCounter();

    for (auto& mapping : mappings)
    {
        if (mapping.parameterID == parameterID)
        {
            if (currentTime - mapping.lastUpdateTime < minUpdateIntervalMs)
                return;

            mapping.lastUpdateTime = currentTime;
            mapping.lastValue = value;

            if (auto* slider = dynamic_cast<juce::Slider*>(mapping.component))
            {
                slider->setValue(value, juce::dontSendNotification);
            }
            else if (auto* button = dynamic_cast<juce::Button*>(mapping.component))
            {
                button->setToggleState(value > 0.5f, juce::dontSendNotification);
            }
            else if (auto* comboBox = dynamic_cast<juce::ComboBox*>(mapping.component))
            {
                comboBox->setSelectedId(static_cast<int>(value) + 1, juce::dontSendNotification);
            }

            break;
        }
    }
}

juce::Component* ParameterBridge::findComponentByParameterID(const juce::String& parameterID)
{
    juce::ScopedLock lock(mappingLock);

    for (const auto& mapping : mappings)
    {
        if (mapping.parameterID == parameterID)
            return mapping.component;
    }

    return nullptr;
}
