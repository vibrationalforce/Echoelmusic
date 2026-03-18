#if canImport(AVFoundation)
// ProMixEngineBehaviorTests.swift
// Echoelmusic — Behavioral Tests for ProMixEngine
//
// Comprehensive behavioral tests covering channel management, fader/pan,
// solo exclusivity, routing, insert effects, mix snapshots, master bus,
// automation, metering, and edge cases.

import XCTest
@testable import Echoelmusic

@MainActor
final class ProMixEngineBehaviorTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(sampleRate: Double = 48000, bufferSize: Int = 256) -> ProMixEngine {
        ProMixEngine(sampleRate: sampleRate, bufferSize: bufferSize)
    }

    // MARK: - 1. Channel Strip Management

    func testAddChannel_AudioType_AppearsInChannelsList() {
        let sut = makeSUT()

        let channel = sut.addChannel(name: "Vocals", type: .audio)

        XCTAssertEqual(sut.channels.count, 1)
        XCTAssertEqual(sut.channels.first?.name, "Vocals")
        XCTAssertEqual(sut.channels.first?.type, .audio)
        XCTAssertEqual(sut.channels.first?.id, channel.id)
    }

    func testAddChannel_MultipleTypes_AllPresent() {
        let sut = makeSUT()

        sut.addChannel(name: "Audio Track", type: .audio)
        sut.addChannel(name: "Instrument", type: .instrument)
        sut.addChannel(name: "Aux Send", type: .aux)
        sut.addChannel(name: "Bus Group", type: .bus)

        XCTAssertEqual(sut.channels.count, 4)
        XCTAssertEqual(sut.channels[0].type, .audio)
        XCTAssertEqual(sut.channels[1].type, .instrument)
        XCTAssertEqual(sut.channels[2].type, .aux)
        XCTAssertEqual(sut.channels[3].type, .bus)
    }

    func testRemoveChannel_ExistingChannel_RemovesFromList() {
        let sut = makeSUT()
        let channel = sut.addChannel(name: "Kick", type: .audio)

        sut.removeChannel(id: channel.id)

        XCTAssertTrue(sut.channels.isEmpty)
    }

    func testRemoveChannel_NonExistentID_NoEffect() {
        let sut = makeSUT()
        sut.addChannel(name: "Kick", type: .audio)

        sut.removeChannel(id: UUID())

        XCTAssertEqual(sut.channels.count, 1)
    }

    func testRemoveChannel_CleansUpRoutingConnections() {
        let sut = makeSUT()
        let channel = sut.addChannel(name: "Kick", type: .audio)

        // Channel is auto-routed to master on creation
        let routesBefore = sut.routingMatrix.resolve(for: channel.id)
        XCTAssertFalse(routesBefore.isEmpty)

        sut.removeChannel(id: channel.id)

        let routesAfter = sut.routingMatrix.resolve(for: channel.id)
        XCTAssertTrue(routesAfter.isEmpty)
    }

    func testRemoveChannel_CleansUpAutomationLanes() {
        let sut = makeSUT()
        let channel = sut.addChannel(name: "Vocals", type: .audio)

        let lane = AutomationLane(
            parameter: .volume,
            channelID: channel.id,
            points: [AutomationPoint(time: 0, value: 0.5)]
        )
        sut.automationLanes.append(lane)
        XCTAssertEqual(sut.automationLanes.count, 1)

        sut.removeChannel(id: channel.id)

        XCTAssertTrue(sut.automationLanes.isEmpty)
    }

    // MARK: - 2. Fader / Pan

    func testChannelStrip_DefaultVolume_Is0Point8() {
        let sut = makeSUT()
        let channel = sut.addChannel(name: "Track", type: .audio)

        guard let idx = sut.channelIndex(for: channel.id) else {
            XCTFail("Channel not found")
            return
        }
        XCTAssertEqual(sut.channels[idx].volume, 0.8, accuracy: 0.001)
    }

    func testChannelStrip_VolumeClamps_ToZeroOne() {
        var strip = ChannelStrip(name: "Test", type: .audio, volume: 1.5)
        XCTAssertEqual(strip.volume, 1.0, accuracy: 0.001)

        strip.volume = -0.5
        XCTAssertEqual(strip.volume, 0.0, accuracy: 0.001)
    }

    func testChannelStrip_PanClamps_ToNegativeOnePositiveOne() {
        var strip = ChannelStrip(name: "Test", type: .audio, pan: 2.0)
        XCTAssertEqual(strip.pan, 1.0, accuracy: 0.001)

        strip.pan = -3.0
        XCTAssertEqual(strip.pan, -1.0, accuracy: 0.001)
    }

    func testChannelStrip_DefaultPan_IsCenter() {
        let strip = ChannelStrip(name: "Test", type: .audio)
        XCTAssertEqual(strip.pan, 0.0, accuracy: 0.001)
    }

    func testChannelStrip_MuteToggle() {
        var strip = ChannelStrip(name: "Test", type: .audio)
        XCTAssertFalse(strip.mute)

        strip.mute = true
        XCTAssertTrue(strip.mute)

        strip.mute = false
        XCTAssertFalse(strip.mute)
    }

    // MARK: - 3. Solo Exclusivity

    func testSoloExclusive_SoloOneChannel_OthersUnsoloed() {
        let sut = makeSUT()
        let kick = sut.addChannel(name: "Kick", type: .audio)
        let snare = sut.addChannel(name: "Snare", type: .audio)
        let hihat = sut.addChannel(name: "HiHat", type: .audio)

        sut.soloExclusive(channelID: snare.id)

        guard let kickIdx = sut.channelIndex(for: kick.id),
              let snareIdx = sut.channelIndex(for: snare.id),
              let hihatIdx = sut.channelIndex(for: hihat.id) else {
            XCTFail("Channel index lookup failed")
            return
        }
        XCTAssertFalse(sut.channels[kickIdx].solo)
        XCTAssertTrue(sut.channels[snareIdx].solo)
        XCTAssertFalse(sut.channels[hihatIdx].solo)
    }

    func testSoloExclusive_ToggleOff_ClearsAllSolos() {
        let sut = makeSUT()
        let kick = sut.addChannel(name: "Kick", type: .audio)
        sut.addChannel(name: "Snare", type: .audio)

        // Solo kick
        sut.soloExclusive(channelID: kick.id)
        guard let kickIdx = sut.channelIndex(for: kick.id) else {
            XCTFail("Channel index lookup failed")
            return
        }
        XCTAssertTrue(sut.channels[kickIdx].solo)

        // Toggle off: solo the already-soloed channel
        sut.soloExclusive(channelID: kick.id)

        // All solos should be cleared
        for channel in sut.channels {
            XCTAssertFalse(channel.solo, "Channel '\(channel.name)' should not be soloed")
        }
    }

    func testSoloExclusive_SwitchSolo_OnlyNewChannelSoloed() {
        let sut = makeSUT()
        let kick = sut.addChannel(name: "Kick", type: .audio)
        let snare = sut.addChannel(name: "Snare", type: .audio)

        sut.soloExclusive(channelID: kick.id)
        sut.soloExclusive(channelID: snare.id)

        guard let kickIdx = sut.channelIndex(for: kick.id),
              let snareIdx = sut.channelIndex(for: snare.id) else {
            XCTFail("Channel index lookup failed")
            return
        }
        XCTAssertFalse(sut.channels[kickIdx].solo)
        XCTAssertTrue(sut.channels[snareIdx].solo)
    }

    // MARK: - 4. Routing

    func testAddChannel_RoutesToMasterByDefault() {
        let sut = makeSUT()
        let channel = sut.addChannel(name: "Track", type: .audio)

        let destinations = sut.routingMatrix.resolve(for: channel.id)
        XCTAssertTrue(destinations.contains(sut.masterChannel.id))
    }

    func testAddSend_CreatesSendSlotOnChannel() {
        let sut = makeSUT()
        let track = sut.addChannel(name: "Vocals", type: .audio)
        let auxBus = sut.createAuxBus(name: "Reverb")

        sut.addSend(from: track.id, to: auxBus.id, level: 0.35, preFader: false)

        guard let trackIdx = sut.channelIndex(for: track.id) else {
            XCTFail("Channel not found")
            return
        }
        XCTAssertEqual(sut.channels[trackIdx].sends.count, 1)
        XCTAssertEqual(sut.channels[trackIdx].sends.first?.destinationID, auxBus.id)
        XCTAssertEqual(sut.channels[trackIdx].sends.first?.level ?? 0, 0.35, accuracy: 0.001)
        XCTAssertEqual(sut.channels[trackIdx].sends.first?.isPreFader, false)
    }

    func testRouteSignal_IncludesSendDestinations() {
        let sut = makeSUT()
        let track = sut.addChannel(name: "Vocals", type: .audio)
        let auxBus = sut.createAuxBus(name: "Reverb")

        sut.addSend(from: track.id, to: auxBus.id, level: 0.5)

        let destinations = sut.routeSignal(from: track.id)
        XCTAssertTrue(destinations.contains(sut.masterChannel.id), "Should route to master")
        XCTAssertTrue(destinations.contains(auxBus.id), "Should route to aux via send")
    }

    func testCreateBusGroup_ReroutesChannelsFromMasterToBus() {
        let sut = makeSUT()
        let kick = sut.addChannel(name: "Kick", type: .audio)
        let snare = sut.addChannel(name: "Snare", type: .audio)

        let drumBus = sut.createBusGroup(name: "Drums", channelIDs: [kick.id, snare.id])

        // Kick and snare should route to drum bus, not directly to master
        let kickDests = sut.routingMatrix.resolve(for: kick.id)
        let snareDests = sut.routingMatrix.resolve(for: snare.id)
        XCTAssertTrue(kickDests.contains(drumBus.id))
        XCTAssertTrue(snareDests.contains(drumBus.id))
        XCTAssertFalse(kickDests.contains(sut.masterChannel.id))
        XCTAssertFalse(snareDests.contains(sut.masterChannel.id))

        // Drum bus itself should route to master
        let busDests = sut.routingMatrix.resolve(for: drumBus.id)
        XCTAssertTrue(busDests.contains(sut.masterChannel.id))
    }

    // MARK: - 5. Insert Effects

    func testAddInsert_CompressorToChannel_AppearsInInserts() {
        let sut = makeSUT()
        let track = sut.addChannel(name: "Vocals", type: .audio)

        let slot = sut.addInsert(to: track.id, effect: .compressor)

        XCTAssertNotNil(slot)
        guard let trackIdx = sut.channelIndex(for: track.id) else {
            XCTFail("Channel not found")
            return
        }
        XCTAssertEqual(sut.channels[trackIdx].inserts.count, 1)
        XCTAssertEqual(sut.channels[trackIdx].inserts.first?.effectType, .compressor)
        XCTAssertEqual(sut.channels[trackIdx].inserts.first?.isEnabled, true)
    }

    func testAddInsert_MaxEightInserts_NinthReturnsNil() {
        let sut = makeSUT()
        let track = sut.addChannel(name: "Track", type: .audio)

        for i in 0..<8 {
            let result = sut.addInsert(to: track.id, effect: .compressor)
            XCTAssertNotNil(result, "Insert \(i) should succeed")
        }

        let overflow = sut.addInsert(to: track.id, effect: .limiter)
        XCTAssertNil(overflow, "9th insert should return nil")

        guard let trackIdx = sut.channelIndex(for: track.id) else {
            XCTFail("Channel not found")
            return
        }
        XCTAssertEqual(sut.channels[trackIdx].inserts.count, ChannelStrip.maxInserts)
    }

    func testAddInsert_NonExistentChannel_ReturnsNil() {
        let sut = makeSUT()

        let result = sut.addInsert(to: UUID(), effect: .compressor)

        XCTAssertNil(result)
    }

    func testInsertSlot_BypassToggle() {
        var slot = InsertSlot(effectType: .parametricEQ, isEnabled: true)
        XCTAssertTrue(slot.isEnabled)

        slot.isEnabled = false
        XCTAssertFalse(slot.isEnabled)
    }

    func testInsertSlot_DryWetClamps() {
        let slotOver = InsertSlot(effectType: .chorus, dryWet: 1.5)
        XCTAssertEqual(slotOver.dryWet, 1.0, accuracy: 0.001)

        let slotUnder = InsertSlot(effectType: .chorus, dryWet: -0.5)
        XCTAssertEqual(slotUnder.dryWet, 0.0, accuracy: 0.001)
    }

    // MARK: - 6. Mix Snapshots

    func testSnapshotMix_CapturesAllChannelStates() {
        let sut = makeSUT()
        let vocals = sut.addChannel(name: "Vocals", type: .audio)
        let guitar = sut.addChannel(name: "Guitar", type: .audio)

        guard let vocalsIdx = sut.channelIndex(for: vocals.id),
              let guitarIdx = sut.channelIndex(for: guitar.id) else {
            XCTFail("Channel index lookup failed")
            return
        }
        sut.channels[vocalsIdx].volume = 0.6
        sut.channels[vocalsIdx].pan = -0.3
        sut.channels[guitarIdx].volume = 0.9
        sut.channels[guitarIdx].mute = true

        let snapshot = sut.snapshotMix(name: "Verse Mix")

        XCTAssertEqual(snapshot.name, "Verse Mix")
        // 2 channels + master = 3 channel states
        XCTAssertEqual(snapshot.channelStates.count, 3)

        let vocalsState = snapshot.channelStates.first(where: { $0.channelID == vocals.id })
        XCTAssertNotNil(vocalsState)
        XCTAssertEqual(vocalsState?.volume ?? 0, 0.6, accuracy: 0.001)
        XCTAssertEqual(vocalsState?.pan ?? 0, -0.3, accuracy: 0.001)

        let guitarState = snapshot.channelStates.first(where: { $0.channelID == guitar.id })
        XCTAssertNotNil(guitarState)
        XCTAssertEqual(guitarState?.volume ?? 0, 0.9, accuracy: 0.001)
        XCTAssertTrue(guitarState?.mute ?? false)
    }

    func testRecallMix_RestoresChannelStates() {
        let sut = makeSUT()
        let vocals = sut.addChannel(name: "Vocals", type: .audio)

        guard let vocalsIdx = sut.channelIndex(for: vocals.id) else {
            XCTFail("Channel index lookup failed")
            return
        }
        sut.channels[vocalsIdx].volume = 0.5
        sut.channels[vocalsIdx].pan = 0.7

        let snapshot = sut.snapshotMix(name: "Saved")

        // Change values
        sut.channels[vocalsIdx].volume = 0.1
        sut.channels[vocalsIdx].pan = -0.9

        // Recall
        sut.recallMix(snapshot: snapshot)

        XCTAssertEqual(sut.channels[vocalsIdx].volume, 0.5, accuracy: 0.001)
        XCTAssertEqual(sut.channels[vocalsIdx].pan, 0.7, accuracy: 0.001)
    }

    func testRecallMix_RestoresMasterChannelState() {
        let sut = makeSUT()

        sut.masterChannel.volume = 0.75
        let snapshot = sut.snapshotMix(name: "MasterTest")

        sut.masterChannel.volume = 1.0
        sut.recallMix(snapshot: snapshot)

        XCTAssertEqual(sut.masterChannel.volume, 0.75, accuracy: 0.001)
    }

    // MARK: - 7. Master Bus

    func testMasterChannel_InitializedWithCorrectDefaults() {
        let sut = makeSUT()

        XCTAssertEqual(sut.masterChannel.name, "Master")
        XCTAssertEqual(sut.masterChannel.type, .master)
        XCTAssertEqual(sut.masterChannel.volume, 1.0, accuracy: 0.001)
        XCTAssertEqual(sut.masterChannel.pan, 0.0, accuracy: 0.001)
        XCTAssertEqual(sut.masterChannel.color, .slate)
    }

    func testMasterChannel_VolumeCanBeAdjusted() {
        let sut = makeSUT()

        sut.masterChannel.volume = 0.5
        XCTAssertEqual(sut.masterChannel.volume, 0.5, accuracy: 0.001)
    }

    // MARK: - 8. Automation

    func testAutomationLane_LinearInterpolation() {
        let lane = AutomationLane(
            parameter: .volume,
            channelID: UUID(),
            points: [
                AutomationPoint(time: 0, value: 0.0, curveType: .linear),
                AutomationPoint(time: 1, value: 1.0, curveType: .linear)
            ]
        )

        XCTAssertEqual(lane.valueAt(time: 0.5), 0.5, accuracy: 0.01)
        XCTAssertEqual(lane.valueAt(time: 0.0), 0.0, accuracy: 0.01)
        XCTAssertEqual(lane.valueAt(time: 1.0), 1.0, accuracy: 0.01)
    }

    func testAutomationLane_HoldCurve_ReturnsFirstPointValue() {
        let lane = AutomationLane(
            parameter: .volume,
            channelID: UUID(),
            points: [
                AutomationPoint(time: 0, value: 0.3, curveType: .linear),
                AutomationPoint(time: 1, value: 0.9, curveType: .hold)
            ]
        )

        // Hold should return the previous point's value for any time in the segment
        XCTAssertEqual(lane.valueAt(time: 0.5), 0.3, accuracy: 0.01)
        XCTAssertEqual(lane.valueAt(time: 0.99), 0.3, accuracy: 0.01)
    }

    func testAutomationLane_BeforeFirstPoint_ReturnsFirstValue() {
        let lane = AutomationLane(
            parameter: .pan,
            channelID: UUID(),
            points: [
                AutomationPoint(time: 5.0, value: 0.7)
            ]
        )

        XCTAssertEqual(lane.valueAt(time: 0.0), 0.7, accuracy: 0.01)
        XCTAssertEqual(lane.valueAt(time: 2.0), 0.7, accuracy: 0.01)
    }

    func testAutomationLane_AfterLastPoint_ReturnsLastValue() {
        let lane = AutomationLane(
            parameter: .volume,
            channelID: UUID(),
            points: [
                AutomationPoint(time: 0, value: 0.2),
                AutomationPoint(time: 1, value: 0.8)
            ]
        )

        XCTAssertEqual(lane.valueAt(time: 10.0), 0.8, accuracy: 0.01)
    }

    func testAutomationLane_EmptyPoints_ReturnsZero() {
        let lane = AutomationLane(
            parameter: .volume,
            channelID: UUID(),
            points: []
        )

        XCTAssertEqual(lane.valueAt(time: 5.0), 0.0, accuracy: 0.01)
    }

    func testUpdateAutomation_AppliesVolumeToChannel() {
        let sut = makeSUT()
        let track = sut.addChannel(name: "Vocals", type: .audio)

        let lane = AutomationLane(
            parameter: .volume,
            channelID: track.id,
            points: [
                AutomationPoint(time: 0, value: 0.2),
                AutomationPoint(time: 10, value: 0.8)
            ],
            isEnabled: true
        )
        sut.automationLanes.append(lane)

        sut.updateAutomation(time: 5.0)

        guard let idx = sut.channelIndex(for: track.id) else {
            XCTFail("Channel not found")
            return
        }
        // At t=5, linear interp between 0.2 and 0.8 should give ~0.5
        XCTAssertEqual(sut.channels[idx].volume, 0.5, accuracy: 0.05)
    }

    func testUpdateAutomation_DisabledLane_DoesNotApply() {
        let sut = makeSUT()
        let track = sut.addChannel(name: "Track", type: .audio)

        guard let idx = sut.channelIndex(for: track.id) else {
            XCTFail("Channel not found")
            return
        }
        let originalVolume = sut.channels[idx].volume

        let lane = AutomationLane(
            parameter: .volume,
            channelID: track.id,
            points: [AutomationPoint(time: 0, value: 0.1)],
            isEnabled: false
        )
        sut.automationLanes.append(lane)

        sut.updateAutomation(time: 0.0)

        XCTAssertEqual(sut.channels[idx].volume, originalVolume, accuracy: 0.001)
    }

    // MARK: - 9. Metering

    func testMeterState_DefaultValues() {
        let meter = MeterState()

        XCTAssertEqual(meter.peak, 0.0, accuracy: 0.001)
        XCTAssertEqual(meter.rms, 0.0, accuracy: 0.001)
        XCTAssertEqual(meter.peakHold, 0.0, accuracy: 0.001)
        XCTAssertFalse(meter.isClipping)
        XCTAssertEqual(meter.phaseCorrelation, 1.0, accuracy: 0.001)
    }

    func testMeterState_CustomValues() {
        let meter = MeterState(peak: 0.9, rms: 0.6, peakHold: 0.95, isClipping: true, phaseCorrelation: -0.5)

        XCTAssertEqual(meter.peak, 0.9, accuracy: 0.001)
        XCTAssertEqual(meter.rms, 0.6, accuracy: 0.001)
        XCTAssertEqual(meter.peakHold, 0.95, accuracy: 0.001)
        XCTAssertTrue(meter.isClipping)
        XCTAssertEqual(meter.phaseCorrelation, -0.5, accuracy: 0.001)
    }

    // MARK: - 10. Edge Cases

    func testEmptyMixer_SnapshotContainsOnlyMaster() {
        let sut = makeSUT()

        let snapshot = sut.snapshotMix(name: "Empty")

        // Only the master channel should be present
        XCTAssertEqual(snapshot.channelStates.count, 1)
        XCTAssertEqual(snapshot.channelStates.first?.channelID, sut.masterChannel.id)
    }

    func testRemoveLastChannel_LeavesEmptyChannelsList() {
        let sut = makeSUT()
        let channel = sut.addChannel(name: "Only Track", type: .audio)

        sut.removeChannel(id: channel.id)

        XCTAssertTrue(sut.channels.isEmpty)
        // Master should still exist
        XCTAssertEqual(sut.masterChannel.type, .master)
    }

    func testRemoveChannel_CleansUpSendsOnOtherChannels() {
        let sut = makeSUT()
        let track = sut.addChannel(name: "Vocals", type: .audio)
        let auxBus = sut.addChannel(name: "Reverb", type: .aux)

        sut.addSend(from: track.id, to: auxBus.id, level: 0.4)

        guard let trackIdxBefore = sut.channelIndex(for: track.id) else {
            XCTFail("Channel not found")
            return
        }
        XCTAssertEqual(sut.channels[trackIdxBefore].sends.count, 1)

        // Remove the aux bus that the send points to
        sut.removeChannel(id: auxBus.id)

        guard let trackIdxAfter = sut.channelIndex(for: track.id) else {
            XCTFail("Channel not found after removal")
            return
        }
        XCTAssertEqual(sut.channels[trackIdxAfter].sends.count, 0,
                       "Send targeting removed channel should be cleaned up")
    }

    func testAddChannel_DuplicateNames_BothExist() {
        let sut = makeSUT()

        sut.addChannel(name: "Vocals", type: .audio)
        sut.addChannel(name: "Vocals", type: .audio)

        XCTAssertEqual(sut.channels.count, 2)
        XCTAssertEqual(sut.channels[0].name, "Vocals")
        XCTAssertEqual(sut.channels[1].name, "Vocals")
        // They should have different UUIDs
        XCTAssertNotEqual(sut.channels[0].id, sut.channels[1].id)
    }

    func testDefaultSession_Creates8TracksAnd2AuxBuses() {
        let sut = ProMixEngine.defaultSession()

        let audioTracks = sut.channels.filter { $0.type == .audio }
        let auxBuses = sut.channels.filter { $0.type == .aux }

        XCTAssertEqual(audioTracks.count, 8)
        XCTAssertEqual(auxBuses.count, 2)
        XCTAssertEqual(sut.channels.count, 10, "8 audio + 2 aux")
    }

    func testProcessBlock_WhenNotPlaying_DoesNotAdvanceTime() {
        let sut = makeSUT()
        sut.isPlaying = false
        sut.currentTime = 0

        sut.processBlock(frameCount: 256)

        XCTAssertEqual(sut.currentTime, 0, accuracy: 0.0001)
    }

    func testProcessBlock_WhenPlaying_AdvancesTime() {
        let sut = makeSUT(sampleRate: 48000, bufferSize: 256)
        sut.isPlaying = true
        sut.currentTime = 0

        sut.processBlock(frameCount: 256)

        let expectedDuration = 256.0 / 48000.0
        XCTAssertEqual(sut.currentTime, expectedDuration, accuracy: 0.0001)
    }

    func testSendSlot_LevelClamps() {
        let sendOver = SendSlot(level: 1.5)
        XCTAssertEqual(sendOver.level, 1.0, accuracy: 0.001)

        let sendUnder = SendSlot(level: -0.5)
        XCTAssertEqual(sendUnder.level, 0.0, accuracy: 0.001)
    }

    func testRoutingMatrix_DuplicateConnection_UpdatesLevel() {
        var matrix = RoutingMatrix()
        let src = UUID()
        let dst = UUID()

        matrix.addConnection(from: src, to: dst, level: 0.5)
        matrix.addConnection(from: src, to: dst, level: 0.8)

        // Should still be one connection, but with updated level
        let matching = matrix.connections.filter { $0.sourceID == src && $0.destinationID == dst }
        XCTAssertEqual(matching.count, 1)
        XCTAssertEqual(matching.first?.level ?? 0, 0.8, accuracy: 0.001)
    }

    func testRoutingMatrix_RemoveConnection() {
        var matrix = RoutingMatrix()
        let src = UUID()
        let dst = UUID()

        matrix.addConnection(from: src, to: dst)
        XCTAssertEqual(matrix.connections.count, 1)

        matrix.removeConnection(from: src, to: dst)
        XCTAssertTrue(matrix.connections.isEmpty)
    }

    func testAutomationPoint_ValueClamps() {
        let over = AutomationPoint(time: 0, value: 1.5)
        XCTAssertEqual(over.value, 1.0, accuracy: 0.001)

        let under = AutomationPoint(time: 0, value: -0.5)
        XCTAssertEqual(under.value, 0.0, accuracy: 0.001)
    }

    func testAutomationLane_PointsSortedByTime() {
        let lane = AutomationLane(
            parameter: .volume,
            channelID: UUID(),
            points: [
                AutomationPoint(time: 5, value: 0.5),
                AutomationPoint(time: 1, value: 0.1),
                AutomationPoint(time: 3, value: 0.3)
            ]
        )

        XCTAssertEqual(lane.points[0].time, 1.0, accuracy: 0.001)
        XCTAssertEqual(lane.points[1].time, 3.0, accuracy: 0.001)
        XCTAssertEqual(lane.points[2].time, 5.0, accuracy: 0.001)
    }

    func testSidechain_ConfiguresRoutingConnection() {
        let sut = makeSUT()
        let bass = sut.addChannel(name: "Bass", type: .audio)
        let kick = sut.addChannel(name: "Kick", type: .audio)

        sut.setSidechain(compressorChannelID: bass.id, sidechainSourceID: kick.id)

        // Should have a routing connection from kick to bass
        let destinations = sut.routingMatrix.resolve(for: kick.id)
        XCTAssertTrue(destinations.contains(bass.id))
    }

    func testChannelStrip_MaxInserts_IsEight() {
        XCTAssertEqual(ChannelStrip.maxInserts, 8)
    }

    func testChannelStrip_MaxSends_IsEight() {
        XCTAssertEqual(ChannelStrip.maxSends, 8)
    }
}

#endif
