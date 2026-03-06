# Ralph Wiggum Lambda Protocol

Execute ONE iteration of the Ralph Wiggum Lambda cycle.

## Steps (execute sequentially):

### 1. Status Check
```bash
git status && git log --oneline -5
```

### 2. Build Check
```bash
swift build 2>&1 | tail -30
```

### 3. Identify ONE Issue
From the build output, identify exactly ONE broken or unclear thing.
- Build errors take absolute priority
- Then test failures
- Then crash-prone code
- Then the current task

### 4. Fix It
Make the minimal change needed (max 3 files).

### 5. Test It
```bash
swift test --filter [relevant test suite] 2>&1 | tail -20
```

### 6. Commit
Use conventional commit format:
```
fix: [description]
```

### 7. Report
State what was fixed and what the next iteration should target.

## Rules
- ONE issue per cycle. No batching.
- Build fails = ONLY priority.
- No features during fix cycles.
- Convergence only.
