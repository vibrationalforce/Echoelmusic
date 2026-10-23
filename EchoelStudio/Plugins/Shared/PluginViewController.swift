import CoreAudioKit
import EchoelCore
import SwiftUI
import UIKit

/// A unit the Echoel extension makes, and its lock. One purchase unlocks the instruments; the
/// effects are free (`needsPurchase` false) and never play as a demo.
protocol EchoelPluginUnit: AUAudioUnit {
    var title: String { get }
    var isUnlocked: Bool { get set }
    var needsPurchase: Bool { get }
    /// One line under the controls, for what the parameters cannot say (a note map).
    var help: String? { get }
}

extension EchoelPluginUnit {
    var help: String? { nil }
    var needsPurchase: Bool { true }
}

/// What the Echoel extension's principal class does: make the unit the host asks for, lock it
/// to the demo until the purchase is found, and show its controls. The subclass says only how
/// to make each unit.
class PluginViewController: AUViewController, AUAudioUnitFactory {
    private var audioUnit: (any EchoelPluginUnit)?
    private var hosting: UIHostingController<PluginControlsView>?

    /// Carries the new unit across threads: from the host's to the license check and the view.
    private final class UnitBox: @unchecked Sendable {
        let unit: any EchoelPluginUnit
        init(_ unit: any EchoelPluginUnit) { self.unit = unit }
    }

    /// Overridden by each extension. Called on the host's thread.
    nonisolated class func makeUnit(_ componentDescription: AudioComponentDescription) throws -> any EchoelPluginUnit {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_InvalidProperty))
    }

    /// Synchronous and nonisolated, as the protocol requires; the host calls it on any thread.
    /// The unit starts locked and is unlocked as soon as the purchase is found, well before the
    /// demo's first silence at 28 seconds.
    nonisolated func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try Self.makeUnit(componentDescription)
        let box = UnitBox(unit)
        guard unit.needsPurchase else {
            unit.isUnlocked = true
            Task { await MainActor.run { self.adopt(box.unit) } }
            return unit
        }
        unit.isUnlocked = false
        Task {
            let unlocked = await PluginLicense.isUnlocked()
            box.unit.isUnlocked = unlocked
            await MainActor.run { self.adopt(box.unit) }
        }
        return unit
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.07, alpha: 1)
        preferredContentSize = CGSize(width: 420, height: 480)
        if let audioUnit { show(audioUnit) }
    }

    private func adopt(_ unit: any EchoelPluginUnit) {
        audioUnit = unit
        if isViewLoaded { show(unit) }
    }

    private func show(_ unit: any EchoelPluginUnit) {
        if let hosting {
            hosting.willMove(toParent: nil)
            hosting.view.removeFromSuperview()
            hosting.removeFromParent()
        }
        guard let tree = unit.parameterTree else { return }
        let model: PluginControlsModel
        if let instrument = unit as? InstrumentAudioUnit, instrument.acceptsSamples {
            let sampler = PluginControlsModel(tree: tree, title: unit.title, isUnlocked: unit.isUnlocked, help: unit.help,
                                              sampleName: instrument.sample?.name,
                                              installSample: { buffer, name in instrument.installSample(buffer, name: name) })
            // A host's session restore or preset changes the sample without this window.
            instrument.observeSample { @Sendable [weak sampler] name in
                Task { @MainActor in sampler?.showSample(name) }
            }
            model = sampler
        } else {
            model = PluginControlsModel(tree: tree, title: unit.title, isUnlocked: unit.isUnlocked, help: unit.help)
        }
        let controller = UIHostingController(rootView: PluginControlsView(
            model: model, maximumSampleSeconds: InstrumentAudioUnit.maximumSampleSeconds,
            maximumSampleFrames: InstrumentAudioUnit.maximumSampleFrames))
        controller.view.backgroundColor = .clear
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        hosting = controller
    }
}
