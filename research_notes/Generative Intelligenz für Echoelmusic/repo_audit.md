# Repo audit — generative / "intelligence" capabilities in Echoelmusic

Measured 2026-10-16 on branch `claude/echoelmusic-review-optimize-u5jjpd` @ `4dbcfc6`.
Read-only inspection. "ext refs" = non-comment references outside the declaring file
(`git grep -nw <Type> -- Sources | grep -v ': *//' | grep -v <decl-file>`), so a name mentioned
only in prose does not count. Classes: **LIVE** (reachable door) · **CORE, NO CALLER** · **PROSE ONLY**.

## 0. Headline facts

- **Zero ML frameworks.** `git grep -ln "^import X\|canImport(X)" -- Sources` for CoreML, MLX,
  NaturalLanguage, CreateML, Vision, SoundAnalysis, Speech → **0 files each**. The only model
  framework is **FoundationModels** (3 files: `Core/OnDeviceModelGate.swift`,
  `EchoelAI/FoundationModelsBrain.swift`, `Sequencer/BioMusicDirector.swift`), always behind
  `#if canImport(FoundationModels)` + `#available(iOS 26)`.
- **Zero HTTP.** `URLSession|URLRequest` in `Sources/` → 0 hits; the only network code is UDP
  (`NWConnection`) in 5 `Sync/` senders/receiver (OSC, ADM-OSC, Art-Net, sACN, OSC-in).
  `Package.swift` `dependencies: []`. No cloud provider exists in code.
- **All music generation is deterministic, rule-based and seeded** (SplitMix64 `SeededRNG`,
  `Sequencer/BioComposer.swift:52`). No Markov chain, no learned weights:
  `git grep -in "markov\|euclid" -- Sources | grep -v ': *//'` → 0.
- **One live LLM call path exists**: ≡ menu → "Describe this piece" (`Studio/WorkspaceView.swift:604`)
  → `AgentReportBanner.describePiece()` (`Studio/AgentReportBanner.swift:62-64`, the ONLY
  `FoundationModelsBrain(` construction) → `EchoelAgentDesk.describePiece` (`EchoelAI/EchoelAgentDesk.swift:311`).
  Read-only, bio-free prompt, iOS 26 + Apple Intelligence only; NEEDS device verify
  (`docs/dev/FEATURE_STATUS.md:50`, build 2622, "offen").
- `FeatureFlags.echoelAI`: `git grep -n "FeatureFlags.echoelAI" -- Sources | grep -v ': *//'` → **0**. Never a gate (decisions.csv row 2026-10-08 "FeatureFlags.echoelAI is never a gate").

## 1. Rule-based composer (the generative core) — LIVE

| Component | File | Evidence / caller | Class |
|---|---|---|---|
| `BioComposer.compose(_ Input) -> BioComposition` | `Sequencer/BioComposer.swift:1000` (3095 lines) | 4 production calls: `Studio/EchoelStudioView.swift:10840` (`generate()`), `:11003` (per-bar), `Sequencer/LaneComposerInput.swift:80`, `Sequencer/BioVariationMaze.swift:185` | LIVE |
| Inputs (`Input`, `:212`) | | `heartRateBPM, hrvNormalized, coherence, breathPhase, breathDepth, key: MusicalKey, style: MusicStyle, mode: ComposerMode, lockedTempo, mood: MoodProfile, seed, structureSeed, progressionPhase, voiceLeading, humanize, suggestJourney, idiomVariation, variationNonce` (+ pad dials) | |
| Output (`BioComposition`, `:182`) | | `notes: [Note]`, `drumSteps/drumAccents` 8×16, `suggestedTempo`. Drums forced silent: `generate()` uses `BioComposer.silentBeat()` (EchoelStudioView ~`:11060`, founder 2026-07-07 "Beat komplett raus") | |
| Determinism | header `:8-10` | "PURE and SEEDED — same inputs + seed produce the same music" | |
| `MusicStyle` (genre identity) | `Sequencer/MusicStyle.swift` (3472 lines) | **58 cases, 41 in `MusicStyle.offered`** (`:139`; python count, comments stripped) — matches `HISTORY_ARCHIVE.md` M1 | LIVE |
| `MoodProfile` (8 dims: liveliness, darkness, tension, romance, weird, virtuosity, syncopation, humanize) | `BioComposer.swift:79-86` | ext refs 17 in 6 files; `MoodPreset`/`MoodPresetStore` save/recall | LIVE |
| `MusicalKey` / `Scale` | `Sequencer/MusicalKey.swift` | **57 scale cases**; every pitch via `MusicalKey.degree` (BioComposer header `:17`) | LIVE |
| `ChordSuggest` (function-aware chord ranking, H2) | `Sequencer/ChordSuggest.swift` | 6 call sites inside BioComposer (`:1734, 2395, 2632, 2685, 3032, 3075`) | LIVE (internal) |
| `VoiceLeader` (min-movement voicing, H1) | `Sequencer/VoiceLeader.swift` | BioComposer `:2699`, ChordSuggest, RollChordStamp | LIVE (internal) |
| `BassGrammar` / `PadGrammar` (one authored figure per genre) | `Sequencer/BassGrammar.swift`, `PadGrammar.swift` | BioComposer `:1724, 2346, 2352` | LIVE (internal) |
| `GenreIdiom` (per-take legal option inside genre) | `Sequencer/GenreIdiom.swift` | enum `GenreIdiom`/`GenreIdiomProfile`/`VariationEnvelope` → 0 ext refs; **`IdiomControl` is used** (BioComposer `:499, 504, 2359`) | partly LIVE via `IdiomControl` |
| `RoleRhythm` (rhythm per sound role) | `Sequencer/RoleRhythm.swift` (1017 lines) | 47 ext refs / 5 files | LIVE |
| `Humanizer`, `ArpFigure`, `BreathArp` | Sequencer/ | 9/3, 8/1 (FieldAutoPlay), 3/3 ext refs | LIVE |
| `BioComposer.tempo(for:)` | `:608` | Flow = `min(max(hr,40),160)`; T1–T3 invariant guarded by `Tests/CISmoke/TempoInvariantTests.swift` | LIVE |
| `BioVariationMaze` ("idea-maze": N seeded variations, scored vs bio driver, leaderboard) | `Sequencer/BioVariationMaze.swift` | Door: "Explore variations" button `Studio/EchoelStudioView.swift:3919` (`exploreVariations()`), in `tempoToolsPanel` | LIVE |
| `LaneComposerInput` + `TrackCompose` (per-track composer, "Compose here") | `Sequencer/LaneComposerInput.swift`, `Studio/TrackComposeRows.swift` | EchoelStudioView `:11362`, TrackComposeRows `:74,98`; agent command `track.composeHere` | LIVE |
| `FieldAutoPlay` (field plays itself, arp walk) | `Sequencer/FieldAutoPlay.swift` (810) | 18 ext refs, Motion picker EchoelStudioView ~`:5685` | LIVE |
| `AutoAttune` (Auto mode, steers mood dials from body state) | `Sequencer/AutoAttune.swift` | EchoelStudioView `:221, 1681, 7390, 10699` | LIVE |
| `RollChordStamp` (coherence-chosen voice-led chord on tap) | `Sequencer/RollChordStamp.swift` | refs only in `Studio/PianoRollView.swift:560,590` (PianoRollModel file; editor struct deleted #475) — reachability not traced further | UNCLEAR |
| `NoteTransform` (Strum/Humanize) | `Sequencer/NoteTransform.swift` | 0 ext refs | CORE, NO CALLER |
| `BioTempoDirector` ("Follow pulse" twin of live servo) | `Core/BioTempoDirector.swift:39` | 0 ext refs (CLAUDE.md register warns it is a twin) | CORE, NO CALLER |
| `ClipHighlightSelector`, `SampleSlicer` | Core/, Sequencer/ | 0 ext refs each | CORE, NO CALLER |
| `SoundPrompt` (keyword→SynthPatch, no LLM) | `DSP/SoundPrompt.swift:30` | Door: `SoundPromptRow(` `Studio/EchoelStudioView.swift:8259` ("Describe it" in soundPanel) | LIVE |

**Where composer output lands.** Live loop: `pianoRoll.loadArrangement(bars, …)` (PianoRollModel,
sound path). Mirror into the timeline: `syncPrimaryRollClip` → `ClipStore.updateComposerMelody(id:notes:)`
(`Core/ClipStore.swift:134`, accepts only `composerOwned` MIDI clips; EchoelStudioView ~`:11459`).
Composer clips are "shown, not edited": `TimelineStore.setClipNotes` refuses them
(`Core/TimelineStore.swift:557` via `ClipNoteEdit.acceptsEdits`); "Edit a copy"/`keepTake` converts to user-owned.
Evolve re-seeds every ~25–45 s (`evolveShouldReseed`, EchoelStudioView `:10432`).

## 2. EchoelAI / language layer

| Type | File | Callers (comment-stripped) | Class |
|---|---|---|---|
| `EchoelCommand*` (typed command registry: `project.describeState`, `track.setLevel`, `part.duplicateAfter`, `agent.undoLast`, `media.applyLook`, `take.keep`, `track.composeHere`) | `EchoelAI/EchoelCommand.swift:32-48` | parser/specs, permissions `readOnly`/`reversibleEdit`/`explicitConsent(publish,sendOrUpload,deleteOriginal,overwriteExport)` `:96-110` | LIVE (via desk) |
| `EchoelCommandExecutor` | `EchoelAI/EchoelCommandExecutor.swift` (708) | ONE construction `EchoelmusicApp.swift:667` (bound into desk) | LIVE |
| `EchoelAgentDesk` (Siri/Shortcuts mailbox, notice, undo) | `EchoelAI/EchoelAgentDesk.swift` (420) | `EchoelmusicApp.swift:665,667,1780,1869`; `Studio/EchoelAppIntents.swift:117`; `AgentReportBanner` | LIVE |
| App Intents (Start/Stop session, Keep last loop, ChangeSelectedTrackLevel, CopySelectedPart, KeepSelectedPart) | `Studio/EchoelAppIntents.swift:38-148` | typed, **no model, no keyword matcher** (`EchoelAgentDesk.swift:12-16`) | LIVE (device verify open, `ContentPipeline/CLAIMS.md:81`) |
| `BrainBackend` protocol | `EchoelAI/BrainBackend.swift` | 1 conformer (FoundationModelsBrain); used as param of `describePiece(with:)` | LIVE |
| `FoundationModelsBrain` | `EchoelAI/FoundationModelsBrain.swift` | `Studio/AgentReportBanner.swift:63` only | LIVE (iOS 26) |
| `OnDeviceModelGate` (ONE availability reader; on-device only, never PCC/3rd party) | `Core/OnDeviceModelGate.swift:46` | FoundationModelsBrain, BioMusicDirector, desk | LIVE |
| `EchoelLanguageModel` / `DeterministicLanguageModel` / `EchoelAIRouter` (modes deterministic/onDevice/cloudOptIn; `PromptBudget` 4096-token fit) | `Core/EchoelLanguageModel.swift` | `EchoelAIRouter(` → 0 constructions; no cloud conformer exists | CORE, NO CALLER |
| `BioMusicDirector` (@Generable `MusicDirection{genre,mood,space}` from bio adjectives) | `Sequencer/BioMusicDirector.swift:353` | 0 ext refs; `BioDirectionFallback.direction` 0 callers | CORE, NO CALLER (tests: `Tests/EchoelmusicTests/BioMusicDirectorTests.swift`) |
| `BioStateSummary` (adjectives only, nil = unmeasured) | same file | used by director | CORE, NO CALLER |
| `BioExplanation` (deterministic narration, prefix "EchoelAI — ") | same file `:144` | `EchoelStudioView.swift:11158, 11164, 11477`; strings `Localizable.xcstrings:16842,16852` | LIVE — but the "EchoelAI" label is on deterministic text (open founder Q GM9/AI-8) |
| `EchoelParameterRegistry` | `Core/EchoelParameterRegistry.swift` | constructed `EchoelmusicApp.swift:440`, seeded with DDSP + Lighting + Visual catalogs `:441-450` | LIVE (as registry) |
| `ParameterToolCore` (list/search/set tool logic) | `EchoelAI/ParameterToolCore.swift` | `ParameterToolCore.` → 0 | CORE, NO CALLER |
| `Resources/EchoelAI/echoelai-vocabulary.json` | | only a doc-comment mention (`EchoelParameterRegistry.swift:68`) | PROSE / data without reader |
| AI-5 `PlannerContext` / `BioEgressPolicy.allowsPlannerContext`; AI-7 `agentEligible` / `applyAgent` / `parameter.set` | planned `scratchpads/PLAN_GMMW_2026-10-08.md:555-557, 1224-1252` | each → 0 hits in Sources | PROSE ONLY (founder-gated GM10) |

"Describe this piece" prompt: `EchoelAgentDesk.describePrompt` (`:361-365`) wraps
`EchoelStateText.describe` (`EchoelCommandExecutor.swift:680-702`): selected track name/device/level,
part span, counts, media-card flags — **no bio, no key/genre/tempo**. Answer capped at 600 chars (`:356`).

**Stale doc found:** `docs/dev/HISTORY_ARCHIVE.md` §M row M2 still says the EchoelAI shell has
"zero callers" — false since AI-4 (FoundationModelsBrain ← AgentReportBanner) and AI-1/2 (executor).

## 3. Generative visuals, light, space

| Component | Evidence | Class |
|---|---|---|
| `MetalBioView` — inline-compiled fragment shader `echoel_bio_fragment` (`Views/MetalBioView.swift:2856`, 3169 lines); 10 field generators: Aurora, Chladni, DepthCaustics, Dish, Fractal, Lissajous, Prism, Rings, Scope, Water | uniforms `hr, coherence, breath, toneHz, intensity, ringDensity, motion, spread, pulseHz, hueShift, saturation …`; colour = sounding pitch → light (`:12-24`) | LIVE |
| `BioVisualParams` (flash-safe body→image map) | read by MetalBioView (CLAUDE.md "NOW WIRED") | LIVE |
| `FaradayDish` (standing-wave lattice for fieldDish/fieldWater) | `Core/FaradayDish.swift` | LIVE |
| `FluidSurfaceMath` (2-D wave eq., Fluid F1) | `Studio/FluidSurfaceMath.swift:14` "NO CALLER YET, ON PURPOSE" until F3 GPU twin; 0 ext refs | CORE, NO CALLER |
| `VisualModulation` | 0 ext refs (CLAUDE.md register) | CORE, NO CALLER |
| `MediaSeed` (photo → dominant colour/brightness/saturation/contrast, pure) → `MediaSeedLook`/`MediaLookUndo` | `Core/MediaSeed.swift`; PhotoSeedCard/VideoSeedCard (ImageIO); agent command `media.applyLook` | LIVE (deterministic image analysis) |
| `LightingStore` (creative lighting state) + `MusicMediaMap` (MusicalFrame → DMX RGB / ADM-OSC position) | `Core/LightingStore.swift`; `Sync/MusicMediaMapping.swift:17` used by ArtNet/sACN/ADM senders | LIVE |
| `SpatialSceneStore` → ADM-OSC out | `Core/SpatialSceneStore.swift` | LIVE (control half) |
| Spatial render half (VBAP, Ambisonics, BinauralPanner, SpaceReverb, LightFixtureGroup, BioPhaser, SpatialAutomationMapping), `BioSpaceMap` | CLAUDE.md register, guard `TheSpatialRenderHalfIsNotClaimedLiveTests` | CORE, NO CALLER |

## 4. Analysis / signal intelligence (no ML, all DSP)

- Import analysis LIVE: `Studio/WorkstationView.swift:596-597` runs `AudioKeyAnalysis.analyse` (→ `DSP/PitchTracker` YIN → `Core/TuningDetector`) and `AudioTempoAnalysis.analyse` (onset envelope autocorrelation) off-main; **writes nothing** except `ClipStore.adoptDetectedNativeBPM`; key is reported, never applied (`SessionContext` stays owner).
- rPPG: `Video/CameraAnalyzer`, `RPPGConditioning`, `PulsePeriodEstimator`, `Bio/CameraRPPGBioPublisher` (LIVE); `Bio/HRVCoherence`, `RespirationEstimator`, `ResonanceFinder`, `PoincareMetrics`, `Core/CoherenceTrend` (LIVE).
- Protected triad: `BioEventGraph` (DELLY k-means) wired via `BioEventPublisher`; `BioSignalDeconvolver`, `HilbertSensorMapper` 0 callers (CLAUDE.md).

## 5. Seams for a generative model / agent

(a) **Symbolic note writer.** Two existing writers, two ownership classes:
  - composer-owned: `ClipStore.updateComposerMelody(id:notes:)` (`Core/ClipStore.swift:134`) — overwritten by evolve, no undo.
  - user-owned: `TimelineStore.setClipNotes(clipID:_:clips:)` (`Core/TimelineStore.swift:557`) — one undo step `.clipNotes`; 17 call sites all in `Studio/PartNoteEditor.swift`.
  - Data shape: `Note{id, pitch:Int, startTick, lengthTicks, velocity:Float}` with `ticksPerQuarter=480`, `ticksPerStep=120` (`Sequencer/Note.swift:91-104`); `MelodyClip{notes}` (`Sequencer/Clip.swift:19`).
  - Cleanest model seam: emit `BioComposer.Input` parameters (style/mood/seed) or a `[Note]` candidate into a NEW user-owned clip via the keep-take path (`TimelineStore` undo case `keptTake`, `:298`), so a model never touches the composer-owned clip.
(b) **Parameter setting.** `ParameterApplyRouter` (`Core/ParameterApplyRouter.swift`): `applyNormalized :97`, `applyReal :130`, `applyAutomation :197`, `automatableDescriptors() :210` (= registry ∩ bound setter; caller `Core/AutomationPlayer.swift:592`). Descriptors carry deny-by-default `automationEligible`/`modulationEligible` (`DSP/ParameterDescriptor.swift:92-140`); an `agentEligible` flag is planned (AI-7a), absent. Modulation routes: `ModulationEngine`, door `PatchbayView.modulationSection`. `ParameterToolCore.set` exists but is unbound and clamps (AI-7 says the agent path must refuse, not clamp).
(c) **Undo / transaction.** Song undo = `TimelineStore.pushUndo` with typed cases (`:285-298`: regions, clipNotes, automation, clipSource, laneMix, lanePatch, lightLook, laneSample, lanePlugin(Effect), cycle, keptTake). Agent undo = executor's own journal of exact inverses, per request, with "changed since" checks and replay de-dup (`EchoelCommandExecutor.swift` header `:15-35`). Any model action should be a registered `EchoelCommand` and go through `EchoelPlanning.plan` → executor (decisions.csv 2026-10-09: "the on-device model plugs in as another planner without a second path").
(d) **Privacy / egress.** `Core/BioEgressPolicy.swift` gates network senders by source (HealthKit-store data never leaves, App Store 5.1.3) and by `FieldClass` (`.derived/.clinical/.raw`, `:101`). `OnDeviceModelGate` header: AI features must never fall back to PCC or third-party. Model prompts today contain no bio. A planner bio context (adjectives only, opt-in default off, no cloud planner in v1) is founder question **GM10** (`docs/dev/FOUNDER_INBOX.md:125`).

## 6. Constraints written in the repo

- `docs/dev/FOUNDER_PRODUCT_LAW.md:43` "Intelligence | AI-assisted and AI-generative production" is in scope; `:48` integrate "AI providers"; `:66` trained models must be "real, bundled, measured models or provider APIs", not "CoreML-powered" code without a model.
- `docs/dev/HISTORY_ARCHIVE.md` §M: M1 deterministic tools (BioComposer, ChordSuggest, BioVariationMaze, SoundPrompt, key/tempo detection) — **"never call these 'AI' in copy"**; M3 old LLMService (Anthropic/OpenAI/Ollama) "would have sent bio context to the cloud" → port only through `BioEgressPolicy` + consent; M4/M6/M8 fake CoreML, fake Demucs, SuperIntelligence/Quantum — DO NOT RESTORE; M5 Markov/Euclidean AIComposerEngine → port algorithm; M9 legitimate future: Foundation Models, provider adapters, real stem separation, audio-to-MIDI.
- decisions.csv: 2026-06-17 (theory hand-encoded, not corpus ingestion; on-device AI explains); 2026-06-20 ("Super Intelligence AI" overclaim stripped from locales); 2026-07-09 (AI interactive not proactive); 2026-07-12 (EchoelAI = later command layer for composition wishes/settings/routing/songwriting); 2026-10-08 ×2 (generative audio "never labelled AI", no microphone; EchoelAI is an ACTION not a place, FM only behind gate + tap); 2026-10-09 (Siri first door, typed intents, model = another planner).
- CLAUDE.md BRAND: claim only what ships; no wellness/esoteric; `ContentPipeline/CLAIMS.md` §11 forbids "AI voice"/voice cloning/TTS claims (`:356, 383`). No microphone input exists (#1302) — any audio-in model has no input graph.
- Open founder gates: GM8 (keep Siri door), GM9/AI-8 (rename "EchoelAI —" on deterministic narration), GM10/AI-5 (body adjectives to planner, cloud planner), GM11 (cloud generative video/neural audio, cost/privacy).
- Engineering: audio thread bans; zero deps; new dependency/target founder-gated; DSP/ Foundation+Accelerate only (AUv3 compiles it in isolation).
