# Feld 1 — Produktions- und Hörgesundheit

> ⛔ **Forschung, keine Produktaussage.** Nichts aus dieser Datei darf in App, App Store, Website, Reels, Pressetext oder Förderantrag als Wirkung von Echoel erscheinen (`docs/dev/ECHOEL_VISION_2026-10-19.md` §6c, Root-`CLAUDE.md`: Heilung/Organe/Gewebe/Wunden bleiben eine harte REJECT-Linie in Code und Copy). Die Datei beschreibt den Stand der Literatur und die Grenze, nicht das Produkt.
>
> ⚠️ **Methode.** Erstellt am 2026-10-19 von einem Workflow mit drei Recherche-Agenten (Produktions-/Hörgesundheit, Gewebe-Evidenz, Recht) und einem Prüf-Agenten. Der Netz-Proxy der Sitzung ließ nur developer.apple.com und GitHub durch; WHO, ITU, PubMed/PMC, Cochrane, EUR-Lex, BfArM und die Verlage waren gesperrt. Selbst geöffnet sind deshalb nur die Apple-Dokumentation, die App Store Review Guidelines und Repo-Dateien (Spalte „geöffnet: ja“). **Jede andere Zahl stammt aus Suchtreffer-Zusammenfassungen und muss vor jedem Zitat im Volltext geprüft werden.** Teile der Rechtskarte blieben ungeprüft, weil das Suchbudget erschöpft war (DSGVO-Urteile, DiGA, EHDS, MDR-Regel 11, § 15 MBO-Ä, Deklaration von Helsinki). Evidenzstufen A–D gelten für Gesundheitsaussagen; „n/a“ steht bei Normen, Recht und API-Fakten.

## Zusammenfassung

EVIDENZKARTE Feld 1 – Produktions-/Hörgesundheit (Stand 2026-10-19). WICHTIGE EINSCHRÄNKUNG ZUR METHODE: Der Netz-Proxy dieser Sitzung ließ nur developer.apple.com (und GitHub) durch. WHO, ITU, NCBI/PMC, Cochrane, eur-lex, BfArM, support.apple.com und Verlage waren gesperrt (CONNECT 403 bzw. DNS-Fehler). Deshalb sind nur die Apple-Developer-Seiten, die App Store Review Guidelines und Repo-Dateien selbst geöffnet (opened=true). Alles andere stammt aus Suchtreffer-Zusammenfassungen (opened=false). Zahlen daraus muss man vor jeder Zitierung im Volltext prüfen. Bewertung: A–D gilt für Gesundheitsaussagen; bei Normen, Recht und API-Fakten steht „n/a“, weil es dort um den Inhalt eines Dokuments geht und nicht um Wirksamkeit.

KERNBEFUNDE: (1) Die WHO-ITU-Norm H.870 (ITU 08/2018, von der WHO 2019 veröffentlicht; Version 2 vom 16.03.2022) legt als Wochenbudget fest: Erwachsene 80 dB(A) über 40 h, Kinder 75 dB(A) über 40 h. Grundlage ist das Gleichenergie-Prinzip. Gefordert sind Dosimetrie, Warnungen und eine Lautstärkebegrenzung. Version 2 erweitert laut ITU-Folien den Geltungsbereich auf kabellose Headsets und schließt professionelle Audiotechnik aus. Weitere Unterschiede zu 2018 sind UNBELEGT, weil der Volltext nicht erreichbar war. (2) Musiker*innen haben deutlich mehr Hörsymptome. Konsistent belegt durch zwei systematische Reviews und eine große deutsche Kohortenstudie: McCray 2026 findet Tinnitus bei 42,6 % gegenüber 13,2 % und Hyperakusis bei 37,3 % gegenüber 15,3 %, aber rund 63 % der Hörverlust-Fälle beruhen auf Selbstauskunft. Für Studio- bzw. DAW-Produzierende gibt es KEINE eigene Studie; belegt sind nur kleine Studien zu Live-Tontechniker*innen und DJs. (3) Prävention: Laut Cochrane (Tikka 2017) ist die Evidenz für Hörschutz-Programme niedrig bis sehr niedrig. Für Ohrstöpsel bei Konzerten gibt es ein gutes RCT, aber nur mit dem Endpunkt vorübergehende Hörschwellenverschiebung (TTS). Dass Pausen das Gehör schützen, ist beim Menschen nicht belegt (nur Tiermodelle). (4) Ergonomie: Muskel-Skelett-Beschwerden bei Musiker*innen sind häufig (12-Monats-Prävalenz 41–93 %), die Studien haben aber ein hohes Bias-Risiko, und kausale Risikofaktoren sind nicht belegt. Für Pausen und Ergonomie-Maßnahmen bei Büroarbeit ist die Evidenz niedrig (Cochrane, Hoe 2018). Mikropausen verbessern Vitalität und Ermüdung leicht, die Leistung nicht. Zur Ergonomie bei Musikproduktion fehlen eigene Studien. (5) Apple: HealthKit stellt headphoneAudioExposure bereit (dB(A)-SPL als Leq, vom System erfasst, iOS 13+), außerdem headphoneAudioExposureEvent (sevenDayLimit, iOS 14.2+), environmentalAudioExposure (Watch), environmentalAudioExposureEvent (NUR LESBAR) und environmentalSoundReduction (iOS 16+). Drittanbieter-Apps dürfen diese Werte mit Nutzerfreigabe lesen. Ob der Lesezugriff verweigert wurde, erfahren sie nicht. Eine öffentliche Echtzeit-API für den Schalldruck am Ohr ist nicht dokumentiert. AVAudioSession.outputVolume liefert nur 0–1 und kann nur vom Nutzer verändert werden. Zur Einstellung „Lautstärke reduzieren“ fand ich keine API (UNBELEGT). (6) Repo: EchoelLoudnessMeter misst die DIGITALE Programmlautheit (BS.1770-4/R128 in LUFS), nicht den Schalldruck am Ohr. Diese Unterscheidung ist die zentrale ehrliche Grenze.

EHRLICH ANBIETBAR, ohne Gesundheitsbehauptung: (a) Den Kopfhörerpegel aus Apple Health anzeigen, nur nach Opt-in, mit der Quellenangabe „laut Apple Health“ und Apples eigenem Genauigkeitshinweis. Die WHO-ITU-Referenz (80 dB(A)/40 h pro Woche) steht dabei nur als zitierte Referenz und ohne Bewertung wie „sicher“. (b) Einen Sitzungs-Timer und eine Pausen-Erinnerung mit selbst gewähltem Intervall, als Arbeitsablauf-Funktion formuliert. (c) Die vorhandene LUFS- und True-Peak-Anzeige, deutlich beschriftet als „digitale Programmlautheit, kein Schalldruck am Ohr“. (d) Lautheitsangeglichenen A/B-Vergleich. (e) Eine Referenzpegel-Kalibrierung nur über eine vom Nutzer extern gemessene SPL-Eingabe, ausdrücklich als Nutzerangabe gekennzeichnet. Voraussetzungen: Wer HealthKit-Audiotypen lesen will, muss den Text NSHealthShareUsageDescription ändern. Der nennt heute nur „heart rate and HRV“, und Resources/iOS/Info.plist ist founder-gated. Außerdem muss am Gerät geprüft werden, ob iOS Echoels Ausgabe als Medien-Audio zählt (UNBELEGT).

## Grenzen

1. KEINE Präventions- oder Heilbehauptung. Formulierungen wie 'schützt dein Gehör', 'verhindert Hörschäden, Tinnitus oder Hyperakusis' oder 'gehörschonendes Mixen' sind verboten. Grund: Prävention ist eine medizinische Zweckbestimmung (MDR 2017/745 Art. 2(1); MDCG 2019-11 Rev.1, Kommentar OpenRegulatory; CMS: ein Disclaimer allein hilft nicht). Hinzu kommen § 3 HWG und das Repo-Gesetz (CLAUDE.md BRAND: 'NOT a wellness, soundscape, or therapy product'). Inhaltlich bestätigt der Cochrane-Review Tikka 2017, dass selbst Hörschutz-Programme nur sehr niedrig belegt sind.
2. KEIN selbst berechneter Schalldruck- oder dB(A)-Wert 'am Ohr' und keine 'Gehörbelastung in %' aus dem eigenen App-Signal. Grund: AVAudioSession.outputVolume liefert nur 0–1, die Kopfhörer-Empfindlichkeit ist unbekannt (Apple-Doku, Developer-Forum 749742). Laut App Store Review Guideline 1.4.1 werden nicht validierbare Genauigkeitsbehauptungen zu Gesundheitsmessungen abgelehnt. LUFS darf nie als dB SPL beschriftet werden (Repo: EchoelLoudnessMeter misst die digitale Programmlautheit).
3. KEINE geschätzten Expositionswerte in HealthKit schreiben. Grund: Guideline 5.1.3(ii) verbietet ungenaue Daten. iOS erfasst die Kopfhörer-Pegel selbst, ein eigener Wert würde doppelt zählen (Apple-Doku headphoneAudioExposure). environmentalAudioExposureEvent ist ausdrücklich nur lesbar.
4. Gelesene Audio-Expositionsdaten niemals für Werbung oder Marketing nutzen, nicht in iCloud speichern und nicht über das Netz senden. Grund: App Store Review Guideline 5.1.3(i)/(ii). Hinzu kommt Echoels eigenes Versprechen in Resources/iOS/Info.plist: 'Health data stays on your device … never sent over the network'.
5. Keine Lesefreigabe für Audio-Typen anfordern, ohne die Nutzungsbeschreibung zu ändern. NSHealthShareUsageDescription nennt heute nur 'heart rate and HRV'. Gründe: Guideline 5.1.3(i) ('disclose the specific health data'), Apple-Doku 'Authorizing access to health data'. Die plist ist founder-gated (.claude/rules/context.md §3).
6. Kein Hörtest, kein Audiogramm, keine Hörverstärkung und keine Einschätzung eines persönlichen Tinnitus- oder Hörverlust-Risikos. Grund: Das ist Diagnose bzw. Medizinprodukt-Terrain, wie die FDA-Zulassung von Apples Hearing Aid Feature 2024 zeigt (Axios). Prävalenzen aus Studien (McCray 2026) sind Gruppenwerte und keine individuelle Vorhersage. Die eigene plist sagt außerdem 'never used for diagnosis'.
7. Keine Behauptung 'WHO-konform', 'H.870-zertifiziert' oder 'nach WHO-Standard sicher'. Grund: H.870 richtet sich an Geräte und Systeme und schließt professionelle Audiotechnik aus (ITU-T H.870 V2, 2022). Für Konformität gibt es einen eigenen Prüfstandard (HSTP.CONF-H870). Die WHO-ITU-Referenz darf nur als zitierte Referenz erscheinen, ohne 'sicher'/'unsicher'-Ampel als Urteil über die Person.
8. Keine Behauptung, Pausen 'regenerieren' oder 'erholen' das Gehör bzw. 'beugen Tinnitus vor'. Grund: Belege für unterbrochene Exposition gibt es nur aus Tiermodellen. Die TTS sagt den dauerhaften Hörverlust schlecht voraus, und eine anerkannte Pausen-Anrechnung beim Menschen gibt es nicht (NIOSH/CDC-Archiv; WUSTL-Chinchilla-Studie). Auch die menschliche Evidenz zur cochleären Synaptopathie ist uneinheitlich (Scoping Review PMC10715634). Sachlich zulässig ist nur: weniger Hördauer bedeutet nach dem Gleichenergie-Prinzip weniger Dosis.
9. Keine Behauptung, eine Pausen- oder Haltungserinnerung 'beugt RSI, Sehnenscheidenentzündung oder Nackenschmerz vor'. Grund: Cochrane Hoe 2018 bewertet Pausen nur mit niedriger bis sehr niedriger Evidenz, und Baadjou 2016 fand keine kausalen Risikofaktoren. Für DAW- bzw. Touchscreen-Produktion gibt es keine eigene Studie.
10. Die Kopfhörersicherheit von iOS nicht umgehen und Nutzer nicht anleiten, sie abzuschalten (Kopfhörer-Benachrichtigungen, 'Lautstärke reduzieren'). Grund: Nur der Nutzer setzt die Systemlautstärke (Apple-Doku outputVolume), und in manchen Ländern ist die Benachrichtigung absichtlich nicht abschaltbar (Apple Support HT211903, nicht geöffnet).
11. Keine Studie mit Gesundheitsdaten von Nutzer*innen ohne informierte Einwilligung und ohne Votum einer Ethikkommission. Grund: App Store Review Guideline 5.1.3(iii)/(iv).

## Forschungsfragen

1. Welche wöchentliche Kopfhörer-Dosis (laut Apple Health, Opt-in) entsteht bei mobiler Musikproduktion im Vergleich zum normalen Musikhören derselben Personen? Beobachtungsstudie mit Ethikvotum, Endpunkt Dosis statt Hörschaden; mögliche Partner: Audiologie UKE Hamburg oder ein Hörforschungsinstitut.
2. Zählt iOS die Ausgabe einer Dritt-App wie Echoel (AVAudioEngine, Wiedergabe-Kategorie) vollständig als Medien-Audio in headphoneAudioExposure, mit AirPods, Bluetooth-Studiokopfhörern und Kabel? Gerätetest: Pegel und Dauer kontrolliert abspielen und mit der Health-App vergleichen.
3. Wie weit liegen Apples Schätzwerte für Nicht-Apple-Kopfhörer (aus der Lautstärke geschätzt) bei typischen Studiokopfhörern neben einer Messung am Kunstkopf oder Ohrsimulator? Kooperation mit einem Akustiklabor, z. B. einer Hamburger Hochschule.
4. Verändert eine NEUTRALE Anzeige der Apple-Health-Pegel in der DAW (mit Quellenangabe, ohne Ampel) Abhörpegel und Hördauer? Randomisiert gegen eine Gruppe ohne Anzeige. Bisherige Evidenz: nur eine nicht randomisierte, entwicklernahe Vorher-nachher-Studie.
5. Senken lautheitsangeglichene A/B-Vergleiche beim Mischen den mittleren Abhörpegel bzw. den Pegelanstieg über eine Session (Effekt 'lauter klingt besser')? Experiment mit Produzierenden.
6. Wie häufig sind Tinnitus und Hyperakusis bei Studio- und Elektronik-Produzierenden, die überwiegend am Kopfhörer arbeiten, mit Audiometrie statt nur Selbstauskunft? Das ist eine Lücke: Belegt sind nur Instrumentalist*innen, Live-Tontechniker*innen und DJs.
7. Verringern selbst gewählte Pausen-Erinnerungen die GESAMTE Wochendosis, oder verlagern sie die Hörzeit nur? Nach dem Gleichenergie-Prinzip zählt nur die Gesamtdosis.
8. Welche Haltungs- und Belastungsmuster (Nackenbeugung, Daumen und Finger) treten bei langer Touchscreen-Produktion auf iPhone/iPad auf, und hängen sie von der Session-Dauer ab? Querschnitt mit Bewegungserfassung, ohne Präventionsbehauptung; Partner: Arbeitswissenschaft oder Musikermedizin.
9. Wie verstehen Nutzer*innen eine dargestellte Referenz '80 dB(A) über 40 h/Woche (WHO-ITU H.870)'? Lesen sie daraus 'darunter ist sicher' oder eine persönliche Diagnose? Kommunikations- und Usability-Studie, damit die Anzeige ehrlich bleibt.
10. Taugt die integrierte LUFS-Lautheit einer Session in Kombination mit der iOS-Lautstärke überhaupt als grober Ersatzwert für die Dosis am Ohr? Hypothese: nein, wegen der unbekannten Kopfhörer-Empfindlichkeit. Mit Messdaten prüfen, statt es zu behaupten.

## Befunde (31, vor der Gegenprüfung)

Die geprüfte Fassung steht in `reports/Evidenzkarte Gesundheitsforschung.md`.

### 1. WHO / ITU (2019 (ITU-T H.870 V1: 2018))

- **Aussage:** ITU-T H.870 / WHO-ITU-Norm 'Safe listening devices and systems': Wochenbudget Mode 1 (Erwachsene) 80 dB(A) über 40 h/Woche, Mode 2 (Kinder) 75 dB(A) über 40 h/Woche. Grundlage ist das Gleichenergie-Prinzip. Gefordert sind eine Dosimetrie als Prozent einer 'sound allowance', personalisiertes Feedback, Lautstärkebegrenzung bzw. -absenkung, eine passwortgeschützte Eltern-Begrenzung und Informationen für Nutzer. Die WHO empfiehlt, die Funktionen per Regulierung verpflichtend zu machen; Hersteller können die Norm freiwillig übernehmen.
- **Stufe:** n/a (Norm) · **geöffnet:** nein
- **Quelle:** Safe listening devices and systems: a WHO-ITU standard — <https://www.who.int/publications-detail/safe-listening-devices-and-systems-a-who-itu-standard>
- **Prüfnotiz:** Zeitleiste: ITU-T H.870 V1 08/2018, von der WHO 2019 als gemeinsamer Standard veröffentlicht (ISBN laut URL 9789241515276). Die Grenzwerte sind normativ gesetzt und kein Wirksamkeitsbeleg der Gerätefunktionen. Die Norm richtet sich an Geräte und Systeme (hier iOS), nicht an einzelne Apps. Nicht selbst geöffnet; Inhalt aus Suchtreffern und WHO-Infografik.

### 2. ITU-T (2022)

- **Aussage:** H.870 Version 2 wurde am 16.03.2022 verabschiedet und ist in Kraft. Laut ITU-Präsentation erweitert sie den Geltungsbereich auf kabellose Headsets. Ausgeschlossen bleiben Zwei-Wege-Kommunikationsgeräte, persönliche Schallverstärker und professionelle Audiotechnik. Spielkonsolen waren 'for future study'. Laut sekundärer Zusammenfassung verlangt V2: Überwachung aller Medienwiedergabe über Kopfhörer, Warnungen bei voreingestellten Schwellen (z. B. 80 % und 100 % des Wochenbudgets), Absenkung auf höchstens 80/75 dB(A), wenn Warnungen nicht bestätigt werden, und eine segmentbasierte Akkumulation über ein rollendes 7-Tage-Fenster. Eine vollständige Änderungsliste 2018→2022 ist UNBELEGT.
- **Stufe:** n/a (Norm) · **geöffnet:** nein
- **Quelle:** Recommendation ITU-T H.870 (V2) (03/2022) – Guidelines for safe listening devices/systems; ITU-Präsentation 'Overview of H.870 guidelines' (2023) — <https://www.itu.int/rec/T-REC-H.870-202203-I>
- **Prüfnotiz:** Volltext nicht erreichbar (ITU gesperrt). Die Angaben 80 %/100 % und das rollende 7-Tage-Fenster stammen aus einer Suchzusammenfassung und sind nicht verifiziert. Einen Konformitätstest gibt es als HSTP.CONF-H870. Eine eigene WHO-ITU-Norm für Gaming erschien laut ITU am 3.3.2025 (nicht geöffnet).

### 3. WHO (2022)

- **Aussage:** Die WHO 'Global standard for safe listening venues and events' (2022) setzt für Veranstaltungen höchstens 100 dB LAeq,15min. Sie nennt sechs Elemente: Pegelgrenze, Monitoring mit kalibriertem Gerät, Raumakustik und Beschallung, persönlicher Gehörschutz, Ruhezonen sowie Personalschulung und Information.
- **Stufe:** n/a (Norm) · **geöffnet:** nein
- **Quelle:** WHO hearing guidelines implemented at major arts festival (Feature Story) / Global standard for safe listening venues and events — <https://www.who.int/news-room/feature-stories/detail/who-hearing-guidelines-implemented-at-major-arts-festival>
- **Prüfnotiz:** Betrifft Live-Event und Performance, nicht persönliche Wiedergabegeräte. Relevant für Echoels 'Event/Performance'-Kontext nur als Hinweis an Veranstalter, nicht als App-Funktion. Ein Wert von 70 dB für Ruhezonen stammt aus einer ENT-Stellungnahme und ist nicht sicher WHO-Text.

### 4. BMJ Global Health 7(11): e010501 (2022)

- **Aussage:** Dillard et al. (systematischer Review und Meta-Analyse; 33 Studien, 35 Datensätze, 19.046 Personen; 12–34 Jahre): Die gepoolte Prävalenz unsicherer Exposition über persönliche Abspielgeräte liegt bei 23,81 % (95 %-KI 18,99–29,42). Für laute Veranstaltungsorte ergibt sich ein MODELLIERTER Schätzwert von 48,20 %. Weltweit werden 0,67–1,35 Mrd. junge Menschen als potenziell gefährdet geschätzt.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Prevalence and global estimates of unsafe listening practices in adolescents and young adults: a systematic review and meta-analysis — <https://gh.bmj.com/content/7/11/e010501.info>
- **Prüfnotiz:** Es ist eine Meta-Analyse, aber die Methodik der Einzelstudien ist nicht standardisiert und heterogen. Der Wert für Veranstaltungsorte ist modelliert und nicht gepoolt. Gemessen wird 'unsicheres Verhalten', nicht Hörschaden.

### 5. Otolaryngology–Head and Neck Surgery (AAO-HNSF) (2026)

- **Aussage:** McCray et al. (systematischer Review und Meta-Analyse; 67 Studien, >28.000 Musiker*innen, 21 Länder), Musiker*innen gegenüber Kontrollen: Tinnitus 42,6 % vs. 13,2 %, Hörverlust 25,7 % vs. 11,6 %, Hyperakusis 37,3 % vs. 15,3 %. Kein signifikanter Unterschied zwischen Klassik und Pop/Rock. Weniger als 50 % nutzen regelmäßig Gehörschutz.
- **Stufe:** A (Richtung) / B (Zahlen) · **geöffnet:** nein
- **Quelle:** Auditory symptoms in recreational and professional musicians: systematic review and meta-analysis (McCray, Ripp, Nguyen, Pelic, Labadie, Meyer) — <https://www.newswise.com/articles/over-40-of-musicians-experience-tinnitus-hearing-loss-and-hyperacusis-also-significantly-elevated>
- **Prüfnotiz:** Die Richtung stimmt mit Di Stadio 2018 und Schink 2014 überein. Die Zahlen sind unsicher, weil ca. 63 % der Hörverlust-Fälle auf Selbstauskunft beruhen und nur ca. 37 % audiometrisch bestätigt sind. DOI 10.1002/ohn.70094, Bd. 174, S. 305–316, nur aus Pressemitteilung und Suchtreffer bekannt; nicht geöffnet.

### 6. PMC (PMC6209930) (2018)

- **Aussage:** Di Stadio et al. (systematischer Review; 41 Artikel, 4.618 Berufsmusiker*innen): Hörverlust bei 38,6 %, bei Pop/Rock 63,5 % gegenüber 32,8 % bei Klassik. Tinnitus ist das häufigste Symptom. Untersucht wurden auch Hyperakusis und Diplakusis.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Hearing Loss, Tinnitus, Hyperacusis, and Diplacusis in Professional Musicians: A Systematic Review — <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6209930/>
- **Prüfnotiz:** Der Genre-Befund widerspricht McCray 2026. Die Zuordnung zur Zeitschrift ist in dieser Sitzung nicht verifiziert, bekannt ist nur PMC6209930; das Jahr 2018 folgt aus dem PMC-Eintrag. Nicht geöffnet (PMC gesperrt).

### 7. Occupational and Environmental Medicine 71(7):472–476 (2014)

- **Aussage:** Schink et al.: historische Kohorte aus Daten dreier deutscher gesetzlicher Krankenkassen 2004–2008 (ca. 7 Mio. Versicherte, 2.227 Berufsmusiker*innen). Lärmbedingter Hörverlust trat bei Musiker*innen etwa 3,5-fach häufiger auf (pressegemeldet 3,51), Tinnitus etwa 57 % häufiger. Die rohe Inzidenzrate-Ratio für Hörverlust insgesamt betrug 1,27.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** Incidence and relative risk of hearing disorders in professional musicians — <https://oem.bmj.com/content/71/7/472.full.pdf+html>
- **Prüfnotiz:** Große Kohorte, aber Routinedaten mit Diagnosekodierung; nicht randomisiert. Bereinigte Hazard Ratios und Konfidenzintervalle konnte ich nicht einsehen. DOI 10.1136/oemed-2014-102172.

### 8. Archives of Environmental & Occupational Health (Macquarie/ANU/Melbourne) (2021)

- **Aussage:** Studie an Live-Tontechniker*innen (n=27, Audiometrie): Die Hörschwellen lagen bei mehreren Frequenzen signifikant schlechter als die Normdaten. 30 % berichteten konstanten Tinnitus, 41 % eine verminderte Geräuschtoleranz. Gehörschutz wurde wenig genutzt, oft weil er bei der Arbeit stört. Für STUDIO- bzw. DAW-Produzierende fand ich keine eigene Studie: UNBELEGT.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** The hearing health of live-music sound engineers — <https://researchers.mq.edu.au/en/publications/the-hearing-health-of-live-music-sound-engineers/>
- **Prüfnotiz:** Kleine Stichprobe ohne Kontrollgruppe (Vergleich mit Normdaten). Live-Arbeit ist nicht mit Studioarbeit am Kopfhörer gleichzusetzen. Zur DJ-Studie (n=30, Clubpegel 93,2–109,7 dB(A), schlechtere Werte nach der Exposition) ist die Zeitschrift nicht verifiziert, daher hier nur als Hinweis.

### 9. Cochrane Database of Systematic Reviews (CD006396.pub4) (2017)

- **Aussage:** Cochrane-Review Tikka et al. (29 Studien) zu Maßnahmen gegen berufsbedingten Lärmhörverlust: Evidenz für strengere Gesetzgebung sehr niedrig. Gehörschutz mit niedriger Evidenz für ca. 20 dB(A) Reduktion. Schulung zum Einsetzen von Ohrstöpseln mit mittlerer Evidenz, aber nur kurzfristig. Hörschutz-Programme mit sehr niedriger Evidenz. Zu technischen Lärmminderungsmaßnahmen gibt es keine kontrollierten Studien.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Interventions to prevent occupational noise-induced hearing loss — <https://cochranelibrary.com/cdsr/doi/10.1002/14651858.CD006396.pub4/information/en>
- **Prüfnotiz:** Die Quelle ist hochwertig (Cochrane), die Vertrauenswürdigkeit der Evidenz ist aber niedrig bis sehr niedrig. Die GRADE-Stufen stammen aus Sekundärzusammenfassungen (NIOSH 'Cochrane Corner', ASHA) und sind vor einer Zitierung am Volltext CD006396.pub4 zu prüfen. Folge für das Produkt: Selbst klassischer Hörschutz ist als Prävention schwach belegt, eine App-Anzeige erst recht.

### 10. JAMA Otolaryngology–Head & Neck Surgery (laut UMC-Utrecht-Eintrag; nicht verifiziert) (2016)

- **Aussage:** Kraaijenga et al. (systematischer Review zu Ohrstöpseln bei Freizeitmusik; von 228 gescreenten Arbeiten 4 geeignet): Nur ein RCT war gut durchgeführt. Es zeigte nach dem Konzert geringere Hörschwellenverschiebungen in der Ohrstöpsel-Gruppe. Die Autoren bewerten die Evidenz insgesamt als dürftig.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** The Effect of Earplugs in Preventing Hearing Loss From Recreational Noise Exposure: A Systematic Review — <https://researchinformation.umcutrecht.nl/en/publications/the-effect-of-earplugs-in-preventing-hearing-loss-from-recreation/>
- **Prüfnotiz:** Ein einzelnes RCT mit Kurzzeit-Endpunkt (TTS). Ein Schutz vor dauerhaftem Hörverlust ist damit nicht belegt. Ein systematischer Review speziell zur Wirksamkeit von Gehörschutz bei BERUFSmusiker*innen wurde nicht gefunden (UNBELEGT).

### 11. NIOSH/CDC Stacks; Washington University (Chinchilla-Studie) (1987–1991 (Tierstudien))

- **Aussage:** Pausen und unterbrochene Exposition: In Chinchilla-Studien verursachten Ruhephasen weniger Hörverlust und weniger Cochlea-Schaden als eine kontinuierliche Exposition gleicher Energie. Beim Menschen gibt es keine Norm, die Pausen als Schutz anrechnet. Die vorübergehende Schwellenverschiebung (TTS) sagt den dauerhaften Hörverlust (PTS) nur schlecht voraus. Das Gleichenergie-Prinzip stammt aus 8-h-Arbeitslärmdaten und gilt nur unterhalb von ca. 115 dB.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Effect of periodic rest on hearing loss and cochlear damage following exposure to noise / Recent studies of TTS and PTS in animals — <https://profiles.wustl.edu/en/publications/effect-of-periodic-rest-on-hearing-loss-and-cochlear-damage-follo/>
- **Prüfnotiz:** Fast ausschließlich Tierdaten und ältere Übersichten (NIOSH/CDC-Archiv, WUSTL). Folge: Ein Pausenhinweis verringert die Dosis nur, indem er die Hördauer verkürzt. Eine 'Erholung' oder einen 'Schutz' darf man daraus nicht ableiten.

### 12. PMC (Scoping Review) (2023)

- **Aussage:** Cochleäre Synaptopathie ('versteckter Hörverlust'): Im Tiermodell ist gut belegt, dass Lärm Synapsen dauerhaft schädigen kann, auch ohne bleibende Schwellenverschiebung. Beim Menschen ist die Evidenz uneinheitlich und hängt stark vom Messverfahren ab. Eine Meta-Analyse menschlicher Studien wurde nicht gefunden.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Cochlear synaptopathy and hidden hearing loss: a scoping review — <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10715634/>
- **Prüfnotiz:** Relevanz für das Produkt in beide Richtungen: 'Klingeln vorbei = alles gut' ist nicht belegt, ein konkreter Schaden beim Menschen ebenso wenig. Daraus folgt keine App-Funktion, wohl aber eine Grenze für jede Formulierung. Quellen: Scoping Review (PMC10715634), Bramhall et al. 2019 Hear Res 'Mission impossible?' (nicht geöffnet).

### 13. Apple / University of Michigan School of Public Health (Bericht MobiHealthNews) (2021)

- **Aussage:** Apple Hearing Study (Apple und University of Michigan, vorläufige Ergebnisse 2021): Etwa 1 von 10 Teilnehmenden lag mit der wöchentlichen Kopfhörer-Exposition über dem WHO-Grenzwert. Etwa 25 % hatten eine tägliche Umgebungslärm-Exposition über dem WHO-Grenzwert. Hörtests deuteten bei ca. 20 % auf einen Hörverlust nach WHO-Kriterien hin.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Apple, University of Michigan share first results from Apple Hearing Study — <https://mobihealthnews.com/node/149620>
- **Prüfnotiz:** Vorläufige, vom Hersteller mitgetragene Studie mit selbst rekrutierter Stichprobe. Belegt, dass die Kopfhörer-Pegel von iOS als Studiendaten genutzt werden, aber keine Wirkung einer Anzeige. Die Daten gehen laut Apple an die WHO-Initiative 'Make Listening Safe'.

### 14. University of Pretoria (2021)

- **Aussage:** Verhaltensänderung durch Dosis-Feedback: Gefunden wurde nur eine Vorher-nachher-Studie (Universität Pretoria, dbTrack-Ohrhörer mit App, laut Pressematerial in 'Ear and Hearing'). Mit eingeschaltetem Feedback wurde sicherer gehört (Pegel und Dauer). Die Studie war nicht randomisiert, die Entwickler sind beteiligt, und im Feedback-Zeitraum gab es zusätzlich Informationsmaterial.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** 'Fitbit for your ears': UP produces first-of-its-kind solution to encourage safe listening — <https://www.up.ac.za/news/post_2968978-fitbit-for-your-ears-up-produces-first-of-its-kind-solution-to-encourage-safe-listening>
- **Prüfnotiz:** Dass eine Dosisanzeige das Hörverhalten ändert, ist schwach belegt; dass sie Hörschäden reduziert, ist UNBELEGT. Stichprobengröße und Effektstärken konnte ich nicht einsehen.

### 15. International Archives of Occupational and Environmental Health (2016)

- **Aussage:** Kok et al. (systematischer Review; 21 Artikel, 5.424 Berufsmusiker*innen): Die Punktprävalenz muskuloskelettaler Beschwerden liegt zwischen 9 und 68 %, die 12-Monats-Prävalenz zwischen 41 und 93 %. Frauen sind häufiger betroffen. Wegen des hohen Bias-Risikos sind verlässliche Aussagen (z. B. zum Alter) nicht möglich.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** The occurrence of musculoskeletal complaints among professional musicians: a systematic review — <https://researchinformation.umcutrecht.nl/en/publications/the-occurrence-of-musculoskeletal-complaints-among-professional-m/>
- **Prüfnotiz:** Die Häufigkeit ist robust, das genaue Ausmaß wegen der großen Spannweite unsicher. Instrumentalist*innen, nicht DAW-Produzierende. Erschienen in Int Arch Occup Environ Health 89(3):373–396, doi 10.1007/s00420-015-1090-6 (laut Suchtreffer).

### 16. Occupational Medicine (2016)

- **Aussage:** Baadjou et al. (systematischer Review zu Risikofaktoren): Weil prospektive Studien fehlen, konnten keine kausalen Zusammenhänge für spielbedingte muskuloskelettale Erkrankungen bei Instrumentalist*innen festgestellt werden.
- **Stufe:** D · **geöffnet:** nein
- **Quelle:** Systematic review: risk factors for musculoskeletal disorders in musicians — <https://cris.maastrichtuniversity.nl/en/publications/systematic-review-risk-factors-for-musculoskeletal-disorders-in-m>
- **Prüfnotiz:** Grad D bezieht sich auf KAUSALE Risikofaktor-Aussagen (z. B. 'Haltung X verursacht RSI'). Zu Ergonomie bei Musikproduktion am Computer oder Touchscreen fand ich keine eigene Studie (UNBELEGT); Fachartikel wie Attack Magazine sind Meinung.

### 17. Cochrane Database of Systematic Reviews (CD008570.pub3) (2018)

- **Aussage:** Cochrane-Review Hoe et al. (15 Studien, 2.165 Beschäftigte) zu ergonomischen Maßnahmen gegen Erkrankungen von Arm und Nacken bei Büroarbeit: Armauflage mit alternativer Maus senkte laut Abstract mit mittlerer Evidenz die Inzidenz von Nacken- und Schulterbeschwerden (RR 0,52; 95 %-KI 0,27–0,99), die Befunde sind insgesamt aber inkonsistent. Zusätzliche Pausen reduzieren Beschwerden nur mit niedriger bis sehr niedriger Evidenz. Schulung zeigt keinen Effekt.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Ergonomic interventions for preventing work-related musculoskeletal disorders of the upper limb and neck among office workers — <https://www.cochrane.org/CD008570>
- **Prüfnotiz:** Die Pausen-Evidenz ist schwach und widersprüchlich zwischen den Fassungen: In der Fassung 2012 fand sich kein Unterschied. Das ist nicht auf Musikproduktion übertragen. GRADE-Formulierungen aus Suchtreffern; Volltext CD008570.pub3 prüfen.

### 18. PLOS ONE 17(8): e0272460 (2022)

- **Aussage:** Albulescu et al. (Meta-Analyse; 19 Arbeiten, 22 Stichproben, N=2.335) zu Mikropausen von höchstens 10 Minuten: kleine signifikante Effekte auf Vitalität (d=0,36) und Ermüdung (d=0,35). Kein signifikanter Effekt auf die Leistung (d=0,16; p=0,116). Längere Pausen hängen mit einer stärkeren Leistungswirkung zusammen.
- **Stufe:** B · **geöffnet:** nein
- **Quelle:** 'Give me a break!' A systematic review and meta-analysis on the efficacy of micro-breaks for increasing well-being and performance — <https://doaj.org/article/c6f37b6ba159469296b2cb968b65505f>
- **Prüfnotiz:** Allgemeine Arbeitsaufgaben, nicht musikspezifisch. Belegt Wohlbefinden-nahe Kurzzeit-Endpunkte, keine Gesundheitsprävention. DOI 10.1371/journal.pone.0272460.

### 19. Postgraduate Medical Journal (PubMed 39764644); Zirek et al. (NTU IRep) (2025)

- **Aussage:** Smartphone-Übernutzung und Nackenschmerz (Meta-Analyse; 7 retrospektive Studien, 10.715 Teilnehmende): gepoolte adjustierte Odds Ratio 2,34 (95 %-KI 1,44–3,82). Ein systematischer Review von Zirek et al. (18 Studien) berichtet eine Prävalenz muskuloskelettaler Beschwerden bei Handynutzer*innen von 8,2–89,9 % auf Basis von Querschnitts- und Fall-Kontroll-Daten.
- **Stufe:** C · **geöffnet:** nein
- **Quelle:** Association of smartphone overuse and neck pain: a systematic review and meta-analysis — <https://pubmed.ncbi.nlm.nih.gov/39764644/>
- **Prüfnotiz:** Retrospektiv bzw. Querschnitt; 'Übernutzung' ist uneinheitlich definiert, Kausalität nicht belegt. Für Touchscreen-Musikproduktion auf dem iPhone ist das nur ein indirekter Hinweis.

### 20. Apple Developer Documentation (2026 (abgerufen))

- **Aussage:** HealthKit HKQuantityTypeIdentifier.headphoneAudioExposure (iOS/iPadOS 13+, watchOS 6+, macOS 13+, visionOS 1+): Kopfhörer-Exposition in A-bewerteten Schalldruck-Einheiten (decibelAWeightedSoundPressureLevel), als diskrete Werte des äquivalenten Dauerschallpegels (Leq). Die Werte können automatisch von iPhone oder Apple Watch erfasst werden. environmentalAudioExposure (Umgebungslärm) wird von der Apple Watch erfasst. environmentalSoundReduction (iOS 16+) misst die Pegelminderung durch Kopfhörer, die Umgebungsgeräusche dämpfen.
- **Stufe:** n/a (API-Dokumentation) · **geöffnet:** ja
- **Quelle:** headphoneAudioExposure / environmentalAudioExposure / environmentalSoundReduction — <https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/headphoneaudioexposure>
- **Prüfnotiz:** Selbst geöffnet. Die Kopfhörer-Pegel misst das System, nicht die App. Eine DAW muss sie also nicht selbst messen, sondern kann sie mit Freigabe lesen. Ob die Ausgabe einer Dritt-App wie Echoel als Medien-Audio mitgezählt wird, ist UNBELEGT; das lässt sich am Gerät prüfen (Health-App nach einer Session).

### 21. Apple Developer Documentation (2026 (abgerufen))

- **Aussage:** HKCategoryTypeIdentifier.headphoneAudioExposureEvent (iOS 14.2+, watchOS 7.1+): iPhone und Watch speichern diesen Eintrag, wenn sie eine Benachrichtigung über laute Kopfhörer-Wiedergabe ausgeben. Einziger Wert ist sevenDayLimit; die Metadaten HKMetadataKeyAudioExposureLevel und HKMetadataKeyAudioExposureDuration geben Pegel und Dauer an. In manchen Regionen lässt sich die Benachrichtigung unter Einstellungen > Töne & Haptik > Kopfhörersicherheit abschalten. environmentalAudioExposureEvent (Lärm-Benachrichtigung der Watch, Mittelwert über 3 min) ist ausdrücklich NUR LESBAR: Apps können keine Schreibberechtigung anfordern.
- **Stufe:** n/a (API-Dokumentation) · **geöffnet:** ja
- **Quelle:** headphoneAudioExposureEvent / HKCategoryValueHeadphoneAudioExposureEvent / environmentalAudioExposureEvent — <https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/headphoneaudioexposureevent>
- **Prüfnotiz:** Selbst geöffnet. Ob headphoneAudioExposureEvent ebenfalls nur lesbar ist, steht nicht auf der Seite (UNBELEGT).

### 22. Apple Developer Documentation (2026 (abgerufen))

- **Aussage:** HealthKit-Freigabe: Für jeden Datentyp braucht die App eine eigene Lese- bzw. Schreibfreigabe. Ob das Lesen verweigert wurde, erfährt die App nicht; sie sieht dann nur selbst gespeicherte Einträge. Nutzer können den Zugriff auf ein jüngeres Zeitfenster beschränken (getEarliestAuthorizedSampleDate). Pflicht sind NSHealthShareUsageDescription und NSHealthUpdateUsageDescription. Freigaben lassen sich jederzeit in Einstellungen bzw. der Health-App widerrufen.
- **Stufe:** n/a (API-Dokumentation) · **geöffnet:** ja
- **Quelle:** Authorizing access to health data — <https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data>
- **Prüfnotiz:** Selbst geöffnet. Repo-Bezug: Resources/iOS/Info.plist (Zeile 85) beschreibt den Lesezugriff heute als 'reads heart rate and HRV'. Kommen Audio-Expositionstypen hinzu, muss dieser Text angepasst werden; die Datei ist founder-gated (.claude/rules/context.md §3). Eine Anzeige muss 'keine Daten' neutral darstellen, weil Verweigerung und Abwesenheit gleich aussehen.

### 23. Apple Developer Documentation / Apple Developer Forums (thread 749742) (2026 (abgerufen); Forum 2024)

- **Aussage:** AVAudioSession.outputVolume liefert nur die systemweite Lautstärke als 0,0–1,0. Die Systemlautstärke kann nur der Nutzer direkt setzen, Apps bieten dafür MPVolumeView an. Eine öffentliche API, die den Schalldruck am Ohr in Echtzeit liefert, ist nicht dokumentiert. Im Apple-Developer-Forum gibt es darauf keine Antwort, ein Antwortender verweist auf die unbekannte Kopfhörer-Empfindlichkeit.
- **Stufe:** n/a (API-Dokumentation) · **geöffnet:** ja
- **Quelle:** AVAudioSession.outputVolume; 'How to get realtime headphone levels in decibel unit' — <https://developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume>
- **Prüfnotiz:** Selbst geöffnet. Folge: Eine App kann aus ihrem eigenen Signal (dBFS/LUFS) plus Lautstärkeregler KEINEN validen dB(A)-Wert am Ohr berechnen. Die Abwesenheit einer solchen API ist nur 'nicht gefunden', nicht bewiesen. Eine API zum Lesen oder Setzen von 'Lautstärke reduzieren' wurde ebenfalls nicht gefunden (UNBELEGT).

### 24. Apple Support (HT211903 / 108968; iPhone User Guide); Macworld (2020–2025)

- **Aussage:** Laut Apple-Support lösen Kopfhörer-Benachrichtigungen aus, wenn die Exposition innerhalb von 7 Tagen insgesamt mehr als 40 h über 80 dB lag. Gezählt wird nur Medien-Audio, keine Telefonate. Nach einer Benachrichtigung wird die Lautstärke beim nächsten Verbinden automatisch gesenkt. In manchen Ländern ist die Funktion nicht abschaltbar. Messungen sind mit Apple- und Beats-Kopfhörern am genauesten (AirPods genauer als Kabel); bei anderen Kopfhörern werden sie aus der iPhone-Lautstärke geschätzt. 'Lautstärke reduzieren' (Reduce Loud Audio) begrenzt laut Drittquellen auf einen wählbaren dB-Wert (iOS 14: 75–100 dB in 5-dB-Schritten) und wirkt auch auf Bluetooth-Lautsprecher.
- **Stufe:** n/a (Herstellerdoku) · **geöffnet:** nein
- **Quelle:** Headphone notifications on your iPhone, iPad, or Apple Watch; Monitor audio levels — <https://support.apple.com/HT211903>
- **Prüfnotiz:** support.apple.com war gesperrt, daher nicht geöffnet. Die WHO-Herkunft der 80-dB/40-h-Schwelle nennt Apple laut Suchtreffer nicht selbst; sie entspricht aber H.870 Mode 1. Die Angaben zu 'Lautstärke reduzieren' stammen aus Drittquellen (Macworld, Yamaha). Folge: Jede Anzeige muss Apples Genauigkeitsvorbehalt mitführen.

### 25. Apple (2026 (abgerufen))

- **Aussage:** App Store Review Guidelines 1.4.1: Apps müssen Daten und Methodik offenlegen, um Genauigkeitsbehauptungen zu Gesundheitsmessungen zu stützen; ist die Genauigkeit nicht validierbar, wird die App abgelehnt. 5.1.3(i): HealthKit-Daten dürfen nicht für Werbung, Marketing oder Data-Mining genutzt werden, und die erhobenen Gesundheitsdaten müssen offengelegt werden. 5.1.3(ii): Apps dürfen keine falschen oder ungenauen Daten in HealthKit schreiben und keine persönlichen Gesundheitsdaten in iCloud speichern. 5.1.3(iii)/(iv): Gesundheitsbezogene Forschung am Menschen braucht eine informierte Einwilligung und ein Votum einer unabhängigen Ethikkommission.
- **Stufe:** n/a (Richtlinie) · **geöffnet:** ja
- **Quelle:** App Store Review Guidelines (1.4.1, 5.1.3) — <https://developer.apple.com/app-store/review/guidelines/>
- **Prüfnotiz:** Selbst geöffnet. Direkt anwendbar: eine selbst geschätzte 'Gehörbelastung' wäre eine nicht validierbare Genauigkeitsbehauptung, und das Schreiben geschätzter Expositionswerte in HealthKit verstößt gegen 5.1.3(ii). Jede Forschungskooperation braucht ein Ethikvotum.

### 26. Europäische Kommission (Spiegel: legislation.gov.uk); FÖD Volksgesundheit Belgien (2009)

- **Aussage:** EU-Beschluss 2009/490/EG (auf Grundlage der Produktsicherheitsrichtlinie 2001/95/EG) legt die Sicherheitsanforderung für persönliche Musikabspielgeräte fest: Bei 80 dB(A) sind höchstens 40 h/Woche, bei 89 dB(A) höchstens 5 h/Woche zulässig, dazwischen linear interpoliert. Geräte müssen angemessen vor den Risiken warnen und informieren. Die Norm EN 50332-3 setzt 1,6 Pa²h (entspricht 80 dB(A) Leq über 40 h) als 100-%-Wochendosis.
- **Stufe:** n/a (Recht/Norm) · **geöffnet:** nein
- **Quelle:** Commission Decision 2009/490/EC, Article 3 – Requirements; Noise standard personal music players — <https://www.legislation.gov.uk/eudn/2009/490/article/3/data.htm>
- **Prüfnotiz:** eur-lex war gesperrt; der Text stammt aus der Spiegelung auf legislation.gov.uk und einer belgischen Gesundheitsseite. Der Bezug zur heutigen EN IEC 62368-1 ist in dieser Sitzung nicht belegt. Adressat sind Gerätehersteller, nicht App-Anbieter; die Werte stimmen mit H.870 Mode 1 überein.

### 27. Europäisches Parlament und Rat (Spiegel: legislation.gov.uk); Health and Safety Authority Irland (2003)

- **Aussage:** Lärmschutz-Richtlinie 2003/10/EG für Beschäftigte: unterer Auslösewert LEX,8h 80 dB(A) (Spitze 112 Pa), oberer Auslösewert 85 dB(A) (140 Pa), Expositionsgrenzwert 87 dB(A) (200 Pa). Gehörschutz zählt beim Grenzwert, nicht bei den Auslösewerten. Für Musik und Unterhaltung sieht sie einen Verhaltenskodex mit praktischen Leitlinien vor; laut irischer HSA gilt sie für diese Branchen seit 15.02.2008.
- **Stufe:** n/a (Recht) · **geöffnet:** nein
- **Quelle:** Directive 2003/10/EC (noise); The Noise of Music — <https://www.legislation.gov.uk/eudr/2003/10/data.htm>
- **Prüfnotiz:** Adressat sind Arbeitgeber und Beschäftigte, nicht eine App. Kontext für angestellte Musiker*innen und Tontechniker*innen. Die deutsche Umsetzung (Lärm- und Vibrations-Arbeitsschutzverordnung) habe ich nicht geöffnet. Den Wortlaut von Art. 14 nicht eingesehen.

### 28. MDCG / Europäische Kommission (Kommentar: OpenRegulatory; CMS Hasche Sigle) (2019 / Rev.1 2025)

- **Aussage:** Medizinprodukte-Recht: Nach MDR 2017/745 und MDCG 2019-11 (Rev.1, 2025) entscheidet die vom Hersteller festgelegte Zweckbestimmung, ob Software ein Medizinprodukt ist; medizinische Zwecke umfassen u. a. Diagnose, Prävention und Überwachung von Krankheiten. Allgemeine Wellness-Software ohne klinische Behauptung fällt nicht darunter. Ein Disclaimer 'kein Medizinprodukt' genügt allein nicht, entscheidend ist die Funktion. Werbung mit Wirkung auf eine Krankheit kann zudem nach § 3 HWG irreführend sein.
- **Stufe:** n/a (Recht/Leitlinie) · **geöffnet:** nein
- **Quelle:** MDCG 2019-11: Qualification and classification of software, explained; Medical Apps – Rechtliche Fallstricke — <https://openregulatory.com/mdcg/mdcg-2019-11>
- **Prüfnotiz:** Weder Gesetzestext noch MDCG-PDF geöffnet (eur-lex und Kommission gesperrt). Quelle sind Kommentare (OpenRegulatory, CMS, Nawroth 2007). Folge: 'verhindert Hörschäden' oder 'schützt Ihr Gehör' ist eine Präventions-Zweckbestimmung und damit Medizinprodukt-Terrain. Vor jeder solchen Formulierung ist eine rechtliche Prüfung nötig, und das Repo-Gesetz verbietet sie ohnehin.

### 29. FDA (Bericht Axios) (2024)

- **Aussage:** Die FDA hat am 12.09.2024 Apples 'Hearing Aid Feature' als erstes rezeptfreies Hörgeräte-Software-Produkt für AirPods Pro zugelassen (ab 18 Jahren, leichte bis mittlere Schwerhörigkeit). Grundlage ist ein Hörtest am iPhone, dessen Ergebnis über HealthKit gelesen wird.
- **Stufe:** n/a (Regulatorischer Fakt) · **geöffnet:** nein
- **Quelle:** FDA authorizes first OTC hearing aid software for Apple's AirPods Pro — <https://www.axios.com/2024/09/12/fda-hearing-device-otc-apple-airpods>
- **Prüfnotiz:** Zeigt die Grenze: Hörtest und Hörunterstützung sind regulierte Medizinprodukt-Funktionen. Ob auch Hörtest und Hörschutz von der Zulassung erfasst sind, bleibt in den Treffern unklar. Nicht geöffnet.

### 30. SMPTE; EBU (2012 / 2016)

- **Aussage:** Referenz-Abhörpegel sind Kalibrier-Konventionen, keine Gesundheitsgrenzen. SMPTE RP 200 definiert ca. 85 dB SPL(C) 'slow' bei −18 bzw. −20 dBFS-Referenzrauschen für Kino- und Filmmischräume und gilt laut Fassung 2012 nicht für den Heimbereich. Die EBU empfiehlt 73 dBC je Hauptlautsprecher mit einem auf −23 LUFS normierten Referenzrauschen für mittelgroße Regieräume (125–250 m³).
- **Stufe:** n/a (Norm) · **geöffnet:** nein
- **Quelle:** SMPTE RP 200:2012; New EBU test signal sets the (Loudness) reference — <https://pub.smpte.org/doc/rp200/20120418-pub/rp0200-2012.pdf>
- **Prüfnotiz:** Die Quellen nennen teils 83 statt 85 dB je Lautsprecher, die Angaben sind also uneinheitlich. Nicht geöffnet. Folge: Eine 'Referenzlautheit'-Funktion muss den Raumbezug nennen und darf nicht als Gehörschutz erscheinen.

### 31. Echoelmusic-Repository (2026)

- **Aussage:** Repo-Befund: Echoel misst schon heute die DIGITALE Programmlautheit nach ITU-R BS.1770-4 / EBU R128 (momentan 400 ms, kurzzeitig 3 s, integriert, LRA). Der Meter ist abtastratenkorrekt und gilt auf dem Audio-Thread als sicher. LoudnessTarget bietet Lieferziele an: Streaming −14, Podcast −16, Broadcast −23, Kino −24 LUFS.
- **Stufe:** n/a (Code-Fakt) · **geöffnet:** ja
- **Quelle:** EchoelLoudnessMeter.swift / LoudnessTarget.swift — `file:///home/user/Echoelmusic/Sources/Echoelmusic/DSP/EchoelLoudnessMeter.swift`
- **Prüfnotiz:** Selbst gelesen: Sources/Echoelmusic/DSP/EchoelLoudnessMeter.swift (Kopf) und Sources/Echoelmusic/Core/LoudnessTarget.swift. LUFS ist auf digitale Vollaussteuerung bezogen und sagt ohne Kopfhörer-Empfindlichkeit und Lautstärke nichts über dB(A) am Ohr. Im Repo gibt es keinen HealthKit-Leser für Audio-Exposition (git grep: nur heartRate, HRV SDNN, respiratoryRate).
