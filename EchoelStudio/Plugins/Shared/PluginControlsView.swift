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
            VStack(alignment: .leading, spacing: EchoelBrand.Space.m) {
                Text(model.title)
                    .font(EchoelBrand.Font.title)
                    .foregroundStyle(EchoelBrand.Color.text)
                    .accessibilityAddTraits(.isHeader)
                if !model.isUnlocked {
                    Text("Demo: two seconds of silence every 30 seconds. Echoel Plugins in the Echoel app unlocks \(model.title) and shows whether it is on sale; reload it here after buying.")
                        .font(EchoelBrand.Font.caption)
                        .foregroundStyle(EchoelBrand.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.acceptsSamples { sampleRow }
                ForEach(model.parameters, id: \.address) { parameter in
                    row(parameter)
                }
                if let help = model.help {
                    Text(help)
                        .font(EchoelBrand.Font.caption)
                        .foregroundStyle(EchoelBrand.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(EchoelBrand.Space.l)
        }
        .background(EchoelBrand.Color.background)
        .tint(EchoelBrand.Color.accent)
        .preferredColorScheme(.dark)
    }

    private var sampleRow: some View {
        VStack(alignment: .leading, spacing: EchoelBrand.Space.xs) {
            HStack(spacing: EchoelBrand.Space.s) {
                Text(model.sampleName ?? "No Sample")
                    .font(EchoelBrand.Font.label)
                    .foregroundStyle(model.sampleName == nil ? EchoelBrand.Color.textSecondary : EchoelBrand.Color.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if model.sampleName != nil {
                    Button("Clear") { model.clearSample() }
                        .buttonStyle(PluginButtonStyle())
                        .accessibilityLabel("Clear Sample")
                }
                Button("Load Sample…") { importing = true }
                    .buttonStyle(PluginButtonStyle())
            }
            if let message = model.sampleMessage {
                Text(message)
                    .font(EchoelBrand.Font.caption)
                    .foregroundStyle(EchoelBrand.Color.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            Task { await model.loadSample(from: url, maximumSeconds: maximumSampleSeconds, maximumFrames: maximumSampleFrames) }
        }
    }

    @ViewBuilder private func row(_ parameter: AUParameter) -> some View {
        let value = model.values[parameter.address] ?? parameter.value
        if let names = parameter.valueStrings {
            VStack(alignment: .leading, spacing: EchoelBrand.Space.xs) {
                Text(parameter.displayName)
                    .font(EchoelBrand.Font.caption)
                    .foregroundStyle(EchoelBrand.Color.textSecondary)
                Picker(parameter.displayName, selection: Binding(
                    get: { Int(value.rounded()) },
                    set: { model.set(parameter, AUValue($0)) }
                )) {
                    ForEach(names.indices, id: \.self) { Text(names[$0]).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: EchoelBrand.touch)
            }
        } else if parameter.unit == .boolean {
            Toggle(isOn: Binding(get: { value >= 0.5 }, set: { model.set(parameter, $0 ? 1 : 0) })) {
                Text(parameter.displayName)
                    .font(EchoelBrand.Font.label)
                    .foregroundStyle(EchoelBrand.Color.text)
            }
            .tint(EchoelBrand.Color.accent)
            .frame(minHeight: EchoelBrand.touch)
        } else {
            PluginValueField(parameter: parameter, value: value) { model.set(parameter, $0) }
        }
    }
}

/// Echoel's value field in the plugin window, drawn as the Studio's `ParameterField`: the name
/// above, the number below, a thin bar for where it sits in its range, a strong boundary that turns
/// green while a finger holds it. Drag up or down — slowly for fine steps, quickly to cover the
/// range (`DragPrecision`, the Studio's own rule). It writes the parameter tree, never a song.
/// Typing a value stays in the Studio: its number pad writes through the song's store, which a
/// plugin in a foreign host does not have.
private struct PluginValueField: View {
    let parameter: AUParameter
    let value: AUValue
    let set: (AUValue) -> Void
    /// The drag in progress: the control position it has reached and the translation last read.
    @State private var drag: (position: AUValue, translation: CGFloat)?

    /// Points of vertical travel for the full range at full speed (as in the Studio).
    private static let travel: CGFloat = 240

    var body: some View {
        let position = PluginControlsView.position(of: value, in: parameter)
        let text = parameter.string(fromValue: [value])
        let engaged = drag != nil
        VStack(alignment: .leading, spacing: EchoelBrand.Space.xs) {
            Text(parameter.displayName)
                .font(EchoelBrand.Font.caption)
                .foregroundStyle(EchoelBrand.Color.textSecondary)
                .lineLimit(1)
            Text(text)
                .font(EchoelBrand.Font.value)
                .foregroundStyle(engaged ? EchoelBrand.Color.accent : EchoelBrand.Color.text)
                .lineLimit(1)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(EchoelBrand.Color.surfaceRaised)
                    Rectangle().fill(EchoelBrand.Color.accent)
                        .frame(width: geometry.size.width * CGFloat(position))
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
        .padding(EchoelBrand.Space.s)
        .frame(maxWidth: .infinity, minHeight: EchoelBrand.touch, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: EchoelBrand.Radius.medium).fill(EchoelBrand.Color.surface))
        .overlay(RoundedRectangle(cornerRadius: EchoelBrand.Radius.medium)
            .strokeBorder(engaged ? EchoelBrand.Color.accent : EchoelBrand.Color.borderStrong, lineWidth: 1))
        .animation(EchoelBrand.Motion.quick, value: engaged)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { gesture in
                    let reached = drag ?? (position: position, translation: 0)
                    let moved = gesture.translation.height - reached.translation
                    let scale = AUValue(DragPrecision.scale(speed: Double(gesture.velocity.height)))
                    let next = Swift.min(Swift.max(reached.position - AUValue(moved / Self.travel) * scale, 0), 1)
                    drag = (position: next, translation: gesture.translation.height)
                    set(PluginControlsView.value(at: next, in: parameter))
                }
                .onEnded { _ in drag = nil }
        )
        .accessibilityElement()
        .accessibilityLabel(parameter.displayName)
        .accessibilityValue(text)
        .accessibilityAdjustableAction { direction in
            let step: AUValue = direction == .increment ? 0.02 : -0.02
            set(PluginControlsView.value(at: position + step, in: parameter))
        }
    }
}

/// The Studio's tool button, for the plugin window: a solid fill, an 8 pt radius, a hairline
/// boundary, the brand face, and opacity on press — never scale.
private struct PluginButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EchoelBrand.Font.label)
            .foregroundStyle(EchoelBrand.Color.text)
            .padding(.horizontal, EchoelBrand.Space.m)
            .frame(minHeight: EchoelBrand.touch)
            .background(RoundedRectangle(cornerRadius: EchoelBrand.Radius.medium).fill(EchoelBrand.Color.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: EchoelBrand.Radius.medium)
                .strokeBorder(EchoelBrand.Color.border, lineWidth: 1))
            .opacity(configuration.isPressed ? EchoelBrand.Motion.pressedOpacity : 1)
            .animation(EchoelBrand.Motion.quick, value: configuration.isPressed)
    }
}
