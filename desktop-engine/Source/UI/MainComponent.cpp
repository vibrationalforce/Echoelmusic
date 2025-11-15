// MainComponent.cpp
// Implementation of main component

#include "MainComponent.h"

MainComponent::MainComponent()
{
    // Create components
    oscManager = std::make_unique<OSCManager>();
    synthesizer = std::make_unique<EnhancedSynthesizer>();

    // Setup
    setupOSC();
    setupUI();

    // Start audio
    setAudioChannels(0, 2);  // 0 inputs, 2 outputs

    // Start UI update timer (30 Hz)
    startTimer(33);

    setSize(600, 450);  // Slightly taller for breath rate label
}

MainComponent::~MainComponent()
{
    stopTimer();
    shutdownAudio();
    oscManager->shutdown();
}

void MainComponent::setupOSC()
{
    // Initialize OSC server on port 8000
    if (oscManager->initialize(8000))
    {
        oscConnected = true;
        DBG("✅ OSC Server started on port 8000");
    }
    else
    {
        oscConnected = false;
        DBG("❌ Failed to start OSC Server");
    }

    // Setup callbacks for biofeedback data
    oscManager->onHeartRateReceived = [this](float bpm)
    {
        synthesizer->setHeartRate(bpm);
        displayHeartRate.store(bpm);

        // Auto-detect iOS client address on first message
        // (In real app, iOS would send its IP via /echoel/sync/hello)
        // For now, we'll set it manually or via command line
    };

    oscManager->onHRVReceived = [this](float ms)
    {
        synthesizer->setHRV(ms);
        displayHRV.store(ms);
    };

    oscManager->onBreathRateReceived = [this](float breathsPerMin)
    {
        synthesizer->setBreathRate(breathsPerMin);
        displayBreathRate.store(breathsPerMin);
    };

    oscManager->onParameterChanged = [this](juce::String paramName, float value)
    {
        if (paramName == "hrv_coherence")
        {
            synthesizer->setHRVCoherence(value);
            displayCoherence.store(value);
        }
    };

    oscManager->onPitchReceived = [this](float frequency, float confidence)
    {
        synthesizer->setPitch(frequency, confidence);
    };

    // Set iOS client address (hardcoded for now - should be configurable)
    // TODO: Add UI for entering iOS device IP address
    // oscManager->setClientAddress("192.168.1.50", 8001);
}

void MainComponent::setupUI()
{
    // Title
    addAndMakeVisible(titleLabel);
    titleLabel.setText("🎵 Echoelmusic Desktop Engine (Enhanced)", juce::dontSendNotification);
    titleLabel.setFont(juce::Font(24.0f, juce::Font::bold));
    titleLabel.setJustificationType(juce::Justification::centred);

    // Status
    addAndMakeVisible(statusLabel);
    statusLabel.setText(oscConnected ? "✅ OSC Server: Listening on port 8000" :
                                       "❌ OSC Server: Failed to start",
                        juce::dontSendNotification);
    statusLabel.setJustificationType(juce::Justification::centred);

    // Biofeedback displays
    addAndMakeVisible(heartRateLabel);
    heartRateLabel.setText("♥️ Heart Rate: --", juce::dontSendNotification);
    heartRateLabel.setFont(juce::Font(18.0f));

    addAndMakeVisible(hrvLabel);
    hrvLabel.setText("🫀 HRV: --", juce::dontSendNotification);
    hrvLabel.setFont(juce::Font(18.0f));

    addAndMakeVisible(breathRateLabel);
    breathRateLabel.setText("🌬️ Breath Rate: --", juce::dontSendNotification);
    breathRateLabel.setFont(juce::Font(18.0f));

    addAndMakeVisible(coherenceLabel);
    coherenceLabel.setText("🧘 Coherence: --", juce::dontSendNotification);
    coherenceLabel.setFont(juce::Font(18.0f));

    addAndMakeVisible(frequencyLabel);
    frequencyLabel.setText("🎹 Frequency: 220 Hz", juce::dontSendNotification);
    frequencyLabel.setFont(juce::Font(18.0f));
}

void MainComponent::prepareToPlay(int samplesPerBlockExpected, double sampleRate)
{
    synthesizer->prepareToPlay(samplesPerBlockExpected, sampleRate);
}

void MainComponent::getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill)
{
    synthesizer->getNextAudioBlock(bufferToFill);
}

void MainComponent::releaseResources()
{
    synthesizer->releaseResources();
}

void MainComponent::paint(juce::Graphics& g)
{
    g.fillAll(getLookAndFeel().findColour(juce::ResizableWindow::backgroundColourId));
}

void MainComponent::resized()
{
    auto area = getLocalBounds().reduced(20);

    // Title
    titleLabel.setBounds(area.removeFromTop(40));
    area.removeFromTop(10);

    // Status
    statusLabel.setBounds(area.removeFromTop(30));
    area.removeFromTop(30);

    // Biofeedback displays (centered)
    auto displayArea = area.withSizeKeepingCentre(400, 250);

    heartRateLabel.setBounds(displayArea.removeFromTop(40));
    displayArea.removeFromTop(10);

    hrvLabel.setBounds(displayArea.removeFromTop(40));
    displayArea.removeFromTop(10);

    breathRateLabel.setBounds(displayArea.removeFromTop(40));
    displayArea.removeFromTop(10);

    coherenceLabel.setBounds(displayArea.removeFromTop(40));
    displayArea.removeFromTop(10);

    frequencyLabel.setBounds(displayArea.removeFromTop(40));
}

void MainComponent::timerCallback()
{
    // Update UI labels (runs on message thread, safe)
    float hr = displayHeartRate.load();
    float hrv = displayHRV.load();
    float breathRate = displayBreathRate.load();
    float coherence = displayCoherence.load();

    if (hr > 0.0f)
    {
        heartRateLabel.setText("♥️ Heart Rate: " + juce::String(hr, 1) + " bpm",
                               juce::dontSendNotification);
    }

    if (hrv > 0.0f)
    {
        hrvLabel.setText("🫀 HRV: " + juce::String(hrv, 1) + " ms",
                         juce::dontSendNotification);
    }

    if (breathRate > 0.0f)
    {
        breathRateLabel.setText("🌬️ Breath Rate: " + juce::String(breathRate, 1) + " /min",
                                juce::dontSendNotification);
    }

    if (coherence > 0.0f)
    {
        coherenceLabel.setText("🧘 Coherence: " + juce::String(coherence * 100.0f, 1) + "%",
                               juce::dontSendNotification);
    }

    // Calculate frequency from HR
    if (hr > 0.0f)
    {
        float freq = 100.0f + (800.0f - 100.0f) * ((hr - 40.0f) / (200.0f - 40.0f));
        frequencyLabel.setText("🎹 Frequency: " + juce::String(freq, 1) + " Hz",
                               juce::dontSendNotification);
    }

    // Send OSC feedback to iOS periodically (every ~333ms)
    feedbackCounter++;
    if (feedbackCounter >= feedbackInterval)
    {
        feedbackCounter = 0;
        sendOSCFeedback();
    }
}

void MainComponent::sendOSCFeedback()
{
    if (!oscConnected || !oscManager)
        return;

    // Get analysis data from synthesizer
    float rms = synthesizer->getRMS();
    float peak = synthesizer->getPeak();
    std::vector<float> spectrum = synthesizer->getSpectrum();

    // Send to iOS
    oscManager->sendAudioAnalysis(rms, peak);
    oscManager->sendSpectrum(spectrum);
}
