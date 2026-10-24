# scratchpads/ — live plans & logs

Session-specific plans, specs, audits and the session log. **Read `SESSION_LOG.md` first**
(its END — `grep -n '^## ' scratchpads/SESSION_LOG.md | tail -20` + `tail -200`), then the
DEAD-ENDS table of `HARNESS_LEDGER.md`.

## What lives here — measure, do not recite

| Question | Command |
|---|---|
| live documents | `git ls-files 'scratchpads/*.md' 'scratchpads/*.txt' 'scratchpads/*.json' \| wc -l` |
| archived documents | `git ls-files 'scratchpads/archive/*' \| wc -l` |
| which plans CLAUDE.md still cites | `git grep -o 'scratchpads/[A-Za-z0-9_./-]*' CLAUDE.md \| sort -u` |

⛔ A table of "live" file names stood here from the 2026-07 cleanup and was stale three ways by
2026-10-24 (two listed files moved, two did not exist, and "37 archived" against 67 on disk).
A list of names in a README is a date, not a fact; the commands above are the fact.

## Always live (never archive)

`SESSION_LOG.md` · `HARNESS_LEDGER.md` · `BAUSTELLEN_BOARD.md` · `FOUNDER_DEVICE_SESSION.md` ·
`EXECUTION_CHECKPOINT.md` · any `PLAN_*` named by CLAUDE.md or by an `in_progress` task ·
`factory/` (job state) · `tools/` (pipeline scripts) · `inspiration/` (intake notes).

## Archive (`archive/`)

Superseded material, moved with `git mv` so history stays. `archive/README.md` carries the rules
and each dated batch with the reason per file. Nothing is deleted; bring a file back instead of
rewriting it.
