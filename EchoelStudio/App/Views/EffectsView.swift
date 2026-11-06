import EchoelCore
import EchoelKernels
import SwiftUI

/// An insert chain — a track's, or the master's: the effects in order, each with bypass, order
/// and remove, and the selected one's own interface below the list. Echoel's standard effects
/// and the installed Audio Unit effects are added from the searchable browser.
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
                        if case .track(let track) = owner {
                            vocalChainMenu(track: track)
                        }
                        if owner == .master {
                            // A push, not a sheet: the page lives inside this one (Law 7).
                            NavigationLink("Mix Analysis…") { MixAnalysisView() }
                                .buttonStyle(ToolButtonStyle())
                                .accessibilityHint("Measures the mix and suggests a master chain")
                        }
                        if let id = selected, let insert = inserts.first(where: { $0.id == id }) {
                            CompareRow(device: .insert(id))
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
        let isSelected = selected == insert.id
        let word = insert.isBypassed ? "Off" : "On"
        return HStack(spacing: Theme.Space.s) {
            Button {
                selected = isSelected ? nil : insert.id
            } label: {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    Text(insert.plugin.displayName)
                        .font(Theme.Font.body)
                        .foregroundStyle(insert.isBypassed ? Theme.Color.textSecondary : Theme.Color.text)
                    Text(status(of: insert))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                // A full touch target: the two lines alone were about 39 pt high (W18, m10).
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isSelected ? "Hides its interface." : "Shows its interface.")
            // The effect whose interface stands below is said to be the selected one (W18, m8).
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            Button(word) {
                perform(bypass: insert.id, !insert.isBypassed)
            }
            .buttonStyle(ToolButtonStyle(isActive: !insert.isBypassed, activeColor: Theme.Color.play))
            .accessibilityLabel("\(insert.plugin.displayName) Active")
            .accessibilityValue(insert.isBypassed ? "Bypassed" : "On")
            // Voice Control answers to the word on the button, not only to its spoken name (W18, m9).
            .accessibilityInputLabels([Text(verbatim: word), Text(verbatim: "\(insert.plugin.displayName) Active")])
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
        .background(isSelected ? Theme.Color.surfaceRaised : Theme.Color.surface)
    }

    private func status(of insert: Insert) -> String {
        let host = engine.plugins
        if let problem = host.problems[.insert(insert.id)] { return problem }
        if host.loading.contains(.insert(insert.id)) { return "Loading…" }
        if insert.isBypassed { return "Bypassed" }
        return insert.plugin.manufacturerName
    }

    /// Echoel's effects and every installed Audio Unit effect, searchable, opened in place under the
    /// button (`PluginBrowser`, Law 7); the one chosen goes at the end of the chain.
    private func addMenu(count: Int) -> some View {
        PluginBrowser(title: "Add Effect", systemImage: "plus", hint: "Adds the effect at the end of the chain.",
                      installed: engine.plugins.effects, own: StandardEffect.allCases.map(\.component),
                      recentsKind: .effects, emptyText: "No effects to add.",
                      isDisabled: count >= Insert.maximumPerTrack) { component in
            add(component)
        }
    }

    /// One tap puts a whole vocal chain on the track, in place of its effects, as one undo step.
    /// A menu, not a sheet (Law 7).
    private func vocalChainMenu(track: TrackID) -> some View {
        Menu {
            Section("Replaces this track's effects — Undo brings them back") {
                ForEach(VocalChain.allCases) { chain in
                    Button {
                        apply(chain, to: track)
                    } label: {
                        Text(chain.title)
                        Text(chain.summary)
                    }
                }
            }
        } label: {
            Label("Vocal Chain", systemImage: "music.mic")
                .font(Theme.Font.body)
                .frame(minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .accessibilityHint("Replaces this track's effects with a vocal chain")
    }

    // MARK: - The commands of this chain's owner

    private func apply(_ chain: VocalChain, to id: TrackID) {
        guard let track = store.project.track(id) else { return }
        if (try? store.perform(chain.commands(for: track), title: VocalChain.actionTitle)) != nil { selected = nil }
    }

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
