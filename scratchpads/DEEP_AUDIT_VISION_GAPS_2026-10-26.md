# Deep Audit — Gaps to the Echoelmusic Vision & Master Plan
2026-10-26

## What the Vision / Master Plan demands (GSIDMMW / DMMW)
One canonical Session that owns the complete creative workflow:
Audio, MIDI/MPE, instruments, FX, recording, arrangement, mix, mastering, automation, video, visual, light, spatial/XR, bio/motion, collaboration, broadcast.
Generative intelligence connects the domains (assistive only, never in realtime callback).
Bio is the differentiator and first surface.
External specialist systems are adapters, never competing owners.

## What strikes me (current state)

**Strengths**
- Clean separation: EchoelStudio (new product) + Sources/Echoelmusic (frozen port source).
- Strong laws: one Session (DMMWProject), one clock (PatternEngine), audio-thread holiness, BioEgressPolicy, recovery principle, no health claims.
- Solid foundation already in Studio: instruments, FX, arrangement, session view, automation, MIDI record, mix, export, AUv3, on-device assistant.
- Recent progress: HRV / rPPG pure math ported to EchoelDSP, song loop, expanded 1.0 plan that re-includes video/voice/face/generative.

**Structural observations**
- Two codebases still coexist; main still shows mostly the old app to outsiders.
- Many old capabilities exist and are measured, but not yet wired into Studio.
- Accessibility is already strong in the old Studio surfaces; new Studio surfaces need the same discipline from day one.
- Documentation is rich but fragmented across many PLAN_*, MASTER_PLAN, VISION, NEUPLANUNG files. The 1.0 wave plan is the current execution order.

## Main Gaps to the Vision

| Gap | Current | Needed for Vision | Priority |
|-----|---------|-------------------|----------|
| Body → visible + modulation | Math in EchoelDSP | BodyFrame display + off-switch → ModRoute (W1 then W2) | Highest |
| Spatial / Light outputs | OSC/ADM-OSC/Art-Net/sACN in old app | Connections module in Studio, all off by default (W4, needs F25) | High |
| Video | Seed card + deleted recorder | Picture lane + capture/export (W7) | Medium (founder re-included) |
| Voice FX | Deleted | Autotune/Harmonizer/Granular as devices (W8) | Medium |
| Face / Motion | Deleted | Modulation sources only (W9) | Medium |
| Generative AI | Describe + intents; planner has no door | Explicit user-triggered door, selection-only (W10) | Medium |
| One Session fully enforced | Decided | Every domain writes through DMMWProject | Ongoing |
| Network Master Clock / Audio streaming | None | W4+ (PTP, jitter buffers, SRT/WebRTC) — future | Low (later) |
| XR / visionOS / native Mac/Watch | IDEA / Designed for iPad | After 1.0 | Later |
| Full broadcast / collab at scale | Live Colabo exists | After core domains | Later |

## Biggest single observation
The pure math for the body (the product differentiator) is now in the right place (EchoelDSP, Foundation-only). The missing piece is the last-mile wiring: visible display + modulation routes. Everything else in the vision can follow once that chain exists.

## Recommendation
Stay on the wave order in PLAN_ONE_POINT_ZERO_COMPLETE. Finish W1 display, then W2, then W4. Document every new surface against the Accessible Design Checklist. Do not open new network-audio or XR work until the core body-to-parameter path is device-verified.

*Deep audit complete. Transparent, docs only.*