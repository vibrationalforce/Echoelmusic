/**
 * SuperLaserScan.cpp - Ultra-Low Latency Laser Scanning Engine
 *
 * Optimized Implementation with:
 * - SIMD vectorization (AVX2/SSE2/NEON)
 * - Lock-free triple buffering
 * - Pre-computed lookup tables
 * - Sub-millisecond frame generation
 *
 * Inspired by 2025 AI Visual Trends:
 * - MirageLSD: < 40ms real-time transformation
 * - TurboDiffusion: 100-200x acceleration
 * - Prequel: One-tap stylization patterns
 * - Edge AI: Local processing, zero cloud latency
 */

#include "SuperLaserScan.h"
#include <chrono>
#include <cstring>
#include <algorithm>
#include <thread>

// High-resolution timer for performance measurement
namespace {
    using Clock = std::chrono::high_resolution_clock;
    using TimePoint = std::chrono::time_point<Clock>;

    inline double getTimeMs()
    {
        static const TimePoint start = Clock::now();
        auto now = Clock::now();
        return std::chrono::duration<double, std::milli>(now - start).count();
    }
}

//==============================================================================
// Constructor / Destructor
//==============================================================================

SuperLaserScan::SuperLaserScan()
{
    // Initialize lookup tables immediately for fastest startup
    initializeLookupTables();

    // Pre-allocate all buffers
    for (auto& buffer : renderBuffers_)
    {
        buffer.clear();
    }

    // Initialize audio/bio data
    audioData_.clear();
    bioData_.reset();
    metrics_.reset();
}

SuperLaserScan::~SuperLaserScan()
{
    shutdown();
}

//==============================================================================
// Initialization
//==============================================================================

void SuperLaserScan::initialize(float targetFPS)
{
    if (initialized_.load(std::memory_order_acquire))
        return;

    targetFPS_ = std::max(1.0f, std::min(targetFPS, 120.0f));
    currentTime_ = 0.0;
    frameCounter_.store(0);

    // Reset all buffers
    for (auto& buffer : renderBuffers_)
    {
        buffer.clear();
    }

    writeBufferIndex_.store(0, std::memory_order_release);
    readBufferIndex_.store(1, std::memory_order_release);
    displayBufferIndex_.store(2, std::memory_order_release);

    metrics_.reset();
    initialized_.store(true, std::memory_order_release);
}

void SuperLaserScan::shutdown()
{
    if (!initialized_.load(std::memory_order_acquire))
        return;

    outputEnabled_.store(false, std::memory_order_release);
    initialized_.store(false, std::memory_order_release);

    // Clear all beams and outputs
    numBeams_.store(0, std::memory_order_release);
    outputs_.clear();
}

void SuperLaserScan::initializeLookupTables()
{
    // Pre-compute sin/cos tables for fast trigonometry
    for (int i = 0; i < laser::kTrigTableSize; ++i)
    {
        float angle = (static_cast<float>(i) / laser::kTrigTableSize) * laser::kTwoPi;
        sinTable_[i] = std::sin(angle);
        cosTable_[i] = std::cos(angle);
    }

    // Pre-compute gamma correction LUT (gamma = 2.2)
    constexpr float gamma = 2.2f;
    for (int i = 0; i < laser::kColorLUTSize; ++i)
    {
        float normalized = static_cast<float>(i) / 255.0f;
        float corrected = std::pow(normalized, gamma);
        gammaLUT_[i] = static_cast<uint8_t>(corrected * 255.0f);
    }
}

//==============================================================================
// Beam Management
//==============================================================================

int SuperLaserScan::addBeam(const laser::BeamConfig& config)
{
    int index = numBeams_.load(std::memory_order_acquire);
    if (index >= laser::kMaxBeams)
        return -1;

    beams_[index] = config;
    numBeams_.fetch_add(1, std::memory_order_release);
    return index;
}

laser::BeamConfig SuperLaserScan::getBeam(int index) const
{
    if (index < 0 || index >= numBeams_.load(std::memory_order_acquire))
        return laser::BeamConfig();
    return beams_[index];
}

void SuperLaserScan::setBeam(int index, const laser::BeamConfig& config)
{
    if (index >= 0 && index < numBeams_.load(std::memory_order_acquire))
    {
        beams_[index] = config;
    }
}

void SuperLaserScan::removeBeam(int index)
{
    int count = numBeams_.load(std::memory_order_acquire);
    if (index < 0 || index >= count)
        return;

    // Shift beams down
    for (int i = index; i < count - 1; ++i)
    {
        beams_[i] = beams_[i + 1];
    }
    numBeams_.fetch_sub(1, std::memory_order_release);
}

void SuperLaserScan::clearBeams()
{
    numBeams_.store(0, std::memory_order_release);
}

int SuperLaserScan::getNumBeams() const noexcept
{
    return numBeams_.load(std::memory_order_acquire);
}

//==============================================================================
// Output Management
//==============================================================================

int SuperLaserScan::addOutput(const laser::OutputConfig& config)
{
    outputs_.push_back(config);
    return static_cast<int>(outputs_.size()) - 1;
}

laser::OutputConfig SuperLaserScan::getOutput(int index) const
{
    if (index >= 0 && index < static_cast<int>(outputs_.size()))
        return outputs_[index];
    return laser::OutputConfig();
}

void SuperLaserScan::setOutput(int index, const laser::OutputConfig& config)
{
    if (index >= 0 && index < static_cast<int>(outputs_.size()))
    {
        outputs_[index] = config;
    }
}

void SuperLaserScan::removeOutput(int index)
{
    if (index >= 0 && index < static_cast<int>(outputs_.size()))
    {
        outputs_.erase(outputs_.begin() + index);
    }
}

void SuperLaserScan::setOutputEnabled(bool enabled) noexcept
{
    outputEnabled_.store(enabled, std::memory_order_release);
}

//==============================================================================
// Safety
//==============================================================================

void SuperLaserScan::setSafetyConfig(const laser::SafetyConfig& config)
{
    safetyConfig_ = config;
}

laser::SafetyConfig SuperLaserScan::getSafetyConfig() const
{
    return safetyConfig_;
}

bool SuperLaserScan::isSafe() const noexcept
{
    return getSafetyWarnings().empty();
}

std::vector<std::string> SuperLaserScan::getSafetyWarnings() const
{
    std::vector<std::string> warnings;

    if (!safetyConfig_.enabled)
    {
        warnings.push_back("WARNING: Safety system DISABLED!");
    }

    // Check total power
    float totalBrightness = 0.0f;
    int count = numBeams_.load(std::memory_order_acquire);
    for (int i = 0; i < count; ++i)
    {
        if (beams_[i].enabled)
        {
            totalBrightness += beams_[i].brightness;
        }
    }

    if (totalBrightness * safetyConfig_.maxPowerMW > safetyConfig_.maxPowerMW)
    {
        warnings.push_back("Total power exceeds safe limit");
    }

    return warnings;
}

//==============================================================================
// Real-Time Rendering (Core Performance Path)
//==============================================================================

void SuperLaserScan::renderFrame(double deltaTime)
{
    if (!initialized_.load(std::memory_order_acquire))
        return;

    TimePoint frameStart = Clock::now();

    currentTime_ += deltaTime;

    // Get write buffer (lock-free)
    int writeIdx = writeBufferIndex_.load(std::memory_order_acquire);
    laser::RenderBuffer& writeBuffer = renderBuffers_[writeIdx];
    writeBuffer.clear();

    laser::ILDAPoint* points = writeBuffer.points.data();
    int totalPoints = 0;
    int maxPoints = laser::kMaxPointsPerFrame;

    // Render all enabled beams
    // OPTIMIZATION: Add bounds checking to prevent out-of-bounds access
    int beamCount = numBeams_.load(std::memory_order_acquire);
    beamCount = std::min(beamCount, static_cast<int>(laser::kMaxBeams));  // Safety clamp

    for (int i = 0; i < beamCount && totalPoints < maxPoints; ++i)
    {
        laser::BeamConfig beam = beams_[i];
        if (!beam.enabled)
            continue;

        // Apply modulation
        if (beam.audioReactive)
            applyAudioModulation(beam);
        if (beam.bioReactive && bioEnabled_.load(std::memory_order_acquire))
            applyBioModulation(beam);

        // Update rotation
        beam.rotation += beam.rotationSpeed * static_cast<float>(deltaTime);
        beam.phase += beam.speed * static_cast<float>(deltaTime);

        // Render pattern
        int renderedPoints = renderBeam(beam, points + totalPoints, maxPoints - totalPoints);
        totalPoints += renderedPoints;

        // Store updated beam state
        beams_[i].rotation = beam.rotation;
        beams_[i].phase = beam.phase;
    }

    // Post-processing optimizations
    if (blankingOptimization_.load(std::memory_order_acquire) > 0)
    {
        optimizeBlankingPoints(points, totalPoints);
    }

    if (maxGalvoAcceleration_.load(std::memory_order_acquire) > 0.0f)
    {
        applyGalvoLimits(points, totalPoints);
    }

    if (safetyConfig_.enabled)
    {
        applySafetyLimits(points, totalPoints);
    }

    // Store frame data
    writeBuffer.numPoints.store(totalPoints, std::memory_order_release);
    writeBuffer.timestamp = currentTime_;
    writeBuffer.deltaTime = deltaTime;
    writeBuffer.frameId.store(frameCounter_.fetch_add(1, std::memory_order_relaxed), std::memory_order_release);
    writeBuffer.ready.store(true, std::memory_order_release);

    // Triple buffer swap (lock-free)
    swapBuffers();

    // Update metrics
    TimePoint frameEnd = Clock::now();
    float frameTimeMs = std::chrono::duration<float, std::milli>(frameEnd - frameStart).count();
    metrics_.frameTimeMs.store(frameTimeMs, std::memory_order_release);
    metrics_.pointsRendered.store(totalPoints, std::memory_order_release);
    metrics_.totalFrames.fetch_add(1, std::memory_order_relaxed);
    metrics_.currentFPS.store(1000.0f / std::max(0.001f, frameTimeMs), std::memory_order_release);

    // Invoke callback
    if (frameCallback_)
    {
        int readIdx = displayBufferIndex_.load(std::memory_order_acquire);
        const laser::RenderBuffer& displayBuffer = renderBuffers_[readIdx];
        frameCallback_(displayBuffer.points.data(),
                       displayBuffer.numPoints.load(std::memory_order_acquire),
                       displayBuffer.frameId.load(std::memory_order_acquire));
    }
}

void SuperLaserScan::swapBuffers() noexcept
{
    // Lock-free triple buffer swap
    int write = writeBufferIndex_.load(std::memory_order_acquire);
    int read = readBufferIndex_.load(std::memory_order_acquire);
    int display = displayBufferIndex_.load(std::memory_order_acquire);

    // Rotate: write -> display -> read -> write
    writeBufferIndex_.store(read, std::memory_order_release);
    displayBufferIndex_.store(write, std::memory_order_release);
    readBufferIndex_.store(display, std::memory_order_release);
}

const laser::ILDAPoint* SuperLaserScan::getCurrentFrame(int& numPoints) const noexcept
{
    int displayIdx = displayBufferIndex_.load(std::memory_order_acquire);
    const laser::RenderBuffer& buffer = renderBuffers_[displayIdx];
    numPoints = buffer.numPoints.load(std::memory_order_acquire);
    return buffer.points.data();
}

void SuperLaserScan::getInterpolatedFrame(laser::ILDAPoint* outPoints, int& numPoints, float interpolation) const noexcept
{
    int displayIdx = displayBufferIndex_.load(std::memory_order_acquire);
    int readIdx = readBufferIndex_.load(std::memory_order_acquire);

    const laser::RenderBuffer& current = renderBuffers_[displayIdx];
    const laser::RenderBuffer& previous = renderBuffers_[readIdx];

    int currentCount = current.numPoints.load(std::memory_order_acquire);
    int previousCount = previous.numPoints.load(std::memory_order_acquire);

    // Use smaller count for interpolation
    numPoints = std::min(currentCount, previousCount);
    if (numPoints == 0)
    {
        numPoints = currentCount;
        std::memcpy(outPoints, current.points.data(), numPoints * sizeof(laser::ILDAPoint));
        return;
    }

    // Interpolate between frames for smooth display
    float t = laser::clamp(interpolation, 0.0f, 1.0f);
    for (int i = 0; i < numPoints; ++i)
    {
        outPoints[i] = laser::ILDAPoint::interpolate(previous.points[i], current.points[i], t);
    }
}

//==============================================================================
// Pattern Rendering
//==============================================================================

int SuperLaserScan::renderBeam(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    switch (beam.pattern)
    {
        case laser::PatternType::Circle:
            return renderCircle(beam, outPoints, maxPoints);
        case laser::PatternType::Square:
        case laser::PatternType::Triangle:
        case laser::PatternType::Polygon:
            return renderPolygon(beam, outPoints, maxPoints);
        case laser::PatternType::Star:
            return renderStar(beam, outPoints, maxPoints);
        case laser::PatternType::Spiral:
            return renderSpiral(beam, outPoints, maxPoints);
        case laser::PatternType::Tunnel:
            return renderTunnel(beam, outPoints, maxPoints);
        case laser::PatternType::Wave:
            return renderWave(beam, outPoints, maxPoints);
        case laser::PatternType::Lissajous:
            return renderLissajous(beam, outPoints, maxPoints);
        case laser::PatternType::Helix:
            return renderHelix(beam, outPoints, maxPoints);
        case laser::PatternType::Grid:
            return renderGrid(beam, outPoints, maxPoints);
        case laser::PatternType::AudioWaveform:
            return renderAudioWaveform(beam, outPoints, maxPoints);
        case laser::PatternType::AudioSpectrum:
            return renderAudioSpectrum(beam, outPoints, maxPoints);
        case laser::PatternType::BioSpiral:
        case laser::PatternType::BioBreath:
        case laser::PatternType::BioHeartbeat:
            return renderBioSpiral(beam, outPoints, maxPoints);
        default:
            return renderCircle(beam, outPoints, maxPoints);
    }
}

int SuperLaserScan::renderCircle(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int numPoints = adaptivePointDensity_.load(std::memory_order_acquire)
                    ? calculateAdaptivePointCount(beam)
                    : beam.pointDensity;
    numPoints = std::min(numPoints, maxPoints);

    // Pre-compute color values
    uint8_t r = static_cast<uint8_t>(beam.red * beam.brightness * 255.0f);
    uint8_t g = static_cast<uint8_t>(beam.green * beam.brightness * 255.0f);
    uint8_t b = static_cast<uint8_t>(beam.blue * beam.brightness * 255.0f);

    // Use SIMD if available and point count is sufficient
#if defined(LASER_USE_AVX2) || defined(LASER_USE_SSE2) || defined(LASER_USE_NEON)
    if (numPoints >= 8)
    {
#if defined(LASER_USE_AVX2)
        renderCircleSIMD_AVX2(beam, outPoints, numPoints);
#elif defined(LASER_USE_SSE2)
        renderCircleSIMD_SSE2(beam, outPoints, numPoints);
#elif defined(LASER_USE_NEON)
        renderCircleSIMD_NEON(beam, outPoints, numPoints);
#endif
        // Set colors (SIMD handles positions only)
        for (int i = 0; i < numPoints; ++i)
        {
            outPoints[i].r = r;
            outPoints[i].g = g;
            outPoints[i].b = b;
            outPoints[i].status = (i == 0) ? laser::ILDAPoint::kBlankingBit : 0;
        }
        return numPoints;
    }
#endif

    // Scalar fallback with fast sin/cos
    float rotation = beam.rotation;
    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    for (int i = 0; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints;
        float angle = t * laser::kTwoPi + rotation;

        float cosVal = laser::fastCos(angle, sinTable_.data());
        float sinVal = laser::fastSin(angle, sinTable_.data());

        float x = beam.x + cosVal * beam.size;
        float y = beam.y + sinVal * beam.size;

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = 0;
        outPoints[i].r = r;
        outPoints[i].g = g;
        outPoints[i].b = b;
        outPoints[i].status = (i == 0) ? laser::ILDAPoint::kBlankingBit : 0;
    }

    return numPoints;
}

int SuperLaserScan::renderPolygon(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int sides = std::max(3, beam.segments);
    int pointsPerSide = std::max(2, beam.pointDensity / sides);
    int numPoints = std::min(sides * pointsPerSide, maxPoints);

    uint8_t r = static_cast<uint8_t>(beam.red * beam.brightness * 255.0f);
    uint8_t g = static_cast<uint8_t>(beam.green * beam.brightness * 255.0f);
    uint8_t b = static_cast<uint8_t>(beam.blue * beam.brightness * 255.0f);

    int pointIdx = 0;
    float angleStep = laser::kTwoPi / static_cast<float>(sides);

    for (int side = 0; side < sides && pointIdx < maxPoints; ++side)
    {
        float angle1 = static_cast<float>(side) * angleStep + beam.rotation;
        float angle2 = static_cast<float>(side + 1) * angleStep + beam.rotation;

        float x1 = beam.x + laser::fastCos(angle1, sinTable_.data()) * beam.size;
        float y1 = beam.y + laser::fastSin(angle1, sinTable_.data()) * beam.size;
        float x2 = beam.x + laser::fastCos(angle2, sinTable_.data()) * beam.size;
        float y2 = beam.y + laser::fastSin(angle2, sinTable_.data()) * beam.size;

        // Interpolate along edge
        for (int p = 0; p < pointsPerSide && pointIdx < maxPoints; ++p)
        {
            float t = static_cast<float>(p) / static_cast<float>(pointsPerSide);
            float x = laser::lerp(x1, x2, t);
            float y = laser::lerp(y1, y2, t);

            outPoints[pointIdx].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
            outPoints[pointIdx].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
            outPoints[pointIdx].z = 0;
            outPoints[pointIdx].r = r;
            outPoints[pointIdx].g = g;
            outPoints[pointIdx].b = b;
            outPoints[pointIdx].status = (pointIdx == 0) ? laser::ILDAPoint::kBlankingBit : 0;
            ++pointIdx;
        }
    }

    return pointIdx;
}

int SuperLaserScan::renderStar(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int points = std::max(5, beam.segments);
    int numPoints = std::min(points * 2 * 5, maxPoints);  // 5 points per segment

    uint8_t r = static_cast<uint8_t>(beam.red * beam.brightness * 255.0f);
    uint8_t g = static_cast<uint8_t>(beam.green * beam.brightness * 255.0f);
    uint8_t b = static_cast<uint8_t>(beam.blue * beam.brightness * 255.0f);

    float outerRadius = beam.size;
    float innerRadius = beam.size * beam.innerRadius;

    int pointIdx = 0;
    float angleStep = laser::kTwoPi / static_cast<float>(points * 2);

    for (int i = 0; i < points * 2 && pointIdx < maxPoints; ++i)
    {
        float angle = static_cast<float>(i) * angleStep + beam.rotation;
        float radius = (i % 2 == 0) ? outerRadius : innerRadius;

        float x = beam.x + laser::fastCos(angle, sinTable_.data()) * radius;
        float y = beam.y + laser::fastSin(angle, sinTable_.data()) * radius;

        outPoints[pointIdx].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[pointIdx].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[pointIdx].z = 0;
        outPoints[pointIdx].r = r;
        outPoints[pointIdx].g = g;
        outPoints[pointIdx].b = b;
        outPoints[pointIdx].status = (pointIdx == 0) ? laser::ILDAPoint::kBlankingBit : 0;
        ++pointIdx;
    }

    return pointIdx;
}

int SuperLaserScan::renderSpiral(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int numPoints = std::min(beam.pointDensity * 2, maxPoints);

    float revolutions = 5.0f * beam.frequency;
    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    for (int i = 0; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints;
        float angle = t * laser::kTwoPi * revolutions + beam.rotation + beam.phase;
        float radius = beam.size * t;

        float x = beam.x + laser::fastCos(angle, sinTable_.data()) * radius;
        float y = beam.y + laser::fastSin(angle, sinTable_.data()) * radius;

        // Color gradient along spiral (HSV to RGB approximation)
        float hue = std::fmod(t + beam.phase * 0.1f, 1.0f);
        float r_val, g_val, b_val;
        float h6 = hue * 6.0f;
        int hi = static_cast<int>(h6) % 6;
        float f = h6 - std::floor(h6);

        switch (hi)
        {
            case 0: r_val = 1.0f; g_val = f; b_val = 0.0f; break;
            case 1: r_val = 1.0f - f; g_val = 1.0f; b_val = 0.0f; break;
            case 2: r_val = 0.0f; g_val = 1.0f; b_val = f; break;
            case 3: r_val = 0.0f; g_val = 1.0f - f; b_val = 1.0f; break;
            case 4: r_val = f; g_val = 0.0f; b_val = 1.0f; break;
            default: r_val = 1.0f; g_val = 0.0f; b_val = 1.0f - f; break;
        }

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = 0;
        outPoints[i].r = static_cast<uint8_t>(r_val * beam.brightness * 255.0f);
        outPoints[i].g = static_cast<uint8_t>(g_val * beam.brightness * 255.0f);
        outPoints[i].b = static_cast<uint8_t>(b_val * beam.brightness * 255.0f);
        outPoints[i].status = (i == 0) ? laser::ILDAPoint::kBlankingBit : 0;
    }

    return numPoints;
}

int SuperLaserScan::renderTunnel(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int numRings = 10;
    int pointsPerRing = beam.pointDensity / numRings;
    int numPoints = std::min(numRings * pointsPerRing, maxPoints);

    uint8_t r = static_cast<uint8_t>(beam.red * beam.brightness * 255.0f);
    uint8_t g = static_cast<uint8_t>(beam.green * beam.brightness * 255.0f);
    uint8_t b = static_cast<uint8_t>(beam.blue * beam.brightness * 255.0f);

    int pointIdx = 0;

    for (int ring = 0; ring < numRings && pointIdx < maxPoints; ++ring)
    {
        float z = (static_cast<float>(ring) / numRings) - 0.5f;
        float radius = beam.size * (1.0f - std::abs(z)) * (0.5f + 0.5f * std::cos(beam.phase * 2.0f + z * laser::kPi));

        for (int p = 0; p < pointsPerRing && pointIdx < maxPoints; ++p)
        {
            float angle = (static_cast<float>(p) / pointsPerRing) * laser::kTwoPi + beam.rotation;

            float x = beam.x + laser::fastCos(angle, sinTable_.data()) * radius;
            float y = beam.y + laser::fastSin(angle, sinTable_.data()) * radius;

            outPoints[pointIdx].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
            outPoints[pointIdx].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
            outPoints[pointIdx].z = static_cast<int16_t>(z * 32767.0f);
            outPoints[pointIdx].r = r;
            outPoints[pointIdx].g = g;
            outPoints[pointIdx].b = b;
            outPoints[pointIdx].status = (pointIdx == 0) ? laser::ILDAPoint::kBlankingBit : 0;
            ++pointIdx;
        }
    }

    return pointIdx;
}

int SuperLaserScan::renderWave(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int numPoints = std::min(beam.pointDensity, maxPoints);

    uint8_t r = static_cast<uint8_t>(beam.red * beam.brightness * 255.0f);
    uint8_t g = static_cast<uint8_t>(beam.green * beam.brightness * 255.0f);
    uint8_t b = static_cast<uint8_t>(beam.blue * beam.brightness * 255.0f);

    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    for (int i = 0; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints;
        float x = (t * 2.0f - 1.0f) * beam.size + beam.x;
        float waveAngle = t * laser::kTwoPi * beam.frequency + beam.phase;
        float y = laser::fastSin(waveAngle, sinTable_.data()) * beam.size * 0.5f + beam.y;

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = 0;
        outPoints[i].r = r;
        outPoints[i].g = g;
        outPoints[i].b = b;
        outPoints[i].status = (i == 0) ? laser::ILDAPoint::kBlankingBit : 0;
    }

    return numPoints;
}

int SuperLaserScan::renderLissajous(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int numPoints = std::min(beam.pointDensity * 2, maxPoints);

    uint8_t r = static_cast<uint8_t>(beam.red * beam.brightness * 255.0f);
    uint8_t g = static_cast<uint8_t>(beam.green * beam.brightness * 255.0f);
    uint8_t b = static_cast<uint8_t>(beam.blue * beam.brightness * 255.0f);

    float freqX = beam.frequency;
    float freqY = beam.frequency * 1.5f;  // 3:2 ratio creates interesting patterns
    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    for (int i = 0; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints * laser::kTwoPi * 4.0f;

        float x = beam.x + laser::fastSin(t * freqX + beam.phase, sinTable_.data()) * beam.size;
        float y = beam.y + laser::fastSin(t * freqY + beam.rotation, sinTable_.data()) * beam.size;

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = 0;
        outPoints[i].r = r;
        outPoints[i].g = g;
        outPoints[i].b = b;
        outPoints[i].status = (i == 0) ? laser::ILDAPoint::kBlankingBit : 0;
    }

    return numPoints;
}

int SuperLaserScan::renderHelix(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int numPoints = std::min(beam.pointDensity * 2, maxPoints);

    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    for (int i = 0; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints;
        float angle = t * laser::kTwoPi * 8.0f + beam.phase;
        float radius = beam.size * (0.3f + 0.7f * t);
        float z = (t * 2.0f - 1.0f);

        float x = beam.x + laser::fastCos(angle, sinTable_.data()) * radius;
        float y = beam.y + laser::fastSin(angle, sinTable_.data()) * radius;

        // Color based on height
        float hue = t;
        uint8_t r_val = static_cast<uint8_t>((0.5f + 0.5f * std::sin(hue * laser::kTwoPi)) * beam.brightness * 255.0f);
        uint8_t g_val = static_cast<uint8_t>((0.5f + 0.5f * std::sin(hue * laser::kTwoPi + 2.094f)) * beam.brightness * 255.0f);
        uint8_t b_val = static_cast<uint8_t>((0.5f + 0.5f * std::sin(hue * laser::kTwoPi + 4.188f)) * beam.brightness * 255.0f);

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = static_cast<int16_t>(z * 32767.0f);
        outPoints[i].r = r_val;
        outPoints[i].g = g_val;
        outPoints[i].b = b_val;
        outPoints[i].status = (i == 0) ? laser::ILDAPoint::kBlankingBit : 0;
    }

    return numPoints;
}

int SuperLaserScan::renderGrid(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int gridSize = std::max(2, beam.segments);
    int pointsPerLine = beam.pointDensity / (gridSize * 2);
    int numPoints = std::min(gridSize * 2 * pointsPerLine, maxPoints);

    uint8_t r = static_cast<uint8_t>(beam.red * beam.brightness * 255.0f);
    uint8_t g = static_cast<uint8_t>(beam.green * beam.brightness * 255.0f);
    uint8_t b = static_cast<uint8_t>(beam.blue * beam.brightness * 255.0f);

    int pointIdx = 0;
    float step = 2.0f / static_cast<float>(gridSize - 1);

    // Horizontal lines
    for (int row = 0; row < gridSize && pointIdx < maxPoints; ++row)
    {
        float y = -1.0f + row * step;
        y = y * beam.size + beam.y;

        for (int p = 0; p < pointsPerLine && pointIdx < maxPoints; ++p)
        {
            float t = static_cast<float>(p) / pointsPerLine;
            float x = (t * 2.0f - 1.0f) * beam.size + beam.x;

            outPoints[pointIdx].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
            outPoints[pointIdx].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
            outPoints[pointIdx].z = 0;
            outPoints[pointIdx].r = r;
            outPoints[pointIdx].g = g;
            outPoints[pointIdx].b = b;
            outPoints[pointIdx].status = (p == 0) ? laser::ILDAPoint::kBlankingBit : 0;
            ++pointIdx;
        }
    }

    // Vertical lines
    for (int col = 0; col < gridSize && pointIdx < maxPoints; ++col)
    {
        float x = -1.0f + col * step;
        x = x * beam.size + beam.x;

        for (int p = 0; p < pointsPerLine && pointIdx < maxPoints; ++p)
        {
            float t = static_cast<float>(p) / pointsPerLine;
            float y = (t * 2.0f - 1.0f) * beam.size + beam.y;

            outPoints[pointIdx].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
            outPoints[pointIdx].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
            outPoints[pointIdx].z = 0;
            outPoints[pointIdx].r = r;
            outPoints[pointIdx].g = g;
            outPoints[pointIdx].b = b;
            outPoints[pointIdx].status = (p == 0) ? laser::ILDAPoint::kBlankingBit : 0;
            ++pointIdx;
        }
    }

    return pointIdx;
}

int SuperLaserScan::renderAudioWaveform(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int numPoints = std::min(beam.pointDensity, maxPoints);

    uint8_t r = static_cast<uint8_t>(beam.red * beam.brightness * 255.0f);
    uint8_t g = static_cast<uint8_t>(beam.green * beam.brightness * 255.0f);
    uint8_t b = static_cast<uint8_t>(beam.blue * beam.brightness * 255.0f);

    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    for (int i = 0; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints;
        int waveIdx = static_cast<int>(t * 1023.0f) & 1023;
        float waveValue = audioData_.waveform[waveIdx];

        float x = (t * 2.0f - 1.0f) * beam.size + beam.x;
        float y = waveValue * beam.size * 0.5f + beam.y;

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = 0;
        outPoints[i].r = r;
        outPoints[i].g = g;
        outPoints[i].b = b;
        outPoints[i].status = (i == 0) ? laser::ILDAPoint::kBlankingBit : 0;
    }

    return numPoints;
}

int SuperLaserScan::renderAudioSpectrum(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int numBars = std::min(64, beam.pointDensity / 4);
    int pointsPerBar = 4;
    int numPoints = std::min(numBars * pointsPerBar, maxPoints);

    int pointIdx = 0;
    float barWidth = 2.0f / static_cast<float>(numBars);

    for (int bar = 0; bar < numBars && pointIdx < maxPoints; ++bar)
    {
        int specIdx = (bar * 512) / numBars;
        float magnitude = std::min(1.0f, audioData_.spectrum[specIdx] * 2.0f);

        float xLeft = -1.0f + bar * barWidth;
        float xRight = xLeft + barWidth * 0.8f;
        float yBottom = -0.8f;
        float yTop = yBottom + magnitude * 1.6f;

        xLeft = xLeft * beam.size + beam.x;
        xRight = xRight * beam.size + beam.x;
        yBottom = yBottom * beam.size + beam.y;
        yTop = yTop * beam.size + beam.y;

        // Color based on magnitude (green to red)
        uint8_t r_val = static_cast<uint8_t>(magnitude * beam.brightness * 255.0f);
        uint8_t g_val = static_cast<uint8_t>((1.0f - magnitude) * beam.brightness * 255.0f);
        uint8_t b_val = static_cast<uint8_t>(0.2f * beam.brightness * 255.0f);

        // Draw bar (4 points)
        outPoints[pointIdx++] = laser::ILDAPoint(
            static_cast<int16_t>(laser::clamp(xLeft, -1.0f, 1.0f) * 32767.0f),
            static_cast<int16_t>(laser::clamp(yBottom, -1.0f, 1.0f) * 32767.0f),
            r_val, g_val, b_val, true);

        if (pointIdx < maxPoints)
            outPoints[pointIdx++] = laser::ILDAPoint(
                static_cast<int16_t>(laser::clamp(xLeft, -1.0f, 1.0f) * 32767.0f),
                static_cast<int16_t>(laser::clamp(yTop, -1.0f, 1.0f) * 32767.0f),
                r_val, g_val, b_val, false);

        if (pointIdx < maxPoints)
            outPoints[pointIdx++] = laser::ILDAPoint(
                static_cast<int16_t>(laser::clamp(xRight, -1.0f, 1.0f) * 32767.0f),
                static_cast<int16_t>(laser::clamp(yTop, -1.0f, 1.0f) * 32767.0f),
                r_val, g_val, b_val, false);

        if (pointIdx < maxPoints)
            outPoints[pointIdx++] = laser::ILDAPoint(
                static_cast<int16_t>(laser::clamp(xRight, -1.0f, 1.0f) * 32767.0f),
                static_cast<int16_t>(laser::clamp(yBottom, -1.0f, 1.0f) * 32767.0f),
                r_val, g_val, b_val, false);
    }

    return pointIdx;
}

int SuperLaserScan::renderBioSpiral(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int maxPoints)
{
    int numPoints = std::min(beam.pointDensity * 2, maxPoints);

    float hrv = bioData_.hrv.load(std::memory_order_acquire);
    float coherence = bioData_.coherence.load(std::memory_order_acquire);
    float breathPhase = bioData_.breathPhase.load(std::memory_order_acquire) ? 1.0f : 0.0f;

    float revolutions = 3.0f + hrv * 4.0f;
    float sizeMod = 0.5f + coherence * 0.5f;
    float breathMod = 0.8f + breathPhase * 0.4f;

    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    for (int i = 0; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints;
        float angle = t * laser::kTwoPi * revolutions + beam.phase;
        float radius = beam.size * t * sizeMod * breathMod;

        float x = beam.x + laser::fastCos(angle, sinTable_.data()) * radius;
        float y = beam.y + laser::fastSin(angle, sinTable_.data()) * radius;

        // Bio-reactive colors (coherence = green, stress = red)
        float stress = bioData_.stress.load(std::memory_order_acquire);
        uint8_t r_val = static_cast<uint8_t>(stress * beam.brightness * 255.0f);
        uint8_t g_val = static_cast<uint8_t>(coherence * beam.brightness * 255.0f);
        uint8_t b_val = static_cast<uint8_t>((1.0f - stress) * hrv * beam.brightness * 255.0f);

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = 0;
        outPoints[i].r = r_val;
        outPoints[i].g = g_val;
        outPoints[i].b = b_val;
        outPoints[i].status = (i == 0) ? laser::ILDAPoint::kBlankingBit : 0;
    }

    return numPoints;
}

//==============================================================================
// Modulation
//==============================================================================

void SuperLaserScan::applyAudioModulation(laser::BeamConfig& beam)
{
    float bass = audioData_.bassLevel.load(std::memory_order_acquire);
    float mid = audioData_.midLevel.load(std::memory_order_acquire);
    float high = audioData_.highLevel.load(std::memory_order_acquire);
    float peak = audioData_.peakLevel.load(std::memory_order_acquire);

    // Size modulation from bass
    beam.size *= (1.0f + bass * 0.5f);

    // Rotation speed from mid frequencies
    beam.rotationSpeed += mid * 2.0f;

    // Brightness from peak
    beam.brightness = laser::clamp(beam.brightness * (0.5f + peak), 0.0f, 1.0f);

    // Color shift from high frequencies
    if (high > 0.5f)
    {
        float shift = (high - 0.5f) * 2.0f;
        beam.blue = laser::clamp(beam.blue + shift * 0.3f, 0.0f, 1.0f);
    }

    // Beat pulse
    if (audioData_.beatDetected.load(std::memory_order_acquire))
    {
        beam.brightness = 1.0f;
        audioData_.beatDetected.store(false, std::memory_order_release);
    }
}

void SuperLaserScan::applyBioModulation(laser::BeamConfig& beam)
{
    float hrv = bioData_.hrv.load(std::memory_order_acquire);
    float coherence = bioData_.coherence.load(std::memory_order_acquire);
    float stress = bioData_.stress.load(std::memory_order_acquire);

    // Smooth size changes with HRV
    beam.size *= (0.7f + hrv * 0.6f);

    // Rotation influenced by coherence (high coherence = smooth rotation)
    beam.rotationSpeed *= (0.5f + coherence);

    // Color shift based on stress
    if (stress > 0.6f)
    {
        beam.red = laser::clamp(beam.red + (stress - 0.6f), 0.0f, 1.0f);
        beam.green *= (1.0f - (stress - 0.6f) * 0.5f);
    }
    else if (coherence > 0.6f)
    {
        beam.green = laser::clamp(beam.green + (coherence - 0.6f), 0.0f, 1.0f);
        beam.blue = laser::clamp(beam.blue + (coherence - 0.6f) * 0.5f, 0.0f, 1.0f);
    }

    // Heartbeat pulse
    if (bioData_.heartbeatPulse.load(std::memory_order_acquire))
    {
        beam.brightness = laser::clamp(beam.brightness * 1.3f, 0.0f, 1.0f);
        bioData_.heartbeatPulse.store(false, std::memory_order_release);
    }
}

//==============================================================================
// Audio/Bio Data Input
//==============================================================================

void SuperLaserScan::updateAudioSpectrum(const float* data, int numBins)
{
    int copyCount = std::min(numBins, 512);
    std::memcpy(audioData_.spectrum.data(), data, copyCount * sizeof(float));
}

void SuperLaserScan::updateAudioWaveform(const float* data, int numSamples)
{
    int copyCount = std::min(numSamples, 1024);
    std::memcpy(audioData_.waveform.data(), data, copyCount * sizeof(float));
}

void SuperLaserScan::updateAudioLevels(float peak, float rms, float bass, float mid, float high)
{
    audioData_.peakLevel.store(peak, std::memory_order_release);
    audioData_.rmsLevel.store(rms, std::memory_order_release);
    audioData_.bassLevel.store(bass, std::memory_order_release);
    audioData_.midLevel.store(mid, std::memory_order_release);
    audioData_.highLevel.store(high, std::memory_order_release);
}

void SuperLaserScan::triggerBeat()
{
    audioData_.beatDetected.store(true, std::memory_order_release);
}

void SuperLaserScan::setBioData(float hrv, float coherence, float heartRate, float breathingRate, float stress)
{
    bioData_.hrv.store(laser::clamp(hrv, 0.0f, 1.0f), std::memory_order_release);
    bioData_.coherence.store(laser::clamp(coherence, 0.0f, 1.0f), std::memory_order_release);
    bioData_.heartRate.store(heartRate, std::memory_order_release);
    bioData_.breathingRate.store(breathingRate, std::memory_order_release);
    bioData_.stress.store(laser::clamp(stress, 0.0f, 1.0f), std::memory_order_release);
}

void SuperLaserScan::setBioReactiveEnabled(bool enabled) noexcept
{
    bioEnabled_.store(enabled, std::memory_order_release);
}

void SuperLaserScan::triggerHeartbeat()
{
    bioData_.heartbeatPulse.store(true, std::memory_order_release);
}

void SuperLaserScan::setBreathPhase(bool inhaling)
{
    bioData_.breathPhase.store(inhaling, std::memory_order_release);
}

//==============================================================================
// Optimization Passes
//==============================================================================

void SuperLaserScan::optimizeBlankingPoints(laser::ILDAPoint* points, int& numPoints)
{
    if (numPoints < 3)
        return;

    int level = blankingOptimization_.load(std::memory_order_acquire);

    // Insert blank points for long jumps to allow galvo settling
    constexpr int16_t jumpThreshold = 8000;  // ~25% of range
    std::array<laser::ILDAPoint, laser::kMaxPointsPerFrame> optimized;
    int outIdx = 0;

    for (int i = 0; i < numPoints && outIdx < laser::kMaxPointsPerFrame - 4; ++i)
    {
        if (i > 0)
        {
            int16_t dx = points[i].x - points[i - 1].x;
            int16_t dy = points[i].y - points[i - 1].y;
            int32_t dist = static_cast<int32_t>(dx) * dx + static_cast<int32_t>(dy) * dy;

            if (dist > jumpThreshold * jumpThreshold)
            {
                // Insert blank transition points
                int numBlanks = (level == 2) ? 3 : 1;
                for (int b = 0; b < numBlanks && outIdx < laser::kMaxPointsPerFrame; ++b)
                {
                    float t = static_cast<float>(b + 1) / (numBlanks + 1);
                    optimized[outIdx] = laser::ILDAPoint::interpolate(points[i - 1], points[i], t);
                    optimized[outIdx].status |= laser::ILDAPoint::kBlankingBit;
                    ++outIdx;
                }
            }
        }

        optimized[outIdx++] = points[i];
    }

    std::memcpy(points, optimized.data(), outIdx * sizeof(laser::ILDAPoint));
    numPoints = outIdx;
}

void SuperLaserScan::applyGalvoLimits(laser::ILDAPoint* points, int& numPoints)
{
    if (numPoints < 2)
        return;

    float maxAccel = maxGalvoAcceleration_.load(std::memory_order_acquire);
    if (maxAccel <= 0.0f)
        return;

    // Limit point-to-point acceleration for smoother galvo movement
    float maxDelta = maxAccel / targetFPS_;
    int16_t maxDeltaInt = static_cast<int16_t>(maxDelta);

    for (int i = 1; i < numPoints; ++i)
    {
        int16_t dx = points[i].x - points[i - 1].x;
        int16_t dy = points[i].y - points[i - 1].y;

        if (std::abs(dx) > maxDeltaInt)
        {
            points[i].x = points[i - 1].x + (dx > 0 ? maxDeltaInt : -maxDeltaInt);
        }
        if (std::abs(dy) > maxDeltaInt)
        {
            points[i].y = points[i - 1].y + (dy > 0 ? maxDeltaInt : -maxDeltaInt);
        }
    }
}

void SuperLaserScan::applySafetyLimits(laser::ILDAPoint* points, int& numPoints)
{
    // Limit total points per frame based on scan speed
    int maxPoints = static_cast<int>(safetyConfig_.maxScanSpeedPPS / targetFPS_);
    if (numPoints > maxPoints)
    {
        numPoints = maxPoints;
    }

    // Clamp all coordinates to safe range
    for (int i = 0; i < numPoints; ++i)
    {
        points[i].x = laser::clamp(points[i].x, static_cast<int16_t>(-32000), static_cast<int16_t>(32000));
        points[i].y = laser::clamp(points[i].y, static_cast<int16_t>(-32000), static_cast<int16_t>(32000));

        // Limit total color power
        int totalPower = points[i].r + points[i].g + points[i].b;
        if (totalPower > 255)
        {
            float scale = 255.0f / totalPower;
            points[i].r = static_cast<uint8_t>(points[i].r * scale);
            points[i].g = static_cast<uint8_t>(points[i].g * scale);
            points[i].b = static_cast<uint8_t>(points[i].b * scale);
        }
    }
}

int SuperLaserScan::calculateAdaptivePointCount(const laser::BeamConfig& beam) const
{
    // Adjust point count based on size and scan speed limits
    float baseDensity = static_cast<float>(beam.pointDensity);
    float sizeFactor = std::max(0.1f, beam.size);

    // More points for larger shapes
    float adjusted = baseDensity * sizeFactor;

    // Limit based on frame rate and scan speed
    float maxPointsPerFrame = safetyConfig_.maxScanSpeedPPS / targetFPS_;
    float beamShare = maxPointsPerFrame / std::max(1.0f, static_cast<float>(numBeams_.load(std::memory_order_acquire)));

    return static_cast<int>(std::min(adjusted, beamShare));
}

//==============================================================================
// Presets
//==============================================================================

std::vector<std::string> SuperLaserScan::getBuiltInPresets() const
{
    return {
        "Audio Tunnel",
        "Bio-Reactive Spiral",
        "Spectrum Circle",
        "Laser Grid",
        "Starfield",
        "Waveform Flow",
        "Cyberpunk Helix",
        "Zen Breathing",
        "Beat Pulse",
        "Rainbow Lissajous"
    };
}

void SuperLaserScan::loadPreset(const std::string& name)
{
    clearBeams();

    laser::BeamConfig beam;

    if (name == "Audio Tunnel")
    {
        beam.pattern = laser::PatternType::Tunnel;
        beam.size = 0.7f;
        beam.rotationSpeed = 0.5f;
        beam.audioReactive = true;
        beam.red = 0.0f;
        beam.green = 1.0f;
        beam.blue = 1.0f;
        beam.pointDensity = 200;
        addBeam(beam);
    }
    else if (name == "Bio-Reactive Spiral")
    {
        beam.pattern = laser::PatternType::BioSpiral;
        beam.size = 0.8f;
        beam.rotationSpeed = 0.3f;
        beam.bioReactive = true;
        beam.red = 1.0f;
        beam.green = 0.0f;
        beam.blue = 1.0f;
        beam.pointDensity = 300;
        addBeam(beam);
    }
    else if (name == "Spectrum Circle")
    {
        beam.pattern = laser::PatternType::Circle;
        beam.size = 0.6f;
        beam.audioReactive = true;
        beam.red = 1.0f;
        beam.green = 1.0f;
        beam.blue = 0.0f;
        beam.pointDensity = 100;
        addBeam(beam);
    }
    else if (name == "Laser Grid")
    {
        beam.pattern = laser::PatternType::Grid;
        beam.size = 0.8f;
        beam.segments = 8;
        beam.red = 0.0f;
        beam.green = 1.0f;
        beam.blue = 0.0f;
        beam.pointDensity = 400;
        addBeam(beam);
    }
    else if (name == "Starfield")
    {
        for (int i = 0; i < 5; ++i)
        {
            beam.pattern = laser::PatternType::Star;
            beam.x = -0.6f + i * 0.3f;
            beam.y = 0.0f;
            beam.size = 0.15f + i * 0.05f;
            beam.segments = 5 + i;
            beam.rotationSpeed = 0.5f - i * 0.1f;
            beam.red = (i % 3 == 0) ? 1.0f : 0.3f;
            beam.green = (i % 3 == 1) ? 1.0f : 0.3f;
            beam.blue = (i % 3 == 2) ? 1.0f : 0.3f;
            beam.pointDensity = 50;
            addBeam(beam);
        }
    }
    else if (name == "Waveform Flow")
    {
        beam.pattern = laser::PatternType::AudioWaveform;
        beam.size = 0.8f;
        beam.red = 0.0f;
        beam.green = 0.8f;
        beam.blue = 1.0f;
        beam.pointDensity = 200;
        addBeam(beam);
    }
    else if (name == "Cyberpunk Helix")
    {
        beam.pattern = laser::PatternType::Helix;
        beam.size = 0.7f;
        beam.rotationSpeed = 1.0f;
        beam.audioReactive = true;
        beam.pointDensity = 300;
        addBeam(beam);
    }
    else if (name == "Zen Breathing")
    {
        beam.pattern = laser::PatternType::BioBreath;
        beam.size = 0.6f;
        beam.bioReactive = true;
        beam.red = 0.2f;
        beam.green = 0.8f;
        beam.blue = 0.4f;
        beam.pointDensity = 150;
        addBeam(beam);
    }
    else if (name == "Beat Pulse")
    {
        beam.pattern = laser::PatternType::AudioPulse;
        beam.size = 0.5f;
        beam.audioReactive = true;
        beam.red = 1.0f;
        beam.green = 0.2f;
        beam.blue = 0.2f;
        beam.pointDensity = 100;
        addBeam(beam);
    }
    else if (name == "Rainbow Lissajous")
    {
        beam.pattern = laser::PatternType::Lissajous;
        beam.size = 0.7f;
        beam.frequency = 3.0f;
        beam.rotationSpeed = 0.2f;
        beam.red = 1.0f;
        beam.green = 0.5f;
        beam.blue = 0.0f;
        beam.pointDensity = 400;
        addBeam(beam);
    }
}

//==============================================================================
// Performance Metrics
//==============================================================================

laser::MetricsSnapshot SuperLaserScan::getMetrics() const noexcept
{
    return metrics_.snapshot();
}

void SuperLaserScan::resetMetrics() noexcept
{
    metrics_.reset();
}

//==============================================================================
// Callbacks
//==============================================================================

void SuperLaserScan::setFrameCallback(laser::FrameCallback callback)
{
    frameCallback_ = std::move(callback);
}

void SuperLaserScan::setErrorCallback(laser::ErrorCallback callback)
{
    errorCallback_ = std::move(callback);
}

//==============================================================================
// Quality Settings
//==============================================================================

void SuperLaserScan::setInterpolationQuality(int quality) noexcept
{
    interpolationQuality_.store(laser::clamp(quality, 0, 2), std::memory_order_release);
}

void SuperLaserScan::setBlankingOptimization(int level) noexcept
{
    blankingOptimization_.store(laser::clamp(level, 0, 2), std::memory_order_release);
}

void SuperLaserScan::setGalvoAcceleration(float maxAcceleration) noexcept
{
    maxGalvoAcceleration_.store(std::max(0.0f, maxAcceleration), std::memory_order_release);
}

void SuperLaserScan::setAdaptivePointDensity(bool enabled) noexcept
{
    adaptivePointDensity_.store(enabled, std::memory_order_release);
}

//==============================================================================
// Output
//==============================================================================

void SuperLaserScan::sendFrame()
{
    if (!outputEnabled_.load(std::memory_order_acquire))
        return;

    int numPoints;
    const laser::ILDAPoint* points = getCurrentFrame(numPoints);

    for (const auto& output : outputs_)
    {
        if (!output.enabled)
            continue;

        std::vector<uint8_t> data;

        if (std::strncmp(output.protocol.data(), "ILDA", 4) == 0)
        {
            data = convertToILDA(points, numPoints);
        }
        else if (std::strncmp(output.protocol.data(), "DMX", 3) == 0)
        {
            data = convertToDMX(points, numPoints);
        }

        sendToOutput(output, data);
    }
}

std::vector<uint8_t> SuperLaserScan::convertToILDA(const laser::ILDAPoint* points, int numPoints)
{
    std::vector<uint8_t> data;
    data.reserve(4 + numPoints * 8);

    // ILDA header
    data.push_back('I');
    data.push_back('L');
    data.push_back('D');
    data.push_back('A');

    // Point data
    for (int i = 0; i < numPoints; ++i)
    {
        data.push_back(static_cast<uint8_t>((points[i].x >> 8) & 0xFF));
        data.push_back(static_cast<uint8_t>(points[i].x & 0xFF));
        data.push_back(static_cast<uint8_t>((points[i].y >> 8) & 0xFF));
        data.push_back(static_cast<uint8_t>(points[i].y & 0xFF));
        data.push_back(points[i].status);
        data.push_back(points[i].r);
        data.push_back(points[i].g);
        data.push_back(points[i].b);
    }

    return data;
}

std::vector<uint8_t> SuperLaserScan::convertToDMX(const laser::ILDAPoint* points, int numPoints)
{
    std::vector<uint8_t> data(512, 0);

    if (numPoints > 0)
    {
        data[0] = static_cast<uint8_t>((points[0].x + 32768) / 256);
        data[1] = static_cast<uint8_t>((points[0].y + 32768) / 256);
        data[2] = points[0].r;
        data[3] = points[0].g;
        data[4] = points[0].b;
    }

    return data;
}

void SuperLaserScan::sendToOutput(const laser::OutputConfig& output, const std::vector<uint8_t>& data)
{
    // Network output implementation would go here
    // Using output.ipAddress and output.port
    (void)output;
    (void)data;
}

//==============================================================================
// SIMD Implementations
//==============================================================================

#if defined(LASER_USE_SSE2)
void SuperLaserScan::renderCircleSIMD_SSE2(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int numPoints)
{
    float rotation = beam.rotation;
    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    __m128 vBeamX = _mm_set1_ps(beam.x);
    __m128 vBeamY = _mm_set1_ps(beam.y);
    __m128 vSize = _mm_set1_ps(beam.size);
    __m128 vScale = _mm_set1_ps(32767.0f);
    __m128 vTwoPi = _mm_set1_ps(laser::kTwoPi);
    __m128 vRotation = _mm_set1_ps(rotation);
    __m128 vInvN = _mm_set1_ps(invNumPoints);

    // Process 4 points at a time
    for (int i = 0; i < numPoints - 3; i += 4)
    {
        __m128 vIdx = _mm_set_ps(
            static_cast<float>(i + 3),
            static_cast<float>(i + 2),
            static_cast<float>(i + 1),
            static_cast<float>(i + 0)
        );

        __m128 vT = _mm_mul_ps(vIdx, vInvN);
        __m128 vAngle = _mm_add_ps(_mm_mul_ps(vT, vTwoPi), vRotation);

        // Approximate sin/cos using polynomial (faster than lookup for SIMD)
        // sin(x) ~ x - x^3/6 + x^5/120 (for small x)
        // Normalize angle to [-pi, pi]
        __m128 vPi = _mm_set1_ps(laser::kPi);
        __m128 vNormAngle = vAngle;

        // Simple cos/sin approximation
        __m128 vCos, vSin;

        // For now, use scalar sin/cos (full SIMD trig would need more code)
        float angles[4], cosVals[4], sinVals[4];
        _mm_storeu_ps(angles, vAngle);
        for (int j = 0; j < 4; ++j)
        {
            cosVals[j] = std::cos(angles[j]);
            sinVals[j] = std::sin(angles[j]);
        }
        vCos = _mm_loadu_ps(cosVals);
        vSin = _mm_loadu_ps(sinVals);

        __m128 vX = _mm_add_ps(vBeamX, _mm_mul_ps(vCos, vSize));
        __m128 vY = _mm_add_ps(vBeamY, _mm_mul_ps(vSin, vSize));

        // Scale to int16 range
        __m128 vXScaled = _mm_mul_ps(vX, vScale);
        __m128 vYScaled = _mm_mul_ps(vY, vScale);

        // Store results
        float xResults[4], yResults[4];
        _mm_storeu_ps(xResults, vXScaled);
        _mm_storeu_ps(yResults, vYScaled);

        for (int j = 0; j < 4; ++j)
        {
            outPoints[i + j].x = static_cast<int16_t>(laser::clamp(xResults[j], -32767.0f, 32767.0f));
            outPoints[i + j].y = static_cast<int16_t>(laser::clamp(yResults[j], -32767.0f, 32767.0f));
            outPoints[i + j].z = 0;
        }
    }

    // Handle remaining points
    for (int i = (numPoints / 4) * 4; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints;
        float angle = t * laser::kTwoPi + rotation;
        float x = beam.x + std::cos(angle) * beam.size;
        float y = beam.y + std::sin(angle) * beam.size;

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = 0;
    }
}
#endif

#if defined(LASER_USE_AVX2)
void SuperLaserScan::renderCircleSIMD_AVX2(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int numPoints)
{
    // AVX2 processes 8 floats at a time
    float rotation = beam.rotation;
    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    __m256 vBeamX = _mm256_set1_ps(beam.x);
    __m256 vBeamY = _mm256_set1_ps(beam.y);
    __m256 vSize = _mm256_set1_ps(beam.size);
    __m256 vScale = _mm256_set1_ps(32767.0f);
    __m256 vTwoPi = _mm256_set1_ps(laser::kTwoPi);
    __m256 vRotation = _mm256_set1_ps(rotation);
    __m256 vInvN = _mm256_set1_ps(invNumPoints);

    for (int i = 0; i < numPoints - 7; i += 8)
    {
        __m256 vIdx = _mm256_set_ps(
            static_cast<float>(i + 7), static_cast<float>(i + 6),
            static_cast<float>(i + 5), static_cast<float>(i + 4),
            static_cast<float>(i + 3), static_cast<float>(i + 2),
            static_cast<float>(i + 1), static_cast<float>(i + 0)
        );

        __m256 vT = _mm256_mul_ps(vIdx, vInvN);
        __m256 vAngle = _mm256_add_ps(_mm256_mul_ps(vT, vTwoPi), vRotation);

        float angles[8], cosVals[8], sinVals[8];
        _mm256_storeu_ps(angles, vAngle);
        for (int j = 0; j < 8; ++j)
        {
            cosVals[j] = std::cos(angles[j]);
            sinVals[j] = std::sin(angles[j]);
        }

        __m256 vCos = _mm256_loadu_ps(cosVals);
        __m256 vSin = _mm256_loadu_ps(sinVals);

        __m256 vX = _mm256_add_ps(vBeamX, _mm256_mul_ps(vCos, vSize));
        __m256 vY = _mm256_add_ps(vBeamY, _mm256_mul_ps(vSin, vSize));

        __m256 vXScaled = _mm256_mul_ps(vX, vScale);
        __m256 vYScaled = _mm256_mul_ps(vY, vScale);

        float xResults[8], yResults[8];
        _mm256_storeu_ps(xResults, vXScaled);
        _mm256_storeu_ps(yResults, vYScaled);

        for (int j = 0; j < 8; ++j)
        {
            outPoints[i + j].x = static_cast<int16_t>(laser::clamp(xResults[j], -32767.0f, 32767.0f));
            outPoints[i + j].y = static_cast<int16_t>(laser::clamp(yResults[j], -32767.0f, 32767.0f));
            outPoints[i + j].z = 0;
        }
    }

    // Handle remaining points
    for (int i = (numPoints / 8) * 8; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints;
        float angle = t * laser::kTwoPi + rotation;
        float x = beam.x + std::cos(angle) * beam.size;
        float y = beam.y + std::sin(angle) * beam.size;

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = 0;
    }
}
#endif

#if defined(LASER_USE_NEON)
void SuperLaserScan::renderCircleSIMD_NEON(const laser::BeamConfig& beam, laser::ILDAPoint* outPoints, int numPoints)
{
    float rotation = beam.rotation;
    float invNumPoints = 1.0f / static_cast<float>(numPoints);

    float32x4_t vBeamX = vdupq_n_f32(beam.x);
    float32x4_t vBeamY = vdupq_n_f32(beam.y);
    float32x4_t vSize = vdupq_n_f32(beam.size);
    float32x4_t vScale = vdupq_n_f32(32767.0f);
    float32x4_t vTwoPi = vdupq_n_f32(laser::kTwoPi);
    float32x4_t vRotation = vdupq_n_f32(rotation);
    float32x4_t vInvN = vdupq_n_f32(invNumPoints);

    for (int i = 0; i < numPoints - 3; i += 4)
    {
        float indices[4] = {
            static_cast<float>(i + 0), static_cast<float>(i + 1),
            static_cast<float>(i + 2), static_cast<float>(i + 3)
        };
        float32x4_t vIdx = vld1q_f32(indices);

        float32x4_t vT = vmulq_f32(vIdx, vInvN);
        float32x4_t vAngle = vaddq_f32(vmulq_f32(vT, vTwoPi), vRotation);

        float angles[4], cosVals[4], sinVals[4];
        vst1q_f32(angles, vAngle);
        for (int j = 0; j < 4; ++j)
        {
            cosVals[j] = std::cos(angles[j]);
            sinVals[j] = std::sin(angles[j]);
        }

        float32x4_t vCos = vld1q_f32(cosVals);
        float32x4_t vSin = vld1q_f32(sinVals);

        float32x4_t vX = vaddq_f32(vBeamX, vmulq_f32(vCos, vSize));
        float32x4_t vY = vaddq_f32(vBeamY, vmulq_f32(vSin, vSize));

        float32x4_t vXScaled = vmulq_f32(vX, vScale);
        float32x4_t vYScaled = vmulq_f32(vY, vScale);

        float xResults[4], yResults[4];
        vst1q_f32(xResults, vXScaled);
        vst1q_f32(yResults, vYScaled);

        for (int j = 0; j < 4; ++j)
        {
            outPoints[i + j].x = static_cast<int16_t>(laser::clamp(xResults[j], -32767.0f, 32767.0f));
            outPoints[i + j].y = static_cast<int16_t>(laser::clamp(yResults[j], -32767.0f, 32767.0f));
            outPoints[i + j].z = 0;
        }
    }

    // Handle remaining points
    for (int i = (numPoints / 4) * 4; i < numPoints; ++i)
    {
        float t = static_cast<float>(i) * invNumPoints;
        float angle = t * laser::kTwoPi + rotation;
        float x = beam.x + std::cos(angle) * beam.size;
        float y = beam.y + std::sin(angle) * beam.size;

        outPoints[i].x = static_cast<int16_t>(laser::clamp(x, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].y = static_cast<int16_t>(laser::clamp(y, -1.0f, 1.0f) * 32767.0f);
        outPoints[i].z = 0;
    }
}
#endif

void SuperLaserScan::transformPointsSIMD(laser::ILDAPoint* points, int numPoints, float xOffset, float yOffset, float scale, float rotation)
{
    float cosR = std::cos(rotation);
    float sinR = std::sin(rotation);

    for (int i = 0; i < numPoints; ++i)
    {
        float x = static_cast<float>(points[i].x) / 32767.0f;
        float y = static_cast<float>(points[i].y) / 32767.0f;

        // Scale
        x *= scale;
        y *= scale;

        // Rotate
        float rx = x * cosR - y * sinR;
        float ry = x * sinR + y * cosR;

        // Translate
        rx += xOffset;
        ry += yOffset;

        points[i].x = static_cast<int16_t>(laser::clamp(rx, -1.0f, 1.0f) * 32767.0f);
        points[i].y = static_cast<int16_t>(laser::clamp(ry, -1.0f, 1.0f) * 32767.0f);
    }
}
