# Debug — Rapid Diagnostics

Gather diagnostic information fast. Run when something breaks and you need context before fixing.

## Steps

### 1. Situation Report
```bash
git branch --show-current
git status --short
git log --oneline -5
```

### 2. Build Status (platform-aware)

**macOS:**
```bash
swift build 2>&1 | tail -30
```

**Linux/web:**
```bash
gh run list --workflow ci.yml --limit 3 --json status,conclusion,headBranch 2>/dev/null || echo "No CI access"
```

### 3. Test Status (platform-aware)

**macOS:**
```bash
swift test 2>&1 | grep -E "(Test Suite|passed|failed|error:)" | tail -20
```

**Linux/web:**
```bash
gh run list --workflow quick-test.yml --limit 3 --json status,conclusion 2>/dev/null || echo "No CI access"
```

### 4. Code Quality Scan (changed files only)
```bash
git diff --name-only HEAD~3 | head -20
```

For each changed Swift file, scan for:
- Force unwraps (`!` not after guard/if-let)
- `print()` (banned — use `log.log()`)
- Missing `@MainActor` on `@Observable`
- Audio thread violations (malloc/locks in render blocks)
- Unguarded divisions

### 5. Diagnosis

Output structured report:
```
## Diagnostics — [branch]

Build: PASS / FAIL (N errors)
Tests: PASS / FAIL (N passed, M failed)
Quality: N issues in changed files

### Errors (if any)
[First 3 errors with file:line]

### Recommended Action
- Build fail → Launch `build-error-resolver` agent
- Test fail → Run `/test` on failed suites
- Quality issues → Run `/review`
- All clear → Continue with current task
```
