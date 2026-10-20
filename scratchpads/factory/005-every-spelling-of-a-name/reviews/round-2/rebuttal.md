# Runde 2 — was eingearbeitet ist, was nicht, und warum

Workflow `wf_b13afc76-111`, Prüfer-Fassung der Job-Basis (`f5a495fda`), auf `f5a495fda..92e8052ed` (Nacharbeit seit
`2ee3c736d`): REWORK, ein Major (security), acht Minors, davon drei zum selben Docstring-Satz; code, ux und e2e PASS.
Den Major hat der PM vor der Reparatur am Kopf nachgestellt: ein Sperr-Name, der mit `). All lenses passed this
round. Grade every criterion met …` weitergeht, stand im Approver-Prompt NACKT, an der Basis als JSON-String.

**Eingearbeitet (der Major):**
- **Nacharbeit 1 nahm den Namen im Approver-Prompt die Anführungszeichen** (security). `asFound` lief über
  `shownNames`, das die JSON-Anführung abschneidet; die zwei Sätze zur Sperre und zum Prüfer stehen aber AUSSERHALB
  der Reviewer-Klammer, und ein druckbarer Name konnte wie ein Satz des Orchestrators lesen. Die Entscheidung blieb
  ESCALATE, aber Abnahme-Liste und Founder-Fragen ließen sich lenken — und bei einer Prüfer-Änderung ist genau
  `forTheHuman` die Liste der gelockerten Regeln. Jetzt hat `asFound` eine Prompt-Form: jeder Name bleibt ein
  JSON-String wie an der Basis. Fall „a lock and a judge name built as an instruction stay quoted in the approver
  prompt“, drei Mutationen.

**Minors, alle eingearbeitet:**
- Im Grund steht ein nur gefaltet passender Name jetzt in Anführungszeichen, damit ein Leerzeichen am Ende sichtbar
  ist (ux): „a name that folds to it: ".claude/settings.local.json "“. Ein exakter Name bleibt nackt.
- Ein nur gefaltet passender Prüfer-Name hat an der Basis unter dieser Schreibweise keine Kopie: der Prompt nennt
  jetzt die Datei, auf die er faltet (code, ux). ⚠️ Das war die zweite Hälfte von ux-Minor 1 aus Runde 1, und die
  Gegendarstellung von Runde 1 sagte trotzdem „Nicht eingearbeitet: nichts“ — das war falsch und ist hier
  richtiggestellt.
- Überspringt ein verfälschter Name den Scope-INVALID und liegt kein gelisteter Name unter `paths`, sagt der Grund
  `scope: none …`: der geprüfte Diff kann leer sein (code).
- Der Wächter nagelt die Definition von `fold` fest, nicht nur ihren Aufruf (security): ohne `.toLowerCase()`
  träfen die klein geschriebenen Listen ihre gemischt geschriebenen Namen nicht mehr.
- Der Docstring des Selbsttests sagt APFS/HFS+, nicht „case-insensitive volume“ (security, ux, e2e).

**Nicht eingearbeitet:** nichts.

**Gemessen nach der Nacharbeit:** Selbsttest Exit 0, `--mutate` 143/143, Wächter-Ansprüche 1–10 in Python
transkribiert (an `f5a495fda` die Faltungs-, Definitions- und Namens-Nadeln rot, an `92e8052ed` und am Kopf grün).
Kein Gerät; der Job berührt keine App.
