/*
  ==============================================================================

    CrossfadeEditor.h
    Created: 2026
    Author:  Echoelmusic

    Professional Crossfade and Fade Editor
    Supports multiple curve shapes, presets, and visual editing

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <functional>
#include <cmath>

namespace Echoelmusic {
namespace Audio {

//==============================================================================
/** Fade curve types */
enum class FadeCurveType {
    Linear,
    EqualPower,
    SCurve,
    Exponential,
    Logarithmic,
    FastStart,
    FastEnd,
    SlowStart,
    SlowEnd,
    Custom
};

inline juce::String fadeCurveToString(FadeCurveType type) {
    switch (type) {
        case FadeCurveType::Linear:      return "Linear";
        case FadeCurveType::EqualPower:  return "Equal Power";
        case FadeCurveType::SCurve:      return "S-Curve";
        case FadeCurveType::Exponential: return "Exponential";
        case FadeCurveType::Logarithmic: return "Logarithmic";
        case FadeCurveType::FastStart:   return "Fast Start";
        case FadeCurveType::FastEnd:     return "Fast End";
        case FadeCurveType::SlowStart:   return "Slow Start";
        case FadeCurveType::SlowEnd:     return "Slow End";
        case FadeCurveType::Custom:      return "Custom";
        default:                         return "Unknown";
    }
}

//==============================================================================
/** Crossfade mode */
enum class CrossfadeMode {
    Symmetric,      // Both clips fade equally
    Asymmetric,     // Independent fade curves
    PreCrossfade,   // Outgoing clip fades, incoming stays full
    PostCrossfade   // Incoming clip fades in, outgoing stays full
};

//==============================================================================
/** Fade curve calculator */
class FadeCurve {
public:
    FadeCurve(FadeCurveType type = FadeCurveType::Linear)
        : curveType_(type)
    {
    }

    /** Calculate fade gain at position (0.0 = start, 1.0 = end) */
    float calculateGain(float position, bool fadeIn = true) const {
        position = juce::jlimit(0.0f, 1.0f, position);
        float gain = 0.0f;

        switch (curveType_) {
            case FadeCurveType::Linear:
                gain = fadeIn ? position : (1.0f - position);
                break;

            case FadeCurveType::EqualPower:
                if (fadeIn) {
                    gain = std::sin(position * juce::MathConstants<float>::halfPi);
                } else {
                    gain = std::cos(position * juce::MathConstants<float>::halfPi);
                }
                break;

            case FadeCurveType::SCurve: {
                // Hermite S-curve: 3t² - 2t³
                float t = fadeIn ? position : (1.0f - position);
                gain = t * t * (3.0f - 2.0f * t);
                break;
            }

            case FadeCurveType::Exponential:
                if (fadeIn) {
                    gain = position * position;
                } else {
                    float t = 1.0f - position;
                    gain = t * t;
                }
                break;

            case FadeCurveType::Logarithmic:
                if (fadeIn) {
                    gain = std::sqrt(position);
                } else {
                    gain = std::sqrt(1.0f - position);
                }
                break;

            case FadeCurveType::FastStart:
                if (fadeIn) {
                    gain = 1.0f - std::pow(1.0f - position, 3.0f);
                } else {
                    gain = std::pow(1.0f - position, 3.0f);
                }
                break;

            case FadeCurveType::FastEnd:
                if (fadeIn) {
                    gain = std::pow(position, 3.0f);
                } else {
                    gain = 1.0f - std::pow(position, 3.0f);
                }
                break;

            case FadeCurveType::SlowStart:
                if (fadeIn) {
                    gain = std::pow(position, 0.5f);
                } else {
                    gain = std::pow(1.0f - position, 0.5f);
                }
                break;

            case FadeCurveType::SlowEnd:
                if (fadeIn) {
                    gain = 1.0f - std::pow(1.0f - position, 0.5f);
                } else {
                    gain = std::pow(position, 0.5f);
                }
                break;

            case FadeCurveType::Custom:
                gain = evaluateCustomCurve(position, fadeIn);
                break;
        }

        return juce::jlimit(0.0f, 1.0f, gain);
    }

    /** Generate curve points for visualization */
    std::vector<juce::Point<float>> generateCurvePoints(int numPoints, bool fadeIn = true) const {
        std::vector<juce::Point<float>> points;
        points.reserve(numPoints);

        for (int i = 0; i < numPoints; ++i) {
            float x = static_cast<float>(i) / (numPoints - 1);
            float y = calculateGain(x, fadeIn);
            points.emplace_back(x, y);
        }

        return points;
    }

    void setCurveType(FadeCurveType type) { curveType_ = type; }
    FadeCurveType getCurveType() const { return curveType_; }

    /** Set custom curve control points */
    void setCustomControlPoints(const std::vector<juce::Point<float>>& points) {
        customControlPoints_ = points;
        curveType_ = FadeCurveType::Custom;
    }

    /** Set curve tension for custom curves */
    void setCurveTension(float tension) {
        curveTension_ = juce::jlimit(0.0f, 1.0f, tension);
    }

private:
    float evaluateCustomCurve(float position, bool fadeIn) const {
        if (customControlPoints_.size() < 2) {
            return fadeIn ? position : (1.0f - position);
        }

        // Find surrounding control points
        auto& points = customControlPoints_;
        for (size_t i = 0; i < points.size() - 1; ++i) {
            if (position >= points[i].x && position <= points[i + 1].x) {
                float t = (position - points[i].x) / (points[i + 1].x - points[i].x);
                // Cubic interpolation
                float t2 = t * t;
                float t3 = t2 * t;
                float gain = points[i].y * (2*t3 - 3*t2 + 1) +
                             points[i + 1].y * (-2*t3 + 3*t2);
                return fadeIn ? gain : (1.0f - gain);
            }
        }

        return fadeIn ? position : (1.0f - position);
    }

    FadeCurveType curveType_;
    std::vector<juce::Point<float>> customControlPoints_;
    float curveTension_ = 0.5f;
};

//==============================================================================
/** Fade region on a clip */
struct FadeRegion {
    double startTime = 0.0;     // Fade start time (seconds)
    double length = 0.1;        // Fade length (seconds)
    FadeCurve curve;
    bool isFadeIn = true;

    double getEndTime() const { return startTime + length; }

    /** Apply fade to audio buffer */
    void apply(juce::AudioBuffer<float>& buffer, double sampleRate,
               int64_t bufferStartSample) const {
        int fadeStartSample = static_cast<int>(startTime * sampleRate);
        int fadeLengthSamples = static_cast<int>(length * sampleRate);

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            float* data = buffer.getWritePointer(ch);

            for (int i = 0; i < buffer.getNumSamples(); ++i) {
                int64_t globalSample = bufferStartSample + i;

                if (globalSample >= fadeStartSample &&
                    globalSample < fadeStartSample + fadeLengthSamples) {
                    float position = static_cast<float>(globalSample - fadeStartSample) /
                                     fadeLengthSamples;
                    float gain = curve.calculateGain(position, isFadeIn);
                    data[i] *= gain;
                } else if (isFadeIn && globalSample < fadeStartSample) {
                    data[i] = 0.0f;
                } else if (!isFadeIn && globalSample >= fadeStartSample + fadeLengthSamples) {
                    data[i] = 0.0f;
                }
            }
        }
    }
};

//==============================================================================
/** Crossfade between two clips */
struct Crossfade {
    juce::String id;
    juce::String outgoingClipId;
    juce::String incomingClipId;

    double crossfadeTime = 0.0;     // Center point of crossfade
    double length = 0.1;            // Total crossfade length
    CrossfadeMode mode = CrossfadeMode::Symmetric;

    FadeCurve outgoingCurve;
    FadeCurve incomingCurve;

    bool isLocked = false;  // Prevent automatic adjustment

    Crossfade() {
        id = juce::Uuid().toString();
        outgoingCurve.setCurveType(FadeCurveType::EqualPower);
        incomingCurve.setCurveType(FadeCurveType::EqualPower);
    }

    double getStartTime() const { return crossfadeTime - length / 2.0; }
    double getEndTime() const { return crossfadeTime + length / 2.0; }

    /** Get outgoing clip gain at position */
    float getOutgoingGain(double time) const {
        if (time < getStartTime()) return 1.0f;
        if (time >= getEndTime()) return 0.0f;

        float position = static_cast<float>((time - getStartTime()) / length);
        return outgoingCurve.calculateGain(position, false);
    }

    /** Get incoming clip gain at position */
    float getIncomingGain(double time) const {
        if (time < getStartTime()) return 0.0f;
        if (time >= getEndTime()) return 1.0f;

        float position = static_cast<float>((time - getStartTime()) / length);
        return incomingCurve.calculateGain(position, true);
    }

    /** Apply crossfade to buffers */
    void apply(juce::AudioBuffer<float>& outgoingBuffer,
               juce::AudioBuffer<float>& incomingBuffer,
               double sampleRate, int64_t bufferStartSample) const {
        int xfadeStartSample = static_cast<int>(getStartTime() * sampleRate);
        int xfadeLengthSamples = static_cast<int>(length * sampleRate);

        int numChannels = std::min(outgoingBuffer.getNumChannels(),
                                   incomingBuffer.getNumChannels());

        for (int ch = 0; ch < numChannels; ++ch) {
            float* outData = outgoingBuffer.getWritePointer(ch);
            float* inData = incomingBuffer.getWritePointer(ch);

            for (int i = 0; i < outgoingBuffer.getNumSamples(); ++i) {
                int64_t globalSample = bufferStartSample + i;

                if (globalSample >= xfadeStartSample &&
                    globalSample < xfadeStartSample + xfadeLengthSamples) {
                    float position = static_cast<float>(globalSample - xfadeStartSample) /
                                     xfadeLengthSamples;
                    float outGain = outgoingCurve.calculateGain(position, false);
                    float inGain = incomingCurve.calculateGain(position, true);

                    outData[i] *= outGain;
                    inData[i] *= inGain;
                }
            }
        }
    }
};

//==============================================================================
/** Crossfade preset */
struct CrossfadePreset {
    juce::String name;
    FadeCurveType outgoingCurve;
    FadeCurveType incomingCurve;
    CrossfadeMode mode;
    double defaultLength;  // In milliseconds
};

//==============================================================================
/** Crossfade manager */
class CrossfadeManager {
public:
    CrossfadeManager() {
        createBuiltInPresets();
    }

    //==============================================================================
    /** Create crossfade between clips */
    Crossfade* createCrossfade(const juce::String& outgoingClipId,
                                const juce::String& incomingClipId,
                                double crossfadeTime,
                                double length = 0.02) {
        auto xfade = std::make_unique<Crossfade>();
        xfade->outgoingClipId = outgoingClipId;
        xfade->incomingClipId = incomingClipId;
        xfade->crossfadeTime = crossfadeTime;
        xfade->length = length;

        Crossfade* ptr = xfade.get();
        crossfades_[xfade->id] = std::move(xfade);

        if (onCrossfadeCreated) onCrossfadeCreated(ptr);
        return ptr;
    }

    /** Remove crossfade */
    void removeCrossfade(const juce::String& id) {
        auto it = crossfades_.find(id);
        if (it != crossfades_.end()) {
            if (onCrossfadeRemoved) onCrossfadeRemoved(id);
            crossfades_.erase(it);
        }
    }

    /** Get crossfade by ID */
    Crossfade* getCrossfade(const juce::String& id) {
        auto it = crossfades_.find(id);
        return it != crossfades_.end() ? it->second.get() : nullptr;
    }

    /** Find crossfade between clips */
    Crossfade* findCrossfadeBetween(const juce::String& outgoingId,
                                     const juce::String& incomingId) {
        for (auto& pair : crossfades_) {
            if (pair.second->outgoingClipId == outgoingId &&
                pair.second->incomingClipId == incomingId) {
                return pair.second.get();
            }
        }
        return nullptr;
    }

    /** Get all crossfades for a clip */
    std::vector<Crossfade*> getCrossfadesForClip(const juce::String& clipId) {
        std::vector<Crossfade*> result;
        for (auto& pair : crossfades_) {
            if (pair.second->outgoingClipId == clipId ||
                pair.second->incomingClipId == clipId) {
                result.push_back(pair.second.get());
            }
        }
        return result;
    }

    //==============================================================================
    /** Apply preset to crossfade */
    void applyPreset(Crossfade& xfade, const juce::String& presetName) {
        for (const auto& preset : presets_) {
            if (preset.name == presetName) {
                xfade.outgoingCurve.setCurveType(preset.outgoingCurve);
                xfade.incomingCurve.setCurveType(preset.incomingCurve);
                xfade.mode = preset.mode;
                xfade.length = preset.defaultLength / 1000.0;  // Convert ms to seconds
                break;
            }
        }
    }

    /** Get all presets */
    const std::vector<CrossfadePreset>& getPresets() const { return presets_; }

    /** Add custom preset */
    void addPreset(const CrossfadePreset& preset) {
        presets_.push_back(preset);
    }

    //==============================================================================
    /** Set default crossfade length */
    void setDefaultLength(double lengthMs) {
        defaultLengthMs_ = juce::jlimit(1.0, 10000.0, lengthMs);
    }

    double getDefaultLength() const { return defaultLengthMs_; }

    /** Set default curve type */
    void setDefaultCurveType(FadeCurveType type) {
        defaultCurveType_ = type;
    }

    //==============================================================================
    /** Auto-create crossfades for overlapping clips */
    void autoCreateCrossfades(const std::vector<std::pair<juce::String, std::pair<double, double>>>& clips,
                              double overlapThreshold = 0.001) {
        // Sort clips by start time
        auto sortedClips = clips;
        std::sort(sortedClips.begin(), sortedClips.end(),
                  [](const auto& a, const auto& b) {
                      return a.second.first < b.second.first;
                  });

        // Find overlapping clips and create crossfades
        for (size_t i = 0; i < sortedClips.size() - 1; ++i) {
            auto& current = sortedClips[i];
            auto& next = sortedClips[i + 1];

            double currentEnd = current.second.second;
            double nextStart = next.second.first;

            // Check for overlap
            if (currentEnd > nextStart + overlapThreshold) {
                double xfadeCenter = (currentEnd + nextStart) / 2.0;
                double xfadeLength = currentEnd - nextStart;

                // Don't create if already exists
                if (!findCrossfadeBetween(current.first, next.first)) {
                    createCrossfade(current.first, next.first, xfadeCenter, xfadeLength);
                }
            }
        }
    }

    //==============================================================================
    // Callbacks
    std::function<void(Crossfade*)> onCrossfadeCreated;
    std::function<void(const juce::String&)> onCrossfadeRemoved;
    std::function<void(Crossfade*)> onCrossfadeModified;

private:
    void createBuiltInPresets() {
        presets_.push_back({"Linear", FadeCurveType::Linear, FadeCurveType::Linear,
                           CrossfadeMode::Symmetric, 20.0});
        presets_.push_back({"Equal Power", FadeCurveType::EqualPower, FadeCurveType::EqualPower,
                           CrossfadeMode::Symmetric, 20.0});
        presets_.push_back({"S-Curve", FadeCurveType::SCurve, FadeCurveType::SCurve,
                           CrossfadeMode::Symmetric, 30.0});
        presets_.push_back({"Fast In", FadeCurveType::SlowEnd, FadeCurveType::FastStart,
                           CrossfadeMode::Symmetric, 20.0});
        presets_.push_back({"Slow In", FadeCurveType::FastEnd, FadeCurveType::SlowStart,
                           CrossfadeMode::Symmetric, 20.0});
        presets_.push_back({"Constant Power", FadeCurveType::EqualPower, FadeCurveType::EqualPower,
                           CrossfadeMode::Symmetric, 10.0});
        presets_.push_back({"Film Standard", FadeCurveType::SCurve, FadeCurveType::SCurve,
                           CrossfadeMode::Symmetric, 50.0});
    }

    std::map<juce::String, std::unique_ptr<Crossfade>> crossfades_;
    std::vector<CrossfadePreset> presets_;
    double defaultLengthMs_ = 20.0;
    FadeCurveType defaultCurveType_ = FadeCurveType::EqualPower;
};

//==============================================================================
/** Crossfade editor UI component */
class CrossfadeEditorComponent : public juce::Component {
public:
    CrossfadeEditorComponent(Crossfade& xfade)
        : crossfade_(xfade)
    {
        setSize(400, 200);
    }

    void paint(juce::Graphics& g) override {
        auto bounds = getLocalBounds().reduced(10);

        // Background
        g.setColour(juce::Colours::darkgrey);
        g.fillRoundedRectangle(bounds.toFloat(), 5.0f);

        // Draw crossfade curves
        auto curveArea = bounds.reduced(20);

        // Outgoing curve (red)
        g.setColour(juce::Colours::red.withAlpha(0.8f));
        drawCurve(g, curveArea, crossfade_.outgoingCurve, false);

        // Incoming curve (green)
        g.setColour(juce::Colours::green.withAlpha(0.8f));
        drawCurve(g, curveArea, crossfade_.incomingCurve, true);

        // Labels
        g.setColour(juce::Colours::white);
        g.setFont(12.0f);
        g.drawText("Outgoing", bounds.removeFromLeft(60), juce::Justification::centred);
        g.drawText("Incoming", bounds.removeFromRight(60), juce::Justification::centred);

        // Length display
        juce::String lengthText = juce::String(crossfade_.length * 1000.0, 1) + " ms";
        g.drawText(lengthText, bounds, juce::Justification::centredBottom);
    }

    void mouseDown(const juce::MouseEvent& e) override {
        // Handle curve editing
        isDragging_ = true;
        lastDragPoint_ = e.position;
    }

    void mouseDrag(const juce::MouseEvent& e) override {
        if (isDragging_) {
            // Adjust crossfade length based on horizontal drag
            float deltaX = e.position.x - lastDragPoint_.x;
            double lengthChange = deltaX * 0.001; // Scale factor
            crossfade_.length = std::max(0.001, crossfade_.length + lengthChange);
            lastDragPoint_ = e.position;
            repaint();
        }
    }

    void mouseUp(const juce::MouseEvent&) override {
        isDragging_ = false;
    }

private:
    void drawCurve(juce::Graphics& g, juce::Rectangle<int> area,
                   const FadeCurve& curve, bool fadeIn) {
        auto points = curve.generateCurvePoints(100, fadeIn);

        juce::Path path;
        bool first = true;

        for (const auto& point : points) {
            float x = area.getX() + point.x * area.getWidth();
            float y = area.getBottom() - point.y * area.getHeight();

            if (first) {
                path.startNewSubPath(x, y);
                first = false;
            } else {
                path.lineTo(x, y);
            }
        }

        g.strokePath(path, juce::PathStrokeType(2.0f));
    }

    Crossfade& crossfade_;
    bool isDragging_ = false;
    juce::Point<float> lastDragPoint_;
};

} // namespace Audio
} // namespace Echoelmusic
