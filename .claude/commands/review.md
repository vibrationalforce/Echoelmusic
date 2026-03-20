# Review — Staff Engineer Code Audit (Echoelmusic)

Perform a structured pre-landing code review. Merges GStack's comprehensive review workflow with Echoelmusic's domain-specific safety checks (audio thread, bio-safety, Swift 6 concurrency).

Use when: "review this PR", "code review", "pre-landing review", "check my diff".

---

## Step 0: Detect Base Branch

Determine which branch this PR targets. Use the result as "the base branch" in all subsequent steps.

1. Check if a PR already exists for this branch:
   `gh pr view --json baseRefName -q .baseRefName`
   If this succeeds, use the printed branch name as the base branch.

2. If no PR exists (command fails), detect the repo's default branch:
   `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`

3. If both commands fail, fall back to `main`.

Print the detected base branch name. In every subsequent `git diff`, `git log`,
and `git fetch` command, substitute the detected branch name wherever the
instructions say "the base branch" or `<base>`.

---

## Step 1: Check Branch

1. Run `git branch --show-current` to get the current branch.
2. If on the base branch, output: **"Nothing to review — you're on the base branch or have no changes against it."** and stop.
3. Run `git fetch origin <base> --quiet && git diff origin/<base> --stat` to check if there's a diff. If no diff, output the same message and stop.

---

## Step 1.5: Scope Drift Detection

Before reviewing code quality, check: **did they build what was requested — nothing more, nothing less?**

1. Read commit messages: `git log origin/<base>..HEAD --oneline`
2. Read PR description (`gh pr view --json body --jq .body 2>/dev/null || true`).
   Read `scratchpads/PLAN_*.md` files if they exist. Read `TODOS.md` if it exists.
   **If no PR exists:** rely on commit messages, plan files, and TODOS.md for stated intent.
3. Identify the **stated intent** — what was this branch supposed to accomplish?
4. Run `git diff origin/<base> --stat` and compare the files changed against the stated intent.
5. Evaluate with skepticism:

   **SCOPE CREEP detection:**
   - Files changed that are unrelated to the stated intent
   - New features or refactors not mentioned in the plan
   - "While I was in there..." changes that expand blast radius
   - Changes touching multiple EchoelTools when intent was scoped to one tool

   **MISSING REQUIREMENTS detection:**
   - Requirements from plan/PR description not addressed in the diff
   - Test coverage gaps for stated requirements
   - Partial implementations (started but not finished)

6. Output:
   ```
   Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
   Intent: <1-line summary of what was requested>
   Delivered: <1-line summary of what the diff actually does>
   [If drift: list each out-of-scope change]
   [If missing: list each unaddressed requirement]
   ```

7. This is **INFORMATIONAL** — does not block the review. Proceed to Step 2.

---

## Step 2: Get the Diff

Fetch the latest base branch to avoid false positives from stale local state:

```bash
git fetch origin <base> --quiet
git diff origin/<base>
git diff origin/<base> --stat
```

Read the full diff. This includes both committed and uncommitted changes.

---

## Step 2.5: Check for Greptile Review Comments (if available)

If a PR exists, check for Greptile bot comments:
```bash
gh pr view --json comments --jq '.comments[] | select(.author.login | test("greptile")) | .body' 2>/dev/null || true
```

If Greptile comments are found, classify each as: VALID & ACTIONABLE, VALID BUT ALREADY FIXED, FALSE POSITIVE, or SUPPRESSED. Store classifications for Step 5.

If no PR exists, `gh` fails, or there are zero Greptile comments: skip silently.

---

## Step 3: Two-Pass Review

Apply ALL checklists against the diff in two passes.

### Pass 1 — CRITICAL (blocks shipping)

Review for these categories. Each finding rated CRITICAL or HIGH.

#### 3.1 Audio Thread Safety

For any code in DSP kernels, render blocks, or audio processing paths:
- [ ] No `malloc`, `free`, `new`, `delete` — no heap allocation
- [ ] No `Array.append`, `Array.init`, `Dictionary` operations — allocates
- [ ] No `String()`, string interpolation — allocates
- [ ] No class instantiation on audio thread
- [ ] No `NSLog`, `print`, `os_log` in render paths (os_log OK in non-render paths)
- [ ] No `@objc` method calls — ObjC runtime overhead
- [ ] No `DispatchQueue`, `Task`, `async/await` — thread management
- [ ] No `NSLock`, `pthread_mutex`, semaphore — blocking
- [ ] No `fopen`, `fclose`, `read`, `write` — file I/O
- [ ] Only pre-allocated Float arrays, vDSP_*, memcpy, arithmetic, C math, ring buffers
- [ ] `nonisolated(unsafe)` for audio thread parameters
- [ ] Render block captures kernel, not `self`

**Launch audio-thread-reviewer agent:** For each changed file in audio/DSP paths, read the FULL file (not just diff hunks) and verify no audio-thread violations exist anywhere in the render path.

#### 3.2 Bio-Safety Compliance

- [ ] No unauthorized health claims (data for self-observation, NOT medical diagnosis)
- [ ] Safety warnings present where required (brainwave entrainment, vehicle operation, medications)
- [ ] Flash rate max 3 Hz (W3C WCAG epilepsy compliance)
- [ ] Apple Watch HR latency acknowledged (~4-5 sec) — no beat-sync with Watch HR
- [ ] RMSSD self-calculated (Apple only gives SDNN)
- [ ] No esoteric terminology (no chakras, auras, energy healing — SCIENCE-ONLY)
- [ ] Every wellness claim has peer-reviewed citation

**Launch bio-safety-reviewer agent:** For any changed file touching bio signals, health data, or visual effects, verify compliance with all bio-safety rules from CLAUDE.md.

#### 3.3 Swift 6 Concurrency

- [ ] `@MainActor` on ALL `@Observable` classes that touch UI
- [ ] `@Sendable` closures don't capture `@MainActor` refs unsafely
- [ ] No `self` before `super.init()` in init chains
- [ ] `@Observable` init assigns ALL stored properties before using `self`
- [ ] All Combine subscriptions stored in `cancellables`
- [ ] `Task { @MainActor in }` for async UI updates from non-isolated context
- [ ] `nonisolated(unsafe)` only for atomic-width audio thread parameters
- [ ] `@escaping` on `TaskGroup.addTask` closures

#### 3.4 Crash Prevention

- [ ] No force unwraps (`!` on optionals) — use `guard let`
- [ ] All divisions guarded (`divisor != 0`)
- [ ] All array access bounds-checked (`index < array.count`)
- [ ] No `@EnvironmentObject` without matching `.environmentObject()` injection
- [ ] No `print()` — use `log.log(.info, category:, "...")` only
- [ ] No UIKit usage without `#if canImport(UIKit)`
- [ ] No `#if os()` missing for platform-specific APIs
- [ ] `Foundation.log()` for math log (global `log` is EchoelLogger)

#### 3.5 Race Conditions & Data Safety

- Shared mutable state without synchronization
- Read-check-write without ensuring atomicity
- TOCTOU races: check-then-set that should be atomic
- vDSP overlapping accesses — inputs copied to temp vars before `vDSP_DFT_Execute`
- Concurrent collection mutations
- `nonisolated(unsafe)` misuse (only for atomic-width audio params)

#### 3.6 Enum & Value Completeness

When the diff introduces a new enum value, status string, or type constant:
- **Trace it through every consumer.** Use Grep to find all files that reference sibling values, then Read each match to check if the new value is handled.
- Check `switch`/`if-else` chains — does the new value fall through to a wrong default?
- Check allowlists/filter arrays containing sibling values.
- Verify type prefixes are correct (SessionMonitorMode vs StreamMonitorMode, etc.)
- This step requires reading code OUTSIDE the diff.

### Pass 2 — INFORMATIONAL (does not block shipping)

Review for these categories. Each finding rated MEDIUM or LOW.

#### 3.7 Architecture Compliance

- [ ] No new dependencies added without approval
- [ ] No new top-level directories
- [ ] Conventional commit messages used (`feat:`, `fix:`, `test:`, etc.)
- [ ] Changes scoped to one concern per commit
- [ ] No hardcoded values where config should be used
- [ ] No `ObservableObject` (use `@Observable` iOS 17+)
- [ ] No `UIScreen.main` (deprecated)
- [ ] No `Color.magenta` (doesn't exist — use `Color(red:1,green:0,blue:1)`)

#### 3.8 Performance

- [ ] Audio latency stays <10ms (FAIL at >15ms)
- [ ] CPU usage stays <30% (FAIL at >50%)
- [ ] Memory stays <200MB (FAIL at >300MB)
- [ ] Visual FPS target 120fps (FAIL at <60fps)
- [ ] Bio loop target 120Hz (FAIL at <60Hz)

#### 3.9 Conditional Side Effects

- Code paths that branch on a condition but forget a side effect on one branch
- Log messages claiming an action happened but the action was conditionally skipped

#### 3.10 Dead Code & Consistency

- Variables assigned but never read
- Comments/docstrings describing old behavior after code changed
- Stale platform-specific code without proper availability checks
- Version mismatch between different files

#### 3.11 Test Gaps

- New functionality without tests (TDD required per workflow)
- Negative-path tests that assert type/status but not side effects
- Security enforcement without integration tests
- Bio-signal processing changes without corresponding DSP test updates
- Missing tests where adding them is a "lake" not an "ocean"

#### 3.12 Magic Numbers & String Coupling

- Bare numeric literals in multiple files — should be named constants
- Error message strings used as query filters elsewhere

#### 3.13 UI Design Compliance (if diff touches SwiftUI views)

- [ ] No border radii > 16px (no pill shapes)
- [ ] No glassmorphism, frosted panels, blur hazes
- [ ] No glow effects, neon accents, shadow layers > 8px blur
- [ ] Transitions 100-200ms, opacity/color only
- [ ] Bio-signal displays: legible numbers first, visualization second
- [ ] Flash rate max 3 Hz (W3C WCAG)
- [ ] No decorative copy ("Live Pulse", "Neural Sync", "Quantum Flow")

---

## Step 4: Specialized Agent Reviews

For changes touching audio or bio code, launch parallel agents:

- **Audio changes detected:** Launch `audio-thread-reviewer` agent — deep DSP audit of every render path in changed files. Read full files, not just diff hunks.
- **Bio changes detected:** Launch `bio-safety-reviewer` agent — health compliance, flash rate, safety disclaimers, terminology audit.

These agents report findings back into the main review.

---

## Step 5: Fix-First Flow

**Every finding gets action — not just critical ones.**

Output a summary header: `Pre-Landing Review: N issues (X critical, Y informational)`

### Step 5a: Classify each finding as AUTO-FIX or ASK

```
AUTO-FIX (apply directly):                ASK (need human judgment):
├─ Dead code / unused variables            ├─ Audio thread safety violations
├─ Missing #if canImport guards            ├─ Bio-safety compliance issues
├─ Stale comments contradicting code       ├─ Race conditions
├─ print() → log.log() conversion         ├─ Concurrency design decisions
├─ Missing division guards (add guard)     ├─ Large fixes (>20 lines)
├─ Deprecated API replacement              ├─ Force unwrap removal (may need
│  (ObservableObject → @Observable,        │  logic change)
│   UIScreen.main removal)                 ├─ Enum completeness across consumers
├─ Dead imports                            ├─ Architecture changes
├─ Magic numbers → named constants         ├─ Removing functionality
└─ Variables assigned but never read       └─ Anything changing user-visible
                                              behavior
```

**Critical findings default toward ASK** (inherently riskier).
**Informational findings default toward AUTO-FIX** (more mechanical).

### Step 5b: Auto-fix all AUTO-FIX items

Apply each fix directly. For each one, output a one-line summary:
`[AUTO-FIXED] [file:line] Problem → what you did`

### Step 5c: Batch-ask about ASK items

If there are ASK items remaining, present them together:

- List each item with a number, severity label, problem, and recommended fix
- For each item: A) Fix as recommended, B) Skip
- Include an overall RECOMMENDATION

Example:
```
I auto-fixed 5 issues. 3 need your input:

1. [CRITICAL] Sources/Audio/DDSPKernel.swift:142 — malloc in render block
   Fix: Pre-allocate buffer in init, reuse in render
   → A) Fix  B) Skip

2. [CRITICAL] Sources/Bio/CoherenceEngine.swift:88 — Health claim without citation
   Fix: Replace "improves wellness" with "displays biometric trends"
   → A) Fix  B) Skip

3. [HIGH] Sources/Synth/VocalDSP.swift:203 — @Sendable closure captures @MainActor ref
   Fix: Copy value to local before closure
   → A) Fix  B) Skip

RECOMMENDATION: Fix all three — #1 will cause audio glitches, #2 violates
App Store guidelines, #3 is a Swift 6 concurrency violation.
```

### Step 5d: Apply user-approved fixes

Apply fixes for items where the user chose "Fix." Output what was fixed.

If no ASK items exist (everything was AUTO-FIX), skip the question entirely.

### Greptile comment resolution (if applicable)

After your own findings, if Greptile comments were classified in Step 2.5:

Include in output header: `+ N Greptile comments (X valid, Y fixed, Z FP)`

- **VALID & ACTIONABLE:** Include in findings, follow Fix-First flow.
- **FALSE POSITIVE:** Present with evidence of why it is incorrect; offer to reply.
- **VALID BUT ALREADY FIXED:** Note the fixing commit SHA.
- **SUPPRESSED:** Skip silently.

### Verification of claims

Before producing the final review output:
- If you claim "this pattern is safe" — cite the specific line proving safety
- If you claim "this is handled elsewhere" — read and cite the handling code
- If you claim "tests cover this" — name the test file and method
- Never say "likely handled" or "probably tested" — verify or flag as unknown

**Rationalization prevention:** "This looks fine" is not a finding. Either cite evidence it IS fine, or flag it as unverified.

---

## Step 5.5: TODOS Cross-Reference

Read `TODOS.md` in the repository root (if it exists). Also check `scratchpads/PLAN_*.md` and `scratchpads/SESSION_LOG.md`.

- **Does this PR close any open TODOs or planned items?** If yes, note: "This PR addresses: <title>"
- **Does this PR create work that should become a TODO?** If yes, flag as informational.
- **Are there related TODOs that provide context?** If yes, reference them.
- **Does this relate to any decisions in `memory/decisions.md`?** If yes, note the connection.

If none of these files exist, skip silently.

---

## Step 5.6: Documentation Staleness Check

Cross-reference the diff against documentation files. For each `.md` file in the repo root (CLAUDE.md, README.md, etc.) and `memory/` directory:

1. Check if code changes affect features, components, or workflows described in that doc.
2. If the doc was NOT updated but the code it describes WAS changed, flag as INFORMATIONAL:
   "Documentation may be stale: [file] describes [feature/component] but code changed in this branch."

This is informational only — never critical.

---

## Step 6: Final Report

Output structured review:
```
## Code Review — [branch] ([N] commits, base: [base branch])

### Scope Check
[CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
Intent: ...
Delivered: ...

### Findings
| # | File | Line | Severity | Category | Issue |
|---|------|------|----------|----------|-------|

### Auto-Fixed
- [file:line] Problem → fix applied

### Greptile
[If applicable: N comments (X valid, Y fixed, Z FP)]

### Summary
[count] findings: [X] CRITICAL, [Y] HIGH, [Z] MEDIUM, [W] LOW
Verdict: APPROVE / CHANGES REQUESTED (N blockers)
```

---

## Step 7: Completion Status

Report final status using one of:

- **DONE** — All steps completed successfully. No blockers found. Evidence provided for each claim.
- **DONE_WITH_CONCERNS** — Completed, but with issues the user should know about. List each concern.
- **BLOCKED** — Cannot proceed. State what is blocking and what was tried.
- **NEEDS_CONTEXT** — Missing information required to continue. State exactly what you need.

### Escalation

Bad work is worse than no work. It is always OK to stop and escalate.
- If you have attempted a task 3 times without success, STOP and escalate.
- If you are uncertain about a security-sensitive or bio-safety change, STOP and escalate.
- If the scope of work exceeds what you can verify, STOP and escalate.

```
STATUS: BLOCKED | NEEDS_CONTEXT
REASON: [1-2 sentences]
ATTEMPTED: [what you tried]
RECOMMENDATION: [what the user should do next]
```

---

## Severity Reference

| Severity | Meaning | Examples |
|----------|---------|---------|
| CRITICAL | Will crash, fail to compile, or violate safety | malloc on audio thread, force unwrap, health claims without citation |
| HIGH | Data race, security issue, silent data loss | Missing @MainActor, unguarded division, concurrency bug |
| MEDIUM | Performance, code smell, maintainability | Missing tests, hardcoded values, stale comments |
| LOW | Style, naming, minor improvement | Naming conventions, minor refactors |

---

## Suppressions — DO NOT Flag These

- Redundancy that aids readability
- "Add a comment explaining why this threshold was chosen" — thresholds change, comments rot
- "This assertion could be tighter" when it already covers the behavior
- Consistency-only changes that don't affect behavior
- ANYTHING already addressed in the diff — read the FULL diff before commenting
- Eval threshold changes tuned empirically
- Harmless no-ops

---

## Important Rules

- **Read the FULL diff before commenting.** Do not flag issues already addressed in the diff.
- **Fix-first, not read-only.** AUTO-FIX items applied directly. ASK items only after user approval. Never commit, push, or create PRs.
- **Be terse.** One line problem, one line fix. No preamble.
- **Only flag real problems.** Skip anything that's fine.
- **Boil the Lake.** When the complete fix costs minutes more than a shortcut, do the complete fix. Don't skip the last 10%.
- **SCIENCE-ONLY.** Flag any esoteric terminology, unsubstantiated health claims, or chakra/aura/energy healing language as CRITICAL.
