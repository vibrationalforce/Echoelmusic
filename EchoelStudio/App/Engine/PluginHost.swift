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
    enum Slot: Hashable, Sendable {
        case instrument(TrackID)
        case insert(InsertID)
    }

    private(set) var instruments: [PluginComponent] = []
    private(set) var effects: [PluginComponent] = []
    /// Why a unit does not play; absent while it plays or loads.
    private(set) var problems: [Slot: String] = [:]
    private(set) var loading: Set<Slot> = []
    /// A unit that stopped and was loaded again plays its last saved settings, which may not be
    /// the ones just heard: said in the status line until the next Play (review 2026-10-20). Said
    /// once the reload has happened, and replaced by the reason when it does not (review
    /// 2026-10-21): announced at the stop, it stood there over a unit that never came back.
    private(set) var notice: String?
    /// The slots being loaded again after their unit stopped, and whether a media reset did it.
    @ObservationIgnored private var reloading: [Slot: Bool] = [:]

    func clearNotice() {
        notice = nil
        noticeIsFailure = false
    }

    /// A unit that did not come back outranks the ones that did, whichever answer arrives last.
    @ObservationIgnored private var noticeIsFailure = false

    private func noteReloaded(_ text: String) {
        guard !noticeIsFailure else { return }
        notice = text
    }

    private func noteNotReloaded(_ reason: String) {
        notice = reason
        noticeIsFailure = true
    }
    /// Changes whenever the loaded units do; observe this, not the units.
    private(set) var revision = 0

    @ObservationIgnored private(set) var units: [TrackID: HostedUnit] = [:]
    /// Each track's loaded, active inserts in chain order, for the engine.
    @ObservationIgnored private(set) var chains: [TrackID: [HostedEffect]] = [:]
    /// The master's loaded, active inserts in chain order.
    @ObservationIgnored private(set) var masterChain: [HostedEffect] = []
    /// Called when a unit finished loading, so the engine republishes with it. `sync` does not
    /// call it: its caller publishes anyway.
    @ObservationIgnored var onUnitsChanged: (() -> Void)?
    /// Called on the main thread when a control in a plugin's own interface moves one of its
    /// parameters: which, to where along its travel (0…1), and whether it was touched, moved or let go.
    @ObservationIgnored var onParameterMoved: ((ParameterAddress, Double, ParameterPhase) -> Void)?
    /// Whose chain each insert sits on — a track's or the master's — as of the last `sync`.
    @ObservationIgnored private var insertOwners: [InsertID: ParameterAddress.Owner] = [:]
    @ObservationIgnored private var loaded: [Slot: Loaded] = [:]
    @ObservationIgnored private var requests: [Slot: Request] = [:]
    @ObservationIgnored private var failed: [Slot: PluginComponent] = [:]
    /// The saved state each loaded unit was last brought in line with — applied on load or after
    /// an undo, or captured from the unit. A song whose state differs gets it applied.
    @ObservationIgnored private var syncedState: [Slot: Data] = [:]
    @ObservationIgnored private var requestCount = 0
    @ObservationIgnored private var registrationObserver: NSObjectProtocol?
    @ObservationIgnored private var invalidationObserver: NSObjectProtocol?
    @ObservationIgnored private var resetObserver: NSObjectProtocol?
    /// When each slot's unit stopped by itself. More than `restartLimit` stops within
    /// `restartWindow` and it is not reloaded; one crash an hour is reloaded every time.
    @ObservationIgnored private var restarts: [Slot: [ContinuousClock.Instant]] = [:]
    private static let restartLimit = 3
    private static let restartWindow: Duration = .seconds(600)
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "plugins")

    private struct Loaded {
        let component: PluginComponent
        let sampleRate: Double
        let unit: AUAudioUnit
        let instrument: HostedUnit?
        let effect: HostedEffect?
        /// Our observer on the unit's parameters; also the originator of values we set, so the
        /// unit does not report them back.
        let observer: AUParameterObserverToken?
    }

    enum ParameterPhase: Sendable { case touch, value, release }

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
        // A plugin's extension that crashes, or the media services resetting, leaves its unit
        // dead: the lane went silent until the song was reopened (ultra-audit R5). The dead unit
        // is forgotten and the next sync loads it again with the song's saved settings.
        invalidationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(kAudioComponentInstanceInvalidationNotification as String), object: nil,
            queue: .main
        ) { @Sendable [weak self] note in
            let dead = (note.object as AnyObject?).map(ObjectIdentifier.init)
            MainActor.assumeIsolated { self?.unitStopped(dead) }
        }
        resetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.unitStopped(nil) }
        }
    }

    /// Forgets the loaded unit `dead` names, or every loaded unit when it is nil, and has the
    /// engine republish so `sync` loads them again.
    private func unitStopped(_ dead: ObjectIdentifier?) {
        let gone = loaded.filter { dead == nil || ObjectIdentifier($0.value.unit) == dead }
        guard !gone.isEmpty else { return }
        for (slot, entry) in gone {
            log.error("plugin: \(entry.component.name, privacy: .public) stopped, reloading")
            if let observer = entry.observer { entry.unit.parameterTree?.removeParameterObserver(observer) }
            loaded[slot] = nil
            syncedState[slot] = nil
            // A media reset is the system's doing; only a unit that stops by itself counts.
            guard dead != nil else { continue }
            let now = ContinuousClock.now
            let recent = restarts[slot, default: []].filter { $0.duration(to: now) < Self.restartWindow } + [now]
            restarts[slot] = recent
            let count = recent.count
            if count > Self.restartLimit {
                reloading[slot] = nil
                let reason = "\(entry.component.name) stopped working and was not loaded again."
                fail(slot, entry.component, reason: reason, detail: "stopped \(count) times")
                noteNotReloaded(reason)
            } else {
                reloading[slot] = false
            }
        }
        if dead == nil { for slot in gone.keys { reloading[slot] = true } }
        revision += 1
        onUnitsChanged?()
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
        for insert in project.masterInserts {
            wanted[.insert(insert.id)] = Wanted(component: insert.plugin, state: insert.state)
        }
        insertOwners = [:]
        for track in project.tracks {
            for insert in track.inserts { insertOwners[insert.id] = .track(track.id) }
        }
        for insert in project.masterInserts { insertOwners[insert.id] = .master }
        var changed = false
        // An undo or a reopened song can carry other settings than the loaded unit has. They are
        // never written into a unit the engine is rendering (B8: a plugin from another maker need
        // not survive that): the unit is dropped and loaded again below, and `prepare` applies the
        // settings before its render resources exist — the path a changed plugin already takes.
        func settingsChanged(_ slot: Slot) -> Bool {
            guard let state = wanted[slot]?.state else { return false }
            return state != syncedState[slot]
        }
        for (slot, entry) in loaded where wanted[slot]?.component != entry.component || entry.sampleRate != sampleRate
            || settingsChanged(slot) {
            if let observer = entry.observer { entry.unit.parameterTree?.removeParameterObserver(observer) }
            loaded[slot] = nil
            syncedState[slot] = nil
            changed = true
        }
        for (slot, request) in requests where wanted[slot]?.component != request.component || request.sampleRate != sampleRate {
            requests[slot] = nil
            loading.remove(slot)
        }
        failed = failed.filter { wanted[$0.key]?.component == $0.value }
        // A slot no longer wanted is not loaded again, so nothing is said about it.
        reloading = reloading.filter { wanted[$0.key] != nil }
        problems = problems.filter { failed[$0.key] != nil }
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
        masterChain = project.masterInserts.filter { !$0.isBypassed }.compactMap { loaded[.insert($0.id)]?.effect }
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
        let isEffect = slot.isInsert
        do {
            log.info("plugin: allocate \(request.component.name, privacy: .public)")
            try Self.prepare(unit, isEffect: isEffect, sampleRate: request.sampleRate, state: state)
        } catch {
            fail(slot, request.component, reason: "\(request.component.name) cannot play in stereo at this rate.",
                 detail: error.localizedDescription)
            return
        }
        let rate = request.sampleRate
        loaded[slot] = Loaded(component: request.component, sampleRate: rate, unit: unit,
                              instrument: isEffect ? nil : Self.instrument(unit, sampleRate: rate),
                              effect: slot.insertID.map { Self.effect(unit, insert: $0, sampleRate: rate) },
                              observer: observe(unit, slot: slot))
        syncedState[slot] = state
        problems[slot] = nil
        if let afterReset = reloading.removeValue(forKey: slot) {
            noteReloaded(afterReset ? "After an audio reset the plugins were loaded again with their last saved settings."
                : "\(request.component.name) stopped and was loaded again with its last saved settings.")
        }
        revision += 1
        // The chains are rebuilt from the song when the engine republishes.
        onUnitsChanged?()
    }

    /// Not retried until the slot names another plugin: every retry would load and fail again.
    private func fail(_ slot: Slot, _ component: PluginComponent, reason: String, detail: String?) {
        log.error("plugin: \(component.name, privacy: .public) failed — \(detail ?? "", privacy: .public)")
        failed[slot] = component
        problems[slot] = reason
        // A unit that stopped and does not come back: the status line says so, not the page alone.
        if reloading.removeValue(forKey: slot) != nil { noteNotReloaded(reason) }
    }

    func isLoaded(_ slot: Slot) -> Bool { loaded[slot] != nil }

    /// Watches the unit's own controls. The unit calls this on any thread, in batches.
    private func observe(_ unit: AUAudioUnit, slot: Slot) -> AUParameterObserverToken? {
        unit.parameterTree?.token(byAddingParameterAutomationObserver: { @Sendable [weak self] count, events in
            var moves: [(address: UInt64, value: Float, phase: ParameterPhase)] = []
            for index in 0..<count {
                let event = events[index]
                let phase: ParameterPhase = event.eventType == .touch ? .touch
                    : event.eventType == .release ? .release : .value
                moves.append((event.address, event.value, phase))
            }
            let batch = moves
            Task { @MainActor in self?.moved(batch, in: slot) }
        })
    }

    private func moved(_ moves: [(address: UInt64, value: Float, phase: ParameterPhase)], in slot: Slot) {
        guard let onParameterMoved, let tree = loaded[slot]?.unit.parameterTree, let owner = owner(of: slot) else { return }
        for move in moves {
            guard let parameter = tree.parameter(withAddress: move.address),
                  parameter.maxValue > parameter.minValue, move.value.isFinite else { continue }
            let position = Double(Swift.min(Swift.max((move.value - parameter.minValue) / (parameter.maxValue - parameter.minValue), 0), 1))
            onParameterMoved(ParameterAddress(owner, .plugin(PluginParameter(slot.unit, address: move.address))),
                             position, move.phase)
        }
    }

    private func owner(of slot: Slot) -> ParameterAddress.Owner? {
        switch slot {
        case .instrument(let track): .track(track)
        case .insert(let insert): insertOwners[insert]
        }
    }

    /// The loaded parameter a plugin address names, and the observer to set it as.
    private func loadedParameter(_ address: ParameterAddress) -> (AUParameter, AUParameterObserverToken?)? {
        guard let plugin = address.key.pluginParameter else { return nil }
        let slot: Slot
        switch (address.owner, plugin.unit) {
        case (.track(let track), .instrument): slot = .instrument(track)
        case (.track, .insert(let insert)), (.master, .insert(let insert)): slot = .insert(insert)
        default: return nil
        }
        guard let entry = loaded[slot], let parameter = entry.unit.parameterTree?.parameter(withAddress: plugin.address),
              parameter.maxValue > parameter.minValue else { return nil }
        return (parameter, entry.observer)
    }

    /// Where a loaded plugin parameter is now, 0…1 of its travel.
    func position(of address: ParameterAddress) -> Double? {
        guard let found = loadedParameter(address)?.0 else { return nil }
        return Double(Swift.min(Swift.max((found.value - found.minValue) / (found.maxValue - found.minValue), 0), 1))
    }

    /// Moves a loaded plugin parameter to `position` (0…1) of its travel — a mapped controller.
    func setPosition(_ address: ParameterAddress, to position: Double) {
        guard let target = loadedParameter(address), position.isFinite else { return }
        let (found, observer) = target
        let n = Float(Swift.min(Swift.max(position, 0), 1))
        let value = found.minValue + n * (found.maxValue - found.minValue)
        if let observer { found.setValue(value, originator: observer) } else { found.value = value }
    }

    /// Stereo at `sampleRate` (input too, for an effect), the engine's largest block, the saved
    /// settings, then render resources.
    private static func prepare(_ unit: AUAudioUnit, isEffect: Bool, sampleRate: Double, state: Data?) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              unit.outputBusses.count > 0 else {
            throw HostError.noOutput
        }
        try unit.outputBusses[0].setFormat(format)
        if isEffect {
            guard unit.inputBusses.count > 0 else { throw HostError.noInput }
            try unit.inputBusses[0].setFormat(format)
        }
        unit.maximumFramesToRender = AUAudioFrameCount(EngineCore.maximumFrames)
        if let state { apply(state, to: unit) }
        try unit.allocateRenderResources()
    }

    private static func instrument(_ unit: AUAudioUnit, sampleRate: Double) -> HostedUnit {
        HostedUnit(render: unit.renderBlock, scheduleMIDI: unit.scheduleMIDIEventBlock, sampleRate: sampleRate,
                   maximumFrames: EngineCore.maximumFrames, owner: unit,
                   scheduleParameter: unit.scheduleParameterBlock, parameterRanges: automatable(unit))
    }

    private static func effect(_ unit: AUAudioUnit, insert: InsertID, sampleRate: Double) -> HostedEffect {
        HostedEffect(render: unit.renderBlock, sampleRate: sampleRate, maximumFrames: EngineCore.maximumFrames, owner: unit,
                     insert: insert, scheduleParameter: unit.scheduleParameterBlock, parameterRanges: automatable(unit))
    }

    /// The parameters automation may move: writable, with a real range. Read after the saved
    /// settings are applied — some units build their tree from them.
    private static func automatable(_ unit: AUAudioUnit) -> [UInt64: ClosedRange<Float>] {
        var ranges: [UInt64: ClosedRange<Float>] = [:]
        for parameter in unit.parameterTree?.allParameters ?? [] where parameter.flags.contains(.flag_IsWritable) {
            let low = parameter.minValue, high = parameter.maxValue
            guard low.isFinite, high.isFinite, high > low else { continue }
            ranges[parameter.address] = low...high
        }
        return ranges
    }

    /// The parameters of the unit in `slot` that the song can automate, in the unit's order, or
    /// none while it is not loaded.
    /// The loaded unit in `slot` when it is one of Echoel's standard effects, for its meter.
    func standardEffect(_ slot: Slot) -> StandardEffectUnit? {
        loaded[slot]?.unit as? StandardEffectUnit
    }

    func automatableParameters(_ slot: Slot) -> [PluginParameterInfo] {
        guard let unit = loaded[slot]?.unit else { return [] }
        return (unit.parameterTree?.allParameters ?? []).compactMap { parameter in
            guard parameter.flags.contains(.flag_IsWritable), parameter.minValue.isFinite, parameter.maxValue.isFinite,
                  parameter.maxValue > parameter.minValue else { return nil }
            return PluginParameterInfo(address: parameter.address, name: parameter.displayName,
                                       low: parameter.minValue, high: parameter.maxValue, unitName: parameter.unitName,
                                       current: parameter.value)
        }
    }

    /// Fresh units for an export: the live ones belong to the render thread. Each is loaded with
    /// the song's saved settings at `sampleRate`; one that cannot load is left out, and its track
    /// or insert is silent (or passes its sound through) in the file. The names of those are returned.
    func offlineUnits(for project: Project, sampleRate: Double) async -> OfflineUnits {
        var units: [TrackID: HostedUnit] = [:]
        var chains: [TrackID: [HostedEffect]] = [:]
        var missing: [String] = []
        for track in project.tracks {
            if track.kind == .instrument, track.instrument.device == .plugin, let plugin = track.instrument.plugin {
                if let unit = await Self.instantiate(plugin, isEffect: false, sampleRate: sampleRate,
                                                     state: track.instrument.pluginState) {
                    units[track.id] = Self.instrument(unit, sampleRate: sampleRate)
                } else {
                    missing.append(plugin.name)
                }
            }
            var chain: [HostedEffect] = []
            for insert in track.inserts where !insert.isBypassed {
                if let unit = await Self.instantiate(insert.plugin, isEffect: true, sampleRate: sampleRate, state: insert.state) {
                    chain.append(Self.effect(unit, insert: insert.id, sampleRate: sampleRate))
                } else {
                    missing.append(insert.plugin.name)
                }
            }
            if !chain.isEmpty { chains[track.id] = chain }
        }
        var masterChain: [HostedEffect] = []
        for insert in project.masterInserts where !insert.isBypassed {
            if let unit = await Self.instantiate(insert.plugin, isEffect: true, sampleRate: sampleRate, state: insert.state) {
                masterChain.append(Self.effect(unit, insert: insert.id, sampleRate: sampleRate))
            } else {
                missing.append(insert.plugin.name)
            }
        }
        return OfflineUnits(units: units, chains: chains, masterChain: masterChain, missing: missing)
    }

    private static func instantiate(_ component: PluginComponent, isEffect: Bool, sampleRate: Double,
                                    state: Data?) async -> AUAudioUnit? {
        let description = AudioComponentDescription(componentType: component.type, componentSubType: component.subtype,
                                                    componentManufacturer: component.manufacturer, componentFlags: 0,
                                                    componentFlagsMask: 0)
        let box: UnitBox = await withCheckedContinuation { continuation in
            AUAudioUnit.instantiate(with: description, options: []) { @Sendable unit, _ in
                continuation.resume(returning: UnitBox(unit))
            }
        }
        guard let unit = box.unit else { return nil }
        do {
            try prepare(unit, isEffect: isEffect, sampleRate: sampleRate, state: state)
        } catch {
            return nil
        }
        return unit
    }

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
        for insert in project.masterInserts {
            if let command = capture(.insert(insert.id), stored: insert.state, only: only,
                                     make: { .setMasterInsertState(insert.id, $0) }) {
                commands.append(command)
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

extension PluginHost.Slot {
    var isInsert: Bool {
        if case .insert = self { true } else { false }
    }

    var insertID: InsertID? {
        if case .insert(let id) = self { id } else { nil }
    }

    /// The unit a plugin parameter of this slot names.
    var unit: PluginParameter.Unit {
        switch self {
        case .instrument: .instrument
        case .insert(let id): .insert(id)
        }
    }
}

/// One automatable parameter of a loaded unit, as the unit describes it.
struct PluginParameterInfo: Identifiable, Equatable {
    let address: UInt64
    let name: String
    let low: Float
    let high: Float
    let unitName: String?
    /// The unit's value when this was read.
    let current: Float

    var id: UInt64 { address }

    /// Where `current` sits along the parameter's travel, 0…1.
    var position: Double {
        Double(Swift.min(Swift.max((current - low) / (high - low), 0), 1))
    }
}

/// Units loaded for one export, handed to the offline render.
struct OfflineUnits: @unchecked Sendable {
    let units: [TrackID: HostedUnit]
    let chains: [TrackID: [HostedEffect]]
    let masterChain: [HostedEffect]
    /// Plugins that could not load; the export is made without them.
    let missing: [String]
}
