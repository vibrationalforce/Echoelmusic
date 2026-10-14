# Wettbewerb, Kritik und Redesign — 2026-10-14

Auftrag (Echoel, 2026-10-14): Grapes 3D Audio Control, Adamson, d&b, Raumklang-Software für
Event und Theater, Dolby Atmos, 4DSOUND, Imaginando, Loopy Pro, Suno, ACE Studio, Drambo,
Ableton, DaVinci Resolve, OBS, Resolume Arena, TouchDesigner und alle Live-Kollaborations-
Lösungen erforschen, kritisieren und daraus ein optimiertes Redesign für Echoelmusic ableiten.

Methode: fünf Rechercheure parallel, je ein Feld, mit Websuche. Vorher haben sie gelesen, was
das Repo schon erforscht hat (`STRATEGY_STATE_OF_THE_ART_2026-06-06`, `VJ_BRIDGE`,
`COLLAB_SYNC_TRIAGE`, `RESEARCH_FRONTIER_ABLETON20`, `RESEARCH_VJ_MAPPING_VISUAL`), damit
nichts doppelt gesucht wird. Danach habe ich die Aussagen über unser Repo selbst gegen den Code
geprüft.

⚠️ **Prüfstand, ehrlich:** Die Websuche lieferte in allen fünf Feldern nur dünne Ergebnisse.
Hier steht nur als Tatsache, was eine Quelle belegt. Alles andere ist als *vermutet* markiert
und darf in keinen Store-, Website- oder Content-Text, bevor es nachgeprüft ist
(`ContentPipeline/CLAIMS.md`). Ein zweiter, unabhängiger Bericht von ChatGPT ist angekündigt.
Er wird im Lernmodus gegen diesen gelegt.

---

## 1. Kurzfassung

- **Allen Werkzeugen fehlt dasselbe: der Körper.** Keines der rund 40 Produkte nimmt Herz oder
  Atem als Quelle. Raumklang-Systeme steuern Objekte von Hand oder per Tracker, Looper per
  Finger, KI per Text. Genau dort steht Echoel allein.
- **Die Profis leben von offenen Protokollen** (ADM-OSC, OSC, MIDI, Timecode, NDI). Wer sie
  spricht, ist im Rig willkommen. Wer eine eigene Welt baut, stirbt mit seinem Server:
  Endlesss schaltete am 31.05.2024 ab und nahm die Arbeit seiner Nutzer mit.
- **Redesign in einem Satz:** Echoel wird das Instrument, das vom Körper gespielt wird, auf
  dem Handy komponiert und aufnimmt — und das jedes Profi-System, ob Raumklang, Licht, Video
  oder DAW, über offene Standards *bespielt* statt es nachzubauen.

---

## 2. Kritik pro Feld

### 2.1 Raumklang für Event und Theater

| Produkt | Stark | Schwach |
|---|---|---|
| **ADM-OSC** (gemeinsame Sprache) | Spec 1.0 von L-Acoustics/FLUX, mitgetragen von d&b, Meyer, Adamson, DiGiCo, Dolby, Lawo, Steinberg; es gibt einen Python-Validator (pypi `adm-osc`) | Kern ist nur Position und Pegel; Breite, Raum und Szenen bleiben herstellereigen (vermutet) |
| **Grapes 3D Audio Control** | herstellerneutraler Controller für viele Engines; v1.4.0 (Feb 2026) steuert Vivace nativ | reiner Controller, keine Sensor- oder Körperquelle |
| **Adamson FletcherMachine** | V2 spricht ADM-OSC, MIDI, OSC, PSN, RTTrPM; V2.3 (Feb 2025) mit Show-Modus, Trajektorien, binaural mit Head-Tracking | an Adamson-Hardware gebunden, teuer (vermutet) |
| **d&b Soundscape** (DS100, En-Scene/En-Space) | alles per OSC steuerbar, seit 2025 Szenenabruf per OSC (TouchOSC/QLab), DS100 bis 128×64 I/O | Prozessor-Bindung; eigene OSC-Adressen neben ADM-OSC |
| **L-Acoustics L-ISA** | großes OSC-API, Snapshots per MIDI PC/MTC/OSC, Tracking-Partner; 2026.2 mit Stimm-Extraktion | auf L-Acoustics-Lautsprecher zugeschnitten, Tour-Preise (vermutet) |
| **Meyer Spacemap Go** | iPad-App mit 2D-Raumkarten und Pfaden, OSC und RTTrPM — die nächste Form zu Echoel | nur Meyer/Galaxy, im Kern 2D |
| **Dolby Atmos** | Logic hat einen eingebauten Renderer und exportiert ADM BWF; Resolve ebenfalls | Authoring ist eine eigene Disziplin; Quellen teils alt |
| **SPAT Revolution · Holoplot · 4DSOUND** | — | in dieser Runde **nicht belegt** |

**Kritik:** Diese Welt ist professionell und offen, aber ihre Bedienung ist Handarbeit.
Positionen werden mit Fader, Maus oder Tracker gesetzt. Grapes und Spacemap Go sind die
Bedienschicht darüber, und beide sind Fernbedienungen — keine Instrumente. Was fehlt, ist eine
*lebendige Quelle*, die Bewegung erzeugt, ohne dass jemand schiebt. Genau das sendet Echoel
schon (`Sync/ADMOSCSender`: `/adm/obj/{n}/*`).

### 2.2 Musik machen auf Handy und Rechner

| Produkt | Stark | Schwach |
|---|---|---|
| **Loopy Pro 2.0** | freie Arbeitsfläche aus eigenen Bedienelementen; MIDI-Clips, polyphone Clips; hostet AUv3 und ist selbst eins | leere Fläche am Anfang = hoher Einrichtaufwand; Noten-Editor flach |
| **Drambo** | tiefe modulare Klangwerkstatt; 2.54 (Juli 2026) verkauft eine Visual-Engine als In-App-Kauf | sehr dicht, auf dem Handy eng |
| **AUM** | der Standard-Host für AUv3 auf iOS — dort lädt auch Echoels eigenes AUv3 | komponiert nicht, Einrichtung von Hand |
| **Imaginando** (LK, DRC, VS, KRSH) | jedes Tool eine klare Touch-Geste, Bild passt zum Klang (vermutet) | flach, viele Einzelkäufe |
| **Koala Sampler** | Maßstab für Einhand-Bedienung am Handy (vermutet) | kein Hosting, kaum MIDI-Bearbeitung (vermutet) |
| **Logic Pro für iPad 2** | Session Players (Drums, Bass, Keys) folgen den Akkorden; Stem Splitter lokal | nur iPad, zu dicht für ein Telefon |
| **Ableton Live 12 · Note · Move** | MIDI-Generatoren und -Transformationen im Clip-Editor; Session-Raster ist der Standard; 12.3 mit Touch-Step-Editing auf Push 3 | Desktop-Dichte, kein Körper |

**Kritik:** Die besten Handy-Apps sind entweder *schnell aber flach* (Koala, GarageBand) oder
*tief aber dicht* (Drambo, Logic). Niemand löst „tief, aber auf dem Daumen". Ableton und Logic
zeigen die stärkste Idee: **eingeschränkte Generatoren** (Dichte, Tonleiter, Umfang), deren
Ergebnis man bearbeiten kann. Das ist Echoels Komponist — nur dass bei uns der Körper die Regler
bewegt.

### 2.3 KI-Musik

| Produkt | Stark | Schwach |
|---|---|---|
| **Suno** | fertige Songs in Sekunden; Studio (Premier, ca. 30 $/Monat) exportiert Stems und MIDI | Gestaltung = Prompt plus Lotterie; Rechte hängen am Abo; Sony-Klage offen |
| **Udio** | lizenziert seit dem Vergleich mit Universal (Okt 2025) | Downloads seit Ende Okt 2025 aus — man bekommt sein Werk nicht heraus |
| **ACE Studio** | Mensch schreibt Noten und Text, KI singt (vermutet) | Stimmlizenzen; Echoel hat keinen Gesangspfad (Audio-Eingang gelöscht, #1302) |
| **Logic Session Players / Stem Splitter** | lokal, ohne Cloud, Ergebnis ist bearbeitbares MIDI | nur Mac/iPad, kein Körper |
| **Moises · LANDR** | Stems bzw. Mastering als Dienst (vermutet) | Hochladen, Abo |

**Rechtslage (belegt):** Warner hat sich im Nov 2025 mit Suno geeinigt (lizenzierte Modelle,
Download-Grenzen), Universal im Okt 2025 mit Udio. Sony hat sich mit keinem der beiden geeinigt.
Das ist ein Flickenteppich aus Einzellizenzen, kein Standard.

**Kritik:** Text-zu-Song nimmt dem Menschen die Urheberschaft und gibt sie einem Abo. Das
Gegenteil von Echoels Prämisse „dein Körper spielt es".

### 2.4 Video und Visuals

| Produkt | Stark | Schwach |
|---|---|---|
| **DaVinci Resolve** (iPad) | beste Farbe, Gratis-Stufe, Cloud-Ingest vom Handy | iPad-Fassung mit Lücken (Fairlight 2026 unbelegt); kein Live-Werkzeug |
| **OBS Studio** | gratis, überall; NDI über das Plugin DistroAV 6.2.0 | nur Desktop; kein OSC, nur WebSocket |
| **Resolume Arena** | schnellster Weg zu einem Live-Set, Mapping, OSC/MIDI/DMX (vermutet) | kein iOS; OSC-Learn je Adresse von Hand |
| **TouchDesigner** | Standard für Installationen, grenzenlos flexibel | steile Lernkurve, kein iOS |
| **VDMX · Notch** | — | nur Mac bzw. Windows/NVIDIA, kein iOS-Pfad |
| **LumaFusion** | echter Mehrspur-Schnitt auf dem iPhone; FCPXML-Export als Pack | kein Live-Eingang; Bezahlschichten |
| **Blackmagic Camera** (iPhone) | gratis; Timecode in jeder Datei, Bluetooth-Timecode von Tentacle; v3.3 (NAB 2026) mit Watch und Mehr-iPhone-Steuerung | nimmt nur auf, weiß nichts von Musik |
| **NDI auf iOS** | NDI HX Camera (iOS 17+) und Drittanbieter-Apps senden NDI | ob das SDK für uns lizenzierbar ist: **unbelegt** |

Syphon gibt es nur auf macOS, Spout nur auf Windows (vermutet, allgemein bekannt) — ein iPhone
kann keins von beiden senden.

**Kritik:** Kein Werkzeug verbindet Bild und Musik *im Takt*. Die Kamera-App kennt Timecode,
aber keinen Takt; das Schnittprogramm kennt den Takt erst, wenn man ihn hineinlegt. Wer auf dem
Handy filmt und zur Musik schneidet, macht es heute von Hand.

### 2.5 Live zusammen spielen

| Produkt | Modell | Stark | Schwach |
|---|---|---|---|
| **Ableton Link** | Tempo und Phase im LAN, Peer-to-Peer | Industriestandard, frei, iOS LinkKit seit 2015 | trägt keine Tonart, kein Bio; macht Echoel zum Mitläufer |
| **SonoBus** | Echtzeit-Audio P2P, iOS | einziges freies iOS-P2P-Audio | v1.7.2 von Dez 2023, unverschlüsselt |
| **Jamulus** | Echtzeit-Audio, Server | offen, große Community | kein iOS |
| **JamKazam** | Echtzeit-Audio + Video | — | nur Desktop, wirkt stillgelegt |
| **NINJAM** | Intervall-Jam: alles ein Intervall versetzt | latenzfest per Design | man spielt nie „im Moment" zusammen |
| **Audiomovers** | Einweg-Stream zum Abhören | Atmos/binaural auf iOS hörbar | nur Zuhören, Abo |
| **Soundtrap · BandLab** | Cloud-DAW, asynchron | einfach, viele Nutzer | Cloud-Bindung, BandLab ohne DAW-Export |
| **Endlesss** | Loop-Jam über die Cloud | beste iOS-UX ihrer Klasse | **abgeschaltet 31.05.2024**, Nutzerwerke weg |

**Kritik:** Echtzeit-Audio übers Internet scheitert an der Physik und braucht Server. Cloud-
Projekte binden an einen Anbieter, der sterben kann. Die robuste Form ist **Synchronisation von
Musik-ZUSTAND** (Tempo, Tonart, Muster) statt Audio — Link und NINJAM zeigen beide Hälften.

---

## 3. Redesign für Echoelmusic

### 3.1 Die Rolle

**Echoel ist die lebendige Quelle und der Dirigent im Profi-Rig — nicht sein Ersatz.**
Raumklang, Licht, Video-Server und DAW gibt es in Weltklasse. Was es nicht gibt: ein Instrument,
das sie vom Körper aus bespielt, auf dem Handy, ohne Tracker-Anzug. Daraus folgen fünf Bausteine.
Jeder ist in kleine Scheiben zerlegt, die zur festgelegten Bau-Reihenfolge passen
(H6 Effekte und Spur-Mixer → Automation schreiben → MIDI/MPE und Touch-Gefühl → Performance-
Clip-Launcher → Videoaufnahme → Videoschnitt).

### 3.2 Baustein A — Performance auf dem Daumen

Vorbild: Koala (Einhand), Ableton Session (Szenen), Live-12-Generatoren (eingeschränkt, bearbeitbar).

1. **Szenen-Reihe statt Raster:** eine Reihe aus 4–8 großen Pads, auf den Takt quantisiert; der
   nächste Abschnitt pulsiert am Rand, bis er greift. Auf dem Telefon ist eine Reihe bedienbar,
   ein 8×8-Raster nicht. Das ist der geplante Clip-Launcher in Telefon-Form. Er muss ein eigenes
   Blatt sein (Hot-State-Gesetz).
2. **Drei Generator-Regler am Komponisten:** Dichte, Umfang, Tonleiter-Strenge. Der Körper
   bewegt sie, der Mensch begrenzt sie. Keine neue Fläche, nur drei `EchoelValueField`-Zeilen.
3. **Eine Harmonie-Wahrheit**, der alle Spuren folgen (die Session-Player-Idee aus Logic).
   `SessionContext` ist dieser Besitzer schon; die Scheibe verbindet die Spuren damit.
4. **Ein großes XY-Pad**, frei auf jeden automatisierbaren Parameter legbar, über die vorhandene
   Parameter-Registry. Das ist Loopys stärkste Idee, für uns billig.

### 3.3 Baustein B — Raum: die lebendige Objekt-Quelle

Vorbild: Grapes (herstellerneutral), Spacemap Go (iPad-Touch), d&b/L-ISA (Szenenabruf per OSC).

1. **ADM-OSC-Konformitätsprüfung:** ein Pipeline-Skript prüft unsere gesendeten Nachrichten
   gegen die ADM-OSC-Spec. Bereichs-Abweichungen sind das größte Risiko zwischen Herstellern.
   ⚠️ Der Python-Validator ist ein fremdes Paket: erst Founder-Freigabe, dann nur gepinnt und
   gehasht (wie `scripts/requirements-pipeline.txt`).
2. **Szenenabruf nach außen:** beginnt ein Abschnitt des Stücks, sendet Echoel eine Szenennummer
   per OSC. Eine winzige Nachricht, die direkt in Theater-Cue-Abläufe passt.
3. **Hand übernimmt Körper:** ein 2D-Pad, auf dem der Performer die Bio-Position eines Objekts
   live überschreibt und wieder freigibt.
4. **Ziel-Profile (Grapes, d&b En-Scene)** neben ADM-OSC — erst, wenn die Adressen aus den
   Handbüchern belegt sind. Felix (Grapes) und Roman (Adamson) sind die natürlichen Prüfer.
5. **PSN/RTTrPM** (Tracking-Formate, die FletcherMachine und Spacemap Go annehmen): BEOBACHTEN,
   bis Roman den Bedarf bestätigt.

### 3.4 Baustein C — Video im Takt

Vorbild: Blackmagic Camera (Timecode), LumaFusion (FCPXML), Resolve (Finishing).

1. **Aufnahme mit Takt-Stempel:** jede Aufnahme trägt die Transport-Position und einen
   Timecode-Track, dazu eine kleine Begleitdatei (BPM, Takt, Bio-Verlauf). Das kann niemand
   sonst, und es ist der Kern des Video-Wunschs.
   ⛔ **Erste Entscheidung vor jedem Code:** die rückseitige Kamera gehört heute dem
   rPPG-Puls (`Video/CameraCapture`). Puls und Videoaufnahme brauchen eine ausdrückliche
   Regel, wer die Kamera hält. Die Aufnahme ist mit #1304 zurückgenommen worden und kommt nur
   als NEUE Umsetzung zurück (`HISTORY_ARCHIVE.md`, #299, #1302).
2. **Schnitt als Timeline-Teile:** Video-Clips liegen als Parts auf der vorhandenen Spur, wie die
   Audio-Parts, und werden auf dem Taktraster geschnitten. Kein eigener Editor.
3. **Übergabe an Profis:** Export als FCPXML plus Originalmedien — so nehmen LumaFusion und
   Resolve es auf. Kein Codec, keine Farbe, kein NLE von uns.
4. **Live-Bild nach außen:** externer Bildschirm/AirPlay des vorhandenen Visual-Fensters (#206),
   von OBS über eine Capture-Karte abgegriffen. NDI: BEOBACHTEN (SDK-Lizenz = Abhängigkeit,
   Founder).
5. **OSC für Video-Server:** Transport- und Clip-Adressen, damit Resolume/TouchDesigner an
   Schnittpunkten mitschalten. `/echoelmusic/music/beat/phase` gibt es schon (#1383); Transport-
   und Clip-Adressen gibt es noch nicht (`git grep` in `Sources/`: null Treffer).

### 3.5 Baustein D — Zusammen spielen, ohne Server

Vorbild: Link (Zustand im LAN), NINJAM (Intervall), Endlesss (UX — und Warnung).

1. **Ableton Link** als wählbare Tempoquelle, nur im Loop-Modus (`.studioLocked`), nie aus dem
   Körper gespeist (T1/T2). ⚠️ LinkKit ist C++ — nach `CLAUDE.md` nur mit Council- und
   Founder-Freigabe.
2. **Intervall-Jam über Multipeer:** Geräte tauschen nur Musik-Zustand (Tonart, Tonleiter, ein
   Takt Noten) und spielen ihn ein Intervall später. Kein Audio, keine Latenz-Kompensation, kein
   Server. Dass jemand das mit körpergesteuertem Zustand macht, ist nicht belegt — vermutlich neu.
3. **Bio-Ensemble (Opt-in, aus per Default):** jedes Gerät teilt nur abgeleitete Werte
   (Kohärenz, Atemphase, Herzschlag-Ereignis) — genau die `.derived`-Klasse aus
   `BioEgressPolicy`. Rohdaten und klinische HRV bleiben gesperrt.
4. **Alles Werk bleibt auf dem Gerät.** Die Endlesss-Lehre: keine Kollaboration darf ein Werk an
   einen Server binden.

### 3.6 Baustein E — KI als Mitspieler, Körper als Dirigent

1. Das Komponieren bleibt **lokal und deterministisch** aus Herz und Atem.
2. Ein Assistent auf dem Gerät (Apple FoundationModels) **schlägt** nur Parameter- oder
   Stimmungswechsel über die typisierte Registry vor, der Mensch nimmt an. Das ist die bestehende
   Regel „das Modell schreibt nie direkt in den DSP-Zustand".
3. Kein Cloud-Generator, kein Text-zu-Song. Store-Text sagt **nicht „KI-Musik"**
   (`FeatureFlags.echoelAI` hat keinen Leser).

---

## 4. Ablehnen — und warum

| Was | Grund |
|---|---|
| eigener Raumklang-Renderer (VBAP/Ambisonics für Venues), Atmos-Authoring | Spezial-Infrastruktur (Produktgesetz); die Kerne liegen unverdrahtet in `Sources/` und bleiben es |
| modulare Patch-Fläche wie Drambo/AUM, Desktop-Raster auf dem Telefon | zu dicht; die Modifier-Kette und das Freeze-Gesetz verbieten Wachstum an der Wurzel |
| Cloud-KI (Suno, Udio, ACE, Moises, LANDR), Text-zu-Song | Bio-Daten und Werk verlassen das Gerät; Rechte und Lizenzen instabil; widerspricht „dein Körper spielt es" |
| Echtzeit-Audio-Jam über Server, Cloud-Projekte | braucht Server und Audio-Eingang (#1302 gelöscht); Endlesss-Risiko |
| eigener Schnitt-Editor, Farbkorrektur, CapCut-Vorlagen | Resolves und LumaFusions Aufgabe |
| Syphon/Spout | existieren auf iOS nicht |
| „kompatibel mit Atmos / L-ISA / d&b" im Store | erst nach einem Lauf gegen echte Hardware |

---

## 5. Reihenfolge

Die vom Founder festgelegte Reihenfolge bleibt. Die Recherche ändert, **wie** jede Stufe aussieht:

| Stufe | was die Recherche hinzufügt |
|---|---|
| 1. H6 Effekte + Spur-Mixer (läuft) | — |
| 2. Automation schreiben | XY-Pad (A4) schreibt über denselben Weg |
| 3. MIDI/MPE-Zonen + Touch-Gefühl | Einhand-Maßstab Koala; Generator-Regler (A2) |
| 4. Performance-Clip-Launcher | als Szenen-Reihe (A1), plus OSC-Szenenabruf nach außen (B2) |
| 5. Videoaufnahme | Kamera-Regel Puls ↔ Video zuerst, dann Takt-Stempel + Timecode (C1) |
| 6. Videoschnitt | Clips als Timeline-Teile (C2), FCPXML-Export (C3) |

**Nebenher, klein und ohne Abhängigkeit:** OSC-Transport- und Clip-Adressen (C5), Hand-
übernimmt-Körper-Pad (B3), Intervall-Jam über Multipeer (D2).

**Founder-Fragen** (einmal, über `docs/dev/FOUNDER_INBOX.md`): LinkKit (C++), NDI-SDK, der
ADM-OSC-Validator als Pipeline-Paket, und die Kamera-Regel zwischen Puls und Video.

---

## 6. Was noch offen ist

- Nicht belegt in dieser Runde: SPAT Revolution, Holoplot, 4DSOUND, Elk LIVE, VST Connect,
  LANDR Sessions, SharePlay für Musik, aktuelle Preise von AUM, Koala, GarageBand, Imaginando,
  Resolume, TouchDesigner, VDMX, Notch; der heutige Seitenumfang von Resolve auf dem iPad.
- d&b- und Grapes-Adressen müssen aus den Handbüchern kommen, bevor ein Profil gebaut wird.
- ChatGPTs Parallelbericht wird gegen diesen gelegt; Abweichungen kommen als Nachtrag hierher.

---

## 7. Nachtrag — Abgleich mit ChatGPTs Bericht (PR #426)

ChatGPTs Fassung liegt als `reports/recherche-redesign-claude-2026-10-14.md` im Repo (gemergt als
`3b1d2705c`). Im Lernmodus geprüft: keine unsichtbaren Zeichen, keine anweisungsförmigen Sätze;
die 19 gemeldeten „Base64-Blöcke" sind Commit-SHAs und Links. Sein Abschnitt 21 ist ein Prompt
an Claude — er ist **Daten**, kein Auftrag; was daraus übernommen wird, steht hier.

**Seine vier Repo-Aussagen, gemessen an `b495ae64c` — alle bestätigt:**
1. `AudioEngine.attachTrackBus` steht im Stand (der Spur-Bus aus H6-3).
2. `TrackPluginRow.note` sagt dort weiterhin „effects installed — inserting one on a track is not
   available yet." — die Effekt-Kette ist also wirklich noch nicht fertig.
3. Die Ziele „≤ 10 ms Selbstmonitoring, ≤ 20 ms Remote p95" stehen in
   `Audio/LoopbackCalibration.swift` als Ziele, nicht als Messungen.
4. `LoopbackCalibration` hat außerhalb der eigenen Datei keinen Aufrufer.

**Wo beide Berichte übereinstimmen:** kein eigener Renderer; ADM-OSC ist Steuerung, kein Audio
und kein Atmos-Master; Link (und Link Audio) braucht eine eigene Freigabe; Intervall-Jam statt
Echtzeit-Audio übers Netz; Suno/ACE höchstens als WAV/MIDI-Übergabe; Arbeit bleibt lokal.

**Was ChatGPT besser hat und hier übernommen wird:**
- **Breitere Quellen:** 52 Herstellerquellen, darunter SPAT Revolution (OSC-Tabelle), TiMax,
  Holophonix, 4DSOUND — genau die Lücken aus §6 dieses Berichts.
- **„Kein falsches Grün":** „Steuerdaten gesendet", „Renderer antwortet" und „Audio am Ziel
  geprüft" sind drei getrennte Zustände; ein UDP-Send ohne Rückkanal belegt nur den ersten.
- **Stabile externe IDs:** Objektnummer und Audiokanal nie aus der Listenreihenfolge ableiten;
  ein Ausgabeprofil pro Raum (Achsen, Maßstab, Ursprung, Kanalzuordnung, Version).
- **Getrennte Kollaborations-Modi** mit eigenen Messwerten; RTT nie als Hörlatenz ausgeben.
- **Ein vollständiger Ablauf zuerst:** Klang → Phrase → Clip → speichern → neu laden → derselbe
  Klang. Das schärft Stufe 1 der Reihenfolge, statt sie zu ersetzen.

**Wo ich anders entscheide:** ChatGPT schlägt als nächsten Schritt einen Drum- oder FM-Kern vor.
Die vom Founder festgelegte Reihenfolge stellt H6 (Effekte + Spur-Mixer) davor, und H6 ist halb
gebaut (Modell, Writer, Bus). Es bleibt bei H6; der Port-Kern folgt danach. ChatGPT schreibt selbst,
dass sein Bericht „keine bereits vereinbarte Reihenfolge ersetzt".
