// MusicTheoryTests.swift
// Tests for GlobalMusicTheoryDatabase
//
// Copyright 2026 Echoelmusic. MIT License.

import XCTest
@testable import Echoelmusic

/// Comprehensive tests for the Global Music Theory Database
/// Coverage: Scales, modes, rhythms, cultures, queries
final class MusicTheoryTests: XCTestCase {

    // MARK: - Database Initialization Tests

    @MainActor
    func testDatabaseInitialization() {
        let database = GlobalMusicTheoryDatabase()

        // Should have loaded data
        XCTAssertNotNil(database.currentCulture)
        XCTAssertEqual(database.currentCulture, .western)
    }

    // MARK: - Music Culture Tests

    func testMusicCultureCount() {
        let cultures = GlobalMusicTheoryDatabase.MusicCulture.allCases

        // Should have 13 cultures
        XCTAssertEqual(cultures.count, 13)
    }

    func testMusicCultureRawValues() {
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.western.rawValue, "Western Classical")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.indian.rawValue, "Indian Classical")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.arabic.rawValue, "Arabic Maqam")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.chinese.rawValue, "Chinese Traditional")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.japanese.rawValue, "Japanese Traditional")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.african.rawValue, "African Traditional")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.indonesian.rawValue, "Indonesian Gamelan")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.persian.rawValue, "Persian Dastgah")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.turkish.rawValue, "Turkish Makam")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.flamenco.rawValue, "Flamenco")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.latin.rawValue, "Latin American")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.blues.rawValue, "Blues & Jazz")
        XCTAssertEqual(GlobalMusicTheoryDatabase.MusicCulture.electronic.rawValue, "Electronic Music")
    }

    // MARK: - Scale Tests

    @MainActor
    func testWesternScales() {
        let database = GlobalMusicTheoryDatabase()
        let westernScales = database.getScales(forCulture: .western)

        XCTAssertGreaterThan(westernScales.count, 0)

        // Should have major scale
        let majorScale = westernScales.first { $0.name.contains("Major") }
        XCTAssertNotNil(majorScale)
    }

    @MainActor
    func testMajorScaleIntervals() {
        let database = GlobalMusicTheoryDatabase()
        let westernScales = database.getScales(forCulture: .western)

        let majorScale = westernScales.first { $0.name.contains("Major Scale") }
        XCTAssertNotNil(majorScale)

        if let scale = majorScale {
            // Major scale intervals: whole, whole, half, whole, whole, whole, half
            // In semitones: 0, 2, 4, 5, 7, 9, 11
            XCTAssertEqual(scale.intervals[0], 0, accuracy: 0.01)
            XCTAssertEqual(scale.intervals[1], 2, accuracy: 0.01)
            XCTAssertEqual(scale.intervals[2], 4, accuracy: 0.01)
            XCTAssertEqual(scale.intervals[3], 5, accuracy: 0.01)
            XCTAssertEqual(scale.intervals[4], 7, accuracy: 0.01)
            XCTAssertEqual(scale.intervals[5], 9, accuracy: 0.01)
            XCTAssertEqual(scale.intervals[6], 11, accuracy: 0.01)

            XCTAssertEqual(scale.degrees, 7)
        }
    }

    @MainActor
    func testMinorScaleIntervals() {
        let database = GlobalMusicTheoryDatabase()
        let westernScales = database.getScales(forCulture: .western)

        let minorScale = westernScales.first { $0.name.contains("Minor Scale") && $0.name.contains("Aeolian") }
        XCTAssertNotNil(minorScale)

        if let scale = minorScale {
            // Natural minor intervals: 0, 2, 3, 5, 7, 8, 10
            XCTAssertEqual(scale.intervals[0], 0, accuracy: 0.01)
            XCTAssertEqual(scale.intervals[1], 2, accuracy: 0.01)
            XCTAssertEqual(scale.intervals[2], 3, accuracy: 0.01)  // Flat 3rd
            XCTAssertEqual(scale.degrees, 7)
        }
    }

    @MainActor
    func testPentatonicScale() {
        let database = GlobalMusicTheoryDatabase()
        let westernScales = database.getScales(forCulture: .western)

        let pentatonic = westernScales.first { $0.name.contains("Pentatonic Major") }
        XCTAssertNotNil(pentatonic)

        if let scale = pentatonic {
            XCTAssertEqual(scale.degrees, 5)
            XCTAssertEqual(scale.intervals.count, 5)
        }
    }

    @MainActor
    func testBluesScale() {
        let database = GlobalMusicTheoryDatabase()
        let bluesScales = database.getScales(forCulture: .blues)

        XCTAssertGreaterThan(bluesScales.count, 0)

        let bluesScale = bluesScales.first { $0.name.contains("Blues") }
        XCTAssertNotNil(bluesScale)

        if let scale = bluesScale {
            XCTAssertEqual(scale.degrees, 6)  // Minor pentatonic + blue note

            // Should have the blue note (b5)
            XCTAssertTrue(scale.intervals.contains(6), "Blues scale should contain the blue note (b5)")
        }
    }

    @MainActor
    func testIndianScales() {
        let database = GlobalMusicTheoryDatabase()
        let indianScales = database.getScales(forCulture: .indian)

        XCTAssertGreaterThan(indianScales.count, 0)

        // Check for Bhairav thaat
        let bhairav = indianScales.first { $0.name.contains("Bhairav") }
        XCTAssertNotNil(bhairav, "Should have Bhairav thaat")
    }

    @MainActor
    func testArabicScalesWithQuarterTones() {
        let database = GlobalMusicTheoryDatabase()
        let arabicScales = database.getScales(forCulture: .arabic)

        XCTAssertGreaterThan(arabicScales.count, 0)

        // Maqam Rast should have quarter tones
        let rast = arabicScales.first { $0.name.contains("Rast") }
        XCTAssertNotNil(rast)

        if let scale = rast {
            // Check for quarter tone intervals (non-integer values)
            let hasQuarterTone = scale.intervals.contains { interval in
                interval.truncatingRemainder(dividingBy: 1.0) != 0
            }
            XCTAssertTrue(hasQuarterTone, "Maqam Rast should have quarter tones")
        }
    }

    @MainActor
    func testJapaneseScales() {
        let database = GlobalMusicTheoryDatabase()
        let japaneseScales = database.getScales(forCulture: .japanese)

        XCTAssertGreaterThan(japaneseScales.count, 0)

        // Check for Hirajoshi
        let hirajoshi = japaneseScales.first { $0.name.contains("Hirajoshi") }
        XCTAssertNotNil(hirajoshi, "Should have Hirajoshi scale")

        if let scale = hirajoshi {
            XCTAssertEqual(scale.degrees, 5)
        }
    }

    @MainActor
    func testIndonesianGamelanScales() {
        let database = GlobalMusicTheoryDatabase()
        let indonesianScales = database.getScales(forCulture: .indonesian)

        XCTAssertGreaterThan(indonesianScales.count, 0)

        // Check for Slendro and Pelog
        let slendro = indonesianScales.first { $0.name.contains("Slendro") }
        let pelog = indonesianScales.first { $0.name.contains("Pelog") }

        XCTAssertNotNil(slendro, "Should have Slendro scale")
        XCTAssertNotNil(pelog, "Should have Pelog scale")
    }

    // MARK: - Scale Generation Tests

    func testScaleGenerateNotes() {
        let scale = GlobalMusicTheoryDatabase.Scale(
            name: "Test Major",
            culture: .western,
            intervals: [0, 2, 4, 5, 7, 9, 11],
            degrees: 7,
            description: "Test",
            emotionalCharacter: "Test",
            typicalInstruments: ["Piano"],
            historicalContext: "Test"
        )

        // Generate C Major (MIDI note 60 = C4)
        let notes = scale.generateNotes(root: 60, octaves: 1)

        XCTAssertEqual(notes.count, 7)
        XCTAssertEqual(notes[0], 60)  // C
        XCTAssertEqual(notes[1], 62)  // D
        XCTAssertEqual(notes[2], 64)  // E
        XCTAssertEqual(notes[3], 65)  // F
        XCTAssertEqual(notes[4], 67)  // G
        XCTAssertEqual(notes[5], 69)  // A
        XCTAssertEqual(notes[6], 71)  // B
    }

    func testScaleGenerateNotesMultipleOctaves() {
        let scale = GlobalMusicTheoryDatabase.Scale(
            name: "Test Pentatonic",
            culture: .western,
            intervals: [0, 2, 4, 7, 9],
            degrees: 5,
            description: "Test",
            emotionalCharacter: "Test",
            typicalInstruments: ["Piano"],
            historicalContext: "Test"
        )

        let notes = scale.generateNotes(root: 60, octaves: 2)

        // 5 notes × 2 octaves = 10 notes
        XCTAssertEqual(notes.count, 10)

        // Second octave should be 12 semitones higher
        XCTAssertEqual(notes[5], notes[0] + 12)
    }

    func testScaleGenerateNotesHighRoot() {
        let scale = GlobalMusicTheoryDatabase.Scale(
            name: "Test",
            culture: .western,
            intervals: [0, 2, 4, 5, 7, 9, 11],
            degrees: 7,
            description: "Test",
            emotionalCharacter: "Test",
            typicalInstruments: ["Piano"],
            historicalContext: "Test"
        )

        // High root - some notes might exceed MIDI range
        let notes = scale.generateNotes(root: 120, octaves: 2)

        // All notes should be <= 127
        for note in notes {
            XCTAssertLessThanOrEqual(note, 127)
        }
    }

    // MARK: - Mode Tests

    @MainActor
    func testIndianModes() {
        let database = GlobalMusicTheoryDatabase()
        let indianModes = database.getModes(forCulture: .indian)

        XCTAssertGreaterThan(indianModes.count, 0)

        // Check for Raga Yaman
        let yaman = indianModes.first { $0.name.contains("Yaman") }
        XCTAssertNotNil(yaman)

        if let mode = yaman {
            XCTAssertNotNil(mode.raga)

            if let raga = mode.raga {
                XCTAssertEqual(raga.thaat, "Kalyan")
                XCTAssertFalse(raga.timeOfDay.isEmpty)
                XCTAssertFalse(raga.rasa.isEmpty)
            }
        }
    }

    @MainActor
    func testArabicMaqamModes() {
        let database = GlobalMusicTheoryDatabase()
        let arabicModes = database.getModes(forCulture: .arabic)

        // Check for Maqam Bayati
        let bayati = arabicModes.first { $0.name.contains("Bayati") }

        if let mode = bayati {
            XCTAssertNotNil(mode.maqam)

            if let maqam = mode.maqam {
                XCTAssertFalse(maqam.family.isEmpty)
                XCTAssertGreaterThan(maqam.jins.count, 0)
            }
        }
    }

    // MARK: - Raga Tests

    func testRagaStructure() {
        let raga = GlobalMusicTheoryDatabase.Mode.Raga(
            name: "Yaman",
            thaat: "Kalyan",
            melakarta: "Mechakalyani",
            aroha: [0, 2, 4, 6, 7, 9, 11, 12],
            avaroha: [12, 11, 9, 7, 6, 4, 2, 0],
            vadi: 7,
            samvadi: 2,
            timeOfDay: "Evening",
            season: "All",
            rasa: "Shringar"
        )

        XCTAssertEqual(raga.name, "Yaman")
        XCTAssertEqual(raga.thaat, "Kalyan")
        XCTAssertEqual(raga.vadi, 7)  // Pa (5th)
        XCTAssertEqual(raga.samvadi, 2)  // Re (2nd)

        // Aroha should be ascending
        XCTAssertEqual(raga.aroha.first, 0)
        XCTAssertEqual(raga.aroha.last, 12)

        // Avaroha should be descending
        XCTAssertEqual(raga.avaroha.first, 12)
        XCTAssertEqual(raga.avaroha.last, 0)
    }

    // MARK: - Maqam Tests

    func testMaqamJinsStructure() {
        let jins = GlobalMusicTheoryDatabase.Mode.Maqam.Jins(
            name: "Bayati",
            intervals: [0.0, 1.5, 3.0, 5.0],
            startingNote: 0
        )

        XCTAssertEqual(jins.name, "Bayati")
        XCTAssertEqual(jins.intervals.count, 4)  // Tetrachord
        XCTAssertEqual(jins.startingNote, 0)
    }

    // MARK: - Rhythm Pattern Tests

    @MainActor
    func testAfricanRhythms() {
        let database = GlobalMusicTheoryDatabase()
        let africanRhythms = database.getRhythms(forCulture: .african)

        XCTAssertGreaterThan(africanRhythms.count, 0)

        let bellPattern = africanRhythms.first { $0.name.contains("Bell") || $0.name.contains("6/8") }
        XCTAssertNotNil(bellPattern)

        if let pattern = bellPattern {
            XCTAssertEqual(pattern.timeSignature, "6/8")
            XCTAssertGreaterThan(pattern.pattern.count, 0)
        }
    }

    @MainActor
    func testIndianTalas() {
        let database = GlobalMusicTheoryDatabase()
        let indianRhythms = database.getRhythms(forCulture: .indian)

        // Check for Teental
        let teental = indianRhythms.first { $0.name.contains("Teental") }

        if let tala = teental {
            XCTAssertEqual(tala.pattern.count, 16)  // 16 beats
        }
    }

    @MainActor
    func testLatinClaves() {
        let database = GlobalMusicTheoryDatabase()
        let latinRhythms = database.getRhythms(forCulture: .latin)

        XCTAssertGreaterThan(latinRhythms.count, 0)

        let clave = latinRhythms.first { $0.name.contains("Clave") }
        XCTAssertNotNil(clave)
    }

    func testRhythmEventTypes() {
        let types: [GlobalMusicTheoryDatabase.RhythmPattern.RhythmEvent.EventType] = [
            .drum, .clap, .rest, .ornament
        ]

        XCTAssertEqual(types[0].rawValue, "Drum")
        XCTAssertEqual(types[1].rawValue, "Clap")
        XCTAssertEqual(types[2].rawValue, "Rest")
        XCTAssertEqual(types[3].rawValue, "Ornament")
    }

    // MARK: - Query Tests

    @MainActor
    func testSearchScalesByName() {
        let database = GlobalMusicTheoryDatabase()

        let majorScales = database.searchScales(byName: "Major")
        XCTAssertGreaterThan(majorScales.count, 0)

        for scale in majorScales {
            XCTAssertTrue(scale.name.localizedCaseInsensitiveContains("Major"))
        }
    }

    @MainActor
    func testSearchScalesByNameCaseInsensitive() {
        let database = GlobalMusicTheoryDatabase()

        let result1 = database.searchScales(byName: "pentatonic")
        let result2 = database.searchScales(byName: "PENTATONIC")
        let result3 = database.searchScales(byName: "Pentatonic")

        XCTAssertEqual(result1.count, result2.count)
        XCTAssertEqual(result2.count, result3.count)
    }

    @MainActor
    func testSearchScalesByEmotion() {
        let database = GlobalMusicTheoryDatabase()

        let happyScales = database.searchScales(byEmotion: "Happy")
        XCTAssertGreaterThan(happyScales.count, 0)

        let sadScales = database.searchScales(byEmotion: "Sad")
        XCTAssertGreaterThan(sadScales.count, 0)
    }

    @MainActor
    func testSearchScalesByEmotionNoResults() {
        let database = GlobalMusicTheoryDatabase()

        let result = database.searchScales(byEmotion: "NonexistentEmotion12345")
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Report Generation Tests

    @MainActor
    func testGenerateMusicTheoryReport() {
        let database = GlobalMusicTheoryDatabase()
        let report = database.generateMusicTheoryReport()

        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("GLOBAL MUSIC THEORY DATABASE"))
        XCTAssertTrue(report.contains("Total Scales"))
        XCTAssertTrue(report.contains("Total Modes"))
        XCTAssertTrue(report.contains("Total Rhythm Patterns"))
    }

    @MainActor
    func testReportContainsCultures() {
        let database = GlobalMusicTheoryDatabase()
        let report = database.generateMusicTheoryReport()

        // Should mention various cultures
        XCTAssertTrue(report.contains("Western"))
        XCTAssertTrue(report.contains("Arabic") || report.contains("Maqam"))
    }

    @MainActor
    func testReportContainsSpecialFeatures() {
        let database = GlobalMusicTheoryDatabase()
        let report = database.generateMusicTheoryReport()

        // Should mention special features
        XCTAssertTrue(report.contains("Quarter-tone") || report.contains("quarter"))
        XCTAssertTrue(report.contains("Raga") || report.contains("Indian"))
    }

    // MARK: - Scale Properties Tests

    func testScaleHasAllRequiredProperties() {
        let scale = GlobalMusicTheoryDatabase.Scale(
            name: "Test Scale",
            culture: .western,
            intervals: [0, 2, 4, 5, 7, 9, 11],
            degrees: 7,
            description: "A test scale",
            emotionalCharacter: "Neutral",
            typicalInstruments: ["Piano", "Guitar"],
            historicalContext: "Created for testing"
        )

        XCTAssertFalse(scale.name.isEmpty)
        XCTAssertFalse(scale.description.isEmpty)
        XCTAssertFalse(scale.emotionalCharacter.isEmpty)
        XCTAssertGreaterThan(scale.typicalInstruments.count, 0)
        XCTAssertFalse(scale.historicalContext.isEmpty)
        XCTAssertEqual(scale.intervals.count, scale.degrees)
    }

    func testScaleIdentifiable() {
        let scale = GlobalMusicTheoryDatabase.Scale(
            name: "Test",
            culture: .western,
            intervals: [0],
            degrees: 1,
            description: "",
            emotionalCharacter: "",
            typicalInstruments: [],
            historicalContext: ""
        )

        // Should have a unique ID
        XCTAssertNotNil(scale.id)
    }

    // MARK: - Performance Tests

    @MainActor
    func testDatabaseInitializationPerformance() {
        measure {
            let _ = GlobalMusicTheoryDatabase()
        }
    }

    @MainActor
    func testScaleQueryPerformance() {
        let database = GlobalMusicTheoryDatabase()

        measure {
            for _ in 0..<100 {
                let _ = database.getScales(forCulture: .western)
                let _ = database.searchScales(byName: "Major")
                let _ = database.searchScales(byEmotion: "Happy")
            }
        }
    }

    func testScaleGenerationPerformance() {
        let scale = GlobalMusicTheoryDatabase.Scale(
            name: "Test",
            culture: .western,
            intervals: [0, 2, 4, 5, 7, 9, 11],
            degrees: 7,
            description: "",
            emotionalCharacter: "",
            typicalInstruments: [],
            historicalContext: ""
        )

        measure {
            for _ in 0..<1000 {
                let _ = scale.generateNotes(root: 60, octaves: 4)
            }
        }
    }

    // MARK: - Edge Cases

    func testScaleWithSingleNote() {
        let scale = GlobalMusicTheoryDatabase.Scale(
            name: "Single Note",
            culture: .western,
            intervals: [0],
            degrees: 1,
            description: "Test",
            emotionalCharacter: "Test",
            typicalInstruments: [],
            historicalContext: "Test"
        )

        let notes = scale.generateNotes(root: 60, octaves: 1)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0], 60)
    }

    func testScaleWithZeroOctaves() {
        let scale = GlobalMusicTheoryDatabase.Scale(
            name: "Test",
            culture: .western,
            intervals: [0, 2, 4],
            degrees: 3,
            description: "",
            emotionalCharacter: "",
            typicalInstruments: [],
            historicalContext: ""
        )

        let notes = scale.generateNotes(root: 60, octaves: 0)
        XCTAssertEqual(notes.count, 0)
    }

    @MainActor
    func testEmptyCultureQuery() {
        let database = GlobalMusicTheoryDatabase()

        // Electronic music might not have scales defined
        let electronicScales = database.getScales(forCulture: .electronic)

        // Should return empty array, not crash
        XCTAssertNotNil(electronicScales)
    }
}
