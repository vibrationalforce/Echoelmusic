# PLAN — DAW-Hülle (Founder-Freigabe 2026-10-02, Postfach E16/E18/E19)

Auftrag (wörtlich): „abtsturzsicher, alles Features in einer accessible und professionellen
übersichtlichen Umgebung … Wichtig ist DAW look mit allen Features".
Entwurf: Artefakt `echoel-daw-shell` (https://claude.ai/artifact/WhyYL38LCHx4giBJcpwtPX).

Antworten:
- Aufbau: **„Ja, so bauen"** — Steuerleiste oben, eine feste Arbeitsfläche, Detailbereich folgt
  der Auswahl, Umschaltleiste unten Arrange · Mixer · Instrument · Browse · Project.
- Pinch: **„Zeit zoomen"** — Pinch zoomt die Zeitachse; Schriftgröße in die Einstellungen.
- Stufen: **„Nur im Detail"** — alle Ansichten immer sichtbar; `SkillLevel` blendet nur
  Profi-Felder im Detailbereich aus.

## Invarianten (gelten in jeder Scheibe)

- `EchoelStudioView` bleibt IMMER gemountet (`.onDisappear` stoppt die Sitzung);
  `FloatingVisualWindow` ebenso (CADisplayLink treibt das Arp).
- Keine Präsentations-Modifier in `WorkspaceView`/`StageShell`/`SurfaceHost` außer EINEM
  `.sheet(item:)` über ein `ShellSheet`-Enum (S1/S3), nie ein angehängter zweiter.
- Heiße Werte (Kamera 10 Hz, Meter 60 Hz, masterVolume, metronome.bpm, Playhead) NUR in
  Blättern; die Ahnen-Prüfung `TheMenuHostReadsNoHotStateTests` bleibt grün.
- Eine Tür je Bereich: was die Umschaltleiste öffnet, verliert seine zweite Tür im SELBEN Commit.
- Ein Transport (`ProjectTransport`/`ProjectPlayStopButton`), PatternEngine bleibt die Uhr.
- Wächter ziehen im selben Commit mit und pinnen die NEUE Form mindestens so streng wie die alte;
  keiner wird gelöscht oder abgeschwächt.

## Scheiben

| # | Scheibe | Kern | Dateien (Sources) |
|---|---|---|---|
| S2 | Umschaltleiste | `PieceView` (arrange · mixer · browse · project, persistiert) + `StudioStage` bleibt; Leiste unten in `StageShell` ersetzt den Saum oben; Arrange/Mix-Kacheln in `pieceTabs` entfallen | StageShell, StudioStage, WorkstationView, StudioDefaultKeys |
| S1 | Steuerleiste | EINE Leiste ersetzt topBar + CompositionHeaderStrip + ProjectHeader: ≡ · ⏮ · ▶/■ · ● · Anzeige-Blatt (Position · BPM+Schloss · Tonart) · Puls; Tonart/Stimmung/Tempo-Modus/Tap/Click in ein Blatt „Song" | WorkspaceView, ProjectHeader, neue DAWControlBar |
| S3 | Projektmenü | ≡: New · Open · Save · Export (WAV/MIDI Stück, Loop-WAV) · Routing · Settings · Learn; verstreute Türen weg | WorkspaceView, WorkstationProjectRow |
| S4 | Arbeitsfläche + Detail | feste Canvas, Detailbereich Track/Part/Notes/Automation/Device, Szenen als Canvas-Schalter | WorkstationView, ArrangeCanvasView |
| S5 | Mixer | Streifen + Master | PieceMixerView |
| S6 | Browse | Import · Medienbibliothek · Sounds/Moods · Foto/Video-Saat | WorkstationView, MediaBrowserView |
| S7 | Instrument entrümpeln | eigene Transport-/Save-Zeilen weg, Chips als Reiter | EchoelStudioView |
| S8 | Querformat | Umschalter als Segment in der Leiste, Detail als rechte Spalte | StageShell, WorkstationView |
| S9 | Zeit-Zoom + Zugänglichkeit | Pinch → Zeitachse; Schrift in Settings; adjustable actions | ArrangeCanvasView, WorkspaceView |
| S10 | Modal-Konsolidierung | Instrument-Modals in den Hüllen-Slot | EchoelStudioView |

Deploy nach 3–4 Scheiben (`.deploy/release` + --since im selben Commit).
Gerät: nichts hiervon ist geräteverifiziert, bis der Founder es sieht.

## Befunde aus dem S2-Review (82b7a6a5a)

- HIGH, repariert: `ThePieceHasTabsTests` verbot `pieceViewRaw =` und traf damit die eigene
  Deklaration — jetzt genau EINE, ausgeschrieben.
- MED, repariert: „New piece" bewegt nur die Bühne; die Leiste ist der EINE Schreiber der Ansicht.
  Der Kompositions-Leitfaden zeichnet deshalb auf jeder Ansicht, solange das Stück keinen Teil hat.
- LOW, Gerät offen: die angedockte Bildkarte parkt `margin + studioControlBandHeight` über dem
  unteren Rand; seit S2 sitzt die Umschaltleiste darunter und hebt die Transportleiste um ~46 pt.
  Das rechte Ende der Transportzeile kann unter der Karte liegen. In S1/S8 mit der Leistenhöhe
  neu messen, nicht blind nachschieben (sieben Wächter lesen diese Größe).
