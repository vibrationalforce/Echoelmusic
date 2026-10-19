# Runde 1 — ux

Range `b1cfc8ad1..9c0677f03` · Workflow `wf_53b5c83e-663` · gesagt: CHANGES

## Zusammenfassung

I reviewed this diff through the UX and claims lens. It touches no app UI, store text or website, so VoiceOver, Dynamic Type, contrast, reduce motion, flash rate and the Uncodixfy rules do not apply here. No health, wellness or esoteric wording appears; health wording shows up only as a reason to escalate. The readers of these files are future sessions and the founder, and several sentences in the skill are not true for this build. (1) The skill says a slice can be APPROVED while its device criteria go to the founder's inbox. The workflow cannot do that: any unmet criterion becomes REWORK with nothing to fix, and in round 3 it becomes ESCALATE. That hits every user-facing slice. (2) The skill and the spec say the code, security and ux lenses are always on, but the workflow does not add them. A caller can drop the claims lens without anyone seeing it. (3) The skill sends readers to memory/inspiration_intake.md for the verdict, and at 9c0677f03 that file has no factory entry. Smaller wording problems: "erzwingt ESCALATE", "fünf Agentenläufe je Runde", which inbox section an escalation goes to, "Quelle nicht geöffnet", and the F-08b and gate citation, which is wrong for EchoelStudio/ slices.

## Befunde

### 1. major — `.claude/workflows/echoel-factory-review.js`:200

The skill's APPROVE branch (SKILL.md:69-70) says device criteria go to docs/dev/FOUNDER_INBOX.md §2 as a request, not as done. That implies a slice with [DEVICE] criteria can still be APPROVED. The workflow makes this impossible. The approver prompt (line 187) says a device, ear or eye criterion 'is NOT met by code', so it gets met:false. Line 198 collects it as unmet, and line 200 turns any unmet criterion into REWORK in rounds 1-2 and ESCALATE in round 3. The REWORK result carries findings: [] (line 202), so the PM gets a rework order with nothing to fix in code. Every user-facing slice carries a [DEVICE] criterion (CLAUDE.md: a UI or render change is not proven until a device run). So exactly the slices this lens exists for burn two pointless rework rounds and then always escalate. This job's own AC8 ('[DEVICE] entfällt') could trigger the same path.

**Vorschlag:** Pick one truth and write it in both files. Either filter criteria whose text starts with [DEVICE] out of `unmet` (or give the approver schema a `device: true` flag) and let APPROVE carry them in forTheHuman for Inbox §2, or change SKILL.md:69-70 to say that a [DEVICE] criterion always ends in ESCALATE. In either case, never return REWORK when `open` is empty and every unmet criterion is device-only.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 2. major — `.claude/workflows/echoel-factory-review.js`:128

SKILL.md:53 says 'Linsen: immer code-reviewer, security-agent, ux', and spec Assumption 5 says 'Drei Linsen sind immer an'. The workflow uses the caller's list as given: `requested = a.lenses.length ? a.lenses : ALWAYS`, and ALWAYS is never added to it. A call with lenses ['ui-state-reviewer'] runs one lens. The ux/claims lens and the security lens are skipped without any message, and the approver is told 'All lenses passed.' (line 184). A user-facing slice can therefore be approved with no claims review at all, while the skill tells its reader this cannot happen.

**Vorschlag:** Use `const lenses = [...new Set([...ALWAYS, ...(a.lenses || [])])]` so the three always-on lenses are always added, and keep the MAX_LENSES check, which then allows at most one domain lens, as the skill says. Or report a missing always-on lens as INVALID.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 3. major — `.claude/skills/factory/SKILL.md`:20

The Herkunft paragraph says 'Verdikt und Messung: `memory/inspiration_intake.md` unter 2026-10-19.' At 9c0677f03 the file has three 2026-10-19 entries (lines 1601, 1609, 1624), and none is about the factory reel. `git show 9c0677f03:memory/inspiration_intake.md | grep -ci 'factory\|zazencodes'` returns 0. The verdict row exists only as an uncommitted line in inspiration.csv (row 306 in the working tree), which is a different file. The claims in this paragraph ('als Werbung gekennzeichnet', 'Die Quelle wurde NICHT geöffnet') rest on a log that does not exist at head. The pointer leads to unrelated entries.

**Vorschlag:** In the same commit, add the Lernmodus entry to memory/inspiration_intake.md under 2026-10-19 (and commit the inspiration.csv row). Or point the sentence at the record that actually exists.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 4. minor — `.claude/skills/factory/SKILL.md`:28

The table says APPROVE means the normal path 'Commit, Push, beide Gates, auto-merge-claude.yml' and cites F-08b as proof that the path to main 'ist schon geregelt'. F-08b (docs/dev/TODO_FOUNDER_2026-10-19.md:29, ECHOEL_VISION_2026-10-19.md:132) says the opposite for the current product: EchoelStudio/ commits are in no auto-merge filter (auto-merge-claude.yml:48-53 lists only Sources, Tests, Package.swift, project.yml and workflows), and the merge belongs to the founder. 'Beide Gates' (Xcode Compile Check, CI/CD) also do not run on EchoelStudio/ paths. The gate there is `Echoel Studio` (studio.yml). For a Studio slice the sentence is false.

**Vorschlag:** Name the gate for each tree: legacy app = Xcode Compile Check plus the Build for Testing step; EchoelStudio/ = Echoel Studio. Say that merging EchoelStudio/ to main is the founder's per F-08b, and stop citing F-08b as evidence that the path is already settled.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 5. minor — `.claude/skills/factory/SKILL.md`:43

The skill says 'Eine `[FOUNDER]`-Annahme erzwingt ESCALATE.' Nothing enforces this. The approver prompt (workflow lines 189-192) lists the founder-class categories but never mentions the [FOUNDER] tag, and line 199 accepts the approver's own decision. A spec writer who tags health wording [FOUNDER] trusts a guarantee the code does not give.

**Vorschlag:** Add 'any Assumption tagged [FOUNDER]' to the ESCALATE-when list in the approver prompt, or soften 'erzwingt' to 'soll … auslösen (Approver-Urteil)'.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 6. minor — `.claude/skills/factory/SKILL.md`:90

'Die Factory kostet fünf Agentenläufe je Runde' overstates the cost. A REWORK round returns at workflow line 174, before the approver runs, so it costs only the lenses (at most 4). The approver runs only in the final round.

**Vorschlag:** Write 'bis zu fünf Agentenläufe je Runde (vier Linsen; der Approver nur in der letzten)'.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 7. minor — `.claude/skills/factory/SKILL.md`:72

ESCALATE writes 'die Inbox-Zeile', and the board example uses 'inbox: F23'. FOUNDER_INBOX F-numbers are §3 'Founder-gated Befunde — berichten, nicht editieren' (lines 250-282). Scope and product decisions sit in §1 under other IDs (for example GM16). A first-time reader does not know which section an escalation belongs in, and the example points at the locked-file section.

**Vorschlag:** Name the section: §1 for decisions and scope, §3 only for founder-locked files, §2 for device requests.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 8. minor — `.claude/skills/factory/SKILL.md`:19

'Die Quelle wurde NICHT geöffnet' contradicts the intake row, which records that the founder uploaded the reel (47.2 s, 480x1042) and that it was analysed. Only the end-card URL was not opened. The same wording appears in spec.md Assumption 6.

**Vorschlag:** Write 'das Reel lag als Founder-Upload vor; die Endkarten-URL und der Quelltext wurden nicht geöffnet'.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 9. minor — `scripts/INDEX.md`:58

The row says the board prints one column per stage '(Spec · Build · Review · Approve · Needs human · Done)'. factory-board.py:20/49 also prints DROPPED. The script's docstring (line 13) says exit 1 covers unreadable boards and unknown stages, but it also returns 1 for an id/folder mismatch and a non-object board (lines 33-42).

**Vorschlag:** Add 'Dropped' to the column list, and list the id-mismatch and non-object cases in the exit-code line.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

