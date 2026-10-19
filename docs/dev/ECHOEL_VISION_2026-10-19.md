# Echoel — Vision, Ordnung und Mehrjahres-Roadmap

**Stand 2026-10-19 · Status: CURRENT, Einstieg für jede Scope-, Reihenfolge- oder Außenfrage.**
Diese Datei entscheidet nur, was in §11 steht. Für alles andere sagt sie, welche Datei die Frage
beantwortet. Wer hier eine Zahl braucht, findet den Befehl daneben, nicht die Zahl.

**Founder-Auftrag, wörtlich (2026-10-19):** *„Ultraechoel mit dem Neuen Wissen: Alles
Aktualisieren, kombinieren der Echoelmusic Vision im Repo, TestFlight Deploy und Website. Wir haben
den gesamten Kontext nun auf dem Prüfstand und sehen über den gesamten künstlerischen Ansatz über
die Gesundheitlichen Aspekte, die ich erforschen will von produktionsgesundheit, Oneclock,
Biofeedback, Knochen-, Wund-, Gewebe- und Orgsnheilung, sowie Inklusion accesible Design,
EchoelBodyVibe Instrument , alle anderen vorbereiteten EchoelTools aus der Featurematrix der
gesamten history seit Beginn der Entwicklung, DMMW GMMW GSIMMW. Langfristiges ausrollen meines
gesamten Peaceful, Business über mehrere Jahre."*
Auf den Hinweis, dass Heilung als Forschungslinie ohne jede Behauptung in App, Store, Website und
Förderantrag geführt wird, antwortete der Founder: *„Weiter“*. Diese Lesart gilt (§6).

Grundlage: eine Korpus-Karte über acht Bündel (Gesetz und Pläne, Feature-Historie, Gesundheit,
Inklusion, Geschäft, Website, Studio und TestFlight, Generatives) plus ein Kritiker, gemessen am
Branch `claude/echoelmusic-review-optimize-u5jjpd`. Die Karte selbst liegt nicht im Repo; ihre
Befunde stehen hier, jeder mit der Datei, aus der er stammt.

---

## 0. In fünf Sätzen

1. **Echoel ist zuerst eine Musik-Workstation für iPhone und iPad** (Echoel Studio, `EchoelStudio/`),
   und sie wächst Modul für Modul zu der verteilten Multimedia-Werkstatt, die das Produktgesetz
   beschreibt: Körpersignale, Bild, Licht und Raum kommen hinzu, jedes erst, wenn es funktioniert.
2. **Es gibt eine Ordnung der Dokumente** (§1): das Produktgesetz sagt, wohin es geht und was nie
   zurückkommt; NEUSTART sagt, was in die erste Fassung gehört; NEUPLANUNG sagt, in welcher
   Reihenfolge gebaut wird; diese Datei sagt, wann, und wo welche Frage beantwortet wird.
3. **Die Namensleiter ist intern** (§3): DMMW ist das Ziel, GMMW die generative Schicht darauf,
   GSIDMMW der Forschungshorizont. Nach außen sagt Echoel, was ein Werkzeug tut.
4. **Gesundheit ist eine Forschungslinie, kein Produktversprechen** (§6). Im Produkt gibt es nur,
   was sich als Mechanismus beschreiben lässt: Lautheit messen, Pausen anbieten, barrierefrei
   bedienen. Heilung von Knochen, Wunden, Gewebe oder Organen bleibt außerhalb von Code und Kopie.
5. **Das Geschäft ist ruhig und überprüfbar** (§7): App frei, eigene Plugins als Einmalkauf, kein
   Abo, kein Konto, keine Telemetrie, offener Code. Daneben Förderung für die offenen Pakete und die
   künstlerische Praxis des Founders als eigene Einnahme.

---

## 1. Welche Datei beantwortet welche Frage

| Frage | Datei | Rolle |
|---|---|---|
| Wohin geht Echoel, was kommt nie zurück? | `docs/dev/FOUNDER_PRODUCT_LAW.md` | **Ziel und rote Linien.** Der volle DMMW-Umfang, das Bio-Gesetz (§4), die Infrastruktur-Regel. |
| Was gehört in die erste Fassung von Echoel Studio? | `docs/dev/NEUSTART_2026-10-17.md` | **Produktgrenze der ersten Fassung.** Ohne Körper, Visual, Video, Licht, Raum, Genres und generierte Noten. |
| In welcher Reihenfolge wird gebaut? | `docs/dev/NEUPLANUNG_2026-10-18.md` §5 | **Reihenfolge P0–P7.** Ersetzt die Reihenfolge-Teile von NEUSTART. |
| Wann, über die Jahre? | diese Datei §8 | **Zeitachse.** Die einzige datierte Mehrjahres-Planung im Repo. |
| Was gibt es heute wirklich? | der Code unter `EchoelStudio/App` (Studio, gemessen; `EchoelStudio/RELEASE` ist nur die Prüfliste) · `docs/dev/FEATURE_STATUS.md` (Alt-App) | **Ist-Stand.** FEATURE_STATUS kennt das Studio noch nicht (§10, Lücke L1). |
| Was darf nach außen gesagt werden? | `ContentPipeline/CLAIMS.md` | **Behauptungsregister.** Gilt für Website, Store, Content und Förderantrag. |
| Was gab es früher, und hat es funktioniert? | `docs/dev/HISTORY_ARCHIVE.md` | **Archiv.** Mit DO-NOT-RESTORE-Liste (§N). |
| Wie läuft die Förderung? | `docs/dev/FOERDERUNG_PROTOTYPE_FUND_2026.md` | Prototype Fund, Jahrgang 03, Frist 30.11.2026 15:00. |
| Was muss der Founder entscheiden? | `docs/dev/FOUNDER_INBOX.md` | Jede Frage einmal, vorher gegrept. |
| Reihenfolge der Alt-App (WA1–WA4) | `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` | **Geschichte.** Gilt für die eingefrorene Alt-App, nicht für das Studio. |

**Konfliktregel.** NEUSTART/NEUPLANUNG und das Produktgesetz widersprechen sich nicht: das eine ist
die erste Fassung, das andere das Ziel. Wo zwei Stellen dasselbe verschieden sagen, gilt das neuere
datierte Founder-Wort. Wo kein Founder-Wort existiert, gilt die Datei aus der Tabelle oben. Andere
Pläne (`PLAN_GMMW_2026-10-08`, `DMMW_DEEP_ARCHITECTURE_2026-10-15`, `ULTRAPLAN_2026-09-10`,
`GSIDMMW_AUDIT_2026-10-16`) sind **Ideenquellen für die Phasen P4–P7**, keine Reihenfolge.

---

## 2. Der eine Produktsatz

**Deutsch:** Echoel ist eine Musik-Workstation für iPhone und iPad: Instrumente, Effekte,
Arrangement, eine Session-Ansicht für Live-Sets, Mischen und Export. Körpersignale, Bild, Licht und
Raum kommen als eigene Module dazu, jedes erst, wenn es funktioniert.

**English:** Echoel is a music workstation for iPhone and iPad: instruments, effects, arrangement,
a session view for live sets, mixing and export. Body signals, visuals, light and space join as
separate modules, each one when it works.

Dieser Satz ersetzt die anderen Fassungen nicht im Wortlaut, er ist die eine, aus der künftige
Kopie zitiert. Die fünf älteren Fassungen (Produktgesetz, NEUSTART, NEUPLANUNG, `memory/vision.md`,
`CLAUDE.md`) beschreiben entweder das Ziel oder die Alt-App; jede trägt einen Verweis hierher.

**Was Echoel nicht ist** (unverändert gültig): kein Wellness-, Therapie- oder Meditationsprodukt,
kein Medizinprodukt, kein Ersatz für Spezialinfrastruktur (Codecs, Dante, NDI, Streaming-CDNs,
Plugin-SDKs). Echoel bindet sie an, statt sie nachzubauen.

---

## 3. Die Namensleiter: DMMW → GMMW → GSIDMMW

| Name | Bedeutung | Stand |
|---|---|---|
| **DMMW** | *distributed multidimensional multimedia workstation*: Audio, MIDI, Instrumente, Effekte, Aufnahme, Arrangement, Mix, Mastering, Automation, Video, Visual, Licht, Raum, Zusammenarbeit. | **Ziel** (`FOUNDER_PRODUCT_LAW.md`). Das Studio baut den Audio- und MIDI-Kern zuerst. |
| **GMMW** | *generative multidimensional multimedia workstation*: dieselbe Werkstatt, in der **Generatoren Geräte auf Spuren sind** (Komponier-Hilfen, Sampler, Slicer, Bild-Saat, der Assistent). Sie schreiben normale, editierbare Teile, nie ungefragt, jede Aktion mit einem Schritt rückgängig. Keine neue Navigation. ⚠️ Bis 1.0 gilt NEUPLANUNG §0.2/§2.1: Noten stammen nur aus Spiel, Eingabe, Import oder dem Assistenten auf ausdrückliche Bitte — Noten VORSCHLAGENDE Komponier-Hilfen kommen nach 1.0 und sind eine Founder-Frage. | **Entschieden in dieser Sitzung** (GM1, §11). Der Assistent im Studio ist der erste Baustein. |
| **GSIDMMW** | *Generative Superintelligence Distributed Multidimensional Multimedia Workstation*: der Forschungshorizont, in dem generative Intelligenz die Bereiche verbindet. | **Nordstern ohne Datum** (`FOUNDER_PRODUCT_LAW.md`, 2026-10-16). Nie ausgelieferte Fähigkeit. |
| **GSIMMW** | Schreibweise des Founders für GSIDMMW. | Kein eigener Begriff (§11). |

**Regel nach außen:** Keiner dieser Namen steht in Store-Text, Website-Kopie oder In-App-Text als
Fähigkeit. „Superintelligenz“ und „Superintelligence“ stehen nirgends nach außen (Wächter
`TheCopyMakesNoHealthClaimTests`). Nach außen heißt es, was ein Werkzeug tut: „schlägt eine Basslinie
in der Tonart vor, die du bearbeiten kannst“, nicht „GMMW“.

---

## 4. Stand heute: zwei Codebasen in einem Repo

**Echoel Studio** (`EchoelStudio/`, Neustart 2026-10-17) ist das Produkt. iPhone und iPad, eine
universelle App, Swift 6, keine externen Abhängigkeiten. Messen statt zitieren:

```
cat EchoelStudio/RELEASE                       # Prüfliste des letzten Builds — keine Quelle für Behauptungen
git ls-files 'EchoelStudio/*.swift' | wc -l    # Größe
grep MARKETING_VERSION EchoelStudio/project.yml
```

Gebaut und in TestFlight, **nichts davon gerätegeprüft**: Instrumente (Synth, Drums, Sampler),
Effekte, Arrangement mit Parts, Session-Ansicht mit Szenen und Launch-Quantisierung, Automation,
MIDI-Aufnahme mit Bend und CC, Audio-Aufnahme auf Spuren, Mix mit Metern, Master-Kette, Export mit
LUFS und True-Peak, MIDI-Datei-Export, Import alter Projekte (gebaut, in 10004/10005 aber wirkungslos:
ohne App Group sieht Studio die alten Songs nicht, F17), eigene AUv3-Instrumente (in keiner Host-App
auf einem Gerät geprüft — die AUM-Messung #1386 gilt nur `echl` der Alt-App) mit gebautem Einmalkauf
(nicht im Verkauf: kein In-App-Kauf in App Store Connect, F-15), der Assistent auf dem Gerät, die
About-Seite.

**Die Alt-App** (`Sources/Echoelmusic`, eingefroren bei 10.79.515) ist die **Port-Quelle**. Dort
leben Kamera-Puls (rPPG), Bluetooth-Gurt, HealthKit, die Egress-Policy, OSC, ADM-OSC, Art-Net, sACN,
das Metal-Visual, die Videospur und eine Video-Aufnahme. Portiert wird nach NEUPLANUNG §4 („Kern
übernehmen, nie ein Subsystem zurückkopieren“). Archiviert wird erst nach Studio-1.0 und nur per
Founder-Entscheidung.

⚠️ **Der öffentliche `main`-Zweig zeigt keines von beiden Neuen.** `EchoelStudio/`, NEUSTART,
NEUPLANUNG, der Förderantrag und diese Datei liegen nur auf dem Arbeitszweig; Studio-Commits stehen
in keinem Auto-Merge-Filter. Wer `main` liest (Jury, Öffentlichkeit), sieht die Alt-App.
`git rev-list --count origin/main..HEAD` misst den Abstand. Der Merge gehört dem Founder (F-08b). ⚠️ Das
betrifft auch die Website: `main` trägt die Datenschutzseite mit „Microphone Access: Not requested“, während
der Studio-Build in TestFlight das Mikrofon anfragt (FOUNDER_INBOX F22).

---

## 5. Domänen-Register: alle EchoelTools aus der Geschichte

Klassen: **STUDIO** = im Studio-Build · **PORT** = in der Alt-App gebaut, kommt als Kern in die
genannte Phase · **PLAN** = geplant, noch nirgends gebaut · **FORSCHUNG** = Frage, kein Plan ·
**NIE** = DO NOT RESTORE (`HISTORY_ARCHIVE.md` §N).

| Familie | Studio heute | Alt-App | Phase | Klasse |
|---|---|---|---|---|
| Instrumente: Synth, Drums, Sampler | gebaut, als AUv3 auch in fremden Hosts | Poly-, Sub-, Body-Stimme | P0–P2 | **STUDIO** |
| Effekte: EQ, Kompressor, Delay, Reverb | gebaut, frei | Kette mit Genre-Presets | P0–P2 | **STUDIO** |
| Arrangement, Parts, Automation, Undo | gebaut | Timeline, Part-Editor | P0–P1 | **STUDIO** |
| Session-Ansicht, Szenen, Launch | gebaut | — | P0, Mapping in P3 | **STUDIO** |
| Mix, Meter, Master, Export (LUFS, True-Peak, MIDI-Datei) | gebaut | Stems, Freeze | Stems in P1 | **STUDIO** |
| Audio-Aufnahme auf Spuren | gebaut | gelöscht (#1302) | P0 | **STUDIO** |
| MIDI ein/aus, MIDI-Clock, Network MIDI | gebaut, Network MIDI aus per Default | MPE-Ausgang, MIDI-2.0-Quelle | P3 | **STUDIO** |
| Assistent (Befehle per Text, auf dem Gerät) | gebaut | EchoelAI-Werkzeugkern | läuft ab P1 mit | **STUDIO** |
| Startprojekte, Presets, Skalen-Lock | — | Genres (nie portieren) | P1 | **PLAN** |
| Live-Set mit Hardware (Xone:96), Link | MIDI-Clock | — | P3; Ableton Link draußen (§11) | **PLAN** |
| Bühnen-I/O: OSC, ADM-OSC, Art-Net, sACN | — | live | P4, Paket `EchoelIO` | **PORT** |
| Modulation: LFO, Hüllkurvenfolger, Makros | — | Modulations-Matrix | P5 | **PORT** |
| Körper: Kamera-Puls, BLE-Gurt, Atem | — | live, Egress-Policy | P6, Paket `EchoelSense` | **PORT** |
| **EchoelBodyVibe** (Körper-Instrument) | `echl` antwortet mit dem Studio-Synth | Body-Stimme und AUv3 | P6 (§5a) | **PORT** |
| Visual (Metal), externer Bildschirm | — | live | P7 | **PORT** |
| Raum: Objekt-Rendering, Binaural, Ambisonics | — | Steuerhälfte live, Render-Kerne ohne Aufrufer | nach P7 | **PORT** |
| Video: Spur, Aufnahme, Schnitt | — | Videospur und Aufnahme gebaut | nach P7, Founder-Frage | **PORT** |
| Apple Watch, Mac, Vision Pro | — | Watch kompiliert, nicht eingebettet | 2029 (§8) | **PLAN** |
| Zusammenarbeit, Streaming | — | Gerüst, nicht verlinkt | nach 2028 | **PLAN** |
| Generatoren (GMMW) | Assistent | Bild-Saat, Grain | Sampler/Slicer ab P1; Noten schreibende Komponier-Hilfen nach 1.0 (Founder-Frage, NEUPLANUNG §0.2/§2.1) | **PLAN** |
| Lernen (Musik durch den Körper) | — | `LearnLibrary` | nach P6 | **PLAN** |
| One Clock (Webseite) | — | — | live auf der Website | **LIVE** |
| Produktionsgesundheit | Lautheitsmessung | — (in der App keiner; die Website trägt einen Hörschutz-Text in `docs/health.html`) | §6 | **FORSCHUNG** |
| Knochen-, Wund-, Gewebe-, Organheilung | — | — | §6 | **FORSCHUNG**, nie Produkt |
| Brainwave-Entrainment, Heilfrequenzen, Organresonanz, Farbtherapie | — | `EchoelEntrainment` verdrahtet, türlos | — | **NIE** |
| NFT, Krypto, Token | — | — | — | **NIE** |

### 5a. EchoelBodyVibe — entschieden

EchoelBodyVibe hatte drei Bedeutungen: die Body-Stimme auf einer Spur der Alt-App, das AUv3
„Echoelmusic: EchoelBodyVibe“ (`aumu`/`echl`) und im Studio nur noch den Subtyp, den der
Studio-Synth beantwortet.

**Ab jetzt heißt EchoelBodyVibe das Körper-Instrument des Studios und kommt in P6.** Es ist ein
Instrument wie die anderen, spielbar mit Tastatur und MIDI, und es nimmt Körpersignale als
Modulationsquelle über `EchoelSense`, wenn ein Sensor da ist. Ohne Sensor klingt es trotzdem. Bis
dahin bleibt `echl` die Tür für alte Host-Sessions und klingt mit dem Studio-Synth. Der Name wird
nach außen erst benutzt, wenn das Instrument mit Körpersignal läuft (die Regel von 2026-07-17: ein
Etikett darf nicht lügen).

⚠️ In der Alt-App tragen zwei AUv3-Presets die Namen „Deep Sleep“ und „Active Focus“
(`EchoelBodyVibeDevice.swift`), und `EchoelEntrainment` benennt Bänder mit Schlafzuständen. Beides
steht gegen die DO-NOT-RESTORE-Liste. Die Alt-App ist eingefroren, deshalb wird nichts geändert;
der Port in P6 übernimmt die Namen nicht (GM19 bleibt im Founder-Eingang).

---

## 6. Gesundheit: eine Forschungslinie mit Grenze

**Die Grenze zuerst.** Echoel ist kein Medizinprodukt. Sobald eine Software nach ihrer
Zweckbestimmung Krankheiten erkennen, behandeln, lindern oder heilen soll, ist sie nach der
EU-Medizinprodukteverordnung ein Medizinprodukt und braucht eine Konformitätsbewertung; eine Werbung mit Heilwirkung ohne gesicherte Evidenz ist nach dem
Heilmittelwerbegesetz irreführend (§3 HWG). Deshalb gilt weiter, ohne Ausnahme:

- Keine Heil-, Therapie-, Wellness- oder Meditationsbehauptung in App, Store-Text, Website,
  Content oder Förderantrag. Wächter: `TheCopyMakesNoHealthClaimTests` (Website, Store-Text,
  String-Katalog der Alt-App). Die Studio-Texte und `ContentPipeline/` scannt er nicht; dort gilt die
  Regel ohne Wächter.
- Kein Code, der eine Heilwirkung verspricht oder einen Körperzustand „herstellen“ soll.
- Mechanismus ja, Wirkung nein: „dein ruhiger Puls verändert die Musik“ ist wahr, „Echoel macht dich
  ruhig“ ist es nicht (`ContentPipeline/CLAIMS.md`).
- Sicherheitshinweise, 3-Hz-Blitzgrenze und „zur Selbstbeobachtung, keine Diagnose“ bleiben Gesetz.

### 6a. Produktionsgesundheit — Definition

**Produktionsgesundheit ist die Gesundheit der Menschen, die mit Echoel produzieren**, soweit eine
Software sie berühren kann, ohne etwas zu behaupten:

1. **Hören.** Echoel misst Lautheit und Spitzenpegel schon heute (LUFS, True-Peak am Export). Das ist
   die *digitale Programmlautheit*, kein Schalldruck am Ohr, und wird auch so beschriftet: iOS gibt einer
   App nur die Systemlautstärke 0–1, die Empfindlichkeit des Kopfhörers ist unbekannt. Ein künftiges
   Werkzeug darf die Sitzungsdauer und, nach Opt-in, die Kopfhörerpegel anzeigen, die iOS selbst in
   Apple Health ablegt, mit Quellenangabe. Es sagt nicht, dass es das Gehör schützt, und nennt die
   WHO-ITU-Referenz (80 dB(A) über 40 h pro Woche) höchstens als Zitat, nie als „sicher“-Ampel.
2. **Belastung.** Lange Sitzungen ohne Pause, Abstürze, die Arbeit kosten, und unklare Oberflächen
   sind die häufigsten Störungen. Die Stabilitätsregeln und die Barrierefreiheit (§6e) sind deshalb
   Teil der Produktionsgesundheit, nicht ein eigenes Feature.
3. **Arbeit ohne Zwang.** Kein Konto, keine Benachrichtigung, die zur Rückkehr drängt, kein
   Zähler, der Nutzung misst.

Ob ein Hinweis auf Hörpausen sinnvoll ist und wie er klingen darf, ist eine Forschungsfrage (F1
unten). Pausen schützen das Gehör beim Menschen nachweislich nicht (die Daten sind fast nur
Tiermodelle); belegt ist nur, dass weniger Hördauer nach dem Gleichenergie-Prinzip weniger Dosis heißt.

**Regel nach außen:** „Produktionsgesundheit“ ist ein INTERNES Forschungsetikett. Es steht nicht in
Store-Text, Website-Kopie, In-App-Text oder einem Förderantrag als Fähigkeit oder Versprechen. Nach außen
steht, was ein Werkzeug tut („zeigt die Lautheit des Exports in LUFS“), nie, was es für die Gesundheit tue.

### 6b. Biofeedback

Biofeedback bleibt Signalwissenschaft: gemessenes Signal → Qualität → abgeleitetes kreatives Merkmal
→ Einwilligung → Steuerquelle (`FOUNDER_PRODUCT_LAW.md` §4). Im Studio kommt es in P6 als Paket
`EchoelSense`. Die stärkste belegte Kopplung zwischen Atem und Herzrate ist die Resonanzatmung bei
etwa sechs Atemzügen pro Minute (`scratchpads/REPORT_SOUND_PAIN_EVIDENCE_2026-07-12.md`, Deep
Research 2026-09-30). Echoel darf sie als Tempo anbieten und den Puls dazu zeigen. Es behauptet
keinen Nutzen.

### 6c. Knochen-, Wund-, Gewebe- und Organheilung

Der Founder will diese Fragen erforschen. Das ist erlaubt, **als Forschung außerhalb des Produkts**,
so wie die Hardware-Linie außerhalb der App liegt (`memory/vision.md`). Die Form:

- **Wo:** in `research_notes/` und `reports/`, nie in `Sources/`, `EchoelStudio/`, `docs/*.html`,
  `fastlane/`, `ContentPipeline/` oder im Förderantrag.
- **Was:** Literatur lesen und bewerten, mit Evidenzgrad und Quelle. Der Stand im Repo: Vibroakustik um
  40 Hz ist ein echtes, aber an Körperschallwandler gebundenes Forschungssignal, kein
  Telefonlautsprecher-Effekt (`REPORT_SOUND_PAIN_EVIDENCE_2026-07-12.md`). Die Evidenzkarte vom
  2026-10-19 steht in `reports/Evidenzkarte Gesundheitsforschung.md` (Rohkarten je Feld unter
  `research_notes/Evidenzkarte Gesundheitsforschung/`). ⚠️ Nur Apple-Dokumentation und Repo waren
  dort selbst geöffnet; jede andere Zahl kommt aus Suchtreffern und wird vor einem Zitat im Volltext
  geprüft.
- **Wie weiter:** Wer am Menschen forscht, braucht eine Partnerinstitution und ein Ethikvotum. Echoel
  kann dort höchstens ein Messwerkzeug sein, und auch das erst nach einer Prüfung der
  Zweckbestimmung durch eine fachkundige Stelle.
- **Was nie:** Organfrequenzen, „bone harmony“, Gewebe-Resonanz, Heilfrequenzen, Solfeggio,
  Chakra, 432 Hz als Heilung. Diese Liste steht in `HISTORY_ARCHIVE.md` §N und bleibt.

Forschungsfragen, die eine Sitzung bearbeiten darf, ohne etwas zu bauen: **F1** Hörpausen und
Abhörlautstärke: was sagen WHO und ITU zu sicherem Hören? **F2** Vibroakustik: welche Studien gibt
es zu Gewebe, Knochen und Wundheilung, mit welchem Evidenzgrad? **F3** Wo liegt die Grenze der
Zweckbestimmung für eine Musik-App, die Körpersignale anzeigt?

**Stand der drei Fragen (Evidenzkarte 2026-10-19), als Literatur, nicht als Produktaussage:**
**F1** Musizierende berichten deutlich häufiger Tinnitus, Hyperakusis und Hörverlust; für Studio- und
Kopfhörer-Produzierende gibt es keine eigene Studie, und selbst Hörschutzprogramme sind laut Cochrane
nur niedrig belegt. **F2** Dass hörbarer Schall Knochen, Wunden oder Gewebe heilt, ist nicht belegt.
Ultraschall- und Vibrationsbefunde stammen aus Medizinprodukten mit Kontaktkopplung im MHz-Bereich und
lassen sich nicht auf einen Audiopfad unter 24 kHz übertragen; Musik lindert im klinischen Rahmen das
Erleben von Schmerz und Angst, Heilungsendpunkte wurden dabei nicht erhoben. **F3** Die
Zweckbestimmung ergibt sich aus Kennzeichnung, Werbung und Verkaufsangaben (MDR Art. 2 Nr. 12): eine
einzige Heilaussage auf Website, im Store oder in einem Reel macht Echoel zum Medizinprodukt-Kandidaten,
und das Heilmittelwerbegesetz greift auch ohne diesen Status. Forschung mit Nutzerdaten braucht
Einwilligung, Ethikvotum und eine Partnerinstitution als Träger (Apple 5.1.3). Acht konkrete
Forschungsfragen für Partner stehen in der Karte.

### 6d. One Clock

„One Clock“ hat zwei Bedeutungen, und beide bleiben:

- **Die Webseite** `docs/one-clock.html`: ein Atemzyklus an der Weltzeit, frei, ohne Konto, ohne
  Server, ohne Daten, nie hinter einem Kauf. **Sie zählt niemanden** (§11). Sie ist eine
  Einladung, keine Übung mit Wirkversprechen.
- **Die eine Uhr der Engine:** im Studio besitzt der Transport von `EchoelEngine` die Zeit, in der
  Alt-App `PatternEngine`. Eine zweite Uhr ist ein Architekturfehler.

### 6e. Inklusion und barrierefreies Design

Die Messlatte „Ultraaccessible Design“ vom 2026-08-19 gilt ab jetzt auch für das Studio, als
Abnahme vor App Store 1.0 (P2):

1. nichts nur per Geste · 2. nichts nur über Farbe · 3. nichts nur über das Bild · 4. nichts nur
unter Zeitdruck · 5. Dynamic Type bis zur größten Stufe, wo Text trägt · 6. Tippziele mindestens 44
pt · 7. „Bewegung reduzieren“ wird befolgt, Blitzrate höchstens 3 Hz · 8. ein Wort pro Funktion.

Gemessen am Studio heute: VoiceOver-Beschriftungen gibt es in den meisten Ansichten, „Bewegung
reduzieren“ wird nirgends gelesen, und die dichte Transportleiste begrenzt die Schriftgröße. Die
Begrenzung bleibt erlaubt, wo Bedienelemente statt Text tragen und jedes eine VoiceOver-Beschriftung
hat. Messen:

```
git grep -c accessibilityLabel -- 'EchoelStudio/*.swift'
git grep -n "dynamicTypeSize\|accessibilityReduceMotion" -- EchoelStudio
```

Die Förderung trägt die Barrierefreiheits-Abnahme in M3 (30 von ~220 h neben `EchoelIO`: VoiceOver,
„Bewegung reduzieren“, 3-Hz-Grenze als Test). Die Mission des Founders, Musik für Menschen mit Einschränkungen erfahrbarer zu
machen, ist der Grund, nicht ein Werbesatz: eine haptische Dimension wird erst behauptet, wenn sie
mit den Menschen geprüft ist, für die sie gedacht ist.

---

## 7. Geschäft: Peaceful Business

**Haltung, nicht Wirkung** (`memory/vision.md`, Prinzip 9). „Peaceful Business“ heißt, wie Echoel
gebaut und verkauft wird:

- **Transparent:** offener Code unter MIT, jede Zahl mit ihrem Befehl, öffentliche Historie.
- **Ohne Abhängigkeit:** keine externen Pakete, offene Formate (das Song-Format ist dokumentiert),
  offene Protokolle (MIDI, OSC, ADM-OSC, Art-Net, sACN).
- **Sanfter Handel:** die App ist frei und vollständig; eigene Plugins kosten einmal, kein Abo,
  keine künstliche Grenze, kein Lockangebot. Kein Konto, keine Werbung, kein Tracking.
- **Alle inbegriffen:** Barrierefreiheit als Abnahme (§6e).

Nie nach außen: Frieden, Weltfrieden, Einheit, Verzeihen oder Heilung als Wirkung der App. Keine
Öko- oder Vegan-Behauptung über die App. Kein öffentliches Versprechen einer „Musikschule“, solange
es keine gibt.

**Einnahmen über die Jahre, jede für sich überprüfbar:**

| Linie | Form | Stand |
|---|---|---|
| Echoel Plugins | Einmalkauf im App Store (`com.echoelmusic.app.pro`), AUv3-Instrumente | im Build; Produkt in App Store Connect anlegen (Founder) |
| Förderung | Prototype Fund für die offenen Pakete `EchoelSense` und `EchoelIO` | Antrag bis 30.11.2026 |
| Künstlerische Praxis | Wasser-Licht-Klang-Installationen, Auftritte, Auftragsarbeiten des Founders mit Echoel | läuft unabhängig von der App |
| Später | Workshops, Partnerschaften mit Spielstätten | erst wenn die Bühnen-Phase P4 läuft |

⛔ **Abgelöst und nicht mehr Plan:** das „Echoel Live“-Jahresabo und die Gebühr pro Veranstaltung
vom 2026-07-10 (seit 2026-10-17 durch den Einmalkauf ersetzt, `decisions.csv`).

**Die Hardware-Linie** (Liege mit Körperschallwandlern, Tauchflieger) ist ein eigenes Projekt. Sie
hängt über OSC oder DMX an Echoel, sie bekommt keinen Umbau der App und steht nie in Produkt-Kopie.

---

## 8. Mehrjahres-Roadmap

Phasen nach `NEUPLANUNG_2026-10-18.md` §5. **Versionsnummern folgen der Auslieferung, nicht der
Phasennummer.** Daten sind Planung, keine Zusage nach außen. Was nicht fertig ist, rutscht; die
Reihenfolge bleibt.

| Zeitraum | Was | Ergebnis |
|---|---|---|
| **2026 Okt–Dez** | P0 abschließen; P1 Komponieren (Startprojekte, Presets, Skalen-Lock, Stems, Projektpaket); TestFlight-Runden; Förderantrag bis 30.11.; Merge auf `main` (Founder) | öffentliche TestFlight-Beta |
| **2027 Jan–Mär** | P2: eigene AUv3 und Kauf (App schreibt, Erweiterung liest, §8a), Kauf wiederherstellen, Plugin-Vertrag (Host-Takt, Umbruch-Fenster, Presets, Tails), Prüfung in AUM und GarageBand bei 44,1 und 48 kHz, Barrierefreiheits-Abnahme (§6e) | **App Store 1.0**, Ziel März 2027 |
| **2027 Apr–Mai** | P3 Live: MIDI-Clock, Szenen-Mapping für die Xone:96, Network MIDI nur mit bekannten Partnern | 1.1, ein Live-Set auf dem Gerät |
| **2027 Jun–Nov** | Förderzeitraum, falls bewilligt: M1 Paketgerüst, M2 `EchoelSense`, M3 `EchoelIO`, M4 Nutzertest und Paket 1.0. Ohne Bewilligung: P4 nach Plan | offene Pakete, Version 1.0 |
| **2027 Dez – 2028 Mär** | Second Stage (keine Code-Meilensteine); P4 Bühnen-I/O in der App: Event-Spuren, Verbindungen, OSC/Art-Net/sACN/ADM-OSC | 1.2, eine Installation läuft vier Stunden von Echoel aus |
| **2028** | P5 Modulation; P6 Körper mit EchoelBodyVibe; P7 Visual und externer Bildschirm; Kopfhörer-Raum-Monitor, offener ADM-BWF-Master, 360°-Mono-Export (§8a) | 1.3 und folgende |
| **2029** | Raum-Rendering; Video in der Workstation (Founder-Frage); Mac und Vision Pro über die iPad-App; Watch als Anzeige; Desktop-Plugins nach einem Linux-Spike (§8a) | weitere Plattformen |
| **2030 und danach** | GMMW-Generatoren in der Breite; Zusammenarbeit; Forschungshorizont GSIDMMW | ohne Datum |

### 8a. Formate und Plattformen (Recherche 2026-10-19)

Quelle: `reports/AUv3 Raumklang und immersives Video.md` (fünf Notizen unter `research_notes/`, Belege je
Satz; Zahlen von Seiten, die nur über Suchtreffer gelesen wurden, sind vor jeder öffentlichen Verwendung im
Volltext zu prüfen). **Ein Prinzip trägt alles: Echoel besitzt das offene Zwischenformat, die letzte Meile
gehört der Plattform.** Nichts davon ist gerätegeprüft.

- **AUv3 voll:** acht Komponenten in EINER Erweiterung stehen; es fehlt die Hälfte des Vertrags, die ein
  Plugin an den Song koppelt — `musicalContextBlock`/`transportStateBlock` in beide Richtungen, ein Fenster,
  das in jedem Rechteck umbricht (GarageBand ~1024 × 335, Logic fragt keine Größen), Factory- und
  User-Presets, `tailTime` und `isRenderingOffline` im Export, später UMP (iOS 15) und eine `aumi`-Komponente
  für Logics MIDI-FX-Platz. Kauf: StoreKit wird in Erweiterungen nicht unterstützt (Apple DTS, März 2026;
  Guideline 4.4) — die App schreibt den Kauf in die App Group, die Erweiterung liest (Factory-Job 002).
  Abnahme ist eine Host-Matrix am Gerät, kein Zertifikat; ob `auval` eine reine iOS-Erweiterung prüfen
  kann, ist offen und kann eine P2-Abnahme ungültig machen.
- **Raumklang:** eigenes, ADM-förmiges Objektmodell (Objekte · Bett · HOA). Monitor über
  `AVAudioEnvironmentNode` (nur Mono-Eingänge, HRTF), Head-Tracking braucht ein Entitlement (Founder).
  Ausgabe offen: ADM-BWF (BS.2076, BW64), AmbiX, Binaural; APAC nur für Bett und HOA ab iOS 26. **Dolby
  Atmos und Apples ASAF werden nicht behauptet** — das Dolby-Profil ist vertraulich (H19), ASAF hat keine
  öffentliche Spezifikation.
- **Immersives Video:** zuerst 360°-Mono nach Apples Projected Media Profile (ein Kompressionsschlüssel ab
  iOS 18), offline aus dem Visual gerendert, mit dem Blitzbegrenzer in Sehwinkel-Einheiten. Stereo-MV-HEVC
  wartet, weil Apples Adapter laut Doku-Metadaten mit iOS 27 endet; Apple Immersive Video ist auf iOS nicht
  autorisierbar. YouTube/Quest brauchen einen zweiten Weg (Spherical V2). NDI wäre die erste fremde
  Abhängigkeit (Founder).
- **Andere Betriebssysteme:** Apple zuerst. Danach Desktop: CLAP (MIT, nur C-Header) und VST3 (SDK seit
  29.10.2025 MIT) über eine C-ABI um den Foundation-only-DSP (`@c`, SE-0495) — erst ein Linux-Spike in einem
  Host, weil Swift-Laufzeit im fremden Prozess ohne Präzedenz ist; kein CMake, solange die Header reichen
  (für CLAP sicher, für die VST3-C-API zu prüfen — `clap-wrapper` und das VST3-SDK bauen mit CMake). AAX
  nicht planen (PACE). Android und Web nicht vor 2029. **Ableton Link ist außerhalb von iOS GPLv2+** — die
  „frei“-Annahme in `CLAUDE.md` gilt nur für LinkKit auf iOS (F11, GM23).
- **Website:** drei getrennte Räume — gemessen (mit Datum), geplant (Zukunftsform), erforscht (ohne Wirkung).
  Kompatibilität nur mit Messdatum. Über Klang, Vibration, Licht und Bild nur Sicherheit und Mechanismus
  (MDCG 2019-11 rev.1: der Werbetext begründet die Zweckbestimmung). Kein „supports Music Haptics“ — Apples
  Music Haptics gilt für Apple-Music-Titel, nicht für erzeugten Klang; eigene Haptik nur über Core Haptics und
  erst nach Ko-Gestaltung mit gehörlosen Menschen. 40-Hz-Licht nie.

**Bedingungen, die die Tabelle kippen:** Kommt App Store 1.0 nach dem 1. Juni 2027, kollidiert es
mit Förder-M1; dann geht 1.0 vor, und M1 beginnt später im Förderzeitraum. Kommt keine Förderung,
bauen P4 und P6 ihre Pakete selbst, in App-Reihenfolge.

Die Drei-Wochen-Taktung bis 8.11. steht in `docs/dev/TODO_FOUNDER_2026-10-19.md`. Das Artifact
„Echoel Interview-Paket“ trägt eine ältere Fassung dieser Zeitachse (M2 und M3 vertauscht, P5 vor
P4); diese Datei ist neuer und gilt.

---

## 9. Was die Website und der Store sagen

- **Website** (`docs/`): beschreibt, was ausgeliefert ist. Bis Studio 1.0 öffentlich ist, nennt sie
  Echoel Studio als TestFlight-Beta und die Roadmap als Planung mit Datum „Stand“. Die Seite
  `docs/roadmap.html` ist die öffentliche Kurzfassung von §8 ohne Founder-Fragen.
- **Store-Text:** wird aus dem Ist-Stand geschrieben, nie aus dieser Datei. Die Formulierung gehört
  dem Founder.
- **Förderantrag:** folgt `FOERDERUNG_PROTOTYPE_FUND_2026.md` §7.5, gemessen mit
  `python3 -I scripts/ptf-wordcount.py`.

---

## 10. Bekannte Lücken (für die nächsten Sitzungen)

- **L1** `FEATURE_STATUS.md` kennt das Studio nicht; `ContentPipeline/CLAIMS.md` trägt seit `20a5469`
  oben einen Studio-Block mit vier Nachträgen. Bis `FEATURE_STATUS.md` nachzieht, wird Kopie für das Studio gegen den Code unter `EchoelStudio/App`
  geprüft; `EchoelStudio/RELEASE` ist eine Prüfliste für Tester, keine Quelle für Behauptungen.
- **L2** Die Alt-App nimmt Video auf (Front- und Rückkamera, `VideoTakeCamera`), während
  `CLAUDE.md`, `FEATURE_STATUS.md`, die Kamera-Beschreibung in `Resources/iOS/Info.plist` und eine
  Website-Seite das verneinen. Die Alt-App ist eingefroren, die Info.plist founder-gesperrt: Bericht
  an den Founder (`FOUNDER_INBOX.md`).
- **L3** Die Barrierefreiheits-Abnahme des Studios (§6e) hat noch keine Tests.
- **L4** `HISTORY_ARCHIVE.md` sagt richtig, dass es vor dem Graft Heilungs-Code gab (ResonanceHealer,
  gelöscht 2026-01); der Satz „never code here“ in `CLAUDE.md` war historisch falsch. Die rote Linie
  bleibt.
- **L5** ~~Die Evidenzkarte zu §6c ist in Arbeit.~~ Erledigt 2026-10-19: `reports/Evidenzkarte
  Gesundheitsforschung.md`. Offen bleibt die Volltext-Prüfung jeder Zahl, die je zitiert werden soll.
- **L6** Die Evidenzkarte fand zwei Apple-Health-Punkte in der Alt-App: die Lese-Beschreibung in
  `Resources/iOS/Info.plist` nennt Herzfrequenz und HRV, gelesen wird auch die Atemrate (Guideline
  5.1.3(i)); und „Save to Apple Health“ schreibt per Opt-in Werte aus Kamera-rPPG und BLE, deren
  Genauigkeit nicht validiert ist (5.1.3(ii)). Beides ist founder-gesperrt bzw. eingefroren: Bericht in
  `FOUNDER_INBOX.md` F21. Echoel Studio liest und schreibt kein Apple Health.
- **L7** §8a ist Recherche, kein Plan mit Zusage. Vor jeder Behauptung nach außen: Volltext der Quelle, und
  für jede Plattform-Aussage ein Gerätebeleg. Die Founder-Posten daraus stehen in `FOUNDER_INBOX.md` GM23–GM26.

---

## 11. Entscheidungen dieser Datei (je eine Zeile in `decisions.csv`, 2026-10-19)

1. **Autoritäts-Karte** wie §1. NEUSTART/NEUPLANUNG = erste Fassung und Reihenfolge, Produktgesetz =
   Ziel und rote Linien, Masterplan = Geschichte der Alt-App, diese Datei = Zeitachse und Einstieg.
2. **Ein Produktsatz** wie §2.
3. **GM1 beantwortet:** GMMW = generative Werkstatt, Generatoren als Geräte auf Spuren, editierbar,
   nie ungefragt, keine neue Navigation. GSIMMW = GSIDMMW.
4. **EchoelBodyVibe** = Körper-Instrument des Studios in P6; `echl` bleibt bis dahin die Tür für alte
   Sessions.
5. **Gesundheit** = Forschungslinie außerhalb des Produkts (§6c); Produktionsgesundheit definiert
   (§6a); keine Behauptung, keine Ausnahme.
6. **Barrierefreiheit:** die 8-Punkte-Messlatte ist Abnahme für Studio 1.0.
7. **One Clock zählt niemanden** — kein Präsenzzähler, weil er einen Server bräuchte.
8. **Ableton Link bleibt draußen**, bis der Founder es ausdrücklich bestellt („keine
   Abhängigkeiten“, 2026-10-18); die Synchronisation ist MIDI-Clock.
9. **Reihenfolge 1.0:** P1 vor P2, App Store 1.0 mit P2 (Mehrheit von `decisions.csv`, NEUPLANUNG
   und Artifact; die abweichende Zeile in `memory/decisions.md` ist überholt).
10. **Förderreihenfolge:** `EchoelSense` (M2) vor `EchoelIO` (M3), wie im Antrag; das Artifact ist
    älter.
11. **Plugin-Kauf über die App Group** (Factory-Job 002): die App schreibt, die Erweiterung liest, StoreKit in
    der Erweiterung nur Rückfall.
12. **Formate: offenes Zwischenformat zuerst** (§8a) — ADM-förmiges Raummodell und ADM-BWF vor jedem
    proprietären Format; 360°-Mono vor Stereo-Video; keine Behauptung zu Dolby Atmos, ASAF oder Music Haptics.
13. **Desktop-Route:** CLAP, dann VST3, nach einem Linux-Spike über eine C-ABI; kein CMake, kein AAX.
14. **Factory** (`.claude/skills/factory`) ist der Weg für mehrteilige oder sichtbare Scheiben.
11. **Versionsnummern folgen der Auslieferung.**
12. **E28 bleibt:** der CCC wird in keiner Kopie genannt. Ein Vortrag auf einem Kongress ist eine
    persönliche Einreichung des Founders und wird nicht beworben.
13. **Geschäftsmodell:** App frei, Plugins einmal kaufen, kein Abo; „Echoel Live“ ist abgelöst.
