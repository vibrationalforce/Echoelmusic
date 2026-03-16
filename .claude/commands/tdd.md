# /tdd — Test-Driven Development Cycle

Run a TDD cycle for the specified feature or fix.

## Usage
`/tdd [feature description]`

## Protocol

### Step 1: Understand
- Read the feature/fix description
- Identify the module and files involved
- Check existing tests for the module

### Step 2: RED — Write Failing Test
```bash
# Create or modify test file
# Test naming: test[Unit]_[Scenario]_[ExpectedBehavior]
```

For DSP/Audio tests:
- Use `XCTAssertEqual(_:_:accuracy:)` for floating-point
- Pre-allocate buffers (simulate audio thread constraints)
- Test with known input signals (sine waves, impulses)

For AUv3 tests:
- Test parameter tree addresses
- Test factory preset loading
- Test state save/restore round-trip
- Test render block with mock input

### Step 3: Verify RED
```bash
swift test --filter [TestClassName] 2>&1 | tail -20
```
Must FAIL. If it passes, the test is meaningless — rewrite it.

### Step 4: GREEN — Minimal Implementation
- Write ONLY enough code to pass the test
- No optimization, no extra features, no cleanup
- Follow CLAUDE.md constraints (no force unwraps, os_log only, etc.)

### Step 5: Verify GREEN
```bash
swift test --filter [TestClassName] 2>&1 | tail -20
```
Must PASS. If it fails, fix the implementation (not the test).

### Step 6: REFACTOR
- Clean up while tests are green
- Extract only if 3+ repetitions
- Run full test suite to verify no regressions:
```bash
swift test 2>&1 | tail -20
```

### Step 7: Commit
```bash
git add [files]
git commit -m "test: add [description]"
git commit -m "feat: implement [description]"
```

## Rules
- ONE test at a time
- If test infrastructure doesn't exist, create it first
- Audio DSP values: always test with accuracy tolerance
- Bio values: test boundary conditions (coherence 0, 1, NaN)
- Never mock what you can test directly
