/*
  ==============================================================================

    LaserScanEngine.h
    Echoelmusic - Bio-Reactive DAW

    Advanced Laser Scanning System with Environment Mapping
    LiDAR integration, crowd detection, and adaptive beam control

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "LaserForce.h"
#include "../Core/RalphWiggumAPI.h"
#include <memory>
#include <vector>
#include <map>
#include <mutex>
#include <atomic>
#include <thread>
#include <queue>
#include <cmath>

namespace Echoel {
namespace Visual {

//==============================================================================
/**
    3D point with additional scan metadata
*/
struct ScanPoint
{
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float intensity = 1.0f;
    float reflectivity = 0.0f;
    uint32_t timestamp = 0;
    uint8_t classification = 0;  // 0=unclassified, 1=ground, 2=crowd, 3=structure
};

//==============================================================================
/**
    Point cloud for environment mapping
*/
class PointCloud
{
public:
    void addPoint(const ScanPoint& point)
    {
        std::lock_guard<std::mutex> lock(cloudMutex);
        points.push_back(point);

        // Update bounds
        minBounds.x = std::min(minBounds.x, point.x);
        minBounds.y = std::min(minBounds.y, point.y);
        minBounds.z = std::min(minBounds.z, point.z);
        maxBounds.x = std::max(maxBounds.x, point.x);
        maxBounds.y = std::max(maxBounds.y, point.y);
        maxBounds.z = std::max(maxBounds.z, point.z);
    }

    void addPoints(const std::vector<ScanPoint>& newPoints)
    {
        std::lock_guard<std::mutex> lock(cloudMutex);
        points.insert(points.end(), newPoints.begin(), newPoints.end());

        for (const auto& point : newPoints)
        {
            minBounds.x = std::min(minBounds.x, point.x);
            minBounds.y = std::min(minBounds.y, point.y);
            minBounds.z = std::min(minBounds.z, point.z);
            maxBounds.x = std::max(maxBounds.x, point.x);
            maxBounds.y = std::max(maxBounds.y, point.y);
            maxBounds.z = std::max(maxBounds.z, point.z);
        }
    }

    void clear()
    {
        std::lock_guard<std::mutex> lock(cloudMutex);
        points.clear();
        minBounds = { 0, 0, 0, 0, 0, 0, 0 };
        maxBounds = { 0, 0, 0, 0, 0, 0, 0 };
    }

    size_t size() const
    {
        std::lock_guard<std::mutex> lock(cloudMutex);
        return points.size();
    }

    std::vector<ScanPoint> getPoints() const
    {
        std::lock_guard<std::mutex> lock(cloudMutex);
        return points;
    }

    ScanPoint getMinBounds() const { return minBounds; }
    ScanPoint getMaxBounds() const { return maxBounds; }

    // Spatial query - get points within radius
    std::vector<ScanPoint> getPointsInRadius(float x, float y, float z, float radius) const
    {
        std::lock_guard<std::mutex> lock(cloudMutex);
        std::vector<ScanPoint> result;

        float radiusSq = radius * radius;
        for (const auto& point : points)
        {
            float dx = point.x - x;
            float dy = point.y - y;
            float dz = point.z - z;
            if (dx * dx + dy * dy + dz * dz <= radiusSq)
                result.push_back(point);
        }

        return result;
    }

    // Classification query
    std::vector<ScanPoint> getPointsByClassification(uint8_t classification) const
    {
        std::lock_guard<std::mutex> lock(cloudMutex);
        std::vector<ScanPoint> result;

        for (const auto& point : points)
        {
            if (point.classification == classification)
                result.push_back(point);
        }

        return result;
    }

private:
    mutable std::mutex cloudMutex;
    std::vector<ScanPoint> points;
    ScanPoint minBounds;
    ScanPoint maxBounds;
};

//==============================================================================
/**
    Crowd detection zone
*/
struct CrowdZone
{
    juce::String id;
    float centerX = 0.0f;
    float centerY = 0.0f;
    float width = 0.0f;
    float depth = 0.0f;
    float density = 0.0f;      // People per square meter (estimated)
    float movement = 0.0f;     // Average movement intensity 0-1
    float energy = 0.0f;       // Crowd energy level 0-1
    int estimatedCount = 0;
    bool isSafeZone = false;   // Laser-free zone
};

//==============================================================================
/**
    LiDAR device configuration
*/
struct LiDARConfig
{
    enum class DeviceType
    {
        Velodyne_VLP16,
        Velodyne_VLP32,
        Ouster_OS0,
        Ouster_OS1,
        Livox_Mid40,
        Intel_RealSense,
        Custom
    };

    DeviceType deviceType = DeviceType::Velodyne_VLP16;
    juce::String ipAddress = "192.168.1.201";
    int dataPort = 2368;
    int telemetryPort = 8308;

    float horizontalFOV = 360.0f;      // Degrees
    float verticalFOV = 30.0f;
    int horizontalResolution = 1800;    // Points per scan
    int verticalChannels = 16;
    float maxRange = 100.0f;            // Meters
    float minRange = 0.5f;
    int rotationsPerSecond = 10;

    // Calibration
    float xOffset = 0.0f;
    float yOffset = 0.0f;
    float zOffset = 0.0f;
    float roll = 0.0f;
    float pitch = 0.0f;
    float yaw = 0.0f;
};

//==============================================================================
/**
    Environment mapping result
*/
struct EnvironmentMap
{
    PointCloud pointCloud;
    std::vector<CrowdZone> crowdZones;

    // Detected surfaces
    struct Surface
    {
        juce::String id;
        juce::String type;  // "floor", "wall", "ceiling", "stage"
        std::vector<ScanPoint> boundary;
        float area = 0.0f;
        bool isProjectable = false;
    };
    std::vector<Surface> surfaces;

    // Room dimensions
    float roomWidth = 0.0f;
    float roomDepth = 0.0f;
    float roomHeight = 0.0f;

    // Stage detection
    bool stageDetected = false;
    float stageX = 0.0f;
    float stageY = 0.0f;
    float stageWidth = 0.0f;
    float stageDepth = 0.0f;
    float stageHeight = 0.0f;
};

//==============================================================================
/**
    Scan pattern for laser scanning
*/
struct ScanPattern
{
    enum class Type
    {
        Linear,
        Spiral,
        Lissajous,
        Random,
        Grid,
        Radial,
        Custom
    };

    Type type = Type::Linear;

    float horizontalStart = -45.0f;    // Degrees
    float horizontalEnd = 45.0f;
    float verticalStart = -15.0f;
    float verticalEnd = 15.0f;

    float speed = 1.0f;                // Scans per second
    int pointsPerLine = 100;
    int linesPerFrame = 50;

    // Lissajous parameters
    float lissajousA = 3.0f;
    float lissajousB = 4.0f;
    float lissajousPhase = 0.0f;

    // Custom pattern (waypoints)
    std::vector<std::pair<float, float>> customPattern;
};

//==============================================================================
/**
    Adaptive beam control based on environment
*/
class AdaptiveBeamController
{
public:
    struct BeamConstraint
    {
        float minHorizontal = -90.0f;
        float maxHorizontal = 90.0f;
        float minVertical = -45.0f;
        float maxVertical = 45.0f;
        float maxPower = 1.0f;
        bool enabled = true;
    };

    void updateFromEnvironment(const EnvironmentMap& envMap)
    {
        std::lock_guard<std::mutex> lock(controllerMutex);

        // Create safe zones around crowd areas
        crowdConstraints.clear();
        for (const auto& zone : envMap.crowdZones)
        {
            if (zone.isSafeZone || zone.density > 0.5f)
            {
                BeamConstraint constraint;
                // Calculate angles to crowd zone
                float angleH = std::atan2(zone.centerY, zone.centerX) * 180.0f / 3.14159f;
                float halfWidth = std::atan2(zone.width / 2.0f, zone.centerY) * 180.0f / 3.14159f;

                constraint.minHorizontal = angleH - halfWidth - safetyMargin;
                constraint.maxHorizontal = angleH + halfWidth + safetyMargin;
                constraint.maxPower = 0.0f;  // No laser in crowd zones

                crowdConstraints.push_back(constraint);
            }
        }
    }

    bool isAngleSafe(float horizontal, float vertical) const
    {
        std::lock_guard<std::mutex> lock(controllerMutex);

        for (const auto& constraint : crowdConstraints)
        {
            if (horizontal >= constraint.minHorizontal &&
                horizontal <= constraint.maxHorizontal &&
                vertical >= constraint.minVertical &&
                vertical <= constraint.maxVertical)
            {
                return false;
            }
        }

        return true;
    }

    float getMaxPowerForAngle(float horizontal, float vertical) const
    {
        std::lock_guard<std::mutex> lock(controllerMutex);

        float maxPower = 1.0f;
        for (const auto& constraint : crowdConstraints)
        {
            if (horizontal >= constraint.minHorizontal &&
                horizontal <= constraint.maxHorizontal &&
                vertical >= constraint.minVertical &&
                vertical <= constraint.maxVertical)
            {
                maxPower = std::min(maxPower, constraint.maxPower);
            }
        }

        return maxPower;
    }

    void setSafetyMargin(float margin) { safetyMargin = margin; }

private:
    mutable std::mutex controllerMutex;
    std::vector<BeamConstraint> crowdConstraints;
    float safetyMargin = 5.0f;  // Degrees
};

//==============================================================================
/**
    Main Laser Scan Engine
*/
class LaserScanEngine
{
public:
    //--------------------------------------------------------------------------
    static LaserScanEngine& getInstance()
    {
        static LaserScanEngine instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    void initialize()
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        if (initialized)
            return;

        // Start processing thread
        processingRunning = true;
        processingThread = std::thread(&LaserScanEngine::processingLoop, this);

        initialized = true;
    }

    void shutdown()
    {
        {
            std::lock_guard<std::mutex> lock(engineMutex);
            processingRunning = false;
        }
        processingCondition.notify_all();

        if (processingThread.joinable())
            processingThread.join();

        disconnectLiDAR();
        initialized = false;
    }

    //--------------------------------------------------------------------------
    // LiDAR Connection
    bool connectLiDAR(const LiDARConfig& config)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        lidarConfig = config;

        // Create UDP socket for LiDAR data
        lidarSocket = std::make_unique<juce::DatagramSocket>();

        if (!lidarSocket->bindToPort(config.dataPort))
        {
            lidarSocket.reset();
            return false;
        }

        lidarConnected = true;

        // Start LiDAR receive thread
        lidarReceiveRunning = true;
        lidarReceiveThread = std::thread(&LaserScanEngine::lidarReceiveLoop, this);

        return true;
    }

    void disconnectLiDAR()
    {
        lidarReceiveRunning = false;

        if (lidarReceiveThread.joinable())
            lidarReceiveThread.join();

        std::lock_guard<std::mutex> lock(engineMutex);
        lidarSocket.reset();
        lidarConnected = false;
    }

    bool isLiDARConnected() const { return lidarConnected.load(); }

    //--------------------------------------------------------------------------
    // Environment Scanning
    void startEnvironmentScan()
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        environmentCloud.clear();
        scanningEnvironment = true;
    }

    void stopEnvironmentScan()
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        scanningEnvironment = false;
        processEnvironmentScan();
    }

    bool isScanningEnvironment() const { return scanningEnvironment.load(); }

    const EnvironmentMap& getEnvironmentMap() const { return environmentMap; }

    //--------------------------------------------------------------------------
    // Crowd Detection
    void enableCrowdDetection(bool enable)
    {
        crowdDetectionEnabled.store(enable);
    }

    bool isCrowdDetectionEnabled() const { return crowdDetectionEnabled.load(); }

    std::vector<CrowdZone> getCrowdZones() const
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        return environmentMap.crowdZones;
    }

    float getCrowdEnergy() const
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        if (environmentMap.crowdZones.empty())
            return 0.0f;

        float totalEnergy = 0.0f;
        for (const auto& zone : environmentMap.crowdZones)
            totalEnergy += zone.energy;

        return totalEnergy / environmentMap.crowdZones.size();
    }

    //--------------------------------------------------------------------------
    // Scan Patterns
    void setScanPattern(const ScanPattern& pattern)
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        currentPattern = pattern;
    }

    const ScanPattern& getScanPattern() const { return currentPattern; }

    //--------------------------------------------------------------------------
    // Laser Output Integration
    void setLaserForce(LaserForce* laser)
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        laserForce = laser;
    }

    void updateLaserSafetyFromScan()
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        if (!laserForce)
            return;

        // Update adaptive beam controller
        beamController.updateFromEnvironment(environmentMap);

        // Apply crowd zones as safety zones to LaserForce
        for (size_t i = 0; i < environmentMap.crowdZones.size(); ++i)
        {
            const auto& zone = environmentMap.crowdZones[i];

            if (zone.isSafeZone || zone.density > 0.5f)
            {
                // Convert to LaserForce coordinate space (-1 to 1)
                float normX = zone.centerX / (environmentMap.roomWidth * 0.5f);
                float normY = zone.centerY / (environmentMap.roomDepth * 0.5f);
                float normW = zone.width / environmentMap.roomWidth;
                float normD = zone.depth / environmentMap.roomDepth;

                juce::Rectangle<float> safeRect(
                    normX - normW * 0.5f,
                    normY - normD * 0.5f,
                    normW,
                    normD
                );

                // Add to LaserForce outputs
                for (int j = 0; j < laserForce->getNumOutputs(); ++j)
                {
                    auto& output = laserForce->getOutput(j);
                    output.safeZones.push_back(safeRect);
                }
            }
        }
    }

    //--------------------------------------------------------------------------
    // Real-time Scan Data
    struct ScanFrame
    {
        uint64_t timestamp;
        std::vector<ScanPoint> points;
        float scanAngle;
    };

    ScanFrame getCurrentScanFrame() const
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        return currentFrame;
    }

    //--------------------------------------------------------------------------
    // Bio-Reactive Integration
    void updateBioState(float coherence, float hrv)
    {
        currentCoherence.store(coherence);
        currentHRV.store(hrv);

        // Adjust scan behavior based on bio state
        if (coherence > 0.7f)
        {
            // High coherence: smoother, more fluid scans
            scanSmoothing.store(0.8f);
        }
        else if (coherence < 0.3f)
        {
            // Low coherence: more dynamic, responsive scans
            scanSmoothing.store(0.3f);
        }
        else
        {
            scanSmoothing.store(0.5f);
        }
    }

    //--------------------------------------------------------------------------
    // Projection Mapping Support
    struct ProjectionSurface
    {
        juce::String id;
        std::vector<ScanPoint> corners;
        float width;
        float height;
        juce::AffineTransform warpMatrix;
    };

    void addProjectionSurface(const ProjectionSurface& surface)
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        projectionSurfaces.push_back(surface);
    }

    void clearProjectionSurfaces()
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        projectionSurfaces.clear();
    }

    std::vector<ProjectionSurface> getProjectionSurfaces() const
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        return projectionSurfaces;
    }

    // Auto-detect projectable surfaces from environment scan
    void detectProjectionSurfaces()
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        projectionSurfaces.clear();

        for (const auto& surface : environmentMap.surfaces)
        {
            if (surface.isProjectable && surface.area > 4.0f)  // Min 4 sq meters
            {
                ProjectionSurface projSurface;
                projSurface.id = surface.id;

                // Extract corner points
                if (surface.boundary.size() >= 4)
                {
                    // Find extreme points for rectangular approximation
                    float minX = std::numeric_limits<float>::max();
                    float maxX = std::numeric_limits<float>::lowest();
                    float minY = std::numeric_limits<float>::max();
                    float maxY = std::numeric_limits<float>::lowest();

                    for (const auto& pt : surface.boundary)
                    {
                        minX = std::min(minX, pt.x);
                        maxX = std::max(maxX, pt.x);
                        minY = std::min(minY, pt.y);
                        maxY = std::max(maxY, pt.y);
                    }

                    projSurface.corners = {
                        { minX, minY, surface.boundary[0].z, 1.0f, 0, 0, 0 },
                        { maxX, minY, surface.boundary[0].z, 1.0f, 0, 0, 0 },
                        { maxX, maxY, surface.boundary[0].z, 1.0f, 0, 0, 0 },
                        { minX, maxY, surface.boundary[0].z, 1.0f, 0, 0, 0 }
                    };

                    projSurface.width = maxX - minX;
                    projSurface.height = maxY - minY;

                    projectionSurfaces.push_back(projSurface);
                }
            }
        }
    }

    //--------------------------------------------------------------------------
    // Statistics
    struct ScanStats
    {
        int pointsPerSecond = 0;
        int framesPerSecond = 0;
        float latencyMs = 0.0f;
        int crowdCount = 0;
        float coveragePercent = 0.0f;
    };

    ScanStats getStats() const
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        return stats;
    }

    //--------------------------------------------------------------------------
    // Callbacks
    void setOnScanComplete(std::function<void(const ScanFrame&)> callback)
    {
        onScanComplete = callback;
    }

    void setOnCrowdUpdate(std::function<void(const std::vector<CrowdZone>&)> callback)
    {
        onCrowdUpdate = callback;
    }

    void setOnEnvironmentMapped(std::function<void(const EnvironmentMap&)> callback)
    {
        onEnvironmentMapped = callback;
    }

private:
    LaserScanEngine() = default;
    ~LaserScanEngine() { shutdown(); }

    LaserScanEngine(const LaserScanEngine&) = delete;
    LaserScanEngine& operator=(const LaserScanEngine&) = delete;

    //--------------------------------------------------------------------------
    void processingLoop()
    {
        while (processingRunning)
        {
            {
                std::unique_lock<std::mutex> lock(engineMutex);
                processingCondition.wait_for(lock, std::chrono::milliseconds(10));
            }

            if (!processingRunning)
                break;

            // Process incoming LiDAR data
            processLiDARData();

            // Update crowd detection
            if (crowdDetectionEnabled.load())
                updateCrowdDetection();

            // Generate scan pattern
            generateScanPattern();

            // Update stats
            updateStats();
        }
    }

    void lidarReceiveLoop()
    {
        std::vector<uint8_t> buffer(65536);

        while (lidarReceiveRunning)
        {
            if (!lidarSocket)
            {
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
                continue;
            }

            juce::String senderIP;
            int senderPort = 0;

            int bytesRead = lidarSocket->read(buffer.data(), static_cast<int>(buffer.size()),
                                              false, senderIP, senderPort);

            if (bytesRead > 0)
            {
                // Parse LiDAR packet based on device type
                parseLiDARPacket(buffer.data(), bytesRead);
            }
        }
    }

    void parseLiDARPacket(const uint8_t* data, int size)
    {
        std::lock_guard<std::mutex> lock(lidarDataMutex);

        // Velodyne VLP-16 packet structure
        if (lidarConfig.deviceType == LiDARConfig::DeviceType::Velodyne_VLP16 && size >= 1206)
        {
            for (int block = 0; block < 12; ++block)
            {
                int blockOffset = block * 100;

                // Parse flag and azimuth
                uint16_t flag = data[blockOffset] | (data[blockOffset + 1] << 8);
                if (flag != 0xEEFF)
                    continue;

                uint16_t azimuth = data[blockOffset + 2] | (data[blockOffset + 3] << 8);
                float azimuthRad = azimuth * 0.01f * 3.14159f / 180.0f;

                // Parse 32 channels (16 channels x 2 returns)
                for (int channel = 0; channel < 32; ++channel)
                {
                    int channelOffset = blockOffset + 4 + channel * 3;

                    uint16_t distance = data[channelOffset] | (data[channelOffset + 1] << 8);
                    uint8_t reflectivity = data[channelOffset + 2];

                    if (distance == 0)
                        continue;

                    float distanceM = distance * 0.002f;  // 2mm resolution

                    // Calculate elevation angle for channel
                    int channelIndex = channel % 16;
                    float elevationDeg = -15.0f + channelIndex * 2.0f;  // VLP-16 channels
                    float elevationRad = elevationDeg * 3.14159f / 180.0f;

                    // Convert to Cartesian
                    ScanPoint point;
                    point.x = distanceM * std::cos(elevationRad) * std::sin(azimuthRad);
                    point.y = distanceM * std::cos(elevationRad) * std::cos(azimuthRad);
                    point.z = distanceM * std::sin(elevationRad);
                    point.intensity = reflectivity / 255.0f;
                    point.reflectivity = reflectivity / 255.0f;
                    point.timestamp = static_cast<uint32_t>(juce::Time::getMillisecondCounter());

                    incomingPoints.push_back(point);
                }
            }
        }
    }

    void processLiDARData()
    {
        std::vector<ScanPoint> points;

        {
            std::lock_guard<std::mutex> lock(lidarDataMutex);
            points = std::move(incomingPoints);
            incomingPoints.clear();
        }

        if (points.empty())
            return;

        // Apply calibration transforms
        for (auto& point : points)
        {
            // Apply offset
            point.x += lidarConfig.xOffset;
            point.y += lidarConfig.yOffset;
            point.z += lidarConfig.zOffset;

            // Apply rotation (simplified - full implementation would use rotation matrices)
            float cosYaw = std::cos(lidarConfig.yaw);
            float sinYaw = std::sin(lidarConfig.yaw);
            float newX = point.x * cosYaw - point.y * sinYaw;
            float newY = point.x * sinYaw + point.y * cosYaw;
            point.x = newX;
            point.y = newY;
        }

        // Update current frame
        {
            std::lock_guard<std::mutex> lock(engineMutex);
            currentFrame.timestamp = juce::Time::getMillisecondCounter();
            currentFrame.points = points;

            // Add to environment cloud if scanning
            if (scanningEnvironment.load())
                environmentCloud.addPoints(points);
        }

        // Notify callback
        if (onScanComplete)
            onScanComplete(currentFrame);
    }

    void processEnvironmentScan()
    {
        // Analyze point cloud to build environment map
        auto points = environmentCloud.getPoints();

        if (points.empty())
            return;

        // Ground plane detection (RANSAC)
        detectGroundPlane(points);

        // Wall detection
        detectWalls(points);

        // Stage detection
        detectStage(points);

        // Calculate room dimensions
        auto minBounds = environmentCloud.getMinBounds();
        auto maxBounds = environmentCloud.getMaxBounds();

        environmentMap.roomWidth = maxBounds.x - minBounds.x;
        environmentMap.roomDepth = maxBounds.y - minBounds.y;
        environmentMap.roomHeight = maxBounds.z - minBounds.z;

        // Detect projectable surfaces
        detectProjectionSurfaces();

        // Notify callback
        if (onEnvironmentMapped)
            onEnvironmentMapped(environmentMap);
    }

    void detectGroundPlane(const std::vector<ScanPoint>& points)
    {
        // Simple ground detection - find lowest z cluster
        std::vector<ScanPoint> lowPoints;
        float groundThreshold = 0.3f;  // 30cm

        for (const auto& point : points)
        {
            if (point.z < groundThreshold)
                lowPoints.push_back(point);
        }

        if (!lowPoints.empty())
        {
            EnvironmentMap::Surface floor;
            floor.id = "floor";
            floor.type = "floor";
            floor.boundary = lowPoints;
            floor.isProjectable = true;

            // Calculate area (convex hull approximation)
            float minX = std::numeric_limits<float>::max();
            float maxX = std::numeric_limits<float>::lowest();
            float minY = std::numeric_limits<float>::max();
            float maxY = std::numeric_limits<float>::lowest();

            for (const auto& pt : lowPoints)
            {
                minX = std::min(minX, pt.x);
                maxX = std::max(maxX, pt.x);
                minY = std::min(minY, pt.y);
                maxY = std::max(maxY, pt.y);
            }

            floor.area = (maxX - minX) * (maxY - minY);

            environmentMap.surfaces.push_back(floor);
        }
    }

    void detectWalls(const std::vector<ScanPoint>& points)
    {
        // Simplified wall detection - vertical surfaces at room edges
        auto minBounds = environmentCloud.getMinBounds();
        auto maxBounds = environmentCloud.getMaxBounds();

        float wallThreshold = 0.5f;

        // Check for walls at X min/max
        for (int wallIndex = 0; wallIndex < 4; ++wallIndex)
        {
            std::vector<ScanPoint> wallPoints;
            juce::String wallId;

            for (const auto& point : points)
            {
                bool isWallPoint = false;

                switch (wallIndex)
                {
                    case 0:  // Left wall
                        isWallPoint = (point.x < minBounds.x + wallThreshold);
                        wallId = "wall_left";
                        break;
                    case 1:  // Right wall
                        isWallPoint = (point.x > maxBounds.x - wallThreshold);
                        wallId = "wall_right";
                        break;
                    case 2:  // Back wall
                        isWallPoint = (point.y < minBounds.y + wallThreshold);
                        wallId = "wall_back";
                        break;
                    case 3:  // Front wall
                        isWallPoint = (point.y > maxBounds.y - wallThreshold);
                        wallId = "wall_front";
                        break;
                }

                if (isWallPoint)
                    wallPoints.push_back(point);
            }

            if (wallPoints.size() > 100)  // Minimum points for wall
            {
                EnvironmentMap::Surface wall;
                wall.id = wallId;
                wall.type = "wall";
                wall.boundary = wallPoints;
                wall.isProjectable = true;

                environmentMap.surfaces.push_back(wall);
            }
        }
    }

    void detectStage(const std::vector<ScanPoint>& points)
    {
        // Look for elevated platform (typical stage height 0.5-1.5m)
        std::vector<ScanPoint> stagePoints;
        float stageMinHeight = 0.4f;
        float stageMaxHeight = 2.0f;

        for (const auto& point : points)
        {
            if (point.z > stageMinHeight && point.z < stageMaxHeight)
            {
                // Check if it's a flat surface (similar z values in neighborhood)
                stagePoints.push_back(point);
            }
        }

        if (stagePoints.size() > 50)
        {
            // Calculate stage bounds
            float minX = std::numeric_limits<float>::max();
            float maxX = std::numeric_limits<float>::lowest();
            float minY = std::numeric_limits<float>::max();
            float maxY = std::numeric_limits<float>::lowest();
            float avgZ = 0.0f;

            for (const auto& pt : stagePoints)
            {
                minX = std::min(minX, pt.x);
                maxX = std::max(maxX, pt.x);
                minY = std::min(minY, pt.y);
                maxY = std::max(maxY, pt.y);
                avgZ += pt.z;
            }
            avgZ /= stagePoints.size();

            float stageWidth = maxX - minX;
            float stageDepth = maxY - minY;

            if (stageWidth > 2.0f && stageDepth > 1.5f)  // Minimum stage size
            {
                environmentMap.stageDetected = true;
                environmentMap.stageX = (minX + maxX) * 0.5f;
                environmentMap.stageY = (minY + maxY) * 0.5f;
                environmentMap.stageWidth = stageWidth;
                environmentMap.stageDepth = stageDepth;
                environmentMap.stageHeight = avgZ;
            }
        }
    }

    void updateCrowdDetection()
    {
        if (!lidarConnected.load())
            return;

        std::lock_guard<std::mutex> lock(engineMutex);

        // Clear previous zones
        environmentMap.crowdZones.clear();

        // Analyze current frame for people (height-based clustering)
        float personMinHeight = 1.4f;
        float personMaxHeight = 2.2f;

        std::vector<ScanPoint> personPoints;
        for (const auto& point : currentFrame.points)
        {
            if (point.z > personMinHeight && point.z < personMaxHeight)
            {
                ScanPoint classified = point;
                classified.classification = 2;  // Crowd
                personPoints.push_back(classified);
            }
        }

        // Cluster person points into zones (simple grid-based)
        float zoneSize = 3.0f;  // 3x3 meter zones

        std::map<std::pair<int, int>, std::vector<ScanPoint>> zoneClusters;

        for (const auto& point : personPoints)
        {
            int zoneX = static_cast<int>(point.x / zoneSize);
            int zoneY = static_cast<int>(point.y / zoneSize);
            zoneClusters[{zoneX, zoneY}].push_back(point);
        }

        int zoneIndex = 0;
        for (const auto& cluster : zoneClusters)
        {
            if (cluster.second.size() < 5)  // Minimum points for zone
                continue;

            CrowdZone zone;
            zone.id = "zone_" + juce::String(zoneIndex++);
            zone.centerX = cluster.first.first * zoneSize + zoneSize * 0.5f;
            zone.centerY = cluster.first.second * zoneSize + zoneSize * 0.5f;
            zone.width = zoneSize;
            zone.depth = zoneSize;

            // Estimate density (very rough - assumes avg person takes ~0.5 sq m)
            zone.estimatedCount = static_cast<int>(cluster.second.size() / 20);
            zone.density = zone.estimatedCount / (zoneSize * zoneSize);

            // Calculate movement (compare with previous frame - simplified)
            zone.movement = 0.3f;  // Default moderate movement

            // Energy based on density and movement
            zone.energy = (zone.density * 0.5f + zone.movement * 0.5f);
            zone.energy = std::min(1.0f, zone.energy);

            // Mark high-density zones as safe zones (no laser)
            zone.isSafeZone = (zone.density > 1.0f);

            environmentMap.crowdZones.push_back(zone);
        }

        // Update stats
        int totalCount = 0;
        for (const auto& zone : environmentMap.crowdZones)
            totalCount += zone.estimatedCount;
        stats.crowdCount = totalCount;

        // Notify callback
        if (onCrowdUpdate)
            onCrowdUpdate(environmentMap.crowdZones);
    }

    void generateScanPattern()
    {
        // Generate scan points based on current pattern
        std::vector<std::pair<float, float>> scanPoints;

        float smoothing = scanSmoothing.load();

        switch (currentPattern.type)
        {
            case ScanPattern::Type::Linear:
            {
                float hRange = currentPattern.horizontalEnd - currentPattern.horizontalStart;
                for (int i = 0; i < currentPattern.pointsPerLine; ++i)
                {
                    float t = static_cast<float>(i) / (currentPattern.pointsPerLine - 1);
                    float h = currentPattern.horizontalStart + t * hRange;
                    float v = currentPattern.verticalStart;
                    scanPoints.push_back({h, v});
                }
                break;
            }

            case ScanPattern::Type::Spiral:
            {
                float maxAngle = 4.0f * 3.14159f;  // 2 full rotations
                float maxRadius = (currentPattern.horizontalEnd - currentPattern.horizontalStart) * 0.5f;

                for (int i = 0; i < currentPattern.pointsPerLine * currentPattern.linesPerFrame; ++i)
                {
                    float t = static_cast<float>(i) / (currentPattern.pointsPerLine * currentPattern.linesPerFrame - 1);
                    float angle = t * maxAngle;
                    float radius = t * maxRadius;
                    float h = radius * std::cos(angle);
                    float v = radius * std::sin(angle);
                    scanPoints.push_back({h, v});
                }
                break;
            }

            case ScanPattern::Type::Lissajous:
            {
                for (int i = 0; i < currentPattern.pointsPerLine * currentPattern.linesPerFrame; ++i)
                {
                    float t = static_cast<float>(i) / (currentPattern.pointsPerLine * currentPattern.linesPerFrame - 1);
                    float angle = t * 2.0f * 3.14159f;
                    float h = (currentPattern.horizontalEnd - currentPattern.horizontalStart) * 0.5f *
                              std::sin(currentPattern.lissajousA * angle + currentPattern.lissajousPhase);
                    float v = (currentPattern.verticalEnd - currentPattern.verticalStart) * 0.5f *
                              std::sin(currentPattern.lissajousB * angle);
                    scanPoints.push_back({h, v});
                }
                break;
            }

            case ScanPattern::Type::Grid:
            {
                float hRange = currentPattern.horizontalEnd - currentPattern.horizontalStart;
                float vRange = currentPattern.verticalEnd - currentPattern.verticalStart;

                for (int y = 0; y < currentPattern.linesPerFrame; ++y)
                {
                    float v = currentPattern.verticalStart +
                              vRange * static_cast<float>(y) / (currentPattern.linesPerFrame - 1);

                    for (int x = 0; x < currentPattern.pointsPerLine; ++x)
                    {
                        float t = static_cast<float>(x) / (currentPattern.pointsPerLine - 1);
                        // Serpentine pattern
                        float h = (y % 2 == 0) ?
                                  currentPattern.horizontalStart + t * hRange :
                                  currentPattern.horizontalEnd - t * hRange;
                        scanPoints.push_back({h, v});
                    }
                }
                break;
            }

            case ScanPattern::Type::Custom:
                scanPoints = currentPattern.customPattern;
                break;

            default:
                break;
        }

        // Apply bio-reactive smoothing
        if (smoothing > 0.0f && !lastScanPoints.empty() && scanPoints.size() == lastScanPoints.size())
        {
            for (size_t i = 0; i < scanPoints.size(); ++i)
            {
                scanPoints[i].first = lastScanPoints[i].first * smoothing +
                                      scanPoints[i].first * (1.0f - smoothing);
                scanPoints[i].second = lastScanPoints[i].second * smoothing +
                                       scanPoints[i].second * (1.0f - smoothing);
            }
        }

        lastScanPoints = scanPoints;

        // Store scan angle
        currentFrame.scanAngle = currentPattern.horizontalStart;
    }

    void updateStats()
    {
        static auto lastStatsTime = std::chrono::steady_clock::now();
        static int frameCount = 0;
        static int pointCount = 0;

        frameCount++;
        pointCount += static_cast<int>(currentFrame.points.size());

        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastStatsTime).count();

        if (elapsed >= 1000)
        {
            std::lock_guard<std::mutex> lock(engineMutex);
            stats.framesPerSecond = frameCount;
            stats.pointsPerSecond = pointCount;
            stats.latencyMs = static_cast<float>(elapsed) / frameCount;

            // Calculate coverage
            if (environmentMap.roomWidth > 0 && environmentMap.roomDepth > 0)
            {
                float scannedArea = stats.pointsPerSecond * 0.01f;  // Rough estimate
                float totalArea = environmentMap.roomWidth * environmentMap.roomDepth;
                stats.coveragePercent = std::min(100.0f, scannedArea / totalArea * 100.0f);
            }

            frameCount = 0;
            pointCount = 0;
            lastStatsTime = now;
        }
    }

    //--------------------------------------------------------------------------
    mutable std::mutex engineMutex;
    std::mutex lidarDataMutex;
    std::condition_variable processingCondition;

    bool initialized = false;
    std::atomic<bool> processingRunning{false};
    std::thread processingThread;

    // LiDAR
    LiDARConfig lidarConfig;
    std::unique_ptr<juce::DatagramSocket> lidarSocket;
    std::atomic<bool> lidarConnected{false};
    std::atomic<bool> lidarReceiveRunning{false};
    std::thread lidarReceiveThread;
    std::vector<ScanPoint> incomingPoints;

    // Environment
    PointCloud environmentCloud;
    EnvironmentMap environmentMap;
    std::atomic<bool> scanningEnvironment{false};

    // Crowd detection
    std::atomic<bool> crowdDetectionEnabled{false};

    // Scan pattern
    ScanPattern currentPattern;
    std::vector<std::pair<float, float>> lastScanPoints;

    // Current frame
    ScanFrame currentFrame;

    // Laser output
    LaserForce* laserForce = nullptr;
    AdaptiveBeamController beamController;

    // Projection mapping
    std::vector<ProjectionSurface> projectionSurfaces;

    // Bio-reactive
    std::atomic<float> currentCoherence{0.5f};
    std::atomic<float> currentHRV{50.0f};
    std::atomic<float> scanSmoothing{0.5f};

    // Stats
    ScanStats stats;

    // Callbacks
    std::function<void(const ScanFrame&)> onScanComplete;
    std::function<void(const std::vector<CrowdZone>&)> onCrowdUpdate;
    std::function<void(const EnvironmentMap&)> onEnvironmentMapped;
};

} // namespace Visual
} // namespace Echoel
