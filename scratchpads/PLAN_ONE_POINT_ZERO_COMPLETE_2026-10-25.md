# PLAN — Echoel Studio 1.0 enthält alles (2026-10-25)

> **Founder 2026-10-25:** „Ich möchte einfach die fertige App auf dem Markt bringen, die alles
> enthält." Das ersetzt die Reihenfolge in `docs/dev/NEUPLANUNG_2026-10-18.md` §5, nach der der
> Körper (P6) erst in 1.4, Licht und OSC (P4) in 1.2 und die Modulation (P5) in 1.3 kamen. Ab
> heute ist **1.0 die vollständige App**; der Store-Start (`PLAN_STORE_FIRST_2026-10-24.md`)
> folgt, wenn die Liste unten erfüllt ist. Die Bau-Gesetze von `EchoelStudio/CLAUDE.md` gelten
> unverändert.

## Was „alles" heißt — gemessen, mit der einen Annahme

**Annahme:** „alles" ist die DAW, die Studio heute ist, plus **jede Fähigkeit, die in der alten
App schon einmal funktionierend auf dem Gerät lief** (Klasse CURRENT oder REUSE in
`docs/dev/HISTORY_ARCHIVE.md`). Portiert wird der erprobte Kern in Studios Besitzer, nie ein
ganzes altes Subsystem (Produktgesetz §5, „recovery principle").

**Nicht in 1.0, mit Grund** (Founder-Entscheidungen vom 2026-09-12 oder kein erprobter Kern):
Video-Aufnahme und -Schnitt, RTMP-Streaming, Harmonizer, Granular, Autotune, Gesicht/Bewegung,
native Watch-, Mac- und Vision-Ziele, Ableton Link. Mac und Vision Pro laufen zum Start als
„Designed for iPad" ohne eigenen Code (Store-Plan, Scheibe 0). Wer davon etwas in 1.0 will, sagt
es mit einem Wort; dann rückt es in die Liste.

## Die Wellen (jede Welle = mehrere Scheiben ≤ 3 Dateien, Gate grün, dann TestFlight)

| Welle | Inhalt | Alte Quelle (Zeilen, gemessen) | Größe | Deine Hand |
|---|---|---|---|---|
| **W0** ✅ | Bildschirmtasten, Pads, Erststart mit Inhalt (10010) · Song-Loop, Overdub, Record ohne Vorbereitung (10011) | — | erledigt | — |
| **W1 Körper** | Puls über Kamera (rPPG), BLE-Gurt, HealthKit/Watch → ein `BodyFrame` (Puls, HRV, Kohärenz, Atem) · sichtbare Anzeige · Aus-Schalter | CameraCapture 681 · CameraAnalyzer 1 401 · RPPGConditioning 182 · PulsePeriodEstimator 100 · CameraRPPGBioPublisher 2 342 · PolarH10 563 · HealthKit 181 · HRVCoherence 363 | L | keine (App hat keine Import-Sperre; Kamera-/Bluetooth-/Health-Texte in `EchoelStudio/project.yml`) |
| **W2 Modulation** | `ModRoute` im Song (Quelle → Parameter, Tiefe, Kurve): Körper, LFO, Makro, MIDI-CC → jeder automatisierbare Parameter · im Render-Pass, feste Routen-Obergrenze | ModulationEngine 391 · ModulationMatrix 561 | M–L | keine; **Format-Version 3** mit Migration (`docs/FORMAT.md`, Golden) |
| **W3 Bild** | Generative Visuals als eigene Fläche und schwebendes Fenster, gespeist vom Song (Takt, Tonart, Pegel) und vom Körper · 3-Hz-Blitzgrenze | MetalBioView 3 169 | L | keine |
| **W4 Verbindungen** | Licht (Art-Net, sACN), OSC-Ausgang, ADM-OSC-Raumobjekte; ein Modul „Verbindungen", alles aus bis zum Einschalten, Bio-Daten nur mit Opt-in (`BioEgressPolicy`) | ArtNet · sACN · OSCSender · ADMOSCSender 610 · BioEgressPolicy 226 | M–L | **ja: eine Zeile in `studio.yml`** (F25 in der Inbox) |
| **W5 Klang+** | DDSP-Engine als viertes eingebautes Instrument · MPE-Ausgang · Bio-Reaktivität der Stimmen über W2 | EchoelDDSP 3 804 · MIDIOutput 872 | M–L | GM30 (2) beantwortet sich damit: **vor** 1.0 |
| **W6 Store** | Kaufprodukt, Store-Text aus `CLAIMS.md`, Datenschutz-Labels (Kamera, Health, Bluetooth), Screenshots, Review-Hinweis (kein Medizinprodukt) | — | M | **ja: F-15, Preis, Paid-Apps-Vertrag, Einreichen** |

**Reihenfolge und warum:** W1 zuerst, weil der Körper Echoels Kern ist und jede spätere Welle
(Modulation, Bild, Licht) ihn als Quelle braucht. W2 direkt danach, weil ohne Routen der Puls
nichts bewegt. W3 und W4 hängen beide nur an W1 + W2 und können sich abwechseln. W5 vor W6,
weil der Store-Text keinen Klang behaupten darf, der fehlt.

**Je Welle ein TestFlight.** Kein Build ohne etwas Neues zum Anfassen; jede Release-Notiz nennt
höchstens fünf Gerätetests.

## Was diesen Plan aufhalten kann

- **Gerät:** der rPPG-Puls lockte in der alten App erst nach mehreren Reparaturen (Licht, Takt,
  Konditionierung). Die Portierung erbt die Lösungen, die Bestätigung braucht trotzdem dich am
  Gerät (W1-Gerätetest).
- **Format:** W2 speichert Routen im Song, also Format-Version 3; ein Song aus 1.0 öffnet nicht in
  10004–10011. Das ist geplant, nicht ein Unfall.
- **Review:** Gesundheitsdaten in einer Musik-App prüft Apple genau. Die Texte bleiben bei
  „Selbstbeobachtung, keine Diagnose"; Bio verlässt das Gerät nie ohne Opt-in.
- **Gate:** W4 wartet auf die eine Workflow-Zeile (F25).
