# /evolve — Self-Improvement Loop

Analyze patterns from recent work and evolve the development system.

## Usage
`/evolve`

## Protocol

### 1. Analyze Recent History
```bash
git log --oneline -30
```
Identify:
- Recurring error patterns (same fix applied 3+ times)
- Slow iterations (commits that needed multiple fix-up commits)
- Successful patterns (clean single-commit features)

### 2. Error Pattern Mining
Search for recently fixed errors that should become permanent rules:
```bash
git log --grep="fix:" --oneline -20
```
For each fix:
- Was the error preventable?
- Should it be in CLAUDE.md error patterns?
- Should an agent rule catch it?

### 3. Agent Evolution
Review each agent in `.claude/agents/`:
- Are there new patterns it should check?
- Are any rules outdated?
- Should coverage be expanded?

Update agents with newly discovered rules.

### 4. Command Evolution
Review each command in `.claude/commands/`:
- Are there manual steps that should be automated?
- Are there steps that consistently fail and need better error handling?
- Should new commands be created?

### 5. CLAUDE.md Evolution
Add new patterns to CLAUDE.md:
- New build error patterns
- New API gotchas
- New type conflict resolutions
- Performance discoveries

### 6. Decision Review
Check `decisions.csv` for decisions due for review:
```bash
cat decisions.csv 2>/dev/null | while IFS=, read date decision reasoning outcome review status; do
    if [[ "$review" < "$(date +%Y-%m-%d)" ]] && [[ "$status" != "REVIEWED" ]]; then
        echo "DUE: $date - $decision"
    fi
done
```

### 7. Metrics Trend
Check `metrics.jsonl` for trends:
- Build times trending up/down?
- Test count growing?
- Error frequency decreasing?

### 8. Output
```markdown
## Evolution Report — [Date]

### New Patterns Added
- [pattern] → [agent/CLAUDE.md]

### Agents Updated
- [agent] — added [rule]

### Commands Updated
- [command] — improved [step]

### Decisions Reviewed
- [decision] — [keep/revise/retire]

### Metrics Trend
- [metric]: [trend]
```

## Goal
Every `/evolve` cycle should make the system slightly better.
The compound effect over 100 cycles should be dramatic.
