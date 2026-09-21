# /verify — Verification Loop

Run a comprehensive verification loop before any push or deploy.

## Usage
`/verify` or `/verify [specific-area]`

## Protocol

### 1. Build + Test Check — CI IS THE ONLY COMPILER AND THE ONLY TEST RUNNER

There is no local Swift toolchain in this environment. The previous version of this step said
`swift build` **MUST PASS** and gave the Linux case a comment instead of an instruction, and
`swift test` **MUST PASS** with no fallback at all — so the first two steps of the repo's own
verification loop could not be executed here and were skipped. That is the same class of defect
as a masked CI gate: a check that reports nothing and is read as approval.

Push the branch, then read the gates. The two that can turn a commit RED are `Xcode Compile
Check` and `Echoelmusic CI/CD Pipeline`. (They do not gate the merge: `auto-merge-claude.yml`
pushes `claude/**` to `main` with no `needs:` and no status-check wait. Red is a signal to you,
not a lock.) `⚡ Quick Test` runs neither a build nor a test — it is a hardcoded-secret grep.

```bash
# saved from mcp__github__actions_list (the raw response overflows context)
python3 scripts/gh-run-status.py <saved-tool-result.json>   # sha status conclusion run_id WORKFLOW-NAME title
```

⛔ **The gates are path-filtered** (`Sources/**`, `Tests/**`, `Package.swift`, `project.yml`,
and each workflow's own file). A commit that touches none of those produces **NO RUN** — and
`gh-run-status.py` will then print the previous commit's runs, all green. **Match the printed
`sha7` against `HEAD` before reading any conclusion. An absent run is not a pass.**

⛔ **A green conclusion is not proof a test ran.** `Echoel Full Test Suite (non-blocking)` carries
`continue-on-error` on its BUILD step, so it reports success even when nothing compiled. If this
verification concerns a test, read the job log lines, not the checkmark:

```
- build-for-testing:      <-- must say success
- test-without-building:  <-- must say success
```

Run `python3 scripts/doctor.py --section A` if you want that reasoning checked for you.

### 2. Audio Thread Safety (parallel agent)
Launch `audio-thread-reviewer` agent on all DSP/Audio files:
- `Sources/Echoelmusic/DSP/**/*.swift`
- `Sources/Echoelmusic/Audio/**/*.swift`
- `Sources/Echoelmusic/Tools/**/*.swift`   (PolySynthVoice, SubBassVoice — real render paths)

(The old list named two paths that no longer exist. `Sources/EchoelmusicAUv3/**` was deleted
with the AUv3 removal, #121 Slice 1 (`5ef8856`). `Sources/EchoelVoice/**` does not exist either,
but NOT for that reason — it has no source history in this checkout at all; it was a
Tuist-declared target that went with Tuist, separately and earlier, see
`docs/dev/APP_STORE_CONNECT.md`. Either way an agent scanning them reported "clean" for nothing.
Note this is a SHALLOW clone, so "was never here" can only ever mean "not in the history this
checkout has".)

### 3. Platform Guard Check
Every `.swift` file with UIKit/AppKit usage must have:
```swift
#if canImport(UIKit)
// ... iOS code
#endif
```
Scan: `grep -r "import UIKit" Sources/ --include="*.swift" -l`
Verify each has `#if canImport`

### 4. Code Quality Scan

⛔ **MEASURED 2026-09-21 (#1426): the three greps that stood here were wrong in BOTH
directions, and the force-unwrap one in the direction that HIDES work.** Run as written they
reported 2 force unwraps and 2 `print()` calls — and three of those four were PROSE: a doc
comment naming `NoteNaming(rawValue:)!`, `ProfessionalLogger`'s header saying it "replaces all
print() statements", and a Python snippet inside a comment in `TimelineStore`. A scan that
cries wolf on every run gets ignored, which is how `continue-on-error` stayed invisible for
14 hours. **And the same needle UNDER-reported:** `)!` is one spelling of four, so it found
**1 of the 4** real force-unwrap expressions in the tree. A measurement that can silently
return less than the truth is not a measurement (`.claude/rules/context.md` §2).

- Force unwraps: `grep -rnE '[A-Za-z0-9_)]!([^=A-Za-z0-9_]|$)' Sources/ --include="*.swift" | grep -v ': *//'`
- print() usage: `grep -rn 'print(' Sources/ --include="*.swift" | grep -v ': *//'`
- TODO/FIXME: `grep -rn 'TODO\|FIXME' Sources/ --include="*.swift" | grep -v ': *//'`

⚠️ **READ THE FORCE-UNWRAP RESULT WITH THIS SUBTRACTION, and do not read a short list as
"none".** Today it prints 18 lines. Fourteen are two known-benign KINDS a shell grep cannot
tell apart from an unwrap, and both are named here so nobody has to re-derive them:
- **Eleven implicitly-unwrapped DECLARATIONS** (`private var outputBus: AUAudioUnitBus!`),
  all in `Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift` — the standard `AUAudioUnit`
  allocate-later pattern, a declaration and not an unwrap.
- **Three sentences inside TRIPLE-QUOTED strings** that simply end in "!" (the share-sheet
  lines in `FXPreset`, `SynthPatch`, `MoodPreset`). `| grep -v ': *//'` cannot see them; the
  triple-quote-aware stripper exists in the blocking bundle, but as a PRIVATE helper on
  `TheStripperDoesNotKnowATripleQuoteTests` (`SourceText.codeOnly` deliberately does NOT
  know triple quotes — #659 — so do not reach for it here), and neither has a shell form.

**The FOUR real ones, all known and all allowed today — a FIFTH is work:**
- `Core/Project.swift:82` — `UUID(uuidString:)!` for `autosaveSlotID`. Knowingly bent, argued
  at the line, and pinned to the exact string by `AutosaveSlotTests`, so a typo goes red in
  CI before it ships.
- `Sequencer/AutomationCanvasMath.swift:67`, `Sequencer/TempoMatch.swift:65`,
  `Sequencer/TimelineAutomationRowMath.swift:135` — each `if best == nil || … best!…`, safe
  by short-circuit evaluation. ⚠️ **All three were INVISIBLE to the old needle**, so they had
  never been listed anywhere; they are written down here rather than rewritten, because three
  behaviour-preserving edits with no local Swift compiler is three chances to redden a gate
  for no user-visible gain. If they are ever rewritten, it is its own slice.

### 5. Bio Safety Check
Launch `bio-safety-reviewer` agent:
- All mandatory warnings present
- No health claims without citations
- HealthKit data stays on device
- Flash rate ≤ 3 Hz

### 6. Report

Report the instrument reading, not a verdict you wish were true. `[X/Y passed]` is not
available here — nothing in this environment counts tests, and a template that asks for a
number invites an invented one.

```
## Verification Report
Date:   [timestamp]
Branch: [branch]
HEAD:   [sha7]   ← every gate line below must be a run on THIS sha, or say "no run"

Xcode Compile Check:       ✅/❌/no run
Echoelmusic CI/CD Pipeline:✅/❌/no run
Full Test Suite (log):     build-for-testing: … / test-without-building: …
Audio Safety:   ✅/❌   (agent, this session)
Platform Guards:✅/❌
Code Quality:   ✅/❌
Bio Safety:     ✅/❌   (agent, this session)

VERDICT: READY / NOT-READY
```

## Escalation
If 3+ verification loops fail on the same issue:
1. Log the pattern to `/learn`
2. Update CLAUDE.md error patterns
3. Consider architectural change
