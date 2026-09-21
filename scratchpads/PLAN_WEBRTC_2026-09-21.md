# WebRTC — Architektur-Audit (KEIN Code)

**Founder-Auftrag 2026-09-21:** WebRTC gehört strategisch in Echoelmusic, aber als
**Transport-/Session-Adapter**, nicht als neue Autorität für Audio, Zeit, Projekt oder
Kollaboration. *„First audit, then implementation. Do NOT add WebRTC yet."*

Methode: drei parallele read-only Bahnen, jede Zahl kommentar-gestrippt
(`| grep -v ': *//'`) und nach TYP gemessen, nie nach Dateiname. Wo Prosa und Code sich
widersprechen, steht beides. Die drei schwersten Befunde habe ich selbst nachgemessen,
statt den Bahnen zu glauben.

---

## A — Besitz-Karte: was heute existiert

### Es GIBT bereits eine Transport-Abstraktion, und sie ist live, typisiert und persistiert

`Core/SignalRouting.swift` + `Core/SignalRouter.swift`:

| Typ | Was |
|---|---|
| `SignalKind` | 11 Fälle, jeder mit `isLive` |
| `SignalTransport` | **18** Fälle, jeder mit `Status { live, roadmap }` |
| `SignalPort` | `id, name, kind, direction, transport` |
| `SignalRoute` | `+ enabled, amount, converterID`, toleranter `init(from:)` |
| `SignalGraph` | `upsert/connect/disconnect/check/restore/hasEnabledRoute(toSink:)` |
| `SignalConverter` / `ConverterCatalog` | 10-Einträge-Default |

`SignalRouter` wird beim App-Start konstruiert, persistiert unter `signalGraph.routes.v1`,
Tür ist `PatchbayView`. **`applyRouting()` ist die Arm-Instanz:** jeder Netz-Sender startet
nur auf `hasEnabledRoute(toSink:)`. Beim Erststart gibt es KEINE Route — **jeder
Netz-Sender ist aus, bis der Nutzer patcht.**

⭐ **Konsequenz: ein WebRTC-Transport ist hier ein Enum-Fall plus ein, zwei Ports plus ein
`applyRouting`-Zweig — keine neue Schicht.** Die „Sender nur online, wenn etwas auf ihn
geroutet ist"-Lebenszyklus-Logik existiert bereits.

### ⛔ Aber `MultipeerSession` steht KOMPLETT AUSSERHALB davon

Gemessen: null Vorkommen in `SignalRouter.swift`/`SignalRouting.swift`, null in
`applyRouting`. Es ist kein Port, kein Transport-Fall. `SignalTransport` hat **keinen**
Fall für Peer-to-Peer, AWDL oder etwas WebRTC-Förmiges. **Heute kann nichts Bio oder Musik
ZU EINEM PEER routen, so wie es zu OSC/Art-Net routet.**

Was `MultipeerSession` besitzt: `MCSession`, `MCPeerID`, Advertiser, Browser, `peerIDs`,
`discovered`, `connectedPeerNames`, `peerReadings`, `incoming`, `pendingInvitation`,
`status`, `isLive`. Genau EIN Lifecycle-Besitzer: das `LiveColaboView`-Sheet
(`start()` am Knopf, `stop()` in `.onDisappear`). Es ist **nicht** türlos — die Tür ist
`quickDoorRow` → Sheet, und die Kette bis zum App-Home ist gemessen.

### Was es NICHT gibt — benannt, nicht umschrieben

- **Keine Session-Abstraktion.** `MultipeerSession` *ist* die Session, konkret, mit
  MC-Typen in den Stored Properties und `#if canImport(MultipeerConnectivity)` um die ganze
  Datei. Es gibt nichts, wogegen man konformieren könnte.
- **Kein Peer-Identity-Typ.** `DiscoveredPeer` ist ein `String`-Wrapper (`var name: String { id }`).
- **Kein Capability-/Permission-Protokoll.** Was existiert (`BioEgressPolicy`,
  `HealthWritePolicy`, `ProGate`, `OnDeviceModelGate`) sind konkrete Enums, nicht komponierbar.
- **Keine Empfangs-Abstraktion.** `NetworkSendActivity` ist die EINZIGE Sender-Abstraktion
  und hat **kein `send`** — sie abstrahiert Beobachtbarkeit (`isActive`, `lastSentTimestamp`).
- **Keine Signalisierung, keine Nicht-LAN-Discovery.** Null `NWBrowser`, null WebRTC-Symbole,
  null STUN/TURN. ⚠️ Ein naives `grep -i "turn:"` liefert EINEN Treffer — das ist `RETURN:`
  in einem Kommentar. Mit Wortgrenze: null.
- **Keine Clock-Sync.** Ausdrücklich abwesend und im Code dokumentiert.

### Eine Identitäts-Lücke, die den Founder direkt betrifft

Peer-Identität ist ein nackter `String` aus `UIDevice.current.name`. Auf iOS 16+ liefert das
ohne das `user-assigned-device-name`-Entitlement schlicht `"iPhone"` — **drei Telefone in
einem Raum sind drei Peers namens „iPhone" und kollabieren in EINE `peerReadings`-Zeile.**
Der Code weiß das und führt es als offenen Defekt. `SessionContext.artistName` existiert,
ist persistiert, und der Netz-Layer liest ihn nie.

⭐ Was schon richtig gelöst ist: `ColabPayload.attributed(to:)` **überschreibt den vom
Sender behaupteten Namen mit dem transport-authentifizierten `MCPeerID.displayName`**.
Autorität ist gelöst; Identität nicht.

---

## B — Widersprüche und Doppel-Wahrheits-Risiken

### B1 — Drei Bedeutungen von „Transport"

| Name | Bedeutet | Datei |
|---|---|---|
| `Transport` | die **musikalische** Uhr (play/stop/tempo/position) | `Core/Transport.swift` |
| `SignalTransport` | das **Netz**-Transportmittel | `Core/SignalRouting.swift` |
| `BroadcastPublisher.Transport` | rtmp/srt | `Stream/BroadcastPublisher.swift` |

Jede WebRTC-Benennung muss das umgehen. Ein `WebRTCTransport` neben `Transport` ist die
teuerste mögliche Namenswahl in diesem Baum.

### B2 — Die Zwei-Besitzer-Falle, schon einmal bezahlt

`blehrs.in` dokumentiert: `applyRouting` als ZWEITER Lifecycle-Besitzer killte einen über
die UI gestarteten BLE-Gurt mitten in der Performance (BLE-3, 2026-07-15). Die Reparatur war,
die Kopplung zu ENTFERNEN. **`MultipeerSession` in `applyRouting` zu hängen, ohne den
Sheet-`start`/`stop` zu entfernen, reproduziert den Defekt exakt.**

### B3 — Was eine WebRTC-Schicht duplizieren WÜRDE, wenn sie eigene Typen mitbringt

`SignalTransport`/`SignalPort`/`SignalGraph` (Transport-Wahrheit) · `BioEgressPolicy`
(Egress-Wahrheit) · `PatternEngine`/`Transport` (Zeit-Wahrheit) · `ColabPayload`/`BioPeek`
(Draht-Format) · `PeerReading` (Staleness) · `NetworkSendActivity` (Status-Vokabular) ·
`Project` (Teil-Einheit).

### B4 — Tote Platzhalter, die wie Fundament aussehen

- `SpatialObject.ownerPeer` — **null Schreiber, null Leser**. Ein Platzhalter für ein
  Multi-Device-Design, das nie gebaut wurde. Wer ihn für eine bestehende Peer-Zuordnung
  hält, baut auf Nichts.
- `Transport.clockSource { internal, midi, link }` — **null Schreiber**. `.midi`/`.link`
  sind Vokabular, kein Follow-Modus.
- `SignalTransport.abletonLink` — Enum-Fall mit `.roadmap`-Status, keine Implementierung.
- `CloudBackend`/`SyncableStore`/`CloudSyncEngine` — null Produktions-Konformer/-Konstruktionen.
- `MultipeerSession.onReceiveSession` — null Setter.

---

## C — Vorgeschlagene WebRTC-Grenze gegen die BESTEHENDEN Typen

Nicht die Wunsch-Hierarchie, sondern was an den gemessenen Baum andockt:

```
BESTEHEND, unverändert:
  PatternEngine  ── die musikalische Uhr (EINE)
  Transport      ── Fan-out + Position (EIN tick-Schreiber)
  EngineBus      ── Kontroll-Ebene + 3 SPSC-Queues
  SignalRouter   ── Transport-Wahrheit, persistiert, Patchbay-Tür
  BioEgressPolicy── Egress-Wahrheit
  AudioEngine    ── der Graph, 48 000 Hz, 6 Render-Blöcke

NEU, klein, jeweils mit EINEM Besitzer:
  SignalTransport.webRTC            (ein Enum-Fall)
  SignalPort "peer.event.out/in"    (Event-Ebene)
  SignalPort "peer.media.out/in"    (Medien-Ebene, später)
  PeerIdentity                      (der fehlende Typ — stabiler Schlüssel + Anzeigename)
  EventTransport                    (Protokoll: sende/empfange ColabPayload-artige Werte)
  NetworkAudioInput                 (Clock-Domain-Grenze, siehe F)
```

⛔ **Kein `WebRTCManager`.** Der Founder verbietet ihn ausdrücklich, und dieser Baum hat den
Grund: `MultipeerSession` IST so ein Objekt (Session + Peers + Discovery + Daten + Status in
einer Klasse hinter einem `#if canImport`), und genau deshalb ist es nicht in die Patchbay
integrierbar und nicht testbar ohne MC.

---

## D — P2P vs. SFU / TURN / Signalisierung

**Empfehlung: die Architektur auf ein Relais AUSLEGEN, aber zuerst 1:1 bauen.** Begründung
aus dem Baum, nicht aus WebRTC-Folklore:

1. Heute existiert **keine Signalisierung**. Multipeer ersetzt sie durch AWDL-Discovery, und
   das kann das lokale Netz nicht verlassen. Jede WAN-Session braucht einen Rendezvous-Dienst
   — das ist die eigentliche neue Infrastruktur, nicht die Medien-Ebene.
2. **Mesh skaliert an der Uplink-Kante.** Bei N Teilnehmern sendet jeder N−1 Ströme. Für ein
   Telefon auf Mobilfunk ist das bei N=4 schon die Grenze.
3. **Der Server darf NIE die DSP-Engine werden** (Founder Punkt 9). Ein SFU leitet weiter und
   mischt nicht — das ist mit der Regel vereinbar; ein „Cloud-Mixer" wäre es nicht.
4. **TURN ist kein Optional.** Ohne Relais scheitert ein nennenswerter Anteil der Verbindungen
   an symmetrischem NAT. Wer „P2P spart Serverkosten" rechnet, rechnet ohne TURN.

**Entscheidungs-Kriterium, das vor allem anderen kommt:** rohes libwebrtc oder ein
höherstufiges SFU-SDK. Das ändert JEDE Antwort in H. Diese Entscheidung ist Founder-Sache.

---

## E — Event-Ebene: Schema und Zeit-Verantwortung

### Wer heute Zeit besitzt (gemessen)

| Sache | Besitzer |
|---|---|
| Der Hardware-Timer (Step-Clock) | `PatternEngine` (`DispatchSourceTimer`) |
| Tempo-Wert + Fan-out | `Transport` |
| Position | `Transport` (**genau EIN** `tick(step:)`-Aufrufer) |
| Die EINE Step-Dauer-Formel | `Transport.stepDuration(atTempo:)` |

⚠️ **CLAUDE.md sagt „`Transport.setTempo` hat keinen eigenen Produktions-Aufrufer" — das ist
als Absicht richtig und als Wortlaut falsch:** es hat genau EINEN, das `PatternEngine`-Relais
an sechs Stellen. Kein UI-, Automations- oder OSC-Pfad ruft es direkt.

### ⭐ Der Erzwingungspunkt existiert schon: `TempoSource`

`.user` · `.flowServo` · `.automation` · `.modulationRoute` · `.remoteControl` ·
`.unspecified`. **Weder `setTempo` noch `glideTempo` hat einen Default für `source:`** — der
Compiler zwingt jeden neuen Tempo-Pfad, sich zu benennen. Ein WebRTC-Tempo muss einen
eigenen Fall hinzufügen (wie `.remoteControl` es für OSC tat) und dasselbe Gate ehren:
nur unter `studio.lockBPM`.

### Fünf Darstellungen musikalischer Position — und zwei PPQ-Zahlen

| Darstellung | Gitter | Status |
|---|---|---|
| `Note.startTick` | **480 PPQ** | **KANONISCH für Inhalt** |
| `TimelineTime` | 480 | LIVE, die eine Konversions-Fläche |
| `TransportPosition` | 16 Steps/Takt, **24 PPQ** | LIVE — **anderes PPQ** |
| `PatternEngine.currentStep` | 16tel | LIVE (der rohe Puls) |
| `MusicalTime/WallTime/SampleTime` | beliebig | **unerreichbar** |

⚠️ **`TransportPosition.ppqTick` ist 24 PPQ, der Inhalts-Grid ist 480.** Wer „ppqTick" liest
und 480 erwartet, bekommt eine Zahl, die um den Faktor 20 zu klein ist. Es hat keinen
Produktions-Verbraucher; die App benutzt `absoluteStep`.

⚠️ **`Transport.currentTick(at:)` modelliert KEINEN Swing** und ist dokumentiert falsch um bis
zu `2 · swing · base` (≈75 ms bei swing 0,30 / 120 BPM). **Sechs angebotene Genres swingen.**
Jeder neue Verbraucher erbt das.

### Vorgeschlagenes Event-Schema (Founder-Form, gegen den Baum geprüft)

```
sourceNode        PeerIdentity          (der Typ, den es noch nicht gibt)
eventID           UUID                  (Dedup über unzuverlässige Zustellung)
sessionTimestamp  CFAbsoluteTime        (dieselbe Referenz-Uhr wie BioSampleFrame)
musicalTime       bar / beat / tick     (tick in 480 PPQ — NICHT ppqTick)
eventType         enum
payload           Codable
```

⚠️ **Der empfangende Knoten plant lokal gegen `PatternEngine`.** Ein Paket-Zeitstempel ist
NIE die musikalische Autorität. `sessionTimestamp` dient Dedup und Staleness, nicht dem Takt.

---

## F — Audio-Uhr- und Resampling-Grenze

### Was wiederverwendbar existiert

| Baustein | Was es gibt |
|---|---|
| `SPSCQueue` | Lock-frei, **korrekte Release/Acquire-Fences** (5× `OSMemoryBarrier`), cache-line-gepaddet, Drop-Metriken |
| `RetroRingCursor` | Das Publish/Acquire-Idiom für einen rohen Frame-Ring (#1429) |
| `RetroCapture`s Raten-Grenze | Die EINZIGE Stelle im Baum, die „die Hardware-Rate hat sich mitten in der Session bewegt und mein Ring hält Frames in zwei Raten" schon löst |
| **Slab-Handshake** (`SamplerVoice`) | main alloziert → SPSC → Render adoptiert am Blockrand (nur Pointer-Move) → Retire-Queue → main gibt frei. **Das Muster, um Netz-PCM auf den Render-Thread zu bringen ohne malloc/free dort.** |
| `AudioEngine`s Drift-Instrument | `hostTime`/`sampleTime`-Doppelkanal, Render-Deadline-Misses |
| `Timebase`/`TempoMap` | Fertige, getestete, tempowechsel-sichere Konversion mit ratentragender `SampleTime` — **unverdrahtet, und eine Netz-Schicht ist genau der Aufrufer, für den sie gebaut wurde** |

### Was NICHT existiert — nicht annehmen

- **Kein Jitter-Buffer, kein adaptives Playout, kein Drift/PLL/Clock-Recovery.**
  `grep -i jitter` liefert nur DSP-Geschmack (Tape-Flutter) und Noten-Humanisierung.
- **Kein `AVAudioTime`, null host-time-verankertes Scheduling.** Jeder
  `scheduleBuffer(..., at: nil)`. **Es gibt heute nirgends sample-genaues Scheduling.**
- **Keine Sample-Raten-Konversion auf irgendeinem Live-Pfad.** Die Rate ist konstruktiv
  48 000; der eine `AVAudioConverter` im Baum ist Ladezeit, Hauptthread, offline.
  ⚠️ #1213 hat die Kosten gemessen: ein nicht passender Knoten lässt `AVAudioEngine` einen
  **impliziten Konverter pro Render-Block und Knoten** einfügen.

### Die Grenze, die gebaut werden müsste

```
WebRTC receive (eigene Queue, fremde Uhr, fremde Rate)
   ↓  ZERO Actor-Hop  —  push in SPSC/lock-geschützte Queue
Jitter-Puffer + EIGENER Resampler (existiert nicht, muss gebaut werden)
   ↓  Slab-Handshake am Blockrand
Echoel Signal Graph @ 48 000 Hz
```

⛔ **Niemals `Task { @MainActor }` pro Paket.** Das ist der zweimal ausgelieferte Defekt
dieses Repos (#30 MIDI, 10.76.48 Kamera) und der Grund, warum `publish(controller:)`
batch-koalesziert ist.

⛔ **Niemals einen `@MainActor`-Typ in einen Render-Block schließen.** Genau das ließ Build
1368 auf `AURemoteIO::IOThread` abstürzen.

---

## G — Privacy-Modell, und der schwerste Befund des Audits

### Was `BioEgressPolicy` leistet

Zwei orthogonale Gates: **Quelle** (`.ble/.cameraPPG/.fallback` erlaubt · `.healthKit/.watch/
.oura` **verboten**, App Store 5.1.3) und **Feld-Klasse** (`.derived` immer · `.clinical`
opt-in, Default aus · `.raw` **nie**, und `.raw` ist *strukturell* unmöglich, weil
`BioSampleFrame` skalar-only ist).

⚠️ **Nur `OSCSender` konsultiert das FELD-Gate. Jeder andere Sender konsultiert allein das
QUELLEN-Gate.** Und `fieldClass(ofOSCAddress:)` schlüsselt auf OSC-**Adress-Strings** — ein
Nicht-OSC-Transport kann es gar nicht aufrufen, ohne zuerst einen adress-förmigen Schlüssel
zu erfinden. **`.clinical` ist außerhalb des OSC-Adressraums nicht durchsetzbar.**

### ⛔ DER BEFUND: MIDI-Ausgang trägt Bio und konsultiert die Policy NULL MAL

Selbst nachgemessen, nicht von einer Bahn übernommen:

1. `EngineBus.usableBio()` filtert **nur auf Frische**, nie auf `BioSource` — ein
   `.healthKit`/`.watch`/`.oura`-Rahmen kommt durch.
2. `PianoRollView` baut daraus `MPEExpression.from(coherence:breathDepth:hrvNormalized:)`
   → **CC74 (Slide) = Kohärenz · Channel Pressure (Press) = Atem · Pitch Bend (Glide) = HRV**.
3. `MIDIOutput.send` fächert an **jedes** CoreMIDI-Ziel.
4. `BioEgressPolicy` kommt in `Audio/MIDIOutput.swift` und `Sync/MPEExpression.swift`
   **null Mal** vor. (Der eine Treffer in `PianoRollView` ist ein Kommentar über etwas anderes.)

**Schwere, ehrlich abgestuft — und die Abstufung ist der Punkt:**

| Hälfte | Was wirklich rausgeht | Gates davor |
|---|---|---|
| **Expression** (CC74/Press/Bend) | **die Messung selbst**, direkt abgebildet | DREI, alle Default aus: `midi.out`-Route + `midi.out.mpe` + `midi.out.expression` |
| **MIDI-Clock** | ein **körper-abgeleitetes Tempo** (unter `.flowFree` folgt es dem Puls) | **EINS**: die `midi.out`-Route |
| Velocity/Notenwahl | bio-**geformte** Musik, keine Messung (`note.velocity · laneGain · exp.velocityScale`) | EINS |

⭐ **Die Clock-Hälfte ist die schärfste, weil der OSC-Pfad GENAU DIESEN FALL gated:**
`/echoelmusic/music/tempo` wird zurückgehalten, wenn die lebende Bio-Quelle egress-gesperrt
ist — mit einem ausdrücklichen Vermerk, dass diese Eigenschaft dem FILTER gehört, nicht dem
Sender. **MIDI tut das nicht.** Eine HealthKit-Herzrate kann ein MIDI-Clock-Tempo erreichen,
wo OSC sie verweigert.

⚠️ **Das ist KEIN ausgelieferter Leak** — alles hängt hinter mindestens einer Default-aus-Route,
und ob es das physische Gerät verlässt, hängt am Ziel (USB/BLE-Hardware oder RTP-MIDI, selbst
Default aus). **Es ist ein fehlendes Gate auf einem Pfad, den das Produkt schon hat** — und
damit der empirische Beweis für Founder-Punkt 4: *Nicht-Vererbung ist real, nicht theoretisch.*

⚠️ **Und die eigene Zählung des Repos übersieht es:**
`TheWholeEgressSurfaceIsClinicalFreeTests` zählt „die SECHS Stellen, an denen ein Bio-Frame
zu Bytes wird" — MIDI ist nicht dabei. Für `.clinical` ist die Zählung richtig; als
„die Egress-Fläche" gelesen, ist sie unvollständig. Das ist die #867-Falle im Register,
das sie als Gesetz führt.

### Provenienz und Krypto

Provenienz ist **pro Transport neu erfunden**: OSC hat `/bio/synthetic` (eigene Adresse,
vorangestellt, auf den Batch gegated) · sACN einen 64-Byte-Namen · Multipeer ein `Bool?`
(dreiwertig) · **ADM-OSC, Art-Net und MIDI: keine.** Es gibt **keinen transport-agnostischen
Provenienz-Träger.**

**Krypto/Auth: es gibt keine, mit genau einer Ausnahme.** Alle vier Netz-Sender sind nacktes
UDP, null TLS/DTLS, null Signatur, null Replay-Schutz, null `URLSession`. Der eine echte
Treffer ist `MCSession(..., securityIdentity: nil, encryptionPreference: .required)` —
Link-Verschlüsselung **ohne** Zertifikat, also gegen passives Mithören, **nicht**
authentifiziert. Peer-Zulassung ist ein menschlicher Tap. Eingehend: die IP-Allowlist des
`OSCReceiver` ist **default leer = jeder Sender**; RTP-MIDI ist `.anyone`.

⭐ **Für WebRTC heißt das: DTLS-SRTP wäre die ERSTE authentifizierte Transportverschlüsselung
im Produkt.** Und Founder-Punkt 8 gilt trotzdem: Verschlüsselung rechtfertigt nicht, mehr zu
senden.

---

## H — Abhängigkeit / Lizenz / Build — **NICHT ERLEDIGT, mit Grund**

`webrtc.googlesource.com` ist vom Egress-Proxy dieser Sitzung **blockiert**
(`EGRESS_BLOCKED`). Der Founder hat ausdrücklich gesagt: *„verify against CURRENT upstream
sources … Do not rely on memory."* **Also steht hier nichts aus dem Gedächtnis.**

Was VOR der Prüfung entschieden werden muss, weil es jede Antwort ändert:
**rohes libwebrtc oder ein höherstufiges SFU-SDK.** Das ist eine Strategie-Entscheidung,
keine Messung.

Danach zu prüfen und in einem ADR mit exakter Revision zu pinnen: Lizenzdatei + Patent-Notiz ·
iOS/macOS-Distributionsfolgen · Binärgröße · unterstützte Codecs · Signing/Packaging ·
die C++/ObjC++-Grenze · minimale OS-Versionen · Update-Last.

⚠️ **Zwei harte Repo-Regeln, die hier kollidieren und die der Founder kennen muss:**
`Package.swift` hat `dependencies: []` — **null externe Abhängigkeiten, heute.** Und
`CLAUDE.md` verbietet C++ außer als *„free, well-contained, Council-approved"* Bibliothek
**außerhalb des Swift-Audio-Kerns**. libwebrtc ist groß, C++ und alles andere als
well-contained. **Das ist die größte einzelne Spannung zwischen diesem Vorhaben und der
bestehenden Doktrin** — und sie gehört vor die Technik, nicht danach.

---

## I — Kleinste Scheibe, die die Abstraktion beweist, ohne WebRTC zu Session-Wahrheit zu machen

**Vorschlag: `PeerIdentity` + ein Event-Port in der Patchbay, OHNE WebRTC.**

Begründung: die Abstraktion, die fehlt, ist nicht der Transport — den gibt es
(`SignalTransport`). Es ist **„wer ist der andere"** und **„ein Peer ist ein Routing-Ziel"**.
Beides lässt sich am BESTEHENDEN Multipeer-Pfad beweisen, wo es heute schon wehtut
(drei Telefone heißen „iPhone"), und zwar ohne eine einzige neue Abhängigkeit.

Scheibe:
1. `PeerIdentity` — stabiler Schlüssel (persistierte UUID) + Anzeigename aus
   `SessionContext.artistName`, nicht `UIDevice.current.name`. Trägt in `ColabPayload`.
2. `peerReadings` auf den stabilen Schlüssel umstellen → der Namenskollisions-Defekt ist weg.
3. **Kein** Patchbay-Eintrag in derselben Scheibe (B2: zweiter Lifecycle-Besitzer).

Wenn das steht, ist WebRTC danach tatsächlich „ein Enum-Fall plus ein Adapter" — und wenn es
nicht steht, wäre WebRTC der zweite Transport ohne Peer-Begriff.

---

## J — Wächter, die VOR dieser Scheibe stehen müssen

1. **`TheClockHasOneWriter`** — `transport.tick(step:)` hat genau EINEN Aufrufer;
   `Transport.setTempo` genau einen (das Relais). Wird rot, wenn ein Netz-Pfad sich
   danebenschiebt.
2. **`TheTempoSourceHasNoDefault`** — weder `setTempo` noch `glideTempo` bekommt ein
   Default-`source:`. (Bestehendes `TempoInvariantTests` deckt Teile; der Default-Anspruch
   ist bereits gepinnt.)
3. **`TheMIDIOutConsultsTheEgressPolicy`** — ⛔ **wäre heute ROT.** Der Befund aus G.
   Er gehört gepinnt, BEVOR ein weiterer ungegateter Egress-Pfad dazukommt.
4. **`TheEgressCensusNamesEveryByteProducer`** — die Sechser-Zählung muss MIDI nennen oder
   ihren Titel ändern.
5. **`NoActorHopPerPacket`** — kein `Task { @MainActor }` innerhalb eines Empfangs-Handlers.
6. **`ThePeerHasAStableIdentity`** — `peerReadings` schlüsselt nicht auf einen Anzeigenamen.
7. **`TheBusQueuesHaveOneProducerEach`** — eine Enqueue außerhalb `@MainActor` ist verboten.

---

## Gate-Empfehlung

**HOLD-FOR-FOUNDER auf zwei Punkten, PROCEED auf dem Rest:**

- ⛔ **H (C++/Abhängigkeits-Doktrin)** — libwebrtc gegen `dependencies: []` und das
  C++-Verbot. Das ist eine Doktrin-Frage, keine technische.
- ⛔ **D (roh vs. SFU-SDK)** — ändert jede Antwort in H.
- ⭐ **G-Befund (MIDI-Egress)** ist unabhängig von WebRTC und sollte unabhängig repariert
  werden. Er ist heute klein (alles hinter Default-aus-Routen) und wird teuer, sobald ein
  weiterer Transport dieselbe Nicht-Vererbung erbt.
- ⭐ **I (PeerIdentity)** ist ohne WebRTC baubar, repariert einen echten bestehenden Defekt
  und ist die Voraussetzung dafür, dass WebRTC später klein bleibt.
