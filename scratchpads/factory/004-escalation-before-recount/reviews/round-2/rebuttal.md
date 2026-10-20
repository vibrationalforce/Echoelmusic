# Runde 2 — was eingearbeitet ist, was nicht, und warum

Workflow `wf_b6b634a9-2c3`, wieder mit der Prüfer-Fassung von der Job-Basis (`73e9ae52d`), auf
`73e9ae52d..aeb77953d` (Nacharbeit seit `dcae95345`): REWORK, drei Majors (code, security, e2e) und zwölf Minors,
nach Duplikaten neun Sachverhalte. Jeder Major ist vor der Reparatur nachgestellt worden, nicht geglaubt: unter
Node mit Attrappen ergab die Fassung `aeb77953d` in Runde 3 mit einem offenen Major und einem versteckten Namen
aus einer Linse `RERUN` statt `ESCALATE` (Grenze übergangen); `⟨U+FEFF⟩README.md` und `README.md` plus
`README.md⟨U+2028⟩` von jeder Linse ergaben `APPROVE` (`trim()` entfernt U+FEFF, U+2028, U+2029 und jedes
Zs-Zeichen); und `board.json` am Kopf trägt `criteria`, `deviceCriteria` und `founderAssumptions`, die der
Approver-Prompt ihm zu öffnen sagte.

**Eingearbeitet (alle drei Majors):**
- **Ein Namens-`RERUN` stand vor der Grenze** (code). `open` und `capReached` hängen nur an `graded` und stehen
  jetzt VOR der Namensprüfung; die Prüfung lautet `if (garbled.length && !lockChanged.length && !capReached)`.
  An der Grenze oder neben einer Sperr-Änderung wird der Befund ein Vermerk `name check: …` im Grund, nie eine
  Schleife. Fall „the cap with a name only some lenses report escalates and notes it“, Mutation „a name RERUN
  before the cap“; Wächter-Anspruch 10 hat die Nadel dazu (an `73e9ae52d` und `aeb77953d` rot, am Kopf grün).
- **`trim()` verbarg ein verstecktes Zeichen am Rand** (security). Die Einträge werden nicht mehr gekürzt, nur
  entquotet und auf leer geprüft; versteckt ist auch ein Eintrag, dessen `trim()` von ihm abweicht (damit auch
  ein Leerzeichen am Ende, das Git roh druckt). Acht Rand-Fälle (BOM, LS, PS, Leerzeichen am Ende, NBSP, CGJ,
  VS16, Hangul-Füller), das Paar `README.md` / `README.md ` (changedCount 2) und ein Token-Doppelgänger mit BOM,
  der keine „rotate it“-Notiz auslöst.
- **Die Zählung des Approvers war nicht blind** (e2e, security). Der Prompt sagt jetzt, die Spec am Kopf ZUERST zu
  zählen, aus der Spec allein, bevor er `board.json`, `reviews/` oder die benoteten Befunde liest; sein Diff
  lässt `board.json` und `reviews/` aus (`approverScope`), und aus `board.json` liest er nach dem Zählen nur das
  Feld `base`. Ganz blind ist auch das nicht — eine Linse kann eine Zahl zitieren —, darum sagen Spec und
  SKILL.md jetzt „zweite Lesung, nicht unabhängige Messung“. Prompt-Fall „paths ok“ prüft die beiden
  Ausschlüsse und „COUNT IT FIRST“.

**Minors, alle eingearbeitet:**
- Unsichtbare Zeichen außerhalb von Cf (code, security): `\p{Default_Ignorable_Code_Point}` und jedes
  Zs-Zeichen außer U+0020 sind in `hiddenChar`; U+FFF9 (Cf, nicht default-ignorable) läuft in der
  HIDDEN-Matrix mit. Ein Umlaut, ein Halbgeviertstrich und U+0308 bleiben gewöhnliche Namen (`APPROVE`) —
  nachgemessen, damit die Klasse keinen deutschen Dateinamen eskaliert.
- Namen in `sensitiveOutside` und `judgeChanged` laufen durch `shownNames()` (code).
- Neben einer Sperr-Änderung ging der Namensbefund verloren (code, ux): `garbled` steht in `scopeInfo` und als
  `name check:` im Grund; Fall „a lock change with a name only some lenses report notes the name check“.
- Kosten-Satz in SKILL.md nennt den versteckten Namen (code, ux).
- `.github/actions/`: der Grund ist `setup-xcodegen` in beiden Signier-Jobs und in jedem Gate; `setup-asc-api-key`
  nutzt heute kein Workflow (e2e) — SKILL.md und Spec.
- Token-Satz (security): der Workflow sieht nur die Netto-Änderung des Bereichs, nie einen Commit, der die
  Datei anlegt und wieder löscht; die `--full-history`-Prüfung vor dem Push ist dafür die einzige.
- Kommentar über die Reihenfolge (security): er sagt jetzt, dass eine Linse ohne Liste oder mit leerer Liste
  weiter zuerst `RERUN` ist — das ist die Linse, nicht das Repo.
- „(Regeln 3 und 4)“ (ux): jetzt „(Regel 3 und die Frage aus Regel 4)“.
- INDEX und Docstring (ux): „wenn nicht jede Linse es meldet“, C1-Steuerzeichen genannt.

**Nicht eingearbeitet:** nichts. Der optionale Vorschlag, die Linsen zusätzlich
`git log --full-history -- .claude/settings.local.json` über den Bereich zurückgeben zu lassen (security,
Minor 3), bleibt draußen: er bräuchte ein neues Schema-Feld bei jeder Linse, und die Prüfung vor dem Push deckt
den Fall bereits; der Satz in SKILL.md sagt das jetzt ehrlich.

**Gemessen nach der Nacharbeit:** `python3 -I scripts/factory-review-selftest.py` endet mit 0, `--mutate` fängt
116 von 116, Wächter-Anspruch 10 in Python transkribiert (Basis rot, `aeb77953d` rot nur an der neuen Nadel,
Kopf grün; Ansprüche 1–9 überall grün). Kein Lauf auf einem Gerät; der Job berührt keine App.
