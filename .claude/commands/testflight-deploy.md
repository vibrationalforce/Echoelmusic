# TestFlight Deploy

Deploy the current branch to TestFlight via GitHub Actions.

## Pre-flight Checks

### 1. Verify clean working tree
```bash
git status
```
If there are uncommitted changes, commit them first.

### 2. Verify build (platform-aware)
On macOS with Xcode:
```bash
swift build 2>&1 | tail -20
```
On Linux/web sessions (no Xcode): Skip local build — CI will verify.
Check latest CI status instead:
```bash
GITHUB_TOKEN=$(python3 -c "import json; print(json.load(open('.claude/settings.local.json'))['github']['token'])" 2>/dev/null)
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/actions/runs?per_page=3" | python3 -c "
import json,sys
for r in json.load(sys.stdin).get('workflow_runs',[])[:3]:
    print(f'{r[\"status\"]:12} {r[\"conclusion\"] or \"pending\":12} {r[\"name\"]:20} {r[\"created_at\"][:16]}')
"
```

### 3. Verify tests (platform-aware)
On macOS: `swift test 2>&1 | tail -30`
On Linux: Skip — CI runs tests. Check CI status from step 2.

### 4. iOS 26 SDK Validation
Verify project.yml targets iOS 26 SDK (ITMS-90725 deadline: April 28, 2026):
```bash
grep -E "deploymentTarget|IPHONEOS_DEPLOYMENT_TARGET" project.yml | head -5
```

### 5. Push to remote
```bash
git push -u origin $(git branch --show-current)
```

### 6. Read GitHub token from local settings
```bash
GITHUB_TOKEN=$(python3 -c "import json; print(json.load(open('.claude/settings.local.json'))['github']['token'])" 2>/dev/null)
```
If token is not found, ask the user to set it up in `.claude/settings.local.json`.

### 7. Trigger TestFlight workflow
```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/actions/workflows/testflight.yml/dispatches" \
  -d "{\"ref\":\"$(git branch --show-current)\",\"inputs\":{\"platform\":\"ios\",\"skip_tests\":\"true\"}}" -w "\n%{http_code}"
```
HTTP 204 = success. Use `"platform":"all"` for multi-platform deploy.

### 8. Monitor workflow status
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
