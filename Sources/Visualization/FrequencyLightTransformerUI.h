#pragma once

#include <JuceHeader.h>
#include "ScientificFrequencyLightTransformer.h"

//==============================================================================
/**
 * @brief FREQUENCY-TO-LIGHT TRANSFORMER UI
 *
 * Real-time visualization of frequency-to-light octave transformation
 * with scientific data display and export capabilities.
 *
 * Features:
 * - Live FFT analysis with dominant frequency detection
 * - Octave transformation visualization
 * - Spectrum display with color mapping
 * - Scientific data readout (wavelength, color, cone response)
 * - Export to OSC/DMX/JSON
 */
class FrequencyLightTransformerUI : public juce::Component,
                                     private juce::Timer
{
public:
    //==============================================================================
    FrequencyLightTransformerUI()
        : forwardFFT(fftOrder),
          window(fftSize, juce::dsp::WindowingFunction<float>::hann)
    {
        fftData.resize(fftSize * 2, 0.0f);
        startTimerHz(30);  // 30 FPS

        // Initialize with A4 = 440 Hz
        updateTransformation(440.0);
    }

    ~FrequencyLightTransformerUI() override
    {
        stopTimer();
    }

    //==============================================================================
    // AUDIO INPUT
    //==============================================================================

    /**
     * @brief Process incoming audio buffer (performs FFT analysis)
     */
    void processAudioBuffer(const juce::AudioBuffer<float>& buffer)
    {
        if (buffer.getNumChannels() == 0 || buffer.getNumSamples() == 0)
            return;

        // Copy audio to FFT buffer (mono sum)
        for (int i = 0; i < juce::jmin(buffer.getNumSamples(), fftSize); ++i)
        {
            float sample = buffer.getSample(0, i);
            if (buffer.getNumChannels() > 1)
                sample = (sample + buffer.getSample(1, i)) * 0.5f;

            fftData[static_cast<size_t>(i)] = sample;
        }

        // Apply windowing
        window.multiplyWithWindowingTable(fftData.data(), fftSize);

        // Perform FFT
        forwardFFT.performFrequencyOnlyForwardTransform(fftData.data());

        // Find dominant frequency
        int maxBin = 1;
        float maxMagnitude = 0.0f;

        for (int i = 1; i < fftSize / 2; ++i)
        {
            float magnitude = fftData[static_cast<size_t>(i)];
            if (magnitude > maxMagnitude)
            {
                maxMagnitude = magnitude;
                maxBin = i;
            }
        }

        // Convert bin to frequency (assuming 44.1 kHz sample rate)
        double dominantFreq = static_cast<double>(maxBin) * 44100.0 / static_cast<double>(fftSize);

        // Only update if significant magnitude
        if (maxMagnitude > 0.01f && dominantFreq >= 20.0 && dominantFreq <= 20000.0)
        {
            updateTransformation(dominantFreq);
        }
    }

    /**
     * @brief Manually set frequency for transformation
     */
    void setFrequency(double frequency_Hz)
    {
        updateTransformation(frequency_Hz);
    }

    /**
     * @brief Get current transformation result
     */
    const ScientificFrequencyLightTransformer::TransformationResult& getCurrentTransform() const
    {
        return currentTransform;
    }

    //==============================================================================
    // COMPONENT OVERRIDES
    //==============================================================================

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff0a0a0f));

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(18.0f, juce::Font::bold));
        g.drawText("🌈 FREQUENCY → LIGHT TRANSFORMER (OCTAVE METHOD) 🔬",
                   bounds.removeFromTop(30).reduced(10, 5),
                   juce::Justification::centred);

        // Divider
        g.setColour(juce::Colour(0xff2a2a4f));
        g.fillRect(bounds.removeFromTop(2));

        bounds.reduce(15, 10);

        // Layout areas
        auto inputArea = bounds.removeFromTop(120);
        auto colorDisplayArea = bounds.removeFromTop(150);
        auto spectrumArea = bounds.removeFromTop(100);
        auto scientificDataArea = bounds.removeFromTop(180);

        // Draw sections
        drawInputSection(g, inputArea);
        drawColorDisplay(g, colorDisplayArea);
        drawSpectrum(g, spectrumArea);
        drawScientificData(g, scientificDataArea);

        // Draw references at bottom
        drawReferences(g, bounds);
    }

    void resized() override
    {
        // Component is self-contained, no child components to layout
    }

private:
    //==============================================================================
    // DRAWING METHODS
    //==============================================================================

    void drawInputSection(juce::Graphics& g, juce::Rectangle<float> area)
    {
        // Background
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.5f));
        g.fillRoundedRectangle(area, 8.0f);

        area.reduce(10, 10);

        // Audio Frequency
        g.setColour(juce::Colours::cyan);
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.drawText("AUDIO INPUT:", area.removeFromTop(25), juce::Justification::left);

        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(28.0f, juce::Font::bold));
        g.drawText(juce::String(currentTransform.audioFrequency_Hz, 2) + " Hz",
                   area.removeFromTop(35), juce::Justification::left);

        g.setFont(juce::Font(20.0f));
        g.setColour(juce::Colours::lightblue);
        g.drawText("Note: " + currentTransform.musicalNote,
                   area.removeFromTop(30), juce::Justification::left);

        // Octaves shifted
        g.setColour(juce::Colours::yellow);
        g.setFont(juce::Font(14.0f, juce::Font::bold));
        g.drawText("Octaves Shifted: +" + juce::String(currentTransform.octavesShifted),
                   area, juce::Justification::left);
    }

    void drawColorDisplay(juce::Graphics& g, juce::Rectangle<float> area)
    {
        // Background
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.5f));
        g.fillRoundedRectangle(area, 8.0f);

        area.reduce(10, 10);

        // Split: Color box on left, data on right
        auto colorBox = area.removeFromLeft(200);
        area.removeFromLeft(10);  // Spacing

        // Draw color box
        g.setColour(currentTransform.juceColor);
        g.fillRoundedRectangle(colorBox, 10.0f);

        // Glow effect
        g.setColour(currentTransform.juceColor.withAlpha(0.3f));
        g.drawRoundedRectangle(colorBox.expanded(5), 10.0f, 3.0f);

        // Light frequency info
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.drawText("LIGHT OUTPUT:", area.removeFromTop(25), juce::Justification::left);

        g.setFont(juce::Font(24.0f, juce::Font::bold));
        g.drawText(juce::String(currentTransform.lightFrequency_THz, 1) + " THz",
                   area.removeFromTop(32), juce::Justification::left);

        g.setFont(juce::Font(20.0f));
        g.setColour(juce::Colours::lightgreen);
        g.drawText("λ = " + juce::String(currentTransform.wavelength_nm, 1) + " nm",
                   area.removeFromTop(28), juce::Justification::left);

        g.setFont(juce::Font(18.0f, juce::Font::bold));
        g.setColour(currentTransform.juceColor);
        g.drawText(currentTransform.color.perceptualName,
                   area.removeFromTop(28), juce::Justification::left);

        // RGB values
        g.setFont(juce::Font(14.0f));
        g.setColour(juce::Colours::grey);
        g.drawText(juce::String::formatted("RGB: (%.2f, %.2f, %.2f)",
                                          currentTransform.color.r,
                                          currentTransform.color.g,
                                          currentTransform.color.b),
                   area, juce::Justification::left);
    }

    void drawSpectrum(juce::Graphics& g, juce::Rectangle<float> area)
    {
        // Background
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.5f));
        g.fillRoundedRectangle(area, 8.0f);

        area.reduce(10, 10);

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(14.0f, juce::Font::bold));
        g.drawText("VISIBLE SPECTRUM (380-780 nm)", area.removeFromTop(20), juce::Justification::centred);

        // Draw continuous spectrum
        for (float x = 0; x < area.getWidth(); ++x)
        {
            double wavelength = 380.0 + (400.0 * x / area.getWidth());
            auto transform = ScientificFrequencyLightTransformer::transformToLight(
                440.0 * std::pow(2.0, (wavelength - 620.0) / 50.0)  // Approximate inverse mapping
            );

            g.setColour(transform.juceColor);
            g.drawLine(area.getX() + x, area.getY(), area.getX() + x, area.getBottom(), 1.0f);
        }

        // Mark current wavelength
        float markerPos = area.getX() + area.getWidth() * (currentTransform.wavelength_nm - 380.0) / 400.0;
        g.setColour(juce::Colours::white);
        g.drawLine(markerPos, area.getY() - 5, markerPos, area.getBottom() + 5, 2.0f);

        // Draw triangle marker
        juce::Path triangle;
        triangle.addTriangle(markerPos - 5, area.getY() - 10,
                            markerPos + 5, area.getY() - 10,
                            markerPos, area.getY() - 5);
        g.fillPath(triangle);
    }

    void drawScientificData(juce::Graphics& g, juce::Rectangle<float> area)
    {
        // Background
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.5f));
        g.fillRoundedRectangle(area, 8.0f);

        area.reduce(10, 10);

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(14.0f, juce::Font::bold));
        g.drawText("SCIENTIFIC DATA:", area.removeFromTop(22), juce::Justification::left);

        g.setFont(juce::Font(13.0f));
        g.setColour(juce::Colours::lightgrey);

        // Photopic luminosity
        g.drawText("Photopic Luminosity V(λ): " +
                   juce::String(currentTransform.perceptualBrightness, 3),
                   area.removeFromTop(20), juce::Justification::left);

        // Cone responses
        g.drawText(juce::String::formatted("Cone Response → S: %.2f | M: %.2f | L: %.2f",
                                          currentTransform.sConeActivation,
                                          currentTransform.mConeActivation,
                                          currentTransform.lConeActivation),
                   area.removeFromTop(20), juce::Justification::left);

        // Visual cortex
        g.setFont(juce::Font(12.0f));
        g.drawText("Cortex: " + currentTransform.visualCortexResponse,
                   area.removeFromTop(35), juce::Justification::left);

        // Flicker fusion
        g.drawText("Flicker Fusion Relation: " +
                   juce::String(currentTransform.flickerFusionRelation, 1) + " Hz",
                   area.removeFromTop(20), juce::Justification::left);

        // Color temperature
        g.drawText("Color Temperature: ~" +
                   juce::String(static_cast<int>(currentTransform.color.colorTemperatureK)) + " K",
                   area.removeFromTop(20), juce::Justification::left);

        // Validation
        if (currentTransform.isPhysicallyValid)
        {
            g.setColour(juce::Colours::green);
            g.drawText("✓ Physically Valid (380-780 nm)", area, juce::Justification::left);
        }
        else
        {
            g.setColour(juce::Colours::red);
            g.drawText("⚠ Outside Visible Spectrum", area, juce::Justification::left);
        }
    }

    void drawReferences(juce::Graphics& g, juce::Rectangle<float> area)
    {
        g.setFont(juce::Font(10.0f));
        g.setColour(juce::Colours::grey.withAlpha(0.7f));

        float y = area.getY();
        for (const auto& ref : currentTransform.references)
        {
            g.drawText(ref, area.getX(), y, area.getWidth(), 12, juce::Justification::left);
            y += 12;
        }
    }

    //==============================================================================
    // PRIVATE METHODS
    //==============================================================================

    void timerCallback() override
    {
        repaint();
    }

    void updateTransformation(double frequency_Hz)
    {
        currentTransform = ScientificFrequencyLightTransformer::transformToLight(frequency_Hz);
    }

    //==============================================================================
    // FFT PARAMETERS
    //==============================================================================

    static constexpr int fftOrder = 11;        // 2048 samples
    static constexpr int fftSize = 1 << fftOrder;

    juce::dsp::FFT forwardFFT;
    juce::dsp::WindowingFunction<float> window;
    std::vector<float> fftData;

    //==============================================================================
    // TRANSFORMATION DATA
    //==============================================================================

    ScientificFrequencyLightTransformer::TransformationResult currentTransform;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FrequencyLightTransformerUI)
};
