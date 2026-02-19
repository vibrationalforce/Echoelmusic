//
//  AUv3ViewController.swift
//  EchoelmusicAUv3
//
//  Created: December 2025
//  AUv3 VIEW CONTROLLER
//  SwiftUI-based UI for Audio Unit hosts — dispatches by pluginID
//  Platform-safe: iOS (UIHostingController) + macOS (NSHostingView)
//

import SwiftUI
import CoreAudioKit
import AudioToolbox

// MARK: - AUv3 View Controller

/// Main view controller for Echoelmusic Audio Units in hosts.
/// Dispatches to the correct SwiftUI view based on the plugin's identity.
public class EchoelmusicAUv3ViewController: AUViewController {

    // MARK: - Properties

    public var audioUnit: EchoelmusicAudioUnit? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.setupUI()
            }
        }
    }

    #if canImport(UIKit)
    private var hostingController: UIHostingController<AnyView>?
    #elseif canImport(AppKit)
    private var hostingView: NSHostingView<AnyView>?
    #endif

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        #if canImport(UIKit)
        // True black (#000000) — echoelmusic.com website CI
        view.backgroundColor = .black
        #elseif canImport(AppKit)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        #endif

        if audioUnit != nil {
            setupUI()
        }
    }

    #if canImport(UIKit)
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostingController?.view.frame = view.bounds
    }
    #elseif canImport(AppKit)
    public override func viewDidLayout() {
        super.viewDidLayout()
        hostingView?.frame = view.bounds
    }
    #endif

    // MARK: - Setup

    private func setupUI() {
        guard let au = audioUnit else { return }

        let swiftUIView: AnyView = createViewForPlugin(au)

        #if canImport(UIKit)
        // Remove existing hosting controller
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        let hosting = UIHostingController(rootView: swiftUIView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)

        hostingController = hosting
        #elseif canImport(AppKit)
        // Remove existing hosting view
        hostingView?.removeFromSuperview()

        let hosting = NSHostingView(rootView: swiftUIView)
        hosting.frame = view.bounds
        hosting.autoresizingMask = [.width, .height]
        view.addSubview(hosting)

        hostingView = hosting
        #endif
    }

    /// Creates the appropriate SwiftUI view for a given audio unit's plugin identity
    private func createViewForPlugin(_ au: EchoelmusicAudioUnit) -> AnyView {
        if let pluginID = au.pluginID {
            switch pluginID {
            // Instruments
            case .echoelSynth:
                return AnyView(TR808AUv3View(audioUnit: au).preferredColorScheme(.dark))
            case .echoelBio:
                return AnyView(BinauralAUv3View(audioUnit: au).preferredColorScheme(.dark))

            // Effects — each plugin gets its own dedicated view
            case .echoelFX:
                return AnyView(ReverbAUv3View(audioUnit: au).preferredColorScheme(.dark))
            case .echoelMix:
                return AnyView(CompressorAUv3View(audioUnit: au).preferredColorScheme(.dark))
            case .echoelField:
                return AnyView(FilterAUv3View(audioUnit: au).preferredColorScheme(.dark))
            case .echoelMind:
                return AnyView(ConsoleAUv3View(audioUnit: au).preferredColorScheme(.dark))

            // MIDI Processors
            case .echoelSeq, .echoelMIDI, .echoelBeam, .echoelNet:
                return AnyView(MIDIProcessorAUv3View(audioUnit: au).preferredColorScheme(.dark))
            }
        }

        // Fallback by AU type when pluginID is unknown
        switch au.auType {
        case .instrument:
            return AnyView(TR808AUv3View(audioUnit: au).preferredColorScheme(.dark))
        case .effect:
            return AnyView(ReverbAUv3View(audioUnit: au).preferredColorScheme(.dark))
        case .midiProcessor:
            return AnyView(MIDIProcessorAUv3View(audioUnit: au).preferredColorScheme(.dark))
        }
    }
}

// MARK: - Shared Components (use AUv3Theme.swift for styling)

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
        VStack(spacing: 0) {
            AUv3PluginHeader(icon: "waveform.path", title: "EchoelSynth", subtitle: "TR-808 Bass Synthesizer")

            BrandDivider()

            ScrollView {
                VStack(spacing: 16) {
                    AUParameterSection(title: "Pitch Glide", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Time", value: $pitchGlideTime, range: 0.01...0.5,
                                          format: "%.0f ms", multiplier: 1000, address: .pitchGlideTime, audioUnit: audioUnit)
                        AUParameterSlider(label: "Range", value: $pitchGlideRange, range: -24...0,
                                          format: "%.0f st", address: .pitchGlideRange, audioUnit: audioUnit)
                    }

                    AUParameterSection(title: "Envelope", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Click", value: $clickAmount, range: 0...1,
                                          format: "%.0f%%", multiplier: 100, address: .clickAmount, audioUnit: audioUnit)
                        AUParameterSlider(label: "Decay", value: $decay, range: 0.1...5,
                                          format: "%.1f s", address: .decay, audioUnit: audioUnit)
                    }

                    AUParameterSection(title: "Tone", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Drive", value: $drive, range: 0...1,
                                          format: "%.0f%%", multiplier: 100, address: .drive, audioUnit: audioUnit)
                        AUParameterSlider(label: "Filter", value: $filterCutoff, range: 20...2000,
                                          format: "%.0f Hz", address: .filterCutoff, audioUnit: audioUnit)
                    }

                    AUParameterSection(title: "Output", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Gain", value: $gain, range: 0...2,
                                          format: "%.0f%%", multiplier: 100, address: .gain, audioUnit: audioUnit)
                    }
                }
                .padding()
            }
        }
        .background(AUv3Brand.bgDeep)
        .onAppear { loadParameters() }
    }

    private func loadParameters() {
        guard let tree = audioUnit.parameterTree else { return }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.pitchGlideTime.rawValue) { pitchGlideTime = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.pitchGlideRange.rawValue) { pitchGlideRange = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.clickAmount.rawValue) { clickAmount = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.decay.rawValue) { decay = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.drive.rawValue) { drive = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.filterCutoff.rawValue) { filterCutoff = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.gain.rawValue) { gain = p.value }
    }
}

// MARK: - Reverb AUv3 View (EchoelFX)

struct ReverbAUv3View: View {
    let audioUnit: EchoelmusicAudioUnit

    @State private var wetDry: Float = 30.0
    @State private var roomSize: Float = 50.0
    @State private var damping: Float = 50.0
    @State private var gain: Float = 1.0

    var body: some View {
        VStack(spacing: 0) {
            AUv3PluginHeader(icon: "waveform.badge.magnifyingglass", title: "EchoelFX", subtitle: "Freeverb Algorithmic Reverb")

            BrandDivider()

            ScrollView {
                VStack(spacing: 16) {
                    AUParameterSection(title: "Reverb", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Wet/Dry", value: $wetDry, range: 0...100,
                                          format: "%.0f%%", address: .reverbWetDry, audioUnit: audioUnit)
                        AUParameterSlider(label: "Room", value: $roomSize, range: 0...100,
                                          format: "%.0f%%", address: .reverbRoomSize, audioUnit: audioUnit)
                        AUParameterSlider(label: "Damping", value: $damping, range: 0...100,
                                          format: "%.0f%%", address: .reverbDamping, audioUnit: audioUnit)
                    }

                    AUParameterSection(title: "Output", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Gain", value: $gain, range: 0...2,
                                          format: "%.0f%%", multiplier: 100, address: .gain, audioUnit: audioUnit)
                    }
                }
                .padding()
            }
        }
        .background(AUv3Brand.bgDeep)
        .onAppear { loadParameters() }
    }

    private func loadParameters() {
        guard let tree = audioUnit.parameterTree else { return }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.reverbWetDry.rawValue) { wetDry = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.reverbRoomSize.rawValue) { roomSize = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.reverbDamping.rawValue) { damping = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.gain.rawValue) { gain = p.value }
    }
}

// MARK: - Compressor AUv3 View (EchoelMix)

struct CompressorAUv3View: View {
    let audioUnit: EchoelmusicAudioUnit

    @State private var threshold: Float = -20.0
    @State private var ratio: Float = 4.0
    @State private var attack: Float = 10.0
    @State private var release: Float = 100.0
    @State private var makeupGain: Float = 0.0
    @State private var knee: Float = 6.0

    var body: some View {
        VStack(spacing: 0) {
            AUv3PluginHeader(icon: "gauge.with.needle", title: "EchoelMix", subtitle: "Analog Compressor")

            BrandDivider()

            ScrollView {
                VStack(spacing: 16) {
                    AUParameterSection(title: "Dynamics", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Threshold", value: $threshold, range: -60...0,
                                          format: "%.1f dB", address: .compThreshold, audioUnit: audioUnit)
                        AUParameterSlider(label: "Ratio", value: $ratio, range: 1...20,
                                          format: "%.1f:1", address: .compRatio, audioUnit: audioUnit)
                        AUParameterSlider(label: "Knee", value: $knee, range: 0...20,
                                          format: "%.1f dB", address: .compKnee, audioUnit: audioUnit)
                    }

                    AUParameterSection(title: "Timing", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Attack", value: $attack, range: 0.1...200,
                                          format: "%.1f ms", address: .compAttack, audioUnit: audioUnit)
                        AUParameterSlider(label: "Release", value: $release, range: 10...2000,
                                          format: "%.0f ms", address: .compRelease, audioUnit: audioUnit)
                    }

                    AUParameterSection(title: "Output", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Makeup", value: $makeupGain, range: 0...24,
                                          format: "%.1f dB", address: .compMakeupGain, audioUnit: audioUnit)
                    }
                }
                .padding()
            }
        }
        .background(AUv3Brand.bgDeep)
        .onAppear { loadParameters() }
    }

    private func loadParameters() {
        guard let tree = audioUnit.parameterTree else { return }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.compThreshold.rawValue) { threshold = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.compRatio.rawValue) { ratio = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.compAttack.rawValue) { attack = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.compRelease.rawValue) { release = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.compMakeupGain.rawValue) { makeupGain = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.compKnee.rawValue) { knee = p.value }
    }
}

// MARK: - Filter AUv3 View (EchoelField)

struct FilterAUv3View: View {
    let audioUnit: EchoelmusicAudioUnit

    @State private var frequency: Float = 1000.0
    @State private var resonance: Float = 1.0
    @State private var filterMode: Float = 0.0
    @State private var gain: Float = 1.0

    private let modeNames = ["Low Pass", "High Pass", "Band Pass", "Notch"]

    var body: some View {
        VStack(spacing: 0) {
            AUv3PluginHeader(icon: "slider.horizontal.below.rectangle", title: "EchoelField", subtitle: "Multi-Mode Biquad Filter")

            BrandDivider()

            ScrollView {
                VStack(spacing: 16) {
                    AUParameterSection(title: "Filter Mode", color: AUv3Brand.textPrimary) {
                        HStack(spacing: 8) {
                            ForEach(0..<4) { index in
                                AUv3PillButton(
                                    label: modeNames[index],
                                    isSelected: Int(filterMode) == index
                                ) {
                                    filterMode = Float(index)
                                    audioUnit.parameterTree?.parameter(
                                        withAddress: EchoelmusicParameterAddress.filterMode.rawValue
                                    )?.value = filterMode
                                }
                            }
                        }
                    }

                    AUParameterSection(title: "Parameters", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Freq", value: $frequency, range: 20...20000,
                                          format: "%.0f Hz", address: .filterFrequency, audioUnit: audioUnit)
                        AUParameterSlider(label: "Reso", value: $resonance, range: 0.1...20,
                                          format: "%.1f Q", address: .filterResonance, audioUnit: audioUnit)
                    }

                    AUParameterSection(title: "Output", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Gain", value: $gain, range: 0...2,
                                          format: "%.0f%%", multiplier: 100, address: .gain, audioUnit: audioUnit)
                    }
                }
                .padding()
            }
        }
        .background(AUv3Brand.bgDeep)
        .onAppear { loadParameters() }
    }

    private func loadParameters() {
        guard let tree = audioUnit.parameterTree else { return }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.filterFrequency.rawValue) { frequency = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.filterResonance.rawValue) { resonance = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.filterMode.rawValue) { filterMode = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.gain.rawValue) { gain = p.value }
    }
}

// MARK: - Console Emulation AUv3 View (EchoelMind)

struct ConsoleAUv3View: View {
    let audioUnit: EchoelmusicAudioUnit

    @State private var legend: Float = 0.0
    @State private var vibe: Float = 50.0
    @State private var blend: Float = 100.0

    private let legendNames = ["SSL VCA", "API Thrust", "Neve", "Pultec",
                                "Fairchild", "LA-2A", "1176", "Manley"]

    var body: some View {
        VStack(spacing: 0) {
            AUv3PluginHeader(icon: "dial.medium", title: "EchoelMind", subtitle: "Analog Console Emulation")

            BrandDivider()

            ScrollView {
                VStack(spacing: 16) {
                    AUParameterSection(title: "Console Legend", color: AUv3Brand.textPrimary) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                            ForEach(0..<8) { index in
                                AUv3PillButton(
                                    label: legendNames[index],
                                    isSelected: Int(legend) == index
                                ) {
                                    legend = Float(index)
                                    audioUnit.parameterTree?.parameter(
                                        withAddress: EchoelmusicParameterAddress.consoleLegend.rawValue
                                    )?.value = legend
                                }
                            }
                        }
                    }

                    AUParameterSection(title: "Character", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Vibe", value: $vibe, range: 0...100,
                                          format: "%.0f%%", address: .consoleVibe, audioUnit: audioUnit)
                        AUParameterSlider(label: "Blend", value: $blend, range: 0...100,
                                          format: "%.0f%%", address: .consoleBlend, audioUnit: audioUnit)
                    }
                }
                .padding()
            }
        }
        .background(AUv3Brand.bgDeep)
        .onAppear { loadParameters() }
    }

    private func loadParameters() {
        guard let tree = audioUnit.parameterTree else { return }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.consoleLegend.rawValue) { legend = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.consoleVibe.rawValue) { vibe = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.consoleBlend.rawValue) { blend = p.value }
    }
}

// MARK: - Binaural Beat AUv3 View (EchoelBio)

struct BinauralAUv3View: View {
    let audioUnit: EchoelmusicAudioUnit

    @State private var carrier: Float = 432.0
    @State private var beat: Float = 10.0
    @State private var amplitude: Float = 0.7

    private let brainwavePresets: [(name: String, freq: Float)] = [
        ("Delta", 2.0), ("Theta", 6.0), ("Alpha", 10.0), ("Beta", 20.0), ("Gamma", 40.0)
    ]

    var body: some View {
        VStack(spacing: 0) {
            AUv3PluginHeader(icon: "brain.head.profile", title: "EchoelBio", subtitle: "Binaural Beat Generator")

            BrandDivider()

            ScrollView {
                VStack(spacing: 16) {
                    AUParameterSection(title: "Brainwave State", color: AUv3Brand.textPrimary) {
                        HStack(spacing: 8) {
                            ForEach(0..<brainwavePresets.count, id: \.self) { index in
                                let preset = brainwavePresets[index]
                                Button(action: {
                                    beat = preset.freq
                                    audioUnit.parameterTree?.parameter(
                                        withAddress: EchoelmusicParameterAddress.binauralBeat.rawValue
                                    )?.value = beat
                                }) {
                                    VStack(spacing: 2) {
                                        Text(preset.name)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        Text("\(Int(preset.freq)) Hz")
                                            .font(.system(size: 9, design: .monospaced))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(abs(beat - preset.freq) < 0.5 ? AUv3Brand.accent : AUv3Brand.bgElevated)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(abs(beat - preset.freq) < 0.5 ? Color.clear : AUv3Brand.border, lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(abs(beat - preset.freq) < 0.5 ? AUv3Brand.bgDeep : AUv3Brand.textSecondary)
                                }
                            }
                        }
                    }

                    AUParameterSection(title: "Parameters", color: AUv3Brand.textPrimary) {
                        AUParameterSlider(label: "Carrier", value: $carrier, range: 100...1000,
                                          format: "%.0f Hz", address: .binauralCarrier, audioUnit: audioUnit)
                        AUParameterSlider(label: "Beat", value: $beat, range: 0.5...50,
                                          format: "%.1f Hz", address: .binauralBeat, audioUnit: audioUnit)
                        AUParameterSlider(label: "Volume", value: $amplitude, range: 0...1,
                                          format: "%.0f%%", multiplier: 100, address: .binauralAmplitude, audioUnit: audioUnit)
                    }
                }
                .padding()
            }
        }
        .background(AUv3Brand.bgDeep)
        .onAppear { loadParameters() }
    }

    private func loadParameters() {
        guard let tree = audioUnit.parameterTree else { return }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.binauralCarrier.rawValue) { carrier = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.binauralBeat.rawValue) { beat = p.value }
        if let p = tree.parameter(withAddress: EchoelmusicParameterAddress.binauralAmplitude.rawValue) { amplitude = p.value }
    }
}

// MARK: - MIDI Processor AUv3 View

struct MIDIProcessorAUv3View: View {
    let audioUnit: EchoelmusicAudioUnit

    var body: some View {
        VStack(spacing: 0) {
            AUv3PluginHeader(icon: "pianokeys", title: audioUnit.pluginID?.displayName ?? "MIDI Pro", subtitle: "MIDI 2.0 + MPE")

            BrandDivider()

            VStack(spacing: 16) {
                Spacer()

                Text("MIDI 2.0 PROCESSOR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AUv3Brand.textSecondary)
                    .tracking(2)

                VStack(spacing: 4) {
                    Text("Universal MIDI Packet support")
                    Text("Per-Note Controllers")
                    Text("MPE Zone Management")
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AUv3Brand.textTertiary)

                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(AUv3Brand.accent)

                Text("Active")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(AUv3Brand.textPrimary)

                Spacer()
            }
            .padding()
        }
        .background(AUv3Brand.bgDeep)
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

    #if canImport(UIKit)
    public func requestViewController(completionHandler: @escaping (UIViewController?) -> Void) {
        completionHandler(EchoelmusicAUv3ViewController())
    }
    #elseif canImport(AppKit)
    public func requestViewController(completionHandler: @escaping (NSViewController?) -> Void) {
        completionHandler(EchoelmusicAUv3ViewController())
    }
    #endif
}
