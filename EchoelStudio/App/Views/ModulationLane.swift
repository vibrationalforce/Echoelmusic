import EchoelCore
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
