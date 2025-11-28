//
//  GenrePatternLibrary.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  COMPLETE GENRE PATTERN LIBRARY
//  All electronic music genres + bass patterns
//
//  **Genres:**
//  - Deep House, Tech House, Progressive House
//  - Techno, Minimal Techno, Industrial Techno
//  - Drum and Bass, Liquid DnB, Neurofunk
//  - Jungle, Breakbeat
//  - Trap, Future Bass
//  - UK Garage, 2-Step
//  - Dubstep, Riddim
//  - Trance, Psytrance
//  - And many more...
//

import Foundation
import SwiftUI

// MARK: - Genre Pattern Library

@MainActor
class GenrePatternLibrary: ObservableObject {
    static let shared = GenrePatternLibrary()

    // MARK: - Genre Types

    enum ElectronicGenre: String, CaseIterable {
        // House
        case deepHouse = "Deep House"
        case techHouse = "Tech House"
        case progressiveHouse = "Progressive House"
        case acidHouse = "Acid House"
        case chicagoHouse = "Chicago House"
        case futureHouse = "Future House"
        case tropicalHouse = "Tropical House"

        // Techno
        case techno = "Techno"
        case minimalTechno = "Minimal Techno"
        case industrialTechno = "Industrial Techno"
        case detroitTechno = "Detroit Techno"
        case hardTechno = "Hard Techno"
        case melodicTechno = "Melodic Techno"

        // Drum and Bass
        case drumAndBass = "Drum and Bass"
        case liquidDnB = "Liquid DnB"
        case neurofunk = "Neurofunk"
        case jump_up = "Jump Up DnB"

        // Jungle / Breakbeat
        case jungle = "Jungle"
        case breakbeat = "Breakbeat"
        case bigBeat = "Big Beat"

        // Trap / Hip-Hop
        case trap = "Trap"
        case futureBass = "Future Bass"
        case phonk = "Phonk"

        // UK
        case ukGarage = "UK Garage"
        case twoStep = "2-Step"
        case grime = "Grime"

        // Bass Music
        case dubstep = "Dubstep"
        case brostep = "Brostep"
        case riddim = "Riddim"

        // Trance
        case trance = "Trance"
        case psytrance = "Psytrance"
        case upliftingTrance = "Uplifting Trance"

        // Other
        case ambient = "Ambient"
        case downtempo = "Downtempo"
        case lofi = "Lo-Fi"

        var bpmRange: ClosedRange<Int> {
            switch self {
            case .deepHouse, .techHouse: return 120...128
            case .progressiveHouse: return 126...132
            case .acidHouse, .chicagoHouse: return 118...126
            case .futureHouse: return 124...130
            case .tropicalHouse: return 100...115

            case .techno, .detroitTechno: return 125...135
            case .minimalTechno, .melodicTechno: return 120...130
            case .industrialTechno, .hardTechno: return 135...150

            case .drumAndBass, .liquidDnB, .neurofunk, .jump_up: return 170...180
            case .jungle: return 160...180
            case .breakbeat, .bigBeat: return 120...140

            case .trap: return 130...150  // Half-time feel at 65-75
            case .futureBass: return 130...160
            case .phonk: return 130...145

            case .ukGarage, .twoStep: return 130...140
            case .grime: return 140...142

            case .dubstep, .brostep, .riddim: return 140...150

            case .trance, .upliftingTrance: return 136...150
            case .psytrance: return 145...150

            case .ambient: return 60...100
            case .downtempo: return 80...110
            case .lofi: return 70...90
            }
        }

        var category: GenreCategory {
            switch self {
            case .deepHouse, .techHouse, .progressiveHouse, .acidHouse, .chicagoHouse, .futureHouse, .tropicalHouse:
                return .house
            case .techno, .minimalTechno, .industrialTechno, .detroitTechno, .hardTechno, .melodicTechno:
                return .techno
            case .drumAndBass, .liquidDnB, .neurofunk, .jump_up:
                return .dnb
            case .jungle, .breakbeat, .bigBeat:
                return .breaks
            case .trap, .futureBass, .phonk:
                return .trap
            case .ukGarage, .twoStep, .grime:
                return .uk
            case .dubstep, .brostep, .riddim:
                return .dubstep
            case .trance, .psytrance, .upliftingTrance:
                return .trance
            case .ambient, .downtempo, .lofi:
                return .ambient
            }
        }
    }

    enum GenreCategory: String, CaseIterable {
        case house = "House"
        case techno = "Techno"
        case dnb = "Drum & Bass"
        case breaks = "Breaks/Jungle"
        case trap = "Trap/Bass"
        case uk = "UK"
        case dubstep = "Dubstep"
        case trance = "Trance"
        case ambient = "Ambient"
    }

    // MARK: - Drum Pattern

    struct DrumPattern: Identifiable {
        let id = UUID()
        let genre: ElectronicGenre
        let name: String
        let bars: Int
        let stepsPerBar: Int  // Usually 16

        var kick: [DrumStep]
        var snare: [DrumStep]
        var clap: [DrumStep]
        var hihatClosed: [DrumStep]
        var hihatOpen: [DrumStep]
        var ride: [DrumStep]
        var crash: [DrumStep]
        var perc1: [DrumStep]  // Additional percussion
        var perc2: [DrumStep]

        var totalSteps: Int { bars * stepsPerBar }
    }

    struct DrumStep: Identifiable {
        let id = UUID()
        var position: Int     // Step position (0-based)
        var velocity: Int     // 0-127
        var isAccent: Bool
        var probability: Float  // 0-1 for humanization
    }

    // MARK: - Bass Pattern

    struct BassPattern: Identifiable {
        let id = UUID()
        let genre: ElectronicGenre
        let name: String

        var notes: [BassNote]
        var rootNote: Int  // MIDI note
        var scale: Scale
    }

    struct BassNote: Identifiable {
        let id = UUID()
        var position: Int     // Step position
        var duration: Int     // In steps
        var pitch: Int        // MIDI note
        var velocity: Int
        var slide: Bool       // For 303-style
        var accent: Bool
    }

    enum Scale: String, CaseIterable {
        case minor = "Minor"
        case major = "Major"
        case dorian = "Dorian"
        case phrygian = "Phrygian"
        case mixolydian = "Mixolydian"
        case harmonicMinor = "Harmonic Minor"
        case melodicMinor = "Melodic Minor"
        case pentatonicMinor = "Pentatonic Minor"
        case blues = "Blues"

        var intervals: [Int] {
            switch self {
            case .minor: return [0, 2, 3, 5, 7, 8, 10]
            case .major: return [0, 2, 4, 5, 7, 9, 11]
            case .dorian: return [0, 2, 3, 5, 7, 9, 10]
            case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
            case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
            case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
            case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
            case .pentatonicMinor: return [0, 3, 5, 7, 10]
            case .blues: return [0, 3, 5, 6, 7, 10]
            }
        }
    }

    // MARK: - Pattern Storage

    @Published var drumPatterns: [ElectronicGenre: [DrumPattern]] = [:]
    @Published var bassPatterns: [ElectronicGenre: [BassPattern]] = [:]

    // MARK: - Initialization

    private init() {
        loadAllPatterns()
        print("🎵 GenrePatternLibrary initialized")
        print("   \(ElectronicGenre.allCases.count) genres available")
    }

    private func loadAllPatterns() {
        loadHousePatterns()
        loadTechnoPatterns()
        loadDnBPatterns()
        loadJungleBreaksPatterns()
        loadTrapPatterns()
        loadUKPatterns()
        loadDubstepPatterns()
        loadTrancePatterns()
    }

    // MARK: - House Patterns

    private func loadHousePatterns() {
        // Deep House - 4/4, laid back, groovy
        drumPatterns[.deepHouse] = [
            createDeepHousePattern(name: "Classic Deep"),
            createDeepHousePattern(name: "Deep Groove", variation: 1)
        ]

        // Tech House - punchier
        drumPatterns[.techHouse] = [
            createTechHousePattern(name: "Tech Groove"),
            createTechHousePattern(name: "Tech Minimal", variation: 1)
        ]

        // Acid House
        drumPatterns[.acidHouse] = [
            createAcidHousePattern(name: "Acid Classic")
        ]

        bassPatterns[.deepHouse] = [createDeepHouseBass(name: "Deep Sub")]
        bassPatterns[.techHouse] = [createTechHouseBass(name: "Tech Stab")]
        bassPatterns[.acidHouse] = [createAcidBass(name: "303 Acid")]
    }

    private func createDeepHousePattern(name: String, variation: Int = 0) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .deepHouse,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Kick: Four on the floor with subtle variations
        let kickPositions = [0, 4, 8, 12, 16, 20, 24, 28]
        for pos in kickPositions {
            let vel = pos % 16 == 0 ? 120 : 100
            pattern.kick.append(DrumStep(position: pos, velocity: vel, isAccent: pos % 16 == 0, probability: 1.0))
        }

        // Clap/Snare on 2 and 4 (positions 4 and 12)
        pattern.clap.append(DrumStep(position: 4, velocity: 100, isAccent: false, probability: 1.0))
        pattern.clap.append(DrumStep(position: 12, velocity: 105, isAccent: true, probability: 1.0))
        pattern.clap.append(DrumStep(position: 20, velocity: 100, isAccent: false, probability: 1.0))
        pattern.clap.append(DrumStep(position: 28, velocity: 105, isAccent: true, probability: 1.0))

        // Hi-hats: Off-beat (positions 2, 6, 10, 14...)
        for i in stride(from: 2, to: 32, by: 4) {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 80, isAccent: false, probability: 0.95))
        }

        // Open hi-hat on occasional off-beats
        if variation == 0 {
            pattern.hihatOpen.append(DrumStep(position: 6, velocity: 70, isAccent: false, probability: 0.8))
            pattern.hihatOpen.append(DrumStep(position: 22, velocity: 70, isAccent: false, probability: 0.7))
        }

        return pattern
    }

    private func createTechHousePattern(name: String, variation: Int = 0) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .techHouse,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Kick: Four on the floor, punchy
        for pos in stride(from: 0, to: 32, by: 4) {
            pattern.kick.append(DrumStep(position: pos, velocity: 127, isAccent: true, probability: 1.0))
        }

        // Additional kick for groove
        pattern.kick.append(DrumStep(position: 11, velocity: 90, isAccent: false, probability: 0.7))
        pattern.kick.append(DrumStep(position: 27, velocity: 90, isAccent: false, probability: 0.6))

        // Clap
        for pos in [4, 12, 20, 28] {
            pattern.clap.append(DrumStep(position: pos, velocity: 110, isAccent: true, probability: 1.0))
        }

        // Hi-hats: every 8th note
        for i in stride(from: 0, to: 32, by: 2) {
            let vel = i % 4 == 2 ? 90 : 70
            pattern.hihatClosed.append(DrumStep(position: i, velocity: vel, isAccent: i % 4 == 2, probability: 1.0))
        }

        return pattern
    }

    private func createAcidHousePattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .acidHouse,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Classic 808/909 pattern
        for pos in stride(from: 0, to: 32, by: 4) {
            pattern.kick.append(DrumStep(position: pos, velocity: 120, isAccent: true, probability: 1.0))
        }

        // Snare
        for pos in [4, 12, 20, 28] {
            pattern.snare.append(DrumStep(position: pos, velocity: 100, isAccent: false, probability: 1.0))
        }

        // Hi-hats: 16th notes
        for i in 0..<32 {
            let vel = i % 2 == 0 ? 80 : 60
            pattern.hihatClosed.append(DrumStep(position: i, velocity: vel, isAccent: i % 4 == 0, probability: 0.9))
        }

        return pattern
    }

    // MARK: - Techno Patterns

    private func loadTechnoPatterns() {
        drumPatterns[.techno] = [
            createTechnoPattern(name: "Berlin Techno"),
            createTechnoPattern(name: "Warehouse", variation: 1)
        ]

        drumPatterns[.minimalTechno] = [
            createMinimalTechnoPattern(name: "Minimal Groove")
        ]

        drumPatterns[.industrialTechno] = [
            createIndustrialTechnoPattern(name: "Industrial Pound")
        ]

        bassPatterns[.techno] = [createTechnoBass(name: "Techno Sub")]
    }

    private func createTechnoPattern(name: String, variation: Int = 0) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .techno,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Hard kick on every beat
        for pos in stride(from: 0, to: 32, by: 4) {
            pattern.kick.append(DrumStep(position: pos, velocity: 127, isAccent: true, probability: 1.0))
        }

        // Off-beat kick for drive
        pattern.kick.append(DrumStep(position: 10, velocity: 100, isAccent: false, probability: 0.8))
        pattern.kick.append(DrumStep(position: 26, velocity: 100, isAccent: false, probability: 0.8))

        // Clap on 2 and 4
        for pos in [4, 12, 20, 28] {
            pattern.clap.append(DrumStep(position: pos, velocity: 115, isAccent: true, probability: 1.0))
        }

        // Closed hi-hats: 16th notes
        for i in 0..<32 {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 70 + (i % 2) * 20, isAccent: false, probability: 1.0))
        }

        // Open hi-hat on off-beats
        for pos in [6, 14, 22, 30] {
            pattern.hihatOpen.append(DrumStep(position: pos, velocity: 80, isAccent: false, probability: 0.9))
        }

        return pattern
    }

    private func createMinimalTechnoPattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .minimalTechno,
            name: name,
            bars: 4,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Sparse kick
        for pos in stride(from: 0, to: 64, by: 8) {
            pattern.kick.append(DrumStep(position: pos, velocity: 120, isAccent: true, probability: 1.0))
        }
        pattern.kick.append(DrumStep(position: 22, velocity: 90, isAccent: false, probability: 0.6))

        // Minimal hi-hats
        for i in stride(from: 2, to: 64, by: 4) {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 60, isAccent: false, probability: 0.8))
        }

        return pattern
    }

    private func createIndustrialTechnoPattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .industrialTechno,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Pounding kick
        for pos in stride(from: 0, to: 32, by: 4) {
            pattern.kick.append(DrumStep(position: pos, velocity: 127, isAccent: true, probability: 1.0))
        }
        // Ghost kicks
        for pos in [2, 10, 18, 26] {
            pattern.kick.append(DrumStep(position: pos, velocity: 80, isAccent: false, probability: 0.7))
        }

        // Hard snare
        for pos in [4, 12, 20, 28] {
            pattern.snare.append(DrumStep(position: pos, velocity: 127, isAccent: true, probability: 1.0))
        }

        // Metallic hi-hats
        for i in 0..<32 {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 100, isAccent: i % 4 == 0, probability: 1.0))
        }

        return pattern
    }

    // MARK: - Drum and Bass Patterns

    private func loadDnBPatterns() {
        drumPatterns[.drumAndBass] = [
            createDnBPattern(name: "Classic Amen"),
            createDnBPattern(name: "Two-Step DnB", variation: 1)
        ]

        drumPatterns[.liquidDnB] = [
            createLiquidDnBPattern(name: "Liquid Roller")
        ]

        drumPatterns[.neurofunk] = [
            createNeurofunkPattern(name: "Neuro Tech")
        ]

        bassPatterns[.drumAndBass] = [createDnBBass(name: "Reese Bass")]
    }

    private func createDnBPattern(name: String, variation: Int = 0) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .drumAndBass,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // DnB kick pattern (syncopated)
        pattern.kick.append(DrumStep(position: 0, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 10, velocity: 110, isAccent: false, probability: 1.0))
        pattern.kick.append(DrumStep(position: 16, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 26, velocity: 110, isAccent: false, probability: 1.0))

        // Snare on 2 and 4 (but at 170 BPM these are half-time)
        pattern.snare.append(DrumStep(position: 4, velocity: 120, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 12, velocity: 120, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 20, velocity: 120, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 28, velocity: 120, isAccent: true, probability: 1.0))

        // Ghost snares
        pattern.snare.append(DrumStep(position: 7, velocity: 60, isAccent: false, probability: 0.6))
        pattern.snare.append(DrumStep(position: 23, velocity: 60, isAccent: false, probability: 0.5))

        // Fast hi-hats
        for i in 0..<32 {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 70 + (i % 2) * 15, isAccent: false, probability: 0.95))
        }

        return pattern
    }

    private func createLiquidDnBPattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .liquidDnB,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Softer, more flowing kick
        pattern.kick.append(DrumStep(position: 0, velocity: 110, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 10, velocity: 90, isAccent: false, probability: 0.9))
        pattern.kick.append(DrumStep(position: 16, velocity: 110, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 26, velocity: 90, isAccent: false, probability: 0.8))

        // Snare with fills
        for pos in [4, 12, 20, 28] {
            pattern.snare.append(DrumStep(position: pos, velocity: 100, isAccent: true, probability: 1.0))
        }

        // Ride cymbal for liquid feel
        for i in stride(from: 0, to: 32, by: 2) {
            pattern.ride.append(DrumStep(position: i, velocity: 60, isAccent: false, probability: 0.9))
        }

        return pattern
    }

    private func createNeurofunkPattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .neurofunk,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Aggressive kick
        pattern.kick.append(DrumStep(position: 0, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 6, velocity: 100, isAccent: false, probability: 0.8))
        pattern.kick.append(DrumStep(position: 10, velocity: 120, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 16, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 22, velocity: 100, isAccent: false, probability: 0.7))
        pattern.kick.append(DrumStep(position: 26, velocity: 120, isAccent: true, probability: 1.0))

        // Hard snare
        for pos in [4, 12, 20, 28] {
            pattern.snare.append(DrumStep(position: pos, velocity: 127, isAccent: true, probability: 1.0))
        }

        // Fast hi-hats with variations
        for i in 0..<32 {
            let vel = 60 + Int.random(in: 0...30)
            pattern.hihatClosed.append(DrumStep(position: i, velocity: vel, isAccent: false, probability: 0.9))
        }

        return pattern
    }

    // MARK: - Jungle / Breakbeat Patterns

    private func loadJungleBreaksPatterns() {
        drumPatterns[.jungle] = [
            createJunglePattern(name: "Amen Break"),
            createJunglePattern(name: "Think Break", variation: 1)
        ]

        drumPatterns[.breakbeat] = [
            createBreakbeatPattern(name: "Funky Breaks")
        ]

        bassPatterns[.jungle] = [createJungleBass(name: "Sub Pressure")]
    }

    private func createJunglePattern(name: String, variation: Int = 0) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .jungle,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Amen-style pattern (chopped)
        // Kick
        pattern.kick.append(DrumStep(position: 0, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 6, velocity: 90, isAccent: false, probability: 0.9))
        pattern.kick.append(DrumStep(position: 10, velocity: 100, isAccent: false, probability: 1.0))
        pattern.kick.append(DrumStep(position: 16, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 22, velocity: 90, isAccent: false, probability: 0.85))
        pattern.kick.append(DrumStep(position: 26, velocity: 100, isAccent: false, probability: 1.0))

        // Snare with ghost notes (essential for jungle)
        pattern.snare.append(DrumStep(position: 4, velocity: 120, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 7, velocity: 50, isAccent: false, probability: 0.7))  // Ghost
        pattern.snare.append(DrumStep(position: 12, velocity: 120, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 15, velocity: 60, isAccent: false, probability: 0.6))  // Ghost
        pattern.snare.append(DrumStep(position: 20, velocity: 120, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 23, velocity: 50, isAccent: false, probability: 0.7))  // Ghost
        pattern.snare.append(DrumStep(position: 28, velocity: 120, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 31, velocity: 60, isAccent: false, probability: 0.5))  // Ghost

        // Ride pattern
        for i in stride(from: 0, to: 32, by: 2) {
            pattern.ride.append(DrumStep(position: i, velocity: 80, isAccent: i % 4 == 0, probability: 0.95))
        }

        return pattern
    }

    private func createBreakbeatPattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .breakbeat,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Funky breakbeat
        pattern.kick.append(DrumStep(position: 0, velocity: 120, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 7, velocity: 100, isAccent: false, probability: 1.0))
        pattern.kick.append(DrumStep(position: 10, velocity: 90, isAccent: false, probability: 0.8))
        pattern.kick.append(DrumStep(position: 16, velocity: 120, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 23, velocity: 100, isAccent: false, probability: 1.0))

        // Snare
        for pos in [4, 12, 20, 28] {
            pattern.snare.append(DrumStep(position: pos, velocity: 110, isAccent: true, probability: 1.0))
        }

        // Hi-hats
        for i in 0..<32 {
            if i % 2 == 0 {
                pattern.hihatClosed.append(DrumStep(position: i, velocity: 80, isAccent: false, probability: 1.0))
            }
        }

        return pattern
    }

    // MARK: - Trap Patterns

    private func loadTrapPatterns() {
        drumPatterns[.trap] = [
            createTrapPattern(name: "Classic Trap"),
            createTrapPattern(name: "Hard Trap", variation: 1)
        ]

        drumPatterns[.futureBass] = [
            createFutureBassPattern(name: "Future Vibes")
        ]

        bassPatterns[.trap] = [createTrap808Bass(name: "808 Sub")]
    }

    private func createTrapPattern(name: String, variation: Int = 0) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .trap,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // 808 kick (long sustain notes)
        pattern.kick.append(DrumStep(position: 0, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 14, velocity: 110, isAccent: false, probability: 0.8))
        pattern.kick.append(DrumStep(position: 16, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 24, velocity: 100, isAccent: false, probability: 0.7))
        pattern.kick.append(DrumStep(position: 30, velocity: 110, isAccent: false, probability: 0.9))

        // Snare on 3 (half-time feel)
        pattern.snare.append(DrumStep(position: 8, velocity: 120, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 24, velocity: 120, isAccent: true, probability: 1.0))

        // Trap hi-hats (rolling, triplet feel)
        // Main hits
        for i in 0..<32 {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 80, isAccent: i % 4 == 0, probability: 1.0))
        }

        // Hi-hat rolls (triplets within steps)
        pattern.hihatClosed.append(DrumStep(position: 6, velocity: 70, isAccent: false, probability: 0.9))
        pattern.hihatClosed.append(DrumStep(position: 22, velocity: 70, isAccent: false, probability: 0.85))

        return pattern
    }

    private func createFutureBassPattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .futureBass,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Sidechain-friendly kick
        pattern.kick.append(DrumStep(position: 0, velocity: 120, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 16, velocity: 120, isAccent: true, probability: 1.0))

        // Snare/clap on 2 and 4 (half-time)
        pattern.clap.append(DrumStep(position: 8, velocity: 110, isAccent: true, probability: 1.0))
        pattern.clap.append(DrumStep(position: 24, velocity: 110, isAccent: true, probability: 1.0))

        // Hi-hats
        for i in stride(from: 0, to: 32, by: 2) {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 70, isAccent: false, probability: 0.95))
        }

        return pattern
    }

    // MARK: - UK Patterns

    private func loadUKPatterns() {
        drumPatterns[.ukGarage] = [
            createUKGaragePattern(name: "Garage Shuffle")
        ]

        drumPatterns[.twoStep] = [
            create2StepPattern(name: "Classic 2-Step")
        ]

        drumPatterns[.grime] = [
            createGrimePattern(name: "Grime Riddim")
        ]

        bassPatterns[.ukGarage] = [createUKBass(name: "Garage Sub")]
    }

    private func createUKGaragePattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .ukGarage,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Shuffled kick
        pattern.kick.append(DrumStep(position: 0, velocity: 120, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 7, velocity: 100, isAccent: false, probability: 0.9))
        pattern.kick.append(DrumStep(position: 16, velocity: 120, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 23, velocity: 100, isAccent: false, probability: 0.85))

        // Snare
        for pos in [4, 12, 20, 28] {
            pattern.snare.append(DrumStep(position: pos, velocity: 100, isAccent: true, probability: 1.0))
        }

        // Shuffled hi-hats
        for i in 0..<32 {
            let vel = 60 + (i % 3 == 0 ? 20 : 0)
            pattern.hihatClosed.append(DrumStep(position: i, velocity: vel, isAccent: false, probability: 0.9))
        }

        return pattern
    }

    private func create2StepPattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .twoStep,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // 2-step skip kick (characteristic missing first kick)
        pattern.kick.append(DrumStep(position: 4, velocity: 110, isAccent: false, probability: 1.0))
        pattern.kick.append(DrumStep(position: 10, velocity: 120, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 20, velocity: 110, isAccent: false, probability: 1.0))
        pattern.kick.append(DrumStep(position: 26, velocity: 120, isAccent: true, probability: 1.0))

        // Snare
        for pos in [8, 24] {
            pattern.snare.append(DrumStep(position: pos, velocity: 100, isAccent: true, probability: 1.0))
        }

        // Hi-hats
        for i in stride(from: 2, to: 32, by: 2) {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 70, isAccent: false, probability: 0.95))
        }

        return pattern
    }

    private func createGrimePattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .grime,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Grime kick (hard, syncopated)
        pattern.kick.append(DrumStep(position: 0, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 6, velocity: 100, isAccent: false, probability: 0.9))
        pattern.kick.append(DrumStep(position: 11, velocity: 110, isAccent: false, probability: 1.0))
        pattern.kick.append(DrumStep(position: 16, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 22, velocity: 100, isAccent: false, probability: 0.85))
        pattern.kick.append(DrumStep(position: 27, velocity: 110, isAccent: false, probability: 1.0))

        // Snare
        for pos in [4, 12, 20, 28] {
            pattern.snare.append(DrumStep(position: pos, velocity: 120, isAccent: true, probability: 1.0))
        }

        // Hi-hats
        for i in 0..<32 {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 80, isAccent: i % 4 == 0, probability: 1.0))
        }

        return pattern
    }

    // MARK: - Dubstep Patterns

    private func loadDubstepPatterns() {
        drumPatterns[.dubstep] = [
            createDubstepPattern(name: "Half-Time Dub")
        ]

        drumPatterns[.riddim] = [
            createRiddimPattern(name: "Riddim Bounce")
        ]

        bassPatterns[.dubstep] = [createDubstepBass(name: "Wobble Bass")]
    }

    private func createDubstepPattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .dubstep,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Half-time kick
        pattern.kick.append(DrumStep(position: 0, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 16, velocity: 127, isAccent: true, probability: 1.0))

        // Snare on 3 (half-time)
        pattern.snare.append(DrumStep(position: 8, velocity: 127, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 24, velocity: 127, isAccent: true, probability: 1.0))

        // Hi-hats
        for i in stride(from: 0, to: 32, by: 2) {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 70, isAccent: false, probability: 0.9))
        }

        return pattern
    }

    private func createRiddimPattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .riddim,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Bouncy kick
        pattern.kick.append(DrumStep(position: 0, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 4, velocity: 100, isAccent: false, probability: 0.7))
        pattern.kick.append(DrumStep(position: 16, velocity: 127, isAccent: true, probability: 1.0))
        pattern.kick.append(DrumStep(position: 20, velocity: 100, isAccent: false, probability: 0.7))

        // Snare
        pattern.snare.append(DrumStep(position: 8, velocity: 120, isAccent: true, probability: 1.0))
        pattern.snare.append(DrumStep(position: 24, velocity: 120, isAccent: true, probability: 1.0))

        // Hi-hats (minimal)
        for i in stride(from: 2, to: 32, by: 4) {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 60, isAccent: false, probability: 0.8))
        }

        return pattern
    }

    // MARK: - Trance Patterns

    private func loadTrancePatterns() {
        drumPatterns[.trance] = [
            createTrancePattern(name: "Classic Trance")
        ]

        drumPatterns[.psytrance] = [
            createPsytrancePattern(name: "Psy Rolling")
        ]

        bassPatterns[.trance] = [createTranceBass(name: "Trance Bass")]
        bassPatterns[.psytrance] = [createPsyBass(name: "Psy Bass")]
    }

    private func createTrancePattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .trance,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Four on the floor
        for pos in stride(from: 0, to: 32, by: 4) {
            pattern.kick.append(DrumStep(position: pos, velocity: 127, isAccent: true, probability: 1.0))
        }

        // Clap
        for pos in [4, 12, 20, 28] {
            pattern.clap.append(DrumStep(position: pos, velocity: 100, isAccent: true, probability: 1.0))
        }

        // Off-beat hi-hats
        for i in stride(from: 2, to: 32, by: 4) {
            pattern.hihatOpen.append(DrumStep(position: i, velocity: 80, isAccent: false, probability: 1.0))
        }

        return pattern
    }

    private func createPsytrancePattern(name: String) -> DrumPattern {
        var pattern = DrumPattern(
            genre: .psytrance,
            name: name,
            bars: 2,
            stepsPerBar: 16,
            kick: [],
            snare: [],
            clap: [],
            hihatClosed: [],
            hihatOpen: [],
            ride: [],
            crash: [],
            perc1: [],
            perc2: []
        )

        // Rolling kick
        for pos in stride(from: 0, to: 32, by: 4) {
            pattern.kick.append(DrumStep(position: pos, velocity: 127, isAccent: true, probability: 1.0))
        }
        // Off-beat kicks for rolling feel
        for pos in stride(from: 2, to: 32, by: 4) {
            pattern.kick.append(DrumStep(position: pos, velocity: 90, isAccent: false, probability: 0.9))
        }

        // Hi-hats
        for i in 0..<32 {
            pattern.hihatClosed.append(DrumStep(position: i, velocity: 60, isAccent: i % 4 == 0, probability: 1.0))
        }

        return pattern
    }

    // MARK: - Bass Pattern Helpers

    private func createDeepHouseBass(name: String) -> BassPattern {
        BassPattern(
            genre: .deepHouse,
            name: name,
            notes: [
                BassNote(position: 0, duration: 4, pitch: 36, velocity: 100, slide: false, accent: true),
                BassNote(position: 8, duration: 2, pitch: 36, velocity: 80, slide: false, accent: false),
                BassNote(position: 12, duration: 2, pitch: 38, velocity: 90, slide: true, accent: false)
            ],
            rootNote: 36,
            scale: .minor
        )
    }

    private func createTechHouseBass(name: String) -> BassPattern {
        BassPattern(genre: .techHouse, name: name, notes: [], rootNote: 36, scale: .minor)
    }

    private func createAcidBass(name: String) -> BassPattern {
        BassPattern(
            genre: .acidHouse,
            name: name,
            notes: [
                BassNote(position: 0, duration: 2, pitch: 36, velocity: 120, slide: false, accent: true),
                BassNote(position: 2, duration: 2, pitch: 36, velocity: 80, slide: false, accent: false),
                BassNote(position: 4, duration: 2, pitch: 38, velocity: 100, slide: true, accent: false),
                BassNote(position: 6, duration: 2, pitch: 41, velocity: 110, slide: true, accent: true),
                BassNote(position: 8, duration: 2, pitch: 36, velocity: 100, slide: false, accent: false),
                BassNote(position: 10, duration: 2, pitch: 36, velocity: 70, slide: false, accent: false),
                BassNote(position: 12, duration: 4, pitch: 43, velocity: 120, slide: true, accent: true)
            ],
            rootNote: 36,
            scale: .minor
        )
    }

    private func createTechnoBass(name: String) -> BassPattern {
        BassPattern(genre: .techno, name: name, notes: [], rootNote: 36, scale: .minor)
    }

    private func createDnBBass(name: String) -> BassPattern {
        BassPattern(genre: .drumAndBass, name: name, notes: [], rootNote: 36, scale: .minor)
    }

    private func createJungleBass(name: String) -> BassPattern {
        BassPattern(genre: .jungle, name: name, notes: [], rootNote: 36, scale: .minor)
    }

    private func createTrap808Bass(name: String) -> BassPattern {
        BassPattern(
            genre: .trap,
            name: name,
            notes: [
                BassNote(position: 0, duration: 8, pitch: 36, velocity: 127, slide: false, accent: true),
                BassNote(position: 14, duration: 6, pitch: 34, velocity: 110, slide: true, accent: false),
                BassNote(position: 24, duration: 4, pitch: 36, velocity: 120, slide: false, accent: true),
                BassNote(position: 30, duration: 2, pitch: 38, velocity: 100, slide: true, accent: false)
            ],
            rootNote: 36,
            scale: .minor
        )
    }

    private func createUKBass(name: String) -> BassPattern {
        BassPattern(genre: .ukGarage, name: name, notes: [], rootNote: 36, scale: .minor)
    }

    private func createDubstepBass(name: String) -> BassPattern {
        BassPattern(genre: .dubstep, name: name, notes: [], rootNote: 36, scale: .minor)
    }

    private func createTranceBass(name: String) -> BassPattern {
        BassPattern(genre: .trance, name: name, notes: [], rootNote: 36, scale: .minor)
    }

    private func createPsyBass(name: String) -> BassPattern {
        BassPattern(genre: .psytrance, name: name, notes: [], rootNote: 36, scale: .minor)
    }

    // MARK: - Query Methods

    func getPattern(for genre: ElectronicGenre) -> DrumPattern? {
        return drumPatterns[genre]?.first
    }

    func getBassPattern(for genre: ElectronicGenre) -> BassPattern? {
        return bassPatterns[genre]?.first
    }

    func getAllGenres(in category: GenreCategory) -> [ElectronicGenre] {
        return ElectronicGenre.allCases.filter { $0.category == category }
    }
}

// MARK: - Debug

#if DEBUG
extension GenrePatternLibrary {
    func testPatterns() {
        print("🧪 Testing GenrePatternLibrary...")

        for category in GenreCategory.allCases {
            let genres = getAllGenres(in: category)
            print("\n\(category.rawValue) (\(genres.count) genres):")
            for genre in genres {
                let hasPattern = getPattern(for: genre) != nil
                let hasBass = getBassPattern(for: genre) != nil
                print("  • \(genre.rawValue): Drums=\(hasPattern ? "✅" : "❌") Bass=\(hasBass ? "✅" : "❌") BPM=\(genre.bpmRange)")
            }
        }

        print("\n✅ GenrePatternLibrary test complete")
    }
}
#endif
