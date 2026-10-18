import CoreAudioKit
import EchoelCore
import EchoelEngine
import SwiftUI
import UIKit

/// The Echoel Effects extension's principal class. One extension carries the four standard
/// effects; the host's component description says which one to make.
public final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    private var audioUnit: StandardEffectUnit?
    private var hosting: UIHostingController<PluginControlsView>?

    /// Carries the new unit across threads: from the host's to the license check and the view.
    private final class UnitBox: @unchecked Sendable {
        let unit: StandardEffectUnit
        init(_ unit: StandardEffectUnit) { self.unit = unit }
    }

    /// Synchronous and nonisolated, as the protocol requires; the host calls it on any thread.
    /// The unit starts locked and is unlocked as soon as the purchase is found, well before the
    /// demo's first silence at 28 seconds.
    public nonisolated func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try StandardEffectUnit(componentDescription: componentDescription, options: [])
        unit.isUnlocked = false
        let box = UnitBox(unit)
        Task {
            let unlocked = await PluginLicense.isUnlocked(.effects)
            box.unit.isUnlocked = unlocked
            await MainActor.run { self.adopt(box.unit) }
        }
        return unit
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.07, alpha: 1)
        preferredContentSize = CGSize(width: 420, height: 420)
        if let audioUnit { show(audioUnit) }
    }

    private func adopt(_ unit: StandardEffectUnit) {
        audioUnit = unit
        if isViewLoaded { show(unit) }
    }

    private func show(_ unit: StandardEffectUnit) {
        if let hosting {
            hosting.willMove(toParent: nil)
            hosting.view.removeFromSuperview()
            hosting.removeFromParent()
        }
        guard let tree = unit.parameterTree else { return }
        let model = PluginControlsModel(tree: tree, title: unit.effect.extensionComponent.name,
                                        isUnlocked: unit.isUnlocked)
        let controller = UIHostingController(rootView: PluginControlsView(model: model))
        controller.view.backgroundColor = .clear
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        hosting = controller
    }
}
