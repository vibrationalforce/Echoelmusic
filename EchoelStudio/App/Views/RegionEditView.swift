import EchoelCore
import EchoelDSP
import SwiftUI

/// One audio region's fades, level and warp (AUD-2): the fade-in and fade-out in milliseconds with
/// a curve each, the region's own gain in dB before the track's fader, and whether it follows the
/// song's tempo from the tempo its file was played at. Every change is a
/// command through the store; a drag of one field is one undo step. Opened from the region's
/// hold menu ("Fades & Gain…") through the one sheet slot.
struct RegionEditView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    @Environment(\.dismiss) private var dismiss
    let trackID: TrackID
    let regionID: RegionID

    /// Listening to the region's file for its tempo, before Follow Song Tempo turns on (W-1).
    @State private var listening: Task<Void, Never>?
    /// What the listening found, said under the toggle.
    @State private var tempoNote: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Region")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            store.endGesture()
                            dismiss()
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
        .onDisappear { listening?.cancel() }
    }

    /// The region and its file as the song has them now; nil once either is gone (undone, deleted).
    private var current: (region: AudioRegion, file: MediaFile)? {
        guard let track = store.project.track(trackID), let index = track.regionIndex(regionID) else { return nil }
        let region = track.regions[index]
        guard let file = store.project.mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite else { return nil }
        return (region, file)
    }

    @ViewBuilder private var content: some View {
        ScrollView {
            if let current {
                form(current.region, file: current.file)
                    .padding(Theme.Space.l)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                Text("This region is no longer in the song.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(Theme.Space.l)
            }
        }
        .background(Theme.Color.background)
        .numberPadHost()
    }

    private func form(_ region: AudioRegion, file: MediaFile) -> some View {
        let lengthMS = Self.milliseconds(region.length, rate: file.sampleRate)
        let fades = region.effectiveFades
        let fadeInMS = Self.milliseconds(fades.fadeIn, rate: file.sampleRate)
        let fadeOutMS = Self.milliseconds(fades.fadeOut, rate: file.sampleRate)
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(file.name)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.textSecondary)
            fadeRow(title: "Fade In", milliseconds: fadeInMS, limit: Swift.max(0, lengthMS - fadeOutMS),
                    curve: region.fadeInCurve, key: "in") { ms in
                setFades(region, file: file, fadeIn: Self.frames(ms, rate: file.sampleRate), fadeOut: fades.fadeOut)
            } setCurve: { curve in
                var next = region
                next.fadeInCurve = curve
                perform(fades: next, file: file)
            }
            fadeRow(title: "Fade Out", milliseconds: fadeOutMS, limit: Swift.max(0, lengthMS - fadeInMS),
                    curve: region.fadeOutCurve, key: "out") { ms in
                setFades(region, file: file, fadeIn: fades.fadeIn, fadeOut: Self.frames(ms, rate: file.sampleRate))
            } setCurve: { curve in
                var next = region
                next.fadeOutCurve = curve
                perform(fades: next, file: file)
            }
            SettingField(title: "Gain", value: Int((region.gainDB ?? 0).rounded()),
                         range: Int(AudioRegion.gainRange.lowerBound)...Int(AudioRegion.gainRange.upperBound),
                         unit: "dB", standard: 0, spokenUnit: "decibels") { db in
                try? store.perform(.setRegionGain(track: trackID, regionID, gainDB: Double(db)),
                                   coalescingKey: "region.gain.\(regionID)")
            }
            warp(region)
                .padding(.top, Theme.Space.m)
        }
    }

    /// Follow Song Tempo and the tempo the file was played at. The tempo is typed or stepped, never
    /// dragged: every value stretches the region anew. Turned on for a region with no native tempo,
    /// the region's audio is listened to first, and what is heard is the tempo it turns on with.
    @ViewBuilder private func warp(_ region: AudioRegion) -> some View {
        let native = region.nativeBPM ?? store.project.tempoMap.bpm(at: region.start)
        Toggle("Follow Song Tempo", isOn: Binding(get: { region.followsTempo == true }, set: { on in
            store.endGesture()
            if on, !region.hasNativeBPM {
                listenThenFollow(region)
            } else {
                tempoNote = nil
                try? store.perform(.setRegionWarp(track: trackID, regionID, nativeBPM: Self.heldBPM(native), followsTempo: on))
            }
        }))
        .toggleStyle(EchoelToggleStyle())
        .disabled(listening != nil)
        .accessibilityHint("Plays the region in time with the song's tempo, its pitch unchanged.")
        if listening != nil {
            Text("Listening for the tempo the file was played at…")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        } else if let tempoNote {
            Text(tempoNote)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        SettingField(title: "Native Tempo", value: Int(Self.heldBPM(native).rounded()),
                     range: Int(AudioRegion.nativeBPMRange.lowerBound)...Int(AudioRegion.nativeBPMRange.upperBound),
                     unit: "BPM", standard: Int(store.project.tempoMap.bpm(at: region.start).rounded()),
                     spokenUnit: "beats a minute", drags: false) { bpm in
            store.endGesture()
            try? store.perform(.setRegionWarp(track: trackID, regionID, nativeBPM: Double(bpm),
                                              followsTempo: region.followsTempo == true))
        }
        .disabled(region.followsTempo != true)
    }

    /// Reads the region's frames for their tempo off the main thread, then turns Follow Song Tempo
    /// on with what was heard — or, when no steady tempo was heard, with the song's tempo, said so.
    /// One command, so one undo step.
    private func listenThenFollow(_ region: AudioRegion) {
        let songBPM = store.project.tempoMap.bpm(at: region.start)
        guard let file = current?.file, let url = documents.mediaURL(file) else {
            let start = region.warpStart(heard: nil, songBPM: songBPM)
            if follow(from: start) {
                tempoNote = "The file is not where the song keeps it, so the region keeps the song's tempo of "
                    + Self.shown(start.bpm) + ". Set Native Tempo to the tempo the file was played at."
            }
            return
        }
        let offset = region.offset, length = region.length
        let beats = TempoAnalysis.beatsPerBar(at: region.start, in: store.project)
        listening = Task {
            let reading = Task.detached(priority: .userInitiated) {
                TempoAnalysis.tempo(of: url, offset: offset, length: length, beatsPerBar: beats,
                                    isCancelled: { Task.isCancelled })
            }
            let heard = await withTaskCancellationHandler { await reading.value } onCancel: { reading.cancel() }
            listening = nil
            guard !Task.isCancelled, let now = current?.region, now.followsTempo != true else { return }
            follow(from: now.warpStart(heard: heard?.bpm, songBPM: store.project.tempoMap.bpm(at: now.start)))
        }
    }

    /// Turns Follow Song Tempo on from `start`, and says where its tempo came from; false when the
    /// song refused it (the region would end past its last bar).
    @discardableResult
    private func follow(from start: (bpm: Double, source: WarpTempoSource)) -> Bool {
        do {
            try store.perform(.setRegionWarp(track: trackID, regionID, nativeBPM: start.bpm, followsTempo: true))
        } catch {
            tempoNote = "The region cannot follow the song's tempo here: it would end past the song's last bar."
            return false
        }
        switch start.source {
        case .heard:
            tempoNote = "Heard " + Self.shown(start.bpm)
                + " in the file. If it plays twice as fast or slow, double or halve Native Tempo."
        case .song:
            tempoNote = "No steady tempo was heard, so the region keeps the song's tempo of "
                + Self.shown(start.bpm) + ". Set Native Tempo to the tempo the file was played at."
        case .stored:
            tempoNote = nil
        }
        return true
    }

    static func shown(_ bpm: Double) -> String { NumberText.string(bpm, decimalsUpTo: 2, unit: "BPM") }

    static func heldBPM(_ bpm: Double) -> Double {
        guard bpm.isFinite else { return 120 }
        return Swift.min(Swift.max(bpm, AudioRegion.nativeBPMRange.lowerBound), AudioRegion.nativeBPMRange.upperBound)
    }

    private func fadeRow(title: String, milliseconds: Int, limit: Int, curve: FadeCurve, key: String,
                         set: @escaping (Int) -> Void, setCurve: @escaping (FadeCurve) -> Void) -> some View {
        HStack(alignment: .center, spacing: Theme.Space.s) {
            SettingField(title: title, value: Swift.min(milliseconds, limit), range: 0...Swift.max(limit, 0), unit: "ms",
                         standard: 0, spokenUnit: "milliseconds", commit: set)
            Picker("\(title) Curve", selection: Binding(get: { curve }, set: setCurve)) {
                ForEach(FadeCurve.allCases, id: \.self) { option in
                    Text(Self.name(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityLabel("\(title) Curve")
        }
    }

    private func setFades(_ region: AudioRegion, file: MediaFile, fadeIn: Int, fadeOut: Int) {
        var next = region
        next.fadeIn = fadeIn
        next.fadeOut = fadeOut
        perform(fades: next, file: file)
    }

    /// The region's fades as `next` holds them, each held inside the region, one coalesced step.
    private func perform(fades next: AudioRegion, file: MediaFile) {
        let rise = Swift.min(Swift.max(next.fadeIn ?? 0, 0), next.length)
        let fall = Swift.min(Swift.max(next.fadeOut ?? 0, 0), next.length - rise)
        try? store.perform(.setRegionFades(track: trackID, regionID, fadeIn: rise, fadeOut: fall,
                                           fadeInCurve: next.fadeInCurve, fadeOutCurve: next.fadeOutCurve),
                           coalescingKey: "region.fades.\(regionID)")
    }

    static func name(_ curve: FadeCurve) -> String {
        switch curve {
        case .linear: "Linear"
        case .equalPower: "Equal Power"
        case .exponential: "Slow Start"
        case .sCurve: "S-Curve"
        }
    }

    static func milliseconds(_ frames: Int, rate: Double) -> Int {
        guard rate > 0, rate.isFinite else { return 0 }
        return Int((Double(frames) * 1_000 / rate).rounded(.down))
    }

    static func frames(_ milliseconds: Int, rate: Double) -> Int {
        guard rate > 0, rate.isFinite else { return 0 }
        return Int((Double(milliseconds) * rate / 1_000).rounded())
    }
}
