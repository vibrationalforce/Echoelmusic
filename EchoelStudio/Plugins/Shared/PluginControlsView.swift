import AudioToolbox
import EchoelCore
import EchoelDSP
import EchoelHost
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// A plugin's controls, mirrored from its parameter tree: the host's automation moves them,
/// and moving them writes the tree. Shared by every Echoel extension.
@MainActor
@Observable
final class PluginControlsModel {
    private(set) var values: [AUParameterAddress: AUValue] = [:]
    let parameters: [AUParameter]
    let title: String
    /// False while the purchase is unknown; `unlock()` when the license check finds it.
    private(set) var isUnlocked: Bool
    let help: String?
    /// For a sampler: what it plays, and the last problem loading one.
    private(set) var sampleName: String?
    private(set) var sampleMessage: String?
    var acceptsSamples: Bool { installSample != nil }
    @ObservationIgnored private let installSample: ((SampleBuffer?, String) -> Void)?
    @ObservationIgnored private var token: AUParameterObserverToken?
    @ObservationIgnored private let tree: AUParameterTree

    init(tree: AUParameterTree, title: String, isUnlocked: Bool, help: String? = nil, sampleName: String? = nil,
         installSample: ((SampleBuffer?, String) -> Void)? = nil) {
        self.sampleName = sampleName
        self.installSample = installSample
        self.tree = tree
        self.title = title
        parameters = tree.allParameters
        self.isUnlocked = isUnlocked
        self.help = help
        for parameter in parameters { values[parameter.address] = parameter.value }
        token = tree.token(byAddingParameterObserver: { @Sendable [weak self] address, value in
            Task { @MainActor in self?.values[address] = value }
        })
    }

    /// Reads the file off the main thread, then hands it to the unit.
    func loadSample(from url: URL, maximumSeconds: Double, maximumFrames: Int) async {
        guard let installSample else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        // Decoded straight into the sample's own memory, as the app imports: an array on the way
        // held the file twice more beside the sample still playing, in an extension whose memory
        // limit is what the frame cap is for (fourth night review, critic).
        let result = await Task.detached { () throws -> SampleBuffer in
            let reader = try SampleFile.Reader(url, maximumSeconds: maximumSeconds, maximumFrames: maximumFrames)
            guard let buffer = try SampleBuffer(capacity: reader.frameCount, sampleRate: reader.sampleRate,
                                                fill: { try reader.read(into: $0) }) else { throw SampleFile.ReadError.empty }
            return buffer
        }.result
        let name = String(url.deletingPathExtension().lastPathComponent.prefix(60))
        do {
            installSample(try result.get(), name)
            sampleName = name
            sampleMessage = nil
        } catch SampleFile.ReadError.tooLong(let seconds) {
            sampleMessage = "This file is longer than \(Int(seconds)) seconds."
        } catch SampleFile.ReadError.empty {
            sampleMessage = "This file holds no audio."
        } catch is SampleBuffer.OutOfMemory {
            sampleMessage = "There is not enough free memory to load this file right now."
        } catch {
            sampleMessage = "This file is not an audio format Echoel can read."
        }
    }

    /// The purchase was found after the controls appeared: the demo text goes.
    func unlock() {
        isUnlocked = true
    }

    func clearSample() {
        installSample?(nil, "")
        sampleName = nil
        sampleMessage = nil
    }

    /// The unit's sample changed outside this window (a host restored its session or loaded a
    /// preset): name what plays now.
    func showSample(_ name: String?, notLoaded: Bool = false) {
        sampleName = name
        sampleMessage = notLoaded
            ? "Not loaded: there was not enough free memory. The host keeps it in its session; Clear removes it."
            : nil
    }

    func set(_ parameter: AUParameter, _ value: AUValue) {
        values[parameter.address] = value
        parameter.setValue(value, originator: token)
    }
}

struct PluginControlsView: View {
    let model: PluginControlsModel
    /// The longest sample the controls offer to load, in seconds and in frames (the frames bound
    /// the memory at a high sample rate).
    var maximumSampleSeconds: Double
    var maximumSampleFrames: Int
    @State private var importing = false

    /// Wide ranges (cutoff, times) move by ratio, so the low end is as reachable as the high.
    private static func isExponential(_ parameter: AUParameter) -> Bool {
        parameter.minValue > 0 && parameter.maxValue / parameter.minValue >= 100
    }

    static func position(of value: AUValue, in parameter: AUParameter) -> AUValue {
        let lo = parameter.minValue, hi = parameter.maxValue
        guard hi > lo else { return 0 }
        let v = Swift.min(Swift.max(value, lo), hi)
        return isExponential(parameter) ? logf(v / lo) / logf(hi / lo) : (v - lo) / (hi - lo)
    }

    static func value(at position: AUValue, in parameter: AUParameter) -> AUValue {
        let lo = parameter.minValue, hi = parameter.maxValue
        let p = Swift.min(Swift.max(position, 0), 1)
        return isExponential(parameter) ? lo * powf(hi / lo, p) : lo + p * (hi - lo)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                if !model.isUnlocked {
                    Text("Demo: two seconds of silence every thirty, until \(model.title) is unlocked in the Echoel app. The unlock is not on sale yet.")
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.6))
                }
                if model.acceptsSamples { sampleRow }
                ForEach(model.parameters, id: \.address) { parameter in
                    row(parameter)
                }
                if let help = model.help {
                    Text(help)
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.6))
                }
            }
            .padding(16)
        }
        .preferredColorScheme(.dark)
    }

    private var sampleRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model.sampleName ?? "No sample").font(.subheadline).foregroundStyle(.white).lineLimit(1)
                Spacer()
                if model.sampleName != nil {
                    Button("Clear") { model.clearSample() }
                }
                Button("Load Sample") { importing = true }
            }
            if let message = model.sampleMessage {
                Text(message).font(.caption).foregroundStyle(Color(white: 0.6))
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            Task { await model.loadSample(from: url, maximumSeconds: maximumSampleSeconds, maximumFrames: maximumSampleFrames) }
        }
    }

    @ViewBuilder private func row(_ parameter: AUParameter) -> some View {
        let value = model.values[parameter.address] ?? parameter.value
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(parameter.displayName).font(.subheadline).foregroundStyle(.white)
                Spacer()
                Text(parameter.string(fromValue: [value]))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(white: 0.6))
            }
            if let names = parameter.valueStrings {
                Picker(parameter.displayName, selection: Binding(
                    get: { Int(value.rounded()) },
                    set: { model.set(parameter, AUValue($0)) }
                )) {
                    ForEach(names.indices, id: \.self) { Text(names[$0]).tag($0) }
                }
                .pickerStyle(.segmented)
            } else if parameter.unit == .boolean {
                Toggle(parameter.displayName, isOn: Binding(get: { value >= 0.5 },
                                                            set: { model.set(parameter, $0 ? 1 : 0) }))
                    .labelsHidden()
            } else {
                Slider(value: Binding(get: { Self.position(of: value, in: parameter) },
                                      set: { model.set(parameter, Self.value(at: $0, in: parameter)) }),
                       in: 0...1)
                    .accessibilityLabel(parameter.displayName)
                    .accessibilityValue(parameter.string(fromValue: [value]))
            }
        }
    }
}
