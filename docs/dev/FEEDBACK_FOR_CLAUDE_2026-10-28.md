# Structured Feedback for Claude — Echoel Studio (2026-10-28)

**Ziel:** Klar strukturiertes, programmiertechnisches Feedback basierend auf dem aktuellen Repo-Stand (EchoelStudio). Fokus auf Stabilität, Architektur-Invarianten, Lücken zur Vision und konkrete Lösungsvorschläge.

**Kontext:** Echoel Studio ist die neue Workstation (Swift 6, keine externen Deps, TestFlight). Die Alt-App (10.79) ist eingefroren. Vision: DMMW mit Bio, Visual, Licht, Raum als Module. Founder-Entscheidung 24.10.: Store-first, keine Förderung, privates Repo später.

---

## 1. Architektur-Stärken (behalten)

- **Einziger Session-Eigentümer:** `Project` / `DMMWProject` + `Command`-Door → Undo, Agent, MIDI-Learn und Speichern bleiben konsistent.
- **EngineCore + Snapshot:** AudioEngine füttert den Core mit Snapshots; keine direkten Graph-Mutationen von außen.
- **DiagnosticLog vor os_log:** Crash-Diagnostik ist solide.
- **AUv3 in einer Erweiterung:** Identitäts-Fix (eine App-ID, eine .auv3, ein Kauf) ist richtig.

**Empfehlung:** Diese Invarianten in `CLAUDE.md` und `FOUNDER_PRODUCT_LAW.md` explizit als „nicht brechen“ markieren.

---

## 2. Kritische technische Probleme & Lösungen

### 2.1 Aufnahme bei Routenwechsel (HOCH — teilweise behoben, aber nachprüfen)
**Problem:** Routenwechsel (Kopfhörer, Bluetooth, Anruf) während Aufnahme kann Take verwerfen oder Recorder in inkonsistentem Zustand lassen.
**Ort:** `AudioEngine.configure`, `replaceEngine`, `take`/`recorder`/`drainTask`.

**Lösung:**
```swift
// In AudioEngine: vor jedem configure/replaceEngine
if take != nil || takeEnding {
    endTake(forced: true)  // oder pauseFromOutside + async end
}
// Recorder immer neu bauen, nie wiederverwenden nach Route-Change.
recorder = nil
```
- Take-Writer und Drain-Task explizit abschließen, bevor Graph neu gebaut wird.
- Unit-Test: Simuliere `AVAudioSession.routeChangeNotification` während armed track.

### 2.2 Tempo-Karte beim Folgen fremder Clock (MITTEL)
**Problem:** Bei Clock-Follow wird die Song-TempoMap statt der gespielten veröffentlicht → Automation/Placement springt.
**Ort:** `AudioEngine.publish(project)` vs. `publish(playing(project))`.

**Lösung:**
```swift
func publish(_ project: Project, playing: Bool = false) {
    let effective = playing ? playing(project) : project
    // ... compile plan from effective
}
```
Immer die gespielte TempoMap für Placement und Automation verwenden, wenn Clock gefolgt wird.

### 2.3 Export im RAM / UInt32-Overflow (MITTEL)
**Problem:** OfflineRender lädt ganzen Song ×4 in RAM; UInt32 overflow bei langen Songs.
**Lösung:** Streaming-Render mit `AVAudioFile` + chunked processing. Tick → Sample-Mapping mit `Int64` oder `Double` für Positionen > 2^32.

### 2.4 MIDI-Aufnahme & Event-Union
**Status:** MIDI-Aufnahme und Pitch-Bend/CC sind teilweise drin (f7f2aaf).
**Lücke:** Kein vollständiger Event-Union-Typ (Note + Bend + CC + Aftertouch) im Clip-Modell für Live-Modifikation.

**Lösung:**
```swift
public enum MIDIEvent: Codable, Equatable {
    case note(Note)
    case bend(tick: Tick, value: Double)
    case cc(tick: Tick, controller: Int, value: Double)
    // ...
}
```
Clip speichert `[MIDIEvent]` sortiert; PlaybackPlan kompiliert daraus.

---

## 3. Lücken zur Vision (Bio / Visual / Licht / Raum)

**Blocker:** Fehlendes Spur-Modell „Quelle + Ziel“ und allgemeine Ereignis-Spur. Live-Modulation geht heute nur über Document → Undo.

**Programmiertechnische Schritte:**

1. **TrackSource / TrackTarget**
   ```swift
   struct TrackSource { /* bio, midi, audio, generator */ }
   struct TrackTarget { /* instrument, effect chain, visual, light, spatial */ }
   ```
   Command: `setTrackSource`, `setTrackTarget`.

2. **Live Modulation Layer** (nicht über Undo)
   - Separater `ModulationBus` (lock-free ring oder actor).
   - BioFrame, MIDI-CC, Automation-Live schreiben direkt in ParameterWriter, ohne Command.
   - Document speichert nur die Basis-Werte.

3. **BodyFrameSource** (bereits angelegt)
   - Adapter in `App/Models/BodyFramePublisherAdapter.swift` fertigstellen.
   - HealthKit / Camera rPPG / BLE → `BodyFrame` auf EngineBus.

4. **Ereignis-Spur**
   - Generischer `EventClip` für Licht, Visual, Spatial.
   - Später OSC/Art-Net/sACN-Output aus der Spur.

---

## 4. Testbarkeit & Qualität

- `App/` hat keinen Test-Target. AudioEngine, PluginHost, DocumentController, MIDIInput sind ungetestet.
- **Lösung:** XCTest-Target für `App/` anlegen. Mindestens:
  - Route-Change während Aufnahme.
  - Clock-Follow + Automation.
  - Offline-Export langer Songs.
  - Command-Apply Roundtrip (Project → Command → Project).

- Accessibility: VoiceOver, Dynamic Type, Reduce Motion noch unvollständig. In `Theme.swift` und Views systematisch prüfen.

---

## 5. Empfohlene nächste Commits für Claude

1. **Stabilisierung Aufnahme + Clock** (2.1 + 2.2) — höchste Priorität für TestFlight-Qualität.
2. **MIDIEvent-Union** in Clip-Modell + PlaybackPlan.
3. **Test-Target** für App/Engine anlegen und die kritischen Pfade abdecken.
4. **TrackSource/Target** Skelett (ohne Bio/Visual) — damit die Architektur für Module bereit ist.
5. **Live-Modulation-Bus** (minimal: ein Parameter kann live überschrieben werden, ohne Undo).

---

## 6. Nicht tun

- Keine neuen Bundle-IDs oder App-Store-Objekte.
- Keine Health-Claims im Code oder Store-Text.
- Keine Cloud/Telemetrie.
- Keine Breaking Changes am JSON-Format ohne Migrationspfad (`EarlierSongImport`).

---

**Zusammenfassung für Claude:** Die Architektur trägt die Vision. Priorisiere Stabilisierung der Audio-Lifecycle-Pfade (Aufnahme, Route, Clock) und füge dann die fehlenden Türen (Source/Target + Live-Mod + Event-Union) hinzu. Tests sind der schnellste Hebel für Vertrauen.

Erstellt von Grok-Team am 2026-10-28 basierend auf Repo-Audit und Code-Review.
