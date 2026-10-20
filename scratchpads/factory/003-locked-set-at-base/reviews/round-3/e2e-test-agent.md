# Runde 3 — e2e-test-agent

Workflow `wf_c8778d4d-f9a`, Bereich `f61d7872d..61d2d1e37` (Nacharbeit seit `6d168b44a`) mit den acht `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 0. Gesamtentscheidung: **ESCALATE** — rework cap of 2 reached with 3 open finding(s). `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Außerhalb von `paths`: die drei `docs/dev`-Dateien aus `532e5b169`, nicht sensibel. Urteil der Linse: **CHANGES**.

## Zusammenfassung

Ship-path lens, round 3. The whole job is f61d7872d..61d2d1e37 and the rework since round 2 is 6d168b44a..61d2d1e37. Commit 532e5b169 is not part of the job. It changes docs/dev/APP_STORE_CONNECT.md, FOUNDER_INBOX.md and TODO_FOUNDER_2026-10-19.md, which lie outside the job's paths and are not sensitive. The job touches no app target, entitlement, Info.plist, privacy manifest or project.yml. It touches no lock-config file, nothing under .claude/agents/, no CLAUDE.md and nothing under .claude/rules/. Only the judge changed: .claude/workflows/echoel-factory-review.js.

My three round-2 findings are all fixed:
- Major (the run rule): SKILL.md:178-185 now also requires the diff over the files a guard reads to be empty. The guard file is in this commit, so the gates started on the final tree.
- Minor: fastlane/Fastfile and Appfile are in SENSITIVE.
- Minor: claim 7 now pins the board.json sentence. Its needle is absent at f61d7872d and 9237c3c91 and present at 6d168b44a and 61d2d1e37, as the guard header says.

Local checks at the head (working tree = 61d2d1e37):
- factory-review-selftest.py: exit 0, --mutate 76/76.
- factory-board.py --selftest: exit 0, --mutate 16/16.
- Guard claims 1-9, transcribed in Python: all green. For claim 8, the hook's PROTECTED_FILES are .claude/settings.json and .mcp.json, PROTECTED_DIRS is empty, and the three permissions.ask Edit(/...) entries are all readable, so the new unreadable-rule failure cannot fire on this tree.

Gate state:
- Head 61d2d1e37: Xcode Compile Check run 39348756755 and CI/CD run 39348756773 were both still running when I checked (Build for Testing in progress). Whether the new Swift compiles and whether the guard passes is not yet observed.
- Previous round, 6d168b44a, CI/CD run 39345875384: Build for Testing succeeded and Run Tests failed, which is the expected #396 failure. gh-test-verdict.py reports 0 failures and 161 tests passing in the window, plus a 1541 s gap. The guard does not appear in the window, so its execution is unobserved (#445).
- No gate runs the selftests or the board tool.

I compared the edited judge rule by rule against f61d7872d. Most changes are stricter:
- kindOf now needs both the PM's list and the approver's label.
- A founder entry needs a dated record.
- A numbered criterion labelled 'founder' and left unmet escalates again, as it did at the base.

One rule is loosened. The new spec-count RERUN runs before the decision ladder. With a PM-supplied count that differs from the spec, it turns the deterministic cap ESCALATE and the lock-config ESCALATE into a RERUN. I reproduced this with stub agents.

Two minors: the SKILL example of which files a guard reads is incomplete, and SENSITIVE misses fastlane/Deliverfile.

## Befunde

1. **major** `.claude/workflows/echoel-factory-review.js`:375 — This rule is loosened compared with the base. At f61d7872d:279-281, once the approver returned acceptance entries, an open finding in round 3 (capReached) always led to ESCALATE, and no caller argument could get in front of it. At the head, the new spec-count comparison (lines 369-376) returns RERUN BEFORE the decision ladder. The cap rule (line 417) and the lock-config rule (line 420) never run when the PM's count differs from the approver's. The PM controls criteria, deviceCriteria and founderAssumptions. SKILL.md:139-146 calls these two ESCALATEs the strongest rules and says the lock one applies 'ohne Ermessen des Approvers und vor jeder Nacharbeit'. I measured this with stub agents, using the harness of factory-review-selftest.py. In round 3 with one lens reporting a major: PM criteria 2 against a spec count of 1 gives RERUN 'spec count: criteria: PM 2, approver 1'; with the matching count it gives ESCALATE 'rework cap of 2 reached'. With .claude/settings.json in changedFiles in round 1, the same mismatch gives RERUN instead of ESCALATE 'the change edits the lock configuration'. On a RERUN, SKILL.md:84-85 tells the PM to recount and call the same round again, and nothing pins head across that call. A capped round 3 can therefore be called again on a new commit after the findings are fixed. That is the third rework SKILL.md:134-136 forbids ('Eine dritte Nacharbeit gibt es nicht'). The graded-set RERUN at lines 390-395 sits in the same position. Every mismatch case in the selftest (factory-review-selftest.py:233-241) uses round 1 with no lock change, so no case and no mutation sees the ordering.
   - Vorschlag: Decide capReached and lockChanged before the count checks. If either holds, return ESCALATE and carry the disagreement in reason or missing; RERUN on a mismatch only when no escalation is already fixed. Add two selftest cases: round 3 with an open major and a count mismatch must give ESCALATE, and a lock-config change with a count mismatch must give ESCALATE. Add a mutation row that moves the disagree block back in front of the ladder. In SKILL.md, state that a RERUN calls the same round again with the same head.
2. **minor** `.claude/skills/factory/SKILL.md`:182 — The new guard rule says which files a guard reads are named by its read calls, and gives 'in TheFactoryReviewersAreReadOnlyTests die text(...)-Stellen' as the example. The example is incomplete. The guard reads .claude/settings.json through Data(contentsOf:) (TheFactoryReviewersAreReadOnlyTests.swift:234-235), and it checks docs/dev/FOUNDER_INBOX.md through FileManager.fileExists (lines 310-311). Neither is a text() call. A PM who follows the example literally leaves both out of the diff that decides whether an earlier run still counts. The impact is small, because a settings.json change escalates anyway.
   - Vorschlag: Name every kind of read call: text(...), the Data(contentsOf:) read of .claude/settings.json and the fileExists check of FOUNDER_INBOX.md. Or list the guard's read set once, in its header, and point to it from here.
3. **minor** `.claude/workflows/echoel-factory-review.js`:221 — The SENSITIVE comment (lines 215-217) says the list covers the store and ship surfaces, including the signing lanes. The rework added fastlane/Fastfile and Appfile but left out fastlane/Deliverfile. Deliverfile is the deliver configuration for App Store submission: it sets submit_for_review false, automatic_release false and skip_screenshots true (fastlane/Deliverfile:70-77). Its own header (#633) warns that a direct `fastlane deliver` reads it with no lane in between. An interleaved commit outside the job's paths that flips one of these produces no sensitiveOutside and no scopeOpen row. App Store submission is on the approver's list of founder-owned decisions.
   - Vorschlag: Change the rule to /^fastlane\/(Fastfile|Appfile|Deliverfile)$/ and add an OUTSIDE entry for it in the selftest.
