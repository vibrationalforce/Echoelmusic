# PLAN — Echoel Studio 1.0 ist die Workstation (Entscheid 2026-10-26)

> ⭐ **Entscheid 2026-10-26.** Founder: „Du entscheidest.“ Ausgeführt: **1.0 ist die Musik-Workstation, nicht die vollständige App.** Der Store-Termin bleibt März 2027. GSIDMMW bleibt der Horizont in `docs/dev/FOUNDER_PRODUCT_LAW.md`, kein Release und kein öffentliches Wort.
>
> Aufgehoben sind damit die zwei Sätze vom 25.10. unten („1.0 ist die vollständige App“ und der Nachtrag, der Video, Harmonizer, Granular, Autotune, Gesicht und „generative Super Intelligence“ in 1.0 zieht). Die Zitate bleiben stehen. Gelöscht wird nichts. Die DSP-Ports, die am 25.10. schon auf `main` liegen (rPPG-Konditionierung, Pulsperiode, HRV), bleiben Bibliothek. Sie sind kein Store-Gate.

> **Founder 2026-10-25, aufgehoben 2026-10-26:** „Ich möchte einfach die fertige App auf dem Markt bringen, die alles enthält.“ Das ersetzte an dem Tag die Reihenfolge in `docs/dev/NEUPLANUNG_2026-10-18.md` §5. **Diese Ersetzung gilt nicht mehr.** Es gilt wieder die Staffel der Vision vom 19.10. (`docs/dev/ECHOEL_VISION_2026-10-19.md`), ohne Förderung und ohne Installation als Geschäft.

## Was 1.0 ist

Die App, die TestFlight seit dem 19.10.2026 trägt, plus das, was die öffentliche Roadmap vor dem Store noch nennt:

- Instrumente, Effekte, Arrange, Session, Aufnahme, Mix, WAV- und MIDI-Export, Assistent nur mit Vorschlag und Undo.
- Komponieren: Startprojekte, Presets, Skalen-Lock, Stems, Projektpaket. Fertig heißt: ein Song mit vier Spuren entsteht, wird gespeichert und im Flugmodus exportiert.
- Eigene AUv3 als Einmalkauf, Wiederherstellung, Barrierefreiheits-Abnahme. Fertig heißt: sie klingen in zwei Hosts bei 44,1 und 48 kHz.

App frei, Plugins einmal, kein Konto, keine Telemetrie, on-device. Kein Heilungsversprechen. Das Wort Superintelligence steht in keinem Store-Text und auf keiner Seite.

## Was nicht in 1.0 ist

Körper, Modulation, Bild, Licht, OSC, ADM-OSC, DDSP als Store-Bedingung, Videoschnitt, Gesicht, Harmonizer, Granular, Autotune, Streaming, Ableton Link, native Watch, Mac und Vision. Mac und Vision Pro nur als „Designed for iPad“, ohne eigenen Code.

Danach, jedes Modul erst wenn es auf dem Gerät läuft: Live (MIDI-Clock, Szenen) im Frühjahr 2027, dann Bühne, dann Modulation, dann Körper als eine Quelle unter mehreren, dann Bild mit 3-Hz-Grenze. Video, Raum, Kollaboration und Generatoren erst, wenn Arrange und Export langweilig stabil sind.

## Was „alles“ am 25.10. heißen sollte — Historie

**Annahme jenes Tages:** „alles“ ist die DAW, die Studio heute ist, plus jede Fähigkeit, die in der alten App schon einmal funktionierend auf dem Gerät lief (Klasse CURRENT oder REUSE in `docs/dev/HISTORY_ARCHIVE.md`). Portiert wird der erprobte Kern, nie ein ganzes altes Subsystem (Produktgesetz §5). Diese Annahme beschreibt die späteren Module, nicht den Inhalt von 1.0.

⭐ **Nachtrag 2026-10-25, aufgehoben am 2026-10-26** (Founder: „Alle alten Features … auch Video-Aufnahme und -Schnitt, Harmonizer, Granular und Autotune sowie Gesicht und Bewegung. Und die ganze on Device generative Super Inteligence“): diese Punkte waren an dem Tag als W7–W10 in 1.0 gezogen. Der Katalog bleibt `docs/dev/ECHOELTOOLS_CATALOG_2026-10-25.md`. Sie sind wieder draußen. Video (#1304) und Audio-Eingang (#1302) wurden gelöscht, weil sie nicht hielten; sie kommen nicht als 1.0-Welle zurück.

Übrig außerhalb von 1.0, wie vor dem Nachtrag: native Watch-, Mac- und Vision-Ziele, RTMP-Streaming, Ableton Link — und zusätzlich W1–W5 als Module nach dem Store sowie W7–W10.

## Die Wellen

W0 ist erledigt und Teil von 1.0. W1–W5 sind Module nach dem Store, nicht seine Bedingung. W6 ist der Store selbst, aber ohne Kamera-, Health- und Bluetooth-Labels, solange der Körper nicht im Build ist. W7–W10 sind draußen.

| Welle | Inhalt | Stand 2026-10-26 |
|---|---|---|
| **W0** ✅ | Bildschirmtasten, Pads, Erststart mit Inhalt (10010) · Song-Loop, Overdub, Record ohne Vorbereitung (10011) | in 1.0, erledigt |
| **W1 Körper** | Puls über Kamera (rPPG), BLE-Gurt, HealthKit/Watch → ein `BodyFrame` · Anzeige · Aus-Schalter | nach dem Store. Bibliothek (HRV, rPPG) liegt schon in `EchoelDSP`; kein UI, kein Gate |
| **W2 Modulation** | `ModRoute` im Song | nach dem Store. Format-Version 3 erst dann |
| **W3 Bild** | Generative Visuals, 3-Hz-Blitzgrenze | nach dem Store |
| **W4 Verbindungen** | Art-Net, sACN, OSC, ADM-OSC, Opt-in | nach dem Store. Braucht die Zeile in `studio.yml` (F25) |
| **W5 Klang+** | DDSP, MPE-Ausgang | nach dem Store, nicht vor dem Store-Text |
| **W6 Store** | Kaufprodukt, Text aus `CLAIMS.md`, Screenshots, Hinweis kein Medizinprodukt | 1.0. Datenschutz-Labels nur für das, was der Build wirklich anfasst |
| **W7 Video** | Aufnahme, Schnitt, Export mit dem Mix | nicht in 1.0 (gelöscht #1304) |
| **W8 Stimme** | Autotune, Harmonizer, Granular | nicht in 1.0 (gelöscht #1302/#1305) |
| **W9 Gesicht + Bewegung** | Mimik und Bewegung als Modulationsquellen | nicht in 1.0 |
| **W10 Generative Intelligenz** | Muster, Melodie, Klang aus einem Satz | nicht in 1.0. Der Assistent bleibt Vorschlag und Undo. „Superintelligence“ ist kein Feature-Name |

**Reihenfolge, die am 25.10. hier stand** („W1 zuerst, weil der Körper Echoels Kern ist“), ist aufgehoben. Der Körper ist seit dem 15.10. nicht der Kern. Zuerst kommt der Store der Workstation, die schon läuft.

**Je Welle ein TestFlight**, wenn eine Welle überhaupt gebaut wird. Kein Build ohne etwas Neues zum Anfassen. Eine Release-Notiz nennt höchstens fünf Gerätetests.

## Was diesen Plan aufhalten kann

- **Umfang.** Der aufgehobene Nachtrag vom 25.10. ist die Gefahr: die nächste Session liest „1.0 enthält alles“ und baut W7. Diese Datei gewinnt gegen diesen Satz.
- **Review.** Gesundheitsdaten in einer Musik-App prüft Apple genau. Solange W1 nicht im Build ist, fragt 1.0 nicht nach Kamera, Health oder Bluetooth.
- **Gerät.** Was nach dem Store kommt, gilt erst nach einem Lauf auf dem Gerät. Die Bibliothek in `EchoelDSP` ist kein Beweis, dass der Puls in Studio läuft.
