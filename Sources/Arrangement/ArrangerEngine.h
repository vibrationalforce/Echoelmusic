#pragma once

#include <JuceHeader.h>
#include <algorithm>
#include <functional>
#include <map>
#include <memory>
#include <vector>

namespace Echoelmusic {

/**
 * ArrangerEngine - Song Structure and Marker System
 *
 * Features:
 * - Timeline markers (named positions)
 * - Arrangement sections (Intro, Verse, Chorus, Bridge, Outro, etc.)
 * - Section looping and arrangement playback
 * - Tempo and time signature changes
 * - Quick navigation between sections
 * - Section colors for visual organization
 * - Import/Export of arrangement data
 * - Arrangement templates
 * - Chord progressions per section
 */

//==============================================================================
// Marker Types
//==============================================================================

enum class MarkerType
{
    Generic,            // Simple named marker
    LoopStart,          // Loop region start
    LoopEnd,            // Loop region end
    PunchIn,            // Recording punch in
    PunchOut,           // Recording punch out
    Cue,                // Cue point (for DJing)
    Beat,               // Beat marker (for beat matching)
    Sync                // Sync point (for video)
};

//==============================================================================
// Section Types
//==============================================================================

enum class SectionType
{
    Intro,
    Verse,
    PreChorus,
    Chorus,
    PostChorus,
    Bridge,
    Breakdown,
    Buildup,
    Drop,
    Solo,
    Interlude,
    Outro,
    Tag,
    Custom
};

inline juce::String getSectionTypeName(SectionType type)
{
    switch (type)
    {
        case SectionType::Intro:      return "Intro";
        case SectionType::Verse:      return "Verse";
        case SectionType::PreChorus:  return "Pre-Chorus";
        case SectionType::Chorus:     return "Chorus";
        case SectionType::PostChorus: return "Post-Chorus";
        case SectionType::Bridge:     return "Bridge";
        case SectionType::Breakdown:  return "Breakdown";
        case SectionType::Buildup:    return "Build-Up";
        case SectionType::Drop:       return "Drop";
        case SectionType::Solo:       return "Solo";
        case SectionType::Interlude:  return "Interlude";
        case SectionType::Outro:      return "Outro";
        case SectionType::Tag:        return "Tag";
        case SectionType::Custom:     return "Custom";
        default:                      return "Section";
    }
}

inline juce::Colour getSectionTypeColor(SectionType type)
{
    switch (type)
    {
        case SectionType::Intro:      return juce::Colour(0xff4a90d9);  // Blue
        case SectionType::Verse:      return juce::Colour(0xff5cb85c);  // Green
        case SectionType::PreChorus:  return juce::Colour(0xff8bc34a);  // Light Green
        case SectionType::Chorus:     return juce::Colour(0xfff0ad4e);  // Orange
        case SectionType::PostChorus: return juce::Colour(0xffff9800);  // Deep Orange
        case SectionType::Bridge:     return juce::Colour(0xff9c27b0);  // Purple
        case SectionType::Breakdown:  return juce::Colour(0xff607d8b);  // Blue Grey
        case SectionType::Buildup:    return juce::Colour(0xffff5722);  // Deep Orange
        case SectionType::Drop:       return juce::Colour(0xfff44336);  // Red
        case SectionType::Solo:       return juce::Colour(0xffe91e63);  // Pink
        case SectionType::Interlude:  return juce::Colour(0xff00bcd4);  // Cyan
        case SectionType::Outro:      return juce::Colour(0xff795548);  // Brown
        case SectionType::Tag:        return juce::Colour(0xff9e9e9e);  // Grey
        case SectionType::Custom:     return juce::Colour(0xff673ab7);  // Deep Purple
        default:                      return juce::Colour(0xff9e9e9e);
    }
}

//==============================================================================
// Marker
//==============================================================================

struct Marker
{
    juce::String id;                // Unique identifier
    juce::String name;              // Display name
    MarkerType type = MarkerType::Generic;
    double positionBeats = 0.0;     // Position in beats
    juce::Colour color;

    // Optional data
    juce::String comment;
    bool isLocked = false;          // Prevent accidental editing

    Marker()
    {
        id = juce::Uuid().toString();
        color = juce::Colours::yellow;
    }

    Marker(const juce::String& markerName, double position, MarkerType markerType = MarkerType::Generic)
        : name(markerName), type(markerType), positionBeats(position)
    {
        id = juce::Uuid().toString();
        color = (type == MarkerType::LoopStart || type == MarkerType::LoopEnd)
                ? juce::Colours::cyan : juce::Colours::yellow;
    }

    juce::var toVar() const
    {
        juce::DynamicObject::Ptr obj = new juce::DynamicObject();
        obj->setProperty("id", id);
        obj->setProperty("name", name);
        obj->setProperty("type", static_cast<int>(type));
        obj->setProperty("position", positionBeats);
        obj->setProperty("color", static_cast<juce::int64>(color.getARGB()));
        obj->setProperty("comment", comment);
        obj->setProperty("locked", isLocked);
        return juce::var(obj.get());
    }

    static Marker fromVar(const juce::var& v)
    {
        Marker m;
        if (auto* obj = v.getDynamicObject())
        {
            m.id = obj->getProperty("id").toString();
            m.name = obj->getProperty("name").toString();
            m.type = static_cast<MarkerType>(static_cast<int>(obj->getProperty("type")));
            m.positionBeats = obj->getProperty("position");
            m.color = juce::Colour(static_cast<juce::uint32>(static_cast<juce::int64>(obj->getProperty("color"))));
            m.comment = obj->getProperty("comment").toString();
            m.isLocked = obj->getProperty("locked");
        }
        return m;
    }
};

//==============================================================================
// Arrangement Section
//==============================================================================

struct ArrangementSection
{
    juce::String id;
    juce::String name;
    SectionType type = SectionType::Custom;

    double startBeat = 0.0;
    double lengthBeats = 16.0;      // Default 4 bars

    juce::Colour color;

    // Musical info
    juce::String chordProgression;  // e.g., "Am - F - C - G"
    juce::String notes;             // User notes

    // Playback
    int repeatCount = 1;            // How many times to play this section
    bool isMuted = false;
    bool isSkipped = false;         // Skip during arranged playback

    ArrangementSection()
    {
        id = juce::Uuid().toString();
        color = getSectionTypeColor(type);
    }

    ArrangementSection(SectionType sectionType, double start, double length)
        : type(sectionType), startBeat(start), lengthBeats(length)
    {
        id = juce::Uuid().toString();
        name = getSectionTypeName(type);
        color = getSectionTypeColor(type);
    }

    double endBeat() const { return startBeat + lengthBeats; }

    juce::var toVar() const
    {
        juce::DynamicObject::Ptr obj = new juce::DynamicObject();
        obj->setProperty("id", id);
        obj->setProperty("name", name);
        obj->setProperty("type", static_cast<int>(type));
        obj->setProperty("start", startBeat);
        obj->setProperty("length", lengthBeats);
        obj->setProperty("color", static_cast<juce::int64>(color.getARGB()));
        obj->setProperty("chords", chordProgression);
        obj->setProperty("notes", notes);
        obj->setProperty("repeat", repeatCount);
        obj->setProperty("muted", isMuted);
        obj->setProperty("skipped", isSkipped);
        return juce::var(obj.get());
    }

    static ArrangementSection fromVar(const juce::var& v)
    {
        ArrangementSection s;
        if (auto* obj = v.getDynamicObject())
        {
            s.id = obj->getProperty("id").toString();
            s.name = obj->getProperty("name").toString();
            s.type = static_cast<SectionType>(static_cast<int>(obj->getProperty("type")));
            s.startBeat = obj->getProperty("start");
            s.lengthBeats = obj->getProperty("length");
            s.color = juce::Colour(static_cast<juce::uint32>(static_cast<juce::int64>(obj->getProperty("color"))));
            s.chordProgression = obj->getProperty("chords").toString();
            s.notes = obj->getProperty("notes").toString();
            s.repeatCount = obj->getProperty("repeat");
            s.isMuted = obj->getProperty("muted");
            s.isSkipped = obj->getProperty("skipped");
        }
        return s;
    }
};

//==============================================================================
// Tempo Change
//==============================================================================

struct TempoChange
{
    double positionBeats = 0.0;
    double bpm = 120.0;
    bool isRamp = false;            // Gradual tempo change
    double rampLengthBeats = 0.0;   // Length of ramp

    juce::var toVar() const
    {
        juce::DynamicObject::Ptr obj = new juce::DynamicObject();
        obj->setProperty("position", positionBeats);
        obj->setProperty("bpm", bpm);
        obj->setProperty("ramp", isRamp);
        obj->setProperty("rampLength", rampLengthBeats);
        return juce::var(obj.get());
    }

    static TempoChange fromVar(const juce::var& v)
    {
        TempoChange t;
        if (auto* obj = v.getDynamicObject())
        {
            t.positionBeats = obj->getProperty("position");
            t.bpm = obj->getProperty("bpm");
            t.isRamp = obj->getProperty("ramp");
            t.rampLengthBeats = obj->getProperty("rampLength");
        }
        return t;
    }
};

//==============================================================================
// Time Signature Change
//==============================================================================

struct TimeSignatureChange
{
    double positionBeats = 0.0;
    int numerator = 4;
    int denominator = 4;

    double beatsPerBar() const { return static_cast<double>(numerator); }

    juce::var toVar() const
    {
        juce::DynamicObject::Ptr obj = new juce::DynamicObject();
        obj->setProperty("position", positionBeats);
        obj->setProperty("num", numerator);
        obj->setProperty("denom", denominator);
        return juce::var(obj.get());
    }

    static TimeSignatureChange fromVar(const juce::var& v)
    {
        TimeSignatureChange t;
        if (auto* obj = v.getDynamicObject())
        {
            t.positionBeats = obj->getProperty("position");
            t.numerator = obj->getProperty("num");
            t.denominator = obj->getProperty("denom");
        }
        return t;
    }
};

//==============================================================================
// Arrangement Playback Order
//==============================================================================

struct ArrangementPlaybackItem
{
    juce::String sectionId;
    int playCount = 1;              // Times to play (for live arrangement)
    bool skip = false;
};

//==============================================================================
// Arranger Engine
//==============================================================================

class ArrangerEngine
{
public:
    using MarkerCallback = std::function<void(const Marker&)>;
    using SectionCallback = std::function<void(const ArrangementSection&)>;

    ArrangerEngine() = default;

    //==========================================================================
    // Marker Management
    //==========================================================================

    /** Add a marker */
    void addMarker(const Marker& marker)
    {
        markers[marker.id] = marker;
        sortMarkers();
        notifyMarkerChanged(marker);
    }

    /** Add marker at position */
    Marker& addMarkerAt(const juce::String& name, double positionBeats,
                        MarkerType type = MarkerType::Generic)
    {
        Marker m(name, positionBeats, type);
        markers[m.id] = m;
        sortMarkers();
        notifyMarkerChanged(m);
        return markers[m.id];
    }

    /** Remove marker */
    void removeMarker(const juce::String& id)
    {
        markers.erase(id);
    }

    /** Get marker by ID */
    Marker* getMarker(const juce::String& id)
    {
        auto it = markers.find(id);
        return (it != markers.end()) ? &it->second : nullptr;
    }

    /** Get all markers */
    std::vector<Marker> getAllMarkers() const
    {
        std::vector<Marker> result;
        for (const auto& [id, marker] : markers)
        {
            result.push_back(marker);
        }
        std::sort(result.begin(), result.end(),
                  [](const Marker& a, const Marker& b) { return a.positionBeats < b.positionBeats; });
        return result;
    }

    /** Get markers of specific type */
    std::vector<Marker> getMarkersOfType(MarkerType type) const
    {
        std::vector<Marker> result;
        for (const auto& [id, marker] : markers)
        {
            if (marker.type == type)
                result.push_back(marker);
        }
        return result;
    }

    /** Get marker at or before position */
    Marker* getMarkerAtOrBefore(double positionBeats)
    {
        Marker* found = nullptr;
        double bestPos = -1e10;

        for (auto& [id, marker] : markers)
        {
            if (marker.positionBeats <= positionBeats && marker.positionBeats > bestPos)
            {
                bestPos = marker.positionBeats;
                found = &marker;
            }
        }
        return found;
    }

    /** Get next marker after position */
    Marker* getNextMarker(double positionBeats)
    {
        Marker* found = nullptr;
        double bestPos = 1e10;

        for (auto& [id, marker] : markers)
        {
            if (marker.positionBeats > positionBeats && marker.positionBeats < bestPos)
            {
                bestPos = marker.positionBeats;
                found = &marker;
            }
        }
        return found;
    }

    /** Get previous marker before position */
    Marker* getPreviousMarker(double positionBeats)
    {
        Marker* found = nullptr;
        double bestPos = -1e10;

        for (auto& [id, marker] : markers)
        {
            if (marker.positionBeats < positionBeats && marker.positionBeats > bestPos)
            {
                bestPos = marker.positionBeats;
                found = &marker;
            }
        }
        return found;
    }

    //==========================================================================
    // Section Management
    //==========================================================================

    /** Add a section */
    void addSection(const ArrangementSection& section)
    {
        sections[section.id] = section;
        notifySectionChanged(section);
    }

    /** Create section at position */
    ArrangementSection& createSection(SectionType type, double startBeat, double lengthBeats)
    {
        ArrangementSection s(type, startBeat, lengthBeats);
        sections[s.id] = s;
        notifySectionChanged(s);
        return sections[s.id];
    }

    /** Remove section */
    void removeSection(const juce::String& id)
    {
        sections.erase(id);
    }

    /** Get section by ID */
    ArrangementSection* getSection(const juce::String& id)
    {
        auto it = sections.find(id);
        return (it != sections.end()) ? &it->second : nullptr;
    }

    /** Get all sections sorted by position */
    std::vector<ArrangementSection> getAllSections() const
    {
        std::vector<ArrangementSection> result;
        for (const auto& [id, section] : sections)
        {
            result.push_back(section);
        }
        std::sort(result.begin(), result.end(),
                  [](const ArrangementSection& a, const ArrangementSection& b)
                  { return a.startBeat < b.startBeat; });
        return result;
    }

    /** Get section at position */
    ArrangementSection* getSectionAt(double positionBeats)
    {
        for (auto& [id, section] : sections)
        {
            if (positionBeats >= section.startBeat && positionBeats < section.endBeat())
            {
                return &section;
            }
        }
        return nullptr;
    }

    /** Get sections of specific type */
    std::vector<ArrangementSection> getSectionsOfType(SectionType type) const
    {
        std::vector<ArrangementSection> result;
        for (const auto& [id, section] : sections)
        {
            if (section.type == type)
                result.push_back(section);
        }
        return result;
    }

    //==========================================================================
    // Tempo Track
    //==========================================================================

    /** Add tempo change */
    void addTempoChange(const TempoChange& change)
    {
        tempoChanges.push_back(change);
        std::sort(tempoChanges.begin(), tempoChanges.end(),
                  [](const TempoChange& a, const TempoChange& b)
                  { return a.positionBeats < b.positionBeats; });
    }

    /** Get tempo at position */
    double getTempoAt(double positionBeats) const
    {
        if (tempoChanges.empty())
            return defaultTempo;

        double tempo = defaultTempo;

        for (const auto& change : tempoChanges)
        {
            if (change.positionBeats <= positionBeats)
            {
                if (change.isRamp && change.rampLengthBeats > 0)
                {
                    // Interpolate during ramp
                    double rampProgress = (positionBeats - change.positionBeats) / change.rampLengthBeats;
                    rampProgress = std::clamp(rampProgress, 0.0, 1.0);

                    // Find next tempo
                    double nextTempo = change.bpm;
                    for (const auto& next : tempoChanges)
                    {
                        if (next.positionBeats > change.positionBeats)
                        {
                            nextTempo = next.bpm;
                            break;
                        }
                    }

                    tempo = tempo + (nextTempo - tempo) * rampProgress;
                }
                else
                {
                    tempo = change.bpm;
                }
            }
        }

        return tempo;
    }

    /** Get all tempo changes */
    const std::vector<TempoChange>& getTempoChanges() const { return tempoChanges; }

    void setDefaultTempo(double bpm) { defaultTempo = bpm; }
    double getDefaultTempo() const { return defaultTempo; }

    //==========================================================================
    // Time Signature Track
    //==========================================================================

    /** Add time signature change */
    void addTimeSignatureChange(const TimeSignatureChange& change)
    {
        timeSignatureChanges.push_back(change);
        std::sort(timeSignatureChanges.begin(), timeSignatureChanges.end(),
                  [](const TimeSignatureChange& a, const TimeSignatureChange& b)
                  { return a.positionBeats < b.positionBeats; });
    }

    /** Get time signature at position */
    TimeSignatureChange getTimeSignatureAt(double positionBeats) const
    {
        TimeSignatureChange current;
        current.numerator = defaultTimeSignatureNum;
        current.denominator = defaultTimeSignatureDenom;

        for (const auto& change : timeSignatureChanges)
        {
            if (change.positionBeats <= positionBeats)
            {
                current = change;
            }
        }

        return current;
    }

    void setDefaultTimeSignature(int num, int denom)
    {
        defaultTimeSignatureNum = num;
        defaultTimeSignatureDenom = denom;
    }

    //==========================================================================
    // Navigation
    //==========================================================================

    /** Jump to marker by name */
    double jumpToMarker(const juce::String& name) const
    {
        for (const auto& [id, marker] : markers)
        {
            if (marker.name.equalsIgnoreCase(name))
            {
                return marker.positionBeats;
            }
        }
        return -1.0;
    }

    /** Jump to section by name */
    double jumpToSection(const juce::String& name) const
    {
        for (const auto& [id, section] : sections)
        {
            if (section.name.equalsIgnoreCase(name))
            {
                return section.startBeat;
            }
        }
        return -1.0;
    }

    /** Jump to section by type */
    double jumpToSectionType(SectionType type, int occurrence = 0) const
    {
        int count = 0;
        auto sorted = getAllSections();

        for (const auto& section : sorted)
        {
            if (section.type == type)
            {
                if (count == occurrence)
                    return section.startBeat;
                count++;
            }
        }
        return -1.0;
    }

    //==========================================================================
    // Arrangement Playback
    //==========================================================================

    /** Get arranged playback order */
    std::vector<ArrangementPlaybackItem> getPlaybackOrder() const
    {
        std::vector<ArrangementPlaybackItem> order;
        auto sorted = getAllSections();

        for (const auto& section : sorted)
        {
            if (!section.isSkipped)
            {
                ArrangementPlaybackItem item;
                item.sectionId = section.id;
                item.playCount = section.repeatCount;
                order.push_back(item);
            }
        }

        return order;
    }

    /** Get total arranged length in beats */
    double getArrangedLength() const
    {
        double totalBeats = 0.0;
        auto sorted = getAllSections();

        for (const auto& section : sorted)
        {
            if (!section.isSkipped)
            {
                totalBeats += section.lengthBeats * section.repeatCount;
            }
        }

        return totalBeats;
    }

    /** Convert arranged position to linear position */
    double arrangedToLinear(double arrangedPosition) const
    {
        double accumulatedArranged = 0.0;
        auto sorted = getAllSections();

        for (const auto& section : sorted)
        {
            if (section.isSkipped)
                continue;

            double sectionTotalLength = section.lengthBeats * section.repeatCount;

            if (arrangedPosition < accumulatedArranged + sectionTotalLength)
            {
                // Position is within this section
                double posInSection = arrangedPosition - accumulatedArranged;
                double repeatOffset = std::fmod(posInSection, section.lengthBeats);
                return section.startBeat + repeatOffset;
            }

            accumulatedArranged += sectionTotalLength;
        }

        // Beyond arrangement
        return arrangedPosition;
    }

    //==========================================================================
    // Templates
    //==========================================================================

    /** Apply arrangement template */
    void applyTemplate(const juce::String& templateName)
    {
        sections.clear();

        if (templateName == "Pop Song")
        {
            createSection(SectionType::Intro, 0, 8);
            createSection(SectionType::Verse, 8, 16);
            createSection(SectionType::PreChorus, 24, 8);
            createSection(SectionType::Chorus, 32, 16);
            createSection(SectionType::Verse, 48, 16);
            createSection(SectionType::PreChorus, 64, 8);
            createSection(SectionType::Chorus, 72, 16);
            createSection(SectionType::Bridge, 88, 8);
            createSection(SectionType::Chorus, 96, 16);
            createSection(SectionType::Outro, 112, 8);
        }
        else if (templateName == "EDM Drop")
        {
            createSection(SectionType::Intro, 0, 16);
            createSection(SectionType::Buildup, 16, 16);
            createSection(SectionType::Drop, 32, 32);
            createSection(SectionType::Breakdown, 64, 16);
            createSection(SectionType::Buildup, 80, 16);
            createSection(SectionType::Drop, 96, 32);
            createSection(SectionType::Outro, 128, 16);
        }
        else if (templateName == "Verse-Chorus")
        {
            createSection(SectionType::Intro, 0, 8);
            createSection(SectionType::Verse, 8, 16);
            createSection(SectionType::Chorus, 24, 16);
            createSection(SectionType::Verse, 40, 16);
            createSection(SectionType::Chorus, 56, 16);
            createSection(SectionType::Outro, 72, 8);
        }
        else if (templateName == "AABA")
        {
            auto& a1 = createSection(SectionType::Verse, 0, 16);
            a1.name = "A (Verse 1)";
            auto& a2 = createSection(SectionType::Verse, 16, 16);
            a2.name = "A (Verse 2)";
            auto& b = createSection(SectionType::Bridge, 32, 16);
            b.name = "B (Bridge)";
            auto& a3 = createSection(SectionType::Verse, 48, 16);
            a3.name = "A (Verse 3)";
        }
    }

    std::vector<juce::String> getAvailableTemplates() const
    {
        return {"Pop Song", "EDM Drop", "Verse-Chorus", "AABA"};
    }

    //==========================================================================
    // State Management
    //==========================================================================

    juce::var getState() const
    {
        juce::DynamicObject::Ptr state = new juce::DynamicObject();

        // Markers
        juce::Array<juce::var> markerArray;
        for (const auto& [id, marker] : markers)
        {
            markerArray.add(marker.toVar());
        }
        state->setProperty("markers", markerArray);

        // Sections
        juce::Array<juce::var> sectionArray;
        for (const auto& [id, section] : sections)
        {
            sectionArray.add(section.toVar());
        }
        state->setProperty("sections", sectionArray);

        // Tempo changes
        juce::Array<juce::var> tempoArray;
        for (const auto& tempo : tempoChanges)
        {
            tempoArray.add(tempo.toVar());
        }
        state->setProperty("tempoChanges", tempoArray);

        // Time signature changes
        juce::Array<juce::var> tsArray;
        for (const auto& ts : timeSignatureChanges)
        {
            tsArray.add(ts.toVar());
        }
        state->setProperty("timeSignatureChanges", tsArray);

        // Defaults
        state->setProperty("defaultTempo", defaultTempo);
        state->setProperty("defaultTSNum", defaultTimeSignatureNum);
        state->setProperty("defaultTSDenom", defaultTimeSignatureDenom);

        return juce::var(state.get());
    }

    void restoreState(const juce::var& state)
    {
        if (auto* obj = state.getDynamicObject())
        {
            markers.clear();
            sections.clear();
            tempoChanges.clear();
            timeSignatureChanges.clear();

            // Restore markers
            if (auto* markerArray = obj->getProperty("markers").getArray())
            {
                for (const auto& m : *markerArray)
                {
                    Marker marker = Marker::fromVar(m);
                    markers[marker.id] = marker;
                }
            }

            // Restore sections
            if (auto* sectionArray = obj->getProperty("sections").getArray())
            {
                for (const auto& s : *sectionArray)
                {
                    ArrangementSection section = ArrangementSection::fromVar(s);
                    sections[section.id] = section;
                }
            }

            // Restore tempo changes
            if (auto* tempoArray = obj->getProperty("tempoChanges").getArray())
            {
                for (const auto& t : *tempoArray)
                {
                    tempoChanges.push_back(TempoChange::fromVar(t));
                }
            }

            // Restore time signatures
            if (auto* tsArray = obj->getProperty("timeSignatureChanges").getArray())
            {
                for (const auto& t : *tsArray)
                {
                    timeSignatureChanges.push_back(TimeSignatureChange::fromVar(t));
                }
            }

            // Restore defaults
            defaultTempo = obj->getProperty("defaultTempo");
            defaultTimeSignatureNum = obj->getProperty("defaultTSNum");
            defaultTimeSignatureDenom = obj->getProperty("defaultTSDenom");
        }
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setMarkerCallback(MarkerCallback cb) { markerCallback = cb; }
    void setSectionCallback(SectionCallback cb) { sectionCallback = cb; }

    //==========================================================================
    // Clear
    //==========================================================================

    void clear()
    {
        markers.clear();
        sections.clear();
        tempoChanges.clear();
        timeSignatureChanges.clear();
    }

private:
    std::map<juce::String, Marker> markers;
    std::map<juce::String, ArrangementSection> sections;

    std::vector<TempoChange> tempoChanges;
    std::vector<TimeSignatureChange> timeSignatureChanges;

    double defaultTempo = 120.0;
    int defaultTimeSignatureNum = 4;
    int defaultTimeSignatureDenom = 4;

    MarkerCallback markerCallback;
    SectionCallback sectionCallback;

    void sortMarkers()
    {
        // Markers are stored in map, sorted access via getAllMarkers()
    }

    void notifyMarkerChanged(const Marker& marker)
    {
        if (markerCallback)
            markerCallback(marker);
    }

    void notifySectionChanged(const ArrangementSection& section)
    {
        if (sectionCallback)
            sectionCallback(section);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ArrangerEngine)
};

} // namespace Echoelmusic
