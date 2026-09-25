// TheEchoelInstanceStateIsAssembledReadOnlyTests.swift
// Echoel — WA3 slice 2 / WA4 prerequisite 4 (`docs/dev/NATIVE_DEVICE_ARCHITECTURE.md` §O, §P).
//
// WHAT THIS PINS. The Echoel instrument's instance state can be gathered into ONE value from the
// owners that hold it today — without writing anything. WA4 needs that before any front shows
// "this track's Echoel", or the front would invent a second truth for it.
//
// The claims, and why each one exists:
// 1. ROUND TRIP — a fully populated value survives encode → decode unchanged.
// 2. EVERY OWNER IS READ — each listed key, seeded with a non-default value, arrives in its field.
//    A field that silently keeps its default passes every other claim.
// 3. NO WRITER — the whole `UserDefaults` dictionary is identical before and after `assemble`.
//    This is the "importer first, writer second" line (#1416) made executable.
// 4. THE BOUNDARY — the encoded value has EXACTLY the declared top-level fields (no key, scale,
//    A4, tone system, BPM lock, bio value or preset cursor), and the Session's tempo route is
//    removed from the device's matrix.
// 5. FRESH INSTALL — an empty store assembles to the owners' own defaults.
// 6. SOURCE — the file writes nothing to `UserDefaults`, and the two keys it names by literal are
//    still declared by that literal in `EchoelStudioView` (the `SoundReset` pattern: a rename there
//    must fail here, not turn one field into a silent default).
//
// ⚠️ A statement about TODAY, not a prohibition (#364): when a writer lands, claim 3 and the
// header of `Core/EchoelInstanceState.swift` are replaced in the same commit.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–5 were transcribed into Python
// over a model of the assembly; claim 6 was driven against this tree. RED on the parent by
// ABSENCE — the subject file is new, so the bundle does not build there.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheEchoelInstanceStateIsAssembledReadOnlyTests: XCTestCase {

    private static let subjectPath = "Sources/Echoelmusic/Core/EchoelInstanceState.swift"
    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    // One fixture VALUE, never a factory (#1419: a defaulted UUID makes a factory a generator).
    private static let deviceRoute = ModRoute(source: .coherence,
                                              destination: ModDestination("synth.cutoff"))
    private static let tempoRoute = ModRoute(source: .heartRate,
                                             destination: ModDestination(ModDestinationKey.tempo))
    private static let probePatch = SynthPatch(name: "Assembly Probe")

    // MARK: Scratch store

    private var suiteName = ""
    private var defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        suiteName = "echoel.test.instanceState.\(UUID().uuidString)"
        guard let d = UserDefaults(suiteName: suiteName) else {
            XCTFail("cannot create a scratch UserDefaults suite")
            return
        }
        defaults = d
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private var otherGenre: MusicStyle {
        MusicStyle.allCases.first { $0 != StudioDefaultKeys.genre.value } ?? .selfObservation
    }

    private var otherLoop: LoopBarLength {
        LoopBarLength.allCases.first { $0 != StudioDefaultKeys.loopBars.value } ?? .eight
    }

    private var otherMood: MoodProfile {
        var m = MoodProfile()
        m.liveliness = 0.91
        m.darkness = 0.12
        m.humanize = 0.77
        return m
    }

    /// Every key the assembly claims to read, seeded with a value that is NOT its default.
    private func seedEveryKey() {
        defaults.set(FXCharacter.vinyl.rawValue, forKey: EchoelInstanceState.fxCharacterKey)
        defaults.set(otherGenre.rawValue, forKey: StudioDefaultKeys.genre.key)
        defaults.set(MoodStorage.encode(otherMood), forKey: StudioDefaultKeys.mood.key)
        defaults.set(0.83, forKey: StudioDefaultKeys.moodVariation.key)
        defaults.set(0.42, forKey: EchoelInstanceState.articulationKey)
        defaults.set("probeBass", forKey: StudioDefaultKeys.bassRhythm.key)
        defaults.set("probePad", forKey: StudioDefaultKeys.padRhythm.key)
        defaults.set(0.11, forKey: StudioDefaultKeys.padGate.key)
        defaults.set(0.66, forKey: StudioDefaultKeys.padAccent.key)
        defaults.set(0.93, forKey: StudioDefaultKeys.padEvolve.key)
        defaults.set(!StudioDefaultKeys.autoMode.value, forKey: StudioDefaultKeys.autoMode.key)
        defaults.set(otherLoop.rawValue, forKey: StudioDefaultKeys.loopBars.key)
        for (i, key) in MixerStore.storageKeys.enumerated() {
            defaults.set(Float(0.2) + Float(i) * 0.1, forKey: key)
        }
    }

    private func assembled() -> EchoelInstanceState {
        EchoelInstanceState.assemble(
            defaults: defaults,
            patch: Self.probePatch,
            modulation: ModulationMatrix(routes: [Self.deviceRoute, Self.tempoRoute]))
    }

    // MARK: 1 — round trip

    func testAFullyPopulatedStateSurvivesEncodeAndDecode() throws {
        seedEveryKey()
        let state = assembled()
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(EchoelInstanceState.self, from: data)
        XCTAssertEqual(back, state, "the instance state must survive encode → decode unchanged")
    }

    // MARK: 2 — every owner is read

    func testEverySeededOwnerArrivesInItsField() {
        seedEveryKey()
        let s = assembled()
        XCTAssertEqual(s.schemaVersion, EchoelInstanceState.currentSchemaVersion)
        XCTAssertEqual(s.deviceType, "echoel.instrument")
        XCTAssertEqual(s.patch, Self.probePatch, "the caller's patch must be carried as given")
        XCTAssertEqual(s.fxCharacterRaw, FXCharacter.vinyl.rawValue)
        XCTAssertEqual(s.genreRaw, otherGenre.rawValue)
        XCTAssertEqual(s.moodFields, MoodStorage.fields(from: otherMood))
        XCTAssertEqual(s.variation, 0.83, accuracy: 1e-9)
        XCTAssertEqual(s.articulation ?? -1, 0.42, accuracy: 1e-9)
        XCTAssertEqual(s.bassRhythmRaw, "probeBass")
        XCTAssertEqual(s.padRhythmRaw, "probePad")
        XCTAssertEqual(s.padGate, 0.11, accuracy: 1e-9)
        XCTAssertEqual(s.padAccent, 0.66, accuracy: 1e-9)
        XCTAssertEqual(s.padEvolve, 0.93, accuracy: 1e-9)
        XCTAssertEqual(s.autoMode, !StudioDefaultKeys.autoMode.value)
        XCTAssertEqual(s.loopBarsRaw, otherLoop.rawValue)
        for (i, key) in MixerStore.storageKeys.enumerated() {
            XCTAssertEqual(s.roleLevels[key] ?? -1, Float(0.2) + Float(i) * 0.1, accuracy: 1e-6,
                           "role level \(key) was not read from its owner")
        }
    }

    // MARK: 3 — no writer

    func testAssemblingWritesNothing() {
        seedEveryKey()
        let before = defaults.dictionaryRepresentation() as NSDictionary
        _ = assembled()
        let after = defaults.dictionaryRepresentation() as NSDictionary
        XCTAssertEqual(before, after,
                       "assemble must be read-only: the UserDefaults dictionary changed. "
                       + "A writer is its own slice (#1416) — replace this claim in that commit.")
    }

    // MARK: 4 — the boundary

    func testTheValueCarriesNoSessionRuntimeOrBioField() throws {
        seedEveryKey()
        let data = try JSONEncoder().encode(assembled())
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("the encoded state is not a JSON object")
            return
        }
        let expected: Set<String> = [
            "schemaVersion", "deviceType", "patch", "fxCharacterRaw", "genreRaw", "moodFields",
            "variation", "articulation", "bassRhythmRaw", "padRhythmRaw", "padGate", "padAccent",
            "padEvolve", "autoMode", "loopBarsRaw", "roleLevels", "modulation"
        ]
        XCTAssertEqual(Set(object.keys), expected,
                       "a new top-level field is a scope decision (WA3 §E / WA2 §O): Session "
                       + "state (key, scale, A4, tone system, BPM lock), runtime state and bio "
                       + "never enter the device's instance state")
    }

    func testTheSessionTempoRouteIsNotDeviceState() {
        let s = assembled()
        XCTAssertEqual(s.modulation.routes, [Self.deviceRoute],
                       "the tempo route is Session state (WA2 §O); only the device's own routes "
                       + "belong to its instance")
    }

    // MARK: 5 — fresh install

    func testAnEmptyStoreAssemblesToTheOwnersDefaults() {
        let s = assembled()
        XCTAssertEqual(s.fxCharacterRaw, FXCharacter.auto.rawValue)
        XCTAssertEqual(s.genreRaw, StudioDefaultKeys.genre.value.rawValue)
        XCTAssertEqual(s.moodFields, MoodStorage.fields(from: MoodProfile()))
        XCTAssertEqual(s.variation, StudioDefaultKeys.moodVariation.value, accuracy: 1e-9)
        XCTAssertNil(s.articulation, "never set must read as nil, not as a copied literal")
        XCTAssertEqual(s.bassRhythmRaw, StudioDefaultKeys.bassRhythm.value)
        XCTAssertEqual(s.padRhythmRaw, StudioDefaultKeys.padRhythm.value)
        XCTAssertEqual(s.padGate, StudioDefaultKeys.padGate.value, accuracy: 1e-9)
        XCTAssertEqual(s.padAccent, StudioDefaultKeys.padAccent.value, accuracy: 1e-9)
        XCTAssertEqual(s.padEvolve, StudioDefaultKeys.padEvolve.value, accuracy: 1e-9)
        XCTAssertEqual(s.autoMode, StudioDefaultKeys.autoMode.value)
        XCTAssertEqual(s.loopBarsRaw, StudioDefaultKeys.loopBars.value.rawValue)
        for key in MixerStore.storageKeys {
            XCTAssertEqual(s.roleLevels[key], MixerStore.defaultLevel)
        }
    }

    // MARK: 6 — source

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func source(_ relativePath: String) -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return text
    }

    private func codeOnly(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .map { line -> String in
                guard let r = line.range(of: " //") else { return line }
                return String(line[..<r.lowerBound])
            }
            .joined(separator: "\n")
    }

    func testTheAssemblyFileWritesNoDefaultsAndItsLiteralKeysStillExist() {
        let subject = codeOnly(source(Self.subjectPath))
        XCTAssertTrue(subject.contains("static func assemble("),
                      "ANCHOR MISSING: the assembly function moved or was renamed")
        for writer in [".set(", "removeObject(", "setValue(", "synchronize("] {
            XCTAssertFalse(subject.contains(writer),
                           "the assembly file contains `\(writer)` — it must stay read-only")
        }
        let studio = source(Self.studioPath)
        for key in [EchoelInstanceState.fxCharacterKey, EchoelInstanceState.articulationKey] {
            XCTAssertTrue(studio.contains("@AppStorage(\"\(key)\")"),
                          "EchoelStudioView no longer declares `\(key)` by that literal — the "
                          + "assembly would silently read a key nobody writes")
        }
    }
}
