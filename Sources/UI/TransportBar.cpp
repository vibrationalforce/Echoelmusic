#include "TransportBar.h"

namespace echoelmusic {
namespace ui {

// ============================================================================
// CONSTRUCTOR / DESTRUCTOR
// ============================================================================

TransportBar::TransportBar(audio::AudioEngine& audioEngine)
    : m_audioEngine(audioEngine)
{
    // Create buttons
    m_playButton = std::make_unique<juce::TextButton>("Play");
    m_playButton->onClick = [this]()
    {
        if (m_audioEngine.isPlaying())
        {
            m_audioEngine.stop();
            m_playButton->setButtonText("Play");
        }
        else
        {
            m_audioEngine.play();
            m_playButton->setButtonText("Stop");
        }
    };
    addAndMakeVisible(m_playButton.get());

    m_stopButton = std::make_unique<juce::TextButton>("Stop");
    m_stopButton->onClick = [this]()
    {
        m_audioEngine.stop();
        m_audioEngine.setPosition(0.0);
        m_playButton->setButtonText("Play");
    };
    addAndMakeVisible(m_stopButton.get());

    m_recordButton = std::make_unique<juce::TextButton>("Record");
    m_recordButton->setColour(juce::TextButton::buttonColourId, juce::Colours::red.withAlpha(0.5f));
    m_recordButton->onClick = [this]()
    {
        // TODO: Implement record functionality
        DBG("Record button clicked");
    };
    addAndMakeVisible(m_recordButton.get());

    m_loopButton = std::make_unique<juce::ToggleButton>("Loop");
    m_loopButton->onStateChange = [this]()
    {
        bool loopEnabled = m_loopButton->getToggleState();
        m_audioEngine.setLooping(loopEnabled);
        DBG("Loop: " + juce::String(loopEnabled ? "ON" : "OFF"));
    };
    addAndMakeVisible(m_loopButton.get());

    // Create labels
    m_timeLabel = std::make_unique<juce::Label>("Time", "00:00.000");
    m_timeLabel->setFont(juce::Font(18.0f, juce::Font::bold));
    m_timeLabel->setJustificationType(juce::Justification::centred);
    m_timeLabel->setColour(juce::Label::textColourId, juce::Colour(0xFF00E5FF));  // Cyan
    addAndMakeVisible(m_timeLabel.get());

    m_tempoLabel = std::make_unique<juce::Label>("Tempo", "128 BPM");
    m_tempoLabel->setFont(juce::Font(14.0f));
    m_tempoLabel->setJustificationType(juce::Justification::centred);
    m_tempoLabel->setColour(juce::Label::textColourId, juce::Colour(0xFF00E5FF));
    addAndMakeVisible(m_tempoLabel.get());

    m_cpuLabel = std::make_unique<juce::Label>("CPU", "CPU: 0%");
    m_cpuLabel->setFont(juce::Font(12.0f));
    m_cpuLabel->setJustificationType(juce::Justification::centredRight);
    m_cpuLabel->setColour(juce::Label::textColourId, juce::Colour(0xFF00E5FF));
    addAndMakeVisible(m_cpuLabel.get());

    // Start update timer (60 FPS)
    startTimer(1000 / 60);
}

TransportBar::~TransportBar()
{
    stopTimer();
}

// ============================================================================
// JUCE COMPONENT
// ============================================================================

void TransportBar::paint(juce::Graphics& g)
{
    // Background (vaporwave dark)
    g.fillAll(juce::Colour(0xFF16213E));

    // Top border (magenta)
    g.setColour(juce::Colour(0xFFFF00FF));
    g.drawLine(0, 0, (float)getWidth(), 0, 2.0f);
}

void TransportBar::resized()
{
    auto bounds = getLocalBounds().reduced(10);

    // Left section: Transport controls
    auto leftSection = bounds.removeFromLeft(300);

    m_playButton->setBounds(leftSection.removeFromLeft(80).reduced(2));
    m_stopButton->setBounds(leftSection.removeFromLeft(80).reduced(2));
    m_recordButton->setBounds(leftSection.removeFromLeft(80).reduced(2));
    m_loopButton->setBounds(leftSection.removeFromLeft(60).reduced(2));

    // Center: Time display
    m_timeLabel->setBounds(bounds.removeFromLeft(150).reduced(2));

    // Right of center: Tempo
    m_tempoLabel->setBounds(bounds.removeFromLeft(100).reduced(2));

    // Far right: CPU meter
    m_cpuLabel->setBounds(bounds.removeFromRight(100).reduced(2));
}

void TransportBar::timerCallback()
{
    updateTimeDisplay();
}

// ============================================================================
// HELPERS
// ============================================================================

void TransportBar::updateTimeDisplay()
{
    // Update time
    double currentTime = m_audioEngine.getCurrentPosition();
    m_timeLabel->setText(formatTime(currentTime), juce::dontSendNotification);

    // Update tempo
    double tempo = m_audioEngine.getTempo();
    m_tempoLabel->setText(juce::String(tempo, 1) + " BPM", juce::dontSendNotification);

    // Update CPU (placeholder - would need actual CPU measurement)
    // m_cpuLabel->setText("CPU: " + juce::String(cpuUsage, 1) + "%", juce::dontSendNotification);

    // Update play button text based on state
    if (m_audioEngine.isPlaying())
    {
        if (m_playButton->getButtonText() != "Stop")
            m_playButton->setButtonText("Stop");
    }
    else
    {
        if (m_playButton->getButtonText() != "Play")
            m_playButton->setButtonText("Play");
    }
}

juce::String TransportBar::formatTime(double seconds)
{
    int minutes = (int)(seconds / 60.0);
    int secs = (int)seconds % 60;
    int millis = (int)((seconds - (int)seconds) * 1000);

    return juce::String(minutes).paddedLeft('0', 2) + ":" +
           juce::String(secs).paddedLeft('0', 2) + "." +
           juce::String(millis).paddedLeft('0', 3);
}

} // namespace ui
} // namespace echoelmusic
