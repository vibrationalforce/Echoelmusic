# Decisions Log

Architectural and strategic decisions with context and rationale.

## Format

### [DATE] Decision Title
- **Decision:** What was decided
- **Reasoning:** Why this choice was made
- **Alternatives considered:** What else was evaluated
- **Expected outcome:** What we expect to happen
- **Review date:** When to revisit this decision

---

### 2026-03-11 Persistent Memory System
- **Decision:** Created /memory directory for cross-session context retention
- **Reasoning:** scratchpads/ serves session-specific logs; memory/ stores durable knowledge that should persist indefinitely
- **Alternatives considered:** Extending scratchpads/, using .ai/ directory
- **Expected outcome:** Faster session starts, no repeated discovery of known facts
- **Review date:** 2026-04-10
