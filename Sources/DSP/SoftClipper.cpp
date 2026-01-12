/**
 * SoftClipper.cpp
 *
 * Professional soft clipping and saturation inspired by Schwabe Digital GoldClip
 * Multiple clipping algorithms with bio-reactive morphing
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE
 */

#include <cmath>
#include <vector>
#include <array>
#include <algorithm>
#include <functional>

namespace Echoelmusic {
namespace DSP {

// ============================================================================
// Clipping Algorithms
// ============================================================================

namespace ClipAlgorithms {

    // Hard clip (digital)
    inline double hardClip(double x, double threshold) {
        return std::clamp(x, -threshold, threshold);
    }

    // Soft clip (cubic)
    inline double softClipCubic(double x, double threshold) {
        if (std::abs(x) < threshold) {
            return x;
        }
        double sign = std::copysign(1.0, x);
        double ax = std::abs(x);
        double t = threshold;

        // Smooth transition using cubic polynomial
        if (ax < t * 2.0) {
            double normalized = (ax - t) / t;
            return sign * (t + t * (normalized - normalized * normalized * normalized / 3.0));
        }
        return sign * t * 1.5;  // Maximum output
    }

    // Soft clip (tanh)
    inline double softClipTanh(double x, double drive) {
        return std::tanh(x * drive) / std::tanh(drive);
    }

    // Tape saturation
    inline double tapeClip(double x, double bias) {
        // Asymmetric soft saturation
        double biased = x + bias * 0.1;
        double saturated = std::tanh(biased * 1.5);

        // Add subtle even harmonics (tape character)
        double harmonics = saturated * saturated * std::copysign(1.0, saturated) * 0.1;

        return (saturated + harmonics) * 0.9;
    }

    // Tube saturation (triode)
    inline double tubeClip(double x, double drive) {
        // Asymmetric tube-style saturation
        double input = x * (1.0 + drive);

        // Grid conduction on negative half
        if (input < 0) {
            input = -std::sqrt(-input * 0.5);
        }

        // Soft saturation on positive half
        if (input > 0) {
            input = 1.0 - std::exp(-input);
        } else {
            input = -1.0 + std::exp(input);
        }

        // Even harmonics from asymmetry
        double harmonics = input * input * 0.15;

        return (input + harmonics) * 0.8;
    }

    // Transistor clip (FET-style)
    inline double transistorClip(double x, double drive) {
        double input = x * (1.0 + drive * 2.0);

        // Asymmetric FET characteristic
        if (input > 0) {
            return 1.0 - std::exp(-input * 1.5);
        } else {
            return -1.0 + std::exp(input * 1.2);
        }
    }

    // Diode clip (germanium style)
    inline double diodeClip(double x, double threshold) {
        double v = x / threshold;

        // Shockley diode equation approximation
        if (v > 0) {
            return threshold * std::log1p(std::exp(v * 2.0) - 1.0) / 2.0;
        } else {
            return -threshold * std::log1p(std::exp(-v * 1.5) - 1.0) / 1.5;
        }
    }

    // Foldback distortion
    inline double foldbackClip(double x, double threshold) {
        if (std::abs(x) < threshold) {
            return x;
        }

        double sign = std::copysign(1.0, x);
        double ax = std::abs(x);

        // Fold back when exceeding threshold
        while (ax > threshold) {
            ax = 2.0 * threshold - ax;
            ax = std::abs(ax);
        }

        return sign * ax;
    }

    // Waveshaper (polynomial)
    inline double waveshaperClip(double x, double amount) {
        // Chebyshev polynomial for harmonic content
        double x2 = x * x;
        double x3 = x2 * x;

        // Mix of odd harmonics
        return x * (1.0 - amount * 0.3) +
               x3 * amount * 0.3 -
               x2 * x3 * amount * 0.1;
    }

}  // namespace ClipAlgorithms

// ============================================================================
// Oversampling Processor
// ============================================================================

class Oversampler {
public:
    static constexpr int MAX_OVERSAMPLE = 8;

    Oversampler() { reset(); }

    void setOversampleFactor(int factor) {
        factor_ = std::clamp(factor, 1, MAX_OVERSAMPLE);
        updateFilters();
    }

    int factor() const { return factor_; }

    void reset() {
        upState_.fill(0.0);
        downState_.fill(0.0);
    }

    // Upsample single sample
    void upsample(double input, std::vector<double>& output) {
        output.resize(factor_);

        // Insert zeros
        output[0] = input * factor_;
        for (int i = 1; i < factor_; i++) {
            output[i] = 0.0;
        }

        // Low-pass filter
        for (int i = 0; i < factor_; i++) {
            output[i] = processFilter(output[i], upState_);
        }
    }

    // Downsample
    double downsample(const std::vector<double>& input) {
        // Low-pass filter and decimate
        double filtered = 0.0;
        for (int i = 0; i < factor_; i++) {
            filtered = processFilter(input[i], downState_);
        }
        return filtered;
    }

private:
    void updateFilters() {
        // Simple first-order filter for demonstration
        // Real implementation would use higher-order IIR or FIR
        filterCoeff_ = 1.0 / factor_;
    }

    double processFilter(double input, std::array<double, 4>& state) {
        // Simple cascade of first-order filters
        state[0] = state[0] + filterCoeff_ * (input - state[0]);
        state[1] = state[1] + filterCoeff_ * (state[0] - state[1]);
        return state[1];
    }

    int factor_ = 4;
    double filterCoeff_ = 0.25;
    std::array<double, 4> upState_;
    std::array<double, 4> downState_;
};

// ============================================================================
// Soft Clipper Main Class
// ============================================================================

class SoftClipper {
public:
    enum class ClipMode {
        Hard,           // Traditional hard clip
        Soft,           // Smooth cubic saturation
        Tanh,           // Hyperbolic tangent
        Tape,           // Tape-style compression
        Tube,           // Tube distortion curve
        Transistor,     // FET transistor clip
        Diode,          // Germanium diode
        Foldback,       // Foldback distortion
        Waveshaper,     // Polynomial waveshaper
        Quantum         // Bio-reactive morphing (blends all)
    };

    SoftClipper() {
        reset();
    }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
    }

    void reset() {
        oversamplerL_.reset();
        oversamplerR_.reset();
        dcBlockerState_[0] = 0.0;
        dcBlockerState_[1] = 0.0;
    }

    // ========== Parameters ==========

    void setMode(ClipMode mode) {
        mode_ = mode;
    }

    ClipMode mode() const { return mode_; }

    void setThreshold(double thresholdDb) {
        threshold_ = std::pow(10.0, std::clamp(thresholdDb, -24.0, 0.0) / 20.0);
    }

    void setCeiling(double ceilingDb) {
        ceiling_ = std::pow(10.0, std::clamp(ceilingDb, -12.0, 0.0) / 20.0);
    }

    void setDrive(double drive) {
        drive_ = std::clamp(drive, 0.0, 1.0);
    }

    void setMix(double mix) {
        mix_ = std::clamp(mix, 0.0, 1.0);
    }

    void setOversample(int factor) {
        oversamplerL_.setOversampleFactor(factor);
        oversamplerR_.setOversampleFactor(factor);
    }

    // Auto gain compensation
    void setAutoGain(bool enable) {
        autoGain_ = enable;
    }

    // DC blocking filter
    void setDCBlock(bool enable) {
        dcBlock_ = enable;
    }

    // Bio-reactive: coherence morphs between clip modes
    void setCoherenceMorph(double coherence) {
        coherenceMorph_ = std::clamp(coherence, 0.0, 1.0);
    }

    // Quantum mode blend weights
    void setQuantumWeights(double soft, double tape, double tube) {
        quantumSoft_ = soft;
        quantumTape_ = tape;
        quantumTube_ = tube;
        normalizeQuantumWeights();
    }

    // ========== Processing ==========

    void process(float* leftChannel, float* rightChannel, int numSamples) {
        for (int i = 0; i < numSamples; i++) {
            double left = static_cast<double>(leftChannel[i]);
            double right = static_cast<double>(rightChannel[i]);

            double dryLeft = left;
            double dryRight = right;

            // Apply input gain (drive)
            double inputGain = 1.0 + drive_ * 4.0;
            left *= inputGain;
            right *= inputGain;

            // Oversample, clip, downsample
            left = processWithOversampling(left, oversamplerL_);
            right = processWithOversampling(right, oversamplerR_);

            // Apply ceiling
            left *= ceiling_;
            right *= ceiling_;

            // Auto gain compensation
            if (autoGain_) {
                double compensation = 1.0 / (1.0 + drive_ * 0.5);
                left *= compensation;
                right *= compensation;
            }

            // DC blocking
            if (dcBlock_) {
                left = processDCBlock(left, 0);
                right = processDCBlock(right, 1);
            }

            // Mix dry/wet
            left = dryLeft * (1.0 - mix_) + left * mix_;
            right = dryRight * (1.0 - mix_) + right * mix_;

            leftChannel[i] = static_cast<float>(left);
            rightChannel[i] = static_cast<float>(right);
        }
    }

private:
    double processWithOversampling(double input, Oversampler& oversampler) {
        std::vector<double> upsampled;
        oversampler.upsample(input, upsampled);

        // Apply clipping at oversampled rate
        for (auto& sample : upsampled) {
            sample = applyClipping(sample);
        }

        return oversampler.downsample(upsampled);
    }

    double applyClipping(double input) {
        switch (mode_) {
            case ClipMode::Hard:
                return ClipAlgorithms::hardClip(input, threshold_);

            case ClipMode::Soft:
                return ClipAlgorithms::softClipCubic(input, threshold_);

            case ClipMode::Tanh:
                return ClipAlgorithms::softClipTanh(input, 1.0 + drive_ * 2.0);

            case ClipMode::Tape:
                return ClipAlgorithms::tapeClip(input, drive_ * 0.5);

            case ClipMode::Tube:
                return ClipAlgorithms::tubeClip(input, drive_);

            case ClipMode::Transistor:
                return ClipAlgorithms::transistorClip(input, drive_);

            case ClipMode::Diode:
                return ClipAlgorithms::diodeClip(input, threshold_);

            case ClipMode::Foldback:
                return ClipAlgorithms::foldbackClip(input, threshold_);

            case ClipMode::Waveshaper:
                return ClipAlgorithms::waveshaperClip(input, drive_);

            case ClipMode::Quantum:
                return applyQuantumClipping(input);

            default:
                return ClipAlgorithms::softClipTanh(input, 1.5);
        }
    }

    double applyQuantumClipping(double input) {
        // Blend multiple clipping modes based on coherence and weights
        double soft = ClipAlgorithms::softClipCubic(input, threshold_);
        double tape = ClipAlgorithms::tapeClip(input, drive_ * 0.5);
        double tube = ClipAlgorithms::tubeClip(input, drive_);

        // Bio-reactive morphing: high coherence = warmer (more tube/tape)
        double warmth = coherenceMorph_;
        double softWeight = quantumSoft_ * (1.0 - warmth * 0.5);
        double tapeWeight = quantumTape_ * (1.0 + warmth * 0.3);
        double tubeWeight = quantumTube_ * (1.0 + warmth * 0.3);

        double total = softWeight + tapeWeight + tubeWeight;
        if (total > 0) {
            return (soft * softWeight + tape * tapeWeight + tube * tubeWeight) / total;
        }
        return soft;
    }

    void normalizeQuantumWeights() {
        double total = quantumSoft_ + quantumTape_ + quantumTube_;
        if (total > 0) {
            quantumSoft_ /= total;
            quantumTape_ /= total;
            quantumTube_ /= total;
        } else {
            quantumSoft_ = quantumTape_ = quantumTube_ = 1.0 / 3.0;
        }
    }

    double processDCBlock(double input, int channel) {
        // High-pass at ~5 Hz
        const double coeff = 0.9995;
        double output = input - dcBlockerState_[channel] + coeff * dcBlockerPrev_[channel];
        dcBlockerState_[channel] = input;
        dcBlockerPrev_[channel] = output;
        return output;
    }

    double sampleRate_ = 44100.0;

    // Processors
    Oversampler oversamplerL_;
    Oversampler oversamplerR_;

    // Parameters
    ClipMode mode_ = ClipMode::Soft;
    double threshold_ = 1.0;
    double ceiling_ = 1.0;
    double drive_ = 0.3;
    double mix_ = 1.0;
    bool autoGain_ = true;
    bool dcBlock_ = true;

    // Bio-reactive
    double coherenceMorph_ = 0.5;
    double quantumSoft_ = 0.4;
    double quantumTape_ = 0.3;
    double quantumTube_ = 0.3;

    // DC blocker state
    double dcBlockerState_[2] = {0.0, 0.0};
    double dcBlockerPrev_[2] = {0.0, 0.0};
};

// ============================================================================
// Presets
// ============================================================================

struct SoftClipperPreset {
    const char* name;
    SoftClipper::ClipMode mode;
    double thresholdDb;
    double ceilingDb;
    double drive;
    bool autoGain;
};

const SoftClipperPreset SOFT_CLIPPER_PRESETS[] = {
    {"Transparent Limiter", SoftClipper::ClipMode::Soft, -0.3, -0.1, 0.1, true},
    {"Warm Tape", SoftClipper::ClipMode::Tape, -3.0, -0.3, 0.4, true},
    {"Tube Warmth", SoftClipper::ClipMode::Tube, -6.0, -0.5, 0.5, true},
    {"Aggressive Clip", SoftClipper::ClipMode::Hard, -1.0, -0.1, 0.6, true},
    {"Transistor Crunch", SoftClipper::ClipMode::Transistor, -6.0, -0.5, 0.6, true},
    {"Vintage Diode", SoftClipper::ClipMode::Diode, -6.0, -0.5, 0.4, true},
    {"Lo-Fi Foldback", SoftClipper::ClipMode::Foldback, -6.0, -1.0, 0.7, false},
    {"Harmonic Shaper", SoftClipper::ClipMode::Waveshaper, -3.0, -0.3, 0.5, true},
    {"Bio-Reactive Quantum", SoftClipper::ClipMode::Quantum, -3.0, -0.3, 0.4, true},
    {"Mastering Glue", SoftClipper::ClipMode::Tanh, -1.0, -0.1, 0.2, true}
};

constexpr int NUM_SOFT_CLIPPER_PRESETS = sizeof(SOFT_CLIPPER_PRESETS) / sizeof(SoftClipperPreset);

} // namespace DSP
} // namespace Echoelmusic
