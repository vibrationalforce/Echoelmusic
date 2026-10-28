---
name: g-a-body-modulation
description: Body frame source, modulation math, validity rules, and format-3 migration for Echoel. Use when implementing or reviewing W1/W2 body-to-modulation path. Load CONTRACT, FIXTURES and run reference.py --selftest.
---

# G-A Body Modulation

Read the contract and distinguish proposed policies from frozen production schema.
Production code stays Claude-only. Keep the render thread free. No diagnostic claims.

## References
- references/CONTRACT.md
- references/FIXTURES.json
- references/reference.py

Run from the repository root:
`python3 .claude/skills/g-a-body-modulation/references/reference.py --selftest`

Fixtures default to the script's sibling file; `--fixtures PATH` selects alternatives.
Python success proves the reference contract only. Port the cases to Swift behaviour
tests and keep sensor, audio, persistence and device acceptance separate.
Start the combined handover at `scratchpads/grok-handover-2026-10-27/README.md`.

Permissions gap is real (no Camera/Bluetooth/Health yet). Production has priority. Coordinate with G-D.
