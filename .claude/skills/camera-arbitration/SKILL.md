---
name: camera-arbitration
description: One-producer camera FSM, production priority, permission handling and generation drop for late callbacks. Use when adding any camera source (rPPG, face, video).
---

# Camera Arbitration

## Rules
- Exactly one producer owns the camera. Production video wins over bio or face when both request it.
- Opt-in starts producer; opt-out stops it and invalidates pending callbacks.
- Every source change gets a generation. Late callbacks from old generation are dropped.
- Permission denied, session interruption and source disconnect are observable states.
- Platform declarations (Info.plist, entitlements) are missing for camera; prepare gated review-only diffs. Do not edit project.yml directly.

Coordinates with bio-safety-reviewer and G-A/G-D contracts.
