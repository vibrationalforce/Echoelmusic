#pragma once

#include <JuceHeader.h>
#include "../Audio/SessionManager.h"
#include "../Hardware/OSCManager.h"

namespace Echoelmusic {

/**
 * @brief Session Management OSC Bridge
 *
 * Provides OSC control for session management (save, load, project info).
 *
 * OSC Address Space:
 * /echoelmusic/session/save [string]        Save session to file path
 * /echoelmusic/session/load [string]        Load session from file path
 * /echoelmusic/session/new                  Create new empty session
 * /echoelmusic/session/title [string]       Set/get project title
 * /echoelmusic/session/artist [string]      Set/get artist name
 * /echoelmusic/session/tempo [float]        Set/get tempo (BPM)
 * /echoelmusic/session/timesig [int int]    Set time signature (numerator, denominator)
 * /echoelmusic/session/samplerate [float]   Get sample rate
 * /echoelmusic/session/dirty [bang]         Query if session has unsaved changes
 * /echoelmusic/session/autosave [int]       Set autosave interval (minutes, 0=disable)
 * /echoelmusic/session/status               Get session status (JSON)
 *
 * Response Messages (sent back to sender):
 * /echoelmusic/session/status/title [string]
 * /echoelmusic/session/status/tempo [float]
 * /echoelmusic/session/status/dirty [int 0/1]
 * /echoelmusic/session/status/file [string]
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class SessionOSCBridge
{
public:
    //==========================================================================
    SessionOSCBridge(SessionManager& manager, OSCManager& oscManager)
        : sessionManager(manager)
        , oscManager(oscManager)
    {
        setupOSCListeners();
    }

    ~SessionOSCBridge()
    {
        removeOSCListeners();
    }

    //==========================================================================
    /**
     * @brief Send session status via OSC (broadcast to all connected clients)
     */
    void sendSessionStatus()
    {
        const auto& info = sessionManager.getProjectInfo();
        juce::String prefix = "/echoelmusic/session/status/";

        oscManager.sendString(prefix + "title", info.title);
        oscManager.sendString(prefix + "artist", info.artist);
        oscManager.sendFloat(prefix + "tempo", static_cast<float>(info.tempo));
        oscManager.sendInt(prefix + "timesig_num", info.timeSignatureNumerator);
        oscManager.sendInt(prefix + "timesig_den", info.timeSignatureDenominator);
        oscManager.sendFloat(prefix + "samplerate", static_cast<float>(info.sampleRate));
        oscManager.sendInt(prefix + "dirty", sessionManager.hasUnsavedChanges() ? 1 : 0);

        juce::File currentFile = sessionManager.getCurrentSessionFile();
        oscManager.sendString(prefix + "file",
            currentFile.exists() ? currentFile.getFullPathName() : "");
    }

    /**
     * @brief Send session status as JSON
     */
    void sendSessionStatusJSON()
    {
        const auto& info = sessionManager.getProjectInfo();

        juce::String json;
        json << "{\n";
        json << "  \"title\": \"" << info.title << "\",\n";
        json << "  \"artist\": \"" << info.artist << "\",\n";
        json << "  \"tempo\": " << info.tempo << ",\n";
        json << "  \"timeSignature\": {\"numerator\": " << info.timeSignatureNumerator
             << ", \"denominator\": " << info.timeSignatureDenominator << "},\n";
        json << "  \"sampleRate\": " << info.sampleRate << ",\n";
        json << "  \"dirty\": " << (sessionManager.hasUnsavedChanges() ? "true" : "false") << ",\n";

        juce::File currentFile = sessionManager.getCurrentSessionFile();
        json << "  \"file\": \"" << (currentFile.exists() ? currentFile.getFullPathName() : "") << "\"\n";
        json << "}";

        oscManager.sendString("/echoelmusic/session/status", json);
    }

private:
    //==========================================================================
    void setupOSCListeners()
    {
        // Save session
        oscManager.addListener("/echoelmusic/session/save",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    juce::String filePath = message[0].getString();
                    juce::File file(filePath);

                    bool success = sessionManager.saveSession(file);

                    // Send response
                    oscManager.sendInt("/echoelmusic/session/save/result", success ? 1 : 0);
                    oscManager.sendString("/echoelmusic/session/save/message",
                        success ? "Session saved successfully" : "Failed to save session");

                    DBG("OSC: Save session to " << filePath << " - " << (success ? "SUCCESS" : "FAILED"));
                }
            });

        // Load session
        oscManager.addListener("/echoelmusic/session/load",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    juce::String filePath = message[0].getString();
                    juce::File file(filePath);

                    bool success = sessionManager.loadSession(file);

                    // Send response
                    oscManager.sendInt("/echoelmusic/session/load/result", success ? 1 : 0);
                    oscManager.sendString("/echoelmusic/session/load/message",
                        success ? "Session loaded successfully" : "Failed to load session");

                    if (success)
                        sendSessionStatus();

                    DBG("OSC: Load session from " << filePath << " - " << (success ? "SUCCESS" : "FAILED"));
                }
            });

        // New session
        oscManager.addListener("/echoelmusic/session/new",
            [this](const juce::OSCMessage&) {
                sessionManager.newSession();
                sendSessionStatus();
                DBG("OSC: Created new session");
            });

        // Set title
        oscManager.addListener("/echoelmusic/session/title",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    auto info = sessionManager.getProjectInfo();
                    info.title = message[0].getString();
                    sessionManager.setProjectInfo(info);
                    sessionManager.markAsDirty();
                    DBG("OSC: Set session title to '" << info.title << "'");
                }
                else
                {
                    // Query - send back current title
                    oscManager.sendString("/echoelmusic/session/status/title",
                        sessionManager.getProjectInfo().title);
                }
            });

        // Set artist
        oscManager.addListener("/echoelmusic/session/artist",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    auto info = sessionManager.getProjectInfo();
                    info.artist = message[0].getString();
                    sessionManager.setProjectInfo(info);
                    sessionManager.markAsDirty();
                    DBG("OSC: Set session artist to '" << info.artist << "'");
                }
                else
                {
                    oscManager.sendString("/echoelmusic/session/status/artist",
                        sessionManager.getProjectInfo().artist);
                }
            });

        // Set tempo
        oscManager.addListener("/echoelmusic/session/tempo",
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
                        auto info = sessionManager.getProjectInfo();
                        info.tempo = juce::jlimit(20.0, 999.0, static_cast<double>(tempo));
                        sessionManager.setProjectInfo(info);
                        sessionManager.markAsDirty();
                        DBG("OSC: Set tempo to " << info.tempo << " BPM");
                    }
                }
                else
                {
                    oscManager.sendFloat("/echoelmusic/session/status/tempo",
                        static_cast<float>(sessionManager.getProjectInfo().tempo));
                }
            });

        // Set time signature
        oscManager.addListener("/echoelmusic/session/timesig",
            [this](const juce::OSCMessage& message) {
                if (message.size() >= 2 && message[0].isInt32() && message[1].isInt32())
                {
                    auto info = sessionManager.getProjectInfo();
                    info.timeSignatureNumerator = juce::jlimit(1, 32, message[0].getInt32());
                    info.timeSignatureDenominator = juce::jlimit(1, 32, message[1].getInt32());
                    sessionManager.setProjectInfo(info);
                    sessionManager.markAsDirty();
                    DBG("OSC: Set time signature to " << info.timeSignatureNumerator
                        << "/" << info.timeSignatureDenominator);
                }
                else
                {
                    const auto& info = sessionManager.getProjectInfo();
                    oscManager.sendInt("/echoelmusic/session/status/timesig_num",
                        info.timeSignatureNumerator);
                    oscManager.sendInt("/echoelmusic/session/status/timesig_den",
                        info.timeSignatureDenominator);
                }
            });

        // Query dirty status
        oscManager.addListener("/echoelmusic/session/dirty",
            [this](const juce::OSCMessage&) {
                oscManager.sendInt("/echoelmusic/session/status/dirty",
                    sessionManager.hasUnsavedChanges() ? 1 : 0);
            });

        // Set autosave interval
        oscManager.addListener("/echoelmusic/session/autosave",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isInt32())
                {
                    int interval = juce::jmax(0, message[0].getInt32());
                    sessionManager.setAutoSave(interval);
                    DBG("OSC: Set autosave interval to " << interval << " minutes");
                }
            });

        // Get full status
        oscManager.addListener("/echoelmusic/session/status",
            [this](const juce::OSCMessage&) {
                sendSessionStatusJSON();
            });
    }

    void removeOSCListeners()
    {
        oscManager.removeListener("/echoelmusic/session/save");
        oscManager.removeListener("/echoelmusic/session/load");
        oscManager.removeListener("/echoelmusic/session/new");
        oscManager.removeListener("/echoelmusic/session/title");
        oscManager.removeListener("/echoelmusic/session/artist");
        oscManager.removeListener("/echoelmusic/session/tempo");
        oscManager.removeListener("/echoelmusic/session/timesig");
        oscManager.removeListener("/echoelmusic/session/dirty");
        oscManager.removeListener("/echoelmusic/session/autosave");
        oscManager.removeListener("/echoelmusic/session/status");
    }

    //==========================================================================
    SessionManager& sessionManager;
    OSCManager& oscManager;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SessionOSCBridge)
};

} // namespace Echoelmusic
