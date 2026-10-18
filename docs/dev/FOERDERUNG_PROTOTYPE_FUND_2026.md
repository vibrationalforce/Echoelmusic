# Förderung: Prototype Fund, Jahrgang 03 (Bewerbung bis 30.11.2026)

> Founder 2026-10-18: „Lieber Förderung.“ — Förderung geht vor Kredit und vor Investoren.
> Diese Datei ist die EINE Stelle für Fakten, Pitch und Zeitplan. Die Kalender-Termine
> (19.10. Sprechstunde, 16.11. Entwurf) zeigen hierher. Fakten tragen ein Datum; was eine
> Sitzung nicht prüfen konnte, steht als UNSICHER, nicht als Tatsache.

## 1. Fakten (geprüft 2026-10-18, Quellen in §6)

| Punkt | Stand | Sicherheit |
|---|---|---|
| Frist | **30.11.2026, 15:00 Uhr**, über bewerben.prototypefund.de, Deutsch oder Englisch | sicher (zwei Quellen) |
| Linien | **Innovation** (Datensicherheit + Software-Infrastruktur) · **Resilienz** (offene, dezentrale Alternativen zu Big Tech; selbstbestimmte Software) · Up and Coming (nur bis 25 Jahre, entfällt) | sicher |
| Summe | 47.500 € Einzelperson / 95.000 € Team (bis 4) für 6 Monate; Anschluss 4 Monate möglich (dann bis 79.000 € / 158.000 €) | sicher; Anschluss-Zahlen aus einer Quelle |
| Förderzeitraum | **ab 1. Juni 2027**, 6 Monate; Anschluss ab Dezember 2027 | UNSICHER: die offizielle Seite nennt auch „Dezember 2026 – März 2027“, vermutlich die Auswahlphase → in der Sprechstunde fragen |
| Bedingungen | nur Software (Hardware-Projekte haben einen eigenen Fonds), Open-Source-Lizenz, öffentliches Repo, Wohnsitz Deutschland, Einzelperson oder Team bis 4 | sicher |
| Echoel erfüllt | MIT-Lizenz (`LICENSE`), öffentliches Repo, Einzelperson in Hamburg | gemessen |
| Sprechstunde | **Mo 19.10.2026, 17–18 Uhr MESZ**, online | Zeit sicher (OSB-Alliance-Meldung); **Link nicht abrufbar** aus der Sitzung → prototypefund.de/bewerbung, die OSB-Meldung („hier“-Link), info@prototypefund.de oder Mastodon @PrototypeFund |

## 2. Was Echoel heute IST (nur das wird behauptet)

- **Echoel Studio** (`EchoelStudio/`): Musik-Workstation für iPhone und iPad, offline, ohne Konto,
  ohne Telemetrie, offenes JSON-Projektformat, voller Export, eigene Instrumente als AUv3,
  On-Device-Agent (nichts verlässt das Gerät). Kern = drei Swift-Pakete ohne Abhängigkeiten
  (`Core`, `DSP`, `Engine`), getestet auf macOS, gebaut für iOS; Linux ungeprüft.
- **One Clock** (`docs/one-clock.html`): freie Web-Seite, Atemzyklus an der Weltzeit, keine
  Daten, kein Server, kein Konto (PR #427).
- **Körper → Licht/Raum** über OSC, ADM-OSC, Art-Net, sACN: offene Standards, in der Alt-App
  live, in Studio verschoben, nicht gestrichen (`docs/dev/NEUPLANUNG_2026-10-18.md` §0.5).
- Nicht behaupten: Heilung, Therapie, Wellness, Meditation. Register der wahren Behauptungen:
  `ContentPipeline/CLAIMS.md`.

## 3. Satz in 20 Sekunden

„Echoelmusic ist eine offene Musik-Workstation unter MIT-Lizenz: offline, ohne Konto, ohne
Tracking, mit offenem Projektformat. Puls und Atem können Klang, Licht und Raum steuern – über
offene Standards wie OSC und ADM-OSC, ohne Abhängigkeit von einem Hersteller.“

## 4. Förderobjekt: Vorschlag, bis die Sprechstunde etwas anderes sagt

**Linie Innovation, Förderobjekt = der offene Kern als Infrastruktur**, nicht die iOS-Oberfläche:

1. `EchoelStudio/Core` + `Engine` + `DSP` als plattformunabhängige Swift-Pakete (Linux-Build als
   Nachweis), mit dokumentiertem Projektformat und Befehlskatalog.
2. Die Körper→Licht/Raum-Schnittstelle (OSC · ADM-OSC · Art-Net · sACN) als wiederverwendbare,
   abhängigkeitsfreie Bibliothek mit Doku und Beispielen.
3. One Clock als Referenz für „gemeinsame Zeit ohne Server“ (klein, aber genau der Geist).

Warum nicht Resilienz als Erstwahl: die Verteilung über Apples App Store ist der erwartbare
Einwand („Alternative zu Big Tech?“). Die Antwort darauf (Kern und Format offen, kein Konto,
offline, Projekt gehört dem Nutzer) ist Frage 1 der Sprechstunde, nicht eine Annahme.

Was im Förderzeitraum NEU entsteht (ab Juni 2027 ist 1.0 nach Plan draußen): Punkte 1–2 oben
sind Phase P3+ der Neuplanung, also echte neue Arbeit, kein Rückblick.

## 5. Zeitplan

| Datum | Was |
|---|---|
| 19.10., 17:00 | Sprechstunde: Fragen 1–7 aus dem Kalender-Termin stellen, Antworten HIER in §1 nachtragen |
| bis 16.11. | Entwurf fertig: Problem in 2 Sätzen · was entsteht · warum Open Source · Arbeitsplan 4–6 Schritte · nur CLAIMS.md-Wahrheiten. Eine Sitzung schreibt ihn auf Zuruf vor, eine Person liest gegen |
| 30.11., 15:00 | Frist |

## 6. Quellen (18.10.2026, aus Suchergebnissen; die Seiten selbst waren aus der Sitzung nicht abrufbar)

- prototypefund.de/en/application · prototypefund.de/en/blog/ptf-3-0 · prototypefund.de/en/up-and-coming
- osb-alliance.de: „Prototype Fund: Bewerbungsphase gestartet“ (Sprechstunde 19.10., 17–18 Uhr)
- foerdermittelkompass.reflecta.org/grants/prototype-fund · foerderdatenbank.d-s-e-e.de (Wohnsitz Deutschland)
