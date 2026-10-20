# Runde 2 — security-agent

Workflow `wf_29831ef4-24e`, Bereich `f61d7872d..6d168b44a` (Nacharbeit seit `9237c3c91`) mit den acht `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 0, Urteil der Linse: **CHANGES**. Gesamtentscheidung: **REWORK** (5 Majors). Außerhalb von `paths`: `docs/dev/APP_STORE_CONNECT.md`, `docs/dev/FOUNDER_INBOX.md`, `docs/dev/TODO_FOUNDER_2026-10-19.md` (Commit `532e5b169`, nicht sensibel); `judgeChanged`: `.claude/workflows/echoel-factory-review.js`.

## Zusammenfassung

Security lens, round 2, range f61d7872d..6d168b44a (the paths from board.json). 532e5b169 is an interleaved docs commit outside the paths: three docs/dev files, not sensitive, no secrets.

All six of my round-1 findings are fixed:
- The judge is now listed in JUDGE_FILES/JUDGE_DIRS. It escalates before APPROVE, and guard claims 8 and 9 read PROTECTED_DIRS and permissions.ask.
- SENSITIVE is wider.
- File names reported by lenses reach the approver only through ascii().
- A founder record now needs a date.
- A lens answer with no changedFiles list is RERUN.
- The approver checks the base recorded in board.json.

The majors from the other lenses are also fixed: --no-renames in both name lists, reviewedBy null stays open, and the run rule now respects the path filters.

Checks I ran:
- `python3 -I scripts/factory-review-selftest.py`: all cases match.
- `factory-board.py --selftest`: ok. Its selftest writes boards to a system temp dir and deletes them.
- I did not run --mutate, because it writes temporary copies.
- I drove the head and base workflows under inline `node -e` with stub agents and wrote no files.

The diff contains no secrets and no app, network or on-device data paths.

Two new majors, both rules loosened relative to the base workflow:
1. kindOf now takes [DEVICE] from the caller's deviceCriteria and ignores the independent approver. In the base workflow an approver answer of "criterion 2: code, unmet" gives REWORK. The head workflow APPROVEs the same answer when the PM passes deviceCriteria [2], and logs the override as "per the spec".
2. criteria and founderAssumptions come from the caller and are stated to the approver as facts about the spec. Grading past criteria is RERUN. If the count is low, an honest approver loops on RERUN, and one that follows the prompt leaves the extra criterion ungraded and the job ends in APPROVE. If founderAssumptions is omitted, the prompt says "No Assumption is tagged [FOUNDER]". The base workflow asked for every criterion in the spec.

So "counted, not believed" counts against a number the builder supplies and nothing checks against the spec.

Minors:
- The judge set leaves out CLAUDE.md and .claude/rules/. Every lens and the approver load them from the tree under review as instructions.
- .claude/settings.local.json is not in LOCK_CONFIG. It outranks settings.json and holds the GitHub token.
- The changedFiles matching breaks on git's quoted non-ASCII paths, and newlines in reported names reach the PM's result raw.

## Befunde

1. **major** `.claude/workflows/echoel-factory-review.js`:361 — A loosened rule compared with the base. In the base, kindOf (line 269 there) let the approver decide the kind: c.kind === 'device' or 'founder', otherwise code. The approver is the only agent that reads the spec in the approve phase. Now the kind is `deviceNumbers.includes(c.number) ? 'device' : …`, so the caller's deviceCriteria override the approver completely. The builder (the PM) can therefore make any criterion non-blocking, and no lens ever sees the deviceCriteria argument. Measured with stub agents, on the same approver answer ([1 code met, 2 code UNMET 'not done', 3 code met]): the base workflow returns REWORK '2 code criterion(s) unmet'. The head workflow with criteria 3 and deviceCriteria [2] returns APPROVE 'every code criterion met; 1 device request(s)' and logs 'criterion 2 labelled code, graded as device per the spec'. That log line is wrong: the number came from the caller, not from the spec. A stale deviceCriteria is enough to trigger this. When a rework inserts a criterion, the numbers shift, and this job itself went from 9 to 10 criteria in its rework. The selftest case 'a code label inside deviceCriteria is device' (scripts/factory-review-selftest.py:218) pins this fail-open as intended behaviour. SKILL.md:54 ('Welche Nummern [DEVICE] sind, sagt die SPEC') describes the caller's list as the spec.
   - Vorschlag: Grade a criterion as device only when BOTH sources say so: `const kindOf = (c) => c.number === 0 ? 'founder' : (deviceNumbers.includes(c.number) && c.kind === 'device') ? 'device' : 'code'`. This keeps the round-1 fix (an approver label alone cannot excuse a criterion) and closes the caller's channel. When the two disagree, grade the criterion as code and log the disagreement as such, not as 'per the spec'. Flip selftest case 218 to expect REWORK, and add a mutation row for the AND.
2. **major** `.claude/workflows/echoel-factory-review.js`:350 — The count that makes acceptance 'counted, not believed' is itself believed. criteria and founderAssumptions are caller arguments, and lines 309-311 state them to the approver as facts about the spec: 'The spec has ${criteria} numbered acceptance criteria', and 'No Assumption is tagged [FOUNDER].' whenever the key is omitted, which is its default (line 162). Line 350 then turns any number above criteria into RERUN. In the base (line 239 there) the approver graded 'EVERY acceptance criterion in the spec'. Measured: with a spec of 4 criteria and criteria 3 passed, an honest approver that grades criterion 4 as unmet gets RERUN ('4 duplicate or unknown'). An approver that follows the prompt and grades only 1..3 gets APPROVE, and criterion 4 is never graded. Nothing compares the arguments with the spec: lenses do not receive them, and the approver is not asked to check them. The job's Goal ('der Workflow zählt selbst, ob der Approver jedes Kriterium der Spec benotet hat') holds only while the builder's number is right.
   - Vorschlag: Add the spec facts as fields the approver reports from its own reading of the spec: specCriteria (integer), specDevice (array) and specFounder (integer), all in APPROVER_SCHEMA and required. Compare them with criteria, deviceCriteria and founderAssumptions, and return RERUN or ESCALATE on any mismatch, with a selftest case and a mutation row. Word the prompt as 'the PM reports N … if the spec says otherwise, ESCALATE' instead of asserting it, and never assert 'No Assumption is tagged [FOUNDER]' when the key was simply omitted.
3. **minor** `.claude/workflows/echoel-factory-review.js`:199 — The judge set (JUDGE_FILES/JUDGE_DIRS) names only this workflow and .claude/agents/. Every lens and the approver also receive CLAUDE.md and .claude/rules/*.md from the tree under review, plus any nested CLAUDE.md in a directory they read. These arrive as project instructions that 'OVERRIDE any default behavior', outside the data fence. This lens received exactly those files in its system context this round. A job that adds a grading rule to one of them, for example 'pipeline-only tooling is reviewed for style only', steers every lens and the approver. It cannot undo the deterministic checks (lock, judge, counting), but it can make met/unmet and the severity of findings softer, and isJudge never flags it.
   - Vorschlag: Either add `.claude/rules/` and the always-loaded `CLAUDE.md` to the judge set, or (cheaper) tell lenses and the approver: if the diff changes CLAUDE.md, a nested CLAUDE.md or .claude/rules/, read them with `git show ${a.base}:` and report any instruction they add about reviewing, grading or approving as major. State the remaining gap in SKILL.md step 4.
4. **minor** `.claude/workflows/echoel-factory-review.js`:196 — LOCK_CONFIG does not cover `.claude/settings.local.json`. That file is gitignored (.gitignore:132), but `git add -f` tracks it. Claude Code ranks it above `.claude/settings.json`, and it can add hooks or set disableAllHooks, so it defines the lock just as much. CLAUDE.md also says the GitHub token lives there, so a tracked copy leaks a secret. Neither lockChanged nor SENSITIVE would report it. Guard claim 8 checks only that the hook/ask paths are a subset of LOCK_CONFIG, so adding an entry stays green.
   - Vorschlag: Add '.claude/settings.local.json' to LOCK_CONFIG (and to SENSITIVE for the secret), and add one selftest case.
5. **minor** `.claude/workflows/echoel-factory-review.js`:250 — changedFiles entries are only trimmed. core.quotePath is unset in this repo, so git uses its default and prints non-ASCII paths quoted with octal escapes, e.g. `"reports/Generative Intelligenz f\303\274r Echoelmusic.md"` (seen in this repo's history). A lens that copies the output verbatim reports `".claude/agents/…"` or `".claude/hooks/…"`, and isJudge/isLockConfig miss it because startsWith fails at the quote. Separately, names that contain newlines or control characters reach `reason`, `outsideScope` and `sensitiveOutside` unescaped. Several SENSITIVE patterns are anchored at only one end, e.g. /\.entitlements$/ and /^\.github\/workflows\//, so arbitrary text survives into the result the PM copies into board.json scopeOpen and reviews/. The impact is low: a new hook needs a settings.json change to run, and that escalates.
   - Vorschlag: Ask for `git -c core.quotePath=false diff --name-only --no-renames` (or -z), strip one pair of surrounding quotes before matching, and treat an entry with a control character as a lens miscount (RERUN naming the lens), with a selftest case.
