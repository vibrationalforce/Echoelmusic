import AudioToolbox
import EchoelCore
import Observation
import SwiftUI

/// A plugin's controls, mirrored from its parameter tree: the host's automation moves them,
/// and moving them writes the tree. Shared by every Echoel extension.
@MainActor
@Observable
final class PluginControlsModel {
    private(set) var values: [AUParameterAddress: AUValue] = [:]
    let parameters: [AUParameter]
    let title: String
    let isUnlocked: Bool
    @ObservationIgnored private var token: AUParameterObserverToken?
    @ObservationIgnored private let tree: AUParameterTree

    init(tree: AUParameterTree, title: String, isUnlocked: Bool) {
        self.tree = tree
        self.title = title
        parameters = tree.allParameters
        self.isUnlocked = isUnlocked
        for parameter in parameters { values[parameter.address] = parameter.value }
        token = tree.token(byAddingParameterObserver: { @Sendable [weak self] address, value in
            Task { @MainActor in self?.values[address] = value }
        })
    }

    func set(_ parameter: AUParameter, _ value: AUValue) {
        values[parameter.address] = value
        parameter.setValue(value, originator: token)
    }
}

struct PluginControlsView: View {
    let model: PluginControlsModel

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
                    Text("Demo: two seconds of silence every thirty. Unlock \(model.title) in the Echoel app to remove it.")
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.6))
                }
                ForEach(model.parameters, id: \.address) { parameter in
                    row(parameter)
                }
            }
            .padding(16)
        }
        .preferredColorScheme(.dark)
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
