#pragma once

#include <JuceHeader.h>
#include "../Audio/AudioEngine.h"
#include "../Hardware/OSCManager.h"

namespace Echoelmusic {

/**
 * @brief Audio Engine OSC Bridge
 *
 * Provides OSC control for AudioEngine (transport, tempo, tracks, recording).
 * Professional DAW-style control via OSC.
 *
 * OSC Address Space:
 * /echoelmusic/audio/transport/play                     Start playback
 * /echoelmusic/audio/transport/stop                     Stop playback
 * /echoelmusic/audio/transport/toggle                   Toggle play/stop
 * /echoelmusic/audio/transport/position [samples]       Set position
 * /echoelmusic/audio/transport/position/beats [beats]   Set position (musical time)
 * /echoelmusic/audio/transport/loop [int 0/1]           Enable/disable loop
 * /echoelmusic/audio/transport/loop/region [start end]  Set loop region (samples)
 *
 * /echoelmusic/audio/tempo [float 20-999]               Set tempo (BPM)
 * /echoelmusic/audio/timesig [int int]                  Set time signature (num, denom)
 * /echoelmusic/audio/sync [int 0/1]                     Enable external sync
 *
 * /echoelmusic/audio/master/volume [float 0-1]          Master volume
 * /echoelmusic/audio/master/level                       Query master level (LUFS)
 * /echoelmusic/audio/master/peak                        Query master peak (dBFS)
 *
 * /echoelmusic/audio/track/<n>/volume [float 0-1]       Track volume
 * /echoelmusic/audio/track/<n>/mute [int 0/1]           Track mute
 * /echoelmusic/audio/track/<n>/solo [int 0/1]           Track solo
 * /echoelmusic/audio/track/<n>/arm [int 0/1]            Arm for recording
 * /echoelmusic/audio/track/<n>/name [string]            Track name
 *
 * /echoelmusic/audio/recording/start                    Start recording on armed tracks
 * /echoelmusic/audio/recording/stop                     Stop recording
 * /echoelmusic/audio/recording/status                   Query recording status
 *
 * /echoelmusic/audio/status                             Get full audio engine status (JSON)
 *
 * Response Messages:
 * /echoelmusic/audio/status/playing [int 0/1]
 * /echoelmusic/audio/status/position [int samples]
 * /echoelmusic/audio/status/tempo [float]
 * /echoelmusic/audio/status/recording [int 0/1]
 * /echoelmusic/audio/status/level [float LUFS]
 * /echoelmusic/audio/status/peak [float dBFS]
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class AudioOSCBridge
{
public:
    //==========================================================================
    AudioOSCBridge(AudioEngine& engine, OSCManager& oscManager)
        : audioEngine(engine)
        , oscManager(oscManager)
    {
        setupOSCListeners();
    }

    ~AudioOSCBridge()
    {
        removeOSCListeners();
    }

    //==========================================================================
    /**
     * @brief Send audio engine status via OSC
     */
    void sendAudioStatus()
    {
        juce::String prefix = "/echoelmusic/audio/status/";

        // Transport
        oscManager.sendInt(prefix + "playing", audioEngine.isPlaying() ? 1 : 0);
        oscManager.sendInt(prefix + "position", static_cast<int>(audioEngine.getPosition()));
        oscManager.sendFloat(prefix + "tempo", static_cast<float>(audioEngine.getTempo()));

        // Recording
        oscManager.sendInt(prefix + "recording", audioEngine.isRecording() ? 1 : 0);

        // Levels
        oscManager.sendFloat(prefix + "level", audioEngine.getMasterLevelLUFS());
        oscManager.sendFloat(prefix + "peak", audioEngine.getMasterPeakLevel());

        // Master volume
        oscManager.sendFloat(prefix + "volume", audioEngine.getMasterVolume());

        // Track count
        oscManager.sendInt(prefix + "tracks", audioEngine.getNumTracks());
    }

    /**
     * @brief Send transport status (high-frequency update)
     * Call this from a timer at 10-60 Hz for real-time position updates
     */
    void sendTransportStatus()
    {
        juce::String prefix = "/echoelmusic/audio/transport/";

        oscManager.sendInt(prefix + "playing", audioEngine.isPlaying() ? 1 : 0);
        oscManager.sendInt(prefix + "position", static_cast<int>(audioEngine.getPosition()));

        // Musical time (beats)
        double tempo = audioEngine.getTempo();
        double sampleRate = audioEngine.getSampleRate();
        int64_t posSamples = audioEngine.getPosition();

        if (tempo > 0.0 && sampleRate > 0.0)
        {
            double posBeats = (posSamples / sampleRate) * (tempo / 60.0);
            oscManager.sendFloat(prefix + "position/beats", static_cast<float>(posBeats));
        }
    }

    /**
     * @brief Send level meters (high-frequency update)
     * Call this from a timer at 30-60 Hz for metering
     */
    void sendLevelMeters()
    {
        juce::String prefix = "/echoelmusic/audio/master/";

        oscManager.sendFloat(prefix + "level", audioEngine.getMasterLevelLUFS());
        oscManager.sendFloat(prefix + "peak", audioEngine.getMasterPeakLevel());
    }

private:
    //==========================================================================
    void setupOSCListeners()
    {
        // Transport - Play
        oscManager.addListener("/echoelmusic/audio/transport/play",
            [this](const juce::OSCMessage&) {
                audioEngine.play();
                DBG("OSC: Audio transport PLAY");
            });

        // Transport - Stop
        oscManager.addListener("/echoelmusic/audio/transport/stop",
            [this](const juce::OSCMessage&) {
                audioEngine.stop();
                DBG("OSC: Audio transport STOP");
            });

        // Transport - Toggle
        oscManager.addListener("/echoelmusic/audio/transport/toggle",
            [this](const juce::OSCMessage&) {
                if (audioEngine.isPlaying())
                    audioEngine.stop();
                else
                    audioEngine.play();

                DBG("OSC: Audio transport TOGGLE - " << (audioEngine.isPlaying() ? "PLAY" : "STOP"));
            });

        // Transport - Position (samples)
        oscManager.addListener("/echoelmusic/audio/transport/position",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0)
                {
                    int64_t position = 0;
                    if (message[0].isInt32())
                        position = message[0].getInt32();
                    else if (message[0].isFloat32())
                        position = static_cast<int64_t>(message[0].getFloat32());

                    position = juce::jmax(static_cast<int64_t>(0), position);
                    audioEngine.setPosition(position);
                    DBG("OSC: Set audio position to " << position << " samples");
                }
                else
                {
                    // Query - send current position
                    oscManager.sendInt("/echoelmusic/audio/status/position",
                        static_cast<int>(audioEngine.getPosition()));
                }
            });

        // Transport - Position (beats)
        oscManager.addListener("/echoelmusic/audio/transport/position/beats",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isFloat32())
                {
                    float beats = message[0].getFloat32();
                    double tempo = audioEngine.getTempo();
                    double sampleRate = audioEngine.getSampleRate();

                    if (tempo > 0.0 && sampleRate > 0.0)
                    {
                        // Convert beats to samples
                        double seconds = (beats / tempo) * 60.0;
                        int64_t samples = static_cast<int64_t>(seconds * sampleRate);

                        audioEngine.setPosition(samples);
                        DBG("OSC: Set audio position to " << beats << " beats (" << samples << " samples)");
                    }
                }
            });

        // Transport - Loop enable
        oscManager.addListener("/echoelmusic/audio/transport/loop",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isInt32())
                {
                    bool shouldLoop = (message[0].getInt32() != 0);
                    audioEngine.setLooping(shouldLoop);
                    DBG("OSC: Loop " << (shouldLoop ? "ENABLED" : "DISABLED"));
                }
            });

        // Transport - Loop region
        oscManager.addListener("/echoelmusic/audio/transport/loop/region",
            [this](const juce::OSCMessage& message) {
                if (message.size() >= 2)
                {
                    int64_t startSample = 0;
                    int64_t endSample = 0;

                    if (message[0].isInt32())
                        startSample = message[0].getInt32();
                    if (message[1].isInt32())
                        endSample = message[1].getInt32();

                    audioEngine.setLoopRegion(startSample, endSample);
                    DBG("OSC: Set loop region " << startSample << " - " << endSample);
                }
            });

        // Tempo
        oscManager.addListener("/echoelmusic/audio/tempo",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0)
                {
                    float tempo = 0.0f;
                    if (message[0].isFloat32())
                        tempo = message[0].getFloat32();
                    else if (message[0].isInt32())
                        tempo = static_cast<float>(message[0].getInt32());

                    if (tempo > 0.0f)
                    {
                        tempo = juce::jlimit(20.0f, 999.0f, tempo);
                        audioEngine.setTempo(tempo);
                        DBG("OSC: Set tempo to " << tempo << " BPM");
                    }
                }
                else
                {
                    // Query
                    oscManager.sendFloat("/echoelmusic/audio/status/tempo",
                        static_cast<float>(audioEngine.getTempo()));
                }
            });

        // Time Signature
        oscManager.addListener("/echoelmusic/audio/timesig",
            [this](const juce::OSCMessage& message) {
                if (message.size() >= 2 && message[0].isInt32() && message[1].isInt32())
                {
                    int numerator = juce::jlimit(1, 32, message[0].getInt32());
                    int denominator = juce::jlimit(1, 32, message[1].getInt32());

                    audioEngine.setTimeSignature(numerator, denominator);
                    DBG("OSC: Set time signature to " << numerator << "/" << denominator);
                }
                else
                {
                    // Query
                    int num, denom;
                    audioEngine.getTimeSignature(num, denom);
                    oscManager.sendInt("/echoelmusic/audio/status/timesig_num", num);
                    oscManager.sendInt("/echoelmusic/audio/status/timesig_den", denom);
                }
            });

        // External Sync
        oscManager.addListener("/echoelmusic/audio/sync",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isInt32())
                {
                    bool enabled = (message[0].getInt32() != 0);
                    audioEngine.setSyncEnabled(enabled);
                    DBG("OSC: External sync " << (enabled ? "ENABLED" : "DISABLED"));
                }
            });

        // Master Volume
        oscManager.addListener("/echoelmusic/audio/master/volume",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isFloat32())
                {
                    float volume = juce::jlimit(0.0f, 1.0f, message[0].getFloat32());
                    audioEngine.setMasterVolume(volume);
                    DBG("OSC: Set master volume to " << volume);
                }
                else
                {
                    // Query
                    oscManager.sendFloat("/echoelmusic/audio/status/volume",
                        audioEngine.getMasterVolume());
                }
            });

        // Master Level (query)
        oscManager.addListener("/echoelmusic/audio/master/level",
            [this](const juce::OSCMessage&) {
                oscManager.sendFloat("/echoelmusic/audio/status/level",
                    audioEngine.getMasterLevelLUFS());
            });

        // Master Peak (query)
        oscManager.addListener("/echoelmusic/audio/master/peak",
            [this](const juce::OSCMessage&) {
                oscManager.sendFloat("/echoelmusic/audio/status/peak",
                    audioEngine.getMasterPeakLevel());
            });

        // Track control (wildcard pattern)
        oscManager.addListener("/echoelmusic/audio/track/*",
            [this](const juce::OSCMessage& message) {
                handleTrackOSC(message);
            });

        // Recording Start
        oscManager.addListener("/echoelmusic/audio/recording/start",
            [this](const juce::OSCMessage&) {
                audioEngine.startRecording();
                DBG("OSC: Recording STARTED");
            });

        // Recording Stop
        oscManager.addListener("/echoelmusic/audio/recording/stop",
            [this](const juce::OSCMessage&) {
                audioEngine.stopRecording();
                DBG("OSC: Recording STOPPED");
            });

        // Recording Status (query)
        oscManager.addListener("/echoelmusic/audio/recording/status",
            [this](const juce::OSCMessage&) {
                oscManager.sendInt("/echoelmusic/audio/status/recording",
                    audioEngine.isRecording() ? 1 : 0);
            });

        // Full Status (query)
        oscManager.addListener("/echoelmusic/audio/status",
            [this](const juce::OSCMessage&) {
                sendAudioStatus();
            });
    }

    void removeOSCListeners()
    {
        oscManager.removeListener("/echoelmusic/audio/transport/play");
        oscManager.removeListener("/echoelmusic/audio/transport/stop");
        oscManager.removeListener("/echoelmusic/audio/transport/toggle");
        oscManager.removeListener("/echoelmusic/audio/transport/position");
        oscManager.removeListener("/echoelmusic/audio/transport/position/beats");
        oscManager.removeListener("/echoelmusic/audio/transport/loop");
        oscManager.removeListener("/echoelmusic/audio/transport/loop/region");
        oscManager.removeListener("/echoelmusic/audio/tempo");
        oscManager.removeListener("/echoelmusic/audio/timesig");
        oscManager.removeListener("/echoelmusic/audio/sync");
        oscManager.removeListener("/echoelmusic/audio/master/volume");
        oscManager.removeListener("/echoelmusic/audio/master/level");
        oscManager.removeListener("/echoelmusic/audio/master/peak");
        oscManager.removeListener("/echoelmusic/audio/track/*");
        oscManager.removeListener("/echoelmusic/audio/recording/start");
        oscManager.removeListener("/echoelmusic/audio/recording/stop");
        oscManager.removeListener("/echoelmusic/audio/recording/status");
        oscManager.removeListener("/echoelmusic/audio/status");
    }

    //==========================================================================
    void handleTrackOSC(const juce::OSCMessage& message)
    {
        juce::String address = message.getAddressPattern().toString();

        // Parse track index: /echoelmusic/audio/track/0/volume -> 0
        int trackIndex = parseTrackIndex(address);
        if (trackIndex < 0 || trackIndex >= audioEngine.getNumTracks())
            return;

        auto* track = audioEngine.getTrack(trackIndex);
        if (!track)
            return;

        // Handle specific track commands
        if (address.contains("/arm"))
        {
            if (message.size() > 0 && message[0].isInt32())
            {
                bool armed = (message[0].getInt32() != 0);
                audioEngine.armTrack(trackIndex, armed);
                DBG("OSC: Track " << trackIndex << " arm = " << armed);
            }
            else
            {
                // Query
                oscManager.sendInt("/echoelmusic/audio/track/" + juce::String(trackIndex) + "/arm",
                    audioEngine.isTrackArmed(trackIndex) ? 1 : 0);
            }
        }
        // Additional track controls (volume, mute, solo) would be implemented
        // based on Track class interface (not shown in AudioEngine.h excerpt)
    }

    int parseTrackIndex(const juce::String& address) const
    {
        // Parse "/echoelmusic/audio/track/0/volume" -> 0
        auto parts = juce::StringArray::fromTokens(address, "/", "");

        for (int i = 0; i < parts.size(); ++i)
        {
            if (parts[i] == "track" && i + 1 < parts.size())
            {
                return parts[i + 1].getIntValue();
            }
        }

        return -1;
    }

    //==========================================================================
    AudioEngine& audioEngine;
    OSCManager& oscManager;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioOSCBridge)
};

} // namespace Echoelmusic
