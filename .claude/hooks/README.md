# Schutz der founder-gesperrten Pfade

Geschützt sind genau vier Pfade, keine weiteren:
`.github/workflows/**` · `project.yml` · `Resources/iOS/Info.plist` · `.deploy/release`.

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
| **Hook** `protect-founder-gated.py` (PreToolUse, Matcher `Bash`) | dieses Verzeichnis | (1) Schreiben aus einem Interpreter heraus (`python3 -c`, `python3 - <<EOF`, `node -e` …), (2) `git commit`, der einen geschützten Pfad mitnimmt |

**Warum es den Hook braucht (belegt, nicht angenommen).** Gemessen am 2026-09-28 in einem
Wegwerf-Repo mit verschachteltem `claude -p`: Nur mit den eingebauten Regeln ging
`python3 -c "open('project.yml','w')…"` im Modus `default` durch. Dieses Projekt erlaubt
`Bash(python3 -c:*)` vorab. Im Modus `auto` stoppte den Zugriff nur der Modell-Klassifikator.
Ohne die Regeln ließ derselbe Klassifikator den Schreibzugriff zu. Das ist eine Einschätzung,
keine Regel.

## Wie deine gezielten Freigaben funktionieren

- Beide Schichten antworten mit **„ask“**, nie mit „deny“. Ein ERKANNTER Zugriff löst eine
  **Berechtigungsabfrage** aus (in 2.1.283, `default` und `auto`, gemessen im
  verschachtelten `claude -p`). **Wo dich die Abfrage erreicht, gibst du genau diese eine
  Aktion frei, indem du sie bestätigst**; die nächste Aktion fragt wieder.
  ⚠️ **In der Cloud-Sitzung vom Handy aus hat dich die Abfrage NICHT erreicht** — sie wurde ohne
  dich aufgelöst (Abschnitt „Handy-Probe“ unten). Dort ist das Versprechen widerlegt.
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
  Pfad-Commit, `shutil.copy` von geschützter Quelle).
- **Mutanten:** jeder absichtlich eingebaute Fehler (16, davon 7 für die Nachbesserung) macht
  mindestens einen Fall rot.
- **Abgleich mit der Sitzungshistorie:** Rund 14 800 frühere Bash-Befehle dieser Sitzung liefen
  durch den Hook. Er hätte vor allem die echten, von dir freigegebenen Schreibzugriffe auf die
  vier Pfade gemeldet.

## Handy-Probe in der Cloud-Sitzung (2026-09-28) — Freigabe per Handy NICHT belegt, sondern widerlegt

Gemessen in DIESER Cloud-Sitzung (`entrypoint remote_mobile`, Claude Code 2.1.283), jeweils mit
einem harmlosen Schreibzugriff auf die `project.yml` des Wegwerf-Repos `scratchpad/gatetest`
(der Hook meldet sie, weil er ein vorangestelltes `cd` nicht verfolgt — Grenze 5):

| Aufruf | Hook-Ausgabe | Rückfrage → Ausführung | Founder-Anweisung |
|---|---|---|---|
| `toolu_0177…` (Echt-git-Test, direkter `printf … > project.yml`, KEIN Testskript) | `ask`, Exit 0, stderr leer — nachgespielt mit derselben Hook-Logik: identisch | lief, Ergebnis 18 s nach der Rückfrage | keine |
| Probe 1 (`printf 'phone-probe'`) | `ask` | Hook-Lauf 14:58:50.8 → Befehl 14:58:51 UTC (≈1 s) | „bestätigen“ — Antwort: „Ich glaube“ |
| **Probe 2 (`printf 'deny-probe'`)** | `ask` | **Hook-Lauf 15:04:17.9 → Befehl 15:04:21 UTC (3,4 s)** | **„ABLEHNEN“** |

**Schluss:** in diesem Sitzungstyp wird ein `ask` des Hooks OHNE den Founder aufgelöst — der
Befehl lief nach einer abgelehnten Freigabe-Anweisung in 3,4 s. Wer auflöst, steht in keinem
Protokoll (Sitzungsdatei und Diagnosedateien führen keine Berechtigungsentscheidung); Zeitmuster
und Modus passen zur Auto-Modus-Prüfung. ⚠️ **Der Hook ist in diesem Sitzungstyp also eine
Meldung, keine Sperre.** Im verschachtelten `claude -p` (Tabelle oben) wirkte dasselbe `ask`
als Sperre, weil dort niemand antworten kann — die beiden Messungen widersprechen sich nicht,
sie messen zwei verschiedene Umgebungen.

**Nicht gemessen:** ob die EINGEBAUTEN `permissions.ask`-Regeln (`Edit(/project.yml)` …) in dieser
Sitzung wirklich fragen — eine harmlose Probe wäre nur an den echten Dateien möglich.

**Offene Entscheidung (Founder):** soll der Hook im Auto-Modus `deny` statt `ask` liefern?
Dann ist er eine echte Sperre, aber „eine Aktion per Handy freigeben“ gibt es nicht mehr —
Freigabe hieße: du machst die Änderung selbst, oder die Sitzung läuft für diesen Schritt im
Modus `default`.

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
   in der Doku und ist hier NICHT gemessen (als root verweigert). `plan`, `acceptEdits` und
   `dontAsk` sind ungeprüft. In der Cloud-Sitzung, in der das gebaut wurde, wurde ein `ask`
   ohne den Founder aufgelöst (Grenze 6).
5. **Fehlalarme sind möglich:** ein `cd` in ein anderes Verzeichnis plus derselbe Dateiname,
   oder das Bearbeiten dieses Hooks selbst. Ein Fehlalarm kostet eine Rückfrage, nie einen
   stillen Durchlauf.
6. **Die Handy-Freigabe ist in der Cloud-Sitzung widerlegt** (Abschnitt „Handy-Probe“): ein
   `ask` des Hooks lief dort ohne dich durch. Bis zur Entscheidung oben gilt: der Hook MELDET in
   diesem Sitzungstyp, er sperrt nicht.

## Nebenbefund, nicht Teil dieses Auftrags

Der Block `safety` in `.claude/settings.json` ist ein eigener Schlüssel. Claude Code **setzt ihn
nicht durch**: Ein `echo`, das dort genannte Muster enthielt, lief im Test ungehindert. Er ist
Doku, keine Sperre. Er bleibt unverändert, weil das eine Entscheidung für dich ist.
