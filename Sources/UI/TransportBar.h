#pragma once

#include <JuceHeader.h>
#include "../Audio/AudioEngine.h"

namespace echoelmusic {
namespace ui {

/**
 * @brief Transport bar with play/stop/record controls
 *
 * MVP UI COMPONENT - Essential playback controls
 *
 * Features:
 * - Play/Stop button
 * - Record button
 * - Loop toggle
 * - Time display (current position)
 * - Tempo display/edit
 * - CPU/memory meters
 *
 * @author Claude Code (ULTRATHINK SUPER LASER MODE)
 * @date 2025-11-18
 */
class TransportBar : public juce::Component,
                     public juce::Timer
{
public:
    /**
     * @brief Constructor
     */
    explicit TransportBar(audio::AudioEngine& audioEngine);

    /**
     * @brief Destructor
     */
    ~TransportBar() override;

    // JUCE Component
    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

private:
    /**
     * @brief Update time display
     */
    void updateTimeDisplay();

    /**
     * @brief Format time as MM:SS.mmm
     */
    static juce::String formatTime(double seconds);

private:
    audio::AudioEngine& m_audioEngine;

    // Buttons
    std::unique_ptr<juce::TextButton> m_playButton;
    std::unique_ptr<juce::TextButton> m_stopButton;
    std::unique_ptr<juce::TextButton> m_recordButton;
    std::unique_ptr<juce::ToggleButton> m_loopButton;

    // Labels
    std::unique_ptr<juce::Label> m_timeLabel;
    std::unique_ptr<juce::Label> m_tempoLabel;
    std::unique_ptr<juce::Label> m_cpuLabel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TransportBar)
};

} // namespace ui
} // namespace echoelmusic
