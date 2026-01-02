#include "EchoelmusicApp.h"
#include "../UI/MainWindow.h"

#if JUCE_IOS
#import <AVFoundation/AVFoundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#endif

//==============================================================================
void EchoelmusicApp::initialise(const juce::String& commandLine)
{
    juce::ignoreUnused(commandLine);

    // Initialize Bluetooth Audio Manager first
    bluetoothManager = std::make_unique<Echoelmusic::BluetoothAudioManager>();

    // Setup iOS audio session for optimal Bluetooth support
    setupAudioSession();

    // Initialize audio device manager
    audioDeviceManager = std::make_unique<juce::AudioDeviceManager>();

    // Setup audio device with optimal settings
    juce::String audioError = audioDeviceManager->initialise(
        2,      // Number of input channels
        2,      // Number of output channels
        nullptr,// XML settings (null = use defaults)
        true,   // Select default device if needed
        juce::String(), // Preferred device name
        nullptr // Preferred audio device setup
    );

    if (audioError.isNotEmpty())
    {
        juce::AlertWindow::showMessageBoxAsync(
            juce::MessageBoxIconType::WarningIcon,
            "Audio Device Error",
            audioError
        );
    }

    // Configure buffer size based on Bluetooth status
    auto* device = audioDeviceManager->getCurrentAudioDevice();
    if (device != nullptr)
    {
        auto bufferSizes = device->getAvailableBufferSizes();
        if (!bufferSizes.isEmpty())
        {
            int targetSize;

            if (bluetoothManager->isBluetoothActive())
            {
                // Bluetooth active: use larger buffer to prevent underruns
                // Bluetooth already adds significant latency, so small buffer gains are negligible
                auto codecInfo = bluetoothManager->getCodecInfo();

                if (codecInfo.supportsLowLatency)
                {
                    targetSize = 128;  // ~2.7ms @ 48kHz for low-latency codecs
                }
                else
                {
                    targetSize = 256;  // ~5.3ms @ 48kHz for standard codecs
                }

                DBG("Bluetooth active (" << codecInfo.name << "), using buffer size: " << targetSize);
            }
            else
            {
                // Wired connection: use smallest buffer for lowest latency
                targetSize = 64;  // ~1.3ms @ 48kHz
                DBG("Wired connection, using ultra-low latency buffer: " << targetSize);
            }

            // Find closest available buffer size
            int selectedSize = bufferSizes[0];

            if (bufferSizes.contains(targetSize))
            {
                selectedSize = targetSize;
            }
            else
            {
                int minDiff = std::abs(bufferSizes[0] - targetSize);
                for (int i = 1; i < bufferSizes.size(); ++i)
                {
                    int diff = std::abs(bufferSizes[i] - targetSize);
                    if (diff < minDiff)
                    {
                        minDiff = diff;
                        selectedSize = bufferSizes[i];
                    }
                }
            }

            device->setBufferSize(selectedSize);

            DBG("Audio buffer size set to: " << selectedSize << " samples");
            DBG("Internal latency: ~" << juce::String(selectedSize * 1000.0 / device->getCurrentSampleRate(), 1) << "ms");
        }

        // Initialize Bluetooth manager with sample rate
        bluetoothManager->initialize(device->getCurrentSampleRate());
    }

    // Setup Bluetooth state change callback
    bluetoothManager->setStateChangeCallback([this](bool active, Echoelmusic::BluetoothCodec codec)
    {
        juce::ignoreUnused(codec);

        juce::MessageManager::callAsync([this, active]()
        {
            if (active)
            {
                showBluetoothLatencyWarningIfNeeded();
            }

            // Reconfigure audio session when Bluetooth state changes
            updateAudioSessionForBluetooth();
        });
    });

    // Create main window
    mainWindow = std::make_unique<MainWindow>(getApplicationName(), audioDeviceManager.get());
    mainWindow->setVisible(true);

    // Show initial Bluetooth warning if needed
    showBluetoothLatencyWarningIfNeeded();

    DBG("Echoelmusic initialized");
    DBG("Bluetooth Status: " << bluetoothManager->getStatusString());
}

void EchoelmusicApp::shutdown()
{
    // Clean shutdown
    mainWindow = nullptr;
    audioDeviceManager = nullptr;
    bluetoothManager = nullptr;
}

void EchoelmusicApp::systemRequestedQuit()
{
    // Allow quit (save state first if needed)
    quit();
}

void EchoelmusicApp::anotherInstanceStarted(const juce::String& commandLine)
{
    juce::ignoreUnused(commandLine);
    // iOS is single-instance, this shouldn't be called
}

//==============================================================================
// iOS Audio Session Setup
//==============================================================================

void EchoelmusicApp::setupAudioSession()
{
#if JUCE_IOS
    // Configure iOS audio session for optimal audio with Bluetooth support

    auto* session = [AVAudioSession sharedInstance];
    NSError* error = nil;

    // Category options for best Bluetooth support:
    // - AllowBluetoothA2DP: Enable high-quality stereo Bluetooth (A2DP profile)
    // - DefaultToSpeaker: Use speaker when no headphones connected
    // - AllowAirPlay: Support AirPlay streaming
    AVAudioSessionCategoryOptions options =
        AVAudioSessionCategoryOptionAllowBluetoothA2DP |
        AVAudioSessionCategoryOptionDefaultToSpeaker |
        AVAudioSessionCategoryOptionAllowAirPlay;

    // If low latency mode is enabled, add measurement mode compatibility
    if (lowLatencyModeEnabled)
    {
        // In low latency mode, we might sacrifice some Bluetooth features
        // for reduced processing delay
    }

    // Set category: PlayAndRecord for full-duplex audio
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:options
                   error:&error];

    if (error != nil)
    {
        DBG("Error setting audio session category: " <<
            [[error localizedDescription] UTF8String]);
        return;
    }

    // Set mode based on use case
    AVAudioSessionMode mode;

    if (lowLatencyModeEnabled)
    {
        // Measurement mode: lowest latency, minimal processing
        mode = AVAudioSessionModeMeasurement;
    }
    else
    {
        // Default mode: balanced for music production
        mode = AVAudioSessionModeDefault;
    }

    [session setMode:mode error:&error];

    if (error != nil)
    {
        DBG("Error setting audio session mode: " <<
            [[error localizedDescription] UTF8String]);
    }

    // Set preferred buffer duration
    // Smaller = lower latency but higher CPU usage
    NSTimeInterval bufferDuration;

    if (bluetoothManager && bluetoothManager->isBluetoothActive())
    {
        // Bluetooth: use moderate buffer (BT already adds latency)
        auto codecInfo = bluetoothManager->getCodecInfo();

        if (codecInfo.supportsLowLatency)
        {
            bufferDuration = 0.003;  // 3ms for low-latency codecs
        }
        else
        {
            bufferDuration = 0.005;  // 5ms for standard codecs
        }
    }
    else
    {
        // Wired: use smallest buffer for lowest latency
        bufferDuration = 0.00133;  // ~1.3ms (64 samples @ 48kHz)
    }

    [session setPreferredIOBufferDuration:bufferDuration error:&error];

    if (error != nil)
    {
        DBG("Error setting buffer duration: " <<
            [[error localizedDescription] UTF8String]);
    }

    // Set preferred sample rate (48kHz for professional audio)
    [session setPreferredSampleRate:48000.0 error:&error];

    if (error != nil)
    {
        DBG("Error setting sample rate: " <<
            [[error localizedDescription] UTF8String]);
    }

    // Request input gain control
    [session setPreferredInputNumberOfChannels:2 error:&error];
    [session setPreferredOutputNumberOfChannels:2 error:&error];

    // Activate audio session
    [session setActive:YES error:&error];

    if (error != nil)
    {
        DBG("Error activating audio session: " <<
            [[error localizedDescription] UTF8String]);
    }
    else
    {
        DBG("iOS Audio Session configured successfully:");
        DBG("  Sample Rate: " << session.sampleRate << " Hz");
        DBG("  Buffer Duration: " << session.IOBufferDuration * 1000.0 << " ms");
        DBG("  Input Channels: " << session.inputNumberOfChannels);
        DBG("  Output Channels: " << session.outputNumberOfChannels);
        DBG("  Mode: " << (lowLatencyModeEnabled ? "Low Latency" : "Default"));
    }

    // Register for interruption notifications (phone calls, etc.)
    [[NSNotificationCenter defaultCenter]
        addObserverForName:AVAudioSessionInterruptionNotification
                    object:session
                     queue:nil
                usingBlock:^(NSNotification* notification)
        {
            NSNumber* interruptionType = notification.userInfo[AVAudioSessionInterruptionTypeKey];

            if (interruptionType.unsignedIntegerValue == AVAudioSessionInterruptionTypeBegan)
            {
                handleAudioSessionInterruption(true);
            }
            else if (interruptionType.unsignedIntegerValue == AVAudioSessionInterruptionTypeEnded)
            {
                NSNumber* options = notification.userInfo[AVAudioSessionInterruptionOptionKey];

                if (options.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume)
                {
                    handleAudioSessionInterruption(false);
                }
            }
        }];

    // Register for route change notifications (Bluetooth connect/disconnect)
    [[NSNotificationCenter defaultCenter]
        addObserverForName:AVAudioSessionRouteChangeNotification
                    object:session
                     queue:nil
                usingBlock:^(NSNotification* notification)
        {
            NSNumber* reason = notification.userInfo[AVAudioSessionRouteChangeReasonKey];

            DBG("Audio route changed, reason: " << reason.integerValue);

            // Reasons:
            // 1 = NewDeviceAvailable (headphones/BT connected)
            // 2 = OldDeviceUnavailable (headphones/BT disconnected)
            // 3 = CategoryChange
            // 4 = Override
            // 8 = WakeFromSleep

            handleAudioSessionRouteChange();
        }];

    // Configure Bluetooth manager with iOS session
    if (bluetoothManager)
    {
        bluetoothManager->configureIOSAudioSession();
    }
#endif
}

void EchoelmusicApp::handleAudioSessionInterruption(bool interrupted)
{
    if (interrupted)
    {
        DBG("Audio session interrupted (phone call, alarm, etc.)");

        // Pause playback/recording
        // The audio engine should handle this gracefully
    }
    else
    {
        DBG("Audio session interruption ended");

#if JUCE_IOS
        // Reactivate audio session
        auto* session = [AVAudioSession sharedInstance];
        NSError* error = nil;

        [session setActive:YES error:&error];

        if (error != nil)
        {
            DBG("Error reactivating audio session: " <<
                [[error localizedDescription] UTF8String]);
        }
#endif
    }
}

void EchoelmusicApp::handleAudioSessionRouteChange()
{
    DBG("Audio route changed");

#if JUCE_IOS
    // Log current route
    auto* session = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription* route = session.currentRoute;

    for (AVAudioSessionPortDescription* output in route.outputs)
    {
        DBG("  Output: " << [[output portName] UTF8String] <<
            " (" << [[output portType] UTF8String] << ")");
    }

    for (AVAudioSessionPortDescription* input in route.inputs)
    {
        DBG("  Input: " << [[input portName] UTF8String] <<
            " (" << [[input portType] UTF8String] << ")");
    }
#endif

    // Update Bluetooth manager
    if (bluetoothManager)
    {
        // The manager will auto-detect the new route
        // and update codec/latency information
    }

    // Reconfigure audio session for new route
    updateAudioSessionForBluetooth();

    // Show warning if Bluetooth with high latency
    showBluetoothLatencyWarningIfNeeded();
}

//==============================================================================
// Bluetooth Support
//==============================================================================

void EchoelmusicApp::setLowLatencyMode(bool enabled)
{
    if (lowLatencyModeEnabled != enabled)
    {
        lowLatencyModeEnabled = enabled;

        if (bluetoothManager)
        {
            bluetoothManager->setLowLatencyMode(enabled);
        }

        // Reconfigure audio session
        setupAudioSession();

        DBG("Low latency mode: " << (enabled ? "ENABLED" : "DISABLED"));
    }
}

void EchoelmusicApp::updateAudioSessionForBluetooth()
{
#if JUCE_IOS
    if (!bluetoothManager)
        return;

    auto* session = [AVAudioSession sharedInstance];
    NSError* error = nil;

    // Adjust buffer duration based on Bluetooth state
    NSTimeInterval bufferDuration;

    if (bluetoothManager->isBluetoothActive())
    {
        auto codecInfo = bluetoothManager->getCodecInfo();

        if (codecInfo.supportsLowLatency)
        {
            bufferDuration = 0.003;  // 3ms
        }
        else
        {
            bufferDuration = 0.005;  // 5ms
        }

        DBG("Bluetooth active, adjusting buffer to " << bufferDuration * 1000.0 << "ms");
    }
    else
    {
        bufferDuration = 0.00133;  // 1.3ms for wired

        DBG("Wired audio, using ultra-low latency buffer");
    }

    [session setPreferredIOBufferDuration:bufferDuration error:&error];

    if (error != nil)
    {
        DBG("Error adjusting buffer duration: " <<
            [[error localizedDescription] UTF8String]);
    }
#endif
}

void EchoelmusicApp::showBluetoothLatencyWarningIfNeeded()
{
    if (!bluetoothManager || !bluetoothManager->isBluetoothActive())
        return;

    juce::String warning = bluetoothManager->getLatencyWarning();

    if (warning.isNotEmpty())
    {
        // Show non-modal notification
        // In a full implementation, this would be a toast/banner notification
        DBG("Bluetooth Warning: " << warning);

        // For now, show an alert (in production, use a subtle notification)
        juce::AlertWindow::showMessageBoxAsync(
            juce::MessageBoxIconType::InfoIcon,
            "Bluetooth Audio",
            warning,
            "OK"
        );
    }
}

//==============================================================================
// JUCE Application Entry Point
//==============================================================================

START_JUCE_APPLICATION(EchoelmusicApp)
