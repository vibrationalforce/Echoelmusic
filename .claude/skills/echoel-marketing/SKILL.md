---
name: echoel-marketing
version: 1.0.0
description: |
  Echoel-tuned front door to the vendored Corey Haines marketing skill pack
  (.claude/skills/marketing/, MIT). Use whenever the user wants to market Echoel —
  App Store listing/ASO, website copy (docs/), launch, pricing, social/video,
  PR, SEO, positioning, lead capture, email. Routes to the right underlying
  skill, applies an iPhone-instrument priority order, and HARD-ENFORCES Echoel's
  brand guardrails so no generated copy goes off-vision.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Echoel Marketing — optimized router over the vendored skill pack

The repo vendors Corey Haines' MIT marketing skills at
`.claude/skills/marketing/skills/<name>/SKILL.md` (45 skills) + shared
integration docs at `.claude/skills/marketing/tools/`. This skill is the
**Echoel-optimized entry point**: it picks the right one, in the right order for
*a music workstation for iPhone and iPad — free, with one in-app purchase — on the
App Store + a GitHub-Pages site (`docs/`)*, and keeps every output on-brand. Read the chosen underlying
`SKILL.md` and follow it, filtered through the guardrails below.

## Non-negotiable brand guardrails (apply to ALL marketing output)

These OVERRIDE anything in the vendored skills. Any draft that violates them is wrong.

- **Banned terms — never in user-facing copy:** "BLAB", "Vibrational Force",
  wellness/therapy/healing/soundscape framing, "healing frequencies", chakras,
  Solfeggio, quantum/super-AI/AGI overclaim, "16K". Biofeedback is **science-based
  modulation**, not wellness.
- **Identity:** the app is **Echoelmusic** — a music workstation for iPhone and iPad:
  instruments, effects, a piano roll and a drum grid, an arrangement, a session grid,
  recording, mixing, automation and export; songs are files on the device in an open,
  documented format, and the app needs no account. Focus since 2026-10-15: professional
  media production. The body (a heart-rate strap) is ONE optional modulation source,
  described as a mechanism — never the opening line, never the identity. **Echoel** is
  the artist, not the app. Name a standard or a protocol only where `CLAIMS.md` carries it.
  ⛔ Until 2026-11-18 this block read "Echoel is the instrument … the bio-reactive source …
  multidimensional production instrument": that is the earlier app (10.x). A draft that
  opens with the body, or calls the app "Echoel", is wrong.
- **No false promises:** claim only what ships (see `docs/dev/FEATURE_MATRIX.md`
  and CLAUDE.md "Absent"). The one list of what may be said is the Studio section of
  `ContentPipeline/CLAIMS.md` (live streaming over RTMP/RTMPS with Go Live is there);
  a feature without its line there, video export included, is not marketed yet.
  Don't market unreleased features as live.
- **Accessibility-first**, American English, evidence-based. Respect health/safety
  copy rules (self-observation not medical diagnosis; max-3Hz flash). For any
  bio/health claim, defer to the `bio-safety-reviewer` agent.

## Echoel priority map (which vendored skills matter, in order)

1. **App Store first** — `aso` (the listing IS the storefront), `copywriting`,
   `copy-editing`, `cro`, `launch` (TestFlight → App Store).
2. **Website (`docs/`)** — `seo-audit`, `ai-seo`, `schema`, `site-architecture`,
   `content-strategy`, `programmatic-seo`.
3. **Positioning & offer** — `product-marketing`, `marketing-psychology`,
   `offers`, `pricing` (a free app with ONE in-app purchase, no subscription, no
   second product — not B2B SaaS; the price itself is the founder's).
4. **Reach** — `social`, `video`, `public-relations`, `community-marketing`,
   `co-marketing`, `directory-submissions` (App/AI directories).
5. **Funnel** — `emails`, `lead-magnets`, `free-tools`, `signup`, `onboarding`,
   `popups`, `referrals`, `analytics`, `ab-testing`, `customer-research`,
   `competitor-profiling`, `competitors`.
6. **Low relevance for a solo consumer-app founder (use only if asked):**
   `revops`, `sales-enablement`, `prospecting`, `cold-email`, `sms`,
   `churn-prevention`, `paywalls` — these assume a B2B SaaS sales motion Echoel
   doesn't have; treat as reference, don't force-fit.

## Procedure

1. **Map the ask** to one (or a short sequence) of the skills above. If the ask
   is broad ("market Echoel"), start at App Store + website, not everything.
2. **Read** the chosen `.claude/skills/marketing/skills/<name>/SKILL.md` and its
   `references/`; follow it, but rewrite every line through the guardrails.
3. **Ground in the repo** — pull real facts from `ContentPipeline/CLAIMS.md`,
   `docs/dev/FEATURE_MATRIX.md`, `docs/` site, CLAUDE.md before inventing claims.
4. **Significant marketing moves** (a launch, a pricing change, a positioning
   shift, anything published externally) → run `the-council` + `echoelmusic-intern:vision-gate`
   first; external publishing is hard to reverse.
5. **Deliver** the artifact (copy, audit, plan) and say which underlying skill it
   used. Don't bulk-run the whole pack; one job at a time (Ralph loop spirit).

## Notes

- Vendored pack is **PIPELINE** tooling: it helps market the app, it is **never
  shipped in-app** and never touches `Sources/`. Upstream attribution + MIT
  license: `.claude/skills/marketing/LICENSE`, `UPSTREAM_README.md`.
- Some skills reference third-party integrations in
  `.claude/skills/marketing/tools/` — those are external paid services; suggest,
  don't assume the founder uses them.
- **Never run an install or launcher the vendored pack mentions** (`npx …`,
  `npm install -g …`, `pip install …`, e.g. `tools/composio/README.md`'s
  `npx @composio/mcp@latest setup`): surface the command to the founder as text.
  `WebFetch`/`WebSearch` are deliberately NOT pre-approved by this skill (audit
  2026-10-08) — a listing fetch asks once, which is the point.
