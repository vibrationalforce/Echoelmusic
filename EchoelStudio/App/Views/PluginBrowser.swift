import EchoelCore
import Foundation
import SwiftUI

/// The components used last, per kind, on this device only — a convenience like the loop switch,
/// never in the song. Read and written on the main thread.
enum PluginRecents {
    enum Kind: String {
        case instruments = "recentInstrumentPlugins"
        case effects = "recentEffectPlugins"
    }

    static func load(_ kind: Kind) -> [PluginComponent] {
        guard let data = UserDefaults.standard.data(forKey: kind.rawValue),
              let list = try? JSONDecoder().decode([PluginComponent].self, from: data) else { return [] }
        return Array(list.prefix(PluginCatalogFilter.recentLimit))
    }

    /// The list after `component` was used, saved.
    static func record(_ component: PluginComponent, kind: Kind) -> [PluginComponent] {
        let list = PluginCatalogFilter.recording(component, in: load(kind))
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: kind.rawValue) }
        return list
    }
}

/// The searchable list of components to add — the effects of an insert chain, the instruments of
/// a track — opened in place under its button, never a sheet (Law 7): Echoel's own first, then
/// the ones used last, then every installed Audio Unit by maker (`PluginCatalogFilter`).
struct PluginBrowser: View {
    let title: String
    let systemImage: String
    let hint: String
    let installed: [PluginComponent]
    var own: [PluginComponent] = []
    let recentsKind: PluginRecents.Kind
    /// Said when nothing at all is installed.
    let emptyText: String
    var isDisabled = false
    let choose: (PluginComponent) -> Void

    @Environment(AudioEngine.self) private var engine
    @State private var isOpen = false
    @State private var query = ""
    @State private var recents: [PluginComponent] = []
    @FocusState private var searching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            openButton
            if isOpen { browser }
        }
        .onChange(of: isDisabled) { _, disabled in if disabled { isOpen = false } }
    }

    private var openButton: some View {
        Button {
            if !isOpen {
                recents = PluginRecents.load(recentsKind)
                // The system may register a unit after launch without saying so: read again.
                engine.plugins.refreshCatalog()
            }
            isOpen.toggle()
            if !isOpen { query = "" }
        } label: {
            HStack(spacing: Theme.Space.s) {
                Label(title, systemImage: systemImage)
                Spacer(minLength: 0)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .foregroundStyle(Theme.Color.textSecondary)
                    .accessibilityHidden(true)
            }
            .font(Theme.Font.body)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.Color.accent)
        .disabled(isDisabled)
        .accessibilityHint(hint)
        .accessibilityValue(isOpen ? "Open" : "Closed")
    }

    @ViewBuilder private var browser: some View {
        if installed.isEmpty && own.isEmpty {
            Text(emptyText)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        } else {
            searchField
            let sections = PluginCatalogFilter.sections(installed: installed, own: own, recents: recents, query: query)
            if sections.isEmpty {
                Text("Nothing matches “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            } else {
                LazyVStack(alignment: .leading, spacing: Theme.Space.m) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        if index == firstMakerIndex(in: sections) {
                            Text("Audio Units")
                                .font(Theme.Font.label)
                                .foregroundStyle(Theme.Color.text)
                                .accessibilityAddTraits(.isHeader)
                        }
                        sectionView(section)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        TextField("Search by name or maker", text: $query)
            .echoelInput()
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            .focused($searching)
            .accessibilityLabel("Search Plugins")
    }

    /// Where the installed units of other makers begin: "Audio Units" stands above them.
    private func firstMakerIndex(in sections: [PluginCatalogFilter.Section]) -> Int? {
        sections.firstIndex { section in
            if case .maker = section.kind { true } else { false }
        }
    }

    private func sectionView(_ section: PluginCatalogFilter.Section) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(section.title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: Theme.Space.hairline) {
                ForEach(section.components, id: \.self) { component in
                    row(component, in: section)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
    }

    private func row(_ component: PluginComponent, in section: PluginCatalogFilter.Section) -> some View {
        let maker = PluginCatalogFilter.makerName(component)
        return Button {
            pick(component)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(component.displayName)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.text)
                // The maker under the name where the section does not already say it.
                if section.kind != .maker(maker) {
                    Text(maker)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Space.m)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
            .background(Theme.Color.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(component.displayName), \(maker)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(hint)
    }

    private func pick(_ component: PluginComponent) {
        recents = PluginRecents.record(component, kind: recentsKind)
        searching = false
        query = ""
        isOpen = false
        choose(component)
    }
}
