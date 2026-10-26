# Accessible Design Checklist + Proofreading Report
2026-10-26 — for the Plan, Handover and next slices.

## Accessible Design Checklist (must hold for every new surface)

### VoiceOver / Screen Reader
- [ ] Every interactive control has an `accessibilityLabel` (localized).
- [ ] Live or changing values have an `accessibilityValue` (or "not measured" / "—").
- [ ] Non-obvious actions have an `accessibilityHint`.
- [ ] Live updating panels use `.accessibilityAddTraits(.updatesFrequently)` where appropriate.
- [ ] No reliance on color alone for meaning.
- [ ] Custom controls expose the correct traits (button, adjustable, etc.).

### Dynamic Type & Layout
- [ ] No fixed heights that clip text at larger sizes (prefer minHeight or flexible).
- [ ] Text scales or is capped only where the design law allows.
- [ ] Touch targets ≥ 44 pt.
- [ ] Content reflows; no absolute frames that break on larger type or landscape.

### Contrast & Visual
- [ ] Text and essential icons meet WCAG AA contrast (or documented exception).
- [ ] 3 Hz flash ceiling respected (existing law).
- [ ] Black-screen modifier-chain law and hot-state leaf law observed.

### Bio / Body Specific (W1 and later)
- [ ] Unmeasured values spoken as "not measured" or equivalent, never a silent 0.
- [ ] Off-switch is clearly labeled and announces its state.
- [ ] Bio data never leaves the device without explicit opt-in (BioEgressPolicy).

### General
- [ ] All user-facing strings are localized (String(localized:) or catalog keys).
- [ ] Device verification planned for the final VoiceOver experience.

## Proofreading Report — Plans & Handover (2026-10-26)

### Checked Documents
- `scratchpads/PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md`
- `scratchpads/HANDOVER_*` and related slice plans created this session
- `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` (relevant sections)
- `docs/dev/ECHOEL_VISION_2026-10-19.md`

### Findings
- Terminology is consistent: BodyFrame, ModRoute, W0–W10, GSIDMMW / DMMW, recovery principle.
- Wave ordering and founder decisions match.
- Network jitter task correctly scoped as W4+ (not current).
- No contradictory claims about what is implemented vs planned.
- Minor: some older Master Plan sections still describe the frozen old-app sequence; the banner at the top correctly marks them as history. No action needed.

### Errors / Issues Found
- None critical in the current plans.
- Accessibility checklist above was missing as an explicit artifact → created here.
- For the upcoming W1 BodyFrame display: the checklist items must be applied in the same commit that adds the view.

### Recommendation
Attach this checklist to the W1 slice plan. Claude can tick the boxes when implementing the display.

*Transparent documentation. No code or rule changes.*