# Runde 1 — was eingearbeitet ist, was nicht, und warum

Workflow `wf_b852534d-658` auf `f61d7872d..9237c3c91`: REWORK, vier Majors (Code zwei, Security einer,
Ship-Pfad einer), UX PASS. Jeder Major ist vor der Reparatur gemessen, nicht geglaubt.

**Eingearbeitet (alle vier Majors):**
- **Eine Umbenennung umging die feste Eskalation** (code). Gemessen auf `1118a1bd3`:
  `git diff --name-only` nennt `EchoelStudio/Plugins/Effects/Info.plist` nicht, `--no-renames` nennt sie.
  Linsen und Approver lesen die ungefilterte Liste jetzt mit `--no-renames`; ein weggeschobener Hook steht
  mit seinem alten Pfad in `changedFiles` und eskaliert (Selbsttest-Fall „a moved-away hook“).
- **`reviewedBy: null` galt als geprüft** (code). Gemessen: `str(None).strip()` ist `"None"`. Offen ist jetzt
  nur ein fehlendes oder `null`-`reviewedBy`; geprüft heißt die Nummer eines ANDEREN, existierenden Jobs oder
  `founder JJJJ-MM-TT`; jeder andere Wert (`"founder"`, `"pending"`, `"  "`, `0`, `false`, die eigene Nummer,
  ein fehlender Job) ist ein Befund. Damit ist auch der UX-Minor „ein beliebiges Wort schließt eine
  Rechtsdatei“ erledigt — dieselbe Strenge wie das Datum einer Geräte-Prüfung.
- **Der Prüfer war selbst nicht gesperrt** (security; als Minor auch code und e2e). Messung: die Linsen dieser
  Runde bekamen den `changedFiles`-Prompt, der an der Basis `f61d7872d` null Mal vorkommt — der Job wurde von
  seiner eigenen Fassung geprüft. Neu: `JUDGE_FILES`/`JUDGE_DIRS` (dieser Workflow, `.claude/agents/`). Ein
  Job, der sie ändert, durchläuft die Nacharbeit wie jeder andere, endet aber nie in APPROVE (Regel 6 in
  SKILL.md Schritt 6). Anders als die Sperr-Konfiguration überspringt das die Nacharbeit nicht, weil der
  Founder eine fertige Fassung beurteilen soll. Ab Job 004 startet der PM einen solchen Job mit der Fassung
  von der Job-Basis (`Workflow({scriptPath})`, SKILL.md Schritt 4), damit die Regel greift, die der Job nicht
  geschrieben hat. **Folge für diesen Job: er eskaliert am Ende über genau diese Regel** — gewollt; er gehört
  zu GM27. Wächter-Anspruch 8 liest jetzt zusätzlich `PROTECTED_DIRS` und `permissions.ask` (dort steht
  `Edit(/.claude/hooks/**)`), Anspruch 9 pinnt die Prüfer-Regel und ihre Stellung vor APPROVE.
- **„Ein Lauf auf dem head“ ignorierte die Pfadfilter** (e2e). Richtig: gemessen startete `9237c3c91` CI/CD
  und Xcode Compile Check, eine reine `.claude/`-Nacharbeit startet nichts. Neu in SKILL.md: je Gate zählt der
  neueste Lauf auf dem Kopf oder einem Vorfahren im Job, nach dem sich kein Pfad DIESES Gates geändert hat;
  „kein Lauf“ gilt nur, wenn der GANZE Job keinen gefilterten Pfad berührt.

**Eingearbeitet (Minor):**
- `paths` ohne `.`-Segment und ohne `//` (code: `.` und `./scripts` passten `PATH`, aber nicht `inScope`).
- `INVALID` nur, wenn JEDE Linse mit einer Liste geantwortet hat; fehlt eine, ist es `RERUN` (code). Eine Linse
  ohne `changedFiles`-Liste ist `RERUN` mit ihrem Namen, sonst fiel die Sperrprüfung still aus (security).
- `SENSITIVE` deckt jetzt die Weiterleitungen `docs/privacy/index.html` und `docs/terms/index.html`,
  `docs/_headers` und `docs/_redirects`, `docs/accessibility.html`, `THIRD_PARTY_NOTICES.md`, jedes
  `project.yml`, `.github/workflows/`, `EchoelStudio/RELEASE` und `docs/dev/FEATURE_STATUS.md` (alle drei
  Linsen). Alle Pfade existieren (gemessen).
- Die Art folgt allein der Spec: ein `founder`-Etikett auf einem nummerierten Kriterium zählt als `code`
  (code). Ein `founder`-Beleg braucht neben der Datei ein Datum; das Beispiel im Selbsttest war die OFFENE
  Zeile GM27 und ist durch eine erfundene, beantwortete ersetzt (security).
- `founderAssumptions` (fehlt = 0): weniger Nummer-0-Einträge als `[FOUNDER]`-Annahmen ist `RERUN` (code).
- Dateinamen der Linsen erreichen den Approver nur noch über `ascii()` wie der Datenblock (security).
- Der Approver prüft, dass `board.json` am Kopf dieselbe `base` führt (security).
- Die Mutationen sind nachrechenbar: `--mutate` in beiden Werkzeugen, die Tabelle steht in der Datei, und
  eine Zeile, die nicht mehr genau einmal passt, ist ein Fehler (code, zu AC9). Stand: Workflow 56 von 56,
  Board 12 von 12.
- „Wann nicht“ nimmt `docs/dev/FEATURE_STATUS.md` aus der Ausnahme für interne Sätze (ux).

**Nicht übernommen, mit Grund:**
- *Ein Pro-Lauf-Token in den Markern* — bleibt Out of scope (der Harness erlaubt kein `Math.random`); der
  ASCII-Block macht `--` unmöglich, das reicht für die Marker.
- *Die Hinweise des Ship-Pfads, dass der Auto-Merge nach `main` vor dem Ende der Prüfung laufen kann und nur
  `Build for Testing` liest* — zutreffend und kein Befund dieses Jobs: der Merge-Weg ist der des Baums
  (SKILL.md, Tabelle oben), `.github/workflows/**` ist founder-gesperrt.

**Spec:** Kriterien 1–9 präzisiert, Kriterium 10 (der Prüfer gibt sich nicht selbst frei) neu, `criteria` 10.
