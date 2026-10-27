---
name: g-a-body-modulation
description: Body frame source, modulation math, validity rules, and format-3 migration for Echoel. Use when implementing or reviewing W1/W2 body-to-modulation path. Load CONTRACT, FIXTURES and run reference.py --selftest.
---

# G-A Body Modulation

Follow the contract exactly. Production code stays Claude-only. Keep render thread free. No diagnostic claims.

## References
- references/CONTRACT.md
- references/FIXTURES.json
- references/reference.py

Run: `python3 references/reference.py --selftest --fixtures references/FIXTURES.json`

Permissions gap is real (no Camera/Bluetooth/Health yet). Production has priority. Coordinate with G-D.
