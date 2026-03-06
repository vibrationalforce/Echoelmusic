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

### 5. Trigger TestFlight workflow
```bash
gh workflow run testflight.yml --ref $(git branch --show-current)
```

### 6. Monitor
```bash
gh run list --workflow=testflight.yml --limit=1
```

Report the workflow run URL and status.
