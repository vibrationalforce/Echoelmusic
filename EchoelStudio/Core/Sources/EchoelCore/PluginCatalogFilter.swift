import Foundation

/// What the plugin browser lists for one search: Echoel's own components in a section of their
/// own, then the components used last on this device, most recent first, then every other
/// installed component grouped by its maker — makers alphabetical, components alphabetical within.
/// The search matches the component's name and its maker, every word of it, ignoring case and
/// accents. Local only: it reads the catalogue the system reported and the device's recent list.
public enum PluginCatalogFilter {
    /// How many components the recent section keeps.
    public static let recentLimit = 8
    /// The manufacturer code of Echoel's own components ('Echo').
    public static let ownManufacturer = PluginComponent.code("Echo")

    /// One section of the browser.
    public struct Section: Equatable, Sendable, Identifiable {
        public enum Kind: Hashable, Sendable {
            /// Echoel's own components.
            case own
            /// Used last on this device.
            case recent
            /// Every other component of one maker.
            case maker(String)
        }

        public let kind: Kind
        public let components: [PluginComponent]

        public init(kind: Kind, components: [PluginComponent]) {
            self.kind = kind
            self.components = components
        }

        public var id: Kind { kind }

        public var title: String {
            switch kind {
            case .own: "Echoelmusic"
            case .recent: "Recent"
            case .maker(let name): name
            }
        }
    }

    /// The sections for `query`, empty ones left out. `own` keeps the order it is given (Echoel's
    /// own lists are ordered on purpose); a component in `installed` with Echoel's manufacturer
    /// joins it. `recents` is most recent first, as `recording(_:in:)` keeps it; a recent component
    /// no longer in the catalogue is not offered, and one that is shows with the catalogue's names.
    public static func sections(installed: [PluginComponent], own: [PluginComponent] = [],
                                recents: [PluginComponent], query: String) -> [Section] {
        let words = searchWords(query)
        var ownList: [PluginComponent] = []
        for component in own + installed.filter({ $0.manufacturer == ownManufacturer })
        where !ownList.contains(component) {
            ownList.append(component)
        }
        let others = installed.filter { $0.manufacturer != ownManufacturer }
        let catalogue = ownList + others

        var sections: [Section] = []
        let shownOwn = ownList.filter { matches($0, words: words) }
        if !shownOwn.isEmpty { sections.append(Section(kind: .own, components: shownOwn)) }

        var recent: [PluginComponent] = []
        for wanted in recents where recent.count < recentLimit {
            guard let listed = catalogue.first(where: { $0 == wanted }), !recent.contains(listed),
                  matches(listed, words: words) else { continue }
            recent.append(listed)
        }
        if !recent.isEmpty { sections.append(Section(kind: .recent, components: recent)) }

        var byMaker: [String: [PluginComponent]] = [:]
        for component in others where matches(component, words: words) {
            byMaker[makerName(component), default: []].append(component)
        }
        for maker in byMaker.keys.sorted(by: { compareNames($0, $1) == .orderedAscending }) {
            let listed = (byMaker[maker] ?? []).sorted { lhs, rhs in
                let order = compareNames(lhs.displayName, rhs.displayName)
                return order == .orderedSame ? compareNames(lhs.name, rhs.name) == .orderedAscending : order == .orderedAscending
            }
            sections.append(Section(kind: .maker(maker), components: listed))
        }
        return sections
    }

    /// Whether `component` answers `query`: each of its words is in the name or the maker.
    public static func matches(_ component: PluginComponent, query: String) -> Bool {
        matches(component, words: searchWords(query))
    }

    /// The recent list after `component` was used: it first, an older entry of it dropped, at most
    /// `recentLimit` long.
    public static func recording(_ component: PluginComponent, in recents: [PluginComponent]) -> [PluginComponent] {
        Array(([component] + recents.filter { $0 != component }).prefix(recentLimit))
    }

    /// The maker a component is grouped under; "Other" for one that names none.
    public static func makerName(_ component: PluginComponent) -> String {
        let maker = component.manufacturerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return maker.isEmpty ? "Other" : maker
    }

    private static func matches(_ component: PluginComponent, words: [String]) -> Bool {
        guard !words.isEmpty else { return true }
        let text = fold(component.name + " " + component.manufacturerName)
        return words.allSatisfy { text.contains($0) }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func searchWords(_ query: String) -> [String] {
        fold(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private static func compareNames(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive, .numeric])
    }
}
