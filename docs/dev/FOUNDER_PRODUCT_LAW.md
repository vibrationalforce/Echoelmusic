# FOUNDER PRODUCT LAW — the current product definition

**Status: CURRENT, highest authority for product scope.** Founder decision 2026-09-24.
It supersedes `docs/dev/PRODUCT_DEFINITION.md` (2026-07-25 → 2026-09-24), which is kept
unaltered below its banner as the record of the "pure instrument" phase.

> ## CURRENT PRODUCT LAW SUPERSEDES HISTORICAL PRODUCT CUTS.
>
> Historical cuts are evidence about failed or unsafe **implementations**. They are
> not automatic **scope prohibitions**. Before you use a historical deletion — a commit,
> a ⛔ block, a decisions.csv row, a guard message — to reject a feature, read this file.

⚠️ **Scope is not a claim.** This file names the DESTINATION. It does not say that any of
it ships. What the app, the App Store text, the website and short-form content may CLAIM is
still decided by what ships today (`docs/dev/FEATURE_STATUS.md`, `ContentPipeline/CLAIMS.md`).
A false claim in the store text is a 2.3 rejection. App Store wording stays with the founder.
This page is published under `docs/dev/` and must be read as a roadmap, never as marketing.

---

## 1. What Echoelmusic is

**Echoelmusic is a full professional distributed multidimensional multimedia workstation
(DMMW).** It is not limited to being a bio-reactive instrument.

It is meant to support professional creation natively across these domains:

| Group | Domains |
|---|---|
| Sound | audio · MIDI / MPE · instruments · effects · recording · sampling |
| Production | arrangement · mixing · mastering · automation |
| Picture | video · cinematic editing · colour / grading · visual generation · animation |
| Space and stage | lighting · spatial audio · immersive / XR / VR · projection / mapping |
| Distribution | collaboration · streaming · broadcast · content and media workflows |
| Intelligence | AI-assisted and AI-generative production |

It integrates professional third-party ecosystems instead of replacing them:

AUv3 · VST3 · CLAP · external DAWs · video/post tools · broadcast tools · CMS/DAM systems ·
lighting systems · spatial systems · hardware · network protocols · AI providers.

### The strategic law

> **OWN THE COMPLETE CREATIVE WORKFLOW. INTEGRATE THE COMPLETE PROFESSIONAL ECOSYSTEM.**

This is **not** permission to rebuild specialist infrastructure in-house. Echoelmusic owns
creative capability. It interoperates with specialist infrastructure. The history shows what
the opposite costs:

| Specialist infrastructure | Integrate it, do not rebuild it | What the history shows |
|---|---|---|
| Codecs, container muxing | AVFoundation / VideoToolbox | — |
| Dante device management | Audinate tools; AES67 as the open interop | Home-made "Dante" transport, never interoperated (2026-03) |
| NDI | NDI SDK (licensed) | Bonjour-only "NDI-compatible" engine (2026-03) |
| CDNs, RTMP ingest | a proven RTMP/SRT library | Hand-rolled RTMP client, never verified against a server |
| Ableton Link | LinkKit | Clean-room re-implementation, interop unverified |
| Plugin SDKs | the vendors' own SDKs | CLAP/VST3/AAX entry points "replace with the real SDK" (2026-02) |
| Trained models | real, bundled, measured models or provider APIs | "CoreML-powered" code that never had a model |

Adding a dependency or a new target is still founder-gated: `CLAUDE.md` DO NOT, and
`.github/workflows/**` / `project.yml` / `Resources/iOS/Info.plist` stay report-not-edit.

---

## 2. Historical supersession law

The repository records many product-phase decisions. Among them:

- "reines Instrument" / pure instrument (2026-07-24, #121) and "DMMW is retired" (2026-07-25)
- DAW / arrangement / clips removed (#121 Slices 2–4)
- piano roll removed (#178, #475)
- recording and audio input removed (#1302)
- granular and harmonizer removed (#1305)
- video capture and edit removed (#1304, #121 Slice 3)
- plugin hosting removed (#121 Slice 2)
- drums removed (#166 / #167)
- motion removed (identity line, 2026-07-31)
- the Watch app left un-embedded

**These are HISTORICAL IMPLEMENTATION / PRODUCT-PHASE DECISIONS. They do not define current
scope.**

> **A HISTORICAL DELETION REVOKES AN IMPLEMENTATION, NOT NECESSARILY THE CAPABILITY.**

Engineering warnings attached to those deletions **remain valid**:

| Deletion | Implementation stays revoked because… | Capability today |
|---|---|---|
| #1302 audio input | the old input graph crashed at the input node (`isInputConnToConverter` family) and a mis-balanced record-route refcount held the phone in `.playAndRecord` (#299). Do not restore it blindly. | Audio input and recording **are** current scope |
| #1304 video capture | recorder/muxer never worked to the founder's satisfaction ("hat leider nicht geklappt") | Professional video **is** current scope |
| #1305 granular | the old implementation lived on the mic path | "Echoel Grain" **is** future scope |
| #121 Slice 2 hosting | the old per-lane host was removed with the DAW shell | AUv3 / VST3 / CLAP hosting **is** future scope |
| #166/#167 drums | the kit sounded thin; pads mixed channels that made no sound | Drums/percussion return as a capability, not the old kit |
| #475 piano roll | a view with no door | Professional MIDI / note editing **is** current scope |
| #1301 face/body | removed with the camera expression path | Research, needs founder consent and privacy design |

---

## 3. UI law

**UI surfaces are replaceable. Capabilities and canonical domain contracts survive redesigns.**

Never infer "view removed → capability forbidden":

- The piano-roll VIEW may be replaced; professional MIDI editing stays a capability.
- An old video workspace may be replaced; video stays a domain.
- An old DAW shell may be replaced; arrangement and production stay capabilities.

The UI engineering laws are unchanged and non-negotiable:

- the black-screen law: no appended root modifiers on the `EchoelStudioView` chain
- the hot-state law: 10 Hz reads live in leaf views only
- `EchoelValueField` for numeric parameters
- the Uncodixfy constraints
- the 3 Hz flash ceiling

---

## 4. Bio and science law

Bio stays a major differentiator. **It is not the outer product boundary.**

The allowed chain is:

```
measured signal → quality / confidence → derived creative feature → consent / privacy → ControlSource
```

These must **never** be restored:

- healing-frequency claims (Solfeggio, 432 Hz "healing", chakra tuning)
- organ or tissue resonance claims ("bone harmony" and relatives)
- unsupported consciousness-state inference
- medical treatment claims (the clinical-intervention catalogue of 2026-02, "therapy" systems)
- fabricated scientific certainty (invented benchmark numbers, invented citations)

Safety warnings, the 3 Hz flash limit and "data for self-observation, not diagnosis" stay law.

---

## 5. Recovery principle

> **NEVER restore a historical subsystem by copying it wholesale merely because it once
> existed.**

A recovery goes through these steps:

```
CURRENT CAPABILITY NEEDED
→ inspect the current implementation
→ inspect the historical implementations (docs/dev/HISTORY_ARCHIVE.md)
→ identify the proven algorithm / semantics / tests
→ discard stale ownership / UI / persistence / runtime assumptions
→ port only the valuable core
→ integrate it into the CURRENT canonical owners (EngineBus, the stores, the FX chain, …)
→ test end to end, then verify on a device
```

Much of the history never compiled, never had a door, or was an overclaim. The archive
records which. **"It existed" is never evidence that "it worked".**

---

## 6. What this law does not change

- **Release sequencing stays iPhone-first.** That is an order, not a limit.
- **The five-check "Instrument-Complete v1" gate** stays the gate for the NEXT App Store
  release until the founder replaces it. It is a release milestone, not the product boundary.
  ⚠️ This reading is a reconciliation made on 2026-09-24 and is open for founder confirmation.
- **Audio-thread law, the protected Rausch triad, zero-dependency default, one slice per
  cycle, device verification, and founder-gated files.** All stay unchanged.
- **Public claims.** They follow what ships (see the banner at the top).

---

## 7. Where things live

| Question | File |
|---|---|
| What is the product (now)? | **this file** |
| In what order is it built, and what state is each item in? | `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` |
| What ships and is reachable today? | `docs/dev/FEATURE_STATUS.md` |
| What existed historically, did it work, and should it come back? | `docs/dev/HISTORY_ARCHIVE.md` |
| What may public copy claim? | `ContentPipeline/CLAIMS.md` |
| The pure-instrument phase definition (history) | `docs/dev/PRODUCT_DEFINITION.md` |
| The June 2026 DMMW blueprint (history; destination revived, blueprint not canonical) | `docs/dev/DMMW_ARCHITECTURE.md` |
