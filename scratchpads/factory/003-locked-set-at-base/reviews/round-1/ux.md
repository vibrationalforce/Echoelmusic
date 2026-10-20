# Runde 1 — ux

Workflow `wf_b852534d-658`, Bereich `f61d7872d..9237c3c91` mit den acht `paths` aus `board.json`, `criteria` 9, `deviceCriteria` [], Urteil der Linse: **PASS**. Gesamtentscheidung: **REWORK** (vier Majors).

## Zusammenfassung

UX/claims lens, round 1. There are no earlier reviews (scratchpads/factory/003-locked-set-at-base/reviews/ does not exist). The diff is pipeline-only tooling: no app UI, no Sources/ copy, no website or store text. So VoiceOver, Dynamic Type, contrast, 3 Hz flashes, Uncodixfy and EchoelValueField do not apply. I found no health, wellness or esoteric wording; "Gesundheit" appears only as a category label for sensitive files.

I checked each claim the diff adds to SKILL.md and INDEX.md against the real source, and these hold:
- The gate path filters in the "Kein Lauf" list match xcode-compile-check.yml:12-20, ci.yml:14-24 and studio.yml.
- The `docs_only=false` sentence matches auto-merge-docs.yml:70-97, which diffs file by file against origin/main.
- The `sha7` column exists in gh-run-status.py:9.
- The UX lens charter does check outward claims, as the new "Wann nicht" sentence says.
- The decision ladder, the counting rule, kind-from-spec and the founder record regex in SKILL.md match the workflow code.
- The INDEX.md descriptions match factory-board.py.

I ran three checks: `factory-board.py --selftest` passes (6 jobs loaded, 8 malformed boards reported), `factory-review-selftest.py` prints "all cases match", and `doctor.py --section B` reports 0 critical findings.

There are three minor findings, none blocking:
1. The SENSITIVE regex misses several live privacy and legal surfaces that the SKILL.md category list says are covered.
2. `reviewedBy` closes a sensitive legal or health file with any non-blank word, while `verified` on a device check needs a date.
3. The new exemption for "internal" files takes in docs/dev/FEATURE_STATUS.md, one of the two claims registers. The other register, ContentPipeline/, is routed through the factory.

## Befunde

1. **minor** `.claude/workflows/echoel-factory-review.js`:191 — SKILL.md:159-161 says sensitive files outside the scope (Rechtstext, Datenschutz, Gesundheit, Privacy-Manifeste, Store-Text) are not covered by an approval and go to scopeOpen. The SENSITIVE regex `^docs/(privacy|terms|health|impressum|security|claims)\.html$` misses live outward surfaces of those same categories. (1) docs/privacy/index.html and docs/terms/index.html are the redirect stubs behind the App Store privacy URL (fastlane/metadata/*/privacy_url.txt = https://echoelmusic.com/privacy). (2) docs/_redirects maps /datenschutz, /agb and /gesundheit to the legal and health pages. (3) docs/_headers:12 carries the Permissions-Policy that closes microphone=(), which CLAUDE.md names as an outward privacy commitment. (4) docs/accessibility.html is the accessibility statement. If a job changes one of these outside its paths, the file shows up only in outsideScope. It never reaches sensitiveOutside, the APPROVE reason's 'not covered' list or scopeOpen.
   - Vorschlag: Widen the docs alternation to `^docs/(privacy|terms|health|impressum|security|claims|accessibility)(\.html|/index\.html)$` and add `^docs/_(headers|redirects)$`. Add one selftest case with docs/privacy/index.html outside the paths. Alternatively, narrow the category sentence in SKILL.md to name the exact files the regex covers.
2. **minor** `scripts/factory-board.py`:46 — scope_open() treats any non-blank `reviewedBy` as reviewed, and selftest board 011 deliberately accepts a bare 'founder'. A placeholder such as 'pending' or 'x' therefore takes a legal, privacy or health file off --open. The SKILL.md example at line 182 implies a dated record ('<Job-Nummer oder founder JJJJ-MM-TT>'). By contrast, deviceOpen.verified must match YYYY-MM-DD. The weaker check sits on the more sensitive surface: health and legal wording is founder-owned per the approver prompt.
   - Vorschlag: Require `reviewedBy` to be either a job id that exists under scratchpads/factory/ or 'founder YYYY-MM-DD', and report anything else as a problem, the same way `verified` is handled. Add a mutation for a bare 'founder' and one for 'pending'.
3. **minor** `.claude/skills/factory/SKILL.md`:193 — The new 'Wann nicht' rule exempts a one-sentence change in an INTERNAL file and names docs/dev/ as internal. docs/dev/FEATURE_STATUS.md is, with ContentPipeline/CLAIMS.md, one of the two registers CLAUDE.md names for what store, website and content may claim. The UX lens charter cites both. The same paragraph routes ContentPipeline/ through the factory as an outward claim. A one-line edit that marks a feature as shipping in FEATURE_STATUS.md changes what is claimable outward, yet skips review. docs/dev/ is also publicly served; docs/robots.txt:21-25 says 'public by GitHub-Pages necessity'. This is a narrowing of the old blanket 'ein Docs-Satz' exemption, not a regression.
   - Vorschlag: Take docs/dev/FEATURE_STATUS.md, and any other register that outward copy is derived from, out of the internal exemption. For example: 'ein Satz in einer internen Datei (docs/dev/ außer FEATURE_STATUS.md, memory/, scratchpads/)'.
