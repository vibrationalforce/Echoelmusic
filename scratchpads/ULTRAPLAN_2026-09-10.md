# Ultraplan 2026-09-10 — eine Reihenfolge für Audit, Council und Marketing

> **Auftrag (Founder, 2026-09-10):** „Deep Audit, Council, Ultraplan und Marketing Strategie" im
> „Apple Developer Korrekturschleifen Modus". Die drei Quelldokumente dieses Plans:
> `DEEP_AUDIT_2026-09-10.md` (54 Befunde, 45 bestätigt) · `GRAND_COUNCIL_DMMW_AUV3_2026-09-10.md`
> (DMMW als Produkt nein, als Ecosystem-Position ja; 12-Schritt-Roadmap; 5 Founder-Fragen) ·
> `MARKETING_STRATEGY_2026-09-10.md` (drei Lanes, fünf Aktionen). **Dieser Plan ordnet die drei zu
> EINER Schlange**, damit die nächste Sitzung nicht drei Listen gegeneinander liest.
>
> **Regeln, die über der Reihenfolge stehen:** Ralph Wiggum — ein Fix je Zyklus, ≤3 Dateien, Build-Rot
> ist die einzige Priorität · founder-gated Dateien (`.github/workflows/**`, `project.yml`,
> `Resources/iOS/Info.plist`) werden berichtet, nie editiert · nutzersichtbare Kopie geht durch
> `the-council` · `decisions.csv:685` hält bis zur Founder-Antwort jede DAW-Tür und jede Löschung.

## 0. Was in dieser Sitzung schon gefahren ist

| # | Was | Commit | Gate |
|---|---|---|---|
| Council | `GRAND_COUNCIL_DMMW_AUV3_2026-09-10.md` + 3 PROPOSED-Zeilen `decisions.csv` + `memory/decisions.md` | `fa45698` | docs |
| #1208 | `EchoelDelay` `tone`/`timeSeconds` NaN-sicher (Audit `audio-dsp-1`) | `4bba144` | Compile Check + CI/CD „Build for Testing" lesen |
| #1209 | Privacy-Link in `LearnView` + Wächter (Audit `ship-path-1`) | `41c9648` | dito |
| #1210 | ADM-OSC-Leaves `/azim` `/elev` `/dist` `/x` `/y` `/z` + Wächter + Prosa (Audit `output-sync-1`) | `8180b27` | dito; NEEDS-FOUNDER-VERIFY am Renderer |
| #1211 | `CLAUDE.md`-Statuskorrekturen (Watch, PERFORMANCE-Zeilen, Kohärenz-Kamera) + die drei Dokumente | dieser Commit | docs |

⚠️ Alles nur transkribiert, nicht kompiliert (keine Toolchain). Nach dem Push die beiden Gates lesen
(`Tests/CISmoke/CLAUDE.md` §5): `Xcode Compile Check` baut `Sources/` allein; die neuen Wächter
beweist erst CI/CD „Build for Testing".


**Nachtrag 2026-09-10, zweite Runde (#1212–#1215), auf die Founder-Frage „Übernahme geklappt? TestFlight
ressourcensparender? Bio auf bestem Stand?":** Übergabe-Punkt #56 (`Project.keyRoot`-Trap) geschlossen (#1212) ·
Audit `audio-dsp-5` (#1213, Sampler auf Graph-Rate, kein SRC pro Block) und `audio-dsp-2` (#1214, Delay-Ton-Cache)
geschlossen · Zyklus 6 (#1215, HealthKit `maxMeasurementAge` 600 s) geschlossen. `HANDOVER_2026-09-10.md` der
Neustart-Sitzung hierher geholt, damit sie mit dem nächsten Code-Commit `main` erreicht (#697). Offen aus derselben
Runde: Zyklus 5 (Polar), Zyklus 7 (Kamera-Kohärenz, braucht Gerät), Cron-Entscheidung (§2 Punkt 8).

## 1. Die Schlange (nächste ~25 Zyklen)

Reihenfolge = (Schwere nach außen) → (Ship-Gate-Nähe) → (Council-Sequenz) → (Marketing). Spalte
„Wer": **S** = Sitzung ohne Toolchain, **F** = Founder (Gerät/Mac/Apple-Portal), **C** = Council vorher.

| # | Zyklus | Quelle | Wer | Dateien / Gate | Status |
|---|---|---|---|---|---|
| 1 | **Founder-Gerätestunde:** Ship-Gate 1 (Klang je Genre) + 5 (Launch, Black-Screen, Menü-Freeze) laut entscheiden; 6 Screenshots; Flagship-1-Rohmaterial; AUM + ein freies Fremd-AU installieren, Warm-Sequenz fahren, A/B/C melden; erste `VERIFIED-2026-09-TT`-Marken (`python3 scripts/founder-verify.py`) | Council §7 Schritt 1 · Marketing Aktion 1 · Audit `tests-guards-8` | F | 0 Deploys | offen — **116/103/0 muss anfangen zu sinken** |
| 2 | **Drei Log-Zeilen + ein Apple-Formular:** A0 (#132 Slice 5b–5d HOLD/verwerfen), Sperrfrist auf `decisions.csv:302`, AUv3-Epic-Zeile; Antrag `com.apple.developer.networking.multicast` | Council §7 Schritt 0, §9 Fragen 1–5 | F (Antwort) → S (Zeilen) | `decisions.csv`, `memory/decisions.md` | offen — 5 Binärfragen in Council §9 |
| 3 | Art-Net-Default auf Unicast, `stateUpdateHandler` → `lastError`, PatchbayView-Satz + `artnet-sacn-from-a-phone.html` | Audit `output-sync-2` (hoch) | S | `Sync/ArtNetSender.swift`, `Studio/PatchbayView.swift`, `docs/artnet-sacn-from-a-phone.html` | ✅ #1219 (`defaultHost` 192.168.1.100, `lastError` in der Patchbay; Wireshark-Verify offen) |
| 4 | sACN/Art-Net Keep-alive ≥ 0,8 s + `Stream_Terminated` (0x40 ×3) in `stop()` | Audit `output-sync-3` (hoch) | S | `SACNSender.swift`, `ArtNetSender.swift`, `SACNSenderTests.swift` | ✅ #1218 (`keepAliveSeconds` 0,8 für beide; 3× 0x40 im `stop()`; Pult-Verify offen) |
| 5 | Polar: `lastNotificationAt`-Gate ≤ 3 s + Sensor-Contact-Bits `0x06` | Audit `bio-pipeline-1` | S | `PolarH10BioPublisher.swift` + Parser-Test | ✅ #1216 (`maxNotificationAgeSeconds` 3 s, Contact-Bits im Parser) |
| 6 | HealthKit: `maxMeasurementAge` (Größenordnung 10 min, > 180 s) | Audit `bio-pipeline-2` | S | `HealthKitBioPublisher.swift` + Test | ✅ #1215 (600 s, NEEDS-FOUNDER-VERIFY am Ort) |
| 7 | Kamera-Kohärenz: rollende RR-Historie (~64) am `lastRespirationBeatTime`-Cursor statt 10-s-Fenster → Kohärenz ab ~16 s bei 60 bpm | Audit `bio-pipeline-3` (Chance-Hälfte) | S → F (Verify) | `CameraRPPGBioPublisher.swift`; `AFreshTakeStartsWithNoHeldFrameTests`-Prosa | ✅ #1220 (Historie 64 = Gurt-Parität, am Atem-Cursor, in `stop()` geleert; NEEDS-FOUNDER-VERIFY an der Kapazität; Prosa in OSCSender · EngineBus · ADMOSCSender · CLAUDE.md ×2 · zwei Wächter-Köpfe mitgezogen) |
| 8 | `generate()` unter BPM-Lock loggt `.user`, nicht `.flowServo` | Audit `sequencer-core-1` | S | `EchoelStudioView.swift` (1 Zeile), `TempoInvariantTests.swift` | ✅ #1217 (Anspruch 3b) |
| 9 | **Integrations-Hub + 2 Spokes** (`integrations.html`, `reaper-osc.html`, `touchdesigner-osc.html`) mit HowTo/FAQ-JSON-LD, ADM-Leaves ab #1210 | Council Schritt 2 · Marketing Aktion 2 · Audit `output-sync-7` | S | `docs/*.html` (docs-only) | |
| 10 | `fastlane/metadata`: Keywords en/de + en-GB, Description-Erstzeilen, `colour`→`color`, „Meditativ" raus | Marketing Aktion 3 · Audit `docs-claims-4` | S + C | `fastlane/metadata/**` | Kopie → Council; `deliver` erst nach Founder-Lesung |
| 11 | Website-Stale-Copy: meta description, „not planned"-Sätze, Specs-Kachel, spielbares Visual + externer Bildschirm | Marketing Aktion 4 · Audit `docs-claims-2/3/5/7` | S | `docs/index.html`, `docs/overview.html`, `docs/tools.html` | ✅ #1238 (`d30f39b`; `tools.html` brauchte nichts — trug die Bühne schon; Store-Text → Zeile 10) |
| 12 | Richtung 3 schließen (a): `._2_0`-UMP-Virtual-Source neben der `._1_0`-Quelle, Schalter im `midiOutSection` | Council Schritt 3a | S | `Audio/MIDIOutput.swift` + Wächter | |
| 13 | Richtung 3 schließen (b): MPE-IN-Zonen — zweiter Verbraucher zuerst (`PLAN_MPE_ZONES_2026-09-01.md`); `TheMPEInputHasNoZonesTests` bewusst rot und umgeschrieben | Council Schritt 3b | S + C | Sequencer/Audio | M |
| 14 | MPE per-note expression VOR dem Note-on senden | Audit `output-sync-5` | S | `MIDIOutput.swift` | ✅ #1221 (Reihenfolge getauscht, Bytes identisch; Anspruch 12 in `TheMPEInputHasNoZonesTests`) |
| 15 | OSC-in Control-Whitelist (`NWListener`, `/echoelmusic/ctrl/*`, `bpm` nur `.studioLocked` über neuen `TempoSource`-Fall `.remoteControl`, Opt-in default AUS, Loopback-Test) | Council Schritt 4 | S + C | `Sync/`, `PatchbayView`, `TempoInvariantTests` | M |
| 16 | Step-Clock: Ideal-Deadline statt `.now()+interval` (Re-Anker nach Suspend) | Audit `sequencer-core-2` | S → F | `PatternEngine.swift`, `TempoStabilityTests.swift` | ✅ #1223 (`nextTickUptime` + `TickAnchor`, reiner Helfer `nextDeadline`; Wächter `TheStepClockKeepsItsGridTests` im BLOCKIERENDEN Bundle statt in `TempoStabilityTests`; NEEDS-FOUNDER-VERIFY am Helfer: 16 Takte gegen den Click) |
| 17 | EIN End-to-End-Render-Wächter `TheDDSPRenderIsDeterministicAndBoundedTests` | Audit `tests-guards-3` | S | `Tests/CISmoke/` | ✅ #1228 (vier Ansprüche auf den SAMPLES; NICHT transkribierbar — der erste Lauf ist das CI-Run-Tests-Job) |
| 18 | PrivacyInfo-Wächter (zwei `- path: Resources/PrivacyInfo.xcprivacy` + `buildPhase: resources`) | Audit `ship-path-4` | S | `Tests/CISmoke/` | ✅ #1222 (`ThePrivacyManifestIsDeclaredForBothTargetsTests`, präventiv GRÜN/GRÜN) |
| 19 | Anker-Skip-Ratchet (`throw XCTSkip` ohne `fileExists` ≤ heute) + `gh-test-verdict.py:105` Zahl → Befehl | Audit `tests-guards-2` (Widerleger: Migration = #806-Sackgasse, Ratchet ist die kleine Form) | S | `Tests/CISmoke/`, `scripts/` | |
| 20 | `Package.swift`-Kommentar: Xcode baut schon Swift 6 | Audit `ship-path-5` | S | `Package.swift` | ✅ #1226 (Kommentar ehrlich; Angleichung tools-version 6.0 bleibt Council) |
| 21 | Niedrige Hygiene in Reihe: `studio-ui-1` (showVisual-Notiz), `audio-dsp-2` (Koeffizient cachen), `audio-dsp-4`, `bio-pipeline-4/5/6`, `studio-ui-3/5`, `sequencer-core-3/4/5`, `ship-path-6`, `tests-guards-6/7`, `output-sync-6` | Audit | S | je 1–2 Dateien | `bio-pipeline-5` ✅ #1224 · `audio-dsp-4` VERWORFEN (Wächter-Kopf in `ANonFiniteControlCannotReachTheRenderTests` hält die Kette absichtlich unrepariert — NaN-geschlossen per Vergleich; der Vorschlag re-litigiert eine aufgeschriebene Entscheidung) · `sequencer-core-3` ✅ #1225 · `ship-path-5` ✅ #1226 (Kommentar) · `studio-ui-3` ✅ #1227 · `output-sync-6` ✅ #1229 · `tests-guards-6` ✅ #1230 · `sequencer-core-5`(a) ✅ #1231 · `tests-guards-7` ✅ #1232 · `studio-ui-1` BEREITS ERLEDIGT (#1105 hat den Absatz auf die Field-Toggle-Tür umgeschrieben) · `bio-pipeline-4` ✅ #1233 · `ship-path-6` ✅ #1234/#1234b (Manifest; Wächter parst jetzt) · `studio-ui-5` ✅ #1235 · `bio-pipeline-6` ✅ #1236 (alle VIER Felder gegated, Gurt-Parität) · `sequencer-core-4` ✅ #1237 (Reviewer safe-with-note; Folge-Kandidat: `var`→`let` auf den Ring-Wörtern) |
| 22 | **Ableton Link (LinkKit, Loop-only)** — NUR nach Entitlement-Zusage + Lizenz-Ja + Founder-Frage 4; `Sync/LinkClock.swift` hinter `#if canImport(LinkKit)`, fünfter `TempoSource`-Fall `.link` nur unter `.studioLocked`; „zero external deps" verlässt Store/Website im selben Commit | Council Schritt 5 | F (Entitlement, `project.yml`) + S + C | founder-gated | HOLD bis Zusage |
| 23 | **AUv3-Epic Grundstein** (Target `EchoelmusicAUv3`, `aumu`, Shared-Code-Entscheid, 6 Kopie-Wächter im selben Commit) — NUR nach Ship-Gate 1+5 und gemeldeter Warm-Sequenz | Council Schritt 6 | F (Mac-Nachmittag) + C | `project.yml`, Info.plist, Entitlements, `testflight.yml` | HOLD |
| 24 | AUv3 Scheibe 1 „hello aumu" (stumm, Deploy-Budget 1) → Scheibe 2 Stimme → Scheibe 3 Bio (`isFresh` sichtbar) → optional `aumi` | Council Schritte 7–10 | S + F | — | HOLD |
| 25 | „Echoel Live" (SharePlay, v1.1, Jahres-Abo) | Council Schritt 11 · Beschluss 2026-07-10 | F + C | `project.yml` (Capability), ASC | HOLD |

**Bewusst NICHT geplant (Workstation-Form, Council Schritt 12):** AUv3-HOSTING, Timeline/Multitrack-
Fläche, RTMP/SRT via HaishinKit, NDI, visionOS-Target, In-App-Social-Scheduler, ILDA-Streams —
jeweils nur nach eigener Founder-Zeile in `decisions.csv` und eigener Grand-Council-Epic.

## 2. Founder-gated (berichten, nicht editieren) — die Liste für den Mac

1. `auto-merge-claude.yml` wartet auf kein Gate; Archiv-Job hängt nicht am Compile-Check (`ship-path-2`, #683).
2. `full-tests.yml` `continue-on-error: true` → die 313-Datei-Suite kann nichts rot machen (Doctor Sektion A, #208).
3. `ci.yml` Test-Filter nennt `ComprehensiveTestSuite`, die nicht existiert (Doctor Sektion A).
4. Ein Workflow pinnt Xcode 16.2/macos-15; `project.yml` `MARKETING_VERSION`-Fallback 94 Versionen zurück (`ship-path-8`).
5. `NSBonjourServices`: 9 Typen, 3 mit Code (`ship-path-7`).
6. Multicast-Entitlement-Antrag (Council Schritt 0) — 0 Code, unbekannte Apple-Latenz.
7. ASC: Titel/Subtitle/Sekundärkategorie (Marketing §3), `robots.txt`-AI-Öffnung (Marketing §4).
8. Cron `trig_01Mio4dc5T4KJPfRZKguy9mn` (aus der Übergabe der Parallel-Sitzung `HANDOVER_2026-09-10.md`): löschen, pausieren oder umhängen.

## 3. Die fünf Founder-Fragen (aus Council §9, hier nur die Nummern)

1 Hosting bleibt CUT? (Empfehlung ja) · 2 „Echoel ALS AUv3" als Epic nach Ship-Gate 1+5? (ja, bedingt) ·
3 Multicast-Entitlement heute beantragen? (ja) · 4 LinkKit als erste Dependency, Loop-only? (ja, nach
Zusage) · 5 Sperrfrist auf `decisions.csv:302` bis v1 abgenommen? (ja). Antwortet der Founder anders,
steht in Council §9, was sich je Frage verschiebt.

## 4. Was diesen Plan rot machen darf

- Ein rotes Gate auf #1208–#1210 → Build-Rot ist die einzige Priorität, alles andere wartet.
- Ein VERIFIED-Datum, das einem Zyklus widerspricht (z. B. der Renderer bewegt sich nach #1210 nicht).
- Eine Founder-Antwort auf Frage 1 mit „Nein" — dann wird Schritt 23 zur Grand-Council-Epic mit
  Flip Nr. 19, und die Zyklen 3–21 bleiben trotzdem die Reihenfolge.
