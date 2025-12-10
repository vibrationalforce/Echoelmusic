/**
 * ProjectManager.h
 * Echoelmusic Project Save/Load Manager
 *
 * High-level project orchestration layer that integrates:
 * - SessionManager (project metadata)
 * - Track audio data
 * - Plugin states
 * - MIDI settings
 * - Bio-feedback configuration
 *
 * Project Structure:
 * MyProject.echoelmusic/
 *   ├── project.xml           (SessionManager format)
 *   ├── tracks/
 *   │   ├── track_001.wav
 *   │   ├── track_002.wav
 *   │   └── ...
 *   ├── midi/
 *   │   ├── track_001.mid
 *   │   └── ...
 *   ├── plugins/
 *   │   ├── track_001_fx.bin
 *   │   └── ...
 *   └── backups/
 *       └── project.autosave.xml
 *
 * Copyright (c) 2025 Echoelmusic
 */

#pragma once

#include <JuceHeader.h>
#include <memory>
#include <vector>
#include <functional>

// Forward declarations
namespace Echoelmusic {
    class AudioEngine;
    class Track;
}

namespace Echoelmusic {

// ============================================================================
// Project Info
// ============================================================================

struct ProjectInfo {
    juce::String title = "Untitled Project";
    juce::String artist;
    juce::String description;
    juce::String genre;
    juce::String tags;

    double tempo = 120.0;
    int timeSignatureNumerator = 4;
    int timeSignatureDenominator = 4;
    double sampleRate = 48000.0;
    int blockSize = 512;

    juce::Time createdTime;
    juce::Time lastModifiedTime;
    juce::String version = "1.0";

    // Bio-feedback settings
    bool bioFeedbackEnabled = false;
    juce::String hrvDeviceId;
    double hrvCoherenceThreshold = 0.5;
};

// ============================================================================
// Track State (for serialization)
// ============================================================================

struct TrackState {
    int trackIndex = 0;
    juce::String name;
    juce::String audioFileName;     // Relative path in tracks/
    juce::String midiFileName;      // Relative path in midi/
    juce::String pluginStateFile;   // Relative path in plugins/

    float volume = 1.0f;
    float pan = 0.0f;
    bool muted = false;
    bool soloed = false;
    bool armed = false;

    juce::Colour color;

    // Audio clip info
    double clipStartTime = 0.0;
    double clipLength = 0.0;
    double clipOffset = 0.0;

    // MIDI clip info
    int midiNoteCount = 0;
};

// ============================================================================
// Callback Types
// ============================================================================

using ProjectSavedCallback = std::function<void(const juce::File& projectFile)>;
using ProjectLoadedCallback = std::function<void(const juce::File& projectFile)>;
using ProjectErrorCallback = std::function<void(const juce::String& errorMessage)>;
using ProgressCallback = std::function<void(float progress, const juce::String& status)>;

// ============================================================================
// ProjectManager Class
// ============================================================================

class ProjectManager {
public:
    ProjectManager();
    ~ProjectManager();

    // --- Initialization ---
    void setAudioEngine(AudioEngine* engine);

    // --- Project Operations ---
    bool newProject(const juce::String& title = "Untitled Project");
    bool saveProject();
    bool saveProjectAs(const juce::File& file);
    bool loadProject(const juce::File& file);
    bool closeProject();

    // --- Quick Save/Load ---
    bool quickSave();
    bool loadLastProject();

    // --- Auto-Save ---
    void enableAutoSave(bool enable, int intervalMinutes = 5);
    bool isAutoSaveEnabled() const { return autoSaveEnabled; }
    void triggerAutoSave();

    // --- Project Info ---
    const ProjectInfo& getProjectInfo() const { return projectInfo; }
    void setProjectInfo(const ProjectInfo& info);

    juce::String getProjectTitle() const { return projectInfo.title; }
    void setProjectTitle(const juce::String& title);

    double getTempo() const { return projectInfo.tempo; }
    void setTempo(double bpm);

    // --- Project State ---
    bool hasUnsavedChanges() const { return isDirty; }
    void markDirty() { isDirty = true; }
    void markClean() { isDirty = false; }

    juce::File getCurrentProjectFile() const { return currentProjectFile; }
    bool hasProjectFile() const { return currentProjectFile.existsAsFile(); }

    // --- Recent Projects ---
    juce::StringArray getRecentProjects() const;
    void addToRecentProjects(const juce::File& file);
    void clearRecentProjects();

    // --- Export ---
    bool exportAudio(const juce::File& outputFile, int formatIndex = 0);
    bool exportMIDI(const juce::File& outputFile);
    bool exportStems(const juce::File& outputFolder);

    // --- Callbacks ---
    void setProjectSavedCallback(ProjectSavedCallback callback) { onProjectSaved = callback; }
    void setProjectLoadedCallback(ProjectLoadedCallback callback) { onProjectLoaded = callback; }
    void setProjectErrorCallback(ProjectErrorCallback callback) { onProjectError = callback; }
    void setProgressCallback(ProgressCallback callback) { onProgress = callback; }

    // --- Backup & Recovery ---
    bool hasAutoSaveBackup() const;
    bool recoverFromAutoSave();
    void createBackup();

    // --- Validation ---
    bool validateProject(const juce::File& projectFile);
    juce::String getLastError() const { return lastError; }

private:
    // Internal save/load
    bool saveProjectInternal(const juce::File& file);
    bool loadProjectInternal(const juce::File& file);

    // XML generation
    std::unique_ptr<juce::XmlElement> createProjectXML();
    bool restoreFromXML(const juce::XmlElement& xml);

    // Track serialization
    bool saveTrackAudio(int trackIndex, const juce::File& tracksFolder);
    bool loadTrackAudio(int trackIndex, const juce::File& tracksFolder);
    bool saveTrackMIDI(int trackIndex, const juce::File& midiFolder);
    bool loadTrackMIDI(int trackIndex, const juce::File& midiFolder);

    // Plugin state serialization
    bool savePluginStates(const juce::File& pluginsFolder);
    bool loadPluginStates(const juce::File& pluginsFolder);

    // File utilities
    juce::File getProjectFolder() const;
    juce::File getTracksFolder() const;
    juce::File getMIDIFolder() const;
    juce::File getPluginsFolder() const;
    juce::File getBackupsFolder() const;
    juce::File getAutoSaveFile() const;

    bool createProjectStructure(const juce::File& projectFolder);
    void cleanupTempFiles();

    // Recent projects
    void loadRecentProjects();
    void saveRecentProjects();
    juce::File getRecentProjectsFile() const;

    // Error handling
    void setError(const juce::String& error);

    // Members
    AudioEngine* audioEngine = nullptr;
    ProjectInfo projectInfo;

    juce::File currentProjectFile;
    bool isDirty = false;
    juce::String lastError;

    // Auto-save
    bool autoSaveEnabled = true;
    int autoSaveIntervalMinutes = 5;
    std::unique_ptr<juce::Timer> autoSaveTimer;

    // Recent projects
    juce::StringArray recentProjects;
    static constexpr int MAX_RECENT_PROJECTS = 10;

    // Callbacks
    ProjectSavedCallback onProjectSaved;
    ProjectLoadedCallback onProjectLoaded;
    ProjectErrorCallback onProjectError;
    ProgressCallback onProgress;

    // Thread safety
    std::mutex projectMutex;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ProjectManager)
};

} // namespace Echoelmusic
