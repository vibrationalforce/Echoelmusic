// TheValueFieldOffersItsDefaultTests.swift
// Echoel — interface audit 2026-09-30, rule 6: "Alles rückgängig machbar … Jeder Wert hat
// „Auf Standard"" (WCAG 3.3.4 / 3.3.7).
//
// WHAT THIS GUARDS. `EchoelValueField` is the app's ONE numeric control (84 call sites), and
// until this slice none of them could say "back to the value a fresh install has" — a player
// who had dragged the concert pitch to 447 Hz had to know that 440 is the standard and type
// it. Rule 6 gives every value that KNOWS its default two doors, both through the field's own
// `apply(_:)` so `onChange` and `onCommit` fire exactly as for a typed number:
//   · the keypad's "Default 440" key (rule 3: symbol plus word). It TYPES the default into the
//     buffer and OK confirms — the same tap every digit needs, so a reset is never one
//     accidental touch, and the header shows what OK will keep. Dimmed while the pending value
//     already IS the default (#164/#227: a key may not offer a change it cannot make).
//   · a VoiceOver custom action "Default 440" on the row itself.
// `standard` is OPTIONAL and `nil` shows nothing: a row whose default is not a fact (a bio
// mapping's live value, a derived binding) offers no key rather than a wrong one.
//
// FIRST CONSUMERS, and why these: the concert pitch (`SessionContext.defaultA4Hz`, 440 —
// the founder's own device note "A4 ≠ 440 banner" is about exactly this row) and the two
// mixer levels (`MixerStore.defaultLevel`, unity). Each names a constant the engine already
// owns — no second definition of a default is born here (#416). The other rows join one
// family per commit, each with its owner's constant; a literal typed at a call site would be
// the #416 defect the parameter exists to avoid.
//
// THIRD FAMILY (claim 3, 2026-09-30): the three felt-sub rows name `SubBassVoice.defaultSubGain` and
// `SubCharacter.defaultPresence` / `defaultHeat` — the constants the voice itself initialises from.
// FOURTH FAMILY (claim 3, same day): the OSC control input's "Port" row names `OSCReceiver.defaultPort`.
// FIFTH FAMILY (claim 3, same day): the light "Master" row names `ArtNetSender.defaultGrandMaster` —
// a constant BORN for it, because the launch value was a literal `1` in two senders and in the
// non-finite fallback; both senders and the fallback now read the one owner (the row binds both).
// SIXTH FAMILY (claim 3, same day): the track inspector's "Level" and "Pan" rows name
// `TimelineLane.defaultLevel` / `defaultPan` — born for them: the lane's init defaults, its two
// decode fallbacks and the four "lane not found" fallbacks (inspector ×3, `AudioLanePlayer`,
// `MultiRollFanout`) were literals `1` / `0`; every one of them reads the owner now.
// SEVENTH FAMILY (claim 3, same day): the "Master volume" row (`MasterVolumeField`) names
// `AudioEngine.defaultMasterVolume`, the constant the engine's fader now initialises from.
// EIGHTH FAMILY (claim 3, same day): the click — "Accent every" names `MetronomeVoice.defaultBeatsPerBar`,
// the two level rows (mixer "Level", tempo-tools "Click level") name `MetronomeVoice.defaultLevel`;
// the stored properties AND their audio-thread mirrors initialise from the same two constants.
// NINTH FAMILY (claim 3, same day): the light "Fixtures" / "Spacing" rows name
// `ArtNetSender.defaultFixtureCount` / `defaultFixtureSpacing`; both senders' stored properties
// and `decodedFixtureCount`'s fallback read them (they were literals `1` / `0` in five places).
// TENTH FAMILY (claim 3, same day): the Workstation's "Pitch" row names
// `TimelineLane.defaultTransposeSemitones`; the lane's init default, its decode fallback and
// `AudioTranspose.semitones(laneID:in:)`'s "no such lane" answer read it.
// ELEVENTH FAMILY (claim 3, same day): the four network targets. Each sender owns its
// `defaultPort` (the two light senders also a `defaultUniverse`); the inits read them, and the
// shared `outputRow` carries them as `standardPort` / `standardUniverse` to its two rows. The
// ADM-OSC number is ALSO pinned against the hub page by `TheIntegrationHubIsPublishedTests`
// claim 4b, which now reads the owner rather than the init's literal.
//
// SECOND FAMILY (claim 5, the same day): every value field in `EchoelStudioView` whose binding
// is a KEYSTORE-backed `@AppStorage` (`StudioDefaultKeys.x.key` … `= StudioDefaultKeys.x.value`)
// passes `standard: StudioDefaultKeys.x.value` — the SAME `x`. The keystore is the one owner of
// those defaults by construction (H15-KEYSTORE), so the row's "Default" and the fresh-install
// value can never disagree. Thirty rows on 2026-09-30 (touch, field auto-play, arp rhythm,
// visual, pad rhythm, bar variation). The claim is a RATCHET: a keystore-bound field added
// later without its `standard:` turns it red, and a `standard:` naming a DIFFERENT key than the
// binding's is the split the keystore exists to prevent.
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN plus two constants. Nothing here taps the key on a device; that
// the dimmed key reads as "you are at the default" and not as "broken" is a founder look.
// `ValueFieldNotifiesEveryPathTests` owns the swipe/drag/keypad closure pairs and is
// unchanged: this file pins only the NEW path and its two premises.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against this tree and the parent
// 62ceec462 (no local toolchain): claims 1–3 RED on the parent for their named reasons (the
// parameter, the key, the action and the three call-site arguments are born here; the two
// constants exist on both trees and are GREEN there — they are the premises, not the slice);
// claim 4 GREEN on both — the counterweight (#343): the pad still commits in exactly ONE
// place, so a "Default" key that committed on its own would turn it red.
// `Tests/CISmoke` is the blocking bundle. SKIPS rather than passes if the tree is absent.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheValueFieldOffersItsDefaultTests: XCTestCase {

    private static let field = "Sources/Echoelmusic/Studio/EchoelValueField.swift"
    private static let pad = "Sources/Echoelmusic/Studio/EchoelNumberPad.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let patchbay = "Sources/Echoelmusic/Studio/PatchbayView.swift"

    // MARK: - claim 1 — the field carries an optional default and hands it to both doors

    func testTheFieldCarriesAnOptionalDefaultAndOffersItAsAnAction() throws {
        let code = try source(Self.field)
        let hint = code.range(of: "var hint: String = \"\"")
        let standard = code.range(of: "var standard: V? = nil")
        let onChange = code.range(of: "var onChange: () -> Void = {}")
        XCTAssertNotNil(standard, "`EchoelValueField` lost `var standard: V? = nil` — rule 6's default per value")
        if let hint, let standard, let onChange {
            XCTAssertTrue(hint.lowerBound < standard.lowerBound && standard.lowerBound < onChange.lowerBound, """
                `standard` must be declared AFTER `hint` and BEFORE the closures: the memberwise \
                initialiser follows declaration order, and every call site writes \
                `…, decimals: 2, standard: 440, onCommit: …`. Moving it is a compile error at \
                84 sites (#930b learned this with `hint`).
                """)
        }
        XCTAssertTrue(code.contains("standard: standard.map { Double($0) }"), """
            The field no longer hands its default to the keypad. The pad's "Default" key is the \
            sighted door of rule 6; without this argument the key never appears and the row's \
            VoiceOver action is the only way back.
            """)
        let actions = slice(code, from: ".accessibilityActions {", to: "\n        }")
        XCTAssertTrue(actions.contains("if let standard {"), "the VoiceOver action is offered only when a default exists — a nil default shows nothing")
        XCTAssertTrue(actions.contains("if apply(Double(standard)) { onChange(); onCommit() }"), """
            The VoiceOver "Default" action no longer goes through `apply` with BOTH closures. \
            Every path of this field fires `onChange` (live-apply) and `onCommit` (persist) only \
            when the value moved (#232/#375); a reset that skipped either would change the \
            number and not the instrument, or the instrument and not the file.
            """)
    }

    // MARK: - claim 2 — the keypad's key types the default; OK still confirms

    func testTheKeypadKeyTypesTheDefaultAndOKConfirms() throws {
        let code = try source(Self.pad)
        let standard = code.range(of: "var standard: Double? = nil")
        let commitDecl = code.range(of: "let onCommit: (Double) -> Void")
        XCTAssertNotNil(standard, "`EchoelNumberPad` lost `var standard: Double? = nil`")
        if let standard, let commitDecl {
            XCTAssertTrue(standard.lowerBound < commitDecl.lowerBound,
                          "`standard` is declared before `onCommit` so the field's trailing closure still binds to `onCommit`")
        }
        let header = slice(code, from: "private var header: some View {", to: "\n    }")
        XCTAssertTrue(header.contains("if let standard {") && header.contains("defaultKey(standard)"), """
            The keypad header no longer mounts `defaultKey` behind `if let standard` — the key \
            must exist exactly when the row has a default, and nowhere else on the pad (the \
            5×3 grid is full and the sheet's 440 pt detent has no room for a sixth row).
            """)
        let key = slice(code, from: "private func defaultKey(_ standard: Double) -> some View {", to: "\n    }")
        XCTAssertTrue(key.contains("buffer = String(format:"), """
            The "Default" key no longer TYPES the default into the buffer. It must write the \
            same ASCII buffer the digit keys write and let OK confirm — a reset that committed \
            by itself would be the one key on this pad that changes a value without OK.
            """)
        XCTAssertFalse(key.contains("onCommit("), "the \"Default\" key must not commit — OK is the pad's one committer")
        XCTAssertFalse(key.contains("dismiss()"), "the \"Default\" key must not close the pad — the header shows what OK will keep")
        XCTAssertTrue(key.contains(".disabled(atDefault)"), """
            The "Default" key is no longer dimmed while the pending value already is the \
            default. A key that offers a change it cannot make is the lying-control class \
            (#164/#227) — the same rule that dims the sign pair on a non-negative row.
            """)
        // E4-28: the word is a catalog key beside the value; the claim (symbol PLUS the word) is unchanged.
        XCTAssertTrue(key.contains("Label(String(localized: \"Default \") + text, systemImage:"), "the key wears symbol PLUS the word \"Default\" (rule 3) — the glossary's word for this thing")
    }

    // MARK: - claim 3 — the first consumers name their owner's constant, and the constant is inside the row's range

    func testTheFirstConsumersNameTheirOwnersConstant() throws {
        XCTAssertEqual(SessionContext.defaultA4Hz, 440, "the concert-pitch default is the ISO 16 standard")
        XCTAssertTrue((380.0...500.0).contains(SessionContext.defaultA4Hz), "the default must sit inside the row's own range, or the key would type a value the row clamps")
        XCTAssertEqual(MixerStore.defaultLevel, 1, "the mixer default is unity")
        XCTAssertTrue((Float(0)...Float(1)).contains(MixerStore.defaultLevel), "unity must sit inside the level row's 0…1 range")

        let workspace = try source(Self.workspace)
        let a4 = slice(workspace, from: "EchoelValueField(label: \"\", value: $session.a4Hz", to: "\n                        .accessibilityLabel(\"Concert pitch A4\")")
        XCTAssertTrue(a4.contains("standard: SessionContext.defaultA4Hz"), """
            The concert-pitch row no longer passes `standard: SessionContext.defaultA4Hz`. This is \
            the row the founder's device note ("A4 ≠ 440") is about; a player who dragged it to \
            447 Hz needs the way back to be one key, not a number they have to know.
            """)
        let studio = try source(Self.studio)
        XCTAssertEqual(occurrences(of: "standard: MixerStore.defaultLevel", in: studio), 2, """
            The two mixer level rows (Bass Level, Melodic Pad) must pass `MixerStore.defaultLevel` \
            as their default — the ENGINE's constant, never a literal `1` typed at the call site \
            (#416). A third mixer row joining is fine: raise this count in the same commit.
            """)

        // THIRD FAMILY — the felt sub (2026-09-30): the three rows under "Sub / Bass (felt)" name the
        // voice's own constants. `SubBassVoice.defaultSubGain` is what the voice initialises `subGain`
        // to; presence and heat initialise from `SubCharacter` — so the key returns EXACTLY the
        // fresh-install sound, never a rounded neighbour of it.
        for (constant, needle) in [(SubBassVoice.defaultSubGain, "standard: SubBassVoice.defaultSubGain"),
                                   (SubCharacter.defaultPresence, "standard: SubCharacter.defaultPresence"),
                                   (SubCharacter.defaultHeat, "standard: SubCharacter.defaultHeat")] {
            XCTAssertTrue((Float(0)...Float(1)).contains(constant), "\(needle): the default must sit inside the row's 0…1 range")
            XCTAssertEqual(occurrences(of: needle, in: studio), 1, """
                The sub row that owns `\(needle)` no longer passes it (or a second row copied it — one \
                row per constant). The voice initialises from that constant; the key must return to it.
                """)
        }

        // FOURTH FAMILY — the OSC control input's port (2026-09-30): `OSCReceiver.defaultPort` is what
        // the receiver initialises with and what the hub page and the FAQ name (8001). It is the ONE
        // port row with an owner constant; the output rows' ports differ per output and stay without.
        XCTAssertTrue((1...65_535).contains(Int(OSCReceiver.defaultPort)), "the receiver's default port must sit inside the row's range")
        let patchbay = try source(Self.patchbay)
        XCTAssertEqual(occurrences(of: "standard: Float(OSCReceiver.defaultPort)", in: patchbay), 1, """
            The OSC-in "Port" row no longer passes `OSCReceiver.defaultPort` (or a second row copied it). \
            8001 is the receiver's own constant, the one the docs name — a call-site literal would be #416.
            """)

        // FIFTH FAMILY — the light Grand Master (2026-09-30). The row drives BOTH senders through one
        // binding, so its default must be the one value both start at: `ArtNetSender.defaultGrandMaster`,
        // read by `ArtNetSender.grandMaster`, `SACNSender.grandMaster` and the non-finite fallback of
        // `masteredDimmer`. A second literal `1` in either sender would be a second owner (#416).
        XCTAssertEqual(ArtNetSender.defaultGrandMaster, 1, "a fresh launch starts at FULL — the operator's predictable state")
        XCTAssertEqual(occurrences(of: "standard: ArtNetSender.defaultGrandMaster", in: patchbay), 1, """
            The light "Master" row no longer passes `ArtNetSender.defaultGrandMaster` (or a second row             copied it). The row moves two senders at once; its default must be the one both start at.
            """)
        for rel in ["Sources/Echoelmusic/Sync/ArtNetSender.swift", "Sources/Echoelmusic/Sync/SACNSender.swift"] {
            let sender = try source(rel)
            XCTAssertEqual(occurrences(of: "var grandMaster: Float = ArtNetSender.defaultGrandMaster", in: sender), 1, """
                \(rel) initialises `grandMaster` from something other than `ArtNetSender.defaultGrandMaster`. \
                Two senders, one fader, one launch value — a literal here is a second owner of the default.
                """)
            XCTAssertEqual(occurrences(of: "var grandMaster: Float = 1", in: sender), 0, "\(rel): the literal launch value is gone; the owner is the constant")
        }

        // SIXTH FAMILY — the track's fader and pan (2026-09-30). `TimelineLane` owns both defaults;
        // the inspector rows pass them, and no fallback in the tree types `1` or `0` for them again.
        XCTAssertEqual(TimelineLane.defaultLevel, 1, "a fresh track sits at unity")
        XCTAssertEqual(TimelineLane.defaultPan, 0, "a fresh track sits at centre")
        // The rows' OWN ranges, read from `TrackMix` (a plain enum, not actor-isolated — measured,
        // after a first draft claimed the opposite and spelled the ranges as literals).
        XCTAssertTrue(TrackMix.levelRange.contains(Double(TimelineLane.defaultLevel)), "unity must sit inside the track level row's range")
        XCTAssertTrue(TrackMix.panRange.contains(Double(TimelineLane.defaultPan)), "centre must sit inside the pan row's range")
        let inspector = try source("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        XCTAssertEqual(occurrences(of: "standard: Double(TimelineLane.defaultLevel)", in: inspector), 1, "the track \"Level\" row passes the lane's default once")
        XCTAssertEqual(occurrences(of: "standard: Double(TimelineLane.defaultPan)", in: inspector), 1, "the track \"Pan\" row passes the lane's default once")
        let lane = try source("Sources/Echoelmusic/Sequencer/Timeline.swift")
        XCTAssertEqual(occurrences(of: "level: Float = TimelineLane.defaultLevel", in: lane), 1, "`TimelineLane.init` takes its level default from the owner")
        XCTAssertEqual(occurrences(of: "pan: Float = TimelineLane.defaultPan", in: lane), 1, "`TimelineLane.init` takes its pan default from the owner")
        XCTAssertEqual(occurrences(of: "forKey: .level) ?? TimelineLane.defaultLevel", in: lane), 1, "the pre-K2a decode fallback reads the owner")
        XCTAssertEqual(occurrences(of: "forKey: .pan) ?? TimelineLane.defaultPan", in: lane), 1, "the pre-B2 decode fallback reads the owner")
        for rel in ["Sources/Echoelmusic/Studio/TrackInspectorView.swift",
                    "Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift",
                    "Sources/Echoelmusic/Sequencer/MultiRollFanout.swift"] {
            let code = try source(rel)
            XCTAssertEqual(occurrences(of: "?.level ?? 1", in: code) + occurrences(of: "?.pan ?? 0", in: code), 0, """
                \(rel) types a literal fallback for a track's level or pan again. The owner is \
                `TimelineLane.defaultLevel` / `defaultPan` — a literal here is a second owner (#416).
                """)
        }

        // SEVENTH FAMILY — the master fader (2026-09-30). `AudioEngine.defaultMasterVolume` is what the
        // engine's `masterVolume` initialises from; the row in `MasterLoudnessGrid` offers it. Pinned
        // to the row's range, not to a value: the launch level is a tuning choice, not a fact.
        XCTAssertTrue((Float(0)...Float(1)).contains(AudioEngine.defaultMasterVolume), "the launch master level must sit inside the row's 0…1 range")
        let engine = try source("Sources/Echoelmusic/Audio/AudioEngine.swift")
        XCTAssertEqual(occurrences(of: "var masterVolume: Float = AudioEngine.defaultMasterVolume", in: engine), 1, "`AudioEngine.masterVolume` initialises from the owner constant, never from a literal")
        let grid = try source("Sources/Echoelmusic/Studio/MasterLoudnessGrid.swift")
        XCTAssertEqual(occurrences(of: "standard: Double(AudioEngine.defaultMasterVolume)", in: grid), 1, "the \"Master volume\" row passes the engine's default once")

        // EIGHTH FAMILY — the click (2026-09-30). Two constants on `MetronomeVoice`; the stored
        // properties and their `nonisolated(unsafe)` audio mirrors initialise from them (a mirror
        // that started from its own literal would be a second owner the render thread reads).
        XCTAssertTrue((1...12).contains(MetronomeVoice.defaultBeatsPerBar), "the accent interval default must sit inside the row's 1…12 range")
        XCTAssertTrue((Float(0)...Float(1)).contains(MetronomeVoice.defaultLevel), "the click level default must sit inside the row's 0…1 range")
        let click = try source("Sources/Echoelmusic/Audio/MetronomeVoice.swift")
        for needle in ["var beatsPerBar: Int = MetronomeVoice.defaultBeatsPerBar",
                       "var level: Float = MetronomeVoice.defaultLevel",
                       "private var audioBeatsPerBar = MetronomeVoice.defaultBeatsPerBar",
                       "private var audioLevel: Float = MetronomeVoice.defaultLevel"] {
            XCTAssertEqual(occurrences(of: needle, in: click), 1, "`\(needle)` — the property (or its audio mirror) no longer initialises from the owner")
        }
        XCTAssertEqual(occurrences(of: "standard: Double(MetronomeVoice.defaultBeatsPerBar)", in: studio), 1, "the \"Accent every\" row passes the click's default once")
        XCTAssertEqual(occurrences(of: "standard: Double(MetronomeVoice.defaultLevel)", in: studio), 2, """
            The two click level rows (mixer "Level" beside the click switch, tempo-tools "Click level") \
            both pass `MetronomeVoice.defaultLevel` — same property, same owner. A third row joining \
            is fine: raise this count in the same commit.
            """)

        // NINTH FAMILY — the rig's shape (2026-09-30). One fixture, no gap; both senders and the
        // decode fallback read `ArtNetSender`'s two constants, the two rows offer them.
        XCTAssertEqual(ArtNetSender.defaultFixtureCount, 1, "a fresh install describes ONE fixture")
        XCTAssertEqual(ArtNetSender.defaultFixtureSpacing, 0, "and no gap between fixtures")
        XCTAssertEqual(occurrences(of: "standard: Double(ArtNetSender.defaultFixtureCount)", in: patchbay), 1, "the \"Fixtures\" row passes the owner's default once")
        XCTAssertEqual(occurrences(of: "standard: Double(ArtNetSender.defaultFixtureSpacing)", in: patchbay), 1, "the \"Spacing\" row passes the owner's default once")
        for rel in ["Sources/Echoelmusic/Sync/ArtNetSender.swift", "Sources/Echoelmusic/Sync/SACNSender.swift"] {
            let sender = try source(rel)
            XCTAssertEqual(occurrences(of: "var fixtureCount: Int = ArtNetSender.defaultFixtureCount", in: sender), 1, "\(rel): `fixtureCount` initialises from the owner")
            XCTAssertEqual(occurrences(of: "var fixtureSpacing: Int = ArtNetSender.defaultFixtureSpacing", in: sender), 1, "\(rel): `fixtureSpacing` initialises from the owner")
        }
        let artNet = try source("Sources/Echoelmusic/Sync/ArtNetSender.swift")
        XCTAssertEqual(occurrences(of: "Swift.min(stored, DMXFixtureFan.maxFixtures) : defaultFixtureCount", in: artNet), 1, "`decodedFixtureCount`'s fallback reads the owner, not a literal `1`")

        // TENTH FAMILY — the track's pitch shift (2026-09-30). None, by default; the lane owns it.
        XCTAssertEqual(TimelineLane.defaultTransposeSemitones, 0, "a fresh track is not transposed")
        XCTAssertTrue(AudioTranspose.fieldRange.contains(Double(TimelineLane.defaultTransposeSemitones)), "the default sits inside the Pitch row's range")
        XCTAssertEqual(occurrences(of: "transposeSemitones: Int = TimelineLane.defaultTransposeSemitones", in: lane), 1, "`TimelineLane.init` takes its pitch default from the owner")
        XCTAssertEqual(occurrences(of: "forKey: .transposeSemitones) ?? TimelineLane.defaultTransposeSemitones", in: lane), 1, "the decode fallback reads the owner")
        let transpose = try source("Sources/Echoelmusic/Sequencer/AudioTranspose.swift")
        XCTAssertEqual(occurrences(of: "else { return TimelineLane.defaultTransposeSemitones }", in: transpose), 2, "`AudioTranspose.semitones(laneID:in:)` and, since GMMW AE-10b, `semitones(for:in:)` (a part's track + part sum) each answer \"no such audio track\" with the owner's default")
        let workstation = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(occurrences(of: "standard: Double(TimelineLane.defaultTransposeSemitones)", in: workstation), 1, "the \"Pitch\" row passes the lane's default once")

        // ELEVENTH FAMILY — the four network targets (2026-09-30). The numbers are the standards'
        // own (TouchOSC 8000 · ADM-OSC v1.0 sender 4001 · Art-Net 6454 · E1.31 5568); each sender
        // owns its own, and `outputRow` only carries them to the key.
        XCTAssertEqual(OSCSender.defaultPort, 8000, "OSC out defaults to TouchOSC's receive port")
        XCTAssertEqual(ADMOSCSender.defaultPort, 4001, "ADM-OSC out defaults to the spec's sender port (#1433)")
        XCTAssertEqual(ArtNetSender.defaultPort, 6454, "Art-Net's port is the standard's")
        XCTAssertEqual(SACNSender.defaultPort, 5568, "E1.31's port is the standard's")
        XCTAssertEqual(ArtNetSender.defaultUniverse, 0, "Art-Net counts universes from 0")
        XCTAssertEqual(SACNSender.defaultUniverse, 1, "sACN counts universes from 1 — 0 is invalid there")
        XCTAssertTrue((Float(0)...Float(32_767)).contains(Float(ArtNetSender.defaultUniverse)), "the Art-Net default sits inside its Universe row's range")
        XCTAssertTrue((Float(1)...Float(63_999)).contains(Float(SACNSender.defaultUniverse)), "the sACN default sits inside its Universe row's range")
        let senders: [(String, String)] = [
            ("Sources/Echoelmusic/Sync/OSCSender.swift", "OSCSender"),
            ("Sources/Echoelmusic/Sync/ADMOSCSender.swift", "ADMOSCSender"),
            ("Sources/Echoelmusic/Sync/ArtNetSender.swift", "ArtNetSender"),
            ("Sources/Echoelmusic/Sync/SACNSender.swift", "SACNSender"),
        ]
        for (rel, type) in senders {
            let sender = try source(rel)
            XCTAssertEqual(occurrences(of: "port: UInt16 = \(type).defaultPort", in: sender), 1, "\(rel): `init` takes its port default from the owner, not a literal")
            XCTAssertEqual(occurrences(of: "standardPort: Float(\(type).defaultPort)", in: patchbay), 1, "the \(type) row hands the owner's port to `outputRow` once")
        }
        for (rel, type) in senders.suffix(2) {
            let sender = try source(rel)
            XCTAssertEqual(occurrences(of: "universe: Int = \(type).defaultUniverse", in: sender), 1, "\(rel): `init` takes its universe default from the owner")
            XCTAssertEqual(occurrences(of: "standardUniverse: Float(\(type).defaultUniverse)", in: patchbay), 1, "the \(type) row hands the owner's universe to `outputRow` once")
        }
        XCTAssertEqual(occurrences(of: "decimals: 0, standard: standardPort)", in: patchbay), 1, "the shared \"Port\" row offers what its caller handed it")
        XCTAssertEqual(occurrences(of: "decimals: 0, standard: standardUniverse)", in: patchbay), 1, "the shared \"Universe\" row offers what its caller handed it")
    }

    // MARK: - claim 5 — the keystore family: a keystore-bound field offers the keystore's default

    func testEveryKeystoreBoundFieldOffersTheKeystoresDefault() throws {
        let code = try source(Self.studio)
        // The bindings: `@AppStorage(StudioDefaultKeys.x.key) … var name = StudioDefaultKeys.x.value`.
        let declPattern = #"@AppStorage\(StudioDefaultKeys\.(\w+)\.key\)\s*(?:private )?var (\w+)\s*(?::\s*\w+)?\s*=\s*StudioDefaultKeys\.\1\.value"#
        let declRegex = try NSRegularExpression(pattern: declPattern)
        var keyOf: [String: String] = [:]
        for m in declRegex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            guard let k = Range(m.range(at: 1), in: code), let v = Range(m.range(at: 2), in: code) else { continue }
            keyOf[String(code[v])] = String(code[k])
        }
        XCTAssertGreaterThanOrEqual(keyOf.count, 30, "the keystore-backed bindings in the instrument file — 58 on 2026-09-30; fewer than 30 means the regex stopped matching the declaration shape, not that the file shrank")

        let callRegex = try NSRegularExpression(pattern: #"EchoelValueField\(label: "([^"]*)",\s*value: \$(\w+)"#)
        var checked = 0
        var missing: [String] = []
        var wrongKey: [String] = []
        for m in callRegex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            guard let labelR = Range(m.range(at: 1), in: code), let varR = Range(m.range(at: 2), in: code) else { continue }
            let label = String(code[labelR]); let name = String(code[varR])
            guard let key = keyOf[name], let start = Range(m.range, in: code) else { continue }
            checked += 1
            // The call runs to the next `EchoelValueField(` or 600 characters, whichever is first —
            // enough for every call in the file (the longest is under 400).
            let tail = code[start.upperBound...].prefix(600)
            let call = tail.range(of: "EchoelValueField(").map { tail[..<$0.lowerBound] } ?? tail
            if !call.contains("standard: StudioDefaultKeys.") {
                missing.append("\(label) ($\(name))")
            } else if !call.contains("standard: StudioDefaultKeys.\(key).value") {
                wrongKey.append("\(label) ($\(name)) should name StudioDefaultKeys.\(key)")
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 30, "thirty keystore-bound value fields on 2026-09-30 — fewer means a binding changed shape, not that rows were removed")
        XCTAssertEqual(missing, [], """
            A value field bound to a keystore setting offers no "Default": \(missing). Rule 6 — the             keystore IS the owner of that default; pass `standard: StudioDefaultKeys.<key>.value`             after `decimals:`/`hint:` and before the closures.
            """)
        XCTAssertEqual(wrongKey, [], "a row's Default names a different key than its binding — the fresh-install value and the key would disagree: \(wrongKey)")
    }

    // MARK: - claim 4 — counterweight: the pad still commits in exactly one place

    func testThePadStillCommitsInExactlyOnePlace() throws {
        let code = try source(Self.pad)
        XCTAssertEqual(occurrences(of: "onCommit(", in: code), 1, """
            `EchoelNumberPad` calls `onCommit(` in more than one place. Only `commit()` — the OK \
            key — may commit; the "Default" key types, the digits type, the sign keys type. A \
            second committer is exactly the accidental one-touch reset rule 6's "in klaren \
            Worten bestätigt" forbids.
            """)
        let field = try source(Self.field)
        XCTAssertTrue(field.contains(".accessibilityAdjustableAction { dir in"),
                      "the swipe path `ValueFieldNotifiesEveryPathTests` owns is still there — the default action is added beside it, never in place of it")
    }

    // MARK: - Reading the source

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is absent — rewrite this guard with the move, do not let it pass on nothing")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// The text from `from` up to the first `to` after it; empty when either is missing, so the
    /// assertions on it read as absences with their own messages.
    private func slice(_ code: String, from: String, to: String) -> String {
        guard let start = code.range(of: from) else { return "" }
        guard let end = code.range(of: to, range: start.upperBound..<code.endIndex) else { return "" }
        return String(code[start.lowerBound..<end.lowerBound])
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }
}
