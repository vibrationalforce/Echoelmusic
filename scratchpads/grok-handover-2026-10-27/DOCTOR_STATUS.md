# Doctor Status – 2026-10-27

`scripts/doctor.py` (2326 Zeilen) ist der deterministische Read-only-Auditor der Messinstrumente (Gates, Tooling, Surfaces, Docs, Ratchets, Isolation).

- Exit 0 nur ohne CRITICAL Findings.
- LIMITS klar: Reachability name-based, keine Kompilierung, Sound/Device außerhalb.
- Bekannter Fehlalarm in Section A bei gültigem `set -eo pipefail` (Studio Build) – daraus keinen Studio-Fehler ableiten.
- **Empfehlung:** Vor jeder Claude-Integration ausführen (`python3 scripts/doctor.py` oder `--section C`).

Findings sind immer file:line + Evidence. Green Doctor heißt „Instrumente sehen ehrlich aus“, nicht „Code funktioniert“.
