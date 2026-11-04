import EchoelCore
import Observation
import SwiftUI

/// The A/B comparisons of the open song's devices (PRO-W1): in memory for the session, never in
/// the song, and forgotten when another song opens. Each switch and each copy that changes what
/// plays is one undo step through the one door (`DeviceComparison`).
@MainActor
@Observable
final class DeviceABStore {
    private(set) var pairs: [DeviceComparison.Device: DeviceComparison.Pair] = [:]
    @ObservationIgnored private var generation = 0

    func active(_ device: DeviceComparison.Device, in store: ProjectStore) -> DeviceComparison.Side {
        guard generation == store.documentGeneration else { return .a }
        return pairs[device]?.active ?? .a
    }

    /// Plays the other side of `device`.
    func toggle(_ device: DeviceComparison.Device, store: ProjectStore, plugins: PluginHost) {
        guard let current = currentSettings(device, store: store, plugins: plugins) else { return }
        var pair = pairs[device] ?? DeviceComparison.Pair()
        let restore = pair.toggle(current: current)
        apply(restore, on: device, title: "Switch to \(pair.active.rawValue)", store: store, pair: pair)
    }

    /// Copies one side of `device` onto the other.
    func copy(_ from: DeviceComparison.Side, to: DeviceComparison.Side, _ device: DeviceComparison.Device,
              store: ProjectStore, plugins: PluginHost) {
        guard let current = currentSettings(device, store: store, plugins: plugins) else { return }
        var pair = pairs[device] ?? DeviceComparison.Pair()
        let restore = pair.copy(from, to: to, current: current)
        apply(restore, on: device, title: "Copy \(from.rawValue) to \(to.rawValue)", store: store, pair: pair)
    }

    /// Whether `device` can be compared now: its settings are known to the song (a plugin's once
    /// it has reported them).
    func canCompare(_ device: DeviceComparison.Device, store: ProjectStore, plugins: PluginHost) -> Bool {
        switch device {
        case .instrument(let id):
            guard let track = store.project.track(id) else { return false }
            return track.instrument.device == .plugin ? plugins.isLoaded(.instrument(id)) : track.instrument.device != .unrecognized
        case .insert(let id):
            return plugins.isLoaded(.insert(id))
        }
    }

    /// What plays now: a plugin's settings are first taken into the song, outside the undo
    /// history, as a save takes them.
    private func currentSettings(_ device: DeviceComparison.Device, store: ProjectStore,
                                 plugins: PluginHost) -> DeviceComparison.Settings? {
        if generation != store.documentGeneration {
            pairs = [:]
            generation = store.documentGeneration
        }
        switch device {
        case .instrument(let id): plugins.store(into: store, only: .instrument(id))
        case .insert(let id): plugins.store(into: store, only: .insert(id))
        }
        return DeviceComparison.current(device, in: store.project)
    }

    private func apply(_ restore: DeviceComparison.Settings?, on device: DeviceComparison.Device, title: String,
                       store: ProjectStore, pair: DeviceComparison.Pair) {
        if let restore {
            guard let command = DeviceComparison.command(restoring: restore, on: device, in: store.project),
                  (try? store.perform([command], title: title)) != nil else { return }
        }
        pairs[device] = pair
    }
}

/// The A and B buttons of one device, and the copy between them. The side that plays is lit.
struct CompareRow: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DeviceABStore.self) private var comparisons
    let device: DeviceComparison.Device

    var body: some View {
        let active = comparisons.active(device, in: store)
        let enabled = comparisons.canCompare(device, store: store, plugins: engine.plugins)
        HStack(spacing: Theme.Space.s) {
            Text("Compare")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.textSecondary)
            ForEach(DeviceComparison.Side.allCases, id: \.self) { side in
                Button(side.rawValue) {
                    guard side != active else { return }
                    comparisons.toggle(device, store: store, plugins: engine.plugins)
                }
                .buttonStyle(ToolButtonStyle(isActive: side == active))
                .accessibilityLabel("Settings \(side.rawValue)")
                .accessibilityAddTraits(side == active ? .isSelected : [])
            }
            Menu {
                Button("Copy A to B", systemImage: "doc.on.doc") {
                    comparisons.copy(.a, to: .b, device, store: store, plugins: engine.plugins)
                }
                Button("Copy B to A", systemImage: "doc.on.doc") {
                    comparisons.copy(.b, to: .a, device, store: store, plugins: engine.plugins)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
            }
            .accessibilityLabel("Copy between A and B")
            Spacer(minLength: 0)
        }
        .disabled(!enabled)
    }
}
