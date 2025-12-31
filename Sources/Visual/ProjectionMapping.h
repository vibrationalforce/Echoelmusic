#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>

/**
 * ProjectionMapping - Advanced Projection Mapping Engine
 *
 * Inspired by: Resolume Arena, MadMapper, TouchDesigner
 *
 * Features:
 * - Multi-projector edge blending
 * - Warping (4-corner, bezier, mesh)
 * - DMX fixture mapping
 * - LED strip pixel mapping
 * - 3D object projection
 * - Real-time mask editing
 * - Spout/Syphon/NDI I/O
 */
namespace Echoel::Visual
{

//==============================================================================
// Warping Types
//==============================================================================

enum class WarpType
{
    None,
    FourCorner,      // Basic perspective correction
    Bezier,          // Smooth bezier curves
    Mesh,            // Freeform mesh grid
    Cylindrical,     // Wrap around cylinder
    Spherical,       // Spherical projection (dome)
    Custom           // User-defined shader
};

//==============================================================================
// Surface Definition (Mappable area)
//==============================================================================

struct MappingSurface
{
    juce::String name = "Surface";
    int id = 0;

    // Source region (from video/visual content)
    juce::Rectangle<float> sourceRect {0.0f, 0.0f, 1.0f, 1.0f};

    // Destination corners (for 4-corner warp)
    std::array<juce::Point<float>, 4> corners {{
        {0.0f, 0.0f},   // Top-left
        {1.0f, 0.0f},   // Top-right
        {1.0f, 1.0f},   // Bottom-right
        {0.0f, 1.0f}    // Bottom-left
    }};

    // Bezier control points (8 points for smooth edges)
    std::array<juce::Point<float>, 8> bezierControls;

    // Mesh grid (for freeform warping)
    int meshGridX = 4;
    int meshGridY = 4;
    std::vector<juce::Point<float>> meshPoints;

    WarpType warpType = WarpType::FourCorner;

    // Blending
    float opacity = 1.0f;
    enum class BlendMode { Normal, Add, Multiply, Screen, Overlay } blendMode = BlendMode::Normal;

    // Edge blending (for multi-projector)
    struct EdgeBlend
    {
        float left = 0.0f;      // 0-1 blend zone width
        float right = 0.0f;
        float top = 0.0f;
        float bottom = 0.0f;
        float gamma = 2.2f;     // Gamma correction for blend
    } edgeBlend;

    // Mask (alpha mask path)
    juce::Path maskPath;
    bool maskEnabled = false;
    bool maskInvert = false;

    // Color correction per surface
    float brightness = 1.0f;
    float contrast = 1.0f;
    float saturation = 1.0f;
    float hue = 0.0f;
    float temperature = 0.0f;   // Warm/cool shift

    MappingSurface()
    {
        initializeMesh();
    }

    void initializeMesh()
    {
        meshPoints.clear();
        for (int y = 0; y <= meshGridY; ++y)
        {
            for (int x = 0; x <= meshGridX; ++x)
            {
                meshPoints.push_back({
                    static_cast<float>(x) / meshGridX,
                    static_cast<float>(y) / meshGridY
                });
            }
        }
    }
};

//==============================================================================
// Projector Configuration
//==============================================================================

struct Projector
{
    juce::String name = "Projector";
    int id = 0;

    // Physical position/orientation
    juce::Vector3D<float> position {0.0f, 0.0f, 0.0f};
    juce::Vector3D<float> rotation {0.0f, 0.0f, 0.0f};  // Euler angles

    // Output configuration
    int outputIndex = 0;       // Display/output number
    int width = 1920;
    int height = 1080;
    float aspectRatio = 16.0f / 9.0f;

    // Lens characteristics
    float throwRatio = 1.5f;   // Throw distance / image width
    float lensShift = 0.0f;    // Vertical lens shift
    float brightness = 1.0f;

    // Color calibration
    juce::Colour whitePoint {255, 255, 255};
    float gamma = 2.2f;

    // Assigned surfaces
    std::vector<int> surfaceIds;

    // Test patterns
    enum class TestPattern { None, Grid, Crosshatch, ColorBars, White, Gradient };
    TestPattern testPattern = TestPattern::None;
};

//==============================================================================
// LED/DMX Pixel Mapping
//==============================================================================

struct PixelMap
{
    juce::String name = "LED Strip";
    int id = 0;

    enum class Layout
    {
        Linear,          // Simple strip
        Matrix,          // 2D grid
        ZigZag,          // Alternating rows
        Snake,           // Continuous snake
        Radial,          // Circular arrangement
        Custom           // User-defined positions
    };

    Layout layout = Layout::Linear;

    // Pixel configuration
    int numPixels = 60;
    int pixelsPerMeter = 30;

    // Matrix dimensions (if applicable)
    int matrixWidth = 16;
    int matrixHeight = 16;

    // Position in video space (0-1 normalized)
    std::vector<juce::Point<float>> pixelPositions;

    // DMX configuration
    int dmxUniverse = 1;
    int dmxStartChannel = 1;

    enum class PixelOrder { RGB, RBG, GRB, GBR, BRG, BGR, RGBW, GRBW };
    PixelOrder pixelOrder = PixelOrder::RGB;

    // Gamma correction for LEDs
    float gamma = 2.5f;

    // Color temperature compensation
    float colorTemp = 6500.0f;  // Kelvin

    void initializeLayout()
    {
        pixelPositions.clear();

        switch (layout)
        {
            case Layout::Linear:
                for (int i = 0; i < numPixels; ++i)
                {
                    pixelPositions.push_back({
                        static_cast<float>(i) / (numPixels - 1),
                        0.5f
                    });
                }
                break;

            case Layout::Matrix:
            case Layout::ZigZag:
                for (int y = 0; y < matrixHeight; ++y)
                {
                    for (int x = 0; x < matrixWidth; ++x)
                    {
                        int actualX = (layout == Layout::ZigZag && y % 2 == 1)
                                      ? (matrixWidth - 1 - x) : x;
                        pixelPositions.push_back({
                            static_cast<float>(actualX) / (matrixWidth - 1),
                            static_cast<float>(y) / (matrixHeight - 1)
                        });
                    }
                }
                break;

            case Layout::Radial:
                for (int i = 0; i < numPixels; ++i)
                {
                    float angle = (2.0f * juce::MathConstants<float>::pi * i) / numPixels;
                    pixelPositions.push_back({
                        0.5f + 0.4f * std::cos(angle),
                        0.5f + 0.4f * std::sin(angle)
                    });
                }
                break;

            default:
                break;
        }
    }
};

//==============================================================================
// Projection Mapping Engine
//==============================================================================

class ProjectionMappingEngine
{
public:
    ProjectionMappingEngine();
    ~ProjectionMappingEngine();

    //==========================================================================
    // Surface Management
    //==========================================================================

    int addSurface(const MappingSurface& surface);
    void removeSurface(int surfaceId);
    MappingSurface* getSurface(int surfaceId);
    const std::vector<MappingSurface>& getSurfaces() const { return surfaces; }

    void setSurfaceCorner(int surfaceId, int cornerIndex, juce::Point<float> position);
    void setSurfaceMeshPoint(int surfaceId, int pointIndex, juce::Point<float> position);

    //==========================================================================
    // Projector Management
    //==========================================================================

    int addProjector(const Projector& projector);
    void removeProjector(int projectorId);
    Projector* getProjector(int projectorId);
    const std::vector<Projector>& getProjectors() const { return projectors; }

    void assignSurfaceToProjector(int surfaceId, int projectorId);

    //==========================================================================
    // Pixel Mapping (LED/DMX)
    //==========================================================================

    int addPixelMap(const PixelMap& pixelMap);
    void removePixelMap(int mapId);
    PixelMap* getPixelMap(int mapId);

    /** Sample video frame and output DMX data for all pixel maps */
    void samplePixels(const juce::Image& frame, std::vector<uint8_t>& dmxOutput);

    //==========================================================================
    // Rendering
    //==========================================================================

    /** Render source content to all projector outputs with warping */
    void render(const juce::Image& sourceContent);

    /** Get warped output for specific projector */
    juce::Image getProjectorOutput(int projectorId, int width, int height);

    /** Apply warp transformation to a point */
    juce::Point<float> warpPoint(const MappingSurface& surface, juce::Point<float> sourcePoint);

    /** Apply inverse warp (for picking/editing) */
    juce::Point<float> inverseWarpPoint(const MappingSurface& surface, juce::Point<float> warpedPoint);

    //==========================================================================
    // Edge Blending
    //==========================================================================

    /** Calculate edge blend alpha for given position */
    float calculateEdgeBlendAlpha(const MappingSurface::EdgeBlend& blend,
                                   float x, float y, float width, float height);

    //==========================================================================
    // Calibration
    //==========================================================================

    /** Start interactive calibration mode */
    void startCalibration(int projectorId);
    void endCalibration();
    bool isCalibrating() const { return calibrationActive; }

    /** Auto-align projectors using camera feedback */
    void autoAlignProjectors();

    //==========================================================================
    // I/O
    //==========================================================================

    /** Save/load mapping configuration */
    void saveConfiguration(const juce::File& file);
    void loadConfiguration(const juce::File& file);

    /** Export as JSON for external tools */
    juce::String exportToJSON() const;
    void importFromJSON(const juce::String& json);

private:
    std::vector<MappingSurface> surfaces;
    std::vector<Projector> projectors;
    std::vector<PixelMap> pixelMaps;

    int nextSurfaceId = 1;
    int nextProjectorId = 1;
    int nextPixelMapId = 1;

    bool calibrationActive = false;
    int calibratingProjector = -1;

    // Rendering buffers
    std::vector<juce::Image> projectorBuffers;

    // Warp mesh cache
    std::vector<std::vector<juce::Point<float>>> warpMeshCache;

    void updateWarpMesh(int surfaceId);
    juce::Point<float> bilinearInterpolate(const std::array<juce::Point<float>, 4>& corners,
                                            float u, float v);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ProjectionMappingEngine)
};

//==============================================================================
// 3D Object Projection (for complex shapes)
//==============================================================================

class Object3DProjection
{
public:
    struct Vertex
    {
        juce::Vector3D<float> position;
        juce::Point<float> uv;  // Texture coordinates
    };

    struct Face
    {
        std::array<int, 3> vertexIndices;
        juce::Vector3D<float> normal;
    };

    struct Mesh3D
    {
        juce::String name;
        std::vector<Vertex> vertices;
        std::vector<Face> faces;

        // Pre-built primitives
        static Mesh3D createCube(float size = 1.0f);
        static Mesh3D createSphere(float radius = 1.0f, int segments = 32);
        static Mesh3D createCylinder(float radius = 0.5f, float height = 1.0f, int segments = 32);
        static Mesh3D createPlane(float width = 1.0f, float height = 1.0f, int divisionsX = 1, int divisionsY = 1);
    };

    /** Project 3D mesh to 2D screen coordinates */
    static std::vector<juce::Point<float>> projectMesh(
        const Mesh3D& mesh,
        const juce::Vector3D<float>& cameraPosition,
        const juce::Vector3D<float>& cameraTarget,
        float fov,
        float aspectRatio,
        float nearPlane = 0.1f,
        float farPlane = 100.0f);

    /** Load mesh from OBJ file */
    static Mesh3D loadOBJ(const juce::File& file);

    /** Generate UV mapping for projection onto 3D surface */
    static void generateProjectionUVs(Mesh3D& mesh, const Projector& projector);
};

}  // namespace Echoel::Visual
