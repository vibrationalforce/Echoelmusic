//
//  SelectedPartBar.swift
//  Echoelmusic — Studio (WA4 critical path 5: edit the part selected on the Arrange canvas)
//
//  WHY THIS EXISTS. The canvas selects a part; this bar acts on it — one bar earlier / later,
//  trim start / end (one grid step inward, `PartTrim`), split, copy, remove. Every write is `TimelineStore`'s existing method (one call = one undo
//  step, `snapshotForUndo` inside each); the playing engine chases a structural edit live.
//  Nothing here is a second truth: the part is resolved from the document on every render,
//  and a part that no longer exists (after Remove, Undo, Open) simply hides the bar.
//
//  ⭐ SPLIT KEEPS WARPED AUDIO SEAMLESS. `TimelineRegion.split(at:bpm:)` advances the second
//  piece's media offset by the elapsed time at the `bpm` it is handed. For an unwarped part
//  that is the song tempo. For a WARPED part it is not: the engine consumes media `rate×` as
//  fast as song time passes (`AudioRegionPlayback.filePositionSeconds`), so a split at the song
//  tempo started the second half `rate×` too early or late in the file — an audible jump at
//  the cut. `PartSplit.mediaBPM` hands the split the tempo at which media time elapses, asked
//  from the SAME `StretchPlan.resolve` the engine plays with (#416), so the second half starts
//  exactly where the first stopped.
//
//  ⚠️ WHERE SPLIT CUTS: the song-grid bar nearest the part's middle, or the nearest beat when
//  no bar line falls inside it — canonical snapping, never a free tick. A part one beat long
//  or shorter cannot be split and the button says so by being unavailable.
//
//  ⚠️ AND A CUT MAY NOT CHANGE WHO PLAYS (review MEDIUM-1). The second half starts later than
//  the original, and `activeRegion` gives an overlap to the later start — so cutting a part
//  that another part overlaps could hand bars back to the buried one. `PartSplit.keepsWhoPlays`
//  asks the one precedence rule before and after; if any tick changes hands, Split is refused
//  and its label says why.
//
//  ⚠️ TRIM ONLY TAKES AWAY, and under the same rule: a trimmed start moves later and can win an
//  overlap it used to lose, so `PartTrim.onlyLetsGo` lets a trim change nothing but the ticks
//  the part gives up — revealing a part underneath is what a trim is for; stealing bars is not.
//
//  Cold reads only: the selection and `timeline.document` change on a tap. The song tempo and
//  the clip are read INSIDE the Split and Trim-start handlers, never in `body`.
//
//  ⭐ M10 — PLAY FROM THE PART, ONE TAP ABOVE ITS NOTES. The loop OPEN → EDIT → PLAY ended at
//  the Workstation's Play, below every track row and far from the note grid — and it always
//  started the song from the top. `PartPlayButton` starts it from the selected part's bar. It
//  starts nothing itself: `playFrom` is the Workstation's one start (`startTimeline`, the one
//  `player.play(` caller) and `songCanStart` its one `canPlay` question, both handed in. The
//  button reads `player.isPlaying` in its OWN body (twice per take), never in this bar's.
//
//  ⭐ W2 — AN AUDIO PART HAS ITS OWN LEVEL (audio editor, founder 2026-10-08: "Die klassische DAW
//  Audio Editing View fehlt mir noch."). `TimelineRegion.gain` was played by `AudioLanePlayer`
//  (the part's gain rides on its track's) and exported with it, but nothing could set it:
//  `TimelineStore.setRegionGain` had no caller. `PartGainField` sets it — offered ONLY for a part
//  on an audio track, because the MIDI player never reads a region's gain and a control that moves
//  nothing is a lie (#164). It writes once, on release, through `setRegionGain`: one undo step
//  per change, never one per drag step. The waveform on the canvas (W1) is drawn at the part's
//  gain, so the change is seen as well as heard. Join refuses two halves of different level — the
//  store's own `abuts` rule (CLIP-6) — so a re-levelled half rejoins only once the levels match.
//  Its off label names the split, not the level: that sentence is not widened here.
//
//  ⭐ W9 — NORMALIZE, under the level. One tap sets the part's level so its loudest sample in
//  the stretch it plays reaches full scale (0 dBFS), held to the field's 0…2 — a file quieter
//  than −6 dBFS comes up only +6 dB, and the label says so. It reads the file detached (the
//  canvas's own `WaveformSketch.overview`), finds the peak over the buckets the canvas draws
//  (`WaveformSketch.peak`, one overlap rule) and writes once through `setRegionGain`: one undo
//  step, nothing for a silent or unreadable part. ⚠️ The peak is the FILE's; a stretched part
//  (warp or tape) can peak a little differently once rendered — a device listen, not a claim.
//
//  ⭐ W3 — STRETCH, for a WARPED audio part only. A segmented choice of the modes the timeline
//  plays (`StretchMode.timelineCapabilities`, projected, never retyped): Clean keeps pitch,
//  Tape lets pitch follow speed, Beats keeps hits sharp. One pick is one undo step through
//  `setRegionStretchMode`. An unwarped part plays at rate 1, where all modes sound alike, so it
//  gets no choice. During play Clean and Tape are heard at once; Beats from the part's next
//  start (it is rendered in the background, and a part entered mid-way plays Clean).
//
//  ⭐ W4c — FADE IN / FADE OUT, for a part on an audio track. The part keeps its fades in ticks
//  (W4a) and the player plays them (W4b); these two fields are the door. They speak BEATS, the
//  unit the part stores, so a fade keeps its musical length when the tempo moves and the field
//  needs no tempo at all. The two fades share the part: each field offers only what the other
//  leaves (`PartFades.inRange` / `outRange`), so neither can quietly shorten the other in the
//  store ("in wins", `FadeEnvelope`). A release writes once through `setRegionFades`: one undo
//  step. The canvas draws the ramps over the waveform (`ArrangeCanvas.AudioWindow.fadeLevel`).
//
//  ⭐ GMMW AE-10c — PART PITCH, for a part on an audio track. The part keeps its own pitch (AE-10a)
//  and the player plays track + part (AE-10b, `AudioTranspose.semitones(for:in:)`); this field is
//  the door. Whole semitones over the audio path's range, written once on release through
//  `setRegionTranspose`: one undo step. Off while the piece plays, the track Pitch field's rule —
//  a first pitch needs the time-pitch chain, attached only at prime time.
//
//  ⭐ GMMW AE-9 — SPLIT AT THE PLAYHEAD, the second Split and the DAW's most common cut. The
//  first Split cuts where the bar computes (the part's middle); this one cuts where the playhead
//  is (`PartSplitAtPlayhead`). Stopped, the playhead is the ruler's line — the bar Play starts
//  from, through the ONE fold every surface asks (AE-7) — so the cut lands where the line is
//  drawn. Playing, it is the transport step sounding now. Same handler as Split (the media tempo,
//  one store call = one undo step), same `keepsWhoPlays` refusal, asked again at the tap.
//

import SwiftUI

/// The pure half of Split: where it cuts, and the tempo at which the part's media elapses.
enum PartSplit {

    /// The cut for `part`: the song-grid bar nearest its middle, else the nearest beat, or nil
    /// when no grid line falls strictly inside the part.
    nonisolated static func tick(for part: TrackParts.Part) -> Int? {
        let start = part.startTick
        let end = part.startTick + part.lengthTicks
        guard part.lengthTicks > 1 else { return nil }
        let middle = Double(start) + Double(part.lengthTicks) / 2
        for unit in [TimelineTime.ticksPerBar, TimelineTime.ticksPerBeat] where unit > 0 {
            let snapped = Int((middle / Double(unit)).rounded()) * unit
            if snapped > start, snapped < end { return snapped }
            // The nearest line may sit outside a short part while another is inside it.
            let inward = snapped <= start ? snapped + unit : snapped - unit
            if inward > start, inward < end { return inward }
        }
        return nil
    }

    /// The tempo at which `region`'s MEDIA elapses when the song plays at `projectBPM` — the
    /// song tempo for an unwarped part, the song tempo divided by the engine's stretch rate for
    /// a warped one. nil for a tempo no split may use (non-finite or not positive).
    nonisolated static func mediaBPM(for region: TimelineRegion, clip: Clip?,
                                     projectBPM: Double) -> Double? {
        guard projectBPM.isFinite, projectBPM > 0 else { return nil }
        let rate = StretchPlan.resolve(mode: region.stretchMode,
                                       warpEnabled: region.warpEnabled,
                                       nativeBPM: clip?.nativeBPM ?? 0,
                                       projectBPM: projectBPM,
                                       capabilities: StretchMode.timelineCapabilities).rate
        guard rate.isFinite, rate > 0 else { return projectBPM }
        return projectBPM / rate
    }

    /// Whether cutting `regionID` at `tick` leaves every tick of its track played by the SAME
    /// part (its second half counting as itself). `activeRegion` gives an overlap to the LATER
    /// start, so the second half of a cut starts later than the original did and can win over a
    /// part that used to cover it — a "cut" that un-buries a hidden part (review MEDIUM-1).
    /// Asked of the one precedence rule (#1440) at the bounded set of ticks where the winner
    /// can change (`candidateSampleTicks`), before and after. The tempo handed to the
    /// hypothetical split moves only media offsets, never who plays, so any positive one does.
    nonisolated static func keepsWhoPlays(regionID: UUID, atTick tick: Int,
                                          in document: TimelineDocument) -> Bool {
        guard let index = document.regions.firstIndex(where: { $0.id == regionID }),
              let (first, second) = document.regions[index].split(at: tick, bpm: 120) else {
            return false
        }
        // The store's own placement: the first half in place, the second appended
        // (`TimelineStore.splitRegion`) — placement breaks ties in `activeRegion`.
        var after = document
        after.regions[index] = first
        after.regions.append(second)
        let lane = first.laneID
        let ticks = Set(TimelineScheduling.candidateSampleTicks(in: document, laneID: lane))
            .union(TimelineScheduling.candidateSampleTicks(in: after, laneID: lane))
        for sample in ticks {
            let before = TimelineScheduling.activeRegion(in: document, laneID: lane, at: sample)?.id
            var now = TimelineScheduling.activeRegion(in: after, laneID: lane, at: sample)?.id
            if now == second.id { now = regionID }
            if before != now { return false }
        }
        return true
    }

    /// GMMW AE-9 — the cut "Split at playhead" makes: the transport step the playhead is on
    /// (floored to `ticksPerTransportStep`, the finest step the transport plays), when it falls
    /// strictly inside `part`; nil otherwise — a cut on the part's own edge cuts nothing.
    nonisolated static func playheadCut(for part: TrackParts.Part, atTick tick: Int) -> Int? {
        let step = TimelineTime.ticksPerTransportStep
        guard step > 0, part.lengthTicks > 1 else { return nil }
        let snapped = (Swift.max(0, tick) / step) * step
        guard snapped > part.startTick, snapped < part.startTick + part.lengthTicks else { return nil }
        return snapped
    }

    /// Whether a line of a grid `unit` ticks wide falls strictly inside `part`. With the
    /// transport step it says whether ANY playhead can cut the part (playing: the step sounding
    /// now); with the bar, whether the ruler's line can (stopped: `locate` puts the line on a
    /// bar) — AE-9 review, MED-1: one rule for both, so neither label can point at a ruler tap
    /// that could never help.
    nonisolated static func hasLineInside(_ part: TrackParts.Part, every unit: Int) -> Bool {
        guard unit > 0, part.lengthTicks > 1 else { return false }
        let first = (Swift.max(0, part.startTick) / unit + 1) * unit
        return first < part.startTick + part.lengthTicks
    }

    /// Where the playhead is, for "Split at playhead": playing, the step sounding now; stopped,
    /// the ruler's line — the bar Play starts from, through the ONE fold (AE-7) that draws the
    /// line, so the cut lands where the line is drawn (AE-9 review, MED-4: one composition, asked
    /// by the button's lit state and by its tap alike).
    nonisolated static func playheadTick(playing: Bool, currentTick: Int, cueTick: Int,
                                         in document: TimelineDocument) -> Int {
        playing ? currentTick : TimelineRegionPlayer.playStartTick(forCue: cueTick, in: document)
    }
}

/// The pure half of the part's own level (audio editor W2).
enum PartGain {

    /// The range the field offers — the store's own clamp (`TimelineStore.setRegionGain` and
    /// `TimelineRegion`'s initialiser both clamp to 0…2), so the field never offers a value the
    /// store would quietly change. `AnAudioPartHasItsOwnLevelTests` drives the store at both ends.
    static let range: ClosedRange<Double> = 0...2

    /// The part's own gain when it sits on an AUDIO track — the one kind whose player reads it —
    /// else nil, and the bar offers no level. A part that is gone has none either.
    nonisolated static func gain(of regionID: UUID, in document: TimelineDocument) -> Float? {
        guard let region = document.regions.first(where: { $0.id == regionID }),
              let lane = document.lanes.first(where: { $0.id == region.laneID }),
              lane.kind == .audio, !lane.isBio else { return nil }
        return region.gain
    }

    /// W9 — what Normalize aims the part's loudest sample at: full scale (0 dBFS), the classic
    /// DAW default.
    static let normalizeTarget: Float = 1

    /// The level that brings a part whose loudest sample is `peak` to `normalizeTarget`, held to
    /// `range` — a file quieter than −6 dBFS comes up only +6 dB, the store's own ceiling, and a
    /// peak so small its reciprocal overflows gets that ceiling too. nil for silence or a
    /// non-finite peak: no level makes nothing loud, so Normalize writes nothing.
    nonisolated static func normalizedGain(forPeak peak: Float) -> Float? {
        guard peak.isFinite, peak > 0 else { return nil }
        let wanted = normalizeTarget / peak
        let top = Float(range.upperBound)
        guard wanted.isFinite else { return top }
        return Swift.min(top, Swift.max(Float(range.lowerBound), wanted))
    }
}

/// The pure half of the part's stretch choice (audio editor W3).
enum PartStretch {

    /// The modes the bar offers: the timeline's own executable set, in the enum's order — a
    /// PROJECTION of `StretchMode.timelineCapabilities` (#416), never a list typed here, so the
    /// bar can never offer a mode the store refuses or the player replaces with Clean.
    static var choices: [StretchMode] {
        StretchMode.allCases.filter { StretchMode.timelineCapabilities.contains($0) && $0.isImplemented }
    }

    /// The part's stretch mode when the choice can be HEARD — a warped part on a non-bio audio
    /// track (only a part with a known native tempo can warp, `AudioWarp`) — else nil, and the
    /// bar offers no choice. An unwarped part plays at rate 1, where every mode sounds the
    /// same: a choice there would move nothing (#164).
    nonisolated static func mode(of regionID: UUID, in document: TimelineDocument) -> StretchMode? {
        guard let region = document.regions.first(where: { $0.id == regionID }), region.warpEnabled,
              let lane = document.lanes.first(where: { $0.id == region.laneID }),
              lane.kind == .audio, !lane.isBio else { return nil }
        return region.stretchMode
    }
}

/// The pure half of the part's fades (audio editor W4c).
enum PartFades {

    /// A part's fades as they play — `FadeEnvelope.effective` over its stored ticks, so a part
    /// whose stored lengths do not fit (an older or hand-edited document) shows what is HEARD —
    /// and its length, all in ticks.
    struct Lengths: Equatable {
        let fadeInTicks: Int
        let fadeOutTicks: Int
        let lengthTicks: Int
    }

    /// The fades of `regionID` when it sits on an AUDIO track — the one kind whose player fades
    /// it (`AudioLanePlayer`) — else nil, and the bar offers no fade. The MIDI player never reads
    /// a part's fades; a field there would move nothing (#164).
    nonisolated static func lengths(of regionID: UUID, in document: TimelineDocument) -> Lengths? {
        guard let region = document.regions.first(where: { $0.id == regionID }), region.lengthTicks > 0,
              let lane = document.lanes.first(where: { $0.id == region.laneID }),
              lane.kind == .audio, !lane.isBio else { return nil }
        let fades = FadeEnvelope.effective(fadeIn: Double(region.fadeInTicks),
                                           fadeOut: Double(region.fadeOutTicks),
                                           duration: Double(region.lengthTicks))
        return Lengths(fadeInTicks: Int(fades.fadeIn), fadeOutTicks: Int(fades.fadeOut),
                       lengthTicks: region.lengthTicks)
    }

    /// Ticks as beats, the fields' unit.
    nonisolated static func beats(fromTicks ticks: Int) -> Double {
        Double(ticks) / Double(TimelineTime.ticksPerBeat)
    }

    /// A field's beats as whole ticks — what the store keeps. A non-finite or non-positive value
    /// is no fade; a value past every tick holds at the largest one instead of trapping.
    nonisolated static func ticks(fromBeats beats: Double) -> Int {
        guard beats.isFinite, beats > 0 else { return 0 }
        let ticks = (beats * Double(TimelineTime.ticksPerBeat)).rounded()
        return ticks >= Double(Int.max) ? Int.max : Int(ticks)
    }

    /// What the fade-in field offers: up to what the fade-out leaves, so a fade-in never
    /// shortens the fade-out in the store.
    nonisolated static func inRange(_ lengths: Lengths) -> ClosedRange<Double> {
        0...beats(fromTicks: Swift.max(0, lengths.lengthTicks - lengths.fadeOutTicks))
    }

    /// What the fade-out field offers: up to what the fade-in leaves — exactly the store's rule.
    nonisolated static func outRange(_ lengths: Lengths) -> ClosedRange<Double> {
        0...beats(fromTicks: Swift.max(0, lengths.lengthTicks - lengths.fadeInTicks))
    }
}

/// The pure half of the part's own pitch (GMMW AE-10c).
enum PartPitch {

    /// The part's own pitch when it sits on an AUDIO track — the one kind whose player plays it
    /// (`AudioTranspose.semitones(for:in:)` adds it to the track's) — else nil, and the bar offers
    /// no pitch: a MIDI part's notes are moved in the note editor, and a control that moves
    /// nothing is a lie (#164). A part that is gone has none either. Held to the audio path's
    /// range, so the field shows what the store keeps.
    nonisolated static func semitones(of regionID: UUID, in document: TimelineDocument) -> Int? {
        guard let region = document.regions.first(where: { $0.id == regionID }),
              let lane = document.lanes.first(where: { $0.id == region.laneID }),
              lane.kind == .audio, !lane.isBio else { return nil }
        return AudioTranspose.clamped(region.transposeSemitones)
    }
}

/// The pure half of Trim (WA4 critical path 5, the verb that was held): each edge moves ONE song
/// grid step INWARD — never outward. A trim only takes material away, so the name promises
/// exactly what happens; lengthening a part past its media would be a different act with a
/// different answer per media kind (silence for audio, a loop for MIDI) and stays out.
/// ⚠️ That holds for the bar's two BUTTONS. Since AE-4a the enum also carries the outward rules
/// the audio editor's edge handles ask since AE-4b (snap, precedence, media end) — see its last MARK.
enum PartTrim {

    /// The new start for "Trim start": the first song-grid bar line after the part's start, else
    /// the first beat, strictly inside the part — or nil when no grid line falls inside it.
    nonisolated static func startTick(for part: TrackParts.Part) -> Int? {
        let start = part.startTick
        let end = part.startTick + part.lengthTicks
        guard start >= 0, part.lengthTicks > 1 else { return nil }
        for unit in [TimelineTime.ticksPerBar, TimelineTime.ticksPerBeat] where unit > 0 {
            let next = (start / unit + 1) * unit
            if next > start, next < end { return next }
        }
        return nil
    }

    /// The new end for "Trim end": the last song-grid bar line before the part's end, else the
    /// last beat, strictly inside the part — or nil when no grid line falls inside it.
    nonisolated static func endTick(for part: TrackParts.Part) -> Int? {
        let start = part.startTick
        let end = part.startTick + part.lengthTicks
        guard start >= 0, part.lengthTicks > 1 else { return nil }
        for unit in [TimelineTime.ticksPerBar, TimelineTime.ticksPerBeat] where unit > 0 {
            let previous = ((end - 1) / unit) * unit
            if previous > start, previous < end { return previous }
        }
        return nil
    }

    /// Whether replacing `regionID` with `trimmed` changes NOTHING but the ticks the part let go
    /// of. Trimming the START moves the part's start later, and `activeRegion` gives an overlap
    /// to the later start — so a trim could hand bars the part still covers to it from a part
    /// that used to win them (or the other way round). The one change a trim may make is the
    /// part giving up a tick outside its new span; anything else is refused, asked of the one
    /// precedence rule (#1440) at the bounded set of ticks where the winner can change.
    nonisolated static func onlyLetsGo(_ trimmed: TimelineRegion, replacing regionID: UUID,
                                       in document: TimelineDocument) -> Bool {
        guard let index = document.regions.firstIndex(where: { $0.id == regionID }) else {
            return false
        }
        var after = document
        after.regions[index] = trimmed
        let lane = trimmed.laneID
        let ticks = Set(TimelineScheduling.candidateSampleTicks(in: document, laneID: lane))
            .union(TimelineScheduling.candidateSampleTicks(in: after, laneID: lane))
        for sample in ticks {
            let before = TimelineScheduling.activeRegion(in: document, laneID: lane, at: sample)?.id
            let now = TimelineScheduling.activeRegion(in: after, laneID: lane, at: sample)?.id
            if before == now { continue }
            let stillCovered = sample >= trimmed.startTick && sample < trimmed.endTick
            if before == regionID, !stillCovered { continue }
            return false
        }
        return true
    }

    /// The region "Trim start" would leave, or nil when it cannot move or would change who plays.
    /// The media offset follows at 120 BPM here — it moves no tick, so precedence cannot see it;
    /// the store's write uses the tempo the media really elapses at (`PartSplit.mediaBPM`).
    nonisolated static func startTrim(_ part: TrackParts.Part,
                                      in document: TimelineDocument) -> Int? {
        guard let tick = startTick(for: part),
              let region = document.regions.first(where: { $0.id == part.id }),
              let trimmed = region.trimmedStart(toTick: tick, bpm: 120),
              trimmed.startTick == tick,
              onlyLetsGo(trimmed, replacing: part.id, in: document) else { return nil }
        return tick
    }

    /// The new length "Trim end" would leave, or nil when it cannot move or would change who plays.
    nonisolated static func endTrim(_ part: TrackParts.Part,
                                    in document: TimelineDocument) -> Int? {
        guard let tick = endTick(for: part),
              let region = document.regions.first(where: { $0.id == part.id }) else { return nil }
        var trimmed = region
        trimmed.lengthTicks = tick - region.startTick
        guard onlyLetsGo(trimmed, replacing: part.id, in: document) else { return nil }
        return trimmed.lengthTicks
    }

    // MARK: AE-4a — the rules an edge handle moves by (GMMW, 2026-10-08)
    //
    // The bar's two buttons above only take material away. The audio editor's edge handles
    // (AE-4b) also move an edge OUTWARD, and `onlyLetsGo` refuses any tick a part gains by
    // construction, so the outward move gets its own rule here — beside the inward one, asked of
    // the same precedence (#1440) — plus the grid a handle snaps to and the media bound. Their
    // caller is `AudioPartEditor.edgeEdit` (AE-4b), which the editor's edge handles ask.

    /// The grid an edge handle snaps to at a time zoom: a bar while bars are small on screen
    /// (zoom below 4), a beat below 16, then one transport step. Never finer than a step: the
    /// transport starts and stops a part only on a step. An unusable zoom snaps to the bar.
    nonisolated static func snapUnit(zoom: Double) -> Int {
        guard zoom.isFinite, zoom >= 4 else { return TimelineTime.ticksPerBar }
        return zoom < 16 ? TimelineTime.ticksPerBeat : TimelineTime.ticksPerTransportStep
    }

    /// Whether replacing `regionID` with `extended` — an edge moved OUTWARD — changes who plays
    /// only on ticks the part newly covers where NOTHING played before. Moving the start earlier
    /// can lose an overlap the part used to win (`activeRegion` gives it to the later start), and
    /// moving either edge over another part can take bars that part plays: both are refused. An
    /// outward move fills silence; it never takes a bar from another part or gives one away.
    nonisolated static func keepsWhoPlays(extending extended: TimelineRegion, replacing regionID: UUID,
                                          in document: TimelineDocument) -> Bool {
        guard let index = document.regions.firstIndex(where: { $0.id == regionID }) else {
            return false
        }
        let original = document.regions[index]
        var after = document
        after.regions[index] = extended
        let lane = extended.laneID
        let ticks = Set(TimelineScheduling.candidateSampleTicks(in: document, laneID: lane))
            .union(TimelineScheduling.candidateSampleTicks(in: after, laneID: lane))
        for sample in ticks {
            let before = TimelineScheduling.activeRegion(in: document, laneID: lane, at: sample)?.id
            let now = TimelineScheduling.activeRegion(in: after, laneID: lane, at: sample)?.id
            if before == now { continue }
            let newlyCovered = sample >= extended.startTick && sample < extended.endTick
                && !(sample >= original.startTick && sample < original.endTick)
            if before == nil, now == regionID, newlyCovered { continue }
            return false
        }
        return true
    }

    /// Whether an audio part still ends inside its file: its media offset plus its length, at the
    /// tempo its media elapses at (`PartSplit.mediaBPM` for a warped part), reaches no further
    /// than `mediaSeconds`. An outward end past the file would play silence and draw a wave that
    /// is not there; it is refused. Unusable inputs refuse. The start edge needs no twin:
    /// `TimelineRegion.trimmedStart` already bottoms out at the media start.
    nonisolated static func endFitsMedia(_ region: TimelineRegion, mediaSeconds: Double,
                                         mediaBPM: Double) -> Bool {
        guard mediaSeconds.isFinite, mediaSeconds > 0, mediaBPM.isFinite, mediaBPM > 0,
              region.contentOffsetSeconds.isFinite else { return false }
        let reach = region.contentOffsetSeconds
            + TimelineTime.seconds(fromTicks: region.lengthTicks, bpm: mediaBPM)
        // One microsecond of slack: a part cut exactly at the file's end must not be refused for
        // the rounding of a tick→seconds conversion.
        return reach <= mediaSeconds + 1e-6
    }
}

/// The actions for the part selected on the Arrange canvas.
@MainActor
struct SelectedPartBar: View {

    @Environment(WorkstationSelection.self) private var selection
    @Environment(TimelineStore.self) private var timeline
    /// ⚠️ READ ONLY INSIDE THE SPLIT, TRIM-START AND JOIN HANDLERS — plus ONE read in the body for Join's
    /// enabled state: `preflightTempo` is `@ObservationIgnored`, so that read registers nothing and may go
    /// stale, which is immaterial there (only a legacy part without a tick twin depends on the tempo at
    /// all — `TimelineRegion.abuts` — and the handler re-reads before the store writes). The clip grid is
    /// not this bar's to observe: `clipStore.clip(id:)` stays inside the handlers.
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(ClipStore.self) private var clipStore

    /// The Workstation's one start, from a tick (M10). Required (#431).
    let playFrom: (Int) -> Void
    /// The Workstation's one "would Play start the song?" (M10) — asked in the button's body.
    let songCanStart: () -> Bool

    var body: some View {
        let document = timeline.document
        if let regionID = WorkstationSelection.resolvedRegion(selection.regionID,
                                                              track: selection.trackID, in: document),
           let trackID = selection.trackID,
           TrackParts.arrangeable(trackID, in: document),
           let part = TrackParts.parts(onLane: trackID, in: document).first(where: { $0.id == regionID }) {
            let title = TrackParts.spanTitle(part)
            let cut = PartSplit.tick(for: part)
            // A cut that would change which overlapping part plays is refused, not made.
            let splittable = cut.map { PartSplit.keepsWhoPlays(regionID: regionID, atTick: $0,
                                                                in: document) } ?? false
            let trims = Trims(start: PartTrim.startTrim(part, in: document),
                              endLength: PartTrim.endTrim(part, in: document))
            // Join is the inverse of Split: the store's own `abuts` decides (same lane, same clip, media
            // contiguous, same gain/warp), so a lit button here is one the store will act on.
            let joinable = timeline.canMergeRegionWithNext(id: regionID, bpm: player.preflightTempo)
            VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
                HStack(spacing: EchoelTheme.spaceS) {
                    Text(String(localized: "Selected part · ") + title)
                        .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                    Spacer(minLength: 8)
                    focusButton
                    PartPlayButton(startTick: part.startTick, playFrom: playFrom,
                                   songCanStart: songCanStart)
                }
                PartStartField(part: part, songBars: WorkstationSummary(document: document).lengthBars)
                // W2: an audio part's own level, on top of its track's — nil for any other part.
                if let gain = PartGain.gain(of: regionID, in: document) {
                    PartGainField(regionID: regionID, gain: gain)
                }
                // W3: how a warped audio part keeps the piece's tempo — nil for any other part.
                if let stretch = PartStretch.mode(of: regionID, in: document) {
                    PartStretchPicker(regionID: regionID, mode: stretch)
                }
                // W4c: an audio part's fade-in and fade-out — nil for any other part.
                if let fades = PartFades.lengths(of: regionID, in: document) {
                    PartFadeFields(regionID: regionID, lengths: fades)
                }
                // AE-10c: an audio part's own pitch, on top of its track's — nil for any other part.
                if let pitch = PartPitch.semitones(of: regionID, in: document) {
                    PartPitchField(regionID: regionID, semitones: pitch)
                }
                // Nine labelled buttons do not fit a phone at every type size (review
                // MEDIUM-3): the row falls back to icons, then to two rows of icons — every
                // button keeping its full spoken label.
                ViewThatFits(in: .horizontal) {
                    actionRow(part, regionID: regionID, cut: cut, splittable: splittable,
                              joinable: joinable, trims: trims, showsTitles: true)
                    actionRow(part, regionID: regionID, cut: cut, splittable: splittable,
                              joinable: joinable, trims: trims, showsTitles: false)
                    // AE-9 review (MED-3): seven icons plus their gaps are 356 pt — wider than a
                    // 375-pt phone leaves the bar (339). The last candidate puts "At playhead" up
                    // with the move pair: three icons over six, the widest row 304 pt.
                    VStack(alignment: .leading, spacing: EchoelTheme.spaceS) {
                        HStack(spacing: EchoelTheme.spaceS) {
                            moveRow(part, showsTitles: false)
                            playheadSplit(part, regionID: regionID, showsTitles: false)
                        }
                        editRow(part, regionID: regionID, cut: cut, splittable: splittable,
                                joinable: joinable, trims: trims, showsTitles: false,
                                withPlayheadSplit: false)
                    }
                }
                // Review of 75d27e615 (LOW): a refused Split said why only to VoiceOver — a
                // sighted player saw a dimmed scissors and no reason.
                if cut != nil, !splittable {
                    Text("Split is off here: it would change which overlapping part plays.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                }
            }
        }
    }

    /// GMMW AE-3b — Focus: the selected part's editors take the Arrange plate
    /// (`WorkstationSelection.editorFocused`, AE-3a), and back. A button, not a double-tap: a
    /// double-tap would delay every single tap that selects a part. The ONE writer of focus — it
    /// stays in reach in focus, because the part bar is what focus keeps. The selection ends focus
    /// with the track.
    private var focusButton: some View {
        let focused = selection.editorFocused
        return button(focused ? "Show all" : "Focus",
                      focused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                      enabled: true, showsTitle: true,
                      label: focused ? String(localized: "Show the whole arrangement again")
                                     : String(localized: "Show only the selected part and its track's editors")) {
            selection.setEditorFocused(!selection.editorFocused)
        }
    }

    /// The two edges a trim may move, resolved once per render (nil = unavailable).
    private struct Trims {
        let start: Int?
        let endLength: Int?
    }

    private func actionRow(_ part: TrackParts.Part, regionID: UUID, cut: Int?, splittable: Bool,
                           joinable: Bool, trims: Trims, showsTitles: Bool) -> some View {
        HStack(spacing: EchoelTheme.spaceS) {
            moveRow(part, showsTitles: showsTitles)
            editRow(part, regionID: regionID, cut: cut, splittable: splittable, joinable: joinable,
                    trims: trims, showsTitles: showsTitles, withPlayheadSplit: true)
        }
    }

    private func moveRow(_ part: TrackParts.Part, showsTitles: Bool) -> some View {
        let earlier = TrackParts.earlierStart(part)
        return HStack(spacing: EchoelTheme.spaceS) {
            button("Earlier", "chevron.left", enabled: earlier != nil, showsTitle: showsTitles,
                   label: String(localized: "Move the selected part one bar earlier")) {
                if let tick = earlier { TrackParts.move(part, toStartTick: tick, timeline: timeline) }
            }
            button("Later", "chevron.right", enabled: true, showsTitle: showsTitles,
                   label: String(localized: "Move the selected part one bar later")) {
                TrackParts.move(part, toStartTick: TrackParts.laterStart(part), timeline: timeline)
            }
        }
    }

    private func editRow(_ part: TrackParts.Part, regionID: UUID, cut: Int?, splittable: Bool,
                         joinable: Bool, trims: Trims, showsTitles: Bool,
                         withPlayheadSplit: Bool) -> some View {
        HStack(spacing: EchoelTheme.spaceS) {
            button("Trim start", "arrow.right.to.line", enabled: trims.start != nil,
                   showsTitle: showsTitles, label: trimStartLabel(trims.start)) {
                if let tick = trims.start { trimStart(regionID, to: tick) }
            }
            button("Trim end", "arrow.left.to.line", enabled: trims.endLength != nil,
                   showsTitle: showsTitles, label: trimEndLabel(part, trims.endLength)) {
                if let length = trims.endLength {
                    timeline.resizeRegion(id: regionID, lengthTicks: length)
                }
            }
            button("Split", "scissors", enabled: splittable, showsTitle: showsTitles,
                   label: splitLabel(cut: cut, splittable: splittable)) {
                if splittable, let cut { split(regionID, at: cut) }
            }
            // GMMW AE-9 — the second Split, beside the first (the narrowest layout moves it up
            // to the move pair instead).
            if withPlayheadSplit {
                playheadSplit(part, regionID: regionID, showsTitles: showsTitles)
            }
            button("Join next", "arrow.triangle.merge", enabled: joinable, showsTitle: showsTitles,
                   label: joinLabel(joinable)) {
                if joinable { join(regionID) }
            }
            button("Copy", "plus.square.on.square", enabled: true, showsTitle: showsTitles,
                   label: String(localized: "Copy the selected part to right after it")) {
                TrackParts.duplicate(part, timeline: timeline)
            }
            button("Remove", "trash", enabled: true, showsTitle: showsTitles,
                   label: String(localized: "Remove the selected part. Undo brings it back")) {
                TrackParts.remove(part, timeline: timeline)
            }
        }
    }

    /// GMMW AE-9 — the second Split: where the playhead is. The leaf reads the player; the cut
    /// goes through THIS bar's `split` (media tempo, one undo step) and wears its button.
    private func playheadSplit(_ part: TrackParts.Part, regionID: UUID, showsTitles: Bool) -> some View {
        PartSplitAtPlayhead(part: part, regionID: regionID,
                            split: { split($0, at: $1) }) { enabled, label, action in
            button("At playhead", "scissors.circle", enabled: enabled, showsTitle: showsTitles,
                   label: label, action: action)
        }
    }

    private func trimStartLabel(_ tick: Int?) -> String {
        guard let tick else {
            return String(localized: "The start cannot be trimmed: no grid line inside the part, or it would change which overlapping part plays")
        }
        return String(localized: "Trim the selected part so it starts at ") + SessionGrid.label(forTick: tick)
    }

    private func trimEndLabel(_ part: TrackParts.Part, _ length: Int?) -> String {
        guard let length else {
            return String(localized: "The end cannot be trimmed: no grid line inside the part, or it would change which overlapping part plays")
        }
        return String(localized: "Trim the selected part so it ends at ") + SessionGrid.label(forTick: part.startTick + length)
    }

    private func splitLabel(cut: Int?, splittable: Bool) -> String {
        guard let cut else { return String(localized: "This part is too short to split") }
        guard splittable else {
            return String(localized: "Splitting here would change which overlapping part plays")
        }
        return String(localized: "Split the selected part at ") + SessionGrid.label(forTick: cut)
    }

    private func joinLabel(_ joinable: Bool) -> String {
        joinable
            ? String(localized: "Join the selected part with the part that starts where it ends, as before a split; one undo step")
            : String(localized: "Join is off here: no part starts where this one ends, or the next part is not the other half of a split")
    }

    /// Join is the inverse of Split and asks the same tempo (`PartSplit.mediaBPM`, #416). The store
    /// re-checks `abuts` with it before writing, so a part whose other half was trimmed or mixed
    /// differently is refused there — never joined lossily here. One history step (`snapshotForUndo`).
    private func join(_ regionID: UUID) {
        guard let region = timeline.document.regions.first(where: { $0.id == regionID }),
              let bpm = PartSplit.mediaBPM(for: region, clip: clipStore.clip(id: region.clipID),
                                           projectBPM: player.preflightTempo) else {
            log.log(.info, category: .audio, "Join refused: no usable song tempo")
            return
        }
        timeline.mergeRegionWithNext(id: regionID, bpm: bpm)
    }

    private func split(_ regionID: UUID, at tick: Int) {
        guard let region = timeline.document.regions.first(where: { $0.id == regionID }),
              let bpm = PartSplit.mediaBPM(for: region, clip: clipStore.clip(id: region.clipID),
                                           projectBPM: player.preflightTempo) else {
            log.log(.info, category: .audio, "Split refused: no usable song tempo")
            return
        }
        timeline.splitRegion(id: regionID, atTick: tick, bpm: bpm)
    }

    /// Trim start moves the media offset with the cut, so the tempo is the one the part's media
    /// really elapses at — the same answer Split uses (`PartSplit.mediaBPM`, #416).
    private func trimStart(_ regionID: UUID, to tick: Int) {
        guard let region = timeline.document.regions.first(where: { $0.id == regionID }),
              let bpm = PartSplit.mediaBPM(for: region, clip: clipStore.clip(id: region.clipID),
                                           projectBPM: player.preflightTempo) else {
            log.log(.info, category: .audio, "Trim start refused: no usable song tempo")
            return
        }
        timeline.trimRegionStart(id: regionID, toTick: tick, bpm: bpm)
    }

    // E4-16 (2026-09-30): `title` is a catalog KEY (every caller passes a literal); `label` stays a
    // `String` because three callers COMPUTE it (the trim/split sentences carry a bar label), so each
    // caller localises its own sentence with `String(localized:)` — head piece + bar, never a format key.
    private func button(_ title: LocalizedStringKey, _ systemImage: String, enabled: Bool, showsTitle: Bool,
                        label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: EchoelTheme.spaceXS) {
                Image(systemName: systemImage).font(EchoelTheme.font(11, .semibold))
                if showsTitle {
                    Text(title).font(EchoelTheme.font(11, .semibold)).lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .buttonStyle(EchoelToolButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// M10 — Play the song from the selected part's bar, or Stop it. A leaf: its own reads of the
/// transport and the song stay in its own body. (The Workstation root rebuilds on start and stop
/// anyway — its transport row reads `isPlaying` — and hands this button fresh closures when it
/// does, so `canPlay` runs once there and once here per such render. Cold state, both times.)
///
/// ⚠️ It never calls `player.play(`: `playFrom` is the Workstation's `startTimeline`, which the
/// player floors to the part's bar (`barStartTick`). A part that starts off the grid plays from
/// the bar it starts in. And it asks `songCanStart` rather than `canPlay` — the Workstation is
/// the one control that may ask the engine (`TheWorkstationPlaysTheTimelineTests`), and the
/// answer is the same one its own Play is dimmed by: a button that is lit here does something.
/// ⚠️ While anything runs on the one clock it is Stop — the app's ONE Stop
/// (`ProjectTransport.stop`), never a second start. Review of 09d35f56e, MED-3: it read the song
/// alone, so while the instrument ran it said Play beside a transport row that said Stop, and a
/// tap started the song under the running pattern. It now reads the same running truth as the
/// transport row and the header (`ProjectTransport.isRunning`).
@MainActor
private struct PartPlayButton: View {
    let startTick: Int
    let playFrom: (Int) -> Void
    let songCanStart: () -> Bool
    @Environment(TimelineRegionPlayer.self) private var player
    /// Cold: `isPlaying` flips on a start or a stop, never per step.
    @Environment(Transport.self) private var transport
    /// ⚠️ READ ONLY IN THE TAP HANDLER: `beatPlayer.pattern` leads to the gliding tempo.
    @Environment(BeatPlayer.self) private var beatPlayer

    var body: some View {
        let playing = ProjectTransport.isRunning(clockRunning: transport.isPlaying,
                                                 songPlaying: player.isPlaying)
        let startable = playing || songCanStart()
        Button {
            if playing {
                ProjectTransport.stop(song: player, pattern: beatPlayer.pattern, source: "part bar")
            } else {
                playFrom(startTick)
            }
        } label: {
            HStack(spacing: EchoelTheme.spaceXS) {
                Image(systemName: playing ? "stop.fill" : "play.fill")
                    .font(EchoelTheme.font(11, .semibold))
                Text(playing ? String(localized: "Stop") : String(localized: "Play from here"))
                    .font(EchoelTheme.font(11, .semibold)).lineLimit(1)
                    .fixedSize()   // the title beside it wraps; the action's name never truncates
            }
            .foregroundStyle(playing ? EchoelTheme.accent
                                     : (startable ? EchoelTheme.text : EchoelTheme.dim))
            .padding(.horizontal, EchoelTheme.spaceS)
            .frame(minWidth: 44, minHeight: 44)
            // A tool tile at rest; while the piece plays, the green label plus the strong
            // frame — the one "plays" look (`ProjectHeader`, the plate's Pause).
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(playing ? EchoelTheme.borderStrong : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!startable)
        .accessibilityLabel(playing ? String(localized: "Stop all playback") : String(localized: "Play the piece from the selected part"))
        .accessibilityHint(startable && !playing
            ? String(localized: "Plays the arrangement from this part's bar on the shared transport.")
            : WorkstationSummary.transportHint(playing: playing, startable: startable))
    }
}

/// Design slice 7 — the selected part's start, typed as a bar number.
///
/// Earlier/Later step one bar per tap; a part that belongs twelve bars away took twelve taps
/// and twelve undo steps. The field names the bar and moves there in ONE `TrackParts.move` —
/// one undo step, through the same writer the buttons and the canvas drag use. The place
/// within the bar is kept (`TrackParts.startTick(forBar:keeping:)`), so the field lands where
/// the buttons would have.
///
/// ⚠️ THE MOVE HAPPENS ON COMMIT, NOT PER DRAG STEP. A vertical-fader drag passes through
/// every bar on the way; writing each one would put a dozen undo steps on the song and
/// re-render the canvas per step. The drag edits a draft; the release writes once (the
/// `PartTempoRow` pattern).
///
/// ⚠️ THE DRAFT IS CLEARED WHENEVER THE PART'S START MOVES — by Earlier/Later, a canvas drag,
/// an undo — while a draft is held; the field would otherwise keep showing the bar it was
/// dragged to, not the bar the part is on. (A CANCELLED drag needs no reset: the field puts
/// the draft back itself, #378.)
///
/// ⚠️ THE RANGE FOLLOWS THE SONG (`TrackParts.startBarRange`), because the field's swipe step
/// and drag distance follow its range — see there.
@MainActor
private struct PartStartField: View {
    let part: TrackParts.Part
    /// The song's length in whole bars (`WorkstationSummary.lengthBars`) — cold, per render.
    let songBars: Int
    @Environment(TimelineStore.self) private var timeline
    @State private var draft: Double? = nil

    var body: some View {
        EchoelValueField(label: "Starts at bar",
                         value: Binding(get: { shownBar }, set: { draft = $0 }),
                         range: TrackParts.startBarRange(for: part, songBars: songBars),
                         decimals: 0,
                         hint: String(localized: "Moves the part to start on this bar; its place within the bar is kept."),
                         onCommit: { commitDraft() })
            .onChange(of: part.startTick) { _, _ in draft = nil }
    }

    private var shownBar: Double {
        draft ?? Double(WorkstationSummary.barNumber(forTick: part.startTick))
    }

    private func commitDraft() {
        guard let bar = draft else { return }
        draft = nil
        if let tick = TrackParts.startTick(forBar: bar, keeping: part) {
            TrackParts.move(part, toStartTick: tick, timeline: timeline)
        }
    }
}

/// Audio editor W2 — the selected audio part's own level, on top of its track's level.
///
/// ⚠️ THE LEVEL IS WRITTEN ON COMMIT, NOT PER DRAG STEP — the `PartStartField` pattern above. A
/// vertical-fader drag passes through a hundred values on the way; writing each would put a
/// hundred undo steps on the song and re-render the canvas per step. The drag edits a draft; the
/// release writes once through `TimelineStore.setRegionGain` (a no-op when unchanged), and the
/// playing engine hears it within a step (`AudioLanePlayer`'s live mix reconcile reads it).
///
/// ⚠️ THE DRAFT IS CLEARED WHENEVER THE STORED LEVEL CHANGES — an undo, a redo, another surface —
/// so the field never keeps showing a level the part no longer has.
///
/// The number is the linear gain the model stores (1.00 = the file as it is; a dimensionless value
/// shows as a raw decimal, the UI law), with the decibel reading beside it by the track header's
/// own rule (`TrackMix.decibelText`, #416).
@MainActor
private struct PartGainField: View {
    let regionID: UUID
    /// The part's stored gain — cold, per render.
    let gain: Float
    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clipStore
    @Environment(TimelineRegionPlayer.self) private var player
    @State private var draft: Double? = nil
    /// True while Normalize reads the file — the button is off, so a second tap cannot start a
    /// second read of the same file.
    @State private var normalizing = false

    var body: some View {
        VStack(alignment: .leading, spacing: EchoelTheme.spaceS) {
            HStack(spacing: EchoelTheme.spaceS) {
                EchoelValueField(label: "Part level",
                                 value: Binding(get: { shownGain }, set: { draft = $0 }),
                                 range: PartGain.range,
                                 decimals: 2,
                                 hint: String(localized: "This part's own level, on top of its track's level. 1.00 plays the file as it is."),
                                 standard: 1,
                                 onCommit: { commitGain() })
                Text(TrackMix.decibelText(shownGain))
                    .font(EchoelTheme.font(11).monospacedDigit())
                    .foregroundStyle(EchoelTheme.dim)
                    .accessibilityLabel("Part level in decibels")
                    .accessibilityValue(TrackMix.decibelText(shownGain))
            }
            // W9: on its own line, so the field keeps the row's width at every type size.
            Button { normalize() } label: {
                HStack(spacing: EchoelTheme.spaceXS) {
                    Image(systemName: "waveform").font(EchoelTheme.font(11, .semibold))
                    Text("Normalize").font(EchoelTheme.font(11, .semibold)).lineLimit(1).fixedSize()
                }
            }
            .buttonStyle(EchoelToolButtonStyle())
            .disabled(normalizing)
            .accessibilityLabel("Normalize the selected part: its loudest moment reaches full scale, at most 6 dB louder")
        }
        .onChange(of: gain) { _, _ in draft = nil }
    }

    private var shownGain: Double {
        draft ?? Double(gain)
    }

    private func commitGain() {
        guard let value = draft else { return }
        draft = nil
        timeline.setRegionGain(id: regionID, Float(value))
    }

    /// W9 — Normalize. The part's stretch of the file is the canvas's own (`ArrangeCanvas
    /// .audioWindow`, the player's position and stretch rate), read here at the tap — never in
    /// `body` — with the cold tempo the canvas draws by. The file is read detached, off the main
    /// actor (it opens a whole file); the peak and the level are pure (`WaveformSketch.peak`,
    /// `PartGain.normalizedGain`); the write is ONE `setRegionGain` — one undo step, a no-op when
    /// the part is already there. A file that does not read, a stretch outside the file, or a
    /// silent part writes nothing.
    private func normalize() {
        guard !normalizing,
              let region = timeline.document.regions.first(where: { $0.id == regionID }),
              let window = ArrangeCanvas.audioWindow(for: region, clip: clipStore.clip(id: region.clipID),
                                                     bpm: player.preflightTempo) else { return }
        normalizing = true
        let ref = window.mediaRef
        Task {
            let overview = await Task.detached(priority: .userInitiated) {
                WaveformSketch.overview(ofRef: ref)
            }.value
            normalizing = false
            guard let overview,
                  let peak = WaveformSketch.peak(overview, fromSeconds: window.fromSeconds,
                                                 lengthSeconds: window.lengthSeconds),
                  let level = PartGain.normalizedGain(forPeak: peak) else { return }
            draft = nil
            timeline.setRegionGain(id: regionID, level)
        }
    }
}

/// Audio editor W3 — how the selected WARPED audio part keeps the piece's tempo.
///
/// A named choice is a `Picker` (the UI law's word is "NUMERIC"), segmented, offering exactly
/// the modes the timeline plays (`PartStretch.choices`). One pick is one write through
/// `TimelineStore.setRegionStretchMode`: one undo step. ⚠️ WHEN IT IS HEARD: the edit is
/// structural, so during play the lane re-primes at the current position — Clean and Tape are
/// heard at once; Beats is rendered in the background (`TimelineAudioSink.prepareBeats`) and
/// the part plays Clean until its next start, the player's own honest fallback. The hint says
/// so. The label sits BESIDE the picker: a row label, not a section heading.
@MainActor
private struct PartStretchPicker: View {
    let regionID: UUID
    /// The part's stored mode — cold, per render.
    let mode: StretchMode
    @Environment(TimelineStore.self) private var timeline

    var body: some View {
        HStack(spacing: EchoelTheme.spaceS) {
            Text("Stretch")
                .font(EchoelTheme.font(11, .semibold))
                .foregroundStyle(EchoelTheme.dim)
            Picker("Stretch", selection: Binding(get: { mode },
                                                 set: { timeline.setRegionStretchMode(id: regionID, $0) })) {
                ForEach(PartStretch.choices, id: \.self) { choice in
                    Text(LocalizedStringKey(choice.displayName)).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("How this part keeps the piece's tempo: Clean keeps its pitch, Tape lets the pitch follow the speed, Beats keeps drum hits sharp and is heard from the part's next start.")
        }
    }
}

/// Audio editor W4c — the selected audio part's fade-in and fade-out, in beats.
///
/// ⚠️ EACH FADE IS WRITTEN ON COMMIT, NOT PER DRAG STEP — the `PartGainField` pattern. The drag
/// edits a draft; the release writes once through `TimelineStore.setRegionFades` (a no-op when
/// unchanged): one undo step per gesture. The other fade is written back as it stands, and the
/// field's range keeps the pair inside the part, so the store keeps both as typed.
///
/// ⚠️ BOTH DRAFTS ARE CLEARED WHENEVER THE STORED FADES OR THE PART'S LENGTH CHANGE — an undo, a
/// trim, a split — so a field never keeps showing a fade the part no longer has.
///
/// The unit is the part's own (beats, stored as ticks): a fade lasts its beats at any tempo, the
/// player's rule (`AudioRegionPlayback.fadePlan`). How a fade sounds is a device listen.
@MainActor
private struct PartFadeFields: View {
    let regionID: UUID
    /// The part's fades as they play, and its length — cold, per render.
    let lengths: PartFades.Lengths
    @Environment(TimelineStore.self) private var timeline
    @State private var draftIn: Double? = nil
    @State private var draftOut: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: EchoelTheme.spaceS) {
            EchoelValueField(label: "Fade in",
                             value: Binding(get: { shownIn }, set: { draftIn = $0 }),
                             range: PartFades.inRange(lengths),
                             unit: "beats",
                             decimals: 2,
                             hint: String(localized: "How long the part rises from silence at its start. The two fades share the part; each can use what the other leaves."),
                             standard: 0,
                             onCommit: { commitIn() })
            EchoelValueField(label: "Fade out",
                             value: Binding(get: { shownOut }, set: { draftOut = $0 }),
                             range: PartFades.outRange(lengths),
                             unit: "beats",
                             decimals: 2,
                             hint: String(localized: "How long the part falls to silence at its end. The two fades share the part; each can use what the other leaves."),
                             standard: 0,
                             onCommit: { commitOut() })
        }
        .onChange(of: lengths) { _, _ in
            draftIn = nil
            draftOut = nil
        }
    }

    private var shownIn: Double {
        draftIn ?? PartFades.beats(fromTicks: lengths.fadeInTicks)
    }

    private var shownOut: Double {
        draftOut ?? PartFades.beats(fromTicks: lengths.fadeOutTicks)
    }

    private func commitIn() {
        guard let value = draftIn else { return }
        draftIn = nil
        timeline.setRegionFades(id: regionID, fadeInTicks: PartFades.ticks(fromBeats: value),
                                fadeOutTicks: lengths.fadeOutTicks)
    }

    private func commitOut() {
        guard let value = draftOut else { return }
        draftOut = nil
        timeline.setRegionFades(id: regionID, fadeInTicks: lengths.fadeInTicks,
                                fadeOutTicks: PartFades.ticks(fromBeats: value))
    }
}

/// GMMW AE-10c — the selected audio part's own pitch, in whole semitones, on top of its track's.
///
/// ⚠️ WRITTEN ON COMMIT, NOT PER DRAG STEP — the `PartGainField` pattern. The drag edits a draft;
/// the release writes once through `TimelineStore.setRegionTranspose` (a no-op when unchanged):
/// one undo step per gesture. The draft is cleared whenever the stored pitch changes (an undo, a
/// redo, another surface), so the field never shows a pitch the part no longer has.
///
/// ⚠️ OFF WHILE THE PIECE PLAYS — the track Pitch field's rule and reason (`WorkstationView
/// .pitchField`): a part's first pitch needs the time-pitch chain, which `AudioLanePlayer.prime`
/// attaches only while nothing sounds, because a mid-song attach pauses the whole engine (review
/// HIGH 2). `player.isPlaying` flips on a start or a stop, never per step, and is read here, in
/// the leaf's own body, not in the bar's — and again in `commitPitch`. ⚠️ Undo/Redo stays live
/// while playing, so a part's pitch CAN still change mid-song; the player then keeps the part
/// on its plain node until the next Play rather than attach a chain (`TimelineAudioSink.play`).
///
/// The number is the PART's own; the engine plays track + part held to the same range
/// (`AudioTranspose.semitones(for:in:)`), so a part can cancel or extend its track's pitch.
/// NEEDS-FOUNDER-VERIFY: on a track at Pitch 0, select one audio part, set Part pitch +7 while stopped and play — that part alone sounds a fifth higher at the same tempo; set the track's Pitch to −7 and play — that part sounds as recorded and the others a fifth lower; one Undo puts the part back.
@MainActor
private struct PartPitchField: View {
    let regionID: UUID
    /// The part's stored pitch — cold, per render.
    let semitones: Int
    @Environment(TimelineStore.self) private var timeline
    /// Cold: `isPlaying` flips on a start or a stop, never per step.
    @Environment(TimelineRegionPlayer.self) private var player
    @State private var draft: Double? = nil

    var body: some View {
        let playing = player.isPlaying
        EchoelValueField(label: "Part pitch",
                         value: Binding(get: { shownPitch }, set: { draft = $0 }),
                         range: AudioTranspose.fieldRange,
                         unit: "semitones",
                         decimals: 0,
                         hint: playing
                             ? String(localized: "Stop the piece to change pitch")
                             : String(localized: "Moves this part up or down on top of its track's pitch, without changing its tempo"),
                         standard: 0,
                         onCommit: { commitPitch() })
            .disabled(playing)
            .onChange(of: semitones) { _, _ in draft = nil }
    }

    private var shownPitch: Double {
        draft ?? Double(semitones)
    }

    private func commitPitch() {
        guard let value = draft else { return }
        draft = nil
        // AE-10 review (LOW): a drag recognised before `.disabled` took hold, or the keypad
        // confirmed after playback began, still ends here — the rule is the field's, not the
        // gesture's, so it is re-asked at the write.
        guard !player.isPlaying else { return }
        timeline.setRegionTranspose(id: regionID, AudioTranspose.semitones(fromField: value))
    }
}

/// GMMW AE-9 — Split at the playhead (founder 2026-10-08: "Die klassische DAW Audio Editing View
/// fehlt mir noch. Orientiere dich an den Bigplayern"). A leaf, so the player's state stays in
/// its own body.
///
/// ⚠️ WHERE THE PLAYHEAD IS (`PartSplit.playheadTick`). Stopped, it is the ruler's line: the bar
/// Play starts from, through the ONE fold the line, the Play hint and `play` ask (AE-7) — so the
/// cut lands exactly where the line is drawn, and only on a bar. Playing, it is the step
/// sounding now, `currentTick`.
///
/// ⚠️ `currentTick` IS READ ONLY INSIDE THIS LEAF'S OWN CLOCK. It is `@ObservationIgnored`
/// (~8 Hz while playing), so a plain body read would subscribe nothing and go stale. While the
/// piece plays the leaf drives itself on a `TimelineView`, paused while stopped — the
/// `ArrangePlayheadView` pattern (10.76.41/50): only this button redraws, no ancestor reads the
/// position. AE-9 review, MED-2: the first version lit the button whenever the part had any step
/// inside it and let the tap decide, so a lit button could do nothing; the lit state is now the
/// tap's own answer, a step at a time.
///
/// The cut goes through the bar's own `split` (the media tempo, one store call = one undo step),
/// after the same `keepsWhoPlays` the first Split asks — asked again at the tap, against the
/// document as it is then.
@MainActor
private struct PartSplitAtPlayhead<Content: View>: View {
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(TimelineStore.self) private var timeline

    let part: TrackParts.Part
    let regionID: UUID
    /// The bar's own Split handler (media tempo, one undo step) — required (#431).
    let split: (UUID, Int) -> Void
    /// The bar's own button, so this one looks and speaks like its neighbours (#416).
    let content: (_ enabled: Bool, _ label: String, _ action: @escaping () -> Void) -> Content

    /// How often the lit state follows the moving playhead: a transport step is 125 ms at 120 BPM.
    /// Computed, not stored: a generic type cannot hold a static stored property.
    private static var playingRefresh: TimeInterval { 1.0 / 8.0 }

    var body: some View {
        let document = timeline.document
        let playing = player.isPlaying
        let cueTick = player.cueTick
        TimelineView(.animation(minimumInterval: Self.playingRefresh, paused: !playing)) { _ in
            let head = PartSplit.playheadTick(playing: playing, currentTick: player.currentTick,
                                              cueTick: cueTick, in: document)
            let cut = PartSplit.playheadCut(for: part, atTick: head)
            let enabled = cut.map { PartSplit.keepsWhoPlays(regionID: regionID, atTick: $0, in: document) } ?? false
            content(enabled, label(playing: playing, cut: cut, enabled: enabled), { splitAtPlayhead() })
        }
    }

    private func label(playing: Bool, cut: Int?, enabled: Bool) -> String {
        // Stopped the line sits on a bar, so a part with no bar line inside it can never be cut
        // from the ruler — say what does work instead (review MED-1).
        let unit = playing ? TimelineTime.ticksPerTransportStep : TimelineTime.ticksPerBar
        guard PartSplit.hasLineInside(part, every: unit) else {
            return playing ? String(localized: "This part is too short to split")
                           : String(localized: "No bar line falls inside this part. Use Split, or cut while the piece plays")
        }
        guard let cut else {
            return String(localized: "The playhead is not inside this part. Tap the ruler above the tracks to move it")
        }
        guard enabled else { return String(localized: "Splitting here would change which overlapping part plays") }
        return String(localized: "Split the selected part at the playhead, ") + SessionGrid.label(forTick: cut)
    }

    private func splitAtPlayhead() {
        let document = timeline.document
        // The position, read again HERE: the lit state may be a step behind the transport.
        let head = PartSplit.playheadTick(playing: player.isPlaying, currentTick: player.currentTick,
                                          cueTick: player.cueTick, in: document)
        guard let cut = PartSplit.playheadCut(for: part, atTick: head),
              PartSplit.keepsWhoPlays(regionID: regionID, atTick: cut, in: document) else {
            log.log(.info, category: .audio, "Split at playhead refused: the playhead is outside the part, or the cut would change which overlapping part plays")
            return
        }
        split(regionID, cut)
    }
}
