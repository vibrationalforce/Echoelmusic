import EchoelCore
import Observation

/// The one path a control's movement takes into the song. Normally it sets the parameter; with
/// automation writing armed and the transport running it writes the movement into the
/// parameter's lane at the playhead instead, overwriting what the lane held where the control
/// passed. Faders, pan controls, value fields and MIDI-learned controllers all go through here.
@MainActor
@Observable
final class ParameterWriter {
    /// Automation write is armed (the "A" button in the transport).
    private(set) var isWriting = false

    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private let engine: AudioEngine
    /// Per parameter, the last tick this gesture wrote.
    @ObservationIgnored private var written: [ParameterAddress: Tick] = [:]

    init(store: ProjectStore, engine: AudioEngine) {
        self.store = store
        self.engine = engine
    }

    func setWriting(_ on: Bool) {
        isWriting = on
        endGesture()
    }

    /// A control moved to `normalized` (0…1) of its travel. Returns the value written into the
    /// lane when the move went there, nil when it set the parameter: during a pass the song's own
    /// value does not change, so the control shows this one under the finger (audit 2026-10-23).
    @discardableResult
    func set(_ address: ParameterAddress, normalized: Double, gesture: Bool) -> Double? {
        guard let descriptor = store.project.descriptor(for: address) else { return nil }
        return set(address, to: descriptor.value(forNormalized: normalized), coalescingKey: gesture ? "parameter.\(address)" : nil)
    }

    /// Double-tap: back to the parameter's default.
    func reset(_ address: ParameterAddress) {
        guard let descriptor = store.project.descriptor(for: address) else { return }
        set(address, to: descriptor.defaultValue, coalescingKey: nil)
        endGesture()
    }

    /// As `set(_:normalized:gesture:)`, by value.
    @discardableResult
    func set(_ address: ParameterAddress, to value: Double, coalescingKey: String?) -> Double? {
        if isWriting, engine.isPlaying, address != .tempo, let passed = write(address, value) { return passed }
        // A plugin parameter's value lives in the unit, not the song.
        if address.key.pluginParameter != nil {
            engine.plugins.setPosition(address, to: value)
            return nil
        }
        guard let command = Command.setParameter(address, to: value) else { return nil }
        try? store.perform(command, coalescingKey: coalescingKey)
        return nil
    }

    /// A control in a plugin's own interface moved. With writing armed and the transport
    /// running, the movement is written like any other; letting go ends the pass.
    func pluginMoved(_ address: ParameterAddress, to position: Double, phase: PluginHost.ParameterPhase) {
        switch phase {
        case .touch:
            written[address] = nil
        case .value:
            guard isWriting, engine.isPlaying else { return }
            _ = write(address, position)
        case .release:
            written[address] = nil
            store.endGesture()
        }
    }

    /// The control was let go: the next movement starts a new undo step and a new pass.
    func endGesture() {
        written = [:]
        store.endGesture()
    }

    /// Writes one point at the playhead and returns its value, nil when nothing was written. A
    /// new lane first holds the parameter's set value up to where writing began, so nothing
    /// before it changes.
    private func write(_ address: ParameterAddress, _ value: Double) -> Double? {
        let project = store.project
        guard let descriptor = project.descriptor(for: address),
              let current = project.value(of: address) ?? engine.plugins.position(of: address) else { return nil }
        let now = engine.playheadTick(in: project)
        let clamped = Swift.min(Swift.max(value, descriptor.range.lowerBound), descriptor.range.upperBound)
        var points = project.automation(for: address)?.points ?? []
        if points.isEmpty {
            points.append(AutomationPoint(tick: 0, value: current))
            if now > 1 { points.append(AutomationPoint(tick: now - 1, value: current)) }
        }
        let last = written[address] ?? now - 1
        // Overwrite what the lane held between the previous point of this pass and now.
        points.removeAll { $0.tick > last && $0.tick <= now }
        let index = points.firstIndex { $0.tick > now } ?? points.count
        points.insert(AutomationPoint(tick: now, value: clamped), at: index)
        written[address] = now
        do {
            try store.perform(.setAutomation(address, points: points), coalescingKey: "automation.\(address)")
            return clamped
        } catch {
            return nil
        }
    }
}
