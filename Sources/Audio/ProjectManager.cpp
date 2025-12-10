/**
 * ProjectManager.cpp
 * Echoelmusic Project Manager Implementation
 *
 * Copyright (c) 2025 Echoelmusic
 */

#include "ProjectManager.h"
#include "AudioEngine.h"
#include "Track.h"

namespace Echoelmusic {

// ============================================================================
// Auto-Save Timer
// ============================================================================

class AutoSaveTimer : public juce::Timer {
public:
    AutoSaveTimer(ProjectManager& pm) : projectManager(pm) {}

    void timerCallback() override {
        projectManager.triggerAutoSave();
    }

private:
    ProjectManager& projectManager;
};

// ============================================================================
// Constructor / Destructor
// ============================================================================

ProjectManager::ProjectManager() {
    loadRecentProjects();
    projectInfo.createdTime = juce::Time::getCurrentTime();
    projectInfo.lastModifiedTime = projectInfo.createdTime;

    DBG("ProjectManager: Initialized");
}

ProjectManager::~ProjectManager() {
    if (autoSaveTimer) {
        autoSaveTimer->stopTimer();
    }
}

// ============================================================================
// Initialization
// ============================================================================

void ProjectManager::setAudioEngine(AudioEngine* engine) {
    audioEngine = engine;
}

// ============================================================================
// Project Operations
// ============================================================================

bool ProjectManager::newProject(const juce::String& title) {
    std::lock_guard<std::mutex> lock(projectMutex);

    // Clear current project
    currentProjectFile = juce::File();
    isDirty = false;

    // Reset project info
    projectInfo = ProjectInfo();
    projectInfo.title = title;
    projectInfo.createdTime = juce::Time::getCurrentTime();
    projectInfo.lastModifiedTime = projectInfo.createdTime;

    // Reset audio engine if available
    if (audioEngine) {
        // audioEngine->reset();  // TODO: Implement
    }

    DBG("ProjectManager: New project created - " << title);
    return true;
}

bool ProjectManager::saveProject() {
    if (!currentProjectFile.existsAsFile()) {
        setError("No project file set. Use Save As first.");
        return false;
    }
    return saveProjectInternal(currentProjectFile);
}

bool ProjectManager::saveProjectAs(const juce::File& file) {
    return saveProjectInternal(file);
}

bool ProjectManager::loadProject(const juce::File& file) {
    return loadProjectInternal(file);
}

bool ProjectManager::closeProject() {
    std::lock_guard<std::mutex> lock(projectMutex);

    if (isDirty) {
        // Caller should handle unsaved changes prompt
        DBG("ProjectManager: Warning - closing project with unsaved changes");
    }

    // Stop auto-save
    if (autoSaveTimer) {
        autoSaveTimer->stopTimer();
    }

    // Clean up temp files
    cleanupTempFiles();

    // Reset state
    currentProjectFile = juce::File();
    projectInfo = ProjectInfo();
    isDirty = false;

    DBG("ProjectManager: Project closed");
    return true;
}

// ============================================================================
// Quick Save/Load
// ============================================================================

bool ProjectManager::quickSave() {
    if (hasProjectFile()) {
        return saveProject();
    }

    // No file set, use auto-save location
    auto autoSave = getAutoSaveFile();
    if (autoSave.hasWriteAccess()) {
        return saveProjectInternal(autoSave);
    }

    setError("Cannot quick save - no project file and no auto-save location");
    return false;
}

bool ProjectManager::loadLastProject() {
    auto recent = getRecentProjects();
    if (recent.isEmpty()) {
        setError("No recent projects");
        return false;
    }

    juce::File lastProject(recent[0]);
    if (lastProject.existsAsFile()) {
        return loadProject(lastProject);
    }

    setError("Last project file not found: " + recent[0]);
    return false;
}

// ============================================================================
// Auto-Save
// ============================================================================

void ProjectManager::enableAutoSave(bool enable, int intervalMinutes) {
    autoSaveEnabled = enable;
    autoSaveIntervalMinutes = intervalMinutes;

    if (enable) {
        if (!autoSaveTimer) {
            autoSaveTimer = std::make_unique<AutoSaveTimer>(*this);
        }
        autoSaveTimer->startTimer(intervalMinutes * 60 * 1000);
        DBG("ProjectManager: Auto-save enabled (" << intervalMinutes << " min)");
    } else {
        if (autoSaveTimer) {
            autoSaveTimer->stopTimer();
        }
        DBG("ProjectManager: Auto-save disabled");
    }
}

void ProjectManager::triggerAutoSave() {
    if (!isDirty) {
        return;  // Nothing to save
    }

    auto autoSaveFile = getAutoSaveFile();
    if (autoSaveFile.hasWriteAccess()) {
        DBG("ProjectManager: Auto-saving...");

        // Save to auto-save file (doesn't change currentProjectFile)
        auto xml = createProjectXML();
        if (xml && xml->writeTo(autoSaveFile)) {
            DBG("ProjectManager: Auto-save complete");
        } else {
            DBG("ProjectManager: Auto-save failed");
        }
    }
}

// ============================================================================
// Project Info
// ============================================================================

void ProjectManager::setProjectInfo(const ProjectInfo& info) {
    projectInfo = info;
    projectInfo.lastModifiedTime = juce::Time::getCurrentTime();
    markDirty();
}

void ProjectManager::setProjectTitle(const juce::String& title) {
    projectInfo.title = title;
    projectInfo.lastModifiedTime = juce::Time::getCurrentTime();
    markDirty();
}

void ProjectManager::setTempo(double bpm) {
    projectInfo.tempo = bpm;
    projectInfo.lastModifiedTime = juce::Time::getCurrentTime();
    markDirty();
}

// ============================================================================
// Recent Projects
// ============================================================================

juce::StringArray ProjectManager::getRecentProjects() const {
    return recentProjects;
}

void ProjectManager::addToRecentProjects(const juce::File& file) {
    juce::String path = file.getFullPathName();

    // Remove if already exists
    recentProjects.removeString(path);

    // Add to front
    recentProjects.insert(0, path);

    // Trim to max
    while (recentProjects.size() > MAX_RECENT_PROJECTS) {
        recentProjects.remove(recentProjects.size() - 1);
    }

    saveRecentProjects();
}

void ProjectManager::clearRecentProjects() {
    recentProjects.clear();
    saveRecentProjects();
}

// ============================================================================
// Export
// ============================================================================

bool ProjectManager::exportAudio(const juce::File& outputFile, int formatIndex) {
    // TODO: Integrate with AudioExporter
    setError("Audio export not yet implemented");
    return false;
}

bool ProjectManager::exportMIDI(const juce::File& outputFile) {
    // TODO: Implement MIDI export
    setError("MIDI export not yet implemented");
    return false;
}

bool ProjectManager::exportStems(const juce::File& outputFolder) {
    // TODO: Export each track as separate file
    setError("Stem export not yet implemented");
    return false;
}

// ============================================================================
// Backup & Recovery
// ============================================================================

bool ProjectManager::hasAutoSaveBackup() const {
    auto autoSaveFile = getAutoSaveFile();
    return autoSaveFile.existsAsFile();
}

bool ProjectManager::recoverFromAutoSave() {
    auto autoSaveFile = getAutoSaveFile();
    if (!autoSaveFile.existsAsFile()) {
        setError("No auto-save backup found");
        return false;
    }

    return loadProjectInternal(autoSaveFile);
}

void ProjectManager::createBackup() {
    if (!currentProjectFile.existsAsFile()) {
        return;
    }

    auto backupsFolder = getBackupsFolder();
    if (!backupsFolder.exists()) {
        backupsFolder.createDirectory();
    }

    auto timestamp = juce::Time::getCurrentTime().formatted("%Y%m%d_%H%M%S");
    auto backupFile = backupsFolder.getChildFile("backup_" + timestamp + ".xml");

    auto xml = createProjectXML();
    if (xml) {
        xml->writeTo(backupFile);
        DBG("ProjectManager: Backup created - " << backupFile.getFileName());
    }
}

// ============================================================================
// Validation
// ============================================================================

bool ProjectManager::validateProject(const juce::File& projectFile) {
    if (!projectFile.existsAsFile()) {
        setError("Project file does not exist");
        return false;
    }

    auto xml = juce::parseXML(projectFile);
    if (!xml) {
        setError("Invalid XML format");
        return false;
    }

    if (!xml->hasTagName("EchoelmusicSession")) {
        setError("Not a valid Echoelmusic project");
        return false;
    }

    return true;
}

// ============================================================================
// Internal Save
// ============================================================================

bool ProjectManager::saveProjectInternal(const juce::File& file) {
    std::lock_guard<std::mutex> lock(projectMutex);

    if (onProgress) onProgress(0.0f, "Saving project...");

    // Create project folder structure if saving as bundle
    juce::File projectFolder = file.getParentDirectory();
    if (file.getFileExtension() == ".echoelmusic") {
        projectFolder = file;
        if (!projectFolder.exists()) {
            if (!createProjectStructure(projectFolder)) {
                return false;
            }
        }
    }

    // Save project XML
    if (onProgress) onProgress(0.2f, "Saving project metadata...");

    auto xml = createProjectXML();
    if (!xml) {
        setError("Failed to create project XML");
        return false;
    }

    juce::File xmlFile = file;
    if (file.isDirectory()) {
        xmlFile = file.getChildFile("project.xml");
    }

    if (!xml->writeTo(xmlFile)) {
        setError("Failed to write project file");
        return false;
    }

    // Save track audio
    if (onProgress) onProgress(0.4f, "Saving audio tracks...");
    auto tracksFolder = file.isDirectory() ? file.getChildFile("tracks") : projectFolder.getChildFile("tracks");
    if (!tracksFolder.exists()) tracksFolder.createDirectory();

    // TODO: Save each track's audio
    // for (int i = 0; i < audioEngine->getTrackCount(); ++i) {
    //     saveTrackAudio(i, tracksFolder);
    // }

    // Save MIDI data
    if (onProgress) onProgress(0.6f, "Saving MIDI data...");
    // TODO: Save MIDI tracks

    // Save plugin states
    if (onProgress) onProgress(0.8f, "Saving plugin states...");
    // TODO: Save plugin states

    // Update state
    currentProjectFile = file;
    isDirty = false;
    projectInfo.lastModifiedTime = juce::Time::getCurrentTime();

    // Add to recent projects
    addToRecentProjects(file);

    if (onProgress) onProgress(1.0f, "Project saved");

    if (onProjectSaved) {
        onProjectSaved(file);
    }

    DBG("ProjectManager: Project saved - " << file.getFullPathName());
    return true;
}

// ============================================================================
// Internal Load
// ============================================================================

bool ProjectManager::loadProjectInternal(const juce::File& file) {
    std::lock_guard<std::mutex> lock(projectMutex);

    if (onProgress) onProgress(0.0f, "Loading project...");

    juce::File xmlFile = file;
    if (file.isDirectory()) {
        xmlFile = file.getChildFile("project.xml");
    }

    if (!xmlFile.existsAsFile()) {
        setError("Project file not found: " + xmlFile.getFullPathName());
        return false;
    }

    // Parse XML
    if (onProgress) onProgress(0.2f, "Parsing project file...");

    auto xml = juce::parseXML(xmlFile);
    if (!xml) {
        setError("Failed to parse project XML");
        return false;
    }

    if (!xml->hasTagName("EchoelmusicSession")) {
        setError("Invalid project format");
        return false;
    }

    // Restore from XML
    if (onProgress) onProgress(0.4f, "Restoring project state...");

    if (!restoreFromXML(*xml)) {
        return false;
    }

    // Load track audio
    if (onProgress) onProgress(0.6f, "Loading audio tracks...");
    auto tracksFolder = file.isDirectory() ? file.getChildFile("tracks") : file.getParentDirectory().getChildFile("tracks");
    // TODO: Load track audio

    // Load MIDI data
    if (onProgress) onProgress(0.8f, "Loading MIDI data...");
    // TODO: Load MIDI tracks

    // Update state
    currentProjectFile = file;
    isDirty = false;

    // Add to recent projects
    addToRecentProjects(file);

    if (onProgress) onProgress(1.0f, "Project loaded");

    if (onProjectLoaded) {
        onProjectLoaded(file);
    }

    DBG("ProjectManager: Project loaded - " << file.getFullPathName());
    return true;
}

// ============================================================================
// XML Generation
// ============================================================================

std::unique_ptr<juce::XmlElement> ProjectManager::createProjectXML() {
    auto xml = std::make_unique<juce::XmlElement>("EchoelmusicSession");
    xml->setAttribute("version", projectInfo.version);

    // Project Info
    auto* infoElement = xml->createNewChildElement("ProjectInfo");
    infoElement->createNewChildElement("Title")->addTextElement(projectInfo.title);
    infoElement->createNewChildElement("Artist")->addTextElement(projectInfo.artist);
    infoElement->createNewChildElement("Description")->addTextElement(projectInfo.description);
    infoElement->createNewChildElement("Genre")->addTextElement(projectInfo.genre);
    infoElement->createNewChildElement("Tags")->addTextElement(projectInfo.tags);

    auto* tempoElement = infoElement->createNewChildElement("Tempo");
    tempoElement->addTextElement(juce::String(projectInfo.tempo));

    auto* timeSignature = infoElement->createNewChildElement("TimeSignature");
    timeSignature->setAttribute("numerator", projectInfo.timeSignatureNumerator);
    timeSignature->setAttribute("denominator", projectInfo.timeSignatureDenominator);

    infoElement->createNewChildElement("SampleRate")->addTextElement(juce::String(projectInfo.sampleRate));
    infoElement->createNewChildElement("BlockSize")->addTextElement(juce::String(projectInfo.blockSize));

    infoElement->createNewChildElement("CreatedTime")->addTextElement(
        projectInfo.createdTime.toISO8601(true));
    infoElement->createNewChildElement("LastModifiedTime")->addTextElement(
        projectInfo.lastModifiedTime.toISO8601(true));

    // Bio-feedback Settings
    auto* bioElement = xml->createNewChildElement("BioFeedback");
    bioElement->setAttribute("enabled", projectInfo.bioFeedbackEnabled);
    bioElement->setAttribute("hrvDeviceId", projectInfo.hrvDeviceId);
    bioElement->setAttribute("coherenceThreshold", projectInfo.hrvCoherenceThreshold);

    // Tracks
    auto* tracksElement = xml->createNewChildElement("Tracks");
    if (audioEngine) {
        // TODO: Serialize tracks from audio engine
        // for (int i = 0; i < audioEngine->getTrackCount(); ++i) {
        //     auto* track = audioEngine->getTrack(i);
        //     auto* trackElement = tracksElement->createNewChildElement("Track");
        //     trackElement->setAttribute("index", i);
        //     trackElement->setAttribute("name", track->getName());
        //     // ... more track properties
        // }
    }

    // MIDI Settings
    auto* midiElement = xml->createNewChildElement("MIDISettings");
    // TODO: Serialize MIDI settings

    return xml;
}

bool ProjectManager::restoreFromXML(const juce::XmlElement& xml) {
    // Version check
    auto version = xml.getStringAttribute("version", "1.0");
    // TODO: Handle version migration

    // Project Info
    if (auto* infoElement = xml.getChildByName("ProjectInfo")) {
        if (auto* el = infoElement->getChildByName("Title"))
            projectInfo.title = el->getAllSubText();
        if (auto* el = infoElement->getChildByName("Artist"))
            projectInfo.artist = el->getAllSubText();
        if (auto* el = infoElement->getChildByName("Description"))
            projectInfo.description = el->getAllSubText();
        if (auto* el = infoElement->getChildByName("Genre"))
            projectInfo.genre = el->getAllSubText();
        if (auto* el = infoElement->getChildByName("Tags"))
            projectInfo.tags = el->getAllSubText();

        if (auto* el = infoElement->getChildByName("Tempo"))
            projectInfo.tempo = el->getAllSubText().getDoubleValue();

        if (auto* el = infoElement->getChildByName("TimeSignature")) {
            projectInfo.timeSignatureNumerator = el->getIntAttribute("numerator", 4);
            projectInfo.timeSignatureDenominator = el->getIntAttribute("denominator", 4);
        }

        if (auto* el = infoElement->getChildByName("SampleRate"))
            projectInfo.sampleRate = el->getAllSubText().getDoubleValue();
        if (auto* el = infoElement->getChildByName("BlockSize"))
            projectInfo.blockSize = el->getAllSubText().getIntValue();

        if (auto* el = infoElement->getChildByName("CreatedTime"))
            projectInfo.createdTime = juce::Time::fromISO8601(el->getAllSubText());
        if (auto* el = infoElement->getChildByName("LastModifiedTime"))
            projectInfo.lastModifiedTime = juce::Time::fromISO8601(el->getAllSubText());
    }

    // Bio-feedback
    if (auto* bioElement = xml.getChildByName("BioFeedback")) {
        projectInfo.bioFeedbackEnabled = bioElement->getBoolAttribute("enabled", false);
        projectInfo.hrvDeviceId = bioElement->getStringAttribute("hrvDeviceId");
        projectInfo.hrvCoherenceThreshold = bioElement->getDoubleAttribute("coherenceThreshold", 0.5);
    }

    // Tracks
    if (auto* tracksElement = xml.getChildByName("Tracks")) {
        // TODO: Restore tracks to audio engine
    }

    // MIDI Settings
    if (auto* midiElement = xml.getChildByName("MIDISettings")) {
        // TODO: Restore MIDI settings
    }

    return true;
}

// ============================================================================
// File Utilities
// ============================================================================

juce::File ProjectManager::getProjectFolder() const {
    if (currentProjectFile.isDirectory()) {
        return currentProjectFile;
    }
    return currentProjectFile.getParentDirectory();
}

juce::File ProjectManager::getTracksFolder() const {
    return getProjectFolder().getChildFile("tracks");
}

juce::File ProjectManager::getMIDIFolder() const {
    return getProjectFolder().getChildFile("midi");
}

juce::File ProjectManager::getPluginsFolder() const {
    return getProjectFolder().getChildFile("plugins");
}

juce::File ProjectManager::getBackupsFolder() const {
    return getProjectFolder().getChildFile("backups");
}

juce::File ProjectManager::getAutoSaveFile() const {
    // Use user's application data folder
    auto appDataFolder = juce::File::getSpecialLocation(
        juce::File::userApplicationDataDirectory)
        .getChildFile("Echoelmusic");

    if (!appDataFolder.exists()) {
        appDataFolder.createDirectory();
    }

    return appDataFolder.getChildFile("autosave.echoelmusic");
}

bool ProjectManager::createProjectStructure(const juce::File& projectFolder) {
    if (!projectFolder.createDirectory()) {
        setError("Failed to create project folder");
        return false;
    }

    projectFolder.getChildFile("tracks").createDirectory();
    projectFolder.getChildFile("midi").createDirectory();
    projectFolder.getChildFile("plugins").createDirectory();
    projectFolder.getChildFile("backups").createDirectory();

    return true;
}

void ProjectManager::cleanupTempFiles() {
    // TODO: Clean up temporary files
}

// ============================================================================
// Recent Projects Persistence
// ============================================================================

void ProjectManager::loadRecentProjects() {
    auto file = getRecentProjectsFile();
    if (file.existsAsFile()) {
        juce::StringArray lines;
        file.readLines(lines);
        for (const auto& line : lines) {
            if (line.isNotEmpty()) {
                recentProjects.add(line);
            }
        }
    }
}

void ProjectManager::saveRecentProjects() {
    auto file = getRecentProjectsFile();
    file.replaceWithText(recentProjects.joinIntoString("\n"));
}

juce::File ProjectManager::getRecentProjectsFile() const {
    return juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory)
        .getChildFile("Echoelmusic")
        .getChildFile("recent_projects.txt");
}

// ============================================================================
// Error Handling
// ============================================================================

void ProjectManager::setError(const juce::String& error) {
    lastError = error;
    DBG("ProjectManager Error: " << error);

    if (onProjectError) {
        onProjectError(error);
    }
}

// ============================================================================
// Track Serialization (Stubs)
// ============================================================================

bool ProjectManager::saveTrackAudio(int trackIndex, const juce::File& tracksFolder) {
    // TODO: Implement
    return true;
}

bool ProjectManager::loadTrackAudio(int trackIndex, const juce::File& tracksFolder) {
    // TODO: Implement
    return true;
}

bool ProjectManager::saveTrackMIDI(int trackIndex, const juce::File& midiFolder) {
    // TODO: Implement
    return true;
}

bool ProjectManager::loadTrackMIDI(int trackIndex, const juce::File& midiFolder) {
    // TODO: Implement
    return true;
}

bool ProjectManager::savePluginStates(const juce::File& pluginsFolder) {
    // TODO: Implement
    return true;
}

bool ProjectManager::loadPluginStates(const juce::File& pluginsFolder) {
    // TODO: Implement
    return true;
}

} // namespace Echoelmusic
