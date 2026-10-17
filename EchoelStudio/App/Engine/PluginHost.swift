import AVFoundation
import CoreAudioKit
import UIKit
import EchoelCore
import EchoelEngine
import Observation
import os

/// The installed Audio Units, and the loaded unit of every track instrument and insert that
/// names one. Loading is asynchronous; a unit still loading, or that cannot load on this device,
/// stays silent and the page that shows it says why. A unit reaches the engine only once its
/// render resources are allocated at the engine's sample rate.
///
/// Lifetime: a unit that is replaced or no longer wanted is dropped here, and the engine drops
/// it with the next snapshot. The last reference goes when the main thread frees the snapshot
/// the render thread has moved past — never while a render call can still reach it.
@MainActor
@Observable
final class PluginHost {
    /// 'Echo' — this app's own components are never hosted inside it.
    nonisolated static let ownManufacturer: UInt32 = 0x4563_686F

    /// What a loaded unit plays: a track's instrument, or one insert on a track's chain.
    enum Slot: Hashable {
        case instrument(TrackID)
        case insert(InsertID)
    }

    private(set) var instruments: [PluginComponent] = []
    private(set) var effects: [PluginComponent] = []
    /// Why a unit does not play; absent while it plays or loads.
    private(set) var problems: [Slot: String] = [:]
    private(set) var loading: Set<Slot> = []
    /// Changes whenever the loaded units do; observe this, not the units.
    private(set) var revision = 0

    @ObservationIgnored private(set) var units: [TrackID: HostedUnit] = [:]
    /// Each track's loaded, active inserts in chain order, for the engine.
    @ObservationIgnored private(set) var chains: [TrackID: [HostedEffect]] = [:]
    /// Called when a unit finished loading, so the engine republishes with it. `sync` does not
    /// call it: its caller publishes anyway.
    @ObservationIgnored var onUnitsChanged: (() -> Void)?
    @ObservationIgnored private var loaded: [Slot: Loaded] = [:]
    @ObservationIgnored private var requests: [Slot: Request] = [:]
    @ObservationIgnored private var failed: [Slot: PluginComponent] = [:]
    /// The saved state each loaded unit was last brought in line with — applied on load or after
    /// an undo, or captured from the unit. A song whose state differs gets it applied.
    @ObservationIgnored private var syncedState: [Slot: Data] = [:]
    @ObservationIgnored private var requestCount = 0
    @ObservationIgnored private var registrationObserver: NSObjectProtocol?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "plugins")

    private struct Loaded {
        let component: PluginComponent
        let sampleRate: Double
        let unit: AUAudioUnit
        let instrument: HostedUnit?
        let effect: HostedEffect?
    }

    private struct Request {
        let component: PluginComponent
        let sampleRate: Double
        let number: Int
    }

    /// What the song wants loaded in one slot.
    private struct Wanted {
        let component: PluginComponent
        let state: Data?
    }

    /// Carries a loaded unit across the completion handler's thread hop; it is touched only on
    /// the main actor after the hop.
    private final class UnitBox: @unchecked Sendable {
        let unit: AUAudioUnit?
        init(_ unit: AUAudioUnit?) { self.unit = unit }
    }

    init() {
        refreshCatalog()
        registrationObserver = NotificationCenter.default.addObserver(
            forName: AVAudioUnitComponentManager.registrationsChangedNotification, object: nil, queue: .main
        ) { @Sendable [weak self] _ in
            Task { @MainActor in self?.refreshCatalog() }
        }
    }

    /// Re-reads the installed units, off the main thread: the system may scan for them.
    func refreshCatalog() {
        Task {
            let found = await Task.detached(priority: .utility) {
                (Self.installed(kAudioUnitType_MusicDevice), Self.installed(kAudioUnitType_Effect))
            }.value
            instruments = found.0
            effects = found.1
        }
    }

    nonisolated private static func installed(_ type: OSType) -> [PluginComponent] {
        let query = AudioComponentDescription(componentType: type, componentSubType: 0, componentManufacturer: 0,
                                              componentFlags: 0, componentFlagsMask: 0)
        return AVAudioUnitComponentManager.shared().components(matching: query)
            .filter { $0.audioComponentDescription.componentManufacturer != ownManufacturer }
            .map { component in
                let description = component.audioComponentDescription
                return PluginComponent(type: description.componentType, subtype: description.componentSubType,
                                       manufacturer: description.componentManufacturer, name: component.name,
                                       manufacturerName: component.manufacturerName)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Brings the loaded units in line with the song at the engine's sample rate: loads what is
    /// wanted, drops what is not, reloads a unit whose plugin or rate changed, and rebuilds the
    /// chains the engine plays.
    func sync(_ project: Project, sampleRate: Double) {
        guard sampleRate > 0, sampleRate.isFinite else { return }
        var wanted: [Slot: Wanted] = [:]
        for track in project.tracks {
            if track.kind == .instrument, track.instrument.device == .plugin, let plugin = track.instrument.plugin {
                wanted[.instrument(track.id)] = Wanted(component: plugin, state: track.instrument.pluginState)
            }
            for insert in track.inserts {
                wanted[.insert(insert.id)] = Wanted(component: insert.plugin, state: insert.state)
            }
        }
        var changed = false
        for (slot, entry) in loaded where wanted[slot]?.component != entry.component || entry.sampleRate != sampleRate {
            loaded[slot] = nil
            syncedState[slot] = nil
            changed = true
        }
        for (slot, request) in requests where wanted[slot]?.component != request.component || request.sampleRate != sampleRate {
            requests[slot] = nil
            loading.remove(slot)
        }
        failed = failed.filter { wanted[$0.key]?.component == $0.value }
        problems = problems.filter { failed[$0.key] != nil }
        // An undo or a reopened song can carry other settings than the loaded unit has.
        for (slot, entry) in loaded {
            guard let state = wanted[slot]?.state, state != syncedState[slot] else { continue }
            Self.apply(state, to: entry.unit)
            syncedState[slot] = state
        }
        for (slot, want) in wanted where loaded[slot] == nil && requests[slot] == nil && failed[slot] != want.component {
            load(want.component, for: slot, state: want.state, sampleRate: sampleRate)
        }
        rebuild(project)
        if changed { revision += 1 }
    }

    /// What the engine reads: each plugin track's instrument, each track's active inserts in order.
    private func rebuild(_ project: Project) {
        var instruments: [TrackID: HostedUnit] = [:]
        var chains: [TrackID: [HostedEffect]] = [:]
        for track in project.tracks {
            if let unit = loaded[.instrument(track.id)]?.instrument { instruments[track.id] = unit }
            let chain = track.inserts.filter { !$0.isBypassed }.compactMap { loaded[.insert($0.id)]?.effect }
            if !chain.isEmpty { chains[track.id] = chain }
        }
        units = instruments
        self.chains = chains
    }

    private func load(_ component: PluginComponent, for slot: Slot, state: Data?, sampleRate: Double) {
        requestCount += 1
        let number = requestCount
        requests[slot] = Request(component: component, sampleRate: sampleRate, number: number)
        loading.insert(slot)
        log.info("plugin: load \(component.name, privacy: .public)")
        let description = AudioComponentDescription(componentType: component.type, componentSubType: component.subtype,
                                                    componentManufacturer: component.manufacturer, componentFlags: 0,
                                                    componentFlagsMask: 0)
        AUAudioUnit.instantiate(with: description, options: []) { @Sendable [weak self] unit, error in
            let box = UnitBox(unit)
            let failure = error.map { $0.localizedDescription }
            Task { @MainActor in self?.finish(box.unit, failure: failure, slot: slot, number: number, state: state) }
        }
    }

    private func finish(_ unit: AUAudioUnit?, failure: String?, slot: Slot, number: Int, state: Data?) {
        // An answer to a request that was replaced or withdrawn changes nothing.
        guard let request = requests[slot], request.number == number else { return }
        requests[slot] = nil
        loading.remove(slot)
        guard let unit else {
            fail(slot, request.component, reason: "\(request.component.name) is not installed on this device.", detail: failure)
            return
        }
        let isEffect: Bool
        if case .insert = slot { isEffect = true } else { isEffect = false }
        do {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: request.sampleRate, channels: 2),
                  unit.outputBusses.count > 0 else {
                throw HostError.noOutput
            }
            try unit.outputBusses[0].setFormat(format)
            if isEffect {
                guard unit.inputBusses.count > 0 else { throw HostError.noInput }
                try unit.inputBusses[0].setFormat(format)
            }
            unit.maximumFramesToRender = AUAudioFrameCount(EngineCore.maximumFrames)
            if let state { Self.apply(state, to: unit) }
            log.info("plugin: allocate \(request.component.name, privacy: .public)")
            try unit.allocateRenderResources()
        } catch {
            fail(slot, request.component, reason: "\(request.component.name) cannot play in stereo at this rate.",
                 detail: error.localizedDescription)
            return
        }
        let rate = request.sampleRate, frames = EngineCore.maximumFrames
        loaded[slot] = Loaded(
            component: request.component, sampleRate: rate, unit: unit,
            instrument: isEffect ? nil : HostedUnit(render: unit.renderBlock, scheduleMIDI: unit.scheduleMIDIEventBlock,
                                                    sampleRate: rate, maximumFrames: frames, owner: unit),
            effect: isEffect ? HostedEffect(render: unit.renderBlock, sampleRate: rate, maximumFrames: frames, owner: unit) : nil)
        syncedState[slot] = state
        problems[slot] = nil
        revision += 1
        // The chains are rebuilt from the song when the engine republishes.
        onUnitsChanged?()
    }

    /// Not retried until the slot names another plugin: every retry would load and fail again.
    private func fail(_ slot: Slot, _ component: PluginComponent, reason: String, detail: String?) {
        log.error("plugin: \(component.name, privacy: .public) failed — \(detail ?? "", privacy: .public)")
        failed[slot] = component
        problems[slot] = reason
    }

    func isLoaded(_ slot: Slot) -> Bool { loaded[slot] != nil }

    private static func apply(_ state: Data, to unit: AUAudioUnit) {
        guard let settings = try? PropertyListSerialization.propertyList(from: state, format: nil) as? [String: Any]
        else { return }
        unit.fullStateForDocument = settings
    }

    /// The commands that store every loaded unit's current settings in the song, for the units
    /// whose settings changed since they were last stored — all of them, or the one `only` names.
    /// Empty when nothing changed.
    func captureCommands(for project: Project, only: Slot? = nil) -> [Command] {
        var commands: [Command] = []
        for track in project.tracks {
            if let command = capture(.instrument(track.id), stored: track.instrument.pluginState, only: only,
                                     make: { .setPluginState(track.id, $0) }) {
                commands.append(command)
            }
            for insert in track.inserts {
                if let command = capture(.insert(insert.id), stored: insert.state, only: only,
                                         make: { .setInsertState(track: track.id, insert.id, $0) }) {
                    commands.append(command)
                }
            }
        }
        return commands
    }

    private func capture(_ slot: Slot, stored: Data?, only: Slot?, make: (Data) -> Command) -> Command? {
        guard only == nil || only == slot, let settings = loaded[slot]?.unit.fullStateForDocument,
              let data = try? PropertyListSerialization.data(fromPropertyList: settings, format: .binary, options: 0),
              data.count <= PluginComponent.maximumStateBytes, data != stored else { return nil }
        syncedState[slot] = data
        return make(data)
    }

    /// The plugin's own interface, or nil when it has none or its unit is not loaded.
    func interface(for slot: Slot) async -> UIViewController? {
        guard let unit = loaded[slot]?.unit else { return nil }
        return await withCheckedContinuation { continuation in
            unit.requestViewController { @Sendable controller in
                let box = ControllerBox(controller)
                Task { @MainActor in continuation.resume(returning: box.controller) }
            }
        }
    }

    /// Carries the plugin's view controller across the completion handler's thread hop.
    private final class ControllerBox: @unchecked Sendable {
        let controller: UIViewController?
        init(_ controller: UIViewController?) { self.controller = controller }
    }

    enum HostError: Error { case noOutput, noInput }
}
