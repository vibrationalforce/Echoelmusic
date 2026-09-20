# Founder Device Session — was NUR am Gerät entschieden werden kann

**Stand 2026-08-25 (#816).** Diese Datei ist die **Urteils-Hälfte** der Geräte-Sitzung.
Die code-verankerten Bitten stehen NICHT hier, sondern im Werkzeug:

```
python3 scripts/founder-verify.py
```

Es sammelt jede `NEEDS-FOUNDER-VERIFY`-Zeile aus `Sources/`, `Tests/` und `CLAUDE.md` und
gruppiert sie nach Bereich. **`scratchpads/` durchsucht es ABSICHTLICH nicht** (sein eigener
Kopf sagt: „scratchpads sind Sitzungsprosa, keine Bitten"). Genau daran ist diese Datei
kaputtgegangen: sie war eine ZWEITE Liste, die kein Werkzeug sah und kein Wächter prüfte —
und deshalb konnte sie zwei Monate lang um Prüfungen bitten, die niemand mehr ausführen kann.
Der ⛔-Abschnitt unten führt jede einzelne mit Messung auf.

**Was hier steht:** nur Punkte, die kein Marker tragen kann, weil sie an keiner Codezeile
hängen — Screenshots, Ein-Feld-Entscheide, Klang- und Gefühls-Urteile, offene Fragen an Dich.

**Was in DIESEM Build zu drücken ist,** steht in der Build-Notiz `.deploy/release`.
Diese Datei wiederholt sie nicht (#416: eine Entscheidung, ein Zuhause).

---

## 1 · ⛔ DER BLOCKER IST WEG — DIESER ABSCHNITT IST GESTRICHEN (#1346, 2026-09-16)

⭐ **Das ist die GUTE Nachricht dieser Datei, und sie stand bis heute als ihr Gegenteil da.**
Der Abschnitt hieß „Der eine Handgriff — er blockiert die ganze Vokal-Kette" und nannte als
Handgriff: *Mix-Panel → „Voice - your microphone" → „Choose input…" → **Live monitoring***.
**Den Handgriff gibt es nicht mehr, und die Kette, die er blockierte, auch nicht** — Du hast
den Audio-Eingang am 2026-09-12 selbst zurückgenommen (#1302, wörtlich „Face und Audio Input
komplett entfernen") und die Stufen darauf einen Commit später (#1305, „Kein audioninout kein
Autotune, Harmonizer, granularsynthese").

Gemessen heute, nicht erinnert:

| Was der Abschnitt verlangte | Messung |
|---|---|
| Mix-Panel → „Choose input…" → Live monitoring | `AudioInputPickerView`, `MonitorInsertAU`, `MonitorTapWindow` sind als DATEIEN gelöscht (#1302). Es gibt keinen Schalter. |
| Zeiger `Audio/MonitorInsertAU.swift:174` | `git ls-files 'Sources/**/MonitorInsertAU.swift' \| wc -l` → **0**. |
| Zeiger `Audio/AudioConfiguration.swift:300` (Bluetooth) | Die Datei lebt, die Bitte sitzt bei **:343** — die Zeilennummer war zusätzlich abgelaufen. Die Bitte selbst ist seit #1302 nicht ausführbar und trägt jetzt `BLOCKED-BY-#1302` (siehe unten). |
| V0 → V1a → V1b (`decisions.csv:398`), „Harmonizer und Granular auf die STIMME" | `EchoelHarmonizer`, `EchoelGranular`, `DiatonicHarmony`, `HarmonyInterval` sind als DATEIEN gelöscht (#1305). Es gibt keine V1a und keine V1b. |

**Konsequenz, und sie ist der Punkt:** die Geräte-Sitzung hat **keinen Blocker mehr**. §2 bis §5
sind heute vollständig ausführbar; nichts wartet mehr auf einen Handgriff, den niemand machen
kann. Wer diese Datei von oben las, plante bis heute eine Sitzung um ein Bedienelement herum,
das seit vier Tagen nicht existiert.

⚠️ **DIE BITTE IST GESTRICHEN, DIE MASCHINE NICHT.** `recordOptions`, `routeCodec` und die
`session:`-Sprossen in `AudioConfiguration` sind unangetastet — nur ruft seit #1302 **niemand**
mehr `upgradeToPlayAndRecord()`, also wird `.playAndRecord` nie betreten und `recordOptions` nie
angewandt (`git grep -n "upgradeToPlayAndRecord()" -- Sources` → nur die Deklaration). Kommt ein
Eingang zurück, kommt die Bitte mit ihm zurück — deshalb steht sie als **BLOCKED**, nicht als
gelöscht (`python3 scripts/founder-verify.py` druckt sie in einem eigenen Abschnitt).

⛔ **ZWEI FRÜHERE RÜCKNAHMEN DIESES ABSCHNITTS BLEIBEN LESBAR, weil sie zusammen die Lehre
tragen.** (1) 2026-09-05: der Zeiger zeigte auf `.deploy/release` („heute v10.79.418"), während
der ausgelieferte Build 447 war und `grep -in "monitoring\|Choose input" .deploy/release`
**nichts** lieferte. Der Fehler war nicht die veraltete Zahl, sondern die **Wahl des Zuhauses**:
`.deploy/release` wird bei jedem Build neu geschrieben, ein *stehender* Blocker gehört dort
strukturell nicht hin — der Zeiger musste kaputtgehen, die einzige Frage war wann. (2) Die
Reparatur verlegte ihn daraufhin auf **zwei Code-Marker** — und elf Tage später war der eine
gelöscht und der andere um 43 Zeilen verrutscht. **Ein Code-Marker ist das richtige Zuhause und
trotzdem kein unsterbliches: ein Zeiger ist nur so haltbar wie das, worauf er zeigt.** Das
Werkzeug, nicht die Zeilennummer, ist die Adresse — `python3 scripts/founder-verify.py`.

---

## 2 · Kern-Klangpfad — die Punkte, die weiterhin ausführbar sind

⚠️ **Diese Liste stand schon in der Fassung von 2026-07-16 und wäre bei der #816-Aufräumung
beinahe mit-gestrichen worden.** Der erste Entwurf schob sie „in die `NEEDS-FOUNDER-VERIFY`-
Marker" — ohne sie dorthin zu schreiben. Gemessen: das Werkzeug deckt keinen dieser Punkte ab.
**Eine Streichung mit dem Zusatz „gehört woanders hin" ist erst dann eine, wenn der Umzug
stattgefunden hat.** Bis Marker existieren, ist das hier ihr Zuhause.

- [ ] **multiRoll** (Flag registriert, also AN): zwei dichte MIDI-Spuren gleichzeitig hörbar?
      Jede mit eigenem Timbre? CPU < 30 %, Speicher im Rahmen (Xcode-Gauge beim Spielen)?
- [ ] **voiceKindRouting** — **Bass-Spur wummert** fühlbaren Sub, und **bei A≠440 in Tune**
      (einmal mit A = 432 gegenprüfen). Poly-Spuren unverändert.
- [ ] **Kein hängender Ton** beim Instrumentwechsel mitten im Take.
- [ ] **Live-Same-Region-Wechsel:** Instrument der Primary-Spur MITTEN im Take ändern, ohne eine
      Regionsgrenze zu kreuzen — bindet der Roll die Stimme erst an der nächsten Grenze neu?
      Falls das stört, ist der Fix ein gezieltes Re-Fire, kein Umbau.
- [ ] **Launch bleibt still** bis zum ersten Arm (keine Bio-Stimme beim Start).
- **Rollback für jedes Flag:** `FeatureFlags.set(.<flag>, false)` — eine Zeile.
- ⛔ **Der Punkt „Drums-Spur trommelt" ist hier ersatzlos weg**, siehe ⛔-Tabelle: es gibt keine
      Schlagzeug-Stimme mehr.

---

## 2b · AUv3 „EchoelBodyVibe" im Fremd-Host — ✅ **BEANTWORTET für AUM am 2026-09-20 (#1386)**

⭐ **ES LÄDT.** Der Founder hat auf Build 2595 (v10.79.475) eine 26-Sekunden-Bildschirmaufnahme
aus **AUM** geliefert, und sie beantwortet die `-3000`-Frage, an der dieses Target im Juli
gestorben ist. Gemessen aus den Einzelbildern und der Tonspur der Aufnahme:

- **Registrierung:** `AUDIO UNIT EXTENSION → ECHOELMUSIC → EchoelBodyVibe · INSTRUMENT PLUGIN (AU)`,
  mit dem Echoel-Icon. (War nie das Problem — hier nur der Vollständigkeit halber.)
- **Instanziierung: ERFOLGREICH.** Kanal `1: EchoelBodyVibe` entsteht, kein Fehler, kein leerer
  Slot. **Damit ist die App-Group-Hypothese aus `EchoelmusicAUv3.entitlements` BESTÄTIGT** —
  das ersatzlose Streichen des Entitlements IST die Reparatur, und sie ist jetzt nachgemessen
  statt vermutet.
- **Oberfläche: rendert.** Kopf „Echoelmusic / Bio-Reactive Instrument", Gruppe `BIO-REACTIVE`
  mit vier Reglern (Coherence · HRV · Heart Rate · Breath), alle auf 50 %.
- **Ton: kommt.** Master-Meter geht von `-∞` auf `-10 … -12 dBFS`.
- **Tonhöhe bei 48 kHz: RICHTIG.** FFT über die stabilen Sekunden 5–8 der Tonspur (44,1 kHz,
  131 072 Punkte, Hann, parabolisch interpoliert): Grundton **220,15 Hz** gegen den
  `baseFrequency`-Default von **220 Hz** = **+1,2 Cent**. Dazu die erwartete Harmonischenreihe
  (440,3 · 660,5 · 880,9) und ein Teilton bei **110,0 Hz**, der die Textur-Stimme ist
  (`texture.frequency = value * 0.5`).

⚠️ **WAS DAS NICHT BEWEIST — EIN Host, nicht jeder.** Logic Pro und GarageBand sind unverändert
ungeprüft. Die offenen Häkchen dafür stehen unten. Der Wächter
`TheStandingPromptDescribesThisRepoTests.testNoRoutineClaimsAUv3HostCompatibility` hat deshalb
mit #1386 nur **AUM** aus seiner Host-Liste verloren, nicht die Liste.

### Was JETZT noch offen ist

- [ ] **GarageBand iOS (44,1 kHz) — die Tonhöhen-Probe.** Board A10 sagt ~8,8 % zu hoch voraus,
      und die AUM-Messung oben hat diese Vorhersage **gestützt, nicht widerlegt**: richtig genau
      dann, wenn die Hostrate der fest genagelten entspricht. Klingt es dort hörbar zu hoch?
      *(Wenn ja: erwarteter Befund, keine Regression. Wenn NEIN: dann folgt der Synth dem
      Host-Format doch irgendwo, und A10 ist falsch analysiert — das wäre die interessantere
      Antwort.)*
- [ ] **Logic Pro (iPad/Mac), falls verfügbar** — lädt es dort?
- [ ] **Noten spielen.** In der Aufnahme wurde keine Taste gedrückt; gehört hat man den
      freilaufenden Grundton. Offen bleibt also der MIDI-Pfad: Tasten → Tonhöhe folgt?

### ⛔ ZWEI BEFUNDE AUS DERSELBEN AUFNAHME, die vorher UNGEMESSEN waren

1. **CPU (Board A11) hat eine Zahl: rund 20 Prozentpunkte für EINE Instanz.** AUMs
   DSP-Anzeige liest **1 %** ohne Plugin und **19–24 %** mit genau einer Instanz, ohne dass
   eine Note gespielt wird. Das ist hoch — vier Instanzen wären das Gerät. Die billige
   Abhilfe bleibt `textureAmount` per Default auf 0; die richtige ist Vektorisierung.
   ⚠️ Die Zahl ist AUMs Anzeige bei DESSEN Puffergröße, kein Xcode-Profil — sie ist ein
   Größenordnungs-Befund, kein Messwert für das Budget in `CLAUDE.md`.
2. **Das Plugin klingt, SOBALD es geladen ist — ohne Note, ohne Transport.** Das ist so
   gebaut (`allocateRenderResources()` ruft `synth.noteOn(frequency: baseFreqParam.value)`,
   und der Render-Block sagt es selbst: *„With NO note event … the free-running bio tone
   armed in allocateRenderResources keeps playing"*). In einem Host ist das eine
   **Entscheidung, kein Fehler** — aber eine, die der Founder treffen muss: Spur anlegen →
   sofort Drone bei −10 dBFS. Konventionell schweigt ein Instrument, bis eine Note kommt.
   Eine Alternative wäre, den Ton erst bei der ersten Note oder beim ersten Transport-Start
   zu armen. **Nicht einseitig geändert.**

⚠️ Die Aufnahme zeigt außerdem, dass der Founder EchoelBodyVibe in AUMs Liste
**MIDI PROCESSORS** gesucht hat. Dort steht es nicht und kann es nicht stehen: es ist ein
`aumu` (Instrument), kein `aumi` (MIDI-Prozessor). Das ist genau die zweite Komponente, die
aus derselben Extension vendbar wäre (`AudioUnitViewController` erfüllt bereits
`AUAudioUnitFactory`) — eigener Posten, kein neues Target.

---

### Der ursprüngliche Auftrag, als Protokoll (Stand #1385, vor der Messung)

**Neu am 2026-09-20 (#1385).** Das AUv3-Target ist zurück (Founder-Auftrag, ohne JUCE — es war
schon immer reines Swift). Es kompiliert und wird in die App eingebettet. Was **nicht** bewiesen
ist, ist das Einzige, was zählt: **ob iOS die Extension startet.**

Die Vorgeschichte steht wörtlich in `EchoelmusicAUv3.entitlements`: am 2026-07-19 registrierte
sich EchoelBodyVibe korrekt (AUM listete es), scheiterte aber in **jedem** Host beim
Instanziieren mit `-3000 invalidComponentID` — die host-unabhängige Signatur eines Appex, dessen
Prozessstart iOS **verweigert**. Die Hypothese war ein App-Group-Entitlement, das die App-ID
`com.echoelmusic.app.auv3` im Portal gar nicht trägt. Die Reparatur — das Entitlement ersatzlos
streichen — ist gebaut und ausgeliefert, **aber nie nachgemessen**: fünf Tage später wurde das
Target gelöscht, und damit wurde die Frage nicht beantwortet, sondern gegenstandslos.

Sie ist jetzt wieder gegenständlich.

- [ ] **Build installieren, dann EINMAL GarageBand öffnen und wieder schließen.** Das forciert
      eine Neuregistrierung der Audio-Komponenten — ohne den Schritt kann ein veraltetes
      Geräte-Register ein falsches Negativ liefern (das war der A8-Workaround).
- [ ] **AUM oder GarageBand → Instrument-Slot → Hersteller „Echo" → „Echoelmusic: EchoelBodyVibe".**
      Erscheint es in der Liste? *(Erscheinen = Registrierung OK, das war nie das Problem.)*
- [ ] **Antippen zum Laden.** **Das ist die eigentliche Frage.** Öffnet sich die Plugin-Oberfläche,
      oder kommt ein Fehler / bleibt der Slot leer?
- [ ] Falls es lädt: **Tasten spielen — kommt Ton?** Und schiebt der Host-Transport nichts kaputt?
- [ ] Falls es **nicht** lädt: `echoel_diag.log` exportieren. Die Zeile mit `ownAUv3` sagt, ob das
      Gerät die Komponente überhaupt kennt.

⚠️ **ZWEI DINGE VORHER WISSEN, damit Du einen BEKANNTEN Fehler nicht für einen kaputten Build
hältst** (beide am 2026-09-20 vom `audio-thread-reviewer` gefunden, beide als A10/A11 auf dem
Board, beide absichtlich NICHT in dieser Nacht repariert):

1. **In GarageBand klingt es voraussichtlich ~8,8 % ZU HOCH.** Der Synth ist hart auf 48 kHz
   genagelt und folgt dem Host-Format nicht; GarageBand iOS läuft auf 44,1 kHz. In AUM (48 kHz)
   sollte die Tonhöhe stimmen. **Wenn es in AUM richtig und in GarageBand zu hoch klingt, ist das
   GENAU dieser Befund und kein neuer.** Die Reparatur greift in DSP-Code, den sich die App
   teilt — das ist eine eigene Scheibe mit Council, kein Einzeiler.
2. **CPU ist ungemessen.** Die Textur-Stimme rechnet ~1,5 Mio. skalare `sin()` pro Sekunde,
   un-vektorisiert. Wenn Du magst: einmal die Xcode-CPU-Anzeige mitlaufen lassen, während das
   Plugin im Host spielt. Falls es zu teuer ist, ist die billige Abhilfe `textureAmount` = 0.

**Was Deine Antwort freischaltet:** erst danach darf „läuft in Deiner DAW" irgendwo stehen —
Store-Text, Website, Social. Bis dahin hält `TheStandingPromptDescribesThisRepoTests` diesen
Claim gesperrt, und das ist Absicht: #158, #192 und #184 haben je einen ganzen Zyklus damit
verbracht, genau diese Behauptung wieder zu entfernen, und im App-Store-Text ist sie eine
2.3-Ablehnung. **„Kompiliert und ist eingebettet" ist nicht „lädt in Logic".**

---

## 3 · Die zwei Ship-Gate-Checks, die nur ein Mensch schließen kann

Von den fünf Checks des Gates „Instrument-Complete v1" (CLAUDE.md) sind **Kontrolle** und
**Modi** code-belegt und zu. Offen sind genau die zwei sensorischen:

- [ ] **Klang** — klingen die kuratierten Genres professionell? Bleibt die Identität eines
      Genres über eine Session erhalten (kein Zusammenlaufen)? Die strukturelle Hälfte ist
      im Repo gepinnt (`GenreFamilyDistinctnessTests`) — dass es GUT klingt, beweist kein Test.
- [ ] **Stabilität** — sauberer Start, kein Schwarzbild, kein Menü-Freeze während Biofeedback.
- [ ] (halb) **Ausgabe** — die Code-Hälfte ist seit #748 zu; offen bleibt das Urteil, ob das
      Visual auf dem Gerät wirklich **kontemplativ** wirkt.

---

## 4 · Screenshots — nur Du, am echten Gerät

- [ ] 6.9" Set (1320×2868), 8 Shots laut `docs/dev/APP_STORE_LISTING_v1.md` — die ersten drei:
      (1) Instrument spielt + Bio-Strip, (2) Immersive Visual, (3) „Generate from Body".
      Captions sind fertig getextet (keyword-tragend) — verbatim übernehmen.
- [ ] 6.5" Set falls bequem.

### 4b · Website-Aufnahme — **derselbe Termin, fast kein Mehraufwand** (2026-09-05)

⭐ **Warum das hier steht und nicht bei den Screenshots:** die Website hat auf **allen 24 Seiten
null** `<img>`, `<video>`, `<canvas>` oder `<iframe>` — der einzige Rasterbild ist `og-cover.png`,
eine typografische Marken-Karte, die nur als `og:image` referenziert wird. Ein Musiker beurteilt
ein Instrument in zehn Sekunden mit Auge und Ohr und bekommt einen Satz über einen Metal-Renderer.

⚠️ **Ich kann den Slot NICHT vorbereiten** — ein `<video>`/`poster`, das auf nicht existierende
Dateien zeigt, stellt ein totes graues Rechteck auf die LIVE-Seite. Das ist schlechter als die
ehrliche Leere. Also wartet die Seite auf genau eine Datei.

- [ ] **~8 Sekunden Bildschirmaufnahme** aus dem schwebenden Visual auf Größe **„Fullscreen"**
      (Kopf-Monitor antippen → Fenster → Größe), während ein Take läuft und Du auf dem Bild
      spielst (die Wasserringe unter den Fingern sind der Punkt — das ist die eine Geste, die
      kein Konkurrent hat).

      ⛔ Hier stand „aus dem **Vollbild-Visual**" und das war eine ANDERE Fläche: der
      `.fullScreenCover(isPresented: $showVisual)` ist mit **#1069** gelöscht. Die Aufnahme
      bleibt vollständig ausführbar — `FloatingVisualWindow` hat eine eigene
      `.fullscreen`-Größe (`WindowSize.fullscreen`, Beschriftung „Fullscreen") —, nur der WEG
      dorthin ist ein anderer. **Das ist eine Reparatur, keine Streichung** (#816: eine Bitte
      wird nicht gestrichen, weil ihr Zeiger veraltet ist, sondern nur, wenn die Fläche fehlt).
- [ ] **Ein Standbild aus derselben Aufnahme** als `poster` — dann zeigt die Seite auch etwas,
      wenn „Bewegung reduzieren" an ist oder das Video nicht lädt.
- [ ] Bedingungen: **kein Blitzen über 3 Hz** (das Gesetz gilt auch für Marketing-Material),
      keine persönlichen Daten im Bild, Hochformat.

**Kosten-Hinweis:** das ist DERSELBE Sitzungstyp wie §4. Wenn Du ohnehin die Store-Screenshots
aufnimmst, kostet die Website-Aufnahme praktisch nichts extra — nur einmal auf Aufnahme drücken,
bevor Du die Standbilder machst.

---

## 5 · Ein-Feld-Entscheide (kurz bestätigen, kein Gerät nötig)

- [ ] Privacy-Label = **„Data Not Collected"** (on-device, kein Server/Analytics/Account) — OK?
- [ ] Kategorie Music + Health & Fitness — OK?
- [ ] Preis Free, kein IAP in v1.0 — OK (Echoel Live = v1.1)?

---

## 6 · Offene Frage an Dich

- [x] **Voice clone — BEANTWORTET 2026-08-25: NEIN.** Die Antwort bleibt stehen; sie ist ein
      Datum und kann von nichts Späterem zurückgenommen werden.

      ⛔ **DER AUFTRAG DANEBEN IST VOM FOUNDER SELBST ZURÜCKGENOMMEN (#1346).** Er lautete:
      „Zugleich beauftragt: Monitoring direkt am Gerät, latenzfrei, mit Harmonizer- und
      Granular-Strategie auf der Stimme (ressourcenschonend). Der Bau läuft (#822 ff.); die
      Hör-Bestätigung bleibt Punkt 1." Am 2026-09-12 wörtlich: „Kein audioninout kein Autotune,
      Harmonizer, granularsynthese. Das hat leider nichtbgeklappt" (#1305), davor „Face und
      Audio Input komplett entfernen" (#1302). Der Bau läuft nicht mehr, und **Punkt 1 gibt es
      nicht mehr** — der Verweis zeigte auf den gestrichenen Abschnitt oben.
      ⚠️ **Eine ANTWORT und ein AUFTRAG stehen hier in einer Zeile und altern verschieden.**
      Die Antwort ist unverwüstlich, der Auftrag hing an einer Fähigkeit. Wer beides als eine
      Einheit gelöscht hätte, hätte eine Founder-Entscheidung samt Datum verloren.

---

## ⛔ Was gestrichen ist — und warum, gemessen am 2026-08-25

Die erste Fassung dieser Datei (2026-07-16) bündelte „ALLE geräte-gebundenen Punkte in EINE
Sitzung". Vier ihrer sieben Abschnitte baten danach um Prüfungen an Oberflächen, die es nicht
mehr gibt. **Das ist die teuerste Sorte veralteter Prosa in diesem Projekt: Geräte-Zeit ist die
knappste Ressource, und ein Posten, der auf ein entferntes Bedienelement zeigt, kostet eine
Probe, die nichts entscheiden kann** (dieselbe Lehre wie #525, nur auf Dokument-Ebene).

| Gestrichener Posten | Messung heute |
|---|---|
| **Piano-Roll-Editing** (6 Primitive, Velocity-Lane, Pin-Frage) | `grep -c "struct PianoRollView" Sources/Echoelmusic/Studio/PianoRollView.swift` → **0**. Der Editor ist mit #475 gelöscht, die Tür schon 2026-07-26 auf Founder-Wunsch („Pianoroll soll raus"). Keines der sechs Primitive ist ausführbar. |
| **Drums-Spur trommelt** (Slice-7-Gate, `.drums`-Bus-Frage) | Es gibt keine Schlagzeug-Stimme mehr: `DrumSynthVoice`, `LaneDrumKitVoice` und `DrumNoteMap` sind mit #166/#167 als Dateien gelöscht. Es kann kein Drum-Klang entstehen. Das Flag `voiceKindRouting` existiert weiter — der Rest des Gates (Bass, Poly, Stuck-Note) ist als Bitte in den `NEEDS-FOUNDER-VERIFY`-Markern zu führen, nicht hier. |
| **`laneAUInstruments`-Flag prüfen** | `git grep -l laneAUInstruments -- Sources Tests | wc -l` → **0**. Das Flag existiert nicht. |
| **AUv3 im Fremd-Host** (AUM/GarageBand) | ⭐ **DIESE STREICHUNG IST AM 2026-09-20 ZURÜCKGENOMMEN (#1385)** — der Founder hat das AUv3-Target zurückgeholt, und die Bitte ist damit wieder ausführbar. Sie steht jetzt als echter Posten in **§2b**. Die Zeile bleibt hier stehen, weil nichts gelöscht wird: sie ist der Beleg, dass diese Prüfung zwischen dem 2026-07-24 und dem 2026-09-20 **nicht** gestellt werden durfte. ⚠️ Die ZWEITE Hälfte der alten Begründung gilt unverändert: `grep -rn "AUv3\|AUM\|GarageBand" fastlane/metadata/ | wc -l` → **0** (#184), und das bleibt so, **bis** §2b beantwortet ist — der Store-Text darf dem Gerät nicht vorauslaufen. |
| **Warp-Hörtest im Audio-Clip-Editor** | Es gibt keine Clip-Editor-Tür: `git grep -ln "clipEditor\|ClipEditorView\|AudioClipEditor" -- Sources | wc -l` → **0**. Die Clip-/Arrangement-Fläche ging mit #121 Slice 4. Die Stretch-Kerne (`StretchPlan`, `AudioClipPlayer`) leben weiter, sind aber unerreichbar. |
| **BLE-Gurt-Begründung** | Die PRÜFUNG bleibt gültig und gehört zu den `NEEDS-FOUNDER-VERIFY`-Markern (CLAUDE.md: „Gerät-Verify wartet auf Gurt-Eintreffen"). Gestrichen ist nur ihre BEGRÜNDUNG: die Listing-Zeile „Polar, Wahoo, Garmin" steht nicht mehr in `fastlane/metadata/`. |
| **„352 geräte-unverifizierte Commits"** | Eine Zahl vom 2026-07-16 — ein Datum, keine Tatsache. Ersatzlos gestrichen statt fortgeschrieben (dieselbe Regel wie in `.claude/rules/context.md` §2). |
| **Sheet-Chain: „12×.sheet + 2×.fullScreenCover auf 4360 Zeilen"** | Die Datei hat heute 11 749 Zeilen; die verbindliche Zahl der Kette steht an genau einer Stelle, im Präsentations-Absatz von CLAUDE.md. Hier zu wiederholen war #416. Die SACHLICHE Entscheidung bleibt: die Konsolidierung ist geräte-gepaart, nicht blind-autonom. |

### Zweite Runde — gemessen am 2026-09-16 (#1346)

Der Wächter unten sagt seinen eigenen Blindfleck in seinem Kopf: *„Die Nadelliste ist FEST und
nennt fünf Flächen, von denen bekannt ist, dass sie weg sind. Eine veraltete Bitte über
irgendeine SECHSTE gelöschte Fläche geht ungesehen durch."* **Genau das ist eingetreten** — vier
Founder-Löschungen später (#1069, #1301, #1302, #1305) bat diese Datei wieder um Dinge, die
niemand mehr tun kann, und diesmal war eines davon der **als Blocker bezeichnete erste Abschnitt**.

| Gestrichener/reparierter Posten | wo die Messung steht |
|---|---|
| **§1 „Der eine Handgriff"** — Mix-Panel → „Choose input…" → Live monitoring, plus V0/V1a/V1b und „Harmonizer und Granular auf die STIMME" | GESTRICHEN. Tabelle in §1 oben (#1302, #1305) |
| **§4b „aus dem Vollbild-Visual"** | REPARIERT, nicht gestrichen — die Aufnahme bleibt ausführbar, nur über die `.fullscreen`-Größe des schwebenden Fensters (#1069). Messung in §4b |
| **§6 Auftrag neben der beantworteten Frage** | ZURÜCKGENOMMEN vom Founder selbst; die ANTWORT bleibt. Messung in §6 |
| **`Audio/AudioConfiguration.swift:343`** (die einzige dieser Runde, die im WERKZEUG stand, nicht hier) | Trägt jetzt `BLOCKED-BY-#1302` und verlässt damit die offene Warteschlange, ohne gelöscht zu werden. Grund: `upgradeToPlayAndRecord()` hat seit #1302 **null** Produktions-Aufrufer, also wird `.playAndRecord` nie betreten und `recordOptions` nie angewandt |

⭐ **Die Lehre ist NICHT „Nadelliste pflegen" — die altert wieder.** Sie ist: **eine Löschung
durch den Founder ist ein Ereignis mit mehreren Zuhausen** (#456), und der Geräte-Zettel ist das
Zuhause, an das beim Löschen niemand denkt, weil er nicht kompiliert und in keinem `paths:`-Filter
steht. Wer das nächste Mal eine Fläche entfernt, greppt diese Datei UND
`python3 scripts/founder-verify.py` nach ihrem Namen, im selben Commit.

**Wächter:** `Tests/CISmoke/TheDeviceChecklistOnlyAsksWhatExistsTests.swift`. Er prüft nur die
Ankreuz-Zeilen (`- [ ]`), nie die Prosa — ein negativer Scan über die ganze Datei träfe genau
diese ⛔-Tabelle, die die gestrichenen Namen absichtlich zitiert (#491). Und er verbietet die
Rückkehr keiner dieser Flächen (#364): kommt eine zurück, wird er rot und nennt diese Tabelle
als die Prosa, die dann im selben Commit mitzuziehen ist.
