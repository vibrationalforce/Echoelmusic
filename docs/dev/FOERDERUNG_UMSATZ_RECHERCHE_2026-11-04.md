# Förderung und Umsatz für Echoel: Recherche vom 4.11.2026

Ich habe nur gelesen und gesucht. Ich habe niemanden kontaktiert und nichts verändert.

**Kurz vorweg:**
- **Prototype Fund ist die einzige Frist im November mit fertigem Entwurf.** Jahrgang 03 läuft vom 01.10. bis 30.11.2026 (Fristtag 15 Uhr laut Repo) ([prototypefund.de/en/apply](https://prototypefund.de/en/apply)). Im Repo liegt ein fast fertiger Antrag (`docs/dev/FOERDERUNG_PROTOTYPE_FUND_2026.md` §7.5). Er hält die Wortgrenzen ein und wurde in einer Jury-Simulation geprüft. Die Datei trägt seit 24.10. den Vermerk „gestrichen“.
- **Ein neuer Konflikt.** GM39 empfiehlt eine UG oder GmbH vor dem ersten Verkauf. Der Prototype Fund fördert aber „Menschen, keine Unternehmen“. Das muss vor der Abgabe schriftlich mit dem Fonds geklärt werden.

## Was im Repo steht

- **Prototype Fund (`FOERDERUNG_PROTOTYPE_FUND_2026.md`)**
  - Förderobjekt: ein eigenes offenes Paket, EchoelSense plus EchoelIO (Körpersignal-Profil, Egress-Policy, OSC/ADM-OSC/sACN, Linux-CI), Linie Innovation. Bis 47.500 € (950 h × 50 €), Second Stage bis 31.650 €. Gefördert werden nur Arbeitsstunden.
  - Hauptrisiko ist die KI-Regel. Laut §1 sind von 9.861 Commits auf `main` 8.805 unter dem Account `claude` verbucht. Die Jury-Simulation gab eine Chance von 2/5.
  - In der Sprechstunde am 19.10. hast du das Vorhaben als bestätigt gewertet (decisions.csv, Zeile 1285).
- **Entscheidungen 18.–24.10.:** Prototype Fund (Weg A), dann Installation an „Inklusive Projekte“ (Zeile 1323), dann am 24.10. alles gestoppt (Zeilen 1329 und 1330). Am 4.11. hast du Förderung wieder geöffnet (Zeile 1368).
  - ⚠️ Zeile 1330 ist noch aktiv: Die Installation ist kein Antragsgegenstand. Dein „alle Förderungen und Ideen“ widerspricht dem. Das ist eine Frage an dich.
- **`ECHOEL_VISION_2026-10-19.md` §7:** Einnahmen sind Plugins als Einmalkauf (`com.echoelmusic.app.pro`), Förderung, künstlerische Praxis, später Workshops. §7 nennt den Antrag bis 30.11. noch als laufend. Das ist veraltet gegenüber dem Vermerk vom 24.10. und wieder richtig seit dem 4.11.
- **GM39 (`FOUNDER_INBOX.md`):** Vor dem ersten Verkauf soll eine haftungsbeschränkte Gesellschaft der Herausgeber sein, dazu eine IT-Haftpflicht. Die EU-Produkthaftungsrichtlinie 2024/2853 gilt ab 9.12.2026 auch für Apps.
- **Ungeprüft im Repo:** Musikfonds „kleine Linie bis 27.11.“ (SESSION_LOG). Das habe ich nicht bestätigen können.

## Top 12 Förderungen, nach Rang

| # | Programm | Passt | Betrag | Frist | Was einreichen / Aufwand | Risiko |
|---|---|---|---|---|---|---|
| 1 | **Prototype Fund Jg. 03**, Innovation ([apply](https://prototypefund.de/en/apply)) | hoch | 47.500 € + bis 31.650 € | **30.11.2026, 15 Uhr** | Online-Formular, Entwurf §7.5 fertig; 2–3 Tage aktualisieren und gegenlesen | KI-Regel (Vibe-Coding nicht förderfähig, laut Repo §1). Keine Unternehmen als Antragsteller, also UG-Konflikt. Keine Doppelförderung. Förderzeit erst 1.6.–30.11.2027 |
| 2 | **Hamburg Projektfonds „Kultur für alle“** ([Richtlinie](https://www.hamburg.de/resource/blob/107764/ffb739f9e5a81f9757fc6fc61458115e/d-inklusive-projekte-foerderrichtlinie-kultur-fuer-alle-data.pdf), [Fristen](https://www.hamburg.de/politik-und-verwaltung/behoerden/behoerde-fuer-kultur-und-medien/themen/kulturfoerderung/antragsfristen-foerderprogramme-kultur)) | mittel-hoch | ohne festen Rahmen, 20 % Eigenanteil | Richtlinie: 01.12.; Fristenseite: **15.12.2026**; dann 01. bzw. 15.05.2027 | Projektskizze plus Kostenplan. Einzelpersonen aus Hamburg dürfen. Die Richtlinie nennt „barrierefreie Websites oder Apps“ als Beispiel; ~1–2 Tage | Die zwei Quellen nennen verschiedene Fristen, also den 1.12. als Frist nehmen. Gefördert wird ein Kulturangebot, keine App-Entwicklung. Keine Wirkungsbehauptung (Inklusion als Zugang, nicht als Heilung) |
| 3 | **NLnet**, offener Call „Restack“ ([funding](https://nlnet.nl/funding.html), [Termine](https://nlnet.nl/news/2026/20260803-phaseshift.html)) | mittel | 5.000–50.000 € | **3.1.2027**, danach am 3. jedes ungeraden Monats | Kurzformular. Gegenstand wäre die EchoelIO-Protokollbrücke als freie Bibliothek; ~1 Tag | Schwerpunkt ist Internet-Infrastruktur; ein Kreativwerkzeug passt nur über das offene Protokoll-Paket. KI-Projekte sind ausgeschlossen. Darf nicht dasselbe Arbeitspaket wie beim Prototype Fund sein (ANNAHME) |
| 4 | **InnoFounder**, IFB Innovationsstarter ([foerderdatenbank](https://www.foerderdatenbank.de/FDB/Content/DE/Foerderprogramm/Land/Hamburg/innofounder-wissensbasierte-gruendungsvorhaben.html)) | mittel | 2.500 € pro Monat, solo bis 45.000 € (18 Monate) | auf der Seite keine Frist genannt, vermutlich laufend (ANNAHME) | Businessplan, Finanzplan, Gründung mit Sitz in Hamburg; ~4–6 Tage | Das Vorhaben darf vor der Zusage nicht begonnen sein, die App ist aber in TestFlight. Schließt sich vermutlich mit dem Prototype Fund aus. Passt zur UG aus GM39 |
| 5 | **Hamburg „Inklusive Projekte“** ([Fristen](https://www.hamburg.de/politik-und-verwaltung/behoerden/behoerde-fuer-kultur-und-medien/themen/kulturfoerderung/antragsfristen-foerderprogramme-kultur)) | mittel | unbekannt | **15.11.2026** (Fenster ab 1.11.) | Projektantrag; der frühere Plan war die Installation plus Medienproduktion | Widerspricht Zeile 1330 (Installation gestrichen). In 10 Tagen sehr knapp |
| 6 | **Musikfonds**, Große Projektförderung ([Regularien](https://www.musikfonds.de/sites/default/files/dokument/2026-03/Musikfonds_Foerderregularien_Stand_20260302.pdf)) | mittel, für das Werk von Echoel | bis 50.000 €, 10 % Eigenanteil | **31.03.2027**, 18 Uhr | Ein künstlerisches Projekt der aktuellen Musik, etwa ein Live-Stück, nicht die App; ~3 Tage | Gefördert werden nicht-kommerzielle, avantgardistische Musikprojekte ([foerderdatenbank](https://www.foerderdatenbank.de/FDB/Content/DE/Foerderprogramm/Bund/BKM/musikfonds.html)). Elektronische Geräte sind nicht förderfähig |
| 7 | **Initiative Musik**, Künstler*innenförderung ([foerderdatenbank](https://www.foerderdatenbank.de/FDB/Content/DE/Foerderprogramm/Bund/InitiativeMusik/musik-kuenstlerfoerderung.html)) | mittel, für die Echoel-Releases | bis 30.000 € | 4 Runden pro Jahr; die 75. lief bis 5.10.2026, die nächste vermutlich im Q1 2027 (ANNAHME) | Produktion, Release, Marketing, Tour. Solo braucht Nachweise wie GEMA, das hast du; ~2 Tage | Fehlbedarfsfinanzierung mit Eigenanteil. Nur für Musik, nicht für Software |
| 8 | **Music WorX** 2027 (Kreativ Gesellschaft, [Seite](https://kreativgesellschaft.org/en/innovation-inkubatoren/inkubatoren/music-worx/)) | mittel-hoch | 3.200 € plus 1.500 € pro Monat für 3 Monate, keine Beteiligung | 2026 lief die Bewerbung 5.5.–17.6.; 2027 vermutlich gleich (ANNAHME) | Kurzbewerbung, Solo erlaubt, Firma nicht nötig; ~1 Tag | Kleiner Betrag, Teams werden bevorzugt. Gut für Netz und Sichtbarkeit |
| 9 | **Fonds Soziokultur** ([Übersicht](https://www.fonds-soziokultur.de/en/projectfunding/overview)) | niedrig-mittel | 5.000–30.000 €, 20 % Eigenanteil | Fenster **2.4.–2.5.2027** | Partizipatives Projekt. **Keine Einzelpersonen**, nur Initiative (≥3 Personen) oder GbR. Die Tropical-Drones-GbR käme in Frage (aus Memory) | Gesellschaftliches Thema verlangt, keine Gesundheitsrahmung |
| 10 | **Crowdfunding-Kampagnenförderung Hamburg** ([BKM 2020](https://www.hamburg.de/politik-und-verwaltung/behoerden/behoerde-fuer-kultur-und-medien/aktuelles/pressemeldungen/crowdfunding-kampagnenfoerderung-518160)) | niedrig-mittel | bis 5.000 € für Kreativleistungen aus Hamburg | unbekannt, ob das Programm noch läuft | Kurzantrag | Quelle von 2020; erst bei der Kreativ Gesellschaft nachfragen |
| 11 | **Kulturstiftung des Bundes**, Allgemeine Projektförderung ([Seite](https://kulturstiftung-des-bundes.de/en/funding/general_project_funding.html)) | niedrig-mittel | ab 50.000 €, 20 % Eigenanteil | Termine sind auf der Seite veraltet; bisher meist 31.1. und 31.7. (ANNAHME) | Internationales Kunstprojekt mit Partnerinstitution; Aufwand hoch | Internationaler Kontext Pflicht, praktisch nur mit Institution |
| 12 | **Aktion Mensch**, Förderangebot Sport/Kultur ([PDF](https://www.aktion-mensch.de/craft-static/craft/assets/downloads_und_materialien/foerderung/Foerderangebote/Aktion-Mensch_Foerderangebot_SportKultur.pdf)) | niedrig direkt, mittel über einen Partner | bis 50.000 €, Projekt mindestens 15.000 €, 90 % Förderquote | Antragszyklen ohne Datum | Nur zusammen mit einem gemeinnützigen Träger, Menschen mit Behinderung planen mit. Dass nur Organisationen antragsberechtigt sind, ist ANNAHME | Therapieprojekte sind ausgeschlossen. Das passt zur roten Linie, bedeutet aber: nie therapeutisch formulieren |

**Geprüft und aussortiert:**
- **Sovereign Tech Fund:** keine Anwendungen für Endnutzer, Mindestvolumen 50.000 €, keine Prototypen ([sovereign.tech](https://sovereign.tech/programs/fund)). Später vielleicht für EchoelIO, wenn andere Projekte es nutzen.
- **Gamecity-Prototypenförderung** (bis 80.000 €): nur digitale Spiele mit Spielregeln und Ziel; Termine 2027 noch nicht bekannt ([gamecity](https://gamecity-hamburg.de/de/foerderung/)).
- **InnoRampUp:** verlangt eine Firma im Handelsregister, jünger als 2 Jahre, Deep-Tech und Marktvalidierung ([foerderdatenbank](https://www.foerderdatenbank.de/FDB/Content/DE/Foerderprogramm/Land/Hamburg/inno-ramp-up.html)).
- **Creative Europe:** braucht ein Konsortium; der Call 2026 endete am 5.5.2026 ([EC](https://culture.ec.europa.eu/node/3995)).
- **Ohne eigene Prüfung aussortiert:** EXIST (braucht eine Hochschulanbindung, ANNAHME), EIC (unrealistisch), Hamburger Labelförderung (15.2.2027, braucht ein Label), MOIN (nur Film).
- **Nicht recherchiert:** Programme von Mozilla, Google oder Apple. Ich habe dazu nichts geprüft.

## Umsatz: was zum Produktgesetz passt (alle Summen ANNAHME)

| Weg | Form | Spanne im 1. Jahr (ANNAHME) | Voraussetzung |
|---|---|---|---|
| Eigene Plugins als Einmalkauf in der App (iOS) | IAP, App frei | 0–5.000 €; hängt stark von Reichweite ab, Musik-Apps verkaufen selten | Produkt in App Store Connect anlegen. Für Kleinentwickler unter 1 Mio. $ gilt 15 % Provision über das [Small Business Program](https://developer.apple.com/app-store/small-business-program/?page=2) |
| AUv3-Instrument in fremden Hosts | dieselbe IAP | in der Spanne darüber enthalten | Bestätigt ist bisher nur der Host AUM |
| Mac/Windows als CLAP oder VST3 | später, eigener Shop | 2027 noch 0 | eigener Vertrieb und Steuerlogik; Lizenzbedingungen des VST3-SDK prüfen |
| Bildungslizenzen und Workshops | Rechnung an Schulen und Vereine | 1.000–8.000 € | Nur anbieten, was es wirklich gibt; kein Versprechen einer „Musikschule“ (Vision §7) |
| Auftritte, Installationen, Aufträge als Künstler | Gage, GEMA/GVL | läuft schon, unabhängig von der App | Die Installation ist laut Zeile 1330 kein Geschäftsfeld im Plan; das musst du klären |

**Rechtliche Voraussetzung vor dem ersten Verkauf (GM39):**
- Eine UG oder GmbH wird Herausgeberin, dazu eine IT-Haftpflicht. Grund ist die Produkthaftungsrichtlinie ab 9.12.2026. Der Entwickler-Account zieht dann um.
- Wie sich die Kleinunternehmerregelung (§19) und die Gutschriften von Apple zusammen verhalten, habe ich nicht geprüft (ANNAHME).
- **Reihenfolge mit dem Prototype Fund:** Wenn die UG die Plugins verkauft, die auf dem geförderten Kern aufbauen, kann das gegen „keine Unternehmensprojekte“ verstoßen (Repo §1). Vor der Abgabe schriftlich fragen.

## Kalender, 6 Monate

| Datum | Was |
|---|---|
| 09.–13.11.2026 | Die drei ersten Schritte unten (nur Entwürfe) |
| 15.11.2026 | Hamburg „Inklusive Projekte“, nur wenn du die Installation wieder öffnest |
| 16.11.2026 | Prototype-Fund-Entwurf gegenlesen (der alte Termin im Repo) |
| **30.11.2026, 15 Uhr** | **Prototype Fund Jg. 03, Abgabe** |
| **01.12.2026** (sicher) bzw. 15.12. | Hamburg „Kultur für alle“ für Projekte 2027 |
| 09.12.2026 | Produkthaftungsrichtlinie gilt; Stichtag für die UG-Frage |
| **03.01.2027** | NLnet, nächste Frist |
| Q1 2027 | Initiative Musik, nächste Runde (Datum offen) |
| ~31.01.2027 | Kulturstiftung des Bundes (ANNAHME) |
| 03.03.2027 | NLnet, Folgefrist |
| März 2027 | Prototype Fund meldet sich; vor Mitte März keine Statusanfragen |
| **31.03.2027**, 18 Uhr | Musikfonds, Große Projektförderung |
| 02.04.–02.05.2027 | Fonds Soziokultur, nur mit GbR oder Initiative |
| 01. bzw. 15.05.2027 | „Kultur für alle“ für Projekte 2027 |
| ~Mai–Juni 2027 | Music WorX, Bewerbung (ANNAHME) |

## Drei billige erste Schritte, Woche ab 9.11. (nur Entwürfe)

1. **Prototype Fund wiederbeleben.**
   - §7.5 auf den Stand vom 4.11. bringen und mit `scripts/ptf-wordcount.py` neu messen.
   - Eine schriftliche Frage an info@prototypefund.de entwerfen: (a) Ist der Anteil KI-assistierter Commits ein Problem? (b) Ist eine geplante UG für den Plugin-Verkauf neben dem offenen Kern vereinbar?
   - Du schickst sie, wenn du Ja sagst.
2. **„Kultur für alle“, eine Seite.**
   - Projektskizze: barrierearme Musik-Werkstatt mit Echoel Studio für Menschen mit Einschränkungen, mit Assistenz.
   - Kostenplan mit 20 % Eigenanteil.
   - Eine Mail-Frage an die Kulturbehörde zur Passung; Zielfrist 1.12.
3. **NLnet-Kurzantrag für EchoelIO.**
   - Entwurf der freien Protokollbrücke OSC/ADM-OSC/sACN für den 3.1.2027.
   - Klar vom Arbeitspaket beim Prototype Fund abgrenzen.

**Fragen, die nur du beantworten kannst:**
- Ist die Installation wieder Antragsgegenstand? (Widerspruch zwischen Zeile 1330 und deinem Wort vom 4.11.)
- Wann gründest du die UG: vor oder nach dem Prototype Fund?
- Nimmst du Prototype Fund oder InnoFounder? Beides zusammen geht wahrscheinlich nicht.

**Für Memory, aus dieser Recherche:**
- NLnet hat die Fristen auf den 3. jedes ungeraden Monats verlegt; nächste Frist 3.1.2027.
- Die Hamburger Quellen zu „Kultur für alle“ widersprechen sich: 1.12. laut Richtlinie, 15.12. laut Fristenseite.
- Aus deinem Memory habe ich nur genutzt: GEMA-Mitgliedschaft, nie in der KSK, §19, die Tropical-Drones-GbR.
