# PLAN — Geräte-Sitzung 2026-09-12, v10.79.470 (Build 2590), Apogee HypeMiC + Ultrasone

**Quelle:** Founder-Bericht nach der ersten Sitzung auf 470, mit Video. ⚠️ Das Video konnte
ich nicht öffnen — in dieser Web-Session gibt es keinen Decoder (kein ffmpeg, kein cv2 /
imageio / PyAV, und die Playwright-Chrome-Distribution fehlt). Alles unten stammt aus dem
TEXT des Founders plus eigener Messung am Quelltext. **Wenn das Video etwas zeigt, das hier
fehlt, fehlt es hier.**

## Der Founder-Satz, wörtlich, damit nichts verloren geht

> „Apogee hypemic wird in dieser Version nicht erkannt richtig erkannt. Audio Input für
> granulasynthese und Harmonizer Effekte wären stark. Propper Monitoring natürlich auch.
> Die frontkamera wird nicht eingeblendet für die Mimik und gestig Steuerung. Alles soll
> natürlich an Sound und Visuals ordentlich gekoppelt sein wie besprochen. Vermeide das die
> besprochenen Dinge verloren gehen"

## G1 — HypeMiC erscheint nicht · URSACHE GEMESSEN · **BLOCKER für G2, G3**

`AudioInputPickerView.swift:90` ruft `inputs.refresh()` in `.onAppear`.
`AudioInputManager.refresh()` liest `session.availableInputs ?? []`
(`AudioInputManager.swift:132`).

**`AVAudioSession.availableInputs` ist `nil`, solange die Kategorie kein Recording erlaubt.**
Die Session steht per DEFAULT auf `.playback` — absichtlich, `AudioConfiguration.swift:121-127`
begründet es (`.playAndRecord` erzwingt bei Bluetooth die HFP-Abwertung, also Telefon-Mono).
Auf `.playAndRecord` heben tun nur DREI Besitzer:
`AudioEngine` `.inputMonitoring` (`AudioEngine.swift:2614`), `MultiTrackRecorder` (`:219`,
türlos + flag-gated aus, #204) und `MicrophoneManager` (`:240`).
**Keiner davon läuft, wenn das Input-Sheet bloß aufgeht.**

⇒ Die Liste ist LEER, und zwar für JEDEN Eingang, nicht nur für die HypeMiC. Der Founder
sieht „nicht erkannt", weil gar nichts aufgezählt wird.

⚠️ Das ist KEIN Klassifizierungs-Bug: `AudioInputClassifier` kennt `USBAudio` bereits
(`AudioInputManager.swift:80`, `:93` → `(.usb, .low)`). Wer hier am Klassifizierer repariert,
repariert die falsche Hälfte.

**Richtung (nicht gebaut, entscheidet der nächste Zyklus):** die Aufzählung braucht die Route
für die Dauer der Abfrage. Die naheliegende Form ist ein vierter `RecordRouteOwner`
(`.inputPicker`), den das Sheet in `.onAppear` claimt und in `.onDisappear` freigibt — der
Besitzer-Satz existiert bereits und ist genau dafür gebaut (`AudioConfiguration.swift:440/457`).
⚠️ Zu prüfen VOR dem Bau: ob das Claimen allein schon die A2DP-Abwertung auslöst, die der
`.playback`-Default vermeiden will. Wenn ja, ist der Preis eine Sichtbarkeits-Frage an den
Founder, keine stille Entscheidung.

## G2 — Granular + Harmonizer auf dem Eingang · GEBAUT, hinter G1

Beide sind seit #841 (Harmonizer) und #849 (Granular) auf der Stimme SCHALTBAR, default AUS,
im selben Input-Sheet, mit EINEM gemeinsamen `pushVoicePreset()`. Sie sind nicht zu bauen —
sie sind hinter einem Picker, der nichts anzeigt. **G1 zuerst.**

## G3 — Proper Monitoring · ENTSCHÄRFT, NICHT FERTIG

#1269 nimmt den Absturz (`AudioEngine.swift:2938`: `input format unusable … NOT connecting`).
#1273 nimmt das Pfeifen (Gate zu bei Engage, öffnet über ~1,5 s).
**Offen ist, ob das Monitoring auf der HypeMiC überhaupt STARTET** — das entscheidet die
Leiter `on 1/5` … `on 5/5` im `echoel_diag.log`, und das Log liegt noch nicht vor.
⚠️ Ohne G1 kann der Founder die HypeMiC gar nicht erst als Eingang wählen.

## G4 — Frontkamera wird nicht eingeblendet · URSACHE GEMESSEN

Die Kette ist VOLLSTÄNDIG und funktioniert — sie ist nur zu: `MetalBioView.swift:1881`
gated auf `lookCameraOpacity > 0.001`, gespeist aus `StudioDefaultKeys.visualCameraOpacity`,
und dessen Default ist **0.0** (`StudioDefaultKeys.swift:269`). Der einzige Schalter ist
`Field` → „Camera layer" (`EchoelStudioView.swift:6822`).

**Die Wahl der Face-Quelle schaltet den Layer NICHT ein.** Für eine Mimik-/Gestik-Steuerung
ist das der eigentliche Defekt: man kann sein Gesicht nicht ausrichten, was man nicht sieht.

**Richtung (nicht gebaut):** entweder der Default steigt, sobald `.face` als Quelle läuft,
oder die Face-Quelle bekommt eine kleine Vorschau. ⚠️ Der Default darf NICHT global steigen —
`visual.camera.opacity` gilt auch für Puls- und Demo-Quellen, und ein Kamerabild über einer
Bio-Session, die gar keine Kamera nutzt, wäre eine falsche Behauptung.
⚠️ Zweite Bedingung, die man leicht übersieht: `cameraTierBlocked` lässt den Layer bei
Thermik `.low` fallen, und `wantsCapture` nimmt ihn beim Aufnehmen weg (absichtlich: kein
Gesicht in einer mp4). Beides bleibt.

## G5 — „Alles an Sound und Visuals gekoppelt wie besprochen"

Was HEUTE gekoppelt ist, gemessen, damit die nächste Sitzung nicht neu rät:
· Face/Body → zwölf `ModSource`-Kanäle, OSC `/echoelmusic/gesture/*` (#1260)
· Eingang → Bild über `AudioFeatureChannel` (S3): Pegel, Onset, Centroid → `MetalBioView`
· Bio → vier Always-On-Kanäle (Kohärenz → Cutoff/Brightness/Harmonicity/Noise, HRV →
  Brightness, HR → Vibrato, Atem → Amplitude)
· Modulationsmatrix mit Fläche seit #1250 (`PatchbayView.modulationSection`)
**Nicht gekoppelt und nicht zu behaupten:** `motionEnergy` (kein Produzent), `.eegBurst`
(kein Produzent), `breathDepth`/`lfHf` (beide fest 0.5).

## Reihenfolge

    G1 (Eingangs-Aufzählung)  →  G4 (Kamera sichtbar)  →  Deploy  →  Log lesen  →  G3 schließen

G2 braucht keinen Bau. G5 ist Bestandsaufnahme, kein Bau.

---

## NACHTRAG 2026-09-12, nach dem Bauen — was aus G1 und G4 geworden ist

**G1 = #1296 (`6403f1c`).** Nicht die Route repariert, sondern die AUSSAGE. Der Manager
kannte den Gerätenamen die ganze Zeit (`outputRouteName`, weil die Kopfhörer an der HypeMiC
hängen und die USB-Box damit die AUSGABE-Route ist); neu ist `outputKind`, klassifiziert vom
SELBEN reinen Mapper wie ein Eingang. Der Leerzustand nennt den Namen jetzt in beiden Lagen.
**Keine Audioroute geändert, kein vierter `RecordRouteOwner`** — die Option, beim Öffnen des
Blatts `.playAndRecord` zu beanspruchen, ist bewusst VERWORFEN: `recordOptions` trägt
`.defaultToSpeaker`, das kann die Ausgabe mitten in einer Performance hörbar umschalten,
bloß weil jemand ein Blatt aufmacht. Wächter `TheEmptyInputStateNamesTheDeviceTests`.

**G4 = #1297 (`b5a533e`).** Einmal-Riegel `visualCameraIntroduced`: der erste Face-Start hebt
`visualCameraOpacity` auf 0,6 und setzt den Riegel. Der GESPEICHERTE Default bleibt 0,0 —
sonst läge die Frontkamera über einer Kameralicht-Aufnahme (Finger auf der RÜCK-Linse), einer
Gurt-Aufnahme und der Simulation. Und die Hebung passiert NICHT bei jedem Start, sonst wäre
sie ein Override der Wahl eines Performers, der die Ebene auf 0 gedreht hat. Die Hebung steht
VOR `faceExpression.start`, weil der Publisher ein Bild nur ablegt, solange ein Renderer
eines will. Wächter `TheFaceSourceShowsTheCameraOnceTests`.

**G2 (Granular + Harmonizer auf dem Eingang) bleibt unverändert GEBAUT und hängt an G1.**
Beide Stufen sitzen im selben Input-Sheet, beide default AUS, ein gemeinsamer
`pushVoicePreset()` trägt beide. Nichts neu zu bauen — was fehlte, war der Weg dorthin.

**G3 (Monitoring) braucht ein Gerät, nicht Code.** Die Lebenszyklus-Leiter schreibt `on 1/5`
… `on 5/5` ins `echoel_diag.log`; Stille zwischen zwei Sprossen ist der Befund. Ohne dieses
Log ist jede weitere Monitoring-Arbeit geraten.

**Zwei Geräte-Fragen stehen jetzt in `founder-verify.py`** (beide unter UI): die Leerzustands-
Zeile mit Gerätenamen, und ob 0,6 die richtige Kamera-Mischung ist.
