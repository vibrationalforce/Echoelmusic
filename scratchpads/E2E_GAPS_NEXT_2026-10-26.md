# Next End-to-End Gaps — 26 October 2026

Autonomous continuation. When one plan is done, search the next.

## 1. Spatial / ADM-OSC Caller Gap
ADM-OSC sender and some render cores exist in the old app. Full production caller in Studio is missing or partial. 

**Next action (docs/plan):** Map exact files in EchoelStudio that already reference spatial or ADM-OSC. Plan the smallest slice that connects a BodyFrame or song position to one ADM-OSC object output, gated by BioEgressPolicy and the Connections module (W4).

## 2. One Session / One Clock Enforcement
WA2 decided DMMWProject is the canonical Session. PatternEngine is the musical clock. 

**Next action:** Audit for any remaining second transport or tempo writers outside PatternEngine.setTempo. Document them as a future small cleanup slice. Do not change code now.

## 3. AI Door
Describe path and intents exist. Model planner has no production door. 

**Next action:** Plan a single explicit user-triggered door (button or menu) that calls the existing planner with selection-only, question-instead-of-guess rules. Offline only. Never in render.

## Priority Order Remains
1. W1 BodyFrame display (plan done).
2. Merge Docs PRs.
3. W2 Modulation.
4. These gaps as subsequent plans.
5. Network jitter as W4+.

No rules changed. All pure documentation. Claude can pick any of these plans on resume.

*Exhaustive search mode active.*