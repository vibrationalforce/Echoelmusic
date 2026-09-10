# Deep Audit 2026-09-10 — Echoelmusic als Ganzes, acht Bereiche, adversarial verifiziert

> **Founder-Ask (2026-09-10):** „Echoelmusic als gesamtes einmal überprüfen und optimieren … im Apple Developer
> Korrekturschleifen Modus. Du bist ein Experten Team aus Apple Musicproduction, Multimedia, VR/XR, UX UI Design,
> multidimensional, Apple Ökosystem, Hardware sämtlicher Bereiche." — Dieser Report ist die Prüfung; die
> Korrekturschleife beginnt in §4 und ihre ersten Zyklen sind in dieser Sitzung gefahren (siehe SESSION_LOG).
>
> **Methode:** Workflow `wf_10b5b2cb-0c8`, gemessen auf `claude/echoelmusic-review-optimize-u5jjpd @ ffd334e`
> (identisch mit `origin/main` bis #1206b; #1207/#1207b sind nachträglich gemerged und ändern keinen Befund —
> sie betreffen `SynthPatch`/`EchoelLFO`, die kein Prüfer beanstandet hat). 8 read-only Prüfer, je einer pro
> Bereich; danach adversariale Verifikation: 2 Widerleger je kritisch/hoch (Linse „Evidenz reproduzieren" und
> Linse „gegen Gesetz und Historie"), 1 je mittel, keiner bei niedrig. **47 Agenten gestartet, 45 fertig; zwei
> starben am Sitzungslimit** — der Widerleger von `tests-guards-8` und die Synthese-Stufe. Dieser Report ist
> deshalb von der Sitzung aus den strukturierten Befunden geschrieben, nicht vom Workflow synthetisiert; die
> Rangliste und die Bereichs-Abschnitte sind maschinell aus den Befund-Objekten erzeugt (Evidenz und
> Prüfer-Urteile wörtlich), Gesamtbild und Korrekturschleife sind Handarbeit.
>
> **Zahlen dieses Laufs (nur für diesen Lauf gültig, nicht nachzählbar):** 54 Befunde, 45 überlebend
> (davon 23 mit Widerleger-Urteil, 22 niedrige ohne), 9 widerlegt. Alle Zahlen IN den Befunden tragen ihren
> Befehl — den Befehl ausführen, nicht die Zahl zitieren.

## 1. Gesamtbild in fünf Sätzen

Der Kern ist solide: Render-Pfade der vier lebenden Stimmen und die drei Taps sind sauber auf den
Audio-Thread-Verboten, `DSP/` importiert exakt {Foundation, Accelerate}, die Bio-Pipeline hält das 1-Hz-Gesetz,
und das blockierende Bundle pinnt die Prosa dieses Repos so dicht, dass die Prüfer bei den meisten Status-Fragen
den Quelltext ehrlicher fanden als die Gesetzesdatei. Fragil ist die **Ausgabestufe nach außen**: ADM-OSC sendet
seit seiner Entstehung eine Adressform, die es in der Spec nicht gibt (`/position/azimuth` statt `/azim` — jeder
konforme Renderer verwirft jede Nachricht; von der Sitzung selbst gegen `docs/adm-osc.bs` Zeilen 116–122
nachgeprüft), Art-Net startet auf einer Broadcast-Adresse, die iOS ohne Entitlement stumm verwirft, und sACN/Art-Net
kennen weder Keep-alive noch `Stream_Terminated` — drei Befunde, die genau die Fähigkeit betreffen, mit der die
Identitätszeile und der Grand Council von heute Echoel „im Rig" positionieren. Die zweite fragile Zone ist die
**Bio-Ehrlichkeit der Quellen**: die Kamera kann bei Ruhepuls strukturell keine Kohärenz liefern (Servo und die
vier LIVE-Kohärenz-Abbildungen laufen dort auf dem Neutral 0,5 — in drei Quelldateien dokumentiert, in
`CLAUDE.md` nicht), der Gurt stempelt einen eingefrorenen Puls sekündlich frisch, HealthKit veröffentlicht bis zu
59 Minuten alte Proben als frisch. Ein Review-Blocker der billigen Sorte steht offen: ein HealthKit-App ohne
In-App-Link zur Datenschutzerklärung (5.1.1(i)). Und die Prüfschleife selbst bleibt der gemessene Engpass — 83 %
des blockierenden Bundles liest Text, es gibt null Performance-, null Golden-Audio-Tests, ~91 Anker-Skips öffnen
nach oben, und `python3 scripts/founder-verify.py` zählt 116 offene Geräte-Bitten in 103 Dateien bei 0
Antworten.

## 2. Rangliste der bestätigten Befunde

Sortierung: Schwere, dann Aufwand (billig zuerst), dann nicht-founder-gated zuerst. Schwere ist die des Prüfers; wo ein Widerleger sie niedriger setzte, steht das in der Spalte „Prüfer“. „unv.“ = niedrige Schwere, bewusst ohne Widerleger.

| Rang | ID | Schwere | Art | Titel | Aufwand | Founder-gated | Prüfer |
|---|---|---|---|---|---|---|---|
| 1 | `output-sync-1` | kritisch | Defekt | ADM-OSC output uses a non-existent `/position/…` address shape; spec v1.0 is `/azim` `/elev` `/dist` `/x` `/y` `/z` | M | nein | 2× bestätigt (Schwere → hoch, hoch) |
| 2 | `output-sync-2` | hoch | Risiko | Art-Net defaults to limited broadcast 255.255.255.255, which iOS gates behind the multicast/broadcast entitlement the app does not hold | S | nein | 2× bestätigt (Schwere → mittel) |
| 3 | `ship-path-1` | hoch | Risiko | No in-app link to the privacy policy — App Review 5.1.1(i) for a HealthKit app | S | nein | 2× bestätigt (Schwere → mittel) |
| 4 | `bio-pipeline-3` | hoch | Status-Drift | The camera cannot produce coherence at a resting pulse, so the Flow servo and the four LIVE coherence mappings run on the neutral 0.5 on the flagship source — documented in three source files, absent from CLAUDE.md | M | nein | 2× bestätigt |
| 5 | `output-sync-3` | hoch | Defekt | sACN and Art-Net send only on change: no keep-alive, and stop() never sends E1.31 Stream_Terminated | M | nein | 2× bestätigt (Schwere → mittel) |
| 6 | `tests-guards-2` | hoch | Risiko | Anchor-miss XCTSkip is a fail-open path in ~91 sites, and the only skip detector is an unvalidated regex over a tail-200 window | M | nein | 2× bestätigt (Schwere → niedrig) |
| 7 | `audio-dsp-1` | mittel | Defekt | EchoelDelay.tone is the unswept sibling of #1206b: NaN-transparent clamp on the one-pole INSIDE the feedback write-back (ring-buffer latch that never heals); timeSeconds latches too | S | nein | 1× bestätigt |
| 8 | `bio-pipeline-1` | mittel | Defekt | Polar publish loop re-stamps a frozen HR every second and ignores the HRM sensor-contact bits | S | nein | 1× bestätigt |
| 9 | `bio-pipeline-2` | mittel | Risiko | HealthKit publishes a heart-rate sample up to 59 minutes old as a receipt-fresh frame with a 90 s usable window | S | nein | 1× bestätigt |
| 10 | `studio-ui-1` | mittel | Status-Drift | In-file note asserts a live `showVisual` door and 'no inline donut toggle' — both false since #1065/#1069 | S | nein | 1× bestätigt |
| 11 | `studio-ui-2` | mittel | Status-Drift | CLAUDE.md PERFORMANCE table rates the shipped design as FAIL: 'Visual FPS 120fps' and 'Bio Loop 120Hz' vs. a deliberately pinned 60 fps and a ~1 Hz bio apply rate | S | nein | 1× bestätigt |
| 12 | `sequencer-core-1` | mittel | Defekt | generate() under the BPM lock records its tempo as `.flowServo` — the T1 log line names the servo for a user decision | S | nein | 1× bestätigt |
| 13 | `ship-path-3` | mittel | Status-Drift | CLAUDE.md says the Watch is 'ausgeliefert'; project.yml keeps the embed commented out — no watch app ships | S | nein | 1× bestätigt |
| 14 | `ship-path-4` | mittel | Risiko | Nothing guards the PrivacyInfo.xcprivacy declaration in project.yml — the 2026-07-21 'manifest never shipped' failure can recur silently | S | nein | 1× bestätigt |
| 15 | `ship-path-5` | mittel | Status-Drift | Swift language mode diverges: Xcode builds in Swift 6 mode, SwiftPM in Swift 5 with -warnings-as-errors — Package.swift's own comment argues against a state that already ships | S | nein | 1× bestätigt (Schwere → niedrig) |
| 16 | `docs-claims-2` | mittel | Chance | The touch-playable visual is sold nowhere on the acquisition pages — only faq.html carries it | S | nein | 1× bestätigt |
| 17 | `docs-claims-3` | mittel | Chance | External-display stage (USB-C/HDMI/AirPlay) is missing from BOTH App Store descriptions and from index.html | S | nein | 1× bestätigt |
| 18 | `tests-guards-3` | mittel | Risiko | Honest ratio: 83 % of the blocking bundle scans text; zero performance tests, zero golden-audio renders, one skippable shader-compile test | S | nein | 1× bestätigt |
| 19 | `tests-guards-8` | mittel | Status-Drift | Founder-verify queue: 116 open device asks in 103 files, none answered — the two open ship-gate checks cannot be closed by any session | S | ja | unv. |
| 20 | `output-sync-7` | mittel | Chance | No published integration surface for VJ/lighting operators: the OSC schema lives only in an unlinked dev doc, no TouchOSC/TouchDesigner template, sACN priority not settable | M | nein | 1× bestätigt |
| 21 | `sequencer-core-2` | mittel | Risiko | The step clock re-arms from `.now()` inside its own handler, so main-thread latency accumulates into the note clock while click and MIDI clock keep absolute cadence | M | nein | 1× bestätigt |
| 22 | `ship-path-2` | mittel | Risiko | Auto-merge to main still waits for no gate (#683), the TestFlight archive never runs tests, and the archive job does not depend on the compile check | M | ja | 1× bestätigt |
| 23 | `audio-dsp-2` | niedrig | Performance | EchoelDelay recomputes powf+expf per sample for a constant control; its sibling EchoelLoFiFX caches the identical coefficient in didSet | S | nein | unv. |
| 24 | `audio-dsp-4` | niedrig | Risiko | PolySynthVoice.clampUnit and BioEntrainmentDirector.target use the NaN-transparent clamp on the path that writes voice.entrainment.depth — the sibling of #1194's SubBassVoice fix | S | nein | unv. |
| 25 | `audio-dsp-5` | niedrig | Chance | SamplerVoice is the only source node pinned to 44.1 kHz in a 48 kHz graph — the always-attached previewVoice pays a sample-rate converter on every render | S | nein | unv. |
| 26 | `bio-pipeline-4` | niedrig | Status-Drift | The bio strip shows HealthKit HRV as a unit-less normalized number although the frame carries the measured SDNN in ms | S | nein | unv. |
| 27 | `bio-pipeline-5` | niedrig | Defekt | CoherenceTrend holds a stale derivative when the SAME source stops measuring, while the level goes neutral on that very frame | S | nein | unv. |
| 28 | `bio-pipeline-6` | niedrig | Hygiene | Camera HRV metrics reach the bus and OSC without RRIntervalHygiene, while the analyzer header credits consumers with running it — only a doorless view does | S | nein | unv. |
| 29 | `studio-ui-3` | niedrig | Hygiene | `shouldAutoPlay` is dead plumbing: bound through onboarding, never written, never read | S | nein | unv. |
| 30 | `studio-ui-5` | niedrig | Hygiene | `ADMStreamStatusLine` is transitively doorless and guarded, but absent from the CLAUDE.md register | S | nein | unv. |
| 31 | `output-sync-5` | niedrig | Defekt | MPE per-note expression is sent AFTER the note-on; MPE practice is to state Bend/CC74/Pressure immediately BEFORE it | S | nein | unv. |
| 32 | `output-sync-6` | niedrig | Status-Drift | 'MIDI 2.0' in the positioning line is input-only; MIDI out is MIDI 1.0 protocol and the MIDI 2.0 word builders have no production caller | S | nein | unv. |
| 33 | `sequencer-core-3` | niedrig | Hygiene | A fourth `register(defaults:)` for `instrumentHome` still sits in the startup `.task` that its own pointer comment says was emptied by #580 | S | nein | unv. |
| 34 | `sequencer-core-4` | niedrig | Performance | SPSCQueue: ordering is correct on arm64, but the three diagnostic counters are separate 8-byte mallocs (shared cache line, full-barrier RMW per op on the audio thread) and `enqueue()` RMWs the consumer's `head` line | S | nein | unv. |
| 35 | `sequencer-core-5` | niedrig | Chance | MIDI export floors 480-PPQ note ticks to 96 PPQ, discarding recorded/microtimed offsets; the shared `Humanizer` documents its ticks in 96 PPQ but `TouchQuantizer` applies them in 480 | S | nein | unv. |
| 36 | `ship-path-6` | niedrig | Hygiene | Privacy manifest declares Disk Space (E174.1 'display disk space to the user') with zero disk-space API calls, and uses the SDK-only reason 0A2A.1 | S | nein | unv. |
| 37 | `docs-claims-4` | niedrig | Hygiene | de-DE release notes diverge from en-US on the genre bullet and use "Meditativ", a word CLAIMS.md §2 bans — while the app's own shelf is literally "Meditative & Ambient" | S | nein | unv. |
| 38 | `docs-claims-5` | niedrig | Risiko | Hero copy "compose music to calm down" is an effect promise, the exact phrasing CLAIMS.md §2 draws the line at | S | nein | unv. |
| 39 | `docs-claims-7` | niedrig | Hygiene | index.html "Specs" tile lists Open Standards as "OSC · ADM-OSC · Art-Net" — sACN and MIDI (both shipped and sold on the same page) are dropped | S | nein | unv. |
| 40 | `tests-guards-6` | niedrig | Status-Drift | `EchoelWSOLA` is a 206-line DSP core with zero production constructors, yet `StretchMode.beats.isImplemented` returns true and a test pins that as 'WSOLA pre-render' | S | nein | unv. |
| 41 | `tests-guards-7` | niedrig | Hygiene | The always-loaded naming law `test[Unit]_[Scenario]_[Expected]` is followed by 0 of 3151 blocking-bundle methods | S | nein | unv. |
| 42 | `sequencer-core-6` | niedrig | Risiko | A tempo automation lane bypasses the user's BPM lock every transport step, while the modulation route honours it — two tempo sources, two precedence rules | S | ja | unv. |
| 43 | `sequencer-core-7` | niedrig | Status-Drift | `ProGate.proFeatures` still lists `.auv3Plugin` and `.videoFXCatalog` — two capabilities the founder removed — as the paid set the store is to be repurposed around | S | ja | unv. |
| 44 | `ship-path-7` | niedrig | Hygiene | NSBonjourServices lists nine service types; only three have a browser or advertiser in code | S | ja | unv. |
| 45 | `ship-path-8` | niedrig | Hygiene | One workflow pins Xcode 16.2/macos-15 against a project written for Xcode 26, and the project.yml MARKETING_VERSION fallback is 94 versions behind | S | ja | unv. |

### Widerlegt (nicht erneut finden)

Jeder Eintrag: der Grund des Widerlegers in einem Satz. Die MESSUNG stimmt in fast allen Fällen; widerlegt ist der SCHLUSS oder die Schwere.

- **`audio-dsp-3`** (mittel) — CLAUDE.md PERFORMANCE row 'Audio Latency <10 ms / FAIL >15 ms' is unmeetable on the shipped default by design (512 frames = 10.67 ms IO buffer alone; founder-measured floor ~23 ms)
  → The bare arithmetic reproduces: `grep -n 'Audio Latency' CLAUDE.md` → line 370 `<10ms | >15ms`; `AudioConfiguration.swift:44` `normalBufferSize = 512` with doc "512/48000 = 10.67ms" and line 61 conceding only the "<15 ms latency FAIL line". So the <10 ms TARGET is above the shipped IO-buffer default — that kernel is real. But the finding's load-bearing evidence and its proposed replacement text are wrong in three places, and the fix would write two new falsehoods into the always-loaded file: (1) "founder-measured r…
- **`studio-ui-4`** (mittel) — iPhone landscape is enabled in Info.plist but the root chrome reads no size class — the only adaptive element is the panel card grid
  → REPRODUCED (literal greps): `grep -nE -A5 UISupportedInterfaceOrientations Resources/iOS/Info.plist` → Portrait+LandscapeLeft+LandscapeRight for iPhone (:51–56). `grep -E 'verticalSizeClass|horizontalSizeClass' Sources/Echoelmusic/Studio/WorkspaceView.swift | grep -vc '^\s*//'` → 0; same on SurfaceSwitcher.swift → 0; EchoelStudioView.swift → exactly :11464/:11465 inside `private struct AdaptiveCardGrid`, columns = `(hSize == .regular || vSize == .compact) ? 2 : 1`. `menuBar` is `ScrollView(.horizontal` at :2855. Al…
- **`studio-ui-6`** (mittel) — Chip IA hides both product pillars: the visual panel is labelled 'Field' and the bio panel has no chip at all
  → THE OBSERVATION REPRODUCES; THE FRAMING AND THE FIX DO NOT. Re-derived: `sed -n 2761,2762p Sources/Echoelmusic/Studio/EchoelStudioView.swift` → `[.sound, .effects, .mix, .master, .mood, .composition, .field, .export]` (exact); labels at :870–899 read Bio/Tempo/Sound/Mix/FX/Master/Mood/Save/Export/Field/Video; `case .field: return AnyView(visualPanel)` at :3149; fullName "Field — the visual surface you play with your fingers" at :943; `.bio` at :867 absent from the strip; `git grep -n 'echoelChromeDoor, object: "bio…
- **`output-sync-4`** (mittel) — Every sender's `isActive` means 'route on', never 'socket viable' — NWConnection state is not observed anywhere
  → Reproduced: `git grep -n 'stateUpdateHandler\|viabilityUpdateHandler' -- Sources` → 0 (exit 1); `git grep -c 'contentProcessed { _ in }' -- Sources/Echoelmusic/Sync` → 4 files, one hit each; the four connect() bodies at OSCSender.swift:171-177, ADMOSCSender.swift:175-181, ArtNetSender.swift:190-199, SACNSender.swift:169-175 are as quoted; `isActive = true` sits one line after connect() in all four (OSCSender:120, ADMOSCSender:133, SACNSender:130, ArtNetSender:151). Those facts hold. What does NOT hold is the findin…
- **`docs-claims-1`** (mittel) — Website says "four generative looks" — the shipped look library has five (Dish, #1102)
  → Every command in the evidence reproduces exactly: `sed -n 51,53p Sources/Echoelmusic/Studio/LookBlendMap.swift` shows five entries including `(2, "Dish")`; the customizer `ForEach(LookBlendMap.library` is at EchoelStudioView.swift:6029 and is mounted inside the reachable `visualPanel` (`visualLookCustomizer` at :5243 under the "Look" collapsible, `showFieldLook` defaults true); `"Dish"` is at FlashGuard.swift:318; `grep -rn 'four generative looks' docs/` gives the same five hits (index.html:104, :803; faq.html:44, …
- **`docs-claims-6`** (mittel) — doctor.py: 2 CRITICAL — masked CI build steps and a test filter naming a suite that does not exist (founder-gated)
  → Re-ran everything. What reproduces: `python3 scripts/doctor.py` section A prints exactly 2 CRITICAL; `git grep -n 'class ComprehensiveTestSuite' -- Tests | wc -l` → 0 (the only repo hits are ci.yml:290-291 and scratchpads); `grep -c ComprehensiveTestSuite scratchpads/HARNESS_LEDGER.md` → 1, `grep -c ... CLAUDE.md` → 0; `python3 scripts/foreign-needles.py` → "no broken needle" (64 checked). The phantom filter is real and founder-gated. What does NOT reproduce / is misread: (1) the evidence says `.github/workflows/fu…
- **`tests-guards-1`** (hoch) — `swift test` (RALPH step 5, SESSION START, Phase 2/3, KEY TESTS) never runs the blocking bundle — Tests/CISmoke is not a SwiftPM test target
  → MECHANICAL HALF REPRODUCES: `grep -c CISmoke Package.swift` → 0; `sed -n '100,108p' Package.swift` shows the lone `.testTarget(name: "EchoelmusicTests", dependencies: ["Echoelmusic"])` with no `path:`; `sed -n '355,360p' project.yml` → `EchoelmusicTests: … sources: - path: Tests/CISmoke`; counts 313 / 487 confirmed; the six `swift test` lines in CLAUDE.md are at 450/484/574/819/821/826 as cited. THE CENTRAL CLAIM IS REFUTED: "Nobody documents the gap" is false — the auditor's negative grep was scoped to a hand-pick…
- **`tests-guards-4`** (mittel) — The `prefix(N)` latent-red surface grew 35 → 45 since the 2026-08-30 playbook while the repair helper has 6 adopters and the measuring tool resolves 6 of 45
  → Re-ran every evidence command. The counts reproduce: shape census → 45; `git grep -l 'codeWindow(' -- 'Tests/CISmoke/*.swift' | wc -l` → 6 (one of them is `SourceText.swift`, the definer, so 5 real adopters); `scripts/window-margins.py` → "6 measured, 39 unresolved"; the 7 `prefix(400|700|1_800)` sites in `TheEngineLifecycleSpeaksInTheDiagLogTests.swift` exist at lines 513/602/653/670/798/826/914 and all 7 are listed unresolved. What does NOT reproduce is the cluster's characterisation, its mechanism, and therefore…
- **`tests-guards-5`** (mittel) — Ten production files in the audio/bio/video path have zero code-level test references — three of them are pure and cheaply testable
  → THE MEASUREMENT REPRODUCES; THE MOTIVATION AND ALL THREE PROPOSED GUARDS DO NOT. Re-derived with a comment/string-stripping script (scratchpad verify_tg5_untested.py, regex `\b<Name>\s*(\(|\.[a-zA-Z])` over `git ls-files 'Tests/**/*.swift'`): all ten zero-ref rows are 0, CameraAnalyzer=2, RetroCapture=2, EchoelGranular=1, `git grep -lE '\bMonitorInsertAU\('`/`EchoelWSOLA\(` → 0/0, and every cited line count matches `wc -l`. As an inventory the finding is accurate. But the severity rests on "pure enough to drive fro…

## 3. Je Bereich

### Audio-Engine + DSP (`audio-dsp`)

The render paths of the four live source nodes (BioReactiveSynthVoice, PolySynthVoice, SubBassVoice, MetronomeVoice) and the three taps in AudioEngine are clean on the audio-thread bans: every mutation is drained from SPSC queues inside the render, output is swept by AudioOutputGuard, tails past the scratch window are zero-filled, and the only allocations found in DSP/ are init-time or in offline/test-only processors (EchoelFDNReverb/EchoelSpaceReverb have zero production constructors; EchoelBiquadCascade/EchoelDecimator have zero callers outside DSP/). DSP/ imports exactly {Foundation, Accelerate} across 40 files with the one known unguarded Accelerate import in EchoelWSOLA (already recorded in swift-audio.md). Session configuration is careful (48 kHz ask, granted-rate read-back and buffer re-ask, AVAudioEngineConfigurationChange watchdog). The #1194–#1206b crackle/NaN round did leave siblings: the same NaN-transparent clamp idiom that #1206b called a class sits on EchoelDelay's `tone` — the one-pole that lives INSIDE the feedback write-back, i.e. the exact ring-buffer latch #1206b fixed on the flanger — and #588's own migration of that file stopped one line short; the same idiom also survives on the PolySynthVoice entrainment path (the sibling of #1194's SubBassVoice fix). Two cheap improvements sit beside them (per-sample powf/expf in the delay tone coefficient; a 44.1 kHz sampler node in a 48 kHz graph), and CLAUDE.md's latency row asserts a target the shipped 512-frame default cannot meet by design.

#### `audio-dsp-1` — EchoelDelay.tone is the unswept sibling of #1206b: NaN-transparent clamp on the one-pole INSIDE the feedback write-back (ring-buffer latch that never heals); timeSeconds latches too

**Schwere:** mittel · **Art:** Defekt · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n 'Swift.min(Swift.max(tone' Sources/Echoelmusic/DSP/EchoelDelay.swift` → line 215 in `toneCoefficient()` (`let fc = 800.0 * powf(20.0, Swift.min(Swift.max(tone, 0.0), 1.0))`). `sed -n 163,175p Sources/Echoelmusic/DSP/EchoelDelay.swift` shows `let g = toneCoefficient(); lpL += g * (rawFbL - lpL) + 1.0e-20; ... var wL = inL + lpL * fb; ... left.write(wL)` — the tone filter state feeds the write-back, so one NaN `g` poisons `lpL/lpR` and the ring buffer permanently (EchoelDelayLine.readAllpass header: the drain that would call `reset()` is gated on output < 1e-5, and `NaN < 1e-5` is false). `tone` is a bare stored property (`grep -n 'public var tone' Sources/Echoelmusic/DSP/EchoelDelay.swift` → line 43, no didSet). Same file, same function: `#588` migrated `feedback`/`mix`/`spread` to `clamped(to:)` (lines 110/111/138) and stopped there. `timeSeconds` (line 35) is also unguarded: `timeSmoothed += timeGlide * (timeSeconds - timeSmoothed)` (line 114) makes `timeSmoothed` NaN forever once a NaN arrives; `Swift.max(1.0, NaN)` on line 141 then returns 1.0, so the delay collapses to one sample until `reset()`. Guard coverage: `grep -nE '\.tone *= *\.nan|timeSeconds *= *\.nan' Tests/CISmoke/ANonFiniteControlCannotReachTheRenderTests.swift` → 0 (the file tests only `feedback` and `mix` NaN on EchoelDelay, lines 254–290). Producer status: latent as #1206 measured (JSONDecoder default throws on NaN; UI field is `0...1`; `FXPreset.morphed(to:amount:)` with a NaN `amount` is the one named route, EchoelModFX.swift:272). Writers: `git grep -nE 'delay\.tone *=' -- Sources` → FXPreset.swift:483, GenreFX.swift:251, EchoelFXView.swift:221.
```

**Warum:** #1206b's commit text states the law this violates: a slice that names a defect CLASS must enumerate it in the files it touches, and the flanger feedback latch it fixed is byte-for-byte the mechanism here — a NaN written into an EchoelDelayLine ring never heals because the sleep drain cannot see it. The delay is enabled by genre presets on both live chains (PolySynthVoice, BioReactiveSynthVoice), so a single non-finite control value would silence the delay stage for the rest of the session. It is the same class CLAUDE.md records as having 'caused shipped permanent-silence bugs'.

**Vorschlag:** Sources/Echoelmusic/DSP/EchoelDelay.swift: in `toneCoefficient()` replace the idiom with `tone.clamped(to: 0...1)` (lower bound 0 = dark, a safe neutral); guard the glide with `if timeSeconds.isFinite { timeSmoothed += ... }` (or clamp `timeSeconds` to `0...maxDelaySeconds` via `clamped(to:)`). Tests/CISmoke/ANonFiniteControlCannotReachTheRenderTests.swift: add two claims in the shape of tests 4–5 (`d.tone = .nan` and `d.timeSeconds = .nan`, then 4096 frames of finite output and a non-zero wet signal afterwards). Two files. Combine with audio-dsp-2 — caching the coefficient in a `didSet` puts the clamp in one place.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Reproduced every command. `grep -n 'Swift.min(Swift.max(tone' Sources/Echoelmusic/DSP/EchoelDelay.swift` → line 215 inside `toneCoefficient()`; `grep -n 'public var tone'` → line 43, bare stored property, no didSet. `sed -n 95,180p` confirms the flow: `let g = toneCoefficient(); lpL += g * (rawFbL - lpL) + 1.0e-20; var wL = inL + lpL * fb; ... left.write(wL)` — the tone-filter state is on the ring-buffer write-back. NaN transparency of the idiom is stated by the repo itself (`Core/FloatingPointClamp.swift` header lines 8–14: `max(NaN, lo) == NaN`, `min(NaN, hi) == NaN`; the #588 comment in the same function says the same), and `toneCoefficient()`'s final `Swift.min(Swift.max(g,0),1)` passes …

#### `audio-dsp-2` — EchoelDelay recomputes powf+expf per sample for a constant control; its sibling EchoelLoFiFX caches the identical coefficient in didSet *(unverifiziert)*

**Schwere:** niedrig · **Art:** Performance · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n 'toneCoefficient()' Sources/Echoelmusic/DSP/EchoelDelay.swift` → line 166, inside `processStereo` (per-sample: `processBuffer` at line 189 loops `for i in 0..<n { processStereo(...) }`). The function (lines 214–218) evaluates `powf(20.0, …)` and `expf(-2π fc / sr)` every call. Contrast `grep -n 'didSet { toneG = Self.toneCoefficient' Sources/Echoelmusic/DSP/EchoelLoFiFX.swift` → line 121 and `sed -n 185,190p` there (`let g = toneG` read per sample). Live instances: `git grep -nE 'EchoelFXChain\(' -- Sources` → PolySynthVoice.swift:375 and BioReactiveSynthVoice.swift:300 (plus the doorless MonitorInsertAU chain and two library builders). At the 48 kHz node rate that is ~96,000 transcendental calls per second per chain whenever `delayEnabled` is true (`GenreFX.swift:251` writes the delay from genre presets). CPU impact UNMEASURED (no toolchain here); the buffer was already raised 256→512 against synth-induced underruns (AudioConfiguration.swift:44 comment, 10.76.49).
```

**Warum:** The additive synth is the render budget's dominant consumer and the app already traded 5 ms of latency for underrun headroom; shaving two transcendental calls per sample from a stage that is on in most genres is free headroom, and the same edit is where the audio-dsp-1 clamp belongs (one definition site, #416). Zero audible change: the coefficient is a pure function of `tone` and `sr`.

**Vorschlag:** Sources/Echoelmusic/DSP/EchoelDelay.swift: make `tone` a `didSet` property that stores `toneG` (computed with `tone.clamped(to: 0...1)`), initialise `toneG` in `init` from the default, and read `toneG` in `processStereo` — exactly the EchoelLoFiFX shape at lines 121/133/147/185. One file; the existing `FXPresetTests` round-trip of `delay.tone` (Tests/EchoelmusicTests/FXPresetTests.swift:23/60) still holds because the stored value is unchanged.


#### `audio-dsp-4` — PolySynthVoice.clampUnit and BioEntrainmentDirector.target use the NaN-transparent clamp on the path that writes voice.entrainment.depth — the sibling of #1194's SubBassVoice fix *(unverifiziert)*

**Schwere:** niedrig · **Art:** Risiko · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n 'private func clampUnit' Sources/Echoelmusic/Tools/PolySynthVoice.swift` → line 1035 `min(max(x, 0), 1)`; callers lines 1017/1019 (`applyEntrainment`), whose result is fanned to every voice: `voice.entrainment.depth = target.depth` (line 1024). `sed -n 60,74p Sources/Echoelmusic/DSP/BioEntrainmentDirector.swift`: `let c = min(max(coherence, 0), 1)` and `depth: min(max(depth, 0), Self.maxDepth)` — a NaN `coherence` yields a NaN depth (the `q >= qualityFloor` guard catches only the QUALITY half). #1194 (`git show 27f4374 -- Sources/ | grep '^[-+].*didSet'`) replaced exactly this idiom on SubBassVoice's two audio-thread mirrors and named the '#937-Form: eine Form repariert, ihr Zwilling stehen gelassen'. LATENT today: `neutralCoherence` is `BioSampleFrame.coherenceForSound` (neutral-substituted, finite) and `motionEnergy` is a constant 0 at all six `BioSampleFrame` construction sites (CLAUDE.md identity paragraph). Not covered by `ANonFiniteControlCannotReachTheRenderTests` (`grep -c 'entrainment' Tests/CISmoke/ANonFiniteControlCannotReachTheRenderTests.swift` → 0).
```

**Warum:** Entrainment depth is read on the render thread by every poly voice; the file's own header names the frame as the single owner of NaN-safety and this path bypasses it with the very spelling CLAUDE.md's max/min rule forbids for anything that reaches the audio thread. Closing it costs three lines and removes the last audio-thread-bound NaN-transparent clamp in Tools/ (`grep -rnE '(Swift\.)?min\(\s*(Swift\.)?max\(' Sources/Echoelmusic/Tools | grep -v isFinite` → 8 hits, the others are setter-side tuning/transposition ranges with finite UI inputs).

**Vorschlag:** Sources/Echoelmusic/Tools/PolySynthVoice.swift:1035 → `x.clamped(to: 0...1)`; Sources/Echoelmusic/DSP/BioEntrainmentDirector.swift:64,65,72 → `clamped(to:)` (lower bounds 0 are the neutral/off values, so NaN → inactive/zero depth, the safe direction). Two files; one behavioural claim in the existing non-finite guard (NaN coherence → `.inactive` or depth 0).


#### `audio-dsp-5` — SamplerVoice is the only source node pinned to 44.1 kHz in a 48 kHz graph — the always-attached previewVoice pays a sample-rate converter on every render *(unverifiziert)*

**Schwere:** niedrig · **Art:** Chance · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`git grep -nE 'static let sampleRate: Double = 4[48]_[01]00' -- Sources/Echoelmusic/Tools Sources/Echoelmusic/Audio Sources/Echoelmusic/Sequencer Sources/Echoelmusic/Bio` → SamplerVoice.swift:51 `44_100`; every other node (PolySynthVoice:203, SubBassVoice:187, BioReactiveSynthVoice:236, MetronomeVoice:110, SessionEngine:89) is `48_000`, and the session asks for `preferredSampleRate` 48 kHz (AudioConfiguration.swift:255). Production attach: `git grep -nE 'engine.attachSourceNode\(previewVoice' -- Sources` → BeatPlayer.swift:110, reached from `beatPlayer.attach(to: audioEngine)` at EchoelmusicApp.swift:776; a second constructor per lane at LaneVoiceRack.swift:159. `loadSample` already resamples to `Self.sampleRate` through `AVAudioConverter` (SamplerVoice.swift:99/122), so the node rate is a free choice. No test pins the constant: `git grep -nE '88_200|SamplerVoice\.sampleRate' -- Tests` → 0. Cost UNMEASURED (no toolchain); AVAudioEngine inserts a converter wherever a source-node format differs from the mixer input format.
```

**Warum:** The preview sampler is attached for the life of the engine and renders silence through a rate converter on every block; each timeline lane adds another. It is also the one node whose internal maths (ChannelInsertFX at line 300 is built from the same constant) disagrees with the rest of the graph, so a future 'why does the sampler sound different' investigation starts one converter away from everything else. Removing it is consistency and headroom, not an audible fix.

**Vorschlag:** Sources/Echoelmusic/Sequencer/SamplerVoice.swift: set `sampleRate = 48_000` and `maxSampleFrames = 96_000` (keeps the documented ~2 s ceiling; `loadSample`'s `maxSrcFrames` at line 90 already scales by the SOURCE rate). One file. State plainly in the commit that the CPU saving is unmeasured; device-verify that a browser preview still plays at pitch (the converter in `resampleToMono` now targets 48 kHz).


### Bio-Pipeline (`bio-pipeline`)

The bio pipeline is structurally as the law file describes it: the camera publishes on `tick % 10` of a 0.1 s loop (~1 Hz), every sound/OSC consumer dedupes on `frame.timestamp`, the capture thread pushes into `RGBSampleQueue` (NSLock, no actor hop) and one 10 Hz main-actor task drains it, `/echoelmusic/bio/synthetic` is emitted from `BioSource.isSynthetic` on both the batch and the event path, the reachable camera lifecycle owner is `EchoelStudioView.startBioSource()` (the two other `cameraRPPG.start` sites live in doorless `BioSourceView`/`SessionView`), Health writes are source-gated to `.ble`/`.cameraPPG` behind a reachable opt-in row, the privacy strings match the shipped uses, and the protected triad shows no diff in this clone (its only history is the graft commit). The defects found are all at the edges of that design: the Polar loop re-stamps a frozen HR at 1 Hz with no "new packet" gate and never parses the sensor-contact bits — the exact defect the camera fixed with `inboundRateEMA`; HealthKit's 1-hour query window lets a reading up to 59 min old go out receipt-stamped with a 90 s usable window; and the camera — the flagship source — cannot produce coherence at rest at all (fixed 10 s window vs `HRVCoherence.minIntervals = 16`), which silently turns the Flow servo into a constant `0.5·hr + 36` and leaves the four LIVE coherence mappings on their neutral, a fact the code documents in three files and CLAUDE.md nowhere. Two smaller science-honesty items: the strip shows HealthKit HRV as a unit-less normalized number although the frame carries real SDNN ms, and `CoherenceTrend` holds a stale derivative on the same source that just went unmeasured while the level goes neutral on the same frame.

#### `bio-pipeline-1` — Polar publish loop re-stamps a frozen HR every second and ignores the HRM sensor-contact bits

**Schwere:** mittel · **Art:** Defekt · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Sources/Echoelmusic/Bio/PolarH10BioPublisher.swift: the 1 s loop publishes whenever `RRIntervalHygiene.isPlausibleBPM(self.latestHR)` holds, with `timestamp: CFAbsoluteTimeGetCurrent()` (lines ~176–235 today) — there is no 'a notification arrived since the last publish' gate; `latestHR` is only zeroed in `stop()` and `didDisconnectPeripheral`. `parseHRMeasurement` reads flags `0x01`, `0x08`, `0x10` only: `grep -n "0x06\|sensorContact\|contactSupported" Sources/Echoelmusic/Bio/PolarH10BioPublisher.swift | wc -l` → 0. Contrast the camera, whose loop guards on `inboundRateEMA >= minMeasurableInboundHz` precisely because 'a stalled camera published a FROZEN pulse with a FRESH timestamp on every tick, which defeats freshBio/usableBio by construction' (`grep -n "FROZEN pulse with a FRESH timestamp" Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift`). Re-derive the lack of a packet-age gate: `grep -n "lastNotif\|lastPacket\|didUpdateValueFor" Sources/Echoelmusic/Bio/PolarH10BioPublisher.swift`.
```

**Warum:** Between a link loss and iOS's `didDisconnectPeripheral` (the BLE supervision timeout, seconds), and whenever a strap keeps sending a last HR with 'sensor contact not detected', the bus receives frames that `freshBio`/`usableBio` accept as live — the music, the visual, the OSC egress and the Health writer (`HealthKitWriter` writes `bus.freshBio()` every 5 s) all run on a dead body. The camera path already paid for this lesson; the strap, called 'the source we call most accurate', has the same hole.

**Vorschlag:** One file: in `PolarH10BioPublisher` (a) record `lastNotificationAt = CFAbsoluteTimeGetCurrent()` in `didUpdateValueFor`; (b) in the loop, publish only if `now - lastNotificationAt <= 3` (the HRM notifies at ~1 Hz); (c) parse flags bit 1–2 (`0x06`: contact supported + detected) in `parseHRMeasurement` and treat 'supported && !detected' as HR 0. Add a `Tests/EchoelmusicTests` case for the parser's contact bits (it is `nonisolated static`, pure).

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Re-derived every command against the tree (2026-09-10). (1) `grep -n "0x06\|sensorContact\|contactSupported" Sources/Echoelmusic/Bio/PolarH10BioPublisher.swift | wc -l` → 0; `parseHRMeasurement` (lines ~284–317) reads only `flags & 0x01`, `0x08`, `0x10` — SIG Sensor-Contact-Status bits 1–2 are never read. (2) `grep -n "lastNotif\|lastPacket\|didUpdateValueFor"` → a single hit, the delegate signature at line 469; `didUpdateValueFor` writes `self.latestHR = parsed.hr` and records no receipt time. (3) The publish loop (`startPublishing`, lines ~176–235) gates only on `RRIntervalHygiene.isPlausibleBPM(self.latestHR)` (a pure range test, `RRIntervalHygiene.swift:171`) and stamps `timestamp: CFAbs…

#### `bio-pipeline-2` — HealthKit publishes a heart-rate sample up to 59 minutes old as a receipt-fresh frame with a 90 s usable window

**Schwere:** mittel · **Art:** Risiko · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Sources/Echoelmusic/Bio/EchoelBioEngine.swift: `HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600)` (`grep -n "3600" Sources/Echoelmusic/Bio/EchoelBioEngine.swift`) and `processHeartRateSamples` takes the newest sample by `endDate` with no age check. Sources/Echoelmusic/Bio/HealthKitBioPublisher.swift `publishIfFresh`: dedupes on `snap.timestamp` (measurement time) but stamps `timestamp: CFAbsoluteTimeGetCurrent()`; `grep -n "age\|timeIntervalSince\|3600" Sources/Echoelmusic/Bio/HealthKitBioPublisher.swift` → nothing. `BioSource.freshnessWindow` for `.healthKit` = 90 (Sources/Echoelmusic/Core/EngineBus.swift, `grep -n "case .watch, .healthKit: return 90" Sources/Echoelmusic/Core/EngineBus.swift`). The receipt-stamp is deliberate and pinned for a 180 s-old measurement (`Tests/EchoelmusicTests/HealthKitBioPublisherTests.swift:23 testHealthKitFrame_stampsReceiptTime_staleMeasurementStaysUsable`), but no test or code bounds how old the MEASUREMENT may be. Consumers of `usableBio()`: `git grep -n "usableBio()" -- Sources` → BioStripView, ModulationEngine, BioFeedbackPublisher, RecordController, BioMetricInfo and more.
```

**Warum:** On start with only the Watch as source, the anchored query's initial batch delivers the newest HR from the last hour; the strip shows it as a live pulse for 5 s and the composer/modulation matrix treats it as the body for 90 s. The 180 s design case (resting Watch writes sporadically) is honest; a 45-minute-old number driving 'your body plays it' is not, and nothing distinguishes the two today. This is also the frame `HealthWritePolicy` never writes back (good) but that OSC's egress policy blocks anyway — so the exposure is in-app only.

**Vorschlag:** One file + one test: in `HealthKitBioPublisher.publishIfFresh`, after the `hasHRSample` guard, add `guard Date().timeIntervalSince(snap.timestamp) <= Self.maxMeasurementAge else { return }` with a named constant (a judgment value — 10 min is the order of magnitude; keep it larger than the pinned 180 s so the existing test stays green) and a companion test that a 45-minute-old snapshot is NOT published. State the constant's provenance at the declaration.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Every cited command reproduces on this tree (2026-09-10). `grep -n "3600" Sources/Echoelmusic/Bio/EchoelBioEngine.swift` → line 286 `withStart: Date().addingTimeInterval(-3600)`, and the comment above it (lines 279–284) states the widen is deliberate so "the latest known HR surfaces immediately". `processHeartRateSamples` (lines 365–399) takes `quantitySamples.max(by: endDate)`, guards only `30...220` BPM, writes `snapshot.timestamp = latestSample.startDate` — no age check. `grep -n "age\|timeIntervalSince\|3600" Sources/Echoelmusic/Bio/HealthKitBioPublisher.swift` → only two comment lines (122, 132), nothing executable. `publishIfFresh` (lines 95–149) has exactly three gates — `dataSource =…

#### `bio-pipeline-3` — The camera cannot produce coherence at a resting pulse, so the Flow servo and the four LIVE coherence mappings run on the neutral 0.5 on the flagship source — documented in three source files, absent from CLAUDE.md

**Schwere:** hoch · **Art:** Status-Drift · **Aufwand:** M · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`HRVCoherence.minIntervals = 16` (`grep -n "static let minIntervals" Sources/Echoelmusic/Bio/HRVCoherence.swift`); `tachogram` returns nil below it. The camera rebuilds `rrIntervals` whole from one peak window each `detectPeaks` (`grep -n "rrIntervals = cleanIntervals" Sources/Echoelmusic/Video/CameraAnalyzer.swift` → two sites), never accumulating. The code says so itself: Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift ~2155 '16 intervals needs ≥17 clean peaks in 10 s, i.e. a sustained ≳102 bpm … at any resting pulse `lastValidCoherence` stays 0 for the whole process'; Sources/Echoelmusic/Sync/OSCSender.swift:30 'on the CAMERA it may never be reached'; Core/EngineBus.swift:149 'on a camera session, possibly never'. Consequence in the servo: Sources/Echoelmusic/Studio/EchoelStudioView.swift:9889 `let liveCoh = rawCoh > 0 ? rawCoh : (heldCoh ?? 0.5)` feeds `BioComposer.tempo(for:)` (`Sequencer/BioComposer.swift:453 hr * (1 - calm) + Self.resonancePulseBPM * calm`, resonance 72), so on the camera calm ≡ 0.5 and tempo ≡ 0.5·hr + 36 — no convergence. In CLAUDE.md: `grep -n "minIntervals\|102 bpm\|10 s peak\|16 RR" CLAUDE.md` → nothing; the DDSP table lists 'Coherence → filter cutoff · brightness · harmonicity · noise level' as LIVE and the TEMPO INVARIANT says the clock 'konvergiert von ihm WEG, je ruhiger der Körper wird'.
```

**Warum:** Both the identity claim (coherence-driven timbre) and the T1–T3 tempo doctrine describe behaviour that only a BLE strap can exercise; on the iPhone-first path — the one the founder tests — the coherence channel is structurally absent at rest, the trend (#813) never gets a run, and `AlwaysOnBioChannel`'s 'live' coherence is the neutral. A session that plans store text or tunes the servo from CLAUDE.md plans from a source that cannot deliver. This is the same class as the retracted 'wired (bio→tempo)' line: machine present, route empty.

**Vorschlag:** Two parts. (1) Status, one file: add one line under CLAUDE.md DDSP Bio-Mappings and one under TEMPO INVARIANT: 'coherence is BLE-only at rest; on the camera `HRVCoherence.minIntervals`=16 vs a rebuilt 10 s window, see CameraRPPGBioPublisher ~2155'. (2) Opportunity, one file: `CameraRPPGBioPublisher` already walks NEW beats once via the `lastRespirationBeatTime` cursor (the loop feeding `respiration.ingest`); append each accepted `ms` to a rolling `coherenceRRHistory` (cap ~64) there and call `HRVCoherence.compute(rrMs: coherenceRRHistory, blend: 1.0)` on that instead of the 10 s snapshot — at 60 BPM the 16-interval floor is reached in ~16 s. Device-verify the resulting values (NEEDS-FOUNDER-VERIFY marker), and update `AFreshTakeStartsWithNoHeldFrameTests`' prose that leans on 'vacuous at rest'.

- Prüfer (bestätigt, Konfidenz high, Schwere hoch): Every cited command and line reproduces on branch claude/echoelmusic-review-optimize-u5jjpd. `grep -n "static let minIntervals" Sources/Echoelmusic/Bio/HRVCoherence.swift` → line 144 `= 16`; `tachogram` (line 225) returns nil below it, and `compute(rrMs:blend:)` then yields `valid: false`. `grep -n "rrIntervals = cleanIntervals" Sources/Echoelmusic/Video/CameraAnalyzer.swift` → lines 794 and 861, both whole-array assignments inside `detectPeaks`, whose window is `min(n, Int(effectiveSampleRate * 10))` (line 628) — a fixed 10 s slice, never accumulated (contrast `PolarH10BioPublisher` lines 477–480, which append into a 64-deep ring). Arithmetic holds: 16 intervals = 17 peaks in 10 s = 102 bpm…
- Prüfer (bestätigt, Konfidenz high, Schwere hoch): Re-derived every evidence line: `grep -n "static let minIntervals" Sources/Echoelmusic/Bio/HRVCoherence.swift` → 144 (=16), tachogram guard at 225; camera coherence computed at CameraRPPGBioPublisher.swift:1559 from `self.analyzer.rrIntervals`, which detectPeaks rebuilds whole from `windowSize = min(n, Int(effectiveSampleRate * 10))` at two sites (`grep -n "rrIntervals = cleanIntervals"` → 794, 861); servo fallback `heldCoh ?? 0.5` at EchoelStudioView.swift:9888-9889 feeds BioComposer.tempo(for:) line 453. The "≥17 clean peaks in 10 s ≈ 102 bpm, lastValidCoherence stays 0 at rest" consequence is stated in CameraRPPGBioPublisher ~2155, OSCSender ~365, EngineBus ~150, AFreshTakeStartsWithNoHel…

#### `bio-pipeline-4` — The bio strip shows HealthKit HRV as a unit-less normalized number although the frame carries the measured SDNN in ms *(unverifiziert)*

**Schwere:** niedrig · **Art:** Status-Drift · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Sources/Echoelmusic/Studio/BioStripView.swift:903 `if bio.hrvRMSSDms == 0 && bio.hrvNormalized > 0 { return EchoelDecimalText.string(bio.hrvNormalized, decimals: 3) }` with `hrvUnit` nil in that branch (lines 907–910); its doc says 'the normalized [0..1] value for sources that only publish that (HealthKit)'. But HealthKit publishes the ms: Sources/Echoelmusic/Bio/HealthKitBioPublisher.swift `hrvSDNNms: Float(snap.hrvSDNNms)` with the comment 'previously left at 0'. `grep -c hrvSDNNms Sources/Echoelmusic/Studio/BioStripView.swift` → 0. `hrvNormalized` on HealthKit is `HRVNormalization.normalize(sdnn)` = SDNN/100 (Sources/Echoelmusic/Bio/EchoelBioEngine.swift:418).
```

**Warum:** A Watch user reads 'HRV 0.450' beside neighbours that read 'HR 62' and 'coh —', a derived ratio presented as a measurement with no unit and no metric name, while the real '45 ms' is in the same frame; switching to a strap flips the cell from a ratio to ms without saying so. CLAUDE.md's science-first rule is 'legible numbers first' and the strip's own header calls 0 'honest —'.

**Vorschlag:** One file: in `BioStripView.hrvString`, before the normalized fallback, `if bio.hrvRMSSDms == 0, Self.plausibleHRVms.contains(bio.hrvSDNNms) { return EchoelDecimalText.string(bio.hrvSDNNms, decimals: 0) }` and make `hrvUnit` return "ms" for that branch (a short 'SDNN' hint belongs in `BioMetricInfo`, which already explains the metric). Extend `TheStripAsksOneFreshnessQuestionTests` or add a small test with a HealthKit-shaped frame.


#### `bio-pipeline-5` — CoherenceTrend holds a stale derivative when the SAME source stops measuring, while the level goes neutral on that very frame *(unverifiziert)*

**Schwere:** niedrig · **Art:** Defekt · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Sources/Echoelmusic/Core/CoherenceTrend.swift `update(...)`: `guard measured, coherence.isFinite, timestamp.isFinite else { runs[source] = nil; return value }` — the run is dropped but `value` (the last reported slope) is returned unchanged; a new run later sets `value = 0`. Both callers pass that return straight to the audio params in the same statement that passes `frame.coherenceForSound` (neutral 0.5 for the unmeasured frame): Sources/Echoelmusic/Tools/BioReactiveSynthVoice.swift:891–896 and Sources/Echoelmusic/Tools/PolySynthVoice.swift:977–983. The hold is deliberate ONLY for the interleaved-source case (the doc: 'a wrist frame carrying no coherence says nothing about the camera's trajectory'; pinned by `Tests/CISmoke/TheCoherenceTrendHasAProducerTests.swift:306` where `unmeasuredSource` never had a run). Same-source unmeasured happens on the strap every time `HRVCoherence` returns `.invalid` (`coherence: reading.valid ? reading.coherence : 0`, PolarH10BioPublisher.swift:224).
```

**Warum:** For the length of an invalid window the synth is told 'coherence neutral' and 'coherence rising at +0.8' from the same frame — the spectral morph keeps moving on a slope no body produced. Small today (strap invalid stretches are short; on the camera the trend never gets a run, see bio-pipeline-3), but it is the exact 'substitution reads as movement' error the trend's own doc warns about, now in the other direction.

**Vorschlag:** One file, three lines: in the `guard measured` else-branch, `if runs.removeValue(forKey: source) != nil { value = 0 }` — a source that HAD a run and lost it reports no slope; a source that never had one keeps the hold, so the pinned interleave test stays green. Add one claim to `TheCoherenceTrendHasAProducerTests`: same-source unmeasured after a climb returns 0.


#### `bio-pipeline-6` — Camera HRV metrics reach the bus and OSC without RRIntervalHygiene, while the analyzer header credits consumers with running it — only a doorless view does *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Sources/Echoelmusic/Video/CameraAnalyzer.swift:157–161 'Consumers run their own hygiene (`RRIntervalHygiene.acceptedSegments`) and get both the beats and the honest survival rate' on `rawIntervalsMs`. `git grep -n "RRIntervalHygiene\.\(acceptedSegments\|canStateHRV\)" -- Sources` → only PolarH10BioPublisher.swift:190/199 and PoincareMetrics.swift:257; `git grep -n rrWindowMs -- Sources` → the only reader is `Studio/AnalysisPoincareView.swift`, one of the four analysis views the register lists as doorless. The publisher's frame uses `analyzer.rmssd` / `HRVMetrics.sdnn(rrMs:)` / `pnn50(segments: analyzer.rrSegments)` (CameraRPPGBioPublisher.swift ~1548–1705), i.e. refractory + 300–1500 ms band + IQR cleaning inside `detectPeaks`, but no successive-difference (Malik) rejection and no `canStateHRV` honesty gate — the strap applies both before publishing.
```

**Warum:** The lower-trust source is the one without the honesty gate: an rPPG take with bad contact can put an RMSSD on `/echoelmusic/bio/heart/rmssd` (gated only on `> 0`) and into `hrvForSound` that the strap would have refused to state. The strip clamps its DISPLAY to 3…300 ms (`plausibleHRVms`), so the number is hidden on screen and still travels to the lighting desk. The analyzer's comment describes a consumer that does not exist on the shipping path.

**Vorschlag:** Smallest honest step, one file: in `CameraRPPGBioPublisher` publish `hrvNormalized`/`hrvRMSSDms` only if `RRIntervalHygiene.canStateHRV(rrMs: analyzer.rawIntervalsMs)` (else 0, the house 'not measured' sentinel, which `hrvForSound` already maps to neutral). Whether `acceptedSegments` suits rPPG gap structure is the measurement the SDNN comment at ~1660 already flags as open — do not copy that half across. Correct the CameraAnalyzer header to name the one reader that runs hygiene and that it is doorless.


### Studio-UI (`studio-ui`)

The Studio UI is in better structural shape than its 12,391-line host file suggests. The two ship-blocker laws hold as measured: the presentation chain is 14 file-wide / 13 on the body (`python3 scripts/doctor.py --section D`), three of those slots are setter-less headroom (`--section C`: showInput, midiImportPresented, showMeditation), and none of the four hot producers (camera readouts, 60 Hz meter, masterVolume, metronome.bpm) is read in EchoelStudioView, WorkspaceView, SurfaceHost or EchoelmusicApp outside a leaf — the only `transport.position` reads sit in the leaves `TransportPositionView` and `MiniTransportView`. Design bans are respected (no radius >16, no material/blur, max shadow radius 8, no raw Slider except the founder-asked look-scrub), the parameter field has full VoiceOver (label/value/hint/adjustable action) and a pinch ladder to accessibility5. What is wrong is prose that has outlived the code it describes: an in-file note asserting a `showVisual` door that #1069 deleted, a PERFORMANCE table in the law file that rates the shipped 60 fps / ~1 Hz design as FAIL, a dead `shouldAutoPlay` binding through onboarding, a doorless leaf missing from the register, and an unexamined landscape story on iPhone whose plist allows it while the root chrome reads no size class. The chip IA hides the two product pillars (bio, visual) behind the least self-explanatory doors — a copy question for the founder, not a code defect.

#### `studio-ui-1` — In-file note asserts a live `showVisual` door and 'no inline donut toggle' — both false since #1065/#1069

**Schwere:** mittel · **Art:** Status-Drift · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Sources/Echoelmusic/Studio/EchoelStudioView.swift ~5982–5990 (the ⛔ #1057 paragraph above the look Slider) says: "#747 gave `showVisual` a door — `EchoelStudioView.swift:5180` writes it `true` from the Visual panel's 'Full screen' — so the overlay's donut toggle is reachable" and "the inline panel has no donut toggle at all, only the overlay does". Re-derive: `git grep -n "showVisual\b" -- Sources | grep -v ":\s*//"` → 0 hits (only comments); `sed -n 5178,5182p Sources/Echoelmusic/Studio/EchoelStudioView.swift` → a comment, not a write; `grep -n 'Toggle(isOn: \$spectralDonuts)' Sources/Echoelmusic/Studio/EchoelStudioView.swift` → line 5280, inside the inline Field panel. The neighbouring paragraph (~5973–5976, 'struck #1104') already records that #1069 deleted `showVisual`, the cover and the overlay — the #1057 paragraph was never retracted with it. `grep -n '#1057' Sources/Echoelmusic/Studio/EchoelStudioView.swift` → 4 sites; only 5982 is stale.
```

**Warum:** This is the paragraph a session reads before touching the donut/look state. It names a line number as a live write and denies a toggle that exists two hundred lines up — exactly the CLAUDE.md 'wirkungslos vs. unerreichbar' trap: a reader would either hunt for a door that is gone or remove the load-bearing `spectralDonuts` clear on the wrong premise.

**Vorschlag:** One file: rewrite the ~5980–5992 paragraph in EchoelStudioView.swift to say that #1069 deleted `showVisual`/cover/overlay, that the ONE reachable donut toggle is `Toggle(isOn: $spectralDonuts)` in the Field panel (#1065), and that the Slider setter's clear is load-bearing for that reason. No code change.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): All three evidence commands reproduce at /home/user/Echoelmusic/Sources/Echoelmusic/Studio/EchoelStudioView.swift. (1) `git grep -n "showVisual\b" -- Sources | grep -v ":\s*//"` → 0 lines (exit 1); the unfiltered grep is 24 hits, every one a `//` or `///` comment — `showVisual` no longer exists as code, and line 789 says so in its own words ("STOOD HERE AND IS DELETED (#1069)"). (2) `sed -n 5178,5182p` prints a comment block about `sizeRaw`/`ChromeBudgetFitsTests`, not a write; the only live "Full screen" control is `Text("Full screen")` at 5191, which since #1067 resizes the one window. (3) `grep -n 'Toggle(isOn: \$spectralDonuts)'` → line 5280 (live code, inside the Field panel, with the #…

#### `studio-ui-2` — CLAUDE.md PERFORMANCE table rates the shipped design as FAIL: 'Visual FPS 120fps' and 'Bio Loop 120Hz' vs. a deliberately pinned 60 fps and a ~1 Hz bio apply rate

**Schwere:** mittel · **Art:** Status-Drift · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -nE 'Visual FPS|Bio Loop' CLAUDE.md` → lines 373–374: `| Visual FPS | 120fps | <60fps |` and `| Bio Loop | 120Hz | <60Hz |`. Code: `grep -n 'preferredFramesPerSecond' Sources/Echoelmusic/Views/MetalBioView.swift` → :531 `view.preferredFramesPerSecond = 60` with the comment at ~1065 "Display frame rate is PINNED at 60 (makeUIView) and NEVER reassigned at runtime" (changing it reconfigures the CADisplayLink — the founder's 'Fullscreen flackert' class). 120 Hz on iPhone additionally needs `CADisableMinimumFrameDurationOnPhone`: `grep -c CADisableMinimumFrameDurationOnPhone Resources/iOS/Info.plist` → 0 (report-only file). Bio: CLAUDE.md's own architecture line (`grep -n 'ANWENDUNGSRATE ist ~1 Hz' CLAUDE.md` → line 39) states the apply rate is ~1 Hz by design, ~6 dB below the table's FAIL threshold of 60 Hz.
```

**Warum:** The table is the only place a session reads a numeric quality bar for the visual and bio loop, and both rows are unreachable by construction — one by a documented engineering decision, one by the bus architecture. A session optimising 'toward 120' would undo the #1196/#1197-era stutter fixes or invent a faster bio poll the dedup law forbids. A FAIL bar the shipping app cannot meet is the same defect class as the retired 'bis die gesamte DMMW auf Profi-Level ist' gate.

**Vorschlag:** One file: replace the two rows in CLAUDE.md with what is measured — Visual: 60 fps pinned (MetalBioView), FAIL = dropped frames/stutter, thermal handled by detail tier not rate; Bio: ~1 Hz apply (deduped on frame.timestamp), 10 Hz poll ceiling. Do NOT touch Info.plist (founder-gated); if the founder wants ProMotion, that is a separate decision needing the plist key plus a rate-switch design that avoids the display-link hitch.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Every cited command reproduces verbatim: `grep -nE 'Visual FPS|Bio Loop' CLAUDE.md` → 373 `| Visual FPS | 120fps | <60fps |`, 374 `| Bio Loop | 120Hz | <60Hz |` (section '## PERFORMANCE — Hard Limits', live, no ⛔ retraction anywhere in it). `grep -n preferredFramesPerSecond Sources/Echoelmusic/Views/MetalBioView.swift` → :531 `view.preferredFramesPerSecond = 60`; :1064–1073 'Display frame rate is PINNED at 60 (makeUIView) and NEVER reassigned at runtime… Thermal pressure is handled by DETAIL scaling… not by toggling the display's frame rate'. `grep -c CADisableMinimumFrameDurationOnPhone Resources/iOS/Info.plist` → 0. `grep -n 'ANWENDUNGSRATE ist ~1 Hz' CLAUDE.md` → line 39. The code refutes…

#### `studio-ui-3` — `shouldAutoPlay` is dead plumbing: bound through onboarding, never written, never read *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`git grep -n shouldAutoPlay -- Sources` → exactly 3 hits: EchoelmusicApp.swift:241 (`@State private var shouldAutoPlay = false`), :462 (passed into `OnboardingView(isComplete:shouldAutoPlay:)`), OnboardingView.swift:18 (`@Binding var shouldAutoPlay: Bool`). No assignment, no reader. `git grep -n shouldAutoPlay -- Tests | wc -l` → 0. The Start button (OnboardingView.swift ~236–262) only flips `isComplete`; the onboarding copy at :175 says "Press Play to start", so no autoplay is promised to the user.
```

**Warum:** A binding named like a feature, threaded through the app root, invites the next session to 'finish' it — an auto-start on first launch would play synth before the user has armed anything and contradicts the 'silent until user-armed' law. Dead state in the root `App` also costs a rebuild trigger for nothing.

**Vorschlag:** Two files: delete the `@State` and the argument in EchoelmusicApp.swift, delete the `@Binding` in OnboardingView.swift. If autoplay is ever wanted, it returns together with its consumer and a guard.


#### `studio-ui-5` — `ADMStreamStatusLine` is transitively doorless and guarded, but absent from the CLAUDE.md register *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`python3 scripts/doctor.py --section C` → WARN 'reachable only through a doorless view': `Sources/Echoelmusic/Studio/NetworkActivityDot.swift:144 struct ADMStreamStatusLine`. `git grep -n 'ADMStreamStatusLine(' -- Sources` → 1 construction, ImmersiveStageView.swift:245, and `ImmersiveStageView(` itself is constructed nowhere (same doctor list). Guard exists: `Tests/CISmoke/TheStageStatusLineHasNoDoorTests.swift`. Register: `grep -c 'NetworkActivityDot\|ADMStreamStatusLine\|StageStatusLine' CLAUDE.md` → 0, while the parent `ImmersiveStageView` has its own register line.
```

**Warum:** The register is the list a session uses to decide what it may open or delete; doctor's own rule is 'unreachable AND unwritten-down is the defect'. The leaf carries the #996 hot-read law for the ADM sender (its file head says the read must stay in this leaf) — a cleanup that deletes 'dead' NetworkActivityDot code would remove the only home of that law.

**Vorschlag:** One file: append one clause to the `ImmersiveStageView` register entry in CLAUDE.md naming `ADMStreamStatusLine` (NetworkActivityDot.swift) as its only child, guarded by `TheStageStatusLineHasNoDoorTests`, re-doored by dooring the parent. No code change.


### Ausgabestufe / Sync (`output-sync`)

The four network senders (OSC · ADM-OSC · Art-Net · sACN) share one sound shape: @MainActor @Observable, a PollingLoop tick, an NWConnection started on .main, pure testable packet kernels, and per-channel measurement gating — the CLAUDE.md OSC address set is exact (every listed address has a producer in OSCSender.bioMessages/eventMessages/sendModulation; nothing unlisted is sent from a reachable path; IEM `/MultiEncoder/*` exists only behind the doorless ImmersiveStageView). ArtDMX (opcode 0x5000 LE, ProtVer 14, seq 1…255, Net/SubUni 15-bit split, even length) and the E1.31 data packet (CID, 64-byte Source Name, priority 100, 513 DMP properties) are byte-correct, the 33 ms tick keeps refresh under Art-Net's 44 Hz and FlashGuard slews dimmer+colour below 3 Hz. The one critical defect is that every ADM-OSC message uses `/adm/obj/{n}/position/azimuth|elevation|distance|x|y|z`, while the ADM-OSC v1.0 table (immersive-audio-live/ADM-OSC docs/adm-osc.bs) defines `/azim`, `/elev`, `/dist`, `/x`, `/y`, `/z` — a spec-conformant renderer drops all of it, so the "bio-reactive object source" claim is untrue on the wire today. Two lighting-operator risks follow: Art-Net defaults to 255.255.255.255, which iOS gates behind the multicast/broadcast entitlement the app does not carry, and neither DMX sender sends keep-alive or Stream_Terminated packets, so an sACN receiver declares source loss 2.5 s into any bio stall. MIDI out is honest MIDI 1.0-over-UMP with a correct MPE Configuration RPN; "MIDI 2.0" is true only for the input port, and per-note expression is emitted after the note-on rather than before. No socket leak, no main-thread blocking send, no audio-thread violation was found in this subsystem.

#### `output-sync-1` — ADM-OSC output uses a non-existent `/position/…` address shape; spec v1.0 is `/azim` `/elev` `/dist` `/x` `/y` `/z`

**Schwere:** kritisch · **Art:** Defekt · **Aufwand:** M · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Echoel sends `/adm/obj/{n}/position/azimuth`, `/position/elevation`, `/position/distance` (Sources/Echoelmusic/Sync/ADMOSCSender.swift admMessages, MusicMediaMapping.swift admMessages(forMusic:), SpatialSceneOSC.swift admMessages) and `/position/x|y|z` (SpatialSceneOSC.swift admCartesianMessages). Re-derive: `git grep -n 'position/azimuth\|position/x"' -- Sources Tests docs` → 3 Sources files, 4 test files (ADMOSCAbsenceTests, ADMOSCSenderTests, MusicMediaMappingTests, SpatialSceneOSCTests), docs/SPATIAL_EXPANSION_AUDIT.md:25; `git grep -n '/azim' -- Sources Tests docs` → 0. The upstream spec table (github.com/immersive-audio-live/ADM-OSC, docs/adm-osc.bs, fetched 2026-09-10) lists `/adm/obj/n/azim` f −180…180, `/elev` f −90…90, `/dist` f 0…1, `/aed` fff, `/x` `/y` `/z` f −1…1, `/xyz`, `/gain` f ≥0, `/w`, `/mute`, `/name`; there is no `position` segment. Object index 1-based and azimuth positive = left match Echoel. The code's own header (ADMOSCSender.swift:16 'ADM-OSC v1.0 namespace') and SpatialSceneOSC.swift:61 ('FletcherMachine, L-ISA, d&b Soundscape, SPAT, Nuendo') claim conformance.
```

**Warum:** A renderer that implements the spec (L-ISA, SPAT Revolution, DS100/Soundscape, the reference Python receiver) rejects every message — the ADM-OSC repo's own receiver log shows 'ERROR: unrecognized ADM address' for unknown paths. The identity line, README.md:64, docs/architecture.html:286, docs/faq.html:222 and ContentPipeline/CLAIMS.md:55 all sell 'bio-reactive object source over ADM-OSC'; on the wire that is currently false, and no test can catch it because the golden files pin the wrong strings.

**Vorschlag:** Rename the four leaf segments in the three formatters — ADMOSCSender.swift (`/azim`, `/elev`, `/dist`, keep `/gain`), MusicMediaMapping.swift (same four), SpatialSceneOSC.swift (polar + `/x` `/y` `/z`) — and move the four golden tests plus the header comments in the same commit; add one CISmoke guard that asserts no Sources file emits the substring `/position/` under `/adm/obj/`. Prose homes to pull along: docs/SPATIAL_EXPANSION_AUDIT.md:25, scratchpads/SPEC_LIGHT_OSC_VERIFICATION.md:17. Ranges and index base need no change.

- Prüfer (bestätigt, Konfidenz high, Schwere hoch): REPRODUCED. (1) `git grep -n 'position/azimuth\|position/x"' -- Sources Tests docs` → exactly the 3 Sources files (ADMOSCSender.swift:17/285/323, MusicMediaMapping.swift:77, SpatialSceneOSC.swift:11/99/118), 4 test files (ADMOSCAbsenceTests, ADMOSCSenderTests, MusicMediaMappingTests, SpatialSceneOSCTests) and docs/SPATIAL_EXPANSION_AUDIT.md:25; `git grep -c '/azim' -- Sources Tests docs` hits only the same `/position/azimuth` lines plus the IEM `/azimuth{i}` dialect — zero occurrences of the spec leaf `/azim`. (2) Read the formatters: ADMOSCSender.admMessages(for:) (line ~323), MusicMediaMap.admMessages(forMusic:) (line 77), SpatialSceneOSC.admMessages/admCartesianMessages (lines 99/118) all…
- Prüfer (bestätigt, Konfidenz high, Schwere hoch): CONFIRMED, not refuted. Re-derived: `git grep -n 'position/azimuth\|position/x"' -- Sources` → ADMOSCSender.swift:323, MusicMediaMapping.swift:77, SpatialSceneOSC.swift:99/118 emit `/adm/obj/{n}/position/{azimuth,elevation,distance,x,y,z}`; `git grep -c '/azim' -- Sources Tests docs` → 0. Upstream `docs/adm-osc.bs` (immersive-audio-live/ADM-OSC, fetched 2026-09-10 via curl) lists `/adm/obj/n/azim` `/elev` `/dist` `/aed` `/x` `/y` `/z` `/xyz` `/gain` — no `position` segment; the README's reference receiver (`pip install adm-osc`) logs `ERROR: unrecognized ADM address` for unknown leaves. Likely origin: the Python helper is named `send_object_position_azimuth` and Echoel transcribed the method…

#### `output-sync-2` — Art-Net defaults to limited broadcast 255.255.255.255, which iOS gates behind the multicast/broadcast entitlement the app does not hold

**Schwere:** hoch · **Art:** Risiko · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Default host literal: `sed -n 137p Sources/Echoelmusic/Sync/ArtNetSender.swift` → `public init(host: String = "255.255.255.255", …)`; connect() (lines 190-199) uses plain `NWParameters.udp` + `allowLocalEndpointReuse` — Network.framework exposes no SO_BROADCAST. Entitlement absent: `grep -c multicast Echoelmusic.entitlements` → 0; SACNSender.swift:10-16 already records that iOS gates multicast behind `com.apple.developer.networking.multicast` (Apple's entitlement text covers 'multicast or broadcast'). No sender installs `stateUpdateHandler`: `git grep -n stateUpdateHandler -- Sources` → 0, so a failed send is invisible. Copy that promises it: Sources/Echoelmusic/Studio/PatchbayView.swift:302 ('Art-Net sends by broadcast (255.255.255.255) to all LAN nodes by default') and docs/artnet-sacn-from-a-phone.html:110 ('broadcast by default').
```

**Warum:** A lighting operator who turns the Art-Net route on without typing a node IP sees the patchbay dot go 'active' while nothing can reach the rig; the sACN header in the same directory documents the constraint for multicast but the Art-Net default contradicts it. NEEDS-FOUNDER-VERIFY on device (Wireshark on the LAN, route on, default host) — the Apple entitlement page could not be fetched from this sandbox, so the entitlement-covers-broadcast half is stated from Apple's published wording, not re-read today.

**Vorschlag:** Cheapest honest step (not gated): change the default host to unicast (empty → the patchbay field shows a placeholder 'node IP', or 192.168.1.255 subnet-directed is equally gated, so unicast only), rewrite the PatchbayView.swift:302 sentence and docs/artnet-sacn-from-a-phone.html:110 to 'unicast to a node IP', and add a `stateUpdateHandler` in ArtNetSender.connect() that surfaces `.failed`/`.waiting` into an observed `lastError` the outputRow can show. The entitlement route (Apple approval, project.yml/entitlements) is a separate founder decision.

- Prüfer (bestätigt, Konfidenz high, Schwere hoch): Every evidence command reproduces, and the one half the auditor could not verify (Apple's wording) I re-read today from Apple's live docs. (1) `sed -n 137p Sources/Echoelmusic/Sync/ArtNetSender.swift` → `public init(host: String = "255.255.255.255", port: UInt16 = 6454, universe: Int = 0)`; the init does `d.string(forKey: hostKey) ?? host`, so a fresh install really lands on the limited-broadcast address. (2) `connect()` (lines 190-199) is plain `NWParameters.udp` + `allowLocalEndpointReuse`, no entitlement-bearing option. (3) `git grep -n stateUpdateHandler -- Sources | wc -l` → 0; and `send(_:)` at line 276 is `conn.send(content: data, completion: .contentProcessed { _ in })` — the error i…
- Prüfer (bestätigt, Konfidenz high, Schwere mittel): NOT refuted — the finding is real, known-but-unparked, and its technical half is now settled from Apple's own text (fetched today, which the auditor could not do). Re-derived: - Code: `sed -n 137p Sources/Echoelmusic/Sync/ArtNetSender.swift` → `public init(host: String = "255.255.255.255", …)`; `connect()` (l.190-199) is plain `NWParameters.udp`, no SO_BROADCAST equivalent. `grep -c multicast Echoelmusic.entitlements` → 0 (same for Watch/Widgets; `project.yml` only names the three entitlement files). `git grep -n stateUpdateHandler -- Sources` → 0. - Apple wording (WebFetch of the JSON doc endpoints, 2026-09-10): entitlement discussion = "Your app must have this entitlement to send or receiv…

#### `output-sync-3` — sACN and Art-Net send only on change: no keep-alive, and stop() never sends E1.31 Stream_Terminated

**Schwere:** hoch · **Art:** Defekt · **Aufwand:** M · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Emission guard: `grep -n 'guard sourceTimestamp != lastFrameTimestamp || masterMoved || slewSettling' Sources/Echoelmusic/Sync/SACNSender.swift Sources/Echoelmusic/Sync/ArtNetSender.swift` → one hit each (SACNSender.swift:232, ArtNetSender.swift:249); a tick with an unchanged source, settled slew and unchanged master sends nothing. `git grep -n -i 'keep.alive\|terminat\|0x40' -- Sources/Echoelmusic/Sync/SACNSender.swift Sources/Echoelmusic/Sync/ArtNetSender.swift` → 0 (the only 'terminat' hit is the Art-Net string null terminator). Options byte is hard 0x00 (SACNSender.swift:333) and stop() only cancels the socket (lines 139-146). E1.31 receivers time out a source after E131_NETWORK_DATA_LOSS_TIMEOUT = 2.5 s and expect unchanged data re-sent at ≥ ~1 Hz; a clean stop is three packets with the Stream_Terminated option bit. Bio frames arrive ~1 Hz only while the camera publishes (CLAUDE.md: the publisher closes on `inboundRateEMA` when the finger leaves), and MusicalFrame stops at transport stop.
```

**Warum:** On grandMA/QLC+/sACNView the universe flips to 'source lost' within 2.5 s of any bio stall or transport stop, then either holds last look or fades to black depending on desk config — an unannounced state change mid-show that the operator cannot distinguish from a network fault. On stop the desk waits out the timeout instead of releasing the universe immediately (merge priority stays claimed).

**Vorschlag:** In both sendIfFresh loops add a keep-alive arm: if `!lastChannels.isEmpty` and `now - lastSentTimestamp >= 0.8`, resend the last packet (same sequence increment, no new slew). In SACNSender.stop() emit three copies of the last packet with Options = 0x40 before cancelling (extend e131Packet with `options:`; default 0 keeps every existing golden test byte-identical). Files: SACNSender.swift, ArtNetSender.swift, Tests/EchoelmusicTests/SACNSenderTests.swift (assert the 0x40 bit and the 0.8 s resend).

- Prüfer (bestätigt, Konfidenz high, Schwere hoch): Reproduced every command. `grep -n 'guard sourceTimestamp != lastFrameTimestamp || masterMoved || slewSettling' Sources/Echoelmusic/Sync/SACNSender.swift Sources/Echoelmusic/Sync/ArtNetSender.swift` → SACNSender.swift:232 and ArtNetSender.swift:249, one each; in context the held arm reuses `lastFrameTimestamp`, so an unchanged source with settled slew/unmoved master returns before `send`. `git grep -n -i 'keep.alive\|terminat\|0x40' -- <both files>` → one hit, ArtNetSender.swift:328 (ArtDmx ID null terminator). SACNSender.swift:333 is `d.append(0x00) // Options`, the sole writer; `stop()` (139–146) only stops the loop and cancels the socket. Premise verified: CameraRPPGBioPublisher.swift ~14…
- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Re-derived, not refuted on law/history — but the severity is inflated. Code: `grep -n 'guard sourceTimestamp != lastFrameTimestamp || masterMoved || slewSettling' Sources/Echoelmusic/Sync/SACNSender.swift Sources/Echoelmusic/Sync/ArtNetSender.swift` → SACNSender.swift:232 and ArtNetSender.swift:249, one each; `e131Packet` writes Options as a literal `0x00` (SACNSender.swift:333) and `stop()` (lines 139–146) only stops the loop and cancels the socket — no terminate packets. `git grep -n -i 'keep.alive\|keepalive\|Stream_Terminated\|0x40\|E131' -- Sources Tests CLAUDE.md docs/dev memory/decisions.md scratchpads/HARNESS_LEDGER.md scratchpads/SESSION_LOG.md` → zero hits about E1.31 keep-alive or…

#### `output-sync-7` — No published integration surface for VJ/lighting operators: the OSC schema lives only in an unlinked dev doc, no TouchOSC/TouchDesigner template, sACN priority not settable

**Schwere:** mittel · **Art:** Chance · **Aufwand:** M · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
The only complete address table is docs/dev/VJ_BRIDGE.md (lines 34-46) — `git grep -n VJ_BRIDGE -- docs/*.html README.md` → 0 (not linked from the site); docs/architecture.html:284-290 repeats a partial list. Templates: `git ls-files | grep -iE '\.tosc$|\.toe$|\.tox$|touchosc|touchdesigner'` → 0. sACN priority is the literal 100 with no property (`grep -n 'd.append(100)' Sources/Echoelmusic/Sync/SACNSender.swift` → line 330); Art-Net implements ArtDMX only, no ArtPollReply (CLAUDE.md OSC section, already recorded). OSC messages are sent as one datagram each, no bundles/timetags (OSCSender.swift:518-522).
```

**Warum:** Resolume/MadMapper learn addresses by wiggling, but TouchDesigner, grandMA3 (OSC in via plugin) and QLC+ need the address list up front; a grandMA operator merging Echoel with a console needs a priority below 100 to keep the desk in charge; ADM-OSC's own repo ships a JSON schema (docs/adm-osc-schema.json) which is the pattern a phone-as-source should mirror.

**Vorschlag:** Publish docs/integrations.html generated from the VJ_BRIDGE.md table (plus the ADM-OSC and DMX channel maps: dimmer,R,G,B ×8/16-bit, universe defaults, ports 8000/9000/6454/5568), link it from docs/index.html and the faq; add `public var priority: UInt8 = 100` to SACNSender with an EchoelValueField in PatchbayView's Light section. A .tosc/.tox binary is a founder/device task; the schema page is not.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Every evidence command reproduces on the current tree (branch claude/echoelmusic-review-optimize-u5jjpd, clean). (1) `git grep -n VJ_BRIDGE -- 'docs/*.html' README.md` → 0; the file exists (docs/dev/VJ_BRIDGE.md, 8300 B) and its 12-row table sits at lines 32-46; no docs/*.html links any `dev/*.md`. (2) `git ls-files | grep -iE '\.tosc$|\.toe$|\.tox$|touchosc|touchdesigner'` → 0. (3) `grep -n 'd.append(100)' Sources/Echoelmusic/Sync/SACNSender.swift` → line 330 `// Priority`; `grep -n -i priority` in that file returns only that line — no property, and Tests/EchoelmusicTests/SACNSenderTests.swift:32 pins `p[108] == 100`. (4) ArtNetSender.swift:329 builds only OpCode 0x5000 (ArtDMX); no ArtPoll…

#### `output-sync-5` — MPE per-note expression is sent AFTER the note-on; MPE practice is to state Bend/CC74/Pressure immediately BEFORE it *(unverifiziert)*

**Schwere:** niedrig · **Art:** Defekt · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`sed -n 279,292p Sources/Echoelmusic/Audio/MIDIOutput.swift`: `send([0x90 | UInt8(ch), UInt8(pitch), vel])` precedes `sendExpression(expression ?? .neutral, channel: ch)`; sendExpression (lines 296-300) emits 0xE0, CC74, 0xD0 on the member channel. The MPE Configuration RPN itself is correct (lines 348-353: CC101=0, CC100=6, CC6=15 on channel 1, lower zone). The guard Tests/CISmoke/TheMPEInputHasNoZonesTests.swift:770-772 pins the three needles, not their order relative to 0x90.
```

**Warum:** The first buffer of every body-expressed note plays with the member channel's previous bend/brightness/pressure, then jumps — audible as a per-note zip on a Seaboard-class synth or Ableton MPE track, and it is the 'MPE OUT is real' half of the identity line.

**Vorschlag:** Swap the two statements in noteOn(pitch:velocity:expression:) so the expression trio goes out before 0x90 (neutral when nil), and add one claim to TheMPEInputHasNoZonesTests that the `sendExpression(` call textually precedes the `0x90 |` send inside that function. Files: MIDIOutput.swift, TheMPEInputHasNoZonesTests.swift.


#### `output-sync-6` — 'MIDI 2.0' in the positioning line is input-only; MIDI out is MIDI 1.0 protocol and the MIDI 2.0 word builders have no production caller *(unverifiziert)*

**Schwere:** niedrig · **Art:** Status-Drift · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
CLAUDE.md:38 lists 'open standards: ADM-OSC, MIDI 2.0, OSC, BLE HRS'; docs/brainstorming.html:187 'speaks open standards — MIDI 2.0/MPE'. Reality: `grep -n 'MIDISourceCreateWithProtocol' Sources/Echoelmusic/Audio/MIDIOutput.swift` → line 229 `._1_0`; both MIDIEventListInit calls are `._1_0` (lines 609, 634). `git grep -n 'midi2NoteOnMessages' -- Sources` → only its declaration in Sync/MPEExpression.swift:92 (0 callers); `UMPEncoder.note2On/perNotePitchBend2/perNoteController2/channelPressure2` are reached only from there. The input side IS 2.0: MIDIInput.swift:117 `._2_0`, and docs/faq.html:170 says 'MIDI 2.0-ready input' honestly.
```

**Warum:** A DAW/hardware integrator reading the positioning line expects MIDI 2.0 per-note controllers out and gets a 15-channel MPE zone instead; the honest-copy guards (#184, CLAIMS.md) cover the store text but not this line or brainstorming.html.

**Vorschlag:** Change CLAUDE.md:38 and docs/brainstorming.html:187 to 'MIDI 2.0-ready input, MPE out' (the faq.html:170 wording), and note in UMPEncoder.swift's header that the 2.0 builders are test-only until a `._2_0` source exists. No code change.


### Sequencer + Core (`sequencer-core`)

Measured on branch claude/echoelmusic-review-optimize-u5jjpd at ffd334e (2026-09-10), read-only. The TEMPO INVARIANT holds structurally: `PatternEngine.TempoSource` has exactly the five cases the guard pins, `Transport.setTempo` is reached only from `PatternEngine.swift` (six relay sites, `git grep -n "setTempo(" -- Sources`), both engine entry points take `source:` without a default, `.studioLocked` never reads the heart and the flow servo clamps 40…160 and converges on 72 — but one production caller mislabels: `generate()` under the user's BPM lock glides to `lockedBPM` with `source: .flowServo`, so the very log line T1 exists for names the servo for a user decision. Persisted-document decode is robust: all six `AppGroupStore.load` roots (`Arrangement`, `AutomationState`, `TimelineDocument`, three trivial `Meta`) either carry forgiving `init(from:)` decoders or lossy element wrappers, `AppGroupStore.load` catches and logs, and `git grep -n "fatalError(\|precondition(" -- Sources/Echoelmusic/Core Sources/Echoelmusic/Sequencer` (code lines) is empty — an old document cannot brick launch. The two dead-but-load-bearing layers are unchanged and still guarded (`git grep -n "\bModRoute(" -- Sources` = 1, the decoder; `RecordController.arm()` has no caller — the one `.arm()` hit at EchoelStudioView:11865 is the body-voice switch). SPSCQueue's acquire/release fence pairing is correct on arm64 (producer slot store is control-dependent on the head load; consumer fences after the tail load); what remains is false sharing on the diagnostic counters and a producer RMW on the consumer's index line. The step clock is a one-shot main-queue timer re-armed from `.now()` inside its own handler, so handler latency accumulates into the note clock while the click (audio-thread phase accumulator) and MIDI clock (repeating timer) do not — unmeasured on device, but structurally a drift source. Ship Gate: checks 2 and 3 are code-provable (`SoundPanelPresetBarTests`, `ComposerMode(locked:)` + `BodyTempoField`), check 1 is structurally pinned only (`GenreFamilyDistinctnessTests`), check 4 is half (code) and check 5 is device-only — nothing in this subsystem changes that count.

#### `sequencer-core-1` — generate() under the BPM lock records its tempo as `.flowServo` — the T1 log line names the servo for a user decision

**Schwere:** mittel · **Art:** Defekt · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`sed -n 10095,10132p Sources/Echoelmusic/Studio/EchoelStudioView.swift` → `let tempo: Double; if lockBPM { … tempo = lockedBPM.clamped(to: Transport.minTempo...Transport.maxTempo) }`; `grep -n "glideTempo(to: tempo, source: .flowServo)" Sources/Echoelmusic/Studio/EchoelStudioView.swift` → 10293, unconditional, with the comment above it saying "a locked take just glides to/holds it". `grep -n "case flowServo" -B 2 Sources/Echoelmusic/Sequencer/PatternEngine.swift` → doc: "`BioComposer.tempo(for:)` under `.flowFree`", and `case user` doc: "A lock toggle, a locked-field edit". `git grep -n "tempoSource=" -- Sources` → PatternEngine.swift:494 writes `lastTempoSource` into the play breadcrumb. `grep -n "lastTempoSource = source" Sources/Echoelmusic/Sequencer/PatternEngine.swift` → both setTempo and glideTempo overwrite it, so a lock toggle's `.user` (BodyTempoField.swift:514/525) is replaced by `.flowServo` on the next Generate/Evolve re-seed.
```

**Warum:** T1 (ratified 2026-08-13) exists so a device log says WHO moved the clock; the ruling itself warns that folding sources means "ein falsches Wort in genau die Log-Zeile zu schreiben, für die T1 existiert". A founder log of a locked take will read `tempoSource=flowServo`, sending the next debugging session after a servo that never ran. T2 is not violated (the value is the user's number), so the guard's claims 1–3 stay green and cannot see this.

**Vorschlag:** EchoelStudioView.swift:10293 — pass `source: lockBPM ? .user : .flowServo` (the non-body `else` branch may also warrant `.user`; decide per branch at the `let tempo` switch). Add one claim to Tests/CISmoke/TempoInvariantTests.swift asserting that the generate-path source depends on the lock (a source scan for the ternary next to the `glideTempo(to: tempo` needle, since generate() is not constructible in a test).

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Every command in the evidence reproduces on today's tree. `sed -n 10095,10132p Sources/Echoelmusic/Studio/EchoelStudioView.swift` shows `let tempo: Double; if lockBPM { … tempo = lockedBPM.clamped(to: Transport.minTempo...Transport.maxTempo) }` (the assignment is at :10139 after the long ⛔ #380 comment). `grep -n "glideTempo(to: tempo, source: .flowServo)"` → exactly one hit, :10293, unconditional, preceded by the comment "lockBPM already resolved `tempo` to the locked value above, so a locked take just glides to/holds it" — no comment documents the `.flowServo` label as deliberate under lock. `PatternEngine.swift:458-473`: `case user` doc = "A lock toggle, a locked-field edit, a tap, or a l…

#### `sequencer-core-2` — The step clock re-arms from `.now()` inside its own handler, so main-thread latency accumulates into the note clock while click and MIDI clock keep absolute cadence

**Schwere:** mittel · **Art:** Risiko · **Aufwand:** M · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n "deadline: .now() + interval" Sources/Echoelmusic/Sequencer/PatternEngine.swift` → 562 (`scheduleTick`, one-shot, called at the END of `advance()`, lines 583–640: `scheduleTick(after: PatternEngine.swingGap(afterStep: step, base: base, swing: swing))`). `grep -n -i "accumul\|catch up\|phase-lock\|absolute deadline" Sources/Echoelmusic/Sequencer/PatternEngine.swift` → nothing: no ideal-deadline accumulator exists. Contrast: `grep -n "repeating: interval" Sources/Echoelmusic/Audio/MIDIOutput.swift` → 541 (24-PPQN clock on a REPEATING timer, absolute cadence) and `grep -n "samplesPerBeat\|resync" Sources/Echoelmusic/Audio/MetronomeVoice.swift` (audio-thread phase accumulator); `git grep -n "\.resync()" -- Sources` → exactly one call, at transport start (EchoelStudioView.swift:10387). `Transport.currentTick(at:)` (Core/Transport.swift:334) derives position from `lastStepAt`, i.e. from the LATE tick, so the drift is internally consistent and invisible to the roll. CLAUDE.md documents 10–60 Hz main-actor churn sources (#919/#928), which is exactly the latency that lands in this handler. UNMEASURED on device — no Swift toolchain here.
```

**Warum:** Every tick's handler latency δ becomes a permanent phase loss (the next deadline is `now+interval`, not `ideal+interval`), so the effective BPM of notes is always ≤ nominal and slips relative to the click (resynced only at Start) and to external gear following the MIDI clock. A 4 ms mean latency at 120 BPM 16ths (125 ms) is ~3 % slow — audible as a click/notes seam after a few bars, and it degrades exactly when the UI is busiest.

**Vorschlag:** PatternEngine.swift only: keep `@ObservationIgnored private var nextTickAt: DispatchTime`, set it to `.now()` in `play()`/`setTempo()`/`glideTempo` landing, and in `advance()` schedule `nextTickAt = nextTickAt + gap` (clamp: if `nextTickAt < .now() - oneStep`, re-anchor to `.now()` so a suspended app does not burst-catch-up). Add a Foundation-only test in Tests/EchoelmusicTests/TempoStabilityTests.swift that injects late handler calls and asserts the schedule stays on the ideal grid. Device-verify against the click (NEEDS-FOUNDER-VERIFY, not founder-gated).

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Reproduced every command. `grep -n "deadline: .now() + interval" Sources/Echoelmusic/Sequencer/PatternEngine.swift` → 562, inside `scheduleTick(after:)` (559–567), a one-shot main-queue `DispatchSourceTimer` that is re-armed as the LAST line of `advance()` (625) after `transport?.tick`, the `onStep` fan-out, `onTick` and the glide relay — so both timer-fire latency and the handler's own execution time land in the next deadline. `grep -n -i "accumul\|catch up\|phase-lock\|absolute deadline"` on that file → empty; no ideal-grid anchor exists. `play()` (507) and the `setTempo` re-arm (317) also schedule a full gap from `.now()`. Contrast holds: `MIDIOutput.swift:547` (the finding said 541 — one…

#### `sequencer-core-3` — A fourth `register(defaults:)` for `instrumentHome` still sits in the startup `.task` that its own pointer comment says was emptied by #580 *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`git grep -c "register(defaults: \[FeatureFlags.Key.instrumentHome.rawValue: true\])" -- Sources` → `EchoelmusicApp.swift:2`. `sed -n 716,720p Sources/Echoelmusic/EchoelmusicApp.swift` → "⛔ THE THREE `register(defaults:)` CALLS THAT STOOD HERE MOVED TO `init()` (#580) … this is a pointer, not a second copy (#416)"; `sed -n 744p` → `UserDefaults.standard.register(defaults: [FeatureFlags.Key.instrumentHome.rawValue: true])` inside the `.task` opened at line 648 (`awk 'NR>=600 && NR<=744 && /\.task/'`). The guard cannot see it: `sed -n 179,195p Tests/CISmoke/EveryFlagSaysWhatItGatesTests.swift` collects registrations into a `Set<String>`, so a duplicate line is invisible.
```

**Warum:** Functionally idempotent, but it is a prose/code contradiction at the one place a session reads to learn where flag defaults live — the #580 account says the `.task` site is empty and it is not. The next reader either doubts #580 or moves the wrong line. The guard's doc claims to catch "a fourth `register(defaults:)`" and does not.

**Vorschlag:** Delete EchoelmusicApp.swift:744 (the `.task` copy). Optionally tighten `testExactlyThreeFlagsAreRegisteredDefaultOn` to also assert `registrationLines.count == 3` so a duplicate registration line goes red.


#### `sequencer-core-4` — SPSCQueue: ordering is correct on arm64, but the three diagnostic counters are separate 8-byte mallocs (shared cache line, full-barrier RMW per op on the audio thread) and `enqueue()` RMWs the consumer's `head` line *(unverifiziert)*

**Schwere:** niedrig · **Art:** Performance · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n "allocate(capacity: 1)" Sources/Echoelmusic/Core/SPSCQueue.swift` → 3 (`_droppedCount`, `_enqueueCount`, `_dequeueCount`; 16-byte malloc quanta ⇒ typically one 64-byte line), while `head`/`tail` get `cacheLineSize / MemoryLayout<Int>.size` slots. `grep -n "OSAtomicIncrement64Barrier" Sources/Echoelmusic/Core/SPSCQueue.swift` → in `enqueue`, `tryEnqueue` (producer) and `dequeue` (consumer). `grep -n "OSAtomicAdd64Barrier(0" Sources/Echoelmusic/Core/SPSCQueue.swift` → 2: the producer performs an atomic RMW on `head` — a store to the consumer's padded line — on every `enqueue()`. Audio-thread consumers: `grep -n "\.dequeue()" Sources/Echoelmusic/Tools/PolySynthVoice.swift` → 1065/1083/1099/1242 (render block). Correctness re-derived: producer `tryEnqueue` stores the slot only after the control-dependent `if nextTail == currentHead { return false }`, then `OSMemoryBarrier()` before the `tail` store; consumer loads `tail`, then `OSMemoryBarrier()`, then the slot, then a barrier before the `head` store — a valid release/acquire fence pairing; `ResolvedPatch`/`NoteCommand`/`TrackFX`/`PolyBioParams` are heap-free value types (`grep -n "struct ResolvedPatch" -A 20 Sources/Echoelmusic/DSP/SynthPatch.swift` → only Float/enum fields), so the slot `= nil` on the render thread frees nothing.
```

**Warum:** Each dequeued command costs the render thread three full `dmb ish` fences plus an RMW on a line the main thread also writes — small at today's rates (tens of commands/s) but it is the one lock-free spine, and its own header promises "cache-line aligned to prevent false sharing", which is true for the indices and false for the counters. No listener reads the counters in production (`git grep -n "droppedCount\|enqueueCount\|dequeueCount" -- Sources` outside SPSCQueue.swift → none).

**Vorschlag:** SPSCQueue.swift only: allocate the three counters with the same 64-byte stride as `head`/`tail`, and since each counter has exactly one writer, replace `OSAtomicIncrement64Barrier` with a plain `pointee += 1` (readers are diagnostics). Replace `OSAtomicAdd64Barrier(0, head)` in `enqueue()` with a plain load + `OSMemoryBarrier()` (the `tryEnqueue` form). Keep `SPSCQueueOverflowTests` as the regression pin.


#### `sequencer-core-5` — MIDI export floors 480-PPQ note ticks to 96 PPQ, discarding recorded/microtimed offsets; the shared `Humanizer` documents its ticks in 96 PPQ but `TouchQuantizer` applies them in 480 *(unverifiziert)*

**Schwere:** niedrig · **Art:** Chance · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n "ticksPerQuarter" Sources/Echoelmusic/Sequencer/MIDIFileExporter.swift Sources/Echoelmusic/Sequencer/Note.swift` → exporter 96, Note 480; `grep -n "func exportTicks" -A 2 Sources/Echoelmusic/Sequencer/MIDIFileExporter.swift` → `noteTicks * 96 / 480` (integer floor: any tick not a multiple of 5 loses up to 4 ticks ≈ 4 ms @120 BPM, lengths floor). Sources of non-grid ticks: `sed -n 9,10p Sources/Echoelmusic/Sequencer/MIDINoteRecorder.swift` ("Unquantized (sub-step precise)") and `sed -n 270,273p Sources/Echoelmusic/Studio/FloatingVisualWindow.swift` (microtiming `timingTicks: touchLife*8`, comment "8 ticks ≈ 8 ms at 120 BPM" — i.e. 480-space). `sed -n 13,17p Sources/Echoelmusic/Sequencer/Humanizer.swift` → "Maximum ± timing jitter in MIDI ticks (96 PPQ → 24 ticks per 16th)" and header "Applied at MIDI export (where real ticks exist)"; `git grep -n "\.jitter(index" -- Sources` → 5 sites, one in TouchQuantizer.swift:223 (480-space). The `.humanized` preset doc "±4 ticks (~21 ms at 120 BPM)" is therefore 5× off for the quantizer caller. Key signature, time signature and tempo meta are correct (`majorSf` table and relative-minor +3 verified by hand; `Tests/EchoelmusicTests/MIDIFileImporterTests.swift:82/91` pin the bytes).
```

**Warum:** The App-Store text claims MIDI export (CLAUDE.md: "nicht entfernen, ohne fastlane/metadata mitzuziehen"). A DAW import of a played-in take is up to 4 ms early per note and shortened — not wrong, but below what the internal 480-PPQ model already holds. The unit ambiguity in `Humanizer` is the kind of two-tick-spaces note that CLAUDE.md's rate lesson ("eine Rate gehört zu genau EINER Operation") already cost the project once.

**Vorschlag:** (a) Doc-only, S: state in Humanizer.swift that `timingTicks` is in the CALLER's tick space and correct the header's "applied at MIDI export" (TouchQuantizer is a second caller). (b) Optional, M: export at `Note.ticksPerQuarter` (480) — change `MIDIFileExporter.ticksPerQuarter`, make `ticksPerStep` derive from it, scale the exporter's humanize delta ×5, and re-pin the byte fixtures in `MIDIFileExporterTests`/`MIDIExportMelodyOnlyTests`/`MIDIFileImporterTests`. Do (a) now; (b) only with the tests in the same commit.


#### `sequencer-core-6` — A tempo automation lane bypasses the user's BPM lock every transport step, while the modulation route honours it — two tempo sources, two precedence rules *(unverifiziert)*

**Schwere:** niedrig · **Art:** Risiko · **Aufwand:** S · **Founder-gated:** ja

**Evidenz (Befehle wörtlich):**

```
`grep -n "lockBPM\|lock" Sources/Echoelmusic/Core/AutomationPlayer.swift` → no lock read; `sed -n 374p` → `case .tempo: pattern?.setTempo(real, source: .automation)` unconditionally (called from `applyStep` on every step). `sed -n 1215,1226p Sources/Echoelmusic/EchoelmusicApp.swift` → the modulation route says "1. the user's BPM lock wins GLOBALLY — a locked take ignores the route" and guards on `UserDefaults.standard.bool(forKey: "studio.lockBPM")`. The lane path is live for persisted documents: `git grep -n "setTimelineLanes(" -- Sources` → PianoRollView.swift:651 feeds `TimelineDocument.automation` into the player; no surface can draw one today (CLAUDE.md #473 note, `TimelineAutomationRow` deleted).
```

**Warum:** `setTempo` also cancels any in-flight glide (`tempoGlideTarget = 0`) and re-arms the tick timer each step, so a stale persisted tempo curve from an older build silently overrides a lock the player just set, on every step, with no UI showing the curve exists. T2 is not violated (no heart rate), but the lock's promise ("wins GLOBALLY") is only half true and neither `TempoInvariantTests` nor `TheTempoDestinationHasNoRouteTests` states the intended precedence.

**Vorschlag:** Decision first (musical precedence: lock vs. authored automation). If lock wins: guard `applyEnum(.tempo)` in AutomationPlayer.swift on the `studio.lockBPM` default (one line, mirroring EchoelmusicApp.swift:1223) and add a claim to TempoInvariantTests.swift. If automation wins: say so at `TempoSource.automation`'s doc and at the EchoelmusicApp comment ("GLOBALLY" → "over the modulation route").


#### `sequencer-core-7` — `ProGate.proFeatures` still lists `.auv3Plugin` and `.videoFXCatalog` — two capabilities the founder removed — as the paid set the store is to be repurposed around *(unverifiziert)*

**Schwere:** niedrig · **Art:** Status-Drift · **Aufwand:** S · **Founder-gated:** ja

**Evidenz (Befehle wörtlich):**

```
`sed -n 40,50p Sources/Echoelmusic/Core/ProGate.swift` → `proFeatures = [.exportFormatPresets, .auv3Plugin, .extendedPresetPacks, .videoFXCatalog]`; `git grep -n "auv3Plugin\|videoFXCatalog" -- Sources Tests` → ProGate.swift only (zero readers, zero tests). `grep -n "AUv3 REMOVED" project.yml` → line 225 ("founder verdict: Echoelmusic = pure instrument, no AUv3", 2026-07-24); video edit removed with #121 Slice 3 (CLAUDE.md). `grep -n "guard FeatureFlags.storeKit" Sources/Echoelmusic/Core/EchoelStore.swift` → 29, so nothing executes today.
```

**Warum:** CLAUDE.md keeps `ProUnlockView`/`EchoelStore`/`ProGate` explicitly "um dafür UMGEWIDMET zu werden" for the v1.1 "Echoel Live" subscription. A v1.1 session that repurposes this enum inherits a paid-feature list naming an AUv3 plugin that does not exist — the same over-claim class #184 removed from the Store text, one hop earlier.

**Vorschlag:** ProGate.swift only: remove the two cases from `proFeatures` (or the enum) with a ⛔ line naming #121 Slice 2/3 and the 2026-07-24 verdict; leave `productID` and the always-free set untouched. Founder-gated because the store's future shape (v1.1 subscription vs one-time Pro) is his 2026-07-10 decision.


### Ship-Pfad (Build, Entitlements, Review) (`ship-path`)

The ship path is largely in order as measured: the iOS 18 floor is synced in all three sources (`Package.swift:47` `.iOS("18.0")`, `project.yml:12/200/279` `18.0`, `Resources/iOS/Info.plist` `MinimumOSVersion` 18.0); all nine `NS*UsageDescription` keys are present, each backed by a real producer in `Sources/` (CBCentralManager in PolarH10BioPublisher, PHPhotoLibrary in VisualRecorder, CLLocationManager in LocationNamer, HKObjectType in EchoelBioEngine, AVAudioApplication.requestRecordPermission in AudioEngine/MicrophoneManager, MultipeerSession + MIDINetworkSession for local network), and `scripts/check-infoplist.sh` guards them at the compile gate; the privacy manifest declares the three required-reason categories the code actually uses (UserDefaults via `suiteName`, FileTimestamp via `.creationDateKey` in VideoLibraryPanel, SystemBootTime via `ProcessInfo.systemUptime`), so neither ITMS-90683 nor ITMS-91053 is expected today; Xcode 26.2 is pinned consistently in the four ship-relevant workflows; the four ASC secrets are name-checked by the preflight job; `ITSAppUsesNonExemptEncryption=false` is honest (no CryptoKit/CommonCrypto in Sources). What is wrong is smaller but real: the app has NO in-app link to its privacy policy (a 5.1.1(i) rejection shape for a HealthKit app, one-file fix); the auto-merge-without-gate hole (#683) is confirmed still open and compounded by a dead `skip_tests` input and an archive job that does not depend on the compile check; CLAUDE.md:231 claims the Watch is "ausgeliefert" while `project.yml:224` keeps the embed commented out; the two build definitions disagree on Swift language mode (Xcode 6.0 vs SwiftPM 5); nothing guards the `PrivacyInfo.xcprivacy` declaration in project.yml, which is exactly how it silently failed to ship until 2026-07-21; and the manifest and Bonjour list carry unbacked declarations.

#### `ship-path-1` — No in-app link to the privacy policy — App Review 5.1.1(i) for a HealthKit app

**Schwere:** hoch · **Art:** Risiko · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`git grep -c 'echoelmusic.com/privacy' -- Sources | awk -F: '{s+=$2} END{print s+0}'` → 0. `git grep -niE 'privacy' -- Sources | grep -iE 'https?://|Link\(|openURL'` → 0 lines. The only in-app web link is the homepage: `git grep -n 'websiteURL' -- Sources/Echoelmusic/Studio/WorkspaceView.swift` → `private static let websiteURL = URL(string: "https://echoelmusic.com")`. The policy page exists on the site (`git ls-files docs | grep -E '^docs/privacy'` → `docs/privacy.html`, `docs/privacy/index.html`) and is the ASC metadata URL (`cat fastlane/metadata/en-US/privacy_url.txt` → https://echoelmusic.com/privacy). The app requests HealthKit read+write (`git grep -n 'HKObjectType.quantityType' -- Sources/Echoelmusic/Bio/EchoelBioEngine.swift` → heartRate, heartRateVariabilitySDNN, respiratoryRate) and Info.plist carries both `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`.
```

**Warum:** Guideline 5.1.1(i) requires the privacy-policy link both in ASC metadata AND "within the app in an easily accessible manner"; for HealthKit apps reviewers check this specifically (5.1.1(iii)/2.5.x cross-reference). The metadata half is done; the in-app half is absent. A HealthKit app with no in-app policy link is a common first-submission rejection, and it is the cheapest item on this list to close.

**Vorschlag:** One file: add a `Link("Privacy policy", destination: URL(string: "https://echoelmusic.com/privacy"))` beside the existing `websiteURL` link in `Sources/Echoelmusic/Studio/WorkspaceView.swift` (or in `Studio/LearnView.swift` next to the announcements toggle) — a static Link reads no hot state, so the 10.76.50 root-churn law is untouched. Optional second file: a CISmoke guard asserting `Sources/` contains the string `echoelmusic.com/privacy` at least once.

- Prüfer (bestätigt, Konfidenz high, Schwere hoch): Every command in the evidence reproduces at /home/user/Echoelmusic on 2026-09-10: `git grep -c 'echoelmusic.com/privacy' -- Sources | awk …` → 0; `git grep -niE 'privacy' -- Sources | grep -iE 'https?://|Link\(|openURL'` → 0 lines; `git grep -noE 'https?://…' -- Sources` finds exactly one non-GitHub, non-comment URL literal in the app: `WorkspaceView.swift:134 private static let websiteURL = URL(string: "https://echoelmusic.com")` (opened via `openWebsite()` at :736, wired to the brand Button at :590). `git ls-files docs | grep '^docs/privacy'` → `docs/privacy.html`, `docs/privacy/index.html`; `fastlane/metadata/en-US/privacy_url.txt` → `https://echoelmusic.com/privacy` (and `Tests/CISmoke/T…
- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Re-derived: `git grep -c 'echoelmusic.com/privacy' -- Sources` → 0; `git grep -nE 'Link\(|openURL' -- Sources` shows the only web door is the brand tap to https://echoelmusic.com (WorkspaceView.swift:134/590/736); OnboardingView.swift:181-207 is a 5-line safety notice, not a policy link. HealthKit read+write is real. History check: memory/decisions.md, decisions.csv, HARNESS_LEDGER.md, BAUSTELLEN_BOARD.md, AUDIT_2026-07-23_SHIP_READINESS.md, DEEP_AUDIT_2026-09-04 and SESSION_LOG cycles #771/#772/#1010 enumerate 5.1.1 surfaces (usage strings, store URLs) and none names an in-app privacy link; `git log -S'echoelmusic.com/privacy' -- Sources` empty; last 30 commits untouched area; no founder de…

#### `ship-path-2` — Auto-merge to main still waits for no gate (#683), the TestFlight archive never runs tests, and the archive job does not depend on the compile check

**Schwere:** mittel · **Art:** Risiko · **Aufwand:** M · **Founder-gated:** ja

**Evidenz (Befehle wörtlich):**

```
`grep -c 'needs:\|workflow_run\|conclusion' .github/workflows/auto-merge-claude.yml` → 0 (the file's only `if: false` is the TestFlight dispatch at line 107; last touched `ccee983`, `git log --oneline -1 -- .github/workflows/auto-merge-claude.yml`). Path filter (`sed -n '15,20p' .github/workflows/auto-merge-claude.yml`) is `Sources/** Tests/** Package.swift project.yml .github/workflows/**` — `Resources/**` (Info.plist, PrivacyInfo.xcprivacy) and `*.entitlements` are absent, as `ContentPipeline/README.md:61-62` already records. In `testflight.yml`: `grep -n 'skip_tests' .github/workflows/testflight.yml` → ONE hit, line 26 (the input declaration) — nothing reads it, so no test step exists on the archive path at all; `sed -n '292,296p' .github/workflows/testflight.yml` → the `ios` archive job has `needs: [preflight]` only, so `compile_check` (line 130, `needs: preflight`) runs in parallel and cannot stop the archive. CI/CD cannot serve as a gate while #396 lives: `grep -n '#396' Tests/CISmoke/CLAUDE.md` → line 489 `TEST EXECUTE FAILED = #396, founder-gated`.
```

**Warum:** `main` can contain a commit that fails `Xcode Compile Check` (CLAUDE.md records #681 doing exactly that), and the tokenless deploy (`push: paths: .deploy/release`) archives from ANY branch with no test step and without waiting for its own compile check. Today the only executable gate on a shipped binary is that xcodebuild archive itself succeeds. Severity stays medium, not high, because the auto-merge's TestFlight dispatch is `if: false` and deploy is an explicit `.deploy/release` bump — an ungated `main` never reaches a user by itself.

**Vorschlag:** Founder-gated, `.github/workflows/**` — REPORT ONLY, in this order: (1) `testflight.yml` `ios` job: `needs: [preflight, compile_check]` and `if: needs.compile_check.result == 'success' || needs.compile_check.result == 'skipped'` (one line each) so the archive waits for the compile gate that already exists; (2) either wire `skip_tests` to a `xcodebuild test -scheme Echoelmusic` step (Tests/CISmoke, ~3 min) or delete the dead input so the UI stops promising a test run; (3) `auto-merge-claude.yml`: add `Resources/**` and `*.entitlements` to `paths:` so a purpose-string or manifest fix can reach `main` on its own; (4) a real gate on the merge itself needs `workflow_run` on `Xcode Compile Check` — feasible now because that workflow is reliable, whereas CI/CD is not until #396 is fixed. `Tests/CISmoke/TheAutoMergeWaitsForNoGateTests.swift` will go red on step (4) by design and names the CLAUDE.md paragraph to update.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Every cited command re-ran and matched. `grep -c 'needs:\|workflow_run\|conclusion' .github/workflows/auto-merge-claude.yml` → 0; its only `if: false` is line 107 (the "Trigger TestFlight" step, disabled 2026-06-16); last touch `ccee983`; `sed -n '15,20p'` shows exactly the five-entry allow-list `Sources/** Tests/** Package.swift project.yml .github/workflows/**` — `Resources/**` and `*.entitlements` absent, and `ContentPipeline/README.md:61-62` records precisely that ("`Resources/**`, `ci_scripts/**` und die `*.entitlements` — die letzten drei sind ship-relevant"); the tracked files `Echoelmusic.entitlements`, `Resources/iOS/Info.plist`, `Resources/PrivacyInfo.xcprivacy` exist. In `testflig…

#### `ship-path-3` — CLAUDE.md says the Watch is 'ausgeliefert'; project.yml keeps the embed commented out — no watch app ships

**Schwere:** mittel · **Art:** Status-Drift · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n 'Heute ausgeliefert' CLAUDE.md` → line 231: `**Heute ausgeliefert: iPhone ("1") + Watch als Anzeige ("4").**`. `sed -n '224p' project.yml` → `# - target: EchoelmusicWatch   # re-enable once the embed phase is correct` (the app target's `dependencies:` lists only `EchoelmusicWidgets`, line 212). The table three lines below CLAUDE.md:231 says the opposite of the headline: `Target existiert und ist **NICHT eingebettet**`. `fastlane/Fastfile:171` `lane :upload_watchos` targets `com.echoelmusic.app.watchkitapp` standalone (`fastlane/Appfile` `for_lane :upload_watchos`) — no workflow calls it (`grep -rn 'upload_watchos' .github/workflows/` → 0). `EchoelmusicWatch` is compiled in isolation only (`testflight.yml:277` `compile_scheme EchoelmusicWatch`, inside the skippable `compile_check` job).
```

**Warum:** CLAUDE.md is the always-loaded law file and this is its platform-status headline; a session reading 'Watch als Anzeige ausgeliefert' will plan Watch UI work, Watch screenshots, or a Watch App Review note for users that do not exist. `TARGETED_DEVICE_FAMILY: "4"` (project.yml:335) is a target setting, not a shipping fact. The same sentence contradicts its own table, so the file currently states both truths.

**Vorschlag:** One file, CLAUDE.md line 231: replace `+ Watch als Anzeige ("4")` with `— die Watch ist ein KOMPILIERTES, NICHT EINGEBETTETES Target (project.yml `# - target: EchoelmusicWatch`); es liefert heute kein Watch-App aus`. Optionally extend `Tests/CISmoke/TheWatchHasNoTransportTests.swift` with one claim that the CLAUDE.md headline does not contain `Watch als Anzeige` while the project.yml embed line stays commented (positive pin on project.yml, not a negative scan on the ledger — #491).

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Re-derived every cited item. `grep -n 'Heute ausgeliefert' CLAUDE.md` → line 231 `**Heute ausgeliefert: iPhone (\"1\") + Watch als Anzeige (\"4\").**`; the table three lines below (CLAUDE.md:236) says `Target existiert und ist **NICHT eingebettet**` — the headline and its own table contradict each other. `sed -n '224p' project.yml` → `# - target: EchoelmusicWatch # re-enable once the embed phase is correct`, and the app's `dependencies:` (lines 206–228) lists only `EchoelmusicWidgets`; the block above it says "embed BLOCKED (C6b) … Kept dependency-OFF". `grep -rn upload_watchos .github/workflows/ | wc -l` → 0; `fastlane/Fastfile:171 lane :upload_watchos` and `fastlane/Appfile:35-36` target `…

#### `ship-path-4` — Nothing guards the PrivacyInfo.xcprivacy declaration in project.yml — the 2026-07-21 'manifest never shipped' failure can recur silently

**Schwere:** mittel · **Art:** Risiko · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`git grep -ln 'PrivacyInfo\|xcprivacy' -- Tests/CISmoke` → 0 files. The manifest ships only via two hand-placed `sources:` entries: `grep -n 'PrivacyInfo.xcprivacy' project.yml` → lines 137 (app) and 257 (widget), each needing `type: file` + `buildPhase: resources`. project.yml:112-115 records that the previous `resources:` block was silently dropped by XcodeGen so 'the App Store privacy manifest was absent' for an unknown period. `Xcode Compile Check` builds `Sources/` only (`.github/workflows/xcode-compile-check.yml:59`, `-scheme Echoelmusic`) and never inspects bundle contents, and there is no `-showBuildSettings`/`ls .app` step in `testflight.yml` (`grep -n 'xcprivacy\|PrivacyInfo' .github/workflows/*.yml` → 0).
```

**Warum:** Since iOS 17.5 Apple rejects at upload with ITMS-91053 (`Missing API declaration … NSPrivacyAccessedAPICategorySystemBootTime`) when the manifest is absent and required-reason APIs are present — `ProcessInfo.systemUptime` is called on the rPPG frame path (`Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift:1006`). A well-meant project.yml tidy (e.g. re-adding a `resources:` key, which the file warns about) removes the manifest with every gate green; the founder learns at upload time.

**Vorschlag:** One new file, `Tests/CISmoke/ThePrivacyManifestIsDeclaredForBothTargetsTests.swift`: parse `project.yml` as text and assert exactly two `- path: Resources/PrivacyInfo.xcprivacy` entries, each followed within 3 lines by `buildPhase: resources`, and that `Resources/PrivacyInfo.xcprivacy` exists and declares `NSPrivacyAccessedAPICategorySystemBootTime` and `NSPrivacyAccessedAPICategoryUserDefaults` (the two categories with measured callers). Per `Tests/CISmoke/CLAUDE.md` the guard is graded by transcription in a web session.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Every evidence command reproduces. `git grep -ln 'PrivacyInfo\|xcprivacy' -- Tests/CISmoke` → exit 1, 0 files. `grep -n 'PrivacyInfo.xcprivacy' project.yml` → 112 (comment), 137 (app, `type: file` + `buildPhase: resources` on the next two lines), 257 (widget, same shape); the widget IS embedded (`- target: EchoelmusicWidgets` at project.yml:212) so both entries are load-bearing. project.yml:112-115 records verbatim that the manifest "had never shipped: the App Store privacy manifest was absent" until the `resources:` block was replaced (the cited commit 8f362ea predates this shallow clone's graft, so the comment is the surviving record — cited correctly). `grep -n 'xcprivacy\|PrivacyInfo' .g…

#### `ship-path-5` — Swift language mode diverges: Xcode builds in Swift 6 mode, SwiftPM in Swift 5 with -warnings-as-errors — Package.swift's own comment argues against a state that already ships

**Schwere:** mittel · **Art:** Status-Drift · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n 'SWIFT_VERSION' project.yml` → line 24 `SWIFT_VERSION: "6.0"` (Xcode's Swift Language Version → Swift 6 mode, strict concurrency as errors); `grep -nE 'SWIFT_STRICT_CONCURRENCY|SWIFT_TREAT_WARNINGS_AS_ERRORS' project.yml` → 0. `sed -n '1p' Package.swift` → `swift-tools-version: 5.10` (language mode 5) with `.unsafeFlags(["-warnings-as-errors"])` and `StrictConcurrency=targeted` (Package.swift:96-99). Package.swift:35-40 states a tools bump 'turns today's strict-concurrency warnings into build failures — a large, untestable change' — but every gate that ships (`xcode-compile-check.yml`, `ci.yml` xcodebuild jobs, `testflight.yml` archive) goes through xcodegen and therefore already compiles in Swift 6 mode. `git ls-files Tests/CISmoke | grep -i Manifest` → `TheManifestArgumentOrderIsTheCompilersTests.swift` pins argument order, not language mode.
```

**Warum:** Two build definitions, two rule sets: code that passes `swift build` on the founder's Mac (mode 5) can fail the Xcode gate on a Swift 6 isolation error, and code that compiles in Xcode with a warning fails SwiftPM's warnings-as-errors. The Package.swift comment is the line a session reads before touching the manifest, and it describes the Swift-6 migration as future risk when it is shipped reality — inviting a session to 'protect' a hurdle already cleared. Not a defect in the shipped binary; a trap in the workbench.

**Vorschlag:** One file, Package.swift: correct the comment block at lines 35-40 to say Xcode already builds in Swift 6 mode via `SWIFT_VERSION: "6.0"` and that the tools-version pin only affects local `swift build`. Alignment itself (tools-version 6.0 + explicit `.swiftLanguageMode(.v6)` + dropping the `.iOS("18.0")` string form) is a Council item because it changes local-build semantics; do it as its own slice after the comment is honest.

- Prüfer (bestätigt, Konfidenz high, Schwere niedrig): Every cited command reproduces: `grep -n SWIFT_VERSION project.yml` → line 24 `SWIFT_VERSION: "6.0"` in settings.base with no per-target override; `grep -nE 'SWIFT_STRICT_CONCURRENCY|SWIFT_TREAT_WARNINGS_AS_ERRORS' project.yml` → 0; `sed -n 1p Package.swift` → `swift-tools-version: 5.10`; Package.swift:96-99 has `-warnings-as-errors` + `StrictConcurrency=targeted`; Package.swift:34-40 calls a tools bump "a large, untestable change" and prescribes `.swiftLanguageMode(.v5)`. No `xcodebuild` line in ci.yml/xcode-compile-check.yml/testflight.yml overrides SWIFT_VERSION or passes -swift-version, so app, widgets, watch and BOTH test bundles (project.yml:355 EchoelmusicTests=Tests/CISmoke, :395 Ech…

#### `ship-path-6` — Privacy manifest declares Disk Space (E174.1 'display disk space to the user') with zero disk-space API calls, and uses the SDK-only reason 0A2A.1 *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`git grep -c 'volumeAvailableCapacity\|attributesOfFileSystem\|systemFreeSize\|volumeTotalCapacity' -- Sources | awk -F: '{s+=$2} END{print s+0}'` → 0, while `grep -n 'NSPrivacyAccessedAPICategoryDiskSpace' Resources/PrivacyInfo.xcprivacy` → declared with `E174.1` and `85F4.1`. `grep -n '0A2A.1' Resources/PrivacyInfo.xcprivacy` → declared under FileTimestamp; Apple defines 0A2A.1 as 'your third-party SDK is providing a wrapper function around file timestamp API(s)' — inapplicable to a first-party app manifest (the real usage, `.creationDateKey` in `Sources/Echoelmusic/Studio/VideoLibraryPanel.swift:486-493`, is covered by the co-declared `C617.1`). `grep -n 'AUv3' Resources/PrivacyInfo.xcprivacy` → line 51 names the AUv3 target removed 2026-07-24 (project.yml:225).
```

**Warum:** Over-declaration does not trigger ITMS-91053 and App Review does not reject on it, but E174.1 is a false statement in a signed privacy document ('the app displays disk space to the user' — it does not), and the manifest is the artifact a reviewer opens on a privacy question. Same class as the `bluetooth-peripheral` background mode the plist removed for being unbacked (Info.plist comment above `UIBackgroundModes`).

**Vorschlag:** One file, `Resources/PrivacyInfo.xcprivacy`: delete the DiskSpace dict, drop `0A2A.1` (keep `C617.1`), and replace `widget/AUv3` with `widget` in the UserDefaults comment. Re-run the disk-space grep above before committing; if a future `AVAssetWriter` pre-flight adds a free-space check, re-declare with `85F4.1` only.


#### `ship-path-7` — NSBonjourServices lists nine service types; only three have a browser or advertiser in code *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** ja

**Evidenz (Befehle wörtlich):**

```
`grep -c '<string>_' Resources/iOS/Info.plist` → 9. Backed: `_echoel-colab._tcp` / `_echoel-colab._udp` ← `git grep -n 'static let serviceType' -- Sources/Echoelmusic/Sync/MultipeerSession.swift` → `"echoel-colab"` (MCNearbyServiceAdvertiser/Browser at lines 117/119); `_apple-midi._udp` ← `git grep -c 'MIDINetworkSession' -- Sources` → 3 files. Unbacked: `_http._tcp`, `_rtsp._tcp`, `_artnet._udp`, `_osc._udp`, `_midi._udp`, `_echoelmusic._tcp` — `git grep -c 'NWBrowser\|NetServiceBrowser' -- Sources | awk -F: '{s+=$2} END{print s+0}'` → 0; OSC/ADM-OSC/Art-Net/sACN are unicast `NWConnection` sends to user-typed addresses (`git ls-files Sources/Echoelmusic/Sync | grep -E 'OSCSender|ArtNetSender|SACNSender'`), which need `NSLocalNetworkUsageDescription` (present) and no Bonjour type. `Tests/CISmoke/EveryPermissionPromptHasACapabilityTests.swift` covers usage strings, not this array.
```

**Warum:** Functionally nothing is missing — the OSC/Art-Net local-network prompt is correctly backed by the usage description. But `_rtsp._tcp`/`_http._tcp` are streaming-era leftovers (RTMP/HaishinKit was never linked, `Package.swift` `dependencies: []`) and read as capabilities to a reviewer scanning the plist; unbacked declarations are the exact class the plist itself already pruned for 2.5.4.

**Vorschlag:** Founder-gated (`Resources/iOS/Info.plist`) — REPORT ONLY: trim `NSBonjourServices` to the three backed entries (`_echoel-colab._tcp`, `_echoel-colab._udp`, `_apple-midi._udp`). If an NWBrowser for OSC/Art-Net discovery is ever built, re-add its type together with the browser in the same commit. Optionally extend `EveryPermissionPromptHasACapabilityTests` with one claim per listed type requiring a code producer.


#### `ship-path-8` — One workflow pins Xcode 16.2/macos-15 against a project written for Xcode 26, and the project.yml MARKETING_VERSION fallback is 94 versions behind *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** ja

**Evidenz (Befehle wörtlich):**

```
`grep -nE 'XCODE_VERSION:' .github/workflows/*.yml` → benchmark.yml:24 `'16.2'`; ci.yml/full-tests.yml/pr-check.yml/testflight.yml all `'26.2'`; `grep -n 'runs-on' .github/workflows/benchmark.yml` → `macos-15`, every other job `macos-26`. benchmark.yml fires on every push to `main` touching `Sources/**` (`sed -n '10,16p' .github/workflows/benchmark.yml`) and runs `xcodegen generate` against a project.yml whose comments are Xcode-26-specific (`grep -n 'Xcode 26' project.yml` → lines 60, 380, 420). `xcode-compile-check.yml` has no `xcode-version` pin at all (`grep -c 'xcode-version' .github/workflows/xcode-compile-check.yml` → 0) — it takes the image default. Version drift: `grep -n 'MARKETING_VERSION:' project.yml` → line 40 `"10.79.372"`; `grep -m1 -oE 'v[0-9]+\.[0-9]+\.[0-9]+' .deploy/release` → `v10.79.466`; the comment at project.yml:33 says it once 'drifted 17 versions before anyone looked'.
```

**Warum:** A benchmark that builds with a different Xcode major than the ship path measures a toolchain nobody ships, and if it fails it adds one more perpetually-red check next to the #396 one, training everyone to ignore red. The unpinned compile gate can silently diverge from the 26.2 archive when GitHub rolls the macos-26 image. The MARKETING_VERSION fallback is latent (the deploy `sed` overrides it) but it is the version every non-TestFlight build and `device-log-triage` reads.

**Vorschlag:** Founder-gated (`.github/workflows/**`, `project.yml`) — REPORT ONLY: (1) benchmark.yml:24 → `'26.2'` and `runs-on: macos-26`, or disable it until it measures the shipping toolchain; (2) add `- uses: maxim-lobanov/setup-xcode@v1 with: xcode-version: '26.2'` to xcode-compile-check.yml so gate and archive share a pin; (3) bump project.yml:40 to the current `.deploy/release` version on the next deploy commit.


### Claims-Konsistenz (Website, Store, Pipeline) (`docs-claims`)

Measured 2026-09-10 on branch claude/echoelmusic-review-optimize-u5jjpd (HEAD ffd334e). The marketing surfaces are in unusually good shape: every over-claim class CLAUDE.md and ContentPipeline/CLAIMS.md forbid (AUv3, RTMP, multitrack, video edit, MPE-in, Tune-to-key/voice harmonizer/granular after #1024, prices) appears on docs/*.html, fastlane/metadata/** and README.md only inside explicit negations; banned vocabulary (wellness/healing/chakra/Solfeggio/BLAB/Vibrational Force/biohacking) is absent from user-facing copy except a third-party project link on artist.html and a "please don't call it wellness" line on press.html; SEO basics are complete on all 16 indexed pages (title, description, og:title/og:image, twitter:card, canonical, JSON-LD, sitemap.xml, robots.txt, CNAME); `python3 scripts/foreign-needles.py` reports 0 broken needles; genre and scale counts are guard-derived (WebsitePagesAreFindableAndHonestTests) and match code (offered = 19, taxonomy = 36). The drift that remains runs in the UNDER-claim direction: the website still says "four generative looks" while `LookBlendMap.library` ships five (Dish, #1102), the founder's touch-playable visual is sold only on faq.html, and the external-display stage is missing from both App Store descriptions and from index.html. Two locale/wording inconsistencies (de-DE release notes vs en-US, hero "to calm down") are cheap to align. `scripts/doctor.py` reports 2 CRITICAL findings, both in founder-gated `.github/workflows/ci.yml` (masked build steps; a test filter naming a non-existent `ComprehensiveTestSuite`) — report-only.

#### `docs-claims-2` — The touch-playable visual is sold nowhere on the acquisition pages — only faq.html carries it

**Schwere:** mittel · **Art:** Chance · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Shipped: `git grep -n 'TouchInstrumentView(' -- Sources` → exactly one construction, Sources/Echoelmusic/Studio/FloatingVisualWindow.swift:895 (the window that is open at launch), plus a comment hit in FieldAutoPlay.swift:61; CLAIMS.md ✅ row "Das Bild ist SPIELBAR" and fastlane/metadata/en-US/description.txt:13 ("The picture is playable: touch the visual and your fingers become notes") both claim it. Website coverage: `grep -c -iE 'playable|touch the visual|fingers' docs/index.html docs/overview.html docs/tools.html docs/artist.html docs/press.html` → 0 0 0 0 0; `grep -c -iE 'playable|touch the visual|fingers' docs/faq.html` → 3. index.html's "Living visuals" card (line 803) sells the visual only as something to watch, record and project.
```

**Warum:** This is the founder's own 2026-07-07 ask ("das Visual in ein Multi-Touch Instrument umwandeln") and the one capability that turns "visuals" into "instrument" for a first-time reader; the CLAIMS row already records that the FAQ actively DENIED it until #999. The home page, overview, tools and press pages — the ones a visitor reads before the FAQ — still describe the pre-#999 product.

**Vorschlag:** One sentence in docs/index.html "Living visuals" card (after line 803) and one in docs/overview.html's EchoelVis/visual row, using the CLAIMS wording ("touch the visual and your fingers become notes, quantized to the take's key" — ONE surface, never "touch instruments"). Two files; the FAQ sentence at faq.html:114 is the template.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Every command in the evidence reproduces byte-for-byte. `git grep -n 'TouchInstrumentView(' -- Sources` → exactly one construction at Sources/Echoelmusic/Studio/FloatingVisualWindow.swift:895 plus the comment hit at Sequencer/FieldAutoPlay.swift:61. `grep -c -iE 'playable|touch the visual|fingers'` over docs/index.html, overview.html, tools.html, artist.html, press.html → 0 0 0 0 0; over docs/faq.html → 3 (lines 44 JSON-LD, 114 tools list, 134 the hands answer). Extended to all 18 docs/*.html: faq.html is the ONLY page with a hit. fastlane/metadata/en-US/description.txt:13 and ContentPipeline/CLAIMS.md:53 (✅ "Das Bild ist SPIELBAR") both claim it, and the CLAIMS row itself records that the F…

#### `docs-claims-3` — External-display stage (USB-C/HDMI/AirPlay) is missing from BOTH App Store descriptions and from index.html

**Schwere:** mittel · **Art:** Chance · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Shipped: `grep -n ExternalDisplaySceneDelegate Resources/iOS/Info.plist` → line 44 (UISceneConfiguration entry point); `git grep -n 'ExternalDisplayScene' -- Sources | wc -l` → 6 (readers of the same look keys); CLAIMS.md ✅ row "Beamer/Externer Bildschirm … `ExternalDisplayScene` (#206)". Copy: `grep -niE 'display|screen|airplay|hdmi|projector|beamer' fastlane/metadata/en-US/description.txt fastlane/metadata/de-DE/description.txt` → 0 hits in either locale; `grep -c -iE 'airplay|hdmi|external (display|screen)' docs/index.html` → 0; the only sale is docs/tools.html:237 (1 hit) and docs/overview.html (2). index.html:803 says "in a movable window or fullscreen for projection" — projection by mirroring, not the dedicated stage.
```

**Warum:** For the stated audiences (Installation · Event · Theater · Performance) "the visual takes the connected screen as its own stage while the phone stays the instrument" is the concrete reason to bring the app to a venue, and the App Store description is the one surface a reviewer and a buyer both read. A shipped, CLAIMS-approved, plist-declared capability with zero Store mentions is a pure under-claim.

**Vorschlag:** Add one CONNECT bullet to fastlane/metadata/en-US/description.txt and fastlane/metadata/de-DE/description.txt ("Connect a screen over USB-C/HDMI or AirPlay — the visual takes it as its own stage while the phone stays the instrument"), mirroring tools.html:237; optionally the same clause in docs/index.html:803. User-facing copy → Council per CLAUDE.md, but not a founder-gated file.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Re-ran every evidence command from /home/user/Echoelmusic. (1) `grep -n ExternalDisplaySceneDelegate Resources/iOS/Info.plist` → line 44, under `UIWindowSceneSessionRoleExternalDisplayNonInteractive` — reproduces. (2) `git grep -n 'ExternalDisplayScene' -- Sources | wc -l` → 17, NOT 6 as the finding states; the auditor's count is wrong but in the harmless direction (more readers, plus the type itself at Studio/ExternalDisplayScene.swift:73 and ExternalStageBridge.swift). (3) `ContentPipeline/CLAIMS.md:73` is the ✅ row "Beamer/Externer Bildschirm … `ExternalDisplayScene` (#206)" — reproduces, and unlike the neighbouring BLE-strap (line 62) and Texture+Glitter (line 74) rows it carries NO "Ger…

#### `docs-claims-4` — de-DE release notes diverge from en-US on the genre bullet and use "Meditativ", a word CLAIMS.md §2 bans — while the app's own shelf is literally "Meditative & Ambient" *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`sed -n 6p fastlane/metadata/de-DE/release_notes.txt` → "Neunzehn kuratierte Genres: acht auf dem Ambient-/Meditativ-Regal (…), zehn Techno, House und Trance (…), dazu Classical"; `sed -n 6p fastlane/metadata/en-US/release_notes.txt` → "Nineteen curated genres: Self-Observation, Deep Ambient, …" (flat list, no shelf split). Ban: `grep -n 'Wellness, Meditation' ContentPipeline/CLAIMS.md` → §2 heading. In-app label: `grep -n 'Meditative & Ambient' Sources/Echoelmusic/Sequencer/MusicStyle.swift` → line 213 (`case .meditative: return "Meditative & Ambient"`), and the offered roster contains `.stillMeditation` (`sed -n 134,145p Sources/Echoelmusic/Sequencer/MusicStyle.swift`). The website guard only recounts the NUMBER: `sed -n 616,640p Tests/CISmoke/WebsitePagesAreFindableAndHonestTests.swift` compares `MusicStyle.allCases.count`/roster, never wording.
```

**Warum:** Two locales of the same What's-New should describe the same build; today a German reader learns about a shelf structure an English reader does not, and the German text uses the one word the claims file forbids without recording that the app UI itself uses it as a musical descriptor. Either CLAIMS §2 is over-broad (a genre/shelf NAME is not a wellness promise) or the DE note is off-policy — the file that exists to settle this does not say which.

**Vorschlag:** Align fastlane/metadata/de-DE/release_notes.txt line 6 to the en-US flat list (1 file), and add one exception sentence to ContentPipeline/CLAIMS.md §2: genre and shelf names shown in the app ("Meditative & Ambient", "Still Meditation") may be quoted as labels; effect claims remain banned. Two files.


#### `docs-claims-5` — Hero copy "compose music to calm down" is an effect promise, the exact phrasing CLAIMS.md §2 draws the line at *(unverifiziert)*

**Schwere:** niedrig · **Art:** Risiko · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n -o '.\{60\}calm.\{40\}' docs/index.html docs/overview.html` → docs/index.html:645 ("compose music to <strong>calm down and observe yourself</strong>", the above-the-fold hero) and docs/overview.html:126 ("to calm down and observe yourself"). Rule: `grep -n 'Nicht erlaubt.*macht Dich ruhig' ContentPipeline/CLAIMS.md` → §2 ("Erlaubt: ruhiger Puls → andere Musik. Nicht erlaubt: macht Dich ruhig / hilft beim Schlafen"). In-app disclaimer for contrast: `git grep -n 'For self-observation, not medical diagnosis' -- Sources/Echoelmusic/Resources/Localizable.xcstrings` → line 130.
```

**Warum:** It is the first bolded sentence on the home page and states a purpose ("to calm down") rather than the mechanism the brand allows; press.html:159 in the same site asks journalists not to describe the app as wellness. A reviewer or journalist quoting the hero gets the framing the founder rejected on 2026-07-06B ("die Leute brauchen gar keine Atemübung").

**Vorschlag:** Rewrite the clause in docs/index.html:645 and docs/overview.html:126 to the mechanism form already used elsewhere on the site (e.g. "as your pulse settles, the music changes — observe yourself, or lock a BPM and export"). Two files, no guard involved (the site guards scan for feature claims, not this phrase).


#### `docs-claims-7` — index.html "Specs" tile lists Open Standards as "OSC · ADM-OSC · Art-Net" — sACN and MIDI (both shipped and sold on the same page) are dropped *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`grep -n -o 'OSC &middot; ADM-OSC &middot; Art-Net[^<]*' docs/index.html` → line 916 (no sACN, no MIDI); the same page claims sACN ten times (`grep -c sACN docs/index.html` → 10) and MPE note output at :104/:810; sACN is live: `git ls-files Sources | grep -c SACNSender` → 1, keyword `sACN` in `cat fastlane/metadata/en-US/keywords.txt`.
```

**Warum:** The Specs strip is the skimmable summary at the bottom of the home page; a lighting tech who scans it sees Art-Net only and may assume sACN (the more common console protocol) is absent — an under-claim on the page's most scannable element, inconsistent with its own JSON-LD featureList.

**Vorschlag:** docs/index.html:916 → "OSC · ADM-OSC · MIDI · Art-Net · sACN". One line, one file.


### Tests + Wächter (`tests-guards`)

The blocking bundle Tests/CISmoke is large (487 files, 3151 `func test`) and its tooling is unusually honest, but it is overwhelmingly a law-about-the-repo layer: 403 of 487 files (83 %) read source text, and 2463 of 3151 methods (78 %) live in those files; only 84 files / 688 methods are pure behaviour tests, and only 5 CISmoke files render a DSP voice at all. There is no XCTest `measure` block anywhere (0), no golden-audio render, and the one shader-compile test can skip; the 3990-method behaviour suite in Tests/EchoelmusicTests is compiled by no blocking gate. The founder-facing instruction "run `swift test` before ANY commit" runs SwiftPM's only test target — which is the NON-blocking suite — because Tests/CISmoke is not a SwiftPM test target at all. 327 of 487 guard files can throw XCTSkip (390 throw sites, ~91 of them anchor-miss skips that turn a renamed function into a silent green), and the only skip detector is an unvalidated regex over a tail-200 log window. The `prefix(N)` latent-red surface has grown from 35 (ledger, 2026-08-30) to 45 while the repair helper has 6 adopters. All five needle checkers and doctor pass their selftests today; the founder-verify queue stands at 116 open asks in 103 files, none answered.

#### `tests-guards-2` — Anchor-miss XCTSkip is a fail-open path in ~91 sites, and the only skip detector is an unvalidated regex over a tail-200 window

**Schwere:** hoch · **Art:** Risiko · **Aufwand:** M · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`git grep -l 'XCTSkip' -- 'Tests/CISmoke/*.swift' | wc -l` → 327 of 487 files; `git grep -h 'throw XCTSkip' -- 'Tests/CISmoke/*.swift' | wc -l` → 390 throw sites; `git grep -B3 'throw XCTSkip' -- 'Tests/CISmoke/*.swift' | grep -c 'fileExists'` → 299 are whole-tree guards, leaving ~91 anchor-miss skips such as `Tests/CISmoke/TheMasterGainMovesInSmallStepsTests.swift:369-370` (`guard let stop = engine.range(of: "func stop(reason: StopReason) {") else { throw XCTSkip("… re-anchor this claim.") }`) and `TheAudioLanesHaveNoProducerTests.swift:247-250`. Under `xcodebuild test-without-building` (`.github/workflows/ci.yml:190`) a skip does not fail the job. The detector's own header: `sed -n '105,123p' scripts/gh-test-verdict.py` — "No log in this repo's reach contains a skip line — measured on the #805 run … zero test" and `SKIP_LINE = re.compile(r"Test [Cc]ase '([^']+)' skipped")`; window: `grep -n WINDOW scripts/gh-test-verdict.py` (tail -200, #807). Its docstring count is stale: line 105 says 358 files, today 327 (command above). The bundle's own law names this: `grep -n 'XCTSkip. would have been green' Tests/CISmoke/*.swift` (#454).
```

**Warum:** A rename of `stop(reason:)` or any anchored signature turns a guard from red to skipped-green; the gate stays green, and the only thing that would say so is a needle nobody has ever matched against a real xcodebuild skip line, read over the last 200 lines of a log. That is exactly the shape §5 of Tests/CISmoke/CLAUDE.md calls the defect this bundle exists to prevent.

**Vorschlag:** (1) One new CISmoke guard (e.g. `TheAnchorMissSkipsDoNotGrowTests.swift`) that counts `throw XCTSkip` sites NOT preceded within 3 lines by `fileExists` and asserts the count is ≤ today's measured value (ratchet, never up); its message says 'use XCTFail for a missed anchor, XCTSkip only for a missing tree'. (2) scripts/gh-test-verdict.py:105 — replace the literal 358 with the command. (3) Migrate the two sampled sites above to `XCTFail` as the first two rungs. 3 files.

- Prüfer (bestätigt, Konfidenz high, Schwere hoch): Every command reproduces exactly on today's tree: `git grep -l 'XCTSkip' -- 'Tests/CISmoke/*.swift' | wc -l` → 327 (of `git ls-files 'Tests/CISmoke/*.swift' | wc -l` → 487); `git grep -h 'throw XCTSkip' … | wc -l` → 390; `git grep -B3 'throw XCTSkip' … | grep -c fileExists` → 299 (a per-site 3-line-window recount in Python gives 298; the one-off is grep -B3 context overlap). Both cited sites exist verbatim: `Tests/CISmoke/TheMasterGainMovesInSmallStepsTests.swift:369-370` throws `XCTSkip` on a missed `func stop(reason: StopReason) {` anchor inside a test method, and `TheAudioLanesHaveNoProducerTests.swift:247-250` throws `XCTSkip` on a missed `func \(name)` anchor — while its own docstring s…
- Prüfer (widerlegt, Konfidenz high, Schwere niedrig): Numbers reproduce (per-site recount with a written predicate: `throw XCTSkip` sites 390, `fileExists` within 3 lines above 299, other 91 in 54 files — python over `git ls-files 'Tests/CISmoke/*.swift'`). But the finding is already known and deliberately parked, and its severity is inflated against the shipped gate. (1) PARKED: `scratchpads/SESSION_LOG.md:14104-14160` (#806) measured exactly this ("268 von 358, 371 Aufrufstellen") and records under "Verworfen, mit Grund" that converting the XCTSkip sites to hard failures is a MIGRATION over 268 files, the #460 shape, and was deferred; the chosen mitigation was making `gh-test-verdict.py` name skips and exit 1 (`sed -n '105,123p' scripts/gh-te…

#### `tests-guards-3` — Honest ratio: 83 % of the blocking bundle scans text; zero performance tests, zero golden-audio renders, one skippable shader-compile test

**Schwere:** mittel · **Art:** Risiko · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Files that read source text: `git grep -lE 'SourceText\.|readSource|sourceText\(|loadSource|repoRoot|packageRoot|contentsOfFile|String\(contentsOf' -- 'Tests/CISmoke/*.swift' | wc -l` → 403 of `git ls-files 'Tests/CISmoke/*.swift' | wc -l` → 487; behaviour-only files via `comm -23` of the two lists → 84. Methods: 2463 in source-reading files vs 688 in behaviour-only files (`… | xargs grep -ho 'func test[A-Za-z0-9_]*' | wc -l` on each list). CISmoke files that render/process a DSP voice: `git grep -lE 'renderBlock|\.render\(|processBlock\(|renderFrames|render\(into' -- 'Tests/CISmoke/*.swift' | wc -l` → 5. Performance: `git grep -nE '^\s*(self\.)?measure\s*(\(metrics|\{)' -- 'Tests/**/*.swift' | wc -l` → 0 (the 12 `measure` hits are a private helper in TheBandEdgeIsMeasurableTests); CLAUDE.md's PERFORMANCE table (<10 ms latency, <30 % CPU) has no enforcing test. Golden audio: `git grep -niE '\bgolden\b' -- 'Tests/**/*.swift'` → 29 hits, all the 'Golden law' (OFF = byte-identical), no reference render. Metal: `git grep -lE 'MTLCreateSystemDefaultDevice|makeLibrary' -- 'Tests/**/*.swift'` → 1 (`TheShippedShaderActuallyCompilesTests.swift`, skips at lines 139/157 without a device). The behaviour-heavy suite (`git grep -ho 'func test[A-Za-z0-9_]*' -- 'Tests/EchoelmusicTests/*.swift' | wc -l` → 3990, 0 source-reading files) is built only by full-tests.yml with `continue-on-error: true` (lines 65, 83) — doctor `--section A` CRITICAL 'A build failure here cannot turn anything red'.
```

**Warum:** The gate proves where prose sits; it does not prove the instrument sounds, keeps time, or stays under budget. A DSP regression that keeps every needle in place (e.g. a NaN path, a denormal CPU spike, a wrong gain constant) ships through two green gates, and the perf table in the law is aspiration with no measurement behind it. The ratio is not a flaw in the guards — it is the number a session must know before reading 'gates green' as 'audio works'.

**Vorschlag:** One blocking END-TO-END guard (`Tests/CISmoke/TheDDSPRenderIsDeterministicAndBoundedTests.swift`): construct `EchoelDDSP` with a fixed patch and bio params, render 4096 frames twice, assert byte-identical, all-finite, peak ≤ 1.0, and RMS > 0 when armed — deterministic, no timing, no device. Label it END-TO-END per §1. Optionally a second claim renders 60 s of frames and asserts it completes (CI wall clock is not a latency measurement — say so in the header rather than pin a millisecond). 1 file.

- Prüfer (bestätigt, Konfidenz high, Schwere mittel): Core claim reproduces exactly. `git ls-files 'Tests/CISmoke/*.swift' | wc -l` → 487; the source-reading regex over the same set → 403; `comm -23` → 84 behaviour-only files (83 %). Methods via `xargs grep -ho 'func test[A-Za-z0-9_]*' | wc -l`: 2463 in source-reading files vs 688 in behaviour-only. `measure` perf regex → 0 (no XCTest `measure` anywhere under `Tests/`). `\bgolden\b` → 29 hits, none a reference audio render (the only 'golden-file' tests, `SpatialSceneOSCTests`, pin OSC byte formatting). `TheShippedShaderActuallyCompilesTests.swift` skips at lines 139 and 157 without a Metal device (confirmed by `grep -n XCTSkip`). `full-tests.yml` has `continue-on-error: true` at lines 65 and 83…

#### `tests-guards-8` — Founder-verify queue: 116 open device asks in 103 files, none answered — the two open ship-gate checks cannot be closed by any session *(unverifiziert)*

**Schwere:** mittel · **Art:** Status-Drift · **Aufwand:** S · **Founder-gated:** ja

⚠️ beide Prüfer am Sitzungslimit gestorben; die Zahl 116/103/0 wurde von der Sitzung selbst mit `python3 scripts/founder-verify.py` nachgemessen

**Evidenz (Befehle wörtlich):**

```
`python3 scripts/founder-verify.py | head -1` → 'Founder device-session checklist — 116 OPEN asks in 103 files, none answered yet'; by area (`… | grep -nE '^── '`): AUDIO 39, VISUAL 27, UI 21, BIO 14, OTHER 11, SYNC 4, NOT ASKS 15, BLOCKED 10 (all ten BLOCKED-BY-#1024, the removed mic door). Zero `VERIFIED-` marks: `git grep -c 'VERIFIED-20' -- Sources Tests CLAUDE.md | wc -l` → 0. The three newest asks were added by #1202 (`git show --stat 013d957`).
```

**Warum:** CLAUDE.md's ship gate says two of five checks (Klang, Stabilität) are founder-ear/device only, and this queue is the shopping list for that device session. It only grows (+3 this week) and has never had a single answer, so every device-facing guard header in the bundle ('a device probe owns the rest') is a promise with no fulfilment path — and 10 of the asks now instruct opening a door #1024 removed.

**Vorschlag:** Founder action, not code: one device session that walks the AUDIO 39 in file order and writes `VERIFIED-2026-MM-DD` on the same line (the tool's own retire recipe). Session-side, cheap: mark the 10 BLOCKED asks' parent prose in CLAUDE.md's #1024 line so the next session does not re-ask them. 1 file.


#### `tests-guards-6` — `EchoelWSOLA` is a 206-line DSP core with zero production constructors, yet `StretchMode.beats.isImplemented` returns true and a test pins that as 'WSOLA pre-render' *(unverifiziert)*

**Schwere:** niedrig · **Art:** Status-Drift · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
`git grep -n 'EchoelWSOLA(' -- Sources` → 0; `git grep -n 'EchoelWSOLA' -- Sources | grep -v DSP/EchoelWSOLA.swift` → only the doc comment `Sources/Echoelmusic/Sequencer/StretchMode.swift:27`; `sed -n '74p' Sources/Echoelmusic/Sequencer/StretchMode.swift` → `case .beats: return true // WSOLA offline pre-render (editor preview)`; `Tests/EchoelmusicTests/StretchEngineTests.swift:24` pins `XCTAssertTrue(StretchMode.beats.isImplemented)`; `wc -l Sources/Echoelmusic/DSP/EchoelWSOLA.swift` → 206. The blocking bundle already knows: `grep -n 'EchoelWSOLA' Tests/CISmoke/ANonFiniteControlCannotReachTheRenderTests.swift` → line 70 'zero production construction site'. CLAUDE.md's unwired-cores sentence (ARCHITECTURE, `grep -n 'BioModulation.*CloudSync' CLAUDE.md`) does not list it, and `TheDSPLayerStaysFoundationOnlyTests.swift:149` pins it as the one unguarded-Accelerate DSP file without saying it is dead.
```

**Warum:** A session reading `isImplemented == true` plans a beats-stretch feature on top of an executor that nothing instantiates; the editor preview that would have used it went with the piano roll (#475). Same class as EchoelModalBank/EchoelCellular — kept on purpose, but cited as live by a shipped enum and a green test.

**Vorschlag:** StretchMode.swift: change the `.beats` doc/comment to 'EchoelWSOLA exists, no executor constructs it (measured `git grep -n "EchoelWSOLA(" -- Sources` → 0)'; CLAUDE.md ARCHITECTURE unwired-cores sentence: add `DSP/EchoelWSOLA` with that command. Whether `isImplemented` should flip to false is a persisted-region question (regions decode `stretchMode`) — report, do not flip. 2 files.


#### `tests-guards-7` — The always-loaded naming law `test[Unit]_[Scenario]_[Expected]` is followed by 0 of 3151 blocking-bundle methods *(unverifiziert)*

**Schwere:** niedrig · **Art:** Hygiene · **Aufwand:** S · **Founder-gated:** nein

**Evidenz (Befehle wörtlich):**

```
Rule: `grep -n 'Test methods' .claude/rules/swift-audio.md` → `test[Unit]_[Scenario]_[Expected]`. Compliance: `git grep -ho 'func test[A-Za-z0-9]*_[A-Za-z0-9]*_[A-Za-z0-9_]*' -- 'Tests/CISmoke/*.swift' | wc -l` → 0 of `git grep -ho 'func test[A-Za-z0-9_]*' -- 'Tests/CISmoke/*.swift' | wc -l` → 3151; non-blocking suite: 1334 of 3990 (same commands over 'Tests/EchoelmusicTests/*.swift'). Tests/CISmoke/CLAUDE.md never mentions the underscore form (`grep -c '_\[Scenario\]' Tests/CISmoke/CLAUDE.md` → 0); its convention is the sentence-style `TheXDoesYTests` file + `testTheY…` method that #374 ('a name describes what the code does') produced.
```

**Warum:** A prescriptive rule in the always-loaded set that the bundle it governs ignores 100 % of the time is dead law (the swift-audio.md file itself says dead law 'is prescriptive, so a session follows it'); a session that obeys it writes the one file out of 487 in a foreign style, and a reviewer cannot tell which convention is current.

**Vorschlag:** .claude/rules/swift-audio.md: scope the underscore form to Tests/EchoelmusicTests or replace it with 'sentence-style, per Tests/CISmoke/CLAUDE.md §2 (#374)'; add the two counting commands beside it. 1 file.


## 4. Die Korrekturschleife

Ein Fix je Zyklus, ≤3 Dateien, nicht-founder-gated zuerst. Die Reihenfolge folgt Schwere × Billigkeit × Reichweite
nach außen (was eine Fremd-Software HEUTE falsch empfängt, geht vor dem, was intern nur ungenau ist). Was diese
Sitzung davon gefahren hat, steht im SESSION_LOG-Eintrag `#1208 ff.`; hier steht der Plan.

| Zyklus | ID | Dateien | Test / Wächter | Bemerkung |
|---|---|---|---|---|
| 1 | `audio-dsp-1` | `DSP/EchoelDelay.swift`, `Tests/CISmoke/ANonFiniteControlCannotReachTheRenderTests.swift` | zwei neue Ansprüche (`tone = .nan`, `timeSeconds = .nan` → endlicher Ausgang) in der Form der Tests 4–5 | die Klasse von #1206b, im dritten Nachbarn; `audio-dsp-2` (Koeffizient cachen) ist die natürliche Zweitscheibe in derselben Datei, bewusst NICHT im selben Commit |
| 2 | `ship-path-1` | `Studio/LearnView.swift` (+ optional ein CISmoke-Wächter) | Wächter: `Sources/` enthält `echoelmusic.com/privacy` ≥ 1 | statischer `Link`, liest keinen heißen Zustand (10.76.50-Gesetz unberührt); `LearnView` ist über `showLearn` erreichbar (`EchoelStudioView.swift:1631`) |
| 3 | `output-sync-1` | `Sync/ADMOSCSender.swift`, `Sync/MusicMediaMapping.swift`, `Sync/SpatialSceneOSC.swift` **+** die vier Golden-Tests im selben Commit (`ADMOSCAbsenceTests`, `ADMOSCSenderTests`, `MusicMediaMappingTests`, `SpatialSceneOSCTests`) | neuer CISmoke-Wächter: kein `Sources/`-Emitter schreibt `/position/` unter `/adm/obj/` | überschreitet die 3-Dateien-Regel, weil die Golden-Strings sonst im SELBEN Commit rot werden — die Regel ist für den EINGRIFF (drei Formatierer, ein Leaf-Rename), nicht für die Zeugen. Prosa-Heimaten mitziehen: `docs/SPATIAL_EXPANSION_AUDIT.md:25`, `docs/ECHOEL_SESSION_PROTOCOL.md:36`, `scratchpads/SPEC_LIGHT_OSC_VERIFICATION.md:17–19`. NEEDS-FOUNDER-VERIFY gegen einen echten Renderer (FletcherMachine/L-ISA/Reference-Receiver) |
| 4 | `studio-ui-2` + `ship-path-3` + `bio-pipeline-3` (Status-Hälfte) | `CLAUDE.md` | `python3 scripts/foreign-needles.py` Exit 0; `TheLawFileStaysUnderItsCeilingTests` (147 021 B heute, Decke 150 000) | drei Prosa-Korrekturen in EINER Datei = ein Zyklus: PERFORMANCE-Zeilen „Visual FPS 120 / Bio Loop 120 Hz" → gemessen (60 fps gepinnt · ~1 Hz Anwendung); „Watch als Anzeige ausgeliefert" → „kompiliert, nicht eingebettet"; Kohärenz = BLE-only bei Ruhepuls unter DDSP-Tabelle und TEMPO-INVARIANT |
| 5 | `output-sync-2` | `Sync/ArtNetSender.swift`, `Studio/PatchbayView.swift`, `docs/artnet-sacn-from-a-phone.html` | bestehende ArtNet-Tests grün; Default-Host-Anspruch anpassen | Default auf Unicast (leerer Host = Platzhalter „node IP"), `stateUpdateHandler` → `lastError`; die Entitlement-Route bleibt Founder-Entscheidung (Council Schritt 0 beantragt sie ohnehin) |
| 6 | `bio-pipeline-1` | `Bio/PolarH10BioPublisher.swift`, ein Parser-Test in `Tests/EchoelmusicTests` | Contact-Bits `0x06`, `lastNotificationAt`-Gate ≤ 3 s | dieselbe Lehre, die der Kamera-Pfad schon bezahlt hat („FROZEN pulse with a FRESH timestamp") |
| 7 | `bio-pipeline-2` | `Bio/HealthKitBioPublisher.swift`, `Tests/EchoelmusicTests/HealthKitBioPublisherTests.swift` | 45-Minuten-Probe wird NICHT veröffentlicht; die 180-s-Probe bleibt | `maxMeasurementAge` als benannte Konstante mit Herkunft |
| 8 | `sequencer-core-1` | `Studio/EchoelStudioView.swift` (eine Zeile), `Tests/CISmoke/TempoInvariantTests.swift` | Anspruch: `source: lockBPM ? .user : .flowServo` | T1 sagt sonst im Log den Servo für eine Nutzer-Entscheidung |
| 9 | `output-sync-3` | `Sync/SACNSender.swift`, `Sync/ArtNetSender.swift`, `Tests/EchoelmusicTests/SACNSenderTests.swift` | Keep-alive ≥ 0,8 s, `Stream_Terminated` (0x40) ×3 in `stop()` | Golden-Bytes bleiben identisch, weil `options:` Default 0 |
| 10 | `docs-claims-2` + `docs-claims-3` | `docs/index.html`, `docs/overview.html`, `fastlane/metadata/*/description.txt` | `WebsitePagesAreFindableAndHonestTests` grün; Store-Kopie → Council (nutzersichtbar) | die zwei billigsten Unter-Behauptungen: spielbares Visual, externer Bildschirm |

**Danach, in dieser Reihenfolge:** `studio-ui-1` (In-File-Notiz zu `showVisual`), `ship-path-4`
(PrivacyInfo-Wächter — neuer Test, kein gated File), `ship-path-5` (Package.swift-Kommentar), `tests-guards-3`
(EIN End-to-End-Render-Wächter `TheDDSPRenderIsDeterministicAndBoundedTests`), `tests-guards-2` (Ratchet auf
Anker-Skips — der Widerleger hat die Migration als #806-Sackgasse markiert, der Ratchet ist die kleine Form),
`sequencer-core-2` (Ideal-Deadline im Step-Clock; NEEDS-FOUNDER-VERIFY gegen den Click), `output-sync-7`
(Integrations-Seite — deckt sich mit Council-Schritt 2 und Marketing-Aktion 2), dann die niedrigen.

**Founder-gated (berichten, nicht editieren):**
- `ship-path-2` — Auto-Merge wartet auf kein Gate (#683), Archiv-Job läuft ohne Tests und hängt nicht am
  Compile-Check (`.github/workflows/**`).
- `tests-guards-8` — 116/103/0 offene Geräte-Bitten; die zwei offenen Ship-Gate-Checks (Klang, Stabilität) sind
  sensorisch. Einkaufszettel: `python3 scripts/founder-verify.py`.
- `sequencer-core-6` — Tempo-Automation umgeht das BPM-Schloss (Verhaltensfrage, T1/T2-Nachbar).
- `sequencer-core-7` — `ProGate.proFeatures` listet `.auv3Plugin`/`.videoFXCatalog` (Umwidmung ist v1.1-Entscheidung).
- `ship-path-7` — `NSBonjourServices` neun Typen, drei mit Code (`Info.plist`).
- `ship-path-8` — Xcode-16.2-Pin in einem Workflow; `MARKETING_VERSION`-Fallback 94 Versionen zurück (`project.yml`).
- `studio-ui-4`/`studio-ui-6` (widerlegt als Befund, aber als FRAGE offen): Querformat/Size-Class und die
  Chip-Beschriftung „Field" — Founder-Geschmack, kein Defekt.

## 5. Was dieser Audit NICHT geprüft hat

- **Klang, Gefühl, Gerät.** Kein Prüfer hat gehört oder ein iPhone berührt; jede „hörbar"-Aussage ist Ableitung.
  Die zwei offenen Ship-Gate-Checks bleiben Founder-Ohr und Founder-Gerät.
- **Kompilation.** Keine Swift-Toolchain in dieser Sitzung; jeder Fix-Vorschlag ist per Transkription benotet
  (`Tests/CISmoke/CLAUDE.md` §0), und die Gates werden erst nach dem Push gelesen.
- **Apple-Seiten hinter dem Egress.** Wo ein Prüfer eine Apple-Doku nicht laden konnte, steht es im Befund
  (`output-sync-2`: die Entitlement-Hälfte wurde vom zweiten Widerleger nachgeladen).
- **Die neun widerlegten Befunde** sind nicht „falsch gemessen", sondern falsch geschlossen — ihre Messungen
  reproduzieren fast alle; der Abschnitt „Widerlegt" hält den Grund fest, damit die nächste Sitzung sie nicht
  erneut findet.
- **#1207/#1207b** (auf `main`, nach dem Messpunkt): nicht geprüft; sie liegen in `SynthPatch`/`EchoelLFO`,
  die kein Befund berührt.
