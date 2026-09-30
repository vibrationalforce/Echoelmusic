#if canImport(UIKit)
import UIKit
import CoreAudioKit
import SwiftUI
import Observation
import os

/// File-scope log handle: `createAudioUnit` runs nonisolated (host thread), so it
/// must not touch MainActor-isolated statics of the view controller.
private let auv3FactoryLog = OSLog(
    subsystem: "com.echoelmusic.app.auv3",
    category: "ViewController"
)

/// Minimal Sendable box to carry the (non-Sendable) freshly built AU across the
/// nonisolated-factory → MainActor-UI hop. Single producer, single consumer.
private struct AUBox: @unchecked Sendable { let value: EchoelmusicAudioUnit }

/// View controller for the AUv3 plugin UI in DAW hosts.
public final class AudioUnitViewController: AUViewController {

    private var audioUnit: EchoelmusicAudioUnit?
    private var parameterObservationToken: AUParameterObserverToken?
    private var hostingController: UIHostingController<AUv3PluginView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        preferredContentSize = CGSize(width: 400, height: 520)
        if let audioUnit { setupUI(audioUnit: audioUnit) }
    }

    /// Called from `createAudioUnit`'s MainActor hop once the AU exists.
    /// Hosts may create more than one AU per view controller — tear the previous
    /// UI + parameter observer down first, or children/observers stack up
    /// (concurrency review #3).
    private func adopt(_ au: EchoelmusicAudioUnit) {
        if let token = parameterObservationToken {
            audioUnit?.parameterTree?.removeParameterObserver(token)
            parameterObservationToken = nil
        }
        if let previous = hostingController {
            previous.willMove(toParent: nil)
            previous.view.removeFromSuperview()
            previous.removeFromParent()
            hostingController = nil
        }
        audioUnit = au
        if isViewLoaded { setupUI(audioUnit: au) }
    }

    private func setupUI(audioUnit: EchoelmusicAudioUnit) {
        guard let tree = audioUnit.parameterTree else { return }
        let vm = AUv3ViewModel(parameterTree: tree)

        parameterObservationToken = tree.token(
            byAddingParameterObserver: { [weak vm] (address, value) in
                Task { @MainActor in vm?.parameterChanged(address: address, value: value) }
            }
        )

        let pluginView = AUv3PluginView(viewModel: vm)
        let hosting = UIHostingController(rootView: pluginView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
    }
}

// MARK: - AUAudioUnitFactory (the extension's actual vending point)

/// REGISTRATION LAW twin (device log 2026-07-16, "ownAUv3 false"): the principal
/// class MUST conform to `AUAudioUnitFactory`, and the protocol's requirement is
/// SYNCHRONOUS `createAudioUnit(with:) throws`. The previous `async` method never
/// satisfied it — even a registered component could not be instantiated by any
/// host. The host may call this on any thread, so it is `nonisolated`; the AU
/// itself is a plain (nonisolated) AUAudioUnit subclass, and only the UI adoption
/// hops to the MainActor.
extension AudioUnitViewController: AUAudioUnitFactory {
    public nonisolated func createAudioUnit(
        with componentDescription: AudioComponentDescription
    ) throws -> AUAudioUnit {
        let au = try EchoelmusicAudioUnit(
            componentDescription: componentDescription, options: []
        )
        let box = AUBox(value: au)
        Task { @MainActor in self.adopt(box.value) }
        os_log(.info, log: auv3FactoryLog, "Audio unit created via factory")
        return au
    }
}

// MARK: - ViewModel

@MainActor @Observable
final class AUv3ViewModel {
    var coherence: Float = 0.5
    var hrv: Float = 0.5
    var heartRate: Float = 0.5
    var breathPhase: Float = 0.5
    var baseFrequency: Float = 220
    var textureAmount: Float = 0.3
    var reverbMix: Float = 0.3
    var masterGain: Float = 0.7

    private let parameterTree: AUParameterTree

    init(parameterTree: AUParameterTree) {
        self.parameterTree = parameterTree
        syncFromTree()
    }

    private func syncFromTree() {
        typealias Addr = EchoelmusicAudioUnit.ParameterAddress
        if let p = parameterTree.parameter(withAddress: Addr.coherence.rawValue) { coherence = p.value }
        if let p = parameterTree.parameter(withAddress: Addr.hrv.rawValue) { hrv = p.value }
        if let p = parameterTree.parameter(withAddress: Addr.heartRate.rawValue) { heartRate = p.value }
        if let p = parameterTree.parameter(withAddress: Addr.breathPhase.rawValue) { breathPhase = p.value }
        if let p = parameterTree.parameter(withAddress: Addr.baseFrequency.rawValue) { baseFrequency = p.value }
        if let p = parameterTree.parameter(withAddress: Addr.textureAmount.rawValue) { textureAmount = p.value }
        if let p = parameterTree.parameter(withAddress: Addr.reverbMix.rawValue) { reverbMix = p.value }
        if let p = parameterTree.parameter(withAddress: Addr.masterGain.rawValue) { masterGain = p.value }
    }

    func parameterChanged(address: AUParameterAddress, value: AUValue) {
        typealias Addr = EchoelmusicAudioUnit.ParameterAddress
        switch address {
        case Addr.coherence.rawValue: coherence = value
        case Addr.hrv.rawValue: hrv = value
        case Addr.heartRate.rawValue: heartRate = value
        case Addr.breathPhase.rawValue: breathPhase = value
        case Addr.baseFrequency.rawValue: baseFrequency = value
        case Addr.textureAmount.rawValue: textureAmount = value
        case Addr.reverbMix.rawValue: reverbMix = value
        case Addr.masterGain.rawValue: masterGain = value
        default: break
        }
    }

    func setParameter(address: UInt64, value: Float) {
        parameterTree.parameter(withAddress: address)?.value = value
    }

    /// The slider range IS the host-visible range: read from the tree, which is built from the
    /// canonical descriptors (`EchoelBodyVibeAUv3Mapping.resolve()`). The view used to restate
    /// all eight ranges and addresses as literals — a second spelling of the one mapping (#416)
    /// that nothing tied to the first. `setupParameterTree()` throws unless all eight
    /// parameters exist, so the unit range below is a type-level floor, not a live path.
    func range(for address: EchoelmusicAudioUnit.ParameterAddress) -> ClosedRange<Float> {
        guard let p = parameterTree.parameter(withAddress: address.rawValue),
              p.minValue.isFinite, p.maxValue.isFinite, p.minValue < p.maxValue else { return 0...1 }
        return p.minValue...p.maxValue
    }
}

// MARK: - SwiftUI Plugin View

struct AUv3PluginView: View {
    @Bindable var viewModel: AUv3ViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Echoelmusic")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 12)
                // ⛔ Until 2026-09-30 this line said "Bio-Reactive Instrument" and nothing more —
                // true of the engine, false of the situation: inside a host there is no body.
                // The four values below are HOST parameters that start at 0.5 and move only
                // when the host (automation, a MIDI/OSC bridge) moves them. The interface
                // audit's gap check named it ("Das AUv3-Plugin hat keinen Körper"); the
                // sentence now says who sets the body. `TheAUv3ViewSaysTheHostSetsTheBodyTests`.
                Text("Bio-reactive instrument · the host sets the body values")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.6))

                parameterSection("Body values (from the host)") {
                    paramSlider("Coherence", value: $viewModel.coherence,
                                address: .coherence, format: "%.0f%%") { $0 * 100 }
                    paramSlider("HRV", value: $viewModel.hrv,
                                address: .hrv, format: "%.0f%%") { $0 * 100 }
                    paramSlider("Heart Rate", value: $viewModel.heartRate,
                                address: .heartRate, format: "%.0f%%") { $0 * 100 }
                    paramSlider("Breath", value: $viewModel.breathPhase,
                                address: .breathPhase, format: "%.0f%%") { $0 * 100 }
                }

                parameterSection("Sound") {
                    paramSlider("Frequency", value: $viewModel.baseFrequency,
                                address: .baseFrequency, format: "%.0f Hz") { $0 }
                    paramSlider("Texture", value: $viewModel.textureAmount,
                                address: .textureAmount, format: "%.0f%%") { $0 * 100 }
                    paramSlider("Reverb", value: $viewModel.reverbMix,
                                address: .reverbMix, format: "%.0f%%") { $0 * 100 }
                    paramSlider("Gain", value: $viewModel.masterGain,
                                address: .masterGain, format: "%.0f%%") { $0 * 100 }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
    }

    @ViewBuilder
    private func parameterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // A plain section title. ⛔ Until 2026-09-30 this was an EYEBROW — `uppercased()`,
            // 11 pt bold, `.kerning(1.5)`, white 0.35 on the 0.05 background (2.8:1) — the
            // exact pattern the design rules ban (tiny uppercase with letter-spacing above a
            // heading) and a colour under the 4.5:1 text floor. The plug-in UI is exempt from
            // `EchoelValueField` only (it compiles without the app's theme), never from the bans
            // or the contrast floor. `TheAUv3ViewHasNoEyebrowTests` pins both.
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.7))
                .padding(.leading, 4)
            VStack(spacing: 6) { content() }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.1)))
        }
    }

    @ViewBuilder
    private func paramSlider(_ label: String, value: Binding<Float>,
                             address: EchoelmusicAudioUnit.ParameterAddress, format: String,
                             display: ((Float) -> Float)? = nil) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.6))
                .frame(width: 80, alignment: .leading) // ADAPTIVE-EXEMPT: fixed-point .system(size:) font in the host-sized plug-in UI; it does not scale with Dynamic Type
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: { value.wrappedValue = $0; viewModel.setParameter(address: address.rawValue, value: $0) }
            ), in: viewModel.range(for: address))
            .tint(Color(white: 0.4))
            Text(String(format: format, display?(value.wrappedValue) ?? value.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white: 0.6))
                .frame(width: 56, alignment: .trailing) // ADAPTIVE-EXEMPT: fixed-point .system(size:) font in the host-sized plug-in UI; it does not scale with Dynamic Type
        }
    }
}
#endif
