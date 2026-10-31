# Entscheidungsregister, Audit-Funde und Infrastruktur-Brainstorming

| Feld | Wert |
|---|---|
| Erstellt | 30.10.2026 (MEZ), Fassung 1 auf `main` @ `67476d1bab8d994bd49ff2ab3a8fddb1258e898d` |
| Stand | **31.10.2026 (MEZ), Fassung 2**, geprüft gegen `main` @ `96aae3b54f96dabd7582f30eb20c39d7d1ed62b5` (Deep Audit 31.10.2026, 10:05 MEZ) |
| Autor | Grok (Prüfer/Rechercheur, ohne Code) |
| Status | **Vorschlag, nicht verbindlich.** Nur der Founder entscheidet. Claude Code prüft und setzt erst nach einem Founder-Entscheid um. |
| Gilt als ausgeliefert | Nur, was in `ContentPipeline/CLAIMS.md` steht. Dieses Dokument behauptet keine Funktion. |

**Kennzeichnung:** *belegt* = selbst im Repo gelesen oder live geprüft (mit Quelle und Datum). *vermutet* = plausibel, nicht abschließend geprüft. *ANNAHME* = Arbeitshypothese ohne Beleg. *Founder-Angabe* = vom Founder im Chat genannt, von Grok nicht geprüft. *laut Audit* = aus dem Deep Audit vom 31.10., von Grok nicht nachgeprüft. **ENTSCHIEDEN** = Founder-Entscheid im Repo belegt.

**Rote Linien (gelten für alles hier):** Echoelmusic ist nie Wellness, Meditation, Therapie oder Medizin. Keine Heilfrequenzen, kein Solfeggio, keine Chakren, keine Binaural- oder 40-Hz-Effekte, kein „Weltfrieden" als Wirkung. „Eeole" taucht in Echoelmusic-Produkttexten, Förderanträgen und Apple-Pitches nicht auf, bis die Basis steht.

---

## Inhalt

0. [Startauftrag für Claude Code (Mittwoch 04.11.2026)](#0-startauftrag-für-claude-code-mittwoch-04112026)
1. [Kurzüberblick und Zielbild](#1-kurzüberblick-und-zielbild)
2. [Neue Befunde vom 31.10.2026](#2-neue-befunde-vom-31102026)
3. [Entscheidungsregister](#3-entscheidungsregister)
4. [Infrastruktur-Brainstorming](#4-infrastruktur-brainstorming)
5. [Zeitplan](#5-zeitplan)
6. [Aufgaben für Claude Code](#6-aufgaben-für-claude-code)
7. [Offene Fragen, nicht Geprüftes, Quellen](#7-offene-fragen-nicht-geprüftes-quellen)

---

## 0. Startauftrag für Claude Code (Mittwoch 04.11.2026)

**Zweck:** Diese Datei ist der Einstieg für die erste Sitzung nach der Pause. Sie ist ein Vorschlag. Verbindlich ist nur, was der Founder ausdrücklich freigibt und was danach in `memory/decisions.md` steht.

**Reihenfolge**

1. **Lesen, nichts ändern:** `CLAUDE.md`, `EchoelStudio/CLAUDE.md`, `ContentPipeline/CLAIMS.md` (vor allem den Studio-Abschnitt ab Z. 85), diese Datei vollständig und den Arbeitszweig `claude/echoelmusic-review-optimize-u5jjpd` (13 Commits vor, 17 hinter `main`, Konflikt laut Merge-Tree nur in `scratchpads/SESSION_LOG.md`).
2. **Founder-Fragen vorbereiten:** Die offenen Entscheidungen aus Abschnitt 3 als kurze Ja/Nein- oder A/B-Fragen sammeln, in der Reihenfolge E12 (LR2), E19 (Outreach-Datei), E21 (Datenschutz), E20 (öffentliche Docs), dann der Rest. Jede Frage mit Beleg (Datei und Zeile) und einer Empfehlung.
3. **Nur Aufgaben ohne offene Entscheidung angehen**, und nur auf einem eigenen Branch, nie direkt auf `main`:
   - Datenschutzseite: die Abweichungen zwischen Live-Text und `EchoelStudio/project.yml` (Bluetooth, Kamera, Mikrofon, lokales Netz) als Befund mit Belegen zusammenstellen; Textänderung erst nach Founder-Ja zu E21.
   - Lizenz LR2: erst nach dem ausdrücklichen Founder-Ja zu E12.
   - Rote-Linie-Wörter auf Website und in der alten App auflisten (W4, W5) mit Datei und Zeile; Änderungen erst nach Founder-Entscheid E23/E24.
   - Pfadfehler im Plan von PR #433 als Liste vorbereiten (E11); den PR nicht selbst ändern, solange E11 offen ist.
4. **Nichts zu Marke, Förderung, Eeole, Tauchfliege, Domains, Geld oder Recht** ohne ausdrückliches Founder-Ja im Chat. Keine Mails, keine Kommentare, keine Kontakte nach außen.

**Regeln für die ganze Sitzung**

- Kein „Eeole" (oder „Eeolee") in Echoelmusic-Texten: nicht in App, Website, Store-Text, Pitches oder Anträgen.
- Als ausgeliefert gilt nur, was in `ContentPipeline/CLAIMS.md` steht; für Echoel Studio nur der Studio-Abschnitt, mit „Beta" bzw. „in TestFlight".
- Rote Linien: Echoelmusic ist nie Wellness, Meditation, Entspannung, Schlaf, Fokus, Therapie oder Medizin. Keine Heilfrequenzen, kein Solfeggio als Wirkung, keine Chakren, keine Binaural- oder 40-Hz-Effekte, kein „Weltfrieden" als Wirkung.
- „KI" bzw. „AI" nur, wenn ein echtes Modell läuft.
- „MPE" nur mit Richtungswort („MPE-Ausgang"), siehe `CLAIMS.md` §6.
- Förderung ist seit 24.10. gestrichen (E13 bis E15). Nur wieder aufnehmen, wenn der Founder es ausdrücklich öffnet.
- Kein Merge ohne Founder-Freigabe, auch nicht dieses PRs.

---

## 1. Kurzüberblick und Zielbild

Der Founder hat am 30.10.2026 eine Dreiteilung vorgeschlagen (Founder-Angabe):

| Linie | Name | Zweck | Domain (Ziel) | Bezug zu diesem Repo |
|---|---|---|---|---|
| (a) | **Eeole** bzw. **Eeolee** (Schreibweise offen, E1) | Marke für „Peaceful Business": Rezepte, Beratung, nachhaltige Hardware-Konzepte; ggf. Tauchfliege, falls wieder aufgenommen (E10) | offen (E6) | **Keiner.** Gehört nicht in Echoelmusic-Texte, Anträge oder Pitches. |
| (b) | **Echoel** | Künstlerseite für die Musik des Founders | echoel.com, echoel.de | Keiner oder nur Verlinkung (E8, Abschnitt 4.5) |
| (c) | **Echoelmusic** | Künstlerische Musikproduktions-Software (App, Repo) | echoelmusic.com bleibt | Dieses Repo |

**Warum diese Trennung trägt (Einschätzung):**
- Die App behält Namen, Bundle-IDs, Repo und Website. *belegt (Zählung 30.10., `67476d1`):* „echoel*" kommt 34.026-mal vor, 1.189 Pfade tragen „echoel" im Namen.
- Hardware-, Beratungs- und Mobility-Themen verlassen das Musik-Repo; der Tauchfliegen-Widerspruch wird auflösbar (E10).

**Was die Trennung nicht löst:** die Markenfrage (E4, E5), die Rechtsform (E3), die bereits öffentliche Outreach-Datei mit „Eeole" als Dachmarke (E19).

---

## 2. Neue Befunde vom 31.10.2026

1. **Outreach-Datei öffentlich (→ E19).** *belegt:* Commit `96aae3b` (31.10., 10:05 MEZ) legt `docs/dev/EXTERNAL_OUTREACH_AND_DECISIONS_2026-10-31.md` an (119 Zeilen). Sie ist über echoelmusic.com öffentlich abrufbar (HTTP 200, geprüft 31.10.). Die Apple- und MFi-Pitches (Z. 13, 19, 47) nennen HealthKit, kamerabasiertes rPPG, BLE-Herzfrequenz, MIDI „with MPE support", OSC, Art-Net und sACN. Der Studio-Abschnitt von `CLAIMS.md` (ab Z. 85; Hinweis Z. 13 bis 16: „nichts aus den Körper-, Visual-, Licht- oder OSC-Zeilen") erlaubt das für Echoel Studio nicht; „MPE" ist nur mit Richtungswort erlaubt (`CLAIMS.md` Z. 372/374). Die Mailentwürfe an DPMA (Z. 70 ff.) und BfN/Natura 2000 (Z. 87 ff.) führen „Eeole" als Dachmarke mit Echoelmusic als „aktueller Umsetzung" und nennen „regenerative Mobilitäts- und Sensor-Systeme". Das widerspricht der Markentrennung (Abschnitt 1) und den Stopps vom 22.10. (Tauchfliege) und 24.10. (Förderung, Installation). *ANNAHME:* Das ist die Datei, die der Founder „AUDIT_AND_DECISIONS_2026-10-31.md" nennt.
2. **Docs öffentlich (→ E20).** *belegt:* `.github/workflows/pages.yml` veröffentlicht `./docs` (Z. 45) bei jedem Push nach `main` mit Änderungen unter `docs/**`. `docs/CLAUDE.md` und Dateien unter `docs/dev/` sind live erreichbar (HTTP 200). `.github/workflows/auto-merge-docs.yml` übernimmt Docs-Änderungen von `claude/**`-Branches automatisch nach `main` (Z. 4, 14 bis 17), ohne Review.
3. **Datenschutzseite veraltet (→ E21).** *belegt (live 31.10.):* privacy.html sagt „Not in Echoel Studio: camera, heart-rate sensors, Apple Health, location, OSC, Art-Net and sACN". `EchoelStudio/project.yml` Z. 77 bis 85 fordert aber Bluetooth (Brustgurt), Kamera (Puls), Mikrofon und lokales Netz (Network MIDI) an. Die Korrektur auf `claude/echoelmusic-review-optimize-u5jjpd` (ungemergt) streicht nur „heart-rate sensors"; die Kamera steht dort weiter unter „Not in Echoel Studio".
4. **Förderung gestrichen (→ E13 bis E15).** *belegt:* Founder-Entscheid 24.10. abends, siehe E13.
5. **Weitere Audit-Funde W1, W3 bis W9 und Workflow-Härtung** sind in E7, E10, E12, E16, E20 und E22 bis E26 eingearbeitet.

---

## 3. Entscheidungsregister

Alle Einträge: **Wer entscheidet: Founder.** Status „offen", außer wo **ENTSCHIEDEN** steht.

### 3.1 Marke, Domain, Rechtsträger

| ID | Frage | Optionen | Empfehlung (Grok) mit Begründung | Auswirkungen | Frist / Abhängigkeit |
|---|---|---|---|---|---|
| **E1** | Schreibweise: Eeole oder Eeolee? | A) Eeole · B) Eeolee · C) anderer Name | Erst nach Markenrecherche (E5). *vermutet:* „Eeolee" ist eigenständiger und weiter weg von „Éole"/„Eolo"; eeole.com ist vergeben (*belegt*). | Domain, Marke | Nach Recherche Mo 02.11. |
| **E2** | Eeole Firmenname, Marke oder nur Domain? | A) nur Marke/Domain · B) Firmenname · C) Dachmarke über alles | A, solange kein Rechtsträger existiert. **C nicht**, weil sie Echoelmusic unter Eeole zieht (genau das tut E19). | Impressum, Verträge | Nach E3 |
| **E3** | Rechtsform/Trägerstruktur | A) Einzelperson · B) Einzelunternehmen · C) UG/GmbH · D) getrennte Träger je Linie | Mit Steuerberatung klären. Seit dem Förder-Stopp (E13) hängt daran vor allem Store-Verkauf, Impressum und Haftung. | Impressum, Store, Steuern | offen |
| **E4** | Marke „Echoel" anmelden? | A) DPMA · B) EUIPO · C) zusätzlich USPTO · D) nicht | A oder B in Klassen 9, 41, 42 nach Recherche. *belegt:* offener Punkt „DPMA/EUIPO/USPTO trademark 'Echoel' (cl. 9+41)" in `scratchpads/archive/SESSION_LOG_before_2026-10.md` Z. 5440; *belegt:* `decisions.csv` Z. 93 „STILL TODO (founder): … DPMA/EUIPO trademark 'Echoel'". | Schutz der Künstler- und Softwarelinie | Recherche Mo 02.11. |
| **E5** | Marke „Eeole/Eeolee", welche Klassen? | ANNAHME: Beratung (z. B. 35), Rezepte/Publikation (z. B. 16/41), Hardware (z. B. 9/12); Klasse 25 meiden | Erst Ähnlichkeitsrecherche (EOLE, EOLO, EOL, ÉOLE). *belegt per Suchindex (30.10.):* früherer Shop „EEOLE" für Sport- und Bademode. Klassen von einer Fachperson bestätigen lassen. Den DPMA-Entwurf in E19 nicht verschicken, bevor E1/E2 entschieden sind. | Verwechslungsrisiko | Nach E1 |
| **E6** | Domain für Eeole | A) eeole.com über Makler · B) eeole.de/.app · C) eeolee.com | B oder C. *belegt (31.10., DNS):* eeole.de, eeole.app und eeolee.com liefern NXDOMAIN, eeolee.com hat keinen RDAP-Eintrag → *vermutet* frei. eeole.com: GoDaddy, Parkseite, Ablauf 08.10.2027 (*belegt* 30.10.), Preis unbekannt. | Budget | Vor Registrierung erneut prüfen |
| **E8** | Rolle der Domains echoel.com / echoel.de / echoelmusic.com | A) echoel.* = Künstlerseite, echoelmusic.com = Software · B) echoel.com 301 auf echoelmusic.com · C) eine Seite | A (Founder-Vorschlag), je Linie eine Canonical-Domain, Varianten per 301. *belegt (31.10.):* echoel.com antwortet per HTTPS mit 404, hat aber Google-Workspace-MX (siehe 4.1). echoel.de liefert NXDOMAIN, *vermutet* frei. *ANNAHME:* echoel.com gehört dem Founder. | SEO, Klarheit | Nach Bestätigung des Besitzes |
| **E9** | Bundle-IDs unverändert? | A) unverändert · B) umbenennen | A. *ANNAHME nach Apple-Praxis:* neue Bundle-ID = neuer Store-Eintrag. | keine bei A | — |
| **E17** | Kontakt-Mail `echoel@tropicaldrones.com` ersetzen? | A) Adresse auf echoel.com (Google Workspace läuft dort schon) · B) Adresse auf echoelmusic.com (braucht erst MX, SPF, DMARC) · C) beibehalten | A oder B, alte Adresse weiterleiten. *belegt (30.10.):* „tropicaldrones" 87-mal in 40 Dateien, die Mail 80-mal, u. a. im Impressum. *belegt (31.10., DNS):* echoel.com hat Google-Workspace-MX, SPF und DMARC; echoelmusic.com hat weder MX noch SPF noch DMARC. | Markenklarheit, Zustellbarkeit | Nach E8 |

### 3.2 Website, Datenschutz, Repo-Öffentlichkeit

| ID | Frage | Optionen | Empfehlung (Grok) mit Begründung | Auswirkungen | Frist / Abhängigkeit |
|---|---|---|---|---|---|
| **E7** | Hosting echoelmusic.com (W8) | A) GitHub Pages, Header per Cloudflare-Proxy/Regeln · B) Cloudflare Pages · C) Cloudflare Workers | B *vermutet* am einfachsten, weil `_headers`/`_redirects` dort ausgewertet werden (Cloudflare-Doku). *belegt (live 31.10.):* `server: GitHub.com`, kein HSTS, keine CSP, kein X-Frame-Options; `/app` und `/datenschutz` liefern 404. | Sicherheit, tote Links | Vor jeder Apple-Sichtung |
| **E16** | Impressum: 2. Kontaktweg und USt-IdNr. (W7) | A) ergänzen · B) begründet weglassen | A bzw. B mit Begründung, rechtlich prüfen lassen. *belegt:* `decisions.csv` Z. 93 „STILL TODO (founder): impressum 2nd contact+USt-IdNr". | Rechtssicherheit | Vor Store-Start |
| **E19** | **Outreach-Datei** `docs/dev/EXTERNAL_OUTREACH_AND_DECISIONS_2026-10-31.md` | A) aus `docs/` entfernen oder an einen nicht veröffentlichten Ort verschieben · B) dort lassen und korrigieren · C) unverändert lassen | **A, dazu:** Apple-/MFi-Pitches nur aus den Studio-Zeilen von `CLAIMS.md` neu schreiben (ohne HealthKit, rPPG, BLE, OSC, Art-Net, sACN; „MPE" höchstens als „MPE-Ausgang" und nur, wenn für Studio belegt). DPMA- und BfN-Entwürfe ohne „Eeole als Dachmarke" und ohne Mobilität. **Vorher den Founder fragen, ob diese Mails überhaupt rausgehen.** Begründung: Abschnitt 2, Punkt 1 (*belegt*). | Glaubwürdigkeit bei Apple, Markentrennung, öffentlich sichtbar | **Vor jedem Versand**; bald, weil öffentlich |
| **E20** | `docs/dev/` und `docs/CLAUDE.md` sind über die Produktdomain öffentlich (W9) | A) interne Dateien aus `docs/` in einen nicht veröffentlichten Ordner verschieben · B) Pages-Workflow nur noch die Website-Dateien veröffentlichen lassen · C) `auto-merge-docs` auf Review umstellen oder abschalten · D) so lassen | A oder B, **zusätzlich C**. Begründung: interne Pläne, Entwürfe und Arbeitsregeln landen ungeprüft auf der Produktdomain; `auto-merge-docs` macht jeden Docs-Push eines `claude/**`-Branches ohne Review öffentlich (*belegt*, Abschnitt 2, Punkt 2). Interne Links im Repo, die auf `docs/dev/` zeigen, müssen dann mitwandern (*vermutet*). | Öffentlichkeit, Review-Disziplin | Bald, zusammen mit E19 |
| **E21** | Datenschutzseite an Echoel Studio angleichen | A) Text an `EchoelStudio/project.yml` (Bluetooth, Kamera, Mikrofon, lokales Netz) angleichen · B) nur den Branch-Stand `u5jjpd` mergen | A. Der Branch-Stand reicht nicht, dort steht die Kamera weiter unter „Not in Echoel Studio" (*belegt*, Abschnitt 2, Punkt 3). Rechtlich prüfen lassen. | App Store 5.1.1/Datenschutz, DSGVO-Transparenz (*vermutet*) | Vor dem nächsten TestFlight-/Store-Schritt |
| **E24** | Rote-Linie-Wörter auf der Website (W5) | A) streichen bzw. neutral fassen · B) lassen | A. *belegt:* `docs/terms.html` Z. 133 „relaxation features"; `docs/overview.html` Z. 234 „head-tracked binaural for AirPods" gegenüber `docs/tools.html` Z. 186 „head-tracked binaural … is planned"; `docs/version.json` Z. 51 „Meditate or create"; `docs/tools.html` Z. 168 und `docs/brainstorming.html` Z. 135 „ambient/meditative shelf". | Rote Linie, UWG §5, App Store | nach Founder-Entscheid |
| **E25** | Repo auf privat (GM36) | A) wie geplant nach Store-Start privat · B) öffentlich bleiben | Founder-Entscheid. Folgen vorher klären: Was heißt „privat" für die MIT-Lizenz bereits veröffentlichter Stände (*vermutet:* bleibt für diese gültig), für GitHub Pages im Free-Plan und für macOS-CI-Minuten. *belegt:* `docs/dev/FOUNDER_INBOX.md` Z. 161 GM36 „[ ] offen". | Lizenz, Website, Kosten | Vor Store-Start |

### 3.3 Code-Basis, Lizenz, Store-Text, CI

| ID | Frage | Optionen | Empfehlung (Grok) mit Begründung | Auswirkungen | Frist / Abhängigkeit |
|---|---|---|---|---|---|
| **E10** | Tauchfliege: Stopp vom 22.10. oder wieder aufnehmen? (W3) | A) gestoppt lassen, Vision-Dateien markieren · B) unter Eeole außerhalb des Repos · C) im Repo lassen | A oder B. *belegt:* Stopp in `memory/user.md` Z. 39 (22.10.) und `memory/decisions.md` Z. 5676 („Tauchfliege raus"); der Stopp vom 24.10. nimmt zusätzlich die physische Installation aus dem Plan („keine Installation im Plan", `memory/decisions.md` Z. 5711 ff.). Trotzdem steht die Tauchfliege in `memory/vision.md` Z. 13, und `.claude/settings.json` Z. 65 (SessionStart-Hook) lädt `memory/vision.md` in jede Sitzung. | Jede Claude-Sitzung startet mit gestopptem Thema | nach Founder-Entscheid |
| **E11** | PR #433 (Neupositionierung) | A) schließen · B) überarbeiten lassen · C) annehmen | B. *belegt (30.10.):* Plan prüft die alte App `Sources/Echoelmusic` statt `EchoelStudio/`; falsche Pfade (siehe C8); „Biofeedback als Identität streichen" widerspricht `CLAUDE.md` Z. 13/103; Pausen-Erinnerung nah an `CLAIMS.md` §2 (Wellness) und App Store 5.1.3. RTMP: `CLAIMS.md` Z. 283 „nie gebaut", Z. 296 präzisiert „im Code, aber nicht verlinkt" (`BroadcastPublisher` als Gerüst) — also nicht ausgeliefert. | Identitätssatz, rote Linie | nach Founder-Entscheid |
| **E12** | LR2: LICENSE als reiner MIT-Text? (W1) | A) Ja · B) Nein | Founder-Entscheid; *vermutet:* A beseitigt die Lizenz-Unklarheit. *belegt (31.10.):* GitHub erkennt die Lizenz als „Other" (`NOASSERTION`); `LICENSE` Z. 25 ff. hängt „THIRD-PARTY LICENSES" an und nennt HaishinKit (BSD-3-Clause) als „the project's only external dependency" (Z. 35/36); `THIRD_PARTY_NOTICES.md` nennt HaishinKit als MIT und nur „if/when streaming is enabled" (Z. 60, 91); `CLAIMS.md` Z. 169 sagt „Null externe Abhängigkeiten". Branch `claude/echoelmusic-review-optimize-u5jjpd`: 13 vor, 17 hinter `main`, Konflikt laut Merge-Tree nur in `scratchpads/SESSION_LOG.md`. **Merge-Termin So 01.11., 11:00 ist überholt**: der Founder arbeitet erst Mi 04.11. wieder mit Claude Code. | Lizenz-Erkennung, Widerspruch in drei Dateien | Mi 04.11. |
| **E22** | Store-Text `fastlane/metadata` (W6, GM28) | A) aus den Studio-Zeilen von `CLAIMS.md` neu schreiben · B) lassen | A. *belegt:* `docs/dev/FOUNDER_INBOX.md` Z. 153 GM28 „[ ] offen": `fastlane/metadata` beschreibt weiter die frühere Bio-App. | App Store 2.3.1/2.3.7 (Metadaten) | Vor Store-Einreichung |
| **E23** | Wellness-Begriffe in der alten App (W4) | A) in der alten App entfernen · B) alte App bleibt eingefroren, Begriffe dokumentiert, nie ausliefern | Founder-Entscheid; *vermutet* B reicht, solange die alte App nicht mehr ausgeliefert wird. *belegt:* `Sources/Echoelmusic/DSP/EchoelEntrainment.swift` Z. 18 (Gamma 40,0), Z. 25 „Deep Sleep", Z. 29 „Peak Focus"; `Sources/Echoelmusic/DSP/EchoelBodyVibeDevice.swift` ab Z. 278 AUv3-Presets „Ambient Calm", „Deep Sleep" (Z. 282), „Active Focus". | Rote Linie 40 Hz, Wellness | nach Founder-Entscheid |
| **E26** | Workflow-Härtung | A) `permissions`-Block in allen Workflows, Actions auf Commit-SHA pinnen, Dependabot für Actions · B) lassen | A. *belegt:* 9 von 18 Workflows ohne `permissions`-Block (u. a. `ci.yml`, `testflight.yml`, `studio.yml`); Actions per Tag (`@v4`) statt SHA; keine `dependabot`-Datei. | Lieferkettenrisiko (*vermutet*) | nach Founder-Entscheid |

### 3.4 Förderung — ENTSCHIEDEN (überholt, nur zur Nachvollziehbarkeit)

> **ENTSCHIEDEN: Förderung am 24.10.2026 vom Founder gestrichen.** *belegt:* `docs/dev/FOERDERUNG_PROTOTYPE_FUND_2026.md` Z. 3 („GESTRICHEN 2026-10-24"); `memory/decisions.md` Z. 5711 bis 5718 („Keine Förderung, keine Installation im Plan"); `decisions.csv` Z. 1329 bis 1331; `docs/dev/FOUNDER_INBOX.md` Z. 160 GM35 „[x] entschieden 24.10. abends: keine Förderung, nirgends". **Nur wieder aufnehmen, wenn der Founder es ausdrücklich öffnet.** Die Zeilen unten bleiben als überholter Stand vom 30.10. stehen.

| ID | Frage | Stand 30.10. (überholt) | Status |
|---|---|---|---|
| ~~**E13**~~ | Prototype Fund Jahrgang 03 | ~~Bewerben mit abgegrenztem Modul; Frist 30.11.2026, 15:00 MEZ; KI-Regel „FAQ 08/09"~~. Quellenhinweis: Die KI-Regel stammt laut Repo aus Blog und Vergleichsseite (`docs/dev/FOERDERUNG_PROTOTYPE_FUND_2026.md` Z. 27/35), nicht direkt beim Prototype Fund verifiziert. KI-Anteil siehe 4.7. | **ENTSCHIEDEN 24.10.: keine Bewerbung** |
| ~~**E14**~~ | SBEP / Blaue Wirtschaft (Skizze 16.11.2026) | ~~Nein, höchstens Partnerrolle~~ | **ENTSCHIEDEN 24.10.: keine Förderung** |
| ~~**E15**~~ | Doppelförderung vermeiden | ~~Linie vom 22.10. (`memory/decisions.md` Z. 5676): Prototype Fund nur Software, Installation über „Inklusive Projekte"; Grund „F12"~~. Quellenhinweis F12: Gemeint war Frage 12 des Prototype-Fund-Formulars „Förderfähigkeit, Verbindungen" (`docs/dev/FOERDERUNG_PROTOTYPE_FUND_2026.md` Z. 83, 667, 730). **Doppelbedeutung:** „F12" steht im Repo auch für den offenen Rechtsform-Satz des Founders (dieselbe Datei Z. 98, 701); die Linie vom 22.10. ist seit 24.10. `superseded`. | **ENTSCHIEDEN 24.10.: überholt** |

### 3.5 Apple

| ID | Frage | Optionen | Empfehlung (Grok) mit Begründung | Auswirkungen | Frist / Abhängigkeit |
|---|---|---|---|---|---|
| **E18** | Apple-Pitch-Reihenfolge und Quelle | A) Developer-Relations-Pitch zuerst, MFi später · B) parallel | A, aber erst nach E19. *belegt:* Eine Datei `Echoelmusic_Apple_Pitch.md` gibt es im Repo nicht. Die Pitches liegen in `docs/dev/EXTERNAL_OUTREACH_AND_DECISIONS_2026-10-31.md` (öffentlich, siehe E19) und in PR #423 (`reports/PITCH_APPLE_TEAM_2026-10-14.md`, offen; *laut Audit* beschreibt er die alte App, *vermutet* passend, weil er „iPad bewusst aus" sagt, während `EchoelStudio/project.yml` iPad aktiviert). „Small Business Program ist angemeldet" passt zu `memory/decisions.md` Z. 5713 (*belegt*). MFi: Founder-Angabe, nicht angemeldet. Pitch nur mit Studio-Zeilen aus `CLAIMS.md`, ohne Eeole, Tauchfliege, Charity. | Glaubwürdigkeit bei Apple | nach E19 |

---

## 4. Infrastruktur-Brainstorming

### 4.1 Domain-, DNS- und Mail-Landkarte (Ist, geprüft 30./31.10.2026)

| Domain | Registrar | Nameserver | Web | Mail (MX, SPF, DMARC) | Status |
|---|---|---|---|---|---|
| echoelmusic.com | Cloudflare (seit 18.01.2026, Ablauf 2035) | Cloudflare | GitHub Pages, kein Proxy | **kein MX, kein SPF, kein DMARC, kein CAA** | *belegt* |
| echoel.com | GoDaddy (09.07.2026 bis 09.07.2029) | Cloudflare | HTTPS 404 | MX Google Workspace; SPF und DMARC (`p=quarantine`) vorhanden; kein CAA | *belegt*; Besitz ANNAHME |
| tropicaldrones.com | nicht geprüft | rzone.de | nicht geprüft | MX rzone.de; DMARC `p=reject`; im TXT kein SPF-Eintrag gefunden | *belegt* (DNS); fehlender SPF *vermutet* problematisch für Versand |
| echoel.de | — | — | — | — | NXDOMAIN, *vermutet* frei |
| eeole.com | GoDaddy (08.10.2025 bis 08.10.2027) | domaincontrol.com | Parkseite `/lander` | kein MX | *belegt* (30.10.) |
| eeole.de, eeole.app, eeolee.com | — | — | — | — | NXDOMAIN; eeolee.com ohne RDAP-Eintrag; *vermutet* frei |
| eeole.org, eeole.net, eeole.io | — | — | — | — | nicht erneut geprüft |

### 4.2 Ziel-Landkarte je Marke (Vorschlag)

| Marke | Canonical (Vorschlag) | Weitere Domains | Hosting (Option) | E-Mail |
|---|---|---|---|---|
| Echoelmusic (Software) | echoelmusic.com | keine nötig | E7 | E17 |
| Echoel (Künstler) | echoel.com **oder** echoel.de | die andere per 301 | eigenes kleines Repo oder Baukasten (4.5) | Google Workspace auf echoel.com läuft bereits |
| Eeole/Eeolee | nach E1/E6 | — | getrennt | eigene Domain |

Regel-Vorschlag: Jede Marke verlinkt höchstens auf die anderen, teilt aber keine Inhalte, keine Kontaktadresse und keine Antragstexte.

### 4.3 Hosting-Optionen für echoelmusic.com

**Ist (belegt):** `pages.yml` veröffentlicht `./docs` auf GitHub Pages; `wrangler.toml` zeigt auf `./docs`, ist nicht aktiv. `docs/_headers` und `docs/_redirects` wirken auf GitHub Pages nicht. Zusätzlich wird alles unter `docs/` öffentlich, auch interne Dateien (E20).

| Option | Vorteile | Nachteile | Kosten |
|---|---|---|---|
| A) GitHub Pages + Cloudflare-Proxy mit Regeln | kein Umzug | Header-Logik im Dashboard statt im Repo | *vermutet* Free-Plan |
| B) Cloudflare Pages | `_headers`/`_redirects` wirken; DNS schon bei Cloudflare | API-Token als GitHub-Secret | Free: 500 Builds/Monat, 20.000 Dateien (*belegt*, [Limits](https://developers.cloudflare.com/pages/platform/limits/)) |
| C) Cloudflare Workers Static Assets | `wrangler.toml` existiert | mehr Konfiguration | *vermutet* Free-Kontingent reicht |

**Migrationsschritte für B in Worten (nach E7):** Pages-Projekt und eng begrenztes Token anlegen (Founder, Token nur als Secret) → Deploy-Workflow ergänzen, GitHub Pages bleibt parallel → Vorschau prüfen (Header da, keine 404 auf `/app` und `/datenschutz`, interne Dateien nicht mehr veröffentlicht) → DNS umstellen (Founder) → live prüfen → GitHub Pages abschalten. Für ein privates Repo (E25) wäre B *vermutet* ohnehin nötig, weil GitHub Pages aus privaten Repos einen bezahlten Plan braucht.

### 4.4 E-Mail-Infrastruktur (Optionen)

| Option | Beschreibung | Hinweis |
|---|---|---|
| A) Google Workspace auf echoel.com nutzen | läuft schon (MX, SPF, DMARC belegt) | passt zur Künstlerlinie; für Software-Kontakt ggf. Alias |
| B) Weiterleitung auf echoelmusic.com (z. B. Cloudflare Email Routing) | Empfang unter Produktdomain | *vermutet:* Senden braucht SPF/DKIM über den Sendedienst |
| Pflicht | SPF, DKIM, DMARC für jede sendende Domain; nicht sendende Domains (z. B. echoelmusic.com) mit „sendet nicht"-Einträgen absichern | *vermutet* nach gängiger Praxis |

### 4.5 Repo-Struktur (Optionen)

| Option | Beschreibung | Bewertung |
|---|---|---|
| A) Alles in diesem Repo | Künstlerseite und Eeole-Web als Unterordner | widerspricht der Trennung. Nicht empfohlen. |
| B) Getrennte Repos | dieses Repo nur Echoelmusic; eigenes Repo für Echoel-Künstlerseite; eigenes (ggf. privates) Repo für Eeole | empfohlen |
| C) Künstlerseite ohne Repo | Baukasten | möglich |

**Regeln im Repo (Vorschlag):**
- Gültig wird eine Entscheidung erst durch einen Eintrag in `memory/decisions.md` (und `decisions.csv`). Dieses Dokument ist nur Vorschlag.
- Prüferberichte liegen in `reports/` auf eigenem Branch `reports/…`, nie direkt auf `main`, und nicht unter `docs/` (sonst öffentlich, E20).
- Nur Claude Code schreibt Code. Grok liefert Prüfungen ohne Code.
- Labels (Vorschlag, nicht angelegt): `entscheidung-offen`, `founder-entscheid`, `rote-linie`, `infrastruktur`, `oeffentlich`.

### 4.6 Trennung der Kommunikationslinien

| Linie | Darf erwähnen | Darf nicht erwähnen |
|---|---|---|
| Echoelmusic (App, Website, Apple) | nur Studio-Zeilen aus `CLAIMS.md` | Eeole, Tauchfliege, Mobilität, Wellness/Medizin-Begriffe, Charity |
| Echoel (Künstler) | Musik, Releases, Auftritte | Softwareversprechen über `CLAIMS.md` hinaus |
| Eeole | Rezepte, Beratung, Hardware-Konzepte | Echoelmusic als „aktuelle Umsetzung" oder Teil der Marke |

### 4.7 Risiko-Matrix

| Risiko | Wahrscheinlichkeit | Wirkung | Gegenmaßnahme | Beleg |
|---|---|---|---|---|
| Öffentliche Pitches mit nicht gedeckten Behauptungen | **eingetreten** | hoch | E19, E20 | *belegt* (Abschnitt 2) |
| Datenschutzseite widerspricht der App | **eingetreten** | hoch | E21 | *belegt* |
| Markenkonflikt Eeole (Éole, Eolo, früherer Shop EEOLE) | mittel (*vermutet*) | hoch | Recherche, ggf. Eeolee | Shop *belegt per Suchindex* |
| Markenkonflikt Echoel | unbekannt | hoch | Recherche Kl. 9/41/42 | offener Punkt *belegt* |
| Verwechslung durch drei Namen | mittel | mittel | 4.6 | Einschätzung |
| Rote Linie Wellness (PR #433, Website W5, alte App W4) | mittel | hoch | E11, E23, E24 | *belegt* |
| ~~Förderinkonsistenz~~ | — | — | **überholt: Förderung gestrichen 24.10.** | E13 bis E15 |
| KI-Anteil der Commits (nur noch relevant, falls Förderung wieder geöffnet wird) | — | mittel | eigene Leistung ehrlich darstellen | Repo-Doku Stand 19.10.: 9.861 Commits auf `main`, 8.805 vom Account `claude`; Audit 31.10.: 10.744 / 9.642 (Grok-Prüfung 31.10. über GitHub-API: 10.744 auf `main`, Account `claude` 9.643 Beiträge) |
| Fehlende Sicherheitsheader | **eingetreten** | mittel | E7 | *belegt* (live) |
| Lieferkette CI | niedrig bis mittel (*vermutet*) | mittel | E26 | *belegt* |

---

## 5. Zeitplan

| Datum | Was | Wer |
|---|---|---|
| **Mo 02.11.2026** | Marken- und Domainprüfung von Hand: „echoel", „eeole", „eeolee", Ähnliche (EOLE, EOLO, EOL, ÉOLE): [DPMAregister](https://register.dpma.de/DPMAregister/marke/basis), [TMview](https://www.tmdn.org/tmview/), [EUIPO eSearch](https://euipo.europa.eu/eSearch/), [WIPO Global Brand Database](https://branddb.wipo.int/). Entscheiden, ob die Mails aus E19 überhaupt rausgehen sollen (bis dahin nichts verschicken). | Founder |
| **Di 03.11.2026** | Entscheidungen vorsortieren: sofort (E19, E20, E21, E12) / vor Store-Start (E7, E16, E22, E25) / später (Marke, Domains). | Founder |
| **Mi 04.11.2026** | Übergabe an Claude Code mit dem Startauftrag (Abschnitt 0). | Founder → Claude Code |
| ~~So 01.11.2026, 11:00~~ | ~~Merge-Termin LR2~~ — **überholt**, siehe E12 | — |
| ~~16.11. / 30.11.2026~~ | ~~SBEP-Skizze / Prototype Fund~~ — **überholt: Förderung gestrichen 24.10.** | — |

---

## 6. Aufgaben für Claude Code

Alle Aufgaben: **erst nach dem genannten Founder-Entscheid**, auf eigenem Branch, kein Merge ohne Freigabe, rote Linien gelten.

| Nr. | Aufgabe (in Worten) | Erst nach Founder-Entscheid | Akzeptanzkriterien |
|---|---|---|---|
| C1 | Hosting-Option umsetzen, damit Sicherheitsheader wirken | E7 | Live-Antwort enthält HSTS, CSP, X-Frame-Options; Prüfung mit Datum dokumentiert |
| C2 | `/app` und `/datenschutz` herstellen | E7 | kein 404 mehr |
| C3 | Canonical und 301-Regeln nach Domain-Rolle | E8 | eine Canonical-Domain je Linie; Sitemap und Canonical stimmen überein |
| C4 | Impressum ergänzen | E16 | 2. Kontaktweg und USt-IdNr. bzw. Begründung; Punkt in `decisions.csv` Z. 93 als erledigt nachgetragen |
| C5 | Kontaktadresse ersetzen | E17 | `echoel@tropicaldrones.com` in öffentlichen Texten ersetzt oder bewusst belassen und dokumentiert |
| C6 | Tauchfliege in Vision-Dateien als „gestoppt 22.10./24.10." markieren oder entfernen; prüfen, was der SessionStart-Hook lädt | E10 | `memory/vision.md` und weitere Fundstellen konsistent; keine Sitzung bekommt die Tauchfliege als aktuelles Ziel |
| C7 | PR #433 gegen `EchoelStudio/CLAUDE.md` und `CLAIMS.md` abgleichen | E11 | Plan prüft `EchoelStudio/`; Pausen-Erinnerung gestrichen oder ohne Wellness-Bezug; RTMP nicht als ausgeliefert |
| C8 | Pfadfehler im Plan von PR #433 korrigieren | E11 | `Workstation/WorkstationView.swift` → unter `Studio/`; `Sources/EchoelAI/ParameterToolCore.swift` → `Sources/Echoelmusic/EchoelAI/`; Verweis auf nicht vorhandenes `Bio/BLEHRSBioPublisher.swift` entfernt oder begründet |
| C9 | LR2 umsetzen, Lizenz-Angaben in `LICENSE`, `THIRD_PARTY_NOTICES.md` und `CLAIMS.md` Z. 169 widerspruchsfrei machen, Arbeitszweig mit `main` abgleichen | E12 | GitHub erkennt MIT; keine Datei nennt HaishinKit als aktive Abhängigkeit, solange `Package.swift` keine hat; Konflikt in `scratchpads/SESSION_LOG.md` gelöst; CI grün |
| C10 | Prüfen, dass „Eeole" in keinem Echoelmusic-Produkttext, Pitch- oder Antragsentwurf steht | E1/E2, E19 | Suche ergibt keinen Treffer außerhalb von `reports/` |
| C11 | Outreach-Datei aus `docs/` nehmen bzw. verschieben; Pitches nur aus Studio-Zeilen neu formulieren | E19 | Datei nicht mehr öffentlich (HTTP 404); jede Pitch-Aussage zeigt auf eine Studio-Zeile in `CLAIMS.md`; kein Versand durch Claude Code |
| C12 | Interne Dateien aus der Veröffentlichung nehmen; `auto-merge-docs` auf Review umstellen | E20 | `docs/CLAUDE.md` und `docs/dev/` live nicht mehr erreichbar; Docs-Änderungen gehen nur nach Review nach `main` |
| C13 | Datenschutzseite an `EchoelStudio/project.yml` angleichen | E21 | Bluetooth, Kamera, Mikrofon, lokales Netz korrekt beschrieben; nichts als „Not in Echoel Studio", was die App anfragt |
| C14 | Store-Text aus Studio-Zeilen neu schreiben | E22 | `fastlane/metadata` enthält nur Studio-Zeilen; GM28 geschlossen |
| C15 | Wellness-/40-Hz-Begriffe der alten App dokumentieren oder entfernen | E23 | Liste mit Datei und Zeile; alte App nicht ausgeliefert oder Begriffe entfernt |
| C16 | Rote-Linie-Wörter auf der Website streichen | E24 | keine Treffer für „relaxation", „meditat", „binaural" (außer klar als „geplant" bzw. technisch neutral, falls der Founder das will) |
| C17 | Workflows härten | E26 | alle Workflows mit `permissions`-Block; Actions auf SHA; Dependabot für Actions |

---

## 7. Offene Fragen, nicht Geprüftes, Quellen

### 7.1 Offene Fragen an den Founder (max. 7)

1. Sollen die Mails aus der Outreach-Datei (Apple, MFi, DPMA, BfN) überhaupt rausgehen, und darf die Datei aus `docs/` verschwinden (E19)?
2. Sollen interne Dateien (`docs/dev/`, `docs/CLAUDE.md`) weiter öffentlich sein, und darf `auto-merge-docs` auf Review umgestellt werden (E20)?
3. LR2: Ja oder Nein (E12)?
4. Eeole oder Eeolee, und nur Marke für Peaceful Business, nicht Dachmarke (E1, E2)?
5. Gehören dir echoel.com und echoel.de, und welche wird Canonical der Künstlerseite (E8)?
6. Gilt der Tauchfliegen-Stopp, und darf sie aus `memory/vision.md` raus (E10)?
7. Repo nach Store-Start privat, ja oder nein (E25)?

### 7.2 Was nicht geprüft werden konnte

- Markenregister DPMA, EUIPO, TMview, WIPO (automatisch nicht abfragbar).
- App-Store-Name (nur in App Store Connect).
- Verkäuflichkeit und Maklerpreis von eeole.com.
- prototypefund.de direkt (HTTP 403 am 30.10.); die KI-Regel stammt laut Repo aus Blog und Vergleichsseite.
- Registrar von tropicaldrones.com; ob dort SPF anders als per TXT hinterlegt ist.
- Ob PR #423 vollständig die alte App beschreibt (nur Stichprobe).
- Die Zahl 9.642 aus dem Audit (die GitHub-API zeigt am 31.10. 9.643 Beiträge für `claude`; die Differenz von 1 ist *vermutet* ein Commit nach dem Audit oder eine andere Zählweise).
- Small Business Program und MFi direkt bei Apple (nur Founder-Angabe und `memory/decisions.md` Z. 5713).
- Rechtliche Bewertung von Impressum und Datenschutz.

### 7.3 Quellen

- Cloudflare Pages Limits: https://developers.cloudflare.com/pages/platform/limits/
- Cloudflare Registrar: https://www.cloudflare.com/products/registrar/
- DPMAregister: https://register.dpma.de/DPMAregister/marke/basis
- TMview: https://www.tmdn.org/tmview/
- EUIPO eSearch: https://euipo.europa.eu/eSearch/
- WIPO Global Brand Database: https://branddb.wipo.int/
- Überholt (Förderung gestrichen), nur zur Nachvollziehbarkeit: BMFTR-Bekanntmachung Blaue Wirtschaft https://www.bmftr.bund.de/SharedDocs/Bekanntmachungen/DE/2025/10/2025-10-10-bekanntmachung-blaue-wirtschaft.html · https://bluepartnership.eu/ · AGVO Art. 6 https://gesetze.legal/eu/vo_eu_2014_651/6 · https://prototypefund.de/
- Repo-Stellen (Stand `96aae3b`): `ContentPipeline/CLAIMS.md` Z. 13 bis 16, ab Z. 85, Z. 169, 283, 296, 372/374, §2, §6 · `CLAUDE.md` Z. 13/103 · `EchoelStudio/CLAUDE.md` · `EchoelStudio/project.yml` Z. 77 bis 85 · `docs/dev/EXTERNAL_OUTREACH_AND_DECISIONS_2026-10-31.md` · `docs/dev/FOERDERUNG_PROTOTYPE_FUND_2026.md` Z. 3, 27, 35, 83, 98, 667, 701, 730 · `docs/dev/FOUNDER_INBOX.md` Z. 153, 160, 161 · `memory/decisions.md` Z. 5676, 5711 bis 5718 · `decisions.csv` Z. 93, 1329 bis 1331 · `memory/user.md` Z. 39 · `memory/vision.md` Z. 13 · `.claude/settings.json` Z. 65 · `.github/workflows/pages.yml`, `auto-merge-docs.yml` · `LICENSE` · `THIRD_PARTY_NOTICES.md` · `docs/terms.html` Z. 133 · `docs/overview.html` Z. 234 · `docs/tools.html` Z. 168, 186 · `docs/version.json` Z. 51 · `docs/brainstorming.html` Z. 135 · `Sources/Echoelmusic/DSP/EchoelEntrainment.swift` Z. 18, 25, 29 · `Sources/Echoelmusic/DSP/EchoelBodyVibeDevice.swift` Z. 278 bis 286 · PR #423, PR #433

---

Orchester: Grok · Entscheidungen & Infrastruktur
