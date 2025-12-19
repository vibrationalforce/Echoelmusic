#pragma once

#include <JuceHeader.h>
#include "../Hardware/OSCManager.h"
#include "BioReactiveOSCBridge.h"
#include "SessionOSCBridge.h"
#include "VisualOSCBridge.h"
#include "SystemOSCBridge.h"
#include "AudioOSCBridge.h"
#include "DMXOSCBridge.h"

namespace Echoelmusic {

/**
 * @brief Master OSC Router
 *
 * Unified management for ALL OSC subsystems. Single entry point for
 * initializing, configuring, and updating the complete OSC API.
 *
 * Prevents duplication by:
 * - Centralizing OSC manager instance
 * - Coordinating all bridge lifecycles
 * - Providing batch update methods
 * - Managing OSC bundles for efficiency
 *
 * Namespace Coverage:
 * - /echoelmusic/bio/*      → BioReactiveOSCBridge
 * - /echoelmusic/mod/*      → BioReactiveOSCBridge
 * - /echoelmusic/trigger/*  → BioReactiveOSCBridge
 * - /echoelmusic/session/*  → SessionOSCBridge
 * - /echoelmusic/visual/*   → VisualOSCBridge
 * - /echoelmusic/system/*   → SystemOSCBridge
 * - /echoelmusic/audio/*    → AudioOSCBridge
 * - /echoelmusic/dmx/*      → DMXOSCBridge
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class MasterOSCRouter : public juce::Timer
{
public:
    //==========================================================================
    /**
     * @brief Configuration for all OSC subsystems
     */
    struct Config
    {
        // Network
        juce::String receiveHost = "0.0.0.0";
        int receivePort = 8000;
        juce::String sendHost = "127.0.0.1";
        int sendPort = 9000;

        // Update rates (Hz)
        int bioUpdateRate = 1;           // Biofeedback: 1 Hz
        int transportUpdateRate = 10;    // Audio transport: 10 Hz
        int meterUpdateRate = 30;        // Level meters: 30 Hz
        int dmxUpdateRate = 44;          // DMX refresh: 44 Hz
        int visualUpdateRate = 60;       // Visual status: 60 Hz (if needed)

        // Features
        bool enableBiofeedback = true;
        bool enableSession = true;
        bool enableVisual = true;
        bool enableSystem = true;
        bool enableAudio = true;
        bool enableDMX = true;

        // Performance
        bool useBundles = true;          // Use OSC bundles for efficiency
        int maxBundleSize = 100;         // Max messages per bundle
    };

    //==========================================================================
    MasterOSCRouter(OSCManager& oscManager) : oscManager(oscManager)
    {
    }

    ~MasterOSCRouter()
    {
        stopTimer();
        cleanup();
    }

    //==========================================================================
    /**
     * @brief Initialize all OSC subsystems
     */
    void initialize(const Config& configuration = Config())
    {
        config = configuration;

        // Start OSC receiver
        oscManager.startReceiver(config.receivePort);

        // Add default sender
        oscManager.addSender("default", config.sendHost, config.sendPort);

        DBG("MasterOSCRouter initialized:");
        DBG("  Receive: " << config.receiveHost << ":" << config.receivePort);
        DBG("  Send: " << config.sendHost << ":" << config.sendPort);

        // Start update timer (1000ms / fastest update rate)
        int timerInterval = juce::jmax(1, 1000 / config.meterUpdateRate);
        startTimer(timerInterval);
    }

    /**
     * @brief Register biofeedback bridge
     */
    void registerBiofeedbackBridge(BioReactiveOSCBridge* bridge)
    {
        bioReactiveBridge = bridge;
    }

    /**
     * @brief Register session bridge
     */
    void registerSessionBridge(SessionOSCBridge* bridge)
    {
        sessionBridge = bridge;
    }

    /**
     * @brief Register visual bridge
     */
    void registerVisualBridge(VisualOSCBridge* bridge)
    {
        visualBridge = bridge;
    }

    /**
     * @brief Register system bridge
     */
    void registerSystemBridge(SystemOSCBridge* bridge)
    {
        systemBridge = bridge;
    }

    /**
     * @brief Register audio bridge
     */
    void registerAudioBridge(AudioOSCBridge* bridge)
    {
        audioBridge = bridge;
    }

    /**
     * @brief Register DMX bridge
     */
    void registerDMXBridge(DMXOSCBridge* bridge)
    {
        dmxBridge = bridge;
    }

    //==========================================================================
    /**
     * @brief Update all OSC subsystems (call from timer or main loop)
     */
    void update()
    {
        updateCounter++;

        // Bio-reactive (low rate: 1 Hz)
        if (config.enableBiofeedback && bioReactiveBridge != nullptr)
        {
            if (updateCounter % (config.meterUpdateRate / config.bioUpdateRate) == 0)
            {
                // Would call bioReactiveBridge->sendBioData() with latest data
            }
        }

        // Audio transport (medium rate: 10 Hz)
        if (config.enableAudio && audioBridge != nullptr)
        {
            if (updateCounter % (config.meterUpdateRate / config.transportUpdateRate) == 0)
            {
                audioBridge->sendTransportStatus();
            }
        }

        // Audio meters (high rate: 30 Hz)
        if (config.enableAudio && audioBridge != nullptr)
        {
            audioBridge->sendLevelMeters();
        }

        // DMX output (very high rate: 44 Hz)
        if (config.enableDMX && dmxBridge != nullptr)
        {
            if (updateCounter % (config.meterUpdateRate / config.dmxUpdateRate) == 0)
            {
                dmxBridge->updateDMXOutput();
            }
        }

        // Reset counter to prevent overflow
        if (updateCounter >= 1000000)
            updateCounter = 0;
    }

    //==========================================================================
    /**
     * @brief Send complete status of ALL subsystems
     * Useful for initial sync or client reconnection
     */
    void sendCompleteStatus()
    {
        if (config.enableBiofeedback && bioReactiveBridge != nullptr)
        {
            // Would send current bio data
        }

        if (config.enableSession && sessionBridge != nullptr)
        {
            sessionBridge->sendSessionStatus();
        }

        if (config.enableVisual && visualBridge != nullptr)
        {
            visualBridge->sendVisualStatus();
        }

        if (config.enableSystem && systemBridge != nullptr)
        {
            systemBridge->sendSystemStatus();
        }

        if (config.enableAudio && audioBridge != nullptr)
        {
            audioBridge->sendAudioStatus();
        }

        if (config.enableDMX && dmxBridge != nullptr)
        {
            dmxBridge->sendDMXStatus();
        }

        DBG("MasterOSCRouter: Sent complete status");
    }

    //==========================================================================
    /**
     * @brief Configure for specific target software
     */
    void configureForTouchDesigner()
    {
        config.sendHost = "127.0.0.1";
        config.sendPort = 9000;
        config.receivePort = 8000;
        config.meterUpdateRate = 60;  // TD can handle high rate

        oscManager.stopReceiver();
        oscManager.startReceiver(config.receivePort);
        oscManager.removeSender("default");
        oscManager.addSender("default", config.sendHost, config.sendPort);

        DBG("MasterOSCRouter: Configured for TouchDesigner");
    }

    void configureForResolume()
    {
        config.sendHost = "127.0.0.1";
        config.sendPort = 7000;
        config.receivePort = 7001;
        config.meterUpdateRate = 30;

        oscManager.stopReceiver();
        oscManager.startReceiver(config.receivePort);
        oscManager.removeSender("default");
        oscManager.addSender("default", config.sendHost, config.sendPort);

        DBG("MasterOSCRouter: Configured for Resolume");
    }

    void configureForMaxMSP()
    {
        config.sendHost = "127.0.0.1";
        config.sendPort = 8000;
        config.receivePort = 9000;
        config.meterUpdateRate = 30;

        oscManager.stopReceiver();
        oscManager.startReceiver(config.receivePort);
        oscManager.removeSender("default");
        oscManager.addSender("default", config.sendHost, config.sendPort);

        DBG("MasterOSCRouter: Configured for Max/MSP");
    }

    void configureForAbleton()
    {
        config.sendHost = "127.0.0.1";
        config.sendPort = 9001;
        config.receivePort = 9002;
        config.meterUpdateRate = 20;

        oscManager.stopReceiver();
        oscManager.startReceiver(config.receivePort);
        oscManager.removeSender("default");
        oscManager.addSender("default", config.sendHost, config.sendPort);

        DBG("MasterOSCRouter: Configured for Ableton Live (Max for Live)");
    }

    //==========================================================================
    /**
     * @brief Get configuration
     */
    const Config& getConfig() const { return config; }

    /**
     * @brief Get OSC manager (for advanced use)
     */
    OSCManager& getOSCManager() { return oscManager; }

    /**
     * @brief Get statistics
     */
    struct Stats
    {
        int updateCounter;
        int registeredBridges;
        bool receiverActive;
        int numSenders;
    };

    Stats getStats() const
    {
        Stats stats;
        stats.updateCounter = updateCounter;
        stats.registeredBridges = 0;

        if (bioReactiveBridge != nullptr) stats.registeredBridges++;
        if (sessionBridge != nullptr) stats.registeredBridges++;
        if (visualBridge != nullptr) stats.registeredBridges++;
        if (systemBridge != nullptr) stats.registeredBridges++;
        if (audioBridge != nullptr) stats.registeredBridges++;
        if (dmxBridge != nullptr) stats.registeredBridges++;

        stats.receiverActive = oscManager.isReceiverActive();
        stats.numSenders = oscManager.getNumSenders();

        return stats;
    }

private:
    //==========================================================================
    void timerCallback() override
    {
        update();
    }

    void cleanup()
    {
        oscManager.stopReceiver();
    }

    //==========================================================================
    OSCManager& oscManager;
    Config config;

    // Bridge references (non-owning)
    BioReactiveOSCBridge* bioReactiveBridge = nullptr;
    SessionOSCBridge* sessionBridge = nullptr;
    VisualOSCBridge* visualBridge = nullptr;
    SystemOSCBridge* systemBridge = nullptr;
    AudioOSCBridge* audioBridge = nullptr;
    DMXOSCBridge* dmxBridge = nullptr;

    // Update tracking
    int updateCounter = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MasterOSCRouter)
};

//==============================================================================
/**
 * @brief Example: Complete OSC Setup
 *
 * Shows how to initialize all OSC subsystems efficiently without duplication.
 */
#if 0
void setupCompleteOSC()
{
    // Create OSC manager (single instance)
    auto oscManager = std::make_unique<OSCManager>();

    // Create master router
    auto masterRouter = std::make_unique<MasterOSCRouter>(*oscManager);

    // Create all bridges (passing existing components)
    auto bioReactiveBridge = std::make_unique<BioReactiveOSCBridge>();
    auto sessionBridge = std::make_unique<SessionOSCBridge>(sessionManager, *oscManager);
    auto visualBridge = std::make_unique<VisualOSCBridge>(visualForge, *oscManager);
    auto systemBridge = std::make_unique<SystemOSCBridge>(*oscManager);
    auto audioBridge = std::make_unique<AudioOSCBridge>(audioEngine, *oscManager);
    auto dmxBridge = std::make_unique<DMXOSCBridge>(dmxSceneManager, artNetController, *oscManager);

    // Register all bridges with router
    masterRouter->registerBiofeedbackBridge(bioReactiveBridge.get());
    masterRouter->registerSessionBridge(sessionBridge.get());
    masterRouter->registerVisualBridge(visualBridge.get());
    masterRouter->registerSystemBridge(systemBridge.get());
    masterRouter->registerAudioBridge(audioBridge.get());
    masterRouter->registerDMXBridge(dmxBridge.get());

    // Configure for target software (optional)
    masterRouter->configureForTouchDesigner();

    // Initialize (starts receiver, timer, etc.)
    masterRouter->initialize();

    // Send initial status to client
    masterRouter->sendCompleteStatus();

    // Now all OSC endpoints are active and no duplication exists!
}
#endif

} // namespace Echoelmusic
