#if canImport(SwiftUI)
import SwiftUI

/// Production level H1 (founder 2026-10-13: „Solange keine vernünftige Produktionsumgebung wie
/// AUv3 Plugins … vorhanden ist finde ich testen planlos") — the first, READ-ONLY step of AUv3
/// hosting: the Device page of a rack track says which Audio Unit instruments and effects this
/// iPhone has installed. Nothing here loads, instantiates or plays a unit — choosing one for a
/// track is H2 (`scratchpads/PLAN_PRODUCTION_LEVEL_2026-10-13.md`), so this row offers NO picker:
/// a menu that cannot load what it lists would be a half-finished door.
///
/// ⚠️ ITS OWN LEAF, ON PURPOSE: the component query walks the system registry, so it runs
/// DETACHED in `.task` (the `TrackSampleRow` pattern), never in a `body`.
/// NEEDS-FOUNDER-VERIFY: H1 — the Device page of a Synth track lists the AUv3 instruments and effects installed on this iPhone (e.g. from AUM-compatible apps), and says "none" when there are none.
@MainActor
struct TrackPluginRow: View {
    @State private var instruments: [PluginDescriptor] = []
    @State private var effects: [PluginDescriptor] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
            Text("Audio Units on this iPhone")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Text(loaded ? Self.summary(instruments: instruments, effects: effects)
                        : String(localized: "Looking for installed Audio Units…"))
                .font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Loading one on a track is not available yet.")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .task {
            let found = await Task.detached(priority: .utility) {
                (PluginCatalog.installed(.instrument),
                 PluginCatalog.installed(.effect) + PluginCatalog.installed(.musicEffect))
            }.value
            guard !Task.isCancelled else { return }
            instruments = found.0
            effects = PluginCatalog.ordered(found.1)
            loaded = true
        }
    }

    /// The one line the row shows: counts first, then the first few names of each kind.
    static func summary(instruments: [PluginDescriptor], effects: [PluginDescriptor],
                        namesShown: Int = 3) -> String {
        func names(_ list: [PluginDescriptor]) -> String {
            let shown = list.prefix(max(0, namesShown)).map(\.name)
            let rest = list.count - shown.count
            return rest > 0 ? shown.joined(separator: ", ") + " +\(rest)" : shown.joined(separator: ", ")
        }
        if instruments.isEmpty && effects.isEmpty {
            return String(localized: "No Audio Unit instruments or effects are installed.")
        }
        var parts: [String] = []
        parts.append(instruments.isEmpty
            ? String(localized: "No instruments")
            : "\(instruments.count) " + String(localized: "instruments") + ": " + names(instruments))
        parts.append(effects.isEmpty
            ? String(localized: "No effects")
            : "\(effects.count) " + String(localized: "effects") + ": " + names(effects))
        return parts.joined(separator: " · ")
    }
}
#endif
