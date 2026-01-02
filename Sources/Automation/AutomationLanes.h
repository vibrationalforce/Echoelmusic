/*
  ==============================================================================

    AutomationLanes.h
    Created: 2026
    Author:  Echoelmusic

    Professional Automation Lane System
    Multi-parameter automation with curves, points, and editing tools

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>
#include <functional>
#include <cmath>

namespace Echoelmusic {
namespace Automation {

//==============================================================================
/** Automation curve shape between points */
enum class CurveShape {
    Linear,         // Straight line
    Exponential,    // Exponential curve
    Logarithmic,    // Logarithmic curve
    SCurve,         // S-curve (smooth transition)
    Square,         // Instant step at start
    Hold,           // Hold value until next point
    Bezier          // Custom bezier curve
};

inline juce::String curveShapeToString(CurveShape shape) {
    switch (shape) {
        case CurveShape::Linear:      return "Linear";
        case CurveShape::Exponential: return "Exponential";
        case CurveShape::Logarithmic: return "Logarithmic";
        case CurveShape::SCurve:      return "S-Curve";
        case CurveShape::Square:      return "Square";
        case CurveShape::Hold:        return "Hold";
        case CurveShape::Bezier:      return "Bezier";
        default:                      return "Unknown";
    }
}

//==============================================================================
/** Automation mode */
enum class AutomationMode {
    Read,           // Play back automation
    Write,          // Record new automation (destructive)
    Touch,          // Record when touched, resume playback
    Latch,          // Record from first touch until stop
    Off             // Ignore automation
};

//==============================================================================
/** Single automation point */
struct AutomationPoint {
    double time = 0.0;          // Position in seconds
    float value = 0.0f;         // Normalized value (0.0 - 1.0)
    CurveShape curveToNext = CurveShape::Linear;
    float curveTension = 0.5f;  // For bezier/S-curve
    bool isSelected = false;
    bool isLocked = false;

    // Bezier control points (relative to this point)
    juce::Point<float> controlPoint1{0.3f, 0.0f};
    juce::Point<float> controlPoint2{0.7f, 0.0f};

    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("time", time);
        obj->setProperty("value", value);
        obj->setProperty("curve", static_cast<int>(curveToNext));
        obj->setProperty("tension", curveTension);
        obj->setProperty("locked", isLocked);
        return juce::var(obj);
    }

    static AutomationPoint fromVar(const juce::var& v) {
        AutomationPoint point;
        if (auto* obj = v.getDynamicObject()) {
            point.time = obj->getProperty("time");
            point.value = obj->getProperty("value");
            point.curveToNext = static_cast<CurveShape>(int(obj->getProperty("curve")));
            point.curveTension = obj->getProperty("tension");
            point.isLocked = obj->getProperty("locked");
        }
        return point;
    }
};

//==============================================================================
/** Automation region (for copy/paste) */
struct AutomationRegion {
    double startTime = 0.0;
    double endTime = 0.0;
    std::vector<AutomationPoint> points;

    double getDuration() const { return endTime - startTime; }

    void offsetTime(double offset) {
        startTime += offset;
        endTime += offset;
        for (auto& point : points) {
            point.time += offset;
        }
    }

    void scaleTime(double factor) {
        double duration = getDuration();
        for (auto& point : points) {
            double relativeTime = (point.time - startTime) / duration;
            point.time = startTime + relativeTime * duration * factor;
        }
        endTime = startTime + duration * factor;
    }
};

//==============================================================================
/** Automation lane for a single parameter */
class AutomationLane {
public:
    AutomationLane(const juce::String& parameterName = "")
        : parameterName_(parameterName)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    juce::String getId() const { return id_; }

    juce::String getParameterName() const { return parameterName_; }
    void setParameterName(const juce::String& name) { parameterName_ = name; }

    juce::String getParameterId() const { return parameterId_; }
    void setParameterId(const juce::String& id) { parameterId_ = id; }

    //==============================================================================
    // Point management
    void addPoint(double time, float value, CurveShape curve = CurveShape::Linear) {
        AutomationPoint point;
        point.time = time;
        point.value = juce::jlimit(0.0f, 1.0f, value);
        point.curveToNext = curve;
        points_.push_back(point);
        sortPoints();
    }

    void removePoint(int index) {
        if (index >= 0 && index < static_cast<int>(points_.size())) {
            points_.erase(points_.begin() + index);
        }
    }

    void removePointsInRange(double startTime, double endTime) {
        points_.erase(
            std::remove_if(points_.begin(), points_.end(),
                           [startTime, endTime](const AutomationPoint& p) {
                               return p.time >= startTime && p.time <= endTime;
                           }),
            points_.end());
    }

    void clearPoints() { points_.clear(); }

    std::vector<AutomationPoint>& getPoints() { return points_; }
    const std::vector<AutomationPoint>& getPoints() const { return points_; }

    int getNumPoints() const { return static_cast<int>(points_.size()); }

    //==============================================================================
    /** Get interpolated value at time */
    float getValueAt(double time) const {
        if (points_.empty()) return defaultValue_;

        // Before first point
        if (time <= points_.front().time) {
            return points_.front().value;
        }

        // After last point
        if (time >= points_.back().time) {
            return points_.back().value;
        }

        // Find surrounding points
        for (size_t i = 0; i < points_.size() - 1; ++i) {
            const auto& p1 = points_[i];
            const auto& p2 = points_[i + 1];

            if (time >= p1.time && time <= p2.time) {
                return interpolate(p1, p2, time);
            }
        }

        return defaultValue_;
    }

    /** Get value at time with optional recording */
    float processValue(double time, float inputValue, AutomationMode mode) {
        switch (mode) {
            case AutomationMode::Read:
                return getValueAt(time);

            case AutomationMode::Write:
                addPoint(time, inputValue);
                return inputValue;

            case AutomationMode::Touch:
                if (isTouched_) {
                    addPoint(time, inputValue);
                    return inputValue;
                }
                return getValueAt(time);

            case AutomationMode::Latch:
                if (isLatched_) {
                    addPoint(time, inputValue);
                    return inputValue;
                }
                return getValueAt(time);

            case AutomationMode::Off:
            default:
                return inputValue;
        }
    }

    //==============================================================================
    // Touch/Latch control
    void setTouched(bool touched) { isTouched_ = touched; }
    bool isTouched() const { return isTouched_; }

    void setLatched(bool latched) { isLatched_ = latched; }
    bool isLatched() const { return isLatched_; }

    //==============================================================================
    // Default value
    void setDefaultValue(float value) { defaultValue_ = juce::jlimit(0.0f, 1.0f, value); }
    float getDefaultValue() const { return defaultValue_; }

    //==============================================================================
    // Range settings
    void setRange(float min, float max) {
        minValue_ = min;
        maxValue_ = max;
    }

    float denormalize(float normalizedValue) const {
        return minValue_ + normalizedValue * (maxValue_ - minValue_);
    }

    float normalize(float actualValue) const {
        if (maxValue_ == minValue_) return 0.0f;
        return (actualValue - minValue_) / (maxValue_ - minValue_);
    }

    //==============================================================================
    // Editing operations
    void moveSelectedPoints(double timeDelta, float valueDelta) {
        for (auto& point : points_) {
            if (point.isSelected && !point.isLocked) {
                point.time = std::max(0.0, point.time + timeDelta);
                point.value = juce::jlimit(0.0f, 1.0f, point.value + valueDelta);
            }
        }
        sortPoints();
    }

    void selectPointsInRange(double startTime, double endTime) {
        for (auto& point : points_) {
            point.isSelected = (point.time >= startTime && point.time <= endTime);
        }
    }

    void selectAllPoints() {
        for (auto& point : points_) {
            point.isSelected = true;
        }
    }

    void deselectAllPoints() {
        for (auto& point : points_) {
            point.isSelected = false;
        }
    }

    void deleteSelectedPoints() {
        points_.erase(
            std::remove_if(points_.begin(), points_.end(),
                           [](const AutomationPoint& p) {
                               return p.isSelected && !p.isLocked;
                           }),
            points_.end());
    }

    //==============================================================================
    // Copy/Paste
    AutomationRegion copyRegion(double startTime, double endTime) const {
        AutomationRegion region;
        region.startTime = startTime;
        region.endTime = endTime;

        for (const auto& point : points_) {
            if (point.time >= startTime && point.time <= endTime) {
                region.points.push_back(point);
            }
        }

        return region;
    }

    void pasteRegion(const AutomationRegion& region, double targetTime) {
        double offset = targetTime - region.startTime;

        for (auto point : region.points) {
            point.time += offset;
            points_.push_back(point);
        }

        sortPoints();
    }

    //==============================================================================
    // Curve tools
    void setCurveForSelection(CurveShape curve) {
        for (auto& point : points_) {
            if (point.isSelected) {
                point.curveToNext = curve;
            }
        }
    }

    void smoothSelection(float amount = 0.5f) {
        // Apply smoothing to selected points
        std::vector<float> newValues;

        for (size_t i = 0; i < points_.size(); ++i) {
            if (points_[i].isSelected && !points_[i].isLocked) {
                float prevValue = (i > 0) ? points_[i - 1].value : points_[i].value;
                float nextValue = (i < points_.size() - 1) ? points_[i + 1].value : points_[i].value;
                float smoothed = points_[i].value * (1.0f - amount) +
                                (prevValue + nextValue) * 0.5f * amount;
                newValues.push_back(smoothed);
            } else {
                newValues.push_back(points_[i].value);
            }
        }

        for (size_t i = 0; i < points_.size(); ++i) {
            points_[i].value = newValues[i];
        }
    }

    void thinPoints(double timeThreshold) {
        if (points_.size() < 3) return;

        std::vector<AutomationPoint> thinned;
        thinned.push_back(points_.front());

        for (size_t i = 1; i < points_.size() - 1; ++i) {
            if (points_[i].time - thinned.back().time >= timeThreshold ||
                points_[i].isLocked) {
                thinned.push_back(points_[i]);
            }
        }

        thinned.push_back(points_.back());
        points_ = thinned;
    }

    //==============================================================================
    // Visual settings
    juce::Colour getColour() const { return colour_; }
    void setColour(juce::Colour colour) { colour_ = colour; }

    bool isVisible() const { return visible_; }
    void setVisible(bool visible) { visible_ = visible; }

    int getHeight() const { return height_; }
    void setHeight(int height) { height_ = std::max(20, height); }

    //==============================================================================
    // Serialization
    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("id", id_);
        obj->setProperty("parameterName", parameterName_);
        obj->setProperty("parameterId", parameterId_);
        obj->setProperty("defaultValue", defaultValue_);
        obj->setProperty("minValue", minValue_);
        obj->setProperty("maxValue", maxValue_);
        obj->setProperty("colour", colour_.toString());
        obj->setProperty("visible", visible_);
        obj->setProperty("height", height_);

        juce::var pointsArray;
        for (const auto& point : points_) {
            pointsArray.append(point.toVar());
        }
        obj->setProperty("points", pointsArray);

        return juce::var(obj);
    }

    static std::unique_ptr<AutomationLane> fromVar(const juce::var& v) {
        auto lane = std::make_unique<AutomationLane>();
        if (auto* obj = v.getDynamicObject()) {
            lane->id_ = obj->getProperty("id").toString();
            lane->parameterName_ = obj->getProperty("parameterName").toString();
            lane->parameterId_ = obj->getProperty("parameterId").toString();
            lane->defaultValue_ = obj->getProperty("defaultValue");
            lane->minValue_ = obj->getProperty("minValue");
            lane->maxValue_ = obj->getProperty("maxValue");
            lane->colour_ = juce::Colour::fromString(obj->getProperty("colour").toString());
            lane->visible_ = obj->getProperty("visible");
            lane->height_ = obj->getProperty("height");

            if (auto* pointsArray = obj->getProperty("points").getArray()) {
                for (const auto& p : *pointsArray) {
                    lane->points_.push_back(AutomationPoint::fromVar(p));
                }
            }
        }
        return lane;
    }

private:
    float interpolate(const AutomationPoint& p1, const AutomationPoint& p2, double time) const {
        double t = (time - p1.time) / (p2.time - p1.time);
        float v1 = p1.value;
        float v2 = p2.value;

        switch (p1.curveToNext) {
            case CurveShape::Linear:
                return static_cast<float>(v1 + (v2 - v1) * t);

            case CurveShape::Exponential:
                return v1 + (v2 - v1) * static_cast<float>(std::pow(t, 2.0));

            case CurveShape::Logarithmic:
                return v1 + (v2 - v1) * static_cast<float>(std::sqrt(t));

            case CurveShape::SCurve: {
                // Hermite curve
                float t2 = static_cast<float>(t * t);
                float t3 = t2 * static_cast<float>(t);
                return v1 * (2*t3 - 3*t2 + 1) + v2 * (-2*t3 + 3*t2);
            }

            case CurveShape::Square:
                return v2;

            case CurveShape::Hold:
                return v1;

            case CurveShape::Bezier: {
                // Cubic bezier
                float ct = static_cast<float>(t);
                float mt = 1.0f - ct;
                float mt2 = mt * mt;
                float mt3 = mt2 * mt;
                float ct2 = ct * ct;
                float ct3 = ct2 * ct;

                float cp1 = v1 + p1.controlPoint1.y * (v2 - v1);
                float cp2 = v1 + p1.controlPoint2.y * (v2 - v1);

                return mt3 * v1 + 3 * mt2 * ct * cp1 + 3 * mt * ct2 * cp2 + ct3 * v2;
            }

            default:
                return static_cast<float>(v1 + (v2 - v1) * t);
        }
    }

    void sortPoints() {
        std::sort(points_.begin(), points_.end(),
                  [](const AutomationPoint& a, const AutomationPoint& b) {
                      return a.time < b.time;
                  });
    }

    juce::String id_;
    juce::String parameterName_;
    juce::String parameterId_;

    std::vector<AutomationPoint> points_;
    float defaultValue_ = 0.5f;
    float minValue_ = 0.0f;
    float maxValue_ = 1.0f;

    juce::Colour colour_ = juce::Colours::orange;
    bool visible_ = true;
    int height_ = 60;

    bool isTouched_ = false;
    bool isLatched_ = false;
};

//==============================================================================
/** Track automation container */
class TrackAutomation {
public:
    TrackAutomation(const juce::String& trackId)
        : trackId_(trackId)
    {
    }

    juce::String getTrackId() const { return trackId_; }

    //==============================================================================
    /** Add automation lane */
    AutomationLane* addLane(const juce::String& parameterName) {
        auto lane = std::make_unique<AutomationLane>(parameterName);
        AutomationLane* ptr = lane.get();
        lanes_[lane->getId()] = std::move(lane);
        return ptr;
    }

    /** Get lane by ID */
    AutomationLane* getLane(const juce::String& id) {
        auto it = lanes_.find(id);
        return it != lanes_.end() ? it->second.get() : nullptr;
    }

    /** Get lane by parameter name */
    AutomationLane* getLaneByParameter(const juce::String& parameterName) {
        for (auto& pair : lanes_) {
            if (pair.second->getParameterName() == parameterName) {
                return pair.second.get();
            }
        }
        return nullptr;
    }

    /** Get all lanes */
    std::vector<AutomationLane*> getAllLanes() {
        std::vector<AutomationLane*> result;
        for (auto& pair : lanes_) {
            result.push_back(pair.second.get());
        }
        return result;
    }

    /** Remove lane */
    void removeLane(const juce::String& id) {
        lanes_.erase(id);
    }

    //==============================================================================
    /** Set automation mode for all lanes */
    void setMode(AutomationMode mode) {
        mode_ = mode;
    }

    AutomationMode getMode() const { return mode_; }

    //==============================================================================
    /** Get or create lane for parameter */
    AutomationLane* getOrCreateLane(const juce::String& parameterName) {
        if (auto* lane = getLaneByParameter(parameterName)) {
            return lane;
        }
        return addLane(parameterName);
    }

private:
    juce::String trackId_;
    std::map<juce::String, std::unique_ptr<AutomationLane>> lanes_;
    AutomationMode mode_ = AutomationMode::Read;
};

//==============================================================================
/** Automation Manager */
class AutomationManager {
public:
    AutomationManager() = default;

    //==============================================================================
    /** Get or create track automation */
    TrackAutomation* getOrCreateTrackAutomation(const juce::String& trackId) {
        auto it = trackAutomation_.find(trackId);
        if (it != trackAutomation_.end()) {
            return it->second.get();
        }

        auto automation = std::make_unique<TrackAutomation>(trackId);
        TrackAutomation* ptr = automation.get();
        trackAutomation_[trackId] = std::move(automation);
        return ptr;
    }

    /** Get track automation */
    TrackAutomation* getTrackAutomation(const juce::String& trackId) {
        auto it = trackAutomation_.find(trackId);
        return it != trackAutomation_.end() ? it->second.get() : nullptr;
    }

    //==============================================================================
    /** Set global automation mode */
    void setGlobalMode(AutomationMode mode) {
        globalMode_ = mode;
        for (auto& pair : trackAutomation_) {
            pair.second->setMode(mode);
        }
    }

    AutomationMode getGlobalMode() const { return globalMode_; }

    //==============================================================================
    /** Process automation at time */
    void processAtTime(double time) {
        currentTime_ = time;

        for (auto& pair : trackAutomation_) {
            for (auto* lane : pair.second->getAllLanes()) {
                float value = lane->getValueAt(time);
                if (onParameterChange) {
                    onParameterChange(pair.first, lane->getParameterId(), value);
                }
            }
        }
    }

    double getCurrentTime() const { return currentTime_; }

    //==============================================================================
    // Callbacks
    std::function<void(const juce::String& trackId, const juce::String& parameterId, float value)> onParameterChange;

private:
    std::map<juce::String, std::unique_ptr<TrackAutomation>> trackAutomation_;
    AutomationMode globalMode_ = AutomationMode::Read;
    double currentTime_ = 0.0;
};

} // namespace Automation
} // namespace Echoelmusic
