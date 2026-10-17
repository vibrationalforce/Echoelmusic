import EchoelCore
import SwiftUI

/// A track's insert chain: the effects in order, each with bypass, order and remove, and the
/// selected one's own interface below the list. Echoel's standard effects and the installed
/// Audio Unit effects are added from the menu.
struct EffectsView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    let trackID: TrackID

    @State private var selected: InsertID?

    var body: some View {
        let track = store.project.track(trackID)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    if let track {
                        chain(track)
                        addMenu(track)
                        if let id = selected, let index = track.insertIndex(id) {
                            if let standard = StandardEffect(component: track.inserts[index].plugin) {
                                StandardEffectPanel(track: track.id, insert: id, effect: standard)
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
            .navigationTitle(track.map { "\($0.name) Effects" } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private func chain(_ track: Track) -> some View {
        if track.inserts.isEmpty {
            Text("No effects. They run in order on the track's sound, before its fader and pan.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        } else {
            VStack(spacing: 1) {
                ForEach(Array(track.inserts.enumerated()), id: \.element.id) { index, insert in
                    row(insert, index: index, of: track)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
    }

    private func row(_ insert: Insert, index: Int, of track: Track) -> some View {
        HStack(spacing: Theme.Space.s) {
            Button {
                selected = selected == insert.id ? nil : insert.id
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(insert.plugin.name)
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
            .accessibilityHint(selected == insert.id ? "Hides its interface" : "Shows its interface")
            Button(insert.isBypassed ? "Off" : "On") {
                try? store.perform(.setInsertBypass(track: track.id, insert.id, !insert.isBypassed))
            }
            .buttonStyle(ToolButtonStyle(isActive: !insert.isBypassed, activeColor: Theme.Color.play))
            .accessibilityLabel("\(insert.plugin.name) active")
            .accessibilityValue(insert.isBypassed ? "Bypassed" : "On")
            Menu {
                Button("Move Up", systemImage: "arrow.up") { move(insert, on: track, to: index - 1) }
                    .disabled(index == 0)
                Button("Move Down", systemImage: "arrow.down") { move(insert, on: track, to: index + 1) }
                    .disabled(index == track.inserts.count - 1)
                Button("Remove", systemImage: "trash", role: .destructive) {
                    if selected == insert.id { selected = nil }
                    try? store.perform(.removeInsert(track: track.id, insert.id))
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
            }
            .accessibilityLabel("More for \(insert.plugin.name)")
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

    private func move(_ insert: Insert, on track: Track, to index: Int) {
        try? store.perform(.moveInsert(track: track.id, insert.id, toIndex: index))
    }

    private func addMenu(_ track: Track) -> some View {
        let installed = engine.plugins.effects
        return Menu {
            Section("Echoel") {
                ForEach(StandardEffect.allCases) { effect in
                    Button(effect.title) { add(effect.component, to: track) }
                }
            }
            Section("Audio Units") {
                if installed.isEmpty { Text("No Audio Unit effects installed") }
                ForEach(installed, id: \.self) { component in
                    Button("\(component.name) — \(component.manufacturerName)") { add(component, to: track) }
                }
            }
        } label: {
            Label("Add Effect…", systemImage: "plus")
                .font(Theme.Font.body)
        }
        .disabled(track.inserts.count >= Insert.maximumPerTrack)
    }

    private func add(_ component: PluginComponent, to track: Track) {
        let id = InsertID()
        if (try? store.perform(.addInsert(track: track.id, id: id, plugin: component, index: nil))) != nil {
            selected = id
        }
    }
}
