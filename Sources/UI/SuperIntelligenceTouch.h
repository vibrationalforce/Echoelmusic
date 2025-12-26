#pragma once

#include <JuceHeader.h>
#include <cmath>
#include <array>
#include <deque>

//==============================================================================
/**
 * @brief SuperIntelligenceTouch - Intelligent Touch Control System
 *
 * Features:
 * - Tremor filtering (Kalman + low-pass for shaky fingers)
 * - Automatic intent detection (Fine vs Fast morphing)
 * - Phase-jump prevention (slew rate limiting)
 * - Adaptive response curves
 * - Gesture velocity analysis
 * - Multi-touch coordination
 *
 * Design Philosophy:
 * "Jeder Touch soll perfekt sein - egal wie zittrig die Finger"
 */

namespace Echoel {
namespace Touch {

//==============================================================================
/**
 * @brief Touch Intent - What the user is trying to do
 */
enum class TouchIntent
{
    Unknown,
    FineAdjust,      // Slow, precise movements - high resolution
    FastMorph,       // Quick gestures - smooth transitions
    Tap,             // Quick touch-release
    Hold,            // Sustained pressure
    Swipe,           // Directional movement
    Pinch,           // Two-finger zoom/scale
    Rotate           // Two-finger rotation
};

//==============================================================================
/**
 * @brief Kalman Filter for 1D touch position
 *
 * Removes high-frequency tremor while preserving intentional movement
 */
class KalmanFilter1D
{
public:
    KalmanFilter1D()
    {
        reset();
    }

    void reset()
    {
        x = 0.0f;           // State estimate
        p = 1.0f;           // Estimate uncertainty
        q = 0.001f;         // Process noise (lower = more smoothing)
        r = 0.1f;           // Measurement noise
        initialized = false;
    }

    void setProcessNoise(float noise) { q = noise; }
    void setMeasurementNoise(float noise) { r = noise; }

    float update(float measurement)
    {
        if (!initialized)
        {
            x = measurement;
            initialized = true;
            return x;
        }

        // Prediction
        float p_pred = p + q;

        // Update
        float k = p_pred / (p_pred + r);  // Kalman gain
        x = x + k * (measurement - x);
        p = (1.0f - k) * p_pred;

        return x;
    }

    float getState() const { return x; }

private:
    float x;    // State
    float p;    // Uncertainty
    float q;    // Process noise
    float r;    // Measurement noise
    bool initialized = false;
};

//==============================================================================
/**
 * @brief 2D Kalman Filter for touch position
 */
class KalmanFilter2D
{
public:
    void reset()
    {
        filterX.reset();
        filterY.reset();
    }

    void setProcessNoise(float noise)
    {
        filterX.setProcessNoise(noise);
        filterY.setProcessNoise(noise);
    }

    void setMeasurementNoise(float noise)
    {
        filterX.setMeasurementNoise(noise);
        filterY.setMeasurementNoise(noise);
    }

    juce::Point<float> update(juce::Point<float> measurement)
    {
        return {
            filterX.update(measurement.x),
            filterY.update(measurement.y)
        };
    }

    juce::Point<float> getState() const
    {
        return { filterX.getState(), filterY.getState() };
    }

private:
    KalmanFilter1D filterX;
    KalmanFilter1D filterY;
};

//==============================================================================
/**
 * @brief Velocity Analyzer - Tracks movement speed and acceleration
 */
class VelocityAnalyzer
{
public:
    static constexpr int HISTORY_SIZE = 10;

    void reset()
    {
        positions.clear();
        timestamps.clear();
        lastVelocity = 0.0f;
        lastAcceleration = 0.0f;
    }

    void addSample(juce::Point<float> position, double timestamp)
    {
        positions.push_back(position);
        timestamps.push_back(timestamp);

        if (positions.size() > HISTORY_SIZE)
        {
            positions.pop_front();
            timestamps.pop_front();
        }

        updateMetrics();
    }

    float getVelocity() const { return lastVelocity; }
    float getAcceleration() const { return lastAcceleration; }
    float getJitter() const { return jitterAmount; }

    bool isStable() const
    {
        return jitterAmount < 2.0f && std::abs(lastAcceleration) < 50.0f;
    }

private:
    void updateMetrics()
    {
        if (positions.size() < 2) return;

        // Calculate velocity (pixels per second)
        auto& p1 = positions[positions.size() - 2];
        auto& p2 = positions[positions.size() - 1];
        double dt = timestamps.back() - timestamps[timestamps.size() - 2];

        if (dt > 0.0001)
        {
            float distance = p1.getDistanceFrom(p2);
            float newVelocity = static_cast<float>(distance / dt);

            // Smooth velocity
            lastVelocity = lastVelocity * 0.7f + newVelocity * 0.3f;

            // Calculate acceleration
            lastAcceleration = (newVelocity - lastVelocity) / static_cast<float>(dt);
        }

        // Calculate jitter (variance in velocity)
        if (positions.size() >= 5)
        {
            float sumSq = 0.0f;
            float sum = 0.0f;

            for (size_t i = 1; i < positions.size(); ++i)
            {
                float dist = positions[i].getDistanceFrom(positions[i-1]);
                sum += dist;
                sumSq += dist * dist;
            }

            float n = static_cast<float>(positions.size() - 1);
            float mean = sum / n;
            jitterAmount = std::sqrt(sumSq / n - mean * mean);
        }
    }

    std::deque<juce::Point<float>> positions;
    std::deque<double> timestamps;
    float lastVelocity = 0.0f;
    float lastAcceleration = 0.0f;
    float jitterAmount = 0.0f;
};

//==============================================================================
/**
 * @brief Intent Detector - Analyzes touch patterns to determine user intent
 */
class IntentDetector
{
public:
    // Thresholds (can be tuned)
    struct Config
    {
        float fineAdjustMaxVelocity = 50.0f;      // pixels/sec
        float fastMorphMinVelocity = 200.0f;      // pixels/sec
        float tapMaxDuration = 0.2f;               // seconds
        float holdMinDuration = 0.5f;              // seconds
        float swipeMinDistance = 50.0f;            // pixels
        float jitterThreshold = 3.0f;              // pixels
        int   stableFramesRequired = 5;            // frames to confirm intent
    };

    IntentDetector() : config() {}

    void setConfig(const Config& cfg) { config = cfg; }

    TouchIntent analyze(const VelocityAnalyzer& velocity,
                        float touchDuration,
                        float totalDistance,
                        bool isTouchActive)
    {
        float vel = velocity.getVelocity();
        float jitter = velocity.getJitter();

        // Tap detection
        if (!isTouchActive && touchDuration < config.tapMaxDuration && totalDistance < 20.0f)
        {
            return TouchIntent::Tap;
        }

        // Hold detection
        if (isTouchActive && touchDuration > config.holdMinDuration && vel < 10.0f)
        {
            return TouchIntent::Hold;
        }

        // Swipe detection
        if (totalDistance > config.swipeMinDistance && vel > config.fastMorphMinVelocity)
        {
            return TouchIntent::Swipe;
        }

        // High jitter = tremor = fine adjust mode
        if (jitter > config.jitterThreshold || vel < config.fineAdjustMaxVelocity)
        {
            stableFrameCount++;
            if (stableFrameCount >= config.stableFramesRequired)
            {
                return TouchIntent::FineAdjust;
            }
        }
        else
        {
            stableFrameCount = 0;
        }

        // Fast movement = morphing
        if (vel > config.fastMorphMinVelocity)
        {
            return TouchIntent::FastMorph;
        }

        // In-between velocities - use acceleration to decide
        if (std::abs(velocity.getAcceleration()) > 100.0f)
        {
            return TouchIntent::FastMorph;  // Accelerating = intentional movement
        }

        return TouchIntent::FineAdjust;  // Default to fine adjust for safety
    }

    void reset()
    {
        stableFrameCount = 0;
    }

private:
    Config config;
    int stableFrameCount = 0;
};

//==============================================================================
/**
 * @brief Slew Rate Limiter - Prevents phase jumps in parameter changes
 */
class SlewRateLimiter
{
public:
    SlewRateLimiter(float maxRatePerSecond = 10.0f)
        : maxRate(maxRatePerSecond), currentValue(0.0f), initialized(false)
    {}

    void setMaxRate(float ratePerSecond) { maxRate = ratePerSecond; }

    float process(float target, float deltaTime)
    {
        if (!initialized)
        {
            currentValue = target;
            initialized = true;
            return currentValue;
        }

        float maxChange = maxRate * deltaTime;
        float diff = target - currentValue;

        if (std::abs(diff) <= maxChange)
        {
            currentValue = target;
        }
        else
        {
            currentValue += (diff > 0 ? maxChange : -maxChange);
        }

        return currentValue;
    }

    void reset()
    {
        initialized = false;
        currentValue = 0.0f;
    }

    void reset(float value)
    {
        currentValue = value;
        initialized = true;
    }

    float getCurrentValue() const { return currentValue; }

private:
    float maxRate;
    float currentValue;
    bool initialized;
};

//==============================================================================
/**
 * @brief Adaptive Response Curve - Dynamic sensitivity based on intent
 */
class AdaptiveResponseCurve
{
public:
    enum class CurveType
    {
        Linear,
        Exponential,
        Logarithmic,
        SCurve,
        FineControl,    // Reduced sensitivity for precise adjustments
        FastResponse    // Quick response for morphing
    };

    AdaptiveResponseCurve() : currentCurve(CurveType::Linear), sensitivity(1.0f) {}

    void setCurve(CurveType type) { currentCurve = type; }
    void setSensitivity(float sens) { sensitivity = juce::jlimit(0.1f, 10.0f, sens); }

    // Adapt curve based on detected intent
    void adaptToIntent(TouchIntent intent)
    {
        switch (intent)
        {
            case TouchIntent::FineAdjust:
                currentCurve = CurveType::FineControl;
                targetSensitivity = 0.3f;  // Reduced sensitivity
                break;

            case TouchIntent::FastMorph:
            case TouchIntent::Swipe:
                currentCurve = CurveType::FastResponse;
                targetSensitivity = 2.0f;  // Increased sensitivity
                break;

            case TouchIntent::Hold:
                currentCurve = CurveType::Linear;
                targetSensitivity = 0.5f;
                break;

            default:
                currentCurve = CurveType::SCurve;
                targetSensitivity = 1.0f;
                break;
        }

        // Smooth sensitivity transition
        sensitivity = sensitivity * 0.9f + targetSensitivity * 0.1f;
    }

    // Apply curve to normalized input [0, 1]
    float apply(float input) const
    {
        input = juce::jlimit(0.0f, 1.0f, input);
        float output = 0.0f;

        switch (currentCurve)
        {
            case CurveType::Linear:
                output = input;
                break;

            case CurveType::Exponential:
                output = input * input;
                break;

            case CurveType::Logarithmic:
                output = std::log1p(input * 9.0f) / std::log(10.0f);
                break;

            case CurveType::SCurve:
                // Smooth S-curve using smoothstep
                output = input * input * (3.0f - 2.0f * input);
                break;

            case CurveType::FineControl:
                // Very gentle curve for precise control
                // Cubic with reduced range
                output = input * input * input * 0.5f + input * 0.5f;
                output *= 0.3f;  // Reduce overall range
                break;

            case CurveType::FastResponse:
                // Quick response curve
                output = 1.0f - (1.0f - input) * (1.0f - input);
                break;
        }

        return output * sensitivity;
    }

    // Apply curve to signed input [-1, 1]
    float applySigned(float input) const
    {
        float sign = input < 0.0f ? -1.0f : 1.0f;
        return apply(std::abs(input)) * sign;
    }

    CurveType getCurrentCurve() const { return currentCurve; }
    float getSensitivity() const { return sensitivity; }

private:
    CurveType currentCurve;
    float sensitivity;
    float targetSensitivity = 1.0f;
};

//==============================================================================
/**
 * @brief TouchPoint - Complete tracking for a single touch
 */
struct TouchPoint
{
    int id = -1;
    juce::Point<float> rawPosition;
    juce::Point<float> filteredPosition;
    juce::Point<float> startPosition;
    double startTime = 0.0;
    double lastUpdateTime = 0.0;
    bool isActive = false;

    KalmanFilter2D kalman;
    VelocityAnalyzer velocity;
    IntentDetector intentDetector;
    SlewRateLimiter slewX { 1000.0f };
    SlewRateLimiter slewY { 1000.0f };
    AdaptiveResponseCurve responseCurve;
    TouchIntent currentIntent = TouchIntent::Unknown;

    float getTotalDistance() const
    {
        return startPosition.getDistanceFrom(filteredPosition);
    }

    float getDuration() const
    {
        return static_cast<float>(lastUpdateTime - startTime);
    }

    void reset()
    {
        id = -1;
        isActive = false;
        kalman.reset();
        velocity.reset();
        intentDetector.reset();
        slewX.reset();
        slewY.reset();
        currentIntent = TouchIntent::Unknown;
    }
};

//==============================================================================
/**
 * @brief SuperIntelligenceTouch - Main Touch Intelligence Controller
 *
 * Zentrale Klasse für intelligente Touch-Verarbeitung
 */
class SuperIntelligenceTouch : public juce::MouseListener
{
public:
    static constexpr int MAX_TOUCH_POINTS = 10;

    //==========================================================================
    struct Config
    {
        // Tremor filtering
        float kalmanProcessNoise = 0.001f;    // Lower = more smoothing
        float kalmanMeasurementNoise = 0.1f;  // Higher = trust measurements less

        // Slew rate limiting (prevents phase jumps)
        float maxSlewRateFine = 200.0f;       // pixels/sec in fine mode
        float maxSlewRateFast = 2000.0f;      // pixels/sec in fast mode

        // Intent detection
        IntentDetector::Config intentConfig;

        // Response adaptation
        bool adaptiveResponseEnabled = true;
        float responseSmoothingFactor = 0.1f;  // Lower = smoother transitions
    };

    //==========================================================================
    class Listener
    {
    public:
        virtual ~Listener() = default;

        virtual void onTouchStart(int id, juce::Point<float> position) {}
        virtual void onTouchMove(int id, juce::Point<float> position, TouchIntent intent) {}
        virtual void onTouchEnd(int id, juce::Point<float> position, TouchIntent finalIntent) {}
        virtual void onIntentChanged(int id, TouchIntent oldIntent, TouchIntent newIntent) {}
        virtual void onParameterChange(int parameterId, float value, TouchIntent intent) {}
    };

    //==========================================================================
    SuperIntelligenceTouch()
    {
        for (auto& tp : touchPoints)
            tp.reset();
    }

    void setConfig(const Config& cfg)
    {
        config = cfg;

        for (auto& tp : touchPoints)
        {
            tp.kalman.setProcessNoise(cfg.kalmanProcessNoise);
            tp.kalman.setMeasurementNoise(cfg.kalmanMeasurementNoise);
            tp.intentDetector.setConfig(cfg.intentConfig);
        }
    }

    void addListener(Listener* listener) { listeners.push_back(listener); }
    void removeListener(Listener* listener)
    {
        listeners.erase(std::remove(listeners.begin(), listeners.end(), listener), listeners.end());
    }

    //==========================================================================
    // Process raw touch input and return filtered, intent-aware output
    juce::Point<float> processTouch(int touchId, juce::Point<float> rawPosition, bool isDown)
    {
        double currentTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;

        TouchPoint* tp = getTouchPoint(touchId);
        if (!tp) return rawPosition;

        if (isDown && !tp->isActive)
        {
            // Touch started
            tp->id = touchId;
            tp->isActive = true;
            tp->rawPosition = rawPosition;
            tp->startPosition = rawPosition;
            tp->startTime = currentTime;
            tp->lastUpdateTime = currentTime;
            tp->kalman.reset();
            tp->velocity.reset();
            tp->slewX.reset(rawPosition.x);
            tp->slewY.reset(rawPosition.y);
            tp->filteredPosition = rawPosition;

            notifyTouchStart(touchId, rawPosition);
            return rawPosition;
        }

        if (!isDown && tp->isActive)
        {
            // Touch ended
            TouchIntent finalIntent = tp->currentIntent;
            tp->isActive = false;

            notifyTouchEnd(touchId, tp->filteredPosition, finalIntent);
            tp->reset();
            return tp->filteredPosition;
        }

        if (!tp->isActive) return rawPosition;

        // Update timing
        float deltaTime = static_cast<float>(currentTime - tp->lastUpdateTime);
        tp->lastUpdateTime = currentTime;
        tp->rawPosition = rawPosition;

        // Step 1: Kalman filter for tremor reduction
        juce::Point<float> kalmanFiltered = tp->kalman.update(rawPosition);

        // Step 2: Update velocity analyzer
        tp->velocity.addSample(kalmanFiltered, currentTime);

        // Step 3: Detect intent
        TouchIntent oldIntent = tp->currentIntent;
        tp->currentIntent = tp->intentDetector.analyze(
            tp->velocity,
            tp->getDuration(),
            tp->getTotalDistance(),
            tp->isActive
        );

        if (tp->currentIntent != oldIntent && oldIntent != TouchIntent::Unknown)
        {
            notifyIntentChanged(touchId, oldIntent, tp->currentIntent);
        }

        // Step 4: Adapt response curve to intent
        if (config.adaptiveResponseEnabled)
        {
            tp->responseCurve.adaptToIntent(tp->currentIntent);
        }

        // Step 5: Adjust slew rate based on intent
        float slewRate = (tp->currentIntent == TouchIntent::FineAdjust)
            ? config.maxSlewRateFine
            : config.maxSlewRateFast;
        tp->slewX.setMaxRate(slewRate);
        tp->slewY.setMaxRate(slewRate);

        // Step 6: Apply slew rate limiting to prevent phase jumps
        float smoothX = tp->slewX.process(kalmanFiltered.x, deltaTime);
        float smoothY = tp->slewY.process(kalmanFiltered.y, deltaTime);
        tp->filteredPosition = { smoothX, smoothY };

        notifyTouchMove(touchId, tp->filteredPosition, tp->currentIntent);

        return tp->filteredPosition;
    }

    //==========================================================================
    // Convert touch movement to parameter change with intelligent scaling
    float touchToParameter(int touchId,
                           juce::Point<float> startPos,
                           juce::Point<float> currentPos,
                           float minValue = 0.0f,
                           float maxValue = 1.0f,
                           bool vertical = true)
    {
        TouchPoint* tp = getTouchPoint(touchId);
        if (!tp) return minValue;

        // Calculate normalized movement
        float delta = vertical
            ? (startPos.y - currentPos.y)  // Up = positive
            : (currentPos.x - startPos.x); // Right = positive

        // Normalize to screen fraction (assume 500px for full range)
        float normalized = delta / 500.0f;

        // Apply adaptive response curve
        float curved = tp->responseCurve.applySigned(normalized);

        // Scale to parameter range
        float center = (minValue + maxValue) * 0.5f;
        float range = (maxValue - minValue) * 0.5f;

        return juce::jlimit(minValue, maxValue, center + curved * range);
    }

    //==========================================================================
    // Get current intent for a touch
    TouchIntent getIntent(int touchId) const
    {
        for (const auto& tp : touchPoints)
        {
            if (tp.id == touchId && tp.isActive)
                return tp.currentIntent;
        }
        return TouchIntent::Unknown;
    }

    // Get filtered position
    juce::Point<float> getFilteredPosition(int touchId) const
    {
        for (const auto& tp : touchPoints)
        {
            if (tp.id == touchId && tp.isActive)
                return tp.filteredPosition;
        }
        return {};
    }

    // Check if we're in fine-adjust mode (tremoring fingers detected)
    bool isFineAdjustMode(int touchId) const
    {
        return getIntent(touchId) == TouchIntent::FineAdjust;
    }

    // Get number of active touches
    int getActiveTouchCount() const
    {
        int count = 0;
        for (const auto& tp : touchPoints)
        {
            if (tp.isActive) count++;
        }
        return count;
    }

    //==========================================================================
    // MouseListener interface (for easy integration with JUCE components)
    void mouseDown(const juce::MouseEvent& e) override
    {
        processTouch(e.source.getIndex(), e.position, true);
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        processTouch(e.source.getIndex(), e.position, true);
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        processTouch(e.source.getIndex(), e.position, false);
    }

private:
    //==========================================================================
    TouchPoint* getTouchPoint(int touchId)
    {
        // Find existing
        for (auto& tp : touchPoints)
        {
            if (tp.id == touchId)
                return &tp;
        }

        // Find free slot
        for (auto& tp : touchPoints)
        {
            if (!tp.isActive)
                return &tp;
        }

        return nullptr;
    }

    void notifyTouchStart(int id, juce::Point<float> pos)
    {
        for (auto* l : listeners)
            l->onTouchStart(id, pos);
    }

    void notifyTouchMove(int id, juce::Point<float> pos, TouchIntent intent)
    {
        for (auto* l : listeners)
            l->onTouchMove(id, pos, intent);
    }

    void notifyTouchEnd(int id, juce::Point<float> pos, TouchIntent intent)
    {
        for (auto* l : listeners)
            l->onTouchEnd(id, pos, intent);
    }

    void notifyIntentChanged(int id, TouchIntent oldIntent, TouchIntent newIntent)
    {
        for (auto* l : listeners)
            l->onIntentChanged(id, oldIntent, newIntent);
    }

    //==========================================================================
    std::array<TouchPoint, MAX_TOUCH_POINTS> touchPoints;
    std::vector<Listener*> listeners;
    Config config;
};

//==============================================================================
/**
 * @brief TouchParameterController - Connects touch to audio parameters
 *
 * Intelligente Verbindung zwischen Touch-Events und Audio-Parametern
 * mit Phasensprung-Vermeidung
 */
class TouchParameterController : public SuperIntelligenceTouch::Listener
{
public:
    struct ParameterBinding
    {
        int parameterId;
        std::function<void(float, TouchIntent)> setter;
        float minValue = 0.0f;
        float maxValue = 1.0f;
        float currentValue = 0.5f;
        SlewRateLimiter slewLimiter { 5.0f };  // Max 5 units/sec change
        bool vertical = true;
    };

    void bindParameter(int id,
                       std::function<void(float, TouchIntent)> setter,
                       float minVal = 0.0f,
                       float maxVal = 1.0f,
                       float initialVal = 0.5f,
                       bool vertical = true)
    {
        ParameterBinding binding;
        binding.parameterId = id;
        binding.setter = std::move(setter);
        binding.minValue = minVal;
        binding.maxValue = maxVal;
        binding.currentValue = initialVal;
        binding.vertical = vertical;

        bindings[id] = std::move(binding);
    }

    void updateParameter(int parameterId, float rawValue, TouchIntent intent, float deltaTime)
    {
        auto it = bindings.find(parameterId);
        if (it == bindings.end()) return;

        auto& binding = it->second;

        // Adjust slew rate based on intent
        float slewRate = (intent == TouchIntent::FineAdjust) ? 2.0f : 20.0f;
        binding.slewLimiter.setMaxRate(slewRate);

        // Apply slew rate limiting to prevent phase jumps
        float smoothedValue = binding.slewLimiter.process(rawValue, deltaTime);

        // Clamp to range
        smoothedValue = juce::jlimit(binding.minValue, binding.maxValue, smoothedValue);

        // Update and notify
        binding.currentValue = smoothedValue;
        if (binding.setter)
        {
            binding.setter(smoothedValue, intent);
        }
    }

    float getParameterValue(int parameterId) const
    {
        auto it = bindings.find(parameterId);
        if (it != bindings.end())
            return it->second.currentValue;
        return 0.0f;
    }

    void onParameterChange(int parameterId, float value, TouchIntent intent) override
    {
        // Forward to bound parameter with slew limiting
        updateParameter(parameterId, value, intent, 1.0f / 60.0f);  // Assume 60fps
    }

private:
    std::map<int, ParameterBinding> bindings;
};

//==============================================================================
/**
 * @brief IntelligentSlider - Touch-optimized slider with tremor filtering
 */
class IntelligentSlider : public juce::Slider,
                          public SuperIntelligenceTouch::Listener
{
public:
    IntelligentSlider(const juce::String& name = "")
        : juce::Slider(name)
    {
        touchController.addListener(this);
        addMouseListener(&touchController, false);
    }

    ~IntelligentSlider() override
    {
        touchController.removeListener(this);
    }

    void onTouchMove(int id, juce::Point<float> position, TouchIntent intent) override
    {
        // Visual feedback based on intent
        if (intent == TouchIntent::FineAdjust)
        {
            // Show "FINE" indicator
            fineAdjustMode = true;
            repaint();
        }
        else
        {
            fineAdjustMode = false;
            repaint();
        }
    }

    void onIntentChanged(int id, TouchIntent oldIntent, TouchIntent newIntent) override
    {
        // Could trigger haptic feedback here on supported devices
        DBG("Intent changed: " + juce::String((int)oldIntent) + " -> " + juce::String((int)newIntent));
    }

    void paint(juce::Graphics& g) override
    {
        juce::Slider::paint(g);

        // Draw fine-adjust indicator
        if (fineAdjustMode && isMouseOverOrDragging())
        {
            g.setColour(juce::Colours::cyan.withAlpha(0.8f));
            g.setFont(10.0f);
            g.drawText("FINE", getLocalBounds().removeFromTop(15), juce::Justification::centred);
        }
    }

    SuperIntelligenceTouch& getTouchController() { return touchController; }

private:
    SuperIntelligenceTouch touchController;
    bool fineAdjustMode = false;
};

//==============================================================================
/**
 * @brief IntelligentXYPad - 2D touch pad with full intelligence
 */
class IntelligentXYPad : public juce::Component,
                         public SuperIntelligenceTouch::Listener
{
public:
    IntelligentXYPad()
    {
        touchController.addListener(this);
        addMouseListener(&touchController, false);
    }

    ~IntelligentXYPad() override
    {
        touchController.removeListener(this);
    }

    std::function<void(float x, float y, TouchIntent intent)> onValueChange;

    void setValues(float x, float y)
    {
        valueX = juce::jlimit(0.0f, 1.0f, x);
        valueY = juce::jlimit(0.0f, 1.0f, y);
        repaint();
    }

    float getValueX() const { return valueX; }
    float getValueY() const { return valueY; }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(juce::Colour(0xff1a1a2a));
        g.fillRoundedRectangle(bounds, 8.0f);

        // Grid
        g.setColour(juce::Colour(0xff303040));
        for (int i = 1; i < 4; ++i)
        {
            float x = bounds.getWidth() * i / 4.0f;
            float y = bounds.getHeight() * i / 4.0f;
            g.drawVerticalLine(static_cast<int>(x), bounds.getY(), bounds.getBottom());
            g.drawHorizontalLine(static_cast<int>(y), bounds.getX(), bounds.getRight());
        }

        // Crosshair at current position
        float posX = bounds.getX() + valueX * bounds.getWidth();
        float posY = bounds.getBottom() - valueY * bounds.getHeight();

        // Draw lines
        g.setColour(juce::Colours::cyan.withAlpha(0.5f));
        g.drawVerticalLine(static_cast<int>(posX), bounds.getY(), bounds.getBottom());
        g.drawHorizontalLine(static_cast<int>(posY), bounds.getX(), bounds.getRight());

        // Draw cursor
        float cursorSize = currentIntent == TouchIntent::FineAdjust ? 20.0f : 12.0f;
        juce::Colour cursorColor = currentIntent == TouchIntent::FineAdjust
            ? juce::Colours::cyan
            : juce::Colours::orange;

        g.setColour(cursorColor);
        g.fillEllipse(posX - cursorSize/2, posY - cursorSize/2, cursorSize, cursorSize);

        g.setColour(juce::Colours::white);
        g.drawEllipse(posX - cursorSize/2, posY - cursorSize/2, cursorSize, cursorSize, 2.0f);

        // Intent indicator
        juce::String intentText;
        switch (currentIntent)
        {
            case TouchIntent::FineAdjust: intentText = "FINE"; break;
            case TouchIntent::FastMorph: intentText = "MORPH"; break;
            default: break;
        }

        if (intentText.isNotEmpty() && isDragging)
        {
            g.setColour(cursorColor);
            g.setFont(12.0f);
            g.drawText(intentText, bounds.removeFromTop(20), juce::Justification::centred);
        }
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        isDragging = true;
        dragStart = e.position;
        startValueX = valueX;
        startValueY = valueY;
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Get filtered position from touch controller
        auto filtered = touchController.getFilteredPosition(e.source.getIndex());

        // Convert to normalized values
        valueX = juce::jlimit(0.0f, 1.0f, filtered.x / bounds.getWidth());
        valueY = juce::jlimit(0.0f, 1.0f, 1.0f - filtered.y / bounds.getHeight());

        if (onValueChange)
            onValueChange(valueX, valueY, currentIntent);

        repaint();
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        isDragging = false;
        currentIntent = TouchIntent::Unknown;
        repaint();
    }

    void onTouchMove(int id, juce::Point<float> position, TouchIntent intent) override
    {
        currentIntent = intent;
        repaint();
    }

private:
    SuperIntelligenceTouch touchController;
    float valueX = 0.5f;
    float valueY = 0.5f;
    float startValueX = 0.5f;
    float startValueY = 0.5f;
    juce::Point<float> dragStart;
    bool isDragging = false;
    TouchIntent currentIntent = TouchIntent::Unknown;
};

} // namespace Touch
} // namespace Echoel
