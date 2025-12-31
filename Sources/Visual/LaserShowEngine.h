#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>
#include <map>
#include <functional>

/**
 * LaserShowEngine - Professional Laser Show System
 *
 * Inspired by: Pangolin Beyond Ultimate, LaserWorld Showcontroller,
 *              Phoenix Pro, Quickshow, LASERWORLD
 *
 * Features:
 * - ILDA frame sequences with interpolation
 * - Advanced timeline with cues and triggers
 * - Effect stacks (morphing, distortion, color cycling)
 * - Zone/projector management with geometric correction
 * - ArtNet/sACN DMX output
 * - SMPTE/MTC timecode sync
 * - Beam optimization (path planning, blanking)
 * - QuickDraw vector editor integration
 * - Abstract generator (procedural effects)
 * - Multi-zone atmospheric effects
 */
namespace Echoel::Visual
{

//==============================================================================
// ILDA Frame Format
//==============================================================================

struct ILDAPoint
{
    int16_t x = 0;                   // -32768 to +32767
    int16_t y = 0;
    int16_t z = 0;                   // For 3D projection (usually 0)
    uint8_t r = 255, g = 255, b = 255;
    uint8_t status = 0;              // Bit 6 = blanking

    bool isBlanked() const { return (status & 0x40) != 0; }
    void setBlanked(bool blanked) { status = blanked ? (status | 0x40) : (status & ~0x40); }

    juce::Colour getColour() const { return juce::Colour(r, g, b); }
    void setColour(juce::Colour c) { r = c.getRed(); g = c.getGreen(); b = c.getBlue(); }

    juce::Point<float> getNormalizedXY() const
    {
        return { x / 32767.0f, y / 32767.0f };
    }

    void setNormalizedXY(float nx, float ny)
    {
        x = static_cast<int16_t>(juce::jlimit(-32768.0f, 32767.0f, nx * 32767.0f));
        y = static_cast<int16_t>(juce::jlimit(-32768.0f, 32767.0f, ny * 32767.0f));
    }
};

struct ILDAFrame
{
    juce::String name;
    std::vector<ILDAPoint> points;
    double duration = 1.0 / 30.0;    // Frame duration in seconds (30fps default)
    int pointsPerSecond = 30000;     // Scan rate

    // Metrics
    int getPointCount() const { return static_cast<int>(points.size()); }
    float getDutyCycle() const;       // Ratio of lit points
    float getPathLength() const;      // Total distance traveled
};

struct ILDASequence
{
    juce::String name;
    std::vector<ILDAFrame> frames;
    bool loop = true;
    double frameRate = 30.0;

    // Playback
    int currentFrame = 0;
    double frameProgress = 0.0;

    // Import/Export
    static ILDASequence loadFromFile(const juce::File& file);
    void saveToFile(const juce::File& file) const;
    static ILDASequence loadFromILDFormat(const juce::MemoryBlock& data);
    juce::MemoryBlock exportToILDFormat() const;
};

//==============================================================================
// Effect Types
//==============================================================================

enum class LaserEffectType
{
    // Transform
    Translate,
    Scale,
    Rotate,
    Shear,
    Perspective,

    // Distortion
    Wave,
    Spiral,
    Pinch,
    Bulge,
    Twirl,
    Ripple,

    // Color
    ColorCycle,
    ColorGradient,
    ColorPulse,
    Strobe,
    FadeIn,
    FadeOut,

    // Beam
    BeamBrush,        // Variable line width simulation
    Afterglow,        // Trail effect
    Starburst,        // Radial explosion
    Scanner,          // Scanner simulation

    // Abstract
    Kaleidoscope,     // Mirror reflections
    Tile,             // Repeating pattern
    Feedback,         // Frame feedback
    Morph             // Blend between frames
};

struct LaserEffect
{
    LaserEffectType type = LaserEffectType::Translate;
    bool enabled = true;

    // Common parameters
    float amount = 1.0f;           // Effect intensity (0-1)
    float speed = 1.0f;            // Animation speed
    float phase = 0.0f;            // Phase offset

    // Transform parameters
    float translateX = 0.0f, translateY = 0.0f;
    float scaleX = 1.0f, scaleY = 1.0f;
    float rotation = 0.0f;         // Radians

    // Distortion parameters
    float frequency = 1.0f;
    float amplitude = 0.1f;
    juce::Point<float> center {0.0f, 0.0f};

    // Color parameters
    float colorPhase = 0.0f;
    std::array<juce::Colour, 4> colorStops {{
        juce::Colours::red,
        juce::Colours::green,
        juce::Colours::blue,
        juce::Colours::cyan
    }};

    // Modulation sources
    enum class ModSource { None, LFO, Audio, Bio, Envelope };
    ModSource modSource = ModSource::None;
    float modAmount = 0.0f;
};

class EffectStack
{
public:
    void addEffect(const LaserEffect& effect);
    void removeEffect(int index);
    void moveEffect(int fromIndex, int toIndex);
    void clearEffects();

    LaserEffect& getEffect(int index) { return effects[index]; }
    int getNumEffects() const { return static_cast<int>(effects.size()); }

    /** Apply all effects to frame */
    void process(ILDAFrame& frame, double time);

    /** Set bypass */
    void setBypass(bool bypassed) { bypass = bypassed; }

private:
    std::vector<LaserEffect> effects;
    bool bypass = false;

    void applyEffect(ILDAFrame& frame, const LaserEffect& effect, double time);
};

//==============================================================================
// Abstract Generator (Procedural Patterns)
//==============================================================================

class AbstractGenerator
{
public:
    enum class Pattern
    {
        // Classic
        Circle,
        Spiral,
        Lissajous,
        Oscilloscope,
        Grid,

        // Complex
        Hypocycloid,        // Spirograph patterns
        Rose,               // Rhodonea curves
        Harmonograph,       // Pendulum simulation
        Superformula,       // Generalized superellipse
        Clifford,           // Clifford attractor
        DeJong,             // De Jong attractor

        // 3D Projection
        WireframeCube,
        WireframeSphere,
        Torus,
        Mobius,

        // Audio-reactive
        AudioScope,
        AudioSpectrum,
        AudioParticles
    };

    AbstractGenerator();

    void setPattern(Pattern pattern) { currentPattern = pattern; }
    void setComplexity(float complexity) { this->complexity = complexity; }
    void setSymmetry(int symmetry) { this->symmetry = symmetry; }
    void setSpeed(float speed) { this->speed = speed; }

    /** Set Lissajous parameters */
    void setLissajousRatio(float a, float b, float delta = 0.0f);

    /** Set Harmonograph parameters */
    void setHarmonograph(float a1, float a2, float f1, float f2,
                          float p1, float p2, float d1, float d2);

    /** Set attractor parameters */
    void setAttractorParams(float a, float b, float c, float d);

    /** Generate frame at given time */
    ILDAFrame generate(double time, int numPoints = 500);

    /** Update with audio data */
    void setAudioSpectrum(const std::vector<float>& spectrum);
    void setAudioWaveform(const std::vector<float>& waveform);

private:
    Pattern currentPattern = Pattern::Circle;
    float complexity = 0.5f;
    int symmetry = 1;
    float speed = 1.0f;

    // Lissajous
    float lissA = 3.0f, lissB = 4.0f, lissDelta = 0.5f;

    // Harmonograph
    struct HarmonoParams { float a, f, p, d; };
    std::array<HarmonoParams, 4> harmonoParams;

    // Attractor
    float attractorA = -1.4f, attractorB = 1.6f;
    float attractorC = 1.0f, attractorD = 0.7f;

    // Audio
    std::vector<float> audioSpectrum;
    std::vector<float> audioWaveform;

    ILDAFrame generateLissajous(double time, int numPoints);
    ILDAFrame generateHarmonograph(double time, int numPoints);
    ILDAFrame generateAttractor(double time, int numPoints, bool clifford);
    ILDAFrame generateSuperformula(double time, int numPoints);
    ILDAFrame generateAudioScope(int numPoints);
    ILDAFrame generateAudioSpectrum(int numPoints);
};

//==============================================================================
// Beam Optimizer (Path Planning)
//==============================================================================

class BeamOptimizer
{
public:
    struct OptimizationSettings
    {
        // Blanking optimization
        int blankingDwell = 8;           // Extra points at blank transitions
        bool minimizeBlankingDistance = true;

        // Point reduction
        float angleTolerance = 0.02f;    // Radians - points on lines can be removed
        int maxPoints = 30000;           // Maximum points per frame
        float minPointDistance = 0.001f; // Normalized distance

        // Corner emphasis
        int cornerDwell = 4;             // Extra points at corners
        float cornerThreshold = 0.3f;    // Angle threshold for corner detection

        // Path optimization
        bool reorderForMinDistance = true;  // TSP-style path optimization
        bool closePaths = true;             // Connect end to start

        // Safety
        float maxBeamSpeed = 1.0f;       // Normalized units per sample
    };

    BeamOptimizer();

    void setSettings(const OptimizationSettings& settings) { this->settings = settings; }

    /** Optimize frame for better scan quality */
    ILDAFrame optimize(const ILDAFrame& input);

    /** Merge multiple frames into one */
    ILDAFrame mergeFrames(const std::vector<ILDAFrame>& frames);

    /** Add blanking points between segments */
    void addBlankingDwell(std::vector<ILDAPoint>& points);

    /** Optimize path order (traveling salesman) */
    std::vector<int> optimizePathOrder(const std::vector<std::vector<ILDAPoint>>& segments);

private:
    OptimizationSettings settings;

    // Point reduction
    std::vector<ILDAPoint> reducePoints(const std::vector<ILDAPoint>& points);

    // Corner detection
    std::vector<int> findCorners(const std::vector<ILDAPoint>& points);
    void addCornerDwell(std::vector<ILDAPoint>& points, const std::vector<int>& corners);

    // Path distance
    float calculatePathLength(const std::vector<ILDAPoint>& points);
    float pointDistance(const ILDAPoint& a, const ILDAPoint& b);
};

//==============================================================================
// Zone Configuration (Multi-Projector)
//==============================================================================

struct LaserZone
{
    juce::String name = "Zone";
    int id = 0;

    // Output assignment
    int outputIndex = 0;              // Which projector
    juce::Rectangle<float> region {0.0f, 0.0f, 1.0f, 1.0f};  // Normalized bounds

    // Geometric correction
    struct GeometricCorrection
    {
        // Four-corner keystoning
        std::array<juce::Point<float>, 4> corners {{
            {0.0f, 0.0f}, {1.0f, 0.0f}, {1.0f, 1.0f}, {0.0f, 1.0f}
        }};

        // Fine tuning
        float xOffset = 0.0f, yOffset = 0.0f;
        float xScale = 1.0f, yScale = 1.0f;
        float rotation = 0.0f;
        float xShear = 0.0f, yShear = 0.0f;

        // Grid warp (for curved surfaces)
        int gridResolution = 4;
        std::vector<juce::Point<float>> gridPoints;
    } correction;

    // Color correction
    float redGain = 1.0f, greenGain = 1.0f, blueGain = 1.0f;
    float brightness = 1.0f;

    // Blanking settings
    float blankingLevel = 0.0f;       // Color when blanked

    // Safety
    bool enabled = true;
    float maxIntensity = 1.0f;

    /** Transform point through zone correction */
    ILDAPoint transformPoint(const ILDAPoint& input) const;
};

class ZoneManager
{
public:
    int addZone(const LaserZone& zone);
    void removeZone(int id);
    LaserZone* getZone(int id);
    const std::vector<LaserZone>& getZones() const { return zones; }

    /** Assign content to zone */
    void setZoneContent(int zoneId, const ILDASequence* sequence);
    void setZoneContent(int zoneId, AbstractGenerator* generator);

    /** Render all zones to output frames */
    std::vector<std::pair<int, ILDAFrame>> renderZones(double time);

private:
    std::vector<LaserZone> zones;
    std::map<int, const ILDASequence*> zoneSequences;
    std::map<int, AbstractGenerator*> zoneGenerators;
    int nextZoneId = 1;
};

//==============================================================================
// Timeline & Cue System
//==============================================================================

struct LaserCue
{
    juce::String name;
    double startTime = 0.0;
    double duration = 1.0;
    int zoneId = 0;

    enum class ContentType { Sequence, Generator, Effect, BlackOut };
    ContentType type = ContentType::Sequence;

    // Content reference
    juce::String sequenceName;        // For Sequence type
    AbstractGenerator::Pattern generatorPattern;  // For Generator type
    std::vector<LaserEffect> effects;

    // Fade
    float fadeInTime = 0.0f;
    float fadeOutTime = 0.0f;

    // Loop/trigger
    enum class TriggerMode { Time, Beat, MIDI, External };
    TriggerMode trigger = TriggerMode::Time;
    int midiNote = 60;                // For MIDI trigger
    float beatInterval = 1.0f;        // For Beat trigger

    // Priority (higher = on top)
    int priority = 0;
};

class Timeline
{
public:
    Timeline();

    // Cue management
    int addCue(const LaserCue& cue);
    void removeCue(int cueId);
    LaserCue* getCue(int cueId);
    void clearCues();

    // Playback
    void play();
    void pause();
    void stop();
    void setPosition(double timeSeconds);
    double getPosition() const { return currentTime; }
    bool isPlaying() const { return playing; }

    // Loop
    void setLoopRegion(double start, double end);
    void setLoopEnabled(bool enabled) { loopEnabled = enabled; }

    // Tempo sync
    void setBPM(double bpm) { this->bpm = bpm; }
    void setBeatPosition(double beat);
    double beatToTime(double beat) const { return beat * 60.0 / bpm; }
    double timeToBeat(double time) const { return time * bpm / 60.0; }

    // Timecode
    void setSMPTESync(bool enabled) { smpteSync = enabled; }
    void updateSMPTE(int hours, int minutes, int seconds, int frames, int frameRate);

    // Get active cues at current time
    std::vector<LaserCue*> getActiveCues();

    // Advance timeline
    void advance(double deltaTime);

private:
    std::vector<LaserCue> cues;
    int nextCueId = 1;

    double currentTime = 0.0;
    bool playing = false;

    double bpm = 120.0;
    bool loopEnabled = false;
    double loopStart = 0.0, loopEnd = 0.0;

    bool smpteSync = false;
};

//==============================================================================
// Output Protocols
//==============================================================================

class LaserOutput
{
public:
    virtual ~LaserOutput() = default;

    virtual bool connect() = 0;
    virtual void disconnect() = 0;
    virtual bool isConnected() const = 0;

    virtual void sendFrame(const ILDAFrame& frame) = 0;
    virtual void setEnabled(bool enabled) = 0;

    virtual juce::String getProtocolName() const = 0;
};

class ILDAOutput : public LaserOutput
{
public:
    ILDAOutput();
    ~ILDAOutput() override;

    void setAddress(const juce::String& ip, int port);

    bool connect() override;
    void disconnect() override;
    bool isConnected() const override { return connected; }

    void sendFrame(const ILDAFrame& frame) override;
    void setEnabled(bool enabled) override { this->enabled = enabled; }

    juce::String getProtocolName() const override { return "ILDA/EtherDream"; }

private:
    juce::String ipAddress = "192.168.0.1";
    int port = 7765;
    bool connected = false;
    bool enabled = true;

    std::unique_ptr<juce::DatagramSocket> socket;
};

class ArtNetDMXOutput : public LaserOutput
{
public:
    ArtNetDMXOutput();
    ~ArtNetDMXOutput() override;

    void setAddress(const juce::String& ip, int universe);

    bool connect() override;
    void disconnect() override;
    bool isConnected() const override { return connected; }

    void sendFrame(const ILDAFrame& frame) override;
    void setEnabled(bool enabled) override { this->enabled = enabled; }

    juce::String getProtocolName() const override { return "ArtNet DMX"; }

    /** Set DMX channel mapping */
    void setChannelMapping(int xChannel, int yChannel,
                           int rChannel, int gChannel, int bChannel,
                           int intensityChannel);

private:
    juce::String ipAddress = "255.255.255.255";
    int universe = 0;
    bool connected = false;
    bool enabled = true;

    // Channel mapping
    int xChan = 1, yChan = 2;
    int rChan = 3, gChan = 4, bChan = 5;
    int intensityChan = 6;

    std::unique_ptr<juce::DatagramSocket> socket;
    std::array<uint8_t, 512> dmxBuffer;
};

//==============================================================================
// Main Laser Show Engine
//==============================================================================

class LaserShowEngine
{
public:
    LaserShowEngine();
    ~LaserShowEngine();

    void prepare(double frameRate = 30.0);
    void shutdown();

    //==========================================================================
    // Content Management
    //==========================================================================

    int loadSequence(const juce::File& ildFile);
    int loadSequence(const ILDASequence& sequence);
    ILDASequence* getSequence(int id);
    void removeSequence(int id);

    AbstractGenerator& getGenerator() { return generator; }
    EffectStack& getMasterEffects() { return masterEffects; }

    //==========================================================================
    // Zone Management
    //==========================================================================

    ZoneManager& getZoneManager() { return zoneManager; }

    //==========================================================================
    // Timeline
    //==========================================================================

    Timeline& getTimeline() { return timeline; }

    //==========================================================================
    // Output Management
    //==========================================================================

    int addOutput(std::unique_ptr<LaserOutput> output);
    void removeOutput(int index);
    void assignZoneToOutput(int zoneId, int outputIndex);

    void setMasterEnabled(bool enabled) { masterEnabled = enabled; }
    bool isMasterEnabled() const { return masterEnabled; }

    //==========================================================================
    // Optimization
    //==========================================================================

    BeamOptimizer& getOptimizer() { return optimizer; }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Process and output frame */
    void processFrame(double deltaTime);

    /** Set audio data for reactive effects */
    void setAudioSpectrum(const std::vector<float>& spectrum);
    void setAudioWaveform(const std::vector<float>& waveform);

    /** Set bio data for reactive effects */
    void setBioData(float hrv, float coherence);

    //==========================================================================
    // Safety
    //==========================================================================

    struct SafetyLimits
    {
        bool masterInterlock = true;     // Must be explicitly enabled
        float maxTotalPower = 1.0f;      // 0-1 master intensity limit
        int maxPointsPerSecond = 30000;  // ILDA standard
        bool audienceZoneProtection = true;
        std::vector<juce::Rectangle<float>> protectedZones;
    };

    void setSafetyLimits(const SafetyLimits& limits) { safetyLimits = limits; }
    SafetyLimits& getSafetyLimits() { return safetyLimits; }

    /** Emergency stop - immediately blanks all outputs */
    void emergencyStop();

    //==========================================================================
    // Live Control
    //==========================================================================

    /** Quick access to common parameters */
    void setMasterIntensity(float intensity) { masterIntensity = intensity; }
    void setMasterColor(juce::Colour color) { masterColor = color; }
    void setMasterSize(float size) { masterSize = size; }
    void setMasterRotation(float rotation) { masterRotation = rotation; }
    void setMasterPosition(float x, float y) { masterX = x; masterY = y; }

    //==========================================================================
    // MIDI Learn
    //==========================================================================

    void handleMIDI(const juce::MidiMessage& message);
    void setMIDILearnTarget(const juce::String& parameter);

private:
    // Content
    std::map<int, ILDASequence> sequences;
    int nextSequenceId = 1;

    AbstractGenerator generator;
    EffectStack masterEffects;

    // Zones and timeline
    ZoneManager zoneManager;
    Timeline timeline;

    // Outputs
    std::vector<std::unique_ptr<LaserOutput>> outputs;
    std::map<int, int> zoneOutputMapping;  // zoneId -> outputIndex

    // Optimization
    BeamOptimizer optimizer;

    // Safety
    SafetyLimits safetyLimits;
    bool masterEnabled = false;

    // Master controls
    float masterIntensity = 1.0f;
    juce::Colour masterColor = juce::Colours::white;
    float masterSize = 1.0f;
    float masterRotation = 0.0f;
    float masterX = 0.0f, masterY = 0.0f;

    // Audio/bio reactive
    std::vector<float> currentSpectrum;
    std::vector<float> currentWaveform;
    float bioHRV = 0.5f, bioCoherence = 0.5f;

    // Frame rate
    double frameRate = 30.0;
    double frameInterval = 1.0 / 30.0;

    // MIDI learn
    juce::String midiLearnTarget;
    std::map<int, std::pair<juce::String, float*>> midiMappings;

    // Internal methods
    ILDAFrame applyMasterControls(const ILDAFrame& frame);
    void applySafetyChecks(ILDAFrame& frame);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LaserShowEngine)
};

}  // namespace Echoel::Visual
