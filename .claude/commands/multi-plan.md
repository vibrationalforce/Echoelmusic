# /multi-plan — Multi-Agent Architecture Planning

Decompose a large task into parallel workstreams executed by specialized agents.

## Usage
`/multi-plan [task description]`

## Protocol

### 1. Task Decomposition
Break the task into independent workstreams that can run in parallel:

```
Agent 1: [Domain] — [Responsibility]
Agent 2: [Domain] — [Responsibility]
Agent 3: [Domain] — [Responsibility]
```

### 2. Default Echoelmusic Decomposition

For feature work:
```
Agent 1: DSP Kernel    — Lock-free audio processing implementation (DSP/, Foundation+Accelerate only)
Agent 2: Control plane — EngineBus subscriber, *Store/Codable persistence, EchoelParameterRegistry
                         + ParameterApplyRouter (the keyPath→live-setter seam), FeatureFlags
Agent 3: UI/Visual     — SwiftUI leaf view (no hot @Observable read in an ancestor), output-stage subscriber
```
⛔ "Agent 2: AUv3 Shell — AudioUnit, parameter tree, state, presets" stood here until #1112
(and Agent 3 said "ViewController"). The AUv3 extension target went 2026-07-24 (#121 Slice 2);
`AUParameterGroup` / `fullState` occur zero times in `Sources/`. A decomposition with an AUv3
agent hands one third of every feature to a product that does not exist.

⛔ AND THE SENTENCE THAT REPLACED IT IS GONE TOO (2026-09-12, #1302): it named
`MonitorInsertAudioUnit` (`Audio/MonitorInsertAU.swift`) as "the ONE `AUAudioUnit` in the
tree", and the founder removed it with the whole microphone rail. **There is no `AUAudioUnit`
in `Sources/`** — `git grep -nE ": *AUAudioUnit\b" -- Sources` → 0. Audio work is owned by
the DSP/audio agent through the `AVAudioSourceNode` render closures, never through a plugin
shell.

⭐ **AND BOTH ⛔ BLOCKS ABOVE ARE STALE SINCE #1385 (2026-09-20; noted 2026-09-25).** The AUv3
INSTRUMENT target is back: `project.yml` declares `EchoelmusicAUv3` (six targets now), and
`git grep -nE ": *AUAudioUnit\b" -- Sources` → 1 (`Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift`)
— parameter tree, `fullState`, factory presets and an `internalRenderBlock` are real again. It
compiles `DSP/` in isolation and hosts nothing. Its testable halves live in `DSP/`/`Core/`
(`EchoelBodyVibeDevice`, `EchoelBodyVibeAUv3Mapping`, `AUv3StateContract`); the extension itself
cannot be instantiated in a test bundle, so its render block is guarded by source scans
(`TheAUv3SuppliesItsOwnOutputBuffersTests` and its neighbours) and verified in a host (AUM, #1386). The decomposition above stays as it is: the AUv3 shell is thin and its logic lives in
`DSP/`, so it is still not a third of every feature.

For audits:
```
Agent 1: Core Systems  — App init, data flow, engine wiring
Agent 2: UI Layer      — Views, environment objects, navigation
Agent 3: Domain Logic  — Audio, bio, visual, lighting pipelines
```

For bug investigation:
```
Agent 1: Error Source   — Trace the error to its origin
Agent 2: Impact Scan    — Find all code affected by the issue
Agent 3: Fix + Test     — Implement fix and write regression test
```

### 3. Dependency Graph
Before launching agents, identify:
- Which agents are truly independent (can run in parallel)
- Which agents depend on outputs of others (must be sequential)
- Shared resources (files both agents might modify)

### 4. Launch Template
```
Launch Agent 1: [description]
  - Focus: [files/directories]
  - Output: [what to return]
  - Constraints: [don't modify X, read-only, etc.]

Launch Agent 2: [description]
  - Focus: [files/directories]
  - Output: [what to return]
  - Constraints: [...]

Launch Agent 3: [description]
  - Focus: [files/directories]
  - Output: [what to return]
  - Constraints: [...]
```

### 5. Synthesis
After all agents complete:
1. Merge findings/code from all agents
2. Resolve any conflicts
3. Run `/verify` to validate the combined result
4. Commit with clear description of what each agent contributed

## Rules
- Maximum 3 parallel agents (diminishing returns beyond that)
- Each agent gets a clear, non-overlapping scope
- Agents should NOT modify the same files
- If conflicts arise, human decides
- Always run `/verify` after merging agent outputs
