#pragma once

#include <JuceHeader.h>
#include "FrequencyColorTranslator.h"
#include <cmath>

//==============================================================================
/**
 * @brief Electromagnetic Spectrum Analyzer with Planck Radiation
 *
 * Extends the visible spectrum to include infrared and ultraviolet,
 * with scientifically accurate Planck blackbody radiation calculations.
 *
 * **SCIENTIFIC FOUNDATION** (Advanced Physics):
 *
 * 1. **Planck's Law** (Blackbody Radiation):
 *    B(λ, T) = (2hc²/λ⁵) × 1/(e^(hc/λkT) - 1)
 *
 *    Where:
 *    - h = Planck constant (6.626 × 10^-34 J·s)
 *    - c = Speed of light (2.998 × 10^8 m/s)
 *    - k = Boltzmann constant (1.381 × 10^-23 J/K)
 *    - λ = Wavelength (m)
 *    - T = Temperature (K)
 *
 * 2. **Wien's Displacement Law**:
 *    λ_max = b / T
 *
 *    Where b = 2.898 × 10^-3 m·K (Wien's constant)
 *    - Sun (5778 K) → λ_max ≈ 502 nm (green, peak of solar spectrum)
 *    - Incandescent bulb (2800 K) → λ_max ≈ 1035 nm (infrared)
 *
 * 3. **Stefan-Boltzmann Law** (Total Radiated Power):
 *    P = σ × A × T⁴
 *
 *    Where σ = 5.670 × 10^-8 W/(m²·K⁴)
 *
 * 4. **Color Temperature** (Kelvin Scale):
 *    - 1000 K: Deep red (candle flame)
 *    - 2800 K: Warm white (incandescent bulb)
 *    - 5778 K: Daylight (sun)
 *    - 6500 K: Cool white (overcast sky)
 *    - 10000 K: Blue (arc welding)
 *
 * **Extended EM Spectrum Coverage:**
 * - Infrared: 700 nm - 1 mm (0.3-430 THz)
 * - Visible: 380-750 nm (400-789 THz)
 * - Ultraviolet: 10-380 nm (789-30,000 THz)
 *
 * References:
 * - Planck (1900): "On the Law of Distribution of Energy in the Normal Spectrum"
 * - Wien (1893): "Eine neue Beziehung der Strahlung schwarzer Körper"
 * - Stefan-Boltzmann (1879, 1884): Thermal radiation laws
 * - CIE 1931 color space: International standard for colorimetry
 */

//==============================================================================
/**
 * @brief Planck Radiation Calculator
 *
 * Calculates blackbody spectral radiance using Planck's law.
 */
class PlanckRadiationCalculator
{
public:
    // Physical constants (SI units)
    static constexpr double PLANCK_CONSTANT = 6.62607015e-34;       // J·s
    static constexpr double SPEED_OF_LIGHT = 299792458.0;           // m/s
    static constexpr double BOLTZMANN_CONSTANT = 1.380649e-23;      // J/K
    static constexpr double WIEN_CONSTANT = 2.897771955e-3;         // m·K
    static constexpr double STEFAN_BOLTZMANN = 5.670374419e-8;      // W/(m²·K⁴)

    //==============================================================================
    /**
     * @brief Calculate Planck spectral radiance
     *
     * B(λ, T) = (2hc²/λ⁵) × 1/(e^(hc/λkT) - 1)
     *
     * @param wavelengthNm Wavelength in nanometers
     * @param temperatureK Temperature in Kelvin
     * @return Spectral radiance (W/(m²·sr·m))
     */
    static double calculateSpectralRadiance(double wavelengthNm, double temperatureK)
    {
        // Convert nm to meters
        double wavelengthM = wavelengthNm * 1e-9;

        // Constants
        const double h = PLANCK_CONSTANT;
        const double c = SPEED_OF_LIGHT;
        const double k = BOLTZMANN_CONSTANT;

        // Planck's law: B(λ, T) = (2hc²/λ⁵) × 1/(e^(hc/λkT) - 1)
        double numerator = 2.0 * h * c * c / std::pow(wavelengthM, 5);
        double exponent = (h * c) / (wavelengthM * k * temperatureK);
        double denominator = std::exp(exponent) - 1.0;

        return numerator / denominator;
    }

    //==============================================================================
    /**
     * @brief Calculate Wien's displacement (peak wavelength)
     *
     * λ_max = b / T
     *
     * @param temperatureK Temperature in Kelvin
     * @return Peak wavelength in nanometers
     */
    static double calculatePeakWavelength(double temperatureK)
    {
        // λ_max = Wien's constant / T
        double wavelengthM = WIEN_CONSTANT / temperatureK;
        return wavelengthM * 1e9;  // Convert to nm
    }

    //==============================================================================
    /**
     * @brief Calculate Stefan-Boltzmann total radiated power
     *
     * P = σ × T⁴ (power per unit area)
     *
     * @param temperatureK Temperature in Kelvin
     * @return Power per unit area (W/m²)
     */
    static double calculateTotalPower(double temperatureK)
    {
        return STEFAN_BOLTZMANN * std::pow(temperatureK, 4);
    }

    //==============================================================================
    /**
     * @brief Get normalized Planck distribution (0-1) for visualization
     *
     * @param wavelengthNm Wavelength in nanometers
     * @param temperatureK Temperature in Kelvin
     * @param peakRadiance Peak radiance for normalization
     * @return Normalized intensity (0-1)
     */
    static float getNormalizedIntensity(double wavelengthNm, double temperatureK, double peakRadiance)
    {
        double radiance = calculateSpectralRadiance(wavelengthNm, temperatureK);
        return static_cast<float>(juce::jlimit(0.0, 1.0, radiance / peakRadiance));
    }
};

//==============================================================================
/**
 * @brief Color Temperature to RGB Mapper
 *
 * Converts color temperature (Kelvin) to RGB using Planck's law
 * and CIE XYZ color matching functions (approximation).
 */
class ColorTemperatureMapper
{
public:
    //==============================================================================
    /**
     * @brief Convert color temperature to RGB
     *
     * Uses Tanner Helland's algorithm (approximation of Planck curves)
     *
     * @param temperatureK Temperature in Kelvin (1000-40000 K)
     * @return RGB color
     */
    static juce::Colour temperatureToRGB(double temperatureK)
    {
        // Clamp temperature to valid range
        temperatureK = juce::jlimit(1000.0, 40000.0, temperatureK);

        // Normalize to 100K units
        double temp = temperatureK / 100.0;

        float r, g, b;

        // Red calculation
        if (temp <= 66.0)
        {
            r = 1.0f;
        }
        else
        {
            r = static_cast<float>(329.698727446 * std::pow(temp - 60.0, -0.1332047592));
            r = juce::jlimit(0.0f, 1.0f, r / 255.0f);
        }

        // Green calculation
        if (temp <= 66.0)
        {
            g = static_cast<float>(99.4708025861 * std::log(temp) - 161.1195681661);
            g = juce::jlimit(0.0f, 1.0f, g / 255.0f);
        }
        else
        {
            g = static_cast<float>(288.1221695283 * std::pow(temp - 60.0, -0.0755148492));
            g = juce::jlimit(0.0f, 1.0f, g / 255.0f);
        }

        // Blue calculation
        if (temp >= 66.0)
        {
            b = 1.0f;
        }
        else if (temp <= 19.0)
        {
            b = 0.0f;
        }
        else
        {
            b = static_cast<float>(138.5177312231 * std::log(temp - 10.0) - 305.0447927307);
            b = juce::jlimit(0.0f, 1.0f, b / 255.0f);
        }

        return juce::Colour::fromFloatRGBA(r, g, b, 1.0f);
    }

    //==============================================================================
    /**
     * @brief Get color temperature name/description
     *
     * @param temperatureK Temperature in Kelvin
     * @return Description string
     */
    static juce::String getTemperatureName(double temperatureK)
    {
        if (temperatureK < 2000.0) return "Candle Flame (Warm Red)";
        if (temperatureK < 3000.0) return "Incandescent Bulb (Warm White)";
        if (temperatureK < 4000.0) return "Sunrise/Sunset (Golden)";
        if (temperatureK < 5000.0) return "Fluorescent (Cool White)";
        if (temperatureK < 6000.0) return "Daylight (Neutral White)";
        if (temperatureK < 7000.0) return "Overcast Sky (Cool Blue)";
        if (temperatureK < 10000.0) return "Blue Sky (Deep Blue)";
        return "Arc Welding (Intense Blue)";
    }
};

//==============================================================================
/**
 * @brief Extended EM Spectrum Analyzer
 *
 * Visualizes the full electromagnetic spectrum from audio frequencies
 * through infrared, visible, and ultraviolet regions.
 */
class ExtendedEMSpectrumAnalyzer : public juce::Component,
                                    private juce::Timer
{
public:
    ExtendedEMSpectrumAnalyzer()
        : forwardFFT(fftOrder),
          window(fftSize, juce::dsp::WindowingFunction<float>::hann)
    {
        fftData.resize(fftSize * 2, 0.0f);
        spectrumData.resize(fftSize / 2, 0.0f);

        // Default: Sun's surface temperature
        currentTemperatureK = 5778.0;

        startTimerHz(30);  // 30 FPS
    }

    void setColorTemperature(double temperatureK)
    {
        currentTemperatureK = juce::jlimit(1000.0, 40000.0, temperatureK);
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

        // Apply window & FFT
        window.multiplyWithWindowingTable(fftData.data(), fftSize);
        forwardFFT.performFrequencyOnlyForwardTransform(fftData.data());

        // Smooth spectrum
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
        juce::String title = "EXTENDED EM SPECTRUM + BLACKBODY RADIATION (Planck " +
                            juce::String(static_cast<int>(currentTemperatureK)) + " K)";
        g.drawText(title, bounds.removeFromTop(25), juce::Justification::centredLeft);

        // Split: Top = Blackbody, Bottom = Audio→Light
        auto blackbodyBounds = bounds.removeFromTop(bounds.getHeight() * 0.5f);
        auto audioSpectrumBounds = bounds;

        // ===== Draw Blackbody Radiation Curve =====
        drawBlackbodyRadiation(g, blackbodyBounds.reduced(10));

        // ===== Draw Audio→Light Spectrum =====
        drawAudioSpectrum(g, audioSpectrumBounds.reduced(10));
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    //==============================================================================
    // Blackbody Radiation Visualization

    void drawBlackbodyRadiation(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.3f));
        g.fillRoundedRectangle(bounds, 8.0f);

        // Calculate peak wavelength (Wien's law)
        double peakWavelengthNm = PlanckRadiationCalculator::calculatePeakWavelength(currentTemperatureK);
        double peakRadiance = PlanckRadiationCalculator::calculateSpectralRadiance(peakWavelengthNm, currentTemperatureK);

        // Draw Planck curve (200 nm - 3000 nm)
        juce::Path planckCurve;
        const int numPoints = 200;
        const double minWavelength = 200.0;   // UV
        const double maxWavelength = 3000.0;  // Infrared

        for (int i = 0; i < numPoints; ++i)
        {
            double wavelengthNm = minWavelength + (maxWavelength - minWavelength) * i / numPoints;
            float intensity = PlanckRadiationCalculator::getNormalizedIntensity(wavelengthNm, currentTemperatureK, peakRadiance);

            float x = bounds.getX() + (i / static_cast<float>(numPoints)) * bounds.getWidth();
            float y = bounds.getBottom() - intensity * bounds.getHeight();

            if (i == 0)
                planckCurve.startNewSubPath(x, y);
            else
                planckCurve.lineTo(x, y);
        }

        // Draw curve
        g.setColour(juce::Colours::yellow);
        g.strokePath(planckCurve, juce::PathStrokeType(2.0f));

        // Mark visible spectrum region (380-750 nm)
        float visibleStart = (380.0 - minWavelength) / (maxWavelength - minWavelength);
        float visibleEnd = (750.0 - minWavelength) / (maxWavelength - minWavelength);
        g.setColour(juce::Colours::white.withAlpha(0.1f));
        g.fillRect(bounds.getX() + visibleStart * bounds.getWidth(),
                  bounds.getY(),
                  (visibleEnd - visibleStart) * bounds.getWidth(),
                  bounds.getHeight());

        // Label
        g.setColour(juce::Colours::white.withAlpha(0.7f));
        g.setFont(10.0f);
        g.drawText("UV", bounds.getX() + 5, bounds.getY() + 5, 40, 15, juce::Justification::centredLeft);
        g.drawText("VISIBLE", bounds.getX() + visibleStart * bounds.getWidth() + 5, bounds.getY() + 5, 60, 15, juce::Justification::centredLeft);
        g.drawText("IR", bounds.getRight() - 30, bounds.getY() + 5, 25, 15, juce::Justification::centredRight);

        // Peak marker
        float peakX = bounds.getX() + ((peakWavelengthNm - minWavelength) / (maxWavelength - minWavelength)) * bounds.getWidth();
        g.setColour(juce::Colours::red);
        g.drawLine(peakX, bounds.getY(), peakX, bounds.getBottom(), 1.0f);
        g.drawText("λ_max = " + juce::String(static_cast<int>(peakWavelengthNm)) + " nm",
                  peakX + 5, bounds.getY() + 20, 100, 15, juce::Justification::centredLeft);
    }

    //==============================================================================
    // Audio→Light Spectrum

    void drawAudioSpectrum(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
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
        }
    }

    //==============================================================================
    static constexpr int fftOrder = 11;
    static constexpr int fftSize = 1 << fftOrder;  // 2048

    juce::dsp::FFT forwardFFT;
    juce::dsp::WindowingFunction<float> window;
    std::vector<float> fftData;
    std::vector<float> spectrumData;

    double currentTemperatureK;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ExtendedEMSpectrumAnalyzer)
};
