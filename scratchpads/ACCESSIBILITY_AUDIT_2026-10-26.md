# Accessibility & Design Audit — 26 October 2026

Deep audit requested. Focus: accessible design (VoiceOver, Dynamic Type, contrast, labels) and proofreading of recent plans.

## Current State (measured)
- Extensive VoiceOver work already done in Sources/Echoelmusic/Studio: accessibilityLabel, accessibilityHint, accessibilityValue on key surfaces (HeaderMonitors, ProjectHeader, WorkstationView, BioStripView, EchoelValueField, WorkspaceView, PatchbayView).
- Dynamic Type handling present (minHeight instead of fixed height, clamps noted as historical defect and addressed).
- UX_AUDIT_2026-10-02.md exists and was followed by many slices (zoom, add menu, undo, etc.).
- Black-screen modifier-chain law and hot-state leaf law are invariants.
- German localization of many surfaces completed in early October.

## Issues Found / Gaps
1. **EchoelStudio (new) surfaces**: Fewer accessibility annotations yet. When BodyFrame display is built (W1-Rest), it must include:
   - accessibilityLabel for the panel ("Body" or localized).
   - accessibilityValue for live numbers (BPM, HRV, coherence) or "not measured".
   - Hint for the off-switch.
   - Dynamic Type support (no fixed heights that clip).
2. **Contrast**: One measured case in UX_AUDIT (note velocity colors ~2.6:1) was deferred as design decision.
3. **NEEDS-FOUNDER-VERIFY**: Some VoiceOver wording decisions still open (e.g. FloatingVisualLayout).
4. **New plans**: Handover and slice plans are clear; minor proofreading done (consistent terminology: BodyFrame, ModRoute, W1–W10).

## Recommended Fixes (safe, next slices)
- When implementing W1 BodyFrame display: add the three accessibility modifiers in the same commit.
- Document a short Accessibility checklist in the W1 slice plan (already partially covered by existing laws).
- No code changes in this audit (docs only). Device is still required to confirm VoiceOver experience.

## Proofreading of Recent Handover Docs
- Terminology consistent with PLAN_ONE_POINT_ZERO and Master Plan.
- No contradictions found in the scratchpads created this session.
- Network task correctly placed as W4+.

Audit complete for pure documentation level. Next real a11y work happens inside the W1 display slice.

*Transparent, no rules changed.*