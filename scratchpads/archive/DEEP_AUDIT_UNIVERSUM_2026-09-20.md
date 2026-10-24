# DEEP AUDIT — Das gesamte Echoelmusic-Universum unter EINEM Hut

**Datum:** 2026-09-20 · **Zweig:** `claude/echoelmusic-review-optimize-u5jjpd`
**Auftrag (Founder, wörtlich):** *„Mache die Deep Audith des gesamten Echoelmusic Universums
und bringe alles unter einen Hut. Ultramarketing ultraechoelartistmode, Ultrascave,
uktraccesible, Ultralonggevity, ultrasoultuning, ultraseelespeichern"*

Jede Zahl unten steht neben dem Befehl, der sie erzeugt (§2 von `.claude/rules/context.md`).
Keine Zahl ist abgeschrieben. Wo eine Messung eine Prosa-Zeile widerlegt, steht das dabei.

---

## 0. DER HUT — ein Satz, eine Messung

> **Echoel speichert den Körper bereits, und Echoel speichert die Musik bereits — in zwei
> Dateien, die nichts voneinander wissen. Alle sieben „Ultra"-Dimensionen hängen an genau
> dieser einen fehlenden Brücke.**

Der Beleg ist eine leere Schnittmenge:

```bash
grep -n "static let all" Sources/Echoelmusic/Core/ModulationEngine.swift
#   357:    public static let all: [String] = [tempo]          → 1 Bio-Ziel

python3 - <<'PY'
import re
keys = re.findall(r'keyPath:\s*"([^"]+)"',
    open('Sources/Echoelmusic/Core/EchoelParameterRegistry.swift', encoding='utf-8').read())
print(len(keys), keys[:3])                                     # 15 Deskriptoren, alle "ddsp.*"
PY
```

**Bio-Seite:** genau EIN modulierbares Ziel (`tempo`).
**Parameter-Seite:** 15 registrierte Parameter, davon **11** mit lebendem Setter
(`PolySynthVoice.automatableBases`, gebunden in `EchoelmusicApp.swift:1288`).
**Schnittmenge: LEER.** `tempo` steht in keinem Deskriptor, kein `ddsp.*`-Schlüssel steht in
`ModDestinationKey.all`.

⭐ **Und die vier NICHT automatisierbaren Deskriptoren sind der Beweis, dass die Brücke schon
halb gedacht ist.** Der Kommentar an der Bindestelle sagt warum:

```bash
sed -n '1286,1289p' Sources/Echoelmusic/EchoelmusicApp.swift
#   // Anything bound into `parameterRouter` becomes automatable by name.
#   // Bio-contested params are excluded in bindAutomatable
#   // (they need automation×bio composition).
```

Die vier Ausgeschlossenen sind `ddsp.filter.cutoff`, `ddsp.osc.frequency`, `ddsp.fx.reverbMix`,
`ddsp.fx.reverbDecay` — **genau die, die der Körper heute schon anfasst** (Kohärenz →
Cutoff/Brightness/Harmonicity/Noise, `AlwaysOnBioChannel`). Jemand hat also bereits
aufgeschrieben, welche Parameter bio-umkämpft sind; was fehlt, ist der Mechanismus, der aus
„umkämpft" eine komponierte Route macht statt eines Ausschlusses.

⚠️ Zwei davon haben allerdings ÜBERHAUPT keinen Verbraucher: `ddsp.fx.reverbMix` und
`ddsp.fx.reverbDecay` kommen in `Sources/` nur in der Registry vor
(`git grep -c "fx.reverbMix" -- Sources` → eine Datei). Das ist die #546-Lage — die
Convolution-Stufe ist zur Laufzeit aus. Sie gehören in eine B1-Scheibe **nicht** hinein.

Das ist zugleich die Messung hinter dem DMMW-Wunsch vom 2026-09-19
(*„alle möglichen Parameter können moduliert werden von Biofeedback"*). Der Wunsch ist keine
Neuentwicklung — er ist **eine Projektion**: `ModDestinationKey.all` aus der Registry ableiten,
statt sie von Hand zu pflegen. Dann macht jeder neue `ParameterDescriptor` automatisch ein
neues Bio-Ziel auf. 1 → 15 in einer Scheibe, ohne eine einzige neue Fläche.

---

## 1. ULTRAMARKETING — die am besten regierte Fläche des Repos

**Gemessen.**

| Fläche | Messung | Befehl |
|---|---|---|
| Wahrheits-Register | 13 ⛔-Abschnitte | `grep -cE '^### [0-9]' ContentPipeline/CLAIMS.md` |
| Website | 22 HTML-Seiten | `ls docs/*.html \| wc -l` |
| App-Store-Text | 8 Metadaten-Dateien | `ls fastlane/metadata/en-US/` |
| Content-Pipeline | Assets · Automation · Prompts · Published · Scripts | `ls ContentPipeline/` |

**Stärke:** `CLAIMS.md` ist die beste Erfindung dieses Repos. Sie existiert, weil #158/#192
zwei ganze Zyklen brauchten, um EINE falsche Behauptung (AUv3) von der Website zu nehmen, und
#184 zwölf aus dem App-Store-Text — wo eine falsche Behauptung eine 2.3-Ablehnung ist.

**⚠️ DIE SCHÄRFSTE SPANNUNG DES GANZEN AUFTRAGS steht in dieser Datei, §2:**

> *„### 2. Wellness, Meditation, Schlaf, Fokus, Stressabbau, **Longevity**, „HealthTech""*

Das Wort **„Longevity" ist als nutzersichtbare Behauptung VERBOTEN** — wörtlich, seit langem,
aus einem harten Grund (Heilungs-Claims sind Alt-Last aus dem Vorgängerprojekt und eine
permanente rote Linie; die App sagt selbst „für Selbstbeobachtung, nicht für medizinische
Diagnose"). Dasselbe gilt sinngemäß für „Seele" und „Soul" (esoterische Terminologie,
`CLAUDE.md` BRAND).

**Das ist KEIN Einwand gegen den Auftrag.** Der Founder benutzt die Wörter als INTERNE
Arbeitsnamen für echte, legitime Sachen (Haltbarkeit des Codes; Identität des Performers).
Die Entscheidung, die ich treffe (delegiert: *„Wie du die App beschreibst … die triffst du"*):

| Interner Arbeitsname | Bleibt intern | Nutzersichtbar heißt es |
|---|---|---|
| Ultralonggevity | ja | **Haltbarkeit** — „null Abhängigkeiten, 541 Wächter". Nie Lebensdauer/Gesundheit. |
| Ultrasoultuning | ja | **Dein Ton** / *tone system* — `TuningSystem`, Kammerton, es ist ein Tonsystem, kein Seelenzustand |
| Ultraseelespeichern | ja | **Signature** — was deine Sessions über deinen Körper und deine Musik wissen |

**Offener Posten (#28, unverändert):** `docs/claims.html` — die ⛔-Hälfte von `CLAIMS.md` ist
nicht öffentlich. Ein Repo, das seine eigenen Nicht-Behauptungen veröffentlicht, ist
Marketing-Material ersten Ranges und kostet keine einzige Behauptung.

---

## 2. ULTRAECHOELARTISTMODE — die Fläche existiert, die IDENTITÄT reist nicht mit

**Gemessen.**

```bash
grep -cE "private var \w*Panel\w*: some View" Sources/Echoelmusic/Studio/EchoelStudioView.swift   # 9 Panels
python3 -c "…offered…"                                                                            # 41 angebotene Genres
ls docs/artist.html                                                                                # existiert (Projekte, Venues, Solo)
```

Das Instrument ist da: 9 Panels, 41 kuratierte Genres, ein Patch-Editor hinter dem Sound-Chip,
Flow/Loop, Export (MIDI + Audio), AUv3 in einem fremden Host gerätebestätigt (#1386, AUM).

**Die Lücke ist nicht die Fläche — es ist, dass der KÜNSTLER im Projekt nur als String vorkommt.**

```bash
grep -nE "^\s+public var (artist|a4Hz|toneSystemID)" Sources/Echoelmusic/Core/Project.swift
#   102: artist: String          ← ein Name, gestempelt in den Session-Titel
#    97: a4Hz: Double            ← Kammerton
#   129: toneSystemID: String?   ← Tonsystem-Referenz
```

`Project` trägt **kein einziges Bio-Feld**. Ein gespeichertes Projekt weiß, in welcher Tonart
und mit welchem Kammerton es entstand — aber nicht, mit welchem Körper.

---

## 3. ULTRASCAPE (gelesen als „Ultrascave") — die STEUER-Hälfte lebt, die RENDER-Hälfte nicht

**Gemessen — alle vier Sender werden beim App-Start konstruiert, das ist echt und auf der Leitung:**

```bash
git grep -n "ADMOSCSender(\|ArtNetSender(\|SACNSender(\|SpatialSceneStore(\|OSCReceiver(" -- Sources | grep -v "/\1"
#   EchoelmusicApp.swift:105  ADMOSCSender()      → /adm/obj/{n}/*
#   EchoelmusicApp.swift:108  ArtNetSender()      → DMX
#   EchoelmusicApp.swift:109  SACNSender()        → E1.31
#   EchoelmusicApp.swift:112  OSCReceiver()       → Steuereingang (#1255)
#   EchoelmusicApp.swift:143  SpatialSceneStore()
```

**Nicht verdrahtet (sieben Kerne, Register in `CLAUDE.md`):** `VBAPPanner`,
`AmbisonicsEncode`, `LightFixtureGroup`, `BioPhaser`, `BinauralPanner`, `EchoelSpaceReverb`,
`SpatialAutomationMapping`.

**`ImmersiveStageView` hat NULL Konstruktionsstellen** (`git grep -n "ImmersiveStageView(" --
Sources` → nur die eigene Datei) — türlos, und das ist **absichtlich**: Ship-Gate 4 sagt
„Licht/Raum demonstrierbar, nicht erforderlich für v1".

**Urteil:** Ultrascape ist die Dimension mit dem besten Verhältnis von *fertig* zu *sichtbar*.
Echoel spricht heute ADM-OSC, Art-Net und sACN — drei offene Standards, null SDK-Bindung. Das
ist die Roman/Adamson-FletcherMachine-Geschichte aus `memory/people.md`, und sie ist WAHR.
Was fehlt, ist eine Tür, nicht eine Fähigkeit.

---

## 4. ULTRAACCESSIBLE — breiter als erwartet, mit zwei echten Löchern

**Gemessen.**

| | Dateien | Befehl |
|---|---|---|
| `.accessibility*`-Modifier | 44 | `git grep -l "\.accessibility" -- Sources \| wc -l` |
| VoiceOver-Bezug | 35 | `git grep -ln "VoiceOver\|isVoiceOverRunning" -- Sources \| wc -l` |
| Reduce Motion | 19 | `git grep -ln "reduceMotion" -- Sources \| wc -l` |
| **Dynamic Type** | **8** | `git grep -ln "dynamicTypeSize" -- Sources \| wc -l` |

Dazu: `docs/accessibility.html` existiert (mit einem ehrlichen Abschnitt *„Accessibility
Profiles (planned)"*), die 3-Hz-Blitzgrenze ist Gesetz und getestet, `EchoelValueField` ist
eine Zahl statt eines Drehknopfs — das ist von Haus aus zugänglicher als jede DAW-Oberfläche.

**Zwei Löcher, beide gemessen:**
1. **Dynamic Type: 8 von 356 Dateien.** VoiceOver ist gut abgedeckt, Schriftgrößen nicht.
2. **#292-Rückstand: 5 von 9 Panels reflowen.** `menuPanelHost`, `bioPanel`,
   `tempoToolsPanel`, `effectsPanel` stapeln starr — und `#1375` hat gemessen, dass der
   Rückstand **NULL Scheiben plus einen Grund** ist: die einzige Fläche mit umbruchfähigem
   Inhalt (`tempoToolsPanel`) hat zwei Zahlenfelder, die *nicht benachbart* sind.

**Urteil:** Accessibility ist keine Baustelle, sie ist ein Alleinstellungsmerkmal. Das
Plattform-Ziel des Founders (*„das gesamte Apple Ökosystem … auch VR/XR und Wearables"*) macht
Dynamic Type zur Pflicht, nicht zur Kür — eine Vision-Pro-Fläche ohne Schriftskalierung ist
keine.

---

## 5. ULTRALONGEVITY (intern: HALTBARKEIT) — stark, mit EINER gemessenen Bedrohung

**Was Haltbarkeit hier bedeutet und warum sie echt ist:**

```bash
grep -n "dependencies" Package.swift        # 66-67:  dependencies: []   ← NULL externe Deps
git ls-files 'Sources/**/*.swift'  | wc -l  # 356 Quelldateien
git ls-files 'Tests/CISmoke/*.swift' | wc -l # 541 blockierende Wächter
git ls-files 'Tests/EchoelmusicTests/*.swift' | wc -l # 302 nicht-blockierende Tests
```

**1,52 Wächter pro Quelldatei.** Null Abhängigkeiten heißt: kein Lieferant kann diese App
abkündigen. Das ist die belastbarste Zahl im ganzen Repo und sie ist Marketing-fähig —
solange sie **Haltbarkeit** heißt und nicht „Longevity".

**⛔ DIE BEDROHUNG, gemessen:**

```bash
wc -c < CLAUDE.md      # 149676   —  Decke: 150000  (TheLawFileStaysUnderItsCeilingTests)
```

**324 Byte Kopfraum. 0,2 %.** Das Gesetz-Dokument, das jede Sitzung ZUERST liest, ist 99,8 %
voll. Der nächste echte Register-Eintrag reißt einen blockierenden Wächter — und die
Reparatur ist bereits vorgeschrieben (`#538`: PROVENIENZ in `memory/LEDGER_COUNTS.md`, GESETZ
in `CLAUDE.md`), aber sie muss jemand ausführen. **Das ist der einzige Posten dieses Audits,
der ein Ablaufdatum hat.**

Zweite, bereits berichtete und founder-gated: `auto-merge-claude.yml` wartet auf kein Gate
(`grep -n "needs:\|workflow_run\|conclusion" .github/workflows/auto-merge-claude.yml` → nichts).

---

## 6. ULTRASOULTUNING (intern) / „DEIN TON" (nutzersichtbar) — REAL, und der ehrlichste Name dafür

**Der Kern existiert und ist verdrahtet.** ⚠️ Messmethodik-Warnung, die ich mir selbst gestellt
habe: eine Suche nach dem DATEINAMEN liefert einen einzigen Treffer und sieht nach einem toten
Kern aus — die Datei heißt `MicrotonalTuning.swift`, der Typ heißt `TuningSystem`. Genau die
#1376-Falle. **Nach dem TYP messen:**

```bash
grep -nE "^(public )?(struct|enum) " Sources/Echoelmusic/Sequencer/MicrotonalTuning.swift
#   27: public struct TuningSystem: Codable, Sendable, Equatable, Identifiable, Hashable

git grep -l "\bTuningSystem\b" -- Sources | grep -v MicrotonalTuning.swift
#   Core/Project.swift · Sequencer/LaneVoiceRack.swift · Sequencer/MusicStyle.swift
#   Sequencer/MusicalKey.swift · Studio/EchoelStudioView.swift · Studio/WorkspaceView.swift
#   Tools/SubBassVoice.swift                                            → SIEBEN Verbraucher
```

Dazu `Sequencer/AutoAttune.swift` (`public enum AutoAttune`) und `Project.a4Hz` (Kammerton)
plus `Project.toneSystemID`.

**Das IST „soul tuning", ohne ein esoterisches Wort:** ein Performer kann sein eigenes
Tonsystem und seinen eigenen Kammerton definieren, und beides reist mit dem Projekt. Das ist
wissenschaftlich sauber (Stimmungssysteme sind Musiktheorie, nicht Metaphysik), es ist
gebaut, und es ist das einzige Feature dieser Liste, das ein Konkurrent nicht in einer Woche
nachbaut.

**Lücke:** ein Tonsystem pro Projekt. 41 Genres, kein genre- oder körperabhängiges Tonsystem.

---

## 7. ULTRASEELESPEICHERN (intern) / „SIGNATURE" — **SCHON GEBAUT, SCHON PERSISTENT, TÜR ZU**

**Das ist der Befund, für den sich dieses Audit gelohnt hat.**

```bash
sed -n '21,33p' Sources/Echoelmusic/Core/SessionRecorder.swift
#   public struct BioSessionSummary: Codable, Sendable, Identifiable, Equatable {
#       id · date · durationSeconds · avgHeartRate · avgHRV
#       avgCoherence · peakCoherence · sampleCount · name
```

Der Dateikopf sagt es selbst: *„Summaries persist across launches as Codable JSON in
UserDefaults."* Dazu `SessionStats.streakDays(_:)` und `SessionStats.coherenceTrend(_:window:)`
— **Übungsserie und Kohärenz-Verlauf über Sessions hinweg, fertig und unit-getestet**
(`Tests/EchoelmusicTests/SessionRecorderTests.swift`, 6 Ansprüche allein auf `streakDays`).

Der Recorder läuft: `git grep -n "SessionRecorder(" -- Sources` → `EchoelmusicApp.swift:218`.

**Und jetzt die Messung, die alles entscheidet:**

```bash
git grep -n "BioSessionSummary\|sessionRecorder\.\|SessionStats" -- Sources | grep -v SessionRecorder.swift
#   Studio/MeditationView.swift:35   @State private var lastSummary: BioSessionSummary?
#   Studio/MeditationView.swift:150  SessionStats.streakDays(recorder.sessions)
#   Studio/MeditationView.swift:181  SessionStats.streakDays(recorder.sessions)
#   → EIN EINZIGER Leser, in EINER EINZIGEN Datei
```

**⚠️ Und hier hätte ich mich fast selbst getäuscht — die erste Fassung dieses Absatzes
schrieb „null Konstruktionsstellen". Falsch. Die Ansicht WIRD konstruiert:**

```bash
git grep -n "MeditationView(" -- Sources | grep -v "/MeditationView.swift:"
#   Studio/EchoelStudioView.swift:1681
#       .fullScreenCover(isPresented: $showMeditation) { MeditationView() }

git grep -n "showMeditation" -- Sources | grep -E "= true|toggle\(\)"
#   (nichts)
```

**`showMeditation` hat NULL Setzer** — der Quelltext daneben sagt es dreimal selbst
(`EchoelStudioView.swift:1592` *„no setter anywhere"*, `:834`, `:5288` *„the un-settable
pair"*). Die Flagge kann nie `true` werden, der Cover kann nie aufgehen. Das ist genau die
Kategorie, die `CLAUDE.md` als **setterlosen Slot** führt — Fläche gebaut, Fähigkeit
erreichbar, Tür fehlt. Dazu die getrennte Founder-Notiz in `CLAUDE.md`: *„MeditationView
bleibt bewusst türlos (Founder: Teil des Produktionsflusses, keine eigene Tür gewollt)."*

**Also:** Echoel zeichnet den Körper des Performers auf, mittelt ihn, speichert ihn dauerhaft,
rechnet Übungsserie und Kohärenz-Verlauf — und der einzige Ort, an dem das je sichtbar würde,
hängt an einer Flagge, die niemand setzen kann. Nicht kaputt: **unbetürt**, und zwar in einem
Rahmen (*Meditation*), den der Founder damals nicht wollte.

**Der Founder fragt heute nach genau dieser Fähigkeit in einem ANDEREN Rahmen:** nicht als
Wellness-Verlauf, sondern als **Performer-Identität**. Derselbe Code, andere Bedeutung, andere
Tür. Das ist keine Neuentwicklung und keine Rücknahme seiner Entscheidung — es ist ein
Umzug.

**Zweite Lücke, gemessen:** `Project` trägt keine Bio-Felder (§2 oben). Der gespeicherte Körper
(`BioSessionSummary` in `UserDefaults`) und die gespeicherte Musik (`Project` als JSON) haben
**kein gemeinsames Feld**, nicht einmal die `id`. Eine Session weiß nicht, welches Stück dabei
entstand; ein Stück weiß nicht, welcher Zustand es hervorgebracht hat.

---

## 8. WAS DAS ZUSAMMEN ERGIBT — drei Brücken, nicht sieben Projekte

Alle sieben Dimensionen laufen auf **drei fehlende Verbindungen** zwischen Dingen, die bereits
gebaut sind. Keine davon ist eine neue Fläche, keine davon bricht eine Founder-Entscheidung.

| # | Brücke | Von | Nach | Kostet | Öffnet |
|---|---|---|---|---|---|
| **B1** | **Universal Modulation** | `EchoelParameterRegistry` (15) | `ModDestinationKey.all` (1) | 1 Scheibe: `all` als Projektion der Registry | Ultrasoultuning · Artistmode · der ganze DMMW-Wunsch |
| **B2** | **Signature** | `BioSessionSummary` (persistent) | `Project` (persistent) | 1 Feld je Seite + eine Tür | Ultraseelespeichern · Longevity(Haltbarkeit) · Marketing |
| **B3** | **Stage** | Steuer-Hälfte (live auf der Leitung) | `ImmersiveStageView` (türlos) | 1 Tür, Founder-Entscheidung | Ultrascape · Accessible(externer Screen) |

**B1 ist die Wurzel.** Solange `ModDestinationKey.all == [tempo]`, ist jede Aussage über
„der Körper steuert X" für X ≠ Tempo eine Über-Behauptung — und `CLAUDE.md` hat genau diese
Über-Behauptung schon zweimal zurücknehmen müssen (#496 am FX-Panel, #541 an der Matrix-Zeile).
B1 macht sie in einer Scheibe wahr statt sie ein drittes Mal zurückzunehmen.

---

## 9. WAS ICH ENTSCHIEDEN HABE (delegiert) — und die EINE Frage, die dem Founder gehört

**Entschieden (Marken- und Sprachebene, ausdrücklich delegiert):**
1. „Longevity", „Soul" und „Seele" bleiben **interne Arbeitsnamen**. Nutzersichtbar:
   **Haltbarkeit · Dein Ton · Signature**. `CLAIMS.md` §2 bleibt unverändert in Kraft.
2. Der Programmname für den DMMW-Wunsch ist **Universal Modulation**, nicht „DMMW" —
   `docs/dev/DMMW_ARCHITECTURE.md:34` definiert DMMW als *Arrangement/Clips-Timeline als
   Heimat-Ansicht*, also genau die Workstation-Hälfte, die der Founder am 2026-07-25 selbst
   zurückgenommen hat. Denselben Namen für das Gegenteil zu benutzen, erzeugt genau den
   Flip, den `decisions.csv` Zeile 685 schon einmal protokolliert hat.
3. Reihenfolge: **B1 → B2 → B3.** B1, weil es die Wurzel ist und eine bestehende
   Über-Behauptung wahr macht statt sie zurückzunehmen.

**NICHT entschieden — gehört dem Founder, und es ist genau EINE Frage:**

> **Deine Sessions werden seit langem gespeichert, und niemand kann sie sehen.**
> `BioSessionSummary` liegt als JSON in `UserDefaults` und überlebt jeden Neustart; der
> einzige Leser ist `MeditationView`, und die hängt an einer Flagge ohne Setzer. Du hast
> damals gesagt: *„Teil des Produktionsflusses, keine eigene Tür gewollt"* — und im
> Meditations-Rahmen war das richtig. Die Frage ist, ob **dieselben Daten im
> Performer-Rahmen** eine Fläche bekommen: was Dein Körper in dieser Session getan hat, neben
> dem Stück, das dabei entstand. Kein Wellness-Verlauf, keine Streak-Gamification, kein
> Gesundheits-Frame — eine Signatur.
>
> **Ja** → ich baue B2 (ein Feld je Seite, eine Tür, ein Wächter).
> **Nein** → die Daten bleiben gespeichert und unsichtbar, und B1/B3 laufen trotzdem.

Alles andere in diesem Audit kann ich ohne Rückfrage bauen.

---

## 10. NICHT GEMESSEN — die Grenzen dieses Audits, ehrlich benannt

- **Klang.** Ob die 41 Genres organisch und professionell klingen, entscheidet ein Ohr am
  Gerät. `GenreFamilyDistinctnessTests` pinnt nur, dass keine zwei denselben Fingerabdruck
  teilen. Offen: Posten #34 (vier A/Bs).
- **Gerät.** GarageBand iOS bei 44,1 kHz (die Messung, die den A10-Fix freigibt), Logic Pro,
  und das tatsächliche Spielen von Noten durch den AUv3 — der Gerätelauf vom 2026-09-20 hatte
  nur den Dauerton.
- **Keine Toolchain.** Diese Sitzung hat kein `swift`; alles oben ist statische Messung plus
  Gate-Lesung, nicht Ausführung.

---

*Messbefehle im Fließtext, damit jede Zahl in zehn Sekunden widerlegbar ist. Wer eine
korrigiert, korrigiert sie hier und nicht aus dem Gedächtnis.*
