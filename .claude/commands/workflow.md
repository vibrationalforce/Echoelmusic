# Workflow Orchestration

Automated workflow for complex multi-step tasks. Combines planning, parallel execution, and self-verification.

## Phase 1: Plan
1. Read `scratchpads/SESSION_LOG.md` for context
2. Analyze task scope — break into atomic steps (max 5 min each)
3. Identify dependencies between steps
4. Write plan to `scratchpads/PLAN_<feature>.md`
5. If ambiguous, ask ONE clarifying question. Then proceed.

## Phase 2: Execute (Parallel Agents)
For independent subtasks, launch parallel agents:
```
Agent 1: Core systems (DSP, audio engine, data flow)
Agent 2: UI layer (Views, navigation, environment objects)
Agent 3: Domain logic (bio, visual, lighting, network)
```

For sequential tasks, use Ralph Wiggum Lambda: ONE fix per cycle.

## Phase 3: Verify
Before marking ANY task complete:
1. `swift build` — zero errors
2. `swift test --filter [relevant]` — green
3. No force unwraps, no divide-by-zero, no missing env objects
4. Audio thread: no locks, no malloc, no ObjC, no I/O
5. Bio safety: no health claims, disclaimers present

## Phase 4: Ship
1. Conventional commit: `feat:` / `fix:` / `refactor:` / `test:`
2. Update `scratchpads/SESSION_LOG.md`
3. Push to feature branch

## Principles
- **Demand Elegance** — No ugly hacks. Clean, minimal, correct.
- **Self-Improve** — After 3 failures on same issue, step back and rethink approach.
- **Autonomous Bug Fix** — If build breaks during feature work, fix it immediately.
- **One Thing at a Time** — Finish current task before starting next.
