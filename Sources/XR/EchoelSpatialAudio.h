#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <thread>
#include <mutex>
#include <cmath>
#include <array>
#include <optional>

namespace Echoel {
namespace XR {

// =============================================================================
// SPATIAL AUDIO TYPES & ENUMS
// =============================================================================

enum class SpatialFormat {
    Stereo,
    Quad,
    Surround51,         // 5.1 surround
    Surround71,         // 7.1 surround
    Surround714,        // 7.1.4 (Atmos bed)
    Surround916,        // 9.1.6 (Full Atmos)
    Ambisonics1stOrder, // 4 channels (WXYZ)
    Ambisonics2ndOrder, // 9 channels
    Ambisonics3rdOrder, // 16 channels
    Ambisonics5thOrder, // 36 channels
    Binaural,           // Headphone 3D
    ObjectBased,        // Object-based audio
    Custom
};

enum class SpeakerLayout {
    // Standard layouts
    Mono,
    Stereo,
    LCR,                // Left, Center, Right
    Quad,               // L, R, Ls, Rs
    Surround50,         // L, C, R, Ls, Rs
    Surround51,         // L, C, R, Ls, Rs, LFE
    Surround70,         // L, C, R, Lss, Rss, Lsr, Rsr
    Surround71,         // L, C, R, Lss, Rss, Lsr, Rsr, LFE

    // Atmos/Immersive layouts
    Atmos714,           // 7.1.4 - Ceiling speakers
    Atmos916,           // 9.1.6 - Full dome
    Atmos51X,           // 5.1 + height objects
    Atmos71X,           // 7.1 + height objects

    // Specialty
    Auro3D,             // Auro-3D format
    MPEG_H,             // MPEG-H 3D Audio
    SonyReality360,     // Sony 360 Reality Audio
    DTS_X,              // DTS:X format

    // VR/AR
    VRHeadphone,        // Binaural for VR
    ARPassthrough,      // AR with real-world audio

    Custom
};

enum class HRTFProfile {
    GenericSmall,       // Generic small head
    GenericMedium,      // Generic medium head
    GenericLarge,       // Generic large head
    Personalized,       // User's measured HRTF
    KEMAR,              // KEMAR mannequin
    MIT,                // MIT HRTF database
    CIPIC,              // CIPIC database
    SADIE,              // SADIE database
    Custom
};

enum class RoomType {
    None,               // Anechoic
    SmallRoom,
    MediumRoom,
    LargeRoom,
    ConcertHall,
    Cathedral,
    Cave,
    Outdoor,
    Studio,
    Bathroom,
    Arena,
    Custom
};

enum class ReflectionModel {
    None,
    Simple,             // First-order only
    ImageSource,        // Image source method
    RayTracing,         // Full ray tracing
    Hybrid              // Hybrid approach
};

enum class OcclusionModel {
    None,
    Binary,             // On/off occlusion
    Frequency,          // Frequency-dependent
    Material,           // Material-based
    Physical            // Physical simulation
};

enum class DistanceModel {
    Linear,
    Inverse,
    InverseSquare,
    Exponential,
    Custom
};

enum class PanningLaw {
    ConstantPower,
    Linear,
    SquareRoot,
    Sine,
    VBAP,               // Vector Base Amplitude Panning
    DBAP,               // Distance-Based Amplitude Panning
    Ambisonics
};

// =============================================================================
// 3D MATH STRUCTURES
// =============================================================================

struct Vector3 {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    Vector3() = default;
    Vector3(float x_, float y_, float z_) : x(x_), y(y_), z(z_) {}

    Vector3 operator+(const Vector3& other) const {
        return {x + other.x, y + other.y, z + other.z};
    }

    Vector3 operator-(const Vector3& other) const {
        return {x - other.x, y - other.y, z - other.z};
    }

    Vector3 operator*(float scalar) const {
        return {x * scalar, y * scalar, z * scalar};
    }

    float dot(const Vector3& other) const {
        return x * other.x + y * other.y + z * other.z;
    }

    Vector3 cross(const Vector3& other) const {
        return {
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        };
    }

    float magnitude() const {
        return std::sqrt(x * x + y * y + z * z);
    }

    Vector3 normalized() const {
        float mag = magnitude();
        if (mag > 0) return *this * (1.0f / mag);
        return {0, 0, 0};
    }

    float distance(const Vector3& other) const {
        return (*this - other).magnitude();
    }
};

struct Quaternion {
    float w = 1.0f;
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    static Quaternion fromEuler(float pitch, float yaw, float roll) {
        float cy = std::cos(yaw * 0.5f);
        float sy = std::sin(yaw * 0.5f);
        float cp = std::cos(pitch * 0.5f);
        float sp = std::sin(pitch * 0.5f);
        float cr = std::cos(roll * 0.5f);
        float sr = std::sin(roll * 0.5f);

        Quaternion q;
        q.w = cr * cp * cy + sr * sp * sy;
        q.x = sr * cp * cy - cr * sp * sy;
        q.y = cr * sp * cy + sr * cp * sy;
        q.z = cr * cp * sy - sr * sp * cy;
        return q;
    }

    Vector3 rotate(const Vector3& v) const {
        Vector3 u(x, y, z);
        float s = w;

        return u * 2.0f * u.dot(v) +
               v * (s * s - u.dot(u)) +
               u.cross(v) * 2.0f * s;
    }
};

struct Transform {
    Vector3 position;
    Quaternion rotation;
    Vector3 scale = {1, 1, 1};

    Vector3 forward() const {
        return rotation.rotate({0, 0, -1});
    }

    Vector3 up() const {
        return rotation.rotate({0, 1, 0});
    }

    Vector3 right() const {
        return rotation.rotate({1, 0, 0});
    }
};

// =============================================================================
// AUDIO SOURCE & LISTENER
// =============================================================================

struct SpatialSourceParams {
    // Position & Orientation
    Vector3 position;
    Vector3 velocity;
    Vector3 direction;
    float innerConeAngle = 360.0f;    // Degrees
    float outerConeAngle = 360.0f;    // Degrees
    float outerConeGain = 0.0f;       // Gain outside cone

    // Distance attenuation
    DistanceModel distanceModel = DistanceModel::InverseSquare;
    float minDistance = 1.0f;
    float maxDistance = 100.0f;
    float rolloffFactor = 1.0f;

    // Directivity
    float directivity = 0.0f;         // 0 = omnidirectional, 1 = highly directional
    float directivitySharpness = 1.0f;

    // LFE/Bass management
    float lfeSend = 0.0f;             // Send to LFE channel
    float bassManagement = 0.0f;       // Bass redirection

    // Reverb
    float reverbSend = 0.3f;
    float reverbDistance = 10.0f;

    // Occlusion & Obstruction
    float occlusion = 0.0f;           // 0 = no occlusion
    float obstruction = 0.0f;         // 0 = no obstruction
    float occlusionLFRatio = 0.25f;   // Low frequency pass-through

    // Doppler
    bool enableDoppler = true;
    float dopplerFactor = 1.0f;

    // Spread
    float spread = 0.0f;              // 0 = point source, 1 = full spread
    float spreadMinDistance = 1.0f;

    // Air absorption
    bool enableAirAbsorption = true;
    float airAbsorptionFactor = 1.0f;
};

struct SpatialListener {
    Transform transform;
    Vector3 velocity;

    // HRTF
    HRTFProfile hrtfProfile = HRTFProfile::GenericMedium;
    float interauralDistance = 0.17f;  // Ear-to-ear distance (meters)

    // Output
    SpatialFormat outputFormat = SpatialFormat::Binaural;
    SpeakerLayout speakerLayout = SpeakerLayout::Stereo;

    // Preferences
    float globalGain = 1.0f;
    float speedOfSound = 343.0f;       // m/s at 20°C
    float globalReverbMix = 1.0f;
};

struct AudioSource {
    std::string id;
    std::string name;
    SpatialSourceParams params;

    // Audio data
    std::vector<float> audioBuffer;
    int sampleRate = 44100;
    int channels = 1;
    bool isPlaying = false;
    bool isLooping = false;
    double playbackPosition = 0.0;

    // Gain
    float gain = 1.0f;
    float pitch = 1.0f;

    // Priority
    int priority = 128;               // 0 = highest
    bool isVirtual = false;           // Virtualized (inaudible but tracked)

    // Object-based audio
    bool isObject = false;            // For Atmos/DTS:X objects
    int objectId = -1;
};

// =============================================================================
// ROOM & ENVIRONMENT
// =============================================================================

struct RoomMaterial {
    std::string name;
    std::array<float, 6> absorption = {0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f};
    // 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz
    float scattering = 0.1f;
    float transmission = 0.0f;
};

struct RoomGeometry {
    Vector3 dimensions = {10, 3, 8};  // Width, Height, Depth (meters)

    // Surface materials
    RoomMaterial floorMaterial;
    RoomMaterial ceilingMaterial;
    RoomMaterial leftWallMaterial;
    RoomMaterial rightWallMaterial;
    RoomMaterial frontWallMaterial;
    RoomMaterial backWallMaterial;

    // Openings
    struct Opening {
        Vector3 position;
        Vector3 size;
        float openness = 1.0f;  // 0 = closed, 1 = fully open
    };
    std::vector<Opening> openings;
};

struct ReverbParams {
    float dryWet = 0.3f;
    float preDelay = 0.02f;           // Seconds
    float decayTime = 1.5f;           // RT60 in seconds
    float damping = 0.5f;             // High frequency damping
    float roomSize = 0.5f;            // 0-1 scale
    float diffusion = 0.8f;
    float earlyReflections = 0.5f;
    float lateDiffusion = 0.7f;
    float density = 0.8f;
    float bandwidth = 0.9f;
    float modulation = 0.1f;

    // Frequency-dependent decay
    float lowFreqDecay = 1.0f;        // Multiplier for low freq RT60
    float highFreqDecay = 0.5f;       // Multiplier for high freq RT60
    float crossoverFreq = 1000.0f;    // Hz
};

struct RoomEnvironment {
    std::string id;
    std::string name;
    RoomType type = RoomType::MediumRoom;
    RoomGeometry geometry;
    ReverbParams reverb;
    ReflectionModel reflectionModel = ReflectionModel::ImageSource;
    OcclusionModel occlusionModel = OcclusionModel::Frequency;

    // Environmental
    float temperature = 20.0f;        // Celsius (affects speed of sound)
    float humidity = 50.0f;           // Percent (affects air absorption)
    float airDensity = 1.2f;          // kg/m³
};

// =============================================================================
// AMBISONICS
// =============================================================================

class AmbisonicsProcessor {
public:
    enum class Normalization {
        SN3D,           // Schmidt semi-normalized
        N3D,            // Fully normalized
        FuMa,           // Furse-Malham
        MaxN            // Max normalized
    };

    enum class ChannelOrdering {
        ACN,            // Ambisonics Channel Number
        FuMa,           // Furse-Malham ordering
        SID             // Single Index Designation
    };

    void setOrder(int order) {
        order_ = order;
        numChannels_ = (order + 1) * (order + 1);
    }

    void setNormalization(Normalization norm) {
        normalization_ = norm;
    }

    void setOrdering(ChannelOrdering ordering) {
        channelOrdering_ = ordering;
    }

    // Encode point source to ambisonic B-format
    std::vector<float> encode(const Vector3& direction, float gain = 1.0f) {
        std::vector<float> coefficients(numChannels_);

        // Spherical coordinates
        float azimuth = std::atan2(direction.x, direction.z);
        float elevation = std::asin(std::clamp(direction.y, -1.0f, 1.0f));

        // First order (W, Y, Z, X)
        if (numChannels_ >= 4) {
            coefficients[0] = 1.0f;  // W (omnidirectional)
            coefficients[1] = std::sin(azimuth) * std::cos(elevation);  // Y
            coefficients[2] = std::sin(elevation);  // Z
            coefficients[3] = std::cos(azimuth) * std::cos(elevation);  // X
        }

        // Higher orders would continue here...

        // Apply normalization and gain
        for (auto& c : coefficients) {
            c *= gain;
        }

        return coefficients;
    }

    // Decode ambisonics to speaker layout
    std::vector<float> decode(const std::vector<float>& ambisonics,
                               SpeakerLayout layout) {
        int numSpeakers = getSpeakerCount(layout);
        std::vector<float> speakers(numSpeakers, 0.0f);

        // Get decoder matrix for layout
        auto decoderMatrix = getDecoderMatrix(layout);

        // Matrix multiplication
        for (int s = 0; s < numSpeakers; s++) {
            for (int c = 0; c < numChannels_ && c < ambisonics.size(); c++) {
                speakers[s] += ambisonics[c] * decoderMatrix[s][c];
            }
        }

        return speakers;
    }

    // Rotate ambisonics field
    void rotate(std::vector<float>& ambisonics, const Quaternion& rotation) {
        if (ambisonics.size() < 4) return;

        // Rotate first-order components (Y, Z, X)
        Vector3 yAxis(1, 0, 0);
        Vector3 zAxis(0, 1, 0);
        Vector3 xAxis(0, 0, 1);

        Vector3 rotY = rotation.rotate(yAxis);
        Vector3 rotZ = rotation.rotate(zAxis);
        Vector3 rotX = rotation.rotate(xAxis);

        float y = ambisonics[1];
        float z = ambisonics[2];
        float x = ambisonics[3];

        ambisonics[1] = y * rotY.x + z * rotZ.x + x * rotX.x;
        ambisonics[2] = y * rotY.y + z * rotZ.y + x * rotX.y;
        ambisonics[3] = y * rotY.z + z * rotZ.z + x * rotX.z;
    }

    int getOrder() const { return order_; }
    int getNumChannels() const { return numChannels_; }

private:
    int order_ = 1;
    int numChannels_ = 4;
    Normalization normalization_ = Normalization::SN3D;
    ChannelOrdering channelOrdering_ = ChannelOrdering::ACN;

    int getSpeakerCount(SpeakerLayout layout) const {
        switch (layout) {
            case SpeakerLayout::Mono: return 1;
            case SpeakerLayout::Stereo: return 2;
            case SpeakerLayout::Quad: return 4;
            case SpeakerLayout::Surround51: return 6;
            case SpeakerLayout::Surround71: return 8;
            case SpeakerLayout::Atmos714: return 12;
            case SpeakerLayout::Atmos916: return 16;
            default: return 2;
        }
    }

    std::vector<std::vector<float>> getDecoderMatrix(SpeakerLayout layout) {
        int numSpeakers = getSpeakerCount(layout);
        std::vector<std::vector<float>> matrix(numSpeakers,
            std::vector<float>(numChannels_, 0.0f));

        // Basic stereo decoder
        if (layout == SpeakerLayout::Stereo) {
            // Left: W + Y
            matrix[0][0] = 0.5f;  // W
            matrix[0][1] = 0.5f;  // Y (left)
            // Right: W - Y
            matrix[1][0] = 0.5f;  // W
            matrix[1][1] = -0.5f; // Y (right)
        }

        // More decoder matrices would be defined for other layouts...

        return matrix;
    }
};

// =============================================================================
// DOLBY ATMOS SUPPORT
// =============================================================================

struct AtmosObject {
    int objectId;
    std::string name;
    Vector3 position;                 // Normalized (-1 to 1)
    float size = 0.0f;                // Object size (0 = point, 1 = full room)
    float gain = 1.0f;
    bool isDynamic = true;            // Can move during playback

    // Snap behaviors
    bool snapToScreen = false;
    bool snapToNearestSpeaker = false;

    // Height
    float height = 0.0f;              // -1 = floor, 0 = ear level, 1 = ceiling
};

struct AtmosBed {
    std::string id;
    std::string name;
    SpeakerLayout layout = SpeakerLayout::Atmos714;
    std::vector<float> channelGains;

    void setChannelGain(int channel, float gain) {
        if (channel < channelGains.size()) {
            channelGains[channel] = gain;
        }
    }
};

class DolbyAtmosRenderer {
public:
    bool initialize(SpeakerLayout outputLayout) {
        outputLayout_ = outputLayout;
        initialized_ = true;
        return true;
    }

    void addObject(const AtmosObject& object) {
        objects_[object.objectId] = object;
    }

    void updateObjectPosition(int objectId, const Vector3& position) {
        if (objects_.count(objectId)) {
            objects_[objectId].position = position;
        }
    }

    void removeObject(int objectId) {
        objects_.erase(objectId);
    }

    void setBed(const AtmosBed& bed) {
        bed_ = bed;
    }

    std::vector<float> render(const std::map<int, std::vector<float>>& objectAudio,
                               const std::vector<float>& bedAudio,
                               int numSamples) {
        int numOutputChannels = getOutputChannelCount();
        std::vector<float> output(numSamples * numOutputChannels, 0.0f);

        // Render bed channels
        if (!bedAudio.empty()) {
            for (int i = 0; i < numSamples; i++) {
                for (int c = 0; c < bed_.channelGains.size() && c < numOutputChannels; c++) {
                    if (i * bed_.channelGains.size() + c < bedAudio.size()) {
                        output[i * numOutputChannels + c] +=
                            bedAudio[i * bed_.channelGains.size() + c] * bed_.channelGains[c];
                    }
                }
            }
        }

        // Render objects using VBAP
        for (const auto& [objectId, audio] : objectAudio) {
            if (!objects_.count(objectId)) continue;

            const auto& obj = objects_[objectId];
            auto speakerGains = calculateVBAPGains(obj.position);

            for (int i = 0; i < numSamples && i < audio.size(); i++) {
                for (int c = 0; c < numOutputChannels && c < speakerGains.size(); c++) {
                    output[i * numOutputChannels + c] += audio[i] * speakerGains[c] * obj.gain;
                }
            }
        }

        return output;
    }

    int getOutputChannelCount() const {
        switch (outputLayout_) {
            case SpeakerLayout::Surround51: return 6;
            case SpeakerLayout::Surround71: return 8;
            case SpeakerLayout::Atmos714: return 12;
            case SpeakerLayout::Atmos916: return 16;
            default: return 2;
        }
    }

private:
    std::vector<float> calculateVBAPGains(const Vector3& position) {
        int numChannels = getOutputChannelCount();
        std::vector<float> gains(numChannels, 0.0f);

        // Simplified VBAP - real implementation would use proper speaker positions
        float azimuth = std::atan2(position.x, position.z);
        float elevation = std::asin(std::clamp(position.y, -1.0f, 1.0f));

        // Basic panning (simplified)
        float leftGain = 0.5f - position.x * 0.5f;
        float rightGain = 0.5f + position.x * 0.5f;

        if (numChannels >= 2) {
            gains[0] = leftGain;
            gains[1] = rightGain;
        }

        // Height handling for Atmos
        if (numChannels > 8 && std::abs(elevation) > 0.1f) {
            float heightGain = std::abs(position.y);
            // Route to height speakers
            if (numChannels >= 12) {
                gains[8] = gains[0] * heightGain;   // Top left
                gains[9] = gains[1] * heightGain;   // Top right
                gains[0] *= (1.0f - heightGain);
                gains[1] *= (1.0f - heightGain);
            }
        }

        return gains;
    }

    bool initialized_ = false;
    SpeakerLayout outputLayout_ = SpeakerLayout::Stereo;
    std::map<int, AtmosObject> objects_;
    AtmosBed bed_;
};

// =============================================================================
// BINAURAL / HRTF PROCESSING
// =============================================================================

struct HRTF {
    std::string id;
    HRTFProfile profile;
    int numElevations = 0;
    int numAzimuths = 0;
    int irLength = 0;
    int sampleRate = 44100;

    // HRTF data: [elevation][azimuth][ear][samples]
    std::vector<std::vector<std::array<std::vector<float>, 2>>> data;

    std::array<std::vector<float>, 2> getIR(float azimuth, float elevation) const {
        // Find nearest HRTF filters and interpolate
        // Simplified - real implementation would do proper interpolation
        int azIdx = static_cast<int>((azimuth + 180.0f) / 360.0f * numAzimuths) % numAzimuths;
        int elIdx = static_cast<int>((elevation + 90.0f) / 180.0f * numElevations);
        elIdx = std::clamp(elIdx, 0, numElevations - 1);

        if (elIdx < data.size() && azIdx < data[elIdx].size()) {
            return data[elIdx][azIdx];
        }

        return {std::vector<float>(irLength, 0.0f), std::vector<float>(irLength, 0.0f)};
    }
};

class BinauralRenderer {
public:
    bool loadHRTF(HRTFProfile profile) {
        hrtfProfile_ = profile;

        // Generate synthetic HRTF (simplified)
        hrtf_.profile = profile;
        hrtf_.numElevations = 9;   // -40 to +90 degrees
        hrtf_.numAzimuths = 72;    // 5-degree steps
        hrtf_.irLength = 256;
        hrtf_.sampleRate = 44100;

        // In reality, would load from SOFA file or database
        hrtf_.data.resize(hrtf_.numElevations);
        for (int e = 0; e < hrtf_.numElevations; e++) {
            hrtf_.data[e].resize(hrtf_.numAzimuths);
            for (int a = 0; a < hrtf_.numAzimuths; a++) {
                // Generate simple delay/level difference
                float azimuth = a * 5.0f - 180.0f;
                float itd = 0.00065f * std::sin(azimuth * M_PI / 180.0f);  // ITD
                float ild = 6.0f * std::sin(azimuth * M_PI / 180.0f);       // ILD in dB

                hrtf_.data[e][a][0].resize(hrtf_.irLength, 0.0f);
                hrtf_.data[e][a][1].resize(hrtf_.irLength, 0.0f);

                // Simple impulse with ITD
                int leftDelay = static_cast<int>((itd > 0 ? itd : 0) * hrtf_.sampleRate);
                int rightDelay = static_cast<int>((itd < 0 ? -itd : 0) * hrtf_.sampleRate);

                float leftGain = std::pow(10.0f, (ild > 0 ? 0 : ild) / 20.0f);
                float rightGain = std::pow(10.0f, (ild < 0 ? 0 : -ild) / 20.0f);

                if (leftDelay < hrtf_.irLength)
                    hrtf_.data[e][a][0][leftDelay] = leftGain;
                if (rightDelay < hrtf_.irLength)
                    hrtf_.data[e][a][1][rightDelay] = rightGain;
            }
        }

        hrtfLoaded_ = true;
        return true;
    }

    std::array<std::vector<float>, 2> render(const std::vector<float>& monoInput,
                                              float azimuth, float elevation) {
        std::array<std::vector<float>, 2> output;
        output[0].resize(monoInput.size() + hrtf_.irLength - 1, 0.0f);
        output[1].resize(monoInput.size() + hrtf_.irLength - 1, 0.0f);

        if (!hrtfLoaded_) {
            // Pass through
            for (size_t i = 0; i < monoInput.size(); i++) {
                output[0][i] = monoInput[i];
                output[1][i] = monoInput[i];
            }
            return output;
        }

        auto [leftIR, rightIR] = hrtf_.getIR(azimuth, elevation);

        // Convolution
        for (size_t i = 0; i < monoInput.size(); i++) {
            for (size_t j = 0; j < leftIR.size(); j++) {
                output[0][i + j] += monoInput[i] * leftIR[j];
                output[1][i + j] += monoInput[i] * rightIR[j];
            }
        }

        return output;
    }

    bool isLoaded() const { return hrtfLoaded_; }

private:
    bool hrtfLoaded_ = false;
    HRTFProfile hrtfProfile_ = HRTFProfile::GenericMedium;
    HRTF hrtf_;
};

// =============================================================================
// SPATIAL AUDIO ENGINE
// =============================================================================

class SpatialAudioEngine {
public:
    static SpatialAudioEngine& getInstance() {
        static SpatialAudioEngine instance;
        return instance;
    }

    // Initialization
    bool initialize(SpatialFormat format, int sampleRate = 44100) {
        format_ = format;
        sampleRate_ = sampleRate;

        // Initialize binaural renderer for headphone output
        if (format == SpatialFormat::Binaural) {
            binaural_.loadHRTF(HRTFProfile::GenericMedium);
        }

        // Initialize Atmos renderer
        if (format == SpatialFormat::Surround714 || format == SpatialFormat::Surround916) {
            atmos_.initialize(format == SpatialFormat::Surround714 ?
                              SpeakerLayout::Atmos714 : SpeakerLayout::Atmos916);
        }

        // Initialize ambisonics
        if (format == SpatialFormat::Ambisonics1stOrder) {
            ambisonics_.setOrder(1);
        } else if (format == SpatialFormat::Ambisonics3rdOrder) {
            ambisonics_.setOrder(3);
        }

        initialized_ = true;
        return true;
    }

    // Listener
    void setListener(const SpatialListener& listener) {
        std::lock_guard<std::mutex> lock(mutex_);
        listener_ = listener;
    }

    const SpatialListener& getListener() const {
        return listener_;
    }

    void updateListenerPosition(const Vector3& position) {
        std::lock_guard<std::mutex> lock(mutex_);
        listener_.transform.position = position;
    }

    void updateListenerOrientation(const Quaternion& rotation) {
        std::lock_guard<std::mutex> lock(mutex_);
        listener_.transform.rotation = rotation;
    }

    // Sources
    std::string createSource(const std::string& name = "") {
        std::lock_guard<std::mutex> lock(mutex_);

        AudioSource source;
        source.id = "src_" + std::to_string(nextSourceId_++);
        source.name = name.empty() ? source.id : name;

        sources_[source.id] = source;
        return source.id;
    }

    void destroySource(const std::string& sourceId) {
        std::lock_guard<std::mutex> lock(mutex_);
        sources_.erase(sourceId);
    }

    void setSourcePosition(const std::string& sourceId, const Vector3& position) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (sources_.count(sourceId)) {
            sources_[sourceId].params.position = position;
        }
    }

    void setSourceVelocity(const std::string& sourceId, const Vector3& velocity) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (sources_.count(sourceId)) {
            sources_[sourceId].params.velocity = velocity;
        }
    }

    void setSourceParams(const std::string& sourceId, const SpatialSourceParams& params) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (sources_.count(sourceId)) {
            sources_[sourceId].params = params;
        }
    }

    void setSourceAudio(const std::string& sourceId, const std::vector<float>& audio) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (sources_.count(sourceId)) {
            sources_[sourceId].audioBuffer = audio;
        }
    }

    void playSource(const std::string& sourceId) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (sources_.count(sourceId)) {
            sources_[sourceId].isPlaying = true;
            sources_[sourceId].playbackPosition = 0.0;
        }
    }

    void stopSource(const std::string& sourceId) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (sources_.count(sourceId)) {
            sources_[sourceId].isPlaying = false;
        }
    }

    // Environment
    void setEnvironment(const RoomEnvironment& environment) {
        std::lock_guard<std::mutex> lock(mutex_);
        environment_ = environment;
    }

    // Atmos Objects
    void addAtmosObject(const AtmosObject& object) {
        atmos_.addObject(object);
    }

    void updateAtmosObject(int objectId, const Vector3& position) {
        atmos_.updateObjectPosition(objectId, position);
    }

    // Rendering
    std::vector<float> render(int numSamples) {
        std::lock_guard<std::mutex> lock(mutex_);

        int outputChannels = getOutputChannels();
        std::vector<float> output(numSamples * outputChannels, 0.0f);

        for (auto& [id, source] : sources_) {
            if (!source.isPlaying) continue;

            // Get source audio
            std::vector<float> sourceAudio(numSamples);
            for (int i = 0; i < numSamples; i++) {
                int pos = static_cast<int>(source.playbackPosition) + i;
                if (pos < source.audioBuffer.size()) {
                    sourceAudio[i] = source.audioBuffer[pos] * source.gain;
                } else if (source.isLooping) {
                    pos = pos % source.audioBuffer.size();
                    sourceAudio[i] = source.audioBuffer[pos] * source.gain;
                }
            }

            source.playbackPosition += numSamples;

            // Apply distance attenuation
            float distance = source.params.position.distance(listener_.transform.position);
            float attenuation = calculateAttenuation(source.params, distance);

            for (auto& s : sourceAudio) {
                s *= attenuation;
            }

            // Apply doppler
            if (source.params.enableDoppler) {
                float dopplerShift = calculateDopplerShift(source);
                applyDoppler(sourceAudio, dopplerShift);
            }

            // Spatialize
            std::vector<float> spatialized;
            if (format_ == SpatialFormat::Binaural) {
                auto direction = getSourceDirection(source);
                float azimuth = std::atan2(direction.x, direction.z) * 180.0f / M_PI;
                float elevation = std::asin(direction.y) * 180.0f / M_PI;

                auto [left, right] = binaural_.render(sourceAudio, azimuth, elevation);

                spatialized.resize(numSamples * 2);
                for (int i = 0; i < numSamples; i++) {
                    spatialized[i * 2] = left[i];
                    spatialized[i * 2 + 1] = right[i];
                }
            } else {
                // Simple stereo panning for other formats
                auto direction = getSourceDirection(source);
                float pan = std::atan2(direction.x, direction.z) / M_PI;  // -1 to 1

                spatialized.resize(numSamples * 2);
                for (int i = 0; i < numSamples; i++) {
                    float leftGain = std::cos((pan + 1.0f) * 0.25f * M_PI);
                    float rightGain = std::sin((pan + 1.0f) * 0.25f * M_PI);
                    spatialized[i * 2] = sourceAudio[i] * leftGain;
                    spatialized[i * 2 + 1] = sourceAudio[i] * rightGain;
                }
            }

            // Mix to output
            for (int i = 0; i < numSamples * outputChannels && i < spatialized.size(); i++) {
                output[i] += spatialized[i];
            }
        }

        // Apply reverb (simplified)
        if (environment_.reverb.dryWet > 0) {
            applyReverb(output, environment_.reverb);
        }

        return output;
    }

    // Format info
    SpatialFormat getFormat() const { return format_; }
    int getSampleRate() const { return sampleRate_; }
    bool isInitialized() const { return initialized_; }

private:
    SpatialAudioEngine() = default;

    int getOutputChannels() const {
        switch (format_) {
            case SpatialFormat::Stereo:
            case SpatialFormat::Binaural:
                return 2;
            case SpatialFormat::Quad:
                return 4;
            case SpatialFormat::Surround51:
                return 6;
            case SpatialFormat::Surround71:
                return 8;
            case SpatialFormat::Surround714:
                return 12;
            case SpatialFormat::Surround916:
                return 16;
            case SpatialFormat::Ambisonics1stOrder:
                return 4;
            case SpatialFormat::Ambisonics3rdOrder:
                return 16;
            default:
                return 2;
        }
    }

    float calculateAttenuation(const SpatialSourceParams& params, float distance) {
        if (distance < params.minDistance) {
            return 1.0f;
        }
        if (distance > params.maxDistance) {
            return 0.0f;
        }

        float d = std::max(distance, params.minDistance);
        float refDist = params.minDistance;

        switch (params.distanceModel) {
            case DistanceModel::Linear:
                return 1.0f - params.rolloffFactor * (d - refDist) /
                       (params.maxDistance - refDist);
            case DistanceModel::Inverse:
                return refDist / (refDist + params.rolloffFactor * (d - refDist));
            case DistanceModel::InverseSquare:
                return refDist * refDist /
                       (refDist * refDist + params.rolloffFactor * (d - refDist) * (d - refDist));
            case DistanceModel::Exponential:
                return std::pow(d / refDist, -params.rolloffFactor);
            default:
                return 1.0f;
        }
    }

    Vector3 getSourceDirection(const AudioSource& source) const {
        Vector3 toSource = source.params.position - listener_.transform.position;
        float dist = toSource.magnitude();
        if (dist > 0) {
            toSource = toSource * (1.0f / dist);
        }

        // Transform to listener's local space
        Quaternion invRotation;
        invRotation.w = listener_.transform.rotation.w;
        invRotation.x = -listener_.transform.rotation.x;
        invRotation.y = -listener_.transform.rotation.y;
        invRotation.z = -listener_.transform.rotation.z;

        return invRotation.rotate(toSource);
    }

    float calculateDopplerShift(const AudioSource& source) {
        Vector3 toListener = listener_.transform.position - source.params.position;
        float distance = toListener.magnitude();
        if (distance < 0.001f) return 1.0f;

        Vector3 direction = toListener * (1.0f / distance);

        float sourceApproach = -source.params.velocity.dot(direction);
        float listenerApproach = listener_.velocity.dot(direction);

        float speedOfSound = listener_.speedOfSound;
        float shift = (speedOfSound + listenerApproach) / (speedOfSound + sourceApproach);

        return std::clamp(shift, 0.5f, 2.0f) * source.params.dopplerFactor;
    }

    void applyDoppler(std::vector<float>& audio, float shift) {
        if (std::abs(shift - 1.0f) < 0.001f) return;

        std::vector<float> resampled;
        float position = 0.0f;

        while (position < audio.size() - 1) {
            int idx = static_cast<int>(position);
            float frac = position - idx;

            float sample = audio[idx] * (1.0f - frac) + audio[idx + 1] * frac;
            resampled.push_back(sample);

            position += shift;
        }

        audio = resampled;
    }

    void applyReverb(std::vector<float>& audio, const ReverbParams& params) {
        // Simplified reverb (comb filters + allpass)
        float mix = params.dryWet;
        std::vector<float> wet(audio.size(), 0.0f);

        // Comb filter delays (in samples)
        int delays[] = {1557, 1617, 1491, 1422};
        float feedback = std::pow(0.001f, delays[0] / (params.decayTime * sampleRate_));

        for (int d = 0; d < 4; d++) {
            std::vector<float> buffer(delays[d], 0.0f);
            int writePos = 0;

            for (size_t i = 0; i < audio.size(); i++) {
                float input = audio[i];
                float delayed = buffer[writePos];
                buffer[writePos] = input + delayed * feedback;

                wet[i] += delayed * 0.25f;
                writePos = (writePos + 1) % delays[d];
            }
        }

        // Mix dry and wet
        for (size_t i = 0; i < audio.size(); i++) {
            audio[i] = audio[i] * (1.0f - mix) + wet[i] * mix;
        }
    }

    bool initialized_ = false;
    SpatialFormat format_ = SpatialFormat::Binaural;
    int sampleRate_ = 44100;
    int nextSourceId_ = 1;

    SpatialListener listener_;
    RoomEnvironment environment_;
    std::map<std::string, AudioSource> sources_;

    BinauralRenderer binaural_;
    DolbyAtmosRenderer atmos_;
    AmbisonicsProcessor ambisonics_;

    std::mutex mutex_;
};

// =============================================================================
// CONVENIENCE FUNCTIONS
// =============================================================================

inline bool initializeSpatialAudio(SpatialFormat format = SpatialFormat::Binaural) {
    return SpatialAudioEngine::getInstance().initialize(format);
}

inline std::string createSpatialSource(const Vector3& position,
                                        const std::string& name = "") {
    auto& engine = SpatialAudioEngine::getInstance();
    auto id = engine.createSource(name);
    engine.setSourcePosition(id, position);
    return id;
}

inline void moveSpatialSource(const std::string& sourceId, const Vector3& newPosition) {
    SpatialAudioEngine::getInstance().setSourcePosition(sourceId, newPosition);
}

inline void setListenerPosition(const Vector3& position, float yaw = 0.0f) {
    SpatialListener listener;
    listener.transform.position = position;
    listener.transform.rotation = Quaternion::fromEuler(0, yaw, 0);
    SpatialAudioEngine::getInstance().setListener(listener);
}

} // namespace XR
} // namespace Echoel
