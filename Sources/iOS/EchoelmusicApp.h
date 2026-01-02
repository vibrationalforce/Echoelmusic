#pragma once

#include <JuceHeader.h>
#include "../Hardware/BluetoothAudioManager.h"

/**
 * Echoelmusic iOS/iPad App
 *
 * Main application class for iOS platform.
 * Handles app lifecycle, audio session, and UI.
 *
 * Features:
 * - Optimized Bluetooth audio support (all BT generations)
 * - Automatic codec detection and latency compensation
 * - A2DP high-quality streaming
 * - Ultra-low latency for wired connections
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
    // iOS Audio Session
    //==========================================================================

    /** Setup iOS audio session with optimal Bluetooth support */
    void setupAudioSession();

    /** Handle interruptions (phone calls, etc.) */
    void handleAudioSessionInterruption(bool interrupted);

    /** Handle route changes (headphones plugged/unplugged, Bluetooth connected) */
    void handleAudioSessionRouteChange();

    //==========================================================================
    // Bluetooth Management
    //==========================================================================

    /** Get Bluetooth audio manager */
    Echoelmusic::BluetoothAudioManager* getBluetoothManager()
    {
        return bluetoothManager.get();
    }

    /** Check if Bluetooth audio is active */
    bool isBluetoothAudioActive() const
    {
        return bluetoothManager && bluetoothManager->isBluetoothActive();
    }

    /** Get current Bluetooth status string */
    juce::String getBluetoothStatus() const
    {
        if (bluetoothManager)
            return bluetoothManager->getStatusString();
        return "Bluetooth Manager not initialized";
    }

    /** Enable/disable low latency mode */
    void setLowLatencyMode(bool enabled);

    /** Check if current audio setup is suitable for real-time monitoring */
    bool isSuitableForMonitoring() const
    {
        if (!bluetoothManager)
            return true;
        return bluetoothManager->isSuitableForMonitoring();
    }

private:
    std::unique_ptr<juce::AudioDeviceManager> audioDeviceManager;
    std::unique_ptr<class MainWindow> mainWindow;
    std::unique_ptr<Echoelmusic::BluetoothAudioManager> bluetoothManager;

    bool lowLatencyModeEnabled = false;

    /** Configure audio session based on current Bluetooth state */
    void updateAudioSessionForBluetooth();

    /** Show latency warning if Bluetooth is active */
    void showBluetoothLatencyWarningIfNeeded();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelmusicApp)
};
