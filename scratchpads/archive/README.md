# Archiv — supersedete Pläne & historische Reports

Systematisches Vergessen (Task #63): Dokumente wandern hierher, wenn sie
(a) von einem NEUEREN Dokument zum selben Thema abgelöst wurden,
(b) ihr Bau-Task im Task-Ledger `completed` ist, oder
(c) reine Historie sind (Nacht-Reports, Handoffs, Erst-Test-Notizen).

Regeln:
- NIE archivieren, was `CLAUDE.md` referenziert (z. B. `DEEP_AUDIT_2026-07-12.md`,
  `ARCHITECTURE_AUDIT_2026-06-09.md`, `MASTERPLAN_2026-07.md`, `PLAN_VIDEO_PAGE.md`).
- NIE archivieren: `SESSION_LOG.md`, `HARNESS_LEDGER.md`, laufende `PLAN_*` zu
  in_progress-Tasks, `FOUNDER_DEVICE_SESSION.md`, `BACKLOG_*`.
- Verschieben mit `git mv` (Historie bleibt), Batch pro Hygiene-Zyklus, eine Zeile
  Begründung im Commit.
- Nichts hier drin ist gelöscht — bei Bedarf zurückholen statt neu schreiben.

## Batch 2026-10-24 (Repo-Aufräumen, Inventur mit Skeptiker-Gegenprüfung)

Root: `LOOP-STATE.md` (Loop-Zustand einer Juli-Sitzung, 0 Verweise) · `TODO.md` (abgelöst von
`docs/dev/TODO_FOUNDER_2026-10-19.md` + `docs/dev/TODO_2026-10-18.md`) ·
`APPLE_INTEGRATION_NOTES.md` (Fragenkatalog; die Antworten stehen in
`APPLE_INTEGRATION_AUDIT_2026-06-19.md` hier im Archiv). Gelöscht statt archiviert (kein
Aufrufer, Inhalt widerspricht dem Stand): `deploy.sh`, `run_integration_tests.sh`,
`.gitmessage`, `scripts/generate-xcode-project.sh`.
