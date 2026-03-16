# /verify — Verification Loop

Run a comprehensive verification loop before any push or deploy.

## Usage
`/verify` or `/verify [specific-area]`

## Protocol

### 1. Build Check
```bash
swift build 2>&1 | tail -30
# On Linux: static analysis only
```
**MUST PASS.** If build fails, stop and fix.

### 2. Test Check
```bash
swift test 2>&1 | tail -30
```
**MUST PASS.** If tests fail, stop and fix.

### 3. Audio Thread Safety (parallel agent)
Launch `audio-thread-reviewer` agent on all DSP/Audio files:
- `Sources/EchoelVoice/**/*.swift`
- `Sources/EchoelmusicAUv3/**/*.swift`
- `Sources/Echoelmusic/DSP/**/*.swift`
- `Sources/Echoelmusic/Audio/**/*.swift`

### 4. Platform Guard Check
Every `.swift` file with UIKit/AppKit usage must have:
```swift
#if canImport(UIKit)
// ... iOS code
#endif
```
Scan: `grep -r "import UIKit" Sources/ --include="*.swift" -l`
Verify each has `#if canImport`

### 5. Code Quality Scan
- Force unwraps: `grep -rn ')\!' Sources/ --include="*.swift"` (exclude `!=`)
- print() usage: `grep -rn 'print(' Sources/ --include="*.swift"`
- TODO/FIXME: `grep -rn 'TODO\|FIXME' Sources/ --include="*.swift"`

### 6. Bio Safety Check
Launch `bio-safety-reviewer` agent:
- All mandatory warnings present
- No health claims without citations
- HealthKit data stays on device
- Flash rate ≤ 3 Hz

### 7. Report
```
## Verification Report
Date: [timestamp]
Branch: [branch]

Build:          ✅/❌
Tests:          ✅/❌ [X/Y passed]
Audio Safety:   ✅/❌
Platform Guards:✅/❌
Code Quality:   ✅/❌
Bio Safety:     ✅/❌

VERDICT: READY / NOT-READY
```

## Escalation
If 3+ verification loops fail on the same issue:
1. Log the pattern to `/learn`
2. Update CLAUDE.md error patterns
3. Consider architectural change
