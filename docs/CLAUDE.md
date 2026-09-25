# docs/ — the published website

Loads only when work touches this directory. Everything here is **PIPELINE**: it ships to
`echoelmusic.com`, never into the app, and never touches `Sources/`.

Measured 2026-08-12. Every number below has its command next to it — re-derive rather than
trust (`.claude/rules/context.md` §2).

```
git ls-files docs/ | wc -l                       → 66 files
git ls-files docs/ | xargs wc -c | tail -1       → 779,910 B
git ls-files 'docs/*.html' 'docs/**/*.html' …    → 24 pages, 395,873 B
```

---

## 1. Two halves in one directory

**The artist page is one file and has no media.** `artist.html` — 204 lines, 15,730 B — is
Echoel (Michael Terbuyken), Hamburg: bio, labels (Tropical Drones ×3, Slow Punch), venues
(Hafenklang, Astra Stube), links. Measured: `grep -c '<audio\|<video\|<iframe\|\.mp3\|\.wav\|\.m4a'`
returns **0**. There is **no player, no embed, no release area, no discography feed**.

⛔ **Do not build one on your own initiative.** A player is a product decision with hosting,
rights and bandwidth attached, and nothing in the repo asks for it. It is linked from 16 other
files (`git grep -ln 'artist\.html' -- docs/ | grep -v docs/artist.html | wc -l`), so it is not
orphaned — it is deliberately thin.

**The other 23 pages are the app site**, plus `docs/dev/` (14 internal markdown files, biggest
`FEATURE_MATRIX.md` at 43,843 B) and `docs/adr/` (1 file). `docs/dev/` is committed to a public
repo — **no tokens, keys or passwords, ever.**

## 2. How the site actually deploys — and the sentence that says otherwise

**THREE deploy paths exist** (⛔ "two" stood here until #1314 — the third, Cloudflare Pages, is
not a workflow and so was invisible to the grep this section trusted; see the ⛔ block below the
table). Of the two IN the table: **one works, one has been dead for eleven weeks, and a workflow
prints the dead one's name.**

| path | runs | newest | event |
|---|---|---|---|
| `pages-build-deployment` (GitHub's built-in branch builder, `dynamic/pages/…`, id `221917431`) | **3,405** | **2026-08-12T11:27:34Z**, `main` @ `4123728` | `dynamic` |
| `.github/workflows/pages.yml` "Deploy Website" (hand-written, Actions-source) | 363 | **2026-05-28T13:50:26Z** | `push` |

Both re-measured today via `mcp__github__actions_list` → `list_workflow_runs`.

**Why `pages.yml` stopped:** it triggers on `push` to `main`. `auto-merge-docs.yml` merges
`claude/**` → `main` with `GITHUB_TOKEN`, and GitHub raises no workflow-triggering event for
such a push. Measured, not assumed: `list_commits(sha=main, path=docs, since=2026-05-28T14:00Z)`
returns a **full page of 40** docs commits on `main` — and `pages.yml` fired for none of them.

**It does not currently matter, and that is the trap.** The built-in builder runs on every push
to `main` regardless of who pushed, so the site is current. `pages.yml` is a redundant second
path that only becomes load-bearing the day someone flips the Pages source from *branch* to
*GitHub Actions* — at which point the site freezes at the 2026-05-28 artifact. `.nojekyll` is
committed, which is consistent with the branch builder being the live one.

⛔ **`auto-merge-docs.yml:171` prints** *"Website deployment will follow automatically via
pages.yml workflow."* The deployment does follow; **not via `pages.yml`.** The sentence is
wrong about the mechanism, which is exactly the thing you need to be right when debugging.
Founder-gated (`.github/workflows/**`): **report, do not edit.**

⛔ **"Cloudflare is not in the loop" STOOD HERE AND IS FALSE (corrected 2026-09-13, #1314).**
Cloudflare Pages builds and deploys THIS repo. Measured, not inferred — on `17eedab` the commit
carries two check runs from the app `cloudflare-workers-and-pages`: *Cloudflare Pages* with
output *"Deployed successfully … Latest commit: `17eedab`"*, and *Workers Builds: echoelmusic*.
Re-derive on any commit:

```
curl -s "https://api.github.com/repos/vibrationalforce/Echoelmusic/commits/<sha>/check-runs" \
  | python3 -c "import json,sys; [print(r['name'], r.get('app',{}).get('slug')) \
                for r in json.load(sys.stdin)['check_runs']]"
```

⭐ **THE EVIDENCE THAT WAS QUOTED IS STILL CORRECT AND STILL DOES NOT ANSWER THE QUESTION.**
`git grep -c wrangler -- .github/workflows/` really is zero, and it stays zero: Cloudflare Pages
is a **GitHub App integration**, not a workflow — it watches pushes and reports a check run, so
it leaves no trace in `.github/`. A workflow-scoped grep cannot see a third deploy path by
construction, and answering "who deploys this" with it is the defect class
`.claude/rules/context.md` §2 names: a measurement that can only return LESS than the truth.
**Three deploy paths now exist, not two** (the two in the table above plus this one).

⚠️ **WHAT IS STILL OPEN, and it is a different question from the one that was answered wrongly:**
which host serves the APEX `echoelmusic.com`. Cloudflare deploying the repo does not prove the
domain points at it. So `_headers` and `_redirects` are **plausibly live, not provably** — do not
write them off as decoration (the old paragraph invited exactly that, and `docs/_headers` is
where `microphone=()` is closed after #1302). Still UNVERIFIED from this container: the agent
proxy 403s `echoelmusic.com`, re-measured today. One command from anywhere else settles it:
`curl -sI https://echoelmusic.com/hilfe` — a `301` means something honours them, a `404` means
they are decoration.

⚠️ **This correction deliberately gets NO guard.** A negative text scan for the struck sentence
would go red on this very retraction (#491), and the live fact lives in the GitHub API, not in a
repo file, so nothing in the tree can pin it.

⚠️ **`git log -- docs/` lies here.** This is a shallow clone grafted onto `545b19e`
(`.git/shallow` exists; `git rev-list --count origin/main` → **3**). Local history reaches back
one commit. I ran that query this session and read "1 docs commit since May" — the real number
is ≥40. **Any history question about `docs/` goes to `mcp__github__list_commits`, not to `git log`.**

## 3. A retraction I owe

I told the founder twice that **"8 of 10 `_redirects` aliases have no backing file."** Measured:
there are **8** aliases and **all 8 targets exist** (`/app`, `/download` → `overview.html`;
`/datenschutz`, `/agb`, `/hilfe`, `/barrierefreiheit`, `/gesundheit`, `/sicherheit` → their
`.html`). Neither half of that pair was right. Recorded here so the wrong pair is not re-quoted.

## 4. The site version is ONE number in three files — and moving it is part of a CSS fix

⛔ **THE FOUR-WAY DRIFT RECORDED HERE IS CLOSED (#1396, 2026-09-20), and the numbers are
deleted rather than refreshed (#818).** They said `version.json` 10.21.0 · `sw.js` 10.21.0 ·
`?v=` 10.14 in 16 pages · `index.html` carrying two more. Measure, do not read:

```
grep -o "CACHE_NAME = 'echoelmusic-v[0-9.]*'" docs/sw.js
grep -o '"version": "[0-9.]*"' docs/version.json
grep -ho 'shared\.css?v=[0-9.]*' docs/*.html | sort -u        # ONE line, or it has drifted
```

⚠️ **WHY THIS IS NOT BOOKKEEPING, measured the hard way in #1396.** The fix to `shared.css`
was on disk and the browser kept serving the broken file — the **service worker** was handing
out its cached copy, and only `Network.setBypassServiceWorker` made the repair visible. A real
returning visitor has no such switch. **A stylesheet repair that does not move `CACHE_NAME`
and the `?v=` query is a repair that does not ship.** Guard:
`Tests/CISmoke/TheSkipLinkIsVisibleWhenFocusedTests.swift`, claim 5 — it scans the whole
directory rather than a named page, because `index.html` is the one page that loads no
`shared.css` at all (§6) and a needle pointed there passes vacuously.

⚠️ `version.json`'s `features` block stays honest (`12UnifiedTools`, `3Editions`, `8Personas`,
`generativeWorlds`, `arWorlds` all `false`). Its `changelog` array is **not**: it narrates AUv3,
EchoelBeat, RTMP, "12 unified tools" and `EchoelCreativeWorkspace` — a type that has never
existed here (`git ls-files "*EchoelCreativeWorkspace*"` → 0). **A changelog is a claim surface
too**, and this one is still unrepaired.

The `features` block is honest where it matters — `12UnifiedTools`, `3Editions`, `8Personas`,
`generativeWorlds`, `arWorlds` all read `false`. **The `changelog` array is not**: it narrates
AUv3, EchoelBeat, RTMP, "12 unified tools" and `EchoelCreativeWorkspace` as shipped history.
The last of those is a type that has never existed in this repo
(`git ls-files "*EchoelCreativeWorkspace*"` → 0) and it is the same phantom two reviewer agents
carried until 2026-08-12. **A changelog is a claim surface too.**

## 5. Do NOT "fix" the AUv3 and RTMP mentions

⭐ **THE AUv3 HALF OF THIS SECTION IS STALE SINCE #1385 (2026-09-20; noted 2026-09-25) — the
pages were already corrected, this instruction was not.** Measured today
(`git grep -n -i auv3 -- 'docs/*.html'`): the site now says Echoelmusic **IS** an AUv3
instrument, confirmed loading and sounding in AUM, other hosts untested (`faq.html`,
`overview.html`, `architecture.html`), and that it does **not host** third-party AUv3 plugins.
So "never claim AUv3 (host or plugin)" below is wrong for the PLUGIN half: the claim that ships is
"AUv3 instrument, AUM-confirmed, not a host". `ContentPipeline/CLAIMS.md` flipped its pin the same
day and is the list to follow. The RTMP half stands. Numbers below (9 hits, 6 pages) are
2026-08 dates, not today's.

`git grep -ci AUv3 -- 'docs/*.html'` sums to **9** hits across 6 pages; RTMP to **10**. Every
single one is a **denial**, not a claim — *"not an AUv3 plugin and not an AUv3 host … both were
built and then deliberately removed"*, *"RTMP was never built — the publisher is a
compile-guarded scaffold and HaishinKit is not linked"*.

#158 and #192 each spent a whole cycle removing the AUv3 **claim** from this site; #184 removed
twelve from the App Store text. What is left is the correction. **A grep hit is not a finding**
— read the sentence before touching it, or you will delete the work those cycles paid for and
reopen a 2.3 rejection risk.

The one list of what is true today is **`ContentPipeline/CLAIMS.md`**. Read it before writing any
page copy, meta description, OG text or press line. Never claim: AUv3 (host or plugin) · RTMP /
live streaming · video **editing** (capture and MP4 export are real; the cut went with #121
Slice 3) · beat maker / drums · MPE **in** (⛔ this list said "MPE out" past #713 — OUT is
real and switchable since then; IN has no zone parser, #548 — a direction word decides the
truth here) · multitrack recording · motion as a bio input.

## 6. `index.html` is the odd one out

16 of 24 pages load `shared.css` + `shared.js`. Eight do not: three directory-index redirect
stubs (`privacy/`, `terms/`, `support/`, ~450 B each), three screenshot demos, `og-image.html`
— and **`index.html`**, the largest page in the directory at **63,899 B**, which instead carries
one inline `<style>` block of **21,942 chars** and no `shared.js` at all.

That is not automatically a defect (the homepage may want to inline its critical CSS), but it
means **a change to `shared.css` does not reach the homepage**. Any site-wide visual or a11y
change has to be made twice, and the second place is easy to miss. State which one you edited.

## 6b. One wide element takes the whole navigation off the screen

⛔ **Measured 2026-09-20 (#1397), headless Chromium at 390×844 against the served tree.**
`integrations.html` reported `documentElement.scrollWidth == 531` in a 390 px viewport, and
`.nav` — the fixed header — had a **used width of 531 px**. The burger button, the only door to
the menu at phone width, sat at **x = 467…507: entirely off-screen.** The navigation did not
exist on that page on a phone, and nothing looked wrong, because `body { overflow-x: hidden }`
swallows the scrollbar that would have betrayed it.

**The mechanism, because it is not obvious.** `body` carries `overflow-x: hidden` while `html`
leaves overflow `visible`, so that value PROPAGATES to the viewport and `body` itself keeps
behaving as `visible`. Any element wider than the screen therefore grows the initial containing
block — and a `position: fixed` box with `left: 0; right: 0` takes its width from THAT block, not
from the screen. So **a wide element anywhere on a page drags the fixed header out with it.**

The wide element was one `<table>` with no class. Three tables on that page carry
`class="spec-table"` (which becomes `display: block; overflow-x: auto` under 600 px); the fourth,
added with the OSC control-input slice, carried none and laid out at its natural 531 px.

**Two rules follow, and both are pinned by `Tests/CISmoke/TheNavCannotLeaveTheScreenTests.swift`:**

- **Every `<table>` in `docs/` gets `class="spec-table"`.** A new table style is fine — give it a
  `@media (max-width: 600px)` rule and add its class to that guard's `widthSafeTableClasses` in
  the same commit.
- **Every long unbreakable token needs `overflow-wrap`.** `shared.css` had no `code` rule at all
  until #1397; `<code>com.apple.developer.networking.multicast</code>` laid out at 337 px in a
  320 px viewport. `code, kbd, samp { overflow-wrap: anywhere; }` is the site-wide rule, and
  `.spec-table code { white-space: nowrap }` is its deliberate exception — inside a table that
  already scrolls, an address broken mid-path is unreadable. **They are a pair; remove one and
  the other misbehaves.**

⚠️ **`og-image.html` still overflows and is CORRECT.** It is a fixed 1200 px Open-Graph template
linked from nowhere (`grep -l og-image.html docs/*.html` → nothing), screenshotted at that size.
Named here so the next reflow sweep does not "repair" it.

Re-derive the whole sweep from anywhere with a browser: load each page at 390 and 320 px and
compare `document.documentElement.scrollWidth` against `clientWidth`. After this commit only
`og-image.html` differs.

## 6c. Heading order, and why promoting a tag is a CSS change too

⛔ **Measured 2026-09-20 (#1399): 13 headings on the site skipped a level** — `h1 → h3` on
claims, health and support; `h2 → h4` on accessibility, brainstorming, overview and tools — and
one `<h2>` on `integrations.html` ("What is not here") was immediately followed by another with
nothing between, i.e. it labelled an empty section while the paragraph written for it sat below
the table. A screen-reader user navigates a long page by heading, and the LEVEL is the outline:
`h2 → h4` says "sub-sub-point of the last thing" about cards that are peers.

**The repair is the tag, and the tag drags the CSS with it.** A browser's default `h3` is 1.17 em
against `h4`'s 1 em and `h2`'s 1.5 em, so a bare promotion grows the text ~17 % (or 50 %). Every
container rule was widened to name BOTH tags and given an explicit `font-size`:
`.feature-content`, `.warning-box`, `.contact-box` in `shared.css`; `.capability`, `.idea`,
`.pillar`, `.engine-item` inline in their own pages (§6 again — the split is real).

⚠️ **And one specificity trap, which is where the time went.** `.subpage h2:not(.page-cta h2)`
is (0,2,2); `.warning-box h2` is (0,1,1). Promoting a callout's `h3` to `h2` therefore handed it
to the generic rule — uppercase, 2 px letter-spacing — a restyle nobody asked for, caused by an
accessibility fix. The generic rule now carries `:not(.warning-box h2):not(.contact-box h2)`.

**Verified by measuring, not by reading:** computed `font-size`, `font-weight`, `color`,
`text-transform`, `letter-spacing`, `margin-top`, `margin-bottom`, `line-height` and
`font-family` for all 13 headings, before and after, in headless Chromium at 1024 px — **zero
differences.** Guard: `Tests/CISmoke/TheHeadingOrderNeverSkipsALevelTests.swift`.

⚠️ `h4` is NOT banned. A genuine third level under an `h3` is correct and the guard passes it;
so does an `h2` introducing a row of `h3` cards, which is the normal shape of every page here.

## 7. Before you commit a change here

- [ ] Copy checked against `ContentPipeline/CLAIMS.md`. No wellness / healing / esoteric framing,
      no "AUv3", no RTMP, no feature that is not in the app today.
- [ ] If you touched anything cache-versioned, say which of the four numbers you moved — and
      whether the other three now disagree by more than they did.
- [ ] If you touched a site-wide style or a11y rule, confirm whether `index.html` needs the same
      edit inline.
- [ ] If you added a `<table>`, it carries `class="spec-table"` (§6b) — an unclassed table takes
      the fixed header off a phone screen, silently.
- [ ] If you touched reflow-relevant CSS, re-measure `scrollWidth` vs `clientWidth` at 390 and
      320 px on every page, not only the one you edited (§6b).
- [ ] If you added a heading, its level is at most one deeper than the heading before it, and it
      has content under it (§6c). Promoting a tag needs the container's CSS rule widened and its
      `font-size` pinned, or the text silently grows.
- [ ] German legal pages (`impressum.html`, `privacy.html`, `terms.html`) are legal text, not
      marketing copy. Do not rewrite them for tone.
- [ ] Neither CI gate runs for a docs-only commit — both are `paths:`-filtered to `Sources/**`,
      `Tests/**`, `Package.swift`, `project.yml`. The state is **NOT TRIGGERED**, which is
      neither green nor red. Never report it as green.
- [ ] `.github/workflows/**` stays founder-gated. Findings about `pages.yml` or
      `auto-merge-docs.yml` go in the status delta, not in a diff.
