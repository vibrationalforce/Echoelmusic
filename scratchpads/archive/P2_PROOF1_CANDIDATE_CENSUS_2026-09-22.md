# P2 PROOF #1 — Candidate census for the first non-audio registered parameter

**Verdict: NO-GO.** Nothing in `Sources/` satisfies all fifteen conditions. This file is the
measurement, so the next session does not repeat it.

Measured at `495b32886` (P2.0 = `c57c8b7bb`). Every number below has its command beside it.

---

## 0. The frame

A registered parameter needs a **canonical runtime owner**: one object, one mutable truth, a
safe programmatic setter, and no UserDefaults write in the apply path. The question is not
"is there a Float in a non-audio domain" — there are dozens — but "is there one that a router
may write".

Complete enumeration of runtime owners:

```
git grep -l "^@Observable" -- Sources        # 62 classes
```

Of those, exactly SIX sit in visual / lighting / spatial:
`SpatialSceneStore` · `ArtNetSender` · `SACNSender` · `ADMOSCSender` · `ExternalStageBridge` ·
`ResourceGovernor`. Each is taken apart below. `HapticController` and `StudioCaption` own no
`Float` at all (`grep -n "var .*: Float"` → 0); haptics is also outside the four `ParameterDomain`
cases.

---

## 1. VISUAL — the owner is `@AppStorage`, and it is wired into the hot root

There are ten visual look scalars (`visual.intensity` · `.detail` · `.motion` · `.spread` ·
`.hue` · `.saturation` · `.texture` · `.glitter` · `.structure` · `.blend`), all declared as
`StudioDefault` in `Core/StudioDefaultKeys.swift`.

```
git grep -n "visualIntensity" -- Sources | grep -v ': *//'
```

Six hits, and **five are `@AppStorage`** — `EchoelStudioView:1007`, `ExternalDisplayScene:158`,
`FloatingVisualWindow:159`, plus a raw `@AppStorage("visual.intensity")` in `MoodPads:187`.
There is no object between the key and the renderer. **`UserDefaults` IS the owner.**

Two conditions fail, and the second is the expensive one:
- **(8) no UserDefaults write in the apply path** — a router setter would have to write the key;
  there is nothing else to write.
- **(9) no hot-root invalidation** — `EchoelStudioView` is the MENU HOST. An `@AppStorage` write
  invalidates its body, which tears down any open `.menu` Picker. That is the 10.76.41/50 freeze
  law verbatim, reached from a modulation route instead of from a finger.

The founder's premise is confirmed by measurement, and it generalises: **not one of the ten is
a candidate**, for the same reason.

## 2. LIGHTING — no canonical intent exists above the adapters

The look is computed from the bio frame INSIDE each sender (`ArtNetSender.dmxChannels(for:)`,
`ch1 dimmer = 0.3 + 0.7·coherence`). Nothing sits above them. `Sync/LightFixtureGroup` looks
like that layer and is not: its own header says *"NOTHING consumes this yet"*, and
`git grep -n "LightFixtureGroup(" -- Sources | grep -v ': *//'` confirms zero production
construction.

So the only creative lighting scalar is `grandMaster`, and it exists TWICE:

```
Sources/Echoelmusic/Sync/ArtNetSender.swift:108:  public var grandMaster: Float = 1
Sources/Echoelmusic/Sync/SACNSender.swift:85:     public var grandMaster: Float = 1
```

`PatchbayView.grandMasterBinding` reads ArtNet and writes BOTH — one fader, two truths, and the
read side is one-way. Fails **(1)** and **(7)**. ⭐ Worth recording because it cuts the other
way: `grandMaster` is explicitly *"Live state, not persisted"* in both files, so it would have
passed **(8)** and **(10)** — the mirroring is the ONLY thing disqualifying it. Consolidating
that ownership is a real slice; it is not this one.

Rejected outright as protocol configuration: `host` · `port` · `universe` · `resolution` ·
`fixtureCount` · `fixtureSpacing` (the last two `didSet`-write UserDefaults, #1442) ·
`blackout` (safety toggle).

## 3. SPATIAL — the owner is canonical, the parameters are per-object

`SpatialSceneStore` is the one instance (`EchoelmusicApp:143`, `@State`, injected at :613),
not persisted, and observed only by the doorless `ImmersiveStageView` — so it would pass
**(1)**, **(8)**, **(9)** and **(10)** cleanly. It is the only non-audio owner in the repo that
does.

It fails on shape. Its entire mutable surface is:

```
setPosition(laneID: UUID, _ position: SpatialPosition)
setExtent(laneID: UUID, _ extent: Float)
```

Both are **per lane**. `SpatialObject.gain` and `.roomSend` — the founder's own example of an
acceptable class — have **no setter at all**. `SpatialScene.room` is only reachable inside the
store (`scene` is `private(set)`, and no `setRoom` exists). Fails **(11)**: a global
`spatial.object.extent` would be a lie, because there is no global extent.

⚠️ **TWO HAZARDS FOUND HERE, both latent, neither fixed in this slice:**

1. **`setExtent` bypasses the clamp.** `SpatialObject.init` sanitises
   (`extent.isFinite ? min(max(extent, 0), 1) : 0`), but `extent` is a plain `var` and the
   setter assigns it directly. `setExtent(laneID:, .nan)` puts NaN in the scene. Latent today:
   `git grep -n "setExtent(" -- Sources | grep -v ': *//'` → **only the declaration**, zero
   callers. `setPosition` is safe — `SpatialPosition.init` clamps and the store passes a whole
   value. Fails **(12)** as it stands.
2. **`extent` is not on the wire.** `grep -n "extent" Sources/Echoelmusic/Sync/ADMOSCSender.swift`
   → **0**. So even a per-lane binding would move a model field that no sender and no renderer
   reads — the #164/#227 lying control. Fails **(15)** in substance: the setter reaches the
   owner, the owner reaches nothing.

## 4. The rest

- `ADMOSCSender` — `host` · `port` · `objectIndex` · `streamsScene` · `sceneDialect`. All
  transport configuration; explicitly rejected by the brief.
- `ExternalStageBridge` — owns no `Float` (`grep -n "var .*: Float"` → 0).
- `ResourceGovernor` / `AdaptiveQuality` — thermal/battery/FPS policy, device-derived, not
  creative intent; renderer-private by the brief's own exclusion.
- `Sync/BioPhaser.spread`, `Sync/VBAPPanner`, `Sync/AmbisonicsEncode`, `DSP/BinauralPanner` —
  the spatial RENDER half, measured at #1379 as having zero production callers. No owner
  instance exists to reach.

---

## THE MISSING SEAM, stated once

**Every non-audio domain in this app reaches its output WITHOUT passing through an owned
creative-intent value.**

- Visual: `@AppStorage` key → SwiftUI view property → GPU uniform. No object.
- Lighting: bio frame → `dmxChannels(for:)` inside each sender → wire. No object, and the one
  scalar that exists is duplicated per protocol.
- Spatial: one real store, but its values are per-object and its one Float setter neither
  clamps nor reaches an output.

That is why P2 has nothing to register yet. The audio domain has this seam
(`PolySynthVoice.automatableBases` → `automatableSetter(forBase:)` → one atomic mirror per
parameter), and it is exactly what the other three lack. **P2 Proof #1 is blocked on building
ONE such seam, not on choosing a parameter.**

The three candidate seams, cheapest first — all founder decisions, none taken here:

| Seam | What it is | Cost | Why it might be wrong |
|---|---|---|---|
| **A — lighting master** | ONE owned `lightingMaster`, both senders read it, neither owns it | smallest; `grandMaster` already passes 8 + 10 | consolidates ownership across two protocols — the founder held this |
| **B — visual look owner** | one `@Observable` look store; `@AppStorage` becomes its persistence, not its identity | medium | touches the hot root and five read sites; the #292/freeze surface |
| **C — spatial scene-level** | a `setRoom`/master on `SpatialSceneStore` + put `extent`/`gain` on the wire | medium | the store is right, the wire is missing; adds ADM-OSC addresses |

**A is the smallest honest seam**, and its prerequisite is the ownership decision the founder
already reserved. Nothing here should be built before that decision.

---

## FUTURE HAZARD, recorded and deliberately NOT fixed (per the brief)

`ParameterDescriptor.init(from:)` maps **missing** `domain` → `.audio` (correct: a legacy
payload predates the field) and **unknown present** `domain` → `.audio` (a SEMANTIC hazard: a
newer build's `.olfactory` silently becomes audio). Both are the same line today. They must be
separated BEFORE any of: the descriptor becomes persisted · domain controls routing eligibility ·
domain controls safety · domain controls privacy/egress · domain controls protocol adaptation.
