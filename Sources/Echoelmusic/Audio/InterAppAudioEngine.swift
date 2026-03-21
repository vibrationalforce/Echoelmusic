// InterAppAudioEngine.swift
// Echoelmusic — AUv3 Plugin Hosting Engine
//
// Discovers, instantiates, and routes AUv3 audio unit plugins
// (instruments + effects) within the AVAudioEngine node graph.
// Uses the modern AudioComponentDescription / AVAudioUnitComponentManager API.
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Observation

#if canImport(CoreAudioTypes)
import CoreAudioTypes
#endif

#if canImport(AudioToolbox)
import AudioToolbox
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - HostedPlugin

/// Represents a single AUv3 plugin hosted within the audio engine node graph.
public struct HostedPlugin: Identifiable, Sendable {
    /// Stable identifier for this hosted instance
    public let id: UUID

    /// Human-readable name reported by the audio component
    public let name: String

    /// Manufacturer name reported by the audio component
    public let manufacturer: String

    /// The AudioComponentDescription used to instantiate this plugin
    public let componentDescription: AudioComponentDescription

    /// Whether this plugin is an instrument (true) or effect (false)
    public let isInstrument: Bool

    /// Index in the hosted plugin chain (0 = first in chain)
    public let chainIndex: Int

    public init(
        id: UUID = UUID(),
        name: String,
        manufacturer: String,
        componentDescription: AudioComponentDescription,
        isInstrument: Bool,
        chainIndex: Int
    ) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.componentDescription = componentDescription
        self.isInstrument = isInstrument
        self.chainIndex = chainIndex
    }
}

// MARK: - DiscoveredPlugin

/// A plugin discovered via AVAudioUnitComponentManager but not yet instantiated.
public struct DiscoveredPlugin: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let manufacturer: String
    public let componentDescription: AudioComponentDescription
    public let isInstrument: Bool
    public let version: UInt32

    public init(
        name: String,
        manufacturer: String,
        componentDescription: AudioComponentDescription,
        isInstrument: Bool,
        version: UInt32
    ) {
        self.id = UUID()
        self.name = name
        self.manufacturer = manufacturer
        self.componentDescription = componentDescription
        self.isInstrument = isInstrument
        self.version = version
    }
}

// MARK: - InterAppAudioEngine

/// AUv3 plugin hosting engine for discovering, instantiating, and routing
/// third-party Audio Unit plugins through the AVAudioEngine node graph.
///
/// Supports both instrument (kAudioUnitType_MusicDevice) and effect
/// (kAudioUnitType_Effect) plugins. Plugins are chained in insertion order:
///
/// ```
/// input → [plugin 0] → [plugin 1] → ... → [plugin N] → output
/// ```
///
/// Plugin state can be saved/restored via `fullState` dictionaries for
/// session persistence.
@preconcurrency @MainActor
@Observable
public final class InterAppAudioEngine {

    // MARK: - Singleton

    /// Shared instance for app-wide AUv3 hosting
    @MainActor static let shared = InterAppAudioEngine()

    // MARK: - Observed Properties

    /// All AUv3 plugins discovered on this device
    var discoveredPlugins: [DiscoveredPlugin] = []

    /// Currently hosted (instantiated) plugins in the audio chain
    var hostedPlugins: [HostedPlugin] = []

    /// Raw AudioComponentDescriptions from the latest scan
    var availablePlugins: [AudioComponentDescription] = []

    /// Whether a plugin scan is currently in progress
    var isScanning: Bool = false

    /// Whether the plugin chain is actively routing audio
    var isRouting: Bool = false

    /// Last error message for UI display
    var lastError: String?

    // MARK: - Internal State

    /// Live AVAudioUnit nodes keyed by HostedPlugin.id
    @ObservationIgnored
    private var audioUnitNodes: [UUID: AVAudioUnit] = [:]

    /// Saved plugin states keyed by HostedPlugin.id
    @ObservationIgnored
    private var savedStates: [UUID: [String: Any]] = [:]

    /// The AVAudioEngine this plugin chain is attached to (set via routeAudio)
    @ObservationIgnored
    private weak var attachedEngine: AVAudioEngine?

    /// Mixer node inserted before the plugin chain for level control
    @ObservationIgnored
    private var inputMixer: AVAudioMixerNode?

    // MARK: - Init

    private init() {
        log.info("InterAppAudioEngine initialized", category: .audio)
    }

    // MARK: - Plugin Discovery

    /// Scans the device for all available AUv3 instrument and effect plugins
    /// using AVAudioUnitComponentManager.
    ///
    /// Results are published to `discoveredPlugins` and `availablePlugins`.
    /// Safe to call multiple times; each scan replaces previous results.
    func scanForPlugins() {
        guard !isScanning else {
            log.warning("Plugin scan already in progress, skipping", category: .audio)
            return
        }

        isScanning = true
        lastError = nil
        log.info("Starting AUv3 plugin scan", category: .audio)

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isScanning = false }

            let manager = AVAudioUnitComponentManager.shared()

            // Discover instruments (kAudioUnitType_MusicDevice)
            let instrumentDesc = AudioComponentDescription(
                componentType: kAudioUnitType_MusicDevice,
                componentSubType: 0,
                componentManufacturer: 0,
                componentFlags: 0,
                componentFlagsMask: 0
            )
            let instruments = manager.components(matching: instrumentDesc)

            // Discover effects (kAudioUnitType_Effect)
            let effectDesc = AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: 0,
                componentManufacturer: 0,
                componentFlags: 0,
                componentFlagsMask: 0
            )
            let effects = manager.components(matching: effectDesc)

            // Discover music effects (kAudioUnitType_MusicEffect)
            let musicEffectDesc = AudioComponentDescription(
                componentType: kAudioUnitType_MusicEffect,
                componentSubType: 0,
                componentManufacturer: 0,
                componentFlags: 0,
                componentFlagsMask: 0
            )
            let musicEffects = manager.components(matching: musicEffectDesc)

            var discovered: [DiscoveredPlugin] = []
            var descriptions: [AudioComponentDescription] = []

            for component in instruments {
                let desc = component.audioComponentDescription
                descriptions.append(desc)
                discovered.append(DiscoveredPlugin(
                    name: component.name,
                    manufacturer: component.manufacturerName,
                    componentDescription: desc,
                    isInstrument: true,
                    version: component.version
                ))
            }

            for component in effects + musicEffects {
                let desc = component.audioComponentDescription
                descriptions.append(desc)
                discovered.append(DiscoveredPlugin(
                    name: component.name,
                    manufacturer: component.manufacturerName,
                    componentDescription: desc,
                    isInstrument: false,
                    version: component.version
                ))
            }

            self.discoveredPlugins = discovered
            self.availablePlugins = descriptions

            log.info(
                "Plugin scan complete — \(instruments.count) instruments, "
                + "\(effects.count + musicEffects.count) effects",
                category: .audio
            )
        }
    }

    // MARK: - Plugin Hosting

    /// Instantiates an AUv3 plugin from its AudioComponentDescription and
    /// adds it to the hosted plugin chain.
    ///
    /// The plugin is appended at the end of the current chain. If the engine
    /// is already routing, the node graph is rebuilt automatically.
    ///
    /// - Parameter description: The AudioComponentDescription identifying the plugin.
    /// - Returns: The `HostedPlugin` metadata on success, or nil on failure.
    @discardableResult
    func hostPlugin(description: AudioComponentDescription) async -> HostedPlugin? {
        lastError = nil

        let isInstrument = description.componentType == kAudioUnitType_MusicDevice

        log.info(
            "Instantiating AUv3 plugin — type: \(isInstrument ? "instrument" : "effect")",
            category: .audio
        )

        do {
            let audioUnit = try await AVAudioUnit.instantiate(
                with: description,
                options: .loadOutOfProcess
            )

            guard let auAudioUnit = audioUnit.auAudioUnit as AUAudioUnit? else {
                log.error("Failed to obtain AUAudioUnit from instantiated AVAudioUnit", category: .audio)
                lastError = "Failed to access audio unit interface"
                return nil
            }

            let componentName = auAudioUnit.componentName ?? "Unknown Plugin"
            let manufacturerName = auAudioUnit.manufacturerName ?? "Unknown"

            let pluginID = UUID()
            let chainIndex = hostedPlugins.count

            let hosted = HostedPlugin(
                id: pluginID,
                name: componentName,
                manufacturer: manufacturerName,
                componentDescription: description,
                isInstrument: isInstrument,
                chainIndex: chainIndex
            )

            audioUnitNodes[pluginID] = audioUnit
            hostedPlugins.append(hosted)

            log.info(
                "Hosted plugin: \(componentName) by \(manufacturerName) at chain index \(chainIndex)",
                category: .audio
            )

            // Rebuild routing if engine is attached
            if let engine = attachedEngine {
                rebuildNodeGraph(engine: engine)
            }

            return hosted
        } catch {
            log.error("Failed to instantiate AUv3 plugin: \(error.localizedDescription)", category: .audio)
            lastError = "Plugin instantiation failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Removes a hosted plugin by its identifier and rebuilds the node graph.
    ///
    /// - Parameter id: The UUID of the hosted plugin to remove.
    /// - Returns: True if the plugin was found and removed.
    @discardableResult
    func removePlugin(id: UUID) -> Bool {
        guard let index = hostedPlugins.firstIndex(where: { $0.id == id }) else {
            log.warning("Cannot remove plugin — ID not found: \(id)", category: .audio)
            return false
        }

        let plugin = hostedPlugins[index]

        // Detach from engine before removing
        if let engine = attachedEngine, let node = audioUnitNodes[id] {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }

        audioUnitNodes.removeValue(forKey: id)
        savedStates.removeValue(forKey: id)
        hostedPlugins.remove(at: index)

        // Reindex chain positions
        for i in hostedPlugins.indices {
            let old = hostedPlugins[i]
            hostedPlugins[i] = HostedPlugin(
                id: old.id,
                name: old.name,
                manufacturer: old.manufacturer,
                componentDescription: old.componentDescription,
                isInstrument: old.isInstrument,
                chainIndex: i
            )
        }

        log.info("Removed plugin: \(plugin.name) from chain", category: .audio)

        // Rebuild routing
        if let engine = attachedEngine {
            rebuildNodeGraph(engine: engine)
        }

        return true
    }

    // MARK: - Audio Routing

    /// Attaches the hosted plugin chain to an AVAudioEngine and builds the
    /// node graph for audio routing.
    ///
    /// Routing topology:
    /// ```
    /// engine.inputNode → inputMixer → [plugin 0] → ... → [plugin N] → engine.mainMixerNode
    /// ```
    ///
    /// - Parameter engine: The AVAudioEngine to attach plugins to.
    func routeAudio(engine: AVAudioEngine) {
        attachedEngine = engine
        rebuildNodeGraph(engine: engine)
        isRouting = true
        log.info("Audio routing established with \(hostedPlugins.count) plugins", category: .audio)
    }

    /// Detaches all hosted plugin nodes from the engine without removing
    /// the plugins from the chain. Call `routeAudio` again to reattach.
    func detachFromEngine() {
        guard let engine = attachedEngine else { return }

        for (_, node) in audioUnitNodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }

        if let mixer = inputMixer {
            engine.disconnectNodeOutput(mixer)
            engine.detach(mixer)
            inputMixer = nil
        }

        attachedEngine = nil
        isRouting = false
        log.info("Detached plugin chain from audio engine", category: .audio)
    }

    /// Rebuilds the internal node graph connecting all hosted plugins in chain order.
    private func rebuildNodeGraph(engine: AVAudioEngine) {
        // Disconnect existing nodes
        for (_, node) in audioUnitNodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }

        if let mixer = inputMixer {
            engine.disconnectNodeOutput(mixer)
            engine.detach(mixer)
        }

        guard !hostedPlugins.isEmpty else {
            isRouting = false
            return
        }

        // Create input mixer for level control
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)
        inputMixer = mixer

        let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)

        guard outputFormat.sampleRate > 0, outputFormat.channelCount > 0 else {
            log.error("Invalid output format — sampleRate or channelCount is zero", category: .audio)
            return
        }

        // Attach all plugin nodes
        let sortedPlugins = hostedPlugins.sorted { $0.chainIndex < $1.chainIndex }
        var orderedNodes: [AVAudioNode] = []

        for plugin in sortedPlugins {
            guard let node = audioUnitNodes[plugin.id] else {
                log.warning("Missing AVAudioUnit node for plugin: \(plugin.name)", category: .audio)
                continue
            }
            engine.attach(node)
            orderedNodes.append(node)
        }

        guard !orderedNodes.isEmpty else {
            log.warning("No valid nodes to route", category: .audio)
            return
        }

        // Wire: input → mixer → [plugin chain] → mainMixer
        engine.connect(engine.inputNode, to: mixer, format: outputFormat)

        var previousNode: AVAudioNode = mixer

        for node in orderedNodes {
            engine.connect(previousNode, to: node, format: outputFormat)
            previousNode = node
        }

        engine.connect(previousNode, to: engine.mainMixerNode, format: outputFormat)

        log.info(
            "Node graph rebuilt — \(orderedNodes.count) plugins in chain",
            category: .audio
        )
    }

    // MARK: - Plugin State Persistence

    /// Saves the current state (fullState) of a hosted plugin for later restoration.
    ///
    /// - Parameter id: The UUID of the hosted plugin.
    /// - Returns: The state dictionary, or nil if the plugin was not found.
    @discardableResult
    func savePluginState(id: UUID) -> [String: Any]? {
        guard let node = audioUnitNodes[id] else {
            log.warning("Cannot save state — plugin not found: \(id)", category: .audio)
            return nil
        }

        guard let state = node.auAudioUnit.fullState else {
            log.warning("Plugin returned nil fullState: \(id)", category: .audio)
            return nil
        }

        savedStates[id] = state

        let pluginName = hostedPlugins.first(where: { $0.id == id })?.name ?? "unknown"
        log.info("Saved state for plugin: \(pluginName) (\(state.count) keys)", category: .audio)
        return state
    }

    /// Restores a previously saved state to a hosted plugin.
    ///
    /// - Parameters:
    ///   - id: The UUID of the hosted plugin.
    ///   - state: The fullState dictionary to restore. If nil, uses the last saved state.
    /// - Returns: True if the state was restored successfully.
    @discardableResult
    func loadPluginState(id: UUID, state: [String: Any]? = nil) -> Bool {
        guard let node = audioUnitNodes[id] else {
            log.warning("Cannot load state — plugin not found: \(id)", category: .audio)
            return false
        }

        guard let stateToLoad = state ?? savedStates[id] else {
            log.warning("No saved state available for plugin: \(id)", category: .audio)
            return false
        }

        node.auAudioUnit.fullState = stateToLoad

        let pluginName = hostedPlugins.first(where: { $0.id == id })?.name ?? "unknown"
        log.info("Restored state for plugin: \(pluginName)", category: .audio)
        return true
    }

    /// Saves all hosted plugin states and returns them keyed by plugin ID string.
    func saveAllPluginStates() -> [String: [String: Any]] {
        var allStates: [String: [String: Any]] = [:]
        for plugin in hostedPlugins {
            if let state = savePluginState(id: plugin.id) {
                allStates[plugin.id.uuidString] = state
            }
        }
        log.info("Saved states for \(allStates.count)/\(hostedPlugins.count) plugins", category: .audio)
        return allStates
    }

    // MARK: - Parameter Observation

    /// Returns the AUParameterTree for a hosted plugin, enabling real-time
    /// parameter observation and control.
    ///
    /// - Parameter id: The UUID of the hosted plugin.
    /// - Returns: The parameter tree, or nil if the plugin was not found.
    func parameterTree(for id: UUID) -> AUParameterTree? {
        guard let node = audioUnitNodes[id] else {
            log.warning("Cannot access parameter tree — plugin not found: \(id)", category: .audio)
            return nil
        }
        return node.auAudioUnit.parameterTree
    }

    /// Observes all parameter changes on a hosted plugin via the AUParameterTree
    /// observer token mechanism.
    ///
    /// - Parameters:
    ///   - id: The UUID of the hosted plugin.
    ///   - handler: Callback invoked on parameter changes with address and value.
    /// - Returns: An opaque observer token, or nil if the plugin was not found.
    ///   Caller must retain this token for the observation lifetime.
    func observeParameters(
        for id: UUID,
        handler: @escaping @Sendable (AUParameterAddress, AUValue) -> Void
    ) -> AUParameterObserverToken? {
        guard let tree = parameterTree(for: id) else { return nil }

        let token = tree.token(byAddingParameterObserver: { address, value in
            handler(address, value)
        })

        let pluginName = hostedPlugins.first(where: { $0.id == id })?.name ?? "unknown"
        log.info("Parameter observation started for: \(pluginName)", category: .audio)
        return token
    }

    /// Sets a parameter value on a hosted plugin.
    ///
    /// - Parameters:
    ///   - id: The UUID of the hosted plugin.
    ///   - address: The parameter address to set.
    ///   - value: The new value.
    ///   - originator: Optional observer token to prevent feedback loops.
    func setParameter(
        for id: UUID,
        address: AUParameterAddress,
        value: AUValue,
        originator: AUParameterObserverToken? = nil
    ) {
        guard let tree = parameterTree(for: id) else { return }
        guard let param = tree.parameter(withAddress: address) else {
            log.warning("Parameter address \(address) not found on plugin: \(id)", category: .audio)
            return
        }
        param.setValue(value, originator: originator)
    }

    // MARK: - Plugin UI

    #if canImport(UIKit)
    /// Requests the AUViewController for a hosted plugin's custom UI.
    ///
    /// AUv3 plugins may provide a custom view controller for parameter editing.
    /// This method asynchronously requests it from the audio unit.
    ///
    /// - Parameter id: The UUID of the hosted plugin.
    /// - Returns: The plugin's view controller, or nil if unavailable.
    func requestPluginViewController(for id: UUID) async -> UIViewController? {
        guard let node = audioUnitNodes[id] else {
            log.warning("Cannot request UI — plugin not found: \(id)", category: .audio)
            return nil
        }

        return await withCheckedContinuation { continuation in
            node.auAudioUnit.requestViewController { viewController in
                if let vc = viewController {
                    log.info("Plugin UI loaded for: \(node.auAudioUnit.componentName ?? "unknown")", category: .audio)
                    continuation.resume(returning: vc)
                } else {
                    log.info("Plugin provides no custom UI: \(node.auAudioUnit.componentName ?? "unknown")", category: .audio)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    #endif

    // MARK: - Utility

    /// Returns the AVAudioUnit node for a hosted plugin, if it exists.
    ///
    /// Useful for advanced routing or direct AUAudioUnit access.
    ///
    /// - Parameter id: The UUID of the hosted plugin.
    /// - Returns: The AVAudioUnit node, or nil.
    func audioUnit(for id: UUID) -> AVAudioUnit? {
        return audioUnitNodes[id]
    }

    /// Removes all hosted plugins and detaches from the engine.
    func removeAllPlugins() {
        detachFromEngine()
        audioUnitNodes.removeAll()
        savedStates.removeAll()
        hostedPlugins.removeAll()
        log.info("All hosted plugins removed", category: .audio)
    }

    /// Returns the total number of parameters across all hosted plugins.
    var totalParameterCount: Int {
        var count = 0
        for (_, node) in audioUnitNodes {
            count += node.auAudioUnit.parameterTree?.allParameters.count ?? 0
        }
        return count
    }
}

// MARK: - AudioComponentDescription + Sendable

extension AudioComponentDescription: @retroactive @unchecked Sendable {}

#endif // canImport(AVFoundation)
