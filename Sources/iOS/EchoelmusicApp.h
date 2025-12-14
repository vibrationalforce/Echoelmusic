#pragma once

#include <JuceHeader.h>

/**
 * Echoelmusic iOS/iPad App
 *
 * Main application class for iOS platform.
 * Handles app lifecycle, audio session, and UI.
 */
class EchoelmusicApp : public juce::JUCEApplication
{
public:
    //==========================================================================
    EchoelmusicApp() = default;

    //==========================================================================
    // JUCEApplication overrides
    //==========================================================================

    const juce::String getApplicationName() override
    {
        return "Echoelmusic";
    }

    const juce::String getApplicationVersion() override
    {
        return "1.0.0";
    }

    void initialise(const juce::String& commandLine) override;
    void shutdown() override;

    void systemRequestedQuit() override;
    void anotherInstanceStarted(const juce::String& commandLine) override;

    //==========================================================================
    // iOS-specific
    //==========================================================================

    /** Setup iOS audio session for low-latency recording */
    void setupAudioSession();

    /** Handle interruptions (phone calls, etc.) */
    void handleAudioSessionInterruption(bool interrupted);

    /** Handle route changes (headphones plugged/unplugged) */
    void handleAudioSessionRouteChange();

    /** Get main window for notifications */
    class MainWindow* getMainWindow() const { return mainWindow.get(); }

private:
    std::unique_ptr<juce::AudioDeviceManager> audioDeviceManager;
    std::unique_ptr<class MainWindow> mainWindow;
    std::unique_ptr<class AudioEngine> audioEngine;

    // Transport state
    bool isPlaying = false;
    bool wasPlayingBeforeInterrupt = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelmusicApp)
};
