//
//  AudioPartEditorView.swift
//  Echoelmusic — Studio (GMMW AE-2, founder 2026-10-08: "Die klassische DAW Audio Editing View
//  fehlt mir noch.")
//
//  WHY THIS EXISTS. An audio part's wave sat only inside its block on the Arrange canvas — a
//  strip a few points tall, cut to the stretch the part plays. Every DAW's audio editor shows
//  the WHOLE file with the part's window marked on it, so a person can see what the part leaves
//  out before and after, where the hits are, and where the song is in the file. This is that
//  view, on the selected track's Part page, above the part list. READ-ONLY in this slice: the
//  edge, fade and slip handles are AE-4b, AE-5 and AE-6, and each will call the pure rules that
//  already exist (`PartTrim`, `FadeEnvelope`) rather than a lookalike.
//
//  ⭐ NO NEW TRUTH (#416). The part's window is `ArrangeCanvas.audioWindow` — the player's own
//  file position and stretch rate, the stretch the canvas block draws. The file is read by
//  `WaveformSketch.overview(ofRef:)` and cut into columns by `WaveformSketch.window`, the
//  canvas leaf's bucket rule. The fade level is the window's own `fadeLevel` (`FadeEnvelope`).
//  The file's length is the one measured at import (`Clip.nativeDurationSeconds`); a clip from
//  an older build without it takes the overview's own length once read.
//
//  ⚠️ THE FILE IS FOUND BY THE PLAYER'S RESOLVER (#1439). `MediaLibrary.resolveRef` is the
//  function the app's injected `resolveURL:` closure calls for `AudioLanePlayer`; it is asked
//  here OFF the main actor, inside the detached read, as `WaveformSketch` asks it — the
//  player's own `resolvedURL(forClipID:)` wrapper is main-actor state and would put a file-
//  system probe in `body`. So the editor says "file not found" exactly when the player skips
//  the part.
//
//  ⚠️ THE READ IS OFF THE MAIN ACTOR AND CANCELLABLE, the `AudioPartWaveform` shape: a
//  `Task.detached` read whose cancellation the `.task(id:)` forwards — a part deselected or
//  re-pointed mid-read stops within one chunk and never lands over the newer one. It lands in
//  `@State` once per file. This is a SECOND read of a file the canvas block may already have
//  read; it happens once per selected file, detached and bounded by `WaveformSketch`'s caps.
//
//  ⚠️ NOTHING IN THE EDITOR'S BODY IS HOT. The selection changes on a tap, the document on an
//  edit, the tempo is `preflightTempo` (`@ObservationIgnored`, the number the canvas draws by).
//  The song position is read ONLY inside `AudioPartPlayheadView`, a self-driving 15 Hz leaf that
//  is paused while the song is stopped — the `PartNotePlayheadView` shape, one page over. A
//  position read in this body would rebuild the Part page 15 times a second (10.76.41/50).
//
//  ⚠️ NO MODAL. The editor is inline on a page that already exists: no sheet, no cover, no
//  popover, no new page word (the black-screen law on the presentation chain).
//

import SwiftUI

/// The pure half: which part the editor shows, what its header says, and where on the file the
/// part and the song are.
enum AudioPartEditor {

    /// What the editor draws for the selected part.
    struct Subject: Equatable, Sendable {
        let regionID: UUID
        let partStartTick: Int
        let lengthTicks: Int
        /// The stretch of the file the part plays (the canvas's own, #416).
        let window: ArrangeCanvas.AudioWindow
        /// The clip's name as the canvas block shows it; empty when it has none.
        let name: String
        /// The file's length measured at import, or nil for a clip from before that measurement.
        let fileSeconds: Double?
    }

    /// How far the file read has got.
    enum Load: Equatable, Sendable {
        case reading
        /// The player's resolver finds no file: the part plays silence (#1439).
        case missing
        /// The file is there but cannot be drawn (unreadable, empty, or past the read caps).
        case unreadable
        case ready(WaveformSketch.Overview)
    }

    /// The selected part when it sits on THIS track — nil for no selection or a part elsewhere.
    nonisolated static func selectedPart(_ regionID: UUID?, track laneID: UUID,
                                         in document: TimelineDocument) -> TimelineRegion? {
        guard let regionID else { return nil }
        return document.regions.first { $0.id == regionID && $0.laneID == laneID }
    }

    /// The editor's subject for a part and its clip at the cold tempo, or nil when the part does
    /// not play a stretch of a file — a MIDI part, a clip without a file, a tempo that is not a
    /// tempo (the gate is `ArrangeCanvas.audioWindow`'s own). A non-finite or non-positive
    /// measured length counts as unmeasured.
    nonisolated static func subject(for region: TimelineRegion, clip: Clip?, bpm: Double) -> Subject? {
        guard let window = ArrangeCanvas.audioWindow(for: region, clip: clip, bpm: bpm) else { return nil }
        let measured = clip?.nativeDurationSeconds.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        return Subject(regionID: region.id, partStartTick: region.startTick, lengthTicks: region.lengthTicks,
                       window: window, name: ArrangeCanvas.partName(clip), fileSeconds: measured)
    }

    /// The file's length to draw against: the measured one, else the overview's own once read
    /// (its last bucket may cover less, so it can read long by at most one bucket), else nil.
    nonisolated static func fileSeconds(_ subject: Subject, load: Load) -> Double? {
        if let measured = subject.fileSeconds { return measured }
        guard case .ready(let overview) = load else { return nil }
        let seconds = Double(overview.buckets.count) * overview.secondsPerBucket
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }

    /// The part's window on the file, as fractions of the file (0…1): where the part starts
    /// playing and where it stops. A part that runs past the file's end is cut at 1 (it plays
    /// silence there, `WaveformSketch.window`'s rule). nil for degenerate input or a window
    /// wholly outside the file.
    nonisolated static func span(of window: ArrangeCanvas.AudioWindow, fileSeconds: Double) -> ClosedRange<Double>? {
        guard fileSeconds.isFinite, fileSeconds > 0, window.fromSeconds.isFinite,
              window.lengthSeconds.isFinite, window.lengthSeconds > 0 else { return nil }
        let start = window.fromSeconds / fileSeconds
        let end = (window.fromSeconds + window.lengthSeconds) / fileSeconds
        guard end > 0, start < 1 else { return nil }
        return start.clamped(to: 0...1)...end.clamped(to: 0...1)
    }

    /// Where the song is on the file, 0…1, or nil when the song is not inside the part (before
    /// its start, at or past its end), the input is degenerate, or the point lies past the
    /// file's end. Measured from the part's start, through the part's own window: a tick a
    /// fraction into the part is that fraction into the window.
    nonisolated static func playheadFraction(tick: Int, partStartTick: Int, lengthTicks: Int,
                                             window: ArrangeCanvas.AudioWindow, fileSeconds: Double) -> Double? {
        guard lengthTicks > 0, fileSeconds.isFinite, fileSeconds > 0,
              window.fromSeconds.isFinite, window.lengthSeconds.isFinite else { return nil }
        let into = tick - partStartTick
        guard into >= 0, into < lengthTicks else { return nil }
        let seconds = window.fromSeconds + Double(into) / Double(lengthTicks) * window.lengthSeconds
        let fraction = seconds / fileSeconds
        guard fraction.isFinite, fraction >= 0, fraction <= 1 else { return nil }
        return fraction
    }

    /// The header's second line: what the part plays of the file, in seconds — or why there is
    /// no wave. Science first: the numbers, then nothing decorative.
    nonisolated static func summary(_ subject: Subject, load: Load) -> String {
        switch load {
        case .missing:
            return String(localized: "File not found — this part plays silence")
        case .unreadable:
            return String(localized: "This file cannot be drawn")
        case .reading, .ready:
            let from = subject.window.fromSeconds
            let to = from + subject.window.lengthSeconds
            let plays = String(localized: "Plays ") + seconds(from) + "–" + seconds(to) + " s"
            guard let total = fileSeconds(subject, load: load) else { return plays }
            return plays + String(localized: " of ") + seconds(total) + " s"
        }
    }

    /// A time in seconds with two decimals, in the reader's locale.
    nonisolated static func seconds(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }
}

/// The audio part editor: the selected audio part's whole file, its window bright and the rest
/// dimmed, under a cold header. Draws nothing unless the selected part on this track plays a
/// stretch of a file.
struct AudioPartEditorView: View {

    @Environment(TimelineStore.self) private var timeline
    @Environment(WorkstationSelection.self) private var selection
    @Environment(ClipStore.self) private var clipStore
    /// Read for `preflightTempo` only — `@ObservationIgnored`, the cold number the canvas draws by.
    @Environment(TimelineRegionPlayer.self) private var player

    let laneID: UUID

    var body: some View {
        let document = timeline.document
        if let region = AudioPartEditor.selectedPart(selection.regionID, track: laneID, in: document),
           let lane = document.lanes.first(where: { $0.id == laneID }),
           let subject = AudioPartEditor.subject(for: region, clip: clipStore.clip(id: region.clipID),
                                                 bpm: player.preflightTempo) {
            // The track's own hue, as its blocks on the canvas draw it.
            AudioPartEditorPane(subject: subject,
                                tint: EchoelTheme.TrackHue.of(kind: lane.kind, instrument: lane.builtinInstrument,
                                                              isBio: lane.isBio).color)
        }
    }
}

/// The editor's content for one subject. Its own struct so the file read is keyed to the file
/// alone (`.task(id:)`), and a gain or fade edit redraws without re-reading.
private struct AudioPartEditorPane: View {

    let subject: AudioPartEditor.Subject
    let tint: Color

    @State private var load: AudioPartEditor.Load = .reading

    var body: some View {
        let load = self.load
        let total = AudioPartEditor.fileSeconds(subject, load: load)
        let summary = AudioPartEditor.summary(subject, load: load)
        VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
            Text(subject.name.isEmpty ? String(localized: "Audio part") : subject.name)
                .font(EchoelTheme.font(12, .semibold))
                .foregroundStyle(EchoelTheme.text)
                .lineLimit(1)
            Text(summary)
                .font(EchoelTheme.font(11).monospacedDigit())
                .foregroundStyle(EchoelTheme.dim)
            ZStack(alignment: .leading) {
                AudioPartFileWave(subject: subject, load: load, fileSeconds: total, tint: tint)
                if let total {
                    AudioPartPlayheadView(subject: subject, fileSeconds: total)
                }
            }
            .frame(minHeight: 72)
            .background(EchoelTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Audio part editor") + ", "
                            + (subject.name.isEmpty ? String(localized: "Audio part") : subject.name))
        .accessibilityValue(summary)
        .task(id: subject.window.mediaRef) {
            let ref = subject.window.mediaRef
            self.load = .reading
            let reader = Task.detached(priority: .utility) { () -> AudioPartEditor.Load in
                guard MediaLibrary.resolveRef(ref) != nil else { return .missing }
                guard let overview = WaveformSketch.overview(ofRef: ref) else { return .unreadable }
                return .ready(overview)
            }
            let read = await withTaskCancellationHandler {
                await reader.value
            } onCancel: {
                reader.cancel()
            }
            // A detached hop does not inherit cancellation: a read for a file this part no
            // longer plays must not land over the newer one.
            guard !Task.isCancelled else { return }
            self.load = read
        }
    }
}

/// The whole file's wave: the part's window in full hue at the level its gain and fades leave
/// it, the rest dimmed. Takes no touches and says nothing — the pane speaks for the part.
private struct AudioPartFileWave: View {

    let subject: AudioPartEditor.Subject
    let load: AudioPartEditor.Load
    let fileSeconds: Double?
    let tint: Color

    var body: some View {
        let subject = self.subject
        let load = self.load
        let total = self.fileSeconds
        let tint = self.tint
        Canvas { context, size in
            guard case .ready(let overview) = load, let total, size.width > 0, size.height > 0 else { return }
            let window = subject.window
            let columns = WaveformSketch.window(overview, fromSeconds: 0, lengthSeconds: total,
                                                columns: WaveformSketch.columns(forWidthPoints: Double(size.width)),
                                                gain: window.gain)
            guard !columns.isEmpty else { return }
            let span = AudioPartEditor.span(of: window, fileSeconds: total)
            let mid = size.height / 2
            let width = size.width / CGFloat(columns.count)
            var inside = Path()
            var outside = Path()
            for (index, column) in columns.enumerated() {
                let centre = (Double(index) + 0.5) / Double(columns.count)
                let x = CGFloat(index) * width
                var level: CGFloat = 1
                var bright = false
                if let span, span.contains(centre), span.upperBound > span.lowerBound {
                    bright = true
                    // The level the part's fades leave at this point of the part (`FadeEnvelope`).
                    level = CGFloat(window.fadeLevel(atFraction: (centre - span.lowerBound)
                                                     / (span.upperBound - span.lowerBound)))
                }
                let top = mid - CGFloat(column.max) * level * mid
                let bottom = mid - CGFloat(column.min) * level * mid
                let rect = CGRect(x: x, y: top, width: width, height: Swift.max(Self.hairline, bottom - top))
                if bright { inside.addRect(rect) } else { outside.addRect(rect) }
            }
            context.fill(outside, with: .color(tint.opacity(Self.dimOpacity)))
            context.fill(inside, with: .color(tint))
            // The window's two edges, so a quiet edge still reads where the part starts and stops.
            if let span {
                var edges = Path()
                for fraction in [span.lowerBound, span.upperBound] {
                    let x = CGFloat(fraction) * size.width
                    edges.move(to: CGPoint(x: x, y: 0))
                    edges.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(edges, with: .color(EchoelTheme.borderStrong), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The thinnest a column is drawn — silence is a line, not nothing.
    private static let hairline: CGFloat = 0.5
    /// The file outside the part's window: present, but plainly not what the part plays.
    private static let dimOpacity: Double = 0.25
}

/// The song position on the file. The ONLY reader of `currentTick` in this file: it self-drives
/// at 15 Hz while the song plays and is paused (and absent) while it is stopped, so the pane
/// above it never observes the position. Hidden from VoiceOver — the Workstation's song-position
/// readout speaks where the song is.
struct AudioPartPlayheadView: View {

    @Environment(TimelineRegionPlayer.self) private var player

    let subject: AudioPartEditor.Subject
    let fileSeconds: Double

    var body: some View {
        let playing = player.isPlaying
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing)) { _ in
            GeometryReader { geometry in
                if playing,
                   let fraction = AudioPartEditor.playheadFraction(tick: player.currentTick,
                                                                   partStartTick: subject.partStartTick,
                                                                   lengthTicks: subject.lengthTicks,
                                                                   window: subject.window,
                                                                   fileSeconds: fileSeconds) {
                    Rectangle()
                        .fill(EchoelTheme.accent)
                        .frame(width: 1)
                        .offset(x: geometry.size.width * fraction)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
