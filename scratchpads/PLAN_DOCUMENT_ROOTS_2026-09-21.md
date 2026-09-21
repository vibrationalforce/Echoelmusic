# DMMW-G — Die Dokument-Wurzeln, kartiert (Design, KEIN Code)

**Founder-Reihenfolge, Posten G:** „document-root unification design". Das hier ist die
Karte plus der Entwurf; H (Re-Betürung / neue Mediendomänen) kommt danach, M2 (der
`DMMWProject`-Umschlag samt Importeur) ist der CODE, der aus diesem Dokument folgt.

⚠️ **Alles unten ist GEMESSEN, kommentar-gestrippt, am 2026-09-21 gegen `4587e024b`.** Wo
eine Zahl steht, steht der Befehl daneben. Wo ich eine frühere Behauptung korrigiere, steht
sie mit ⛔ da — die Karte ist nur so viel wert wie ihre Nachprüfbarkeit.

---

## 1. Es sind ZWÖLF persistierte Wurzeln, nicht vier

Das Audit (`AUDIT_DMMW_RECONCILIATION_2026-09-21.md` §9) sagt „Four persisted document
roots overlap". Das ist richtig für die SONG-Wurzeln und **unvollständig als
Bestandsaufnahme**: gemessen sind es zwölf, in zwei Sicherungsarten.

```
git grep -nE '(let|var) (fileName|storageKey|defaultsKey|key)\s*=\s*"' -- Sources
```

| # | Wurzel | Datei / Schlüssel | Sicherung | Klasse |
|---|---|---|---|---|
| 1 | `Project` / `ProjectStore` | `projects.json` | App-Group-Datei | **SONG** |
| 2 | `TimelineDocument` / `TimelineStore` | `timeline` | App-Group-Datei | **SONG** |
| 3 | `Arrangement` / `ArrangementStore` | `song` | App-Group-Datei | **SONG** |
| 4 | `[Clip?]` / `ClipStore` | `clips` | App-Group-Datei | **SONG** |
| 5 | `AutomationState` / `AutomationPlayer` | `automation` | App-Group-Datei | **SONG** |
| 6 | `PatchStore` | `userPatches` | App-Group-Datei | Bibliothek |
| 7 | `FXPresetStore` | `userFXPresets` | App-Group-Datei | Bibliothek |
| 8 | `MoodPresetStore` | `userMoodPresets` | App-Group-Datei | Bibliothek |
| 9 | `ModulationEngine` | `modulationMatrix.v1` | UserDefaults | Einstellung |
| 10 | `SignalRouter` | `signalGraph.routes.v1` | UserDefaults | Einstellung |
| 11 | `TrackFXStore` | (Schlüssel je Bus) | UserDefaults | Einstellung |
| 12 | `SessionRecorder` | `bioSessions.v1` | UserDefaults | Bio-Protokoll |

⭐ **Die Klasse entscheidet, was in den Umschlag gehört, und das ist die eigentliche
Design-Arbeit.** Ein `DMMWProject`, das die Bibliothek und die Einstellungen mit einpackt,
macht aus „Projekt öffnen" ein „App-Zustand ersetzen" — der Nutzer verlöre seine Presets,
weil er ein fremdes Stück geladen hat. **In den Umschlag gehören die fünf SONG-Wurzeln,
sonst nichts.** Bibliothek und Einstellungen bleiben, wo sie sind; das Projekt REFERENZIERT
sie (Patch per Wert, weil er klein und projektbestimmend ist — Presets per ID).

⚠️ **Jede der zwölf wird an genau EINER Stelle konstruiert** (gemessen: `EchoelmusicApp` für
zehn, `EchoelFXView` für #7, `EchoelStudioView` für #8). Es gibt also keine versteckte
zweite Instanz — die Wurzeln sind sauber einmal da. Das ist die gute Nachricht dieser Karte.

---

## 2. Die drei ECHTEN Überlappungen — gemessen, nicht vermutet

### 2.1 ⛔ AUTOMATION HAT ZWEI HEIMATEN, und nichts hält sie synchron
`AutomationPlayer` speichert `AutomationState { enabled, lanes: [AutomationLane] }` in die
Datei `automation` (`AutomationPlayer.swift:165/260/263/634`). `TimelineDocument` hält ein
**zweites** `automation: [AutomationLane]` in der Datei `timeline`
(`Timeline.swift`, gelesen/geschrieben in `TimelineStore.swift:780-816`). **Derselbe Typ,
zwei Dateien, kein Abgleich.** Der SPIELER liest die erste, der (heute türlose) EDITOR
schriebe in die zweite.

Das ist der #416-Defekt eine Ebene über dem Code: eine Entscheidung, zwei Zuhause. Und er ist
heute unsichtbar, weil die Timeline-Fläche mit #121 Slice 4 gelöscht wurde — **genau die
Lage, vor der dieses Repo warnt**: nicht kaputt, sondern *still*, bis jemand die Fläche
zurückbringt und sich wundert, warum seine Kurve nicht spielt.

### 2.2 NOTEN LIEGEN IN ZWEI WURZELN
`Project.notes: [Note]` (plus `rawTake.bars: [[Note]]`) gegen `TimelineDocument.regions`,
deren MIDI-Regionen dieselben Noten tragen. Welche gewinnt, entscheidet, wer zuletzt
geschrieben hat. Für heute harmlos (der Roll-Editor ist mit #475 weg, die Timeline türlos),
für M2 die zentrale Entscheidung: **die Timeline ist die Wurzel, `Project.notes` wird beim
Import in eine Region gehoben** — nicht umgekehrt, weil nur die Timeline mehrere Spuren und
mehrere Medien tragen kann.

### 2.3 ⭐ TEMPO HAT GAR KEINE HEIMAT IM ZEITDOKUMENT — das ist die Lücke, die M1 sichtbar macht
`Project.bpm: Double` ist ein SKALAR und liegt in der Projekt-Wurzel. `TimelineDocument` hat
**kein Tempo-Feld**. Mit #1416 gibt es jetzt `TempoMap` — eine Tempokurve ist ab heute
ausdrückbar und hat **nirgends einen Platz zum Wohnen**. Genau deshalb steht G nach F: erst
der Typ, dann das Dokument, das ihn trägt.

⚠️ **`TimelineRegion`s Doppel-Trim ist der bereits bezahlte Beleg dafür**, dass ein Skalar
nicht reicht: die Datei trägt Ticks für MIDI und Sekunden für Medien nebeneinander und ihr
eigener Kommentar erklärt, warum (ein in Sekunden gespeicherter MIDI-Trim verrutscht, wenn
sich zwischen Bearbeiten und Abspielen das Tempo ändert). Das ist eine Umgehung für zwei
Domänen und skaliert nicht.

---

## 3. Zwei Befunde, die NICHT Überlappung sind, aber in den Entwurf gehören

· **Nur ZWEI der zwölf tragen eine `schemaVersion`:** `Project` (`Project.swift:40`) und
  `TimelineDocument` (`Timeline.swift:475`). `Arrangement`, die Clip-Slots, `AutomationState`
  und jede UserDefaults-Wurzel haben keine. ⭐ **Ein Umschlag ohne Version ist ein Umschlag,
  den man nur einmal aufmachen kann** — die Versionierung gehört auf den UMSCHLAG, einmal,
  nicht in jede Wurzel.

· **`Project.drumSteps` / `drumAccents` sind eine Nutzlast ohne Klang.** Sie werden weiterhin
  kodiert und dekodiert (`Project.swift:461/507`) und `BioComposer` FÜLLT sie noch
  (`BioComposer.swift:186-198`), aber seit #166/#167 gibt es keine Drum-Stimme mehr — es kann
  kein Drum-Klang entstehen. ⚠️ **Nicht löschen, und der Grund ist der #527-Grund:** ein von
  einem älteren Build geschriebenes Projekt trägt sie, und ein Decoder, der sie nicht kennt,
  müsste entscheiden, was er mit dem Rest der Datei macht. Für M2 heißt das: der Importeur
  LIEST sie und schreibt sie nicht weiter, und diese Zeile hier ist die Begründung.

---

## 4. Der Entwurf — ein Umschlag, fünf Fächer, ein Importeur zuerst

```
DMMWProject                      ← der einzige neue Wurzel-Typ
  ├─ envelopeVersion: Int        ← EINMAL, auf dem Umschlag (nicht je Fach)
  ├─ meta      { id, name, artist, savedAt }
  ├─ timebase  : Timebase        ← #1416. ppq · sampleRate · TempoMap · MeterMap
  ├─ musical   { keyRoot, scaleRaw, styleRaw, modeRaw, a4Hz, toneSystemID, moodFields }
  ├─ timeline  : TimelineDocument
  ├─ sound     { patch: SynthPatch, fxCharacterRaw }
  └─ legacy    { notes, rawTake, drumSteps, drumAccents, loopBars, bpm }
                                 ← NUR vom Importeur beschrieben, nie vom Schreiber
```

**Vier Regeln, jede mit ihrem Grund:**

1. **IMPORTEUR ZUERST, SCHREIBER ZWEITENS** (das Audit sagt es und es ist die ganze
   Risikominderung): M2 legt den Umschlag an und einen Importeur, der die fünf SONG-Wurzeln
   liest. **Es wird noch keine neue Datei geschrieben.** Alte Dateien öffnen weiter, und wenn
   der Importeur falsch liegt, ist nichts verloren — die Quelle ist unangetastet.
2. **`bpm` WIRD ZU `timebase.tempoMap`, nicht neben sie.** Ein Skalar-BPM und eine Tempokurve
   nebeneinander sind dieselbe Entscheidung in zwei Zuhause, und genau deshalb steht der
   Import als `TempoMap.constant(project.bpm)` im Entwurf: die Umwandlung ist total, sie
   verliert nichts, und sie hinterlässt kein zweites Feld.
3. **DIE AUTOMATIONS-DOPPELUNG WIRD IM IMPORT ENTSCHIEDEN, nicht vertagt:** `timeline`
   gewinnt, `automation` wird beim Import hineingefaltet, und der Spieler liest danach aus dem
   Dokument. ⚠️ Solange das nicht passiert ist, bleiben BEIDE Dateien liegen — die
   `automation`-Datei abzuklemmen, bevor der Umschlag sie trägt, macht aus einer sichtbaren
   Doppelung eine stille Stummheit (#527).
4. **DIE SIEBEN NICHT-SONG-WURZELN BLEIBEN DRAUSSEN.** Bibliothek (Patches, FX-Presets,
   Moods) und Einstellungen (Matrix, Routing, Track-FX) sind APP-Zustand. Ein Projektwechsel
   darf sie nicht ersetzen. Das Projekt trägt den EINEN Patch, den es klingen lässt, als WERT
   — er ist klein und stückbestimmend; alles andere per Verweis oder gar nicht.

---

## 5. Was dieser Entwurf NICHT entscheidet (und wem es gehört)

· **Das Dateiformat auf der Platte** (ein `.echoel`-Paket gegen eine JSON-Datei) — das ist
  eine Founder-/Produktfrage, keine Architekturfrage, und sie ist umkehrbar, solange der
  Umschlag ein `Codable`-Werttyp ist.
· **Ob `Arrangement` und die Clip-Slots überhaupt in den Umschlag kommen.** Beide sind türlos
  (`ArrangeTimelineView` und `ClipView` sind mit #121 Slice 4 gelöscht). Sie gehören in die
  SONG-Klasse, weil sie Stück-Inhalt tragen — aber ob M2 sie importiert oder erst M5, wenn
  eine Fläche zurückkommt, ist eine Scheiben-Entscheidung, keine Entwurfs-Entscheidung.
· **Migration alter `projects.json`-Dateien auf dem GERÄT.** Nur eine Geräte-Session kann
  sagen, ob ein echtes gespeichertes Projekt durch den Importeur kommt. Der Importeur ist
  gegen die TYPEN testbar, nicht gegen die Dateien echter Nutzer.

---

## 6. Nächste Scheibe (M2), Umfang

Drei Dateien, ein Wächter, null Aufrufstellen-Änderungen: `Core/DMMWProject.swift` (der
Umschlag), `Core/DMMWProjectImport.swift` (die fünf Leser), ein Wächter, der je Altformat
die Dekodier-Treue prüft — und **keine Schreibseite**. Genau die Form, die #1416 gerade
vorgemacht hat: additiv, von beiden Gates gebaut, vom blockierenden Bundle fahrbar, und
zurücknehmbar durch Löschen zweier Dateien.
