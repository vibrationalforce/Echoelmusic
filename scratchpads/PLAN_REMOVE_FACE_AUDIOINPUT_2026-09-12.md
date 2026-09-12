# PLAN — Face und Audio Input KOMPLETT entfernen (Founder 2026-09-12)

> „OK Face und Audio Input komplett entfernen. Keine Tests davon sollen im Repo bleiben"

**Das ist eine Löschanweisung, keine Umbau-Anweisung.** Sie kommt NACH `v10.79.471`, in dem
beides gerade erst erweitert wurde (#1296–#1300) — die Arbeit dieser Runde wird damit
zurückgenommen, und das ist die Entscheidung des Founders.

---

## ⚠️ EINE KONSEQUENZ, DIE ER VIELLEICHT NICHT MEINT — vor dem Schnitt genannt, dann geschnitten

Zwei Nachrichten zuvor: „Die stimme soll unabhängig davon eine eigene Rubrik bekommen mit den
entsprechenden Einstellungen für Autotune granular Synthese und Harmonizer". **Diese drei
verarbeiten das MIKROFON-Signal** — sie sitzen auf dem Monitorpfad (`input → notchEQ →
voiceTunePitch → monitorMixer`). Ohne Audio-Eingang gibt es keine Stimme zu stimmen. Die
Stimm-Rubrik ist mit dieser Löschung also nicht „später", sondern **weg**.

Die neuere Anweisung ist ausdrücklich („komplett", „keine Tests"), also wird sie ausgeführt.
Steht hier, damit die Rücknahme dokumentiert ist und nicht als Versehen gelesen wird.

## ⭐ WAS TROTZ ÄHNLICHEM NAMEN BLEIBT — gemessen, nicht vermutet

| Sache | Warum sie BLEIBT |
|---|---|
| `DSP/EchoelGranular.swift` | Einzige Konstruktionsstelle ist `EchoelFXChain.swift:218` — die FX-Kette auf dem SYNTH-Bus. Der Granular-EFFEKT auf der Musik bleibt; nur die Granular-TEXTUR auf der Stimme geht. |
| `PolySynthVoice` · `SubBassVoice` · `LaneVoiceRack` · `MetronomeVoice` · `SamplerVoice` und ihre Tests | „Voice" heisst hier SYNTH-Stimme, nicht Gesangsstimme. Ein Namens-Grep über „Voice" trifft sie alle — wer danach löscht, löscht das Instrument. |
| `Video/CameraCapture` · `CameraAnalyzer` · `CameraRPPGBioPublisher` | Das ist die RÜCKkamera-Pulsquelle (rPPG), nicht das Gesicht. Bleibt die Haupt-Bio-Quelle. |
| `RetroCapture` · `AutoMixChain` · `SingleExport` | Master-BUS, nicht Eingang. |
| `Core/TuningDetector.swift` | Hat schon heute NULL Produktions-Konsumenten (nur Kommentar-Nennungen). Unverändert lassen — es ist nicht Teil des Eingangs, es ist bereits türlos. |

---

## A — FACE (Frontkamera als Ausdrucks-/Gesten-Eingang)

**Dateien, die ganz gehen** (8):
`Bio/FaceExpressionBioPublisher.swift` · `Bio/BodyPoseAnalyzer.swift` · `Core/BodyPoseMath.swift` ·
`Core/FaceExpressionMapping.swift` · `Core/FaceTrackingRate.swift` · `Studio/FaceChannelsRow.swift` ·
`Video/CameraFrameSlot.swift` (wird NUR von der Face-Sitzung gefüttert) ·
`Tests/EchoelmusicTests/FaceExpressionMappingTests.swift`

**Symbole, die aus gemeinsamen Typen gehen:**
`BioSourceOption.face` · `BioSourceKind.face` · `BioSource.faceCam` (rawValue 6) ·
`ModSource.faceSmile/.faceBrow/.faceJaw` + die Kopf-/Augen-/Mund-/Körper-Kanäle ·
`/echoelmusic/gesture/*` in `OSCSender` · die Kameraebene in `MetalBioView`
(`camA…camTy`, `camOpacity`, `camMirror`, `camBlend`, `camMatte`, `camPresent`) ·
`StudioDefaultKeys.visualCamera{Opacity,Mirror,Blend,Cutout,Size,Introduced}` +
`faceTrackingHz` · `cameraLayerRow` und der #1298-Schalter.

**⚠️ `BioSource.faceCam = 6` ist ein PERSISTIERTER rawValue.** Wie bei `TrackInstrument.drums`
(#167) entscheidet der Decoder, ob ein unbekannter Case die ganze Struktur verwirft. Vor dem
Entfernen des Cases prüfen, ob `BioSource` `Codable` ist und wie sein Decoder fällt.

## B — AUDIO INPUT (Mikrofon, Monitoring, Stimm-Kette)

**Dateien, die ganz gehen** (12):
`Audio/AudioInputManager.swift` · `Audio/MonitorInsertAU.swift` · `Audio/MonitorTapWindow.swift` ·
`Core/FeedbackGuard.swift` · `Studio/AudioInputPickerView.swift` · `Studio/PlugInInvitation.swift` ·
`Studio/VoiceAnalyzer.swift` · `Studio/VoiceCaptureController.swift` ·
`Studio/VoiceCaptureEngine.swift` · `Sequencer/VoicePitchCorrector.swift` ·
`MicrophoneManager.swift` · `Core/VocoderCore`-Reste, soweit nur von diesen gelesen

**Symbole aus gemeinsamen Typen:**
`AudioEngine.setInputMonitoring` / `engageInputMonitoring` / `isInputMonitoring` /
`monitorMixer` / `monitorGate*` / `voiceTune*` / `voiceHarmony*` / `micPermissionDenied` ·
`AudioConfiguration.RecordRouteOwner.inputMonitoring` (⚠️ `RecordRouteOwnershipTests` pinnt
die Menge HART — im selben Commit mitziehen) · der Master-Türknopf „Audio input" ·
`masterDoorButton`-Eintrag · `micMixStrip`.

**⚠️ `AudioEngine.microphoneManager` ist ein `let` im Init.** `AudioEngine(microphoneManager:)`
wird in `EchoelmusicApp:370` gerufen. Der Init ändert sich, also auch jede Testkonstruktion.

---

## Reihenfolge — jede Scheibe muss KOMPILIEREN

**A1** Face-UI: Schalter, `cameraLayerRow`, `FaceChannelsRow`-Montage, Chooser-Eintrag.
**A2** Kameraebene im Renderer + beide Montagen + die sieben `StudioDefault`-Schlüssel.
**A3** Die Quelle: `BioSource.faceCam`, `ModSource`-Gesichtskanäle, OSC-Block, die 8 Dateien.
**B1** Audio-Input-UI: Master-Tür, `AudioInputPickerView`, `PlugInInvitation`, Stimm-Zeilen.
**B2** Monitor-Graph in `AudioEngine` + `RecordRouteOwner` + `FeedbackGuard` + Insert + Tap.
**B3** `MicrophoneManager` + die verbliebenen Dateien + `AudioEngine`-Init.
**T**  Tests: gewidmete Wächter LÖSCHEN, aufzählende Wächter NACHFÜHREN.

**⚠️ Der Unterschied in T ist der ganze Aufwand.** ~32 CISmoke-Dateien nennen `faceCam` oder die
Kameraebene, ~49 nennen Monitor/Input/Voice — aber die meisten sind Wächter ÜBER ETWAS ANDERES,
die den Case nur AUFZÄHLEN (`TheWireSaysWhoseBody`, `AnUnmeasuredChannelReadsNeutral`,
`TheClinicalDetailIsOptIn`). Die werden NACHGEFÜHRT, nicht gelöscht. Gelöscht werden nur die,
deren SUBJEKT Face oder Audio Input ist. Ein Namens-Grep entscheidet das NICHT — jede Datei wird
einzeln gelesen.
