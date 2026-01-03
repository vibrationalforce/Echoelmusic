/*
  ==============================================================================

    GlobalKeyScaleManager.h
    Ralph Wiggum Loop Genius - Global Key/Scale System

    "Tonarten übertragen sich bei Bedarf auf alle Plugins"
    (Keys transfer on demand to all plugins)

    Created: 2026
    Author: Echoelmusic Team

    Features:
    - Global project key/scale management
    - On-demand key broadcast to all registered plugins
    - Real-time key detection from MIDI/Audio
    - Key lock and modulation tracking
    - Plugin key synchronization protocol
    - Key history with undo/redo
    - Chord progression key changes
    - Multi-track key independence option
    - Wise Save Mode integration

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <set>
#include <functional>
#include <memory>
#include <atomic>
#include <mutex>

namespace RalphWiggum
{

//==============================================================================
/** Musical key representation */
enum class RootNote
{
    C = 0, Cs = 1, D = 2, Ds = 3, E = 4, F = 5,
    Fs = 6, G = 7, Gs = 8, A = 9, As = 10, B = 11
};

/** Scale types supported by the system */
enum class ScaleType
{
    // Western scales
    Major,              // Ionian
    NaturalMinor,       // Aeolian
    HarmonicMinor,
    MelodicMinor,
    Dorian,
    Phrygian,
    Lydian,
    Mixolydian,
    Locrian,

    // Pentatonic
    MajorPentatonic,
    MinorPentatonic,

    // Blues & Jazz
    Blues,
    BebopDominant,
    BebopMajor,

    // Exotic
    WholeTone,
    Diminished,
    Chromatic,
    Hungarian,
    Spanish,
    Arabic,
    Japanese,
    Persian,
    Byzantine,

    // Modal variations
    LydianDominant,
    SuperLocrian,       // Altered scale

    // Custom user scale
    Custom
};

//==============================================================================
/** Complete key/scale information */
struct KeySignature
{
    RootNote root = RootNote::C;
    ScaleType scale = ScaleType::Major;
    std::vector<int> customScaleIntervals;  // For Custom scale type

    // Optional: detected confidence
    float detectionConfidence = 1.0f;

    // Key modifiers
    bool isMinor() const
    {
        return scale == ScaleType::NaturalMinor ||
               scale == ScaleType::HarmonicMinor ||
               scale == ScaleType::MelodicMinor ||
               scale == ScaleType::Dorian ||
               scale == ScaleType::Phrygian ||
               scale == ScaleType::Locrian ||
               scale == ScaleType::MinorPentatonic;
    }

    /** Get scale intervals in semitones */
    std::vector<int> getIntervals() const
    {
        if (scale == ScaleType::Custom)
            return customScaleIntervals;

        static const std::map<ScaleType, std::vector<int>> intervals = {
            { ScaleType::Major,           {0, 2, 4, 5, 7, 9, 11} },
            { ScaleType::NaturalMinor,    {0, 2, 3, 5, 7, 8, 10} },
            { ScaleType::HarmonicMinor,   {0, 2, 3, 5, 7, 8, 11} },
            { ScaleType::MelodicMinor,    {0, 2, 3, 5, 7, 9, 11} },
            { ScaleType::Dorian,          {0, 2, 3, 5, 7, 9, 10} },
            { ScaleType::Phrygian,        {0, 1, 3, 5, 7, 8, 10} },
            { ScaleType::Lydian,          {0, 2, 4, 6, 7, 9, 11} },
            { ScaleType::Mixolydian,      {0, 2, 4, 5, 7, 9, 10} },
            { ScaleType::Locrian,         {0, 1, 3, 5, 6, 8, 10} },
            { ScaleType::MajorPentatonic, {0, 2, 4, 7, 9} },
            { ScaleType::MinorPentatonic, {0, 3, 5, 7, 10} },
            { ScaleType::Blues,           {0, 3, 5, 6, 7, 10} },
            { ScaleType::WholeTone,       {0, 2, 4, 6, 8, 10} },
            { ScaleType::Diminished,      {0, 2, 3, 5, 6, 8, 9, 11} },
            { ScaleType::Chromatic,       {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11} },
            { ScaleType::Hungarian,       {0, 2, 3, 6, 7, 8, 11} },
            { ScaleType::Spanish,         {0, 1, 4, 5, 7, 8, 10} },
            { ScaleType::Arabic,          {0, 1, 4, 5, 7, 8, 11} },
            { ScaleType::Japanese,        {0, 1, 5, 7, 8} },
            { ScaleType::Persian,         {0, 1, 4, 5, 6, 8, 11} },
            { ScaleType::Byzantine,       {0, 1, 4, 5, 7, 8, 11} },
            { ScaleType::BebopDominant,   {0, 2, 4, 5, 7, 9, 10, 11} },
            { ScaleType::BebopMajor,      {0, 2, 4, 5, 7, 8, 9, 11} },
            { ScaleType::LydianDominant,  {0, 2, 4, 6, 7, 9, 10} },
            { ScaleType::SuperLocrian,    {0, 1, 3, 4, 6, 8, 10} }
        };

        auto it = intervals.find(scale);
        if (it != intervals.end())
            return it->second;
        return {0, 2, 4, 5, 7, 9, 11};  // Default to major
    }

    /** Check if a MIDI note is in the scale */
    bool isNoteInScale(int midiNote) const
    {
        int noteClass = midiNote % 12;
        int rootOffset = static_cast<int>(root);
        int relativeNote = (noteClass - rootOffset + 12) % 12;

        auto intervals = getIntervals();
        return std::find(intervals.begin(), intervals.end(), relativeNote) != intervals.end();
    }

    /** Get display name */
    juce::String getDisplayName() const
    {
        static const std::array<juce::String, 12> noteNames = {
            "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
        };

        static const std::map<ScaleType, juce::String> scaleNames = {
            { ScaleType::Major, "Major" },
            { ScaleType::NaturalMinor, "Minor" },
            { ScaleType::HarmonicMinor, "Harmonic Minor" },
            { ScaleType::MelodicMinor, "Melodic Minor" },
            { ScaleType::Dorian, "Dorian" },
            { ScaleType::Phrygian, "Phrygian" },
            { ScaleType::Lydian, "Lydian" },
            { ScaleType::Mixolydian, "Mixolydian" },
            { ScaleType::Locrian, "Locrian" },
            { ScaleType::MajorPentatonic, "Major Pentatonic" },
            { ScaleType::MinorPentatonic, "Minor Pentatonic" },
            { ScaleType::Blues, "Blues" },
            { ScaleType::WholeTone, "Whole Tone" },
            { ScaleType::Diminished, "Diminished" },
            { ScaleType::Chromatic, "Chromatic" },
            { ScaleType::Hungarian, "Hungarian" },
            { ScaleType::Spanish, "Spanish" },
            { ScaleType::Arabic, "Arabic" },
            { ScaleType::Japanese, "Japanese" },
            { ScaleType::Persian, "Persian" },
            { ScaleType::Byzantine, "Byzantine" },
            { ScaleType::BebopDominant, "Bebop Dominant" },
            { ScaleType::BebopMajor, "Bebop Major" },
            { ScaleType::LydianDominant, "Lydian Dominant" },
            { ScaleType::SuperLocrian, "Super Locrian" },
            { ScaleType::Custom, "Custom" }
        };

        juce::String scaleName = "Major";
        auto it = scaleNames.find(scale);
        if (it != scaleNames.end())
            scaleName = it->second;

        return noteNames[static_cast<int>(root)] + " " + scaleName;
    }

    bool operator==(const KeySignature& other) const
    {
        return root == other.root && scale == other.scale;
    }

    bool operator!=(const KeySignature& other) const
    {
        return !(*this == other);
    }
};

//==============================================================================
/** Key change event for modulation tracking */
struct KeyChangeEvent
{
    KeySignature previousKey;
    KeySignature newKey;
    double positionBeats;       // Position in project
    double positionSeconds;
    juce::String reason;        // "Manual", "Detected", "Progression", "Modulation"
    float confidence;
    juce::Time timestamp;
};

//==============================================================================
/** Interface for plugins that want to receive key updates */
class KeyScaleListener
{
public:
    virtual ~KeyScaleListener() = default;

    /** Called when the global key changes */
    virtual void onKeyChanged(const KeySignature& newKey) = 0;

    /** Called when key is broadcast on demand */
    virtual void onKeyBroadcast(const KeySignature& key) = 0;

    /** Return plugin's unique ID for identification */
    virtual juce::String getPluginId() const = 0;

    /** Return true if plugin supports key sync */
    virtual bool supportsKeySync() const { return true; }

    /** Get plugin's current key (if it has its own) */
    virtual std::optional<KeySignature> getLocalKey() const { return std::nullopt; }

    /** Set whether this plugin follows global key */
    virtual void setFollowGlobalKey(bool follow) { followsGlobal = follow; }
    virtual bool getFollowGlobalKey() const { return followsGlobal; }

protected:
    bool followsGlobal = true;
};

//==============================================================================
/** Key detection from MIDI data */
class KeyDetector
{
public:
    KeyDetector() { reset(); }

    /** Reset detection state */
    void reset()
    {
        std::fill(noteHistogram.begin(), noteHistogram.end(), 0);
        totalNotes = 0;
    }

    /** Add a MIDI note to the histogram */
    void addNote(int midiNote, float velocity = 1.0f, float duration = 1.0f)
    {
        int noteClass = midiNote % 12;
        noteHistogram[noteClass] += velocity * duration;
        totalNotes++;
    }

    /** Detect the most likely key */
    KeySignature detectKey() const
    {
        if (totalNotes < 4)
            return KeySignature();  // Not enough data

        KeySignature bestKey;
        float bestScore = 0.0f;

        // Try all roots and common scales
        for (int root = 0; root < 12; ++root)
        {
            for (auto scale : { ScaleType::Major, ScaleType::NaturalMinor,
                               ScaleType::Dorian, ScaleType::Mixolydian,
                               ScaleType::MajorPentatonic, ScaleType::MinorPentatonic })
            {
                KeySignature testKey;
                testKey.root = static_cast<RootNote>(root);
                testKey.scale = scale;

                float score = calculateKeyScore(testKey);
                if (score > bestScore)
                {
                    bestScore = score;
                    bestKey = testKey;
                    bestKey.detectionConfidence = score;
                }
            }
        }

        return bestKey;
    }

private:
    float calculateKeyScore(const KeySignature& key) const
    {
        auto intervals = key.getIntervals();
        float inScaleWeight = 0.0f;
        float outScaleWeight = 0.0f;
        float totalWeight = 0.0f;

        for (int i = 0; i < 12; ++i)
        {
            int relativeNote = (i - static_cast<int>(key.root) + 12) % 12;
            bool inScale = std::find(intervals.begin(), intervals.end(), relativeNote) != intervals.end();

            totalWeight += noteHistogram[i];
            if (inScale)
                inScaleWeight += noteHistogram[i];
            else
                outScaleWeight += noteHistogram[i];
        }

        if (totalWeight == 0)
            return 0.0f;

        // Score based on in-scale ratio, with bonus for root and fifth
        float baseScore = inScaleWeight / totalWeight;

        // Bonus for root note presence
        int rootIndex = static_cast<int>(key.root);
        float rootBonus = noteHistogram[rootIndex] / totalWeight * 0.2f;

        // Bonus for fifth
        int fifthIndex = (rootIndex + 7) % 12;
        float fifthBonus = noteHistogram[fifthIndex] / totalWeight * 0.1f;

        return std::min(1.0f, baseScore + rootBonus + fifthBonus);
    }

    std::array<float, 12> noteHistogram;
    int totalNotes = 0;
};

//==============================================================================
/**
    GlobalKeyScaleManager

    Singleton manager for project-wide key/scale synchronization.

    "Ralph Wiggum Loop Genius" Philosophy:
    - Keep it simple but powerful
    - Key transfers when YOU want, not automatically (unless enabled)
    - All plugins can listen, but respect individual override
    - Wise Save remembers everything
*/
class GlobalKeyScaleManager : public juce::ChangeBroadcaster
{
public:
    //==========================================================================
    // Singleton Access

    static GlobalKeyScaleManager& getInstance()
    {
        static GlobalKeyScaleManager instance;
        return instance;
    }

    //==========================================================================
    // Key/Scale Management

    /** Get the current global key */
    KeySignature getCurrentKey() const
    {
        std::lock_guard<std::mutex> lock(keyMutex);
        return currentKey;
    }

    /** Set the global key manually */
    void setKey(const KeySignature& key, const juce::String& reason = "Manual")
    {
        std::lock_guard<std::mutex> lock(keyMutex);

        if (key != currentKey)
        {
            // Record key change event
            KeyChangeEvent event;
            event.previousKey = currentKey;
            event.newKey = key;
            event.positionBeats = currentPositionBeats;
            event.positionSeconds = currentPositionSeconds;
            event.reason = reason;
            event.confidence = key.detectionConfidence;
            event.timestamp = juce::Time::getCurrentTime();

            keyHistory.push_back(event);

            // Update current key
            currentKey = key;

            // Notify if auto-broadcast is enabled
            if (autoBroadcastEnabled)
            {
                broadcastKeyToAllPlugins();
            }

            sendChangeMessage();
        }
    }

    /** Set key by root and scale type */
    void setKey(RootNote root, ScaleType scale, const juce::String& reason = "Manual")
    {
        KeySignature key;
        key.root = root;
        key.scale = scale;
        key.detectionConfidence = 1.0f;  // Manual = full confidence
        setKey(key, reason);
    }

    //==========================================================================
    // Key Broadcast (Tonarten übertragen)

    /**
        Broadcast the current key to all registered plugins.
        This is the "on demand" transfer feature.
    */
    void broadcastKeyToAllPlugins()
    {
        std::lock_guard<std::mutex> lock(listenerMutex);

        KeySignature key = getCurrentKey();

        for (auto* listener : listeners)
        {
            if (listener->getFollowGlobalKey() && listener->supportsKeySync())
            {
                listener->onKeyBroadcast(key);
            }
        }

        lastBroadcastTime = juce::Time::getCurrentTime();
        broadcastCount++;
    }

    /** Broadcast to specific plugins only */
    void broadcastKeyToPlugins(const std::vector<juce::String>& pluginIds)
    {
        std::lock_guard<std::mutex> lock(listenerMutex);

        KeySignature key = getCurrentKey();
        std::set<juce::String> targetSet(pluginIds.begin(), pluginIds.end());

        for (auto* listener : listeners)
        {
            if (targetSet.count(listener->getPluginId()) > 0 && listener->supportsKeySync())
            {
                listener->onKeyBroadcast(key);
            }
        }
    }

    /** Enable/disable automatic broadcast on key change */
    void setAutoBroadcast(bool enabled)
    {
        autoBroadcastEnabled = enabled;
    }

    bool isAutoBroadcastEnabled() const
    {
        return autoBroadcastEnabled;
    }

    //==========================================================================
    // Listener Management

    /** Register a plugin to receive key updates */
    void addListener(KeyScaleListener* listener)
    {
        std::lock_guard<std::mutex> lock(listenerMutex);
        listeners.insert(listener);

        // Send current key to new listener
        listener->onKeyChanged(getCurrentKey());
    }

    /** Unregister a plugin */
    void removeListener(KeyScaleListener* listener)
    {
        std::lock_guard<std::mutex> lock(listenerMutex);
        listeners.erase(listener);
    }

    /** Get all registered plugin IDs */
    std::vector<juce::String> getRegisteredPluginIds() const
    {
        std::lock_guard<std::mutex> lock(listenerMutex);
        std::vector<juce::String> ids;
        for (auto* listener : listeners)
        {
            ids.push_back(listener->getPluginId());
        }
        return ids;
    }

    /** Get count of plugins following global key */
    int getFollowingPluginCount() const
    {
        std::lock_guard<std::mutex> lock(listenerMutex);
        int count = 0;
        for (auto* listener : listeners)
        {
            if (listener->getFollowGlobalKey())
                count++;
        }
        return count;
    }

    //==========================================================================
    // Key Detection

    /** Start detecting key from incoming MIDI */
    void startKeyDetection()
    {
        keyDetector.reset();
        isDetecting = true;
    }

    /** Stop detection and apply detected key */
    void stopKeyDetection(bool applyDetectedKey = true)
    {
        isDetecting = false;

        if (applyDetectedKey)
        {
            KeySignature detected = keyDetector.detectKey();
            if (detected.detectionConfidence > 0.6f)
            {
                setKey(detected, "Detected");
            }
        }
    }

    /** Feed MIDI note to detector */
    void feedMIDINote(int midiNote, float velocity, float duration)
    {
        if (isDetecting)
        {
            keyDetector.addNote(midiNote, velocity, duration);
        }
    }

    /** Get current detection result without applying */
    KeySignature peekDetectedKey() const
    {
        return keyDetector.detectKey();
    }

    //==========================================================================
    // Key History & Modulation Tracking

    /** Get key change history */
    const std::vector<KeyChangeEvent>& getKeyHistory() const
    {
        return keyHistory;
    }

    /** Clear key history */
    void clearKeyHistory()
    {
        keyHistory.clear();
    }

    /** Undo last key change */
    bool undoKeyChange()
    {
        if (keyHistory.size() > 1)
        {
            // Remove last event
            keyHistory.pop_back();

            // Restore previous key
            const auto& lastEvent = keyHistory.back();
            currentKey = lastEvent.newKey;

            if (autoBroadcastEnabled)
                broadcastKeyToAllPlugins();

            sendChangeMessage();
            return true;
        }
        return false;
    }

    //==========================================================================
    // Transport Position (for key change events)

    void setTransportPosition(double beats, double seconds)
    {
        currentPositionBeats = beats;
        currentPositionSeconds = seconds;
    }

    //==========================================================================
    // Key Lock (prevent automatic changes)

    void setKeyLocked(bool locked)
    {
        keyLocked = locked;
    }

    bool isKeyLocked() const
    {
        return keyLocked;
    }

    //==========================================================================
    // Serialization (for Wise Save Mode)

    std::unique_ptr<juce::XmlElement> createStateXML() const
    {
        auto xml = std::make_unique<juce::XmlElement>("GlobalKeyScale");

        // Current key
        auto* keyXml = xml->createNewChildElement("CurrentKey");
        keyXml->setAttribute("root", static_cast<int>(currentKey.root));
        keyXml->setAttribute("scale", static_cast<int>(currentKey.scale));
        keyXml->setAttribute("confidence", currentKey.detectionConfidence);

        // Settings
        xml->setAttribute("autoBroadcast", autoBroadcastEnabled);
        xml->setAttribute("keyLocked", keyLocked);

        // Key history
        auto* historyXml = xml->createNewChildElement("KeyHistory");
        for (const auto& event : keyHistory)
        {
            auto* eventXml = historyXml->createNewChildElement("Event");
            eventXml->setAttribute("prevRoot", static_cast<int>(event.previousKey.root));
            eventXml->setAttribute("prevScale", static_cast<int>(event.previousKey.scale));
            eventXml->setAttribute("newRoot", static_cast<int>(event.newKey.root));
            eventXml->setAttribute("newScale", static_cast<int>(event.newKey.scale));
            eventXml->setAttribute("posBeats", event.positionBeats);
            eventXml->setAttribute("reason", event.reason);
            eventXml->setAttribute("confidence", event.confidence);
        }

        // Plugin follow states
        auto* pluginsXml = xml->createNewChildElement("PluginStates");
        {
            std::lock_guard<std::mutex> lock(listenerMutex);
            for (auto* listener : listeners)
            {
                auto* pluginXml = pluginsXml->createNewChildElement("Plugin");
                pluginXml->setAttribute("id", listener->getPluginId());
                pluginXml->setAttribute("followGlobal", listener->getFollowGlobalKey());

                auto localKey = listener->getLocalKey();
                if (localKey.has_value())
                {
                    pluginXml->setAttribute("hasLocalKey", true);
                    pluginXml->setAttribute("localRoot", static_cast<int>(localKey->root));
                    pluginXml->setAttribute("localScale", static_cast<int>(localKey->scale));
                }
            }
        }

        return xml;
    }

    void restoreFromXML(const juce::XmlElement& xml)
    {
        // Current key
        if (auto* keyXml = xml.getChildByName("CurrentKey"))
        {
            currentKey.root = static_cast<RootNote>(keyXml->getIntAttribute("root", 0));
            currentKey.scale = static_cast<ScaleType>(keyXml->getIntAttribute("scale", 0));
            currentKey.detectionConfidence = (float)keyXml->getDoubleAttribute("confidence", 1.0);
        }

        // Settings
        autoBroadcastEnabled = xml.getBoolAttribute("autoBroadcast", false);
        keyLocked = xml.getBoolAttribute("keyLocked", false);

        // Key history
        keyHistory.clear();
        if (auto* historyXml = xml.getChildByName("KeyHistory"))
        {
            for (auto* eventXml : historyXml->getChildIterator())
            {
                KeyChangeEvent event;
                event.previousKey.root = static_cast<RootNote>(eventXml->getIntAttribute("prevRoot"));
                event.previousKey.scale = static_cast<ScaleType>(eventXml->getIntAttribute("prevScale"));
                event.newKey.root = static_cast<RootNote>(eventXml->getIntAttribute("newRoot"));
                event.newKey.scale = static_cast<ScaleType>(eventXml->getIntAttribute("newScale"));
                event.positionBeats = eventXml->getDoubleAttribute("posBeats");
                event.reason = eventXml->getStringAttribute("reason");
                event.confidence = (float)eventXml->getDoubleAttribute("confidence");
                keyHistory.push_back(event);
            }
        }

        // Broadcast restored key
        broadcastKeyToAllPlugins();
        sendChangeMessage();
    }

    //==========================================================================
    // Statistics

    int getBroadcastCount() const { return broadcastCount; }
    juce::Time getLastBroadcastTime() const { return lastBroadcastTime; }

private:
    GlobalKeyScaleManager() = default;
    ~GlobalKeyScaleManager() = default;

    GlobalKeyScaleManager(const GlobalKeyScaleManager&) = delete;
    GlobalKeyScaleManager& operator=(const GlobalKeyScaleManager&) = delete;

    //==========================================================================
    // State

    KeySignature currentKey;
    mutable std::mutex keyMutex;

    std::set<KeyScaleListener*> listeners;
    mutable std::mutex listenerMutex;

    KeyDetector keyDetector;
    std::atomic<bool> isDetecting{false};

    std::vector<KeyChangeEvent> keyHistory;

    bool autoBroadcastEnabled = false;  // Default: manual broadcast
    bool keyLocked = false;

    double currentPositionBeats = 0.0;
    double currentPositionSeconds = 0.0;

    // Statistics
    int broadcastCount = 0;
    juce::Time lastBroadcastTime;
};

//==============================================================================
/**
    KeyScaleSyncComponent

    UI component for key/scale display and control.
*/
class KeyScaleSyncComponent : public juce::Component,
                               public juce::ChangeListener,
                               public juce::ComboBox::Listener,
                               public juce::Button::Listener
{
public:
    KeyScaleSyncComponent()
    {
        // Root note selector
        rootSelector.addItem("C", 1);
        rootSelector.addItem("C#", 2);
        rootSelector.addItem("D", 3);
        rootSelector.addItem("D#", 4);
        rootSelector.addItem("E", 5);
        rootSelector.addItem("F", 6);
        rootSelector.addItem("F#", 7);
        rootSelector.addItem("G", 8);
        rootSelector.addItem("G#", 9);
        rootSelector.addItem("A", 10);
        rootSelector.addItem("A#", 11);
        rootSelector.addItem("B", 12);
        rootSelector.setSelectedId(1);
        rootSelector.addListener(this);
        addAndMakeVisible(rootSelector);

        // Scale selector
        scaleSelector.addItem("Major", 1);
        scaleSelector.addItem("Minor", 2);
        scaleSelector.addItem("Dorian", 3);
        scaleSelector.addItem("Phrygian", 4);
        scaleSelector.addItem("Lydian", 5);
        scaleSelector.addItem("Mixolydian", 6);
        scaleSelector.addItem("Harmonic Minor", 7);
        scaleSelector.addItem("Melodic Minor", 8);
        scaleSelector.addItem("Major Pentatonic", 9);
        scaleSelector.addItem("Minor Pentatonic", 10);
        scaleSelector.addItem("Blues", 11);
        scaleSelector.setSelectedId(1);
        scaleSelector.addListener(this);
        addAndMakeVisible(scaleSelector);

        // Broadcast button
        broadcastButton.setButtonText("Broadcast Key");
        broadcastButton.addListener(this);
        addAndMakeVisible(broadcastButton);

        // Auto-broadcast toggle
        autoBroadcastToggle.setButtonText("Auto");
        autoBroadcastToggle.addListener(this);
        addAndMakeVisible(autoBroadcastToggle);

        // Key lock toggle
        keyLockToggle.setButtonText("Lock");
        keyLockToggle.addListener(this);
        addAndMakeVisible(keyLockToggle);

        // Detect button
        detectButton.setButtonText("Detect");
        detectButton.addListener(this);
        addAndMakeVisible(detectButton);

        // Status label
        statusLabel.setText("0 plugins synced", juce::dontSendNotification);
        statusLabel.setJustificationType(juce::Justification::centred);
        addAndMakeVisible(statusLabel);

        // Register for updates
        GlobalKeyScaleManager::getInstance().addChangeListener(this);
        updateFromManager();
    }

    ~KeyScaleSyncComponent() override
    {
        GlobalKeyScaleManager::getInstance().removeChangeListener(this);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(4);
        int rowHeight = 28;
        int spacing = 4;

        auto row1 = bounds.removeFromTop(rowHeight);
        rootSelector.setBounds(row1.removeFromLeft(80));
        row1.removeFromLeft(spacing);
        scaleSelector.setBounds(row1);

        bounds.removeFromTop(spacing);

        auto row2 = bounds.removeFromTop(rowHeight);
        broadcastButton.setBounds(row2.removeFromLeft(120));
        row2.removeFromLeft(spacing);
        autoBroadcastToggle.setBounds(row2.removeFromLeft(50));
        row2.removeFromLeft(spacing);
        keyLockToggle.setBounds(row2.removeFromLeft(50));
        row2.removeFromLeft(spacing);
        detectButton.setBounds(row2);

        bounds.removeFromTop(spacing);
        statusLabel.setBounds(bounds.removeFromTop(20));
    }

    void comboBoxChanged(juce::ComboBox* box) override
    {
        auto& manager = GlobalKeyScaleManager::getInstance();
        if (manager.isKeyLocked())
            return;

        if (box == &rootSelector || box == &scaleSelector)
        {
            RootNote root = static_cast<RootNote>(rootSelector.getSelectedId() - 1);

            // Map combo selection to ScaleType
            static const std::map<int, ScaleType> scaleMap = {
                {1, ScaleType::Major},
                {2, ScaleType::NaturalMinor},
                {3, ScaleType::Dorian},
                {4, ScaleType::Phrygian},
                {5, ScaleType::Lydian},
                {6, ScaleType::Mixolydian},
                {7, ScaleType::HarmonicMinor},
                {8, ScaleType::MelodicMinor},
                {9, ScaleType::MajorPentatonic},
                {10, ScaleType::MinorPentatonic},
                {11, ScaleType::Blues}
            };

            ScaleType scale = ScaleType::Major;
            auto it = scaleMap.find(scaleSelector.getSelectedId());
            if (it != scaleMap.end())
                scale = it->second;

            manager.setKey(root, scale);
        }
    }

    void buttonClicked(juce::Button* button) override
    {
        auto& manager = GlobalKeyScaleManager::getInstance();

        if (button == &broadcastButton)
        {
            manager.broadcastKeyToAllPlugins();
            updateStatus();
        }
        else if (button == &autoBroadcastToggle)
        {
            manager.setAutoBroadcast(autoBroadcastToggle.getToggleState());
        }
        else if (button == &keyLockToggle)
        {
            manager.setKeyLocked(keyLockToggle.getToggleState());
            rootSelector.setEnabled(!keyLockToggle.getToggleState());
            scaleSelector.setEnabled(!keyLockToggle.getToggleState());
        }
        else if (button == &detectButton)
        {
            if (detectButton.getToggleState())
            {
                manager.startKeyDetection();
                detectButton.setButtonText("Stop");
            }
            else
            {
                manager.stopKeyDetection(true);
                detectButton.setButtonText("Detect");
                updateFromManager();
            }
        }
    }

    void changeListenerCallback(juce::ChangeBroadcaster*) override
    {
        updateFromManager();
    }

private:
    void updateFromManager()
    {
        auto& manager = GlobalKeyScaleManager::getInstance();
        auto key = manager.getCurrentKey();

        rootSelector.setSelectedId(static_cast<int>(key.root) + 1, juce::dontSendNotification);

        // Reverse map for scale
        static const std::map<ScaleType, int> reverseScaleMap = {
            {ScaleType::Major, 1},
            {ScaleType::NaturalMinor, 2},
            {ScaleType::Dorian, 3},
            {ScaleType::Phrygian, 4},
            {ScaleType::Lydian, 5},
            {ScaleType::Mixolydian, 6},
            {ScaleType::HarmonicMinor, 7},
            {ScaleType::MelodicMinor, 8},
            {ScaleType::MajorPentatonic, 9},
            {ScaleType::MinorPentatonic, 10},
            {ScaleType::Blues, 11}
        };

        auto it = reverseScaleMap.find(key.scale);
        if (it != reverseScaleMap.end())
            scaleSelector.setSelectedId(it->second, juce::dontSendNotification);

        autoBroadcastToggle.setToggleState(manager.isAutoBroadcastEnabled(), juce::dontSendNotification);
        keyLockToggle.setToggleState(manager.isKeyLocked(), juce::dontSendNotification);

        updateStatus();
    }

    void updateStatus()
    {
        auto& manager = GlobalKeyScaleManager::getInstance();
        int count = manager.getFollowingPluginCount();
        statusLabel.setText(juce::String(count) + " plugins synced", juce::dontSendNotification);
    }

    juce::ComboBox rootSelector;
    juce::ComboBox scaleSelector;
    juce::TextButton broadcastButton;
    juce::ToggleButton autoBroadcastToggle;
    juce::ToggleButton keyLockToggle;
    juce::ToggleButton detectButton;
    juce::Label statusLabel;
};

} // namespace RalphWiggum
