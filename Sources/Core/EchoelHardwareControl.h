/**
 * EchoelHardwareControl.h
 *
 * Universal Hardware Control & Vehicle Interface System
 *
 * "Blablub" Hardware Concept - Control everything!
 * - Submarines (Tauchfliegen)
 * - Aircraft & Drones
 * - Ships & Boats
 * - Ground Vehicles
 * - Smart Home Devices
 * - Studio Equipment
 * - Stage Lighting
 * - Robotics & Animatronics
 * - Space Vehicles (why not?)
 *
 * Control modes:
 * - Direct control via MIDI/OSC
 * - Gesture control
 * - Voice commands
 * - Brain-Computer Interface (BCI)
 * - Timeline-synced automation
 * - AI-assisted navigation
 *
 * Part of Ralph Wiggum Genius Loop Mode - Phase 1
 * "I'm a unitard!" - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <functional>
#include <chrono>
#include <optional>
#include <atomic>
#include <mutex>
#include <cmath>

namespace Echoel {

// ============================================================================
// Device Types
// ============================================================================

enum class DeviceCategory {
    // Vehicles
    Submarine,          // Tauchfliegen! 🐠
    Aircraft,           // Planes, helicopters
    Drone,              // Quadcopters, FPV
    Ship,               // Boats, yachts
    GroundVehicle,      // Cars, tanks, rovers
    SpaceVehicle,       // Rockets, spacecraft

    // Studio
    Lighting,           // Stage/studio lights
    Camera,             // PTZ cameras
    Projector,          // Video projectors
    Fog,                // Fog/haze machines
    Pyro,               // Pyrotechnics (careful!)
    Laser,              // Laser systems
    LED,                // LED panels/strips

    // Robotics
    Robot,              // General robots
    Animatronic,        // Animated figures
    Servo,              // Individual servos
    Motor,              // Motors
    Actuator,           // Linear actuators

    // Home
    SmartLight,         // Smart bulbs
    SmartPlug,          // Smart outlets
    HVAC,               // Climate control
    Blinds,             // Window blinds
    Speaker,            // Smart speakers

    // Musical
    Motorized,          // Motorized faders/knobs
    Display,            // LED displays
    Haptic,             // Haptic feedback devices

    Custom
};

enum class ConnectionProtocol {
    MIDI,               // Musical instruments
    OSC,                // Open Sound Control
    DMX,                // Lighting (DMX512)
    ArtNet,             // DMX over network
    sACN,               // Streaming ACN
    MQTT,               // IoT messaging
    HTTP,               // REST API
    WebSocket,          // Real-time web
    Serial,             // RS-232/RS-485
    USB,                // Direct USB
    Bluetooth,          // Bluetooth/BLE
    WiFi,               // Direct WiFi
    ZigBee,             // ZigBee mesh
    ZWave,              // Z-Wave home automation
    MAVLink,            // Drone protocol
    ROS,                // Robot Operating System
    CAN,                // CAN bus (vehicles)
    Custom
};

// ============================================================================
// 3D Position & Orientation
// ============================================================================

struct Vector3D {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    Vector3D operator+(const Vector3D& other) const {
        return {x + other.x, y + other.y, z + other.z};
    }

    Vector3D operator*(float scalar) const {
        return {x * scalar, y * scalar, z * scalar};
    }

    float magnitude() const {
        return std::sqrt(x*x + y*y + z*z);
    }

    Vector3D normalized() const {
        float mag = magnitude();
        if (mag == 0) return {0, 0, 0};
        return {x/mag, y/mag, z/mag};
    }
};

struct Orientation3D {
    float pitch = 0.0f;  // Nose up/down
    float roll = 0.0f;   // Bank left/right
    float yaw = 0.0f;    // Heading
};

struct Transform3D {
    Vector3D position;
    Orientation3D orientation;
    Vector3D scale{1.0f, 1.0f, 1.0f};
};

// ============================================================================
// Control Axes
// ============================================================================

struct ControlAxis {
    std::string id;
    std::string name;

    float minValue = -1.0f;
    float maxValue = 1.0f;
    float defaultValue = 0.0f;
    float currentValue = 0.0f;

    float deadzone = 0.05f;
    float sensitivity = 1.0f;
    bool inverted = false;

    // Smoothing
    float smoothing = 0.1f;  // 0 = instant, 1 = very smooth
    float targetValue = 0.0f;

    // Limits
    float rateLimit = 0.0f;  // Max change per second (0 = unlimited)
    bool hasEndstops = false;

    void setValue(float value) {
        // Apply deadzone
        if (std::abs(value) < deadzone) {
            value = 0.0f;
        }

        // Apply inversion
        if (inverted) value = -value;

        // Apply sensitivity
        value *= sensitivity;

        // Clamp
        value = std::clamp(value, minValue, maxValue);

        targetValue = value;
    }

    void update(float deltaTime) {
        if (smoothing > 0) {
            float alpha = 1.0f - smoothing;
            currentValue = currentValue * smoothing + targetValue * alpha;
        } else {
            currentValue = targetValue;
        }

        // Apply rate limit
        if (rateLimit > 0) {
            float maxDelta = rateLimit * deltaTime;
            float delta = targetValue - currentValue;
            if (std::abs(delta) > maxDelta) {
                currentValue += (delta > 0 ? maxDelta : -maxDelta);
            }
        }
    }
};

// ============================================================================
// Device Definition
// ============================================================================

struct DeviceCapability {
    std::string id;
    std::string name;

    enum class Type {
        Axis,           // Continuous control
        Button,         // On/off
        Toggle,         // Latching on/off
        Trigger,        // Momentary
        Display,        // Output only
        Sensor,         // Input only
        Custom
    } type = Type::Axis;

    std::optional<ControlAxis> axis;

    // For buttons/toggles
    bool state = false;

    // For displays
    std::string displayValue;

    // For sensors
    float sensorValue = 0.0f;
    std::string sensorUnit;
};

struct HardwareDevice {
    std::string id;
    std::string name;
    std::string manufacturer;
    std::string model;
    std::string serialNumber;

    DeviceCategory category = DeviceCategory::Custom;
    ConnectionProtocol protocol = ConnectionProtocol::MIDI;

    // Connection
    std::string address;  // IP, COM port, etc.
    int port = 0;
    bool isConnected = false;
    bool isEnabled = true;

    // Capabilities
    std::map<std::string, DeviceCapability> capabilities;

    // Position tracking
    Transform3D transform;
    Vector3D velocity;
    Vector3D acceleration;

    // Status
    float batteryLevel = 1.0f;  // 0-1
    float signalStrength = 1.0f;
    std::string statusMessage;

    // Metadata
    std::string iconName;
    std::string color;
    std::map<std::string, std::string> customProperties;
};

// ============================================================================
// Vehicle Control Profiles
// ============================================================================

struct SubmarineControls {
    // Diving
    ControlAxis depth;          // Ballast tanks
    ControlAxis pitch;          // Dive planes
    float maxDepth = 100.0f;    // meters

    // Movement
    ControlAxis throttle;       // Propulsion
    ControlAxis rudder;         // Yaw control
    ControlAxis lateralThrust;  // Side thrusters

    // Systems
    bool lightsOn = false;
    bool sonarActive = false;
    bool silentRunning = false;
    float oxygenLevel = 1.0f;
    float hullIntegrity = 1.0f;

    // Emergency
    bool emergencyBlow = false;  // Emergency surface!
};

struct AircraftControls {
    // Primary flight controls
    ControlAxis throttle;
    ControlAxis pitch;          // Elevator
    ControlAxis roll;           // Ailerons
    ControlAxis yaw;            // Rudder

    // Secondary
    ControlAxis flaps;
    ControlAxis trim;
    bool landingGear = true;
    bool autopilot = false;

    // Navigation
    float altitude = 0.0f;      // meters
    float airspeed = 0.0f;      // m/s
    float heading = 0.0f;       // degrees
    float verticalSpeed = 0.0f; // m/s

    // Systems
    bool lightsNav = true;
    bool lightsStrobe = true;
    bool lightsLanding = false;
    float fuelLevel = 1.0f;
};

struct DroneControls {
    // Flight
    ControlAxis throttle;       // Altitude
    ControlAxis pitch;          // Forward/back
    ControlAxis roll;           // Left/right
    ControlAxis yaw;            // Rotation

    // Camera
    ControlAxis gimbalPitch;
    ControlAxis gimbalYaw;
    bool cameraRecording = false;
    int cameraMode = 0;         // Photo/video modes

    // Features
    bool followMe = false;
    bool returnToHome = false;
    bool orbitMode = false;
    float orbitRadius = 10.0f;

    // Status
    float batteryLevel = 1.0f;
    float altitude = 0.0f;
    float distanceFromHome = 0.0f;
    int satellites = 0;
};

struct ShipControls {
    // Propulsion
    ControlAxis throttle;
    ControlAxis rudder;
    ControlAxis bowThruster;    // Side thruster front
    ControlAxis sternThruster;  // Side thruster rear

    // Navigation
    float heading = 0.0f;
    float speed = 0.0f;         // knots
    Vector3D gpsPosition;

    // Systems
    bool anchor = false;
    bool horn = false;
    int lightsMode = 0;         // Navigation lights pattern
    float fuelLevel = 1.0f;

    // Fun additions
    bool partyMode = false;     // Deck lights & music sync!
};

struct GroundVehicleControls {
    // Movement
    ControlAxis throttle;
    ControlAxis steering;
    ControlAxis brake;

    // Features
    bool headlights = false;
    bool hazardLights = false;
    bool horn = false;
    int gear = 0;               // -1=R, 0=N, 1-6=forward

    // Status
    float speed = 0.0f;
    float rpm = 0.0f;
    float fuelLevel = 1.0f;
};

// ============================================================================
// Lighting Control
// ============================================================================

struct LightingFixture {
    std::string id;
    std::string name;

    // DMX addressing
    int universe = 0;
    int startChannel = 1;
    int channelCount = 8;

    // Color
    float red = 1.0f;
    float green = 1.0f;
    float blue = 1.0f;
    float white = 0.0f;       // RGBW
    float amber = 0.0f;       // RGBWA
    float uv = 0.0f;          // UV channel

    // Intensity
    float dimmer = 1.0f;
    float strobe = 0.0f;      // 0 = off

    // Movement (for moving heads)
    float pan = 0.5f;         // 0-1
    float tilt = 0.5f;        // 0-1
    float zoom = 0.5f;
    float focus = 0.5f;

    // Gobo/prism
    int goboWheel = 0;
    float goboRotation = 0.0f;
    int prism = 0;

    // Effects
    bool colorMixing = true;   // CMY vs RGB
    int colorWheel = 0;
};

struct LightingScene {
    std::string id;
    std::string name;

    std::map<std::string, LightingFixture> fixtures;

    // Timing
    float fadeInTime = 0.0f;   // seconds
    float fadeOutTime = 0.0f;
    float holdTime = 0.0f;

    // Triggers
    bool triggerOnBeat = false;
    std::string triggerNote;   // MIDI note
};

// ============================================================================
// Hardware Controller Manager
// ============================================================================

class HardwareControlManager {
public:
    static HardwareControlManager& getInstance() {
        static HardwareControlManager instance;
        return instance;
    }

    // ========================================================================
    // Device Management
    // ========================================================================

    std::string registerDevice(const HardwareDevice& device) {
        std::lock_guard<std::mutex> lock(mutex_);

        HardwareDevice newDevice = device;
        newDevice.id = generateId("dev");

        devices_[newDevice.id] = newDevice;

        return newDevice.id;
    }

    void unregisterDevice(const std::string& deviceId) {
        std::lock_guard<std::mutex> lock(mutex_);
        disconnectDevice(deviceId);
        devices_.erase(deviceId);
    }

    bool connectDevice(const std::string& deviceId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it == devices_.end()) return false;

        // Would establish connection based on protocol
        it->second.isConnected = true;
        it->second.statusMessage = "Connected";

        return true;
    }

    void disconnectDevice(const std::string& deviceId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it != devices_.end()) {
            it->second.isConnected = false;
            it->second.statusMessage = "Disconnected";
        }
    }

    std::optional<HardwareDevice> getDevice(const std::string& deviceId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it != devices_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    std::vector<HardwareDevice> getDevices(
        std::optional<DeviceCategory> category = std::nullopt) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<HardwareDevice> result;
        for (const auto& [id, device] : devices_) {
            if (category && device.category != *category) continue;
            result.push_back(device);
        }

        return result;
    }

    std::vector<HardwareDevice> discoverDevices(ConnectionProtocol protocol) {
        // Would scan network/ports for devices
        std::vector<HardwareDevice> discovered;

        // Simulated discovery
        if (protocol == ConnectionProtocol::MIDI) {
            // Scan MIDI ports
        } else if (protocol == ConnectionProtocol::OSC) {
            // Scan network for OSC devices
        } else if (protocol == ConnectionProtocol::DMX) {
            // Scan for DMX interfaces
        }

        return discovered;
    }

    // ========================================================================
    // Control Interface
    // ========================================================================

    void setAxisValue(const std::string& deviceId, const std::string& axisId, float value) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it == devices_.end()) return;

        auto capIt = it->second.capabilities.find(axisId);
        if (capIt != it->second.capabilities.end() && capIt->second.axis) {
            capIt->second.axis->setValue(value);
        }
    }

    void setButtonState(const std::string& deviceId, const std::string& buttonId, bool pressed) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it == devices_.end()) return;

        auto capIt = it->second.capabilities.find(buttonId);
        if (capIt != it->second.capabilities.end()) {
            capIt->second.state = pressed;
        }
    }

    float getAxisValue(const std::string& deviceId, const std::string& axisId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it == devices_.end()) return 0.0f;

        auto capIt = it->second.capabilities.find(axisId);
        if (capIt != it->second.capabilities.end() && capIt->second.axis) {
            return capIt->second.axis->currentValue;
        }

        return 0.0f;
    }

    // ========================================================================
    // Vehicle Control
    // ========================================================================

    void controlSubmarine(const std::string& deviceId, const SubmarineControls& controls) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it == devices_.end() || it->second.category != DeviceCategory::Submarine) return;

        // Apply controls
        // Would send commands via appropriate protocol

        // Emergency handling
        if (controls.emergencyBlow) {
            // EMERGENCY SURFACE! 🚨
            // Override all controls, maximum buoyancy!
        }
    }

    void controlAircraft(const std::string& deviceId, const AircraftControls& controls) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it == devices_.end()) return;

        // Safety checks
        if (controls.altitude < 0) {
            // Terrain warning!
        }

        // Apply controls
    }

    void controlDrone(const std::string& deviceId, const DroneControls& controls) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it == devices_.end()) return;

        // Battery check
        if (controls.batteryLevel < 0.2f && !controls.returnToHome) {
            // Low battery - should return home!
        }

        // Apply controls - would send MAVLink commands
    }

    void controlShip(const std::string& deviceId, const ShipControls& controls) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = devices_.find(deviceId);
        if (it == devices_.end()) return;

        // Party mode! 🎉
        if (controls.partyMode) {
            // Sync deck lights to music
            // enableMusicSync(deviceId);
        }

        // Apply controls
    }

    // ========================================================================
    // Lighting Control
    // ========================================================================

    void setLightingScene(const std::string& sceneId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = lightingScenes_.find(sceneId);
        if (it == lightingScenes_.end()) return;

        currentScene_ = sceneId;

        // Apply scene with fade
        applyLightingScene(it->second);
    }

    void setFixtureColor(const std::string& fixtureId, float r, float g, float b) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = lightingFixtures_.find(fixtureId);
        if (it == lightingFixtures_.end()) return;

        it->second.red = r;
        it->second.green = g;
        it->second.blue = b;

        sendDMXValues(it->second);
    }

    void setFixtureDimmer(const std::string& fixtureId, float level) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = lightingFixtures_.find(fixtureId);
        if (it == lightingFixtures_.end()) return;

        it->second.dimmer = std::clamp(level, 0.0f, 1.0f);

        sendDMXValues(it->second);
    }

    void setFixturePosition(const std::string& fixtureId, float pan, float tilt) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = lightingFixtures_.find(fixtureId);
        if (it == lightingFixtures_.end()) return;

        it->second.pan = std::clamp(pan, 0.0f, 1.0f);
        it->second.tilt = std::clamp(tilt, 0.0f, 1.0f);

        sendDMXValues(it->second);
    }

    void blackout() {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [id, fixture] : lightingFixtures_) {
            fixture.dimmer = 0.0f;
            sendDMXValues(fixture);
        }
    }

    void restoreFromBlackout() {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [id, fixture] : lightingFixtures_) {
            fixture.dimmer = 1.0f;
            sendDMXValues(fixture);
        }
    }

    // ========================================================================
    // Music Sync
    // ========================================================================

    void enableMusicSync(const std::string& deviceId, bool enabled) {
        std::lock_guard<std::mutex> lock(mutex_);
        musicSyncDevices_[deviceId] = enabled;
    }

    void onBeat(float intensity) {
        // Trigger beat-synced actions
        std::lock_guard<std::mutex> lock(mutex_);

        for (const auto& [deviceId, enabled] : musicSyncDevices_) {
            if (!enabled) continue;

            // Flash lights, move fixtures, etc.
        }
    }

    void onFrequencyData(const std::vector<float>& spectrum) {
        // React to frequency spectrum
        // Could color-map frequencies to lighting
    }

    // ========================================================================
    // MIDI Control
    // ========================================================================

    void handleMIDICC(int channel, int cc, int value) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Map MIDI CC to device controls
        auto it = midiMappings_.find({channel, cc});
        if (it != midiMappings_.end()) {
            setAxisValue(it->second.deviceId, it->second.axisId,
                         value / 127.0f * 2.0f - 1.0f);  // Map 0-127 to -1 to +1
        }
    }

    void handleMIDINote(int channel, int note, int velocity, bool noteOn) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Trigger actions from MIDI notes
        if (noteOn) {
            // Could trigger lighting scenes, pyro, etc.
        }
    }

    void mapMIDIToAxis(int channel, int cc, const std::string& deviceId,
                        const std::string& axisId) {
        std::lock_guard<std::mutex> lock(mutex_);

        midiMappings_[{channel, cc}] = {deviceId, axisId};
    }

    // ========================================================================
    // OSC Control
    // ========================================================================

    void handleOSC(const std::string& address, const std::vector<float>& args) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Parse OSC address and route to devices
        // e.g., /echoel/submarine/1/depth -> submarine control

        auto it = oscMappings_.find(address);
        if (it != oscMappings_.end() && !args.empty()) {
            setAxisValue(it->second.deviceId, it->second.axisId, args[0]);
        }
    }

    void mapOSCToAxis(const std::string& address, const std::string& deviceId,
                       const std::string& axisId) {
        std::lock_guard<std::mutex> lock(mutex_);

        oscMappings_[address] = {deviceId, axisId};
    }

    // ========================================================================
    // Update Loop
    // ========================================================================

    void update(float deltaTime) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Update all control axes (smoothing)
        for (auto& [id, device] : devices_) {
            for (auto& [capId, cap] : device.capabilities) {
                if (cap.axis) {
                    cap.axis->update(deltaTime);
                }
            }
        }

        // Send control values to devices
        for (const auto& [id, device] : devices_) {
            if (!device.isConnected) continue;
            sendDeviceUpdate(device);
        }
    }

private:
    HardwareControlManager() = default;
    ~HardwareControlManager() = default;

    HardwareControlManager(const HardwareControlManager&) = delete;
    HardwareControlManager& operator=(const HardwareControlManager&) = delete;

    std::string generateId(const std::string& prefix) {
        return prefix + "_" + std::to_string(nextId_++);
    }

    void applyLightingScene(const LightingScene& scene) {
        for (const auto& [id, fixture] : scene.fixtures) {
            lightingFixtures_[id] = fixture;
            sendDMXValues(fixture);
        }
    }

    void sendDMXValues(const LightingFixture& fixture) {
        // Would send DMX values via ArtNet/sACN
    }

    void sendDeviceUpdate(const HardwareDevice& device) {
        // Would send control values to device via its protocol
    }

    mutable std::mutex mutex_;

    std::map<std::string, HardwareDevice> devices_;
    std::map<std::string, LightingFixture> lightingFixtures_;
    std::map<std::string, LightingScene> lightingScenes_;
    std::string currentScene_;

    std::map<std::string, bool> musicSyncDevices_;

    struct AxisMapping {
        std::string deviceId;
        std::string axisId;
    };

    std::map<std::pair<int, int>, AxisMapping> midiMappings_;  // {channel, cc} -> mapping
    std::map<std::string, AxisMapping> oscMappings_;           // address -> mapping

    std::atomic<int> nextId_{1};
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Hardware {

inline void connect(const std::string& deviceId) {
    HardwareControlManager::getInstance().connectDevice(deviceId);
}

inline void disconnect(const std::string& deviceId) {
    HardwareControlManager::getInstance().disconnectDevice(deviceId);
}

inline void setAxis(const std::string& deviceId, const std::string& axisId, float value) {
    HardwareControlManager::getInstance().setAxisValue(deviceId, axisId, value);
}

inline void lightScene(const std::string& sceneId) {
    HardwareControlManager::getInstance().setLightingScene(sceneId);
}

inline void blackout() {
    HardwareControlManager::getInstance().blackout();
}

inline void partyMode(const std::string& deviceId) {
    HardwareControlManager::getInstance().enableMusicSync(deviceId, true);
}

} // namespace Hardware

// ============================================================================
// Predefined Vehicle Profiles
// ============================================================================

namespace Vehicles {

inline HardwareDevice createSubmarine(const std::string& name) {
    HardwareDevice sub;
    sub.name = name;
    sub.category = DeviceCategory::Submarine;
    sub.iconName = "submarine";
    sub.color = "#00CED1";

    // Add standard submarine axes
    sub.capabilities["depth"] = {.id = "depth", .name = "Depth", .type = DeviceCapability::Type::Axis,
        .axis = ControlAxis{.id = "depth", .name = "Depth", .minValue = 0, .maxValue = 100}};
    sub.capabilities["throttle"] = {.id = "throttle", .name = "Throttle", .type = DeviceCapability::Type::Axis,
        .axis = ControlAxis{.id = "throttle", .name = "Throttle"}};
    sub.capabilities["rudder"] = {.id = "rudder", .name = "Rudder", .type = DeviceCapability::Type::Axis,
        .axis = ControlAxis{.id = "rudder", .name = "Rudder"}};
    sub.capabilities["lights"] = {.id = "lights", .name = "Lights", .type = DeviceCapability::Type::Toggle};
    sub.capabilities["sonar"] = {.id = "sonar", .name = "Sonar", .type = DeviceCapability::Type::Toggle};

    return sub;
}

inline HardwareDevice createDrone(const std::string& name) {
    HardwareDevice drone;
    drone.name = name;
    drone.category = DeviceCategory::Drone;
    drone.protocol = ConnectionProtocol::MAVLink;
    drone.iconName = "airplane";
    drone.color = "#FF6347";

    drone.capabilities["throttle"] = {.id = "throttle", .name = "Throttle", .type = DeviceCapability::Type::Axis,
        .axis = ControlAxis{.id = "throttle", .name = "Altitude", .minValue = 0, .maxValue = 1}};
    drone.capabilities["pitch"] = {.id = "pitch", .name = "Pitch", .type = DeviceCapability::Type::Axis,
        .axis = ControlAxis{.id = "pitch", .name = "Forward/Back"}};
    drone.capabilities["roll"] = {.id = "roll", .name = "Roll", .type = DeviceCapability::Type::Axis,
        .axis = ControlAxis{.id = "roll", .name = "Left/Right"}};
    drone.capabilities["yaw"] = {.id = "yaw", .name = "Yaw", .type = DeviceCapability::Type::Axis,
        .axis = ControlAxis{.id = "yaw", .name = "Rotation"}};

    return drone;
}

inline HardwareDevice createPartyBoat(const std::string& name) {
    HardwareDevice boat;
    boat.name = name;
    boat.category = DeviceCategory::Ship;
    boat.iconName = "ferry";
    boat.color = "#FFD700";

    boat.capabilities["throttle"] = {.id = "throttle", .name = "Throttle", .type = DeviceCapability::Type::Axis,
        .axis = ControlAxis{.id = "throttle", .name = "Engine"}};
    boat.capabilities["rudder"] = {.id = "rudder", .name = "Rudder", .type = DeviceCapability::Type::Axis,
        .axis = ControlAxis{.id = "rudder", .name = "Steering"}};
    boat.capabilities["partyMode"] = {.id = "partyMode", .name = "Party Mode", .type = DeviceCapability::Type::Toggle};
    boat.capabilities["horn"] = {.id = "horn", .name = "Horn", .type = DeviceCapability::Type::Trigger};
    boat.capabilities["anchor"] = {.id = "anchor", .name = "Anchor", .type = DeviceCapability::Type::Toggle};

    return boat;
}

} // namespace Vehicles

} // namespace Echoel
