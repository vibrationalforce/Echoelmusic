# ADR-007 — Immersive-Master-Format

- **Status:** **Proposed** — wartet auf Gate R (Founder beantwortet F-A … F-E unten). Kein Code vor der Antwort.
- **Datum:** 2026-10-04
- **Kontext:** Founder-Prompt „SPATIAL MIX SOVEREIGNTY v1.0“, Phase R. Belege: `docs/research/SPATIAL_MIX_RESEARCH.md` (R1–R4, R6, L3). CLAUDE.md überstimmt diesen Text bei jedem Konflikt.
- **Nummer:** 007, weil ADR-001…006 in `docs/SPATIAL_EXPANSION_AUDIT.md` §3/§6.8 vergeben sind.

## Problem

Echoel exportiert heute genau eine Audiodatei: einen **Stereo**-Echtzeit-Mitschnitt mit 44,1 kHz / 24 bit. Er läuft durch den Limiter, den −1-dB-Trim und die LUFS-Normalisierung. Räumliche Positionen verlassen die App nur live als ADM-OSC.

Ein Mischtonmeister kann mit einem Echoel-Stück deshalb nicht immersiv weiterarbeiten. Es fehlen Einzelquellen und eine zeitgestempelte Positionsspur.

## Entscheidung (vorgeschlagen)

1. **Primärer Master: ADM BWF**, also eine BW64-Datei nach ITU-R BS.2088 mit einem ADM-`axml` nach BS.2076 (deklariert als `ITU-R_BS.2076-2`) und einem `chna`.
   - Geschrieben wird er von einem **eigenen Swift-Writer**, der nur Foundation braucht und in `Audio/` liegt.
   - Das ADM-Modell und der Serializer sind rein, liegen in `Core/` und schreiben deterministisch: kein `Date()`, IDs aus dem Inhalt, feste Float-Formatierung.
   - Das Byte-Layout ist aus libbw64 und EAR belegt (Research §1.2/§1.3). Ein C++-Paket ist dafür nicht nötig.
2. **Inhalt v1 (das Mindest-Modell):**
   - **Jede Audiospur wird ein Objekt** (Typ `0003`, ein Mono-Kanal pro Objekt). Gefüllt wird es aus `SpatialSceneStore`: polare Koordinaten, Azimut positiv = links. Das ist unsere Konvention und die von ADM, eine Umrechnung entfällt.
   - **Die generierten Stimmen** (Synth, Bass, Body) haben heute keine Objektposition. Sie gehen als **Stereo-Bett** `AP_00010002` (BS.2094 Common Definition, nur referenziert) in die Datei. Das bleibt so, bis sie eigene Objekte bekommen.
   - **Kein LFE, keine Höhenbetten in v1.**
   - Die Objektbewegung kommt aus der zeitgestempelten Trajektorie (S-A2). Sie wird mit 20 Hz auf der Sample-Uhr aufgezeichnet und dann ausgedünnt: zeit-treues RDP mit ≤ 1° Winkelfehler, ≤ 0,01 Distanzfehler und einer Höchstlänge pro Block.
   - Die Blöcke liegen lückenlos. `jumpPosition=1` steht **nur im ersten** Block, alle weiteren tragen den Default 0.
   - Zeiten werden dezimal mit 9 Stellen geschrieben, nie in der `S`-Form. Gain ist linear, `importance` und `profileList` fallen weg.
   - Format: **48 kHz / 24 bit PCM.** Die Engine läuft bereits mit 48 kHz. Der Stereo-Export bleibt unverändert bei 44,1 kHz.
3. **Kein Limiter, keine Normalisierung und kein Trim auf Stems oder Objekten.** Lautheit wird **gemessen und berichtet**, nie erzwungen: in einer eigenen `loudness.json` (S-A6) oder als Information.
   - Unser True Peak ist eine Catmull-Rom-Schätzung und nicht BS.1770-normgerecht. Er wird deshalb **nicht als BS.1770-Wert** in eine Datei geschrieben, bis der FIR-Meter existiert.
4. **Zwischenstufe vor dem BW64 (S-A4):** ein Exportordner mit Stems und Trajektorien. Er besteht aus `manifest.json`, `stems/NN_<track>.wav` (alle gleich lang, sample-genau, vor dem Master), `trajectories/NN_<track>.json`/`.csv` und `README.txt`.
   - Damit kann ein Studio schon arbeiten, bevor der ADM-Writer bewiesen ist.
   - Er ist zugleich die Testgrundlage des ADM-Writers.
5. **Später, je nach Founder:**
   - **HOA AmbiX** (ACN/SN3D) aus dem schon vorhandenen `Sync/AmbisonicsEncode`.
   - **IAMF** nur **außerhalb der App** über iamf-tools. Grund: Der Referenzkonverter faltet Objekte zu Ambisonics 3. Ordnung. Ein In-App-Writer lohnt sich erst mit einem v2-Objektpfad und dem gelesenen OAR-Text.
6. **Niemals:**
   - **`dbmd`** und andere proprietäre Dolby-Chunks: kein Reverse Engineering.
   - **DAMF/`.atmos`**.
   - **MPEG-H**: Patentpool.
   - Eine Upmix-„Objektisierung“ des Stereo-Masters. Laut Apple-Lieferhandbuch wird eine solche Mischung abgelehnt.
   - Proprietäre Encoder (DD+, AC-4). Das ist der letzte Schritt **des Studios**, nicht unserer.
7. **Abhängigkeiten:** keine neuen.
   - libbw64, libadm, EAR/libear, MediaInfo und iamf-tools sind **Orakel außerhalb der App**. Der Founder oder die Recherche lässt sie auf exportierten Dateien laufen. Gelinkt oder vendored werden sie nie.
   - Die zwei Pakete aus B2 (HaishinKit, Logboard) gelten nur für RTMP.
8. **Namen:** Die vom Prompt vorgeschlagene Kanalrolle heißt **`ChannelRole`** (`.object | .bed(BS2051Channel) | .lfe`), nicht `SpatialRole`. Der Grund: `SpatialRole` existiert schon in `Core/SpatialScene.swift:153` als Kollaborations-Berechtigung. Ein zweiter Typ gleichen Namens wäre ein Compile-Fehler, eine Umbenennung des lebenden Typs ein Eingriff, den niemand bestellt hat.
9. **Ehrlichkeit (L7):** Erlaubter Satz bis zu einem Studio-Ingest:
   > „exportiert einen offenen ADM-BWF-Immersive-Master (ITU-R BS.2076 / BS.2088) für immersive Mixing-Workflows“

   „Dolby Atmos“, „Atmos-certified“ und „Apple Spatial Audio ready“ kommen in keine UI, keinen Store-Text, keine Website und keinen Commit-Titel. Jeder Bericht trennt zwischen **gebaut · verdrahtet · am Gerät bestätigt · im Studio bestätigt**.

## Begründung

- **ADM BWF ist das einzige offene Format, das alle drei Ziele zugleich bedient.** Logic öffnet es, Nuendo und Reaper öffnen es (jeweils LIKELY); Apple verlangt es als Lieferform (LIKELY); EAR rendert es als BS.2127-Referenz (VERIFIED).
- IAMF verliert heute über das Referenzwerkzeug die Objekte. HOA verliert die Objekt-Identität grundsätzlich.
- **Ein eigener Writer ist klein:** drei Chunks mit belegtem Byte-Layout plus deterministisches XML. Ein C++-Paket wäre die erste nicht-RTMP-Abhängigkeit, und dafür fehlt jeder Grund.
- **Objekte nur für Audiospuren** ist kein Verzicht, sondern die Wahrheit des Codes. Nur Audiospuren haben heute eine Szenenposition (S3). Mit E10-1 kommen echte Mono-Quellen dazu, die Mikrofon-Takes, und das sind ideale Objekte.

## Konsequenzen

- **Positiv:**
  - Ein Studio bekommt Einzelquellen samt Bewegung, ohne dass Echoel eine Lizenz braucht.
  - Der Stereo-Pfad bleibt unangetastet.
- **Negativ / offen:**
  - **Ob eine rein offene ADM-Datei direkt bei Apple Music, Tidal oder Amazon durchgeht, ist unbekannt.** Der Grund ist die `dbmd`-Frage, Research §8 F3. Bis das geklärt ist, lautet der Weg: **Echoel → Studio → Plattform**.
  - Generierte Stimmen sind nur ein Stereo-Bett, nicht positionierbar.
  - Das Dolby-Profil verlangt für ein „Atmos_Master“ Bedingungen, die wir v1 nicht erfüllen: unter anderem `audioProgrammeName == "Atmos_Master"`, laut Drittquellen kartesische Objekte, und eigene Bett-Kanalformate.

## Fragen an den Founder (Gate R)

| # | Frage | Empfehlung | Warum es deine Entscheidung ist |
|---|---|---|---|
| **F-A** | Zuerst ein **generisches ITU/EBU-ADM** (Reaper/EAR prüfbar, Logic wahrscheinlich) oder gleich ein **Dolby-Profil-konformes** (`Atmos_Master`, kartesisch, 48k/24, ≤ 118 Objekte)? | **Generisch zuerst**, danach ein Dolby-Profil-Schalter, sobald ein Studio-Ingest (TONIK/Loft) zeigt, was gebraucht wird | Markenfrage (`Atmos_Master` als Programmname) und Zielmarkt: Studio-Übergabe oder Direktlieferung |
| **F-B** | Generierte Stimmen in v1 als **Stereo-Bett**, oder warten, bis sie eigene Objekte sind? | **Stereo-Bett.** Sonst fehlt die Hälfte des Stücks im Master | Klangliche Erwartung im Studio |
| **F-C** | Export-Format 48 kHz / 24 bit für den Immersive-Master, der Stereo-Export bleibt 44,1? | **Ja** | Ändert, was der Nutzer bekommt |
| **F-D** | Reihenfolge: zuerst der **Ordner (Stems + JSON)** (S-A1…S-A4), ADM BWF danach (S-A5)? | **Ja.** Der Ordner ist früher nutzbar und ist das Testmaterial des Writers | Zeitplan vor TONIK/Loft |
| **F-E** | Darf die Markenfrage (Programmname `Atmos_Master` in einer Datei, Research §8 F11) an Jurist oder Dolby gehen, bevor es ein Dolby-Profil gibt? | **Ja, aber erst nach F-A „Dolby-Profil“** | Außenkommunikation |
