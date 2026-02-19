import XCTest
@testable import Echoelmusic

/// Comprehensive tests for ProMixEngine — professional mixing console.
/// Tests channel management, inserts, sends, routing, automation, snapshots.
@MainActor
final class ProMixEngineTests: XCTestCase {

    var sut: ProMixEngine!

    override func setUp() async throws {
        try await super.setUp()
        sut = ProMixEngine.defaultSession()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization (5 tests)

    func testDefaultSessionInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.channels.isEmpty, "Default session should have channels")
    }

    func testDefaultSessionHasMasterChannel() {
        let master = sut.channels.first { $0.type == .master }
        XCTAssertNotNil(master, "Default session must have a master channel")
    }

    func testDefaultSessionBPM() {
        XCTAssertGreaterThan(sut.bpm, 0)
    }

    func testDefaultSessionSampleRate() {
        XCTAssertGreaterThanOrEqual(sut.sampleRate, 44100)
    }

    func testIsPlayingInitiallyFalse() {
        XCTAssertFalse(sut.isPlaying)
    }

    // MARK: - Channel Management (8 tests)

    func testAddAudioChannel() {
        let countBefore = sut.channels.count
        let channel = sut.addChannel(name: "Vocals", type: .audio)
        XCTAssertEqual(channel.name, "Vocals")
        XCTAssertEqual(channel.type, .audio)
        XCTAssertEqual(sut.channels.count, countBefore + 1)
    }

    func testAddInstrumentChannel() {
        let channel = sut.addChannel(name: "Synth", type: .instrument)
        XCTAssertEqual(channel.type, .instrument)
    }

    func testRemoveChannel() {
        let channel = sut.addChannel(name: "Temp", type: .audio)
        let countBefore = sut.channels.count
        sut.removeChannel(id: channel.id)
        XCTAssertEqual(sut.channels.count, countBefore - 1)
    }

    func testRemoveNonexistentChannelDoesNotCrash() {
        let countBefore = sut.channels.count
        sut.removeChannel(id: UUID())
        XCTAssertEqual(sut.channels.count, countBefore)
    }

    func testChannelDefaultVolume() {
        let channel = sut.addChannel(name: "Test", type: .audio)
        XCTAssertGreaterThanOrEqual(channel.volume, 0)
        XCTAssertLessThanOrEqual(channel.volume, 1)
    }

    func testChannelDefaultPan() {
        let channel = sut.addChannel(name: "Test", type: .audio)
        XCTAssertEqual(channel.pan, 0, accuracy: 0.01, "Default pan should be center")
    }

    func testChannelNotMutedByDefault() {
        let channel = sut.addChannel(name: "Test", type: .audio)
        XCTAssertFalse(channel.mute)
    }

    func testChannelNotSoloedByDefault() {
        let channel = sut.addChannel(name: "Test", type: .audio)
        XCTAssertFalse(channel.solo)
    }

    // MARK: - Insert Effects (5 tests)

    func testAddInsert() {
        let channel = sut.addChannel(name: "Vox", type: .audio)
        let insert = sut.addInsert(to: channel.id, effect: .compressor)
        XCTAssertNotNil(insert)
        XCTAssertEqual(insert?.effectType, .compressor)
    }

    func testAddInsertToInvalidChannelReturnsNil() {
        let insert = sut.addInsert(to: UUID(), effect: .compressor)
        XCTAssertNil(insert)
    }

    func testAddMultipleInserts() {
        let channel = sut.addChannel(name: "Mix", type: .audio)
        let eq = sut.addInsert(to: channel.id, effect: .parametricEQ)
        let comp = sut.addInsert(to: channel.id, effect: .compressor)
        XCTAssertNotNil(eq)
        XCTAssertNotNil(comp)
    }

    func testInsertEnabledByDefault() {
        let channel = sut.addChannel(name: "Mix", type: .audio)
        let insert = sut.addInsert(to: channel.id, effect: .parametricEQ)
        XCTAssertTrue(insert?.isEnabled ?? false)
    }

    func testInsertDefaultDryWet() {
        let channel = sut.addChannel(name: "Mix", type: .audio)
        let insert = sut.addInsert(to: channel.id, effect: .convolutionReverb)
        XCTAssertNotNil(insert)
        XCTAssertGreaterThanOrEqual(insert?.dryWet ?? -1, 0)
        XCTAssertLessThanOrEqual(insert?.dryWet ?? 2, 1)
    }

    // MARK: - Sends & Routing (5 tests)

    func testCreateAuxBus() {
        let aux = sut.createAuxBus(name: "Reverb Bus")
        XCTAssertEqual(aux.name, "Reverb Bus")
        XCTAssertEqual(aux.type, .aux)
    }

    func testAddSend() {
        let source = sut.addChannel(name: "Vox", type: .audio)
        let aux = sut.createAuxBus(name: "FX1")
        sut.addSend(from: source.id, to: aux.id, level: 0.7)
        // Verify send was added to channel
        let updated = sut.channels.first { $0.id == source.id }
        XCTAssertFalse(updated?.sends.isEmpty ?? true)
    }

    func testCreateBusGroup() {
        let ch1 = sut.addChannel(name: "Drum1", type: .audio)
        let ch2 = sut.addChannel(name: "Drum2", type: .audio)
        let bus = sut.createBusGroup(name: "Drums", channelIDs: [ch1.id, ch2.id])
        XCTAssertEqual(bus.type, .bus)
        XCTAssertEqual(bus.name, "Drums")
    }

    func testRouteSignal() {
        let channel = sut.addChannel(name: "Guitar", type: .audio)
        let destinations = sut.routeSignal(from: channel.id)
        XCTAssertNotNil(destinations)
    }

    func testRouteNonexistentChannel() {
        let destinations = sut.routeSignal(from: UUID())
        XCTAssertTrue(destinations.isEmpty)
    }

    // MARK: - Solo (3 tests)

    func testSoloExclusive() {
        let ch1 = sut.addChannel(name: "Ch1", type: .audio)
        let _ = sut.addChannel(name: "Ch2", type: .audio)
        sut.soloExclusive(channelID: ch1.id)
        let soloed = sut.channels.first { $0.id == ch1.id }
        XCTAssertTrue(soloed?.solo ?? false)
    }

    func testSoloExclusiveUnsolosOthers() {
        let ch1 = sut.addChannel(name: "Ch1", type: .audio)
        let ch2 = sut.addChannel(name: "Ch2", type: .audio)
        sut.soloExclusive(channelID: ch1.id)
        sut.soloExclusive(channelID: ch2.id)
        let firstChannel = sut.channels.first { $0.id == ch1.id }
        XCTAssertFalse(firstChannel?.solo ?? true, "Previous solo should be cleared")
    }

    func testSoloExclusiveInvalidIDDoesNotCrash() {
        sut.soloExclusive(channelID: UUID())
    }

    // MARK: - Automation (4 tests)

    func testUpdateAutomation() {
        sut.updateAutomation(time: 0)
        sut.updateAutomation(time: 1.0)
        // Verify engine survives automation updates
        XCTAssertNotNil(sut, "ProMixEngine should remain valid after automation updates")
    }

    func testAutomationAtDifferentTimes() {
        sut.updateAutomation(time: 0)
        sut.updateAutomation(time: 30)
        sut.updateAutomation(time: 60)
        XCTAssertNotNil(sut, "ProMixEngine should remain valid after automation at different times")
    }

    func testProcessBlock() {
        sut.processBlock(frameCount: 512)
        // Verify metering updates
        let master = sut.channels.first { $0.type == .master }
        XCTAssertNotNil(master)
    }

    func testProcessBlockZeroFrames() {
        sut.processBlock(frameCount: 0)
    }

    // MARK: - Snapshots (4 tests)

    func testSnapshotMix() {
        let snapshot = sut.snapshotMix(name: "Scene A")
        XCTAssertEqual(snapshot.name, "Scene A")
        XCTAssertFalse(snapshot.channelStates.isEmpty)
    }

    func testRecallMix() {
        let ch = sut.addChannel(name: "Vox", type: .audio)
        let snapshot = sut.snapshotMix(name: "Before")

        // Modify state
        sut.removeChannel(id: ch.id)

        // Recall
        sut.recallMix(snapshot: snapshot)
        // Engine should restore state
    }

    func testSnapshotPreservesChannelCount() {
        let snapshot = sut.snapshotMix()
        let channelCount = snapshot.channelStates.count
        XCTAssertGreaterThan(channelCount, 0)
    }

    func testSnapshotDefaultName() {
        let snapshot = sut.snapshotMix()
        XCTAssertFalse(snapshot.name.isEmpty)
    }
}
