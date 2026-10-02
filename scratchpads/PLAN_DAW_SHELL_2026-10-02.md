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
| S3 ✅ | Projektmenü | GEBAUT 2026-10-02: ≡ = Open · Save │ Live Colabo · Learn │ Guide; `quickDoorRow`, Save-Kachel und `WorkstationProjectRow` gelöscht. New bleibt im Open-Blatt, Export auf der Projekt-Platte, Routing bei seiner einen Tür (Licht-Kachel) — je Bereich EINE Tür, darum nicht doppelt ins Menü | WorkspaceView, EchoelStudioView, WorkstationView |
| S4 (a ✅ b ✅) | Arbeitsfläche + Detail | feste Canvas, Detailbereich Track/Part/Notes/Automation/Device, Szenen als Canvas-Schalter | WorkstationView, ArrangeCanvasView |
| S5 ✅ | Mixer | Streifen + Master (Master-Streifen gebaut) | WorkstationView, MasterStripView |
| S6 (a ✅) | Browse | Sounds (gebaut) · Medienbibliothek · Foto/Video-Saat; Import bleibt im Add-Menü, Moods im Instrument | WorkstationView, SoundBrowserView |
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

## S3 — Entscheidungen und Befunde (2026-10-02)

- **Das Menü sendet, der Empfänger präsentiert.** `WorkspaceView` trägt weiter NULL
  Präsentations-Modifier: jeder Eintrag postet `.echoelChromeDoor`, der vorhandene Empfänger in
  `EchoelStudioView` hebt die VORHANDENEN Blätter. Keine neue Sheet-Zeile → Black-Screen-Kette
  unverändert (Zähler gleich).
- **Nie ausgegraut, beim Tippen geprüft.** Ein `.disabled` im Menü läse `panelSheetUp` oder
  `hasComposed` im Ahnen-Rumpf. Stattdessen: jeder Arm beginnt mit `guard !panelSheetUp`, und das
  #622-Gesetz (kein leeres Sichern unter echtem Namen) fragt Save beim Tippen über
  `saveHasNothing` — die Abfrage zeigt dann „Nothing to save yet …“ mit nur „OK“.
- **Nicht #492 zurück.** #492 löste ein „•••“-Overflow auf, das niemand als Tür las. Das ≡ ist
  das Logo, heißt „Menu“, nennt alle fünf Einträge im Hinweis und ist der Ort, an dem jeder
  DAW-Nutzer Open/Save sucht. Live Colabo und Learn waren vorher NUR auf der verborgenen
  Instrument-Bühne erreichbar — vom Stück aus gar nicht.
- **Wächter umgezogen, nicht gelockert:** 14 Dateien in `Tests/CISmoke` (Türen, Schloss,
  Save-Gesetz, Tippfläche, Erstlauf-Satz, Guide, MIDI-Export-Reihenfolge u. a.); jeder pinnt die
  NEUE Form mit Abwesenheit der alten Tür PLUS Anwesenheit im Menü.

## S4a — Entscheidungen und Befunde (2026-10-02)

- **EIN Detailbereich, EIN Seitenbesitzer.** Notes und Automation sind Seiten des Inspektors
  (Track · Part · Notes · Automation · Device), nicht mehr zwei aufklappbare Editoren unter der
  Arbeitsfläche. Besitzer der Seite ist `WorkstationSelection.inspectorPage`; `notesOpen` ist nur
  noch ABGELEITET (`inspectorPage == .notes`), damit „Write notes“ und der Kompositions-Leitfaden
  ohne zweiten Zustand weiterlaufen.
- **Jede Seite wird von ihrem eigenen Editor-Gate angeboten (#416):** Notes nur, wenn
  `PartNoteEditor.editableRegion` einen MIDI-Teil auf einer nicht-Bio-Spur findet; Automation nur,
  wenn `SongAutomationEditor` die Spur klingen lassen kann. `TrackMix.detailPages` ist die EINE
  Liste; die Seite fällt über `shown(_:offered:)` auf Track zurück, wenn ihr Gate zufällt.
- **Kein Auf/Zu-Knopf mehr in den Editoren** — die Seite IST das Öffnen. Vier Hide/Show-Schlüssel
  aus dem Katalog entfernt, drei Sätze auf „on the track's Notes page“ umgeschrieben.
- **Wächter:** `TheInspectorShowsOnePageOfThreeTests` → `TheDetailShowsOnePageAtATimeTests`
  (#374, `git mv`), mit einer Matrix über Spur × Auswahl × Kapazität; sechs weitere umgezogen.
  Nebenbei gefunden: die `spokenCount`-Nadel in `TheSelectedPartSaysItsEndAndItsNotesTests` war
  seit E4-91 rot auf korrektem Code (#807) — auf die ausgelieferte Form neu verankert.
- **Gerät offen:** fünf Segmente in der 260-pt-Spalte im Querformat und auf 375 pt; „Write notes“
  springt auf die Notes-Seite.
- **Nächste Scheibe S4b:** Detail-Kopf mit Spurfarbe, einklappbar; Arm/Tonhöhe/Teil-Tempo auf ihre Seiten.

## S4b — Entscheidungen und Befunde (2026-10-02)

- **Die Zeilen der offenen Spur gehören auf ihre Seiten:** Aufnahme-Schalter + Pitch → Track, Teil-Tempo → Part.
  `TrackInspectorView` nimmt sie als zwei `@ViewBuilder`-Slots; gebaut im Workstation-Rumpf, weil sie dessen
  Transport-/Messzustand lesen — keine neue Beobachtung, eine Konstruktionsstelle bleibt.
- **Review-Reparaturen S4a:** Notes-Überschrift (VoiceOver einmal), Teile-Hinweis ohne „above",
  `NoteToolFlow` für die 260-pt-Spalte. Der Detail-Kopf mit Spurfarbe (einklappbar) ist NICHT gebaut —
  das Detail folgt der Auswahl schon und klappt mit ihr; ein zweiter Zu-Knopf wäre ein zweiter Zustand.
- **Gerät offen:** Automationszeile im Querformat (Namensspalte + ~130-pt-Kurve), Segment-Wort „Automation".


## S5 — Entscheidungen und Befunde (2026-10-02)

- **Der Master gehört ans Ende des Mixers, nicht ins Instrument.** `MasterStripView` (eigenes Blatt):
  Lautstärke, Pegel-Balken + EBU-R128-Zahlen (`MasterLoudnessGrid`), „Clear". Verschoben, nicht kopiert —
  das Master-Panel behält Lautheits-Ziel, Klangcharakter, Latenz/Route/Timing, Panic.
- **Das ganze Post-Chain-Raster wandert, nicht nur die Balken:** die R128-Zahlen beobachten die
  Master-Lautstärke per Konstruktion, die Pre-Chain-Balken womöglich nicht — getrennt stünde der Regler
  neben einem Meter, das ihn ignoriert.
- **Montiert außerhalb des Leer-Song-Zweigs:** ein leerer Song spielt weiter das Instrument, also bleibt
  sein Master erreichbar.
- **Kein heißer Read in `PieceMixerView`/`WorkstationView`:** eigene Datei, weil `ThePieceHasAMixerTests`
  `masterLevel` dort verbietet und genau 2 `EchoelValueField(` pinnt.
- `DetailedMeteringOwner.masterPanel` → `.masterReadout` (der Anspruchsteller ist das Raster, wo immer es hängt).
- **Gerät offen:** Streifen unter den Spuren auf 375–440 pt, Regler hörbar, Zahlen laufen, Clear.

## S6a — Entscheidungen und Befunde (2026-10-02)

- **Browse beginnt mit „Sounds".** `SoundBrowserView` listet die gespeicherten Klänge; ein Tipp gibt der
  geöffneten Synth-Spur den Klang über DIESELBE Naht wie die Sound-Zeile der Device-Seite
  (`TrackMix.setSound` in `timeline.editLanePatch`) — ein Undo-Schritt, keine zweite Klang-Logik (#416).
- **Ziel = die Regel der Sound-Zeile** (`TrackMix.controls(…).sound`): nur eine Poly-Rack-Spur. Echoel-Spur,
  Sub, Körperstimme, Audio, Bio → Zeilen gedimmt, Hinweis „Open a synth track in Arrange …".
- **Speicher-Reihenfolge, nicht Favoriten zuerst:** der Device-Hinweis sagt „Default plays the first of the
  Sounds" — dieser erste Klang muss auf beiden Platten derselbe sein. Favoriten tragen einen Stern statt
  nach vorn zu rücken; ein Tipp ruft kein `markUsed` (das Sound-Panel bleibt Besitzer der Zuletzt-Liste).
- **Import und Moods bleiben, wo sie sind:** Import ist das Add-Menü (Arrange, eine Tür); Moods gehören
  dem Instrument (`moodPanel`). Eine zweite Tür wäre gegen „eine Tür je Bereich".
- **Review-Folge S5 (LOW-3):** `MasterStripView` und `SoundBrowserView` stehen jetzt in beiden Chrome-Listen.
- **Gerät offen:** Liste auf 375 pt, Haken nach Tipp, Device-Seite zeigt denselben Klang, Undo im Kopf.

