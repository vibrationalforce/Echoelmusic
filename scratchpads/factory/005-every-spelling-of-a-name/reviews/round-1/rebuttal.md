# Runde 1 — was eingearbeitet ist, was nicht, und warum

Workflow `wf_1edd4391-ce0`, Prüfer-Fassung der Job-Basis (`f5a495fda`), auf `f5a495fda..2ee3c736d`: REWORK, zwei
Majors (code, e2e) zum selben Sachverhalt, sieben Minors; security und ux PASS. Der Major ist vor der Reparatur
nachgestellt, nicht geglaubt: die Mutation „forged names left out of the INVALID test“ setzt genau die Zeile von
`2ee3c736d` zurück und macht drei neue Fälle rot.

**Eingearbeitet (der Major):**
- **„C0 nie INVALID“ galt nur in einer Richtung** (code, e2e). `2ee3c736d` nahm verfälschte Namen aus dem
  INVALID-Test heraus; lag ein verfälschter Name INNERHALB von `paths` und ein echter außerhalb, war der Aufruf
  INVALID, und die Grenze oder die Sperre samt Token-Notiz ging verloren — an der Basis eskalierte dieselbe Eingabe.
  Die Abhilfe von code (`changed.every(f => !inScope(f))`) reicht nicht: mit Pfaden auf genau eine Datei liegt die
  verfälschte Kopie außerhalb, und die Lücke bleibt. Übernommen ist die Abhilfe von e2e: steht irgendein
  verfälschter Name in der Liste, gibt es keinen Scope-INVALID — so ein Name kommt nur neben einer festen
  Eskalation hier an, die Runde eskaliert also ohnehin. Drei Fälle (Grenze + verfälscht innen + echt außen; Sperre +
  verfälscht innen; Grenze mit Datei-Pfaden), zwei Mutationen.

**Minors, alle eingearbeitet:**
- Die exakte Token-Datei: beide Fälle verlangen jetzt „.claude/settings.local.json holds a token“, und eine
  Mutation, die ihr die schwache Formulierung gibt, wird rot (code).
- Kommentar „nothing a lens reported leaves the reason“: es ist das ERGEBNIS (`outsideScope`, `sensitiveOutside`),
  nicht der Text des Grundes (code).
- Wächter-Anspruch 8 vergleicht Hook und `permissions.ask` klein geschrieben mit `LOCK_CONFIG`, sonst widersprächen
  sich Teilmenge und Kleinschreibung bei einem gemischten Pfad (security).
- „auf JEDEM Dateisystem“ war zu viel: die Faltung vergleicht wie APFS und HFS+ (Schreibweise, Normalform,
  ignorierbare Code-Punkte); NTFS-Aliasse und ß→ss deckt sie nicht ab, und das steht jetzt so in Kommentar, SKILL.md,
  INDEX und Spec (security). Nachgebaut ist es bewusst nicht: die Founder-Rechner sind Apple.
- Ein nur gefaltet passender Name heißt in Grund und Approver-Prompt „a name that folds to it“, ein exakter nie —
  für Sperre und Prüfer (ux). Fälle und zwei Mutationen.
- „a padded token name is still the token file“ in Kommentar und Wächter-Meldung → „counts as the token file for the
  lock“ (ux).
- Die Listen müssen ASCII UND klein sein, nicht nur klein: NFKC und das Entfernen versteckter Zeichen sind nur auf
  ASCII die Identität (e2e).

**Nicht eingearbeitet:** nichts.

**Gemessen nach der Nacharbeit:** Selbsttest Exit 0, `--mutate` 136/136, Wächter-Ansprüche 1–10 in Python
transkribiert (an `f5a495fda` die Faltungs- und Namens-Nadeln rot, an `2ee3c736d` und am Kopf grün; die Teilmenge
klein geschrieben ändert heute nichts, weil jeder Sperr-Pfad klein ist). Kein Gerät; der Job berührt keine App.
