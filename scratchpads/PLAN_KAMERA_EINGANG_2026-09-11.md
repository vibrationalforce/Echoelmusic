# PLAN — Kamera als Instrument-Eingang (Gesicht · Körper · Video-Layer), 2026-09-11

Founder-Prompt (Upload `PROMPT_KAMERA_EINGANG.md`, 2026-09-11): Frontkamera → benannte, normalisierte
Modulationssignale für Klang/Charakter/Visual + Kamerabild als Textur-Layer. Kein Recorder, keine
Abhängigkeit, kein Netz, kein taktgenaues Triggern. Reihenfolge des Prompts: 1 Besitzer/Moduswechsel ·
2 Blendshapes→Kanäle+Kalibrierung, nur Zahlen · 3 EIN hörbares Mapping · 4 Matrix+Presets+OSC ·
5 Textur-Layer · 6 Körper/Hände · 7 Segmentierung.

## 0. Vorgefunden (gemessen, read-only, vor dem Entwurf — der Prompt verlangt das)

| Prompt nimmt an | Repo hat wirklich | Folge für den Plan |
|---|---|---|
| Greenfield: ARKit-Pfad bauen | **`Bio/FaceExpressionBioPublisher.swift` (187 Z.) + `Core/FaceExpressionMapping.swift` (145 Z.) EXISTIEREN** seit 2026-07-18 (A5): `ARSession`+`ARFaceTrackingConfiguration`, Delegate → Lock-Blatt (kein Actor-Hop pro Frame), 10-Hz-Drain, EMA, `.faceCam`-Frames mit `faceSmile/faceBrowRaise/faceJawOpen`. **0 Konstruktionsstellen** (`git grep -n "FaceExpressionBioPublisher(" -- Sources` → 0), Register-Eintrag #1002, Wächter `TheFaceSourceHasNoDoorTests` (#364: verbietet das Verdrahten nicht) | Scheibe 1 ist eine TÜR, kein Neubau; Scheibe 2 baut auf `FaceExpressionMapping` auf |
| Matrix Quelle→Ziel bauen | **`ModSource.faceSmile/.faceBrow/.faceJaw` existieren** (Range, `isMeasured` = Provenienz `.faceCam`), `hasProducer` = `false` mit Doc „the day it is constructed, flip these to true in the same commit". Matrix-Fläche seit #1250 (`PatchbayView.modulationSection`, `ModRoute` persistiert, Kurve/Depth vorhanden). FX-Bio-Mod (`FXModCarrier.allChoices = allCases.filter(\.hasProducer)`, Carrier/Target/Curve/Depth, Tür `showAllFX`) | `hasProducer → true` in Scheibe 1 macht Smile/Brow/Jaw sofort als FX-Carrier routbar = das „eine hörbare Mapping" ohne neue UI |
| Kamera-Besitzer bauen | **EIN Besitzer existiert: das Quellen-Dropdown** (`startBioSource`/`stopBioSource`/`selectBioSource`, `BioSourceKind` ⟷ `BioSourceOption {camera, ble, sim}`, Hot-Swap mit Drain der in-flight-Starts). rPPG = einzige `AVCaptureSession` (Rücklinse, Torch). ARKit hält die Frontkamera exklusiv | Gesten-Modus = VIERTER Eintrag im selben Dropdown; die Exklusivität rPPG↔Face ist dort bereits Gesetz (decisions.csv:48, 2026-06-01) |
| Frame ohne Puls stört den Klang | Konsumenten HALTEN: `measured(frame.heartRateBPM) ?? heldBody ?? 70`, `coherenceForSound` = 0,5 neutral, `hrvForSound` 0,5; Tempo-Servo sieht nie die 0 | Face-Frames mit HR 0 sind sicher. ⚠️ Offen: Health-autorisierte Nutzer — der Wrist-Publisher (#1015) schreibt alle 4–5 s ein `.healthKit`-Frame in denselben Slot; `FXBioModulator` schaltet Face-Routen dann für ≤100 ms auf „unmeasured" (FXRouteFade 0,25 s) → periodischer Dip. **Scheibe 3 löst das** (Konsumenten-Hold über das Freshness-Fenster der Quelle) |
| Visual bekommt Texturen | `MetalBioView` liest NUR Uniforms (`#1244`: „no textures" ist die Prämisse des GPU-Skip); Uniform-Layout wird byte-weise von Hand gespiegelt; `VisualRecorder` hat schon `CVMetalTextureCache`. Kein `import Vision`, kein `capturedImage`-Leser | Scheibe 5 muss den #1244-Skip um „neue Textur da?" erweitern und BEIDE Uniform-Deklarationen in EINEM Commit bewegen |
| `/echoel/gesture/<kanal>` | Namensraum im Repo ist `/echoelmusic/...`; `/bio/synthetic`-Gesetz, Egress gated `BioEgressPolicy.allowsEgress(.faceCam)` = true | Adresse wird `/echoelmusic/gesture/<kanal>` (Prompt-Abweichung, begründet: ein Namensraum) |
| `NSCameraUsageDescription` | nennt NUR die Rücklinse/Finger; `project.yml` trägt keine Kopie. Info.plist ist founder-gated — **der Prompt IST die Founder-Anweisung** („in einem Satz und ehrlich") | Scheibe 1 verbreitert den EINEN Satz; im Commit als Prompt-Autorisierung benannt |
| Flag | `FeatureFlags.cameraExpression` = ungelesen, Doc „one-line enable lever once wired"; `EveryFlagSaysWhatItGatesTests` pinnt genau drei registrierte + elf ungelesene | Tür wird NICHT über das Flag gegated, sondern über `isSupported` (Gerätefähigkeit). Flag bleibt ungelesen, Doc wird ehrlich („nie der Hebel geworden") — spart vier Prosa-Stellen und ein Wächter-Umbau |
| Thermik | `ResourceGovernor` (thermal/battery/FPS → `QualityTier minimal…high`), `CameraCapture` liest `thermalState` | Scheibe 5/6 hängen an den Tier, nicht an eigene Schwellen |
| Research | `RESEARCH_BODYVIBE_CAMERA_2026-07-17.md` SYNTHESE: Stufe 1 Vision-Face, Stufe 2 ARKit exklusiv (Puls derweil vom Gurt), Stufe 3 Body-Pose → `motionEnergy` (+ `MotionPeakDetector` der Triade GRATIS) | Scheibe 6 füllt `motionEnergy` aus Vision-Body — der reservierte, leere Kanal (#215) bekommt einen Produzenten |

Abweichung vom Prompt, ausdrücklich: „Berechtigung entzogen/verweigert" ist im Publisher heute NICHT
behandelt (kein `didFailWithError`, kein `sessionWasInterrupted`) — Scheibe 1 trägt es nach.

## 1. Council (fast, sechs Sitze) — Verdikt

- Architect: die Tür ist der vierte Dropdown-Eintrag; kein zweiter Lifecycle-Besitzer (BLE-3-Klasse).
- DSP Purist: Kanäle bleiben Kontrollrate (10 Hz Drain, EMA); Render-Thread liest nur SPSC/atomar — unverändert.
- Vision-Keeper: Ausdruck als STEUERSIGNAL, nie Emotion (EU-AI-Act-Kopf bleibt Pflicht); „Play with your face" statt Wellness.
- Shipper: 7 Scheiben, jede CI-kompilierbar; Textur-Layer (5) ist die einzige, die den Visual-Kern anfasst → eigener Deploy.
- Skeptic: KEIN Gerät hier — jede Scheibe endet mit `NEEDS-FOUNDER-VERIFY`; Uniform-Layout und Metal-Shader können nur am Gerät bestätigt werden.
- User-Advocate: Geräte ohne TrueDepth sehen den Eintrag NICHT (`isSupported`), statt einen toten Eintrag.
**Gate: proceed.** Founder-gated bleibt: der Info.plist-Satz (Prompt = Autorisierung, im Bericht benannt) und der Vision-Fallback-Pfad ohne TrueDepth (Scheibe 6b, erst nach Gerätprobe des ARKit-Pfads).

## 2. Scheiben

**Stand 2026-09-11 11:00 UTC (#1268 `7dcf618` = Review-Fixes: Freeze-Wächter kennt die Face-Quelle, `availableTrackingRates` als `let`, `import ImageIO`; Compile-Lauf jetzt auf `7dcf618`; Build for Testing grün auch für K5a/K5b (6024/6025)).** Vorher: K1 `0f5212f` · K2 `ebc1f98` · K3 `d2fe686` · K4a `4f87ba3` · K4b `8e335f9` · K5a `5bbec8d` · K5b `a507c72` · K6a `b8b8d0c` · K7 `e8d003c` · K6c `7c8c0e8` · K7b `f7b594f` gepusht — alle sieben Prompt-Scheiben gebaut. Compile Check grün bis K5b (#2560), Build for Testing grün für K1/K2/K3/K4a/K4b (6019–6023); K6a–K7b: Compile-Lauf auf `f7b594f` lesen. Bewusst offen: 6b-Fallback ohne TrueDepth (Gerätesondierung zuerst), Gerät-Verify aller NEEDS-FOUNDER-VERIFY (`python3 scripts/founder-verify.py --since 1438077`), FEATURE_MATRIX-Zeile nach dem ersten Build. OSC-Namensraum `/echoelmusic/gesture/` (Prompt: `/echoel/`); Segmentierung `.personSegmentation` statt `…WithDepth`.

**K1 — Tür + Besitzer (dieser Zyklus, #1257).** `BioSourceOption.face` (Label „Play with your face — front camera, no pulse"), `BioSourceKind.face`, `startBioSource`/`stopBioSource`, Publisher konstruiert in `EchoelmusicApp` + `.environment`. `offered` filtert über `FaceExpressionBioPublisher.isSupported` (nonisolated). `hasProducer` Face → true. Publisher: `didFailWithError`/`sessionWasInterrupted` → `lastError`, Stop; Kopf aktualisiert. Info.plist-Satz verbreitert. Wächter: `TheFaceSourceHasNoDoorTests` → `TheFaceSourceHasADoorTests`; `TheBioSourceChooserHasOneDefinitionTests` (Set/Count/Needles). CLAUDE.md-Register #1002 → erledigt. Verify: Moduswechsel Puls↔Face zehnmal, kein Absturz; Kanäle erscheinen als FX-Carrier.
**K2 — Kalibrierung + Deadzone + Zahlen.** `FaceCalibration` (3 s neutral → Baseline/Spannweite je Kanal), Deadzone+Hysterese in `FaceExpressionMapping`; Zahlen-Blatt im Bio-Panel (eigene Leaf-View, Freeze-Gesetz); Kalibrier-Knopf. Verify: ruhiges Gesicht ⇒ ruhige Zahlen.
**K3 — Signalverlust als Zustand + Konsumenten-Hold.** Gesicht weg → Kanäle über ~300 ms nach 0, dann Stille; Fremd-Frame (Wrist) → Face-Werte im FX-Modulator gehalten bis Freshness-Fenster. Verify: kein Knack, kein 5-s-Dip.
**K4 — Kanäle · OSC · Presets.** Kopf (yaw/pitch/roll/distance aus `ARFaceAnchor.transform`), `eyeBlink`, `browDown`, `eyeSquint`, `mouthPucker`, `cheekPuff` als Frame-Felder + `ModSource`-Cases (am Ende, persistenz-sicher); `/echoelmusic/gesture/<kanal>` in `OSCSender` (Batch, synthetic-Gesetz); 2–3 Routen-Presets.
**K5 — Kamerabild als Layer.** `ARFrame.capturedImage` → Lock-Blatt → `CVMetalTextureCache` (Y + CbCr, Konvertierung im Shader) → `MetalBioView` Layer (Deckkraft, Blend, Spiegelung); #1244-Skip erweitert; Tier-Rückbau (Auflösung). 5a Feed+Textur ohne Zeichnen, 5b Shader.
**K6 — Körper/Hände (Vision auf `capturedImage`,** eigene Queue, Drop-Strategie) → `handHeightL/R`, `handDistance`, `shoulderTilt`, `bodyPresence`, und `motionEnergy` bekommt seinen Produzenten. 6b: Fallback ohne TrueDepth (`AVCaptureSession`+`VNDetectFaceLandmarksRequest`) — nach Gerätprobe.
**K7 — Segmentierung** (`personSegmentationWithDepth`, nur wo verfügbar; sonst ausgegraut).

Latenz-Regel (16–33 ms + Glättung): Modulation ja, Trigger nein — keine UI-Formulierung, die Trigger nahelegt.
`FEATURE_MATRIX.md` bekommt die Zeile erst, wenn ein Build läuft (Prompt-Regel); CLAUDE.md-Register sagt ab K1 nur „Tür da, Gerät unbestätigt".
