#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>

/**
 * LaserForce
 *
 * Professional laser show control system.
 * Inspired by Pangolin Beyond, LaserWorld ShowNET, Lightjams.
 * ILDA and DMX protocol support for laser projectors.
 *
 * Features:
 * - ILDA protocol support (International Laser Display Association)
 * - DMX512 control
 * - Vector graphics rendering
 * - Beam effects (spirals, tunnels, grids, waves)
 * - Text/logo projection
 * - Audio-reactive patterns
 * - Bio-reactive beam control
 * - Zone mapping (multiple projectors)
 * - Safety scanning (prevent audience exposure)
 * - Timecode sync
 */
class LaserForce
{
public:
    //==========================================================================
    // Laser Output Configuration
    //==========================================================================

    struct LaserOutput
    {
        bool enabled = true;
        juce::String name;
        juce::String protocol = "ILDA";  // "ILDA" or "DMX"

        // Connection
        juce::String ipAddress = "127.0.0.1";
        int port = 7255;                  // ILDA default
        int dmxUniverse = 1;              // For DMX

        // Calibration
        float xOffset = 0.0f;             // -1.0 to 1.0
        float yOffset = 0.0f;
        float xScale = 1.0f;
        float yScale = 1.0f;
        float rotation = 0.0f;            // Radians

        // Safety
        bool safetyEnabled = true;
        std::vector<juce::Rectangle<float>> safeZones;  // Areas to avoid

        LaserOutput() = default;
    };

    //==========================================================================
    // Pattern Types
    //==========================================================================

    enum class PatternType
    {
        // Basic Shapes
        Circle,
        Square,
        Triangle,
        Star,
        Polygon,

        // Lines
        HorizontalLine,
        VerticalLine,
        Cross,
        Grid,

        // Animated
        Spiral,
        Tunnel,
        Wave,
        Lissajous,

        // Text
        Text,
        Logo,

        // Advanced
        ParticleBeam,
        Constellation,
        VectorAnimation,

        // Audio-Reactive
        AudioWaveform,
        AudioSpectrum,
        AudioTunnel
    };

    //==========================================================================
    // Beam Configuration
    //==========================================================================

    struct Beam
    {
        bool enabled = true;
        juce::String name;

        PatternType pattern = PatternType::Circle;

        // Position & Transform
        float x = 0.0f, y = 0.0f;         // -1.0 to 1.0 (screen space)
        float z = 0.0f;                   // Depth (for 3D effects)
        float size = 0.5f;                // 0.0 to 1.0
        float rotation = 0.0f;            // Radians
        float rotationSpeed = 0.0f;       // Radians/second

        // Color (RGB laser)
        float red = 1.0f;                 // 0.0 to 1.0
        float green = 0.0f;
        float blue = 0.0f;
        float brightness = 1.0f;

        // Animation
        float speed = 1.0f;
        float phaseOffset = 0.0f;

        // Pattern-specific
        int sides = 5;                    // For Polygon, Star
        float frequency = 1.0f;           // For Wave, Lissajous
        juce::String text;                // For Text pattern

        // Modulation
        bool audioReactive = false;
        bool bioReactive = false;

        Beam() = default;
    };

    //==========================================================================
    // Safety Configuration
    //==========================================================================

    struct SafetyConfig
    {
        bool enabled = true;

        // Maximum scan speed (points per second)
        int maxScanSpeed = 30000;         // ILDA standard: 30K pps

        // Minimum beam diameter (mm at specified distance)
        float minBeamDiameter = 5.0f;
        float measurementDistance = 3000.0f;  // mm (3 meters)

        // Power limits
        float maxPowerMw = 500.0f;        // Milliwatts

        // Audience scanning prevention
        bool preventAudienceScanning = true;
        float audienceHeight = 1800.0f;   // mm

        SafetyConfig() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    LaserForce();
    ~LaserForce() = default;

    //==========================================================================
    // Output Management
    //==========================================================================

    int addOutput(const LaserOutput& output);
    LaserOutput& getOutput(int index);
    const LaserOutput& getOutput(int index) const;
    void removeOutput(int index);

    int getNumOutputs() const { return static_cast<int>(outputs.size()); }

    //==========================================================================
    // Beam Management
    //==========================================================================

    int addBeam(const Beam& beam);
    Beam& getBeam(int index);
    const Beam& getBeam(int index) const;
    void setBeam(int index, const Beam& beam);
    void removeBeam(int index);
    void clearBeams();

    int getNumBeams() const { return static_cast<int>(beams.size()); }

    //==========================================================================
    // Safety
    //==========================================================================

    void setSafetyConfig(const SafetyConfig& config);
    const SafetyConfig& getSafetyConfig() const { return safetyConfig; }

    /** Check if current configuration is safe */
    bool isSafe() const;

    /** Get safety warnings */
    std::vector<juce::String> getSafetyWarnings() const;

    //==========================================================================
    // Audio Reactive
    //==========================================================================

    void updateAudioSpectrum(const std::vector<float>& spectrumData);
    void updateWaveform(const std::vector<float>& waveformData);

    //==========================================================================
    // Bio-Reactive
    //==========================================================================

    void setBioData(float hrv, float coherence);
    void setBioReactiveEnabled(bool enabled);

    //==========================================================================
    // Rendering & Output
    //==========================================================================

    /** Render frame to ILDA points */
    struct ILDAPoint
    {
        int16_t x, y, z;                  // -32768 to +32767
        uint8_t r, g, b;                  // 0 to 255
        uint8_t status;                   // Blanking bit, etc.
    };

    std::vector<ILDAPoint> renderFrame(double deltaTime);

    /** Send frame to all outputs */
    void sendFrame();

    /** Enable/disable laser output (master switch) */
    void setOutputEnabled(bool enabled);
    bool isOutputEnabled() const { return outputEnabled; }

    //==========================================================================
    // Presets
    //==========================================================================

    std::vector<juce::String> getBuiltInPresets() const;
    void loadBuiltInPreset(const juce::String& name);

    //==========================================================================
    // Recording
    //==========================================================================

    void startRecording(const juce::File& outputFile);
    void stopRecording();
    bool isRecording() const { return recording; }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    std::vector<LaserOutput> outputs;
    std::vector<Beam> beams;

    SafetyConfig safetyConfig;

    bool outputEnabled = false;  // Safety: off by default
    bool bioReactiveEnabled = false;

    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;

    std::vector<float> currentSpectrum;
    std::vector<float> currentWaveform;

    // Animation time
    double currentTime = 0.0;

    // Recording
    bool recording = false;
    juce::File recordingFile;
    std::vector<std::vector<ILDAPoint>> recordedFrames;

    //==========================================================================
    // Rendering Methods
    //==========================================================================

    std::vector<ILDAPoint> renderBeam(const Beam& beam);
    std::vector<ILDAPoint> renderCircle(const Beam& beam);
    std::vector<ILDAPoint> renderPolygon(const Beam& beam);
    std::vector<ILDAPoint> renderSpiral(const Beam& beam);
    std::vector<ILDAPoint> renderTunnel(const Beam& beam);
    std::vector<ILDAPoint> renderText(const Beam& beam);
    std::vector<ILDAPoint> renderAudioWaveform(const Beam& beam);

    // Safety checking
    bool checkSafetyZones(const std::vector<ILDAPoint>& points, const LaserOutput& output);
    void applySafetyLimits(std::vector<ILDAPoint>& points);

    // Protocol conversion
    std::vector<uint8_t> convertToILDA(const std::vector<ILDAPoint>& points);
    std::vector<uint8_t> convertToDMX(const std::vector<ILDAPoint>& points);

    // Network output
    void sendToOutput(const LaserOutput& output, const std::vector<uint8_t>& data);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (LaserForce)
};
