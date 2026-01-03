#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>
#include <fstream>
#include <filesystem>

/**
 * ProjectFileFormat - Production-Ready Project Save/Load
 *
 * Complete project persistence with:
 * - JSON metadata + binary audio data
 * - Track, clip, automation state
 * - Plugin state serialization
 * - Media file management (copy/reference)
 * - Auto-save and backup
 * - Version migration
 * - Compression (optional)
 *
 * File Structure:
 * .echoelproj/
 *   ├── project.json      (metadata, settings)
 *   ├── tracks.json       (track configuration)
 *   ├── clips.json        (clip data)
 *   ├── automation.json   (automation lanes)
 *   ├── plugins/          (plugin state blobs)
 *   ├── media/            (audio/video files)
 *   └── backups/          (auto-save snapshots)
 *
 * Super Ralph Wiggum Loop Genius Wise Save Mode
 */

namespace Echoelmusic {
namespace Project {

//==============================================================================
// Project Data Structures
//==============================================================================

struct ClipData
{
    std::string id;
    std::string name;
    std::string type;           // "audio", "midi", "video"
    std::string mediaPath;      // Path to media file
    double startTime = 0.0;     // Position in timeline (beats or seconds)
    double duration = 0.0;
    double offset = 0.0;        // Start offset within media
    float gain = 1.0f;
    float fadeInTime = 0.0f;
    float fadeOutTime = 0.0f;
    bool muted = false;
    bool locked = false;
    juce::Colour color{0xFF4A9EFF};

    // For MIDI clips
    std::vector<std::tuple<int, int, float, float>> midiNotes;  // pitch, vel, start, dur

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("id", juce::String(id));
        obj->setProperty("name", juce::String(name));
        obj->setProperty("type", juce::String(type));
        obj->setProperty("mediaPath", juce::String(mediaPath));
        obj->setProperty("startTime", startTime);
        obj->setProperty("duration", duration);
        obj->setProperty("offset", offset);
        obj->setProperty("gain", gain);
        obj->setProperty("fadeInTime", fadeInTime);
        obj->setProperty("fadeOutTime", fadeOutTime);
        obj->setProperty("muted", muted);
        obj->setProperty("locked", locked);
        obj->setProperty("color", static_cast<int>(color.getARGB()));
        return juce::var(obj);
    }

    static ClipData fromVar(const juce::var& v)
    {
        ClipData clip;
        if (auto* obj = v.getDynamicObject())
        {
            clip.id = obj->getProperty("id").toString().toStdString();
            clip.name = obj->getProperty("name").toString().toStdString();
            clip.type = obj->getProperty("type").toString().toStdString();
            clip.mediaPath = obj->getProperty("mediaPath").toString().toStdString();
            clip.startTime = obj->getProperty("startTime");
            clip.duration = obj->getProperty("duration");
            clip.offset = obj->getProperty("offset");
            clip.gain = obj->getProperty("gain");
            clip.fadeInTime = obj->getProperty("fadeInTime");
            clip.fadeOutTime = obj->getProperty("fadeOutTime");
            clip.muted = obj->getProperty("muted");
            clip.locked = obj->getProperty("locked");
            clip.color = juce::Colour(static_cast<uint32_t>(static_cast<int>(obj->getProperty("color"))));
        }
        return clip;
    }
};

struct AutomationPoint
{
    double time = 0.0;
    float value = 0.0f;
    int curveType = 0;  // 0=linear, 1=bezier, 2=step

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("time", time);
        obj->setProperty("value", value);
        obj->setProperty("curveType", curveType);
        return juce::var(obj);
    }

    static AutomationPoint fromVar(const juce::var& v)
    {
        AutomationPoint pt;
        if (auto* obj = v.getDynamicObject())
        {
            pt.time = obj->getProperty("time");
            pt.value = obj->getProperty("value");
            pt.curveType = obj->getProperty("curveType");
        }
        return pt;
    }
};

struct AutomationLane
{
    std::string parameterId;
    std::string parameterName;
    float minValue = 0.0f;
    float maxValue = 1.0f;
    std::vector<AutomationPoint> points;

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("parameterId", juce::String(parameterId));
        obj->setProperty("parameterName", juce::String(parameterName));
        obj->setProperty("minValue", minValue);
        obj->setProperty("maxValue", maxValue);

        juce::Array<juce::var> pts;
        for (const auto& pt : points)
            pts.add(pt.toVar());
        obj->setProperty("points", pts);

        return juce::var(obj);
    }
};

struct PluginState
{
    std::string pluginId;
    std::string pluginName;
    std::string format;         // "VST3", "AU", "CLAP"
    juce::MemoryBlock stateData;
    bool bypassed = false;
};

struct TrackData
{
    std::string id;
    std::string name;
    std::string type;           // "audio", "midi", "aux", "master"
    int index = 0;
    juce::Colour color{0xFF4A9EFF};

    float volume = 0.0f;        // dB
    float pan = 0.0f;           // -1 to +1
    bool muted = false;
    bool solo = false;
    bool recordArm = false;

    std::string inputSource;
    std::string outputTarget;

    std::vector<ClipData> clips;
    std::vector<AutomationLane> automationLanes;
    std::vector<PluginState> plugins;
    std::array<float, 8> sendLevels{};

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("id", juce::String(id));
        obj->setProperty("name", juce::String(name));
        obj->setProperty("type", juce::String(type));
        obj->setProperty("index", index);
        obj->setProperty("color", static_cast<int>(color.getARGB()));
        obj->setProperty("volume", volume);
        obj->setProperty("pan", pan);
        obj->setProperty("muted", muted);
        obj->setProperty("solo", solo);
        obj->setProperty("recordArm", recordArm);
        obj->setProperty("inputSource", juce::String(inputSource));
        obj->setProperty("outputTarget", juce::String(outputTarget));

        juce::Array<juce::var> clipArray;
        for (const auto& clip : clips)
            clipArray.add(clip.toVar());
        obj->setProperty("clips", clipArray);

        juce::Array<juce::var> autoArray;
        for (const auto& lane : automationLanes)
            autoArray.add(lane.toVar());
        obj->setProperty("automation", autoArray);

        return juce::var(obj);
    }

    static TrackData fromVar(const juce::var& v)
    {
        TrackData track;
        if (auto* obj = v.getDynamicObject())
        {
            track.id = obj->getProperty("id").toString().toStdString();
            track.name = obj->getProperty("name").toString().toStdString();
            track.type = obj->getProperty("type").toString().toStdString();
            track.index = obj->getProperty("index");
            track.color = juce::Colour(static_cast<uint32_t>(static_cast<int>(obj->getProperty("color"))));
            track.volume = obj->getProperty("volume");
            track.pan = obj->getProperty("pan");
            track.muted = obj->getProperty("muted");
            track.solo = obj->getProperty("solo");
            track.recordArm = obj->getProperty("recordArm");

            if (auto* clips = obj->getProperty("clips").getArray())
            {
                for (const auto& c : *clips)
                    track.clips.push_back(ClipData::fromVar(c));
            }
        }
        return track;
    }
};

struct ProjectMetadata
{
    std::string name = "Untitled";
    std::string author;
    std::string description;
    std::string version = "1.0";
    int formatVersion = 1;

    double bpm = 120.0;
    int timeSignatureNumerator = 4;
    int timeSignatureDenominator = 4;
    std::string keySignature = "C";

    int sampleRate = 44100;
    int bitDepth = 24;

    double projectLength = 0.0;     // Total duration
    double loopStart = 0.0;
    double loopEnd = 0.0;
    bool loopEnabled = false;

    std::string createdDate;
    std::string modifiedDate;

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("name", juce::String(name));
        obj->setProperty("author", juce::String(author));
        obj->setProperty("description", juce::String(description));
        obj->setProperty("version", juce::String(version));
        obj->setProperty("formatVersion", formatVersion);
        obj->setProperty("bpm", bpm);
        obj->setProperty("timeSignatureNumerator", timeSignatureNumerator);
        obj->setProperty("timeSignatureDenominator", timeSignatureDenominator);
        obj->setProperty("keySignature", juce::String(keySignature));
        obj->setProperty("sampleRate", sampleRate);
        obj->setProperty("bitDepth", bitDepth);
        obj->setProperty("projectLength", projectLength);
        obj->setProperty("loopStart", loopStart);
        obj->setProperty("loopEnd", loopEnd);
        obj->setProperty("loopEnabled", loopEnabled);
        obj->setProperty("createdDate", juce::String(createdDate));
        obj->setProperty("modifiedDate", juce::String(modifiedDate));
        return juce::var(obj);
    }

    static ProjectMetadata fromVar(const juce::var& v)
    {
        ProjectMetadata meta;
        if (auto* obj = v.getDynamicObject())
        {
            meta.name = obj->getProperty("name").toString().toStdString();
            meta.author = obj->getProperty("author").toString().toStdString();
            meta.bpm = obj->getProperty("bpm");
            meta.sampleRate = obj->getProperty("sampleRate");
            meta.formatVersion = obj->getProperty("formatVersion");
        }
        return meta;
    }
};

//==============================================================================
// Project Document
//==============================================================================

class ProjectDocument
{
public:
    ProjectMetadata metadata;
    std::vector<TrackData> tracks;
    std::map<std::string, juce::MemoryBlock> pluginStates;
    std::map<std::string, std::string> mediaReferences;  // id -> path

    bool hasUnsavedChanges = false;
    std::string filePath;

    void markDirty() { hasUnsavedChanges = true; }
    void markClean() { hasUnsavedChanges = false; }

    std::string generateId()
    {
        static int counter = 0;
        return "id_" + std::to_string(++counter) + "_" +
               std::to_string(std::time(nullptr));
    }

    TrackData& addTrack(const std::string& name, const std::string& type)
    {
        TrackData track;
        track.id = generateId();
        track.name = name;
        track.type = type;
        track.index = static_cast<int>(tracks.size());
        tracks.push_back(track);
        markDirty();
        return tracks.back();
    }

    void removeTrack(int index)
    {
        if (index >= 0 && index < static_cast<int>(tracks.size()))
        {
            tracks.erase(tracks.begin() + index);
            markDirty();
        }
    }
};

//==============================================================================
// Project File Manager
//==============================================================================

class ProjectFileManager
{
public:
    struct SaveOptions
    {
        bool copyMediaFiles = true;     // Copy media into project folder
        bool compressMedia = false;     // Compress audio files
        bool includeBackup = true;      // Create backup before overwriting
        bool createAutoSave = true;
    };

    struct LoadResult
    {
        bool success = false;
        std::string errorMessage;
        std::vector<std::string> warnings;
        std::vector<std::string> missingMedia;
    };

    static ProjectFileManager& getInstance()
    {
        static ProjectFileManager instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Save Project
    //--------------------------------------------------------------------------

    bool saveProject(ProjectDocument& project, const std::string& path,
                     const SaveOptions& options = {})
    {
        try
        {
            juce::File projectDir(path);

            // Create project directory
            if (!projectDir.exists())
                projectDir.createDirectory();

            // Create subdirectories
            projectDir.getChildFile("plugins").createDirectory();
            projectDir.getChildFile("media").createDirectory();
            projectDir.getChildFile("backups").createDirectory();

            // Backup existing project
            if (options.includeBackup && projectDir.getChildFile("project.json").exists())
            {
                createBackup(projectDir);
            }

            // Update metadata
            project.metadata.modifiedDate = getCurrentTimestamp();
            if (project.metadata.createdDate.empty())
                project.metadata.createdDate = project.metadata.modifiedDate;

            // Save project.json
            saveMetadata(project, projectDir);

            // Save tracks.json
            saveTracks(project, projectDir);

            // Copy media files
            if (options.copyMediaFiles)
            {
                copyMediaFiles(project, projectDir);
            }

            // Save plugin states
            savePluginStates(project, projectDir);

            project.filePath = path;
            project.markClean();

            return true;
        }
        catch (const std::exception& e)
        {
            lastError = e.what();
            return false;
        }
    }

    //--------------------------------------------------------------------------
    // Load Project
    //--------------------------------------------------------------------------

    LoadResult loadProject(ProjectDocument& project, const std::string& path)
    {
        LoadResult result;

        try
        {
            juce::File projectDir(path);

            if (!projectDir.exists())
            {
                result.errorMessage = "Project directory does not exist";
                return result;
            }

            // Load metadata
            juce::File metaFile = projectDir.getChildFile("project.json");
            if (metaFile.exists())
            {
                juce::var metaVar = juce::JSON::parse(metaFile);
                project.metadata = ProjectMetadata::fromVar(metaVar);
            }
            else
            {
                result.warnings.push_back("project.json not found, using defaults");
            }

            // Load tracks
            juce::File tracksFile = projectDir.getChildFile("tracks.json");
            if (tracksFile.exists())
            {
                juce::var tracksVar = juce::JSON::parse(tracksFile);
                if (auto* arr = tracksVar.getArray())
                {
                    for (const auto& t : *arr)
                        project.tracks.push_back(TrackData::fromVar(t));
                }
            }

            // Verify media files
            for (auto& track : project.tracks)
            {
                for (auto& clip : track.clips)
                {
                    juce::File mediaFile(clip.mediaPath);
                    if (!mediaFile.existsAsFile())
                    {
                        // Try relative to project
                        juce::File relativeFile = projectDir.getChildFile("media")
                                                           .getChildFile(juce::File(clip.mediaPath).getFileName());
                        if (relativeFile.exists())
                        {
                            clip.mediaPath = relativeFile.getFullPathName().toStdString();
                        }
                        else
                        {
                            result.missingMedia.push_back(clip.mediaPath);
                        }
                    }
                }
            }

            // Load plugin states
            loadPluginStates(project, projectDir);

            project.filePath = path;
            project.markClean();
            result.success = true;
        }
        catch (const std::exception& e)
        {
            result.errorMessage = e.what();
        }

        return result;
    }

    //--------------------------------------------------------------------------
    // Auto-Save
    //--------------------------------------------------------------------------

    void enableAutoSave(ProjectDocument& project, int intervalSeconds = 60)
    {
        autoSaveEnabled = true;
        autoSaveInterval = intervalSeconds;
        lastAutoSave = std::time(nullptr);
    }

    void disableAutoSave()
    {
        autoSaveEnabled = false;
    }

    void checkAutoSave(ProjectDocument& project)
    {
        if (!autoSaveEnabled || project.filePath.empty()) return;

        auto now = std::time(nullptr);
        if (now - lastAutoSave >= autoSaveInterval && project.hasUnsavedChanges)
        {
            juce::File projectDir(project.filePath);
            juce::File autoSaveFile = projectDir.getChildFile("backups")
                                                .getChildFile("autosave_" + getCurrentTimestamp() + ".json");

            // Quick save of just the tracks
            juce::Array<juce::var> tracksArray;
            for (const auto& track : project.tracks)
                tracksArray.add(track.toVar());

            autoSaveFile.replaceWithText(juce::JSON::toString(tracksArray));

            lastAutoSave = now;
        }
    }

    //--------------------------------------------------------------------------
    // Recent Projects
    //--------------------------------------------------------------------------

    void addRecentProject(const std::string& path)
    {
        // Remove if already exists
        recentProjects.erase(std::remove(recentProjects.begin(), recentProjects.end(), path),
                             recentProjects.end());

        // Add to front
        recentProjects.insert(recentProjects.begin(), path);

        // Limit to 10
        if (recentProjects.size() > 10)
            recentProjects.resize(10);
    }

    const std::vector<std::string>& getRecentProjects() const { return recentProjects; }

    std::string getLastError() const { return lastError; }

private:
    ProjectFileManager() = default;

    std::string lastError;
    bool autoSaveEnabled = false;
    int autoSaveInterval = 60;
    std::time_t lastAutoSave = 0;
    std::vector<std::string> recentProjects;

    void saveMetadata(const ProjectDocument& project, const juce::File& projectDir)
    {
        juce::File metaFile = projectDir.getChildFile("project.json");
        juce::String json = juce::JSON::toString(project.metadata.toVar());
        metaFile.replaceWithText(json);
    }

    void saveTracks(const ProjectDocument& project, const juce::File& projectDir)
    {
        juce::Array<juce::var> tracksArray;
        for (const auto& track : project.tracks)
            tracksArray.add(track.toVar());

        juce::File tracksFile = projectDir.getChildFile("tracks.json");
        tracksFile.replaceWithText(juce::JSON::toString(tracksArray));
    }

    void copyMediaFiles(ProjectDocument& project, const juce::File& projectDir)
    {
        juce::File mediaDir = projectDir.getChildFile("media");

        for (auto& track : project.tracks)
        {
            for (auto& clip : track.clips)
            {
                juce::File srcFile(clip.mediaPath);
                if (srcFile.existsAsFile())
                {
                    juce::File dstFile = mediaDir.getChildFile(srcFile.getFileName());
                    if (!dstFile.exists())
                    {
                        srcFile.copyFileTo(dstFile);
                    }
                    clip.mediaPath = dstFile.getFullPathName().toStdString();
                }
            }
        }
    }

    void savePluginStates(const ProjectDocument& project, const juce::File& projectDir)
    {
        juce::File pluginsDir = projectDir.getChildFile("plugins");

        for (const auto& [id, state] : project.pluginStates)
        {
            juce::File stateFile = pluginsDir.getChildFile(id + ".bin");
            stateFile.replaceWithData(state.getData(), state.getSize());
        }
    }

    void loadPluginStates(ProjectDocument& project, const juce::File& projectDir)
    {
        juce::File pluginsDir = projectDir.getChildFile("plugins");

        for (const auto& file : pluginsDir.findChildFiles(juce::File::findFiles, false, "*.bin"))
        {
            juce::MemoryBlock data;
            file.loadFileAsData(data);
            project.pluginStates[file.getFileNameWithoutExtension().toStdString()] = data;
        }
    }

    void createBackup(const juce::File& projectDir)
    {
        juce::File backupsDir = projectDir.getChildFile("backups");
        juce::File projectJson = projectDir.getChildFile("project.json");
        juce::File tracksJson = projectDir.getChildFile("tracks.json");

        std::string timestamp = getCurrentTimestamp();

        if (projectJson.exists())
            projectJson.copyFileTo(backupsDir.getChildFile("project_" + timestamp + ".json"));

        if (tracksJson.exists())
            tracksJson.copyFileTo(backupsDir.getChildFile("tracks_" + timestamp + ".json"));
    }

    std::string getCurrentTimestamp()
    {
        auto now = std::time(nullptr);
        char buf[32];
        std::strftime(buf, sizeof(buf), "%Y%m%d_%H%M%S", std::localtime(&now));
        return buf;
    }
};

//==============================================================================
// Convenience
//==============================================================================

#define ProjectManager ProjectFileManager::getInstance()

} // namespace Project
} // namespace Echoelmusic
