# Review — Paranoid Staff Engineer Code Audit

Comprehensive pre-landing review combining GStack's structural analysis with Echoelmusic's domain-specific safety checks. Analyzes diff against base branch for production-breaking bugs that tests don't catch.

Use when: "review this PR", "code review", "pre-landing review", "check my diff".

## Step 0: Detect Base Branch

```bash
_BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
echo "BASE: $_BASE"
```

Use the result as "the base branch" in all subsequent steps.

## Step 1: Check Branch

1. `git branch --show-current` — if on base branch, stop: "Nothing to review."
2. `git fetch origin $_BASE --quiet && git diff origin/$_BASE --stat` — if no diff, stop.

## Step 1.5: Scope Drift Detection

Before reviewing quality, check: **did they build what was requested — nothing more, nothing less?**

1. Read commit messages: `git log origin/$_BASE..HEAD --oneline`
2. Read `scratchpads/PLAN_*.md` or PR description for stated intent
3. Compare files changed against stated intent

Output:
```
Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
Intent: <1-line summary of what was requested>
Delivered: <1-line summary of what the diff actually does>
```

This is INFORMATIONAL — does not block the review.

## Step 2: Get the Diff

```bash
git fetch origin $_BASE --quiet
git diff origin/$_BASE
```

## Step 3: Two-Pass Review

### Pass 1 — CRITICAL (blocks shipping)

**Echoelmusic Audio Thread Safety:**
- [ ] No `malloc`, `free`, `new`, `delete` in render blocks
- [ ] No `NSLock`, `pthread_mutex`, `DispatchQueue`, `Task`, `async/await` on audio thread
- [ ] No `@objc` method calls in DSP kernels
- [ ] No `String()`, `Array.append`, `Dictionary` ops on audio thread
- [ ] No `os_log`, `print`, `fopen` in render paths
- [ ] Pre-allocated buffers only; ring buffer for lock-free patterns

**Echoelmusic Swift 6 Concurrency:**
- [ ] `@MainActor` on ALL `@Observable` classes that touch UI
- [ ] `@Sendable` closures don't capture `@MainActor` refs unsafely
- [ ] No `self` before `super.init()` in init chains
- [ ] `@Observable` init assigns ALL stored properties before using `self`
- [ ] All Combine subscriptions stored in `cancellables`

**Echoelmusic Crash Prevention:**
- [ ] No force unwraps (`!` on optionals) — use `guard let`
- [ ] All divisions guarded (`divisor != 0`)
- [ ] All array access bounds-checked (`index < array.count`)
- [ ] No `@EnvironmentObject` without matching `.environmentObject()` injection

**Race Conditions & Data Safety:**
- Shared mutable state without synchronization
- Read-after-write without ensuring order
- Concurrent collection mutations
- `nonisolated(unsafe)` misuse (only for atomic-width audio params)

**Trust Boundary Violations:**
- External/user input used without validation
- API responses used without type checking before storage

### Pass 2 — INFORMATIONAL (does not block)

**Echoelmusic Code Quality:**
- [ ] No `print()` — use `log.log(.info, category:, "...")` only
- [ ] No UIKit usage without `#if canImport(UIKit)`
- [ ] No `Color.magenta` (doesn't exist — use `Color(red:1,green:0,blue:1)`)
- [ ] Conventional commit messages used
- [ ] Changes scoped to one concern per commit
- [ ] No hardcoded values where config should be used
- [ ] Math `log()` not shadowed by EchoelLogger — use `Foundation.log()` or `logf()`

**Architecture:**
- [ ] No new dependencies added without approval
- [ ] No new top-level directories
- [ ] No `ObservableObject` (use `@Observable` iOS 17+)
- [ ] No `UIScreen.main` (deprecated)

**Bio-Safety Compliance:**
- [ ] Flash rate ≤ 3 Hz (W3C WCAG epilepsy)
- [ ] No unauthorized health claims
- [ ] Safety disclaimers present for brainwave entrainment
- [ ] Data labeled as "self-observation, NOT medical diagnosis"

**Enum & Value Completeness:**
When diff introduces new enum values, use Grep to find all switch/if statements handling sibling values. Read those files to verify new value is handled.

**Dead Code & Consistency:**
- Unused imports, variables, functions
- Inconsistent naming patterns
- Stale comments referencing removed code

## Step 4: Specialized Agent Reviews

For changes touching audio or bio code, launch agents in parallel:

- **Audio changes:** Launch `audio-thread-reviewer` agent for deep DSP audit
- **Bio changes:** Launch `bio-safety-reviewer` agent for health compliance

## Step 5: Fix-First Flow

### 5a: Classify each finding as AUTO-FIX or ASK

**AUTO-FIX** (apply directly):
- Missing `#if canImport` guards
- `print()` → `log.log()` conversion
- Deprecated API replacement (`UIScreen.main`, `ObservableObject`)
- Missing `@MainActor` on `@Observable` classes
- Dead imports

**ASK** (need user judgment):
- Race conditions
- Architecture changes
- Trust boundary violations
- Force unwrap removal (may need logic change)

### 5b: Auto-fix all AUTO-FIX items

Apply each fix. Output one line per fix:
`[AUTO-FIXED] [file:line] Problem → what you did`

### 5c: Batch-ask about ASK items

Present remaining items in ONE AskUserQuestion with per-item A) Fix / B) Skip options.

### 5d: Apply user-approved fixes

Apply fixes for items where user chose "Fix."

**Important:** Never commit, push, or create PRs — that's /ship's job.

## Step 5.5: TODOS Cross-Reference

If `scratchpads/SESSION_LOG.md` or any `scratchpads/PLAN_*.md` exists, cross-reference:
- Does this PR close any planned items?
- Does this PR create work that should become a task?

## Step 5.6: Documentation Staleness Check

For each `.md` file in repo root (CLAUDE.md, README.md, etc.):
- If code changes affect features described in that doc but the doc wasn't updated, flag as INFORMATIONAL:
  "Documentation may be stale: [file] describes [feature] but code changed."

## Step 6: Report

Output structured review:
```
## Code Review — [branch] ([N] commits)

### Scope Check
[CLEAN / DRIFT / MISSING from Step 1.5]

### Findings
| # | File | Line | Severity | Category | Issue |
|---|------|------|----------|----------|-------|

### Auto-Fixed
[List of auto-applied fixes]

### Summary
APPROVE / CHANGES REQUESTED with blocker count

STATUS: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
```

## Severity Ratings

| Severity | Meaning |
|----------|---------|
| CRITICAL | Will crash, fail to compile, or corrupt data |
| HIGH | Data race, security issue, audio thread violation, silent data loss |
| MEDIUM | Performance issue, code smell, missing platform guard |
| LOW | Style, naming, minor improvement |

## Rules

- Read the FULL diff before commenting. Don't flag issues already fixed in the diff.
- Fix-first, not read-only. AUTO-FIX directly, ASK before judgment calls.
- Be terse. One line problem, one line fix. No preamble.
- Only flag real problems. Skip anything that's fine.
- Verify claims: "this is handled elsewhere" → cite the code. Never say "probably tested."
