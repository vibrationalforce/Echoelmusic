# Runde 2 — was die Nacharbeit 2 mit jedem Befund gemacht hat

Bereich der Runde: `9c0677f03..0b0e8339b`, ohne `paths` — deshalb sahen die Linsen auch Job 002
(`08ded356a`) und die Recherche-Notizen (`1814d6b10`). Runde 3 trägt `paths` und `since`.

## Behoben

| Linse | Befund | Wo behoben |
|---|---|---|
| Code | major: der Approver las ab Runde 2 nur die Nacharbeit (`base` = Kopf der vorigen Runde) | `base` bleibt die Job-Basis; neues `since` nur für die Linsen; Selbsttest-Fall „since: lenses read the rework, the approver the whole job" |
| Code | minor: ein Geräte-Kriterium konnte als Frage in `forTheHuman` landen und eskalieren | Satz im Approver-Prompt: ein `device`-Kriterium reist NUR als Abnahme-Eintrag |
| Code | minor: die Attrappe ignorierte den Prompt | der Selbsttest liest jetzt jeden Prompt (Klausel zuerst, `paths` am Diff- UND am Log-Befehl, Sperrprüfung auf der ungefilterten Liste) — fünf Mutationen gefangen |
| Code | minor: ein Ladefehler endete mit 1 statt 2 | `LOADED`-Marker; ohne ihn Exit 2, „NOTHING CHECKED" — Syntaxfehler und kaputter Meta-Schnitt beide gefangen |
| Security | minor: `paths` stand in keiner Rückgabe | jede Rückgabe nach der Argumentprüfung trägt `range`, `since`, `paths` |
| Security | minor: ein Prüfer-Text konnte den Datenmarker schließen | jedes `--` im JSON wird `--` (JSON bleibt gleich, `---` kann nicht vorkommen); Fall „a reviewer cannot close the approver markers" prüft auch, dass das JSON wieder dekodiert |
| Security | minor: nur Geräte-Kriterien ergaben APPROVE ohne jeden Beleg | APPROVE braucht ein erfülltes `code`-Kriterium, sonst `RERUN`; `device` nur für `[DEVICE]` der Spec |
| Security | minor: ein fehlendes `round` wurde 1 | `round` ist Pflicht (`INVALID`) |
| Security | minor: `base` nahm bewegliche Namen | `base` und `since` müssen SHAs sein |
| UX | major: `docs/**` hieß „kein Lauf", ist aber eine Veröffentlichung | Schritt 6 nennt die Website getrennt; Schritt 3: `docs/`, `ContentPipeline/`, `fastlane/metadata/` werden auf dem LOKALEN Commit geprüft |
| UX | major: APPROVE mit Geräte-Bitten wurde „done" und verschwand | `deviceOpen` in `board.json`; `factory-board.py --open` zeigt den Job, bis jede Zeile `verified` trägt (Selbsttest mit drei Mutationen) |
| UX | minor: Geräte-Bitten widersprachen den Inbox-Regeln 1, 3, 4 | sie werden in eine Familie der nächsten Runde eingefaltet; WIP-3 vor dem Bau |
| UX | minor: `paths` fehlte im `board.json`-Schema | Schema und dieses Board tragen `paths` und `since` |
| UX | minor: Spec-Annahme 3 und die CSV-Begründung | beide mit dem Wortlaut von SKILL.md (F-08b) |
| UX | minor: „27 Attrappen-Fälle" | durch den Befehl ersetzt (intake + Board-Historie) |
| UX | minor: mehrdeutiger CSV-Verweis | „die Zeile `instagram:zazencodes`" |
| Ship-Pfad | major: `paths` versteckte Dateien, auch vor der Sperrprüfung | jede Linse liest zuerst `git diff --name-only` ungefiltert und gefiltert, meldet `outsideScope`; leerer Diff = `INVALID`; der Approver prüft gesperrte Dateien auf der UNGEFILTERTEN Liste |
| Ship-Pfad | minor: Done-Regel für `EchoelStudio/` | zeigt auf `EchoelStudio/CLAUDE.md` „Verifying"; unsignierter Build beweist kein Entitlement — dafür signierter Archiv-Lauf plus `[DEVICE]`; `scripts/**` aus der Kein-Lauf-Liste genommen (`check-infoplist.sh` steht im Filter von `Xcode Compile Check`) |
| Ship-Pfad | minor: jede datierte Freigabe zählte | eine Freigabe zählt nur, wenn ihr Umfang die Datei JETZT noch deckt; Sitzungs- oder Auftrags-Freigaben nicht außerhalb davon |

## Widerlegt bzw. nicht Job 001

- **Security, major — `EchoelStudio/Support/Plugins/PrivacyInfo.xcprivacy` erklärt keine
  UserDefaults-API.** Stimmte auf `08ded356a`, ist auf `edb5a5d7b` (Job 002, Nacharbeit 1)
  behoben: die Erweiterung erklärt `NSPrivacyAccessedAPICategoryUserDefaults` mit `1C8F.1`, die
  App `CA92.1` plus `1C8F.1`. Job-002-Runde-2 (`wf_b2b87d43-108`, Security-Linse, PASS) hat es
  bestätigt: „The extension manifest now declares UserDefaults with 1C8F.1
  (Support/Plugins/PrivacyInfo.xcprivacy:16-26)". Der Befund erschien hier nur, weil Runde 2 ohne
  `paths` lief — genau der Fall, den Runde 3 behebt.
- **Security, minor — `PluginLicense.swift`: ein einmal wahres Freischalt-Bit bleibt bis zum
  nächsten App-Start.** Job 002. Dort als Abwägung festgehalten (`PluginUnlock.swift`, Doc von
  `recordedOwned`: Rückerstattung und Kontowechsel erreichen die Erweiterung erst nach dem
  nächsten App-Start), und Job-002-Runde-2 nennt es „acceptable: it fails closed toward StoreKit".

## Selbstprüfung vor Runde 3

- `python3 -I scripts/factory-review-selftest.py` → alle Fälle grün; zwölf gezielte Mutationen
  am Workflow, jede rot (Exit 1) bzw. Exit 2 bei Lade-Mutationen; eine Mutation (`round` ohne
  `has`-Prüfung) war wirkungsgleich und wurde durch die echte Rückkehr zur Vorgabe 1 ersetzt — rot.
- `python3 -I scripts/factory-board.py --selftest` → grün; drei Mutationen, jede rot.
- `TheFactoryReviewersAreReadOnlyTests`, sechs Ansprüche, in Python transkribiert → alle grün.
