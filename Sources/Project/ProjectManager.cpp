#include "ProjectManager.h"
#include <fstream>

namespace echoelmusic {
namespace project {

// ============================================================================
// SINGLETON
// ============================================================================

ProjectManager& ProjectManager::getInstance()
{
    static ProjectManager instance;
    return instance;
}

// ============================================================================
// CONSTRUCTOR / DESTRUCTOR
// ============================================================================

ProjectManager::ProjectManager()
{
    // Default project directory: ~/Documents/Echoelmusic Projects/
    m_defaultProjectDirectory = juce::File::getSpecialLocation(
        juce::File::userDocumentsDirectory
    ).getChildFile("Echoelmusic Projects");

    // Create if doesn't exist
    if (!m_defaultProjectDirectory.exists())
    {
        m_defaultProjectDirectory.createDirectory();
    }

    // Initialize application properties (for settings)
    juce::PropertiesFile::Options options;
    options.applicationName = "Echoelmusic";
    options.filenameSuffix = ".settings";
    options.osxLibrarySubFolder = "Application Support";
    options.folderName = "Echoelmusic";
    options.commonToAllUsers = false;

    m_appProperties.setStorageParameters(options);
}

ProjectManager::~ProjectManager()
{
    // Save settings on exit
    if (m_appProperties.getUserSettings() != nullptr)
    {
        m_appProperties.getUserSettings()->saveIfNeeded();
    }
}

// ============================================================================
// INITIALIZATION
// ============================================================================

bool ProjectManager::initialize()
{
    if (m_initialized)
        return true;

    // Load recent projects list
    loadRecentProjectsList();

    // Create new empty project
    createNewProject("Untitled Project");

    m_initialized = true;
    return true;
}

// ============================================================================
// PROJECT MANAGEMENT
// ============================================================================

bool ProjectManager::createNewProject(const juce::String& projectName)
{
    // Check for unsaved changes
    if (hasUnsavedChanges())
    {
        // In a real app, show dialog asking to save
        // For now, just log
        DBG("Warning: Creating new project with unsaved changes!");
    }

    // Reset project info
    m_currentProject = ProjectInfo();
    m_currentProject.name = projectName;
    m_currentProject.tempo = 128.0;
    m_currentProject.timeSignature = "4/4";
    m_currentProject.sampleRate = 48000;
    m_currentProject.bufferSize = 512;
    m_currentProject.isModified = false;
    m_currentProject.lastModified = juce::Time::getCurrentTime();

    // Set file path to default directory
    m_currentProject.filePath = m_defaultProjectDirectory.getChildFile(
        projectName + PROJECT_FILE_EXTENSION
    );

    DBG("Created new project: " + projectName);
    return true;
}

bool ProjectManager::saveProject(const juce::File& filePath)
{
    // Use current project path if none specified
    juce::File saveFile = filePath.existsAsFile() || filePath != juce::File()
                            ? filePath
                            : m_currentProject.filePath;

    // If still no path, this is a new project - need "Save As"
    if (saveFile == juce::File())
    {
        DBG("Error: No file path specified for new project. Use saveProjectAs()");
        return false;
    }

    // Export to JSON
    juce::String jsonString = exportToJSON();

    // Write to file
    if (!saveFile.replaceWithText(jsonString))
    {
        DBG("Error: Failed to write project file: " + saveFile.getFullPathName());
        return false;
    }

    // Update project info
    m_currentProject.filePath = saveFile;
    m_currentProject.isModified = false;
    m_currentProject.lastModified = juce::Time::getCurrentTime();

    // Add to recent projects
    addToRecentProjects(saveFile);

    DBG("Saved project: " + saveFile.getFullPathName());
    return true;
}

bool ProjectManager::loadProject(const juce::File& filePath)
{
    // Check file exists
    if (!filePath.existsAsFile())
    {
        DBG("Error: Project file doesn't exist: " + filePath.getFullPathName());
        return false;
    }

    // Read file
    juce::String jsonString = filePath.loadFileAsString();
    if (jsonString.isEmpty())
    {
        DBG("Error: Project file is empty: " + filePath.getFullPathName());
        return false;
    }

    // Import from JSON
    if (!importFromJSON(jsonString))
    {
        DBG("Error: Failed to parse project file: " + filePath.getFullPathName());
        return false;
    }

    // Update project info
    m_currentProject.filePath = filePath;
    m_currentProject.isModified = false;
    m_currentProject.lastModified = juce::Time(filePath.getLastModificationTime());

    // Add to recent projects
    addToRecentProjects(filePath);

    DBG("Loaded project: " + filePath.getFullPathName());
    return true;
}

bool ProjectManager::saveProjectAs(const juce::File& filePath)
{
    // Check valid path
    if (filePath == juce::File())
    {
        DBG("Error: Invalid file path for Save As");
        return false;
    }

    // Save to new location
    return saveProject(filePath);
}

bool ProjectManager::hasUnsavedChanges() const
{
    return m_currentProject.isModified;
}

void ProjectManager::markAsModified()
{
    m_currentProject.isModified = true;
}

const ProjectManager::ProjectInfo& ProjectManager::getCurrentProjectInfo() const
{
    return m_currentProject;
}

void ProjectManager::setProjectInfo(const ProjectInfo& info)
{
    m_currentProject = info;
    markAsModified();
}

// ============================================================================
// AUTO-SAVE
// ============================================================================

void ProjectManager::setAutoSave(bool enabled, int intervalSeconds)
{
    m_autoSaveEnabled = enabled;
    m_autoSaveInterval = intervalSeconds;

    if (enabled)
    {
        m_lastAutoSave = juce::Time::getCurrentTime();
        DBG("Auto-save enabled: every " + juce::String(intervalSeconds) + " seconds");
    }
}

void ProjectManager::performAutoSave()
{
    if (!m_autoSaveEnabled)
        return;

    // Check if enough time has passed
    auto now = juce::Time::getCurrentTime();
    auto elapsed = (now - m_lastAutoSave).inSeconds();

    if (elapsed < m_autoSaveInterval)
        return;

    // Check if project has unsaved changes
    if (!hasUnsavedChanges())
        return;

    // Create auto-save file (append .autosave)
    juce::File autoSaveFile = m_currentProject.filePath.withFileExtension(
        PROJECT_FILE_EXTENSION + juce::String(".autosave")
    );

    // Save to auto-save file
    juce::String jsonString = exportToJSON();
    if (autoSaveFile.replaceWithText(jsonString))
    {
        m_lastAutoSave = now;
        DBG("Auto-saved to: " + autoSaveFile.getFullPathName());
    }
    else
    {
        DBG("Error: Auto-save failed!");
    }
}

// ============================================================================
// RECENT PROJECTS
// ============================================================================

std::vector<juce::File> ProjectManager::getRecentProjects(int maxItems) const
{
    int count = juce::jmin(maxItems, (int)m_recentProjects.size());
    return std::vector<juce::File>(
        m_recentProjects.begin(),
        m_recentProjects.begin() + count
    );
}

void ProjectManager::addToRecentProjects(const juce::File& filePath)
{
    // Remove if already in list
    m_recentProjects.erase(
        std::remove(m_recentProjects.begin(), m_recentProjects.end(), filePath),
        m_recentProjects.end()
    );

    // Add to front
    m_recentProjects.insert(m_recentProjects.begin(), filePath);

    // Limit size
    if (m_recentProjects.size() > MAX_RECENT_PROJECTS)
    {
        m_recentProjects.resize(MAX_RECENT_PROJECTS);
    }

    // Save to settings
    saveRecentProjectsList();
}

void ProjectManager::clearRecentProjects()
{
    m_recentProjects.clear();
    saveRecentProjectsList();
}

void ProjectManager::loadRecentProjectsList()
{
    auto* settings = m_appProperties.getUserSettings();
    if (settings == nullptr)
        return;

    // Load from settings
    juce::StringArray recentPaths;
    recentPaths.addTokens(settings->getValue("recentProjects"), "|", "");

    m_recentProjects.clear();
    for (const auto& path : recentPaths)
    {
        juce::File file(path);
        if (file.existsAsFile())
        {
            m_recentProjects.push_back(file);
        }
    }
}

void ProjectManager::saveRecentProjectsList()
{
    auto* settings = m_appProperties.getUserSettings();
    if (settings == nullptr)
        return;

    // Convert to string
    juce::StringArray recentPaths;
    for (const auto& file : m_recentProjects)
    {
        recentPaths.add(file.getFullPathName());
    }

    // Save to settings
    settings->setValue("recentProjects", recentPaths.joinIntoString("|"));
    settings->saveIfNeeded();
}

// ============================================================================
// JSON SERIALIZATION
// ============================================================================

juce::String ProjectManager::exportToJSON() const
{
    // Create root JSON object
    juce::DynamicObject::Ptr root = new juce::DynamicObject();

    // Project metadata
    root->setProperty("version", PROJECT_VERSION);
    root->setProperty("name", m_currentProject.name);
    root->setProperty("artist", m_currentProject.artist);
    root->setProperty("description", m_currentProject.description);
    root->setProperty("tempo", m_currentProject.tempo);
    root->setProperty("timeSignature", m_currentProject.timeSignature);
    root->setProperty("sampleRate", m_currentProject.sampleRate);
    root->setProperty("bufferSize", m_currentProject.bufferSize);

    // Audio engine state
    // TODO: Serialize AudioEngine when integrated
    juce::Array<juce::var> tracks;
    // For now, empty array (will be filled when AudioEngine integration is done)
    root->setProperty("tracks", tracks);

    // Master effects
    juce::Array<juce::var> masterEffects;
    root->setProperty("masterEffects", masterEffects);

    // Convert to JSON string
    return juce::JSON::toString(juce::var(root.get()), true);  // true = pretty print
}

bool ProjectManager::importFromJSON(const juce::String& jsonString)
{
    // Parse JSON
    juce::var json;
    auto result = juce::JSON::parse(jsonString, json);

    if (result.failed())
    {
        DBG("Error parsing JSON: " + result.getErrorMessage());
        return false;
    }

    // Check version
    juce::String version = json.getProperty("version", "unknown");
    if (version != PROJECT_VERSION)
    {
        DBG("Warning: Project version mismatch. File: " + version + ", Current: " + PROJECT_VERSION);
        // Continue anyway (backward compatibility)
    }

    // Load project metadata
    m_currentProject.name = json.getProperty("name", "Untitled");
    m_currentProject.artist = json.getProperty("artist", "");
    m_currentProject.description = json.getProperty("description", "");
    m_currentProject.tempo = json.getProperty("tempo", 128.0);
    m_currentProject.timeSignature = json.getProperty("timeSignature", "4/4");
    m_currentProject.sampleRate = json.getProperty("sampleRate", 48000);
    m_currentProject.bufferSize = json.getProperty("bufferSize", 512);

    // Load tracks
    // TODO: Deserialize tracks when AudioEngine integration is done
    auto tracksArray = json.getProperty("tracks", juce::var());
    if (tracksArray.isArray())
    {
        DBG("Found " + juce::String(tracksArray.size()) + " tracks");
        // Will implement deserialization when AudioEngine is integrated
    }

    // Load master effects
    auto effectsArray = json.getProperty("masterEffects", juce::var());
    if (effectsArray.isArray())
    {
        DBG("Found " + juce::String(effectsArray.size()) + " master effects");
    }

    return true;
}

// ============================================================================
// SETTINGS
// ============================================================================

juce::File ProjectManager::getDefaultProjectDirectory() const
{
    return m_defaultProjectDirectory;
}

void ProjectManager::setDefaultProjectDirectory(const juce::File& directory)
{
    if (directory.isDirectory() || directory.createDirectory())
    {
        m_defaultProjectDirectory = directory;

        // Save to settings
        auto* settings = m_appProperties.getUserSettings();
        if (settings != nullptr)
        {
            settings->setValue("defaultProjectDirectory", directory.getFullPathName());
            settings->saveIfNeeded();
        }
    }
}

// ============================================================================
// TEMPLATES
// ============================================================================

bool ProjectManager::createTemplate(const juce::String& templateName, const juce::String& description)
{
    // Get templates directory
    juce::File templatesDir = juce::File::getSpecialLocation(
        juce::File::userApplicationDataDirectory
    ).getChildFile("Echoelmusic").getChildFile("Templates");

    if (!templatesDir.exists())
    {
        templatesDir.createDirectory();
    }

    // Create template file
    juce::File templateFile = templatesDir.getChildFile(templateName + ".template");

    // Save current project as template
    juce::String jsonString = exportToJSON();

    // Add template metadata
    juce::var json;
    juce::JSON::parse(jsonString, json);

    if (auto* obj = json.getDynamicObject())
    {
        obj->setProperty("templateName", templateName);
        obj->setProperty("templateDescription", description);
        jsonString = juce::JSON::toString(json, true);
    }

    // Write to file
    if (!templateFile.replaceWithText(jsonString))
    {
        DBG("Error: Failed to create template: " + templateName);
        return false;
    }

    DBG("Created template: " + templateName);
    return true;
}

std::vector<juce::String> ProjectManager::getAvailableTemplates() const
{
    std::vector<juce::String> templates;

    // Get templates directory
    juce::File templatesDir = juce::File::getSpecialLocation(
        juce::File::userApplicationDataDirectory
    ).getChildFile("Echoelmusic").getChildFile("Templates");

    if (!templatesDir.exists())
        return templates;

    // Find all .template files
    juce::Array<juce::File> templateFiles;
    templatesDir.findChildFiles(templateFiles, juce::File::findFiles, false, "*.template");

    for (const auto& file : templateFiles)
    {
        templates.push_back(file.getFileNameWithoutExtension());
    }

    return templates;
}

bool ProjectManager::loadFromTemplate(const juce::String& templateName)
{
    // Get template file
    juce::File templatesDir = juce::File::getSpecialLocation(
        juce::File::userApplicationDataDirectory
    ).getChildFile("Echoelmusic").getChildFile("Templates");

    juce::File templateFile = templatesDir.getChildFile(templateName + ".template");

    if (!templateFile.existsAsFile())
    {
        DBG("Error: Template doesn't exist: " + templateName);
        return false;
    }

    // Load template
    juce::String jsonString = templateFile.loadFileAsString();
    if (!importFromJSON(jsonString))
    {
        DBG("Error: Failed to load template: " + templateName);
        return false;
    }

    // Reset file path (this is a new project based on template)
    m_currentProject.filePath = juce::File();
    m_currentProject.name = "Untitled (from " + templateName + ")";
    m_currentProject.isModified = true;

    DBG("Loaded template: " + templateName);
    return true;
}

// ============================================================================
// SERIALIZATION HELPERS (TODO: Integrate with AudioEngine)
// ============================================================================

juce::var ProjectManager::serializeAudioEngine(const audio::AudioEngine& engine) const
{
    // TODO: Implement when AudioEngine is integrated into ProjectManager
    juce::DynamicObject::Ptr engineState = new juce::DynamicObject();

    engineState->setProperty("sampleRate", engine.getSampleRate());
    engineState->setProperty("bufferSize", engine.getBlockSize());
    engineState->setProperty("isPlaying", engine.isPlaying());
    engineState->setProperty("currentPosition", engine.getCurrentPosition());

    // Serialize tracks
    juce::Array<juce::var> tracks;
    for (int i = 0; i < engine.getNumTracks(); ++i)
    {
        auto track = engine.getTrack(i);
        if (track != nullptr)
        {
            tracks.add(serializeTrack(*track));
        }
    }
    engineState->setProperty("tracks", tracks);

    return juce::var(engineState.get());
}

bool ProjectManager::deserializeAudioEngine(audio::AudioEngine& engine, const juce::var& json)
{
    // TODO: Implement when AudioEngine is integrated
    if (!json.isObject())
        return false;

    // Load tracks
    auto tracksArray = json.getProperty("tracks", juce::var());
    if (tracksArray.isArray())
    {
        for (int i = 0; i < tracksArray.size(); ++i)
        {
            auto trackData = tracksArray[i];
            auto track = deserializeTrack(trackData);
            if (track != nullptr)
            {
                // Add track to engine
                // engine.addTrack(std::move(track));
            }
        }
    }

    return true;
}

juce::var ProjectManager::serializeTrack(const audio::Track& track) const
{
    juce::DynamicObject::Ptr trackData = new juce::DynamicObject();

    trackData->setProperty("name", track.getName());
    trackData->setProperty("isAudioTrack", track.isAudioTrack());
    trackData->setProperty("volume", track.getVolume());
    trackData->setProperty("pan", track.getPan());
    trackData->setProperty("muted", track.isMuted());
    trackData->setProperty("soloed", track.isSoloed());
    trackData->setProperty("armed", track.isArmed());

    // Color (as ARGB int)
    trackData->setProperty("colour", (int)track.getColour().getARGB());

    // Audio clips
    if (track.isAudioTrack())
    {
        juce::Array<juce::var> clips;
        // TODO: Serialize audio clips
        trackData->setProperty("audioClips", clips);
    }
    else
    {
        // MIDI notes
        juce::Array<juce:var> midiData;
        // TODO: Serialize MIDI data
        trackData->setProperty("midiNotes", midiData);
    }

    return juce::var(trackData.get());
}

std::unique_ptr<audio::Track> ProjectManager::deserializeTrack(const juce::var& json)
{
    if (!json.isObject())
        return nullptr;

    juce::String name = json.getProperty("name", "Track");
    bool isAudioTrack = json.getProperty("isAudioTrack", true);

    auto track = std::make_unique<audio::Track>(name, isAudioTrack);

    track->setVolume(json.getProperty("volume", 0.75f));
    track->setPan(json.getProperty("pan", 0.0f));
    track->setMuted(json.getProperty("muted", false));
    track->setSoloed(json.getProperty("soloed", false));
    track->setArmed(json.getProperty("armed", false));

    // Color
    int colourARGB = json.getProperty("colour", 0xFF4A90E2);
    track->setColour(juce::Colour(colourARGB));

    // Load clips/MIDI
    // TODO: Implement when clip/MIDI systems are integrated

    return track;
}

} // namespace project
} // namespace echoelmusic
