//
//  DMMWProject.swift
//  Echoelmusic — Core (DMMW M2: one envelope over the five song roots)
//
//  WHY THIS EXISTS, in one measurement. The repository persists TWELVE roots
//  (`scratchpads/PLAN_DOCUMENT_ROOTS_2026-09-21.md` has the table and the command). Five of
//  them describe the PIECE and overlap; seven describe the APP — the user's patch library,
//  their FX and mood presets, the modulation matrix, the signal routes, the track FX, the bio
//  log. ⛔ **Only the five are in here, and that is the load-bearing decision of this file.**
//  An envelope that swallowed the library would turn "open a project" into "replace the app's
//  state": the user would lose their own presets because they loaded somebody else's piece.
//
//  ⚠️ IMPORTER FIRST, WRITER SECOND — nothing writes this type yet, and that is the whole
//  risk mitigation. `DMMWProjectImport` reads the five existing roots into this shape; the old
//  files keep being the truth on disk. If the import is wrong, nothing is lost, because the
//  sources are untouched. The writer is its own slice and its own decision.
//
//  ⭐ WRITING THE CODE CORRECTED THE DESIGN, and the correction is recorded rather than
//  quietly applied. The design document said `Project.notes` would be "lifted into a region"
//  at import. **It cannot be, in one step:** `TimelineRegion` carries a `clipID` and the NOTES
//  live in a `Clip` (`Clip.melody`), and clips are a DIFFERENT persisted root. A region whose
//  clip is not in the envelope is a dangling reference — which is exactly why `clipSlots` is a
//  compartment here and not a later slice. Lifting the notes additionally means MINTING a clip,
//  i.e. restructuring, and an importer's job is lossless capture. So the notes ride in
//  `legacy`, whole, and the lift is the WRITER's decision. The design doc is corrected in the
//  same commit (#456 — prose moves in every home, not only the one you are looking at).
//
//  ⭐ AND THE AUTOMATION FINDING GOT SHARPER, in the direction that matters. The design said
//  automation has TWO homes. It has THREE: `AutomationState.lanes` (the player's file),
//  `TimelineDocument.automation` (the timeline's file) and `Clip.automation` (inside each
//  clip). ⚠️ The third is NOT part of the duplication — it is a different SCOPE, clip-relative
//  rather than song-absolute, the way any DAW separates clip automation from track automation.
//  Naming it matters precisely so that whoever unifies "automation" does not fold three things
//  into one and silently lose that distinction.
//
//  Foundation-only, like everything it carries: `TimelineDocument`, `Clip`, `Arrangement`,
//  `AutomationLane`, `SynthPatch` and `Note` each import Foundation and nothing else, so the
//  envelope inherits the property that would let this layer be lifted into its own target.
//

import Foundation

/// One project, one envelope. A value type end to end: it can be diffed, copied, sent and
/// compared without touching a store.
public struct DMMWProject: Codable, Sendable, Equatable {

    /// ⭐ THE VERSION LIVES HERE, ONCE. Measured across the twelve roots, exactly TWO carry a
    /// `schemaVersion` of their own (`Project`, `TimelineDocument`) — an envelope whose
    /// compartments each version themselves is an envelope you can only open once.
    public static let currentEnvelopeVersion = 1

    public var envelopeVersion: Int
    public var meta: Meta
    /// Tempo, meter, the PPQ grid and the render rate — the #1416 conversion authority.
    public var timebase: Timebase
    public var musical: Musical
    public var content: Content
    public var sound: Sound
    public var legacy: Legacy

    public init(envelopeVersion: Int = DMMWProject.currentEnvelopeVersion,
                meta: Meta, timebase: Timebase, musical: Musical,
                content: Content, sound: Sound, legacy: Legacy) {
        self.envelopeVersion = Swift.max(1, envelopeVersion)
        self.meta = meta
        self.timebase = timebase
        self.musical = musical
        self.content = content
        self.sound = sound
        self.legacy = legacy
    }

    // MARK: Compartments

    public struct Meta: Codable, Sendable, Equatable {
        public var id: UUID
        public var name: String
        public var artist: String
        public var savedAt: Date

        public init(id: UUID, name: String, artist: String, savedAt: Date) {
            self.id = id
            self.name = name
            self.artist = artist
            self.savedAt = savedAt
        }
    }

    /// What the piece IS musically, as raw values — the same shape `Project` already persists,
    /// so a decode cannot fail on an enum case a later build removed.
    public struct Musical: Codable, Sendable, Equatable {
        public var keyRoot: Int
        public var scaleRaw: String
        public var styleRaw: String
        public var modeRaw: String
        public var a4Hz: Double
        public var toneSystemID: String?
        public var moodFields: [String: Float]?

        public init(keyRoot: Int, scaleRaw: String, styleRaw: String, modeRaw: String,
                    a4Hz: Double, toneSystemID: String?, moodFields: [String: Float]?) {
            self.keyRoot = keyRoot
            self.scaleRaw = scaleRaw
            self.styleRaw = styleRaw
            self.modeRaw = modeRaw
            self.a4Hz = a4Hz
            self.toneSystemID = toneSystemID
            self.moodFields = moodFields
        }
    }

    /// The four content roots that used to be four files.
    ///
    /// ⚠️ `clipSlots` is POSITIONAL and keeps its holes. `ClipStore` persists `[Clip?]` — a
    /// fixed grid where the index IS the identity a section refers to. Compacting it here
    /// would silently renumber every slot a saved arrangement points at.
    public struct Content: Codable, Sendable, Equatable {
        public var timeline: TimelineDocument
        public var clipSlots: [Clip?]
        public var songForm: Arrangement
        /// The PLAYER's lanes, kept beside the timeline's rather than merged into them.
        /// The merge rule is the importer's and is written there, with its reason.
        public var playerAutomation: [AutomationLane]

        public init(timeline: TimelineDocument, clipSlots: [Clip?],
                    songForm: Arrangement, playerAutomation: [AutomationLane]) {
            self.timeline = timeline
            self.clipSlots = clipSlots
            self.songForm = songForm
            self.playerAutomation = playerAutomation
        }
    }

    public struct Sound: Codable, Sendable, Equatable {
        public var patch: SynthPatch
        public var fxCharacterRaw: String

        public init(patch: SynthPatch, fxCharacterRaw: String) {
            self.patch = patch
            self.fxCharacterRaw = fxCharacterRaw
        }
    }

    /// Everything the old `Project` carried that the new shape does not yet have a home for.
    ///
    /// ⛔ THIS IS NOT A DUMPING GROUND AND IT IS NOT DEAD WEIGHT — each field is here for a
    /// stated reason, and deleting any of them loses a real user's data:
    /// · `notes` / `rawTake*` — the take. It belongs in a clip; minting one is restructuring
    ///   and therefore the writer's job, not the importer's (see the file header).
    /// · `drumSteps` / `drumAccents` — a payload that cannot SOUND since #166/#167 removed the
    ///   drum voice, but `Project` still encodes and decodes it and `BioComposer` still fills
    ///   it. A project written by an older build carries it (#527), so it is read and not
    ///   thrown away; it is simply never written forward.
    /// · `loopBars` — song structure that the timeline expresses as region lengths. Until a
    ///   writer maps it, losing it would change how a reopened piece loops.
    public struct Legacy: Codable, Sendable, Equatable {
        public var notes: [Note]
        public var rawTakeBars: [[Note]]
        public var rawTakeStyleRaw: String?
        public var drumSteps: [[Bool]]
        public var drumAccents: [[Bool]]
        public var loopBars: Int

        public init(notes: [Note], rawTakeBars: [[Note]], rawTakeStyleRaw: String?,
                    drumSteps: [[Bool]], drumAccents: [[Bool]], loopBars: Int) {
            self.notes = notes
            self.rawTakeBars = rawTakeBars
            self.rawTakeStyleRaw = rawTakeStyleRaw
            self.drumSteps = drumSteps
            self.drumAccents = drumAccents
            self.loopBars = loopBars
        }
    }

    // MARK: Decode

    /// Tolerant on the way in, like every store in this repository: an envelope written by a
    /// build that had one compartment fewer must still open. The version is the ONLY field
    /// that is allowed to be absent and still meaningful — it then reads as 1.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            envelopeVersion: try c.decodeIfPresent(Int.self, forKey: .envelopeVersion) ?? 1,
            meta: try c.decode(Meta.self, forKey: .meta),
            timebase: try c.decode(Timebase.self, forKey: .timebase),
            musical: try c.decode(Musical.self, forKey: .musical),
            content: try c.decode(Content.self, forKey: .content),
            sound: try c.decode(Sound.self, forKey: .sound),
            legacy: try c.decode(Legacy.self, forKey: .legacy))
    }
}
