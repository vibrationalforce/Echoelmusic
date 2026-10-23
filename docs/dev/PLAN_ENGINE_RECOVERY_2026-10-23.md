# Plan · Die früheren Engines zurück nach Echoel Studio — DDSP · BodyVibe · Field · MIDI-Prozessor

**Stand 2026-10-23 · nur PLAN, nichts gebaut, nichts am Gerät bestätigt.** Anlass: der Founder
nach dem AUv3-Check („Es läuft, aber es fehlt gefühlt MIDI Processor … die komplexe Engine von
den früheren Builds … DDSP und mehrere Engines in einer?“). Die Entscheidungen, die dieser Plan
braucht, stehen EINMAL in `docs/dev/FOUNDER_INBOX.md` (GM30) und hier nicht noch einmal als
Frage. Alles hier ist gemessen (read-only, kommentar-bereinigt); wo eine Zeile auf eine Datei
zeigt, ist die Zeilennummer ein Datum, kein Sachverhalt.

## 0. Die Antwort in fünf Sätzen

1. **Ja, die frühere Engine war mehrere in einer.** Der alte AUv3 hieß „EchoelBodyVibe“
   (`aumu`/`echl`, `Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift`) und rechnete drei
   Kerne zusammen: **`EchoelDDSP`** (harmonisch + Rauschen, 3.804 Zeilen), eine
   **`EchoelCellular`**-Textur (623 Zeilen) und **`EchoelReverb`**. Host-Parameter 0–7:
   coherence, hrv, heartRate, breathPhase, baseFrequency, textureAmount, reverbMix, masterGain.
   Die frühere App lief DDSP an fünf Stellen (Harmonie, Lead, Bass, Touch, Spur-Rack —
   `docs/dev/HISTORY_ARCHIVE.md` A1).
2. **„Field“ war keine Engine**, sondern die Spielfläche: Touch-Instrument + Patch
   „Echoel Field“ + `FieldAutoPlay`, das selbst Töne erzeugt.
3. **Einen MIDI-Prozessor (`aumi`) gab es nie** — weder in der früheren App noch in Studio.
4. **Heute** öffnet `echl` in Studio den Studio-Synth (`SynthKernel`: PolyBLEP → SVF,
   16 Stimmen, 10 Parameter). Das ist Absicht (alte Host-Sessions laden weiter) und zugleich die
   eine Risikostelle dieses Plans (§4).
5. **Der Rückweg ist ein Neubau in die heutigen Besitzer, keine Kopie** (Produktgesetz:
   „a historical deletion revokes an IMPLEMENTATION, not the capability“) — in drei Stufen,
   jede an ein Gate gebunden (§2).

## 1. Was Studio heute in der einen Erweiterung trägt

`EchoelStudio/Plugins/AUv3/Info.plist`, acht Komponenten:

| Typ/Subtyp | Name | Kern |
|---|---|---|
| `aumu`/`eSyn` | Echoel Synth | `SynthKernel` |
| `aumu`/`eDrm` | Echoel Drums | `DrumKernel` |
| `aumu`/`eSmp` | Echoel Sampler | `SamplerKernel` |
| `aufx`/`xEQ5` `xCmp` `xDly` `xRvb` | EQ · Compressor · Delay · Reverb | `EchoelDSP` |
| `aumu`/`echl` | Echoel Synth (earlier sessions) | `SynthKernel` |

Kein `aumi`. Studio kann auch keinen MIDI-Effekt **hosten**: `PluginHost.refreshCatalog` listet
nur MusicDevice und Effect, und `.midiEffect` hat keinen Produktions-Leser.

## 2. Der Rückweg — drei Stufen, in dieser Reihenfolge

### Stufe K · „Echoel Keys“ — der erste MIDI-Prozessor (frei)

**Was:** vier Umformungen dessen, was gespielt wird — nichts wird erzeugt, also verträgt es sich
mit NEUPLANUNG §2, Prinzip 1 („Nichts komponiert ungefragt“):
1. Skalen-Sperre (Grundton + Skala, wie „Keys Follow Scale“ in der App),
2. Transponieren ±24 Halbtöne (vor der Sperre, damit es in der Tonart bleibt),
3. Tastenbereich und Anschlag (Unter-/Obergrenze, fester Anschlag),
4. alles andere unverändert durchreichen (CC, Pitch-Bend, Aftertouch, Program Change, SysEx).

**Warum zuerst:** kleinster Schritt mit hörbarem Nutzen in AUM/Cubasis/Loopy/Drambo, kein
Körper-Sensor nötig, nutzt den vorhandenen P1-Kern (`LiveKeys`, `MusicalContext`).

**Scheiben (je ein Commit mit Verhaltenstest):**
- **K1** `LiveKeys` aus `EchoelEngine` nach `EchoelKernels` (die Erweiterung darf `EchoelEngine`
  nie importieren, `studio.yml` prüft es doppelt) und eine Skalen-Tabelle mit 128 Einträgen, die
  abseits des Render-Threads gebaut wird — `Scale.intervals` baut heute bei jedem Aufruf ein
  neues `Set` und ist damit auf dem Render-Thread verboten.
- **K2** reiner Kern MIDI-ein → MIDI-aus, ohne Allokation, mit Tests auf macOS und Linux; die
  heutige Grenze „höchstens 3 Nachrichten je Taste“ reicht für Akkorde nicht.
- **K3** neue AU-Klasse: ein stiller Stereo-Ausgang (Apple DTS: ein MIDI-Plug-in braucht trotzdem
  einen Ausgangsbus für die Abtastrate), `midiOutputNames`, der MIDI-Ausgangsblock in
  `allocateRenderResources` zwischengespeichert, 1- und 2-Byte-Nachrichten weitergereicht
  (heute verwirft die Render-Schleife alles unter 3 Byte).
- **K4** Info.plist-Eintrag (`aumi`, neuer Subtyp, Tag `MIDI`), ein `case` in `makeUnit`, eine
  dritte `OwnPlugin`-Liste und `PluginTests` angepasst (heute: Instrument = `.instrument`,
  frei = `.effect`).
- **K5** Gerät: AUM (MIDI-Strip → Echoel Synth), Cubasis, Loopy Pro; Logic für iPad: erscheint
  es unter MIDI FX? (unbestätigt — GarageBand hostet nach Berichten keine `aumi`).

**Gate:** (a) eine der drei wartenden Familien SP · SR · SN ist geschlossen (WIP-Grenze 3),
(b) `eSyn` lädt nachweislich in AUM auf dem Gerät (`decisions.csv` 2026-09-10, PROPOSED:
„Component aumu zuerst, aumi/aufx nur nach geraeteverifiziertem Laden“), (c) GM30 Teil 1 beantwortet.

**Danach, nur mit Founder-Wort:** ein Arpeggiator auf Host-Tempo (der frühere `ArpFigure`-Kern
mit 18 Tests wäre portierbar). Er erzeugt Töne, solange Tasten gehalten werden — NEUPLANUNG
lehnt die Euklid-Spur aus genau diesem Grund ab, deshalb nicht ohne dein Ja.

### Stufe D · DDSP als vierte eingebaute Engine — ohne Körper, klingt trotzdem

**Was:** ein neuer Kern in `EchoelDSP` (harmonisch + Rauschen + Textur), als viertes Gerät neben
Synth, Drums, Sampler, und als eigenes `aumu` in der Erweiterung. Das ist die „komplexe Engine“,
die du aus früheren Builds kennst — neu geschrieben, nicht kopiert.

**Warum Neubau:** der frühere `EchoelDDSP` ist ganz in `#if canImport(Accelerate)` gewickelt
(17 vDSP-Stellen), hängt an einem `SynthPatch`, der mit Studios gleichnamigem Typ kollidiert, und
an `EchoelEntrainment` (DO NOT RESTORE, GM19). Der Prototype-Fund-Antrag sagt, Core und DSP
importieren nur Foundation und laufen auf Linux — ein Accelerate-Port würde diesen Satz falsch
machen.

**Was jede neue eingebaute Engine anfasst** (gemessen): `InstrumentDevice` (neuer Fall am Ende,
Titel, `builtIn`, Parametertabelle), `docs/FORMAT.md`, `StoredNamesTests` +
Schlüsselreihenfolge, `InstrumentTablesTests`, `KernelParameterContractTests`, ein Kern nach
`EngineInstrumentKernel`, `BuiltInKernels`, `LiveKeys`, `SoundPanel` (vierte Auswahl; die Annahme
„höchstens eine Auswahlzeile je Gerät“ bricht), `OwnPlugin` + `StoreView` + `makeUnit` +
Info.plist, und vor dem Verkauf `auval` plus zwei Hosts.

**Kosten-Messung zuerst:** die Engine legt jeden Kern 32-mal vor (32 Instrument-Plätze). Der
frühere BodyVibe kostete im Leerlauf ~20 Prozentpunkte AUM-CPU (Board A11). Scheibe D0 misst das
Budget, bevor die Tabelle wächst.

**Gate und Zeitpunkt — deine Wahl (GM30 Teil 2):**
- **(a) in P1, Dezember 2026** — nach dem 30.11. (Antrag), wenn eine Familie zu ist; P2 trägt
  dann eine Einheit mehr durch `auval` und die Zwei-Host-Prüfung.
- **(b) direkt nach 1.0** (1.0 kommt mit P2, Vision §8: Januar–März 2027), vor P6. **Empfehlung**, weil es deinem
  Satz „wenn das stabile Fundament steht“ entspricht und 1.0 nicht verlängert.

Die Abnahme ist in beiden Fällen dein Ohr — kein Test kann „klingt reich“ entscheiden.

### Stufe B · EchoelBodyVibe — der Körper kommt an DIESELBE Engine

**Was:** Puls und Atem werden Modulationsquellen (`ModSource.bio.*` → `ModRoute` →
`ParameterAddress`, kein eigener Bus — NEUPLANUNG), Kamera-rPPG und BLE-Gurt kommen als
„EchoelSense“ zurück, und die DDSP-Engine aus Stufe D wird damit zum Körper-Instrument
„EchoelBodyVibe“ (Vision §5a: ohne Sensor klingt es trotzdem).

**Zeitpunkt:** P6, nach Plan 2028; mit Prototype-Fund-Förderung im Förderzeitraum Juni–November
2027 (NEUPLANUNG: die EchoelSense-Hälfte wird nur dann vorher gebaut). Kein Körper-Code vorher.

**Keine Gesundheitsbehauptung**, nirgends: Körpersignale sind Steuerdaten wie ein Controller.

### Field

`FieldAutoPlay` erzeugt Töne ohne Noten-Payload und steht damit gegen NEUPLANUNG §2, Prinzip 1. Eine
reine Spielfläche (Tippen = Ton, Skalen-Sperre wie bei Keys) passt zu GM29 (Tastenleiste auf dem
Bildschirm) und bräuchte keine neue Regel. Der selbstspielende Teil kommt nur, wenn du dieses Prinzip dafür
aufhebst (GM30 Teil 4).

## 3. Reihenfolge auf einen Blick

| Wann | Was | Hängt an |
|---|---|---|
| jetzt bis 30.11. | nichts davon gebaut; P1 und Antrag | WIP 3 voll (SP · SR · SN) |
| nach der ersten geschlossenen Familie | Stufe K (Echoel Keys, K1–K5) | `eSyn` lädt in AUM am Gerät · GM30.1 |
| Dez 2026 **oder** nach 1.0 | Stufe D (DDSP-Engine, D0 Kosten zuerst) | GM30.2 · dein Ohr |
| Juni–Nov 2027 (gefördert) / 2028 | Stufe B (BodyVibe = D + Körper) | P6 · Förderbescheid |

## 4. Die eine Risikostelle: `echl`

Host-Sessions, die mit der früheren App gespeichert wurden, tragen Automation auf den Adressen
0–7 (coherence … masterGain). Heute bewegen dieselben Adressen Studio-Synth-Parameter
(Wellenform … Sustain) — `InstrumentState.forBaseRestore` entfernt nur den gespeicherten
Parameter-Schnappschuss, nicht die Automationsspuren des Hosts. Plausibel, nicht am Gerät
geprüft. Würde BodyVibe später `echl` übernehmen, kippte das Layout ein zweites Mal, diesmal
gegen Studio-Sessions. **Empfehlung (GM30 Teil 3): `echl` bleibt der Synth, BodyVibe bekommt einen
neuen Subtyp.** Typ, Subtyp und Hersteller sind nach dem ersten Ausliefern eingefroren.

## 5. Was dieser Plan NICHT tut

- Er baut nichts vor den Gates und öffnet keine vierte wartende Familie.
- Er bringt keinen Gesundheits-, Wellness- oder Therapie-Satz in Store, Website oder App.
- Er hostet keine fremden MIDI-Effekte (das ist NEUSTART M3 und eine eigene Scheibe).
- Er kopiert keine Datei aus `Sources/` nach `EchoelStudio/` — portiert wird der bewiesene Kern.

Quellen der Messung: `EchoelStudio/Plugins/AUv3/Info.plist`, `AudioUnitViewController.swift`,
`EchoelKernels/BuiltInKernels.swift`, `InstrumentAudioUnit.swift`, `App/Engine/PluginHost.swift`,
`EchoelEngine/LiveKeys.swift`, `EchoelCore/MusicalContext.swift`, `EchoelCore/OwnPlugins.swift`,
`Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift`, `docs/dev/NEUPLANUNG_2026-10-18.md`,
`docs/dev/ECHOEL_VISION_2026-10-19.md`, `docs/dev/HISTORY_ARCHIVE.md`, `decisions.csv`.
Plattform: Apple-Doku zu `kAudioUnitType_MIDIProcessor`, `midiOutputNames`,
`MIDIOutputEventBlock`/`MIDIOutputEventListBlock`, `musicalContextBlock` (gelesen 2026-10-23).
