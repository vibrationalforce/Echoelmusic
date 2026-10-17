import CoreAudioKit
import SwiftUI
import UIKit

/// The extension's principal class: it makes the Audio Unit for the host and shows its controls.
public final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    private var audioUnit: EchoelSynthAudioUnit?
    private var hosting: UIHostingController<SynthPluginView>?

    /// Carries the new unit from the host's thread to the main thread.
    private final class UnitBox: @unchecked Sendable {
        let unit: EchoelSynthAudioUnit
        init(_ unit: EchoelSynthAudioUnit) { self.unit = unit }
    }

    /// Synchronous and nonisolated: that is the protocol's requirement, and the host calls it on
    /// any thread. Only adopting the unit for the view hops to the main actor.
    public nonisolated func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try EchoelSynthAudioUnit(componentDescription: componentDescription, options: [])
        let box = UnitBox(unit)
        Task { @MainActor in self.adopt(box.unit) }
        return unit
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.07, alpha: 1)
        preferredContentSize = CGSize(width: 420, height: 480)
        if let audioUnit { show(audioUnit) }
    }

    private func adopt(_ unit: EchoelSynthAudioUnit) {
        audioUnit = unit
        if isViewLoaded { show(unit) }
    }

    private func show(_ unit: EchoelSynthAudioUnit) {
        if let hosting {
            hosting.willMove(toParent: nil)
            hosting.view.removeFromSuperview()
            hosting.removeFromParent()
        }
        guard let tree = unit.parameterTree else { return }
        let controller = UIHostingController(rootView: SynthPluginView(model: SynthPluginModel(tree: tree, unit: unit)))
        controller.view.backgroundColor = .clear
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        hosting = controller
    }
}
