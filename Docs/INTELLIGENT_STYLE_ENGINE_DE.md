# Intelligent Style Engine - SUPER INTELLIGENCE MODE 🚀
## Echoelmusic IntelligentStyleEngine - Deutsche Anleitung

> **NEU:** Genre-basiertes Processing + Dolby Atmos Standard + Stufenlose Loudness + Zip-Import mit gemischten Qualitäten!

---

## ✨ Was ist neu?

### 1. **.ZIP Import mit gemischten Qualitäten** ✅
- Verschiedene Bit-Tiefen (16/24/32-bit) in einem .zip
- Verschiedene Sample-Raten (44.1/48/96/192kHz) gemischt
- Beliebige Ordnerstrukturen
- Auto-Organisation nach Qualität

### 2. **Dolby Atmos als Standard** ✅
- Alle Samples werden automatisch für Dolby Atmos optimiert!
- -18 LUFS Target (Atmos-Standard)
- 4dB Headroom für Spatial-Encoding
- Optimierte Stereo-Breite für Atmos
- Compliance-Check

### 3. **Stufenlose Loudness mit Anzeige** ✅
- Dolby Atmos (-18 LUFS) → Club Mix (-6 LUFS)
- Live-Anzeige: Current LUFS, Target, True Peak, Headroom
- 5 Presets: Atmos, Streaming, Broadcast, Production, Club
- Custom Target möglich

### 4. **Genre-basiertes Processing** ✅ (statt einzelner Producer!)
- **User-Friendly Genres:** Trap, Hip-Hop, Techno, House, Dubstep, Ambient, Experimental
- **Einstellbare Parameter:** Bass, Stereo Width, Atmosphere, Warmth, Punch, Brightness
- **Auto-Detection:** Genre, BPM, Key, Instrument automatisch erkennen

### 5. **Super Intelligence Mode** ✅
- Volle Auto-Detection
- Intelligente Parameter-Anpassung
- Best-of-all-Worlds Processing

---

## 🎯 Deine Fragen beantwortet

### ❓ "Sind die WAV files okay, wenn sie verschiedene Qualitäten haben?"
✅ **JA!** Der IntelligentStyleEngine handhabt:
- 16-bit / 44.1kHz (CD-Qualität)
- 24-bit / 48kHz (Broadcast)
- 24-bit / 96kHz (Studio)
- 32-bit / 96kHz (Mastering)
- 32-bit / 192kHz (Audiophile)

**ALLE in einem .zip!** Das System erkennt automatisch jede Qualität und verarbeitet optimal.

### ❓ "Verschiedene Ordner in einer komprimierten .zip?"
✅ **JA!** Beliebige Ordnerstruktur ist okay:
```
samples.zip
├── Kicks/
│   ├── 808_kick_24bit_96khz.wav
│   └── acoustic_kick_16bit_44khz.wav
├── Snares/
│   └── snare_32bit_192khz.wav
└── Random Folder/
    └── hihat_24bit_48khz.wav
```

Der Engine findet alle .wav Dateien rekursiv und importiert sie!

### ❓ "Dolby Atmos Standard?"
✅ **JA!** Alle Samples werden standardmäßig für Dolby Atmos optimiert:
- Target: -18 LUFS (Atmos-Standard)
- True Peak: < -2 dBTP
- Dynamic Range: >= 10 dB (wichtig für Atmos!)
- Optimale Stereo-Breite (nicht zu weit für Atmos)
- 4dB Headroom für Spatial-Encoding

### ❓ "Stufenlos von Atmos bis Club-Mix mit Anzeige?"
✅ **JA!** Stufenlose Loudness-Einstellung:

| Target | LUFS | Verwendung |
|--------|------|------------|
| **Dolby Atmos** | -18 LUFS | Spatial Audio (Standard!) |
| **Streaming** | -14 LUFS | Spotify, Apple Music |
| **Broadcast** | -23 LUFS | TV, Radio (EBU R128) |
| **Production** | -10 LUFS | Moderne Musikproduktion |
| **Club** | -6 LUFS | Maximum Impact! |
| **Custom** | Frei wählbar | Dein eigener Wert |

**Mit Live-Anzeige:**
- Current LUFS
- Target LUFS
- True Peak
- Dynamic Range
- Headroom
- Quality Rating

### ❓ "Genre statt Producer für User?"
✅ **JA!** Viel benutzerfreundlicher:

**Vorher (Producer-Namen):**
- "Southside / 808 Mafia" ← Was ist das?
- "Andrey Pushkarev" ← Wer?

**Jetzt (Genres):**
- "Trap" ← Klar!
- "Techno" ← Verständlich!

**Mit einstellbaren Parametern:**
- Bass Amount (0-100%)
- Stereo Width (0-100%)
- Atmosphere (0-100%)
- Warmth (0-100%)
- Punch (0-100%)
- Brightness (0-100%)

---

## 🚀 Quick Start

### 1. .Zip mit gemischten Qualitäten importieren

```cpp
#include "IntelligentStyleEngine.h"

IntelligentStyleEngine engine;

// .zip importieren (beliebige Struktur + Qualitäten)
auto result = engine.importFromZip(
    juce::File("/path/to/my_samples.zip"),
    juce::File("/path/to/extract/"));

// Statistik
DBG("Total files: " << result.totalFiles);
DBG("Imported: " << result.imported);
DBG("16-bit files: " << result.files16bit);
DBG("24-bit files: " << result.files24bit);
DBG("32-bit files: " << result.files32bit);
DBG("96kHz files: " << result.files96khz);
DBG("192kHz files: " << result.files192khz);

// Qualitäts-Info pro Datei
for (const auto& quality : result.fileQualities)
{
    DBG(quality.file.getFileName() << ": " <<
        quality.bitDepth << "-bit, " <<
        quality.sampleRate << "Hz - " <<
        quality.qualityRating);
}
```

### 2. Genre-basiert verarbeiten mit Dolby Atmos

```cpp
// Config erstellen
GenreProcessingConfig config;
config.genre = MusicGenre::Trap;

// Parameter einstellen (0.0 - 1.0)
config.bassAmount = 0.8f;           // 80% Bass
config.stereoWidth = 0.7f;          // 70% Stereo Width
config.atmosphereAmount = 0.5f;     // 50% Atmosphere
config.warmthAmount = 0.6f;         // 60% Warmth
config.punchAmount = 0.7f;          // 70% Punch
config.brightnessAmount = 0.6f;     // 60% Brightness

// Dolby Atmos: STANDARD (automatisch an!)
config.optimizeForAtmos = true;     // ✅ Standard!

// Loudness: Atmos-Standard
config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::DolbyAtmos);

// Sample verarbeiten
auto audio = styleProcessor.loadHighResAudio(file);
auto result = engine.processIntelligent(audio, config);

// Ergebnis
DBG("LUFS: " << result.lufs);
DBG("Atmos Compliant: " << (result.atmosCompliant ? "YES" : "NO"));
DBG("Atmos Rating: " << result.atmosRating);
DBG("Atmos Headroom: " << result.atmosHeadroom << " dB");
```

### 3. Stufenlose Loudness (Atmos → Club)

```cpp
// Live Loudness Meter
auto meterData = engine.getLoudnessMeterData(
    audio,
    48000.0,
    LoudnessTarget::DolbyAtmos);

DBG("Current LUFS: " << meterData.currentLUFS);
DBG("Target LUFS: " << meterData.targetLUFS);
DBG("True Peak: " << meterData.truePeak << " dBTP");
DBG("Headroom: " << meterData.headroom << " dB");
DBG("Dynamic Range: " << meterData.dynamicRange << " dB");
DBG("Target: " << meterData.targetName);

// Loudness anpassen (stufenlos!)
LoudnessSpec spec;
spec.targetLUFS = -10.0f;  // Zwischen Atmos (-18) und Club (-6)
spec.truePeakMax = -1.0f;
spec.preserveDynamics = true;

auto adjusted = engine.adjustLoudnessWithFeedback(audio, 48000.0, spec);

DBG("Input LUFS: " << adjusted.inputLUFS);
DBG("Output LUFS: " << adjusted.outputLUFS);
DBG("Gain Applied: " << adjusted.gainApplied << " dB");
DBG("True Peak: " << adjusted.truePeak << " dBTP");
DBG("Dynamic Range: " << adjusted.dynamicRange << " dB");
DBG("Quality: " << adjusted.quality);  // "Excellent", "Good", "Over-processed"
```

---

## 🎛️ Alle Genres

### TRAP
**Charakteristik:**
- Heavy 808 Bass
- Wide Stereo
- Modern, clean sound
- Moderate Compression

**Empfohlene Einstellungen:**
- Bass: 80%
- Stereo Width: 70%
- Atmosphere: 30%
- Warmth: 40%
- Punch: 60%
- Brightness: 70%

**Loudness:** Streaming (-14 LUFS)

### HIP-HOP
**Charakteristik:**
- Punchy Drums
- Analog Warmth
- Moderate Bass
- Classic Vibe

**Empfohlene Einstellungen:**
- Bass: 60%
- Stereo Width: 40%
- Atmosphere: 20%
- Warmth: 70%
- Punch: 70%
- Brightness: 50%

**Loudness:** Streaming (-14 LUFS)

### TECHNO
**Charakteristik:**
- Deep Bass
- Atmospheric
- Analog Character
- Spatial Depth

**Empfohlene Einstellungen:**
- Bass: 70%
- Stereo Width: 60%
- Atmosphere: 70%
- Warmth: 70%
- Punch: 50%
- Brightness: 40%

**Loudness:** Club (-6 LUFS)

### HOUSE
**Charakteristik:**
- Groovy, Organic
- Warm, Vintage
- Moderate Compression
- Musical

**Empfohlene Einstellungen:**
- Bass: 60%
- Stereo Width: 50%
- Atmosphere: 40%
- Warmth: 70%
- Punch: 50%
- Brightness: 60%

**Loudness:** Streaming (-14 LUFS)

### DUBSTEP
**Charakteristik:**
- HEAVY Sub Bass
- Wide Stereo
- Aggressive Processing
- Wobbles/Modulation

**Empfohlene Einstellungen:**
- Bass: 90%
- Stereo Width: 80%
- Atmosphere: 40%
- Warmth: 60%
- Punch: 80%
- Brightness: 60%

**Loudness:** Club (-6 LUFS)

### AMBIENT
**Charakteristik:**
- Huge Reverb/Space
- Minimal Compression
- Wide Stereo
- Atmospheric

**Empfohlene Einstellungen:**
- Bass: 30%
- Stereo Width: 90%
- Atmosphere: 90%
- Warmth: 50%
- Punch: 20%
- Brightness: 70%

**Loudness:** Dolby Atmos (-18 LUFS)

### EXPERIMENTAL
**Charakteristik:**
- Granular Processing
- Bit Crushing
- Creative Effects
- Unique Character

**Empfohlene Einstellungen:**
- Bass: 50%
- Stereo Width: 80%
- Atmosphere: 60%
- Warmth: 70%
- Punch: 60%
- Brightness: 60%

**Loudness:** Streaming (-14 LUFS)

---

## 🤖 Super Intelligence Mode (Full Auto!)

```cpp
// FULL AUTO: Alles automatisch!
auto result = engine.processFullAuto(audio, 48000.0);

// Was wird auto-detected:
DBG("Detected Genre: " << result.detectedGenre);
DBG("Detected Key: " << result.detectedKey);       // "A minor"
DBG("Detected BPM: " << result.detectedBPM);        // 128.0
DBG("Detected Instrument: " << result.detectedInstrument);  // "Kick"

// Processing wird automatisch angepasst!
// Loudness wird optimal gesetzt
// Dolby Atmos wird optimiert
```

**Oder mit Custom Config + Auto-Detection:**

```cpp
GenreProcessingConfig config;
config.genre = MusicGenre::EchoelIntelligent;  // Auto-detect!
config.autoDetectGenre = true;
config.autoDetectKey = true;
config.autoDetectBPM = true;
config.autoDetectInstrument = true;

// Custom Parameter trotzdem einstellen
config.bassAmount = 0.7f;
config.stereoWidth = 0.6f;

auto result = engine.processIntelligent(audio, config);
```

---

## 🎯 Kompletter Workflow: .zip → Process → Atmos

```cpp
// ========== SCHRITT 1: .ZIP IMPORT ==========
IntelligentStyleEngine engine;

// Deine .zip mit gemischten Qualitäten + Ordnern
auto zipResult = engine.importFromZip(
    juce::File("/path/to/my_samples.zip"),
    juce::File("/path/to/extracted/"));

DBG("✅ Imported " << zipResult.imported << " samples");
DBG("   16-bit: " << zipResult.files16bit);
DBG("   24-bit: " << zipResult.files24bit);
DBG("   32-bit: " << zipResult.files32bit);

// ========== SCHRITT 2: GENRE-PROCESSING ==========
GenreProcessingConfig config;
config.genre = MusicGenre::Trap;

// Parameter (wie Knöpfe auf nem Hardware-Gerät!)
config.bassAmount = 0.8f;
config.stereoWidth = 0.7f;
config.atmosphereAmount = 0.5f;
config.warmthAmount = 0.6f;
config.punchAmount = 0.7f;
config.brightnessAmount = 0.6f;

// Dolby Atmos: Standard!
config.optimizeForAtmos = true;

// Loudness: Stufenlos wählbar
config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::DolbyAtmos);
// Oder Custom:
// config.loudness.targetLUFS = -12.0f;  // Zwischen Atmos und Club

// ========== SCHRITT 3: BATCH PROCESSING ==========
auto results = engine.processBatch(zipResult.importedFiles, config);

// ========== SCHRITT 4: ATMOS COMPLIANCE CHECK ==========
for (const auto& result : results)
{
    DBG("Sample: " << result.audio.getNumSamples());
    DBG("  LUFS: " << result.lufs);
    DBG("  Peak: " << result.peakDB << " dB");
    DBG("  True Peak: " << result.truePeakDB << " dBTP");
    DBG("  Dynamic Range: " << result.dynamicRange << " dB");
    DBG("  Atmos Compliant: " << (result.atmosCompliant ? "✅ YES" : "❌ NO"));
    DBG("  Atmos Rating: " << result.atmosRating);
    DBG("  Atmos Headroom: " << result.atmosHeadroom << " dB");

    if (result.atmosCompliant)
    {
        DBG("  ✅ Ready for Dolby Atmos!");
    }
    else
    {
        DBG("  ⚠️ Needs adjustment for Atmos");

        // Auto-fix Atmos issues
        auto atmosCheck = engine.checkAtmosCompliance(result.audio, 48000.0);
        auto fixed = engine.fixAtmosIssues(result.audio, atmosCheck);

        DBG("  ✅ Fixed! Now Atmos-compliant.");
    }
}

// ========== SCHRITT 5: EXPORT ==========
for (int i = 0; i < results.size(); ++i)
{
    auto outputFile = juce::File("/path/to/output/" +
                                zipResult.importedFiles[i].getFileNameWithoutExtension() +
                                "_echoelmusic_atmos.wav");

    styleProcessor.exportForEngine(results[i].audio, outputFile);

    DBG("✅ Exported: " << outputFile.getFileName());
}

// FERTIG! 🎉
// - Alle Samples aus .zip importiert (gemischte Qualitäten)
// - Mit Genre-Processing bearbeitet
// - Für Dolby Atmos optimiert
// - Loudness perfekt eingestellt
// - Ready for Echoelmusic!
```

---

## 📊 Loudness Targets im Detail

### Dolby Atmos (-18 LUFS)
**Verwendung:** Spatial Audio, Immersive Content

**Specs:**
- Target LUFS: -18
- True Peak Max: -2 dBTP
- Dynamic Range Min: 12 dB
- Preserve Dynamics: YES

**Wichtig:**
- Viel Headroom für Spatial-Encoding!
- Hohe Dynamic Range = bessere Atmos-Qualität
- Stereo-Breite wird optimiert (nicht zu weit)

**Wann verwenden:**
- Dolby Atmos Music
- Apple Spatial Audio
- Immersive Content
- Echoelmusic Standard! ✨

### Streaming (-14 LUFS)
**Verwendung:** Spotify, Apple Music, YouTube Music

**Specs:**
- Target LUFS: -14
- True Peak Max: -1 dBTP
- Dynamic Range Min: 8 dB
- Preserve Dynamics: YES

**Wann verwenden:**
- Musik-Releases
- Online-Distribution
- Streaming-Plattformen

### Broadcast (-23 LUFS)
**Verwendung:** TV, Radio, EBU R128 Standard

**Specs:**
- Target LUFS: -23
- True Peak Max: -1 dBTP
- Dynamic Range Min: 10 dB
- Preserve Dynamics: YES

**Wann verwenden:**
- TV-Produktionen
- Radio
- Broadcast-Content

### Music Production (-10 LUFS)
**Verwendung:** Moderne Musikproduktion

**Specs:**
- Target LUFS: -10
- True Peak Max: -1 dBTP
- Dynamic Range Min: 6 dB
- Preserve Dynamics: YES

**Wann verwenden:**
- Commercial Releases
- Pop/Rock/Electronic
- Wettbewerbsfähige Lautheit

### Club Mix (-6 LUFS)
**Verwendung:** Maximum Impact, DJ-Sets, Club-Systeme

**Specs:**
- Target LUFS: -6
- True Peak Max: -0.5 dBTP
- Dynamic Range Min: 4 dB
- Preserve Dynamics: NO (mehr Compression)

**Wann verwenden:**
- DJ-Sets
- Club-Sound-Systeme
- Festival-Playback
- Maximum Loudness!

**WARNUNG:** Nicht für Streaming geeignet! Spotify/Apple normalisieren runter.

---

## 🎚️ UI Slider Konzept (für später)

```cpp
// Loudness Slider (stufenlos)
// [Dolby Atmos]─────●──────────────[Club Mix]
//      -18 LUFS    -10 LUFS        -6 LUFS

// Live Meter Display:
// ┌─────────────────────────────────┐
// │  Current:  -12.3 LUFS           │
// │  Target:   -10.0 LUFS  [Production] │
// │  True Peak: -1.8 dBTP           │
// │  Headroom:   0.8 dB             │
// │  Dynamic Range: 8.2 dB          │
// │  Quality: ✅ Excellent           │
// └─────────────────────────────────┘

// Genre Selector mit Parametern:
// Genre: [Trap ▼]
// ├─ Bass:        [████████░░] 80%
// ├─ Stereo:      [███████░░░] 70%
// ├─ Atmosphere:  [█████░░░░░] 50%
// ├─ Warmth:      [██████░░░░] 60%
// ├─ Punch:       [███████░░░] 70%
// └─ Brightness:  [██████░░░░] 60%
//
// [✅] Optimize for Dolby Atmos
// [Apply Processing]
```

---

## 💡 Best Practices

### 1. Immer mit Dolby Atmos starten
```cpp
config.optimizeForAtmos = true;  // ✅ Standard!
config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::DolbyAtmos);
```

**Warum?**
- Höchste Qualität
- Maximale Dynamic Range
- Beste Spatial-Audio-Kompatibilität
- Kann später noch lauter gemacht werden
- **NICHT umgekehrt!** (Laut → leise verliert Qualität)

### 2. Verschiedene Loudness-Versionen exportieren
```cpp
// Version 1: Dolby Atmos
config.loudness.targetLUFS = -18.0f;
auto atmosVersion = engine.processIntelligent(audio, config);
export(atmosVersion, "sample_atmos.wav");

// Version 2: Streaming
config.loudness.targetLUFS = -14.0f;
auto streamingVersion = engine.processIntelligent(audio, config);
export(streamingVersion, "sample_streaming.wav");

// Version 3: Club
config.loudness.targetLUFS = -6.0f;
auto clubVersion = engine.processIntelligent(audio, config);
export(clubVersion, "sample_club.wav");
```

### 3. Auto-Detection nutzen
```cpp
// Lass den Engine die Arbeit machen!
config.autoDetectGenre = true;
config.autoDetectBPM = true;
config.autoDetectKey = true;
```

### 4. Atmos Compliance prüfen
```cpp
auto atmosCheck = engine.checkAtmosCompliance(audio, 48000.0);

if (!atmosCheck.compliant)
{
    DBG("Issues:");
    for (const auto& issue : atmosCheck.issues)
        DBG("  - " << issue);

    DBG("Recommendations:");
    for (const auto& rec : atmosCheck.recommendations)
        DBG("  → " << rec);

    // Auto-fix
    auto fixed = engine.fixAtmosIssues(audio, atmosCheck);
}
```

---

## 📋 Cheat Sheet

| Workflow | Verwendung |
|----------|------------|
| **.zip → importFromZip()** | Gemischte Qualitäten importieren |
| **Genre wählen** | MusicGenre::Trap, HipHop, Techno, etc. |
| **Parameter einstellen** | Bass, Stereo, Atmosphere, etc. (0-1) |
| **Atmos optimieren** | optimizeForAtmos = true (Standard!) |
| **Loudness einstellen** | -18 (Atmos) → -6 (Club), stufenlos |
| **processIntelligent()** | Verarbeiten! |
| **Atmos Check** | checkAtmosCompliance() |
| **Export** | exportForEngine() |

| Loudness | LUFS | Verwendung |
|----------|------|------------|
| **Dolby Atmos** | -18 | Spatial Audio ⭐ |
| **Streaming** | -14 | Spotify, Apple Music |
| **Broadcast** | -23 | TV, Radio |
| **Production** | -10 | Moderne Musik |
| **Club** | -6 | Maximum Loudness 🔥 |

---

## ❓ FAQ

**Q: Kann ich verschiedene Qualitäten in einem .zip hochladen?**
A: ✅ JA! 16/24/32-bit, 44.1/48/96/192kHz - alles gemischt in einem .zip!

**Q: Wird automatisch für Dolby Atmos optimiert?**
A: ✅ JA! Standard-Einstellung: optimizeForAtmos = true

**Q: Kann ich die Loudness stufenlos einstellen?**
A: ✅ JA! Von -18 LUFS (Atmos) bis -6 LUFS (Club), jeder Wert dazwischen!

**Q: Gibt es Live-Meter-Anzeigen?**
A: ✅ JA! getLoudnessMeterData() zeigt Current/Target/Peak/Headroom/Quality

**Q: Genre statt Producer-Namen?**
A: ✅ JA! Trap, Hip-Hop, Techno, House, etc. - viel verständlicher!

**Q: Kann ich Parameter verstellen?**
A: ✅ JA! Bass, Stereo, Atmosphere, Warmth, Punch, Brightness (0-100%)

**Q: Auto-Detection?**
A: ✅ JA! Genre, BPM, Key, Instrument werden automatisch erkannt!

**Q: Super Intelligence Mode?**
A: ✅ JA! processFullAuto() macht alles automatisch!

---

**Echoelmusic IntelligentStyleEngine** - Genre-basiert, Dolby Atmos Standard, Stufenlose Loudness! 🚀✨

**Soundqualität = DOLBY ATMOS READY** 🔥
