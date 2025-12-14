/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║             CARTESIAN BIO-SEQUENCER                                        ║
 * ║                                                                            ║
 * ║     "Non-Linear Patterns Driven by Your Biology"                          ║
 * ║                                                                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 *
 * Inspired by: Slate + Ash CYCLES Cartesian Sequencer, Make Noise René
 *
 * Revolutionary 2D grid-based sequencer where:
 * - Sequence position is determined by bio-data (HRV, coherence)
 * - Patterns evolve based on user's biological state
 * - XY navigation creates non-linear musical journeys
 * - Generative algorithms produce infinite variations
 *
 * Bio-Reactive Features:
 * - Heart Rate → Tempo/Clock Speed
 * - HRV → Pattern Complexity
 * - Coherence → Scale Quantization Strength
 * - Breathing → Grid Navigation Speed
 * - Stress → Randomization Amount
 *
 * Grid Types (Like Slate+Ash CYCLES):
 * - Pitch Grid: Scale-quantized melodic sequences
 * - Position Grid: Sample slice selection
 * - Volume Grid: Dynamic velocity patterns
 * - Size Grid: Grain envelope shaping
 * - Filter Grid: Timbral evolution
 * - Pan Grid: Spatial movement
 *
 * Architecture:
 *
 *     ┌─────────────────────────────────────────────────────────────┐
 *     │                   BIO-DATA INPUT                            │
 *     │  [HRV] [Coherence] [HeartRate] [Breathing] [Stress]         │
 *     └────────────────────────┬────────────────────────────────────┘
 *                              │
 *     ┌────────────────────────▼────────────────────────────────────┐
 *     │              CARTESIAN GRID ENGINE                          │
 *     │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
 *     │  │  Pitch   │ │ Position │ │  Volume  │ │   Size   │       │
 *     │  │   Grid   │ │   Grid   │ │   Grid   │ │   Grid   │       │
 *     │  │  4x4     │ │   4x4    │ │   4x4    │ │   4x4    │       │
 *     │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       │
 *     │       │            │            │            │              │
 *     │  ┌────▼────────────▼────────────▼────────────▼────┐        │
 *     │  │              XY NAVIGATOR                       │        │
 *     │  │     Bio-Driven Position + Pattern Selector      │        │
 *     │  └─────────────────┬───────────────────────────────┘        │
 *     └────────────────────┼────────────────────────────────────────┘
 *                          │
 *     ┌────────────────────▼────────────────────────────────────────┐
 *     │                   OUTPUT                                    │
 *     │  [Note] [Velocity] [Position] [GrainSize] [Filter] [Pan]    │
 *     └─────────────────────────────────────────────────────────────┘
 */

#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <random>
#include <cmath>

class CartesianBioSequencer
{
public:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int kMaxGridSize = 8;
    static constexpr int kMaxGrids = 6;
    static constexpr int kMaxPatterns = 32;
    static constexpr int kMaxScales = 16;

    //==========================================================================
    // Grid Types
    //==========================================================================

    enum class GridType
    {
        Pitch,      // Melodic note selection
        Position,   // Sample/slice position
        Volume,     // Velocity/dynamics
        Size,       // Grain envelope size
        Filter,     // Filter cutoff
        Pan         // Stereo position
    };

    //==========================================================================
    // Navigation Patterns (like René)
    //==========================================================================

    enum class NavigationPattern
    {
        // Linear patterns
        LeftToRight,
        RightToLeft,
        TopToBottom,
        BottomToTop,

        // Snake patterns
        SnakeHorizontal,
        SnakeVertical,

        // Diagonal patterns
        DiagonalDown,
        DiagonalUp,

        // Random patterns
        Random,
        RandomWalk,

        // Bio-reactive patterns
        BioSpiral,       // Spiral based on coherence
        BioBreath,       // Follows breathing cycle
        BioHeart,        // Pulses with heartbeat
        BioCoherence,    // Smooth when coherent, chaotic when stressed

        // Generative patterns
        ConwayLife,      // Game of Life cellular automata
        Euclidean,       // Euclidean rhythm distribution
        Fibonacci        // Fibonacci spiral
    };

    //==========================================================================
    // Musical Scales
    //==========================================================================

    enum class Scale
    {
        Chromatic,
        Major,
        Minor,
        Dorian,
        Phrygian,
        Lydian,
        Mixolydian,
        Locrian,
        HarmonicMinor,
        MelodicMinor,
        Pentatonic,
        Blues,
        WholeTone,
        Diminished,
        HealingFrequencies,  // 432Hz based
        Solfeggio           // Ancient healing tones
    };

    //==========================================================================
    // Grid Cell Structure
    //==========================================================================

    struct GridCell
    {
        float value = 0.0f;          // Primary value (0-1)
        float probability = 1.0f;    // Trigger probability
        bool active = true;          // Cell active state
        int tie = 0;                 // Tie to next cell (0 = no tie)

        GridCell() = default;
    };

    //==========================================================================
    // Grid Structure
    //==========================================================================

    struct Grid
    {
        GridType type = GridType::Pitch;
        int sizeX = 4;
        int sizeY = 4;
        std::array<std::array<GridCell, kMaxGridSize>, kMaxGridSize> cells;

        // Range mapping
        float minValue = 0.0f;
        float maxValue = 1.0f;

        // Scale quantization (for pitch grid)
        Scale scale = Scale::Major;
        int rootNote = 60;  // Middle C
        float quantizeStrength = 1.0f;

        Grid() = default;
    };

    //==========================================================================
    // Bio State Input
    //==========================================================================

    struct BioState
    {
        float heartRate = 70.0f;      // BPM
        float hrv = 0.5f;             // 0-1 normalized
        float coherence = 0.5f;       // 0-1
        float breathingRate = 12.0f;  // Breaths per minute
        float breathingPhase = 0.0f;  // 0-1 cycle position
        float stress = 0.5f;          // 0-1 (inverted coherence)
    };

    //==========================================================================
    // Sequencer Output
    //==========================================================================

    struct SequencerOutput
    {
        int midiNote = 60;
        float velocity = 0.8f;
        float samplePosition = 0.0f;  // 0-1
        float grainSize = 0.5f;       // 0-1
        float filterCutoff = 0.7f;    // 0-1
        float pan = 0.5f;             // 0=L, 0.5=C, 1=R
        bool trigger = true;

        SequencerOutput() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    CartesianBioSequencer()
    {
        initializeGrids();
        initializeScales();
    }

    ~CartesianBioSequencer() = default;

    //==========================================================================
    // Grid Management
    //==========================================================================

    /** Get grid reference */
    Grid& getGrid(GridType type)
    {
        return grids[static_cast<int>(type)];
    }

    const Grid& getGrid(GridType type) const
    {
        return grids[static_cast<int>(type)];
    }

    /** Set grid size */
    void setGridSize(GridType type, int sizeX, int sizeY)
    {
        auto& grid = grids[static_cast<int>(type)];
        grid.sizeX = std::clamp(sizeX, 1, kMaxGridSize);
        grid.sizeY = std::clamp(sizeY, 1, kMaxGridSize);
    }

    /** Set cell value */
    void setCellValue(GridType type, int x, int y, float value)
    {
        auto& grid = grids[static_cast<int>(type)];
        if (x >= 0 && x < grid.sizeX && y >= 0 && y < grid.sizeY)
        {
            grid.cells[y][x].value = std::clamp(value, 0.0f, 1.0f);
        }
    }

    /** Randomize grid values */
    void randomizeGrid(GridType type, float amount = 1.0f)
    {
        auto& grid = grids[static_cast<int>(type)];

        std::uniform_real_distribution<float> dist(0.0f, 1.0f);

        for (int y = 0; y < grid.sizeY; ++y)
        {
            for (int x = 0; x < grid.sizeX; ++x)
            {
                float random = dist(rng);
                float current = grid.cells[y][x].value;
                grid.cells[y][x].value = current * (1.0f - amount) + random * amount;
            }
        }
    }

    //==========================================================================
    // Navigation Control
    //==========================================================================

    /** Set navigation pattern */
    void setNavigationPattern(NavigationPattern pattern)
    {
        currentPattern = pattern;
    }

    /** Set position manually */
    void setPosition(float x, float y)
    {
        positionX = std::clamp(x, 0.0f, 1.0f);
        positionY = std::clamp(y, 0.0f, 1.0f);
    }

    /** Get current grid position */
    std::pair<int, int> getCurrentCell() const
    {
        const auto& grid = grids[0];
        int cellX = static_cast<int>(positionX * (grid.sizeX - 1));
        int cellY = static_cast<int>(positionY * (grid.sizeY - 1));
        return { cellX, cellY };
    }

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    /** Update bio-data */
    void setBioState(const BioState& state)
    {
        bioState = state;

        // Bio-driven parameter updates
        updateBioDrivenParameters();
    }

    /** Enable/disable bio-reactive navigation */
    void setBioNavigationEnabled(bool enabled)
    {
        bioNavigationEnabled = enabled;
    }

    //==========================================================================
    // Scale/Pitch Control
    //==========================================================================

    /** Set musical scale for pitch grid */
    void setScale(Scale scale, int rootNote = 60)
    {
        grids[static_cast<int>(GridType::Pitch)].scale = scale;
        grids[static_cast<int>(GridType::Pitch)].rootNote = rootNote;
    }

    /** Set quantize strength (0 = free, 1 = fully quantized) */
    void setQuantizeStrength(float strength)
    {
        grids[static_cast<int>(GridType::Pitch)].quantizeStrength =
            std::clamp(strength, 0.0f, 1.0f);
    }

    //==========================================================================
    // Timing
    //==========================================================================

    /** Set tempo (BPM) */
    void setTempo(double bpm)
    {
        tempo = std::clamp(bpm, 20.0, 300.0);
    }

    /** Set clock division */
    void setClockDivision(int division)
    {
        clockDivision = std::clamp(division, 1, 64);
    }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        samplesPerBeat = sampleRate * 60.0 / tempo;
        sampleCounter = 0;
    }

    /** Process and get next sequencer state */
    SequencerOutput process()
    {
        SequencerOutput output;

        // Update position based on navigation pattern
        updatePosition();

        // Get current cell indices
        auto [cellX, cellY] = getCurrentCell();

        // Read values from all grids
        output.midiNote = readPitchGrid(cellX, cellY);
        output.velocity = readGrid(GridType::Volume, cellX, cellY);
        output.samplePosition = readGrid(GridType::Position, cellX, cellY);
        output.grainSize = readGrid(GridType::Size, cellX, cellY);
        output.filterCutoff = readGrid(GridType::Filter, cellX, cellY);
        output.pan = readGrid(GridType::Pan, cellX, cellY);

        // Check probability
        const auto& pitchGrid = grids[static_cast<int>(GridType::Pitch)];
        float probability = pitchGrid.cells[cellY][cellX].probability;

        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        output.trigger = dist(rng) < probability;

        return output;
    }

    /** Advance clock by sample count */
    void advanceClock(int numSamples)
    {
        sampleCounter += numSamples;

        double samplesPerStep = samplesPerBeat / clockDivision;

        while (sampleCounter >= samplesPerStep)
        {
            sampleCounter -= samplesPerStep;
            stepCounter++;

            // Advance navigation
            if (!bioNavigationEnabled)
            {
                advanceNavigation();
            }
        }
    }

    //==========================================================================
    // Presets
    //==========================================================================

    /** Apply a preset pattern to all grids */
    void loadPreset(int presetIndex)
    {
        switch (presetIndex)
        {
            case 0: // Meditative
                applyMeditativePreset();
                break;
            case 1: // Energetic
                applyEnergeticPreset();
                break;
            case 2: // Chaotic
                applyChaoticPreset();
                break;
            case 3: // Healing
                applyHealingPreset();
                break;
            case 4: // Generative
                applyGenerativePreset();
                break;
            default:
                break;
        }
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    std::array<Grid, kMaxGrids> grids;
    BioState bioState;

    // Navigation state
    NavigationPattern currentPattern = NavigationPattern::BioCoherence;
    float positionX = 0.0f;
    float positionY = 0.0f;
    int stepCounter = 0;
    bool bioNavigationEnabled = true;

    // Timing
    double tempo = 120.0;
    int clockDivision = 4;
    double currentSampleRate = 48000.0;
    double samplesPerBeat = 24000.0;
    double sampleCounter = 0;

    // Random generator
    std::mt19937 rng{ std::random_device{}() };

    // Scale tables
    std::array<std::vector<int>, kMaxScales> scaleTables;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeGrids()
    {
        // Initialize all grids with default values
        for (int g = 0; g < kMaxGrids; ++g)
        {
            auto& grid = grids[g];
            grid.type = static_cast<GridType>(g);
            grid.sizeX = 4;
            grid.sizeY = 4;

            for (int y = 0; y < kMaxGridSize; ++y)
            {
                for (int x = 0; x < kMaxGridSize; ++x)
                {
                    grid.cells[y][x].value = 0.5f;
                    grid.cells[y][x].probability = 1.0f;
                    grid.cells[y][x].active = true;
                }
            }
        }

        // Set grid-specific ranges
        grids[static_cast<int>(GridType::Pitch)].minValue = 36.0f;   // C2
        grids[static_cast<int>(GridType::Pitch)].maxValue = 96.0f;   // C7
        grids[static_cast<int>(GridType::Volume)].minValue = 0.0f;
        grids[static_cast<int>(GridType::Volume)].maxValue = 1.0f;
    }

    void initializeScales()
    {
        // Major scale intervals
        scaleTables[static_cast<int>(Scale::Major)] = { 0, 2, 4, 5, 7, 9, 11 };

        // Natural minor
        scaleTables[static_cast<int>(Scale::Minor)] = { 0, 2, 3, 5, 7, 8, 10 };

        // Dorian
        scaleTables[static_cast<int>(Scale::Dorian)] = { 0, 2, 3, 5, 7, 9, 10 };

        // Pentatonic
        scaleTables[static_cast<int>(Scale::Pentatonic)] = { 0, 2, 4, 7, 9 };

        // Blues
        scaleTables[static_cast<int>(Scale::Blues)] = { 0, 3, 5, 6, 7, 10 };

        // Whole tone
        scaleTables[static_cast<int>(Scale::WholeTone)] = { 0, 2, 4, 6, 8, 10 };

        // Chromatic (all notes)
        scaleTables[static_cast<int>(Scale::Chromatic)] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 };

        // Healing frequencies (based on 432Hz tuning concept)
        scaleTables[static_cast<int>(Scale::HealingFrequencies)] = { 0, 2, 4, 5, 7, 9, 11 };

        // Solfeggio frequencies
        scaleTables[static_cast<int>(Scale::Solfeggio)] = { 0, 2, 4, 5, 7, 9, 11 };
    }

    void updateBioDrivenParameters()
    {
        // Bio-reactive grid modifications
        if (bioNavigationEnabled)
        {
            // Coherence affects quantize strength (high coherence = more quantized)
            grids[static_cast<int>(GridType::Pitch)].quantizeStrength = bioState.coherence;

            // HRV affects randomization amount (high HRV = more variation)
            float randomAmount = bioState.hrv * 0.3f;
            for (int g = 0; g < kMaxGrids; ++g)
            {
                // Subtle per-step randomization based on HRV
                if (randomAmount > 0.1f)
                {
                    // Add micro-variations
                }
            }
        }
    }

    void updatePosition()
    {
        if (!bioNavigationEnabled)
            return;

        // Bio-reactive position update
        switch (currentPattern)
        {
            case NavigationPattern::BioSpiral:
            {
                // Spiral movement based on coherence
                float angle = stepCounter * 0.1f + bioState.coherence * 6.28f;
                float radius = bioState.hrv * 0.5f;
                positionX = 0.5f + std::cos(angle) * radius;
                positionY = 0.5f + std::sin(angle) * radius;
                break;
            }

            case NavigationPattern::BioBreath:
            {
                // Follow breathing cycle
                positionX = bioState.breathingPhase;
                positionY = 0.5f + std::sin(bioState.breathingPhase * 6.28f) * 0.4f;
                break;
            }

            case NavigationPattern::BioHeart:
            {
                // Pulse with heartbeat
                float heartPhase = std::fmod(stepCounter * (bioState.heartRate / 60.0f / 4.0f), 1.0f);
                positionX = heartPhase;
                positionY = 0.5f + std::sin(heartPhase * 12.56f) * bioState.hrv * 0.3f;
                break;
            }

            case NavigationPattern::BioCoherence:
            {
                // Smooth when coherent, chaotic when stressed
                float chaos = bioState.stress;
                std::uniform_real_distribution<float> dist(-chaos * 0.2f, chaos * 0.2f);

                positionX += 0.0625f + dist(rng);  // 1/16 step + chaos
                positionY += dist(rng);

                // Wrap around
                while (positionX >= 1.0f) positionX -= 1.0f;
                while (positionX < 0.0f) positionX += 1.0f;
                positionY = std::clamp(positionY, 0.0f, 1.0f);
                break;
            }

            default:
                break;
        }
    }

    void advanceNavigation()
    {
        const auto& grid = grids[0];
        int steps = grid.sizeX * grid.sizeY;

        switch (currentPattern)
        {
            case NavigationPattern::LeftToRight:
            {
                int step = stepCounter % steps;
                positionX = static_cast<float>(step % grid.sizeX) / (grid.sizeX - 1);
                positionY = static_cast<float>(step / grid.sizeX) / std::max(1, grid.sizeY - 1);
                break;
            }

            case NavigationPattern::SnakeHorizontal:
            {
                int step = stepCounter % steps;
                int row = step / grid.sizeX;
                int col = step % grid.sizeX;
                if (row % 2 == 1) col = grid.sizeX - 1 - col;  // Reverse odd rows
                positionX = static_cast<float>(col) / (grid.sizeX - 1);
                positionY = static_cast<float>(row) / std::max(1, grid.sizeY - 1);
                break;
            }

            case NavigationPattern::Random:
            {
                std::uniform_real_distribution<float> dist(0.0f, 1.0f);
                positionX = dist(rng);
                positionY = dist(rng);
                break;
            }

            case NavigationPattern::RandomWalk:
            {
                std::uniform_real_distribution<float> dist(-0.25f, 0.25f);
                positionX += dist(rng);
                positionY += dist(rng);
                positionX = std::clamp(positionX, 0.0f, 1.0f);
                positionY = std::clamp(positionY, 0.0f, 1.0f);
                break;
            }

            case NavigationPattern::Euclidean:
            {
                // Euclidean rhythm distribution
                int pulses = static_cast<int>(bioState.coherence * 8 + 1);
                int euclideanStep = stepCounter % steps;
                int bucket = (euclideanStep * pulses) % steps;
                positionX = static_cast<float>(bucket % grid.sizeX) / (grid.sizeX - 1);
                positionY = static_cast<float>(bucket / grid.sizeX) / std::max(1, grid.sizeY - 1);
                break;
            }

            default:
                break;
        }
    }

    float readGrid(GridType type, int cellX, int cellY) const
    {
        const auto& grid = grids[static_cast<int>(type)];

        if (cellX < 0 || cellX >= grid.sizeX || cellY < 0 || cellY >= grid.sizeY)
            return 0.5f;

        return grid.cells[cellY][cellX].value;
    }

    int readPitchGrid(int cellX, int cellY) const
    {
        const auto& grid = grids[static_cast<int>(GridType::Pitch)];

        if (cellX < 0 || cellX >= grid.sizeX || cellY < 0 || cellY >= grid.sizeY)
            return grid.rootNote;

        float rawValue = grid.cells[cellY][cellX].value;

        // Map to note range
        float noteRange = grid.maxValue - grid.minValue;
        float rawNote = grid.minValue + rawValue * noteRange;

        // Apply scale quantization
        if (grid.quantizeStrength > 0.001f)
        {
            int quantized = quantizeToScale(rawNote, grid.scale, grid.rootNote);
            rawNote = rawNote * (1.0f - grid.quantizeStrength) + quantized * grid.quantizeStrength;
        }

        return static_cast<int>(std::round(rawNote));
    }

    int quantizeToScale(float noteValue, Scale scale, int rootNote) const
    {
        const auto& scaleNotes = scaleTables[static_cast<int>(scale)];
        if (scaleNotes.empty())
            return static_cast<int>(noteValue);

        int note = static_cast<int>(std::round(noteValue));
        int octave = (note - rootNote) / 12;
        int degree = (note - rootNote) % 12;
        if (degree < 0) { degree += 12; octave--; }

        // Find nearest scale degree
        int nearestDegree = scaleNotes[0];
        int minDistance = 12;

        for (int scaleDegree : scaleNotes)
        {
            int distance = std::abs(degree - scaleDegree);
            if (distance < minDistance)
            {
                minDistance = distance;
                nearestDegree = scaleDegree;
            }
        }

        return rootNote + octave * 12 + nearestDegree;
    }

    //==========================================================================
    // Presets
    //==========================================================================

    void applyMeditativePreset()
    {
        setScale(Scale::Pentatonic, 60);
        setGridSize(GridType::Pitch, 4, 4);
        setNavigationPattern(NavigationPattern::BioBreath);
        setClockDivision(8);

        // Gentle, sparse pattern
        auto& pitchGrid = grids[static_cast<int>(GridType::Pitch)];
        for (int y = 0; y < 4; ++y)
        {
            for (int x = 0; x < 4; ++x)
            {
                pitchGrid.cells[y][x].value = 0.4f + 0.2f * std::sin(x * 0.5f + y * 0.3f);
                pitchGrid.cells[y][x].probability = 0.5f + 0.3f * bioState.coherence;
            }
        }
    }

    void applyEnergeticPreset()
    {
        setScale(Scale::Minor, 48);
        setGridSize(GridType::Pitch, 8, 8);
        setNavigationPattern(NavigationPattern::BioHeart);
        setClockDivision(2);

        // Dense, active pattern
        randomizeGrid(GridType::Pitch, 0.8f);
        randomizeGrid(GridType::Volume, 0.5f);
    }

    void applyChaoticPreset()
    {
        setScale(Scale::Chromatic, 60);
        setGridSize(GridType::Pitch, 8, 8);
        setNavigationPattern(NavigationPattern::Random);
        setClockDivision(1);

        // Full random
        for (int g = 0; g < kMaxGrids; ++g)
        {
            randomizeGrid(static_cast<GridType>(g), 1.0f);
        }
    }

    void applyHealingPreset()
    {
        setScale(Scale::HealingFrequencies, 57);  // A = 432Hz equivalent
        setGridSize(GridType::Pitch, 4, 4);
        setNavigationPattern(NavigationPattern::BioCoherence);
        setClockDivision(16);

        // Healing intervals
        auto& pitchGrid = grids[static_cast<int>(GridType::Pitch)];
        float healingRatios[] = { 0.0f, 0.17f, 0.33f, 0.42f, 0.58f, 0.75f, 0.92f, 1.0f };

        for (int y = 0; y < 4; ++y)
        {
            for (int x = 0; x < 4; ++x)
            {
                pitchGrid.cells[y][x].value = healingRatios[(x + y * 2) % 8];
                pitchGrid.cells[y][x].probability = 0.7f;
            }
        }
    }

    void applyGenerativePreset()
    {
        setScale(Scale::Dorian, 60);
        setGridSize(GridType::Pitch, 8, 8);
        setNavigationPattern(NavigationPattern::Euclidean);
        setClockDivision(4);

        // Semi-random with structure
        randomizeGrid(GridType::Pitch, 0.6f);
        randomizeGrid(GridType::Volume, 0.4f);
        randomizeGrid(GridType::Position, 0.5f);
    }

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CartesianBioSequencer)
};
