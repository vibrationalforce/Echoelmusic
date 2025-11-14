#pragma once

#include <JuceHeader.h>
#include "AudioEngine.h"
#include "../DSP/BioReactiveAudioProcessor.h"

/**
 * SessionManager - Project save/load system for Echoelmusic
 *
 * Features:
 * - XML-based session format (.echoelmusic or .xml)
 * - Save/Load full project state
 * - Track states (audio clips, MIDI, routing)
 * - Plugin/Effect states
 * - Tempo, time signature, markers
 * - Bio-feedback settings
 * - Wellness system states
 * - Auto-save functionality
 * - Crash recovery
 *
 * Session File Structure:
 * <EchoelmusicSession version="1.0">
 *   <ProjectInfo>
 *     <Title>My Project</Title>
 *     <Tempo>120.0</Tempo>
 *     <TimeSignature numerator="4" denominator="4"/>
 *     <SampleRate>48000.0</SampleRate>
 *   </ProjectInfo>
 *
 *   <Tracks>
 *     <Track id="1" name="Audio 1" type="audio">
 *       <Clips>
 *         <Clip start="0" file="audio1.wav"/>
 *       </Clips>
 *       <Effects>
 *         <Effect type="EQ" state="..."/>
 *       </Effects>
 *     </Track>
 *   </Tracks>
 *
 *   <BioFeedback enabled="true">
 *     <HRVSettings source="Simulated"/>
 *   </BioFeedback>
 *
 *   <Wellness>
 *     <AVE enabled="false"/>
 *     <ColorTherapy enabled="false"/>
 *   </Wellness>
 * </EchoelmusicSession>
 */
class SessionManager
{
public:
    //==========================================================================
    // Project Information
    //==========================================================================

    struct ProjectInfo
    {
        juce::String title = "Untitled";
        juce::String artist;
        juce::String description;

        double tempo = 120.0;
        int timeSignatureNumerator = 4;
        int timeSignatureDenominator = 4;

        double sampleRate = 48000.0;
        int blockSize = 512;

        juce::Time createdTime;
        juce::Time lastModifiedTime;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SessionManager();
    ~SessionManager();

    //==========================================================================
    // Save / Load
    //==========================================================================

    /**
     * Save current session to file
     *
     * @param file Output file (.echoelmusic or .xml)
     * @return true if save succeeded
     */
    bool saveSession(const juce::File& file);

    /**
     * Load session from file
     *
     * @param file Input file
     * @return true if load succeeded
     */
    bool loadSession(const juce::File& file);

    /**
     * Create new empty session
     */
    void newSession();

    /**
     * Check if session has unsaved changes
     */
    bool hasUnsavedChanges() const { return isDirty; }

    /**
     * Mark session as modified
     */
    void markAsDirty() { isDirty = true; }

    /**
     * Get current session file (empty if not saved yet)
     */
    juce::File getCurrentSessionFile() const { return currentSessionFile; }

    //==========================================================================
    // Auto-Save
    //==========================================================================

    /**
     * Enable/disable auto-save
     *
     * @param intervalMinutes Auto-save interval (0 to disable)
     */
    void setAutoSave(int intervalMinutes);

    /**
     * Trigger immediate auto-save (if enabled)
     */
    void triggerAutoSave();

    //==========================================================================
    // Project Info
    //==========================================================================

    /**
     * Get project information
     */
    const ProjectInfo& getProjectInfo() const { return projectInfo; }

    /**
     * Set project information
     */
    void setProjectInfo(const ProjectInfo& info);

    //==========================================================================
    // Session State (to be set by AudioEngine)
    //==========================================================================

    /**
     * Set session state XML (will be saved with session)
     * Call this before saveSession() to include engine state
     */
    void setSessionState(std::unique_ptr<juce::XmlElement> state);

    /**
     * Get current session state XML
     */
    juce::XmlElement* getSessionState() const { return sessionState.get(); }

private:
    //==========================================================================
    // XML Serialization
    //==========================================================================

    std::unique_ptr<juce::XmlElement> createSessionXML();
    bool restoreFromXML(const juce::XmlElement& xml);

    std::unique_ptr<juce::XmlElement> createProjectInfoXML();
    bool restoreProjectInfoFromXML(const juce::XmlElement& xml);

    //==========================================================================
    // Auto-Save Timer
    //==========================================================================

    class AutoSaveTimer : public juce::Timer
    {
    public:
        AutoSaveTimer(SessionManager& owner) : sessionManager(owner) {}

        void timerCallback() override
        {
            sessionManager.triggerAutoSave();
        }

    private:
        SessionManager& sessionManager;
    };

    AutoSaveTimer autoSaveTimer;
    int autoSaveIntervalMinutes = 5;  // Default: every 5 minutes

    //==========================================================================
    // State
    //==========================================================================

    ProjectInfo projectInfo;
    juce::File currentSessionFile;
    bool isDirty = false;

    std::unique_ptr<juce::XmlElement> sessionState;  // Current session XML state

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SessionManager)
};
