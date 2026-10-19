# Runde 1 — code-reviewer

Range `b1cfc8ad1..9c0677f03` · Workflow `wf_53b5c83e-663` · gesagt: CHANGES

## Zusammenfassung

Code lens, round 1. What the guard needs holds up. I re-ran claims 1–4 of TheFactoryReviewersAreReadOnlyTests in Python against 9c0677f03: two agent calls and both go through withReadOnly; READ_ONLY matches the §5 clause of context.md after whitespace normalisation; all nine agentType values are on the ultracode roster; MAX_REWORK_ROUNDS is 2 in both the workflow and the skill. `factory-board.py --open` runs read-only and exits 0. I did not run its `--selftest`, because it creates a temp directory. I did run the workflow body in memory: export stripped, wrapped in an AsyncFunction, with stubbed agent/parallel/phase/log hooks. That run showed three logic defects that break what the spec promises. (1) Line 200 turns an unmet criterion into REWORK in rounds 1–2. It even overrides an approver ESCALATE. A [DEVICE] criterion, which the spec says is never met, therefore forces two rework rounds with zero open findings, and a [FOUNDER] escalation gets downgraded. (2) Lines 124/126/128 replace arguments that are present but malformed with defaults. round:"3" becomes round 1 and resets the rework cap; this goes against AC1. (3) Line 128 never enforces the three always-on lenses. lenses:['dsp-reviewer'] runs one lens and can reach APPROVE. Minor findings: prototype keys pass the lens check; an empty acceptance array still gets APPROVE; the guard does not pin the body of withReadOnly; the job's board.json has an empty head; the ref regex is loose. The Swift guard itself is sound and has no isolation or force-unwrap problems.

## Befunde

### 1. major — `.claude/workflows/echoel-factory-review.js`:200

`if (capReached || unmet.length) decision = (!capReached && round <= MAX_REWORK_ROUNDS) ? 'REWORK' : 'ESCALATE'` turns ANY unmet criterion into REWORK in rounds 1 and 2, including when the approver said ESCALATE. Two consequences, both reproduced with stubbed hooks. (a) The approver prompt (line 187) and the skill (line 45) say a [DEVICE] criterion is never met by code. Any spec with such a criterion therefore returns REWORK with `findings: []`: there is nothing for the PM to fix, yet it burns rounds 1 and 2 (about 10 agent runs) before round 3 escalates. The APPROVE path the skill describes for device criteria (line 69, 'Geräte-Kriterien gehen als Bitte in FOUNDER_INBOX §2') can never be reached. (b) An approver ESCALATE for a founder-class reason (skill line 43: 'Eine [FOUNDER]-Annahme erzwingt ESCALATE') is downgraded to REWORK whenever any criterion is also unmet. Stub results: device-unmet in round 1 gave REWORK with nextRound 2; ESCALATE plus one unmet criterion gave REWORK. The approver prompt (line 189, 'ESCALATE when … a criterion is unmet') and the code also disagree about what an unmet criterion means.

**Vorschlag:** Never downgrade an approver ESCALATE. Add a per-criterion classification to APPROVER_SCHEMA (e.g. `kind: 'code'|'device'|'founder'`). Only unmet `code` criteria may trigger REWORK in rounds ≤ MAX_REWORK_ROUNDS. Unmet `device` criteria go to forTheHuman and must not block APPROVE, or they escalate directly. Make line 189 of the prompt match whichever rule you choose.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 2. major — `.claude/workflows/echoel-factory-review.js`:126

Arguments that are present but malformed get defaults instead of INVALID, which contradicts AC1 ('lehnt fehlerhafte Argumente mit decision: INVALID ab, statt zu raten'). `Number.isInteger(a.round) ? a.round : 1` turns round:"3", 2.5 or null into 1. Line 124 does the same for head (a non-string becomes 'HEAD'), and line 128 for lenses (a string or object becomes ALWAYS). The round argument is the cap's only input, so a stringified round resets the cap. Reproduced: {round:"3"} with an open major finding returned REWORK with nextRound 2, where ESCALATE was due. The cap from AC4/AC5 can therefore be bypassed without any warning.

**Vorschlag:** Default only when the key is absent: `const round = a.round === undefined ? 1 : a.round`, then `if (!Number.isInteger(round) || round < 1 || round > MAX_REWORK_ROUNDS + 1) problems.push(...)`. Do the same for head (`a.head === undefined ? 'HEAD' : a.head`, must be a string) and for lenses (undefined becomes ALWAYS; anything else must be a non-empty array of strings, or INVALID).

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 3. major — `.claude/workflows/echoel-factory-review.js`:128

ALWAYS is only a fallback, not a floor. The spec Assumption says 'Drei Linsen sind immer an (Code, Security, UX/Claims), eine vierte nach Pfad', and the skill (line 53) says 'immer code-reviewer, security-agent, ux; dazu höchstens EINE Domänen-Linse'. A PM who follows that wording passes only the domain lens, and the code then drops all three always-on lenses. Reproduced: lenses:['dsp-reviewer'] spawned one reviewer plus the approver and returned APPROVE, with no code, security or claims review. The 'at most ONE domain lens' rule is not enforced either: four domain lenses are accepted.

**Vorschlag:** `const lenses = [...new Set([...ALWAYS, ...requested])]` and reject more than one lens outside ALWAYS with INVALID. Alternatively, rename the argument to `domainLens` so the caller cannot drop the always-on three.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 4. minor — `.claude/workflows/echoel-factory-review.js`:130

`lenses.filter(l => !LENSES[l])` treats inherited Object.prototype keys as known lenses. Reproduced: lenses:['constructor'] passes validation and spawns an agent with `agentType: undefined` and charter `undefined`. 'toString', '__proto__' and 'hasOwnProperty' behave the same way. Non-string entries are not rejected explicitly either.

**Vorschlag:** `lenses.filter(l => typeof l !== 'string' || !Object.hasOwn(LENSES, l))`.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 5. minor — `.claude/workflows/echoel-factory-review.js`:198

An approver that returns `acceptance: []` gets APPROVE with zero criteria checked (reproduced). APPROVER_SCHEMA line 90 has no minItems. This contradicts the workflow's own rule that a missing review is not a pass, and the prompt's 'For EVERY acceptance criterion'.

**Vorschlag:** Add `minItems: 1` to `acceptance`, and treat an empty acceptance list as RERUN (missing: ['approver']).

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 6. minor — `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift`:82

Claim 1 checks that the text `agent(withReadOnly(` wraps every call, and claim 2 pins the READ_ONLY constant. Nothing pins that `withReadOnly` (workflow line 20) actually prepends READ_ONLY. Rewriting it as `(text) => text` would leave all five claims green while no prompt carries the §5 clause.

**Vorschlag:** Also assert that the comment-stripped workflow contains `const withReadOnly = (text) => `${READ_ONLY}` (or check that the body references READ_ONLY).

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 7. minor — `scratchpads/factory/001-factory-loop/board.json`:2

stage is 'review' but head is "". The skill (line 50) says the head SHA goes into board.json at build time. Passing the board's head to the workflow verbatim returns INVALID ('head must be a git ref or sha', reproduced with head:""). A commit cannot contain its own SHA, so the skill's instruction cannot be followed within the build commit.

**Vorschlag:** In the skill, say that head is recorded after the build commit, or that it is omitted (the workflow then defaults to HEAD). Do not leave an empty string in board.json.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 8. minor — `.claude/workflows/echoel-factory-review.js`:120

REF accepts values that are not valid refs: a leading '-' (an option-shaped value such as `-p`) and an embedded '..' (base 'a..b' becomes the range 'a..b..HEAD'). Both reach the agent prompt as a git command line.

**Vorschlag:** Use `/^(?!-)(?!.*\.\.)[A-Za-z0-9._\/~^-]{1,80}$/`.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

