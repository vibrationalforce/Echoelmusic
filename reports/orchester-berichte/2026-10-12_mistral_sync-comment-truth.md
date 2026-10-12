# Orchester-Bericht — Mistral · Auftrag 11 (sync-comment-truth)

## 1. Kopf

- **Auftrag:** 11 — sync-comment-truth. Nur Kommentarzeilen in den fünf Sync-Dateien korrigieren, wo sie vom Code abweichen.
- **Datum:** 2026-10-12
- **Repo:** `vibrationalforce/Echoelmusic`
- **Branch:** `orchester/mistral/sync-comment-truth`
- **Basis-Commit:** `3a47150c5be679116edf0432350b548c9ff0ed31` — verifiziert: die fünf Code-Commits des Branchs sitzen direkt auf diesem Commit.
- **Letzter Code-Commit:** `a73f0c274c8876b6524a980ac2164613b875c102` (OSCReceiver)
- **Berichts-Commit:** dieser Commit — sein SHA existiert erst nach dem Push und ist in der Chat-Fassung dieses Berichts genannt.
- **Push-Uhrzeit (UTC):** 2026-10-12T20:04:01.808Z

## 2. Commits

| # | SHA | Nachricht (Subject) | Inhalt |
|---|-----|----------------------|--------|
| 1 | `5b213d93` | docs(sync): OSCSender-Kopf nennt Musik-Batch und Events, Ziel ist konfigurierbar | E1, E3 |
| 2 | `b0042f5f` | docs(sync): OSCSender breath/phase-Gate im Kopf heisst hasMeasuredBreathWaveform | E2 |
| 3 | `6f899f81` | docs(sync): OSCSender-Rumpf-Doku beschreibt den heutigen Stand, nicht den alten | E4, E5 |
| 4 | `c159954b` | docs(sync): ADMOSCSender nennt hasMeasuredBreathWaveform als Atem-/Phasen-Gate (#1140) | E6, E7 |
| 5 | `a73f0c27` | docs(sync): OSCReceiver ctrl-Doku nennt die tatsächliche Argumentform (Argument.number) | E9, E10, E8 |
| 6 | (dieser Bericht) | docs(orchester): Bericht zu Auftrag 11 (sync-comment-truth) | Berichtsdatei |

Jede Commit-Nachricht endet mit der Zeile: `Orchester: Mistral · Auftrag 11`

## 3. Dateien

| Datei | Status | Zeilen (Basis → neu) | Diff |
|---|---|---|---|
| Sources/Echoelmusic/Sync/OSCSender.swift | M | 708 → 704 | +8 / -12 |
| Sources/Echoelmusic/Sync/ADMOSCSender.swift | M | 611 → 613 | +5 / -3 |
| Sources/Echoelmusic/Sync/OSCReceiver.swift | M | 652 → 655 | +6 / -3 |
| Sources/Echoelmusic/Sync/ArtNetSender.swift | — | unverändert | 0 |
| Sources/Echoelmusic/Sync/SACNSender.swift | — | unverändert | 0 |
| reports/orchester-berichte/2026-10-12_mistral_sync-comment-truth.md | A | neu | dieser Bericht |

## 4. Änderungen (10 Stück — nur Kommentarzeilen)

### E1 — OSCSender.swift:5-6 (Dateikopf, Streams-Zeile)

**Vorher:** Der Kopf behauptete, der Sender streame ausschließlich `EngineBus.latestBio` hinaus.
**Nachher:** Der Kopf nennt zusätzlich den musikalischen Batch (#1383) und die diskreten Bio-Events — der Tick ruft alle drei Pfade.

**Beleg:** OSCSender.swift:178-180 (`self.sendIfFresh(from: bus)` / `self.sendMusicIfFresh(from: bus)` / `self.drainAndSendEvents(from: bus)`).

Alt (wörtlich):

```
//  Streams EngineBus.latestBio onto an OSC over UDP endpoint so any
```

Neu (wörtlich):

```
//  Streams EngineBus.latestBio, the musical batch (#1383) and the
//  discrete bio events onto an OSC over UDP endpoint so any
```

### E2 — OSCSender.swift:35-38 (Adressliste, /breath/phase)

**Vorher:** Die Kopf-Adressliste sagte zu `/breath/phase`: with the RATE — das Rate-Gate wurde aber durch #1140 durch das Wellenform-Gate ersetzt.
**Nachher:** Die Liste nennt `hasMeasuredBreathWaveform` (#1140) und begründet, warum die Phase nie auf sich selbst gated.

**Beleg:** OSCSender.swift:582 (`if frame.hasMeasuredBreathWaveform {` sendet `/echoelmusic/bio/breath/phase`).

Alt (wörtlich):

```
//    /echoelmusic/bio/breath/phase  float [0..1]     — with the RATE, never gated on itself:
//        the phase has no unknown sentinel (0 = EXHALE start, 0.5 = inhale start), so a value
//        gate would drop real data once per breath cycle
```

Neu (wörtlich):

```
//    /echoelmusic/bio/breath/phase  float [0..1]     — gated on `hasMeasuredBreathWaveform`
//        (#1140: the rate gate was blind to a source with a real rate and no waveform),
//        never gated on itself: the phase has no unknown sentinel (0 = EXHALE start,
//        0.5 = inhale start), so a value gate would drop real data once per breath cycle
```

### E3 — OSCSender.swift:82 (Default-Endpoint)

**Vorher:** user-configurable in a later cycle — das Ziel ist aber heute schon konfigurierbar.
**Nachher:** Ein Edit persistiert und verbindet einen live Output neu.

**Beleg:** OSCSender.swift:102 (`didSet { Self.persistTarget(host, port); reconnectIfActive() }` auf `host` und `port`).

Alt (wörtlich):

```
//  user-configurable in a later cycle).
```

Neu (wörtlich):

```
//  user-configurable: an edit persists and reconnects a live output).
```

### E4 — OSCSender.swift:111 (lastSentTimestamp-Doc)

**Vorher:** Mach-time — der Code speichert aber `CFAbsoluteTimeGetCurrent()`, keine Mach-Zeit.
**Nachher:** CFAbsoluteTime.

**Beleg:** OSCSender.swift:237 (`lastSentTimestamp = CFAbsoluteTimeGetCurrent()`).

Alt (wörtlich):

```
    /// Mach-time of the last message sent. Lets the UI render an
```

Neu (wörtlich):

```
    /// CFAbsoluteTime of the last message sent. Lets the UI render an
```

### E5 — OSCSender.swift:344 ff. (drainAndSendEvents-Doc, Löschung)

**Vorher:** Der Doc-Block beschrieb die alte Snapshot-Lesung (`latestBioEvent`) mit 100-ms-Kollaps — der Code drainiert seit dem Audit aber die volle `bioEvents`-Warteschlange.
**Nachher:** Der veraltete Absatz (6 Kommentarzeilen) ist gelöscht; der folgende, bereits korrekte Absatz (Drains the `bioEvents` SPSC queue ...) beschreibt den Code.

**Beleg:** OSCSender.swift:352-355 (`func drainAndSendEvents(from:)`, `while let event = bus.bioEvents.dequeue()`).

Alt (wörtlich):

```
    /// Sends the latest discrete bio event if it is newer than the one we
    /// last forwarded. Reads the `@MainActor` snapshot (`latestBioEvent`),
    /// not the lock-free `bioEvents` queue, so it never contends with the
    /// audio-thread consumer for that SPSC queue. At the 100 ms tick cadence,
    /// events closer together than 100 ms collapse to the most recent — fine
    /// for heartbeat/breath/motion rates; a return channel can tighten this later.
```

Neu: — (gelöscht, kein Ersatz; alle anderen Zeilen des Blocks unverändert).

### E6 — ADMOSCSender.swift:36-37 (Dateikopf, bio-objekt-Mapping)

**Vorher:** Der Kopf verlangte `hasMeasuredBreath` für die Atem-phase-Azimut-Abbildung — das Gate im Code ist seit #1140 `hasMeasuredBreathWaveform`.
**Nachher:** Der Kopf nennt `hasMeasuredBreathWaveform` (#1140).

**Beleg:** ADMOSCSender.swift:370 (`if f.hasMeasuredBreathWaveform, f.breathPhase.isFinite {`).

Alt (wörtlich):

```
//    breath phase → azimuth    sound sweeps L↔R with the breath — needs `hasMeasuredBreath`
```

Neu (wörtlich):

```
//    breath phase → azimuth    sound sweeps L↔R with the breath — needs
//    `hasMeasuredBreathWaveform` (#1140)
```

### E7 — ADMOSCSender.swift:352-354 (Gate-Kommentar über der azim-Zeile)

**Vorher:** Der Kommentar sagte: Gated on `breathRate` — der Code gated auf `hasMeasuredBreathWaveform`.
**Nachher:** Der Kommentar nennt das echte Gate (`hasMeasuredBreathWaveform`, #1140 below) und hält die zutreffende Sentinel-Begründung.

**Beleg:** ADMOSCSender.swift:370 (`if f.hasMeasuredBreathWaveform, f.breathPhase.isFinite {`).

Alt (wörtlich):

```
        // Gated on `breathRate`, not on the phase: `breathPhase` has no unknown sentinel
        // (0 is a real position, exhale start), so it cannot answer for itself.
```

Neu (wörtlich):

```
        // Gated on `hasMeasuredBreathWaveform` (#1140 below), not on the phase:
        // `breathPhase` has no unknown sentinel (0 is a real position, exhale start),
        // so it cannot answer for itself.
```

### E9 — OSCReceiver.swift:120-121 (Doc zu ctrl/key)

**Vorher:** Das Doc verlangte `<i>` — `parse` nimmt aber jede numerische Form (`Argument.number`: f/i/T/F), rundet und prüft dann 0...11.
**Nachher:** Das Doc nennt die echte Argumentform (Any numeric argument, rounded, then bounded).

**Belege:** OSCReceiver.swift:50 (`case .float(let f): return Double(f)`); OSCReceiver.swift:178-179 (`(0...11).contains(v.rounded())`, `return .key(Int(v.rounded()))`).

Alt (wörtlich):

```
    /// `/echoelmusic/ctrl/key <i>` — root pitch class 0 (C) … 11 (B).
```

Neu (wörtlich):

```
    /// `/echoelmusic/ctrl/key` — root pitch class 0 (C) … 11 (B). Any numeric
    /// argument (`Argument.number`); rounded, then bounded.
```

### E10 — OSCReceiver.swift:127-128 (Doc zu ctrl/visualStyle)

**Vorher:** Das Doc verlangte `<i>` — `parse` nimmt auch hier jede numerische Form, rundet und prüft 0...9.
**Nachher:** Das Doc nennt die echte Argumentform.

**Beleg:** OSCReceiver.swift:189 (`(0...9).contains(v.rounded())` in `parse`).

Alt (wörtlich):

```
    /// `/echoelmusic/ctrl/visualStyle <i>` — look 0…9 (`EchoelStudioView.visualStyle`'s index space).
```

Neu (wörtlich):

```
    /// `/echoelmusic/ctrl/visualStyle` — look 0…9 (`EchoelStudioView.visualStyle`'s
    /// index space). Any numeric argument (`Argument.number`); rounded, then bounded.
```

### E8 — OSCReceiver.swift:130-131 (Doc zu ctrl/blackout)

**Vorher:** Das Doc verlangte `<T|F|i>` — T/F sind nur Spezialfälle von `Argument.number`, und jede Zahl ungleich 0 gilt als on.
**Nachher:** Das Doc nennt f/i/T/F und non-zero = on.

**Belege:** OSCReceiver.swift:191-193 (`guard let v = first?.number, v.isFinite`, `return .blackout(v != 0)`); OSCReceiver.swift:50 (`Argument.number` mappt T/F zu 1/0).

Alt (wörtlich):

```
    /// `/echoelmusic/ctrl/blackout <T|F|i>` — Art-Net + sACN blackout, together.
```

Neu (wörtlich):

```
    /// `/echoelmusic/ctrl/blackout` — Art-Net + sACN blackout, together. Any
    /// numeric argument (`Argument.number`: f/i/T/F); non-zero = on.
```

## 5. Prüfungsmethode

- Vollständige Lektüre aller fünf Sync-Dateien am Basis-Commit `3a47150c5` (OSCSender, OSCReceiver, ADMOSCSender, ArtNetSender, SACNSender).
- Jeder Kommentar wurde gegen den Code derselben Datei geprüft; OSC-Adressen zusätzlich gegen CLAUDE.md, Abschnitt `## OSC (EchoelSync)` (Wahrheitsquelle, unverändert gelassen).
- Jede Änderung: serverseitiger Ganz-Datei-Abruf am Basis-Commit, Patch mit Eindeutigkeits-Check (genau 1 Treffer), Prüfung, dass jede entfernte und jede eingefügte Zeile eine Kommentarzeile ist (nach Einrückung `//` bzw. `///`), dann Push auf den Branch.
- ⛐- und ⭐-Absätze (Geschichte/Gesetze) wurden ausdrücklich nicht angefasst.
- ArtNetSender und SACNSender: keine vom Code abweichende Kommentarzeile gefunden — unverändert gelassen (Beispielprüfung: ArtNet-Sequenz beginnt bei 1 und wrappt auf 1, wie der Kommentar sagt; SACN `sayGoodbye` zählt pro Paket, wie der Kommentar sagt).
- NICHT kompiliert, keine Tests ausgeführt — ich habe keinen Compiler in meiner Umgebung.

## 6. CI

- CI-Ergebnisse sind für mich nicht sichtbar; ich habe keinen CI-Status gelesen.
- Nicht kompiliert (kein Compiler verfügbar). Da ausschließlich Kommentarzeilen geändert wurden, ist keine Verhaltensänderung zu erwarten — das ist aber nicht gemessen.

## 7. Abweichungen

- Basis: keine Abweichung. Der Branch steht exakt auf `3a47150c5`; der Connector löst Branch-Anlagen nur nach Namen auf, deshalb hat der Orchestrator den Branch bei diesem Commit angelegt, und alle fünf Code-Commits liegen direkt auf der Basis (per Commit-Liste verifiziert).
- Der Berichts-Commit-SHA kann im Kopf dieser Branch-Fassung nicht stehen (er existiert erst nach dem Push); die Chat-Fassung nennt ihn.
- Sonst keine Abweichungen vom Auftrag.

## 8. Verbotsliste

- Kein Push auf andere Branches (nur `orchester/mistral/sync-comment-truth`); keine Tags; kein Force-Push; kein Rebase; kein Branch-Löschen; keine PRs, Merges, Issues oder Kommentare; kein Merge des Branchs.
- Keine geschützten Pfade berührt: `.github/`, `.deploy/`, `project.yml`, `Package.*`, `Info.plist`, `*.entitlements`, `CLAUDE.md`, `.claude/`, `memory/`, `decisions.csv`, `inspiration.csv`, `scripts/`, `fastlane/`, `.mcp.json`, `LICENSE` — alle unverändert.
- Nur Kommentarzeilen geändert; keine Code-Zeile verändert oder gelöscht (je Patch geprüft: jede entfernte und eingefügte Zeile ist eine Kommentarzeile).
- Genau ein Branch angelegt/geneigt; nur die fünf Sync-Dateien + die Berichtsdatei berührt.

Vollständige Dateiliste A/M/D (Branch gegen Basis):

- M Sources/Echoelmusic/Sync/OSCSender.swift
- M Sources/Echoelmusic/Sync/ADMOSCSender.swift
- M Sources/Echoelmusic/Sync/OSCReceiver.swift
- A reports/orchester-berichte/2026-10-12_mistral_sync-comment-truth.md
- D: (keine)
- Sources/Echoelmusic/Sync/ArtNetSender.swift und Sources/Echoelmusic/Sync/SACNSender.swift: unverändert.

## 9. Offene Fragen an Claude Code (max. 5)

1. ADMOSCSender.swift:329 (⛐-Absatz AND BOTH OCCURRED ON SHIPPING HARDWARE) erzählt die prä-#1220-Kamera-Historie (Coherence 0 für ganze Takes, 10-s-Fenster) und widerspricht damit dem aktuellen #1220-Stand im OSCSender-Kopf (OSCSender.swift:42-47). Ich habe ihn als Geschichte unangetastet gelassen — bleibt er bewusst als Historie stehen?
2. OSCSender.swift:111-112: Das `lastSentTimestamp`-Doc sagt Lets the UI render an activity dot; ADMOSCSender.swift sagt für sein Pendant explizit, es habe keinen Leser in `Sources/`. Hat `OSCSender.lastSentTimestamp` tatsächlich einen UI-Leser? Aus den fünf Sync-Dateien ist das nicht messbar — deshalb nicht geändert.
3. Der OSCSender-Kopf listet ab Z. 74 die Event-Adressen (u. a. motion/coherence/eeg); CLAUDE.md markiert einige davon als ohne Produzenten (nie gesendet). Das Mapping `address(for:)` existiert real (OSCSender.swift:435), gesendet wird nur, was der Publisher liefert. Soll der Kopf das differenzieren?
4. OSCReceiver.swift:606 vs. 607, 618: `ignoredCount` zählt auch un-dekodierbare Datagramme (z. B. `#bundle`), obwohl das Doc (OSCReceiver.swift:404) sagt decoded but were not on the whitelist. Ist das beabsichtigt (dann wäre die Doc-Zeile falsch) oder ein Code-Fehler?
5. ADMOSCSender.swift:120 (⛐ NOTHING IN `Sources/` WRITES THIS, #745 zu `sceneDialect`): aus den fünf Sync-Dateien nicht nachmessbar, ob das heute noch gilt — eine repo-weite Suche stand mir nicht zur Verfügung. Stimmt die Aussage noch?

## 10. Vermutungen

- ANNAHME: `hasMeasuredBreathWaveform` ist ein eigenständiges `BioSampleFrame`-Gate (in keiner der fünf Dateien definiert; Nomenklatur aus den #1140-Blöcken beider Sender).
- ANNAHME: `Transport.minTempo`/`maxTempo` liegen über 1, deshalb habe ich die `<f|i>`-Doc von `/echoelmusic/ctrl/bpm` nicht geändert — ein T/F-Argument fiele am Bereichstest durch und würde ignoriert; die genannte Form stimmt.
- ANNAHME: Der UTF-8-Roundtrip Abruf → Patch → Push ist verlustfrei; belegt über die Commit-Stats (z. B. ADMOSCSender +5/-3), nicht über einen eigenen Diff-Reader.
- ANNAHME: CI läuft auf dem Branch; das Ergebnis ist für mich nicht sichtbar (siehe Abschnitt 6).

Orchester: Mistral · Auftrag 11
