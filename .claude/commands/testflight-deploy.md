# TestFlight Deploy

Deploy the current branch to TestFlight via GitHub Actions.

## Pre-flight Checks

### 1. Verify clean working tree
```bash
git status
```
If there are uncommitted changes, commit them first.

### 2. Verify build
```bash
swift build 2>&1 | tail -20
```
Build must pass. If not, fix before deploying.

### 3. Verify tests
```bash
swift test 2>&1 | tail -30
```
Tests must pass. If not, fix before deploying.

### 4. Push to remote
```bash
git push -u origin $(git branch --show-current)
```

### 5. Read GitHub token from local settings
```bash
GITHUB_TOKEN=$(python3 -c "import json; print(json.load(open('.claude/settings.local.json'))['github']['token'])" 2>/dev/null)
```
If token is not found, ask the user to set it up in `.claude/settings.local.json`.

### 6. Trigger TestFlight workflow
```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/actions/workflows/testflight.yml/dispatches" \
  -d "{\"ref\":\"$(git branch --show-current)\"}" -w "\n%{http_code}"
```
HTTP 204 = success.

### 7. Monitor workflow status
```bash
sleep 5 && curl -s \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/actions/runs?per_page=1" | python3 -c "
import json,sys
r=json.load(sys.stdin)['workflow_runs'][0]
print(f'Run: {r[\"name\"]} #{r[\"run_number\"]}')
print(f'Status: {r[\"status\"]}')
print(f'URL: {r[\"html_url\"]}')
"
```

Report the workflow run URL and status.
