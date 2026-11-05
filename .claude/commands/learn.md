# /learn — Continuous Learning & Knowledge Persistence

Capture insights from the current session and persist them for future sessions.

## Usage
`/learn [topic or insight]`

## Protocol

### 1. Gather Session Insights
Analyze the current session for:
- Build errors encountered and their fixes
- Architectural decisions made
- Performance discoveries
- API gotchas found
- Pattern solutions that worked

### 2. Update Knowledge Base

#### `echoelmusic-intern/memory/decisions.md` — Architectural Decisions
```markdown
## [Date] — [Decision Title]
**Decision:** [What was decided]
**Reasoning:** [Why]
**Alternatives:** [What else was considered]
**Review Date:** [30 days from now]
```

#### `echoelmusic-intern/decisions.csv` — Machine-Readable Log
```csv
date,decision,reasoning,expected_outcome,review_date,status
```

#### `CLAUDE.md` — Critical Build Error Patterns
If a new error pattern was discovered, add it to the
"CRITICAL BUILD ERROR PATTERNS" section:
```markdown
| Pattern | Fix |
|---------|-----|
| [error message] | [solution] |
```

#### `echoelmusic-intern/scratchpads/SESSION_LOG.md` — Session Summary
```markdown
## Session [Date]
**Branch:** [branch]
**Commits:** [list]
**Key Discoveries:**
- [insight 1]
- [insight 2]
**Unresolved:**
- [issue still open]
```

### 3. Update Agent Knowledge
If a specialized agent (DSP, audio-thread, bio-safety) needs new rules:
- Add the rule to the agent's `.md` file in `.claude/agents/`
- Include the specific pattern and its fix

### 4. Review Overdue Decisions
Check `echoelmusic-intern/decisions.csv` for any decisions past their review date:
```bash
# Find decisions due for review
./review.sh   # run in the private repo echoelmusic-intern
```

## Rules
- ALWAYS update `echoelmusic-intern/scratchpads/SESSION_LOG.md` at session end
- ALWAYS log architectural decisions to both `echoelmusic-intern/memory/decisions.md` AND
  `echoelmusic-intern/decisions.csv`
- New error patterns → update CLAUDE.md
- New agent rules → update agent .md files
- Keep insights specific and actionable (not vague)
- Include file paths and line numbers where relevant
