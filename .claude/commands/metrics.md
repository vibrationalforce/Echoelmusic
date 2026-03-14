# Metrics — Track Build & Performance Over Time

Record metrics from the current build/test cycle into `metrics.jsonl`.
Inspired by pi-autoresearch: append-only log, measure everything, keep what works.

## Usage

Run after any build, test, or deploy cycle to log results.

## Steps (execute sequentially):

### 1. Gather Metrics

Collect available data points:

```bash
# Build number from last TestFlight run
GITHUB_TOKEN=$(python3 -c "import json; print(json.load(open('.claude/settings.local.json'))['github']['token'])" 2>/dev/null)
BUILD_INFO=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/actions/runs?per_page=1" | python3 -c "
import json,sys
r=json.load(sys.stdin)['workflow_runs'][0]
print(json.dumps({'run_number': r['run_number'], 'status': r['status'], 'conclusion': r.get('conclusion','pending'), 'branch': r['head_branch']}))")
echo "$BUILD_INFO"
```

```bash
# Repo stats
echo "commits: $(git rev-list --count HEAD)"
echo "swift_files: $(find Sources -name '*.swift' | wc -l)"
echo "test_files: $(find Tests -name '*.swift' | wc -l)"
echo "loc: $(find Sources -name '*.swift' -exec cat {} + | wc -l)"
```

### 2. Log to metrics.jsonl

Append a JSON line with timestamp, metrics, and context:

```bash
python3 -c "
import json, datetime, subprocess

# Git info
commit = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).decode().strip()
branch = subprocess.check_output(['git', 'branch', '--show-current']).decode().strip()
commit_count = subprocess.check_output(['git', 'rev-list', '--count', 'HEAD']).decode().strip()

entry = {
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'commit': commit,
    'branch': branch,
    'commit_count': int(commit_count),
    'event': 'BUILD_RESULT',  # or TEST_RESULT, DEPLOY_RESULT
    'metrics': {}
}

print(json.dumps(entry))
" >> metrics.jsonl
```

### 3. Show Trend

Display last 10 entries:

```bash
tail -10 metrics.jsonl | python3 -c "
import json, sys
for line in sys.stdin:
    try:
        e = json.loads(line)
        ts = e['timestamp'][:16]
        event = e.get('event', '?')
        commit = e.get('commit', '?')
        metrics = e.get('metrics', {})
        conclusion = metrics.get('conclusion', e.get('conclusion', ''))
        print(f'{ts} | {commit} | {event:15s} | {conclusion}')
    except: pass
"
```

## Metric Types

| Event | What's Measured |
|-------|----------------|
| `BUILD_RESULT` | CI pass/fail, compile duration, warning count |
| `TEST_RESULT` | Test count, pass/fail, duration |
| `DEPLOY_RESULT` | TestFlight build number, upload success |
| `PERF_BASELINE` | Audio latency, CPU%, memory, FPS |
| `BUNDLE_SIZE` | IPA size, binary size |

## Rules
- Append-only. Never edit existing entries.
- One entry per event.
- Always include commit hash for traceability.
- metrics.jsonl is gitignored (local-only tracking).
