/*
  ==============================================================================

    TransportBar.h
    Transport Controls - Play, Pause, Stop, Record, Loop

    Accessible transport with large touch targets and keyboard shortcuts.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../UI/AccessibilityConstants.h"
#include <functional>

namespace Echoelmusic {
namespace GUI {

//==============================================================================
// Transport Button
//==============================================================================

class TransportButton : public juce::Component
{
public:
    enum class Type { Play, Pause, Stop, Record, Loop, Metronome };

    TransportButton(Type type, const juce::String& label)
        : buttonType(type), accessibleLabel(label)
    {
        setWantsKeyboardFocus(true);

        // Accessibility
        setAccessible(true);
        setTitle(label);
        setDescription(getDescription());
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(4);

        // Background
        juce::Colour bgColor = isActive ? activeColor : normalColor;
        if (isMouseOver())
            bgColor = bgColor.brighter(0.1f);
        if (isMouseButtonDown())
            bgColor = bgColor.darker(0.1f);

        g.setColour(bgColor);
        g.fillRoundedRectangle(bounds, 8.0f);

        // Focus ring
        if (hasKeyboardFocus(true))
        {
            g.setColour(juce::Colour(0xFF00D9FF));
            g.drawRoundedRectangle(bounds.reduced(1), 8.0f, 2.0f);
        }

        // Icon
        g.setColour(isActive ? juce::Colours::white : juce::Colour(0xFFB8B8C8));
        drawIcon(g, bounds.reduced(bounds.getWidth() * 0.25f));
    }

    void mouseDown(const juce::MouseEvent&) override
    {
        if (onClick)
            onClick();
        repaint();
    }

    void mouseEnter(const juce::MouseEvent&) override { repaint(); }
    void mouseExit(const juce::MouseEvent&) override { repaint(); }

    bool keyPressed(const juce::KeyPress& key) override
    {
        if (key == juce::KeyPress::returnKey || key == juce::KeyPress::spaceKey)
        {
            if (onClick)
                onClick();
            return true;
        }
        return false;
    }

    void setActive(bool active)
    {
        if (isActive != active)
        {
            isActive = active;
            repaint();
        }
    }

    bool getActive() const { return isActive; }

    void setActiveColor(juce::Colour color) { activeColor = color; }

    std::function<void()> onClick;

private:
    void drawIcon(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        auto cx = bounds.getCentreX();
        auto cy = bounds.getCentreY();
        auto size = std::min(bounds.getWidth(), bounds.getHeight()) * 0.5f;

        switch (buttonType)
        {
            case Type::Play:
            {
                juce::Path triangle;
                triangle.addTriangle(
                    cx - size * 0.4f, cy - size * 0.5f,
                    cx - size * 0.4f, cy + size * 0.5f,
                    cx + size * 0.6f, cy
                );
                g.fillPath(triangle);
                break;
            }

            case Type::Pause:
            {
                float barWidth = size * 0.25f;
                float gap = size * 0.2f;
                g.fillRect(cx - gap - barWidth, cy - size * 0.4f, barWidth, size * 0.8f);
                g.fillRect(cx + gap, cy - size * 0.4f, barWidth, size * 0.8f);
                break;
            }

            case Type::Stop:
            {
                float rectSize = size * 0.7f;
                g.fillRect(cx - rectSize / 2, cy - rectSize / 2, rectSize, rectSize);
                break;
            }

            case Type::Record:
            {
                g.fillEllipse(cx - size * 0.4f, cy - size * 0.4f, size * 0.8f, size * 0.8f);
                break;
            }

            case Type::Loop:
            {
                juce::Path loop;
                loop.addArc(cx - size * 0.4f, cy - size * 0.3f,
                           size * 0.8f, size * 0.6f,
                           0, juce::MathConstants<float>::pi * 1.5f, true);
                g.strokePath(loop, juce::PathStrokeType(2.0f));

                // Arrow
                juce::Path arrow;
                arrow.addTriangle(
                    cx + size * 0.3f, cy - size * 0.1f,
                    cx + size * 0.5f, cy - size * 0.3f,
                    cx + size * 0.5f, cy + size * 0.1f
                );
                g.fillPath(arrow);
                break;
            }

            case Type::Metronome:
            {
                // Simple metronome shape
                juce::Path metronome;
                metronome.addTriangle(
                    cx - size * 0.35f, cy + size * 0.4f,
                    cx + size * 0.35f, cy + size * 0.4f,
                    cx, cy - size * 0.5f
                );
                g.strokePath(metronome, juce::PathStrokeType(1.5f));

                // Pendulum
                g.drawLine(cx, cy - size * 0.3f, cx + size * 0.2f, cy + size * 0.2f, 2.0f);
                break;
            }
        }
    }

    juce::String getDescription() const
    {
        switch (buttonType)
        {
            case Type::Play:      return "Start playback";
            case Type::Pause:     return "Pause playback";
            case Type::Stop:      return "Stop and return to start";
            case Type::Record:    return "Record on armed tracks";
            case Type::Loop:      return "Toggle loop mode";
            case Type::Metronome: return "Toggle metronome";
            default:              return "";
        }
    }

    Type buttonType;
    juce::String accessibleLabel;
    bool isActive = false;

    juce::Colour normalColor   {0xFF2A2A3A};
    juce::Colour activeColor   {0xFF00D9FF};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TransportButton)
};

//==============================================================================
// Transport Bar
//==============================================================================

class TransportBar : public juce::Component,
                     public juce::Timer
{
public:
    TransportBar()
    {
        // Create buttons
        stopButton = std::make_unique<TransportButton>(TransportButton::Type::Stop, "Stop");
        stopButton->onClick = [this]() { stop(); };
        addAndMakeVisible(stopButton.get());

        playPauseButton = std::make_unique<TransportButton>(TransportButton::Type::Play, "Play");
        playPauseButton->onClick = [this]() { togglePlayPause(); };
        addAndMakeVisible(playPauseButton.get());

        recordButton = std::make_unique<TransportButton>(TransportButton::Type::Record, "Record");
        recordButton->onClick = [this]() { toggleRecord(); };
        recordButton->setActiveColor(juce::Colour(0xFFFF4444));
        addAndMakeVisible(recordButton.get());

        loopButton = std::make_unique<TransportButton>(TransportButton::Type::Loop, "Loop");
        loopButton->onClick = [this]() { toggleLoop(); };
        addAndMakeVisible(loopButton.get());

        metronomeButton = std::make_unique<TransportButton>(TransportButton::Type::Metronome, "Metronome");
        metronomeButton->onClick = [this]() { toggleMetronome(); };
        addAndMakeVisible(metronomeButton.get());

        // Time display
        timeDisplay.setText("00:00:00.000", juce::dontSendNotification);
        timeDisplay.setFont(juce::Font(juce::Font::getDefaultMonospacedFontName(), 24.0f, juce::Font::bold));
        timeDisplay.setColour(juce::Label::textColourId, juce::Colour(0xFF00D9FF));
        timeDisplay.setJustificationType(juce::Justification::centred);
        addAndMakeVisible(timeDisplay);

        // Tempo control
        tempoSlider.setRange(20.0, 300.0, 0.1);
        tempoSlider.setValue(120.0);
        tempoSlider.setSliderStyle(juce::Slider::LinearHorizontal);
        tempoSlider.setTextBoxStyle(juce::Slider::TextBoxRight, false, 60, 24);
        tempoSlider.setColour(juce::Slider::thumbColourId, juce::Colour(0xFF00D9FF));
        tempoSlider.setColour(juce::Slider::trackColourId, juce::Colour(0xFF3A3A4A));
        tempoSlider.setTextValueSuffix(" BPM");
        addAndMakeVisible(tempoSlider);

        startTimer(33);  // ~30fps for time display
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF1A1A24));

        // Bottom border
        g.setColour(juce::Colour(0xFF2A2A3A));
        g.drawLine(0, static_cast<float>(getHeight()),
                  static_cast<float>(getWidth()), static_cast<float>(getHeight()), 1.0f);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10, 8);

        int buttonSize = 44;  // WCAG minimum touch target

        // Transport buttons on left
        auto buttonArea = bounds.removeFromLeft(buttonSize * 5 + 40);

        stopButton->setBounds(buttonArea.removeFromLeft(buttonSize));
        buttonArea.removeFromLeft(8);

        playPauseButton->setBounds(buttonArea.removeFromLeft(buttonSize));
        buttonArea.removeFromLeft(8);

        recordButton->setBounds(buttonArea.removeFromLeft(buttonSize));
        buttonArea.removeFromLeft(16);

        loopButton->setBounds(buttonArea.removeFromLeft(buttonSize));
        buttonArea.removeFromLeft(8);

        metronomeButton->setBounds(buttonArea.removeFromLeft(buttonSize));

        // Time display in center
        bounds.removeFromLeft(20);
        timeDisplay.setBounds(bounds.removeFromLeft(180));

        // Tempo on right
        bounds.removeFromLeft(20);
        tempoSlider.setBounds(bounds.removeFromLeft(200));
    }

    void timerCallback() override
    {
        if (isPlaying)
        {
            currentTimeMs += 33;
            updateTimeDisplay();
        }
    }

    // Public interface
    void togglePlayPause()
    {
        isPlaying = !isPlaying;
        playPauseButton->setActive(isPlaying);

        if (onTransportChange)
            onTransportChange(isPlaying ? TransportState::Playing : TransportState::Paused);
    }

    void stop()
    {
        isPlaying = false;
        isRecording = false;
        currentTimeMs = 0;

        playPauseButton->setActive(false);
        recordButton->setActive(false);
        updateTimeDisplay();

        if (onTransportChange)
            onTransportChange(TransportState::Stopped);
    }

    void toggleRecord()
    {
        isRecording = !isRecording;
        recordButton->setActive(isRecording);

        if (isRecording && !isPlaying)
        {
            isPlaying = true;
            playPauseButton->setActive(true);
        }

        if (onTransportChange)
            onTransportChange(isRecording ? TransportState::Recording :
                            (isPlaying ? TransportState::Playing : TransportState::Stopped));
    }

    void toggleLoop()
    {
        isLooping = !isLooping;
        loopButton->setActive(isLooping);
    }

    void toggleMetronome()
    {
        metronomeActive = !metronomeActive;
        metronomeButton->setActive(metronomeActive);
    }

    double getTempo() const { return tempoSlider.getValue(); }
    void setTempo(double bpm) { tempoSlider.setValue(bpm); }

    enum class TransportState { Stopped, Playing, Paused, Recording };
    std::function<void(TransportState)> onTransportChange;

private:
    void updateTimeDisplay()
    {
        int ms = currentTimeMs % 1000;
        int totalSeconds = currentTimeMs / 1000;
        int seconds = totalSeconds % 60;
        int minutes = (totalSeconds / 60) % 60;
        int hours = totalSeconds / 3600;

        timeDisplay.setText(
            juce::String::formatted("%02d:%02d:%02d.%03d", hours, minutes, seconds, ms),
            juce::dontSendNotification);
    }

    std::unique_ptr<TransportButton> stopButton;
    std::unique_ptr<TransportButton> playPauseButton;
    std::unique_ptr<TransportButton> recordButton;
    std::unique_ptr<TransportButton> loopButton;
    std::unique_ptr<TransportButton> metronomeButton;

    juce::Label timeDisplay;
    juce::Slider tempoSlider;

    bool isPlaying = false;
    bool isRecording = false;
    bool isLooping = false;
    bool metronomeActive = false;
    int64_t currentTimeMs = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TransportBar)
};

} // namespace GUI
} // namespace Echoelmusic
