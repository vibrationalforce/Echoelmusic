# ULTRA-MASTERPLAN — 2026-10-16

| | |
|---|---|
| **Datum** | 2026-10-16 |
| **Branch** | `claude/echoelmusic-review-optimize-u5jjpd` (laut `.deploy/release`, live: `git branch --show-current`) |
| **Ausgeliefert** | v10.79.508 (`.deploy/release` Zeile 1) |
| **Gemessen an** | HEAD `4dbcfc6` (Gatherer plan/board) und `9e570bc` (Gatherer founder/code). ⚠️ Das sind **zwei verschiedene HEADs**. Ein Befund, der nur an einem gemessen wurde, steht unten mit seinem SHA. |
| **Zieldatei** | `scratchpads/ULTRAMASTERPLAN_2026-10-16.md` |

**Was dieser Plan ist:** Er bringt die offene Arbeit in eine Reihenfolge. Jeder Posten ist gegen den Code geprüft. Er gilt **unter** `docs/dev/FOUNDER_PRODUCT_LAW.md` (volle DMMW: das Ökosystem anbinden, Spezial-Infrastruktur nie selbst nachbauen) und **unter** `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` (WA1–WA4). **Er setzt keins von beiden außer Kraft.**

⚠️ **Vorschlag an dich, keine Entscheidung:** Laut CLAUDE.md ist WA3 als Nächstes dran (Geräte-Instanzen: WA3-S3/S4, PRE2/PRE3). Dein Fokus vom 2026-10-15/16 lautet aber: Produktion zuerst, entspanntes MIDI-Editieren, jede sichtbare Funktion arbeitet von Ende zu Ende. Dieser Plan zieht deshalb **WA4-Edit- und Export-Scheiben vor WA3-S3/S4**. WA3-S3 hat heute keinen sichtbaren Nutzen („internal plumbing; nothing user-visible until a second instance"). Willst du die WA-Reihenfolge behalten, verschieben sich Track A und C hinter Track E/WA3. → Frage **F-0** unten.

**Schon in dieser Sitzung erledigt, steht hier nicht als offen:** EP-7, EP-8, EP-9, EP-10, EP-11, Deploy 10.79.508.

---

## 1. Tracks

Legende: Aufwand **S**/**M**/**L** · Nutzen **hoch**/**mittel**/**niedrig** · Gate **P** = proceed · **C** = erst Plan + Council · **F** = Founder · **D** = erst Gerät

### Track A — MIDI-Edit von Ende zu Ende
**Ziel:** Ein MIDI-Teil lässt sich entspannt sehen, verschieben, kürzen, kopieren und exportieren, ohne dass dabei still etwas verloren geht.

| # | Scheibe | Aufw. | Nutzen | Beleg | Wächter, den sie braucht | Gerätecheck, den sie erzeugt | Gate |
|---|---|---|---|---|---|---|---|
| A1 | **HIDDEN-NOTES**: sichtbare Zahl bzw. Marker „N Noten hinter dem Ende" | S | mittel | `Studio/SelectedPartBar.swift:1124`: einziger Hinweis, nur VoiceOver-`hint:` | `TheHiddenNotesAreVisibleTests`: Zähltext erscheint, wenn Noten jenseits `region.length` liegen | Teil kürzen → Hinweis sichtbar? | P |
| A2 | **N2a** Tastatur-Spalte links im Notengitter | M | hoch | `Studio/PartNoteEditor.swift:206` `rowHeight = 24` fest, `:995` „reads without a keyboard" | Spalte rendert die Tonnamen der sichtbaren Zeilen und liest keinen heißen State (#menu-freeze) | Tonhöhe ablesbar ohne Raten? | P |
| A3 | **N2b** vertikaler Zoom (Zeilenhöhe) | S–M | hoch | wie A2 | Zeilenhöhe begrenzt, Treffer-Mathe (`RollHitTest`) skaliert mit | Pinch vertikal, Treffer stimmen | P |
| A4 | **WA4-DRAG-XTRACK** Teil auf eine andere Spur ziehen | M | hoch | `Core/TimelineStore.swift:720` `laneOffset:` hat nur die Deklaration. UI ruft nur `moveRegion(id:toStartTick:)` (`Studio/TrackPartsView.swift:218`) | `laneOffset:` hat genau einen Produktions-Aufrufer, ein Undo-Schritt | Ziehen über Spurgrenze, Undo | P (>3 Dateien → C-lite) |
| A5 | **EP-6b** unabhängige Kopie nach Repeat/Duplicate | M | hoch | `Core/TimelineStore.swift:668-692` teilt `clipID`. `makeUnique` hat 0 Treffer. `PartNoteEditor.swift:386` zeigt „a change edits all of them" | Kopie hat eigenen Clip-Slot, ein Undo-Schritt, Slot-Kapazität wird geprüft | eine Wiederholung variieren | **F (H9)** dann C (ClipStore-Slot vs Undo) |
| A6 | **MIDI-IMPORT-META** Verluste in der Erfolgsmeldung nennen (Tempo, Taktart, Program Change, CC) | S | niedrig | `Sequencer/MIDIImport.swift:30-44` „still unread AND unsaid" | Meldungstext nennt die nicht gelesenen Arten | — | P |
| A7 | **N3b** Triolen- und 1/32-Raster | S | mittel | `Sequencer/ClipNoteEdit.swift:206-218` `QuantizeGrid {16,8,4}` | — | — | **erst nach B1** (sonst zieht die Wiedergabe auf 16tel) |
| A8 | **N5** CC/Pitch-Bend/Pressure-Spur | L | mittel | `Studio/PartVelocityLane.swift:23-26` | Clip-Controller-Event-Modell zuerst | — | C |
| A9 | **TOOL-MODES** Add · Move · Lengthen | M | mittel | kein Modus-Enum in `PartNoteEditor.swift` | — | — | **D** (nur wenn das Gerät Fehlgriffe zeigt) |
| A10 | **EP-5-Rest** Zoom über 8× | S | niedrig | `Studio/ArrangeTimeZoom.swift:57` `1...8`. Snap nach sichtbarer Breite ist schon da (AE-11, `ArrangeCanvasView.swift:216-230`) | Texturgrenze gemessen | — | P (nach Texturmessung) |
| A11 | **VO-LENGTHEN / AE-VO** VoiceOver-Aktionen für Kanten | S | niedrig | `ArrangePartEdgeHandles.swift:34-35`, `AudioPartEditorView.swift:547-549`, `accessibilityAction(named` hat 0 Treffer | — | — | P |

### Track B — Wiedergabe-Präzision
**Ziel:** Noten klingen dort, wo sie stehen, unabhängig von der Last auf dem Main-Thread.

| # | Scheibe | Aufw. | Nutzen | Beleg | Wächter | Gerätecheck | Gate |
|---|---|---|---|---|---|---|---|
| B0 | **FV-REC-Baseline** vor dem Umbau abhören (16 Takte, Click an) | S | hoch | `PatternEngine.swift:679`, `MetronomeVoice.swift:321` | — | Referenzaufnahme | D |
| B1 | **T-1** Noten render-seitig von einer Host-Time-Uhr planen | L | hoch | `Studio/PianoRollView.swift:1126` `$0.startStep == step`. `Sequencer/PatternEngine.swift:381,599` `makeTimerSource(queue: .main)` | Audio-Thread-Bann (kein malloc/Lock), eine Uhr (Entscheidung 2026-08-23 C2, Review fällig) | Timing unter Last | **C** (Audio-Thread) |
| B2 | **INSTR-SHADOWS-PART** laufendes Instrument tauscht alle 25–45 s die Rolle des Workstation-Teils | M | hoch | `Sequencer/MIDIImport.swift:45-49`. Halb behoben: `EchoelStudioView.swift:11438` (S2) verhindert nur das Anlegen | Rolle des Nutzerteils wird von `evolve` nicht neu geladen | Instrument läuft + Teil spielt | C (eigene Roll-Lane-Stimme oder nach B1). Wiegt schwerer, seit der Start auf **Instrument** steht |
| B3 | **M7-LOW-3** Song-Play mitten im Takt wiederholt einen Takt | S | niedrig | möglicherweise mit M5 behoben (`TimelineRegionPlayer.swift:1473-1483`). `play()` ist nicht nachgemessen | — | Repro auf Gerät | erst `play()` lesen |
| B4 | **AU-2** sample-genaue Noten an gehostete Plugins | M | mittel | `Audio/HostedInstrumentHost.swift:14-16` `AUEventSampleTimeImmediate` | — | — | nach B1 |
| B5 | **SECONDARY-LANE-EXPR** Rack-Spuren ohne Operatoren/Bio/MPE | M | niedrig | `Sequencer/LaneNotePump.swift:9-10` | — | — | nach B1 |
| B6 | **SUBBAR-LAUNCH / D2-LAUNCHQUANT** | M | niedrig | `TimelineRegionPlayer.swift:1790` | — | — | später |

### Track C — Export
**Ziel:** Antippen und exportieren. Jede Tür sagt, WAS sie schreibt, und der Bounce hängt nicht davon ab, was gerade zu hören ist.

| # | Scheibe | Aufw. | Nutzen | Beleg | Wächter | Gerätecheck | Gate |
|---|---|---|---|---|---|---|---|
| C1 | **MIDI-DOORS** Titel benennen den Umfang („Take .mid" / „Song .mid") | S | mittel | `EchoelStudioView.swift:2483-2492` „MIDI" (Take). `SongExportTab.swift:77-85` „Export" (ganzer Song). Nur die a11y-Hints unterscheiden sie | Titel tragen den Umfang. Kopie in `fastlane/metadata` bleibt unberührt (MIDI-Export ist dort behauptet) | — | P |
| C2 | **MIDI-PART-EXPORT** Zeile „Part .mid" in `SelectedPartBar` über den **vorhandenen** Share-Slot | S | hoch | `Sequencer/MIDIFileExporter.swift:203` `export(clip:tempo:)` hat 0 Aufrufer | genau ein Produktions-Aufrufer, **kein neuer `.sheet`** (Kette 11/12, Decke 14) | .mid in einer DAW öffnen | P |
| C3 | **C4-OFFLINE-BOUNCE / WAV-REALTIME** schneller als Echtzeit, Umfang wählbar | L | hoch | `enableManualRenderingMode` hat 0 Treffer. `Studio/PieceAudioExportTab.swift:106`. `SingleExport.swift:131` Limiter-Zustand | Graph-Lebenszyklus-Leiter (Sprossen VOR Aufruf), Limiter-Zustand wird zurückgesetzt | Export-Dauer, Klanggleichheit | **C** (Audio-Graph) |
| C4 | **STEM-EXPORT** `StemCaptureSession` hat keinen Aufrufer | M | mittel | `Audio/StemCaptureSession.swift:53`, 0 Konstruktionen | — | — | zusammen mit C3 entscheiden |
| C5 | **TRUE-PEAK-LIMIT** beim Export | M | niedrig | nur das Meter existiert (`AudioEngine.swift:255,269,284`) | — | — | nach C3 |

### Track D — Arrange / Session (WA2/WA4-Eigentum)
**Ziel:** Ein gespeicherter Song kommt vollständig zurück. Es gibt keine zwei Wahrheiten über dasselbe.

| # | Scheibe | Aufw. | Nutzen | Beleg | Gate |
|---|---|---|---|---|---|
| D1 | **RACK-CAP-Rest** Satz zur Kapazität in `addedTrackNote` + Marker auf der Arrange-Spur | S | mittel | `Sequencer/MIDIImport.swift:159-166` hängt ohne Prüfung an. Device-Zeile und Noten-Editor nennen es schon (`TrackInspectorView.swift:198-200`, `PartNoteEditor.swift:117-123`) | P. Kapazität > 4 nur **D** (CPU) |
| D2 | **INSTANCE-GAPS** Bus-Inserts, Live-FX-Parameter, `delaySync` im Instanzzustand | M | mittel | `Core/EchoelInstanceState.swift:29-32` | C |
| D3 | **WA2-MIGRATE** Wurzeln in die kanonische `DMMWProject`-Session | L | mittel | Envelope hat jetzt einen Aufrufer (`SessionSaveOpen.swift:106`). Besitz ist nicht migriert | C |
| D4 | **WA4-SONGFORM-RESTORE / WA2-ARRANGEMENT-PROJ** | S–M | niedrig | `SessionSaveOpen.swift:36,147-151`, kein Leser von `ArrangementStore` | erst wenn eine Fläche liest |
| D5 | **WA4-AUTOMATION-SAVE / AUTOMATION-GLOBAL-LANES** | S–M | niedrig | `EchoelStudioView.swift:11868-11874` `playerAutomation: []`, `AutomationPlayer.swift:513-624` hat 0 externe Aufrufer | nicht abklemmen (#527) |
| D6 | **A2/A3** Kurvenformen, Latch/Touch-Aufnahme | M | mittel | `AutomationPunch.swift` fehlt. A2-Beleg zeigt auf die Velocity-Spur, also neu messen | C (mix.gain double-apply) |
| D7 | **M1b-0** TakeAnchor | S | mittel | `TakeAnchor` hat 0 Treffer | P |
| D8 | **WA4-P9-PATCHNAME** Patchname in der Echoel-Spurzeile | S | niedrig | `Studio/EchoelInstanceLine.swift:19` | P |

### Track E — Mixer / Plugins
**Ziel:** Gehostete Plugins laufen im Takt mit, Effekte klingen, ein Pick mitten im Spiel reißt nichts ab.

| # | Scheibe | Aufw. | Nutzen | Beleg | Gate |
|---|---|---|---|---|---|
| E1 | **RC-R2** Plugin-Load bis zum nächsten Stop zurückhalten (statt `masterEngine.pause()` beim Region-Onset) | S | mittel | `AudioEngine.attachAudioUnit` `if wasRunning { pause() }`, `HostedInstrumentHost.swift:340-342` | C-lite (Engine-Lebenszyklus) |
| E2 | **AU-T** `musicalContextBlock` + `transportStateBlock` für gehostete Instrumente | M | hoch | 0 Treffer in `Sources` | **C** (Blöcke laufen auf dem Render-Thread) |
| E3 | **RC-R4** Invalidierung zusätzlich vergleichen, unbekannte loggen | S | niedrig | `HostedInstrumentHost.swift:398-400` | P |
| E4 | **H6-5** Effekt-Host + Insert in den Spur-Bus | L | hoch | `Core/PluginEffectInsert.swift` hat den Werttyp, `pluginEffect(` hat 0 Aufrufer. `TrackPluginRow.swift:20` „listed only" | **C** + Gerät |
| E5 | **H6-6** Tür auf der Device-Seite | M | hoch | wartet auf E4 | nach E4 |
| E6 | **AU-P** Plugin-Parameter automatisieren | M | mittel | kein Host-Code liest `parameterTree` | nach Gerätecheck |
| E7 | **D2-AUTOMIX-LUFS** Auto-Gain aus integrierter LUFS statt RMS | M | mittel | `Audio/AutoMixChain.swift:445-453` | C |
| E8 | **C6-MASTER-COMP**, **SENDS-RETURNS** → B3-SPACEREVERB, B2-FDN | M–L | mittel/niedrig | je 0 Treffer | C |
| E9 | **HW-7** MIDI-Ziel je Nachrichtenart | M | mittel | `Audio/MIDIOutput.swift:767,850-864` sendet an alle Ziele | P. Danach HW-8..11 (HW-11 Kanal-10 vorziehen, wenn ein TR-8S hängt) |
| E10 | **MIDI-OUT-RACK** Rack-Spuren-Noten nach CoreMIDI | M | mittel | `EchoelmusicApp.swift:1207-1220` ohne `midiOut` | nach E9 |
| E11 | Echoel-als-AUv3: PLUG-2 Host-Tempo, PLUG-3 Poly/Bend/CC, PLUG-4 resizable, A11 Textur-Default 0 | S–M | niedrig | `musicalContextBlock` hat 0 Treffer in `Sources/EchoelmusicAUv3`, `AudioUnitViewController.swift:29`, `EchoelBodyVibeDevice.swift:279-287` | P (A11 erst nach CPU-Messung) |
| E12 | **A3-DEADFX** `BioReactiveSynthVoice.fxChain` läuft nie | S | niedrig | `Tools/BioReactiveSynthVoice.swift:51,318,326-328` | P |

### Track F — UI / Design
**Ziel:** Weniger Doppeltüren und lesbare Flächen, ohne neue Bühne und ohne neues Modal.

| # | Scheibe | Aufw. | Gate |
|---|---|---|---|
| F1 | **KANDIDAT-B** (f) Tempo an EINER Stelle · (e) Field 4 + Mehr · (d) Routing „Erweitert" · (h) 9→6 Chips. Belege: `BodyTempoField.swift:338`, `WorkspaceView.swift:1427-1436`, `memory/decisions.md:5334` | M | **D** (nach Gerätesession 1) |
| F2 | **D2** antippbare Rahmen auf `borderStrong`. Teilweise erledigt (56 Treffer), Rest je Datei nachmessen | S | P (erst messen) |
| F3 | **D3-Rest** 2 UI-Stellen `.caption2` monospaced (`EchoelStudioView.swift:9449`, `SafeModeView.swift:112`), vermutlich Absicht | XS | P |
| F4 | **S10** Modal-Konsolidierung in den Shell-Slot | M | C (render-safety) |
| F5 | **D4/D5** Dynamic Type accessibility3 | M | D (Session 2) |
| F6 | **AU5** Meter-Props `@ObservationIgnored` (präventiv) | M | C |

### Track G — Ship / CI / Hygiene
**Ziel:** Ein grünes Häkchen beweist, was es behauptet, und die Register lügen nicht.

| # | Scheibe | Gate |
|---|---|---|
| G1 | Doku-Drift aus §6 (Session-fähiger Teil) | P |
| G2 | **NEXTBUILD-WS + FV-EDIT** in ≤5 Familien bündeln (siehe §5) | P |
| G3 | **IMPORTMIDI-INSTRUMENT** `EchoelStudioView.swift:12307` hat 0 Aufrufer. CLAUDE.md führt es bewusst als „übrig". Entfernen nur mit Prosa-Zug in CLAUDE.md, das gerade eingefroren ist | F-light |
| G4 | **DEAD-FLAGS** 10 Flags ohne Leser | P (Council: Löschung) |
| G5 | **OSC-LOOP** 8-s-Fehler, Testname unbekannt | braucht Log |
| G6 | **INBOX-S4** `./review.sh` → **845** fällig. Nur stapelweise triagieren | P (Vorbereitung), F (Urteil) |
| G7 | **XCR-23**, **HOLD-CI-TESTED**, **E29**, **F2–F6**, **F15/F16** liegen in founder-gated Workflows | F |
| G8 | **WA3-PRE2** `PianoRollModel` aus `PianoRollView.swift:109` herausziehen (Prosa-Zitate im selben Commit) | P (nach CLAUDE.md-Unfreeze) |

### Track H — Bio / Visual / Licht / Raum (nicht auf dem Produktionspfad)
| Posten | Beleg | Gate |
|---|---|---|
| **H11** Musik-Modus-Dimmer ≈ 2,4/s gegen eine 0,5/s-Bremse. **Sicherheitsgesetz** | `Sync/MusicMediaMapping.swift:23`, `ArtNetSender.swift:466-474`, `SACNSender.swift:288` | **F** (eine Konstante), vorziehen |
| SPATIAL-RENDER (7 Kerne), G1-FIXTURES, FLUID-F2..F5, IMMERSIVE-STAGE-DOOR, BIO-DOORLESS, CORES-NOCALLER, FOLLOW-PULSE-TWIN | je 0 Aufrufer | später / P |
| V1–V4, GM2/GM3/GM4, H12 | Inbox | F |
| WA3-MODMATRIX-INSTANCE, I-BIO-FUTURE, D8-MPE-ZONES | — | später |

### Track I — Plattform / Instrument-Kerne
| Posten | Gate |
|---|---|
| WA3-PRE3 (ein Realtime-Kanal), WA3-S3 Resolver, WA3-S4 zweite Instanz, WA3-DEVSTATE-CALLER | C. Nach Vorschlag F-0 hinter A/C |
| SP-3 In-App-Drums (`BioComposer.swift:1153` `silentBeat()`), SP-4 Acid, SP-5..7, A7 Karplus, A8 Ladder, A9 Drums, A4/A5 | C, nach B1. GM5 ist zuerst zu beantworten |
| SP-1 Psychedelic-FX-Charakter (keine neue DSP) | P |
| HW-3 Ausgangszahl anzeigen | P |
| HW-4/5 Multi-Out | C + D |
| WATCH-B-E, PLATFORMS-GM16, HOLD-95, BROADCAST-S2/F14, J-NET, VST3-CLAP, E1-AUDIO-INPUT/E10-J0 | F |

---

## 2. Die nächsten 12 Scheiben

Jede Scheibe ist eine Änderung mit einem Wächter. Kein neues Modal, keine neue Bühne. Zahlen laufen über `EchoelValueField`.

| # | Scheibe | Track | Aufw. | Warum jetzt | Council? |
|---|---|---|---|---|---|
| 1 | **DOC-EDGE-VERIFY**: `ArrangePartEdgeHandles.swift:37-38` „moves by bars" → Zoom-Raster (EP-11) | G | XS | Sonst prüfst du am Gerät ein Verhalten, das es nicht mehr gibt | nein |
| 2 | **Gerätebogen**: `DEVICE_SESSION_1_2026-10-17.md` auf 10.79.508 heben und NEXTBUILD-WS + FV-EDIT in ≤5 Familien bündeln (§5) | G | S | Gerätesession 1 gibt TOOL-MODES und Kandidat B frei | nein |
| 3 | **C1 MIDI-DOORS** Umfang in die Titel (Take/Song) | C | S | Billig, beseitigt eine Doppelbedeutung | nein |
| 4 | **C2 MIDI-PART-EXPORT** „Part .mid" über den vorhandenen Share-Slot | C | S | Fertiger, getesteter Exporter ohne Tür. „Dieser Teil in meine DAW" | nein (kein neues Sheet) |
| 5 | **A1 HIDDEN-NOTES** sichtbarer Zähler | A | S | Stiller Verlust im ersten Fokus | nein |
| 6 | **D1 RACK-CAP-Rest** Kapazitätssatz + Arrange-Marker | D | S | Eine 5. Spur bleibt sonst still, ohne dass es jemand sagt | nein |
| 7 | **A6 MIDI-IMPORT-META** Verluste nennen | A | S | Ehrlichkeit beim Import, 1 Datei | nein |
| 8 | **A2 N2a** Tastatur-Spalte | A | M | Kern-Affordanz für entspanntes MIDI | nein (Leaf-Read beachten) |
| 9 | **A3 N2b** vertikaler Zoom | A | S–M | Gehört zu A2 | nein |
| 10 | **A4 WA4-DRAG-XTRACK** | A | M | Store kann es, die Geste fehlt | ja, lite (>3 Dateien möglich) |
| 11 | **E1 RC-R2** Load bis Stop zurückhalten | E | S | Pick mitten im Spiel pausiert die Engine | **ja** (Engine-Lebenszyklus) |
| 12 | **B1 T-1: Plan + Council** (nur Dokument, kein Code). Danach AU-T (E2) | B | S (Plan) | Fundament für N3b, AU-2, SP-3, HW-10. **Vorher B0-Baseline am Gerät** | **ja** (Audio-Thread) |

**Abhängigkeiten:** A5 (EP-6b) wartet auf H9. A7 (N3b) wartet auf B1. C3 (Offline-Bounce) bekommt nach Scheibe 12 einen eigenen Council (Audio-Graph). E4/E5 (Effekt-Host) kommen nach dem Gerätecheck FV-AUV3.

---

## 3. Founder-Entscheidungen

„Inbox" heißt: steht schon in `docs/dev/FOUNDER_INBOX.md`, also nicht neu fragen.

| ID | Frage | Empfehlung | Inbox? |
|---|---|---|---|
| **F-0** | Sollen WA4-Edit/Export-Scheiben (Track A/C) **vor** WA3-S3/S4 laufen? | Ja: Produktion zuerst. WA3-S3 hat heute keinen sichtbaren Nutzen | **neu** |
| H9 | Kopie nach Repeat/Duplicate unabhängig oder verknüpft? | Standard unabhängig, verknüpft als Option. Gibt EP-6b frei | ja (`:98`) |
| **H11** | Musik-Modus-Dimmer auf das Flash-Limit bremsen? | **Ja, sofort.** 2,4/s gegen 0,5/s ist ein Sicherheitsgesetz, eine Konstante | ja |
| **LR5** | Die zwei Sätze Offenlegung unter „Diagnose teilen" freigeben? | Ja, **vor** Gerätesession 1, die dich Diagnosen teilen lässt | ja (`:146`) |
| E29 | Workflow-only-Pushes ohne Gate mergen lassen? | Nein: `.github/workflows/**` aus dem Trigger nehmen oder dort gaten. Einzeiler, Sicherheit | ja |
| F15/F16 | `pr-check.yml:119,143` Scheme `Echoelmusic-macOS` existiert nicht. testflight: SHA-Pins + `contents: read` | Patch freigeben | ja |
| F10 | `CFBundleDocumentTypes` für .mid/.wav („In Echoel öffnen") | Ja, Produktionswert | ja |
| GM12 | dSYMs + MetricKit | Ja, hilft beim Absturz-Triage in der Gerätesession | ja |
| E17 | Fünf Anlege-Knöpfe in ein „Add"-Menü (gebaut, `WorkstationView.swift:1151`) | Behalten | ja (`:67`) |
| GM7 | Vier Konsolidierungen (Lautheit am Master, Szenen im Arrange, Compose-Hilfe, ein Tempo-Lock) | Ja, passt zu „jede Funktion tut, was sie sagt" | ja (`:121`) |
| GM15 | „Part" = Editor des gewählten Teils, „Notes"-Seite weg | Erst nach dem FV-EDIT-Gerätecheck fragen | ja (`:130`) |
| GM5 | Sampler-Budget/Slicer | Voraussetzung für Drums (SP-3/A9). Beantworten, bevor Track I startet | ja (`:119`) |
| GM6 | Meditations-Fullscreen-Slot entfernen (`EchoelStudioView.swift:835,1840`, nie `true`) | Ja, gibt Platz in der Sheet-Kette | ja |
| GM18 | `SessionEngine` stumm im Graph, `SessionView` ohne Präsentation | Attach aufschieben | ja (`:132`) |
| GM19 | „Deep Sleep/Meditation"-Labels in `EchoelEntrainment` | Auf Bandnamen umbenennen. **Inbox-Zeile ergänzen:** auch `DSP/EchoelBodyVibeDevice.swift:282` (AUv3-Preset, im Host sichtbar). Deckt WA3-PRESET-SEED mit ab | ja (unvollständig) |
| GM21/F13 | App-Store-Text ohne ARRANGE-Absatz | Session entwirft, du setzt ihn | ja (`:135`) |
| E22 | Toten Code mit Tests löschen (**18** Dateien, nicht 15) | Je Datei freigeben | ja (`:72`) |
| E20 | Echoel als AUv3-Effekt (`aumf`) | Zeile ist veraltet (Autotune/Harmonizer/Granular gestrichen #1305). Session schreibt sie neu, dann fragen | ja (veraltet) |
| WA4-MEDIUM4 | Recovery-Slot behält Session ohne Nutzerteile | So lassen (Absicht) | MASTER_PLAN:461,505 |
| A1e | Automationszeile für den Echoel-Track: was soll sie treiben? | Vor dem Fragen in der Inbox suchen. Im Inbox-Ausschnitt nicht gefunden | **prüfen** |
| DETECTED-KEY-ADOPT | Knopf „erkannte Tonart übernehmen" (schreibt über `SessionContext`) | Ja, ein Knopf, Nutzer entscheidet | **prüfen** |
| CLAUDE.md-Unfreeze | Root-View-Absatz („THE PIECE IS THE HOME") ist seit 2026-10-15 falsch, Start ist Instrument | Freigabe für genau diesen Absatz | `decisions.md:5330` (eingefroren) |
| INBOX-WEB | `docs/faq.html:195` „Video is not part …" stellt das ausgelieferte Video-Lane unter Wert | Deine Formulierung, Wächter `TheShareReadyClipIsNotSoldAnywhereTests:173` zieht mit | Quelle SESSION_LOG, Inbox prüfen |
| REV-STALE | 845 fällige Reviews | Session bereitet Schließ-Stapel vor, du urteilst nur über Scope | ja (§4) |
| Weiter offen, kein v1-Pfad | GM1, GM2(=GM22), GM3/4, GM8, GM9–11, GM13, GM14, GM16, GM17, GM20, E4b, E8/9, E14, E23 (Empf.: Mixer-Seite), E24–27, E30–33, H1/2/6/7, H8, H12, H16/17/19, LR1(=LR6), LR3, LR4, F7–F12, F14, E10-J0, V1–V4, A10-GM-Lizenz, VST3-CLAP, J-NET, WATCH-B-E, HOLD-95/94/58, PROUNLOCK-V11, BROADCAST-S2, DESIGN-R2, XCR-23 | — | ja |

---

## 4. Geräte-Session (≤5 Familien, Stil `docs/dev/DEVICE_SESSION_1_2026-10-17.md`)

`python3 scripts/founder-verify.py` meldet **378 offene Bitten in 326 Dateien, 0 beantwortet** (beide HEADs). Erledigt wird mit `VERIFIED-JJJJ-MM-TT` auf der Marker-Zeile.

| Familie | Inhalt | Erwartung / Hinweis |
|---|---|---|
| **1 Start & Stabilität** | G5, FV-ENGINE (Unterbrechung/Route/Hintergrund, `EchoelStudioView.swift:5088,5153,5209`), die drei 2613-Klasse-Absturzproben, G10 Stillstart/Safe Mode | App öffnet auf **Instrument** (`StudioDefaultKeys.swift:112`), nicht auf Piece |
| **2 MIDI-Edit** | FV-EDIT, EP-7…EP-11, die „+"-Zeile aus DS1, KA-b (ein Play), INSTR-SHADOWS-Repro (Instrument läuft + Teil), M7-LOW-3-Repro, **B0 FV-REC-Baseline** (16 Takte, Click) | Entscheidet TOOL-MODES und Kandidat B |
| **3 Import & Export** | FV-IMPORT (`TempoDetector.swift:180`, `AudioKeyAnalysis.swift:136/143/190`, `AudioTranspose.swift:36`), G7 Sampler-Spur, G9/G10 WAV-Export inkl. FV-EXPORT-Lautheit (`SingleExport.swift:140`), .mid in einer DAW, E3-1..6 Lautheitsmeter bei Routenwechsel, G2/G3 Persistenz | Gate für jede Export-Behauptung |
| **4 Plugins** | FV-AUV3/DS-PLUGIN H1–H6-4 (`HostedInstrumentHost.swift:52`), RC-R2-Repro (Pick beim Spielen), WA3-1…6 (Echoel-AUv3 in AUM), AUV3-OTHER-HOSTS/A10-PLUG-6 (GarageBand/Logic, 44,1 kHz), A11 CPU-Messung, WA4-P10 Akzeptanz-Reise | Gate für E2/E4/E6 |
| **5 Klang, Ausgabe, Layout** | G4/B2-EARS (Ship-Gate 1, dein Ohr), SP-2, FV-UI AX5 + Querformat auf dem kleinsten iPhone, U5/U6, WA4-P2 Relaunch. Nur wenn Zeit ist: FV-VISUAL, FV-BIO/rPPG, H10/G484 (Hardware-Tastatur), G1/FV-SYNC (braucht ADM-OSC-/Lichthardware) | Bio, Sync und Licht gaten v1 nicht |

---

## 5. Doku-Drift

| Datei:Zeile | Steht da | Richtig | Wer darf |
|---|---|---|---|
| `Studio/ArrangePartEdgeHandles.swift:37-38` | „moves by bars" | folgt dem Zoom-Raster (EP-11, `230dd33`) | Session |
| `docs/dev/DEVICE_SESSION_1_2026-10-17.md:1` | Build 10.79.505 | 10.79.508 | Session |
| `docs/dev/DEVICE_SESSION_2026-10-12.md:20` | „öffnet auf dem Stück (Piece)" | Instrument seit 2026-10-15 | Session |
| `docs/dev/FEATURE_STATUS.md:25` / `:92` | v10.79.499 · Build 2624 / `{B}` | Befehl statt Literal | Session |
| `docs/dev/FOUNDER_INBOX.md:7,195` | 280 Bitten / 234 Dateien | Befehl `python3 scripts/founder-verify.py` (#818) | Session |
| `FOUNDER_INBOX.md:116/136`, `:142/147` | GM2 = GM22, LR1 = LR6 doppelt | zusammenlegen | Session |
| `FOUNDER_INBOX.md` GM19-Zeile | ohne AUv3-Preset | `EchoelBodyVibeDevice.swift:282` ergänzen | Session |
| `FOUNDER_INBOX.md:70` E20 | „Autotune · Harmonizer · Granular" | heutigen Umfang schreiben | Session |
| `FOUNDER_INBOX.md` §2 „Ältere offene Bitten" | Familie „launch on piece" | streichen, die anderen vier bleiben | Session |
| `docs/dev/ECHOELMUSIC_MASTER_PLAN.md:216`, `:622` | Plugin hosting **IDEA** | Instrument-Hosting gebaut (`HostedInstrumentHost`, `EchoelmusicApp.swift:1206`), Effekte offen | Session |
| `MASTER_PLAN` §5.2 | „no system ⌘Z yet" | `SongHistoryRow.swift:66,71` | Session |
| `MASTER_PLAN:420-422` | WA4-M1 „logged only" | A1 Schritt 2 (`SessionSaveOpen.swift:70-97`, `EchoelStudioView.swift:11878`) | Session |
| `MASTER_PLAN` WA2 | Importer 0 Aufrufer | `SessionSaveOpen.swift:106` | Session |
| `docs/dev/HISTORY_ARCHIVE.md` next-safe-slices | L2, D6 offen | gelandet. **Eintragsweise** nachführen | Session |
| `DSP/EchoelDDSP.swift:39`, `:54` | „LF/HF → Reverb", „multi-band FIR noise" | Kopf korrigieren | Session |
| `decisions.csv` | keine Zeile zu 14-Tage-Plan / Editor-Urteil (`grep -c` = 0) | Zeilen anhängen (+ `memory/decisions.md`) | Session |
| Testname/Prosa `TheAppOpensOnThePieceTests` | „Piece" | pinnt nur den `.small`-Karten-Seed. Umbenennen nach #374 | Session (mit Prosa-Zug) |
| `CLAUDE.md` Root-View-Absatz | „THE PIECE IS THE HOME … default Piece" | Instrument (`StudioDefaultKeys.swift:100-112`) | **Founder** (eingefroren) |
| `docs/faq.html:195` | Video nicht Teil der App | Video-Lane ausgeliefert | **Founder** + Wächter |
| `LICENSE:3` | 2024-2025 | Jahr | Founder (E31) |
| Brief „Known open" | „rack capacity silent", „zwei Türen beide ‚MIDI export'" | still nur beim Hinzufügen. Titel lauten „MIDI" / „Export" | — |

---

## 6. Erledigt / hinfällig

| ID | Beleg |
|---|---|
| WA4-M1 | `Core/SessionSaveOpen.swift:70-97` + `EchoelStudioView.swift:11878` |
| ADR004-BANNER | `docs/adr/004-cross-platform-strategy.md:12-14` |
| M2 Multicam-Schnitt | `VideoLanePlan.swift:176-185` `programShot` (Gerät offen) |
| RACK-CAP „still" | `TrackInspectorView.swift:198-200`, `PartNoteEditor.swift:117-123`. Rest: D1 |
| EP-5 Snap-Hälfte | AE-11 `ArrangeCanvasView.swift:216-230`. Rest: A10 |
| D3 (13/17 Stellen) | kommentar-gestrippt nur 6, davon 4 AppIcon. Rest: F3 |
| INSTR-SHADOWS-PART Anlege-Hälfte | `EchoelStudioView.swift:11438` (S2). Rest: B2 |
| PLUG-3 Velocity | `EchoelmusicAudioUnit.swift:735-736` |
| D2 teilweise | `borderStrong` 56× |
| WA2-MIGRATE Importer-Prämisse | `SessionSaveOpen.swift:106` |
| O7 | Bühne absichtlich ohne Tür |
| FV-BLOCKED | `AudioConfiguration.swift:372` BLOCKED-BY-#1302, kein Mikrofon |
| G484 Familie 1 | Start ist Instrument |
| DS1-drift-Richtung | Bogen 1 hat recht, falsch sind CLAUDE.md, der 10-12-Bogen und der Testname |
| FV-EXPORT, FV-ENGINE, H10 | Duplikate von G9/G10, G5, G484 |
| M7-LOW-3 | möglicherweise mit M5 erledigt (`TimelineRegionPlayer.swift:1473-1483`), `play()` nicht nachgemessen |
| Korrekturen am Collector | SP-3 sitzt in `BioComposer.swift:1153` · A2-Beleg zeigte auf die Velocity-Spur · E22 sind 18 Dateien · Review-Rückstand 845, nicht 540 |

---

## 7. Ehrliche Grenzen (Notizen der Gatherer, zusammengefasst)

- **plan (`4dbcfc6`):** Nicht gemessen sind der TRUE-PEAK-Limiter (nur das Meter ist bestätigt), D2-LAUNCHQUANT, B8, die Forschungszeilen F/G/I und DRIFT-ARCHIVE-SLICES je Eintrag. Es wurden keine Dateien geschrieben.
- **board (`4dbcfc6`):** Nicht nachgemessen sind die Tiefe von AU-P, KB-e/d/h, die Zählungen D4/D5, die A11-CPU, der Name des OSC-LOOP-Tests und SP-2. `review.sh` wurde nicht selbst gezählt. founder-verify lief einmal (378/326), die Bitten wurden nicht einzeln geprüft. Die D3-Nadel wich vom Report ab: 39 Zeilen nach dem board, 6 Code-Stellen nach dem code-Gatherer. Die kommentar-gestrippte Messung gilt.
- **founder (`9e570bc`):** Nicht gemessen sind die unkommittete E10-1-Datei (`git status` nicht angesehen), der Stand von Issue #418, der GitHub-About-Text und die rund 30 NEXTBUILD-Proben einzeln.
- **code (`9e570bc`):** Nur gelesen, nichts editiert. `play()` für M7-LOW-3 wurde nicht nachgemessen. Bei S10 ist die kommentar-gestrippte Modal-Zählung offen (roh 19, `doctor --section D` zeigte keine Zusammenfassung). Bei D2 ist offen, welche antippbaren Rahmen noch `border` tragen.
- **Übergreifend:** Zwei HEADs (`4dbcfc6` und `9e570bc`). Alle Gerätechecks sind unbeantwortet, also ist nichts auf diesem Plan geräteverifiziert. Der Status „kompiliert" hängt am CI-Lesen nach `Tests/CISmoke/CLAUDE.md` §5 (#396: die Conclusion allein beweist nichts). Ob A1e und DETECTED-KEY-ADOPT schon in der Inbox stehen, ist nicht geprüft.
