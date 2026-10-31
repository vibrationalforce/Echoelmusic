import EchoelCore
import SwiftUI

/// An insert chain — a track's, or the master's: the effects in order, each with bypass, order
/// and remove, and the selected one's own interface below the list. Echoel's standard effects
/// and the installed Audio Unit effects are added from the menu.
struct EffectsView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    /// `.track` for a track's chain, `.master` for the master's.
    let owner: ParameterAddress.Owner

    @State private var selected: InsertID?

    var body: some View {
        let inserts = chainInserts
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    if let inserts {
                        chain(inserts)
                        addMenu(count: inserts.count)
                        if let id = selected, let insert = inserts.first(where: { $0.id == id }) {
                            if let standard = StandardEffect(component: insert.plugin) {
                                StandardEffectPanel(owner: owner, insert: id, effect: standard)
                                    .id(id)
                            } else {
                                PluginInterfaceSection(slot: .insert(id))
                                    .id(id)
                            }
                        }
                    } else {
                        Text("This track was deleted.")
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.Color.background)
            // A field typed into opens Echoel's number pad at the page's bottom edge, not a sheet.
            .numberPadHost()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// The chain, or nil when its track is gone.
    private var chainInserts: [Insert]? {
        switch owner {
        case .track(let id): store.project.track(id)?.inserts
        case .master: store.project.masterInserts
        case .project: nil
        }
    }

    private var title: String {
        switch owner {
        case .track(let id): store.project.track(id).map { "\($0.name) Effects" } ?? ""
        case .master: "Master Effects"
        case .project: ""
        }
    }

    @ViewBuilder private func chain(_ inserts: [Insert]) -> some View {
        if inserts.isEmpty {
            Text(owner == .master
                 ? "No effects. They run in order on the master mix, after the master fader — the place for a final limiter."
                 : "No effects. They run in order on the track's sound, before its fader and pan.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        } else {
            VStack(spacing: Theme.Space.hairline) {
                ForEach(Array(inserts.enumerated()), id: \.element.id) { index, insert in
                    row(insert, index: index, count: inserts.count)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
    }

    private func row(_ insert: Insert, index: Int, count: Int) -> some View {
        HStack(spacing: Theme.Space.s) {
            Button {
                selected = selected == insert.id ? nil : insert.id
            } label: {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    Text(insert.plugin.displayName)
                        .font(Theme.Font.body)
                        .foregroundStyle(insert.isBypassed ? Theme.Color.textSecondary : Theme.Color.text)
                    Text(status(of: insert))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(selected == insert.id ? "Hides its interface." : "Shows its interface.")
            Button(insert.isBypassed ? "Off" : "On") {
                perform(bypass: insert.id, !insert.isBypassed)
            }
            .buttonStyle(ToolButtonStyle(isActive: !insert.isBypassed, activeColor: Theme.Color.play))
            .accessibilityLabel("\(insert.plugin.displayName) Active")
            .accessibilityValue(insert.isBypassed ? "Bypassed" : "On")
            Menu {
                Button("Move Up", systemImage: "arrow.up") { perform(move: insert.id, to: index - 1) }
                    .disabled(index == 0)
                Button("Move Down", systemImage: "arrow.down") { perform(move: insert.id, to: index + 1) }
                    .disabled(index == count - 1)
                Button("Remove", systemImage: "trash", role: .destructive) {
                    if selected == insert.id { selected = nil }
                    perform(remove: insert.id)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
            }
            .accessibilityLabel("More for \(insert.plugin.displayName)")
        }
        .padding(.horizontal, Theme.Space.m)
        .background(selected == insert.id ? Theme.Color.surfaceRaised : Theme.Color.surface)
    }

    private func status(of insert: Insert) -> String {
        let host = engine.plugins
        if let problem = host.problems[.insert(insert.id)] { return problem }
        if host.loading.contains(.insert(insert.id)) { return "Loading…" }
        if insert.isBypassed { return "Bypassed" }
        return insert.plugin.manufacturerName
    }

    private func addMenu(count: Int) -> some View {
        let installed = engine.plugins.effects
        return Menu {
            Section("Echoel") {
                ForEach(StandardEffect.allCases) { effect in
                    Button(effect.title) { add(effect.component) }
                }
            }
            Section("Audio Units") {
                if installed.isEmpty { Text("No Audio Unit effects installed") }
                ForEach(installed, id: \.self) { component in
                    Button("\(component.displayName) — \(component.manufacturerName)") { add(component) }
                }
            }
        } label: {
            Label("Add Effect", systemImage: "plus")
                .font(Theme.Font.body)
        }
        .disabled(count >= Insert.maximumPerTrack)
    }

    // MARK: - The commands of this chain's owner

    private func add(_ component: PluginComponent) {
        let id = InsertID()
        let command: Command
        switch owner {
        case .track(let track): command = .addInsert(track: track, id: id, plugin: component, index: nil)
        case .master: command = .addMasterInsert(id: id, plugin: component, index: nil)
        case .project: return
        }
        if (try? store.perform(command)) != nil { selected = id }
    }

    private func perform(bypass id: InsertID, _ bypassed: Bool) {
        switch owner {
        case .track(let track): try? store.perform(.setInsertBypass(track: track, id, bypassed))
        case .master: try? store.perform(.setMasterInsertBypass(id, bypassed))
        case .project: break
        }
    }

    private func perform(move id: InsertID, to index: Int) {
        switch owner {
        case .track(let track): try? store.perform(.moveInsert(track: track, id, toIndex: index))
        case .master: try? store.perform(.moveMasterInsert(id, toIndex: index))
        case .project: break
        }
    }

    private func perform(remove id: InsertID) {
        switch owner {
        case .track(let track): try? store.perform(.removeInsert(track: track, id))
        case .master: try? store.perform(.removeMasterInsert(id))
        case .project: break
        }
    }
}
