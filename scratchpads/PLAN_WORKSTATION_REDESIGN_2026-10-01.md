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
- **A1b** Teile tragen ihren Namen (Clip-Name im Block, 11 pt).
- **A2** Genre raus aus dem Kopfstreifen → „Stil" am Echoel-Gerät (eine Tür). A2b: Stil-Wahl
  schreibt Tonart/Stimmung nicht mehr (WA2-Bindung). **✓ A2 b006cdbd1** (A2b offen).
- **A3** Feste Transportleiste unten auf der Stück-Bühne (⏮ ■ ▶ ● Klick · Position · Pegel);
  `transportRow` mitten im Scroll entfällt. EIN Transport (`ProjectTransport`). **✓ dbbe191cf**
  (Scroll in `WorkstationView`, `transportBar` per `safeAreaInset`). A3b offen: Kopf-Play und
  Leisten-Play doppeln sich auf der Stück-Bühne — Kopf-Play bleibt für die Instrument-Bühne.
- **A4** Kopf-Anzeige: Song-Position TAKT.SCHLAG.16tel · BPM · 4/4 · Tonart.
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
  Start/Ende/Länge als `EchoelValueField`. **✓ a5748ed13** — Kopf der offenen Spur trägt Farbband + Symbol der Rinne (`TrackHue`); die Teil-Felder standen schon in `SelectedPartBar`. Segmente Spur/Teil/Gerät offen.
- **A9** Querformat: drei Spalten (Spuren+Browser | Arrange+Editor | Inspektor+Visual). **✓ ceb9ede82** — als ZWEI Spalten am Telefon (Arrange+Editoren | Spurköpfe+Inspektor, 260–360 pt), per `AnyLayout`, damit eine Drehung keinen Schalter zurücksetzt; die dritte Spalte (Visual) ist die schwebende Karte. M/S in der Rinne bleibt Founder-Frage (H5).

### Phase B — Engine-Glaubwürdigkeit
- **B1** 8-Clip-Decke heben + „Eigenständig machen" beim Duplizieren (Format-Migration).
- **B2** Presets je Spur + Sampler wählbar.
- **B3** Mixer-Ansicht (alle Spuren als Kanalzüge) + Mixer-Undo. **✓ ec276058b (Ansicht)** —
  `PieceMixerView` hinter dem Reiter „Mix“ (Tor `showsSongs`), steht STATT des Arrangements (ein
  Bedienelement pro Tatsache auf dem Schirm). Kanalzug = `TrackMix.controls` (keine zweite Regel),
  Schreiben nur über `TrackMix.*`; stumme Spuren ohne Zug, aber gezählt. Pegel-Hinweis als
  `TrackMix.levelHint` gehoben (#416). Arrange ist jetzt ein Knopf (zwei Ansichten der Platte).
  **Offen: B3b Mixer-Undo** (eigener `HistoryStep`, nicht in der Teil-Historie) und Meter (= B5).
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
- **B6** Velocity-Spur + CC-Spuren im Noteneditor; Import behält CC/Bend/Pressure.

### Phase C — Multimedia-Spuren (die Lücke, die niemand besetzt)
- **C1** `visual.*`-Parameter (Intensität, Bewegung, Farbton, Detail, Blend) registriert,
  Automations-Zustand AUSSERHALB von `@AppStorage`/SwiftUI, gelesen in `draw(in:)`.
- **C2** Visual-Spur (Kurven) + domänen-bewusster Automations-Editor + Play-Gate für Kurven-Songs.
- **C3** Licht-Spur: Look-Intensität automationsfähig (nur dämpfend, FlashGuard bleibt; KEIN Strobe).
- **C4** Raum: Szene app-weit aus der Zeitleiste, Stream-Schalter mit Tür; Bewegungs-Spur.
- **C5** Bereichs-Tabs Music · Visual · Light · Space.

## Gesetze, die jede Scheibe einhält
Kein neues `.sheet` (Budget 12/14; Inspektoren inline) · keine heißen Reads in Vorfahren
(`TheMenuHostReadsNoHotStateTests`) · `EchoelStudioView` bleibt montiert · Uncodixfy (kein Glow,
Radius ≤ 12, Primär monochrom) · Zahlen = `EchoelValueField` · deutsche Chrome über den Katalog ·
nichts behaupten, was nicht klingt/leuchtet (CLAIMS.md) · iPad bleibt founder-gated (`project.yml`).
