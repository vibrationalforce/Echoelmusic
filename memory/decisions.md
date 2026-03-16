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

### 2026-03-16 EchoelVoice as First AUv3 Product
- **Decision:** Build EchoelVoice (bio-reactive vocal processor) as first standalone AUv3 plugin
- **Reasoning:** Zero competition in bio+audio+visual AUv3 space. Vocal processing highest-demand category. $14.99 validated.
- **Alternatives considered:** EchoelFX (effects), EchoelSynth (synthesis) — deferred
- **Expected outcome:** First revenue-generating plugin, validates AUv3 pipeline
- **Review date:** 2026-04-16

### 2026-03-16 iOS 17+ for AUv3 Targets
- **Decision:** Raise AUv3 deployment targets to iOS 17.0
- **Reasoning:** `@Observable` requires iOS 17+. ObservableObject banned per CLAUDE.md.
- **Alternatives considered:** Stay on iOS 15 with ObservableObject — rejected
- **Expected outcome:** Modern SwiftUI patterns, cleaner ViewModel code
- **Review date:** 2026-04-16

### 2026-03-16 Claude Code Enhancement System
- **Decision:** Integrate everything-claude-code patterns (agents, commands, rules)
- **Reasoning:** Structured TDD, planning, security, and verification workflows accelerate development
- **Alternatives considered:** Install full generic repo — rejected, adapted to Echoelmusic context
- **Expected outcome:** Faster iteration cycles, fewer regressions, self-improving system
- **Review date:** 2026-04-16

### 2026-03-16 Replace LiquidGlass with EchoelSurface Design System
- **Decision:** Removed all glassmorphism (blur, .ultraThinMaterial, glow blend modes, >8px shadows, pill shapes) and replaced with EchoelSurface — solid fills, subtle 1px borders, shadows capped at 8px, corners capped at 12px
- **Reasoning:** LiquidGlass violated every design constraint in CLAUDE.md (glassmorphism, glow effects, large shadows, scale animations). Corporate design requires Linear/Stripe aesthetic — functional, minimal, precise
- **Alternatives considered:** Keeping LiquidGlass with reduced effects — rejected, fundamentally wrong approach
- **Expected outcome:** Clean, compliant UI matching brand identity. Backward-compatible type aliases prevent breaking existing code
- **Review date:** 2026-04-16

### 2026-03-16 Wire All 12 EchoelTools into App
- **Decision:** Initialize EchoelSeqEngine, EchoelLuxEngine, EchoelAIEngine, OSCEngine in workspace.deferredSetup(). Add Sequencer, Bio, Lighting, AI panels to EchoelStudioView bottom bar (scrollable)
- **Reasoning:** 4 engines had code but were never initialized. 4 views existed but had no navigation path. Users couldn't access major advertised features
- **Alternatives considered:** Leaving uninitialized (broken UX) — rejected
- **Expected outcome:** All 12 EchoelTools accessible from studio workspace
- **Review date:** 2026-04-16

---

### 2026-03-11 Persistent Memory System
- **Decision:** Created /memory directory for cross-session context retention
- **Reasoning:** scratchpads/ serves session-specific logs; memory/ stores durable knowledge that should persist indefinitely
- **Alternatives considered:** Extending scratchpads/, using .ai/ directory
- **Expected outcome:** Faster session starts, no repeated discovery of known facts
- **Review date:** 2026-04-10
