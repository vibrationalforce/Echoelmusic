#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "ModernLookAndFeel.h"

//==============================================================================
/**
 * @brief Modern Rotary Knob with Value Display
 *
 * Features:
 * - Touch-optimized
 * - Value label
 * - Parameter name
 * - Smooth animation
 * - Accessibility support
 */
class ModernKnob : public ResponsiveComponent
{
public:
    ModernKnob(const juce::String& parameterName = "",
               const juce::String& unit = "",
               float minValue = 0.0f,
               float maxValue = 1.0f,
               float defaultValue = 0.5f)
        : paramName(parameterName), unitSuffix(unit)
    {
        // Setup slider
        addAndMakeVisible(slider);
        slider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
        slider.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);
        slider.setRange(minValue, maxValue, 0.01);
        slider.setValue(defaultValue);
        slider.setDoubleClickReturnValue(true, defaultValue);
        slider.onValueChange = [this] { updateValueLabel(); };

        // Setup labels
        addAndMakeVisible(nameLabel);
        nameLabel.setText(paramName, juce::dontSendNotification);
        nameLabel.setJustificationType(juce::Justification::centred);
        nameLabel.setFont(juce::Font(12.0f));

        addAndMakeVisible(valueLabel);
        valueLabel.setJustificationType(juce::Justification::centred);
        valueLabel.setFont(juce::Font(14.0f, juce::Font::bold));
        updateValueLabel();
    }

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();
        auto metrics = getLayoutMetrics();

        // Name at top
        nameLabel.setBounds(bounds.removeFromTop(20));

        // Value at bottom
        valueLabel.setBounds(bounds.removeFromBottom(24));

        // Knob in middle
        slider.setBounds(bounds);
    }

    juce::Slider& getSlider() { return slider; }

    void setValue(float value, juce::NotificationType notification = juce::sendNotificationAsync)
    {
        slider.setValue(value, notification);
    }

    float getValue() const
    {
        return static_cast<float>(slider.getValue());
    }

private:
    void updateValueLabel()
    {
        auto value = slider.getValue();
        juce::String text;

        // Format based on range
        if (slider.getMaximum() - slider.getMinimum() > 100)
            text = juce::String(value, 0);  // No decimals for large ranges
        else if (slider.getMaximum() - slider.getMinimum() > 10)
            text = juce::String(value, 1);  // 1 decimal
        else
            text = juce::String(value, 2);  // 2 decimals

        text += " " + unitSuffix;
        valueLabel.setText(text, juce::dontSendNotification);
    }

    juce::Slider slider;
    juce::Label nameLabel;
    juce::Label valueLabel;
    juce::String paramName;
    juce::String unitSuffix;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ModernKnob)
};

//==============================================================================
/**
 * @brief Modern Linear Slider with Label
 */
class ModernSlider : public ResponsiveComponent
{
public:
    ModernSlider(const juce::String& parameterName = "",
                 const juce::String& unit = "",
                 float minValue = 0.0f,
                 float maxValue = 1.0f,
                 float defaultValue = 0.5f,
                 bool isHorizontal = true)
        : paramName(parameterName), unitSuffix(unit)
    {
        addAndMakeVisible(slider);
        slider.setSliderStyle(isHorizontal ? juce::Slider::LinearHorizontal : juce::Slider::LinearVertical);
        slider.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);
        slider.setRange(minValue, maxValue, 0.01);
        slider.setValue(defaultValue);
        slider.setDoubleClickReturnValue(true, defaultValue);
        slider.onValueChange = [this] { updateValueLabel(); };

        addAndMakeVisible(nameLabel);
        nameLabel.setText(paramName, juce::dontSendNotification);
        nameLabel.setJustificationType(juce::Justification::centredLeft);
        nameLabel.setFont(juce::Font(12.0f));

        addAndMakeVisible(valueLabel);
        valueLabel.setJustificationType(juce::Justification::centredRight);
        valueLabel.setFont(juce::Font(12.0f, juce::Font::bold));
        updateValueLabel();
    }

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();
        auto labelHeight = 20;

        // Top row: name and value
        auto labelRow = bounds.removeFromTop(labelHeight);
        nameLabel.setBounds(labelRow.removeFromLeft(bounds.getWidth() / 2));
        valueLabel.setBounds(labelRow);

        // Slider takes remaining space
        slider.setBounds(bounds.reduced(0, 4));
    }

    juce::Slider& getSlider() { return slider; }

private:
    void updateValueLabel()
    {
        auto value = slider.getValue();
        juce::String text = juce::String(value, 2) + " " + unitSuffix;
        valueLabel.setText(text, juce::dontSendNotification);
    }

    juce::Slider slider;
    juce::Label nameLabel;
    juce::Label valueLabel;
    juce::String paramName;
    juce::String unitSuffix;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ModernSlider)
};

//==============================================================================
/**
 * @brief Spectrum Visualizer Component
 *
 * Displays FFT spectrum with frequency response curve
 */
class SpectrumVisualizer : public ResponsiveComponent,
                           private juce::Timer
{
public:
    SpectrumVisualizer()
    {
        startTimerHz(60);  // 60 FPS refresh
    }

    void setFFTData(const float* magnitudes, int numBins, float sampleRate)
    {
        if (numBins != fftMagnitudes.size())
            fftMagnitudes.resize(numBins);

        std::copy(magnitudes, magnitudes + numBins, fftMagnitudes.begin());
        this->sampleRate = sampleRate;
        repaint();
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff1a1a1f));

        // Grid lines
        g.setColour(juce::Colour(0xff35353f));
        for (int i = 1; i < 10; ++i)
        {
            float y = bounds.getHeight() * i / 10.0f;
            g.drawHorizontalLine(static_cast<int>(y), bounds.getX(), bounds.getRight());
        }

        if (fftMagnitudes.empty())
            return;

        // Draw spectrum
        juce::Path spectrumPath;
        spectrumPath.startNewSubPath(bounds.getX(), bounds.getBottom());

        for (int i = 0; i < fftMagnitudes.size(); ++i)
        {
            float frequency = (i * sampleRate) / (fftMagnitudes.size() * 2);
            float x = bounds.getX() + frequencyToX(frequency, bounds.getWidth());
            float magnitude = juce::jlimit(0.0f, 1.0f, fftMagnitudes[i]);
            float y = bounds.getBottom() - (magnitude * bounds.getHeight());

            if (i == 0)
                spectrumPath.startNewSubPath(x, y);
            else
                spectrumPath.lineTo(x, y);
        }

        spectrumPath.lineTo(bounds.getRight(), bounds.getBottom());
        spectrumPath.closeSubPath();

        // Gradient fill
        juce::ColourGradient gradient(
            juce::Colour(0xff00d4ff).withAlpha(0.6f), bounds.getCentreX(), bounds.getY(),
            juce::Colour(0xffaa44ff).withAlpha(0.3f), bounds.getCentreX(), bounds.getBottom(),
            false
        );
        g.setGradientFill(gradient);
        g.fillPath(spectrumPath);

        // Outline
        g.setColour(juce::Colour(0xff00d4ff));
        g.strokePath(spectrumPath, juce::PathStrokeType(2.0f));

        // Frequency labels
        g.setColour(juce::Colour(0xffa8a8a8));
        g.setFont(10.0f);
        const float frequencies[] = { 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000 };
        for (float freq : frequencies)
        {
            float x = bounds.getX() + frequencyToX(freq, bounds.getWidth());
            juce::String label = freq < 1000 ? juce::String(static_cast<int>(freq))
                                             : juce::String(freq / 1000.0f, 1) + "k";
            g.drawText(label, static_cast<int>(x - 20), static_cast<int>(bounds.getBottom() - 15), 40, 12,
                      juce::Justification::centred);
        }
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    float frequencyToX(float frequency, float width) const
    {
        // Logarithmic frequency scale
        float minFreq = 20.0f;
        float maxFreq = 20000.0f;
        float normalized = std::log(frequency / minFreq) / std::log(maxFreq / minFreq);
        return normalized * width;
    }

    std::vector<float> fftMagnitudes;
    float sampleRate = 44100.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectrumVisualizer)
};

//==============================================================================
/**
 * @brief Level Meter Component
 */
class LevelMeter : public ResponsiveComponent,
                   private juce::Timer
{
public:
    enum class Orientation { Horizontal, Vertical };

    LevelMeter(Orientation orient = Orientation::Vertical)
        : orientation(orient)
    {
        startTimerHz(30);
    }

    void setLevel(float level)
    {
        currentLevel = juce::jlimit(0.0f, 1.0f, level);

        // Peak hold
        if (currentLevel > peakLevel)
        {
            peakLevel = currentLevel;
            peakHoldTime = 2000;  // Hold for 2 seconds
        }
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(juce::Colour(0xff252530));
        g.fillRoundedRectangle(bounds, 4.0f);

        // Level bar
        float levelHeight = bounds.getHeight() * currentLevel;
        auto levelBounds = bounds.withTop(bounds.getBottom() - levelHeight);

        // Gradient (green -> yellow -> red)
        juce::ColourGradient gradient(
            juce::Colour(0xffff4444), bounds.getCentreX(), bounds.getY(),        // Red at top
            juce::Colour(0xff00ff88), bounds.getCentreX(), bounds.getBottom(),   // Green at bottom
            false
        );
        gradient.addColour(0.7, juce::Colour(0xffffaa00));  // Yellow in middle
        g.setGradientFill(gradient);
        g.fillRoundedRectangle(levelBounds, 4.0f);

        // Peak indicator
        if (peakLevel > 0.0f)
        {
            float peakY = bounds.getBottom() - (bounds.getHeight() * peakLevel);
            g.setColour(juce::Colours::white);
            g.drawHorizontalLine(static_cast<int>(peakY), bounds.getX(), bounds.getRight());
        }

        // dB markers
        g.setColour(juce::Colour(0xff686868));
        g.setFont(9.0f);
        const float dbLevels[] = { 0, -6, -12, -18, -24, -30, -40, -50, -60 };
        for (float db : dbLevels)
        {
            float normalized = juce::jmap(db, -60.0f, 0.0f, 0.0f, 1.0f);
            float y = bounds.getBottom() - (bounds.getHeight() * normalized);
            g.drawText(juce::String(static_cast<int>(db)), bounds.getRight() + 2, static_cast<int>(y - 6), 30, 12,
                      juce::Justification::centredLeft);
        }
    }

private:
    void timerCallback() override
    {
        // Decay current level
        currentLevel *= 0.95f;

        // Decay peak hold
        if (peakHoldTime > 0)
            peakHoldTime -= 33;  // ~30 FPS
        else
            peakLevel *= 0.98f;

        repaint();
    }

    Orientation orientation;
    float currentLevel = 0.0f;
    float peakLevel = 0.0f;
    int peakHoldTime = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LevelMeter)
};

//==============================================================================
/**
 * @brief Preset Browser Component
 */
class PresetBrowser : public ResponsiveComponent
{
public:
    PresetBrowser()
    {
        addAndMakeVisible(presetCombo);
        presetCombo.setTextWhenNothingSelected("Select Preset...");
        presetCombo.onChange = [this]
        {
            if (onPresetSelected)
                onPresetSelected(presetCombo.getSelectedId() - 1);
        };

        addAndMakeVisible(prevButton);
        prevButton.setButtonText("<");
        prevButton.onClick = [this] { selectPreviousPreset(); };

        addAndMakeVisible(nextButton);
        nextButton.setButtonText(">");
        nextButton.onClick = [this] { selectNextPreset(); };
    }

    void addPreset(const juce::String& name)
    {
        int id = presetCombo.getNumItems() + 1;
        presetCombo.addItem(name, id);
    }

    void clearPresets()
    {
        presetCombo.clear();
    }

    void selectPreset(int index)
    {
        presetCombo.setSelectedId(index + 1, juce::sendNotificationAsync);
    }

    std::function<void(int)> onPresetSelected;

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();
        auto buttonWidth = 40;

        prevButton.setBounds(bounds.removeFromLeft(buttonWidth));
        nextButton.setBounds(bounds.removeFromRight(buttonWidth));
        presetCombo.setBounds(bounds.reduced(4, 0));
    }

private:
    void selectPreviousPreset()
    {
        int current = presetCombo.getSelectedId();
        if (current > 1)
            presetCombo.setSelectedId(current - 1, juce::sendNotificationAsync);
    }

    void selectNextPreset()
    {
        int current = presetCombo.getSelectedId();
        if (current < presetCombo.getNumItems())
            presetCombo.setSelectedId(current + 1, juce::sendNotificationAsync);
    }

    juce::ComboBox presetCombo;
    juce::TextButton prevButton;
    juce::TextButton nextButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PresetBrowser)
};

//==============================================================================
/**
 * @brief Bio Heart Rate Visualizer
 *
 * Displays real-time heart rate waveform with BPM display
 */
class BioHeartRateVisualizer : public ResponsiveComponent,
                                private juce::Timer
{
public:
    BioHeartRateVisualizer()
    {
        startTimerHz(30);
        waveformBuffer.resize(200, 0.0f);
    }

    void setHeartRate(double bpm, double quality = 1.0)
    {
        currentBPM = bpm;
        signalQuality = quality;

        // Generate synthetic heartbeat waveform
        phase += (bpm / 60.0) * 0.033;  // ~30 FPS timing
        if (phase >= 1.0)
        {
            phase -= 1.0;
            beatPulse = 1.0f;
        }

        // Simulate ECG-like waveform
        float waveValue = 0.0f;
        float beatPhase = static_cast<float>(std::fmod(phase * 10.0, 1.0));

        if (beatPhase < 0.1f)
            waveValue = beatPhase * 10.0f * 0.3f;           // P wave
        else if (beatPhase < 0.15f)
            waveValue = 0.3f - (beatPhase - 0.1f) * 6.0f;   // P wave down
        else if (beatPhase < 0.2f)
            waveValue = 0.0f;                                // PR interval
        else if (beatPhase < 0.25f)
            waveValue = (beatPhase - 0.2f) * -4.0f;         // Q wave
        else if (beatPhase < 0.35f)
            waveValue = -0.2f + (beatPhase - 0.25f) * 12.0f; // R wave up
        else if (beatPhase < 0.45f)
            waveValue = 1.0f - (beatPhase - 0.35f) * 12.0f;  // R wave down
        else if (beatPhase < 0.5f)
            waveValue = (beatPhase - 0.45f) * -4.0f;         // S wave
        else if (beatPhase < 0.7f)
            waveValue = -0.2f + (beatPhase - 0.5f) * 2.5f;   // ST segment + T wave up
        else if (beatPhase < 0.85f)
            waveValue = 0.3f - (beatPhase - 0.7f) * 2.0f;    // T wave down
        else
            waveValue = 0.0f;

        // Add to buffer
        waveformBuffer.erase(waveformBuffer.begin());
        waveformBuffer.push_back(waveValue);

        repaint();
    }

    void setHRV(double rmssd)
    {
        currentHRV = rmssd;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(juce::Colour(0xff1a1a2e));
        g.fillRoundedRectangle(bounds, 8.0f);

        // Border based on signal quality
        juce::Colour borderColor = signalQuality > 0.7 ? juce::Colour(0xff00ff88)
                                 : signalQuality > 0.4 ? juce::Colour(0xffffaa00)
                                                       : juce::Colour(0xffff4444);
        g.setColour(borderColor);
        g.drawRoundedRectangle(bounds.reduced(1), 8.0f, 2.0f);

        // Waveform area
        auto waveArea = bounds.reduced(10).removeFromBottom(bounds.getHeight() * 0.6f);

        // Draw waveform
        juce::Path waveformPath;
        float xStep = waveArea.getWidth() / static_cast<float>(waveformBuffer.size());

        for (size_t i = 0; i < waveformBuffer.size(); ++i)
        {
            float x = waveArea.getX() + i * xStep;
            float y = waveArea.getCentreY() - (waveformBuffer[i] * waveArea.getHeight() * 0.4f);

            if (i == 0)
                waveformPath.startNewSubPath(x, y);
            else
                waveformPath.lineTo(x, y);
        }

        g.setColour(juce::Colour(0xffff6b6b).withAlpha(0.9f));
        g.strokePath(waveformPath, juce::PathStrokeType(2.5f));

        // Beat pulse glow
        if (beatPulse > 0.0f)
        {
            g.setColour(juce::Colour(0xffff6b6b).withAlpha(beatPulse * 0.3f));
            g.fillEllipse(waveArea.getCentreX() - 30, waveArea.getCentreY() - 30, 60, 60);
            beatPulse *= 0.85f;
        }

        // BPM Display
        auto textArea = bounds.reduced(10).removeFromTop(bounds.getHeight() * 0.35f);

        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(32.0f, juce::Font::bold));
        g.drawText(juce::String(static_cast<int>(currentBPM)), textArea, juce::Justification::centred);

        g.setFont(juce::Font(12.0f));
        g.setColour(juce::Colour(0xffa0a0a0));
        g.drawText("BPM", textArea.translated(0, 28), juce::Justification::centred);

        // HRV display
        if (currentHRV > 0)
        {
            g.setFont(juce::Font(11.0f));
            g.setColour(juce::Colour(0xff88ccff));
            g.drawText("HRV: " + juce::String(currentHRV, 1) + "ms",
                      bounds.removeFromBottom(20), juce::Justification::centred);
        }
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    std::vector<float> waveformBuffer;
    double currentBPM = 72.0;
    double currentHRV = 0.0;
    double signalQuality = 1.0;
    double phase = 0.0;
    float beatPulse = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioHeartRateVisualizer)
};

//==============================================================================
/**
 * @brief Flow State Indicator
 *
 * Visual indicator of creative flow state with intensity ring
 */
class FlowStateIndicator : public ResponsiveComponent,
                           private juce::Timer
{
public:
    FlowStateIndicator()
    {
        startTimerHz(60);
    }

    void setFlowState(bool active, float intensity, float duration = 0.0f)
    {
        flowActive = active;
        targetIntensity = juce::jlimit(0.0f, 1.0f, intensity);
        flowDuration = duration;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(4);
        auto center = bounds.getCentre();
        float radius = std::min(bounds.getWidth(), bounds.getHeight()) * 0.45f;

        // Background circle
        g.setColour(juce::Colour(0xff252535));
        g.fillEllipse(center.x - radius, center.y - radius, radius * 2, radius * 2);

        // Flow ring
        if (currentIntensity > 0.01f)
        {
            // Animated gradient
            animPhase += 0.02f;

            for (int i = 0; i < 3; ++i)
            {
                float ringRadius = radius - (i * 4);
                float alpha = currentIntensity * (1.0f - i * 0.25f);
                float hue = 0.75f + std::sin(animPhase + i * 0.5f) * 0.1f;  // Purple-blue

                g.setColour(juce::Colour::fromHSV(hue, 0.8f, 1.0f, alpha));

                juce::Path ringPath;
                ringPath.addCentredArc(center.x, center.y, ringRadius, ringRadius,
                                       0, -juce::MathConstants<float>::pi,
                                       juce::MathConstants<float>::pi * currentIntensity * 2 - juce::MathConstants<float>::pi,
                                       true);
                g.strokePath(ringPath, juce::PathStrokeType(3.0f));
            }

            // Inner glow
            juce::ColourGradient glow(
                juce::Colour(0xffaa44ff).withAlpha(currentIntensity * 0.4f), center.x, center.y,
                juce::Colour(0xffaa44ff).withAlpha(0.0f), center.x, center.y - radius * 0.8f,
                true
            );
            g.setGradientFill(glow);
            g.fillEllipse(center.x - radius * 0.7f, center.y - radius * 0.7f,
                         radius * 1.4f, radius * 1.4f);
        }

        // Center icon
        g.setColour(flowActive ? juce::Colour(0xffaa44ff) : juce::Colour(0xff606080));
        g.setFont(juce::Font(radius * 0.6f));
        g.drawText(flowActive ? "◉" : "○", bounds, juce::Justification::centred);

        // Label
        g.setFont(juce::Font(11.0f));
        g.setColour(flowActive ? juce::Colours::white : juce::Colour(0xff808080));
        g.drawText(flowActive ? "FLOW" : "Ready",
                  bounds.removeFromBottom(20), juce::Justification::centred);

        // Duration display
        if (flowActive && flowDuration > 0)
        {
            int minutes = static_cast<int>(flowDuration) / 60;
            int seconds = static_cast<int>(flowDuration) % 60;
            g.setFont(juce::Font(10.0f));
            g.setColour(juce::Colour(0xff88ccff));
            g.drawText(juce::String::formatted("%d:%02d", minutes, seconds),
                      bounds.removeFromBottom(16), juce::Justification::centred);
        }
    }

private:
    void timerCallback() override
    {
        // Smooth intensity transition
        float diff = targetIntensity - currentIntensity;
        currentIntensity += diff * 0.1f;

        repaint();
    }

    bool flowActive = false;
    float targetIntensity = 0.0f;
    float currentIntensity = 0.0f;
    float flowDuration = 0.0f;
    float animPhase = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FlowStateIndicator)
};

//==============================================================================
/**
 * @brief Key/Scale Display Component
 *
 * Shows current key and scale with piano keyboard visualization
 */
class KeyScaleDisplay : public ResponsiveComponent
{
public:
    KeyScaleDisplay()
    {
    }

    void setKey(int root, const juce::String& scaleName)
    {
        keyRoot = root;
        this->scaleName = scaleName;
        updateScaleNotes();
        repaint();
    }

    void setScaleNotes(const std::vector<int>& notes)
    {
        scaleNotes = notes;
        repaint();
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(juce::Colour(0xff1e1e28));
        g.fillRoundedRectangle(bounds, 6.0f);

        // Key name display
        auto textArea = bounds.removeFromTop(35);
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(18.0f, juce::Font::bold));
        g.drawText(getKeyName() + " " + scaleName, textArea, juce::Justification::centred);

        // Piano keyboard visualization
        auto keyboardArea = bounds.reduced(10, 5);
        float whiteKeyWidth = keyboardArea.getWidth() / 7.0f;
        float blackKeyWidth = whiteKeyWidth * 0.6f;
        float blackKeyHeight = keyboardArea.getHeight() * 0.6f;

        // White keys
        const int whiteNotes[] = { 0, 2, 4, 5, 7, 9, 11 };
        for (int i = 0; i < 7; ++i)
        {
            auto keyRect = keyboardArea.withWidth(whiteKeyWidth - 1)
                                       .withX(keyboardArea.getX() + i * whiteKeyWidth);

            bool inScale = isNoteInScale(whiteNotes[i]);
            bool isRoot = whiteNotes[i] == keyRoot;

            // Key color
            if (isRoot)
                g.setColour(juce::Colour(0xffaa44ff));
            else if (inScale)
                g.setColour(juce::Colour(0xff44ddff));
            else
                g.setColour(juce::Colour(0xffe8e8e8));

            g.fillRoundedRectangle(keyRect, 2.0f);
            g.setColour(juce::Colour(0xff404040));
            g.drawRoundedRectangle(keyRect, 2.0f, 1.0f);
        }

        // Black keys
        const int blackNotes[] = { 1, 3, -1, 6, 8, 10 };
        const float blackOffsets[] = { 0.7f, 1.7f, -1, 3.7f, 4.7f, 5.7f };

        for (int i = 0; i < 6; ++i)
        {
            if (blackNotes[i] < 0) continue;

            auto keyRect = juce::Rectangle<float>(
                keyboardArea.getX() + blackOffsets[i] * whiteKeyWidth,
                keyboardArea.getY(),
                blackKeyWidth,
                blackKeyHeight
            );

            bool inScale = isNoteInScale(blackNotes[i]);
            bool isRoot = blackNotes[i] == keyRoot;

            if (isRoot)
                g.setColour(juce::Colour(0xff8833cc));
            else if (inScale)
                g.setColour(juce::Colour(0xff2299bb));
            else
                g.setColour(juce::Colour(0xff303030));

            g.fillRoundedRectangle(keyRect, 2.0f);
        }
    }

private:
    juce::String getKeyName() const
    {
        const char* noteNames[] = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" };
        return noteNames[keyRoot % 12];
    }

    bool isNoteInScale(int note) const
    {
        for (int scaleNote : scaleNotes)
        {
            if (scaleNote % 12 == note % 12)
                return true;
        }
        return false;
    }

    void updateScaleNotes()
    {
        // Generate scale notes based on common patterns
        scaleNotes.clear();
        scaleNotes.push_back(keyRoot);

        // Default to major scale intervals if not set
        if (scaleName.containsIgnoreCase("Major"))
        {
            const int intervals[] = { 0, 2, 4, 5, 7, 9, 11 };
            for (int interval : intervals)
                scaleNotes.push_back((keyRoot + interval) % 12);
        }
        else if (scaleName.containsIgnoreCase("Minor"))
        {
            const int intervals[] = { 0, 2, 3, 5, 7, 8, 10 };
            for (int interval : intervals)
                scaleNotes.push_back((keyRoot + interval) % 12);
        }
    }

    int keyRoot = 0;
    juce::String scaleName = "Major";
    std::vector<int> scaleNotes;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(KeyScaleDisplay)
};

//==============================================================================
/**
 * @brief Animated Toggle Button with Icon
 */
class AnimatedToggleButton : public ResponsiveComponent
{
public:
    AnimatedToggleButton(const juce::String& onLabel = "ON",
                         const juce::String& offLabel = "OFF")
        : onText(onLabel), offText(offLabel)
    {
        setMouseCursor(juce::MouseCursor::PointingHandCursor);
    }

    void setToggleState(bool shouldBeOn, bool animate = true)
    {
        if (isOn != shouldBeOn)
        {
            isOn = shouldBeOn;
            if (animate)
                startAnimation();
            else
                animProgress = isOn ? 1.0f : 0.0f;

            if (onClick)
                onClick(isOn);
        }
    }

    bool getToggleState() const { return isOn; }

    std::function<void(bool)> onClick;

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(2);

        // Track
        g.setColour(juce::Colour(0xff353545));
        g.fillRoundedRectangle(bounds, bounds.getHeight() / 2);

        // Active fill
        if (animProgress > 0.0f)
        {
            g.setColour(juce::Colour(0xff44bbff).withAlpha(animProgress));
            g.fillRoundedRectangle(bounds, bounds.getHeight() / 2);
        }

        // Thumb
        float thumbSize = bounds.getHeight() - 4;
        float thumbX = bounds.getX() + 2 + animProgress * (bounds.getWidth() - thumbSize - 4);

        g.setColour(juce::Colours::white);
        g.fillEllipse(thumbX, bounds.getY() + 2, thumbSize, thumbSize);

        // Label
        g.setFont(juce::Font(10.0f, juce::Font::bold));
        g.setColour(isOn ? juce::Colours::white : juce::Colour(0xff808080));
        g.drawText(isOn ? onText : offText, bounds.reduced(4, 0),
                  isOn ? juce::Justification::centredLeft : juce::Justification::centredRight);
    }

    void mouseDown(const juce::MouseEvent&) override
    {
        setToggleState(!isOn);
    }

private:
    void startAnimation()
    {
        startTimerHz(60);
    }

    void timerCallback() override
    {
        float target = isOn ? 1.0f : 0.0f;
        animProgress += (target - animProgress) * 0.2f;

        if (std::abs(target - animProgress) < 0.01f)
        {
            animProgress = target;
            stopTimer();
        }
        repaint();
    }

    bool isOn = false;
    float animProgress = 0.0f;
    juce::String onText, offText;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AnimatedToggleButton)
};

//==============================================================================
/**
 * @brief Tooltip Helper
 *
 * Enhanced tooltips with delay and styling
 */
class TooltipHelper : public juce::TooltipClient
{
public:
    TooltipHelper(juce::Component* target, const juce::String& tip)
        : tooltipText(tip), targetComponent(target)
    {
    }

    juce::String getTooltip() override { return tooltipText; }

    void setTooltip(const juce::String& newTip) { tooltipText = newTip; }

private:
    juce::String tooltipText;
    juce::Component* targetComponent;
};
