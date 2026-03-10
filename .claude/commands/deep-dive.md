# Deep Dive — Functional Audit

Run a deep functional audit of ALL systems. Find stubs, broken connections, and fake data.

## Strategy
Launch 3 parallel agents for maximum coverage:

### Agent 1: Audio/Sound/MIDI
Scan all files in:
- `Sources/Echoelmusic/Sound/`
- `Sources/Echoelmusic/Audio/`
- `Sources/Echoelmusic/MIDI/`
- `Sources/Echoelmusic/DSP/`

For each file: verify methods have real implementations, not stubs.
Flag: empty bodies, hardcoded returns, TODO/FIXME, `[Float](repeating: 0, ...)`.

### Agent 2: Video/Recording/Export
Scan all files in:
- `Sources/Echoelmusic/Video/`
- `Sources/Echoelmusic/Recording/`

Same stub detection as Agent 1.

### Agent 3: Visual/Bio/Stage/Net
Scan for implementations of:
- EchoelVis (visualization, Metal rendering)
- EchoelBio (HealthKit, bio-reactive)
- EchoelStage (external displays, projection)
- EchoelLux (DMX, Art-Net, lighting)
- EchoelNet (OSC, Dante, cloud sync)

Check if these exist as real code or only as CLAUDE.md documentation.

## Output
Table per system:
| Component | File | Status | Key Issue |

Status: WORKS / PARTIAL / STUB / MISSING
