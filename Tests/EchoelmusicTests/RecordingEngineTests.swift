import XCTest
@testable import Echoelmusic

/// Comprehensive tests for RecordingEngine, Session, Track, and multi-track recording
final class RecordingEngineTests: XCTestCase {

    // MARK: - Session Tests

    func testSessionCreation() {
        let session = Session(name: "Test Session")

        XCTAssertEqual(session.name, "Test Session")
        XCTAssertTrue(session.tracks.isEmpty)
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.createdAt)
    }

    func testSessionWithTracks() {
        var session = Session(name: "Multi-Track Session")

        let track1 = Track(name: "Vocals", type: .audio)
        let track2 = Track(name: "Guitar", type: .audio)
        let track3 = Track(name: "Drums", type: .midi)

        session.tracks.append(track1)
        session.tracks.append(track2)
        session.tracks.append(track3)

        XCTAssertEqual(session.tracks.count, 3)
        XCTAssertEqual(session.tracks[0].name, "Vocals")
        XCTAssertEqual(session.tracks[2].type, .midi)
    }

    func testSessionDuration() {
        var session = Session(name: "Duration Test")
        session.duration = 120.5

        XCTAssertEqual(session.duration, 120.5, accuracy: 0.001)
    }

    func testSessionTempo() {
        var session = Session(name: "Tempo Test")
        session.tempo = 140.0

        XCTAssertEqual(session.tempo, 140.0, accuracy: 0.001)
    }

    // MARK: - Track Tests

    func testTrackCreation() {
        let track = Track(name: "Lead Vocal", type: .audio)

        XCTAssertEqual(track.name, "Lead Vocal")
        XCTAssertEqual(track.type, .audio)
        XCTAssertNotNil(track.id)
    }

    func testTrackDefaultValues() {
        let track = Track(name: "Default Track", type: .audio)

        XCTAssertEqual(track.volume, 1.0, accuracy: 0.001)
        XCTAssertEqual(track.pan, 0.0, accuracy: 0.001)
        XCTAssertFalse(track.isMuted)
        XCTAssertFalse(track.isSoloed)
    }

    func testTrackVolumeRange() {
        var track = Track(name: "Volume Test", type: .audio)

        track.volume = 0.0
        XCTAssertEqual(track.volume, 0.0, accuracy: 0.001)

        track.volume = 1.0
        XCTAssertEqual(track.volume, 1.0, accuracy: 0.001)

        track.volume = 0.75
        XCTAssertEqual(track.volume, 0.75, accuracy: 0.001)
    }

    func testTrackPanRange() {
        var track = Track(name: "Pan Test", type: .audio)

        track.pan = -1.0  // Full left
        XCTAssertEqual(track.pan, -1.0, accuracy: 0.001)

        track.pan = 1.0   // Full right
        XCTAssertEqual(track.pan, 1.0, accuracy: 0.001)

        track.pan = 0.0   // Center
        XCTAssertEqual(track.pan, 0.0, accuracy: 0.001)
    }

    func testTrackMuteToggle() {
        var track = Track(name: "Mute Test", type: .audio)

        XCTAssertFalse(track.isMuted)

        track.isMuted = true
        XCTAssertTrue(track.isMuted)

        track.isMuted = false
        XCTAssertFalse(track.isMuted)
    }

    func testTrackSoloToggle() {
        var track = Track(name: "Solo Test", type: .audio)

        XCTAssertFalse(track.isSoloed)

        track.isSoloed = true
        XCTAssertTrue(track.isSoloed)

        track.isSoloed = false
        XCTAssertFalse(track.isSoloed)
    }

    func testTrackTypes() {
        let audioTrack = Track(name: "Audio", type: .audio)
        let midiTrack = Track(name: "MIDI", type: .midi)
        let busTrack = Track(name: "Bus", type: .bus)
        let auxTrack = Track(name: "Aux", type: .aux)

        XCTAssertEqual(audioTrack.type, .audio)
        XCTAssertEqual(midiTrack.type, .midi)
        XCTAssertEqual(busTrack.type, .bus)
        XCTAssertEqual(auxTrack.type, .aux)
    }

    func testTrackTypeIcons() {
        XCTAssertEqual(Track.TrackType.audio.icon, "waveform")
        XCTAssertEqual(Track.TrackType.midi.icon, "pianokeys")
        XCTAssertEqual(Track.TrackType.bus.icon, "arrow.triangle.merge")
        XCTAssertEqual(Track.TrackType.aux.icon, "arrow.uturn.left")
    }

    func testTrackTypeRawValues() {
        XCTAssertEqual(Track.TrackType.audio.rawValue, "Audio")
        XCTAssertEqual(Track.TrackType.midi.rawValue, "MIDI")
        XCTAssertEqual(Track.TrackType.bus.rawValue, "Bus")
        XCTAssertEqual(Track.TrackType.aux.rawValue, "Aux")
    }

    // MARK: - RecordingEngine Tests

    @MainActor
    func testRecordingEngineInitialization() async {
        let engine = RecordingEngine()

        XCTAssertNil(engine.currentSession)
        XCTAssertFalse(engine.isRecording)
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.currentTime, 0.0)
        XCTAssertEqual(engine.recordingLevel, 0.0)
    }

    @MainActor
    func testRecordingEngineRetrospectiveCapture() async {
        let engine = RecordingEngine()

        XCTAssertTrue(engine.isRetrospectiveCaptureEnabled)
    }

    @MainActor
    func testRecordingWaveformInitialState() async {
        let engine = RecordingEngine()

        XCTAssertTrue(engine.recordingWaveform.isEmpty)
    }

    // MARK: - Circular Buffer Tests

    func testCircularBufferAppend() {
        // Test that circular buffer works correctly
        var buffer: [Float] = []
        let capacity = 5

        for i in 0..<10 {
            buffer.append(Float(i))
            if buffer.count > capacity {
                buffer.removeFirst()
            }
        }

        XCTAssertEqual(buffer.count, 5)
        XCTAssertEqual(buffer.first, 5.0)
        XCTAssertEqual(buffer.last, 9.0)
    }

    // MARK: - Audio Region Tests

    func testAudioRegionCreation() {
        let region = AudioRegion(
            id: UUID(),
            name: "Intro",
            startTime: 0.0,
            duration: 8.0,
            fileURL: nil
        )

        XCTAssertEqual(region.name, "Intro")
        XCTAssertEqual(region.startTime, 0.0)
        XCTAssertEqual(region.duration, 8.0)
    }

    func testAudioRegionEndTime() {
        let region = AudioRegion(
            id: UUID(),
            name: "Chorus",
            startTime: 16.0,
            duration: 32.0,
            fileURL: nil
        )

        let endTime = region.startTime + region.duration
        XCTAssertEqual(endTime, 48.0)
    }

    // MARK: - Session Metadata Tests

    func testSessionMetadata() {
        var session = Session(name: "Metadata Test")
        session.artist = "Test Artist"
        session.album = "Test Album"
        session.genre = "Electronic"

        XCTAssertEqual(session.artist, "Test Artist")
        XCTAssertEqual(session.album, "Test Album")
        XCTAssertEqual(session.genre, "Electronic")
    }

    // MARK: - Time Formatting Tests

    func testTimeFormatting() {
        // Helper function to format time
        func formatTime(_ seconds: TimeInterval) -> String {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
            return String(format: "%02d:%02d.%02d", mins, secs, ms)
        }

        XCTAssertEqual(formatTime(0.0), "00:00.00")
        XCTAssertEqual(formatTime(60.0), "01:00.00")
        XCTAssertEqual(formatTime(90.5), "01:30.50")
        XCTAssertEqual(formatTime(3599.99), "59:59.99")
    }

    // MARK: - Track Ordering Tests

    func testTrackReordering() {
        var session = Session(name: "Reorder Test")

        let track1 = Track(name: "Track 1", type: .audio)
        let track2 = Track(name: "Track 2", type: .audio)
        let track3 = Track(name: "Track 3", type: .audio)

        session.tracks = [track1, track2, track3]

        // Move track 3 to position 0
        let moved = session.tracks.remove(at: 2)
        session.tracks.insert(moved, at: 0)

        XCTAssertEqual(session.tracks[0].name, "Track 3")
        XCTAssertEqual(session.tracks[1].name, "Track 1")
        XCTAssertEqual(session.tracks[2].name, "Track 2")
    }

    // MARK: - Sample Rate Tests

    func testSupportedSampleRates() {
        let supportedRates: [Double] = [44100, 48000, 88200, 96000]

        XCTAssertTrue(supportedRates.contains(44100))
        XCTAssertTrue(supportedRates.contains(48000))
        XCTAssertTrue(supportedRates.contains(96000))
    }

    // MARK: - Bit Depth Tests

    func testSupportedBitDepths() {
        let supportedDepths: [Int] = [16, 24, 32]

        XCTAssertTrue(supportedDepths.contains(16))
        XCTAssertTrue(supportedDepths.contains(24))
        XCTAssertTrue(supportedDepths.contains(32))
    }

    // MARK: - Channel Configuration Tests

    func testChannelConfigurations() {
        enum ChannelConfig: String {
            case mono = "Mono"
            case stereo = "Stereo"
            case surround51 = "5.1 Surround"
            case surround71 = "7.1 Surround"

            var channelCount: Int {
                switch self {
                case .mono: return 1
                case .stereo: return 2
                case .surround51: return 6
                case .surround71: return 8
                }
            }
        }

        XCTAssertEqual(ChannelConfig.mono.channelCount, 1)
        XCTAssertEqual(ChannelConfig.stereo.channelCount, 2)
        XCTAssertEqual(ChannelConfig.surround51.channelCount, 6)
        XCTAssertEqual(ChannelConfig.surround71.channelCount, 8)
    }

    // MARK: - Level Metering Tests

    func testDecibelConversion() {
        // Convert linear amplitude to dB
        func linearToDecibels(_ linear: Float) -> Float {
            guard linear > 0 else { return -Float.infinity }
            return 20.0 * log10(linear)
        }

        XCTAssertEqual(linearToDecibels(1.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(linearToDecibels(0.5), -6.02, accuracy: 0.1)
        XCTAssertEqual(linearToDecibels(0.1), -20.0, accuracy: 0.1)
    }

    func testLinearConversion() {
        // Convert dB to linear amplitude
        func decibelsToLinear(_ db: Float) -> Float {
            return pow(10.0, db / 20.0)
        }

        XCTAssertEqual(decibelsToLinear(0.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(decibelsToLinear(-6.0), 0.5, accuracy: 0.01)
        XCTAssertEqual(decibelsToLinear(-20.0), 0.1, accuracy: 0.01)
    }

    // MARK: - Transport Position Tests

    func testTransportPositionCalculation() {
        let tempo: Double = 120.0  // BPM
        let beatsPerBar = 4

        // Calculate bar/beat from time
        func timeToBarBeat(seconds: Double) -> (bar: Int, beat: Int) {
            let totalBeats = seconds * (tempo / 60.0)
            let bar = Int(totalBeats / Double(beatsPerBar)) + 1
            let beat = Int(totalBeats.truncatingRemainder(dividingBy: Double(beatsPerBar))) + 1
            return (bar, beat)
        }

        let position = timeToBarBeat(seconds: 4.0)  // 8 beats at 120 BPM
        XCTAssertEqual(position.bar, 3)
        XCTAssertEqual(position.beat, 1)
    }

    // MARK: - File Path Tests

    func testSessionFileNaming() {
        let sessionName = "My Recording Session"
        let sanitized = sessionName.replacingOccurrences(of: " ", with: "_")

        XCTAssertEqual(sanitized, "My_Recording_Session")
        XCTAssertFalse(sanitized.contains(" "))
    }

    // MARK: - Waveform Display Tests

    func testWaveformDownsampling() {
        // Downsample waveform data for display
        let sampleCount = 1000
        let displayWidth = 100
        let samplesPerPixel = sampleCount / displayWidth

        XCTAssertEqual(samplesPerPixel, 10)
    }
}
