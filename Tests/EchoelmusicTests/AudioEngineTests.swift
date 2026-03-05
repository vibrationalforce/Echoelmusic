// AudioEngineTests.swift
// Echoelmusic — Phase 2 Test Coverage: Audio & Infrastructure Tests
//
// Tests for MetronomeSound, MetronomeSubdivision, CountInMode,
// MetronomeConfiguration, TunerReading, MusicalNote extended,
// MemoryPressureLevel, LogLevel, LogCategory, LogEntry,
// SessionState.BioSettings, and EchoelLogger.

import XCTest
@testable import Echoelmusic

// MARK: - MetronomeSound Tests

final class MetronomeSoundTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(MetronomeSound.allCases.count, 7)
    }

    func testDownbeatFrequencies() {
        for sound in MetronomeSound.allCases {
            XCTAssertGreaterThan(sound.downbeatFrequency, 0)
            XCTAssertLessThan(sound.downbeatFrequency, 20000)
        }
    }

    func testUpbeatFrequencies() {
        for sound in MetronomeSound.allCases {
            XCTAssertGreaterThan(sound.upbeatFrequency, 0)
            XCTAssertLessThan(sound.upbeatFrequency, 20000)
        }
    }

    func testDownbeatHigherThanUpbeat() {
        for sound in MetronomeSound.allCases {
            XCTAssertGreaterThanOrEqual(sound.downbeatFrequency, sound.upbeatFrequency,
                                        "\(sound) downbeat should be >= upbeat")
        }
    }

    func testCodable() throws {
        let original = MetronomeSound.cowbell
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetronomeSound.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testRawValues() {
        XCTAssertEqual(MetronomeSound.woodBlock.rawValue, "Wood Block")
        XCTAssertEqual(MetronomeSound.click.rawValue, "Click")
        XCTAssertEqual(MetronomeSound.cowbell.rawValue, "Cowbell")
    }
}

// MARK: - MetronomeSubdivision Tests

final class MetronomeSubdivisionTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(MetronomeSubdivision.allCases.count, 5)
    }

    func testClicksPerBeat() {
        XCTAssertEqual(MetronomeSubdivision.none.clicksPerBeat, 1)
        XCTAssertEqual(MetronomeSubdivision.eighth.clicksPerBeat, 2)
        XCTAssertEqual(MetronomeSubdivision.triplet.clicksPerBeat, 3)
        XCTAssertEqual(MetronomeSubdivision.sixteenth.clicksPerBeat, 4)
        XCTAssertEqual(MetronomeSubdivision.swing.clicksPerBeat, 2)
    }

    func testTimingRatiosStartAtZero() {
        for subdivision in MetronomeSubdivision.allCases {
            XCTAssertEqual(subdivision.timingRatios.first, 0.0,
                           "\(subdivision) should start at 0.0")
        }
    }

    func testTimingRatiosCount() {
        for subdivision in MetronomeSubdivision.allCases {
            XCTAssertEqual(subdivision.timingRatios.count, subdivision.clicksPerBeat,
                           "\(subdivision) timing ratios count should match clicksPerBeat")
        }
    }

    func testTimingRatiosWithinRange() {
        for subdivision in MetronomeSubdivision.allCases {
            for ratio in subdivision.timingRatios {
                XCTAssertGreaterThanOrEqual(ratio, 0.0)
                XCTAssertLessThan(ratio, 1.0)
            }
        }
    }

    func testTimingRatiosAreAscending() {
        for subdivision in MetronomeSubdivision.allCases {
            let ratios = subdivision.timingRatios
            for i in 1..<ratios.count {
                XCTAssertGreaterThan(ratios[i], ratios[i - 1],
                                     "\(subdivision) ratios should be ascending")
            }
        }
    }
}

// MARK: - CountInMode Tests

final class CountInModeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(CountInMode.allCases.count, 4)
    }

    func testBars() {
        XCTAssertEqual(CountInMode.off.bars, 0)
        XCTAssertEqual(CountInMode.oneBar.bars, 1)
        XCTAssertEqual(CountInMode.twoBars.bars, 2)
        XCTAssertEqual(CountInMode.fourBars.bars, 4)
    }

    func testCodable() throws {
        let original = CountInMode.twoBars
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CountInMode.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - MetronomeConfiguration Tests

final class MetronomeConfigurationTests: XCTestCase {

    func testDefaults() {
        let config = MetronomeConfiguration()
        XCTAssertEqual(config.sound, .click)
        XCTAssertEqual(config.subdivision, .none)
        XCTAssertEqual(config.countIn, .oneBar)
        XCTAssertEqual(config.volume, 0.7, accuracy: 0.001)
        XCTAssertTrue(config.accentDownbeat)
        XCTAssertFalse(config.muteDuringPlayback)
        XCTAssertTrue(config.flashOnBeat)
        XCTAssertTrue(config.hapticOnBeat)
        XCTAssertEqual(config.panPosition, 0.0, accuracy: 0.001)
    }

    func testCodable() throws {
        let original = MetronomeConfiguration(
            sound: .cowbell,
            subdivision: .triplet,
            countIn: .fourBars,
            volume: 0.9
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetronomeConfiguration.self, from: encoded)
        XCTAssertEqual(decoded.sound, .cowbell)
        XCTAssertEqual(decoded.subdivision, .triplet)
        XCTAssertEqual(decoded.countIn, .fourBars)
        XCTAssertEqual(decoded.volume, 0.9, accuracy: 0.001)
    }
}

// MARK: - TunerReading Tests

final class TunerReadingTests: XCTestCase {

    func testIsInTuneWithinThreshold() {
        let reading = TunerReading(
            frequency: 440.0,
            note: MusicalNote.fromFrequency(440.0),
            centsOffset: 2.0,
            confidence: 0.9,
            amplitude: 0.5
        )
        XCTAssertTrue(reading.isInTune())
        XCTAssertTrue(reading.isInTune(threshold: 5.0))
    }

    func testIsOutOfTune() {
        let reading = TunerReading(
            frequency: 445.0,
            note: MusicalNote.fromFrequency(445.0),
            centsOffset: 20.0,
            confidence: 0.9,
            amplitude: 0.5
        )
        XCTAssertFalse(reading.isInTune())
    }

    func testLowConfidenceNotInTune() {
        let reading = TunerReading(
            frequency: 440.0,
            note: MusicalNote.fromFrequency(440.0),
            centsOffset: 1.0,
            confidence: 0.3,
            amplitude: 0.5
        )
        XCTAssertFalse(reading.isInTune())
    }

    func testCustomThreshold() {
        let reading = TunerReading(
            frequency: 441.0,
            note: MusicalNote.fromFrequency(441.0),
            centsOffset: 3.0,
            confidence: 0.8,
            amplitude: 0.5
        )
        XCTAssertTrue(reading.isInTune(threshold: 5.0))
        XCTAssertFalse(reading.isInTune(threshold: 2.0))
    }

    func testNegativeCentsOffset() {
        let reading = TunerReading(
            frequency: 438.0,
            note: MusicalNote.fromFrequency(438.0),
            centsOffset: -8.0,
            confidence: 0.9,
            amplitude: 0.5
        )
        XCTAssertFalse(reading.isInTune(threshold: 5.0))
    }
}

// MARK: - MusicalNote Extended Tests

final class MusicalNoteExtendedTests: XCTestCase {

    func testAllChromaticNotes() {
        let expected = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        for (i, name) in expected.enumerated() {
            let midi = 60 + i // C4 = MIDI 60
            let freq = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
            let note = MusicalNote.fromFrequency(freq)
            XCTAssertEqual(note.name, name, "MIDI \(midi) should be \(name)")
            XCTAssertEqual(note.midiNumber, midi)
        }
    }

    func testExtremeHighFrequency() {
        let note = MusicalNote.fromFrequency(4186.0) // C8
        XCTAssertEqual(note.name, "C")
        XCTAssertEqual(note.octave, 8)
    }

    func testExtremeLowFrequency() {
        let note = MusicalNote.fromFrequency(27.5) // A0
        XCTAssertEqual(note.name, "A")
        XCTAssertEqual(note.octave, 0)
    }

    func testDisplayName() {
        let note = MusicalNote.fromFrequency(440.0)
        XCTAssertEqual(note.displayName, "A4")
    }

    func testZeroFrequency() {
        let note = MusicalNote.fromFrequency(0)
        XCTAssertEqual(note.name, "-")
        XCTAssertEqual(note.midiNumber, 0)
    }

    func testNegativeFrequency() {
        let note = MusicalNote.fromFrequency(-100)
        XCTAssertEqual(note.name, "-")
    }

    func test432Reference() {
        let note = MusicalNote.fromFrequency(432.0, referenceA4: 432.0)
        XCTAssertEqual(note.name, "A")
        XCTAssertEqual(note.octave, 4)
        XCTAssertEqual(note.midiNumber, 69)
    }

    func testNoteEquality() {
        let a = MusicalNote.fromFrequency(440.0)
        let b = MusicalNote.fromFrequency(440.0)
        XCTAssertEqual(a, b)
    }

    func testNoteNamesArray() {
        XCTAssertEqual(MusicalNote.noteNames.count, 12)
        XCTAssertEqual(MusicalNote.noteNames.first, "C")
        XCTAssertEqual(MusicalNote.noteNames.last, "B")
    }
}

// MARK: - TuningReference Tests (Extended)

final class TuningReferenceExtendedTests: XCTestCase {

    func testScientific256() {
        // C4 = 256 Hz → A4 = 430.539 Hz
        XCTAssertEqual(TuningReference.scientific256.a4Frequency, 430.539, accuracy: 0.001)
    }

    func testAllReferencesProduceValidA4() {
        for ref in TuningReference.allCases {
            if ref != .custom {
                XCTAssertGreaterThan(ref.a4Frequency, 400)
                XCTAssertLessThan(ref.a4Frequency, 500)
            }
        }
    }
}

// MARK: - MemoryPressureLevel Tests

final class MemoryPressureLevelTests: XCTestCase {

    func testComparable() {
        XCTAssertTrue(MemoryPressureLevel.normal < .warning)
        XCTAssertTrue(MemoryPressureLevel.warning < .critical)
        XCTAssertTrue(MemoryPressureLevel.critical < .terminal)
    }

    func testDescription() {
        XCTAssertEqual(MemoryPressureLevel.normal.description, "Normal")
        XCTAssertEqual(MemoryPressureLevel.warning.description, "Warning")
        XCTAssertEqual(MemoryPressureLevel.critical.description, "Critical")
        XCTAssertEqual(MemoryPressureLevel.terminal.description, "Terminal")
    }

    func testRawValues() {
        XCTAssertEqual(MemoryPressureLevel.normal.rawValue, 0)
        XCTAssertEqual(MemoryPressureLevel.warning.rawValue, 1)
        XCTAssertEqual(MemoryPressureLevel.critical.rawValue, 2)
        XCTAssertEqual(MemoryPressureLevel.terminal.rawValue, 3)
    }
}

// MARK: - LogLevel Tests

final class LogLevelTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(LogLevel.allCases.count, 7)
    }

    func testComparable() {
        XCTAssertTrue(LogLevel.trace < .debug)
        XCTAssertTrue(LogLevel.debug < .info)
        XCTAssertTrue(LogLevel.info < .notice)
        XCTAssertTrue(LogLevel.notice < .warning)
        XCTAssertTrue(LogLevel.warning < .error)
        XCTAssertTrue(LogLevel.error < .critical)
    }

    func testEmoji() {
        for level in LogLevel.allCases {
            XCTAssertFalse(level.emoji.isEmpty, "\(level) should have emoji")
        }
    }

    func testRawValuesAscending() {
        let allCases = LogLevel.allCases
        for i in 1..<allCases.count {
            XCTAssertGreaterThan(allCases[i].rawValue, allCases[i - 1].rawValue)
        }
    }

    func testOsLogType() {
        // Just verify they return valid types without crashing
        for level in LogLevel.allCases {
            _ = level.osLogType
        }
    }
}

// MARK: - LogCategory Tests

final class LogCategoryTests: XCTestCase {

    func testCoreCategories() {
        let categories = LogCategory.allCases.map { $0.rawValue }
        XCTAssertTrue(categories.contains("Audio"))
        XCTAssertTrue(categories.contains("Video"))
        XCTAssertTrue(categories.contains("MIDI"))
        XCTAssertTrue(categories.contains("Biofeedback"))
        XCTAssertTrue(categories.contains("System"))
        XCTAssertTrue(categories.contains("UI"))
        XCTAssertTrue(categories.contains("Performance"))
        XCTAssertTrue(categories.contains("Network"))
    }

    func testOsLog() {
        for category in LogCategory.allCases {
            let osLog = category.osLog
            XCTAssertNotNil(osLog)
        }
    }

    func testTotalCount() {
        // 31 categories defined in ProfessionalLogger.swift
        XCTAssertEqual(LogCategory.allCases.count, 31)
    }
}

// MARK: - LogEntry Tests

final class LogEntryTests: XCTestCase {

    func testFormattedMessage() {
        let entry = LogEntry(
            level: .info,
            category: .audio,
            message: "Test message",
            file: "/path/to/TestFile.swift",
            function: "testFunc",
            line: 42
        )
        let formatted = entry.formattedMessage
        XCTAssertTrue(formatted.contains("Audio"))
        XCTAssertTrue(formatted.contains("Test message"))
        XCTAssertTrue(formatted.contains("TestFile.swift"))
        XCTAssertTrue(formatted.contains("42"))
    }

    func testMetadata() {
        let entry = LogEntry(
            level: .debug,
            category: .system,
            message: "Debug",
            file: "test.swift",
            function: "test",
            line: 1,
            metadata: ["key": "value"]
        )
        XCTAssertEqual(entry.metadata["key"], "value")
    }

    func testUniqueIds() {
        let entry1 = LogEntry(level: .info, category: .audio, message: "a", file: "", function: "", line: 0)
        let entry2 = LogEntry(level: .info, category: .audio, message: "b", file: "", function: "", line: 0)
        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    func testTimestamp() {
        let before = Date()
        let entry = LogEntry(level: .info, category: .system, message: "t", file: "", function: "", line: 0)
        let after = Date()
        XCTAssertGreaterThanOrEqual(entry.timestamp, before)
        XCTAssertLessThanOrEqual(entry.timestamp, after)
    }
}

// MARK: - SessionState.BioSettings Tests

final class SessionStateBioSettingsTests: XCTestCase {

    func testDefaults() {
        let settings = SessionState.BioSettings()
        XCTAssertTrue(settings.enabled)
        XCTAssertEqual(settings.coherenceThreshold, 0.6, accuracy: 0.001)
        XCTAssertEqual(settings.smoothingFactor, 0.3, accuracy: 0.01)
    }

    func testCodable() throws {
        let original = SessionState.BioSettings()
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionState.BioSettings.self, from: encoded)
        XCTAssertEqual(original.enabled, decoded.enabled)
        XCTAssertEqual(original.coherenceThreshold, decoded.coherenceThreshold, accuracy: 0.001)
        XCTAssertEqual(original.smoothingFactor, decoded.smoothingFactor, accuracy: 0.001)
    }
}

// MARK: - SessionState.AudioSettings Tests

final class SessionStateAudioSettingsTests: XCTestCase {

    func testDefaults() {
        let settings = SessionState.AudioSettings()
        XCTAssertEqual(settings.volume, 0.8, accuracy: 0.001)
        XCTAssertEqual(settings.bpm, 120, accuracy: 0.001)
        XCTAssertEqual(settings.carrierFrequency, 440, accuracy: 0.001)
        XCTAssertTrue(settings.toneEnabled)
        XCTAssertEqual(settings.toneFrequency, 10, accuracy: 0.001)
    }
}

// MARK: - EchoelLogger Tests

final class EchoelLoggerTests: XCTestCase {

    func testSharedInstance() {
        let logger = EchoelLogger.shared
        XCTAssertNotNil(logger)
    }

    func testProfessionalLoggerAlias() {
        // ProfessionalLogger is a typealias for EchoelLogger
        let a: ProfessionalLogger = EchoelLogger.shared
        XCTAssertNotNil(a)
    }

    func testGlobalLogAlias() {
        // Global `log` is EchoelLogger.shared
        XCTAssertNotNil(log)
    }

    func testMinimumLevelFiltering() {
        let logger = EchoelLogger.shared
        let originalLevel = logger.minimumLevel
        logger.setMinimumLevel(.warning)
        // Should not crash — trace messages filtered out
        logger.trace("This should be filtered")
        logger.setMinimumLevel(originalLevel)
    }

    func testLogDoesNotCrash() {
        let logger = EchoelLogger.shared
        logger.log(.info, category: .audio, "Test message")
        logger.log(.error, category: .system, "Error test", metadata: ["key": "val"])
        logger.audio("Audio test")
        logger.midi("MIDI test")
        logger.performance("Perf test")
    }
}
