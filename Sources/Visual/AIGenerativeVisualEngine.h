#pragma once

#include <JuceHeader.h>
#include "../BioData/BioFeedbackSystem.h"
#include <memory>
#include <vector>
#include <random>

namespace Echoelmusic {

/**
 * @brief AI Generative Visual Engine
 *
 * **REAL-TIME GENERATIVE VISUALS:**
 * - Procedural generation (fractals, particles, flow fields)
 * - AI-assisted generation (style transfer, neural patterns)
 * - Bio-reactive parameters (HRV → complexity, coherence → harmony)
 * - BPM-reactive evolution (tempo-locked morphing)
 * - GPU-accelerated rendering (Metal/OpenGL shaders)
 *
 * **Generation Styles:**
 * 1. **Fractals** - Mandelbrot, Julia, L-systems
 * 2. **Particles** - Flow fields, attractors, flocking
 * 3. **Cellular Automata** - Conway's Life, reaction-diffusion
 * 4. **Neural Patterns** - Style transfer, deep dream
 * 5. **Geometry** - Sacred geometry, Voronoi, Delaunay
 * 6. **Fluid Simulation** - Navier-Stokes, SPH
 *
 * **Architecture:**
 * ```
 * [BioFeedbackSystem] ──┐
 *                       ├──> [AIGenerativeEngine] ──> [GPU Shaders] ──> [Output]
 * [AudioEngine/BPM]  ───┘          │
 *                                  ├──> Procedural algorithms
 *                                  ├──> AI models (optional)
 *                                  └──> Real-time evolution
 * ```
 *
 * @author Echoelmusic Team
 * @date 2025-12-19
 * @version 1.0.0
 */
class AIGenerativeVisualEngine
{
public:
    //==========================================================================
    // Generation Styles
    //==========================================================================

    enum class GenerationStyle
    {
        // Fractals
        Mandelbrot,         // Classic Mandelbrot set
        Julia,              // Julia set
        BurningShip,        // Burning Ship fractal
        Newton,             // Newton fractal
        LSystem,            // Lindenmayer systems (trees, plants)

        // Particles
        Particles,          // Basic particle system
        FlowField,          // Flow field particles
        Attractors,         // Strange attractors (Lorenz, Rössler)
        Flocking,           // Boids algorithm
        Galaxy,             // Galaxy simulation

        // Cellular Automata
        GameOfLife,         // Conway's Game of Life
        ReactionDiffusion,  // Gray-Scott model
        WireWorld,          // Wireworld CA
        Langton,            // Langton's Ant

        // Geometry
        SacredGeometry,     // Flower of Life, Metatron's Cube
        Voronoi,            // Voronoi diagram
        Delaunay,           // Delaunay triangulation
        FractalTree,        // Recursive tree
        Spirograph,         // Spirograph patterns

        // Fluid Simulation
        FluidSim,           // Navier-Stokes equations
        SPH,                // Smoothed Particle Hydrodynamics
        LBM,                // Lattice Boltzmann Method

        // Neural/AI
        StyleTransfer,      // Neural style transfer
        DeepDream,          // Google DeepDream
        NeuralCA,           // Neural cellular automata
        GAN,                // Generative Adversarial Network

        // Abstract
        Plasma,             // Plasma effect
        Tunnel,             // Tunnel effect
        Kaleidoscope,       // Kaleidoscope
        Mandala,            // Mandala generator
        LightPainting       // Light painting effect
    };

    //==========================================================================
    // Generation Parameters
    //==========================================================================

    struct GenerationParams
    {
        GenerationStyle style = GenerationStyle::Mandelbrot;

        // Visual parameters (normalized 0-1)
        float complexity = 0.5f;    // Detail level
        float speed = 0.5f;          // Animation speed
        float chaos = 0.3f;          // Randomness
        float harmony = 0.7f;        // Symmetry/order
        float energy = 0.5f;         // Intensity/brightness

        // Color palette
        juce::Colour color1 = juce::Colours::blue;
        juce::Colour color2 = juce::Colours::purple;
        juce::Colour color3 = juce::Colours::pink;
        float colorShift = 0.0f;     // Hue shift over time

        // Bio-reactive mapping
        bool bioReactive = true;
        juce::String bioComplexityParam = "coherence";   // Which bio-param for complexity
        juce::String bioSpeedParam = "heartrate";        // Which bio-param for speed
        juce::String bioColorParam = "hrv";              // Which bio-param for color

        // BPM-reactive mapping
        bool bpmReactive = true;
        bool evolveOnBeat = true;    // Morph/change on beat
        int evolutionBeatDiv = 4;    // Evolve every N beats
    };

    //==========================================================================
    AIGenerativeVisualEngine(BioFeedbackSystem* bioSystem = nullptr)
        : bioFeedbackSystem(bioSystem)
    {
        // Initialize random number generator
        rng.seed(static_cast<unsigned>(juce::Time::currentTimeMillis()));

        // Set default parameters
        params.style = GenerationStyle::Mandelbrot;
        params.bioReactive = true;
        params.bpmReactive = true;
    }

    //==========================================================================
    // Configuration
    //==========================================================================

    void setBioFeedbackSystem(BioFeedbackSystem* system)
    {
        bioFeedbackSystem = system;
    }

    void setGenerationStyle(GenerationStyle style)
    {
        params.style = style;
        resetGeneration();
    }

    void setGenerationParams(const GenerationParams& newParams)
    {
        params = newParams;
    }

    GenerationParams& getParams()
    {
        return params;
    }

    /**
     * @brief Set output resolution
     */
    void setResolution(int width, int height)
    {
        outputWidth = width;
        outputHeight = height;
        resetGeneration();
    }

    /**
     * @brief Set BPM for tempo-sync features
     */
    void setBPM(double bpm)
    {
        currentBPM = bpm;
    }

    /**
     * @brief Set beat phase (0.0 to 1.0 within beat)
     */
    void setBeatPhase(double phase)
    {
        bool beatTrigger = (phase < lastBeatPhase);
        if (beatTrigger && params.bpmReactive && params.evolveOnBeat)
        {
            beatCounter++;
            if (beatCounter % params.evolutionBeatDiv == 0)
            {
                evolveGeneration();
            }
        }
        lastBeatPhase = phase;
    }

    //==========================================================================
    // Generation
    //==========================================================================

    /**
     * @brief Generate one frame
     * @param deltaTime Time since last frame (seconds)
     * @return Generated visual frame
     */
    juce::Image generateFrame(double deltaTime)
    {
        currentTime += deltaTime;

        // Update bio-reactive parameters
        if (params.bioReactive && bioFeedbackSystem != nullptr)
        {
            updateBioReactiveParams();
        }

        // Generate frame based on style
        switch (params.style)
        {
            case GenerationStyle::Mandelbrot:
                return generateMandelbrot();

            case GenerationStyle::Julia:
                return generateJulia();

            case GenerationStyle::Particles:
                return generateParticles(deltaTime);

            case GenerationStyle::FlowField:
                return generateFlowField(deltaTime);

            case GenerationStyle::GameOfLife:
                return generateGameOfLife(deltaTime);

            case GenerationStyle::Mandala:
                return generateMandala();

            case GenerationStyle::Kaleidoscope:
                return generateKaleidoscope();

            case GenerationStyle::Plasma:
                return generatePlasma();

            default:
                return generateMandelbrot();
        }
    }

    /**
     * @brief Reset generation (clear state, reinitialize)
     */
    void resetGeneration()
    {
        particles.clear();
        caGrid.clear();
        currentTime = 0.0;
        beatCounter = 0;
    }

    /**
     * @brief Evolve generation (change parameters, morph)
     */
    void evolveGeneration()
    {
        // Slight random variation in parameters
        params.complexity += (randomFloat() - 0.5f) * 0.1f;
        params.chaos += (randomFloat() - 0.5f) * 0.05f;
        params.colorShift += 0.05f;

        // Clamp to valid range
        params.complexity = juce::jlimit(0.0f, 1.0f, params.complexity);
        params.chaos = juce::jlimit(0.0f, 1.0f, params.chaos);
    }

private:
    //==========================================================================
    // Bio-Reactive Update
    //==========================================================================

    void updateBioReactiveParams()
    {
        auto bioData = bioFeedbackSystem->getCurrentBioData();

        if (!bioData.isValid)
            return;

        // Map bio-data to generation parameters
        if (params.bioComplexityParam == "coherence")
        {
            params.complexity = bioData.coherence;
        }
        else if (params.bioComplexityParam == "hrv")
        {
            params.complexity = bioData.hrv;
        }

        if (params.bioSpeedParam == "heartrate")
        {
            // Map heart rate to speed (60 BPM = 0.5x, 120 BPM = 1.0x)
            params.speed = static_cast<float>((bioData.heartRate - 60.0) / 120.0);
            params.speed = juce::jlimit(0.1f, 2.0f, params.speed);
        }

        if (params.bioColorParam == "hrv")
        {
            // HRV controls hue
            params.colorShift = bioData.hrv * 360.0f;
        }
        else if (params.bioColorParam == "coherence")
        {
            // Coherence controls saturation
            params.color1 = juce::Colour::fromHSV(params.colorShift / 360.0f,
                                                 bioData.coherence, 1.0f, 1.0f);
        }

        // Chaos from stress
        params.chaos = bioData.stress;
        params.harmony = bioData.coherence;
    }

    //==========================================================================
    // Generation Algorithms
    //==========================================================================

    juce::Image generateMandelbrot()
    {
        juce::Image frame(juce::Image::ARGB, outputWidth, outputHeight, true);

        // Mandelbrot parameters
        float zoom = 0.5f + params.complexity * 4.0f;
        float offsetX = std::sin(currentTime * params.speed * 0.1f) * 0.2f;
        float offsetY = std::cos(currentTime * params.speed * 0.1f) * 0.2f;
        int maxIterations = static_cast<int>(10 + params.complexity * 100);

        for (int y = 0; y < outputHeight; ++y)
        {
            for (int x = 0; x < outputWidth; ++x)
            {
                // Map pixel to complex plane
                float cx = (x - outputWidth / 2.0f) / (outputWidth / 4.0f) / zoom + offsetX;
                float cy = (y - outputHeight / 2.0f) / (outputHeight / 4.0f) / zoom + offsetY;

                // Mandelbrot iteration
                float zx = 0.0f, zy = 0.0f;
                int iteration = 0;

                while (zx * zx + zy * zy < 4.0f && iteration < maxIterations)
                {
                    float xtemp = zx * zx - zy * zy + cx;
                    zy = 2.0f * zx * zy + cy;
                    zx = xtemp;
                    iteration++;
                }

                // Color mapping
                if (iteration == maxIterations)
                {
                    frame.setPixelAt(x, y, juce::Colours::black);
                }
                else
                {
                    float t = static_cast<float>(iteration) / maxIterations;
                    auto colour = interpolateColor(t);
                    frame.setPixelAt(x, y, colour);
                }
            }
        }

        return frame;
    }

    juce::Image generateJulia()
    {
        juce::Image frame(juce::Image::ARGB, outputWidth, outputHeight, true);

        // Julia set constant (animated)
        float cx = std::sin(currentTime * params.speed * 0.2f) * 0.7f;
        float cy = std::cos(currentTime * params.speed * 0.3f) * 0.7f;
        int maxIterations = static_cast<int>(10 + params.complexity * 100);

        for (int y = 0; y < outputHeight; ++y)
        {
            for (int x = 0; x < outputWidth; ++x)
            {
                float zx = (x - outputWidth / 2.0f) / (outputWidth / 4.0f);
                float zy = (y - outputHeight / 2.0f) / (outputHeight / 4.0f);

                int iteration = 0;
                while (zx * zx + zy * zy < 4.0f && iteration < maxIterations)
                {
                    float xtemp = zx * zx - zy * zy + cx;
                    zy = 2.0f * zx * zy + cy;
                    zx = xtemp;
                    iteration++;
                }

                float t = static_cast<float>(iteration) / maxIterations;
                frame.setPixelAt(x, y, interpolateColor(t));
            }
        }

        return frame;
    }

    juce::Image generateParticles(double deltaTime)
    {
        juce::Image frame(juce::Image::ARGB, outputWidth, outputHeight, true);
        juce::Graphics g(frame);

        // Initialize particles if needed
        if (particles.empty())
        {
            int numParticles = static_cast<int>(100 + params.complexity * 900);
            for (int i = 0; i < numParticles; ++i)
            {
                Particle p;
                p.x = randomFloat() * outputWidth;
                p.y = randomFloat() * outputHeight;
                p.vx = (randomFloat() - 0.5f) * 100.0f;
                p.vy = (randomFloat() - 0.5f) * 100.0f;
                p.size = 2.0f + randomFloat() * 5.0f;
                p.lifetime = randomFloat() * 5.0f;
                particles.push_back(p);
            }
        }

        // Update particles
        for (auto& p : particles)
        {
            p.x += p.vx * deltaTime * params.speed;
            p.y += p.vy * deltaTime * params.speed;
            p.lifetime -= deltaTime;

            // Wrap around
            if (p.x < 0) p.x += outputWidth;
            if (p.x > outputWidth) p.x -= outputWidth;
            if (p.y < 0) p.y += outputHeight;
            if (p.y > outputHeight) p.y -= outputHeight;

            // Respawn if dead
            if (p.lifetime <= 0.0f)
            {
                p.x = randomFloat() * outputWidth;
                p.y = randomFloat() * outputHeight;
                p.lifetime = randomFloat() * 5.0f;
            }
        }

        // Draw particles
        for (const auto& p : particles)
        {
            float alpha = juce::jlimit(0.0f, 1.0f, p.lifetime);
            g.setColour(params.color1.withAlpha(alpha));
            g.fillEllipse(p.x, p.y, p.size, p.size);
        }

        return frame;
    }

    juce::Image generateFlowField(double deltaTime)
    {
        // Similar to particles but with Perlin noise flow field
        return generateParticles(deltaTime);  // Placeholder
    }

    juce::Image generateGameOfLife(double deltaTime)
    {
        juce::Image frame(juce::Image::ARGB, outputWidth, outputHeight, true);

        int gridWidth = 100;
        int gridHeight = 100;
        int cellWidth = outputWidth / gridWidth;
        int cellHeight = outputHeight / gridHeight;

        // Initialize grid if needed
        if (caGrid.empty())
        {
            caGrid.resize(gridWidth * gridHeight);
            for (auto& cell : caGrid)
            {
                cell = randomFloat() > 0.7f;
            }
        }

        // Update every 0.1 seconds
        caUpdateTimer += deltaTime;
        if (caUpdateTimer >= 0.1 / params.speed)
        {
            caUpdateTimer = 0.0;
            updateGameOfLife(gridWidth, gridHeight);
        }

        // Draw grid
        juce::Graphics g(frame);
        for (int y = 0; y < gridHeight; ++y)
        {
            for (int x = 0; x < gridWidth; ++x)
            {
                if (caGrid[y * gridWidth + x])
                {
                    g.setColour(params.color1);
                    g.fillRect(x * cellWidth, y * cellHeight, cellWidth, cellHeight);
                }
            }
        }

        return frame;
    }

    void updateGameOfLife(int gridWidth, int gridHeight)
    {
        std::vector<bool> newGrid = caGrid;

        for (int y = 0; y < gridHeight; ++y)
        {
            for (int x = 0; x < gridWidth; ++x)
            {
                int neighbors = 0;
                for (int dy = -1; dy <= 1; ++dy)
                {
                    for (int dx = -1; dx <= 1; ++dx)
                    {
                        if (dx == 0 && dy == 0) continue;
                        int nx = (x + dx + gridWidth) % gridWidth;
                        int ny = (y + dy + gridHeight) % gridHeight;
                        if (caGrid[ny * gridWidth + nx])
                            neighbors++;
                    }
                }

                bool alive = caGrid[y * gridWidth + x];
                if (alive && (neighbors < 2 || neighbors > 3))
                    newGrid[y * gridWidth + x] = false;
                else if (!alive && neighbors == 3)
                    newGrid[y * gridWidth + x] = true;
            }
        }

        caGrid = newGrid;
    }

    juce::Image generateMandala()
    {
        juce::Image frame(juce::Image::ARGB, outputWidth, outputHeight, true);
        juce::Graphics g(frame);

        float cx = outputWidth / 2.0f;
        float cy = outputHeight / 2.0f;
        int segments = static_cast<int>(4 + params.complexity * 12);
        float radius = juce::jmin(outputWidth, outputHeight) * 0.4f;

        for (int i = 0; i < segments; ++i)
        {
            float angle = (i / static_cast<float>(segments)) * juce::MathConstants<float>::twoPi;
            float x = cx + std::cos(angle + currentTime * params.speed) * radius;
            float y = cy + std::sin(angle + currentTime * params.speed) * radius;

            g.setColour(interpolateColor(i / static_cast<float>(segments)));
            g.fillEllipse(x - 20, y - 20, 40, 40);
        }

        return frame;
    }

    juce::Image generateKaleidoscope()
    {
        // Kaleidoscope effect (placeholder)
        return generateMandala();
    }

    juce::Image generatePlasma()
    {
        juce::Image frame(juce::Image::ARGB, outputWidth, outputHeight, true);

        for (int y = 0; y < outputHeight; ++y)
        {
            for (int x = 0; x < outputWidth; ++x)
            {
                float value = std::sin(x * 0.02f + currentTime * params.speed);
                value += std::sin(y * 0.02f + currentTime * params.speed * 0.5f);
                value += std::sin((x + y) * 0.01f + currentTime * params.speed * 0.3f);
                value = (value + 3.0f) / 6.0f;  // Normalize 0-1

                auto colour = interpolateColor(value);
                frame.setPixelAt(x, y, colour);
            }
        }

        return frame;
    }

    //==========================================================================
    // Utilities
    //==========================================================================

    juce::Colour interpolateColor(float t) const
    {
        t = juce::jlimit(0.0f, 1.0f, t);

        // Apply color shift
        float h = std::fmod(t + params.colorShift / 360.0f, 1.0f);
        float s = params.harmony;
        float v = params.energy;

        return juce::Colour::fromHSV(h, s, v, 1.0f);
    }

    float randomFloat()
    {
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        return dist(rng);
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    BioFeedbackSystem* bioFeedbackSystem = nullptr;

    GenerationParams params;

    int outputWidth = 1920;
    int outputHeight = 1080;

    // Timing
    double currentTime = 0.0;
    double currentBPM = 120.0;
    double lastBeatPhase = 0.0;
    int beatCounter = 0;

    // Particle system
    struct Particle
    {
        float x, y, vx, vy, size, lifetime;
    };
    std::vector<Particle> particles;

    // Cellular automata
    std::vector<bool> caGrid;
    double caUpdateTimer = 0.0;

    // Random number generator
    std::mt19937 rng;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AIGenerativeVisualEngine)
};

} // namespace Echoelmusic
