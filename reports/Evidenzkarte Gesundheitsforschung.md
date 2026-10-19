# Evidenzkarte Gesundheitsforschung

> ⛔ **Forschung, keine Produktaussage.** Nichts aus dieser Datei darf in App, App Store, Website, Reels, Pressetext oder Förderantrag als Wirkung von Echoel erscheinen (`docs/dev/ECHOEL_VISION_2026-10-19.md` §6c, Root-`CLAUDE.md`: Heilung/Organe/Gewebe/Wunden bleiben eine harte REJECT-Linie in Code und Copy). Die Datei beschreibt den Stand der Literatur und die Grenze, nicht das Produkt.
>
> ⚠️ **Methode.** Erstellt am 2026-10-19 von einem Workflow mit drei Recherche-Agenten (Produktions-/Hörgesundheit, Gewebe-Evidenz, Recht) und einem Prüf-Agenten. Der Netz-Proxy der Sitzung ließ nur developer.apple.com und GitHub durch; WHO, ITU, PubMed/PMC, Cochrane, EUR-Lex, BfArM und die Verlage waren gesperrt. Selbst geöffnet sind deshalb nur die Apple-Dokumentation, die App Store Review Guidelines und Repo-Dateien (Spalte „geöffnet: ja“). **Jede andere Zahl stammt aus Suchtreffer-Zusammenfassungen und muss vor jedem Zitat im Volltext geprüft werden.** Teile der Rechtskarte blieben ungeprüft, weil das Suchbudget erschöpft war (DSGVO-Urteile, DiGA, EHDS, MDR-Regel 11, § 15 MBO-Ä, Deklaration von Helsinki). Evidenzstufen A–D gelten für Gesundheitsaussagen; „n/a“ steht bei Normen, Recht und API-Fakten.

## Kurzfassung (Prüf-Agent)

Echoel kann Gesundheitsfragen nur als offene Forschungsfragen mit Partnern führen. Das Produkt selbst behauptet keine Wirkung auf Gehör, Gewebe oder Krankheit. Belegt ist, dass Musizierende deutlich häufiger Tinnitus, Hyperakusis und Hörverlust berichten (Meta-Analyse 2026, 67 Studien). Für Studio- und Kopfhörer-Produzierende fehlt aber eine eigene Studie, und selbst Hörschutzprogramme sind laut Cochrane nur niedrig bis sehr niedrig belegt. Ehrlich anbieten kann Echoel Messinfrastruktur statt eines Schutzversprechens: die eigene digitale Programmlautheit (BS.1770/R128) mit der Beschriftung „kein Schalldruck am Ohr“ und, nach Opt-in, die Kopfhörerpegel, die iOS selbst in HealthKit ablegt, mit Quellenangabe. Einen eigenen dB(A)-Wert am Ohr kann die App nicht berechnen, denn iOS liefert nur eine Systemlautstärke von 0 bis 1, und Apple lehnt nicht validierbare Gesundheitsmessungen ab (Guideline 1.4.1). Dass hörbarer Schall Wunden, Knochen oder Gewebe heilt, ist nicht belegt; Ultraschall- und Vibrationsbefunde stammen aus Medizinprodukten mit Kontaktkopplung im MHz-Bereich und lassen sich nicht übertragen, und selbst dieser Ultraschall (LIPUS) hilft bei frischen Frakturen laut BMJ-Review und Leitlinie nicht. Musik lindert im klinischen Rahmen das Erleben von Schmerz und Angst (Lancet 2015, 73 RCTs), Heilungsendpunkte wurden dabei aber nicht erhoben, wie der Cochrane-Review zur präoperativen Angst wörtlich festhält. Rechtlich entscheidet die Zweckbestimmung, die Kennzeichnung, Werbung und Verkaufsangaben vermitteln (MDR Art. 2 Nr. 12): Eine einzige Heilaussage auf Website, im Store oder in einem Reel macht Echoel zum Medizinprodukt-Kandidaten und öffnet unabhängig davon das HWG, das bei Vorsatz strafbar ist. Forschung mit Nutzerdaten braucht eine Einwilligung, ein unabhängiges Ethikvotum und bei Gesundheitsfragen eine juristische Person als Träger, also eine Partnerinstitution (Apple 5.1.3 und 5.1.1(ix)); ihre Ergebnisse bleiben Wissenschaft und werden nie zur Produktaussage. Zum Prüfstand dieser Karte: Apple-Dokumentation und Repo habe ich selbst geöffnet, alle anderen Zahlen nur über Suchtreffer-Zusammenfassungen gegengeprüft, dabei acht Angaben korrigiert (u. a. Schink HR 3,61 statt 3,51, die Population im Cochrane-LIPUS-Review, ein im plist fehlender gelesener HealthKit-Typ), und weil das Suchbudget erschöpft war, blieben Teile der Rechtskarte ungeprüft (DSGVO-Urteile, DiGA, EHDS, Regel 11, § 15 MBO-Ä, Helsinki).

## Grenzen für jede Kopie und jedes Feature

1. VERBOTEN: jede Heil-, Linderungs- oder Präventionsaussage, auf Website, im App Store, in Reels und in Kommentaren. Beispiele: 'heilt', 'lindert', 'hilft bei', 'gegen', 'senkt', 'reguliert', 'schützt dein Gehör', 'verhindert Tinnitus', 'beschleunigt Wund- oder Knochenheilung', 'hilft bei Angst, Schmerz oder Schlaf'. Gründe: Das HWG greift auch ohne Medizinprodukt-Status (§ 1 Abs. 1 Nr. 2, § 3; Vorsatz strafbar nach § 14, Fahrlässigkeit bis 20.000 € nach § 15 Abs. 2/3). Die Zweckbestimmung ergibt sich aus Kennzeichnung, Werbe- UND Verkaufsangaben (MDR Art. 2 Nr. 12). Dazu kommt das Repo-Gesetz (CLAUDE.md BRAND, rote Linie zu Heilung, Organen, Gewebe, Wunden).
2. VERBOTEN: Diagnose-, Überwachungs- und Vorhersagesprache wie 'erkennt', 'überwacht dein Herz', 'misst deine Gesundheit', 'Frühwarnung', 'Gehörbelastung in %'. Diagnose, Überwachung und Vorhersage sind medizinische Zwecke im Sinne der MDR. Ob jemand einen Disclaimer daneben setzt, ändert nichts: Eine Abgrenzung trägt nur, wenn die medizinische Verwendung 'hinreichend deutlich und nicht willkürlich' ausgeschlossen ist (EuGH C-219/11; BGH I ZR 53/09 'Messgerät II').
3. VERBOTEN: ein selbst berechneter dB(A)- oder Schalldruckwert 'am Ohr' aus dem eigenen Signal. AVAudioSession.outputVolume liefert nur 0–1, und nur der Nutzer setzt die Systemlautstärke (Apple-Doku, selbst geöffnet). LUFS heißt immer 'digitale Programmlautheit, kein Schalldruck am Ohr' (Repo: EchoelLoudnessMeter). Nicht validierbare Gesundheitsmessungen lehnt Apple ab (Guideline 1.4.1, selbst geöffnet).
4. ERLAUBT, mit Bedingung: Kopfhörerpegel aus Apple Health nur nach Opt-in, mit Quellenangabe 'laut Apple Health' und Apples Genauigkeitsvorbehalt. Die WHO-ITU-Referenz '80 dB(A) über 40 h pro Woche' darf nur als Zitat erscheinen, ohne 'sicher'-Ampel. Nie 'WHO-konform' oder 'H.870-zertifiziert': H.870 richtet sich an Geräte und Systeme, und professionelle Audiotechnik ist laut Scope-Text (nur in einer Drittkopie gefunden) ausgeschlossen.
5. VERBOTEN: geschätzte oder ungenaue Werte in HealthKit schreiben (Guideline 5.1.3(ii)). Das betrifft den bestehenden Opt-in-Pfad Sources/Echoelmusic/Bio/HealthKitWriter.swift, der Herzfrequenz und Atemrate aus Kamera-rPPG bzw. BLE schreibt; er bleibt nur haltbar, wenn die Genauigkeit validiert ist. Audio-Expositionswerte schreibt iOS selbst, environmentalAudioExposureEvent ist ausdrücklich nur lesbar.
6. PFLICHT: Die HealthKit-Nutzungsbeschreibung muss JEDEN gelesenen Typ nennen (Guideline 5.1.3(i): 'disclose the specific health data'). Schon heute fehlt die Atemrate: Resources/iOS/Info.plist nennt 'heart rate and HRV', gelesen werden laut Sources/Echoelmusic/Bio/EchoelBioEngine.swift auch respiratoryRate. Neue Audio-Typen gehen nur mit geändertem Text. Die plist ist founder-gated, also berichten, nicht editieren.
7. PFLICHT: Die HealthKit-Nutzung muss in Marketingtext und Oberfläche offen erkennbar sein und einem Gesundheits-, Bewegungs- oder Fitnesszweck dienen (DPLA 3.3.3(H); Guideline 2.5.1, selbst geöffnet). Das wird ehrlich als Datenbeschreibung gelöst, z. B. 'Herzfrequenz aus Apple Health als Anzeige- und Steuerwert, zur Selbstbeobachtung, keine Diagnose', ohne Wellness- oder Heilrahmung. Ob Apple künstlerische Steuerung als zulässigen Zweck wertet, ist UNBELEGT.
8. VERBOTEN: HealthKit-, Bio- und Kameradaten für Werbung, Marketing-Analytics oder Data Mining nutzen, ohne vorherige ausdrückliche Einwilligung an Dritte geben oder in iCloud bzw. CloudKit ablegen (Guidelines 5.1.2(vi), 5.1.3(i)(ii); DPLA 3.3.3(D)(H), alle selbst geöffnet). Das gilt auch, falls Core/CloudSync jemals verdrahtet wird.
9. VERBOTEN: Befunde aus Ultraschall-, Vibrations- oder Klinik-Musikstudien auf das Produkt übertragen, etwa 'wie Ultraschalltherapie' oder 'Vibrationstherapie'. LIPUS ist 1,5-MHz-Kontakt-Ultraschall mit Gel, ein Audiopfad endet unter 24 kHz, und mehr als 99,9 % des Luftschalls werden an der Haut reflektiert. Selbst LIPUS hat bei frischen Frakturen Evidenz der Stufe A gegen einen Nutzen (BMJ 2017 j656/j576; Cochrane CD008579.pub4).
10. VERBOTEN: 'Heilfrequenzen', Solfeggio, Heilaussagen zu 432 oder 528 Hz, 'DNA-Reparatur', auch nicht als Preset-Name oder Zitat. Die Evidenz liegt bei C (kleinste Surrogat-Studien) bis D. Zitate aus Raubverlagen gehören nicht in Belege (FTC gegen OMICS, 50,1 Mio. USD, bestätigt 2020). Dazu kommt das Repo-Gesetz (CLAUDE.md BRAND).
11. VERBOTEN: 'klinisch erwiesen', 'wissenschaftlich belegt' oder 'Studien zeigen, dass Echoel …' ohne eine Studie zum PRODUKT selbst. Studien Dritter, etwa Lancet 2015 zu Musik nach Operationen, belegen therapeutisch eingesetzte Interventionen im klinischen Rahmen, keine App. Gesundheitsbezogene Werbung braucht gesicherte Erkenntnis oder einen Hinweis auf die Gegenmeinung (Strengeprinzip: BGH I ZR 204/19, I ZR 146/20; KG Berlin 5 U 9/24).
12. VERBOTEN: Erfahrungsberichte zu Symptomen ('seit Echoel schlafe ich wieder'), Empfehlungen bekannter Personen und Forschungs-Posts mit verstecktem Download-Aufruf (§ 11 Abs. 1 Nr. 9 und 11 HWG; § 3 HWG). Das gilt auch für Reels, wo Pflichtangaben im Video selbst stehen müssen (OLG Köln 6 U 118/24).
13. VERBOTEN: 'DiGA', 'App auf Rezept', 'Kasse zahlt', 'vom BfArM geprüft', 'zugelassenes Medizinprodukt'. Nichts davon trifft zu (§ 5 UWG, § 3 HWG). Die DiGA-Voraussetzungen habe ich in dieser Runde nicht nachgeprüft.
14. VERBOTEN: Pausen- oder Haltungserinnerungen als Schutz verkaufen, etwa 'regeneriert das Gehör' oder 'beugt RSI und Nackenschmerz vor'. Für Pausen bei Büroarbeit ist die Evidenz sehr niedrig (Cochrane Hoe 2018), kausale Risikofaktoren bei Musiker*innen sind nicht belegt (Baadjou 2016), und Daten zum Pausenschutz des Gehörs stammen fast nur aus Tiermodellen. Zulässig ist nur der Satz: weniger Hördauer bedeutet nach dem Gleichenergie-Prinzip weniger Dosis.
15. VERBOTEN: Hörtest, Audiogramm, Hörverstärkung oder individuelle Risikoprognose. Das ist reguliertes Medizinprodukt-Terrain, siehe die FDA-Zulassung von Apples Hearing Aid Feature am 12.09.2024. Die Kopfhörersicherheit von iOS wird nicht umgangen, und Nutzer werden nicht angeleitet, sie abzuschalten; in manchen Regionen ist sie absichtlich nicht abschaltbar (Apple Support).
16. FORSCHUNGSREGEL: Jede gesundheitsbezogene Studie mit Nutzerdaten braucht eine Einwilligung mit den Punkten (a) Art, Zweck, Dauer, (b) Verfahren, Risiken, Nutzen, (c) Datenumgang, (d) Kontaktperson, (e) Widerruf, und die Zustimmung einer unabhängigen Ethikkommission (Guideline 5.1.3(iii)(iv)). Für das Gesundheitswesen sieht Apple eine juristische Person als Einreicher vor (5.1.1(ix)). Solche Studien laufen deshalb über eine Partnerinstitution und nicht unter dem Produktnamen in der App. Ein Studienergebnis wird nie zur Produktaussage.
17. REPO-REGEL, STRENGER ALS DAS RECHT: auch keine Wellness-Rahmung wie 'unterstützt Entspannung' oder 'reduziert Stress' (CLAUDE.md BRAND). Biofeedback ist ein Steuersignal und keine Therapie; 'Biofeedback-Therapie' oder 'Training gegen …' ist verboten.
18. Externe Vibroakustik-Liegen oder Vibrationsplattformen: keine Dosis-, Therapie- oder Knochendichte-Versprechen. Ganzkörpervibration ist arbeitsschutzrechtlich begrenzt (Richtlinie 2002/44/EG: A(8) 1,15 m/s², Auslösewert 0,5 m/s²; in Deutschland für die z-Achse 0,8 m/s²). Die Evidenz zur Knochendichte ist uneinheitlich (Übersicht 2024: kein signifikanter Vorteil), zur Spastik bei MS und Zerebralparese negativ (Moggio 2022).

## Forschungsfragen für Partnerinstitutionen

Jede Frage braucht eine Partnerinstitution als Träger, eine Einwilligung der Teilnehmenden und ein unabhängiges Ethikvotum; ein Ergebnis wird nie zur Produktaussage.

1. Messinfrastruktur mit einem Hörakustik-Labor oder einer Hamburger Hochschule: Zählt iOS die Ausgabe einer Dritt-App wie Echoel (AVAudioEngine, Wiedergabe-Kategorie) vollständig als Medien-Audio in headphoneAudioExposure? Und wie weit liegen Apples Schätzwerte für typische Studiokopfhörer neben einer Messung am Ohrsimulator? Ergebnis wäre eine Validierungstabelle, kein Schutzversprechen.
2. Beobachtungsstudie mit Audiologie-Partner und Ethikvotum: Welche wöchentliche Kopfhörer-Dosis (laut Apple Health, Opt-in) entsteht bei mobiler Musikproduktion im Vergleich zum normalen Hören derselben Personen? Und wie häufig sind Tinnitus und Hyperakusis bei Studio- und Elektronik-Produzierenden, audiometrisch erhoben statt per Selbstauskunft? Für diese Gruppe fehlt bisher jede Studie.
3. Randomisierte Verhaltensstudie: Verändern eine NEUTRALE Anzeige der Apple-Health-Pegel (ohne Ampel) oder lautheitsangeglichene A/B-Vergleiche beim Mischen den mittleren Abhörpegel und die Hördauer einer Session? Endpunkt ist das Verhalten, nicht der Hörschaden. Bisher gibt es dazu nur eine nicht randomisierte, entwicklernahe Vorher-nachher-Studie.
4. Validierungsstudie mit einem Messtechnik-Partner: Wie genau sind Herzfrequenz und Atemrate aus Kamera-rPPG und BLE gegenüber EKG und Atemgurt, ausgewertet nach Bland-Altman unter Licht-, Bewegungs- und Hauttyp-Bedingungen? Das Ergebnis entscheidet, ob der HealthKit-Schreibpfad bleiben darf (Guideline 5.1.3(ii)) und ob überhaupt eine Genauigkeitsangabe öffentlich sein darf (1.4.1).
5. Aufklärungsstudie mit Musikpsychologie: präregistriert und doppelblind, mit dem bit-identisch gerenderten Stück in A=432 Hz und A=440 Hz. Endpunkte sind Unterscheidbarkeit, Präferenz, Herzfrequenz und HRV. Veröffentlicht wird ausdrücklich auch ein Null-Ergebnis, das hier wahrscheinlich ist.
6. Forschungsinfrastruktur für Vibroakustik, z. B. mit der Arbeitsgruppe Kantor in Olomouc oder Musiktherapie-Studiengängen: Kann Echoel versionierte, reproduzierbare Tieffrequenz-Reizdateien samt Metadaten zu Frequenz, Amplitude, Pulsation und Lautheit liefern, die Kantor 2022 als fehlenden Berichtsstandard benennt? Ziel ist, sham-kontrollierte Studien vergleichbar zu machen. Echoel liefert dabei den Reiz, nicht die Wirkbehauptung.
7. Klinische Begleitstudie mit einem Verbrennungszentrum oder einer Wundambulanz, Ethikvotum und vorab geklärter MDR-Einordnung (ggf. Antrag nach § 6 Abs. 2 MPDG beim BfArM): Hat ein von Musiktherapeut*innen geführtes generatives Instrument beim Verbandwechsel einen Mehrwert für prozeduralen Schmerz und Angst, verglichen mit einer kuratierten Playlist und mit Kopfhörern ohne Musik? Nach Hole 2015 machte die Musikwahl kaum einen Unterschied, ein Null-Ergebnis wäre also plausibel und publizierbar. Kein Ergebnis wird zur Produktaussage.
8. Performance- und Wahrnehmungsforschung ohne Gesundheitsendpunkt, mit Musikhochschule oder Psychologie: Wie erleben Performer und Publikum Urheberschaft und Verkörperung, wenn Klang, Bild und Licht vom Körper gesteuert werden? Erkennen Zuhörende, ob ein Stück körpergesteuert ist? Und welche Artefakte (Bewegung, Fingerdruck, Lichtwechsel) verfälschen die angezeigten Bio-Werte so, dass die Anzeige ihre Unsicherheit offen darstellen muss?

## Geprüfte Befunde (67)

Nach der Gegenprüfung; Korrekturen stehen in der Prüfnotiz. Die Rohkarten je Feld liegen unter `research_notes/Evidenzkarte Gesundheitsforschung/`.

### 1. WHO / ITU (2019 (ITU-T H.870 V1: 2018))

- **Aussage:** WHO-ITU-Standard für sichere Hörgeräte (ITU-T H.870, 2018; als WHO-ITU-Standard 2019 veröffentlicht): Mode 1 für Erwachsene sind 80 dB(A) über 40 h pro Woche, Mode 2 für Kinder und empfindliche Hörer 75 dB(A) über 40 h pro Woche. Eine 'sound allowance'-Funktion erfasst die Exposition als Prozent einer Referenzdosis. Bei 100 % warnt das Gerät; bestätigt der Nutzer die Warnung nicht, wird die Ausgabe auf den Pegel des gewählten Modus abgesenkt.
- **Stufe:** n/a (Norm) · **geöffnet:** nein
- **Quelle:** Safe listening devices and systems: a WHO-ITU standard — <https://www.who.int/publications/i/item/9789241515276>
- **Prüfnotiz:** Bestätigt über Suchtreffer (WHO-Publikationsseite, Hearing Review, Canadian Audiologist). Beide Jahresangaben stimmen: ITU 08/2018, WHO-Veröffentlichung 2019. Die Norm richtet sich an Geräte und Systeme, nicht an einzelne Apps.

### 2. ITU-T (2022)

- **Aussage:** ITU-T H.870 in der Fassung 2022 wurde am 16.03.2022 genehmigt, ist in Kraft und wird von der ITU-T Study Group 21 gepflegt. Laut offizieller ITU-Zusammenfassung sind Kommunikationsgeräte und assistive Geräte vom Anwendungsbereich ausgeschlossen, Gaming-Geräte sind 'for future study'.
- **Stufe:** n/a (Norm) · **geöffnet:** nein
- **Quelle:** Recommendation ITU-T H.870 (03/2022), Summary / AAP record — <https://www.itu.int/dms_pubrec/itu-t/rec/h/T-REC-H.870-202203-I!!SUM-HTM-E.htm>
- **Prüfnotiz:** Teilweise bestätigt. Dass auch persönliche Schallverstärker (PSAPs) und professionelle Audiotechnik ausgeschlossen sind, fand ich nur in einer Drittkopie des Scope-Textes; vor jedem Zitat am ITU-PDF prüfen. Nicht geprüft habe ich die Warnschwellen 80 %/100 % und das rollende 7-Tage-Fenster.

### 3. WHO (2022)

- **Aussage:** Der WHO-Standard für Veranstaltungsorte (2022) begrenzt den mittleren Pegel auf 100 dB LAeq,15min. Er hat sechs Elemente: Pegelgrenze, Monitoring mit kalibriertem Gerät, Raumakustik und Beschallung, persönlicher Gehörschutz mit Anleitung, Ruhezonen sowie Schulung und Information des Personals.
- **Stufe:** n/a (Norm) · **geöffnet:** nein
- **Quelle:** WHO global standard for safe listening venues and events — <https://www.who.int/publications/i/item/9789240043114>
- **Prüfnotiz:** Bestätigt (WHO-Feature-Story, Publikation 9789240043114). Er gilt für Orte und Events, bei denen verstärkte Musik das Hauptangebot ist, und nicht für persönliche Wiedergabegeräte.

### 4. BMJ Global Health 7(11): e010501 (2022)

- **Aussage:** Systematischer Review und Meta-Analyse mit 33 Studien (35 Records, 19.046 Personen im Alter von 12–34 Jahren): Die gepoolte Prävalenz unsicherer Exposition über persönliche Abspielgeräte beträgt 23,81 % (95 %-KI 18,99–29,42). Für laute Veranstaltungsorte ergibt ein Modell 48,20 %. Potenziell gefährdet sind 0,67–1,35 Mrd. junge Menschen.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Prevalence and global estimates of unsafe listening practices in adolescents and young adults: a systematic review and meta-analysis — <https://gh.bmj.com/content/7/11/e010501>
- **Prüfnotiz:** Alle Zahlen bestätigt. Den Wert für Veranstaltungsorte haben die Autoren modelliert, weil der gepoolte Wert zu unsicher war (p>0,50). Gemessen wird unsicheres Verhalten, kein Hörschaden. Die Autorenreihenfolge (Dillard als Erstautorin) habe ich nicht verifiziert.

### 5. Otolaryngology–Head and Neck Surgery (AAO-HNSF) (2026)

- **Aussage:** Meta-Analyse zu Musiker*innen gegenüber Kontrollen (67 Studien, 28.311 Teilnehmende, 21 Länder): Tinnitus 42,6 % vs. 13,2 %, Hörverlust 25,7 % vs. 11,6 %, Hyperakusis 37,3 % vs. 15,3 %. Klassik und Pop/Rock unterscheiden sich nicht signifikant. Rund 63 % der Hörverlust-Fälle beruhen auf Selbstauskunft, rund 37 % sind audiometrisch bestätigt.
- **Stufe:** A (Richtung) / B (Zahlen) · **geöffnet:** nein
- **Quelle:** Auditory symptoms in recreational and professional musicians: systematic review and meta-analysis (McCray et al.) — <https://www.entnet.org/resource/over-40-of-musicians-experience-tinnitus-hearing-loss-and-hyperacusis-also-significantly-elevated/>
- **Prüfnotiz:** Bestätigt (AAO-HNSF-Pressemitteilung, HealthDay, Hearing Review), erschienen in Otolaryngol Head Neck Surg 174:305–316. Ergänzend: 76,3 % der Betroffenen berichten gelegentlichen, 15,6 % dauerhaften Tinnitus. Den Volltext habe ich nicht gesehen.

### 6. Int J Environ Res Public Health (PMC6209930) (2018)

- **Aussage:** Systematischer Review mit 41 Artikeln und 4.618 Berufsmusiker*innen: Hörverlust bei 38,6 %, bei Pop/Rock 63,5 % gegenüber 32,8 % bei Klassik, vor allem im Bereich 3–6 kHz. Tinnitus ist das häufigste Symptom, danach folgen Hyperakusis und Diplakusis.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Hearing Loss, Tinnitus, Hyperacusis, and Diplacusis in Professional Musicians: A Systematic Review (Di Stadio et al.) — <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6209930/>
- **Prüfnotiz:** Bestätigt. Die Zeitschrift ist das International Journal of Environmental Research and Public Health (2018); in der Karte war sie offen geblieben. Der Genre-Befund widerspricht McCray 2026.

### 7. Occupational and Environmental Medicine 71(7):472–476 (2014)

- **Aussage:** Historische Kohorte aus drei deutschen gesetzlichen Krankenkassen, 2004–2008: Ausgewertet wurden mehr als 3 Mio. Versicherte, darunter 2.227 Berufsmusiker*innen (0,07 %). Die rohe Inzidenzrate-Ratio für Hörverlust beträgt 1,27. Adjustierte Hazard Ratios: Hörverlust 1,45 (95 %-KI 1,28–1,65), lärmbedingter Hörverlust 3,61 (1,81–7,20), Tinnitus etwa 1,57 (57 % höher).
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Incidence and relative risk of hearing disorders in professional musicians (Schink et al.) — <https://oem.bmj.com/content/71/7/472>
- **Prüfnotiz:** KORRIGIERT: Die HR für lärmbedingten Hörverlust ist 3,61, nicht 3,51. 'ca. 7 Mio.' bezeichnet die Gesamtgröße der Kassen; eingeschlossen waren mehr als 3 Mio. Versicherte.

### 8. Archives of Environmental & Occupational Health (2021)

- **Aussage:** Studie an 27 Live-Tontechniker*innen mit Audiometrie, OAE und Fragebogen: Die Hörschwellen liegen bei mehreren Frequenzen schlechter als die Normdaten. 30 % berichten konstanten Tinnitus, 41 % eine verminderte Geräuschtoleranz. Gehörschutz wird wenig genutzt, oft weil er bei der Arbeit stört.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** The hearing health of live-music sound engineers — <https://researchers.mq.edu.au/en/publications/the-hearing-health-of-live-music-sound-engineers/>
- **Prüfnotiz:** Bestätigt: McGinnity, Beach, Cowan, Mulder; Arch Environ Occup Health 76(6):301–312, online 10/2020, Druck 2021. Es gibt keine Kontrollgruppe. Zu Studio- bzw. DAW-Produzierenden bleibt die Lage UNBELEGT.

### 9. Cochrane Database of Systematic Reviews (CD006396.pub4) (2017)

- **Aussage:** Cochrane-Review mit 29 Studien (1 zur Gesetzgebung, 11 zu Gehörschutz, 17 zu Hörschutzprogrammen): Für strengere Gesetzgebung ist die Evidenz sehr niedrig. Gehörschutz senkt die Exposition im Mittel um etwa 20 dB(A), mit niedriger Evidenz. Eine Anleitung zum Einsetzen von Ohrstöpseln verbessert die Dämpfung um 8,59 dB, mit mittlerer Evidenz und nur kurzfristig. Für Hörschutzprogramme ist die Evidenz sehr niedrig, technische Lärmminderung wurde in keiner kontrollierten Studie untersucht.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Interventions to prevent occupational noise-induced hearing loss (Tikka et al.) — <https://cochranelibrary.com/cdsr/doi/10.1002/14651858.CD006396.pub4/information/en>
- **Prüfnotiz:** Bestätigt (ASHA Evidence Map, NIOSH Cochrane Corner). Die Quelle ist hochwertig, die Evidenz selbst niedrig bis sehr niedrig.

### 10. JAMA Otolaryngology–Head & Neck Surgery (2016)

- **Aussage:** Systematischer Review (Suche bis 22.06.2015) mit 4 Originalstudien: Nur ein gut durchgeführtes RCT liegt vor. Es zeigt nach dem Konzert geringere Hörschwellenverschiebungen in der Ohrstöpsel-Gruppe. Die Evidenz ist dürftig.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** The Effect of Earplugs in Preventing Hearing Loss From Recreational Noise Exposure: A Systematic Review — <https://researchinformation.umcutrecht.nl/en/publications/the-effect-of-earplugs-in-preventing-hearing-loss-from-recreation/>
- **Prüfnotiz:** Bestätigt: Kraaijenga, Ramakers, Grolman, JAMA Otolaryngol Head Neck Surg 2016. Die Zahl von 228 gescreenten Arbeiten habe ich NICHT verifiziert. Das zugehörige Festival-RCT (Ramakers 2016) randomisierte 51 Personen, 25 mit und 26 ohne Ohrstöpsel. Endpunkt ist nur die vorübergehende Schwellenverschiebung.

### 11. International Archives of Occupational and Environmental Health (2016)

- **Aussage:** Systematischer Review mit 21 Artikeln und 5.424 Berufsmusiker*innen (1.258 Treffer gescreent): Die Punktprävalenz muskuloskelettaler Beschwerden liegt bei 9–68 %, die 12-Monats-Prävalenz bei 41–93 %, die Lebenszeitprävalenz bei 62–93 %. In 10 von 12 Studien sind Frauen häufiger betroffen, am häufigsten Nacken und Schultern. Wegen des hohen Bias-Risikos sind keine verlässlichen Aussagen zum Alter möglich.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** The occurrence of musculoskeletal complaints among professional musicians: a systematic review — <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4786597/>
- **Prüfnotiz:** Bestätigt: Kok et al., Int Arch Occup Environ Health 89(3):373–396, online 11/2015.

### 12. Occupational Medicine (2016)

- **Aussage:** Systematischer Review zu Risikofaktoren spielbedingter muskuloskelettaler Erkrankungen (1 Fall-Kontroll- und 14 Querschnittsstudien): Die methodische Qualität ist überwiegend niedrig. Assoziationen finden sich u. a. mit früheren Verletzungen, Auftrittsangst und Stress. Kausale Zusammenhänge sind nicht feststellbar, weil prospektive Studien fehlen.
- **Stufe:** D (für kausale Risikofaktor-Aussagen) · **geöffnet:** nein
- **Quelle:** Systematic review: risk factors for musculoskeletal disorders in musicians — <https://cris.maastrichtuniversity.nl/en/publications/systematic-review-risk-factors-for-musculoskeletal-disorders-in-m>
- **Prüfnotiz:** Bestätigt: Baadjou et al., Occup Med 66:614–622. Zur Ergonomie bei DAW- oder Touchscreen-Produktion bleibt die Lage UNBELEGT.

### 13. Cochrane Database of Systematic Reviews (CD008570.pub3) (2018)

- **Aussage:** Cochrane-Review mit 15 RCTs und 2.165 Beschäftigten im Büro, 14 davon mit hohem Bias-Risiko: Eine Armauflage zusammen mit einer alternativen Maus senkt Nacken- und Schulterbeschwerden (RR 0,52; 95 %-KI 0,27–0,99; 2 Studien; mittlere Qualität), Beschwerden der rechten oberen Extremität aber nicht. Für zusätzliche Pausen ist die Evidenz zu Beschwerden der oberen Extremität sehr niedrig. Schulungen zeigen keinen Effekt.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Ergonomic interventions for preventing work-related musculoskeletal disorders of the upper limb and neck among office workers (Hoe et al.) — <https://www.cochrane.org/CD008570>
- **Prüfnotiz:** Bestätigt. Die Kernaussage der Autoren lautet, solche Maßnahmen 'may or may not prevent' Beschwerden. Der RR-Wert stützt sich auf nur zwei Studien, und das Konfidenzintervall schließt die 1 gerade noch aus.

### 14. PLOS ONE (2022)

- **Aussage:** Meta-Analyse zu Mikropausen von höchstens 10 Minuten (19 Records, 22 Stichproben, N=2.335): Vitalität steigt (d=0,36), Ermüdung sinkt (d=0,35), auf die Leistung zeigt sich kein signifikanter Effekt (d=0,16). Je länger die Pause, desto größer der Leistungseffekt.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** 'Give me a break!' A systematic review and meta-analysis on the efficacy of micro-breaks — <https://doaj.org/article/c6f37b6ba159469296b2cb968b65505f>
- **Prüfnotiz:** Bestätigt: Albulescu et al., PLOS ONE 17(8):e0272460, erschienen 31.08.2022. Untersucht wurden allgemeine Arbeitsaufgaben, nichts Musikspezifisches.

### 15. Postgraduate Medical Journal (2025)

- **Aussage:** Meta-Analyse aus 7 retrospektiven Studien mit 10.715 Teilnehmenden: Übermäßige Smartphone-Nutzung geht mit Nackenschmerz einher, gepoolte adjustierte OR 2,34 (95 %-KI 1,44–3,82).
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Association of smartphone overuse and neck pain: a systematic review and meta-analysis — <https://pubmed.ncbi.nlm.nih.gov/39764644/>
- **Prüfnotiz:** Bestätigt: Postgrad Med J 101(1197):620–626, doi 10.1093/postmj/qgae200. Wegen des retrospektiven Designs ist keine Kausalität ableitbar. Den Teilbefund aus Zirek et al. habe ich nicht geprüft.

### 16. Apple Developer Documentation (2026 (abgerufen 2026-10-19))

- **Aussage:** HealthKit headphoneAudioExposure ist verfügbar ab iOS/iPadOS 13.0, watchOS 6.0, macOS 13.0 und visionOS 1.0. Die Werte haben die Einheit decibelAWeightedSoundPressureLevel und sind diskrete Werte des äquivalenten Dauerschallpegels; laut Doku 'can be automatically detected by an iPhone or Apple Watch'. environmentalAudioExposure (iOS 13 / watchOS 6) wird von der Apple Watch automatisch erfasst. environmentalSoundReduction (iOS 16 / watchOS 9) wird automatisch erfasst, wenn unterstützte Kopfhörer getragen werden.
- **Stufe:** n/a (API-Dokumentation) · **geöffnet:** ja
- **Quelle:** headphoneAudioExposure / environmentalAudioExposure / environmentalSoundReduction — <https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/headphoneaudioexposure>
- **Prüfnotiz:** Selbst geöffnet über die Doku-JSON von developer.apple.com und bestätigt. Ob iOS die Ausgabe einer Dritt-App wie Echoel als Medien-Audio mitzählt, bleibt UNBELEGT und ist am Gerät zu prüfen.

### 17. Apple Developer Documentation (2026 (abgerufen 2026-10-19))

- **Aussage:** headphoneAudioExposureEvent ist verfügbar ab iOS 14.2 und watchOS 7.1. iPhone und Watch speichern einen solchen Eintrag, wenn sie eine Benachrichtigung über laute Kopfhörer-Wiedergabe erzeugen. In manchen Regionen lässt sich das unter Einstellungen > Töne & Haptik > Kopfhörersicherheit ein- oder ausschalten. Der einzige Enum-Wert ist sevenDayLimit. environmentalAudioExposureEvent (iOS 14.0 / watchOS 7.0) entsteht, wenn der Mittelwert drei Minuten lang die Schwelle erreicht. Dieser Typ ist ausdrücklich nur lesbar: Apps können keine Schreibfreigabe anfordern.
- **Stufe:** n/a (API-Dokumentation) · **geöffnet:** ja
- **Quelle:** headphoneAudioExposureEvent / HKCategoryValueHeadphoneAudioExposureEvent / environmentalAudioExposureEvent — <https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/headphoneaudioexposureevent>
- **Prüfnotiz:** Selbst geöffnet und bestätigt. Nicht gesehen habe ich in den geöffneten Seiten die Metadatenschlüssel HKMetadataKeyAudioExposureLevel und -Duration; sie sind ungeprüft. Ob headphoneAudioExposureEvent ebenfalls nur lesbar ist, steht nicht auf der Seite (UNBELEGT).

### 18. Apple Developer Documentation (2026 (abgerufen 2026-10-19))

- **Aussage:** HealthKit vergibt die Freigabe fein gestaffelt, für Lesen und Teilen je Datentyp. Eine App erfährt nicht, ob das Lesen verweigert wurde; sie sieht dann nur selbst gespeicherte Einträge. Gewährt der Nutzer nur ein jüngeres Zeitfenster, kann die App bei einzelnen Typen volle und verweigerte Freigabe nicht unterscheiden. Für Lesen ist NSHealthShareUsageDescription Pflicht, für Schreiben NSHealthUpdateUsageDescription.
- **Stufe:** n/a (API-Dokumentation) · **geöffnet:** ja
- **Quelle:** Authorizing access to health data — <https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data>
- **Prüfnotiz:** Selbst geöffnet und bestätigt. Folge für die Oberfläche: 'keine Daten' muss neutral angezeigt werden.

### 19. Echoelmusic-Repository (2026)

- **Aussage:** Repo-Befund: Der Lesetext in Resources/iOS/Info.plist (NSHealthShareUsageDescription, Zeile 85) nennt nur 'heart rate and HRV'. Sources/Echoelmusic/Bio/EchoelBioEngine.swift (Zeilen 222–229) fordert aber Lesezugriff auf drei Typen an: heartRate, heartRateVariabilitySDNN und respiratoryRate. Audio-Expositionstypen liest das Repo nicht (git grep 'headphoneAudio|environmentalAudio' -- Sources liefert 0 Treffer).
- **Stufe:** n/a (Code-Fakt) · **geöffnet:** ja
- **Quelle:** Resources/iOS/Info.plist; Sources/Echoelmusic/Bio/EchoelBioEngine.swift — `file:///home/user/Echoelmusic/Sources/Echoelmusic/Bio/EchoelBioEngine.swift`
- **Prüfnotiz:** NEUER Befund des Gegenlesers. Der bestehende Text verschweigt schon heute einen gelesenen Typ, die Atemrate. Guideline 5.1.3(i) verlangt 'disclose the specific health data'. Die plist ist founder-gated, also berichten statt editieren. Zeilennummern geben den Stand vom 2026-10-19 wieder.

### 20. Apple Developer Documentation (2026 (abgerufen 2026-10-19))

- **Aussage:** AVAudioSession.outputVolume liefert die vom Nutzer gesetzte systemweite Lautstärke als 0,0–1,0. Laut Doku 'Only the user can directly set the system volume'; als Bedienelement in der App ist MPVolumeView vorgesehen.
- **Stufe:** n/a (API-Dokumentation) · **geöffnet:** ja
- **Quelle:** AVAudioSession.outputVolume — <https://developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume>
- **Prüfnotiz:** Selbst geöffnet und bestätigt. Daraus lässt sich ohne die Kopfhörer-Empfindlichkeit kein dB(A)-Wert am Ohr berechnen. Den Forum-Thread 749742 habe ich nicht geprüft.

### 21. Apple Support (laufend)

- **Aussage:** Laut Apple-Support warnen Kopfhörer-Benachrichtigungen, wenn die Medien-Audio-Exposition z. B. mehr als 80 dB über insgesamt 40 h in den letzten 7 Tagen erreicht; Telefonate zählen nicht. Beim nächsten Verbinden wird die Lautstärke automatisch gesenkt, der Nutzer kann sie wieder erhöhen. In manchen Ländern lässt sich die Benachrichtigung aus regulatorischen Gründen nicht abschalten. Zusätzlich gibt es 'Laute Töne reduzieren' als feste Obergrenze.
- **Stufe:** n/a (Herstellerdoku) · **geöffnet:** nein
- **Quelle:** Headphone notifications on your iPhone, iPad, or Apple Watch — <https://support.apple.com/HT211903>
- **Prüfnotiz:** Bestätigt über Suchtreffer (support.apple.com/HT211903 bzw. 108968). Den Genauigkeitsvorbehalt (Apple/Beats genauer, andere Kopfhörer aus der Lautstärke geschätzt) und den Bereich 75–100 dB habe ich NICHT geprüft.

### 22. Apple (2026 (abgerufen 2026-10-19))

- **Aussage:** App Store Review Guidelines im Wortlaut: 1.4.1 verlangt bei Genauigkeitsaussagen zu Gesundheitsmessungen offengelegte Daten und Methodik; ist das nicht validierbar, wird die App abgelehnt. Messungen von Blutdruck, Temperatur, Blutzucker oder SpO2 nur mit Gerätesensoren sind nicht erlaubt. 2.5.1: HealthKit 'should be used for health and fitness purposes and integrate with the Health app'. 5.1.1(ix): Apps im Gesundheitswesen soll eine juristische Person einreichen, kein Einzelentwickler. 5.1.2(vi): HealthKit- und Kameradaten dürfen nicht für Marketing, Werbung oder Data Mining genutzt werden. 5.1.3(i)–(iv): keine Nutzung für Werbung, die erhobenen Gesundheitsdaten sind konkret offenzulegen, keine falschen Daten in HealthKit, keine persönlichen Gesundheitsdaten in iCloud; Forschung braucht eine Einwilligung mit den Punkten (a)–(e) und die Zustimmung einer unabhängigen Ethikkommission.
- **Stufe:** n/a (Richtlinie) · **geöffnet:** ja
- **Quelle:** App Store Review Guidelines (1.4.1, 2.5.1, 5.1.1(ix), 5.1.2(vi), 5.1.3) — <https://developer.apple.com/app-store/review/guidelines/>
- **Prüfnotiz:** Selbst geöffnet und wörtlich bestätigt; Karte 2 führte die Seite als nicht geöffnet. Gelesen habe ich die ersten 100.000 von 114.428 Zeichen der Seite.

### 23. Apple (2026 (abgerufen 2026-10-19))

- **Aussage:** Apple Developer Program License Agreement (Version 6.9): Nach 3.3.3(H) darf eine App HealthKit nur für Gesundheits-, Bewegungs- oder Fitnesszwecke nutzen, 'clearly evident in Your marketing text and user interface'; an Dritte gehen Daten nur mit vorheriger ausdrücklicher Einwilligung, eine Weitergabe für medizinische Forschung kann der Nutzer erlauben. Nach 3.3.3(D) braucht Forschung am Menschen eine Einwilligung, Dritte dürfen kodierte Daten nicht re-identifizieren, und sensible Gesundheitsdaten dürfen ohne schriftliche Erlaubnis von Apple nicht über iCloud oder CloudKit laufen. Nach 3.3.2 darf die App nur 'for its cleared or approved intended use' vermarktet werden.
- **Stufe:** n/a (Vertrag) · **geöffnet:** ja
- **Quelle:** Apple Developer Program License Agreement 3.3.2 / 3.3.3(D) / 3.3.3(H) — <https://developer.apple.com/support/terms/apple-developer-program-license-agreement/>
- **Prüfnotiz:** Selbst geöffnet und bestätigt. Das Recht, Freigabedokumente auf Anfrage zu verlangen, stand nicht im gelesenen Ausschnitt von 3.3.2. Daraus folgt eine Spannung zum Repo-Gesetz: Apple verlangt, dass die HealthKit-Nutzung als Gesundheits- oder Fitnesszweck erkennbar ist. Ob eine rein künstlerische Steuerung akzeptiert wird, ist UNBELEGT.

### 24. Europäische Kommission (Spiegel: legislation.gov.uk) (2009)

- **Aussage:** Kommissionsbeschluss 2009/490/EG vom 23.06.2009, Art. 3 (gestützt auf Art. 4 Abs. 1 lit. a der Richtlinie 2001/95/EG): Bei 80 dB(A) ist die Exposition auf 40 h pro Woche zu begrenzen, bei 89 dB(A) auf 5 h pro Woche, dazwischen gilt lineare Inter- und Extrapolation. Persönliche Musikabspielgeräte müssen angemessen vor den Risiken warnen und informieren.
- **Stufe:** n/a (Recht) · **geöffnet:** nein
- **Quelle:** Commission Decision 2009/490/EC, Article 3 — <https://www.legislation.gov.uk/eudn/2009/490/article/3/data.html>
- **Prüfnotiz:** Art. 3 bestätigt (Kopie auf legislation.gov.uk, LawPlayer). Die Erwägungsgründe beschreiben die Risikoannahme abweichend; maßgeblich ist Art. 3. Die Angaben zu EN 50332-3 und 1,6 Pa²h habe ich NICHT geprüft.

### 25. Europäisches Parlament und Rat (Spiegel: legislation.gov.uk) (2003)

- **Aussage:** Lärmschutz-Richtlinie 2003/10/EG: unterer Auslösewert 80 dB(A) bzw. 112 Pa Spitze, oberer Auslösewert 85 dB(A) bzw. 140 Pa, Expositionsgrenzwert 87 dB(A) bzw. 200 Pa. Gehörschutz wird nur beim Grenzwert angerechnet, nicht bei den Auslösewerten.
- **Stufe:** n/a (Recht) · **geöffnet:** nein
- **Quelle:** Directive 2003/10/EC, Article 3 — <https://www.legislation.gov.uk/eudr/2003/10/article/3>
- **Prüfnotiz:** Werte bestätigt. Die Übergangsfrist für Musik und Unterhaltung bis 15.02.2008 und den Verhaltenskodex habe ich NICHT verifiziert.

### 26. MDCG / Europäische Kommission (2025)

- **Aussage:** MDCG 2019-11 Rev.1 ist am 17.06.2025 erschienen. Laut Sekundärquellen bringt die Fassung keine inhaltlichen Änderungen, sondern Klarstellungen, u. a. zu Grenzfällen bei Wellness-Apps; reine Verwaltungs- oder allgemeine Wellness-Software fällt nicht darunter.
- **Stufe:** n/a (Leitlinie, nicht bindend) · **geöffnet:** nein
- **Quelle:** Update – MDCG 2019-11 rev.1 Qualification and classification of software — <https://health.ec.europa.eu/latest-updates/update-mdcg-2019-11-rev1-qualification-and-classification-software-regulation-eu-2017745-and-2025-06-17_en>
- **Prüfnotiz:** Erscheinen bestätigt (Meldung der EU-Kommission, Emergo). Das in Karte 3 genannte Beispiel einer Herzfrequenz-App ohne medizinische Aussage habe ich NICHT verifiziert; es darf nicht als Beleg zitiert werden, bevor es im PDF gefunden ist.

### 27. U.S. FDA (2024)

- **Aussage:** Die FDA hat am 12.09.2024 Apples Hearing Aid Feature als erste rezeptfreie Hörgeräte-Software zugelassen, als reine Software-App für Medizinzwecke für AirPods Pro. Zielgruppe sind Erwachsene ab 18 Jahren mit wahrgenommener leichter bis mittlerer Schwerhörigkeit. Die Einstellung erfolgt selbst am iOS-Gerät auf Basis von Hördaten aus HealthKit.
- **Stufe:** n/a (regulatorischer Fakt) · **geöffnet:** nein
- **Quelle:** FDA authorizes first over-the-counter hearing aid software — <https://www.fda.gov/news-events/press-announcements/fda-authorizes-first-over-counter-hearing-aid-software>
- **Prüfnotiz:** Bestätigt (FDA-Pressemitteilung laut Suchtreffer, Axios). Das zeigt: Hörtest und Hörunterstützung sind regulierte Medizinprodukt-Funktionen.

### 28. Echoelmusic-Repository (2026)

- **Aussage:** Repo-Befund: EchoelLoudnessMeter misst die DIGITALE Programmlautheit nach BS.1770-4 / EBU R128: momentan (400 ms), kurzzeitig (3 s), integriert und LRA in LUFS bzw. LU. Die K-Gewichtung wird je Abtastrate abgeleitet, bei nicht unterstützten Raten misst der Meter ausdrücklich nicht. LoudnessTarget bietet Streaming −14, Podcast −16, Broadcast −23 und Kino −24 LUFS an, mit True-Peak-Zielen von −1 bzw. −2.
- **Stufe:** n/a (Code-Fakt) · **geöffnet:** ja
- **Quelle:** Sources/Echoelmusic/DSP/EchoelLoudnessMeter.swift; Sources/Echoelmusic/Core/LoudnessTarget.swift — `file:///home/user/Echoelmusic/Sources/Echoelmusic/DSP/EchoelLoudnessMeter.swift`
- **Prüfnotiz:** Selbst gelesen. Die Messung bezieht sich auf digitale Vollaussteuerung und sagt nichts über dB(A) am Ohr.

### 29. The BMJ 2017;356:j656 (Schandelmaier et al.) (2017)

- **Aussage:** LIPUS bei Frakturen und Osteotomien: In 26 RCTs (Median 30 Teilnehmende, Spanne 8–501) gegen Sham oder kein Gerät hat LIPUS mit mittlerer bis hoher Gewissheit (GRADE) wenig oder keinen Einfluss auf patientenrelevante Endpunkte.
- **Stufe:** A (konsistent GEGEN Nutzen) · **geöffnet:** nein
- **Quelle:** Low intensity pulsed ultrasound for bone healing: systematic review of randomized controlled trials — <https://www.bmj.com/content/356/bmj.j656.abstract>
- **Prüfnotiz:** Bestätigt (BMJ-Abstract, Pressemitteilung). Es handelt sich um Kontakt-Ultraschall, nicht um hörbaren Schall.

### 30. The BMJ 2017;356:j576 (Poolman et al.) (2017)

- **Aussage:** Die BMJ Rapid Recommendation empfiehlt einstimmig GEGEN LIPUS bei jeder Fraktur oder Osteotomie. Grundlage ist, mit mittlerer bis hoher Gewissheit, kaum ein Effekt auf Rückkehr zur Arbeit, Vollbelastung, Schmerz, Folgeoperationen und radiologische Heilungszeit.
- **Stufe:** A (Leitlinie, gegen Nutzen) · **geöffnet:** nein
- **Quelle:** Low intensity pulsed ultrasound (LIPUS) for bone healing: a clinical practice guideline — <https://orthobuzz.jbjs.org/2017/04/06/guest-post-is-there-a-role-for-lipus-in-bone-healing/>
- **Prüfnotiz:** Bestätigt. Kritik (OrthoBuzz): Die Empfehlung stützt sich stark auf TRUST, wo fast alle Frakturen heilten; der Nutzen bei etablierten Pseudarthrosen ist damit nicht geprüft. Hintergrund: Die FDA hat LIPUS 1994 zugelassen.

### 31. The BMJ (Busse et al.) (2016)

- **Aussage:** TRUST-Studie: verblindete, sham-kontrollierte RCT mit 501 Patient*innen an 43 nordamerikanischen Traumazentren, Einschluss 10/2008–09/2012, ein Jahr Nachbeobachtung, Tibiafraktur mit Marknagel. LIPUS beschleunigte weder die funktionelle Erholung noch die radiologische Heilung.
- **Stufe:** B (eine große, hochwertige RCT; negativ) · **geöffnet:** nein
- **Quelle:** Re-evaluation of low intensity pulsed ultrasound in treatment of tibial fractures (TRUST) — <https://pmc.ncbi.nlm.nih.gov/articles/PMC5080446>
- **Prüfnotiz:** Bestätigt: BMJ 2016;355:i5351, erschienen 25.10.2016. Die Angabe '1 Pseudarthrose bei 195 Sham-Patienten' habe ich nicht geprüft.

### 32. Cochrane (Searle et al.; CD008579.pub4) (2023)

- **Aussage:** Cochrane-Review (Update 2023) mit 21 Studien zu 1.543 Frakturen bei 1.517 Erwachsenen mit AKUTEN Frakturen (20 Studien zu LIPUS, 1 zu Stoßwelle, keine zu HIFUS): Mit mittlerer Gewissheit gibt es nach 6–12 Monaten wahrscheinlich kaum oder keinen Unterschied in der RATE verzögerter Heilung oder Pseudarthrose. Mit niedriger Gewissheit verkürzt LIPUS die Zeit bis zur Rückkehr zur Arbeit nicht. Alle Studien haben in mindestens einer Domäne ein unklares oder hohes Bias-Risiko.
- **Stufe:** A (gegen Nutzen; mittlere Gewissheit) · **geöffnet:** nein
- **Quelle:** Ultrasound and shockwave therapy for acute fractures in adults — <https://cochranelibrary.com/cdsr/doi/10.1002/14651858.CD008579.pub4>
- **Prüfnotiz:** KORRIGIERT: Die Fassung der Karte ('bei verzögerter Heilung bzw. Pseudarthrose kein Unterschied') ist in diesem Punkt widerlegt. Der Review untersucht frische Frakturen; verzögerte Heilung und Pseudarthrose sind dort ein ENDPUNKT, nicht die Population. Zur Behandlung bereits bestehender Pseudarthrosen sagt er nichts, dafür siehe NICE und G-BA. Die Zahlen '7 Studien, 746 Teilnehmende' habe ich nicht verifiziert.

### 33. NICE (MTG12 / HTG296) (2013, Überprüfung 2019)

- **Aussage:** NICE befürwortet EXOGEN bei Röhrenknochen-Frakturen mit Pseudarthrose, also ohne Heilung nach 9 Monaten. Die geschätzte Einsparung liegt bei 2.407 GBP pro Patient (Stand 2019, vorher 1.164 GBP), vor allem durch vermiedene Operationen. Bei verzögerter Heilung nach etwa 3 Monaten ist die Lage unsicher.
- **Stufe:** C–B (Leitlinie für Nischenindikation) · **geöffnet:** nein
- **Quelle:** EXOGEN ultrasound bone healing system for long bone fractures with non-union or delayed healing — <https://nice.org.uk/guidance/MTG12/chapter/1-recommendations>
- **Prüfnotiz:** Bestätigt. Die Jahresfrage ist geklärt: MTG12 erschien 2013 und wurde am 08.10.2019 überprüft, die Empfehlung blieb unverändert. Die Leitlinie ist inzwischen als HTG296 geführt. Die Kostenangabe stammt laut Treffer aus einer Herstellermitteilung, die NICE-Zahlen wiedergibt.

### 34. Gemeinsamer Bundesausschuss (G-BA) (2023)

- **Aussage:** Der G-BA lässt die Erprobungsstudie PiNGUin durchführen, vom Universitätsklinikum Essen und vom BG Klinikum Duisburg. Sie prüft, ob niedrigdosierter gepulster Ultraschall bei Pseudarthrose der Operation in der Heilungsrate nicht unterlegen ist. Die Behandlung läuft 20 min täglich über 200 Tage; primärer Endpunkt ist die Frakturheilung nach 12 Monaten. Die Erprobungs-Richtlinie wurde am 19.01.2023 beschlossen und trat am 21.04.2023 in Kraft.
- **Stufe:** C (Potenzial anerkannt, Nutzen NICHT belegt; Studie läuft) · **geöffnet:** nein
- **Quelle:** PiNGUin – Niedrigdosierter gepulster Ultraschall bei Pseudarthrosen; Erprobungs-Richtlinie — <https://www.g-ba.de/studien/erprobung/pinguin-studie/>
- **Prüfnotiz:** Bestätigt und präzisiert. Den IQWiG-Auftrag E21-07 und das Jahr 2021 fand ich NICHT, beide sind unverifiziert.

### 35. BMC Women's Health (2024)

- **Aussage:** Übersicht über 15 systematische Reviews (12 Meta-Analysen, 3 qualitative; Suche bis 31.07.2023): Ganzkörpervibration bringt postmenopausalen Frauen keinen signifikanten Vorteil für die Knochendichte. Nach AMSTAR-2 sind 13 der 15 Reviews von kritisch niedriger Qualität, nach ROBIS haben 8 ein hohes Bias-Risiko. Nur 5 Reviews berichten Nebenwirkungen, keine davon schwer.
- **Stufe:** B (uneinheitlich, methodisch schwach) · **geöffnet:** nein
- **Quelle:** Effects of whole-body vibration on bone mineral density in postmenopausal women: an overview of systematic reviews — <https://pubmed.ncbi.nlm.nih.gov/39107743/>
- **Prüfnotiz:** Bestätigt: Yin et al., BMC Womens Health 24(1):444, erschienen 06.08.2024.

### 36. Osteoporosis International (2023)

- **Aussage:** Meta-Analyse von RCTs: Ganzkörpervibration wirkt signifikant positiv auf die Knochendichte postmenopausaler Frauen. Die Evidenz ist 'hoher Qualität' für hochfrequente, niedrigmagnitudige Vibration mit hoher kumulativer Dosis.
- **Stufe:** B (Widerspruch zur Übersicht 2024) · **geöffnet:** nein
- **Quelle:** Effectiveness of whole-body vibration on bone mineral density in postmenopausal women: a systematic review and meta-analysis of randomized controlled trials — <https://pubmed.ncbi.nlm.nih.gov/36282343/>
- **Prüfnotiz:** Bestätigt: Osteoporos Int 34(1):29–52, epub 10/2022. Der Befund zu hochfrequenter, niedrigmagnitudiger Vibration beruht auf Subgruppenanalysen.

### 37. Osteoporosis International (2016)

- **Aussage:** Meta-Analyse aus 15 RCTs: In der Primäranalyse findet sich kein Unterschied bei der Knochendichte. Effekte zeigen sich nur in Sensitivitäts- und Subgruppenanalysen, an der LWS sowie teils an Schenkelhals und Trochanter.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Effects of whole body vibration on bone mineral density in postmenopausal women: a systematic review and meta-analysis — <https://pubmed.ncbi.nlm.nih.gov/27145947/>
- **Prüfnotiz:** Bestätigt: Oliveira et al., Osteoporos Int 27(10):2913–2933.

### 38. Annals of Internal Medicine (2011)

- **Aussage:** RCT mit 202 gesunden postmenopausalen Frauen (T-Score −1,0 bis −2,5) über 12 Monate: 0,3 g bei 90 oder 30 Hz, 20 min täglich, alle mit Calcium und Vitamin D. Die trabekuläre vBMD der Tibia änderte sich nicht (P=0,55), ebenso wenig die aBMD an Schenkelhals, Hüfte und LWS. Die Adhärenz lag bei 65–79 %, eine doppelte Verblindung war nicht möglich.
- **Stufe:** B (einzelne, gut gemachte RCT, Null-Ergebnis) · **geöffnet:** nein
- **Quelle:** Effect of 12 months of whole-body vibration therapy on bone density and structure in postmenopausal women — <https://pubmed.ncbi.nlm.nih.gov/22084333/>
- **Prüfnotiz:** Bestätigt: Slatkovska et al., Ann Intern Med 2011;155(10):668–679.

### 39. Osteoporosis International (Slatkovska et al.) (2010)

- **Aussage:** Meta-Analyse: kleine, signifikante Zunahme der aBMD an der Hüfte bei postmenopausalen Frauen, an anderen Messorten kein Effekt. Bei Kindern und Jugendlichen nimmt die vBMD an Tibia und Wirbelsäule zu.
- **Stufe:** B–C · **geöffnet:** nein
- **Quelle:** Effect of whole-body vibration on BMD: a systematic review and meta-analysis — <https://search.pedro.org.au/search-results/record-detail/25614>
- **Prüfnotiz:** Teilweise bestätigt: Zitat (Osteoporos Int 21(12):1969–1980) und Richtung stimmen. Die Zahlen der Karte (8 RCTs, +0,015 g/cm², n=131) habe ich NICHT verifiziert; eine Meta-Analyse von 2016 schreibt, der Review habe 5 RCTs gepoolt. Vor einem Zitat am Volltext klären.

### 40. EU (Spiegel: legislation.gov.uk); DGUV IFA (2002)

- **Aussage:** Richtlinie 2002/44/EG, Art. 3, Ganzkörpervibration: Der Tages-Grenzwert A(8) beträgt 1,15 m/s² (wahlweise Vibrationsdosiswert 21 m/s^1,75), der Auslösewert 0,5 m/s² (wahlweise 9,1 m/s^1,75), jeweils bezogen auf 8 Stunden.
- **Stufe:** n/a (Recht) · **geöffnet:** nein
- **Quelle:** Directive 2002/44/EC; DGUV IFA – Vibrationen: Regelwerk — <https://www.legislation.gov.uk/eudr/2002/44/data.html>
- **Prüfnotiz:** Bestätigt. Ergänzend nennt die DGUV für die deutsche Umsetzung (LärmVibrationsArbSchV) 0,8 m/s² für die z-Achse und 1,15 m/s² für x/y. In Deutschland gilt also achsenabhängig ein strengerer Wert.

### 41. Disability and Rehabilitation (2022)

- **Aussage:** Umbrella-Review über 16 systematische Reviews (Suche bis 11/2020): Vibrationstherapie scheint die Spastik bei MS und Zerebralparese NICHT zu reduzieren. Beim Schlaganfall hilft Ganzkörpervibration eher bei Gang und Gleichgewicht, fokale Muskelvibration eher gegen Spastik. Geeignete Anwendungsparameter ließen sich nicht definieren.
- **Stufe:** B (gegen Nutzen bei MS und Zerebralparese) · **geöffnet:** nein
- **Quelle:** Vibration therapy role in neurological diseases rehabilitation: an umbrella review of systematic reviews — <https://air.unipr.it/handle/11381/2932486>
- **Prüfnotiz:** Bestätigt: Moggio et al., Disabil Rehabil 44(20):5741–5749, online 2021. Betrifft mechanische Vibration, nicht Vibroakustik.

### 42. BMJ Open (2022)

- **Aussage:** Scoping-Review zu vibroakustischer Therapie bei Schmerz: Von 430 Records wurden 20 eingeschlossen (15 zu chronischem, 2 zu akutem, 2 zu beiden Schmerzarten, 1 zu experimentellem Schmerz). Die Protokolle sind sehr heterogen, am häufigsten 40 Hz und 20–45 min. Die Forschung ist zu dünn, um nützliche Eigenschaften zu bestimmen. Die Autoren fordern, dass Studien mindestens Frequenz, Amplitude, Pulsation und Lautheit berichten.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Exploring vibroacoustic therapy in adults experiencing pain: a scoping review — <https://bmjopen.bmj.com/content/12/4/e046591>
- **Prüfnotiz:** Bestätigt: Kantor et al., BMJ Open 12(4):e046591.

### 43. International Journal of Environmental Research and Public Health (MDPI) (2019)

- **Aussage:** Narrativer Review zu vibroakustischer Therapie bei Zerebralparese: Die Suche in 13 Datenbanken und 2 Grauliteratur-Quellen ergab 823 Treffer, davon 7 relevant (5 experimentelle Studien, 2 RCTs). Die meisten berichten eine verbesserte Motorik.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Potential of Vibroacoustic Therapy in Persons with Cerebral Palsy: An Advanced Narrative Review — <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6843730/>
- **Prüfnotiz:** Bestätigt: Kantor et al., IJERPH 16(20):3940. Das Bias-Risiko ist hoch.

### 44. Sensors (MDPI); Frontiers in Psychology (2024 / 2022)

- **Aussage:** Vibroakustik bei Stress: Fooks und Niebuhr (Sensors 24(18):5924, 2024) fanden nach einer vibroakustischen Klangmassage eine erhöhte parasympathische Aktivität im EKG (gemessen mit PSS-10, EKG und EEG; laut Sekundärquelle etwa 40 Erwachsene, 38 ausgewertet). Die RCT mit 54 Studierenden ist eine ANDERE Arbeit: Kantor et al. 2022, Frontiers in Psychology, Pilot-RCT in Olomouc. Dort unterschieden sich die Gruppen nur in der HRV (LF/HF, pNN50).
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Effects of Vibroacoustic Stimulation on Psychological, Physiological, and Cognitive Stress; Effect of low frequency sound vibration on acute stress response in university students — <https://www.frontiersin.org/articles/10.3389/fpsyg.2022.980756/full>
- **Prüfnotiz:** KORRIGIERT: Die Karte schrieb die 54-Studierenden-RCT samt VIBROBED Fooks und Niebuhr zu. VIBROBED gehört zu Vilímek et al. 2022 (Healthcare, Crossover-Design). Ob die Kantor-RCT doppelblind war, habe ich nicht verifiziert. Alle Endpunkte sind physiologische Surrogatmarker.

### 45. Cochrane (Bradt et al.; CD006911.pub4) (2021)

- **Aussage:** Cochrane-Review zu Musikinterventionen bei Krebs: 81 Studien mit 5.576 Teilnehmenden (74 bei Erwachsenen, N=5.306; 7 bei Kindern, N=270; 38 Musiktherapie- und 43 Musikmedizin-Studien). Die Angst sinkt im Mittel um 7,73 Punkte im STAI (95 %-KI −10,02 bis −5,44; 17 Studien, 1.381 Teilnehmende; sehr niedrige Gewissheit). Depression SMD −0,41 (sehr niedrige Gewissheit), auf die Stimmung kein Effekt.
- **Stufe:** B (positiv, aber niedrige bis sehr niedrige Gewissheit) · **geöffnet:** nein
- **Quelle:** Music interventions for improving psychological and physical outcomes in people with cancer — <https://www.cochrane.org/evidence/CD006911>
- **Prüfnotiz:** Bestätigt. Den Schmerzwert SMD −0,67 habe ich nicht geprüft. Die Endpunkte betreffen Erleben und Symptome, keine Gewebeheilung.

### 46. Cochrane (Bradt, Dileo, Shim; CD006908.pub2) (2013)

- **Aussage:** Cochrane-Review zu Musik vor Operationen (26 Studien, 2.051 Teilnehmende): Musikhören kann die präoperative Angst senken; in einer großen Studie wirkte es stärker als Midazolam. Wegen des hohen Bias-Risikos ist das vorsichtig zu deuten. Wörtlich heißt es: 'None of the studies included wound healing, infection rate, time to discharge, or patient satisfaction as outcome variables.' Nebenwirkungen wurden keine festgestellt.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Music interventions for preoperative anxiety — <https://cochranelibrary.com/cdsr/doi/10.1002/14651858.CD006908.pub2/information>
- **Prüfnotiz:** Bestätigt (PMID 23740695, erschienen 06.06.2013). Das ist der stärkste Einzelbeleg dafür, dass zur Heilung keine Daten erhoben wurden.

### 47. The Lancet (2015)

- **Aussage:** Meta-Analyse aus 73 RCTs bei operierten Erwachsenen (20–458 Teilnehmende je Studie): Musik senkt postoperativ den Schmerz (SMD −0,77; 95 %-KI −0,99 bis −0,56), die Angst (−0,68; −0,95 bis −0,41) und den Analgetikabedarf (−0,37; −0,54 bis −0,20) und erhöht die Zufriedenheit (1,09). Auf die Liegedauer wirkt sie nicht (−0,11; −0,35 bis 0,12). Auswahl und Zeitpunkt der Musik machten kaum einen Unterschied, wirksam war sie auch unter Vollnarkose.
- **Stufe:** A (konsistent für das Erleben von Schmerz und Angst als Begleitmaßnahme) · **geöffnet:** nein
- **Quelle:** Music as an aid for postoperative recovery in adults: a systematic review and meta-analysis — <https://pubmed.ncbi.nlm.nih.gov/26277246/>
- **Prüfnotiz:** Bestätigt: Hole et al., Lancet 386(10004):1659–71, PROSPERO CRD42013005220. Die Meta-Regression fand unter 8 Variablen keine Quelle der Heterogenität. Heilungsendpunkte gibt es keine.

### 48. BMC Complementary and Alternative Medicine (2017)

- **Aussage:** Meta-Analyse von RCTs zu Musik bei Verbrennungspatient*innen während Behandlungsprozeduren wie Verbandwechsel, Wundversorgung und Debridement. Gesucht wurde bis 02/2016; frühere Einzelergebnisse waren uneinheitlich.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** The effects of music intervention on burn patients during treatment procedures: a systematic review and meta-analysis of randomized controlled trials — <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5356403/>
- **Prüfnotiz:** Teilweise bestätigt: Zitat und Design stimmen (Li, Zhou, Wang, BMC Complement Altern Med, 17.03.2017, doi 10.1186/s12906-017-1669-4). Die gepoolten Effekte auf Schmerz und Herzfrequenz habe ich NICHT verifiziert.

### 49. Frontiers in Rehabilitation Sciences (2024)

- **Aussage:** Netzwerk-Meta-Analyse aus 17 RCTs mit 1.119 Verbrennungspatient*innen (Suche bis 22.11.2023, RoB 2.0): Musiktherapie und VR senken Schmerz und Angst gegenüber Kontrollen. Für den Schmerz rangiert Musik am höchsten (SUCRA 85,4 %), für die Angst VR (SUCRA 79,5 %).
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Effects of two non-drug interventions on pain and anxiety in the nursing process of burn patients: a literature review with meta-analysis — <https://www.frontiersin.org/journals/rehabilitation-sciences/articles/10.3389/fresc.2024.1479833/full>
- **Prüfnotiz:** Bestätigt: Zhang et al., Front Rehabil Sci 5 (2024), PROSPERO CRD42024566536. Die Effektgrößen habe ich nicht eingesehen. Es geht um das Erleben, nicht um Heilung.

### 50. Cochrane (Cepeda et al.; CD004843) (2006 (Rückzugsvermerk 2013))

- **Aussage:** Cochrane 'Music for pain relief': Die Fassung von 2006 (51 Studien, 3.663 Teilnehmende) fand kleine Effekte auf Schmerz und Opioidbedarf. Ihre klinische Relevanz ist unklar, Musik sei keine Erstlinientherapie. Die Fassung von 2013 (pub3) trägt einen Rückzugsvermerk; das Ersatzprotokoll ist CD009284 (2011).
- **Stufe:** — (Status der Evidenzbasis) · **geöffnet:** nein
- **Quelle:** Music for pain relief — <https://pubmed.ncbi.nlm.nih.gov/16625614/>
- **Prüfnotiz:** Im Kern bestätigt. Wer 'laut Cochrane lindert Musik Schmerz' zitiert, zitiert eine veraltete bzw. zurückgezogene Fassung mit selbst eingeräumt kleinem Effekt.

### 51. Health (SCIRP) (2018)

- **Aussage:** Studie zu 528 Hz gegenüber 440 Hz bei 9 Gesunden (1 Mann, 8 Frauen, 26–37 Jahre): Nach 528 Hz sank das Speichel-Cortisol und stieg Oxytocin signifikant; bei 440 Hz änderte sich im Speichel nichts. LF/HF sank in beiden Bedingungen.
- **Stufe:** C (n=9, Einzelstudie, Surrogatmarker) · **geöffnet:** nein
- **Quelle:** Effect of 528 Hz Music on the Endocrine System and Autonomic Nervous System — <https://www.scirp.org/html/2-8204397_87146.htm>
- **Prüfnotiz:** Bestätigt: Akimoto et al., Health (SCIRP) 10(9). Eine Replikation fand ich nicht. Aussagen zu Heilung oder DNA lassen sich daraus nicht ableiten.

### 52. BMC Complementary Medicine and Therapies (2025)

- **Aussage:** 432 Hz: Eine Crossover-RCT bei 43 Krebspatient*innen (Hohneck et al., BMC Complement Med Ther, Januar 2025; 15 min Monochord) senkte die Herzfrequenz in beiden Stimmungen, stärker bei 432 Hz (Median −3 gegenüber −1 bpm, p=0,04). Die HRV stieg nur bei 432 Hz (+3 ms). Die Gefäßparameter unterschieden sich zwischen den Stimmungen nicht signifikant. Die Pilotstudie von 2019 (33 Personen, −4,79 bpm, p=0,05) ist nur über Sekundärquellen belegt.
- **Stufe:** C für kleine physiologische Effekte; D für jede Heilaussage · **geöffnet:** nein
- **Quelle:** Differential effects of sound interventions tuned to 432 Hz or 443 Hz on cardiovascular parameters in cancer patients: a randomized cross-over trial — <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11755923/>
- **Prüfnotiz:** Bestätigt und präzisiert (n=43). Laut Dissertation zur Studie unterschieden sich Stress und Ermüdung zwischen den Frequenzen nicht.

### 53. FTC v. OMICS (Bericht Manatt / Physics Today) (2019 / 2020)

- **Aussage:** FTC gegen OMICS Group: Am 29.03.2019 erging ein Summary Judgment über mehr als 50,1 Mio. USD wegen täuschender Angaben zu Peer Review, Gebühren, Impact Factors und Herausgebergremien. Der Ninth Circuit bestätigte am 11.09.2020 mit 2:1, mit einem Teil-Dissens zur Höhe.
- **Stufe:** — (Quellenqualität) · **geöffnet:** nein
- **Quelle:** Split Ninth Circuit Upholds $50M FTC Victory Against Online Publisher — <https://www.manatt.com/insights/newsletters/advertising-law/split-ninth-circuit-upholds-50m-ftc-victory-again>
- **Prüfnotiz:** Bestätigt (Manatt, JD Supra, Infodocket). Deshalb taugen OMICS-Arbeiten wie Babayi und Riazi 2017 zu 528 Hz nicht als Beleg.

### 54. Communications Biology (2025)

- **Aussage:** In vitro: Hörbarer Schall (440 Hz, 14 kHz, weißes Rauschen) mit 100 Pa über einen Vibrationswandler veränderte in C2C12-Myoblasten der Maus die Genexpression, 42 Gene nach 2 h und 145 nach 24 h. Ptgs2/COX-2 wird FAK-abhängig aktiviert und führt zur PGE2-Synthese. Die Differenzierung von Fettzellen wurde unterdrückt.
- **Stufe:** C (Zellkultur, Mechanismus) · **geöffnet:** nein
- **Quelle:** Acoustic modulation of mechanosensitive genes and adipocyte differentiation — <https://pmc.ncbi.nlm.nih.gov/articles/PMC12003795/>
- **Prüfnotiz:** KORRIGIERT: Der Titel lautet 'Acoustic modulation of mechanosensitive genes and adipocyte differentiation' (Kumeta et al., Commun Biol 2025, doi 10.1038/s42003-025-07969-1). Die Rechnung 100 Pa ≈ 134 dB SPL stimmt (20·log10(100/2e-5) = 133,98).

### 55. Journal of Psychosomatic Research (2009)

- **Aussage:** Psychischer Stress hängt mit schlechterer Wundheilung zusammen: r = −0,42 (95 %-KI −0,51 bis −0,32; P<0,01). Der Review umfasst 22 Arbeiten, davon 11 in der Meta-Analyse; 17 berichten eine beeinträchtigte Heilung oder veränderte Biomarker. Die Autoren fordern experimentelle Interventionsstudien, um Kausalität zu prüfen.
- **Stufe:** B–C (korrelativ) · **geöffnet:** nein
- **Quelle:** Psychological stress and wound healing in humans: a systematic review and meta-analysis — <https://pubmed.ncbi.nlm.nih.gov/19686881/>
- **Prüfnotiz:** Bestätigt: Walburn et al., J Psychosom Res 67(3):253–271. Dass stresssenkende Musik die Heilung beschleunigt, folgt daraus NICHT.

### 56. ClinicalTrials.gov (registriert, Beginn 2026 geschätzt)

- **Aussage:** NCT07456618 'Using Music During Wound Care Among Seniors With Pressure Injuries' (offizieller Titel 'Investigating the Use of Music During Wound Care') ist an der McMaster University registriert. Status: noch nicht rekrutierend. Geschätzter Beginn 01.04.2026, Primärabschluss 01.10.2026, Gesamtabschluss 01.06.2027.
- **Stufe:** D (UNBELEGT, nur registriert) · **geöffnet:** nein
- **Quelle:** Using Music During Wound Care Among Seniors With Pressure Injuries — <https://clinicaltrials.gov/study/NCT07456618>
- **Prüfnotiz:** Dass die Studie existiert, ist bestätigt. Die Angabe der Karte, sie prüfe den 'Heilungsverlauf', habe ich NICHT verifiziert; Endpunkte und Design standen nicht im Treffer.

### 57. Cochrane (CD001180.pub4) (2017)

- **Aussage:** Cochrane-Review zu Ultraschall bei venösem Ulcus cruris: Ob hoch- oder niederfrequenter Ultraschall die Heilung verbessert, ist unsicher. Die Evidenz ist überwiegend niedrig bis sehr niedrig, wegen Bias-Risiko und Unschärfe.
- **Stufe:** B–C (unsicher) · **geöffnet:** nein
- **Quelle:** Therapeutic ultrasound for venous leg ulcers — <https://cochranelibrary.com/cdsr/doi/10.1002/14651858.CD001180.pub4/information/en>
- **Prüfnotiz:** Bestätigt: Cullum und Liu, erschienen 15.05.2017. Die Angaben zu Nebenwirkungen (1 Studie, 337 Teilnehmende) habe ich NICHT verifiziert.

### 58. Cochrane (Baba-Akbari Sari et al.) (2006)

- **Aussage:** Cochrane-Review zu Ultraschall bei Dekubitus: 3 Studien mit 146 Personen. Ein Nutzen ist nicht belegt; Nutzen oder Schaden lassen sich wegen der wenigen und kleinen Studien aber nicht ausschließen.
- **Stufe:** C–D · **geöffnet:** nein
- **Quelle:** Therapeutic ultrasound for pressure ulcers — <https://cochranelibrary.com/cdsr/doi/10.1002/14651858.CD001275.pub2/information>
- **Prüfnotiz:** Bestätigt (CD001275.pub2, erschienen 19.07.2006). 'Nicht belegt' heißt hier: die Studien waren zu klein, nicht dass Unwirksamkeit gezeigt wurde.

### 59. Kammergericht Berlin (Bericht Rheinisches Ärzteblatt) (2024)

- **Aussage:** KG Berlin, Urteil vom 03.12.2024 (5 U 9/24): Die Werbung einer Ärztin für osteopathische Behandlungen entsprach nicht dem Stand gesicherter wissenschaftlicher Erkenntnis, den § 3 Satz 2 Nr. 1 HWG verlangt. Gesundheitsbezogene Werbung braucht den Nachweis der Wirksamkeit oder einen klaren Hinweis auf die Gegenmeinung.
- **Stufe:** B (OLG-Ebene) · **geöffnet:** nein
- **Quelle:** KG Berlin 5 U 9/24 – Werbung mit Osteopathie — <https://aekno.de/fileadmin/user_upload/RheinischesAerzteblatt/Ausgaben/2025/2025.04.025.pdf>
- **Prüfnotiz:** Bestätigt über das Rheinische Ärzteblatt 4/2025, den Volltext habe ich nicht eingesehen. Das LG Bamberg (2024) zitiert dieselbe Linie mit BGH I ZR 204/19 vom 05.11.2020.

### 60. EU (Verordnung 2017/745); Johner Institute; Taylor Wessing (2017 / 2023)

- **Aussage:** MDR Art. 2 Nr. 12: Zweckbestimmung ist die Verwendung, für die das Produkt nach den Angaben des Herstellers auf der Kennzeichnung, in der Gebrauchsanweisung oder im Werbe- oder Verkaufsmaterial bzw. in Werbe- oder Verkaufsangaben bestimmt ist, und wie der Hersteller sie in der klinischen Bewertung angibt. 'Verkaufsmaterial' und 'Angaben' sind gegenüber der alten Richtlinie neu.
- **Stufe:** A (Normtext) · **geöffnet:** nein
- **Quelle:** MDR Art. 2(12) – intended purpose; BGH I ZR 17/23 (Vorlagebeschluss) — <https://blog.johner-institute.com/regulatory-affairs/intended-purpose/>
- **Prüfnotiz:** Bestätigt und VERVOLLSTÄNDIGT (der Teil zur klinischen Bewertung fehlte in der Karte). Zwei KORREKTUREN bzw. VORBEHALTE: (1) Der BGH-Vorlagebeschluss I ZR 17/23 vom 21.12.2023 (Trockenluftkompressoren für Zahnarztpraxen) betrifft vor allem die Prüfpflichten von Händlern nach Art. 14 MDR. Dass er Art. 2 Nr. 12 als Maßstab nennt, habe ich nicht verifiziert. (2) Laut einer nicht geöffneten Kanzlei-Zusammenfassung (Osborne Clarke) hat der EuGH entschieden, die angegebene Zweckbestimmung des Herstellers sei ein Element der Definition, aber nicht das einzige. Das schwächt die Lesart 'nur die Zweckbestimmung zählt' und ist vor jeder Verwendung zu klären.

### 61. EuGH / BGH (Berichte rechtslupe.de, Covington) (2012 / 2013)

- **Aussage:** EuGH C-219/11 (Brain Products gegen BioSemi, 22.11.2012): Ein Gerät zur Untersuchung physiologischer Vorgänge ist nur dann ein Medizinprodukt, wenn der Hersteller es für einen medizinischen Zweck bestimmt. Der BGH folgte in 'Messgerät II' (I ZR 53/09, 18.04.2013): Ein solches Gerät fällt nicht unter den Begriff, wenn der Hersteller die medizinische Verwendung 'hinreichend deutlich und nicht willkürlich' ausschließt. Im Fall war das Gerät ohne wesentliche Änderungen auch objektiv nicht für Diagnose oder Therapie geeignet.
- **Stufe:** B (alte Richtlinie 93/42/EWG) · **geöffnet:** nein
- **Quelle:** Messung am Menschen zu nicht medizinischen Zwecken (BGH I ZR 53/09); CJEU clarifies medical device borderline — <https://www.rechtslupe.de/wirtschaftsrecht/messung-am-menschen-zu-nicht-medizinischen-zwecken-368010>
- **Prüfnotiz:** Bestätigt und PRÄZISIERT. Die Bedingung 'nicht willkürlich' entscheidet: Ein Ausschluss trägt nur, wenn Produkt und Vermarktung objektiv nicht auf einen medizinischen Zweck zielen. Ein Disclaimer neben Heilaussagen hilft also nicht. Ob die Linie auf die MDR übertragbar ist, bleibt offen.

### 62. EuGH (ECLI:EU:C:2017:947) (2017)

- **Aussage:** EuGH C-329/16 (Snitem und Philips France, Vierte Kammer, 07.12.2017): Software kann ein Medizinprodukt sein, auch wenn sie nicht selbst im oder am Körper wirkt. Dafür müssen zwei kumulative Bedingungen erfüllt sein, die sich auf das verfolgte Ziel (medizinischer Zweck laut Hersteller) und die bewirkte Wirkung beziehen. CE-gekennzeichnete Medizinprodukt-Software darf keiner zusätzlichen nationalen Zertifizierung unterworfen werden.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Urteil C-329/16 Snitem und Philips France — <https://www.bristows.com/news/digital-health-the-cjeu-s-first-decision-on-standalone-software-as-a-medical-device>
- **Prüfnotiz:** Bestätigt (Taylor Wessing, Bristows). Den genauen Wortlaut der zweiten Bedingung habe ich nicht eingesehen. Das Urteil erging noch zur alten Richtlinie.

### 63. Bundesamt für Justiz / buzer.de (geltend)

- **Aussage:** § 14 HWG: Wer gegen das Verbot irreführender Werbung (§ 3) verstößt, wird mit Freiheitsstrafe bis zu einem Jahr oder mit Geldstrafe bestraft. § 15 Abs. 2 und 3 HWG: Ein fahrlässiger Verstoß gegen § 3 ist eine Ordnungswidrigkeit mit Geldbuße bis 20.000 €.
- **Stufe:** A (Normtext) · **geöffnet:** nein
- **Quelle:** Heilmittelwerbegesetz §§ 14, 15 — <https://www.gesetze-im-internet.de/heilmwerbg/__15.html>
- **Prüfnotiz:** Bestätigt (buzer.de, lexmea, gesetze-im-internet.de). buzer.de führt zuletzt Änderungen vom 26.06.2026; die geltende Fassung ist vor Zitat zu prüfen.

### 64. omsels.info / buzer.de (geltend)

- **Aussage:** § 11 Abs. 1 HWG: Außerhalb der Fachkreise darf für 'Arzneimittel, Verfahren, Behandlungen, Gegenstände oder andere Mittel' u. a. nicht mit Werbeaussagen geworben werden, die nahelegen, 'dass die Gesundheit durch die Nichtverwendung des Arzneimittels beeinträchtigt oder durch die Verwendung verbessert werden könnte' (Nr. 7). Für Medizinprodukte gilt Satz 1 Nr. 7 bis 9, 11 und 12 entsprechend (Satz 2). Das OLG Frankfurt (6 U 64/16) wertet Satz 2 als Sonderregel für Medizinprodukte, die nicht dadurch umgangen werden darf, dass man sie als 'Gegenstände' nach § 1 Abs. 1 Nr. 2 behandelt.
- **Stufe:** A (Normtext) / B (Auslegung) · **geöffnet:** nein
- **Quelle:** § 11 HWG Werbung außerhalb der Fachkreise; § 11 Abs. 1 S. 2 HWG Medizinprodukte — <https://www.omsels.info/die-verbote-oder-was-darf-ich-nicht/2-heilmittelwerbegesetz/11-hwg-werbung-ausserhalb-der-fachkreise>
- **Prüfnotiz:** Bestätigt (omsels.info, buzer.de); die Liste der Karte, Nr. 7, 8, 9, 11, 12, stimmt. Einschränkung: Nr. 7 spricht wörtlich vom 'Arzneimittel', ob es auf ein bloßes 'anderes Mittel' wie Echoel anwendbar ist, bleibt offen. Nr. 2 (bekannte Personen) gilt nicht für Medizinprodukte. Den Wortlaut von Nr. 9 und Nr. 11 habe ich nicht neu geprüft.

### 65. OLG Nürnberg / Bayern.Recht (2021)

- **Aussage:** OLG Nürnberg, Urteil vom 16.02.2021 (3 U 2204/20; Gewinnspiel einer Optikerkette): Das HWG erfasst nur produktbezogene Werbung (Produkt- und Absatzwerbung), nicht die allgemeine Unternehmens- und Imagewerbung. Entscheidend ist der Gesamteindruck, also ob das Unternehmen oder bestimmte bzw. bestimmbare Produkte im Vordergrund stehen. Reine Sonnen- und Modebrillen sind keine Medizinprodukte.
- **Stufe:** B (OLG) · **geöffnet:** nein
- **Quelle:** OLG Nürnberg, Endurteil v. 16.02.2021 – 3 U 2204/20 — <https://www.gesetze-bayern.de/Content/Document/Y-300-Z-GRURRS-B-2021-N-44910>
- **Prüfnotiz:** Bestätigt (gesetze-bayern.de, GRUR-RS 2021, 44910). Die Übertragung auf eine Künstler-Website ist ein eigener Schluss (C).

### 66. OLG Köln (Bericht beck-aktuell) (2025)

- **Aussage:** OLG Köln, Urteil vom 11.09.2025 (6 U 118/24; Vorinstanz LG Köln 33 O 181/24): Ein 18-sekündiges Instagram-Reel für ein Arzneimittel verstieß gegen das HWG. Der Pflichthinweis muss im Video sichtbar und gesprochen erscheinen, Beschreibungstext oder Link reichen nicht. Ob jemand eine 'bekannte Person' ist, entscheidet der Einzelfall, nicht die Statistik allein; hier reichte die Reichweite der Influencerin.
- **Stufe:** B (OLG) · **geöffnet:** nein
- **Quelle:** Pharmakonzern durfte nicht mit Influencerin werben (OLG Köln 6 U 118/24) — <https://www.beck-aktuell.de/heute-im-recht/rechtsprechung/olg-koeln-6u11824-werbung-arzneimittel-influencerin-heilmittelwerbegesetz-2025-10-24>
- **Prüfnotiz:** Bestätigt (beck-aktuell, WBS, Forvis Mazars). Welcher Absatz von § 4 HWG den Pflichthinweis trägt, geben die Quellen unterschiedlich an. Den Satz der Karte, eine Kennzeichnung als Werbung mache die Empfehlung nicht zulässig, habe ich nicht verifiziert. Das Urteil betrifft ein Arzneimittel.

### 67. BGH (Fundstellen omsels.info) (2013–2021)

- **Aussage:** Strengeprinzip: Für gesundheitsbezogene Werbung gelten besonders strenge Anforderungen an Richtigkeit, Eindeutigkeit und Klarheit (BGH I ZR 146/20 vom 09.12.2021, 'Werbung für Fernbehandlung', Rn. 62). Zulässig ist sie nur, wenn sie gesicherter wissenschaftlicher Erkenntnis entspricht (BGH I ZR 62/11 vom 06.02.2013, 'Basisinsulin mit Gewichtsvorteil'; BGH I ZR 204/19 vom 05.11.2020).
- **Stufe:** A (gefestigte BGH-Linie) · **geöffnet:** nein
- **Quelle:** Strengeprinzip – Beweislast bei gesundheitsbezogener Werbung — <https://www.omsels.info/v-das-verfahren-oder-wie-laeufts-ab/g-gerichtliche-verfahren/9-beweislast/heilmittel-lebensmittel-kosmetika-medizinprodukte-sonstige-mittel-zur-anwendung-am-koerper/strengeprinzip>
- **Prüfnotiz:** Bestätigt über Sekundärquellen (omsels.info, LG Bamberg 2024, Rheinisches Ärzteblatt). Bei I ZR 62/11 widersprechen sich die Quellen zur Randnummer (Tz. 15 bzw. 16); am Original prüfen.
