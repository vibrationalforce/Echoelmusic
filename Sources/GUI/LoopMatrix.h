/*
  ==============================================================================

    LoopMatrix.h
    Ralph Wiggum Loop Genius - Visual Loop Grid

    Ableton-style loop triggering with bio-reactive visual feedback.
    Supports 4x4 loop grid with layering and effects.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <array>
#include <functional>

namespace Echoelmusic {
namespace GUI {

//==============================================================================
// Loop Cell
//==============================================================================

class LoopCell : public juce::Component,
                 public juce::Timer
{
public:
    enum class State { Empty, Loaded, Playing, Recording, Queued };

    LoopCell(int row, int col)
        : rowIndex(row), colIndex(col)
    {
        setWantsKeyboardFocus(true);
        startTimerHz(30);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(2);

        // Background based on state
        juce::Colour bgColor;
        switch (state)
        {
            case State::Empty:     bgColor = juce::Colour(0xFF1A1A24); break;
            case State::Loaded:    bgColor = juce::Colour(0xFF2A2A3A); break;
            case State::Playing:   bgColor = baseColor.withAlpha(0.6f); break;
            case State::Recording: bgColor = juce::Colour(0xFFFF4444).withAlpha(0.6f); break;
            case State::Queued:    bgColor = baseColor.withAlpha(0.3f); break;
        }

        if (isMouseOver())
            bgColor = bgColor.brighter(0.1f);

        g.setColour(bgColor);
        g.fillRoundedRectangle(bounds, 6.0f);

        // Border
        g.setColour(isMouseOver() ? baseColor : juce::Colour(0xFF3A3A4A));
        g.drawRoundedRectangle(bounds, 6.0f, 1.5f);

        // Playing indicator - waveform animation
        if (state == State::Playing)
        {
            drawWaveform(g, bounds.reduced(8));
        }
        else if (state == State::Recording)
        {
            drawRecordingIndicator(g, bounds);
        }
        else if (state == State::Queued)
        {
            drawQueuedIndicator(g, bounds);
        }

        // Loop name
        if (!loopName.isEmpty())
        {
            g.setColour(juce::Colours::white.withAlpha(0.9f));
            g.setFont(juce::Font(11.0f, juce::Font::bold));
            g.drawText(loopName, bounds.reduced(5), juce::Justification::bottomLeft);
        }

        // Focus ring
        if (hasKeyboardFocus(true))
        {
            g.setColour(juce::Colour(0xFF00D9FF));
            g.drawRoundedRectangle(bounds, 6.0f, 2.0f);
        }
    }

    void timerCallback() override
    {
        if (state == State::Playing || state == State::Recording)
        {
            animationPhase += 0.1f;
            if (animationPhase > juce::MathConstants<float>::twoPi)
                animationPhase -= juce::MathConstants<float>::twoPi;
            repaint();
        }
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        if (e.mods.isRightButtonDown())
        {
            showContextMenu();
        }
        else
        {
            trigger();
        }
    }

    void mouseEnter(const juce::MouseEvent&) override { repaint(); }
    void mouseExit(const juce::MouseEvent&) override { repaint(); }

    bool keyPressed(const juce::KeyPress& key) override
    {
        if (key == juce::KeyPress::returnKey || key == juce::KeyPress::spaceKey)
        {
            trigger();
            return true;
        }
        if (key == juce::KeyPress::deleteKey)
        {
            clear();
            return true;
        }
        return false;
    }

    void trigger()
    {
        if (state == State::Empty)
        {
            // Start recording
            state = State::Recording;
            if (onRecord) onRecord(rowIndex, colIndex);
        }
        else if (state == State::Playing)
        {
            // Stop
            state = State::Loaded;
            if (onStop) onStop(rowIndex, colIndex);
        }
        else
        {
            // Start playing
            state = State::Queued;
            if (onPlay) onPlay(rowIndex, colIndex);
            // After quantization, would become Playing
        }
        repaint();
    }

    void clear()
    {
        state = State::Empty;
        loopName = "";
        repaint();
    }

    void setState(State newState) { state = newState; repaint(); }
    State getState() const { return state; }

    void setLoopName(const juce::String& name) { loopName = name; repaint(); }
    void setColor(juce::Colour color) { baseColor = color; repaint(); }

    std::function<void(int, int)> onPlay;
    std::function<void(int, int)> onStop;
    std::function<void(int, int)> onRecord;

private:
    void drawWaveform(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        g.setColour(baseColor);

        int numBars = 8;
        float barWidth = bounds.getWidth() / (numBars * 2);

        for (int i = 0; i < numBars; ++i)
        {
            float phase = animationPhase + i * 0.5f;
            float height = (std::sin(phase) + 1.0f) / 2.0f * bounds.getHeight() * 0.6f + 4;

            float x = bounds.getX() + i * barWidth * 2 + barWidth / 2;
            float y = bounds.getCentreY() - height / 2;

            g.fillRoundedRectangle(x, y, barWidth, height, 2.0f);
        }
    }

    void drawRecordingIndicator(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        // Pulsing red dot
        float pulse = (std::sin(animationPhase * 2) + 1.0f) / 2.0f;
        g.setColour(juce::Colour(0xFFFF4444).withAlpha(0.5f + pulse * 0.5f));

        float dotSize = std::min(bounds.getWidth(), bounds.getHeight()) * 0.3f;
        g.fillEllipse(bounds.getCentreX() - dotSize / 2,
                     bounds.getCentreY() - dotSize / 2,
                     dotSize, dotSize);
    }

    void drawQueuedIndicator(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        // Blinking border
        float blink = (std::sin(animationPhase * 4) + 1.0f) / 2.0f;
        g.setColour(baseColor.withAlpha(blink));
        g.drawRoundedRectangle(bounds.reduced(2), 6.0f, 2.0f);
    }

    void showContextMenu()
    {
        juce::PopupMenu menu;
        menu.addItem(1, "Clear Loop");
        menu.addItem(2, "Duplicate");
        menu.addSeparator();
        menu.addItem(3, "Half Speed");
        menu.addItem(4, "Double Speed");
        menu.addItem(5, "Reverse");
        menu.addSeparator();
        menu.addItem(6, "Set Color...");

        menu.showMenuAsync(juce::PopupMenu::Options(),
            [this](int result) {
                if (result == 1) clear();
                // Handle other options
            });
    }

    int rowIndex;
    int colIndex;
    State state = State::Empty;
    juce::String loopName;
    juce::Colour baseColor {0xFF00D9FF};
    float animationPhase = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LoopCell)
};

//==============================================================================
// Loop Matrix
//==============================================================================

class LoopMatrix : public juce::Component
{
public:
    static constexpr int ROWS = 4;
    static constexpr int COLS = 4;

    LoopMatrix()
    {
        // Create cells
        for (int row = 0; row < ROWS; ++row)
        {
            for (int col = 0; col < COLS; ++col)
            {
                auto cell = std::make_unique<LoopCell>(row, col);

                // Color scheme per row
                juce::Colour rowColor;
                switch (row)
                {
                    case 0: rowColor = juce::Colour(0xFF00D9FF); break;  // Cyan
                    case 1: rowColor = juce::Colour(0xFFFF6B9D); break;  // Pink
                    case 2: rowColor = juce::Colour(0xFFFBBF24); break;  // Yellow
                    case 3: rowColor = juce::Colour(0xFF4ADE80); break;  // Green
                }
                cell->setColor(rowColor);

                cell->onPlay = [this](int r, int c) { handlePlay(r, c); };
                cell->onStop = [this](int r, int c) { handleStop(r, c); };
                cell->onRecord = [this](int r, int c) { handleRecord(r, c); };

                addAndMakeVisible(cell.get());
                cells[row][col] = std::move(cell);
            }
        }

        // Scene launch buttons
        for (int row = 0; row < ROWS; ++row)
        {
            auto button = std::make_unique<juce::TextButton>(">");
            button->onClick = [this, row]() { launchScene(row); };
            addAndMakeVisible(button.get());
            sceneLaunchButtons[row] = std::move(button);
        }

        // Title
        titleLabel.setText("LOOPS", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(11.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xFF6B6B7B));
        addAndMakeVisible(titleLabel);

        // Stop all button
        stopAllButton.setButtonText("Stop All");
        stopAllButton.onClick = [this]() { stopAll(); };
        addAndMakeVisible(stopAllButton);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF121218));

        // Grid lines
        g.setColour(juce::Colour(0xFF2A2A3A));

        auto gridBounds = getGridBounds();
        float cellWidth = gridBounds.getWidth() / COLS;
        float cellHeight = gridBounds.getHeight() / ROWS;

        for (int i = 1; i < COLS; ++i)
        {
            float x = gridBounds.getX() + i * cellWidth;
            g.drawLine(x, gridBounds.getY(), x, gridBounds.getBottom(), 1.0f);
        }

        for (int i = 1; i < ROWS; ++i)
        {
            float y = gridBounds.getY() + i * cellHeight;
            g.drawLine(gridBounds.getX(), y, gridBounds.getRight(), y, 1.0f);
        }
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);

        // Title and controls at top
        auto topBar = bounds.removeFromTop(30);
        titleLabel.setBounds(topBar.removeFromLeft(60));
        stopAllButton.setBounds(topBar.removeFromRight(80));

        bounds.removeFromTop(10);

        // Scene launch buttons on right
        auto launchArea = bounds.removeFromRight(40);

        // Grid area
        auto gridBounds = bounds;
        float cellWidth = (gridBounds.getWidth()) / COLS;
        float cellHeight = gridBounds.getHeight() / ROWS;

        for (int row = 0; row < ROWS; ++row)
        {
            for (int col = 0; col < COLS; ++col)
            {
                cells[row][col]->setBounds(
                    static_cast<int>(gridBounds.getX() + col * cellWidth),
                    static_cast<int>(gridBounds.getY() + row * cellHeight),
                    static_cast<int>(cellWidth - 4),
                    static_cast<int>(cellHeight - 4)
                );
            }

            // Scene launch button
            sceneLaunchButtons[row]->setBounds(
                launchArea.getX() + 5,
                static_cast<int>(gridBounds.getY() + row * cellHeight + cellHeight / 2 - 15),
                30, 30
            );
        }
    }

    void triggerLoop(int index)
    {
        if (index >= 0 && index < ROWS * COLS)
        {
            int row = index / COLS;
            int col = index % COLS;
            cells[row][col]->trigger();
        }
    }

private:
    juce::Rectangle<float> getGridBounds()
    {
        auto bounds = getLocalBounds().reduced(10);
        bounds.removeFromTop(40);
        bounds.removeFromRight(40);
        return bounds.toFloat();
    }

    void handlePlay(int row, int col)
    {
        // Stop other cells in same row (exclusive groups)
        for (int c = 0; c < COLS; ++c)
        {
            if (c != col && cells[row][c]->getState() == LoopCell::State::Playing)
            {
                cells[row][c]->setState(LoopCell::State::Loaded);
            }
        }

        cells[row][col]->setState(LoopCell::State::Playing);
    }

    void handleStop(int row, int col)
    {
        cells[row][col]->setState(LoopCell::State::Loaded);
    }

    void handleRecord(int row, int col)
    {
        cells[row][col]->setLoopName("Loop " + juce::String(row + 1) + "-" + juce::String(col + 1));
        cells[row][col]->setState(LoopCell::State::Recording);
    }

    void launchScene(int row)
    {
        for (int col = 0; col < COLS; ++col)
        {
            if (cells[row][col]->getState() != LoopCell::State::Empty)
            {
                cells[row][col]->trigger();
            }
        }
    }

    void stopAll()
    {
        for (int row = 0; row < ROWS; ++row)
        {
            for (int col = 0; col < COLS; ++col)
            {
                if (cells[row][col]->getState() == LoopCell::State::Playing)
                {
                    cells[row][col]->setState(LoopCell::State::Loaded);
                }
            }
        }
    }

    std::array<std::array<std::unique_ptr<LoopCell>, COLS>, ROWS> cells;
    std::array<std::unique_ptr<juce::TextButton>, ROWS> sceneLaunchButtons;

    juce::Label titleLabel;
    juce::TextButton stopAllButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LoopMatrix)
};

} // namespace GUI
} // namespace Echoelmusic
