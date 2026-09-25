//
//  DMMWProjectImport.swift
//  Echoelmusic — Core (DMMW M2: the importer, and ONLY the importer)
//
//  ⛔ THERE IS NO WRITER IN THIS FILE, AND ITS ABSENCE IS THE DESIGN. The five song roots on
//  disk stay the truth; this reads them into one `DMMWProject` value. Its one production caller is
//  `SessionSaveOpen.capturing` (WA4-S3, Save and the recovery slot).
//  If a rule below turns out to be wrong, the cost is a corrected function — not a user's
//  piece, because the sources were never touched. The writer is its own slice, with its own
//  gate and its own founder-visible decision about the on-disk format.
//
//  ⚠️ PURE AND TOTAL. It takes VALUES, never the stores — so the blocking bundle can drive it
//  end to end, and so a future caller decides where the values come from. Every parameter is
//  required (#431: a defaulted argument no call site writes appears in no diff, and here there
//  are no call sites at all to notice).
//
//  THE THREE RULES THE DESIGN DECIDED, each encoded below with its reason at the line.
//

import Foundation

public enum DMMWProjectImport {

    /// Read the five persisted song roots into one envelope. Lossless by construction:
    /// everything that has no new home rides in `legacy`, and nothing is dropped.
    ///
    /// - Parameters:
    ///   - project: `ProjectStore`'s `projects.json` element.
    ///   - timeline: `TimelineStore`'s `timeline` document.
    ///   - clipSlots: `ClipStore`'s `clips` grid, POSITIONAL — holes included.
    ///   - songForm: `ArrangementStore`'s `song`.
    ///   - playerAutomation: `AutomationPlayer`'s `automation` lanes.
    ///   - ppq: the tick grid the ticks in `timeline` are counted in. NOT defaulted — the
    ///     app's grid is `Note.ticksPerQuarter`, and a second hard-coded grid is the defect
    ///     `Timebase` exists to end.
    ///   - sampleRate: the project's render rate, for `SampleTime` conversions.
    public static func envelope(project: Project,
                                timeline: TimelineDocument,
                                clipSlots: [Clip?],
                                songForm: Arrangement,
                                playerAutomation: [AutomationLane],
                                ppq: Int,
                                sampleRate: Double) -> DMMWProject {

        // RULE 1 — THE SCALAR BPM BECOMES A TEMPO MAP, it does not sit beside one.
        // A project's `bpm` is one number for the whole piece; `TempoMap.constant` says exactly
        // that and nothing more. Keeping both would be one decision in two homes (#416) inside
        // the type built to end that, and the conversion is total: it loses nothing and it
        // leaves no second field for a later edit to disagree with.
        let timebase = Timebase(ppq: ppq,
                                sampleRate: sampleRate,
                                tempoMap: .constant(project.bpm),
                                meterMap: .fourFour)

        // RULE 2 — THE TIMELINE'S AUTOMATION WINS, AND THE PLAYER'S IS STILL NOT THROWN AWAY.
        // "Timeline wins" is the reading rule; an importer that acted on it by DELETING the
        // player's lanes would turn a visible duplication into a silent loss — the #527 shape,
        // where a root with no surface is still the only thing holding somebody's data. So the
        // player's lanes are carried beside, minus the parameters the timeline already covers.
        let covered = Set(timeline.automation.map(\.parameter))
        let surviving = playerAutomation.filter { !covered.contains($0.parameter) }

        let content = DMMWProject.Content(timeline: timeline,
                                          clipSlots: clipSlots,
                                          songForm: songForm,
                                          playerAutomation: surviving)

        // RULE 3 — THE TAKE RIDES IN `legacy`, WHOLE, AND IS NOT LIFTED INTO A REGION.
        // The design said "lift it"; the code says it cannot be one step, and the code is
        // right: a `TimelineRegion` references a `clipID`, the notes live in `Clip.melody`,
        // so lifting means MINTING a clip. That is restructuring, and an importer that
        // restructures cannot be checked against "did it lose anything" — only against
        // "did it guess the same way I would have". The lift belongs to the writer.
        let legacy = DMMWProject.Legacy(notes: project.notes,
                                        rawTakeBars: project.rawTake?.bars ?? [],
                                        rawTakeStyleRaw: project.rawTake?.styleRaw,
                                        drumSteps: project.drumSteps,
                                        drumAccents: project.drumAccents,
                                        loopBars: project.loopBars)

        return DMMWProject(
            meta: .init(id: project.id, name: project.name,
                        artist: project.artist, savedAt: project.savedAt),
            timebase: timebase,
            musical: .init(keyRoot: project.keyRoot,
                           scaleRaw: project.scaleRaw,
                           styleRaw: project.styleRaw,
                           modeRaw: project.modeRaw,
                           a4Hz: project.a4Hz,
                           toneSystemID: project.toneSystemID,
                           moodFields: project.moodFields),
            content: content,
            sound: .init(patch: project.patch, fxCharacterRaw: project.fxCharacterRaw),
            legacy: legacy)
    }

    /// The tempo the envelope reports at the song start, in BPM.
    ///
    /// ⚠️ It exists so a reader never has to know whether a project came in as a scalar or as
    /// a curve — which is the ONE thing rule 1 would otherwise leak. Asking the map at tick 0
    /// is correct for both, and it is the shape a writer has to preserve.
    public static func openingTempo(of envelope: DMMWProject) -> Double {
        envelope.timebase.tempoMap.entries.first?.bpm ?? Transport.defaultTempo
    }
}
