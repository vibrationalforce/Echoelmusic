# Entscheidungsregister und Infrastruktur-Brainstorming

| Feld | Wert |
|---|---|
| Datum | 30.10.2026 (MEZ) |
| Autor | Grok (Prüfer/Rechercheur, ohne Code) |
| Basis | `main` @ `67476d1bab8d994bd49ff2ab3a8fddb1258e898d` |
| Status | **Vorschlag, nicht verbindlich. Nur der Founder entscheidet.** Claude Code prüft und setzt erst nach einem Founder-Entscheid um. |
| Gilt als ausgeliefert | Nur, was in `ContentPipeline/CLAIMS.md` steht. Dieses Dokument behauptet keine Funktion. |

**Kennzeichnung:** *belegt* = selbst gelesen oder live geprüft (mit Quelle). *vermutet* = plausibel, nicht abschließend geprüft. *ANNAHME* = Arbeitshypothese ohne Beleg. *Founder-Angabe* = vom Founder im Chat genannt, von Grok nicht geprüft.

**Rote Linien (gelten für alles hier):** Echoelmusic ist nie Wellness, Meditation, Therapie oder Medizin. Keine Heilfrequenzen, kein Solfeggio, keine Chakren, keine Binaural- oder 40-Hz-Effekte, kein „Weltfrieden" als Wirkung. „Eeole" taucht in Echoelmusic-Produkttexten, Förderanträgen und Apple-Pitches nicht auf, bis die Basis steht (Marke geprüft, Name entschieden).

---

## Inhalt

1. [Kurzüberblick und Zielbild](#1-kurzüberblick-und-zielbild)
2. [Entscheidungsregister](#2-entscheidungsregister)
3. [Infrastruktur-Brainstorming](#3-infrastruktur-brainstorming)
4. [Zeitplan bis Mittwoch und danach](#4-zeitplan-bis-mittwoch-und-danach)
5. [Aufgaben für Claude Code](#5-aufgaben-für-claude-code)
6. [Offene Fragen, nicht Geprüftes, Quellen](#6-offene-fragen-nicht-geprüftes-quellen)

---

## 1. Kurzüberblick und Zielbild

Der Founder hat am 30.10.2026 eine Dreiteilung vorgeschlagen (Founder-Angabe):

| Linie | Name | Zweck | Domain (Ziel) | Bezug zu diesem Repo |
|---|---|---|---|---|
| (a) | **Eeole** bzw. **Eeolee** (Schreibweise offen, E1) | Marke für „Peaceful Business": Rezepte, Beratung, nachhaltige Hardware-Konzepte; ggf. Tauchfliege, falls wieder aufgenommen (E10) | offen (E6) | **Keiner.** Gehört nicht in Echoelmusic-Texte, Anträge oder Pitches. |
| (b) | **Echoel** | Künstlerseite für die Musik des Founders | echoel.com, echoel.de | Keiner oder nur Verlinkung (E8, Abschnitt 3.5) |
| (c) | **Echoelmusic** | Künstlerische Musikproduktions-Software (App, Repo) | echoelmusic.com bleibt | Dieses Repo |

**Warum diese Trennung trägt (Einschätzung):**
- Die App behält Namen, Bundle-IDs, Repo und Website. Kein Namenswechsel im Code nötig. *belegt:* „echoel*" kommt im Repo 34.026-mal vor, 1.189 Pfade tragen „echoel" im Namen (Zählung Grok, Stand `67476d1`).
- Hardware-, Beratungs- und Mobility-Themen verlassen das Musik-Repo. Der Widerspruch Tauchfliege gestoppt (22.10.) vs. wieder in Vision-Dateien (28.10.) wird auflösbar (E10).
- Förderanträge bleiben stimmig: ein Name pro Antrag, ein Förderobjekt (E15).

**Was die Trennung nicht löst:** die Markenfrage (E4, E5), die Rechtsform (E3) und den KI-Anteil im Prototype-Fund-Antrag (E13).

---

## 2. Entscheidungsregister

Alle Einträge: **Wer entscheidet: Founder. Status: offen.**

| ID | Frage | Optionen | Empfehlung (Grok) mit Begründung | Auswirkungen | Frist / Abhängigkeit |
|---|---|---|---|---|---|
| **E1** | Schreibweise: Eeole oder Eeolee? | A) Eeole · B) Eeolee · C) anderer Name | Erst nach Markenrecherche (E5) wählen. *vermutet:* „Eeolee" ist eigenständiger und weiter weg von „Éole"/„Eolo", eeole.com ist belegt vergeben. | Domain, Marke, Logo | Nach Montag 02.11. (Recherche) |
| **E2** | Ist Eeole Firmenname, Marke oder nur Domain? | A) nur Marke/Domain · B) Firmenname (Rechtsträger) · C) Dachmarke über alles | A, solange kein Rechtsträger existiert. Firmenname erst mit E3. | Impressum, Verträge, Förderfähigkeit | Nach E3 |
| **E3** | Rechtsform/Trägerstruktur | A) Einzelperson · B) Einzelunternehmen · C) UG/GmbH · D) getrennte Träger je Linie | Erst mit Steuerberatung klären. Der Prototype Fund fördert laut Repo-Doku Einzelpersonen/Teams, keine Unternehmen (*vermutet* nach Repo-Doku und Websuche, F12). SBEP verlangt ein Unternehmen mit Jahresabschluss 2025 (*belegt*, FONA-Seite). | Entscheidet, welche Förderung formal möglich ist | Vor 30.11.2026 (Prototype Fund) |
| **E4** | Marke „Echoel" anmelden? | A) DPMA (DE) · B) EUIPO (EU) · C) zusätzlich USPTO · D) nicht anmelden | A oder B in Klassen 9, 41, 42 nach Recherche. *belegt:* offener Punkt „DPMA/EUIPO/USPTO trademark 'Echoel' (cl. 9+41)" in `scratchpads/archive/SESSION_LOG_before_2026-10.md` Z. 5440, kein Erledigt-Beleg gefunden. | Kosten, Schutz der Künstler- und Softwarelinie | Recherche Mo 02.11. |
| **E5** | Marke „Eeole/Eeolee" anmelden? Welche Klassen? | Klassen je Angebot. ANNAHME: Beratung (z. B. 35), Rezepte/Publikation (z. B. 16/41), Hardware (z. B. 9/12), Bekleidung 25 meiden | Erst Ähnlichkeitsrecherche (EOLE, EOLO, EOL, ÉOLE). *belegt per Suchindex:* früherer Shop „EEOLE" für Sport- und Bademode → Klasse 25 riskant. Klassennummern als ANNAHME von einer Fachperson bestätigen lassen. | Verwechslungsrisiko, Kosten | Nach E1 |
| **E6** | Domain für Eeole | A) eeole.com über Makler kaufen · B) eeole.de/.app sichern · C) eeolee.com prüfen | B/C zuerst prüfen. *belegt:* eeole.com bei GoDaddy registriert (08.10.2025, Ablauf 08.10.2027), GoDaddy-Parkseite, RDAP-Sperren. Preis unbekannt. *vermutet:* eeole.de/.app/.org/.net frei. | Budget, Erreichbarkeit | Vor Registrierung RDAP erneut prüfen |
| **E7** | Hosting echoelmusic.com | A) GitHub Pages bleiben, Header per Cloudflare-Proxy/Regeln · B) Umzug Cloudflare Pages · C) Cloudflare Workers (`wrangler.toml`) | B *vermutet* als einfachster Weg, weil `docs/_headers` und `docs/_redirects` dort ausgewertet werden (Cloudflare-Doku). A ist ohne Umzug möglich, aber zwei Systeme. | HSTS/CSP, 404 auf `/app` und `/datenschutz` | Vor jeder Jury-/Apple-Sichtung |
| **E8** | Rolle der Domains echoel.com / echoel.de / echoelmusic.com | A) echoel.* = Künstlerseite, echoelmusic.com = Software · B) echoel.com leitet 301 auf echoelmusic.com · C) eine Seite für alles | A (Founder-Vorschlag). Je Linie eine Canonical-Domain, sonstige Varianten 301 auf die Canonical. *ANNAHME:* echoel.com gehört dem Founder (registriert am Tag von `NAMING_MAP_2026-07-09.md`). echoel.de nicht geprüft. | SEO, Klarheit für Jury und Apple | Nach Bestätigung des Besitzes |
| **E9** | Bundle-IDs unverändert lassen? | A) unverändert · B) umbenennen | A. *ANNAHME nach Apple-Praxis:* neue Bundle-ID = neuer App-Store-Eintrag, iCloud-Container nicht umbenennbar. IDs hängen nicht an der Domain (`com.echoelmusic.app` u. a., *belegt*). | Keine, wenn A | — |
| **E10** | Tauchfliege: Stopp vom 22.10. oder wieder aufnehmen? | A) gestoppt lassen, Vision-Dateien markieren · B) wieder aufnehmen, aber unter Eeole außerhalb des Repos · C) im Repo lassen | A oder B. *belegt:* Stopp „in keinem Antragstext" in `memory/user.md` Z. 39 (22.10.); Wiederaufnahme in Vision-Dateien seit Commit `e756a7cfd7` (28.10.), u. a. `memory/vision.md` Z. 13, insgesamt 12 Dateien. | Förderkonsistenz, rote Linien | Vor jedem Antragstext |
| **E11** | PR #433 (Neupositionierung) annehmen? | A) ablehnen · B) überarbeiten lassen · C) annehmen | B. *belegt:* Plan prüft alte App `Sources/Echoelmusic` statt `EchoelStudio/`; falsche Pfade; „Biofeedback als Identität streichen" widerspricht `CLAUDE.md` Z. 13/103 (nur über Grand Council änderbar); Pausen-Erinnerung („Produktionspause, beweg dich") nah an `CLAIMS.md` §2 (Wellness) und App Store 5.1.3; RTMP laut `CLAIMS.md` §5 nie gebaut. | Identitätssatz, rote Linie Wellness | Nach Founder-Entscheid |
| **E12** | LR2: LICENSE als reiner MIT-Text? | A) Ja · B) Nein, Anhang „THIRD-PARTY LICENSES" bleibt | Founder-Entscheid. *belegt (30.10.):* Anhang auf `main` und auf `claude/echoelmusic-review-optimize-u5jjpd` noch vorhanden; Branch 13 Commits vor, 16 hinter `main`. Merge-Termin laut Founder-Kalender So 01.11., 11:00 MEZ (Founder arbeitet erst Mi 04.11. mit Claude). | Merge braucht vorherigen Abgleich mit `main` | Mi 04.11. |
| **E13** | Prototype Fund Jahrgang 03 bewerben? | A) ja, mit abgegrenztem Modul · B) nein | A. *belegt (Websuche, offizielle Auszüge):* Frist **30.11.2026, 15:00 MEZ**; Förderung 01.06.–30.11.2027; Einzelperson bis 47.500 €, Team bis 95.000 €; Bestand erlaubt, wenn Vorhaben klar abgrenzbar; FAQ 08: „Vibe-Coding nicht förderfähig", KI nur Werkzeug; FAQ 09: Idee in eigenen Worten. *belegt laut Repo-Doku:* 8.805 von 9.861 Commits vom Account `claude`. | Ehrliche KI-Darstellung nötig, Rechtsform (E3/F12) | 30.11.2026, 15:00 MEZ |
| **E14** | SBEP / Blaue Wirtschaft (Skizze 16.11.2026) ja oder nein? | A) nein · B) nur als Partner in fremdem Konsortium, über PtJ klären · C) eigene Skizze | A, höchstens B. *belegt:* Skizze 16.11.2026, 15:00 MEZ, Konsortium ≥ 3 Länder, Unternehmen müssen Jahresabschluss 2025 und BWA August 2026 an ptj-sbep@ptj.de senden. Im Repo kein Meerbezug außer der gestoppten Tauchfliege. Die drei Quellen widersprechen sich teils (Abschnitt 6.3). | Aufwand ohne realistische Chance | 16.11.2026 |
| **E15** | Doppelförderung vermeiden | A) Linie vom 22.10. halten: Prototype Fund nur Software, Installation über Hamburg „Inklusive Projekte" · B) neu schneiden | A. *belegt:* `memory/decisions.md` Z. 5676 (22.10.), Grund F12 (keine andere öffentliche Förderung für dasselbe Förderobjekt). Ein SBEP-Antrag mit derselben Software würde das unterlaufen. | Förderfähigkeit | Vor jeder Einreichung |
| **E16** | Impressum: 2. Kontaktweg und USt-IdNr. | A) ergänzen · B) begründet weglassen (z. B. keine USt-IdNr. vorhanden) | A bzw. B mit Begründung, rechtlich prüfen lassen. *belegt laut Vorprüfung:* in `decisions.csv` seit 18.06. offen. | Rechtssicherheit der Website | Vor Jury-/Apple-Sichtung |
| **E17** | Kontakt-Mail `echoel@tropicaldrones.com` ersetzen? | A) Adresse auf eigener Domain (z. B. echoelmusic.com) · B) beibehalten | A, mit Weiterleitung der alten Adresse. *belegt:* „tropicaldrones" 87-mal in 40 Dateien, die Mail 80-mal, u. a. im Impressum. echoelmusic.com hat keinen MX (*belegt*), braucht also erst E-Mail-Infrastruktur (3.4). | Markenklarheit, Zustellbarkeit | Nach E-Mail-Setup |
| **E18** | Apple-Pitch-Reihenfolge | A) Developer-Relations-Pitch zuerst, MFi später · B) beides parallel | A. *Founder-Angabe:* Small Business Program aktiv, MFi nicht angemeldet, Pitch-Datei `Echoelmusic_Apple_Pitch.md` liegt vor (im Repo **nicht geprüft**). Pitch nur mit dem, was in `CLAIMS.md` steht, ohne Eeole, Tauchfliege, Charity. | Glaubwürdigkeit bei Apple | Nach Founder-Freigabe |

---

## 3. Infrastruktur-Brainstorming

### 3.1 Domain- und DNS-Landkarte (Ist)

| Domain | Registrar | Nameserver | Ziel / Inhalt | Status |
|---|---|---|---|---|
| echoelmusic.com | Cloudflare (seit 18.01.2026, Ablauf 2035) | Cloudflare | A-Einträge auf GitHub Pages, kein Proxy, kein MX, kein CAA; Antwort `server: GitHub.com` | *belegt* (live 30.10.) |
| echoel.com | GoDaddy (09.07.2026, Ablauf 2029) | Cloudflare | im Repo nicht erwähnt | *belegt*; Besitz = ANNAHME |
| echoel.de | — | — | — | nicht geprüft |
| eeole.com | GoDaddy (08.10.2025, Ablauf 08.10.2027) | domaincontrol.com | Weiterleitung `/lander`, GoDaddy-Parkseite, kein MX, RDAP-Sperren | *belegt* |
| eeole.de / .app / .org / .net | — | — | — | *vermutet* frei |
| eeole.io, eeolee.com | — | — | — | nicht geprüft |

### 3.2 Ziel-Landkarte je Marke (Vorschlag)

| Marke | Canonical (Vorschlag) | Weitere Domains | Hosting (Option) | E-Mail |
|---|---|---|---|---|
| Echoelmusic (Software) | echoelmusic.com | keine nötig | E7 | Adresse auf echoelmusic.com |
| Echoel (Künstler) | echoel.com **oder** echoel.de (eine wählen) | die andere per 301 | eigenes kleines Repo oder Hosting außerhalb dieses Repos (3.5) | Adresse auf echoel.* |
| Eeole/Eeolee | nach E1/E6 | — | getrennt, eigenes Repo | Adresse auf eigener Domain |

Regel-Vorschlag: Jede Marke verlinkt höchstens auf die anderen, teilt aber keine Inhalte, keine Kontaktadresse und keine Antragstexte.

### 3.3 Hosting-Optionen für echoelmusic.com

**Ist (belegt):** `.github/workflows/pages.yml` veröffentlicht `docs/` auf GitHub Pages. `wrangler.toml` zeigt auf `./docs`, ist aber nicht aktiv (bräuchte API-Token). `docs/_headers` und `docs/_redirects` wirken auf GitHub Pages nicht: HSTS, CSP, X-Frame-Options fehlen live, `/app` und `/datenschutz` liefern 404.

| Option | Vorteile | Nachteile | Kosten |
|---|---|---|---|
| A) GitHub Pages bleibt, Cloudflare-Proxy mit Header-/Redirect-Regeln | kein Umzug, Workflow bleibt | Header-Logik liegt außerhalb des Repos (Dashboard), `_headers` bleibt tote Datei | *vermutet* im Free-Plan machbar |
| B) Cloudflare Pages | `_headers`/`_redirects` werden ausgewertet; Domain und DNS schon bei Cloudflare | API-Token als GitHub-Secret nötig; Umstellung DNS | Free: 500 Builds/Monat, 20.000 Dateien (*belegt*, [Limits](https://developers.cloudflare.com/pages/platform/limits/)) |
| C) Cloudflare Workers mit Static Assets | `wrangler.toml` existiert schon | mehr Konfiguration, für statische Seite überdimensioniert (*vermutet*) | *vermutet* Free-Kontingent reicht |

**Migrationsschritte in Worten (für B, nach Founder-Entscheid E7):**
1. Founder legt in Cloudflare ein Pages-Projekt an und erzeugt ein eng begrenztes API-Token; Token nur als GitHub-Secret, nie im Repo.
2. Claude Code ergänzt oder ersetzt den Deploy-Workflow; GitHub Pages bleibt bis zur erfolgreichen Prüfung aktiv.
3. Prüfung auf der Vorschau-URL: Header vorhanden, `/app` und `/datenschutz` liefern kein 404.
4. Founder stellt DNS von GitHub-A-Einträgen auf Cloudflare Pages um.
5. Live-Prüfung der Header; danach GitHub Pages abschalten und `docs/CNAME` bewerten.

### 3.4 E-Mail-Infrastruktur (Optionen)

| Option | Beschreibung | Hinweis |
|---|---|---|
| A) Weiterleitung (z. B. Cloudflare Email Routing) | Adresse auf eigener Domain leitet an bestehendes Postfach | *vermutet:* nur Empfang; Senden unter der Domain braucht eigene Lösung |
| B) Gehostetes Postfach (Anbieter nach Wahl) | eigenes Senden und Empfangen | laufende Kosten (nicht geprüft) |
| Pflicht in jedem Fall | SPF, DKIM, DMARC für jede sendende Domain; Domains ohne Mailversand mit „sendet nicht"-Einträgen absichern | *vermutet* nach gängiger Praxis |

### 3.5 Repo-Struktur (Optionen)

| Option | Beschreibung | Bewertung |
|---|---|---|
| A) Alles in diesem Repo | Künstlerseite und Eeole-Web als Unterordner | widerspricht der Trennung; Eeole-Inhalte würden im Software-Repo landen. Nicht empfohlen. |
| B) Getrennte Repos | dieses Repo = nur Echoelmusic; eigenes Repo für Echoel-Künstlerseite; eigenes (ggf. privates) Repo für Eeole | empfohlen; klare Zuständigkeiten, saubere Förderobjekte |
| C) Künstlerseite ohne Repo (Baukasten) | z. B. Hosting-Baukasten | möglich, wenn kein Code-Bedarf |

**Regeln im Repo (Vorschlag):**
- Entscheidungen werden in `memory/decisions.md` festgehalten (dort liegen schon frühere, z. B. Z. 5676). Dieses Dokument ist nur Vorschlag; erst ein Eintrag dort macht eine Entscheidung gültig.
- Berichte von Prüfern landen in `reports/` auf eigenem Branch `reports/…`, nie direkt auf `main`.
- Nur Claude Code schreibt Code. Grok liefert Prüfungen und Recherche ohne Code.
- Labels (Vorschlag, nicht angelegt): `entscheidung-offen`, `founder-entscheid`, `rote-linie`, `foerderung`, `infrastruktur`.

### 3.6 Trennung der Kommunikationslinien

| Linie | Darf erwähnen | Darf nicht erwähnen |
|---|---|---|
| Echoelmusic (App, Website, Apple, Prototype Fund) | nur Inhalte aus `CLAIMS.md` | Eeole, Tauchfliege, Wellness/Medizin-Begriffe, Charity-Themen (laut Founder bewusst draußen) |
| Echoel (Künstler) | Musik, Releases, Auftritte | Softwareversprechen über `CLAIMS.md` hinaus |
| Eeole | Rezepte, Beratung, Hardware-Konzepte | Echoelmusic als Wirkversprechen; Verknüpfung „Musik-App + Wohlbefinden" |

### 3.7 Risiko-Matrix

| Risiko | Wahrscheinlichkeit | Wirkung | Gegenmaßnahme | Beleg |
|---|---|---|---|---|
| Markenkonflikt Eeole (Éole, Eolo, früherer Shop EEOLE) | mittel (*vermutet*) | hoch | Recherche Mo 02.11., ggf. Eeolee oder anderer Name | Shop *belegt per Suchindex*; Eolo nicht geprüft |
| Markenkonflikt Echoel | unbekannt | hoch | Recherche Klassen 9/41/42 | offener Punkt Z. 5440 *belegt* |
| Verwechslung durch drei Namen | mittel | mittel | Kommunikationslinien 3.6, je Linie eine Domain | Einschätzung |
| Förderinkonsistenz (Name, Förderobjekt, Tauchfliege) | hoch ohne Klärung | hoch | E10, E15, ein Name pro Antrag | `memory/decisions.md` Z. 5676 *belegt* |
| Rote Linie Wellness (PR #433 Pausen-Erinnerung; Eeole-Nähe) | mittel | hoch (App Store 5.1.3, UWG §5) | E11, Linie 3.6 | *belegt* (PR #433) |
| KI-Anteil im Prototype Fund (8.805 von 9.861 Commits `claude`) | hoch | hoch | eigene Leistung ehrlich darstellen, Idee in eigenen Worten (FAQ 08/09) | *belegt laut Repo-Doku* |
| Website-Sicherheitsheader fehlen | belegt | mittel | E7 | *belegt* (live) |

---

## 4. Zeitplan bis Mittwoch und danach

| Datum | Was | Wer |
|---|---|---|
| **Mo 02.11.2026** | Marken- und Domainprüfung von Hand: „echoel", „eeole", „eeolee", Ähnliche (EOLE, EOLO, EOL, ÉOLE). Register: [DPMAregister](https://register.dpma.de/DPMAregister/marke/basis), [TMview](https://www.tmdn.org/tmview/), [EUIPO eSearch](https://euipo.europa.eu/eSearch/), [WIPO Global Brand Database](https://branddb.wipo.int/). Domains eeole.de/.app, eeolee.com, echoel.de per RDAP. | Founder |
| **Di 03.11.2026** | Entscheidungen E1–E18 vorsortieren: sofort / bis 30.11. / später. Ergebnisse für Claude Code notieren. | Founder (Grok kann zuarbeiten) |
| **Mi 04.11.2026** | Übergabe an Claude Code: dieses Dokument + Founder-Entscheide; LR2 (E12); Abgleich Arbeitszweig mit `main`. | Founder → Claude Code |
| **Mo 16.11.2026, 15:00 MEZ** | SBEP-Skizzenfrist (nur relevant, wenn E14 ≠ A) | Founder |
| **Mo 30.11.2026, 15:00 MEZ** | Prototype Fund Jahrgang 03, Bewerbungsschluss (E13) | Founder |

---

## 5. Aufgaben für Claude Code

Alle Aufgaben: **erst nach dem genannten Founder-Entscheid**, kein Merge ohne Freigabe, rote Linien gelten.

| Nr. | Aufgabe (in Worten) | Erst nach | Akzeptanzkriterien |
|---|---|---|---|
| C1 | Klären und dokumentieren, warum `docs/_headers` und `docs/_redirects` live nicht wirken, und die gewählte Hosting-Option umsetzen | E7 | Live-Antwort von echoelmusic.com enthält HSTS, CSP, X-Frame-Options; Prüfung mit Datum dokumentiert |
| C2 | Weiterleitungen für `/app` und `/datenschutz` herstellen | E7 | beide Pfade liefern kein 404 mehr, sondern Inhalt oder 301 |
| C3 | Canonical und 301-Regeln nach Domain-Rolle setzen | E8 | eine Canonical-Domain je Linie; Sitemap und Canonical in `docs/index.html` stimmen überein |
| C4 | Impressum ergänzen (2. Kontaktweg, USt-IdNr. oder begründeter Hinweis) | E16 | Felder vorhanden; Eintrag in `decisions.csv` geschlossen |
| C5 | Kontaktadresse ersetzen | E17 und E-Mail-Setup | keine Vorkommen von `echoel@tropicaldrones.com` mehr in öffentlichen Texten, außer bewusst belassen und dokumentiert |
| C6 | Tauchfliege in Vision-Dateien als „gestoppt 22.10." markieren oder aus dem Repo nehmen | E10 | alle betroffenen Dateien (laut Vorprüfung 12, u. a. `memory/vision.md`) konsistent; kein Antragstext erwähnt sie |
| C7 | PR #433 gegen `EchoelStudio/CLAUDE.md` und `CLAIMS.md` abgleichen | E11 | Plan prüft `EchoelStudio/`; Pausen-Erinnerung gestrichen oder ohne Wellness-Bezug; Identitätssatz nur über Grand Council |
| C8 | Pfadfehler im Plan von PR #433 korrigieren | E11 | `Workstation/WorkstationView.swift` → unter `Studio/`; `Sources/EchoelAI/ParameterToolCore.swift` → `Sources/Echoelmusic/EchoelAI/`; Verweis auf nicht vorhandenes `Bio/BLEHRSBioPublisher.swift` entfernt oder begründet |
| C9 | LR2 umsetzen und Arbeitszweig mit `main` abgleichen | E12 | LICENSE entspricht der Entscheidung; Arbeitszweig ohne Rückstand zu `main`; CI grün |
| C10 | Prüfen, dass „Eeole" in keinem Produkttext, Pitch- oder Antragsentwurf im Repo steht | E1/E2 | Suche ergibt keinen Treffer außerhalb von `reports/` |

---

## 6. Offene Fragen, nicht Geprüftes, Quellen

### 6.1 Offene Fragen an den Founder (max. 7)

1. Eeole oder Eeolee, und soll der Name Firmenname werden (E1, E2)?
2. Gehören dir echoel.com und echoel.de, und welche soll Canonical der Künstlerseite sein (E8)?
3. Gibt es eine Rechtsform und einen Jahresabschluss 2025 (E3, E14)?
4. Gilt der Tauchfliegen-Stopp vom 22.10. (E10)?
5. Soll PR #433 überarbeitet oder geschlossen werden (E11)?
6. Welches abgegrenzte Modul soll in den Prototype Fund (E13)?
7. Liegt `Echoelmusic_Apple_Pitch.md` im Repo oder lokal, und soll Grok sie gegen `CLAIMS.md` prüfen (E18)?

### 6.2 Was nicht geprüft werden konnte

- Markenregister DPMA, EUIPO, TMview, WIPO (automatisch nicht abfragbar: JavaScript bzw. „Request Rejected").
- App-Store-Name (nur in App Store Connect sichtbar).
- Verkäuflichkeit und Maklerpreis von eeole.com.
- eeole.io, eeolee.com, echoel.de per RDAP.
- prototypefund.de direkt (HTTP 403); Angaben stützen sich auf Auszüge per Websuche.
- Bedingungen der Hamburger Förderung „Inklusive Projekte".
- Small Business Program, MFi-Status, Kontakt Anto Mandaric (nur Founder-Angabe).
- Kosten für gehostete Postfächer.

### 6.3 Widersprüche in den SBEP-Quellen (belegt)

- BMFTR-Link ist die Bekanntmachung „vom 12. September 2025" (BAnz 10.10.2025), Rahmen mit 5 Schwerpunkten, gültig bis 30.06.2027. Der aktuelle Call (Frist 16.11.2026) steht auf FONA 2026 und bluepartnership (4. Call, 4 Schwerpunkte, Vollantrag 14.06.2027, 36 Monate).
- Konsortium: BMFTR-Rahmen verlangt ≥ 3 Partner und „mindestens zwei Unternehmen der gewerblichen Wirtschaft aus zwei EU-Mitgliedsstaaten"; bluepartnership „at least two independent legal entities".
- Nur FONA nennt die Pflicht, Jahresabschluss 2025 und BWA August 2026 an ptj-sbep@ptj.de zu senden.

### 6.4 Quellen

- BMFTR-Bekanntmachung Blaue Wirtschaft (SBEP): https://www.bmftr.bund.de/SharedDocs/Bekanntmachungen/DE/2025/10/2025-10-10-bekanntmachung-blaue-wirtschaft.html
- Sustainable Blue Economy Partnership: https://bluepartnership.eu/
- AGVO Art. 6 (Anreizeffekt): https://gesetze.legal/eu/vo_eu_2014_651/6
- Prototype Fund: https://prototypefund.de/ (direkt 403, Auszüge per Websuche)
- Cloudflare Pages Limits: https://developers.cloudflare.com/pages/platform/limits/
- Cloudflare Registrar: https://www.cloudflare.com/products/registrar/
- Music WorX (Hamburg Kreativ Gesellschaft): https://kreativgesellschaft.org/innovation-inkubatoren/inkubatoren/music-worx/
- Initiative Musik: https://www.initiative-musik.de/kuenstlerinnenfoerderung/
- DPMAregister: https://register.dpma.de/DPMAregister/marke/basis
- TMview: https://www.tmdn.org/tmview/
- EUIPO eSearch: https://euipo.europa.eu/eSearch/
- WIPO Global Brand Database: https://branddb.wipo.int/
- Repo-Stellen: `ContentPipeline/CLAIMS.md` (§2, §5, Z. 85), `CLAUDE.md` Z. 13/103, `EchoelStudio/CLAUDE.md`, `memory/user.md` Z. 39, `memory/vision.md` Z. 13, `memory/decisions.md` Z. 5676, `scratchpads/archive/SESSION_LOG_before_2026-10.md` Z. 5440, `.github/workflows/pages.yml`, `wrangler.toml`, `docs/_headers`, `docs/_redirects`, `docs/CNAME`, PR #433

---

Orchester: Grok · Entscheidungen & Infrastruktur
