#pragma once

#include <JuceHeader.h>
#include "../Audio/AudioEngine.h"
#include "../Audio/Track.h"
#include <memory>
#include <vector>

namespace echoelmusic {
namespace project {

/**
 * @brief Project Management System for Echoelmusic
 *
 * CRITICAL MVP COMPONENT - Enables users to save/load their work!
 *
 * Features:
 * - Save/Load projects to JSON
 * - Auto-save every 5 minutes
 * - Recent projects list
 * - Project templates
 * - Version control friendly format
 *
 * JSON Structure:
 * {
 *   "version": "1.0",
 *   "name": "My Song",
 *   "tempo": 128.0,
 *   "timeSignature": "4/4",
 *   "sampleRate": 48000,
 *   "tracks": [...]
 * }
 *
 * @author Claude Code (ULTRATHINK SUPER LASER MODE)
 * @date 2025-11-18
 */
class ProjectManager
{
public:
    /**
     * @brief Project metadata
     */
    struct ProjectInfo
    {
        juce::String name = "Untitled Project";
        juce::String artist = "";
        juce::String description = "";
        juce::File filePath;
        juce::Time lastModified;
        double tempo = 128.0;
        juce::String timeSignature = "4/4";
        int sampleRate = 48000;
        int bufferSize = 512;
        bool isModified = false;
    };

    /**
     * @brief Track save data
     */
    struct TrackData
    {
        juce::String name;
        bool isAudioTrack;  // true = audio, false = MIDI
        float volume;
        float pan;
        bool muted;
        bool soloed;
        bool armed;
        juce::Colour colour;

        // Audio-specific
        std::vector<juce::String> audioClips;  // File paths

        // MIDI-specific
        std::vector<juce::MidiMessage> midiNotes;

        // Effects chain
        std::vector<juce::String> effectNames;
        std::vector<juce::String> effectStates;  // Serialized plugin states
    };

public:
    /**
     * @brief Get singleton instance
     */
    static ProjectManager& getInstance();

    /**
     * @brief Initialize project manager
     */
    bool initialize();

    /**
     * @brief Create new project
     *
     * @param projectName Name of the new project
     * @return true if created successfully
     */
    bool createNewProject(const juce::String& projectName = "Untitled Project");

    /**
     * @brief Save current project
     *
     * @param filePath Where to save (if empty, uses current project path)
     * @return true if saved successfully
     */
    bool saveProject(const juce::File& filePath = juce::File());

    /**
     * @brief Load project from file
     *
     * @param filePath Path to .echoel project file
     * @return true if loaded successfully
     */
    bool loadProject(const juce::File& filePath);

    /**
     * @brief Save project with new name (Save As...)
     *
     * @param filePath New file path
     * @return true if saved successfully
     */
    bool saveProjectAs(const juce::File& filePath);

    /**
     * @brief Check if project has unsaved changes
     *
     * @return true if modified since last save
     */
    bool hasUnsavedChanges() const;

    /**
     * @brief Mark project as modified
     */
    void markAsModified();

    /**
     * @brief Get current project info
     *
     * @return Project metadata
     */
    const ProjectInfo& getCurrentProjectInfo() const;

    /**
     * @brief Set project info
     *
     * @param info New project metadata
     */
    void setProjectInfo(const ProjectInfo& info);

    /**
     * @brief Enable/disable auto-save
     *
     * @param enabled true to enable auto-save
     * @param intervalSeconds Seconds between auto-saves (default: 300 = 5 minutes)
     */
    void setAutoSave(bool enabled, int intervalSeconds = 300);

    /**
     * @brief Get list of recent projects
     *
     * @param maxItems Maximum number of recent projects (default: 10)
     * @return Vector of recent project file paths
     */
    std::vector<juce::File> getRecentProjects(int maxItems = 10) const;

    /**
     * @brief Add project to recent list
     *
     * @param filePath Project file path
     */
    void addToRecentProjects(const juce::File& filePath);

    /**
     * @brief Clear recent projects list
     */
    void clearRecentProjects();

    /**
     * @brief Export project to JSON string (for debugging/backup)
     *
     * @return JSON representation of project
     */
    juce::String exportToJSON() const;

    /**
     * @brief Import project from JSON string
     *
     * @param jsonString JSON project data
     * @return true if imported successfully
     */
    bool importFromJSON(const juce::String& jsonString);

    /**
     * @brief Get default project directory
     *
     * @return Directory where projects are saved by default
     */
    juce::File getDefaultProjectDirectory() const;

    /**
     * @brief Set default project directory
     *
     * @param directory New default directory
     */
    void setDefaultProjectDirectory(const juce::File& directory);

    /**
     * @brief Create project template
     *
     * Templates are pre-configured projects (e.g., "Electronic", "Rock Band", "Lo-Fi")
     *
     * @param templateName Name of template
     * @param description Template description
     * @return true if created successfully
     */
    bool createTemplate(const juce::String& templateName, const juce::String& description);

    /**
     * @brief Get available templates
     *
     * @return Vector of template names
     */
    std::vector<juce::String> getAvailableTemplates() const;

    /**
     * @brief Load project from template
     *
     * @param templateName Template to load
     * @return true if loaded successfully
     */
    bool loadFromTemplate(const juce::String& templateName);

private:
    ProjectManager();
    ~ProjectManager();

    // Prevent copying
    ProjectManager(const ProjectManager&) = delete;
    ProjectManager& operator=(const ProjectManager&) = delete;

    /**
     * @brief Serialize audio engine state to JSON
     */
    juce::var serializeAudioEngine(const audio::AudioEngine& engine) const;

    /**
     * @brief Deserialize audio engine state from JSON
     */
    bool deserializeAudioEngine(audio::AudioEngine& engine, const juce::var& json);

    /**
     * @brief Serialize track to JSON
     */
    juce::var serializeTrack(const audio::Track& track) const;

    /**
     * @brief Deserialize track from JSON
     */
    std::unique_ptr<audio::Track> deserializeTrack(const juce::var& json);

    /**
     * @brief Perform auto-save (called by timer)
     */
    void performAutoSave();

    /**
     * @brief Load recent projects from settings
     */
    void loadRecentProjectsList();

    /**
     * @brief Save recent projects to settings
     */
    void saveRecentProjectsList();

private:
    ProjectInfo m_currentProject;
    juce::File m_defaultProjectDirectory;
    std::vector<juce::File> m_recentProjects;

    // Auto-save
    bool m_autoSaveEnabled = true;
    int m_autoSaveInterval = 300;  // 5 minutes
    juce::Time m_lastAutoSave;

    // Settings
    juce::ApplicationProperties m_appProperties;

    // Backup
    int m_maxBackupCopies = 5;

    bool m_initialized = false;

    // Constants
    static constexpr const char* PROJECT_FILE_EXTENSION = ".echoel";
    static constexpr const char* PROJECT_VERSION = "1.0";
    static constexpr int MAX_RECENT_PROJECTS = 20;
};

} // namespace project
} // namespace echoelmusic
