import EchoelCore
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
        .task(id: engine.plugins.revision) {
            guard controller == nil else { return }
            let found = await engine.plugins.interface(for: slot)
            controller = found
            hasNoInterface = found == nil && engine.plugins.isLoaded(slot)
        }
        .onDisappear(perform: storeSettings)
    }

    private func storeSettings() {
        let commands = engine.plugins.captureCommands(for: store.project, only: slot)
        try? store.perform(commands, title: "Plugin Settings")
    }

    /// The plugin's preferred height, kept between a usable minimum and most of a phone screen.
    private static func height(of controller: UIViewController) -> CGFloat {
        let preferred = controller.preferredContentSize.height
        return preferred > 0 ? min(max(preferred, 240), 560) : 360
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
