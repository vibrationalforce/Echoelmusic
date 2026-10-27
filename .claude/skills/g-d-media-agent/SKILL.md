---
name: g-d-media-agent
description: Camera ownership FSM with production priority, stable target IDs, document generation protection and non-destructive media edit for EchoelStudio W7/W9/W10. Use when touching video capture, face/motion sources or agent tools.
---

# G-D Media & Agent

## Key Rules
- One camera producer. Production (video) has priority over bio or face. Opt-out and permission denial are observable states. Generation drops late callbacks.
- Stable target IDs for agent results. documentGeneration protects against wrong-song application.
- Video uses AVFoundation/VideoToolbox; do not revive the old recorder that did not work.
- Non-destructive edit; results stay editable and undoable.
- Agent already has menu door, availability check and executor; preserve them.

Coordinates with G-A for source validity. Full contract in references or scratchpads.
