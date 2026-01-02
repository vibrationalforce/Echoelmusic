/*
  ==============================================================================

    CompingManager.h
    Created: 2026
    Author:  Echoelmusic

    Professional Comping System for Multi-Take Management
    Supports loop recording, take lanes, swipe comping, and crossfades

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>
#include <optional>
#include <functional>

namespace Echoelmusic {
namespace Audio {

//==============================================================================
/** Take rating for organization */
enum class TakeRating {
    None,
    Poor,
    Fair,
    Good,
    Great,
    Perfect
};

inline juce::String takeRatingToString(TakeRating rating) {
    switch (rating) {
        case TakeRating::None:    return "None";
        case TakeRating::Poor:    return "Poor";
        case TakeRating::Fair:    return "Fair";
        case TakeRating::Good:    return "Good";
        case TakeRating::Great:   return "Great";
        case TakeRating::Perfect: return "Perfect";
        default:                  return "";
    }
}

inline juce::Colour takeRatingToColour(TakeRating rating) {
    switch (rating) {
        case TakeRating::Poor:    return juce::Colours::red;
        case TakeRating::Fair:    return juce::Colours::orange;
        case TakeRating::Good:    return juce::Colours::yellow;
        case TakeRating::Great:   return juce::Colours::lightgreen;
        case TakeRating::Perfect: return juce::Colours::green;
        default:                  return juce::Colours::grey;
    }
}

//==============================================================================
/** Single recording take */
class Take {
public:
    Take(int takeNumber, double startTime, double endTime)
        : takeNumber_(takeNumber)
        , startTime_(startTime)
        , endTime_(endTime)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    // Basic properties
    juce::String getId() const { return id_; }
    int getTakeNumber() const { return takeNumber_; }
    double getStartTime() const { return startTime_; }
    double getEndTime() const { return endTime_; }
    double getDuration() const { return endTime_ - startTime_; }

    //==============================================================================
    // Audio data
    void setAudioData(const juce::AudioBuffer<float>& buffer, double sampleRate) {
        audioBuffer_ = buffer;
        sampleRate_ = sampleRate;
    }

    const juce::AudioBuffer<float>& getAudioBuffer() const { return audioBuffer_; }
    double getSampleRate() const { return sampleRate_; }

    //==============================================================================
    // Metadata
    void setRating(TakeRating rating) { rating_ = rating; }
    TakeRating getRating() const { return rating_; }

    void setName(const juce::String& name) { name_ = name; }
    juce::String getName() const {
        if (name_.isEmpty()) {
            return "Take " + juce::String(takeNumber_);
        }
        return name_;
    }

    void setNotes(const juce::String& notes) { notes_ = notes; }
    juce::String getNotes() const { return notes_; }

    void setColour(juce::Colour colour) { colour_ = colour; }
    juce::Colour getColour() const { return colour_; }

    //==============================================================================
    // State
    void setMuted(bool muted) { muted_ = muted; }
    bool isMuted() const { return muted_; }

    void setSelected(bool selected) { selected_ = selected; }
    bool isSelected() const { return selected_; }

    //==============================================================================
    // Serialization
    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("id", id_);
        obj->setProperty("takeNumber", takeNumber_);
        obj->setProperty("startTime", startTime_);
        obj->setProperty("endTime", endTime_);
        obj->setProperty("rating", static_cast<int>(rating_));
        obj->setProperty("name", name_);
        obj->setProperty("notes", notes_);
        obj->setProperty("muted", muted_);
        return juce::var(obj);
    }

    static std::unique_ptr<Take> fromVar(const juce::var& v) {
        if (auto* obj = v.getDynamicObject()) {
            auto take = std::make_unique<Take>(
                obj->getProperty("takeNumber"),
                obj->getProperty("startTime"),
                obj->getProperty("endTime"));
            take->id_ = obj->getProperty("id").toString();
            take->rating_ = static_cast<TakeRating>(int(obj->getProperty("rating")));
            take->name_ = obj->getProperty("name").toString();
            take->notes_ = obj->getProperty("notes").toString();
            take->muted_ = obj->getProperty("muted");
            return take;
        }
        return nullptr;
    }

private:
    juce::String id_;
    int takeNumber_;
    double startTime_;
    double endTime_;

    juce::AudioBuffer<float> audioBuffer_;
    double sampleRate_ = 44100.0;

    TakeRating rating_ = TakeRating::None;
    juce::String name_;
    juce::String notes_;
    juce::Colour colour_ = juce::Colours::lightblue;

    bool muted_ = false;
    bool selected_ = false;
};

//==============================================================================
/** Comp segment - a selected region from a take */
struct CompSegment {
    juce::String takeId;
    double startTime;       // Start time in comp
    double endTime;         // End time in comp
    double takeStartTime;   // Offset within the take
    double fadeInLength = 0.01;   // Crossfade in (seconds)
    double fadeOutLength = 0.01;  // Crossfade out (seconds)

    double getDuration() const { return endTime - startTime; }

    bool overlaps(const CompSegment& other) const {
        return startTime < other.endTime && endTime > other.startTime;
    }

    bool contains(double time) const {
        return time >= startTime && time < endTime;
    }
};

//==============================================================================
/** Crossfade shape */
enum class CrossfadeShape {
    Linear,
    EqualPower,
    SCurve,
    Exponential,
    Logarithmic
};

//==============================================================================
/** Crossfade calculator */
class CrossfadeCalculator {
public:
    static float calculateGain(float position, CrossfadeShape shape, bool fadeIn) {
        // Position: 0.0 = start, 1.0 = end
        float gain = 0.0f;

        switch (shape) {
            case CrossfadeShape::Linear:
                gain = fadeIn ? position : (1.0f - position);
                break;

            case CrossfadeShape::EqualPower:
                if (fadeIn) {
                    gain = std::sin(position * juce::MathConstants<float>::halfPi);
                } else {
                    gain = std::cos(position * juce::MathConstants<float>::halfPi);
                }
                break;

            case CrossfadeShape::SCurve:
                // Hermite S-curve
                if (fadeIn) {
                    gain = position * position * (3.0f - 2.0f * position);
                } else {
                    float t = 1.0f - position;
                    gain = t * t * (3.0f - 2.0f * t);
                }
                break;

            case CrossfadeShape::Exponential:
                if (fadeIn) {
                    gain = std::pow(position, 2.0f);
                } else {
                    gain = std::pow(1.0f - position, 2.0f);
                }
                break;

            case CrossfadeShape::Logarithmic:
                if (fadeIn) {
                    gain = std::sqrt(position);
                } else {
                    gain = std::sqrt(1.0f - position);
                }
                break;
        }

        return juce::jlimit(0.0f, 1.0f, gain);
    }
};

//==============================================================================
/** Complete comp from multiple takes */
class Comp {
public:
    Comp(const juce::String& name = "Comp")
        : name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    juce::String getId() const { return id_; }
    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    //==============================================================================
    /** Add a segment to the comp */
    void addSegment(const CompSegment& segment) {
        // Remove any overlapping segments
        removeOverlappingSegments(segment.startTime, segment.endTime);

        segments_.push_back(segment);

        // Sort by start time
        std::sort(segments_.begin(), segments_.end(),
                  [](const CompSegment& a, const CompSegment& b) {
                      return a.startTime < b.startTime;
                  });

        updateCrossfades();
    }

    /** Remove segment at time */
    void removeSegmentAt(double time) {
        segments_.erase(
            std::remove_if(segments_.begin(), segments_.end(),
                           [time](const CompSegment& s) { return s.contains(time); }),
            segments_.end());
    }

    /** Remove overlapping segments */
    void removeOverlappingSegments(double start, double end) {
        segments_.erase(
            std::remove_if(segments_.begin(), segments_.end(),
                           [start, end](const CompSegment& s) {
                               return s.startTime < end && s.endTime > start;
                           }),
            segments_.end());
    }

    /** Get all segments */
    const std::vector<CompSegment>& getSegments() const { return segments_; }

    /** Get segment at time */
    std::optional<CompSegment> getSegmentAt(double time) const {
        for (const auto& segment : segments_) {
            if (segment.contains(time)) {
                return segment;
            }
        }
        return std::nullopt;
    }

    //==============================================================================
    /** Set crossfade shape */
    void setCrossfadeShape(CrossfadeShape shape) { crossfadeShape_ = shape; }
    CrossfadeShape getCrossfadeShape() const { return crossfadeShape_; }

    /** Set default crossfade length */
    void setDefaultCrossfadeLength(double seconds) {
        defaultCrossfadeLength_ = seconds;
    }

    //==============================================================================
    /** Clear all segments */
    void clear() {
        segments_.clear();
    }

    /** Get total duration */
    double getDuration() const {
        if (segments_.empty()) return 0.0;
        double maxEnd = 0.0;
        for (const auto& s : segments_) {
            maxEnd = std::max(maxEnd, s.endTime);
        }
        return maxEnd;
    }

private:
    void updateCrossfades() {
        // Automatically create crossfades between adjacent segments
        for (size_t i = 0; i < segments_.size() - 1; ++i) {
            auto& current = segments_[i];
            auto& next = segments_[i + 1];

            // Check if segments are adjacent or overlapping
            double gap = next.startTime - current.endTime;
            if (gap <= defaultCrossfadeLength_ * 2) {
                // Create crossfade
                double xfadeLength = std::max(defaultCrossfadeLength_,
                                              std::abs(gap) / 2.0);
                current.fadeOutLength = xfadeLength;
                next.fadeInLength = xfadeLength;
            }
        }
    }

    juce::String id_;
    juce::String name_;
    std::vector<CompSegment> segments_;
    CrossfadeShape crossfadeShape_ = CrossfadeShape::EqualPower;
    double defaultCrossfadeLength_ = 0.01; // 10ms default
};

//==============================================================================
/** Take lane containing multiple takes */
class TakeLane {
public:
    TakeLane(const juce::String& name = "Take Lane")
        : name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    juce::String getId() const { return id_; }
    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    //==============================================================================
    /** Add a new take */
    Take* addTake(double startTime, double endTime) {
        int takeNumber = static_cast<int>(takes_.size()) + 1;
        auto take = std::make_unique<Take>(takeNumber, startTime, endTime);
        Take* ptr = take.get();
        takes_.push_back(std::move(take));
        return ptr;
    }

    /** Get take by index */
    Take* getTake(int index) {
        if (index >= 0 && index < static_cast<int>(takes_.size())) {
            return takes_[index].get();
        }
        return nullptr;
    }

    /** Get take by ID */
    Take* getTakeById(const juce::String& id) {
        for (auto& take : takes_) {
            if (take->getId() == id) {
                return take.get();
            }
        }
        return nullptr;
    }

    /** Get number of takes */
    int getNumTakes() const { return static_cast<int>(takes_.size()); }

    /** Get all takes */
    const std::vector<std::unique_ptr<Take>>& getTakes() const { return takes_; }

    /** Remove take */
    void removeTake(int index) {
        if (index >= 0 && index < static_cast<int>(takes_.size())) {
            takes_.erase(takes_.begin() + index);
            renumberTakes();
        }
    }

    /** Delete all takes except one */
    void keepOnlyTake(int index) {
        if (index >= 0 && index < static_cast<int>(takes_.size())) {
            auto kept = std::move(takes_[index]);
            takes_.clear();
            takes_.push_back(std::move(kept));
            renumberTakes();
        }
    }

    //==============================================================================
    /** Create a new comp */
    Comp* createComp(const juce::String& name = "New Comp") {
        auto comp = std::make_unique<Comp>(name);
        Comp* ptr = comp.get();
        comps_.push_back(std::move(comp));
        return ptr;
    }

    /** Get active comp */
    Comp* getActiveComp() {
        if (activeCompIndex_ >= 0 && activeCompIndex_ < static_cast<int>(comps_.size())) {
            return comps_[activeCompIndex_].get();
        }
        return nullptr;
    }

    /** Set active comp */
    void setActiveComp(int index) {
        if (index >= 0 && index < static_cast<int>(comps_.size())) {
            activeCompIndex_ = index;
        }
    }

    /** Get number of comps */
    int getNumComps() const { return static_cast<int>(comps_.size()); }

    //==============================================================================
    /** Expanded state for UI */
    void setExpanded(bool expanded) { expanded_ = expanded; }
    bool isExpanded() const { return expanded_; }

    /** Lane height */
    void setLaneHeight(int height) { laneHeight_ = height; }
    int getLaneHeight() const { return laneHeight_; }

private:
    void renumberTakes() {
        for (int i = 0; i < static_cast<int>(takes_.size()); ++i) {
            // Keep original take numbers for identification
        }
    }

    juce::String id_;
    juce::String name_;
    std::vector<std::unique_ptr<Take>> takes_;
    std::vector<std::unique_ptr<Comp>> comps_;
    int activeCompIndex_ = -1;
    bool expanded_ = true;
    int laneHeight_ = 60;
};

//==============================================================================
/** Loop recording settings */
struct LoopRecordingSettings {
    bool enabled = false;
    double loopStart = 0.0;
    double loopEnd = 4.0;
    int maxTakes = 100;
    bool autoCreateNewTakes = true;
    bool overwriteMode = false;  // If true, overwrites instead of stacking
};

//==============================================================================
/** Comping mode */
enum class CompingMode {
    Swipe,          // Click and drag to select regions
    Click,          // Click to select whole takes
    Split,          // Split takes at click points
    Audition        // Click to audition, double-click to select
};

//==============================================================================
/** Main Comping Manager */
class CompingManager {
public:
    CompingManager()
    {
    }

    //==============================================================================
    /** Create a new take lane for a track */
    TakeLane* createTakeLane(const juce::String& trackId, const juce::String& name = "") {
        auto lane = std::make_unique<TakeLane>(name.isEmpty() ? "Takes" : name);
        TakeLane* ptr = lane.get();
        takeLanes_[trackId] = std::move(lane);
        return ptr;
    }

    /** Get take lane for track */
    TakeLane* getTakeLane(const juce::String& trackId) {
        auto it = takeLanes_.find(trackId);
        if (it != takeLanes_.end()) {
            return it->second.get();
        }
        return nullptr;
    }

    /** Remove take lane */
    void removeTakeLane(const juce::String& trackId) {
        takeLanes_.erase(trackId);
    }

    //==============================================================================
    /** Start loop recording */
    void startLoopRecording(const juce::String& trackId,
                           const LoopRecordingSettings& settings) {
        loopSettings_ = settings;
        currentTrackId_ = trackId;
        isLoopRecording_ = true;
        currentLoopPass_ = 0;

        // Create take lane if needed
        if (!getTakeLane(trackId)) {
            createTakeLane(trackId);
        }
    }

    /** Called when transport loops */
    void onLoopBoundary() {
        if (!isLoopRecording_) return;

        currentLoopPass_++;

        if (auto* lane = getTakeLane(currentTrackId_)) {
            // Create new take for this loop pass
            if (currentLoopPass_ <= loopSettings_.maxTakes) {
                lane->addTake(loopSettings_.loopStart, loopSettings_.loopEnd);
            }
        }
    }

    /** Stop loop recording */
    void stopLoopRecording() {
        isLoopRecording_ = false;
        currentLoopPass_ = 0;
    }

    /** Is currently loop recording */
    bool isLoopRecording() const { return isLoopRecording_; }

    //==============================================================================
    /** Set comping mode */
    void setCompingMode(CompingMode mode) { compingMode_ = mode; }
    CompingMode getCompingMode() const { return compingMode_; }

    //==============================================================================
    /** Swipe comp - select region from take to add to comp */
    void swipeComp(const juce::String& trackId, const juce::String& takeId,
                   double startTime, double endTime) {
        auto* lane = getTakeLane(trackId);
        if (!lane) return;

        auto* comp = lane->getActiveComp();
        if (!comp) {
            comp = lane->createComp("Main Comp");
            lane->setActiveComp(0);
        }

        auto* take = lane->getTakeById(takeId);
        if (!take) return;

        // Create segment
        CompSegment segment;
        segment.takeId = takeId;
        segment.startTime = startTime;
        segment.endTime = endTime;
        segment.takeStartTime = startTime - take->getStartTime();

        comp->addSegment(segment);
    }

    /** Quick comp - select entire take for a region */
    void quickComp(const juce::String& trackId, const juce::String& takeId) {
        auto* lane = getTakeLane(trackId);
        if (!lane) return;

        auto* take = lane->getTakeById(takeId);
        if (!take) return;

        swipeComp(trackId, takeId, take->getStartTime(), take->getEndTime());
    }

    //==============================================================================
    /** Flatten comp to single audio clip */
    juce::AudioBuffer<float> flattenComp(const juce::String& trackId, double sampleRate) {
        auto* lane = getTakeLane(trackId);
        if (!lane) return {};

        auto* comp = lane->getActiveComp();
        if (!comp) return {};

        double duration = comp->getDuration();
        int numSamples = static_cast<int>(duration * sampleRate);
        int numChannels = 2; // Assume stereo

        juce::AudioBuffer<float> result(numChannels, numSamples);
        result.clear();

        CrossfadeShape xfadeShape = comp->getCrossfadeShape();

        for (const auto& segment : comp->getSegments()) {
            auto* take = lane->getTakeById(segment.takeId);
            if (!take) continue;

            const auto& takeBuffer = take->getAudioBuffer();
            if (takeBuffer.getNumSamples() == 0) continue;

            int destStart = static_cast<int>(segment.startTime * sampleRate);
            int srcStart = static_cast<int>(segment.takeStartTime * sampleRate);
            int segmentSamples = static_cast<int>(segment.getDuration() * sampleRate);

            int fadeInSamples = static_cast<int>(segment.fadeInLength * sampleRate);
            int fadeOutSamples = static_cast<int>(segment.fadeOutLength * sampleRate);

            for (int ch = 0; ch < std::min(numChannels, takeBuffer.getNumChannels()); ++ch) {
                const float* src = takeBuffer.getReadPointer(ch);
                float* dst = result.getWritePointer(ch);

                for (int i = 0; i < segmentSamples; ++i) {
                    int srcIdx = srcStart + i;
                    int dstIdx = destStart + i;

                    if (srcIdx < 0 || srcIdx >= takeBuffer.getNumSamples()) continue;
                    if (dstIdx < 0 || dstIdx >= numSamples) continue;

                    float sample = src[srcIdx];

                    // Apply fade in
                    if (i < fadeInSamples) {
                        float pos = static_cast<float>(i) / fadeInSamples;
                        sample *= CrossfadeCalculator::calculateGain(pos, xfadeShape, true);
                    }

                    // Apply fade out
                    int fadeOutStart = segmentSamples - fadeOutSamples;
                    if (i >= fadeOutStart) {
                        float pos = static_cast<float>(i - fadeOutStart) / fadeOutSamples;
                        sample *= CrossfadeCalculator::calculateGain(pos, xfadeShape, false);
                    }

                    dst[dstIdx] += sample;
                }
            }
        }

        return result;
    }

    //==============================================================================
    /** Auto-select best takes based on rating */
    void autoSelectBest(const juce::String& trackId) {
        auto* lane = getTakeLane(trackId);
        if (!lane || lane->getNumTakes() == 0) return;

        // Find the highest-rated take
        Take* bestTake = nullptr;
        TakeRating bestRating = TakeRating::None;

        for (int i = 0; i < lane->getNumTakes(); ++i) {
            auto* take = lane->getTake(i);
            if (take->getRating() > bestRating) {
                bestRating = take->getRating();
                bestTake = take;
            }
        }

        if (bestTake) {
            quickComp(trackId, bestTake->getId());
        }
    }

    //==============================================================================
    /** Delete unused takes (not in any comp) */
    void deleteUnusedTakes(const juce::String& trackId) {
        auto* lane = getTakeLane(trackId);
        if (!lane) return;

        // Collect all take IDs used in comps
        std::set<juce::String> usedTakeIds;
        for (int c = 0; c < lane->getNumComps(); ++c) {
            // Get comp segments and collect take IDs
            if (auto* comp = lane->getActiveComp()) {
                for (const auto& segment : comp->getSegments()) {
                    usedTakeIds.insert(segment.takeId);
                }
            }
        }

        // Remove unused takes (iterate in reverse)
        for (int i = lane->getNumTakes() - 1; i >= 0; --i) {
            if (auto* take = lane->getTake(i)) {
                if (usedTakeIds.find(take->getId()) == usedTakeIds.end()) {
                    lane->removeTake(i);
                }
            }
        }
    }

    //==============================================================================
    /** Duplicate comp */
    void duplicateComp(const juce::String& trackId, int compIndex) {
        auto* lane = getTakeLane(trackId);
        if (!lane) return;

        // Get source comp
        lane->setActiveComp(compIndex);
        auto* srcComp = lane->getActiveComp();
        if (!srcComp) return;

        // Create new comp
        auto* newComp = lane->createComp(srcComp->getName() + " Copy");

        // Copy segments
        for (const auto& segment : srcComp->getSegments()) {
            newComp->addSegment(segment);
        }
    }

    //==============================================================================
    /** Render comp to new audio file */
    bool exportComp(const juce::String& trackId, const juce::File& outputFile,
                    double sampleRate = 44100.0) {
        auto buffer = flattenComp(trackId, sampleRate);
        if (buffer.getNumSamples() == 0) return false;

        juce::WavAudioFormat wavFormat;
        std::unique_ptr<juce::AudioFormatWriter> writer(
            wavFormat.createWriterFor(
                new juce::FileOutputStream(outputFile),
                sampleRate,
                buffer.getNumChannels(),
                24, {}, 0));

        if (writer) {
            writer->writeFromAudioSampleBuffer(buffer, 0, buffer.getNumSamples());
            return true;
        }
        return false;
    }

    //==============================================================================
    // Callbacks
    std::function<void(const juce::String& trackId, Take*)> onTakeAdded;
    std::function<void(const juce::String& trackId, int takeIndex)> onTakeRemoved;
    std::function<void(const juce::String& trackId, Comp*)> onCompChanged;

private:
    std::map<juce::String, std::unique_ptr<TakeLane>> takeLanes_;

    LoopRecordingSettings loopSettings_;
    juce::String currentTrackId_;
    bool isLoopRecording_ = false;
    int currentLoopPass_ = 0;

    CompingMode compingMode_ = CompingMode::Swipe;
};

//==============================================================================
/** Comping UI component */
class CompingEditor : public juce::Component {
public:
    CompingEditor(CompingManager& manager, const juce::String& trackId)
        : manager_(manager)
        , trackId_(trackId)
    {
    }

    void paint(juce::Graphics& g) override {
        auto* lane = manager_.getTakeLane(trackId_);
        if (!lane) return;

        // Draw take lanes
        int laneHeight = lane->getLaneHeight();

        for (int i = 0; i < lane->getNumTakes(); ++i) {
            auto* take = lane->getTake(i);
            if (!take) continue;

            juce::Rectangle<int> takeBounds(0, i * laneHeight, getWidth(), laneHeight - 2);

            // Background
            g.setColour(take->getColour().withAlpha(0.3f));
            g.fillRect(takeBounds);

            // Waveform would be drawn here
            g.setColour(take->getColour());
            g.drawRect(takeBounds);

            // Take name
            g.setColour(juce::Colours::white);
            g.drawText(take->getName(), takeBounds.reduced(4), juce::Justification::topLeft);

            // Rating indicator
            g.setColour(takeRatingToColour(take->getRating()));
            g.fillEllipse(takeBounds.getRight() - 16.0f, takeBounds.getY() + 4.0f, 12.0f, 12.0f);
        }

        // Draw comp segments overlay
        if (auto* comp = lane->getActiveComp()) {
            g.setColour(juce::Colours::yellow.withAlpha(0.3f));

            for (const auto& segment : comp->getSegments()) {
                // Find which lane this segment is from
                for (int i = 0; i < lane->getNumTakes(); ++i) {
                    auto* take = lane->getTake(i);
                    if (take && take->getId() == segment.takeId) {
                        int x = static_cast<int>(segment.startTime * pixelsPerSecond_);
                        int width = static_cast<int>(segment.getDuration() * pixelsPerSecond_);

                        juce::Rectangle<int> segBounds(x, i * laneHeight, width, laneHeight - 2);
                        g.fillRect(segBounds);
                        g.setColour(juce::Colours::yellow);
                        g.drawRect(segBounds, 2);
                        break;
                    }
                }
            }
        }
    }

    void mouseDown(const juce::MouseEvent& e) override {
        auto* lane = manager_.getTakeLane(trackId_);
        if (!lane) return;

        int laneHeight = lane->getLaneHeight();
        int takeIndex = e.y / laneHeight;

        if (takeIndex >= 0 && takeIndex < lane->getNumTakes()) {
            auto* take = lane->getTake(takeIndex);
            if (!take) return;

            swipeStartTime_ = e.x / pixelsPerSecond_;
            swipeTakeId_ = take->getId();
            isSwiping_ = true;
        }
    }

    void mouseDrag(const juce::MouseEvent& e) override {
        if (!isSwiping_) return;
        repaint();
    }

    void mouseUp(const juce::MouseEvent& e) override {
        if (!isSwiping_) return;

        double endTime = e.x / pixelsPerSecond_;

        if (swipeStartTime_ != endTime) {
            double start = std::min(swipeStartTime_, endTime);
            double end = std::max(swipeStartTime_, endTime);
            manager_.swipeComp(trackId_, swipeTakeId_, start, end);
        }

        isSwiping_ = false;
        repaint();
    }

    void setPixelsPerSecond(double pps) { pixelsPerSecond_ = pps; }

private:
    CompingManager& manager_;
    juce::String trackId_;
    double pixelsPerSecond_ = 100.0;

    bool isSwiping_ = false;
    double swipeStartTime_ = 0.0;
    juce::String swipeTakeId_;
};

} // namespace Audio
} // namespace Echoelmusic
