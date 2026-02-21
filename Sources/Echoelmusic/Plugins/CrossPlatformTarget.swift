//
//  CrossPlatformTarget.swift
//  Echoelmusic
//
//  Created: February 2026
//  CROSS-PLATFORM TARGET DEFINITIONS
//
//  Defines build targets and capabilities for all platforms:
//  Current: iOS, macOS, watchOS, tvOS, visionOS, Android, Web
//  Future: Windows, Linux, Xbox, PlayStation, Nintendo Switch,
//          Raspberry Pi, NVIDIA Jetson, Meta Quest, Apple Vision Pro
//
//  This file serves as the central registry for platform-specific
//  capabilities, feature flags, and build configuration.

import Foundation

// MARK: - Target Platform

/// All platforms Echoelmusic targets (current + future)
public enum EchoelPlatform: String, CaseIterable, Codable, Sendable {
    // Apple
    case iOS            = "iOS"
    case macOS          = "macOS"
    case watchOS        = "watchOS"
    case tvOS           = "tvOS"
    case visionOS       = "visionOS"

    // Mobile
    case android        = "Android"

    // Desktop
    case windows        = "Windows"
    case linux          = "Linux"

    // Web
    case web            = "Web"             // PWA + WebAssembly

    // Game Consoles
    case xbox           = "Xbox"            // Xbox Series X|S (GDK)
    case playstation    = "PlayStation"      // PS5 (PSSL/GNM)
    case nintendo       = "Nintendo Switch" // NX (NVN API)

    // Embedded / IoT
    case raspberryPi    = "Raspberry Pi"    // ARM64 Linux
    case nvidiaJetson   = "NVIDIA Jetson"   // CUDA + TensorRT
    case beagleBone     = "BeagleBone"      // ARM Linux (DMX/MIDI gateway)

    // XR / VR
    case metaQuest      = "Meta Quest"      // Android-based VR
    case steamVR        = "SteamVR"         // OpenXR (Windows)
    case picoVR         = "Pico VR"         // Android VR

    // AI Devices
    case nvidiaShield   = "NVIDIA Shield"   // Android TV + CUDA
    case coralTPU       = "Google Coral"    // Edge TPU inference

    // MARK: - Platform Properties

    /// Current build status
    public var buildStatus: BuildStatus {
        switch self {
        case .iOS, .macOS, .watchOS, .tvOS, .visionOS:
            return .production       // Shipping
        case .android:
            return .beta             // Active development
        case .web:
            return .beta             // WebAssembly + PWA
        case .windows, .linux:
            return .alpha            // CMake build working
        case .raspberryPi:
            return .alpha            // ARM NEON build
        case .nvidiaJetson:
            return .planned          // CUDA integration designed
        case .xbox, .playstation, .nintendo:
            return .planned          // SDK access needed
        case .metaQuest, .steamVR, .picoVR:
            return .planned          // OpenXR designed
        case .beagleBone, .nvidiaShield, .coralTPU:
            return .concept          // Architecture documented
        }
    }

    /// Audio backend for this platform
    public var audioBackend: AudioBackend {
        switch self {
        case .iOS, .macOS, .watchOS, .tvOS, .visionOS:
            return .coreAudio
        case .android, .metaQuest, .picoVR, .nvidiaShield:
            return .oboe
        case .windows, .xbox:
            return .wasapi
        case .linux, .raspberryPi, .beagleBone:
            return .jack
        case .nvidiaJetson:
            return .alsa
        case .web:
            return .webAudio
        case .playstation:
            return .native           // Sony audio SDK
        case .nintendo:
            return .native           // Nintendo audio SDK
        case .steamVR:
            return .wasapi
        case .coralTPU:
            return .alsa
        }
    }

    /// GPU API for this platform
    public var gpuAPI: GPUAPI {
        switch self {
        case .iOS, .macOS, .watchOS, .tvOS, .visionOS:
            return .metal
        case .android, .metaQuest, .picoVR, .nvidiaShield:
            return .vulkan
        case .windows, .xbox:
            return .directX12
        case .linux, .raspberryPi, .steamVR:
            return .vulkan
        case .nvidiaJetson:
            return .cuda
        case .web:
            return .webGPU
        case .playstation:
            return .gnm              // Sony GNM/GNMX
        case .nintendo:
            return .nvn              // Nintendo NVN
        case .beagleBone, .coralTPU:
            return .openGLES
        }
    }

    /// SIMD instruction set
    public var simdLevel: SIMDLevel {
        switch self {
        case .iOS, .macOS, .watchOS, .tvOS, .visionOS,
             .android, .raspberryPi, .nvidiaJetson,
             .metaQuest, .picoVR, .nvidiaShield, .beagleBone:
            return .neon
        case .windows, .linux, .xbox, .steamVR:
            return .avx2
        case .web:
            return .wasmSIMD
        case .playstation:
            return .avx2             // PS5 uses Zen 2 (AVX2)
        case .nintendo:
            return .neon             // ARM Cortex-A57
        case .coralTPU:
            return .neon
        }
    }

    /// Plugin formats supported on this platform
    public var supportedPluginFormats: [EchoelPluginFormat] {
        switch self {
        case .iOS, .visionOS:
            return [.auv3, .standalone]
        case .macOS:
            return [.auv3, .au, .vst3, .aax, .clap, .ofx, .dctl, .standalone]
        case .windows:
            return [.vst3, .aax, .clap, .ofx, .dctl, .ffx, .standalone]
        case .linux:
            return [.vst3, .clap, .ofx, .standalone]
        case .android:
            return [.standalone]
        case .web:
            return [.wasm]
        default:
            return [.standalone]
        }
    }

    /// Minimum deployment requirement
    public var minimumVersion: String {
        switch self {
        case .iOS:           return "15.0"
        case .macOS:         return "12.0"
        case .watchOS:       return "8.0"
        case .tvOS:          return "15.0"
        case .visionOS:      return "1.0"
        case .android:       return "8.0 (API 26)"
        case .windows:       return "10 (1903)"
        case .linux:         return "Ubuntu 22.04 / Fedora 38"
        case .web:           return "Chrome 94 / Safari 16 / Firefox 100"
        case .raspberryPi:   return "Raspberry Pi OS 12 (Bookworm)"
        case .nvidiaJetson:  return "JetPack 6.0"
        default:             return "TBD"
        }
    }
}

// MARK: - Supporting Types

public enum BuildStatus: String, Codable, Sendable {
    case production = "Production"      // Shipping to users
    case beta       = "Beta"            // Active testing
    case alpha      = "Alpha"           // Builds and runs
    case planned    = "Planned"         // Architecture designed
    case concept    = "Concept"         // Research phase
}

public enum AudioBackend: String, Codable, Sendable {
    case coreAudio  = "CoreAudio"       // Apple
    case oboe       = "Oboe"            // Android (AAudio + OpenSL ES)
    case wasapi     = "WASAPI"          // Windows
    case asio       = "ASIO"            // Windows (professional)
    case jack       = "JACK"            // Linux (<10ms latency)
    case pipewire   = "PipeWire"        // Linux (modern)
    case alsa       = "ALSA"            // Linux (low-level)
    case webAudio   = "WebAudio"        // Browser
    case native     = "Native"          // Console-specific SDK
}

public enum GPUAPI: String, Codable, Sendable {
    case metal      = "Metal"           // Apple
    case vulkan     = "Vulkan"          // Cross-platform
    case directX12  = "DirectX 12"      // Windows / Xbox
    case openGL     = "OpenGL"          // Legacy desktop
    case openGLES   = "OpenGL ES"       // Mobile / embedded
    case webGPU     = "WebGPU"          // Browser (next-gen)
    case webGL      = "WebGL"           // Browser (current)
    case cuda       = "CUDA"            // NVIDIA compute
    case gnm        = "GNM"             // PlayStation
    case nvn        = "NVN"             // Nintendo
}

public enum SIMDLevel: String, Codable, Sendable {
    case avx512     = "AVX-512"
    case avx2       = "AVX2"
    case sse42      = "SSE4.2"
    case neon       = "ARM NEON"
    case wasmSIMD   = "WASM SIMD128"
    case scalar     = "Scalar"
}

// MARK: - Build Configuration

/// Complete build configuration for a target platform
public struct EchoelBuildConfig: Codable, Sendable {
    public let platform: EchoelPlatform
    public let audioBackend: AudioBackend
    public let gpuAPI: GPUAPI
    public let simdLevel: SIMDLevel
    public let pluginFormats: [EchoelPluginFormat]
    public let buildStatus: BuildStatus

    /// Build flags for CMake / Xcode / Gradle
    public var buildFlags: [String: String] {
        var flags: [String: String] = [
            "ECHOEL_PLATFORM": platform.rawValue,
            "ECHOEL_AUDIO_BACKEND": audioBackend.rawValue,
            "ECHOEL_GPU_API": gpuAPI.rawValue,
            "ECHOEL_SIMD": simdLevel.rawValue,
            "ECHOEL_MAX_VOICES": "32",
            "ECHOEL_SAMPLE_RATE": "48000",
            "ECHOEL_MAX_BLOCK_SIZE": "512",
        ]

        // Platform-specific
        switch platform {
        case .iOS, .macOS, .watchOS, .tvOS, .visionOS:
            flags["ECHOEL_USE_CORE_AUDIO"] = "1"
            flags["ECHOEL_USE_METAL"] = "1"
            flags["ECHOEL_USE_HEALTHKIT"] = platform == .iOS || platform == .watchOS || platform == .visionOS ? "1" : "0"

        case .android:
            flags["ECHOEL_USE_OBOE"] = "1"
            flags["ECHOEL_USE_VULKAN"] = "1"
            flags["ECHOEL_NDK_MIN_API"] = "26"

        case .windows:
            flags["ECHOEL_USE_WASAPI"] = "1"
            flags["ECHOEL_USE_DX12"] = "1"
            flags["ECHOEL_USE_ASIO"] = "1"

        case .linux, .raspberryPi:
            flags["ECHOEL_USE_JACK"] = "1"
            flags["ECHOEL_USE_ALSA"] = "1"
            flags["ECHOEL_USE_PIPEWIRE"] = "1"
            flags["ECHOEL_USE_VULKAN"] = "1"

        case .web:
            flags["ECHOEL_USE_WEBAUDIO"] = "1"
            flags["ECHOEL_USE_WEBGPU"] = "1"
            flags["ECHOEL_WASM_THREADS"] = "1"
            flags["ECHOEL_WASM_SIMD"] = "1"

        case .nvidiaJetson:
            flags["ECHOEL_USE_CUDA"] = "1"
            flags["ECHOEL_USE_TENSORRT"] = "1"

        default:
            break
        }

        return flags
    }

    /// Generate for a specific platform
    public static func forPlatform(_ platform: EchoelPlatform) -> EchoelBuildConfig {
        EchoelBuildConfig(
            platform: platform,
            audioBackend: platform.audioBackend,
            gpuAPI: platform.gpuAPI,
            simdLevel: platform.simdLevel,
            pluginFormats: platform.supportedPluginFormats,
            buildStatus: platform.buildStatus
        )
    }
}
