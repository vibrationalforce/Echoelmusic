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

### 2.1 ⛔ AUTOMATION HAT DREI HEIMATEN — zwei davon doppeln sich, die dritte NICHT
`AutomationPlayer` speichert `AutomationState { enabled, lanes: [AutomationLane] }` in die
Datei `automation` (`AutomationPlayer.swift:165/260/263/634`). `TimelineDocument` hält ein
**zweites** `automation: [AutomationLane]` in der Datei `timeline`
(`Timeline.swift`, gelesen/geschrieben in `TimelineStore.swift:780-816`). **Derselbe Typ,
zwei Dateien, kein Abgleich.** Der SPIELER liest die erste, der (heute türlose) EDITOR
schriebe in die zweite.

⭐ **KORRIGIERT BEIM BAUEN VON M2 (#1419): es sind DREI, nicht zwei.** Die dritte ist
`Clip.automation` — eine Kurvenliste IN jedem Clip. ⚠️ **Sie gehört NICHT zur Doppelung, und
das genau aufzuschreiben ist der Punkt:** ihr GELTUNGSBEREICH ist ein anderer
(clip-relativ statt song-absolut), so wie jede DAW Clip-Automation von Spur-Automation
trennt. Wer „Automation vereinheitlichen" liest und drei Dinge in eins faltet, verliert
diese Unterscheidung still. Die Doppelung sind die ZWEI song-absoluten Heimaten unten; die
dritte wird benannt, damit sie beim Vereinheitlichen nicht mitgerissen wird.

Das ist der #416-Defekt eine Ebene über dem Code: eine Entscheidung, zwei Zuhause. Und er ist
heute unsichtbar, weil die Timeline-Fläche mit #121 Slice 4 gelöscht wurde — **genau die
Lage, vor der dieses Repo warnt**: nicht kaputt, sondern *still*, bis jemand die Fläche
zurückbringt und sich wundert, warum seine Kurve nicht spielt.

### 2.2 NOTEN LIEGEN IN ZWEI WURZELN
`Project.notes: [Note]` (plus `rawTake.bars: [[Note]]`) gegen `TimelineDocument.regions`,
deren MIDI-Regionen dieselben Noten tragen. Welche gewinnt, entscheidet, wer zuletzt
geschrieben hat. Für heute harmlos (der Roll-Editor ist mit #475 weg, die Timeline türlos),
für M2 die zentrale Entscheidung: **die Timeline ist die Wurzel** — nicht umgekehrt, weil nur
sie mehrere Spuren und mehrere Medien tragen kann.

⛔ **UND DER ZWEITE HALBSATZ DIESER ZEILE WAR FALSCH — er lautete „`Project.notes` wird beim
Import in eine Region gehoben", und das Schreiben des Codes (#1419) hat ihn widerlegt.** Es
geht nicht in EINEM Schritt: eine `TimelineRegion` trägt eine `clipID`, die Noten wohnen in
`Clip.melody`, und Clips sind eine ANDERE persistierte Wurzel. Eine Region, deren Clip nicht
mit im Umschlag liegt, ist ein hängender Verweis. Heben hieße also zusätzlich einen Clip zu
PRÄGEN — das ist Umstrukturieren, und ein Importeur, der umstrukturiert, ist nicht mehr gegen
„hat er etwas verloren?" prüfbar, sondern nur noch gegen „hat er so geraten wie ich?". Die
erste Frage ist die einzige, die ein Importeur schuldet. **Der Take fährt deshalb GANZ in
`legacy` mit, und das Heben gehört dem SCHREIBER.** ⭐ Lehre, und sie ist der Grund, warum
diese Korrektur hier steht und nicht nur im Quelltext: **ein Entwurf, der eine Umwandlung in
einem Satz beschreibt, hat sie damit noch nicht auf ihre Schritte geprüft** — „wird gehoben"
klang wie eine Zuweisung und war eine Restrukturierung.

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
  ├─ content   { timeline, clipSlots: [Clip?], songForm: Arrangement, playerAutomation }
  ├─ sound     { patch: SynthPatch, fxCharacterRaw }
  └─ legacy    { notes, rawTakeBars, rawTakeStyleRaw, drumSteps, drumAccents, loopBars }
                                 ← NUR vom Importeur beschrieben, nie vom Schreiber
```

⛔ **ZWEI KORREKTUREN AN DIESER SKIZZE, beide aus #1419, beide vom Code gefunden:**
· **`bpm` stand in `legacy` — und widersprach damit Regel 2 vier Zeilen weiter unten**, die
  sagt, er werde zur `tempoMap` und hinterlasse kein zweites Feld. Die Skizze und ihre eigene
  Regel waren im selben Abschnitt uneins; der gebaute Umschlag hat KEIN `bpm`-Feld, und ein
  Wächter hält das fest. ⭐ **Lehre: ein Entwurf widerlegt sich manchmal auf derselben Seite,
  und ein Diagramm liest sich dabei autoritativer als der Fließtext daneben.**
· **`timeline` stand allein, wo VIER Inhalts-Wurzeln hingehören.** §5 führte „ob `Arrangement`
  und die Clip-Slots überhaupt in den Umschlag kommen" als offene Scheiben-Frage; M2 hat sie
  entschieden — sie kommen mit, weil sie SONG-Inhalt tragen und weil eine Wurzel, die man
  später nachrüstet, in der Zwischenzeit die einzige Heimat von Nutzerdaten ohne Umschlag ist
  (#527). `clipSlots` bleibt dabei POSITIONAL, Löcher inklusive: der Index IST die Identität,
  auf die eine gespeicherte Section zeigt.

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
   gewinnt. ⛔ **Hier stand „`automation` wird beim Import hineingefaltet", und das ist beim
   Bauen präzisiert worden (#1419), weil „einfalten" zwei Dinge heißen kann und nur eines
   davon richtig ist.** „Timeline gewinnt" ist eine **LESE-Regel**: eine Spieler-Spur für einen
   Parameter, den die Timeline schon fährt, fällt weg — **jede andere Spieler-Spur wird
   MITGENOMMEN**, nicht gelöscht. Ein Importeur, der alle löschte, machte aus einer sichtbaren
   Doppelung einen stillen Verlust, also genau die #527-Form, vor der der nächste Satz warnt.
   ⚠️ Und solange kein Schreiber existiert, bleiben ohnehin BEIDE Dateien liegen — die
   `automation`-Datei abzuklemmen, bevor der Umschlag sie trägt, macht aus einer sichtbaren
   Doppelung eine stille Stummheit.
4. **DIE SIEBEN NICHT-SONG-WURZELN BLEIBEN DRAUSSEN.** Bibliothek (Patches, FX-Presets,
   Moods) und Einstellungen (Matrix, Routing, Track-FX) sind APP-Zustand. Ein Projektwechsel
   darf sie nicht ersetzen. Das Projekt trägt den EINEN Patch, den es klingen lässt, als WERT
   — er ist klein und stückbestimmend; alles andere per Verweis oder gar nicht.

---

## 5. Was dieser Entwurf NICHT entscheidet (und wem es gehört)

· **Das Dateiformat auf der Platte** (ein `.echoel`-Paket gegen eine JSON-Datei) — das ist
  eine Founder-/Produktfrage, keine Architekturfrage, und sie ist umkehrbar, solange der
  Umschlag ein `Codable`-Werttyp ist.
· ⭐ **ENTSCHIEDEN IN M2 (#1419), nicht mehr offen: `Arrangement` und die Clip-Slots kommen
  mit.** Die Frage stand hier als Scheiben-Entscheidung („M2 oder erst M5, wenn eine Fläche
  zurückkommt") und ist so beantwortet: beide sind türlos, aber türlos heißt nicht
  wirkungslos — eine SONG-Wurzel, die der Umschlag NICHT trägt, ist in der Zwischenzeit die
  einzige Heimat von Nutzerdaten ohne Umschlag, und genau daraus wird die #527-Lage. Beide
  fahren im Fach `content` mit, die Clip-Slots positional.
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
