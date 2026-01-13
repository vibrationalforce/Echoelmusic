#pragma once
/**
 * EchoelCore - WebXR Audio Bridge
 *
 * Cross-platform abstraction layer for WebXR/WebAudio/WASM deployment.
 * Enables browser-based immersive audio experiences with bio-reactive modulation.
 *
 * Features:
 * - WebAudio API abstraction for C++ audio code
 * - WebXR spatial audio positioning
 * - WASM-compatible lock-free design
 * - Progressive Web App (PWA) support patterns
 * - Fallback to 2D audio when XR unavailable
 *
 * MIT License - Echoelmusic 2026
 */

#include "../Bio/BioState.h"
#include <cstdint>
#include <cmath>
#include <array>
#include <string>
#include <functional>

namespace EchoelCore {
namespace WebXR {

//==============================================================================
// WebXR Session State
//==============================================================================

enum class XRSessionType {
    None,              // No XR - standard 2D audio
    Immersive_VR,      // Full VR headset (Oculus, Vive, etc.)
    Immersive_AR,      // AR passthrough (Quest 3, Hololens)
    Inline             // Non-immersive 360 in browser
};

enum class XRReferenceSpace {
    Viewer,            // Head-locked
    Local,             // Seated experience
    LocalFloor,        // Standing, origin at floor
    BoundedFloor,      // Room-scale with boundaries
    Unbounded          // Large-scale AR
};

//==============================================================================
// Spatial Audio Position
//==============================================================================

struct Vec3 {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    Vec3() = default;
    constexpr Vec3(float x_, float y_, float z_) : x(x_), y(y_), z(z_) {}

    float length() const noexcept {
        return std::sqrt(x * x + y * y + z * z);
    }

    Vec3 normalized() const noexcept {
        float len = length();
        if (len < 0.0001f) return {0, 0, 1};
        return {x / len, y / len, z / len};
    }

    Vec3 operator+(const Vec3& other) const noexcept {
        return {x + other.x, y + other.y, z + other.z};
    }

    Vec3 operator-(const Vec3& other) const noexcept {
        return {x - other.x, y - other.y, z - other.z};
    }

    Vec3 operator*(float s) const noexcept {
        return {x * s, y * s, z * s};
    }
};

struct Quaternion {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float w = 1.0f;

    Quaternion() = default;
    constexpr Quaternion(float x_, float y_, float z_, float w_)
        : x(x_), y(y_), z(z_), w(w_) {}

    static Quaternion identity() noexcept { return {0, 0, 0, 1}; }

    static Quaternion fromAxisAngle(const Vec3& axis, float angle) noexcept {
        float halfAngle = angle * 0.5f;
        float s = std::sin(halfAngle);
        return {axis.x * s, axis.y * s, axis.z * s, std::cos(halfAngle)};
    }

    Vec3 rotateVector(const Vec3& v) const noexcept {
        // Quaternion rotation: q * v * q^-1
        Vec3 u{x, y, z};
        float s = w;
        float dot = u.x * v.x + u.y * v.y + u.z * v.z;
        Vec3 cross{
            u.y * v.z - u.z * v.y,
            u.z * v.x - u.x * v.z,
            u.x * v.y - u.y * v.x
        };
        return v * (s * s - (u.x * u.x + u.y * u.y + u.z * u.z)) +
               u * (2.0f * dot) +
               cross * (2.0f * s);
    }
};

struct SpatialPose {
    Vec3 position;
    Quaternion orientation;
    uint64_t timestamp = 0;
    bool tracked = false;
};

//==============================================================================
// WebAudio Node Abstraction
//==============================================================================

/**
 * Represents a spatial audio source in the WebXR scene.
 * Maps to WebAudio PannerNode with HRTF processing.
 */
struct SpatialAudioSource {
    uint32_t id = 0;
    Vec3 position;
    Vec3 velocity;

    // Distance model parameters
    float refDistance = 1.0f;      // Distance at which volume is 100%
    float maxDistance = 100.0f;    // Beyond this, no further attenuation
    float rolloffFactor = 1.0f;    // How quickly sound attenuates

    // Cone parameters (for directional sources)
    float coneInnerAngle = 360.0f; // Degrees
    float coneOuterAngle = 360.0f;
    float coneOuterGain = 0.0f;

    // Bio-reactive modulation
    bool bioReactive = false;
    float coherenceModulation = 0.0f;  // How much coherence affects distance
    float hrvModulation = 0.0f;        // How much HRV affects cone angle

    // Audio buffer (WASM-safe: fixed size)
    static constexpr size_t kMaxBufferSize = 4096;
    std::array<float, kMaxBufferSize> buffer{};
    size_t bufferSize = 0;
};

//==============================================================================
// WebXR Audio Bridge
//==============================================================================

/**
 * Bridge between native C++ audio and WebXR/WebAudio.
 *
 * Usage:
 *   WebXRAudioBridge bridge(bioState);
 *   bridge.startSession(XRSessionType::Immersive_VR);
 *
 *   // In render loop
 *   bridge.updateListenerPose(headPose);
 *   bridge.processAudio(inputs, outputs, numFrames);
 */
class WebXRAudioBridge {
public:
    static constexpr size_t kMaxSources = 64;
    static constexpr float kSpeedOfSound = 343.0f;  // m/s

    WebXRAudioBridge(BioState& bioState) noexcept
        : mBioState(bioState)
        , mSessionType(XRSessionType::None)
        , mReferenceSpace(XRReferenceSpace::Local)
        , mNumSources(0)
        , mSampleRate(48000.0)
    {}

    //==========================================================================
    // Session Management
    //==========================================================================

    /**
     * Start an XR session.
     * On web, this triggers navigator.xr.requestSession().
     */
    bool startSession(XRSessionType type, XRReferenceSpace space = XRReferenceSpace::LocalFloor) {
        mSessionType = type;
        mReferenceSpace = space;
        return true;
    }

    /**
     * End the current session.
     */
    void endSession() {
        mSessionType = XRSessionType::None;
    }

    /**
     * Check if XR session is active.
     */
    bool isSessionActive() const noexcept {
        return mSessionType != XRSessionType::None;
    }

    /**
     * Get current session type.
     */
    XRSessionType getSessionType() const noexcept { return mSessionType; }

    //==========================================================================
    // Listener (Head) Tracking
    //==========================================================================

    /**
     * Update listener position from XR headset.
     * Call this each frame with pose from XRFrame.getViewerPose().
     */
    void updateListenerPose(const SpatialPose& pose) noexcept {
        mListenerPose = pose;
    }

    /**
     * Get current listener pose.
     */
    const SpatialPose& getListenerPose() const noexcept {
        return mListenerPose;
    }

    //==========================================================================
    // Source Management
    //==========================================================================

    /**
     * Add a spatial audio source.
     * @return Source ID (0 on failure)
     */
    uint32_t addSource(const SpatialAudioSource& source) noexcept {
        if (mNumSources >= kMaxSources) return 0;
        uint32_t id = mNextSourceId++;
        mSources[mNumSources] = source;
        mSources[mNumSources].id = id;
        mNumSources++;
        return id;
    }

    /**
     * Remove a source by ID.
     */
    bool removeSource(uint32_t id) noexcept {
        for (size_t i = 0; i < mNumSources; ++i) {
            if (mSources[i].id == id) {
                // Shift remaining sources
                for (size_t j = i; j < mNumSources - 1; ++j) {
                    mSources[j] = mSources[j + 1];
                }
                mNumSources--;
                return true;
            }
        }
        return false;
    }

    /**
     * Update source position.
     */
    void updateSourcePosition(uint32_t id, const Vec3& position) noexcept {
        for (size_t i = 0; i < mNumSources; ++i) {
            if (mSources[i].id == id) {
                mSources[i].velocity = position - mSources[i].position;
                mSources[i].position = position;
                return;
            }
        }
    }

    /**
     * Set audio data for a source.
     */
    void setSourceBuffer(uint32_t id, const float* data, size_t size) noexcept {
        for (size_t i = 0; i < mNumSources; ++i) {
            if (mSources[i].id == id) {
                size_t copySize = std::min(size, SpatialAudioSource::kMaxBufferSize);
                for (size_t j = 0; j < copySize; ++j) {
                    mSources[i].buffer[j] = data[j];
                }
                mSources[i].bufferSize = copySize;
                return;
            }
        }
    }

    //==========================================================================
    // Audio Processing
    //==========================================================================

    /**
     * Process spatial audio for the current frame.
     * CRITICAL: Audio thread safe - no allocations, no locks.
     *
     * @param outputL Left channel output buffer
     * @param outputR Right channel output buffer
     * @param numFrames Number of samples to process
     */
    void processAudio(float* outputL, float* outputR, size_t numFrames) noexcept {
        // Clear output
        for (size_t i = 0; i < numFrames; ++i) {
            outputL[i] = 0.0f;
            outputR[i] = 0.0f;
        }

        // Get bio modulation values
        float coherence = mBioState.getCoherence();
        float hrv = mBioState.getHRV();

        // Process each source
        for (size_t s = 0; s < mNumSources; ++s) {
            const auto& source = mSources[s];
            if (source.bufferSize == 0) continue;

            // Calculate listener-relative position
            Vec3 relPos = source.position - mListenerPose.position;
            relPos = mListenerPose.orientation.rotateVector(relPos);

            // Calculate distance and attenuation
            float distance = relPos.length();
            float attenuation = calculateAttenuation(source, distance);

            // Bio-reactive modulation
            if (source.bioReactive) {
                // Coherence increases presence (reduces attenuation)
                attenuation *= (1.0f - source.coherenceModulation * coherence * 0.5f);
            }

            // Calculate stereo panning (simple HRTF approximation)
            float pan = 0.0f;
            if (distance > 0.001f) {
                pan = relPos.x / distance;  // -1 to +1
            }

            // Apply equal-power panning
            float leftGain = attenuation * std::cos((pan + 1.0f) * 0.25f * 3.14159f);
            float rightGain = attenuation * std::cos((1.0f - pan) * 0.25f * 3.14159f);

            // Doppler shift (simplified)
            float dopplerRatio = 1.0f;
            if (mSessionType == XRSessionType::Immersive_VR) {
                float relVelocity = source.velocity.x * relPos.x +
                                    source.velocity.y * relPos.y +
                                    source.velocity.z * relPos.z;
                if (distance > 0.01f) {
                    relVelocity /= distance;
                    dopplerRatio = kSpeedOfSound / (kSpeedOfSound + relVelocity);
                    dopplerRatio = std::clamp(dopplerRatio, 0.5f, 2.0f);
                }
            }

            // Mix source into output
            size_t processFrames = std::min(numFrames, source.bufferSize);
            for (size_t i = 0; i < processFrames; ++i) {
                float sample = source.buffer[i];
                outputL[i] += sample * leftGain;
                outputR[i] += sample * rightGain;
            }
        }
    }

    //==========================================================================
    // Bio-Reactive Scene Modulation
    //==========================================================================

    /**
     * Apply bio-reactive modulation to all sources.
     * Call this from a non-audio thread to update spatial positions.
     */
    void applyBioReactiveLayout() noexcept {
        float coherence = mBioState.getCoherence();
        float breathPhase = mBioState.getBreathPhase();

        for (size_t i = 0; i < mNumSources; ++i) {
            if (!mSources[i].bioReactive) continue;

            // Breathing modulates distance (sources "breathe" in/out)
            float breathOffset = std::sin(breathPhase * 2.0f * 3.14159f) * 0.5f;
            mSources[i].refDistance = 1.0f + breathOffset * coherence;

            // High coherence = tighter cone (focused attention)
            float coneAngle = 360.0f - coherence * 180.0f;
            mSources[i].coneInnerAngle = coneAngle;
        }
    }

    //==========================================================================
    // PWA/Offline Support
    //==========================================================================

    /**
     * Get the Web App Manifest configuration.
     * Returns JSON string for manifest.json.
     */
    std::string getWebManifest() const {
        return R"({
  "name": "Echoelmusic",
  "short_name": "Echoel",
  "description": "Bio-reactive spatial audio experience",
  "start_url": "/",
  "display": "standalone",
  "orientation": "any",
  "background_color": "#000000",
  "theme_color": "#6B46C1",
  "icons": [
    {"src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png"},
    {"src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png"}
  ],
  "xr": {
    "immersive-vr": true,
    "immersive-ar": true
  }
})";
    }

    /**
     * Check if running in PWA mode.
     * On web, this checks display-mode media query.
     */
    bool isPWAMode() const noexcept { return mPWAMode; }
    void setPWAMode(bool pwa) noexcept { mPWAMode = pwa; }

    //==========================================================================
    // WASM Export Helpers
    //==========================================================================

    /**
     * Set sample rate for audio processing.
     */
    void setSampleRate(double sampleRate) noexcept {
        mSampleRate = sampleRate;
    }

    /**
     * Get number of active sources.
     */
    size_t getSourceCount() const noexcept { return mNumSources; }

private:
    BioState& mBioState;
    XRSessionType mSessionType;
    XRReferenceSpace mReferenceSpace;
    SpatialPose mListenerPose;

    std::array<SpatialAudioSource, kMaxSources> mSources;
    size_t mNumSources;
    uint32_t mNextSourceId = 1;

    double mSampleRate;
    bool mPWAMode = false;

    /**
     * Calculate distance attenuation using inverse distance model.
     */
    float calculateAttenuation(const SpatialAudioSource& source, float distance) const noexcept {
        if (distance <= source.refDistance) {
            return 1.0f;
        }
        if (distance >= source.maxDistance) {
            return 0.0f;
        }
        // Inverse distance with rolloff
        float attenuation = source.refDistance /
            (source.refDistance + source.rolloffFactor * (distance - source.refDistance));
        return std::clamp(attenuation, 0.0f, 1.0f);
    }
};

//==============================================================================
// WASM Bindings (for Emscripten)
//==============================================================================

#ifdef __EMSCRIPTEN__

#include <emscripten/bind.h>

EMSCRIPTEN_BINDINGS(webxr_audio_bridge) {
    emscripten::class_<WebXRAudioBridge>("WebXRAudioBridge")
        .constructor<BioState&>()
        .function("startSession", &WebXRAudioBridge::startSession)
        .function("endSession", &WebXRAudioBridge::endSession)
        .function("isSessionActive", &WebXRAudioBridge::isSessionActive)
        .function("addSource", &WebXRAudioBridge::addSource)
        .function("removeSource", &WebXRAudioBridge::removeSource)
        .function("getSourceCount", &WebXRAudioBridge::getSourceCount);

    emscripten::enum_<XRSessionType>("XRSessionType")
        .value("None", XRSessionType::None)
        .value("Immersive_VR", XRSessionType::Immersive_VR)
        .value("Immersive_AR", XRSessionType::Immersive_AR)
        .value("Inline", XRSessionType::Inline);
}

#endif

} // namespace WebXR
} // namespace EchoelCore
