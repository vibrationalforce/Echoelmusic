# SPATIAL_MIX_RESEARCH.md — Phase R (S-A0) · Immersive Master

**Datum:** 2026-10-04 · **Stand des Codes:** `d9b9f241d` (Zweig `claude/echoelmusic-review-optimize-u5jjpd`)
**Auftrag:** Founder-Prompt „SPATIAL MIX SOVEREIGNTY v1.0“, Phase R (L2 + L3). **Dieses Dokument ändert keinen Code.**
**Entscheidungen:** `docs/adr/007-immersive-master-format.md` · `docs/adr/008-stem-capture-strategy.md`
**Audit-Eintrag:** `docs/SPATIAL_EXPANSION_AUDIT.md` §7

---

## 0. Wie dieses Dokument zu lesen ist — und was es NICHT ist

**Konfidenz.** Jede Zeile trägt eine der folgenden Stufen:
- **VERIFIED** heißt: in dieser Sitzung in einer Primärquelle gelesen. Primärquellen sind die Referenz-Implementierung, ein Spec-Quelltext auf GitHub, eine Apple-Doku oder der Repo-Code.
- **LIKELY** heißt: nur aus Suchtreffern des Herstellers oder aus zwei unabhängigen Sekundärquellen.
- **UNVERIFIED / NEEDS-VERIFY** heißt: keine Quelle erreicht. Die Zeile nennt dann die Quelle, die man prüfen müsste.

**Die wichtigste Grenze steht hier vorne, nicht im Kleingedruckten.** Der Egress-Proxy dieser Umgebung sperrte `itu.int`, `tech.ebu.ch`, `adm.ebu.io`, `professional(support).dolby.com`, `help.apple.com`, `aomedia.org` und `sofacoustics.org`. Damit hat **keine** ITU-Empfehlung (BS.2076/2088/2094/2125/2127/2051/1770) und **kein** Dolby- oder Apple-Lieferhandbuch hier im Volltext vorgelegen. Was trotzdem VERIFIED ist, stammt aus den **EBU-Referenz-Implementierungen**, die die Standards ausführen: libbw64, EAR (`ebu_adm_renderer`, „Referenz-Implementierung von BS.2127“), der Quelltext der EBU ADM Guidelines (`ebu/adm.ebu.io`) und MediaInfoLib (`File_Adm.cpp`, prüft das Dolby-Profil). Hinzu kommen der IAMF-Spec-Quelltext (`AOMediaCodec/iamf/index.bs`), die Apple DocC-JSON und der eigene Code.
**Klausel-Nummern von ITU-Texten stehen deshalb bewusst nirgends.**

**Methode.** Zwei unabhängige Recherche-Durchläufe mit je einem adversarialen Gegenprüfer pro Bereich haben dieses Dokument gefüttert. Jede vom Prüfer gefundene Korrektur ist unten bereits eingearbeitet und als ⛔ markiert, weil eine zurückgenommene Aussage sonst wiederkommt.

**Zugriffsdatum aller Web-Zeilen:** 2026-10-04.

**Vier Prompt-Annahmen, die nicht mehr stimmen** (CLAUDE.md gewinnt, L0.1):
1. **„Zero dependencies: `Package.swift dependencies: []`“** stimmt nicht mehr. Seit B2 (Founder-Freigabe 2026-10-04) gibt es genau zwei Pakete, HaishinKit und Logboard, und beide **nur für RTMP**. Für dieses Vorhaben gilt die Regel trotzdem unverändert: libbw64, libadm, EAR, libear, libiamf, libmysofa und iamf-tools werden **nie gelinkt**. Sie dienen nur als Orakel außerhalb der App.
2. **„EBU Tech 3392“** ist laut EBU-Guidelines `documents/ebu_documents.md` **deprecated**. Nachfolger ist **EBU Tech 3393**, das ADM-Produktionsprofil für BS.2076-3 (VERIFIED). Dessen Grenzwerte konnten nicht gelesen werden (NEEDS-VERIFY).
3. **„Nothing in the headphone path is spatial today“** ist seit S3c (`5cf8d02fe`) **widerlegt**, siehe L3 #7.
4. **„the flag-off multitrack recording chain“** stimmt nicht: `FeatureFlags.audioLaneRecording` hat seit #1302 **gar keinen Zweig** mehr. Siehe L3 #2.

---

## 1. R1 — Container & Metadaten (der Master)

Quellen-Kürzel: **LB** = `github.com/ebu/libbw64/include/bw64/` · **EAR** = `github.com/ebu/ebu_adm_renderer/` · **G** = `github.com/ebu/adm.ebu.io/docs/` · **MI** = `MediaArea/MediaInfoLib/Source/MediaInfo/Audio/File_Adm.cpp`

### 1.1 Revisionen

| Aussage | Quelle | Konf. | Folge für Echoel |
|---|---|---|---|
| BS.2076-3 (02/2025) ist die gültige ADM-Fassung | itu.int Rec-Seite (Suchtreffer) | LIKELY | Wir schreiben eine konservative Teilmenge (§1.4). |
| Versions-Attribut: `version="ITU-R_BS.2076-N"` auf `audioFormatExtended` | EAR `ear/fileio/adm/elements/version.py` | VERIFIED | Wir schreiben **`ITU-R_BS.2076-2`**, weil das Dolby-Profil auf -2 aufbaut (R2) und EAR -2 parst. Ob ältere Importer „-3“ verstehen, ist NEEDS-VERIFY. |
| BS.2088-2 (11/2025) ersetzt BS.2088-1 (10/2019) | itu.int PDF-Titel (Suchtreffer) | LIKELY | Was sich in -2 geändert hat, ist **offen** (§8 F1). ⛔ Ein „gültig ab 2026-08-01“ samt „Annex 4“ stand im ersten Bericht ohne Quelle und ist gestrichen. |
| BS.2094-2 (02/2025) hält die Common Definitions | itu.int (Suchtreffer) | LIKELY | Die IDs in §1.5 vor dem ersten Bett-Export gegen -2 prüfen. |

### 1.2 BW64-Container (BS.2088), so wie die Referenz ihn schreibt

| Aussage | Quelle | Konf. | Folge |
|---|---|---|---|
| BW64 = RIFF/WAVE + `ds64` + `chna` + `axml`. Unter 4 GB bleibt der äußere Header `RIFF` mit echter Größe. Darüber wird er `BW64`, das Größenfeld 0xFFFFFFFF, und die echten Größen stehen in `ds64` | LB `writer.hpp` (`finalizeRiffChunk`); G `excursions/bw64_and_adm.md` | VERIFIED | Ein Swift-Writer ganz auf Foundation ist machbar. **Kein C++ nötig.** |
| libbw64 reserviert direkt nach `WAVE` einen 40-Byte-`JUNK`-Platzhalter (28 B `ds64` + 1 Tabelleneintrag) und überschreibt ihn erst beim Überschreiten von 4 GB. Ein Reader verlangt `ds64` als **ersten** Chunk | LB `writer.hpp`, `reader.hpp` | VERIFIED | Muster übernehmen: immer `JUNK` zuerst, dann ist ein In-Place-Upgrade möglich. |
| `ds64`: `riffSize` u64, `dataSize` u64, `dummySize` u64, `tableLength` u32, danach N × {chunkId u32, size u64}, little-endian | LB `chunks.hpp`; EAR `fileio/bw64/chunks.py` (`'<3QI'`, `'<4sQ'`) | VERIFIED (zwei Implementierungen stimmen überein) | Exaktes Byte-Layout für einen Golden-Test. |
| Chunks ungerader Länge bekommen ein Null-Pad-Byte. Das Größenfeld zählt das Pad nicht mit | LB `utils.hpp` | VERIFIED | Wichtig für `axml`, dessen Länge oft ungerade ist. |
| libbw64 schreibt einen 16-Byte-PCM-`fmt ` (Tag 1) mit 16, 24 oder 32 Bit | LB `chunks.hpp` | VERIFIED | ⛔ Der Satz „Extensible ist eine optionale Writer-Funktion“ ist gestrichen. Der Writer erzeugt Extensible nie, und der Klassenpfad dafür meldet eine falsche Chunk-Größe (`size()` liefert hart 16 u). **Nicht als Vorlage nehmen.** Ob BS.2088 für mehr als 2 Kanäle Extensible *verlangt*, ist NEEDS-VERIFY. |
| Kanal-Obergrenze aus `fmt `: Anzahl als u16, und Kanäle × Bytes/Sample ≤ 65535 (block align u16) | LB `chunks.hpp` | VERIFIED (Feldbreite) | Die Grenze des Standards selbst ist offen. Praktisch begrenzt Dolby auf 128 (R2). |
| `kAudioFileBW64Type` existiert in AudioToolbox | developer.apple.com (nur der Titel geladen) | LIKELY | Ob AVAudioFile/ExtAudioFile `chna`/`axml` schreibt, ist **NEEDS-VERIFY**. Davon hängt ab, ob wir den Container nachbearbeiten oder selbst schreiben. Empfehlung in ADR-007: selbst schreiben. |

### 1.3 `chna`-Chunk

| Aussage | Quelle | Konf. |
|---|---|---|
| Kopf: `numTracks` u16, `numUIDs` u16, dann N × 40-Byte-`audioID`; `ckSize = 4 + 40·N`; N ≥ numUIDs (Vorbelegung erlaubt) | G `excursions/chna_chunk.md`; LB `chunks.hpp`; EAR `bw64/chunks.py` | VERIFIED (drei stimmen überein) |
| `audioID` = `trackIndex` u16 (ab 1) + `UID` char[12] (`ATU_xxxxxxxx`) + `trackRef` char[14] (`AT_xxxxxxxx_xx`) + `packRef` char[11] (`AP_xxxxxxxx`) + 1 Pad-Byte | dieselben drei; EAR `'<H12s14s11sx'` | VERIFIED |
| Golden-Vektor Stereo: `ckSize=84`; Spur 1 = `ATU_00000001`/`AT_00010001_01`/`AP_00010002`, Spur 2 = `ATU_00000002`/`AT_00010002_01`/`AP_00010002` | G `chna_chunk.md` | VERIFIED |
| **Füllbytes sind uneinheitlich:** die Guidelines und EAR schreiben `\0`, libbw64 schreibt Leerzeichen | alle drei gelesen | VERIFIED. **Wir schreiben `\0`; ein Leser muss beides akzeptieren.** Welche Form Pro Tools, Logic und Nuendo verlangen, ist NEEDS-VERIFY. |
| `ATU_00000000` ist reserviert (stumm), EAR lehnt es ab | EAR `chna.py`; G `use_of_ids.md` | VERIFIED. UIDs ab `ATU_00000001`. |
| ⛔ „`AC_…_00` als trackRef **ab BS.2076-2**“: die Form selbst ist in EAR VERIFIED, die Versionszuordnung UNVERIFIED (kein Versions-Gate im Code) | EAR | Nicht schreiben. Wir nehmen die klassische Form `AT_…_01`. |

### 1.4 ADM-Modell: die Mindestmenge, die wir schreiben

| Aussage | Quelle | Konf. | Folge |
|---|---|---|---|
| Inhaltskette: `audioProgramme → audioContent → audioObject → (audioPackFormat + audioTrackUID)`. Formatkette: `audioPackFormat → audioChannelFormat (Blöcke) ← audioStreamFormat ← audioTrackFormat` | G `reference/adm_elements/*` | VERIFIED | **Minimum:** 1 programme, 1 content, je Spur ein `audioObject`, für jedes eigene Objekt die volle pack/channel/stream/track-Kette. Betten werden nur **referenziert** (§1.5). |
| ID-Schema `AP_yyyyxxxx` usw.: Typ Objects = `0003`; xxxx 0001–0FFF ist für Common Definitions reserviert, 1000–FFFF frei | G `use_of_ids.md` | VERIFIED | Objekt n → `AP_0003(1000+n)`, Block-Index ab `00000001`. |
| Zeitformat `hh:mm:ss.zzzzz` (≥ 5 Dezimalen, bei >48 kHz mehr empfohlen). Die Bruch-Form `…S<den>` gibt es erst in v2, und EAR lehnt sie in v1-Dateien ab | G `excursions/timing.md`; EAR `time_format.py` | VERIFIED | **Dezimal mit 9 Stellen**, nie die `S`-Form. |
| `rtime`/`duration` nur gemeinsam. Bei dynamischen Objekten sind die Blöcke **lückenlos**, zeitlich geordnet und beginnen bei 0. Eine Lücke = Sprung ohne Interpolation (EAR Issue #11) | EAR `block_formats.py`, `objectbased/renderer.py`; G `timing.md` | VERIFIED | Blockgrenzen sample-genau setzen und lückenlos halten. |
| Polar: Azimut −180…180, **positiv = links**; Elevation −90…90; Distanz normiert (1.0 = Kugelradius). Kartesisch: X rechts, Y vorne, Z oben, ±1 | G `excursions/coordinate_system.md` | VERIFIED | **Deckt sich mit unserer Konvention** (`Core/SpatialScene.swift`, `Core/HeadphoneSpace.swift`, `Sync/ADMOSCSender.swift`: Azimut positiv = links). Ein polarer Export braucht keine Umrechnung. |
| `jumpPosition`: Default 0 interpoliert über den ganzen Block, 1 springt (bzw. über `interpolationLength`) | G `parameters/jump_position.md` | VERIFIED | ⛔ Korrigiert: **nur der ERSTE Block** bekommt `jumpPosition=1`, alle weiteren den Default **0**. Die erste Empfehlung („1 auf dem ersten, dann kurze Blöcke ohne `interpolationLength`“) hätte Treppenstufen erzeugt. |
| `gain` linear, Default 1.0. `gainUnit="dB"` gibt es erst in v2 | G `parameters/gain.md`; EAR `xml.py` | VERIFIED | Immer linear schreiben. |
| `importance` 0–10, Default 10 | G `parameters/importance.md` | VERIFIED | ⛔ Korrigiert: auf **Objects**-Blöcken akzeptiert EAR es auch in v1. Nur auf Nicht-Objekt-Blöcken ist es v2-only. Wir lassen es weg (Default). |
| Extent: polar `width`/`height` in Grad, `depth` als Verhältnis; kartesisch ist `depth` die **Y**-Achse | G `audio_channel_format_objects.md` | VERIFIED | `SpatialObject.extent` existiert, wird aber heute nirgends gelesen (§6). v1: 0 schreiben. |
| `profileList`/`profile` (profileName, -Version, -Level) kann Konformität deklarieren. Generisches ADM trägt das Label `ADM_ITU2076` | G `best_practices/adm_profiles_levels_table.html` | VERIFIED (Attribute) · Ort des Elements UNVERIFIED | Kein Profil deklarieren, das nicht validiert ist. |

### 1.5 BS.2094 Common Definitions (Betten)

Quelle für alle Zeilen: EAR `ear/fileio/adm/data/2094_common_definitions.xml`, vollständig gelesen, ohne Revisionsmarke.

| Pack | Inhalt | Konf. |
|---|---|---|
| `AP_00010001` | Mono 0+1+0 → `AC_00010003` | VERIFIED |
| `AP_00010002` | Stereo 0+2+0 → `AC_00010001` L (M+030), `AC_00010002` R (M−030) | VERIFIED |
| `AP_00010003` | „5.1 (0+5+0)“: L, R, C, **LFE (4.)**, Ls M+110, Rs M−110 | VERIFIED |
| `AP_00010017` | 7.1.4 (4+7+0): L, R, C, LFE, SideL/R, BackL/R M±135, TopFrontL/R U±045, TopBackL/R U±135 | VERIFIED |
| `AP_00010016` | „7.1.2 (2+7+0)“: die Datei enthält `AC_0001000b` SideRight und `AC_0001000c` **TopCentre**, aber **kein** SideLeft | Dateiinhalt VERIFIED · als korrektes BS.2094-Bett **UNVERIFIED (verdächtig)**. **Nicht schreiben**, bevor das gegen BS.2094-2 geprüft ist. |

Common-Bett-Spuren brauchen nur einen `chna`-Eintrag und einen `audioObject`-Verweis; IDs ≤ 0FFF löst der Leser aus BS.2094 auf (G `chna_chunk.md`, VERIFIED).
⚠️ **Für Atmos-Ingest gilt das womöglich nicht.** Dolby-Master beschreiben das Bett laut Drittquellen mit **eigenen** Kanalformaten in kartesischen Koordinaten (UNVERIFIED, §8 F3).

### 1.6 S-ADM (BS.2125)

**Urteil: nur Recherche, nicht gebraucht.** S-ADM rahmt ADM in Zeitfenster für Live-Strecken über AES3 (ST 2116), ST 2110-41 und MXF/IMF (G `documents/adm_standards.md`, VERIFIED; die Flusstypen sind LIKELY). Unser Live-Pfad ist ADM-OSC, unser Liefergegenstand ist eine Datei, und ein iPhone hat weder AES3 noch ST 2110. Wiedervorlage nur, wenn ein Sender oder eine IMF-Lieferung Ziel wird. **Die RTMP-Strecke aus B2 ist kein Anlass**: sie trägt Stereo-Master plus Bild, keine Objekte.

---

## 2. R2 — Lieferrealität: was Plattformen und Studios annehmen

⚠️ Apple-, Dolby- und Steinberg-Seiten waren gesperrt. Alles hier, was nicht aus dem MediaInfo-Quelltext oder dem ADM-OSC-Repo stammt, ist höchstens **LIKELY**.

### 2.1 Musik-Lieferung (Apple Music u. a.)

| Aussage | Quelle | Konf. | Folge |
|---|---|---|---|
| Apple erwartet den Immersive-Master als **BWF ADM**, eine Datei pro Titel | help.apple.com Video & Audio Asset Guide (Snippet) | LIKELY | Lieferung ist eine Datei. Heute hat Echoel **keinen** BW64-Writer (`git grep -n -iw "BW64\|axml\|chna" -- Sources` → 0; ⛔ ohne `-w` sind es 14 Falschtreffer wie `leadPatchName`). |
| 24-bit LPCM, 48 oder 96 kHz; 96 k wird für die Ausgabe auf 48 k gewandelt | dto. | LIKELY | Ziel: **48 kHz / 24-bit**. Die Engine läuft schon mit 48 kHz (`Audio/AudioConfiguration.swift`). |
| Integrierte Lautheit **nicht über** −18 LKFS, True Peak nicht über −1 dBTP, gemessen nach BS.1770-4 | dto. | LIKELY | −18 ist eine **Obergrenze**, kein Ziel. Unser Stereo-Export normalisiert auf −14 (`Core/LoudnessTarget.swift`, Default „Streaming“). Für einen Immersive-Master ist das das falsche Ziel. |
| Tidal und Amazon dieselben Grenzen | Labelgrid, Distrokid (Blogs) | UNVERIFIED | Annahme: Apples Grenzen sind bindend, bis Erstquellen da sind. |
| Der Immersive-Master muss **gleich lang** wie der Stereo-Master und mit ihm synchron sein | Apple (Snippet) | LIKELY | Ein Export erzeugt **beide** aus derselben Aufnahme (ADR-008). |
| Kein Vollband-Inhalt im LFE | Apple (Snippet) | LIKELY | v1 schreibt **kein LFE** (ADR-007). |
| Eine Stereo-Mischung, die mit Hall „in den Raum gestellt“ wird, gilt nicht als Atmos | Apple (Snippet) | LIKELY | **Kein Upmix.** Objekte brauchen echte Einzelquellen, also Stems pro Spur. Das ist der Kern von ADR-008. |
| Binaural Render Mode (Off/Near/Mid/Far) je Kanal/Objekt *sollte* gesetzt sein | Apple (Snippet) | LIKELY | Proprietäre Metadaten (§2.2). Ein „sollte“, kein „muss“. |
| Frame-Rate einheitlich je Projekt; „24 fps“ und FFOA-Empfehlungen widersprechen sich zwischen den Quellen | Apple (Snippet) / Blogs | LIKELY / UNVERIFIED | Hängt am blockierten M1b (FrameTime/Timecode). Offen: §8 F2. |

### 2.2 Offen vs. proprietär in einem „Atmos-Master“

| Aussage | Quelle | Konf. | Folge |
|---|---|---|---|
| `axml`, `chna` und `ds64` sind der **offene** Teil (BS.2088/BS.2076) | libbw64 README (Apache-2.0) | VERIFIED | Das schreiben wir selbst, in Swift. |
| Das **Dolby Atmos Master ADM Profile v1.1** ist eine Teilmenge von BS.2076-2: nur DirectSpeakers und Objects, kein HOA, kein Matrix, kein Binaural | mediaarea.net Specs (Snippet) | LIKELY | Wer Dolby-Werkzeuge bedienen will, bleibt in dieser Teilmenge. |
| MediaInfoLib (BSD) prüft dieses Profil maschinell. Erkennung über `audioProgrammeName == "Atmos_Master"`; ≤1 audioProgramme (==1 für das Label); ≤123 audioContent/audioObject/audioPackFormat; ≤128 audioChannelFormat/audioTrackUID/audioTrackFormat/audioStreamFormat; trackUID-Rate 48000/96000; 24 bit; jedes audioObject beginnt bei `00:00:00.00000`; Programmdauer ±0,2 % zur Inhaltsdauer; trackUIDs lückenlos ab 00000001; Bett-Layouts 2.0/3.0/5.0/5.1/7.0/7.1/7.0.2/7.1.2; **audioObject→audioTrackUIDRef ≤10 (DirectSpeakers) bzw. ≤1 (Objects)** | MI ~2458–2467, 6847, 7014–7154, 7505–7590 | VERIFIED (als MediaInfos Kodierung) · LIKELY (als Dolby-Text) | **Eine prüfbare Abnahmeliste** für einen späteren Writer. MediaInfo kann außerhalb der App als Validator dienen. ⛔ „DirectSpeakers-Pack ≤10 Kanäle / Objects-Pack genau 1“ war das falsche Element; geprüft wird die TrackUID-Referenzzahl des Objekts, und das ist nur eine Obergrenze. |
| Renderer-Budget: 128 Eingänge, davon bis zu **118 Objekte**, dazu ein 7.1.2-Bett auf 1–10 | Dolby Atmos Renderer Guide v3.0 (2018, Snippet) | LIKELY | Autoren-Grenze: **118 Objekte + 10 Bettkanäle**. Die 123/128 von MediaInfo sind Element-Grenzen, kein Objekt-Budget. |
| Der `dbmd`-Chunk ist Dolby-proprietär und steht außerhalb von BS.2076 | Dolby Support „Master File Formats“ (Snippet) | LIKELY | **Schreiben wir nie** (kein Reverse Engineering). |
| Ob `dbmd` oder andere Dolby-Metadaten für den Ingest bei Apple, Tidal oder Amazon **Pflicht** sind | — | **UNVERIFIED** | **Die größte offene Frage.** Sie entscheidet, ob eine rein offene ADM-Datei überhaupt direkt ausgeliefert werden kann. Bis dahin gilt ADR-007: Wir liefern an das **Studio**, das Studio liefert an die Plattform. |
| `.atmos`/DAMF hält Trim-, Downmix- und Binaural-Metadaten; der Dolby-Renderer exportiert ADM BWF | Dolby (Snippet) | LIKELY | DAMF ist kein Ziel für uns. |
| EBU-Profil-Exporte (EAR Production Suite) sind laut Forum „nicht kompatibel“ mit Dolby-Werkzeugen | Gearspace (Snippet) | UNVERIFIED | **„Offenes ADM“ ist nicht dasselbe wie „Atmos-ingestfähig“.** Es sind zwei Profile und zwei Ziele (ADR-007, Frage F-A). |

### 2.3 Import eines **schlichten** ADM BWF — Kompatibilitätsmatrix

| Werkzeug | Was überlebt | Konf. |
|---|---|---|
| **Logic Pro** | Neues Atmos-Projekt: Bettspuren zu einer Bettspur zusammengefasst, je Objekt eine Mono-Spur, Stereo-Objekte in zwei Mono-Objekte geteilt, **Objekt-Automation angewandt**, Downmix und Trim übernommen | LIKELY (support.apple.com, Snippet). Verhalten bei Dateien **ohne** Dolby-Profil: unbekannt |
| **Pro Tools** | Import ab 12.8 über „Import Session Data“ mit Audio und Panning-Metadaten | UNVERIFIED (kein Avid-Primärtext) |
| **Nuendo** | ADM aus der Dolby Atmos Production Suite „mit intakter Objekt-Automation“ | LIKELY für Dolby-Profil-ADM; für beliebiges BS.2076 UNVERIFIED |
| **Reaper + EBU EAR Production Suite** | „Create project from ADM file“ erzeugt Spuren, Automationskurven und Metadaten-Plugins; tolerant gegenüber Profilen | LIKELY. **Bester freier Prüfpfad für ein offenes ADM.** |
| **Dolby Atmos Renderer** | Exportiert ADM BWF; ein Re-Render fremder ADM-Master ist nicht belegt | UNVERIFIED |
| **SPAT Revolution** (≥20.12) | Spielt ADM-Master ab und gibt die Metadaten als OSC aus | LIKELY |

### 2.4 ADM-OSC-Empfänger (Implementierungsmatrix v1.0, 14.10.2024)

Quelle: `immersive-audio-live/ADM-OSC`, Zweig gh-pages, `html/implementation_matrix.md` @ `af6ca9a6`. Die Zellen sind **VERIFIED**, die Versionsnummern LIKELY.

| Produkt | polar einzeln | `/aed` | x/y/z einzeln | `/xyz` | gain | Folge für Echoel |
|---|---|---|---|---|---|---|
| SPAT Revolution | ✓ | ✓ | ✓ | ✓ | ✓ | Beide Modi funktionieren. |
| L-ISA Controller | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| **Nuendo** | – | – | ✓ | ✓ | – | **Nur kartesisch, kein Gain.** Unser polarer Strom erreicht Nuendo nicht, und `sceneDialect` hat **keinen Schreiber** in der App (L3 #3). |
| d&b En-Bridge | rx | rx | ✓ | ✓ | ✓ | Polar nur Empfang. Aktuelle Version vermutlich v2.10 (UNVERIFIED). |
| Adamson FletcherMachine | ✓ | ✓ | ✓ | ✓ | ✓ | Breiteste Unterstützung. |
| Merging Ovation | – | ✓ | ✓ | ✓ | ✓ | ⛔ Korrigiert: polar nur gepackt, kartesisch einzeln **und** gepackt. |
| Meyer SpaceMap Go | rx | rx | rx | rx | rx | — |
| QLab 5 | tx | tx | tx | tx | tx | Sender, kein Empfänger. |
| Reaper, Dolby Renderer, Pro Tools, Logic | **nicht in der Matrix** | | | | | **Nicht behaupten.** |

Spec-Fakten (`adm-osc-quick-reference.md` v1.0, VERIFIED): UDP, Default-Port **4001** (Echoel: `Sync/ADMOSCSender.swift:102`), Query-Port 4002. ⛔ Korrigiert: Azimut und Elevation in **Grad**, nur `dist` und x/y/z sind normiert. Das „muss `/xyz` oder `/aed` können“ ist eine Checklisten-Empfehlung (§9), keine normative Pflicht.

### 2.5 Marke

Was Dolbys Nutzungsrichtlinien zu „Dolby Atmos“ in Fremdprodukt-Texten sagen, konnte **nicht gelesen** werden (NEEDS-VERIFY). Folge, L7: Der Satz bleibt *„exportiert einen offenen ADM-BWF-Immersive-Master (ITU-R BS.2076 / BS.2088) für immersive Mixing-Workflows“*. Ob der Programmname `Atmos_Master` in einer Datei (das ist der Erkennungsschlüssel des Dolby-Profils) markenrechtlich unproblematisch ist, ist eine **Founder- bzw. Juristen-Frage** (ADR-007, F-A).

---

## 3. R3 — Offene Alternativen

| Aussage | Quelle | Konf. | Folge |
|---|---|---|---|
| **IAMF v2.0.0** trägt im Header „Status: FD“ (Final Deliverable). PR #901 „Release v2.0.0“ ist am 2026-09-21 gemergt; libiamf hat einen v2.0.0-Release-Tag | `AOMediaCodec/iamf/index.bs`; PR #901; libiamf-Releases | LIKELY (freigegeben); das genaue Freigabedatum UNVERIFIED | ⛔ Korrigiert: Der erste Bericht hielt die Freigabe für offen. Der FD-Kopf beantwortet die Frage schon. |
| IAMF: OBUs (Sequence Header, Codec Config, Audio Element, Mix Presentation, Parameter Block, Audio Frame; v2 dazu Metadata). Codecs Opus, AAC-LC, FLAC, **LPCM** | index.bs | VERIFIED | LPCM-IAMF braucht keinen Codec. |
| `audio_element_type` 0 = Kanäle, 1 = Szene (Ambisonics), **2 = Objekte, neu in v2** | index.bs | VERIFIED | Objekt-Export nach IAMF geht nur mit v2. |
| Profile: Base-Advanced verlangt, dass die **erste** Mix Presentation nur Objekt-Elemente referenziert. Objekte gemischt mit Kanal- oder Szenen-Elementen gibt es erst ab Advanced-1/-2 (18/28 Kanäle) | index.bs §Profiles | VERIFIED (⛔ umformuliert; „Base-Advanced erlaubt nur Objekte“ war überzogen) | Ein N-Objekt-Echoel-Stück kostet N Kanäle von diesem Budget. |
| Objekt-Positionen: polar, Azimut **positiv = links**, Distanz /127 | index.bs | VERIFIED | Gleiche Händigkeit wie bei uns und bei ADM. |
| Szenen-Elemente sind **AmbiX** (ACN/SN3D), (1+n)², n ≤ 14 | index.bs §Ambisonics Config | VERIFIED | `Sync/AmbisonicsEncode` ist ACN/SN3D bis 3. Ordnung (16 Kanäle) und könnte das direkt füttern. Die Datei hat heute **null** Produktions-Aufrufer. |
| Kanal-Layouts: Die Tabelle zeigt nur die Positionen. **Kodiert** werden zuerst gekoppelte Paare, dann C, dann LFE, z. B. 5.1 = (L/R)(Ls/Rs) C LFE | index.bs, Regel nach den Layout-Tabellen | VERIFIED (⛔ korrigiert; „L/C/R/Ls/Rs/LFE“ war die Auflistungsreihenfolge) | Bei einem Export im BS.2051-Layout (LFE an 4.) wird umsortiert, und zwar auf die **Substream-Reihenfolge**. |
| Jeder Sub-Mix **SHALL** Lautheit für Stereo (System A) tragen; gemessen wird nach BS.1770-**4** | index.bs §Mix Presentation, §Loudness Info | VERIFIED | Ein IAMF-Export braucht immer zusätzlich ein Stereo-Rendering samt Messung. |
| Rendering ist **nicht** Teil von IAMF, sondern einer eigenen Spec **OAR 1.0.0** | index.bs | Verweis VERIFIED · Inhalt UNVERIFIED | Ohne OAR kein Versprechen „was du hörst, spielt IAMF so ab“. |
| **iamf-tools** (BSD-3-Clause-Clear) wandelt ADM-BWF in IAMF, schreibt aber immer **base profile + LPCM**. **Objekte sind „nicht direkt darstellbar“** und können zu Ambisonics 3. Ordnung gefaltet werden. Der Konverter ist „experimental“ | `iamf-tools/.../adm_to_user_metadata/README.md` | VERIFIED | Über das heutige Referenz-Werkzeug wird aus einer Objekt-Szene ein 3OA-Bett. **Objekt-Identität und Bewegung gehen verloren.** IAMF ist damit ein späterer Export, kein Master. |
| YouTube, Samsung-TVs (2025), Google TV/Android 16 und Chrome spielen IAMF („Eclipsa Audio“) | Google Open-Source-Blog u. a. (Suchtreffer) | LIKELY | Realistisches Erstziel für einen Immersive-Upload. Apple-Wiedergabe von IAMF: UNVERIFIED. |
| **AVAudioEnvironmentNode** verräumlicht **nur Mono-Eingänge**. Mehrkanal-Ausgabe nur in den Tags 4/5.0/6.0/7.0/7.0 Front/8, **ohne Höhen** | Apple DocC JSON | VERIFIED | Taugt für die binaurale Kopfhörer-Vorschau von Mono-Objekten (so nutzt S3c es heute). **Kein Vorschau-Renderer für 2+5+0 oder 4+7+0**, kein AmbiX-Decoder. |
| Head-Tracking am Environment-Node ab iOS 18; braucht das Entitlement `com.apple.developer.coremotion.head-pose` | Apple DocC | VERIFIED | Ein Entitlement ist eine Projekt-Änderung und damit **founder-gated**. |
| PHASE ist ein eigener Engine-Weltraum (Geometrie, Okklusion); `RenderingMode` gibt es nur auf visionOS 26 | Apple DocC | VERIFIED | Dass sich PHASE-Ausgabe nicht in den AVAudioEngine-Master oder den Export abzweigen lässt, ist LIKELY. Bestätigt ADR-001: PHASE nicht. |
| `kAudioChannelLayoutTag_HOA_ACN_SN3D` (iOS 11+) und `…_Atmos_7_1_4` (iOS 13+) existieren | Apple DocC | VERIFIED (Tags) | Eine AmbiX-Datei lässt sich mit Systemtypen taggen. Einen iOS-HOA-Decoder gibt es nicht belegt. |
| **MPEG-H 3D Audio**: Patentpool bei Via LA, lizenzpflichtig | via-la.com (Suchtreffer) | LIKELY | **Keine Implementierung.** |

---

## 4. R4 — Rendering & Lautheit (Vorschau und Messung ohne Dolby)

| Aussage | Quelle | Konf. | Folge |
|---|---|---|---|
| BS.2127-1 (11/2023) ist die gültige Fassung | itu.int (Titel) | LIKELY | Ob EAR -0 oder -1 umsetzt, ist offen. |
| **EAR** v2.0 ist „auch die Referenz-Implementierung von BS.2127“, BSD-3-Clause-Clear, Python. Layouts u. a. 0+2+0, 0+5+0, 2+5+0, 4+5+0, 4+7+0 | EAR README | VERIFIED | **Goldene Referenz** für Vorschau-Paritätstests, nur offline. |
| EAR-Punktquellen-Panner: konvexe Hülle über **nominale** Positionen, Gains auf **realen**. Dreiecke als **VBAP**-Tripel mit Leistungsnormierung, **Vierecke als `QuadRegion`** (kein VBAP). Virtuelle Lautsprecher oben und unten werden per `VirtualNgon` mit 1/√n heruntergemischt, dazu Zusatz-Lautsprecher an Lagenlücken | EAR `ear/core/point_source.py` | VERIFIED (Code; BS.2127-Text nicht gelesen) | **Eine reine VBAP-Vorschau weicht ab**, und zwar an Vierecks-Facetten (das obere Quadrat von 4+7+0), an den Polen und in Lagenlücken. `Sync/VBAPPanner` ist **nur 2-D** und kann keine Höhe. Für Parität müssten Triplet, QuadRegion, VirtualNgon und die Zusatz-Lautsprecher portiert werden. |
| EAR auf 0+2+0 pannt **nicht** L/R, sondern in 0+5+0 mit BS.775-Downmix und dämpft dann von 0 dB vorne auf −3 dB hinten | EAR `StereoPanDownmix` | VERIFIED | Eine Stereo-Vorschau über ein VBAP-L/R-Paar hätte hintere Objekte zu laut und nach vorn geklappt. Entweder die Regel umsetzen oder ehrlich „ungefähr“ schreiben. |
| Objekt-Gains sind mehr als ein Punkt-Panner: Screen, Channel-Lock, Divergenz, Extent, Zone Exclusion, Diffuse. Kartesische Objekte gehen über einen **eigenen allozentrischen Panner** | EAR `objectbased/gain_calc.py` | VERIFIED | Eine Vorschau ohne Extent und Divergenz stimmt nur für Punktobjekte mit Default-Werten. |
| BS.2051-3 (05/2022). Reihenfolgen: **0+5+0** = M+030, M−030, M+000, **LFE1**, M+110, M−110; **4+7+0** = M±030, M+000, LFE1, M±090, M±135, U±045, U±135 | EAR `ear/core/data/2051_layouts.yaml` | VERIFIED (EAR) / LIKELY (Revision) | Kanalreihenfolge im Bett-Export. LFE steht an 4. Stelle, anders als im IAMF-Substream. |
| BS.1770-5 (11/2023) ist aktuell; was sich gegenüber -4 geändert hat, ist offen | itu.int (Titel) | LIKELY | IAMF und Apple zitieren **-4**. Unser Messgerät auch (`DSP/EchoelLoudnessMeter.swift`). |
| Immersive Gewichtung: bei \|Elev\| < 30° gilt 1,41 (+1,5 dB) für 60° ≤ \|Az\| ≤ 120°, sonst 1,0; Höhen 1,0; **LFE ausgeschlossen** | BS.1770-Tabelle (Snippet); libebur128 `ebur128.c` | LIKELY (Tabelle) / VERIFIED (libebur128-Verhalten) | ⛔ libebur128 setzt das nur mit **explizit gesetzten** Kanalkarten um. Die Default-Karte wirft bei 4+7+0 sechs Kanäle still weg. Ein eigener Mehrkanal-Meter braucht Gewichte pro Kanalposition, und dieser Fallstrick gehört in den Test. |
| True Peak: BS.1770 Annex 2 verlangt ≥4× Oversampling; libebur128 nutzt einen 49-Tap-Polyphasen-Sinc | libebur128 | VERIFIED (libebur128) / LIKELY (ITU) | **Befund:** `DSP/EchoelMeter` schätzt True Peak mit 4× **Catmull-Rom**, nicht mit dem BS.1770-FIR. Unser dBTP ist **nicht normgerecht** und darf nicht als „BS.1770 true peak“ in eine Datei geschrieben werden. Außerdem ist die Boost-Kappe im Export ein **Sample**-Peak (`SingleExport.peakSafeGainDB`). |
| HRTF-Datensätze: **SADIE (original) Apache-2.0** in Googles Resonance Audio (VERIFIED, LICENSE gelesen); SADIE II Apache-2.0 (LIKELY); MIT KEMAR „keine Nutzungsbeschränkung, Zitat erbeten“ (LIKELY; ⛔ KEMAR ist ein Kopf- **und Torso**-Simulator, „ohne Torso“ war falsch); ARI CC BY-SA, Version 3.0 vs. 4.0 strittig (LIKELY); HUTUBS CC BY 4.0 (LIKELY) | Resonance-Audio-LICENSE; Suchtreffer | siehe Zeile | **Bevorzugt: SADIE II** (Apache-2.0, nach Lesen der LICENSE im Download). **ARI meiden**: ShareAlike würde ein verarbeitetes Asset in der App anstecken. Zero-Dep: SOFA bei Build-Zeit in ein flaches Asset wandeln, kein libmysofa (C) zur Laufzeit. |

---

## 5. R5 — Das bio-reaktive Problem: Aufnahme vs. Wiederholung

**Urteil: Die deterministische Offline-Neuberechnung eines Takes ist heute ABGELEHNT. Stems müssen in EINEM Durchgang aufgenommen werden, während der Take spielt.** Die Entscheidung steht in ADR-008. Das hier sind die Belege, gemessen am Code (Zeilennummern = Stand `470563f23`, Stichproben an `d9b9f241d` bestätigt).

**Was schon deterministisch ist:** `SeededRNG` (SplitMix64, `Sequencer/BioComposer.swift`) als einzige Zufallsquelle des Komponisten, Noten-IDs aus dem RNG, das Voice-Rauschen per Index geseedet, `CoherenceTrend` und die ModulationEngine-Glättung über `frame.timestamp`.

**Was es verhindert (jede Zeile allein reicht):**

| Ursache | Fundstelle | Konf. |
|---|---|---|
| Der Sequencer-Takt ist ein `DispatchSourceTimer` auf der **Main Queue** nach Systemzeit, nicht nach Samples. Der Dateikopf nennt sample-genaues Timing als Zukunft („W2“) | `Sequencer/PatternEngine.swift:5,21` | VERIFIED |
| Noten werden am **Anfang** eines Render-Blocks ohne Sample-Offset abgeholt. Welcher Block eine Note bekommt, ist ein Wettlauf Main ↔ Render | `Tools/PolySynthVoice.swift` (`drainNoteCommands()` in `renderOnAudioThread`) | VERIFIED |
| Re-Seed-Zeitpunkte nach Wanduhr (Evolve 25–45 s, `Date()` + Sleep) | `Studio/EchoelStudioView.swift` (Evolve-Task) | VERIFIED |
| Der Fallback-Seed pro Take ist `UInt64.random` | `EchoelStudioView.swift` | VERIFIED |
| `usableBio()` entscheidet über Veralterung per `CFAbsoluteTimeGetCurrent()` | `Core/EngineBus.swift` | VERIFIED |
| Das FX-Bio-Modul misst seinen Zeitschritt mit `systemUptime`; Bio-Events kommen aus einem 100-ms-`Task.sleep`-Poll | `Tools/FXBioModulator.swift`; `Bio/BioEventPublisher.swift` | VERIFIED |
| Verborgener Zustand: das Performer-Signatur-Salz (UserDefaults), das Wetter-Salz (live WeatherKit), „Randomize patch“, Live-MIDI-Eingang | `EchoelStudioView.swift`; CLAUDE.md | VERIFIED |
| Die Sample-Rate hängt an der Route (48 k Default, Bluetooth teils 24 k) | `Audio/AudioConfiguration.swift` | LIKELY |

**Was das Urteil zu OPEN machen würde:** (1) jede `generate()`-Eingabe samt beider Seeds und Salze mit dem Sample-Index loggen, an dem sie wirkte; (2) die Zuordnung Tick → Sample → aktueller Frame loggen; (3) **W2: sample-genaues Noten- und Parameter-Scheduling**; (4) Render-Quantum und Rate für den Offline-Lauf fest. Selbst dann bleibt offen, ob vDSP über Geräte und OS-Versionen hinweg bit-stabil ist.

**Aufnahme-Fakten (AVAudioEngine):**

| Aussage | Quelle | Konf. | Folge |
|---|---|---|---|
| **Nur ein Tap pro Bus** | Apple DocC `installTap`; `AVAudioNode.h` | VERIFIED | Heute gibt es drei Taps: Meter auf dem Limiter-Ausgang (`AudioEngine.swift:1006`), Pre-Chain-RMS auf `masterMixer` (`:1186`, bedingt) und RetroCapture auf `mainMixerNode` (`RetroCapture.swift:355`). Ein Stem-Rekorder kann keinen dieser Busse mitbenutzen. |
| Die angeforderte `bufferSize` ist nicht garantiert (Header: 100–400 ms; Forum: < 4800 Frames ignoriert) | Apple DocC; Forum 797033 | VERIFIED / LIKELY | Tap-Chunkgrenzen sind über Stems nicht deckungsgleich. **Ausrichten über `when.sampleTime`**, nie über Chunks. |
| Der Tap-Block läuft nicht auf Main; ob auf dem Render-Thread, ist undokumentiert | Apple DocC | VERIFIED / UNVERIFIED | Taps kommen spät und gebündelt. |
| Taps an mehreren Knoten **einer** Engine teilen einen Sample-Zeitstrahl, also **keine Drift**. Nach `reset()`/Stop beginnt die Sample-Zeit bei 0 | Header (`renderOffline`), Forum 749686 | LIKELY | Eine Master-Engine (unser Fall) hat keine Drift, aber Chunk-Versatz. |
| Manual Rendering: Engine muss gestoppt sein, offline „ohne Echtzeitgrenzen“, Moduswechsel entfernt Taps an Ein-/Ausgang | Apple DocC; `AVAudioEngine.h` | VERIFIED | Erst sinnvoll, wenn der Take reproduzierbar ist (oben: heute nicht). |
| Besser für die **generierten** Stimmen: im eigenen `AVAudioSourceNode`-Render-Block mitschneiden, in einen vorallokierten lock-freien Ring, ohne Tap | Repo: `PolySynthVoice.renderOnAudioThread` rendert bereits in `scratchL/scratchR` | LIKELY (Entwurfsschluss) | Sample-genau per Konstruktion. Plattenschreiben erst hinter dem Ring, nach dem Muster von RetroCapture seit #1413. |

**ADM-Blockdichte:**
- Die Mindestdauer eines Blocks ist 1 ms (Datei) bzw. ≥ 5 ms (serielles ADM) (EBU-Profil-Entwurf, Snippet, LIKELY).
- EAR interpoliert **Gains, nicht Positionen** über `interpolationLength` (EAR `renderer.py`, VERIFIED).
- Unsere echte Informationsrate liegt bei **~1 Hz**: Der ADM-OSC-Sender läuft mit ~20 Hz, gespeist aus ~1-Hz-Bio-Frames (das Bus-Gesetz in CLAUDE.md).
- Schätzung, nicht gemessen: ~300 B XML pro Block. Bei 16 Objekten macht das ~0,35 GB/h bei 20 Hz gegenüber ~1,7 GB/h bei 100 Hz; 16 Kanäle Audio 48k/24-bit kommen auf ~8,3 GB/h.

**Empfehlung (ADR-007):**
- Aufzeichnen mit 20 Hz auf der Sample-Uhr.
- Ausdünnen mit **zeit-treuem** Ramer–Douglas–Peucker (synchronisierte euklidische Distanz, nicht die senkrechte), Fehlerschranke ≤ 1° Azimut/Elevation und ≤ 0,01 Distanz, plus eine Höchstlänge pro Block.
- Die Toleranz der Importer gegenüber großen `axml`-Chunks ist offen (§8 F4).

---

## 6. R6 — Repo-Wahrheit für diese Mission (Code, nicht Doku)

| Baustein | Wahrheit | Fundstelle |
|---|---|---|
| Master-Kette | player → `masterMixer` → AutoMixChain (EQ → Gain → **PeakLimiter**, immer an) → `mainMixerNode` (**−1 dB-Trim**, `outputTrimLinear = 0.89`) → Ausgang | `Audio/AudioEngine.swift:184,886`; `Audio/AutoMixChain.swift` |
| Bounce | **Echtzeit-Mitschnitt** über RetroCapture auf `mainMixerNode`, kein Offline-Render. „Piece (WAV)“ spielt das Stück einmal ab Takt 1 | `Audio/LoopExporter.swift` (`exportPiece`); `Studio/PieceAudioExportTab.swift` |
| Export-Format | **44,1 kHz / 24-bit / 2 Kanäle**, resampelt aus der 48-kHz-Engine; Normalisierung auf integrierte LUFS (Default −14, abschaltbar), Boost gekappt an **Sample**-Peak −1 dBFS | `Audio/SingleExport.swift:145`; `Core/LoudnessTarget.swift` |
| Szene | `SpatialScene` = Objekte + Raum. `SpatialObject` hält Position, Extent, Gain, roomSend, motionRef, visualRef, ownerPeer. **Kein Bett, keine Kanalrolle, kein LFE.** `SpatialRole` ist eine **Kollaborations-Berechtigung**, keine Kanalrolle | `Core/SpatialScene.swift:65,153` |
| Ein Schreiber der Positionen | `SpatialSceneStore`: ein Objekt pro Nicht-Bio-Spur; `apply(ADMObjectInput)`; persistiert nur lokal | `Core/SpatialSceneStore.swift` |
| Kopfhörer-Raum (S3a–S3d) | Jede **Audio**spur über einen eigenen Mono-HRTF-Bus (`AVAudioEnvironmentNode`, `.HRTFHQ`) an ihrer Szenenposition, Schalter „Headphone space“ im Mixer, **Default AUS**. Generierte Stimmen bleiben Stereo. Kein Raumhall, kein Head-Tracking. Positionsänderungen wirken **live** am nächsten Transport-Schritt; nur das An/Aus wartet auf den nächsten Start | `Audio/AudioEngine.swift:2185–2205`; `Core/HeadphoneSpace.swift`; `Sequencer/TimelineAudioSink.swift`; `Core/StudioDefaultKeys.swift:659` |
| ADM-OSC aus | gepacktes `/aed` (#1421), Szenen-Arm (#1430), gepacktes `/xyz` (#1432), Port 4001 (#1433). Szenen-Streaming opt-in. **`sceneDialect` hat keinen Schreiber** → aus der App ist nur polar erreichbar | `Sync/ADMOSCSender.swift`; `Sync/SpatialSceneOSC.swift` |
| ADM-OSC ein | `ADMObjectInput` bewegt die Szene, UDP 8001 | `Sync/OSCReceiver.swift:234–370` |
| Render-Kerne | `Sync/VBAPPanner` (**2-D**), `Sync/AmbisonicsEncode` (ACN/SN3D ≤ 3. Ordnung), `DSP/BinauralPanner` (ITD/ILD, keine HRIR), `DSP/EchoelSpaceReverb`, `Core/EchoelFDNReverb+RoomModel`, `Sequencer/SpatialAutomationMapping`: **null Produktions-Aufrufer** | `git grep -n "Name(" -- Sources \| grep -v ': *//'` |
| Automation | `PerTrackAutomationResolver` löst nur Synth-Slots auf, **keine Raum-Schlüssel** | `Sequencer/PerTrackAutomationResolver.swift` |
| Mehrspur-Aufnahme | `TakeRecorder`/`RecordController` nehmen MIDI und Bio auf. Der Audio-Zweig ist an HEAD `nil`. E10-1 (Mikrofon in eine Spur, `AVAudioRecorder` außerhalb des Graphen) liegt **unkommittiert** im Arbeitsbaum und wartet auf die Freigabe des Info.plist-Schlüssels | `Core/RecordController.swift`; `EchoelmusicApp.swift` |
| Sync aus | nur MIDI Clock 24 ppqn; **kein Song Position Pointer, kein MTC/LTC**. Ableton Link ist nur ein Enum-Fall | `Audio/MIDIOutput.swift`; `Core/SignalRouting.swift` |
| Flags | Zehn Flags ohne Leser, darunter `spatialEngine`, `bioSpace`, `echoelRender`, `motionEngine`, `headTracking` | `Core/FeatureFlags.swift`; `docs/dev/FEATURE_STATUS.md` |

---

## 7. L3 — Re-Audit der Founder-Lückenliste (2026-10-04)

| # | Behauptung | Urteil | Beleg / Präzisierung |
|---|---|---|---|
| 1 | Nur ein Stereo-Master-Bounce, durch Limiter, −1-dB-Trim und LUFS-Normalisierung | **BESTÄTIGT, mit Präzisierung** | `AutoMixChain` (Limiter immer an), `AudioEngine.swift:886` (Trim), `SingleExport` (Normalisierung). Präzisierungen: (a) es ist ein **Echtzeit-Mitschnitt**, kein Offline-Render; (b) die Normalisierung ist abschaltbar („No target“); (c) Ausgabe 44,1 kHz, nicht 48; (d) zwei Lautheitsstufen, nämlich Live-Auto-Gain plus Export-Gain; (e) **mit „Headphone space“ an wird das Binaural in die Stereo-Datei eingebacken**; (f) MIDI verlässt die App zusätzlich als SMF Typ 1. |
| 2 | Kein Stem-Export pro Spur; Mehrspur-Aufnahmekette existiert, aber Flag aus | **TEILWEISE** | „Keine Stems“ stimmt: Die einzigen Audio-Schreiber sind RetroCapture und SingleExport. „Flag aus“ stimmt **nicht**: `audioLaneRecording` hat seit #1302 keinen Zweig, der Audio-Zweig ist hart `nil`. MIDI- und Bio-Takes **laufen**. |
| 3 | Positionen verlassen die App nur live per OSC; kein Trajektorien-Export | **BESTÄTIGT** | Kein Datei-Export. `Project.sharedDocumentData` entfernt den Session-Umschlag samt `DMMWProject.spatial`. Positionen sind pro Objekt statisch, Bewegung kommt nur über ADM-OSC-Eingang oder den Bio/Musik-Arm von Objekt 1. |
| 4 | SpatialScene kennt nur Objekte — keine Bett-/Kanalrolle, kein LFE | **BESTÄTIGT** | `SpatialScene.swift:65–80, 180–189`. ⚠️ `SpatialRole` **nicht** als Kanalrolle lesen, das ist die Kollaborations-Berechtigung. Eine Kanalrolle bräuchte einen **neuen Namen** (Vorschlag in ADR-007: `ChannelRole`), sonst kollidiert der Prompt-Name `SpatialRole` mit einem lebenden Typ. |
| 5 | Kein LTC/MTC — Live-ADM-OSC-Aufnahme in eine DAW ist nicht synchronisierbar | **BESTÄTIGT** | Null Treffer für MTC/LTC/Quarter-Frame/0xF1. `Timebase` vertagt Timecode, der MIDI-Datei-Import lehnt SMPTE-Division ab. Nur MIDI Clock, **ohne SPP**: Eine DAW kann den Takt folgen, aber keine Position. |
| 6 | ADM-OSC spec-korrekt seit #1210, aber NEEDS-FOUNDER-VERIFY in einem echten Renderer | **BESTÄTIGT, präzisiert** | #1210 hat nur die Blattnamen korrigiert. Gepacktes `/aed` kam mit #1421, `/xyz` mit #1432, Port 4001 mit #1433. Der Marker steht bei `ADMOSCSender.swift:29`. **Neu:** Nuendo empfängt laut Matrix **nur kartesisch**, und aus der App ist heute nur polar erreichbar. |
| 7 | Im Kopfhörerweg ist heute nichts räumlich (Binaural-Kern unverdrahtet) | **WIDERLEGT seit S3c** | `BinauralPanner` ist tatsächlich unverdrahtet, aber Apples HRTF-Renderer setzt **Audiospuren** an ihre Szenenposition (Schalter Default AUS). Nicht am Gerät bestätigt (G6, `TimelineAudioSink.swift:384`). Die generierten Stimmen bleiben Stereo. |

**Was die Liste übersieht:**
- **a.** Der Export ist 44,1 kHz; ein Immersive-Master braucht 48 kHz.
- **b.** Unser True Peak ist eine Catmull-Rom-Schätzung, kein BS.1770-FIR.
- **c.** `extent` und `roomSend` werden im Kopfhörer- und ADM-Pfad nicht gelesen.
- **d.** Das ADM-OSC-Kartesisch (Nuendo) ist in der App nicht schaltbar.
- **e.** Die generierten Stimmen (Synth, Bass, Body) haben keine Objektposition; nur Audiospuren sind Objekte.
- **f.** `Sync/VBAPPanner` ist 2-D und taugt nicht als Höhen-Vorschau.
- **g.** `docs/dev/FEATURE_STATUS.md` trug am alten HEAD noch „im Kopfhörer ist nichts räumlich“.
- **h.** Echoel hat mit E10-1 **demnächst echte Mono-Audioquellen** (Mikrofon-Takes). Die sind die natürlichsten Objekte überhaupt.

---

## 8. Offene Fragen (NEEDS-VERIFY, mit der Quelle, die man prüfen müsste)

| # | Frage | Quelle |
|---|---|---|
| F1 | Was ändert BS.2088-2 (11/2025)? Extensible `fmt ` Pflicht? Kanalgrenze? `chna`-Layout? | itu.int PDF BS.2088-2 |
| F2 | FFOA/Frame-Rate/Timecode für reine Musik-Master (die „24 fps“ sind umstritten) | Apple Asset Guide; Dolby Music Delivery Spec |
| F3 | Ist `dbmd` (bzw. Dolby-Metadaten wie Binaural Render Mode) für den Ingest **Pflicht**? Kartesisch Pflicht für Objekte? Common- oder eigene Bett-IDs? | Dolby „Master File Formats“; Apple Asset Guide |
| F4 | Toleranz der Importer (Logic, Nuendo, Pro Tools, Reaper/EPS) gegenüber großen `axml`-Chunks und hohen Blockraten; Füllbytes `\0` vs. Leerzeichen | Testdateien, real importiert (Studio-Session) |
| F5 | EBU Tech 3393: Level-Grenzen, Pflichtelemente, polar vs. kartesisch, minimale Blockdauer | tech.ebu.ch Tech 3393 |
| F6 | Schreibt `kAudioFileBW64Type` (AVAudioFile/ExtAudioFile) `chna`/`axml`? | Gerätetest oder Apple-Header |
| F7 | `AP_00010016` (7.1.2) in EAR ohne SideLeft, aber mit TopCentre: Datenfehler? | BS.2094-2 |
| F8 | OAR 1.0.0 (IAMF-Rendering): BS.2127-artig oder VBAP? | aomedia.org |
| F9 | BS.1770-5 vs. -4: Gewichte, True-Peak-Filter | itu.int |
| F10 | Lizenztexte von SADIE II und ARI im jeweiligen Download | zenodo / oeaw |
| F11 | Dolby-Markenrichtlinie zu „Dolby Atmos“ in Fremdtexten **und** zum Programmnamen `Atmos_Master` in einer Datei | Dolby Trademark Guidelines; Jurist |
| F12 | Lässt sich PHASE in AVAudioEngine einspeisen oder mitschneiden? | Gerätetest (nur noch relevant, falls ADR-001 neu aufgerollt wird) |

---

## 9. Nachvollziehbarkeit

Die Rohberichte beider Recherche-Durchläufe samt Gegenprüfung liegen in der Sitzungs-Scratchpad und werden **nicht** ins Repo kopiert, weil sie Quell-Downloads Dritter enthalten. Was hier steht, ist ihre geprüfte Zusammenfassung. Wer eine Zeile anzweifelt, folgt der Quelle in der Zeile, nicht diesem Dokument.
