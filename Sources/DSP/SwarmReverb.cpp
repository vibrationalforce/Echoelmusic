#include "SwarmReverb.h"
#include <cmath>
#include <algorithm>

//==============================================================================
// Constructor
//==============================================================================

SwarmReverb::SwarmReverb()
    : rng(std::random_device{}())
    , uniformDist(-1.0f, 1.0f)
    , normalDist(0.0f, 1.0f)
{
    initializeParticles();
}

//==============================================================================
// Swarm Parameters
//==============================================================================

void SwarmReverb::setParticleCount(int count)
{
    targetParticleCount = juce::jlimit(100, 1000, count);

    // Reinitialize particles if count changed significantly
    if (std::abs(static_cast<int>(particles.size()) - targetParticleCount) > 50)
    {
        initializeParticles();
    }
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

//==============================================================================
// Space Parameters
//==============================================================================

void SwarmReverb::setSize(float size)
{
    float normalizedSize = juce::jlimit(0.0f, 1.0f, size);

    // Map to room size (logarithmic: 1m to 50m)
    roomSize = MIN_ROOM_SIZE * std::pow(MAX_ROOM_SIZE / MIN_ROOM_SIZE, normalizedSize);
}

void SwarmReverb::setDiffusion(float amount)
{
    diffusion = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Time Parameters
//==============================================================================

void SwarmReverb::setDecayTime(float timeSeconds)
{
    decayTime = juce::jlimit(0.1f, 20.0f, timeSeconds);
}

void SwarmReverb::setPreDelay(float delayMs)
{
    preDelayMs = juce::jlimit(0.0f, 500.0f, delayMs);
}

//==============================================================================
// Tone Parameters
//==============================================================================

void SwarmReverb::setHighCut(float freqHz)
{
    highCutFreq = juce::jlimit(1000.0f, 20000.0f, freqHz);
}

void SwarmReverb::setLowCut(float freqHz)
{
    lowCutFreq = juce::jlimit(20.0f, 1000.0f, freqHz);
}

void SwarmReverb::setDamping(float amount)
{
    damping = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Special Modes
//==============================================================================

void SwarmReverb::setShimmerEnabled(bool enable)
{
    shimmerEnabled = enable;
}

void SwarmReverb::setShimmerPitch(float semitones)
{
    shimmerPitchSemitones = juce::jlimit(-12.0f, 12.0f, semitones);
}

void SwarmReverb::setFreezeEnabled(bool enable)
{
    freezeEnabled = enable;
}

//==============================================================================
// Modulation
//==============================================================================

void SwarmReverb::setModulationEnabled(bool enable)
{
    modulationEnabled = enable;
}

void SwarmReverb::setModulationRate(float rateHz)
{
    modulationRate = juce::jlimit(0.01f, 10.0f, rateHz);
}

void SwarmReverb::setModulationDepth(float depth)
{
    modulationDepth = juce::jlimit(0.0f, 1.0f, depth);
}

//==============================================================================
// Bio-Reactive
//==============================================================================

void SwarmReverb::setBioReactiveEnabled(bool enable)
{
    bioReactiveEnabled = enable;
}

void SwarmReverb::updateBioData(float hrvNormalized, float coherence, float stressLevel)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrvNormalized);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentStress = juce::jlimit(0.0f, 1.0f, stressLevel);
}

void SwarmReverb::applyBioReactiveModulation()
{
    if (!bioReactiveEnabled)
        return;

    // Bio-reactive logic:
    // High HRV + High Coherence = Low chaos, smooth reverb (calm, flowing)
    // Low HRV + High Stress = High chaos, dynamic reverb (energetic, turbulent)

    float bioFactor = (currentHRV + currentCoherence) * 0.5f;
    float stressFactor = currentStress;

    // Modulate chaos: stress increases, coherence decreases it
    float bioModulation = (1.0f - bioFactor) * 0.3f + stressFactor * 0.2f;
    float effectiveChaos = chaos + bioModulation;
    chaos = juce::jlimit(0.0f, 1.0f, effectiveChaos);
}

//==============================================================================
// Mix
//==============================================================================

void SwarmReverb::setMix(float wetAmount)
{
    wetMix = juce::jlimit(0.0f, 1.0f, wetAmount);
}

//==============================================================================
// Processing
//==============================================================================

void SwarmReverb::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    // Prepare pre-delay
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = maxBlockSize;
    spec.numChannels = 1;

    preDelayLine.prepare(spec);
    preDelayLine.setMaximumDelayInSamples(static_cast<int>(sampleRate * 0.5));  // 500ms max

    // Prepare all particle delay lines
    for (auto& particle : particles)
    {
        particle.delayLine.prepare(spec);
        particle.delayLine.setMaximumDelayInSamples(static_cast<int>(sampleRate * MAX_DELAY_TIME));

        particle.filter.prepare(spec);
        updateParticleFilter(particle);
    }

    reset();
}

void SwarmReverb::reset()
{
    preDelayLine.reset();

    for (auto& particle : particles)
    {
        particle.delayLine.reset();
        particle.filter.reset();
        particle.age = 0.0f;
    }

    lfoPhase = 0.0f;
}

void SwarmReverb::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (wetMix < 0.01f)
        return;  // Bypassed

    // Apply bio-reactive modulation
    applyBioReactiveModulation();

    // Update LFO
    updateLFO();

    // Calculate delta time for particle updates
    float deltaTime = numSamples / static_cast<float>(currentSampleRate);

    // Update swarm behavior (only if not frozen)
    if (!freezeEnabled)
    {
        updateSwarm(deltaTime);
    }

    // Process audio through swarm
    juce::AudioBuffer<float> wetBuffer(numChannels, numSamples);
    wetBuffer.clear();

    // Apply pre-delay
    float preDelaySamples = (preDelayMs / 1000.0f) * currentSampleRate;
    preDelayLine.setDelay(preDelaySamples);

    // Process each channel
    for (int channel = 0; channel < numChannels; ++channel)
    {
        const float* inputData = buffer.getReadPointer(channel);
        float* wetData = wetBuffer.getWritePointer(channel);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float inputSample = inputData[sample];

            // Apply pre-delay
            preDelayLine.pushSample(0, inputSample);
            float delayedInput = preDelayLine.popSample(0);

            float swarmOutput = 0.0f;

            // Process through all particles
            for (auto& particle : particles)
            {
                // Calculate delay time based on particle position
                float delayTime = calculateDelayTime(particle);
                float delaySamples = delayTime * currentSampleRate;

                // Set delay
                particle.delayLine.setDelay(delaySamples);

                // Push input to particle delay line
                particle.delayLine.pushSample(0, delayedInput);

                // Get delayed output
                float particleOutput = particle.delayLine.popSample(0);

                // Apply particle filter
                particleOutput = particle.filter.processSample(particleOutput);

                // Apply gain (distance attenuation)
                float gain = calculateGain(particle);
                particleOutput *= gain;

                // Apply pitch shift (shimmer mode)
                if (shimmerEnabled)
                {
                    particle.pitchShift = std::pow(2.0f, shimmerPitchSemitones / 12.0f);
                    // Simplified pitch shift (just gain modulation here)
                    // Real pitch shifting would use granular synthesis or phase vocoder
                    particleOutput *= particle.pitchShift;
                }

                // Apply decay envelope
                float ageNormalized = particle.age / decayTime;
                float decayGain = 1.0f - ageNormalized;
                decayGain = juce::jlimit(0.0f, 1.0f, decayGain);
                particleOutput *= decayGain;

                // Accumulate to swarm output
                swarmOutput += particleOutput;
            }

            // Normalize by particle count
            swarmOutput /= std::max(1, static_cast<int>(particles.size()));

            // Write to wet buffer
            wetData[sample] = swarmOutput;
        }
    }

    // Mix dry and wet
    for (int channel = 0; channel < numChannels; ++channel)
    {
        float* outputData = buffer.getWritePointer(channel);
        const float* wetData = wetBuffer.getReadPointer(channel);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float dry = outputData[sample];
            float wet = wetData[sample];

            outputData[sample] = dry * (1.0f - wetMix) + wet * wetMix;
        }
    }

    // Update metering
    updateMetering();
}

//==============================================================================
// Particle System
//==============================================================================

void SwarmReverb::initializeParticles()
{
    particles.clear();
    particles.reserve(targetParticleCount);

    for (int i = 0; i < targetParticleCount; ++i)
    {
        Particle particle;

        // Random initial position within room (centered at origin)
        float halfRoom = roomSize * 0.5f;
        particle.x = uniformDist(rng) * halfRoom;
        particle.y = uniformDist(rng) * halfRoom;
        particle.z = uniformDist(rng) * halfRoom;

        // Random initial velocity
        particle.vx = uniformDist(rng) * 0.5f;
        particle.vy = uniformDist(rng) * 0.5f;
        particle.vz = uniformDist(rng) * 0.5f;

        // Random initial age
        particle.age = uniformDist(rng) * decayTime * 0.5f;

        particles.push_back(particle);
    }

    DBG("Swarm Reverb: Initialized " + juce::String(particles.size()) + " particles");
}

void SwarmReverb::updateSwarm(float deltaTime)
{
    // Update each particle using swarm rules
    for (auto& particle : particles)
    {
        applySwarmRules(particle, deltaTime);

        // Update age
        particle.age += deltaTime;

        // Respawn particle if it's too old
        if (particle.age > decayTime)
        {
            // Reset to random position near origin
            float halfRoom = roomSize * 0.5f * diffusion;
            particle.x = uniformDist(rng) * halfRoom;
            particle.y = uniformDist(rng) * halfRoom;
            particle.z = uniformDist(rng) * halfRoom;

            particle.vx = uniformDist(rng) * 0.5f;
            particle.vy = uniformDist(rng) * 0.5f;
            particle.vz = uniformDist(rng) * 0.5f;

            particle.age = 0.0f;
        }

        // Update particle filter based on new position
        updateParticleFilter(particle);
    }
}

void SwarmReverb::applySwarmRules(Particle& particle, float deltaTime)
{
    // Swarm behavior rules (Boids algorithm)

    // 1. COHESION: Move towards center of mass (swarm center)
    float cohesionForceX = -particle.x * cohesion * 0.1f;
    float cohesionForceY = -particle.y * cohesion * 0.1f;
    float cohesionForceZ = -particle.z * cohesion * 0.1f;

    // 2. SEPARATION: Avoid nearby particles
    float separationForceX = 0.0f;
    float separationForceY = 0.0f;
    float separationForceZ = 0.0f;

    const float separationDistance = roomSize * 0.1f;  // 10% of room size

    for (const auto& other : particles)
    {
        if (&other == &particle)
            continue;

        float distance = calculateDistance(particle.x, particle.y, particle.z,
                                          other.x, other.y, other.z);

        if (distance < separationDistance && distance > 0.001f)
        {
            float dx = particle.x - other.x;
            float dy = particle.y - other.y;
            float dz = particle.z - other.z;

            float repulsionStrength = separation * (1.0f - distance / separationDistance);

            separationForceX += dx * repulsionStrength;
            separationForceY += dy * repulsionStrength;
            separationForceZ += dz * repulsionStrength;
        }
    }

    // 3. CHAOS: Random movement
    float chaosForceX = normalDist(rng) * chaos * 2.0f;
    float chaosForceY = normalDist(rng) * chaos * 2.0f;
    float chaosForceZ = normalDist(rng) * chaos * 2.0f;

    // 4. MODULATION: LFO movement
    float modulationForceX = 0.0f;
    float modulationForceY = 0.0f;
    float modulationForceZ = 0.0f;

    if (modulationEnabled)
    {
        float lfoValue = std::sin(lfoPhase * juce::MathConstants<float>::twoPi);
        modulationForceX = lfoValue * modulationDepth * 1.0f;
        modulationForceY = std::cos(lfoPhase * juce::MathConstants<float>::twoPi) * modulationDepth * 1.0f;
        modulationForceZ = std::sin(lfoPhase * 2.0f * juce::MathConstants<float>::twoPi) * modulationDepth * 0.5f;
    }

    // Sum all forces
    float totalForceX = cohesionForceX + separationForceX + chaosForceX + modulationForceX;
    float totalForceY = cohesionForceY + separationForceY + chaosForceY + modulationForceY;
    float totalForceZ = cohesionForceZ + separationForceZ + chaosForceZ + modulationForceZ;

    // Update velocity (acceleration = force / mass, assuming mass = 1)
    particle.vx += totalForceX * deltaTime;
    particle.vy += totalForceY * deltaTime;
    particle.vz += totalForceZ * deltaTime;

    // Apply velocity damping (air resistance)
    float dampingFactor = 0.95f;
    particle.vx *= dampingFactor;
    particle.vy *= dampingFactor;
    particle.vz *= dampingFactor;

    // Limit velocity
    float maxVelocity = roomSize * 0.5f;  // Max = half room per second
    particle.vx = juce::jlimit(-maxVelocity, maxVelocity, particle.vx);
    particle.vy = juce::jlimit(-maxVelocity, maxVelocity, particle.vy);
    particle.vz = juce::jlimit(-maxVelocity, maxVelocity, particle.vz);

    // Update position
    particle.x += particle.vx * deltaTime;
    particle.y += particle.vy * deltaTime;
    particle.z += particle.vz * deltaTime;

    // Boundary conditions (bounce off walls)
    float halfRoom = roomSize * 0.5f;

    if (particle.x < -halfRoom || particle.x > halfRoom)
    {
        particle.vx = -particle.vx * 0.8f;  // Reverse and dampen
        particle.x = juce::jlimit(-halfRoom, halfRoom, particle.x);
    }

    if (particle.y < -halfRoom || particle.y > halfRoom)
    {
        particle.vy = -particle.vy * 0.8f;
        particle.y = juce::jlimit(-halfRoom, halfRoom, particle.y);
    }

    if (particle.z < -halfRoom || particle.z > halfRoom)
    {
        particle.vz = -particle.vz * 0.8f;
        particle.z = juce::jlimit(-halfRoom, halfRoom, particle.z);
    }
}

float SwarmReverb::calculateDistance(float x1, float y1, float z1, float x2, float y2, float z2) const
{
    float dx = x2 - x1;
    float dy = y2 - y1;
    float dz = z2 - z1;

    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

float SwarmReverb::calculateDelayTime(const Particle& particle) const
{
    // Calculate distance from listener (at origin)
    float distance = calculateDistance(particle.x, particle.y, particle.z,
                                      LISTENER_X, LISTENER_Y, LISTENER_Z);

    // Speed of sound in air: ~343 m/s
    const float speedOfSound = 343.0f;

    float delayTime = distance / speedOfSound;

    // Clamp to maximum delay time
    delayTime = juce::jlimit(0.0f, MAX_DELAY_TIME, delayTime);

    return delayTime;
}

float SwarmReverb::calculateGain(const Particle& particle) const
{
    // Inverse square law: gain ∝ 1 / distance²
    float distance = calculateDistance(particle.x, particle.y, particle.z,
                                      LISTENER_X, LISTENER_Y, LISTENER_Z);

    // Add small offset to avoid division by zero
    distance = std::max(0.1f, distance);

    float gain = 1.0f / (distance * distance);

    // Normalize to reasonable range
    gain = std::min(1.0f, gain * roomSize);

    return gain;
}

void SwarmReverb::updateParticleFilter(Particle& particle)
{
    // Filter frequency depends on distance (air absorption)
    // Distant particles = more high-frequency damping

    float distance = calculateDistance(particle.x, particle.y, particle.z,
                                      LISTENER_X, LISTENER_Y, LISTENER_Z);

    // Map distance to filter cutoff (closer = brighter)
    float normalizedDistance = distance / roomSize;
    float cutoffFreq = highCutFreq * (1.0f - normalizedDistance * damping);
    cutoffFreq = juce::jlimit(lowCutFreq, highCutFreq, cutoffFreq);

    // Create low-pass filter
    auto coefficients = juce::dsp::IIR::Coefficients<float>::makeLowPass(currentSampleRate, cutoffFreq);
    *particle.filter.coefficients = *coefficients;
}

//==============================================================================
// LFO
//==============================================================================

void SwarmReverb::updateLFO()
{
    if (!modulationEnabled)
        return;

    // Update LFO phase (per-sample would be more accurate, but this is close enough)
    float lfoIncrement = modulationRate / currentSampleRate;
    lfoPhase += lfoIncrement;

    if (lfoPhase >= 1.0f)
        lfoPhase -= 1.0f;
}

//==============================================================================
// Metering
//==============================================================================

void SwarmReverb::updateMetering()
{
    // Calculate average particle distance from center
    float sumDistance = 0.0f;

    for (const auto& particle : particles)
    {
        float distance = calculateDistance(particle.x, particle.y, particle.z,
                                          LISTENER_X, LISTENER_Y, LISTENER_Z);
        sumDistance += distance;
    }

    avgParticleDistance = particles.empty() ? 0.0f : sumDistance / particles.size();

    // Calculate swarm density (inverse of average distance)
    swarmDensity = 1.0f - juce::jlimit(0.0f, 1.0f, avgParticleDistance / roomSize);
}
