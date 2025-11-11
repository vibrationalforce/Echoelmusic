#include "SpectrumAnalyzer.h"

//==============================================================================
// Constructor / Destructor
//==============================================================================

SpectrumAnalyzer::SpectrumAnalyzer()
{
    // Initialize arrays
    spectrumBins.fill (0.0f);
    smoothedBins.fill (0.0f);
    peakBins.fill (0.0f);
    peakHoldTimers.fill (0);
    fftData.fill (0.0f);

    startTimer (30); // ~30 FPS for display updates
}

SpectrumAnalyzer::~SpectrumAnalyzer()
{
    stopTimer();
}

//==============================================================================
// Component
//==============================================================================

void SpectrumAnalyzer::paint (juce::Graphics& g)
{
    // Background
    g.fillAll (backgroundColour);

    // Draw grid
    drawGrid (g);

    // Draw spectrum
    drawSpectrum (g);

    // Draw labels
    drawLabels (g);

    // Border
    g.setColour (gridColour);
    g.drawRect (getLocalBounds(), 1);
}

void SpectrumAnalyzer::resized()
{
    // Nothing to resize
}

//==============================================================================
// Audio Data Updates
//==============================================================================

void SpectrumAnalyzer::updateAudioData (const std::vector<float>& spectrumData)
{
    // Update spectrum bins from external data
    const int dataSize = juce::jmin ((int)spectrumData.size(), numBins);

    for (int i = 0; i < dataSize; ++i)
    {
        spectrumBins[i] = juce::jlimit (0.0f, 1.0f, spectrumData[i]);
    }

    updateSpectrum();
}

void SpectrumAnalyzer::processAudioBuffer (const juce::AudioBuffer<float>& buffer)
{
    // Process audio buffer with FFT
    if (buffer.getNumChannels() == 0)
        return;

    const auto* channelData = buffer.getReadPointer (0);
    const int numSamples = buffer.getNumSamples();

    // Fill FFT buffer
    for (int i = 0; i < numSamples; ++i)
    {
        if (fftDataIndex < fftSize)
        {
            fftData[fftDataIndex] = channelData[i];
            fftDataIndex++;
        }

        if (fftDataIndex >= fftSize)
        {
            // Perform FFT
            window.multiplyWithWindowingTable (fftData.data(), fftSize);
            fft.performFrequencyOnlyForwardTransform (fftData.data());

            // Convert FFT data to spectrum bins (logarithmic grouping)
            const float sampleRate = 44100.0f; // Default, should be passed in
            const float binWidth = sampleRate / fftSize;

            for (int bin = 0; bin < numBins; ++bin)
            {
                // Logarithmic frequency mapping (20Hz to 20kHz)
                float minFreq = 20.0f * std::pow (1000.0f, (float)bin / numBins);
                float maxFreq = 20.0f * std::pow (1000.0f, (float)(bin + 1) / numBins);

                int minFFTBin = (int)(minFreq / binWidth);
                int maxFFTBin = (int)(maxFreq / binWidth);

                // Average magnitude in frequency range
                float sum = 0.0f;
                int count = 0;

                for (int fftBin = minFFTBin; fftBin < maxFFTBin && fftBin < fftSize / 2; ++fftBin)
                {
                    sum += fftData[fftBin];
                    count++;
                }

                if (count > 0)
                {
                    float avgMagnitude = sum / count;

                    // Convert to dB scale
                    float db = juce::Decibels::gainToDecibels (avgMagnitude + 0.001f);

                    // Normalize to 0.0 to 1.0 range (-60dB to 0dB)
                    spectrumBins[bin] = juce::jmap (db, -60.0f, 0.0f, 0.0f, 1.0f);
                    spectrumBins[bin] = juce::jlimit (0.0f, 1.0f, spectrumBins[bin]);
                }
            }

            // Reset index
            fftDataIndex = 0;
            fftData.fill (0.0f);

            updateSpectrum();
        }
    }
}

//==============================================================================
// Spectrum Update
//==============================================================================

void SpectrumAnalyzer::updateSpectrum()
{
    const float smoothing = 0.2f; // Smoothing factor
    const int peakHoldTime = 30; // Frames to hold peak

    for (int i = 0; i < numBins; ++i)
    {
        // Smooth current value
        smoothedBins[i] += (spectrumBins[i] - smoothedBins[i]) * smoothing;

        // Update peak hold
        if (smoothedBins[i] > peakBins[i])
        {
            peakBins[i] = smoothedBins[i];
            peakHoldTimers[i] = peakHoldTime;
        }
        else
        {
            // Decay peak hold
            if (peakHoldTimers[i] > 0)
            {
                peakHoldTimers[i]--;
            }
            else
            {
                // Slowly decay peak
                peakBins[i] *= 0.95f;
            }
        }
    }
}

//==============================================================================
// Timer Callback
//==============================================================================

void SpectrumAnalyzer::timerCallback()
{
    // Trigger repaint
    repaint();
}

//==============================================================================
// Rendering
//==============================================================================

void SpectrumAnalyzer::drawSpectrum (juce::Graphics& g)
{
    auto bounds = getLocalBounds().reduced (30, 20).toFloat();
    const float barWidth = bounds.getWidth() / numBins;

    for (int i = 0; i < numBins; ++i)
    {
        float level = smoothedBins[i];
        float peak = peakBins[i];

        // Bar position
        float x = bounds.getX() + i * barWidth;
        float barHeight = level * bounds.getHeight();

        // Draw bar with gradient
        juce::ColourGradient gradient (
            barColour.brighter (0.5f), x, bounds.getBottom() - barHeight,
            barColour.darker (0.3f), x, bounds.getBottom(),
            false
        );

        g.setGradientFill (gradient);
        g.fillRect (x + 1.0f, bounds.getBottom() - barHeight, barWidth - 2.0f, barHeight);

        // Draw peak indicator
        if (peak > 0.05f)
        {
            float peakY = bounds.getBottom() - peak * bounds.getHeight();

            g.setColour (peakColour);
            g.fillRect (x, peakY - 1.0f, barWidth, 2.0f);
        }

        // Highlight effect on top of bar
        if (level > 0.7f)
        {
            g.setColour (juce::Colours::white.withAlpha (0.3f));
            g.fillRect (x + 1.0f, bounds.getBottom() - barHeight, barWidth - 2.0f, 3.0f);
        }
    }
}

void SpectrumAnalyzer::drawGrid (juce::Graphics& g)
{
    auto bounds = getLocalBounds().reduced (30, 20).toFloat();

    g.setColour (gridColour.withAlpha (0.3f));

    // Horizontal grid lines (dB levels)
    const int numHorizontalLines = 5;
    for (int i = 0; i <= numHorizontalLines; ++i)
    {
        float y = bounds.getY() + (float)i / numHorizontalLines * bounds.getHeight();
        g.drawLine (bounds.getX(), y, bounds.getRight(), y, 1.0f);

        // dB labels
        float db = juce::jmap ((float)i / numHorizontalLines, 0.0f, -60.0f);
        g.setColour (textColour.withAlpha (0.5f));
        g.setFont (juce::Font ("Helvetica", 10.0f, juce::Font::plain));
        g.drawText (juce::String ((int)db) + " dB",
                    5, (int)y - 8, 25, 16,
                    juce::Justification::left);
        g.setColour (gridColour.withAlpha (0.3f));
    }

    // Vertical grid lines (frequency markers)
    const std::array<float, 7> freqMarkers = {20.0f, 50.0f, 100.0f, 500.0f, 1000.0f, 5000.0f, 10000.0f};

    for (float freq : freqMarkers)
    {
        // Find bin corresponding to frequency
        float normalizedFreq = std::log (freq / 20.0f) / std::log (1000.0f);
        int bin = (int)(normalizedFreq * numBins);

        if (bin >= 0 && bin < numBins)
        {
            float x = bounds.getX() + bin * (bounds.getWidth() / numBins);
            g.drawLine (x, bounds.getY(), x, bounds.getBottom(), 1.0f);
        }
    }
}

void SpectrumAnalyzer::drawLabels (juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    g.setColour (textColour.withAlpha (0.7f));
    g.setFont (juce::Font ("Helvetica", 11.0f, juce::Font::bold));

    // Title
    g.drawText ("SPECTRUM ANALYZER", bounds.removeFromTop (15).reduced (5, 0),
                juce::Justification::centredLeft);

    // Frequency labels at bottom
    g.setFont (juce::Font ("Helvetica", 9.0f, juce::Font::plain));
    auto bottomArea = bounds.withTop (bounds.getBottom() - 15);

    const std::array<std::pair<float, juce::String>, 5> freqLabels = {
        {{0.0f, "20Hz"}, {0.25f, "100Hz"}, {0.5f, "1kHz"}, {0.75f, "5kHz"}, {1.0f, "20kHz"}}
    };

    for (const auto& [position, label] : freqLabels)
    {
        int x = (int)(30 + position * (bounds.getWidth() - 60));
        g.drawText (label, x - 25, bottomArea.getY(), 50, 15, juce::Justification::centred);
    }
}

float SpectrumAnalyzer::binToFrequency (int bin) const
{
    // Logarithmic frequency mapping (20Hz to 20kHz)
    return 20.0f * std::pow (1000.0f, (float)bin / numBins);
}

juce::String SpectrumAnalyzer::formatFrequency (float freq) const
{
    if (freq < 1000.0f)
        return juce::String ((int)freq) + " Hz";
    else
        return juce::String (freq / 1000.0f, 1) + " kHz";
}
