# Redesign — Profi-Oberfläche, Barrierefreiheit, AUv3 Host und Plugin (2026-10-15)

Auftrag des Founders: „Deep Audit DMMW/GMMW, AUv3 Plugin-Host und Plugin, Redesign nach den
Top-Vorbildern, professioneller, neuer und barrierefreier."

Grundlage: drei nur lesende Prüfungen (AUv3 · Design-System · bestehende Pläne), deren
Kernaussagen hier nachgemessen sind. Geprüft auf HEAD `32fe4f3e0`. Kein Build, kein Gerät.

**Rahmen, an den sich dieser Plan hält:** Produktion führt, Bio ist optional (decisions.csv
2026-10-15); 14 Tage Vereinfachen und Stabilisieren (Kandidat A ist raus als 10.79.505,
Kandidat B offen); keine neue Bühne, kein neuer Modal (Black-Screen-Gesetz, 12 von 14 Slots
belegt); Uncodixfy-Regeln; `EchoelValueField` für jede Zahl. Dieser Plan führt die schon
vorhandenen Redesign-Pläne zusammen (Workstation-Redesign, DAW-Shell, GMMW, Produktionslevel
H1–H6, Edit-Präzision, Hardware live, DMMW-Architektur §5) — er ersetzt keinen.

---

## 1. Befund in fünf Sätzen

1. **Das Fundament ist besser als sein Ruf:** Kontraste bestehen WCAG AA (Text 14,6:1, gedimmter
   Text 6,6:1, Akzent 11,6:1 auf der Fläche), keine Glas-/Blur-Effekte, Radien ≤ 12, 87
   `EchoelValueField` gegen 2 rohe Slider, 249 VoiceOver-Labels auf 236 Knöpfe.
2. **Was „unprofessionell" wirkt, ist Uneinheitlichkeit, nicht Stil:** 424 Abstände als freie
   Zahlen gegen 52 Token-Verwendungen (15 verschiedene Werte), 12 Schriftgrößen, zwei
   Überschrift-Arten (27 System-`Section` neben dem eigenen `groupHeader`), 13 Stellen in
   System-Schrift statt Atkinson Hyperlegible, harte Weiß-/Orange-Werte im Visual-Fenster.
3. **Die Barrierefreiheit hat drei echte Lücken:** zwei Steuerungen unter 44 pt (Quellen-Menü 34,
   Vollbild 36 — der 34-pt-„Hausstandard" für Pillen ist bewusst, #617, aber unter Apples 44),
   Bedienrahmen mit nur 1,16:1 Kontrast (130× `border` gegen 36× `borderStrong`), Dynamic Type an
   Kopf und Umschalter bei `accessibility1` gedeckelt.
4. **Der Plugin-HOST lädt Instrumente und zeigt ihre Oberfläche, aber Effekte klingen nicht**
   (Modell da, kein Aufrufer), kein Tempo/Transport an die Plugins, Noten nicht samplegenau,
   keine Automation von Plugin-Parametern — und nichts davon ist am Gerät geprüft.
5. **Das PLUGIN Echoel lädt in AUM** (gemessen 20.09.), ist aber dünn: einstimmig, 8 Parameter,
   kein Host-Tempo, feste Fenstergröße 400×520, keine Effekt-Variante, Logic/GarageBand ungeprüft.

## 2. Vorbilder — welches Muster wir je übernehmen (und welches nicht)

| Vorbild | Muster, das wir übernehmen | Wo es in Echoel landet | Nicht übernehmen |
|---|---|---|---|
| **Ableton Note / Move** | Ein großes Spielfeld, wenige Knöpfe, alles mit dem Daumen | Instrument-Bühne: Kandidat B (e: 4 Hauptregler + „Mehr", h: 9→6 Chips) | Clip-Raster als neue Bühne |
| **Koala Sampler** | Riesige Pads, ein Tipp = ein Ergebnis, keine Menüs zum Spielen | Fingerziele ≥ 44 pt, live ≥ 60 pt (DMMW §5.3) | Sampler-zentriertes Layout |
| **Logic Pro für iPad** | Plugin-Kacheln je Spur, einheitlicher Inspektor, Sound-Browser mit Vorhören | Device-Seite der Spur: Instrument + Effekt-Kacheln (H6-6) | Logic-Look kopieren |
| **AUM** | Kanalzug = Quelle → Inserts → Sends; jedes Plugin-Fenster aus dem Kanal | Mixer-Bühne: Insert-Zeile je Kanal, Plugin öffnen aus der Kachel | Matrix-Routing auf der Hauptfläche |
| **Loopy Pro** | Frei belegbare MIDI-Steuerung, alles lernbar | HW-7 (MIDI-Ziel je Art), späteres MIDI-Learn | Frei zeichenbare Oberfläche |
| **Drambo** | Ein Modulationssystem für alles | Die vorhandene Modulationsmatrix (Body → Parameter) als EINE Tür | Modular-Rack |
| **Bitwig** | Modulatoren sichtbar am Ziel (kleiner Ring am Regler) | Ein Modulations-Ring an `EchoelValueField` | — |

Diese Namen stehen nur intern; nach außen nie „wie Ableton" (CLAIMS).

## 3. Design-System v2 — sieben Regeln

1. **Rollen statt Größen:** fünf Textrollen auf der vorhandenen Rampe — Meta 11 · Label 12 ·
   Body 13 · Titel 15/18 · Anzeige 28+. 11 pt nur für Meta (Einheiten, Zeitstempel), nie für
   Bedienbeschriftung. Heute 320 Stellen in 11 pt → schrittweise auf Rolle prüfen.
2. **Ein Abstands-Raster (4 pt):** nur `spaceXS…spaceXL`; 6/10/14 werden 4/8/12/16. Ein Wächter
   zählt freie Zahlen und darf nur sinken (Ratchet, #364-gerecht).
3. **Bedienelemente haben sichtbare Kanten:** jeder tippbare Rahmen nimmt `borderStrong`
   (3,7:1, WCAG 1.4.11); `border` bleibt Dekor-Linien.
4. **Fingerziele:** 44 pt überall (statt 34 pt Hausstandard), 60 pt für Live-Steuerung
   (Play, Not-Aus, Szenen). Der 34-pt-Standard wird bewusst abgelöst, Wächter im selben Commit.
5. **Eine Schrift:** Atkinson Hyperlegible auch in den 13 System-Schrift-Stellen.
6. **Dynamic Type bis `accessibility3`** an Kopf und Umschalter; bei mehr bricht der Kopf in zwei
   Zeilen, statt abzuschneiden.
7. **Eine Überschrift-Art:** `groupHeader` überall; die 27 `Section`-Köpfe folgen beim Umbau
   ihrer Fläche, nicht in einem Großumbau.
Unverändert: dunkles Thema (Profi-Audio, Bühne), Akzentgrün nur für Bio-Signal, Radien 4/8/12,
Übergänge 120/180 ms, Blitz ≤ 3 Hz. Neu als Option: ein Kontrast-Modus, der bei „Kontrast
erhöhen" (iOS) automatisch `dim` und `border` anhebt.

## 4. AUv3 — Host und Plugin, Reihenfolge

**Host (Echoel lädt fremde Plugins):**
1. **H6-5 + H6-6 Effekt-Inserts** — Effekt-Plugins auf einer Spur klingen, Kachel auf der
   Device-Seite (Plan liegt: `scratchpads/PLAN_H6_EFFECT_PLUGINS_2026-10-14.md`).
2. **AU-T Tempo und Transport an Plugins** — `musicalContextBlock` + `transportStateBlock`, damit
   Arpeggiatoren, LFOs und Delays im Song-Tempo laufen.
3. **AU-2 samplegenaue Noten** — gekoppelt an T-1 (samplegenauer Sequencer).
4. **AU-P Plugin-Parameter automatisieren** — über `AUParameterTree`, in die vorhandene
   Song-Automation.
Erst nach Gerätesitzung: H1/H2c/H3 sind gebaut, aber nie am Gerät bestätigt.

**Plugin (Echoel in AUM, Logic, GarageBand):**
1. **Drone beim Laden entscheiden** (still bis zur ersten Note?) — Founder-Frage aus §2b.
2. **Host-Tempo lesen** (`musicalContextBlock`) — die Körper-Stimme im Tempo des Hosts.
3. **Mehrstimmig + Velocity + Pitch-Bend + CC** (heute einstimmig, nur Note an/aus).
4. **Größenveränderliche Oberfläche** (`supportedViewConfigurations`).
5. **Effekt-Variante `aufx`** — der Founder hat sie in AUMs Liste gesucht.
6. **Logic und GarageBand am Gerät prüfen** — bis dahin nach außen nur „läuft in AUM".

## 5. Reihenfolge, passend zum 14-Tage-Plan

| Wann | Scheibe | Art |
|---|---|---|
| jetzt (14 Tage) | **D1** Fingerziele: 34-pt-Hausstandard → 44 pt, Quellen-Menü + Vollbild zuerst | Barrierefreiheit, kein neues Element |
| jetzt | **D2** Bedienrahmen auf `borderStrong` | Kontrast |
| jetzt | **D3** 13 System-Schrift-Stellen → Atkinson | Einheitlichkeit |
| jetzt | **Kandidat B** (f · e · d · h) | Vereinfachung, schon geplant |
| nach Gerätesitzung 2 | **D4** Dynamic Type bis `accessibility3` · **D5** Abstands-Ratchet | System |
| danach | **H6-5/H6-6** Effekt-Inserts → **AU-T** → **AU-2/T-1** → **AU-P** | Host |
| parallel, klein | Plugin 1–4 | Plugin |

Nicht in den 14 Tagen: neue Bühnen, neue Modals, ein Großumbau von `EchoelStudioView`
(13.406 Zeilen) — er wird Fläche für Fläche kleiner, wenn eine Fläche ohnehin angefasst wird.

## 6. Widersprüche zwischen den Plänen (aufzuräumen, nur Doku)

- `ECHOELMUSIC_MASTER_PLAN.md` nennt Plugin-Hosting noch „IDEA" — es ist seit E11 Priorität,
  H1–H6-4 sind gebaut.
- `DMMW_DEEP_ARCHITECTURE` §5.2 nennt die fünfte Bühne „Project", seit H18 heißt sie „Piece".
- CLAUDE.md sagt „THE PIECE IS THE HOME" — seit 15.10. öffnet die App auf dem Instrument
  (CLAUDE.md ist eingefroren; Vermerk in `memory/decisions.md`).
- Die 14-Tage-Entscheidung und das Editor-Urteil stehen nur in `memory/decisions.md`, nicht in
  `decisions.csv`.

## 7. Offen am Gerät (keine Rechnung ersetzt das)

Ob die App „professioneller" wirkt, entscheidet dein Auge auf dem iPhone, nicht dieser Bericht.
Messbar am Gerät: VoiceOver-Durchgang einer Bühne, größte Textgröße ohne Abschneiden, ein
fremdes Instrument-Plugin laden und spielen, Echoel in GarageBand.
