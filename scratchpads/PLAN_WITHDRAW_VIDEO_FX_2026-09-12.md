# PLAN — Dritte Rücknahme: Pläne, Video-Capture, Autotune/Harmonizer/Granular (Founder 2026-09-12)

> „Der ganze Plan mit shimmer reverb und face Input soll weg. Kein Video Capture . Kein
> audioninout kein Autotune, Harmonizer, granularsynthese. Das hat leider nichtbgeklappt.
> Komplett aufräumen"

**Dritte Löschanweisung desselben Tages und die WEITESTE.** Die erste nahm das Gesicht
(#1301), die zweite den Audio-Eingang (#1302–#1302c). Diese nimmt zusätzlich:

1. **die PLÄNE** zu Shimmer-Reverb / Face-Input / Stimme / Audio-Eingang,
2. **Video-Capture** (Aufnahme + Bibliothek + mp4-Export) — die rPPG-PULSQUELLE bleibt,
3. **Autotune · Harmonizer · Granularsynthese** — diesmal AUCH auf dem Musik-Bus, nicht nur
   ihre Mikrofon-Hälften.

**Punkt 3 ist die Ausweitung, die man übersehen kann.** `PLAN_REMOVE_FACE_AUDIOINPUT_2026-09-12.md`
hielt `DSP/EchoelGranular.swift` ausdrücklich als BLEIBT fest, mit korrekter Begründung
(seine einzige Konstruktionsstelle ist die FX-Kette auf dem Synth-Bus, nicht die Stimme).
Diese Anweisung nennt „granularsynthese" ohne Einschränkung und nach dem Satz „Das hat
leider nichtbgeklappt" — also geht auch die Musik-Bus-Hälfte. Die alte Zeile ist damit
überholt, nicht falsch gewesen.

---

## ⛔ WAS TROTZ ÄHNLICHEM NAMEN BLEIBT — gemessen, nicht vermutet

| Sache | Warum sie BLEIBT |
|---|---|
| `Video/CameraCapture` · `CameraAnalyzer` · `RPPGConditioning` · `PulsePeriodEstimator` | Das ist die **rPPG-Pulsquelle** (Finger auf der Rücklinse), die Flaggschiff-Bio-Quelle — sie liegt nur im selben Verzeichnis wie der Videorekorder. „Kein Video Capture" meint die AUFNAHME, nicht die Messung. Wer nach Verzeichnis löscht, löscht das Instrument. |
| `Core/MusicalKey` · `Sequencer/MicrotonalTuning` · `Core/DiatonicHarmony`-Nachbarn der Tonart | Tonart, Skala und Kammerton sind die KOMPOSITIONS-Theorie. Sie sind nicht der Harmonizer-EFFEKT; der Generator braucht sie auf jedem Ton. |
| `PolySynthVoice` · `SubBassVoice` · `MetronomeVoice` · `SamplerVoice` | „Voice" = SYNTH-Stimme. Ein Namens-Grep auf „Voice" trifft sie alle. |
| `RetroCapture` · `SingleExport` | Schneiden den EIGENEN Ausgang mit (Audio), nie eine Kamera. |
| `DSP/VoiceTimbreProfiler` + `SynthPatch.voiceProfile*` | #1293/#1302: der NAME sagt „Voice", die SACHE ist der Synth-Patch. Ein von einem älteren Build gespeicherter Patch trägt sie und wendet sie an (#95/#527). |

---

## GRABSTEIN — gelöschte Plan-Dokumente (Scheibe 1)

Gelöscht, weil ihr GEGENSTAND eine zurückgenommene Fähigkeit ist. Wiederherstellbar aus der
Historie; **nicht daraus weiterbauen.** Dieselbe Einordnung wie bei den Wächtern in #1301/#1302:
ein Dokument geht, wenn es die Fähigkeit BEAUFTRAGT, und bleibt, wenn es sie nur erwähnt.

`PLAN_FIELD_FACE_VOICE_2026-09-12.md` (der Shimmer-Reverb-/Face-Plan, den der Founder
namentlich nennt) · `PLAN_KAMERA_EINGANG_2026-09-11.md` · `PLAN_AUDIO_INPUT_2026-09-11.md` ·
`PLAN_LIVE_MONITORING_VOICE_2026-08-19.md` · `PLAN_VOCAL_CHAIN_2026-08-20.md` ·
`PLAN_VOCAL_CHAIN_V1.md` · `PLAN_VOICE_LIVE_2026-07-12.md` · `PLAN_VOICE_STAGE_2026-08-14.md` ·
`RESEARCH_BODYVIBE_CAMERA_2026-07-17.md` · `RESEARCH_MULTI_INTERFACE_2026-07-10.md`

**ZWEI sind bewusst GEBLIEBEN, und der Grund ist beide Male ein lebender Zeiger:**

- `PLAN_ECHOEL_VOICE.md` — **vier Produktions-/Wächter-Dateien zeigen darauf**
  (`EchoelDDSP.swift:2692`, `VoiceTimbreProfiler.swift:4`, `PolySynthVoice.swift:681`,
  `TheVoiceProfileIsMeasuredNotRecordedTests`, `TheVoiceProfileSurvivesThePatchDrainTests`).
  Sie beschreiben die PATCH-Hälfte der Stimmfarbe, die #1302 ausdrücklich behalten hat.
  Ein Zeiger ist nur so haltbar wie das, worauf er zeigt — löschen hieße, fünf lebende
  Begründungen ins Leere zeigen zu lassen.
- `PLAN_REMOVE_FACE_AUDIOINPUT_2026-09-12.md` — das ist der BERICHT über die Entfernung,
  nicht ein Auftrag zum Bauen. Er trägt die Messungen, an denen #1301/#1302 hängen.

⚠️ **Die Video-Pläne sind NICHT in dieser Scheibe** (`PLAN_VIDEO_PAGE.md`, `PLAN_VIDEO_AUDIO.md`,
`PLAN_VIDEO_IMPORT_CAPTURE_2026-07-15.md`, `RESEARCH_VIDEO_FRONTIER_2026-07-12.md`,
`PLAN_ARRANGEMENT_VIDEO_ONE_VIEW.md`). Sie gehen mit der Video-Scheibe, weil `CLAUDE.md`
und `decisions.csv` auf `PLAN_VIDEO_PAGE.md` zeigen und diese Prosa ohnehin in derselben
Scheibe umgeschrieben wird — ein Zeiger, der einen Commit lang ins Leere zeigt, ist genau
der Defekt, den die Zeile darüber benennt.

---

## SCHEIBEN

| # | Inhalt | Stand |
|---|---|---|
| 1 | Plan-Dokumente (oben) | DIESE |
| 2 | Video-Capture: `VisualRecorder` · `VideoRecorder` · `VideoMuxer` · `VideoMuxAlignment` · REC-Taste · `videoPanel`/`VideoLibraryPanelContent` · Wächter · Store-/Website-Zeilen · die fünf Video-Pläne | **FERTIG `122724d` (#1304)** |
| 3 | Autotune/Harmonizer/Granular: `EchoelHarmonizer` · `EchoelGranular` · `DiatonicHarmony` · `DiatonicHarmonyFollower` (mit `KeyHarmony`) · `HarmonyInterval` · ihre Stufen in `EchoelFXChain`/`FXPreset`/`GenreFX`/`FXCuratedLibrary`/`EchoelFXView` · Wächter · Store-Zeile „Harmonizer effect" | **FERTIG (#1305)** |

**NACHTRAG zur Scheibe-3-Zeile, weil zwei Namen darin nicht stimmten:** `GenrePatches` trägt
gar keine Harmonizer-/Granular-Stufe (der Treffer war das Wort „granularity"), und **Autotune war
schon mit #1302 weg** — `VoicePitchCorrector` ging mit dem Audio-Eingang. Was #1305 zusätzlich
finden musste und in keinem Plan stand: `FXCharacter.harmonizer` (ein PERSISTIERTER
`rawValue` — decode-sicher, weil beide Leser über eine failable Init mit Rückfall gehen), die
zwei Kuratier-Presets „Octave Lead"/„Fifth Stack" (ganz auf dem Harmonizer gebaut), der
Panel-Untertitel „Follow the key", und **eine Zähl-Nadel bei 15, die 13 hätte sein müssen**
(`ANonFiniteControlCannotReachTheRenderTests`). ⭐ **Die Nadel fand `moved-needles.py`, NICHT
`count-pins.py`** — das hatte sie geparst, konnte ihren Empfänger aber nicht auf einen Pfad
auflösen und ließ sie darum aus dem Verdikt fallen. Steht als Regel jetzt in
`Tests/CISmoke/CLAUDE.md` §4.

⛔ **DER SWEEP HATTE EINE LÜCKE UND SIE KOSTETE EINEN CI-UMLAUF (#1305b).** Compile Check
#2601 meldete vier Fehlerzeilen, per #689 auf EINE Ursache zurückgeführt: drei Aufrufstellen von
`rebaselineFollowerFromVM()` in `EchoelFXView` (die vierte, „unable to type-check", ist deren
Kaskade). **Der Spielplan sweept die deklarierten Symbole der GELÖSCHTEN DATEIEN — diese Methode
stand in einer BEARBEITETEN Datei und wurde mit ihrem Umfeld entfernt, ihre drei Aufrufer aber
nicht.** Die Sache ist dieselbe Klasse („ein Dateiname ist kein Geltungsbereich"), nur eine Stufe
kleiner: nicht die Datei verschwindet, sondern eine Deklaration IN ihr.

⭐ **ERWEITERTE FORM, hier als Rezept, weil sie billig ist und dieser Commit sie gefahren hat:**
die ENTFERNTEN Deklarationszeilen aus dem Diff über `Sources` und `Tests` ziehen
(`git diff <basis> -- Sources Tests | grep '^-' | grep -oE '(func|var|let|case|struct|enum|class) +[A-Za-z_][A-Za-z0-9_]*'`),
auf unterscheidbare Namen filtern und fragen, welche davon im kommentar- und stringbereinigten
Rest-Baum noch REFERENZIERT, aber nicht mehr DEKLARIERT sind. Nachgefahren: 307 unterscheidbare
Namen, 3 Treffer, alle drei belegbar falsch (`pitchSemitones` und `selection` sind
Argument-Labels, `videoSettings` eine `AVCaptureVideoDataOutput`-Eigenschaft). Der echte Treffer
war nach der Reparatur weg — der Sweep wurde also gegen ein bekanntes Positiv validiert.

**`Sequencer/MicrotonalTuning` BLEIBT** und ist der Fall, der beim nächsten „Autotune raus"
wieder auftaucht: sein Dateikopf nennt sich selbst das Autotune-ZIEL, aber es ist das Tonsystem
JEDER gestimmten Stimme (`EveryPitchedVoiceFollowsTheToneSystemTests`). **Ein Name im Dateikopf
ist keine Zugehörigkeit.**

**Vor jedem `git rm` gilt der #1302-Spielplan:** die DEKLARIERTEN SYMBOLE der Opfer-Dateien
(alle Deklarationsformen, nicht nur Typen) gegen einen kommentar- und stringbereinigten
Rest-Baum greppen — **ein Dateiname ist kein Geltungsbereich.** Genau das hat `VoiceHarmony`
und `openAppSettings` gefangen; `logEngineLifecycle` musste der Compiler fangen, weil der
Schnitt dort von PROSA statt von einer Deklaration begrenzt war.
