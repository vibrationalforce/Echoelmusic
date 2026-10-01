# Schutz der founder-gesperrten Pfade

Geschützt sind genau drei Pfade, keine weiteren:
`.github/workflows/**` · `project.yml` · `Resources/iOS/Info.plist`.

⭐ **`.deploy/release` ist seit 2026-10-01 FREI** (Founder, wörtlich: „Nur Deploy frei“). Der Agent hebt die Version und löst den TestFlight-Deploy selbst aus. Die drei übrigen Pfade bleiben gesperrt, weil ein Fehler dort den Build oder die App-Store-Prüfung bricht. Alles unten über „vier Pfade“ und die Tabellenzeilen mit `.deploy/release` beschreibt den Stand vom 2026-09-28 und bleibt als Messprotokoll stehen.

> **Geltungsbereich aller Aussagen hier: Claude Code 2.1.283** (`claude --version`, gemessen
> 2026-09-28), Modi `default` und `auto`, ausgelöst über `claude -p` im Wegwerf-Repo. Für eine
> andere Version oder einen anderen Modus ist nichts davon geprüft — nach einem Update den
> Test-Repo-Lauf unten wiederholen, bevor man sich darauf verlässt.

Die Grundlage ist die bestehende Regel „berichten, nicht editieren“ (`CLAUDE.md` DO NOT,
`.claude/rules/context.md` §3). Diese Datei beschreibt die technische Durchsetzung. Freigegeben
hat sie der Founder am 2026-09-28 als kleine, separate Änderung.

## Die zwei Schichten

| Schicht | Wo | Was sie fängt |
|---|---|---|
| **Eingebaute Regeln** `permissions.ask` | `.claude/settings.json` | Edit/Write-Werkzeug; Bash-Schreibzugriffe, die Claude Code selbst parst (Umleitung `>`, `cp`, `sed -i`, `git mv`) |
| **Hook** `protect-founder-gated.py` (PreToolUse, Matcher `Bash`) | dieses Verzeichnis | (1) Schreiben aus einem Interpreter heraus (`python3 -c`, `python3 - <<EOF`, `node -e` …), (2) `git commit`, der einen geschützten Pfad mitnimmt. Antwort: **`deny` im Modus `auto`**, sonst `ask` |

**Warum es den Hook braucht (belegt, nicht angenommen).** Gemessen am 2026-09-28 in einem
Wegwerf-Repo mit verschachteltem `claude -p`: Nur mit den eingebauten Regeln ging
`python3 -c "open('project.yml','w')…"` im Modus `default` durch. Dieses Projekt erlaubt
`Bash(python3 -c:*)` vorab. Im Modus `auto` stoppte den Zugriff nur der Modell-Klassifikator.
Ohne die Regeln ließ derselbe Klassifikator den Schreibzugriff zu. Das ist eine Einschätzung,
keine Regel.

## Wie deine gezielten Freigaben funktionieren

- **Im Modus `auto` lehnt der Hook einen erkannten Bash-Zugriff ab („deny“)** — seit
  2026-09-28, Variante A. Dort gibt es KEINE Freigabe per Abfrage mehr. In jedem anderen
  Modus antwortet er „ask“; die eingebauten Regeln antworten immer „ask“.
- **Was als Freigabeweg tatsächlich geprüft ist — ehrlich, weil es wenig ist:**
  · *geprüft:* im Modus `auto` verhindert „deny“ die Ausführung (Abschnitt „Deny-Beleg“);
    im verschachtelten `claude -p` (`default`) wirkte „ask“ als Sperre, weil niemand antwortete.
  · *NICHT geprüft:* dass eine Abfrage dich auf dem Handy erreicht und deine Bestätigung genau
    eine Aktion freigibt — in keinem Modus, in keiner Sitzung.
  · *nicht über Claude:* deine eigene Änderung (Editor, Terminal, GitHub-Weboberfläche) läuft
    an beiden Schichten vorbei — das ist Bauart, keine Messung.
  **Freigabe heißt deshalb heute: du machst die Änderung selbst**, oder du lässt einen Schritt
  im Modus `default` laufen und prüfst dabei, ob die Abfrage dich erreicht.
- Der Agent kann sich **nicht selbst freischalten**. Es gibt kein Token, keine Datei und keine
  Variable dafür, und das ist Absicht.
- Deine eigenen Änderungen (Editor, Terminal, GitHub-Weboberfläche) und die CI laufen **nicht**
  durch diese Schichten. Betroffen sind nur Claudes Werkzeugaufrufe.
- In einem Lauf ohne Menschen (`claude -p`) kann niemand antworten. Dort wirkt „ask“ wie eine
  Sperre.

## Beleg im Test-Repo (verschachteltes `claude -p`, 2026-09-28)

| Zugriff | `default` | `auto` |
|---|---|---|
| `python3 -c` schreibt `project.yml` | gesperrt (Hook) | gesperrt (Hook) |
| Python-Heredoc schreibt `.deploy/release` über eine Variable | — | gesperrt (Hook) |
| Edit-Werkzeug auf `.deploy/release` | gesperrt (eingebaute Regel) | — |
| `printf x > Resources/iOS/Info.plist` | gesperrt | — |
| `git commit` mit gestagter `.github/workflows/ci.yml` | — | gesperrt (Hook, Commit-Regel) |
| `git add project.yml && git commit …` in EINEM Befehl (Nachbesserung, echtes git) | Hook fragt | Hook fragt |
| `shutil.copy('.deploy/release', 'copy.txt')` (Nachbesserung, echtes git) | frei | frei |
| `cat project.yml` | erlaubt | — |
| `python3 -c` schreibt `notes.md`, Edit auf `notes.md` | erlaubt | erlaubt |
| `git restore --staged .github/workflows/ci.yml` (nur Index) | — | erlaubt |
| Commit nur mit `notes.md` | — | erlaubt |

Zusätzlich:

- **Selbsttest:** `python3 .claude/hooks/protect-founder-gated.py --selftest` — Fallzahl druckt er
  selbst; darunter die Regressionsfälle der Nachbesserung (Stagen + Commit in einem Befehl,
  Pfad-Commit, `shutil.copy` von geschützter Quelle, `shutil.copy` von geschützt auf
  geschützt, `dst=` vorn) und die Entscheidung je Modus (`auto` → `deny`, sonst `ask`).
- **Mutanten:** 16 aus der ersten Nachbesserung, jeder macht mindestens einen Fall rot. Aus der
  zweiten 5: 4 gefangen; der fünfte (Kopieren über Variablen, altes Muster) ist praktisch
  gleichwertig — er unterscheidet sich nur bei `shutil.copy(q, q)`, einer Kopie auf sich selbst.
- **Abgleich mit der Sitzungshistorie:** Rund 14 800 frühere Bash-Befehle dieser Sitzung liefen
  durch den Hook. Er hätte vor allem die echten, von dir freigegebenen Schreibzugriffe auf die
  vier Pfade gemeldet.

## Handy-Probe in der Cloud-Sitzung (2026-09-28, vor Variante A)

Gemessen in DIESER Cloud-Sitzung (`entrypoint remote_mobile`, Claude Code 2.1.283), jeweils mit
einem harmlosen Schreibzugriff auf die `project.yml` des Wegwerf-Repos `scratchpad/gatetest`
(der Hook meldet sie, weil er ein vorangestelltes `cd` nicht verfolgt — Grenze 5):

| Aufruf | Hook-Ausgabe | Rückfrage → Ausführung | Founder-Anweisung |
|---|---|---|---|
| `toolu_0177…` (Echt-git-Test, direkter `printf … > project.yml`, KEIN Testskript) | `ask`, Exit 0, stderr leer — nachgespielt mit derselben Hook-Logik: identisch | lief, Ergebnis 18 s nach der Rückfrage | keine |
| Probe 1 (`printf 'phone-probe'`) | `ask` | Hook-Lauf 14:58:50.8 → Befehl 14:58:51 UTC (≈1 s) | „bestätigen“ — Antwort: „Ich glaube“ |
| **Probe 2 (`printf 'deny-probe'`)** | `ask` | **Hook-Lauf 15:04:17.9 → Befehl 15:04:21 UTC (3,4 s)** | „ablehnen“ |

**Belegt ist genau das: der Hook gab `ask` aus, der Befehl wurde ausgeführt, und WELCHE Instanz
die Rückfrage aufgelöst hat, ist unbekannt.** Weder die Sitzungsdatei noch die Diagnosedateien
führen eine Berechtigungsentscheidung. Nicht belegt ist, ob du eine Abfrage gesehen oder
beantwortet hast (Antwort auf Probe 1: „Ich glaube“). Im verschachtelten `claude -p` wirkte
dasselbe `ask` als Sperre, weil dort niemand antworten kann — zwei Umgebungen, kein Widerspruch.
**Daraus folgt nur: im Modus `auto` war `ask` keine verlässliche Sperre.** Deshalb Variante A.

**Inzwischen gemessen (Grenze 6):** die EINGEBAUTEN `permissions.ask`-Regeln haben ein Edit auf
`project.yml` in dieser Sitzung (`auto`) nicht aufgehalten; gehalten hat die Commit-Regel.

## Deny-Beleg in derselben Cloud-Sitzung (2026-09-28, nach Variante A)

Gemessen in DIESER Sitzung; der Hook bekommt dort `"permission_mode": "auto"` (Nutzlast
mitgeschnitten, danach die Mitschnitt-Zeilen wieder entfernt).

| Aufruf | Hook | Ergebnis |
|---|---|---|
| `cd …/gatetest && echo DENY-PROBE-RAN && printf 'name: deny-live-probe\n' > project.yml` | `deny` | Aufruf 15:27:50.455 → Fehler 15:27:50.529 UTC; **kein** `DENY-PROBE-RAN`; `project.yml` danach unverändert (`name: x`, gleiche mtime, 8 B); echtes `project.yml` ohne Diff |
| unbeabsichtigt: mein eigener Python-Heredoc, der Selbsttest-Fälle mit `shutil.copy(…, '.deploy/release')` in den Hook schreiben wollte | `deny` | nicht ausgeführt — keiner der neuen Fälle stand danach in der Datei (Fehlalarm, Grenze 5) |

Der ganze Befehl wird abgelehnt, nicht nur der erkannte Teil.

## Verbleibende Grenzen

`python3 .claude/hooks/protect-founder-gated.py --limits` gibt die vollständige Liste aus. Die
wichtigsten Punkte:

1. **Regel 1 liest Text.** Ein zur Laufzeit gebauter Pfad bleibt unsichtbar, etwa per base64,
   durch Verkettung, über den Parameter einer Hilfsfunktion oder mit `cd Resources/iOS && …`.
   Das Netz dafür ist die Commit-Regel.
2. **Die Commit-Regel greift nur bei `git commit`.** Was DERSELBE Befehl vorher staget
   (`git add`/`git stage` mit Pfad, Verzeichnis, `-A`/`.`/`-u`, oder ein Pfad-Commit
   `git commit <pfad>`), rechnet sie aus dem Arbeitsbaum mit — Stagen über ein Skript oder eine
   Variable sieht sie nicht; dafür liest sie den Index erst beim NÄCHSTEN Commit-Befehl. `merge`, `cherry-pick`, `revert` und `am`
   erzeugen Commits an ihr vorbei, und `git push` wird nicht geprüft.
3. **Hook und `settings.json` sind selbst nicht geschützt.** Das ist eine bewusste Grenze des
   Auftrags. Eine Änderung daran bleibt in Diff und Commit sichtbar.
4. **Nur `default` und `auto` sind geprüft.** Dass `bypassPermissions` „ask“ überspringt, steht
   in der Doku und ist hier NICHT gemessen (als root verweigert); dort antwortet der Hook
   weiterhin `ask`. `plan`, `acceptEdits` und `dontAsk` sind ungeprüft. Fehlt
   `permission_mode` in der Nutzlast (andere Version), antwortet er `ask`.
5. **Fehlalarme sind möglich:** ein `cd` in ein anderes Verzeichnis plus derselbe Dateiname,
   oder das Bearbeiten dieses Hooks selbst. Ein Fehlalarm kostet eine Rückfrage, nie einen
   stillen Durchlauf.
6. **„deny“ gilt nur für Bash-Befehle, die der Hook erkennt.** Das Edit-/Write-Werkzeug läuft
   über die eingebauten `permissions.ask`-Regeln — und die haben im Modus `auto` NICHT
   gesperrt: am 2026-09-28 hat das Edit-Werkzeug `project.yml` in dieser Cloud-Sitzung ohne
   sichtbare Rückfrage geändert (Fall 20, vom Founder freigegeben, danach wieder auf HEAD
   gesetzt). Ob eine Rückfrage erzeugt und automatisch beantwortet wurde, ist unbekannt; die
   Wirkung ist gemessen. Die eigentliche Sperre war danach die Commit-Regel des Hooks: der
   Commit mit `project.yml` wurde abgelehnt. **Im Modus `auto` schützt also der COMMIT, nicht
   das Schreiben.** Grenzen 1 und 2 gelten
   unverändert: was der Hook nicht erkennt, lehnt er auch nicht ab.
7. **Eine Freigabe per Handy ist in keinem Modus belegt** (Abschnitt „Wie deine gezielten
   Freigaben funktionieren“).

## Nebenbefund, nicht Teil dieses Auftrags

Der Block `safety` in `.claude/settings.json` ist ein eigener Schlüssel. Claude Code **setzt ihn
nicht durch**: Ein `echo`, das dort genannte Muster enthielt, lief im Test ungehindert. Er ist
Doku, keine Sperre. Er bleibt unverändert, weil das eine Entscheidung für dich ist.
