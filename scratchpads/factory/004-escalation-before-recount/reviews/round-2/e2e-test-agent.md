# Runde 2 — e2e-test-agent

Workflow `wf_b6b634a9-2c3` — Prüfer-Fassung von der Job-Basis (`73e9ae52d`), Bereich `73e9ae52d..aeb77953d` (Nacharbeit seit `dcae95345`) mit den sechs `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **REWORK** — 3 offene Befunde, Nacharbeit 2 von 2; der Approver lief nicht. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Außerhalb von `paths`: `scratchpads/factory/001-factory-loop/reviews/round-3/security-agent.md` (`108fa2da7`), nicht sensibel. Urteil der Linse: **CHANGES**.

## Zusammenfassung

Round 2 ship-path review of job 004, range 73e9ae52d..aeb77953d. Of the 13 changed files, 108fa2da7 lies outside paths and is not sensitive.

Round-1 findings: all seven of my round-1 minors are fixed at the head.
1. Claim 10 is now graded needle by needle, and each needle runs before the early return.
2. Both RERUN spellings are scanned (`decision\s*[:=]\s*'RERUN'`).
3. SKILL.md now says recount escalates only a count note.
4. The spec's Pluginfile reason is corrected.
5. `.github/actions/` and the Gemfile are now in SENSITIVE.
6. The raw-printing comment is corrected.
7. An early ESCALATE now carries deviceAsks, founderOpen and unmet.

I also checked the other lenses' round-1 majors in code. The cap and the lock now each add a part to `fixedParts` and keep the token note. The lock check is computed before the name RERUN, and a disguised name escalates. The token check uses `--full-history`. The read list names `Data(contentsOf:)`.

Rule comparison against `git show 73e9ae52d:.claude/workflows/echoel-factory-review.js`: no rule is removed or loosened.
- A C0 name with a lock change now becomes ESCALATE instead of RERUN.
- A Cc/Cf/Zl/Zp name that the base let through to APPROVE now becomes RERUN or ESCALATE.
- The REWORK exit also skips on a disguised name.

What I ran (no file written):
- `python3 -I scripts/factory-review-selftest.py`: exit 0, all cases match.
- Every row of MUTATIONS, run in memory through stdin: 108 of 108 caught, none stale.
- Guard claim 10 transcribed in Python. At 73e9ae52d it is red: the kindOf, cap, lock, join and escalation needles are absent, the order anchor is missing, and metCode is green as the counterweight. At dcae95345 the three fixedParts needles are red. At aeb77953d all six needles are green, with 2 RERUNs after `if (escalation) {` and 0 before it.
- `doctor.py --section B`: 0 critical.
- `factory-board.py --open` parses.
- Token check: `git log --full-history` over the range = 0, and `rev-list --objects | grep settings.local.json` = 0.
- No tracked name contains a Cc, Cf, Zl or Zp character.
- I did not run the board `--selftest`, because it writes temp files and the script did not change.

Gates on aeb77953d:
- Xcode Compile Check: success. It compiles Sources/ only and proves nothing about the guard file.
- CI/CD `Build for Testing`: success, so the edited guard compiles.
- `Run Tests`: still in progress, so claim 10 has been transcribed but not seen running.
- Full Test Suite (non-blocking): proves nothing (#208).
- No gate runs the JS workflow.
- Context: on dcae95345 the gates passed, but the auto-merge step "Merge to main" failed.
- No target, entitlements file, Info.plist or project.yml is touched.

New findings: one major (the approver's count is not blind) and one minor (the `.github/actions/` reason is false).

## Befunde

1. **major** `.claude/workflows/echoel-factory-review.js`:391 — The approver's count of the spec is not blind, although the job claims it is. SKILL.md:92 says 'BLIND, sein Prompt nennt keine Zahl des PM', and the spec's Assumption says the approver 'bekommt die Zahlen des PM nicht zu sehen ... kein Echo'. AC4 is met to the letter, since the prompt text names no number. But the same prompt sends the approver to the PM's numbers in two ways. (1) Line 391 tells it to open `git show ${head}:${jobDir}/board.json`, and that file holds all three numbers: board.json:21-23 reads `"criteria": 10, "deviceCriteria": [], "founderAssumptions": 1`. SKILL.md:271-272 requires them there. (2) Line 353 tells it to read the whole-job diff, and the job folder is in `paths`. From round 2 on, that diff contains every reviews/round-<n>/*.md protocol, and SKILL.md:269-270 requires each one to carry `criteria`, `deviceCriteria` and `founderAssumptions`. Example: reviews/round-1/code-reviewer.md:3 contains '`criteria` 10, `deviceCriteria` [], `founderAssumptions` 1'. Lens summaries reach the fenced block and can quote the numbers too. Failure: the PM undercounts. It passes and records criteria 9 for a 10-criterion spec. The approver checks board.json for the base, sees 9, copies it into specCriteria and grades 1..9. Then disagree is empty, ungraded is empty, criterion 10 is never graded, and the round can APPROVE. That is the job-003 round-2 failure the second reading was meant to catch. No selftest case covers it: the 'PM numbers shown to the approver' case checks only the prompt string.
   - Vorschlag: Make the claim true or make it honest. Either tell the approver to count the spec at the head BEFORE it opens board.json or anything under reviews/, and never to take a count from board.json, the protocols or the reviews. Narrow line 391 to the `base` field, for example `git show ${head}:${jobDir}/board.json` and compare only `"base"`. Add a selftest prompt case that pins the count-first instruction. Or correct SKILL.md:92 and the spec Assumption: the prompt names no number, but board.json and the protocols do, so the count is a second reading only as far as the approver counts first.
2. **minor** `.claude/skills/factory/SKILL.md`:255 — The reason given for making `.github/actions/` sensitive is false. SKILL.md:255 says '(die Signier-Jobs laden dort den App-Store-Connect-Schlüssel)', and spec.md:28 says the same, naming `setup-asc-api-key`. That action is used by no workflow: `git grep -n setup-asc-api-key -- .github/workflows` returns 0, and only .github/actions/README.md mentions it. Both signing jobs write the key inline: testflight.yml:366-368 and studio-testflight.yml:86-88. The pattern itself is right for another reason: the composite action `setup-xcodegen` runs inside both signing jobs (testflight.yml:341 and studio-testflight.yml:69, before the key is written in the same job) and in every gate (ci.yml, full-tests.yml, pr-check.yml). This is the same class as my round-1 Pluginfile minor: correct code, wrong ship-path reason.
   - Vorschlag: Change the reason in SKILL.md:255 and spec.md:28 to: 'setup-xcodegen runs in both signing jobs, in the same job as the App Store Connect key, and in every gate; setup-asc-api-key is unused today'. No code change is needed.
