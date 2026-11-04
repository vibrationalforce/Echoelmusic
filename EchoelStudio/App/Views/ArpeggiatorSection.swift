import EchoelCore
import SwiftUI

/// An instrument track's arpeggiator, on its Sound page (EDIT-2): a switch, then its rate, order,
/// octaves, gate and latch. Every change is one `Command.setArpeggio` through the one door, so it
/// undoes like every edit; a drag on Gate is one undo step. It plays the notes the track holds —
/// its clips and the keys played into it — and adds none of its own.
struct ArpeggiatorSection: View {
    @Environment(ProjectStore.self) private var store
    let track: Track

    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 150

    /// The settings shown: the track's, or the defaults while it has none.
    private var settings: Arpeggio {
        if let arpeggio = track.arpeggio { return arpeggio }
        var off = Arpeggio()
        off.isOn = false
        return off
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Toggle(isOn: Binding(get: { settings.isOn }, set: { on in change { $0.isOn = on } })) {
                Text("Arpeggiator").font(Theme.Font.body).foregroundStyle(Theme.Color.text)
            }
            .frame(minHeight: Theme.Size.touch)
            .accessibilityHint("Plays the notes this track holds one after another on the song's grid.")
            if settings.isOn { controls }
        }
    }

    @ViewBuilder private var controls: some View {
        Picker("Rate", selection: Binding(get: { settings.rate }, set: { rate in change { $0.rate = rate } })) {
            ForEach(ArpRate.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Rate")
        Picker("Order", selection: Binding(get: { settings.order }, set: { order in change { $0.order = order } })) {
            ForEach(ArpOrder.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Order")
        if let later = settings.unrecognizedOrder ?? settings.unrecognizedRate {
            Text("“\(later)” comes from a later version of Echoel Studio and plays as Up, 1/16 here.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: Theme.Space.s)],
                  alignment: .leading, spacing: Theme.Space.s) {
            SettingField(title: "Octaves", value: settings.octaves, range: Arpeggio.octaveRange, standard: 1,
                         spokenUnit: settings.octaves == 1 ? "octave" : "octaves") { octaves in
                change { $0.octaves = octaves }
            }
            SettingField(title: "Gate", value: Int((settings.gate * 100).rounded()), range: 5...100, unit: "%",
                         standard: 50, spokenUnit: "percent of each step",
                         commit: { percent in
                             change(coalescing: "arpeggio.gate.\(track.id)") { $0.gate = Double(percent) / 100 }
                         },
                         ended: { store.endGesture() })
        }
        Toggle(isOn: Binding(get: { settings.latch }, set: { latch in change { $0.latch = latch } })) {
            Text("Latch").font(Theme.Font.body).foregroundStyle(Theme.Color.text)
        }
        .frame(minHeight: Theme.Size.touch)
        .accessibilityHint("Keys keep playing after you let go, until the next chord.")
    }

    /// One edit of the settings as one command; a drag passes a key so it undoes in one step.
    private func change(coalescing key: String? = nil, _ edit: (inout Arpeggio) -> Void) {
        var next = settings
        edit(&next)
        try? store.perform(.setArpeggio(track.id, next), coalescingKey: key)
    }
}
