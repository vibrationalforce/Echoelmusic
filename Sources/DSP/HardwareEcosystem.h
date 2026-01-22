/**
 * Hardware Ecosystem - Phase 10000 ULTIMATE
 * Nobel Prize Multitrillion Dollar Company - Ralph Wiggum Lambda Loop
 *
 * C++ Cross-Platform Hardware Support for Windows, Linux, and macOS
 *
 * Deep Research Sources:
 * - Windows: WASAPI, ASIO (native support late 2025), FlexASIO
 * - Linux: ALSA, JACK, PipeWire (wiki.archlinux.org/title/Professional_audio)
 * - macOS: Core Audio (AVAudioEngine, Audio Unit)
 *
 * The ultimate hardware ecosystem for professional audio, video, lighting, and broadcasting
 */

#pragma once

#include <string>
#include <vector>
#include <memory>
#include <map>
#include <set>
#include <functional>
#include <chrono>
#include <optional>

namespace Echoelmusic {
namespace Hardware {

// MARK: - Enums

enum class EcosystemStatus {
    Initializing,
    Ready,
    Scanning,
    Connected,
    Error
};

enum class DeviceType {
    // Apple
    iPhone, iPad, Mac, AppleWatch, AppleTV, VisionPro, HomePod, AirPods,

    // Android
    AndroidPhone, AndroidTablet, WearOS, AndroidTV,

    // Desktop
    WindowsPC, LinuxPC,

    // VR/AR
    MetaQuest, MetaGlasses,

    // Audio
    AudioInterface, MIDIController, Synthesizer, DrumMachine,

    // Video/Lighting
    VideoSwitcher, Camera, DMXController, LightFixture, LEDStrip,

    // Vehicles
    Tesla, CarPlay, AndroidAuto,

    // Smart Home
    SmartLight, SmartSpeaker,

    Custom
};

enum class DevicePlatform {
    // Apple
    iOS, iPadOS, macOS, watchOS, tvOS, visionOS,

    // Google/Android
    Android, WearOS, AndroidTV, AndroidAuto,

    // Desktop
    Windows, Linux,

    // Meta
    QuestOS,

    // Vehicles
    TeslaOS, CarPlay,

    // Smart Home
    HomeKit, GoogleHome, Alexa, Matter,

    Embedded, Custom
};

enum class ConnectionType {
    // Wired
    USB, USB_C, Thunderbolt, Lightning, HDMI, SDI, XLR, Ethernet, DMX, MIDI_5Pin,

    // Wireless
    Bluetooth, BluetoothLE, WiFi, AirPlay, NDI, ArtNet, sACN, OSC,

    // Streaming
    RTMP, SRT, WebRTC, HLS
};

enum class DeviceCapability {
    // Audio
    AudioInput, AudioOutput, MIDIInput, MIDIOutput, SpatialAudio, LowLatencyAudio,

    // Video
    VideoInput, VideoOutput, Streaming, Recording,

    // Biometrics
    HeartRate, HRV, BloodOxygen, ECG, Breathing, Temperature,

    // Sensors
    Accelerometer, Gyroscope, GPS, LiDAR, FaceTracking, HandTracking, EyeTracking,

    // Display
    Display, HDR, DolbyVision, ProMotion,

    // Lighting
    DMXControl, RGBControl, RGBWControl, MovingHead, Laser,

    // Haptics
    Haptics, ForceTouch
};

enum class AudioDriverType {
    // Apple
    CoreAudio, AVAudioEngine, AudioUnit,

    // Windows
    WASAPI, WASAPI_Exclusive, ASIO, ASIO4ALL, FlexASIO, WDM, DirectSound, MME,

    // Linux
    ALSA, JACK, PipeWire, PulseAudio,

    // Android
    AAudio, Oboe, OpenSLES,

    // Cross-platform
    PortAudio, RtAudio
};

// MARK: - Structures

struct ConnectedDevice {
    std::string id;
    std::string name;
    DeviceType type;
    DevicePlatform platform;
    ConnectionType connectionType;
    std::set<DeviceCapability> capabilities;
    bool isActive = true;
    double latencyMs = 0.0;
};

struct MultiDeviceSession {
    enum class SyncMode { Master, Slave, Peer, Cloud };

    std::string id;
    std::string name;
    std::vector<ConnectedDevice> devices;
    SyncMode syncMode = SyncMode::Peer;
    bool latencyCompensation = true;
    std::chrono::system_clock::time_point startTime;
};

// MARK: - Audio Interface

struct AudioInterface {
    std::string id;
    std::string brand;
    std::string model;
    int inputs;
    int outputs;
    std::vector<int> sampleRates = {44100, 48000, 88200, 96000, 176400, 192000};
    std::vector<int> bitDepths = {16, 24, 32};
    std::vector<ConnectionType> connectionTypes;
    bool hasPreamps = true;
    bool hasDSP = false;
    bool hasMIDI = false;
    std::vector<DevicePlatform> platforms;
};

// MARK: - MIDI Controller

struct MIDIController {
    enum class ControllerType {
        PadController, Keyboard, FaderController, KnobController,
        DJController, Groovebox, MPEController, WindController, DrumController
    };

    std::string id;
    std::string brand;
    std::string model;
    ControllerType type;
    int pads = 0;
    int keys = 0;
    int faders = 0;
    int knobs = 0;
    bool hasMPE = false;
    bool hasDisplay = false;
    bool isStandalone = false;
    std::vector<ConnectionType> connectionTypes;
    std::vector<DevicePlatform> platforms;
};

// MARK: - Lighting Hardware

struct DMXController {
    enum class LightingProtocol { DMX512, ArtNet, sACN, RDM, KiNET, Hue, Nanoleaf, LIFX, WLED };

    std::string id;
    std::string name;
    std::string brand;
    int universes;
    std::vector<LightingProtocol> protocols;
    std::vector<ConnectionType> connectionTypes;
    bool hasRDM = false;
};

// MARK: - Video Hardware

struct Camera {
    enum class VideoFormat { HD720p, HD1080p, UHD4K, UHD6K, UHD8K, UHD12K, UHD16K };
    enum class FrameRate { FPS_24 = 24, FPS_30 = 30, FPS_60 = 60, FPS_120 = 120, FPS_240 = 240, FPS_1000 = 1000 };

    std::string id;
    std::string brand;
    std::string model;
    VideoFormat maxResolution;
    FrameRate maxFrameRate;
    std::vector<ConnectionType> connectionTypes;
    bool hasNDI = false;
    bool hasSDI = false;
    bool isPTZ = false;
};

struct CaptureCard {
    std::string id;
    std::string brand;
    std::string model;
    int inputs;
    Camera::VideoFormat maxResolution;
    Camera::FrameRate maxFrameRate;
    std::vector<ConnectionType> connectionTypes;
    bool hasPassthrough = false;
};

// MARK: - Video Switcher

struct VideoSwitcher {
    enum class SwitcherType { ATEM, TriCaster, vMix, OBS, Wirecast, Ecamm };

    std::string id;
    SwitcherType type;
    std::string model;
    int inputs;
    int outputs;
    Camera::VideoFormat maxResolution;
    bool hasStreaming = true;
    bool hasRecording = true;
    bool hasNDI = false;
    std::vector<DevicePlatform> platforms;
};

// MARK: - Hardware Ecosystem Class

class HardwareEcosystem {
public:
    static HardwareEcosystem& getInstance() {
        static HardwareEcosystem instance;
        return instance;
    }

    // Delete copy/move
    HardwareEcosystem(const HardwareEcosystem&) = delete;
    HardwareEcosystem& operator=(const HardwareEcosystem&) = delete;

    // Status
    EcosystemStatus getStatus() const { return status_; }
    const std::vector<ConnectedDevice>& getConnectedDevices() const { return connectedDevices_; }
    const std::optional<MultiDeviceSession>& getActiveSession() const { return activeSession_; }

    // Session Management
    MultiDeviceSession startSession(const std::string& name,
                                    const std::vector<ConnectedDevice>& devices = {}) {
        MultiDeviceSession session;
        session.name = name;
        session.devices = devices;
        session.startTime = std::chrono::system_clock::now();
        activeSession_ = session;
        return session;
    }

    void endSession() {
        activeSession_ = std::nullopt;
    }

    void addDeviceToSession(const ConnectedDevice& device) {
        if (activeSession_) {
            activeSession_->devices.push_back(device);
            connectedDevices_.push_back(device);
        }
    }

    // Platform-specific driver recommendations
    AudioDriverType getRecommendedDriver() const {
        #if defined(__APPLE__)
            return AudioDriverType::CoreAudio;
        #elif defined(_WIN32)
            return AudioDriverType::ASIO;  // Native ASIO support coming late 2025
        #elif defined(__linux__)
            return AudioDriverType::PipeWire;  // Modern replacement for JACK/PulseAudio
        #else
            return AudioDriverType::PortAudio;
        #endif
    }

    // Get all audio interfaces
    const std::vector<AudioInterface>& getAudioInterfaces() const { return audioInterfaces_; }

    // Get all MIDI controllers
    const std::vector<MIDIController>& getMIDIControllers() const { return midiControllers_; }

    // Get all DMX controllers
    const std::vector<DMXController>& getDMXControllers() const { return dmxControllers_; }

    // Get all cameras
    const std::vector<Camera>& getCameras() const { return cameras_; }

    // Get all capture cards
    const std::vector<CaptureCard>& getCaptureCards() const { return captureCards_; }

    // Get all video switchers
    const std::vector<VideoSwitcher>& getVideoSwitchers() const { return videoSwitchers_; }

    // Generate report
    std::string generateReport() const;

private:
    HardwareEcosystem() {
        initializeRegistries();
        status_ = EcosystemStatus::Ready;
    }

    void initializeRegistries();

    EcosystemStatus status_ = EcosystemStatus::Initializing;
    std::vector<ConnectedDevice> connectedDevices_;
    std::optional<MultiDeviceSession> activeSession_;

    // Hardware registries
    std::vector<AudioInterface> audioInterfaces_;
    std::vector<MIDIController> midiControllers_;
    std::vector<DMXController> dmxControllers_;
    std::vector<Camera> cameras_;
    std::vector<CaptureCard> captureCards_;
    std::vector<VideoSwitcher> videoSwitchers_;
};

// MARK: - Streaming Platforms

struct StreamingPlatform {
    std::string name;
    std::string rtmpUrl;
    int maxBitrate;  // kbps
};

const std::vector<StreamingPlatform> STREAMING_PLATFORMS = {
    {"YouTube Live", "rtmp://a.rtmp.youtube.com/live2", 51000},
    {"Twitch", "rtmp://live.twitch.tv/app", 8500},
    {"Facebook Live", "rtmps://live-api-s.facebook.com:443/rtmp", 8000},
    {"Instagram Live", "rtmps://live-upload.instagram.com:443/rtmp", 3500},
    {"TikTok Live", "rtmp://push.tiktokv.com/live", 6000},
    {"Vimeo Live", "rtmps://rtmp-global.cloud.vimeo.com:443/live", 20000},
    {"Restream", "rtmp://live.restream.io/live", 51000},
    {"Castr", "rtmp://live.castr.io/static", 51000}
};

// MARK: - Streaming Protocols

struct StreamingProtocol {
    std::string name;
    std::string latency;
    std::string reliability;
};

const std::vector<StreamingProtocol> STREAMING_PROTOCOLS = {
    {"RTMP", "2-5 seconds", "Good"},
    {"RTMPS", "2-5 seconds", "Excellent (encrypted)"},
    {"SRT", "< 1 second", "Excellent"},
    {"WebRTC", "< 500ms", "Good"},
    {"HLS", "6-30 seconds", "Excellent"},
    {"RIST", "< 1 second", "Excellent"},
    {"NDI", "< 1 frame", "Excellent (LAN only)"},
    {"NDI|HX", "1-2 frames", "Good"},
    {"NDI|HX2", "< 1 frame", "Excellent"},
    {"NDI|HX3", "< 1 frame", "Excellent"}
};

// MARK: - Platform-Specific Audio Info

struct PlatformAudioInfo {
    DevicePlatform platform;
    AudioDriverType recommendedDriver;
    std::string notes;
};

const std::vector<PlatformAudioInfo> PLATFORM_AUDIO_INFO = {
    {DevicePlatform::macOS, AudioDriverType::CoreAudio,
     "Native low-latency audio via AVAudioEngine and Audio Units"},
    {DevicePlatform::iOS, AudioDriverType::CoreAudio,
     "Core Audio with AVAudioSession for routing"},
    {DevicePlatform::Windows, AudioDriverType::ASIO,
     "ASIO for professional low-latency. Native ASIO support in Windows 11 late 2025"},
    {DevicePlatform::Linux, AudioDriverType::PipeWire,
     "PipeWire replaces JACK/PulseAudio with unified low-latency stack"},
    {DevicePlatform::Android, AudioDriverType::Oboe,
     "Oboe wraps AAudio (8.1+) and OpenSL ES for lowest latency"}
};

} // namespace Hardware
} // namespace Echoelmusic
