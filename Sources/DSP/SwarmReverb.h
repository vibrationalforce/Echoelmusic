#pragma once

#include <JuceHeader.h>
#include <vector>

/**
 * @brief Swarm Reverb - 3D Particle-Based Reverb
 *
 * Algorithmic reverb using particle swarm simulation.
 * Creates organic, evolving reverb tails with spatial movement.
 */
class SwarmReverb
{
public:
    SwarmReverb();
    ~SwarmReverb() = default;

    //==========================================================================
    // Lifecycle

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Swarm Parameters

    void setParticleCount(int count);             // 10 to 500
    void setCohesion(float amount);               // 0.0 to 1.0
    void setSeparation(float amount);             // 0.0 to 1.0
    void setChaos(float amount);                  // 0.0 to 1.0

    //==========================================================================
    // Reverb Parameters

    void setSize(float size);                     // 0.0 to 1.0
    void setDamping(float damping);               // 0.0 to 1.0
    void setMix(float mix);                       // 0.0 to 1.0

    //==========================================================================
    // Bio-Reactive

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float stress);

private:
    struct Particle
    {
        float x, y, z;           // Position
        float vx, vy, vz;        // Velocity
        float delay;             // Delay time
        float gain;              // Amplitude
    };

    double currentSampleRate = 44100.0;
    int currentBlockSize = 512;

    // Swarm parameters
    int particleCount = 100;
    float cohesion = 0.5f;
    float separation = 0.5f;
    float chaos = 0.3f;

    // Reverb parameters
    float size = 0.7f;
    float damping = 0.5f;
    float mix = 0.3f;

    // Bio-reactive
    bool bioReactiveEnabled = false;
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.5f;

    // Particle swarm
    std::vector<Particle> particles;

    // Delay buffers
    juce::AudioBuffer<float> delayBuffer;
    int delayBufferWritePos = 0;

    juce::Random random;

    void updateParticles();
    void initializeParticles();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SwarmReverb)
};
