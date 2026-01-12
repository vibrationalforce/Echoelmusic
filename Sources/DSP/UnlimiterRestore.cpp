/**
 * UnlimiterRestore.cpp
 *
 * Dynamics restoration processor inspired by iZotope Ozone Unlimiter concept
 * Recovers dynamics from over-limited/over-compressed audio
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE
 */

#include <cmath>
#include <vector>
#include <array>
#include <algorithm>
#include <deque>
#include <numeric>

namespace Echoelmusic {
namespace DSP {

// ============================================================================
// Transient Detector
// ============================================================================

class TransientDetector {
public:
    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateCoefficients();
    }

    void setAttack(double attackMs) {
        attackMs_ = std::clamp(attackMs, 0.01, 10.0);
        updateCoefficients();
    }

    void setRelease(double releaseMs) {
        releaseMs_ = std::clamp(releaseMs, 1.0, 500.0);
        updateCoefficients();
    }

    void setSensitivity(double sensitivity) {
        sensitivity_ = std::clamp(sensitivity, 0.0, 1.0);
    }

    void reset() {
        fastEnv_ = 0.0;
        slowEnv_ = 0.0;
    }

    // Returns transient amount (0-1)
    double process(double input) {
        double absInput = std::abs(input);

        // Fast envelope follower (for transients)
        double fastCoeff = absInput > fastEnv_ ? fastAttackCoeff_ : fastReleaseCoeff_;
        fastEnv_ = fastCoeff * fastEnv_ + (1.0 - fastCoeff) * absInput;

        // Slow envelope follower (for sustained level)
        double slowCoeff = absInput > slowEnv_ ? slowAttackCoeff_ : slowReleaseCoeff_;
        slowEnv_ = slowCoeff * slowEnv_ + (1.0 - slowCoeff) * absInput;

        // Transient is when fast envelope exceeds slow envelope
        double transientAmount = 0.0;
        if (slowEnv_ > 1e-10) {
            transientAmount = (fastEnv_ - slowEnv_) / slowEnv_;
            transientAmount = std::max(0.0, transientAmount);
            transientAmount = std::tanh(transientAmount * sensitivity_ * 5.0);
        }

        return transientAmount;
    }

private:
    void updateCoefficients() {
        if (sampleRate_ <= 0) return;

        fastAttackCoeff_ = std::exp(-1.0 / (sampleRate_ * attackMs_ / 1000.0));
        fastReleaseCoeff_ = std::exp(-1.0 / (sampleRate_ * releaseMs_ / 1000.0 * 0.5));
        slowAttackCoeff_ = std::exp(-1.0 / (sampleRate_ * attackMs_ / 1000.0 * 10.0));
        slowReleaseCoeff_ = std::exp(-1.0 / (sampleRate_ * releaseMs_ / 1000.0 * 2.0));
    }

    double sampleRate_ = 44100.0;
    double attackMs_ = 0.5;
    double releaseMs_ = 50.0;
    double sensitivity_ = 0.5;

    double fastAttackCoeff_ = 0.0;
    double fastReleaseCoeff_ = 0.0;
    double slowAttackCoeff_ = 0.0;
    double slowReleaseCoeff_ = 0.0;

    double fastEnv_ = 0.0;
    double slowEnv_ = 0.0;
};

// ============================================================================
// Crest Factor Analyzer
// ============================================================================

class CrestFactorAnalyzer {
public:
    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateWindowSize();
    }

    void setWindowMs(double windowMs) {
        windowMs_ = std::clamp(windowMs, 10.0, 1000.0);
        updateWindowSize();
    }

    void reset() {
        peakBuffer_.clear();
        rmsBuffer_.clear();
        peakBuffer_.resize(windowSamples_, 0.0);
        rmsBuffer_.resize(windowSamples_, 0.0);
        writePos_ = 0;
    }

    // Returns crest factor in dB (typically 3-20 dB for music)
    double process(double input) {
        double absInput = std::abs(input);
        double sqInput = input * input;

        // Update circular buffers
        peakBuffer_[writePos_] = absInput;
        rmsBuffer_[writePos_] = sqInput;
        writePos_ = (writePos_ + 1) % windowSamples_;

        // Calculate peak (max in window)
        double peak = *std::max_element(peakBuffer_.begin(), peakBuffer_.end());

        // Calculate RMS
        double sumSq = std::accumulate(rmsBuffer_.begin(), rmsBuffer_.end(), 0.0);
        double rms = std::sqrt(sumSq / windowSamples_);

        // Crest factor = peak / RMS
        if (rms > 1e-10) {
            double crestFactor = peak / rms;
            return 20.0 * std::log10(crestFactor);
        }
        return 0.0;
    }

    // Get current crest factor in dB
    double getCrestFactorDb() const {
        double peak = *std::max_element(peakBuffer_.begin(), peakBuffer_.end());
        double sumSq = std::accumulate(rmsBuffer_.begin(), rmsBuffer_.end(), 0.0);
        double rms = std::sqrt(sumSq / std::max(1, static_cast<int>(rmsBuffer_.size())));

        if (rms > 1e-10) {
            return 20.0 * std::log10(peak / rms);
        }
        return 0.0;
    }

private:
    void updateWindowSize() {
        windowSamples_ = static_cast<int>(sampleRate_ * windowMs_ / 1000.0);
        windowSamples_ = std::max(1, windowSamples_);
        reset();
    }

    double sampleRate_ = 44100.0;
    double windowMs_ = 100.0;
    int windowSamples_ = 4410;

    std::vector<double> peakBuffer_;
    std::vector<double> rmsBuffer_;
    int writePos_ = 0;
};

// ============================================================================
// Dynamics Expander
// ============================================================================

class DynamicsExpander {
public:
    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateCoefficients();
    }

    void setThreshold(double thresholdDb) {
        threshold_ = std::pow(10.0, thresholdDb / 20.0);
    }

    void setRatio(double ratio) {
        ratio_ = std::max(1.0, ratio);
    }

    void setAttack(double attackMs) {
        attackMs_ = std::clamp(attackMs, 0.01, 100.0);
        updateCoefficients();
    }

    void setRelease(double releaseMs) {
        releaseMs_ = std::clamp(releaseMs, 1.0, 1000.0);
        updateCoefficients();
    }

    void setRange(double rangeDb) {
        range_ = std::pow(10.0, std::clamp(rangeDb, 0.0, 24.0) / 20.0);
    }

    void reset() {
        envelope_ = 0.0;
        gainSmooth_ = 1.0;
    }

    double process(double input) {
        double absInput = std::abs(input);

        // Envelope follower
        double coeff = absInput > envelope_ ? attackCoeff_ : releaseCoeff_;
        envelope_ = coeff * envelope_ + (1.0 - coeff) * absInput;

        // Calculate expansion gain
        double gain = 1.0;
        if (envelope_ < threshold_ && envelope_ > 1e-10) {
            double dB = 20.0 * std::log10(envelope_ / threshold_);
            double expandDb = dB * (ratio_ - 1.0);
            expandDb = std::max(expandDb, -20.0 * std::log10(range_));
            gain = std::pow(10.0, expandDb / 20.0);
        }

        // Smooth gain changes
        gainSmooth_ = 0.99 * gainSmooth_ + 0.01 * gain;

        return input * gainSmooth_;
    }

private:
    void updateCoefficients() {
        if (sampleRate_ <= 0) return;

        attackCoeff_ = std::exp(-1.0 / (sampleRate_ * attackMs_ / 1000.0));
        releaseCoeff_ = std::exp(-1.0 / (sampleRate_ * releaseMs_ / 1000.0));
    }

    double sampleRate_ = 44100.0;
    double threshold_ = 0.1;
    double ratio_ = 2.0;
    double attackMs_ = 0.5;
    double releaseMs_ = 50.0;
    double range_ = 2.0;

    double attackCoeff_ = 0.0;
    double releaseCoeff_ = 0.0;
    double envelope_ = 0.0;
    double gainSmooth_ = 1.0;
};

// ============================================================================
// Multiband Dynamics Restorer
// ============================================================================

class MultibandDynamicsRestorer {
public:
    static constexpr int NUM_BANDS = 4;

    MultibandDynamicsRestorer() {
        // Default crossover frequencies
        crossoverFreqs_[0] = 100.0;   // Low band
        crossoverFreqs_[1] = 1000.0;  // Low-mid
        crossoverFreqs_[2] = 5000.0;  // High-mid to high
    }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateFilters();

        for (auto& detector : transientDetectors_) {
            detector.setSampleRate(sampleRate);
        }
        for (auto& expander : expanders_) {
            expander.setSampleRate(sampleRate);
        }
    }

    void reset() {
        for (int i = 0; i < NUM_BANDS; i++) {
            lpState_[i].fill(0.0);
            hpState_[i].fill(0.0);
            transientDetectors_[i].reset();
            expanders_[i].reset();
            bandBuffers_[i] = 0.0;
        }
    }

    // Set recovery amount per band (0-1)
    void setBandRecovery(int band, double amount) {
        if (band >= 0 && band < NUM_BANDS) {
            bandRecovery_[band] = std::clamp(amount, 0.0, 1.0);
        }
    }

    double process(double input) {
        // Split into bands
        splitBands(input);

        // Process each band
        double output = 0.0;
        for (int i = 0; i < NUM_BANDS; i++) {
            double band = bandBuffers_[i];

            // Detect transients
            double transient = transientDetectors_[i].process(band);

            // Apply expansion
            double expanded = expanders_[i].process(band);

            // Blend based on recovery amount and transient detection
            double recovery = bandRecovery_[i] * (1.0 + transient * 0.5);
            band = band * (1.0 - recovery) + expanded * recovery;

            output += band;
        }

        return output;
    }

private:
    void updateFilters() {
        for (int i = 0; i < NUM_BANDS - 1; i++) {
            double omega = 2.0 * M_PI * crossoverFreqs_[i] / sampleRate_;
            filterCoeffs_[i] = omega / (omega + 1.0);
        }
    }

    void splitBands(double input) {
        // Cascaded low-pass / high-pass for crossover
        double remaining = input;

        for (int i = 0; i < NUM_BANDS - 1; i++) {
            // Low-pass for this band
            lpState_[i][0] = filterCoeffs_[i] * remaining + (1.0 - filterCoeffs_[i]) * lpState_[i][0];
            bandBuffers_[i] = lpState_[i][0];

            // High-pass for remaining
            remaining = remaining - bandBuffers_[i];
        }

        // Last band gets the remainder
        bandBuffers_[NUM_BANDS - 1] = remaining;
    }

    double sampleRate_ = 44100.0;

    double crossoverFreqs_[NUM_BANDS - 1];
    double filterCoeffs_[NUM_BANDS - 1];
    std::array<double, 2> lpState_[NUM_BANDS];
    std::array<double, 2> hpState_[NUM_BANDS];
    double bandBuffers_[NUM_BANDS];
    double bandRecovery_[NUM_BANDS] = {0.5, 0.5, 0.5, 0.5};

    std::array<TransientDetector, NUM_BANDS> transientDetectors_;
    std::array<DynamicsExpander, NUM_BANDS> expanders_;
};

// ============================================================================
// Unlimiter Restore Main Class
// ============================================================================

class UnlimiterRestore {
public:
    UnlimiterRestore() {
        reset();
    }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;

        for (int ch = 0; ch < 2; ch++) {
            transientDetector_[ch].setSampleRate(sampleRate);
            crestAnalyzer_[ch].setSampleRate(sampleRate);
            multibandRestorer_[ch].setSampleRate(sampleRate);
        }
    }

    void reset() {
        for (int ch = 0; ch < 2; ch++) {
            transientDetector_[ch].reset();
            crestAnalyzer_[ch].reset();
            multibandRestorer_[ch].reset();
        }
    }

    // ========== Parameters ==========

    // Overall recovery amount (0-1)
    void setRecoveryAmount(double amount) {
        recoveryAmount_ = std::clamp(amount, 0.0, 1.0);
    }

    // Transient restoration (0-1)
    void setTransientRestore(double amount) {
        transientRestore_ = std::clamp(amount, 0.0, 1.0);
    }

    // Peak restoration (0-1)
    void setPeakRestore(double amount) {
        peakRestore_ = std::clamp(amount, 0.0, 1.0);
    }

    // Enable multiband processing
    void setMultiband(bool enable) {
        multiband_ = enable;
    }

    // Intelligent over-limiting detection
    void setIntelligentDetect(double amount) {
        intelligentDetect_ = std::clamp(amount, 0.0, 1.0);
    }

    // Target crest factor in dB (for intelligent mode)
    void setTargetCrestFactor(double crestDb) {
        targetCrestFactor_ = std::clamp(crestDb, 6.0, 20.0);
    }

    // Per-band recovery (for multiband mode)
    void setBandRecovery(int band, double amount) {
        for (int ch = 0; ch < 2; ch++) {
            multibandRestorer_[ch].setBandRecovery(band, amount);
        }
    }

    // Bio-reactive: breathing syncs dynamics
    void setBreathingSync(double breathPhase, double amount) {
        breathPhase_ = breathPhase;
        breathingSyncAmount_ = std::clamp(amount, 0.0, 1.0);
    }

    // Mix
    void setMix(double mix) {
        mix_ = std::clamp(mix, 0.0, 1.0);
    }

    // ========== Processing ==========

    void process(float* leftChannel, float* rightChannel, int numSamples) {
        for (int i = 0; i < numSamples; i++) {
            double left = static_cast<double>(leftChannel[i]);
            double right = static_cast<double>(rightChannel[i]);

            double dryLeft = left;
            double dryRight = right;

            // Analyze current crest factor
            double crestL = crestAnalyzer_[0].process(left);
            double crestR = crestAnalyzer_[1].process(right);
            double avgCrest = (crestL + crestR) * 0.5;

            // Calculate how much restoration is needed
            double needsRestoration = calculateRestorationNeed(avgCrest);

            // Apply breathing sync modulation
            double dynamicAmount = recoveryAmount_;
            if (breathingSyncAmount_ > 0.0) {
                // Inhale = more dynamics, exhale = less
                double breathMod = std::sin(breathPhase_ * 2.0 * M_PI);
                dynamicAmount *= (1.0 + breathMod * breathingSyncAmount_ * 0.3);
            }

            // Process left channel
            left = processChannel(left, 0, dynamicAmount, needsRestoration);

            // Process right channel
            right = processChannel(right, 1, dynamicAmount, needsRestoration);

            // Mix
            left = dryLeft * (1.0 - mix_) + left * mix_;
            right = dryRight * (1.0 - mix_) + right * mix_;

            leftChannel[i] = static_cast<float>(left);
            rightChannel[i] = static_cast<float>(right);
        }
    }

    // Get current crest factor (for metering)
    double getCurrentCrestFactor() const {
        return (crestAnalyzer_[0].getCrestFactorDb() + crestAnalyzer_[1].getCrestFactorDb()) * 0.5;
    }

private:
    double calculateRestorationNeed(double currentCrest) {
        if (!intelligentDetect_) return 1.0;

        // Calculate how much below target crest we are
        double deficit = targetCrestFactor_ - currentCrest;
        if (deficit <= 0) return 0.0;  // Already has good dynamics

        // Scale restoration need based on deficit
        double need = std::tanh(deficit / 6.0);  // 6dB deficit = ~0.76 need
        return need * intelligentDetect_;
    }

    double processChannel(double input, int channel, double amount, double need) {
        // Detect transients
        double transient = transientDetector_[channel].process(input);

        // Transient restoration
        double transientBoost = 1.0 + transient * transientRestore_ * amount * need * 0.5;

        // Peak restoration (gentle expansion)
        double absInput = std::abs(input);
        double peakBoost = 1.0;
        if (absInput > 0.5 && peakRestore_ > 0.0) {
            // Boost peaks that are being squashed
            peakBoost = 1.0 + (absInput - 0.5) * peakRestore_ * amount * need * 0.3;
        }

        double processed = input * transientBoost * peakBoost;

        // Multiband processing
        if (multiband_) {
            double mbProcessed = multibandRestorer_[channel].process(input);
            processed = processed * (1.0 - amount) + mbProcessed * amount;
        }

        // Soft limit to prevent clipping
        if (std::abs(processed) > 0.99) {
            processed = std::tanh(processed);
        }

        return processed;
    }

    double sampleRate_ = 44100.0;

    // Processors
    TransientDetector transientDetector_[2];
    CrestFactorAnalyzer crestAnalyzer_[2];
    MultibandDynamicsRestorer multibandRestorer_[2];

    // Parameters
    double recoveryAmount_ = 0.5;
    double transientRestore_ = 0.5;
    double peakRestore_ = 0.3;
    bool multiband_ = true;
    double intelligentDetect_ = 0.5;
    double targetCrestFactor_ = 12.0;  // dB
    double mix_ = 1.0;

    // Bio-reactive
    double breathPhase_ = 0.0;
    double breathingSyncAmount_ = 0.0;
};

// ============================================================================
// Presets
// ============================================================================

struct UnlimiterRestorePreset {
    const char* name;
    double recoveryAmount;
    double transientRestore;
    double peakRestore;
    bool multiband;
    double intelligentDetect;
    double targetCrest;
};

const UnlimiterRestorePreset UNLIMITER_PRESETS[] = {
    {"Subtle Recovery", 0.3, 0.3, 0.2, false, 0.5, 10.0},
    {"Moderate Restore", 0.5, 0.5, 0.3, true, 0.5, 12.0},
    {"Aggressive Recovery", 0.7, 0.7, 0.5, true, 0.7, 14.0},
    {"Transient Focus", 0.5, 0.8, 0.2, false, 0.3, 12.0},
    {"Peak Emphasis", 0.4, 0.3, 0.7, false, 0.3, 10.0},
    {"Multiband Precision", 0.5, 0.5, 0.4, true, 0.6, 12.0},
    {"Loudness War Fix", 0.8, 0.6, 0.6, true, 0.8, 14.0},
    {"Broadcast Restore", 0.4, 0.4, 0.3, true, 0.5, 10.0},
    {"Bio-Reactive Breath", 0.5, 0.5, 0.4, true, 0.5, 12.0},
    {"Mastering Touch", 0.3, 0.4, 0.3, true, 0.4, 11.0}
};

constexpr int NUM_UNLIMITER_PRESETS = sizeof(UNLIMITER_PRESETS) / sizeof(UnlimiterRestorePreset);

} // namespace DSP
} // namespace Echoelmusic
