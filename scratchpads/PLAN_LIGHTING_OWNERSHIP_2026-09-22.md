# P2 — Lighting ownership: where a creative lighting parameter would live

**Verdict: NO-GO for implementation.** Not because the seam is hard, but because the one
decision it needs is the founder's, and the census's own recommendation (consolidate
`grandMaster`) is REFUTED by this measurement.

Measured at `7672b97db`. Every claim has its command beside it.

---

## 1. The pipeline, measured end to end

Both senders run the identical eight stages. Read from `ArtNetSender.sendIfFresh`
and `SACNSender.sendIfFresh`:

| # | Stage | Function | Protocol-independent? |
|---|---|---|---|
| 1 | source choice | `bus.freshMusical(maxAge: 1.5)` → `isSounding` ? music : `bus.latestBio` | ✅ same predicate in both |
| 2 | **egress gate** | `BioEgressPolicy.allowsEgress(frame.source)` | ✅ |
| 3 | **creative mapping** | music: `MusicMediaMap.dmxChannels(forMusic:resolution:)` + `.dimmerUnit(forMusic:)` · bio: `ArtNetSender.dmxChannels(for:resolution:)` + `.dimmerUnit(for:)` | ✅ ONE implementation, called twice |
| 4 | hold | `lastChannels` / `lastTarget` | ✗ per-sender state |
| 5 | **operator master** | `ArtNetSender.masteredDimmer(target, grandMaster:, blackout:)` | ✅ shared function, ✗ two `grandMaster` values |
| 6 | **safety slew** | `FlashGuard.slewedDimmer(from:to:blackout:maxDelta:)` + `applySlewedColour` | ✅ |
| 7 | fan | `DMXFixtureFan.fanned(_:count:spacing:)` | ✅ shared function, ✗ two persisted counts |
| 8 | packet | `artDMXPacket` / `e131Packet` | ✗ genuinely protocol-specific |

**The founder's proposed ordering is confirmed, with one correction:** blackout is not a stage
after the master — it is a short-circuit INSIDE it (`guard !blackout else { return 0 }`), and
FlashGuard re-applies it downstream (`if blackout { return 0 }`). Two independent
short-circuits, so blackout outranks the master twice over. Safety is the LAST stage before
the fan, not a peer of the master.

⭐ **The creative luminance survives the whole chain as a Float.** Stage 3 produces
protocol-shaped bytes AND a separate `target: Float` 0…1; stage 8's dimmer channel is
overwritten from that Float after mastering and slewing (`applyDimmer`). So a creative
lighting scalar already has a place to stand — it is simply never STORED anywhere a human or
a route could reach.

## 2. The duplication is NOT the creative mapping — that claim was wrong

Measured, comment-stripped, over `SACNSender.swift`:

```
ArtNetSender.{DMXResolution, applyDimmer, applySlewedColour, decodedFixtureCount,
              decodedFixtureSpacing, decodedResolution, dimmerUnit, dmxChannels,
              masteredDimmer, reencode}          # 10
MusicMediaMap.{dimmerUnit, dmxChannels}          #  2
FlashGuard.{senderTickDelta, senderTickMilliseconds, slewedDimmer}   # 3
DMXFixtureFan.fanned · BioEgressPolicy.allowsEgress                  # 2
```

**Seventeen shared symbols. sACN defines ZERO creative mapping of its own.** The single-source
migration the census anticipated in §6 is, for the MAPPING, already done — it was done by
making the kernels `static`.

What is genuinely duplicated is three things, and only one of them is a defect:
- **per-transport state** (`lastChannels` · `lastTarget` · `lastDimmer` · `lastColour` ·
  `lastSentGrandMaster` · `lastSentBlackout` · `lastFrameTimestamp` · `lastSentTimestamp`,
  plus each sender's own `PollingLoop`) — **correct as-is**: each stream owns its own slew
  history and keep-alive clock.
- **the source-selection block** — same semantics, written twice. Cosmetic.
- **`grandMaster` + `blackout`** — two mutable truths for one operator concept. The real one.

## 3. Type classification — is there already an owner?

| Type | Class | Owner? |
|---|---|---|
| `Sync/MusicMediaMap` | **PURE MAPPER** (`enum`, all `static`, no state) | no |
| `Core/SpectralColor` | **PURE MAPPER** (`enum`) | no |
| `Core/DMXFixtureFan` | **PURE MAPPER** (`enum`) | no |
| `Core/FlashGuard` | **SAFETY LAYER** (`enum`, constants + pure functions) | no |
| `Sync/LightFixtureGroup` | **MODEL ONLY** — its own header says "NOTHING consumes this yet"; zero production construction | no |
| `ArtNetSender` · `SACNSender` | **TRANSPORT ADAPTER** that also happens to host the shared kernels | no (and must not become one) |
| `SignalRoute.amount` | **MODEL ONLY** — its own doc: "a schema slot with an honest comment"; zero readers; persisted | no |

**No existing type owns "what Echoelmusic wants the lights to do".** ⚠️ And the closest thing
to it — `ArtNetSender`'s ten shared statics — must NOT be promoted: a pure mapper that is
shared is still a pure mapper (the founder's own instruction), and promoting a transport
adapter to the owner is the inversion this whole exercise exists to avoid.

## 4. `grandMaster` is an operator control, not a creative parameter

Six professional-semantics questions, answered from source rather than from taste:

| Question | Answer | Evidence |
|---|---|---|
| Human operator's final level? | **YES** | doc: *"every lighting desk's first fader"*; the Patchbay section is the *"kleines Lichtpult"* |
| May bio/automation raise it? | **NO** | a route raising a master the operator pulled down inverts the control hierarchy of every lighting rig |
| May automation override a manual reduction? | **NO** | same |
| Part of creative recall? | **NO** | *"Live state, not persisted — a fresh launch always starts at full (predictable for the operator)"*, in BOTH senders |
| Stay non-persisted? | **YES** | #1442 persisted the rig SHAPE and deliberately left master + blackout live-only, with the reason written at the declaration |
| Does blackout always outrank it? | **YES** | `masteredDimmer` short-circuits before reading the master; `FlashGuard.slewedDimmer` short-circuits again |

**`grandMaster` MUST NOT be the first creative P2 parameter.** ⛔ This retracts the previous
report's "next safe step". Consolidating it remains worth doing as an OPERATOR-model fix — one
owned master both adapters read — but that is a correctness slice, not P2, and it would produce
an owner whose one value is deliberately ineligible for modulation.

## 5. The finding that blocks the slice

**Lighting in this app is a STATELESS PROJECTION.** `f(BioSampleFrame | MusicalFrame) → bytes`,
evaluated at tick time. There is no stored creative lighting value anywhere — not a brightness,
not a colour bias, not a spread. The only stored lighting values in the repo are: the operator
master, the safety blackout, and the rig shape (host · port · universe · resolution ·
fixtureCount · fixtureSpacing).

So §5's preferred candidate — *"an ALREADY EXISTING creative value currently recomputed
independently inside both senders"* — resolves to exactly one thing: `target` / `lastTarget`,
the generated luminance unit. It is genuinely computed twice, on two tick phases, cached in two
places (`lastTarget` appears 3× in each file).

⚠️ **And it cannot become a P2 parameter without a decision, because it is a READ-OUT.**
Owning it removes a real duplication and invents nothing. *Writing* it means a route or a
human overriding the generated intensity — and that is a new user-facing lighting behaviour,
which §5 forbids this slice from inventing. It also re-creates the `grandMaster` defect in a
different axis: two writers (the generator each tick, the route whenever it moves) racing for
one value, last-writer-wins, instead of two values for one concept.

## 6. What a compliant owner would look like (design only, NOT approved)

Naming, measured rather than chosen: `Core/` uses **`*Store`** for an `@MainActor @Observable`
owner of mutable state — eleven of them (`MixerStore` · `PatchStore` · `SpatialSceneStore` ·
`TimelineStore` · `TrackFXStore` · …). ⚠️ **`LightingIntent` would be wrong**: all three
`*Intent` types in this repo are Apple `AppIntent` conformances (`StartEchoelSessionIntent`,
`StopEchoelSessionIntent`, `KeepLastLoopIntent`), so the suffix already means "Siri/Shortcuts
action" here. The idiomatic name is **`Core/LightingStore`**.

Contract it would have to satisfy: one instance per session (`@State` in `EchoelmusicApp`,
injected) · protocol-independent (no `Network` import, no packet knowledge) · exactly ONE
creative scalar · no persistence, no `UserDefaults` · not the master, not the blackout · read
by both senders at stage 3/5 · FlashGuard untouched downstream · `@MainActor`.

P2 fit, if such a scalar existed: key `lighting.look.intensity` (no collision —
`ModDestinationKey.all` is `seq.tempo` + eleven `ddsp.*`; no `UserDefaults` key begins
`lighting.`), `Float`, range 0…1, default 1, `domain: .lighting`, one owner, and — critically —
the setter must clamp ITSELF, because `applyReal` bypasses the descriptor range and the value
reaches a physical fixture. `SpatialSceneStore.setExtent` already shows what an unclamped
setter looks like.

---

## THE FOUNDER DECISION

**Does Echoelmusic get a creative lighting VALUE at all, or does lighting stay a pure
projection of bio + music?**

- **If it stays a projection:** there is no lighting parameter to register, now or later, and
  P2 Proof #1 must find its seam in another domain — or accept that the first non-audio
  parameter requires building a domain value first, in whichever domain the founder picks.
- **If it gets one:** it is a new (small) user-facing lighting behaviour, it needs a
  two-writer rule against the per-tick generator, and it needs a name the operator can tell
  apart from the Grand Master on a dark stage.

Nothing in this document should be built before that answer.

## Interop boundary, recorded and unchanged

Echoelmusic owns creative lighting intent. Art-Net and sACN are adapters. Fixture
personalities, patch, cues, HTP/LTP, RDM and venue configuration belong to the desk and stay
there. Dante · AES67 · SMPTE ST 2110 · NMOS follow the same rule — session truth above,
transport/discovery adapters below — and none of them is implemented or planned here.
