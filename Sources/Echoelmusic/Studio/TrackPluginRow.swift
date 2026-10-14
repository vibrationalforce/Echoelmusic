#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Production level H1 → H2c (founder 2026-10-13: „Solange keine vernünftige Produktionsumgebung
/// wie AUv3 Plugins … vorhanden ist finde ich testen planlos"). The Device page of a rack track
/// lists the Audio Unit instruments installed on this iPhone and lets the track PLAY one instead of
/// its built-in voice: a pick writes `DeviceInsert.pluginInstrument` through the one writer
/// (`TimelineStore.setLanePluginInstrument`, one Undo step via `editLanePlugin`), and the region
/// player hands it to `HostedInstrumentHost`, which loads it and sends the track's notes to it.
///
/// H3: "Open plugin" shows the chosen plugin's OWN screen in a sheet. The controller is asked for
/// only on the tap (`HostedInstrumentHost.requestView`), held by the sheet while it is shown and
/// let go on close. A plugin without a screen, or one that is not loaded yet (it loads when its
/// track plays), says so under the menu instead of opening an empty window.
///
/// H4: closing the window keeps the plugin's own settings in the song, and the next load gives
/// them back. What the row says plainly, because it is not built yet: effects are listed only —
/// inserting one on a track is H6.
///
/// ⚠️ ITS OWN LEAF, ON PURPOSE: the component query walks the system registry, so it runs
/// DETACHED in `.task` (the `TrackSampleRow` pattern), never in a `body`.
/// NEEDS-FOUNDER-VERIFY: H1 — the Device page of a Synth track lists the AUv3 instruments and effects installed on this iPhone (e.g. from AUM-compatible apps), and says "none" when there are none.
/// NEEDS-FOUNDER-VERIFY: H3 — on a Synth track playing an installed instrument, "Open plugin" (after Play has loaded it) shows that plugin's own screen, its controls change the sound while it plays, and closing the sheet keeps the sound.
/// NEEDS-FOUNDER-VERIFY: H2c — picking an installed instrument on a Synth track's Device page makes that track play it (the built-in voice goes quiet), Undo gives the built-in voice back, and "Built-in voice" returns to it.
@MainActor
struct TrackPluginRow: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(TimelineRegionPlayer.self) private var player
    let laneID: UUID

    @State private var instruments: [PluginDescriptor] = []
    @State private var effects: [PluginDescriptor] = []
    @State private var loaded = false
    #if canImport(UIKit)
    @State private var window: PluginWindow?
    /// The plugin the open window shows — the settings kept on close belong to THIS one.
    @State private var shownComponent: DeviceInsert.PluginComponent?
    #endif
    /// Why the last "Open plugin" tap opened nothing — cleared by the next pick.
    @State private var openNote: String?

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
                #if canImport(UIKit)
                if let current {
                    Button("Open plugin") { open(current) }
                        .font(EchoelTheme.font(12)).tint(EchoelTheme.text)
                        .frame(minHeight: 44)
                        .accessibilityHint("Shows this plugin's own screen")
                }
                #endif
            }
            if let openNote {
                Text(openNote)
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(loaded ? Self.note(current: current, installed: offered.count, effects: effects.count)
                        : String(localized: "Looking for installed Audio Units…"))
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        #if canImport(UIKit)
        .sheet(item: $window, onDismiss: keepSettings) { shown in
            PluginWindowSheet(window: shown)
        }
        #endif
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
        openNote = nil
        timeline.editLanePlugin(id: laneID) { timeline.setLanePluginInstrument(laneID, insert) }
    }

    #if canImport(UIKit)
    /// The rack slot this track plays in — the one lane→slot lookup, asked on demand.
    private func trackSlot() -> Int? {
        let document = timeline.document
        return MultiRollFanout.slot(forLaneID: laneID, in: document, rollLane: document.rollLaneID,
                                    capacity: player.laneVoiceCapacity)
    }

    /// Ask the host for the track's plugin screen — only now, on the tap.
    private func open(_ component: DeviceInsert.PluginComponent) {
        guard let host = HostedInstrumentHost.live,
              let slot = trackSlot(),
              host.requestView(forSlot: slot, expecting: component, done: { controller in
                  if let controller {
                      // A second fast tap answers while the first window is up: keep that one, so
                      // its close still keeps the settings of the plugin it shows.
                      guard window == nil else { return }
                      openNote = nil
                      shownComponent = component
                      window = PluginWindow(name: component.name, controller: controller)
                  } else {
                      openNote = String(localized: "This plugin has no screen of its own.")
                  }
              }) else {
            openNote = String(localized: "The plugin loads when its track plays — press Play, then open it.")
            return
        }
    }

    /// H4b — when the plugin window closes, the song keeps what the person set in it. Nothing is
    /// written when the unit reports no settings; the store refuses an oversize state.
    private func keepSettings() {
        let component = shownComponent
        shownComponent = nil
        guard let component, let host = HostedInstrumentHost.live, let slot = trackSlot(),
              let state = host.captureState(forSlot: slot, expecting: component) else { return }
        timeline.setLanePluginState(laneID, state)
    }
    #endif

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
                         + String(localized: ". Open the plugin to shape its sound — the piece keeps its settings."))
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

#if canImport(UIKit)
/// One open plugin screen. The sheet holds the controller while it is shown; closing drops it.
struct PluginWindow: Identifiable {
    let id = UUID()
    let name: String
    let controller: UIViewController
}

/// The sheet: the plugin's name, a Done button, and the plugin's own screen below.
private struct PluginWindowSheet: View {
    @Environment(\.dismiss) private var dismiss
    let window: PluginWindow

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(window.name).font(EchoelTheme.font(15)).foregroundStyle(EchoelTheme.text)
                Spacer(minLength: EchoelTheme.spaceS)
                Button("Done") { dismiss() }.tint(EchoelTheme.text).frame(minHeight: 44)
            }
            .padding(.horizontal, EchoelTheme.spaceM)
            PluginScreenHost(controller: window.controller)
        }
    }
}

/// Hangs the plugin's view controller into SwiftUI as a child, and takes it out again on close.
private struct PluginScreenHost: UIViewControllerRepresentable {
    let controller: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.addChild(controller)
        controller.view.frame = container.view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.view.addSubview(controller.view)
        controller.didMove(toParent: container)
        return container
    }

    func updateUIViewController(_ container: UIViewController, context: Context) {}

    static func dismantleUIViewController(_ container: UIViewController, coordinator: ()) {
        for child in container.children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
}
#endif
#endif
