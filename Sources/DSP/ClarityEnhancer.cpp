/**
 * ClarityEnhancer.cpp
 *
 * Intelligent clarity and presence enhancement inspired by iZotope Ozone Clarity
 * Removes mud, enhances presence, adds transparency with bio-reactive mapping
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE
 */

#include <cmath>
#include <vector>
#include <array>
#include <algorithm>
#include <complex>
#include <memory>

namespace Echoelmusic {
namespace DSP {

// ============================================================================
// FFT Processor (Simplified for Clarity Processing)
// ============================================================================

class FFTProcessor {
public:
    static constexpr int FFT_SIZE = 2048;
    static constexpr int HOP_SIZE = FFT_SIZE / 4;

    FFTProcessor() {
        // Initialize Hann window
        for (int i = 0; i < FFT_SIZE; i++) {
            window_[i] = 0.5 * (1.0 - std::cos(2.0 * M_PI * i / (FFT_SIZE - 1)));
        }
        reset();
    }

    void reset() {
        inputBuffer_.assign(FFT_SIZE * 2, 0.0);
        outputBuffer_.assign(FFT_SIZE * 2, 0.0);
        inputPos_ = 0;
        outputPos_ = 0;
    }

    // Process with spectral callback
    using SpectralCallback = std::function<void(std::vector<std::complex<double>>&)>;

    void process(const double* input, double* output, int numSamples,
                 SpectralCallback callback) {
        for (int i = 0; i < numSamples; i++) {
            // Add to input buffer
            inputBuffer_[inputPos_] = input[i];
            inputPos_ = (inputPos_ + 1) % (FFT_SIZE * 2);

            // Output from overlap-add buffer
            output[i] = outputBuffer_[outputPos_];
            outputBuffer_[outputPos_] = 0.0;
            outputPos_ = (outputPos_ + 1) % (FFT_SIZE * 2);

            // Process FFT frame when we have enough samples
            hopCounter_++;
            if (hopCounter_ >= HOP_SIZE) {
                hopCounter_ = 0;
                processFrame(callback);
            }
        }
    }

private:
    void processFrame(SpectralCallback& callback) {
        std::vector<std::complex<double>> spectrum(FFT_SIZE);

        // Copy and window input
        for (int i = 0; i < FFT_SIZE; i++) {
            int pos = (inputPos_ - FFT_SIZE + i + FFT_SIZE * 2) % (FFT_SIZE * 2);
            spectrum[i] = std::complex<double>(inputBuffer_[pos] * window_[i], 0.0);
        }

        // Forward FFT (simplified DFT for demonstration)
        fft(spectrum, false);

        // Apply spectral processing
        callback(spectrum);

        // Inverse FFT
        fft(spectrum, true);

        // Overlap-add to output
        for (int i = 0; i < FFT_SIZE; i++) {
            int pos = (outputPos_ + i) % (FFT_SIZE * 2);
            outputBuffer_[pos] += spectrum[i].real() * window_[i] / (FFT_SIZE * 0.5);
        }
    }

    void fft(std::vector<std::complex<double>>& x, bool inverse) {
        int N = static_cast<int>(x.size());

        // Bit reversal
        for (int i = 1, j = 0; i < N; i++) {
            int bit = N >> 1;
            for (; j & bit; bit >>= 1) {
                j ^= bit;
            }
            j ^= bit;
            if (i < j) std::swap(x[i], x[j]);
        }

        // Cooley-Tukey FFT
        for (int len = 2; len <= N; len <<= 1) {
            double angle = (inverse ? 2.0 : -2.0) * M_PI / len;
            std::complex<double> wlen(std::cos(angle), std::sin(angle));

            for (int i = 0; i < N; i += len) {
                std::complex<double> w(1.0, 0.0);
                for (int j = 0; j < len / 2; j++) {
                    std::complex<double> u = x[i + j];
                    std::complex<double> v = x[i + j + len / 2] * w;
                    x[i + j] = u + v;
                    x[i + j + len / 2] = u - v;
                    w *= wlen;
                }
            }
        }

        if (inverse) {
            for (auto& val : x) {
                val /= N;
            }
        }
    }

    std::array<double, FFT_SIZE> window_;
    std::vector<double> inputBuffer_;
    std::vector<double> outputBuffer_;
    int inputPos_ = 0;
    int outputPos_ = 0;
    int hopCounter_ = 0;
};

// ============================================================================
// Dynamic EQ Band (for Mud Removal)
// ============================================================================

class DynamicEQBand {
public:
    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateCoefficients();
    }

    void setFrequency(double frequency) {
        frequency_ = std::clamp(frequency, 20.0, 20000.0);
        updateCoefficients();
    }

    void setQ(double q) {
        q_ = std::clamp(q, 0.1, 10.0);
        updateCoefficients();
    }

    void setThreshold(double thresholdDb) {
        threshold_ = thresholdDb;
    }

    void setRatio(double ratio) {
        ratio_ = std::max(1.0, ratio);
    }

    void setMaxCut(double maxCutDb) {
        maxCut_ = std::clamp(maxCutDb, -24.0, 0.0);
    }

    void reset() {
        state_.fill(0.0);
        envelope_ = 0.0;
    }

    double process(double input) {
        // Band-pass filter to isolate frequency region
        double bp = processBiquad(input);

        // Envelope follower on band-passed signal
        double level = std::abs(bp);
        double coeff = level > envelope_ ? attackCoeff_ : releaseCoeff_;
        envelope_ = coeff * envelope_ + (1.0 - coeff) * level;

        // Calculate dynamic gain reduction
        double levelDb = 20.0 * std::log10(envelope_ + 1e-10);
        double gainDb = 0.0;

        if (levelDb > threshold_) {
            double excess = levelDb - threshold_;
            gainDb = -excess * (1.0 - 1.0 / ratio_);
            gainDb = std::max(gainDb, maxCut_);
        }

        // Apply bell EQ cut
        double gain = std::pow(10.0, gainDb / 20.0);
        return input * (1.0 - bandAmount_) + input * gain * bandAmount_;
    }

private:
    void updateCoefficients() {
        if (sampleRate_ <= 0) return;

        double omega = 2.0 * M_PI * frequency_ / sampleRate_;
        double alpha = std::sin(omega) / (2.0 * q_);

        double a0 = 1.0 + alpha;
        coeffs_[0] = alpha / a0;
        coeffs_[1] = 0.0;
        coeffs_[2] = -alpha / a0;
        coeffs_[3] = -2.0 * std::cos(omega) / a0;
        coeffs_[4] = (1.0 - alpha) / a0;

        // Attack/release for envelope
        attackCoeff_ = std::exp(-1.0 / (sampleRate_ * 0.001));  // 1ms attack
        releaseCoeff_ = std::exp(-1.0 / (sampleRate_ * 0.050)); // 50ms release
    }

    double processBiquad(double input) {
        double output = coeffs_[0] * input + coeffs_[1] * state_[0] +
                        coeffs_[2] * state_[1] - coeffs_[3] * state_[2] -
                        coeffs_[4] * state_[3];

        state_[1] = state_[0];
        state_[0] = input;
        state_[3] = state_[2];
        state_[2] = output;

        return output;
    }

    double sampleRate_ = 44100.0;
    double frequency_ = 300.0;
    double q_ = 2.0;
    double threshold_ = -20.0;
    double ratio_ = 4.0;
    double maxCut_ = -6.0;
    double bandAmount_ = 0.5;

    std::array<double, 5> coeffs_;
    std::array<double, 4> state_;
    double envelope_ = 0.0;
    double attackCoeff_ = 0.0;
    double releaseCoeff_ = 0.0;
};

// ============================================================================
// Presence Enhancer (Harmonic Exciter)
// ============================================================================

class PresenceEnhancer {
public:
    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateFilters();
    }

    void setFrequency(double frequency) {
        frequency_ = std::clamp(frequency, 1000.0, 10000.0);
        updateFilters();
    }

    void setAmount(double amount) {
        amount_ = std::clamp(amount, 0.0, 1.0);
    }

    void setHarmonics(double harmonics) {
        harmonics_ = std::clamp(harmonics, 0.0, 1.0);
    }

    void reset() {
        hpState_.fill(0.0);
        lpState_.fill(0.0);
    }

    double process(double input) {
        // High-pass to isolate presence region
        double hp = processHP(input);

        // Generate harmonics through soft saturation
        double saturated = std::tanh(hp * (1.0 + harmonics_ * 3.0));

        // Add even harmonics
        double harmonicContent = saturated * saturated * std::copysign(1.0, saturated) * harmonics_;

        // Low-pass to smooth harmonics
        double smoothed = processLP(harmonicContent);

        // Mix
        return input + smoothed * amount_;
    }

private:
    void updateFilters() {
        if (sampleRate_ <= 0) return;

        // High-pass coefficients
        double omegaHP = 2.0 * M_PI * frequency_ / sampleRate_;
        double alphaHP = omegaHP / (omegaHP + 1.0);
        hpCoeff_ = 1.0 - alphaHP;

        // Low-pass coefficients (2x frequency for harmonics)
        double omegaLP = 2.0 * M_PI * std::min(frequency_ * 3.0, sampleRate_ * 0.45) / sampleRate_;
        lpCoeff_ = omegaLP / (omegaLP + 1.0);
    }

    double processHP(double input) {
        hpState_[0] = hpCoeff_ * (hpState_[0] + input - hpState_[1]);
        hpState_[1] = input;
        return hpState_[0];
    }

    double processLP(double input) {
        lpState_[0] = lpCoeff_ * input + (1.0 - lpCoeff_) * lpState_[0];
        return lpState_[0];
    }

    double sampleRate_ = 44100.0;
    double frequency_ = 3000.0;
    double amount_ = 0.3;
    double harmonics_ = 0.3;

    double hpCoeff_ = 0.0;
    double lpCoeff_ = 0.0;
    std::array<double, 2> hpState_;
    std::array<double, 1> lpState_;
};

// ============================================================================
// Stereo Width Enhancer
// ============================================================================

class StereoWidthEnhancer {
public:
    void setWidth(double width) {
        width_ = std::clamp(width, 0.0, 2.0);
    }

    void setLowFreqWidth(double width) {
        lowFreqWidth_ = std::clamp(width, 0.0, 1.0);
    }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        updateFilters();
    }

    void process(double& left, double& right) {
        // Split into low and high
        double lowL = lpState_[0] = lpCoeff_ * left + (1.0 - lpCoeff_) * lpState_[0];
        double lowR = lpState_[1] = lpCoeff_ * right + (1.0 - lpCoeff_) * lpState_[1];
        double highL = left - lowL;
        double highR = right - lowR;

        // Mid-side encoding for highs
        double midHigh = (highL + highR) * 0.5;
        double sideHigh = (highL - highR) * 0.5;

        // Apply width to side channel
        sideHigh *= width_;

        // Decode back to stereo
        highL = midHigh + sideHigh;
        highR = midHigh - sideHigh;

        // Apply reduced width to lows (keep bass mono-compatible)
        double midLow = (lowL + lowR) * 0.5;
        double sideLow = (lowL - lowR) * 0.5;
        sideLow *= lowFreqWidth_;
        lowL = midLow + sideLow;
        lowR = midLow - sideLow;

        // Recombine
        left = lowL + highL;
        right = lowR + highR;
    }

private:
    void updateFilters() {
        double omega = 2.0 * M_PI * 200.0 / sampleRate_;  // 200 Hz crossover
        lpCoeff_ = omega / (omega + 1.0);
    }

    double sampleRate_ = 44100.0;
    double width_ = 1.0;
    double lowFreqWidth_ = 0.5;
    double lpCoeff_ = 0.0;
    double lpState_[2] = {0.0, 0.0};
};

// ============================================================================
// Clarity Enhancer Main Class
// ============================================================================

class ClarityEnhancer {
public:
    ClarityEnhancer() {
        // Initialize mud removal bands
        for (int i = 0; i < NUM_MUD_BANDS; i++) {
            mudBands_[i].setFrequency(MUD_FREQUENCIES[i]);
            mudBands_[i].setQ(2.0);
            mudBands_[i].setThreshold(-18.0);
            mudBands_[i].setRatio(4.0);
            mudBands_[i].setMaxCut(-8.0);
        }
    }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;

        for (auto& band : mudBands_) {
            band.setSampleRate(sampleRate);
        }
        presenceEnhancer_.setSampleRate(sampleRate);
        widthEnhancer_.setSampleRate(sampleRate);
    }

    void reset() {
        for (auto& band : mudBands_) {
            band.reset();
        }
        presenceEnhancer_.reset();
    }

    // ========== Parameters ==========

    // Presence (mid-high enhancement)
    void setPresence(double presence) {
        presence_ = std::clamp(presence, 0.0, 1.0);
        presenceEnhancer_.setAmount(presence * 0.5);
    }

    // Transparency (mud removal)
    void setTransparency(double transparency) {
        transparency_ = std::clamp(transparency, 0.0, 1.0);
    }

    // Width (stereo clarity)
    void setWidth(double width) {
        width_ = std::clamp(width, 0.0, 2.0);
        widthEnhancer_.setWidth(width);
    }

    // Auto-detect problem areas
    void setAutoDetect(bool enable) {
        autoDetect_ = enable;
    }

    // Processing intensity
    void setIntensity(double intensity) {
        intensity_ = std::clamp(intensity, 0.0, 1.0);
    }

    // Bio-reactive: coherence → clarity
    void setCoherenceMapping(double coherence) {
        // High coherence = more clarity processing
        if (autoDetect_) {
            double bioIntensity = 0.3 + coherence * 0.5;  // 0.3-0.8 range
            presenceEnhancer_.setAmount(presence_ * bioIntensity);
        }
    }

    // Presence frequency
    void setPresenceFrequency(double frequency) {
        presenceEnhancer_.setFrequency(frequency);
    }

    // Harmonics amount
    void setHarmonics(double harmonics) {
        presenceEnhancer_.setHarmonics(harmonics);
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

            // Apply mud removal (transparency)
            if (transparency_ > 0.0) {
                for (auto& band : mudBands_) {
                    left = band.process(left);
                    right = band.process(right);
                }

                // Blend based on transparency setting
                left = dryLeft * (1.0 - transparency_ * intensity_) +
                       left * transparency_ * intensity_;
                right = dryRight * (1.0 - transparency_ * intensity_) +
                        right * transparency_ * intensity_;
            }

            // Apply presence enhancement
            if (presence_ > 0.0) {
                left = presenceEnhancer_.process(left);
                right = presenceEnhancer_.process(right);
            }

            // Apply stereo width
            if (width_ != 1.0) {
                widthEnhancer_.process(left, right);
            }

            // Final mix
            left = dryLeft * (1.0 - mix_) + left * mix_;
            right = dryRight * (1.0 - mix_) + right * mix_;

            leftChannel[i] = static_cast<float>(left);
            rightChannel[i] = static_cast<float>(right);
        }
    }

private:
    static constexpr int NUM_MUD_BANDS = 4;
    static constexpr double MUD_FREQUENCIES[NUM_MUD_BANDS] = {200.0, 300.0, 400.0, 500.0};

    double sampleRate_ = 44100.0;

    // Processors
    std::array<DynamicEQBand, NUM_MUD_BANDS> mudBands_;
    PresenceEnhancer presenceEnhancer_;
    StereoWidthEnhancer widthEnhancer_;

    // Parameters
    double presence_ = 0.5;
    double transparency_ = 0.5;
    double width_ = 1.0;
    double intensity_ = 0.5;
    double mix_ = 1.0;
    bool autoDetect_ = true;
};

// ============================================================================
// Presets
// ============================================================================

struct ClarityEnhancerPreset {
    const char* name;
    double presence;
    double transparency;
    double width;
    double intensity;
    double presenceFreq;
    double harmonics;
};

const ClarityEnhancerPreset CLARITY_PRESETS[] = {
    {"Subtle Polish", 0.3, 0.3, 1.0, 0.4, 3000.0, 0.2},
    {"Mix Clarity", 0.5, 0.5, 1.1, 0.5, 3500.0, 0.3},
    {"Vocal Forward", 0.7, 0.4, 1.0, 0.6, 2500.0, 0.4},
    {"Remove Mud", 0.2, 0.8, 1.0, 0.7, 3000.0, 0.1},
    {"Wide & Clear", 0.5, 0.5, 1.5, 0.5, 3500.0, 0.3},
    {"Aggressive Clarity", 0.8, 0.7, 1.2, 0.8, 4000.0, 0.5},
    {"Mastering Touch", 0.3, 0.4, 1.05, 0.3, 4500.0, 0.2},
    {"Meditation Space", 0.4, 0.3, 1.3, 0.4, 2000.0, 0.2},
    {"Bio-Reactive Focus", 0.5, 0.5, 1.0, 0.5, 3000.0, 0.3},
    {"Hi-Fi Enhancement", 0.6, 0.4, 1.1, 0.5, 5000.0, 0.4}
};

constexpr int NUM_CLARITY_PRESETS = sizeof(CLARITY_PRESETS) / sizeof(ClarityEnhancerPreset);

} // namespace DSP
} // namespace Echoelmusic
