import EchoelCore
import EchoelEngine
import SwiftUI

/// A modulation route as a row of the arrangement, under its track's automation lanes (Michael on
/// 10083: "Die Modulation sollte auch in der automation wieder zu finden sein"). Before, a route
/// lived only inside two levels of the Modulate menu, and after it was made nothing showed it.
/// Here it is one row: its name on the left; on the right its depth as a value field in tenths of
/// a percent (drag, type, or VoiceOver swipe), on or off, the source centred or from zero, and
/// remove. Every change is one undo step through the one door; a drag of the depth is one step.
struct ModulationName: View {
    @Environment(ProjectStore.self) private var store
    let route: ModulationRoute

    var body: some View {
        Text(Self.title(of: route, in: store.project))
            .font(Theme.Font.caption)
            .foregroundStyle(route.enabled ? Theme.Color.textSecondary : Theme.Color.textTertiary)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .padding(.leading, Theme.Space.l)
            .padding(.trailing, Theme.Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Theme.Size.trackRowHeight)
            .background(Theme.Color.background)
            .accessibilityLabel("Modulation, " + Self.title(of: route, in: store.project))
    }

    /// "Heart Rate → Cutoff": the source and the value it moves, no depth (the row shows it).
    static func title(of route: ModulationRoute, in project: Project) -> String {
        let source = ModulateMenu.sources.first { $0.0 == route.source }?.1 ?? route.source.rawValue
        let target = project.descriptor(for: route.target)?.title ?? route.target.description
        return "\(source) → \(target)"
    }
}

struct ModulationLane: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    let route: ModulationRoute

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            SettingField(title: "Depth", value: Int((route.depth * 1_000).rounded()), range: -1_000...1_000,
                         unit: "%", decimals: 1, adjustStep: 10, standard: 250, spokenUnit: "percent", commit: { tenths in
                var changed = route
                changed.depth = Double(tenths) / 1_000
                try? store.perform(.setModRoute(changed), coalescingKey: "modulation.depth.\(route.id)")
            }, ended: { store.endGesture() })
            .frame(width: 150)
            Toggle("On", isOn: Binding(get: { route.enabled }, set: { on in change { $0.enabled = on } }))
                .toggleStyle(EchoelToggleStyle())
                .fixedSize()
                .accessibilityLabel(route.enabled ? "On" : "Off")
            Picker("Source", selection: Binding(get: { route.polarity }, set: { polarity in change { $0.polarity = polarity } })) {
                Text("From Zero").tag(ModulationRoute.Polarity.unipolar)
                Text("Centred").tag(ModulationRoute.Polarity.bipolar)
            }
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityHint("From zero adds only upward; centred moves the value both ways.")
            ModulationLiveMeter(route: route)
            Button(role: .destructive) {
                documents.attempt([.removeModRoute(route.id)], title: "Remove Modulation")
            } label: {
                Image(systemName: "trash")
                    .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove " + ModulationName.title(of: route, in: store.project))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.Color.surface.opacity(route.enabled ? 1 : 0.5))
    }

    private func change(_ edit: (inout ModulationRoute) -> Void) {
        var changed = route
        edit(&changed)
        documents.attempt([.setModRoute(changed)], title: "Modulation")
    }
}

/// What a route is doing right now (Michael on 10084: "Mir fehlt die Visualisierung, was gerade
/// bei den meisten Parametern wirklich passiert"): the source's reading as a bar, 0 … 100 %, and
/// what the route adds to its value — "+12.5 %" — the same arithmetic the engine adds
/// (`Modulation.contribution`). Its own leaf, refreshed ten times a second while it shows, so no
/// view above it reads a live value (Law 6). A source nothing measures says so instead of a bar.
struct ModulationLiveMeter: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let route: ModulationRoute

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let reading = currentReading()
            let added = Modulation.contribution(of: reading, depth: route.depth, curve: route.curve,
                                                polarity: route.polarity)
            HStack(spacing: Theme.Space.xs) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.Color.surfaceRaised)
                        Rectangle().fill(route.enabled ? Theme.Color.accent : Theme.Color.textTertiary)
                            .frame(width: geometry.size.width * CGFloat(reading ?? 0))
                    }
                }
                .frame(width: 64, height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                Text(reading == nil ? "Not measured" : NumberText.signed(added * 100, decimals: 1, unit: "%"))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(minWidth: 72, alignment: .leading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Now")
            .accessibilityValue(reading.map { "source \(Int(($0 * 100).rounded())) percent, adds "
                + NumberText.signed(added * 100, decimals: 1, unit: "percent") } ?? "not measured")
        }
    }

    /// The source's reading now: the body and the phone from the engine's inputs, the Bar LFO and
    /// the Bar Weave from the song position, as the engine reads them.
    private func currentReading() -> Double? {
        let project = store.project
        switch route.source {
        case .lfo1:
            return Modulation.songLFO(at: Double(engine.playheadTick(in: project)), meter: project.meterMap)
        case .weave1:
            let seed = BarWeave.seed(keyMask: BarWeave.keyMask(project.context))
            return Modulation.songWeave(at: Double(engine.playheadTick(in: project)), meter: project.meterMap, seed: seed)
        default:
            return engine.modulation.value(route.source)
        }
    }
}
