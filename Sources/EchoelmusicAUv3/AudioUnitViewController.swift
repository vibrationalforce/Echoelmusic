#if canImport(UIKit)
import UIKit
import CoreAudioKit
import SwiftUI
import os

/// View controller for the AUv3 plugin UI
///
/// Hosts a SwiftUI view inside the standard CoreAudioKit
/// `AUViewController` container. The host DAW presents this
/// view when the user opens the plugin window.
public final class AudioUnitViewController: AUViewController {

    private static let auLog = OSLog(
        subsystem: "com.echoelmusic.app.auv3",
        category: "ViewController"
    )

    private var audioUnit: EchoelmusicAudioUnit?
    private var parameterObservationToken: AUParameterObserverToken?
    private var hostingController: UIHostingController<AUv3PluginView>?

    // MARK: - AUViewController

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)

        // Preferred size for host DAW window
        preferredContentSize = CGSize(width: 480, height: 640)

        if let audioUnit {
            setupUI(audioUnit: audioUnit)
        }
    }

    /// Called by the host to provide the audio unit instance
    public override func createAudioUnit(
        with componentDescription: AudioComponentDescription
    ) async throws -> AUAudioUnit {
        let au = try EchoelmusicAudioUnit(
            componentDescription: componentDescription,
            options: []
        )
        self.audioUnit = au

        if isViewLoaded {
            setupUI(audioUnit: au)
        }

        os_log(.info, log: Self.auLog, "Audio unit created via view controller")
        return au
    }

    // MARK: - UI Setup

    private func setupUI(audioUnit: EchoelmusicAudioUnit) {
        guard let parameterTree = audioUnit.parameterTree else { return }

        let viewModel = AUv3ViewModel(parameterTree: parameterTree)

        // Observe parameter changes from host automation
        parameterObservationToken = parameterTree.token(
            byAddingParameterObserver: { [weak viewModel] address, value in
                Task { @MainActor in
                    viewModel?.parameterChanged(address: address, value: value)
                }
            }
        )

        let pluginView = AUv3PluginView(viewModel: viewModel)
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

// MARK: - ViewModel

@MainActor
@Observable
final class AUv3ViewModel {
    var wetDry: Float = 0.3
    var roomSize: Float = 0.5
    var damping: Float = 0.5
    var delayTime: Float = 0.25
    var feedback: Float = 0.4
    var filterCutoff: Float = 8000.0
    var filterResonance: Float = 0.707
    var inputGain: Float = 1.0
    var outputGain: Float = 1.0

    private let parameterTree: AUParameterTree

    init(parameterTree: AUParameterTree) {
        self.parameterTree = parameterTree

        // Read initial values
        syncFromTree()
    }

    private func syncFromTree() {
        if let p = parameterTree.parameter(withAddress: 0) { wetDry = p.value }
        if let p = parameterTree.parameter(withAddress: 1) { roomSize = p.value }
        if let p = parameterTree.parameter(withAddress: 2) { damping = p.value }
        if let p = parameterTree.parameter(withAddress: 3) { delayTime = p.value }
        if let p = parameterTree.parameter(withAddress: 4) { feedback = p.value }
        if let p = parameterTree.parameter(withAddress: 5) { filterCutoff = p.value }
        if let p = parameterTree.parameter(withAddress: 6) { filterResonance = p.value }
        if let p = parameterTree.parameter(withAddress: 7) { inputGain = p.value }
        if let p = parameterTree.parameter(withAddress: 8) { outputGain = p.value }
    }

    func parameterChanged(address: AUParameterAddress, value: AUValue) {
        switch address {
        case 0: wetDry = value
        case 1: roomSize = value
        case 2: damping = value
        case 3: delayTime = value
        case 4: feedback = value
        case 5: filterCutoff = value
        case 6: filterResonance = value
        case 7: inputGain = value
        case 8: outputGain = value
        default: break
        }
    }

    func setParameter(address: UInt64, value: Float) {
        parameterTree.parameter(withAddress: address)?.value = value
    }
}

// MARK: - SwiftUI Plugin View

struct AUv3PluginView: View {
    @Bindable var viewModel: AUv3ViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                Text("Echoelmusic")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.top, 12)

                Text("Bio-Reactive Audio Processor")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(white: 0.5))

                // Gain
                parameterSection("Gain") {
                    parameterSlider("Input", value: $viewModel.inputGain, range: 0...2,
                                    address: 7, format: "%.2f")
                    parameterSlider("Output", value: $viewModel.outputGain, range: 0...2,
                                    address: 8, format: "%.2f")
                }

                // Reverb
                parameterSection("Reverb") {
                    parameterSlider("Wet/Dry", value: $viewModel.wetDry, range: 0...1,
                                    address: 0, format: "%.0f%%") { $0 * 100 }
                    parameterSlider("Room Size", value: $viewModel.roomSize, range: 0...1,
                                    address: 1, format: "%.0f%%") { $0 * 100 }
                    parameterSlider("Damping", value: $viewModel.damping, range: 0...1,
                                    address: 2, format: "%.0f%%") { $0 * 100 }
                }

                // Delay
                parameterSection("Delay") {
                    parameterSlider("Time", value: $viewModel.delayTime, range: 0.01...2,
                                    address: 3, format: "%.0f ms") { $0 * 1000 }
                    parameterSlider("Feedback", value: $viewModel.feedback, range: 0...0.9,
                                    address: 4, format: "%.0f%%") { $0 * 100 }
                }

                // Filter
                parameterSection("Filter") {
                    parameterSlider("Cutoff", value: $viewModel.filterCutoff, range: 20...20000,
                                    address: 5, format: "%.0f Hz") { $0 }
                    parameterSlider("Resonance", value: $viewModel.filterResonance, range: 0.1...20,
                                    address: 6, format: "%.2f") { $0 }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
    }

    // MARK: - Section

    @ViewBuilder
    private func parameterSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
                .padding(.leading, 4)

            VStack(spacing: 6) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(white: 0.18), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Slider

    @ViewBuilder
    private func parameterSlider(
        _ label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        address: UInt64,
        format: String,
        displayTransform: ((Float) -> Float)? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.7))
                .frame(width: 80, alignment: .leading)

            Slider(
                value: Binding(
                    get: { value.wrappedValue },
                    set: { newValue in
                        value.wrappedValue = newValue
                        viewModel.setParameter(address: address, value: newValue)
                    }
                ),
                in: range
            )
            .tint(Color(red: 0.4, green: 0.6, blue: 1.0))

            let displayValue = displayTransform?(value.wrappedValue) ?? value.wrappedValue
            Text(String(format: format, displayValue))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 64, alignment: .trailing)
        }
    }
}
#endif
