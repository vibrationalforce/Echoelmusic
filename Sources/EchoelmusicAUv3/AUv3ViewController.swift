//
//  AUv3ViewController.swift
//  EchoelmusicAUv3
//
//  Created: December 2025
//  AUv3 VIEW CONTROLLER
//  SwiftUI-based UI for Audio Unit hosts
//

import SwiftUI
import CoreAudioKit
import AudioToolbox

// MARK: - AUv3 View Controller

/// Main view controller for Echoelmusic Audio Units in hosts
public class EchoelmusicAUv3ViewController: AUViewController {

    // MARK: - Properties

    public var audioUnit: EchoelmusicAudioUnit? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.setupUI()
            }
        }
    }

    private var hostingController: UIHostingController<AnyView>?

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black

        if audioUnit != nil {
            setupUI()
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostingController?.view.frame = view.bounds
    }

    // MARK: - Setup

    private func setupUI() {
        guard let au = audioUnit else { return }

        // Remove existing hosting controller
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        // Create appropriate SwiftUI view based on AU type
        let swiftUIView: AnyView

        switch au.auType {
        case .instrument:
            swiftUIView = AnyView(
                TR808AUv3View(audioUnit: au)
                    .preferredColorScheme(.dark)
            )
        case .effect:
            swiftUIView = AnyView(
                StemSeparationAUv3View(audioUnit: au)
                    .preferredColorScheme(.dark)
            )
        case .midiProcessor:
            swiftUIView = AnyView(
                MIDIProcessorAUv3View(audioUnit: au)
                    .preferredColorScheme(.dark)
            )
        }

        // Create hosting controller
        let hosting = UIHostingController(rootView: swiftUIView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)

        hostingController = hosting
    }
}

// MARK: - TR-808 AUv3 View

struct TR808AUv3View: View {
    let audioUnit: EchoelmusicAudioUnit

    @State private var pitchGlideTime: Float = 0.08
    @State private var pitchGlideRange: Float = -12.0
    @State private var clickAmount: Float = 0.3
    @State private var decay: Float = 1.5
    @State private var drive: Float = 0.2
    @State private var filterCutoff: Float = 500
    @State private var gain: Float = 1.0

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("808")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading) {
                    Text("Pulse Drum Bass")
                        .font(.headline)
                    Text("Pitch Glide Synth")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)

            Divider()

            // Parameters
            ScrollView {
                VStack(spacing: 20) {
                    // Pitch Glide Section
                    parameterSection(title: "Pitch Glide", color: .orange) {
                        parameterSlider(
                            label: "Time",
                            value: $pitchGlideTime,
                            range: 0.01...0.5,
                            format: "%.0f ms",
                            multiplier: 1000,
                            address: .pitchGlideTime
                        )

                        parameterSlider(
                            label: "Range",
                            value: $pitchGlideRange,
                            range: -24...0,
                            format: "%.0f st",
                            address: .pitchGlideRange
                        )
                    }

                    // Envelope Section
                    parameterSection(title: "Envelope", color: .red) {
                        parameterSlider(
                            label: "Click",
                            value: $clickAmount,
                            range: 0...1,
                            format: "%.0f%%",
                            multiplier: 100,
                            address: .clickAmount
                        )

                        parameterSlider(
                            label: "Decay",
                            value: $decay,
                            range: 0.1...5,
                            format: "%.1f s",
                            address: .decay
                        )
                    }

                    // Tone Section
                    parameterSection(title: "Tone", color: .purple) {
                        parameterSlider(
                            label: "Drive",
                            value: $drive,
                            range: 0...1,
                            format: "%.0f%%",
                            multiplier: 100,
                            address: .drive
                        )

                        parameterSlider(
                            label: "Filter",
                            value: $filterCutoff,
                            range: 20...2000,
                            format: "%.0f Hz",
                            address: .filterCutoff
                        )
                    }

                    // Output
                    parameterSection(title: "Output", color: .green) {
                        parameterSlider(
                            label: "Gain",
                            value: $gain,
                            range: 0...2,
                            format: "%.0f%%",
                            multiplier: 100,
                            address: .gain
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color.black)
        .onAppear { loadParameters() }
    }

    private func loadParameters() {
        guard let tree = audioUnit.parameterTree else { return }

        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.pitchGlideTime.rawValue) {
            pitchGlideTime = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.pitchGlideRange.rawValue) {
            pitchGlideRange = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.clickAmount.rawValue) {
            clickAmount = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.decay.rawValue) {
            decay = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.drive.rawValue) {
            drive = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.filterCutoff.rawValue) {
            filterCutoff = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.gain.rawValue) {
            gain = param.value
        }
    }

    @ViewBuilder
    private func parameterSection<Content: View>(title: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(color)

            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }

    private func parameterSlider(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String,
        multiplier: Float = 1,
        address: EchoelmusicParameterAddress
    ) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)

            Slider(value: value, in: range)
                .onChange(of: value.wrappedValue) { newValue in
                    audioUnit.parameterTree?.parameter(withAddress: address.rawValue)?.value = newValue
                }

            Text(String(format: format, value.wrappedValue * multiplier))
                .font(.caption.monospacedDigit())
                .frame(width: 60, alignment: .trailing)
        }
    }
}

// MARK: - Stem Separation AUv3 View

struct StemSeparationAUv3View: View {
    let audioUnit: EchoelmusicAudioUnit

    @State private var vocalLevel: Float = 1.0
    @State private var drumLevel: Float = 1.0
    @State private var bassLevel: Float = 1.0
    @State private var otherLevel: Float = 1.0
    @State private var mix: Float = 1.0

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title)
                    .foregroundColor(.cyan)

                VStack(alignment: .leading) {
                    Text("Stem Splitter")
                        .font(.headline)
                    Text("AI Separation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)

            Divider()

            // Stem Faders
            HStack(spacing: 20) {
                stemFader(label: "VOX", value: $vocalLevel, color: .pink, address: .vocalLevel)
                stemFader(label: "DRM", value: $drumLevel, color: .orange, address: .drumLevel)
                stemFader(label: "BAS", value: $bassLevel, color: .purple, address: .bassLevel)
                stemFader(label: "OTH", value: $otherLevel, color: .cyan, address: .otherLevel)
            }
            .padding()

            Divider()

            // Mix control
            HStack {
                Text("Dry/Wet")
                    .font(.caption)

                Slider(value: $mix, in: 0...1)
                    .onChange(of: mix) { newValue in
                        audioUnit.parameterTree?.parameter(withAddress: EchoelmusicParameterAddress.mix.rawValue)?.value = newValue
                    }

                Text(String(format: "%.0f%%", mix * 100))
                    .font(.caption.monospacedDigit())
                    .frame(width: 40)
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color.black)
        .onAppear { loadParameters() }
    }

    private func loadParameters() {
        guard let tree = audioUnit.parameterTree else { return }

        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.vocalLevel.rawValue) {
            vocalLevel = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.drumLevel.rawValue) {
            drumLevel = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.bassLevel.rawValue) {
            bassLevel = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.otherLevel.rawValue) {
            otherLevel = param.value
        }
        if let param = tree.parameter(withAddress: EchoelmusicParameterAddress.mix.rawValue) {
            mix = param.value
        }
    }

    private func stemFader(label: String, value: Binding<Float>, color: Color, address: EchoelmusicParameterAddress) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(color)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: geo.size.height * CGFloat(min(1, value.wrappedValue)))
                }
            }
            .frame(width: 40)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newValue = Float(1 - gesture.location.y / 150)
                        value.wrappedValue = max(0, min(2, newValue))
                        audioUnit.parameterTree?.parameter(withAddress: address.rawValue)?.value = value.wrappedValue
                    }
            )

            Text(String(format: "%.0f", value.wrappedValue * 100))
                .font(.caption2.monospacedDigit())
        }
        .frame(height: 180)
    }
}

// MARK: - MIDI Processor AUv3 View

struct MIDIProcessorAUv3View: View {
    let audioUnit: EchoelmusicAudioUnit

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "pianokeys")
                    .font(.title)
                    .foregroundColor(.green)

                VStack(alignment: .leading) {
                    Text("MIDI Pro")
                        .font(.headline)
                    Text("MIDI 2.0 + MPE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)

            Divider()

            VStack(spacing: 12) {
                Text("MIDI 2.0 Processor")
                    .font(.title3)

                Text("Universal MIDI Packet support\nPer-Note Controllers\nMPE Zone Management")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)

                Text("Active")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding()

            Spacer()
        }
        .background(Color.black)
    }
}

// MARK: - Factory

/// Factory for creating Audio Unit view controllers
@objc(EchoelmusicAUv3ViewControllerFactory)
public class EchoelmusicAUv3ViewControllerFactory: NSObject, AUAudioUnitFactory {

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let auType: EchoelmusicAUType
        switch componentDescription.componentType {
        case kAudioUnitType_MusicDevice:
            auType = .instrument
        case kAudioUnitType_Effect:
            auType = .effect
        case kAudioUnitType_MIDIProcessor:
            auType = .midiProcessor
        default:
            auType = .effect
        }

        return try EchoelmusicAudioUnit(componentDescription: componentDescription, auType: auType)
    }

    public func requestViewController(completionHandler: @escaping (UIViewController?) -> Void) {
        completionHandler(EchoelmusicAUv3ViewController())
    }
}
