/**
 * SpatialAudioProcessor.cpp
 *
 * Professional spatial audio processing with HRTF, Ambisonics, and bio-reactive positioning
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE
 */

#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <cmath>
#include <algorithm>
#include <cstdint>
#include <array>
#include <complex>
#include <map>

namespace Echoelmusic {
namespace Spatial {

// ============================================================================
// 3D Vector and Position Types
// ============================================================================

struct Vector3D {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    Vector3D() = default;
    Vector3D(float x_, float y_, float z_) : x(x_), y(y_), z(z_) {}

    float length() const {
        return std::sqrt(x * x + y * y + z * z);
    }

    Vector3D normalized() const {
        float len = length();
        if (len < 1e-10f) return {0, 0, 1};
        return {x / len, y / len, z / len};
    }

    Vector3D operator+(const Vector3D& other) const {
        return {x + other.x, y + other.y, z + other.z};
    }

    Vector3D operator-(const Vector3D& other) const {
        return {x - other.x, y - other.y, z - other.z};
    }

    Vector3D operator*(float scalar) const {
        return {x * scalar, y * scalar, z * scalar};
    }

    float dot(const Vector3D& other) const {
        return x * other.x + y * other.y + z * other.z;
    }

    Vector3D cross(const Vector3D& other) const {
        return {
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        };
    }
};

struct SphericalPosition {
    float azimuth = 0.0f;    // Horizontal angle (-180 to 180 degrees)
    float elevation = 0.0f;  // Vertical angle (-90 to 90 degrees)
    float distance = 1.0f;   // Distance in meters

    static SphericalPosition fromCartesian(const Vector3D& v) {
        SphericalPosition pos;
        pos.distance = v.length();
        if (pos.distance < 1e-10f) return pos;

        pos.azimuth = std::atan2(v.x, v.z) * 180.0f / M_PI;
        pos.elevation = std::asin(std::clamp(v.y / pos.distance, -1.0f, 1.0f)) * 180.0f / M_PI;
        return pos;
    }

    Vector3D toCartesian() const {
        float azRad = azimuth * M_PI / 180.0f;
        float elRad = elevation * M_PI / 180.0f;
        return {
            distance * std::cos(elRad) * std::sin(azRad),
            distance * std::sin(elRad),
            distance * std::cos(elRad) * std::cos(azRad)
        };
    }
};

// ============================================================================
// HRTF (Head-Related Transfer Function) Processor
// ============================================================================

class HRTFProcessor {
public:
    static constexpr int HRTF_LENGTH = 512;
    static constexpr int NUM_AZIMUTHS = 72;   // 5-degree resolution
    static constexpr int NUM_ELEVATIONS = 19; // -45 to 90 degrees

    HRTFProcessor(int sampleRate) : sampleRate_(sampleRate) {
        // Initialize HRTF filters
        generateMITKemarHRTF();
        initializeConvolutionBuffers();
    }

    // Process mono input to binaural stereo output
    void process(const float* input, float* leftOut, float* rightOut,
                 int numSamples, const SphericalPosition& position) {

        // Get interpolated HRTF filters for position
        auto [leftHRTF, rightHRTF] = getInterpolatedHRTF(position.azimuth, position.elevation);

        // Apply distance attenuation
        float distanceGain = calculateDistanceAttenuation(position.distance);

        // Convolve with HRTF
        for (int i = 0; i < numSamples; i++) {
            float sample = input[i] * distanceGain;

            // Overlap-add convolution
            float leftSum = 0.0f;
            float rightSum = 0.0f;

            // Simple direct convolution (real implementation uses FFT)
            for (int j = 0; j < std::min(HRTF_LENGTH, numSamples - i); j++) {
                leftSum += sample * leftHRTF[j];
                rightSum += sample * rightHRTF[j];
            }

            leftOut[i] = leftSum;
            rightOut[i] = rightSum;
        }

        // Apply ITD (Interaural Time Difference)
        applyITD(leftOut, rightOut, numSamples, position.azimuth);
    }

    // Process with head tracking
    void processWithHeadTracking(const float* input, float* leftOut, float* rightOut,
                                  int numSamples, const SphericalPosition& sourcePos,
                                  const Vector3D& headOrientation) {
        // Transform source position relative to head orientation
        SphericalPosition relativePos = transformToHeadSpace(sourcePos, headOrientation);
        process(input, leftOut, rightOut, numSamples, relativePos);
    }

private:
    void generateMITKemarHRTF() {
        // Generate simplified HRTF database
        // Real implementation would load MIT KEMAR or CIPIC database

        for (int az = 0; az < NUM_AZIMUTHS; az++) {
            for (int el = 0; el < NUM_ELEVATIONS; el++) {
                float azimuth = (az - NUM_AZIMUTHS / 2) * 5.0f;  // -180 to 175
                float elevation = (el - 9) * 7.5f;  // -67.5 to 67.5

                // Generate simplified impulse response
                std::vector<float> leftIR(HRTF_LENGTH, 0.0f);
                std::vector<float> rightIR(HRTF_LENGTH, 0.0f);

                // Model head shadow and pinna effects
                generateHRTFForPosition(leftIR.data(), rightIR.data(), azimuth, elevation);

                hrtfDatabase_[az][el] = {leftIR, rightIR};
            }
        }
    }

    void generateHRTFForPosition(float* leftIR, float* rightIR, float azimuth, float elevation) {
        float azRad = azimuth * M_PI / 180.0f;
        float elRad = elevation * M_PI / 180.0f;

        // Head radius (approximately 8.75 cm)
        const float headRadius = 0.0875f;
        const float soundSpeed = 343.0f;

        // Calculate ILD (Interaural Level Difference) based on head shadow
        float ild = std::sin(azRad) * (1.0f + 0.5f * std::cos(elRad));

        // Generate minimum-phase IR approximation
        for (int i = 0; i < HRTF_LENGTH; i++) {
            float t = static_cast<float>(i) / sampleRate_;

            // Simple model: direct path + pinna reflection
            float direct = (i == 0) ? 1.0f : 0.0f;
            float reflection = 0.0f;

            // Pinna notch (concha resonance around 4-5 kHz, elevation dependent)
            float pinnaNtochDelay = 0.0001f + 0.00005f * (1.0f - std::abs(std::sin(elRad)));
            int notchSample = static_cast<int>(pinnaNtochDelay * sampleRate_);
            if (i == notchSample) {
                reflection = -0.3f * (1.0f - std::abs(std::sin(elRad)));
            }

            // Apply ILD
            float leftGain = 1.0f - std::max(0.0f, ild * 0.3f);
            float rightGain = 1.0f + std::max(0.0f, -ild * 0.3f);

            leftIR[i] = (direct + reflection) * leftGain;
            rightIR[i] = (direct + reflection) * rightGain;
        }

        // Apply low-pass filter for head shadow (contralateral ear)
        if (azimuth > 0) {
            applyHeadShadowFilter(rightIR, HRTF_LENGTH, azimuth);
        } else {
            applyHeadShadowFilter(leftIR, HRTF_LENGTH, -azimuth);
        }
    }

    void applyHeadShadowFilter(float* ir, int length, float azimuth) {
        // Simple first-order low-pass for head shadow
        float cutoff = 10000.0f - std::abs(azimuth) * 50.0f;  // Lower cutoff for more shadow
        float alpha = std::exp(-2.0f * M_PI * cutoff / sampleRate_);

        float prev = 0.0f;
        for (int i = 0; i < length; i++) {
            ir[i] = alpha * prev + (1.0f - alpha) * ir[i];
            prev = ir[i];
        }
    }

    std::pair<std::vector<float>, std::vector<float>> getInterpolatedHRTF(float azimuth, float elevation) {
        // Normalize angles
        while (azimuth < -180.0f) azimuth += 360.0f;
        while (azimuth > 180.0f) azimuth -= 360.0f;
        elevation = std::clamp(elevation, -67.5f, 67.5f);

        // Find nearest HRTF indices
        int azIdx = static_cast<int>((azimuth + 180.0f) / 5.0f) % NUM_AZIMUTHS;
        int elIdx = static_cast<int>((elevation + 67.5f) / 7.5f);
        elIdx = std::clamp(elIdx, 0, NUM_ELEVATIONS - 1);

        return hrtfDatabase_[azIdx][elIdx];
    }

    void initializeConvolutionBuffers() {
        inputBuffer_.resize(HRTF_LENGTH * 2, 0.0f);
        outputBufferL_.resize(HRTF_LENGTH * 2, 0.0f);
        outputBufferR_.resize(HRTF_LENGTH * 2, 0.0f);
    }

    float calculateDistanceAttenuation(float distance) {
        // Inverse square law with minimum distance clamp
        const float minDistance = 0.3f;  // 30 cm
        const float referenceDistance = 1.0f;

        distance = std::max(distance, minDistance);
        return referenceDistance / distance;
    }

    void applyITD(float* leftOut, float* rightOut, int numSamples, float azimuth) {
        // Calculate ITD in samples
        const float headRadius = 0.0875f;
        const float soundSpeed = 343.0f;

        float azRad = azimuth * M_PI / 180.0f;
        float itdSeconds = (headRadius / soundSpeed) * (azRad + std::sin(azRad));
        int itdSamples = static_cast<int>(std::abs(itdSeconds) * sampleRate_);

        // Apply delay to appropriate ear
        if (azimuth > 0) {
            // Sound from right - delay right ear
            delayBuffer(rightOut, numSamples, itdSamples);
        } else if (azimuth < 0) {
            // Sound from left - delay left ear
            delayBuffer(leftOut, numSamples, itdSamples);
        }
    }

    void delayBuffer(float* buffer, int numSamples, int delaySamples) {
        if (delaySamples <= 0 || delaySamples >= numSamples) return;

        // Shift samples
        for (int i = numSamples - 1; i >= delaySamples; i--) {
            buffer[i] = buffer[i - delaySamples];
        }
        for (int i = 0; i < delaySamples; i++) {
            buffer[i] = 0.0f;
        }
    }

    SphericalPosition transformToHeadSpace(const SphericalPosition& sourcePos,
                                            const Vector3D& headOrientation) {
        // Convert to cartesian, rotate, convert back
        Vector3D cartesian = sourcePos.toCartesian();

        // Apply head rotation (simplified yaw only)
        float yaw = std::atan2(headOrientation.x, headOrientation.z);
        float cosYaw = std::cos(-yaw);
        float sinYaw = std::sin(-yaw);

        Vector3D rotated = {
            cartesian.x * cosYaw - cartesian.z * sinYaw,
            cartesian.y,
            cartesian.x * sinYaw + cartesian.z * cosYaw
        };

        return SphericalPosition::fromCartesian(rotated);
    }

    int sampleRate_;
    std::map<int, std::map<int, std::pair<std::vector<float>, std::vector<float>>>> hrtfDatabase_;
    std::vector<float> inputBuffer_;
    std::vector<float> outputBufferL_;
    std::vector<float> outputBufferR_;
};

// ============================================================================
// Ambisonics Processor (First Order - B-Format)
// ============================================================================

class AmbisonicsProcessor {
public:
    static constexpr int NUM_CHANNELS = 4;  // W, X, Y, Z for first-order

    AmbisonicsProcessor(int sampleRate) : sampleRate_(sampleRate) {}

    // Encode mono source to B-format
    void encode(const float* input, float* bFormat[NUM_CHANNELS],
                int numSamples, const SphericalPosition& position) {

        float azRad = position.azimuth * M_PI / 180.0f;
        float elRad = position.elevation * M_PI / 180.0f;

        // Spherical harmonic coefficients for first-order
        float w = 0.707107f;  // 1/sqrt(2)
        float x = std::cos(azRad) * std::cos(elRad);
        float y = std::sin(azRad) * std::cos(elRad);
        float z = std::sin(elRad);

        // Distance attenuation
        float gain = 1.0f / std::max(0.5f, position.distance);

        for (int i = 0; i < numSamples; i++) {
            float sample = input[i] * gain;
            bFormat[0][i] += sample * w;  // W (omnidirectional)
            bFormat[1][i] += sample * x;  // X (front-back)
            bFormat[2][i] += sample * y;  // Y (left-right)
            bFormat[3][i] += sample * z;  // Z (up-down)
        }
    }

    // Decode B-format to binaural stereo
    void decodeToBinaural(float* bFormat[NUM_CHANNELS], float* leftOut, float* rightOut,
                          int numSamples) {
        // Virtual speaker positions for binaural decoding
        const SphericalPosition virtualSpeakers[] = {
            {-30.0f, 0.0f, 1.0f},   // Front left
            {30.0f, 0.0f, 1.0f},    // Front right
            {-110.0f, 0.0f, 1.0f},  // Rear left
            {110.0f, 0.0f, 1.0f}    // Rear right
        };

        // Decode to virtual speakers then apply HRTF
        for (int i = 0; i < numSamples; i++) {
            float left = 0.0f;
            float right = 0.0f;

            for (int sp = 0; sp < 4; sp++) {
                float azRad = virtualSpeakers[sp].azimuth * M_PI / 180.0f;

                // Decode coefficient
                float w = 0.707107f;
                float x = std::cos(azRad);
                float y = std::sin(azRad);

                float speakerSignal =
                    w * bFormat[0][i] +
                    x * bFormat[1][i] +
                    y * bFormat[2][i];

                // Simple panning (real impl would use HRTF)
                float pan = (virtualSpeakers[sp].azimuth + 180.0f) / 360.0f;
                left += speakerSignal * (1.0f - pan) * 0.5f;
                right += speakerSignal * pan * 0.5f;
            }

            leftOut[i] = left;
            rightOut[i] = right;
        }
    }

    // Decode to speaker array (quad, 5.1, 7.1, etc.)
    void decodeToSpeakers(float* bFormat[NUM_CHANNELS], std::vector<float*>& speakerOuts,
                          int numSamples, const std::vector<SphericalPosition>& speakerPositions) {

        for (size_t sp = 0; sp < speakerPositions.size(); sp++) {
            float azRad = speakerPositions[sp].azimuth * M_PI / 180.0f;
            float elRad = speakerPositions[sp].elevation * M_PI / 180.0f;

            // Spherical harmonic decode coefficients
            float w = 0.707107f;
            float x = std::cos(azRad) * std::cos(elRad);
            float y = std::sin(azRad) * std::cos(elRad);
            float z = std::sin(elRad);

            for (int i = 0; i < numSamples; i++) {
                speakerOuts[sp][i] =
                    w * bFormat[0][i] +
                    x * bFormat[1][i] +
                    y * bFormat[2][i] +
                    z * bFormat[3][i];
            }
        }
    }

    // Rotate B-format sound field
    void rotateSoundField(float* bFormat[NUM_CHANNELS], int numSamples,
                          float yaw, float pitch, float roll) {
        float yawRad = yaw * M_PI / 180.0f;
        float pitchRad = pitch * M_PI / 180.0f;
        float rollRad = roll * M_PI / 180.0f;

        // Build rotation matrix
        float cy = std::cos(yawRad);
        float sy = std::sin(yawRad);
        float cp = std::cos(pitchRad);
        float sp = std::sin(pitchRad);
        float cr = std::cos(rollRad);
        float sr = std::sin(rollRad);

        // Combined rotation matrix (ZYX order)
        float m[3][3] = {
            {cy * cp, cy * sp * sr - sy * cr, cy * sp * cr + sy * sr},
            {sy * cp, sy * sp * sr + cy * cr, sy * sp * cr - cy * sr},
            {-sp, cp * sr, cp * cr}
        };

        for (int i = 0; i < numSamples; i++) {
            float x = bFormat[1][i];
            float y = bFormat[2][i];
            float z = bFormat[3][i];

            bFormat[1][i] = m[0][0] * x + m[0][1] * y + m[0][2] * z;
            bFormat[2][i] = m[1][0] * x + m[1][1] * y + m[1][2] * z;
            bFormat[3][i] = m[2][0] * x + m[2][1] * y + m[2][2] * z;
        }
    }

private:
    int sampleRate_;
};

// ============================================================================
// Spatial Audio Source
// ============================================================================

class SpatialAudioSource {
public:
    SpatialAudioSource(int id) : id_(id) {}

    // Position
    void setPosition(const Vector3D& position) {
        position_ = position;
        spherical_ = SphericalPosition::fromCartesian(position);
    }

    void setPosition(const SphericalPosition& position) {
        spherical_ = position;
        position_ = position.toCartesian();
    }

    const Vector3D& position() const { return position_; }
    const SphericalPosition& sphericalPosition() const { return spherical_; }

    // Movement
    void setVelocity(const Vector3D& velocity) { velocity_ = velocity; }
    const Vector3D& velocity() const { return velocity_; }

    // Properties
    void setGain(float gain) { gain_ = gain; }
    float gain() const { return gain_; }

    void setMute(bool mute) { muted_ = mute; }
    bool isMuted() const { return muted_; }

    // Size/spread (for area sources)
    void setSize(float size) { size_ = std::max(0.0f, size); }
    float size() const { return size_; }

    // Directivity
    void setDirectivity(float directivity, float sharpness) {
        directivity_ = std::clamp(directivity, 0.0f, 1.0f);
        directivitySharpness_ = std::max(0.0f, sharpness);
    }

    // Doppler effect
    void enableDoppler(bool enable) { dopplerEnabled_ = enable; }
    bool isDopplerEnabled() const { return dopplerEnabled_; }

    int id() const { return id_; }

private:
    int id_;
    Vector3D position_;
    SphericalPosition spherical_;
    Vector3D velocity_;
    float gain_ = 1.0f;
    bool muted_ = false;
    float size_ = 0.0f;
    float directivity_ = 0.0f;
    float directivitySharpness_ = 1.0f;
    bool dopplerEnabled_ = false;
};

// ============================================================================
// Bio-Reactive Spatial Field
// ============================================================================

class BioReactiveSpatialField {
public:
    enum class FieldGeometry {
        Grid,         // Regular grid
        Fibonacci,    // Fibonacci sphere
        Orbital,      // Orbiting sources
        Breathing,    // Expand/contract with breath
        Coherence,    // Shape based on HRV coherence
        Heart         // Pulsing with heartbeat
    };

    BioReactiveSpatialField() {}

    void setGeometry(FieldGeometry geometry) { geometry_ = geometry; }
    FieldGeometry geometry() const { return geometry_; }

    // Update from biometric data
    void updateFromBio(float heartRate, float hrv, float coherence,
                       float breathPhase, float breathRate) {
        heartRate_ = heartRate;
        hrv_ = hrv;
        coherence_ = coherence;
        breathPhase_ = breathPhase;
        breathRate_ = breathRate;

        updateSourcePositions();
    }

    // Get positions for N sources
    std::vector<SphericalPosition> getSourcePositions(int numSources) {
        std::vector<SphericalPosition> positions(numSources);

        switch (geometry_) {
            case FieldGeometry::Grid:
                generateGridPositions(positions, numSources);
                break;
            case FieldGeometry::Fibonacci:
                generateFibonacciPositions(positions, numSources);
                break;
            case FieldGeometry::Orbital:
                generateOrbitalPositions(positions, numSources);
                break;
            case FieldGeometry::Breathing:
                generateBreathingPositions(positions, numSources);
                break;
            case FieldGeometry::Coherence:
                generateCoherencePositions(positions, numSources);
                break;
            case FieldGeometry::Heart:
                generateHeartPositions(positions, numSources);
                break;
        }

        return positions;
    }

private:
    void updateSourcePositions() {
        // Update internal time/phase
        time_ += 1.0f / 60.0f;  // Assume 60 Hz update rate
    }

    void generateGridPositions(std::vector<SphericalPosition>& positions, int n) {
        int rows = static_cast<int>(std::sqrt(n));
        int cols = (n + rows - 1) / rows;

        for (int i = 0; i < n; i++) {
            int row = i / cols;
            int col = i % cols;

            float azimuth = (col - cols / 2.0f) * 30.0f;  // 30 degree spacing
            float elevation = (row - rows / 2.0f) * 20.0f;  // 20 degree spacing

            positions[i] = {azimuth, elevation, baseDistance_};
        }
    }

    void generateFibonacciPositions(std::vector<SphericalPosition>& positions, int n) {
        const float goldenAngle = M_PI * (3.0f - std::sqrt(5.0f));  // ~137.5 degrees

        for (int i = 0; i < n; i++) {
            float y = 1.0f - (i / static_cast<float>(n - 1)) * 2.0f;  // -1 to 1
            float radius = std::sqrt(1.0f - y * y);
            float theta = goldenAngle * i;

            float azimuth = std::atan2(radius * std::sin(theta), radius * std::cos(theta)) * 180.0f / M_PI;
            float elevation = std::asin(y) * 180.0f / M_PI;

            positions[i] = {azimuth, elevation, baseDistance_};
        }
    }

    void generateOrbitalPositions(std::vector<SphericalPosition>& positions, int n) {
        float orbitSpeed = 0.1f + hrv_ * 0.2f;  // HRV modulates orbit speed

        for (int i = 0; i < n; i++) {
            float phase = static_cast<float>(i) / n * 360.0f;
            float orbitPhase = phase + time_ * orbitSpeed * 360.0f;

            float elevation = std::sin(time_ * 0.5f + phase * M_PI / 180.0f) * 30.0f;

            positions[i] = {orbitPhase, elevation, baseDistance_};
        }
    }

    void generateBreathingPositions(std::vector<SphericalPosition>& positions, int n) {
        // Distance expands on inhale, contracts on exhale
        float breathModulation = std::sin(breathPhase_ * 2.0f * M_PI);
        float distance = baseDistance_ * (1.0f + breathModulation * 0.3f);

        generateFibonacciPositions(positions, n);

        // Modulate distance
        for (auto& pos : positions) {
            pos.distance = distance;
        }
    }

    void generateCoherencePositions(std::vector<SphericalPosition>& positions, int n) {
        // High coherence = organized sphere, low coherence = scattered
        generateFibonacciPositions(positions, n);

        float scatter = 1.0f - coherence_;

        for (auto& pos : positions) {
            // Add randomness based on coherence
            pos.azimuth += (std::rand() / static_cast<float>(RAND_MAX) - 0.5f) * scatter * 60.0f;
            pos.elevation += (std::rand() / static_cast<float>(RAND_MAX) - 0.5f) * scatter * 40.0f;
            pos.distance = baseDistance_ * (1.0f + scatter * 0.5f * (std::rand() / static_cast<float>(RAND_MAX) - 0.5f));
        }
    }

    void generateHeartPositions(std::vector<SphericalPosition>& positions, int n) {
        // Pulsing based on heart rate
        float heartPhase = std::fmod(time_ * heartRate_ / 60.0f, 1.0f);
        float pulse = 1.0f + 0.1f * std::sin(heartPhase * 2.0f * M_PI);

        generateFibonacciPositions(positions, n);

        for (auto& pos : positions) {
            pos.distance = baseDistance_ * pulse;
        }
    }

    FieldGeometry geometry_ = FieldGeometry::Fibonacci;
    float baseDistance_ = 2.0f;
    float time_ = 0.0f;

    // Bio data
    float heartRate_ = 60.0f;
    float hrv_ = 50.0f;
    float coherence_ = 0.5f;
    float breathPhase_ = 0.0f;
    float breathRate_ = 12.0f;
};

// ============================================================================
// Spatial Audio Engine
// ============================================================================

class SpatialAudioEngine {
public:
    enum class RenderMode {
        Stereo,         // Simple stereo panning
        Binaural,       // HRTF-based binaural
        Ambisonics,     // B-format encoding
        Surround_5_1,   // 5.1 surround
        Surround_7_1,   // 7.1 surround
        Atmos           // Dolby Atmos (object-based)
    };

    SpatialAudioEngine(int sampleRate)
        : sampleRate_(sampleRate),
          hrtf_(sampleRate),
          ambisonics_(sampleRate),
          bioField_() {

        // Initialize B-format buffers
        for (int i = 0; i < 4; i++) {
            bFormatBuffers_[i].resize(MAX_BUFFER_SIZE, 0.0f);
        }
    }

    void setRenderMode(RenderMode mode) { renderMode_ = mode; }
    RenderMode renderMode() const { return renderMode_; }

    // Add/remove sources
    int addSource() {
        int id = nextSourceId_++;
        sources_.emplace_back(id);
        return id;
    }

    void removeSource(int id) {
        sources_.erase(
            std::remove_if(sources_.begin(), sources_.end(),
                [id](const SpatialAudioSource& s) { return s.id() == id; }),
            sources_.end());
    }

    SpatialAudioSource* getSource(int id) {
        for (auto& source : sources_) {
            if (source.id() == id) return &source;
        }
        return nullptr;
    }

    // Listener position/orientation
    void setListenerPosition(const Vector3D& position) { listenerPosition_ = position; }
    void setListenerOrientation(const Vector3D& forward, const Vector3D& up) {
        listenerForward_ = forward.normalized();
        listenerUp_ = up.normalized();
    }

    // Process audio
    void process(const std::vector<const float*>& sourceInputs,
                 float* leftOut, float* rightOut, int numSamples) {

        // Clear outputs
        std::fill(leftOut, leftOut + numSamples, 0.0f);
        std::fill(rightOut, rightOut + numSamples, 0.0f);

        // Clear B-format
        for (int ch = 0; ch < 4; ch++) {
            std::fill(bFormatBuffers_[ch].begin(), bFormatBuffers_[ch].begin() + numSamples, 0.0f);
        }

        // Process each source
        for (size_t i = 0; i < sources_.size() && i < sourceInputs.size(); i++) {
            if (sources_[i].isMuted()) continue;

            const float* input = sourceInputs[i];
            const auto& pos = sources_[i].sphericalPosition();

            switch (renderMode_) {
                case RenderMode::Stereo:
                    processStereoPan(input, leftOut, rightOut, numSamples, pos);
                    break;

                case RenderMode::Binaural:
                    processBinaural(input, leftOut, rightOut, numSamples, pos);
                    break;

                case RenderMode::Ambisonics: {
                    float* bFormat[4] = {
                        bFormatBuffers_[0].data(),
                        bFormatBuffers_[1].data(),
                        bFormatBuffers_[2].data(),
                        bFormatBuffers_[3].data()
                    };
                    ambisonics_.encode(input, bFormat, numSamples, pos);
                    break;
                }

                default:
                    processStereoPan(input, leftOut, rightOut, numSamples, pos);
                    break;
            }
        }

        // Decode ambisonics if needed
        if (renderMode_ == RenderMode::Ambisonics) {
            float* bFormat[4] = {
                bFormatBuffers_[0].data(),
                bFormatBuffers_[1].data(),
                bFormatBuffers_[2].data(),
                bFormatBuffers_[3].data()
            };
            ambisonics_.decodeToBinaural(bFormat, leftOut, rightOut, numSamples);
        }
    }

    // Bio-reactive field
    BioReactiveSpatialField& bioField() { return bioField_; }

    // Update sources from bio-reactive field
    void updateFromBioField() {
        auto positions = bioField_.getSourcePositions(static_cast<int>(sources_.size()));

        for (size_t i = 0; i < sources_.size(); i++) {
            sources_[i].setPosition(positions[i]);
        }
    }

private:
    void processStereoPan(const float* input, float* leftOut, float* rightOut,
                          int numSamples, const SphericalPosition& pos) {
        // Simple stereo pan based on azimuth
        float pan = (pos.azimuth + 90.0f) / 180.0f;  // 0 = left, 1 = right
        pan = std::clamp(pan, 0.0f, 1.0f);

        // Equal power panning
        float leftGain = std::cos(pan * M_PI * 0.5f);
        float rightGain = std::sin(pan * M_PI * 0.5f);

        // Distance attenuation
        float distGain = 1.0f / std::max(0.5f, pos.distance);

        for (int i = 0; i < numSamples; i++) {
            float sample = input[i] * distGain;
            leftOut[i] += sample * leftGain;
            rightOut[i] += sample * rightGain;
        }
    }

    void processBinaural(const float* input, float* leftOut, float* rightOut,
                         int numSamples, const SphericalPosition& pos) {
        // Use HRTF processor
        std::vector<float> tempLeft(numSamples);
        std::vector<float> tempRight(numSamples);

        hrtf_.process(input, tempLeft.data(), tempRight.data(), numSamples, pos);

        // Mix to output
        for (int i = 0; i < numSamples; i++) {
            leftOut[i] += tempLeft[i];
            rightOut[i] += tempRight[i];
        }
    }

    static constexpr int MAX_BUFFER_SIZE = 8192;

    int sampleRate_;
    RenderMode renderMode_ = RenderMode::Binaural;

    std::vector<SpatialAudioSource> sources_;
    int nextSourceId_ = 1;

    Vector3D listenerPosition_;
    Vector3D listenerForward_ = {0, 0, 1};
    Vector3D listenerUp_ = {0, 1, 0};

    HRTFProcessor hrtf_;
    AmbisonicsProcessor ambisonics_;
    BioReactiveSpatialField bioField_;

    std::array<std::vector<float>, 4> bFormatBuffers_;
};

// ============================================================================
// Room Acoustics Simulator
// ============================================================================

class RoomAcoustics {
public:
    struct RoomProperties {
        float width = 10.0f;    // meters
        float depth = 12.0f;
        float height = 3.5f;

        // Wall absorption coefficients (0-1)
        float leftWallAbs = 0.3f;
        float rightWallAbs = 0.3f;
        float frontWallAbs = 0.3f;
        float backWallAbs = 0.3f;
        float floorAbs = 0.5f;
        float ceilingAbs = 0.4f;
    };

    RoomAcoustics(int sampleRate) : sampleRate_(sampleRate) {
        initializeDelayLines();
    }

    void setRoom(const RoomProperties& room) { room_ = room; }
    const RoomProperties& room() const { return room_; }

    // Calculate early reflections
    void calculateReflections(const Vector3D& source, const Vector3D& listener,
                               std::vector<SphericalPosition>& reflections,
                               std::vector<float>& delays,
                               std::vector<float>& gains) {
        reflections.clear();
        delays.clear();
        gains.clear();

        // First-order reflections (6 walls)
        calculateWallReflection(source, listener, {-room_.width / 2, 0, 0}, {1, 0, 0},
                                 room_.leftWallAbs, reflections, delays, gains);
        calculateWallReflection(source, listener, {room_.width / 2, 0, 0}, {-1, 0, 0},
                                 room_.rightWallAbs, reflections, delays, gains);
        calculateWallReflection(source, listener, {0, 0, room_.depth / 2}, {0, 0, -1},
                                 room_.frontWallAbs, reflections, delays, gains);
        calculateWallReflection(source, listener, {0, 0, -room_.depth / 2}, {0, 0, 1},
                                 room_.backWallAbs, reflections, delays, gains);
        calculateWallReflection(source, listener, {0, 0, 0}, {0, 1, 0},
                                 room_.floorAbs, reflections, delays, gains);
        calculateWallReflection(source, listener, {0, room_.height, 0}, {0, -1, 0},
                                 room_.ceilingAbs, reflections, delays, gains);
    }

private:
    void initializeDelayLines() {
        // Max delay for room reflections (diagonal of max room size)
        maxDelayMs_ = 500.0f;  // 500ms max
        int maxDelaySamples = static_cast<int>(maxDelayMs_ * sampleRate_ / 1000.0f);

        for (int i = 0; i < 6; i++) {
            delayLines_[i].resize(maxDelaySamples, 0.0f);
        }
    }

    void calculateWallReflection(const Vector3D& source, const Vector3D& listener,
                                  const Vector3D& wallPoint, const Vector3D& wallNormal,
                                  float absorption,
                                  std::vector<SphericalPosition>& reflections,
                                  std::vector<float>& delays,
                                  std::vector<float>& gains) {
        // Mirror image method
        // Calculate distance from source to wall
        Vector3D toWall = wallPoint - source;
        float dist = toWall.dot(wallNormal);

        // Image source position
        Vector3D imageSource = source + wallNormal * (2 * dist);

        // Calculate path length
        float pathLength = (imageSource - listener).length();

        // Delay in seconds
        const float soundSpeed = 343.0f;
        float delay = pathLength / soundSpeed;

        // Gain based on distance and absorption
        float gain = (1.0f - absorption) / std::max(1.0f, pathLength);

        // Direction from listener to image source
        SphericalPosition reflPos = SphericalPosition::fromCartesian(imageSource - listener);

        reflections.push_back(reflPos);
        delays.push_back(delay);
        gains.push_back(gain);
    }

    int sampleRate_;
    RoomProperties room_;
    float maxDelayMs_;
    std::array<std::vector<float>, 6> delayLines_;
    std::array<int, 6> delayWritePos_;
};

} // namespace Spatial
} // namespace Echoelmusic
