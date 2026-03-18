# Full Repository Audit Command

Führe eine **vollständige, systematische Analyse** des gesamten Echoelmusic-Repositories durch.

---

## PHASE 1: ARCHITEKTUR-SCAN

### 1.1 Projektstruktur
- Analysiere die komplette Verzeichnisstruktur
- Identifiziere alle Module, Packages und deren Abhängigkeiten
- Erstelle ein Dependency-Graph der Komponenten
- Prüfe Package.swift, project.yml (XcodeGen), build.gradle.kts

### 1.2 Design Patterns
- Identifiziere verwendete Design Patterns (MVC, MVVM, Observer, etc.)
- Prüfe Konsistenz der Pattern-Anwendung
- Finde Anti-Patterns oder Code Smells

### 1.3 Schichtenarchitektur
- Analysiere die Trennung: UI → Business Logic → Data Layer
- Prüfe ob Abhängigkeiten korrekt fließen (nur nach unten)
- Identifiziere zirkuläre Abhängigkeiten

---

## PHASE 2: ENGINE-STATUS-ANALYSE

Für **JEDE Engine/Manager/Service** im Repository:

### 2.1 Kategorisierung
Erstelle eine Tabelle mit folgenden Spalten:
| Engine Name | Datei | Status | Vollständigkeit | Kritische Issues |

**Status-Kategorien:**
- ✅ PRODUCTION_READY - Vollständig implementiert, getestet, produktionsreif
- 🟡 FUNCTIONAL - Funktioniert, aber unvollständig oder mit Einschränkungen
- 🟠 PARTIAL - Teilweise implementiert, Core-Funktionalität fehlt
- 🔴 STUB - Nur Struktur/Interface, keine echte Implementierung
- ❌ BROKEN - Kompiliert nicht oder hat kritische Runtime-Fehler
- ⚠️ DEPRECATED - Veraltet oder durch andere Komponente ersetzt

### 2.2 Detailanalyse pro Engine
Für jede Engine dokumentiere:
```
Engine: [Name]
Datei: [Pfad:Zeile]
Status: [siehe oben]
Implementierte Features: [Liste]
Fehlende Features: [Liste]
Externe Abhängigkeiten: [Liste]
Test-Coverage: [%]
Kritische TODOs: [Liste mit Zeilennummern]
```

---

## PHASE 3: CODE-QUALITÄT

### 3.1 Statische Analyse
Suche nach:
- `// TODO:` - Alle offenen TODOs mit Kontext
- `// FIXME:` - Alle bekannten Bugs
- `// HACK:` - Workarounds
- `// WARNING:` - Warnungen im Code
- `fatalError(` - Potenzielle Crashes
- `try!` / `force unwrap !` - Unsichere Operationen
- `print(` - Debug-Ausgaben in Production-Code
- Leere Funktionen / Placeholder-Implementierungen

### 3.2 Stub-Erkennung
Identifiziere Stubs durch:
- Funktionen die nur `return` ohne echte Logik haben
- Methoden die `NotImplementedError` werfen
- Klassen mit leeren Methoden-Bodies
- `#warning` oder `#error` Compiler-Direktiven
- Kommentare wie "placeholder", "stub", "mock", "dummy"

### 3.3 Error Handling
- Prüfe ob Errors korrekt propagiert werden
- Finde swallowed Errors (leere catch-Blöcke)
- Identifiziere fehlende Error-Handling-Pfade

---

## PHASE 4: BUILD & TEST STATUS

### 4.1 Build-Analyse
```bash
swift build 2>&1 | grep -E "(error|warning|note)"
```
- Liste alle Compiler-Warnings
- Liste alle Compiler-Errors
- Identifiziere deprecated API-Verwendung

### 4.2 Test-Analyse
- Welche Tests existieren?
- Welche Komponenten haben KEINE Tests?
- Test-Coverage pro Modul schätzen
- Finde `XCTSkip` oder auskommentierte Tests

---

## PHASE 5: FUNKTIONS-MATRIX

### 5.1 Feature-Vollständigkeit
Erstelle Matrix für jede Hauptfunktion:

| Feature | iOS | macOS | watchOS | tvOS | visionOS | Android | Web |
|---------|-----|-------|---------|------|----------|---------|-----|
| Audio Engine | ? | ? | ? | ? | ? | ? | ? |
| Biofeedback | ? | ? | ? | ? | ? | ? | ? |
| Visuals | ? | ? | ? | ? | ? | ? | ? |
| MIDI | ? | ? | ? | ? | ? | ? | ? |
| Streaming | ? | ? | ? | ? | ? | ? | ? |
| etc. | | | | | | | |

Legende: ✅ Vollständig | 🟡 Teilweise | ❌ Fehlt | N/A Nicht anwendbar

### 5.2 Use-Case-Validierung
Prüfe ob diese Use Cases technisch möglich sind:
1. Solo-Meditation mit HRV-Tracking
2. Live-Performance mit MIDI-Controller
3. Gruppen-Session mit Coherence-Sync
4. Streaming zu YouTube/Twitch
5. VR-Erlebnis auf Vision Pro
6. Apple Watch Standalone
7. Cross-Platform Session (iOS + Android)
8. Plugin-Entwicklung mit SDK

---

## PHASE 6: EXTERNAL DEPENDENCIES

### 6.1 API-Integrationen
Für jede externe API:
- Ist der API-Key/Auth konfiguriert?
- Gibt es Fallback bei API-Ausfall?
- Rate-Limiting implementiert?
- Error-Handling vorhanden?

### 6.2 Hardware-Abhängigkeiten
- HealthKit (echte Daten vs. Simulation)
- MIDI-Geräte (Push 3, etc.)
- DMX/Art-Net Lighting
- Kamera/ARKit

---

## PHASE 7: SECURITY & COMPLIANCE

### 7.1 Security Scan
- Hardcoded Secrets/API-Keys?
- Unsichere Netzwerk-Kommunikation?
- Fehlende Input-Validierung?
- SQL/Command Injection Risiken?

### 7.2 Privacy
- DSGVO-Konformität der Datenverarbeitung?
- Health-Daten korrekt geschützt?
- Disclaimer vorhanden wo nötig?

---

## OUTPUT FORMAT

Erstelle einen strukturierten Report mit:

### 1. Executive Summary
- Gesamtstatus des Projekts (1 Absatz)
- Top 5 kritische Issues
- Top 5 Stärken

### 2. Engine Status Table (komplett)

### 3. Kritische Issues (priorisiert)
```
🔴 CRITICAL: [Issue] - [Datei:Zeile] - [Impact]
🟠 HIGH: [Issue] - [Datei:Zeile] - [Impact]
🟡 MEDIUM: [Issue] - [Datei:Zeile] - [Impact]
```

### 4. Stub/Placeholder Liste

### 5. TODO/FIXME Sammlung (mit Kontext)

### 6. Empfehlungen
- Sofort zu beheben
- Kurzfristig (vor Release)
- Langfristig (Tech Debt)

---

## ANWEISUNGEN FÜR CLAUDE

1. **Sei gründlich** - Scanne JEDE Datei, nicht nur offensichtliche
2. **Sei ehrlich** - Beschönige nichts, reale Status-Einschätzung
3. **Sei konkret** - Immer mit Datei:Zeile referenzieren
4. **Sei systematisch** - Folge der Phase-Struktur
5. **Nutze parallele Agents** - Für verschiedene Bereiche gleichzeitig
6. **Prüfe tatsächliche Implementierung** - Nicht nur Deklarationen

Starte mit Phase 1 und arbeite systematisch durch alle Phasen.
