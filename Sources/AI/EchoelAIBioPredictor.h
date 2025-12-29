#pragma once

/*
 * EchoelAIBioPredictor.h
 * Ralph Wiggum Genius Loop Mode - Predictive Bio-Feedback AI
 *
 * Ultra-optimized predictive system for bio-feedback responses,
 * entrainment timing, and adaptive session management.
 *
 * NOTE: This is an ASSISTIVE system - user has full control.
 * All predictions are suggestions, user makes final decisions.
 */

#include <atomic>
#include <vector>
#include <array>
#include <memory>
#include <functional>
#include <string>
#include <cmath>
#include <algorithm>
#include <deque>
#include <chrono>

namespace Echoel {
namespace AI {

// ============================================================================
// Bio-Signal Types
// ============================================================================

enum class BioSignalType {
    HeartRate,              // BPM
    HeartRateVariability,   // HRV in ms
    SkinConductance,        // GSR in microsiemens
    SkinTemperature,        // Celsius
    BreathingRate,          // Breaths per minute
    BreathingDepth,         // Relative depth 0-1
    BrainwaveAlpha,         // 8-13 Hz band power
    BrainwaveBeta,          // 13-30 Hz band power
    BrainwaveTheta,         // 4-8 Hz band power
    BrainwaveDelta,         // 0.5-4 Hz band power
    BrainwaveGamma,         // 30-100 Hz band power
    MuscleActivity,         // EMG
    EyeMovement,            // EOG
    BloodOxygen,            // SpO2 percentage
    BloodPressure           // mmHg
};

enum class BioState {
    Baseline,
    Relaxing,
    Deepening,
    Peak,
    Plateau,
    Emerging,
    Alert,
    Stressed,
    Fatigued,
    Transitioning
};

enum class EntrainmentPhase {
    Induction,      // Beginning of session
    Deepening,      // Going deeper
    Maintenance,    // Holding state
    Integration,    // Processing
    Emergence       // Coming back
};

// ============================================================================
// Time-Series Data Buffer (Lock-Free)
// ============================================================================

template<typename T, size_t MaxSize = 1024>
class CircularBuffer {
public:
    CircularBuffer() : head_(0), tail_(0) {}

    bool push(const T& value) {
        size_t currentHead = head_.load(std::memory_order_relaxed);
        size_t nextHead = (currentHead + 1) % MaxSize;

        if (nextHead == tail_.load(std::memory_order_acquire)) {
            return false; // Buffer full
        }

        buffer_[currentHead] = value;
        head_.store(nextHead, std::memory_order_release);
        return true;
    }

    bool pop(T& value) {
        size_t currentTail = tail_.load(std::memory_order_relaxed);

        if (currentTail == head_.load(std::memory_order_acquire)) {
            return false; // Buffer empty
        }

        value = buffer_[currentTail];
        tail_.store((currentTail + 1) % MaxSize, std::memory_order_release);
        return true;
    }

    size_t size() const {
        size_t h = head_.load(std::memory_order_relaxed);
        size_t t = tail_.load(std::memory_order_relaxed);
        return (h >= t) ? (h - t) : (MaxSize - t + h);
    }

    bool empty() const {
        return head_.load(std::memory_order_relaxed) ==
               tail_.load(std::memory_order_relaxed);
    }

    // Get last N values (for analysis)
    std::vector<T> getRecent(size_t n) const {
        std::vector<T> result;
        size_t h = head_.load(std::memory_order_acquire);
        size_t t = tail_.load(std::memory_order_acquire);

        size_t count = (h >= t) ? (h - t) : (MaxSize - t + h);
        n = std::min(n, count);

        result.reserve(n);
        size_t start = (h >= n) ? (h - n) : (MaxSize - (n - h));

        for (size_t i = 0; i < n; ++i) {
            result.push_back(buffer_[(start + i) % MaxSize]);
        }

        return result;
    }

private:
    std::array<T, MaxSize> buffer_;
    std::atomic<size_t> head_;
    std::atomic<size_t> tail_;
};

// ============================================================================
// Bio-Signal Sample
// ============================================================================

struct BioSample {
    float value = 0.0f;
    uint64_t timestamp = 0;  // Microseconds
    BioSignalType type = BioSignalType::HeartRate;
    float quality = 1.0f;    // Signal quality 0-1

    static uint64_t now() {
        auto now = std::chrono::high_resolution_clock::now();
        return std::chrono::duration_cast<std::chrono::microseconds>(
            now.time_since_epoch()).count();
    }
};

// ============================================================================
// Statistical Analysis
// ============================================================================

class BioStatistics {
public:
    void addSample(float value) {
        samples_.push_back(value);
        if (samples_.size() > maxSamples_) {
            samples_.pop_front();
        }
        dirty_ = true;
    }

    void clear() {
        samples_.clear();
        dirty_ = true;
    }

    float getMean() const {
        updateStats();
        return mean_;
    }

    float getStdDev() const {
        updateStats();
        return stdDev_;
    }

    float getMin() const {
        updateStats();
        return min_;
    }

    float getMax() const {
        updateStats();
        return max_;
    }

    float getRange() const {
        return getMax() - getMin();
    }

    // Get trend: positive = increasing, negative = decreasing
    float getTrend() const {
        if (samples_.size() < 10) return 0.0f;

        // Simple linear regression
        float sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
        size_t n = samples_.size();

        for (size_t i = 0; i < n; ++i) {
            float x = static_cast<float>(i);
            float y = samples_[i];
            sumX += x;
            sumY += y;
            sumXY += x * y;
            sumX2 += x * x;
        }

        float slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
        return slope;
    }

    float getVariability() const {
        return getStdDev() / (getMean() + 0.001f);
    }

    size_t getSampleCount() const {
        return samples_.size();
    }

private:
    void updateStats() const {
        if (!dirty_ || samples_.empty()) return;

        float sum = 0;
        min_ = std::numeric_limits<float>::max();
        max_ = std::numeric_limits<float>::lowest();

        for (float v : samples_) {
            sum += v;
            min_ = std::min(min_, v);
            max_ = std::max(max_, v);
        }

        mean_ = sum / samples_.size();

        float variance = 0;
        for (float v : samples_) {
            float diff = v - mean_;
            variance += diff * diff;
        }
        variance /= samples_.size();
        stdDev_ = std::sqrt(variance);

        dirty_ = false;
    }

    std::deque<float> samples_;
    size_t maxSamples_ = 1000;
    mutable bool dirty_ = true;
    mutable float mean_ = 0;
    mutable float stdDev_ = 0;
    mutable float min_ = 0;
    mutable float max_ = 0;
};

// ============================================================================
// Pattern Recognition
// ============================================================================

class PatternRecognizer {
public:
    struct Pattern {
        std::string name;
        std::vector<float> template_;
        float matchThreshold = 0.8f;
    };

    // Common bio-patterns
    void addDefaultPatterns() {
        // Stress response pattern (HR up, HRV down)
        patterns_["stress_onset"] = {
            "stress_onset",
            {0.3f, 0.4f, 0.5f, 0.6f, 0.7f, 0.8f, 0.85f, 0.9f},
            0.75f
        };

        // Relaxation response
        patterns_["relaxation"] = {
            "relaxation",
            {0.8f, 0.75f, 0.7f, 0.65f, 0.6f, 0.55f, 0.52f, 0.5f},
            0.75f
        };

        // Deep state entry
        patterns_["deepening"] = {
            "deepening",
            {0.6f, 0.55f, 0.48f, 0.42f, 0.38f, 0.35f, 0.33f, 0.32f},
            0.7f
        };

        // Emergence pattern
        patterns_["emerging"] = {
            "emerging",
            {0.3f, 0.35f, 0.42f, 0.5f, 0.58f, 0.65f, 0.7f, 0.72f},
            0.7f
        };

        // Breathing cycle
        patterns_["breath_cycle"] = {
            "breath_cycle",
            {0.0f, 0.3f, 0.6f, 0.85f, 1.0f, 0.85f, 0.6f, 0.3f, 0.0f},
            0.8f
        };
    }

    float matchPattern(const std::string& name, const std::vector<float>& signal) const {
        auto it = patterns_.find(name);
        if (it == patterns_.end()) return 0.0f;

        return calculateCorrelation(it->second.template_, signal);
    }

    std::string detectPattern(const std::vector<float>& signal) const {
        std::string bestMatch = "unknown";
        float bestScore = 0.0f;

        for (const auto& [name, pattern] : patterns_) {
            float score = calculateCorrelation(pattern.template_, signal);
            if (score > pattern.matchThreshold && score > bestScore) {
                bestScore = score;
                bestMatch = name;
            }
        }

        return bestMatch;
    }

private:
    float calculateCorrelation(const std::vector<float>& a,
                                const std::vector<float>& b) const {
        if (a.empty() || b.empty()) return 0.0f;

        // Resample to match lengths
        std::vector<float> resampled;
        size_t targetLen = a.size();

        for (size_t i = 0; i < targetLen; ++i) {
            float pos = static_cast<float>(i) / targetLen * (b.size() - 1);
            size_t idx = static_cast<size_t>(pos);
            float frac = pos - idx;

            if (idx + 1 < b.size()) {
                resampled.push_back(b[idx] * (1 - frac) + b[idx + 1] * frac);
            } else {
                resampled.push_back(b.back());
            }
        }

        // Calculate Pearson correlation
        float meanA = 0, meanB = 0;
        for (size_t i = 0; i < targetLen; ++i) {
            meanA += a[i];
            meanB += resampled[i];
        }
        meanA /= targetLen;
        meanB /= targetLen;

        float num = 0, denA = 0, denB = 0;
        for (size_t i = 0; i < targetLen; ++i) {
            float da = a[i] - meanA;
            float db = resampled[i] - meanB;
            num += da * db;
            denA += da * da;
            denB += db * db;
        }

        float den = std::sqrt(denA * denB);
        if (den < 0.0001f) return 0.0f;

        return num / den;
    }

    std::unordered_map<std::string, Pattern> patterns_;
};

// ============================================================================
// Prediction Model (Simple ARIMA-like)
// ============================================================================

class PredictionModel {
public:
    void addObservation(float value, uint64_t timestamp) {
        observations_.push_back({value, timestamp});
        if (observations_.size() > maxHistory_) {
            observations_.pop_front();
        }
    }

    // Predict value N steps ahead
    float predict(size_t stepsAhead) const {
        if (observations_.size() < 5) {
            return observations_.empty() ? 0.0f : observations_.back().value;
        }

        // Use exponential smoothing with trend
        float alpha = 0.3f;  // Smoothing factor
        float beta = 0.1f;   // Trend factor

        float level = observations_[0].value;
        float trend = 0.0f;

        for (size_t i = 1; i < observations_.size(); ++i) {
            float prevLevel = level;
            level = alpha * observations_[i].value + (1 - alpha) * (level + trend);
            trend = beta * (level - prevLevel) + (1 - beta) * trend;
        }

        return level + trend * stepsAhead;
    }

    // Predict with confidence interval
    struct Prediction {
        float value;
        float lowerBound;
        float upperBound;
        float confidence;
    };

    Prediction predictWithConfidence(size_t stepsAhead) const {
        Prediction pred;
        pred.value = predict(stepsAhead);

        // Calculate prediction error from historical data
        float mse = 0.0f;
        size_t n = 0;

        for (size_t i = 5; i < observations_.size(); ++i) {
            // One-step-ahead prediction error
            float predicted = 0;
            for (size_t j = 0; j < 5; ++j) {
                predicted += observations_[i - 1 - j].value * (0.4f - j * 0.08f);
            }
            float error = observations_[i].value - predicted;
            mse += error * error;
            n++;
        }

        if (n > 0) {
            float rmse = std::sqrt(mse / n);
            // Widen interval for further predictions
            float uncertainty = rmse * std::sqrt(static_cast<float>(stepsAhead));
            pred.lowerBound = pred.value - 2 * uncertainty;
            pred.upperBound = pred.value + 2 * uncertainty;
            pred.confidence = 1.0f / (1.0f + uncertainty);
        } else {
            pred.lowerBound = pred.value * 0.8f;
            pred.upperBound = pred.value * 1.2f;
            pred.confidence = 0.5f;
        }

        return pred;
    }

    void clear() {
        observations_.clear();
    }

private:
    struct Observation {
        float value;
        uint64_t timestamp;
    };

    std::deque<Observation> observations_;
    size_t maxHistory_ = 500;
};

// ============================================================================
// Session State Analyzer
// ============================================================================

class SessionAnalyzer {
public:
    struct SessionState {
        BioState currentState = BioState::Baseline;
        EntrainmentPhase phase = EntrainmentPhase::Induction;
        float depth = 0.0f;             // 0-1, session depth
        float stability = 0.0f;         // 0-1, state stability
        float responsiveness = 0.5f;    // User's response to entrainment
        float estimatedTimeToTarget = 0.0f;  // Seconds
        float optimalFrequency = 10.0f;      // Suggested freq
    };

    // Suggestion - user decides whether to apply
    struct Suggestion {
        std::string type;           // "frequency", "tempo", "intensity", etc.
        float suggestedValue;
        float currentValue;
        std::string reason;
        float confidence;
        bool userApproved = false;  // User must approve before applying
    };

    void updateState(float hrv, float alpha, float theta, float relaxation) {
        // Determine current bio state
        if (relaxation > 0.8f && alpha > 0.6f) {
            state_.currentState = BioState::Peak;
        } else if (relaxation > 0.6f && hrv > 0.5f) {
            state_.currentState = BioState::Relaxing;
        } else if (theta > 0.6f) {
            state_.currentState = BioState::Deepening;
        } else if (relaxation < 0.3f) {
            state_.currentState = BioState::Stressed;
        } else {
            state_.currentState = BioState::Baseline;
        }

        // Update depth
        state_.depth = (alpha + theta + hrv) / 3.0f;

        // Calculate stability (low variance = high stability)
        hrvStats_.addSample(hrv);
        alphaStats_.addSample(alpha);
        state_.stability = 1.0f - std::min(1.0f,
            (hrvStats_.getVariability() + alphaStats_.getVariability()) * 2.0f);

        // Suggest optimal frequency based on state
        if (state_.currentState == BioState::Deepening) {
            state_.optimalFrequency = 6.0f + theta * 2.0f;  // Theta range
        } else if (state_.currentState == BioState::Relaxing) {
            state_.optimalFrequency = 10.0f + alpha * 2.0f;  // Alpha range
        } else if (state_.currentState == BioState::Stressed) {
            state_.optimalFrequency = 10.0f;  // Calming alpha
        } else {
            state_.optimalFrequency = 10.0f;  // Default alpha
        }
    }

    SessionState getState() const { return state_; }

    // Generate suggestions (user must approve)
    std::vector<Suggestion> getSuggestions(float currentFreq, float currentTempo,
                                           float currentIntensity) const {
        std::vector<Suggestion> suggestions;

        // Frequency suggestion
        if (std::abs(currentFreq - state_.optimalFrequency) > 1.0f) {
            Suggestion s;
            s.type = "frequency";
            s.currentValue = currentFreq;
            s.suggestedValue = state_.optimalFrequency;
            s.confidence = state_.stability * 0.8f;
            s.reason = getFrequencyReason();
            suggestions.push_back(s);
        }

        // Tempo suggestion based on state
        float optimalTempo = getOptimalTempo();
        if (std::abs(currentTempo - optimalTempo) > 5.0f) {
            Suggestion s;
            s.type = "tempo";
            s.currentValue = currentTempo;
            s.suggestedValue = optimalTempo;
            s.confidence = state_.responsiveness * 0.7f;
            s.reason = getTempoReason();
            suggestions.push_back(s);
        }

        // Intensity suggestion
        float optimalIntensity = getOptimalIntensity();
        if (std::abs(currentIntensity - optimalIntensity) > 0.15f) {
            Suggestion s;
            s.type = "intensity";
            s.currentValue = currentIntensity;
            s.suggestedValue = optimalIntensity;
            s.confidence = 0.6f;
            s.reason = getIntensityReason();
            suggestions.push_back(s);
        }

        return suggestions;
    }

private:
    float getOptimalTempo() const {
        switch (state_.currentState) {
            case BioState::Stressed: return 60.0f;
            case BioState::Deepening: return 50.0f;
            case BioState::Peak: return 55.0f;
            case BioState::Relaxing: return 65.0f;
            default: return 70.0f;
        }
    }

    float getOptimalIntensity() const {
        if (state_.currentState == BioState::Stressed) return 0.4f;
        if (state_.depth > 0.7f) return 0.5f;
        return 0.6f + state_.responsiveness * 0.2f;
    }

    std::string getFrequencyReason() const {
        switch (state_.currentState) {
            case BioState::Deepening:
                return "Theta frequency may help deepen current state";
            case BioState::Relaxing:
                return "Alpha frequency may support relaxation";
            case BioState::Stressed:
                return "Alpha frequency may help reduce stress";
            default:
                return "Frequency adjustment may improve entrainment";
        }
    }

    std::string getTempoReason() const {
        if (state_.currentState == BioState::Stressed) {
            return "Slower tempo may help reduce arousal";
        }
        if (state_.depth > 0.6f) {
            return "Slower tempo may deepen current state";
        }
        return "Tempo adjustment may improve experience";
    }

    std::string getIntensityReason() const {
        if (state_.currentState == BioState::Stressed) {
            return "Lower intensity may be more comfortable";
        }
        return "Intensity adjustment based on session depth";
    }

    SessionState state_;
    BioStatistics hrvStats_;
    BioStatistics alphaStats_;
};

// ============================================================================
// Main Bio-Predictor System
// ============================================================================

class EchoelAIBioPredictor {
public:
    struct PredictorConfig {
        float predictionHorizon = 30.0f;    // Seconds ahead to predict
        float updateRate = 10.0f;           // Hz
        bool enablePatternDetection = true;
        bool enableTrendPrediction = true;
        bool enableSessionAnalysis = true;

        // User control settings
        bool suggestionsEnabled = true;     // Show suggestions to user
        bool autoApply = false;             // NEVER auto-apply by default
        float suggestionThreshold = 0.7f;   // Min confidence to show
    };

    struct BioPrediction {
        // Predicted values (seconds ahead)
        std::map<BioSignalType, float> predictions;

        // Trend directions (-1 to 1)
        std::map<BioSignalType, float> trends;

        // Confidence levels (0 to 1)
        std::map<BioSignalType, float> confidence;

        // Detected patterns
        std::vector<std::string> detectedPatterns;

        // Session analysis
        SessionAnalyzer::SessionState sessionState;

        // User suggestions (require approval)
        std::vector<SessionAnalyzer::Suggestion> suggestions;

        // Timestamp
        uint64_t timestamp = 0;
    };

    EchoelAIBioPredictor() {
        patternRecognizer_.addDefaultPatterns();

        // Initialize prediction models for each signal type
        predictors_[BioSignalType::HeartRate] = std::make_unique<PredictionModel>();
        predictors_[BioSignalType::HeartRateVariability] = std::make_unique<PredictionModel>();
        predictors_[BioSignalType::SkinConductance] = std::make_unique<PredictionModel>();
        predictors_[BioSignalType::BrainwaveAlpha] = std::make_unique<PredictionModel>();
        predictors_[BioSignalType::BrainwaveBeta] = std::make_unique<PredictionModel>();
        predictors_[BioSignalType::BrainwaveTheta] = std::make_unique<PredictionModel>();
        predictors_[BioSignalType::BreathingRate] = std::make_unique<PredictionModel>();

        // Initialize statistics
        for (int i = 0; i <= static_cast<int>(BioSignalType::BloodPressure); ++i) {
            statistics_[static_cast<BioSignalType>(i)] = std::make_unique<BioStatistics>();
        }
    }

    void setConfig(const PredictorConfig& config) {
        config_ = config;
    }

    // Feed bio-signal data
    void addSample(BioSignalType type, float value, uint64_t timestamp = 0) {
        if (timestamp == 0) timestamp = BioSample::now();

        BioSample sample{value, timestamp, type, 1.0f};
        sampleBuffers_[type].push(sample);

        // Update predictor
        auto it = predictors_.find(type);
        if (it != predictors_.end()) {
            it->second->addObservation(value, timestamp);
        }

        // Update statistics
        auto statIt = statistics_.find(type);
        if (statIt != statistics_.end()) {
            statIt->second->addSample(value);
        }
    }

    // Get current prediction
    BioPrediction predict() {
        BioPrediction result;
        result.timestamp = BioSample::now();

        size_t stepsAhead = static_cast<size_t>(
            config_.predictionHorizon * config_.updateRate);

        // Generate predictions for each signal
        for (auto& [type, predictor] : predictors_) {
            auto pred = predictor->predictWithConfidence(stepsAhead);
            result.predictions[type] = pred.value;
            result.confidence[type] = pred.confidence;
        }

        // Calculate trends
        for (auto& [type, stats] : statistics_) {
            result.trends[type] = stats->getTrend();
        }

        // Detect patterns
        if (config_.enablePatternDetection) {
            detectPatterns(result);
        }

        // Analyze session
        if (config_.enableSessionAnalysis) {
            float hrv = getLatestValue(BioSignalType::HeartRateVariability);
            float alpha = getLatestValue(BioSignalType::BrainwaveAlpha);
            float theta = getLatestValue(BioSignalType::BrainwaveTheta);
            float relaxation = calculateRelaxation(hrv, alpha);

            sessionAnalyzer_.updateState(hrv, alpha, theta, relaxation);
            result.sessionState = sessionAnalyzer_.getState();
        }

        // Generate suggestions (user must approve)
        if (config_.suggestionsEnabled) {
            result.suggestions = sessionAnalyzer_.getSuggestions(
                currentFrequency_, currentTempo_, currentIntensity_);

            // Filter by confidence threshold
            result.suggestions.erase(
                std::remove_if(result.suggestions.begin(), result.suggestions.end(),
                    [this](const auto& s) {
                        return s.confidence < config_.suggestionThreshold;
                    }),
                result.suggestions.end());
        }

        return result;
    }

    // User approves a suggestion
    void approveSuggestion(const std::string& type, float value) {
        approvedSuggestions_[type] = value;
    }

    // Get approved value (if any)
    std::optional<float> getApprovedValue(const std::string& type) const {
        auto it = approvedSuggestions_.find(type);
        if (it != approvedSuggestions_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // Clear approved suggestions after applying
    void clearApprovedSuggestion(const std::string& type) {
        approvedSuggestions_.erase(type);
    }

    // Update current audio parameters (for context)
    void setCurrentParameters(float frequency, float tempo, float intensity) {
        currentFrequency_ = frequency;
        currentTempo_ = tempo;
        currentIntensity_ = intensity;
    }

    // Get optimal target based on user's goal
    struct EntrainmentTarget {
        float frequency;
        float tempo;
        float intensity;
        std::string rationale;
    };

    EntrainmentTarget suggestTarget(const std::string& userGoal) const {
        EntrainmentTarget target;

        if (userGoal == "deep_relaxation") {
            target.frequency = 6.0f;   // Theta
            target.tempo = 50.0f;
            target.intensity = 0.5f;
            target.rationale = "Theta frequency (6Hz) supports deep relaxation states";
        } else if (userGoal == "focus") {
            target.frequency = 14.0f;  // Low beta
            target.tempo = 70.0f;
            target.intensity = 0.6f;
            target.rationale = "Low beta (14Hz) supports alert focus";
        } else if (userGoal == "creativity") {
            target.frequency = 8.0f;   // Alpha-theta border
            target.tempo = 60.0f;
            target.intensity = 0.55f;
            target.rationale = "Alpha-theta border (8Hz) supports creative flow";
        } else if (userGoal == "meditation") {
            target.frequency = 7.5f;   // Low alpha/theta
            target.tempo = 45.0f;
            target.intensity = 0.4f;
            target.rationale = "7.5Hz supports meditative states";
        } else if (userGoal == "sleep") {
            target.frequency = 3.0f;   // Delta
            target.tempo = 40.0f;
            target.intensity = 0.3f;
            target.rationale = "Delta (3Hz) supports sleep onset";
        } else {
            // Default: balanced alpha
            target.frequency = 10.0f;
            target.tempo = 60.0f;
            target.intensity = 0.5f;
            target.rationale = "10Hz alpha promotes balanced relaxation";
        }

        return target;
    }

    // Analyze session effectiveness
    struct SessionReport {
        float averageDepth;
        float peakDepth;
        float stabilityScore;
        float responsivenessScore;
        std::chrono::seconds timeInTarget;
        std::vector<std::string> highlights;
        std::vector<std::string> suggestions;
    };

    SessionReport generateSessionReport() const {
        SessionReport report;

        // Calculate metrics from session history
        if (sessionHistory_.empty()) {
            return report;
        }

        float sumDepth = 0, maxDepth = 0, sumStability = 0;

        for (const auto& state : sessionHistory_) {
            sumDepth += state.depth;
            maxDepth = std::max(maxDepth, state.depth);
            sumStability += state.stability;
        }

        report.averageDepth = sumDepth / sessionHistory_.size();
        report.peakDepth = maxDepth;
        report.stabilityScore = sumStability / sessionHistory_.size();
        report.responsivenessScore = sessionAnalyzer_.getState().responsiveness;

        // Generate highlights
        if (report.peakDepth > 0.8f) {
            report.highlights.push_back("Reached deep entrainment state");
        }
        if (report.stabilityScore > 0.7f) {
            report.highlights.push_back("Maintained stable state throughout");
        }

        // Generate suggestions for next session
        if (report.averageDepth < 0.5f) {
            report.suggestions.push_back(
                "Consider longer session for deeper states");
        }
        if (report.stabilityScore < 0.5f) {
            report.suggestions.push_back(
                "Try reducing external distractions");
        }

        return report;
    }

    void reset() {
        for (auto& [_, predictor] : predictors_) {
            predictor->clear();
        }
        for (auto& [_, stats] : statistics_) {
            stats->clear();
        }
        sessionHistory_.clear();
        approvedSuggestions_.clear();
    }

private:
    float getLatestValue(BioSignalType type) const {
        auto it = statistics_.find(type);
        if (it != statistics_.end() && it->second->getSampleCount() > 0) {
            return it->second->getMean();
        }
        return 0.5f;
    }

    float calculateRelaxation(float hrv, float alpha) const {
        // Higher HRV and alpha = more relaxed
        return (hrv + alpha) * 0.5f;
    }

    void detectPatterns(BioPrediction& result) {
        // Get recent HRV samples for pattern detection
        auto recentHRV = sampleBuffers_[BioSignalType::HeartRateVariability].getRecent(20);

        std::vector<float> hrvValues;
        for (const auto& sample : recentHRV) {
            hrvValues.push_back(sample.value);
        }

        if (hrvValues.size() >= 8) {
            std::string pattern = patternRecognizer_.detectPattern(hrvValues);
            if (pattern != "unknown") {
                result.detectedPatterns.push_back(pattern);
            }
        }
    }

    PredictorConfig config_;

    std::unordered_map<BioSignalType, CircularBuffer<BioSample>> sampleBuffers_;
    std::unordered_map<BioSignalType, std::unique_ptr<PredictionModel>> predictors_;
    std::unordered_map<BioSignalType, std::unique_ptr<BioStatistics>> statistics_;

    PatternRecognizer patternRecognizer_;
    SessionAnalyzer sessionAnalyzer_;

    std::vector<SessionAnalyzer::SessionState> sessionHistory_;
    std::unordered_map<std::string, float> approvedSuggestions_;

    // Current audio parameters for context
    float currentFrequency_ = 10.0f;
    float currentTempo_ = 60.0f;
    float currentIntensity_ = 0.5f;
};

} // namespace AI
} // namespace Echoel
