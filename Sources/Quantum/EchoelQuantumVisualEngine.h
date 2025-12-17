#pragma once

#include <JuceHeader.h>
#include "EchoelPoint3D.h"
#include "EchoelQuantumCore.h"

/**
 * EchoelQuantumVisualEngine - Holographic, Laser, Mapping, Visual Production
 *
 * Revolutionary visual engine integrating:
 * - Real-time video processing
 * - Projection mapping (buildings, stages, installations)
 * - Holographic displays
 * - Laser show programming (ILDA protocol)
 * - DMX512 lighting control
 * - LED matrix control
 * - AR/VR integration
 * - Bio-reactive visuals
 * - AI-generated visuals
 * - Particle systems
 *
 * Compatible with:
 * - Resolume Arena (via OSC/MIDI)
 * - TouchDesigner (via OSC/NDI)
 * - MadMapper (via Syphon/Spout)
 * - VDMX (via Syphon)
 * - Unity/Unreal (via NDI/OSC)
 * - TouchOSC/Lemur
 */
class EchoelQuantumVisualEngine
{
public:
    //==========================================================================
    // 1. PROJECTION MAPPING
    //==========================================================================

    /**
     * 3D Surface for projection mapping
     */
    struct ProjectionSurface
    {
        juce::String surfaceID;
        enum class Type
        {
            Flat,          // 2D screen/wall
            Cylinder,      // Round column
            Sphere,        // Dome/ball
            Cube,          // Box
            Building,      // Architectural mapping
            Custom         // User-defined mesh
        } type;

        // Geometry
        std::vector<juce::Point<float>> corners;  // Corner points for warping
        juce::File meshFile;                       // .obj file for complex shapes

        // Transform
        EchoelPoint3D<float> position;
        EchoelPoint3D<float> rotation;
        EchoelPoint3D<float> scale;

        // Content
        juce::Image contentImage;
        juce::File videoFile;

        // Warping
        bool keystoneEnabled = true;
        bool meshWarpEnabled = false;
    };

    juce::String createProjectionSurface(ProjectionSurface::Type type);
    void setSurfaceCorners(const juce::String& surfaceID, const std::vector<juce::Point<float>>& corners);
    void loadSurfaceMesh(const juce::String& surfaceID, const juce::File& objFile);

    /**
     * Automatic calibration via camera/projector feedback
     */
    void calibrateProjector(const juce::File& cameraFeed);

    //==========================================================================
    // 2. HOLOGRAPHIC DISPLAY
    //==========================================================================

    /**
     * Holographic display types
     */
    enum class HologramType
    {
        Pepper,          // Pepper's Ghost illusion
        Volumetric,      // True 3D volumetric display
        Holographic,     // Laser-based holography
        LightField,      // Light field display
        AR,              // Augmented Reality (phone/tablet/glasses)
        VR               // Virtual Reality (headset)
    };

    void setHologramType(HologramType type);

    /**
     * Holographic content layer
     */
    struct HologramLayer
    {
        juce::String layerID;
        EchoelPoint3D<float> position;
        float depth = 1.0f;            // Z-depth in hologram
        juce::Colour color;
        float opacity = 1.0f;

        // Animation
        bool animated = false;
        enum class AnimationType { Rotate, Pulse, Wave, Particle } animType;

        // Bio-reactive
        bool bioReactive = false;
        juce::String bioParameter;
    };

    juce::String createHologramLayer();
    void setLayerBioMapping(const juce::String& layerID, const juce::String& bioParam);

    //==========================================================================
    // 3. LASER SHOW PROGRAMMING (ILDA Protocol)
    //==========================================================================

    /**
     * Laser frame (ILDA standard)
     */
    struct LaserPoint
    {
        float x = 0.0f, y = 0.0f;      // -1 to +1 (normalized)
        juce::Colour color;
        bool blanking = false;          // Laser off (move without drawing)
    };

    struct LaserFrame
    {
        std::vector<LaserPoint> points;
        float scanRate = 30000.0f;      // Points per second (typical: 30k)
    };

    /**
     * Laser show control
     */
    void enableLaserOutput(bool enable);
    void setLaserDAC(const juce::String& deviceID);  // EtherDream, Helios, etc.
    void sendLaserFrame(const LaserFrame& frame);

    /**
     * Pre-programmed laser effects
     */
    enum class LaserEffect
    {
        AudioWaveform,   // Draw audio waveform
        Spectrum,        // Frequency spectrum
        Tunnel,          // 3D tunnel
        Spiral,          // Geometric spiral
        Text,            // Scrolling text
        Logo,            // Vector logo
        Beam,            // Straight beam
        Scan,            // Scanning effect
        BioReactive      // React to bio-data
    };

    void playLaserEffect(LaserEffect effect);

    //==========================================================================
    // 4. DMX512 LIGHTING CONTROL
    //==========================================================================

    /**
     * DMX Universe (512 channels)
     */
    struct DMXUniverse
    {
        int universeID = 1;
        std::array<uint8_t, 512> channels;  // DMX channels 1-512
    };

    /**
     * Lighting fixture
     */
    struct LightingFixture
    {
        juce::String fixtureID;
        enum class Type
        {
            PAR,           // PAR can (RGB)
            MovingHead,    // Moving head spot/wash
            Strobe,        // Strobe light
            Laser,         // DMX-controlled laser
            LED_Bar,       // LED bar/strip
            Fog,           // Fog machine
            Custom         // User-defined
        } type;

        int dmxChannel = 1;             // Starting DMX channel
        int numChannels = 3;            // Number of channels (e.g., RGB = 3)

        // Control values
        float red = 0.0f, green = 0.0f, blue = 0.0f;
        float intensity = 1.0f;
        float pan = 0.5f, tilt = 0.5f;  // Moving head position
        float strobe = 0.0f;

        // Bio-reactive mapping
        bool bioReactive = false;
        juce::String bioParameter;
    };

    juce::String createLightingFixture(LightingFixture::Type type, int dmxChannel);
    void setFixtureColor(const juce::String& fixtureID, juce::Colour color);
    void setFixtureBioMapping(const juce::String& fixtureID, const juce::String& bioParam);

    /**
     * DMX output via USB-DMX interface
     */
    void enableDMXOutput(bool enable);
    void setDMXInterface(const juce::String& deviceID);  // Enttec, DMXKing, etc.
    void sendDMXUniverse(const DMXUniverse& universe);

    //==========================================================================
    // 5. LED MATRIX CONTROL
    //==========================================================================

    /**
     * LED Matrix configuration
     */
    struct LEDMatrix
    {
        int width = 16;                 // Columns
        int height = 16;                // Rows
        int totalPixels = 256;

        enum class Protocol
        {
            WS2812,      // NeoPixel (most common)
            APA102,      // DotStar
            SK6812,      // RGBW NeoPixel
            DMX,         // DMX512 pixels
            ArtNet       // Art-Net over Ethernet
        } protocol = Protocol::WS2812;

        std::vector<juce::Colour> pixels;

        // Physical layout
        bool serpentine = true;  // Zigzag wiring
    };

    void setLEDMatrixSize(int width, int height);
    void setLEDPixel(int x, int y, juce::Colour color);
    void displayLEDImage(const juce::Image& image);

    /**
     * LED effects
     */
    enum class LEDEffect
    {
        AudioSpectrum,   // Frequency bars
        Waveform,        // Audio waveform
        VUMeter,         // Level meter
        Equalizer,       // Multi-band EQ display
        BioVisualization, // HRV/brainwave display
        Particle,        // Particle system
        Fire,            // Fire effect
        Rainbow,         // Rainbow cycle
        Matrix           // Matrix rain
    };

    void playLEDEffect(LEDEffect effect);

    //==========================================================================
    // 6. AR/VR INTEGRATION
    //==========================================================================

    /**
     * AR/VR Platform
     */
    enum class XRPlatform
    {
        ARKit,           // Apple ARKit (iOS)
        ARCore,          // Google ARCore (Android)
        OculusQuest,     // Meta Quest
        VisionPro,       // Apple Vision Pro
        PSVR2,           // PlayStation VR2
        SteamVR,         // Valve Index, HTC Vive
        WebXR            // Browser-based XR
    };

    void enableXR(XRPlatform platform);

    /**
     * Spatial Anchor (AR)
     */
    struct SpatialAnchor
    {
        juce::String anchorID;
        EchoelPoint3D<float> worldPosition;
        EchoelPoint3D<float> rotation;

        // Content
        juce::String hologramLayerID;
        juce::String audioObjectID;
    };

    juce::String createSpatialAnchor(const EchoelPoint3D<float>& position);
    void attachContentToAnchor(const juce::String& anchorID, const juce::String& contentID);

    //==========================================================================
    // 7. BIO-REACTIVE VISUAL GENERATION
    //==========================================================================

    /**
     * AI-generated visuals based on bio-state
     */
    struct BioVisualMapping
    {
        juce::String mappingID;

        // Input bio-parameter
        juce::String bioParameter;  // "hrv", "alpha", "stress", etc.

        // Output visual parameter
        enum class VisualParameter
        {
            Color,           // Hue shift
            Brightness,      // Intensity
            Speed,           // Animation speed
            Complexity,      // Detail level
            Particle_Count,  // Number of particles
            Blur,            // Blur amount
            Saturation,      // Color saturation
            Rotation,        // Rotation speed
            Scale,           // Size
            Position         // XYZ position
        } visualParam;

        // Mapping curve
        float minValue = 0.0f;
        float maxValue = 1.0f;
        bool invert = false;
    };

    juce::String createBioVisualMapping(const juce::String& bioParam, BioVisualMapping::VisualParameter visualParam);

    /**
     * Generative AI visuals
     */
    enum class AIVisualStyle
    {
        Abstract,        // Abstract patterns
        Fractal,         // Fractal geometry
        FlowField,       // Flow fields
        Particle,        // Particle systems
        Neural,          // Neural network visualization
        Organic,         // Organic shapes
        Geometric,       // Geometric patterns
        Psychedelic,     // Psychedelic visuals
        Minimal          // Minimalist
    };

    void setAIVisualStyle(AIVisualStyle style);
    void generateAIVisuals(const EchoelQuantumCore::QuantumBioState& bioState);

    //==========================================================================
    // 8. VIDEO PROCESSING & EFFECTS
    //==========================================================================

    /**
     * Real-time video effects
     */
    enum class VideoEffect
    {
        ChromaKey,       // Green screen
        ColorGrading,    // LUT-based grading
        Blur,            // Gaussian blur
        Sharpen,         // Sharpen
        EdgeDetect,      // Edge detection
        Glitch,          // Glitch effect
        Datamosh,        // Datamoshing
        TimeRemap,       // Time effects
        Trail,           // Motion trail
        Kaleidoscope,    // Kaleidoscope
        Mirror,          // Mirror effect
        Feedback         // Video feedback
    };

    void enableVideoEffect(VideoEffect effect, float intensity);

    /**
     * Video input sources
     */
    enum class VideoSource
    {
        Webcam,          // Built-in camera
        HDMI,            // HDMI capture card
        NDI,             // NewTek NDI
        Syphon,          // Syphon (macOS)
        Spout,           // Spout (Windows)
        ScreenCapture,   // Screen recording
        VideoFile        // Video file playback
    };

    void setVideoSource(VideoSource source, const juce::String& config);

    //==========================================================================
    // 9. INTEGRATION PROTOCOLS
    //==========================================================================

    /**
     * Output protocols for VJ software integration
     */
    void enableOSCOutput(int port = 8000);
    void enableNDIOutput(const juce::String& streamName);
    void enableSyphonOutput(const juce::String& serverName);  // macOS
    void enableSpoutOutput(const juce::String& serverName);   // Windows

    /**
     * Send data to external apps
     */
    void sendOSCMessage(const juce::String& address, float value);
    void sendMIDICC(int channel, int cc, int value);

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    EchoelQuantumVisualEngine();
    ~EchoelQuantumVisualEngine();

    /**
     * Process function - generates visuals synchronized to audio
     */
    void process(juce::Image& outputImage, const EchoelQuantumCore::QuantumBioState& bioState);

private:
    std::vector<ProjectionSurface> projectionSurfaces;
    std::vector<HologramLayer> hologramLayers;
    std::vector<LightingFixture> lightingFixtures;
    std::vector<SpatialAnchor> spatialAnchors;
    std::vector<BioVisualMapping> bioVisualMappings;

    LEDMatrix ledMatrix;
    DMXUniverse dmxUniverse;
    LaserFrame currentLaserFrame;

    HologramType currentHologramType = HologramType::Pepper;
    AIVisualStyle currentAIStyle = AIVisualStyle::Abstract;

    // GPU-accelerated rendering (OpenGL to be added later)
    // std::unique_ptr<juce::OpenGLContext> openGLContext;

    // Internal rendering
    void renderProjectionMapping(juce::Image& output);
    void renderHolograms(juce::Image& output);
    void renderBioReactiveVisuals(juce::Image& output, const EchoelQuantumCore::QuantumBioState& bioState);
    void updateLighting(const EchoelQuantumCore::QuantumBioState& bioState);
    void updateLaser(const EchoelQuantumCore::QuantumBioState& bioState);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelQuantumVisualEngine)
};
