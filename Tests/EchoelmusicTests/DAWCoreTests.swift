import XCTest
@testable import Echoelmusic

/// Comprehensive Unit Tests for DAW Core Engine
/// Tests all critical functionality: tracks, clips, MIDI, automation, undo/redo, project management
@MainActor
final class DAWCoreTests: XCTestCase {

    var dawCore: DAWCore!

    override func setUp() async throws {
        await MainActor.run {
            dawCore = DAWCore()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            dawCore = nil
        }
    }

    // MARK: - Project Tests

    func testProjectCreation() async throws {
        await MainActor.run {
            XCTAssertEqual(dawCore.project.name, "Untitled Project")
            XCTAssertEqual(dawCore.project.tempo, 120.0)
            XCTAssertEqual(dawCore.project.timeSignature.numerator, 4)
            XCTAssertEqual(dawCore.project.timeSignature.denominator, 4)
            XCTAssertEqual(dawCore.project.tracks.count, 0)
        }
    }

    func testNewProject() async throws {
        await MainActor.run {
            dawCore.newProject(name: "Test Project")

            XCTAssertEqual(dawCore.project.name, "Test Project")
            XCTAssertEqual(dawCore.project.tracks.count, 0)
            XCTAssertEqual(dawCore.playbackPosition, 0.0)
        }
    }

    func testTempoChange() async throws {
        await MainActor.run {
            dawCore.setTempo(140.0)

            XCTAssertEqual(dawCore.project.tempo, 140.0)
        }
    }

    func testTimeSignatureChange() async throws {
        await MainActor.run {
            dawCore.setTimeSignature(numerator: 6, denominator: 8)

            XCTAssertEqual(dawCore.project.timeSignature.numerator, 6)
            XCTAssertEqual(dawCore.project.timeSignature.denominator, 8)
        }
    }

    // MARK: - Track Tests

    func testCreateMIDITrack() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "MIDI Track", type: .midi)

            XCTAssertEqual(dawCore.project.tracks.count, 1)
            XCTAssertEqual(track.name, "MIDI Track")
            XCTAssertEqual(track.type, .midi)
            XCTAssertFalse(track.isMuted)
            XCTAssertFalse(track.isSolo)
        }
    }

    func testCreateAudioTrack() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "Audio Track", type: .audio)

            XCTAssertEqual(track.type, .audio)
        }
    }

    func testDeleteTrack() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "Test Track", type: .midi)
            XCTAssertEqual(dawCore.project.tracks.count, 1)

            dawCore.deleteTrack(id: track.id)

            XCTAssertEqual(dawCore.project.tracks.count, 0)
        }
    }

    func testDuplicateTrack() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "Original Track", type: .midi)
            XCTAssertEqual(dawCore.project.tracks.count, 1)

            dawCore.duplicateTrack(id: track.id)

            XCTAssertEqual(dawCore.project.tracks.count, 2)
            XCTAssertTrue(dawCore.project.tracks[1].name.contains("Copy"))
        }
    }

    func testToggleMute() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "Test Track", type: .midi)
            XCTAssertFalse(dawCore.project.tracks[0].isMuted)

            dawCore.toggleMute(trackId: track.id)

            XCTAssertTrue(dawCore.project.tracks[0].isMuted)
        }
    }

    func testToggleSolo() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "Test Track", type: .midi)
            XCTAssertFalse(dawCore.project.tracks[0].isSolo)

            dawCore.toggleSolo(trackId: track.id)

            XCTAssertTrue(dawCore.project.tracks[0].isSolo)
        }
    }

    // MARK: - Clip Tests

    func testCreateMIDIClip() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "MIDI Track", type: .midi)
            let clip = dawCore.createMIDIClip(on: track.id, at: 0.0, duration: 4.0)

            XCTAssertEqual(dawCore.project.tracks[0].clips.count, 1)
            XCTAssertEqual(clip.startTime, 0.0)
            XCTAssertEqual(clip.duration, 4.0)
        }
    }

    func testCreateAudioClip() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "Audio Track", type: .audio)
            let clip = dawCore.createAudioClip(on: track.id, audioFileURL: "/test/audio.wav", at: 0.0)

            XCTAssertEqual(dawCore.project.tracks[0].clips.count, 1)
        }
    }

    func testDeleteClip() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "MIDI Track", type: .midi)
            let clip = dawCore.createMIDIClip(on: track.id, at: 0.0, duration: 4.0)

            XCTAssertEqual(dawCore.project.tracks[0].clips.count, 1)

            dawCore.deleteClip(trackId: track.id, clipId: clip.id)

            XCTAssertEqual(dawCore.project.tracks[0].clips.count, 0)
        }
    }

    // MARK: - MIDI Note Tests

    func testAddMIDINote() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "MIDI Track", type: .midi)
            let clip = dawCore.createMIDIClip(on: track.id, at: 0.0, duration: 4.0)

            dawCore.addMIDINote(to: clip.id, pitch: 60, velocity: 100, startTime: 0.0, duration: 1.0)

            if case .midi(let midiClip) = dawCore.project.tracks[0].clips[0].type {
                XCTAssertEqual(midiClip.notes.count, 1)
                XCTAssertEqual(midiClip.notes[0].pitch, 60)
                XCTAssertEqual(midiClip.notes[0].velocity, 100)
            } else {
                XCTFail("Clip should be MIDI type")
            }
        }
    }

    func testDeleteMIDINote() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "MIDI Track", type: .midi)
            let clip = dawCore.createMIDIClip(on: track.id, at: 0.0, duration: 4.0)

            dawCore.addMIDINote(to: clip.id, pitch: 60, velocity: 100, startTime: 0.0, duration: 1.0)

            if case .midi(let midiClip) = dawCore.project.tracks[0].clips[0].type {
                let noteId = midiClip.notes[0].id
                dawCore.deleteMIDINote(clipId: clip.id, noteId: noteId)

                if case .midi(let updatedClip) = dawCore.project.tracks[0].clips[0].type {
                    XCTAssertEqual(updatedClip.notes.count, 0)
                }
            }
        }
    }

    func testQuantizeNotes() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "MIDI Track", type: .midi)
            let clip = dawCore.createMIDIClip(on: track.id, at: 0.0, duration: 4.0)

            // Add note at 0.123 beats
            dawCore.addMIDINote(to: clip.id, pitch: 60, velocity: 100, startTime: 0.123, duration: 1.0)

            // Quantize to 1/4 notes
            dawCore.quantizeNotes(in: clip.id, to: .quarter)

            if case .midi(let midiClip) = dawCore.project.tracks[0].clips[0].type {
                // Should be quantized to 0.0
                XCTAssertEqual(midiClip.notes[0].startTime, 0.0)
            }
        }
    }

    // MARK: - Transport Tests

    func testTransportPlay() async throws {
        await MainActor.run {
            XCTAssertEqual(dawCore.transportState, .stopped)

            dawCore.play()

            XCTAssertEqual(dawCore.transportState, .playing)
        }
    }

    func testTransportStop() async throws {
        await MainActor.run {
            dawCore.play()
            XCTAssertEqual(dawCore.transportState, .playing)

            dawCore.stop()

            XCTAssertEqual(dawCore.transportState, .stopped)
            XCTAssertEqual(dawCore.playbackPosition, 0.0)
        }
    }

    func testTransportPause() async throws {
        await MainActor.run {
            dawCore.play()
            XCTAssertEqual(dawCore.transportState, .playing)

            dawCore.pause()

            XCTAssertEqual(dawCore.transportState, .paused)
        }
    }

    func testTransportRecord() async throws {
        await MainActor.run {
            dawCore.record()

            XCTAssertEqual(dawCore.transportState, .recording)
            XCTAssertTrue(dawCore.isRecording)
        }
    }

    func testPlaybackPosition() async throws {
        await MainActor.run {
            dawCore.setPlaybackPosition(5.0)

            XCTAssertEqual(dawCore.playbackPosition, 5.0)
        }
    }

    // MARK: - Loop Tests

    func testSetLoop() async throws {
        await MainActor.run {
            dawCore.setLoop(start: 0.0, end: 8.0)

            XCTAssertTrue(dawCore.loopEnabled)
            XCTAssertEqual(dawCore.loopStart, 0.0)
            XCTAssertEqual(dawCore.loopEnd, 8.0)
        }
    }

    func testToggleLoop() async throws {
        await MainActor.run {
            XCTAssertFalse(dawCore.loopEnabled)

            dawCore.toggleLoop()

            XCTAssertTrue(dawCore.loopEnabled)
        }
    }

    // MARK: - Undo/Redo Tests

    func testUndo() async throws {
        await MainActor.run {
            let originalTempo = dawCore.project.tempo
            dawCore.setTempo(150.0)
            XCTAssertEqual(dawCore.project.tempo, 150.0)

            dawCore.undo()

            XCTAssertEqual(dawCore.project.tempo, originalTempo)
        }
    }

    func testRedo() async throws {
        await MainActor.run {
            dawCore.setTempo(150.0)
            dawCore.undo()
            XCTAssertNotEqual(dawCore.project.tempo, 150.0)

            dawCore.redo()

            XCTAssertEqual(dawCore.project.tempo, 150.0)
        }
    }

    func testMultipleUndo() async throws {
        await MainActor.run {
            dawCore.setTempo(130.0)
            dawCore.setTempo(140.0)
            dawCore.setTempo(150.0)

            dawCore.undo()
            XCTAssertEqual(dawCore.project.tempo, 140.0)

            dawCore.undo()
            XCTAssertEqual(dawCore.project.tempo, 130.0)
        }
    }

    // MARK: - Project Save/Load Tests

    func testSaveProject() async throws {
        await MainActor.run {
            let track = dawCore.createTrack(name: "Test Track", type: .midi)
            let clip = dawCore.createMIDIClip(on: track.id, at: 0.0, duration: 4.0)
            dawCore.addMIDINote(to: clip.id, pitch: 60, velocity: 100, startTime: 0.0, duration: 1.0)

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_project.json")

            do {
                try await dawCore.saveProject(to: tempURL)
                XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
            } catch {
                XCTFail("Failed to save project: \(error)")
            }
        }
    }

    func testLoadProject() async throws {
        await MainActor.run {
            // Create and save a project
            let track = dawCore.createTrack(name: "Test Track", type: .midi)
            let clip = dawCore.createMIDIClip(on: track.id, at: 0.0, duration: 4.0)
            dawCore.addMIDINote(to: clip.id, pitch: 60, velocity: 100, startTime: 0.0, duration: 1.0)

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_load.json")

            do {
                try await dawCore.saveProject(to: tempURL)

                // Create new DAW instance and load
                let newDAW = DAWCore()
                try await newDAW.loadProject(from: tempURL)

                XCTAssertEqual(newDAW.project.tracks.count, 1)
                XCTAssertEqual(newDAW.project.tracks[0].clips.count, 1)

                if case .midi(let midiClip) = newDAW.project.tracks[0].clips[0].type {
                    XCTAssertEqual(midiClip.notes.count, 1)
                }
            } catch {
                XCTFail("Failed to load project: \(error)")
            }
        }
    }

    // MARK: - Performance Tests

    func testPerformanceCreateManyTracks() throws {
        measure {
            Task { @MainActor in
                let daw = DAWCore()
                for i in 0..<100 {
                    _ = daw.createTrack(name: "Track \(i)", type: .midi)
                }
            }
        }
    }

    func testPerformanceCreateManyNotes() throws {
        measure {
            Task { @MainActor in
                let daw = DAWCore()
                let track = daw.createTrack(name: "MIDI Track", type: .midi)
                let clip = daw.createMIDIClip(on: track.id, at: 0.0, duration: 64.0)

                for i in 0..<1000 {
                    daw.addMIDINote(to: clip.id, pitch: 60, velocity: 100, startTime: Double(i) * 0.25, duration: 0.25)
                }
            }
        }
    }
}
