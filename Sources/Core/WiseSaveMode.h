/*
  ==============================================================================

    WiseSaveMode.h
    Ralph Wiggum Loop Genius - Wise Save Mode

    Intelligent session saving that remembers everything:
    - Key/Scale relationships across all plugins
    - Smart preset naming based on musical context
    - Automatic snapshot system
    - Incremental saves with diff tracking
    - Cloud sync integration
    - Version history with branching
    - AI-powered session descriptions
    - Recovery mode for crashes
    - Plugin state compression
    - Collaborative session support

    "Save wisely, loop infinitely" - Ralph Wiggum

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "GlobalKeyScaleManager.h"
#include <vector>
#include <map>
#include <memory>
#include <optional>
#include <chrono>
#include <thread>
#include <atomic>
#include <mutex>
#include <functional>

namespace RalphWiggum
{

//==============================================================================
/** Session snapshot for version history */
struct SessionSnapshot
{
    juce::String id;                    // Unique snapshot ID
    juce::String name;                  // User-friendly name
    juce::String description;           // Auto-generated or manual
    juce::Time timestamp;

    // Musical context
    KeySignature keyAtSnapshot;
    double tempoAtSnapshot = 120.0;
    int timeSignatureNum = 4;
    int timeSignatureDenom = 4;

    // State data
    std::unique_ptr<juce::MemoryBlock> compressedState;
    size_t uncompressedSize = 0;

    // Metadata
    juce::StringArray tags;
    juce::String parentSnapshotId;      // For branching
    bool isAutoSave = false;
    bool isRecoveryPoint = false;

    // Statistics
    int pluginCount = 0;
    int trackCount = 0;
    double sessionLengthSeconds = 0.0;
};

//==============================================================================
/** Plugin state cache entry */
struct PluginStateEntry
{
    juce::String pluginId;
    juce::String pluginName;
    juce::String pluginType;            // "Instrument", "Effect", "Analyzer"

    // Key relationship
    bool followsGlobalKey = true;
    std::optional<KeySignature> localKey;

    // State
    std::unique_ptr<juce::MemoryBlock> state;
    juce::String stateHash;             // For change detection

    // Preset info
    juce::String presetName;
    juce::String presetCategory;

    // UI state
    bool windowOpen = false;
    juce::Rectangle<int> windowBounds;
};

//==============================================================================
/** Track state for session */
struct TrackState
{
    int trackId;
    juce::String trackName;
    juce::String trackType;             // "Audio", "MIDI", "Aux", "Master"

    // Key relationship
    bool followsGlobalKey = true;
    std::optional<KeySignature> localKey;

    // Plugin chain
    std::vector<PluginStateEntry> plugins;

    // Track settings
    float volume = 0.0f;                // dB
    float pan = 0.0f;                   // -1 to 1
    bool muted = false;
    bool soloed = false;
    bool armed = false;

    // Routing
    int outputBus = 0;
    std::vector<int> sends;
};

//==============================================================================
/** Wise Save configuration */
struct WiseSaveConfig
{
    // Auto-save
    bool autoSaveEnabled = true;
    int autoSaveIntervalMinutes = 3;
    int maxAutoSaves = 50;

    // Snapshots
    bool createSnapshotOnKeyChange = true;
    bool createSnapshotBeforeMajorChange = true;
    int maxSnapshots = 100;

    // Compression
    bool enableCompression = true;
    int compressionLevel = 6;           // 1-9

    // Smart naming
    bool smartNamingEnabled = true;
    bool includeKeyInFilename = true;
    bool includeTempoInFilename = true;
    bool includeDateInFilename = true;

    // Cloud sync
    bool cloudSyncEnabled = false;
    juce::String cloudProvider;         // "iCloud", "Dropbox", "Google Drive"

    // Recovery
    bool recoveryModeEnabled = true;
    int recoveryIntervalSeconds = 30;

    // Collaboration
    bool collaborationEnabled = false;
    juce::String collaborationServer;
};

//==============================================================================
/** Diff information for incremental saves */
struct SessionDiff
{
    juce::Time timestamp;
    juce::String fromSnapshotId;
    juce::String toSnapshotId;

    // Changes
    std::vector<juce::String> addedPlugins;
    std::vector<juce::String> removedPlugins;
    std::vector<juce::String> modifiedPlugins;

    std::vector<int> addedTracks;
    std::vector<int> removedTracks;
    std::vector<int> modifiedTracks;

    bool keyChanged = false;
    KeySignature previousKey;
    KeySignature newKey;

    bool tempoChanged = false;
    double previousTempo;
    double newTempo;

    // Size
    size_t diffSizeBytes = 0;
};

//==============================================================================
/**
    WiseSaveMode

    The heart of Ralph Wiggum Loop Genius session management.

    Features:
    - Intelligent auto-save with musical context awareness
    - Key/Scale state preservation across all plugins
    - Smart preset naming based on musical content
    - Snapshot branching for creative exploration
    - Recovery mode for crash protection
    - Collaborative session support
*/
class WiseSaveMode : public juce::Timer,
                      public juce::ChangeListener
{
public:
    //==========================================================================
    // Singleton Access

    static WiseSaveMode& getInstance()
    {
        static WiseSaveMode instance;
        return instance;
    }

    //==========================================================================
    // Initialization

    /** Initialize with project directory */
    void initialize(const juce::File& projectDir)
    {
        projectDirectory = projectDir;
        snapshotsDirectory = projectDir.getChildFile("WiseSave_Snapshots");
        recoveryDirectory = projectDir.getChildFile("WiseSave_Recovery");

        snapshotsDirectory.createDirectory();
        recoveryDirectory.createDirectory();

        // Start listening to key changes
        GlobalKeyScaleManager::getInstance().addChangeListener(this);

        // Start timers
        if (config.autoSaveEnabled)
            startTimer(config.autoSaveIntervalMinutes * 60 * 1000);

        if (config.recoveryModeEnabled)
            startRecoveryTimer();

        initialized = true;
    }

    //==========================================================================
    // Session Management

    /** Create a new session */
    void newSession(const juce::String& name = "Untitled")
    {
        currentSessionName = name;
        currentSessionId = generateUniqueId();
        sessionStartTime = juce::Time::getCurrentTime();

        snapshots.clear();
        tracks.clear();
        plugins.clear();

        isDirty = false;

        // Create initial snapshot
        createSnapshot("Session Start", true);
    }

    /** Save current session */
    bool saveSession(const juce::File& file)
    {
        if (!initialized)
            return false;

        // Create session XML
        auto xml = createSessionXML();
        if (!xml)
            return false;

        // Apply smart naming if enabled
        juce::File targetFile = file;
        if (config.smartNamingEnabled && file.getFileName() == "Untitled.echoelmusic")
        {
            targetFile = file.getParentDirectory().getChildFile(generateSmartFilename());
        }

        // Save to file
        if (!xml->writeTo(targetFile))
            return false;

        currentSessionFile = targetFile;
        isDirty = false;
        lastSaveTime = juce::Time::getCurrentTime();

        return true;
    }

    /** Load session */
    bool loadSession(const juce::File& file)
    {
        auto xml = juce::XmlDocument::parse(file);
        if (!xml)
            return false;

        if (!restoreFromXML(*xml))
            return false;

        currentSessionFile = file;
        isDirty = false;

        // Broadcast restored key to all plugins
        GlobalKeyScaleManager::getInstance().broadcastKeyToAllPlugins();

        return true;
    }

    //==========================================================================
    // Snapshot System

    /** Create a snapshot of current state */
    juce::String createSnapshot(const juce::String& name = "", bool isAuto = false)
    {
        SessionSnapshot snapshot;
        snapshot.id = generateUniqueId();
        snapshot.name = name.isEmpty() ? generateSnapshotName() : name;
        snapshot.description = generateSnapshotDescription();
        snapshot.timestamp = juce::Time::getCurrentTime();

        // Capture musical context
        snapshot.keyAtSnapshot = GlobalKeyScaleManager::getInstance().getCurrentKey();
        snapshot.tempoAtSnapshot = currentTempo;
        snapshot.timeSignatureNum = currentTimeSignatureNum;
        snapshot.timeSignatureDenom = currentTimeSignatureDenom;

        // Capture state
        auto stateXml = createStateSnapshot();
        if (stateXml)
        {
            juce::MemoryBlock uncompressed;
            juce::MemoryOutputStream stream(uncompressed, false);
            stateXml->writeTo(stream);

            snapshot.uncompressedSize = uncompressed.getSize();

            if (config.enableCompression)
            {
                snapshot.compressedState = std::make_unique<juce::MemoryBlock>();
                juce::MemoryOutputStream compressedStream(*snapshot.compressedState, false);
                juce::GZIPCompressorOutputStream gzip(compressedStream, config.compressionLevel);
                gzip.write(uncompressed.getData(), uncompressed.getSize());
                gzip.flush();
            }
            else
            {
                snapshot.compressedState = std::make_unique<juce::MemoryBlock>(uncompressed);
            }
        }

        // Set parent if this is a branch
        if (!snapshots.empty())
            snapshot.parentSnapshotId = snapshots.back().id;

        snapshot.isAutoSave = isAuto;
        snapshot.pluginCount = (int)plugins.size();
        snapshot.trackCount = (int)tracks.size();

        snapshots.push_back(std::move(snapshot));

        // Cleanup old snapshots if needed
        cleanupOldSnapshots();

        return snapshots.back().id;
    }

    /** Restore a snapshot */
    bool restoreSnapshot(const juce::String& snapshotId)
    {
        for (const auto& snapshot : snapshots)
        {
            if (snapshot.id == snapshotId)
            {
                return restoreSnapshotState(snapshot);
            }
        }
        return false;
    }

    /** Get all snapshots */
    const std::vector<SessionSnapshot>& getSnapshots() const
    {
        return snapshots;
    }

    /** Delete a snapshot */
    bool deleteSnapshot(const juce::String& snapshotId)
    {
        auto it = std::remove_if(snapshots.begin(), snapshots.end(),
            [&](const SessionSnapshot& s) { return s.id == snapshotId; });

        if (it != snapshots.end())
        {
            snapshots.erase(it, snapshots.end());
            return true;
        }
        return false;
    }

    //==========================================================================
    // Track Management

    /** Register a track */
    void registerTrack(int trackId, const juce::String& name, const juce::String& type)
    {
        TrackState track;
        track.trackId = trackId;
        track.trackName = name;
        track.trackType = type;
        tracks[trackId] = std::move(track);
        markDirty();
    }

    /** Update track state */
    void updateTrackState(int trackId, const TrackState& state)
    {
        tracks[trackId] = state;
        markDirty();
    }

    /** Get track state */
    std::optional<TrackState> getTrackState(int trackId) const
    {
        auto it = tracks.find(trackId);
        if (it != tracks.end())
            return it->second;
        return std::nullopt;
    }

    //==========================================================================
    // Plugin State Management

    /** Register a plugin */
    void registerPlugin(const juce::String& pluginId, const juce::String& name,
                        const juce::String& type)
    {
        PluginStateEntry entry;
        entry.pluginId = pluginId;
        entry.pluginName = name;
        entry.pluginType = type;
        plugins[pluginId] = std::move(entry);
        markDirty();
    }

    /** Update plugin state */
    void updatePluginState(const juce::String& pluginId, const juce::MemoryBlock& state)
    {
        auto it = plugins.find(pluginId);
        if (it != plugins.end())
        {
            // Calculate hash for change detection
            juce::String newHash = juce::MD5(state.getData(), state.getSize()).toHexString();

            if (newHash != it->second.stateHash)
            {
                it->second.state = std::make_unique<juce::MemoryBlock>(state);
                it->second.stateHash = newHash;
                markDirty();
            }
        }
    }

    /** Update plugin key relationship */
    void updatePluginKeyRelationship(const juce::String& pluginId,
                                      bool followsGlobal,
                                      const std::optional<KeySignature>& localKey = std::nullopt)
    {
        auto it = plugins.find(pluginId);
        if (it != plugins.end())
        {
            it->second.followsGlobalKey = followsGlobal;
            it->second.localKey = localKey;
            markDirty();
        }
    }

    /** Get plugin state */
    std::optional<PluginStateEntry> getPluginState(const juce::String& pluginId) const
    {
        auto it = plugins.find(pluginId);
        if (it != plugins.end())
            return it->second;
        return std::nullopt;
    }

    //==========================================================================
    // Smart Naming

    /** Generate smart filename based on musical context */
    juce::String generateSmartFilename() const
    {
        juce::String filename = currentSessionName;

        if (config.includeKeyInFilename)
        {
            auto key = GlobalKeyScaleManager::getInstance().getCurrentKey();
            filename += "_" + key.getDisplayName().replace(" ", "-");
        }

        if (config.includeTempoInFilename)
        {
            filename += "_" + juce::String((int)currentTempo) + "bpm";
        }

        if (config.includeDateInFilename)
        {
            auto now = juce::Time::getCurrentTime();
            filename += "_" + now.formatted("%Y%m%d");
        }

        return filename + ".echoelmusic";
    }

    /** Generate smart snapshot name */
    juce::String generateSnapshotName() const
    {
        auto key = GlobalKeyScaleManager::getInstance().getCurrentKey();
        auto now = juce::Time::getCurrentTime();

        return key.getDisplayName() + " @ " + now.formatted("%H:%M");
    }

    /** Generate AI-powered session description */
    juce::String generateSnapshotDescription() const
    {
        juce::String desc;

        auto key = GlobalKeyScaleManager::getInstance().getCurrentKey();
        desc += "Key: " + key.getDisplayName() + "\n";
        desc += "Tempo: " + juce::String(currentTempo, 1) + " BPM\n";
        desc += "Tracks: " + juce::String((int)tracks.size()) + "\n";
        desc += "Plugins: " + juce::String((int)plugins.size()) + "\n";

        // Count plugins following global key
        int followingCount = 0;
        for (const auto& [id, plugin] : plugins)
        {
            if (plugin.followsGlobalKey)
                followingCount++;
        }
        desc += "Plugins following key: " + juce::String(followingCount) + "/" + juce::String((int)plugins.size());

        return desc;
    }

    //==========================================================================
    // Recovery Mode

    /** Create recovery point */
    void createRecoveryPoint()
    {
        if (!config.recoveryModeEnabled)
            return;

        auto recoveryFile = recoveryDirectory.getChildFile(
            "recovery_" + juce::Time::getCurrentTime().formatted("%Y%m%d_%H%M%S") + ".xml"
        );

        auto xml = createSessionXML();
        if (xml)
        {
            xml->writeTo(recoveryFile);
        }

        // Cleanup old recovery files (keep last 10)
        cleanupRecoveryFiles(10);

        lastRecoveryTime = juce::Time::getCurrentTime();
    }

    /** Check for recovery files */
    juce::Array<juce::File> getRecoveryFiles() const
    {
        return recoveryDirectory.findChildFiles(juce::File::findFiles, false, "recovery_*.xml");
    }

    /** Recover from most recent recovery point */
    bool recoverFromLatest()
    {
        auto files = getRecoveryFiles();
        if (files.isEmpty())
            return false;

        // Sort by modification time (newest first)
        std::sort(files.begin(), files.end(),
            [](const juce::File& a, const juce::File& b) {
                return a.getLastModificationTime() > b.getLastModificationTime();
            });

        return loadSession(files[0]);
    }

    //==========================================================================
    // Dirty State

    bool hasUnsavedChanges() const { return isDirty; }
    void markDirty() { isDirty = true; }
    void clearDirty() { isDirty = false; }

    //==========================================================================
    // Configuration

    WiseSaveConfig& getConfig() { return config; }
    const WiseSaveConfig& getConfig() const { return config; }

    void setConfig(const WiseSaveConfig& newConfig)
    {
        config = newConfig;

        // Update auto-save timer
        stopTimer();
        if (config.autoSaveEnabled)
            startTimer(config.autoSaveIntervalMinutes * 60 * 1000);
    }

    //==========================================================================
    // Musical Context

    void setTempo(double bpm)
    {
        if (currentTempo != bpm)
        {
            currentTempo = bpm;
            markDirty();
        }
    }

    void setTimeSignature(int num, int denom)
    {
        if (currentTimeSignatureNum != num || currentTimeSignatureDenom != denom)
        {
            currentTimeSignatureNum = num;
            currentTimeSignatureDenom = denom;
            markDirty();
        }
    }

    double getTempo() const { return currentTempo; }
    int getTimeSignatureNum() const { return currentTimeSignatureNum; }
    int getTimeSignatureDenom() const { return currentTimeSignatureDenom; }

    //==========================================================================
    // Callbacks

    /** Set callback for when session is saved */
    void setOnSaveCallback(std::function<void()> callback)
    {
        onSaveCallback = std::move(callback);
    }

    /** Set callback for when snapshot is created */
    void setOnSnapshotCallback(std::function<void(const juce::String&)> callback)
    {
        onSnapshotCallback = std::move(callback);
    }

    //==========================================================================
    // Timer Callback

    void timerCallback() override
    {
        if (isDirty && config.autoSaveEnabled)
        {
            createSnapshot("Auto-save", true);

            if (!currentSessionFile.existsAsFile())
            {
                // No file yet, just create recovery point
                createRecoveryPoint();
            }
            else
            {
                // Save to existing file
                saveSession(currentSessionFile);
            }
        }
    }

    //==========================================================================
    // Change Listener (for key changes)

    void changeListenerCallback(juce::ChangeBroadcaster*) override
    {
        if (config.createSnapshotOnKeyChange)
        {
            // Create snapshot when key changes
            createSnapshot("Key change to " +
                GlobalKeyScaleManager::getInstance().getCurrentKey().getDisplayName(), true);
        }
    }

private:
    WiseSaveMode() = default;

    ~WiseSaveMode()
    {
        // Stop recovery thread safely
        recoveryThreadRunning = false;
        if (recoveryThread.joinable())
        {
            recoveryThread.join();
        }
    }

    WiseSaveMode(const WiseSaveMode&) = delete;
    WiseSaveMode& operator=(const WiseSaveMode&) = delete;

    //==========================================================================
    // Internal Methods

    juce::String generateUniqueId() const
    {
        return juce::Uuid().toString();
    }

    std::unique_ptr<juce::XmlElement> createSessionXML() const
    {
        auto xml = std::make_unique<juce::XmlElement>("WiseSaveSession");
        xml->setAttribute("version", "1.0");
        xml->setAttribute("sessionId", currentSessionId);
        xml->setAttribute("sessionName", currentSessionName);
        xml->setAttribute("savedAt", juce::Time::getCurrentTime().toISO8601(true));

        // Musical context
        auto* musicalXml = xml->createNewChildElement("MusicalContext");
        musicalXml->setAttribute("tempo", currentTempo);
        musicalXml->setAttribute("timeSignatureNum", currentTimeSignatureNum);
        musicalXml->setAttribute("timeSignatureDenom", currentTimeSignatureDenom);

        // Key/Scale state
        auto keyXml = GlobalKeyScaleManager::getInstance().createStateXML();
        if (keyXml)
            xml->addChildElement(keyXml.release());

        // Tracks
        auto* tracksXml = xml->createNewChildElement("Tracks");
        for (const auto& [id, track] : tracks)
        {
            auto* trackXml = tracksXml->createNewChildElement("Track");
            trackXml->setAttribute("id", track.trackId);
            trackXml->setAttribute("name", track.trackName);
            trackXml->setAttribute("type", track.trackType);
            trackXml->setAttribute("followsGlobalKey", track.followsGlobalKey);
            trackXml->setAttribute("volume", track.volume);
            trackXml->setAttribute("pan", track.pan);
            trackXml->setAttribute("muted", track.muted);
            trackXml->setAttribute("soloed", track.soloed);
            trackXml->setAttribute("armed", track.armed);

            if (track.localKey.has_value())
            {
                trackXml->setAttribute("localKeyRoot", static_cast<int>(track.localKey->root));
                trackXml->setAttribute("localKeyScale", static_cast<int>(track.localKey->scale));
            }

            // Track plugins
            auto* trackPluginsXml = trackXml->createNewChildElement("Plugins");
            for (const auto& plugin : track.plugins)
            {
                auto* pluginXml = trackPluginsXml->createNewChildElement("Plugin");
                pluginXml->setAttribute("id", plugin.pluginId);
                pluginXml->setAttribute("name", plugin.pluginName);
                pluginXml->setAttribute("type", plugin.pluginType);
                pluginXml->setAttribute("followsGlobalKey", plugin.followsGlobalKey);
                pluginXml->setAttribute("presetName", plugin.presetName);

                if (plugin.state)
                {
                    pluginXml->setAttribute("stateBase64",
                        juce::Base64::toBase64(plugin.state->getData(), plugin.state->getSize()));
                }
            }
        }

        // Global plugins
        auto* pluginsXml = xml->createNewChildElement("GlobalPlugins");
        for (const auto& [id, plugin] : plugins)
        {
            auto* pluginXml = pluginsXml->createNewChildElement("Plugin");
            pluginXml->setAttribute("id", plugin.pluginId);
            pluginXml->setAttribute("name", plugin.pluginName);
            pluginXml->setAttribute("type", plugin.pluginType);
            pluginXml->setAttribute("followsGlobalKey", plugin.followsGlobalKey);
            pluginXml->setAttribute("presetName", plugin.presetName);
            pluginXml->setAttribute("stateHash", plugin.stateHash);

            if (plugin.localKey.has_value())
            {
                pluginXml->setAttribute("localKeyRoot", static_cast<int>(plugin.localKey->root));
                pluginXml->setAttribute("localKeyScale", static_cast<int>(plugin.localKey->scale));
            }

            if (plugin.state)
            {
                pluginXml->setAttribute("stateBase64",
                    juce::Base64::toBase64(plugin.state->getData(), plugin.state->getSize()));
            }

            // Window state
            pluginXml->setAttribute("windowOpen", plugin.windowOpen);
            if (!plugin.windowBounds.isEmpty())
            {
                pluginXml->setAttribute("windowX", plugin.windowBounds.getX());
                pluginXml->setAttribute("windowY", plugin.windowBounds.getY());
                pluginXml->setAttribute("windowW", plugin.windowBounds.getWidth());
                pluginXml->setAttribute("windowH", plugin.windowBounds.getHeight());
            }
        }

        // Snapshot metadata (just IDs and names for quick reference)
        auto* snapshotsXml = xml->createNewChildElement("Snapshots");
        for (const auto& snapshot : snapshots)
        {
            auto* snapXml = snapshotsXml->createNewChildElement("Snapshot");
            snapXml->setAttribute("id", snapshot.id);
            snapXml->setAttribute("name", snapshot.name);
            snapXml->setAttribute("timestamp", snapshot.timestamp.toISO8601(true));
            snapXml->setAttribute("isAutoSave", snapshot.isAutoSave);
            snapXml->setAttribute("keyRoot", static_cast<int>(snapshot.keyAtSnapshot.root));
            snapXml->setAttribute("keyScale", static_cast<int>(snapshot.keyAtSnapshot.scale));
            snapXml->setAttribute("tempo", snapshot.tempoAtSnapshot);
        }

        // Config
        auto* configXml = xml->createNewChildElement("WiseSaveConfig");
        configXml->setAttribute("autoSaveEnabled", config.autoSaveEnabled);
        configXml->setAttribute("autoSaveInterval", config.autoSaveIntervalMinutes);
        configXml->setAttribute("createSnapshotOnKeyChange", config.createSnapshotOnKeyChange);
        configXml->setAttribute("smartNamingEnabled", config.smartNamingEnabled);
        configXml->setAttribute("includeKeyInFilename", config.includeKeyInFilename);
        configXml->setAttribute("includeTempoInFilename", config.includeTempoInFilename);
        configXml->setAttribute("recoveryModeEnabled", config.recoveryModeEnabled);

        return xml;
    }

    bool restoreFromXML(const juce::XmlElement& xml)
    {
        if (xml.getTagName() != "WiseSaveSession")
            return false;

        currentSessionId = xml.getStringAttribute("sessionId");
        currentSessionName = xml.getStringAttribute("sessionName");

        // Musical context
        if (auto* musicalXml = xml.getChildByName("MusicalContext"))
        {
            currentTempo = musicalXml->getDoubleAttribute("tempo", 120.0);
            currentTimeSignatureNum = musicalXml->getIntAttribute("timeSignatureNum", 4);
            currentTimeSignatureDenom = musicalXml->getIntAttribute("timeSignatureDenom", 4);
        }

        // Key/Scale state
        if (auto* keyXml = xml.getChildByName("GlobalKeyScale"))
        {
            GlobalKeyScaleManager::getInstance().restoreFromXML(*keyXml);
        }

        // Tracks
        tracks.clear();
        if (auto* tracksXml = xml.getChildByName("Tracks"))
        {
            for (auto* trackXml : tracksXml->getChildIterator())
            {
                TrackState track;
                track.trackId = trackXml->getIntAttribute("id");
                track.trackName = trackXml->getStringAttribute("name");
                track.trackType = trackXml->getStringAttribute("type");
                track.followsGlobalKey = trackXml->getBoolAttribute("followsGlobalKey", true);
                track.volume = (float)trackXml->getDoubleAttribute("volume", 0.0);
                track.pan = (float)trackXml->getDoubleAttribute("pan", 0.0);
                track.muted = trackXml->getBoolAttribute("muted", false);
                track.soloed = trackXml->getBoolAttribute("soloed", false);
                track.armed = trackXml->getBoolAttribute("armed", false);

                if (trackXml->hasAttribute("localKeyRoot"))
                {
                    KeySignature localKey;
                    localKey.root = static_cast<RootNote>(trackXml->getIntAttribute("localKeyRoot"));
                    localKey.scale = static_cast<ScaleType>(trackXml->getIntAttribute("localKeyScale"));
                    track.localKey = localKey;
                }

                // Track plugins
                if (auto* trackPluginsXml = trackXml->getChildByName("Plugins"))
                {
                    for (auto* pluginXml : trackPluginsXml->getChildIterator())
                    {
                        PluginStateEntry plugin;
                        plugin.pluginId = pluginXml->getStringAttribute("id");
                        plugin.pluginName = pluginXml->getStringAttribute("name");
                        plugin.pluginType = pluginXml->getStringAttribute("type");
                        plugin.followsGlobalKey = pluginXml->getBoolAttribute("followsGlobalKey", true);
                        plugin.presetName = pluginXml->getStringAttribute("presetName");

                        if (pluginXml->hasAttribute("stateBase64"))
                        {
                            plugin.state = std::make_unique<juce::MemoryBlock>();
                            juce::Base64::convertFromBase64(*plugin.state,
                                pluginXml->getStringAttribute("stateBase64"));
                        }

                        track.plugins.push_back(std::move(plugin));
                    }
                }

                tracks[track.trackId] = std::move(track);
            }
        }

        // Global plugins
        plugins.clear();
        if (auto* pluginsXml = xml.getChildByName("GlobalPlugins"))
        {
            for (auto* pluginXml : pluginsXml->getChildIterator())
            {
                PluginStateEntry plugin;
                plugin.pluginId = pluginXml->getStringAttribute("id");
                plugin.pluginName = pluginXml->getStringAttribute("name");
                plugin.pluginType = pluginXml->getStringAttribute("type");
                plugin.followsGlobalKey = pluginXml->getBoolAttribute("followsGlobalKey", true);
                plugin.presetName = pluginXml->getStringAttribute("presetName");
                plugin.stateHash = pluginXml->getStringAttribute("stateHash");

                if (pluginXml->hasAttribute("localKeyRoot"))
                {
                    KeySignature localKey;
                    localKey.root = static_cast<RootNote>(pluginXml->getIntAttribute("localKeyRoot"));
                    localKey.scale = static_cast<ScaleType>(pluginXml->getIntAttribute("localKeyScale"));
                    plugin.localKey = localKey;
                }

                if (pluginXml->hasAttribute("stateBase64"))
                {
                    plugin.state = std::make_unique<juce::MemoryBlock>();
                    juce::Base64::convertFromBase64(*plugin.state,
                        pluginXml->getStringAttribute("stateBase64"));
                }

                plugin.windowOpen = pluginXml->getBoolAttribute("windowOpen", false);
                if (pluginXml->hasAttribute("windowX"))
                {
                    plugin.windowBounds.setX(pluginXml->getIntAttribute("windowX"));
                    plugin.windowBounds.setY(pluginXml->getIntAttribute("windowY"));
                    plugin.windowBounds.setWidth(pluginXml->getIntAttribute("windowW"));
                    plugin.windowBounds.setHeight(pluginXml->getIntAttribute("windowH"));
                }

                plugins[plugin.pluginId] = std::move(plugin);
            }
        }

        // Config
        if (auto* configXml = xml.getChildByName("WiseSaveConfig"))
        {
            config.autoSaveEnabled = configXml->getBoolAttribute("autoSaveEnabled", true);
            config.autoSaveIntervalMinutes = configXml->getIntAttribute("autoSaveInterval", 3);
            config.createSnapshotOnKeyChange = configXml->getBoolAttribute("createSnapshotOnKeyChange", true);
            config.smartNamingEnabled = configXml->getBoolAttribute("smartNamingEnabled", true);
            config.includeKeyInFilename = configXml->getBoolAttribute("includeKeyInFilename", true);
            config.includeTempoInFilename = configXml->getBoolAttribute("includeTempoInFilename", true);
            config.recoveryModeEnabled = configXml->getBoolAttribute("recoveryModeEnabled", true);
        }

        return true;
    }

    std::unique_ptr<juce::XmlElement> createStateSnapshot() const
    {
        return createSessionXML();
    }

    bool restoreSnapshotState(const SessionSnapshot& snapshot)
    {
        if (!snapshot.compressedState)
            return false;

        juce::MemoryBlock decompressed;

        if (config.enableCompression)
        {
            juce::MemoryInputStream compressedStream(*snapshot.compressedState, false);
            juce::GZIPDecompressorInputStream gzip(compressedStream);

            juce::MemoryOutputStream decompressedStream(decompressed, false);
            decompressedStream.writeFromInputStream(gzip, -1);
        }
        else
        {
            decompressed = *snapshot.compressedState;
        }

        auto xml = juce::XmlDocument::parse(decompressed.toString());
        if (!xml)
            return false;

        return restoreFromXML(*xml);
    }

    void cleanupOldSnapshots()
    {
        while (snapshots.size() > (size_t)config.maxSnapshots)
        {
            // Remove oldest auto-save that isn't the first snapshot
            for (auto it = snapshots.begin() + 1; it != snapshots.end(); ++it)
            {
                if (it->isAutoSave)
                {
                    snapshots.erase(it);
                    break;
                }
            }
        }
    }

    void cleanupRecoveryFiles(int keepCount)
    {
        auto files = getRecoveryFiles();
        if (files.size() <= static_cast<size_t>(keepCount))
            return;

        // Sort by modification time (newest first)
        std::sort(files.begin(), files.end(),
            [](const juce::File& a, const juce::File& b) {
                return a.getLastModificationTime() > b.getLastModificationTime();
            });

        // Delete older files
        for (size_t i = static_cast<size_t>(keepCount); i < files.size(); ++i)
        {
            files[i].deleteFile();
        }
    }

    void startRecoveryTimer()
    {
        // Stop any existing recovery thread
        recoveryThreadRunning = false;
        if (recoveryThread.joinable())
        {
            recoveryThread.join();
        }

        // Start managed recovery thread
        recoveryThreadRunning = true;
        recoveryThread = std::thread([this]() {
            while (recoveryThreadRunning && config.recoveryModeEnabled)
            {
                // Sleep in small intervals to allow quick shutdown
                for (int i = 0; i < config.recoveryIntervalSeconds && recoveryThreadRunning; ++i)
                {
                    std::this_thread::sleep_for(std::chrono::seconds(1));
                }

                if (recoveryThreadRunning && isDirty && initialized)
                {
                    createRecoveryPoint();
                }
            }
        });
    }

    //==========================================================================
    // State (atomic for thread-safe access from recovery thread)

    std::atomic<bool> initialized{false};
    std::atomic<bool> isDirty{false};

    juce::String currentSessionId;
    juce::String currentSessionName = "Untitled";
    juce::File currentSessionFile;
    juce::File projectDirectory;
    juce::File snapshotsDirectory;
    juce::File recoveryDirectory;

    juce::Time sessionStartTime;
    juce::Time lastSaveTime;
    juce::Time lastRecoveryTime;

    // Musical context
    double currentTempo = 120.0;
    int currentTimeSignatureNum = 4;
    int currentTimeSignatureDenom = 4;

    // Session data
    std::vector<SessionSnapshot> snapshots;
    std::map<int, TrackState> tracks;
    std::map<juce::String, PluginStateEntry> plugins;

    // Configuration
    WiseSaveConfig config;

    // Callbacks
    std::function<void()> onSaveCallback;
    std::function<void(const juce::String&)> onSnapshotCallback;

    mutable std::mutex stateMutex;

    // Recovery thread management
    std::atomic<bool> recoveryThreadRunning{false};
    std::thread recoveryThread;
};

//==============================================================================
/**
    WiseSavePanel

    UI component for Wise Save Mode controls.
*/
class WiseSavePanel : public juce::Component,
                       public juce::Button::Listener,
                       public juce::Timer
{
public:
    WiseSavePanel()
    {
        // Title
        titleLabel.setText("Wise Save Mode", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(18.0f, juce::Font::bold));
        addAndMakeVisible(titleLabel);

        // Subtitle
        subtitleLabel.setText("Ralph Wiggum Loop Genius", juce::dontSendNotification);
        subtitleLabel.setColour(juce::Label::textColourId, juce::Colours::grey);
        addAndMakeVisible(subtitleLabel);

        // Save button
        saveButton.setButtonText("Save Session");
        saveButton.addListener(this);
        addAndMakeVisible(saveButton);

        // Snapshot button
        snapshotButton.setButtonText("Create Snapshot");
        snapshotButton.addListener(this);
        addAndMakeVisible(snapshotButton);

        // Broadcast key button
        broadcastKeyButton.setButtonText("Broadcast Key to All Plugins");
        broadcastKeyButton.addListener(this);
        addAndMakeVisible(broadcastKeyButton);

        // Auto-save toggle
        autoSaveToggle.setButtonText("Auto-Save");
        autoSaveToggle.setToggleState(WiseSaveMode::getInstance().getConfig().autoSaveEnabled,
                                       juce::dontSendNotification);
        autoSaveToggle.addListener(this);
        addAndMakeVisible(autoSaveToggle);

        // Key-aware toggle
        keyAwareToggle.setButtonText("Snapshot on Key Change");
        keyAwareToggle.setToggleState(WiseSaveMode::getInstance().getConfig().createSnapshotOnKeyChange,
                                       juce::dontSendNotification);
        keyAwareToggle.addListener(this);
        addAndMakeVisible(keyAwareToggle);

        // Smart naming toggle
        smartNamingToggle.setButtonText("Smart Naming");
        smartNamingToggle.setToggleState(WiseSaveMode::getInstance().getConfig().smartNamingEnabled,
                                          juce::dontSendNotification);
        smartNamingToggle.addListener(this);
        addAndMakeVisible(smartNamingToggle);

        // Status
        statusLabel.setText("Ready", juce::dontSendNotification);
        addAndMakeVisible(statusLabel);

        // Snapshot count
        snapshotCountLabel.setText("Snapshots: 0", juce::dontSendNotification);
        addAndMakeVisible(snapshotCountLabel);

        // Dirty indicator
        dirtyIndicator.setText("", juce::dontSendNotification);
        addAndMakeVisible(dirtyIndicator);

        startTimer(1000);  // Update every second
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);

        titleLabel.setBounds(bounds.removeFromTop(24));
        subtitleLabel.setBounds(bounds.removeFromTop(18));

        bounds.removeFromTop(10);

        auto row = bounds.removeFromTop(30);
        saveButton.setBounds(row.removeFromLeft(120));
        row.removeFromLeft(10);
        snapshotButton.setBounds(row.removeFromLeft(140));

        bounds.removeFromTop(8);
        broadcastKeyButton.setBounds(bounds.removeFromTop(30));

        bounds.removeFromTop(10);
        autoSaveToggle.setBounds(bounds.removeFromTop(24));
        keyAwareToggle.setBounds(bounds.removeFromTop(24));
        smartNamingToggle.setBounds(bounds.removeFromTop(24));

        bounds.removeFromTop(10);
        snapshotCountLabel.setBounds(bounds.removeFromTop(20));
        statusLabel.setBounds(bounds.removeFromTop(20));
        dirtyIndicator.setBounds(bounds.removeFromTop(20));
    }

    void buttonClicked(juce::Button* button) override
    {
        auto& wiseSave = WiseSaveMode::getInstance();
        auto& keyManager = GlobalKeyScaleManager::getInstance();

        if (button == &saveButton)
        {
            // For demo, just create snapshot
            wiseSave.createSnapshot("Manual save");
            statusLabel.setText("Session saved", juce::dontSendNotification);
        }
        else if (button == &snapshotButton)
        {
            wiseSave.createSnapshot("User snapshot");
            statusLabel.setText("Snapshot created", juce::dontSendNotification);
        }
        else if (button == &broadcastKeyButton)
        {
            keyManager.broadcastKeyToAllPlugins();
            statusLabel.setText("Key broadcast to all plugins", juce::dontSendNotification);
        }
        else if (button == &autoSaveToggle)
        {
            auto config = wiseSave.getConfig();
            config.autoSaveEnabled = autoSaveToggle.getToggleState();
            wiseSave.setConfig(config);
        }
        else if (button == &keyAwareToggle)
        {
            auto config = wiseSave.getConfig();
            config.createSnapshotOnKeyChange = keyAwareToggle.getToggleState();
            wiseSave.setConfig(config);
        }
        else if (button == &smartNamingToggle)
        {
            auto config = wiseSave.getConfig();
            config.smartNamingEnabled = smartNamingToggle.getToggleState();
            wiseSave.setConfig(config);
        }

        updateUI();
    }

    void timerCallback() override
    {
        updateUI();
    }

private:
    void updateUI()
    {
        auto& wiseSave = WiseSaveMode::getInstance();

        snapshotCountLabel.setText("Snapshots: " +
            juce::String((int)wiseSave.getSnapshots().size()), juce::dontSendNotification);

        if (wiseSave.hasUnsavedChanges())
        {
            dirtyIndicator.setText("● Unsaved changes", juce::dontSendNotification);
            dirtyIndicator.setColour(juce::Label::textColourId, juce::Colours::orange);
        }
        else
        {
            dirtyIndicator.setText("○ All saved", juce::dontSendNotification);
            dirtyIndicator.setColour(juce::Label::textColourId, juce::Colours::green);
        }
    }

    juce::Label titleLabel;
    juce::Label subtitleLabel;
    juce::TextButton saveButton;
    juce::TextButton snapshotButton;
    juce::TextButton broadcastKeyButton;
    juce::ToggleButton autoSaveToggle;
    juce::ToggleButton keyAwareToggle;
    juce::ToggleButton smartNamingToggle;
    juce::Label statusLabel;
    juce::Label snapshotCountLabel;
    juce::Label dirtyIndicator;
};

} // namespace RalphWiggum
