#pragma once

#include <JuceHeader.h>
#include <vector>
#include <random>

/**
 * Swarm Synthesis Reverb
 *
 * Revolutionary reverb using swarm/particle algorithms inspired by Soundtoys SpaceBlender (2025).
 * Creates dense, textured reverb spaces using hundreds of particles with swarm behavior.
 *
 * **Innovation**: First bio-reactive swarm reverb with HRV-controlled particle chaos.
 *
 * NOT traditional algorithmic reverb (Freeverb, plate, hall, etc.)
 * NOT convolution reverb (impulse responses)
 * NEW APPROACH: Particle/swarm synthesis
 *
 * How It Works:
 * - Creates N particles (100-1000) in virtual 3D space
 * - Each particle = delay line + filter + gain
 * - Particles follow swarm rules:
 *   - Cohesion: Attraction to center (group together)
 *   - Separation: Repulsion from neighbors (avoid collisions)
 *   - Chaos: Random movement (unpredictability)
 * - Particle positions update each sample → unique delay/filter per particle
 * - Output = mix of all particle outputs with distance-based gain
 *
 * Result:
 * - Dense, "living" reverb tails that evolve organically
 * - Unique texture unavailable in traditional reverbs
 * - Ideal for ambient, cinematic, experimental music
 * - Bio-reactive: HRV controls chaos → reverb "breathes" with you
 *
 * Features:
 * - 100-1000 particles (adjustable)
 * - 3D virtual space (10m × 10m × 10m)
 * - Swarm behavior parameters (cohesion, separation, chaos)
 * - Size control (space dimensions)
 * - Decay time (particle lifetime)
 * - Density (particle count)
 * - Diffusion (particle spread)
 * - Modulation (LFO on particle movement)
 * - Bio-reactive chaos (HRV-controlled randomness)
 * - Shimmer mode (pitch-shifting particles)
 * - Freeze mode (lock particle positions)
 * - Pre-delay (initial delay before reverb)
 * - High/Low cut filters
 * - Dry/Wet mix
 *
 * Use Cases:
 * - Ambient textures and soundscapes
 * - Cinematic atmosphere
 * - Experimental/avant-garde music
 * - Sound design for film/games
 * - Meditation and relaxation (bio-reactive)
 * - Live performance (freeze/modulation)
 */
class SwarmReverb
{
public:
    //==========================================================================
    // Particle (Internal)
    //==========================================================================

    struct Particle
    {
        // Position in 3D space (meters)
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;

        // Velocity (m/s)
        float vx = 0.0f;
        float vy = 0.0f;
        float vz = 0.0f;

        // Delay line
        juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> delayLine { 192000 };  // Max 4 sec @ 48kHz

        // Filter (per-particle tone)
        juce::dsp::IIR::Filter<float> filter;

        // Gain (distance-based attenuation)
        float gain = 1.0f;

        // Age (for decay)
        float age = 0.0f;

        // Pitch shift amount (for shimmer mode)
        float pitchShift = 1.0f;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SwarmReverb();
    ~SwarmReverb() = default;

    //==========================================================================
    // Swarm Parameters
    //==========================================================================

    /** Set number of particles (100 to 1000) */
    void setParticleCount(int count);

    /** Set cohesion strength (0.0 to 1.0) - Attraction to center */
    void setCohesion(float amount);

    /** Set separation strength (0.0 to 1.0) - Repulsion from neighbors */
    void setSeparation(float amount);

    /** Set chaos amount (0.0 to 1.0) - Random movement */
    void setChaos(float amount);

    //==========================================================================
    // Space Parameters
    //==========================================================================

    /** Set room size (0.0 to 1.0) - Maps to 1m - 50m dimensions */
    void setSize(float size);

    /** Set diffusion (0.0 to 1.0) - Particle spread */
    void setDiffusion(float amount);

    //==========================================================================
    // Time Parameters
    //==========================================================================

    /** Set decay time in seconds (0.1 to 20.0) */
    void setDecayTime(float timeSeconds);

    /** Set pre-delay in milliseconds (0 to 500) */
    void setPreDelay(float delayMs);

    //==========================================================================
    // Tone Parameters
    //==========================================================================

    /** Set high cut frequency in Hz (1000 to 20000) */
    void setHighCut(float freqHz);

    /** Set low cut frequency in Hz (20 to 1000) */
    void setLowCut(float freqHz);

    /** Set damping amount (0.0 to 1.0) - High-frequency absorption */
    void setDamping(float amount);

    //==========================================================================
    // Special Modes
    //==========================================================================

    /** Enable shimmer mode (pitch-shifting particles) */
    void setShimmerEnabled(bool enable);

    /** Set shimmer pitch shift in semitones (±12) */
    void setShimmerPitch(float semitones);

    /** Enable freeze mode (lock particle positions) */
    void setFreezeEnabled(bool enable);

    //==========================================================================
    // Modulation
    //==========================================================================

    /** Enable LFO modulation of particle movement */
    void setModulationEnabled(bool enable);

    /** Set modulation rate in Hz (0.01 to 10) */
    void setModulationRate(float rateHz);

    /** Set modulation depth (0.0 to 1.0) */
    void setModulationDepth(float depth);

    //==========================================================================
    // Bio-Reactive Integration
    //==========================================================================

    /** Enable bio-reactive chaos (HRV controls randomness) */
    void setBioReactiveEnabled(bool enable);

    /** Update bio-data for reactive processing */
    void updateBioData(float hrvNormalized, float coherence, float stressLevel);

    //==========================================================================
    // Mix
    //==========================================================================

    /** Set dry/wet mix (0.0 = dry, 1.0 = wet) */
    void setMix(float wetAmount);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset state */
    void reset();

    /** Process audio buffer (mono or stereo) */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Analysis
    //==========================================================================

    /** Get current particle count */
    int getCurrentParticleCount() const { return particles.size(); }

    /** Get average particle distance from center */
    float getAverageParticleDistance() const { return avgParticleDistance; }

    /** Get current swarm density (0.0 to 1.0) */
    float getSwarmDensity() const { return swarmDensity; }

private:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr float MAX_ROOM_SIZE = 50.0f;  // meters
    static constexpr float MIN_ROOM_SIZE = 1.0f;   // meters
    static constexpr float MAX_DELAY_TIME = 4.0f;  // seconds

    //==========================================================================
    // Parameters
    //==========================================================================

    int targetParticleCount = 300;

    float cohesion = 0.3f;
    float separation = 0.5f;
    float chaos = 0.3f;

    float roomSize = 10.0f;  // meters
    float diffusion = 0.7f;

    float decayTime = 2.0f;  // seconds
    float preDelayMs = 0.0f;

    float highCutFreq = 8000.0f;
    float lowCutFreq = 100.0f;
    float damping = 0.5f;

    bool shimmerEnabled = false;
    float shimmerPitchSemitones = 12.0f;

    bool freezeEnabled = false;

    bool modulationEnabled = false;
    float modulationRate = 0.5f;
    float modulationDepth = 0.3f;

    bool bioReactiveEnabled = false;
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.0f;

    float wetMix = 0.5f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Particle System
    //==========================================================================

    std::vector<Particle> particles;

    // Listener position (origin)
    static constexpr float LISTENER_X = 0.0f;
    static constexpr float LISTENER_Y = 0.0f;
    static constexpr float LISTENER_Z = 0.0f;

    //==========================================================================
    // Pre-Delay
    //==========================================================================

    juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> preDelayLine { 96000 };

    //==========================================================================
    // Modulation
    //==========================================================================

    float lfoPhase = 0.0f;

    //==========================================================================
    // Random Number Generator
    //==========================================================================

    std::mt19937 rng;
    std::uniform_real_distribution<float> uniformDist;
    std::normal_distribution<float> normalDist;

    //==========================================================================
    // Metering
    //==========================================================================

    float avgParticleDistance = 0.0f;
    float swarmDensity = 0.0f;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    /** Initialize particle system */
    void initializeParticles();

    /** Update swarm behavior for all particles */
    void updateSwarm(float deltaTime);

    /** Apply swarm rules to a single particle */
    void applySwarmRules(Particle& particle, float deltaTime);

    /** Calculate distance between two points in 3D */
    float calculateDistance(float x1, float y1, float z1, float x2, float y2, float z2) const;

    /** Calculate delay time based on particle position (distance from listener) */
    float calculateDelayTime(const Particle& particle) const;

    /** Calculate gain based on particle position (inverse square law) */
    float calculateGain(const Particle& particle) const;

    /** Update particle filter based on position and damping */
    void updateParticleFilter(Particle& particle);

    /** Apply bio-reactive modulation to swarm parameters */
    void applyBioReactiveModulation();

    /** Update LFO for modulation */
    void updateLFO();

    /** Update metering values */
    void updateMetering();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SwarmReverb)
};
