// TenThousandPercentTests.swift
// Echoelmusic - 10000% Ralph Wiggum Loop Mode
//
// Comprehensive tests for 10000% features
// Tests: Orchestral, Streaming, Film Scoring, Logger, Phase 8000 Engines
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import XCTest
@testable import Echoelmusic

final class TenThousandPercentTests: XCTestCase {

    // MARK: - Cinematic Scoring Engine Tests

    func testArticulationTypes() {
        XCTAssertEqual(ArticulationType.allCases.count, 27)
        XCTAssertTrue(ArticulationType.allCases.contains(.legato))
        XCTAssertTrue(ArticulationType.allCases.contains(.spiccato))
        XCTAssertTrue(ArticulationType.allCases.contains(.colLegno))
        XCTAssertTrue(ArticulationType.allCases.contains(.cuivre))
        XCTAssertTrue(ArticulationType.allCases.contains(.flutter))
    }

    func testArticulationAttackTimes() {
        XCTAssertEqual(ArticulationType.legato.attackTime, 0.15, accuracy: 0.01)
        XCTAssertEqual(ArticulationType.staccato.attackTime, 0.02, accuracy: 0.01)
        XCTAssertEqual(ArticulationType.pizzicato.attackTime, 0.005, accuracy: 0.001)
    }

    func testOrchestraSections() {
        XCTAssertEqual(OrchestraSection.allCases.count, 8)
        XCTAssertTrue(OrchestraSection.allCases.contains(.strings))
        XCTAssertTrue(OrchestraSection.allCases.contains(.brass))
        XCTAssertTrue(OrchestraSection.allCases.contains(.woodwinds))
        XCTAssertTrue(OrchestraSection.allCases.contains(.choir))
        XCTAssertTrue(OrchestraSection.allCases.contains(.piano))
        XCTAssertTrue(OrchestraSection.allCases.contains(.harp))
        XCTAssertTrue(OrchestraSection.allCases.contains(.celesta))
    }

    func testSectionMixWeights() {
        XCTAssertEqual(OrchestraSection.strings.defaultMixWeight, 0.35, accuracy: 0.01)
        XCTAssertEqual(OrchestraSection.brass.defaultMixWeight, 0.20, accuracy: 0.01)
        XCTAssertEqual(OrchestraSection.celesta.defaultMixWeight, 0.02, accuracy: 0.01)

        // Total should be approximately 1.0
        let totalWeight = OrchestraSection.allCases.reduce(0) { $0 + $1.defaultMixWeight }
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.01)
    }

    func testInstrumentRanges() {
        // Violin G3 (55) to G7 (103)
        XCTAssertEqual(CinematicConstants.violinRange.lowerBound, 55)
        XCTAssertEqual(CinematicConstants.violinRange.upperBound, 103)

        // Cello C2 (36) to E5 (76)
        XCTAssertEqual(CinematicConstants.celloRange.lowerBound, 36)
        XCTAssertEqual(CinematicConstants.celloRange.upperBound, 76)

        // French Horn transposition
        XCTAssertEqual(CinematicConstants.hornRange.lowerBound, 34)
    }

    func testOrchestraInstrumentCreation() {
        let violin = OrchestraInstrument(
            name: "Test Violin",
            section: .strings,
            range: CinematicConstants.violinRange,
            supportedArticulations: [.legato, .staccato],
            sectionSize: 16
        )

        XCTAssertEqual(violin.name, "Test Violin")
        XCTAssertEqual(violin.section, .strings)
        XCTAssertEqual(violin.sectionSize, 16)
        XCTAssertEqual(violin.transposition, 0)
        XCTAssertTrue(violin.supportedArticulations.contains(.legato))
    }

    func testStagePosition() {
        let position = OrchestraInstrument.StagePosition(x: -0.6, y: 0.3, width: 0.4)

        XCTAssertEqual(position.x, -0.6, accuracy: 0.01)
        XCTAssertEqual(position.y, 0.3, accuracy: 0.01)
        XCTAssertEqual(position.width, 0.4, accuracy: 0.01)
    }

    func testOrchestraVoice() {
        let instrument = OrchestraInstrument(
            name: "Violin",
            section: .strings,
            range: CinematicConstants.violinRange,
            supportedArticulations: [.legato]
        )

        let voice = OrchestraVoice(instrument: instrument, pitch: 69, velocity: 0.8)

        XCTAssertEqual(voice.pitch, 69)  // A4
        XCTAssertEqual(voice.frequency, 440.0, accuracy: 0.1)  // A4 = 440 Hz
        XCTAssertEqual(voice.velocity, 0.8, accuracy: 0.01)
    }

    func testVoicePitchClamping() {
        let instrument = OrchestraInstrument(
            name: "Violin",
            section: .strings,
            range: 55...103,  // Violin range
            supportedArticulations: [.legato]
        )

        // Pitch below range should be clamped
        let lowVoice = OrchestraVoice(instrument: instrument, pitch: 30)
        XCTAssertEqual(lowVoice.pitch, 55)  // Clamped to min

        // Pitch above range should be clamped
        let highVoice = OrchestraVoice(instrument: instrument, pitch: 120)
        XCTAssertEqual(highVoice.pitch, 103)  // Clamped to max
    }

    func testScoreEventTypes() {
        XCTAssertEqual(ScoreEvent.EventType.note.rawValue, "Note")
        XCTAssertEqual(ScoreEvent.EventType.chord.rawValue, "Chord")
        XCTAssertEqual(ScoreEvent.EventType.crescendo.rawValue, "Crescendo")
    }

    func testDynamicMarkings() {
        XCTAssertEqual(ScoreEvent.DynamicMarking.allCases.count, 12)

        // Check velocity ranges
        XCTAssertEqual(ScoreEvent.DynamicMarking.ppp.velocityRange.lowerBound, 0.0, accuracy: 0.01)
        XCTAssertEqual(ScoreEvent.DynamicMarking.fff.velocityRange.upperBound, 1.0, accuracy: 0.01)
        XCTAssertGreaterThan(ScoreEvent.DynamicMarking.f.velocityRange.lowerBound, ScoreEvent.DynamicMarking.p.velocityRange.upperBound)
    }

    func testScoreConfiguration() {
        let config = ScoreConfiguration(title: "Test Score", composer: "Test Composer", tempo: 120, style: .epic)

        XCTAssertEqual(config.title, "Test Score")
        XCTAssertEqual(config.composer, "Test Composer")
        XCTAssertEqual(config.tempo, 120)
        XCTAssertEqual(config.style, .epic)
        XCTAssertEqual(config.timeSignature.numerator, 4)
        XCTAssertEqual(config.timeSignature.denominator, 4)
    }

    func testScoringStyles() {
        XCTAssertEqual(ScoreConfiguration.ScoringStyle.allCases.count, 14)
        XCTAssertTrue(ScoreConfiguration.ScoringStyle.allCases.contains(.animation))  // Disney
        XCTAssertTrue(ScoreConfiguration.ScoringStyle.allCases.contains(.epic))
        XCTAssertTrue(ScoreConfiguration.ScoringStyle.allCases.contains(.cinematic))
    }

    func testScoreMoods() {
        XCTAssertEqual(ScoreConfiguration.ScoreMood.allCases.count, 14)
        XCTAssertTrue(ScoreConfiguration.ScoreMood.allCases.contains(.magical))    // Disney
        XCTAssertTrue(ScoreConfiguration.ScoreMood.allCases.contains(.whimsical))  // Disney
        XCTAssertTrue(ScoreConfiguration.ScoreMood.allCases.contains(.triumphant))
    }

    func testOrchestraSizes() {
        XCTAssertEqual(ScoreConfiguration.OrchestraSize.allCases.count, 5)
        XCTAssertTrue(ScoreConfiguration.OrchestraSize.allCases.contains(.hollywood))
    }

    func testMixPresets() {
        XCTAssertEqual(ScoreConfiguration.MixPreset.allCases.count, 6)
        XCTAssertTrue(ScoreConfiguration.MixPreset.allCases.contains(.tree))  // Decca Tree
        XCTAssertTrue(ScoreConfiguration.MixPreset.allCases.contains(.surround))
    }

    func testReverbTypes() {
        XCTAssertEqual(ScoreConfiguration.ReverbType.allCases.count, 7)
        XCTAssertTrue(ScoreConfiguration.ReverbType.allCases.contains(.airStudios))
        XCTAssertTrue(ScoreConfiguration.ReverbType.allCases.contains(.abbeyRoad))
    }

    // MARK: - Film Score Composer Tests

    func testFilmSceneTypes() {
        XCTAssertEqual(FilmSceneType.allCases.count, 17)
        XCTAssertTrue(FilmSceneType.allCases.contains(.magicalMoment))
        XCTAssertTrue(FilmSceneType.allCases.contains(.wishSequence))
        XCTAssertTrue(FilmSceneType.allCases.contains(.transformationScene))
        XCTAssertTrue(FilmSceneType.allCases.contains(.underwaterWonder))
        XCTAssertTrue(FilmSceneType.allCases.contains(.flyingSequence))
    }

    func testSceneTempos() {
        XCTAssertEqual(FilmSceneType.comedyChase.suggestedTempo, 140)
        XCTAssertEqual(FilmSceneType.battleScene.suggestedTempo, 150)
        XCTAssertEqual(FilmSceneType.emotionalGoodbye.suggestedTempo, 60)
        XCTAssertEqual(FilmSceneType.wishSequence.suggestedTempo, 72)
    }

    func testScenePrimarySections() {
        let magicalSections = FilmSceneType.magicalMoment.primarySections
        XCTAssertTrue(magicalSections.contains(.celesta))
        XCTAssertTrue(magicalSections.contains(.harp))

        let battleSections = FilmSceneType.battleScene.primarySections
        XCTAssertTrue(battleSections.contains(.brass))
        XCTAssertTrue(battleSections.contains(.percussion))
    }

    func testCompositionalTechniques() {
        XCTAssertEqual(CompositionalTechnique.allCases.count, 21)
        XCTAssertTrue(CompositionalTechnique.allCases.contains(.leitmotif))
        XCTAssertTrue(CompositionalTechnique.allCases.contains(.mickeyMousing))
        XCTAssertTrue(CompositionalTechnique.allCases.contains(.waltTime))
        XCTAssertTrue(CompositionalTechnique.allCases.contains(.fanfare))
    }

    func testLeitmotifCreation() {
        let motif = Leitmotif(
            name: "Hero Theme",
            associatedWith: "Protagonist",
            melody: [0, 4, 7, 12],
            rhythm: [1, 0.5, 0.5, 2],
            keyCenter: 60,
            mode: .major
        )

        XCTAssertEqual(motif.name, "Hero Theme")
        XCTAssertEqual(motif.associatedWith, "Protagonist")
        XCTAssertEqual(motif.melody.count, 4)
        XCTAssertEqual(motif.keyCenter, 60)
        XCTAssertEqual(motif.mode, .major)
    }

    func testMusicalModes() {
        XCTAssertEqual(Leitmotif.MusicalMode.allCases.count, 8)
        XCTAssertTrue(Leitmotif.MusicalMode.allCases.contains(.lydian))
        XCTAssertTrue(Leitmotif.MusicalMode.allCases.contains(.phrygian))
    }

    func testHarmonicProgressionStyles() {
        XCTAssertEqual(HarmonicProgression.ProgressionStyle.allCases.count, 9)
        XCTAssertTrue(HarmonicProgression.ProgressionStyle.allCases.contains(.disneyMagic))
        XCTAssertTrue(HarmonicProgression.ProgressionStyle.allCases.contains(.villainTheme))
        XCTAssertTrue(HarmonicProgression.ProgressionStyle.allCases.contains(.whimsicalWaltz))
    }

    func testHarmonicProgressionCreation() {
        let progression = HarmonicProgression(name: "Test", style: .disneyMagic)

        XCTAssertEqual(progression.name, "Test")
        XCTAssertEqual(progression.style, .disneyMagic)
        XCTAssertEqual(progression.chords.count, 4)
    }

    func testChordQualities() {
        XCTAssertEqual(HarmonicProgression.ChordSymbol.ChordQuality.allCases.count, 14)
        XCTAssertTrue(HarmonicProgression.ChordSymbol.ChordQuality.allCases.contains(.major7))
        XCTAssertTrue(HarmonicProgression.ChordSymbol.ChordQuality.allCases.contains(.halfDiminished))
    }

    // MARK: - Professional Streaming Engine Tests

    func testStreamQualities() {
        XCTAssertEqual(StreamQuality.allCases.count, 8)
        XCTAssertTrue(StreamQuality.allCases.contains(.uhd4k))
        XCTAssertTrue(StreamQuality.allCases.contains(.uhd8k))
    }

    func testStreamQualityResolutions() {
        let hd = StreamQuality.hd.resolution
        XCTAssertEqual(hd.width, 1920)
        XCTAssertEqual(hd.height, 1080)

        let uhd4k = StreamQuality.uhd4k.resolution
        XCTAssertEqual(uhd4k.width, 3840)
        XCTAssertEqual(uhd4k.height, 2160)

        let uhd8k = StreamQuality.uhd8k.resolution
        XCTAssertEqual(uhd8k.width, 7680)
        XCTAssertEqual(uhd8k.height, 4320)
    }

    func testStreamQualityBitrates() {
        XCTAssertLessThan(StreamQuality.mobile.bitrate, StreamQuality.standard.bitrate)
        XCTAssertLessThan(StreamQuality.standard.bitrate, StreamQuality.hd.bitrate)
        XCTAssertLessThan(StreamQuality.hd.bitrate, StreamQuality.uhd4k.bitrate)
        XCTAssertEqual(StreamQuality.uhd8k.bitrate, 80_000_000)
    }

    func testStreamProtocols() {
        XCTAssertEqual(StreamProtocol.allCases.count, 6)
        XCTAssertTrue(StreamProtocol.allCases.contains(.rtmp))
        XCTAssertTrue(StreamProtocol.allCases.contains(.rtmps))
        XCTAssertTrue(StreamProtocol.allCases.contains(.webrtc))
        XCTAssertTrue(StreamProtocol.allCases.contains(.srt))
    }

    func testStreamPlatforms() {
        XCTAssertEqual(StreamDestination.StreamPlatform.allCases.count, 6)
        XCTAssertTrue(StreamDestination.StreamPlatform.allCases.contains(.youtube))
        XCTAssertTrue(StreamDestination.StreamPlatform.allCases.contains(.twitch))
        XCTAssertTrue(StreamDestination.StreamPlatform.allCases.contains(.tiktok))
    }

    func testPlatformDefaultURLs() {
        XCTAssertTrue(StreamDestination.StreamPlatform.youtube.defaultUrl.contains("youtube"))
        XCTAssertTrue(StreamDestination.StreamPlatform.twitch.defaultUrl.contains("twitch"))
        XCTAssertTrue(StreamDestination.StreamPlatform.facebook.defaultUrl.contains("facebook"))
    }

    func testStreamDestinationCreation() {
        let destination = StreamDestination(name: "My Stream", platform: .youtube, streamKey: "test-key-123")

        XCTAssertEqual(destination.name, "My Stream")
        XCTAssertEqual(destination.platform, .youtube)
        XCTAssertEqual(destination.streamKey, "test-key-123")
        XCTAssertTrue(destination.isEnabled)
        XCTAssertEqual(destination.protocol, .rtmp)
    }

    func testRTMPHandshakeStates() {
        XCTAssertEqual(RTMPHandshakeState.uninitialized.rawValue, "Uninitialized")
        XCTAssertEqual(RTMPHandshakeState.versionSent.rawValue, "C0 Sent")
        XCTAssertEqual(RTMPHandshakeState.ackSent.rawValue, "C1 Sent")
        XCTAssertEqual(RTMPHandshakeState.handshakeDone.rawValue, "Handshake Complete")
        XCTAssertEqual(RTMPHandshakeState.connected.rawValue, "Connected")
    }

    func testStreamingConstants() {
        XCTAssertEqual(StreamingConstants.rtmpVersion, 3)
        XCTAssertEqual(StreamingConstants.rtmpHandshakeSize, 1536)
        XCTAssertEqual(StreamingConstants.defaultBitrate, 6_000_000)
        XCTAssertEqual(StreamingConstants.audioSampleRate, 48000)
    }

    func testRTMPClientCreation() {
        let client = RTMPClientComplete()

        XCTAssertEqual(client.state, .uninitialized)
        XCTAssertFalse(client.isConnected)
    }

    // MARK: - Professional Logger Tests

    func testLogLevels() {
        XCTAssertEqual(LogLevel.allCases.count, 7)
        XCTAssertLessThan(LogLevel.trace, LogLevel.debug)
        XCTAssertLessThan(LogLevel.debug, LogLevel.info)
        XCTAssertLessThan(LogLevel.warning, LogLevel.error)
        XCTAssertLessThan(LogLevel.error, LogLevel.critical)
    }

    func testLogLevelEmojis() {
        XCTAssertEqual(LogLevel.trace.emoji, "🔍")
        XCTAssertEqual(LogLevel.debug.emoji, "🐛")
        XCTAssertEqual(LogLevel.error.emoji, "❌")
        XCTAssertEqual(LogLevel.critical.emoji, "🚨")
    }

    func testLogCategories() {
        XCTAssertEqual(LogCategory.allCases.count, 16)
        XCTAssertTrue(LogCategory.allCases.contains(.audio))
        XCTAssertTrue(LogCategory.allCases.contains(.orchestral))
        XCTAssertTrue(LogCategory.allCases.contains(.lambda))
        XCTAssertTrue(LogCategory.allCases.contains(.streaming))
        XCTAssertTrue(LogCategory.allCases.contains(.scoring))
    }

    func testLogEntryCreation() {
        let entry = LogEntry(
            level: .info,
            category: .audio,
            message: "Test message",
            file: "TestFile.swift",
            function: "testFunction()",
            line: 42
        )

        XCTAssertEqual(entry.level, .info)
        XCTAssertEqual(entry.category, .audio)
        XCTAssertEqual(entry.message, "Test message")
        XCTAssertEqual(entry.line, 42)
    }

    func testLogEntryFormatting() {
        let entry = LogEntry(
            level: .warning,
            category: .video,
            message: "Frame dropped",
            file: "/path/to/VideoEngine.swift",
            function: "processFrame()",
            line: 100
        )

        let formatted = entry.formattedMessage
        XCTAssertTrue(formatted.contains("⚠️"))
        XCTAssertTrue(formatted.contains("[Video]"))
        XCTAssertTrue(formatted.contains("Frame dropped"))
        XCTAssertTrue(formatted.contains("VideoEngine.swift:100"))
    }

    // MARK: - Expression Controller Tests

    func testExpressionControllers() {
        XCTAssertEqual(ExpressionController.modWheel.rawValue, 1)
        XCTAssertEqual(ExpressionController.expression.rawValue, 11)
        XCTAssertEqual(ExpressionController.brightness.rawValue, 74)
    }

    // MARK: - Constants Tests

    func testCinematicConstants() {
        XCTAssertEqual(CinematicConstants.concertPitch, 440.0, accuracy: 0.1)
        XCTAssertEqual(CinematicConstants.viennaPitch, 443.0, accuracy: 0.1)
        XCTAssertEqual(CinematicConstants.baroquePitch, 415.0, accuracy: 0.1)

        XCTAssertEqual(CinematicConstants.firstViolins, 16)
        XCTAssertEqual(CinematicConstants.cellos, 10)
        XCTAssertEqual(CinematicConstants.basses, 8)
    }

    func testFilmScoreConstants() {
        XCTAssertEqual(FilmScoreConstants.magicalTempo, 92.0, accuracy: 0.1)
        XCTAssertEqual(FilmScoreConstants.adventureTempo, 140.0, accuracy: 0.1)

        // Disney magic intervals should form Maj7 + 9
        XCTAssertEqual(FilmScoreConstants.disneyMagicIntervals, [0, 4, 7, 11, 14])
    }

    // MARK: - Integration Tests

    func testOrchestralVoiceToFrequencyConversion() {
        let instrument = OrchestraInstrument(
            name: "Flute",
            section: .woodwinds,
            range: CinematicConstants.fluteRange,
            supportedArticulations: [.legato]
        )

        // A4 = 440 Hz
        let voiceA4 = OrchestraVoice(instrument: instrument, pitch: 69)
        XCTAssertEqual(voiceA4.frequency, 440.0, accuracy: 0.1)

        // A5 = 880 Hz (one octave up)
        let voiceA5 = OrchestraVoice(instrument: instrument, pitch: 81)
        XCTAssertEqual(voiceA5.frequency, 880.0, accuracy: 0.1)

        // Middle C = ~261.63 Hz
        let voiceC4 = OrchestraVoice(instrument: instrument, pitch: 60)
        XCTAssertEqual(voiceC4.frequency, 261.63, accuracy: 0.5)
    }

    func testProgressionChordCount() {
        for style in HarmonicProgression.ProgressionStyle.allCases {
            let progression = HarmonicProgression(name: "Test", style: style)
            XCTAssertGreaterThan(progression.chords.count, 0, "Style \(style) should have chords")
            XCTAssertLessThanOrEqual(progression.chords.count, 8, "Style \(style) should have reasonable chord count")
        }
    }

    func testSceneTypeHasPrimarySections() {
        for scene in FilmSceneType.allCases {
            XCTAssertFalse(scene.primarySections.isEmpty, "Scene \(scene) should have primary sections")
        }
    }

    // MARK: - Performance Tests

    func testVoiceCreationPerformance() {
        let instrument = OrchestraInstrument(
            name: "Violin",
            section: .strings,
            range: CinematicConstants.violinRange,
            supportedArticulations: [.legato]
        )

        measure {
            for _ in 0..<10000 {
                _ = OrchestraVoice(
                    instrument: instrument,
                    pitch: Int.random(in: 55...103),
                    velocity: Float.random(in: 0...1),
                    duration: Double.random(in: 0.1...4.0)
                )
            }
        }
    }

    func testProgressionCreationPerformance() {
        measure {
            for style in HarmonicProgression.ProgressionStyle.allCases {
                for _ in 0..<100 {
                    _ = HarmonicProgression(name: "Perf Test", style: style)
                }
            }
        }
    }

    func testLogEntryFormattingPerformance() {
        let entry = LogEntry(
            level: .info,
            category: .audio,
            message: "Performance test message",
            file: "TestFile.swift",
            function: "testFunction()",
            line: 42
        )

        measure {
            for _ in 0..<10000 {
                _ = entry.formattedMessage
            }
        }
    }

    // MARK: - Edge Cases

    func testEmptyLeitmotif() {
        let motif = Leitmotif(name: "Empty", associatedWith: "Nothing")

        XCTAssertTrue(motif.melody.isEmpty)
        XCTAssertTrue(motif.rhythm.isEmpty)
    }

    func testExtremeDynamics() {
        let ppp = ScoreEvent.DynamicMarking.ppp.velocityRange
        XCTAssertEqual(ppp.lowerBound, 0.0, accuracy: 0.01)

        let fff = ScoreEvent.DynamicMarking.fff.velocityRange
        XCTAssertEqual(fff.upperBound, 1.0, accuracy: 0.01)
    }

    func testAllSceneTypesHaveTempos() {
        for scene in FilmSceneType.allCases {
            XCTAssertGreaterThan(scene.suggestedTempo, 0)
            XCTAssertLessThan(scene.suggestedTempo, 300)  // Reasonable tempo range
        }
    }

    func testAllStreamQualitiesHaveValidResolutions() {
        for quality in StreamQuality.allCases {
            let res = quality.resolution
            XCTAssertGreaterThan(res.width, 0)
            XCTAssertGreaterThan(res.height, 0)
            XCTAssertLessThanOrEqual(res.width, 7680)  // Max 8K
            XCTAssertLessThanOrEqual(res.height, 4320)
        }
    }
}
