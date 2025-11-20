// EchoelmusicViewController.swift
// AUv3 Plugin UI for iOS
//
// Displays bio-reactive parameters and real-time biofeedback visualization
// Hosts in GarageBand, AUM, Cubasis, and other AUv3-compatible DAWs

import CoreAudioKit
import SwiftUI
import AVFoundation

/// Main view controller for AUv3 plugin UI
public class EchoelmusicViewController: AUViewController {

    // MARK: - Properties

    /// Reference to the audio unit
    private var audioUnit: EchoelmusicAudioUnit?

    /// SwiftUI hosting controller
    private var hostingController: UIHostingController<EchoelmusicPluginView>?

    // MARK: - View Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Set preferred content size (width, height)
        preferredContentSize = CGSize(width: 400, height: 600)

        // Setup SwiftUI view
        setupSwiftUIView()
    }

    private func setupSwiftUIView() {
        // Create SwiftUI view
        let pluginView = EchoelmusicPluginView(audioUnit: audioUnit)

        // Create hosting controller
        let hosting = UIHostingController(rootView: pluginView)
        hostingController = hosting

        // Add as child view controller
        addChild(hosting)
        view.addSubview(hosting.view)

        // Setup constraints
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hosting.didMove(toParent: self)
    }

    // MARK: - Audio Unit Connection

    /// Called when audio unit is set by the host
    public var au: AUAudioUnit? {
        didSet {
            audioUnit = au as? EchoelmusicAudioUnit

            // Update SwiftUI view with audio unit
            if let audioUnit = audioUnit {
                let pluginView = EchoelmusicPluginView(audioUnit: audioUnit)
                hostingController?.rootView = pluginView
            }
        }
    }
}

// MARK: - SwiftUI Plugin View

struct EchoelmusicPluginView: View {

    // MARK: - Properties

    /// Reference to audio unit (optional, may be nil during preview)
    let audioUnit: EchoelmusicAudioUnit?

    /// Parameter values (observed from audio unit)
    @State private var filterCutoff: Float = 1000.0
    @State private var reverbSize: Float = 0.5
    @State private var delayTime: Float = 500.0
    @State private var delayFeedback: Float = 0.3
    @State private var modulationRate: Float = 1.0
    @State private var modulationDepth: Float = 0.5
    @State private var bioVolume: Float = 1.0
    @State private var hrvSensitivity: Float = 0.7
    @State private var coherenceSensitivity: Float = 0.7

    /// Current preset
    @State private var selectedPreset: Int = 0

    /// Bio-feedback status
    @State private var heartRate: Int = 72
    @State private var hrvValue: Double = 50.0
    @State private var coherenceLevel: Double = 0.5

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView

                    // Bio-Feedback Status
                    bioFeedbackView

                    // Presets
                    presetsView

                    // DSP Parameters
                    dspParametersView

                    // Bio-Sensitivity Controls
                    bioSensitivityView

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .onAppear {
            loadParametersFromAudioUnit()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Echoelmusic")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Bio-Reactive Audio")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Bio-Feedback View

    private var bioFeedbackView: some View {
        VStack(spacing: 12) {
            Text("Biofeedback Status")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                // Heart Rate
                bioMetricCard(
                    title: "Heart Rate",
                    value: "\(heartRate)",
                    unit: "BPM",
                    color: .red
                )

                // HRV
                bioMetricCard(
                    title: "HRV",
                    value: String(format: "%.1f", hrvValue),
                    unit: "ms",
                    color: .green
                )

                // Coherence
                bioMetricCard(
                    title: "Coherence",
                    value: String(format: "%.1f%%", coherenceLevel * 100),
                    unit: "",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func bioMetricCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(color.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Presets View

    private var presetsView: some View {
        VStack(spacing: 12) {
            Text("Presets")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Preset", selection: $selectedPreset) {
                Text("Relaxed State").tag(0)
                Text("Focused State").tag(1)
                Text("Creative Flow").tag(2)
                Text("Deep Meditation").tag(3)
                Text("High Energy").tag(4)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedPreset) { newValue in
                loadPreset(newValue)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - DSP Parameters View

    private var dspParametersView: some View {
        VStack(spacing: 16) {
            Text("DSP Effects")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Filter Cutoff
            parameterSlider(
                label: "Filter Cutoff",
                value: $filterCutoff,
                range: 20...20000,
                unit: "Hz",
                logarithmic: true
            )

            // Reverb Size
            parameterSlider(
                label: "Reverb Size",
                value: $reverbSize,
                range: 0...1,
                unit: ""
            )

            // Delay Time
            parameterSlider(
                label: "Delay Time",
                value: $delayTime,
                range: 0...2000,
                unit: "ms"
            )

            // Delay Feedback
            parameterSlider(
                label: "Delay Feedback",
                value: $delayFeedback,
                range: 0...0.95,
                unit: ""
            )

            // Modulation Rate
            parameterSlider(
                label: "Modulation Rate",
                value: $modulationRate,
                range: 0.1...10,
                unit: "Hz"
            )

            // Modulation Depth
            parameterSlider(
                label: "Modulation Depth",
                value: $modulationDepth,
                range: 0...1,
                unit: ""
            )

            // Bio Volume
            parameterSlider(
                label: "Bio Volume",
                value: $bioVolume,
                range: 0...1,
                unit: ""
            )
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Bio-Sensitivity View

    private var bioSensitivityView: some View {
        VStack(spacing: 16) {
            Text("Bio-Sensitivity")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            // HRV Sensitivity
            parameterSlider(
                label: "HRV Sensitivity",
                value: $hrvSensitivity,
                range: 0...1,
                unit: ""
            )

            // Coherence Sensitivity
            parameterSlider(
                label: "Coherence Sensitivity",
                value: $coherenceSensitivity,
                range: 0...1,
                unit: ""
            )
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Parameter Slider

    private func parameterSlider(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        unit: String,
        logarithmic: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Text(formatParameterValue(value.wrappedValue, unit: unit, logarithmic: logarithmic))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            Slider(value: value, in: range) { editing in
                if !editing {
                    updateAudioUnitParameter(label: label, value: value.wrappedValue)
                }
            }
            .accentColor(.cyan)
        }
    }

    // MARK: - Helper Functions

    private func formatParameterValue(_ value: Float, unit: String, logarithmic: Bool) -> String {
        if logarithmic {
            return String(format: "%.0f %@", value, unit)
        } else if value < 1.0 {
            return String(format: "%.2f %@", value, unit)
        } else if value < 10.0 {
            return String(format: "%.1f %@", value, unit)
        } else {
            return String(format: "%.0f %@", value, unit)
        }
    }

    private func loadParametersFromAudioUnit() {
        guard let au = audioUnit, let paramTree = au.parameterTree else { return }

        // Load parameter values
        if let param = paramTree.parameter(withAddress: 0) {
            filterCutoff = param.value
        }
        if let param = paramTree.parameter(withAddress: 1) {
            reverbSize = param.value
        }
        if let param = paramTree.parameter(withAddress: 2) {
            delayTime = param.value
        }
        if let param = paramTree.parameter(withAddress: 3) {
            delayFeedback = param.value
        }
        if let param = paramTree.parameter(withAddress: 4) {
            modulationRate = param.value
        }
        if let param = paramTree.parameter(withAddress: 5) {
            modulationDepth = param.value
        }
        if let param = paramTree.parameter(withAddress: 6) {
            bioVolume = param.value
        }
        if let param = paramTree.parameter(withAddress: 7) {
            hrvSensitivity = param.value
        }
        if let param = paramTree.parameter(withAddress: 8) {
            coherenceSensitivity = param.value
        }
    }

    private func updateAudioUnitParameter(label: String, value: Float) {
        guard let au = audioUnit, let paramTree = au.parameterTree else { return }

        // Map label to parameter address
        let address: AUParameterAddress
        switch label {
        case "Filter Cutoff": address = 0
        case "Reverb Size": address = 1
        case "Delay Time": address = 2
        case "Delay Feedback": address = 3
        case "Modulation Rate": address = 4
        case "Modulation Depth": address = 5
        case "Bio Volume": address = 6
        case "HRV Sensitivity": address = 7
        case "Coherence Sensitivity": address = 8
        default: return
        }

        // Update parameter
        if let param = paramTree.parameter(withAddress: address) {
            param.value = value
        }
    }

    private func loadPreset(_ presetNumber: Int) {
        guard let au = audioUnit else { return }

        // Load factory preset
        let preset = AUAudioUnitPreset()
        preset.number = presetNumber
        preset.name = ["Relaxed State", "Focused State", "Creative Flow", "Deep Meditation", "High Energy"][presetNumber]

        au.currentPreset = preset

        // Reload parameters from audio unit
        loadParametersFromAudioUnit()
    }
}

// MARK: - Preview

struct EchoelmusicPluginView_Previews: PreviewProvider {
    static var previews: some View {
        EchoelmusicPluginView(audioUnit: nil)
            .previewLayout(.fixed(width: 400, height: 600))
    }
}
