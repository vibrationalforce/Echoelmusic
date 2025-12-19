#include "SwarmReverb.h"

SwarmReverb::SwarmReverb()
{
    initializeParticles();
}

void SwarmReverb::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;
    currentBlockSize = maxBlockSize;

    // Allocate delay buffer (4 seconds max)
    int maxDelaySamples = static_cast<int>(sampleRate * 4.0);
    delayBuffer.setSize(2, maxDelaySamples);
    delayBuffer.clear();
    delayBufferWritePos = 0;

    initializeParticles();
}

void SwarmReverb::reset()
{
    delayBuffer.clear();
    delayBufferWritePos = 0;
    initializeParticles();
}

void SwarmReverb::process(juce::AudioBuffer<float>& buffer)
{
    if (mix < 0.01f)
        return;  // Bypass if mix is too low

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();
    const int delayBufferSize = delayBuffer.getNumSamples();

    // Apply bio-reactive modulation
    float effectiveMix = mix;
    if (bioReactiveEnabled)
    {
        effectiveMix *= (0.5f + currentCoherence * 0.5f);
    }

    // Update particle positions
    updateParticles();

    // Process reverb
    juce::AudioBuffer<float> reverbBuffer(numChannels, numSamples);
    reverbBuffer.clear();

    // Accumulate particle contributions
    for (const auto& particle : particles)
    {
        int delaySamples = static_cast<int>(particle.delay * currentSampleRate * size);
        delaySamples = juce::jlimit(0, delayBufferSize - 1, delaySamples);

        for (int ch = 0; ch < numChannels; ++ch)
        {
            auto* wetData = reverbBuffer.getWritePointer(ch);

            for (int i = 0; i < numSamples; ++i)
            {
                int readPos = (delayBufferWritePos - delaySamples + delayBufferSize) % delayBufferSize;
                float delayedSample = delayBuffer.getSample(ch, readPos);
                wetData[i] += delayedSample * particle.gain * (1.0f - damping);
            }
        }
    }

    // Write input to delay buffer
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* channelData = buffer.getReadPointer(ch);
        auto* delayData = delayBuffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
        {
            delayData[delayBufferWritePos] = channelData[i];
            delayBufferWritePos = (delayBufferWritePos + 1) % delayBufferSize;
        }
    }

    // Mix wet and dry
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* channelData = buffer.getWritePointer(ch);
        auto* wetData = reverbBuffer.getReadPointer(ch);

        for (int i = 0; i < numSamples; ++i)
        {
            channelData[i] = channelData[i] * (1.0f - effectiveMix) + wetData[i] * effectiveMix;
        }
    }
}

void SwarmReverb::initializeParticles()
{
    particles.clear();
    particles.reserve(particleCount);

    for (int i = 0; i < particleCount; ++i)
    {
        Particle p;
        p.x = random.nextFloat() * 2.0f - 1.0f;
        p.y = random.nextFloat() * 2.0f - 1.0f;
        p.z = random.nextFloat() * 2.0f - 1.0f;
        p.vx = (random.nextFloat() * 2.0f - 1.0f) * 0.01f;
        p.vy = (random.nextFloat() * 2.0f - 1.0f) * 0.01f;
        p.vz = (random.nextFloat() * 2.0f - 1.0f) * 0.01f;
        p.delay = random.nextFloat() * 0.5f;
        p.gain = 1.0f / std::sqrt(static_cast<float>(particleCount));

        particles.push_back(p);
    }
}

void SwarmReverb::updateParticles()
{
    for (auto& p : particles)
    {
        // Update position
        p.x += p.vx;
        p.y += p.vy;
        p.z += p.vz;

        // Apply swarm forces
        float fx = 0.0f, fy = 0.0f, fz = 0.0f;

        for (const auto& other : particles)
        {
            if (&p == &other) continue;

            float dx = other.x - p.x;
            float dy = other.y - p.y;
            float dz = other.z - p.z;
            float distSq = dx*dx + dy*dy + dz*dz;

            if (distSq < 0.01f) distSq = 0.01f;

            // Cohesion (attraction)
            fx += dx * cohesion * 0.001f;
            fy += dy * cohesion * 0.001f;
            fz += dz * cohesion * 0.001f;

            // Separation (repulsion)
            float repel = separation / distSq;
            fx -= dx * repel * 0.01f;
            fy -= dy * repel * 0.01f;
            fz -= dz * repel * 0.01f;
        }

        // Add chaos (random)
        fx += (random.nextFloat() * 2.0f - 1.0f) * chaos * 0.001f;
        fy += (random.nextFloat() * 2.0f - 1.0f) * chaos * 0.001f;
        fz += (random.nextFloat() * 2.0f - 1.0f) * chaos * 0.001f;

        // Update velocity
        p.vx += fx;
        p.vy += fy;
        p.vz += fz;

        // Damping
        p.vx *= 0.99f;
        p.vy *= 0.99f;
        p.vz *= 0.99f;

        // Boundary wrap
        if (std::abs(p.x) > 1.0f) p.x = -p.x * 0.9f;
        if (std::abs(p.y) > 1.0f) p.y = -p.y * 0.9f;
        if (std::abs(p.z) > 1.0f) p.z = -p.z * 0.9f;

        // Update delay based on distance from center
        float dist = std::sqrt(p.x*p.x + p.y*p.y + p.z*p.z);
        p.delay = dist * 0.5f;
    }
}

void SwarmReverb::setParticleCount(int count)
{
    particleCount = juce::jlimit(10, 500, count);
    initializeParticles();
}

void SwarmReverb::setCohesion(float amount)
{
    cohesion = juce::jlimit(0.0f, 1.0f, amount);
}

void SwarmReverb::setSeparation(float amount)
{
    separation = juce::jlimit(0.0f, 1.0f, amount);
}

void SwarmReverb::setChaos(float amount)
{
    chaos = juce::jlimit(0.0f, 1.0f, amount);
}

void SwarmReverb::setSize(float newSize)
{
    size = juce::jlimit(0.0f, 1.0f, newSize);
}

void SwarmReverb::setDamping(float newDamping)
{
    damping = juce::jlimit(0.0f, 1.0f, newDamping);
}

void SwarmReverb::setMix(float newMix)
{
    mix = juce::jlimit(0.0f, 1.0f, newMix);
}

void SwarmReverb::setBioReactiveEnabled(bool enabled)
{
    bioReactiveEnabled = enabled;
}

void SwarmReverb::setBioData(float hrv, float coherence, float stress)
{
    currentHRV = hrv;
    currentCoherence = coherence;
    currentStress = stress;
}
