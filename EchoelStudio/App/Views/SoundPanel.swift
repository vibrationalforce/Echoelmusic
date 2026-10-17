import EchoelCore
import SwiftUI

/// An instrument track's sound: a preset to start from, then every synth parameter.
struct SoundPanel: View {
    @Environment(ProjectStore.self) private var store
    let track: Track

    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 150

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                devicePicker
                if track.instrument.device == .drums {
                    Text("General MIDI drum kit: Kick 36, Snare 38, Clap 39, Low Tom 45, Closed Hat 42, High Tom 50, Open Hat 46, Crash 49.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                } else {
                    synthControls
                }
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Color.background)
    }

    private var devicePicker: some View {
        Picker("Instrument", selection: Binding(
            get: { track.instrument.device },
            set: { try? store.perform(.setInstrumentDevice(track.id, $0)) }
        )) {
            ForEach(InstrumentDevice.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Instrument")
    }

    @ViewBuilder private var synthControls: some View {
        Menu {
            ForEach(InstrumentPreset.all, id: \.name) { preset in
                Button(preset.name) { try? store.perform(.loadInstrumentPreset(track.id, name: preset.name)) }
            }
        } label: {
            HStack {
                Text("Preset").foregroundStyle(Theme.Color.textSecondary)
                Text(track.instrument.preset).foregroundStyle(Theme.Color.text)
                Image(systemName: "chevron.down").foregroundStyle(Theme.Color.textSecondary)
                    .accessibilityHidden(true)
            }
            .font(Theme.Font.body)
            .frame(minHeight: Theme.Size.touch)
        }
        .accessibilityLabel("Preset \(track.instrument.preset)")

        waveformPicker

        LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: Theme.Space.s)],
                  alignment: .leading, spacing: Theme.Space.s) {
            ForEach(SynthParameter.all.filter { $0.unit != .choice }, id: \.key) { parameter in
                ParameterField(address: ParameterAddress(.track(track.id), parameter.key))
            }
        }
    }

    private var waveformPicker: some View {
        let parameter = SynthParameter.waveform
        let current = Int(track.instrument.value(parameter).rounded())
        return Picker(parameter.title, selection: Binding(
            get: { current },
            set: { try? store.perform(.setInstrumentParameter(track.id, key: parameter.key.rawValue, value: Double($0))) }
        )) {
            ForEach(parameter.choices.indices, id: \.self) { Text(parameter.choices[$0]).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(parameter.title)
    }
}
