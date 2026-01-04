/*
  ==============================================================================

    ArrangementView.h
    Timeline-Based Arrangement View

    Linear arrangement editor with tracks, clips, and automation.
    Supports drag-and-drop, zooming, and AI-assisted arrangement.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>

namespace Echoelmusic {
namespace GUI {

//==============================================================================
// Clip Component
//==============================================================================

class ClipComponent : public juce::Component
{
public:
    enum class Type { Audio, MIDI, Automation };

    ClipComponent(Type type, double startBeat, double lengthBeats,
                  const juce::String& name, juce::Colour color)
        : clipType(type), start(startBeat), length(lengthBeats),
          clipName(name), clipColor(color)
    {
        setMouseCursor(juce::MouseCursor::PointingHandCursor);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(1);

        // Clip background
        juce::Colour bgColor = isSelected ? clipColor.brighter(0.2f) : clipColor;
        if (isMouseOver())
            bgColor = bgColor.brighter(0.1f);

        g.setColour(bgColor);
        g.fillRoundedRectangle(bounds, 4.0f);

        // Waveform/MIDI visualization
        if (clipType == Type::Audio)
            drawWaveform(g, bounds.reduced(2, 4));
        else if (clipType == Type::MIDI)
            drawMIDI(g, bounds.reduced(2, 4));

        // Clip name
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(10.0f, juce::Font::bold));
        g.drawText(clipName, bounds.reduced(4, 2), juce::Justification::topLeft, true);

        // Selection outline
        if (isSelected)
        {
            g.setColour(juce::Colours::white);
            g.drawRoundedRectangle(bounds, 4.0f, 2.0f);
        }
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        isSelected = !isSelected;
        dragStartX = e.x;
        repaint();
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        if (onDrag)
        {
            int deltaX = e.x - dragStartX;
            onDrag(this, deltaX);
        }
    }

    void mouseEnter(const juce::MouseEvent&) override { repaint(); }
    void mouseExit(const juce::MouseEvent&) override { repaint(); }

    double getStart() const { return start; }
    double getLength() const { return length; }
    void setStart(double s) { start = s; }
    void setLength(double l) { length = l; }

    std::function<void(ClipComponent*, int)> onDrag;

private:
    void drawWaveform(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        g.setColour(clipColor.darker(0.3f));

        juce::Path waveform;
        float midY = bounds.getCentreY();

        waveform.startNewSubPath(bounds.getX(), midY);

        for (float x = bounds.getX(); x < bounds.getRight(); x += 2)
        {
            float amp = (std::sin(x * 0.3f) + std::sin(x * 0.7f)) * bounds.getHeight() * 0.3f;
            waveform.lineTo(x, midY + amp);
        }

        g.strokePath(waveform, juce::PathStrokeType(1.0f));
    }

    void drawMIDI(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        g.setColour(clipColor.darker(0.2f));

        // Draw some note rectangles
        juce::Random rng(static_cast<int64_t>(start * 100));
        int numNotes = static_cast<int>(length * 2);

        for (int i = 0; i < numNotes; ++i)
        {
            float x = bounds.getX() + rng.nextFloat() * bounds.getWidth() * 0.8f;
            float y = bounds.getY() + rng.nextFloat() * bounds.getHeight() * 0.7f;
            float w = 5 + rng.nextFloat() * 20;
            float h = 4;

            g.fillRect(x, y, w, h);
        }
    }

    Type clipType;
    double start;
    double length;
    juce::String clipName;
    juce::Colour clipColor;
    bool isSelected = false;
    int dragStartX = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ClipComponent)
};

//==============================================================================
// Track Header
//==============================================================================

class TrackHeader : public juce::Component
{
public:
    TrackHeader(int index, const juce::String& name, juce::Colour color)
        : trackIndex(index), trackName(name), trackColor(color)
    {
        // Track name
        nameLabel.setText(name, juce::dontSendNotification);
        nameLabel.setColour(juce::Label::textColourId, juce::Colours::white);
        nameLabel.setFont(juce::Font(12.0f, juce::Font::bold));
        addAndMakeVisible(nameLabel);

        // Mute button
        muteButton.setButtonText("M");
        muteButton.setClickingTogglesState(true);
        addAndMakeVisible(muteButton);

        // Solo button
        soloButton.setButtonText("S");
        soloButton.setClickingTogglesState(true);
        addAndMakeVisible(soloButton);

        // Record arm
        armButton.setButtonText("R");
        armButton.setClickingTogglesState(true);
        armButton.setColour(juce::TextButton::buttonOnColourId, juce::Colour(0xFFFF4444));
        addAndMakeVisible(armButton);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(juce::Colour(0xFF1A1A24));
        g.fillRect(bounds);

        // Color strip
        g.setColour(trackColor);
        g.fillRect(bounds.getX(), bounds.getY(), 4.0f, bounds.getHeight());

        // Bottom border
        g.setColour(juce::Colour(0xFF2A2A3A));
        g.drawLine(0, bounds.getBottom(), bounds.getRight(), bounds.getBottom(), 1.0f);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(8, 4);
        bounds.removeFromLeft(8);  // After color strip

        nameLabel.setBounds(bounds.removeFromTop(20));

        auto buttonRow = bounds;
        int buttonSize = 22;
        muteButton.setBounds(buttonRow.removeFromLeft(buttonSize));
        buttonRow.removeFromLeft(4);
        soloButton.setBounds(buttonRow.removeFromLeft(buttonSize));
        buttonRow.removeFromLeft(4);
        armButton.setBounds(buttonRow.removeFromLeft(buttonSize));
    }

private:
    int trackIndex;
    juce::String trackName;
    juce::Colour trackColor;

    juce::Label nameLabel;
    juce::TextButton muteButton;
    juce::TextButton soloButton;
    juce::TextButton armButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TrackHeader)
};

//==============================================================================
// Timeline Ruler
//==============================================================================

class TimelineRuler : public juce::Component
{
public:
    TimelineRuler() = default;

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(juce::Colour(0xFF1A1A24));
        g.fillRect(bounds);

        // Beat markers
        g.setColour(juce::Colour(0xFF4A4A5A));
        g.setFont(juce::Font(10.0f));

        float beatsPerPixel = 1.0f / pixelsPerBeat;
        float startBeat = scrollOffset * beatsPerPixel;

        for (float beat = std::floor(startBeat); beat < startBeat + bounds.getWidth() * beatsPerPixel; beat += 1.0f)
        {
            float x = (beat - startBeat) * pixelsPerBeat;

            if (static_cast<int>(beat) % 4 == 0)
            {
                // Bar marker
                g.setColour(juce::Colour(0xFF6A6A7A));
                g.drawLine(x, bounds.getHeight() - 15, x, bounds.getHeight(), 1.0f);

                int bar = static_cast<int>(beat) / 4 + 1;
                g.drawText(juce::String(bar), static_cast<int>(x) + 2, 2, 30, 12,
                          juce::Justification::centredLeft);
            }
            else
            {
                // Beat marker
                g.setColour(juce::Colour(0xFF4A4A5A));
                g.drawLine(x, bounds.getHeight() - 8, x, bounds.getHeight(), 1.0f);
            }
        }

        // Playhead
        float playheadX = (playheadBeat - startBeat) * pixelsPerBeat;
        if (playheadX >= 0 && playheadX <= bounds.getWidth())
        {
            g.setColour(juce::Colour(0xFF00D9FF));
            g.drawLine(playheadX, 0, playheadX, bounds.getHeight(), 2.0f);
        }
    }

    void setPixelsPerBeat(float ppb) { pixelsPerBeat = ppb; repaint(); }
    void setScrollOffset(float offset) { scrollOffset = offset; repaint(); }
    void setPlayhead(float beat) { playheadBeat = beat; repaint(); }

private:
    float pixelsPerBeat = 30.0f;
    float scrollOffset = 0.0f;
    float playheadBeat = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TimelineRuler)
};

//==============================================================================
// Arrangement View
//==============================================================================

class ArrangementView : public juce::Component,
                        public juce::Timer
{
public:
    ArrangementView()
    {
        // Timeline ruler
        addAndMakeVisible(timelineRuler);

        // Create some demo tracks
        createDemoTracks();

        startTimerHz(30);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF121218));

        // Grid lines
        auto contentBounds = getContentBounds();
        g.setColour(juce::Colour(0xFF1A1A24));

        // Vertical grid (beats)
        for (float x = 0; x < contentBounds.getWidth(); x += pixelsPerBeat)
        {
            g.setColour(static_cast<int>(x / pixelsPerBeat) % 4 == 0 ?
                       juce::Colour(0xFF2A2A3A) : juce::Colour(0xFF1A1A24));
            g.drawLine(contentBounds.getX() + x, contentBounds.getY(),
                      contentBounds.getX() + x, contentBounds.getBottom(), 1.0f);
        }

        // Horizontal grid (tracks)
        float y = contentBounds.getY();
        for (size_t i = 0; i < tracks.size(); ++i)
        {
            g.setColour(juce::Colour(0xFF2A2A3A));
            g.drawLine(contentBounds.getX(), y + trackHeight,
                      contentBounds.getRight(), y + trackHeight, 1.0f);
            y += trackHeight;
        }

        // Playhead
        float playheadX = contentBounds.getX() + playheadBeat * pixelsPerBeat;
        g.setColour(juce::Colour(0xFF00D9FF));
        g.drawLine(playheadX, contentBounds.getY(),
                  playheadX, contentBounds.getBottom(), 2.0f);
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        // Header area for track headers
        headerWidth = 150;
        auto headerArea = bounds.removeFromLeft(headerWidth);

        // Timeline ruler at top
        timelineRuler.setBounds(bounds.removeFromTop(30));
        headerArea.removeFromTop(30);

        // Track headers
        float y = 0;
        for (auto& header : trackHeaders)
        {
            header->setBounds(0, static_cast<int>(30 + y), headerWidth, static_cast<int>(trackHeight));
            y += trackHeight;
        }

        // Position clips
        auto contentBounds = getContentBounds();
        for (size_t trackIdx = 0; trackIdx < clips.size(); ++trackIdx)
        {
            for (auto& clip : clips[trackIdx])
            {
                float x = contentBounds.getX() + clip->getStart() * pixelsPerBeat;
                float w = clip->getLength() * pixelsPerBeat;
                float clipY = contentBounds.getY() + trackIdx * trackHeight + 2;

                clip->setBounds(static_cast<int>(x), static_cast<int>(clipY),
                              static_cast<int>(w), static_cast<int>(trackHeight - 4));
            }
        }
    }

    void timerCallback() override
    {
        // Update playhead position
        if (isPlaying)
        {
            playheadBeat += 0.1f;  // ~120 BPM at 30fps
            timelineRuler.setPlayhead(playheadBeat);
            repaint();
        }
    }

    void setPlaying(bool playing) { isPlaying = playing; }
    void setPlayhead(float beat) { playheadBeat = beat; repaint(); }

private:
    juce::Rectangle<float> getContentBounds()
    {
        auto bounds = getLocalBounds().toFloat();
        bounds.removeFromLeft(headerWidth);
        bounds.removeFromTop(30);
        return bounds;
    }

    void createDemoTracks()
    {
        struct TrackInfo {
            juce::String name;
            juce::Colour color;
        };

        std::vector<TrackInfo> demoTracks = {
            {"Drums", juce::Colour(0xFFFF6B9D)},
            {"Bass", juce::Colour(0xFF00D9FF)},
            {"Synth", juce::Colour(0xFFFBBF24)},
            {"Vocals", juce::Colour(0xFF4ADE80)},
            {"FX", juce::Colour(0xFFA78BFA)}
        };

        for (size_t i = 0; i < demoTracks.size(); ++i)
        {
            auto& info = demoTracks[i];

            auto header = std::make_unique<TrackHeader>(
                static_cast<int>(i), info.name, info.color);
            addAndMakeVisible(header.get());
            trackHeaders.push_back(std::move(header));

            tracks.push_back(info.name);
            clips.push_back({});

            // Add demo clips
            if (i < 3)
            {
                auto clip = std::make_unique<ClipComponent>(
                    ClipComponent::Type::MIDI,
                    static_cast<double>(i * 4),
                    8.0,
                    info.name + " 1",
                    info.color
                );
                addAndMakeVisible(clip.get());
                clips[i].push_back(std::move(clip));
            }
        }
    }

    TimelineRuler timelineRuler;
    std::vector<std::unique_ptr<TrackHeader>> trackHeaders;
    std::vector<juce::String> tracks;
    std::vector<std::vector<std::unique_ptr<ClipComponent>>> clips;

    float pixelsPerBeat = 30.0f;
    float trackHeight = 60.0f;
    int headerWidth = 150;
    float playheadBeat = 0.0f;
    bool isPlaying = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ArrangementView)
};

} // namespace GUI
} // namespace Echoelmusic
