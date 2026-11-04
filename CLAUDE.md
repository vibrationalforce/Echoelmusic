# CLAUDE.md — die Karte von Echoelmusic

Diese Datei lädt in **jeder** Sitzung und ist deshalb eine KARTE: wer was ist, wo was liegt, welche
Gesetze überall gelten, wohin man für den Rest geht. Das Gesetz der früheren App steht seit 2026-11-01
**wörtlich** in `Sources/CLAUDE.md` und lädt beim Arbeiten dort. Größe und Decke beider Dateien:
`python3 scripts/doctor.py --section D`, gepinnt von `TheLawFileStaysUnderItsCeilingTests`.

## Identität — drei Namen, drei Dinge

- **Echoel** — die Marke.
- **Echoel Studio** — die App. TestFlight trägt sie seit 2026-10-18/19 (Version 11.0.0); Code und
  Gesetz: `EchoelStudio/` und `EchoelStudio/CLAUDE.md`. Bundles `com.echoelmusic.app` plus die eine
  AUv3-Erweiterung `com.echoelmusic.app.auv3` (gemessen in `EchoelStudio/project.yml`).
- **Echoelmusic** — das Projekt: dieses Repo, die Domain, die Website `docs/`.
- **Die frühere App** (10.x, das Bio-Instrument) — `Sources/`, `Tests/`, `Package.swift`, das
  root-`project.yml`; eingefroren, seit Studio TestFlight trägt. Ihr Gesetz: `Sources/CLAUDE.md`.

Repository: https://github.com/vibrationalforce/Echoelmusic
Developer: Echoel (Michael Terbuyken) @ Studio Hamburg
App Apple ID: 6757957358 · SKU: Simsalabimbam · Team ID: via `APPLE_TEAM_ID` secret
Bundle prefix: `com.echoelmusic` · App Group: `group.com.echoelmusic`

**Canonical identity map:** `docs/dev/APP_STORE_CONNECT.md` · **Cross-platform plan:** `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` §10

## Wo was liegt

| Pfad | Was | Gesetz / Einstieg |
|---|---|---|
| `EchoelStudio/` | die App: `Core/` · `DSP/` · `Engine/` · `App/` · `Plugins/` | `EchoelStudio/CLAUDE.md` · Bauplan `docs/dev/NEUPLANUNG_2026-10-18.md` · Song-Format `docs/FORMAT.md` |
| `Sources/` · `Tests/` · `Package.swift` · `project.yml` | die frühere App; `Tests/CISmoke` ist das blockierende Wächter-Bündel | `Sources/CLAUDE.md` · `Tests/CISmoke/CLAUDE.md` |
| `docs/` | Website (GitHub Pages); `docs/dev/` · `adr/` · `research/` intern, unveröffentlicht | `docs/CLAUDE.md` |
| `ContentPipeline/` · `fastlane/` | Content und Store-Text; `ContentPipeline/CLAIMS.md` = was nach außen gesagt werden darf | `ContentPipeline/README.md` |
| `memory/` | kuratiertes Gedächtnis, der Hook liest Scheiben; `memory/LEDGER_COUNTS.md` = Provenienz, nie beim Start lesen | DEVELOPMENT WORKFLOW unten |
| `scratchpads/` | Rohes: Sitzungsprotokoll, Pläne, Board, Sackgassen | DEVELOPMENT WORKFLOW unten |
| `scripts/` | die Messinstrumente | `scripts/INDEX.md` |
| `.claude/` | `rules/` (immer geladen), `skills/`, `agents/`, `hooks/` | `.claude/rules/context.md` |
| `decisions.csv` · `inspiration.csv` | Entscheidungs- und Inspirations-Ledger, maschinenlesbar | Decision Logging unten |

## Wohin die alten Abschnitte gezogen sind (W-MAP, 2026-11-01)

Ein Zeiger auf einen Abschnitt „von `CLAUDE.md`" — in Code, Wächtern, Skripten, Dokumenten — löst in einem Schritt auf:

| Alter Abschnitt | Heute |
|---|---|
| IDENTITY (Tagline, Built for, Capabilities, Streichliste) · CURRENT STATE · BRAND (Fassung von 10.x) · ARCHITECTURE · EchoelStudioView · TECH STACK mit Plattform-Leiter · REPO STRUCTURE · BIO-SIGNAL DSP · DDSP Bio-Mappings · PERFORMANCE · TEMPO INVARIANT · RALPH WIGGUM LAMBDA PROTOCOL · "CLEAR SOFTWARE" CHECKLIST · SESSION START (Bash) · CODE STYLE · Logger Usage · API Gotchas · KEY TESTS · die Alt-App-Zeilen aus CI/CD · GitHub API Access · OSC (EchoelSync) · PLATFORM NOTES · 4-Phase Workflow · Parallel Agent Strategy · Code Review Checklist · Parameter rows (`EchoelValueField`) | `Sources/CLAUDE.md` — wörtlich, gleiche Überschriften, gleiche Reihenfolge |
| CRITICAL BUILD ERROR PATTERNS · Language-level notes | `.claude/rules/swift-audio.md` (gelten für beide Apps) |
| Zeilen der universellen Abschnitte, die hier ersetzt wurden | `memory/LEDGER_COUNTS.md` §AQ |

## Produktgesetz — vor jeder Scope-Entscheidung

- **⭐ PRODUCT LAW (canonical since 2026-09-24 — read `docs/dev/FOUNDER_PRODUCT_LAW.md` before ANY scope decision; entry + timeline = `docs/dev/ECHOEL_VISION_2026-10-19.md`; Studio order = NEUPLANUNG §5).** Echoelmusic is a full professional **DMMW** (distributed multidimensional multimedia workstation) — audio, MIDI/MPE, instruments, FX, recording, arrangement, mixing, mastering, automation, video, visual, light, spatial/XR, streaming, collaboration, AI. *Own the complete creative workflow, integrate the complete professional ecosystem* — never rebuild specialist infrastructure (codecs, Dante, NDI, CDNs, plugin SDKs).
  **CURRENT PRODUCT LAW SUPERSEDES HISTORICAL PRODUCT CUTS — a historical deletion revokes an IMPLEMENTATION, not the capability.** Every ⛔ „gestrichen / CUT / reines Instrument" in this file and in `decisions.csv` is PHASE HISTORY: its ENGINEERING warning stays law (#1302 input graph, #299 refcount, black-screen chain, hot-state), its SCOPE verdict does not. Recovery ports the proven core into today's owners — never copy a subsystem back; what existed, whether it worked and its recovery class: `docs/dev/HISTORY_ARCHIVE.md`. ⚠️ **Scope is not a claim:** store, website and content still claim only what ships (`docs/dev/FEATURE_STATUS.md`, `ContentPipeline/CLAIMS.md`).
- **§4b — keine Waffen, keine Überwachung, kein Targeting** (Founder 2026-11-01): nie gebaut, nie
  integriert, nie als Beitrag angenommen; einmal in `decisions.csv` verbucht und nicht wieder geöffnet.
- **§4c — nicht beim Steuern:** niemand spielt Echoelmusic beim Fahren, Steuern oder Bedienen einer
  Maschine, auch nicht mit Autopilot; hier entsteht kein Navigations-, Sicherheits- oder Browser-Projekt.
- **Fokus seit 2026-10-15 (§1):** professionelle Medienproduktion. Biofeedback ist eine optionale
  Modulationsquelle, nicht die Identität.

## Gesetze, die überall gelten

- **Nach außen nur, was ausgeliefert ist.** Store-Text, Website, Presse und Content behaupten nur, was
  `ContentPipeline/CLAIMS.md` trägt (Studio-Abschnitt); eine falsche Store-Behauptung ist eine
  2.3-Ablehnung. Scope ist keine Behauptung.
- **Sprache.** Nie Wellness, Meditation, Entspannung, Schlaf, Fokus, Therapie, Medizin, Heilfrequenzen,
  Solfeggio, Chakren, Binaural oder 40 Hz (CLAIMS §2, Produktgesetz §4). „KI/AI" nur, wo ein Modell
  läuft; „MPE" nur als MPE-Ausgang; „pitch correction", nie „Autotune" (eine Marke); „Eeolee" steht in
  keinem Echoelmusic-Text (§4c).
NEVER use "BLAB", "Vibrational Force", legacy bio-wellness/soundscape branding, or esoteric terminology ("healing frequencies", chakras, Solfeggio) in user-facing copy.
- **Founder-gegatet — berichten, nicht editieren:** `.github/workflows/**`, `project.yml` (beide),
  `Resources/iOS/Info.plist`, `.claude/settings.json`, `.mcp.json` — Hook
  `.claude/hooks/protect-founder-gated.py`, `.claude/rules/context.md` §3. `.deploy/release` ist frei.
- **Messen, nicht zitieren** (`.claude/rules/context.md` §2): eine Zahl ist ein Datum, der Befehl
  steht daneben. **Ehrlich verifizieren** (`.claude/rules/engineering.md`): grün kompiliert ist nicht
  am Gerät geprüft.
- **Build-Rhythmus** (die Founder-Regeln, seit 2026-11-01 auch für jeden Agenten, `decisions.csv`):
  seit 2026-11-04 (Founder: „immer wieder TestFlight deploy“) ein Build, sobald ein grüner, stimmiger Stapel landet — davor höchstens EIN TestFlight-Build pro Woche · höchstens drei gebaute Scheiben warten auf ein
  Geräte-Urteil (WIP 3) · genau fünf Geräte-Fragen je Build (`docs/dev/FOUNDER_INBOX.md`, Regeln 1–4;
  Skill `studio-release`). Außer der Reihe nur ein Absturzfix für den Build, den der Founder gerade
  testet, und ein grüner Knackfix — Knacken ist ein Blocker wie ein Absturz.
- **Eine Frage an den Founder genau einmal**, in `docs/dev/FOUNDER_INBOX.md`, und erst nach der
  Messung, die sie erübrigen könnte (`.claude/rules/context.md` §6).
- **Tempo:** roher Puls erreicht die Uhr nie direkt — das gilt für beide Apps. Wortlaut T1·T2·T3 und
  Wächter der früheren App: `Sources/CLAUDE.md` „TEMPO INVARIANT"; in Studio
  `EchoelStudio/Core/Sources/EchoelCore/FlowTempo.swift`, getestet in
  `EchoelStudio/Core/Tests/EchoelCoreTests/FlowTempoTests.swift`.

## Arbeitsweise

- **Branch:** run `git branch --show-current` — the literal used to be pinned here and was wrong for weeks. Prior cycles auto-merged to `main`.
- **Mode:** RALPH WIGGUM LAMBDA — one feature/fix per cycle, build → test → ship → loop

ONE issue per cycle. No batching. Build fails = ONLY priority.
No features during fix cycles. Convergence only.
Priority: Build errors → Test failures → Crash code → Task → Cleanup

- **Keine Toolchain in der Cloud-Sitzung — die CI ist der Compiler.** Studio: Lauf `Echoel Studio`
  (`studio.yml`), Job-Schritte lesen (`EchoelStudio/CLAUDE.md` „Verifying"). Frühere App und Wächter:
  `Xcode Compile Check` plus CI/CD-Schritt `Build for Testing`; Testergebnisse mit
  `python3 scripts/gh-test-verdict.py`, WINDOW-Zeile beachten (`Tests/CISmoke/CLAUDE.md` §0 und §5).

- **TESTFLIGHT = ECHOEL STUDIO (since 2026-10-18/19, builds 10004+).** Ship by changing `EchoelStudio/RELEASE` and pushing — ANY change uploads. `studio-testflight.yml` waits for the `Echoel Studio` run on that commit, signs in to App Store Connect before signing, uploads, and waits for Apple's processing (VALID/INVALID). The earlier app's `testflight.yml` uploads only with `legacy_upload=LEGACY` (2026-10-20); `scripts/check-testflight.sh` and `/testflight-deploy` dispatch THAT workflow. Guard `TheStudioUploadWaitsForItsGateTests`. ⛔ The 2026-05-30 "PIPELINE GREEN" line that stood here: `memory/LEDGER_COUNTS.md` §AP.

---

## PLATFORM CONSTRAINTS

- Apple Watch HR: ~4-5 sec latency — NO beat-sync!
- RMSSD: Self-calculate (Apple only gives SDNN)
- Bluetooth Audio: 150-250ms latency
- Flash animations: Max 3 Hz (epilepsy W3C WCAG)

---

## SAFETY WARNINGS (must be in app)

- Brainwave Entrainment: NOT while operating vehicles
- NOT under influence of alcohol/drugs
- Therapeutic use: coordinate medications with provider
- Max 3 Hz visual flash rate
- Data for self-observation, NOT medical diagnosis

---

## CI/CD

### Active Workflows (.github/workflows/)

| Workflow | Purpose |
|----------|---------|
| `testflight.yml` | TestFlight der früheren App (ID: 225043686) — lädt seit 2026-10-20 nur mit `legacy_upload=LEGACY` hoch |
| `ci.yml` | Main CI (SwiftPM build, test, lint) |
| `xcode-compile-check.yml` | XcodeGen + `xcodebuild` compile gate (catches Xcode/AUv3-only errors) |
| `quick-test.yml` | Fast test suite |
| `pr-check.yml` | PR validation |
| `auto-merge-claude.yml` | **Entscheidet, was `main` erreicht** — siehe den Absatz direkt unter dieser Tabelle |
| `studio.yml` · `studio-testflight.yml` · `studio-linux.yml` | **Echoel Studio**: Tests und Builds (Gate des Merges seit 2026-10-20) · TestFlight beim Bump von `EchoelStudio/RELEASE` · Linux-Portabilität von Core/DSP |

⭐ **DER MERGE NACH `main` WARTET SEIT #1405 AUF ZWEI GATES** (Founder 2026-09-21: „auto-merge-claude.yml du hast das alles unter Kontrolle und machste das klar"). Vier Monate lang tat er es nicht, und diese Tabelle nannte den entscheidenden Workflow gar nicht erst (#683) — genau die Register-Lücke, die diese Datei an anderer Stelle „teurer als eine falsche Zahl" nennt, weil sie nie als Frage auftaucht.

**Was das Gate liest, und warum es ein POLL ist statt eines `needs:` — die Unterscheidung entscheidet jede künftige Änderung daran.** `Xcode Compile Check` wird über seine **Conclusion** gelesen (er baut `Sources/` allein, und seine Conclusion ist ehrlich). Die CI/CD-Pipeline wird über **einen SCHRITT** gelesen, `Build for Testing` — ihre eigene Conclusion ist wegen #396 auf JEDEM Push `failure`, trägt also null Information, und ein `needs:` darauf blockierte jeden Merge für immer. Eine Schritt-Conclusion ist aus `needs:` nicht erreichbar; sie muss abgefragt werden. **Abwesenheit ist Ablehnung, nie Zustimmung:** `never-ran` und `timeout` merged nicht.

⭐ **SEIT 2026-10-20 IST ECHOEL STUDIO EIN EIGENES GATE-GEBIET** (Founder: „Die Echoelmusic CI übernehmen“). `EchoelStudio/**` startet den Merge, und ein Merge, der Studio-Code bringt, wartet auf `Echoel Studio` (Conclusion). Vorher erreichte eine reine Studio-Änderung `main` nie, und Studio-Code lief durch zwei Alt-App-Gates, die ihn nie bauen. Ein nötiges Gate ohne Lauf auf dem Commit wird EINMAL per Dispatch gestartet; ist der Zweig inzwischen weiter, endet der Job als `superseded`, ohne zu mergen. Wächter-Anspruch 8.

⚠️ **Die EINE Ausnahme, und sie ist eng:** berührt der Merge weder `Sources/` noch `Tests/` noch `Package.swift` noch `project.yml` noch `EchoelStudio/`, läuft KEIN Gate — die Gate-Workflows haben genau diese Pfadfilter plus ihre eigene Datei. Dann gibt es nichts zu prüfen und der Merge geht durch. Ohne diese Ausnahme wartete ausgerechnet ein Commit, der CI repariert, auf ein Gate, das nie startet.


Wächter: `Tests/CISmoke/TheAutoMergeWaitsForTheGatesTests.swift`. ⛔ Die Provenienz — die vier Monate ohne Gate, die zwei gemessenen Fenster (`f61be63` zehn Minuten, `edc37a4a5` neun) und die zurückgenommene Fassung dieses Absatzes — liegt in `memory/LEDGER_COUNTS.md` §AG.

⛔ **UND DER ZWILLING DAZU (#697/#698/#699): ein Commit, der NUR `CLAUDE.md`, `memory/**` oder `scratchpads/**` anfasst, löst KEINEN eigenen Merge aus.** Die Filter stehen in `ContentPipeline/README.md` (#252). Er fährt als **PASSAGIER** auf dem nächsten Code-Commit mit (der Merge nimmt `${{ github.sha }}` samt Vorgeschichte); endet ein Zweig auf ihm, bleibt die Drift ohne Signal. Ein wartender Gesetzes-Commit **blockiert den Docs-Merge** (`auto-merge-docs.yml` setzt dann `docs_only=false` und endet trotzdem grün). Wächter: `Tests/CISmoke/TheLawFileNeverReachesMainByItselfTests.swift`. Die #697-Über-Behauptung („NIE durch Automatik“) samt Messung: `memory/LEDGER_COUNTS.md` §AO.


⚠️ **`Sources/CLAUDE.md` liegt unter `Sources/**`:** anders als dieses File löst ein Commit, der nur
das Gesetz der früheren App ändert, den Merge und beide Alt-App-Gates aus (Pfadfilter von
`auto-merge-claude.yml`, `xcode-compile-check.yml` und `ci.yml`).

---

## DEVELOPMENT WORKFLOW

### Persistent Memory (memory/)

The `memory/` directory is **durable knowledge** that persists across all sessions:

| File | Purpose |
|------|---------|
| `decisions.md` | Architectural and strategic decisions with rationale and review dates |
| `people.md` | Key contributors, collaborators, contacts |
| `preferences.md` | User preferences for workflow, communication, tooling |
| `user.md` | User profile, project vision, working style |
| `LEDGER_COUNTS.md` | **Zähl-Ketten (Provenienz).** ~580 KB. **NICHT beim Sitzungsstart lesen** — nur öffnen, wenn eine Zahl nachzuführen ist (#538) |

**SESSION START (mandatory):**
1. Restore context from `memory/` — **but not by reading the directory whole.** The
   SessionStart hook already `cat`s the small files (`people` · `user` · `vision` ·
   `project_knowledge` · `preferences`) and prints SLICES of the two big ones
   (`decisions.md` tail-400, `inspiration_intake.md` head-60 + tail-120), each with the
   command that reads the rest. ⛔ **„Read ALL files in `memory/`" stand hier und war
   die Anweisung, die sich selbst widerlegt:** der Hook schneidet seit #533 zwei Dateien,
   weil sie zusammen 191 875 B kosteten — eine Prosa-Zeile, die „lies alles" sagt, hebt
   genau die Messung auf, für die der Schnitt existiert. Seit #538 liegt zusätzlich
   `LEDGER_COUNTS.md` dort, das allein ~580 KB wiegt; wer die Zeile wörtlich befolgt,
   verbrennt mehr Budget als das gesamte Gesetz dieser Datei ausmacht.
2. Read `scratchpads/SESSION_LOG.md` for recent session history
3. Read `memory/decisions.md` for any decisions due for review

**SESSION END (mandatory):**
1. Update `memory/` files with any new discoveries, decisions, or preferences learned during the session
2. Log new decisions to `memory/decisions.md` AND `decisions.csv` (see Decision Logging below)
3. Update `scratchpads/SESSION_LOG.md` with session summary

### Decision Logging (decisions.csv)

Machine-readable decision log at repo root. Format:
```
date,decision,reasoning,expected_outcome,review_date,status
```

- Log every architectural/strategic decision the user describes
- Review dates default to 30 days from decision date
- Run `./review.sh` to surface decisions due for review; `./review.sh --flag` schreibt `REVIEW_DUE` in die Datei zurück
- ⛔ **NICHTS FLAGGT AUTOMATISCH — hier stand ein täglicher Cron als Tatsache.** #510 hat genau diese Behauptung am 2026-08-08 in `.claude/routines/05-decision-review.md` zurückgenommen („unwired as automation") und **diese** Datei stehen lassen, die jede Sitzung ZUERST liest — die #456-Form: Prosa zieht in JEDEM Zuhause mit, nicht nur dort, wo man gerade schreibt, und 16 Tage lang gewann das immer-geladene Zuhause. Gemessen an der STATUS-SPALTE, weil ein Wort-Zähler hier von der Prosa über sich selbst widerlegt wird (⛔ `git log -S REVIEW_DUE` stand hier als „leer" und liefert seit #805/#815 zwei Treffer — beide Prosa, null geflaggte Zeilen; §W): `python3 -c "import csv;print(sum(1 for r in csv.reader(open('decisions.csv')) if len(r)==6 and r[5].strip()=='REVIEW_DUE'))"` → **0**. Und **kein einziger Workflow trägt überhaupt einen `schedule:`-Trigger**; `check-decisions.sh` ist eine crontab-Zeile, die ein Mensch installiert. Die Folge ist nicht kosmetisch: der Rückstand — Zahl mit `./review.sh | grep -c '^REVIEW DUE'` messen, nicht hier ablesen (#803) — sieht betreut aus und ist es nicht. Wächter: `TheDecisionLogIsMachineReadableTests`, Anspruch 7.

### Long-Term Memory (scratchpads/)

The `scratchpads/` directory is session-specific logs and plans:

| File | Purpose |
|------|---------|
| `SESSION_LOG.md` | **Read first — CAPPED**: newest entries are at the END; the hook prints `sed -n '1,80p'`; read `grep -n '^## ' scratchpads/SESSION_LOG.md \| tail -20` + `tail -200`, never the whole ~1.8 MB |
| `HARNESS_LEDGER.md` | **The idea-maze** — proven DEAD-ENDS (don't retry), reliable PLAYBOOKS, shipped leaderboard |
| `ARCHITECTURE_AUDIT_*.md` | Data flow diagrams, env object chains, init sequence |
| `PLAN_*.md` | Feature/fix plans before implementation |

**Start every session** by reading `memory/` first (the hook's slices), then the END of
`scratchpads/SESSION_LOG.md`, then the DEAD-ENDS table of `scratchpads/HARNESS_LEDGER.md`
(~300 KB — index it with `grep -n '^## ' scratchpads/HARNESS_LEDGER.md`, do not read it whole).

**Harness discipline (long-running-agent effectiveness).** Before trying any
non-trivial approach, scan `HARNESS_LEDGER.md` DEAD-ENDS — a past (context-compacted)
cycle may already have proven it wrong; take the "do this instead". After a cycle,
append ONE row for any real dead-end hit or reliable playbook found, so the loop
climbs instead of circling. Check CI gate status compactly with
`python3 scripts/gh-run-status.py <saved-tool-result.json>` (parses the overflowing
`mcp__github__actions_*` dump into `sha status conclusion run_id title`).

---

## UI DESIGN CONSTRAINTS (Uncodixfy)

When generating SwiftUI views, follow clean design principles. Avoid AI-default patterns.

**Reference aesthetic:** Linear, Raycast, Stripe, GitHub — functional, minimal, precise.

**BANNED patterns:**
- Border radii > 16px (no pill shapes, no 20-32px radii)
- Glassmorphism, frosted panels, blur hazes, soft gradients
- Decorative KPI card grids, fake charts, hero sections inside dashboards
- "Eyebrow" labels (tiny uppercase with letter-spacing above headings)
- Glow effects, neon accents, shadow layers > 8px blur
- Transform/scale animations on hover/tap (use opacity/color only)
- Nested panel types (card-in-card, panel-in-panel)
- Decorative copy ("Live Pulse", "Neural Sync", "Quantum Flow")
- Floating cards with large shadows

**REQUIRED patterns:**
- Solid fills or borders on buttons, 8-12px radius max
- Subtle borders (1px, muted color), max 8px shadow blur
- Sidebars: 240-260px fixed, solid background, 1px border
- Forms: labels above inputs, no floating labels, simple focus ring
- Tables: left-aligned text, subtle row hover, clean grid
- Color: use existing palette, dark muted backgrounds, avoid neon
- Transitions: 100-200ms, opacity/color only
- Bio-signal displays: legible numbers first, visualization second
- Flash rate: max 3 Hz (W3C WCAG epilepsy compliance)
- **Zahlen-Parameter:** EIN Wertfeld mit eigener Zahlentastatur, kein rohes `Slider`/`Stepper`;
  Auswahlen mit Namen bleiben Picker. Studio: `EchoelStudio/App/Design/ParameterControls.swift`
  und `EchoelStudio/App/Design/NumberPad.swift`; frühere App: `EchoelValueField` (`Sources/CLAUDE.md`).

**SCIENCE-FIRST display:**
- Real biometric data only — no decorative visualizations
- HR, HRV, coherence: large legible numbers, small trend sparklines
- No "control room cosplay" or "premium dashboard" aesthetic
- Every visual element must reflect actual data or serve a control function

---

## DO NOT

- Restructure project without approval
- Add dependencies without asking
- Create new targets or top-level dirs
- Modify Info.plist / CI config without asking
- Use force unwrap, `print()`, `ObservableObject`, `UIScreen.main`
- Simplify Rausch DSP algorithms
- Allocate memory on audio thread
- Batch unrelated fixes
- Add features during fix cycles
- Use esoteric terminology

---

## THE COUNCIL (always-on, optimized)

Before any **significant or hard-to-reverse** decision — architecture, scope
changes, >1 file, audio-thread / protected Rausch triad, user-facing copy,
ambiguous founder asks, or deploy/delete/publish — **convene The Council**
(`.claude/skills/the-council/SKILL.md`). Fixed seats (Architect · DSP Purist ·
Vision-Keeper · Shipper · Skeptic · User-Advocate) each give a one-line position
+ sharpest concern; dissent is surfaced, not smoothed; synthesize ONE cheapest
next step + a gate (proceed / mitigate / hold-for-founder). **Skip trivial
reversible actions** — convening on trivia is the failure mode. Composes with
`vision-gate` and the Ralph Wiggum loop; never overrides explicit founder
instructions or the hard rules above.

**Marketing:** to market Echoel (App Store/ASO, website `docs/`, launch, pricing,
social, PR, SEO), use the `echoel-marketing` skill — the Echoel-tuned front door
over the vendored MIT pack at `.claude/skills/marketing/` (Corey Haines, 45
skills). It enforces brand guardrails (no wellness/esoteric/overclaim, claim only
what ships) and is **PIPELINE only — never shipped in-app, never touches `Sources/`**.

**Short-form video content** (TikTok/Reels/Shorts, founder 2026-07-30) lives in
`ContentPipeline/` — same PIPELINE-only rule. **Read `ContentPipeline/CLAIMS.md`
BEFORE writing any script, caption or hashtag set**; it is the one list of what is
true today and what is struck, with the reason. It exists because #158/#192 spent two
whole cycles removing ONE false claim (AUv3) from the website and #184 removed twelve
from the App Store text, where a false claim is a 2.3 rejection. A model asked for
"bio-music app content" will reliably invent an AUv3 plugin and a meditation audience
— Echoel is neither. Note two structural facts recorded in `ContentPipeline/README.md`:
XcodeGen needs no exclusion (targets list explicit source paths, so a new top-level
directory is never scanned), and `ContentPipeline/**` is in NO auto-merge path filter,
so commits touching only it never reach `main` by automation (#252).

## ACTIVATION

```
ECHOEL MODE ACTIVE
Branch: [branch]  Build: [number]
Priority: [errors | failures | task]
Mode: Ralph Wiggum Lambda — Fix → Build → Test → Ship → Loop
```

No intro. Audit → Fix → Build → Loop.
