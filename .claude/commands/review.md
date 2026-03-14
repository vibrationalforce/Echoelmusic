# Review — Staff Engineer Code Audit

Perform a structured code review of recent changes. Inspired by gstack's /review command.

## Steps (execute sequentially):

### 1. Scope Changes
```bash
git diff main...HEAD --stat
git log main..HEAD --oneline
```

If no diff from main, review last 5 commits:
```bash
git diff HEAD~5...HEAD --stat
git log HEAD~5..HEAD --oneline
```

### 2. Structural Review

For each changed file, verify:

**Safety Checklist:**
- [ ] No force unwraps (`!` on optionals)
- [ ] All divisions guarded (divisor can't be zero)
- [ ] All array access bounds-checked
- [ ] No `@EnvironmentObject` without matching `.environmentObject()` injection
- [ ] `@MainActor` on all `@Observable` classes that touch UI
- [ ] No `print()` — use `log.log(.info, ...)` only
- [ ] No memory allocation on audio thread
- [ ] No UIKit usage without `#if canImport(UIKit)`

**Architecture Checklist:**
- [ ] No new dependencies added without approval
- [ ] No new top-level directories
- [ ] Conventional commit messages used
- [ ] Changes scoped to one concern per commit
- [ ] No hardcoded values where config should be used

**Concurrency Checklist:**
- [ ] All Combine subscriptions stored in cancellables
- [ ] `@Sendable` closures don't capture @MainActor refs
- [ ] No `self` before `super.init()` in init chains
- [ ] `@Observable` init assigns ALL stored properties before using `self`

### 3. Risk Assessment

Rate each finding:
| Severity | Meaning |
|----------|---------|
| CRITICAL | Will crash or fail to compile |
| HIGH | Data race, security issue, or silent data loss |
| MEDIUM | Performance issue, code smell, or maintainability concern |
| LOW | Style, naming, or minor improvement |

### 4. Report

Output a structured review:
```
## Code Review — [branch] ([N] commits)

### Findings
| # | File | Line | Severity | Issue |
|---|------|------|----------|-------|

### Summary
APPROVE / CHANGES REQUESTED with blocker count
```
