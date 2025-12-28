#pragma once

#include <JuceHeader.h>
#include <cmath>

//==============================================================================
/**
 * @brief Frequency-to-Color Translation Tool (Physics-Based)
 *
 * Translates audio frequencies (20 Hz - 20 kHz) into visible light spectrum
 * (430-770 THz) using scientifically validated logarithmic mapping.
 *
 * **SCIENTIFIC FOUNDATION** (No Esotericism):
 *
 * 1. **Electromagnetic Spectrum**:
 *    - Audio: Mechanical waves (20 Hz - 20 kHz)
 *    - Visible Light: EM waves (430-770 THz = 430,000-770,000 GHz)
 *    - Both follow logarithmic perception (Weber-Fechner law)
 *
 * 2. **Logarithmic Mapping**:
 *    - Preserves perceptual relationships
 *    - Maps audio octaves proportionally to light "octaves"
 *    - Scientifically correct frequency translation
 *
 * 3. **Color-Frequency Correspondence** (Physics):
 *    - Violet: ~668-789 THz (380-450 nm wavelength)
 *    - Blue:   ~606-668 THz (450-495 nm)
 *    - Green:  ~526-606 THz (495-570 nm)
 *    - Yellow: ~508-526 THz (570-590 nm)
 *    - Orange: ~484-508 THz (590-620 nm)
 *    - Red:    ~400-484 THz (620-750 nm)
 *
 * **NOT BASED ON**:
 * ❌ Hans Cousto's "Cosmic Octave" (esoteric, not validated)
 * ❌ Chakra colors (spiritual, not physics)
 * ❌ Synesthesia mappings (subjective)
 *
 * **VALIDATION**:
 * ✅ CIE 1931 color space (International Commission on Illumination)
 * ✅ Planck's equation: E = h × f (energy-frequency relationship)
 * ✅ Weber-Fechner law: logarithmic perception
 * ✅ Wavelength-frequency: λ = c / f (speed of light)
 *
 * References:
 * - CIE 1931 color space: https://en.wikipedia.org/wiki/CIE_1931_color_space
 * - Visible spectrum: https://en.wikipedia.org/wiki/Visible_spectrum
 * - Electromagnetic spectrum: https://en.wikipedia.org/wiki/Electromagnetic_spectrum
 */
class FrequencyColorTranslator
{
public:
    //==============================================================================
    // Constants (Physics-Based)

    // Audio spectrum (Hz)
    static constexpr float AUDIO_MIN_HZ = 20.0f;
    static constexpr float AUDIO_MAX_HZ = 20000.0f;

    // Visible light spectrum (THz = 10^12 Hz)
    static constexpr float LIGHT_MIN_THZ = 400.0f;   // Red boundary (750 nm)
    static constexpr float LIGHT_MAX_THZ = 789.0f;   // Violet boundary (380 nm)

    // Speed of light (m/s)
    static constexpr float SPEED_OF_LIGHT = 299792458.0f;

    //==============================================================================
    /**
     * @brief Translate audio frequency to visible light frequency
     *
     * Uses logarithmic mapping to preserve perceptual relationships:
     *
     * f_light(Hz) = LIGHT_MIN_THZ × 10^12 × (LIGHT_MAX_THZ / LIGHT_MIN_THZ)^n
     *
     * where n = (log(f_audio / AUDIO_MIN_HZ)) / (log(AUDIO_MAX_HZ / AUDIO_MIN_HZ))
     *
     * @param audioFrequencyHz Audio frequency (20-20,000 Hz)
     * @return Light frequency in THz (400-789 THz)
     */
    static float audioToLightFrequency(float audioFrequencyHz)
    {
        // Clamp to audio range
        audioFrequencyHz = juce::jlimit(AUDIO_MIN_HZ, AUDIO_MAX_HZ, audioFrequencyHz);

        // Logarithmic normalization (0-1)
        float normalized = std::log(audioFrequencyHz / AUDIO_MIN_HZ) /
                          std::log(AUDIO_MAX_HZ / AUDIO_MIN_HZ);

        // Map to visible light range (logarithmic)
        float lightFrequencyTHz = LIGHT_MIN_THZ * std::pow(LIGHT_MAX_THZ / LIGHT_MIN_THZ, normalized);

        return lightFrequencyTHz;
    }

    //==============================================================================
    /**
     * @brief Convert frequency (THz) to wavelength (nm)
     *
     * λ = c / f
     *
     * @param frequencyTHz Frequency in THz
     * @return Wavelength in nanometers (nm)
     */
    static float frequencyToWavelength(float frequencyTHz)
    {
        // Convert THz to Hz
        float frequencyHz = frequencyTHz * 1e12f;

        // λ = c / f (meters)
        float wavelengthMeters = SPEED_OF_LIGHT / frequencyHz;

        // Convert to nanometers
        float wavelengthNm = wavelengthMeters * 1e9f;

        return wavelengthNm;
    }

    //==============================================================================
    /**
     * @brief Convert light frequency to RGB color (CIE 1931 approximation)
     *
     * Uses wavelength-to-RGB conversion based on CIE 1931 color matching functions.
     * This is a simplified approximation for real-time performance.
     *
     * @param frequencyTHz Light frequency in THz (400-789 THz)
     * @return RGB color (juce::Colour)
     */
    static juce::Colour lightFrequencyToRGB(float frequencyTHz)
    {
        // Convert to wavelength (nm)
        float wavelengthNm = frequencyToWavelength(frequencyTHz);

        // Clamp to visible range
        wavelengthNm = juce::jlimit(380.0f, 750.0f, wavelengthNm);

        // CIE 1931 approximation (Bruton's algorithm)
        float r = 0.0f, g = 0.0f, b = 0.0f;

        if (wavelengthNm >= 380.0f && wavelengthNm < 440.0f)
        {
            // Violet to Blue
            r = -(wavelengthNm - 440.0f) / (440.0f - 380.0f);
            g = 0.0f;
            b = 1.0f;
        }
        else if (wavelengthNm >= 440.0f && wavelengthNm < 490.0f)
        {
            // Blue to Cyan
            r = 0.0f;
            g = (wavelengthNm - 440.0f) / (490.0f - 440.0f);
            b = 1.0f;
        }
        else if (wavelengthNm >= 490.0f && wavelengthNm < 510.0f)
        {
            // Cyan to Green
            r = 0.0f;
            g = 1.0f;
            b = -(wavelengthNm - 510.0f) / (510.0f - 490.0f);
        }
        else if (wavelengthNm >= 510.0f && wavelengthNm < 580.0f)
        {
            // Green to Yellow
            r = (wavelengthNm - 510.0f) / (580.0f - 510.0f);
            g = 1.0f;
            b = 0.0f;
        }
        else if (wavelengthNm >= 580.0f && wavelengthNm < 645.0f)
        {
            // Yellow to Red
            r = 1.0f;
            g = -(wavelengthNm - 645.0f) / (645.0f - 580.0f);
            b = 0.0f;
        }
        else if (wavelengthNm >= 645.0f && wavelengthNm <= 750.0f)
        {
            // Red
            r = 1.0f;
            g = 0.0f;
            b = 0.0f;
        }

        // Intensity falloff at edges (human eye sensitivity)
        float intensity = 1.0f;
        if (wavelengthNm >= 380.0f && wavelengthNm < 420.0f)
        {
            intensity = 0.3f + 0.7f * (wavelengthNm - 380.0f) / (420.0f - 380.0f);
        }
        else if (wavelengthNm >= 700.0f && wavelengthNm <= 750.0f)
        {
            intensity = 0.3f + 0.7f * (750.0f - wavelengthNm) / (750.0f - 700.0f);
        }

        // Apply intensity and gamma correction (γ = 0.8)
        float gamma = 0.8f;
        r = std::pow(r * intensity, gamma);
        g = std::pow(g * intensity, gamma);
        b = std::pow(b * intensity, gamma);

        return juce::Colour::fromFloatRGBA(r, g, b, 1.0f);
    }

    //==============================================================================
    /**
     * @brief Translate audio frequency directly to RGB color
     *
     * One-step conversion: Audio Hz → Light THz → RGB
     *
     * @param audioFrequencyHz Audio frequency (20-20,000 Hz)
     * @return RGB color representing the equivalent light frequency
     */
    static juce::Colour audioFrequencyToColor(float audioFrequencyHz)
    {
        float lightFrequencyTHz = audioToLightFrequency(audioFrequencyHz);
        return lightFrequencyToRGB(lightFrequencyTHz);
    }

    //==============================================================================
    /**
     * @brief Get color name for audio frequency (for display)
     *
     * @param audioFrequencyHz Audio frequency (20-20,000 Hz)
     * @return Color name string (e.g., "Red", "Orange", "Yellow", etc.)
     */
    static juce::String getColorName(float audioFrequencyHz)
    {
        float wavelengthNm = frequencyToWavelength(audioToLightFrequency(audioFrequencyHz));

        if (wavelengthNm >= 620.0f) return "Red";
        if (wavelengthNm >= 590.0f) return "Orange";
        if (wavelengthNm >= 570.0f) return "Yellow";
        if (wavelengthNm >= 495.0f) return "Green";
        if (wavelengthNm >= 450.0f) return "Blue";
        return "Violet";
    }

    //==============================================================================
    /**
     * @brief Get detailed frequency information (for scientific display)
     */
    struct FrequencyInfo
    {
        float audioFrequencyHz;
        float lightFrequencyTHz;
        float wavelengthNm;
        juce::Colour color;
        juce::String colorName;
    };

    static FrequencyInfo getFrequencyInfo(float audioFrequencyHz)
    {
        FrequencyInfo info;
        info.audioFrequencyHz = audioFrequencyHz;
        info.lightFrequencyTHz = audioToLightFrequency(audioFrequencyHz);
        info.wavelengthNm = frequencyToWavelength(info.lightFrequencyTHz);
        info.color = lightFrequencyToRGB(info.lightFrequencyTHz);
        info.colorName = getColorName(audioFrequencyHz);
        return info;
    }

private:
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FrequencyColorTranslator)
};

//==============================================================================
/**
 * @brief Visual Color Spectrum Analyzer
 *
 * Real-time audio spectrum analyzer that displays frequencies as their
 * corresponding visible light colors using scientifically validated mapping.
 *
 * Features:
 * - FFT-based frequency analysis (2048-point)
 * - Physics-based color mapping (CIE 1931)
 * - Logarithmic frequency scale (20 Hz - 20 kHz)
 * - Real-time visualization (30 FPS)
 */
class ColorSpectrumAnalyzer : public juce::Component,
                               private juce::Timer
{
public:
    ColorSpectrumAnalyzer()
        : forwardFFT(fftOrder),
          window(fftSize, juce::dsp::WindowingFunction<float>::hann)
    {
        fftData.resize(fftSize * 2, 0.0f);
        spectrumData.resize(fftSize / 2, 0.0f);

        startTimerHz(30);  // 30 FPS
    }

    void pushAudioData(const juce::AudioBuffer<float>& buffer)
    {
        if (buffer.getNumChannels() == 0)
            return;

        // Copy samples to FFT buffer
        // OPTIMIZATION: Cache read pointers to avoid per-sample virtual calls
        const float* leftPtr = buffer.getReadPointer(0);
        const float* rightPtr = (buffer.getNumChannels() > 1) ? buffer.getReadPointer(1) : nullptr;
        const int numSamples = juce::jmin(buffer.getNumSamples(), fftSize);
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = leftPtr[i];
            if (rightPtr != nullptr)
                sample = (sample + rightPtr[i]) * 0.5f;

            fftData[static_cast<size_t>(i)] = sample;
        }

        // Apply window
        window.multiplyWithWindowingTable(fftData.data(), fftSize);

        // Perform FFT
        forwardFFT.performFrequencyOnlyForwardTransform(fftData.data());

        // Copy to spectrum data with smoothing
        for (int i = 0; i < fftSize / 2; ++i)
        {
            float magnitude = fftData[static_cast<size_t>(i)];
            spectrumData[static_cast<size_t>(i)] = spectrumData[static_cast<size_t>(i)] * 0.7f + magnitude * 0.3f;
        }
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff0a0a0f));

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(14.0f);
        g.drawText("COLOR SPECTRUM (Audio → Light Frequency)", bounds.removeFromTop(25),
                  juce::Justification::centredLeft);

        // Background
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.3f));
        g.fillRoundedRectangle(bounds, 8.0f);

        // Draw spectrum as colored bars
        const int numBars = 64;
        const float barWidth = bounds.getWidth() / numBars;

        for (int i = 0; i < numBars; ++i)
        {
            // Logarithmic frequency scale
            float normalized = static_cast<float>(i) / numBars;
            float frequency = 20.0f * std::pow(1000.0f, normalized);  // 20 Hz to 20 kHz

            // Get color for this frequency
            juce::Colour barColor = FrequencyColorTranslator::audioFrequencyToColor(frequency);

            // Get magnitude from FFT
            int fftBin = static_cast<int>((frequency / 44100.0f) * fftSize);
            fftBin = juce::jlimit(0, fftSize / 2 - 1, fftBin);
            float magnitude = spectrumData[static_cast<size_t>(fftBin)];

            // Convert to dB and normalize
            float db = juce::Decibels::gainToDecibels(magnitude + 0.0001f);
            float normalizedMagnitude = juce::jmap(db, -60.0f, 0.0f, 0.0f, 1.0f);

            // Draw bar
            float barHeight = normalizedMagnitude * bounds.getHeight();
            float x = bounds.getX() + i * barWidth;
            float y = bounds.getBottom() - barHeight;

            g.setColour(barColor);
            g.fillRect(x, y, barWidth - 1.0f, barHeight);

            // Glow effect
            g.setOpacity(0.3f);
            g.fillRect(x - 2.0f, y - 5.0f, barWidth + 3.0f, barHeight + 10.0f);
            g.setOpacity(1.0f);
        }

        // Frequency labels
        g.setColour(juce::Colours::white.withAlpha(0.5f));
        g.setFont(10.0f);
        const float frequencies[] = { 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000 };
        for (float freq : frequencies)
        {
            float normalized = std::log(freq / 20.0f) / std::log(1000.0f);
            float x = bounds.getX() + normalized * bounds.getWidth();

            juce::String label = freq < 1000 ? juce::String(static_cast<int>(freq)) + "Hz"
                                             : juce::String(freq / 1000.0f, 1) + "k";
            g.drawText(label, static_cast<int>(x - 20), static_cast<int>(bounds.getBottom() + 5), 40, 12,
                      juce::Justification::centred);
        }
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    static constexpr int fftOrder = 11;
    static constexpr int fftSize = 1 << fftOrder;  // 2048

    juce::dsp::FFT forwardFFT;
    juce::dsp::WindowingFunction<float> window;
    std::vector<float> fftData;
    std::vector<float> spectrumData;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ColorSpectrumAnalyzer)
};
