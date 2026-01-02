/*
  ==============================================================================

    ClipEditor.h
    Created: 2026
    Author:  Echoelmusic

    Professional Audio/MIDI Clip Editor
    Non-destructive editing with slip, split, resize, and gain tools

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>
#include <functional>
#include <optional>

namespace Echoelmusic {
namespace Editing {

//==============================================================================
/** Clip type */
enum class ClipType {
    Audio,
    MIDI,
    Video,
    Automation
};

/** Edit tool */
enum class EditTool {
    Select,         // Default selection tool
    Range,          // Range selection
    Split,          // Split clips at cursor
    Slip,           // Adjust clip content position
    Stretch,        // Time-stretch clip
    Fade,           // Create/edit fades
    Gain,           // Adjust clip gain
    Pencil,         // Draw automation/MIDI
    Eraser,         // Delete clips/events
    Zoom            // Zoom tool
};

/** Snap mode */
enum class SnapMode {
    Off,
    Grid,
    Events,
    Markers,
    All
};

//==============================================================================
/** Audio clip representation */
class AudioClip {
public:
    AudioClip(const juce::File& audioFile)
        : sourceFile_(audioFile)
    {
        id_ = juce::Uuid().toString();
        name_ = audioFile.getFileNameWithoutExtension();
    }

    AudioClip(const juce::String& name = "New Clip")
        : name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    juce::String getId() const { return id_; }
    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    //==============================================================================
    // Timeline position
    double getStartTime() const { return startTime_; }
    void setStartTime(double time) { startTime_ = std::max(0.0, time); }

    double getEndTime() const { return startTime_ + duration_; }

    double getDuration() const { return duration_; }
    void setDuration(double dur) { duration_ = std::max(0.0, dur); }

    //==============================================================================
    // Content offset (slip editing)
    double getContentOffset() const { return contentOffset_; }
    void setContentOffset(double offset) {
        contentOffset_ = std::max(0.0, offset);
    }

    // Slip content within clip bounds
    void slipContent(double delta) {
        contentOffset_ = std::max(0.0, contentOffset_ + delta);
    }

    //==============================================================================
    // Gain
    float getGain() const { return gain_; }
    void setGain(float gain) { gain_ = juce::jlimit(0.0f, 4.0f, gain); }

    float getGainDB() const { return juce::Decibels::gainToDecibels(gain_); }
    void setGainDB(float db) { gain_ = juce::Decibels::decibelsToGain(db); }

    //==============================================================================
    // Fades
    double getFadeInLength() const { return fadeInLength_; }
    void setFadeInLength(double length) {
        fadeInLength_ = juce::jlimit(0.0, duration_ / 2.0, length);
    }

    double getFadeOutLength() const { return fadeOutLength_; }
    void setFadeOutLength(double length) {
        fadeOutLength_ = juce::jlimit(0.0, duration_ / 2.0, length);
    }

    //==============================================================================
    // State
    bool isSelected() const { return selected_; }
    void setSelected(bool sel) { selected_ = sel; }

    bool isMuted() const { return muted_; }
    void setMuted(bool muted) { muted_ = muted; }

    bool isLocked() const { return locked_; }
    void setLocked(bool locked) { locked_ = locked; }

    bool isLooped() const { return looped_; }
    void setLooped(bool looped) { looped_ = looped; }

    //==============================================================================
    // Visual
    juce::Colour getColour() const { return colour_; }
    void setColour(juce::Colour colour) { colour_ = colour; }

    //==============================================================================
    // Source file
    juce::File getSourceFile() const { return sourceFile_; }
    void setSourceFile(const juce::File& file) { sourceFile_ = file; }

    // Offline peak data for waveform display
    std::vector<float>& getWaveformPeaks() { return waveformPeaks_; }
    const std::vector<float>& getWaveformPeaks() const { return waveformPeaks_; }

    //==============================================================================
    // Audio data
    void setAudioBuffer(const juce::AudioBuffer<float>& buffer, double sampleRate) {
        audioBuffer_ = buffer;
        sampleRate_ = sampleRate;
        sourceDuration_ = buffer.getNumSamples() / sampleRate;
    }

    const juce::AudioBuffer<float>& getAudioBuffer() const { return audioBuffer_; }
    double getSampleRate() const { return sampleRate_; }
    double getSourceDuration() const { return sourceDuration_; }

    //==============================================================================
    /** Read audio for playback at given position */
    void readAudio(juce::AudioBuffer<float>& buffer, int64_t playheadSample,
                   double projectSampleRate) const {
        if (audioBuffer_.getNumSamples() == 0) return;

        int64_t clipStartSample = static_cast<int64_t>(startTime_ * projectSampleRate);
        int64_t clipEndSample = static_cast<int64_t>(getEndTime() * projectSampleRate);

        // Check if playhead is within clip
        if (playheadSample < clipStartSample || playheadSample >= clipEndSample) {
            return;
        }

        // Calculate source position
        double clipPosition = (playheadSample - clipStartSample) / projectSampleRate;
        double sourcePosition = contentOffset_ + clipPosition;

        // Sample rate conversion
        double sampleRateRatio = sampleRate_ / projectSampleRate;
        int64_t sourceSample = static_cast<int64_t>(sourcePosition * sampleRate_);

        // Copy samples with gain and fade
        int numSamples = buffer.getNumSamples();
        int numChannels = std::min(buffer.getNumChannels(), audioBuffer_.getNumChannels());

        for (int ch = 0; ch < numChannels; ++ch) {
            const float* src = audioBuffer_.getReadPointer(ch);
            float* dst = buffer.getWritePointer(ch);

            for (int i = 0; i < numSamples; ++i) {
                int64_t srcIdx = sourceSample + static_cast<int64_t>(i * sampleRateRatio);

                if (srcIdx >= 0 && srcIdx < audioBuffer_.getNumSamples()) {
                    float sample = src[srcIdx] * gain_;

                    // Apply fades
                    double sampleTime = (playheadSample + i - clipStartSample) / projectSampleRate;
                    sample *= getFadeMultiplier(sampleTime);

                    dst[i] += sample;
                }
            }
        }
    }

    //==============================================================================
    // Serialization
    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("id", id_);
        obj->setProperty("name", name_);
        obj->setProperty("startTime", startTime_);
        obj->setProperty("duration", duration_);
        obj->setProperty("contentOffset", contentOffset_);
        obj->setProperty("gain", gain_);
        obj->setProperty("fadeIn", fadeInLength_);
        obj->setProperty("fadeOut", fadeOutLength_);
        obj->setProperty("muted", muted_);
        obj->setProperty("locked", locked_);
        obj->setProperty("looped", looped_);
        obj->setProperty("colour", colour_.toString());
        obj->setProperty("sourceFile", sourceFile_.getFullPathName());
        return juce::var(obj);
    }

    static std::unique_ptr<AudioClip> fromVar(const juce::var& v) {
        auto clip = std::make_unique<AudioClip>();
        if (auto* obj = v.getDynamicObject()) {
            clip->id_ = obj->getProperty("id").toString();
            clip->name_ = obj->getProperty("name").toString();
            clip->startTime_ = obj->getProperty("startTime");
            clip->duration_ = obj->getProperty("duration");
            clip->contentOffset_ = obj->getProperty("contentOffset");
            clip->gain_ = obj->getProperty("gain");
            clip->fadeInLength_ = obj->getProperty("fadeIn");
            clip->fadeOutLength_ = obj->getProperty("fadeOut");
            clip->muted_ = obj->getProperty("muted");
            clip->locked_ = obj->getProperty("locked");
            clip->looped_ = obj->getProperty("looped");
            clip->colour_ = juce::Colour::fromString(obj->getProperty("colour").toString());
            clip->sourceFile_ = juce::File(obj->getProperty("sourceFile").toString());
        }
        return clip;
    }

private:
    float getFadeMultiplier(double clipTime) const {
        float mult = 1.0f;

        // Fade in
        if (clipTime < fadeInLength_ && fadeInLength_ > 0.0) {
            mult *= static_cast<float>(clipTime / fadeInLength_);
        }

        // Fade out
        double timeFromEnd = duration_ - clipTime;
        if (timeFromEnd < fadeOutLength_ && fadeOutLength_ > 0.0) {
            mult *= static_cast<float>(timeFromEnd / fadeOutLength_);
        }

        return mult;
    }

    juce::String id_;
    juce::String name_;

    double startTime_ = 0.0;
    double duration_ = 0.0;
    double contentOffset_ = 0.0;

    float gain_ = 1.0f;
    double fadeInLength_ = 0.0;
    double fadeOutLength_ = 0.0;

    bool selected_ = false;
    bool muted_ = false;
    bool locked_ = false;
    bool looped_ = false;

    juce::Colour colour_ = juce::Colours::lightblue;

    juce::File sourceFile_;
    juce::AudioBuffer<float> audioBuffer_;
    double sampleRate_ = 44100.0;
    double sourceDuration_ = 0.0;

    std::vector<float> waveformPeaks_;
};

//==============================================================================
/** Edit operation for undo/redo */
struct ClipEditOperation {
    enum class Type {
        Move,
        Resize,
        Split,
        Delete,
        Create,
        Slip,
        Gain,
        Fade,
        Duplicate
    };

    Type type;
    juce::String clipId;
    juce::var beforeState;
    juce::var afterState;
    double timestamp;

    ClipEditOperation(Type t, const juce::String& id)
        : type(t), clipId(id), timestamp(juce::Time::getMillisecondCounterHiRes()) {}
};

//==============================================================================
/** Clip editing manager */
class ClipEditor {
public:
    ClipEditor() = default;

    //==============================================================================
    // Tool selection
    void setActiveTool(EditTool tool) { activeTool_ = tool; }
    EditTool getActiveTool() const { return activeTool_; }

    //==============================================================================
    // Snap settings
    void setSnapMode(SnapMode mode) { snapMode_ = mode; }
    SnapMode getSnapMode() const { return snapMode_; }

    void setSnapValue(double gridValue) { snapValue_ = gridValue; }
    double getSnapValue() const { return snapValue_; }

    /** Snap time to grid */
    double snapTime(double time) const {
        if (snapMode_ == SnapMode::Off) return time;
        return std::round(time / snapValue_) * snapValue_;
    }

    //==============================================================================
    // Clip management
    void addClip(std::unique_ptr<AudioClip> clip) {
        clips_[clip->getId()] = std::move(clip);
    }

    void removeClip(const juce::String& id) {
        clips_.erase(id);
    }

    AudioClip* getClip(const juce::String& id) {
        auto it = clips_.find(id);
        return it != clips_.end() ? it->second.get() : nullptr;
    }

    std::vector<AudioClip*> getAllClips() {
        std::vector<AudioClip*> result;
        for (auto& pair : clips_) {
            result.push_back(pair.second.get());
        }
        return result;
    }

    std::vector<AudioClip*> getClipsInRange(double startTime, double endTime) {
        std::vector<AudioClip*> result;
        for (auto& pair : clips_) {
            if (pair.second->getStartTime() < endTime &&
                pair.second->getEndTime() > startTime) {
                result.push_back(pair.second.get());
            }
        }
        return result;
    }

    //==============================================================================
    /** Split clip at time */
    std::pair<AudioClip*, AudioClip*> splitClip(const juce::String& clipId, double splitTime) {
        auto* clip = getClip(clipId);
        if (!clip || clip->isLocked()) return {nullptr, nullptr};

        if (splitTime <= clip->getStartTime() || splitTime >= clip->getEndTime()) {
            return {nullptr, nullptr};
        }

        // Record operation
        recordOperation(ClipEditOperation::Type::Split, clipId, clip->toVar());

        // Create second clip
        auto newClip = std::make_unique<AudioClip>(clip->getName() + " (2)");
        newClip->setSourceFile(clip->getSourceFile());
        newClip->setAudioBuffer(clip->getAudioBuffer(), clip->getSampleRate());
        newClip->setStartTime(splitTime);
        newClip->setDuration(clip->getEndTime() - splitTime);
        newClip->setContentOffset(clip->getContentOffset() + (splitTime - clip->getStartTime()));
        newClip->setGain(clip->getGain());
        newClip->setColour(clip->getColour());

        // Adjust original clip
        clip->setDuration(splitTime - clip->getStartTime());

        AudioClip* newPtr = newClip.get();
        addClip(std::move(newClip));

        if (onClipSplit) onClipSplit(clip, newPtr, splitTime);

        return {clip, newPtr};
    }

    /** Move clip to new position */
    void moveClip(const juce::String& clipId, double newStartTime) {
        auto* clip = getClip(clipId);
        if (!clip || clip->isLocked()) return;

        recordOperation(ClipEditOperation::Type::Move, clipId, clip->toVar());

        clip->setStartTime(snapTime(newStartTime));

        if (onClipMoved) onClipMoved(clip);
    }

    /** Resize clip (left or right edge) */
    void resizeClip(const juce::String& clipId, double newStart, double newEnd) {
        auto* clip = getClip(clipId);
        if (!clip || clip->isLocked()) return;

        recordOperation(ClipEditOperation::Type::Resize, clipId, clip->toVar());

        double oldStart = clip->getStartTime();

        clip->setStartTime(snapTime(newStart));
        clip->setDuration(snapTime(newEnd) - clip->getStartTime());

        // Adjust content offset if left edge moved
        if (newStart != oldStart) {
            clip->setContentOffset(clip->getContentOffset() + (newStart - oldStart));
        }

        if (onClipResized) onClipResized(clip);
    }

    /** Slip clip content */
    void slipClipContent(const juce::String& clipId, double offset) {
        auto* clip = getClip(clipId);
        if (!clip || clip->isLocked()) return;

        recordOperation(ClipEditOperation::Type::Slip, clipId, clip->toVar());

        clip->slipContent(offset);

        if (onClipSlipped) onClipSlipped(clip);
    }

    /** Duplicate clip */
    AudioClip* duplicateClip(const juce::String& clipId, double targetTime = -1.0) {
        auto* sourceClip = getClip(clipId);
        if (!sourceClip) return nullptr;

        auto newClip = AudioClip::fromVar(sourceClip->toVar());
        if (targetTime >= 0.0) {
            newClip->setStartTime(snapTime(targetTime));
        } else {
            newClip->setStartTime(sourceClip->getEndTime());
        }
        newClip->setName(sourceClip->getName() + " Copy");

        AudioClip* ptr = newClip.get();
        addClip(std::move(newClip));

        if (onClipDuplicated) onClipDuplicated(sourceClip, ptr);

        return ptr;
    }

    /** Adjust clip gain */
    void setClipGain(const juce::String& clipId, float gain) {
        auto* clip = getClip(clipId);
        if (!clip || clip->isLocked()) return;

        recordOperation(ClipEditOperation::Type::Gain, clipId, clip->toVar());

        clip->setGain(gain);

        if (onClipGainChanged) onClipGainChanged(clip);
    }

    /** Set clip fades */
    void setClipFades(const juce::String& clipId, double fadeIn, double fadeOut) {
        auto* clip = getClip(clipId);
        if (!clip || clip->isLocked()) return;

        recordOperation(ClipEditOperation::Type::Fade, clipId, clip->toVar());

        clip->setFadeInLength(fadeIn);
        clip->setFadeOutLength(fadeOut);

        if (onClipFadesChanged) onClipFadesChanged(clip);
    }

    //==============================================================================
    // Selection
    void selectClip(const juce::String& clipId, bool addToSelection = false) {
        if (!addToSelection) {
            deselectAll();
        }

        if (auto* clip = getClip(clipId)) {
            clip->setSelected(true);
            selectedClipIds_.insert(clipId);
        }
    }

    void deselectClip(const juce::String& clipId) {
        if (auto* clip = getClip(clipId)) {
            clip->setSelected(false);
            selectedClipIds_.erase(clipId);
        }
    }

    void deselectAll() {
        for (const auto& id : selectedClipIds_) {
            if (auto* clip = getClip(id)) {
                clip->setSelected(false);
            }
        }
        selectedClipIds_.clear();
    }

    void selectClipsInRange(double startTime, double endTime) {
        deselectAll();
        for (auto* clip : getClipsInRange(startTime, endTime)) {
            clip->setSelected(true);
            selectedClipIds_.insert(clip->getId());
        }
    }

    std::vector<AudioClip*> getSelectedClips() {
        std::vector<AudioClip*> result;
        for (const auto& id : selectedClipIds_) {
            if (auto* clip = getClip(id)) {
                result.push_back(clip);
            }
        }
        return result;
    }

    //==============================================================================
    // Undo/Redo
    bool canUndo() const { return !undoStack_.empty(); }
    bool canRedo() const { return !redoStack_.empty(); }

    void undo() {
        if (undoStack_.empty()) return;

        auto op = std::move(undoStack_.back());
        undoStack_.pop_back();

        // Restore before state
        if (auto* clip = getClip(op.clipId)) {
            auto currentState = clip->toVar();
            *clip = *AudioClip::fromVar(op.beforeState);
            op.afterState = currentState;
        }

        redoStack_.push_back(std::move(op));
    }

    void redo() {
        if (redoStack_.empty()) return;

        auto op = std::move(redoStack_.back());
        redoStack_.pop_back();

        // Restore after state
        if (auto* clip = getClip(op.clipId)) {
            auto currentState = clip->toVar();
            *clip = *AudioClip::fromVar(op.afterState);
            op.beforeState = currentState;
        }

        undoStack_.push_back(std::move(op));
    }

    //==============================================================================
    // Callbacks
    std::function<void(AudioClip*)> onClipMoved;
    std::function<void(AudioClip*)> onClipResized;
    std::function<void(AudioClip*, AudioClip*, double)> onClipSplit;
    std::function<void(AudioClip*)> onClipSlipped;
    std::function<void(AudioClip*, AudioClip*)> onClipDuplicated;
    std::function<void(AudioClip*)> onClipGainChanged;
    std::function<void(AudioClip*)> onClipFadesChanged;

private:
    void recordOperation(ClipEditOperation::Type type, const juce::String& clipId,
                         const juce::var& beforeState) {
        ClipEditOperation op(type, clipId);
        op.beforeState = beforeState;
        undoStack_.push_back(std::move(op));

        // Clear redo stack on new operation
        redoStack_.clear();

        // Limit undo stack size
        while (undoStack_.size() > maxUndoSteps_) {
            undoStack_.erase(undoStack_.begin());
        }
    }

    std::map<juce::String, std::unique_ptr<AudioClip>> clips_;
    std::set<juce::String> selectedClipIds_;

    EditTool activeTool_ = EditTool::Select;
    SnapMode snapMode_ = SnapMode::Grid;
    double snapValue_ = 0.25; // Quarter note default

    std::vector<ClipEditOperation> undoStack_;
    std::vector<ClipEditOperation> redoStack_;
    size_t maxUndoSteps_ = 100;
};

} // namespace Editing
} // namespace Echoelmusic
