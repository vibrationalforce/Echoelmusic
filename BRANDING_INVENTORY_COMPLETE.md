# VOLLSTÄNDIGES BRANDING-INVENTAR

**Erstellungsdatum:** 2025-11-26
**Status:** KRITISCH - Inkonsistentes Branding über 100+ Dateien

---

## EXECUTIVE SUMMARY

Das Repository enthält **6 verschiedene Branding-Varianten** die historisch gewachsen sind:

| Variante | Vorkommen | Status |
|----------|-----------|--------|
| **Echoelmusic** | 788 | AKTUELL (Hauptname) |
| **Echoel** | 438 | AKTUELL (Kurzname) |
| **BLAB/Blab/blab** | 437 | VERALTET - Muss migriert werden |
| **blab-ios-app** | 51 | VERALTET (alter Repo-Name) |
| **vibrationalforce** | 42 | BEHALTEN (GitHub Username) |
| **EOEL** | 11 (nur Commits) | HISTORISCH (Zwischenname) |

---

## 1. BRANDING-STATISTIK

### Detaillierte Zählung

```
Echoelmusic:        696 Vorkommen (Hauptname)
Echoel:             417 Vorkommen (Kurzname, Produktfamilie)
echoelmusic:         92 Vorkommen (lowercase)
echoel:              21 Vorkommen (lowercase)
--------------------------------------------------
ECHOEL-FAMILIE:   1,226 VORKOMMEN (KORREKT)

Blab:               205 Vorkommen
BLAB:               155 Vorkommen
blab:                77 Vorkommen
--------------------------------------------------
BLAB-FAMILIE:       437 VORKOMMEN (VERALTET)

blab-ios-app:        51 Vorkommen (alter Repo-Name)
BlabApp:             14 Vorkommen (Swift Entry Point)
com.blab:             9 Vorkommen (Bundle ID)
BlabNode:             8 Vorkommen (Protocol Name)
BlabColors:           7 Vorkommen (Color Constants)
BlabStudio:           6 Vorkommen (Ordnerpfad)
--------------------------------------------------
LEGACY-VARIANTEN:    95 VORKOMMEN (VERALTET)

vibrationalforce:    42 Vorkommen (GitHub Username)
--------------------------------------------------
BEHALTEN:            42 VORKOMMEN

EOEL:                11 Vorkommen (nur in Git Commits)
--------------------------------------------------
HISTORISCH:          11 VORKOMMEN (ignorieren)
```

---

## 2. KRITISCHE DATEIEN MIT VERALTETEM BRANDING

### 2.1 Konfigurationsdateien (HÖCHSTE PRIORITÄT)

| Datei | Problem | Fix |
|-------|---------|-----|
| `project.yml` | `name: Blab`, `Sources/Blab`, `com.blab` | → Echoelmusic |
| `Info.plist` | `CFBundleName: Blab`, Permissions mit "Blab" | → Echoelmusic |
| `Resources/Info.plist` | `BLAB needs microphone...` | → Echoelmusic |
| `Makefile` | Referenzen auf Blab | → Echoelmusic |

### 2.2 GitHub Workflows (HOHE PRIORITÄT)

| Datei | Zeilen | Problem |
|-------|--------|---------|
| `.github/workflows/build-ios.yml` | 38-411 | Komplettes Xcode-Projekt als "Blab" |
| `.github/workflows/ios-build.yml` | 48, 58, 85-106 | `-scheme Blab`, Artifact names |
| `.github/workflows/ios-build-simple.yml` | 54, 67 | `-scheme Blab` |

### 2.3 Swift Source Code (HOHE PRIORITÄT)

| Datei | Zeile | Problem |
|-------|-------|---------|
| `Sources/Echoelmusic/Audio/Nodes/NodeGraph.swift` | 32 | `com.blab.nodegraph.audio` |
| `Sources/Echoelmusic/Unified/UnifiedControlHub.swift` | 61, 152 | `com.blab.control`, `com.blab.healthkit` |
| `Sources/Echoelmusic/Biofeedback/HealthKitManager.swift` | 88 | `com.blab.healthkit` |
| `Sources/Echoelmusic/LED/MIDIToLightMapper.swift` | 473 | `com.blab.udp` |
| `Sources/Echoelmusic/Video/BackgroundSourceManager.swift` | 42-730 | `blabVisualRenderer`, `BlabError`, etc. |

### 2.4 Shell Scripts (MITTLERE PRIORITÄT)

| Datei | Problem |
|-------|---------|
| `build.sh` | Referenzen auf Blab |
| `debug.sh` | Referenzen auf Blab |
| `deploy.sh` | Referenzen auf Blab |
| `test.sh` | Referenzen auf Blab |
| `test-ios15.sh` | Referenzen auf Blab |

### 2.5 Dokumentation (MITTLERE PRIORITÄT)

| Datei | Referenzen |
|-------|------------|
| `README.md` | "# BLAB iOS App", "BLAB is an embodied..." |
| `QUICK_DEV_REFERENCE.md` | 30+ Referenzen (Sources/Blab/, BlabNode, BlabColors) |
| `DAW_INTEGRATION_GUIDE.md` | 40+ Referenzen ("BLAB MIDI 2.0 Output") |
| `INTEGRATION_COMPLETE.md` | 20+ Referenzen |
| `GITHUB_ACTIONS_GUIDE.md` | 20+ Referenzen |
| `TESTFLIGHT_SETUP.md` | 15+ Referenzen |
| `XCODE_HANDOFF.md` | 10+ Referenzen |
| `COMPATIBILITY.md` | Referenzen |
| `DEPLOYMENT.md` | Referenzen |
| `QUICKSTART.md` | BlabStudio Pfade |
| `BUGFIXES.md` | "BUG FIXES REPORT - Blab iOS App" |
| `DEBUGGING_COMPLETE.md` | Referenzen |
| `Prompts/BLAB_MASTER_PROMPT_v4.3.md` | 100+ Referenzen (gesamtes Dokument) |
| `BLAB_Allwave_V∞_ClaudeEdition.txt` | 50+ Referenzen |

---

## 3. VOLLSTÄNDIGE DATEILISTE

### 3.1 Dateien mit "BLAB/Blab/blab" (44 Dateien)

```
.github/CLAUDE_TODO.md
.github/HANDOFF_TO_CODEX_WEEK1.md
.github/workflows/build-ios.yml
.github/workflows/ios-build-simple.yml
.github/workflows/ios-build.yml
BLAB_Allwave_V∞_ClaudeEdition.txt
BUGFIXES.md
CHATGPT_CODEX_INSTRUCTIONS.md
CLAUDE_CODE_ULTIMATE_PROMPT.md
COMPATIBILITY.md
CURRENTLY_WORKING.md
DAW_INTEGRATION_GUIDE.md
DEBUGGING_COMPLETE.md
DEPLOYMENT.md
ECHOEL_BRAND_STRATEGY.md
GITHUB_ACTIONS_GUIDE.md
Info.plist
INTEGRATION_COMPLETE.md
INTEGRATION_SUCCESS.md
iOS15_COMPATIBILITY_AUDIT.md
Makefile
PHASE_3_OPTIMIZED.md
Prompts/BLAB_MASTER_PROMPT_v4.3.md
QUICK_DEV_REFERENCE.md
QUICKSTART.md
README.md
Resources/Info.plist
SESSION_SUMMARY_2025_11_12.md
SETUP_COMPLETE.md
Sources/Echoelmusic/Audio/Nodes/NodeGraph.swift
Sources/Echoelmusic/Biofeedback/HealthKitManager.swift
Sources/Echoelmusic/LED/MIDIToLightMapper.swift
Sources/Echoelmusic/Unified/UnifiedControlHub.swift
Sources/Echoelmusic/Video/BackgroundSourceManager.swift
SUSTAINABLE_BUSINESS_STRATEGY.md
TESTFLIGHT_SETUP.md
XCODE_HANDOFF.md
build.sh
debug.sh
deploy.sh
project.yml
test-ios15.sh
test.sh
```

### 3.2 Dateien mit "Echoel" (ohne "Echoelmusic") (23 Dateien)

```
AUDIT_REPORT_2025_11_26.md
COMPETITIVE_ANALYSIS_2025.md
CURRENT_STATUS.md
ECHOEL_AI_ARCHITECTURE.md
ECHOEL_BRAND_CORRECTION.md
ECHOEL_WISDOM_ARCHITECTURE.md
HIGHCLASS_DEVELOPMENT.md
MVP_INTEGRATION_STRATEGY.md
OPTIMIZATION_FEATURES.md
PR_BODY.md
QUICK_START_PRODUCTION.md
SESSION_SUMMARY_2025_11_12.md
SUSTAINABLE_BUSINESS_STRATEGY.md
iOS_DEVELOPMENT_GUIDE.md
Sources/Audio/AudioEngine.h
Sources/Biofeedback/AdvancedBiofeedbackProcessor.h
Sources/Common/GlobalWarningFixes.h
Sources/DAW/DAWOptimizer.h
Sources/Development/AdvancedDiagnostics.h
Sources/Development/AutomatedTesting.h
Sources/Development/DeploymentAutomation.h
Sources/Examples/IntegratedProcessor.h
Sources/Lighting/LightController.h
Sources/Remote/EchoelCloudManager.h
Sources/Sync/EchoelSync.h
Sources/UI/MainWindow.cpp
Sources/UI/MainWindow.h
Sources/Video/VideoSyncEngine.h
```

---

## 4. NAMING-KONVENTIONEN (SOLL-ZUSTAND)

### 4.1 Offizieller Name

| Kontext | Name | Beispiel |
|---------|------|----------|
| **App Store** | Echoelmusic | "Echoelmusic - Bio-Reactive Music" |
| **Bundle ID** | com.echoelmusic.app | `PRODUCT_BUNDLE_IDENTIFIER` |
| **Swift Module** | Echoelmusic | `import Echoelmusic` |
| **C++ Namespace** | echoelmusic:: | `namespace echoelmusic { }` |
| **GitHub Repo** | Echoelmusic | `vibrationalforce/Echoelmusic` |

### 4.2 Produkt-Familie

| Produkt | Vollname | Kurzname |
|---------|----------|----------|
| Sync-Engine | EchoelSync™ | Sync |
| Cloud-Service | EchoelCloud™ | Cloud |
| Spatial Audio | EchoelSpatial™ | Spatial |
| AI Features | EchoelAI™ | AI |
| Health/Wellness | EchoelHealth™ | Health |
| Operating System | EchoelOS™ | OS |
| Knowledge Base | EchoelWisdom™ | Wisdom |

### 4.3 Code-Konventionen

```swift
// Swift Naming
class EchoelmusicAudioEngine { }
struct EchoelmusicConfiguration { }
enum EchoelmusicMode { }
let echoelmusicQueue = DispatchQueue(label: "com.echoelmusic.audio")

// C++ Naming
namespace echoelmusic {
    class AudioEngine { };
}
```

### 4.4 File/Folder Struktur

```
Sources/
├── Echoelmusic/          # Swift iOS App
│   ├── Audio/
│   ├── Biofeedback/
│   └── ...
├── Audio/                # C++ Shared
├── DSP/                  # C++ DSP
├── Plugin/               # C++ JUCE Plugin
└── ...
```

---

## 5. MIGRATIONS-ANLEITUNG

### Phase 1: Kritische Konfiguration (30 min)

```bash
# 1. project.yml
sed -i 's/name: Blab/name: Echoelmusic/g' project.yml
sed -i 's/Sources\/Blab/Sources\/Echoelmusic/g' project.yml
sed -i 's/com\.blab/com.echoelmusic/g' project.yml

# 2. Info.plist
sed -i 's/<string>Blab<\/string>/<string>Echoelmusic<\/string>/g' Info.plist
sed -i 's/Blab needs/Echoelmusic needs/g' Info.plist
sed -i 's/BLAB needs/Echoelmusic needs/g' Resources/Info.plist
sed -i 's/BLAB reads/Echoelmusic reads/g' Resources/Info.plist
sed -i 's/BLAB uses/Echoelmusic uses/g' Resources/Info.plist
sed -i 's/BLAB may/Echoelmusic may/g' Resources/Info.plist
sed -i 's/BLAB detects/Echoelmusic detects/g' Resources/Info.plist
```

### Phase 2: Swift Source Code (1h)

```bash
# Bundle IDs
find Sources -name "*.swift" -exec sed -i 's/com\.blab\./com.echoelmusic./g' {} \;

# Variable Names
find Sources -name "*.swift" -exec sed -i 's/blabVisualRenderer/echoelmusicVisualRenderer/g' {} \;
find Sources -name "*.swift" -exec sed -i 's/blabVisual/echoelmusicVisual/g' {} \;
find Sources -name "*.swift" -exec sed -i 's/BlabError/EchoelmusicError/g' {} \;
```

### Phase 3: CI/CD Workflows (2h)

Die `.github/workflows/*.yml` Dateien enthalten embedded Xcode-Projekte.
Diese müssen manuell aktualisiert werden:

1. `build-ios.yml`: Komplettes pbxproj neu generieren
2. `ios-build.yml`: Scheme-Namen ändern
3. `ios-build-simple.yml`: Scheme-Namen ändern

### Phase 4: Dokumentation (2h)

```bash
# Hauptdokumentation
sed -i 's/# BLAB iOS App/# Echoelmusic/g' README.md
sed -i 's/BLAB is/Echoelmusic is/g' README.md
sed -i 's/BLAB MIDI/Echoelmusic MIDI/g' DAW_INTEGRATION_GUIDE.md

# Alle MD-Dateien
find . -name "*.md" -exec sed -i 's/Sources\/Blab/Sources\/Echoelmusic/g' {} \;
find . -name "*.md" -exec sed -i 's/BlabNode/EchoelmusicNode/g' {} \;
find . -name "*.md" -exec sed -i 's/BlabColors/EchoelmusicColors/g' {} \;
```

### Phase 5: Prompt-Dateien umbenennen

```bash
mv Prompts/BLAB_MASTER_PROMPT_v4.3.md Prompts/ECHOELMUSIC_MASTER_PROMPT_v5.0.md
# Dann Inhalt manuell aktualisieren
```

---

## 6. VALIDIERUNG NACH MIGRATION

```bash
# Check für verbleibende BLAB-Referenzen
echo "=== Verbleibende BLAB Referenzen ==="
grep -rli "blab" --include="*.swift" --include="*.yml" --include="*.plist" . | grep -v ".git"

# Check für verbleibende com.blab
echo "=== Verbleibende com.blab Referenzen ==="
grep -rn "com\.blab" --include="*.swift" --include="*.yml" --include="*.plist" .

# Check für Sources/Blab Pfade
echo "=== Verbleibende Sources/Blab Pfade ==="
grep -rn "Sources/Blab" --include="*.md" --include="*.yml" --include="*.swift" .
```

---

## 7. RISIKO-BEWERTUNG

| Änderung | Risiko | Mitigation |
|----------|--------|------------|
| Bundle ID ändern | HOCH | Neue App im Store, Datenverlust |
| Scheme-Namen | MITTEL | CI muss aktualisiert werden |
| Swift Code | NIEDRIG | Nur String-Ersetzungen |
| Dokumentation | NIEDRIG | Keine Auswirkung auf Build |

### Bundle ID Strategie

**EMPFEHLUNG:** Bundle ID `com.blab.studio` NICHT sofort ändern!

Wenn die App bereits im App Store ist oder TestFlight-Builds existieren:
- Behalte `com.blab.studio` als Bundle ID
- Verwende "Echoelmusic" nur als Display Name
- Plane Bundle ID Migration für v2.0

Wenn noch keine Veröffentlichung:
- Ändere zu `com.echoelmusic.app`
- Jetzt ist der beste Zeitpunkt

---

## 8. ZEITLEISTE

| Phase | Aufwand | Priorität |
|-------|---------|-----------|
| Konfiguration (project.yml, Info.plist) | 30 min | KRITISCH |
| Swift Source Code | 1h | HOCH |
| CI/CD Workflows | 2h | HOCH |
| Shell Scripts | 30 min | MITTEL |
| Dokumentation | 2h | MITTEL |
| Prompt-Dateien | 1h | NIEDRIG |
| **GESAMT** | **7h** | |

---

## 9. COMMIT-STRATEGIE

```bash
# Phase 1
git commit -m "chore(branding): Update project.yml and Info.plist to Echoelmusic"

# Phase 2
git commit -m "refactor(swift): Migrate com.blab to com.echoelmusic in source"

# Phase 3
git commit -m "ci: Update GitHub workflows to Echoelmusic branding"

# Phase 4
git commit -m "docs: Migrate documentation from BLAB to Echoelmusic"

# Phase 5
git commit -m "chore: Rename BLAB prompt files to Echoelmusic"
```

---

## 10. EOEL HISTORIE

**EOEL** war ein Zwischenname, der in der Entwicklung verwendet wurde:

```
Commits mit EOEL:
- "EOEL 100% COMPLETE!"
- "EOEL V1.0 FINAL IMPLEMENTATION PLAN"
- "Complete EOEL Rebranding - JUMPER→EoelWork, Echoel/Echoelmusic→EOEL"
- "EOEL v3.0 Complete Overview"
- "EOEL v2.0 Unified Architecture"
```

**Status:** EOEL wurde zu Echoelmusic umbenannt. Keine aktiven Dateien mit EOEL.

---

**Erstellt von:** Claude Code (Opus 4)
**Für:** Echoelmusic Repository Branding Cleanup
