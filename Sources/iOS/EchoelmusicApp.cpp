#include "EchoelmusicApp.h"
#include "../UI/MainWindow.h"

//==============================================================================
void EchoelmusicApp::initialise(const juce::String& commandLine)
{
    juce::ignoreUnused(commandLine);

    // Setup iOS audio session for low-latency
    setupAudioSession();

    // Initialize audio device manager
    audioDeviceManager = std::make_unique<juce::AudioDeviceManager>();

    // Setup audio device with low-latency settings
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

    // Set buffer size for ultra-low latency (64 samples = ~1.3ms @ 48kHz)
    auto* device = audioDeviceManager->getCurrentAudioDevice();
    if (device != nullptr)
    {
        auto bufferSizes = device->getAvailableBufferSizes();
        if (!bufferSizes.isEmpty())
        {
            // Optimized buffer size selection: try 64 first, then smallest available
            constexpr int targetSize = 64;
            int selectedSize = bufferSizes[0];  // Default to first (usually smallest)

            // Check if target size is available (early exit optimization)
            if (bufferSizes.contains(targetSize))
            {
                selectedSize = targetSize;
            }
            else
            {
                // Find closest size to target
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
            DBG("Latency: ~" << juce::String(selectedSize * 1000.0 / device->getCurrentSampleRate(), 1) << "ms");
        }
    }

    // Create main window
    mainWindow = std::make_unique<MainWindow>(getApplicationName(), audioDeviceManager.get());
    mainWindow->setVisible(true);
}

void EchoelmusicApp::shutdown()
{
    // Clean shutdown
    mainWindow = nullptr;
    audioDeviceManager = nullptr;
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
    // Configure iOS audio session for pro audio
    // This requires AVFoundation framework

    auto* session = [AVAudioSession sharedInstance];
    NSError* error = nil;

    // Set category: PlayAndRecord for recording + playback
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:AVAudioSessionCategoryOptionAllowBluetooth |
                        AVAudioSessionCategoryOptionDefaultToSpeaker |
                        AVAudioSessionCategoryOptionMixWithOthers
                   error:&error];

    if (error != nil)
    {
        DBG("Error setting audio session category: " << error.localizedDescription);
        return;
    }

    // Set preferred buffer duration (64 samples @ 48kHz = ~0.00133s)
    NSTimeInterval bufferDuration = 0.00133;
    [session setPreferredIOBufferDuration:bufferDuration error:&error];

    if (error != nil)
    {
        DBG("Error setting buffer duration: " << error.localizedDescription);
    }

    // Set preferred sample rate
    [session setPreferredSampleRate:48000.0 error:&error];

    if (error != nil)
    {
        DBG("Error setting sample rate: " << error.localizedDescription);
    }

    // Activate audio session
    [session setActive:YES error:&error];

    if (error != nil)
    {
        DBG("Error activating audio session: " << error.localizedDescription);
    }
    else
    {
        DBG("iOS Audio Session configured:");
        DBG("  Sample Rate: " << session.sampleRate << " Hz");
        DBG("  Buffer Duration: " << session.IOBufferDuration * 1000.0 << " ms");
        DBG("  Input Channels: " << session.inputNumberOfChannels);
        DBG("  Output Channels: " << session.outputNumberOfChannels);
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
                // Interruption began (phone call, alarm, etc.)
                handleAudioSessionInterruption(true);
            }
            else if (interruptionType.unsignedIntegerValue == AVAudioSessionInterruptionTypeEnded)
            {
                // Interruption ended
                NSNumber* options = notification.userInfo[AVAudioSessionInterruptionOptionKey];

                if (options.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume)
                {
                    // Resume audio
                    handleAudioSessionInterruption(false);
                }
            }
        }];

    // Register for route change notifications (headphones plugged/unplugged)
    [[NSNotificationCenter defaultCenter]
        addObserverForName:AVAudioSessionRouteChangeNotification
                    object:session
                     queue:nil
                usingBlock:^(NSNotification* notification)
        {
            handleAudioSessionRouteChange();
        }];
#endif
}

void EchoelmusicApp::handleAudioSessionInterruption(bool interrupted)
{
    if (interrupted)
    {
        DBG("Audio session interrupted (phone call, etc.)");

        // Pause playback/recording
        wasPlayingBeforeInterrupt = isPlaying;
        if (audioEngine != nullptr && isPlaying)
        {
            audioEngine->pause();
            isPlaying = false;
        }
    }
    else
    {
        DBG("Audio session interruption ended");

        // Resume if user was playing before interruption
        if (audioEngine != nullptr && wasPlayingBeforeInterrupt)
        {
            audioEngine->resume();
            isPlaying = true;
        }
        wasPlayingBeforeInterrupt = false;
    }
}

void EchoelmusicApp::handleAudioSessionRouteChange()
{
    DBG("Audio route changed (headphones plugged/unplugged, etc.)");

    // Update UI to reflect new audio route
    juce::String routeMessage = "Audio output changed";
    if (auto* mainWindow = getMainWindow())
    {
        mainWindow->showNotification(routeMessage, 2000);  // 2 second toast
    }
}

//==============================================================================
// JUCE Application Entry Point
//==============================================================================

START_JUCE_APPLICATION(EchoelmusicApp)
