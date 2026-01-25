# Music Theory Module

Global music theory database covering scales, modes, and rhythms from world cultures.

## Overview

The GlobalMusicTheoryDatabase provides comprehensive music theory knowledge from cultures worldwide, enabling culturally-informed music generation and education.

## Cultures Supported

| Culture | Scales | Modes | Rhythms |
|---------|--------|-------|---------|
| Western Classical | Major, Minor, Pentatonic, Blues | Ionian, Dorian, etc. | 4/4, 3/4, 6/8 |
| Indian Classical | Thaats (Bhairav, Kafi, etc.) | Ragas with aroha/avaroha | Talas (Teental) |
| Arabic Maqam | Rast, Hijaz, Bayati | Maqamat with jins | Middle Eastern |
| Chinese Traditional | Gong mode pentatonic | 5 modes | Traditional |
| Japanese Traditional | Hirajoshi, In Sen | Gagaku modes | Taiko patterns |
| African Traditional | African pentatonic | Folk modes | 6/8 bell patterns |
| Indonesian Gamelan | Slendro, Pelog | Gamelan modes | Polyrhythmic |
| Persian Dastgah | Shur, Segah | Gusheh patterns | Persian meters |
| Turkish Makam | Makamlar | Turkish modes | Usul |
| Flamenco | Phrygian Dominant | Flamenco modes | Compás |
| Latin American | Latin scales | Latin modes | Clave patterns |
| Blues & Jazz | Blues scale | Jazz modes | Swing, shuffle |
| Electronic Music | Synthesizer scales | Experimental | 4/4, breakbeat |

## Key Components

### GlobalMusicTheoryDatabase

```swift
let database = GlobalMusicTheoryDatabase()

// Query by culture
let westernScales = database.getScales(forCulture: .western)
let indianModes = database.getModes(forCulture: .indian)
let africanRhythms = database.getRhythms(forCulture: .african)

// Search
let happyScales = database.searchScales(byEmotion: "Happy")
let minorScales = database.searchScales(byName: "Minor")

// Generate report
print(database.generateMusicTheoryReport())
```

### Scale

```swift
struct Scale {
    let name: String
    let culture: MusicCulture
    let intervals: [Float]        // In semitones (supports quarter tones)
    let degrees: Int
    let description: String
    let emotionalCharacter: String
    let typicalInstruments: [String]
    let historicalContext: String

    // Generate MIDI notes
    func generateNotes(root: Int, octaves: Int = 2) -> [Int]
}
```

**Example: C Major**
```swift
// Intervals: 0, 2, 4, 5, 7, 9, 11 (whole, whole, half, whole, whole, whole, half)
scale.generateNotes(root: 60, octaves: 1)  // [60, 62, 64, 65, 67, 69, 71]
```

### Mode

Complex modal systems with cultural-specific data:

**Raga (Indian)**
```swift
struct Raga {
    let name: String
    let thaat: String        // Parent scale
    let melakarta: String?   // Carnatic equivalent
    let aroha: [Int]         // Ascending pattern
    let avaroha: [Int]       // Descending pattern
    let vadi: Int            // Most important note
    let samvadi: Int         // Second important
    let timeOfDay: String
    let season: String
    let rasa: String         // Emotional flavor
}
```

**Maqam (Arabic)**
```swift
struct Maqam {
    let name: String
    let family: String
    let jins: [Jins]         // Tetrachords
    let qarar: Int           // Resting note
    let ghammaz: Int         // Leading note
}
```

**Dastgah (Persian)**
```swift
struct Dastgah {
    let name: String
    let gusheh: [String]     // Melodic patterns
    let shahed: Int          // Important note
    let ista: Int            // Stopping note
}
```

### RhythmPattern

```swift
struct RhythmPattern {
    let name: String
    let culture: MusicCulture
    let timeSignature: String
    let pattern: [RhythmEvent]
    let tempo: ClosedRange<Int>
    let description: String
}

struct RhythmEvent {
    let beat: Float
    let accent: Float    // 0-1
    let duration: Float
    let type: EventType  // .drum, .clap, .rest, .ornament
}
```

## Special Features

### Quarter Tones

Arabic and Persian scales support quarter tones:
```swift
// Maqam Rast intervals (with quarter tones)
[0, 2, 3.5, 5, 7, 9, 10.5]
```

### Non-Equal Temperament

Indonesian gamelan uses non-equal temperament:
```swift
// Slendro (approximately equal 5-tone)
[0.0, 2.4, 4.8, 7.2, 9.6]
```

### Time-Specific Ragas

Indian ragas specify appropriate times:
```swift
raga.timeOfDay  // "Evening (sunset to midnight)"
raga.season     // "All seasons"
```

## Usage Examples

### Generate Scale Notes

```swift
let database = GlobalMusicTheoryDatabase()
let scales = database.getScales(forCulture: .japanese)

if let hirajoshi = scales.first(where: { $0.name.contains("Hirajoshi") }) {
    let notes = hirajoshi.generateNotes(root: 60)  // C4
    playMelody(notes)
}
```

### Find Emotional Matches

```swift
// Find scales matching a mood
let mysteriousScales = database.searchScales(byEmotion: "Mysterious")
let joyfulScales = database.searchScales(byEmotion: "Joyful")
```

### Cross-Cultural Exploration

```swift
// Compare pentatonic scales across cultures
let western = database.getScales(forCulture: .western)
    .filter { $0.name.contains("Pentatonic") }
let chinese = database.getScales(forCulture: .chinese)
let african = database.getScales(forCulture: .african)
```

## Files

| File | Description |
|------|-------------|
| `GlobalMusicTheoryDatabase.swift` | Complete database implementation |

## Data Sources

- Ethnomusicology research (UCLA, SOAS, Smithsonian)
- Grove Music Online
- Traditional conservatories worldwide
- Field recordings & analysis
