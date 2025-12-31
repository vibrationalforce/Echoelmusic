#pragma once

/*
 * EchoelAIVisualGen.h
 * Ralph Wiggum Genius Loop Mode - AI Visual/Laser Pattern Generator
 *
 * Ultra-optimized AI-powered visual pattern generation for laser shows,
 * LED arrays, and visual displays with bio-reactive integration.
 */

#include <atomic>
#include <vector>
#include <array>
#include <memory>
#include <functional>
#include <string>
#include <cmath>
#include <algorithm>
#include <random>
#include <complex>

namespace Echoel {
namespace AI {

// ============================================================================
// Visual Constants & Types
// ============================================================================

struct Vec2 {
    float x = 0.0f;
    float y = 0.0f;

    Vec2() = default;
    Vec2(float x_, float y_) : x(x_), y(y_) {}

    Vec2 operator+(const Vec2& o) const { return {x + o.x, y + o.y}; }
    Vec2 operator-(const Vec2& o) const { return {x - o.x, y - o.y}; }
    Vec2 operator*(float s) const { return {x * s, y * s}; }

    float length() const { return std::sqrt(x * x + y * y); }
    Vec2 normalized() const {
        float len = length();
        return len > 0.0001f ? Vec2{x / len, y / len} : Vec2{0, 0};
    }

    static Vec2 fromAngle(float angle) {
        return {std::cos(angle), std::sin(angle)};
    }
};

struct Vec3 {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    Vec3() = default;
    Vec3(float x_, float y_, float z_) : x(x_), y(y_), z(z_) {}

    Vec3 operator+(const Vec3& o) const { return {x + o.x, y + o.y, z + o.z}; }
    Vec3 operator-(const Vec3& o) const { return {x - o.x, y - o.y, z - o.z}; }
    Vec3 operator*(float s) const { return {x * s, y * s, z * s}; }

    float length() const { return std::sqrt(x * x + y * y + z * z); }
};

struct Color {
    float r = 1.0f;
    float g = 1.0f;
    float b = 1.0f;
    float a = 1.0f;

    Color() = default;
    Color(float r_, float g_, float b_, float a_ = 1.0f)
        : r(r_), g(g_), b(b_), a(a_) {}

    Color operator*(float s) const { return {r * s, g * s, b * s, a}; }
    Color operator+(const Color& o) const {
        return {r + o.r, g + o.g, b + o.b, (a + o.a) * 0.5f};
    }

    static Color lerp(const Color& a, const Color& b, float t) {
        return {
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t
        };
    }

    static Color fromHSV(float h, float s, float v) {
        float c = v * s;
        float x = c * (1.0f - std::abs(std::fmod(h / 60.0f, 2.0f) - 1.0f));
        float m = v - c;

        float r, g, b;
        if (h < 60) { r = c; g = x; b = 0; }
        else if (h < 120) { r = x; g = c; b = 0; }
        else if (h < 180) { r = 0; g = c; b = x; }
        else if (h < 240) { r = 0; g = x; b = c; }
        else if (h < 300) { r = x; g = 0; b = c; }
        else { r = c; g = 0; b = x; }

        return {r + m, g + m, b + m, 1.0f};
    }
};

// ============================================================================
// Enumerations
// ============================================================================

enum class VisualMode {
    LaserShow,
    LEDArray,
    ProjectorMapping,
    DMXLighting,
    ParticleSystem,
    VectorGraphics,
    VolumetricDisplay,
    HolographicSimulation
};

enum class PatternType {
    // Geometric
    Spiral,
    Star,
    Mandala,
    SacredGeometry,
    LissajousCurve,
    Rose,
    Polygon,
    Fractal,

    // Dynamic
    Wave,
    Ripple,
    Pulse,
    Vortex,
    Explosion,
    Flow,

    // Organic
    Breathing,
    Heartbeat,
    Neural,
    Organic,
    Cellular,

    // Audio-reactive
    Spectrum,
    Waveform,
    BeatSync,
    FrequencyBands,

    // Abstract
    Noise,
    Kaleidoscope,
    Morph,
    Generative
};

enum class AnimationType {
    Static,
    Rotate,
    Scale,
    Translate,
    Morph,
    Pulse,
    Wave,
    Particle,
    Physics,
    Generative
};

enum class ColorScheme {
    Monochrome,
    Complementary,
    Triadic,
    Analogous,
    Rainbow,
    Fire,
    Ice,
    Aurora,
    Chakra,
    BioReactive,
    Custom
};

enum class BrainwaveVisualMode {
    Alpha_Calm,
    Beta_Focus,
    Theta_Dream,
    Delta_Deep,
    Gamma_Peak,
    Coherent,
    Adaptive
};

// ============================================================================
// Laser Point Data
// ============================================================================

struct LaserPoint {
    Vec2 position;          // -1 to 1 normalized
    Color color;
    float intensity = 1.0f;
    bool blanked = false;   // Beam off during movement

    LaserPoint() = default;
    LaserPoint(Vec2 pos, Color col, float intens = 1.0f)
        : position(pos), color(col), intensity(intens), blanked(false) {}
};

struct LaserFrame {
    std::vector<LaserPoint> points;
    float duration = 1.0f / 30.0f;  // Frame duration in seconds
    uint32_t timestamp = 0;

    void addPoint(Vec2 pos, Color col, float intens = 1.0f) {
        points.emplace_back(pos, col, intens);
    }

    void addBlankMove(Vec2 from, Vec2 to) {
        LaserPoint blank;
        blank.position = from;
        blank.blanked = true;
        points.push_back(blank);

        blank.position = to;
        points.push_back(blank);
    }
};

// ============================================================================
// Pattern Generators
// ============================================================================

class PatternGenerator {
public:
    virtual ~PatternGenerator() = default;
    virtual void generate(LaserFrame& frame, float time, float intensity) = 0;
    virtual void setBioState(float relaxation, float arousal, float focus) {
        relaxation_ = relaxation;
        arousal_ = arousal;
        focus_ = focus;
    }

protected:
    float relaxation_ = 0.5f;
    float arousal_ = 0.5f;
    float focus_ = 0.5f;
};

class SpiralPattern : public PatternGenerator {
public:
    void generate(LaserFrame& frame, float time, float intensity) override {
        const int numPoints = 200;
        const float revolutions = 3.0f + relaxation_ * 2.0f;
        const float speed = 0.5f + arousal_;

        for (int i = 0; i < numPoints; ++i) {
            float t = static_cast<float>(i) / numPoints;
            float angle = t * revolutions * 6.28318f + time * speed;
            float radius = t * 0.8f;

            Vec2 pos(
                std::cos(angle) * radius,
                std::sin(angle) * radius
            );

            float hue = std::fmod(t * 360.0f + time * 50.0f, 360.0f);
            Color col = Color::fromHSV(hue, 0.8f, intensity);

            frame.addPoint(pos, col, intensity * (0.5f + t * 0.5f));
        }
    }
};

class MandalaPattern : public PatternGenerator {
public:
    void generate(LaserFrame& frame, float time, float intensity) override {
        const int symmetry = 6 + static_cast<int>(focus_ * 6);
        const int layerPoints = 50;
        const int numLayers = 4;

        for (int layer = 0; layer < numLayers; ++layer) {
            float layerRadius = 0.2f + layer * 0.2f;
            float layerPhase = time * (0.3f + layer * 0.1f);

            for (int sym = 0; sym < symmetry; ++sym) {
                float baseAngle = sym * 6.28318f / symmetry + layerPhase;

                for (int p = 0; p < layerPoints; ++p) {
                    float t = static_cast<float>(p) / layerPoints;
                    float modRadius = layerRadius * (1.0f + 0.3f *
                        std::sin(t * 12.0f + time * 2.0f));

                    float angle = baseAngle + t * 6.28318f / symmetry;

                    Vec2 pos(
                        std::cos(angle) * modRadius,
                        std::sin(angle) * modRadius
                    );

                    float hue = std::fmod(layer * 60.0f + time * 20.0f, 360.0f);
                    Color col = Color::fromHSV(hue, 0.9f, intensity);

                    frame.addPoint(pos, col, intensity);
                }
            }
        }
    }
};

class LissajousPattern : public PatternGenerator {
public:
    void generate(LaserFrame& frame, float time, float intensity) override {
        const int numPoints = 300;

        // Frequencies based on bio state
        float freqA = 3.0f + relaxation_ * 2.0f;
        float freqB = 4.0f + arousal_ * 3.0f;
        float phase = focus_ * 3.14159f;

        for (int i = 0; i < numPoints; ++i) {
            float t = static_cast<float>(i) / numPoints * 6.28318f;

            Vec2 pos(
                0.8f * std::sin(freqA * t + time),
                0.8f * std::sin(freqB * t + phase + time * 0.7f)
            );

            float hue = std::fmod(t * 57.3f + time * 30.0f, 360.0f);
            Color col = Color::fromHSV(hue, 0.85f, intensity);

            frame.addPoint(pos, col, intensity);
        }
    }
};

class SacredGeometryPattern : public PatternGenerator {
public:
    void generate(LaserFrame& frame, float time, float intensity) override {
        // Flower of Life pattern
        const float mainRadius = 0.3f;
        const int numCircles = 7;

        // Central circle
        generateCircle(frame, Vec2(0, 0), mainRadius, time, intensity, 0.0f);

        // Surrounding circles
        for (int i = 0; i < 6; ++i) {
            float angle = i * 6.28318f / 6 + time * 0.1f;
            Vec2 center(
                std::cos(angle) * mainRadius,
                std::sin(angle) * mainRadius
            );
            generateCircle(frame, center, mainRadius, time, intensity,
                          i * 60.0f);
        }
    }

private:
    void generateCircle(LaserFrame& frame, Vec2 center, float radius,
                        float time, float intensity, float hueOffset) {
        const int numPoints = 60;

        for (int i = 0; i <= numPoints; ++i) {
            float angle = static_cast<float>(i) / numPoints * 6.28318f;
            Vec2 pos(
                center.x + std::cos(angle) * radius,
                center.y + std::sin(angle) * radius
            );

            float hue = std::fmod(hueOffset + time * 20.0f, 360.0f);
            Color col = Color::fromHSV(hue, 0.7f, intensity);

            frame.addPoint(pos, col, intensity);
        }
    }
};

class FractalPattern : public PatternGenerator {
public:
    void generate(LaserFrame& frame, float time, float intensity) override {
        // Simple recursive tree fractal
        int depth = 4 + static_cast<int>(focus_ * 2);
        float angle = -1.5708f; // Start pointing up
        float length = 0.4f;

        Vec2 start(0, -0.8f);
        generateBranch(frame, start, angle, length, depth, time, intensity);
    }

private:
    void generateBranch(LaserFrame& frame, Vec2 start, float angle,
                        float length, int depth, float time, float intensity) {
        if (depth == 0 || length < 0.01f) return;

        Vec2 end = start + Vec2::fromAngle(angle) * length;

        // Draw branch
        const int segments = 10;
        for (int i = 0; i <= segments; ++i) {
            float t = static_cast<float>(i) / segments;
            Vec2 pos = start + (end - start) * t;

            float hue = std::fmod(depth * 40.0f + time * 30.0f, 360.0f);
            Color col = Color::fromHSV(hue, 0.8f, intensity);

            frame.addPoint(pos, col, intensity * (0.5f + depth * 0.1f));
        }

        // Recursive branches
        float spread = 0.4f + relaxation_ * 0.3f + std::sin(time) * 0.1f;
        float newLength = length * (0.65f + arousal_ * 0.1f);

        generateBranch(frame, end, angle - spread, newLength, depth - 1,
                      time, intensity);
        generateBranch(frame, end, angle + spread, newLength, depth - 1,
                      time, intensity);
    }
};

class WavePattern : public PatternGenerator {
public:
    void generate(LaserFrame& frame, float time, float intensity) override {
        const int numPoints = 150;
        const int numWaves = 3;

        for (int wave = 0; wave < numWaves; ++wave) {
            float yOffset = (wave - 1) * 0.4f;
            float frequency = 2.0f + wave + arousal_ * 2.0f;
            float amplitude = 0.3f * relaxation_;
            float phase = wave * 2.0f + time * (1.0f + wave * 0.5f);

            for (int i = 0; i < numPoints; ++i) {
                float t = static_cast<float>(i) / numPoints;
                float x = t * 2.0f - 1.0f;
                float y = yOffset + amplitude *
                         std::sin(frequency * x * 3.14159f + phase);

                Vec2 pos(x, y);

                float hue = std::fmod(wave * 120.0f + t * 60.0f + time * 40.0f, 360.0f);
                Color col = Color::fromHSV(hue, 0.85f, intensity);

                frame.addPoint(pos, col, intensity);
            }
        }
    }
};

class NeuralPattern : public PatternGenerator {
public:
    NeuralPattern() {
        // Initialize neural nodes
        std::mt19937 rng(42);
        std::uniform_real_distribution<float> dist(-0.7f, 0.7f);

        for (int i = 0; i < MAX_NODES; ++i) {
            nodes_[i].position = Vec2(dist(rng), dist(rng));
            nodes_[i].activation = 0.0f;
            nodes_[i].phase = dist(rng) * 3.14159f;
        }

        // Create connections
        for (int i = 0; i < MAX_NODES; ++i) {
            for (int j = i + 1; j < MAX_NODES; ++j) {
                float distance = (nodes_[i].position - nodes_[j].position).length();
                if (distance < 0.5f) {
                    connections_.push_back({i, j, 1.0f - distance * 2.0f});
                }
            }
        }
    }

    void generate(LaserFrame& frame, float time, float intensity) override {
        // Update activations
        for (int i = 0; i < MAX_NODES; ++i) {
            nodes_[i].activation = 0.5f + 0.5f *
                std::sin(time * 2.0f + nodes_[i].phase);

            // Bio-reactive modulation
            nodes_[i].activation *= (0.5f + focus_ * 0.5f);
        }

        // Draw connections
        for (const auto& conn : connections_) {
            float avgActivation = (nodes_[conn.from].activation +
                                  nodes_[conn.to].activation) * 0.5f;

            if (avgActivation < 0.3f) continue;

            const int segments = 15;
            for (int i = 0; i <= segments; ++i) {
                float t = static_cast<float>(i) / segments;
                Vec2 pos = nodes_[conn.from].position * (1.0f - t) +
                          nodes_[conn.to].position * t;

                float pulse = 0.5f + 0.5f * std::sin(time * 5.0f - t * 10.0f);
                float hue = std::fmod(120.0f + avgActivation * 60.0f + time * 30.0f, 360.0f);
                Color col = Color::fromHSV(hue, 0.7f, avgActivation * pulse);

                frame.addPoint(pos, col, intensity * avgActivation * conn.strength);
            }
        }

        // Draw nodes
        for (int i = 0; i < MAX_NODES; ++i) {
            if (nodes_[i].activation > 0.4f) {
                drawNode(frame, nodes_[i].position, nodes_[i].activation,
                        time, intensity);
            }
        }
    }

private:
    struct Node {
        Vec2 position;
        float activation;
        float phase;
    };

    struct Connection {
        int from;
        int to;
        float strength;
    };

    void drawNode(LaserFrame& frame, Vec2 center, float activation,
                  float time, float intensity) {
        const int numPoints = 16;
        float radius = 0.03f + activation * 0.02f;

        for (int i = 0; i <= numPoints; ++i) {
            float angle = static_cast<float>(i) / numPoints * 6.28318f;
            Vec2 pos(
                center.x + std::cos(angle) * radius,
                center.y + std::sin(angle) * radius
            );

            float hue = std::fmod(180.0f + activation * 60.0f + time * 50.0f, 360.0f);
            Color col = Color::fromHSV(hue, 0.9f, activation);

            frame.addPoint(pos, col, intensity * activation);
        }
    }

    static constexpr int MAX_NODES = 20;
    std::array<Node, MAX_NODES> nodes_;
    std::vector<Connection> connections_;
};

class SpectrumPattern : public PatternGenerator {
public:
    void setAudioData(const float* spectrum, size_t numBands) {
        numBands_ = std::min(numBands, static_cast<size_t>(MAX_BANDS));
        std::copy(spectrum, spectrum + numBands_, spectrum_.begin());
    }

    void generate(LaserFrame& frame, float time, float intensity) override {
        const float barWidth = 1.6f / numBands_;
        const float maxHeight = 0.8f;

        for (size_t i = 0; i < numBands_; ++i) {
            float x = -0.8f + i * barWidth + barWidth * 0.5f;
            float height = spectrum_[i] * maxHeight;

            // Draw bar
            const int segments = 20;
            for (int j = 0; j <= segments; ++j) {
                float t = static_cast<float>(j) / segments;
                float y = -0.8f + t * height;

                Vec2 pos(x, y);

                float hue = std::fmod(i * 10.0f + t * 60.0f + time * 30.0f, 360.0f);
                float sat = 0.7f + spectrum_[i] * 0.3f;
                Color col = Color::fromHSV(hue, sat, intensity);

                frame.addPoint(pos, col, intensity * (0.3f + spectrum_[i] * 0.7f));
            }
        }
    }

private:
    static constexpr size_t MAX_BANDS = 64;
    std::array<float, MAX_BANDS> spectrum_{};
    size_t numBands_ = 32;
};

class HeartbeatPattern : public PatternGenerator {
public:
    void setHeartRate(float bpm) {
        heartBpm_ = bpm;
    }

    void generate(LaserFrame& frame, float time, float intensity) override {
        float beatPeriod = 60.0f / heartBpm_;
        float beatPhase = std::fmod(time, beatPeriod) / beatPeriod;

        // ECG-like waveform
        const int numPoints = 200;

        for (int i = 0; i < numPoints; ++i) {
            float t = static_cast<float>(i) / numPoints;
            float x = t * 2.0f - 1.0f;

            // Calculate ECG-like value
            float phase = std::fmod(t + beatPhase, 1.0f);
            float y = calculateECG(phase) * 0.4f;

            Vec2 pos(x, y);

            // Color based on phase (red near beat)
            float beatProximity = 1.0f - std::abs(phase - 0.15f) * 5.0f;
            beatProximity = std::max(0.0f, beatProximity);

            Color col = Color::lerp(
                Color(0.2f, 0.8f, 1.0f),  // Cyan
                Color(1.0f, 0.2f, 0.3f),   // Red
                beatProximity
            );

            frame.addPoint(pos, col, intensity * (0.5f + beatProximity * 0.5f));
        }

        // Heart symbol at beat
        if (beatPhase < 0.1f) {
            float pulseScale = 1.0f + (1.0f - beatPhase / 0.1f) * 0.3f;
            drawHeart(frame, Vec2(0, 0.5f), 0.15f * pulseScale,
                     time, intensity);
        }
    }

private:
    float calculateECG(float phase) {
        // Simplified ECG waveform
        if (phase < 0.1f) {
            return 0.1f * std::sin(phase * 31.4159f); // P wave
        } else if (phase < 0.15f) {
            return 0.0f;
        } else if (phase < 0.17f) {
            return -0.2f; // Q
        } else if (phase < 0.20f) {
            return 1.0f * (1.0f - std::abs(phase - 0.185f) * 66.7f); // R
        } else if (phase < 0.23f) {
            return -0.15f; // S
        } else if (phase < 0.35f) {
            return 0.0f;
        } else if (phase < 0.45f) {
            return 0.25f * std::sin((phase - 0.35f) * 31.4159f); // T wave
        }
        return 0.0f;
    }

    void drawHeart(LaserFrame& frame, Vec2 center, float size,
                   float time, float intensity) {
        const int numPoints = 50;

        for (int i = 0; i <= numPoints; ++i) {
            float t = static_cast<float>(i) / numPoints * 6.28318f;

            // Heart parametric equation
            float x = 16.0f * std::pow(std::sin(t), 3);
            float y = 13.0f * std::cos(t) - 5.0f * std::cos(2*t) -
                     2.0f * std::cos(3*t) - std::cos(4*t);

            Vec2 pos(
                center.x + x * size / 16.0f,
                center.y - y * size / 16.0f
            );

            Color col(1.0f, 0.2f, 0.3f);
            frame.addPoint(pos, col, intensity);
        }
    }

    float heartBpm_ = 72.0f;
};

// ============================================================================
// Color Palette System
// ============================================================================

class ColorPalette {
public:
    void setScheme(ColorScheme scheme) {
        scheme_ = scheme;
        generatePalette();
    }

    void setBaseHue(float hue) {
        baseHue_ = hue;
        generatePalette();
    }

    Color getColor(float t) const {
        if (colors_.empty()) return Color(1, 1, 1);

        float scaled = t * (colors_.size() - 1);
        size_t idx = static_cast<size_t>(scaled);
        float frac = scaled - idx;

        if (idx >= colors_.size() - 1) return colors_.back();
        return Color::lerp(colors_[idx], colors_[idx + 1], frac);
    }

    Color getColorForBioState(float relaxation, float arousal, float focus) const {
        // Map bio states to color
        float hue = 180.0f * relaxation;  // Blue when relaxed
        hue += 60.0f * arousal;           // Shift to yellow when aroused
        hue = std::fmod(hue, 360.0f);

        float saturation = 0.5f + focus * 0.5f;
        float value = 0.7f + arousal * 0.3f;

        return Color::fromHSV(hue, saturation, value);
    }

private:
    void generatePalette() {
        colors_.clear();

        switch (scheme_) {
            case ColorScheme::Monochrome:
                for (int i = 0; i < 5; ++i) {
                    float value = 0.2f + i * 0.2f;
                    colors_.push_back(Color::fromHSV(baseHue_, 0.8f, value));
                }
                break;

            case ColorScheme::Complementary:
                colors_.push_back(Color::fromHSV(baseHue_, 0.8f, 1.0f));
                colors_.push_back(Color::fromHSV(std::fmod(baseHue_ + 180, 360), 0.8f, 1.0f));
                break;

            case ColorScheme::Triadic:
                for (int i = 0; i < 3; ++i) {
                    colors_.push_back(Color::fromHSV(
                        std::fmod(baseHue_ + i * 120, 360), 0.8f, 1.0f));
                }
                break;

            case ColorScheme::Rainbow:
                for (int i = 0; i < 7; ++i) {
                    colors_.push_back(Color::fromHSV(i * 51.4f, 0.9f, 1.0f));
                }
                break;

            case ColorScheme::Fire:
                colors_.push_back(Color(0.1f, 0.0f, 0.0f));   // Dark red
                colors_.push_back(Color(0.8f, 0.1f, 0.0f));   // Red
                colors_.push_back(Color(1.0f, 0.5f, 0.0f));   // Orange
                colors_.push_back(Color(1.0f, 0.9f, 0.2f));   // Yellow
                colors_.push_back(Color(1.0f, 1.0f, 0.8f));   // White
                break;

            case ColorScheme::Ice:
                colors_.push_back(Color(0.0f, 0.0f, 0.2f));   // Deep blue
                colors_.push_back(Color(0.0f, 0.3f, 0.6f));   // Blue
                colors_.push_back(Color(0.2f, 0.6f, 0.9f));   // Light blue
                colors_.push_back(Color(0.6f, 0.9f, 1.0f));   // Cyan
                colors_.push_back(Color(1.0f, 1.0f, 1.0f));   // White
                break;

            case ColorScheme::Aurora:
                colors_.push_back(Color(0.0f, 0.2f, 0.1f));   // Dark green
                colors_.push_back(Color(0.0f, 0.8f, 0.3f));   // Green
                colors_.push_back(Color(0.2f, 0.9f, 0.7f));   // Cyan-green
                colors_.push_back(Color(0.5f, 0.3f, 0.9f));   // Purple
                colors_.push_back(Color(0.9f, 0.2f, 0.5f));   // Pink
                break;

            case ColorScheme::Chakra:
                colors_.push_back(Color(0.8f, 0.0f, 0.0f));   // Root - Red
                colors_.push_back(Color(1.0f, 0.5f, 0.0f));   // Sacral - Orange
                colors_.push_back(Color(1.0f, 1.0f, 0.0f));   // Solar - Yellow
                colors_.push_back(Color(0.0f, 0.8f, 0.0f));   // Heart - Green
                colors_.push_back(Color(0.0f, 0.7f, 1.0f));   // Throat - Blue
                colors_.push_back(Color(0.3f, 0.0f, 0.8f));   // Third Eye - Indigo
                colors_.push_back(Color(0.6f, 0.0f, 0.8f));   // Crown - Violet
                break;

            default:
                colors_.push_back(Color(1, 1, 1));
                break;
        }
    }

    ColorScheme scheme_ = ColorScheme::Rainbow;
    float baseHue_ = 0.0f;
    std::vector<Color> colors_;
};

// ============================================================================
// Animation Controller
// ============================================================================

class AnimationController {
public:
    struct Keyframe {
        float time;
        float value;
        float easeIn = 0.0f;
        float easeOut = 0.0f;
    };

    void addKeyframe(float time, float value) {
        keyframes_.push_back({time, value, 0.0f, 0.0f});
        std::sort(keyframes_.begin(), keyframes_.end(),
                  [](const auto& a, const auto& b) { return a.time < b.time; });
    }

    float getValue(float time) const {
        if (keyframes_.empty()) return 0.0f;
        if (keyframes_.size() == 1) return keyframes_[0].value;

        // Find surrounding keyframes
        size_t next = 0;
        for (size_t i = 0; i < keyframes_.size(); ++i) {
            if (keyframes_[i].time > time) {
                next = i;
                break;
            }
            next = i;
        }

        if (next == 0) return keyframes_[0].value;
        if (next >= keyframes_.size()) return keyframes_.back().value;

        const auto& k0 = keyframes_[next - 1];
        const auto& k1 = keyframes_[next];

        float t = (time - k0.time) / (k1.time - k0.time);

        // Ease in/out
        t = smoothstep(t);

        return k0.value + (k1.value - k0.value) * t;
    }

    void setLooping(bool loop) { looping_ = loop; }
    void setDuration(float duration) { duration_ = duration; }

    float getLoopedTime(float time) const {
        if (!looping_ || duration_ <= 0.0f) return time;
        return std::fmod(time, duration_);
    }

private:
    static float smoothstep(float t) {
        return t * t * (3.0f - 2.0f * t);
    }

    std::vector<Keyframe> keyframes_;
    bool looping_ = true;
    float duration_ = 1.0f;
};

// ============================================================================
// Main AI Visual Generator
// ============================================================================

class EchoelAIVisualGen {
public:
    struct GenerationConfig {
        VisualMode mode = VisualMode::LaserShow;
        PatternType pattern = PatternType::Spiral;
        ColorScheme colorScheme = ColorScheme::Rainbow;
        AnimationType animation = AnimationType::Rotate;

        float intensity = 0.8f;
        float speed = 1.0f;
        float complexity = 0.5f;
        float smoothness = 0.7f;

        int targetPointsPerFrame = 500;
        float frameRate = 30.0f;

        // Bio-reactive
        bool bioReactive = true;
        float bioSensitivity = 0.5f;
        BrainwaveVisualMode brainwaveMode = BrainwaveVisualMode::Adaptive;
    };

    struct BioVisualState {
        float relaxation = 0.5f;
        float arousal = 0.5f;
        float focus = 0.5f;
        float heartRate = 72.0f;
        float breathingPhase = 0.0f;

        // Brainwave band powers
        float alpha = 0.5f;
        float beta = 0.5f;
        float theta = 0.5f;
        float delta = 0.5f;
        float gamma = 0.5f;
    };

    EchoelAIVisualGen() {
        initializePatterns();
    }

    void setConfig(const GenerationConfig& config) {
        config_ = config;
        palette_.setScheme(config.colorScheme);
        selectPattern();
    }

    void setBioState(const BioVisualState& state) {
        bioState_ = state;
        if (currentPattern_) {
            currentPattern_->setBioState(state.relaxation, state.arousal, state.focus);
        }
        adaptVisualsToState();
    }

    void setAudioSpectrum(const float* spectrum, size_t numBands) {
        if (auto* specPattern = dynamic_cast<SpectrumPattern*>(currentPattern_.get())) {
            specPattern->setAudioData(spectrum, numBands);
        }
        std::copy(spectrum, spectrum + std::min(numBands, size_t(64)),
                  audioSpectrum_.begin());
    }

    LaserFrame generateFrame(float time) {
        LaserFrame frame;
        frame.timestamp = static_cast<uint32_t>(time * 1000.0f);
        frame.duration = 1.0f / config_.frameRate;

        // Apply time modulation
        float modTime = time * config_.speed;

        // Apply bio-reactive time modulation
        if (config_.bioReactive) {
            modTime *= (0.7f + bioState_.relaxation * 0.6f);
        }

        // Generate base pattern
        if (currentPattern_) {
            currentPattern_->generate(frame, modTime, config_.intensity);
        }

        // Apply animation transforms
        applyAnimation(frame, modTime);

        // Apply color palette
        applyColorPalette(frame, modTime);

        // Optimize for laser output
        optimizeForLaser(frame);

        return frame;
    }

    std::vector<LaserFrame> generateSequence(float startTime, float duration,
                                              float frameRate) {
        std::vector<LaserFrame> frames;
        size_t numFrames = static_cast<size_t>(duration * frameRate);
        frames.reserve(numFrames);

        for (size_t i = 0; i < numFrames; ++i) {
            float time = startTime + static_cast<float>(i) / frameRate;
            frames.push_back(generateFrame(time));
        }

        return frames;
    }

    // Get DMX values for lighting integration
    std::vector<uint8_t> generateDMX(float time, size_t numChannels = 512) {
        std::vector<uint8_t> dmx(numChannels, 0);

        // Map bio state to DMX channels
        // Channels 1-10: Master controls
        dmx[0] = static_cast<uint8_t>(config_.intensity * 255);
        dmx[1] = static_cast<uint8_t>(bioState_.arousal * 255);
        dmx[2] = static_cast<uint8_t>(bioState_.relaxation * 255);

        // Channels 11-20: RGB color
        Color bioColor = palette_.getColorForBioState(
            bioState_.relaxation, bioState_.arousal, bioState_.focus);
        dmx[10] = static_cast<uint8_t>(bioColor.r * 255);
        dmx[11] = static_cast<uint8_t>(bioColor.g * 255);
        dmx[12] = static_cast<uint8_t>(bioColor.b * 255);

        // Channels 21+: Audio reactive
        for (size_t i = 0; i < 32 && i + 20 < numChannels; ++i) {
            dmx[20 + i] = static_cast<uint8_t>(audioSpectrum_[i] * 255);
        }

        return dmx;
    }

    // Get LED array data
    void generateLEDArray(Color* output, size_t width, size_t height, float time) {
        for (size_t y = 0; y < height; ++y) {
            for (size_t x = 0; x < width; ++x) {
                float u = static_cast<float>(x) / width;
                float v = static_cast<float>(y) / height;

                // Create wave pattern
                float wave = std::sin(u * 6.28318f * 3.0f +
                                     v * 6.28318f * 2.0f +
                                     time * 2.0f);
                wave = (wave + 1.0f) * 0.5f;

                // Bio modulation
                wave *= (0.5f + bioState_.alpha * 0.5f);

                Color col = palette_.getColor(wave);
                col = col * config_.intensity;

                output[y * width + x] = col;
            }
        }
    }

private:
    void initializePatterns() {
        patterns_[PatternType::Spiral] = std::make_unique<SpiralPattern>();
        patterns_[PatternType::Mandala] = std::make_unique<MandalaPattern>();
        patterns_[PatternType::LissajousCurve] = std::make_unique<LissajousPattern>();
        patterns_[PatternType::SacredGeometry] = std::make_unique<SacredGeometryPattern>();
        patterns_[PatternType::Fractal] = std::make_unique<FractalPattern>();
        patterns_[PatternType::Wave] = std::make_unique<WavePattern>();
        patterns_[PatternType::Neural] = std::make_unique<NeuralPattern>();
        patterns_[PatternType::Spectrum] = std::make_unique<SpectrumPattern>();
        patterns_[PatternType::Heartbeat] = std::make_unique<HeartbeatPattern>();
    }

    void selectPattern() {
        auto it = patterns_.find(config_.pattern);
        if (it != patterns_.end()) {
            currentPattern_ = it->second.get();
        } else {
            currentPattern_ = patterns_[PatternType::Spiral].get();
        }
    }

    void adaptVisualsToState() {
        // Adapt based on brainwave mode
        switch (config_.brainwaveMode) {
            case BrainwaveVisualMode::Alpha_Calm:
                config_.speed = 0.5f + bioState_.alpha * 0.5f;
                config_.complexity = 0.3f;
                break;

            case BrainwaveVisualMode::Beta_Focus:
                config_.speed = 1.0f + bioState_.beta * 0.5f;
                config_.complexity = 0.6f;
                break;

            case BrainwaveVisualMode::Theta_Dream:
                config_.speed = 0.3f + bioState_.theta * 0.3f;
                config_.complexity = 0.7f;
                break;

            case BrainwaveVisualMode::Adaptive:
            default:
                // Blend based on dominant brainwave
                float maxWave = std::max({bioState_.alpha, bioState_.beta,
                                         bioState_.theta, bioState_.delta});
                config_.speed = 0.5f + maxWave * 0.5f;
                config_.complexity = 0.4f + bioState_.focus * 0.4f;
                break;
        }

        // Update heartbeat pattern if active
        if (auto* heartPattern = dynamic_cast<HeartbeatPattern*>(currentPattern_)) {
            heartPattern->setHeartRate(bioState_.heartRate);
        }
    }

    void applyAnimation(LaserFrame& frame, float time) {
        switch (config_.animation) {
            case AnimationType::Rotate:
                rotateFrame(frame, time * 0.5f);
                break;

            case AnimationType::Scale:
                scaleFrame(frame, 0.8f + 0.2f * std::sin(time * 2.0f));
                break;

            case AnimationType::Pulse:
                {
                    float pulse = 0.8f + 0.2f * std::sin(time * 4.0f);
                    for (auto& point : frame.points) {
                        point.intensity *= pulse;
                    }
                }
                break;

            case AnimationType::Wave:
                for (auto& point : frame.points) {
                    float wave = std::sin(point.position.x * 3.0f + time * 2.0f) * 0.1f;
                    point.position.y += wave;
                }
                break;

            default:
                break;
        }
    }

    void rotateFrame(LaserFrame& frame, float angle) {
        float cosA = std::cos(angle);
        float sinA = std::sin(angle);

        for (auto& point : frame.points) {
            float x = point.position.x;
            float y = point.position.y;
            point.position.x = x * cosA - y * sinA;
            point.position.y = x * sinA + y * cosA;
        }
    }

    void scaleFrame(LaserFrame& frame, float scale) {
        for (auto& point : frame.points) {
            point.position = point.position * scale;
        }
    }

    void applyColorPalette(LaserFrame& frame, float time) {
        size_t numPoints = frame.points.size();
        if (numPoints == 0) return;

        for (size_t i = 0; i < numPoints; ++i) {
            float t = static_cast<float>(i) / numPoints;
            t = std::fmod(t + time * 0.1f, 1.0f);

            Color palColor = palette_.getColor(t);

            // Blend with existing color
            frame.points[i].color = Color::lerp(
                frame.points[i].color, palColor, 0.7f);
        }
    }

    void optimizeForLaser(LaserFrame& frame) {
        if (frame.points.size() <= 1) return;

        // Add blank moves for jumps
        std::vector<LaserPoint> optimized;
        optimized.reserve(frame.points.size() * 1.5f);

        for (size_t i = 0; i < frame.points.size(); ++i) {
            if (i > 0) {
                float dist = (frame.points[i].position -
                             frame.points[i-1].position).length();

                // Insert blank if jump is too far
                if (dist > 0.2f) {
                    LaserPoint blank;
                    blank.position = frame.points[i-1].position;
                    blank.blanked = true;
                    optimized.push_back(blank);

                    blank.position = frame.points[i].position;
                    optimized.push_back(blank);
                }
            }

            optimized.push_back(frame.points[i]);
        }

        frame.points = std::move(optimized);

        // Limit point count
        if (frame.points.size() > static_cast<size_t>(config_.targetPointsPerFrame)) {
            std::vector<LaserPoint> reduced;
            float step = static_cast<float>(frame.points.size()) /
                        config_.targetPointsPerFrame;

            for (float i = 0; i < frame.points.size(); i += step) {
                reduced.push_back(frame.points[static_cast<size_t>(i)]);
            }

            frame.points = std::move(reduced);
        }
    }

    GenerationConfig config_;
    BioVisualState bioState_;
    ColorPalette palette_;

    std::unordered_map<PatternType, std::unique_ptr<PatternGenerator>> patterns_;
    PatternGenerator* currentPattern_ = nullptr;

    std::array<float, 64> audioSpectrum_{};
};

} // namespace AI
} // namespace Echoel
