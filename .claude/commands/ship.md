# Ship — Pre-Release Checklist

Run the complete pre-release verification pipeline before any TestFlight or App Store submission.

## Steps (execute ALL sequentially):

### 0. iOS 26 SDK Validation (ITMS-90725)
Verify project targets iOS 26 SDK (deadline: April 28, 2026):
```bash
grep -E "deploymentTarget|IPHONEOS_DEPLOYMENT_TARGET|SDK" project.yml | head -5
```
BLOCKER if not targeting iOS 26 SDK.

### 1. Build Verification (platform-aware)
On macOS with Xcode:
```bash
swift build 2>&1
```
On Linux/web sessions: Check latest CI build status via GitHub API.
Must pass with zero errors. Warnings documented but non-blocking.

### 2. Test Suite (platform-aware)
On macOS:
```bash
swift test 2>&1
```
On Linux: Check latest CI test results via GitHub API.
Must pass 100%. No skipped tests without documented reason.

### 3. Audio Thread Safety Audit
Use the `audio-thread-reviewer` agent to scan all render callbacks for violations:
- No malloc, no locks, no ObjC, no file I/O, no GCD on audio thread

### 4. Bio-Safety Compliance
Use the `bio-safety-reviewer` agent to verify:
- All disclaimers present
- No unauthorized health claims
- Flash rate <3 Hz
- Privacy compliance

### 5. Crash Path Scan
Search for:
- Force unwraps (`!` not preceded by guard/if-let)
- Unguarded divisions
- Unguarded array access
- Missing `@MainActor` on ObservableObject
- Missing `.environmentObject()` injection

### 6. Performance Baseline
Verify targets:
- Audio latency: <10ms
- CPU: <30%
- Memory: <200MB
- Visual FPS: 120fps
- Bio loop: 120Hz

### 7. Git Status
```bash
git status
git log --oneline -10
```
Clean working tree. All changes committed with conventional prefixes.

## Output
Report: SHIP / NO-SHIP with blocker list if NO-SHIP.
