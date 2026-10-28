---
name: format-v3-migration
description: Explicit Format 3 migration for ModRoutes, empty array from v1/v2, golden preservation and offline freeze rules. Use before any song-document change that adds modulation storage.
---

# Format v3 Migration

## Rules
- Bump format version. On open of earlier formats add empty modRoutes array (or documented default).
- Never edit existing golden files. Add new golden for v3.
- Unknown sources/targets and invalid routes are rejected, not silently remapped or dropped.
- Routes store IDs and meaning, not render-slot indices.
- Failed mutation leaves last valid document.
- Offline export: live camera/BLE never produce a second random render. Explicit freeze or recorded tracks.

See also scratchpads/FORMAT_V3_MIGRATION_SKETCH_2026-10-26.md and G-A contract.
