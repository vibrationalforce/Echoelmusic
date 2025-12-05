import Foundation
import AVFoundation
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(CoreAudioKit)
import CoreAudioKit
#endif

// MARK: - Audio Unit v3 Plugin Host
// Host for AU, VST3, and AUv3 plugins with real-time processing

@MainActor
public final class AUv3PluginHost: ObservableObject {
    public static let shared = AUv3PluginHost()

    @Published public private(set) var availablePlugins: [PluginDescription] = []
    @Published public private(set) var loadedPlugins: [String: LoadedPlugin] = [:]
    @Published public private(set) var isScanning = false

    // Audio processing
    private var audioEngine: AVAudioEngine?
    private var pluginNodes: [String: AVAudioUnit] = [:]

    // Plugin paths
    private let systemPluginPaths = [
        "/Library/Audio/Plug-Ins/Components",
        "/Library/Audio/Plug-Ins/VST3",
        "~/Library/Audio/Plug-Ins/Components",
        "~/Library/Audio/Plug-Ins/VST3"
    ]

    // Cache
    private var pluginCache: [String: PluginDescription] = [:]
    private let cacheURL: URL

    public init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheURL = cacheDir.appendingPathComponent("plugin_cache.json")
        loadPluginCache()
    }

    // MARK: - Plugin Scanning

    /// Scan for available plugins
    public func scanPlugins() async {
        isScanning = true
        defer { isScanning = false }

        var discovered: [PluginDescription] = []

        // Scan Audio Units
        #if canImport(AudioToolbox)
        let auPlugins = await scanAudioUnits()
        discovered.append(contentsOf: auPlugins)
        #endif

        // Scan VST3
        let vst3Plugins = await scanVST3Plugins()
        discovered.append(contentsOf: vst3Plugins)

        // Update cache
        for plugin in discovered {
            pluginCache[plugin.identifier] = plugin
        }
        savePluginCache()

        availablePlugins = discovered.sorted { $0.name < $1.name }
    }

    #if canImport(AudioToolbox)
    private func scanAudioUnits() async -> [PluginDescription] {
        return await withCheckedContinuation { continuation in
            var descriptions: [PluginDescription] = []

            // Get component descriptions for different AU types
            let auTypes: [AudioComponentDescription] = [
                AudioComponentDescription(
                    componentType: kAudioUnitType_Effect,
                    componentSubType: 0,
                    componentManufacturer: 0,
                    componentFlags: 0,
                    componentFlagsMask: 0
                ),
                AudioComponentDescription(
                    componentType: kAudioUnitType_MusicDevice,
                    componentSubType: 0,
                    componentManufacturer: 0,
                    componentFlags: 0,
                    componentFlagsMask: 0
                ),
                AudioComponentDescription(
                    componentType: kAudioUnitType_MusicEffect,
                    componentSubType: 0,
                    componentManufacturer: 0,
                    componentFlags: 0,
                    componentFlagsMask: 0
                )
            ]

            for desc in auTypes {
                var component: AudioComponent? = nil
                var searchDesc = desc

                repeat {
                    component = AudioComponentFindNext(component, &searchDesc)

                    if let comp = component {
                        var name: CFString?
                        AudioComponentCopyName(comp, &name)

                        var compDesc = AudioComponentDescription()
                        AudioComponentGetDescription(comp, &compDesc)

                        let pluginDesc = PluginDescription(
                            identifier: "\(compDesc.componentManufacturer).\(compDesc.componentSubType)",
                            name: (name as String?) ?? "Unknown",
                            manufacturer: fourCharCodeToString(compDesc.componentManufacturer),
                            version: "1.0",
                            type: auTypeToPluginType(compDesc.componentType),
                            format: .audioUnit,
                            category: categoryForAUType(compDesc.componentType),
                            inputChannels: 2,
                            outputChannels: 2
                        )

                        descriptions.append(pluginDesc)
                    }
                } while component != nil
            }

            continuation.resume(returning: descriptions)
        }
    }
    #endif

    private func scanVST3Plugins() async -> [PluginDescription] {
        var descriptions: [PluginDescription] = []

        for basePath in systemPluginPaths {
            let expandedPath = NSString(string: basePath).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)

            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            ) else { continue }

            for item in contents where item.pathExtension == "vst3" {
                let name = item.deletingPathExtension().lastPathComponent

                let desc = PluginDescription(
                    identifier: "vst3.\(name)",
                    name: name,
                    manufacturer: "Unknown",
                    version: "1.0",
                    type: .effect,
                    format: .vst3,
                    category: .dynamics,
                    inputChannels: 2,
                    outputChannels: 2
                )

                descriptions.append(desc)
            }
        }

        return descriptions
    }

    // MARK: - Plugin Loading

    /// Load a plugin by identifier
    public func loadPlugin(_ identifier: String) async throws -> LoadedPlugin {
        guard let description = availablePlugins.first(where: { $0.identifier == identifier }) else {
            throw PluginError.pluginNotFound
        }

        // Check if already loaded
        if let existing = loadedPlugins[identifier] {
            return existing
        }

        switch description.format {
        case .audioUnit:
            return try await loadAudioUnit(description)
        case .vst3:
            return try await loadVST3(description)
        case .auv3:
            return try await loadAUv3(description)
        }
    }

    #if canImport(AudioToolbox)
    private func loadAudioUnit(_ description: PluginDescription) async throws -> LoadedPlugin {
        // Parse identifier to get manufacturer and subtype
        let parts = description.identifier.split(separator: ".")
        guard parts.count >= 2 else {
            throw PluginError.invalidIdentifier
        }

        let componentDesc = AudioComponentDescription(
            componentType: auTypeFromPluginType(description.type),
            componentSubType: stringToFourCharCode(String(parts[1])),
            componentManufacturer: stringToFourCharCode(String(parts[0])),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        return try await withCheckedThrowingContinuation { continuation in
            AVAudioUnit.instantiate(with: componentDesc, options: []) { audioUnit, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let audioUnit = audioUnit else {
                    continuation.resume(throwing: PluginError.instantiationFailed)
                    return
                }

                let loaded = LoadedPlugin(
                    description: description,
                    audioUnit: audioUnit,
                    parameters: self.extractParameters(from: audioUnit)
                )

                Task { @MainActor in
                    self.loadedPlugins[description.identifier] = loaded
                    self.pluginNodes[description.identifier] = audioUnit
                }

                continuation.resume(returning: loaded)
            }
        }
    }
    #else
    private func loadAudioUnit(_ description: PluginDescription) async throws -> LoadedPlugin {
        throw PluginError.platformNotSupported
    }
    #endif

    private func loadVST3(_ description: PluginDescription) async throws -> LoadedPlugin {
        // VST3 loading would use VST3 SDK
        // Placeholder for cross-platform implementation
        throw PluginError.formatNotSupported
    }

    private func loadAUv3(_ description: PluginDescription) async throws -> LoadedPlugin {
        // Similar to Audio Unit loading but for AUv3 extensions
        #if canImport(AudioToolbox)
        return try await loadAudioUnit(description)
        #else
        throw PluginError.platformNotSupported
        #endif
    }

    /// Unload a plugin
    public func unloadPlugin(_ identifier: String) {
        loadedPlugins.removeValue(forKey: identifier)
        pluginNodes.removeValue(forKey: identifier)
    }

    // MARK: - Plugin Processing

    /// Process audio through a plugin
    public func process(
        _ identifier: String,
        buffer: AVAudioPCMBuffer
    ) async throws -> AVAudioPCMBuffer {
        guard let audioUnit = pluginNodes[identifier] else {
            throw PluginError.pluginNotLoaded
        }

        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else {
            throw PluginError.bufferCreationFailed
        }

        // Render
        #if canImport(AudioToolbox)
        var renderError: OSStatus = noErr

        let renderBlock = audioUnit.auAudioUnit.renderBlock

        var flags = AudioUnitRenderActionFlags()
        var timeStamp = AudioTimeStamp()
        timeStamp.mSampleTime = 0
        timeStamp.mFlags = .sampleTimeValid

        let status = buffer.floatChannelData!.withMemoryRebound(
            to: UnsafeMutablePointer<Float>.self,
            capacity: Int(buffer.format.channelCount)
        ) { channelData in
            var ablPointer = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: buffer.format.channelCount,
                    mDataByteSize: buffer.frameLength * 4,
                    mData: channelData.pointee
                )
            )

            return renderBlock(
                &flags,
                &timeStamp,
                buffer.frameLength,
                0,
                &ablPointer,
                nil
            )
        }

        if status != noErr {
            throw PluginError.renderFailed(status)
        }
        #endif

        return outputBuffer
    }

    // MARK: - Parameter Management

    #if canImport(AudioToolbox)
    private func extractParameters(from audioUnit: AVAudioUnit) -> [PluginParameter] {
        var parameters: [PluginParameter] = []

        let parameterTree = audioUnit.auAudioUnit.parameterTree

        func extractFromGroup(_ group: AUParameterGroup?) {
            guard let group = group else { return }

            for child in group.allParameters {
                let param = PluginParameter(
                    identifier: child.identifier,
                    name: child.displayName,
                    value: child.value,
                    minValue: child.minValue,
                    maxValue: child.maxValue,
                    defaultValue: child.value,
                    unit: child.unitName ?? ""
                )
                parameters.append(param)
            }
        }

        if let tree = parameterTree {
            for child in tree.allParameters {
                let param = PluginParameter(
                    identifier: "\(child.address)",
                    name: child.displayName,
                    value: child.value,
                    minValue: child.minValue,
                    maxValue: child.maxValue,
                    defaultValue: child.value,
                    unit: child.unitName ?? ""
                )
                parameters.append(param)
            }
        }

        return parameters
    }
    #endif

    /// Set parameter value
    public func setParameter(
        pluginId: String,
        parameterId: String,
        value: Float
    ) {
        guard let loaded = loadedPlugins[pluginId],
              let audioUnit = pluginNodes[pluginId] else { return }

        #if canImport(AudioToolbox)
        if let address = UInt64(parameterId),
           let param = audioUnit.auAudioUnit.parameterTree?.parameter(withAddress: address) {
            param.value = value
        }
        #endif

        // Update local state
        if var params = loadedPlugins[pluginId]?.parameters,
           let index = params.firstIndex(where: { $0.identifier == parameterId }) {
            params[index].value = value
            loadedPlugins[pluginId]?.parameters = params
        }
    }

    // MARK: - Preset Management

    /// Load factory preset
    public func loadFactoryPreset(_ pluginId: String, presetIndex: Int) async throws {
        guard let audioUnit = pluginNodes[pluginId] else {
            throw PluginError.pluginNotLoaded
        }

        #if canImport(AudioToolbox)
        let presets = audioUnit.auAudioUnit.factoryPresets ?? []
        guard presetIndex < presets.count else {
            throw PluginError.presetNotFound
        }

        audioUnit.auAudioUnit.currentPreset = presets[presetIndex]
        #endif
    }

    /// Save user preset
    public func saveUserPreset(_ pluginId: String, name: String) async throws -> URL {
        guard let loaded = loadedPlugins[pluginId] else {
            throw PluginError.pluginNotLoaded
        }

        let presetData = PluginPreset(
            name: name,
            pluginId: pluginId,
            parameters: loaded.parameters.map { ($0.identifier, $0.value) }
        )

        let presetsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Presets")
            .appendingPathComponent(loaded.description.name)

        try FileManager.default.createDirectory(at: presetsDir, withIntermediateDirectories: true)

        let presetURL = presetsDir.appendingPathComponent("\(name).ecpreset")
        let data = try JSONEncoder().encode(presetData)
        try data.write(to: presetURL)

        return presetURL
    }

    /// Load user preset
    public func loadUserPreset(_ pluginId: String, url: URL) async throws {
        let data = try Data(contentsOf: url)
        let preset = try JSONDecoder().decode(PluginPreset.self, from: data)

        for (parameterId, value) in preset.parameters {
            setParameter(pluginId: pluginId, parameterId: parameterId, value: value)
        }
    }

    // MARK: - Cache Management

    private func loadPluginCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode([String: PluginDescription].self, from: data) else {
            return
        }
        pluginCache = cached
    }

    private func savePluginCache() {
        guard let data = try? JSONEncoder().encode(pluginCache) else { return }
        try? data.write(to: cacheURL)
    }

    // MARK: - Helpers

    #if canImport(AudioToolbox)
    private func auTypeToPluginType(_ type: OSType) -> PluginType {
        switch type {
        case kAudioUnitType_Effect, kAudioUnitType_MusicEffect:
            return .effect
        case kAudioUnitType_MusicDevice:
            return .instrument
        case kAudioUnitType_Generator:
            return .generator
        default:
            return .effect
        }
    }

    private func auTypeFromPluginType(_ type: PluginType) -> OSType {
        switch type {
        case .effect:
            return kAudioUnitType_Effect
        case .instrument:
            return kAudioUnitType_MusicDevice
        case .generator:
            return kAudioUnitType_Generator
        case .analyzer:
            return kAudioUnitType_Effect
        }
    }

    private func categoryForAUType(_ type: OSType) -> PluginCategory {
        switch type {
        case kAudioUnitType_Effect:
            return .dynamics
        case kAudioUnitType_MusicDevice:
            return .synthesizer
        default:
            return .other
        }
    }
    #endif

    private func fourCharCodeToString(_ code: UInt32) -> String {
        let chars = [
            Character(UnicodeScalar((code >> 24) & 0xFF)!),
            Character(UnicodeScalar((code >> 16) & 0xFF)!),
            Character(UnicodeScalar((code >> 8) & 0xFF)!),
            Character(UnicodeScalar(code & 0xFF)!)
        ]
        return String(chars)
    }

    private func stringToFourCharCode(_ string: String) -> UInt32 {
        var result: UInt32 = 0
        for (i, char) in string.prefix(4).enumerated() {
            result |= UInt32(char.asciiValue ?? 0) << (24 - i * 8)
        }
        return result
    }
}

// MARK: - Plugin Types

public struct PluginDescription: Codable, Identifiable {
    public var id: String { identifier }

    public let identifier: String
    public let name: String
    public let manufacturer: String
    public let version: String
    public let type: PluginType
    public let format: PluginFormat
    public let category: PluginCategory
    public let inputChannels: Int
    public let outputChannels: Int
}

public enum PluginType: String, Codable {
    case effect
    case instrument
    case generator
    case analyzer
}

public enum PluginFormat: String, Codable {
    case audioUnit
    case auv3
    case vst3
}

public enum PluginCategory: String, Codable, CaseIterable {
    case equalizer
    case dynamics
    case reverb
    case delay
    case modulation
    case distortion
    case filter
    case synthesizer
    case sampler
    case analyzer
    case other
}

public struct LoadedPlugin {
    public let description: PluginDescription
    public var audioUnit: AVAudioUnit?
    public var parameters: [PluginParameter]
}

public struct PluginParameter: Identifiable {
    public var id: String { identifier }

    public let identifier: String
    public let name: String
    public var value: Float
    public let minValue: Float
    public let maxValue: Float
    public let defaultValue: Float
    public let unit: String
}

public struct PluginPreset: Codable {
    public let name: String
    public let pluginId: String
    public let parameters: [(String, Float)]

    enum CodingKeys: String, CodingKey {
        case name, pluginId, parameters
    }

    public init(name: String, pluginId: String, parameters: [(String, Float)]) {
        self.name = name
        self.pluginId = pluginId
        self.parameters = parameters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        pluginId = try container.decode(String.self, forKey: .pluginId)

        let paramArray = try container.decode([[String: Float]].self, forKey: .parameters)
        parameters = paramArray.compactMap { dict in
            guard let key = dict.keys.first, let value = dict[key] else { return nil }
            return (key, value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(pluginId, forKey: .pluginId)

        let paramArray = parameters.map { [$0.0: $0.1] }
        try container.encode(paramArray, forKey: .parameters)
    }
}

// MARK: - Errors

public enum PluginError: Error {
    case pluginNotFound
    case invalidIdentifier
    case instantiationFailed
    case pluginNotLoaded
    case formatNotSupported
    case platformNotSupported
    case bufferCreationFailed
    case renderFailed(OSStatus)
    case presetNotFound
}

// MARK: - Plugin Chain

public class PluginChain: ObservableObject {
    @Published public var plugins: [String] = []

    private let host = AUv3PluginHost.shared

    public init() {}

    /// Add plugin to chain
    public func add(_ pluginId: String) async throws {
        _ = try await host.loadPlugin(pluginId)
        plugins.append(pluginId)
    }

    /// Remove plugin from chain
    public func remove(at index: Int) {
        guard index < plugins.count else { return }
        let pluginId = plugins[index]
        host.unloadPlugin(pluginId)
        plugins.remove(at: index)
    }

    /// Move plugin in chain
    public func move(from: Int, to: Int) {
        let plugin = plugins.remove(at: from)
        plugins.insert(plugin, at: to)
    }

    /// Process through chain
    public func process(_ buffer: AVAudioPCMBuffer) async throws -> AVAudioPCMBuffer {
        var currentBuffer = buffer

        for pluginId in plugins {
            currentBuffer = try await host.process(pluginId, buffer: currentBuffer)
        }

        return currentBuffer
    }
}

// MARK: - Plugin Browser

public struct PluginBrowser {
    public static func filter(
        plugins: [PluginDescription],
        type: PluginType? = nil,
        format: PluginFormat? = nil,
        category: PluginCategory? = nil,
        search: String = ""
    ) -> [PluginDescription] {
        var filtered = plugins

        if let type = type {
            filtered = filtered.filter { $0.type == type }
        }

        if let format = format {
            filtered = filtered.filter { $0.format == format }
        }

        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }

        if !search.isEmpty {
            let lowercased = search.lowercased()
            filtered = filtered.filter {
                $0.name.lowercased().contains(lowercased) ||
                $0.manufacturer.lowercased().contains(lowercased)
            }
        }

        return filtered
    }

    public static func groupByManufacturer(_ plugins: [PluginDescription]) -> [String: [PluginDescription]] {
        Dictionary(grouping: plugins, by: { $0.manufacturer })
    }

    public static func groupByCategory(_ plugins: [PluginDescription]) -> [PluginCategory: [PluginDescription]] {
        Dictionary(grouping: plugins, by: { $0.category })
    }
}
