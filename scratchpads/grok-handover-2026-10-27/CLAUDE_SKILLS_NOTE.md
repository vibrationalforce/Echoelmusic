# Claude Skills Note — 2026-10-27

Skills added on branch `claude/gsidmmw-skills-and-mods-2026-10-27`:

- g-b-visual-connections
- g-c-sound-recovery
- g-d-media-agent
- format-v3-migration
- camera-arbitration
- offline-export-freeze
- permissions-gated-diff

They are short, triggerable SKILL.md files. Full contracts, fixtures and reference scripts remain in this scratchpad or can be added as references/ next to each skill.

Recommended workflow for Claude Code:
1. Load relevant skill (or let the description trigger it).
2. Run doctor skill / `python3 scripts/doctor.py` before significant edits.
3. Keep slices ≤3 product/test files.
4. Single agent loop + skills on demand preferred over many subagents.
5. Production has priority on shared resources (camera).

Doctor-gate and render-thread-guard Mods are recommended next but not yet committed (TypeScript plugins require review).
