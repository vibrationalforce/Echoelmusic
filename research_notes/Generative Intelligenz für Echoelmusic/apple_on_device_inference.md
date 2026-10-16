# Apple On-Device Inference Stack for Generative Models in a Real-Time Audio App (iPhone first; iPad/Mac/Vision Pro later), state 2025–2026

Research date: 2026-10-16. Scope: Foundation Models framework, Core ML / Core AI, MLX Swift, BNNS Graph, MPSGraph, device budgets, distribution limits, App Review and EU AI Act, shipping music-app examples.

Source legend: **[DOC]** = Apple documentation or WWDC session page fetched this session. **[PRESS]** = trade press. **[BLOG/FORUM]** = third-party claim, unverified. **[TRAINING]** = from model training knowledge (pre-June-2026), NOT re-fetched this session. The URL is given so the writer can check it; treat as lower confidence. `machinelearning.apple.com` and `dafx.de` failed DNS resolution from this sandbox, so the Apple tech report and the DAFx26 paper were seen only as search snippets.

---

## 1. Apple Foundation Models framework (iOS 26 → iOS 27)

### Takeaway
A roughly 3B-parameter, heavily quantized on-device LLM reached through a Swift API (`LanguageModelSession`, `@Generable` guided generation, `Tool` calling). Context window: 4096 tokens in iOS 26. The iOS 27 cycle (WWDC26) rebuilt the model, added image input, and added a Private Cloud Compute model with a 32K context. The on-device model only runs on Apple-Intelligence-capable devices (iPhone 15 Pro and later). It suits small structured tasks (classification, extraction, picking parameters from a schema). It is not a music or audio generator, and it does not belong anywhere near the render thread.

### Cited Findings
- The context window is **4096 tokens per `LanguageModelSession`**. Instructions, all prompts, tool schemas with their inputs and outputs, `Generable` schemas and all responses count against it. Exceeding it throws `LanguageModelSession.GenerationError.exceededContextWindowSize`. One token is about 3–4 characters in Latin-script languages. The TechNote was revised 2026-03-31 for the 26.4 API. — [DOC: TN3193](https://developer.apple.com/tutorials/data/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window.md)
- Apple's guidance in TN3193: give the model at most **3–5 tools**, keep tool and `@Guide` descriptions to a short phrase, call the tool directly instead of tool calling when its output is always needed, cap arrays with `.maximumCount`, and split large tasks across new sessions. `maximumResponseTokens` can produce malformed partial output. Use `tokenCount(for:)` and the Foundation Models instrument in Instruments to measure token use. — [DOC: TN3193](https://developer.apple.com/tutorials/data/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window.md)
- **iOS 26.4** introduced `SystemLanguageModel().contextSize` and `tokenCount(for:)`. The WWDC26 session's example prints `contextSize` as **8192**. The on-device model is "rebuilt from the ground up" with better tool calling. — [DOC: WWDC26 session 241](https://developer.apple.com/videos/play/wwdc2026/241/)
  - **Conflict:** a WWDC26 Q&A video, as summarized by search, still quotes 4096 tokens on-device (shared input and output). Use the runtime `contextSize` value; do not hard-code either number. — [DOC: WWDC26 8121](https://developer.apple.com/videos/play/wwdc2026/8121/) (via search summary only)
- New in WWDC26: **`PrivateCloudComputeLanguageModel`** with a **32,000-token** context and a reasoning level (`.light` / `.deep`). It needs no API keys and stores no prompts. It costs developers nothing below **2 million first-time downloads**, needs an entitlement, and is available on watchOS 27. Other additions: image `Attachment`s (UIImage, CGImage, CVPixelBuffer, …), built-in `OCRTool`, `BarcodeReaderTool` and a Spotlight RAG tool, a `LanguageModel` protocol (open-source `CoreAILanguageModel` and `MLXLanguageModel` back-ends; Anthropic and Google publish Swift packages), `DynamicProfile`, an Evaluations framework, an `fm` CLI on macOS 27, and a Python SDK. — [DOC: WWDC26 session 241](https://developer.apple.com/videos/play/wwdc2026/241/)
- About 3B parameters with 2-bit weights. Intended for summarization, extraction and classification; not designed for world knowledge or advanced reasoning. Runs on iPhone 15 Pro and later (A17 Pro+), M1+ Macs and M-series iPads. — [BLOG: atelier-socle](https://www.atelier-socle.com/en/articles/foundation-models-api-guide); [BLOG: drobinin](https://drobinin.com/consulting/foundation-models-apple-intelligence/putting-apple-foundation-models-in-a-real-app/); consistent with [DOC: WWDC25 286 "Meet the Foundation Models framework"](https://developer.apple.com/videos/play/wwdc2025/286/)
- [TRAINING] Apple's 2025 tech report "Apple Intelligence Foundation Language Models Tech Report 2025": about 3B parameters, 2-bit quantization-aware training, and a KV-cache-sharing split that reduces KV memory by about 37.5%. Custom **LoRA adapters** (rank 32) are trained with Apple's Python "adapter training toolkit". An adapter must be **retrained for every base-model version**, and shipping one needs the *Foundation Models Framework Adapter Entitlement*. Adapters are about 160 MB each and are best delivered through Background Assets. — [Apple ML Research](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates) (fetch failed: DNS), [developer.apple.com/apple-intelligence/foundation-models-adapter/](https://developer.apple.com/apple-intelligence/foundation-models-adapter/)
- Availability in the EU and Germany: Apple Intelligence went live in all EU member states with **iOS/iPadOS 18.4 (April 2025)**, adding German, French, Italian, Spanish, Japanese, Korean, Simplified Chinese and Brazilian Portuguese. Reports disagree on Mac language support at that time. — [PRESS: heise](https://heise.de/-10334964); [mjtsai](https://mjtsai.com/blog/2025/04/03/apple-intelligence-available-in-eu)
- [TRAINING] The framework exposes `SystemLanguageModel.default.availability` with reasons `.deviceNotEligible`, `.appleIntelligenceNotEnabled` and `.modelNotReady` (model still downloading). The user must turn on Apple Intelligence, and the device and Siri language must be supported. — [DOC: SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- Guardrails: tuned in iOS 26.4 to reduce false positives, with more changes in iOS 27. — [DOC: WWDC26 241](https://developer.apple.com/videos/play/wwdc2026/241/)

### Inferences
- **What fits Echoelmusic:** turning natural-language or bio-state input into a `@Generable` struct, for example `{genre, key, scale, density, bpmLockSuggestion}`, or choosing among 3–5 tools that wrap `ParameterApplyRouter` or `EchoelParameterRegistry`. The output is a small control-plane value written to `EngineBus`, never audio.
- Generating MIDI or note tokens with it is possible in principle, through a `Generable` array of notes. The 4K/8K context and ~3B general-purpose weights make long-form composition weak, though, and nothing suggests it was trained on music. The existing in-house music-theory generators stay the producers.
- Respond latency is seconds-scale and runs as `async` on a non-real-time thread. The result should be consumed at the existing ~1 Hz / user-gesture cadence, never per render cycle.
- Coverage gap: iPhone 15 (non-Pro), 14 and older get nothing. A feature built on it needs a deterministic fallback, and that fallback is the shipping product.
- Prompts and results stay on-device, so the 5.1.2(i) third-party-AI disclosure (Section 4) arguably does not apply. PCC and the partner-model back-ends change that analysis.

### Gaps
- No official published tokens/s or time-to-first-token for the on-device model on iPhone 15/16/17 was found. Measure it with the Foundation Models instrument.
- Whether the iOS 27 on-device model differs in parameter count was not stated in session 241. One blog's "~20B" claim is unverified and was not used.
- Whether the adapter toolkit and entitlement continue unchanged for the iOS 27 base model was not confirmed this session.

---

## 2. Core ML / Core AI, MLX Swift, BNNS Graph, MPSGraph — and what is safe near the audio thread

### Takeaway
**BNNS Graph is the only Apple inference API documented to be real-time-safe on the audio thread.** On CPU, with a precompiled graph, a preallocated page-aligned workspace and single-thread compile, Apple documents no allocation and no thread hops at execute time, and Apple's own sample is an Audio Unit extension. Core ML (and its WWDC26 successor Core AI), MLX and MPSGraph dispatch to GPU or ANE asynchronously. They belong on a worker thread that feeds the render thread through a lock-free ring buffer, as the Echoel SPSC pattern already does.

### Cited Findings
- **BNNS Graph (WWDC24 "Support real-time ML inference on the CPU"):**
  - The graph is compiled once from a bundled `.mlmodelc` (`BNNSGraphCompileFromFile`), typically on a background thread.
  - The workspace is sized with `BNNSGraphContextGetWorkspaceSize` and allocated page-aligned before execution.
  - Max dynamic shapes are set up front (`BNNSGraphContextSetDynamicShapes`) so nothing reallocates. `BNNSGraphArgumentTypePointer` passes audio buffers directly.
  - **Execution is multi-threaded by default.** Real-time use requires `BNNSGraphCompileOptionsSetTargetSingleThread(options, true)`.
  - A context may execute on only one thread at a time; the demo uses separate contexts for the UI and the audio thread.
  - The demo is a bit-crusher inside an Xcode **Audio Unit Extension** template's C++ DSP kernel, calling `BNNSGraphContextExecute` per render.
  - It is at least 2x faster than the old BNNS primitives. Turn `NaNAndInfinityChecks` off in production.
  - The speaker notes that Swift itself does not guarantee real-time safety.
  — [DOC: WWDC24 10211](https://developer.apple.com/videos/play/wwdc2024/10211/)
- **BNNS Graph Builder (WWDC25 "What's new in BNNS Graph"):** graphs of operations can now be written directly in Swift, and the bit-crusher is re-implemented entirely in Swift. — [DOC: WWDC25 276](https://developer.apple.com/videos/play/wwdc2025/276/) (search summary)
- **Independent verification:** a DAFx 2026 paper reports that BNNSGraph compiles the whole graph ahead of time (fusion, weight repacking, copy elimination) and can run **in the audio thread** without the worker-thread buffering other frameworks need. The authors checked the no-allocation/no-lock claim with a real-time sanitizer. — [DAFx26 paper 16](https://www.dafx.de/paper-archive/2026/papers/DAFx26_paper_16.pdf) (search snippet only; full text unreachable)
- **Core AI (WWDC26):** announced as the successor to Core ML, aimed at on-device LLMs and generative models (converted PyTorch plus pre-optimized open models). It integrates with Foundation Models through the `LanguageModel` protocol. Pre-event reports said Core ML and Core AI may coexist for some time. — [PRESS: InfoQ](https://infoq.com/news/2026/06/apple-core-ai-wwdc); [PRESS: AppleInsider](https://appleinsider.com/articles/26/03/01/wwdc-2026-to-introduce-core-ai-as-replacement-for-core-ml). The open-source `CoreAILanguageModel` back-end is named in [DOC: WWDC26 241](https://developer.apple.com/videos/play/wwdc2026/241/). Details such as a ".aimodel" format appear only in low-quality sources and were not used.
- [TRAINING] **Core ML (iOS 18 / WWDC24):**
  - Stateful models (`MLState`, so the KV cache lives inside the model).
  - `MLTensor`.
  - Multifunction models (one base plus several LoRA functions that share weights).
  - Core ML Tools 8 compression: int4 per-block weight quantization, palettization (1–8 bit, grouped/per-channel LUT), pruning, and joint compression; activation quantization (W8A8) on ANE-friendly paths.
  - Compute units `.cpuOnly`, `.cpuAndGPU`, `.cpuAndNeuralEngine`, `.all`. The scheduler picks the ANE or GPU and gives no latency guarantee.
  - Prediction can be `async`.

  — [WWDC24 10159 "Bring your models to Apple silicon"](https://developer.apple.com/videos/play/wwdc2024/10159/), [WWDC24 10161 "Deploy ML and AI models on-device with Core ML"](https://developer.apple.com/videos/play/wwdc2024/10161/), [coremltools docs](https://apple.github.io/coremltools/docs-guides/)
- **MLX Swift:**
  - Community guidance says it runs on iOS through Metal, recommends the Increased Memory Limit entitlement, staying under about 60% of RAM, a cache limit (for example 512 MB), and unloading on background or memory pressure.
  - The Simulator cannot exercise Metal inference.

  — [BLOG: tessl mlx-swift skill reference](https://tessl.io/registry/dpearson2699/swift-ios-skills/3.9.0/files/skills/apple-on-device-ai/references/mlx-swift.md); [BLOG: strathweb, Phi on iOS with MLX](https://strathweb.com/2025/03/running-phi-models-on-ios-with-apple-mlx-framework/). An `MLXLanguageModel` back-end for Foundation Models was open-sourced at WWDC26 — [DOC: WWDC26 241](https://developer.apple.com/videos/play/wwdc2026/241/)
- [TRAINING] MLX is a GPU (Metal) array framework with lazy evaluation and unified memory. It has no ANE back-end and no real-time guarantee. Repo: [github.com/ml-explore/mlx-swift](https://github.com/ml-explore/mlx-swift).
- [TRAINING] **MPSGraph** compiles graphs to Metal (GPU). Command buffers are asynchronous; waiting on one is a blocking call, so it is unsuitable on the render thread. — [MPSGraph docs](https://developer.apple.com/documentation/metalperformanceshadersgraph)

### Inferences
- **Audio-thread rules for Echoelmusic:**
  1. On the render thread only BNNS Graph, with a single-thread compile, a preallocated workspace, preset max shapes and its own context. Call it from C or from Swift code that is already allocation-free. The Swift Graph Builder needs an RTSan or Instruments allocation check before it is trusted.
  2. Everything else (Foundation Models, Core ML/Core AI, MLX, MPSGraph) runs on a worker or `Task`, writes results into a lock-free SPSC ring (the existing `SPSCQueue`), and the render thread reads with no blocking.
  3. The GPU is shared with `MetalBioView`'s pinned 60 fps. GPU-heavy generation (MLX/MPSGraph) competes with the visual and should be gated by `ResourceGovernor` thermal state.
- BNNS Graph is a fit for small neural DSP: learned saturation, neural filters, tiny timbre-transfer or DDSP-control nets running per block. It is not a fit for multi-hundred-MB generative LLM or diffusion models.
- **AUv3 extension memory is far tighter than the app's** (see Section 3), and the Echoelmusic AUv3 compiles `DSP/` in isolation with Foundation and Accelerate only. BNNS is part of Accelerate, so a BNNS Graph kernel would not break the "DSP imports Foundation + Accelerate only" rule. Core ML/Core AI/MLX would add new framework imports to the extension.
- Zero-dependency policy: Foundation Models, Core ML/Core AI, BNNS and MPSGraph are system frameworks with no new package dependency. MLX Swift **is a Swift Package dependency**, which `Package.swift`'s `dependencies: []` and the Council rule would gate.

### Gaps
- BNNS Graph's supported-operator list, and which Core ML op set compiles to it, are not stated in the sessions reviewed.
- No measured latency numbers for BNNS Graph versus Core ML on A17/A18/A19 at audio block sizes; the DAFx26 tables were unreachable.
- Whether Core AI keeps BNNS Graph as its real-time CPU path, and Core ML's deprecation timeline, are unconfirmed.
- No primary source found on MLX Swift's minimum iOS version.

---

## 3. Practical budgets: RAM, thermals, model download and app size

### Takeaway
Plan for about **≤ 1–2 GB of model memory in the main app on 8 GB iPhones**, and treat the ~6 GB per-app ceiling observed even with the entitlement as an absolute upper bound. Ship models outside the binary through **Apple-hosted Background Assets** (up to 200 GB compressed per app, 100 asset packs). The **4 GB uncompressed app** limit makes bundling large models impractical anyway.

### Cited Findings
- `com.apple.developer.kernel.increased-memory-limit` is a Boolean entitlement that lets an app's core features exceed the default limit **"only on some device models"**. The app must still work without the extra memory. Use `os_proc_available_memory()` (advisory, do not cache, it changes during the app's lifecycle). — [DOC: entitlement](https://developer.apple.com/tutorials/data/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit.md); [DOC: os_proc_available_memory](https://developer.apple.com/documentation/os/os_proc_available_memory.md)
- One developer measured a flat **~6144 MB** ceiling with the entitlement on an iPhone 16 Pro Max (8 GB) and an iPhone 17 Pro Max (12 GB). The debugging memory-limit entitlement raised it to ~6656 MB. Extended virtual addressing made no difference. (FB23183521; no Apple answer.) — [FORUM](https://developer.apple.com/forums/thread/834805)
- Another report: about 15 GB available in a development build on an iPad, but **crashes around 6 GB after App Store distribution**. Test the shipped build, not only the development build. — [FORUM](https://developer.apple.com/forums/thread/770868)
- App Store build limits: **iOS/iPadOS/visionOS 4 GB maximum uncompressed app**, **500 MB total `__TEXT`**; **macOS 200 GB**; App Clip 100 MB (iOS 17+, digital invocation only). Larger content goes into Background Assets. — [DOC: Maximum build file sizes](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes/)
- **Apple-Hosted Background Assets:** up to **200 GB** compressed per app, a maximum of **100 asset pack IDs**, limits shared across platforms, available for TestFlight and App Store on all platforms except watchOS. The product page shows an "Up to" size that includes essential packs. — [DOC: asset pack size limits](https://developer.apple.com/help/app-store-connect/reference/apple-hosted-asset-pack-size-limits); [DOC: Downloading Apple-hosted asset packs](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs.md). The legacy On-Demand Resources limits page still exists: [DOC](https://developer.apple.com/help/app-store-connect/reference/on-demand-resources-size-limits/)
- [TRAINING] The Apple Intelligence model is downloaded and managed by the OS, so it does not count toward the app's size. `availability == .unavailable(.modelNotReady)` covers the download window. — [DOC: SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [TRAINING] Thermal: `ProcessInfo.thermalState` (`.nominal/.fair/.serious/.critical`) plus the `thermalStateDidChangeNotification`. Apple publishes no figure for sustained ANE/GPU throughput under throttling. — [DOC: ProcessInfo.ThermalState](https://developer.apple.com/documentation/foundation/processinfo/thermalstate)

### Inferences
- Budget against the project's own hard limits: memory under 200 MB target / over 300 MB FAIL (per `CLAUDE.md`). That is far below any LLM footprint. Running a ~1–4 GB model (MLX or Core AI) would mean revising those limits on purpose, or running the model only in non-performance moments with the audio graph idle. The system Foundation Model runs in its own memory space, which is a major argument for it over a bundled LLM. (Widely understood but **not verified this session**; see Gaps.)
- AUv3 extensions run under a much smaller jetsam budget than the host app (commonly cited in the low hundreds of MB; **no primary source found**). Generative models should live in the main app, not in `EchoelmusicAUv3`.
- Ship any custom model weights as Apple-hosted asset packs (non-essential, on demand), and keep the app binary small.

### Gaps
- No official per-device default jetsam limits (iPhone 15/16/17) or AUv3 extension limit were found; Apple documents none.
- Not confirmed whether Foundation Models inference memory is attributed to the app process or a system daemon.
- No official cellular-download threshold for Background Assets was found; the "200 MB cellular" claim from a third-party site is unreliable.

---

## 4. App Store Review Guidelines and EU AI Act obligations

### Takeaway
On-device-only generation triggers no AI-specific App Review rule beyond the usual content and UGC rules. **Guideline 5.1.2(i) (revised 13 Nov 2025)** requires explicit disclosure plus permission before personal data goes to **third-party AI**, which matters for bio data if a cloud model is ever used. Under the EU AI Act, **Article 50** transparency duties have applied since **2 Aug 2026**. The machine-readable marking duty for synthetic audio is deferred to **2 Dec 2026**, and only for systems already on the market before August 2026; new systems are covered immediately.

### Cited Findings
- 5.1.2(i), revised 13 Nov 2025: apps must clearly disclose where personal data is shared with third parties **"including with third-party AI"** and obtain explicit permission first. Apple has not clarified whether on-device or system models count. Vendor blogs read it as needing an in-app consent, not just a privacy-policy line; that is an interpretation, not Apple text. — [PRESS: TechCrunch](https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai); [BLOG: qawerk](https://qawerk.com/blog/apple-app-store-ai-data-sharing-guidelines/)
- [TRAINING] Other relevant guidelines: 1.1 objectionable content; 1.2 user-generated content (filtering, reporting, blocking) applies if generated content is shared inside the app; 2.3 accurate metadata (claiming AI features that do not ship is a 2.3 rejection, already Echoel practice); 5.1.1 data collection/consent; 5.1.3 health data (HealthKit data may not be used for advertising or shared without consent, which bears directly on sending bio data to any model); 4.7 for apps that run code or models downloaded at runtime (downloaded *weights* are data, not executable code, but behavior must not change to violate review). — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [TRAINING] Apple's Foundation Models acceptable-use requirements forbid certain uses of the framework (e.g., regulated healthcare diagnosis, unlawful content). — [developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework](https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/)
- EU AI Act: the Digital Omnibus (cited as Regulation (EU) 2026/1744, in force 27 July 2026) moved the Art. 50(2) machine-readable marking of synthetic audio, image, video and text from 2 Aug 2026 to **2 Dec 2026**, only for systems placed on the market before Aug 2026. Art. 50(1) (disclosing AI interaction) and deepfake labelling have applied since **2 Aug 2026** with no extension. — [BLOG: CSA research note](https://labs.cloudsecurityalliance.org/wp-content/uploads/2026/09/CSA_research_note_eu_ai_act_article50_watermarking_deadline_20260921-csa-styled.pdf); [BLOG: lobsterpack](https://www.lobsterpack.com/blog/eu-ai-act-omnibus-delay-2027/). These are secondary sources and disagree on whether the grace period is three or four months. Verify against the Official Journal.
- [TRAINING] Under Art. 50(2) the obligation sits with the **provider** of the generative system, meaning whoever places it on the market. A developer integrating Apple's model may still be the provider of their own system. Art. 50(2) exempts systems performing an "assistive function for standard editing" or not substantially altering input data. Art. 50(4) deepfake disclosure has an exemption for evidently artistic or creative works: disclosure is then limited to not hampering display or enjoyment of the work. — [EUR-Lex Regulation (EU) 2024/1689, Art. 50](https://eur-lex.europa.eu/eli/reg/2024/1689/oj)

### Inferences
- If Echoelmusic exports audio produced substantially by a generative model, it should plan a machine-readable mark, such as metadata in the exported file (ID3/BWF/iXML or C2PA). Because the app was on the market before August 2026, a newly added generative feature probably counts as a new system, but that is a legal judgement. Algorithmic, rule-based composition (today's in-house theory engine) is very likely not an "AI system generating synthetic content" in the Act's sense. That classification question needs a lawyer, not a session.
- Bio/HealthKit data must never go to PCC or partner models without explicit consent (5.1.2(i) plus 5.1.3). On-device Foundation Models avoids the third-party question.

### Gaps
- No Apple statement on whether the on-device Foundation Model counts as "third-party AI" under 5.1.2(i).
- The Official Journal text of 2026/1744 was not read directly.
- No guidance found on how the Act treats generated MIDI (symbolic) versus generated audio.

---

## 5. Shipping examples: on-device ML in iOS / AUv3 music apps

### Takeaway
Real-time on-device stem separation has shipped on iOS since 2020 (djay Neural Mix on Core ML and the Neural Engine). Apple's own Logic Pro for iPad 2 (May 2024) gates on-device Stem Splitter to M1 or later and recommends M-series for Session Players. That is a strong signal that heavy generative and separation models are M-class-iPad and Mac features, with iPhone getting lighter versions. No primary source was found for Moises's iOS processing location or for any AUv3 that ships an on-device generative model.

### Cited Findings
- djay Neural Mix (June 2020) splits vocals, beats and instruments in **real time** using **Core ML and the Neural Engine** (A12Z iPad Pro). The 2021 iOS update expanded it to four stems (vocal, harmonic, bass, drums) on newer devices. djay Pro 5 (Dec 2023) brought next-generation Neural Mix developed with AudioShake. — [PRESS: ipsnews/AppleInsider](https://ipsnews.net/business/2020/06/19/apples-neural-engine-tapped-in-new-djay-pro-to-reinvent-live-mixing/?amp=1); [PRESS: 9to5mac](https://9to5mac.com/2021/05/06/djay-pro-ios-update-taps-apple-neural-engine/); [PRESS: DJ Life](https://djlifemag.com/2023/12/algoriddim-unveils-djay-pro-5-0/?amp=1)
- A forum user claims djay adapts its separation algorithm to device compute. — [FORUM: Engine DJ community](https://community.enginedj.com/t/is-something-cooking/65709?page=2) (unverified)
- Logic Pro for iPad 2 / Logic Pro 11 (May 2024): Stem Splitter **requires M1 or later** on iPad and Mac (on-device). Session Players: **M-series recommended** on iPad. — [Apple press release via BusinessWire](https://www.businesswire.com/news/home/20240507524533/en/Logic-Pro-takes-music-making-to-the-next-level-with-new-AI-features); [PRESS: 9to5mac](https://9to5mac.com/2024/05/14/logic-pro-ai-built-band/)
- The AudioShake Local Inference SDK lists iOS with Metal and Neural Engine back-ends. — [AudioShake SDK](https://developer.audioshake.ai/sdk). Community Core ML conversions of UVR MDX-Net for ANE/GPU/CPU exist. — [Hugging Face](https://huggingface.co/gyoom/UVR-MDX-CoreML). SplitFire claims 100% on-device separation. — [App Store](https://apps.apple.com/app/id6751143237)

### Inferences
- These products confirm the pattern that works: separation and generation run **offline or buffered** on ANE/GPU with look-ahead, then play out through a normal render path. djay's "real time" runs on buffered audio with latency the DJ never sees, not inside the render callback. An instrument such as Echoelmusic that needs sub-10 ms bio→sound response should keep generative models in the **control plane** (choosing notes and parameters at ~1 Hz or per bar) and keep the DSP deterministic.
- The Logic M1 gate suggests that comparable features on iPhone 15/16 need smaller models or no generative model at all.

### Gaps
- No primary source on Moises iOS on-device versus cloud.
- No confirmation that "Spawn" or AudioKit "Synth One" use any ML; nothing found.
- No technology disclosure for Logic's Session Players (generative versus sample-driven), or whether Apple uses Core ML or BNNS internally.
- No shipping AUv3 with on-device generative ML was found.
