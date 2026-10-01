# PLAN — Workstation-Neugestaltung (Founder 2026-10-01)

**Auftrag, wörtlich:** „Generell finde ich diese Entwürfe wirken etwas zugänglicher. Grundsätzlich
finde ich das Ding mit den Genres und die rudimentären Bedienungen nicht so schön. Das angehängte
Bild gefällt mir auch. Mache nochmal Deep Research und Deep Audith zu allen Bereichen und leg dann
los. Gestallte alles so um, dass ich Echoelmusic als Workstation ernsthaft vertreten kann. Vorbild
Software übertreffen wir mit Leichtigkeit und wir haben die besten Visuals."

**Referenzen:** der iPhone-Entwurf „Lake Reflection" (26.09., `inspiration.csv:230`) und der
Tablet-Entwurf (Workstation, Querformat, vom Founder heute erneut angehängt).

**Founder-Antworten, die dieser Auftrag gibt** (vorher offen in `memory/inspiration_intake.md:907`):
- (a) Genre ist NICHT mehr die Kopf-Bedienung → wird „Stil" am Generator-Gerät (Echoel-Spur).
  Hebt die 2026-07-14-Platzierung im Kopfstreifen auf.
- (b) Die Bereichs-Tabs des Tablet-Entwurfs sind gewollt → Music · Visual · Light · Space
  (Space = ADM-OSC-Steuerung). **Stream und XR bleiben weg**: kein HaishinKit, kein visionOS-Target —
  ein Tab dorthin wäre eine tote Tür.
- (c) Loop-Schalter bleibt BLOCKED_FOUNDER (nicht Teil dieses Auftrags).

## Messung (fünf Audits, 2026-10-01, read-only)

1. **Oberfläche:** die Funktion des iPhone-Entwurfs ist zu ~70 % da (13 Design-Scheiben vom 26.09.),
   aber die HIERARCHIE nicht: Genre ist das erste Bedienelement des immer sichtbaren Kopfs; der
   Transport sitzt mitten im Scroll; Teile sind graue Blöcke ohne Namen/Farbe; Spuren erscheinen
   zweimal (Canvas-Rinne + Karten darunter); Chips nur auf der Instrument-Bühne, nur Text.
2. **Engine:** Rückgrat echt (Arrange, Undo, Notenedit, Automation, Import). Lücken: 8-Clip-Decke
   (`ClipStore.slotCount`), keine Presets je Spur, keine Mixer-Ansicht, keine Per-Spur-Meter-Quelle,
   kein Song-Export (MIDI/Bounce), keine CC-Spuren. Genre SCHREIBT Tonart/Stimmung/Patch beim Wechsel
   (`EchoelStudioView ~4862`) — widerspricht der WA2-Bindung (Session-Kontext liest, Gerät folgt).
3. **Visual/Licht/Raum:** kein `visual.*`-Parameter registriert; Licht-Look nicht automationsfähig
   (bewusst); Spatial-Szene praktisch leer (Rebuild nur in türloser `ImmersiveStageView`).
   Ehrlicher erster Schritt: KURVEN-Spuren über die vorhandene Song-Automation, nicht Clip-Engines.
4. **Design-System:** Regeln stark und bewacht; es fehlt Identität je Spur (Farbe+Symbol) und
   dicke Bausteine (Track-Kopf, Inspektor-Kopf, Transportleiste, Icon-Tabs).
5. **Recherche:** Logic iPad (Kontrollleiste oben, Ansichtsleiste unten), Cubasis iPhone nur
   quer, Koala (3 Tabs nach Arbeitsfluss) als UX-Maßstab. Keine Mobil-App vereint Musik, Visual,
   Licht und Raum auf EINER Zeitleiste mit dem Körper als Quelle — das ist die Lücke.

## Reihenfolge (eine Scheibe je Zyklus, ≤3 Dateien + Wächter)

### Phase A — Aussehen und Hierarchie (Telefon zuerst)
- **A1** Spur-Identität: `EchoelTheme.TrackHue` (gedämpfte Farbe je Instrument/Art), Symbol +
  Farbe in der Canvas-Rinne, getönte Teile, höhere Spuren. Farbe nie allein (Symbol + Name).
- **A1b** Teile tragen ihren Namen (Clip-Name im Block, 11 pt). **✓ 9352e9791** — `ArrangeCanvas.partName` (getrimmt, leer = kein Etikett), `ArrangePartBlock.nameTag` über den Noten, unter dem Auswahlring, VoiceOver-Wert; Wächter `ThePartsWearTheirNamesTests`. Gerät offen: Lesbarkeit auf jeder Spurfarbe, Kürzung bei einem Ein-Takt-Teil.
- **A2** Genre raus aus dem Kopfstreifen → „Stil" am Echoel-Gerät (eine Tür). A2b: Stil-Wahl
  schreibt Tonart/Stimmung nicht mehr (WA2-Bindung). **✓ A2 b006cdbd1** (A2b offen).
- **A3** Feste Transportleiste unten auf der Stück-Bühne (⏮ ■ ▶ ● Klick · Position · Pegel);
  `transportRow` mitten im Scroll entfällt. EIN Transport (`ProjectTransport`). **✓ dbbe191cf**
  (Scroll in `WorkstationView`, `transportBar` per `safeAreaInset`). A3b offen: Kopf-Play und
  Leisten-Play doppeln sich auf der Stück-Bühne — Kopf-Play bleibt für die Instrument-Bühne.
  **A3b ✓ 3f44da17a** — die Stück-Bühne hat EIN Play (die Leiste); Kopf-Play nur auf der Instrument-Bühne. VoiceOver-Hinweis (`ProjectTransport.buttonHint`) GEPRÜFT, keine Änderung: `canPlay` ignoriert Stumm, der Hinweis ist also wahr (Runde 3).
- **A4** Kopf-Anzeige: Song-Position TAKT.SCHLAG.16tel · BPM · 4/4 · Tonart. **✓ b519c6c44** — `WorkstationSummary.counterText`/`meterText`, Blatt `ProjectPositionReadout` (eigene `TimelineView`, 15 fps, pausiert im Stopp, Breiten-Schablone „888.4.4“, kein heißer Read im Kopf); Reihenfolge Position · Tempo · Taktart · Ort. Die Tonart wird NICHT wiederholt — sie steht im Streifen eine Zeile darüber. Wächter `TheHeadCountsThePieceInBarsBeatsAndSixteenthsTests`. Offen: Inbox H7 (zwei Zähler im selben Format).
- **A5** Spur-Köpfe IM Canvas (M/S verschoben, nicht verdoppelt); Kartenliste → nur Inspektor.
  **✓ a63319b72 (Telefon):** Kopf im Canvas WÄHLT; M/S bleibt im Inspektor-Kopf (zwei 44-pt-
  Schalter passen nicht in eine 96-pt-Rinne neben einen Namen). M/S-in-Rinne → A9 Querformat,
  Founder-Entscheid nötig. Karten nur noch: offene Spur + nicht gezeichnete (`listsCard`).
- **A6** Kompositions-Anleitung zugeklappt, sobald das Stück einen Teil hat. **✓ 12430034e**
  (EINMAL beim Ankommen aus `opensExpanded`, nie selbst zuklappend — c672c2adf-Lehre).
- **A7** Icon+Wort-Tabs auf der Stück-Bühne: Arrange · Mix · Sound · FX · Master · Export. **✓ 7303c048a**
  (Arrange · Sound · FX · Master — gemessen: nur Arrange hat ein Ziel AUF der Stück-Bühne, die
  drei anderen sind Instrument-Panels über die Chrome-Tür + `showStage(.instrument)`. **Mix und
  Export sind KEINE Tabs**: es gibt kein Ganzstück-Mischpult (B3) und keinen Song-Export (B4) —
  ein Tab ohne Ziel ist ein Knopf, der nichts tut. FX/Master folgen den `SkillLevel`-Toren.)
- **A8** Inspektor: Kopf (Symbol, Name, Art · Spur n), Segmente Spur/Teil/Gerät, Teil-Felder
  Start/Ende/Länge als `EchoelValueField`. **✓ a5748ed13** — Kopf der offenen Spur trägt Farbband + Symbol der Rinne (`TrackHue`); die Teil-Felder standen schon in `SelectedPartBar`. **Segmente ✓ 4c3d5be63** — der Inspektor zeigt EINE Seite von dreien (Spur · Teil · Gerät).
- **A9** Querformat: drei Spalten (Spuren+Browser | Arrange+Editor | Inspektor+Visual). **✓ ceb9ede82** — als ZWEI Spalten am Telefon (Arrange+Editoren | Spurköpfe+Inspektor, 260–360 pt), per `AnyLayout`, damit eine Drehung keinen Schalter zurücksetzt; die dritte Spalte (Visual) ist die schwebende Karte. M/S in der Rinne bleibt Founder-Frage (H5).

### Phase B — Engine-Glaubwürdigkeit
- **B1** 8-Clip-Decke heben + „Eigenständig machen" beim Duplizieren (Format-Migration).
  **B1a ✓ a137976f7** — `ClipStore.slotCount` 64, ein altes 8er-Gitter öffnet sich im größeren (`migratedGrid`), gespeichert wird das Präfix bis zum letzten belegten Platz (`storedGrid`, min. 8 — ein Rückfall auf einen alten Build behält bis zu 8). Wächter `TheOldPartGridOpensInTheLargerOneTests`. Rückfall-Kosten: Inbox H8. **B1b HOLD** — Undo-Schritt für den geprägten Teil, nur MIDI, Tür-Ort, plus Founder-Frage H9.
- **B2** Presets je Spur + Sampler wählbar. **B2a ✓ 8d48d0461** — Klang-Menü (`TrackMix.setSound` → `setLanePatch`, dessen erster Produktions-Aufrufer) nur auf POLY-Rack-Spuren; Standard = kein Spur-Patch, Wahl = Kopie, fremde Kopie heißt „In diesem Stück“. Wächter `TheTrackChoosesItsSoundTests`. **B2b ✓ 1df12b6db** — eine Klangwahl ist EIN Undo-Schritt (`.lanePatch`, beide Klänge als Werte, über `editLanePatch`; `setLanePatch`/`setSound` bleiben roh). Wächter `TheSoundChoiceIsOneUndoStepTests`. Offen: Sampler-Wahl.
- **B3** Mixer-Ansicht (alle Spuren als Kanalzüge) + Mixer-Undo. **✓ ec276058b (Ansicht)** —
  `PieceMixerView` hinter dem Reiter „Mix“ (Tor `showsSongs`), steht STATT des Arrangements (ein
  Bedienelement pro Tatsache auf dem Schirm). Kanalzug = `TrackMix.controls` (keine zweite Regel),
  Schreiben nur über `TrackMix.*`; stumme Spuren ohne Zug, aber gezählt. Pegel-Hinweis als
  `TrackMix.levelHint` gehoben (#416). Arrange ist jetzt ein Knopf (zwei Ansichten der Platte).
  **B3b ✓ 5de7b12f4** — `.laneMix` als fünfte Schritt-Art über einen GETRENNTEN Nutzer-Pfad (`editLaneMix`/`commitLaneMix`), eine Geste = ein Schritt; Undo setzt nur Felder zurück, die die Geste geändert hat UND die noch ihr Ergebnis tragen (Review D1); der Agent-Pfad `TrackMix.setLevel` bleibt draußen. **B3c ✓ e0e28f83a** — Inspektor (Pegel/Pan mit `onCommit`), Spurkopf M/S und Perform-Gitter laufen jetzt durch `editLaneMix`/`commitLaneMix`; Wächter `EveryHandMadeMixChangeIsOneUndoStepTests` (Zensus: jeder Nicht-Agent-Schreiber umhüllt). Dazu **bc907d1eb**: `TheWorkstationHasADoorTests` Anspruch E war seit A7 rot (zwei Wächter widersprachen sich) — eng auf die EINE `@AppStorage`-Lesung von A7 ausgenommen. Wächter `TheMixerGestureIsOneUndoStepTests`. Meter = B5.
  ⚠️ B3b gemessen und VERTAGT: `TheAgentActsThroughTheButtonsPathsTests` verlangt, dass der
  Agent-Pfad über `TrackMix.setLevel` KEINEN Song-Undo-Schritt schreibt — ein Undo im geteilten
  Schreiber bräche das; es braucht einen getrennten Nutzer-Schreiber. Eigene Scheibe.
- **B4** Song-MIDI-Export (alle Spuren). **✓ a6729b78e + Review-Reparatur ff5a7c907** (Transposition je Spur angewendet, `sounding`; Kopf sagt „wie platziert“ und nennt die drei Abweichungen zum Transport; `.buttonStyle(.plain)`) — letzter Reiter „Export“ = `ShareLink`
  im eigenen Blatt (`SongExportTab`, kein Modal, Tor `showsSongs`, gedimmt+inert ohne Note).
  `SongMIDIExport` fragt die drei Regeln des Spielers (`midiLaneIDs` · `executableNotes` ·
  `activeRegion`), schreibt Format 1 (Dirigent + eine Spur je MIDI-Spur, Kanal 10 übersprungen,
  Ende = letzter ganzer Takt). Tempo über `preflightTempo` beim Teilen. Stummgeschaltete Spuren
  werden geschrieben; Pegel/Pan/Klang nicht (der Hinweis sagt es). Wächter
  `ThePieceExportsTheSongAsMIDITests`; `ThePieceHasTabsTests` FX-Tor neu verankert.
- **B5** Per-Spur-Meter-Quelle (Audio-Thread-Review, Gerät).
- **B6** Velocity-Spur + CC-Spuren im Noteneditor; Import behält CC/Bend/Pressure. **B6a ✓ 7e12f1976** — `PartVelocityLane` unter dem Gitter (Tipp = eine Spalte, Halten+Ziehen = Gerade, EIN `setClipNotes` beim Loslassen = ein Undo-Schritt). Wächter `TheVelocityIsDrawnUnderTheNotesInOneStepTests`. **B6b-0 ✓ 02a68bcaf** — der MIDI-Import sagt, was er weglässt (Pedal; Bend/Aftertouch/Controller-ÄNDERUNGEN, nur auf Kanälen mit Noten im Teil). Wächter `TheMIDIImportSaysWhatItLeavesOutTests`. **B6b HOLD** (nichts spielt ein gespeichertes Controller-Ereignis). **B6b-1 ✓ 72c3b04e2** — das Haltepedal verlängert die Noten, die es hält (pro Kanal: erstes Heben an/nach dem Loslassen, Neuanschlag gleicher Höhe, sonst Kanalende); die Landezeile zählt die verlängerten Noten statt das Pedal als weggelassen zu nennen. Wächter `TheSustainPedalLengthensTheNotesItHoldsTests`.

### Phase C — Multimedia-Spuren (die Lücke, die niemand besetzt)
- **C1** `visual.*`-Parameter (Intensität, Bewegung, Farbton, Detail, Blend) registriert,
  Automations-Zustand AUSSERHALB von `@AppStorage`/SwiftUI, gelesen in `draw(in:)`.
  ⚠️ **Verengt auf EINEN Parameter (2026-10-01):** nur `visual.creative.intensity` (Owner
  `VisualCreativeState`, Slew = FlashGuard 0,30/s, beide Eignungen verweigert). Bewegung, Farbton,
  Detail und Blend brauchen je eine eigene Flash-/Sprung-Analyse und kommen einzeln nach C2.
  **✓ 357067db2** — Registry → Deskriptor → Router → `VisualCreativeState`, pro Bild in `MetalBioView.draw(in:)` mit Slew gelesen; kein Produktions-Schreiber (beide Eignungen verweigert). Wächter `TheVisualIntensityIsACanonicalParameterTests`. Gerät: H10.
- **C2** Visual-Spur (Kurven) + domänen-bewusster Automations-Editor + Play-Gate für Kurven-Songs. **C2a HOLD — Inbox H12** (Entwurf fertig, Runde 4): hebt die C1-Sperre auf; die Blitzgrenze des Bildes mit Verstärkung bis ~2,8× ist nur am Gerät belegbar.
- **C3** Licht-Spur: Look-Intensität automationsfähig (nur dämpfend, FlashGuard bleibt; KEIN Strobe). **C3a ✓ fd782725b** — die Look-Stärke gleitet mit höchstens 0,3/s (0,10 × 3 Hz) in beiden Sendern, heute byte-gleich. Wächter `TheLightLookMovesNoFasterThanTheFlashLawTests`. C3b (Kurve + Eignung) offen. Befund dabei: Musik-Dimmer → Inbox H11.
- **C4** Raum: Szene app-weit aus der Zeitleiste, Stream-Schalter mit Tür; Bewegungs-Spur. **C4a-1 ✓ 358afe0a1** — `EchoelmusicApp` baut die Szene aus den Spuren (Start + jede Dokument-Änderung, an `onDocumentChanged` GEKETTET), Routing-Schalter „Every track as its own object (ADM-OSC)“ = erste Tür zu `streamsScene` (nicht persistiert; leeres Stück sendet im An-Zustand nichts — der Text sagt es). Wächter `TheTrackObjectsFollowThePieceAndHaveASwitchTests`. Offen: C4b Bewegungs-Spur (Automations-Schreiber für Objekt-Positionen), danach der Space-Reiter.
- **C5** Bereichs-Tabs Music · Visual · Light · Space. **✓ 9c4bb62b8 (Music · Visual · Light)** — Visual → Feld-Panel (ungegatet wie die Bereichszeile), Light → Routing (Empfänger verweigert, solange FX/Live Colabo offen sind). **Space bleibt auf HOLD bis C4** (heute nur die ADM-OSC-Zeile im Routing = zweites Wort für Light). ⚠️ Gebaut VOR C2–C4: kommt mit C2 ein Visual-Kurven-Track, muss die Visual-Tür eventuell umzeigen. Wächter `TheDomainTabsOpenOnlyWhatExistsTests`.

## Gesetze, die jede Scheibe einhält
Kein neues `.sheet` (Budget 12/14; Inspektoren inline) · keine heißen Reads in Vorfahren
(`TheMenuHostReadsNoHotStateTests`) · `EchoelStudioView` bleibt montiert · Uncodixfy (kein Glow,
Radius ≤ 12, Primär monochrom) · Zahlen = `EchoelValueField` · deutsche Chrome über den Katalog ·
nichts behaupten, was nicht klingt/leuchtet (CLAIMS.md) · iPad bleibt founder-gated (`project.yml`).
