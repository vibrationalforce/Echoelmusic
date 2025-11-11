#pragma once

#include <JuceHeader.h>
#include <vector>

/**
 * Bio-Reactive Visualizer
 *
 * Real-time particle-based visualization that reacts to bio-data.
 * - HRV controls particle count and movement speed
 * - Coherence controls color and pattern formation
 * - Renders smooth, GPU-accelerated animations
 */
class BioReactiveVisualizer : public juce::Component,
                               private juce::Timer
{
public:
    BioReactiveVisualizer();
    ~BioReactiveVisualizer() override;

    //==========================================================================
    // Component
    //==========================================================================

    void paint (juce::Graphics&) override;
    void resized() override;

    //==========================================================================
    // Bio-Data Updates
    //==========================================================================

    /** Update bio-data values for visualization */
    void updateBioData (float hrv, float coherence);

    /** Get current bio-data */
    float getHRV() const { return currentHRV; }
    float getCoherence() const { return currentCoherence; }

private:
    //==========================================================================
    // Timer
    //==========================================================================

    void timerCallback() override;

    //==========================================================================
    // Particle System
    //==========================================================================

    struct Particle
    {
        juce::Point<float> position;
        juce::Point<float> velocity;
        float size;
        float alpha;
        juce::Colour color;
        float phase; // For sine wave motion
    };

    std::vector<Particle> particles;
    const int maxParticles = 200;

    void initializeParticles();
    void updateParticles();

    //==========================================================================
    // Visualization State
    //==========================================================================

    float currentHRV {0.5f};
    float currentCoherence {0.5f};

    // Smoothed values for animation
    float smoothedHRV {0.5f};
    float smoothedCoherence {0.5f};

    float animationTime {0.0f};

    //==========================================================================
    // Rendering
    //==========================================================================

    void drawParticles (juce::Graphics& g);
    void drawWaveform (juce::Graphics& g);
    void drawCoherenceIndicator (juce::Graphics& g);

    juce::Colour getColorForCoherence (float coherence) const;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BioReactiveVisualizer)
};
