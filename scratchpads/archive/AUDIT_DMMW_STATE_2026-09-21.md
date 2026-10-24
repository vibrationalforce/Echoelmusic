# Ω63 — DMMW-Zustandsbericht (Messung, KEIN Code)

Erstellt 2026-09-21 auf `claude/echoelmusic-review-optimize-u5jjpd`.
Vier parallele Lese-Bahnen plus eigene Nachmessung jeder tragenden Behauptung.
**Kommentare, Scratchpads und Docs sind ABSICHT/HISTORIE — Zustand ist nur, was
konstruiert und ausgeführt wird (Ω3).**

---

## A — HEAD und Merge-Zustand

| Frage | Antwort | Beleg |
|---|---|---|
| Branch | `claude/echoelmusic-review-optimize-u5jjpd` | `git branch --show-current` |
| HEAD | `872b00014` | `git rev-parse HEAD` |
| `origin/main` | `6a202ffc5` (#1433, ADM-OSC-Port) | `git rev-parse origin/main` |
| Existiert `872b00014`? | JA | HEAD selbst |
| Auf diesem Branch? | JA | `git log --decorate` |
| Auf `main`? | **NEIN** | `git branch -r --contains 872b00014` → nur der Feature-Branch |
| Also: unverschmolzener Passagier? | **JA, und korrekt so** | Das Delta ist EINE Datei, `scratchpads/PLAN_WEBRTC_2026-09-21.md`. Scratchpad-only-Commits lösen kein Gate aus und werden nicht automatisch gemerged (#697/#699). |
| `PLAN_WEBRTC_2026-09-21.md` vorhanden? | **JA**, 22.101 B, 412 Zeilen, Abschnitte A–J | `ls -la` |
| Ist er aktuell? | **JA — gegen die heutige Quelle nachgeprüft, nicht neu erstellt (Ω11)** | Sein G-Befund und seine `SignalTransport`-Zählung stimmen mit meiner unabhängigen Nachmessung überein. Eine Präzisierung: er schreibt „`MIDIOutput.send` fächert an jedes CoreMIDI-Ziel" — das ist RICHTIG (`MIDIOutput.swift:782` Schleife über `MIDIGetDestination(i)`), und ZUSÄTZLICH gibt es eine virtuelle Quelle (`:778`). |

**Gate-Lesung nachgeholt (Ω61, kein abgeleitetes Grün):**
`6a202ffc5` → `Xcode Compile Check` Run **35611008867 = success**. `main` ist auf diesen SHA
vorgerückt, also hat auch der CI/CD-Schritt `Build for Testing` gehalten (der #1405-Auto-Merge
pollt genau diesen Schritt). Gate geschlossen.

---

## B — DMMW-Wahrheitsmatrix

Legende: **M**odelliert · **W**ired · **R**eachable · **E**ditable · **A**utomatable ·
**P**ersisted · **D**evice-verified.

| Domäne | M | W | R | E | A | P | D | Der eine Satz, der die Zeile entscheidet |
|---|---|---|---|---|---|---|---|---|
| **MIDI out** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⛔ | Virtuelle Quelle „Echoelmusic" + Fan-out über alle Ziele (`MIDIOutput.swift:778/:782`); Tür = `PatchbayView`; Route `midi.out` default aus. ⛔ **Der Founder hat MIDI-Export am Gerät als DEFEKT gemeldet** („Midi Export geht nicht", `SESSION_LOG.md:10836`) und die Probe steht seither offen (`:10862`). Die Zeile ist damit nicht „unverifiziert", sondern **negativ berichtet**. |
| **MIDI-Datei-Import** | ✅ | ✅ | ❌ | — | — | — | ❌ | `importMIDI()` implementiert (`:11806`), `fileImporter` montiert (`:1661`), `midiImportPresented` hat **keinen Setter**. |
| **MIDI in** | ✅ | ✅ | ✅ | — | ❌ | ✅ | ❌ | `MIDIBusPublisher` → `controllerEvents` → EINE monophone Performer-Stimme. |
| **MIDI 2.0 out** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | `MIDISourceCreateWithProtocol(…, ._2_0, …)` `MIDIOutput.swift:707`, Schalter `midi.out.ump2` in `PatchbayView.swift:311`. ⚠️ **`SignalTransport.midi2.status == .roadmap` ist damit VERALTET** — „roadmap = typed, not wired" trifft nicht mehr zu (`SignalRouting.swift:92`). Folgenlos heute, weil es keinen `midi2`-Port gibt. |
| **MPE out** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | Drei Dimensionen klingen; zwei Opt-ins, beide default aus. **Trägt Bio ohne Egress-Gate — siehe D.** |
| **MPE in** | ⚠️ | ⚠️ | — | — | ❌ | — | ❌ | Parser da, **keine Zonen**; der einzige Verbraucher liest `event.channel` nirgends (#548/#713). |
| **Audio (Spuren/Regionen)** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | `AudioLanePlayer` konstruiert (`EchoelmusicApp.swift:1126`) und vom Transport gefahren — **null Erzeuger**: keine erreichbare Stelle baut eine audio-tragende `TimelineRegion`. |
| **Audio-Aufnahme** | ✅ | ✅ | ❌ | — | — | — | ❌ | `RecordController.arm()` (`:95`) hat **null Aufrufer**; `audioRecorder:` seit #1302 hart nil (kein Mikrofon). Die MIDI-Hälfte funktionierte ab dem ersten `arm()`. |
| **Audio-Export** | ✅ | ✅ | ✅ | — | — | — | ❌ | `SingleExport` (der EINE `AVAssetWriter` im Baum, `mediaType: .audio`). |
| **Automation** | ✅ | ✅ | ⚠️ | ❌ | — | ✅ | ❌ | `AutomationPlayer` spielt persistierte Kurven; **kein Autoren-Pfad** (`addPoint` null externe Aufrufer). Erreichbar ist genau EIN Feld: der `enabled`-Toggle in `AutomationStatusStrip` hinter dem Sound-Chip. Ziele: `masterLevel, tempo, filterCutoff` — alle Audio. |
| **Modulationsmatrix** | ✅ | ✅ | ✅ | ✅ | — | ✅ | ❌ | **Voll doored seit #1250/#1391.** `ModRoute(` wird an genau einer Produktionsstelle gebaut: `PatchbayView.swift:383`. Ziele = `[tempo] + PolySynthVoice.automatableBases`. |
| **Bio** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | Vier Quellen im Chooser (`BioSourceOption`: camera/ble/sim/health). Kamera-rPPG ist die Flaggschiff-Quelle. |
| **Motion** | ⚠️ | ❌ | ❌ | ❌ | ❌ | — | ❌ | `ModSource.motion` existiert mit Label und Range, `hasProducer == false`. **Null Mess-Fähigkeit im Baum:** `CoreMotion`, `Vision`, `ARKit` je **0 importierende Dateien**. |
| **Visual** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | `MetalBioView` an genau 2 Stellen: `FloatingVisualWindow.swift:811`, `ExternalDisplayScene.swift:255`. Tür: Monitor-Kachel im Root + `.field`-Chip. |
| **Animation/Keyframes** | ⚠️ | ⚠️ | ❌ | ❌ | — | ✅ | ❌ | `git grep -in keyframe -- Sources` → **0**. Es gibt nur Automation, und die ist audio-only. |
| **Licht (Art-Net/sACN)** | ✅ | ✅ | ✅ | ✅ | ❌ | ⚠️ | ❌ | Beide Sender live auf der Leitung, Tür = EchoelLux-Kachel → Routing. ⚠️ **Persistenz-Lücke:** Host/Port/Universe persistieren, **`grandMaster`, `fixtureCount`, `fixtureSpacing`, `resolution` nicht** — ein Rig-Setup ist nach dem Neustart weg. |
| **Raum (ADM-OSC)** | ✅ | ⚠️ | ⚠️ | ⚠️ | ❌ | ⚠️ | ❌ | Der EIN-Objekt-Pfad ist live. Der SZENEN-Pfad ist **doppelt türlos**: `streamsScene` default false, einziger Setter in `ImmersiveStageView` — und die hat **null Konstruktionsstellen**. Folge: der Nutzer kann heute kein Raumobjekt platzieren. `SpatialSceneStore` hat **keinen Encoder** — nichts davon persistiert. |
| **Raum-RENDER** | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Sieben Kerne, je null externe Verweise (VBAP, Ambisonics, BinauralPanner, SpaceReverb, BioPhaser, LightFixtureGroup, SpatialAutomationMapping). Real ist die STEUER-Hälfte. |
| **Externer Bildschirm** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | **Realer als die Doku sagt.** `ExternalDisplaySceneDelegate` ist in `Resources/iOS/Info.plist:38-44` als Szene registriert; `ExternalStageBridge.shared.wire(...)` läuft als erste Anweisung des Start-Tasks (`EchoelmusicApp.swift:688`). Tür = HDMI/AirPlay; **keine In-App-Tür nötig und keine vorhanden**. |
| **Video** | ⚠️ | ❌ | ❌ | ❌ | ❌ | ⚠️ | ❌ | `ClipKind.video` existiert, aber `timelineEngineKinds = [.midi]`, und `ClipKind` wird in `Studio/` und `Views/` **null mal** genannt. **Ω25 ist damit bereits erfüllt** — video ist nirgends als benutzbar angeboten. |
| **Mapping** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Null Geometrie, null Warp. Die 13 Treffer sind Prosa über fremde Consumer (Resolume, MadMapper). |
| **Laser** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | `ILDA` → 0. Ein einzelnes `laserEnabled: Bool` in `CrashSafeStatePersistence` — dessen ganzer Container hat null Leser. |
| **Multipeer** | ✅ | ✅ | ✅ | ✅ | ❌ | ⚠️ | ❌ | `LiveColaboView` ist doored. Bio-Egress **korrekt gegated** über `BioPeek.egressible`. **Steht komplett außerhalb des Patchbay-Modells** — kein Port, kein Transport-Fall. |
| **WebRTC** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | `git grep -nEi '\b(webrtc\|RTCPeerConnection\|SDP\|stun:\|turn:)\b' -- Sources` → **0**. (Ein früherer Treffer war `RETURN:` in einem Kommentar — Wortgrenze nötig.) |
| **Broadcast** | ⚠️ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | `Package.swift dependencies: []`. `BroadcastView` null Konstruktionsstellen. Fehlt eine ABHÄNGIGKEIT, keine Tür. |
| **Plugins (AUv3)** | ✅ | ✅ | ✅ | ✅ | ✅ | — | **✅** | Target `EchoelmusicAUv3` (`aumu`/`echl`), eingebettet, 2 Dateien. **Die EINZIGE gerätebestätigte Zeile der Matrix** (AUM, 2026-09-20, #1386): Registrierung, Instanziierung, UI, Grundton 220,15 Hz gegen 220 Hz Soll. ⚠️ **Der MIDI-Noten-Pfad wurde NICHT geprüft — es wurde keine Taste gedrückt** (`FOUNDER_DEVICE_SESSION.md:117-129`); Logic und GarageBand ebenfalls offen. |
| **Plugin-HOSTING** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Mit #121 Slice 2 entfernt, vom Founder gestrichen. Nicht mit der Zeile darüber verwechseln. |

⚠️ **Spalte D ist fast durchgehend ❌, und das ist eine MESSUNG:**
`git grep -c 'VERIFIED-20' -- Sources Tests CLAUDE.md` → **keine Datei**. Das einzige
gerätebestätigte Element im Repo ist der AUv3-Load in AUM.

---

## C — Besitz-Graph

### Der eine Befund, der eine Founder-Regel berührt

**Ω49 sagt „KEINE FÜNFTE WURZEL". Es gibt heute FÜNF, und die fünfte ist die einzige mit Tür.**
Selbst nachgemessen, Datei für Datei:

| # | Wurzel | Ablage | Schreiber | Tür? |
|---|---|---|---|---|
| 1 | `[Clip?]` | AppGroup `Clips/clips.json` | `ClipStore.persist()` | nur indirekt (Generate) |
| 2 | `Arrangement` | AppGroup `Arrangement/song.json` | `ArrangementStore.persist()` | **keine** |
| 3 | `TimelineDocument` | AppGroup `Timeline/timeline.json` | `TimelineStore.persist()` | nur indirekt (Generate) |
| 4 | `AutomationState` | AppGroup `Automation/automation.json` | `AutomationPlayer.persist()` | nur `enabled` |
| 5 | **`[Project]`** | AppGroup `Echoel/projects.json` | `ProjectStore.persist()` | **JA** — `EchoelStudioView.swift:11457/:11506`, Löschen `:9419/:9427`, `LiveColaboView.swift:271` |

`Project` ist **kein Zeiger** in 1–4: es trägt eigene Kopien von Noten, Patch, BPM, Tonart,
Loop-Länge, Mood-Feldern und `rawTake` (`Core/Project.swift:40-200`).
**Konsequenz für die Planung: „keine fünfte Wurzel" ist keine Vorgabe mehr, die man einhalten
kann — es ist eine Konsolidierungs-Aufgabe.** Und Automation liegt gleichzeitig in DREI der
fünf (global, pro Clip, pro Arrangement).

### Zeit — EIN Master, keine Doppelung

`PatternEngine` ist der einzige Typ mit einem Hardware-Timer und die einzige Autorität.
`Transport.setTempo` hat **null Produktions-Aufrufer** — alle sechs Aufrufe stehen in
`PatternEngine.swift`. **`Timebase` ist KEINE zweite Uhr** und sagt das selbst
(`Core/Timebase.swift:4-8`: „⛔ NOT A CLOCK"); es hat null erreichbare Konstruktionsstellen.
**Ω48 ist damit beantwortet: es gibt keine zweite Master-Uhr, und es darf keine geben.**
Sechs Tempo-Quellen, alle über `PatternEngine`: `.user`, `.flowServo`, `.automation`,
`.modulationRoute`, `.remoteControl` — die T1-Aufzählung stimmt.

### Zeitleiste — ZWEI parallele Modelle

`TimelineDocument`/`TimelineLane`/`TimelineRegion` (Ticks, Lanes) **und**
`Arrangement`/`ArrangementSection` (Takte, Kette von `clipID`). Beide modellieren „der Song
über die Zeit", beide referenzieren `ClipStore`, beide haben eigene Datei und eigenen Player,
**keines hat eine Tür**. **Ω21 („keine zweite Zeitleiste") ist bereits verletzt — vor dieser
Sitzung.** `TimelineDocument` ist das jüngere und reichere; `Arrangement` ist der Kandidat
zum Stilllegen, nicht zum Betüren.

### Routing

`SignalGraph` (Wertmodell) + `SignalRouter` (App-Lebenszeit-Halter, persistiert
`signalGraph.routes.v1`). **`SignalTransport` hat 18 Fälle** — unabhängig zweimal gezählt;
die Falle ist das verschachtelte `enum Status { case live, roadmap }` im selben Klammer-
bereich, das eine naive Zählung auf 20 bringt. 12 live / 6 roadmap. 12 deklarierte Ports,
10 davon live.
**`MultipeerSession` kommt in `SignalRouter.swift` und `SignalRouting.swift` NULL mal vor.**
Es gibt keinen Peer-Port und keinen Peer-Transport-Fall.
**Ω5 beantwortet: `SignalGraph` KANN die Relation darstellen** — der Transport-Enum ist heute
schon breiter als das Port-Inventar (`rtpMIDI`, `abletonLink` haben keinen Port). Ein
WebRTC-Fall wäre Nr. 19, kein neuer Graph.
**Ω6 beantwortet: genau zwei Typen heißen `Transport`** — die musikalische Klasse
(`Core/Transport.swift:56`) und `BroadcastPublisher.Transport` (ein Wire-Protokoll-Selektor,
`rtmp`/`srt`, genestet und damit abgeschattet). Plus `SignalTransport`. **Ein dritter
generischer Netz-`Transport` wäre die dritte Bedeutung — das Verbot ist begründet.**

---

## D — Privacy / Egress — **Ω7 BESTÄTIGT**

### Die Kette, selbst nachgemessen

```
PianoRollView.swift:1151   let expression: MPEExpression? = {
:1152                        guard midiOut?.expressionEnabled == true,
                                   let bio = bus?.usableBio() else { return nil }
:1164                        return MPEExpression.from(coherence: bio.coherenceForSound,
                                                       breathDepth: breathSwell,
                                                       hrvNormalized: bio.hrvForSound) }()
:1189                      midiOut?.noteOn(pitch:velocity:expression: noteExpr)
MIDIOutput.swift:778/:782  → virtuelle Quelle UND Fan-out über alle CoreMIDI-Ziele
```

`EngineBus.usableBio()` (`EngineBus.swift:747-753`) filtert **ausschließlich auf Frische** —
`f.source` wird nie geprüft. `BioEgressPolicy` kommt auf dieser Kette **null Mal im Code** vor;
der einzige Treffer in `PianoRollView.swift` ist Zeile 1328 und steht in einem `///`-Block.

### Welche Daten genau

| MIDI-Nachricht | Trägt | Feldklasse |
|---|---|---|
| CC74 (Slide) | `coherenceForSound` | `.derived` |
| Channel Pressure (Press) | Atemphase, zu einem Hügel geformt | `.derived` |
| Pitch Bend (Glide) | `hrvForSound` | `.derived` |

**Nicht betroffen:** Velocity und Notenwahl. Die sind bio-**geformte Musik**, keine Messung —
durch Generierung, Skalenquantisierung und Lane-Gain gelaufen. Sie als Exposition zu führen
wäre eine Übertreibung.

### Was es gated — und was nicht

Drei Default-aus-Schalter: die Route `midi.out`, `midi.out.mpe` (`MIDIOutput.swift:50`),
`midi.out.expression` (`:63`). Der Bio-Chooser bietet **`.health` als echten Eintrag**
(`BioSourceOption.swift:58`). Also: erreichbar, aber nur nach drei bewussten Handlungen.

### Die Schwere, bewusst NICHT aufgeblasen

- Es ist **kein ausgelieferter Leak** — alles hinter Default-aus.
- Die Klasse ist `.derived`, nicht `.clinical`, nicht `.raw`. Die Millisekunden-HRV-Statistik
  ist seit #1292 separat opt-in und **nicht** betroffen.
- Empfänger sind CoreMIDI-Clients; Echoel öffnet selbst keinen Netz-Socket für MIDI.
- **Aber**: 5.1.3 unterscheidet nicht nach Transport, und **drei der vier anderen
  Egress-Flächen sind korrekt gegated** (OSC/ADM/Art-Net/sACN über `OSCSender`, Multipeer über
  `BioPeek.egressible`). MIDI ist die einzige Ausnahme.

### Der Beleg, dass es strukturell übersehen wurde

`Tests/CISmoke/TheWholeEgressSurfaceIsClinicalFreeTests.swift:3` zählt **„exactly ONE of the
six places a bio frame becomes bytes"** und listet: OSC-Batch, ADM-OSC, Art-Net, sACN,
Multipeer, Mod-Tap. **MIDI fehlt.** Es sind SIEBEN. Das ist der #867-Defekt in genau dem
Wächter, der #867 in seinem eigenen Kopf als Gesetz führt.

### Kleinste korrekte Reparatur

`PianoRollView.swift:1152` um eine Klausel erweitern:
`guard …, BioEgressPolicy.allowsEgress(bio.source) else { return nil }`.
**Eine Datei, eine Zeile**, plus ein Wächter und die Korrektur der Sechser-Zählung.
Verhalten bei `.camera`/`.ble`/`.fallback` unverändert.

### Zweiter, SCHWÄCHERER Befund — nicht mitfixen, getrennt entscheiden

Der MIDI-Clock (`EchoelmusicApp.swift:859/:866`) erbt den #1383-Filter **nicht**:
`OSCSender.swift:272-274` hält `/echoelmusic/music/tempo` zurück, wenn die lebende Bio-Quelle
egress-gesperrt ist — genau weil das Tempo unter `.flowFree` dem Puls folgt. CLAUDE.md sagt es
wörtlich voraus: „Die Fail-closed-Eigenschaft gehört EINEM Filter … ein neuer Pfad erbt sie
NICHT." Schwächer, weil zwischen Puls und Clock vier dämpfende Stufen liegen
(`bodyTempoTrustworthy`, Oktav-Faltung, Konvergenz-Kappe, ~2 s Glide).

### Drei Leser ohne Erzeuger, die im selben Zug gemessen wurden

Keiner ist zu löschen (#527: sie lesen persistierte Dokumente älterer Builds), aber sie
gehören in die Karte, weil sie sonst als Fundament gelesen werden:

- `RecordPlan.armedAudioLaneIDs` (`Sequencer/RecordAnchor.swift:100-101`) filtert auf
  `recordSource == .audioInput` — **eine Quellklasse, die #1302 entfernt hat.** Der Zweig
  kann nie wahr werden; `TrackInstrument.audioInput` überlebt nur als Enum-Fall.
- `ControllerEvent.Kind.airCC` — Erzeuger `MIDIBusPublisher.swift:209`, Verbraucher
  `BioReactiveSynthVoice.swift:818 case .airCC: break`. **Veröffentlicht und verworfen.**
- `MPEExpression.merging(bio:override:)` liest `note.mpe`, und `PianoRollModel.setMPE(` hat
  genau EINEN Treffer: die Deklaration. Der Noten-Inspektor, der sie schrieb, ging mit #475.

---

## E — PeerIdentity

**Es gibt keinen Identitätstyp. Die Identität IST ein Anzeigename.**

`MultipeerSession.swift:100-105`:
```swift
let raw = UIDevice.current.name          // iOS; sonst hostName
let id  = MCPeerID(displayName: name.isEmpty ? "Echoelmusic" : name)
```
Dieser String ist der einzige Schlüssel überall: `peerIDs: [String: MCPeerID]` (`:95`),
`DiscoveredPeer.id` (`:36`, Kommentar: „unique enough for a nearby session"),
`peerReadings[…]` (`:313`), Aufräumen per `peerID.displayName` (`:282`).

**Was GUT ist und nicht angefasst werden darf:**
- Apple-Typen lecken **nicht** ins Modell: `DiscoveredPeer` und `ColabPayload` sind
  `Codable`/`Sendable` und String-basiert. `MCPeerID`/`MCSession` bleiben im Adapter.
- Spoofing ist **geschlossen** (#517): `ColabPayload.attributed(to: peerName)` schreibt den
  Absendernamen am Boundary auf den authentifizierten Wert um.

**Der echte Defekt — und er ist NICHT selten:**
`com.apple.developer.device-information.user-assigned-device-name` ist in diesem Baum
**nicht vorhanden** (`grep` über alle `*.entitlements`/`*.plist`/`*.yml` → leer). Ohne diese
Berechtigung gibt `UIDevice.current.name` seit iOS 16 den MODELLNAMEN zurück. Dann heißen
**alle iPhones gleich** — und `peerIDs[name]` überschreibt, `discovered` dedupliziert zu EINER
Zeile, `peerReadings[name]` mischt zwei Körper zu einem. **Drei Telefone sähen einen Peer.**
⚠️ Die Entitlement-Abwesenheit ist gemessen; die iOS-16-Folge ist dokumentiertes
Apple-Verhalten und braucht eine Zwei-Geräte-Probe — das ist eine 30-Sekunden-Prüfung.

**Was Ω8 verlangt vs. was da ist:** `stableID` ❌ · `displayName` ⚠️ (Gerätename, nicht
Künstlername) · `deviceRole` ❌ · `capabilities` ❌.

**Und die Wurzel-Frage ist schon beantwortet (Ω49):** `SessionContext.artistName` ist bereits
persistiert (`echoel.artistName`), nutzer-editierbar und hat eine Nicht-Leer-Invariante. Eine
stabile Peer-UUID gehört **dorthin**, nicht in eine neue Ablage.

---

## F — Workstation-Rückholbarkeit

`doctor --section D` heute: **360** Quelldateien · **302** in `Tests/EchoelmusicTests` ·
**13** Präsentations-Modifier dateiweit (**12** auf der Rumpf-Kette) · `CLAUDE.md` **141.866 B**
von 150.000 → **8.134 B Kopfraum**.

**Der Kopfraum für Flächen ist größer als gedacht: 1 freier Budget-Platz + 2 montierte, aber
unsetzbare Modifier.** UND — der wichtigere Befund: **ein CHIP kostet NULL Budget.** Die
`studioChips`-Liste (`EchoelStudioView.swift:2808`) plus ein `case` in `dropdownContent`
(`:3187`) ist der billige Weg für eine Workstation-Fläche. Modals kosten Budget, Panels nicht.

Render-Kette, exakt: `EchoelmusicApp.swift:563 WorkspaceView()` → `WorkspaceView.swift:244 SurfaceHost()` → `SurfaceSwitcher.swift:70 EchoelStudioView()`.

**Heutige Chips:** Sound · FX · Mix · Master · Mood · Tempo · Field · Save/Export
(+ Bio über die Puls-Pille). **Keiner davon ist eine Zeitleiste, ein Clip-Grid, eine
Spurenliste oder ein Recorder. Ω17/Ω18 beantwortet: es gibt heute KEINE Workstation-Tür**,
außer man liest `PatchbayView` als eine — und das ist die einzige genuin
workstation-förmige Fläche, die ausgeliefert wird.

**Rangliste nach Wert je berührter Datei:**

| Rang | Was | Fehlt | Dateien | Anmerkung |
|---|---|---|---|---|
| 1 | **Ein Play-Knopf auf `timelinePlayer`** | EIN `play(`-Aufruf | 1–2 | `timelinePlayer.play(` hat **null** Aufrufer (selbst nachgemessen). Darunter liegen `TimelineRegionPlayer` + `AudioLanePlayer` + `TimelineStore` + `TimelineAudioSink`, alle verdrahtet, alle im Leerlauf. Die größte schlafende Maschine im Baum. |
| 2 | **Aufnahme-Arm** | ⚠️ **ZWEI Auslöser, nicht einer** | 2–3 | Korrigiert nach Nachmessung: `RecordController.arm()` (`:95`) hat null Aufrufer **UND** `TimelineStore.toggleArm(id:)` (`:505`) hat null Aufrufer — eine Spur kann heute gar nicht scharfgestellt werden. MIDI-Spur-Aufnahme läuft, sobald beide da sind. Audio bleibt tot (kein Mikrofon). |
| 3 | `midiImportPresented = true` | EINE Zeile | 1 | Der `fileImporter` ist bereits montiert (`:1661`), `importMIDI()` implementiert (`:11806`). Kollateralschaden des Tools-Grid-Abbaus, **keine** Founder-Entscheidung. |
| 4 | `ImmersiveStageView` betüren | eine Präsentationsstelle | 1 (+1 Slot) | Entsperrt den GESAMTEN Raum-Bereich: Objekt-Platzierung, Szenen-Stream, IEM-Dialekt. `ADMStreamStatusLine` kommt gratis mit. ⚠️ Ship-Gate 4 parkt es absichtlich. |
| 5 | Timeline-/Clip-/Automations-AUTOREN-UI | eine echte neue Fläche | 2–3 je | Die Modelle sind vollständig; es fehlt der Editor. |

**⛔ Zwei Korrekturen an der Bahn-Rangliste, die ich NICHT ungeprüft weitergebe:**
1. `showMeditation = true` wurde als „eine Zeile, großer Gewinn" geführt. **CLAUDE.md sagt
   ausdrücklich: MeditationView ist türlos, „Founder: bewusst so".** Das ist eine
   Founder-Entscheidung, kein vergessener Setter. Nicht anfassen.
2. `ArrangementStore`/`ArrangementPlayer` **nicht** betüren — das wäre das ÄLTERE der zwei
   Zeitleisten-Modelle (siehe C).

---

## G — Live-Performance-Fundament

Alles, was Ω31/Ω32 verlangt, existiert schon als Maschine:

| Ω31-Teil | Bestehender Besitzer | Zustand |
|---|---|---|
| INPUT | `SignalRouter` Quell-Ports + `BioSourceOption` | live, doored |
| ROUTING | `SignalGraph` + `PatchbayView` | live, doored, persistiert |
| MODULATION | `ModulationEngine` + `ModRoute` | live, doored seit #1250 |
| STATUS | `NetworkActivityDot`, `AutomationStatusStrip`, `EchoelLuxMonitorMini` | live |
| OUTPUT | OSC · ADM · Art-Net · sACN · MIDI · Visual · Externer Bildschirm | live |
| **SCENES** | **nichts** | ⛔ die einzige echte Lücke |

**Ein Live-Modus braucht also KEIN neues Routing-Konzept — er braucht Szenen (Snapshots), und
die haben heute keinen Besitzer.** Ω49 beißt hier sofort: ein Szenen-Store wäre Wurzel **sechs**.
Der ehrliche Vorschlag ist, Szenen als Feld einer BESTEHENDEN Wurzel zu führen — `Project` ist
der natürliche Kandidat, weil es bereits die einzige Wurzel mit Tür ist. **Das ist eine
Founder-Architekturentscheidung, keine Sitzungsentscheidung.**

---

## H — Motion Control 2.0 — Einfügenaht (kein Code)

**Die Kontrollschicht existiert bereits und heißt `ModSource` → `ModRoute` → `ModulationMatrix`.**
`ModSource.motion` ist da, mit Label, Range und `hasProducer == false`. Die Naht ist **ein
Erzeuger**, nicht eine neue Schicht.

Ω28-30 verlangt CONTINUOUS/EVENT/STATE plus „Null ist nicht unbekannt". Beides existiert
teilweise: `ModSource.isMeasured` trennt gemessen von Default — und sein Doc trägt bereits das
#1301-Gesetz: **ein Kanal, dessen neutrale Messung eine echte 0 ist, kann nicht über seinen
eigenen WERT gegatet werden, er braucht die PROVENIENZ des Frames.** Was fehlt: pro Kanal
`timestamp` und `confidence`.

**Was NICHT aus der Historie zurückgeholt werden darf (Ω1, ausdrücklich):** die #1301-Löschung
— `FaceExpressionBioPublisher`, `BodyPoseAnalyzer`, `FaceExpressionMapping`, `FaceTrackingRate`,
`BodyPoseMath`, `FaceChannelsRow`, `CameraFrameSlot`, `BioSource.faceCam`, die 17 Gesichts-/
Kopf-/Körperfelder, die 17 `ModSource`-Kanäle, `FXModPreset`, `/echoelmusic/gesture/*`, die 13
Kamera-Uniforms, `FeatureFlags.cameraExpression`, `BioSourceOption.face` und die zwölf Wächter.
Motion 2.0 kommt **generisch** zurück oder gar nicht.

**Plattform-Fähigkeit, gemessen:** `CoreMotion` **0** Dateien, `Vision` **0**, `ARKit` **0**.
Motion 2.0 braucht also einen **neuen Framework-Import**. Das ist keine Abhängigkeit (Apple,
kostenlos), aber es ist eine neue Fläche und braucht die ausdrückliche Founder-Freigabe, die
Ω33-38 darstellt.

⚠️ **Und ein bereits bezahltes Gesetz gilt sofort wieder:** #1298/#1300 — **ein Schalter in
einer Visual-Fläche darf das Instrument nicht starten.**

---

## I — WebRTC-Voraussetzungen

| Voraussetzung | Zustand |
|---|---|
| Transport-Abstraktion | ✅ `SignalTransport` (18 Fälle); ein WebRTC-Fall wäre Nr. 19 |
| Peer-Begriff | ❌ existiert nicht (E) — **die eigentliche Lücke** |
| Peer als Routing-Ziel | ❌ Multipeer ist unsichtbar für den Router |
| Zeit-Autorität geschützt | ✅ `PatternEngine` ist einzige Autorität, `TempoSource` ist der Erzwingungspunkt |
| Egress-Policy vollständig | ⛔ **NEIN** — siehe D. Ein zweiter Transport würde die Nicht-Vererbung erben |
| Provenienz-Träger | ❌ pro Transport neu erfunden; MIDI, ADM-OSC und Art-Net tragen keine |
| Lizenz/Abhängigkeit geklärt | ⛔ **NICHT MESSBAR HIER** — `webrtc.googlesource.com` ist vom Egress-Proxy blockiert (`EGRESS_BLOCKED`). Aus dem Gedächtnis zu antworten hat der Founder ausdrücklich verboten. |

**Ω13-Beweisscheibe bleibt richtig dimensioniert:** DataChannel, nur PeerIdentity +
Capability-Handshake + Ping + Timestamp. Kein Bio, kein Audio, kein Video, kein Projekt-Sync.

---

## J — TestFlight-Vorschlag: FÜNF Scheiben

### S1 — MPE-Ausgang konsultiert die Egress-Policy *(unsichtbar, Korrektheit)*
Nutzerwert: keiner sichtbar — eine Compliance-Lücke schließt sich · Wiederverwendet:
`BioEgressPolicy.allowsEgress(_ source:)` · Dateien: `PianoRollView.swift` + 1 Wächter + die
Sechser-Zählung im Zensus-Wächter · Neues Modell: nein · Persistenz: keine · Realtime: keine
(MainActor-Tick) · Accessibility: keine · Geräteprobe: nicht nötig (Verhalten bei den drei
eigenen Quellen bit-identisch) · Rollback: eine Klausel entfernen.

### S2 — `PeerIdentity` mit stabilem Schlüssel *(Reparatur, nicht Abstraktion)*
Nutzerwert: **zwei iPhones sehen sich als zwei Geräte statt als eines** · Wiederverwendet:
`SessionContext` (persistierte UUID + `artistName`), `ColabPayload.attributed(to:)` ·
Dateien: `SessionContext.swift`, `ColabPayload.swift`, `MultipeerSession.swift` · Neues Modell:
**ja, ein kleiner neutraler Werttyp** — aber **keine neue Wurzel** (Ω49) · Persistenz: ein Feld
in einer bestehenden Ablage · Realtime: keine · Accessibility: Peer-Zeilen bekommen
unterscheidbare Namen · Geräteprobe: **ja, zwei Telefone** · Rollback: der alte Schlüssel
bleibt als Anzeigename.

### S3 — Die Workstation-Tür: ein neunter Chip *(sichtbar, Ω17/Ω18)*
Nutzerwert: **eine offensichtliche Handlung führt zur Zeitleiste** · Wiederverwendet: die
Chip-Mechanik (**null Modal-Budget**), `TimelineStore`, `TimelineRegionPlayer` · Dateien:
`EchoelStudioView.swift` + eine neue Panel-Datei · Neues Modell: **nein — ausdrücklich
`TimelineDocument`, nicht `Arrangement`, und keine byte-für-byte-Wiederherstellung der
gelöschten Arrange-UI** · Persistenz: schreibt in Wurzel 3 · Realtime: keine · Accessibility:
neue Fläche ⇒ volle Labels, keine Tempo-/Sync-Zusage ohne Code-Beleg (Ω59) · Geräteprobe: ja ·
Rollback: einen Array-Eintrag entfernen.

### S4 — Der Play-Knopf auf der Zeitleiste *(die schlafende Maschine aufwecken)*
Nutzerwert: **eine erzeugte Passage spielt von der Zeitleiste** · Wiederverwendet: alles —
es fehlt genau ein `play(`-Aufruf · Dateien: 1–2 · Neues Modell: nein · Persistenz: keine ·
Realtime: `TimelineRegionPlayer` startet `PatternEngine` (`:300`), also **muss T1/T2 gelten**:
die Play-Ursache ist bereits `PlayCause.timelineRegion`, der Fall existiert und ist heute als
unerreichbar annotiert · Accessibility: ein Knopf, ein Label · Geräteprobe: ja · Rollback:
trivial.

### S5 — Licht-Rig-Einstellungen überleben den Neustart *(kleiner, echter Ärger)*
Nutzerwert: `grandMaster`/`fixtureCount`/`fixtureSpacing`/`resolution` bleiben erhalten —
heute ist ein Rig-Setup nach dem App-Neustart weg, während Host/Port es überleben ·
Wiederverwendet: `persistTarget`-Muster in beiden Sendern · Dateien: `ArtNetSender.swift`,
`SACNSender.swift` (+Wächter) · Neues Modell: nein · Persistenz: UserDefaults-Skalare, **keine
neue Wurzel** · Realtime: keine · Accessibility: keine · Geräteprobe: nur die Wirkung, nicht
der Code · Rollback: `didSet` entfernen.

---

## K — Ausführungsreihenfolge

**0.** S1 (Egress) — Ω53 sagt es ausdrücklich: **vor** WebRTC, vor Motion-Egress, vor neuer
Fernsteuerung. Unsichtbar, eine Zeile, heute billig und morgen teuer.
**1.** S2 (PeerIdentity) — Voraussetzung für alles Netz-Seitige UND eine Reparatur für sich.
**2.** S3 (Workstation-Tür) — die sichtbare TestFlight-Scheibe.
**3.** S4 (Play) — macht S3 nützlich statt nur sichtbar. Kann mit S3 zusammenfallen, ist aber
eine eigene Ausfall-Geschichte und bleibt deshalb getrennt.
**4.** S5 (Licht-Persistenz) — unabhängig, jederzeit einschiebbar.

**Ω52 ehrlich neu gerankt, wie erlaubt:** Der Founder erwartete „4 Audio-Import → Region →
Playback" vor „5 Region-Editing". Gemessen ist **Playback von MIDI-Regionen zu ~95 % gebaut und
fehlt nur ein Aufruf**, während Audio-Regionen **keinen Erzeuger** haben (kein Mikrofon seit
#1302, `RecordController.arm()` ohne Aufrufer). Also: **MIDI-Region-Playback zuerst**,
Audio-Import danach als eigene Scheibe.

---

## L — Ausdrückliche Zurückstellungen

- **WebRTC-Code jeder Art** — Ω12 plus die zwei offenen Founder-Fragen (H: C++/Abhängigkeits-
  doktrin; D: roh vs. SFU-SDK). Lizenz **nicht verifizierbar** in dieser Umgebung.
- **Motion Control 2.0** — braucht einen neuen Framework-Import und damit eine Freigabe.
- **Video 2.0, Mapping, Laser, 360, XR** — null Fundament; jede wäre eine ganze Domäne.
- **Konsolidierung der fünf Wurzeln** — die größte Architekturschuld im Baum und ausdrücklich
  Founder-Gebiet.
- **Szenen / Live-Modus** — die eine echte Lücke in G, blockiert an der Wurzel-Frage.
- **`.deploy/release`** — nicht anfassen (#1151).
- **`ArrangementStore`/`ArrangementPlayer` betüren** — falsches Modell.
- **`showMeditation`** — Founder-Entscheidung, nicht vergessener Setter.
- **`SignalTransport.midi2.status`** — der Wert ist veraltet, folgenlos (kein Port).
  Registriert, nicht mit einer Scheibe gebündelt.

---

## Eine gemeldete Falschstelle, die ich GEPRÜFT UND VERWORFEN habe

## Eine gemeldete Falschstelle — und meine eigene Prüfung davon war ZU SAUBER

Eine Lese-Bahn meldete die CLAUDE.md-Passage über die Modulationsmatrix (#541, `CLAUDE.md:80`)
als veraltet, weil `PatchbayView.swift:383` heute ein lebender Erzeuger ist. Mein erster
Prüfbefund war „nicht veraltet" — und **auch der war falsch.** Beides war halb richtig, also
steht hier die ganze Messung:

Die Zeile beginnt korrekt mit „⭐ **ERLEDIGT mit #1250:** … der Eintrag bleibt als Herleitung".
Die Rücknahme ist also da. **Aber die Herleitung darunter steht im PRÄSENS:** „Gemessen fehlt
die ROUTE … liefert **genau EINEN** Treffer … **Null Produktions-Konstruktionsstellen**."
Diese drei Sätze sind heute schlicht falsch, und sie stehen NACH der Korrektur, in der Datei,
die eine Sitzung als Erstes liest.

**Der Defekt ist die ZEITFORM, nicht die fehlende Rücknahme** — genau die Sorte, die diese
Datei an anderer Stelle selbst benennt: eine Korrektur, die die alte Messung als Gegenwart
stehen lässt, liest sich beim Überfliegen wie die Gegenwart. Registriert als eigene kleine
Scheibe (Präsens → Vergangenheitsform, ein Absatz), **nicht mit S1–S5 gebündelt** und nicht
ungefragt in eine immer-geladene Datei geschrieben. Kopfraum dafür ist da: 8.134 B.
