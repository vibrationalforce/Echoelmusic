# Review — Staff Engineer Code Audit (GStack + Echoelmusic)

Perform a structured pre-landing code review combining GStack's paranoid diff analysis with Echoelmusic's domain-specific safety checks. Use when asked to "review", "code review", "pre-landing review", or "check my diff".

## Steps (execute sequentially):

### 0. Detect Base Branch

```bash
_BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
echo "BASE: $_BASE"
```

### 1. Scope Changes

```bash
git fetch origin $_BASE --quiet
git diff origin/$_BASE --stat
git log origin/$_BASE..HEAD --oneline
```

If no diff from base, review last 5 commits:
```bash
git diff HEAD~5...HEAD --stat
git log HEAD~5..HEAD --oneline
```

### 1.5. Scope Drift Detection

Before reviewing code quality, check: **did they build what was requested?**

1. Read commit messages (`git log origin/<base>..HEAD --oneline`)
2. Identify the **stated intent** — what was this branch supposed to accomplish?
3. Compare files changed against stated intent
4. Flag:
   - **SCOPE CREEP:** Files changed unrelated to stated intent, "while I was in there" changes
   - **MISSING REQUIREMENTS:** Requirements not addressed in the diff

Output: `Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]`

### 2. Structural Review — Two-Pass Analysis

For each changed file, apply two review passes:

**Pass 1 — CRITICAL (production-breaking):**

| Category | What to hunt |
|----------|-------------|
| Race Conditions | Concurrent state mutation, missing locks, TOCTOU, async/await gaps |
| Trust Boundaries | Unvalidated external input, LLM output used without type-checking |
| Data Safety | Unguarded divisions, unguarded array access, force unwraps |
| Enum Completeness | New enum values not handled in all switch/if chains (read code OUTSIDE diff) |
| Integer Overflow | Arithmetic on user-supplied values without bounds checking |
| Deadlocks | Lock ordering violations, nested async waits |

**Pass 2 — INFORMATIONAL (code quality):**

| Category | What to hunt |
|----------|-------------|
| Dead Code | Unreachable branches, unused imports, commented-out code |
| Magic Values | Hardcoded strings/numbers where config should be used |
| Conditional Side Effects | State mutations inside conditions that may not execute |
| Test Gaps | Changed code paths without corresponding test coverage |

### 3. Echoelmusic Domain Checks

**Audio Thread Safety** (use `audio-thread-reviewer` agent for deep scan):
- [ ] No `malloc`, `free`, `new`, `delete` on audio thread
- [ ] No `Array.append`, `Array.init`, `String()`, `Dictionary` ops on audio thread
- [ ] No `NSLog`, `print`, `os_log` in render blocks
- [ ] No `@objc` method calls in render blocks
- [ ] No `DispatchQueue`, `Task`, `async/await` on audio thread
- [ ] No `NSLock`, `pthread_mutex`, `semaphore` on audio thread
- [ ] No file I/O on audio thread
- [ ] AUv3 render blocks capture kernel, not self

**Swift 6 Concurrency:**
- [ ] `@MainActor` on all `@Observable` classes that touch UI
- [ ] `@Sendable` closures don't capture @MainActor refs
- [ ] No `self` before `super.init()` in init chains
- [ ] All Combine subscriptions stored in `cancellables`
- [ ] `nonisolated(unsafe)` for audio thread parameters

**Platform & Safety:**
- [ ] No force unwraps (`!` on optionals)
- [ ] All divisions guarded (divisor can't be zero)
- [ ] All array access bounds-checked
- [ ] No `@EnvironmentObject` without matching `.environmentObject()` injection
- [ ] No `print()` — use `log.log(.info, ...)` only
- [ ] No UIKit usage without `#if canImport(UIKit)`
- [ ] No new dependencies added without approval
- [ ] No new top-level directories
- [ ] Conventional commit messages used

**Bio-Safety Compliance** (use `bio-safety-reviewer` agent if bio code changed):
- [ ] No unauthorized health claims
- [ ] Flash rate < 3 Hz (W3C WCAG epilepsy compliance)
- [ ] Privacy compliance for health data
- [ ] All disclaimers present

### 4. Risk Assessment

Rate each finding:
| Severity | Meaning |
|----------|---------|
| CRITICAL | Will crash, data race, security issue, or fail to compile |
| HIGH | Silent data loss, performance regression, trust boundary violation |
| MEDIUM | Code smell, maintainability concern, missing test coverage |
| LOW | Style, naming, minor improvement |

### 5. Fix-First Review

**Every finding gets action — not just critical ones.**

**Step 5a:** Classify each finding as AUTO-FIX or ASK:
- AUTO-FIX: Mechanical fixes (deprecated API, missing null check, dead code, stale imports)
- ASK: Judgment calls (architecture, race conditions, design decisions)

**Step 5b:** Apply all AUTO-FIX items directly. Output one line per fix:
`[AUTO-FIXED] [file:line] Problem → what you did`

**Step 5c:** Batch-ask about ASK items in ONE AskUserQuestion:
- List each with number, severity, problem, recommended fix
- Per-item options: A) Fix B) Skip
- Include overall RECOMMENDATION

**Step 5d:** Apply user-approved fixes.

### 6. Verification of Claims

Before producing final output:
- If you claim "this is safe" → cite the specific line proving safety
- If you claim "this is handled elsewhere" → read and cite the handling code
- If you claim "tests cover this" → name the test file and method
- Never say "likely handled" or "probably tested" — verify or flag as unknown

### 7. Report

Output a structured review:
```
## Code Review — [branch] ([N] commits)

Scope Check: [CLEAN / DRIFT / MISSING]

### Findings
| # | File | Line | Severity | Category | Issue |
|---|------|------|----------|----------|-------|

### Auto-Fixed
[list of auto-fixed items]

### Summary
APPROVE / CHANGES REQUESTED with blocker count

Pre-Landing Review: N issues — M auto-fixed, K asked (J fixed, L skipped)
```
