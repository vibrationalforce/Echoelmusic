# GSIMMW-Deep-Audit — Stand 2026-10-26

**GSIMMW = die Founder-Schreibweise für GSIDMMW** (`ECHOEL_VISION_2026-10-19.md` §3/§11). Gemessen am `main` `8c2e010` (2026-10-25), read-only über die GitHub-API; Vorgänger: `scratchpads/GSIDMMW_AUDIT_2026-10-16.md`. Messen statt zitieren; keine Zeilennummern (sie sind Daten); jede Aussage hängt an Datei oder Commit.

## Ergebnis in fünf Sätzen

1. Der Code ist dem Papier voraus: der Plan vom 25.10. (`PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md`, „die fertige App, die alles enthält", Wellen W1–W10) hat die Phasenordnung dieser Vision ersetzt — aber der Einstieg (`ECHOEL_VISION_2026-10-19.md`) trägt keinen Banner dazu.
2. Drei Register (Vision, `FEATURE_STATUS.md`, `ContentPipeline/CLAIMS.md` Studio-Block) hinken dem HEAD um 6–22 Tage hinterher; CLAIMS verbietet „overdub", während Build 10011 (`4ab8ba4`) Overdub ausliefert.
3. Das größte Risiko ist der fehlende Gerätebeleg: sieben Studio-Uploads (11.0.0), ~200 Härtungs-Reparaturen, alles „compile-only evidence"; die je Build definierten 5-Punkte-Gerätetests sind alle offen.
4. Die GSIDMMW-Pakete A–D2 sind gebaut und auf `main`, aber in keinem ausgelieferten Build belegbar (Alt-App eingefroren, LEGACY-Upload gesperrt); E–G bleiben offen; W10 des neuen Plans trägt sie.
5. Sicherheit und Deploy-Disziplin sind überdurchschnittlich (Secrets nur aus GitHub-Secrets, Team-ID-Srubbing, Grün-Gate vor Upload, LEGACY-Sperre); das äußere Risiko des öffentlichen Repos sind Founder-Prozessdaten (`decisions.csv` 1,17 MB / 1333 Zeilen, `FOUNDER_INBOX.md` 152 KB) bis zum geplanten Private-Gang (GM36 offen).

## Befunde

### B1 · Autoritätsdrift — BESTÄTIGT

`ECHOEL_VISION_2026-10-19.md` („CURRENT, Einstieg für jede Scope-Frage") sagt: Komponier-Hilfen nach 1.0 (§3), Video „ja, aber später, nicht vor Studio 1.0" (GM3), Körper erst P6/2028 (§8). `PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md` setzt auf Founder-Wort vom 25.10. W7 Video, W8 Stimme, W9 Gesicht+Bewegung, W10 Generative Intelligenz IN 1.0 und hebt #1301/#1302/#1304/#1305 (Commits `19017f2`, `405183b`). Die Konfliktregel (§1) löst das — aber der Einstieg kennt nur den ⛔-Banner vom 24.10 (Förderung). **Reparatur dieses Commits:** der 25.10-Banner oben in der Vision.

### B2 · Register-Drift — BESTÄTIGT

`FEATURE_STATUS.md` Stand 2026-10-04 (Alt-App, Build 2624) — Studio läuft bei 11.0.0, siebtem Upload. `CLAIMS.md` Studio-Block gemessen 2026-10-20 (`372727570`): sagt noch „'loop recording', 'overdub': gibt es nicht", während Build 10011 genau Overdub liefert („MIDI take records through the wrap … becomes one overdubbed clip", `4ab8ba4`). Genau der Defekt, vor dem CLAIMS selbst warnt: eine widerlegbare Begründung entwertet ein richtiges Verbot. Bildschirmtasten/Pads, Vier-Spur-Starter (10010) fehlen ebenfalls. **Reparatur:** Nachträge in CLAIMS und ein Alt-App-Banner in FEATURE_STATUS — als konkrete Formulierungen im PR beschrieben (diese Dateien sind wächterbewacht; die Sätze gehören in eine Sitzung mit lokalem `git grep`).

### B3 · Gerätebeleg null bei sieben Uploads — BESTÄTIGT, größtes Einzelrisiko

Jeder aktuelle Code-Commit endet „Compile-only evidence … Not device-verified"; `EchoelStudio/RELEASE` (siebter Upload): „nothing here is device-verified yet", mit fertiger 5-Punkte-Geräteliste pro Build. Die Merge-Vision vom 24.10 (Produktgesetz §1) setzt die Tore WIP 3 und „gerätegeprüfter Host-Load" voraus; „Store first" und „1.0 enthält alles" bedeuten: jede Welle hat einen offenen Geräte-Meilenstein vor sich, Rückstand mindestens sieben Build-Runden. **Empfehlung:** eine Geräte-Session pro TestFlight-Build, angefangen mit der Liste des siebten Uploads — die billigste Risikosenkung des ganzen Plans.

### B4 · GSIDMMW-Pakete A–G — TEILS BESTÄTIGT

Gemessen am `GSIDMMW_AUDIT_2026-10-16.md` und `FEATURE_STATUS.md` §1b: A erledigt; B, C1/C2a–c, D1/D2 gebaut (Gates zum Eintragszeitpunkt offen); E–G offen. Die Fähigkeitstabelle des Audits sagt für alle acht Fähigkeiten „Im Build: nein, Gerät: offen" — kein Eintrag seitdem hebt das. Die Alt-App (wo die Agent-Fähigkeiten gebaut sind) ist eingefroren; ihr Upload ist hinter dem Wort `LEGACY` gesperrt (`testflight.yml`, ultra-audit TF-1); der Studio-TestFlight weist die Agent-Fähigkeiten nicht nach. **Konsequenz:** die Tür zum Nordstern existiert im Code, aber kein Tester kann sie heute öffnen. W10 muss sie in einen Studio-Build tragen.

### B5 · Hygiene — BESTÄTIGT

~185 Branches, davon ~150 verlassene `claude/*`-Sessionen (teils aus dem Frühjahr). 3 offene PRs (#422–#424, Basis `1e7c64a` vom 14.10., mehrere große Merges hinter dem HEAD). Issue #418 „echomusic Crash Report" (externer Tester, 21.07., 2026-10-26 aktualisiert): offen. Root-Gewicht: `decisions.csv` 1,17 MB / 1333 Zeilen, `CLAUDE.md` 149 KB, `FOUNDER_INBOX.md` 152 KB, `inspiration.csv` 200 KB; F24 (7 markierte Root-Dateien, 24.10.) offen. **Empfehlung:** Session-Branches ohne PR löschen, PRs mergen/rebasen, #418 beantworten (`community-triage.yml` existiert), F24 abschließen.

### B6 · `main` und Öffentlichkeit — TEILS ERLEDIGT

Der Merge nach `main` ist erfolgt (`EchoelStudio/` auf `main`, gemessen 2026-10-26); `docs/privacy.html` nennt den Studio-Mikrofon-Zugriff korrekt („Echoel Studio asks for it the first time you arm an audio track") — F22 behoben. Der Warnsatz in Vision §4 („Der öffentliche `main`-Zweig zeigt keines von beiden Neuen") ist veraltet und wird in diesem Commit ersetzt. Derselbe Warnsatz steht noch in `CLAIMS.md` oben („ÖFFENTLICH ist es erst nach dem Merge").

### B7 · Sicherheit — KEINE BEFUNDE VON GEWICHT

`.mcp.json` (nur Env-Platzhalter `${FIRECRAWL_API_KEY}`, gepinnte Versionen), `wrangler.toml` (keine Tokens), Entitlements (dokumentiert, Keychain-Gruppe nach eigenem Audit entfernt), `studio-testflight.yml` (Signierung nur aus GitHub-Secrets, wartet auf das grüne Studio-Gate desselben Commits, prüft die ASC-Verarbeitung, Team-ID wird aus Fehlerlogs geschrubbt, dSYMs 90 Tage), `testflight.yml` (LEGACY-Wort-Sperre, `.deploy/release`-Trigger eingefroren), `.secrets.baseline` + `.pre-commit-config.yaml` vorhanden. Restrisiken (Abwägungen, keine Secrets): das öffentliche Repo trägt Founder-Prozessdaten bis zum Private-Gang (GM36 offen); #418 enthält Crash-Daten eines Fremden. Formale Secret-Scans der Workflow-Dateien waren aus der Ferne nicht ausführbar (Sichtprüfung); das lokale pre-commit + `.secrets.baseline` deckt das im Repo ab.

### B8 · Store-Blocker (W6) — OFFEN, Founder-Hand

Kein In-App-Kauf in App Store Connect (F-15), Preis, Paid-Apps-Vertrag, Screenshots/Review-Hinweis; GM36 (welche Plattformen, was kostet der Private-Gang); W4 wartet auf die eine `studio.yml`-Zeile (F25).

## Risiken, geordnet

| # | Risiko | Zustand |
|---|---|---|
| R1 | „1.0 enthält alles" (W1–W10) ohne Gerätebeleg; Store-Start droht auf Sicht | sicher, wenn keine Gerätesitzungen kommen |
| R2 | Register (Vision/CLAIMS/FEATURE_STATUS) widerlegen den Code | schon eingetreten (B1, B2) |
| R3 | Alt-App-Einfrieren + LEGACY-Sperre lassen GSIDMMW A–D ohne Tür | besteht heute (B4) |
| R4 | Repo-Gewicht & ~150 tote Branches; Public-Repo trägt Prozessdaten | besteht (B5) |
| R5 | Externer Crash-Report #418 unbeantwortet | besteht (B5) |

## Empfehlungen (priorisiert)

1. Geräte-Session für Build 10010/10011 — die 5-Punkte-Liste steht in `EchoelStudio/RELEASE`; danach je Upload eine Runde.
2. 25.10-Banner in der Vision + GM3/§8-Kontext (B1) — geschieht in diesem Commit.
3. CLAIMS-Studio-Block nachziehen (Overdub-Korrektur überfällig) + Alt-App-Banner in FEATURE_STATUS (B2) — Formulierungen im PR.
4. W10 so bauen, dass die Agent-Fähigkeiten in einen Studio-Build kommen (B4).
5. #418 beantworten; PRs 422–424 mergen; Session-Branches löschen; F24 abschließen (B5).
6. Veralteten Vision-§4-Warnsatz ersetzen (B6) — geschieht in diesem Commit.
7. W6-/GM36-Founder-Liste für den Store-Start (B8).

## Grenzen dieses Audits

Read-only aus der Ferne: kein lokales `git grep` (Textsuchen über die GitHub-Suche), kein Build, kein Gerätetest, kein App-Store-Connect-Zugriff. Zeilennummern bewusst nicht zitiert. Nächster sinnvoller Punkt: nach W1 oder dem achten Upload.

*Deep Audit, beauftragt vom Founder am 2026-10-26 („Deep Audith im Repo Echoelmusic GSIMMW").*
