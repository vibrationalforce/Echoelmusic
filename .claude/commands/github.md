# GitHub Operations

Perform GitHub API operations using the stored token from `.claude/settings.local.json`.

## Setup
Read the token:
```bash
GITHUB_TOKEN=$(python3 -c "import json; print(json.load(open('.claude/settings.local.json'))['github']['token'])" 2>/dev/null)
```
If empty, tell the user to configure `.claude/settings.local.json` with their GitHub PAT.

Base URL: `https://api.github.com/repos/vibrationalforce/Echoelmusic`

## Available Operations

### List recent workflow runs
```bash
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "$BASE_URL/actions/runs?per_page=5" | python3 -c "
import json,sys
for r in json.load(sys.stdin)['workflow_runs']:
    print(f'{r[\"status\"]:12} {r[\"conclusion"] or \"\":10} {r[\"name\"]:20} #{r[\"run_number\"]} {r[\"html_url\"]}')
"
```

### Get workflow run details
```bash
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "$BASE_URL/actions/runs/$RUN_ID"
```

### Create PR
```bash
curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "$BASE_URL/pulls" -d '{"title":"...","body":"...","head":"branch","base":"main"}'
```

### List open PRs
```bash
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "$BASE_URL/pulls?state=open"
```

### List issues
```bash
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "$BASE_URL/issues?state=open&per_page=10"
```

Use the appropriate operation based on what the user asks for. Always read the token first.
