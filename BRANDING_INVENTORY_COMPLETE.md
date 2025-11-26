# VOLLSTÄNDIGES BRANDING-INVENTAR

**Erstellungsdatum:** 2025-11-26
**Status:** KRITISCH - Inkonsistentes Branding über 100+ Dateien

---

## EXECUTIVE SUMMARY

Das Repository enthält **6 verschiedene Branding-Varianten** die historisch gewachsen sind:

| Variante | Vorkommen | Status |
|----------|-----------|--------|
| **Eoel** | 788 | AKTUELL (Hauptname) |
| **Echoel** | 438 | AKTUELL (Kurzname) |
| **Eoel/Eoel/blab** | 437 | VERALTET - Muss migriert werden |
| **eoel-ios-app** | 51 | VERALTET (alter Repo-Name) |
| **vibrationalforce** | 42 | BEHALTEN (GitHub Username) |
| **EOEL** | 11 (nur Commits) | HISTORISCH (Zwischenname) |

---

## 1. BRANDING-STATISTIK

### Detaillierte Zählung

```
Eoel:        696 Vorkommen (Hauptname)
Echoel:             417 Vorkommen (Kurzname, Produktfamilie)
echoelmusic:         92 Vorkommen (lowercase)
echoel:              21 Vorkommen (lowercase)
--------------------------------------------------
ECHOEL-FAMILIE:   1,226 VORKOMMEN (KORREKT)

Eoel:               205 Vorkommen
Eoel:               155 Vorkommen
blab:                77 Vorkommen
--------------------------------------------------
Eoel-FAMILIE:       437 VORKOMMEN (VERALTET)

eoel-ios-app:        51 Vorkommen (alter Repo-Name)
EoelApp:             14 Vorkommen (Swift Entry Point)
com.blab:             9 Vorkommen (Bundle ID)
EoelNode:             8 Vorkommen (Protocol Name)
EoelColors:           7 Vorkommen (Color Constants)
EoelStudio:           6 Vorkommen (Ordnerpfad)
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
| `project.yml` | `name: Eoel`, `Sources/Eoel`, `com.blab` | → Eoel |
| `Info.plist` | `CFBundleName: Eoel`, Permissions mit "Eoel" | → Eoel |
| `Resources/Info.plist` | `Eoel needs microphone...` | → Eoel |
| `Makefile` | Referenzen auf Eoel | → Eoel |

### 2.2 GitHub Workflows (HOHE PRIORITÄT)

| Datei | Zeilen | Problem |
|-------|--------|---------|
| `.github/workflows/build-ios.yml` | 38-411 | Komplettes Xcode-Projekt als "Eoel" |
| `.github/workflows/ios-build.yml` | 48, 58, 85-106 | `-scheme Eoel`, Artifact names |
| `.github/workflows/ios-build-simple.yml` | 54, 67 | `-scheme Eoel` |

### 2.3 Swift Source Code (HOHE PRIORITÄT)

| Datei | Zeile | Problem |
|-------|-------|---------|
| `Sources/Eoel/Audio/Nodes/NodeGraph.swift` | 32 | `com.blab.nodegraph.audio` |
| `Sources/Eoel/Unified/UnifiedControlHub.swift` | 61, 152 | `com.blab.control`, `com.blab.healthkit` |
| `Sources/Eoel/Biofeedback/HealthKitManager.swift` | 88 | `com.blab.healthkit` |
| `Sources/Eoel/LED/MIDIToLightMapper.swift` | 473 | `com.blab.udp` |
| `Sources/Eoel/Video/BackgroundSourceManager.swift` | 42-730 | `blabVisualRenderer`, `EoelError`, etc. |

### 2.4 Shell Scripts (MITTLERE PRIORITÄT)

| Datei | Problem |
|-------|---------|
| `build.sh` | Referenzen auf Eoel |
| `debug.sh` | Referenzen auf Eoel |
| `deploy.sh` | Referenzen auf Eoel |
| `test.sh` | Referenzen auf Eoel |
| `test-ios15.sh` | Referenzen auf Eoel |

### 2.5 Dokumentation (MITTLERE PRIORITÄT)

| Datei | Referenzen |
|-------|------------|
| `README.md` | "# Eoel iOS App", "Eoel is an embodied..." |
| `QUICK_DEV_REFERENCE.md` | 30+ Referenzen (Sources/Eoel/, EoelNode, EoelColors) |
| `DAW_INTEGRATION_GUIDE.md` | 40+ Referenzen ("Eoel MIDI 2.0 Output") |
| `INTEGRATION_COMPLETE.md` | 20+ Referenzen |
| `GITHUB_ACTIONS_GUIDE.md` | 20+ Referenzen |
| `TESTFLIGHT_SETUP.md` | 15+ Referenzen |
| `XCODE_HANDOFF.md` | 10+ Referenzen |
| `COMPATIBILITY.md` | Referenzen |
| `DEPLOYMENT.md` | Referenzen |
| `QUICKSTART.md` | EoelStudio Pfade |
| `BUGFIXES.md` | "BUG FIXES REPORT - Eoel iOS App" |
| `DEBUGGING_COMPLETE.md` | Referenzen |
| `Prompts/Eoel_MASTER_PROMPT_v4.3.md` | 100+ Referenzen (gesamtes Dokument) |
| `Eoel_Allwave_V∞_ClaudeEdition.txt` | 50+ Referenzen |

---

## 3. VOLLSTÄNDIGE DATEILISTE

### 3.1 Dateien mit "Eoel/Eoel/blab" (44 Dateien)

```
.github/CLAUDE_TODO.md
.github/HANDOFF_TO_CODEX_WEEK1.md
.github/workflows/build-ios.yml
.github/workflows/ios-build-simple.yml
.github/workflows/ios-build.yml
Eoel_Allwave_V∞_ClaudeEdition.txt
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
Prompts/Eoel_MASTER_PROMPT_v4.3.md
QUICK_DEV_REFERENCE.md
QUICKSTART.md
README.md
Resources/Info.plist
SESSION_SUMMARY_2025_11_12.md
SETUP_COMPLETE.md
Sources/Eoel/Audio/Nodes/NodeGraph.swift
Sources/Eoel/Biofeedback/HealthKitManager.swift
Sources/Eoel/LED/MIDIToLightMapper.swift
Sources/Eoel/Unified/UnifiedControlHub.swift
Sources/Eoel/Video/BackgroundSourceManager.swift
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

### 3.2 Dateien mit "Echoel" (ohne "Eoel") (23 Dateien)

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
| **App Store** | Eoel | "Eoel - Bio-Reactive Music" |
| **Bundle ID** | com.echoelmusic.app | `PRODUCT_BUNDLE_IDENTIFIER` |
| **Swift Module** | Eoel | `import Eoel` |
| **C++ Namespace** | echoelmusic:: | `namespace echoelmusic { }` |
| **GitHub Repo** | Eoel | `vibrationalforce/Eoel` |

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
class EoelAudioEngine { }
struct EoelConfiguration { }
enum EoelMode { }
let echoelmusicQueue = DispatchQueue(label: "com.echoelmusic.audio")

// C++ Naming
namespace echoelmusic {
    class AudioEngine { };
}
```

### 4.4 File/Folder Struktur

```
Sources/
├── Eoel/          # Swift iOS App
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
sed -i 's/name: Eoel/name: Eoel/g' project.yml
sed -i 's/Sources\/Eoel/Sources\/Eoel/g' project.yml
sed -i 's/com\.blab/com.echoelmusic/g' project.yml

# 2. Info.plist
sed -i 's/<string>Eoel<\/string>/<string>Eoel<\/string>/g' Info.plist
sed -i 's/Eoel needs/Eoel needs/g' Info.plist
sed -i 's/Eoel needs/Eoel needs/g' Resources/Info.plist
sed -i 's/Eoel reads/Eoel reads/g' Resources/Info.plist
sed -i 's/Eoel uses/Eoel uses/g' Resources/Info.plist
sed -i 's/Eoel may/Eoel may/g' Resources/Info.plist
sed -i 's/Eoel detects/Eoel detects/g' Resources/Info.plist
```

### Phase 2: Swift Source Code (1h)

```bash
# Bundle IDs
find Sources -name "*.swift" -exec sed -i 's/com\.blab\./com.echoelmusic./g' {} \;

# Variable Names
find Sources -name "*.swift" -exec sed -i 's/blabVisualRenderer/echoelmusicVisualRenderer/g' {} \;
find Sources -name "*.swift" -exec sed -i 's/blabVisual/echoelmusicVisual/g' {} \;
find Sources -name "*.swift" -exec sed -i 's/EoelError/EoelError/g' {} \;
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
sed -i 's/# Eoel iOS App/# Eoel/g' README.md
sed -i 's/Eoel is/Eoel is/g' README.md
sed -i 's/Eoel MIDI/Eoel MIDI/g' DAW_INTEGRATION_GUIDE.md

# Alle MD-Dateien
find . -name "*.md" -exec sed -i 's/Sources\/Eoel/Sources\/Eoel/g' {} \;
find . -name "*.md" -exec sed -i 's/EoelNode/EoelNode/g' {} \;
find . -name "*.md" -exec sed -i 's/EoelColors/EoelColors/g' {} \;
```

### Phase 5: Prompt-Dateien umbenennen

```bash
mv Prompts/Eoel_MASTER_PROMPT_v4.3.md Prompts/ECHOELMUSIC_MASTER_PROMPT_v5.0.md
# Dann Inhalt manuell aktualisieren
```

---

## 6. VALIDIERUNG NACH MIGRATION

```bash
# Check für verbleibende Eoel-Referenzen
echo "=== Verbleibende Eoel Referenzen ==="
grep -rli "blab" --include="*.swift" --include="*.yml" --include="*.plist" . | grep -v ".git"

# Check für verbleibende com.blab
echo "=== Verbleibende com.blab Referenzen ==="
grep -rn "com\.blab" --include="*.swift" --include="*.yml" --include="*.plist" .

# Check für Sources/Eoel Pfade
echo "=== Verbleibende Sources/Eoel Pfade ==="
grep -rn "Sources/Eoel" --include="*.md" --include="*.yml" --include="*.swift" .
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
- Verwende "Eoel" nur als Display Name
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
git commit -m "chore(branding): Update project.yml and Info.plist to Eoel"

# Phase 2
git commit -m "refactor(swift): Migrate com.blab to com.echoelmusic in source"

# Phase 3
git commit -m "ci: Update GitHub workflows to Eoel branding"

# Phase 4
git commit -m "docs: Migrate documentation from Eoel to Eoel"

# Phase 5
git commit -m "chore: Rename Eoel prompt files to Eoel"
```

---

## 10. EOEL HISTORIE

**EOEL** war ein Zwischenname, der in der Entwicklung verwendet wurde:

```
Commits mit EOEL:
- "EOEL 100% COMPLETE!"
- "EOEL V1.0 FINAL IMPLEMENTATION PLAN"
- "Complete EOEL Rebranding - JUMPER→EoelWork, Echoel/Eoel→EOEL"
- "EOEL v3.0 Complete Overview"
- "EOEL v2.0 Unified Architecture"
```

**Status:** EOEL wurde zu Eoel umbenannt. Keine aktiven Dateien mit EOEL.

---

**Erstellt von:** Claude Code (Opus 4)
**Für:** Eoel Repository Branding Cleanup
