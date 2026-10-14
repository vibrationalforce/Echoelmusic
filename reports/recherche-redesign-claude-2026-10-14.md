# Echoelmusic: Recherche, Redesign und Übergabe an Claude

**Stand: 14. Oktober 2026.** Dieser Bericht führt die Wettbewerbsrecherche, den Redesign-Entwurf und die Ergebnisse des Archiv-Reviews zusammen. Am Ende steht ein direkt kopierbarer Arbeitsauftrag für Claude. Diese Änderung besteht ausschließlich aus dieser Markdown-Datei.

**Empfehlung:** Echoelmusic soll den vollständigen kreativen Ablauf verbinden: Klang → Phrase → Clip → Arrangement oder Live-Performance → Raum/Bild/Licht → gemeinsame Session. Ein gemeinsamer Projektzustand trägt die Arbeit; spezialisierte Renderer, Plugins und Übertragungsdienste werden über nachgewiesene Schnittstellen integriert.

**Lesepfad:** [Aktueller Codeabgleich](#0-übergabestand-und-abgleich-mit-dem-repo) · [Archiv-Kandidaten](#die-acht-archiv-kandidaten-im-überblick) · [Markt und Kritik](#3-raum-steuerung-und-wiedergabe) · [Bedienentwurf](#13-eine-oberfläche-klare-zuständigkeiten) · [Umsetzung](#19-umsetzung-in-vollständigen-schritten) · [Claude-Prompt](#21-kopierbarer-prompt-für-claude) · [Quellen](#22-quellen-und-nachweise)

## 0. Übergabestand und Abgleich mit dem Repo

| Bezug | Festgehaltener Stand | Gültigkeit |
| --- | --- | --- |
| Wettbewerbsrecherche | Offizielle Quellen, Abruf 2026-10-14 | Dokumentierte Fähigkeiten; keine eigenen Hör-, Geräte- oder Netzwerktests |
| Ursprünglicher Repo-Abgleich und Archiv-Review, **B** | `48ba58a7b33879b0efdc9fea6c96979b44a29197` | Grundlage der vorhandenen Port-Befunde und der Quellen R0–R8 |
| Nachtrag für diese Übergabe, **H** | `b495ae64c7aec213c0552ecc5a4e754a9ce18681` | Gezielter statischer Abgleich von Plugin-Fenster, Zustandsspeicherung und Effekt-Grundlagen |
| Umsetzung dieses Auftrags | Neue Datei unter `reports/` auf eigenem Branch | Keine Produktcode-Änderung, kein Build, keine Paketinstallation |

Der frühere PDF-Bericht ist eine Recherchefassung. Diese Repo-Fassung ergänzt den neueren Codebefund und den Claude-Auftrag. Sie korrigiert außerdem zwei zu pauschale Stellen: Der ältere Dokumentationsstand ist kein Beweis für fehlendes Plugin-Hosting; FFT ist nicht grundsätzlich außerhalb eines Audio-Callbacks erforderlich. Entscheidend sind vorbereiteter Zustand, begrenzte Laufzeit und nachgewiesene Echtzeiteignung.

### Was inzwischen im Code vorhanden ist

| Bereich | An H im Quelltext belegt | Weiterhin unklar / Folge für Claude |
| --- | --- | --- |
| Fremde Instrumente und Plugin-Fenster | `TrackPluginRow` bietet Instrumentauswahl und „Open plugin“. `HostedInstrumentHost.requestView` fordert die native AUv3-View an; `PluginWindowSheet` stellt sie dar. Der Host-Code existierte bereits vor diesem Nachtrag. [R10](#r10) | Katalog, hörbares Instrument und native Oberfläche tragen noch Geräte-Prüfbitten. Nicht erneut bauen; zuerst vorhandenen Pfad und aktuelle Arbeit lesen. |
| Plugin-Zustand | `captureState` serialisiert `fullStateForDocument`; das Schließen des Fensters übergibt den Zustand über `TimelineStore.setLanePluginState`. Der Host kann gespeicherten Zustand beim Laden wieder setzen. `DeviceChain` speichert begrenzte Zustandsdaten. [R10](#r10), [R11](#r11) | Ein gefundener Save/Restore-Pfad beweist keinen erfolgreichen Roundtrip mit beliebigen Fremd-Plugins. Geräteverhalten, Automation und Fehlerszenarien bleiben ungeprüft. |
| Effekt-Plugin-Grundlage | `PluginEffectInsert` modelliert einen gesonderten Effekt-Eintrag; `TimelineStore.setLanePluginEffect` schreibt ihn. `AudioEngine.attachTrackBus` stellt einen Bus vor dem Master bereit. [R11](#r11), [R12](#r12) | Diese Bausteine belegen noch keine vollständige Effekt-Plugin-Kette. `TrackPluginRow` erklärt das Einsetzen eines Effekts an H weiterhin als nicht verfügbar. |
| Laufende Planung | `scratchpads/PLAN_H6_EFFECT_PLUGINS_2026-10-14.md` beschreibt die H6-Schritte. Modell, Writer und Bus-Grundlage sind inzwischen im Code vorhanden. [R13](#r13) | Statusnotizen im Plan können älter sein als der Code. Keine parallele H6-Neuimplementierung aus diesem Bericht ableiten. |
| Historische DSP-Prüfung | [Port-Kandidaten-Bericht](port-kandidaten-2026-10-14.md), eingebracht über [PR #425](https://github.com/vibrationalforce/Echoelmusic/pull/425), liegt an H bereits im Repo. [R14](#r14) | Seine Compile- und Integrationsaussagen sind an B bzw. historische SHAs gebunden. Neue Aufrufer nach B vor der Auswahl nachprüfen. |

**Prüftiefe:** Für diesen Nachtrag wurden die genannten Quellen und die relevanten Änderungen von B nach H gelesen. Es wurde kein vollständiges Re-Audit aller Funktionen durchgeführt. Ein grüner CI-Status, kompilierbarer Code, ein aufrufbarer Renderpfad und ein tatsächlich gehörter Geräteausgang sind getrennte Nachweise. Fehlender Nachweis heißt **unklar**.

### Die acht Archiv-Kandidaten im Überblick

Die Reihenfolge stammt aus dem [gesonderten Audit](port-kandidaten-2026-10-14.md). Sie bewertet zusätzlichen Nutzen für Musikproduktion am Stand B, keine gemessene Klangqualität. Alle acht enthalten tatsächliche Sample-Berechnung; ein verifizierter hörbarer Lauf wurde bei keinem Kandidaten nachgewiesen. Die vollständigen historischen Pfade, SHAs, Rückholbefehle und CI-Belege stehen im verlinkten Audit.

| Rang | Kandidat | Compile-Beleg im Audit | Geschätzter enger Port | Aufnahmeort am Stand B / Hauptrisiko |
| --- | --- | --- | --- | --- |
| 1 | 808-Kick und metallische Hi-Hat | unklar | 200–320 Zeilen | `LaneVoiceRack`; alte Locks und dynamische Voice-Verwaltung entfernen |
| 2 | EchoelSynth: FM, Karplus–Strong, Supersaw | unklar | 350–550 Zeilen für die drei Kerne, getrennte Schritte | `PolySynthVoice` / `SynthPatch`; Array-Kopien, Allokation, RNG und Lock im alten Umfeld |
| 3 | Resonanter Basskern | unklar | 120–220 Zeilen | `SubBassVoice`; Filterstabilität prüfen; kein belegter 303-Slide oder echter Growl-Formantfilter |
| 4 | ModalBank als Mallet-/Percussion-Stimme | ja, zugeordnete historische/aktuelle Checks | 120–220 Zeilen Adapter; Kern bleibt | `LaneVoiceRack`; vorhandenen Kern wieder anbinden, Zustandsübergabe prüfen |
| 5 | FDN-Reverb | ja, zugeordneter Check an B | 100–180 Zeilen Adapter; Kern bleibt | `EchoelFXChain`; Mono-Kern, Bus-/Send-Besitz und sichere Raumänderung festlegen |
| 6 | Zweistimmiger Delay-Harmonizer | ja, historischer Check | 130–200 Zeilen | `EchoelFXChain`; kreativer Delay-Effekt, keine validierte Stimmkorrektur |
| 7 | Cellular-Textur in der App | ja, App-Target an B | 120–220 Zeilen Adapter; Kern bleibt | `LaneVoiceRack`; aktuelle reparierte Fassung verwenden, CPU messen |
| 8 | Ringmodulation | nein im ausgeschalteten C++-Standard-Build; Sonderbuild unklar | 40–80 Zeilen Swift-Kern/Adapter | `EchoelFXChain`; nur den isolierten Kern übernehmen, kein JUCE, kein Bode-Shifter-Versprechen |

Die Größen schließen UI, Presets, Tests und umfangreiche Persistenzmigration aus. **Echte Klangausgabe: bei allen acht unklar.** „Compile: ja“ ist keine Aussage über den neuen Übergabestand H. Im Audio-Thread dürfen auch bei diesen Kandidaten keine Allokation, kein Lock und kein GCD verbleiben. Vorhandener Sampler und Grain-Bake sind keine neuen Rückholkandidaten.

**Nächste Empfehlung:** Nach dem Abgleich mit der laufenden Plugin-Arbeit genau einen Drum- oder FM-Kern auswählen. ModalBank ist die Alternative, wenn zunächst ein erhaltener Kern mit zugeordnetem Compile-Beleg wieder angebunden werden soll. Die folgende Roadmap ist ein Vorschlag für Abhängigkeiten und Nutzen; sie ersetzt keine bereits vereinbarte Reihenfolge.

## 1. Ein Werk. Viele Ausgänge.

**Echoelmusic als durchgängige Umgebung für Komposition, Performance, Raum, Bild und Zusammenarbeit.**

Die stärkste Richtung ist eine gemeinsame musikalische Struktur: Ein Clip lässt sich arrangieren, live spielen, räumlich bewegen und mit Bild oder Licht verbinden. Fachsysteme übernehmen die Aufgaben, für die sie gebaut sind. Echoelmusic hält das Werk, seine Bearbeitung und seine Aufführung zusammen.

### Drei Entscheidungen mit dem größten Nutzen

| Entscheidung | Konsequenz für das Redesign |
| --- | --- |
| **1. Spielbare Tiefe** | Loopy Pro liefert die unmittelbare Performance-Idee, Drambo die nachvollziehbare Modulation und Ableton den Übergang von Improvisation zu Arrangement. Echoelmusic braucht dafür gemeinsame Clips und eindeutige Zustände. |
| **2. Raum als Musik** | Von Grapes und 4DSOUND: Bewegungen als bearbeitbares musikalisches Material. Von Bühnenprozessoren: Raumkalibrierung, kontrollierte Übergänge und getrennte Wiedergabeprofile. |
| **3. Ehrliche Kollaboration** | Nahes Zusammenspiel, verzögerter Loop-Austausch, Remote-Aufnahme und Projektbearbeitung erhalten jeweils einen eigenen Betriebsmodus und passende Messwerte. |

**Kernempfehlung:** Zuerst einen vollständigen Ablauf stabil machen: Klang wählen → Phrase spielen → Clip bearbeiten → Bewegung aufnehmen → über einen geprüften Ausgang wiedergeben → Session weitergeben. Diese Richtung erweitert die bestehende Workstation und respektiert das parallel entstehende Plugin-Fenster.

### Was dieser Bericht liefert

Vergleich der genannten Produkte und relevanter Ergänzungen; konkrete Kritik mit Grenzen der Beleglage; Kollaborationsmarkt nach Arbeitsweise; zwei iPhone-Layout-Entwürfe und eine größere Arbeitsfläche; Schnittstellen, technische Zuständigkeiten, priorisierte Umsetzung und Abnahmekriterien.

## 2. Umfang und belastbare Ausgangslage

„OSB“ wird als **OBS Studio**, „drumbo“ als **Drambo** und „dB Audio“ als **d&b audiotechnik** behandelt. Grapes ist das Produkt **Grapes 3D Audio Control**. Imaginando wird anhand von VS, FRMS, DRC und BAM betrachtet.

**Belegklassen:** [Sxx] bezeichnet offizielle Produktseiten, Handbücher oder Hersteller-Repositories; [Rxx] bezeichnet den festgehaltenen Echoelmusic-Stand. Produktfähigkeiten sind dokumentiert, aber hier nicht am Gerät getestet. Kritik und Empfehlungen sind eigene Ableitungen. „Unklar“ bezeichnet nicht geprüfte oder nicht belegbare Punkte.

Die Recherche deckt die genannten Anbieter und wichtige Vertreter aller relevanten Kollaborationsarten ab. Sie ist keine beweisbar vollständige Liste sämtlicher Nischenprodukte. Preise, Abonnements und Plattformfreigaben wurden nicht flächendeckend verglichen. Keine Hörtests, keine Netzwerktests und keine Herstellerkontakte.

### Echoelmusic: bestehende Fähigkeiten nicht neu erfinden

| Gelesener Stand | Folge für den Entwurf |
| --- | --- |
| Workstation-Shell: Arrange, Mixer, Instrument, Browse, Piece; ein Transport. [R1](#r1), [R2](#r2) | Diese Navigation bildet den Ausgangspunkt. Live-Ansichten und Raumkontrolle ergänzen die bestehenden Arbeitsbereiche. |
| Spuren, Teile, Sampler, Grain-Insert; für viele Funktionen steht Geräteprüfung noch aus. [R1](#r1) | Zuerst durchgängige Bedienung und verifizierbare Ausgänge; keine neue Parallel-Engine als Abkürzung. |
| ADM-OSC sowie räumlicher Szenenzustand vorhanden; Kopfhörerpfad eingeschränkt und Geräteprüfung offen. [R1](#r1), [R3](#r3) | Steuerdaten, tatsächlichen Klangpfad und bestätigte Renderer-Verbindung getrennt anzeigen. |
| Live Colabo teilt Inhalte mit nahen Geräten und misst Netzwerk-RTT. [R4](#r4) | Das ist eine Basis für Austausch, kein Nachweis für synchrones Netz-Audio oder gemessene Hörlatenz. |
| AUv3-Instrument und Host-Code vorhanden; Plugin-Fenster und Zustandspfad an H gezielt nachgelesen. [R10](#r10), [R11](#r11) | Die laufende Hosting-Arbeit weiterverwenden. Frühere Statusdokumente beweisen keine fehlende Implementierung; siehe Abschnitt 0. |

**Revisionsgrenze:** Die ursprüngliche Codebasis ist B (48ba58a7b33879b0efdc9fea6c96979b44a29197); die in Abschnitt 0 genannten Hosting-Befunde sind an H (b495ae64c7aec213c0552ecc5a4e754a9ce18681) ergänzt. Die übrigen Repo-Verweise bleiben an B gebunden. Das Produktgesetz vom 24.09.2026 definiert die volle Workstation; ältere Einschränkungen der Produktidee gelten nicht als heutige Verbote. [R0](#r0)

## 3. Raum: Steuerung und Wiedergabe

| System / belegter Schwerpunkt | Kritik und Übertragung auf Echoelmusic |
| --- | --- |
| **Grapes 3D**<br>OSC-Middleware mit Bewegungsclips, Trajektorien, Gruppen und Szenen; Standalone und VST3. Kein eigener Audio-Renderer. Atmos-Anbindung erfolgt über passende DAW-Panner. [S01](#s01) | **Stark:** Raumbewegung wird aufführbar und zwischen Systemen übertragbar.<br>**Grenze:** Gleiche Koordinaten garantieren keine gleiche Wahrnehmung in verschiedenen Sälen. Ein laufender OSC-Sender beweist keinen hörbaren Ausgang.<br>**Übernehmen:** Bewegungsclips plus getrennte, kalibrierbare Ausgabeprofile. |
| **Adamson FletcherMachine**<br>Objektbasierte Wiedergabe mit Amplituden- und Laufzeitverfahren, Trajektorien, Snapshots, Binaural-Option und ADM-OSC. Virtual und Hardware-Ausführungen. [S02](#s02) | **Stark:** Reales Lautsprecherlayout und Signalverarbeitung gehören zusammen.<br>**Grenze:** Prozessorlatenz ist nur ein Teil der gesamten Kette; Hardware- und Virtual-Werte sind nicht austauschbar.<br>**Übernehmen:** Raumprofile und nachvollziehbare Objekt-/Ausgangszuordnung; als externen Renderer anbinden. |
| **d&b Soundscape**<br>En-Scene positioniert Objekte; En-Space gestaltet die Raumakustik. Steuerung über R1 beziehungsweise dokumentierte OSC-Befehle. [S03](#s03), [S04](#s04), [S51](#s51) | **Stark:** Trennung zwischen Ortung und Raumantwort.<br>**Grenze:** Installation, Lautsprecheraufstellung und jeweilige Prozessor-/Lizenzkonfiguration bleiben entscheidend.<br>**Übernehmen:** Position und Raumanteil als getrennte Parameter; d&b-Profil gegen reales System prüfen. |
| **Dolby Atmos**<br>Produktions-, Rendering- und Auslieferungsökosystem; ADM BWF und DAMF sind relevante Masterformate. [S05](#s05) | **Stark:** Definierter Weg zu immersiven Medienproduktionen.<br>**Grenze:** ADM-OSC ist kein Atmos-Audiostream und kein fertiger Atmos-Master. Kopfhörer-Spatial allein reicht ebenfalls nicht.<br>**Übernehmen:** Separater Übergabeweg an eine geprüfte Atmos-Toolchain; im UI genau benennen, was exportiert wird. |

**Designregel:** Eine räumliche Bearbeitung besitzt mindestens drei sichtbare Tatsachen: welches Objekt bewegt wird, welcher Audiokanal dazugehört und welches Wiedergabesystem die Position tatsächlich umsetzt.

## 4. Raum als kompositorisches Material

| System / belegter Schwerpunkt | Kritik und Übertragung auf Echoelmusic |
| --- | --- |
| **4DSOUND**<br>Räumliche Komposition mit Formen, Partikeln und deren Kopplung an Audioprozesse; eigene Suite und Framework. Die offizielle Seite meldet aktuell keine neuen R&D-Lizenzen und eine noch vorbereitete kommerzielle Verfügbarkeit. [S06](#s06) | **Stark:** Ausdehnung und Bewegung werden Bestandteile des Klangs.<br>**Grenze:** „Sound Holograms“ ist Anbietersprache, kein hier bestätigter Wahrnehmungsnachweis. Zugang und Integrationsbedingungen sind kein gesicherter Produktpfad.<br>**Übernehmen:** Punkt, Fläche und Wolke als spielbare Gestaltungsformen; keinen proprietären Algorithmus nachbauen. |
| **L-Acoustics L-ISA**<br>Controller und Studio/Prozessor-Systeme für Objekte, Räume und Show-Anbindung; OSC und dokumentierte Integrationen. [S07](#s07) | **Stark:** Vorbereitung im Studio lässt sich mit der Aufführung verbinden.<br>**Grenze:** Ein Kopfhörermix belegt keine gleichwertige Publikumsabdeckung. Versionsabhängige Protokollfähigkeiten müssen am Ziel bestätigt werden.<br>**Übernehmen:** Ein Werk mit separatem Studio- und Veranstaltungsprofil. |
| **FLUX SPAT Revolution**<br>Immersive Verarbeitung, DAW-Integration und OSC-Grammatiken einschließlich ADM-OSC; Local Audio Path als eigener Audioweg. [S08](#s08) | **Stark:** Breites räumliches Werkzeug und dokumentierte Schnittstellen.<br>**Grenze:** Parameter, Räume und Routing erhöhen die Einrichtungsarbeit; OSC überträgt nicht automatisch das Audio einer verteilten Installation.<br>**Übernehmen:** Gut sichtbare Audio- und Steuerpfade mit zunächst wenigen funktionsfähigen Vorlagen. |
| **IRCAM Spat**<br>Software für Echtzeit-Spatialisierung, unter anderem in Max; Eingänge werden verarbeitet und über Lautsprecher oder Kopfhörer ausgegeben. [S09](#s09) | **Stark:** Tiefe experimentelle und kompositorische Kontrolle.<br>**Grenze:** Ein Forschungs-/Patch-Werkzeug setzt andere Kenntnisse voraus als eine sofort spielbare iPhone-Oberfläche.<br>**Übernehmen:** Klanglich definierte Makros mit Expertenzugang; Entwicklungsumgebung nicht zur Standardbedienung machen. |

**Konkreter Vorschlag:** Ein Bewegungsclip speichert Zielobjekt, Kurve, Dauer, Schleife und Referenzraum. „Kreis“, „Linie“ und „Wolke“ sind zunächst drei nachvollziehbare Werkzeuge. Zufall erhält einen gespeicherten Seed; eine Performance kann reproduziert werden. Das ist ein Entwurf, keine bestehende Echoelmusic-Funktion.

## 5. Theater und Veranstaltung

| System / belegter Schwerpunkt | Kritik und Übertragung auf Echoelmusic |
| --- | --- |
| **TiMax SoundHub**<br>Hardware mit dynamischer Delay-Matrix; Objekt-/Zonensteuerung, OSC und Tracking-Anbindung. [S11](#s11) | **Stark:** Lokalisierung in Aufführungssituationen und Zuordnung zu realen Darstellern.<br>**Grenze:** Die Raumplanung und Laufzeitabstimmung kann eine generische 3D-Ansicht nicht ersetzen.<br>**Übernehmen:** Bühnenkoordinaten, Referenzpunkte und Tracking-Fallback pro Objekt. |
| **Meyer Sound Spacemap Go**<br>iPad-Steuerung für das Galileo-GALAXY-System; räumliche Karten, Trajektorien sowie OSC-/DAW-Anbindung. [S10](#s10) | **Stark:** Touch-Bedienung im Veranstaltungsraum.<br>**Grenze:** Die App ist Teil eines Prozessorsystems; ein Tablet allein liefert dessen Lautsprecherverarbeitung nicht.<br>**Übernehmen:** Große Raumflächen und direkte Bewegungsaufnahme, gekoppelt an einen getesteten Renderer. |
| **HOLOPHONIX**<br>Plattform für Performing Arts mit Prozessoren, Native-macOS-Software, Designer und Automationswerkzeugen. [S12](#s12) | **Stark:** Vorproduktion und Aufführung als zusammengehörige Aufgaben.<br>**Grenze:** Die konkrete Protokollversion, Lizenz und Leistung eines Echoelmusic-Adapters sind hier unklar.<br>**Übernehmen:** Als weiteres Wiedergabeprofil planen; erst nach dokumentiertem Interop-Test als unterstützt zeigen. |
| **QLab**<br>Cue-Struktur für Audio, Video und Steuerung; Netzwerk-, MIDI- und Timecode-Funktionen; Verhalten bei Timecode-Stopp konfigurierbar. [S13](#s13) | **Stark:** Ein klarer Aufführungsablauf mit expliziten Aktionen.<br>**Grenze:** Eine Cue-Liste ist keine musikalische Clip-Improvisation; eine korrekte Cue-Auslösung garantiert noch kein korrektes externes Ziel.<br>**Übernehmen:** Vorbereitung, GO, Übergangszeit und Rückmeldung; QLab weiter als Show-Partner nutzbar machen. |

**Für Echoelmusic:** Ein Cue ist eine geplante Aktion, ein Snapshot ein Zustand, ein Bewegungsclip ein zeitlicher Verlauf und ein Raumprofil die konkrete Installation. Diese vier Dinge bekommen unterschiedliche Namen. So bleibt „Szene“ nicht zugleich Musikabschnitt, Mischpultzustand und 3D-Raum.

## 6. Musikproduktion und Touch

| System / belegter Schwerpunkt | Kritik und Übertragung auf Echoelmusic |
| --- | --- |
| **Loopy Pro**<br>Live-Loops, anpassbare Bedienflächen, Aktionen, Sequenzierung, Audio-/MIDI-Routing und AUv3-Hosting. [S14](#s14) | **Stark:** Die Oberfläche lässt sich auf die eigene Performance zuschneiden.<br>**Grenze:** Freie Konfiguration schafft Einrichtungsaufwand; mehrfach belegte Gesten können verzögerte Auslösung benötigen.<br>**Übernehmen:** Sofort nutzbare Vorlagen, eindeutige Record/Overdub/Play-Zustände und ein freiwilliger Bearbeitungsmodus. |
| **Drambo**<br>Modulare Synthese/Verarbeitung, automatische Verbindungen, Parameter-Locks, Morphs, Sequencer und AUv3-Hosting. Die aktuelle Produktseite nennt auch eine optionale Visual-Erweiterung. [S15](#s15) | **Stark:** Sequenz, Klang und Modulation wirken zusammen.<br>**Grenze:** Implizite Verbindungen sparen Kabel, müssen aber erklärbar bleiben; modulare Tiefe erhöht Lernaufwand.<br>**Übernehmen:** Parameter berühren → Quelle und Wirkung sehen; Step-Werte und Kurven bearbeiten denselben Parameter. |
| **Ableton Live**<br>Session View für Clips und Improvisation, Arrangement für den linearen Verlauf. Link und inzwischen Link Audio verbinden passende Geräte im LAN. [S16](#s16), [S17](#s17) | **Stark:** Gespielte Entscheidungen lassen sich in ein Werk überführen.<br>**Grenze:** Clip- und Arrangement-Autorität können für Einsteiger unklar werden; Link Audio löst kein beliebiges Internet-Ensemble.<br>**Übernehmen:** Live-Ausnahme einer Spur sichtbar anzeigen und jederzeit gezielt zum Arrangement zurückkehren. |
| **Imaginando**<br>VS koppelt Visual-Synthese an Audio/MIDI; FRMS verbindet Granulararbeit und Oszillatoren; DRC ist ein Synthesizer, BAM eine Groovebox. [S18](#s18), [S19](#s19), [S20](#s20) | **Stark:** Visuelles Gestalten wird wie ein Instrument bedienbar.<br>**Grenze:** Mehrere Spezialprodukte ergeben noch keinen gemeinsamen Projektzustand oder Bühnenablauf.<br>**Übernehmen:** Einheitliche Makros und gespeicherte Bindungen für Klang und Bild; Spezialinstrumente über passende Plugins beziehungsweise Medienübergabe einbinden. |

**Priorität:** Gute Standardklänge, verlässliche Clip-Zustände und sichtbare Modulationswege bringen mehr als ein erster Bildschirm mit sämtlichen verfügbaren Funktionen. Tiefe bleibt vorhanden und erscheint im ausgewählten Kontext.

## 7. Bild, Postproduktion und Live-Video

| System / belegter Schwerpunkt | Kritik und Übertragung auf Echoelmusic |
| --- | --- |
| **DaVinci Resolve / Fairlight**<br>Schnitt, Farbe, Fusion und Audio in spezialisierten Arbeitsseiten; Cloud-Projekte und gemeinsame Bearbeitung. Fairlight/Studio dokumentieren immersive Workflows. [S21](#s21), [S22](#s22) | **Stark:** Unterschiedliche Gewerke arbeiten am gleichen Werk.<br>**Grenze:** Diese Oberflächentiefe passt nicht unverändert auf ein Telefon. Gemeinsame Projektbearbeitung bedeutet kein latenzarmes gemeinsames Musizieren.<br>**Übernehmen:** Kontextansichten auf gemeinsamen Daten; überprüfbare Medien-/Timeline-Übergabe für die Postproduktion. |
| **OBS Studio**<br>Live-Aufzeichnung und Streaming; integrierte WebSocket-Fernsteuerung seit Version 28. [S23](#s23) | **Stark:** Bewährter Ausspielpartner mit steuerbaren Szenen und Quellen.<br>**Grenze:** Stream-Verzögerung und Programmausgabe eignen sich nicht als Musiker-Monitorweg.<br>**Übernehmen:** Eigener Sendemix; OBS-Verbindung als Status mit Zielszene. Preview, freigegebener Stand und tatsächlich gesendetes Programm auseinanderhalten. |
| **Resolume Arena**<br>Live-Visuals, OSC-Steuerung, NDI-Ein-/Ausgänge und SMPTE-Eingang in Arena. [S24](#s24), [S25](#s25) | **Stark:** Bildclips lassen sich aufführen und mit einer Show verbinden.<br>**Grenze:** Ein Video-Frame ist zeitlich gröber als ein Audiosample; Timecode allein synchronisiert keine Audiogeräte-Takte.<br>**Übernehmen:** Bild-Cues und Mapping-Ziele; auf dem Telefon zuerst einfache, stabile Ausspielung, komplexes Mapping beim Mediensystem. |
| **TouchDesigner**<br>Prozedurale Echtzeit-Bilder und Datenverarbeitung; OSC sowie NDI und weitere Schnittstellen. [S26](#s26) | **Stark:** Freie Gestaltung interaktiver Zusammenhänge.<br>**Grenze:** Ein umfangreicher Patchgraph verlangt Spezialwissen und Ressourcenplanung.<br>**Übernehmen:** Sofort spielbare audiovisuelle Makros; benannte Kontrollkanäle für Experten-Patches. Grafik darf bei Überlast Qualität reduzieren, ohne den Klang zu unterbrechen. |

### Ein Werk, drei verschiedene Ausspielungen

**Musiker:** direkter, möglichst kurzer Monitorweg.

**Publikum im Raum:** PA/Renderer und kalibrierte Projektion.

**Stream:** eigener Audio-/Videomix mit erforderlichem Bild-Ton-Abgleich. Die drei Wege dürfen eigene Verzögerungen haben und brauchen eigene Anzeigen.

## 8. KI als bearbeitbarer Produktionsschritt

| System / belegter Schwerpunkt | Kritik und Übertragung auf Echoelmusic |
| --- | --- |
| **Suno / Suno Studio**<br>Generatives Erzeugen und Bearbeiten; Stem-Separation; Export von Mix, Bereich und Multitrack-WAV. Die aktuelle Hilfe beschreibt auch MIDI-Erzeugung aus Stems. [S27](#s27), [S28](#s28) | **Stark:** Schnelle musikalische Varianten und Material für weitere Produktion.<br>**Grenze:** Getrennte Stems sind nicht automatisch ursprüngliche Einzelaufnahmen; extrahiertes MIDI ist keine garantierte Originalpartitur. Qualität und Präzision müssen am Material geprüft werden.<br>**Übernehmen:** Varianten vorhören, vergleichen und selektiv übernehmen; Original und Herkunft behalten. |
| **ACE Studio**<br>Vokalsynthese aus Noten und Text; lokale Beschleunigung auf geeigneter Hardware, mit Cloud-Fallback. Bearbeitete Abschnitte können gezielt neu gerendert werden. [S29](#s29), [S30](#s30) | **Stark:** Musikalische Steuerung über konkrete Noten und Silben.<br>**Grenze:** Hintergrund-Rendering ist kein belegter latenzfreier Live-Sänger. Lokale Berechnung braucht Leistungsreserven; „lokal“ belegt keinen vollständig offline nutzbaren Gesamtworkflow.<br>**Übernehmen:** Region bearbeiten, Renderzustand sehen, fertigen Take vorhören und bewusst freigeben. |

### Vorgeschlagener Ablauf in Echoelmusic

**1. Auswahl:** Nur den ausgewählten Clip oder Bereich an den gewählten Dienst übergeben.

**2. Auftrag:** Musikalische Absicht, Bezugstempo, Tonart und verfügbare Stimmen explizit machen.

**3. Varianten:** Neue Ergebnisse in einer Variantenliste sammeln; die laufende Performance spielt ihren bisherigen Stand weiter.

**4. Übernahme:** A/B vorhören, einzelne Regionen ersetzen, Änderung als einen rückgängig machbaren Schritt speichern.

**5. Aufführung:** Vorher gerenderte, lokal vorhandene Medien verwenden; bei fehlendem Render den bestätigten Take behalten.

**Integrationsstatus unklar:** Eine nutzbare, lizenzierte öffentliche API/SDK für direkte Echoelmusic-Anbindung an Suno oder ACE Studio wurde nicht nachgewiesen. Deshalb zuerst WAV/MIDI-Übergabe planen. Anbieter, Modellversion soweit verfügbar, Herkunft und Zustimmung bei fremden Stimmen gehören zum Asset. Kein fertiges Rechteversprechen daraus ableiten.

## 9. Kollaboration braucht getrennte Modi

| Modus | Was gemeinsam geschieht | Woran Erfolg gemessen wird |
| --- | --- | --- |
| **Im selben Raum** | Tempo/Phase, gegebenenfalls Audio im LAN; jeder spielt lokal. Ableton Link / Link Audio. | Tatsächlich gehörte Ausrichtung und Dropouts; Netzwerkverbindung allein genügt nicht. |
| **Direktes Remote-Spiel** | Audio läuft während des Spiels zu den anderen. Jamulus, JackTrip, SonoBus, FarPlay, JamKazam. | Hörlatenz pro Richtung, Jitter und Aussetzer; Verbindung und Musikstil entscheiden. |
| **Loop-Austausch** | Abgeschlossene Phrasen treffen später ein und laufen auf einer musikalischen Grenze. NINJAM, JamTaba; Loop-Workflow bei Endlesss. | Exakter Einsatz am Zielintervall und Versionsklarheit; Verzögerung in Takten sichtbar. |
| **Remote-Aufnahme / Review** | Musiker spielt zu vorbereiteter Begleitung; Produzent hört, bespricht und erhält Takes. | Unversehrte Aufnahme, korrekte Zeitausrichtung, klare Monitor-/Talkback-Wege. |
| **Projekt gemeinsam bearbeiten** | Noten, Clips, Dateien und Revisionen werden geteilt; Bearbeitungen können gleichzeitig erfolgen. | Keine verlorenen Änderungen; reproduzierbare Version und vollständige Medien. |

**Warum diese Unterscheidung zählt:** Ein synchronisiertes Tempo bringt eine erst später empfangene Note nicht früher zum Ohr. Ein sauber nachträglich ausgerichteter Take beweist kein zeitgleiches Ensemble. Die Bezeichnung „real time“ in Produkttexten darf diese Unterschiede nicht verdecken. [S17](#s17), [S31](#s31), [S32](#s32), [S33](#s33), [S34](#s34), [S35](#s35), [S36](#s36), [S37](#s37), [S38](#s38), [S39](#s39), [S40](#s40), [S41](#s41), [S42](#s42), [S43](#s43), [S44](#s44), [S45](#s45), [S46](#s46), [S47](#s47)

**Vorschlag für die Oberfläche:** „Gemeinsam spielen“, „Loops austauschen“, „Takes aufnehmen“ und „Projekt bearbeiten“ sind klare Auswahlmöglichkeiten. Der Verbindungsassistent zeigt, welche davon für die aktuelle Strecke und verfügbare Integration geprüft sind. Ein Moduswechsel erfolgt bewusst, niemals unbemerkt während des Stücks.

## 10. Direktes Zusammenspiel über Netz

| Lösung / dokumentierter Ansatz | Bewertung für Echoelmusic |
| --- | --- |
| **Jamulus** [S31](#s31)<br>Servergestütztes gemeinsames Musizieren; persönlicher Mix. Herstellerdoku empfiehlt kabelgebundenes Netz und Kopfhörer; iOS/Android experimentell. | Guter Referenzfall für einen gemeinsamen Rückmix. Der Monitorweg ist Teil des musikalischen Konzepts: Die Jamulus-Anleitung verlangt das Hören des Serverrückwegs. Eine pauschale lokale Direktmonitor-Regel wäre hier falsch. Serverstandort und Gerätekette müssen gemessen werden. |
| **SonoBus** [S32](#s32)<br>Peer-to-peer-Audio, Kontrolle des Jitterpuffers je Teilnehmer; mehrere Plattformen. | Sehr relevanter Vergleich für Musiker-Mixe und transparente Puffer. Die konsultierte Anleitung nennt keine Verschlüsselung der Datenkommunikation. Daraus folgt: Integrationsbedingungen und Vertrauensmodell prüfen; kein sicherer Privatkanal versprechen. |
| **JackTrip** [S33](#s33)<br>Netzmusik mit Studios und DAW-Audio-Bridge; Audio-/Netzkonfiguration dokumentiert. | Starker Kandidat für einen späteren Transportvergleich. Software, Betrieb der Studios und Routing sind getrennte Aufgaben. Eine Echoelmusic-Einbettung oder mobile Bibliothek wird hier nicht als verfügbar angenommen. |
| **FarPlay** [S34](#s34)<br>Direktes Remote-Musizieren; getrennte Pufferstrategie für gehörten Stream und hochwertige Aufnahme. | Besonders wertvolle Idee: Monitor und Aufzeichnung dürfen unterschiedliche Qualitäts-/Latenzprioritäten haben. Ein sauberer Take kann Glitches im gehörten Signal nicht rückwirkend beheben. |
| **JamKazam** [S35](#s35)<br>Online-Sessions mit Audio/Video und Vermittlung von Mitmusikern; Anbieter beschreibt optimierte Netzpfade. | Interessant als vollständiger Session-Ablauf. Behauptete Branchenbestwerte wurden nicht unabhängig geprüft. Entdecken, einrichten, messen und spielen als getrennte Schritte übernehmen; keinen Latenzsieger benennen. |
| **Elk LIVE** [S49](#s49)<br>Als weiterer Marktteilnehmer geprüft; offizielle Seite hier nicht abrufbar (HTTP 401). | Aktueller Betrieb, Hardwarebedarf, SDK und Supportstatus unklar. Kein belastbarer Integrationsvorschlag; vor Beschaffung oder Planung gesondert verifizieren. |

**Auswahlvorschlag:** Jamulus als Referenz für Server-Monitoring, SonoBus für Peer-Mixe und JackTrip für professionellen Netztransport vergleichen. FarPlay dient als Vorbild für getrennte Aufnahme-/Monitorpfade. Das ist eine Testauswahl, keine Aussage über heute verfügbare iOS-SDKs.

## 11. Studio, Aufnahme und Fernabhören

| Lösung / dokumentierter Ansatz | Kritik und passende Übernahme |
| --- | --- |
| **Sessionwire** [S36](#s36)<br>Musikstream, Gespräch, Video, Dateien und DAW-Plugins in einer Session. | Nützliche Trennung von Gespräch und Produktion. Diesen Komfort nicht mit garantiertem Ensemble-Spiel verwechseln. In Echoelmusic: Talkback, Aufnahmestatus und Peer-Berechtigungen getrennt. |
| **Audiomovers LISTENTO** [S37](#s37)<br>Audioübertragung aus Produktionsumgebungen; Handbuch nennt wählbare Latenz bis hinunter zu 50 ms. | Sehr geeignet als Referenz für Mix-Review. Eine eingestellte Mindestlatenz ist kein gemessener Gesamtweg. Für enges rhythmisches Wechselspiel kein pauschales Versprechen ableiten. |
| **Steinberg VST Connect** [S38](#s38)<br>Remote-Aufnahme mit Performer-Seite und Integration in Cubase/Nuendo. | Übernimmt Studiomaterial in einen kontrollierten Aufnahmeablauf. Dieser Workflow unterscheidet sich von gleichberechtigtem Live-Jammen. Veraltete Login-Beschreibungen vermeiden: Support nennt seit Oktober 2025 die Verbindung über Session-Schlüssel. |
| **Source-Connect** [S39](#s39)<br>Professionelle Fernaufnahme, Monitoring und DAW-Anbindung; unterschiedliche Ausbaustufen. | Wichtig für Talent/Regie und Postproduktion. Ein passender Funktionsumfang ist editions- und versionsabhängig. In Echoelmusic: Take-Zuordnung, Timecode-Kontext und prüfbare Übergabe statt pauschalem „Studio-Sync“. |
| **Soundwhale** [S40](#s40)<br>Synchronisierte Remote-Sessions mit Bild, DAW und Take-Bedienung. | Guter Vergleich für Musik zu Bild und gemeinsame Review-Marker. Dokumentation unterscheidet eigene synchronisierte Aufnahme vom bloßen Aufzeichnen eines eintreffenden Streams in der DAW. Diese Unterscheidung im Entwurf erhalten. |
| **Cleanfeed** [S41](#s41)<br>Browserbasierte Audioverbindung und Aufnahme; Mehrspur- sowie Musikmodi. | Niedrige Einstiegshürde für Gäste. Browser-, Geräte- und Netzpuffer bleiben relevant. Als Review/Remote-Aufnahme betrachten; den Einsatz als präzises Ensemble erst unter konkreten Bedingungen nachweisen. |

**Architekturfolge:** Live-Monitorstream, lokaler Original-Take und Gespräch sind drei verschiedene Datenwege. Original-Takes können später vollständig übertragen und anhand ihrer Zeitreferenz eingesetzt werden. Der schnelle Stream bleibt für das Hören während der Session zuständig.

## 12. Loops, Projekte und Verfügbarkeit

| Lösung / dokumentierter Ansatz | Kritik und passende Übernahme |
| --- | --- |
| **NINJAM / ReaNINJAM** [S42](#s42)<br>Aufzeichnen und Austauschen synchronisierter Intervalle. | Macht Netzverzögerung zum musikalischen Prinzip. Funktioniert besonders mit wiederkehrenden Formen; unmittelbares Reagieren auf spontane Formwechsel ist eine andere Aufgabe. Zielintervall explizit anzeigen. |
| **JamTaba** [S43](#s43)<br>NINJAM-Client, Standalone beziehungsweise dokumentierte DAW-Anbindungen. | Nützliche Bedienreferenz für internationale Loop-Sessions. Plugin-/OS-Kompatibilität gegen aktuelle Builds prüfen. Es ist kein zusätzlicher latenzfreier Transport. |
| **Endlesss** [S44](#s44)<br>Gemeinsames Erzeugen, Layern und Remixen von Loops; aktueller App-Store-Eintrag mit Versionshistorie bis September 2025. | Starkes Vorbild für schnelle kreative Beteiligung und Verlauf. Kein Server-/Session-Test durchgeführt; Betriebsqualität unklar. Die alte Schließungsmeldung allein wäre als aktuelles Urteil unzureichend. |
| **Satellite Sessions** [S45](#s45)<br>Audio-/MIDI-Material direkt zwischen DAW-Projekten austauschen. | Gut für unterschiedliche DAWs. Schnelles Hochladen fertiger Stems ist nicht dasselbe wie gegenseitiges Audio-Monitoring. Übernehmen: „neue Version verfügbar“ mit hörbarem Vergleich und eindeutiger Position. |
| **BandLab** [S46](#s46)<br>Online-/Mobile-Studio mit Einladungen zur Zusammenarbeit. | Niedrige Hürde für gemeinsames Produzieren. Gemeinsames Projekt ist kein Beleg für einen bestimmten Ensemble-Latenzwert. Übernehmen: Einladung und eindeutige Rollen; Audio-Routing separat behandeln. |
| **Soundtrap** [S47](#s47)<br>Geteilte Projekte und gleichzeitige Zusammenarbeit; Hilfen für Aufnahme-Latenz. | Browserzugang erleichtert Beteiligung. Aufnahmekalibrierung löst keine Internetlaufzeit. Übernehmen: unkomplizierter Projekteinstieg und bewusstes Übernehmen neuer Beiträge. |
| **jammr** [S48](#s48)<br>Offizielle Seite meldet Schließung und verweist auf Alternativen. | Kein neuer Integrationskandidat. Allgemeine Lehre: lokal vollständige Projekte und exportierbare Medien sichern die Weiterarbeit auch ohne Dienst. |

**Abdeckung:** Dazu gehören die lokale Link-/Link-Audio-Klasse (Abschnitte 6 und 9) sowie Resolve als gemeinsames Postproduktionsprojekt (Abschnitt 7). Zoom-/Meeting-Tools, reine Cloud-Laufwerke und weitere Nischenangebote wurden nicht einzeln geprüft. „Alle“ wird hier als Abdeckung der relevanten Arbeitsweisen verstanden, nicht als unbelegbare Vollständigkeitsbehauptung.

## 13. Eine Oberfläche, klare Zuständigkeiten

**Vorschlag:** Die vorhandenen fünf Arbeitsbereiche bleiben das Grundgerüst. Neue Fähigkeiten erscheinen dort, wo ihr Material bearbeitet wird. Ein gemeinsamer Projektkopf hält Transport, Undo, Auswahl und Verbindungsstatus. Die folgenden Namen beschreiben den Entwurf, keine bereits implementierten APIs.

| Bereich | Optimierter Inhalt und Bedienregel |
| --- | --- |
| **Arrange** | Timeline und ein umschaltbares Live-Raster greifen auf dieselben Clips zu. Live-Spiel kann als Arrangement-Take festgehalten werden. Pro Spur ist sichtbar, ob Timeline oder Live-Auslösung gerade führt. |
| **Mixer** | Pegel, Inserts, Sends und Raum. Der Inspector wechselt zwischen Klangkette, Raumposition und Ausgängen. Persönlicher Kopfhörermix und Publikums-/Sendemix sind benannt. |
| **Instrument** | Spielen und Klangformung. Acht frei belegbare, gut lesbare Makros als vorgeschlagenes Startlayout; bei großer Schrift weniger gleichzeitig. Modulation zeigt Quelle, Bereich und aktuelle Wirkung. |
| **Browse** | Instrumente, Effekte, Samples, Bildmedien, Bewegungen und KI-Varianten. Filter nach Aufgabe und verfügbarem Zielsystem. Ein Plugin ohne passenden Host ist kein scheinbar spielbarer Eintrag. |
| **Piece** | Stückdaten, Tempo/Tonart, Medien, Versionen, Export und Show-Zuordnung. Live Colabo behält eine eindeutige globale Tür; ein Statushinweis öffnet diese vorhandene Tür, keine zweite Session-Verwaltung. |

### Vier Interaktionsregeln

**Auswahl bleibt erhalten.** Wer „Bass“ auswählt, sieht denselben Bass in Arrangement, Mixer und Raum.

**Werte haben Ursachen.** Jeder modulierte Regler zeigt Grundwert, Modulationsquelle und wirksamen Wert; manuelles Übernehmen ist möglich.

**Vorbereiten ist sichtbar.** „Vorgemerkt: nächster Takt“ unterscheidet sich eindeutig von „läuft“ und „Aufnahme“.

**Ein Fehler hat einen Ort.** „Renderer antwortet nicht“ und „Audioeingang fehlt“ sind verschiedene Zustände mit passenden nächsten Schritten.

**Zugänglichkeit:** Mindestens 44 pt Touch-Ziele gemäß bestehender Produktvorgabe, Werteingabe mit EchoelValueField, Text/Icons zusätzlich zur Farbe, VoiceOver-Listenalternative zur Raumkarte, große Schrift und reduzierte Bewegung. Show-Modus sperrt Bearbeitung optional; Stop und definierter Licht-Blackout bleiben erreichbar. [R0](#r0), [R2](#r2)

## 14. iPhone: spielen und verbinden

Schematische Entwürfe. Keine Screenshots und keine implementierte Funktion; Beispielwerte sind keine Messwerte.

### Layout-Spezifikation der beiden iPhone-Entwürfe

Die PDF-Grafiken sind hier als prüfbare Layout-Beschreibung wiedergegeben; es werden keine Bilddateien oder Oberflächen hinzugefügt. Alle Namen und Werte sind Beispiele.

| Ebene | Spielen / Arrange | Live-Colabo-Kontext |
| --- | --- | --- |
| Kopf | Projekt „Nachtwasser“; 120 BPM, 4/4; Stop, Play, Record | Titel, Schließen; gewähltes Gegenüber „Studio B“ |
| Zustand | Umschaltung Arrange / Live-Raster | „Projekt-Austausch aktiv“; „Audio-Jam noch nicht geprüft“ |
| Inhalt | Drums: läuft, 4 Takte; Bass: läuft, 4 Takte; Stimme: vorgemerkt für nächsten Takt; Raumbewegung: bereit, Kreis an Bass gebunden | Netzwerk-RTT: noch nicht gemessen; Hörlatenz A→B: unklar; Kopfhörermix: lokal, kein Netz-Audio; Freigaben: Clips teilen, Bio aus |
| Primäre Aktion | „Letzte Phrase behalten“ | „Verbindung prüfen“ und „Ausgewählte Clips teilen“ |
| Navigation | Bestehende fünf Arbeitsbereiche; Auswahl bleibt erhalten | Rückkehr zur bisherigen Auswahl; keine zweite Transportinstanz |

### Warum dieser Aufbau?

Links bleibt die musikalische Handlung im Vordergrund. Die Raumbewegung ist ein zugeordneter Clip mit eigener Aufnahme und Bearbeitung. Rechts wird erkennbar, was eine Verbindung bereits kann. Eine Session kann für Austausch funktionieren, während Audio-Jam noch ungeprüft ist.

**Layout-Verhalten:** Im Querformat die vorhandene Seitenleiste nutzen. Bei großer Schrift werden Clipdetails umgebrochen und scrollen; Transport und Zustand bleiben lesbar. Auf Gesten versteckte Befehle erhalten sichtbare Alternativen.

## 15. Größere Fläche: Raum und Routing

Desktop-/Tablet-Zielbild zur Diskussion; die Umsetzung bleibt iPhone-first.

### Layout-Spezifikation für Tablet und Desktop

| Fläche | Inhalt und Bedienung |
| --- | --- |
| Gemeinsamer Kopf | Projekt, Tempo, Play/Stop, Undo |
| Linke Spurliste | Drums, Bass, Stimme, Textur; Bass ausgewählt |
| Mittlere Raumfläche | Draufsicht mit bezeichnetem Vorne; Objekte und editierbare Bewegungskurve; gleichwertige bedienbare Listenansicht |
| Rechter Inspektor | Derselbe Bass; Position X −0,4 / Y 0,2 / Z 0,0; Bewegung Kreis, 4 Takte; Beispielprofil „SPAT / Saal A“; Audiokanal 2, externe Objekt-ID 12; **Probe ausstehend** |
| Cue-Zeile | „Cue 04 / Bass nach vorn“; Vorbereitung, GO; Ausführungsstatus |
| Navigation | Arrange, Mixer/Raum, Instrument, Browse, Piece; bestehende Auswahl und Transport |

Koordinaten, Kanalnummern und Profilname sind Entwurfsdaten, keine geprüfte Installation. Ein externer Empfänger darf erst nach einem konkreten Test als unterstützt bezeichnet werden.

### Ein Objekt, drei zusammenhängende Bearbeitungen

**Spur:** Der ausgewählte Bass bleibt derselbe musikalische Inhalt.

**Bewegung:** Die Kurve kann aufgenommen, gekürzt, quantisiert oder als Variante gespeichert werden.

**Ausgabe:** Audiokanal und externe Objektnummer sind sichtbar und werden nicht aus der momentanen Bildschirmreihenfolge abgeleitet.

Ein Raumwechsel lädt ein Ausgabeprofil mit Achsen, Maßstab, Ursprung, Kanalzuordnung und Leistungsgrenzen. Das Werk selbst bleibt erhalten. Außerhalb erreichbarer Bereiche erhält die Bewegung eine sichtbare Einschränkung. Eine räumliche Live-Geste hat einen klaren Override- und Rückkehrzustand.

**Kein falsches Grün:** „Steuerdaten gesendet“, „Renderer antwortet“ und „Audio am Ziel geprüft“ sind getrennte Zustände. Ein UDP-Send ohne Rückkanal darf nur den ersten bestätigen. Die gezeichnete Raumkarte bietet zusätzlich eine bedienbare Objektliste.

## 16. Schnittstellen mit klarer Bedeutung

| Weg | Trägt / trägt nicht | Vorgeschlagener Nachweis |
| --- | --- | --- |
| **AUv3** | Instrument-/Effekt-Integration auf geeigneten Apple-Hosts. Ein eigenes Plugin-Target ist noch kein Host fremder Plugins. [S52](#s52), [R1](#r1) | Preset und Zustand speichern, Automation, Reload, Fehlerfall und Kanalwechsel mit realem Plugin prüfen. |
| **Link / Link Audio** | Link: Tempo/Timing; Link Audio zusätzlich LAN-Audio in unterstützten Apps. Nicht pauschal für Internet-Jams geeignet. [S17](#s17) | Offiziellen SDK-/Lizenzpfad gesondert prüfen; mehrere Geräte, Monitorweg und Drift messen. |
| **ADM-OSC / Hersteller-OSC** | Objektmetadaten und Befehle; kein Audio. Achsen, Einheiten, Bereiche und unterstützte Felder unterscheiden sich. [S01](#s01), [S08](#s08), [S50](#s50), [S51](#s51) | Profil versionieren; alle Achsen, Gain/Extent, Limits und Rückmeldung gegen Zielrenderer prüfen. |
| **USB / Dante / AES67** | Audio benötigt einen eigenen nutzbaren Geräte-/Netzpfad. Gleiche IP-Verbindung bedeutet keine Audio-Kompatibilität. [R0](#r0) | Reale Ein-/Ausgänge und Kanäle prüfen. Dante-Verwaltung über Fachtools; AES67 ist kein vollständiger Ersatz für alle Dante-Funktionen. |
| **Timecode / MIDI / OSC-Cues** | Position und Steuerung; keine gemeinsame Sample-Clock durch bloße Befehlsübertragung. [S13](#s13), [S25](#s25) | Start, Stop, Sprung, Tempoänderung und Ausfall definieren; genau eine Autorität je Transportmodus. |
| **Video / NDI / OBS** | Bild-/Audioverteilung beziehungsweise Fernsteuerung. OBS-WebSocket und OSC sind Steuerwege, kein Videobild. [S23](#s23), [S24](#s24), [S25](#s25), [S26](#s26) | Bildformat und Bild-Ton-Versatz prüfen; Integrations-SDKs und tatsächliche Empfangsseite nachweisen. |
| **WAV / MIDI / Atmos** | Medienübergabe; ein WAV/MIDI-Paket ist keine native Fremd-DAW-Session. ADM BWF benötigt passende Metadaten/Toolchain. [S05](#s05), [S28](#s28) | Import in Zielprogramm und hörbaren Roundtrip testen; Kanalbezeichnungen, Startposition und Format beilegen. |

**Profilvertrag:** Interne Objekt-ID → externe ID → Audiokanal; Koordinatensystem und Version; gewünschte/unterstützte Funktionen; gemessene oder unbekannte Latenz; Rückkanal; Ausfallverhalten. Nicht unterstützte Parameter werden angezeigt, nicht stillschweigend als erfolgreich ausgegeben.

## 17. Latenz messen, Betrieb bewusst wählen

Der vorhandene Code trennt bereits Netzwerk-Rundlaufzeit von Hörlatenz. Die dort genannten Ziele sind **höchstens 10 ms Selbstmonitoring** und **höchstens 20 ms entfernte Einweglatenz im p95**. Es sind Ziele, keine bestätigten Messungen. Der vorhandene Kalibrationskern hat laut gelesener Datei keinen Audio-API-Aufrufpfad. [R4](#r4), [R7](#r7)

| Messgröße | Bedeutung und zulässige Aussage |
| --- | --- |
| Netzwerk-RTT | Hin- und Rückweg eines Probes. Nicht als Audio-Einweglatenz ausgeben und nicht einfach halbieren. |
| Selbstmonitoring | Eigener Eingang bis zum gehörten lokalen Ausgang, einschließlich Geräte- und Pluginpfad. |
| Entfernte Hörlatenz | Ereignis bei A bis zum ausgegebenen Klang bei B; Richtung umgekehrt separat messen. Messaufbau und Unsicherheit angeben. |
| Drift / Jitter / Aussetzer | Langfristige Taktabweichung, Ankunftsschwankung und nicht rechtzeitig verfügbare Samples; p50/p95 und Aussetzerzahlen über dokumentierte Dauer. |

### Rechenbeispiel, kein Benchmark

Bei 48 kHz dauert ein Puffer mit 128 Samples 2,67 ms. Zwei solche Puffer ergeben bereits 5,33 ms; Wandler, Plugins, Paketbildung, Netz und Jitterpuffer kommen hinzu. Eine hypothetische Einwegkette von 3 + 2 + 8 + 4 + 3 ms ergibt 20 ms. Kein Summand wurde hier gemessen; die Beispielrechnung zeigt nur, wie knapp ein Gesamtbudget sein kann.

### Vorgeschlagene Session-Zustände

**Entdeckt → eingeladen → verbunden → geprüft → bereit → spielt.** Pro Zustand ist klar, welche Freigaben und Prüfungen fehlen. Wird eine Verbindung schlechter, lautet die Meldung etwa „Direktes Zusammenspiel instabil; Loop-Austausch verfügbar“. Der Wechsel braucht eine bewusste musikalische Entscheidung.

**Monitoring:** Für Peer-direkte Wege und Remote-Overdubs kann lokales Monitoring sinnvoll sein. Bei einem Jamulus-artigen gemeinsamen Rückmix gilt ein anderer Vertrag. Deshalb pro Backend ein eindeutiges Monitorprofil, Mix-minus gegen Rückkopplung und ein separater Aufnahmeweg. [S31](#s31), [S34](#s34)

**Musikalische Alternative:** Vier Takte bei 120 BPM und 4/4 dauern acht Sekunden. Ein Intervall-Jam kann diese Verzögerung absichtlich nutzen und weltweit sinnvoll bleiben. Im UI steht dann „Beitrag für den nächsten 4-Takt-Block“, nicht „latenzfrei“. [S42](#s42)

## 18. In die bestehenden Eigentümer einpassen

| Bestehender Anker | Vorgeschlagene Verantwortung / Grenze |
| --- | --- |
| **StageShell / WorkstationView** [R2](#r2) | Neue Kontextansichten auf bestehender Auswahl. Lebensdauer der Instrument-View erhalten; keine neue Root-Presentation-Kette. Schnelle Anzeigen bleiben in Blattansichten. |
| **TimelineStore / Projektzustand** [R5](#r5) | Clips, Versionen und aufgezeichnete Performance bilden ein Werk. Bewegungsclips erhalten stabile IDs und Referenzen; keine zweite Timeline nur für Spatial. |
| **SpatialSceneStore** [R3](#r3) | Kanonischer Szenenzustand im Control-Bereich. Externe ID-Tabelle pro Profil ergänzen; Umordnen von Spuren darf Zuordnungen nicht ändern. |
| **ADMOSCSender / OSCReceiver** [R3](#r3) | Adapter, Validierung, Begrenzung und Sendetakt. Rückmeldungen nicht endlos erneut senden; Herkunft intern verfolgen, ohne fremde Protokolle eigenmächtig um Felder zu erweitern. |
| **EngineBus / Renderpfade** [R6](#r6) | Vorbereitete Parameter und Events an vorhandene Audio-Eigentümer übergeben. Jede Queue braucht einen nachgewiesenen Erzeuger und Verbraucher; keine neue wartende Queue ohne Wirkung. |
| **MultipeerSession / ColabPayload** [R4](#r4) | Vorhandener lokaler Austausch bleibt seine eigene Transportart. Neue Audioverbindung und Projektoperationen benötigen explizite Verträge, nicht einen zusätzlichen Namen für denselben Sendebefehl. |
| **Externe Bild-/Show-Ziele** [R8](#r8) | Zeitmarkierte Steuer-Snapshots an Bild und Licht. Langsame Empfänger dürfen den Audio-Callback nicht blockieren; unter Last zuerst Grafikqualität und optionale Datenrate reduzieren. |

**Audio-Thread:** Keine Allokation, kein Lock, kein GCD, kein Task/await, keine Datei-/Netz-I/O und keine UI-Arbeit. Puffer und DSP-Zustand vorher vorbereiten; begrenzte Queues, klare Lebensdauer und glatte Parameterwechsel. Plugin-Aufbau, FFT-Planung/Setup, JSON, Upload und KI-Rendering gehören außerhalb des Callbacks. Eine FFT-Ausführung im Renderpfad ist nur mit vorab vorbereitetem Speicher und nachgewiesen begrenzter Laufzeit vertretbar; sie ist nicht pauschal verboten. [R0](#r0), [R6](#r6)

**Gemeinsames Bearbeiten:** Für den ersten Entwurf rollenbasierte Änderungen und eindeutig angenommene Revisionen wählen. Live-Transport hat eine benannte Autorität; gleichzeitige Bearbeitungen desselben Clips erzeugen sichtbare Varianten. Ein umfassendes CRDT-System ist ohne konkrete Konfliktfälle noch nicht begründet.

## 19. Umsetzung in vollständigen Schritten

Keine neuen Kalender- oder Zeilenschätzungen für diese Gesamt-Roadmap ohne Implementierungsprüfung; die begrenzten Port-Größen aus dem Archiv-Audit stehen gesondert in Abschnitt 0. Die Reihenfolge folgt musikalischem Nutzen, Abhängigkeiten und Nachweisbarkeit. Jeder Schritt endet mit einer nutzbaren Funktion und einem Geräteprotokoll.

| Reihenfolge | Lieferbarer Schritt | Abnahme / wichtigste Abhängigkeit |
| --- | --- | --- |
| **0. Bestand sichern** | Aktuellen Stand nach dem Plugin-Fenster aufnehmen; bestehende Türen, Auswahl und Save/Open prüfen. | Keine konkurrierende UI-/Hosting-Implementierung. Aktuellen Commit und Gerätebefund festhalten. |
| **1. Klang → Clip** | Ein gutes Instrument, spielbare Phrase, behalten/bearbeiten und als Stück sichern. Geeignete Alt-DSP-Kerne aus Audit PR #425 gezielt übernehmen. | Hörbarer, reproduzierbarer Save/Open-Roundtrip; Klangqualität mit dem Musiker prüfen. Keine komplette Alt-Engine zurückkopieren. |
| **2. Clip → Raum** | Bewegung aufnehmen und auf genau einem dokumentierten externen Renderer hören; stabile Objekt-/Kanalzuordnung. | Bass umordnen, speichern, neu laden und identisch zuordnen. Achsen und Bereichsgrenzen bestätigt. |
| **3. Lokal zusammen** | Bestehenden Austausch um nachgewiesenes Timing erweitern; offizieller Link-Pfad prüfen, Link Audio separat evaluieren. | Zwei Geräte, Tempoänderung und Wiederverbindung; gehörte Ausrichtung messen. SDK/Abhängigkeit ist eine eigene Freigabe. |
| **4. Remote-Takes / Loops** | Ein verbindlicher Session-Modus mit lokalem Original-Take und Wiederaufnahme abgebrochener Transfers. | Netzunterbrechung verliert keinen bestätigten Take. Eingehende Variante wird an der richtigen musikalischen Stelle eingesetzt. |
| **5. Direkter Remote-Jam** | Geeigneten Transport nach Vergleich integrieren, Monitorprofile und Qualitätsanzeige ergänzen. | p95-Ziel auf benannter Strecke prüfen; andere Strecken nicht mit abgedeckt. Kein stiller Wechsel in einen anderen Modus. |
| **6. Bild, Bühne, KI** | Je ein vertikaler Ablauf: Cue an Bild/Show-Ziel; KI-Variante als lokales Medium übernehmen. | Ein korrektes externes Ergebnis pro Integration. Render-/Exportstatus sichtbar, Live-Klang bleibt stabil. |

**Warum diese Reihenfolge?** Sie bringt nach jedem Schritt einen vollständigen musikalischen Ablauf. Sie schiebt keine Produktdomäne dauerhaft aus dem Zielbild; sie verhindert, dass viele neue Oberflächen zugleich auf ungeprüfte Signalwege zeigen.

## 20. So wird das Redesign nachgewiesen

| Aufgabe | Nachweis vor einer Funktionsbehauptung |
| --- | --- |
| Klang und Plugin | Preset, Automation und Medien nach Neustart wiederherstellen; Plugin-Ausfall und Wechsel des Audio-Geräts kontrolliert behandeln. |
| Live → Arrangement | Clip auslösen, Übergang aufnehmen und denselben Verlauf abspielen; kein zweiter Transport, keine versehentlich doppelte Stimme. |
| Raumwechsel | Eine kurze Bewegung in zwei Ausgabeprofilen prüfen. Achsen, Extent, Gain und Kanalbezug protokollieren; Unterschiede hörbar beurteilen. |
| Show-Cue | Vorbereiten, GO, Stop, Wiederholung und Timecode-Sprung testen. Pro Empfänger bestätigen, was ausgeführt wurde und was unklar bleibt. |
| Direkter Jam | Beide Richtungen messen; p50/p95, Aussetzer, Geräte-/OS-/Interface-/Pufferdaten und Netzweg dokumentieren. RTT nicht als Hörlatenz werten. |
| Gemeinsamer Take | Verbindung während Transfer trennen, wiederaufnehmen, Prüfsumme und Samplezahl vergleichen; kein unvollständiges Asset als fertig anzeigen. |
| Video / Stream | Bild-Ton-Versatz am tatsächlichen Programmausgang messen. Stream-Monitor darf nicht unbemerkt zum Musiker-Monitor werden. |
| KI-Variante | Vorhandene Version bleibt erhalten; nur gewählter Bereich wird übernommen; fehlendes Render oder Dienstfehler stoppt keine Performance. |
| Bedienbarkeit | Mit VoiceOver und großer Schrift: Spur wählen, Pegel ändern, Cue auslösen, zurücknehmen. Keine ausschließlich farb- oder gestenabhängige Kernaktion. |

### Offen bleibt ausdrücklich

Keine Aussage zur relativen Klangqualität der Wettbewerber ohne Hörvergleich. Keine bestätigte Serververfügbarkeit aus einer Webseite allein. SDKs, Lizenzbedingungen, iOS-Verfügbarkeit und konkrete Adapterleistungen brauchen eigene Prüfung. Die Wireframes sind Designhypothesen; ihre Überlegenheit ist erst mit Aufgabentests belegt.

## 21. Kopierbarer Prompt für Claude

Dieser Übergabeauftrag ist zunächst ein **Codeabgleich und ein konkreter Plan für den nächsten Entwicklungsschritt**. Er erteilt keine pauschale Freigabe für die gesamte Roadmap. Eine bereits separat erteilte, konkrete Implementierungsfreigabe bleibt gültig; deren Umfang darf durch diesen Bericht nicht erweitert werden.

```text
Repo: vibrationalforce/Echoelmusic
Auftrag: Die Recherche in reports/recherche-redesign-claude-2026-10-14.md
gegen den aktuellen Code prüfen und daraus genau einen konkreten nächsten
Entwicklungsschritt für Echoelmusic vorbereiten.

Arbeite vom aktuellen Nutzerauftrag aus. Das parallel gebaute Plugin-Fenster
und die laufende H6-Effekt-Arbeit haben bestehende Eigentümer. Keine zweite
Hosting-Implementierung, kein UI-Neubau und keine neue Parallel-Engine.

1. Tatsächlichen Ausgangspunkt feststellen
   - git status --short, git branch --show-current, git rev-parse HEAD und
     die jüngsten relevanten Commits lesen. Fremde Änderungen erhalten.
   - Geltende AGENTS.md, CLAUDE.md, docs/dev/FOUNDER_PRODUCT_LAW.md und
     docs/dev/ECHOELMUSIC_MASTER_PLAN.md lesen. Gegenwärtige Produktgesetze
     gelten; historische Kürzungen sind keine heutige Produktgrenze.
   - docs/dev/FEATURE_STATUS.md und ContentPipeline/CLAIMS.md als zu
     prüfende Aussagen behandeln, nicht als Ersatz für Produktionsaufrufer.
   - Diesen Bericht, reports/port-kandidaten-2026-10-14.md,
     docs/dev/HISTORY_ARCHIVE.md A/B und
     scratchpads/PLAN_H6_EFFECT_PLUGINS_2026-10-14.md lesen.
   - Die Recherchebasis B ist 48ba58a7b33879b0efdc9fea6c96979b44a29197.
     Der Hosting-Nachtrag H ist b495ae64c7aec213c0552ecc5a4e754a9ce18681.
     Spätere Änderungen nicht als fehlend behandeln.

2. Bestehende Umsetzung zuerst abgleichen
   - TrackPluginRow, HostedInstrumentHost, DeviceChain, PluginEffectInsert,
     TimelineStore und AudioEngine prüfen: Was ist seit H tatsächlich hinzu-
     gekommen? Wo sind Konstruktor, Produzent, Verbraucher und Audioausgang?
   - Native Plugin-View, fullStateForDocument, Save/Open, Effekt-Modell,
     Writer, Track-Bus und wirklich eingehängten Effekt auseinanderhalten.
   - Je Aussage getrennt angeben: Codepfad vorhanden, Compile-Nachweis,
     verifizierter Geräte-/Hörnachweis. Ohne Beleg ausdrücklich „unklar“.
   - Vorhandene NEEDS-FOUNDER-VERIFY-Bitten nicht durch Codelektüre schließen.
     Keine neuen Features als ausgeliefert bezeichnen.

3. Eine musikalisch vollständige nächste Scheibe auswählen
   - Vorrang hat die aktuelle vereinbarte Arbeitsreihenfolge. Diesen Bericht
     nicht als Auftrag verstehen, die laufende Plugin-Arbeit zu unterbrechen.
   - Für Schritt 2 die acht Archiv-Kandidaten am aktuellen HEAD nachprüfen.
     Empfehlung: ein Drum- oder FM-Kern; Alternative ModalBank, falls eine
     Wiederanbindung des erhaltenen Kerns den sinnvolleren ersten Schritt gibt.
   - Bei historischen Quellen Löschcommit und gelesenen Elternstand trennen:
     git show <Loeschcommit>^:<alter_Pfad>. Ist der Report-SHA bereits der
     Quellstand, direkt git show <Quell-SHA>:<alter_Pfad> verwenden.
   - Den kleinsten brauchbaren Ablauf beschreiben: Klang wählen → spielen →
     Phrase/Clip behalten → speichern → neu laden → denselben Klang hören.
   - Genau eine bevorzugte Scheibe benennen, mit aktuellem Aufnahmeort,
     betroffenen Dateien, unverzichtbarer Zustands-/Persistenzänderung,
     Abhängigkeiten, Risiken und begründeter Größenordnung. Fehlende
     Informationsgrundlage als „unklar“ angeben. Keine ganze Alt-Shell portieren.

4. Redesign bei jeder Integration einhalten
   - Ein Projekt, eine Auswahl, eine Transport-Autorität je Betriebsmodus.
     Bestehende fünf Arbeitsbereiche und iPhone-first berücksichtigen.
   - Clips, Audio, Bewegung, Cues und Ausgabeprofile über stabile Identitäten
     verbinden. Externe Objektnummer und Audiokanal niemals aus wechselnder
     Listenreihenfolge ableiten. Cue, Snapshot, Bewegungsclip, Raumprofil trennen.
   - „Steuerdaten gesendet“, „Renderer antwortet“ und „Audio am Ziel geprüft“
     getrennt ausweisen. ADM-OSC transportiert keine Audiosamples und ist
     kein Atmos-Master. Schnittstellen zuerst mit einem realen Ziel nachweisen.
   - Lokales Timing, direktes Remote-Spiel, Intervall-Loops, Remote-Takes und
     Projektbearbeitung getrennt behandeln. RTT nicht als Hörlatenz ausgeben
     und nicht halbieren. Ein Link-Audio-Produktbeleg beweist kein verfügbares
     Drittanbieter-SDK für Echoelmusic.
   - Remote-Audio getrennt nach Monitor, lokalem Original-Take und Gespräch
     entwerfen; Dropouts, Drift, p50/p95 und Messaufbau benennen. Ziele aus
     dem Repo nicht als Messwerte darstellen.
   - Bei Suno/ACE zunächst WAV/MIDI-Übergabe, bis ein zulässiger offizieller
     Integrationspfad belegt ist. Ergebnisse als Varianten mit Herkunft
     speichern; laufenden Klang bei Dienstfehler nicht ersetzen oder stoppen.
   - Klare Zustände, sichtbare Modulationsursachen, EchoelValueField,
     mindestens 44-pt-Ziele, VoiceOver, große Schrift und reduzierte Bewegung.

5. Technische Grenzen und Abnahme konkret machen
   - Render-Callback und alle erreichbaren Funktionen: keine Allokation,
     kein Lock (auch kein Try-Lock), kein GCD, keine Tasks/await, Datei-/Netz-I/O
     oder UI-Arbeit. Vorbereitete feste Puffer, klare Besitzer, sichere
     begrenzte Übergaben, geglättete Parameter. Copy-on-write, Lazy-Init,
     System-RNG und Referenzfreigaben nicht aus der Prüfung ausklammern.
   - Control-/UI-Arbeit und Audio-Arbeit sauber trennen. GCD außerhalb des
     Audiopfads ist durch diese Regel nicht pauschal verboten.
   - Bestehende Audio-/Projekt-Eigentümer wiederverwenden; keine neuen
     Pakete, Frameworks, Targets oder Infrastruktur ohne den jeweils geltenden
     Auftrag. Die geschützte Triade und die Root-Presentation-Regeln beachten.
   - Für spätere Implementierung gezielt prüfen: Compile im tatsächlich
     betroffenen Target; echte Signalwerte; Noten-/Release-/Reset-Verhalten;
     Save/Open; hörbarer Geräte-Roundtrip; Renderzeit/Allokation unter Last.
     Geräte-/Hörprüfungen bleiben offen, solange sie nicht ausgeführt wurden.
   - Für wesentliche Architektur-/Audio-Entscheidungen die geltende
     Council-Regel aus CLAUDE.md anwenden. Keine hypothetischen Extra-Gates.

6. Ergebnis dieses Übergabeauftrags
   A. Kurze Tabelle „Behauptung / aktueller Codebeleg mit SHA und Pfad /
      Compile / Gerätebeleg / Korrektur oder offene Frage“.
   B. Genau eine bevorzugte nächste Scheibe mit Nutzen, Dateien,
      Zustandsfluss, Audio-Thread-Grenze und prüfbaren Abnahmekriterien.
   C. Was wegen der laufenden Plugin-Arbeit später anschließt; übrige
      Roadmap als Reihenfolge, nicht als parallele Arbeitsaufträge.
   D. Nur Fragen nennen, deren Antwort die konkrete nächste Entscheidung
      tatsächlich verändert. Routineentscheidungen selbst begründen.

Ohne separat erteilten Implementierungsauftrag bleibt dieser Durchlauf
lesend und liefert A–D als Bericht. Sources/, Tests/, .github/, CLAUDE.md,
project.yml und Info.plist nicht verändern; keine Pakete installieren.
Keine Code-Tests nur für diese Textübergabe erfinden oder Build-Erfolg
behaupten. Besteht bereits ein konkreter Implementierungsauftrag, gilt
dessen freigegebener Umfang und dessen bestehender Prüf-/PR-Ablauf.
```

### Abnahme dieser Berichtsänderung

- Genau eine neue Datei unter `reports/`; keine Änderung an Produktcode oder Konfiguration.
- Alle genannten Produktgruppen enthalten belegte Funktionen, eigene Kritik und Konsequenzen für Echoelmusic.
- Marktquellen und Repo-Quellen sind getrennt; Repo-Belege sind an feste SHAs gebunden.
- Der neuere Hosting-Stand überschreibt die veraltete Annahme „Hosting nicht belegt“.
- Archiv-Befunde bleiben am ursprünglichen Prüfstand; unbestätigtes Audio bleibt „unklar“.
- Der Claude-Prompt enthält einen konkreten nächsten Arbeitsablauf und schützt die laufende Plugin-Arbeit.

## 22. Quellen und Nachweise

Abruf der Webquellen: **14.10.2026**. Primärquellen sind Produktdokumentation, Hersteller-Repositories und offizielle Supportseiten. Herstellerangaben sind keine unabhängigen Benchmarks. Quelle S49 dokumentiert ausdrücklich einen fehlgeschlagenen Abruf, keine bestätigte Produkteigenschaft.

### S01

Grapes 3D: Funktionen und FAQ

- [https://grapes-3d.com/](https://grapes-3d.com/)

### S02

Adamson: FletcherMachine, Rendering, System und Integration

- [https://adamson-fletcher-machine.com/](https://adamson-fletcher-machine.com/)
- [https://adamson.ai/news/2024-07-04-the-fletchermachine-v2-now-available-for-download](https://adamson.ai/news/2024-07-04-the-fletchermachine-v2-now-available-for-download)

### S03

d&b: En-Scene

- [https://www.dbaudio.com/global/en/products/all/product-types/software/en-scene/](https://www.dbaudio.com/global/en/products/all/product-types/software/en-scene/)

### S04

d&b: En-Space

- [https://www.dbaudio.com/global/en/products/all/product-types/software/en-space/](https://www.dbaudio.com/global/en/products/all/product-types/software/en-space/)

### S05

Dolby: Masterformate und Produktionsworkflow

- [https://professionalsupport.dolby.com/s/article/Overview-of-Dolby-Atmos-Master-File-Formats](https://professionalsupport.dolby.com/s/article/Overview-of-Dolby-Atmos-Master-File-Formats)
- [https://professional.dolby.com/en-gb/content-creation/dolby-atmos-for-content-creators/](https://professional.dolby.com/en-gb/content-creation/dolby-atmos-for-content-creators/)

### S06

4DSOUND: Software, Formen, Framework und Lizenzstatus

- [https://4dsound.net/software](https://4dsound.net/software)

### S07

L-Acoustics: L-ISA Controller und Studio

- [https://www.l-acoustics.com/products/l-isa-controller/](https://www.l-acoustics.com/products/l-isa-controller/)
- [https://www.l-acoustics.com/fr/products/l-isa-studio/](https://www.l-acoustics.com/fr/products/l-isa-studio/)

### S08

FLUX: SPAT Revolution, OSC und Plugin-/Audio-Anbindung

- [https://www.flux.audio/project/spat-revolution/](https://www.flux.audio/project/spat-revolution/)
- [https://doc.flux.audio/spat-revolution/Appendix_C_OSC_Table.html](https://doc.flux.audio/spat-revolution/Appendix_C_OSC_Table.html)
- [https://doc.flux.audio/spat-revolution/Ecosystem_%26_integration_Plugins.html](https://doc.flux.audio/spat-revolution/Ecosystem_%26_integration_Plugins.html)

### S09

IRCAM: Spat-Projekt und Echtzeit-Verarbeitung

- [https://forum.ircam.fr/projects/detail/spat/](https://forum.ircam.fr/projects/detail/spat/)

### S10

Meyer Sound: Spacemap Go und System-Handbuch

- [https://software.meyersound.com/spacemap-go](https://software.meyersound.com/spacemap-go)
- [https://docs.meyersound.com/products/en/user-guide---spacemap-go.html](https://docs.meyersound.com/products/en/user-guide---spacemap-go.html)

### S11

TiMax: SoundHub und Lokalisierungsansatz

- [https://timaxspatial.com/products/timax-soundhub/](https://timaxspatial.com/products/timax-soundhub/)
- [https://timaxspatial.com/support/science-of-immersion/](https://timaxspatial.com/support/science-of-immersion/)

### S12

HOLOPHONIX: aktuelle Produktfamilie

- [https://holophonix.xyz/en](https://holophonix.xyz/en)

### S13

QLab 5: Cues und Timecode-Verhalten

- [https://qlab.app/docs/v5/fundamentals/cues/](https://qlab.app/docs/v5/fundamentals/cues/)
- [https://qlab.app/docs/v5/networking/using-timecode/](https://qlab.app/docs/v5/networking/using-timecode/)

### S14

Loopy Pro: Handbuch, Routing, Aktionen, MIDI, Sequencer

- [https://loopypro.com/manual/](https://loopypro.com/manual/)

### S15

BeepStreet: Drambo, Modulation, AUv3 und Visual-Erweiterung

- [https://www.beepstreet.com/ios/drambo](https://www.beepstreet.com/ios/drambo)
- [https://www.beepstreet.com/drambo-docs/parameter-locks.html](https://www.beepstreet.com/drambo-docs/parameter-locks.html)

### S16

Ableton Live 12: Session und Arrangement

- [https://www.ableton.com/en/live-manual/12/session-view/](https://www.ableton.com/en/live-manual/12/session-view/)
- [https://www.ableton.com/en/live-manual/12/arrangement-view/](https://www.ableton.com/en/live-manual/12/arrangement-view/)

### S17

Ableton: Link Audio FAQ, LAN-Grenze und Monitoring

- [https://help.ableton.com/hc/en-us/articles/25425913328924-Link-Audio-FAQ](https://help.ableton.com/hc/en-us/articles/25425913328924-Link-Audio-FAQ)

### S18

Imaginando: VS Visual Synthesizer

- [https://www.imaginando.pt/products/vs-visual-synthesizer](https://www.imaginando.pt/products/vs-visual-synthesizer)

### S19

Imaginando: FRMS-Handbuch

- [https://help.imaginando.pt/en/article/frms-granular-synthesizer-user-manual-1rtea03/](https://help.imaginando.pt/en/article/frms-granular-synthesizer-user-manual-1rtea03/)

### S20

Imaginando: BAM und DRC-Handbücher

- [https://help.imaginando.pt/en/article/bam-beat-maker-music-maker-user-manual-1k520vv/](https://help.imaginando.pt/en/article/bam-beat-maker-music-maker-user-manual-1k520vv/)
- [https://help.imaginando.pt/en/article/drc-polyphonic-synthesizer-user-manual-195skme/](https://help.imaginando.pt/en/article/drc-polyphonic-synthesizer-user-manual-195skme/)

### S21

Blackmagic Design: Fairlight und Resolve Studio

- [https://www.blackmagicdesign.com/de/products/davinciresolve/fairlight](https://www.blackmagicdesign.com/de/products/davinciresolve/fairlight)
- [https://www.blackmagicdesign.com/de/products/davinciresolve/studio](https://www.blackmagicdesign.com/de/products/davinciresolve/studio)

### S22

Blackmagic Design: gemeinsame Projektbearbeitung

- [https://www.blackmagicdesign.com/products/davinciresolve/collaboration](https://www.blackmagicdesign.com/products/davinciresolve/collaboration)

### S23

OBS Studio: Remote Control Guide

- [https://obsproject.com/kb/remote-control-guide](https://obsproject.com/kb/remote-control-guide)

### S24

Resolume: OSC und NDI-Ein-/Ausgänge

- [https://resolume.com/support/en/osc](https://resolume.com/support/en/osc)
- [https://resolume.com/support/en/NDI_inputs_and_outputs](https://resolume.com/support/en/NDI_inputs_and_outputs)

### S25

Resolume: SMPTE in Arena

- [https://www.resolume.com/support/en/smpte](https://www.resolume.com/support/en/smpte)

### S26

Derivative: TouchDesigner-Schnittstellen und NDI

- [https://derivative.ca/feature/interoperability/73](https://derivative.ca/feature/interoperability/73)
- [https://derivative.ca/UserGuide/NDI](https://derivative.ca/UserGuide/NDI)

### S27

Suno: Studio und aktuelle Stem-Separation

- [https://www.suno.com/blog/suno-studio](https://www.suno.com/blog/suno-studio)
- [https://help.suno.com/en/articles/13925185](https://help.suno.com/en/articles/13925185)

### S28

Suno: WAV-/Multitrack- und MIDI-Export aus Studio

- [https://help.suno.com/en/articles/13925249](https://help.suno.com/en/articles/13925249)

### S29

ACE Studio: Vocals aus MIDI und Text

- [https://docs.acestudio.ai/ai-vocal-synth/creating-ai-vocals](https://docs.acestudio.ai/ai-vocal-synth/creating-ai-vocals)

### S30

ACE Studio: lokales Rendering und Cloud-Fallback

- [https://docs.acestudio.ai/ai-rendering/local-rendering](https://docs.acestudio.ai/ai-rendering/local-rendering)

### S31

Jamulus: Setup, Monitoring und Plattformstatus

- [https://jamulus.app/wiki/Getting-Started](https://jamulus.app/wiki/Getting-Started)
- [https://jamulus.app/wiki/FAQ](https://jamulus.app/wiki/FAQ)

### S32

SonoBus: Handbuch, Peer-Verbindungen, Puffer und Verschlüsselung

- [https://www.sonobus.net/sonobus_userguide.html](https://www.sonobus.net/sonobus_userguide.html)

### S33

JackTrip: Produkt und Konfiguration von Studios

- [https://www.jacktrip.com/](https://www.jacktrip.com/)
- [https://support.jacktrip.com/managing-virtual-studios](https://support.jacktrip.com/managing-virtual-studios)

### S34

FarPlay: Aufnahme-/Monitorpfade und Latenz

- [https://farplay.io/](https://farplay.io/)
- [https://farplay.io/latency/](https://farplay.io/latency/)

### S35

JamKazam: Online-Musik und Netzpfade (Anbieterangaben)

- [https://jamkazam.com/play-music-live-online-with-others/](https://jamkazam.com/play-music-live-online-with-others/)
- [https://jamkazam.com/part-7-of-10-minimizing-latency-in-online-music-performance/](https://jamkazam.com/part-7-of-10-minimizing-latency-in-online-music-performance/)

### S36

Sessionwire: Funktionen und getrennte Gesprächs-/Musikwege

- [https://www.sessionwire.com/product](https://www.sessionwire.com/product)
- [https://www.sessionwire.com/blog/preparing-for-remote-collaboration](https://www.sessionwire.com/blog/preparing-for-remote-collaboration)

### S37

Audiomovers: LISTENTO Application Manual V3.99

- [https://audiomovers.com/content/uploads/2023/03/LISTENTO-Application-User-Manual-V3.99.pdf](https://audiomovers.com/content/uploads/2023/03/LISTENTO-Application-User-Manual-V3.99.pdf)

### S38

Steinberg: VST Connect; korrigierter Verbindungsweg im Support

- [https://www.steinberg.net/vst-connect/](https://www.steinberg.net/vst-connect/)
- [https://helpcenter.steinberg.de/hc/en-us/articles/360013543859-VST-Connect-How-to-connect-with-VST-Connect-Performer](https://helpcenter.steinberg.de/hc/en-us/articles/360013543859-VST-Connect-How-to-connect-with-VST-Connect-Performer)

### S39

Source Elements: Source-Connect und Version 4

- [https://www.sourceelements.com/products/source-connect/](https://www.sourceelements.com/products/source-connect/)
- [https://support.source-elements.com/sc4-studio-facility/introducing-source-connect-studio-and-facility-40](https://support.source-elements.com/sc4-studio-facility/introducing-source-connect-studio-and-facility-40)

### S40

Soundwhale: synchronisierte Sessions und Aufnahmegrenzen

- [https://soundwhale.com/](https://soundwhale.com/)
- [https://soundwhale.com/recording-software/](https://soundwhale.com/recording-software/)

### S41

Cleanfeed: Pro und getrennte Aufnahmespuren

- [https://cleanfeed.net/pro](https://cleanfeed.net/pro)
- [https://cleanfeed.net/knowledge/recording-to-separate-tracks](https://cleanfeed.net/knowledge/recording-to-separate-tracks)

### S42

Cockos: NINJAM; Ninbot: Client-Einordnung

- [https://cockos.com/ninjam/](https://cockos.com/ninjam/)
- [https://ninbot.com/](https://ninbot.com/)

### S43

JamTaba: Entwickler-Repository

- [https://github.com/elieserdejesus/JamTaba](https://github.com/elieserdejesus/JamTaba)

### S44

Endlesss: Entwicklerbeschreibung und Versionshistorie im App Store

- [https://apps.apple.com/de/app/endlesss-multiplayer-music/id1439811325](https://apps.apple.com/de/app/endlesss-multiplayer-music/id1439811325)

### S45

Mixed In Key: Satellite-Workflow

- [https://mixedinkey.com/satellite/how-to-guide/](https://mixedinkey.com/satellite/how-to-guide/)

### S46

BandLab: Studio und Einladungen zur Zusammenarbeit

- [https://www.bandlab.com/](https://www.bandlab.com/)
- [https://help.bandlab.com/hc/en-us/articles/115002945253-How-do-I-invite-other-users-to-collaborate](https://help.bandlab.com/hc/en-us/articles/115002945253-How-do-I-invite-other-users-to-collaborate)

### S47

Soundtrap: Zusammenarbeit und Aufnahme-Latenz

- [https://support.soundtrap.com/hc/en-us/articles/360023195053-How-to-Invite-Users-to-Collaborate-on-a-Soundtrap-Project](https://support.soundtrap.com/hc/en-us/articles/360023195053-How-to-Invite-Users-to-Collaborate-on-a-Soundtrap-Project)
- [https://support.soundtrap.com/hc/en-us/articles/26663690434066-How-to-Fix-Latency-Issues-in-Soundtrap](https://support.soundtrap.com/hc/en-us/articles/26663690434066-How-to-Fix-Latency-Issues-in-Soundtrap)

### S48

jammr: offizielle Schließungsmeldung

- [https://jammr.net/](https://jammr.net/)

### S49

Elk LIVE: Abruf nicht erfolgreich; Status unklar, keine Funktionsquelle

- [https://elk.live/](https://elk.live/)

### S50

ADM-OSC: offizielle Spezifikation und Repository

- [https://immersive-audio-live.github.io/ADM-OSC/](https://immersive-audio-live.github.io/ADM-OSC/)
- [https://github.com/immersive-audio-live/ADM-OSC](https://github.com/immersive-audio-live/ADM-OSC)

### S51

d&b: DS100 OSC-Protokoll, Version 1.3.12

- [https://www.dbaudio.com/assets/products/downloads/manuals-documentation/electronics/dbaudio-osc-protocol-ds100-1.3.12-en.pdf](https://www.dbaudio.com/assets/products/downloads/manuals-documentation/electronics/dbaudio-osc-protocol-ds100-1.3.12-en.pdf)

### S52

Apple: Audio Unit v3 / Hosting

- [https://developer.apple.com/documentation/audiotoolbox/hosting-audio-unit-extensions-using-the-auv2-api](https://developer.apple.com/documentation/audiotoolbox/hosting-audio-unit-extensions-using-the-auv2-api)
- [https://developer.apple.com/audio/](https://developer.apple.com/audio/)

### R0

Produktgesetz, 24.09.2026 · Stand B `48ba58a7b33879b0efdc9fea6c96979b44a29197`

- [docs/dev/FOUNDER_PRODUCT_LAW.md](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/docs/dev/FOUNDER_PRODUCT_LAW.md)

### R1

Fähigkeits- und Claims-Stand · Stand B `48ba58a7b33879b0efdc9fea6c96979b44a29197`

- [docs/dev/FEATURE_STATUS.md](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/docs/dev/FEATURE_STATUS.md)
- [ContentPipeline/CLAIMS.md](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/ContentPipeline/CLAIMS.md)

### R2

Bestehende Oberfläche · Stand B `48ba58a7b33879b0efdc9fea6c96979b44a29197`

- [Sources/Echoelmusic/Studio/StageShell.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Studio/StageShell.swift)
- [Sources/Echoelmusic/Studio/WorkstationView.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Studio/WorkstationView.swift)

### R3

Raumzustand und OSC-Grenzen · Stand B `48ba58a7b33879b0efdc9fea6c96979b44a29197`

- [Sources/Echoelmusic/Core/SpatialSceneStore.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Core/SpatialSceneStore.swift)
- [Sources/Echoelmusic/Sync/ADMOSCSender.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Sync/ADMOSCSender.swift)
- [Sources/Echoelmusic/Sync/OSCReceiver.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Sync/OSCReceiver.swift)

### R4

Lokaler Austausch und Netzwerk-Probes · Stand B `48ba58a7b33879b0efdc9fea6c96979b44a29197`

- [Sources/Echoelmusic/Sync/MultipeerSession.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Sync/MultipeerSession.swift)
- [Sources/Echoelmusic/Sync/ColabPayload.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Sync/ColabPayload.swift)
- [Sources/Echoelmusic/Sync/LinkProbe.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Sync/LinkProbe.swift)

### R5

Timeline-Eigentümer · Stand B `48ba58a7b33879b0efdc9fea6c96979b44a29197`

- [Sources/Echoelmusic/Core/TimelineStore.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Core/TimelineStore.swift)

### R6

Bus, Stimmen und Wiedergabe · Stand B `48ba58a7b33879b0efdc9fea6c96979b44a29197`

- [Sources/Echoelmusic/Core/EngineBus.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Core/EngineBus.swift)
- [Sources/Echoelmusic/Sequencer/LaneVoiceRack.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Sequencer/LaneVoiceRack.swift)
- [Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift)

### R7

Latenz-Kalibrationskern und erklärte Grenzen · Stand B `48ba58a7b33879b0efdc9fea6c96979b44a29197`

- [Sources/Echoelmusic/Audio/LoopbackCalibration.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Audio/LoopbackCalibration.swift)

### R8

Externe Bildbühne · Stand B `48ba58a7b33879b0efdc9fea6c96979b44a29197`

- [Sources/Echoelmusic/Studio/ExternalDisplayScene.swift](https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/Studio/ExternalDisplayScene.swift)

### R9

Historischer Auftrag: [PR #425 – Port-Kandidaten](https://github.com/vibrationalforce/Echoelmusic/pull/425). Der Inhalt ist an H im Repo vorhanden, siehe R14.

### R10

Plugin-Auswahl, native View und Host-Zustand · Stand H `b495ae64c7aec213c0552ecc5a4e754a9ce18681`

- [Sources/Echoelmusic/Studio/TrackPluginRow.swift](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/Sources/Echoelmusic/Studio/TrackPluginRow.swift)
- [Sources/Echoelmusic/Audio/HostedInstrumentHost.swift](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/Sources/Echoelmusic/Audio/HostedInstrumentHost.swift)

### R11

Persistenz und Writer für Instrument-/Effekt-Einträge · Stand H `b495ae64c7aec213c0552ecc5a4e754a9ce18681`

- [Sources/Echoelmusic/Core/DeviceChain.swift](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/Sources/Echoelmusic/Core/DeviceChain.swift)
- [Sources/Echoelmusic/Core/TimelineStore.swift](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/Sources/Echoelmusic/Core/TimelineStore.swift)
- [Sources/Echoelmusic/Core/PluginEffectInsert.swift](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/Sources/Echoelmusic/Core/PluginEffectInsert.swift)

### R12

Track-Bus-Grundlage im Audiograph · Stand H `b495ae64c7aec213c0552ecc5a4e754a9ce18681`

- [Sources/Echoelmusic/Audio/AudioEngine.swift](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/Sources/Echoelmusic/Audio/AudioEngine.swift)

### R13

Vorhandene H6-Planung; Status mit dem Code abgleichen · Stand H `b495ae64c7aec213c0552ecc5a4e754a9ce18681`

- [scratchpads/PLAN_H6_EFFECT_PLUGINS_2026-10-14.md](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/scratchpads/PLAN_H6_EFFECT_PLUGINS_2026-10-14.md)

### R14

Archiv-Audit im aktuellen Übergabestand; inhaltlicher Prüfstand B · Stand H `b495ae64c7aec213c0552ecc5a4e754a9ce18681`

- [reports/port-kandidaten-2026-10-14.md](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/reports/port-kandidaten-2026-10-14.md)

### R15

Geltende Repo-Regeln und Produktplanung · Stand H `b495ae64c7aec213c0552ecc5a4e754a9ce18681`

- [CLAUDE.md](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/CLAUDE.md)
- [docs/dev/FOUNDER_PRODUCT_LAW.md](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/docs/dev/FOUNDER_PRODUCT_LAW.md)
- [docs/dev/ECHOELMUSIC_MASTER_PLAN.md](https://github.com/vibrationalforce/Echoelmusic/blob/b495ae64c7aec213c0552ecc5a4e754a9ce18681/docs/dev/ECHOELMUSIC_MASTER_PLAN.md)

Alle Produktbewertungen beziehen sich auf die gelesene Dokumentation. Nicht dokumentierte Fähigkeiten werden nicht als fehlend ausgegeben. Die Gestaltung und Priorisierung sind Vorschläge; ihre Überlegenheit ist ohne Aufgabentests unklar. Dieser Bericht ersetzt keine Geräte-, Hör-, Lizenz- oder Interoperabilitätsprüfung.
