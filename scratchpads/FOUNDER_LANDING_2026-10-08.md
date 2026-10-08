# Freigabe-Paket 2026-10-08 — drei Commits, die nur du freigeben kannst

**Kurz:** Drei fertige Patches liegen in `scratchpads/`. Jeder wird genau ein Commit. Jeder berührt
eine Datei, die nur du ändern darfst (`Info.plist` · `project.yml` · der Auto-Merge-Workflow).
Der Sicherheits-Hook dieser Sitzung lehnt diese Commits im Auto-Modus ab — absichtlich. Du hast
zwei Wege; Weg A ist der einfachste.

## Was drin ist

| Reihenfolge | Patch | Commit-Text | Was es tut | Gesperrte Datei | Größe |
|---|---|---|---|---|---|
| 1 | `LANDING_P3_auto_merge_310.patch` | `LANDING_P3_commit_message.txt` | Auto-Merge: eine leere oder fehlgeschlagene API-Antwort wird wiederholt statt als „nie gelaufen" gelesen (#310) | `.github/workflows/auto-merge-claude.yml` | 1 Datei, +36 / −6 |
| 2 | `LANDING_P1_E10-1_microphone.patch` | `LANDING_P1_commit_message.txt` | Mikrofon-Aufnahme auf eine Audiospur (E10-1), mit allen Review-Korrekturen und den Website-Wahrheiten für 10.79.492 | `Resources/iOS/Info.plist` (ein Schlüssel: Mikrofon-Text) | 31 Dateien, +1186 / −287 |
| 3 | `LANDING_P2_B2_broadcast.patch` | `LANDING_P2_commit_message.txt` | Livestream RTMP/RTMPS: HaishinKit eingebunden (B2), auf den Commit des Tags 2.2.5 gepinnt | `project.yml` (dazu `Package.swift`, frei) | 30 Dateien, +823 / −120 |

**Reihenfolge einhalten: 1 → 2 → 3.** Patch 3 baut auf Patch 2 auf (sieben gemeinsame Dateien).
Patch 1 ist unabhängig, kommt aber zuerst, damit der reparierte Auto-Merge die beiden anderen
nicht wieder abweist.

Geprüft am 2026-10-08 auf dem Stand `4db2629` (Zweig `claude/echoelmusic-review-optimize-u5jjpd`):
alle drei nacheinander mit `git apply --index` sauber; der Ergebnis-Baum ist identisch mit dem
Prüfbaum, aus dem die Patches erzeugt wurden.

Prüfsummen (`sha256sum`, erste 16 Zeichen): P1 `b9752bf0021debcb` · P2 `d985c51face1e49c` ·
P3 `14252cb52c74cd1c`.

## Weg A — in dieser Sitzung (empfohlen)

1. Den Modus der Sitzung von **Auto** auf **Standard** stellen (der Modus-Umschalter der Claude-App).
2. Mir schreiben: **„Standard ist an, leg los."**
3. Ich mache dann alles: Patches anwenden, committen, pushen, die Gates lesen, die TestFlight-Bumps.
   Bei jedem der drei Commits fragt der Hook **einmal** nach, weil eine gesperrte Datei dabei ist —
   da antwortest du mit **Erlauben**.
4. Danach kannst du wieder auf Auto stellen.

Ablauf in Weg A: Patch 1 + 2 → Push → Gates (`Xcode Compile Check` grün, CI/CD-Schritt
`Build for Testing` grün) → Bump **10.79.493** (Mikrofon) → Patch 3 → Push → Gates → Bump
**10.79.494** (Livestream). Zwei Builds, damit ein Gerätebefund klar einem der beiden gehört.

## Weg B — selbst im Terminal am Mac

```bash
cd <dein Klon von Echoelmusic>
git fetch origin claude/echoelmusic-review-optimize-u5jjpd
git checkout claude/echoelmusic-review-optimize-u5jjpd
git pull --ff-only origin claude/echoelmusic-review-optimize-u5jjpd
git status --short        # muss LEER sein, sonst erst aufräumen

git apply --index scratchpads/LANDING_P3_auto_merge_310.patch
git commit -F scratchpads/LANDING_P3_commit_message.txt

git apply --index scratchpads/LANDING_P1_E10-1_microphone.patch
git commit -F scratchpads/LANDING_P1_commit_message.txt

git apply --index scratchpads/LANDING_P2_B2_broadcast.patch
git commit -F scratchpads/LANDING_P2_commit_message.txt

git push origin claude/echoelmusic-review-optimize-u5jjpd
```

Wenn `git apply` etwas ablehnt: **nichts erzwingen**, mir den Fehlertext schicken. Nach dem Push
lese ich die Gates und mache einen Bump (**10.79.493** mit beidem) — oder zwei, wenn du „zwei Builds"
sagst.

## Was ich NICHT tue

- Die Sperre umgehen: kein `git merge`, `cherry-pick` oder `push` als Umweg um den Hook; keine
  Änderung an `.github/workflows/**`, `project.yml`, `Info.plist` ohne deine Freigabe im Standard-Modus.
- Einen Bump ohne neuen Code (das wäre ein doppelter Build, #1151).
- Nach außen behaupten, dass Aufnahme oder Livestream funktionieren, bevor du es am Gerät gesehen
  hast (Geräte-Bitten G9 und G10 in `docs/dev/FOUNDER_INBOX.md`).

## Sicherheit — geprüft am 2026-10-08

- **Keine neuen Netzwerk-Aufrufe** außerhalb von `Sync/` und `Stream/`. Die Aufnahme bleibt eine Datei
  auf dem Gerät; nichts lädt sie hoch. Keine Geheimnisse, Tokens oder Schlüssel im Diff.
- **Der Stream-Key kommt nie ins Log:** die Konsolen-Ausgabe der Stream-Bibliothek ist stumm
  geschaltet, bevor eine Verbindung existiert.
- **HaishinKit ist auf den Commit gepinnt** (`dc880cb540b8feeb98f64e8b7dcfaaf320b6b2bd`, aus dem Tag
  2.2.5 in einem schreibgeschützten Klon abgeleitet). Ein Tag kann verschoben werden, ein Commit
  nicht. Logboard bleibt exakt 2.6.0 (HaishinKit verlangt eine 2.6.x-Version). Nur die RTMP-Produkte;
  die Binär-Pakete für SRT/WebRTC werden nicht verlinkt.
- **Info.plist:** genau ein neuer Schlüssel (Mikrofon-Text). Keine Entitlements, kein File-Sharing,
  keine Hintergrund-Modi geändert.
- **Wächter, hier nachgerechnet** (ohne Swift-Toolchain, als Python-Abschrift): die Pin-Zeilen in
  `Package.swift` und `project.yml` stimmen mit den drei Wächtern überein · der Text-Katalog ist
  gültig, jeder Schlüssel hat sein Literal · `CLAUDE.md` 148 976 B (Decke 150 000) ·
  `scripts/check-infoplist.sh` PASSED · `python3 scripts/doctor.py --section D` 0 kritisch ·
  Auto-Merge-Simulation 4/4 Szenarien richtig.
- **Was nur die Gates entscheiden:** ob alles kompiliert. **Was nur das Gerät entscheidet:** ob die
  Aufnahme hörbar ist (G9) und ob ein Server den Stream annimmt (G10).

## Danach (mache ich, ohne weitere Frage)

Gates lesen → Bump(s) nach `.deploy/release`-Gesetz (Prüf-Bitten per `scripts/founder-verify.py --since`)
→ `FOUNDER_INBOX` F2 als erledigt eintragen → Ledger und Sitzungsprotokoll.

## Herkunft

Ersetzt `E10-1_RELEASE_PREP_2026-10-07.md` §4 (ein Patch, nur E10-1). Die alten Dateien
`E10-1_microphone_recording.patch`, `E10-1_review_fixes.patch`, `E10-1_commit_message.txt`,
`B2_broadcast_haishinkit.patch` und `AUTO_MERGE_310_proposed.patch` sind in diesem Paket
aufgegangen und gelöscht; ihre Geschichte steht in Git.
