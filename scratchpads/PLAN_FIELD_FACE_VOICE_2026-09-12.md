# PLAN — Field-Gesicht · Smile-Modulation · Stimm-Rubrik (Founder 2026-09-12)

**Auslöser.** Screenshot mit rot eingekreistem Eintrag „Play with your face — front camera,
no pul…" im Quellen-Dropdown der Puls-Pille, dazu wörtlich:

> „Sorry ich hab die Funktion gesehen aber es soll nicht dort angeschaltet werden sondern im
> Field und den Field Sound modulieren das Gesicht kann in der Größe angepasst werden. Smile
> detection sollte reichen um den arpeggio etc zusätzlich zu beeinflussen wobei Filter wie bei
> Logic aber mit shimmer reverb wenn smile detected wird. Die stimme soll unabhängig davon
> eine eigene Rubrik bekommen mit den entsprechenden Einstellungen für Autotune granular
> Synthese und Harmonizer welche sich automatisch auf kammerton ind die Tonart sowie das
> Tuning anpasst"

**Das ist eine KORREKTUR an #1257, nicht ein neues Feature.** Die Face-Quelle wurde als
VIERTE BIO-QUELLE gebaut (Puls-Pille → Quellen-Dropdown), also als Alternative zu Kamera,
Gurt und Simulation. Der Founder will sie als **Feld-Werkzeug**: eine Ebene im Visual, die
den FELD-KLANG moduliert — nicht als Ersatz für die Pulsquelle.

---

## Was GEMESSEN schon da ist (nicht neu bauen)

| Sache | Stand, gemessen | Datei |
|---|---|---|
| Face-Tracking + zwölf Kanäle (Smile/Brow/Jaw/Kopf/Augen/Mund) | LIVE, `ModSource.faceSmile` u. a., `hasProducer` = true | `Bio/FaceExpressionBioPublisher.swift` |
| Kamerabild als Metal-Textur (Deckkraft · Spiegel · Blend · Cutout) | LIVE seit K5 (#1262), beide Montagen binden die Schlüssel | `Views/MetalBioView.swift`, `Core/StudioDefaultKeys.swift` |
| Kamera wird beim ersten Face-Start sichtbar | NEU seit #1297 (Einmal-Riegel auf 0,6) | `Studio/EchoelStudioView.swift` |
| Modulations-Matrix mit Fläche („Body → parameter") | LIVE seit #1250, Ziele = `ModDestinationKey.all` | `Studio/PatchbayView.swift` |
| **Autotune folgt Tonart UND Kammerton** | **LIVE** — `updateVoiceTune` liest `rootIndex`, `scale` und `a4Hz` ~1 Hz aus der EINEN gespeicherten Definition | `Audio/AudioEngine.swift:3695-3706` |
| **Harmonizer folgt der Tonart** | **LIVE** — „Harmony in key" (`updateHarmonyInKey`) wählt die Intervalle pro gesungener Note aus der Tonart | `Audio/AudioEngine.swift` |
| Granular auf der Stimme | LIVE seit #849, schaltbar, default AUS | `Studio/AudioInputPickerView.swift` |
| Kammerton-Fächer (A4 an alle Stimmen) | LIVE — `applyConcertPitch` fächert an sieben Stimmen | `Studio/EchoelStudioView.swift:4480-4487` |
| Mikrotonales Tonsystem | `Sequencer/MicrotonalTuning.swift` existiert, `MusicalKey`-Pfad ist gleichstufig | — |

**Konsequenz: von den vier Founder-Punkten sind ZWEI zur Hälfte schon erfüllt.** Die
Stimm-Kette passt sich Kammerton und Tonart bereits automatisch an; was fehlt, ist die
RUBRIK (sie ist im Audio-Input-Blatt vergraben) und das TUNING (Tonsystem) als dritte Achse.

---

## Die Scheiben, in Reihenfolge

### FV1 — Die Face-Tür wandert ins Field
Heute: `BioSourceOption.face`, vierter Eintrag des Quellen-Dropdowns, MUTUALLY EXCLUSIVE zu
Kamera/Gurt/Simulation (`startBioSource` schaltet um).
Ziel: ein Schalter im `visualPanel` („Face"), der den Publisher startet/stoppt.

⚠️ **ARCHITEKTUR-ENTSCHEIDUNG, die vor dem Code steht.** Der Face-Publisher schreibt heute
`BioSampleFrame`s auf den Bus — er IST eine Bio-Quelle. Als Feld-Werkzeug liefe er
GLEICHZEITIG mit einer Pulsquelle, also zwei Publisher auf EINEN `latestBio`-Slot. Das ist
genau die #1015-Verschränkung, die schon einmal drei Scheiben gekostet hat.
**Zwei Formen, und die zweite ist die richtige:**
- (a) Face bleibt Bio-Quelle, bekommt nur eine zweite Tür → die Verschränkung wird REAL.
- (b) **Face wird ein MODULATIONS-Erzeuger, keine Bio-Quelle.** Die zwölf Kanäle gehen an die
  Matrix (die es seit #1250 gibt), der Puls kommt weiter von Kamera/Gurt/HealthKit. Das ist
  auch das, was der Founder-Satz sagt: „den Field Sound modulieren".
**Gewählt: (b).** Aufwand liegt darin, den Publish-Pfad von `latestBio` auf einen
Gesten-Kanal umzuhängen, ohne die K2–K7-Arbeit (Kalibrierung, Signalverlust-Fade, OSC
`/echoelmusic/gesture/*`) zu verlieren.

### FV2 — Gesichtsgröße einstellbar
Heute gibt es Deckkraft · Spiegel · Blend · Cutout. Neu: **Größe/Zoom** der Kameraebene.
Der Renderer bekommt einen Skalenfaktor auf die Textur-UV; ein `EchoelValueField`
„Camera size" neben „Camera layer".

### FV3 — Smile → Filter + Shimmer-Reverb
Founder: „Filter wie bei Logic aber mit shimmer reverb wenn smile detected wird", und
„Smile detection sollte reichen um den arpeggio etc zusätzlich zu beeinflussen".
⚠️ **GEMESSEN: es gibt heute KEINEN Shimmer-Reverb.** `grep shimmer` über `Sources/` findet
`partialShimmer` (eine Oszillator-Eigenschaft in `EchoelDDSP`) und Genre-Prosa — keine
Reverb-Stufe mit oktav-pitchgeschobenem Feedback. Das ist die einzige Scheibe hier, die eine
neue DSP-Stufe braucht, nicht nur eine Route.
Drei Teile: (1) Smile → Filter-Cutoff als Route (die Matrix kann das schon),
(2) Shimmer-Stufe in `EchoelFXChain` (Pitch-Shift +12 im Reverb-Feedback),
(3) Smile → Shimmer-Mix.

### FV4 — Die Stimme bekommt ihre eigene Rubrik
Heute liegen „Tune to key" · „Harmony voices" · „Harmony in key" · „Granular texture" im
Audio-Input-Blatt hinter der Master-Tür „Audio input". Der Founder will sie **unabhängig
davon**, als eigene Rubrik.
⚠️ **DIE MODAL-DECKE GILT.** `EchoelStudioView` trägt 13 Modifier auf der Kette und der
Black-Screen-SIGSEGV von 10.76.34 kam vom Anhängen eines weiteren. Eine neue Stimm-Fläche
wird ein **Dropdown-Panel neben den bestehenden Chips**, KEIN neues `.sheet`.

### FV5 — Das TUNING als dritte Achse
Autotune und Harmonizer folgen Kammerton und Tonart. Das TONSYSTEM
(`MicrotonalTuning`) ist der dritte Teil des Founder-Satzes und noch nicht am Korrektor.

---

## Was NICHT passiert
- Kein neues `.sheet`/`.fullScreenCover` (Modal-Decke).
- Keine zweite Kopie von Tonart oder Kammerton — es gibt EINE gespeicherte Definition, und
  `updateVoiceTune` liest genau sie (#416).
- Die K2–K7-Arbeit wird nicht weggeworfen; FV1 hängt den Publish-Pfad um, sie nicht ab.
