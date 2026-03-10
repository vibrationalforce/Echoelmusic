# Ship — Pre-Release Checklist

Run the complete pre-release verification pipeline before any TestFlight or App Store submission.

## Steps (execute ALL sequentially):

### 1. Build Verification
```bash
swift build 2>&1
```
Must pass with zero errors. Warnings documented but non-blocking.

### 2. Test Suite
```bash
swift test 2>&1
```
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
