import EchoelCore
import EchoelDSP
import EchoelEngine
import SwiftUI
import UniformTypeIdentifiers

/// The sample and media browser (Recovery 7): the open song's files, the library's other songs'
/// files and files picked into the browser — filtered by kind, searched by name, sorted, heard,
/// and placed on a track, into a sampler or into a wavetable. Local only, no network.
///
/// Placing goes through the commands the imports already send: a file of the open song through
/// `MediaBrowser.commands` and the store, a file from elsewhere through the document controller's
/// imports, which copy it into the song first. Opened from the Song menu through the one sheet
/// slot; its own file picker is the one presentation a sheet may own (Law 7).
struct MediaBrowserView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(StreamingController.self) private var streaming
    @Environment(\.dismiss) private var dismiss
    @State private var model = MediaBrowserModel()
    @State private var kind: MediaBrowser.Kind?
    @State private var query = ""
    @State private var sort: MediaBrowser.Sort = .name
    @State private var isPicking = false
    /// The listening level, the browser's own — never the master's (a device setting, not the song's).
    @AppStorage("browser.listeningLevelDB") private var listeningLevel = -6
    /// Listening on outputs 3/4, where the interface has them.
    @AppStorage("browser.listensOnCue") private var listensOnCue = false

    var body: some View {
        NavigationStack {
            list
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by name")
                .navigationTitle("Browser")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isPicking) {
            AudioFilePicker(pick: { url in
                isPicking = false
                model.importFile(url, songs: documents.songs, current: documents.currentURL)
            }, cancel: { isPicking = false }, types: [.audio, .movie, .image])
            .ignoresSafeArea()
        }
        .onAppear {
            model.reload(songs: documents.songs, current: documents.currentURL)
            engine.preview.setLevel(decibels: Double(listeningLevel))
            engine.preview.setCueOutput(listensOnCue)
        }
        .onChange(of: listeningLevel) { _, level in engine.preview.setLevel(decibels: Double(level)) }
        .onChange(of: listensOnCue) { _, on in engine.preview.setCueOutput(on) }
        .task(id: pitchJobIDs) { model.index(pitchJobs) }
        .onDisappear { model.stopListening(engine.preview) }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Import", systemImage: "square.and.arrow.down") { isPicking = true }
                .accessibilityHint("Adds a sound, a video or a picture from Files to the browser")
        }
        ToolbarItem(placement: .principal) { sortMenu }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sort) {
                ForEach(MediaBrowser.Sort.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        } label: {
            Label("Sort: \(sort.title)", systemImage: "arrow.up.arrow.down")
                .labelStyle(.titleAndIcon)
                .font(Theme.Font.label)
        }
        .accessibilityLabel("Sort by \(sort.title)")
    }

    /// Everything the browser knows: the open song's files as the store has them now, then the rest.
    private var allItems: [MediaBrowser.Item] {
        MediaBrowser.items(of: store.project, origin: .song, package: documents.currentURL) + model.items
    }

    /// The audio files whose note the browser measures, with where each is read from.
    private var pitchJobs: [MediaBrowserModel.PitchJob] {
        allItems.filter { $0.kind == .audio }.map { item in
            MediaBrowserModel.PitchJob(id: item.id, url: url(of: item), loaded: item.media.flatMap { documents.samples[$0] })
        }
    }

    private var pitchJobIDs: [String] { allItems.filter { $0.kind == .audio }.map(\.id) }

    private var list: some View {
        let all = allItems
        let shown = MediaBrowser.shown(all, kind: kind, query: query, sort: sort)
        return List {
            EchoelSection {
                kindPicker(counts: MediaBrowser.counts(all), total: all.count)
                if let message = model.message { NoteText(message, tone: .problem) }
                if streaming.isLive || streaming.isStarting {
                    NoteText("Listening is off while the stream is live: the stream would carry it.")
                }
            }
            listeningSection
            EchoelSection(footer: footer(shown: shown.count, total: all.count)) {
                if shown.isEmpty {
                    NoteText(emptyText(total: all.count))
                } else {
                    ForEach(shown) { row($0) }
                }
            }
        }
        .echoelList()
        .numberPadHost()
    }

    /// The listening level and, on an interface with four outputs or more, the cue pair. Listening
    /// is added after the master and its effects, and no export or take ever holds it.
    private var listeningSection: some View {
        EchoelSection("Listening", footer: "Heard on the output in use — headphones, when they are plugged in. Never in an export or a recording.") {
            SettingField(title: "Listening Level", value: listeningLevel,
                         range: Int(PreviewPlayer.levelRange.lowerBound)...Int(PreviewPlayer.levelRange.upperBound),
                         unit: "dB", standard: -6, spokenUnit: "decibels") { listeningLevel = $0 }
            if engine.outputChannels > 2 {
                Toggle("Listen on Outputs 3/4", isOn: $listensOnCue)
                    .accessibilityHint("Sends the browser's listening to the interface's cue pair instead of the main pair")
            }
        }
    }

    private func kindPicker(counts: [MediaBrowser.Kind: Int], total: Int) -> some View {
        Picker("Kind", selection: $kind) {
            Text("All \(total)").tag(MediaBrowser.Kind?.none)
            ForEach(MediaBrowser.Kind.allCases, id: \.self) { kind in
                Text("\(kind.title) \(counts[kind] ?? 0)").tag(MediaBrowser.Kind?.some(kind))
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Show")
    }

    private func footer(shown: Int, total: Int) -> String? {
        model.isLoading ? "Reading the other songs…" : (shown == total ? nil : "\(shown) of \(total) files")
    }

    private func emptyText(total: Int) -> String {
        if model.isLoading { return "Reading the other songs…" }
        if total == 0 { return "No files yet. Import a sound, a video or a picture, or bring one into a song." }
        if kind == .image, query.trimmingCharacters(in: .whitespaces).isEmpty {
            return "No pictures. Import one to keep it here; a song holds sounds and videos, not pictures."
        }
        return "Nothing matches."
    }

    // MARK: - Rows

    private func row(_ item: MediaBrowser.Item) -> some View {
        MediaBrowserRow(item: item, details: details(of: item)) {
            listenButton(item)
        } place: {
            placeMenu(item)
        }
        .swipeActions {
            if item.origin == .imported {
                Button("Remove", role: .destructive) {
                    model.remove(item, songs: documents.songs, current: documents.currentURL)
                }
            }
        }
    }

    /// What is measured about a file, and where it is. Nothing else.
    private func details(of item: MediaBrowser.Item) -> [String] {
        var parts = [item.kind.title, item.origin.title]
        if let seconds = item.duration { parts.append(Self.length(seconds)) }
        if let rate = item.sampleRate { parts.append(NumberText.string(rate / 1_000, decimalsUpTo: 1) + " kHz") }
        if let bpm = item.tempo { parts.append(NumberText.string(bpm, decimalsUpTo: 1) + " BPM") }
        if item.kind == .audio, let pitch = model.pitches[item.id] {
            switch pitch {
            case .measuring: break
            case .none: parts.append("Note —")
            case .note(let reading): parts.append(MediaBrowser.pitchText(note: reading.note, cents: reading.cents))
            }
        }
        return parts
    }

    static func length(_ seconds: Double) -> String {
        let whole = Int(seconds.rounded(.down))
        if whole >= 60 { return String(format: "%d:%02d", whole / 60, whole % 60) }
        return NumberText.string(seconds, decimalsUpTo: 1) + " s"
    }

    @ViewBuilder private func listenButton(_ item: MediaBrowser.Item) -> some View {
        if item.canListen {
            ListenButton(name: item.name, take: model.listening?.id == item.id ? model.listening?.take : nil,
                         player: engine.preview, enabled: engine.isUp && !streaming.isLive && !streaming.isStarting) {
                model.listen(item, url: url(of: item), loaded: item.media.flatMap { documents.samples[$0] },
                             player: engine.preview)
            }
        }
    }

    /// Where a file is read from: a song file inside the open song's package, else the item's own.
    private func url(of item: MediaBrowser.Item) -> URL? {
        if let media = item.media, let file = store.project.mediaFile(media) { return documents.mediaURL(file) }
        return item.location
    }

    @ViewBuilder private func placeMenu(_ item: MediaBrowser.Item) -> some View {
        let destinations = MediaBrowser.destinations(for: item.kind, in: store.project, at: 0)
        Menu {
            if destinations.isEmpty {
                Text(item.kind == .image ? "A song holds no pictures." : "Add an audio or instrument track first.")
            }
            ForEach(destinations, id: \.self) { destination in
                Button(title(of: destination)) { place(item, on: destination) }
                // The measured note as the sampler's root, only when the musician picks this one.
                if case .sampler = destination, let root = measuredNote(of: item) {
                    Button(title(of: destination) + ", Root " + NoteEditing.name(of: root)) {
                        place(item, on: destination, rootKey: root)
                    }
                }
            }
        } label: {
            Label("Place", systemImage: "plus.square.on.square")
                .labelStyle(.iconOnly)
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
        }
        .disabled(destinations.isEmpty || documents.packageIsBusy)
        .accessibilityLabel("Place \(item.name)")
        .accessibilityHint(destinations.isEmpty ? "Nowhere in this song takes it" : "On a track, into a sampler or a wavetable")
    }

    private func title(of destination: MediaBrowser.Destination) -> String {
        func name(_ id: TrackID) -> String { store.project.track(id)?.name ?? "Track" }
        switch destination {
        case .track(let id, _): return "On \(name(id)) at the Playhead"
        case .sampler(let id): return "Sampler of \(name(id))"
        case .wavetable(let id): return "Wavetable of \(name(id))"
        case .video(let id?, _): return "On \(name(id)) at the Playhead"
        case .video(nil, _): return "On a New Video Track"
        }
    }

    private func measuredNote(of item: MediaBrowser.Item) -> Int? {
        if case .note(let reading) = model.pitches[item.id] { return reading.note }
        return nil
    }

    /// Puts `item` at `destination`: the playhead's tick read now, at the tap, never in the body.
    /// `rootKey` makes the measured note the sampler's root in the same undo step.
    private func place(_ item: MediaBrowser.Item, on destination: MediaBrowser.Destination, rootKey: Int? = nil) {
        let tick = Swift.min(Swift.max(0, engine.playheadTick(in: store.project)), MusicalTime.maximumTick)
        let target: MediaBrowser.Destination
        switch destination {
        case .track(let id, _): target = .track(id, at: tick)
        case .video(let id, _): target = .video(id, at: tick)
        default: target = destination
        }
        if let media = item.media {
            do {
                let commands = try MediaBrowser.commands(placing: media, on: target, in: store.project, rootKey: rootKey)
                try store.perform(commands, title: "Place \(item.name)")
                model.message = nil
            } catch {
                model.message = "Could not place \(item.name) there."
            }
            return
        }
        guard let url = item.location else { return }
        model.message = nil
        Task {
            switch target {
            case let .track(id, start): await documents.importAudio(url, placingOn: id, at: start)
            case .sampler(let id): await documents.importAudio(url, onto: id, rootKey: rootKey)
            case .wavetable(let id): await documents.importWavetable(url, onto: id)
            case let .video(id, start): await documents.importVideo(url, onto: id, at: start)
            }
        }
    }
}

/// One file: its name and what is measured, a listen button and the place menu. The text reads as
/// one element to VoiceOver; at the largest text sizes the buttons go under it.
private struct MediaBrowserRow<Listen: View, Place: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let item: MediaBrowser.Item
    let details: [String]
    @ViewBuilder let listen: Listen
    @ViewBuilder let place: Place

    var body: some View {
        if typeSize >= Theme.Accessibility.denseStripLimit {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                text
                HStack(spacing: Theme.Space.s) {
                    listen
                    place
                }
            }
        } else {
            HStack(spacing: Theme.Space.s) {
                text
                Spacer(minLength: Theme.Space.s)
                listen
                place
            }
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(item.name)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
                .lineLimit(2)
            Text(details.joined(separator: " · "))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityValue(details.joined(separator: ", "))
    }
}

/// Listen and Stop for one file. Whether the take still sounds is asked of the player here, in this
/// leaf, a few times a second while it plays — never in the browser's body (Law 6).
private struct ListenButton: View {
    let name: String
    let take: UInt64?
    let player: PreviewPlayer
    let enabled: Bool
    let toggle: () -> Void

    var body: some View {
        if let take {
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                button(playing: player.isPlaying(take))
            }
        } else {
            button(playing: false)
        }
    }

    private func button(playing: Bool) -> some View {
        Button(action: toggle) {
            Image(systemName: playing ? "stop.fill" : "play.fill")
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled && !playing)
        .accessibilityLabel(playing ? "Stop \(name)" : "Listen to \(name)")
    }
}
