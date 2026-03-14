# Ralph Wiggum Lambda Protocol

Execute ONE iteration of the Ralph Wiggum Lambda cycle.

## Steps (execute sequentially):

### 1. Status Check
```bash
git status && git log --oneline -5
```

### 2. Build Check
If on Linux (no Xcode), use CI-based verification:
- Check latest GitHub Actions run status
- Read build annotations for errors
- Audit code statically for known crash patterns

If on macOS:
```bash
swift build 2>&1 | tail -30
```

### 3. Identify ONE Issue
From the build output or CI logs, identify exactly ONE broken or unclear thing.
- Build errors take absolute priority
- Then test failures
- Then crash-prone code
- Then the current task

### 4. Fix It
Make the minimal change needed (max 3 files).

### 5. Test It
If on macOS:
```bash
swift test --filter [relevant test suite] 2>&1 | tail -20
```

If on Linux: verify fix via static analysis (grep for known error patterns).

### 6. Commit
Use conventional commit format:
```
fix: [description]
```

### 7. Log Metrics
Append cycle result to `metrics.jsonl`:
```bash
python3 -c "
import json, datetime, subprocess
commit = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).decode().strip()
entry = {
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'commit': commit,
    'event': 'RALPH_WIGGUM_CYCLE',
    'metrics': {'issue': 'DESCRIBE_ISSUE', 'result': 'FIXED'}
}
print(json.dumps(entry))
" >> metrics.jsonl
```

### 8. Report
State what was fixed and what the next iteration should target.
Include cycle count and trend from metrics.jsonl if available.

## Rules
- ONE issue per cycle. No batching.
- Build fails = ONLY priority.
- No features during fix cycles.
- Convergence only.
- Log every cycle to metrics.jsonl for trend tracking.
