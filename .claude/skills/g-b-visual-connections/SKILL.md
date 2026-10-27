---
name: g-b-visual-connections
description: Visual snapshot with one timebase, off-by-default connections, golden protocol vectors and F25 for EchoelStudio W3/W4. Use when implementing visuals, Art-Net, OSC, ADM-OSC or connection egress.
---

# G-B Visual & Connections

Load the full contract and fixtures before any change.

## Key Rules
- One song timebase; visuals and outputs consume a compact VisualSnapshot.
- Connections start off. Address, port, protocol and activity are visible.
- No raw bio without explicit opt-in. Opt-out clears pending buffers.
- Golden byte vectors for proposed Art-Net/sACN/OSC messages; independent decoder check.
- Network outside the audio callback. Bounded queue, drop/coalesce, no cue storm on reconnect.
- F25 is the specific workflow allowlist for ConnectionsOutput; not a general blocker.

Reference checks and fixtures live alongside this skill or in scratchpads/grok-handover-2026-10-27/.
