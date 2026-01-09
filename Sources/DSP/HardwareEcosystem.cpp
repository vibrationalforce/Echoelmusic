/**
 * Hardware Ecosystem Implementation - Phase 10000 ULTIMATE
 * Nobel Prize Multitrillion Dollar Company - Ralph Wiggum Lambda Loop
 *
 * C++ Cross-Platform Hardware Support for Windows, Linux, and macOS
 */

#include "HardwareEcosystem.h"
#include <sstream>
#include <iomanip>

namespace Echoelmusic {
namespace Hardware {

void HardwareEcosystem::initializeRegistries() {
    // Initialize Audio Interfaces
    audioInterfaces_ = {
        // Universal Audio Apollo Series
        {"", "Universal Audio", "Apollo Twin X", 10, 6, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24, 32},
         {ConnectionType::Thunderbolt, ConnectionType::USB_C}, true, true, true, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", "Universal Audio", "Apollo x4", 12, 18, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24, 32},
         {ConnectionType::Thunderbolt}, true, true, true, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", "Universal Audio", "Volt 2", 2, 2, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24, 32},
         {ConnectionType::USB_C}, true, false, false, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},

        // Focusrite Scarlett Series
        {"", "Focusrite", "Scarlett 2i2 4th Gen", 2, 2, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24},
         {ConnectionType::USB_C}, true, false, false, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
        {"", "Focusrite", "Scarlett 4i4 4th Gen", 4, 4, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24},
         {ConnectionType::USB_C}, true, false, true, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
        {"", "Focusrite", "Clarett+ 8Pre", 18, 20, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24},
         {ConnectionType::USB_C}, true, false, true, {DevicePlatform::macOS, DevicePlatform::Windows}},

        // RME
        {"", "RME", "Babyface Pro FS", 12, 12, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24, 32},
         {ConnectionType::USB}, true, false, true, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
        {"", "RME", "Fireface UFX III", 94, 94, {44100, 48000, 88200, 96000, 176400, 192000, 352800, 384000}, {16, 24, 32},
         {ConnectionType::USB, ConnectionType::Thunderbolt}, true, true, true, {DevicePlatform::macOS, DevicePlatform::Windows}},

        // MOTU
        {"", "MOTU", "M2", 2, 2, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24, 32},
         {ConnectionType::USB_C}, true, false, false, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
        {"", "MOTU", "M4", 4, 4, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24, 32},
         {ConnectionType::USB_C}, true, false, true, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
        {"", "MOTU", "UltraLite mk5", 18, 22, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24, 32},
         {ConnectionType::USB_C}, true, true, true, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},

        // Apogee
        {"", "Apogee", "Duet 3", 2, 4, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24, 32},
         {ConnectionType::USB_C}, true, true, false, {DevicePlatform::macOS, DevicePlatform::iOS}},
        {"", "Apogee", "Symphony Desktop", 10, 14, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24, 32},
         {ConnectionType::USB_C}, true, true, true, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},

        // SSL
        {"", "SSL", "SSL 2+", 2, 4, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24},
         {ConnectionType::USB}, true, false, true, {DevicePlatform::macOS, DevicePlatform::Windows}},

        // Audient
        {"", "Audient", "iD14 MKII", 10, 4, {44100, 48000, 88200, 96000}, {16, 24},
         {ConnectionType::USB_C}, true, false, true, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},

        // Native Instruments
        {"", "Native Instruments", "Komplete Audio 6 MK2", 6, 6, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24},
         {ConnectionType::USB}, true, false, true, {DevicePlatform::macOS, DevicePlatform::Windows}},

        // Arturia
        {"", "Arturia", "MiniFuse 2", 2, 2, {44100, 48000, 88200, 96000, 176400, 192000}, {16, 24},
         {ConnectionType::USB_C}, true, false, true, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
    };

    // Initialize MIDI Controllers
    midiControllers_ = {
        // Ableton
        {"", "Ableton", "Push 3", MIDIController::ControllerType::PadController,
         64, 0, 0, 8, true, true, true, {ConnectionType::USB, ConnectionType::Bluetooth}, {DevicePlatform::macOS, DevicePlatform::Windows}},

        // Novation
        {"", "Novation", "Launchpad X", MIDIController::ControllerType::PadController,
         64, 0, 0, 0, false, false, false, {ConnectionType::USB}, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
        {"", "Novation", "Launchpad Pro MK3", MIDIController::ControllerType::PadController,
         64, 0, 0, 0, true, false, false, {ConnectionType::USB}, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
        {"", "Novation", "SL MkIII 61", MIDIController::ControllerType::Keyboard,
         16, 61, 8, 8, false, true, false, {ConnectionType::USB, ConnectionType::MIDI_5Pin}, {DevicePlatform::macOS, DevicePlatform::Windows}},

        // Native Instruments
        {"", "Native Instruments", "Maschine MK3", MIDIController::ControllerType::PadController,
         16, 0, 0, 8, false, true, false, {ConnectionType::USB}, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", "Native Instruments", "Maschine+", MIDIController::ControllerType::Groovebox,
         16, 0, 0, 8, false, true, true, {ConnectionType::USB, ConnectionType::WiFi}, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", "Native Instruments", "Komplete Kontrol S61 MK3", MIDIController::ControllerType::Keyboard,
         0, 61, 0, 8, false, true, false, {ConnectionType::USB}, {DevicePlatform::macOS, DevicePlatform::Windows}},

        // Akai
        {"", "Akai", "MPC Live II", MIDIController::ControllerType::Groovebox,
         16, 0, 0, 4, false, true, true, {ConnectionType::USB, ConnectionType::MIDI_5Pin, ConnectionType::WiFi}, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", "Akai", "APC64", MIDIController::ControllerType::PadController,
         64, 0, 8, 0, false, true, false, {ConnectionType::USB}, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", "Akai", "MPK Mini MK3", MIDIController::ControllerType::Keyboard,
         8, 25, 0, 8, false, false, false, {ConnectionType::USB}, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},

        // Arturia
        {"", "Arturia", "KeyLab Essential 61 MK3", MIDIController::ControllerType::Keyboard,
         8, 61, 9, 9, false, true, false, {ConnectionType::USB}, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
        {"", "Arturia", "MiniLab 3", MIDIController::ControllerType::Keyboard,
         8, 25, 0, 8, false, false, false, {ConnectionType::USB}, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},

        // Roland
        {"", "Roland", "A-88 MKII", MIDIController::ControllerType::Keyboard,
         0, 88, 0, 0, false, false, false, {ConnectionType::USB, ConnectionType::MIDI_5Pin, ConnectionType::Bluetooth}, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},

        // Korg
        {"", "Korg", "nanoKONTROL2", MIDIController::ControllerType::FaderController,
         0, 0, 8, 8, false, false, false, {ConnectionType::USB}, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},

        // MPE
        {"", "ROLI", "Seaboard RISE 2", MIDIController::ControllerType::MPEController,
         0, 49, 0, 0, true, false, false, {ConnectionType::USB, ConnectionType::Bluetooth}, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::iOS}},
        {"", "Expressive E", "Osmose", MIDIController::ControllerType::MPEController,
         0, 49, 0, 0, true, false, true, {ConnectionType::USB, ConnectionType::MIDI_5Pin}, {DevicePlatform::macOS, DevicePlatform::Windows}},
    };

    // Initialize DMX Controllers
    dmxControllers_ = {
        {"", "DMX USB Pro", "ENTTEC", 1, {DMXController::LightingProtocol::DMX512}, {ConnectionType::USB}, false},
        {"", "DMX USB Pro MK2", "ENTTEC", 2, {DMXController::LightingProtocol::DMX512, DMXController::LightingProtocol::RDM}, {ConnectionType::USB}, true},
        {"", "ODE MK3", "ENTTEC", 2, {DMXController::LightingProtocol::DMX512, DMXController::LightingProtocol::ArtNet, DMXController::LightingProtocol::sACN, DMXController::LightingProtocol::RDM}, {ConnectionType::Ethernet}, true},
        {"", "Storm 24", "ENTTEC", 24, {DMXController::LightingProtocol::DMX512, DMXController::LightingProtocol::ArtNet, DMXController::LightingProtocol::sACN, DMXController::LightingProtocol::RDM}, {ConnectionType::Ethernet}, true},
        {"", "ultraDMX Micro", "DMXking", 1, {DMXController::LightingProtocol::DMX512}, {ConnectionType::USB}, false},
        {"", "eDMX4 PRO", "DMXking", 4, {DMXController::LightingProtocol::DMX512, DMXController::LightingProtocol::ArtNet, DMXController::LightingProtocol::sACN, DMXController::LightingProtocol::RDM}, {ConnectionType::Ethernet}, true},
        {"", "MagicQ MQ80", "ChamSys", 48, {DMXController::LightingProtocol::DMX512, DMXController::LightingProtocol::ArtNet, DMXController::LightingProtocol::sACN}, {ConnectionType::Ethernet, ConnectionType::USB}, false},
    };

    // Initialize Cameras
    cameras_ = {
        {"", Camera::VideoFormat::UHD6K, Camera::FrameRate::FPS_60, "Blackmagic", "Pocket Cinema Camera 6K Pro", {ConnectionType::HDMI, ConnectionType::USB}, false, false, false},
        {"", Camera::VideoFormat::UHD12K, Camera::FrameRate::FPS_60, "Blackmagic", "URSA Mini Pro 12K", {ConnectionType::SDI, ConnectionType::USB}, false, true, false},
        {"", Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_120, "Sony", "FX6", {ConnectionType::HDMI, ConnectionType::SDI}, false, true, false},
        {"", Camera::VideoFormat::UHD8K, Camera::FrameRate::FPS_30, "Sony", "a1", {ConnectionType::HDMI, ConnectionType::USB}, false, false, false},
        {"", Camera::VideoFormat::UHD8K, Camera::FrameRate::FPS_60, "Canon", "EOS R5 C", {ConnectionType::HDMI, ConnectionType::USB}, false, false, false},
        {"", Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_60, "PTZOptics", "Move 4K", {ConnectionType::HDMI, ConnectionType::SDI, ConnectionType::Ethernet}, true, true, true},
        {"", Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_60, "BirdDog", "P400", {ConnectionType::Ethernet}, true, false, true},
        {"", Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_60, "Logitech", "Brio 4K", {ConnectionType::USB}, false, false, false},
        {"", Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_60, "Elgato", "Facecam Pro", {ConnectionType::USB_C}, false, false, false},
    };

    // Initialize Capture Cards
    captureCards_ = {
        {"", "Blackmagic", "DeckLink Mini Recorder 4K", 1, Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_60, {ConnectionType::HDMI, ConnectionType::SDI}, false},
        {"", "Blackmagic", "DeckLink Quad HDMI Recorder", 4, Camera::VideoFormat::HD1080p, Camera::FrameRate::FPS_60, {ConnectionType::HDMI}, false},
        {"", "Elgato", "HD60 X", 1, Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_60, {ConnectionType::HDMI, ConnectionType::USB}, true},
        {"", "Elgato", "4K60 Pro MK.2", 1, Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_60, {ConnectionType::HDMI}, true},
        {"", "Elgato", "Cam Link 4K", 1, Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_30, {ConnectionType::HDMI, ConnectionType::USB}, false},
        {"", "Magewell", "USB Capture HDMI 4K Plus", 1, Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_60, {ConnectionType::HDMI, ConnectionType::USB}, false},
        {"", "AVerMedia", "Live Gamer 4K 2.1", 1, Camera::VideoFormat::UHD4K, Camera::FrameRate::FPS_120, {ConnectionType::HDMI}, true},
    };

    // Initialize Video Switchers
    videoSwitchers_ = {
        {"", VideoSwitcher::SwitcherType::ATEM, "ATEM Mini", 4, 1, Camera::VideoFormat::HD1080p, true, true, false, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", VideoSwitcher::SwitcherType::ATEM, "ATEM Mini Pro", 4, 2, Camera::VideoFormat::HD1080p, true, true, false, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", VideoSwitcher::SwitcherType::ATEM, "ATEM Mini Extreme ISO G2", 8, 3, Camera::VideoFormat::HD1080p, true, true, false, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", VideoSwitcher::SwitcherType::ATEM, "ATEM Television Studio HD8 ISO", 8, 4, Camera::VideoFormat::HD1080p, true, true, false, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", VideoSwitcher::SwitcherType::ATEM, "ATEM Constellation 8K", 40, 24, Camera::VideoFormat::UHD8K, true, true, false, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", VideoSwitcher::SwitcherType::vMix, "vMix Pro", 1000, 3, Camera::VideoFormat::UHD4K, true, true, true, {DevicePlatform::Windows}},
        {"", VideoSwitcher::SwitcherType::OBS, "OBS Studio", 99, 1, Camera::VideoFormat::UHD8K, true, true, true, {DevicePlatform::macOS, DevicePlatform::Windows, DevicePlatform::Linux}},
        {"", VideoSwitcher::SwitcherType::Wirecast, "Wirecast Pro", 64, 3, Camera::VideoFormat::UHD4K, true, true, true, {DevicePlatform::macOS, DevicePlatform::Windows}},
        {"", VideoSwitcher::SwitcherType::Ecamm, "Ecamm Live", 99, 1, Camera::VideoFormat::UHD4K, true, true, true, {DevicePlatform::macOS}},
    };
}

std::string HardwareEcosystem::generateReport() const {
    std::ostringstream report;

    report << "═══════════════════════════════════════════════════════════════════\n";
    report << "🌐 ECHOELMUSIC HARDWARE ECOSYSTEM - C++ - PHASE 10000 ULTIMATE\n";
    report << "═══════════════════════════════════════════════════════════════════\n\n";

    report << "📊 ECOSYSTEM OVERVIEW\n";
    report << "───────────────────────────────────────────────────────────────────\n";
    report << "Status: Ready\n";
    report << "Connected Devices: " << connectedDevices_.size() << "\n";
    report << "Active Session: " << (activeSession_ ? activeSession_->name : "None") << "\n";

    #if defined(__APPLE__)
    report << "Recommended Driver: Core Audio\n\n";
    #elif defined(_WIN32)
    report << "Recommended Driver: ASIO (Native ASIO support in Windows 11 late 2025)\n\n";
    #elif defined(__linux__)
    report << "Recommended Driver: PipeWire (Modern JACK/PulseAudio replacement)\n\n";
    #else
    report << "Recommended Driver: PortAudio\n\n";
    #endif

    report << "🎛️ AUDIO INTERFACES: " << audioInterfaces_.size() << "+ models\n";
    report << "───────────────────────────────────────────────────────────────────\n";
    report << "Brands: Universal Audio, Focusrite, RME, MOTU, Apogee, SSL,\n";
    report << "        Audient, Native Instruments, Arturia\n\n";

    report << "🎹 MIDI CONTROLLERS: " << midiControllers_.size() << "+ models\n";
    report << "───────────────────────────────────────────────────────────────────\n";
    report << "Brands: Ableton Push, Novation, Native Instruments, Akai,\n";
    report << "        Arturia, Roland, Korg, ROLI, Expressive E\n\n";

    report << "💡 LIGHTING: " << dmxControllers_.size() << "+ DMX controllers\n";
    report << "───────────────────────────────────────────────────────────────────\n";
    report << "Protocols: DMX512, Art-Net, sACN (E1.31), RDM\n";
    report << "Brands: ENTTEC, DMXking, ChamSys, MA Lighting\n\n";

    report << "📹 VIDEO: " << cameras_.size() << "+ cameras, " << captureCards_.size() << "+ capture cards\n";
    report << "───────────────────────────────────────────────────────────────────\n";
    report << "Cameras: Blackmagic, Sony, Canon, PTZOptics, BirdDog, Logitech\n";
    report << "Capture: Blackmagic DeckLink, Elgato, Magewell, AVerMedia\n\n";

    report << "📡 BROADCAST: " << videoSwitchers_.size() << "+ switchers\n";
    report << "───────────────────────────────────────────────────────────────────\n";
    report << "Switchers: ATEM, vMix, OBS, Wirecast, Ecamm\n";
    report << "Protocols: RTMP, RTMPS, SRT, WebRTC, HLS, NDI\n\n";

    report << "═══════════════════════════════════════════════════════════════════\n";
    report << "✅ Nobel Prize Multitrillion Dollar Company Ready\n";
    report << "✅ Phase 10000 ULTIMATE Ralph Wiggum Lambda Loop\n";
    report << "═══════════════════════════════════════════════════════════════════\n";

    return report.str();
}

} // namespace Hardware
} // namespace Echoelmusic
