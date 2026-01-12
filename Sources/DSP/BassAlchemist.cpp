/**
 * BassAlchemist.cpp
 *
 * Professional low-end processing inspired by iZotope Low End Focus
 * Sub/Bass/Low-Mid split with punch, warmth, tightness, and phase alignment
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE
 */

#include <cmath>
#include <vector>
#include <array>
#include <algorithm>
#include <memory>

namespace Echoelmusic {
namespace DSP {

// ============================================================================
// Linkwitz-Riley Crossover Filter
// ============================================================================

class LinkwitzRileyCrossover {
public:
    LinkwitzRileyCrossover() { reset(); }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateCoefficients();
    }

    void setFrequency(double frequency) {
        frequency_ = std::clamp(frequency, 20.0, 20000.0);
        updateCoefficients();
    }

    void reset() {
        for (int i = 0; i < 2; i++) {
            lpState_[i].fill(0.0);
            hpState_[i].fill(0.0);
        }
    }

    // Process and split into low and high bands
    void process(double input, double& lowOut, double& highOut, int channel) {
        // First LP/HP pair
        double lp1 = processBiquad(input, lpCoeffs_, lpState_[channel], 0);
        double hp1 = processBiquad(input, hpCoeffs_, hpState_[channel], 0);

        // Second LP/HP pair (cascaded for LR4)
        lowOut = processBiquad(lp1, lpCoeffs_, lpState_[channel], 1);
        highOut = processBiquad(hp1, hpCoeffs_, hpState_[channel], 1);
    }

private:
    void updateCoefficients() {
        if (sampleRate_ <= 0) return;

        double omega = 2.0 * M_PI * frequency_ / sampleRate_;
        double sn = std::sin(omega);
        double cs = std::cos(omega);
        double Q = 0.7071067811865476;  // Butterworth Q for LR4

        double alpha = sn / (2.0 * Q);

        // Low-pass coefficients
        double b0 = (1.0 - cs) / 2.0;
        double b1 = 1.0 - cs;
        double b2 = (1.0 - cs) / 2.0;
        double a0 = 1.0 + alpha;
        double a1 = -2.0 * cs;
        double a2 = 1.0 - alpha;

        lpCoeffs_[0] = b0 / a0;
        lpCoeffs_[1] = b1 / a0;
        lpCoeffs_[2] = b2 / a0;
        lpCoeffs_[3] = a1 / a0;
        lpCoeffs_[4] = a2 / a0;

        // High-pass coefficients
        b0 = (1.0 + cs) / 2.0;
        b1 = -(1.0 + cs);
        b2 = (1.0 + cs) / 2.0;

        hpCoeffs_[0] = b0 / a0;
        hpCoeffs_[1] = b1 / a0;
        hpCoeffs_[2] = b2 / a0;
        hpCoeffs_[3] = a1 / a0;
        hpCoeffs_[4] = a2 / a0;
    }

    double processBiquad(double input, const std::array<double, 5>& coeffs,
                         std::array<double, 4>& state, int stage) {
        int offset = stage * 2;
        double output = coeffs[0] * input + coeffs[1] * state[offset] +
                        coeffs[2] * state[offset + 1] - coeffs[3] * state[offset] -
                        coeffs[4] * state[offset + 1];

        state[offset + 1] = state[offset];
        state[offset] = input;

        return output;
    }

    double sampleRate_ = 44100.0;
    double frequency_ = 100.0;

    std::array<double, 5> lpCoeffs_;
    std::array<double, 5> hpCoeffs_;
    std::array<double, 4> lpState_[2];
    std::array<double, 4> hpState_[2];
};

// ============================================================================
// Transient Shaper (for Punch control)
// ============================================================================

class TransientShaper {
public:
    TransientShaper() { reset(); }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateCoefficients();
    }

    void setAttack(double attackMs) {
        attackMs_ = std::clamp(attackMs, 0.1, 100.0);
        updateCoefficients();
    }

    void setSustain(double sustainMs) {
        sustainMs_ = std::clamp(sustainMs, 1.0, 500.0);
        updateCoefficients();
    }

    void setAttackGain(double gain) {
        attackGain_ = std::clamp(gain, -12.0, 12.0);
    }

    void setSustainGain(double gain) {
        sustainGain_ = std::clamp(gain, -12.0, 12.0);
    }

    void reset() {
        for (int ch = 0; ch < 2; ch++) {
            envelope_[ch] = 0.0;
            attackEnv_[ch] = 0.0;
            sustainEnv_[ch] = 0.0;
        }
    }

    double process(double input, int channel) {
        // Envelope follower
        double absInput = std::abs(input);
        double envCoeff = (absInput > envelope_[channel]) ? attackCoeff_ : releaseCoeff_;
        envelope_[channel] = envCoeff * envelope_[channel] + (1.0 - envCoeff) * absInput;

        // Differentiate envelope to detect transients
        double transient = envelope_[channel] - sustainEnv_[channel];
        sustainEnv_[channel] = sustainCoeff_ * sustainEnv_[channel] +
                               (1.0 - sustainCoeff_) * envelope_[channel];

        // Attack envelope (fast)
        attackEnv_[channel] = attackEnvCoeff_ * attackEnv_[channel] +
                              (1.0 - attackEnvCoeff_) * std::max(0.0, transient);

        // Calculate gain modulation
        double attackMod = attackEnv_[channel] * (std::pow(10.0, attackGain_ / 20.0) - 1.0);
        double sustainMod = (envelope_[channel] - attackEnv_[channel]) *
                            (std::pow(10.0, sustainGain_ / 20.0) - 1.0);

        double gain = 1.0 + attackMod + sustainMod;
        gain = std::clamp(gain, 0.1, 10.0);

        return input * gain;
    }

private:
    void updateCoefficients() {
        if (sampleRate_ <= 0) return;

        attackCoeff_ = std::exp(-1.0 / (sampleRate_ * attackMs_ / 1000.0));
        releaseCoeff_ = std::exp(-1.0 / (sampleRate_ * 50.0 / 1000.0));
        sustainCoeff_ = std::exp(-1.0 / (sampleRate_ * sustainMs_ / 1000.0));
        attackEnvCoeff_ = std::exp(-1.0 / (sampleRate_ * attackMs_ / 1000.0));
    }

    double sampleRate_ = 44100.0;
    double attackMs_ = 10.0;
    double sustainMs_ = 100.0;
    double attackGain_ = 0.0;
    double sustainGain_ = 0.0;

    double attackCoeff_ = 0.0;
    double releaseCoeff_ = 0.0;
    double sustainCoeff_ = 0.0;
    double attackEnvCoeff_ = 0.0;

    double envelope_[2] = {0.0, 0.0};
    double attackEnv_[2] = {0.0, 0.0};
    double sustainEnv_[2] = {0.0, 0.0};
};

// ============================================================================
// Tape Saturation (for Warmth control)
// ============================================================================

class TapeSaturation {
public:
    void setDrive(double drive) {
        drive_ = std::clamp(drive, 0.0, 1.0);
    }

    void setBias(double bias) {
        bias_ = std::clamp(bias, 0.0, 1.0);
    }

    void setTone(double tone) {
        tone_ = std::clamp(tone, 0.0, 1.0);
    }

    double process(double input) {
        // Apply drive
        double driven = input * (1.0 + drive_ * 4.0);

        // Tape saturation curve (asymmetric)
        double biasOffset = (bias_ - 0.5) * 0.2;
        driven += biasOffset;

        // Soft saturation using tanh
        double saturated = std::tanh(driven * (1.0 + drive_ * 2.0));

        // Add subtle even harmonics (tape character)
        double harmonics = saturated * saturated * saturated * 0.1 * drive_;
        saturated += harmonics;

        // Tone control (high frequency roll-off for warmth)
        double filtered = prevOutput_ * tone_ + saturated * (1.0 - tone_);
        prevOutput_ = filtered;

        // Mix and compensate gain
        double output = filtered / (1.0 + drive_ * 0.5);

        return output;
    }

    void reset() {
        prevOutput_ = 0.0;
    }

private:
    double drive_ = 0.3;
    double bias_ = 0.5;
    double tone_ = 0.3;
    double prevOutput_ = 0.0;
};

// ============================================================================
// Phase Alignment (Mono Bass Compatibility)
// ============================================================================

class PhaseAligner {
public:
    PhaseAligner() { reset(); }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateDelayBuffer();
    }

    void setMonoFrequency(double frequency) {
        monoFreq_ = std::clamp(frequency, 20.0, 500.0);
    }

    void setPhaseCorrection(bool enable) {
        phaseCorrection_ = enable;
    }

    void reset() {
        delayBuffer_.assign(delayBuffer_.size(), 0.0);
        writePos_ = 0;
        lpState_.fill(0.0);
    }

    // Process stereo pair, align phase below mono frequency
    void process(double& left, double& right) {
        // Extract low frequencies
        double monoLow = (left + right) * 0.5;

        // Low-pass filter for mono bass
        double omega = 2.0 * M_PI * monoFreq_ / sampleRate_;
        double alpha = omega / (omega + 1.0);

        lpState_[0] = alpha * monoLow + (1.0 - alpha) * lpState_[0];
        double bassContent = lpState_[0];

        // High-pass the original (everything above mono freq)
        double leftHigh = left - bassContent;
        double rightHigh = right - bassContent;

        // Phase correction for bass
        if (phaseCorrection_) {
            // Delay one channel slightly to align phase
            int readPos = (writePos_ - phaseDelaySamples_ + delayBuffer_.size()) % delayBuffer_.size();
            double delayedBass = delayBuffer_[readPos];
            delayBuffer_[writePos_] = bassContent;
            writePos_ = (writePos_ + 1) % delayBuffer_.size();

            // Use correlation to determine which channel to delay
            bassContent = (bassContent + delayedBass) * 0.5;
        }

        // Recombine: mono bass + stereo highs
        left = bassContent + leftHigh;
        right = bassContent + rightHigh;
    }

private:
    void updateDelayBuffer() {
        // Max delay of 10ms for phase alignment
        int maxDelay = static_cast<int>(sampleRate_ * 0.01);
        delayBuffer_.resize(maxDelay, 0.0);
        phaseDelaySamples_ = maxDelay / 4;  // ~2.5ms default
    }

    double sampleRate_ = 44100.0;
    double monoFreq_ = 120.0;
    bool phaseCorrection_ = true;
    int phaseDelaySamples_ = 110;

    std::vector<double> delayBuffer_;
    int writePos_ = 0;
    std::array<double, 2> lpState_;
};

// ============================================================================
// Bass Alchemist Main Class
// ============================================================================

class BassAlchemist {
public:
    BassAlchemist() {
        reset();
    }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;

        subBassXover_.setSampleRate(sampleRate);
        bassXover_.setSampleRate(sampleRate);
        transientShaper_.setSampleRate(sampleRate);
        phaseAligner_.setSampleRate(sampleRate);

        // Default crossover frequencies
        subBassXover_.setFrequency(60.0);   // Sub: 20-60 Hz
        bassXover_.setFrequency(200.0);     // Bass: 60-200 Hz, Low-mid: 200-500 Hz
    }

    void reset() {
        subBassXover_.reset();
        bassXover_.reset();
        transientShaper_.reset();
        tapeSaturation_.reset();
        phaseAligner_.reset();

        for (int ch = 0; ch < 2; ch++) {
            subBand_[ch] = 0.0;
            bassBand_[ch] = 0.0;
            lowMidBand_[ch] = 0.0;
        }
    }

    // ========== Parameters ==========

    // Sub bass (20-60 Hz)
    void setSubGain(double gainDb) {
        subGain_ = std::pow(10.0, std::clamp(gainDb, -24.0, 12.0) / 20.0);
    }

    // Bass (60-200 Hz)
    void setBassGain(double gainDb) {
        bassGain_ = std::pow(10.0, std::clamp(gainDb, -24.0, 12.0) / 20.0);
    }

    // Low-mid (200-500 Hz)
    void setLowMidGain(double gainDb) {
        lowMidGain_ = std::pow(10.0, std::clamp(gainDb, -24.0, 12.0) / 20.0);
    }

    // Punch (transient emphasis)
    void setPunch(double punch) {
        punch_ = std::clamp(punch, 0.0, 1.0);
        transientShaper_.setAttackGain(punch * 6.0);  // Up to +6dB on transients
    }

    // Warmth (tape saturation)
    void setWarmth(double warmth) {
        warmth_ = std::clamp(warmth, 0.0, 1.0);
        tapeSaturation_.setDrive(warmth * 0.6);
    }

    // Tightness (attack time)
    void setTightness(double tightness) {
        tightness_ = std::clamp(tightness, 0.0, 1.0);
        // Tighter = faster attack
        transientShaper_.setAttack(30.0 - tightness * 25.0);  // 30ms to 5ms
    }

    // Mono below frequency
    void setMonoBelow(double frequency) {
        phaseAligner_.setMonoFrequency(frequency);
    }

    // Phase correction
    void setPhaseCorrection(bool enable) {
        phaseAligner_.setPhaseCorrection(enable);
    }

    // Bio-reactive: Heart rate syncs bass pulse
    void setHeartRateSync(double heartRate, double amount) {
        heartRate_ = heartRate;
        heartRateSyncAmount_ = std::clamp(amount, 0.0, 1.0);
    }

    // Crossover frequencies
    void setSubBassFrequency(double freq) {
        subBassXover_.setFrequency(std::clamp(freq, 30.0, 100.0));
    }

    void setBassFrequency(double freq) {
        bassXover_.setFrequency(std::clamp(freq, 100.0, 300.0));
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

            // Split into 3 bands for each channel
            processBandSplit(left, 0);
            processBandSplit(right, 1);

            // Apply gains to each band
            double subL = subBand_[0] * subGain_;
            double subR = subBand_[1] * subGain_;
            double bassL = bassBand_[0] * bassGain_;
            double bassR = bassBand_[1] * bassGain_;
            double lowMidL = lowMidBand_[0] * lowMidGain_;
            double lowMidR = lowMidBand_[1] * lowMidGain_;

            // Apply punch (transient shaping) to bass band
            if (punch_ > 0.0) {
                bassL = transientShaper_.process(bassL, 0);
                bassR = transientShaper_.process(bassR, 1);
            }

            // Apply warmth (tape saturation) to bass
            if (warmth_ > 0.0) {
                bassL = tapeSaturation_.process(bassL);
                bassR = tapeSaturation_.process(bassR);
            }

            // Heart rate sync modulation
            if (heartRateSyncAmount_ > 0.0) {
                double pulse = calculateHeartPulse();
                double mod = 1.0 + (pulse - 0.5) * heartRateSyncAmount_ * 0.3;
                subL *= mod;
                subR *= mod;
            }

            // Recombine bands
            left = subL + bassL + lowMidL;
            right = subR + bassR + lowMidR;

            // Phase alignment (mono bass)
            phaseAligner_.process(left, right);

            // Mix dry/wet
            left = dryLeft * (1.0 - mix_) + left * mix_;
            right = dryRight * (1.0 - mix_) + right * mix_;

            leftChannel[i] = static_cast<float>(left);
            rightChannel[i] = static_cast<float>(right);
        }

        sampleCounter_ += numSamples;
    }

    // Process single sample (for real-time)
    void processSample(float& left, float& right) {
        process(&left, &right, 1);
    }

private:
    void processBandSplit(double input, int channel) {
        double low1, high1, low2, high2;

        // First split: sub vs (bass + low-mid)
        subBassXover_.process(input, low1, high1, channel);
        subBand_[channel] = low1;

        // Second split: bass vs low-mid
        bassXover_.process(high1, low2, high2, channel);
        bassBand_[channel] = low2;
        lowMidBand_[channel] = high2;
    }

    double calculateHeartPulse() {
        if (heartRate_ <= 0.0 || sampleRate_ <= 0.0) return 0.5;

        double beatsPerSecond = heartRate_ / 60.0;
        double samplesPerBeat = sampleRate_ / beatsPerSecond;
        double phase = std::fmod(static_cast<double>(sampleCounter_), samplesPerBeat) / samplesPerBeat;

        // Create pulse shape (sharp attack, gradual decay)
        return std::exp(-phase * 4.0);
    }

    double sampleRate_ = 44100.0;

    // Crossovers
    LinkwitzRileyCrossover subBassXover_;
    LinkwitzRileyCrossover bassXover_;

    // Processors
    TransientShaper transientShaper_;
    TapeSaturation tapeSaturation_;
    PhaseAligner phaseAligner_;

    // Band buffers
    double subBand_[2] = {0.0, 0.0};
    double bassBand_[2] = {0.0, 0.0};
    double lowMidBand_[2] = {0.0, 0.0};

    // Parameters
    double subGain_ = 1.0;
    double bassGain_ = 1.0;
    double lowMidGain_ = 1.0;
    double punch_ = 0.0;
    double warmth_ = 0.0;
    double tightness_ = 0.5;
    double mix_ = 1.0;

    // Bio-reactive
    double heartRate_ = 60.0;
    double heartRateSyncAmount_ = 0.0;

    // Sample counter for heart sync
    uint64_t sampleCounter_ = 0;
};

// ============================================================================
// Presets
// ============================================================================

struct BassAlchemistPreset {
    const char* name;
    double subGain;
    double bassGain;
    double lowMidGain;
    double punch;
    double warmth;
    double tightness;
    double monoBelow;
};

const BassAlchemistPreset BASS_ALCHEMIST_PRESETS[] = {
    {"Clean & Tight", 0.0, 0.0, 0.0, 0.3, 0.0, 0.8, 120.0},
    {"Warm Analog", 0.0, 1.0, -1.0, 0.2, 0.6, 0.5, 100.0},
    {"Heavy Sub", 3.0, 0.0, -2.0, 0.5, 0.3, 0.6, 80.0},
    {"Punchy Mix", 0.0, 2.0, 0.0, 0.7, 0.2, 0.7, 120.0},
    {"EDM Smasher", 2.0, 3.0, -3.0, 0.8, 0.4, 0.9, 150.0},
    {"Hip-Hop 808", 4.0, 1.0, -2.0, 0.4, 0.5, 0.5, 100.0},
    {"Rock Foundation", 0.0, 2.0, 1.0, 0.6, 0.3, 0.6, 120.0},
    {"Meditation Bass", 1.0, 0.0, -1.0, 0.0, 0.4, 0.3, 80.0},
    {"Bio-Reactive Pulse", 2.0, 1.0, 0.0, 0.3, 0.3, 0.5, 100.0},
    {"Mastering Touch", 0.5, 0.5, 0.0, 0.2, 0.2, 0.5, 120.0}
};

constexpr int NUM_BASS_ALCHEMIST_PRESETS = sizeof(BASS_ALCHEMIST_PRESETS) / sizeof(BassAlchemistPreset);

} // namespace DSP
} // namespace Echoelmusic
