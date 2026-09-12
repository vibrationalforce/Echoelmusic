# Third-Party Notices & Attributions — Echoel

This document lists third-party material in the Echoel app and how it is licensed /
attributed. It covers what ships **in the app binary** and, separately, developer-only
tooling that does **not** ship.

> Not legal advice. This is standard open-source attribution hygiene maintained by the
> developer. A final review by counsel is recommended before release.

_Last reviewed: 2026-09-12._

---

## Ships in the app

### Atkinson Hyperlegible (font) — SIL Open Font License 1.1
- **Files:** `Resources/Fonts/AtkinsonHyperlegible-{Regular,Bold,Italic}.ttf` (v1.006).
- **Copyright:** © 2020 Braille Institute of America, Inc., with Reserved Font Name
  "Atkinson Hyperlegible". Designers: Elliott Scott, Megan Eiswerth, Linus Boman,
  Theodore Petrosky (Applied Design Works).
- **License:** SIL Open Font License, Version 1.1 — full text in `Resources/Fonts/OFL.txt`.
- **Compliance:** the OFL text + copyright notice are bundled alongside the font
  (OFL §2). The font is embedded, not sold by itself (OFL §1). The Reserved Font Name is
  not reused (OFL §3). ✅ Make sure `Resources/Fonts/OFL.txt` is included as a bundled
  resource so the license ships with the app (see "Action items").

### Drum samples — REMOVED 2026-07-27 (no longer shipped)
- **Files:** `Sources/Echoelmusic/Resources/Drums/*.wav` (Kick, Snare, Clap, Hats, Perc,
  Bass, LeadFX) — **deleted** with the drum apparatus (#167), together with the
  categorized sample library under `Resources/Samples/`.
- **Origin (historical):** procedurally synthesised by Echoel's own DSP (commit `aa54bb8`,
  "procedural samples"). Original works of the developer — **no third-party rights**.
- **Why this entry stays:** the removal is what makes it moot, and a notices file that
  silently drops an entry gives no way to tell "was never there" from "was removed". The
  app now ships no bundled audio samples at all, so there is nothing here to license.

### Apple system frameworks
- AVFoundation, Accelerate, Metal/MetalKit, CoreMIDI, HealthKit, CoreBluetooth, Network,
  SwiftUI, CoreHaptics, MultipeerConnectivity, etc.
- Used under the Apple SDK / developer-program terms. No separate attribution required.
- ⛔ **`SwiftData` and `VideoToolbox` stood in this list and are imported NOWHERE** (measured
  2026-09-12: `git grep -l "^import <X>$\|canImport(<X>)" -- Sources` → **0** for both, while
  the other eleven names return 4–65 files each). `CLAUDE.md`'s tech-stack table had already
  struck the same two phantoms on 2026-07-31 and this file was not pulled along — the #456
  shape: a correction goes to EVERY home of the claim, not only the one being edited.
  Harmless legally (naming a framework you do not use creates no obligation), but this is the
  document counsel reads first, and a list with two invented entries is not one to audit from.

### Light/colour mapping — physically-derived (no third-party concept)
- The immersive visual colours a tone by transposing it up whole octaves into the visible
  band and converting that **light wavelength → RGB via the CIE colour-matching functions**
  (`MetalBioView.swift`, `wavelengthToRGB`/`toneColour`). This is standard physics
  (octave mathematics f × 2ⁿ + CIE 1931), not a third-party convention — no attribution
  required. (The earlier Hans Cousto "Cosmic Octave" colour-wheel and planetary-tone tunings
  were removed in 10.76.40.)

### External Swift packages — NONE currently ship
- `Package.swift` `dependencies: []`; the Xcode app target `dependencies: []`
  (`project.yml`). No third-party libraries are linked into the shipping binary today.
- **If RTMP/SRT streaming is enabled later via HaishinKit (MIT):** add HaishinKit's MIT
  license + copyright here and to the in-app acknowledgments before shipping that build.

---

## Does NOT ship (developer tooling only — excluded from the app binary)

These live under `.claude/` and are used only for development/marketing workflows. They
are not in `Sources/` or app `Resources/` and are never compiled into the app:
- **Marketing skill pack** — `.claude/skills/marketing/` — MIT (Corey Haines). License
  retained at `.claude/skills/marketing/LICENSE`. Pipeline-only.
- **gstack** — `.claude/skills/gstack/` — license retained at
  `.claude/skills/gstack/LICENSE`. Tooling-only.

---

## Echoel's own license
The Echoel source is MIT-licensed — see `LICENSE` (© 2024–2025 Echoelmusic).

---

## Action items (compliance checklist)
- [x] **DONE — verified 2026-09-12.** `Resources/Fonts/OFL.txt` ships: `project.yml:142-144`
      adds `Resources/Fonts` as a `type: group` with `buildPhase: resources`, and the OFL text
      lives in that directory, so the whole folder (three .ttf + the licence) is copied into the
      bundle (OFL §2 satisfied). ⚠️ That is the strongest claim available without opening a built
      `.app`; a device/archive check would settle it beyond the project file. The box stood
      unticked while the work was already done — a checklist that overstates the backlog costs
      the same attention as one that understates it.
- [ ] Add an in-app **Acknowledgments** screen surfacing this file (font OFL notice).
      Nice-to-have for OFL; standard for App Store apps.
- [ ] Re-add HaishinKit's MIT notice here **if/when** streaming is enabled.
- [ ] Counsel review before release.
