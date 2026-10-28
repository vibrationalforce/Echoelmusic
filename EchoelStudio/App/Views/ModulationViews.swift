import EchoelCore
import SwiftUI

/// "Modulate" for one owner (wave W2): the body moves the owner's volume or pan. Only sources
/// with a producer are offered — the chest strap's pulse, HRV and coherence; a source nothing
/// measures would be a control that does nothing. Every change goes through
/// `ProjectStore.perform` (`modulation.set` / `modulation.remove`), one undo step each.
struct ModulateMenu: View {
    @Environment(ProjectStore.self) private var store
    let owner: ParameterAddress.Owner

    /// The sources a route can be made from today, with the words the menu uses: the strap's
    /// pulse and what its beat-to-beat intervals carry. HRV needs 8 beats and coherence 16
    /// before they add anything.
    static let sources: [(ModulationSource, String)] = [(.heartRate, "Heart Rate"), (.hrv, "HRV"),
                                                        (.coherence, "Coherence")]
    /// The depths offered, as a share of the control's travel.
    static let depths: [Double] = [0.1, 0.25, 0.5, 1]

    private var targets: [ParameterAddress] {
        switch owner {
        case .master: [.masterVolume, .masterPan]
        case .track(let id): [.volume(id), .pan(id)]
        case .project: []
        }
    }

    var body: some View {
        let project = store.project
        let routes = project.modRoutes.filter { targets.contains($0.target) }
        Menu("Modulate", systemImage: "waveform.path.ecg") {
            ForEach(targets, id: \.self) { target in
                if let descriptor = project.descriptor(for: target) {
                    Menu(descriptor.title) {
                        ForEach(Self.sources, id: \.0) { source, title in
                            Button("\(title) → \(descriptor.title)") {
                                try? store.perform(.setModRoute(ModulationRoute(source: source, target: target, depth: 0.25)))
                            }
                        }
                    }
                }
            }
            if !routes.isEmpty { Divider() }
            ForEach(routes) { route in
                Menu(Self.title(of: route, in: project)) { RouteActions(route: route) }
            }
        }
        .disabled(targets.isEmpty)
    }

    static func title(of route: ModulationRoute, in project: Project) -> String {
        let source = sources.first { $0.0 == route.source }?.1 ?? route.source.rawValue
        let target = project.descriptor(for: route.target)?.title ?? route.target.description
        let depth = Int((route.depth * 100).rounded())
        return "\(source) → \(target) \(depth > 0 ? "+" : "")\(depth)%\(route.enabled ? "" : " (off)")"
    }
}

/// What one route can do: its depth and sign, its polarity, on or off, removed.
private struct RouteActions: View {
    @Environment(ProjectStore.self) private var store
    let route: ModulationRoute

    var body: some View {
        ForEach(ModulateMenu.depths, id: \.self) { depth in
            Button("Depth \(Int(depth * 100))%") { change { $0.depth = depth * ($0.depth < 0 ? -1 : 1) } }
        }
        Button("Invert") { change { $0.depth = -$0.depth } }
        Button(route.polarity == .unipolar ? "Centre the Source (bipolar)" : "Source From Zero (unipolar)") {
            change { $0.polarity = $0.polarity == .unipolar ? .bipolar : .unipolar }
        }
        Button(route.enabled ? "Turn Off" : "Turn On") { change { $0.enabled.toggle() } }
        Button("Remove", role: .destructive) { try? store.perform(.removeModRoute(route.id)) }
    }

    private func change(_ edit: (inout ModulationRoute) -> Void) {
        var changed = route
        edit(&changed)
        try? store.perform(.setModRoute(changed))
    }
}
