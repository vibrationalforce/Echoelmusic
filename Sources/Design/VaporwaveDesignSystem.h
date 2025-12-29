#pragma once

#include <JuceHeader.h>
#include <array>
#include <cmath>

/**
 * VaporwaveDesignSystem - Science-Based Aesthetic Engine
 *
 * Inspired by: Vaporwave, Synthwave, Retrowave aesthetics
 * Science Foundation: Color psychology, frequency-color mapping,
 *                     cymatics visualization, sacred geometry
 *
 * "The most intelligent visual design system the world has ever seen"
 */
namespace Echoel::Design
{

//==============================================================================
// Color Science - Vaporwave Palette
//==============================================================================

struct VaporwaveColors
{
    // Primary Neon Colors (high saturation, luminance)
    static constexpr uint32_t NeonPink     = 0xFFFF71CE;
    static constexpr uint32_t NeonCyan     = 0xFF01CDFE;
    static constexpr uint32_t NeonMint     = 0xFF05FFA1;
    static constexpr uint32_t NeonPurple   = 0xFFB967FF;
    static constexpr uint32_t NeonYellow   = 0xFFFFFB96;
    static constexpr uint32_t NeonOrange   = 0xFFFF6B35;

    // Background Gradients (deep, atmospheric)
    static constexpr uint32_t DeepSpace    = 0xFF1A1A2E;
    static constexpr uint32_t MidnightBlue = 0xFF16213E;
    static constexpr uint32_t DarkPurple   = 0xFF0F0E17;
    static constexpr uint32_t Sunset1      = 0xFFFF6B6B;
    static constexpr uint32_t Sunset2      = 0xFFFFA07A;
    static constexpr uint32_t Sunset3      = 0xFFFFD93D;

    // Marble/Classical (Greek aesthetic)
    static constexpr uint32_t MarbleWhite  = 0xFFF5F5F5;
    static constexpr uint32_t MarblePink   = 0xFFFFE4E1;
    static constexpr uint32_t MarbleGray   = 0xFFD3D3D3;

    // VHS Degradation
    static constexpr uint32_t VHSBlue      = 0xFF4169E1;
    static constexpr uint32_t VHSRed       = 0xFFDC143C;
    static constexpr uint32_t VHSScanline  = 0x20FFFFFF;

    // Chromatic Aberration offsets (in pixels)
    static constexpr float ChromaOffsetR = 2.0f;
    static constexpr float ChromaOffsetG = 0.0f;
    static constexpr float ChromaOffsetB = -2.0f;
};

//==============================================================================
// Frequency-Color Mapping (Science-Based Synesthesia)
//==============================================================================

class FrequencyColorMapper
{
public:
    /**
     * Maps audio frequency to color using scientific frequency-wavelength relationship
     * Based on: Audible range (20Hz-20kHz) → Visible light (380-750nm)
     */
    static juce::Colour frequencyToColour(float frequencyHz)
    {
        // Logarithmic mapping: audio frequency to color wavelength
        // 20Hz → Red (700nm), 20kHz → Violet (400nm)
        constexpr float minFreq = 20.0f;
        constexpr float maxFreq = 20000.0f;
        constexpr float minWavelength = 380.0f;  // Violet
        constexpr float maxWavelength = 750.0f;  // Red

        float logFreq = std::log2(std::clamp(frequencyHz, minFreq, maxFreq) / minFreq);
        float logRange = std::log2(maxFreq / minFreq);
        float normalizedFreq = logFreq / logRange;

        // Invert: low freq = red, high freq = violet
        float wavelength = maxWavelength - normalizedFreq * (maxWavelength - minWavelength);

        return wavelengthToRGB(wavelength);
    }

    /**
     * Musical note to color (A4 = 440Hz)
     * Based on chakra/note associations and color wheel
     */
    static juce::Colour noteToColour(int midiNote)
    {
        // C = Red, D = Orange, E = Yellow, F = Green,
        // G = Cyan, A = Blue, B = Violet
        static const std::array<juce::Colour, 12> noteColors = {{
            juce::Colour(0xFFFF0000),  // C  - Red
            juce::Colour(0xFFFF4500),  // C# - Red-Orange
            juce::Colour(0xFFFF8C00),  // D  - Orange
            juce::Colour(0xFFFFD700),  // D# - Gold
            juce::Colour(0xFFFFFF00),  // E  - Yellow
            juce::Colour(0xFF00FF00),  // F  - Green
            juce::Colour(0xFF00CED1),  // F# - Teal
            juce::Colour(0xFF00FFFF),  // G  - Cyan
            juce::Colour(0xFF0080FF),  // G# - Sky Blue
            juce::Colour(0xFF0000FF),  // A  - Blue
            juce::Colour(0xFF8000FF),  // A# - Violet
            juce::Colour(0xFFFF00FF)   // B  - Magenta
        }};

        int noteIndex = midiNote % 12;
        return noteColors[noteIndex];
    }

    /**
     * Brainwave frequency to therapeutic color
     * Based on neurofeedback research and light therapy
     */
    static juce::Colour brainwaveToColour(float hz)
    {
        if (hz < 4.0f)       return juce::Colour(0xFF800080);  // Delta - Deep Purple
        else if (hz < 8.0f)  return juce::Colour(0xFF4169E1);  // Theta - Royal Blue
        else if (hz < 12.0f) return juce::Colour(0xFF00CED1);  // Alpha - Teal
        else if (hz < 30.0f) return juce::Colour(0xFF32CD32);  // Beta - Lime Green
        else                 return juce::Colour(0xFFFFD700);  // Gamma - Gold
    }

private:
    static juce::Colour wavelengthToRGB(float wavelength)
    {
        float r = 0, g = 0, b = 0;

        if (wavelength >= 380 && wavelength < 440)
        {
            r = -(wavelength - 440) / (440 - 380);
            b = 1.0f;
        }
        else if (wavelength >= 440 && wavelength < 490)
        {
            g = (wavelength - 440) / (490 - 440);
            b = 1.0f;
        }
        else if (wavelength >= 490 && wavelength < 510)
        {
            g = 1.0f;
            b = -(wavelength - 510) / (510 - 490);
        }
        else if (wavelength >= 510 && wavelength < 580)
        {
            r = (wavelength - 510) / (580 - 510);
            g = 1.0f;
        }
        else if (wavelength >= 580 && wavelength < 645)
        {
            r = 1.0f;
            g = -(wavelength - 645) / (645 - 580);
        }
        else if (wavelength >= 645 && wavelength <= 750)
        {
            r = 1.0f;
        }

        // Intensity falloff at edges
        float factor = 1.0f;
        if (wavelength >= 380 && wavelength < 420)
            factor = 0.3f + 0.7f * (wavelength - 380) / (420 - 380);
        else if (wavelength >= 700 && wavelength <= 750)
            factor = 0.3f + 0.7f * (750 - wavelength) / (750 - 700);

        return juce::Colour::fromFloatRGBA(r * factor, g * factor, b * factor, 1.0f);
    }
};

//==============================================================================
// Sacred Geometry Generator (Cymatics, Fibonacci, Golden Ratio)
//==============================================================================

class SacredGeometry
{
public:
    static constexpr float GoldenRatio = 1.6180339887498948482f;
    static constexpr float Pi = 3.14159265358979323846f;

    /**
     * Generate Fibonacci spiral points
     */
    static std::vector<juce::Point<float>> fibonacciSpiral(int numPoints, float scale = 1.0f)
    {
        std::vector<juce::Point<float>> points;
        points.reserve(numPoints);

        const float goldenAngle = Pi * (3.0f - std::sqrt(5.0f));  // ~137.5 degrees

        for (int i = 0; i < numPoints; ++i)
        {
            float r = scale * std::sqrt(static_cast<float>(i));
            float theta = i * goldenAngle;
            points.push_back({r * std::cos(theta), r * std::sin(theta)});
        }

        return points;
    }

    /**
     * Generate Flower of Life pattern
     */
    static std::vector<juce::Point<float>> flowerOfLife(float radius, int rings = 3)
    {
        std::vector<juce::Point<float>> centers;
        centers.push_back({0.0f, 0.0f});  // Center circle

        for (int ring = 1; ring <= rings; ++ring)
        {
            int numCircles = ring * 6;
            float ringRadius = radius * ring;

            for (int i = 0; i < numCircles; ++i)
            {
                float angle = (2.0f * Pi * i) / numCircles;
                centers.push_back({ringRadius * std::cos(angle), ringRadius * std::sin(angle)});
            }
        }

        return centers;
    }

    /**
     * Generate Chladni pattern (cymatics) for given frequency
     * Based on: Ernst Chladni's acoustic experiments
     */
    static float chladniPattern(float x, float y, float m, float n)
    {
        // Chladni equation: cos(m*pi*x) * cos(n*pi*y) - cos(n*pi*x) * cos(m*pi*y)
        float mx = std::cos(m * Pi * x);
        float ny = std::cos(n * Pi * y);
        float nx = std::cos(n * Pi * x);
        float my = std::cos(m * Pi * y);

        return mx * ny - nx * my;
    }

    /**
     * Map audio frequency to Chladni pattern parameters
     */
    static std::pair<float, float> frequencyToChladni(float frequencyHz)
    {
        // Lower frequencies = simpler patterns, higher = complex
        float logFreq = std::log2(frequencyHz / 100.0f);
        float m = 1.0f + std::fmod(logFreq, 5.0f);
        float n = 1.0f + std::fmod(logFreq * GoldenRatio, 5.0f);
        return {m, n};
    }
};

//==============================================================================
// VHS/Retro Effect Generators
//==============================================================================

class RetroEffects
{
public:
    /**
     * VHS tracking distortion (horizontal offset based on scanline)
     */
    static float vhsTrackingOffset(int scanline, float time, float intensity = 1.0f)
    {
        float noise = std::sin(scanline * 0.1f + time * 10.0f) *
                      std::sin(scanline * 0.03f + time * 3.0f);
        return noise * intensity * 5.0f;  // Max 5 pixel offset
    }

    /**
     * Scanline effect (alternate line darkening)
     */
    static float scanlineMultiplier(int y, float intensity = 0.1f)
    {
        return (y % 2 == 0) ? 1.0f : (1.0f - intensity);
    }

    /**
     * CRT curvature (barrel distortion)
     */
    static juce::Point<float> crtDistort(float x, float y, float amount = 0.1f)
    {
        // Normalize to -1 to 1
        float nx = x * 2.0f - 1.0f;
        float ny = y * 2.0f - 1.0f;

        float r2 = nx * nx + ny * ny;
        float distortion = 1.0f + r2 * amount;

        return {(nx * distortion + 1.0f) * 0.5f, (ny * distortion + 1.0f) * 0.5f};
    }

    /**
     * Chromatic aberration offsets
     */
    static std::array<juce::Point<float>, 3> chromaticAberration(float x, float y, float amount = 1.0f)
    {
        float dx = (x - 0.5f) * amount * 0.02f;
        float dy = (y - 0.5f) * amount * 0.02f;

        return {{
            {x - dx, y - dy},   // Red channel (shifted outward)
            {x, y},              // Green channel (center)
            {x + dx, y + dy}     // Blue channel (shifted opposite)
        }};
    }

    /**
     * Glitch block effect (random rectangular artifacts)
     */
    struct GlitchBlock
    {
        juce::Rectangle<float> bounds;
        juce::Point<float> offset;
        float intensity = 0.0f;
    };

    static std::vector<GlitchBlock> generateGlitchBlocks(float width, float height,
                                                          int numBlocks, float intensity)
    {
        std::vector<GlitchBlock> blocks;
        blocks.reserve(numBlocks);

        for (int i = 0; i < numBlocks; ++i)
        {
            if (static_cast<float>(std::rand()) / RAND_MAX > intensity)
                continue;

            GlitchBlock block;
            block.bounds = {
                (static_cast<float>(std::rand()) / RAND_MAX) * width,
                (static_cast<float>(std::rand()) / RAND_MAX) * height,
                (static_cast<float>(std::rand()) / RAND_MAX) * width * 0.3f + 10.0f,
                (static_cast<float>(std::rand()) / RAND_MAX) * 20.0f + 2.0f
            };
            block.offset = {
                (static_cast<float>(std::rand()) / RAND_MAX - 0.5f) * 50.0f,
                0.0f
            };
            block.intensity = static_cast<float>(std::rand()) / RAND_MAX;
            blocks.push_back(block);
        }

        return blocks;
    }
};

//==============================================================================
// Retro Grid Generator (Tron-style perspective grid)
//==============================================================================

class RetroGrid
{
public:
    struct GridParams
    {
        int horizontalLines = 20;
        int verticalLines = 30;
        float horizonY = 0.4f;        // 0-1, where horizon sits
        float perspectiveStrength = 2.0f;
        float scrollSpeed = 0.5f;     // Grid movement speed
        juce::Colour lineColor = juce::Colour(VaporwaveColors::NeonCyan);
        float lineWidth = 1.5f;
        float glowRadius = 3.0f;
    };

    /**
     * Generate perspective grid lines for vaporwave sun/horizon aesthetic
     */
    static std::vector<juce::Line<float>> generateGrid(float width, float height,
                                                        const GridParams& params,
                                                        float time)
    {
        std::vector<juce::Line<float>> lines;

        float horizonY = height * params.horizonY;

        // Vertical lines (converging to vanishing point)
        float vanishX = width * 0.5f;
        float vanishY = horizonY;

        for (int i = 0; i <= params.verticalLines; ++i)
        {
            float t = static_cast<float>(i) / params.verticalLines;
            float bottomX = t * width;
            lines.push_back(juce::Line<float>(vanishX, vanishY, bottomX, height));
        }

        // Horizontal lines (with perspective and scrolling)
        float scrollOffset = std::fmod(time * params.scrollSpeed, 1.0f);

        for (int i = 0; i <= params.horizontalLines; ++i)
        {
            float t = (static_cast<float>(i) + scrollOffset) / params.horizontalLines;
            // Exponential spacing for perspective
            float y = horizonY + std::pow(t, params.perspectiveStrength) * (height - horizonY);

            if (y <= height)
            {
                lines.push_back(juce::Line<float>(0, y, width, y));
            }
        }

        return lines;
    }
};

//==============================================================================
// Vaporwave Sun Generator
//==============================================================================

class VaporwaveSun
{
public:
    struct SunParams
    {
        float centerX = 0.5f;
        float centerY = 0.35f;
        float radius = 0.25f;
        int numStripes = 8;
        float stripeGap = 0.02f;
        std::array<juce::Colour, 3> gradientColors = {{
            juce::Colour(0xFFFFD700),  // Top - Gold
            juce::Colour(0xFFFF6347),  // Middle - Tomato
            juce::Colour(0xFFFF1493)   // Bottom - Deep Pink
        }};
    };

    /**
     * Generate sun with horizontal stripe cutouts (classic vaporwave aesthetic)
     */
    static void paint(juce::Graphics& g, float width, float height, const SunParams& params)
    {
        float cx = width * params.centerX;
        float cy = height * params.centerY;
        float r = std::min(width, height) * params.radius;

        // Create gradient
        juce::ColourGradient gradient(params.gradientColors[0], cx, cy - r,
                                       params.gradientColors[2], cx, cy + r, false);
        gradient.addColour(0.5, params.gradientColors[1]);

        g.setGradientFill(gradient);

        // Draw sun with stripe cutouts
        juce::Path sunPath;
        sunPath.addEllipse(cx - r, cy - r, r * 2, r * 2);

        // Subtract horizontal stripes from bottom half
        float stripeHeight = r * 2 / (params.numStripes * 2);
        for (int i = 0; i < params.numStripes; ++i)
        {
            float y = cy + i * stripeHeight * 2;
            if (y > cy)  // Only in bottom half
            {
                juce::Rectangle<float> stripe(cx - r * 1.5f, y,
                                               r * 3, stripeHeight * params.stripeGap);
                sunPath.addRectangle(stripe);
            }
        }

        g.fillPath(sunPath, juce::AffineTransform());
    }
};

//==============================================================================
// Animation Timing Functions (Easing)
//==============================================================================

class Easing
{
public:
    static float linear(float t) { return t; }

    static float easeInQuad(float t) { return t * t; }
    static float easeOutQuad(float t) { return t * (2 - t); }
    static float easeInOutQuad(float t)
    {
        return t < 0.5f ? 2 * t * t : -1 + (4 - 2 * t) * t;
    }

    static float easeInCubic(float t) { return t * t * t; }
    static float easeOutCubic(float t) { return (--t) * t * t + 1; }

    static float easeInExpo(float t)
    {
        return t == 0 ? 0 : std::pow(2, 10 * (t - 1));
    }
    static float easeOutExpo(float t)
    {
        return t == 1 ? 1 : 1 - std::pow(2, -10 * t);
    }

    static float easeInElastic(float t)
    {
        const float c4 = (2 * SacredGeometry::Pi) / 3;
        return t == 0 ? 0 : t == 1 ? 1 :
               -std::pow(2, 10 * t - 10) * std::sin((t * 10 - 10.75f) * c4);
    }

    static float easeOutElastic(float t)
    {
        const float c4 = (2 * SacredGeometry::Pi) / 3;
        return t == 0 ? 0 : t == 1 ? 1 :
               std::pow(2, -10 * t) * std::sin((t * 10 - 0.75f) * c4) + 1;
    }

    static float easeOutBounce(float t)
    {
        const float n1 = 7.5625f;
        const float d1 = 2.75f;

        if (t < 1 / d1)
            return n1 * t * t;
        else if (t < 2 / d1)
            return n1 * (t -= 1.5f / d1) * t + 0.75f;
        else if (t < 2.5f / d1)
            return n1 * (t -= 2.25f / d1) * t + 0.9375f;
        else
            return n1 * (t -= 2.625f / d1) * t + 0.984375f;
    }
};

}  // namespace Echoel::Design
