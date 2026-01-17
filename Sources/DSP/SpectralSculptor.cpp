/**
 * SpectralSculptor.cpp
 * Echoelmusic - Spectral Processing Suite
 *
 * FFT-based spectral manipulation for creative sound design
 * Inspired by iZotope Iris, Zynaptiq Morph, Sonic Charge Echobode
 *
 * Features:
 * - Real-time FFT analysis (up to 8192 bins)
 * - Spectral freeze/blur/smear
 * - Frequency shifting
 * - Spectral gate/filter
 * - Harmonic enhancement
 * - Bio-reactive spectral modulation
 *
 * Created: 2026-01-15
 */

#include <cmath>
#include <complex>
#include <vector>
#include <array>
#include <algorithm>

namespace Echoelmusic {
namespace DSP {

// ============================================================================
// Constants
// ============================================================================

constexpr float PI = 3.14159265358979323846f;
constexpr float TWO_PI = 2.0f * PI;
constexpr int MAX_FFT_SIZE = 8192;
constexpr int DEFAULT_FFT_SIZE = 2048;

// ============================================================================
// FFT Implementation (Cooley-Tukey Radix-2)
// ============================================================================

class FFT {
public:
    FFT(int size) : fftSize(size), logSize(log2i(size)) {
        // Precompute twiddle factors
        twiddleFactors.resize(size / 2);
        for (int i = 0; i < size / 2; ++i) {
            float angle = -TWO_PI * i / size;
            twiddleFactors[i] = std::complex<float>(std::cos(angle), std::sin(angle));
        }

        // Precompute bit-reversal indices
        bitReversed.resize(size);
        for (int i = 0; i < size; ++i) {
            bitReversed[i] = reverseBits(i, logSize);
        }
    }

    void forward(std::complex<float>* data) {
        // Bit-reversal permutation
        for (int i = 0; i < fftSize; ++i) {
            if (i < bitReversed[i]) {
                std::swap(data[i], data[bitReversed[i]]);
            }
        }

        // Cooley-Tukey iterative FFT
        for (int s = 1; s <= logSize; ++s) {
            int m = 1 << s;
            int m2 = m >> 1;
            int twiddleStep = fftSize / m;

            for (int k = 0; k < fftSize; k += m) {
                for (int j = 0; j < m2; ++j) {
                    std::complex<float> t = twiddleFactors[j * twiddleStep] * data[k + j + m2];
                    std::complex<float> u = data[k + j];
                    data[k + j] = u + t;
                    data[k + j + m2] = u - t;
                }
            }
        }
    }

    void inverse(std::complex<float>* data) {
        // Conjugate
        for (int i = 0; i < fftSize; ++i) {
            data[i] = std::conj(data[i]);
        }

        // Forward FFT
        forward(data);

        // Conjugate and scale
        float scale = 1.0f / fftSize;
        for (int i = 0; i < fftSize; ++i) {
            data[i] = std::conj(data[i]) * scale;
        }
    }

    int getSize() const { return fftSize; }

private:
    int fftSize;
    int logSize;
    std::vector<std::complex<float>> twiddleFactors;
    std::vector<int> bitReversed;

    static int log2i(int n) {
        int result = 0;
        while (n > 1) {
            n >>= 1;
            ++result;
        }
        return result;
    }

    static int reverseBits(int n, int bits) {
        int result = 0;
        for (int i = 0; i < bits; ++i) {
            result = (result << 1) | (n & 1);
            n >>= 1;
        }
        return result;
    }
};

// ============================================================================
// Window Functions
// ============================================================================

enum class WindowType {
    Hann,
    Hamming,
    Blackman,
    Kaiser,
    FlatTop
};

class WindowFunction {
public:
    static void apply(float* buffer, int size, WindowType type) {
        for (int i = 0; i < size; ++i) {
            buffer[i] *= getWindowValue(i, size, type);
        }
    }

    static float getWindowValue(int i, int size, WindowType type) {
        float n = static_cast<float>(i) / static_cast<float>(size - 1);

        switch (type) {
            case WindowType::Hann:
                return 0.5f * (1.0f - std::cos(TWO_PI * n));

            case WindowType::Hamming:
                return 0.54f - 0.46f * std::cos(TWO_PI * n);

            case WindowType::Blackman:
                return 0.42f - 0.5f * std::cos(TWO_PI * n) + 0.08f * std::cos(4.0f * PI * n);

            case WindowType::Kaiser: {
                float alpha = 3.0f;
                float x = 2.0f * n - 1.0f;
                return bessel0(alpha * std::sqrt(1.0f - x * x)) / bessel0(alpha);
            }

            case WindowType::FlatTop:
                return 0.21557895f - 0.41663158f * std::cos(TWO_PI * n)
                     + 0.277263158f * std::cos(4.0f * PI * n)
                     - 0.083578947f * std::cos(6.0f * PI * n)
                     + 0.006947368f * std::cos(8.0f * PI * n);
        }
        return 1.0f;
    }

private:
    static float bessel0(float x) {
        float sum = 1.0f;
        float term = 1.0f;
        for (int k = 1; k < 20; ++k) {
            term *= (x * x) / (4.0f * k * k);
            sum += term;
        }
        return sum;
    }
};

// ============================================================================
// Spectral Sculpting Modes
// ============================================================================

enum class SpectralMode {
    Bypass,
    Freeze,          // Hold current spectrum
    Blur,            // Smear spectrum across bins
    Shift,           // Frequency shifting
    Gate,            // Spectral noise gate
    Filter,          // Spectral filtering
    Harmonics,       // Harmonic enhancement
    Robotize,        // Quantize to pitch grid
    Whisper,         // Remove harmonics, keep noise
    BioReactive      // Bio-data driven modulation
};

// ============================================================================
// Spectral Sculpting Processor
// ============================================================================

class SpectralSculptor {
public:
    SpectralSculptor(int fftSize = DEFAULT_FFT_SIZE)
        : fftSize(fftSize), fft(fftSize), hopSize(fftSize / 4) {

        // Allocate buffers
        inputBuffer.resize(fftSize, 0.0f);
        outputBuffer.resize(fftSize, 0.0f);
        fftBuffer.resize(fftSize);
        frozenSpectrum.resize(fftSize / 2 + 1);
        magnitudes.resize(fftSize / 2 + 1);
        phases.resize(fftSize / 2 + 1);
        window.resize(fftSize);

        // Generate window
        for (int i = 0; i < fftSize; ++i) {
            window[i] = WindowFunction::getWindowValue(i, fftSize, WindowType::Hann);
        }
    }

    void setSampleRate(float sr) {
        sampleRate = sr;
        binFrequency = sr / static_cast<float>(fftSize);
    }

    void setMode(SpectralMode newMode) {
        mode = newMode;
    }

    // ========================================================================
    // Parameters
    // ========================================================================

    void setBlurAmount(float amount) {
        blurAmount = std::clamp(amount, 0.0f, 1.0f);
    }

    void setFrequencyShift(float shiftHz) {
        frequencyShift = shiftHz;
    }

    void setGateThreshold(float thresholdDb) {
        gateThreshold = std::pow(10.0f, thresholdDb / 20.0f);
    }

    void setFilterCutoff(float cutoffHz) {
        filterCutoff = cutoffHz;
    }

    void setFilterResonance(float q) {
        filterResonance = q;
    }

    void setHarmonicBoost(float boostDb) {
        harmonicBoost = std::pow(10.0f, boostDb / 20.0f);
    }

    void setRobotizePitch(float pitchHz) {
        robotizePitch = pitchHz;
    }

    void setFreeze(bool freeze) {
        if (freeze && !isFrozen) {
            // Capture current spectrum
            for (int i = 0; i <= fftSize / 2; ++i) {
                frozenSpectrum[i] = magnitudes[i];
            }
        }
        isFrozen = freeze;
    }

    // ========================================================================
    // Bio-Reactive Modulation
    // ========================================================================

    void setBioModulation(float coherence, float heartRate, float breathPhase) {
        bioCoherence = coherence;
        bioHeartRate = heartRate;
        bioBreathPhase = breathPhase;
    }

    // ========================================================================
    // Processing
    // ========================================================================

    void process(float* input, float* output, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            // Add sample to input buffer
            inputBuffer[inputBufferPos] = input[i];
            inputBufferPos = (inputBufferPos + 1) % fftSize;

            // Output from overlap-add buffer
            output[i] = outputBuffer[outputBufferPos];
            outputBuffer[outputBufferPos] = 0.0f;
            outputBufferPos = (outputBufferPos + 1) % fftSize;

            // Process FFT frame every hopSize samples
            if (++sampleCounter >= hopSize) {
                sampleCounter = 0;
                processFFTFrame();
            }
        }
    }

private:
    int fftSize;
    FFT fft;
    int hopSize;
    float sampleRate = 48000.0f;
    float binFrequency = 23.4375f;

    SpectralMode mode = SpectralMode::Bypass;

    // Buffers
    std::vector<float> inputBuffer;
    std::vector<float> outputBuffer;
    std::vector<std::complex<float>> fftBuffer;
    std::vector<float> frozenSpectrum;
    std::vector<float> magnitudes;
    std::vector<float> phases;
    std::vector<float> window;

    int inputBufferPos = 0;
    int outputBufferPos = 0;
    int sampleCounter = 0;

    // Parameters
    float blurAmount = 0.5f;
    float frequencyShift = 0.0f;
    float gateThreshold = 0.01f;
    float filterCutoff = 5000.0f;
    float filterResonance = 1.0f;
    float harmonicBoost = 1.0f;
    float robotizePitch = 100.0f;
    bool isFrozen = false;

    // Bio-reactive state
    float bioCoherence = 0.0f;
    float bioHeartRate = 72.0f;
    float bioBreathPhase = 0.0f;

    // ========================================================================
    // FFT Frame Processing
    // ========================================================================

    void processFFTFrame() {
        // Copy input to FFT buffer with window
        int readPos = (inputBufferPos - fftSize + fftSize) % fftSize;
        for (int i = 0; i < fftSize; ++i) {
            int idx = (readPos + i) % fftSize;
            fftBuffer[i] = std::complex<float>(inputBuffer[idx] * window[i], 0.0f);
        }

        // Forward FFT
        fft.forward(fftBuffer.data());

        // Convert to magnitude/phase
        for (int i = 0; i <= fftSize / 2; ++i) {
            magnitudes[i] = std::abs(fftBuffer[i]);
            phases[i] = std::arg(fftBuffer[i]);
        }

        // Apply spectral processing based on mode
        applySpectralProcessing();

        // Convert back to complex
        for (int i = 0; i <= fftSize / 2; ++i) {
            fftBuffer[i] = std::polar(magnitudes[i], phases[i]);
            if (i > 0 && i < fftSize / 2) {
                fftBuffer[fftSize - i] = std::conj(fftBuffer[i]);
            }
        }

        // Inverse FFT
        fft.inverse(fftBuffer.data());

        // Overlap-add to output
        int writePos = outputBufferPos;
        for (int i = 0; i < fftSize; ++i) {
            int idx = (writePos + i) % fftSize;
            outputBuffer[idx] += fftBuffer[i].real() * window[i];
        }
    }

    void applySpectralProcessing() {
        switch (mode) {
            case SpectralMode::Bypass:
                break;

            case SpectralMode::Freeze:
                applyFreeze();
                break;

            case SpectralMode::Blur:
                applyBlur();
                break;

            case SpectralMode::Shift:
                applyFrequencyShift();
                break;

            case SpectralMode::Gate:
                applySpectralGate();
                break;

            case SpectralMode::Filter:
                applySpectralFilter();
                break;

            case SpectralMode::Harmonics:
                applyHarmonicEnhancement();
                break;

            case SpectralMode::Robotize:
                applyRobotize();
                break;

            case SpectralMode::Whisper:
                applyWhisper();
                break;

            case SpectralMode::BioReactive:
                applyBioReactiveModulation();
                break;
        }
    }

    // ========================================================================
    // Spectral Effects
    // ========================================================================

    void applyFreeze() {
        if (isFrozen) {
            for (int i = 0; i <= fftSize / 2; ++i) {
                magnitudes[i] = frozenSpectrum[i];
            }
        }
    }

    void applyBlur() {
        std::vector<float> blurred(fftSize / 2 + 1);
        int blurRadius = static_cast<int>(blurAmount * 50.0f) + 1;

        for (int i = 0; i <= fftSize / 2; ++i) {
            float sum = 0.0f;
            int count = 0;

            for (int j = -blurRadius; j <= blurRadius; ++j) {
                int idx = i + j;
                if (idx >= 0 && idx <= fftSize / 2) {
                    sum += magnitudes[idx];
                    ++count;
                }
            }

            blurred[i] = sum / count;
        }

        // Blend original and blurred
        for (int i = 0; i <= fftSize / 2; ++i) {
            magnitudes[i] = magnitudes[i] * (1.0f - blurAmount) + blurred[i] * blurAmount;
        }
    }

    void applyFrequencyShift() {
        int shiftBins = static_cast<int>(frequencyShift / binFrequency);
        std::vector<float> shifted(fftSize / 2 + 1, 0.0f);

        for (int i = 0; i <= fftSize / 2; ++i) {
            int targetBin = i + shiftBins;
            if (targetBin >= 0 && targetBin <= fftSize / 2) {
                shifted[targetBin] = magnitudes[i];
            }
        }

        magnitudes = shifted;
    }

    void applySpectralGate() {
        float maxMag = *std::max_element(magnitudes.begin(), magnitudes.end());
        float threshold = maxMag * gateThreshold;

        for (int i = 0; i <= fftSize / 2; ++i) {
            if (magnitudes[i] < threshold) {
                magnitudes[i] = 0.0f;
            }
        }
    }

    void applySpectralFilter() {
        int cutoffBin = static_cast<int>(filterCutoff / binFrequency);

        for (int i = 0; i <= fftSize / 2; ++i) {
            float freq = i * binFrequency;
            float response = 1.0f / std::sqrt(1.0f + std::pow(freq / filterCutoff, 2.0f * filterResonance));
            magnitudes[i] *= response;
        }
    }

    void applyHarmonicEnhancement() {
        // Detect fundamental frequency (simplified peak detection)
        int fundamentalBin = 0;
        float maxMag = 0.0f;

        for (int i = 1; i < fftSize / 8; ++i) {  // Search in low frequencies
            if (magnitudes[i] > maxMag) {
                maxMag = magnitudes[i];
                fundamentalBin = i;
            }
        }

        if (fundamentalBin > 0) {
            // Boost harmonics
            for (int h = 2; h <= 8; ++h) {
                int harmonicBin = fundamentalBin * h;
                if (harmonicBin <= fftSize / 2) {
                    magnitudes[harmonicBin] *= harmonicBoost;
                }
            }
        }
    }

    void applyRobotize() {
        // Quantize phases to create robotic effect
        int pitchBin = static_cast<int>(robotizePitch / binFrequency);

        for (int i = 0; i <= fftSize / 2; ++i) {
            // Snap to nearest harmonic of robotize pitch
            int nearestHarmonic = std::round(static_cast<float>(i) / pitchBin) * pitchBin;
            if (nearestHarmonic != i && nearestHarmonic > 0 && nearestHarmonic <= fftSize / 2) {
                phases[i] = phases[nearestHarmonic];
            }
        }
    }

    void applyWhisper() {
        // Remove harmonics, keep only noise floor
        std::vector<float> noise(fftSize / 2 + 1);

        // Estimate noise floor (minimum of local region)
        for (int i = 0; i <= fftSize / 2; ++i) {
            float minMag = magnitudes[i];
            for (int j = -5; j <= 5; ++j) {
                int idx = i + j;
                if (idx >= 0 && idx <= fftSize / 2) {
                    minMag = std::min(minMag, magnitudes[idx]);
                }
            }
            noise[i] = minMag;
        }

        // Keep only noise components
        for (int i = 0; i <= fftSize / 2; ++i) {
            magnitudes[i] = std::min(magnitudes[i], noise[i] * 2.0f);
        }
    }

    void applyBioReactiveModulation() {
        // Coherence controls spectral brightness
        float brightnessBoost = 1.0f + bioCoherence * 0.5f;

        // Heart rate creates rhythmic spectral modulation
        float hrPhase = std::fmod(bioHeartRate * 0.1f, TWO_PI);
        float hrMod = 0.5f + 0.5f * std::sin(hrPhase);

        // Breath phase controls spectral width
        float widthMod = 0.8f + 0.2f * std::sin(bioBreathPhase * TWO_PI);

        for (int i = 0; i <= fftSize / 2; ++i) {
            float freq = i * binFrequency;

            // High coherence = boost high frequencies
            if (freq > 2000.0f) {
                magnitudes[i] *= brightnessBoost;
            }

            // Heart rate modulates mid frequencies
            if (freq > 500.0f && freq < 4000.0f) {
                magnitudes[i] *= hrMod;
            }

            // Breath widens/narrows spectrum
            magnitudes[i] *= widthMod;
        }
    }
};

} // namespace DSP
} // namespace Echoelmusic
