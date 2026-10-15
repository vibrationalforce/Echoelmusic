# Echoelmusic — Tiefenarchitektur und barrierefreie Oberfläche (2026-10-15)

**Auftrag (Founder, 2026-10-15):** „Deep Architecture und accessible userinterface Design for
Professional DMMW-GMMW Echoelmusic. From Spectral Stem Separation via generative Sound and video
AI to production, cutting, live performance, eventproduction, Colabo à la JamKazam etc., OBS
YoloBox streaming Organisation, Content management production. Spatial Audio, Video, Visuals,
Laser and Light."

**Was diese Datei ist:** die Abbildung ALLER genannten Bereiche auf EIN Modell, gemessen am
Stand `f2d6ac01b`. Sie ersetzt nichts. Was schon gilt, wird zitiert, nicht wiederholt (#416):

- Produktgesetz: `docs/dev/FOUNDER_PRODUCT_LAW.md` (Produktion zuerst, Bio ist die Zugabe —
  Founder 2026-10-15).
- Kanonisches Modell und die 13 Architektur-Invarianten: `docs/dev/ECHOELMUSIC_MASTER_PLAN.md`
  §2 und §3. **Jede Zeile hier unterliegt ihnen.**
- Bühnen-Aufbau (E18) und Könnensstufen (E19): `docs/dev/FOUNDER_INBOX.md`.
- Wettbewerb und Ablehnungen: `reports/wettbewerb-und-redesign-2026-10-14.md` §3–§4.
- Multicam M1–M6: `scratchpads/PLAN_MULTICAM_2026-10-15.md`.

**Was sie nicht ist:** eine Behauptung nach außen. Store, Website und `ContentPipeline/CLAIMS.md`
nennen nur, was ausgeliefert und am Gerät gesehen ist.

---

## 0. Kurzfassung

Ein Stück, eine Uhr, viele Medien. Alles, was der Founder aufzählt, ist eine von sechs
**Tätigkeiten** an EINEM Dokument (`DMMWProject`) über EINER Zeitachse (`TimelineDocument`,
getaktet von `PatternEngine`):

```
 AUFNEHMEN ─▶ ERZEUGEN ─▶ BEARBEITEN ─▶ AUFFÜHREN ─▶ VERTEILEN ─▶ ARCHIVIEREN
 Kamera·Ton·   Stems·KI·    Schnitt·Mix·   Szenen·Show·   Stream·Export·  Bibliothek·
 Fremdkamera   Komponist    Automation     Licht·Raum     Colabo          Content
```

Vier Bausteine fehlen heute und tragen fast alles Weitere. Jeder ist klein im Kern:

1. **Medien-Jobs** (§3.2) — schwere Arbeit (Stem-Trennung, KI, Render, Ton-Abgleich) läuft als
   abbrechbarer Job abseits der Echtzeit und landet über die EINE Lande-Transaktion als neues
   Medium. Muster: `VideoImport.perform`.
2. **Zeit-Brücke** (§3.3) — Song-Uhr ↔ Host-Zeit ↔ Timecode, damit Kameras, Netzwerk-Geräte und
   Fremdsysteme auf dieselbe Zeit zeigen.
3. **Show-Ausgang** (§3.4) — EIN Besitzer für alles, was auf eine Bühne geht (Licht, Laser,
   Raum, Bild, Stream), mit EINEM Not-Aus.
4. **Netz-Transport** (§3.5) — EIN Transport auf Network.framework für Kamera-Link, Colabo und
   Live-Jam. Multipeer ist ab der Xcode-27-Beta abgekündigt.

---

## 1. Was heute steht (gemessen, nicht erinnert)

| Bereich | heute im Code | Befehl |
|---|---|---|
| Stück / Dokument | `DMMWProject` + `ProjectStore`, `TimelineStore` | `git grep -l DMMWProject -- Sources` |
| Medien | `MediaLibrary`, `MediaAsset`, `MediaAssetStore` (dauerhafte Identität) | Wächter `TheMediaAssetIsADurableIdentityTests` |
| Audio-Produktion | Spuren, Teile, Fades, Gain, Pitch, Stretch, Automation, Export (`SingleExport`, `LoopExporter`) | `ls Sources/Echoelmusic/Sequencer` |
| Video | Bildspuren stapeln (M2), Import, Aufnahme Rück + Front (M1), Blitz-Begrenzer `VideoFlashLimiter` | `git grep -l VideoLanePlan -- Sources` |
| Visuals | `MetalBioView`, schwebendes Fenster, Foto/Video als Ebene | — |
| Licht | `LightingStore` → Art-Net + sACN (Unicast), Blackout im Register | `git grep -l ArtNetSender -- Sources` |
| Laser | **nichts** außer einem Persistenz-Flag `laserEnabled` | `git grep -n "laserEnabled" -- Sources` |
| Raum | `SpatialSceneStore` → ADM-OSC aus und ein; ein `AVAudioEnvironmentNode` im Engine; Venue-Renderer-Kerne unverdrahtet (bewusst) | `git grep -l ADMOSCSender -- Sources` |
| Stream | `Stream/` = Gerüst hinter `canImport(HaishinKit)`, nicht verlinkt | `ls Sources/Echoelmusic/Stream` |
| Colabo | `MultipeerSession` (538 Zeilen) + `LiveColaboView`, Zustand statt Audio | `wc -l Sources/Echoelmusic/Sync/MultipeerSession.swift` |
| KI | `EchoelAI/` (FoundationModels, typisierte Befehle, Executor mit Undo) | `ls Sources/Echoelmusic/EchoelAI` |
| Stem-Trennung | **nichts** (null Treffer für Separation/Demucs, kein `CoreML`) | `git grep -il "separat" -- Sources` |
| Content | nur Pipeline (`ContentPipeline/`, nie in der App) | — |
| Barrierefreiheit | VoiceOver-Texte in 71 Dateien, Reduce Motion in 20, Dynamic Type in 20, Katalog nur Englisch (E4) | `git grep -l accessibilityLabel -- Sources \| wc -l` |

---

## 2. Das Modell — eine Erweiterung von Master-Plan §2, kein zweites

```
SESSION (DMMWProject)  ── die einzige Besitzerin des Stücks
 ├─ Timeline           Spuren: Audio · MIDI · Instrument · Video · Visual · Licht · Raum · Bio
 │                      Teile verweisen auf MEDIEN, nie auf Dateipfade (#1439: der Auflöser entscheidet)
 ├─ Szenen             nichtlineare Sicht DERSELBEN Teile (Clip-Start, Live)
 ├─ Medien             Asset + abgeleitete Fassungen: Stems · Proxy · Analyse · Ton-Fingerabdruck
 ├─ Show               Ausgangs-Profile pro Ort (Licht-Patch, Laser-Zonen, Raum-Objekte, Bild, Stream)
 └─ Lieferungen        Export-Profile + Metadaten (Content-Werkstatt)

EBENEN
 Steuerung   EngineBus (Momentaufnahmen + SPSC) · Parameter-Register · Modulation · Automation
 Medien      Audio-Graph (Echtzeit) · Bild-Takt (Metal, 60 fps) · Kamera-Sitzungen
 Zeit        PatternEngine = Song-Uhr · Host-Zeit-Brücke · Timecode
 Jobs        abseits der Echtzeit: Stems · KI · Render · Abgleich · Analyse
 Netz        ein Transport: Kamera-Link · Colabo · Jam · Fernsteuerung
 Adapter     OSC · ADM-OSC · Art-Net · sACN · MIDI/MPE · (Link) · (HaishinKit) · (SRT/NDI) · FCPXML
```

**Drei Regeln, die das Modell zusammenhalten:**

1. **Alles Neue ist ein Medium oder ein Teil.** Ein Stem, eine KI-Variante, eine Kamera-Aufnahme,
   ein Stream-Mitschnitt — jedes landet als `MediaAsset` und wird als Teil auf eine Spur gelegt.
   Es gibt keinen zweiten Ort, an dem „Material" lebt.
2. **Ein Besitzer pro Entscheidung.** Welche Bildspur zeigt: `VideoLanePlan.programShot`. Welche
   Region spielt: `TimelineScheduling.activeRegion`. Welches Tempo: `PatternEngine`. Neue
   Bereiche fragen diese, sie bauen sie nicht nach.
3. **Spezial-Infrastruktur wird angeschlossen, nicht gebaut** (Produktgesetz §1): Codecs, NDI,
   SRT, CDN, Plugin-SDKs, Venue-Renderer, Lichtpulte, NLE-Finishing.

---

## 3. Die vier tragenden Bausteine

### 3.1 Was sie gemeinsam haben

Jeder ist ein reiner Kern mit Wächter plus eine Geräte-Hälfte, die injiziert wird. Das ist das
Muster, das `VideoLanePlayer` + `VideoLaneAVSink` schon trägt.

### 3.2 Medien-Jobs (`Core/MediaJob…`, neu)

- **Was:** eine Warteschlange für schwere Arbeit mit Fortschritt, Abbruch und Ergebnis.
  Läuft nie im Render-Callback, nie auf dem Main-Thread (Invarianten 6 + 7).
- **Ergebnis:** immer ein neues `MediaAsset` (oder eine Analyse-Datei daneben), das über EINE
  Lande-Transaktion ins Stück kommt — ein Undo-Schritt.
- **Nutzer:** Stem-Trennung (§4.1), KI-Erzeugung (§4.2/§4.3), Ton-Abgleich M3, Proxy-Render,
  Lautheits-Analyse, Content-Render (§4.13).
- **Gerätegrenze:** Thermik und Akku entscheiden (`ResourceGovernor`); ein Job pausiert bei
  kritischer Thermik, statt die Wiedergabe zu stören.

### 3.3 Zeit-Brücke (`Core/TimeBridge…`, neu)

- **Song-Uhr** bleibt `PatternEngine` (Invariante 3).
- **Brücke:** jede Transport-Position bekommt eine Host-Zeit (`mach_absolute_time`), damit eine
  Kamera-Aufnahme, ein Netzwerk-Gerät und ein Stream-Mitschnitt wissen, welcher Takt zu welchem
  Bild gehört. Das ist der „Takt-Stempel" aus dem Wettbewerbs-Bericht §3.4.
- **Nach außen:** Timecode (LTC/MTC) und Ableton Link sind Adapter, nie Uhr-Besitzer. Link nur im
  Loop-Modus (T1/T2), LinkKit ist C++ → Founder.
- **M1b** (bildgenauer Kamera-Start) ist der erste Nutzer.

### 3.4 Show-Ausgang (`Sync/ShowOutput…`, neu)

- **EIN Besitzer** für alle Bühnen-Ausgänge: Licht (Art-Net/sACN), Laser (§4.11), Raum
  (ADM-OSC), Bild (externer Bildschirm), Stream (§4.10), Fremd-OSC (Resolume, TouchDesigner, QLab).
- **Ausgangs-Profil pro Ort:** ein Ort ist eine benannte Liste von Zielen. Ein Stück spielt an
  einem anderen Ort, ohne dass sein Inhalt sich ändert.
- **Drei Zustände je Ziel** (aus dem ChatGPT-Bericht übernommen): gesendet · Ziel antwortet ·
  am Ziel geprüft. Die Oberfläche sagt nie „verbunden", wenn nur gesendet wurde.
- **EIN Not-Aus** („Blackout"), von jeder Bühne in einem Tipp erreichbar: Licht dunkel, Laser
  aus, Bild schwarz. Der Blackout-Parameter existiert im Register; er wird der Besitzer für ALLE
  Bühnen-Ausgänge, nicht nur für Licht.
- **Sicherheit sitzt im Ausgang, nicht in der Quelle:** die 3-Hz-Blitzgrenze (`FlashGuard`,
  `VideoFlashLimiter`) gilt für jedes Ziel, das Licht ausgibt.

### 3.5 Netz-Transport (`Sync/PeerTransport…`, neu, ersetzt Multipeer)

- **Network.framework** (Bonjour + QUIC/UDP), wie Apple es für die Multipeer-Ablösung empfiehlt.
- **Ein Transport, drei Kanäle mit getrennten Regeln:**
  - *Zustand* (Tonart, Tempo, Szene, Bio-Ableitungen) — zuverlässig, klein.
  - *Medien* (Kamera-Bild HEVC, später Audio) — Echtzeit, verlustbehaftet, mit Zeitstempel aus
    der Zeit-Brücke.
  - *Dateien* (Teile, Stems, Projekte zum Austausch) — zuverlässig, groß, im Hintergrund.
- **Nutzer:** M4 (zweites iPhone als Kamera), K1 (Colabo umziehen), §4.8 (Jam).
- **Privatsphäre:** Körperdaten nur als `.derived`-Klasse aus `BioEgressPolicy`, Opt-in, aus per
  Standard (E8 bleibt offen).

---

## 4. Die Bereiche — je Ziel, Eigen oder Anschluss, Sperre, erste Scheibe

Legende **Sperre:** — = keine · **F** = Founder-Entscheidung · **A** = neue Abhängigkeit (Founder) ·
**P** = `Info.plist`/`project.yml` (Founder) · **G** = nur am Gerät beweisbar.

| # | Bereich | Ziel | Eigen / Anschluss | Sperre | erste Scheibe |
|---|---|---|---|---|---|
| 4.1 | **Spektrale Stem-Trennung** | Audio-Teil → 4 Stems (Stimme · Drums · Bass · Rest) als neue Teile, auf dem Gerät | Eigen: Job + Lande-Weg · Anschluss: ein Trenn-Modell (Demucs-Klasse, als Core-ML-Modell) | **A** (Modell ~80–300 MB, Lizenz prüfen) | S0: Job-Rahmen + „Split to stems"-Tür mit einem **spektralen** Trenner ohne Modell (Harmonisch/Perkussiv per Median-Filter, vDSP) — echt, klein, keine Abhängigkeit |
| 4.2 | **Generativer Klang (KI)** | Varianten, Begleitspuren, Füll-Takte aus dem Stück | Eigen: der deterministische Komponist bleibt Kern · KI **schlägt vor** (FoundationModels, typisierte Befehle) | — für Vorschläge · **F** für jedes Ton-Modell | Komponist-Varianten als Job, die als Teile landen („Keep take" gibt es) |
| 4.3 | **Generatives Video (KI)** | Bildmaterial aus Text/Bild | **Nur Anschluss** (Datei-Import aus externen Werkzeugen). Auf dem iPhone kein eigenes Modell | **F** | keine — Import Video reicht; Store sagt nichts dazu |
| 4.4 | **Produktion** | Spuren, Plugins (AUv3), Automation, Mix, Mastering, Export | Eigen | läuft (E11, `PLAN_PRODUCTION_LEVEL`) | weiter nach Plan H6 → Automation schreiben |
| 4.5 | **Schnitt** | Video- und Audio-Teile auf dem Takt-Raster schneiden, Multicam | Eigen: Teile-Werkzeuge + Stapel (M2) · Anschluss: FCPXML an Resolve/LumaFusion fürs Finishing | — | M1b bildgenauer Start → M3 Ton-Abgleich → FCPXML-Export |
| 4.6 | **Live-Performance** | Szenen-Reihe, XY-Pad, Generator-Regler, MIDI-Learn | Eigen | — | Szenen-Reihe als eigenes Blatt (Hot-State-Gesetz) |
| 4.7 | **Event-Produktion** | Cue-Liste: Szene X → Licht-Look, Laser-Zone, Raum-Szene, Bild, OSC an Fremdsysteme | Eigen: Show-Ausgang §3.4 · Anschluss: QLab/Pulte per OSC | — | OSC-Szenenabruf nach außen (B2) + Ausgangs-Profil pro Ort |
| 4.8 | **Colabo à la JamKazam** | (a) Zustands-Jam, (b) Intervall-Jam, (c) Echtzeit-Audio-Jam, (d) Datei-Austausch | Eigen auf §3.5 | (a)(b)(d) — · (c) **P** (Mikrofon E10-1) + im Internet **F** (Relay-Server = laufende Kosten) | K1: Colabo auf Network.framework, Zustand zuerst |
| 4.9 | **Multicam / YoloBox-Ersatz** | mehrere Kameras + Ton, synchron, Schnitt, Mitschnitt jedes Eingangs (ISO) | Eigen: M1–M4 · Anschluss: SRT/NDI M6 | M6 **A** | M1b (siehe Multicam-Plan) |
| 4.10 | **Streaming (OBS/YoloBox)** | RTMP/SRT raus, hoch + quer, Szenen, Overlays, Mitschnitt | Anschluss: HaishinKit (BSD-3) · Eigen: Szenen-Mix aus Bildspuren + Visual + Bauchbinde | **A** (HaishinKit) | bis zur Freigabe: externer Bildschirm (#206) → OBS per Capture-Karte |
| 4.11 | **Laser** | Laser-Looks vom Takt und Körper, Zonen, Not-Aus | Eigen: Looks über den Show-Ausgang · Anschluss: **DMX-Modus** der Laser über Art-Net/sACN (keine Abhängigkeit); später ILDA-Netz-DACs (z. B. Ether Dream) | Recht: Laser ab Klasse 3B brauchen am Einsatzort einen Laserschutzbeauftragten; die App behauptet nie „sicher" | Laser als Licht-Gerät mit eigenem Fixture-Profil + Blackout-Pflicht |
| 4.12 | **Licht** | Looks, Chases, Bio/Takt-Modulation, Fixture-Profile | Eigen (läuft) | — | Fixture-Gruppe verdrahten (`LightFixtureGroup` liegt unverdrahtet) |
| 4.13 | **Content-Werkstatt** | Ein Stück → Lieferungen: Reel hoch, Video quer, Audio −14 LUFS, Stems, Thumbnail, Untertitel | Eigen: Export-Profile + Job-Render · Spezifikationen aus Entfalt (`PLATFORM_SPECS`, `loudnorm`) | — | Export-Profil „Reel 9:16" aus Bildspuren + Mix |
| 4.14 | **Content-Management** | Bibliothek der Lieferungen mit Status (Entwurf · fertig · veröffentlicht), Metadaten, Rechte | Eigen: Lieferungen im Dokument · Anschluss: Veröffentlichen per Share-Sheet (kein eigener Upload) | — | „Lieferungen"-Liste im Projekt |
| 4.15 | **Raumklang** | (a) Kopfhörer: binaural/Head-Tracking auf dem Gerät · (b) Bühne: Objekte per ADM-OSC an fremde Renderer | (a) Eigen über `AVAudioEnvironmentNode` · (b) Anschluss (läuft) | (a) **G** | Spur → Raum-Objekt im Mixer (Position, Größe), Kopfhörer-Vorhören |
| 4.16 | **Video** | Aufnahme, Import, Stapel, Schnitt, Blitzschutz | Eigen (läuft) | **P** für den Kamera-Text | M1b |
| 4.17 | **Visuals** | generativ aus Musik + Körper, Footage-Ebenen, Ausgang auf Bildschirm/Stream | Eigen (läuft) | — | Visual als Szenen-Quelle im Show-Ausgang |

**Bewusst abgelehnt (unverändert aus dem Wettbewerbs-Bericht §4):** eigener Venue-Raumklang-
Renderer, Farbkorrektur/NLE-Finishing, Cloud-KI-Musik (Text-zu-Song), Syphon/Spout (gibt es auf
iOS nicht), Kompatibilitäts-Aussagen ohne Gerätelauf. **Neu bewertet:** Stem-Trennung ist
erlaubt, weil sie AUF DEM GERÄT läuft und kein Werk das Gerät verlässt. Der Echtzeit-Audio-Jam
ist erlaubt, sobald Mikrofon (E10-1) und Transport da sind; im Internet nur mit Founder-Freigabe
für einen Relay.

---

## 5. Barrierefreie Oberfläche

### 5.1 Grundsatz

**Jede Funktion ist auf drei Wegen erreichbar: berühren, sprechen (VoiceOver/Sprachsteuerung),
steuern (Tastatur, MIDI-Controller, Schaltersteuerung).** Ein Weg, der nur mit dem Auge geht, ist
ein Defekt, kein Stilmittel.

### 5.2 Wo die Bereiche wohnen — ohne neue Bühne

E18 hat die Umschaltleiste festgelegt: **Arrange · Mixer · Instrument · Browse · Project.** Alles
oben Genannte passt hinein, ohne eine sechste Bühne:

| Bühne | wohnt hier |
|---|---|
| **Arrange** | Spuren aller Arten, Schnitt, Multicam-Stapel, Stems als Teile, Automation |
| **Mixer** | Audio-Busse **und** eine Seite **„Outputs"**: Licht · Laser · Raum · Bild · Stream · OSC, mit Zuständen und dem Not-Aus |
| **Instrument** | Echoel, Szenen-Reihe, XY-Pad, Kamera-Karte, Live-Performance |
| **Browse** | Medien, Stems, Presets, Takes, Mitschnitte |
| **Project** | Stück-Einstellungen, Orte (Ausgangs-Profile), **Lieferungen** (Content), Colabo-Sitzung |

Eine sechste Bühne „Show" wäre die Alternative (E23). Die Empfehlung ist dagegen: der Mixer IST
der Ort, an dem Signale ihren Ausgang finden, und eine weitere Bühne verlängert die Leiste auf
dem Telefon über die Daumenbreite.

### 5.3 Regeln, die jede neue Fläche erfüllen muss

1. **VoiceOver:** jedes Bedienelement trägt Name, Wert und Hinweis. Teile auf der Zeitachse haben
   eigene Aktionen (Trimmen, Teilen, Verschieben, Stummschalten) über den Rotor — offen ist die
   Trim-Scheibe S4. Der Noten-Editor ist schon per VoiceOver bedienbar
   (`TheNoteGridEditsByVoiceOverTests`).
2. **Sichtbarer Name = Sprachname:** was auf dem Knopf steht, ist das Wort, das Sprachsteuerung
   versteht. Keine Symbol-only-Knöpfe ohne Label.
3. **Dynamic Type bis zur größten Stufe:** Panels brechen um (`AdaptiveCardGrid`), statt
   abzuschneiden. Zahlenfelder bleiben `EchoelValueField`.
4. **Ziele ≥ 44 pt**, auf der Bühne (Live) ≥ 60 pt, mit Abstand. Einhand-Bedienung für die
   Szenen-Reihe.
5. **Farbe trägt nie allein:** Spurart = Symbol + Wort + Farbe. Zustände (gesendet / antwortet /
   geprüft) = Wort + Form.
6. **Bewegung und Licht:** Reduce Motion abschalten, Blitze ≤ 3 Hz, Rot-Blitz-Kanal begrenzt
   (`VideoFlashLimiter`) — für Bildschirm UND Bühnen-Ausgänge.
7. **Ohne Sehen spielen:** Takt- und Szenenwechsel auch als Haptik und als leises Klick-Signal;
   Pegel und Tempo per VoiceOver-Ansage auf Abruf.
8. **Steuern ohne Touch:** Tastaturkürzel (iPad, Mac), MIDI-Learn auf jeden automatisierbaren
   Parameter (das Register gibt es), Schaltersteuerung über Standard-Elemente.
9. **Nicht-Muttersprachler:** ein Wort pro Sache (`docs/dev/GLOSSARY.md`), kurze Sätze. Die App
   spricht Englisch (E4); eine zweite Sprache beginnt mit dem Wiederherstellen der Einheiten.
10. **Untertitel:** Content-Lieferungen bekommen eine Untertitel-Spur (Teil der Lieferung, §4.13).
11. **Not-Aus** ist auf jeder Bühne in einem Tipp erreichbar und spricht sich als „Blackout".
12. **Gesetze bleiben:** keine neuen Modals an der Studio-Kette (Schwarzbild-Gesetz), heiße Werte
    nur in Blatt-Views (Freeze-Gesetz), Uncodixfy.

### 5.4 Plattformen

iPhone zuerst (Reihenfolge, nicht Umfang). iPad bringt HDMI/USB-Kameras (UVC) und mehr Fläche;
Mac und Vision Pro als „Designed for iPhone" (E15 offen). Große Flächen sind zuerst AUSGABE
(Bildschirm, Beamer, Raum), nicht eine zweite App-Oberfläche.

---

## 6. Reihenfolge

Die festgelegte Produktions-Reihenfolge (E11, `PLAN_PRODUCTION_LEVEL`) bleibt vorn. Die neuen
Bausteine schieben sich ohne Abhängigkeit dazwischen:

| Phase | Inhalt | Sperre |
|---|---|---|
| **P** | Produktion: Effekte + Spur-Mixer, Automation schreiben, AUv3-Hosting | läuft |
| **V** | Video: M1b (Zeit-Brücke) → M3 (Ton-Abgleich als erster Medien-Job) → FCPXML | — |
| **J** | Medien-Jobs: Rahmen + spektrale H/P-Trennung (S0) → Modell-Stems (4.1) | 4.1 **A** |
| **S** | Show-Ausgang: Besitzer + Not-Aus für alle → Laser als DMX-Gerät → Orte | — |
| **N** | Netz: K1 Colabo auf Network.framework → M4 Kamera-Link → Intervall-Jam | — |
| **D** | Verteilen: Export-Profile + Lieferungen → Stream (HaishinKit) | Stream **A** |
| **L** | Live-Audio-Jam (Echtzeit) | **P** (E10-1) + Internet **F** |

Eine Scheibe je Zyklus, jede mit Wächter, Gates grün vor der nächsten.

---

## 7. Founder-Entscheidungen

Einmal eingetragen in `docs/dev/FOUNDER_INBOX.md` (E23–E27). Bestehende bleiben dort: E8 (Puls
im Colabo), E9 (SharePlay), E10-1 (Mikrofon), E15 (Mac/Vision), HaishinKit, NDI, LinkKit.

- **E23** — Show/Outputs: Seite im Mixer (Empfehlung) oder sechste Bühne?
- **E24** — Stem-Trennung mit einem Modell auf dem Gerät (Demucs-Klasse, Core ML, +80–300 MB)?
- **E25** — Echtzeit-Jam über das Internet: Relay-Server mit laufenden Kosten, oder nur LAN?
- **E26** — Laser: zuerst nur DMX-Modus (keine Abhängigkeit), ILDA-Netz-DAC später?
- **E27** — Generatives Video: nur Import aus externen Werkzeugen, kein eigenes Modell?

---

## 8. Ehrlichkeit

Nichts davon ist am Gerät bestätigt außer dem, was §1 als „läuft" führt — und auch dort gilt die
Geräte-Liste (`python3 scripts/founder-verify.py`). Die Größenangabe für Stem-Modelle und die
Aussage über Ether Dream sind VERMUTET und vor der jeweiligen Scheibe zu messen.

---

## 9. Haltung und Formate — unabhängig, immersiv, inklusiv

Founder 2026-10-15, wörtlich: *„Für alles möglichst unabhängig und authentisch Echoelmusic
Chaos Computer Club Hamburg. VR/XR, Planetarium, 360, multidimensional, immersiv und inklusiv."*
Das ist eine Haltung UND eine Liste von Ausgabe-Formaten. Beides wird hier einmal festgehalten.

### 9.1 Unabhängigkeit — sieben Regeln für jede Scheibe

Im Geist der Hacker-Ethik, für die der CCC steht. ⚠️ Das ist eine HALTUNG, keine Zugehörigkeit:
nach außen wird der CCC nicht genannt — weder Name noch Logo, in keiner Kopie (E28, Founder 2026-10-15: „CCC nur Haltung").

1. **Lokal zuerst.** Jede Produktions-Funktion läuft ohne Netz und ohne Konto. Cloud ist ein
   Ausgang, nie eine Voraussetzung.
2. **Offene Standards vor Anbieter-SDKs.** OSC, ADM-OSC, Art-Net, sACN, MIDI, AmbiX, FCPXML,
   SRT. Ein SDK nur, wo kein offener Weg existiert, und dann founder-gated (HaishinKit, NDI,
   LinkKit stehen schon so in der Inbox).
3. **Deine Daten bleiben deine.** Medien liegen als normale Dateien im Projekt-Ordner, lesbar
   ohne Echoel. Kein proprietärer Container, aus dem man nicht mehr herauskommt.
4. **Keine Telemetrie, keine Tracker.** Diagnose bleibt auf dem Gerät und geht nur hinaus, wenn
   du sie selbst teilst (heute schon so: `echoel_diag.log`).
5. **Körperdaten verlassen das Gerät nie stillschweigend.** Die Bio-Egress-Sperre
   (`BioEgressPolicy`) gilt für jeden neuen Ausgang, auch für Stream und Colabo.
6. **Keine Abhängigkeit, die Geld kostet, ohne Freigabe** („Es sollen keine Kosten entstehen").
   Ein Relay-Server für Internet-Jam ist genau so eine Frage (E25).
7. **Nachvollziehbar.** Das Repo ist öffentlich; jede Behauptung nach außen steht in
   `ContentPipeline/CLAIMS.md` und ist aus dem Code belegbar.

### 9.2 Immersive Ausgabe-Formate

Alle drei teilen EINEN Kern: die Szene wird einmal als volle Kugel gerendert (Würfel-Textur,
sechs Seiten) und dann je Format umprojiziert. Ton läuft als Objekte oder Ambisonics daneben.

| Format | Bild | Ton | Was es schon gibt | Erste Scheibe |
|---|---|---|---|---|
| **360-Video** (YouTube, Headsets) | equirektangular 2:1 | AmbiX (Ambisonics) | `Sync/AmbisonicsEncode` (AmbiX bis 3. Ordnung, rein, **ohne Aufrufer**) | Würfel → equirektangular als reine Funktion mit Wächter; Export später |
| **Planetarium / Fulldome** | Domemaster: quadratisches Fischauge, 180° | Objekte über ADM-OSC an das Haus-System | `Sync/ADMOSCSender` (live) | Würfel → Domemaster aus demselben Kern |
| **VR/XR** (Vision Pro) | Raum statt Fläche | Objekte | nichts; Vision läuft heute nur als „Designed for iPhone" (E15) | erst nach E15; der Kern oben ist die Vorarbeit |

„Multidimensional" heißt hier praktisch: dieselbe Szene speist Fläche, Kuppel, Kugel und Raum,
ohne dass für jedes Format ein eigenes Projekt entsteht. Der visuelle Renderer (`MetalBioView`)
zeichnet heute nur eine flache Ansicht; die Kugel ist eine neue Stufe dahinter, keine Änderung
an seinem Shader.

### 9.3 Inklusiv

§5 (barrierefreie Oberfläche) gilt für jedes Format oben. Dazu für immersive Ausgaben:

- **Licht- und Blitz-Gesetz gilt auch in der Kuppel und im Headset** (max. 3 Hz) — gerade dort,
  weil das Bild das ganze Sichtfeld füllt.
- **Jede immersive Fassung hat eine flache Zweitfassung** (Stereo-Ton, normales Video), damit
  niemand ausgeschlossen ist, der kein Headset trägt oder keine Kuppel erreicht.
- **Sprache ist Teil der Barrierefreiheit:** die App ist heute nur englisch; Übersetzung bleibt
  ein eigener Strang (#232).

### 9.4 Reihenfolge

Ändert §6 nicht. Der Kugel-Kern ist eine reine Funktion ohne Abhängigkeit und passt als kleine
Scheibe zwischen V und S; Export eines 360- oder Domemaster-Films braucht danach den
Video-Export, den es heute nicht gibt.

**E28 beantwortet** (2026-10-15): nur Haltung. Die sieben Regeln in §9.1 gelten; der Name CCC erscheint
in keiner App-, Store-, Website- oder Content-Kopie.
