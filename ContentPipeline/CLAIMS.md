# CLAIMS — was Echoel heute WIRKLICH kann

**Diese Datei ist die Quelle für jedes Skript, jede Caption, jedes Thumbnail.**
Sie steht bewusst VOR den Templates in dieser Pipeline, weil das Grundproblem von
Marketing-Content nicht das Format ist, sondern die Behauptung.

Zwei ganze Arbeitszyklen (#158, #192) wurden damit verbracht, EINE falsche Behauptung
wieder aus acht Dateien und ~25 Stellen der Website zu entfernen. Ein weiterer (#184)
entfernte zwölf falsche Behauptungen aus dem App-Store-Text — dort ist eine falsche
Behauptung ein 2.3-Ablehnungsgrund („Accurate Metadata"). Ein Skript, das eine
gestrichene Behauptung wieder einführt, macht diese Arbeit rückgängig.

⭐ **SEIT 2026-10-19 TRÄGT TESTFLIGHT ECHOEL STUDIO (`EchoelStudio/`, Version 11.0.0), und dieses Register
beschreibt bis auf die vier Nachträge unten die eingefrorene Alt-App (10.79.515).** Für Studio-Kopie gilt
der eigene Abschnitt „Echoel Studio 11.0.0“ direkt vor der Alt-App-Tabelle: behauptet wird nur, was dort steht,
mit „noch auf Geräten im Test“, und nichts aus den Körper-, Visual-, Licht- oder OSC-Zeilen. ⚠️ `EchoelStudio/RELEASE`
ist eine PRÜFLISTE für Tester, keine Quelle für Behauptungen — bis 2026-10-19 stand hier das Gegenteil, und
dieselbe Runde schrieb „tested in AUM“ in Store-Text und Roadmap, für Instrumente, die nie in einem Host
liefen (`20a5469`, zurückgenommen mit `26e507745` und der Folgescheibe). Die Nachträge:
(1) **§7:** für die eigenen AUv3-Instrumente ist ein EINMALKAUF GEBAUT (`com.echoelmusic.app.pro`), aber
NICHT im Verkauf: in App Store Connect ist kein In-App-Kauf angelegt (F-15), der Store-Bildschirm meldet
„not available“. Sagbar ist „geplant als Einmalkauf, kein Abo, noch nicht im Verkauf“ — nie ein Preis, nie
„Pro“, nie „Trial“, nie das Präsens „kann man kaufen“. Die App ist frei. (2) **§11:** das Studio nimmt Audio
vom Mikrofon oder Interface auf eine scharf geschaltete Audiospur auf, der Take bleibt auf dem Gerät; die
Stimm-Verbote (Cloning, AI-Voice, Autotune) bleiben. (3) **§1:** die AUM-Messung vom 2026-09-20 (#1386) gilt
NUR für `echl` der ALT-App (`EchoelmusicAUv3`). Studios Instrumente (`eSyn`, `eDrm`, `eSmp`) liefen auf keinem
Gerät in einem Host — sagbar ist „noch in keiner Host-App auf einem Gerät geprüft“, nie „in AUM geprüft“.
(4) **§1, die andere Richtung:** das Studio LÄDT Audio Units anderer Hersteller als Instrument oder Effekt auf
Spuren (`EchoelStudio/App/Engine/PluginHost.swift`, `AUAudioUnit.instantiate`), auf keinem Gerät geprüft. Sagbar
ist „spielt Audio Units anderer Apps auf Spuren, noch nicht auf einem Gerät geprüft“; die Verneinung des Hostens
in diesem Register gilt der Alt-App. Fremde Audio Units laufen unter den Bedingungen ihres Herstellers
(`docs/privacy.html`, Abschnitt „Echoel Studio“).
Auf dem Arbeitszweig steht das in `docs/roadmap.html`, `docs/privacy.html` (Abschnitt „Echoel Studio“) und oben auf
`docs/claims.html`. ⚠️ ÖFFENTLICH ist es erst nach dem Merge nach `main` (Founder, F-08b): die Website baut
aus `main`, und dort sagt `docs/privacy.html` noch „Microphone Access: Not requested“ (FOUNDER_INBOX F22).
Einstieg: `docs/dev/ECHOEL_VISION_2026-10-19.md`.

Stand: 2026-10-13 (Produktgesetz vom 2026-09-24 nachgezogen — `docs/dev/FOUNDER_PRODUCT_LAW.md`:
Echoelmusic IST die Workstation. ✅ neu: Mixer-Bühne, Sampler je Spur, Grain-Insert, Stück-Export,
Siri/Kurzbefehle — alle „Geräte-Verify offen“. §1b und §5 begründen nicht mehr mit einer
„Produktgrenze“: eine historische Streichung widerruft eine IMPLEMENTIERUNG, nicht die Fähigkeit;
behauptet wird weiter nur, was ausgeliefert ist. Davor 2026-09-12 (#1302 — Face UND Audio Input sind auf Founder-Ansage komplett entfernt;
JEDE Stimm-, Mikrofon- und Gesichts-Zeile ist gestrichen, §11 als ganzer Abschnitt ausgesetzt.
Davor 2026-08-28, Brand-Audit: §12 korrigiert — Kohärenz-Trend ist seit #813 WAHR). **Vor jeder neuen Kampagne
gegen `CLAUDE.md` „CURRENT STATE" und `docs/dev/FEATURE_MATRIX.md` gegenprüfen.** (Die Versionsnummer stand hier früher
daneben und veraltete schneller als der Inhalt — sie belegte nichts, was das Datum
nicht besser belegt.)

**Zwei Behauptungen dieser Datei sind maschinell gepinnt** (`Tests/CISmoke/ContentPipelineClaimsTests.swift`,
im blockierenden Bundle): „Null externe Abhängigkeiten" und — seit 2026-09-20 in der
UMGEKEHRTEN Richtung — „das AUv3-Target EXISTIERT". Beide sind Tatsachen über das Repo,
keine Formulierungen — wer sie ändert, färbt das Gate rot und muss diese Datei im selben
Commit mitziehen.

⭐ **Der AUv3-Pin ist am 2026-09-20 GEKIPPT, nicht entfernt (#1385).** Bis dahin hielt er die
ABWESENHEIT des Targets fest; der Founder hat es zurückgeholt (ausdrücklich ohne JUCE — es war
immer reines Swift), also hält er jetzt seine ANWESENHEIT. **Ein Verbot, das wahr war und es
nicht mehr ist, wird invertiert, nicht gelöscht:** ein gelöschter Pin merkt nichts mehr, und
diese Datei ist das, woraus jeder Store-Text und jede Caption geschrieben wird. Die HOSTING-
Hälfte ist **nicht** mit gekippt und wird seit #1385 getrennt gepinnt — siehe §1.

⚠️ **Wie weit der Zaun WIRKLICH reicht** — die erste Fassung dieses Absatzes versprach
mehr, als der Test hält, und ein zu weit versprochener Zaun ist schlimmer als keiner:
- **Abhängigkeiten:** geprüft werden `Package.swift` UND der `packages:`-Block in
  `project.yml` (die App wird über XcodeGen gebaut, nicht über SwiftPM — nur das
  Manifest zu prüfen hätte die Hälfte offen gelassen).
- **AUv3:** geprüft wird das TARGET, gebunden an den Namen `EchoelmusicAUv3`, **seit
  #1385 auf ANWESENHEIT** (plus die Existenz von `Sources/EchoelmusicAUv3/`). Ein Target
  unter anderem Namen rutscht weiterhin durch — das wäre eine laute, gewollte Änderung,
  aber der Test findet sie nicht. ⭐ Die HOSTING-Hälfte (seit 2026-10-14: „Code da, nicht
  behauptet") ist **seit #1385 gepinnt** und war es vorher nicht: sie steckte mit der
  Target-Hälfte in EINEM Satz, und genau deshalb machte die Rückkehr der einen den ganzen
  Eintrag falsch. Zwei Tatsachen in einem Satz sind ein Pin, der nur gemeinsam altern
  kann.
- Alles andere hier ist **ungepinnt** und lebt von der Gegenprüfung oben. Urteilsfragen
  (Wellness-Ton, Watch-Formulierung, §10) kann kein Test entscheiden.

ℹ️ **Nebenwirkung, die man wissen muss:** #252 hält `ContentPipeline/**` bewusst aus
JEDEM Auto-Merge-Pfadfilter heraus, damit reine Pipeline-Commits nie automatisch nach
`main` wandern. Der Wächter liegt aber in `Tests/` — **ein Commit, der beide anfasst,
zieht diese Datei mit nach `main` und löst TestFlight aus.** Wer nur an dieser Datei
arbeitet, fasst `Tests/` nicht an und bleibt wie vorgesehen isoliert.

## ✅ Echoel Studio 11.0.0 — was gesagt werden darf (gemessen 2026-10-20)

**Gemessen, nicht erinnert:** 36 Behauptungen über `EchoelStudio/`, je eine Tür vom Startbildschirm
bis zum Klang im Code verfolgt (Stand `372727570`), dann von einem zweiten Prüfer gegengelesen —
16 bestätigt, 20 zu weit gefasst und hier enger formuliert. Vier der zu weit gefassten waren
Fehler im Code und sind seitdem behoben (`57673cf96`, `81133dceb`, `c3ef58028`, `f4ff0b00f`).
**Nichts davon ist auf einem Gerät geprüft.** Jede Kopie sagt „Beta“ oder „in TestFlight“.
Die Sätze sind englisch, weil Store und Website englisch zuerst sind: übersetzen darf man,
erweitern nicht.

**Spuren und Klang**
- „Songs hold instrument, audio and return tracks (up to 32, 64 and 8). Add any kind, or add a drum track that comes with an empty one-bar pattern to fill. Recolour, mute, solo and delete tracks.“
- „Instrument tracks can play the built-in 16-voice synth: six presets, four waveforms (sine, saw, square, triangle) and nine adjustable sound parameters.“
- „… a synthesized eight-piece drum kit (kick, snare, clap, two toms, closed and open hi-hat, crash) on General MIDI drum note numbers.“
- „… an imported audio file (mixed to mono, up to ten minutes) as a sampler across the keyboard, at its original pitch on C4.“
- „… an installed third-party Audio Unit instrument that runs in stereo. Its own interface appears on the track's Sound page, and its settings are saved with the song.“
- „Every track and the master have an insert chain of up to eight effects: Echoel EQ, Compressor, Delay and Reverb, or installed stereo Audio Unit effects.“

**Schreiben und Arrangieren**
- „On a synth, sampler or plugin instrument track, edit a clip's notes in a piano roll: tap to add or remove a note, drag to move it, drag its right edge to change its length, on a grid from 1/4 to 1/32 or 1/8 and 1/16 triplets.“
- „Drum tracks have a step grid with one row for each kit piece. Tap a step to set or clear a hit, hold it for an accent.“
- „In Arrange, place clips on a bar timeline, drag them in whole bars, duplicate them or take them off the timeline. Tap an audio track to import a file at a bar, then move it and trim either edge to the beat.“
- „A session grid launches clips and scenes on the next bar, the next quarter note or at once, stops a track or all session clips, and hands every track back to the arrangement.“

**MIDI**
- „Play any instrument track live from a MIDI keyboard or controller by USB, Bluetooth (paired with iOS) or network MIDI. The synth and plugin instruments follow pitch bend, the mod wheel and the sustain pedal; the drum kit and sampler play notes.“
- „Record a MIDI performance onto an armed instrument track; each take becomes a new clip with its notes, pitch bend and controllers, as one undo step.“
- „MIDI Learn maps a knob or fader to a mixer control, a synth parameter or a built-in effect parameter.“
- „Send MIDI clock to the outputs you choose, or follow an external MIDI clock.“ · „Novation Launchpad Mini MK3, X and Pro MK3 become a window onto the session grid.“

**Aufnahme, Mix, Export**
- „Record mono audio from the microphone or one interface input onto an armed audio track; takes stay on the device.“ (das ist §11, Nachtrag 2)
- „A channel strip for every track and the master, with fader, pan and a peak meter; sends to up to eight return tracks; any track can go to its own output pair of a multichannel interface.“
- „Draw automation for volume, pan, sends, synth parameters and the parameters of plugins on a track, or record it by moving the control while the song plays.“
- „Export the arrangement as a 24-bit, 48 kHz stereo WAV, with its loudness (LUFS) and true peak reported, or as a Standard MIDI File.“
- „Songs save automatically as .echoel files that the Files app shows, and a song sent by AirDrop opens in Echoel.“

**Nicht sagen — und warum**
- „ready-made beat“: der neue Schlagzeug-Track bringt ein LEERES Muster mit.
- „any Audio Unit“, „any controller“: nur Stereo-Units; Launchpads spielen keine Noten, sie steuern das Raster; Drums und Sampler folgen weder Bend noch Pedal.
- „edit velocity“, „quantize“, „split“, „loop recording“, „overdub“: gibt es nicht.
- „everything is undoable“: Werte der eingebauten Effekte sind kein Undo-Schritt.
- „mastering“, „normalised export“, „stems“: der Export misst und warnt, er normalisiert nicht; nur das Arrangement, keine Session-Starts.
- „works in AUM, Logic, GarageBand“, „plugin you can buy“: Studios Audio Units liefen in keinem Host auf einem Gerät (§1, Nachtrag 3); nichts ist im Verkauf (§7, Nachtrag 1).
- „imports your old Echoelmusic songs“: der Import findet erst etwas, wenn die App die App Group `group.com.echoelmusic` trägt (FOUNDER_INBOX F17).
- „AI that writes your song“: der Assistent ist nur mit Apple Intelligence sichtbar, ändert Tempo, Spuren, Sounds, Mix und einfache Muster, und lief auf keinem Gerät. Nie „KI komponiert“, nie „Superintelligenz“.
- „Network MIDI between two iPads running Echoel“: Echoel nimmt Verbindungen an, startet keine, und sendet nur Clock.

Die volle Messung (Tür, Pfad, Grenze je Behauptung) liegt nicht im Repo; wer sie neu braucht,
wiederholt sie gegen den heutigen Code, statt diese Liste zu verlängern.

---

## ✅ DARF behauptet werden — gebaut, verdrahtet, am Gerät gesehen

| Behauptung | Beleg |
|---|---|
| Der Puls wird **mit der iPhone-Kamera** gemessen (Finger auf die Linse, rPPG) | live; Log 2477: Lock in 14 s, danach Minuten bei Confidence 0,8–0,96 |
| Herzschlag, HRV und Kohärenz **modulieren Klang in Echtzeit** | `EchoelDDSP` Bio-Mappings, `FXBioModulator` |
| **Generative Komposition** in gewählter Tonart/Skala/Genre, tonartrein | `BioComposer`, 57 Skalen, 15 Stimmungssysteme |
| **Bio-reaktive Visuals** live auf dem Gerät (Metal) | `MetalBioView`, `FloatingVisualWindow` |
| **Das Bild ist SPIELBAR**: Berühren des Visuals erzeugt tonartreine Noten auf dem Klang des Takes — im schwebenden Fenster in JEDER Größenstufe, bis hinauf zu Vollbild, mit Wasserringen unter den Fingern | `TouchInstrumentView(` hat GENAU EINE Konstruktionsstelle, im `.overlay` des Visuals in `FloatingVisualWindow` — also an der Fläche, die beim Start offen ist. **Messen, nicht zitieren: `git grep -n "TouchInstrumentView(" -- Sources`** (der zweite Treffer ist ein Kommentar in `FieldAutoPlay.swift`). ⛔ Hier stand `FloatingVisualWindow.swift:791`, und die Zeile ist seither 895 — eine Zeilennummer ist ein Datum, eine zitierte Phrase überlebt eine Einfügung. Kein Größen-Gate: der Kommentar an der Stelle sagt „PLAY SURFACE at EVERY size". ⚠️ **Und die frühere Formulierung „im schwebenden Fenster UND im Vollbild" war zwar wahr, las sich aber wie ZWEI Flächen (#1161).** Es ist EINE: `WindowSize` hat vier Stufen (`small, medium, large, fullscreen`). Der SEPARATE Vollbild-Deckel (`.fullScreenCover($showVisual)`) ist mit #1069 gelöscht — wer die alte Formulierung gegen den Code prüft, sucht die zweite Fläche und findet sie nicht. ⭐ **Die WEBSITE ist geprüft und bleibt unverändert:** „movable/floating window or fullscreen" steht dort an SECHS Stellen (`git grep -c "window or fullscreen" -- docs`, inkl. zweimal im JSON-LD-Block von `faq.html`) und beschreibt zwei ZUSTÄNDE einer Fläche — für einen Leser richtig. Eine dieser sechs anzufassen hätte fünf abweichende Zwillinge hinterlassen; das wäre schlechter als die Ungenauigkeit, die es nicht gibt. **Nicht „korrigieren".** Quantisierung: `MusicalKey(root: rootIndex, scale: touchScale)` + `touchQuantizer`. Founder-Auftrag 2026-07-07: »das Visual in ein Multi-Touch Instrument umwandeln … wie mit den Fingern durchs Wasser«. ⚠️ **Nicht als »Touch-Instrumente« schreiben** — Chord-Pad, XY-Pad, Keyboard und Strum-Pad sind Roadmap und stehen weiter unter ⛔; was existiert, ist DIESE eine Fläche. ⛔ Bis #999 war das in KEINER Akquise-Kopie und wurde in der FAQ aktiv VERNEINT (»Dedicated touch instruments … on the roadmap«), während die Fläche beim Start offen war |
| **Licht: Art-Net + sACN** (DMX über Netzwerk), Grand Master + Blackout | EchoelLux, unicast live |
| **Immersiver Raum: ADM-OSC** Objekt-Ausgabe (`/adm/obj/{n}/*`) | `ADMOSCSender` |
| **OSC-Ausgabe** des Bio-Signals an jede Software im Netz | `OSCSender`, Adressliste in `CLAUDE.md` |
| **OSC-Eingang: Steuer-Whitelist** (`/echoelmusic/ctrl/{bpm,key,scale,genre,visualStyle,blackout}`, UDP 8001, Opt-in default AUS, Sender-Allowlist — leer = NUR dieses Gerät seit T18 2026-10-08, nie über Mobilfunk) | #1255 (`OSCReceiver`); `bpm` NUR bei BPM-Lock (`TempoSource.remoteControl`); KEIN Bio-Kanal, KEIN Play/Stop (One-Start-Gesetz → Founder-Frage), KEINE bidirektionale Session — NIE „bidirektional" schreiben; **Geräte-Verify offen — so kennzeichnen** |
| **ADM-OSC-Objekteingang** (`/adm/obj/{n}/aed · xyz · azim · elev · dist · x · y · z · gain`, derselbe Port 8001, dasselbe Opt-in + Allowlist) | Spatial S1 (`ADMObjectInput` → `SpatialSceneStore.apply`); Objekt n = Spur n der Szene; ein Spatial-Controller (z. B. Grapes, L-ISA, SPAT) bewegt die Spuren, der ADM-OSC-Szenen-Stream reicht sie an den Renderer weiter. KEINE Glättung, KEIN Atmos, KEIN Dante. Binaural: seit Restructure S3c sitzen AUDIO-Spuren bei eingeschaltetem „Headphone space“ (Mixer, Default AUS) über Apples HRTF im Kopfhörer an ihrer Szenen-Position — gebaut, aber am Gerät UNBESTÄTIGT (G6), und die generierten Stimmen bleiben stereo. Bis G6 bestätigt ist trotzdem NIE „renders Atmos/binaural“ schreiben; **Geräte-Verify offen — so kennzeichnen** |
| **MIDI-Export** der erzeugten Musik als `.mid` | `MIDIFileExporter`, Tür im Export-Schacht |
| **Workstation**: Teile auf Spuren anordnen (verschieben, kopieren, teilen, trimmen, Undo), **Noteneditor** für MIDI-Teile, **`.mid`- und Audio-Import** auf eine Spur, **MIDI-Take-Aufnahme** vom Controller, Pegel/Pan/Mute/Solo je Spur | `WorkstationView` (Startfläche, `StageShell`), `PartNoteEditor`, ein `.fileImporter` (`UTType.midi`/`.audio`), `RecordTakeControls`, `TrackInspectorView`. Gates grün, **Geräte-Verify offen — so kennzeichnen** (die Website sagt „new, still being tested on devices“). ⛔ Bis Audit 2026-10-03 (MKT-1) VERNEINTEN FAQ, Presse, Übersicht, Architektur und `claims.html` genau das („deliberately no note editor“, „Importing a .mid is not in this build“, „an instrument, not a workstation“) — eine Unter-Behauptung über die Startfläche. ⚠️ **Aufnahme heißt MIDI, nie Ton**: es gibt keinen Mikrofon-Eingang (#1302), also nie „records audio“/„multitrack recording“ schreiben. |
| **Mixer-Bühne**: Umschalter unten **Arrange · Mixer · Instrument · Browse · Piece**; Pegel, Pan, Mute, Solo je Spur, ein Undo-Schritt | DAW-Shell S2 (`StageShell`, fünftes Wort „Piece“ seit H18); **Geräte-Verify offen — so kennzeichnen** |
| **Sampler je Spur**: ein Sample auf eine Spur laden, die Teile der Spur spielen es | GMMW GA-4 (`LaneVoiceRack.samplers`), Tür `TrackSampleRow` im Spur-Detail (2026-10-10); **Geräte-Verify offen — so kennzeichnen**. ⛔ Bis 2026-10-13 stand der Sampler in §5 als „türlos“ |
| **Echoel Grain als Spur-Insert** auf Audiospuren (Position · Länge · Dichte · Streuung · Tonhöhe · Breite) | GMMW GA-9 + GA-10a–d2 (`GrainCloud`, `GrainBake`, Zeilen „Grain“ auf der Device-Seite: `TrackGrainRows`); **Geräte-Verify offen (G10) — so kennzeichnen** |
| **WAV-Export des ganzen Stücks** („Piece (WAV)“, LUFS-normalisiert) neben dem Loop-Export | `PieceAudioExportTab` → `LoopExporter.exportPiece`; **Geräte-Verify offen — so kennzeichnen** |
| **Siri / Kurzbefehle**: Start, Stop, „Keep last loop“, Spurpegel, Teil kopieren, Teil behalten, Undo — jeder Befehl mit Bericht und eigenem Undo in der App | GMMW AI-1/AI-2 (`EchoelAppIntents` → `EchoelAgentDesk` → `EchoelCommandExecutor`, `AgentReportBanner`); **Geräte-Verify offen — so kennzeichnen**. ⚠️ Kein Sprachmodell plant (AI-5 ist Founder-Gate) — „KI“ nicht behaupten |
| **MIDI-Eingang**: ein externer Controller spielt EINE monophone Stimme — Noten, Pitch-Bend, Press (Channel Pressure, #939) und Slide (CC 74, #942) | `BioReactiveSynthVoice` ist der EINZIGE Verbraucher von `controllerEvents`; `apply(controller:)` ruft `playNote(` genau EINMAL, auf EIN `synth`. (⛔ #943b: hier stand «`heldByController` ist ein einzelner `Bool`» — mit #943 ist das ein BERECHNETER `Bool` über einen Tasten-STAPEL, der Beleg nannte also genau das, was aufgehört hatte, einzeln zu sein. Die Monophonie sitzt im einen `synth`, nicht im Riegel.) Wächter: `TheMPEInputHasNoZonesTests` |
| **MIDI-Ausgang live**: gespielte NOTEN an dein Rig (MIDI 1.0) | `MIDIOutput`, Schalter in der Routing-Fläche (`midi.out`), Default AUS |
| **Zweite Quelle im MIDI-2.0-Protokoll** („Echoelmusic (MIDI 2.0)": dieselben Noten mit 16-bit-Velocity, 32-bit-Bend/CC) | #1253, Schalter »MIDI 2.0 source« in der Routing-Fläche, Default AUS; **Geräte-Verify offen — so kennzeichnen**; NIE als „natives MIDI-2.0-MPE" (per-note-Bend bleibt Test-only) |
| **MPE-AUSGANG an Dein Rig**: Zone angekündigt, Noten über Member-Kanäle 2–16, jede mit Glide (Pitch-Bend), Slide (CC 74) und Press (Channel Pressure) | `MIDIOutput.sendMPEConfiguration()` plus die drei Sendepfade; zwei Schalter in der erreichbaren Routing-Fläche (»MPE note layout«, »Per-note expression«), beide Default AUS. **Nur MIT Richtungswort schreiben** — warum, steht in §6 |
| **Dein Rig erfährt, ob ein Körper sendet oder der Demo-Generator**: auf OSC als eigene Adresse `/echoelmusic/bio/synthetic` (1 = Demo, 0 = echter Körper), auf sACN als Quellname »Echoelmusic (DEMO)« in der Quellenliste des Pults | #639 (Batch, der Flagge geht jedem Tick voran der mindestens einen Messwert sendet) · #785 (Ereignisse, Flagge unmittelbar VOR dem Ereignis, erneut nur bei Wechsel) · #789 (sACN, das 64-Byte-Source-Name-Feld von E1.31 — das eigene Feld des Standards, nichts erfunden). Wächter: `TheWireSaysWhoseBodyTests`, `TheLightRigSeesTheSimulatorTests`. ⛔ **NIE »alle Ausgänge« schreiben**: ADM-OSC und Art-Net tragen sie NICHT, und die Gründe sind verschieden (fremder Adressraum, dessen Erweiterungsregeln hinter einer AES-Paywall liegen · `ArtDMX` hat gar kein Namensfeld, `ArtPollReply` ist ungebaut). Die sACN-Hälfte: **Geräte-Verify offen — so kennzeichnen** (ob ein Pult den Namen mitten in der Sitzung neu zeichnet, ist im Repo nicht messbar) |
| **Universeller BLE-Herzgurt** (0x180D), z. B. Polar H10 | gebaut + verdrahtet, Geräte-Verify offen — **so kennzeichnen** |
| **Apple Health** als Pulsquelle | `HealthKitBioPublisher` |
| **Offene Standards, kein SDK-Lock-in** | OSC · ADM-OSC · MIDI · Art-Net/sACN · BLE HRS |
| **Null externe Abhängigkeiten**, alles on-device | `Package.swift: dependencies: []` UND `project.yml` ohne `packages:`-Block — beide, siehe Zaun-Absatz oben |
| **Barrierefrei spielbar**: Notennamen International/Deutsch/Solfège, VoiceOver auf der Spielfläche, Atkinson Hyperlegible | #232 C/E, `EchoelValueField` |
| ~~**Deine Stimme wird die Klangfarbe des Instruments**~~ | EchoelVoice #591–#593, #600 Take-Hälfte. ⛔ **GESTRICHEN 2026-09-12 (#1302) — DARF NICHT MEHR BEHAUPTET WERDEN.** Der Founder hat Audio-Input und Face komplett entfernt ("Face und Audio Input komplett entfernen"); `VoiceCaptureEngine`, `VoiceAnalyzer` und `VoiceTimbreProfiler`s Aufnahme-Weg sind als Dateien weg, es gibt keine Capture-Tür und kein Mikrofon mehr. **Was BLEIBT und NICHT behauptet werden darf, bis es wieder eine Tür hat:** die Patch-Hälfte (`SynthPatch.voiceProfileTaps/-Label/-Blend` und `PolySynthVoice.applyVoiceProfile`) ist absichtlich im Code — ein Patch, den ein älterer Build gespeichert hat, trägt weiter ein Profil und wendet es an (#95/#527). Gebaut ≠ erreichbar; eine Werbe-Behauptung darüber wäre die 2.3-Klasse. |
| ⛔ **GESTRICHEN 2026-09-06 (#1024) — „Tune to key" DARF NICHT MEHR BEHAUPTET WERDEN.** ⛔ Der Code lebte (`VoicePitchCorrector`, fest im Monitorpfad, bei AUS bypassed) — **seit #1302 ist die Datei gelöscht** (#1347); seine einzige Tür war schon vorher das Input-Sheet, und der Founder hat alle drei Mikrofon-Türen entfernt ("das mit dem Audio Input Monitoren klappt immer noch nicht also fliegt das raus"). Kein Nutzer kann die Stufe heute erreichen — eine Werbe-Behauptung darüber wäre die 2.3-Klasse. Im selben Commit aus `fastlane/metadata/{de-DE,en-US}/release_notes.txt` entfernt. ⛔ **DIESE ZEILE TRUG EINE AUSNAHME UND SIE IST MIT #1305 HINFÄLLIG:** sie lautete „Was BLEIBT und weiter behauptet werden darf: ‚Follow the key' — die Harmonizer-Stimmen des MUSIK-Pfads sind über das FX-Panel erreichbar und von #1024 nicht berührt." Der Founder hat den Harmonizer am 2026-09-12 ganz gestrichen („Kein … Autotune, Harmonizer, granularsynthese"); Stufe, Panel-Abschnitt, Toggle und Untertitel sind gelöscht. **Es gibt keinen MUSIK-Harmonizer mehr, über den eine Ausnahme laufen könnte.** ⛔ **DIESE ZEILE TRUG EINE BEDINGTE ERLAUBNIS UND SIE IST MIT #1302 HINFÄLLIG (#1347, 2026-09-16).** Sie lautete: *„#1247 (2026-09-11): die Master-Panel-Tür ‚Audio input' ist ZURÜCK (Founder-Ask), aber der Monitorpfad ist am Gerät weiter UNBESTÄTIGT — die Zeile bleibt gestrichen, bis ein `VERIFIED-`Datum an `setInputMonitoring` steht."* Es gibt kein `setInputMonitoring` mehr, keine Tür und keinen Monitorpfad — gemessen in kommentar-gestrippten `Sources/`: `setInputMonitoring` · `showInput` · `AudioInputPickerView` · `VoicePitchCorrector` · `isInputMonitoring` je **0**. **Die Bedingung kann nie eintreten, also ist die Streichung ENDGÜLTIG, nicht aufgeschoben** — und genau das ist der Unterschied, den ein Texter liest. |
| ~~**Harmoniestimmen auf deiner Stimme** (zwei benannte Intervalle + Mix, nur im Monitor)~~ | #841. ⛔ **GESTRICHEN 2026-09-06 (#1038) — DARF NICHT MEHR BEHAUPTET WERDEN, gleicher Grund wie »Tune to key« eine Zeile höher.** #1024 hat alle DREI Mikrofon-Türen entfernt (Mix-Streifen · »Audio input«-Knopf · Einlade-Banner), also setzt nichts mehr `showInput` — gemessen: `git grep -n "showInput = true" -- Sources` → **0**, und **seit #1302 ist auch `AudioInputPickerView` als Datei gelöscht** (#1347) — die erste Fassung schrieb hier „wird weiterhin in einem `.sheet` konstruiert, das niemand öffnen kann", was seit dem 2026-09-12 nicht mehr stimmt. Diese Stufe sitzt AUSSCHLIESSLICH im Monitorpfad, und der Monitorpfad hat keine Tür. ⛔ „Der Code lebt und ist unangetastet; Wieder-Betüren sind drei Aufrufstellen" stand hier und ist mit #1302 falsch (#1347): die Stufe ist als DATEI gelöscht, Wieder-Betüren heißt hier neu bauen, nicht wieder anhängen. **Bis dahin ist jede Werbe-Behauptung darüber die 2.3-Klasse.** ⛔ **DIE UNTERSCHEIDUNG, DIE HIER STAND, IST MIT #1305 GEGENSTANDSLOS.** Sie lautete: „Nicht mit dem MUSIK-Harmonizer verwechseln, der über das FX-Panel erreichbar ist und weiter behauptet werden darf … Die App-Store-Notiz »third and fifth harmony voices above the melody« meint DIESEN und bleibt korrekt." Beide Hälften sind weg: der Founder hat den Harmonizer ganz gestrichen, und **die App-Store-Notiz ist im selben Commit aus `fastlane/metadata/{de-DE,en-US}/release_notes.txt` sowie aus beiden `description.txt` entfernt** — zusammen mit `docs/faq.html` (zweimal, inkl. JSON-LD), `docs/brainstorming.html`, `docs/dev/ROADMAP.md` und `docs/dev/FEATURE_MATRIX.md`. ⭐ **LEHRE, weil sie allgemein ist: eine Ausnahme in dieser Datei zeigt auf einen Codepfad und muss mitsterben, wenn der Pfad stirbt.** Ein überlebender „… darf weiter behauptet werden"-Satz ist die 2.3-Klasse und liest sich wie eine Erlaubnis, nicht wie eine Ruine. ⛔ **DIESE ZEILE TRUG EINE BEDINGTE ERLAUBNIS UND SIE IST MIT #1302 HINFÄLLIG (#1347, 2026-09-16).** Sie lautete: *„#1247 (2026-09-11): die Master-Panel-Tür ‚Audio input' ist ZURÜCK (Founder-Ask), aber der Monitorpfad ist am Gerät weiter UNBESTÄTIGT — die Zeile bleibt gestrichen, bis ein `VERIFIED-`Datum an `setInputMonitoring` steht."* Es gibt kein `setInputMonitoring` mehr, keine Tür und keinen Monitorpfad — gemessen in kommentar-gestrippten `Sources/`: `setInputMonitoring` · `showInput` · `AudioInputPickerView` · `VoicePitchCorrector` · `isInputMonitoring` je **0**. **Die Bedingung kann nie eintreten, also ist die Streichung ENDGÜLTIG, nicht aufgeschoben** — und genau das ist der Unterschied, den ein Texter liest. |
| ~~**Granular-Textur auf deiner Stimme** (Grain-Wolke unter dem trockenen Signal, nur im Monitor)~~ | #849. ⛔ **GESTRICHEN 2026-09-06 (#1038) — DARF NICHT MEHR BEHAUPTET WERDEN, gleicher Grund wie »Tune to key« eine Zeile höher.** #1024 hat alle DREI Mikrofon-Türen entfernt (Mix-Streifen · »Audio input«-Knopf · Einlade-Banner), also setzt nichts mehr `showInput` — gemessen: `git grep -n "showInput = true" -- Sources` → **0**, und **seit #1302 ist auch `AudioInputPickerView` als Datei gelöscht** (#1347) — die erste Fassung schrieb hier „wird weiterhin in einem `.sheet` konstruiert, das niemand öffnen kann", was seit dem 2026-09-12 nicht mehr stimmt. Diese Stufe sitzt AUSSCHLIESSLICH im Monitorpfad, und der Monitorpfad hat keine Tür. ⛔ „Der Code lebt und ist unangetastet; Wieder-Betüren sind drei Aufrufstellen" stand hier und ist mit #1302 falsch (#1347): die Stufe ist als DATEI gelöscht, Wieder-Betüren heißt hier neu bauen, nicht wieder anhängen. **Bis dahin ist jede Werbe-Behauptung darüber die 2.3-Klasse.** ⛔ **DIESE ZEILE TRUG EINE BEDINGTE ERLAUBNIS UND SIE IST MIT #1302 HINFÄLLIG (#1347, 2026-09-16).** Sie lautete: *„#1247 (2026-09-11): die Master-Panel-Tür ‚Audio input' ist ZURÜCK (Founder-Ask), aber der Monitorpfad ist am Gerät weiter UNBESTÄTIGT — die Zeile bleibt gestrichen, bis ein `VERIFIED-`Datum an `setInputMonitoring` steht."* Es gibt kein `setInputMonitoring` mehr, keine Tür und keinen Monitorpfad — gemessen in kommentar-gestrippten `Sources/`: `setInputMonitoring` · `showInput` · `AudioInputPickerView` · `VoicePitchCorrector` · `isInputMonitoring` je **0**. **Die Bedingung kann nie eintreten, also ist die Streichung ENDGÜLTIG, nicht aufgeschoben** — und genau das ist der Unterschied, den ein Texter liest. |
| ~~**Feedback-Schutz, der Pfeifen VERHINDERT statt es wegzuducken**~~ | #847/#848 (`HowlDetector` + Notch-Kette im Monitorpfad). ⛔ **GESTRICHEN 2026-09-06 (#1038) — DARF NICHT MEHR BEHAUPTET WERDEN, gleicher Grund wie »Tune to key« eine Zeile höher.** #1024 hat alle DREI Mikrofon-Türen entfernt (Mix-Streifen · »Audio input«-Knopf · Einlade-Banner), also setzt nichts mehr `showInput` — gemessen: `git grep -n "showInput = true" -- Sources` → **0**, und **seit #1302 ist auch `AudioInputPickerView` als Datei gelöscht** (#1347) — die erste Fassung schrieb hier „wird weiterhin in einem `.sheet` konstruiert, das niemand öffnen kann", was seit dem 2026-09-12 nicht mehr stimmt. Diese Stufe sitzt AUSSCHLIESSLICH im Monitorpfad, und der Monitorpfad hat keine Tür. ⛔ „Der Code lebt und ist unangetastet; Wieder-Betüren sind drei Aufrufstellen" stand hier und ist mit #1302 falsch (#1347): die Stufe ist als DATEI gelöscht, Wieder-Betüren heißt hier neu bauen, nicht wieder anhängen. **Bis dahin ist jede Werbe-Behauptung darüber die 2.3-Klasse.** ⚠️ Diese Zeile ist die HEIKELSTE der drei: ein Schutz-Versprechen für ein Problem, das ohne Mikrofon-Tür gar nicht entstehen kann, klingt nach Sicherheit und beschreibt nichts, was ein Nutzer erleben könnte. ⛔ **DIESE ZEILE TRUG EINE BEDINGTE ERLAUBNIS UND SIE IST MIT #1302 HINFÄLLIG (#1347, 2026-09-16).** Sie lautete: *„#1247 (2026-09-11): die Master-Panel-Tür ‚Audio input' ist ZURÜCK (Founder-Ask), aber der Monitorpfad ist am Gerät weiter UNBESTÄTIGT — die Zeile bleibt gestrichen, bis ein `VERIFIED-`Datum an `setInputMonitoring` steht."* Es gibt kein `setInputMonitoring` mehr, keine Tür und keinen Monitorpfad — gemessen in kommentar-gestrippten `Sources/`: `setInputMonitoring` · `showInput` · `AudioInputPickerView` · `VoicePitchCorrector` · `isInputMonitoring` je **0**. **Die Bedingung kann nie eintreten, also ist die Streichung ENDGÜLTIG, nicht aufgeschoben** — und genau das ist der Unterschied, den ein Texter liest. |
| ~~**Visual-Aufnahme + mp4-Export**~~ | ⛔ **GESTRICHEN 2026-09-12 (#1304) — DARF NICHT MEHR BEHAUPTET WERDEN.** Founder wörtlich: „Kein Video Capture“. `VisualRecorder`, `VideoRecorder`, `VideoMuxer` und die Video-Bibliothek sind als DATEIEN gelöscht; es gibt keine Aufnahme und kein mp4. Im selben Commit aus `fastlane/metadata/{de-DE,en-US}/description.txt`, `docs/architecture.html`, `docs/faq.html`, `docs/overview.html`, `docs/press.html` und `docs/privacy.html` entfernt. ⚠️ **Nicht mit der WAV-Aufnahme verwechseln** — die schneidet den eigenen Ausgang mit, nie eine Kamera, und bleibt erlaubt. |
| **Beamer/Externer Bildschirm**: das Visual bespielt ein angeschlossenes Display als eigene Bühne, das Telefon bleibt Spielfläche | `ExternalDisplayScene` (#206) |
| **Texture- und Glitter-Regler im Visual** (Korn-Tiefe + Glitzer-Menge, 0–2, Default = bisheriger Look) | #853, Fine-tune-Fläche; **Geräte-Verify offen — so kennzeichnen** |

---

## ⛔ DARF NICHT behauptet werden — und warum genau

⭐ **DIESE HÄLFTE IST SEIT 2026-09-20 ÖFFENTLICH: `docs/claims.html`** (#1389). Jede Sektion
unten hat dort einen Eintrag mit derselben Nummer (`id="claim-<n>"`), auf Englisch und für
einen Leser geschrieben, nicht übersetzt. **Wer hier eine Sektion ANLEGT, legt sie dort im
SELBEN Commit an** — `Tests/CISmoke/TheClaimsPageCoversEveryDenialTests.swift` wird sonst rot
und nennt die Nummer. Umgekehrt genauso: ein Seiten-Eintrag ohne Sektion hier ist eine
öffentliche Zusage, die niemand geprüft hat, und Anspruch 3 desselben Wächters verbietet ihn.
⚠️ Gepinnt ist die ABDECKUNG, nicht der WORTLAUT — diese Datei ist deutsch und intern, die
Seite ist englisch und öffentlich, und eine maschinelle Übersetzung wäre schlechtere Kopie als
ein geschriebener Satz. Die Grenze steht im Wächter-Kopf, statt versteckt zu sein.

### 1. „läuft in Logic/Ableton/GarageBand", „in Deiner DAW" — **NOCH NICHT**, und „lädt fremde Plugins" — **HEUTE NICHT**

⭐ **DIESER EINTRAG IST AM 2026-09-20 NEU GESCHRIEBEN (#1385).** Er stand seit dem 2026-07-24
als schlichtes Verbot da („das Target wurde ENTFERNT"), und der Founder hat das Target
zurückgeholt. Ein Verbot mit abgelaufener Begründung ist gefährlicher als gar keins: die
nächste Sitzung liest die falsche Begründung, prüft sie, findet sie widerlegt — und streicht
dann auch den Teil, der weiterhin gilt. Deshalb steht er jetzt in **zwei** Hälften, die
getrennt altern können.

**a) Echoel IST ein AUv3-Instrument, und es LÄDT — in AUM, am Gerät, gemessen am
2026-09-20 (#1386).** Das Target `EchoelmusicAUv3` existiert wieder (`aumu`, subtype `echl`,
„Echoelmusic: EchoelBodyVibe"), reines Swift ohne jede Abhängigkeit, kompiliert und
eingebettet. Der Founder hat auf Build 2595 (v10.79.475) eine Bildschirmaufnahme geliefert,
und sie beantwortet die `-3000`-Frage, an der das Target 2026-07 gestorben ist: unter
`AUDIO UNIT EXTENSION → ECHOELMUSIC` steht `EchoelBodyVibe · INSTRUMENT PLUGIN (AU)`, es
instanziiert, die Plugin-Oberfläche („Echoelmusic · Bio-Reactive Instrument", vier Regler)
rendert, und Ton kommt. **Die App-Group-Hypothese war richtig** — das Entfernen des
Entitlements ist die Reparatur, und sie ist jetzt nachgemessen statt vermutet.

⚠️ **WAS DAMIT NICHT BEWIESEN IST, und die Grenze ist eng zu ziehen: EIN Host, nicht jeder.**
Geprüft ist AUM. **Logic Pro und GarageBand sind unverändert ungeprüft**, und GarageBand ist
der interessantere Fall, weil er auf 44,1 kHz läuft (Board A10). Was in einer Caption stehen
darf, ist also **„läuft in AUM"** — nicht „läuft in Deiner DAW" und nicht „in Logic".
Gepinnt von `TheStandingPromptDescribesThisRepoTests.testNoRoutineClaimsAUv3HostCompatibility`,
dessen Host-Liste seit #1386 genau die zwei UNGEPRÜFTEN nennt: ein Wächter, der eine
inzwischen wahre Aussage verbietet, ist selbst der Defekt (#364). Im App-Store-Text bleibt
der Unterschied zwischen einer Zeile und einer 2.3-Ablehnung — #158, #192 und #184 haben je
einen ganzen Zyklus mit dem Entfernen dieses Claims verbracht.

⚠️ **ZWEI MESSWERTE AUS DERSELBEN AUFNAHME, die eine Caption nicht verschweigen darf, wenn
sie das Plugin verkauft.** (1) **Die Tonhöhe stimmt bei 48 kHz** — der freilaufende Grundton
misst 220,15 Hz gegen den Default von 220 Hz, also +1,2 Cent; das WIDERLEGT den
44,1-kHz-Befund nicht, es bestätigt seine Form (richtig genau dann, wenn die Hostrate der
fest genagelten entspricht). (2) **Eine Instanz kostet in AUM rund 20 Prozentpunkte
DSP-Anzeige** (1 % leer → 19–24 % mit einer Instanz). „Läuft neben Deinem ganzen Set" ist
damit keine belegte Aussage.

**b) Echoel BEHAUPTET KEIN Laden fremder Plugins — der Code ist da, ein Gerät hat ihn nicht
bestätigt.** Das AUv3-*Hosting* ging mit #121 Slice 2 und ist seit der Production-Level-Reihe
(H2b–H6, Oktober 2026, TestFlight ab 10.79.501) als INSTRUMENT-Hosting zurück:
`Audio/HostedInstrumentHost` ruft `AVAudioUnit.instantiate`, die Tür ist die Device-Seite einer
Rack-Spur. Effekt-Plugins klingen nicht (H6-5 offen). ⛔ **Bis 2026-10-14 stand hier „Echoel lädt
KEINE fremden Plugins — heute. nichts davon ist zurück"**, und `docs/claims.html` sagte „never …
not coming back", während der Build es auslieferte — eine UNTER-Behauptung, gefunden von einer
lesenden Fremdprüfung. Behauptet wird weiter NICHTS davon, bis ein Gerätelauf mit einem echten
Fremd-Plugin es bestätigt; dann wird dieser Absatz zur Erlaubnis, nicht vorher. ⛔ **Bis 2026-10-13
stand hier als BEGRÜNDUNG „die Produktgrenze aus `PRODUCT_DEFINITION.md` — ein Instrument IN
der DAW zu sein ist das Gegenteil davon, selbst die DAW sein zu wollen“, und „steht nicht zur
Debatte“.** Das ist PHASENGESCHICHTE: seit dem Produktgesetz vom 2026-09-24
(`docs/dev/FOUNDER_PRODUCT_LAW.md`) IST Echoelmusic die Workstation, und Plugin-Hosting ist
künftiger DMMW-Umfang NACH dem Geräte-Vertrag (WA3; `CLAUDE.md` sagt es an der AUv3-Zeile). Eine
Begründung, die das Gegenteil des geltenden Gesetzes sagt, verführt eine Content-Sitzung dazu,
die Workstation selbst zu verneinen — und genau das stand bis heute in FAQ und Store-Text. Das
VERBOT bleibt, seine Begründung ist jetzt die wahre: nicht geräte-bestätigt, also nicht behauptet (bis 2026-10-14 stand hier „nicht gebaut" — seit H2b falsch).
Gepinnt von `ContentPipelineClaimsTests` gegen den Satz „Echoel BEHAUPTET KEIN Laden fremder Plugins“.

*Zwei richtige Bilder seit dem Produktgesetz: die EIGENE Arrange-Bühne (die App startet auf
ihr) und ein Plugin-Slot in einem fremden Host (AUM, siehe a). Nicht erlaubt bleibt — bis ein
Gerätelauf es bestätigt — ein Bild, in dem Echoel ein FREMDES Plugin lädt.*

### 2. Wellness, Meditation, Schlaf, Fokus, Stressabbau, Longevity, „HealthTech"
`CLAUDE.md`: **„Biofeedback ist Kern, NICHT Wellness."** Echoel ist ausdrücklich kein
Wellness-, Soundscape- oder Therapieprodukt. Das ist keine Geschmacksfrage:
Heilungs-/Organ-/Frequenz-Claims sind Alt-Last aus einem Vorgängerprojekt und eine
permanente rote Linie, und in der App steht der Satz „für Selbstbeobachtung, nicht
für medizinische Diagnose". Ein Reel, das „nutze es für Meditation und
Schlafoptimierung" sagt, widerspricht dem Text in der eigenen App.
**Erlaubt** ist die Beschreibung des Mechanismus: *„ruhiger Puls → andere Musik."*
**Nicht erlaubt** ist die Wirkungsbehauptung: *„macht Dich ruhig / hilft beim Schlafen."*
Der Unterschied entscheidet auch über die App-Store-Kategorie.

### 3. Apple Watch misst und steuert
`Sources/EchoelmusicWatch/EchoelWatchApp.swift` ist eine **95-Zeilen-Anzeige**: sie
LIEST die Werte, die das iPhone in die App-Gruppe schreibt. Die Produzenten-Hälfte
(Puls am Handgelenk → App-Gruppe → Telefon) ist **nicht gebaut** und im Kopf der Datei
als offen markiert. Dazu die harte Grenze aus `CLAUDE.md`: Watch-HR hat 4–5 s Latenz,
**niemals** Beat-Sync. Ein Hook, der mit einer pulsierenden Watch aufmacht, verkauft
die Richtung falsch herum. **Der echte Hook ist der Finger auf der Kamera** — er ist
wahr, er braucht kein Zusatzgerät, und er sieht besser aus.

### 4. „Im App Store" / Store-Link
Es gibt heute **nur TestFlight**. Erst nach der ersten Freigabe umstellen.

### 5. Drums, Beats, ~~Sampler-Instrument~~, Video-Schnitt, RTMP-Livestream, Audio-Mehrspur-Recorder
⭐ **2026-10-13: „Sampler-Instrument“ ist aus dieser Überschrift gestrichen** — seit GMMW GA-4
(2026-10-10) hat jede Spur einen Sampler mit Lader und Tür (`TrackSampleRow` im Spur-Detail);
die Behauptung steht in der ✅-Tabelle, „Geräte-Verify offen“. Gestrichen bleiben Drum-Kit und
Beat-Maker. ⚠️ Die vier übrigen Verbote sind seit dem Produktgesetz (2026-09-24) KEINE
Produktgrenze mehr, sondern Stand: Audio-Mehrspur-Aufnahme braucht einen Audio-Eingang (keiner,
#1302), Video-Schnitt und -Aufnahme sind entfernt, RTMP ist nie gebaut — alles im Workstation-Plan,
nichts davon behauptet, bis es ausgeliefert ist.
⭐ **2026-10-03 (Audit MKT-1): „Sample-Import“ ist aus dieser Überschrift gestrichen** — die Workstation importiert Audiodateien auf eine Spur (Audio Import V1), und ein Verbot, das diesen Weg mit-verneint, ist eine Unter-Behauptung. Verboten bleibt ein Sampler-INSTRUMENT (Pads, Sample-Browser). Ebenso „Mehrspur-Recorder“ → **Audio**-Mehrspur-Recorder: MIDI-Takes nimmt die Workstation auf (siehe ✅-Zeile „Workstation“).
**Das VERBOT gilt unverändert — der Nutzer kann nichts davon aufrufen.** Die Begründung
war falsch und ist der Grund, warum dieser Abschnitt jetzt drei Fälle unterscheidet
statt einen: es stand hier *„Alles entfernt oder nie gebaut"*, und „nie gebaut" ist für
zwei der sieben Einträge per `git grep` widerlegbar. Das ist exakt der Defekt, den
derselbe Commit aus §8 entfernt hat: **eine widerlegbare Begründung entwertet ein
richtiges Verbot** — wer sie prüft und kippen sieht, kippt das Verbot gleich mit.

- **Gelöscht, existiert nicht mehr:** Drums/Beats (#166/#167 — `DrumSynthVoice`,
  `LaneDrumKitVoice`, `DrumNoteMap` sind als Dateien weg), Sample-Import/Browser
  (`SampleBrowserView` mit #167 gelöscht), Video-SCHNITT (#121 Slice 3).
- **Im Code, aber nicht verlinkt:** RTMP — `BroadcastPublisher` ist ein
  `#if canImport(HaishinKit)`-Gerüst, `Package.swift` hat `dependencies: []`.
- **Betürt seit 2026-10-10 (GA-4):** `SamplerVoice` — ⛔ stand hier als „gebaut, aber für den
  Nutzer TÜRLOS“ (keine Oberfläche, die Samples in die Hand gibt). `LaneVoiceRack.samplers` +
  `loadSampleIfNeeded`, Tür `TrackSampleRow`; der Eintrag bleibt als Herkunft, die Behauptung
  steht oben in ✅. Was NICHT zurück ist: das Drum-KIT und der Beat-Maker.
  ⛔ **`MultiTrackRecorder` stand hier an erster Stelle und ist GELÖSCHT** (#1302, Founder
  2026-09-12, „Face und Audio Input komplett entfernen"). Der Eintrag beschrieb ihn als „in
  `AudioEngine` bedingungslos angelegt" — die Datei existiert nicht mehr, und mit dem
  Mikrofon ist auch das weg, was er aufgenommen hätte. `FeatureFlags.audioLaneRecording`
  lebt weiter und hat seit #1302 KEINEN Zweig. ⚠️ **Für Content ändert das nichts am
  Verbot und alles an seiner BEGRÜNDUNG**, und genau dafür ist die Liste da: der Absatz
  unten sagt, „nie gebaut" lade eine Sitzung ein, etwas neu zu bauen, das schon da sei —
  bei diesem Posten ist heute das Gegenteil wahr, es ist wirklich weg, und wer ihn nach
  dieser Zeile wieder anfassen will, fängt bei null an und braucht eine Founder-Frage.

**Für Content heißt das dasselbe wie vorher: nicht behaupten** (den Sampler je Spur
ausgenommen, siehe ✅). Der Unterschied liegt
nicht im Verbot, sondern in seiner Haltbarkeit — und darin, dass „nie gebaut" eine
Session dazu einlädt, etwas neu zu bauen, das schon da ist.

### 6b. „spielt die Stimmen" (Plural) — gestrichen 2026-08-23 (#774)

Die Zeile im Wahr-Register hieß **„externer Controller spielt die Stimmen"**. Gemessen:
`git grep -n controllerEvents -- Sources` (kommentar-bereinigt) liefert außerhalb von
`EngineBus` **genau einen** Verbraucher — `BioReactiveSynthVoice`, und der ist monophon
(`apply(controller:)` ruft `playNote(` genau einmal, auf ein `synth` — #943b, siehe die Zeile in der Tabelle oben).
`PolySynthVoice` abonniert den Bus zwar, aber nicht diese Topic; die Stimme im
`LaneVoiceRack` ist laut eigenem Kommentar „NEVER subscribed to the bus".

**Es ist genau dasselbe Wort, das #548 aus `CLAUDE.md` gestrichen hat** („notes, plural —
unreachable by construction"), und es stand hier weiter in der Datei, deren einziger Zweck
es ist, falsche Captions zu verhindern. Die Zeile direkt darunter (MIDI-AUSGANG) war die
ganze Zeit peinlich genau — „gespielte NOTEN an dein Rig (MIDI 1.0)", mit Schalter und
Default. Eine Zeile ehrlich zu schreiben härtet die daneben nicht.

*Erlaubt: „steck einen Controller an und spiel die Körperstimme", „Noten und Pitch-Bend
kommen an". Nicht erlaubt: „spielt die Stimmen", „spiel Akkorde", „polyphon".*

⚠️ Nicht überkorrigieren: der Eingang ist NICHT hinter dem „Body voice"-Schalter versteckt —
`apply(controller:)` ist ausdrücklich nicht `isArmed`-gated („the performer always leads").
Ein Controller klingt sofort. Nur eben einstimmig.

### 6. MPE
Aus dem I/O-Satz gestrichen. ⛔ **Die BEGRÜNDUNG, die hier stand, ist seit #713 falsch**
(„die Schalter haben seit dem Tools-Grid-Removal keinen Schreiber") — „MPE note layout"
und „Per-note expression" sind persistiert und haben zwei Schalter in der erreichbaren
Routing-Fläche. Der Schluss hält aus einem ANDEREN Grund: **MPE OUT ist real und
schaltbar, MPE IN nicht** (#548). `MIDIBusPublisher` parst MPE-Verkehr, unterscheidet
aber keine Zonen, und `BioReactiveSynthVoice.apply(controller:)` liest `event.channel`
nirgends — es gibt also keinen Member-Kanal zu unterscheiden.

⛔ **Die BEGRÜNDUNG, die hier stand, ist mit #942 abgelaufen — der SCHLUSS nicht.** Sie
lautete: der Verbraucher laufe „für Slide (CC 74), Air und Channel Pressure in ein einziges
`break` — genau die drei Dimensionen, die MPE erst zu MPE machen". Zwei Fehler in einem Satz.
Erstens ist `.airCC` (CC 21–31) gar keine MPE-Dimension; MPE hat Pitch-Bend, CC 74 und Channel
Pressure — und Pitch-Bend klang schon immer. Zweitens klingen seit #939 (Press) und #942
(Slide) **alle drei**. Trotzdem bleibt „MPE-Eingang" verboten, weil die fehlende Hälfte nie
die Anzahl war: **eine Zone ist das, was MPE hinzufügt**, und RPN 6,6 hat auf dem Eingang
keinen Erzeuger. Ein richtungsloses „MPE"-Wort in einer Caption verspricht also weiter die
Hälfte, die fehlt.

⛔ **UND DIE REGELZEILE, DIE HIER STAND, WAR SEIT #713 ZU BREIT — gestrichen 2026-08-24
(#780).** Sie lautete *»Nicht erlaubt: MPE, per-note expression, spielt Deinen
MPE-Controller«* und verbot damit auch die Hälfte, die AUSGELIEFERT ist. Zwei Kosten,
beide konkret: »per-note expression« ist die wörtliche Beschriftung eines Schalters, den
der Nutzer auf dem Schirm sieht (`PatchbayView`) — eine Caption durfte eine sichtbare
Bedienstelle nicht benennen; und ein Rig-Besitzer las »nein«, wo die App »ja« sagt. **Der
Absatz DARÜBER sagte seit #548 das Richtige** (»MPE OUT ist real und schaltbar, MPE IN
nicht«) — die Begründung wurde nachgeführt, die Regelzeile nicht, und die Regelzeile ist
die, die ein Skript-Autor kopiert. Genau die Lücke, die #775 auf der Website geschlossen
hat und die hier einen Zyklus länger stand, in der Datei, deren einziger Zweck es ist,
falsche Captions zu verhindern (#456: jede Heimat im selben Commit).

⚠️ **Der GRUND für das Verbot bleibt gültig und trägt die neue Fassung: ein RICHTUNGSLOSES
»MPE« verspricht die fehlende Hälfte.** Deshalb ist das Richtungswort Pflicht, nicht
Geschmack — »MPE« allein bleibt verboten, »MPE-Ausgang« ist erlaubt.

*Erlaubt: »MIDI-Noten raus an Dein Rig«; »MPE-AUSGANG an Dein Rig« bzw. »MPE out« — immer
MIT dem Wort Ausgang/out; »per-note expression RAUS an Dein Rig«. Nicht erlaubt: ein
richtungsloses »MPE«; »MPE-Eingang«; »spielt Deinen MPE-Controller«; »per-note expression«
ohne Richtungswort.*

### 7. Abo, „Pro", Paywall, „Monthly/Annual Access", MRR
**v1.0 ist vollständig KOSTENLOS und zeigt KEINE Kauf-Oberfläche.** Das ist eine
protokollierte Founder-Entscheidung (2026-07-10, zweite des Tages, sie hebt das
Einmal-Pro desselben Tages auf) und steht wörtlich im Code über `WorkspaceView.body`:
Umsatz kommt erst in **v1.1** als „Echoel Live"-Jahresabo (~29,99 €, weltweite
SharePlay-Sessions) plus Event-Gebühr in v1.2. `ProUnlockView` / `EchoelStore` /
`ProGate` kompilieren, werden aber **nirgends präsentiert** — sie liegen bereit, um
dafür umgewidmet zu werden.
⛔ **Der Abo-Plan in diesem Absatz ist seit 2026-10-17 ABGELÖST** (`decisions.csv`, ECHOEL_VISION §7): kein
„Echoel Live“-Abo, keine Event-Gebühr — die App bleibt frei, eigene Instrumente werden einmal gekauft (für das
Studio gebaut, noch nicht im Verkauf, siehe Nachtrag (1) oben). Der Absatz bleibt als Geschichte stehen; die
Außenregel darunter gilt weiter, für das Studio zusätzlich „geplant als Einmalkauf, kein Abo“.
Ein Preis in einer Caption ist keine Übertreibung, sondern eine **Falschangabe im
App-Store-Sinn** (2.3 „Accurate Metadata") und enttäuscht jeden, der deshalb lädt.
*Erlaubt: „kostenlos". Nicht erlaubt: irgendein Preis, „Pro-Version", „Abo", „Trial".*

### 8. Tech-Stack-Behauptungen: „TCA", „RevenueCat", „SwiftData", „VideoToolbox", „HaishinKit"
`Package.swift` hat ein **leeres `dependencies`-Array** — Echoel hat heute NULL externe
Abhängigkeiten, und das steht oben in der ✅-Tabelle als eigene Behauptung.
Das klingt nach einem Entwickler-Detail, ist aber Marketing-Material, sobald ein
Text über Architektur, Investoren oder Stellen spricht — und es ist die Sorte
Behauptung, die man nicht mehr los wird, weil sie plausibel klingt.

Drei verschiedene Wahrheiten, und die Unterscheidung ist der Punkt:
- **Gar nicht vorhanden:** TCA (The Composable Architecture — wir sind SwiftUI +
  `@Observable`), RevenueCat, VideoToolbox. Null Vorkommen in `Sources/`.
- **Nur als Prosa erwähnt:** SwiftData — eine einzige Kommentarzeile in
  `SessionRecorder.swift`, die erklärt, dass wir es NICHT benutzen.
- **Im Code, aber NICHT VERLINKT:** HaishinKit. ⛔ Die erste Fassung dieses Eintrags
  schrieb „nicht im Code", und das ist mit einem `grep` widerlegbar:
  `BroadcastPublisher.swift` enthält ein `import HaishinKit` hinter
  `#if canImport(HaishinKit)`. Es ist ein Compile-Gerüst ohne Paket — die
  Marketing-Folge (nie RTMP/Livestream behaupten) bleibt dieselbe, aber die
  Begründung muss stimmen: **eine Datei, deren ganze Autorität darauf beruht, nicht
  widerlegbar zu sein, darf keine widerlegbare Begründung tragen.**

*Persistenz = `Codable` + JSON, Video-Encode = `AVAssetWriter`, StoreKit nativ.*

### 9. „Biohacking"
Gehört fachlich zu Punkt 2 und steht trotzdem hier, weil es dort **nicht** in der
Aufzählung stand und deshalb durchrutschte. Es ist die Vokabel, die Echoel in genau
die Ecke stellt, aus der die Marke ausdrücklich heraus ist: Optimierungs-Szene statt
Instrument. **Nie in Skript, Caption, Hashtag oder Titel.**

### 10. „Postet automatisch auf TikTok/YouTube/Instagram", „MCP in der App"
Die App **veröffentlicht nichts**. Sie NIMMT auf und EXPORTIERT (WAV-Aufnahme des
eigenen Ausgangs, MIDI-Export) — die Verteilung passiert danach von Hand oder über
diese Pipeline auf einem Rechner. (⛔ Das Video-Panel mit mp4-Teilen stand hier und
ist mit #1304 gelöscht.)
Drei unabhängige Gründe, damit die Behauptung nicht in anderer Form wiederkommt
(die beiden letzten sind Aussagen über FREMDE Plattformen, Stand 2026-07-31 — sie
altern, ohne dass es hier jemand merkt; vor einer Kampagne kurz nachsehen):
**MCP ist ein Agenten-Host-Protokoll, keine App-Fähigkeit** (es verbindet ein Modell
mit Werkzeugen — eine iOS-App „macht" kein MCP); die **Posting-APIs der Plattformen
sind gated** (eigener Review je Plattform, OAuth, Business-/Creator-Konten, bei TikTok
ein bestandenes Audit — Privatkonten weitgehend gar nicht); und ein Multi-Plattform-
Publisher wäre ein **zweites Produkt** neben dem Instrument.
*Erlaubt: „den fertigen Loop teilen“. Nicht erlaubt: „postet für Dich“. ⛔ „das fertige
Video teilen“ stand hier und ist mit #1304 gegenstandslos — die App erzeugt kein Video.*

### 11. Stimme: „nimmt Deine Stimme auf", „Voice Cloning", „AI-Voice", „Text-to-Speech", „Autotune auf der Musik"

⛔ **SEIT #1302 (Founder 2026-09-12, „Face und Audio Input komplett entfernen") IST DIE GANZE
STIMM-FÄHIGKEIT UNBEHAUPTBAR — nicht nur die vier Formulierungen in der Überschrift.** Es gibt
kein Mikrofon mehr: `MicrophoneManager`, `AudioInputManager`, `VoiceCaptureEngine`,
`VoiceAnalyzer`, `VoicePitchCorrector`, `FeedbackGuard` und das Input-Sheet sind als Dateien
gelöscht. Ein Reel, das irgendetwas über die Stimme des Spielers sagt, beschreibt eine App, die
nicht existiert. **Die Unterscheidung darunter bleibt trotzdem stehen, weil sie das GESETZ ist,
nach dem eine künftige Stimm-Fähigkeit beschrieben werden müsste** — und weil §11 sonst als
gelöst gelesen würde statt als ausgesetzt.

Die Stimm-Fähigkeit war eine **MESSUNG, keine Aufnahme** — das ist die eine
Formulierung, an der hier alles hängt. `VoiceTimbreProfiler` misst eine
Spektral-Hüllkurve (**64 Zahlen**), das Audio selbst wird **nie gespeichert**;
das Mikrofon-Versprechen der App bleibt wörtlich wahr, und ein Reel, das „records
your voice" sagt, macht aus einem Privacy-Vorteil einen Privacy-Verdacht.
Ebenfalls nicht behaupten, weil per Entwurfs-Grenze ausgeschlossen (EchoelVoice
v1, protokolliert): **kein TTS**, **kein Stimm-Klon / keine Synthese Deiner
Sprechstimme**, **kein Import fremder Stimmen** — die Farbe kommt vom lebenden
Spieler am Gerät, und ein gespeicherter Patch trägt immer ein Namens-Label
(Share-Label-Gesetz: nie anonym, keine Misattribution). ⛔ Und „Tune to key" ist
seit #1024 **gar nicht mehr behauptbar** — nicht weil es falsch wäre (es war und
bleibt Monitor-only, die komponierte Musik läuft nie durch einen Autotune),
sondern weil der Founder alle drei Mikrofon-Türen entfernt hat und die Stufe
damit unerreichbar ist. Siehe die gestrichene Zeile in der Tabelle oben.
*Erlaubt: NICHTS über die Stimme, solange kein Mikrofon existiert. Die früher erlaubten
Formulierungen — „das Instrument klingt nach Dir", „gemessen, nie aufgenommen" — stehen hier
als Muster für den Tag, an dem eine Tür zurückkommt. Nicht erlaubt: „AI voice", „clones your
voice", „records you", „Autotune auf dem Track" — und seit #1302 auch nicht die erlaubten.*


### 12. Atemtiefe und LF/HF als Klang-Abbildung — der Kohärenz-TREND ist seit #813 WAHR
**Zwei Bio-Kanäle bewegen heute NICHTS, und sie klingen in einer Caption besonders gut** —
genau deshalb steht das hier. Gemessen: `breathDepth` und `lfHf` sind an BEIDEN
Konstruktionsstellen (`BioReactiveSynthVoice`, `PolySynthVoice`) auf das Literal `0.5`
festgenagelt. Der Atemtiefen-Faktor ist damit auf jedem Frame exakt 1,0, und `lfHfRatio`
wird im Rumpf gar nicht gelesen. `applyBioReactive` sagt es an der Stelle selbst: *„must
not be claimed as live in any user-facing copy."*

⛔ **Hier standen DREI Kanäle, und der dritte war beim Audit 2026-08-28 seit zwei Wochen
falsch:** `coherenceTrend` hat seit **#813** einen echten Produzenten — `Core/CoherenceTrend`
leitet aus der Kohärenz-HISTORIE eine Änderungsrate ab, und beide Konstruktionsstellen
übergeben `coherenceTrend: trend` statt der Literal-0 (nachmessbar:
`git grep -n "coherenceTrend: trend" -- Sources` → zwei Treffer). **„Der Kohärenz-Trend
morpht die Klangform (steigend/fallend)" ist damit ERLAUBT** — mit der ehrlichen Fußnote,
dass die SKALA des Effekts eine Schätzung ist (NEEDS-FOUNDER-VERIFY am Gerät). Diese Datei
war die Fläche, die #813 NICHT mitzog, und sie hat damit vierzehn Tage einen wahren Claim
verboten und eine widerlegte Messung behauptet — genau der Defekt, vor dem §5 warnt: eine
widerlegbare Begründung entwertet auch ein richtiges Verbot.

**Das ist die Behauptung mit den meisten Fundstellen in der Geschichte dieses Repos.** Sie
wurde dreimal getilgt: #496 aus der App-Kopie (drei Wächter, alle lesen nur Swift), #755
aus `docs/overview.html`, #757 aus dem **englischen** App-Store-Text — wo die deutsche
Fassung derselben Anzeige die ganze Zeit ehrlich war. Diese Datei war die vierte Fläche und
hatte keinen Eintrag; ein Skript-Autor, der sie liest, hätte nichts gefunden, was ihn
aufhält.

⚠️ **LF/HF wird sehr wohl BERECHNET** (`HRVCoherence`, Welch + Lomb-Scargle) — die FAQ nennt
das korrekt „LF/HF-Analyse". **Analysiert ist nicht abgebildet.** Verboten ist der Pfeil,
nicht das Wort.

**Was stattdessen stimmt — die geprüfte Vier-Kanal-Tabelle** (`AlwaysOnBioChannel.shapedParameters`):
Kohärenz → Filter-Cutoff · Brillanz · Harmonizität · Rauschanteil ·
HRV → Brillanz · Herzfrequenz → Vibrato (Tiefe UND Rate) · Brillanz ·
Atem**phase** → die Amplituden-Schwelle · **Kohärenz-Trend → Klangform-Morph (#813)**.
Daraus zitieren.
*Erlaubt: „Dein Atem lässt den Klang anschwellen und wieder absinken", „wird dein Körper
ruhiger, verschiebt sich die Klangfarbe". Nicht erlaubt: „Deine Atemtiefe formt das
Rauschen", „LF/HF kippt das Spektrum".*

---

## Woher die Punkte 7–10 kommen — und was das über diese Datei sagt

Am **2026-07-31** legte der Founder ein durchdachtes Strategiepapier vor. Es enthielt
in einem Dokument: ein **AUv3-Plugin** als Content- und Umsatzsäule (Punkt 1, seit
2026-07-24 gelöscht), **TCA** und **RevenueCat** als bestehende Architektur (Punkt 8,
null Codezeilen), **watchOS-Einbindung** als ausgelieferte Eigenschaft (Punkt 3, Embed
in `project.yml` blockiert), **„Biohacking"** als Content-Fokus (Punkt 9) und ein
**Abo-Modell** als nächsten Schritt (Punkt 7, gegen die eigene Entscheidung des
Founders).

Fünf Falschbehauptungen, gut geschrieben, plausibel — und **nur eine davon** (AUv3)
stand vorher in dieser Datei. Die Lehre ist nicht „mehr Zeilen", sondern eine
**zweite Achse**: bis hierhin listete die Datei nur FEATURES. Erfunden werden aber
genauso zuverlässig **Tech-Stack**, **Preis/Geschäftsmodell** und **Vertriebswege**,
weil ein Modell (oder ein Berater) sie aus dem Umfeld ähnlicher Apps ergänzt, wo sie
üblich sind. Wer hier einen Punkt ergänzt, prüfe deshalb nicht nur „kann die App
das?", sondern auch **„kostet sie das?", „ist das im Stack?", „geht das da raus?"**

---

## Sprache

- Marke: **Echoel**. Nie „BLAB", „Vibrational Force", nie Heilfrequenzen, Chakren, Solfeggio.
- **Wissenschaft zuerst:** lesbare Zahl vor Deko-Visual. HRV-Resonanz ist zitierbar
  (Lehrer/Vaschillo, Goessl 2017) — als *Forschungslage*, nie als Versprechen.
- Blitzrate in jedem Videomaterial **≤ 3 Hz** (W3C WCAG, Epilepsie). Das gilt auch für
  den Schnitt, nicht nur für die App.
- Diese Pipeline ist **PIPELINE-ONLY**: sie fasst `Sources/` niemals an.
