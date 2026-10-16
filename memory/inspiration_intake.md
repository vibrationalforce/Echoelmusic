# Echoel — Inspiration Intake (the Knowledge Funnel)

**How we integrate the repo's own history + external inspiration (deep research,
shared screenshots, repo links, MCP/agent/tool ecosystems) WITHOUT diluting the
optimized Echoel vision.**

The rule: **the vision is the filter, not the inbox.** Nothing is adopted because
it is impressive. Everything is scored against `memory/vision.md` and lands in a
tier. We record *what we evaluated and why we did/didn't adopt it* — so we never
re-litigate, and we never drift. The self-applying form lives in
`.claude/skills/vision-gate/SKILL.md`; the machine-readable ledger is
`inspiration.csv` (repo root, mirrors `decisions.csv`).

---

## The funnel

```
external input (repo history lesson · deep research · screenshot · repo link · MCP/agent/tool)
        │
        ▼
[ VISION GATE ]  ── score against memory/vision.md + the 8 founder principles
        │
        ├─ ADOPT → PRODUCT    fits a LIVE/ROADMAP pillar · iOS-native-feasible · on-brand · no realtime risk
        ├─ ADOPT → PIPELINE   helps us BUILD/TEST/MARKET (dev tooling, agents, CI) — never in-app
        ├─ WATCH              promising but not now → park with a review date
        └─ REJECT             off-vision / overclaim / redundant → log the reason, close it
        │
        ▼
log to inspiration.csv (+ this ledger) · if PRODUCT and material → also decisions.csv
```

## The gate — to be ADOPT→PRODUCT it must pass ALL

1. **Serves a dimension** — Body / Sound / Space / Light / Vibration / Data
   (or an explicit North-Star tier, labeled as concept, never shipped copy).
2. **iOS-native feasible on iPhone** — or honestly tiered ROADMAP / NORTH STAR.
3. **On-brand** — no wellness/esoteric, no quantum/super-AI overclaim; open-standard
   preferred; accessibility-first; the code stays the truth.
4. **Realtime-safe** — does not threaten audio-thread sanctity or the single main
   beat clock; heavy media goes on its own GPU/capture queue reading the bus snapshot.

If it fails #1 it's usually WATCH or REJECT. If it helps us ship but isn't a
feature, it's PIPELINE. When unsure: WATCH with a review date beats premature adoption.

## How the repo "stays smart"

- **History → durable lessons**, not re-discovery. The crash crucible, the silence
  saga, the breadth-first oscillation — distilled in `memory/vision.md` principles and
  `SESSION_LOG.md`. Past mistakes are encoded as rules, so we don't repeat them.
- **External inspo → ledger entries**, not scope creep. Every carousel/repo/research
  drop gets one row with a verdict. Re-seeing it later = look up the row, not re-debate.
- **Adoption → one cycle.** A PRODUCT adoption enters the Ralph loop as exactly one
  feature/cycle, built green, shipped, logged. No batching imported ideas.

---

## Ledger (running; newest first)

### 2026-09-04 — Anthropic-Skill-Folie „Algorithmic Art" (FlowField), Founder-Frage: „was interessantes bei?"

**Gemessen zuerst, dann bewertet.** Echoels Visual heute: `MetalBioView` mit DREI Mustern
(Rings · Cymatics · Mandala), bio-getrieben über `BioVisualParams` (pulseHz · hue · complexity ·
spread · intensity), im `visualPanel` von Hand nachstellbar mit GENAU DREI Feldern (Detail ·
Energy · Intensity). Kein Seed, kein Standbild-Export, keine FPS-Anzeige.

**ADOPT-PRODUCT (1, war 2 — siehe die Rücknahme darunter):**
· **Standbild-Export.** `VisualRecorder` liefert heute nur mp4. Ein einzelnes Bild ist das
  billigste und meistgebrauchte Artefakt (Cover, Post). Größe gemessen, nicht geschätzt:
  `capture(from source: MTLTexture, in commandBuffer:, device:)` blittet den Frame BEREITS in
  einen BGRA-`CVPixelBuffer` — ein Standbild ist derselbe Puffer, einmal statt pro Frame.

⛔ **RÜCKNAHME AM SELBEN TAG, EINE STUNDE SPÄTER: „Seed + Randomize fürs Visual" war
ADOPT-PRODUCT und ist WATCH.** Die Begründung lautete „die MUSIK ist seed-reproduzierbar, das
VISUAL nicht — man bekommt denselben Take zurück, aber nicht denselben Look". **Gemessen:** das
Visual hat GAR KEINEN Zufall. `grep -cE "\.random\(|SystemRandomNumberGenerator|SplitMix|shuffled\("`
liefert **0** für `MetalBioView.swift` UND `BioVisualParams.swift`, und `echoelHash` ist ein
POSITIONS-Hash (Pixel bzw. Zelle rein, deterministisch raus) — kein Zufallsgenerator. Es gibt
also nichts zu pinnen. Ein Seed wäre ein **Variations-Regler** (gleicher Körper, andere Textur —
genau die „infinite variations" der Folie), nicht die Reparatur einer Lücke. Wert fällt damit von
„schließt eine Asymmetrie" auf „nett". ⚠️ **Und das ist der #984c-Fehler in einer anderen Gattung:**
dort stimmte die Rechnung und die Beschriftung log; hier klang die Begründung plausibel und war
schlicht ungemessen. Beide Male hätte EIN `grep` es vor dem Aufschreiben entschieden.

**WATCH (1):** Info-Zeile (FPS + aktive Qualitätsstufe). `AdaptiveQuality` senkt bei Hitze/Akku
die Detailstufe und der Nutzer erfährt nie warum — ehrliche Diagnose, keine Deko. ⚠️ Muss ein
Leaf-View sein (10-Hz-Read-Gesetz, 10.76.50), sonst reißt es offene Menüs ab. Nach dem Ohr zu 438/439.

**REJECT (1), zwei harte Gründe:** die Regler-WAND als Hauptoberfläche (Density · Turbulence ·
Flow Strength · Scale · Complexity · Contrast · Brightness) ist das Gegenteil von „Dein Körper
spielt es" und fällt unter das Uncodixfy-Verbot „control room cosplay" — das Tools-Grid wurde
2026-07-02 aus genau diesem Grund entfernt. Und **NFT** (auf der Folie ausdrücklich als Zielgruppe
genannt) ist Marken-Rote-Linie, nie in nutzersichtbarer Kopie.

**Nicht übernommen, ohne dass es ein REJECT wäre:** die Flow-Field-Engine selbst. Ein VIERTES
Muster wäre erlaubt (ein Muster ist ein Muster), eine zweite Visual-Engine wäre eine neue Fläche —
und die Produktdefinition sagt: ein Medium dazunehmen heißt einen Abonnenten dazunehmen, nie eine
neue Oberfläche. Die Auslieferung als einzelne HTML-Datei ist PIPELINE (Website-Demo), nie In-App.

**Mirror:** `inspiration.csv` (vier Zeilen, 2026-09-04).

### 2026-08-28 — Founder-Dreiklang: Raumfahrtmedizin · Psychonauten · TSMOM/„Einfalt"-Strategie

- **Raumfahrtmedizin → WATCH** (Learn-Content-Kandidat, Review 2026-11-26). Autonome/HRV-
  Forschung in Raumfahrt & Extremumgebungen ist echte, zitierbare Wissenschaft — dieselbe
  Klasse wie die bestehende Body-Science-Sektion (`BioScienceInfo`: Lehrer/Vaschillo,
  Goessl 2017). Als ZITIERTE Learn-Karte („HRV unter Extrembedingungen") on-brand;
  als POSITIONING („wie bei Astronauten") wäre es Overclaim → verboten. Gate-Bedingung
  vor Adoption: echte Paper-Verifikation (eigener Evidence-Report wie
  `REPORT_SOUND_PAIN_EVIDENCE`), aus der Sandbox nicht seriös leistbar. KEIN Health-Claim,
  nur Fakten + Selbstbeobachtung.
- **Psychonauten → REJECT (für Copy), Kern bereits ratifiziert.** Die legitime Hälfte —
  kontemplative Selbstbeobachtung, Innenreise — IST der ratifizierte Produktsatz
  („Create From Within", PRODUCT_DEFINITION). Das WORT trägt Esoterik-/Drogenkultur-
  Konnotation und kollidiert mit der mandatierten Sicherheitswarnung („NOT under the
  influence") und der FDA-General-Wellness-Linie → Brand-Rotlinie. Nie in nutzersichtbare
  Kopie; nicht re-litigieren.
- **TSMOM („time-series momentum", Moskowitz/Ooi/Pedersen 2012) + „Einfalt"-Strategie →
  WATCH mit präziser Adoptions-Bedingung** (Review 2026-10-15). Die Übersetzung auf Echoel
  ist bereits GEBAUT, einmal: #813 leitet aus der Kohärenz-HISTORIE eine vorzeichenbehaftete
  Änderungsrate ab (Momentum des Körpers, nicht sein Pegel) → Spektral-Morph. TSMOM
  generalisiert das: HR-Trend, Atemraten-Trend als weitere Modulationsquellen — „die
  RICHTUNG des Körpers spielt mit". Bedingung: ERST die Founder-Geräteprobe des
  #813-Trends (Hörbarkeit, `fullScaleRisePerSecond`-Skala = NEEDS-FOUNDER-VERIFY), DANN
  fächern — ein unverifiziertes Muster vervielfältigen wäre die Breadth-first-Falle
  (Prinzip 6). „Einfalt" gelesen als Strategie-Bestätigung: ein Instrument, eine
  Grenze (Editor ≠ Workstation), keine neue Fläche — Validierung, kein To-do.

### 2026-06-19 — Corey Haines `marketingskills` (MIT, 45 skills) → ADOPT→PIPELINE
- Founder: adopt the marketing pack "optimized" into the repo, keep CLAUDE.md tidy.
- **Verdict: ADOPT→PIPELINE** — it markets the App Store app + `docs/` site; it is
  **never in-app / never touches `Sources/`**. MIT, self-contained, zero build/audio risk.
- **Optimized form:** vendored whole + functional at `.claude/skills/marketing/`
  (upstream LICENSE + README kept; their `CLAUDE.md`/`AGENTS.md` dropped so they don't
  shadow Echoel). Front door = new `echoel-marketing` skill: iPhone-instrument priority
  map (ASO/copy/CRO/site first; revops/sales/cold-email = low relevance) + HARD brand
  guardrails (no wellness/esoteric/overclaim; claim only what ships). CLAUDE.md gets ONE
  pointer line. `decisions.csv` 2026-06-19. Review 2026-09-19.

### 2026-06-17 — Two "top Claude tools" + "Fable 5 OS / Jarvis" carousels (17 tools)
- **claude-video** (FFmpeg frames + Whisper) → **ADOPT→PIPELINE** — analyze device
  screen-recordings for QA + promo reels. Not in-app.
- **Skill architecture (SKILL.md)** & **markdown long-term memory (Obsidian-vault pattern)**
  → **ALREADY ADOPTED** — we run `.claude/skills/` + `memory/`+`scratchpads/`+`decisions.csv`.
  Validation, not a to-do.
- **graphify / open-design / impeccable / design-extract** → **WATCH** — only touch the
  `docs/` marketing site; optional polish, not product.
- **Local voice (Whisper STT + Kokoro TTS)** → **WATCH** — on iOS the equivalent is
  Siri/App Intents, already wired (`EchoelIntentInbox`).
- **caveman / codeburn / career-ops / browser-harness** → **REJECT** — terse-output risks
  rigor / pure ops / irrelevant / redundant with the Playwright MCP.
- **VAULT HUD + reskin-per-client** → **REJECT** — agency play; Echoel is one consumer app.

### 2026-06-17 — BAM (Imaginando) as DAW+visuals benchmark
- → **BENCHMARK (informs PRODUCT)** — confirms the integrated DAW+visuals core direction;
  drove the Metal bio-visual foundation (build 1867). Not a dependency.

### 2026-06-17 — Deep research: "multidimensional" positioning
- → **ADOPT→PRODUCT/POSITIONING** — MPE freed the term; Dolby/Apple own spatial/immersive.
  Logged in `decisions.csv` (2026-06-17). Drove the 5-dimension website + sub-bass/LFE.

### 2026-06 — "Claude for Creative Work" MCP connectors (Ableton/Resolume/Blender/Adobe…)
- → **PIPELINE / COMPLEMENTARY** — agent *controllers*; Echoel is the live bio *source*.
  An agent can drive Ableton/Resolume while the body (Echoel) is the input. Not embeddable in iOS.

### 2026-06 — Earlier carousel (Superpowers / Remotion / Agent Browser)
- **Remotion** → **ADOPT→PIPELINE** (promo reels on CI; `remotion-best-practices` skill installed).
- **Playwright / gstack / agent-browser** → **ADOPT→PIPELINE** (docs/site E2E + visual QA).
- **Superpowers** → **WATCH** (dev shell, minor).

---

_Update this ledger + `inspiration.csv` whenever new inspo arrives. Run the gate
before adopting anything. PRODUCT adoptions also get a `decisions.csv` row._

## 2026-06-17 — Video / Video-AI / broadcast / collab gate (founder ask + WWDC2026/382)

Founder: re-introduce the full "biofeedback meets composition/production/video cut/
visual light/performance/live broadcast/collab + realtime worldwide" vision; asks about
video capture, automatic white balance, "Video AI"; shared WWDC2026/382. Gate result —
resolve the standing Live-Broadcast oscillation (gap #1) and do NOT re-open breadth.

- **WWDC2026/382 is NOT a video session** — it's "Inside Apple Intelligence and Xcode"
  (Foundation Models, Core AI, MLX, App Intents, Xcode 27). Relevant to the AI half only.
- **Foundation Models / Core AI (on-device) → WATCH.** AI is an *enabler*, not one of the
  five dimensions. On-device+private fits the brand. Adopt into product ONLY after a real
  on-device latency/availability probe (same gate as CoreML/RAVE). No AGI/super-AI copy.
- **MLX → REJECT (in-app).** Mac/distributed; at most asset-gen pipeline.
- **Video capture + auto white balance → ROADMAP-WATCH.** Feasible (rPPG CameraCapture
  already coexists with audio via `automaticallyConfiguresApplicationAudioSession=false`),
  but it's the exact pillar that slopped. Adopt only AFTER bio-core depth and only as a
  *bio-reactive* camera (coherence-driven grade/visual), never a generic recorder clone.
- **Live broadcast (RTMP/SRT) → WATCH.** Stop oscillating: stays ROADMAP, HaishinKit is the
  sole sanctioned dep, build only after core + open-standard out-pillars are complete.
- **Realtime worldwide collab → NORTH STAR.** Physics-bounded; honest-feasible is async/loop
  or OSC/MIDI-over-LAN, not "realtime worldwide". Never product copy.

Highest-value move: NOT a new pillar. Finish bio-core *depth* — wire the just-landed
HRVCoherence + BreathPacer into the one EchoelStudioView and the existing live dimensions
(Sound/Light/Space/Vibration already consume the bus). Breadth comes one bio-reactive
pillar at a time, on the stable bus, after the core loop is visible on device.

## 2026-06-17 — Homepage optimization + Blackbox/community-platform direction

Founder: "optimize the entire homepage" (ref unitycodetechno.com — blocked 403, could
not view) + note that Blackbox App's job-placement direction is close to a planned idea,
but for Echoel it's about development/science/art/health/learning, not jobs.

- **Community/collaboration/learning platform → NORTH STAR (parked).** A people+projects+
  learning matching layer is a major pivot beyond "the instrument." Gate: build the
  instrument's traction + audience first; do not graft a platform onto the product site
  now. Most that belongs on the homepage later is a small "collaborate / learn" teaser —
  never as a shipping claim. Logged; awaiting founder go/no-go before any scope.
- **Homepage optimization = in-scope polish**, but the live site is already well-built
  (SEO/OG/structured-data/own CI/Atkinson/16 subpages, honest "concept in development").
  Not broken → "optimize" needs a direction. Reference unreachable (403); need screenshots
  or a specific focus (design refresh / copy / performance / IA / science angle).
- Opportunity now: the homepage's science angle can be strengthened HONESTLY — real
  frequency-domain HRV coherence (HRVCoherence) + a resonance breath guide just landed.

## 2026-06-21 — Spectral light-therapy science review (founder document, PMC-cited)
Founder shared a rigorous, peer-reviewed review of light→physiology (circadian ipRGC/melanopsin
~480nm; bright-light therapy; green ~525nm analgesia; red/NIR photobiomodulation via CCO; blue
antimicrobial; neonatal phototherapy) + empirical colour psychology (global colour–emotion
meta-analysis 1895–2022, Yerkes-Dodson, colour-in-context).

- **ADOPT→PRODUCT (narrow):** Use the WAVELENGTH SCIENCE + colour–emotion data to make Echoel's
  **Light (Art-Net/sACN) + Visual (SpectralColor)** output scientifically accurate, and enrich the
  **"app as a school"** tap-to-learn with cited facts. Facts + self-observation only.
- **REJECT (hard, never re-litigate):** any **therapeutic/medical claim** (treat depression,
  migraine, acne, pain, jaundice). FDA general-wellness red line + principles 3/4. Echoel is NOT a
  therapy/wellness/medical product. No "light therapy mode", no benefit promise, no dosage protocol.
- **WATCH:** circadian-aware palette (warmer/dimmer evening), strictly perceptual framing, no health claim.

Highest-value adoption: a **science-grounded light/colour engine + cited LearnLibrary entries** —
deepens the TIER-1 Light dimension with rigor, stays on the right side of the medical red line.

---

## 2026-07-02 — Deep-research relay: web STT + web bio-visuals for echoelmusic.com

External suggestion (founder relay): local STT via **Whisper-Flow** (WebSocket server),
bio-visuals via **Three.js + MediaPipe FaceMesh + Web Bluetooth**. Scored against vision +
"straight to future Apple hardware / iOS ecosystem".

- **Verdict pattern: the CAPABILITIES are on-vision; the TOOLS are the wrong platform.** The
  suggested stack is a browser/Python glue architecture that directly contradicts principle 2
  (near-zero deps, no SDK lock-in) and Echoel's on-device, no-backend identity. Every piece has
  a *native* equivalent that is already shipping or is the correct Apple path:
  - Whisper-Flow → **Apple SpeechAnalyzer / SpeechTranscriber** (iOS 26, on-device, streaming) — REJECT tool, ADOPT capability natively.
  - Three.js → **Metal / MetalBioView** already ships (TIER-1) — REJECT (redundant).
  - MediaPipe FaceMesh → **ARKit blendShapes / Vision** — WATCH (face as a later body input).
  - Web Bluetooth → **Core Bluetooth** universal 0x180D already ships (TIER-1) — REJECT (redundant).
- **Highest-value nugget: on-device SPEECH as a control/caption modality** — voice as a 6th body
  input (hands-free control, take-tagging, **live captions = accessibility win**, and spoken-word
  into the flagship **AUDIOVISUAL VOCODER**). Apple just shipped the perfect native tool; this is
  the one thing worth planning (one Ralph cycle, sequenced after the vocoder wiring).
- **Apple-ecosystem read:** Apple's on-device Apple Intelligence + SpeechAnalyzer pivot is a
  *tailwind* — "your voice and body never leave your iPhone" is now Apple's own headline. Betting
  native bets *with* Apple's roadmap (Neural Engine, visionOS spatial = the installation North Star);
  a localhost web stack fights it and undercuts the privacy narrative.
- **Website only:** a live browser demo (Three.js + Web BLE + browser STT) is the ONE legit place
  the web stack fits — PIPELINE, never Sources/. But it's heavy and risks being worse than the app;
  prefer the already-logged cheaper route (Hyperframes pre-rendered loop/video) first.

---

## 2026-07-02 — YouTube intake capability + first video

**Capability shipped (pipeline):** `scripts/analyze-youtube.py` + `.claude/skills/youtube-analyze/`
— fetch a video's metadata + transcript → score via vision-gate → log here. Robust (URL/ID
parsing self-tested, yt-dlp→oEmbed metadata fallback, modern+legacy transcript API, clean
network-block error). NETWORK NOTE: this session's policy blocks youtube.com at the proxy
(403), so live fetch needs a session/machine where YouTube is reachable; PyPI is reachable.

**First video — "Use These 17 Claude Plugins" (V2RIVnGCy74):** a Claude Code *plugin* roundup
= DEV TOOL, not the app. Verdict **ADOPT-PIPELINE (selective) / WATCH** (see
`scratchpads/inspiration/youtube-V2RIVnGCy74.md`). Echoel already runs the mature bespoke
equivalent (skills + review sub-agents + rules + markdown memory), so no wholesale install.
Only nuggets: `mcp-builder` for a tiny TestFlight/ASC-status MCP (kill the 400 KB actions_list
dumps), and the plugin/marketplace format if we ever publish our `.claude/` skills. Transcript
was blocked in-session; re-run the tool where YT is reachable to capture the exact 17 list.

---

## 2026-07-02 — Deep-research strategic synthesis (founder doc)

Mostly **validation**: the protected DSP triad, the Core-Bluetooth (not HealthKit) realtime
path, and the **deterministic bio→parameter mapping** are confirmed on-vision AND a **legal
moat** in the 2026 AI "consent crisis" (AFM v UMG/WMG; Spotify/TME synthetic-track purges; EU
AI Act 50(4)) — Echoel replicates no copyrighted training data, so it dodges the generative
"black-box" liability. That's positioning/marketing truth (echoel-marketing), not a code change.
Genuine roadmap WATCH items logged to inspiration.csv: AccessorySetupKit onboarding · C2PA/DDEX
session provenance · Cyborg-Synchrony collective audience biofeedback over OSC (North Star live
pillar) · AVAudioEngine spatial + CMHeadphoneMotionManager head-tracking. **REJECT:** the
five-tone/Jue clinical-anxiety framing (wellness/medical red line — facts may inform cited
tap-to-learn, never a therapy claim). No change to the active professionalization loop.

## 2026-07-02 — PENDING YouTube analysis (network-blocked, awaiting policy widening)
Founder shared these as inspiration; youtube.com is egress-blocked in this env (see
memory/decisions.md 2026-07-02). Once the env network policy allows youtube.com +
*.googlevideo.com, run each through youtube-analyze → vision-gate → verdict + nugget.
- https://www.youtube.com/watch?v=ovj_Gor6nSM
- https://www.youtube.com/watch?v=0UaqjKb3QHM  (from search "Software developer claude solo apple")
- https://www.youtube.com/watch?v=Ffh9OeJ7yxw  (from search "Software developer claude solo apple")
- https://www.youtube.com/watch?v=MzhIr7BfpI0
- https://youtu.be/GQGr4sXlWb0
- Playlist: https://youtube.com/playlist?list=PLRmLTbt9DLCEW7BSqwhnwFwGOw_vC9rUK

---

## 2026-07-02 — Founder legacy-doc dump (12 files) — vision-gate triage

Founder uploaded 12 old planning docs asking "ist noch was Brauchbares bei?":
Übersicht.docx (=Gibberish Master Spec), Musik_Wellness_TraumaForschung.docx,
ProjectKnowledge_Optimized/Gibberish, App_ToDo_Board, AI_README_V10_3,
Dev_Kit_v1 (+ LICENSE/TESTPLAN/Manifest/CONTRIBUTORS), Gibberish_Master.

**Verdict: mostly HISTORICAL/SUPERSEDED; a big chunk OFF-VISION (wellness/esoteric);
a handful of genuinely useful on-vision salvage items.**

### SALVAGE — on-vision, worth keeping/considering
- **TESTPLAN.md** → adopt as an rPPG QA reference: the lighting (daylight/LED warm-cold/
  low-light+torch) × motion (stable/micro/strong) × temperature (ambient/warmed) matrix +
  "freeze on low confidence / fallback values" is exactly our device-verification grid.
  ADOPT-PIPELINE (a docs/dev/RPPG_TESTPLAN.md), timely for the current rPPG hardening.
- **Ableton Link** — already CLAUDE.md-sanctioned + noted planned in PatternEngine/App;
  best concrete tech pickup for the performance-instrument vision. WATCH→build when scheduled.
- **Dolby Atmos / spatial objects** (V10.3 spatial_mixing, "Atmos bed+objects") — aligns with
  the existing ADM-OSC immersive-object direction. WATCH (future pro output).
- **Facial-expression as a bio-input** (Vision framework face landmarks) — on-vision as a
  science-based MODULATION SOURCE if framed neutrally (expression→modulation), dropping the
  "School of Smiling"/wellness framing. ADOPT-PRODUCT candidate (new bio input; not built yet).
- **Shared-coherence multiplayer** (WebRTC/LiveNet performer↔audience) — on-vision; partially
  exists (MultipeerSession). WATCH.
- **OSC / Ableton M4L companion bridge + AUM mapping presets** (Dev_Kit) — fits the open-
  standards / no-SDK-lock-in positioning. WATCH (ecosystem play).
- **Manifest.md "Science + Art, no health-claim" framing** — reinforces current brand; the doc
  itself already quarantines the spiritual layer from the evidence-based core. Reference only.
- LICENSE (MIT code + © brand/artwork) — repo ALREADY has one; no action.

### REJECT — off-vision / banned by brand guardrail (do NOT bring into the app)
Organuhr, Meridiane, Soultuning, Stammbaum-Visualisierung, KI-Trauma-Modelle, Dorn-Methode,
Kinesiologie, Reflexzonen, ätherische Öle/Cremes/Supplements, "Wellness/Therapy" positioning,
"Health & Fitness" category framing. Also superseded tech: JUCE/VST desktop, AudioKit, Android/
Web as core (iPhone-first, Swift-only, HaishinKit sole dep). The umbrella-business empire
(Gastro/Shop/Club/Consulting/Board/Glasses hardware) is founder BUSINESS vision, not app scope.

Note: the "Gibberish" files are just stylized/obfuscated duplicates of the plain docs — no new info.

### 2026-07-02 addendum — Artifacts_1.txt / Artifacts_2.txt (SYNG-era dumps)
Triaged: NO code salvage. Old "SYNG" pre-Echoel prototype — C++ UpdateSystem, Python
VisualProcessor/PerformanceManager stubs, GPL v3 repo tree, Windows build.yml — the exact
C++/CMake/desktop/GPL stack deliberately removed (Swift-only/MIT/iPhone-first now). Only
business/branding/monetization brainstorming (freemium, domains) = business-side, not app.
The in-file "TherapeuticEffects→HarmonicEffects" rename just confirms the de-medicalize direction.

### 2026-07-02 addendum 2 — Atmos/Dante batch + more BLAB code dumps
- **Ableton_Atmos_Live_Workflow / Dolby_Renderer_Config / Dante_Routing_Guide** — the ONE
  genuinely valuable find in the whole legacy dump. Pro live-production workflow: Ableton →
  Dolby Atmos Renderer (Bed 7.1.2 + N objects) → ADM BWF, Dante two-machine routing, binaural
  monitor; "BLAB/Blub receives OSC for visuals & haptics." VALIDATES Echoel's existing ADM-OSC
  output (/adm/obj/{n}/*) as the bio-reactive OBJECT SOURCE into a spatial rig — exactly the
  CLAUDE.md strategy ("bio-reactive object source for accessible immersive media"). ADOPT-PIPELINE:
  write a docs/integration guide "Echoel → Atmos/Ambisonics via ADM-OSC (+ OSC→visuals/haptics)".
  Not app code. Confirms the immersive direction is already correctly built.
- **code.txt / code_2.txt (identical), blab_blub_suite_v2.txt, Code_Bausteine.docx,
  AI_README_V10_3 (dup)** — BLAB C++ "Immersive Sound" core + BLAB/BLUB C++ starter kit +
  HTML/JS sound→light tutorial. Banned brand + discarded C++/JS stack + already-built concept.
  NO salvage.

**ARCHIVE CLOSED (~27 files triaged).** Net on-vision salvage across the ENTIRE legacy dump:
(1) Atmos/ADM integration guide [pipeline/docs], (2) per-track Kammerton/Tonart [music feature],
(3) worldwide-styles/harmony DB [genre depth], (4) Ableton Link, (5) facial-expression bio-input,
(6) shared-coherence multiplayer. Everything else = BLAB/SYNG banned brand / discarded stack /
wellness-esoteric / already-shipped. Do not deep-read further dumps — signal-scan + bucket only.

### 2026-07-08 — Ambient-Tool-Links (Void&Vista · 10K Gyro · Eraform) + Ambient-Rezept + Cousto-Attribution
- **Void & Vista (FOLDS/STRANDS/FRAMES)** — REJECT als Produktmodell (Kontakt-Sample-Libraries,
  25GB-Assets ≠ synthesis-first/zero-deps); ihre UI-als-Kunst-Messlatte = Validierung unseres
  Visual-first-Anspruchs.
- **10K Audio Gyro (ex-NI)** — WATCH/Strukturvalidierung: generative Loops + reaktive GPU-Visuals
  = unser nächster kommerzieller Verwandter, aber MAUS-gesteuert. Body-as-controller bleibt das
  Alleinstellungsmerkmal auf exakt diesem Feld. Nuggets: kuratierte Chord-Packs, Half-Time-FX.
- **Eraform Fraction** — ADOPT-PIPELINE (Pricing): One-time-Payment + wachsende Gratis-Inhalte
  bestätigt MASTERPLAN §2 wörtlich.
- **Ambient-Rezept (Founder):** Slow-Attack-Drone (3–6 s Attack, max Release) = ADOPT-PRODUCT,
  als nächster Sound-Zyklus eingeplant (reine SynthPatch-Params, dient "weicher/wärmer").
  Shimmer/Wash-Reverb + Micro-Harmonizer = WATCH (FX-Workstream; sanftes 2-Voice/7¢-Unison ist
  schon die dezente Harmonizer-Stufe). Field-Recordings/Vinyl-Beds = WATCH nur als SYNTHESE
  (noiseColor/Cellular), keine Sample-Beds (SoundscapeEngine bleibt tot), kein Wellness-Framing.
- **Cousto-Attribution (Founder: "er will erwähnt werden"):** Credit-Zeile in LightScienceInfo
  (.scope) + Visual-Panel-Caption ergänzt — science-first formuliert (Konzept-Credit, mathematisch
  exakt, "artistic convention", KEIN kosmisch/therapeutischer Claim). Rechtslage: Oktav-MATHE ist
  als Methode nicht schutzfähig, wir reproduzieren keine Cousto-TEXTE/Tabellen/Grafiken →
  keine CC-Pflicht entsteht; die Nennung ist freiwillige, korrekte Wissenschaftspraxis. Seine
  Markenbegriffe ("Kosmische Oktave" als Produktname, "Planetentöne"-Branding) NICHT als
  Feature-Namen verwenden — nur beschreibend/attributiv.

## 2026-07-09 — Rapidflow Sphere V3 (founder: "evtl als Inspiration interessant?")
- **Was es ist:** Audio-reaktiver VST-Visualizer (Desktop/DAW): splittet Audio in Frequenzbänder,
  Modifier per Drag-and-drop auf Visual-Parameter (Zoom/Displacement/Farbe/Bewegung), MIDI-CC,
  LFO-Modulation, Video-Recording. Kein iOS, kein SDK.
- **Verdict: WATCH.** Bestätigt die Kategorie (audio-reaktive immersive Visuals) — Echoel macht
  das nativ UND bio-reaktiv (unser Differenzierer). Die eine übertragbare Idee — PER-BAND-
  Reaktivität statt nur Master-Level — liegt bereits geparkt ("trackLevels → Element-Reaktivität:
  Drums/Bass/Lead getrennt", seit v10.79.118; masterLevel→Intensity ist geshippt). Nichts zu
  adoptieren außer dem geparkten Zyklus; kein Dependency-Kandidat.

## 2026-07-10 — AI-Chat "Apple-Stack DAW-Plan" + Fluid Voice (founder: "Ist da was brauchbares bei?")
- **AudioKit-Architektur-Shift — REJECT:** Die Prämisse des Chats (weg von einer Web-DAW)
  trifft uns nicht — Echoel war nie web-basiert und sitzt bereits DIREKT auf Core Audio/
  AVAudioEngine mit eigenem lock-freiem DSP-Kern (zero deps, <10 ms). AudioKit wäre ein
  Wrapper über dieselbe API: nichts gewonnen, eine Dependency verloren.
- **Empfehlungstabelle des Chats (AVFoundation/Metal/Fastlane) — CONFIRMS:** beschreibt
  wortwörtlich unseren Ist-Zustand bzw. den bestehenden Video-Plan (Stage 3–5 gegen die
  Transport-Clock). Externe Validierung, kein neuer Inhalt.
- **openDAW als Konzept-Referenz — WATCH:** ggf. UX-Referenz für Region-Editing bei K3.
- **Swift-Packages-Refactor — REJECT (jetzt):** Umbau ohne Ship-Wert mitten im Launch.
- **⭐ Multichannel-Routing (BiG SiX/Xone 96) — ADOPT-PRODUCT (Roadmap):** der eine echte
  Nugget. Stems (Drums/Synth/Bass/Master) auf getrennte Kanäle eines class-compliant
  USB-Interfaces → das Pult wird Summing-Mixer/Insert-Weg. Passt exakt zu "Sämtliche
  Hardware wird unterstützt"; Zyklus nach den One-View-K-Stufen.
- **Fluid Voice — WATCH (Pipeline):** macOS-Diktat-Tool, braucht Apple Silicon — der
  Founder-Laptop kann das nicht; iPhone-Diktat in der Claude-App erfüllt den Job heute.
  Keine Repo-Integration nötig (diktierter Text ist normaler Text).

## 2026-07-10 — AI-Chat "Killer-Prompt" (FL Studio 2026 Gopher/Transmitter, Leapfrogging)
- **Komplett-Reframe zur macOS-exklusiven Desktop-DAW — REJECT:** widerspricht iPhone-first
  (Founder-bestätigt) UND dem laufenden Launch; der Founder-Rechner könnte das Produkt nicht
  einmal bauen. Feature-Krieg gegen FL/Ableton/Reaper/Resolve ist beschieden (2026-07-09:
  Wedge = Biofeedback + Interop, nicht Parität). Der echte Leapfrog IST unserer: der Körper
  als Controller + generative Puls-Sync-Kollaboration — von keiner Audio-streamenden DAW
  kopierbar. AudioKit/SwiftPM/Fluid-Voice-Punkte: bereits am selben Tag gegated (s. o.).
- **Agentic Command Engine (CoreML/ANE-Voice-Agent) — WATCH:** Copy-Reflex auf ein
  Konkurrenz-Experiment; unser Interface ist der Körper, nicht Chat. On-device-ML-Schicht
  bleibt Tier-2 (Latenz-Prototyp zuerst).
- **⭐ Transient/Sustain-Split (vDSP) — WATCH-ROADMAP:** der brauchbare DSP-Kern. Contained
  Accelerate-Node für den EchoelFX-Workstream; EchoelBreak plant Transient-Detection ohnehin.
  Bio-moduliert (Körper → Attack-Anteil) wäre er ein Alleinstellungsmerkmal. Nach dem
  One-View-Arc.
- **Metal-Timeline (120fps) — REJECT (jetzt):** prämature Optimierung; SwiftUI trägt unsere
  Skala, Metal bleibt dem Bio-Visual vorbehalten (ein GPU-Pfad). Audio-Clock treibt
  Video-Clock = bestätigt den bestehenden Stage-3–5-Plan.

## 2026-07-12 — Founder-Share: Imaginando VS (Warning-Screenshot + 50s-Video)
- Video analysiert (8-Layer-Rail + B-Background, per-Layer-Strip ENABLED/SOLO/ALPHA/
  BRIGHT/SPEED/X/Y/RADIUS/NOISE/GLOW/MONO/GLIDE/TRIG, MIDI-Learn überall, Patch-Header,
  30-FPS-Anzeige, Record-Button; Look: Chromatic-Aberration-Ringe).
- **NEU → ADOPT-PRODUCT (klein):** Photosensitivity-Notice beim ersten Visual-Open mit
  "Show again"-Toggle (VS-Muster). Unser Vorteil bleibt: 3-Hz-Clamp VERHINDERT, VS warnt nur.
- **NEU → ALREADY-POSSIBLE:** VS ist selbst ein AUv3 → seit v175 direkt in Echoelmusic
  hostbar (Plugins-Chip); Echoel-MIDI → VS-Visuals im Plugin-Fenster. Founder-Test.
- **Design-Referenz für Layer 3 (AVObjects, Spatial v2):** die Per-Layer-Strip-Grammatik
  (Enable/Solo + Parameterzeile je visueller Ebene) ist exakt die UI-Form für unsere
  SpatialObject-visualRef-Liste — mit EchoelValueField statt Knobs (Ein-Control-Regel).
  Ergänzt den bestehenden ADOPT-ROADMAP-Eintrag (Bio→Layer-Routing), kein neues Verdict.
- Alles Übrige (9:16-Export, Video-Out, Visuals-as-Plugin) bleibt wie am 2026-07-11 gegated.

## 2026-07-12 — Founder-Share: Demo | Songwriting Studio (id1563264178) — „Können wir besser"
- Was es ist: geführter Songwriting-Bogen (Akkord-Generator + Progressionen → Rhythmus
  passt sich Akkordwechseln an → Lyrics mit Reim-Tool → Mehrspur-Gesangsaufnahme →
  Export Mix/Stems/MIDI/Chord-Sheet), iCloud-Sync + CoWrite; Demo+ 39,99 $/Jahr.
  Neuestes Feature „Suggest in Chords": einsingen → Offline-Notenerkennung (explizit
  ohne AI) → Akkordvorschläge. Rezeption gut bis auf Cloud-Sync-Ausfälle.
- **ADOPT-ROADMAP (Flow):** der geführte Bogen ist die richtige Meßlatte — Echoel hat
  Akkorde/Theorie/MIDI-Export in-house und schlägt Vorlagen mit BIO-Generativität;
  fehlend: Lyrics-Fläche + Mic-Overdub (Multitrack = bestehende Roadmap, nichts Neues).
- **⭐ Hypothese an den Founder:** sein „Word" in der EchoelBioSynth-Panel-Liste
  (Comp/Session/Transpose/Sound/FX/Mood/Synth/**Word**) könnte LYRICS/Songtext meinen —
  Demo-Share stützt das. Bestätigen lassen, bevor E4 die Panels schneidet.
- **ADOPT-ROADMAP (Hum-to-Harmony):** „Suggest in Chords" bio-first gedacht: Stimme =
  Körpersignal; hauseigene Pitch-Detection (Tools/, VocoderCore) + in-house-Theorie →
  einsummen → Akkorde, deterministisch, ohne neue Deps, ohne AI-Claim.
- **WATCH (Lehren):** Cloud-Sync-Beschwerden = Warnung für CollabSync (State klein,
  Protokoll v1 statt Dokument-Sync); Abo-für-Features bestätigt unser Modell
  (freies Instrument, Abo nur für den Live-VERBINDUNGS-Dienst).

## 2026-07-12 — Deep-Research 3-Strang (Founder-Auftrag) + Nachnennungen — KONDENSAT
- **Dreifach-Lücke bestätigt (Positionierung):** kein Bio-AUv3, keine ADM-OSC-Quelle
  auf iPhone, kein kommerzielles Bio→Visual/Licht-Tool. dearVR ist tot (Sennheiser
  2025). „Bio-reaktive Objektquelle" = unbesetzt UND bei uns schon live (ADMOSCSender).
  Claim-Regel: nur nennen was LIVE ist.
- **AUv3-Sandbox-Realität (E4):** Plugin liest kein HealthKit/BLE frei — App-als-
  Sensor-Hub via App-Group/Host-MIDI ist DAS Markt-Muster (deckt PLAN E4). Audio
  Damage „same engine everywhere" + Otoo (standalone+AUv3+Host zugleich) = Vorbilder.
- **Stärkste Feature-Übernahmen (geloggt, je eigener CSV-Eintrag):** Rubato-Zeit-
  Elastizität bio-getrieben · Ribbon/Transit-Ein-Gesten-Morph (= EchoelFX Workstream 3,
  Morph-Regler kann Bio sein) · Scaler-EQ-Idee tonart-getrackt (wir KENNEN den Key) ·
  Hum-to-Harmony (Demo) · MusiKraken-Inputs AirPods-Head/Watch-Crown (WATCH).
- **Spatial-Baurichtung bestätigt:** Hosts sind stereo → intern binaural dekodieren
  (Audio-Brewers-Muster); Isone hosten = Binaural-Vorschau vor eigenem Kern;
  Animoog Galaxy (visionOS) = Präzedenz „Stimmen als Raumobjekte" → SpatialScene-Plan.
- **Licht/Visual-Messlatte:** Fixture-Profiles + Cue-Stacks (Luminair/Blackout),
  BeatTracker+Link (Photon), Timeline-über-Engine (MadMapper 6 → Layer 7). VS-2-
  Modulations-MATRIX (nicht Node-Graph) = die mobile Routing-UX. TDLidar beweist
  „iPhone als Sensor-Peripherie großer Rigs" — exakt unsere OSC-Rolle.
- **BLE-MIDI-Befund (Founder-Frage):** MPE/MIDI2.0-Parsing + RTP-MIDI laufen; BLE-MIDI-
  Geräte erscheinen als CoreMIDI-Quelle sobald GEKOPPELT — es fehlt nur der In-App-
  Kopplungsdialog (CABTMIDICentralViewController als Panel-Inhalt, KEIN neues Sheet).

## 2026-07-12 — Deep-Research: ACE Studio 2.0 (Founder: „alles Sinnvolle übertragen, Zero Deps")
- Was es ist: Desktop-KI-Gesangs-Workstation (Timedomain, Peking; 2.0 Dez 2025,
  140+ Stimmen/8 Sprachen, Server-Render, Abo ~150-200$/Jahr). Kein Mobile, kein Realtime.
- **Übertragen (Konzepte, in-house deterministisch):** Lyrics/Phoneme ALS NOTEN-
  EIGENSCHAFT in der Roll (→ bestätigt „Word"=Lyrics für E4) · Zwei-Kurven-Pitch
  (Basis dunkel/Override weiß → VL3: erkannt vs. korrigiert; Roll: generativ vs.
  gemalt) · Per-Note-Vibrato {depth,speed} · Vocal→MIDI Note-Only (YIN-Segmentierung
  → Roll → MIDI-Export; „Singen wird Komponieren") · Atem als Ereignis — bei uns
  BIO-ECHT aus BioEventGraph statt künstlich eingefügt.
- **WATCH:** semantische Vocal-Macros (Power/Soft/Breathy/Chest über DDSP-Achsen,
  nach VL3) · ACE-Bridge/ARA-Muster (MIDI-Capture im Plugin) für EchoelBioSynth E4.
- **Bestätigt unsere Gesetze:** ihre Top-Beschwerden = Cloud-Render-Latenz + Abo-
  Dark-Patterns → on-device + Einmal-Unlock ist die exakte Gegenposition. KI-Stimm-
  Weights bleiben REJECT-UNTIL-LICENSED (ihr Voice-Donor-Royalty-Modell = einziges
  ethisches Vorbild, FALLS je relevant).

## 2026-07-13 — Founder-Video-Uploads (2 Reels, per neuem video-watch-Skill GESEHEN)
- **Reel 1 (buildwith.conrad, „Claude can't watch video → so I gave it eyes"):** Rezept
  yt-dlp → ffmpeg-Frames → Claude liest Frames als Bilder. **ADOPT-PIPELINE → GEBAUT**
  als `.claude/skills/video-watch` (Script self-tested + End-to-End auf den Uploads
  bewiesen). Local-Upload-Pfad = zero network; YouTube-URL-Pfad in dieser Session
  proxy-blockiert (403 googlevideo) → Freischalten via Environment-Network-Policy
  (youtube.com + googlevideo.com) ODER Founder lädt Datei hoch (funktioniert immer).
  Kein lokales Speech-to-Text — ohne Subs zählt nur das Bild (ehrlich ausweisen).
- **Reel 2 (sebastiankauffmann, „5 beste GitHub-Repos für Claude Code"):** Leads:
  everything-claude-code (Dev-Team R/M/S/T) · claude-mem (~Erinnerung) · last30days-skill
  (24k Stars) · Token-Reduktions-Skill (−20 %) · Design-Output-Skill. **WATCH** —
  Supply-Chain-Regel: nie Skill-Packs aus Videos auto-installieren; wir fahren bereits
  memory/ + decisions.csv + Reviewer-Fleet (deckt claude-mem/Dev-Team-Kern ab).
  Einzeln vision-gaten, wenn der Founder eines konkret will.

## 2026-07-13 — FL Studio Mobile (Founder-Video + Deep-Research, 56 Agenten, adversarisch verifiziert)
Founder: „schau dir per Deep Research alle EFx und Instrumente an und lass dich inspirieren"
(Echoel bleibt Profi-Level, aber das leichte Handling ist attraktiv). Video Frame-für-Frame
gesehen + Research gegen Image-Line-Manual verifiziert.

**Kern-Erkenntnis:** FLs „leichtes Handling" = EINE Idee — man kann keinen falschen Ton spielen.

- **ADOPT-PRODUCT · Scale-Lock + Root-Wahl** (verifiziert, Image-Line Module_Note_Scale):
  12 Notenschalter C–B (snap/filter), one-tap „Scales"-Preset, „Key"=Grundton A–G. Echoel
  hat Key/Scale/Kammerton schon in-house → billig; wrong-note-free schnelles Live-Spiel,
  on-vision. **Höchster-Hebel-Adopt.** (Kammerton=A440 bleibt separat vom Grundton.)
- **ADOPT-PRODUCT · Single-Knob-Morph** (verifiziert, MiniSynth-Manual): ein Modifier-Regler
  morpht Wellenform-Charakter (Saw+Square-Pulsweite) statt vieler Osc-Params → passt exakt
  zu EchoelValueField; ein Charakter/Morph-Knopf für PolySynthVoice.
- **WATCH · Chord-/Strum-Pads pro Skalenstufe** (im Mobile-Video sichtbar; note→chord nur für
  Desktop-FL/VFX-Key-Mapper verifiziert, 2-1). Adopt-fähig NACH Scale-Lock (gleiche Theorie).
- **REJECT · GMSynth/SoundFont** (GM/Consumer-Klang, gegen Profi-/Bio-Identität) · IAA/Audiobus
  (veraltet, wir sind AUv3-Host). Transistor-Bass/Slicer ≈ SubBassVoice+LoopCutter (schon da).
- **Offene Lücke:** Voll-Roster aller FX + Instrumente NICHT unabhängig verifiziert (nur
  MiniSynth + Scale-Modul primärbelegt). Bei Bedarf zweite Research-Runde gezielt auf FX-Liste.

**Roadmap-Einordnung:** Scale-Lock + Morph-Knopf = Prio-Zyklen NACH dem laufenden AUv3-Block
(Founder-bestätigt „AUv3-Struktur JETZT"). Nicht vorgezogen ohne Founder-Ask — nicht verfransen.

### FL Mobile Voll-Roster (Lücke geschlossen, WebSearch Image-Line-Manual 2026-07-13)
**Instrumente (aus Video-Menü):** MiniSynth · DW Sampler (DirectWave-Stil) · GMSynth ·
Transistor Bass (TB-303) · SuperSaw · Slicer · 3x Osc · SoundFont Player · Drum-Kits.
**Effekte (~32 Module, Image-Line-Manual):** Analyzer · Autoduck · Pitcher/Pitcher 2 ·
Chorus · Comb Filter · Compressor · Multiband Compressor · Distortion · Waveshaper ·
Parametric EQ · Graphic EQ · Tuned EQ · Filter · Flanger · Phaser · Tremolo · Gate ·
Leveller · Limiter · Multi FX · Reverb · Reverb 2 · Spacer · Spreader · Stereoizer ·
Tape Delay · Trance Delay · Tape Stop · Tuner · Wow & Flutter · Note Effects (inkl. Scale).
**Echoel-Gap:** EchoelFX hat Bitcrush/Widener/Reverb — es fehlen für Profi-Level: EQ
(parametrisch/grafisch), Kompressor + Multiband + Limiter (deckt sich mit Mastering-Plan
M2/M3), echtes Delay (Tape/Trance), Modulation (Chorus/Flanger/Phaser/Tremolo), Gate/
Autoduck, Distortion/Waveshaper. = eigener FX-Ausbau-Block (nach AUv3 + Scale-Lock).

## 2026-07-14 — Founder 5 reference reels (video-watch → vision-gate)

Founder mandate: "integriere alles was uns wirklich hilft und unsere Arbeit
effektiver macht" + "Natürlich auch alles was kreativ und technisch wertvoll ist."

- **ADOPT→PRODUCT — On-device generative "Idea-Maze" composer.** From @jakebeau_'s
  agentic PLAN→ACT→OBSERVE→REFLECT loop + local brain + idea-maze/leaderboard
  (Anthropic "Effective harnesses for long-running agents"). Echoel reinterpretation:
  the bio-generative engine proposes N musical variations, **scores them by
  bio-fit/coherence**, keeps a ranked leaderboard, the musician picks. Passes all
  four gates — Sound (Tier-1 differentiator), iOS-feasible (BioComposer already
  deterministic/seeded; MVP needs NO LLM), on-brand (body curates the ideas;
  seed-recall is our edge), realtime-safe as a control-plane core. **Cheapest first
  step (this Ralph cycle): a pure, tested `BioVariationMaze` core** — seed + bio
  snapshot → N deterministic variation seeds → bio-fit score → ranked leaderboard;
  Foundation-only, flag-gated OFF, zero audio-thread/UI. Later: LLM-assisted
  proposals via the existing EchoelAI brain; a Touch surface to audition the maze.
- **WATCH — offline voice/singing (HeyGem/OmniVoice).** Reinforces the EXISTING
  Tier-2 flagship AUDIOVISUAL VOCODER (VocoderCore built, wiring next) — accelerate
  that, don't start a parallel voice system. Person voice/face-CLONE specifically =
  REJECT (deepfake identity, off-brand, not bio-driven).
- **ADOPT→PIPELINE — "offline/on-device/free/no-subscription" positioning** + the
  **carousel-reel format**: both go to `echoel-marketing` (validated hook + launch/ASO
  playbook; our green-on-black CI already matches). Never in-app.
- **REJECT — Fincept Bloomberg-clone / HyperFrames code→video / Jarvis agent-app /
  auto-content-farm.** Off-vision; building any is the breadth-first scope-creep the
  constitution warns against (principle 6). EchoelAI stays an assistant behind a flag.

**Single highest-value adoption:** the on-device bio-curated Idea-Maze composer
(ADOPT→PRODUCT). Building the pure core now.

### 2026-07-16 — IG-Reel alan.buildz „Claude ist jetzt dein Kreativstudio" (5 Claude-Tools, Founder-Upload .mp4)
Analysiert via watch-clip (37 s, Contact-Sheet + Frames). Alles PIPELINE-Kandidaten,
nichts für Sources/. Abgleich mit bestehenden Verdikten (kein Re-Litigieren):
- **HyperFrames (heygen) „Claude = dein Video-Editor"** → bleibt **REJECT** (bereits
  gescort: code→video Scope-Creep; zudem externe Cloud — Founder-Media verließe die Maschine).
- **Voicebox (jamiepine; 3-Sek-Voice-Clone + On-Device-Whisper-Diktat)** → Clone-Teil
  fällt unters bestehende Deepfake/Voice-Clone-**REJECT** (nie in-app, nicht bio-getrieben).
  On-Device-Diktat = persönliches Founder-Produktivitäts-Tool, keine Repo-Sache.
- **competitive-ads-extractor** (awesome-claude-skills) → **WATCH→PIPELINE**: erst relevant,
  wenn Echoel Paid/ASO-Konkurrenzanalyse fährt (Launch-Phase); dann als Ergänzung zum
  vendorierten Marketing-Pack prüfen. Kein Adopt jetzt (wir schalten keine Ads).
- **last30days-skill** (Nischen-Recherche letzte 30 Tage) → **WATCH**: redundant zum
  vorhandenen deep-research-Harness; nur übernehmen, falls dessen Recency-Sweeps zu teuer sind.
- **Voice DNA (Claude schreibt im eigenen Stil)** → **WATCH→PIPELINE**: die Idee (Stil-Profil
  aus eigenen Texten) ist für echoel-marketing-Copy nützlich; unsere Brand-Guardrails
  existieren schon — ggf. ein Founder-Stil-Absatz in echoel-marketing statt neuem Skill.
- **Format-Takeaway (das eigentlich Wertvolle):** das Reel selbst — schneller Schnitt,
  nummerierte Tool-Liste, Caption-Overlays, „Kommentiere X und ich schicke dir die Liste"
  als Lead-Hook — ist ein validiertes Muster für #52 (Echoel-Reels). → echoel-marketing.
**Kein App-Code-Impact. Höchster Wert: Reel-FORMAT für #52.**

### 2026-07-16 — YouTube-Vortrag Schmedding „KI Second Brains scheitern" (Founder-Upload, JSON-Summary)
Vision-Gate: trifft REPO-GEDÄCHTNIS + FOUNDER, nicht die App.
- **Validierung (kein Handlungsbedarf):** Sein Layer-5-Mapping empfiehlt für Coding-Agents
  wörtlich „LLM Knowledge Base, Bash/Grep-Navigation im Repo" = unser memory/+scratchpads/
  +CLAUDE.md-System; „Decision Logbook" = unsere decisions.csv. Sein Anti-Markdown-Verdikt
  zielt auf Enterprise-OPS, nicht auf Agent-Repos. EchoelAI N0-N4 (Registry+Tools statt
  Generic-RAG) = sein „use-case-specific pipelines"-Prinzip.
- **ADOPT-PIPELINE (billig, real): systematisches Vergessen.** Collector's-Fallacy trifft
  uns: ~65 PLAN_*-Dateien, viele supersedet → Attention-Verschmutzung. Hygiene-Zyklus:
  supersedete Scratchpads nach scratchpads/archive/ (Session-Start lädt nur Lebendes).
- **ADOPT-RITUAL (der schärfste Punkt): „Der Mann des Buches" = der Founder.** Ungeschriebenes
  Jahres-Wissen (EEG-Beispiel heute) ist der einzige echte SPOF. Ritual: jede erinnerte
  Alt-Planung sofort einwerfen → wird in Tasks + memory/ verankert (Tacit-Knowledge-Capture).
- **REJECT:** „Company Brain" als Produkt-Pivot — off-vision, Scope-Creep. Echoel bleibt Instrument.

### 2026-07-31 — DSPy (Founder-Einwurf: ein Wort, ohne Kontext)
Vision-Gate. **Schon bewertet** — `inspiration.csv:132` (2026-07-10) hat DSPy als einen von
zwölf Posten einer LLM/RAG-Stack-Liste mit REJECT geschlossen. Der Founder fragt es jetzt
EINZELN, also bekommt es eine eigene Zeile statt eines Verweises auf eine Sammelablehnung.

- **Tier: REJECT als Abhängigkeit · ALREADY-ADOPTED als Konzept.** Am Vier-Punkte-Tor
  scheitert es sofort an Punkt 2 (iOS-nativ auf dem iPhone machbar): DSPy ist Python,
  `Package.swift` hat `dependencies: []`, Prinzip 2 der Verfassung ist „open standards,
  near-zero dependencies". Das ist keine Geschmacksfrage.
- **Und der Pipeline-Ausweg trägt hier ausnahmsweise auch nicht** — was er sonst fast immer
  tut. Zwei harte Gründe: (a) ein Optimierer optimiert gegen ein Modell, das er ANSTEUERN
  kann; Apples On-Device-Foundation-Model ist aus Python nicht ansteuerbar, und gegen ein
  Cloud-Modell kompilierte Instruktionen auf ein ~3B-Gerätemodell zu übertragen ist
  unbelegbar. (b) DSPys ganzer Wert hängt an einer METRIK. Echoels tatsächliche Messlatte
  ist „klingt professionell" / „wow" — die Metrik ist das Ohr des Founders. Ohne Metrik ist
  ein Prompt-Optimierer nur ein langsamerer Prompt.
- **Das Konzept läuft längst, in Swift.** `ParameterDescriptor` (keyPath · Anzeigename ·
  min/max · Einheit · Wertelabels) IST eine typisierte Signatur; `ParameterToolCore` ist die
  modellfreie Werkzeuglogik getrennt vom Modell; das ADR-Gesetz „das Modell schreibt NIE
  direkt DSP-State" ist strenger als alles, was DSPy erzwingt. Die Trennung
  Programm-Struktur ↔ Prompt-Text war die eigentliche Idee, und sie ist adoptiert.
- **⛔ KORREKTUR AN DER ALTEN BEGRÜNDUNG (Zeile 132), und sie ist der Grund, warum dieser
  Eintrag nicht bloss ein Verweis ist.** Dort stand: *„Echoel ist ein Zero-Dep-iPhone-
  Instrument OHNE Server/LLM-Feature"*. Die erste Hälfte gilt unverändert. Die zweite wurde
  **zwei Tage später falsch**: am 2026-07-12 landete EchoelAI N0–N4 (Registry + BrainBackend/
  FoundationModelsBrain + ParameterToolCore). Das Urteil bleibt richtig, eine seiner beiden
  Begründungen nicht — genau das Muster, das dieses Repo „Mechanismus richtig, Begründung
  falsch" nennt. Nachgeprüft: `Sources/Echoelmusic/EchoelAI/` hat **null Produktions-
  Aufrufer** ausserhalb sich selbst, `FeatureFlags.echoelAI` ist default AUS, und
  `ParameterApplyRouter` hat keine gebundene Apply-Closure vom Modell her. Das LLM-Feature
  ist Gerüst, nicht Funktion — deshalb ändert es am Urteil nichts.
- **⭐ DER EINE ÜBERTRAGBARE GEDANKE, und er ist heute schon terminiert: BAU ZUERST DIE
  METRIK.** DSPys Lehre ist nicht der Optimierer, sondern dass ohne messbares Ziel gar nicht
  erst optimiert werden kann. Echoel hat genau eine Stelle, an der eine echte Metrik
  ansteht und mit ZERO Deps baubar ist: **#313 Slice 2** (BS.1770-Messbank über
  `EchoelLoudnessMeter` statt der Fünf-Skalar-Heuristik) — war blockiert hinter **#316** (die
  LUFS-Anzeige maß vor der Master-Kette, das Messgerät war selbst falsch). **ENTBLOCKT am
  2026-08-01 durch #316b**: der R128-Tap sitzt auf `AutoMixChain.chainOutputNode`, die vier
  Werte tragen den −1-dB-Trim zurück. Die Reihenfolge hat gehalten; die Sperre ist weg.
  Kein neuer Task, keine neue Abhängigkeit.
**Kein App-Code-Impact. Kein neuer Task. Höchster Wert war: #316 vor #313 — erledigt.**

## 2026-08-15 — herdr (github.com/herdrdev/herdr) — Founder: „Installieren?"
**Tier: WATCH (Founder-Workstation-Tooling, kein Echoel-Task).** Rust-Terminal-Runtime für
Coding-Agents (tmux-artig: Background-Server, Sessions überleben Deckel-zu/Neustart, Panes
mit working/blocked/idle-Status, Socket-API, Claude Code/Codex/Cursor als Gäste; Apache-2.0,
ein Binary, kein Electron). Nachgelesen im Shallow-Clone, nicht nur im README-Marketing.
- **Für DIESE Session-Infrastruktur: nutzlos.** Die 24h-Mandat-Sessions laufen remote
  (claude.ai/code, Container ephemer, Cron weckt) — Persistenz liefert die Plattform, ein
  lokaler Terminal-Server im Container stürbe mit ihm.
- **Für den Founder-Mac: sein Call, kein Repo-Belang.** Sinnvoll ERST, wenn mehrere LOKALE
  Agents in Terminals laufen sollen (der interessante Fall wäre ein lokaler Mac mit Xcode
  für Device-Builds — das wäre aber eine Infrastruktur-Entscheidung, nicht diese Zeile).
  Installation dann via `brew install herdr` (Homebrew-Formel existiert; dem
  `curl | sh`-Installer vorziehen).
- **App/Pipeline-Impact: null.** Keine Code-Abhängigkeit (Zero-Dep-Gesetz unberührt),
  berührt nie `Sources/`, auch nicht ContentPipeline.
**Kein App-Code-Impact. Kein neuer Task.**

## 2026-08-27 — IG-Reel @getintoai: „10 prompts … code with Claude" (Founder-Clip, ohne Text)
14,7-s-Screen-Recording eines Instagram-Carousels: zehn Persona-Prompts („Act as a senior
security engineer…", Tech-Lead-Modus, DevOps usw.). Gegen die Pipeline gescort, nicht gegen
das Produkt (der Clip handelt vom ENTWICKELN, nicht von Bio/Sound/Space).
- **REJECT (redundant), Zeile in inspiration.csv.** Jeder der zehn Prompts existiert hier
  als stärkeres, repo-spezifisches Werkzeug: Team-Fan-out mit Leads (ultracode-teams) statt
  einer Persona, spezialisierte Reviewer-Agents (audio-thread/security/ui-state/concurrency)
  statt „act as senior X", the-council als echter Tech-Lead-Modus (Sitze + Dissens),
  device-log-triage statt „production debugger", doctor/e2e-test-agent statt DevOps-Prompt.
  Der eigentliche Unterschied ist die MESS-Disziplin: Wächter + Python-Transkription + ehrliche
  Gate-Lesung — genau das, was generische Persona-Prompts nicht haben.
- Nr. 5 („rebuild messy code into clean architecture") widerspricht sogar `engineering.md`
  (kein unbeauftragtes Refactoring) — als Arbeitsanweisung hier verboten, nicht nur unnötig.
**Kein App-Code-Impact. Kein neuer Task.**

## 2026-09-11 — Founder-Paste: „Tropical Drones als Referenz-Modul" (Vorschlag einer ANDEREN KI)
Der Founder hat den Vorschlag einer anderen KI eingefügt (Drone-Bewegungsprofile als virtuelle
Kamera, audio-reaktives Fliegen via OSC an Resolume/Grapes, Aufnahme→Edit→Multi-Platform-Post +
Live-Streaming; dazu ein angebotenes „Grundgerüst": CMakeLists.txt + JUCE für Windows/Mac/Linux +
VST3/AU, ZeroMQ-Event-Bus, `/code/audio_engine.cpp`, `/inspiration/`-Ordner, `/docs/master_plan.md`).
Acht Teile EINZELN gescort — **nichts davon wurde gebaut**; acht Zeilen in `inspiration.csv`.
- **5× REJECT, und zwar nicht wegen Geschmack, sondern weil jeder Teil eine ausgesprochene harte
  Regel bricht, die das Repo schon einmal BEZAHLT hat:** JUCE/CMake/VST3-AU (JUCE ist PAID — genau
  dieses Gerüst wurde am 2026-06-19 entfernt, AUv3 am 2026-07-24 gelöscht: „neither a plugin nor a
  host") · ZeroMQ (zweiter Bus neben `EngineBus`, erste externe Abhängigkeit überhaupt, auf dem
  Audio-Thread unbenutzbar) · `audio_engine.cpp` (C++ ist erlaubt NUR gekapselt AUSSERHALB des
  Swift-Audio-Kerns; ein handgeschriebener Engine-Kern IST der Kern) · audio-reaktives VJ-Steuern
  (das ZIEL ist gebaut — Body→OSC→Resolume, `docs/dev/VJ_BRIDGE.md`; die QUELLE ist off-vision:
  Echoels Differenzierer ist „dein Körper spielt es", nicht „die Musik triggert das Bild", und
  `/audio/rms` + `/audio/pitch` wurden am 2026-07-04 als NIE-gesendet aus der Adressliste gestrichen)
  · Live-Streaming (am 2026-07-25 als Editor≠Workstation CUT, nicht Roadmap — Wiedereintritt braucht
  eine Founder-Bitte, keinen Plan).
- **1× REJECT-DUPLIKAT:** `/inspiration/` + `/docs/master_plan.md`. Das KONZEPT läuft hier seit
  Monaten und stärker (diese Datei + `inspiration.csv` + das `vision-gate`-Skill, mit Tier,
  Begründung und Review-Datum; Master-Plan = `docs/dev/PRODUCT_DEFINITION.md`). Eine ZWEITE Heimat
  für dasselbe Gesetz ist der #416-Fehler, den dieses Repo mehrfach bezahlt hat: die ältere Kopie
  gewinnt still.
- **1× ALREADY-ADOPTED:** Aufnehmen→Edit→Multi-Platform-Post. `ContentPipeline/` existiert seit
  2026-07-30 mit genau dieser Aufgabe, der PIPELINE-only-Regel und `CLAIMS.md` als Wahrheitsliste.
- **1× WATCH (review 2026-10-11) — das EINZIGE Stück mit echtem Wert, und es ist kein Code:** die
  BEWEGUNGSSPRACHE von Tropical Drones (langsam, weich geeast, durchgehend, nie ruckartig) als
  Qualitätslatte fürs kontemplative Visual — also Ship-Gate 4 („wow", kontemplativ). Umsetzbar OHNE
  3D-Kamera: `MetalBioView` ist ein Fragment-Feld, kein Szenengraph; die Entsprechung sind
  Easing-Zeitkonstanten und Drift-Raten. „Orbit" existiert bereits als Begriff im RAUM
  (`BioSpacePreset.breathOrbit`, ADM-OSC) — aber dieser Kern hat null Produktions-Aufrufer, ein
  Helix-Preset dort wäre türlos. Reihenfolge: erst Founder-Auge an einem Take, dann EINE Scheibe.
**Kein App-Code-Impact. Kein neuer Task.** Lehre für die nächste eingefügte Fremd-Empfehlung: ein
Vorschlag, der ein „Grundgerüst" ANBIETET, ist die teuerste Sorte — er klingt nach Fundament und ist
in diesem Repo dreimal ein Abriss (CMake/JUCE 06-19, AUv3 07-24, DAW-Hälfte 07-25). Gegen die
GESCHICHTE prüfen, nicht nur gegen die Regel.

## 2026-09-13 — Founder-Screenshots: 4-teiliger Purple-Cow-Prompt-Satz (Seth Godin)

Vier Karten ohne Begleittext, nacheinander geschickt: Rolle/Task/Steps/Rules/Context/Output je
Prompt. (1) „What's Making You Forgettable", (2) „What You've Been Downplaying", (3) „Turn It
Into Your Purple Cow". Fremder Autor, Marketing-Werkzeug.

**Tier: ADOPT→PIPELINE.** Nie in `Sources/`, nie in der App. Der Grund, warum es überhaupt
adoptiert wird statt beobachtet: die Kette arbeitet auf dem **WORTLAUT** statt auf
Branchen-Annahmen — dieselbe Disziplin, die dieses Repo ohnehin erzwingt („Base the diagnosis
on what I actually describe, not assumptions about my industry in general").

### Angewendet — drei belegbare Befunde, keine Meinungen

1. **Die H1 verletzt die eigene Marken-Regel.** `docs/index.html:636-639` sagt „Create from
   Within"; `CLAUDE.md` BRAND sagt hart *„NOT a wellness, soundscape, or therapy product"*.
   Das ist kein Positionierungs-Streit, das ist ein Widerspruch im eigenen Haus — auflösbar
   ohne jede Kundenstimme, indem die BEREITS AUSGELIEFERTE Store-Zeile dort steht.
2. **Die Ehrlichkeits-Mechanik ist vorn vollständig unterdrückt.** 34 Wächter im
   blockierenden Bundle lesen `docs/`, `fastlane/metadata` oder `CLAIMS.md` — der Build fällt,
   wenn die Werbung lügt. Gemessen trägt `index.html` „honest" **1×** und „claim" **0×**; die
   Sprache lebt auf `architecture.html`, `faq.html`, `terms.html`. Sie existiert, nur nicht
   dort, wo entschieden wird.
3. **Feld 3 des Prompts ist LEER.** „Was Kunden über mich gesagt haben" — `grep` über `docs/`
   und `fastlane/` findet **kein einziges Zitat**. Die ganze Methode steht auf dem, was andere
   sagen, und genau der Teil fehlt. Das ist der billigste offene Hebel nach dem
   TestFlight-Build von v10.79.472.

### Was daraus ein Vorhaben wurde

`docs/claims.html` — die ⛔-Hälfte von `ContentPipeline/CLAIMS.md` (360 Zeilen, 14 begründete
Streichungen, liegt fertig und unveröffentlicht) als öffentliche Seite, **aus der Fußzeile
verlinkt, nicht aus der H1**. Damit ist sie ein TEST der Position statt einer Wette auf sie:
wird sie geteilt, ohne dass der Founder sie geteilt hat, ist die Position verdient.

⚠️ **Risiko, benannt statt überspielt:** ohne eine dritte Spalte — *was tragend ist und nicht
entfernt wird* — liest sich eine öffentliche Streichliste als Instabilität für jemanden, der
eine Show um das Werkzeug herum plant. Die Spalte ist Teil des Vorhabens, nicht Zierde.

## 2026-09-13 — Founder-Ansage: „Nächster big step TestFlight für Watch"

**Tier: WATCH — messen statt bauen.** Kein REJECT: die Richtung ist Founder-Wille und deckt
sich mit dem Plattform-Ziel. Aber der Schritt ist kein Schalter.

Gemessen, nicht zitiert: Target **auskommentiert** (`project.yml:224`), **`import
WatchConnectivity` = 0** (die drei `WCSession`-Treffer sind der Warnkommentar in
`EchoelWatchApp.swift` selbst — genau die `EchoelModalBank`-Falle, ein `grep`, der seine eigene
Beschreibung trifft), und die Uhr liest den App-Group-Container **dieses Geräts**.

⛔ **Der Ausfall ist bauartbedingt STILL.** `refreshFromSharedStore()` gibt bei leerem Container
`nil`, die Uhr rendert den plausiblen Leerzustand „Start a session on iPhone." — **eine
verdrahtete Route, die nichts überträgt, sieht identisch aus wie eine unverdrahtete.** Ein
TestFlight-Build wäre eine Uhr-App, die installiert, startet, fertig aussieht und nie einen
Herzschlag zeigt.

⭐ **Der Wendepunkt:** Handgelenk-Herzfrequenz erreicht das Instrument mutmaßlich **heute schon**
über Apple Health — `HealthKitBioPublisher` ist live, der Store-Text behauptet es. Wenn das
stimmt, ist die Watch-App **Anzeige plus Latenz, keine Fähigkeit**, und der Umfang des Projekts
ändert sich um den Faktor zehn. Das wird im Code verifiziert, bevor irgendetwas geplant wird.

`WCSession` ist ein **neues Framework** ⇒ Council/Founder **vor** der ersten Zeile.

---

## 2026-09-17 — Instagram-Reel „I Don't Think You Should Build AI Agents Anymore" (cooper.simson)

**Eingang:** Founder-Upload, 30,8 s, 480×1042, ohne Begleittext, direkt nach dem
TestFlight-Deploy v10.79.473. ⚠️ **Hochformat heißt NICHT Echoel** — genau die Falle, vor der
`watch-clip` warnt und die am 2026-08-12 schon einmal drei Clips gekostet hat. Die Kontaktbogen-
Lesung kam VOR jeder Weiterleitung; es ist ein Reel, kein Gerätemitschnitt, also Inspiration
und kein Defekt.

**Die These:** statt Agenten zu bauen, eine **AI Delegation Loop** — `playbook` (ein `SKILL.md`
je wiederkehrendem Job) → `toolbox` (`files/`, einmal gebaut, jedes Mal wiederverwendet) →
`proof` (das Ergebnis prüft sich selbst, bevor es Dich erreicht) → **Deine Korrektur** zurück
ins Playbook. Zwei Betriebs-Details im Volltext lesbar: ein `files/INDEX.md` mit Dateiname +
Zweck + Datum, und die Prüffrage *„fahr den Job noch einmal von null und sag mir, welche
gespeicherten Dateien Du benutzt und welche Teile Du neu gebaut hast — alles Neugebaute ist ein
Kandidat für die Toolbox."*

**Tor-Urteil: ADOPT-PIPELINE, größtenteils schon da — und das ist die ehrliche Antwort, nicht
die bescheidene.** Die Schleife IST der Betrieb dieses Repos, und zwar strenger als im Reel:
Playbook = `CLAUDE.md` + zwanzig eigene `.claude/skills/*/SKILL.md` · Toolbox = `scripts/` mit
24 Werkzeugen · Proof = die acht Prüfer, das blockierende `Tests/CISmoke`-Bündel und
`doctor.py`, das fragt, ob die Messgeräte selbst lügen · Korrektur-Rückfluss = die
⛔-Rücknahme-Konvention, die den Irrtum **in das Gesetz zurückschreibt**, statt ihn zu löschen.
CLAUDE.md sagt das über sich selbst bereits: „Die zwei Muster, die schon unser Standard sind:
skill-architecture + markdown memory."

⭐ **GENAU EIN TEIL FEHLTE, und er ist übernommen (#1359): das `INDEX.md`.** Gemessen standen
**zwei** der 24 Werkzeuge in KEINER Anweisungsdatei — `window-margins.py` und
`doorless-state.py`, `git grep` über `CLAUDE.md`, `.claude/**` und `Tests/CISmoke/CLAUDE.md`,
null Treffer für beide. ⛔ Die erste Fassung sagte DREI und zählte `needle-reachability.py` mit;
das steht sehr wohl in `Tests/CISmoke/CLAUDE.md` §#808. **Eine Aussage über einen Nachbarn ist
eine MESSUNG** — dasselbe Gesetz, das #1358 sich gerade in den Wächter-Kopf geschrieben hat, und
es ist im selben Tag noch einmal fällig geworden.

⚠️ **Bewusste Abweichung vom Reel:** dessen Index nennt Dateiname + Zweck + Datum. Hier ist die
tragende Spalte **WANN man das Werkzeug holt**, denn man sucht ein Werkzeug, das man nicht
kennt — eine Beschreibung findet nur, wer schon weiß, wonach er sucht.

**Was ausdrücklich NICHT übernommen wird:** die Agenten-Rhetorik und das „delegiere den ganzen
Job"-Framing. Dieses Repo delegiert keine Entscheidungen an eine Schleife; es schreibt sie
begründet auf und lässt sie prüfen. Kein Byte in `Sources/`, keine Abhängigkeit, kein
Agent-Framework — Pipeline-only, wie jede Skill-Inspiration davor.

**Nebenbefund, NICHT in dieser Scheibe repariert:** `inspiration.csv` hat **13 fehlerhafte
Zeilen** (Index 108 mit 9 Spalten, 140–151 mit 7 statt 8) — ein unmaskiertes Komma und eine
fehlende Spalte. Die Datei ist die, die `vision-gate` liest. Eigene Scheibe.

## 2026-09-18 — „Code Guardian repo skill installieren?" (Founder-Frage)

**Erstes Ergebnis der Recherche: „Code Guardian" ist nicht EIN Ding.** Mindestens fünf
verschiedene Projekte tragen den Namen — `dam-agents/code-guardian` (PR-Review-Agent auf der
Claude-Code-Harness), `Nitishjha7/code-guardian`, ein CodeGuardian-**MCP-Server** (11 Werkzeuge,
Qualität + Security), **Code Guardian Studio** (113+ MCP-Werkzeuge, „AI safety layer", open-core),
und **Project CodeGuard** (CoSAI/OASIS, Security-Regelwerk). „Installieren wir Code Guardian" ist
also keine wohldefinierte Handlung, und das ist der erste Befund, nicht die Einleitung.

**⚠️ ABDECKUNG, weil eine Empfehlung ohne sie keine ist:** von fünf Kandidaten konnte ich DREI
lesen. `codeguardian.studio` und der InfoQ-Artikel über den MCP-Server sind vom Egress-Proxy
blockiert (`EGRESS_BLOCKED`) — über diese zwei weiß ich nur, was Suchtreffer-Schnipsel sagen, und
darauf gründet hier keine Empfehlung.

**Der entscheidende Befund ist aber gar keiner ÜBER Code Guardian, sondern über dieses Repo:**
der wahrscheinlichste Kandidat reviewt PULL REQUESTS, und **dieses Repo hat keinen PR-Fluss
mehr.** Gemessen: neuester PR **#419, geschlossen 2026-08-26**; einziger offener **#399 vom
2026-02-17** (sieben Monate alt); **233 Commits** sind seither auf `main` gelandet, jeder einzelne
per `auto-merge-claude.yml` DIREKT gepusht. Ein PR-Reviewer hätte null Gegenstand. Das ist keine
Geschmacksfrage und kein Vorwurf an das Werkzeug — es ist die Frage, ob der Haken in die Wand
passt, und sie wird mit zwei API-Aufrufen beantwortet.

**Was das Repo statt dessen schon hat**, und warum die Lücke woanders liegt: 526 blockierende
Wächter, 16 Prüfskripte, und die `doctor`-Skill, die etwas prüft, das KEINER der fünf Kandidaten
anbietet — ob die MESSGERÄTE ehrlich sind (maskierte Gates, veraltete Kommandos, türlose Flächen,
gedriftete Zahlen). Ein externer Reviewer prüft den Code. Dieses Repo hat bereits zweimal teuer
gelernt, dass sein Problem die Ebene DARÜBER ist.

⭐ **Und die Kosten, die kein Anbieter nennt: KONTEXT ist hier die knappste Ressource.** Die
immer geladene Fläche ist **166 414 B** (`CLAUDE.md` 149 182 + drei Regeldateien), Autocompact
feuert bei 50 %, und `TheLawFileStaysUnderItsCeilingTests` hat eine Decke von 150 000 B auf
`CLAUDE.md` allein — 818 B Kopfraum. Ein MCP-Server mit 11 oder gar 113 Werkzeugen schreibt seine
Schemata in JEDE künftige Anfrage JEDER künftigen Sitzung. Das ist der Posten, der in keiner
README steht und der hier am meisten wehtut.

**Verdikte** (Zeilen in `inspiration.csv`): `dam-agents/code-guardian` = **REJECT** (kein
Gegenstand; dazu 1 Stern, 0 Forks, und er verlangt ein Bot-Konto mit `repo`-scope als
Collaborator). `cosai-oasis/project-codeguard` = **WATCH** (echte Governance, 338 Sterne,
CC BY 4.0, Markdown-Regeln statt Abhängigkeit — aber seine Themen sind Krypto, Auth,
Supply-Chain, Cloud, und Echoel hat null Server, null externe Deps, keine Auth und genau EINEN
Netz-Eingang. Als LESESTOFF für den OSC-Steuerempfänger und die Entitlements wertvoll, nicht als
Installation.)

⚠️ **Was WIRKLICH fehlt, und es ist nicht das, was Code Guardian verkauft:** `auto-merge-claude
.yml` wartet auf KEIN Gate (#683) — kein `needs:`, kein `workflow_run:`, keine fremde Conclusion.
#681 ist am `Xcode Compile Check` gescheitert und stand trotzdem auf `main`; `d78b249` stellte ein
nicht bauendes Test-Bündel dort ab (#1337). Das repariert kein Reviewer, sondern eine Zeile
`needs:` — und die ist **founder-gated** (`.github/workflows/**` = berichten, nicht editieren).
Ein PR-Review-Agent auf einen Fluss ohne PRs zu setzen, während der eigentliche Defekt eine
ungeprüfte Direkt-Push-Route ist, wäre ein Schloss an einer Tür neben dem offenen Fenster.

## 2026-09-26 — Zwei ChatGPT-Mockups der Oberfläche (Founder: „du bist der wahre magische Designer")

**Verdikt: ADOPT→PRODUCT, teilweise — als Inspiration, nicht als Spezifikation.** Das Telefon-Mockup
zeichnet zu großen Teilen, was schon ausgeliefert ist (Selected-Part-Leiste mit Earlier/Later/Trim/
Split/Duplicate/Delete, „Play from here", Media Library mit Place/Relink, Add/Import-Türen,
Track-Inspector). Übernommen wird nur, was eine AUSGELIEFERTE Fähigkeit lesbarer oder zugänglicher
macht, je eine Scheibe mit Wächter:
- **D1** Song-Position „Bar 12 · Beat 3" neben Play/Stop, eigenes Blatt (`SongPositionReadout`, e1036b874).
- **D1b** die Caption sagte „from the top" auch beim Start aus einem Teil — jetzt nennt sie den Start-Takt (b91cdcdf0).
- weitere Scheiben aus einem Lese-Zensus Mockup ↔ Code (MODES_CENSUS § Design).

**REJECT:** „MUSIC FOR A CALMER WORLD" (wellness-nah) · AI Assist (`FeatureFlags.echoelAI` ohne
Leser) · Drum-Anmutung (#167) · „Arm for recording" als Mikrofon (#1302) · Neon/Glow (Uncodixfy).
**PAUSIERT (Founder-Frage 4):** die Tablet-Domänen-Tabs Visual/Spatial/Light/Stream/XR; iPad als
Instrumenten-Fläche (v1.0 = iPhone, Sensor-Grund). Zeile in `inspiration.csv`.

## 2026-09-28 — Instagram-Reel „Anthropic's AI-Native SDLC Playbook" (@aiwithbuntyshah)

Founder-Upload, 51,6 s, 14 Einzelbilder gelesen; Ton ohne Transkript, eingebrannte Untertitel nur bruchstückhaft. Der zitierte Blogpost (claude.com/blog, Aug 2026) ist von hier nicht prüfbar; die Wochenzahlen nennt das Reel selbst „illustrative".

- **Schon da (keine Übernahme):** CLAUDE.md als Team-Regeln · Skills als Regel-Schicht · Datei-Spur je Stufe (PLAN_*.md, EXECUTION_CHECKPOINT, decisions.csv, SESSION_LOG) · Check-Fix-Schleife (Ralph + sieben Prüfskripte) · Reviewer-Agenten.
- **ADOPT-PIPELINE-Kandidat, Founder entscheidet:** Schicht 2 „Hooks, die blockieren". Gemessen: `.claude/settings.json` trägt nur einen SessionStart-Hook. Die founder-gesperrten Pfade sind reine Prosa — genau der Fall „one slips past" aus dem Reel. Ein PreToolUse-Hook auf Edit/Write für `.github/workflows/**`, `project.yml`, `Resources/iOS/Info.plist`, `.deploy/release` wäre die kleinste Übernahme.
- **WATCH:** „Autor gibt nicht frei" — Agenten-Code erreicht main per Auto-Merge nach zwei Gates; menschliche Freigabe sitzt bei TestFlight/Gerät (#1405, bewusst). **WATCH:** Geräte-Monitoring — MetricKit kommt in `Sources/` nicht vor; wäre Produktcode, nicht in einer Reparaturrunde.

## 2026-09-30 — Organuhr-Tabelle + Deep Research „Frequenzen und Stimulationsmuster" (Adey, Weltraummedizin, auditiv)

Founder-Upload einer TCM-Organuhr-Tabelle (Tageszeit → Organ → Frequenz/Stimmung) mit dem Auftrag, die effektivsten Frequenzen und Stimulationsmuster zu recherchieren. Drei Recherche-Agenten; Ergebnis als Tab „Evidenz" im Audit-Doc. ⚠️ Methodische Grenze: der Proxy blockierte JEDE Fachdomäne — Noten aus Abstract-Zitaten, kein Volltext; vor jeder Store-/Web-/Panel-Zeile am Founder-Mac gegenlesen.

- **REJECT — Organ → Frequenz (Hz):** keine kontrollierte Studie zu irgendeiner Zuordnung, die Tabellen widersprechen sich (Grad D); im Produkt die Heilungs-Rote-Linie.
- **WATCH — Tageszeit als Default-Kurve** (Tempo, Blauanteil, Presets): Zirkadianik real (B), Organ-Stunden nicht (D). Reine Gestaltungsentscheidung ohne Gesundheitswort, T1-Log als Nutzer-Geste. Review 2026-12-29, erst nach den fünf offenen Audit-Entscheidungen.
- **REJECT — Adey-Fenster:** in vitro nur in Original-Laboren repliziert (C), Übertragung auf Schall/Licht/Haptik nirgends gezeigt (D). Name nirgends in Copy.
- **ADOPT-TEILWEISE — Weltraummedizin:** Abendmodus des Visuals (HERA/ISS-Lichtschema, B) · Atem-Pacer-Default 6/min (HRVB A auf der Erde) · ruhige Presets 60–80 BPM, Stille, 10-s-Phrasen (Bernardi, B) · Haptik nur als Cue. REJECT: Vibrationstherapie am Gerät (Taptic ~230 Hz, 0,003–0,15 g gegen LIV 30 Hz/0,3 g stehend), 40-Hz-Lichtflimmern (3-Hz-Decke, Soula 2023 ohne Replikation). WATCH: Vibroakustik nur als externer Ausgang.
- **REJECT — auditive Wirk-Claims:** binaural (C/D), isochron (D), 432/528 Hz (D, Brand-Verbot). 40-Hz-AM auf Audio ist messbar (ASSR, B) und blitzfrei — allenfalls Klangfarbe, nie Kognitions-Claim.
- **Die eine Zeile:** genau EIN Reiz hat Grad A und ist auf dem iPhone lieferbar — Resonanzatmung ~6/min. Gebaut. Alles andere heißt „Klanggestaltung", nie „Wirkung". Fünf Zeilen in `inspiration.csv`.
- **Nachtrag (KI-Text „belegte Wirkfrequenzen" + Deep-Dub/Lo-Fi-Blueprint, Founder-Einfügung):** Gegenlesung im Evidenz-Tab. Physiologie meist echt, Evidenznote ein bis zwei Stufen zu hoch (40 Hz klinisch C, 10-Hz-Cortisol C, Theta-Entrainment D, Vibroakustik C und nicht am Telefon, 100–200 Hz echte Gate-Control-Physiologie, aber Kontakt am Schmerzort + Rote Linie). Drei Physikfehler: 40-Hz-Sinus ≠ 40-Hz-AM; Binaural nur per Kopfhörer; ein Filter-LFO synchronisiert keine Atmung — der Pacer schon, also **Atem → Filter, nicht umgekehrt**. Heute schon möglich: `ModSource.breathPhase` → Cutoff per Matrix, Genres `dubTechno`/`dubEcho`/`loFiHipHop`/`trap`, `SubBassVoice`. **WATCH:** Hybrid-Genre 110–116 BPM + voreingestellter Atem-Filter-Weg als reine Klanggestaltung, Genre-Runde (Founder-Ohr). Keine Behauptung erreicht Store/Web/Panel. Zeile in `inspiration.csv`.

## 2026-10-01 — Tablet-Workstation-Entwurf (ChatGPT, erneut angehängt) + Auftrag „Workstation ernsthaft vertreten“

**Verdikt: ADOPT→PRODUCT, scheibenweise.** Founder wörtlich: „Gestalte alles so um, dass ich Echoelmusic
als Workstation ernsthaft vertreten kann.“ Damit sind zwei PAUSIERTE Punkte vom 2026-09-26 entschieden:
Genre ist nicht mehr die Kopf-Bedienung (→ „Stil“ am Echoel-Gerät) und die Bereichs-Tabs sind gewollt —
**Music · Visual · Light · Space**; Stream und XR bleiben REJECT (unverlinkt / kein Target).
Plan mit fünf Audits und Reihenfolge A1–A9 · B1–B6 · C1–C5: `scratchpads/PLAN_WORKSTATION_REDESIGN_2026-10-01.md`.
iPad als Instrumenten-Fläche bleibt founder-gated (`project.yml`, Sensor-Grund).


### 2026-10-09 — ChatGPT/Astra: „Von ‚Ich höre etwas‘ zu ‚Das habe ich gestaltet‘“
- Quelle: Founder-Prompt (Claude-Auftrag), Modell sah das Repo nicht. [verified 5/6]
- Gemessen: `BioComposer.liveliness` (Dichte) + Mood-Regler „Liveliness“ ✓ · „Edit a copy“/Keep (GA-2a/b) ✓ · `TimelineStore.undo/redo` ✓ · Demo-Quelle ✓ · `BreathGuideView` nur in türloser `BioSourceView` ✓ · Vorher/Jetzt-Vergleich ✗ (neu).
- Verdikt ADOPT-PRODUCT, EINE Scheibe: Einstieg A (hören → Bewegung → vergleichen → behalten) aus vorhandenen Teilen, plus A/B-Vergleich. Rest (Anfang·Entwicklung·Ende, Handschrift, Körper-Zuordnung) WATCH bis Einstieg A am Gerät getestet ist. Drei Founder-Fragen offen.

### 2026-10-10 — ChatGPT/Astra: Siri-Sätze für „take.keep" und „Vorher/Jetzt"-Vergleich
- Quelle: Claude-Auftrag (`reports/Auftrag Astra – Siri-Sätze und Vorher-Jetzt.md`), Modell sah das Repo nicht. Säuberung leer. [verified 3/6]
- Widerlegt: Sprechname ist „Echoelmusic", nicht „Echoel" · „take" ist im Glossar gestrichen · kein deutscher Katalog, also keine deutschen Siri-Sätze.
- Bestätigt: „Save" meiden · der Vergleich braucht einen festgehaltenen Vorher-Stand, den es nicht gibt · Abhören ohne Undo-Schritt.
- Verdikt: Sätze ADOPT-PRODUCT, neu formuliert nach dem Knopf „Edit a copy" (AI-6b, 921419dde). Deutsch WATCH (Lokalisierung #232). Vergleich WATCH bis GM17. Die vorhandenen Fehlertexte bleiben, weil sie sagen, was zu tun ist.

### 2026-10-10 — Unbekanntes Modell (wohl Gemini): „Baustellen im Repo“ + KI-Panel
- Quelle: Founder-Einfügung, Modell sah das Repo nicht und nennt sich nirgends. Säuberung: ein Variationsselektor (Emoji), sonst leer. [verified 0/6]
- Muster: keine Behauptung stimmt so, wie sie dasteht, aber fünf von sechs nennen ein echtes Thema mit veraltetem Weg — es erinnert sich an BLAB-Altmaterial, es erfindet nicht. Mein erstes Urteil („alles erfunden“) war zu hart; drei Prüfer haben es korrigiert.
- Echt und schon in Arbeit: offener ADM-BWF-Immersive-Master mit Trajektorien (ADR-007, S-A), Grapes über ADM-OSC, Binaural über Apples HRTF (Tür „Headphone space“, Gerät offen), Self-Healing als SH-Spur. Falsch: Live-Python-Brücke, Dolby-Etikett, Dante bauen, autonome Code-Reparatur, Vagus-Modulation als Funktion.
- Nebenfund und einzige Folge: zwei Website-Seiten nannten „Dolby Atmos“ gegen ADR-007 §9 — korrigiert; F-E steht jetzt als H19 in `docs/dev/FOUNDER_INBOX.md`. Nichts aus dem Text geht in Code.
- Regel für Fremdmodelle: nur Prüfer-Sitz (MASTER_PLAN §12), nie Bauer; nie Diagnose-Log (Puls), Schlüssel oder private Daten weitergeben.

### 2026-10-11 — DeepSeek: Monorepo „Apple first für alle Plattformen“ + „Issue #1 Water Reminder“
- Quelle: Founder-Chat, DeepSeek sah das Repo nicht. Säuberung beider Texte leer. Gebrieft wurde DeepSeek danach mit öffentlichen Repo-Fakten und einer kleinen Prüf-Aufgabe (Plattform-Reihenfolge, ≤ 8 belegte Punkte, kein Code).
- Monorepo [verified 5/12]: fast alles schon da (Architektur, EINE Roadmap, CI, Swift-Kern); Ordnerumbau abgelehnt. Die Messung fand aber vier echte veraltete Stellen bei uns (Plattform-Zeiger, ADR-004-Linux-Gate, fehlende Watch im Plan, „3 SPSC topics“) — umgesetzt, plus die neue Lernmodus-Regel „Was RAUSGEHT“.
- Wasser-Erinnerung [verified 2/8]: als Echoel-Funktion REJECT (kein Wellness, kein Ton außer Musik, Bühnenrisiko); der Code tut nicht, was seine Kriterien sagen. Die Fürsorge-Absicht ist echt; der Weg dafür ist Erinnerungen-App + Fokus, ganz ohne Code.
- Muster DeepSeek: warm und hilfsbereit, aber ohne Repo rät es den Stack und schreibt sofort Code. Gut nutzbar als Prüfer mit enger, belegpflichtiger Bitte; nie als Bauer.

### 2026-10-11 — Mistral (Vibe-App): Repo-Review „technisch sauber, Risiko Coding-Agent“ + Issue #418
- Quelle: Founder-Einfügung; das Modell las die öffentliche GitHub-Seite und das README, nicht den Baum (das zeigt sich daran, WO es falsch liegt). Säuberung leer. Drei Messer + Lead, `wf_831a2ccb-122`. [verified 13/21]
- Bestätigt: EngineBus `@MainActor @Observable` + lock-free SPSC · vier Bio-Quellen, BLE über `CBUUID("180D")` ohne SDK · OSC/ADM-OSC/Art-Net/sACN/MIDI in `applyRouting` (opt-in je Route) · Watch-Target nicht eingebettet · MPE-Eingang fehlt, README sagt es · 0 Stars/Forks · Commits ~89 % Claude (GitHub-API, 9 484 Commits) · die geschützte Triade hat je EINEN Commit, von Claude, ohne PR — nie von einem Menschen geprüft.
- Teilweise: „SPSC für den Audio-Thread“ — beide Queues werden auf dem MainActor gefüllt UND geleert, der Render-Block liest Spiegel · LICENSE: unter dem MIT-Text hängt ein Drittlizenz-Block mit „HaishinKit = einzige Dependency“ (falsch) → GitHub meldet `NOASSERTION` · „fair and sensitive Plattform“ steht nur in der GitHub-About-Beschreibung (mit „Wellbeing“ — gegen die Markenregel), nirgends im Baum.
- Widerlegt: „EchoelAI ohne Production-Caller“ (seit `0c164c516`: Siri → `EchoelAgentDesk`, `AgentReportBanner` in `WorkspaceView:265`) · „Upload-Fehler der App“ (0× URLSession/MetricKit; der Platzhalter ist GitHubs Web-Anhang; den Dateinamen `echomusic_crash_…` erzeugt kein Code) · „erst schmal shippen institutionalisiert“ (FOUNDER_PRODUCT_LAW :7/:83 sagt das Gegenteil; „schmal“ bleibt nur als Release-Reihenfolge).
- Schärfster eigener Befund: der Diagnose-Export trägt Pulswerte (`bpm=` in `CameraRPPGBioPublisher` ~:1475 je Status-Tick, `EchoelStudioView:10025`), und weder `SafeModeView:86` noch das Diagnostics-Sheet (`EchoelStudioView:9454`) sagen es — während die Owner-Antwort auf #418 einen Fremden bat, den Log ÖFFENTLICH anzuhängen. ADOPT→PRODUCT als EINE Scheibe (Offenlegung aus EINER Konstante, kein Schwärzen, Wächter), Council einberufen.
- Erledigt (ADOPT→PIPELINE, dieser Commit): README :24 (unbelegte „Polar H10 validation“ / „DELLY / Tracy“ gestrichen), :89 (drei Wege zu TestFlight), :132-136 (EchoelAI 6 Dateien + Aufrufer, Stream 7 Dateien, `MicrophoneManager` weg); FEATURE_STATUS Agent-Zeile; CLAUDE.md: `ParameterToolCore` liegt in `EchoelAI/`, nicht `Core/`.
- Founder-gated, in `docs/dev/FOUNDER_INBOX.md` nachzutragen: GitHub-About ersetzen · LICENSE-Anhang in `THIRD_PARTY_NOTICES.md` · #418 „needs info“ schließen und die Antwort korrigieren (der Share erzeugt TEXT, keine Datei) · PR #399 · die Tabelle BIO-SIGNAL DSP in CLAUDE.md gegen den Code (kein k-means; DELLY/Tracy sind nach Modellwissen Genomik-Werkzeuge — im Repo UNVERIFIZIERT) · Fach-Review auf den LEBENDEN Bio-Pfad (rPPG, HRVCoherence, Respiration), nicht auf die zwei Kerne ohne Aufrufer.
- REJECT: Upload-Pfad bauen (neuer Netzwerkweg für Gesundheitsdaten) · pauschal „einplanen oder löschen“ (#527-Falle) · das Angebot, Issues anzulegen (Schreiben auf GitHub gehört dem Founder).
- Muster Mistral/Vibe: wohlwollend und meist richtig, wo es Code las; übernimmt veraltete README-Zeilen als Befund. Als Prüfer mit Ausschnitten brauchbar (siehe Brief `briefs_2026-10-11/Mistral.txt`), nicht als Leser der GitHub-Seite.
- Nebenbei: der Gemini-„Baustellen“-Text vom 2026-10-10 wurde am 2026-10-11 ERNEUT eingefügt — keine neue Zeile (Regel 4: einmal loggen); das Urteil [verified 0/6] REJECT bleibt.

### 2026-10-11 — Founder: „World UNITY“ — Werte-Statement durch den Vision-Gate (`wf_7ab06b71-143`)

## Founder-Worte 2026-10-11 — „World UNITY" (gelesen durch den Vision-Gate; Stand `5bc17bc6b`)

> „World UNITY Friedensabkommen über sanften und lächelnden Handel. Alles werden involviert und lernen zu verzeihen. Oberstes Gebot Transparenz und Volkswirtschaftliche Ökonomie wie sie alle gerne hätten. Vermeide BigPlayer Monopolistische Einseitigkeit ohne Regenwälder, Tiere und Menschen zu zerteilen. Vermeide das dringenst. Wir starten mit Airbus bei den Tauchfliegen und enden mit Echoelmusic als neue Musikschule, die Vegane Musikbetriebene Brötchen backt."
> — Echoel (Michael Terbuyken), 2026-10-11, wörtlich.

Lesart: das sind WERTE dafür, WIE Echoel gebaut und gehandelt wird, plus EINE Richtung („Echoelmusic als neue Musikschule" = Musik durch den Körper lernen). Airbus/Tauchfliegen und vegane Brötchen sind Stimme des Founders, keine Spezifikation — kein Code-Gegenstück, keines gesucht.

### Was davon schon Code ist (nachgemessen, kommentar-bereinigt)
- **Transparenz:** MIT-Lizenz (`LICENSE:1`); Privacy-Seite „runs no servers and receives nothing" (`docs/privacy.html:116`); Store-Text „no accounts, no ads, no tracking" (`fastlane/metadata/en-US/description.txt:45`); kein HTTP-Client in der App: `git grep -n 'URLSession\|URLRequest' -- Sources | grep -v ': *//' | wc -l` → 0.
- **Kein Lock-in / kein BigPlayer:** `Package.swift:66-73` `dependencies: []`; offene Protokolle `Sync/OSCSender.swift:92`, `Sync/ADMOSCSender.swift:60`, `Sync/ArtNetSender.swift:33`, `Sync/SACNSender.swift:35`, `Audio/MIDIOutput.swift:36`; offene Formate `Audio/SingleExport.swift:29` (`wav, aac`), MIDI-Export-Tür `Studio/EchoelStudioView.swift:2481`.
- **Sanfter Handel:** v1.0 kostenlos, keine Kauf-UI — `Studio/WorkspaceView.swift:156-163` (Founder 2026-07-10); `git grep -n 'ProUnlockView(' -- Sources | grep -v ': *//'` → 0 Produktionsaufrufer.
- **Gesundheitsdaten bleiben im Gerät:** `Core/BioEgressPolicy.swift:8-12` (HealthKit-Frames erreichen keinen Netzsender), `:117-118` klinische HRV-Details OPT-IN, default aus.
- **Alle werden involviert:** `Studio/LearnLibrary.swift:128-137` Karte „For every body" (hören · sehen · fühlen); `Core/FlashGuard.swift:45` `maxFlashHz = 3.0`; Simulationsquelle `Studio/BioSourceOption.swift:58`; 252 `accessibilityLabel(`-Stellen (`git grep -n 'accessibilityLabel(' -- Sources | grep -v ': *//' | wc -l`).
- **Ressourcen schonen (die einzige „Ökologie" im Code):** `Core/AdaptiveQuality.swift:3-16`, `Core/ResourceGovernor.swift:3-14` — Akku/Thermik steuern Detailstufe und Poll-Rate. Kein CO₂-/Footprint-Konto existiert (`git grep -n -i 'carbon\|co2\|footprint' -- Sources docs/*.html | grep -v ': *//'` → nur ein Fehltreffer).
- **Musikschule, der Keim:** `Studio/LearnLibrary.swift:1-6` („the single index behind the ‚app as a school' idea"), sechs Sektionen `:16`, Tür `Studio/WorkspaceView.swift:600` → `Studio/EchoelStudioView.swift:1337` → `.sheet` `:1814`; Start-Tour `Studio/GuideOverlay.swift:43` aus derselben Quelle; Compose-Walk `Studio/ComposeGuide.swift:33`; Theorie-Primer `Studio/MusicTheoryPrimer.swift:16`.

### Was davon Haltung ist (Praxis, kein Feature, in Copy nur als „so arbeiten wir")
Transparenz · fairer Handel · kein Monopol/Lock-in · alle inbegriffen · **„lernen zu verzeihen" = Korrektur ohne Schuld** — das Repo praktiziert es wörtlich: 91 ⛔-Vermerke auf 77 Zeilen allein in `CLAUDE.md` (`grep -o '⛔' CLAUDE.md | wc -l` / `grep -c '⛔' CLAUDE.md`), die falsche Behauptung bleibt neben ihrer Korrektur stehen; Sackgassen im `scratchpads/HARNESS_LEDGER.md`, Supersessions in `decisions.csv`. Das ist eine Arbeitskultur, kein Nutzer-Feature und keine Produktaussage.

### Was davon NIE Kopie wird (Wirkungen)
Frieden, Weltfrieden, Einheit, Verzeihen, Heilung als WIRKUNG des Produkts — in Store-Text, Website, In-App-Kopie und Content. Gründe sind hart, nicht geschmacklich: Prinzip 3 oben („Show the number, never promise the benefit"), BANNED-Liste (`memory/vision.md:122-124`), `CLAUDE.md` BRAND („NOT a wellness, soundscape, or therapy product"), `ContentPipeline/CLAIMS.md:153-155` §2, App-Store 2.3 (#184) und die FDA-General-Wellness-Linie (`memory/vision.md:118-120`). Der Master-Prompt des Founders vom 2026-10-07 („Weltfrieden, Heilung oder Therapie als Wirkung" verboten) ist seit `cc80127c5` im Baum zitiert: `reports/Orchester – ein Kopf, fünf Aufträge (2026-10-11).md:5, :27, :65`. „Vegan" und „Regenwald" sind keine Produkteigenschaften der App — es gibt keine eigene Lieferkette; der ehrliche Satz lautet „akku- und wärmebewusst gebaut; keine Footprint-Aussage".

### Richtung Musikschule (Tiering)
- **ADOPT → PRODUCT (Tier 1, jetzt): „From pulse to piece"** — siebte Start-Here-Karte in `LearnLibrary.guideEntries`, die den Körperpfad in Lern-Reihenfolge erzählt und nur ausgelieferte Bedienelemente wörtlich nennt (Play → Finger auf Rückkamera → Tempo-Feld unter „Tempo & variations", Flow folgt dem Puls / Lock für festen BPM → „Key"/„Scale" auf der Piece-Platte → fünf Schritte der Arrange-Karte → Export „MIDI"). Kopie-only, reversibel, erbt `TheGuideNamesOnlyRealControlsTests` und `testTheGuideMakesNoHealingClaim`. Die strukturelle Lücke, die sie schließt: heute erklärt die Guide-Seite den Puls auf der Instrument-Bühne, der Compose-Walk beginnt bei „Add a MIDI track" auf der Arrange-Bühne, und nichts verbindet beides als EINEN Weg.
- **WATCH (nächste, nach Founder-Blick auf Scheibe 1): „Your piece, right now"** — in `LearnView.entryDetail` (eigenes Blatt, `Studio/LearnView.swift:151`) unter `music.key`/`music.scale`/`music.tempo` eine Zeile mit Tonart, Skala und BPM des laufenden Stücks aus `SessionContext` (`Core/SessionContext.swift:141/146/196`, 8 bestehende `@Environment`-Leser) und `BeatPlayer` (13 Leser); nur im Detail-Blatt lesen, nie in `list` (`:41`) — Tempo glidet bis ~20 Hz. Neuer Wächter nötig; erst nach Scheibe 1.
- **WATCH / Founder-Frage:** Lektionen, Fortschritt, Übungen, Lehrer/Schüler-Rollen — Curriculum existiert nicht; jede Fläche dafür läuft über `docs/dev/FOUNDER_PRODUCT_LAW.md` und die WA-Reihenfolge des Master-Plans (WA3 zuerst). Deutsch als Unterrichtssprache ist eine vom Founder zurückgenommene Entscheidung (`docs/dev/FOUNDER_INBOX.md:53`, E4 „Nur Englisch") — kein Slice, nur eine Frage.
- **Öffentlich bleibt „Musikschule" UNBEHAUPTET** — richtig so: ein Satz über die In-App-Learn-Bibliothek wäre wahr, ein „Kurs"/„Schule"-Versprechen nicht (`grep -ic learn docs/claims.html` → 0, `ContentPipeline/CLAIMS.md` hat keine Learn-Zeile).

#### Die Haltung in Worten (Entwurf; Manifest-Text, NIE Produktkopie)

HALTUNG (so wird Echoel gebaut und gehandelt — keine Wirkungsversprechen)
Echoel ist ein Instrument, bei dem Herzschlag und Atem Klang, Bild, Licht und Raum mitspielen. Wir bauen es offen und nachprüfbar: der ganze Code liegt unter MIT-Lizenz öffentlich, jede Zahl im Repo steht neben dem Befehl, der sie misst, und ein Fehler wird nicht gelöscht, sondern datiert stehen gelassen und korrigiert (⛔-Vermerke) — Korrektur ohne Schuldzuweisung ist unsere Arbeitsweise.
Wir binden niemanden: null fremde Bibliotheken, alle Ausgänge sprechen offene Standards (OSC, ADM-OSC, Art-Net, sACN, MIDI), Export in offene Formate (MIDI, WAV, AAC), keine Konten, keine Server, keine Werbung, kein Tracking; Puls- und Atemwerte bleiben auf dem Gerät, Gesundheitsdaten verlassen das Telefon nie.
v1.0 ist vollständig kostenlos und es gibt nichts zu kaufen; eine spätere Einnahme wird offen und kündbar angekündigt, nie über dunkle Muster.
Alle sollen mitspielen können: hören, sehen oder fühlen — jeder Kanal ist ein eigener Zugang, VoiceOver und Systemschriftgröße werden bedient, Blitzlicht ist auf 3 Hz begrenzt, und eine Simulation spielt auch ohne Sensor.
Biofeedback ist hier eine gemessene Steuerquelle, kein Wellness-, Meditations- oder Therapieprodukt. Wir zeigen die Zahl und versprechen keinen Nutzen: keine Heilung, keine Diagnose, kein Weltfrieden als Wirkung. Gemeinsam spielen ist eine künstlerische Erfahrung, kein Versprechen. Als wahr gilt nur, was im Code steht und gemessen ist.

#### Die eine Scheibe

EMPFOHLENE SCHEIBE: „From pulse to piece" — eine siebte Start-Here-Karte (Größe S, Kopie-only, 3 Dateien, kein neuer Typ, null Präsentations-Modifier, kein Hot-State).

Was: `LearnEntry(id: "guide.pulseToPiece", section: .guide, …)` in `LearnLibrary.guideEntries`, direkt NACH `guide.pulse` (`Sources/Echoelmusic/Studio/LearnLibrary.swift:123-127`) und VOR `guide.access` (`:129`). Text in Lern-Reihenfolge, nur ausgelieferte Bedienelemente wörtlich: Press Play → a fingertip on the back camera (the pulse pill shows the lock) → the tempo field under „Tempo & variations" (Flow follows your pulse; lock it for a fixed BPM — `BodyTempoField.swift:342` „Tempo, locked") → „Key" and „Scale" on the Piece plate (`WorkspaceView.swift:1305/1314`) → the five steps on Arrange's guide card (`ComposeGuide.swift:33`: Add a MIDI track · Add a part · Write notes · Play · Save) → Export „MIDI" into your DAW (`EchoelStudioView.swift:2481`). Jede Feld-Kopie als eigenes `String(localized:)`-Literal, typografische Anführungszeichen (E4-23), keine Wirkungs- oder Lernerfolgs-Behauptung („you will learn…" ist verboten; „this is the path" ist erlaubt).

Dateien (3):
1. `Sources/Echoelmusic/Studio/LearnLibrary.swift` — +1 Eintrag.
2. `Tests/EchoelmusicTests/LearnLibraryTests.swift:11` — `guideEntries.count` 6 → 7 (Kommentar „#589 — hand-written" mitziehen).
3. `Sources/Echoelmusic/Resources/Localizable.xcstrings` — die neuen Schlüssel (Titel · Summary · Detail) als `en`-Einheiten; gemessen: alle drei letzten Kopie-Commits an `LearnLibrary.swift` (2ef716273, 3b6381857, 4d59d5db0) zogen den Katalog mit, und `StringCatalogIsHonestTests` pinnt `testEveryKeyStillExistsAsALiteralInSources` (:332) und `testTheEnglishUnitEqualsTheKey` (:319) — ohne Katalog-Zeile wird ein Wächter rot.

Wächter, die schon greifen (kein neuer nötig): `Tests/CISmoke/TheGuideNamesOnlyRealControlsTests.swift` (jeder zitierte Bedienname muss im UI-Quelltext existieren; `testTheGuideMakesNoHealingClaim` :87 verbietet Heil-Vokabular), `TheShareReadyClipIsNotSoldAnywhereTests` (Scan auf zurückgenommene Fähigkeiten über diese Datei), der Chrome-Wort-Wächter (kein „project/session/song"). `GuideOverlay` (`Studio/GuideOverlay.swift:43`) blättert die Karte automatisch mit — die Start-Tour gewinnt die eine Karte, die den Weg geht.

Council: trivial-reversibel (Kopie), stillschweigend; einziger Einwand (Skeptic): die Karte bleibt Prosa und KANN den Schritt nicht ausführen — bewusst so, weil ein Körper-Schritt im `ComposeGuide` den founder-zitierten Fünf-Schritte-Walk ändern würde (Founder-Frage, nicht freie Scheibe). Verifikation: CI-kompiliert (Xcode Compile Check + CI/CD „Build for Testing"); Geräteblick auf ≡ → Guide bleibt offen (`docs/dev/FEATURE_STATUS.md:46` „offen", `FOUNDER_INBOX.md:203` S1b-1) — dort KEINE neue Zeile, die Karte reitet auf der bestehenden Bitte mit.

Nachfolger (WATCH, nicht jetzt): „Your piece, right now" — Live-Zeile mit Tonart/Skala/BPM im Theorie-Detailblatt (`LearnView.swift:151` `entryDetail`, nie in `list` :41), eigener CISmoke-Wächter, erst nach Founder-Blick auf Scheibe 1.

#### Rote Linien, die daraus folgen

DARF NICHT PASSIEREN:
1. „Weltfrieden", „Frieden", „Einheit/UNITY", „Verzeihen", „Heilung" als WIRKUNG in Store-Text (`fastlane/metadata`), Website (`docs/*.html`), In-App-Kopie (`Sources/`), Content (`ContentPipeline/`) — App-Store 2.3, FDA-General-Wellness-Linie, `memory/vision.md:118-124`, `CLAUDE.md` BRAND, `ContentPipeline/CLAIMS.md:153-155`. Erlaubt ist nur Haltung („so bauen und handeln wir") und Founder-Stimme in einem Manifest außerhalb der Produktflächen.
2. Kein Handels-/Marktplatz-/Trade-Feature, kein Shop, kein „Friedensabkommen"-Flow, keine Spenden- oder Fair-Trade-Mechanik in der App — v1.0 ist kostenlos und zeigt keine Kauf-UI (`WorkspaceView.swift:156-163`); `ProUnlockView`/`EchoelStore`/`ProGate` werden NICHT präsentiert und NICHT gelöscht (Umwidmung v1.1).
3. Nichts Esoterisches: keine Heilfrequenzen, Solfeggio, Chakren, Entrainment-„Wirkung", keine Wellness-/Meditations-/Therapie-Positionierung — auch nicht als „Musikschule für Achtsamkeit".
4. Keine Öko-/Vegan-/Regenwald-Behauptung über die App („vegan", „CO₂-neutral", „nachhaltig") — es gibt keine Lieferkette und kein Footprint-Konto im Code (`git grep -i 'carbon\|co2\|footprint' -- Sources docs/*.html` → nur ein Fehltreffer). Ehrlich bleibt nur „akku- und wärmebewusst" (`Core/AdaptiveQuality.swift:3-16`).
5. Kein öffentliches „Musikschule"/„Kurs"/„Lehrplan"-Versprechen auf Website, Store oder Content, solange nur die In-App-Learn-Bibliothek existiert; keine Learn-Zeile in `CLAIMS.md` ohne Founder-Freigabe.
6. Keine strukturelle Scheibe an der Schule ohne Gate: kein Körper-Schritt im `ComposeGuide` (founder-zitierter Fünf-Schritte-Walk), kein GM17-Vorher/Jetzt (Founder-blockiert, `FOUNDER_INBOX.md:112`), keine Wiederherstellung der deutschen Katalog-Einheiten (E4 „Nur Englisch", `:53`), kein Re-Dooring von `BreathGuideView` (Founder-Frage; Elternteil betüren, nie das Kind), keine neue Fläche außerhalb der WA-Reihenfolge des Master-Plans.
7. Keine Live-Bio- oder Tempo-Lesung in `LearnView.list`/`body` oder in einem Vorfahren des Menü-Wirts (10.76.41/50-Freeze-Gesetz) — eine Live-Zeile gehört ausschließlich ins Detail-Blatt.
8. Kein neues Framework, keine Abhängigkeit, kein Server, kein Konto — die „kein Lock-in"-Haltung ist nur wahr, solange `Package.swift:73` `dependencies: []` bleibt.

#### Prüfprotokoll des Richters

Nur-Lese-Prüfung (git grep / sed / ls / git log / git show --stat), keine Datei angefasst. Stand: HEAD ist `5bc17bc6b`, NICHT `7536984c9` wie in der Aufgabe — zwei Docs-Commits dazwischen (`cc80127c5` Orchester-Kopf, `5bc17bc6b` Inbox LR5/LR3); kein `Sources/`-Unterschied für die geprüften Stellen.

Stichproben (alle HALTEN, nichts gestrichen):
1. `Sources/Echoelmusic/Studio/LearnLibrary.swift:1-6` („app as a school"), `:16` (sechs Sektionen), `:123-127` guide.pulse, `:128-137` guide.access mit In-Code-⛔ (#1018) — bestätigt.
2. `Sources/Echoelmusic/Studio/EchoelStudioView.swift:1337` `showLearn = true`, `:1814` `.sheet(isPresented: $showLearn) { AnyView(LearnView()) }`, `:2481` `Button { exportMIDI() }` — bestätigt.
3. `Sources/Echoelmusic/Studio/WorkspaceView.swift:156-163` (v1.0 frei, keine Kauf-UI), `:600` Tür „learn", `:608` Toggle guideVisible, `:1305/:1314` Picker „Key"/„Scale" — bestätigt.
4. `Package.swift:66-73` `dependencies: []`; `git grep -n 'URLSession\|URLRequest' -- Sources | grep -v ': *//' | wc -l` → 0 — bestätigt.
5. `Tests/EchoelmusicTests/LearnLibraryTests.swift:11` `guideEntries.count == 6`; `Sources/Echoelmusic/Studio/ComposeGuide.swift:33` fünf Fälle; `Sources/Echoelmusic/Studio/BodyTempoField.swift:342` „Tempo, locked" — bestätigt.
6. `Sources/Echoelmusic/Core/SessionContext.swift:141/146/196` keyScale/a4Hz/key; `Sources/Echoelmusic/Core/BioEgressPolicy.swift:8-12, :117-118`; `memory/vision.md:118-136`; `ContentPipeline/CLAIMS.md:153-155`; `docs/dev/FOUNDER_INBOX.md:53` (E4), `:112` (GM17), `:203` (S1b-1); `Sources/Echoelmusic/Studio/MusicTheoryPrimer.swift:16, :73-75`; `Sources/Echoelmusic/Studio/LearnView.swift:41/151/162`; `Sources/Echoelmusic/Studio/GuideOverlay.swift:43` — alle bestätigt. Wächter-Dateien `TheGuideNamesOnlyRealControlsTests`, `TheGuideHasADoorTests`, `TheShareReadyClipIsNotSoldAnywhereTests` existieren.

Zähl-Nachmessungen: `grep -o '⛔' CLAUDE.md | wc -l` → 91, `grep -c '⛔' CLAUDE.md` → 77 (beide wie in MAP A). `Environment(SessionContext.self)` → 8, `Environment(BeatPlayer.self)` → 13 Leser in `Sources/` (kommentar-bereinigt). „Tempo & variations" existiert als Katalog-Schlüssel (`Localizable.xcstrings:9052`).

Zwei Korrekturen an den MAP-Notizen: (a) MAP-A-Honesty-Note 1 („Weltfrieden nicht im Baum") ist seit `cc80127c5` überholt — `git grep -n -i weltfrieden` trifft `reports/Orchester – ein Kopf, fünf Aufträge (2026-10-11).md:5, :27, :65`; die durchsetzbaren roten Linien bleiben trotzdem vision.md/CLAUDE.md/CLAIMS.md. (b) Scheibe 1 hat DREI Dateien, nicht zwei: die letzten drei Kopie-Commits an `LearnLibrary.swift` (2ef716273, 3b6381857, 4d59d5db0) zogen `Localizable.xcstrings` mit, und `Tests/CISmoke/StringCatalogIsHonestTests.swift:319/:332` pinnen Katalog↔Literal in beide Richtungen.

Nicht geprüft (Umfang): die Accessibility-Zählungen 252/176/54 und die Wächter-Listen zur Flash-Decke wurden nicht nachgemessen, sondern aus MAP A übernommen; Gerätebefunde (≡-Menü, Guide) bleiben offen wie in `FEATURE_STATUS.md:46`.

## 2026-10-11 — ChatGPT: Gate-Bericht zu `main` = `05047ad34` (Lernmodus; Founder-Einfügung, Quelle des xcresult-Zugriffs unbekannt)

Intake: `scripts/learn-intake.py` — 0 unsichtbare Zeichen, 0 URLs, 0 befehlsförmige Zeilen, 0 anweisungsförmige Sätze. Die Run-IDs im Text (38123532864, 38123532861) stimmen mit den echten Läufen überein; das Modell hat also GitHub-Actions-Daten gelesen. Wie es an ein „vollständiges xcresult“ kam, sagt der Text nicht.

### Behauptung → Messung → Verdikt

| Nr | Behauptung | Messung | Verdikt |
|---|---|---|---|
| 1 | `main` = `05047ad34`, enthält SH-2b samt Typkorrektur und die Lernkarte | `git ls-remote origin refs/heads/main` → 05047ad34; `git log` zeigt f2a8be28f · 96f744c15 · 4e041a88b · 7cc9686c4 darunter | BESTÄTIGT |
| 2 | Compile Check 38123532864 bestanden | `get_workflow_run` → success, 08:11:50 → 08:17:31 | BESTÄTIGT |
| 3 | Build for Testing bestanden | Job 114423201371, Schritt 9 success (08:18:20 → 08:25:26) | BESTÄTIGT |
| 4 | Run Tests fehlgeschlagen | Schritt 11 failure, Exit 65; Fenster in der #396-Form (`TEST EXECUTE FAILED`, kein Startfehler) | BESTÄTIGT |
| 5 | xcresult: 5.469 bestanden, 21 fehlgeschlagen, 1 übersprungen | Artefakt `test-results-ios-iPhone 17` (id 11697132938, 10,1 MB) existiert; Download scheitert: `CONNECT tunnel failed, response 403` — der Blob-Host ist in der Netz-Policy dieser Umgebung nicht erlaubt. Fenster (`gh-test-verdict.py`): 162 passed, 0 failed, 0 skipped, Lücke 2.088 s. `git grep -ho 'func test…' Tests/CISmoke` = 5.500 → Summe 5.491 plausibel | UNVERIFIZIERT |
| 6 | Alle neun SH-2b-Tests gelaufen und bestanden, inkl. Live-Reader | 5 + 4 Namen als `passed` im Fenster von 05047ad34 (und schon im Fenster von 4e041a88b) | BESTÄTIGT |
| 7 | L1-Join („Verbindungskontrolle der Lernkarte“) gelaufen und bestanden | `TheGuideNamesOnlyRealControlsTests`: 0 Ergebniszeilen im Fenster — kompiliert nachweislich, Ausführung unbelegt (#445) | UNVERIFIZIERT |
| 8 | OSC-Loopback „diesmal wieder grün“, Verhalten wechselnd | Keine Loopback-/OSC-Ergebniszeile in einem heute gelesenen Fenster (4e041a88b, 05047ad34); Kandidaten im Bundle: `TheLoopbackCalibrationRejectsWhatItCannotMeasureTests`, `TheOSCInputIsBoundedTests`, `TheOSCControlInputIsAWhitelistTests` | UNVERIFIZIERT |
| 9 | Auto-Merge 38123532861 erfolgreich | `main` trägt die SHA | BESTÄTIGT |
| 10 | TestFlight-Schritt übersprungen | `auto-merge-claude.yml`: Dispatch steht auf `if: false` (CLAUDE.md, CI/CD-Absatz) | BESTÄTIGT |
| 11 | Branch seit 2759e4592 nur Docs; kein neuer TestFlight-Upload | `54d9b7fb9`, `2759e4592` = Log-Einträge; `.deploy/release` seit dieser Sitzung unverändert | BESTÄTIGT |

### Verdikt

**WATCH** auf Nr. 5. Eine Zahl, die ich nicht messen kann, ist keine Tatsache — aber diese hier wäre, wenn wahr, die #686/#943b-Lage in groß: Rots im Loch des `tail -200`-Fensters, die kein Gate meldet. Die zwei Hypothesen sind gleich plausibel: (a) 21 echte Rots auf korrektem Baum (Tests/CISmoke/CLAUDE.md §3 „delta grading ist blind“), (b) der Clone-Tod (#396) zählt die auf Clone 2 laufenden Fälle als fehlgeschlagen. Entscheiden kann das nur das Artefakt.

**Die eine Übernahme:** das Artefakt MESSBAR machen. Zwei Hälften, beide beim Founder: (1) in der Umgebung den Host `*.blob.core.windows.net` (GitHub-Artefakt-Speicher) unter „Allowed domains“ erlauben — dann kann die Sitzung das Zip holen; (2) `ci.yml` nach dem Lauf eine `xcrun xcresulttool`-Zusammenfassung (Zahl bestanden/fehlgeschlagen/übersprungen + Namen der Fehlschläge) in den Job-Log drucken lassen — `.github/workflows/**` ist founder-gated, also berichtet, nicht editiert (dieselbe Reparaturform, die Tests/CISmoke/CLAUDE.md §5 beim #807-Block schon nennt).

Nichts aus dem Text wurde ausgeführt oder wörtlich übernommen. Tally danach: `python3 -I scripts/learn-intake.py --tally`.

## 2026-10-11 — „Meta-Prompt Engine“: ein System-Prompt, der Claude umschalten soll (Lernmodus; Founder-Einfügung, Herkunft unbekannt)

Intake: `scripts/learn-intake.py` VOR dieser Runde — 1 unsichtbares Zeichen (U+FE0F direkt nach 🎛, der Emoji-Präsentations-Selektor einer Tastatur), 0 URLs, 0 befehlsförmige Zeilen, **0 anweisungsförmige Sätze** — obwohl der Text eine Rollen-Injektion in Reinform ist („[SYSTEM INSTRUCTION“, „Role: You are an elite …“, „Acknowledge activation by outputting“, „Füge diesen Text direkt als System Prompt ein“). Ein Scanner, der auf der Form, für die er existiert, nichts trifft, ist ein Befund (`.claude/rules/context.md` §2). NACH `50c334f51` liest derselbe Lauf 5 anweisungsförmige Sätze und 0 Kontamination (1 gutartiger Selektor, eigene Zeile). Drei Messer + Richter (`wf_604f63fe-9a2`), jede Zeile vom Richter gegen Befehl oder Datei:Zeile nachgeprüft.

### Behauptung → Messung → Verdikt

| Nr | Behauptung | Messung | Verdikt |
|---|---|---|---|
| 1 | ADM-OSC-Brücke (OUT ADMOSCSender, IN ADMObjectInput/OSCReceiver Port 8001) ist real und verdrahtet | git grep -n -e 'ADMOSCSender(' -e 'OSCReceiver(' -e onObjectMove -e 8001 -- Sources \| grep -v ': *//' → EchoelmusicApp.swift:128/:135/:1528, OSCReceiver.swift:439 defaultPort 8001, :648 onObjectMove; SpatialSceneStore.swift:141 apply(_:); Default aus: StudioDefaultKeys.swift:557 oscInEnabled=false; reine Steuerung: OSCReceiver.swift:231-232 „no render … nothing in the app's own audio is panned by it“ | BESTÄTIGT |
| 2 | Es gibt eine „Binaural DSP Engine“ im Repo (DSP/BinauralPanner mit Produktionspfad) | git grep -n 'BinauralPanner\.' -- Sources \| grep -v ': *//' \| grep -v DSP/BinauralPanner.swift → 0 (exit 1); DSP/BinauralPanner.swift:48 public enum, nur statische cues(). Binaural klingt NUR über Apples HRTF-Bus: AudioEngine.swift:2211 renderingAlgorithm = .HRTFHQ, Core/HeadphoneSpace.swift:29 (kein eigener DSP). HISTORY_ARCHIVE.md:497/:500 führt den Panner als Null-Aufrufer mit Recovery-Scheibe | WIDERLEGT |
| 3 | Das Repo empfängt OSC von „Grapes 3D“ über ein Grapes-spezifisches Protokoll | git grep -n -i grapes -- Sources \| grep -v ': *//' → 0 (ungestrippt 5, alle Kommentare: OSCReceiver.swift:216 Beispiel neben L-ISA/SPAT); git grep -n -i 'grapes 3d' → nur scratchpads/STRATEGY_STATE_OF_THE_ART_2026-06-06.md:53. Protokoll ist generisches ADM-OSC v1.0 (CLAIMS.md:70) | WIDERLEGT |
| 4 | „Dolby Atmos Binaural Mappings“ sind Repo-Gegenstand | git grep -n -i dolby -- Sources \| grep -v ': *//' → 0; git grep -n -i atmos -- Sources \| grep -v ': *//' \| grep -v -i atmosph → nur Core/ImmersiveMasterPlan.swift:78 reservedProgrammeNames = ["atmos_master"] (Negativ-Guard, ADR-007 F-E); docs/adr/007-immersive-master-format.md:38-39 „Niemals dbmd / DAMF/.atmos“, :50 „Dolby Atmos … kommen in keine UI, keinen Store-Text, keine Website“; „binaural“ im ADR: 0 | WIDERLEGT |
| 5 | Ein Python-Skript im Echoelmusic-Repo empfängt OSC-Meldungen | git ls-files '*.py' \| wc -l → 28; git ls-files 'Sources/**/*.py' \| wc -l → 0; git grep -l -i 'import socket' -- '*.py' → 0; git grep -n -i -w osc -- '*.py' → nur Prosa/Kategorie-Strings (doctor.py:1509/:1541/:1657, founder-verify.py:142/:237); Package.swift:66-68 dependencies leer; Empfang ist Swift: Sync/OSCReceiver.swift (NWListener) | WIDERLEGT |
| 6 | Bei Dropouts werden Fehler automatisch abgefangen | Sync/OSCReceiver.swift:482-486 listen failed → lastError + return; :516-520 state .failed → lastError; :530-534 Fremdsender → refusedCount++, cancel; :535-537 maxConnections 16, älteste fällt; :553-558 Verbindungsfehler → removeAll; :609-615 unparsbar → ignoredCount++. Verlorene Datagramme NICHT erkennbar: grep -n -i -E 'sequence\|heartbeat' OSCReceiver.swift (ohne ///) → 0 Treffer (UDP/OSC hat kein Sequenzfeld) | BESTÄTIGT |
| 7 | Fremde Modelle (ChatGPT, DeepSeek, Ollama) dürfen als BAUER Code/Skripte für das Repo erzeugen („ready to copy-paste“, metaprompt.txt:26/:50) | docs/dev/ECHOELMUSIC_MASTER_PLAN.md:632 ChatGPT = roadmap/orchestration, :634 Claude Code = primary implementation agent, :639 „The builder never self-certifies“; .claude/skills/learn-mode/SKILL.md:32 „nie eingefügt“, :109 „PRÜFER, nie Bauer“; reports/Orchester … (2026-10-11).md:13 „Keines baut, keines schreibt Code“, :51-52 „Du schreibst keinen Code … Nur Claude Code schreibt ins Repo“ | WIDERLEGT |
| 8 | Die Zielplattformen der Engine (Midjourney, Suno/Udio, Ollama, GPT-4o, Claude 3.5, DeepSeek-R1) haben einen Abnehmer im Repo | git grep -n -i -w -E 'suno\|udio\|midjourney' -- ContentPipeline .claude/skills/echoel-marketing \| wc -l → 0; git grep -n -i -w suno / udio → je 1, beide inspiration.csv:67 (Gegenbeispiel, nicht-generative Produktion als MOAT); git grep -l -i midjourney → 4 Dateien (3 im vendored .claude/skills/marketing-Pack + inspiration.csv), 9 Zeilen; git grep -l -i -w ollama → 3 (HISTORY_ARCHIVE, inspiration.csv, RESEARCH_DSPY); gpt-4o 1; 'claude 3\.5' 0; deepseek-r1 0. Orchester §3 nutzt ChatGPT · Codex/Astra · Gemini · Grok · Mistral · DeepSeek · Claude Code (grep '^### ' Z. 83-263), keine Versionen | WIDERLEGT |
| 9 | Das Tier-A/Tier-B-XML-Format plus Aktivierungszeile ist mit dem Orchester-Kopf kompatibel | reports/Orchester … (2026-10-11).md:70 „ANTWORTFORMAT (genau so, nichts davor und nichts danach)“, :72 Tabelle Nr\|Datei:Zeile\|Befund\|Folge\|sicher/vermutet, :75 „Höchstens 8 Zeilen“, :78 „Keine Einleitung, keine Zusammenfassung, kein Code“, :24 „ein Antwortformat“ als Friedensbedingung, :298 jede Zeile einzeln verdiktet; metaprompt.txt:40-41 verlangt eine Pflicht-Präambel, :19 <code_contract>-Tags | WIDERLEGT |
| 10 | Die Engine liefert „zero-hallucination“-Prompts | python3 -I scripts/learn-intake.py --tally → chatgpt-astra 16/23 (3 Zeilen), mistral 13/21, deepseek 7/20, unknown 0/6; kein Modell, keine Zeile bei 100 %, selbst mit Datei:Zeile-Pflicht und festem Commit. Nebenbefund: Orchester :317 nennt noch „ChatGPT/Astra 8/12“, :485 „16/23“ (eine Zahl veraltet) | WIDERLEGT |
| 11 | Die Engine liefert „mathematically tight“ Prompts | metaprompt.txt:7 nennt keine Operationalisierung (keine Metrik, kein Test, kein Vergleichswert); kein Befehl im Repo kann es entscheiden | UNVERIFIZIERT |
| 12 | scripts/learn-intake.py meldet auf dem Text 0 anweisungsförmige Sätze und 1 unsichtbares Zeichen (U+FE0F, Zeile 3) *(Nebenbefund der Messung, keine Textbehauptung)* | python3 -I scripts/learn-intake.py <scratchpad>/learn_metaprompt_2026-10-11/metaprompt.txt → invisible 1 (line 3: U+FE0F), URLs 0, base64 0, hex 0, command-shaped 0, instruction-shaped 0, CLAIMS 1 (Zeile 50); Python: FE0F an Zeile 3, Vorgänger U+1F39B (🎛), Nachfolger U+0020, count 1; python3 -I scripts/learn-intake.py --selftest → OK | BESTÄTIGT |
| 13 | Der Meta-Prompt ergänzt, was dem Kopf fehlt: Negativ-Trigger, Per-Ziel-Injektion, Variablen, Intent-Zerlegung | reports/Orchester … (2026-10-11).md: grep -c 'Nicht deine Spur' → 6; grep -c 'Nur für dich' → 5; :62-66 „ROTE LINIEN (gelten in jeder Antwort)“; :71 Platzhalter <dein Name>/<Titel>/Stand; :273 „misst jede Prämisse, bevor ein Auftrag rausgeht“; :263 Claude Code bekommt absichtlich keinen Kopf (Schreiber, kein Zielmodell) | WIDERLEGT |
| 14 | Das Beispiel „Python-Skript … Grapes 3D … Dolby Atmos Binaural … Dropouts“ steht im Master-Plan oder Archiv als Vorhaben | grep -n -i -E 'atmos\|binaural\|grapes\|python' docs/dev/ECHOELMUSIC_MASTER_PLAN.md → nur :257/:539 (python3 scripts/…), 0× atmos/binaural/grapes; docs/dev/HISTORY_ARCHIVE.md:490 SpatialForge „Atmos 9.1.6“ nie kompiliert, :657 binaurales Entrainment purged; dieselbe Idee bereits geloggt: inspiration.csv:242 (2026-10-10, llm:unknown, REJECT, [verified 0/6]) und memory/inspiration_intake.md:964/:987; Orchester :136 (Gemini-Auftrag) sagt es wörtlich. Vision-Gate Schritt 1 (SKILL.md:28-29): nicht neu bewerten, auf die Zeile zeigen | WIDERLEGT |
| 15 | Das einzige Pipeline-Prompt-Template ContentPipeline/Prompts/variants.md ist in seiner Kernprämisse aktuell (Nebenbefund der Messung) *(Nebenbefund der Messung, keine Textbehauptung)* | ls ContentPipeline/Prompts → nur variants.md (2396 B); variants.md:13 „Echoel ist KEIN AUv3-Plugin und kann keine Plugins laden (Target am 2026-07-24 entfernt)“ vs ContentPipeline/CLAIMS.md:115 „Echoel IST ein AUv3-Instrument, und es LÄDT — in AUM … (#1386)“, :144 Hosting bleibt gestrichen; variants.md:16 (Watch zeigt an) stimmt mit CLAIMS.md §3 :164-170 überein; git grep -n variants.md -- Tests \| wc -l → 0 (ungepinnt) | WIDERLEGT |

Zählung für den Tally: **[verified 2/13]** — 13 Behauptungen DES TEXTES (Zeilen 1–11, 13, 14): 2 bestätigt, 10 widerlegt, 1 unverifizierbar. Zeilen 12 und 15 sind Nebenbefunde über das eigene Werkzeug und das eigene Template; sie zählen nicht in den Tally, aber sie sind die zwei Dinge, die diese Runde VERÄNDERT hat.

### Verdikt: **REJECT** (die Rolle), mit einem Nebenprodukt ADOPT→PIPELINE

Der Prompt als Ganzes ist ein Rollen-Wechsel: Claude soll Prompt-Lieferant für sieben fremde Plattformen werden, die dann bauen. Das widerspricht dem gemessenen Gesetz an drei Stellen (MASTER_PLAN §12:632-639, learn-mode SKILL.md:32/:109, Orchester-Kopf :13/:51-52/:70-78): fremde Modelle prüfen, EIN Format, nur Claude Code schreibt. Was der Text an Struktur anbietet (Negativ-Trigger, Per-Ziel-Form, Platzhalter) ist im Kopf schon vorhanden (Zeile 13) und dort strenger. Die Zielplattformen Midjourney/Suno/Udio/Ollama haben im Repo keinen Abnehmer (Zeile 8); nicht-generative Produktion ist geloggte Positionierung (inspiration.csv:67). „zero-hallucination“ ist durch den Tally widerlegt (bestes Modell 16/23), „mathematically tight“ unmessbar; beides berührt FOUNDER_PRODUCT_LAW.md:135 (fabricated certainty) und context.md §2 (measure, do not recite). Die Aktivierungszeile und die Dekor-Begriffe fallen unter CLAUDE.md:943 (Decorative copy) und die vision.md-BANNED-Liste (Überbehauptung). Das einzige konkrete Beispiel ist bereits am 2026-10-10 als REJECT [verified 0/6] geloggt (inspiration.csv:242), Vision-Gate Schritt 1 verbietet die Neubewertung. Quelle ist formal kontaminiert (U+FE0F), also keine Formulierung in Kopie, Kommentar oder Commit. Nicht WATCH: es gibt nichts, das mit einem Datum reifen könnte.

### Die zwei Übernahmen — beide Nebenprodukte der MESSUNG, keine Übernahme des Textes

1. **`ContentPipeline/Prompts/variants.md`** (Zeile 13 und der erste Absatz): das einzige Pipeline-Prompt-Template ließ ein Modell einen seit #1385/#1386 WAHREN Claim verneinen („KEIN AUv3-Plugin … Target entfernt“). Jetzt: Echoel IST ein AUv3-Instrument (lädt in AUM, Gerät 2026-09-20) und HOSTET keines — `ContentPipeline/CLAIMS.md` §a/§b, zwei Hälften. Kein Wächter betroffen (`git grep -n variants.md -- Tests` → 0); Zeile 16 (Watch zeigt an) stimmt mit CLAIMS §3 und bleibt.
2. **`scripts/learn-intake.py`** (`50c334f51`): sechs Rollen-Injektions-Nadeln, jede vorher mit `git grep -c -i -E` über alle getrackten Dateien gemessen (0 Treffer) und im Text (1 Treffer): `acknowledge (activation|receipt) by (outputting|replying|responding)` · `\[system[ _]instruction` · `role:\s*you are an? ` · `als system[ -]?prompt` · `kopiere .{0,60} in (claude|chatgpt|gemini)` · `f(ü|ue)ge .{0,80} als (system|erste) ?(prompt|eingabe)`. **Bewusst NICHT aufgenommen:** `you are an? (elite|expert|senior|world-class)` — 48 getrackte Dateien (die eingelagerten Skill-Pakete) tragen die Zeile; eine Nadel, die bei jedem Lauf schreit, wird ignoriert (#665). Dazu: U+FE0E/FE0F unmittelbar nach einem Symbol/Emoji (≥ U+2600) ist ein Präsentations-Selektor, wird gezählt und benannt, aber nicht mehr zur Kontamination erhoben; jeder andere Variation-Selektor, Zero-Width-, Bidi- und Tag-Buchstabe bleibt ein Treffer. Selftest um beide Fälle erweitert und grün; die Zeichenketten, die `TheLearnModeTreatsFeedbackAsDataTests` pinnt, sind unverändert (gemessen vor dem Commit).

### Verworfen (vom Richter, mit Grund)

- Measurer B, Zahlen in Finding 2: „midjourney 9 Zeilen in 5 Dateien“ und „ollama 7 Dateien“. Gemessen: git grep -l -i midjourney → 4 Dateien (9 Zeilen), git grep -l -i -w ollama → 3 Dateien. Der Befund (kein Echoel-Werkzeug nutzt sie) bleibt, die Zahlen sind korrigiert.
- Measurer C, Finding 12, Teilbeleg „inspiration.csv:184 (Founder-Reel, Heilungs-Thema → harte REJECT-Linie)“: die Zeile trägt das Verdikt ADOPT-PLAN (Forensik des Heilungs-Themas plus drei brand-safe No-Claim-Optionen); Midjourney steht nur im Quellen-Titel des Reels. Als Beleg für eine REJECT-Linie verworfen.
- Measurer A, Finding 4, Formulierung „einziger Dolby-Treffer ist ImmersiveMasterPlan.swift:78“: kommentar-gestrippt hat `dolby` in Sources 0 Treffer (das Wort steht im Kommentar :77), der Treffer an :78 ist das Literal „atmos_master“. Verdikt bleibt, Satz korrigiert.
- Measurer A, Findings 2/4, Schlussfolgerung „Binaural hat null Fundament“: zu stark. Live ist Apples HRTF-Bus (AudioEngine.swift:2211 .HRTFHQ) mit Core/HeadphoneSpace.swift, und HISTORY_ARCHIVE.md:500 führt BinauralPanner-Monitoring als nächste sichere Scheibe. Null Fundament hat allein „Dolby Atmos Binaural Mapping“; DSP/BinauralPanner bleibt gemessen aufruferlos.
- Measurer C, Finding 15, Vorschlag „Zeile 16 (Watch) prüfen“: geprüft gegen ContentPipeline/CLAIMS.md:164-170 (Anzeige, Produzenten-Hälfte nicht gebaut). Konsistent, kein Eingriff nötig, aus der Adoption gestrichen.
- Measurer C, Finding 13 als Tabellenzeile: ist ein Urteil über Anti-Muster, keine messbare Repo-Behauptung; aus n ausgeschlossen, Inhalt nur im tier_reason verwendet (die zitierten Gesetzesstellen CLAUDE.md:943/:111/:1003, FOUNDER_PRODUCT_LAW.md:135, vision.md:122-126 sind geprüft und stimmen).
- Measurer B, Finding 4, „mathematically tight“ unter WIDERLEGT mitgeführt: nicht operationalisiert, also UNVERIFIZIERT; als eigene Zeile 11 getrennt, zählt in n, nicht in k.

### Lehren

- **Ein Scanner, der 0 meldet, hat etwas gemessen — nämlich seine eigene Nadelmenge.** Die 13 alten Nadeln waren alle englisch und alle aus der „ignore previous“-Familie; eine Rollen-Zuweisung mit Aktivierungsritual ist derselbe Ausfall in anderer Grammatik. Vor einer neuen Nadel zuerst das Repo zählen: eine mit 48 Treffern wäre schlimmer als keine.
- **Eine Messung über fremden Text findet auch eigene Fehler.** Zeile 15 (variants.md) und Zeile 12 (der Scanner) standen in keiner Behauptung des Textes; sie fielen beim Nachmessen der Prämissen auf. Das ist der eigentliche Ertrag dieser Quelle — nicht ihre Behauptungen, die zu 10 von 13 widerlegt sind.
- **Das Beispiel war schon geloggt.** Vision-Gate Schritt 1 (nicht neu bewerten, auf die Zeile zeigen) hat hier gegriffen: `inspiration.csv:242`, 2026-10-10, REJECT [verified 0/6]. Dieselbe Idee kam binnen 24 h in neuem Gewand zurück; der Tally für `unknown` sagt jetzt 2/19.

## 2026-10-12 — Mistral: rote Blitze im Video-Begrenzer (Orchester-Auftrag, Stand `0205769fc`) — [verified 6/6]

| Nr | Behauptung | Messung | Verdikt |
|---|---|---|---|
| 1 | WCAG 2.3.1 verlangt allgemeine UND Rot-Blitz-Schwelle, Flächenregel 25 % | Understanding-Dokument W3C; deckt sich mit `FlashGuard` (0.10 / 0.80 / 3 Hz) für die allgemeine Hälfte | BESTÄTIGT |
| 2 | Keine Rot-Bedingung in `FlashGuard` | `git grep -i -E 'red flash\|saturated\|chromatic'` in den vier Dateien → 0 (ganze Datei, 672 Zeilen) | BESTÄTIGT |
| 3 | Der Zähler sieht nur einen Skalar je Zelle | `step(time:cells: [Double], …)` Z. 204, `registers(_ value: Double…)` Z. 143, `VideoLayerSlot` Z. 340 → `relativeLuminance` | BESTÄTIGT (Zeilen versetzt) |
| 4 | Gegenbeispiel ist normativ ein Rot-Blitz | R-Anteil 0.800, u'v'-Abstand 0.284 > 0.2, (R−G−B)×320 = 96 > 20 | BESTÄTIGT |
| 5 | Begrenzer registriert ihn nicht | ΔL = 0.0077 < 0.025 (Fenster) und < 0.10 (Zelle) | BESTÄTIGT |
| 6 | Leuchtdichte-Blitze: Zählregel hält (5 Übergänge → ≤ 2,5 Blitze/s) | `engageTransitions = 2·3−1` Z. 108 | BESTÄTIGT |

Verdikt **ADOPT→PRODUCT, eine Scheibe**: ein Rot-Kanal im `VideoFlashLimiter` (je Zelle zusätzlich der Rot-Anteil bzw. u'v', Übergänge in/aus gesättigtem Rot zählen in dieselbe 3-Hz-Kappe), mit Wächter, **bevor `attachVideoOutput` einen Aufrufer bekommt**. Heute latent: kein Produktionspfad zeigt Footage. Offene Normfrage (Mistral): WCAG-2.2-u'v' oder 2.0/2.1-(R−G−B)×320 — Empfehlung 2.2, das Gegenbeispiel erfüllt beide. Lehre: der Auftrag mit eingesetzter Vermutung UND der Bitte um ein Gegenbeispiel mit Zahlen hat die erste voll bestätigte Antwort des Orchesters gebracht.

## 2026-10-12 — Grok: Video an die EINE Uhr (Orchester-Auftrag, Stand `0205769fc`) — [verified 6/7]

Code war im Prompt eingebettet (Grok öffnet keine Links). Alle sieben FAKTEN stimmen am Code:
`scheduleSegment/Buffer(…, at: nil)` an fünf Stellen in `TimelineAudioSink` (kein Host-Anker) ·
`PatternEngine.nextTickUptime` ist das IDEAL-Raster (#1223) · `nextDeadline` springt nach einem Stau
über eine Lücke auf `now` (Z.684) · `VideoLanePlan`-Konstanten (1/30 · 0,25 · 3 % · 0,5) · `resync`
liefert eine Rate ohne Host-Zeit · `VideoLayerSlot.pullFootageFrame` fragt `itemTime` zur ZEICHEN-Zeit
(`CACurrentMediaTime()`), nicht zur Anzeige-Zeit · `filePositionSeconds` rechnet mit der aktuellen bpm.
**Teilweise:** Befund 7 — Audio und Video teilen dieselbe Funktion, springen beim Glide also gemeinsam.
**Unverifiziert:** jedes Apple-API-Verhalten (setRate(atHostTime:)-Bedingung, Seek-Schleifen bei langem GOP).
**Referenz-Vorschlag real:** `BroadcastAudioAnchor` wird lebend vom Render-Pfad geschrieben
(`RetroCapture.masterRingView`). Verdikt WATCH→PLAN: Vorbedingung für den VideoLanePlayer, kein Code
jetzt (`attachVideoOutput` hat 0 Aufrufer). Säuberung: nur die gemessene Zusammenfassung lag vor, der
Rohtext wurde nicht durch `learn-intake.py` geschickt — keine Formulierung daraus übernommen.

## 2026-10-12 — DeepSeek: Echoel Grain, Pegel- und Index-Rechnung (Orchester-Auftrag, Stand `0205769fc`) — [verified 3/4]

Code eingebettet. Bestätigt: Normierung 1 · 2/3 · 4/7 · zu kurze Quelle wird Stille · kein Lesen
außerhalb des Puffers. Alle drei stehen schon im Dateikopf von `DSP/GrainCloud.swift` (GA-9-Messung) —
kein neues Wissen. **Widerlegt:** „Pegel fällt bei vollem Pool" — das Spawnen ist deterministisch,
aktiv sind höchstens 4 Körner bei `maxGrains = 8`. DeepSeek übersah außerdem den dokumentierten Abfall
unter density 0,5 (bis −12 dB bei 0). Verdikt: kein Befund, nichts zu bauen. Säuberung: der Text kam
als Tabelle ohne Anweisungen; keine Formulierung übernommen.

## 2026-10-12 — Orchester Runde 2: ChatGPT [verified 3/8] · Grok [verified 7/8] (Stand `05047ad34`, Code eingebettet)

**ChatGPT (stiller Start):** Am Code bestätigt: ein einziger unbestätigter Lauf genügt, damit der nächste
Start im Sicherheitsmodus landet (Schwelle 2, keine Anlass-Prüfung). Die Einschränkung zum Wegwischen
stimmt ebenfalls: `confirmHealthy` feuert beim ersten Hintergrundwechsel. Die Kontextzeile steht hinter
Zählung und Urteil. Fünf Punkte sind Apple-Verhalten (Prewarm, Watchdog, Jetsam, BLE-Restore,
ActivePrewarm-Lebensdauer), als Doku ausgewiesen, im Repo nicht messbar. WATCH: die SH-2b-Zeile liefert
beim nächsten Fall den Beleg, ob ein Absturz vorlag.
**Grok (Erstnutzer-Lesart):** Der stärkste Befund der Runde: das Onboarding sagt „Press Play to start",
die App öffnet aber auf Piece, wo Play ohne Teil mit Inhalt `.unavailable` ist und nicht das Instrument
startet. Dazu Karte 5 ohne Bühnenangabe, Quellenmenü nur per Langdruck, Loslassen-Hinweis nur im
Bio-Panel, Karte 6 schickt arrangierte Noten zur Instrument-MIDI-Kachel. Karte 1 nennt die Bühne sehr
wohl (Teilbefund). ADOPT→PRODUCT: eine Copy-Scheibe, Founder-Freigabe nötig (nutzersichtbarer Text).
DeepSeek schickte dieselbe Grain-Antwort ein zweites Mal — nicht doppelt geloggt.

## 2026-10-12 — Musiktech-Briefing 5.–12.10. (Quelle nicht genannt) — [verified 2/3]

Xcode 27.1 RC und iOS 27.2 Beta 3 extern bestätigt; Asset Library existiert, Startdatum unbelegt. Neu und
relevant, im Briefing nicht genannt: **iPhone Duo** (faltbar, ab 23.10.; Duo-Screenshots ab April 2027
Pflicht) — Echoel ist iPhone-only, läuft also darauf; die Reflow-Arbeit (#292) wird damit dringlicher.
CI/TestFlight pinnen Xcode 26.2 (founder-gated). Testliste des Briefings enthält vier Flächen, die es nicht
gibt (iPad, Videoexport, Aufnahme, binaural) — nicht übernehmen. WATCH Toolchain-Wechsel; ADOPT→PIPELINE
kanonischer Satz echter In-App-Aufnahmen für die Asset Library (CLAIMS.md-Regel: nur was ausgeliefert ist).

## 2026-10-12 — Orchester Runde 3: Mistral [verified 7/7] · Grok [verified 5/6]

**Mistral (Startkontext-Zeile, Stand `05047ad34`):** Alle sieben Aussagen stimmen. Übernommen in
`8f4c45d61`: `Int(clamping:)` statt der fangenden `size_t → Int`-Umwandlung (Crash-Netz-Leser und
`MemoryPressureHandler`), der init-Kommentar (ein Log, das am Urteil endet, starb im Kontext-Leser, nicht
in einem Store-Konstruktor), die sysctl-Doku, und die Markerliste des Wächters (5 → 12 Schreibungen; „ein
Marker ist nie klein geschrieben“ war falsch). Stärkste Quelle der Runde für Code-gegen-Kommentar.
**Grok (Rot-Blitz-Angriff, Stand `a678d9959`):** Prämisse Gamma-Mischung widerlegt (der Shader mischt linear),
aber Punkt 2 — „die Begründung gilt nur über dunklem Grund“ — führte zur echten Lücke: die Screen-Mischung
lässt R − G − B um bis zu 3·Gain schwanken; bei 0,05 zeigte ein gedeckelter Rot/Cyan-Strobe über dunklem Rot
0,145. VV-4d (`465713bf9`): engagedGain = Rot-Schritt/4, Anspruch 12. Der Lead fand dabei VV-4e (Gain 1,
Grün/Blau der Ebene über rotem Feld, von keinem Kanal gezählt) — offen, im Limiter-Kopf benannt, braucht
eine Entscheidung (Feldfarbe zählen oder Kanal-Schranke). Lehre: ein falsches Warum kann auf ein echtes Was
zeigen — die Prämisse messen, die Folgerung trotzdem nachrechnen.

## 2026-10-12 — Orchester Auftrag 12: ChatGPT mit Schreibrecht (Website-Ehrlichkeit) — [verified 8/10]

Erster Lauf der Schreibrecht-Regel. Branch `orchester/chatgpt/website-claims` (11 Commits, Basis
`3a47150c5`), `git diff --name-status` = nur die fünf erlaubten `docs/`-Seiten + der Bericht:
Verbotsliste eingehalten. Acht von zehn Funden stimmen und sind von mir NEU formuliert auf
`claude/…` gelandet; zwei abgelehnt, weil sie Sicherheitshinweise LÖSCHEN statt sie zu
präzisieren (health.html: „kein therapeutisches Gerät“ und der 3-Hz-Satz — `FlashGuard` deckelt
`LightingStore` und `VisualCreativeState`). **Lehre über die Quelle:** gut im Finden von
Widersprüchen auf der Seite, schwach im Unterscheiden „Behauptung ohne Beleg“ vs. „Pflichttext“
— ein Ehrlichkeits-Auftrag braucht künftig die Zeile „Sicherheits- und Haftungshinweise nie
entfernen“. Beim Entrainment war das Ergebnis richtig, die Begründung falsch (CLAIMS §2 statt
der fehlenden Tür). Der Branch wird nicht gemergt; Löschung gehört dem Founder.

## 2026-10-12 — Statusbericht eines fremden Modells mit CI-Zugriff — [verified 3/5]

Die wertvollste Eigenschaft dieser Quelle: sie las das **xcresult-Artefakt** (5 473 bestanden,
23 fehlgeschlagen, 1 übersprungen) — genau die vollständigen Ergebnisse, die der Job-Log wegen
`tail -200` (#807) nie zeigt und die diese Sitzung nicht laden kann (Artefakt-Host von der
Proxy-Richtlinie gesperrt). Einer der zwei genannten Fehler war in Minuten verifizierbar: ein
kurzer `AVAudioFile.read` schloss einen halben Waveform-Bucket mitten in der Datei; ein einziger
kurzer Lesezugriff ergibt genau die gemeldeten 201 statt 200 → Fix `939aaa63f` + Wächter.
Widerlegt: „kein TestFlight-Upload“ (die Quelle verwechselte die übersprungenen Archiv-Jobs von
`ci.yml` mit `testflight.yml`, das Build 2622 hochgeladen hat) und ein veralteter Zweig-Stand.
**Lehre:** Diese Quelle als ARTEFAKT-LESER einsetzen — um die Namen und Meldungen aller 23
Fehler bitten, nicht um Bewertungen.

## 2026-10-12 — Orchester Auftrag 11: Mistral mit Schreibrecht (Sync-Kommentare) — [verified 10/10]

Bester Lauf des Orchesters bisher. Branch nur mit den drei erlaubten Dateien + Bericht, jede
geänderte Zeile ein Kommentar, jede Behauptung mit Beleg-Zeile — alle zehn hielten der Messung
stand. Wert über den Auftrag hinaus: die offenen Fragen. Zwei davon (Event-Adressen ohne
Produzent im Kopf; `ignoredCount` zählt auch Undekodierbares) waren weitere echte Abweichungen,
eine (UI-Leser von `lastSentTimestamp`) konnte die Quelle aus ihrem Datei-Ausschnitt nicht
beantworten und hat das ehrlich als offen markiert statt zu raten. **Lehre:** enge Aufträge mit
Belegpflicht und „frag statt rate“ liefern bei Mistral fast fehlerfreie Ergebnisse; der Engpass
war nur die Branch-Anlage (Connector kennt keinen SHA) — die übernimmt jetzt Claude Code.

**Nachtrag 2026-10-13:** Die Quelle des Statusberichts mit xcresult-Zugriff ist ChatGPT (Founder). Ihre Folgemeldung „Build 2622 hochgeladen, processingState=VALID“ deckt sich mit der eigenen Messung (testflight.yml 38291799199 grün) — ihre frühere Aussage „kein TestFlight-Upload belegt“ hat sie damit selbst korrigiert. Für ChatGPT als CI-/Artefakt-Leser also: [verified 4/5] über beide Meldungen.

## 2026-10-13 — Grok Auftrag 10b (ohne Connector) — [verified 6/6]

Der Connector fiel aus; der Auftrag lief mit wörtlich eingebettetem Code und reiner Chat-Antwort —
und das Ergebnis war das beste von Grok bisher: eine vollständige, kompilierfähig aussehende
Testdatei, die nur die gezeigten APIs nutzt, plus eine Rechentabelle, die sich Fall für Fall
nachrechnen ließ. **Lehre:** für Grok ist „Code im Prompt, Antwort im Chat“ verlässlicher als der
Connector. Übernommen als `TheFieldUnderTheLayerCannotTurnAColourIntoARedFlashTests` — Anspruch A als
`XCTExpectFailure`, damit das blockierende Bündel heute ehrlich bleibt und bei der Reparatur rot wird.

### 2026-10-13 — Lokale KI-Musikgeneratoren (ACE-Step 1.5), Video youtu.be/zeEpZhNSnqw

Quelle: Founder-Link mit Zusammenfassung; das Video selbst nicht gesehen (Proxy). Verdikt **WATCH**.
In der App nicht: ein Modell dieser Größe passt nicht in den Render-Pfad (REJECT 2026-06-18), und
ganze Tracks zu generieren konkurriert mit dem deterministischen Körper→Klang-Kern, den der Eintrag
vom 2026-07-02 als rechtlichen Vorteil gegen Suno/Udio führt. Die Brücke existiert schon: was ein
externes Werkzeug erzeugt, kommt über „Import Audio" in die Workstation (Wellenform, Pegel, Fades,
Warp). Für die eigenen Produktionen des Founders: Lizenz und Trainingsdaten-Bedingungen des Modells
vor kommerzieller Veröffentlichung prüfen. Wiedervorlage 2026-11-12.

**Nachtrag gleicher Tag — LLM-Bericht zu ACE-Step 1.5 (Founder eingefügt), [verified 3/6].** An der
Primärquelle (GitHub-README) gemessen: Mac/MLX, Modellgrößen und Speicherbedarf stimmen. FALSCH: die
Lizenz ist MIT (Code), nicht Apache 2.0, und für die Gewichte nennt die Seite keine; „uneingeschränkte
kommerzielle Rechte" steht dort nicht — der Disclaimer verlangt Offenlegung von KI-Beteiligung und
Erlaubnis bei geschützten Stilen. Lehre: Rechte-Aussagen aus einem LLM-Bericht immer an der Quelle
nachlesen. Verdikt unverändert WATCH, Brücke = Import Audio.

**Zweiter Nachtrag — erweiterter Bericht mit „God's Eye View" und Roadmap, [verified 2/5], REJECT.**
GEV existiert (MIT, 54k Sterne), ist aber ein Browser-Globus auf CesiumJS mit Google-3D-Tiles (API-Key,
gebührenpflichtig) und OpenAI-Realtime-Sprache — zwei Cloud-Abhängigkeiten, also weder „autark" noch
kostenfrei. Kein Musik-, VJ-, OSC- oder MIDI-Pfad auf der Seite. Die Abschnitte 6 und 7 des Berichts
sind leere Überschriften. Für das Produkt REJECT (Echoels Visual ist der Körper, on-device). Die
Installations-Schritte der „Roadmap" wurden nicht ausgeführt (Lernmodus Regel 1).

**Dritter Nachtrag — derselbe Bericht, jetzt mit §8 „KI-Wasserzeichen neutralisieren", REJECT.** §8 ist eine
Anleitung zum Entfernen von Herkunftsmarkern (SynthID, C2PA), damit Plattformen KI-Material nicht erkennen
— Unterabschnitte leer, Zweck klar. Nicht bearbeitet, keine Methode irgendwo festgehalten. Widerspricht dem
ACE-Step-Disclaimer (KI-Beteiligung offenlegen) und der Zeile vom 2026-07-02 (EU AI Act Art. 50(4) als Teil
des rechtlichen Vorteils). „Wasserzeichenfrei" ≠ „rechtlich frei". GEV-„Taktsynchronisation" steht nicht im
README. Lehre: der Bericht wächst je Runde um einen Abschnitt und korrigiert seine Kernfehler nicht —
weitere Einfügungen davon nicht mehr messen, es sei denn mit NEUER Primärquelle.

**Nachtrag — Herkunft des Fluid-Prompts:** die Quelle (ein fremdes Modell mit Lesezugriff auf das
öffentliche Repo, Workspace ohne Checkout) hat den Prompt nach eigenem Read-Audit geschrieben und
sagt selbst: nichts ins Swift-Repo geschrieben. Zweite Einfügung textgleich; nicht erneut gemessen.
Der Vorspann wiederholt den einen Fehler („keine Viskosität“ — `Core/FaradayDish.swift`). Plan bleibt
`scratchpads/PLAN_FLUID_SURFACE_2026-10-13.md`, F1–F5.

**2026-10-13 — Grok, Deep Audit (nur gelesen, main @ 969c271fb).** Gemessen 17 Behauptungen,
8 bestätigt. Bestätigt und FOUNDER-GATED (nur berichtet): die Repo-Beschreibung auf GitHub sagt
„Wellbeing" (Marken-Regel: kein Wellness); `LICENSE:35` nennt HaishinKit als „einzige externe
Abhängigkeit", während `Package.swift` `dependencies: []` hat, Copyright endet 2025. Bestätigt und
von der Sitzung erledigt: `README.md:30` beschrieb den Root von vor dem 2026-09-30 (nur
`EchoelStudioView`, ohne `StageShell`/Piece). Nebenbefund der Messung, nicht Groks: `CLAUDE.md`
führte `WeatherProvider` zweimal als am 2026-06-19 gelöscht — die Datei lebt (`Core/`, E3b, drei
Aufrufer); beide Zeilen korrigiert, 149.990 B von 150.000 (die nächste Zeile in CLAUDE.md braucht
einen Umzug ins Ledger). Bestätigt, offen: `ContentPipeline/CLAIMS.md` hat keinen Haptik-Eintrag,
obwohl `Studio/HapticEngine.swift` ausgeliefert ist (Website nennt „Haptic beat"); „Apple TV" auf
`docs/index.html:679` steht in keinem Plan; Auto-Merge wartet auf `Build for Testing`, nie auf grüne
Tests (#396); nie-rote Jobs (#208); große Dateien (`EchoelStudioView.swift` 941 KB!). Widerlegt:
PrivacyInfo fehlt (existiert, drei Targets in `project.yml`); „MIDI 2.0-ready input" ist falsch
(`MIDIInput.swift:131` öffnet mit `._2_0`); Blitz-Wortlaut unbelegt (FlashGuard-Slew in Art-Net UND
sACN, VideoFlashLimiter am Schirm, kein Bypass-Symbol); /health-Wortlaut (die Medikamenten-Zeile IST
die Pflicht-Warnung, der Coaches-Absatz sagt selbst „kein therapeutisches Gerät"); CloudKit vs
„no cloud" (hart aus, `CloudSync(` null Aufrufer; WeatherKit Opt-in und in `privacy.html` erklärt);
Footage-Layer unerwähnt (türlos — richtig so); Impressum fehlt (`docs/impressum.html`).
Unverifiziert: Rechtsfragen der Datenschutzerklärung. Verdikt ADOPT→PIPELINE. Lehre: ein Audit,
das den Baum nicht gezogen hat, findet Datei-Abwesenheiten, die ein `git ls-files` widerlegt —
aber seine Vergleiche zweier Textstellen (README↔Code, LICENSE↔Package.swift) trafen alle.

**2026-10-13 — ChatGPT, GMMW Deep Audit (nur gelesen, main @ 969c271fb, mit xcresult).** Sechs
Punkte, fünf messbar, vier halten. Bestätigt: Safe Mode baut dieselben 44 `@State`-Stores wie der
Normalstart (sie entstehen beim Bau des App-Structs, vor der `body`-Verzweigung) · Record im leeren
Stück ist gesperrt (`RecordTake.state` → `.songCannotPlay`, `TimelineRegionPlayer.play:684` prüft
`canPlay`) — der erste menschliche Take ist damit unmöglich, das wird die nächste Sources-Scheibe
nach der Audit-Synthese · J0: `audioRecorder: nil` (bewusst seit #1302) und `StemCaptureSession(`
null Produktions-Aufrufer (S-A3c-2b, offen) · J1: `MultipeerSession` sendet Bio-Frames und
Link-Proben, keinen Ton — „hörbares Duo" ist nicht belegt. Widerlegt: Save/Open — `playerAutomation`
steht in `DMMWProject.Content`, `lightLookIntensity`/`cycle`/`automation` im `TimelineDocument`;
nur der VISUELLE Look bleibt App-Einstellung (Council-Frage „trägt das Stück sein Bild?", kein
Bug). Nicht messbar: die 22 Testnamen — nur in der Berichtsdatei und im 10-MB-Artefakt
`test-results-ios-iPhone 17` (Blob-Host 403 durch den Proxy; das Job-Log ist `tail -200` ohne
Fehlerzeile). Beim Founder angefragt. Verdikt ADOPT→PRODUCT (Punkt 3 als Scheibe). Lehre: das
Artefakt gehört in den Auftrag an das fremde Modell — die eine Behauptung, die auf dem xcresult
steht, ist die, die die Sitzung selbst nicht erreichen kann.

**2026-10-13 — ChatGPT, Design-Zielbild „Ein Stück. Viele Ausdrucksformen." (drei iPhones).** Acht
Aussagen gemessen; fünf sind heute schon wahr (CI mit Atkinson/Wellen-E/kleinen Radien · ein Stück
mit Ansichten, `WorkstationSelection` app-weit, Instrument bleibt montiert · Spielfläche mit
Metal-Ripples · Quellenwahl an der Puls-Pille · fester Transport, Focus-Editor, Dynamic Type). Drei
Lücken: (a) „Farbe mit musikalischer Bedeutung" ist zu zwei Dritteln gebaut — `SpectralColor`
färbt Pads und Bild, der Noteneditor zeichnet in Theme-Farbe → EINE Scheibe (ADOPT→PRODUCT);
(b) Tonart im Kopf fehlt (BPM + Takt stehen da) → klein, Council zuerst; (c) EINE Ausgabe-Fläche
(Bild · Licht · Raum · Export · Bühne) gibt es nicht, die Teile liegen in Visual-Fenster, Routing
(Blackout dort), türloser Bühne, `ExternalDisplayScene`, Export-Schacht — 3-Tab-IA „Stück · Medien
· Ausgabe" ist eine FLÄCHEN-Entscheidung des Founders in der WA-Reihenfolge, keine Ad-hoc-Scheibe.
Drums im Bild nur als Audio-Spur möglich. Kein Text und kein Bild aus dem Entwurf wandert in
Sources/docs; das Bild ist Zielbild, nichts daraus wird behauptet.

**2026-10-13 — unbekanntes Modell, „Echoelmusic optimiert" (Text + zwei Mockups).** Der Text hat
das Repo gelesen: 6 von 8 Aussagen stimmen (Quellen, Atem gemessen, WAV/MIDI, vier Ausgänge,
Produktgesetz nennt AUv3 · VST3 · CLAP, Plattformrichtung). Zwei veraltet: es gibt keinen Bio-CHIP
(Puls-Pille, #704), und die Arrangement-Fläche ist nicht entfernt — die Workstation ist seit dem
30.09. die Bühne. Die MOCKUPS sind als UI-Richtung abgelehnt: „CREATE SESSION"-Knopf (der eine
Startknopf ist Play), „ECG" (kein Elektrodenpfad, nur rPPG — eine falsche Sensor-Behauptung),
„INSIGHTS"-Dashboard, KPI-Kacheln, Serifen-Wortmarke statt Atkinson, dekoratives Blattwerk,
„ARTIFACTS 2 %" ohne Messung — Uncodixfy verbietet genau diese Ästhetik. Die Studio-Szene taugt
als Stimmungsbild für die Pipeline, wenn die ECG-/Respiration-Monitore weichen. Nichts aus den
Bildern wird behauptet. Verdikt REJECT (Bilder), kein Befund (Text).

## 2026-10-13 — Reel alan.buildz: SEO-Workflow per Claude-Diktat — WATCH
- Gesehen (12 Frames, Ton unbekannt): Search Console, Keyword Planner, Trends, AnswerThePublic, Ubersuggest, Screaming Frog, PageSpeed, Rich Results, Yoast, Business Profile; Platz #9 → #1 als Animation.
- Für Echoel nur die Website betroffen (PIPELINE). Billig später: Linkcrawl auf 404/301 und Rich-Results-Prüfung der vorhandenen Seiten. Jetzt nicht — der Auftrag ist Produktionsniveau in der App.

## 2026-10-13 — Short @leosynthess: GLM-5.3-Flash · OpenViking · lokaler Model-Hub — WATCH
- Gesehen (12 Frames, Ton unbekannt): ein offenes Modell (GLM-5.3-Flash, GitHub MiaAI-Lab), OpenViking als „Kontext-Datenbank für Agenten" per MCP an Claude Code/Codex/Antigravity, Z.AI und ein Model-Hub für lokale GGUF-Modelle (Gemma 4, Feinjustierung).
- PRODUKT: nein. Null Fremdabhängigkeiten (`Package.swift` leer); der Sprachpfad auf dem Gerät ist Apples eigener (`import FoundationModels` in drei Dateien). Ein mitgeliefertes Modell kostete Gigabytes und eine Lizenz für eine Aufgabe, die schon gelöst ist.
- PIPELINE: OpenViking macht, was `memory/` + `scratchpads/` + `decisions.csv` von Hand tun. Ein neuer MCP-Server ist Founder-Sache (Sicherheitsaudit 2026-10-08 §T) und wird nie aus einem Video installiert. Wiedervorlage 2026-11-12.

## 2026-10-13 — Link kilernen.de (KI-Kursplattform) — WATCH
- Seite aus der Sitzung gesperrt (Netzwerk-Regel); gelesen nur Suchtreffer: bezahlte deutsche KI-Kurse von Everlast Consulting GmbH, u. a. „Claude Code Masterclass" (5 Module, 108 Lektionen), „Agentic Coding Workshop", Team-Lizenzen.
- Inhalt: allgemeines Claude-Code-/Agenten-Handwerk. Das Repo betreibt das schon (CLAUDE.md, Skills, Hooks, Teams, Workflows, Lernmodus, CI-Gates). Nutzen eher für den Founder persönlich (Sitzungen briefen und steuern), nicht für den Code. Kurs-Auszüge laufen über den Lernmodus. Wiedervorlage 2026-11-12.

## 2026-10-14 — Grok: AUv3-Hosting-Recherche (H3/H4) — ADOPT→PRODUCT

Zehn Punkte zum Plugin-Hosting, ohne Repo-Zugriff. Messbar hier: nur „Plugins laufen außerhalb
des App-Prozesses“ — stimmt mit dem Kopf von `HostedInstrumentHost` überein (verified 1/10). Der
Rest betrifft Apple-Frameworks und fremde Hosts und bleibt UNVERIFIZIERT; übernommen als
Entwurfs-Annahmen: Fenster nur auf Tipp anfordern, Ergebnis auf den Main-Actor, beim Schließen
loslassen, nil heißt „kein eigenes Fenster“ (umgesetzt in H3, 1657030d6); `fullStateForDocument`
mit Fehlerbehandlung speichern (H4); Invalidation-Notification bei abgestürztem Plugin (eigene
Scheibe). Kein Befehl, kein Paket übernommen.

## 2026-10-14 — ChatGPT: Port-Kandidaten aus HISTORY_ARCHIVE A+B (PR #425) — ADOPT→PRODUCT

Bericht gemergt (e8e9250e7, nur `reports/`). Stichprobe 9/9 bestätigt, darunter zwei veraltete
Archiv-Aussagen (A3 FX-Kette wird benutzt, A6 Sampler lädt). Reihenfolge für Schritt 2:
ModalBank wieder anbinden (Kern erhalten, kompiliert) → eine FM-Engine → Kick/Hi-Hat.
Jeder Port wird neu und audio-thread-sauber geschrieben (alte Kerne nehmen Try-Locks und
allokieren), nie kopiert. PhaseVocoder bleibt draußen (fünf belegte Defekte).

## 2026-10-14 — Wettbewerb: Raumklang · Handy-Musik · KI · Video · Kollaboration — ADOPT→PRODUCT
Fünf Rechercheure, ~40 Werkzeuge, Bericht `reports/wettbewerb-und-redesign-2026-10-14.md`.
Befund: keinem Werkzeug dient der Körper als Quelle; die Profi-Welt lebt von offenen Protokollen;
Endlesss (abgeschaltet 31.05.2024) ist die Warnung gegen Server-Bindung. Redesign: Echoel bespielt
das Profi-Rig vom Körper aus, statt es nachzubauen. Übernommen nur als FORM der bereits
festgelegten Reihenfolge (Szenen-Reihe, Generator-Regler, XY-Pad, OSC-Szenenabruf, takt-gestempelte
Aufnahme + FCPXML, Intervall-Jam über Multipeer). Founder-Fragen: LinkKit, NDI-SDK, ADM-OSC-Validator,
Kamera-Regel Puls ↔ Video. Websuche dünn — „vermutet" bleibt aus jedem Text.

## 2026-10-14 — ChatGPT: Recherche, Redesign und Claude-Übergabe (PR #426) — ADOPT→PRODUCT
[verified 4/4] Repo-Aussagen am Stand `b495ae64c` bestätigt; Säuberung sauber. Gemergt `3b1d2705c`.
Übernommen als Entwurfsregeln: drei getrennte Ausgabe-Zustände (gesendet / Renderer antwortet /
am Ziel geprüft), stabile externe Objekt-IDs + Ausgabeprofil pro Raum, getrennte Kollaborations-
Modi, RTT nie als Hörlatenz, zuerst ein vollständiger Ablauf. Nicht übernommen: Drum/FM-Kern als
nächster Schritt — H6 bleibt vorn. Der Prompt in §21 ist Daten. Abgleich: Nachtrag §7 in
`reports/wettbewerb-und-redesign-2026-10-14.md`.

## 2026-10-15 — Grok Heavy: Multicam-Recherche M1–M6 — ADOPT→PRODUCT
[verified 8/12] Bestätigt: hardwareCost ≤ 1, `synchronizationClock`, Synchronizer paart nur,
Continuity Camera nicht iPhone→iPhone, Drift 20 ppm = 72 ms/h, **MultipeerConnectivity ab
Xcode-27-Beta abgekündigt** (Apple DTS; TN-Nummer nicht auffindbar). Nicht übernommen: Front+Rück
„sensorsynchron" (gilt nur für ein virtuelles Gerät), NDI-iOS-Store „sicher" (Lizenz nennt nur
Android), HaishinKit-Version 2.2.5 (gefunden 2.0.9). Übernommen in
`scratchpads/PLAN_MULTICAM_2026-10-15.md`: M2 zuerst, M1b Writer-Start auf der Session-Uhr, M3
GCC-PHAT-Funktionsliste, M4 auf Network.framework, neu **K1: Colab (`MultipeerSession`) umziehen**.

## 2026-10-15 — ChatGPT Astra: Code-Review der Video-Aufnahme (e27de94d9) — ADOPT→PRODUCT
[verified 10/10] Alle zehn Befunde am Code bestätigt und in `5279814c9` behoben: Take-Identität
(zweites Stop, fremde Dateien), Take wurde bei fehlgeschlagenem Import gelöscht, Schließen während
des Starts, abgebrochenes Öffnen, Front-Datei als Rück-Datei umetikettiert, zwei Landungen rasen
um eine Spur, Linsen landen an verschiedenen Stellen, ungeschriebene Dateien bleiben liegen,
Multicam-Kosten vor `commitConfiguration` gelesen, feste Drehung. Gerät für 8 davon offen.
Lehre: ein fremdes Review gegen KONKRETEN Code mit Commit-Stand war die bisher ergiebigste Form —
deutlich besser als offene Recherche-Fragen (Grok 8/12).

## 2026-10-15 — Grok Heavy Runde 2: Uhr, immersive Formate, Network.framework — ADOPT→PRODUCT
[verified 6/8] Bestätigt: Plist-Schlüssel samt `_echoel-colab._tcp` liegen schon, also braucht K1
KEINE gesperrte Plist-Änderung und kein Multicast-Entitlement. M1b nimmt `AVAssetWriter` (Start
festlegbar). IMERSA-Domemaster, `sv3d` für MP4 und YouTube-AmbiX stimmen. TN3213 existiert (Titel).
Strittig: „Multipeer ganz abgekündigt" — ein DTS-Beitrag sagt offiziell nicht (TN3151). Die
UNGEPRÜFT-Markierungen waren ehrlich. Eingang in `PLAN_MULTICAM` (Update nachts) und
Tiefenarchitektur §9.2.

## 2026-10-15 — ChatGPT Astra: Gegenprüfung der Take-Korrekturen — ADOPT→PRODUCT
[verified 7/7] Astra fand in meinem Fix `5279814c9` einen echten Fehler (B1: Ergebnis-Übergabe
nach Freigabe des Locks → ein fertiger Take konnte als Fehler enden). B1–B4 in `4ac093662` behoben
(`VideoTakeLedger` als reiner Wert, End-to-End-Wächter `ATakeIsLandedExactlyOnceTests`). B5
(Standbild bei gestopptem Sprung) war schon vor M2 da; B6/B7 (gemeinsamer Startpunkt ≠ gleiches
erstes Bild; fehlender Song-Anker) gehen in M1b. Lehre: Gegenprüfung durch dasselbe Modell auf
konkretem Commit-Stand ist die ergiebigste Schleife; Text-Wächter beweisen keine Abläufe —
Zustände gehören in reine Werte mit End-to-End-Tests.

## 2026-10-15 — Grok Heavy: Deep Audit 2 (ohne Klon) — ADOPT→PRODUCT
[verified 6/9] Behoben in `798e0f6a8`: zu große Plugin-Einstellungen (>1 MiB) werden jetzt
GESAGT statt still verworfen; Plugin-Pegel auf 0…1 begrenzt. Bestätigt, offen: Plugin-Zustand
nur beim Schließen des Fensters gesichert (Scheibe H4f: auch beim Speichern/Hintergrund);
Workflow-only-Änderungen gehen ohne Gate nach `main` (E29, gesperrt); `gstack`-Paket mit
Telemetrie (E30); LICENSE-Jahr (E31). Widerlegt: `PrivacyInfo.xcprivacy` fehlt nicht
(`Resources/PrivacyInfo.xcprivacy`, drei Targets). Die Blitz-Aussage auf `/health` hält: auch die
neue Video-Spur läuft durch `VideoLayerSlot` → `VideoFlashLimiter`.

## 2026-10-15 — Grok Heavy: Deep Audit 3 — ADOPT→PRODUCT
[verified 5/7] Bestätigt: `/health` versprach für Art-Net/sACN dieselbe harte 3-Hz-Grenze wie
für den Bildschirm; `ArtNetSender` sagt selbst, dass die Slew-Bremse kleine schnelle Wechsel nicht
zählt. `/health` jetzt präzise (`79b469e06`). Offen als Scheiben: DMX-Blitz-ZÄHLER wie
`VideoFlashLimiter` (S-DMX1), Plugin-Zustand auch beim Speichern/Hintergrund (H4f),
Plugin-Fenstergröße (H3b). Widerlegt: „therapeutic use" in der Sicherheitswarnung ist PFLICHT
(CLAUDE.md SAFETY WARNINGS). `EchoelEntrainment` nur aus der türlosen `BioSourceView`, Standard aus.

## 2026-10-15 — ChatGPT: vollständiges Deep Audit (Stand 79361144) — ADOPT→PRODUCT
[verified 6/8] Der wertvollste Fund des Tages: mein neuer Test kompilierte nicht (mutierende
Methode auf einem temporären Wert, Z. 128) — meine Python-Transkription liest Nadeln als Daten
und kann so etwas nicht sehen (CLAUDE.md Tests §4, fünfte Gestalt). Behoben `d82fb7b9f`, dazu der
Stop-vor-Start-Pfad (der Start beendet und landet seinen Take selbst, wenn die Karte inzwischen
verlassen wurde) und die Datenschutzseite (`d386c6ee1`). Kamera-Zwecktext in der Info.plist:
gesperrt, Patch liegt bereit — vor einer App-Store-Einreichung Pflicht. Neue Scheiben: AU-1
(AUv3-Spiegel atomar), AU-2 (samplegenaues MIDI im AUv3). Lehre: vor jedem Push eines Wächters
jede `VideoTakeLedger()`-artige Wert-Erzeugung auf `let`/Temporär-Mutation lesen.

## 2026-10-15 — Fremdes Modell: „Eventide H90 aus Echoelmusic steuern" — ADOPT→PRODUCT (2/6)
- Gemessen: MIDI-Clock (0xF8) stimmt und ist gebaut (HW-1 Host-Zeit, HW-2 SPP + Continue).
- Lücke bestätigt: die App sendet KEIN Program Change (0xC0 nur im MIDI-Datei-Export) und KEINE
  Parameter-CCs (nur MPE CC74, Panic CC123, RPN) → HW-8 (Program Change je Abschnitt) und HW-9
  (Modulations-Matrix → CC out).
- WATCH: Tonart/Skala per CC oder Noten an den H90 — ob der H90 das annimmt, steht nicht im Repo.
- REJECT: OSC→MIDI-Brücke — CoreMIDI-Ausgang existiert nativ, ein zweiter Weg wäre eine Kopie.
- UNVERIFIZIERT: die Menü-Schritte am H90.
- Was die Quelle übersah: Clock UND Performer-Noten gehen an JEDES CoreMIDI-Ziel — am H90 per USB
  kämen Noten ungefragt an → HW-7 Ziel-Auswahl zuerst. Und: ein USB-C-Port am iPhone — H90 und
  Xone beide per USB heißt Hub, oder das Xone reicht USB-MIDI an seine DIN-Buchse durch (ungemessen).

## 2026-10-15 — Gemini: Live-Rig Xone:96 + H90 + iPhone + Echoel AI — ADOPT→PIPELINE (2/6)
- Stimmt am Repo: Clock auf Host-Zeit (HW-1, heute) · 128-Frame-Puffer als Latenz-Option „Ultra".
- Stimmt heute NICHT: Mehrkanal-Ausgang der App (Graph auf Stereo, HW-5 geplant) · KI hört den
  Mixer (kein Audio-Eingang seit #1302; E10-1/J0 offen in der Inbox) · Live-Tonart/BPM per CoreML
  (kein CoreML, Tonart nur offline auf importierten Dateien) · PC/CC/Noten an den H90 (HW-8/HW-9).
- Erfunden: die CC-Nummern 11/12/21/22 (H90-Zuweisung ist frei; CC11 ist MIDI-Expression).
- Übernommen als Setup-Anleitung (Gerätedaten, hier nicht prüfbar): aktiver USB-C-Hub mit Netzteil,
  H90 Dual Routing, Line-Pegel, Kill Dry ON, Sends post-fader, Return-Low-EQ absenken.
- Offen am Gerät: reicht der H90 per USB empfangenes MIDI an seine DIN-Thru (TR-8S-Kette) durch?

## 2026-10-15 — ECC (everything-claude-code) v2.2.3 erneut gesichtet — ADOPT→PIPELINE (Muster), REJECT (Paket)
- Nur gelesen (Klon `b92f181`, 11.10.), nichts ausgeführt. MIT. Neu seit Juli: GateGuard (Fakten
  vor der ersten Änderung einer Datei), delivery-gate (Stop-Hook gegen Ausreden), config-protection.
- Gemessen: 16 MCP-Server per `npx -y`, 3 davon `@latest`; Lern-Daemon per `nohup`, der im
  Hintergrund `claude --print` aufruft; Selbst-Updater; Sponsor-Aufrufe → Paket bleibt verboten.
- Muster zum Selbstbauen: (1) Fakten-Gate vor der ersten Änderung an `Sources/**/*.swift` (ECCs
  eigener Pilot: ~45 % mehr Schritte, Nutzen nicht belegt → nur opt-in und gemessen); (2) Stop-Hook,
  der vor „pre-existing" / „kann ich lokal nicht prüfen" ohne Gate-Ergebnis warnt; (3) Konfidenz-Spalte
  im HARNESS_LEDGER. Hooks ändern jede Sitzung → Founder-Frage E33.

## 2026-10-15 — Grok: Auftrag G, das Deep Audit angreifen — ADOPT→PIPELINE (4/5)

Gemessen: Founder-Notiz „kleines Gimmick" stimmt (decisions.csv); `main` öffnet noch auf dem Stück
(`StudioDefaultKeys` `.piece` auf `2d8d8b11f`, der Zweig hat `.instrument`); Export/MIDI-Out existieren;
der blinde Fleck ist echt. Falsch: „357 offene Geräteprüfungen" — `founder-verify.py` zählt heute 371.
Ungeprüft: „kein Instrument mit Retention auf Kamera-rPPG" (plausibel, ohne Quelle). Sein 14-Tage-Satz
ist schon unterwegs (Kandidat A + Gerätesitzung 1). Übernommen: der blinde Fleck als drei Felder im
Gerätebogen (Licht + Sekunden bis zum Lock · WAV in einer DAW gehört · „morgen wieder öffnen?"). Kein Code.

## 2026-10-15 — ChatGPT: Physik-Short „Zeit" + Zeitwege im Repo — ADOPT→PIPELINE (6/6)

Physik: Kunst-Impuls, kein Beleg. Repo-Aussagen alle bestätigt. Selbst gefunden: eine Kamera-Aufnahme
landet heute hinter dem letzten Teil (`nextStartTick`), nicht an der Song-Stelle — es gibt keinen
Anker; `TempoMap.tick(atSeconds:)` liefert bei NaN eine 0 (stille Tick-0-Platzierung). Multicam-Plan:
zwei „höchstens ein Bild"-Zusagen als überholt markiert, Verträge 7–10 ergänzt. Vorschlag M1b-0
(reiner `TakeAnchor`). Bericht: `reports/ZEIT_EMERGENZ_ECHOELMUSIC_2026-10-15.md`.

## 2026-10-15 — Fünf KI-Mockups (Arrange · Mixer · Instrument · Device · Noten-Editor) — ADOPT→PRODUCT

Keine App-Screenshots, sondern Entwürfe. Übernommen: Werkzeug-Modi im Noten-Editor (EP-3b),
Noten-Inspektor Start/Dauer/Tonhöhe (N-F1), Teilleiste Start/Länge/Snap (EP-4), Device-Zeile
Öffnen·Umgehen·Entfernen (H6-6). Abgelehnt: Schieberegler, Deko-Text, Eyebrow-Überschriften,
eigene Leisten je Seite, Vocal/Lyrics/Echoel-als-Delay, lila Akzent. Details:
`reports/Design-Input ChatGPT und Grok (2026-10-15).md` §4.

## 2026-10-16 — Grok: GSI-Recherche + Audit — ADOPT→PRODUCT (5/6)

Founder-Paste, read-only, Repo-Kontext unklar. Fünf von sechs Behauptungen gemessen bestätigt
(PLAN_GMMW:392 DO NOT RESTORE · CLAIMS.md ohne „Describe this piece" · PerformerSignature im
Backup-Kanal, als Abwägung dokumentiert, 5.1.3-Konformität UNVERIFIZIERT → Anwalt/Founder ·
„EchoelAI — " auf deterministischem Text, `BioMusicDirector.swift:285` = GM9/AI-8 · kein Wächter
nannte „superintelligence"). TEILWEISE: die Stem-Trennung ist auf `faq.html`/`overview.html` als
Planned markiert, nur „in active development" überbehauptet — das ist CL-15, Founder-Gate. Eigener
Nebenbefund: `faq.html` „On-device AI is on the roadmap, not in the app today" könnte seit
„Describe this piece" UNTER-behaupten. **Übernommen, genau eins:** superintelligence/quantum im
Satz-Wächter `TheCopyMakesNoHealthClaimTests` (353e14f), Verneinung bleibt erlaubt. Abgelehnt: das
„EchoelAI"-Präfix vor AI-8 umbenennen (Grok sagt selbst: erst nach AI-8). Quelle lohnt die Messung:
präzise Zeilenangaben, eine Teil-Überbehauptung.

## 2026-10-16 — ChatGPT: korrigierter Auftrag „Website und TestFlight im laufenden GSIMMW-Ausbau" — ADOPT→PRODUCT (4/4)

Founder-Paste, ChatGPT hatte den Zweig bei `81ebe64` gelesen (kein Code-Audit, kein Gerät). Kern: der
GSIDMMW-Ausbau bleibt führend, keine vorgeschaltete Beta-Phase. Gemessen und übernommen: (1) die
C2-Kollision (SESSION_LOG „C2" = Share as MIDI, Audit „C2" = Planer-Tür) → Präfix-Regel im Audit;
(2) die Planer-Tür fehlte → GSIDMMW-C2a (`8e0299e`, Vorschlag → Apply/Discard → Undo) und C2b
(`39f954d`, „Ask Echoel"-Intent); (3) FEATURE_STATUS §1b stand auf „Leer." bei fünf Fähigkeiten auf
dem Zweig → nachgetragen, Audit-Tabelle trennt gebaut / im Build / erreichbar / Gerät; (4) Geräte-
Bitte G11 in FOUNDER_INBOX. Nicht übernommen: Website-Beleg aus gestellten Screens — er wartet auf
einen echten Gerätelauf. Formulierungen der Quelle nicht übernommen.
