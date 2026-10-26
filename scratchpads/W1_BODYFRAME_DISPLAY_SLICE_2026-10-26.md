# W1-Rest Slice Plan: Visible BodyFrame Display + Off-Switch
2026-10-26 — next concrete code slice under full mandate.

## Goal
Wire the already-ported EchoelDSP math (HRVNormalization, HRVMetrics, HRVCoherence, PulsePeriodEstimator, RPPGConditioning, RR*) into a visible BodyFrame display in Studio, with an off-switch that silences the publisher.

## Why now
Math is CI-green and Foundation-only. This is the missing end-to-end link from pure calculation to user-visible body signal. Enables later W2 ModRoute.

## Suggested implementation (≤ 3 files)
1. BodyFrame publisher or adapter that consumes the DSP math and produces a normalized frame (BPM, hrvNormalized, coherence).
2. Small SwiftUI view (or extension of existing bio surface) that displays the three values and shows "—" when unmeasured.
3. Toggle (UserDefaults or session flag) that disables the publisher; when off, no frames are published and egress is impossible.

## Constraints (unchanged)
- No allocations or locks in any render-adjacent path.
- BioEgressPolicy respected (nothing leaves device without opt-in).
- CI (studio.yml + Linux) must go green.
- Device verification required for: camera lock time, display correctness, off-switch silence.
- No claims until device confirms.

## Acceptance
- Display shows live values when source is active.
- Off-switch stops updates immediately.
- Tests cover the pure mapping (already exist) + one view or publisher unit test if pure.

This is the highest-priority code slice. Ready for implementation when Claude resumes or when a device-capable session is available.

*Transparent continuation. No rules altered.*