# Zeit, Emergenz und Echoelmusic — Prüfbericht (2026-10-15)

Eingang: ein fremd erstellter Rechercheimpuls (Physik-Short „Was Physiker jetzt über die Zeit
herausfanden …" + Repo-Lesung am Commit `2d8d8b11f`) mit Arbeitsauftrag. Behandelt als
Hypothese (Lernmodus): jede Repo-Aussage ist hier am aktuellen Stand nachgemessen.

Geprüft auf Zweig `claude/echoelmusic-review-optimize-u5jjpd`, HEAD `1fbe9f475`. Kein Swift-Build,
keine Tests ausgeführt, keine Gerätemessung — reine Lese- und Rechenprüfung.

## 1. Entscheidung

- **Übernommen:** nichts aus der Physik. Übernommen wird der praktische Kern des Auftrags — die
  M1b-Verträge (Song-Anker) waren schon im Multicam-Plan; zwei veraltete „höchstens ein Bild"-Zusagen
  sind jetzt dort als überholt markiert, vier fehlende Prüffälle ergänzt.
- **Künstlerische Analogie, kein Beleg:** „Zeit entsteht aus Beziehungen" (relationale Zeit,
  Page-Wootters) als Gestaltungsidee für Phasen, Wiederholung und Puls — siehe §4. Keine Produktaussage,
  kein Store- oder Website-Text daraus.
- **Fachliche Einordnung (aus dem Eingang, Quellen dort genannt, hier nicht neu gelesen):** die
  Sekunden-Definition über Caesium-133 stimmt; „Zeit existiert nicht" folgt aus der Wheeler-DeWitt-
  Gleichung nicht (offenes Problem der Zeit); Verschränkung überträgt nichts schneller als Licht —
  für Fernkollaboration gilt weiter: messen, puffern, Vorhersage nie als empfangenes Spiel zeigen.

## 2. Befunde am Code (maximal fünf)

| # | Befund | Beleg | Sicherheit |
|---|---|---|---|
| 1 | **Eine Kamera-Aufnahme landet heute NICHT an der Song-Stelle ihres Starts**, sondern hinter dem letzten Teil der Spur. Es gibt keinen Song-Anker im Code (`songAnchor`: 0 Treffer, `synchronizationClock`: 0, `CMSyncConvertTime`: 0). | `Studio/WorkstationView.swift` `landTake` → `Sequencer/VideoImport.swift` `performTake` (`start = … nextStartTick(inLane:)`) → `Sequencer/Timeline.swift:698` (`regions(in:).map(\.endTick).max() ?? 0`) | SICHER |
| 2 | **Die stückweise Tempo-Umrechnung existiert schon** — der Anker braucht keine zweite Uhr. `TempoMap.tick(atSeconds:ppq:)` läuft Abschnitt für Abschnitt; für 0,5 s @120 + 0,5 s @60 (Wechsel bei Tick 480, 480 PPQ) ergibt sie 480 + 240 = **720**. | `Core/TempoMap.swift:182` ff. | SICHER (Rechnung), Ausführung nicht geprüft |
| 3 | **Falle für den Anker:** dieselbe Funktion gibt bei nicht-endlicher Eingabe `0` zurück. Wer einen ungültigen Anker durchreicht, platziert still bei Tick 0 — genau der Fall, den der Auftrag verbietet. | `Core/TempoMap.swift:184` `guard seconds.isFinite … else { return 0 }` | SICHER |
| 4 | **Die beiden Linsen starten nacheinander auf einer Queue, nicht frame-locked** — zwei `AVCaptureMovieFileOutput`, der Dateikopf sagt es selbst; Gerätemessung offen. | `Video/VideoTakeCamera.swift:25`, `:64`, `:66`, `:224`/`:227` | SICHER (Code), Versatz am Gerät UNGEMESSEN |
| 5 | **Der Broadcast-Start stempelt das erste zugelassene Bild auf T0**, auch wenn es später gerendert wurde — richtig für einen gemeinsamen Stream-Nullpunkt, aber kein Beleg für gleichzeitig belichtete Kamerabilder; der Broadcast-Pfad ist ohnehin ein Gerüst (HaishinKit nicht verlinkt). | `Stream/BroadcastTimebase.swift` `videoStamp(renderedAt:startTicks:isFirst:)`; Aufrufer `Stream/BroadcastMasterPump.swift:239` | SICHER |

Nicht als Befund geführt: `Timebase`/`SampleTime` haben außer dem Dokument-Decoder
(`Core/DMMWProject.swift:197`) keinen Produktionsaufrufer; `SampleTime(` hat null. Das ist Bestand,
kein Fehler — für den 44,1/48-kHz-Vergleich ist `SampleTime.converted(to:)` die vorhandene Stelle.
`RenderGapDetector` trennt Host-Abstand, Sample-Fortschritt und Unterbrechung
(Aufrufer `Audio/AudioEngine.swift:1078`, `:1468`) — taugt als Epochen-Signal, beweist aber weder
Klickfreiheit noch Latenz.

## 3. Genau eine nächste Scheibe — M1b-0 „Song-Anker" (rein, ohne Kamera-Umbau)

**Nutzen:** eine Aufnahme landet dort, wo der Song beim Start stand — Grundlage für jede
Mehrkamera-, Ton-Abgleich- und Schnittarbeit. Heute stimmt die Lage nur zufällig.

**Schnitt (kleinstmöglich):** ein reiner Werttyp `TakeAnchor` (Take-ID, Host-Sekunden beim Start,
Song-Tick beim Start, Tempo-Karte, Epoche) plus eine reine Funktion
`placement(firstSampleAt:) -> Placement` mit den Fällen `.tick(Int64)` und `.undetermined(reason)`.
Umrechnung ausschließlich über `TempoMap.tick(atSeconds:ppq:)` mit `Note.ticksPerQuarter`.
Noch KEINE Verdrahtung in `VideoImport` — die folgt als eigene Scheibe, wenn der Wert grün ist.
Betroffene Symbole: neu `TakeAnchor` (in `Sequencer/`), gelesen `TempoMap`, `Note.ticksPerQuarter`.
Keine neue Abhängigkeit, keine zweite Uhr.

**Abnahme (Wächter im blockierenden Bündel, Sollwerte vorher in Python gerechnet):**
1. Anker 100,000 s ↔ Tick 3.840, 480 PPQ, 120 BPM, erstes Sample bei 100,050 s → **3.888**;
   ein späterer Stopp ändert das nicht.
2. 200 ms Startverzögerung bei 120 BPM → **192 Ticks** Abstand, ausgewiesen, nicht genullt.
3. 0,5 s @120 + 0,5 s @60 → **720** (nicht mit dem letzten BPM durchgerechnet).
4. Ungültig (nicht-endlich, vor dem Anker, falsche Epoche) → `.undetermined`, **nie** `.tick(0)`.
5. Seek/Loop/Stop/Engine-Neustart während der Aufnahme → neue Epoche, Platzierung nach der
   Gestoppt-Regel (Cue-Takt), kein Fortrechnen.
6. 44,1 vs. 48 kHz: gleiche Dauer gleich platziert (über `SampleTime.converted(to:)`).
7. Synthetischer Drift 20 ppm → 72 ms nach 3.600 s im Ergebnis sichtbar — Prüfwert, keine
   iPhone-Aussage.
Dateinullpunkt und erstes Bild je Linse bleiben zwei getrennte Felder (Vertrag 4 im Plan) — das
kommt mit dem Writer-Umbau, nicht in dieser Scheibe.

**Offen am Gerät, keine Rechnung ersetzt das:** verbleibender A/V-Versatz und beobachtete Maxima
je Linse, mit Messdauer, Bildrate, Audio-Route und Last.

## 4. Spätere musikalische Ideen (Backlog, nachrangig zum Vereinfachungs-Plan)

1. **Phasen spielen:** zwei Loop-Ebenen gleicher Länge mit einstellbarem Versatz, die über N Takte
   auseinander- und wieder zusammenlaufen (Dub Techno, Ambient).
2. **Zeitmaterial formen:** Freeze/Reverse/Grain-Dichte auf vorhandenen Geräten (Echoel Grain,
   RetroCapture) per Automation statt neuem Modul.
3. **Körper als optionale Quelle:** ein gemessener Puls bewegt die Phasen-Geschwindigkeit aus 1. —
   über die vorhandene Modulationsmatrix, mit Herkunft und Qualität getrennt vom Mapping; bei
   Ausfall bleibt das Timing stabil. Keine Wellness-Aussage.

## 5. Geänderte Dokumente

- `scratchpads/PLAN_MULTICAM_2026-10-15.md`: die zwei „höchstens ein Bild"-Zusagen als überholt
  markiert (Verweis auf die Verträge); Verträge 7–10 ergänzt (Ist-Zustand `nextStartTick`, nur
  `TempoMap`, Epoche/Abtastrate, Drift-Prüfwert).
- dieser Bericht; Lernmodus-Eintrag in `inspiration.csv` und `memory/inspiration_intake.md`.
Nicht angefasst: Store-Text, Website, CLAIMS, Code, Abhängigkeiten.
