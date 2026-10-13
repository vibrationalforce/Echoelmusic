#if canImport(SwiftUI)
import SwiftUI

/// Production level H1 → H2c (founder 2026-10-13: „Solange keine vernünftige Produktionsumgebung
/// wie AUv3 Plugins … vorhanden ist finde ich testen planlos"). The Device page of a rack track
/// lists the Audio Unit instruments installed on this iPhone and lets the track PLAY one instead of
/// its built-in voice: a pick writes `DeviceInsert.pluginInstrument` through the one writer
/// (`TimelineStore.setLanePluginInstrument`, one Undo step via `editLanePlugin`), and the region
/// player hands it to `HostedInstrumentHost`, which loads it and sends the track's notes to it.
///
/// What the row says plainly, because it is not built yet: the plugin's own screen does not open
/// here (H3) and its own settings are not saved with the piece (H4) — it plays its default sound.
/// Effects are listed only: inserting one on a track is H6.
///
/// ⚠️ ITS OWN LEAF, ON PURPOSE: the component query walks the system registry, so it runs
/// DETACHED in `.task` (the `TrackSampleRow` pattern), never in a `body`.
/// NEEDS-FOUNDER-VERIFY: H1 — the Device page of a Synth track lists the AUv3 instruments and effects installed on this iPhone (e.g. from AUM-compatible apps), and says "none" when there are none.
/// NEEDS-FOUNDER-VERIFY: H2c — picking an installed instrument on a Synth track's Device page makes that track play it (the built-in voice goes quiet), Undo gives the built-in voice back, and "Built-in voice" returns to it.
@MainActor
struct TrackPluginRow: View {
    @Environment(TimelineStore.self) private var timeline
    let laneID: UUID

    @State private var instruments: [PluginDescriptor] = []
    @State private var effects: [PluginDescriptor] = []
    @State private var loaded = false

    var body: some View {
        let current = timeline.document.lanes.first(where: { $0.id == laneID })?
            .deviceChain?.instrument?.pluginComponent
        let offered = Self.offered(instruments)
        VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
            HStack(spacing: EchoelTheme.spaceS) {
                Text("Plugin")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .accessibilityHidden(true)   // the Picker speaks the label once
                Picker("Plugin", selection: Binding<String?>(
                    get: { current.map(Self.key(for:)) },
                    set: { key in pick(key, among: offered) })) {
                    Text("Built-in voice").tag(String?.none)
                    if let current, !offered.contains(where: { Self.key(for: $0) == Self.key(for: current) }) {
                        Section("In this piece") {
                            Text(current.name + String(localized: " (not on this iPhone)"))
                                .tag(String?.some(Self.key(for: current)))
                        }
                    }
                    if !offered.isEmpty {
                        Section("Installed") {
                            ForEach(Array(offered.enumerated()), id: \.offset) { _, component in
                                Text(component.name + " · " + component.manufacturerName)
                                    .tag(String?.some(Self.key(for: component)))
                            }
                        }
                    }
                }
                .pickerStyle(.menu).tint(EchoelTheme.text)
                .frame(minHeight: 44)
                .accessibilityHint("The Audio Unit instrument this track plays instead of its built-in voice")
                Spacer(minLength: 0)
            }
            Text(loaded ? Self.note(current: current, installed: offered.count, effects: effects.count)
                        : String(localized: "Looking for installed Audio Units…"))
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task {
            let found = await Task.detached(priority: .utility) {
                (PluginCatalog.installed(.instrument),
                 PluginCatalog.installed(.effect) + PluginCatalog.installed(.musicEffect))
            }.value
            guard !Task.isCancelled else { return }
            instruments = found.0
            effects = PluginCatalog.ordered(found.1)
            loaded = true
        }
    }

    /// One pick, one Undo step, through the one writer; an unknown key changes nothing.
    private func pick(_ key: String?, among offered: [DeviceInsert.PluginComponent]) {
        let insert: DeviceInsert?
        if let key {
            guard let component = offered.first(where: { Self.key(for: $0) == key }) else { return }
            insert = .pluginInstrument(component)
        } else {
            insert = nil
        }
        timeline.editLanePlugin(id: laneID) { timeline.setLanePluginInstrument(laneID, insert) }
    }

    /// The installed instruments a track may play: never this app's own (the host refuses them,
    /// `HostedInstrumentHost.ownManufacturer`), as the plain values the song stores.
    static func offered(_ installed: [PluginDescriptor]) -> [DeviceInsert.PluginComponent] {
        installed
            .filter { $0.role == .instrument && $0.manufacturer != HostedInstrumentHost.ownManufacturer }
            .map { DeviceInsert.PluginComponent(type: $0.type, subtype: $0.subtype, manufacturer: $0.manufacturer,
                                                 name: $0.name, manufacturerName: $0.manufacturerName) }
    }

    /// The identity of a component in the menu — the three codes, never the names (two units may
    /// share a name; a renamed unit is still the same unit).
    static func key(for component: DeviceInsert.PluginComponent) -> String {
        "\(component.type)/\(component.subtype)/\(component.manufacturer)"
    }

    /// What the row says under the menu: what plays, then the honest limits.
    static func note(current: DeviceInsert.PluginComponent?, installed: Int, effects: Int) -> String {
        var lines: [String] = []
        if let current {
            lines.append(String(localized: "This track plays ") + current.name
                         + String(localized: " with its default sound. Its own screen and settings are not available here yet."))
        } else if installed == 0 {
            lines.append(String(localized: "No Audio Unit instruments are installed on this iPhone."))
        } else {
            lines.append(String(localized: "Pick an installed instrument to play this track instead of its built-in voice."))
        }
        if effects > 0 {
            lines.append("\(effects) " + String(localized: "effects installed — inserting one on a track is not available yet."))
        }
        return lines.joined(separator: " ")
    }
}
#endif
