//
//  PluginBundleManager.swift
//  Echoelmusic
//
//  Created: February 2026
//  PLUGIN BUNDLE MANAGER — Manages all plugin formats from the host app
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  Architecture:
//
//    Echoelmusic.app (Host)
//        │
//    PluginBundleManager
//        ├── AUv3 Extensions (iOS/macOS — embedded in app bundle)
//        ├── AU Components (macOS — ~/Library/Audio/Plug-Ins/Components/)
//        ├── VST3 Bundles (macOS — ~/Library/Audio/Plug-Ins/VST3/)
//        ├── CLAP Bundles (macOS — ~/Library/Audio/Plug-Ins/CLAP/)
//        ├── AAX Bundles (macOS — /Library/Application Support/Avid/Audio/Plug-Ins/)
//        ├── OFX Bundles (macOS — /Library/OFX/Plugins/)
//        ├── DCTL Files (macOS — ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/DCTL/)
//        └── WebAssembly (Hybrid PWA — served from CDN)
//
//  Supported Plugin Formats:
//    Audio: AUv3, AU, VST3, AAX, CLAP
//    Video: OFX, DCTL, FFX/GLSL
//    Web:   WebAssembly + WebAudio AudioWorklet
//  ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import Combine

#if canImport(AudioToolbox)
import AudioToolbox
#endif

// MARK: - Plugin Format Definitions

/// All supported plugin formats across platforms
public enum EchoelPluginFormat: String, CaseIterable, Codable, Sendable {
    // Audio Plugin Formats
    case auv3       = "AUv3"        // Apple Audio Unit v3 (iOS/macOS)
    case au         = "AU"          // Classic Audio Unit (macOS)
    case vst3       = "VST3"        // Steinberg VST3 (macOS/Windows/Linux)
    case aax        = "AAX"         // Avid AAX (Pro Tools)
    case clap       = "CLAP"        // CLever Audio Plugin (all platforms, MIT)

    // Video Plugin Formats
    case ofx        = "OFX"         // OpenFX (DaVinci Resolve/Nuke/Natron)
    case dctl       = "DCTL"        // DaVinci Color Transform Language
    case glsl       = "GLSL"        // OpenGL Shading Language
    case ffx        = "FFX"         // AMD FidelityFX / HLSL Compute
    case metal      = "Metal"       // Apple Metal Shaders

    // Hybrid
    case wasm       = "WebAssembly" // WebAssembly + WebAudio
    case standalone = "Standalone"  // Native standalone app

    /// Platform availability
    public var supportedPlatforms: [String] {
        switch self {
        case .auv3:       return ["iOS", "macOS", "visionOS"]
        case .au:         return ["macOS"]
        case .vst3:       return ["macOS", "Windows", "Linux"]
        case .aax:        return ["macOS", "Windows"]
        case .clap:       return ["macOS", "Windows", "Linux"]
        case .ofx:        return ["macOS", "Windows", "Linux"]
        case .dctl:       return ["macOS", "Windows", "Linux"]
        case .glsl:       return ["macOS", "Windows", "Linux", "Android", "Web"]
        case .ffx:        return ["Windows", "Xbox", "PlayStation"]
        case .metal:      return ["iOS", "macOS", "tvOS", "visionOS"]
        case .wasm:       return ["Web", "iOS", "Android", "macOS", "Windows", "Linux"]
        case .standalone: return ["iOS", "macOS", "Windows", "Linux", "Android"]
        }
    }

    /// File extension for this format
    public var fileExtension: String {
        switch self {
        case .auv3:       return "appex"
        case .au:         return "component"
        case .vst3:       return "vst3"
        case .aax:        return "aaxplugin"
        case .clap:       return "clap"
        case .ofx:        return "ofx.bundle"
        case .dctl:       return "dctl"
        case .glsl:       return "glsl"
        case .ffx:        return "hlsl"
        case .metal:      return "metallib"
        case .wasm:       return "wasm"
        case .standalone: return "app"
        }
    }

    /// Installation path on macOS
    public var macOSInstallPath: String? {
        switch self {
        case .auv3:  return nil  // Embedded in app bundle
        case .au:    return "~/Library/Audio/Plug-Ins/Components"
        case .vst3:  return "~/Library/Audio/Plug-Ins/VST3"
        case .aax:   return "/Library/Application Support/Avid/Audio/Plug-Ins"
        case .clap:  return "~/Library/Audio/Plug-Ins/CLAP"
        case .ofx:   return "/Library/OFX/Plugins"
        case .dctl:  return "~/Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/DCTL"
        default:     return nil
        }
    }
}

// MARK: - Plugin Descriptor

/// Describes a single plugin within the Echoelmusic suite
public struct EchoelPluginDescriptor: Identifiable, Codable, Sendable {
    public let id: String                   // "com.echoelmusic.synth"
    public let name: String                 // "EchoelSynth"
    public let subtitle: String             // "Bio-reactive synthesis instrument"
    public let category: PluginCategory
    public let supportedFormats: [EchoelPluginFormat]
    public let parameterCount: Int
    public let inputChannels: Int
    public let outputChannels: Int

    // AU-specific identifiers
    public let auType: String              // "aumu", "aufx", "aumi"
    public let auSubtype: String           // "Esyn"
    public let auManufacturer: String      // "Echo"

    public enum PluginCategory: String, Codable, Sendable {
        case instrument     = "Instrument"
        case effect         = "Effect"
        case midi           = "MIDI"
        case analyzer       = "Analyzer"
        case videoEffect    = "Video Effect"
    }
}

// MARK: - Plugin Bundle Manager

/// Central manager for all Echoelmusic plugin formats
@MainActor
public final class PluginBundleManager: ObservableObject {

    public static let shared = PluginBundleManager()

    // MARK: - Published State

    @Published public var installedFormats: Set<EchoelPluginFormat> = []
    @Published public var registeredPlugins: [EchoelPluginDescriptor] = []
    @Published public var isScanning: Bool = false

    // MARK: - Plugin Registry

    /// All Echoelmusic plugins with their format support
    public static let pluginSuite: [EchoelPluginDescriptor] = [
        EchoelPluginDescriptor(
            id: "com.echoelmusic.synth", name: "EchoelSynth",
            subtitle: "Bio-reactive synthesis — DDSP, Modal, Quantum, Cellular, Sampler",
            category: .instrument,
            supportedFormats: [.auv3, .au, .vst3, .clap, .aax, .standalone, .wasm],
            parameterCount: 36, inputChannels: 0, outputChannels: 2,
            auType: "aumu", auSubtype: "Esyn", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.fx", name: "EchoelFX",
            subtitle: "Professional effects chain — reverb, delay, compressor, EQ, saturation",
            category: .effect,
            supportedFormats: [.auv3, .au, .vst3, .clap, .aax, .standalone],
            parameterCount: 36, inputChannels: 2, outputChannels: 2,
            auType: "aufx", auSubtype: "Eefx", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.mix", name: "EchoelMix",
            subtitle: "Console-grade mixer bus processor with spatial audio",
            category: .effect,
            supportedFormats: [.auv3, .au, .vst3, .clap, .aax, .standalone],
            parameterCount: 36, inputChannels: 2, outputChannels: 2,
            auType: "aufx", auSubtype: "Emix", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.bass", name: "EchoelBass",
            subtitle: "5-engine morphing bass — 808, Reese, Moog, Acid, Growl",
            category: .instrument,
            supportedFormats: [.auv3, .au, .vst3, .clap, .aax, .standalone, .wasm],
            parameterCount: 36, inputChannels: 0, outputChannels: 2,
            auType: "aumu", auSubtype: "E808", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.beat", name: "EchoelBeat",
            subtitle: "Professional drum machine + 808 HiHat synth with roll sequencer",
            category: .instrument,
            supportedFormats: [.auv3, .au, .vst3, .clap, .aax, .standalone, .wasm],
            parameterCount: 36, inputChannels: 0, outputChannels: 2,
            auType: "aumu", auSubtype: "Ebt1", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.mind", name: "EchoelMind",
            subtitle: "AI-powered stem separation and audio enhancement",
            category: .effect,
            supportedFormats: [.auv3, .au, .vst3, .clap, .aax, .standalone],
            parameterCount: 36, inputChannels: 2, outputChannels: 2,
            auType: "aufx", auSubtype: "Emnd", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.bio", name: "EchoelBio",
            subtitle: "Binaural beat & AI tone generator for meditation and focus",
            category: .instrument,
            supportedFormats: [.auv3, .au, .vst3, .clap, .standalone, .wasm],
            parameterCount: 36, inputChannels: 0, outputChannels: 2,
            auType: "aumu", auSubtype: "Ebio", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.seq", name: "EchoelSeq",
            subtitle: "Bio-reactive step sequencer with generative patterns",
            category: .midi,
            supportedFormats: [.auv3, .au, .vst3, .clap],
            parameterCount: 36, inputChannels: 0, outputChannels: 2,
            auType: "aumi", auSubtype: "Eseq", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.midi", name: "EchoelMIDI",
            subtitle: "MIDI 2.0 + MPE processor, arpeggiator, chord generator",
            category: .midi,
            supportedFormats: [.auv3, .au, .vst3, .clap],
            parameterCount: 36, inputChannels: 0, outputChannels: 0,
            auType: "aumi", auSubtype: "Emid", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.field", name: "EchoelField",
            subtitle: "Audio-reactive visual analyzer — spectrum, waveform, cymatics",
            category: .analyzer,
            supportedFormats: [.auv3, .au, .vst3, .clap, .ofx],
            parameterCount: 36, inputChannels: 2, outputChannels: 2,
            auType: "aufx", auSubtype: "Efld", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.beam", name: "EchoelBeam",
            subtitle: "Audio-to-lighting DMX bridge for live performance",
            category: .midi,
            supportedFormats: [.auv3, .au, .clap],
            parameterCount: 36, inputChannels: 2, outputChannels: 0,
            auType: "aumi", auSubtype: "Ebem", auManufacturer: "Echo"),

        EchoelPluginDescriptor(
            id: "com.echoelmusic.net", name: "EchoelNet",
            subtitle: "Network protocol bridge — OSC, MSC, Dante, NDI",
            category: .midi,
            supportedFormats: [.auv3, .au, .clap],
            parameterCount: 36, inputChannels: 2, outputChannels: 2,
            auType: "aumi", auSubtype: "Enet", auManufacturer: "Echo"),

        // Video plugins
        EchoelPluginDescriptor(
            id: "com.echoelmusic.vfx", name: "EchoelVFX",
            subtitle: "Bio-reactive video effects for DaVinci Resolve / Nuke",
            category: .videoEffect,
            supportedFormats: [.ofx, .dctl, .glsl, .ffx, .metal],
            parameterCount: 14, inputChannels: 0, outputChannels: 0,
            auType: "", auSubtype: "", auManufacturer: "Echo"),
    ]

    // MARK: - Initialization

    private init() {
        registeredPlugins = Self.pluginSuite
        detectInstalledFormats()
    }

    // MARK: - Format Detection

    /// Detect which plugin formats are available on this system
    public func detectInstalledFormats() {
        var formats = Set<EchoelPluginFormat>()

        // AUv3 always available on Apple platforms
        #if os(iOS) || os(macOS) || os(visionOS)
        formats.insert(.auv3)
        formats.insert(.standalone)
        formats.insert(.metal)
        #endif

        #if os(macOS)
        formats.insert(.au)

        // Check for VST3 SDK
        let vst3Path = NSString(string: "~/Library/Audio/Plug-Ins/VST3").expandingTildeInPath
        if FileManager.default.fileExists(atPath: vst3Path) {
            formats.insert(.vst3)
        }

        // Check for CLAP directory
        let clapPath = NSString(string: "~/Library/Audio/Plug-Ins/CLAP").expandingTildeInPath
        if FileManager.default.fileExists(atPath: clapPath) {
            formats.insert(.clap)
        }

        // Check for DaVinci Resolve DCTL directory
        let dctlPath = NSString(string: "~/Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/DCTL").expandingTildeInPath
        if FileManager.default.fileExists(atPath: dctlPath) {
            formats.insert(.dctl)
        }

        // Check for OFX directory
        if FileManager.default.fileExists(atPath: "/Library/OFX/Plugins") {
            formats.insert(.ofx)
        }

        // Check for AAX (Pro Tools)
        if FileManager.default.fileExists(atPath: "/Library/Application Support/Avid/Audio/Plug-Ins") {
            formats.insert(.aax)
        }
        #endif

        // WebAssembly always available
        formats.insert(.wasm)
        formats.insert(.glsl)

        installedFormats = formats
    }

    // MARK: - Plugin Installation

    /// Install DCTL shaders to DaVinci Resolve's DCTL directory
    public func installDCTLShaders() -> Bool {
        #if os(macOS)
        let dctlPath = NSString(string: "~/Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/DCTL/Echoelmusic").expandingTildeInPath

        do {
            try FileManager.default.createDirectory(atPath: dctlPath, withIntermediateDirectories: true)

            // Copy DCTL files from app bundle
            if let bundle = Bundle.main.url(forResource: "EchoelBioReactive", withExtension: "dctl") {
                let dest = URL(fileURLWithPath: dctlPath).appendingPathComponent("EchoelBioReactive.dctl")
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: bundle, to: dest)
            }

            if let bundle = Bundle.main.url(forResource: "EchoelCymaticGrade", withExtension: "dctl") {
                let dest = URL(fileURLWithPath: dctlPath).appendingPathComponent("EchoelCymaticGrade.dctl")
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: bundle, to: dest)
            }

            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Build Info

    /// Get build information for all plugin formats
    public var buildMatrix: [(format: EchoelPluginFormat, status: String, platforms: [String])] {
        EchoelPluginFormat.allCases.map { format in
            let status: String
            if installedFormats.contains(format) {
                status = "Ready"
            } else {
                status = "Available"
            }
            return (format: format, status: status, platforms: format.supportedPlatforms)
        }
    }

    /// Summary of all plugins and formats
    public var summary: String {
        let audioPlugins = registeredPlugins.filter { $0.category != .videoEffect }
        let videoPlugins = registeredPlugins.filter { $0.category == .videoEffect }
        let audioFormats = Set(EchoelPluginFormat.allCases.filter {
            [.auv3, .au, .vst3, .aax, .clap, .standalone].contains($0)
        })
        let videoFormats = Set(EchoelPluginFormat.allCases.filter {
            [.ofx, .dctl, .glsl, .ffx, .metal].contains($0)
        })

        return """
        Echoelmusic Plugin Suite v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")
        ═══════════════════════════════════════
        Audio Plugins: \(audioPlugins.count) (\(audioFormats.count) formats)
        Video Plugins: \(videoPlugins.count) (\(videoFormats.count) formats)
        Hybrid: WebAssembly PWA
        Installed Formats: \(installedFormats.map(\.rawValue).sorted().joined(separator: ", "))
        """
    }
}
