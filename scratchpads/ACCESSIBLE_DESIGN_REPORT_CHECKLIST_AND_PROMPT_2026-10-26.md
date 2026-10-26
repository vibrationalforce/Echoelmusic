# Accessible Design Report — Checklist, .accessibilityLabel, and Plan Prompt
2026-10-26

## 1. Checklist for an Accessible Design Report

Use this when reviewing any new surface (especially W1 BodyFrame display and later waves).

### Must-have
- [ ] Every tappable control has a clear `accessibilityLabel`.
- [ ] Changing or live values expose `accessibilityValue`.
- [ ] Non-obvious actions have `accessibilityHint`.
- [ ] Live panels use `.updatesFrequently` where the value changes often.
- [ ] Dynamic Type does not clip or overflow critical text.
- [ ] Touch targets are at least 44×44 pt.
- [ ] Meaning is not conveyed by color alone.
- [ ] Localized strings used for all spoken text.
- [ ] Off / disabled states are announced.
- [ ] Bio unmeasured state is spoken as "not measured" (not silent 0).

### Report structure
- Surfaces reviewed
- Pass / Fail per checklist item
- Concrete code locations of any gaps
- Recommended fix (one sentence)
- Device-verify needed? (yes/no)

## 2. How `.accessibilityLabel` works

`.accessibilityLabel` sets the string that VoiceOver speaks when the element receives focus.

**Basic usage (SwiftUI):**
```swift
Text("72")
    .accessibilityLabel("Heart rate")
    .accessibilityValue("72 beats per minute")
```

**Rules of thumb in this project:**
- Prefer `String(localized:)` or a catalog key so German (and future languages) work.
- Keep the label short and stable; put the changing number in `accessibilityValue`.
- For a whole panel, one label on the container is often enough.
- Combine with `.accessibilityElement(children: .ignore)` or `.combine` when children would otherwise be read separately and confuse the user.
- Existing examples: `EchoelValueField`, `HeaderMonitors`, `BioStripView`, `ProjectHeader`.

**Common mistakes to avoid:**
- Label that includes the current number (it will be wrong when the value changes).
- Missing label on a custom button or slider.
- Label that only makes sense visually.

## 3. Reusable Prompt for the Plan

Copy-paste this into a future session or give it to Claude:

```
You are continuing the Echoel Studio 1.0 plan (PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md).

When you design or implement any new user-facing surface (especially the W1 BodyFrame display):

1. Follow the Accessible Design Checklist in scratchpads/ACCESSIBLE_DESIGN_REPORT_CHECKLIST_AND_PROMPT_2026-10-26.md.
2. Every interactive element must have .accessibilityLabel (localized).
3. Live values must have .accessibilityValue.
4. Respect Dynamic Type, 44 pt targets, the black-screen law, and the 3 Hz flash ceiling.
5. Unmeasured bio values must be spoken as "not measured".
6. Keep the slice ≤ 3 files.
7. CI must be green; device verification is required before any claim.
8. Do not change founder-gated files (project.yml, Info.plist, workflows) without explicit approval.

Current priority: finish the visible BodyFrame display + off-switch, then proceed to W2 ModRoute.

Report what you added for accessibility in the commit message.
```

*Created under full mandate. Transparent, docs only.*