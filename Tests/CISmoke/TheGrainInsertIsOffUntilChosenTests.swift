// TheGrainInsertIsOffUntilChosenTests.swift
// Echoel — GMMW GA-10a: Echoel Grain as an insert on a track's `DeviceChain` — the model.
//
// WHAT IT PINS.
// 1. OFF UNTIL CHOSEN: an empty chain, a character-only chain and a chain with only an unknown
//    insert all answer `soundingGrain == nil`; a disabled grain insert does not sound.
// 2. THE WRITER keeps the character insert and any unknown insert in place, keeps ONE grain insert
//    and its identity, removes it on nil, and stores no chain when nothing is left; the character
//    writer keeps the grain insert in turn.
// 3. SETTINGS round-trip through a lane's JSON byte-stable, decode missing fields as defaults, and
//    reach the kernel only inside its ranges (non-finite → default).
// 4. A LATER `typeVersion` is not read with this build's meaning, and choosing settings over it
//    re-stamps state and version together.
//
// END-TO-END BEHAVIOUR over shipped value types (`DeviceChain`, `DeviceInsert`, `GrainSettings`,
// `TimelineLane`); no source-text scan.
// HONEST GRADING (§3): the file does NOT compile against the parent — `GrainSettings`,
// `DeviceInsert.grain`, `grainSettings`, `soundingGrain` and `settingGrain` are new — so no
// assertion has a verdict there; every claim is a FORWARD guard (one absence, #486). Counterweights:
// claim 1's character answer, claim 2's untouched unknown and character inserts. Graded by Python
// transcription of `settingGrain` and `sanitized`.
//
// ⚠️ THE LIMIT. Nothing here makes sound: GA-10b bakes the cloud off the render thread, GA-10c plays
// it. No production caller writes a grain insert yet, so no song changes by this slice.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheGrainInsertIsOffUntilChosenTests: XCTestCase {

    private static let unknownInsert = DeviceInsert(
        typeID: "com.example.later.reverb", typeVersion: 2, isEnabled: true,
        stateBlob: Data([0x01, 0xFE]))

    private func settings(position: Float = 0.25, mix: Float = 0.75, seed: UInt64 = 7) -> GrainSettings {
        var s = GrainSettings()
        s.position = position
        s.mix = mix
        s.seed = seed
        return s
    }

    // MARK: 1

    func testNoChainSoundsAGrainUntilOneIsChosen() {
        XCTAssertNil(DeviceChain(inserts: []).soundingGrain)
        XCTAssertNil(DeviceChain(inserts: [.character(.room)]).soundingGrain)
        XCTAssertNil(DeviceChain(inserts: [Self.unknownInsert]).soundingGrain)
        var off = DeviceInsert.grain(settings())
        off.isEnabled = false
        XCTAssertNil(DeviceChain(inserts: [off]).soundingGrain, "a disabled grain insert is silent")
        XCTAssertEqual(DeviceChain(inserts: [off, .grain(settings(position: 0.5))]).soundingGrain?.position, 0.5,
                       "the first ENABLED grain insert is what sounds")
        XCTAssertEqual(DeviceChain(inserts: [.grain(settings())]).soundingCharacter, nil,
                       "COUNTERWEIGHT: a grain insert is not a character")
    }

    // MARK: 2

    func testTheWriterKeepsEveryOtherInsertAndOneGrain() throws {
        XCTAssertNil(DeviceChain(inserts: []).settingGrain(nil), "nothing chosen, nothing stored")
        let character = DeviceInsert.character(.hall)
        let chain = DeviceChain(inserts: [Self.unknownInsert, character])
        let set = try XCTUnwrap(chain.settingGrain(settings()))
        XCTAssertEqual(set.inserts.map(\.typeID),
                       [Self.unknownInsert.typeID, DeviceInsert.characterTypeID, DeviceInsert.grainTypeID])
        XCTAssertEqual(set.inserts[0], Self.unknownInsert, "an unknown insert is kept verbatim")
        XCTAssertEqual(set.inserts[1], character, "the character insert is untouched")
        XCTAssertEqual(set.soundingCharacter, .hall)

        let grainID = try XCTUnwrap(set.inserts.last?.id)
        let changed = try XCTUnwrap(set.settingGrain(settings(position: 0.9)))
        XCTAssertEqual(changed.inserts.last?.id, grainID, "the grain insert keeps its identity")
        XCTAssertEqual(changed.soundingGrain?.position, 0.9)

        let doubled = DeviceChain(inserts: [.grain(settings()), Self.unknownInsert, .grain(settings(position: 0.4))])
        let one = try XCTUnwrap(doubled.settingGrain(settings(position: 0.6)))
        XCTAssertEqual(one.inserts.filter { $0.typeID == DeviceInsert.grainTypeID }.count, 1)

        let removed = try XCTUnwrap(set.settingGrain(nil))
        XCTAssertEqual(removed.inserts, [Self.unknownInsert, character])
        XCTAssertNil(DeviceChain(inserts: [.grain(settings())]).settingGrain(nil), "an empty chain is stored as none")

        let afterCharacter = try XCTUnwrap(set.settingCharacter(nil))
        XCTAssertEqual(afterCharacter.soundingGrain, set.soundingGrain,
                       "the character writer keeps the grain insert (it keeps every other type)")
    }

    // MARK: 3

    func testTheSettingsRoundTripAndReachTheKernelInsideTheirRanges() throws {
        let lane = TimelineLane(name: "Loop", kind: .audio,
                                deviceChain: DeviceChain(inserts: [.grain(settings())]))
        let data = try JSONEncoder().encode(lane)
        let back = try JSONDecoder().decode(TimelineLane.self, from: data)
        XCTAssertEqual(back.deviceChain, lane.deviceChain)
        XCTAssertEqual(back.deviceChain?.soundingGrain, settings().sanitized)

        let partial = try JSONDecoder().decode(GrainSettings.self, from: Data(#"{"position":0.3}"#.utf8))
        XCTAssertEqual(partial.position, 0.3)
        XCTAssertEqual(partial.grainMilliseconds, GrainSettings().grainMilliseconds, "a missing field is its default")

        var wild = GrainSettings()
        wild.position = 4
        wild.grainMilliseconds = .nan
        wild.density = -1
        wild.spraySeconds = .infinity
        wild.pitchSemitones = 99
        wild.stereoSpread = -3
        wild.mix = 2
        let clean = wild.sanitized
        XCTAssertEqual(clean.position, 1)
        XCTAssertEqual(clean.grainMilliseconds, GrainSettings().grainMilliseconds, "non-finite → default")
        XCTAssertEqual(clean.density, 0)
        XCTAssertEqual(clean.spraySeconds, GrainSettings().spraySeconds)
        XCTAssertEqual(clean.pitchSemitones, 24)
        XCTAssertEqual(clean.stereoSpread, 0)
        XCTAssertEqual(clean.mix, 1)
        XCTAssertEqual(DeviceInsert.grain(wild).grainSettings, clean, "the reader hands out sanitised settings")
    }

    // MARK: 4

    func testALaterGrainIsNotReadAndChoosingRestampsIt() throws {
        let later = DeviceInsert(typeID: DeviceInsert.grainTypeID, typeVersion: 2, isEnabled: true,
                                 stateBlob: Data(#"{"position":0.5}"#.utf8))
        XCTAssertNil(later.grainSettings, "a later format is not read with this build's meaning")
        XCTAssertNil(DeviceChain(inserts: [later]).soundingGrain)
        let restamped = try XCTUnwrap(DeviceChain(inserts: [later]).settingGrain(settings()))
        XCTAssertEqual(restamped.inserts.first?.id, later.id)
        XCTAssertEqual(restamped.inserts.first?.typeVersion, DeviceInsert.grainTypeVersion,
                       "state and version change together — never v1 bytes under a v2 label")
        XCTAssertEqual(restamped.soundingGrain, settings().sanitized)
    }
}
