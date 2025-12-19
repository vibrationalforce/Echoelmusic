#pragma once

#include <JuceHeader.h>
#include "../BioData/BioReactiveModulator.h"
#include "../BioData/HRVProcessor.h"
#include "../Hardware/OSCManager.h"

namespace Echoelmusic {

/**
 * @brief Bio-Reactive OSC Bridge
 *
 * Sends bio-data and modulated parameters to external software via OSC.
 *
 * Compatible with:
 * - TouchDesigner
 * - Resolume Arena/Avenue
 * - Ableton Live (via Max for Live)
 * - VDMX
 * - MadMapper
 * - Any OSC-capable software
 *
 * OSC Address Space:
 * /echoelmusic/bio/hrv          [float 0-1]     Heart Rate Variability (normalized)
 * /echoelmusic/bio/coherence    [float 0-1]     HeartMath Coherence
 * /echoelmusic/bio/heartrate    [float 40-200]  Heart Rate BPM
 * /echoelmusic/bio/stress       [float 0-1]     Stress Index
 * /echoelmusic/bio/breathing    [float 0-1]     Breathing Rate (normalized)
 * /echoelmusic/bio/sdnn         [float ms]      Standard Deviation of NN intervals
 * /echoelmusic/bio/rmssd        [float ms]      Root Mean Square of Successive Differences
 * /echoelmusic/bio/lfpower      [float]         Low Frequency Power (0.04-0.15 Hz)
 * /echoelmusic/bio/hfpower      [float]         High Frequency Power (0.15-0.4 Hz)
 * /echoelmusic/bio/lfhf         [float]         LF/HF Ratio (autonomic balance)
 *
 * /echoelmusic/mod/filter       [float 20-20000] Filter Cutoff Hz
 * /echoelmusic/mod/reverb       [float 0-1]      Reverb Mix
 * /echoelmusic/mod/compression  [float 1-20]     Compression Ratio
 * /echoelmusic/mod/delay        [float 0-2000]   Delay Time ms
 * /echoelmusic/mod/distortion   [float 0-1]      Distortion Amount
 * /echoelmusic/mod/lfo          [float 0.1-20]   LFO Rate Hz
 *
 * /echoelmusic/trigger/beat     [bang]           Heart beat trigger
 * /echoelmusic/trigger/breath   [bang]           Breath trigger
 */
class BioReactiveOSCBridge
{
public:
    //==========================================================================
    // Configuration

    struct Config
    {
        juce::String targetHost = "127.0.0.1";
        int targetPort = 9000;           // Default OSC port
        int updateRateHz = 30;           // Send updates at 30 Hz
        bool sendBioData = true;
        bool sendModulatedParams = true;
        bool sendTriggers = true;
        juce::String addressPrefix = "/echoelmusic";
    };

    //==========================================================================
    BioReactiveOSCBridge()
    {
        oscSender = std::make_unique<juce::OSCSender>();
    }

    ~BioReactiveOSCBridge()
    {
        disconnect();
    }

    //==========================================================================
    // Connection

    bool connect(const juce::String& host, int port)
    {
        config.targetHost = host;
        config.targetPort = port;

        if (oscSender->connect(host, port))
        {
            connected = true;
            DBG("BioReactiveOSCBridge connected to " << host << ":" << port);
            return true;
        }

        DBG("BioReactiveOSCBridge failed to connect");
        return false;
    }

    bool connect()
    {
        return connect(config.targetHost, config.targetPort);
    }

    void disconnect()
    {
        if (oscSender)
        {
            oscSender->disconnect();
            connected = false;
        }
    }

    bool isConnected() const { return connected; }

    //==========================================================================
    // Send Bio Data

    void sendBioData(float hrv, float coherence, float heartRate, float stress)
    {
        if (!connected || !config.sendBioData)
            return;

        juce::String prefix = config.addressPrefix + "/bio/";

        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "hrv"), hrv));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "coherence"), coherence));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "heartrate"), heartRate));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "stress"), stress));
    }

    void sendBioData(const BioDataInput::BioDataSample& sample)
    {
        sendBioData(sample.hrv, sample.coherence, sample.heartRate, sample.stressIndex);
    }

    /**
     * @brief Send complete HRV metrics (including advanced time/frequency domain)
     * @param metrics HRVMetrics from HRVProcessor
     */
    void sendHRVMetrics(const HRVProcessor::HRVMetrics& metrics)
    {
        if (!connected || !config.sendBioData)
            return;

        juce::String prefix = config.addressPrefix + "/bio/";

        // Basic metrics
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "hrv"), metrics.hrv));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "coherence"), metrics.coherence));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "heartrate"), metrics.heartRate));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "stress"), metrics.stressIndex));

        // Time-domain metrics (ms)
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "sdnn"), metrics.sdnn));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "rmssd"), metrics.rmssd));

        // Frequency-domain metrics
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "lfpower"), metrics.lfPower));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "hfpower"), metrics.hfPower));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "lfhf"), metrics.lfhfRatio));
    }

    //==========================================================================
    // Send Modulated Parameters

    void sendModulatedParams(const BioReactiveModulator::ModulatedParameters& params)
    {
        if (!connected || !config.sendModulatedParams)
            return;

        juce::String prefix = config.addressPrefix + "/mod/";

        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "filter"), params.filterCutoff));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "reverb"), params.reverbMix));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "compression"), params.compressionRatio));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "delay"), params.delayTime));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "distortion"), params.distortionAmount));
        oscSender->send(juce::OSCMessage(juce::OSCAddressPattern(prefix + "lfo"), params.lfoRate));
    }

    //==========================================================================
    // Send Triggers

    void sendHeartbeatTrigger()
    {
        if (!connected || !config.sendTriggers)
            return;

        oscSender->send(juce::OSCMessage(
            juce::OSCAddressPattern(config.addressPrefix + "/trigger/beat")));
    }

    void sendBreathTrigger()
    {
        if (!connected || !config.sendTriggers)
            return;

        oscSender->send(juce::OSCMessage(
            juce::OSCAddressPattern(config.addressPrefix + "/trigger/breath")));
    }

    //==========================================================================
    // Combined Update (call from timer at config.updateRateHz)

    void update(const BioDataInput::BioDataSample& bioData,
                const BioReactiveModulator::ModulatedParameters& params)
    {
        sendBioData(bioData);
        sendModulatedParams(params);

        // Detect heartbeat (simple threshold)
        static float lastHeartPhase = 0.0f;
        float currentPhase = std::fmod(juce::Time::getMillisecondCounterHiRes() *
                                       (bioData.heartRate / 60000.0f), 1.0f);
        if (currentPhase < lastHeartPhase)
            sendHeartbeatTrigger();
        lastHeartPhase = currentPhase;
    }

    //==========================================================================
    // Configuration

    Config& getConfig() { return config; }
    void setConfig(const Config& newConfig) { config = newConfig; }

    //==========================================================================
    // Presets for common targets

    void configureForTouchDesigner()
    {
        config.targetPort = 9000;
        config.addressPrefix = "/echoelmusic";
        config.updateRateHz = 60;  // TD can handle high rate
    }

    void configureForResolume()
    {
        config.targetPort = 7000;  // Resolume default
        config.addressPrefix = "/composition";
        config.updateRateHz = 30;
    }

    void configureForAbleton()
    {
        config.targetPort = 9001;  // Custom for Max for Live
        config.addressPrefix = "/echoelmusic";
        config.updateRateHz = 30;
    }

    void configureForVDMX()
    {
        config.targetPort = 1234;  // VDMX default
        config.addressPrefix = "/echoelmusic";
        config.updateRateHz = 30;
    }

private:
    std::unique_ptr<juce::OSCSender> oscSender;
    Config config;
    bool connected = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioReactiveOSCBridge)
};

} // namespace Echoelmusic
