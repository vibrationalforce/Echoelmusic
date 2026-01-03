#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>
#include <chrono>

/**
 * MixSnapshotSystem - Professional Mix State Recall
 *
 * Save, organize, and instantly recall complete mix states:
 * - All fader positions and gain values
 * - Pan, mute, solo states
 * - Plugin parameters and bypass states
 * - Send levels and routing
 * - Automation enable states
 * - A/B comparison with morphing
 * - Version history with undo
 * - Export/import for collaboration
 *
 * Inspired by: Pro Tools, SSL consoles, Neve DFC
 */

namespace Echoelmusic {
namespace Mixer {

//==============================================================================
// Channel State
//==============================================================================

struct ChannelState
{
    juce::String name;
    int index = 0;

    // Fader & Pan
    float faderDb = 0.0f;           // -inf to +12 dB
    float pan = 0.0f;               // -1 (L) to +1 (R)

    // States
    bool muted = false;
    bool solo = false;
    bool recordArmed = false;
    bool monitorEnabled = false;

    // Automation
    bool automationRead = true;
    bool automationWrite = false;

    // Sends (up to 8)
    std::array<float, 8> sendLevels = { 0.0f };
    std::array<bool, 8> sendEnabled = { false };

    // Input/Output routing
    int inputBus = 0;
    int outputBus = 0;

    // Plugin states (serialized)
    std::vector<juce::MemoryBlock> pluginStates;
    std::vector<bool> pluginBypassed;

    // Color coding
    juce::Colour trackColor = juce::Colours::grey;

    ChannelState() = default;
};

//==============================================================================
// Mix Snapshot
//==============================================================================

struct MixSnapshot
{
    juce::String name;
    juce::String description;
    juce::String author;
    juce::Time timestamp;
    juce::Uuid uuid;

    // All channel states
    std::vector<ChannelState> channels;

    // Master section
    float masterFaderDb = 0.0f;
    bool masterMono = false;
    bool masterDim = false;
    float masterDimAmount = -20.0f;

    // Global states
    double tempo = 120.0;
    int timeSignatureNum = 4;
    int timeSignatureDenom = 4;

    // Tags for organization
    std::vector<juce::String> tags;

    // Rating (1-5 stars)
    int rating = 0;

    // Thumbnail waveform data (optional)
    std::vector<float> waveformThumbnail;

    MixSnapshot()
    {
        uuid = juce::Uuid();
        timestamp = juce::Time::getCurrentTime();
    }

    MixSnapshot(const juce::String& snapshotName)
        : name(snapshotName)
    {
        uuid = juce::Uuid();
        timestamp = juce::Time::getCurrentTime();
    }
};

//==============================================================================
// Snapshot Comparison Result
//==============================================================================

struct SnapshotDiff
{
    struct ChannelDiff
    {
        int channelIndex;
        juce::String channelName;

        bool faderChanged = false;
        float faderDelta = 0.0f;

        bool panChanged = false;
        float panDelta = 0.0f;

        bool muteChanged = false;
        bool soloChanged = false;

        bool pluginsChanged = false;
        int pluginsModified = 0;
    };

    std::vector<ChannelDiff> channelDiffs;
    bool masterChanged = false;
    bool tempoChanged = false;

    int totalChanges = 0;
};

//==============================================================================
// Mix Snapshot System
//==============================================================================

class MixSnapshotSystem
{
public:
    //==========================================================================
    // Constructor
    //==========================================================================

    MixSnapshotSystem() = default;

    //==========================================================================
    // Snapshot Management
    //==========================================================================

    /** Create a new snapshot from current mix state */
    int createSnapshot(const juce::String& name, const juce::String& description = "")
    {
        MixSnapshot snapshot(name);
        snapshot.description = description;
        snapshot.author = currentAuthor;

        // Capture current state
        captureCurrentState(snapshot);

        snapshots.push_back(snapshot);

        // Add to undo history
        addToHistory(static_cast<int>(snapshots.size()) - 1);

        if (onSnapshotCreated)
            onSnapshotCreated(static_cast<int>(snapshots.size()) - 1);

        return static_cast<int>(snapshots.size()) - 1;
    }

    /** Recall a snapshot by index */
    bool recallSnapshot(int index, bool interpolate = false, float morphTime = 0.0f)
    {
        if (index < 0 || index >= static_cast<int>(snapshots.size()))
            return false;

        const auto& snapshot = snapshots[index];

        if (interpolate && morphTime > 0.0f)
        {
            // Start morph transition
            startMorph(currentSnapshotIndex, index, morphTime);
        }
        else
        {
            // Instant recall
            applySnapshot(snapshot);
            currentSnapshotIndex = index;
        }

        if (onSnapshotRecalled)
            onSnapshotRecalled(index);

        return true;
    }

    /** Update existing snapshot with current state */
    bool updateSnapshot(int index)
    {
        if (index < 0 || index >= static_cast<int>(snapshots.size()))
            return false;

        auto& snapshot = snapshots[index];
        snapshot.timestamp = juce::Time::getCurrentTime();
        captureCurrentState(snapshot);

        if (onSnapshotUpdated)
            onSnapshotUpdated(index);

        return true;
    }

    /** Delete a snapshot */
    bool deleteSnapshot(int index)
    {
        if (index < 0 || index >= static_cast<int>(snapshots.size()))
            return false;

        snapshots.erase(snapshots.begin() + index);

        if (currentSnapshotIndex >= index && currentSnapshotIndex > 0)
            currentSnapshotIndex--;

        return true;
    }

    /** Rename a snapshot */
    bool renameSnapshot(int index, const juce::String& newName)
    {
        if (index < 0 || index >= static_cast<int>(snapshots.size()))
            return false;

        snapshots[index].name = newName;
        return true;
    }

    /** Duplicate a snapshot */
    int duplicateSnapshot(int index)
    {
        if (index < 0 || index >= static_cast<int>(snapshots.size()))
            return -1;

        MixSnapshot copy = snapshots[index];
        copy.name = snapshots[index].name + " (Copy)";
        copy.uuid = juce::Uuid();
        copy.timestamp = juce::Time::getCurrentTime();

        snapshots.push_back(copy);
        return static_cast<int>(snapshots.size()) - 1;
    }

    //==========================================================================
    // A/B Comparison
    //==========================================================================

    /** Set snapshot A for comparison */
    void setCompareA(int index)
    {
        if (index >= 0 && index < static_cast<int>(snapshots.size()))
            compareAIndex = index;
    }

    /** Set snapshot B for comparison */
    void setCompareB(int index)
    {
        if (index >= 0 && index < static_cast<int>(snapshots.size()))
            compareBIndex = index;
    }

    /** Toggle between A and B */
    void toggleAB()
    {
        if (compareAIndex < 0 || compareBIndex < 0)
            return;

        isShowingA = !isShowingA;
        recallSnapshot(isShowingA ? compareAIndex : compareBIndex);
    }

    /** Get which snapshot is currently active (A or B) */
    bool isShowingSnapshotA() const { return isShowingA; }

    /** Compare two snapshots and get differences */
    SnapshotDiff compareSnapshots(int indexA, int indexB) const
    {
        SnapshotDiff diff;

        if (indexA < 0 || indexA >= static_cast<int>(snapshots.size()) ||
            indexB < 0 || indexB >= static_cast<int>(snapshots.size()))
            return diff;

        const auto& a = snapshots[indexA];
        const auto& b = snapshots[indexB];

        // Compare channels
        size_t numChannels = std::min(a.channels.size(), b.channels.size());
        for (size_t i = 0; i < numChannels; ++i)
        {
            SnapshotDiff::ChannelDiff cd;
            cd.channelIndex = static_cast<int>(i);
            cd.channelName = a.channels[i].name;

            if (std::abs(a.channels[i].faderDb - b.channels[i].faderDb) > 0.1f)
            {
                cd.faderChanged = true;
                cd.faderDelta = b.channels[i].faderDb - a.channels[i].faderDb;
                diff.totalChanges++;
            }

            if (std::abs(a.channels[i].pan - b.channels[i].pan) > 0.01f)
            {
                cd.panChanged = true;
                cd.panDelta = b.channels[i].pan - a.channels[i].pan;
                diff.totalChanges++;
            }

            if (a.channels[i].muted != b.channels[i].muted)
            {
                cd.muteChanged = true;
                diff.totalChanges++;
            }

            if (a.channels[i].solo != b.channels[i].solo)
            {
                cd.soloChanged = true;
                diff.totalChanges++;
            }

            if (cd.faderChanged || cd.panChanged || cd.muteChanged || cd.soloChanged)
                diff.channelDiffs.push_back(cd);
        }

        // Compare master
        if (std::abs(a.masterFaderDb - b.masterFaderDb) > 0.1f)
        {
            diff.masterChanged = true;
            diff.totalChanges++;
        }

        // Compare tempo
        if (std::abs(a.tempo - b.tempo) > 0.1)
        {
            diff.tempoChanged = true;
            diff.totalChanges++;
        }

        return diff;
    }

    //==========================================================================
    // Morphing Between Snapshots
    //==========================================================================

    /** Start morphing between two snapshots */
    void startMorph(int fromIndex, int toIndex, float durationSeconds)
    {
        if (fromIndex < 0 || fromIndex >= static_cast<int>(snapshots.size()) ||
            toIndex < 0 || toIndex >= static_cast<int>(snapshots.size()))
            return;

        morphFromIndex = fromIndex;
        morphToIndex = toIndex;
        morphDuration = durationSeconds;
        morphProgress = 0.0f;
        isMorphing = true;
    }

    /** Update morph progress (call from timer or audio callback) */
    void updateMorph(float deltaTime)
    {
        if (!isMorphing)
            return;

        morphProgress += deltaTime / morphDuration;

        if (morphProgress >= 1.0f)
        {
            morphProgress = 1.0f;
            isMorphing = false;
            currentSnapshotIndex = morphToIndex;
            applySnapshot(snapshots[morphToIndex]);
        }
        else
        {
            // Interpolate between snapshots
            applyInterpolatedSnapshot(snapshots[morphFromIndex],
                                     snapshots[morphToIndex],
                                     morphProgress);
        }
    }

    /** Get current morph position (0-1) */
    float getMorphProgress() const { return morphProgress; }

    /** Check if currently morphing */
    bool getIsMorphing() const { return isMorphing; }

    /** Cancel current morph */
    void cancelMorph()
    {
        isMorphing = false;
        morphProgress = 0.0f;
    }

    //==========================================================================
    // Organization & Search
    //==========================================================================

    /** Add tag to snapshot */
    void addTag(int index, const juce::String& tag)
    {
        if (index >= 0 && index < static_cast<int>(snapshots.size()))
        {
            auto& tags = snapshots[index].tags;
            if (std::find(tags.begin(), tags.end(), tag) == tags.end())
                tags.push_back(tag);
        }
    }

    /** Remove tag from snapshot */
    void removeTag(int index, const juce::String& tag)
    {
        if (index >= 0 && index < static_cast<int>(snapshots.size()))
        {
            auto& tags = snapshots[index].tags;
            tags.erase(std::remove(tags.begin(), tags.end(), tag), tags.end());
        }
    }

    /** Set rating for snapshot */
    void setRating(int index, int rating)
    {
        if (index >= 0 && index < static_cast<int>(snapshots.size()))
            snapshots[index].rating = juce::jlimit(0, 5, rating);
    }

    /** Find snapshots by tag */
    std::vector<int> findByTag(const juce::String& tag) const
    {
        std::vector<int> results;
        for (size_t i = 0; i < snapshots.size(); ++i)
        {
            const auto& tags = snapshots[i].tags;
            if (std::find(tags.begin(), tags.end(), tag) != tags.end())
                results.push_back(static_cast<int>(i));
        }
        return results;
    }

    /** Find snapshots by name (partial match) */
    std::vector<int> findByName(const juce::String& searchTerm) const
    {
        std::vector<int> results;
        for (size_t i = 0; i < snapshots.size(); ++i)
        {
            if (snapshots[i].name.containsIgnoreCase(searchTerm))
                results.push_back(static_cast<int>(i));
        }
        return results;
    }

    //==========================================================================
    // Undo/Redo
    //==========================================================================

    /** Undo last snapshot operation */
    bool undo()
    {
        if (historyIndex <= 0)
            return false;

        historyIndex--;
        recallSnapshot(history[historyIndex]);
        return true;
    }

    /** Redo last undone operation */
    bool redo()
    {
        if (historyIndex >= static_cast<int>(history.size()) - 1)
            return false;

        historyIndex++;
        recallSnapshot(history[historyIndex]);
        return true;
    }

    /** Check if undo is available */
    bool canUndo() const { return historyIndex > 0; }

    /** Check if redo is available */
    bool canRedo() const { return historyIndex < static_cast<int>(history.size()) - 1; }

    //==========================================================================
    // Import/Export
    //==========================================================================

    /** Export snapshot to file */
    bool exportSnapshot(int index, const juce::File& file) const
    {
        if (index < 0 || index >= static_cast<int>(snapshots.size()))
            return false;

        const auto& snapshot = snapshots[index];

        juce::var data;
        data.append(juce::var(snapshot.name));
        data.append(juce::var(snapshot.description));
        data.append(juce::var(snapshot.author));
        data.append(juce::var(snapshot.timestamp.toMilliseconds()));
        data.append(juce::var(snapshot.masterFaderDb));
        data.append(juce::var(snapshot.tempo));

        // Serialize channels
        juce::var channelsData;
        for (const auto& ch : snapshot.channels)
        {
            juce::var chData;
            chData.append(juce::var(ch.name));
            chData.append(juce::var(ch.faderDb));
            chData.append(juce::var(ch.pan));
            chData.append(juce::var(ch.muted));
            chData.append(juce::var(ch.solo));
            channelsData.append(chData);
        }
        data.append(channelsData);

        juce::String json = juce::JSON::toString(data);
        return file.replaceWithText(json);
    }

    /** Import snapshot from file */
    int importSnapshot(const juce::File& file)
    {
        juce::String json = file.loadFileAsString();
        juce::var data = juce::JSON::parse(json);

        if (!data.isArray())
            return -1;

        MixSnapshot snapshot;
        snapshot.name = data[0].toString();
        snapshot.description = data[1].toString();
        snapshot.author = data[2].toString();
        snapshot.timestamp = juce::Time(data[3].operator int64());
        snapshot.masterFaderDb = static_cast<float>(data[4]);
        snapshot.tempo = static_cast<double>(data[5]);

        // Deserialize channels
        juce::var channelsData = data[6];
        if (channelsData.isArray())
        {
            for (int i = 0; i < channelsData.size(); ++i)
            {
                juce::var chData = channelsData[i];
                ChannelState ch;
                ch.name = chData[0].toString();
                ch.faderDb = static_cast<float>(chData[1]);
                ch.pan = static_cast<float>(chData[2]);
                ch.muted = static_cast<bool>(chData[3]);
                ch.solo = static_cast<bool>(chData[4]);
                snapshot.channels.push_back(ch);
            }
        }

        snapshots.push_back(snapshot);
        return static_cast<int>(snapshots.size()) - 1;
    }

    /** Export all snapshots to folder */
    bool exportAll(const juce::File& folder) const
    {
        if (!folder.isDirectory())
            folder.createDirectory();

        for (size_t i = 0; i < snapshots.size(); ++i)
        {
            juce::String filename = juce::String(i) + "_" +
                snapshots[i].name.replaceCharacters(" /\\", "___") + ".emsnap";
            exportSnapshot(static_cast<int>(i), folder.getChildFile(filename));
        }

        return true;
    }

    //==========================================================================
    // Getters
    //==========================================================================

    int getNumSnapshots() const { return static_cast<int>(snapshots.size()); }

    const MixSnapshot* getSnapshot(int index) const
    {
        if (index >= 0 && index < static_cast<int>(snapshots.size()))
            return &snapshots[index];
        return nullptr;
    }

    int getCurrentSnapshotIndex() const { return currentSnapshotIndex; }

    const std::vector<MixSnapshot>& getAllSnapshots() const { return snapshots; }

    //==========================================================================
    // Channel State Interface (to be connected to mixer)
    //==========================================================================

    std::function<void(int channelIndex, const ChannelState&)> onApplyChannelState;
    std::function<ChannelState(int channelIndex)> onCaptureChannelState;
    std::function<int()> onGetNumChannels;

    std::function<void(float)> onApplyMasterFader;
    std::function<float()> onCaptureMasterFader;

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(int)> onSnapshotCreated;
    std::function<void(int)> onSnapshotRecalled;
    std::function<void(int)> onSnapshotUpdated;
    std::function<void(float)> onMorphProgress;

    //==========================================================================
    // Configuration
    //==========================================================================

    void setAuthor(const juce::String& author) { currentAuthor = author; }
    void setMaxHistory(int max) { maxHistory = max; }

private:
    std::vector<MixSnapshot> snapshots;
    int currentSnapshotIndex = -1;

    // A/B comparison
    int compareAIndex = -1;
    int compareBIndex = -1;
    bool isShowingA = true;

    // Morphing
    bool isMorphing = false;
    int morphFromIndex = -1;
    int morphToIndex = -1;
    float morphDuration = 1.0f;
    float morphProgress = 0.0f;

    // Undo history
    std::vector<int> history;
    int historyIndex = -1;
    int maxHistory = 50;

    // Settings
    juce::String currentAuthor;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void captureCurrentState(MixSnapshot& snapshot)
    {
        if (!onGetNumChannels || !onCaptureChannelState)
            return;

        int numChannels = onGetNumChannels();
        snapshot.channels.clear();

        for (int i = 0; i < numChannels; ++i)
        {
            snapshot.channels.push_back(onCaptureChannelState(i));
        }

        if (onCaptureMasterFader)
            snapshot.masterFaderDb = onCaptureMasterFader();
    }

    void applySnapshot(const MixSnapshot& snapshot)
    {
        if (!onApplyChannelState)
            return;

        for (size_t i = 0; i < snapshot.channels.size(); ++i)
        {
            onApplyChannelState(static_cast<int>(i), snapshot.channels[i]);
        }

        if (onApplyMasterFader)
            onApplyMasterFader(snapshot.masterFaderDb);
    }

    void applyInterpolatedSnapshot(const MixSnapshot& from,
                                   const MixSnapshot& to,
                                   float t)
    {
        if (!onApplyChannelState)
            return;

        // Smooth interpolation curve
        float smoothT = t * t * (3.0f - 2.0f * t);

        size_t numChannels = std::min(from.channels.size(), to.channels.size());

        for (size_t i = 0; i < numChannels; ++i)
        {
            ChannelState interpolated;
            interpolated.name = to.channels[i].name;
            interpolated.index = static_cast<int>(i);

            // Interpolate continuous values
            interpolated.faderDb = from.channels[i].faderDb +
                (to.channels[i].faderDb - from.channels[i].faderDb) * smoothT;
            interpolated.pan = from.channels[i].pan +
                (to.channels[i].pan - from.channels[i].pan) * smoothT;

            // Snap boolean values at midpoint
            interpolated.muted = (smoothT < 0.5f) ? from.channels[i].muted : to.channels[i].muted;
            interpolated.solo = (smoothT < 0.5f) ? from.channels[i].solo : to.channels[i].solo;

            // Interpolate sends
            for (int s = 0; s < 8; ++s)
            {
                interpolated.sendLevels[s] = from.channels[i].sendLevels[s] +
                    (to.channels[i].sendLevels[s] - from.channels[i].sendLevels[s]) * smoothT;
            }

            onApplyChannelState(static_cast<int>(i), interpolated);
        }

        // Interpolate master
        if (onApplyMasterFader)
        {
            float masterDb = from.masterFaderDb +
                (to.masterFaderDb - from.masterFaderDb) * smoothT;
            onApplyMasterFader(masterDb);
        }

        if (onMorphProgress)
            onMorphProgress(t);
    }

    void addToHistory(int snapshotIndex)
    {
        // Truncate redo history if we're in the middle
        if (historyIndex < static_cast<int>(history.size()) - 1)
        {
            history.erase(history.begin() + historyIndex + 1, history.end());
        }

        history.push_back(snapshotIndex);
        historyIndex = static_cast<int>(history.size()) - 1;

        // Limit history size
        while (static_cast<int>(history.size()) > maxHistory)
        {
            history.erase(history.begin());
            historyIndex--;
        }
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MixSnapshotSystem)
};

} // namespace Mixer
} // namespace Echoelmusic
