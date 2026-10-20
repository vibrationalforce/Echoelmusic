# Runde 1 — was eingearbeitet ist, was nicht, und warum

Workflow `wf_630b7969-cf1`, erstmals mit der Prüfer-Fassung von der Job-Basis (`73e9ae52d`), auf
`73e9ae52d..dcae95345`: REWORK, sieben Majors (code zwei, security drei, ux zwei; e2e PASS mit sieben Minors).
Nach Duplikaten sind es VIER Sachverhalte. Zwei Behauptungen der Linsen hat der PM vor der Reparatur in einem
Wegwerf-Repo im Scratchpad nachgemessen, nicht geglaubt: Git druckt mit `core.quotePath=false` U+202E, U+200B,
U+0085, U+061C und ein Tag-Zeichen roh und quotet nur C0, DEL, `"` und `\`; und `git log` ohne `--full-history`
übergeht einen gemergten Seitenast, der `.claude/settings.local.json` anlegt und wieder löscht (leer), mit
`--full-history` erscheinen beide Commits.

**Eingearbeitet (alle vier):**
- **`fixed` war ein Ternär, und an der Grenze fielen Sperre und Token-Notiz weg** (code, security, ux). Genau der
  wahrscheinliche Fall: ein Token, in Nacharbeit 2 committet, taucht erst in Runde 3 auf, wo die Security-Linse ihn
  als Blocker meldet. `fixed` setzt sich jetzt aus Teilen zusammen (Grenze · Sperre samt Token-Notiz · versteckter
  Name), `join('; ')`; der Approver-Prompt nennt jeden Teil. Fall „the cap with the token committed keeps the lock
  and the token note“, Mutation „the cap keeps only one part“.
- **Die erweiterte Zeichenklasse machte einen ECHTEN Namen zur endlosen `RERUN`-Schleife vor der Sperre** (code,
  security). Neu: C0 und DEL (druckt Git nie roh) → `RERUN` mit der Linse; ein Format-, Trenn- oder C1-Zeichen
  (`\p{Cc}\p{Cf}\p{Zl}\p{Zp}`, damit auch U+061C, U+00AD, U+180E, U+206A–206F und Tag-Zeichen) → `ESCALATE`, wenn
  JEDE Linse den Namen meldet (Trojan Source ist eine Founder- und Sicherheitsfrage), sonst `RERUN`. Die
  Sperrliste wird VOR dieser Prüfung berechnet, und eine Sperr-Änderung in irgendeiner Liste hebt jedes solche
  `RERUN` auf. Der falsche Kommentar ist ersetzt. Elf Zeichen je zweimal (eine Linse / alle Linsen) plus vier
  Kombinationsfälle; Namen im Grund laufen durch `ascii()`.
- **Die Token-Prüfung vor dem Push hatte die beruhigende Fehlerrichtung** (security): jetzt
  `git log --full-history`, mit dem Grund im Satz.
- **Die Lese-Liste des Wächters ließ `Data(contentsOf:)` auf `.claude/settings.json` weg** (ux): genannt, dazu der
  `grep`, der jede Lese-Stelle findet.

**Minors, alle eingearbeitet:** `recount` eskaliert nur eine ZÄHL-Abweichung (SKILL Schritt 6, code und e2e) ·
die `deviceCriteria`-Lesart nennt den `recount`- und Eskalationsfall (ux) · Anspruch 10 scannt `decision: 'RERUN'`
UND `decision = 'RERUN'` (code, e2e), und seine Benotung ist je Nadel korrigiert: `metCode` ist ein Gegengewicht,
die Reihenfolge ist an der Basis durch Anker-Abwesenheit rot, und jede Nadel läuft jetzt VOR dem frühen Ausstieg
(e2e) · ein leerer Eintrag fällt weg, und Kriterium 6 sagt das jetzt so (code — ein leerer Name kann keinen
Sperrpfad verstecken, ein Zwang zu `RERUN` kostete nur Runden) · `Gemfile` und `.github/actions/` sind sensibel,
die Pluginfile-Begründung der Spec ist korrigiert (security, e2e — `setup-asc-api-key` lädt den Schlüssel) · eine
Annahme, die `[FOUNDER]` nur im Text nennt und nach einer Founder-Entscheidung klingt, geht in `forTheHuman`
(security) · eine frühe Eskalation trägt `deviceAsks`, `founderOpen` und `unmet` mit (e2e).

**Nicht eingearbeitet:** nichts. Außerhalb von `paths` liegt diesmal `108fa2da7` (U+2028/U+2029 im Protokoll von
Job 001 als ⟨U+XXXX⟩ geschrieben — der frühere Scan prüfte die Kategorien Zl/Zp nicht), nicht sensibel.

Selbsttest: alle Fälle wie erwartet, `--mutate` 108/108. Wächter-Ansprüche 1–10 in Python gegen `73e9ae52d` und den
Arbeitsbaum transkribiert (Anspruch 10 je Nadel). Nicht kompiliert (kein Swift hier). Nichts gerätegeprüft; der Job
berührt keine App.
