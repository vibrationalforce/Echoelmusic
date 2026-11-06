import EchoelCore
import EchoelHost
import SwiftUI
import UIKit

/// A loaded plugin's own interface, inside the page that shows it rather than in a sheet of its
/// own (one presentation slot, law 7). Leaving it stores the plugin's settings in the song as one
/// step.
struct PluginInterfaceSection: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let slot: PluginHost.Slot

    @State private var controller: UIViewController?
    @State private var hasNoInterface = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HostedPresetRow(slot: slot)
            interface
        }
        // Asked again for every unit loaded into the slot — at a new rate, say — so the knobs on
        // screen are the playing unit's (audit 2026-10-23).
        .task(id: engine.plugins.loadNumber(of: slot)) {
            controller = nil
            hasNoInterface = false
            let found = await engine.plugins.interface(for: slot)
            guard !Task.isCancelled else { return }
            controller = found
            hasNoInterface = found == nil && engine.plugins.isLoaded(slot)
        }
        .onDisappear(perform: storeSettings)
    }

    @ViewBuilder private var interface: some View {
        Group {
            if let controller {
                PluginControllerHost(controller: controller)
                    .frame(height: Self.height(of: controller))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
            } else if hasNoInterface {
                Text("This plugin has no interface of its own.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }

    private func storeSettings() {
        engine.plugins.store(into: store, only: slot, title: "Plugin Settings")
    }

    /// The plugin's preferred height, kept between a usable minimum and most of a phone screen.
    private static func height(of controller: UIViewController) -> CGFloat {
        let preferred = controller.preferredContentSize.height
        return preferred > 0 ? min(max(preferred, 240), 560) : 360
    }
}

/// The loaded unit's presets: back and forward arrows, the menu (the unit's factory presets, then
/// the musician's own), and Save, which names a new user preset in place — no alert, the page
/// already holds its one presentation (Law 7). Choosing one stores the unit's settings in the song
/// as one undo step. Nothing shows while the unit is not loaded or offers no presets at all.
private struct HostedPresetRow: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let slot: PluginHost.Slot

    private typealias Presets = (menu: [HostedPresets.Entry], current: HostedPresets.Entry?)

    /// The name being typed for a new user preset; nil while none is.
    @State private var naming: String?
    @FocusState private var focused: Bool

    var body: some View {
        let host = engine.plugins
        let presets = host.presets(for: slot)
        let saves = host.savesUserPresets(slot)
        if !presets.menu.isEmpty || saves {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(spacing: Theme.Space.s) {
                    arrow(-1, presets: presets)
                    menu(presets)
                    arrow(1, presets: presets)
                    if saves {
                        Button("Save Preset") {
                            naming = presets.current?.isUser == true ? presets.current?.name ?? "" : ""
                            focused = true
                        }
                        .buttonStyle(ToolButtonStyle())
                        .accessibilityHint("Saves this plugin's sound as a preset of your own.")
                    }
                }
                if naming != nil { nameRow }
            }
        }
    }

    private func arrow(_ offset: Int, presets: Presets) -> some View {
        Button {
            if let target = HostedPresets.step(from: presets.current, by: offset, in: presets.menu) { choose(target) }
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
        }
        .buttonStyle(ToolButtonStyle())
        .disabled(presets.menu.isEmpty)
        .accessibilityLabel(offset < 0 ? "Previous Preset" : "Next Preset")
    }

    private func menu(_ presets: Presets) -> some View {
        let factory = presets.menu.filter { !$0.isUser }
        let user = presets.menu.filter(\.isUser)
        let name = presets.current?.name ?? "No Preset"
        return Menu {
            if !factory.isEmpty {
                Section("Factory") {
                    ForEach(factory) { entry in item(entry, current: presets.current) }
                }
            }
            if !user.isEmpty {
                Section("User Presets") {
                    ForEach(user) { entry in item(entry, current: presets.current) }
                }
            }
            if presets.menu.isEmpty { Text("No presets yet") }
        } label: {
            HStack(spacing: Theme.Space.xs) {
                Text("Preset").foregroundStyle(Theme.Color.textSecondary)
                Text(name).foregroundStyle(Theme.Color.text).lineLimit(1)
                Image(systemName: "chevron.down").foregroundStyle(Theme.Color.textSecondary)
                    .accessibilityHidden(true)
            }
            .font(Theme.Font.body)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Preset")
        .accessibilityValue(name)
    }

    @ViewBuilder private func item(_ entry: HostedPresets.Entry, current: HostedPresets.Entry?) -> some View {
        Button {
            choose(entry)
        } label: {
            if entry == current { Label(entry.name, systemImage: "checkmark") } else { Text(entry.name) }
        }
    }

    private var nameRow: some View {
        HStack(spacing: Theme.Space.s) {
            TextField("Preset Name", text: Binding(get: { naming ?? "" }, set: { naming = $0 }))
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(save)
                .padding(.horizontal, Theme.Space.s)
                .frame(minHeight: Theme.Size.touch)
                .background(Theme.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Color.borderStrong, lineWidth: 1))
                .accessibilityLabel("Preset Name")
            Button("Save", action: save)
                .buttonStyle(ToolButtonStyle())
                .disabled(HostedPresets.userName(naming ?? "") == nil)
            Button("Cancel") { naming = nil }
                .buttonStyle(ToolButtonStyle())
        }
    }

    private func choose(_ entry: HostedPresets.Entry) {
        engine.plugins.choose(preset: entry.number, for: slot, into: store)
    }

    /// Saves under the typed name; the row closes once the unit kept it.
    private func save() {
        guard let typed = naming, engine.plugins.saveUserPreset(named: typed, for: slot) != nil else { return }
        naming = nil
    }
}

/// Holds the plugin's view controller as a child, so it receives its appearance calls.
private struct PluginControllerHost: UIViewControllerRepresentable {
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
