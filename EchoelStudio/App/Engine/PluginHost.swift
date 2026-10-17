import AVFoundation
import EchoelCore
import EchoelEngine
import Observation
import os

/// The installed Audio Unit instruments, and the loaded unit of every track that plays one.
/// Loading is asynchronous; a track whose unit is still loading, or cannot be loaded on this
/// device, stays silent and its Sound page says why. A unit is handed to the engine only once
/// its render resources are allocated at the engine's sample rate.
///
/// Lifetime: a unit that is replaced or no longer wanted is dropped here, and the engine drops
/// it with the next snapshot. The last reference goes when the main thread frees the snapshot
/// the render thread has moved past — never while a render call can still reach it.
@MainActor
@Observable
final class PluginHost {
    /// 'Echo' — this app's own components are never hosted inside it.
    static let ownManufacturer: UInt32 = 0x4563_686F

    private(set) var instruments: [PluginComponent] = []
    /// Why a track's plugin does not play; nil while it plays or loads.
    private(set) var problems: [TrackID: String] = [:]
    private(set) var loadingTracks: Set<TrackID> = []
    /// Changes whenever `units` does; observe this, not the units.
    private(set) var revision = 0

    @ObservationIgnored private(set) var units: [TrackID: HostedUnit] = [:]
    /// Called when a unit finished loading, so the engine republishes with it. `sync` does not
    /// call it: its caller publishes anyway.
    @ObservationIgnored var onUnitsChanged: (() -> Void)?
    @ObservationIgnored private var loaded: [TrackID: Loaded] = [:]
    @ObservationIgnored private var requests: [TrackID: Request] = [:]
    @ObservationIgnored private var failed: [TrackID: PluginComponent] = [:]
    @ObservationIgnored private var requestCount = 0
    @ObservationIgnored private var registrationObserver: NSObjectProtocol?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "plugins")

    private struct Loaded {
        let component: PluginComponent
        let sampleRate: Double
        let unit: AUAudioUnit
    }

    private struct Request {
        let component: PluginComponent
        let sampleRate: Double
        let number: Int
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

    /// Re-reads the installed instruments, off the main thread: the system may scan for them.
    func refreshCatalog() {
        Task {
            let found = await Task.detached(priority: .utility) { Self.installedInstruments() }.value
            instruments = found
        }
    }

    nonisolated private static func installedInstruments() -> [PluginComponent] {
        let query = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: 0,
                                              componentManufacturer: 0, componentFlags: 0, componentFlagsMask: 0)
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
    /// wanted, drops what is not, reloads a unit whose plugin or rate changed.
    func sync(_ project: Project, sampleRate: Double) {
        guard sampleRate > 0, sampleRate.isFinite else { return }
        var wanted: [TrackID: PluginComponent] = [:]
        for track in project.tracks where track.kind == .instrument && track.instrument.device == .plugin {
            if let plugin = track.instrument.plugin { wanted[track.id] = plugin }
        }
        var changed = false
        for (id, entry) in loaded where wanted[id] != entry.component || entry.sampleRate != sampleRate {
            loaded[id] = nil
            units[id] = nil
            changed = true
        }
        for (id, request) in requests where wanted[id] != request.component || request.sampleRate != sampleRate {
            requests[id] = nil
            loadingTracks.remove(id)
        }
        failed = failed.filter { wanted[$0.key] == $0.value }
        problems = problems.filter { failed[$0.key] != nil }
        for (id, component) in wanted where loaded[id] == nil && requests[id] == nil && failed[id] != component {
            load(component, for: id, state: project.track(id)?.instrument.pluginState, sampleRate: sampleRate)
        }
        if changed { revision += 1 }
    }

    private func load(_ component: PluginComponent, for track: TrackID, state: Data?, sampleRate: Double) {
        requestCount += 1
        let number = requestCount
        requests[track] = Request(component: component, sampleRate: sampleRate, number: number)
        loadingTracks.insert(track)
        log.info("plugin: load \(component.name, privacy: .public)")
        let description = AudioComponentDescription(componentType: component.type, componentSubType: component.subtype,
                                                    componentManufacturer: component.manufacturer, componentFlags: 0,
                                                    componentFlagsMask: 0)
        AUAudioUnit.instantiate(with: description, options: []) { @Sendable [weak self] unit, error in
            let box = UnitBox(unit)
            let failure = error.map { $0.localizedDescription }
            Task { @MainActor in self?.finish(box.unit, failure: failure, track: track, number: number, state: state) }
        }
    }

    private func finish(_ unit: AUAudioUnit?, failure: String?, track: TrackID, number: Int, state: Data?) {
        // An answer to a request that was replaced or withdrawn changes nothing.
        guard let request = requests[track], request.number == number else { return }
        requests[track] = nil
        loadingTracks.remove(track)
        guard let unit else {
            fail(track, request.component, reason: "\(request.component.name) is not installed on this device.", detail: failure)
            return
        }
        do {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: request.sampleRate, channels: 2),
                  unit.outputBusses.count > 0 else {
                throw HostError.noOutput
            }
            try unit.outputBusses[0].setFormat(format)
            unit.maximumFramesToRender = AUAudioFrameCount(EngineCore.maximumFrames)
            if let state,
               let settings = try? PropertyListSerialization.propertyList(from: state, format: nil) as? [String: Any] {
                unit.fullStateForDocument = settings
            }
            log.info("plugin: allocate \(request.component.name, privacy: .public)")
            try unit.allocateRenderResources()
        } catch {
            fail(track, request.component, reason: "\(request.component.name) cannot play in stereo at this rate.",
                 detail: error.localizedDescription)
            return
        }
        loaded[track] = Loaded(component: request.component, sampleRate: request.sampleRate, unit: unit)
        units[track] = HostedUnit(render: unit.renderBlock, scheduleMIDI: unit.scheduleMIDIEventBlock,
                                  sampleRate: request.sampleRate, maximumFrames: EngineCore.maximumFrames, owner: unit)
        problems[track] = nil
        revision += 1
        onUnitsChanged?()
    }

    /// Not retried until the track names another plugin: every retry would load and fail again.
    private func fail(_ track: TrackID, _ component: PluginComponent, reason: String, detail: String?) {
        log.error("plugin: \(component.name, privacy: .public) failed — \(detail ?? "", privacy: .public)")
        failed[track] = component
        problems[track] = reason
    }

    /// The loaded unit's own settings as a binary property list, for the song to keep; nil when
    /// the track has no loaded unit or its settings are not a property list.
    func captureState(of track: TrackID) -> Data? {
        guard let settings = loaded[track]?.unit.fullStateForDocument else { return nil }
        return try? PropertyListSerialization.data(fromPropertyList: settings, format: .binary, options: 0)
    }

    enum HostError: Error { case noOutput }
}
