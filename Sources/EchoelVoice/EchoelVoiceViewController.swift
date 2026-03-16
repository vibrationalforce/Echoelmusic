#if canImport(UIKit)
import UIKit
import CoreAudioKit
import SwiftUI
import Observation
import QuartzCore
import os

/// View controller for the EchoelVoice AUv3 plugin UI
///
/// Hosts a SwiftUI view with:
/// - Pitch correction controls (key, scale, speed, strength)
/// - Harmony controls (intervals, mix)
/// - CIE 1931 spectral color visualization (audio → visible light)
/// - Real-time pitch/note display
public final class EchoelVoiceViewController: AUViewController {

    private static let auLog = OSLog(
        subsystem: "com.echoelmusic.voice.auv3",
        category: "ViewController"
    )

    private var audioUnit: EchoelVoiceAudioUnit?
    private var parameterObservationToken: AUParameterObserverToken?
    private var hostingController: UIHostingController<EchoelVoicePluginView>?

    // MARK: - AUViewController

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)
        preferredContentSize = CGSize(width: 480, height: 720)

        if let audioUnit {
            setupUI(audioUnit: audioUnit)
        }
    }

    public override func createAudioUnit(
        with componentDescription: AudioComponentDescription
    ) async throws -> AUAudioUnit {
        let au = try EchoelVoiceAudioUnit(
            componentDescription: componentDescription,
            options: []
        )
        self.audioUnit = au

        if isViewLoaded {
            setupUI(audioUnit: au)
        }

        os_log(.info, log: Self.auLog, "EchoelVoice audio unit created via view controller")
        return au
    }

    // MARK: - UI Setup

    private func setupUI(audioUnit: EchoelVoiceAudioUnit) {
        guard let parameterTree = audioUnit.parameterTree else { return }

        let viewModel = EchoelVoiceViewModel(
            parameterTree: parameterTree,
            kernel: audioUnit.dspKernel
        )

        parameterObservationToken = parameterTree.token(
            byAddingParameterObserver: { [weak viewModel] address, value in
                Task { @MainActor in
                    viewModel?.parameterChanged(address: address, value: value)
                }
            }
        )

        let pluginView = EchoelVoicePluginView(viewModel: viewModel)
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
final class EchoelVoiceViewModel {

    // Pitch Correction
    var correctionSpeed: Float = 50.0
    var correctionStrength: Float = 0.8
    var rootNote: Float = 0
    var scaleType: Float = 0
    var transpose: Float = 0
    var humanize: Float = 0.2

    // Formant
    var formantShift: Float = 0.0

    // Harmony
    var harmonyMix: Float = 0.0
    var harmonyInterval1: Float = 4.0
    var harmonyInterval2: Float = 7.0

    // Gain
    var inputGain: Float = 1.0
    var outputGain: Float = 1.0
    var dryWet: Float = 1.0

    // Spectral visualization (read from kernel)
    var spectralColor: CIE1931SpectralMapper.SpectralColor = .black
    var dominantFrequency: Float = 0
    var rmsLevel: Float = 0

    private let parameterTree: AUParameterTree
    private let kernel: VocalDSPKernel
    private var spectralTimer: Timer?

    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static let scaleNames = [
        "Chromatic", "Major", "Minor", "Harm. Minor", "Mel. Minor",
        "Pent. Maj", "Pent. Min", "Blues", "Dorian", "Phrygian",
        "Lydian", "Mixolydian", "Locrian", "Whole Tone", "Diminished",
        "Augmented", "Arabian", "Japanese", "Hungarian"
    ]

    init(parameterTree: AUParameterTree, kernel: VocalDSPKernel) {
        self.parameterTree = parameterTree
        self.kernel = kernel
        syncFromTree()
        startSpectralTimer()
    }

    private func syncFromTree() {
        if let p = parameterTree.parameter(withAddress: 0) { correctionSpeed = p.value }
        if let p = parameterTree.parameter(withAddress: 1) { correctionStrength = p.value }
        if let p = parameterTree.parameter(withAddress: 2) { rootNote = p.value }
        if let p = parameterTree.parameter(withAddress: 3) { scaleType = p.value }
        if let p = parameterTree.parameter(withAddress: 4) { formantShift = p.value }
        if let p = parameterTree.parameter(withAddress: 5) { harmonyMix = p.value }
        if let p = parameterTree.parameter(withAddress: 6) { harmonyInterval1 = p.value }
        if let p = parameterTree.parameter(withAddress: 7) { harmonyInterval2 = p.value }
        if let p = parameterTree.parameter(withAddress: 8) { inputGain = p.value }
        if let p = parameterTree.parameter(withAddress: 9) { outputGain = p.value }
        if let p = parameterTree.parameter(withAddress: 10) { dryWet = p.value }
        if let p = parameterTree.parameter(withAddress: 11) { transpose = p.value }
        if let p = parameterTree.parameter(withAddress: 12) { humanize = p.value }
    }

    func parameterChanged(address: AUParameterAddress, value: AUValue) {
        switch address {
        case 0: correctionSpeed = value
        case 1: correctionStrength = value
        case 2: rootNote = value
        case 3: scaleType = value
        case 4: formantShift = value
        case 5: harmonyMix = value
        case 6: harmonyInterval1 = value
        case 7: harmonyInterval2 = value
        case 8: inputGain = value
        case 9: outputGain = value
        case 10: dryWet = value
        case 11: transpose = value
        case 12: humanize = value
        default: break
        }
    }

    func setParameter(address: UInt64, value: Float) {
        parameterTree.parameter(withAddress: address)?.value = value
    }

    // MARK: - Spectral Update Timer

    private func startSpectralTimer() {
        spectralTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSpectral()
            }
        }
    }

    private func updateSpectral() {
        spectralColor = CIE1931SpectralMapper.bandsToColor(kernel.spectralBands)
        dominantFrequency = kernel.dominantFrequency
        rmsLevel = kernel.rmsLevel
    }

    func stopTimer() {
        spectralTimer?.invalidate()
        spectralTimer = nil
    }
}

// MARK: - SwiftUI Plugin View

@MainActor
struct EchoelVoicePluginView: View {
    @Bindable var viewModel: EchoelVoiceViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Text("EchoelVoice")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.top, 8)

                Text("Bio-Reactive Vocal Processor")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(white: 0.45))

                // Spectral Color Display
                spectralDisplay

                // Pitch Correction
                parameterSection("Pitch") {
                    keyScalePicker
                    parameterSlider("Speed", value: $viewModel.correctionSpeed, range: 0...200,
                                    address: 0, format: "%.0f ms")
                    parameterSlider("Strength", value: $viewModel.correctionStrength, range: 0...1,
                                    address: 1, format: "%.0f%%") { $0 * 100 }
                    parameterSlider("Transpose", value: $viewModel.transpose, range: -24...24,
                                    address: 11, format: "%+.0f st")
                    parameterSlider("Humanize", value: $viewModel.humanize, range: 0...1,
                                    address: 12, format: "%.0f%%") { $0 * 100 }
                }

                // Formant
                parameterSection("Formant") {
                    parameterSlider("Shift", value: $viewModel.formantShift, range: -12...12,
                                    address: 4, format: "%+.1f st")
                }

                // Harmony
                parameterSection("Harmony") {
                    parameterSlider("Mix", value: $viewModel.harmonyMix, range: 0...1,
                                    address: 5, format: "%.0f%%") { $0 * 100 }
                    parameterSlider("Voice 1", value: $viewModel.harmonyInterval1, range: -12...12,
                                    address: 6, format: "%+.0f st")
                    parameterSlider("Voice 2", value: $viewModel.harmonyInterval2, range: -12...12,
                                    address: 7, format: "%+.0f st")
                }

                // Gain
                parameterSection("Output") {
                    parameterSlider("Input", value: $viewModel.inputGain, range: 0...2,
                                    address: 8, format: "%.2f")
                    parameterSlider("Output", value: $viewModel.outputGain, range: 0...2,
                                    address: 9, format: "%.2f")
                    parameterSlider("Dry/Wet", value: $viewModel.dryWet, range: 0...1,
                                    address: 10, format: "%.0f%%") { $0 * 100 }
                }

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(red: 0.02, green: 0.02, blue: 0.05))
    }

    // MARK: - Spectral Color Display

    @ViewBuilder
    private var spectralDisplay: some View {
        let c = viewModel.spectralColor
        let brightness = max(0.05, c.brightness)

        VStack(spacing: 6) {
            // Color orb
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: Double(c.r), green: Double(c.g), blue: Double(c.b))
                                    .opacity(Double(brightness)),
                                Color(red: Double(c.r * 0.3), green: Double(c.g * 0.3), blue: Double(c.b * 0.3))
                                    .opacity(Double(brightness * 0.3)),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // Frequency readout
                VStack(spacing: 2) {
                    if viewModel.dominantFrequency > 50 {
                        Text(String(format: "%.0f Hz", viewModel.dominantFrequency))
                            .font(.system(size: 24, weight: .light, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))

                        let wavelength = CIE1931SpectralMapper.frequencyToWavelength(
                            viewModel.dominantFrequency
                        )
                        Text(String(format: "%.0f nm", wavelength))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text("—")
                            .font(.system(size: 24, weight: .light, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }

            // Level meter
            GeometryReader { geo in
                let width = geo.size.width
                let level = CGFloat(min(1.0, viewModel.rmsLevel * 3.0))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.15))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                Color(
                                    red: Double(c.r * brightness),
                                    green: Double(c.g * brightness),
                                    blue: Double(c.b * brightness)
                                )
                            )
                            .frame(width: width * level)
                    }
            }
            .frame(height: 4)
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Key/Scale Picker

    @ViewBuilder
    private var keyScalePicker: some View {
        HStack(spacing: 12) {
            // Key picker
            VStack(alignment: .leading, spacing: 2) {
                Text("KEY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))

                HStack(spacing: 4) {
                    ForEach(0..<12, id: \.self) { note in
                        let isSelected = Int(viewModel.rootNote) == note
                        let isSharp = [1, 3, 6, 8, 10].contains(note)
                        Button {
                            viewModel.rootNote = Float(note)
                            viewModel.setParameter(address: 2, value: Float(note))
                        } label: {
                            Text(EchoelVoiceViewModel.noteNames[note])
                                .font(.system(size: isSharp ? 8 : 9, weight: .medium, design: .monospaced))
                                .foregroundColor(isSelected ? .white : Color(white: 0.5))
                                .frame(width: isSharp ? 22 : 26, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isSelected ?
                                              Color(red: 0.3, green: 0.5, blue: 0.9) :
                                              Color(white: 0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        // Scale picker (simplified as stepper)
        HStack(spacing: 8) {
            Text("SCALE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
                .frame(width: 44, alignment: .leading)

            Button {
                let idx = max(0, Int(viewModel.scaleType) - 1)
                viewModel.scaleType = Float(idx)
                viewModel.setParameter(address: 3, value: Float(idx))
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.5))
            }
            .buttonStyle(.plain)

            let scaleIdx = min(Int(viewModel.scaleType), EchoelVoiceViewModel.scaleNames.count - 1)
            Text(EchoelVoiceViewModel.scaleNames[max(0, scaleIdx)])
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)

            Button {
                let idx = min(EchoelVoiceViewModel.scaleNames.count - 1, Int(viewModel.scaleType) + 1)
                viewModel.scaleType = Float(idx)
                viewModel.setParameter(address: 3, value: Float(idx))
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Section

    @ViewBuilder
    private func parameterSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
                .padding(.leading, 4)

            VStack(spacing: 5) {
                content()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(white: 0.14), lineWidth: 1)
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
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(white: 0.65))
                .frame(width: 72, alignment: .leading)

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
            .tint(Color(red: 0.3, green: 0.5, blue: 0.9))

            let displayValue = displayTransform?(value.wrappedValue) ?? value.wrappedValue
            Text(String(format: format, displayValue))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(Color(white: 0.45))
                .frame(width: 56, alignment: .trailing)
        }
    }
}
#endif
