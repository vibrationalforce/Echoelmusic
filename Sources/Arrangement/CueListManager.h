/*
  ==============================================================================

    CueListManager.h
    Created: 2026
    Author:  Echoelmusic

    Professional Cue List Manager for Navigation and Live Performance
    Supports markers, memory locations, and show control

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>
#include <functional>

namespace Echoelmusic {
namespace Arrangement {

//==============================================================================
/** Cue type */
enum class CueType {
    Marker,         // Simple position marker
    MemoryLocation, // Named location for quick recall
    LoopStart,      // Loop region start
    LoopEnd,        // Loop region end
    RegionStart,    // Selection/region start
    RegionEnd,      // Selection/region end
    PunchIn,        // Punch recording in point
    PunchOut,       // Punch recording out point
    TempoChange,    // Tempo marker
    TimeSignature,  // Time signature change
    KeyChange,      // Key signature change
    ChapterMarker,  // For export/podcast chapters
    Action          // Trigger an action (MIDI, OSC, etc.)
};

inline juce::String cueTypeToString(CueType type) {
    switch (type) {
        case CueType::Marker:         return "Marker";
        case CueType::MemoryLocation: return "Memory";
        case CueType::LoopStart:      return "Loop Start";
        case CueType::LoopEnd:        return "Loop End";
        case CueType::RegionStart:    return "Region Start";
        case CueType::RegionEnd:      return "Region End";
        case CueType::PunchIn:        return "Punch In";
        case CueType::PunchOut:       return "Punch Out";
        case CueType::TempoChange:    return "Tempo";
        case CueType::TimeSignature:  return "Time Sig";
        case CueType::KeyChange:      return "Key";
        case CueType::ChapterMarker:  return "Chapter";
        case CueType::Action:         return "Action";
        default:                      return "Unknown";
    }
}

//==============================================================================
/** Action trigger for cue points */
struct CueAction {
    enum class ActionType {
        None,
        SendMIDI,
        SendOSC,
        ExecuteScript,
        TriggerClip,
        ChangeScene
    };

    ActionType type = ActionType::None;
    juce::String target;        // MIDI channel, OSC address, script path
    juce::String command;       // Command/message to send
    juce::var parameters;       // Additional parameters

    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("type", static_cast<int>(type));
        obj->setProperty("target", target);
        obj->setProperty("command", command);
        obj->setProperty("params", parameters);
        return juce::var(obj);
    }

    static CueAction fromVar(const juce::var& v) {
        CueAction action;
        if (auto* obj = v.getDynamicObject()) {
            action.type = static_cast<ActionType>(int(obj->getProperty("type")));
            action.target = obj->getProperty("target").toString();
            action.command = obj->getProperty("command").toString();
            action.parameters = obj->getProperty("params");
        }
        return action;
    }
};

//==============================================================================
/** Single cue point */
class CuePoint {
public:
    CuePoint(double timeSeconds = 0.0, const juce::String& name = "")
        : time_(timeSeconds)
        , name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    juce::String getId() const { return id_; }

    double getTime() const { return time_; }
    void setTime(double time) { time_ = std::max(0.0, time); }

    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    CueType getType() const { return type_; }
    void setType(CueType type) { type_ = type; }

    //==============================================================================
    // Time display
    juce::String getTimeString(double bpm = 120.0, int beatsPerBar = 4) const {
        // Format: Bars:Beats:Ticks or Minutes:Seconds:Frames
        if (useBarsBeatsTicks_) {
            double beatsPerSecond = bpm / 60.0;
            double totalBeats = time_ * beatsPerSecond;
            int bars = static_cast<int>(totalBeats / beatsPerBar) + 1;
            int beats = static_cast<int>(std::fmod(totalBeats, beatsPerBar)) + 1;
            int ticks = static_cast<int>(std::fmod(totalBeats * 960, 960));
            return juce::String::formatted("%d|%d|%03d", bars, beats, ticks);
        } else {
            int minutes = static_cast<int>(time_) / 60;
            int seconds = static_cast<int>(time_) % 60;
            int frames = static_cast<int>((time_ - std::floor(time_)) * 30); // 30fps
            return juce::String::formatted("%02d:%02d:%02d", minutes, seconds, frames);
        }
    }

    void setUseBarsBeatsTicks(bool use) { useBarsBeatsTicks_ = use; }

    //==============================================================================
    // Visual properties
    juce::Colour getColour() const { return colour_; }
    void setColour(juce::Colour colour) { colour_ = colour; }

    juce::String getComment() const { return comment_; }
    void setComment(const juce::String& comment) { comment_ = comment; }

    //==============================================================================
    // Region support (for loop/region cues)
    double getEndTime() const { return endTime_; }
    void setEndTime(double time) { endTime_ = time; }

    double getDuration() const { return endTime_ > time_ ? endTime_ - time_ : 0.0; }

    bool isRegion() const {
        return type_ == CueType::LoopStart || type_ == CueType::RegionStart ||
               endTime_ > time_;
    }

    //==============================================================================
    // Action trigger
    CueAction& getAction() { return action_; }
    const CueAction& getAction() const { return action_; }

    //==============================================================================
    // Lock state
    bool isLocked() const { return locked_; }
    void setLocked(bool locked) { locked_ = locked; }

    //==============================================================================
    // Number for quick access (1-9, 0)
    int getNumber() const { return number_; }
    void setNumber(int num) { number_ = juce::jlimit(0, 99, num); }

    //==============================================================================
    // Serialization
    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("id", id_);
        obj->setProperty("time", time_);
        obj->setProperty("endTime", endTime_);
        obj->setProperty("name", name_);
        obj->setProperty("type", static_cast<int>(type_));
        obj->setProperty("colour", colour_.toString());
        obj->setProperty("comment", comment_);
        obj->setProperty("number", number_);
        obj->setProperty("locked", locked_);
        obj->setProperty("action", action_.toVar());
        return juce::var(obj);
    }

    static std::unique_ptr<CuePoint> fromVar(const juce::var& v) {
        auto cue = std::make_unique<CuePoint>();
        if (auto* obj = v.getDynamicObject()) {
            cue->id_ = obj->getProperty("id").toString();
            cue->time_ = obj->getProperty("time");
            cue->endTime_ = obj->getProperty("endTime");
            cue->name_ = obj->getProperty("name").toString();
            cue->type_ = static_cast<CueType>(int(obj->getProperty("type")));
            cue->colour_ = juce::Colour::fromString(obj->getProperty("colour").toString());
            cue->comment_ = obj->getProperty("comment").toString();
            cue->number_ = obj->getProperty("number");
            cue->locked_ = obj->getProperty("locked");
            cue->action_ = CueAction::fromVar(obj->getProperty("action"));
        }
        return cue;
    }

private:
    juce::String id_;
    double time_ = 0.0;
    double endTime_ = 0.0;
    juce::String name_;
    CueType type_ = CueType::Marker;
    juce::Colour colour_ = juce::Colours::yellow;
    juce::String comment_;
    int number_ = 0;
    bool locked_ = false;
    bool useBarsBeatsTicks_ = true;
    CueAction action_;
};

//==============================================================================
/** Cue list (collection of related cues) */
class CueList {
public:
    CueList(const juce::String& name = "Main")
        : name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    juce::String getId() const { return id_; }
    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    //==============================================================================
    /** Add cue point */
    CuePoint* addCue(double time, const juce::String& name = "") {
        auto cue = std::make_unique<CuePoint>(time, name);
        CuePoint* ptr = cue.get();
        cues_.push_back(std::move(cue));
        sortCues();
        return ptr;
    }

    /** Add existing cue */
    void addCue(std::unique_ptr<CuePoint> cue) {
        cues_.push_back(std::move(cue));
        sortCues();
    }

    /** Remove cue by ID */
    void removeCue(const juce::String& id) {
        cues_.erase(
            std::remove_if(cues_.begin(), cues_.end(),
                           [&id](const auto& cue) { return cue->getId() == id; }),
            cues_.end());
    }

    /** Get cue by ID */
    CuePoint* getCue(const juce::String& id) {
        for (auto& cue : cues_) {
            if (cue->getId() == id) return cue.get();
        }
        return nullptr;
    }

    /** Get cue by number */
    CuePoint* getCueByNumber(int number) {
        for (auto& cue : cues_) {
            if (cue->getNumber() == number) return cue.get();
        }
        return nullptr;
    }

    /** Get all cues */
    std::vector<CuePoint*> getAllCues() {
        std::vector<CuePoint*> result;
        for (auto& cue : cues_) {
            result.push_back(cue.get());
        }
        return result;
    }

    /** Get cues by type */
    std::vector<CuePoint*> getCuesByType(CueType type) {
        std::vector<CuePoint*> result;
        for (auto& cue : cues_) {
            if (cue->getType() == type) {
                result.push_back(cue.get());
            }
        }
        return result;
    }

    /** Get cue at or before time */
    CuePoint* getCueAtOrBefore(double time) {
        CuePoint* result = nullptr;
        for (auto& cue : cues_) {
            if (cue->getTime() <= time) {
                result = cue.get();
            } else {
                break;
            }
        }
        return result;
    }

    /** Get cue after time */
    CuePoint* getCueAfter(double time) {
        for (auto& cue : cues_) {
            if (cue->getTime() > time) {
                return cue.get();
            }
        }
        return nullptr;
    }

    /** Get cues in time range */
    std::vector<CuePoint*> getCuesInRange(double startTime, double endTime) {
        std::vector<CuePoint*> result;
        for (auto& cue : cues_) {
            if (cue->getTime() >= startTime && cue->getTime() <= endTime) {
                result.push_back(cue.get());
            }
        }
        return result;
    }

    //==============================================================================
    int getNumCues() const { return static_cast<int>(cues_.size()); }

    void clear() { cues_.clear(); }

    void sortCues() {
        std::sort(cues_.begin(), cues_.end(),
                  [](const auto& a, const auto& b) {
                      return a->getTime() < b->getTime();
                  });
    }

private:
    juce::String id_;
    juce::String name_;
    std::vector<std::unique_ptr<CuePoint>> cues_;
};

//==============================================================================
/** Main Cue List Manager */
class CueListManager {
public:
    CueListManager() {
        // Create default cue list
        defaultList_ = createList("Main");
    }

    //==============================================================================
    /** Create new cue list */
    CueList* createList(const juce::String& name) {
        auto list = std::make_unique<CueList>(name);
        CueList* ptr = list.get();
        lists_[list->getId()] = std::move(list);
        return ptr;
    }

    /** Get list by ID */
    CueList* getList(const juce::String& id) {
        auto it = lists_.find(id);
        return it != lists_.end() ? it->second.get() : nullptr;
    }

    /** Get all lists */
    std::vector<CueList*> getAllLists() {
        std::vector<CueList*> result;
        for (auto& pair : lists_) {
            result.push_back(pair.second.get());
        }
        return result;
    }

    /** Get default list */
    CueList* getDefaultList() { return defaultList_; }

    //==============================================================================
    /** Quick marker creation on default list */
    CuePoint* addMarker(double time, const juce::String& name = "") {
        if (defaultList_) {
            auto* cue = defaultList_->addCue(time, name);
            cue->setType(CueType::Marker);
            if (onCueAdded) onCueAdded(cue);
            return cue;
        }
        return nullptr;
    }

    /** Quick memory location creation */
    CuePoint* addMemoryLocation(double time, const juce::String& name, int number) {
        if (defaultList_) {
            auto* cue = defaultList_->addCue(time, name);
            cue->setType(CueType::MemoryLocation);
            cue->setNumber(number);
            if (onCueAdded) onCueAdded(cue);
            return cue;
        }
        return nullptr;
    }

    /** Create loop region */
    std::pair<CuePoint*, CuePoint*> createLoopRegion(double startTime, double endTime,
                                                       const juce::String& name = "Loop") {
        CuePoint* startCue = nullptr;
        CuePoint* endCue = nullptr;

        if (defaultList_) {
            startCue = defaultList_->addCue(startTime, name + " Start");
            startCue->setType(CueType::LoopStart);
            startCue->setEndTime(endTime);

            endCue = defaultList_->addCue(endTime, name + " End");
            endCue->setType(CueType::LoopEnd);
        }

        return {startCue, endCue};
    }

    //==============================================================================
    /** Navigate to cue */
    void gotoCue(CuePoint* cue) {
        if (cue && onNavigate) {
            onNavigate(cue->getTime());
        }
    }

    /** Navigate to numbered memory location */
    void gotoMemoryLocation(int number) {
        if (defaultList_) {
            if (auto* cue = defaultList_->getCueByNumber(number)) {
                gotoCue(cue);
            }
        }
    }

    /** Navigate to next cue */
    void gotoNextCue(double currentTime) {
        if (defaultList_) {
            if (auto* cue = defaultList_->getCueAfter(currentTime)) {
                gotoCue(cue);
            }
        }
    }

    /** Navigate to previous cue */
    void gotoPreviousCue(double currentTime) {
        if (defaultList_) {
            auto cues = defaultList_->getAllCues();
            CuePoint* prev = nullptr;

            for (auto* cue : cues) {
                if (cue->getTime() >= currentTime - 0.1) {
                    break;
                }
                prev = cue;
            }

            if (prev) gotoCue(prev);
        }
    }

    //==============================================================================
    /** Trigger cue actions at time */
    void triggerActionsAtTime(double time, double tolerance = 0.01) {
        if (!defaultList_) return;

        for (auto* cue : defaultList_->getAllCues()) {
            if (std::abs(cue->getTime() - time) <= tolerance) {
                executeAction(cue->getAction());
            }
        }
    }

    /** Execute cue action */
    void executeAction(const CueAction& action) {
        switch (action.type) {
            case CueAction::ActionType::SendMIDI:
                if (onSendMIDI) onSendMIDI(action.target, action.command);
                break;

            case CueAction::ActionType::SendOSC:
                if (onSendOSC) onSendOSC(action.target, action.command);
                break;

            case CueAction::ActionType::ExecuteScript:
                if (onExecuteScript) onExecuteScript(action.command);
                break;

            case CueAction::ActionType::TriggerClip:
                if (onTriggerClip) onTriggerClip(action.target);
                break;

            case CueAction::ActionType::ChangeScene:
                if (onChangeScene) onChangeScene(action.target);
                break;

            default:
                break;
        }
    }

    //==============================================================================
    /** Export markers to various formats */
    juce::String exportToCSV() {
        juce::String csv = "Number,Name,Time,Type,Comment\n";

        if (defaultList_) {
            for (auto* cue : defaultList_->getAllCues()) {
                csv += juce::String(cue->getNumber()) + ",";
                csv += "\"" + cue->getName() + "\",";
                csv += juce::String(cue->getTime(), 3) + ",";
                csv += cueTypeToString(cue->getType()) + ",";
                csv += "\"" + cue->getComment() + "\"\n";
            }
        }

        return csv;
    }

    /** Export for chapter markers (podcast/video) */
    juce::String exportChapters() {
        juce::String chapters;

        if (defaultList_) {
            for (auto* cue : defaultList_->getCuesByType(CueType::ChapterMarker)) {
                int minutes = static_cast<int>(cue->getTime()) / 60;
                int seconds = static_cast<int>(cue->getTime()) % 60;
                chapters += juce::String::formatted("%02d:%02d ", minutes, seconds);
                chapters += cue->getName() + "\n";
            }
        }

        return chapters;
    }

    //==============================================================================
    /** Save to file */
    bool saveToFile(const juce::File& file) {
        juce::var listsArray;

        for (auto& pair : lists_) {
            auto listObj = new juce::DynamicObject();
            listObj->setProperty("id", pair.second->getId());
            listObj->setProperty("name", pair.second->getName());

            juce::var cuesArray;
            for (auto* cue : pair.second->getAllCues()) {
                cuesArray.append(cue->toVar());
            }
            listObj->setProperty("cues", cuesArray);

            listsArray.append(juce::var(listObj));
        }

        auto root = new juce::DynamicObject();
        root->setProperty("version", 1);
        root->setProperty("lists", listsArray);

        juce::FileOutputStream stream(file);
        if (stream.openedOk()) {
            juce::JSON::writeToStream(stream, juce::var(root));
            return true;
        }
        return false;
    }

    /** Load from file */
    bool loadFromFile(const juce::File& file) {
        if (!file.existsAsFile()) return false;

        juce::var data = juce::JSON::parse(file);
        if (!data.isObject()) return false;

        auto* root = data.getDynamicObject();
        if (!root) return false;

        lists_.clear();

        if (auto* listsArray = root->getProperty("lists").getArray()) {
            for (const auto& listVar : *listsArray) {
                if (auto* listObj = listVar.getDynamicObject()) {
                    auto list = std::make_unique<CueList>(
                        listObj->getProperty("name").toString());

                    if (auto* cuesArray = listObj->getProperty("cues").getArray()) {
                        for (const auto& cueVar : *cuesArray) {
                            list->addCue(CuePoint::fromVar(cueVar));
                        }
                    }

                    lists_[list->getId()] = std::move(list);
                }
            }
        }

        // Restore default list
        if (!lists_.empty()) {
            defaultList_ = lists_.begin()->second.get();
        } else {
            defaultList_ = createList("Main");
        }

        return true;
    }

    //==============================================================================
    // Callbacks
    std::function<void(double)> onNavigate;
    std::function<void(CuePoint*)> onCueAdded;
    std::function<void(const juce::String&, const juce::String&)> onSendMIDI;
    std::function<void(const juce::String&, const juce::String&)> onSendOSC;
    std::function<void(const juce::String&)> onExecuteScript;
    std::function<void(const juce::String&)> onTriggerClip;
    std::function<void(const juce::String&)> onChangeScene;

private:
    std::map<juce::String, std::unique_ptr<CueList>> lists_;
    CueList* defaultList_ = nullptr;
};

//==============================================================================
/** Cue List UI Component */
class CueListComponent : public juce::Component,
                         public juce::TableListBoxModel {
public:
    CueListComponent(CueListManager& manager)
        : manager_(manager)
    {
        table_.setModel(this);
        table_.getHeader().addColumn("Num", 1, 40);
        table_.getHeader().addColumn("Name", 2, 150);
        table_.getHeader().addColumn("Time", 3, 100);
        table_.getHeader().addColumn("Type", 4, 80);
        addAndMakeVisible(table_);

        setSize(400, 300);
    }

    void resized() override {
        table_.setBounds(getLocalBounds());
    }

    int getNumRows() override {
        if (auto* list = manager_.getDefaultList()) {
            return list->getNumCues();
        }
        return 0;
    }

    void paintRowBackground(juce::Graphics& g, int rowNumber,
                           int /*width*/, int /*height*/,
                           bool rowIsSelected) override {
        if (rowIsSelected) {
            g.fillAll(juce::Colours::lightblue);
        } else if (rowNumber % 2) {
            g.fillAll(juce::Colours::grey.withAlpha(0.1f));
        }
    }

    void paintCell(juce::Graphics& g, int rowNumber, int columnId,
                   int width, int height, bool /*rowIsSelected*/) override {
        auto* list = manager_.getDefaultList();
        if (!list) return;

        auto cues = list->getAllCues();
        if (rowNumber >= static_cast<int>(cues.size())) return;

        auto* cue = cues[rowNumber];
        g.setColour(juce::Colours::white);

        juce::String text;
        switch (columnId) {
            case 1: text = juce::String(cue->getNumber()); break;
            case 2: text = cue->getName(); break;
            case 3: text = cue->getTimeString(); break;
            case 4: text = cueTypeToString(cue->getType()); break;
        }

        g.drawText(text, 4, 0, width - 8, height, juce::Justification::centredLeft);

        // Color indicator
        if (columnId == 2) {
            g.setColour(cue->getColour());
            g.fillRect(0, 2, 3, height - 4);
        }
    }

    void cellDoubleClicked(int rowNumber, int /*columnId*/,
                           const juce::MouseEvent&) override {
        auto* list = manager_.getDefaultList();
        if (!list) return;

        auto cues = list->getAllCues();
        if (rowNumber < static_cast<int>(cues.size())) {
            manager_.gotoCue(cues[rowNumber]);
        }
    }

    void refresh() {
        table_.updateContent();
    }

private:
    CueListManager& manager_;
    juce::TableListBox table_;
};

} // namespace Arrangement
} // namespace Echoelmusic
