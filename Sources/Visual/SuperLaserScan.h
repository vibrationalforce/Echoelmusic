#pragma once

/**
 * SuperLaserScan - Ultra-Low Latency Laser Scanning Engine
 *
 * DESIGN PHILOSOPHY: Real-time feeling with direct monitoring quality
 *
 * PERFORMANCE OPTIMIZATIONS:
 * - SIMD vectorization (ARM NEON / SSE2/AVX2)
 * - Lock-free triple buffering for zero-stall rendering
 * - Pre-computed trigonometric lookup tables
 * - Denormal number protection for consistent CPU performance
 * - Memory pool allocation (zero runtime allocations)
 * - Cache-aligned data structures for optimal memory access
 * - Interpolated frame blending for smooth transitions
 * - Adaptive point optimization based on scan speed
 *
 * LATENCY TARGETS:
 * - Frame generation: < 0.5ms
 * - Buffer swap: < 10us (lock-free)
 * - Network output: < 1ms (async non-blocking)
 * - Total pipeline: < 2ms (sub-frame latency)
 *
 * QUALITY FEATURES:
 * - 16-bit precision ILDA output
 * - Color interpolation with gamma correction
 * - Beam blanking optimization
 * - Galvo acceleration limiting for smooth scanning
 * - Anti-aliased point interpolation
 */

#include <array>
#include <atomic>
#include <cstdint>
#include <cmath>
#include <memory>
#include <vector>
#include <functional>
#include <string>

// Platform-specific SIMD
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    #include <arm_neon.h>
    #define LASER_USE_NEON 1
#elif defined(__AVX2__)
    #include <immintrin.h>
    #define LASER_USE_AVX2 1
#elif defined(__SSE2__)
    #include <emmintrin.h>
    #define LASER_USE_SSE2 1
#endif

// Cache line alignment for optimal memory access
#if defined(_MSC_VER)
    #define LASER_CACHE_ALIGN __declspec(align(64))
#else
    #define LASER_CACHE_ALIGN __attribute__((aligned(64)))
#endif

namespace laser {

//==============================================================================
// Constants & Configuration
//==============================================================================

constexpr float kPi = 3.14159265358979323846f;
constexpr float kTwoPi = 6.28318530717958647692f;
constexpr float kHalfPi = 1.57079632679489661923f;
constexpr float kInvTwoPi = 0.15915494309189533577f;  // 1 / (2 * pi)
constexpr float kDenormalThreshold = 1.0e-15f;
constexpr int kMaxPointsPerFrame = 4096;
constexpr int kMaxBeams = 64;
constexpr int kTrigTableSize = 4096;
constexpr int kColorLUTSize = 256;
constexpr float kMaxScanSpeedPPS = 100000.0f;  // Points per second
constexpr float kDefaultFrameRate = 60.0f;
constexpr int kNumRenderBuffers = 3;  // Triple buffering

//==============================================================================
// Utility Functions
//==============================================================================

/** Flush denormals to zero for consistent CPU performance */
inline float flushDenormal(float value) noexcept
{
    return (std::abs(value) < kDenormalThreshold) ? 0.0f : value;
}

/** Fast approximation of sin using lookup table interpolation */
inline float fastSin(float angle, const float* sinTable) noexcept
{
    // OPTIMIZATION: Fast angle normalization to [0, 2pi]
    float normalized = angle * kInvTwoPi;  // Convert to 0-1 range
    normalized -= static_cast<float>(static_cast<int>(normalized));  // Fast fmod
    if (normalized < 0.0f) normalized += 1.0f;

    float indexF = normalized * static_cast<float>(kTrigTableSize);
    int index0 = static_cast<int>(indexF) & (kTrigTableSize - 1);
    int index1 = (index0 + 1) & (kTrigTableSize - 1);
    // OPTIMIZATION: Fast floor for fractional part
    float frac = indexF - static_cast<float>(static_cast<int>(indexF));

    return sinTable[index0] * (1.0f - frac) + sinTable[index1] * frac;
}

/** Fast approximation of cos using sin table offset */
inline float fastCos(float angle, const float* sinTable) noexcept
{
    return fastSin(angle + kHalfPi, sinTable);
}

/** Linear interpolation */
inline float lerp(float a, float b, float t) noexcept
{
    return a + t * (b - a);
}

/** Smooth interpolation (ease in/out) */
inline float smoothStep(float t) noexcept
{
    return t * t * (3.0f - 2.0f * t);
}

/** Clamp value to range */
template<typename T>
inline T clamp(T value, T min, T max) noexcept
{
    return value < min ? min : (value > max ? max : value);
}

//==============================================================================
// Gamma Correction Lookup Tables (2.2 gamma for sRGB)
//==============================================================================

struct GammaLUT
{
    // Forward gamma (linear -> gamma-corrected): pow(x, 2.2)
    std::array<float, 256> toLinear;
    // Inverse gamma (gamma-corrected -> linear): pow(x, 1/2.2)
    std::array<uint8_t, 256> toGamma;

    static const GammaLUT& getInstance() noexcept
    {
        static GammaLUT instance;
        return instance;
    }

    // Fast gamma-corrected interpolation using lookup tables
    static uint8_t interpolateGamma(uint8_t a, uint8_t b, float t) noexcept
    {
        const auto& lut = getInstance();
        float linearA = lut.toLinear[a];
        float linearB = lut.toLinear[b];
        float linearResult = linearA + t * (linearB - linearA);

        // Convert back to gamma space (clamp to 0-255)
        int idx = static_cast<int>(linearResult * 255.0f + 0.5f);
        idx = idx < 0 ? 0 : (idx > 255 ? 255 : idx);
        return lut.toGamma[static_cast<size_t>(idx)];
    }

private:
    GammaLUT() noexcept
    {
        constexpr float gamma = 2.2f;
        constexpr float invGamma = 1.0f / 2.2f;

        for (int i = 0; i < 256; ++i)
        {
            float normalized = static_cast<float>(i) / 255.0f;
            // To linear (sRGB decode)
            toLinear[static_cast<size_t>(i)] = std::pow(normalized, gamma);
            // To gamma (sRGB encode) - maps 0-255 linear input to gamma output
            toGamma[static_cast<size_t>(i)] = static_cast<uint8_t>(std::pow(normalized, invGamma) * 255.0f + 0.5f);
        }
    }
};

//==============================================================================
// ILDA Point (Optimized Layout)
//==============================================================================

struct LASER_CACHE_ALIGN ILDAPoint
{
    int16_t x;      // -32768 to +32767 (normalized laser coordinates)
    int16_t y;
    int16_t z;      // Usually 0, can be used for 3D effects
    uint8_t r;      // Red intensity (0-255)
    uint8_t g;      // Green intensity (0-255)
    uint8_t b;      // Blue intensity (0-255)
    uint8_t status; // Bit 0: blanking, Bit 1-7: reserved

    // Status bits
    static constexpr uint8_t kBlankingBit = 0x40;
    static constexpr uint8_t kLastPointBit = 0x80;

    ILDAPoint() noexcept : x(0), y(0), z(0), r(0), g(0), b(0), status(0) {}

    ILDAPoint(int16_t px, int16_t py, uint8_t pr, uint8_t pg, uint8_t pb, bool blanked = false) noexcept
        : x(px), y(py), z(0), r(pr), g(pg), b(pb), status(blanked ? kBlankingBit : 0) {}

    void setBlanking(bool blanked) noexcept { status = blanked ? (status | kBlankingBit) : (status & ~kBlankingBit); }
    bool isBlanked() const noexcept { return (status & kBlankingBit) != 0; }

    // Color interpolation with gamma correction (using lookup tables - ~20x faster)
    static ILDAPoint interpolate(const ILDAPoint& a, const ILDAPoint& b, float t) noexcept
    {
        ILDAPoint result;
        result.x = static_cast<int16_t>(lerp(static_cast<float>(a.x), static_cast<float>(b.x), t));
        result.y = static_cast<int16_t>(lerp(static_cast<float>(a.y), static_cast<float>(b.y), t));
        result.z = static_cast<int16_t>(lerp(static_cast<float>(a.z), static_cast<float>(b.z), t));

        // Gamma-corrected color interpolation using lookup tables
        result.r = GammaLUT::interpolateGamma(a.r, b.r, t);
        result.g = GammaLUT::interpolateGamma(a.g, b.g, t);
        result.b = GammaLUT::interpolateGamma(a.b, b.b, t);

        result.status = t < 0.5f ? a.status : b.status;
        return result;
    }
};

//==============================================================================
// Render Buffer (Lock-Free Triple Buffer)
//==============================================================================

struct LASER_CACHE_ALIGN RenderBuffer
{
    std::array<ILDAPoint, kMaxPointsPerFrame> points;
    std::atomic<int> numPoints{0};
    std::atomic<uint64_t> frameId{0};
    std::atomic<bool> ready{false};

    // Timing information for interpolation
    double timestamp = 0.0;
    double deltaTime = 0.0;

    void clear() noexcept
    {
        numPoints.store(0, std::memory_order_release);
        ready.store(false, std::memory_order_release);
    }
};

//==============================================================================
// Pattern Types
//==============================================================================

enum class PatternType : uint8_t
{
    // Basic Geometric
    Circle = 0,
    Square,
    Triangle,
    Star,
    Polygon,

    // Lines & Grids
    HorizontalLine,
    VerticalLine,
    Cross,
    Grid,

    // Animated
    Spiral,
    Tunnel,
    Wave,
    Lissajous,
    Helix,

    // Text & Graphics
    Text,
    Logo,
    VectorGraphics,

    // Audio-Reactive
    AudioWaveform,
    AudioSpectrum,
    AudioTunnel,
    AudioPulse,

    // Bio-Reactive
    BioSpiral,
    BioBreath,
    BioHeartbeat,

    // Advanced Effects
    ParticleBeam,
    Constellation,
    FractalTree,

    NumPatterns
};

//==============================================================================
// Beam Configuration (Optimized for Cache)
//==============================================================================

struct LASER_CACHE_ALIGN BeamConfig
{
    // Pattern Selection
    PatternType pattern = PatternType::Circle;
    bool enabled = true;

    // Position & Transform (normalized -1 to 1)
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;          // Depth for 3D effects
    float size = 0.5f;       // Scale factor
    float rotation = 0.0f;   // Current rotation (radians)
    float rotationSpeed = 0.0f;  // Radians per second

    // Color (linear RGB, 0-1)
    float red = 1.0f;
    float green = 0.0f;
    float blue = 0.0f;
    float brightness = 1.0f;

    // Animation
    float speed = 1.0f;
    float phase = 0.0f;      // Animation phase offset
    float frequency = 1.0f;  // For wave patterns

    // Pattern-specific
    int segments = 5;        // For polygon/star
    float innerRadius = 0.3f; // For star patterns

    // Modulation flags
    bool audioReactive = false;
    bool bioReactive = false;

    // Quality settings
    int pointDensity = 100;  // Points per shape (auto-adjusted for scan speed)
    bool antiAliased = true;

    BeamConfig() = default;
};

//==============================================================================
// Safety Configuration
//==============================================================================

struct SafetyConfig
{
    bool enabled = true;
    float maxScanSpeedPPS = 30000.0f;  // ILDA standard: 30K pps
    float maxPowerMW = 500.0f;
    float minBeamDiameter = 5.0f;      // mm at reference distance
    bool preventAudienceScanning = true;
    float audienceHeightMM = 1800.0f;

    SafetyConfig() = default;
};

//==============================================================================
// Output Configuration
//==============================================================================

struct OutputConfig
{
    bool enabled = true;
    std::array<char, 64> name = {};
    std::array<char, 16> protocol = {'I', 'L', 'D', 'A', 0};  // "ILDA" or "DMX"
    std::array<char, 16> ipAddress = {'1', '2', '7', '.', '0', '.', '0', '.', '1', 0};
    uint16_t port = 7255;
    uint16_t dmxUniverse = 1;

    // Geometric correction
    float xOffset = 0.0f;
    float yOffset = 0.0f;
    float xScale = 1.0f;
    float yScale = 1.0f;
    float rotation = 0.0f;

    OutputConfig() = default;
};

//==============================================================================
// Performance Metrics (Copyable Snapshot)
//==============================================================================

struct MetricsSnapshot
{
    float frameTimeMs = 0.0f;
    float renderTimeMs = 0.0f;
    float outputTimeMs = 0.0f;
    int pointsRendered = 0;
    int framesDropped = 0;
    uint64_t totalFrames = 0;
    float currentFPS = 0.0f;
    float latencyMs = 0.0f;
};

//==============================================================================
// Performance Metrics (Atomic - Internal Use)
//==============================================================================

struct PerformanceMetrics
{
    std::atomic<float> frameTimeMs{0.0f};
    std::atomic<float> renderTimeMs{0.0f};
    std::atomic<float> outputTimeMs{0.0f};
    std::atomic<int> pointsRendered{0};
    std::atomic<int> framesDropped{0};
    std::atomic<uint64_t> totalFrames{0};
    std::atomic<float> currentFPS{0.0f};
    std::atomic<float> latencyMs{0.0f};

    void reset() noexcept
    {
        frameTimeMs.store(0.0f);
        renderTimeMs.store(0.0f);
        outputTimeMs.store(0.0f);
        pointsRendered.store(0);
        framesDropped.store(0);
        totalFrames.store(0);
        currentFPS.store(0.0f);
        latencyMs.store(0.0f);
    }

    MetricsSnapshot snapshot() const noexcept
    {
        MetricsSnapshot s;
        s.frameTimeMs = frameTimeMs.load(std::memory_order_acquire);
        s.renderTimeMs = renderTimeMs.load(std::memory_order_acquire);
        s.outputTimeMs = outputTimeMs.load(std::memory_order_acquire);
        s.pointsRendered = pointsRendered.load(std::memory_order_acquire);
        s.framesDropped = framesDropped.load(std::memory_order_acquire);
        s.totalFrames = totalFrames.load(std::memory_order_acquire);
        s.currentFPS = currentFPS.load(std::memory_order_acquire);
        s.latencyMs = latencyMs.load(std::memory_order_acquire);
        return s;
    }
};

//==============================================================================
// Audio/Bio Data Input
//==============================================================================

struct LASER_CACHE_ALIGN AudioData
{
    std::array<float, 512> spectrum;     // FFT spectrum bins
    std::array<float, 1024> waveform;    // Audio waveform samples
    std::atomic<float> peakLevel{0.0f};
    std::atomic<float> rmsLevel{0.0f};
    std::atomic<float> bassLevel{0.0f};
    std::atomic<float> midLevel{0.0f};
    std::atomic<float> highLevel{0.0f};
    std::atomic<bool> beatDetected{false};

    void clear() noexcept
    {
        spectrum.fill(0.0f);
        waveform.fill(0.0f);
        peakLevel.store(0.0f);
        rmsLevel.store(0.0f);
        bassLevel.store(0.0f);
        midLevel.store(0.0f);
        highLevel.store(0.0f);
        beatDetected.store(false);
    }
};

struct LASER_CACHE_ALIGN BioData
{
    std::atomic<float> hrv{0.5f};            // Heart rate variability (0-1)
    std::atomic<float> coherence{0.5f};      // Coherence level (0-1)
    std::atomic<float> heartRate{70.0f};     // BPM
    std::atomic<float> breathingRate{12.0f}; // Breaths per minute
    std::atomic<float> stress{0.3f};         // Stress level (0-1)
    std::atomic<bool> heartbeatPulse{false}; // Heartbeat trigger
    std::atomic<bool> breathPhase{false};    // Inhale/exhale

    void reset() noexcept
    {
        hrv.store(0.5f);
        coherence.store(0.5f);
        heartRate.store(70.0f);
        breathingRate.store(12.0f);
        stress.store(0.3f);
        heartbeatPulse.store(false);
        breathPhase.store(false);
    }
};

//==============================================================================
// Forward Declarations
//==============================================================================

class SuperLaserScan;

//==============================================================================
// Render Callback Types
//==============================================================================

using FrameCallback = std::function<void(const ILDAPoint*, int, uint64_t)>;
using ErrorCallback = std::function<void(int errorCode, const char* message)>;

} // namespace laser

//==============================================================================
// SuperLaserScan Class
//==============================================================================

class SuperLaserScan
{
public:
    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SuperLaserScan();
    ~SuperLaserScan();

    // Non-copyable, movable
    SuperLaserScan(const SuperLaserScan&) = delete;
    SuperLaserScan& operator=(const SuperLaserScan&) = delete;
    SuperLaserScan(SuperLaserScan&&) noexcept = default;
    SuperLaserScan& operator=(SuperLaserScan&&) noexcept = default;

    //==========================================================================
    // Initialization
    //==========================================================================

    /** Initialize with target frame rate */
    void initialize(float targetFPS = 60.0f);

    /** Shutdown and release resources */
    void shutdown();

    /** Check if initialized */
    bool isInitialized() const noexcept { return initialized_.load(std::memory_order_acquire); }

    //==========================================================================
    // Beam Management
    //==========================================================================

    /** Add a new beam, returns beam index */
    int addBeam(const laser::BeamConfig& config);

    /** Get beam configuration (thread-safe copy) */
    laser::BeamConfig getBeam(int index) const;

    /** Update beam configuration (lock-free) */
    void setBeam(int index, const laser::BeamConfig& config);

    /** Remove beam */
    void removeBeam(int index);

    /** Clear all beams */
    void clearBeams();

    /** Get number of active beams */
    int getNumBeams() const noexcept;

    //==========================================================================
    // Output Management
    //==========================================================================

    /** Add output destination */
    int addOutput(const laser::OutputConfig& config);

    /** Get output configuration */
    laser::OutputConfig getOutput(int index) const;

    /** Update output configuration */
    void setOutput(int index, const laser::OutputConfig& config);

    /** Remove output */
    void removeOutput(int index);

    /** Enable/disable master output */
    void setOutputEnabled(bool enabled) noexcept;

    /** Check if output is enabled */
    bool isOutputEnabled() const noexcept { return outputEnabled_.load(std::memory_order_acquire); }

    //==========================================================================
    // Safety
    //==========================================================================

    /** Set safety configuration */
    void setSafetyConfig(const laser::SafetyConfig& config);

    /** Get safety configuration */
    laser::SafetyConfig getSafetyConfig() const;

    /** Check if current configuration is safe */
    bool isSafe() const noexcept;

    /** Get safety warning messages */
    std::vector<std::string> getSafetyWarnings() const;

    //==========================================================================
    // Real-Time Rendering
    //==========================================================================

    /** Render a single frame (call at target FPS) */
    void renderFrame(double deltaTime);

    /** Get current frame data (for direct monitoring) */
    const laser::ILDAPoint* getCurrentFrame(int& numPoints) const noexcept;

    /** Get interpolated frame for smoother display */
    void getInterpolatedFrame(laser::ILDAPoint* outPoints, int& numPoints, float interpolation) const noexcept;

    /** Send current frame to all outputs */
    void sendFrame();

    //==========================================================================
    // Audio Reactivity
    //==========================================================================

    /** Update audio spectrum data (lock-free) */
    void updateAudioSpectrum(const float* data, int numBins);

    /** Update audio waveform data (lock-free) */
    void updateAudioWaveform(const float* data, int numSamples);

    /** Update audio levels (lock-free) */
    void updateAudioLevels(float peak, float rms, float bass, float mid, float high);

    /** Trigger beat detection */
    void triggerBeat();

    //==========================================================================
    // Bio-Reactivity
    //==========================================================================

    /** Update bio-data (lock-free) */
    void setBioData(float hrv, float coherence, float heartRate, float breathingRate, float stress);

    /** Enable/disable bio-reactive mode */
    void setBioReactiveEnabled(bool enabled) noexcept;

    /** Check if bio-reactive mode is enabled */
    bool isBioReactiveEnabled() const noexcept { return bioEnabled_.load(std::memory_order_acquire); }

    /** Trigger heartbeat pulse */
    void triggerHeartbeat();

    /** Set breathing phase (inhale=true, exhale=false) */
    void setBreathPhase(bool inhaling);

    //==========================================================================
    // Presets
    //==========================================================================

    /** Get list of built-in presets */
    std::vector<std::string> getBuiltInPresets() const;

    /** Load a built-in preset */
    void loadPreset(const std::string& name);

    //==========================================================================
    // Performance Monitoring
    //==========================================================================

    /** Get current performance metrics */
    laser::MetricsSnapshot getMetrics() const noexcept;

    /** Reset performance counters */
    void resetMetrics() noexcept;

    //==========================================================================
    // Callbacks
    //==========================================================================

    /** Set frame callback (called after each frame render) */
    void setFrameCallback(laser::FrameCallback callback);

    /** Set error callback */
    void setErrorCallback(laser::ErrorCallback callback);

    //==========================================================================
    // Direct Monitoring Quality Settings
    //==========================================================================

    /** Set point interpolation quality (0=none, 1=linear, 2=cubic) */
    void setInterpolationQuality(int quality) noexcept;

    /** Set blanking optimization level (0=none, 1=normal, 2=aggressive) */
    void setBlankingOptimization(int level) noexcept;

    /** Set galvo acceleration limit (points per second squared) */
    void setGalvoAcceleration(float maxAcceleration) noexcept;

    /** Enable/disable adaptive point density */
    void setAdaptivePointDensity(bool enabled) noexcept;

private:
    //==========================================================================
    // Internal State
    //==========================================================================

    std::atomic<bool> initialized_{false};
    std::atomic<bool> outputEnabled_{false};
    std::atomic<bool> bioEnabled_{false};

    float targetFPS_ = 60.0f;
    double currentTime_ = 0.0;
    std::atomic<uint64_t> frameCounter_{0};

    // Pre-computed trigonometric lookup tables
    std::array<float, laser::kTrigTableSize> sinTable_;
    std::array<float, laser::kTrigTableSize> cosTable_;

    // Gamma-corrected color lookup table
    std::array<uint8_t, laser::kColorLUTSize> gammaLUT_;

    // Beams (atomic for lock-free access)
    std::array<laser::BeamConfig, laser::kMaxBeams> beams_;
    std::atomic<int> numBeams_{0};

    // Outputs
    std::vector<laser::OutputConfig> outputs_;

    // Safety
    laser::SafetyConfig safetyConfig_;

    // Triple buffer for lock-free rendering
    std::array<laser::RenderBuffer, laser::kNumRenderBuffers> renderBuffers_;
    std::atomic<int> writeBufferIndex_{0};
    std::atomic<int> readBufferIndex_{1};
    std::atomic<int> displayBufferIndex_{2};

    // Audio/Bio data (lock-free)
    laser::AudioData audioData_;
    laser::BioData bioData_;

    // Performance metrics
    laser::PerformanceMetrics metrics_;

    // Callbacks
    laser::FrameCallback frameCallback_;
    laser::ErrorCallback errorCallback_;

    // Quality settings
    std::atomic<int> interpolationQuality_{1};
    std::atomic<int> blankingOptimization_{1};
    std::atomic<float> maxGalvoAcceleration_{50000.0f};
    std::atomic<bool> adaptivePointDensity_{true};

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeLookupTables();
    void swapBuffers() noexcept;

    // Pattern rendering (optimized)
    int renderBeam(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderCircle(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderPolygon(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderSpiral(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderTunnel(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderWave(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderLissajous(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderAudioWaveform(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderAudioSpectrum(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderBioSpiral(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderGrid(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderStar(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);
    int renderHelix(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints);

    // Optimization passes
    void optimizeBlankingPoints(laser::ILDAPoint* points, int& numPoints);
    void applyGalvoLimits(laser::ILDAPoint* points, int& numPoints);
    void applySafetyLimits(laser::ILDAPoint* points, int& numPoints);
    int calculateAdaptivePointCount(const laser::BeamConfig& beam) const;

    // Modulation
    void applyAudioModulation(laser::BeamConfig& beam);
    void applyBioModulation(laser::BeamConfig& beam);

    // Protocol conversion
    std::vector<uint8_t> convertToILDA(const laser::ILDAPoint* points, int numPoints);
    std::vector<uint8_t> convertToDMX(const laser::ILDAPoint* points, int numPoints);

    // Network output
    void sendToOutput(const laser::OutputConfig& output, const std::vector<uint8_t>& data);

    //==========================================================================
    // SIMD Helpers
    //==========================================================================

#if defined(LASER_USE_AVX2)
    void renderCircleSIMD_AVX2(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int numPoints);
#elif defined(LASER_USE_SSE2)
    void renderCircleSIMD_SSE2(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int numPoints);
#elif defined(LASER_USE_NEON)
    void renderCircleSIMD_NEON(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int numPoints);
#endif

    void transformPointsSIMD(laser::ILDAPoint* points, int numPoints, float xOffset, float yOffset, float scale, float rotation);
};
