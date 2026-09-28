# Schutz der founder-gesperrten Pfade

Geschützt sind genau vier Pfade, keine weiteren:
`.github/workflows/**` · `project.yml` · `Resources/iOS/Info.plist` · `.deploy/release`.

Die Grundlage ist die bestehende Regel „berichten, nicht editieren“ (`CLAUDE.md` DO NOT,
`.claude/rules/context.md` §3). Diese Datei beschreibt die technische Durchsetzung. Freigegeben
hat sie der Founder am 2026-09-28 als kleine, separate Änderung.

## Die zwei Schichten

| Schicht | Wo | Was sie fängt |
|---|---|---|
| **Eingebaute Regeln** `permissions.ask` | `.claude/settings.json` | Edit/Write-Werkzeug; Bash-Schreibzugriffe, die Claude Code selbst parst (Umleitung `>`, `cp`, `sed -i`, `git mv`) |
| **Hook** `protect-founder-gated.py` (PreToolUse, Matcher `Bash`) | dieses Verzeichnis | (1) Schreiben aus einem Interpreter heraus (`python3 -c`, `python3 - <<EOF`, `node -e` …), (2) `git commit`, der einen geschützten Pfad mitnimmt |

**Warum es den Hook braucht (belegt, nicht angenommen).** Gemessen am 2026-09-28 in einem
Wegwerf-Repo mit verschachteltem `claude -p`: Nur mit den eingebauten Regeln ging
`python3 -c "open('project.yml','w')…"` im Modus `default` durch. Dieses Projekt erlaubt
`Bash(python3 -c:*)` vorab. Im Modus `auto` stoppte den Zugriff nur der Modell-Klassifikator.
Ohne die Regeln ließ derselbe Klassifikator den Schreibzugriff zu. Das ist eine Einschätzung,
keine Regel.

## Wie deine gezielten Freigaben funktionieren

- Beide Schichten antworten mit **„ask“**, nie mit „deny“. Jeder betroffene Zugriff löst eine
  **Berechtigungsabfrage** aus, und in der Cloud-Sitzung landet sie in der App.
  **Du gibst genau diese eine Aktion frei, indem du die Abfrage bestätigst.** Die nächste
  Aktion fragt wieder.
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
| `cat project.yml` | erlaubt | — |
| `python3 -c` schreibt `notes.md`, Edit auf `notes.md` | erlaubt | erlaubt |
| `git restore --staged .github/workflows/ci.yml` (nur Index) | — | erlaubt |
| Commit nur mit `notes.md` | — | erlaubt |

Zusätzlich:

- **Selbsttest:** `python3 .claude/hooks/protect-founder-gated.py --selftest` (40 Fälle).
- **Neun Mutanten:** Jeder absichtlich eingebaute Fehler macht mindestens einen Fall rot.
- **Abgleich mit der Sitzungshistorie:** Rund 14 800 frühere Bash-Befehle dieser Sitzung liefen
  durch den Hook. Er hätte vor allem die echten, von dir freigegebenen Schreibzugriffe auf die
  vier Pfade gemeldet.

## Verbleibende Grenzen

`python3 .claude/hooks/protect-founder-gated.py --limits` gibt die vollständige Liste aus. Die
wichtigsten Punkte:

1. **Regel 1 liest Text.** Ein zur Laufzeit gebauter Pfad bleibt unsichtbar, etwa per base64,
   durch Verkettung, über den Parameter einer Hilfsfunktion oder mit `cd Resources/iOS && …`.
   Das Netz dafür ist die Commit-Regel.
2. **Die Commit-Regel greift nur bei `git commit`.** `merge`, `cherry-pick`, `revert` und `am`
   erzeugen Commits an ihr vorbei, und `git push` wird nicht geprüft.
3. **Hook und `settings.json` sind selbst nicht geschützt.** Das ist eine bewusste Grenze des
   Auftrags. Eine Änderung daran bleibt in Diff und Commit sichtbar.
4. **`bypassPermissions` überspringt „ask“.** Die Cloud-Sitzungen dieses Repos laufen in `auto`.
5. **Fehlalarme sind möglich:** ein `cd` in ein anderes Verzeichnis plus derselbe Dateiname,
   oder das Bearbeiten dieses Hooks selbst. Ein Fehlalarm kostet eine Rückfrage, nie einen
   stillen Durchlauf.
6. **Nicht am echten Gerät geprüft:** wie die Abfrage in der App aussieht. Das zeigt sich beim
   nächsten TestFlight-Deploy, der `.deploy/release` anfasst. Dort erscheint dann pro
   Schreibzugriff eine Abfrage.

## Nebenbefund, nicht Teil dieses Auftrags

Der Block `safety` in `.claude/settings.json` ist ein eigener Schlüssel. Claude Code **setzt ihn
nicht durch**: Ein `echo`, das dort genannte Muster enthielt, lief im Test ungehindert. Er ist
Doku, keine Sperre. Er bleibt unverändert, weil das eine Entscheidung für dich ist.
