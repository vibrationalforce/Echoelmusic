# 005 — Nur leere Einträge fallen weg, und Sperre, Prüfer und Sensibles erkennen jede Schreibweise eines Namens

## Goal
Die Namensprüfung des Factory-Prüfers wirft nur wirklich leere Einträge weg, und ein Name, der auf einem APFS- oder
HFS+-Volume die Sperr-Konfiguration, der Prüfer oder eine sensible Fläche ist, wird auch so behandelt.

## Assumptions
- Herkunft: der offene Major und die Minors aus Job 004, Runde 3 (`wf_c2619890-b9f`,
  `scratchpads/factory/004-escalation-before-recount/decision.md`). Den Major hat der PM vor dem Bau
  nachgemessen: `trim()` leert ein Leerzeichen, NBSP, BOM, U+2028 und U+3000; ein Wegwerf-Repo mit den
  Dateien ` ` und NBSP druckt `git show --name-only` beide roh.
- [FOUNDER] Dieser Job beginnt unter der Delegation des Founders, solange GM27 (`docs/dev/FOUNDER_INBOX.md` §1)
  offen ist; ein Nein zu GM27 nimmt die Jobs 003, 004 und diesen zurück.
- Geprüft wird mit der Prüfer-Fassung an SEINER Basis (`git show <base>:.claude/workflows/echoel-factory-review.js`
  in den Scratchpad, `Workflow({scriptPath})`); weil er den Prüfer ändert, eskaliert er am Ende über die
  Prüfer-Regel. Das ist gewollt.
- Die Richtung ist nur strenger: ein Name wird für Sperre, Prüfer und SENSIBLES gefaltet (versteckte Zeichen
  und C0 entfernt, Rand-Leerraum entfernt, NFKC, Groß-/Kleinschreibung gefaltet), damit `.claude/Hooks/…`,
  `.Claude/settings.json` oder ein aufgefüllter Token-Name nicht an der Sperre vorbeigeht. Unter Linux ist nicht
  messbar, ob APFS ohne Unterscheidung der Schreibweise zwei solche Pfade auf eine Datei legt; die Faltung
  eskaliert dann eben einmal zu viel, nie einmal zu wenig. Der Scope (`inScope`) bleibt exakt, weil Git-Pfade
  im Repo die Schreibweise unterscheiden. Nicht gedeckt, bewusst (Runde 1, security): NTFS-Aliasse (Punkt am
  Ende, `::$DATA`, 8.3-Namen) und die volle Fallfaltung (ß→ss) — Founder-Rechner sind Apple, Sitzungen Linux.
- Die Listen der Sperre und des Prüfers stehen in gefalteter Form (Kleinbuchstaben), sonst träfe der gefaltete
  Name sie nicht; der Wächter hält das fest.
- Dieser Job hat kein Geräte-Kriterium: er berührt keine App.

## Acceptance criteria
1. Nach dem Entquoten fällt nur ein Eintrag weg, der GENAU leer ist; ein Name nur aus Leerraum, BOM, NBSP,
   U+2028 oder U+3000 erreicht die Prüfung auf versteckte Zeichen: `ESCALATE` (disguised), wenn jede Linse ihn
   meldet, sonst `RERUN` — Selbsttest-Fälle je Zeichen in beiden Richtungen.
2. Ein Namens-`RERUN` weicht auch einem `disguised`-Namen (wie der Grenze und der Sperre) und wird dann ein
   Vermerk `name check:` im Grund — Selbsttest-Fall.
3. `lockChanged`, `judgeChanged` und `sensitiveOutside` prüfen den GEFALTETEN Namen; `.claude/Hooks/x.py`,
   `.Claude/settings.json`, `.claude/SETTINGS.JSON`, ein Token-Name mit Leerzeichen am Ende (auch von nur einer
   Linse, auch an der Grenze, dann mit der Token-Notiz), `.claude/Workflows/echoel-factory-review.js` und
   `docs/PRIVACY.html` werden erkannt; die Token-Notiz vergleicht ebenfalls gefaltet; ein Name, der nur GEFALTET
   passt, heißt im Grund und im Approver-Prompt „a name that folds to it“, ein exakter nie — Selbsttest-Fälle.
4. Ein Name mit C0-Zeichen macht den Aufruf nie `INVALID`, in keiner Richtung (innerhalb oder außerhalb von
   `paths`): an der Grenze oder neben einer Sperr-Änderung ist es `ESCALATE` mit `name check:`; er bleibt in `outsideScope` und `sensitiveOutside`, damit
   nichts, was eine Linse meldete, aus dem Grund fällt — Selbsttest-Fälle.
5. Der Selbsttest pinnt den Linsen-Diff wieder bis zum schließenden Backtick (`git diff ${range}${scope}` ohne
   den Approver-Ausschluss) — eine Mutation, die den Linsen den Approver-Diff gibt, wird rot.
6. `SKILL.md`, `scripts/INDEX.md`, der Docstring des Selbsttests und die Workflow-Kommentare sagen dasselbe wie
   der Code: nur Leeres fällt weg, gefaltete Sperr-/Prüfer-/Sensibel-Prüfung, das Ausweichen vor `disguised`,
   kein „immer `RERUN`“ und kein unbedingtes „blind“ — und zitieren nur Pfade, die existieren
   (`scripts/doctor.py --section B`).
7. Beide Selbsttests enden mit 0, und `--mutate` fängt jede Zeile seiner Tabelle, auch die neuen (Leer-Test,
   Ausweichen, je eine Faltung, Token-Notiz, C0-Scope, Linsen-Diff).
8. `TheFactoryReviewersAreReadOnlyTests`: Anspruch 8 verlangt die Faltung an der `lockChanged`-Stelle und
   Listen in gefalteter Form, Anspruch 9 dasselbe für `judgeChanged`, Anspruch 10 das Ausweichen vor `disguised`
   — in Python gegen Basis und Kopf transkribiert (an der Basis rot durch die Änderung, am Kopf grün).

## Out of scope
`factory-board.py`, `.claude/hooks/`, `.claude/settings.json`, `.claude/agents/`, eine Faltung des Scopes
(`inScope`), jede Änderung an der Eskalationsreihenfolge außer dem Ausweichen vor `disguised`.
