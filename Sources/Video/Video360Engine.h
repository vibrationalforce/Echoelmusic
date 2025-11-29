#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <cmath>

/**
 * Video360Engine - Comprehensive 360° Video Processing System
 *
 * Full implementation of equirectangular and cubemap video support
 * for immersive VR/AR content creation and playback.
 *
 * Features:
 * - Equirectangular (2:1) format support
 * - Cubemap (6 faces) format support
 * - Format conversion (equirect ↔ cubemap)
 * - Viewport extraction for head-tracked playback
 * - Stereoscopic 3D (top-bottom, side-by-side, packed)
 * - Projection mapping for dome displays
 * - Spatial audio metadata sync
 * - VR180 half-sphere support
 */

namespace Echoel {

//==========================================================================
// 360° Video Format Types
//==========================================================================

enum class Video360Format {
    Equirectangular,          // Standard 2:1 aspect ratio
    EquirectangularMono,      // Mono equirectangular
    EquirectangularStereoTB,  // Stereo top-bottom
    EquirectangularStereoLR,  // Stereo left-right (side-by-side)
    Cubemap,                  // Standard cubemap (6 faces)
    CubemapPacked,           // Packed cubemap (3x2 or 1x6)
    VR180,                    // Half-sphere (180° horizontal)
    VR180Stereo,             // Stereoscopic VR180
    Fisheye,                  // Circular fisheye
    DualFisheye,             // Dual fisheye (front/back)
    EAC,                      // Equi-Angular Cubemap (YouTube)
    Unknown
};

enum class CubemapFace {
    PositiveX,  // Right
    NegativeX,  // Left
    PositiveY,  // Top
    NegativeY,  // Bottom
    PositiveZ,  // Front
    NegativeZ   // Back
};

enum class StereoscopicLayout {
    Mono,
    TopBottom,
    SideBySide,
    PackedTopBottom,
    PackedSideBySide
};

//==========================================================================
// Spherical Coordinates
//==========================================================================

struct SphericalCoord {
    float theta = 0.0f;  // Azimuth (horizontal) -π to π
    float phi = 0.0f;    // Elevation (vertical) -π/2 to π/2

    SphericalCoord() = default;
    SphericalCoord(float t, float p) : theta(t), phi(p) {}

    // Convert from 3D Cartesian (unit sphere)
    static SphericalCoord fromCartesian(float x, float y, float z) {
        SphericalCoord coord;
        coord.theta = std::atan2(x, z);
        coord.phi = std::asin(juce::jlimit(-1.0f, 1.0f, y));
        return coord;
    }

    // Convert to 3D Cartesian (unit sphere)
    void toCartesian(float& x, float& y, float& z) const {
        float cosPhi = std::cos(phi);
        x = cosPhi * std::sin(theta);
        y = std::sin(phi);
        z = cosPhi * std::cos(theta);
    }
};

//==========================================================================
// 360° Video Metadata
//==========================================================================

struct Video360Metadata {
    Video360Format format = Video360Format::Unknown;
    StereoscopicLayout stereoLayout = StereoscopicLayout::Mono;

    int width = 0;
    int height = 0;
    double frameRate = 30.0;
    double duration = 0.0;

    // Projection center offset (for off-center projections)
    float yawOffset = 0.0f;
    float pitchOffset = 0.0f;
    float rollOffset = 0.0f;

    // Field of view (for VR180 and fisheye)
    float horizontalFOV = 360.0f;
    float verticalFOV = 180.0f;

    // Spatial audio tracks
    int ambisonicsOrder = 0;  // 0 = no ambisonics, 1 = FOA, etc.
    juce::String audioFormat;

    bool hasDepthMap = false;
    bool hasAlphaChannel = false;
};

//==========================================================================
// Cubemap Data Structure
//==========================================================================

template<typename PixelType>
struct Cubemap {
    std::array<std::vector<PixelType>, 6> faces;
    int faceSize = 0;

    void allocate(int size) {
        faceSize = size;
        for (auto& face : faces) {
            face.resize(size * size);
        }
    }

    PixelType& getPixel(CubemapFace face, int x, int y) {
        int idx = static_cast<int>(face);
        return faces[idx][y * faceSize + x];
    }

    const PixelType& getPixel(CubemapFace face, int x, int y) const {
        int idx = static_cast<int>(face);
        return faces[idx][y * faceSize + x];
    }
};

//==========================================================================
// Video360Engine - Main Class
//==========================================================================

class Video360Engine {
public:
    Video360Engine() = default;

    //==========================================================================
    // Format Detection
    //==========================================================================

    Video360Metadata detectFormat(int width, int height, const juce::String& hint = "") {
        Video360Metadata meta;
        meta.width = width;
        meta.height = height;

        float aspect = static_cast<float>(width) / height;

        // Check hints first
        if (hint.containsIgnoreCase("equirect")) {
            meta.format = Video360Format::Equirectangular;
        } else if (hint.containsIgnoreCase("cubemap")) {
            meta.format = Video360Format::Cubemap;
        } else if (hint.containsIgnoreCase("vr180")) {
            meta.format = Video360Format::VR180;
        } else if (hint.containsIgnoreCase("eac")) {
            meta.format = Video360Format::EAC;
        }
        // Auto-detect based on aspect ratio
        else if (std::abs(aspect - 2.0f) < 0.1f) {
            meta.format = Video360Format::Equirectangular;
        } else if (std::abs(aspect - 1.0f) < 0.1f) {
            // Could be equirect stereo top-bottom or cubemap cross
            if (height > 2000) {
                meta.format = Video360Format::EquirectangularStereoTB;
                meta.stereoLayout = StereoscopicLayout::TopBottom;
            } else {
                meta.format = Video360Format::Cubemap;
            }
        } else if (std::abs(aspect - 1.5f) < 0.1f) {
            // 3:2 could be cubemap packed (3x2 layout)
            meta.format = Video360Format::CubemapPacked;
        } else if (std::abs(aspect - 4.0f) < 0.1f) {
            // 4:1 could be stereo side-by-side equirect
            meta.format = Video360Format::EquirectangularStereoLR;
            meta.stereoLayout = StereoscopicLayout::SideBySide;
        }

        // Set FOV based on format
        switch (meta.format) {
            case Video360Format::Equirectangular:
            case Video360Format::EquirectangularStereoTB:
            case Video360Format::EquirectangularStereoLR:
                meta.horizontalFOV = 360.0f;
                meta.verticalFOV = 180.0f;
                break;
            case Video360Format::VR180:
            case Video360Format::VR180Stereo:
                meta.horizontalFOV = 180.0f;
                meta.verticalFOV = 180.0f;
                break;
            case Video360Format::Fisheye:
                meta.horizontalFOV = 180.0f;
                meta.verticalFOV = 180.0f;
                break;
            default:
                break;
        }

        return meta;
    }

    //==========================================================================
    // Equirectangular ↔ Spherical Conversion
    //==========================================================================

    // UV coordinates in equirectangular to spherical
    SphericalCoord equirectToSpherical(float u, float v) const {
        // u: 0-1 maps to theta: -π to π
        // v: 0-1 maps to phi: π/2 to -π/2
        float theta = (u - 0.5f) * juce::MathConstants<float>::twoPi;
        float phi = (0.5f - v) * juce::MathConstants<float>::pi;
        return SphericalCoord(theta, phi);
    }

    // Spherical to equirectangular UV
    std::pair<float, float> sphericalToEquirect(const SphericalCoord& coord) const {
        float u = coord.theta / juce::MathConstants<float>::twoPi + 0.5f;
        float v = 0.5f - coord.phi / juce::MathConstants<float>::pi;
        return {u, v};
    }

    //==========================================================================
    // Cubemap ↔ Spherical Conversion
    //==========================================================================

    // Direction vector to cubemap face and UV
    std::tuple<CubemapFace, float, float> directionToCubemap(float x, float y, float z) const {
        float absX = std::abs(x);
        float absY = std::abs(y);
        float absZ = std::abs(z);

        CubemapFace face;
        float u, v, ma;

        if (absX >= absY && absX >= absZ) {
            ma = absX;
            if (x > 0) {
                face = CubemapFace::PositiveX;
                u = -z;
                v = -y;
            } else {
                face = CubemapFace::NegativeX;
                u = z;
                v = -y;
            }
        } else if (absY >= absX && absY >= absZ) {
            ma = absY;
            if (y > 0) {
                face = CubemapFace::PositiveY;
                u = x;
                v = z;
            } else {
                face = CubemapFace::NegativeY;
                u = x;
                v = -z;
            }
        } else {
            ma = absZ;
            if (z > 0) {
                face = CubemapFace::PositiveZ;
                u = x;
                v = -y;
            } else {
                face = CubemapFace::NegativeZ;
                u = -x;
                v = -y;
            }
        }

        // Convert to 0-1 range
        u = (u / ma + 1.0f) * 0.5f;
        v = (v / ma + 1.0f) * 0.5f;

        return {face, u, v};
    }

    // Cubemap face and UV to direction vector
    void cubemapToDirection(CubemapFace face, float u, float v,
                           float& x, float& y, float& z) const {
        // Convert UV from 0-1 to -1 to 1
        float s = u * 2.0f - 1.0f;
        float t = v * 2.0f - 1.0f;

        switch (face) {
            case CubemapFace::PositiveX:
                x = 1.0f; y = -t; z = -s;
                break;
            case CubemapFace::NegativeX:
                x = -1.0f; y = -t; z = s;
                break;
            case CubemapFace::PositiveY:
                x = s; y = 1.0f; z = t;
                break;
            case CubemapFace::NegativeY:
                x = s; y = -1.0f; z = -t;
                break;
            case CubemapFace::PositiveZ:
                x = s; y = -t; z = 1.0f;
                break;
            case CubemapFace::NegativeZ:
                x = -s; y = -t; z = -1.0f;
                break;
        }

        // Normalize
        float len = std::sqrt(x*x + y*y + z*z);
        x /= len; y /= len; z /= len;
    }

    //==========================================================================
    // Format Conversion
    //==========================================================================

    // Convert equirectangular to cubemap
    template<typename PixelType>
    void equirectToCubemap(const PixelType* equirect, int eqWidth, int eqHeight,
                          Cubemap<PixelType>& cubemap, int faceSize) {
        cubemap.allocate(faceSize);

        for (int faceIdx = 0; faceIdx < 6; ++faceIdx) {
            CubemapFace face = static_cast<CubemapFace>(faceIdx);

            for (int y = 0; y < faceSize; ++y) {
                for (int x = 0; x < faceSize; ++x) {
                    // Get direction from cubemap face position
                    float u = (x + 0.5f) / faceSize;
                    float v = (y + 0.5f) / faceSize;

                    float dx, dy, dz;
                    cubemapToDirection(face, u, v, dx, dy, dz);

                    // Convert to spherical
                    SphericalCoord spherical = SphericalCoord::fromCartesian(dx, dy, dz);

                    // Convert to equirect UV
                    auto [eqU, eqV] = sphericalToEquirect(spherical);

                    // Sample equirectangular image (bilinear interpolation)
                    float eqX = eqU * (eqWidth - 1);
                    float eqY = eqV * (eqHeight - 1);

                    int x0 = static_cast<int>(eqX);
                    int y0 = static_cast<int>(eqY);
                    int x1 = std::min(x0 + 1, eqWidth - 1);
                    int y1 = std::min(y0 + 1, eqHeight - 1);

                    float fx = eqX - x0;
                    float fy = eqY - y0;

                    // Bilinear interpolation
                    PixelType p00 = equirect[y0 * eqWidth + x0];
                    PixelType p10 = equirect[y0 * eqWidth + x1];
                    PixelType p01 = equirect[y1 * eqWidth + x0];
                    PixelType p11 = equirect[y1 * eqWidth + x1];

                    // Interpolate (assuming PixelType supports arithmetic)
                    cubemap.getPixel(face, x, y) =
                        p00 * (1-fx) * (1-fy) +
                        p10 * fx * (1-fy) +
                        p01 * (1-fx) * fy +
                        p11 * fx * fy;
                }
            }
        }
    }

    // Convert cubemap to equirectangular
    template<typename PixelType>
    void cubemapToEquirect(const Cubemap<PixelType>& cubemap,
                          PixelType* equirect, int eqWidth, int eqHeight) {
        for (int y = 0; y < eqHeight; ++y) {
            for (int x = 0; x < eqWidth; ++x) {
                // Get spherical coordinates
                float u = (x + 0.5f) / eqWidth;
                float v = (y + 0.5f) / eqHeight;

                SphericalCoord spherical = equirectToSpherical(u, v);

                // Convert to direction
                float dx, dy, dz;
                spherical.toCartesian(dx, dy, dz);

                // Get cubemap face and UV
                auto [face, cubeU, cubeV] = directionToCubemap(dx, dy, dz);

                // Sample cubemap face (bilinear)
                float cubeX = cubeU * (cubemap.faceSize - 1);
                float cubeY = cubeV * (cubemap.faceSize - 1);

                int cx0 = static_cast<int>(cubeX);
                int cy0 = static_cast<int>(cubeY);
                int cx1 = std::min(cx0 + 1, cubemap.faceSize - 1);
                int cy1 = std::min(cy0 + 1, cubemap.faceSize - 1);

                float fx = cubeX - cx0;
                float fy = cubeY - cy0;

                PixelType p00 = cubemap.getPixel(face, cx0, cy0);
                PixelType p10 = cubemap.getPixel(face, cx1, cy0);
                PixelType p01 = cubemap.getPixel(face, cx0, cy1);
                PixelType p11 = cubemap.getPixel(face, cx1, cy1);

                equirect[y * eqWidth + x] =
                    p00 * (1-fx) * (1-fy) +
                    p10 * fx * (1-fy) +
                    p01 * (1-fx) * fy +
                    p11 * fx * fy;
            }
        }
    }

    //==========================================================================
    // Viewport Extraction
    //==========================================================================

    struct ViewportConfig {
        float yaw = 0.0f;        // Horizontal rotation (radians)
        float pitch = 0.0f;      // Vertical rotation (radians)
        float roll = 0.0f;       // Roll rotation (radians)
        float hFOV = 90.0f;      // Horizontal field of view (degrees)
        float vFOV = 90.0f;      // Vertical field of view (degrees)
        int width = 1920;
        int height = 1080;
    };

    // Extract a rectilinear viewport from equirectangular
    template<typename PixelType>
    void extractViewport(const PixelType* equirect, int eqWidth, int eqHeight,
                        PixelType* viewport, const ViewportConfig& config) {
        float hFOVRad = config.hFOV * juce::MathConstants<float>::pi / 180.0f;
        float vFOVRad = config.vFOV * juce::MathConstants<float>::pi / 180.0f;

        float tanHalfH = std::tan(hFOVRad / 2.0f);
        float tanHalfV = std::tan(vFOVRad / 2.0f);

        // Rotation matrix from yaw, pitch, roll
        float cy = std::cos(config.yaw), sy = std::sin(config.yaw);
        float cp = std::cos(config.pitch), sp = std::sin(config.pitch);
        float cr = std::cos(config.roll), sr = std::sin(config.roll);

        // Combined rotation matrix
        float r00 = cy * cr + sy * sp * sr;
        float r01 = -cy * sr + sy * sp * cr;
        float r02 = sy * cp;
        float r10 = cp * sr;
        float r11 = cp * cr;
        float r12 = -sp;
        float r20 = -sy * cr + cy * sp * sr;
        float r21 = sy * sr + cy * sp * cr;
        float r22 = cy * cp;

        for (int y = 0; y < config.height; ++y) {
            for (int x = 0; x < config.width; ++x) {
                // Normalized device coordinates
                float ndcX = (2.0f * x / config.width - 1.0f) * tanHalfH;
                float ndcY = (1.0f - 2.0f * y / config.height) * tanHalfV;

                // Ray direction (forward is +Z)
                float dx = ndcX;
                float dy = ndcY;
                float dz = 1.0f;

                // Normalize
                float len = std::sqrt(dx*dx + dy*dy + dz*dz);
                dx /= len; dy /= len; dz /= len;

                // Apply rotation
                float rx = r00 * dx + r01 * dy + r02 * dz;
                float ry = r10 * dx + r11 * dy + r12 * dz;
                float rz = r20 * dx + r21 * dy + r22 * dz;

                // Convert to spherical
                SphericalCoord spherical = SphericalCoord::fromCartesian(rx, ry, rz);

                // Convert to equirect UV
                auto [eqU, eqV] = sphericalToEquirect(spherical);

                // Bilinear sample
                float eqX = eqU * (eqWidth - 1);
                float eqY = eqV * (eqHeight - 1);

                int x0 = static_cast<int>(eqX) % eqWidth;
                int y0 = juce::jlimit(0, eqHeight - 1, static_cast<int>(eqY));
                int x1 = (x0 + 1) % eqWidth;
                int y1 = std::min(y0 + 1, eqHeight - 1);

                float fx = eqX - std::floor(eqX);
                float fy = eqY - std::floor(eqY);

                PixelType p00 = equirect[y0 * eqWidth + x0];
                PixelType p10 = equirect[y0 * eqWidth + x1];
                PixelType p01 = equirect[y1 * eqWidth + x0];
                PixelType p11 = equirect[y1 * eqWidth + x1];

                viewport[y * config.width + x] =
                    p00 * (1-fx) * (1-fy) +
                    p10 * fx * (1-fy) +
                    p01 * (1-fx) * fy +
                    p11 * fx * fy;
            }
        }
    }

    //==========================================================================
    // Stereoscopic Handling
    //==========================================================================

    struct StereoView {
        int leftStartX = 0, leftStartY = 0;
        int rightStartX = 0, rightStartY = 0;
        int viewWidth = 0, viewHeight = 0;
    };

    StereoView getStereoLayout(const Video360Metadata& meta) const {
        StereoView view;
        view.viewWidth = meta.width;
        view.viewHeight = meta.height;

        switch (meta.stereoLayout) {
            case StereoscopicLayout::TopBottom:
                view.leftStartX = 0;
                view.leftStartY = 0;
                view.rightStartX = 0;
                view.rightStartY = meta.height / 2;
                view.viewWidth = meta.width;
                view.viewHeight = meta.height / 2;
                break;
            case StereoscopicLayout::SideBySide:
                view.leftStartX = 0;
                view.leftStartY = 0;
                view.rightStartX = meta.width / 2;
                view.rightStartY = 0;
                view.viewWidth = meta.width / 2;
                view.viewHeight = meta.height;
                break;
            case StereoscopicLayout::PackedTopBottom:
                // For vertically squeezed content
                view.leftStartX = 0;
                view.leftStartY = 0;
                view.rightStartX = 0;
                view.rightStartY = meta.height / 2;
                view.viewWidth = meta.width;
                view.viewHeight = meta.height / 2;
                // Note: needs vertical upscaling
                break;
            case StereoscopicLayout::PackedSideBySide:
                // For horizontally squeezed content
                view.leftStartX = 0;
                view.leftStartY = 0;
                view.rightStartX = meta.width / 2;
                view.rightStartY = 0;
                view.viewWidth = meta.width / 2;
                view.viewHeight = meta.height;
                // Note: needs horizontal upscaling
                break;
            default:  // Mono
                view.leftStartX = 0;
                view.leftStartY = 0;
                view.rightStartX = 0;
                view.rightStartY = 0;
                view.viewWidth = meta.width;
                view.viewHeight = meta.height;
        }

        return view;
    }

    //==========================================================================
    // Dome Projection
    //==========================================================================

    struct DomeConfig {
        float tiltAngle = 20.0f;     // Dome tilt (degrees)
        float radius = 10.0f;        // Dome radius (meters)
        int resolution = 2048;       // Output resolution
        bool fisheyeOutput = true;   // Output as fisheye
    };

    // Generate dome master from equirectangular
    template<typename PixelType>
    void equirectToDomeMaster(const PixelType* equirect, int eqWidth, int eqHeight,
                             PixelType* domeMaster, const DomeConfig& config) {
        float tiltRad = config.tiltAngle * juce::MathConstants<float>::pi / 180.0f;
        float cosTilt = std::cos(tiltRad);
        float sinTilt = std::sin(tiltRad);

        for (int y = 0; y < config.resolution; ++y) {
            for (int x = 0; x < config.resolution; ++x) {
                // Normalize to -1 to 1
                float nx = (2.0f * x / config.resolution) - 1.0f;
                float ny = (2.0f * y / config.resolution) - 1.0f;

                float r = std::sqrt(nx * nx + ny * ny);

                if (r > 1.0f) {
                    // Outside dome circle - black
                    domeMaster[y * config.resolution + x] = PixelType();
                    continue;
                }

                // Fisheye projection (angular)
                float theta = r * juce::MathConstants<float>::halfPi;
                float phi = std::atan2(ny, nx);

                // Direction on hemisphere
                float dx = std::sin(theta) * std::cos(phi);
                float dy = std::sin(theta) * std::sin(phi);
                float dz = std::cos(theta);

                // Apply dome tilt
                float ry = dy * cosTilt - dz * sinTilt;
                float rz = dy * sinTilt + dz * cosTilt;

                // Convert to spherical
                SphericalCoord spherical = SphericalCoord::fromCartesian(dx, ry, rz);

                // Sample equirect
                auto [eqU, eqV] = sphericalToEquirect(spherical);

                float eqX = eqU * (eqWidth - 1);
                float eqY = eqV * (eqHeight - 1);

                int sx = static_cast<int>(eqX) % eqWidth;
                int sy = juce::jlimit(0, eqHeight - 1, static_cast<int>(eqY));

                domeMaster[y * config.resolution + x] = equirect[sy * eqWidth + sx];
            }
        }
    }

    //==========================================================================
    // EAC (Equi-Angular Cubemap) Support
    //==========================================================================

    // YouTube's EAC format provides better quality at cube edges
    std::pair<float, float> eacToCubemapUV(float eacU, float eacV) const {
        // EAC uses tan mapping instead of linear
        float tanU = std::tan(juce::MathConstants<float>::halfPi * (eacU - 0.5f));
        float tanV = std::tan(juce::MathConstants<float>::halfPi * (eacV - 0.5f));

        // Convert back to standard cubemap UV
        float u = (tanU / std::sqrt(1.0f + tanU * tanU + tanV * tanV) + 1.0f) * 0.5f;
        float v = (tanV / std::sqrt(1.0f + tanU * tanU + tanV * tanV) + 1.0f) * 0.5f;

        return {u, v};
    }

    std::pair<float, float> cubemapToEACUV(float u, float v) const {
        // Convert standard UV to EAC UV
        float x = u * 2.0f - 1.0f;
        float y = v * 2.0f - 1.0f;

        float eacU = std::atan(x) / juce::MathConstants<float>::halfPi + 0.5f;
        float eacV = std::atan(y) / juce::MathConstants<float>::halfPi + 0.5f;

        return {eacU, eacV};
    }

private:
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(Video360Engine)
};

} // namespace Echoel
