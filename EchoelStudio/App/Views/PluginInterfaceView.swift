import EchoelCore
import EchoelHost
import SwiftUI
import UIKit

/// A loaded plugin's own interface, inside the page that shows it rather than in a sheet of its
/// own (one presentation slot, law 7). It is drawn the full width of the page at the unit's
/// preferred height, or at the unit's full size where that fits and is larger; Full Size raises the
/// height ceiling in place, never into a second sheet. A unit without an interface of
/// its own shows its parameters as value fields instead. Leaving it stores the plugin's settings in
/// the song as one step.
struct PluginInterfaceSection: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let slot: PluginHost.Slot

    @State private var controller: UIViewController?
    @State private var hasNoInterface = false
    /// The sizes the unit says its interface can take, asked once per load.
    @State private var sizes: [CGSize] = []
    /// The interface drawn full size, in place.
    @State private var isExpanded = false
    /// The width the page gives the interface.
    @State private var width: CGFloat = 0

    /// The height the page offers an expanded interface: room for the full-size one (1024 × 700).
    private static let expandedHeight: CGFloat = 760

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HostedPresetRow(slot: slot)
            interface
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { newWidth in width = newWidth }
        // Asked again for every unit loaded into the slot — at a new rate, say — so the knobs on
        // screen are the playing unit's (audit 2026-10-23).
        .task(id: engine.plugins.loadNumber(of: slot)) {
            controller = nil
            hasNoInterface = false
            sizes = []
            let found = await engine.plugins.interface(for: slot)
            guard !Task.isCancelled else { return }
            sizes = found == nil ? [] : engine.plugins.interfaceSizes(for: slot)
            controller = found
            hasNoInterface = found == nil && engine.plugins.isLoaded(slot)
        }
        .onDisappear(perform: storeSettings)
    }

    @ViewBuilder private var interface: some View {
        if let controller {
            expandButton
            sized(controller)
        } else if hasNoInterface {
            Text("This plugin has no interface of its own. Its parameters:")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
            HostedParameterGrid(slot: slot)
        }
    }

    private var expandButton: some View {
        Button {
            isExpanded.toggle()
        } label: {
            Label(isExpanded ? "Compact" : "Full Size",
                  systemImage: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(Theme.Font.body)
        }
        .buttonStyle(ToolButtonStyle(isActive: isExpanded))
        .accessibilityLabel("Full Size Interface")
        .accessibilityValue(isExpanded ? "On" : "Off")
        .accessibilityHint("Shows the plugin's interface as large as this page allows.")
    }

    /// The interface at the size `PluginViewSize` chooses; the unit is told which of its sizes it got.
    private func sized(_ controller: UIViewController) -> some View {
        let ceiling = isExpanded ? Self.expandedHeight : PluginViewSize.compactCeiling
        let choice = PluginViewSize.choose(reported: sizes, available: CGSize(width: width, height: ceiling),
                                           preferredHeight: controller.preferredContentSize.height, ceiling: ceiling)
        let frameWidth: CGFloat?, frameHeight: CGFloat
        switch choice {
        case .configuration(_, let size):
            frameWidth = size.width
            frameHeight = size.height
        case .height(let height):
            frameWidth = nil
            frameHeight = height
        }
        return PluginControllerHost(controller: controller)
            .frame(width: frameWidth, height: frameHeight)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
            .onChange(of: choice, initial: true) { _, chosen in
                if case .configuration(_, let size) = chosen { engine.plugins.selectInterfaceSize(size, for: slot) }
            }
    }

    private func storeSettings() {
        engine.plugins.store(into: store, only: slot, title: "Plugin Settings")
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
