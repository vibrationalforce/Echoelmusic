# Feld 3 — Rechtliche Grenze (EU/DE, Apple)

> ⛔ **Forschung, keine Produktaussage.** Nichts aus dieser Datei darf in App, App Store, Website, Reels, Pressetext oder Förderantrag als Wirkung von Echoel erscheinen (`docs/dev/ECHOEL_VISION_2026-10-19.md` §6c, Root-`CLAUDE.md`: Heilung/Organe/Gewebe/Wunden bleiben eine harte REJECT-Linie in Code und Copy). Die Datei beschreibt den Stand der Literatur und die Grenze, nicht das Produkt.
>
> ⚠️ **Methode.** Erstellt am 2026-10-19 von einem Workflow mit drei Recherche-Agenten (Produktions-/Hörgesundheit, Gewebe-Evidenz, Recht) und einem Prüf-Agenten. Der Netz-Proxy der Sitzung ließ nur developer.apple.com und GitHub durch; WHO, ITU, PubMed/PMC, Cochrane, EUR-Lex, BfArM und die Verlage waren gesperrt. Selbst geöffnet sind deshalb nur die Apple-Dokumentation, die App Store Review Guidelines und Repo-Dateien (Spalte „geöffnet: ja“). **Jede andere Zahl stammt aus Suchtreffer-Zusammenfassungen und muss vor jedem Zitat im Volltext geprüft werden.** Teile der Rechtskarte blieben ungeprüft, weil das Suchbudget erschöpft war (DSGVO-Urteile, DiGA, EHDS, MDR-Regel 11, § 15 MBO-Ä, Deklaration von Helsinki). Evidenzstufen A–D gelten für Gesundheitsaussagen; „n/a“ steht bei Normen, Recht und API-Fakten.

## Zusammenfassung

EVIDENZKARTE Feld 3: rechtliche Grenze in der EU und in Deutschland. Das ist keine Rechtsberatung.

WERKZEUG-GRENZE: WebFetch erreichte nur developer.apple.com. Die Primärseiten von eur-lex, gesetze-im-internet.de, BfArM, EU-Kommission, Wikipedia und PubMed scheiterten am Proxy (Host nicht freigegeben). Ich habe deshalb nur die App Review Guidelines und die Developer Program License Agreement (DPLA) selbst geöffnet (opened=true). Alles andere stammt aus Suchtreffern (opened=false). Vor jeder Veröffentlichung muss der Normtext an der Primärquelle geprüft werden.

NOTENSKALA, juristisch angepasst: A = Normtext oder höchstrichterliche Rechtsprechung, konsistent wiedergegeben. B = Leitlinie, OLG-Urteil, alte Rechtslage oder Details nur aus Sekundärquellen. C = Praxisliteratur, Einzelmeinung oder eigener Schluss. D = keine Belegung gefunden (UNBELEGT).

KERNBEFUNDE
(a) MDR: Die Werbeaussage REICHT. Die Zweckbestimmung (Art. 2 Nr. 12) ergibt sich aus Kennzeichnung, Gebrauchsanweisung UND Werbe- oder Verkaufsmaterial. Ein Disclaimer „kein Medizinprodukt“ hebt eine medizinische Zweckbestimmung nicht auf. Sobald ein medizinischer Zweck vorliegt (Diagnose, Überwachung, Vorhersage, Linderung), greift Regel 11. Software, die physiologische Prozesse überwacht, ist danach mindestens Klasse IIa und braucht eine Benannte Stelle. Ein Mess- oder Forschungsgerät ohne medizinische Zweckbestimmung ist kein Medizinprodukt (EuGH Brain Products, 2012, noch zur alten Richtlinie). Eine bloße Herzfrequenz-Anzeige ohne medizinische Aussage gilt nach Sekundärquellen zu MDCG 2019-11 in der Regel nicht als Medizinprodukt-Software.
(b) HWG gilt UNABHÄNGIG vom Medizinprodukt-Status. Nach § 1 Abs. 1 Nr. 2 erfasst es auch „andere Mittel, Verfahren, Behandlungen und Gegenstände“, sobald die Werbeaussage Krankheiten, Leiden oder krankhafte Beschwerden betrifft. § 3 (Irreführung) ist bei Vorsatz strafbar (§ 14), bei Fahrlässigkeit eine Ordnungswidrigkeit bis 20.000 € (§ 15). Das HWG gilt für produktbezogene Werbung, also auch für Website und Instagram (OLG Köln 2025), nicht aber für reine Imagewerbung. Daneben gilt das UWG mit dem Strengeprinzip (gesundheitsbezogene Werbung nur mit wissenschaftlich gesicherter Grundlage). Mitbewerber können abmahnen, nach EuGH C-21/23 auch wegen DSGVO-Verstößen.
(c) DiGA setzt dreierlei voraus: ein CE-gekennzeichnetes Medizinprodukt der Klasse I, IIa oder (seit dem DigiG 2024) IIb, die BfArM-Prüfung mit Listung und einen positiven Versorgungseffekt. Ohne Listung keine DiGA-, Rezept- oder Kassen-Sprache.
(d) Apple: Die Nummer „27.x“ ist die alte Nummerierung von 2014/2015 und existiert heute nicht mehr. Maßgeblich sind:
- 1.4.1: Genauigkeit von Gesundheitsmessungen nur mit offengelegter Methodik.
- 5.1.3: Gesundheitsdaten nicht für Werbung nutzen, keine ungenauen Daten in HealthKit schreiben, keine persönlichen Gesundheitsdaten in iCloud. Forschung am Menschen braucht Einwilligung mit den Punkten a–e und ein unabhängiges Ethik-Board.
- 5.1.1(ix): Apps im Gesundheitswesen sollen von einer juristischen Person eingereicht werden, nicht von einem Einzelentwickler.
- 2.5.1 und DPLA 3.3.3(H): HealthKit nur für Gesundheits- und Fitnesszwecke, und das muss in Marketing und Oberfläche erkennbar sein.
(e) Ethikvotum: Pflicht ist es berufsrechtlich für Ärzte (§ 15 der Berufsordnungen) und für klinische Prüfungen von Medizinprodukten (MDR/MPDG). Eine allgemeine gesetzliche Pflicht außerhalb der Medizin habe ich NICHT gefunden (UNBELEGT). Faktisch ist ein Votum trotzdem nötig, weil Apple 5.1.3(iv), Fachzeitschriften und die DSGVO-Garantien es verlangen. Für eine Privatperson heißt das: über eine Partnerinstitution gehen. Ob private Ethikkommissionen Anträge von Privatpersonen annehmen, ist UNBELEGT.
(f) DSGVO: „Gesundheitsdaten“ werden weit ausgelegt (EuGH C-184/20, C-21/23). Herzfrequenz und Atemrate einer Person sind sehr wahrscheinlich erfasst; das ist mein Schluss, ein Urteil speziell zur Herzfrequenz habe ich nicht gefunden. Zulässig wird die Verarbeitung durch die ausdrückliche Einwilligung (Art. 9 Abs. 2 lit. a) oder durch lit. j mit den Garantien aus Art. 89 und § 27 BDSG (Erforderlichkeit, Interessenabwägung, getrennte Speicherung der Zuordnungsmerkmale). Ein Broad Consent ist nach der Datenschutzkonferenz (DSK) nur eng zulässig.

REPO-BEZUG
`Sources/Echoelmusic/Bio/HealthKitWriter.swift` schreibt nach Opt-in die selbst gemessene Herzfrequenz und Atemrate (Kamera-rPPG oder BLE-Gurt) in Apple Health. Damit greift Apple 5.1.3(ii): keine ungenauen Daten in HealthKit schreiben. Ob dieser Pfad die Regel erfüllt, ist eine offene Validierungsfrage und keine erledigte Sache.

Die Produktgrenze des Repos ist STRENGER als das Recht: Wellness-Aussagen wie „unterstützt Stressabbau“ fallen nach Praxisliteratur nicht unter das HWG, sind im Repo aber trotzdem verboten. Diese Grenze bleibt richtig.

## Grenzen

1. ERLAUBT, mit Bedingung: „Wir untersuchen die Frage, ob …“ und „Das ist eine offene Forschungsfrage, kein Ergebnis.“ Bedingung: Im selben Post steht kein Download-Aufruf und kein Produktbezug mit Wirkungsversprechen, sonst ist es getarnte Werbung (§ 11 Abs. 1 Nr. 9 HWG) bzw. Irreführung (§ 3 HWG). Quelle: buzer.de § 11 HWG; gesetze-im-internet.de § 3 HWG.
2. ERLAUBT: Reine Funktionsbeschreibung ohne medizinischen Zweck, z. B. „Echoel liest die Herzfrequenz (Kamera am Finger, Brustgurt oder Apple Health) und nutzt sie als Steuersignal für Klang, Bild und Licht.“ Apple verlangt sogar, dass die HealthKit-Nutzung in Marketingtext und Oberfläche erkennbar ist. Datennutzung offen zu beschreiben ist keine Heilaussage. Quelle: App Review 2.5.1; DPLA 3.3.3(H) (opened=true).
3. ERLAUBT: „Zur Selbstbeobachtung und als künstlerisches Steuersignal, keine medizinische Diagnose.“ Das bestätigt den nicht-medizinischen Zweck, HEILT aber keine medizinische Aussage an anderer Stelle. Ein Disclaimer ist kein Feigenblatt. Quelle: MDR Art. 2 Nr. 12; BfArM-Abgrenzungspraxis.
4. VERBOTEN: „hilft bei“, „gegen“, „lindert“, „heilt“, „therapiert“, „senkt“ oder „reguliert“ in Verbindung mit Krankheiten, Leiden oder krankhaften Beschwerden. Beispiele: Angst, Panik, Depression, Schlafstörungen, Bluthochdruck, Tinnitus, Schmerzen, ADHS, Burn-out, Herzrhythmus. Das eröffnet das HWG auch ohne Medizinprodukt-Status (§ 1 Abs. 1 Nr. 2, § 3 Nr. 1 HWG; Vorsatz strafbar nach § 14) und begründet eine medizinische Zweckbestimmung (MDR Art. 2 Nr. 1/12, dann Regel 11, mindestens IIa).
5. VERBOTEN: Diagnose- und Überwachungs-Sprache: „erkennt“, „misst deine Gesundheit“, „überwacht dein Herz“, „Frühwarnung“, „Stress-Score als Gesundheitswert“, „Vorhersage“. Diagnose, Überwachung, Vorhersage und Prognose sind medizinische Zwecke nach Art. 2 Nr. 1 MDR; Überwachung physiologischer Prozesse ist nach Regel 11 IIa. Quelle: EUR-Lex 2017/745; Bristows zu Regel 11.
6. VERBOTEN: „klinisch erwiesen“, „wissenschaftlich belegt“, „Studien zeigen, dass Echoel …“ ohne gesicherte Evidenz zum PRODUKT selbst; Studien Dritter nicht auf Echoel übertragen. Gesundheitsbezogen werben darf man nur mit wissenschaftlich gesicherter Grundlage, eine umstrittene Ansicht nur mit Hinweis auf die Gegenmeinung (BGH I ZR 62/11, I ZR 204/19, I ZR 146/20; § 3 HWG; § 5 UWG). Quelle: omsels.info Strengeprinzip.
7. VERBOTEN in Publikumswerbung: „verbessert deine Gesundheit“ und „ohne Echoel fehlt deinem Körper etwas“ (§ 11 Abs. 1 Nr. 7 HWG, soweit das HWG anwendbar ist). Quelle: buzer.de § 11 HWG.
8. VERBOTEN: Erfahrungsberichte zu Symptomen wie „Seit Echoel schlafe ich wieder“ oder „meine Panikattacken sind weg“, auch nicht als Repost oder Kommentar-Antwort. Das sind irreführende Äußerungen Dritter (§ 11 Abs. 1 Nr. 11 HWG) und zugleich Wirkungszuschreibungen (§ 3 HWG). Gilt auf Website, App Store, Instagram und TikTok gleichermaßen (OLG Köln 6 U 118/24).
9. VERBOTEN: „DiGA“, „App auf Rezept“, „Kasse zahlt“, „vom BfArM geprüft“, „zugelassenes Medizinprodukt“ und „CE-zertifiziert (medizinisch)“. Nichts davon trifft zu: Eine DiGA braucht CE als Medizinprodukt, BfArM-Listung und einen positiven Versorgungseffekt. Quelle: BfArM DiGA-Leitfaden; § 5 UWG. Ein konkretes Urteil dazu: UNBELEGT.
10. VERBOTEN: Forschung als Werbeformat, also „Mach mit bei unserer Studie, lade Echoel“, ohne unabhängiges Ethik-Board und ohne Einwilligung mit den Punkten (a) Art, Zweck, Dauer, (b) Verfahren, Risiken, Nutzen, (c) Datenumgang, (d) Kontaktperson, (e) Widerruf. Quelle: App Review 5.1.3(iii)(iv); DPLA 3.3.3(D) (opened=true).
11. VERBOTEN: Bio- oder Kameradaten für Werbung, Marketing-Analytics, Retargeting oder Data Mining nutzen oder sie ohne vorherige ausdrückliche Einwilligung an Dritte weitergeben. Quelle: App Review 5.1.2(vi), 5.1.3(i); DPLA 3.3.3(H) (opened=true).
12. VERBOTEN: Persönliche Gesundheits- oder Biodaten in iCloud oder CloudKit ablegen. Falls der unverdrahtete `Core/CloudSync` je verdrahtet wird, dürfen Biodaten nicht hindurchlaufen. Quelle: App Review 5.1.3(ii); DPLA 3.3.3(D) (opened=true).
13. VERBOTEN, solange nicht validiert: Genauigkeitsaussagen zur Kamera-Herzfrequenz wie „medizinisch genau“ oder „so genau wie ein EKG“. Genauigkeitsaussagen brauchen offengelegte Daten und Methodik (App Review 1.4.1). Ungenaue Werte dürfen nicht in HealthKit landen (5.1.3(ii)); das betrifft den bestehenden Opt-in-Pfad `Sources/Echoelmusic/Bio/HealthKitWriter.swift`.
14. VERBOTEN: „Biofeedback-Therapie“ oder „Biofeedback-Training gegen …“. „Biofeedback“ als Bezeichnung des Steuersignals ist Repo-Gesetz und rechtlich unkritisch; „Therapie“ oder „gegen [Leiden]“ macht daraus ein beworbenes Verfahren mit Krankheitsbezug (§ 1 Abs. 1 Nr. 2 HWG). Eigener Schluss aus dem Normtext, ein Urteil zum Begriff ist UNBELEGT.
15. REPO-REGEL, STRENGER ALS DAS RECHT: Auch „unterstützt Entspannung“ oder „reduziert Stress“ nicht verwenden. Nach Praxisliteratur fällt das zwar nicht unter das HWG (Stress ist keine Krankheit, Quelle IWW), bleibt aber an § 5 UWG und dem Strengeprinzip messbar. Vor allem verbietet die Produktgrenze des Repos Wellness-Rahmung ausdrücklich (CLAUDE.md BRAND).
16. DATENSCHUTZ-REGEL: Bio-Rohdaten einer Person als Gesundheitsdaten behandeln. Jede Forschungsnutzung braucht eine ausdrückliche, zweckgebundene Einwilligung (Art. 9 Abs. 2 lit. a DSGVO) oder § 27 BDSG mit den Garantien aus Art. 89 (Pseudonymisierung, getrennte Speicherung der Zuordnungsmerkmale). Pauschales „für Forschung“ reicht nicht (DSK zum Broad Consent). Fehler sind auch durch Mitbewerber abmahnbar (EuGH C-21/23).
17. STRUKTUR-REGEL: Eine Forschungsspur mit gesundheitsbezogener Fragestellung läuft NICHT unter dem Echoel-Produktnamen in der App, sondern über eine Partnerinstitution mit Ethikvotum. Gründe: Apple 5.1.1(ix) sieht für das Gesundheitswesen eine juristische Person vor, 5.1.3(iv) verlangt ein unabhängiges Ethik-Board, und § 15 MBO-Ä bindet beteiligte Ärzte. Vorher gegebenenfalls die Abgrenzung nach § 6 Abs. 2 MPDG beim BfArM klären.

## Forschungsfragen

1. Wie genau sind die Herzfrequenz und die Atemrate, die Echoels Kamera-rPPG und BLE-Pfad liefern, verglichen mit einem EKG- bzw. Atemgurt-Referenzsystem (Bland-Altman-Analyse, Bedingungen Licht, Bewegung, Hauttyp)? Mit einer Partnerinstitution und Ethikvotum. Das Ergebnis entscheidet, ob der HealthKit-Schreibpfad bleiben darf und ob überhaupt eine Genauigkeitsangabe öffentlich gemacht werden darf (Apple 1.4.1, 5.1.3(ii)).
2. Verändern Spielende eines bio-reaktiven Instruments ihre Atemfrequenz während des Spiels, und hängt das von der musikalischen Abbildung ab? Gefragt als Verhaltens- und Interaktionsfrage, ausdrücklich ohne Gesundheitsendpunkt.
3. Erleben Performer und Publikum Urheberschaft und Verkörperung anders, wenn Klang und Licht vom Körper gesteuert werden? Erkennen Zuhörende, ob ein Stück körpergesteuert ist? (Musikpsychologie, Wahrnehmungsstudie mit Fragebogen, Einwilligung nach Art. 9 Abs. 2 lit. a DSGVO.)
4. Welche Artefakte, z. B. Bewegung, Fingerdruck auf der Linse oder Lichtwechsel, verfälschen die angezeigten Kohärenz- und HRV-Werte, und wie sollte eine ehrliche Anzeige von Unsicherheit aussehen? (Messmethodik, keine Gesundheitsaussage.)
5. Ist Echoel für Menschen mit eingeschränkter Feinmotorik als Instrument zugänglich, wenn Atem oder Puls statt Fingerbewegung steuern? Gefragt als Zugangs- und Usability-Frage, ausdrücklich NICHT als Therapie.
6. Ob musikalische Rückmeldung das Halten einer langsamen Atemfrequenz erleichtert, ist eine gesundheitsnahe Frage. Klärungsfrage vorab: Bleibt eine solche Studie außerhalb der MDR (Brain-Products-Linie: Messung ohne medizinischen Zweck), oder macht sie das Produkt zu einem Prüfprodukt? Zu klären vor Studienbeginn mit Rechtsberatung oder einem Antrag nach § 6 Abs. 2 MPDG beim BfArM. Ein Ergebnis darf auch bei positivem Befund nicht als Produktaussage verwendet werden, solange Echoel kein Medizinprodukt ist.
7. Welche Datenarchitektur, etwa ausschließlich lokale Verarbeitung, pseudonymisierter Export, getrennte Schlüsselhaltung und Löschfristen, erfüllt Art. 89 DSGVO und § 27 BDSG für eine Partnerstudie? Ist eine Datenschutz-Folgenabschätzung nötig? Art. 35 ist in dieser Recherche nicht belegt und muss mit dem Datenschutzbeauftragten der Partnerinstitution geklärt werden.
8. Welche Ethikkommission ist für eine nicht-ärztlich geleitete Studie mit einem Künstler als Initiator zuständig: eine Musikhochschule, ein Psychologie-Institut oder eine private Kommission? Und nimmt eine Kommission überhaupt Anträge ohne institutionelle Anbindung an? Für Privatpersonen ist das UNBELEGT.

## Befunde (35, vor der Gegenprüfung)

Die geprüfte Fassung steht in `reports/Evidenzkarte Gesundheitsforschung.md`.

### 1. EU (Amtsblatt) / EUR-Lex (2017)

- **Aussage:** Software ist nach Art. 2 Nr. 1 MDR ein Medizinprodukt, wenn der Hersteller sie für Menschen und für mindestens einen medizinischen Zweck bestimmt: unter anderem Diagnose, Verhütung, Überwachung, Vorhersage, Prognose, Behandlung oder Linderung von Krankheiten. Maßgeblich ist, was der Hersteller angibt, nicht was die Software technisch könnte.
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** Verordnung (EU) 2017/745 über Medizinprodukte, Art. 2 Nr. 1 — <https://eur-lex.europa.eu/legal-content/DE/TXT/PDF/?uri=CELEX:32017R0745>
- **Prüfnotiz:** Normtext, in mehreren Suchtreffern übereinstimmend wiedergegeben. Eur-lex war nicht erreichbar. Vorhersage und Prognose sind gegenüber der alten Richtlinie neu.

### 2. EU / BGH / CMS (2017/2023)

- **Aussage:** Antwort auf Frage (a): JA, die Werbeaussage reicht. Die Zweckbestimmung nach Art. 2 Nr. 12 MDR ist die Verwendung, für die das Produkt laut Hersteller bestimmt ist: auf der Kennzeichnung, in der Gebrauchsanweisung, im Werbe- oder Verkaufsmaterial bzw. in den Werbe- oder Verkaufsangaben und bei der klinischen Bewertung. Nach Praxisliteratur zählen dazu auch Website, App-Store-Text und Social Media.
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** MDR Art. 2 Nr. 12; BGH Beschluss I ZR 17/23; CMS: Preventive Healthcare – Wellness-Tool oder Medizinprodukt? — <https://www.taylorwessing.com/-/media/taylor-wessing/files/germany/2025/04/bgh---vorlagebeschluss---trockenluftkompressor.pdf>
- **Prüfnotiz:** Normtext (A). Der BGH nennt Art. 2 Nr. 12 im Vorlagebeschluss I ZR 17/23 ausdrücklich als Maßstab. Dass Website, App Store und Social Media dazugehören, stammt aus einer Kanzlei-Darstellung (CMS) und ist für sich nur C.

### 3. EuGH (C-219/11), Bericht Covington (2012)

- **Aussage:** Ein Gerät zur Untersuchung physiologischer Vorgänge ist nur dann ein Medizinprodukt, wenn der Hersteller es für einen medizinischen Zweck bestimmt. Der Fall: BioSemi ActiveTwo, ein Biopotential-Messsystem für EEG, EKG und EMG in der kognitionswissenschaftlichen Forschung, wurde nicht als Medizinprodukt eingestuft. Der BGH folgte dem in „Messgerät II“. Bedeutung für Echoel: Physiologie zu künstlerischen oder Forschungszwecken zu messen macht noch kein Medizinprodukt, solange kein medizinischer Zweck behauptet wird.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** CJEU clarifies medical device borderline (Brain Products v BioSemi) — <https://www.covingtonblogs.com/2012/12/26/cjeu-clarifies-medical-device-borderline/>
- **Prüfnotiz:** EuGH-Urteil, aber zur alten Richtlinie 93/42/EWG. Ob es auf die erweiterte MDR-Definition übertragbar ist, wurde nicht geprüft. Bekannt nur aus Sekundärquellen (Covington u. a.), Urteilstext nicht geöffnet.

### 4. EuGH (ECLI:EU:C:2017:947) (2017)

- **Aussage:** Der EuGH hat in C-329/16 (Snitem/Philips, 7.12.2017) entschieden, dass eigenständige Software ein Medizinprodukt sein kann. Maßgeblich sind die medizinische Zweckbestimmung durch den Hersteller und eine Funktion, die über Speichern oder Archivieren hinausgeht. Software mit CE-Kennzeichnung darf keiner zusätzlichen nationalen Zertifizierung unterworfen werden.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Urteil C-329/16 Snitem und Philips France — <https://cdn.johner-institut.de/blog/wp-content/uploads/2017/12/EuGH-Software-Medizinprodukt-Module.pdf>
- **Prüfnotiz:** Das Urteil selbst ist bestätigt. Die genauen Randnummern der zwei Voraussetzungen lagen in den Treffern nicht vor. Das PDF ist beim Johner-Institut gehostet, ich habe es nicht geöffnet.

### 5. Medical Device Coordination Group / EU-Kommission; NAMSA (2025)

- **Aussage:** MDCG 2019-11 Rev.1 (Juni 2025) ist die aktuelle, NICHT verbindliche Leitlinie zur Qualifizierung von Software. Ihr Entscheidungsbaum fragt: Ist es Software? Verarbeitet sie Daten über Speichern und Übertragen hinaus? Geschieht das zum Nutzen einzelner Patienten? Fällt der Zweck unter Art. 2 Nr. 1? Wellness- und Lifestyle-Apps ohne medizinische Aussage sind danach in der Regel keine Medizinprodukt-Software. Als Beispiel wird eine App genannt, die die Herzfrequenz über den Tag anzeigt, ohne medizinische Information oder Entscheidung: kein Medizinprodukt.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** MDCG 2019-11 rev.1 – Qualification and classification of software (Update 17.06.2025) — <https://health.ec.europa.eu/latest-updates/update-mdcg-2019-11-rev1-qualification-and-classification-software-regulation-eu-2017745-and-2025-06-17_en>
- **Prüfnotiz:** Die Veröffentlichung von Rev.1 ist durch eine EU-Meldung belegt. Die Inhalte, auch das Herzfrequenz-Beispiel, stammen nur aus Sekundärquellen (NAMSA, Johner, Emergo). Die Seite health.ec.europa.eu war nicht erreichbar.

### 6. Bristows LLP / RAPS (2019)

- **Aussage:** Regel 11 (Anhang VIII MDR) teilt Software so ein: Liefert sie Informationen für Diagnose- oder Therapieentscheidungen, ist sie IIa, bei Gefahr schwerer Verschlechterung IIb, bei Gefahr von Tod oder irreversibler Verschlechterung III. Überwacht sie physiologische Prozesse, ist sie IIa, bei vitalen Parametern mit unmittelbarer Gefahr IIb. Alle übrige Software ist Klasse I. Folge: Bekäme Echoels Bio-Anzeige einen medizinischen Zweck, wäre sie mindestens IIa, und die Konformitätsbewertung bräuchte eine Benannte Stelle.
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** Deciphering Rule 11: new guidance on the classification of software medical devices under the EU MDR — <https://www.bristows.com/news/deciphering-rule-11-new-guidance-on-the-classification-of-software-medical-devices-under-the-eu-mdr>
- **Prüfnotiz:** Normtext, übereinstimmend bei Bristows, Johner und RAPS. Eine Quelle schreibt „immediate damage“ statt „immediate danger“, also am Amtsblatt prüfen. Laut RAPS ist schon Herzfrequenz-Überwachung bei einer Routineuntersuchung IIa.

### 7. BfArM; bvitg/Bitkom/ZVEI (2017)

- **Aussage:** Ein Disclaimer wie „Dies ist kein Medizinprodukt“ hebt eine medizinische Zweckbestimmung nicht auf, wenn Kennzeichnung, Gebrauchsanweisung oder Werbung einen medizinischen Zweck vermitteln. Begriffe wie analysieren, detektieren, diagnostizieren, überwachen oder messen deuten eher auf ein Medizinprodukt hin. Ein Armband, das Herzfrequenz misst und nur für Sporttraining bestimmt ist, ist keines.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** BfArM – Rechtlicher Status, Klassifizierung, Einstufung; Checkliste Medical Apps als Medizinprodukt — <https://www.bfarm.de/DE/Medizinprodukte/Aufgaben/Feststellung-rechtlicher-Status-und-Klassifizierung/_node.html>
- **Prüfnotiz:** Stammt aus Suchtreffer-Zusammenfassungen der BfArM-Orientierungshilfe und der Bitkom/ZVEI-Checkliste von 2017, die noch zum alten MPG gehören. Welche Quelle den Satz zum Disclaimer genau trägt, ist unsicher. Ergebnisgleich mit Art. 2 Nr. 12 MDR.

### 8. BfArM (2021+)

- **Aussage:** Ein Hersteller kann beim BfArM formlos und gebührenpflichtig (§ 87 MPDG) beantragen, dass der rechtliche Status seines Produkts festgestellt wird (§ 6 Abs. 2 MPDG: Medizinprodukt, Zubehör oder Anhang-XVI-Produkt). Die erste Einordnung trifft der Hersteller selbst.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Request for classification / differentiation (§ 6 MPDG) — <https://www.bfarm.de/EN/Medical-devices/Applications-and-reports/Request-classification-differentiation/_node.html>
- **Prüfnotiz:** BfArM-Antragsseite und MPDG, nur aus Suchtreffern. Das ist der saubere Weg, falls eine Forschungsfunktion an die Grenze rückt.

### 9. GvW Graf von Westphalen (Blog); gesetze.legal (2022)

- **Aussage:** Art. 7 MDR verbietet bei Medizinprodukten irreführende Angaben in Kennzeichnung, Gebrauchsanweisung und Werbung, etwa Eigenschaften, die das Produkt nicht hat, oder verschwiegene Risiken. Die OLG Frankfurt, Köln und Hamm werten Art. 7 als Marktverhaltensregel im Sinne von § 3a UWG; Mitbewerber können also abmahnen.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Von Wundauflagen, Werbung und Wissenschaft (OLG Hamm 4 U 39/22) — <https://www.gvw.com/aktuelles/blog/detail/von-wundauflagen-werbung-und-wissenschaft>
- **Prüfnotiz:** Greift nur, wenn ein Medizinprodukt vorliegt. Für Echoel heute nicht einschlägig, wohl aber, sobald eine medizinische Zweckbestimmung entstünde.

### 10. Bundesamt für Justiz (aktuell)

- **Aussage:** Das HWG gilt nicht nur für Arzneimittel und Medizinprodukte. Nach § 1 Abs. 1 Nr. 2 erfasst es auch „andere Mittel, Verfahren, Behandlungen und Gegenstände“, sobald sich die Werbeaussage auf das Erkennen, Beseitigen oder Lindern von Krankheiten, Leiden, Körperschäden oder krankhaften Beschwerden bezieht. Auch eine Musik-App, die KEIN Medizinprodukt ist, fällt damit unter das HWG, sobald sie mit einer Krankheit in Verbindung gebracht wird.
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** Heilmittelwerbegesetz § 1 — <https://www.gesetze-im-internet.de/heilmwerbg/__1.html>
- **Prüfnotiz:** Normtext ist A. Dass das konkret für Apps gilt, folgt aus dem Wortlaut. Ein Urteil zu einer Musik- oder Wellness-App habe ich nicht gefunden (UNBELEGT).

### 11. Bundesamt für Justiz; Rheinisches Ärzteblatt (aktuell / 2024)

- **Aussage:** § 3 HWG verbietet irreführende Werbung. Irreführend ist sie insbesondere, wenn Verfahren, Gegenständen oder anderen Mitteln eine therapeutische Wirksamkeit oder Wirkungen beigelegt werden, die sie nicht haben (Nr. 1), oder wenn der Eindruck entsteht, ein Erfolg sei sicher zu erwarten (Nr. 2a). Das KG Berlin (5 U 9/24, 3.12.2024) verlangt für gesundheitsbezogene Werbung gesicherte wissenschaftliche Erkenntnisse oder einen klaren Hinweis auf die Gegenmeinung.
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** Heilmittelwerbegesetz § 3 — <https://www.gesetze-im-internet.de/heilmwerbg/__3.html>
- **Prüfnotiz:** Normtext übereinstimmend wiedergegeben; das KG-Urteil ist bekannt über das Rheinische Ärzteblatt 4/2025.

### 12. Bundesamt für Justiz (aktuell)

- **Aussage:** Wer vorsätzlich gegen § 3 HWG verstößt, macht sich strafbar (§ 14 HWG: Freiheitsstrafe bis zu einem Jahr oder Geldstrafe). Fahrlässige Verstöße sind Ordnungswidrigkeiten mit Bußgeld bis 20.000 € (§ 15 Abs. 2 und 3).
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** Heilmittelwerbegesetz §§ 14, 15 — <https://www.gesetze-im-internet.de/heilmwerbg/__15.html>
- **Prüfnotiz:** Normtext aus Suchtreffern. Die 50.000 € in § 15 gelten für ANDERE Verstöße nach Abs. 1, nicht für die Irreführung.

### 13. buzer.de / omsels.info (aktuell)

- **Aussage:** § 11 Abs. 1 HWG gilt für Publikumswerbung, also Werbung außerhalb der Fachkreise. Verboten sind unter anderem: Werbung mit der Aussage, die Gesundheit könne durch die Verwendung verbessert werden (Nr. 7); Veröffentlichungen, deren Werbezweck missverständlich oder nicht deutlich erkennbar ist (Nr. 9); Äußerungen Dritter wie Dankschreiben, wenn sie missbräuchlich, abstoßend oder irreführend sind (Nr. 11); Empfehlungen bekannter Personen (Nr. 2).
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** § 11 HWG Werbung außerhalb der Fachkreise — <https://www.buzer.de/gesetz/1998/a28553.htm>
- **Prüfnotiz:** Wortlaut von Nr. 7 und Nr. 9 über buzer.de, die Novelle 2012 aus Fachartikeln. Welche Nummern für Medizinprodukte gelten (laut Blog Nr. 7, 8, 9, 11, 12), ist nur B. Nr. 9 ist zentral für Forschungs-Posts mit verstecktem Produktbezug.

### 14. OLG Nürnberg / Bayerische Staatskanzlei (2021)

- **Aussage:** Das HWG erfasst nur produktbezogene Absatzwerbung, keine allgemeine Image- oder Unternehmenswerbung. Entscheidend ist der Gesamteindruck: Steht ein bestimmtes oder bestimmbares Produkt im Vordergrund? (OLG Nürnberg 3 U 2204/20 unter Berufung auf BGH I ZR 99/07.) Antwort auf Frage (b): Website und Social Media eines Künstlers fallen unter das HWG, sobald dort die eigene App mit Krankheitsbezug beworben wird. Reine Kunst- oder Forschungsdarstellung ohne Produktbezug fällt wahrscheinlich nicht darunter, aber getarnte Werbung verbietet § 11 Nr. 9.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** OLG Nürnberg, Endurteil v. 16.02.2021 – 3 U 2204/20 — <https://www.gesetze-bayern.de/Content/Document/Y-300-Z-GRURRS-B-2021-N-44910>
- **Prüfnotiz:** OLG-Urteil im Volltext bei gesetze-bayern.de, nur als Suchtreffer. Die Übertragung auf eine Künstler-Website ist mein Schluss (C). Ein Urteil zu Künstlern habe ich nicht gefunden.

### 15. beck-aktuell / OLG Köln (2025)

- **Aussage:** Das OLG Köln (6 U 118/24, 11.09.2025) wendet das HWG auf ein Instagram-Reel an. Pflichthinweise müssen im Video selbst stehen, ein Link in der Caption reicht nicht. Ob jemand eine „bekannte Person“ ist, wird im Einzelfall entschieden, nicht nach Followerzahl. Eine Kennzeichnung als Werbung macht eine verbotene Empfehlung nicht zulässig.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Pharmakonzern durfte nicht mit Influencerin werben (OLG Köln 6 U 118/24) — <https://www.beck-aktuell.de/heute-im-recht/rechtsprechung/olg-koeln-6u11824-werbung-arzneimittel-influencerin-heilmittelwerbegesetz-2025-10-24>
- **Prüfnotiz:** OLG-Urteil zu einem Arzneimittel, bekannt über beck-aktuell und Kanzleiberichte. Für Medizinprodukte und andere Mittel gilt das nur, soweit die jeweiligen Nummern des HWG anwendbar sind.

### 16. IWW Institut (o. J.)

- **Aussage:** Nach Praxisliteratur eröffnet „unterstützt den Stressabbau“ das HWG nicht, weil Stress keine Krankheit ist. Wo die Grenze zu Schlafstörungen, Angst oder Burn-out verläuft, ist nicht geklärt.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Das Heilmittelwerbegesetz: Gestaltung von Werbeanzeigen — <https://www.iww.de/pp/archiv/das-heilmittelwerbegesetz-gestaltung-von-werbeanzeigen-das-muessen-sie-inhaltlich-beachten-f34800>
- **Prüfnotiz:** Praxisleitfaden, kein Urteil. Für Echoel ohne Folgen, weil das Repo-Gesetz Wellness-Aussagen ohnehin verbietet. Und § 5 UWG mit dem Strengeprinzip gilt trotzdem.

### 17. omsels.info (Fundstellen BGH) (2013–2021)

- **Aussage:** Strengeprinzip: Für gesundheitsbezogene Werbung gelten besonders strenge Anforderungen an Richtigkeit, Eindeutigkeit und Klarheit (BGH I ZR 146/20, Rn. 62). Gesundheitsbezogen werben darf man nur mit wissenschaftlich gesicherter Grundlage (BGH I ZR 62/11), eine umstrittene Ansicht nur mit Hinweis auf die Gegenmeinung (BGH I ZR 204/19). Außerhalb des HWG greift § 5 UWG als Auffangtatbestand. Den Werbenden trifft oft eine sekundäre Darlegungslast.
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** Strengeprinzip – Beweislast bei gesundheitsbezogener Werbung — <https://www.omsels.info/v-das-verfahren-oder-wie-laeufts-ab/g-gerichtliche-verfahren/9-beweislast/heilmittel-lebensmittel-kosmetika-medizinprodukte-sonstige-mittel-zur-anwendung-am-koerper/strengeprinzip>
- **Prüfnotiz:** Gefestigte BGH-Linie, aber nur über eine Fundstellen-Sammlung (omsels.info) bekannt. Randnummern im Original prüfen.

### 18. Taylor Wessing / EuGH (2024)

- **Aussage:** EuGH C-21/23 (Lindenapotheke, 4.10.2024): Mitbewerber dürfen DSGVO-Verstöße über das UWG verfolgen. Schon Bestelldaten für nicht verschreibungspflichtige Arzneimittel sind Gesundheitsdaten nach Art. 9 DSGVO. Für Echoel heißt das: Abmahnrisiko besteht für Werbe- UND Datenschutzfehler.
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** ECJ: Lindenapotheke (C-21/23) — <https://www.taylorwessing.com/de/insights-and-events/insights/2024/10/ecj-lindenapotheke>
- **Prüfnotiz:** EuGH-Urteil, bekannt über Taylor Wessing und weitere Fachbeiträge. Der BGH hat die Verfahren am 27.03.2025 fortgeführt.

### 19. BfArM; BAG Selbsthilfe (2024/2025)

- **Aussage:** Antwort auf Frage (c), die DiGA-Voraussetzungen (§ 139e SGB V, DiGAV):
- Medizinprodukt der Klasse I oder IIa, seit dem DigiG 2024 auch IIb.
- Die Hauptfunktion beruht im Wesentlichen auf digitaler Technik.
- Das Konformitätsbewertungsverfahren ist abgeschlossen (CE).
- Anforderungen an Sicherheit, Funktionstauglichkeit, Qualität, Datenschutz und Informationssicherheit sind erfüllt; die Datensicherheit muss seit dem 01.01.2025 per Zertifikat nachgewiesen werden.
- Ein positiver Versorgungseffekt ist belegt.
- Eine vorläufige Aufnahme zur Erprobung dauert 12 Monate, verlängerbar um 12; für IIb ist sie nach Leitfaden nicht möglich.
- Klasse IIb muss zusätzlich einen medizinischen Nutzen durch eine prospektive Vergleichsstudie zeigen.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** DiGA-Leitfaden (Fast-Track-Verfahren); Arbeitshilfe DiGA — <https://www.bfarm.de/SharedDocs/Downloads/DE/Medizinprodukte/diga_leitfaden.pdf?__blob=publicationFile>
- **Prüfnotiz:** BfArM-Leitfaden (Version 3.5 oder 3.6) und BAG-Selbsthilfe-Arbeitshilfe, nur als Suchtreffer. Ob IIb von der Erprobung ausgeschlossen ist, ist für den Entwurf belegt; das Gesetz in Kraft am Primärtext prüfen. Fazit: Ohne CE und BfArM-Listung ist Echoel keine DiGA.

### 20. Forvis Mazars (zu OLG Brandenburg) (2025)

- **Aussage:** Werbung mit DiGA-Status, „auf Rezept“ oder Kassenerstattung ohne BfArM-Listung ist nach Wettbewerbsrecht irreführend.
- **Stufe:** D · **geöffnet:** nein
- **Quelle:** Fax-Werbung für DiGAs: OLG Brandenburg setzt klare Grenzen — <https://www.forvismazars.com/de/de/branchen/life-sciences/healthcare-life-sciences/fax-werbung-was-diga-hersteller-beachten-muessen>
- **Prüfnotiz:** UNBELEGT. Ich habe kein Urteil gefunden, das genau diesen Fall entscheidet; gefunden wurde nur OLG Brandenburg 6 U 130/24 (Fax-Werbung für eine GELISTETE DiGA). Die Aussage folgt nur aus § 5 UWG und § 3 HWG in Verbindung mit den Listungsvoraussetzungen. Als Formulierungsregel trotzdem zwingend, weil die Aussage schlicht unwahr wäre.

### 21. Apple (2026 (abgerufen 2026-10-19))

- **Aussage:** Apple 1.4.1 (Medical): Medizinische Apps, die ungenaue Daten liefern oder zur Diagnose bzw. Behandlung genutzt werden könnten, werden strenger geprüft. Genauigkeitsaussagen zu Gesundheitsmessungen müssen Daten und Methodik offenlegen; ist das nicht validierbar, wird die App abgelehnt. Messungen allein mit Gerätesensoren (z. B. Blutdruck, Blutzucker, SpO2) sind ausdrücklich nicht erlaubt. Apps sollen raten, zusätzlich einen Arzt zu konsultieren; eine regulatorische Freigabe ist zu verlinken.
- **Stufe:** A · **geöffnet:** ja
- **Quelle:** App Store Review Guidelines, 1.4.1 — <https://developer.apple.com/app-store/review/guidelines/>
- **Prüfnotiz:** Primärquelle, selbst geöffnet; die Seite trägt kein Datum („living document“). Herzfrequenz per Kamera steht nicht in der Verbotsliste, fällt aber unter die Pflicht, die Methodik für Genauigkeitsaussagen offenzulegen.

### 22. Apple (2026 (abgerufen 2026-10-19))

- **Aussage:** Apple 5.1.3 (Health and Health Research):
(i) Gesundheits-, Fitness- und Forschungsdaten dürfen nicht für Werbung, Marketing oder Data Mining genutzt oder weitergegeben werden, außer für Gesundheitsmanagement oder Forschung und dann nur mit Erlaubnis; welche Daten erhoben werden, ist offenzulegen.
(ii) Apps dürfen keine falschen oder ungenauen Daten in HealthKit schreiben und keine persönlichen Gesundheitsinformationen in iCloud speichern.
(iii) Forschung am Menschen braucht eine Einwilligung mit: (a) Art, Zweck und Dauer der Studie, (b) Verfahren, Risiken und Nutzen, (c) Vertraulichkeit und Datenumgang, (d) Kontaktperson, (e) Widerrufsweg.
(iv) Sie braucht außerdem die Zustimmung eines unabhängigen Ethik-Review-Boards, nachzuweisen auf Anfrage.
- **Stufe:** A · **geöffnet:** ja
- **Quelle:** App Store Review Guidelines, 5.1.3 (i)–(iv) — <https://developer.apple.com/app-store/review/guidelines/>
- **Prüfnotiz:** Primärquelle, selbst geöffnet. (iv) gilt unabhängig davon, ob nationales Recht ein Votum verlangt. (ii) betrifft den bestehenden HealthKitWriter-Pfad, der Herzfrequenz und Atemrate aus Kamera-rPPG oder BLE-Gurt schreibt.

### 23. Apple (2026 (abgerufen 2026-10-19))

- **Aussage:** Apple 5.1.1(ix): Apps in hochregulierten Feldern, ausdrücklich auch dem Gesundheitswesen, sollen von der juristischen Person eingereicht werden, die den Dienst erbringt, nicht von einem Einzelentwickler. Apple 5.1.2(vi): Daten aus HealthKit sowie aus Kamera- und Tiefen-APIs dürfen nicht für Marketing, Werbung oder Data Mining genutzt werden, auch nicht durch Dritte.
- **Stufe:** A · **geöffnet:** ja
- **Quelle:** App Store Review Guidelines, 5.1.1(ix) und 5.1.2(vi) — <https://developer.apple.com/app-store/review/guidelines/>
- **Prüfnotiz:** Primärquelle, selbst geöffnet. Bedeutung: Ein Gesundheits- oder Forschungsprodukt wäre für einen Einzelentwickler ein strukturelles Hindernis im App Store.

### 24. Apple (2026 (abgerufen 2026-10-19))

- **Aussage:** DPLA:
- 3.3.3(H): HealthKit darf nur für Gesundheits-, Bewegungs- oder Fitnesszwecke genutzt werden, und diese Nutzung muss in Marketingtext und Oberfläche klar erkennbar sein. Daten gehen an Dritte nur mit vorheriger ausdrücklicher Einwilligung; eine Weitergabe für medizinische Forschung kann der Nutzer erlauben.
- 3.3.3(D): Bei Forschung am Menschen müssen Teilnehmer informiert werden und einwilligen; Dritte dürfen kodierte Daten nicht re-identifizieren. Sensible Gesundheitsdaten dürfen ohne schriftliche Erlaubnis von Apple nicht über iCloud oder CloudKit laufen.
- 3.3.2: Die App darf nur für ihre zugelassene Zweckbestimmung vermarktet werden; Freigabedokumente sind auf Anfrage vorzulegen.
- App Review 2.5.1: HealthKit ist für Gesundheits- und Fitnesszwecke zu nutzen und mit der Health-App zu integrieren.
- **Stufe:** A · **geöffnet:** ja
- **Quelle:** Apple Developer Program License Agreement, 3.3.2 / 3.3.3(D) / 3.3.3(H) — <https://developer.apple.com/support/terms/apple-developer-program-license-agreement/>
- **Prüfnotiz:** Primärquelle, selbst geöffnet (Ausschnitt ab Zeichen 100.000, ohne Datum). Spannung zum Repo-Gesetz: Apple verlangt, die HealthKit-Nutzung offen zu benennen. Eine solche Datenbeschreibung ist aber KEINE Heilaussage, beides lässt sich trennen.

### 25. Apple; 9to5Mac; MobiHealthNews (2014/2015/2026)

- **Aussage:** Die Angabe „27.x HealthKit“ ist die alte Nummerierung der Review Guidelines von 2014/2015: 27.1 Recht des Vertriebslandes, 27.4 kein Data Mining, 2015 erweitert um Forschung am Menschen mit Einwilligung (27.9) und Pflicht-IRB. Die heutige Fassung kennt keinen Abschnitt 27; die Inhalte stehen in 2.5.1, 5.1.2(vi) und 5.1.3.
- **Stufe:** A · **geöffnet:** ja
- **Quelle:** App Store Review Guidelines (aktuell) / Apple sets rules for developers using HealthKit (2014) — <https://9to5mac.com/2014/09/02/apple-sets-rules-for-developers-using-healthkit-homekit-testflight-and-extensions-ahead-of-ios-8-launch>
- **Prüfnotiz:** Die aktuelle Gliederung habe ich selbst geöffnet (opened=true). Die alte Nummerierung stammt aus Berichten von 9to5Mac (2014) und MobiHealthNews (2015), die ich nicht geöffnet habe.

### 26. Landesärztekammer Brandenburg; Arbeitskreis Medizinischer Ethik-Kommissionen (AKEK) (2024)

- **Aussage:** Ärzte müssen sich vor biomedizinischer Forschung am Menschen von einer Ethikkommission bei Ärztekammer oder Medizinischer Fakultät beraten lassen (§ 15 der Berufsordnungen nach dem Muster der MBO-Ä; ausgenommen sind rein epidemiologische Vorhaben). Die Pflicht trifft Ärztinnen und Ärzte: Sobald einer beteiligt ist, braucht die Studie ein Votum.
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** Berufsrechtliche Studien; Sonstige Studien — <https://www.akek.de/sonstige-studien/>
- **Prüfnotiz:** Berufsrecht, übereinstimmend bei LÄK Brandenburg und AKEK. Nicht-Ärzte bindet es nicht unmittelbar. Was landesrechtlich darüber hinaus gilt, hängt von Kammergesetz und Satzung ab.

### 27. Ethikkommission Universität Tübingen (2021+)

- **Aussage:** Für klinische Prüfungen von Medizinprodukten gelten MDR (Art. 62 ff., Art. 74, Art. 82) und MPDG: Antrag über das DMIDS, Bewertung durch die Ethik-Kommission, ein Sponsor, qualifizierte Prüfer und Unterlagen nach Anhang XV. Das gilt nur, wenn eine Studie Sicherheit oder Leistung eines Medizinprodukts bewertet. Eine Studie, die eine Heilwirkung von Echoel zeigen soll, würde Echoel eher in diesen Rahmen ziehen.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Klinische Prüfung eines Medizinprodukts — <https://www.medizin.uni-tuebingen.de/de/medizinische-fakultaet/ethikkommission/mpg>
- **Prüfnotiz:** Universität Tübingen und MPDG, nur als Suchtreffer. Die genauen Voraussetzungen von Art. 82 hatten die Treffer nicht. Der Satz zur Wirkungsstudie ist mein Schluss (C).

### 28. RatSWD / KonsortSWD; FH Wedel (2017/2022)

- **Aussage:** Eine allgemeine gesetzliche Pflicht zum Ethikvotum für Forschung am Menschen AUSSERHALB von Arzneimittel- und Medizinprodukterecht und ärztlichem Berufsrecht habe ich in Deutschland nicht gefunden. Fakultäts-Ethikkommissionen außerhalb der Medizin sind uneinheitlich verbreitet; Zeitschriften treiben den Bedarf. Hochschulkommissionen beraten meist nur eigene Angehörige (Beispiel FH Wedel). Ob eine Privatperson ohne Institution ein Votum bekommt, etwa bei einer privaten Kommission wie der FEKI, ist UNBELEGT.
- **Stufe:** D · **geöffnet:** nein
- **Quelle:** Forschungsethische Grundsätze und Prüfverfahren in den Sozial- und Wirtschaftswissenschaften — <https://www.konsortswd.de/en/publication/forschungsethische-grundsatze-und-prufverfahren-in-den-sozial-und-wirtschaftswissenschaften/>
- **Prüfnotiz:** Die NICHT-Existenz einer Pflicht ist nicht belegt, nur nicht gefunden. RatSWD 2017/2022 und FH Wedel stützen nur die Struktur. Praktisch verlangen Apple 5.1.3(iv), Zeitschriften und die DSGVO-Garantien trotzdem ein Votum. Für eine Privatperson ist der realistische Weg eine Partnerinstitution.

### 29. World Medical Association (2024)

- **Aussage:** Die Deklaration von Helsinki (WMA, Revision Oktober 2024) verlangt in Abs. 23 unabhängige, ausreichend ausgestattete Ethikkommissionen, die eine Zustimmung entziehen und laufende Forschung aussetzen dürfen. Seit 1975 schreibt sie die Prüfung jeder Forschung am Menschen durch eine Ethikkommission vor.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Declaration of Helsinki – Revision Process 2024 — <https://www.wma.net/?p=23549>
- **Prüfnotiz:** Soft Law für medizinische Forschung. Den genauen Wortlaut von Abs. 23 zur Vorab-Zustimmung habe ich nicht verifiziert, die Angaben stammen aus WMA-Zusammenfassung und JAMA-Kommentar. Eine deutsche Fassung ist bei der ÄK Nordrhein verfügbar.

### 30. DSGVO-Portal; rechtstipp24 (Kommentar § 27 BDSG) (2016/2018)

- **Aussage:** Antwort auf Frage (f): Nach Art. 9 Abs. 1 DSGVO ist die Verarbeitung von Gesundheitsdaten grundsätzlich verboten. Ausnahmen: die ausdrückliche Einwilligung (Abs. 2 lit. a; eine stillschweigende reicht nicht) oder die Forschung nach lit. j. Lit. j verlangt eine Grundlage im Unions- oder nationalen Recht sowie Garantien nach Art. 89 Abs. 1, etwa Pseudonymisierung und Datenminimierung. In Deutschland ist das § 27 BDSG: Forschung ohne Einwilligung, wenn sie erforderlich ist und die Interessen des Verantwortlichen überwiegen; Zuordnungsmerkmale sind getrennt zu speichern. Daneben ist stets eine Rechtsgrundlage nach Art. 6 nötig.
- **Stufe:** A · **geöffnet:** nein
- **Quelle:** Artikel 9 DSGVO; § 27 BDSG Online-Kommentar — <https://www.dsgvo-portal.de/dsgvo_artikel_9.php>
- **Prüfnotiz:** Normtext aus dsgvo-portal.de und Kommentaren, nicht selbst geöffnet; die Kommentare sind teils von 2018–2022. Ob sich § 27 BDSG durch das Forschungsdatengesetz geändert hat, ist ungeprüft. Ob Art. 35 Abs. 3 lit. b (DSFA bei umfangreicher Verarbeitung besonderer Daten) greift, hat diese Suche nicht bestätigt: UNBELEGT.

### 31. Covington Inside Privacy / EuGH (2022)

- **Aussage:** Der EuGH legt sensible Daten weit aus. In C-184/20 (1.8.2022) genügt es, dass Daten mittelbar auf ein sensibles Merkmal schließen lassen. C-21/23 (2024) bestätigt das für Gesundheitsdaten. Daraus folgt: Herzfrequenz, Atemrate und HRV, die einer Person zugeordnet sind, sind sehr wahrscheinlich Gesundheitsdaten nach Art. 9.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Special category data by inference: CJEU significantly expands the scope of Article 9 GDPR — <https://www.insideprivacy.com/eu-data-protection/special-category-data-by-inference-cjeu-significantly-expands-the-scope-of-article-9-gdpr/>
- **Prüfnotiz:** Die Rechtsprechung ist A, ihre Anwendung auf die Herzfrequenz ist mein Schluss (C). Ein Urteil speziell zu Herzfrequenz- oder Fitnessdaten habe ich nicht gefunden.

### 32. Datenschutzkonferenz (über Osborne Clarke) (2019)

- **Aussage:** Einen Broad Consent (Erwägungsgrund 33: Einwilligung für bestimmte Forschungsbereiche) legt die Datenschutzkonferenz eng aus. Er ist nur zulässig, wenn sich der Zweck bei der Erhebung noch nicht vollständig bestimmen lässt, und braucht ausgleichende Maßnahmen wie Verschlüsselung oder ein positives Ethikvotum. Für Gesundheitsdaten muss zusätzlich Art. 9 Abs. 2 lit. a erfüllt sein.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Datenschutzaufsichtsbehörden präzisieren Anforderungen an Broad Consent — <https://www.osborneclarke.com/de/insights/datenschutzaufsichtsbehoerden-praezisieren-anforderungen-broad-consent-und>
- **Prüfnotiz:** DSK-Beschluss 2019, bekannt über Osborne Clarke. Folge: Eine pauschale Einwilligung wie „Daten für Forschung“ ohne konkreten Zweck reicht nicht.

### 33. beck-aktuell (2026)

- **Aussage:** Die Haushaltsausnahme (Art. 2 Abs. 2 lit. c DSGVO) gilt nur für ausschließlich persönliche oder familiäre Tätigkeiten. Wie weit sie reicht, ist offen: Der BGH hat am 17.09.2026 dem EuGH Fragen dazu vorgelegt (I ZR 256/25, I ZR 289/25). Eine Studie mit fremden Teilnehmern ist nach dem Zweck der Ausnahme nicht „ausschließlich persönlich“. Auch ein Privatforscher wäre also Verantwortlicher im Sinne der DSGVO.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Wie weit reicht die DS-GVO in den privaten Bereich? (BGH-Vorlage zur Haushaltsausnahme) — <https://www.beck-aktuell.de/heute-im-recht/rechtsprechung/bgh-izr25625-izr28925-dsgvo-haushaltsausnahme-eugh-vorlage-reichweite-2026-09-17>
- **Prüfnotiz:** Dass die Vorlage existiert, ist belegt (beck-aktuell). Die Anwendung auf Forschung ist mein Schluss; eine Quelle speziell zu Privatforschung habe ich nicht gefunden.

### 34. Heuking Kühn Lüer Wojtek (2025)

- **Aussage:** Die Verordnung über den Europäischen Gesundheitsdatenraum (EHDS, (EU) 2025/327) enthält in Art. 47–49 Kennzeichnungs- und Informationspflichten für Wellness-Apps, die Interoperabilität mit elektronischen Patientenakten behaupten, sowie eine EU-Datenbank. Die Sekundärnutzung von Gesundheitsdaten läuft über Zugangsstellen. Die Verordnung gilt im Wesentlichen ab 26.03.2027, Teile später.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** EU-Verordnung über den Europäischen Gesundheitsdatenraum (EHDS) veröffentlicht — <https://www.heuking.de/de/news-events/newsletter-fachbeitraege/artikel/eu-verordnung-ueber-den-europaeischen-gesundheitsdatenraum-ehds-veroeffentlicht.html>
- **Prüfnotiz:** Bekannt aus Kanzleiberichten (Heuking, Noerr). Für Echoel erst relevant, falls jemals eine Anbindung an Patientenakten oder eine Datenspende für Forschung behauptet würde.

### 35. Medical Device HQ (o. J.)

- **Aussage:** Rechtliche Abgrenzung nach Modalität: Anhang XVI Nr. 6 MDR (Produkte OHNE medizinischen Zweck, die trotzdem unter die MDR fallen) nennt nur Geräte, die elektrische Ströme oder magnetische bzw. elektromagnetische Felder durch die Schädeldecke einsetzen, um die Hirnaktivität zu verändern. Hörbarer Schall, Musik, Ultraschall und Ganzkörpervibration stehen nicht in dieser Liste. Ob sie Medizinprodukte sind, richtet sich allein nach der Zweckbestimmung, nicht nach der Physik.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** MDR Annex XVI — <https://medicaldevicehq.com/articles/mdr-annex-xvi/>
- **Prüfnotiz:** Wortlaut von Nr. 6 laut medicaldevicehq. Dass Schall, Ultraschall und Vibration NICHT erfasst sind, schließe ich aus dem Wortlaut (C); die vollständige Liste von Anhang XVI habe ich nicht geprüft.
